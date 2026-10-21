class_name TrainBridge
extends RefCounted
## One worker's side of the bridge between the trainer in Python and the race in Godot
## (RACING_PLAN.md, RD3; AI_FLEET_PLAN.md, D6b, "PPO in Python over the bridge"): a race of a
## curriculum stage (TrainingDrops) with several boards, each an environment of the trainer's, all
## sailed by the one network the trainer is learning. The messages are plain dictionaries (the
## worker script, Game/dev/train_worker.gd, sends and receives them as one JSON line each over a
## TCP socket; the tests call these functions directly):
##
##   hello()               what the trainer needs to know first: the observation's size and names,
##                         the actions', how many boards, the stage
##   reset(seed)           a new race for the stage; every board's first observation
##   step(actions, seed)   one decision for every board (the network's three numbers each), held
##                         for the stage's half second; then each board's observation, reward,
##                         whether its episode is over (and whether it was only cut short by the
##                         time limit), its stats at the end of an episode, and, for a board whose
##                         episode is over, the last observation of that episode (the one it has
##                         now is the first of the next)
##
## A board whose episode is over is set down again at once where the stage's rule says (S1 to S4:
## the drops do not depend on the race's clock), so the trainer always has a board in play; in the
## stages with a countdown (S5, S6) a board that is done waits, parked, until the race is over for
## everyone, and then the whole race is new. While it waits it reports its last observation, no
## reward and no end, so the trainer sees a few idle steps there (bounded: the race ends 60 s after
## the first finisher at most).

## A stage's races are seeded from the trainer's seeds; the drops of the respawns from this much on.
const RESPAWN_SEED_STEP: int = 7919


var stage: TrainingDrops.Stage
var boards: int = 4
var env: RaceEnv = null
## The last observation of each board (what a parked board keeps reporting).
var _last_obs: Array[PackedFloat32Array] = []
## The seed the race was made from, and a counter for the respawns' drops.
var _race_seed: int = 0
var _respawns: int = 0
## How many steps and episodes this worker has done, for the trainer's log.
var steps: int = 0
var episodes: int = 0
## The boards whose episode is over and that wait, parked, for the race to end (by number).
var _parked: Dictionary[int, bool] = {}


func _init(stage_name: String = "S1", board_count: int = 0) -> void:
	stage = TrainingDrops.stage_named(stage_name)
	if stage == null:
		stage = TrainingDrops.stage_named("S1")
	boards = board_count if board_count > 0 else stage.boards


## What the trainer needs to know first.
func hello() -> Dictionary:
	return {
		"obs_size": RaceObservation.size(),
		"obs_names": Array(RaceObservation.names()),
		"action_size": LearnedSkipper.TWA_ACTION_NAMES.size(),
		"action_names": Array(LearnedSkipper.TWA_ACTION_NAMES),
		"boards": boards,
		"stage": stage.name,
		"stage_description": stage.describe(),
		"decision_ticks": 30,
		"decision_s": 30 * RaceEnv.DT,
	}


## A new race of the stage from a seed: every board's first observation, and the race's facts.
func reset(seed: int) -> Dictionary:
	_race_seed = seed
	_respawns = 0
	_parked.clear()
	env = TrainingDrops.make_env(stage, seed, boards)
	_last_obs.clear()
	var obs: Array = []
	for i: int in env.board_count():
		var o: PackedFloat32Array = env.observe(i)
		_last_obs.append(o)
		obs.append(Array(o))
	return {"obs": obs, "race": _race_facts()}


## One decision for every board, held for the stage's decision interval, and what came of it.
func step(actions: Array, seed: int) -> Dictionary:
	if env == null:
		return {"error": "no race: reset first"}
	steps += 1
	var count: int = env.board_count()
	for i: int in mini(actions.size(), count):
		var action: PackedFloat32Array = PackedFloat32Array(actions[i])
		if action.size() < 3:
			action.resize(3)
		if not env.done(i):
			env.act(i, action)
	for t: int in env.decision_ticks:
		env.tick()
		if env.all_done():
			break
	var obs: Array = []
	var rewards: Array = []
	var dones: Array = []
	var truncated: Array = []
	var infos: Array = []
	var terminal: Array = []
	for i: int in count:
		rewards.append(env.reward(i))
		# A board done at this step ends its episode now; one parked since an earlier step does not
		# end it again.
		var done_now: bool = env.done(i) and not _parked.get(i, false)
		dones.append(done_now)
		truncated.append(done_now and env.board(i).truncated)
		infos.append(env.info(i) if done_now else null)
		if done_now:
			episodes += 1
			var last: PackedFloat32Array = env.observe(i)
			terminal.append(Array(last))
			_last_obs[i] = last
			_parked[i] = true
		else:
			terminal.append(null)
	var race_new: bool = false
	if stage.respawn_alone:
		for i: int in count:
			if env.done(i):
				_respawn(i, seed)
	elif env.all_done():
		# The race is over for everyone: a new one, from the trainer's seed.
		reset(seed)
		race_new = true
	for i: int in count:
		if env.done(i):
			# Parked: it keeps reporting where it ended, and nothing happens to it.
			obs.append(Array(_last_obs[i]))
		else:
			var o: PackedFloat32Array = env.observe(i)
			_last_obs[i] = o
			obs.append(Array(o))
	var reply: Dictionary = {"obs": obs, "rew": rewards, "done": dones, "trunc": truncated, "info": infos, "terminal_obs": terminal}
	if race_new:
		reply["race"] = _race_facts()
	return reply


# ---------------------------------------------------------------- inside

func _respawn(i: int, seed: int) -> void:
	_respawns += 1
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed * 1000 + i * RESPAWN_SEED_STEP + _respawns
	var drop: RaceEnv.Drop = TrainingDrops.drop(stage, env.race, env.course, rng)
	env.respawn(i, drop, rng.randi())
	_parked.erase(i)


func _race_facts() -> Dictionary:
	return {
		"course": env.course.name,
		"template": env.course.template,
		"wind_kt": snappedf(env.wind_kt, 0.1),
		"wind_from_deg": snappedf(env.wind_from_deg(), 0.1),
		"steps": env.race.steps().size(),
		"length_m": snappedf(SailingDistance.course_length_m(env.race, env.course.axis_deg), 1.0),
		"prestart_s": snappedf(env.options.prestart_s, 0.1),
		"episode_s": snappedf(env.options.episode_s, 0.1),
	}
