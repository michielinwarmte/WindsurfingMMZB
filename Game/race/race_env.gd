class_name RaceEnv
extends RefCounted
## One race as a learning environment (RACING_PLAN.md, Part 9C; AI_FLEET_PLAN.md, D6b): the boards,
## their sailors' hands, the race, and the reward that says how well each board is doing. A trainer
## runs it like this:
##
##   env.reset(seed)                                   # or reset_dropped(seed, drops)
##   while not env.done(0):
##       env.act(0, brain.forward(env.observe(0)))     # one decision...
##       for t in env.decision_ticks: env.tick()        # ...held for half a second
##       total += env.reward(0)
##
## (run_episode() does exactly that.) Every board is the open water's simulation, driven through
## the player's beginner controller with the auto-sheet on (RD1); the network's three numbers go
## onto the controller's hands through a LearnedSkipper.Driver, as in the game, so a brain sails here
## as it will there (in the wind-angle mode by default: the first number is the wind angle to hold,
## the third the hold-back speed; see LearnedSkipper). Nothing here is random except through the
## seed, so the same seed and the same actions give the same race, tick for tick.
##
## The reward (D6b: "the candy follows the course"), per board, in metres of sailing distance times
## progress_per_m:
##   + the fall of the sailing distance still to go round the course (SailingDistance.remaining_m:
##     the way to the next step's point, through the steps after it), each tick. Inside the tacking
##     cone that is the speed made good to windward along the course's axis, so going out to a
##     layline pays the same as pointing at the mark; off the laylines it is the closing speed to
##     the mark's rounding point, past the mark on its correct side, not to the mark itself; and a
##     detour never pays, because the sailing distance is a true distance;
##   + rounding_bonus_m for each step completed (the start, each mark, each gate), and finish_bonus_m
##     more at the finish;
##   - manoeuvre_cost_m for each tack and gybe (the speed lost already costs progress; the candy
##     makes the lesson plain early);
##   - fall_cost_m for each fall, ocs_cost_m for being over the line at the gun;
##   - time_cost_m_per_s for every second, so that faster is better.
## Collisions and running aground are not counted (the boards pass through each other).
##
## A board's episode ends when it finishes, at its time limit, when it is more than bounds_margin_m
## from the course, and, if stall_s is set, when it has gained nothing for that long. A board out of
## the race early (out of bounds or stalled) is charged the time it had left: otherwise giving up
## would be cheaper than sailing on. Only finishing early saves time. A board that is done is
## parked (it no longer moves and earns nothing) until respawn() drops it somewhere new, which the
## trainer does between decisions: the race goes on for the others.

const DT: float = 1.0 / 60.0


## The settings of an environment. The defaults are the old stage 1 of the plan's curriculum: one
## lap of T1 from behind the start line, a steady wind, flat water.
class Options:
	## The episode's time limit, seconds from reset (the countdown included).
	var episode_s: float = 240.0
	## The countdown, seconds.
	var prestart_s: float = 10.0
	var laps: int = 1
	## The network decides every this many ticks of 1/60 s (the trainer uses 30: twice a second).
	var decision_ticks: int = LearnedSkipper.DECISION_TICKS
	## How the network's numbers are read: the wind angle to hold, or the stick (LearnedSkipper).
	var actions: LearnedSkipper.ActionMode = LearnedSkipper.ActionMode.TWA
	## Whether the third number is the hold-back speed (the hands' hold-back skill; wind-angle mode).
	var hold: bool = true
	var waves: bool = false
	var gusts: bool = false
	var shifts: bool = false
	## The wind comes from the course's axis turned by this much (degrees): the start line's bias.
	var wind_bias_deg: float = 0.0
	## The boards see no other board (as if alone on the course).
	var blind: bool = false
	## A board further than this from the course's marks is out of the race.
	var bounds_margin_m: float = 1500.0
	## When above 0: a board whose progress (progress_m) has not reached a new best for this many
	## seconds is done.
	var stall_s: float = 0.0
	## reset(): how far behind the middle of the start line the boards wait, metres. The plan's
	## pre-start spot (RaceCourses.pre_start_spot) is 150 m back.
	var start_behind_m: float = RaceCourses.PRE_START_BEHIND_M
	## reset(): the seed moves each board's starting spot along the line by up to this much (and back
	## from it by up to this much, or a quarter of start_behind_m if that is less, so that no board
	## starts over the line), and turns its heading by up to heading_jitter_deg, so a brain does not
	## learn one start by heart.
	var spot_jitter_m: float = 20.0
	var heading_jitter_deg: float = 15.0
	## The reward's weights (above), in metres of sailing distance; progress_per_m turns metres into
	## reward. These are also the personality knobs.
	var progress_per_m: float = 0.01
	var rounding_bonus_m: float = 50.0
	var finish_bonus_m: float = 100.0
	var manoeuvre_cost_m: float = 5.0
	var fall_cost_m: float = 50.0
	var ocs_cost_m: float = 50.0
	var time_cost_m_per_s: float = 2.0


## Where a board is set down: a spot, a heading, and the step of the course it is sailing to (0:
## the start, with the countdown; 1: mark 1, the start behind it; ...).
class Drop:
	var position: Vector2 = Vector2.ZERO
	var heading_deg: float = 0.0
	var next_step: int = 0
	## The episode ends (as a finish, not cut short) once the board has completed the steps before
	## this one: the stage's goal (a drop below a windward mark ends when the mark is rounded). 0
	## or less: only the finish line ends it.
	var goal_step: int = 0

	static func at(spot: Vector2, heading: float, step: int = 0, goal: int = 0) -> Drop:
		var drop: Drop = Drop.new()
		drop.position = spot
		drop.heading_deg = heading
		drop.next_step = step
		drop.goal_step = goal
		return drop


## One board: its simulation, its sailor, and the running sums of its reward.
class Board:
	var sim: WindsurferSim
	var controller: PlayerController
	var hands: AiHands
	## Turns the network's numbers into the hands (LearnedSkipper.Driver).
	var driver: LearnedSkipper.Driver
	## A scripted skipper sailing this board instead of the network (set_scripted()): the yardstick
	## on the same drops, or company in a race. Its own hands; act() leaves it alone.
	var scripted: RaceSkipper = null
	var controls: SimControls
	## The reward earned since the last reward() call.
	var pending: float = 0.0
	## The whole episode's reward so far, and what it is made of.
	var total: float = 0.0
	## The metres of sailing distance gained round the course (the fall of remaining_m).
	var progress_m: float = 0.0
	## The best progress so far, and when it was reached (seconds since reset), for stall_s.
	var best_progress_m: float = 0.0
	var best_progress_at_s: float = 0.0
	var falls: int = 0
	var manoeuvres: int = 0
	var decisions: int = 0
	## The sailing distance still to go at the last tick, and how many steps were done then.
	var remaining_m: float = 0.0
	var last_steps: int = 0
	var was_fallen: bool = false
	var last_manoeuvre: PlayerController.Manoeuvre = PlayerController.Manoeuvre.NONE
	var since_manoeuvre_s: float = RaceObservation.SINCE_MANOEUVRE_SCALE_S
	## When this board's episode began (seconds since reset) and when its time is up, and the step
	## that ends it early (Drop.goal_step; 0 for none).
	var episode_from_s: float = 0.0
	var episode_until_s: float = 0.0
	var goal_step: int = 0
	var done: bool = false
	## Why it is done: it finished, its time ran out (truncated: the episode was cut, not ended),
	## it left the course's bounds, or it stalled.
	var finished: bool = false
	var truncated: bool = false
	var out_of_bounds: bool = false
	var stalled: bool = false

	## How long this episode has run, seconds.
	func episode_s(now_s: float) -> float:
		return now_s - episode_from_s


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
## Where the wind comes from, degrees: the course's axis and the options' bias.
var _wind_from_deg: float = 0.0


func _init(race_course: Course, boards: int = 1, wind_speed_kt: float = 15.0, env_options: Options = null) -> void:
	course = race_course
	_board_count = maxi(boards, 1)
	wind_kt = wind_speed_kt
	options = env_options if env_options != null else Options.new()
	decision_ticks = maxi(options.decision_ticks, 1)
	_bounds = course.bounds().grow(options.bounds_margin_m)
	_wind_from_deg = fposmod(course.axis_deg + options.wind_bias_deg, 360.0)


## A new race: new simulations at the waiting spots behind the start line (spread along it if there
## are several boards, each moved a little by the seed), the countdown, and the race started.
func reset(seed: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var start: RaceStep = RaceSim.new(course, 1, 0.0).steps()[0]
	var along: Vector2 = (start.points[0] - start.points[1]).normalized()
	# Straight back from the middle of the line, away from the course, as RaceCourses' pre-start spot.
	var back: Vector2 = (RaceCourses.pre_start_spot(course) - course.start_middle()).normalized()
	var spot: Vector2 = course.start_middle() + back * options.start_behind_m
	var back_jitter_m: float = minf(options.spot_jitter_m, 0.25 * options.start_behind_m)
	var heading_deg: float = RaceCourses.pre_start_heading_deg(course)
	var line_m: float = start.points[0].distance_to(start.points[1])
	var drops: Array[Drop] = []
	for i: int in _board_count:
		# Several boards wait side by side along the line, so they do not start on top of each other.
		var share: float = (float(i + 1) / (_board_count + 1) - 0.5) if _board_count > 1 else 0.0
		var at: Vector2 = spot + along * (share * line_m + rng.randf_range(-1.0, 1.0) * options.spot_jitter_m)
		at += back * rng.randf_range(-1.0, 1.0) * back_jitter_m
		drops.append(Drop.at(at, heading_deg + rng.randf_range(-1.0, 1.0) * options.heading_jitter_deg, 0))
	reset_dropped(seed, drops)


## A new race with the boards set down where the drops say (one per board; the drops' steps count
## as done: a board dropped on the way to mark 1 has started). The countdown runs if any board still
## has the start to do; otherwise the gun has gone and the clock runs.
func reset_dropped(seed: int, drops: Array[Drop]) -> void:
	var needs_countdown: bool = false
	for drop: Drop in drops:
		if drop.next_step == 0:
			needs_countdown = true
	# The race's own time limit is far away: the episode's limit (done()) ends things first.
	race = RaceSim.new(course, options.laps, options.prestart_s if needs_countdown else 0.0, options.episode_s + 7200.0)
	race.finish_window_s = 7200.0
	time_s = 0.0
	ticks = 0
	_boards.clear()
	_board_count = maxi(drops.size(), 1)
	for i: int in _board_count:
		var drop: Drop = drops[mini(i, drops.size() - 1)]
		var board: Board = _make_board(drop.position, drop.heading_deg, seed + i)
		board.goal_step = drop.goal_step
		_boards.append(board)
		race.add_board("board%d" % (i + 1))
		race.place_board(i, drop.position, drop.next_step)
	race.start()
	for i: int in _boards.size():
		_begin_episode(_boards[i], i)


## Sets a board down somewhere new for a fresh episode in the same race (the trainer, between two
## decisions, once the board is done): a new simulation at the drop, its counters cleared, the drop's
## steps counted as done. The other boards sail on.
func respawn(index: int, drop: Drop, seed: int) -> void:
	var board: Board = _make_board(drop.position, drop.heading_deg, seed)
	board.goal_step = drop.goal_step
	_boards[index] = board
	race.place_board(index, drop.position, drop.next_step)
	_begin_episode(board, index)


## Puts a scripted skipper (Skipper, with a character sheet) on a board in place of the network:
## it sails the same drop, in the same race, through the same hands. The yardstick for a stage
## (the all-rounder on the trainer's drops), or company. Null takes it off again.
func set_scripted(index: int, skipper: RaceSkipper) -> void:
	var b: Board = _boards[index]
	b.scripted = skipper
	if skipper != null:
		skipper.random_seed = index + 1
		skipper.setup(b.sim, b.controller, b.hands, race, index)


func board_count() -> int:
	return _boards.size()


## The board's simulation, its controller and its hands, for the tests and the tools.
func board(index: int) -> Board:
	return _boards[index]


## Where the wind comes from in this race, degrees.
func wind_from_deg() -> float:
	return _wind_from_deg


## What board `index` sees now (RaceObservation).
func observe(index: int) -> PackedFloat32Array:
	var b: Board = _boards[index]
	var positions: PackedVector2Array = PackedVector2Array()
	var velocities: PackedVector2Array = PackedVector2Array()
	if not options.blind:
		for other: int in _boards.size():
			if other == index or _boards[other].done:
				continue
			var t: Telemetry = _boards[other].sim.telemetry
			positions.append(Vector2(t.position.x, t.position.z))
			velocities.append(Course.direction_of(t.heading_deg) * t.speed_ms)
	return RaceObservation.build(b.sim.telemetry, race, index, b.sim.wind, positions, velocities,
			_in_manoeuvre(b), b.since_manoeuvre_s, b.driver.wanted_twa_deg, b.hands.hold_speed_ms)


## A decision for board `index`: the network's three numbers (each -1 to 1) for its hands, held until
## the next decision: the wind angle to hold or the steer, the sheet, and the hold-back speed (or,
## stick mode, the tack).
func act(index: int, action: PackedFloat32Array) -> void:
	var b: Board = _boards[index]
	if b.done or b.scripted != null:
		return
	b.decisions += 1
	if b.sim.sailor_state != WindsurferSim.SailorState.SAILING:
		return  # in the water: the hands have nothing to hold
	b.driver.decide(action, _in_manoeuvre(b))


## One tick of 1/60 s for every board still racing: the sailor's controller (while on the board),
## the physics, the falls and the manoeuvres; then the race is told where everyone is, and the
## rewards are counted.
func tick() -> void:
	for i: int in _boards.size():
		var b: Board = _boards[i]
		if b.done:
			continue  # parked: it no longer moves, and earns nothing
		b.since_manoeuvre_s = RaceObservation.advance_since_manoeuvre(b.since_manoeuvre_s, _in_manoeuvre(b), DT)
		if b.scripted != null:
			# A scripted skipper sets the hands itself, every tick, in the water or not.
			b.scripted.update(b.sim.telemetry, DT)
		if b.sim.sailor_state == WindsurferSim.SailorState.SAILING:
			# The hands first (steering for the wind angle wanted), then the controller reads them.
			if b.scripted == null:
				b.driver.steer(b.sim.telemetry, _in_manoeuvre(b), DT)
			b.controller.update(b.sim.telemetry, b.controls, DT)
		var manoeuvre: PlayerController.Manoeuvre = b.controller.manoeuvre
		if manoeuvre != PlayerController.Manoeuvre.NONE and b.last_manoeuvre == PlayerController.Manoeuvre.NONE:
			b.manoeuvres += 1
			_add_metres(b, -options.manoeuvre_cost_m)
		b.last_manoeuvre = manoeuvre
		b.sim.step(DT, b.controls)
		var fallen: bool = b.sim.sailor_state == WindsurferSim.SailorState.FALLEN
		if fallen and not b.was_fallen:
			b.falls += 1
			_add_metres(b, -options.fall_cost_m)
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
			_add_metres(b, -options.ocs_cost_m)
		_add_metres(b, -options.time_cost_m_per_s * DT)
		_count_progress(i, b)
		if b.progress_m > b.best_progress_m:
			b.best_progress_m = b.progress_m
			b.best_progress_at_s = time_s
		b.finished = race.is_finished(i) or (b.goal_step > 0 and race.next_step_index(i) >= b.goal_step)
		b.stalled = options.stall_s > 0.0 and time_s - b.best_progress_at_s > options.stall_s
		b.out_of_bounds = not _bounds.has_point(_where(b))
		b.truncated = not b.finished and not b.stalled and not b.out_of_bounds and time_s >= b.episode_until_s - 0.5 * DT
		b.done = b.finished or b.truncated or b.out_of_bounds or b.stalled
		if b.out_of_bounds or b.stalled:
			_charge_the_rest_of_the_time(b)


## The reward board `index` earned since the last call.
func reward(index: int) -> float:
	var b: Board = _boards[index]
	var earned: float = b.pending
	b.pending = 0.0
	return earned


## True once board `index`'s episode is over: finished, the time limit, out of bounds, or stalled.
func done(index: int) -> bool:
	return _boards[index].done


## True when every board is done.
func all_done() -> bool:
	for b: Board in _boards:
		if not b.done:
			return false
	return true


## What a trainer wants to know about a board's episode so far, as plain data.
func info(index: int) -> Dictionary:
	var b: Board = _boards[index]
	return {
		"steps_done": race.next_step_index(index),
		"steps_total": race.steps().size(),
		"finished": b.finished,
		"finish_s": race.finish_time_s(index),
		"goal_step": b.goal_step,
		"splits": Array(race.splits_s(index)),
		"truncated": b.truncated,
		"out_of_bounds": b.out_of_bounds,
		"stalled": b.stalled,
		"falls": b.falls,
		"manoeuvres": b.manoeuvres,
		"progress_m": snappedf(b.progress_m, 0.1),
		"remaining_m": snappedf(b.remaining_m, 0.1),
		"episode_s": snappedf(b.episode_s(time_s), 0.1),
		"total": snappedf(b.total, 0.001),
	}


## Sails a whole episode for board 0 with one brain, from the state reset() left, and returns the
## reward summed over it (the trainer's fitness). The brain's inputs are picked by name from the
## observation, so a brain from before an input was added still sails.
func run_episode(brain: NeuralNet) -> float:
	var total: float = 0.0
	var names: PackedStringArray = RaceObservation.names()
	while not done(0):
		act(0, brain.forward(brain.select_inputs(observe(0), names)))
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
func _make_board(at: Vector2, heading_deg: float, _seed: int) -> Board:
	var b: Board = Board.new()
	b.sim = WindsurferSim.create_default(options.waves)
	var wind_config: WindConfig = b.sim.wind_config.duplicate()
	wind_config.speed_kt = wind_kt
	wind_config.from_bearing_deg = _wind_from_deg
	wind_config.gusts_enabled = options.gusts
	wind_config.shifts_enabled = options.shifts
	b.sim.wind_config = wind_config
	b.sim.wind = WindField.new(wind_config)
	b.sim.set_waves(options.waves)  # again, so the waves line up with this wind
	b.sim.reset(Vector3(at.x, 0.0, at.y), deg_to_rad(fposmod(heading_deg, 360.0)))
	b.controller = PlayerController.new()
	b.controller.set_sail(b.sim.sail, b.sim.sailor_config, b.sim.air_density_kg_m3)
	b.hands = AiHands.new()
	b.controller.hands = b.hands
	b.driver = LearnedSkipper.Driver.new(b.hands, options.actions)
	b.driver.uses_hold = options.hold and options.actions == LearnedSkipper.ActionMode.TWA
	b.controls = SimControls.new()
	b.controller.reset_controls(b.controls)
	return b


## A board's episode begins where it is: the yardstick set to the distance it has to go.
func _begin_episode(b: Board, index: int) -> void:
	b.episode_from_s = time_s
	b.episode_until_s = time_s + options.episode_s
	b.remaining_m = SailingDistance.remaining_m(race, index, _where(b), course.axis_deg)
	b.last_steps = race.next_step_index(index)
	b.best_progress_at_s = time_s


## The progress reward of one tick: the fall of the sailing distance still to go. Completing a step
## is counted through the same number (it can only ever shorten the way, by what the board saved by
## crossing where it did), plus the step's bonus.
func _count_progress(index: int, b: Board) -> void:
	var steps_now: int = race.next_step_index(index)
	var remaining_now: float = SailingDistance.remaining_m(race, index, _where(b), course.axis_deg)
	var gained_m: float = b.remaining_m - remaining_now
	if steps_now > b.last_steps:
		_add_metres(b, options.rounding_bonus_m * (steps_now - b.last_steps))
		if race.is_finished(index):
			_add_metres(b, options.finish_bonus_m)
	b.progress_m += gained_m
	_add_metres(b, gained_m)
	b.remaining_m = remaining_now
	b.last_steps = steps_now


## The seconds a board out of the race early would still have sailed before its time limit, each at
## the time cost (nothing at the time limit itself).
func _charge_the_rest_of_the_time(b: Board) -> void:
	_add_metres(b, -options.time_cost_m_per_s * maxf(b.episode_until_s - time_s, 0.0))


func _add_metres(b: Board, metres: float) -> void:
	var amount: float = metres * options.progress_per_m
	b.pending += amount
	b.total += amount


func _in_manoeuvre(b: Board) -> bool:
	return b.controller.manoeuvre != PlayerController.Manoeuvre.NONE


static func _where(b: Board) -> Vector2:
	var position: Vector3 = b.sim.telemetry.position
	return Vector2(position.x, position.z)
