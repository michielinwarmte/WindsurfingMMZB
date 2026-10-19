class_name RaceEnv
extends RefCounted
## One race as a learning environment (RACING_PLAN.md, Part 9C): the boards, their sailors' hands,
## the race, and the reward that says how well each board is doing. A trainer runs it like this:
##
##   env.reset(seed)
##   while not env.done(0):
##       env.act(0, brain.forward(env.observe(0)))     # one decision...
##       for t in env.decision_ticks: env.tick()        # ...held for a tenth of a second
##       total += env.reward(0)
##
## (run_episode() does exactly that.) Every board is the open water's simulation, driven through
## the player's beginner controller with the auto-sheet on (RD1); the network's three numbers go
## onto the controller's hands through a LearnedSkipper.Driver, as in the game, so a brain sails here
## as it will there (in the wind-angle mode by default: the first number is the wind angle to hold;
## see LearnedSkipper). Nothing here is random except through the seed, so the same seed and the
## same actions give the same race, tick for tick.
##
## The reward (the plan's table, "What it is rewarded for"), per board:
##   + the metres gained toward the next step of the course, / 100: the dense signal that teaches it
##     to sail toward a point, and through that, to tack;
##   + 50 for each step completed (the start, each mark, the gate), + 200 more at the finish;
##   - 0.01 for each decision, so that faster is better;
##   - 20 for each fall, - 10 for being over the line at the gun (OCS).
## Collisions and running aground are not counted yet (one board on open water).
## A board's episode ends when it finishes, at the time limit, or when it is more than
## bounds_margin_m from the course; and, if stall_s is set, when it has gained nothing toward the
## course for that long (a trainer's saving: a board going nowhere is not sailed to the end). A
## board that is out of the race early (out of bounds or stalled) is charged the decisions it would
## have made up to the time limit: otherwise giving up would be cheaper than sailing on, and the
## trainer would breed quitters. Only finishing early saves time.

const DT: float = 1.0 / 60.0


## The settings of an environment. The defaults are stage 1 of the plan's curriculum: one lap of
## T1, a steady wind, flat water.
class Options:
	## The episode's time limit, seconds from reset (the countdown included).
	var episode_s: float = 240.0
	## The countdown, seconds.
	var prestart_s: float = 10.0
	var laps: int = 1
	## The network decides every this many ticks (6 ticks of 1/60 s: ten times a second).
	var decision_ticks: int = LearnedSkipper.DECISION_TICKS
	## How the network's numbers are read: the wind angle to hold, or the stick (LearnedSkipper).
	var actions: LearnedSkipper.ActionMode = LearnedSkipper.ActionMode.TWA
	var waves: bool = false
	var gusts: bool = false
	## A board further than this from the course's marks is out of the race.
	var bounds_margin_m: float = 1500.0
	## When above 0: a board whose progress (progress_m) has not reached a new best for this many
	## seconds is done.
	var stall_s: float = 0.0
	## How far behind the middle of the start line the boards wait at reset, metres. The plan's
	## pre-start spot (RaceCourses.pre_start_spot) is 150 m back, which is too far to reach the
	## 60 m line of T1 on one tack: a trainer can bring the boards closer while they learn.
	var start_behind_m: float = RaceCourses.PRE_START_BEHIND_M
	## The seed moves each board's starting spot along the line by up to this much (and back from it
	## by up to this much, or a quarter of start_behind_m if that is less, so that no board starts
	## over the line), and turns its heading by up to heading_jitter_deg, so a brain does not learn
	## one start by heart.
	var spot_jitter_m: float = 20.0
	var heading_jitter_deg: float = 15.0
	## The reward's weights (the plan's table). These are also the personality knobs.
	var progress_per_m: float = 0.01
	var step_bonus: float = 50.0
	var finish_bonus: float = 200.0
	var decision_cost: float = 0.01
	var fall_cost: float = 20.0
	var ocs_cost: float = 10.0


## One board: its simulation, its sailor, and the running sums of its reward.
class Board:
	var sim: WindsurferSim
	var controller: PlayerController
	var hands: AiHands
	## Turns the network's numbers into the hands (LearnedSkipper.Driver).
	var driver: LearnedSkipper.Driver
	var controls: SimControls
	## The reward earned since the last reward() call.
	var pending: float = 0.0
	## The whole episode's reward so far, and what it is made of.
	var total: float = 0.0
	var progress_m: float = 0.0
	## The best progress so far, and when it was reached (seconds since reset), for stall_s.
	var best_progress_m: float = 0.0
	var best_progress_at_s: float = 0.0
	var falls: int = 0
	var decisions: int = 0
	## The distance to the next step at the last tick, and how many steps were done then.
	var last_distance_m: float = 0.0
	var last_steps: int = 0
	var was_fallen: bool = false
	var since_manoeuvre_s: float = RaceObservation.SINCE_MANOEUVRE_SCALE_S
	var done: bool = false


var course: Course
var options: Options
var wind_kt: float = 15.0
## The network decides every this many ticks (from the options).
var decision_ticks: int = 6
var race: RaceSim
## The seconds since reset().
var time_s: float = 0.0
var ticks: int = 0
var _board_count: int = 1
var _boards: Array[Board] = []
## The area the boards must stay in: the marks' box grown by bounds_margin_m.
var _bounds: Rect2 = Rect2()


func _init(race_course: Course, boards: int = 1, wind_speed_kt: float = 15.0, env_options: Options = null) -> void:
	course = race_course
	_board_count = maxi(boards, 1)
	wind_kt = wind_speed_kt
	options = env_options if env_options != null else Options.new()
	decision_ticks = maxi(options.decision_ticks, 1)
	_bounds = course.bounds().grow(options.bounds_margin_m)


## A new race: new simulations at the waiting spots behind the start line (spread along it if there
## are several boards, each moved a little by the seed), a short countdown, and the race started.
func reset(seed: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	# The race's own time limit is far away: the episode's limit (done()) ends things first.
	race = RaceSim.new(course, options.laps, options.prestart_s, options.episode_s + 3600.0)
	time_s = 0.0
	ticks = 0
	_boards.clear()
	var start: RaceStep = race.steps()[0]
	var along: Vector2 = (start.points[0] - start.points[1]).normalized()
	# Straight back from the middle of the line, away from the course, as RaceCourses' pre-start spot.
	var back: Vector2 = (RaceCourses.pre_start_spot(course) - course.start_middle()).normalized()
	var spot: Vector2 = course.start_middle() + back * options.start_behind_m
	var back_jitter_m: float = minf(options.spot_jitter_m, 0.25 * options.start_behind_m)
	var heading_deg: float = RaceCourses.pre_start_heading_deg(course)
	var line_m: float = start.points[0].distance_to(start.points[1])
	for i: int in _board_count:
		# Several boards wait side by side along the line, so they do not start on top of each other.
		var share: float = (float(i + 1) / (_board_count + 1) - 0.5) if _board_count > 1 else 0.0
		var at: Vector2 = spot + along * (share * line_m + rng.randf_range(-1.0, 1.0) * options.spot_jitter_m)
		at += back * rng.randf_range(-1.0, 1.0) * back_jitter_m
		var board: Board = _make_board(at, heading_deg + rng.randf_range(-1.0, 1.0) * options.heading_jitter_deg)
		_boards.append(board)
		race.add_board("board%d" % (i + 1))
		race.update_board(i, at)
	race.start()
	for i: int in _boards.size():
		_boards[i].last_distance_m = race.distance_to_next_m(i)
		_boards[i].last_steps = race.next_step_index(i)


func board_count() -> int:
	return _boards.size()


## The board's simulation, its controller and its hands, for the tests and the tools.
func board(index: int) -> Board:
	return _boards[index]


## What board `index` sees now (RaceObservation).
func observe(index: int) -> PackedFloat32Array:
	var b: Board = _boards[index]
	var positions: PackedVector2Array = PackedVector2Array()
	var velocities: PackedVector2Array = PackedVector2Array()
	for other: int in _boards.size():
		if other == index:
			continue
		var t: Telemetry = _boards[other].sim.telemetry
		positions.append(Vector2(t.position.x, t.position.z))
		velocities.append(Course.direction_of(t.heading_deg) * t.speed_ms)
	return RaceObservation.build(b.sim.telemetry, race, index, b.sim.wind, positions, velocities,
			_in_manoeuvre(b), b.since_manoeuvre_s)


## A decision for board `index`: the network's three numbers (each -1 to 1) for its hands, held until
## the next decision: the wind angle to hold or the steer, the sheet, and (stick mode) the tack.
## Each decision costs decision_cost.
func act(index: int, action: PackedFloat32Array) -> void:
	var b: Board = _boards[index]
	if b.done:
		return
	b.decisions += 1
	_add_reward(b, -options.decision_cost)
	if b.sim.sailor_state != WindsurferSim.SailorState.SAILING:
		return  # in the water: the hands have nothing to hold
	b.driver.decide(action, _in_manoeuvre(b))


## One tick of 1/60 s for every board still racing: the sailor's controller (while on the board),
## the physics, the falls; then the race is told where everyone is, and the rewards are counted.
func tick() -> void:
	for i: int in _boards.size():
		var b: Board = _boards[i]
		if b.done:
			continue  # parked: it no longer moves, and earns nothing
		b.since_manoeuvre_s = RaceObservation.advance_since_manoeuvre(b.since_manoeuvre_s, _in_manoeuvre(b), DT)
		if b.sim.sailor_state == WindsurferSim.SailorState.SAILING:
			# The hands first (steering for the wind angle wanted), then the controller reads them.
			b.driver.steer(b.sim.telemetry, _in_manoeuvre(b), DT)
			b.controller.update(b.sim.telemetry, b.controls, DT)
		b.sim.step(DT, b.controls)
		var fallen: bool = b.sim.sailor_state == WindsurferSim.SailorState.FALLEN
		if fallen and not b.was_fallen:
			b.falls += 1
			_add_reward(b, -options.fall_cost)
		elif b.was_fallen and not fallen:
			# Up again after the waterstart: the sail eased and nothing remembered, as in the game.
			b.controller.reset_controls(b.controls)
			b.hands.tack = false
		b.was_fallen = fallen
		race.update_board(i, _where(b))
	var before_gun: bool = race.clock_s() < 0.0
	race.step(DT)
	time_s += DT
	ticks += 1
	for i: int in _boards.size():
		var b: Board = _boards[i]
		if b.done:
			continue
		if before_gun and race.clock_s() >= 0.0 and race.is_ocs(i):
			_add_reward(b, -options.ocs_cost)
		_count_progress(i, b)
		if b.progress_m > b.best_progress_m:
			b.best_progress_m = b.progress_m
			b.best_progress_at_s = time_s
		var stalled: bool = options.stall_s > 0.0 and time_s - b.best_progress_at_s > options.stall_s
		var out: bool = not _bounds.has_point(_where(b))
		b.done = race.is_finished(i) or time_s >= options.episode_s - 0.5 * DT or out or stalled
		if b.done and not race.is_finished(i):
			_charge_the_rest_of_the_time(b)


## The reward board `index` earned since the last call.
func reward(index: int) -> float:
	var b: Board = _boards[index]
	var earned: float = b.pending
	b.pending = 0.0
	return earned


## True once board `index`'s episode is over: finished, the time limit, or out of bounds.
func done(index: int) -> bool:
	return _boards[index].done


## True when every board is done.
func all_done() -> bool:
	for b: Board in _boards:
		if not b.done:
			return false
	return true


## Sails a whole episode for board 0 with one brain, from the state reset() left, and returns the
## reward summed over it (the trainer's fitness).
func run_episode(brain: NeuralNet) -> float:
	var total: float = 0.0
	while not done(0):
		act(0, brain.forward(observe(0)))
		for t: int in decision_ticks:
			tick()
			if done(0):
				break
		total += reward(0)
	return total


# ---------------------------------------------------------------- inside

## A board at rest at a spot, pointing along a heading: the default open-water simulation in this
## environment's wind, with its own copy of the wind's settings (so no two boards share anything
## they write to), and the player's beginner controller with the auto-sheet on, its hands an AI's.
func _make_board(at: Vector2, heading_deg: float) -> Board:
	var b: Board = Board.new()
	b.sim = WindsurferSim.create_default(options.waves)
	var wind_config: WindConfig = b.sim.wind_config.duplicate()
	wind_config.speed_kt = wind_kt
	wind_config.from_bearing_deg = course.axis_deg
	wind_config.gusts_enabled = options.gusts
	wind_config.shifts_enabled = false
	b.sim.wind_config = wind_config
	b.sim.wind = WindField.new(wind_config)
	b.sim.set_waves(options.waves)  # again, so the waves line up with this wind
	b.sim.reset(Vector3(at.x, 0.0, at.y), deg_to_rad(fposmod(heading_deg, 360.0)))
	b.controller = PlayerController.new()
	b.controller.set_sail(b.sim.sail, b.sim.sailor_config, b.sim.air_density_kg_m3)
	b.hands = AiHands.new()
	b.controller.hands = b.hands
	b.driver = LearnedSkipper.Driver.new(b.hands, options.actions)
	b.controls = SimControls.new()
	b.controller.reset_controls(b.controls)
	return b


## The progress reward of one tick: the metres the board came closer to its next step. When it
## completes a step, the distance that step still had at the last tick counts as gained, and the
## next step's distance is counted from here on (so a rounding is not a loss of the whole next leg),
## with the step's bonus on top.
func _count_progress(index: int, b: Board) -> void:
	var steps_now: int = race.next_step_index(index)
	var distance_now_m: float = race.distance_to_next_m(index)
	var gained_m: float = b.last_distance_m - distance_now_m
	if steps_now > b.last_steps:
		gained_m = b.last_distance_m
		_add_reward(b, options.step_bonus * (steps_now - b.last_steps))
		if race.is_finished(index):
			_add_reward(b, options.finish_bonus)
	b.progress_m += gained_m
	_add_reward(b, gained_m * options.progress_per_m)
	b.last_distance_m = distance_now_m
	b.last_steps = steps_now


## The decisions a board out of the race early would still have made before the time limit, each
## at decision_cost (nothing at the time limit itself).
func _charge_the_rest_of_the_time(b: Board) -> void:
	var decision_s: float = decision_ticks * DT
	var left: int = maxi(ceili((options.episode_s - time_s) / decision_s - 0.001), 0)
	_add_reward(b, -options.decision_cost * left)


func _add_reward(b: Board, amount: float) -> void:
	b.pending += amount
	b.total += amount


func _in_manoeuvre(b: Board) -> bool:
	return b.controller.manoeuvre != PlayerController.Manoeuvre.NONE


static func _where(b: Board) -> Vector2:
	var position: Vector3 = b.sim.telemetry.position
	return Vector2(position.x, position.z)
