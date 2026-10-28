extends GutTest
## RaceEnv, a race as a learning environment (RACING_PLAN.md, Part 9C; AI_FLEET_PLAN.md, D6b): what
## a board sees stays within -3 and 3; the progress reward is the fall of the sailing distance still
## to go round the course, in metres / 100, so a detour pays nothing and a completed step pays its
## bonus and never a loss; a tack costs 5 m, a fall 50, being over the line at the gun 50, and every
## second 2; the same seed and the same actions give the same rewards; an episode ends at the time
## limit, far from the course, or (if asked) when the board stops gaining; a board can be dropped
## at any step of the course and respawned for a new episode in the same race; and a hand-written
## wind-angle policy, answering as a network does in the "twa" mode, starts and rounds mark 1 within
## 240 s (the ceiling a learner chases).
##
## The course is T1 for a wind from the west (270): the start line runs north and south through
## the origin, mark 1 lies 556 m to the west, and the boards wait 150 m east of the line, heading
## south on a beam reach (starboard tack).

const DT: float = 1.0 / 60.0
## Starboard tack, 60 degrees off the wind from the west: toward the start line on a close reach.
const CLOSE_REACH_DEG: float = 210.0
## Starboard tack, 45 degrees off the wind: close-hauled, the quickest way up to the line.
const CLOSE_HAULED_DEG: float = 225.0


static func _course() -> Course:
	return RaceCourses.t1_loop(270.0, Vector2.ZERO)


## Options with only the parts of the reward a test looks at, and the stick mode, so that the action
## [0, 0, 0] lets go of the stick and the controller holds the heading.
static func _options(progress: bool, time: bool) -> RaceEnv.Options:
	var options: RaceEnv.Options = RaceEnv.Options.new()
	options.actions = LearnedSkipper.ActionMode.STICK
	options.progress_per_m = 0.01
	if not progress:
		options.rounding_bonus_m = 0.0
		options.finish_bonus_m = 0.0
	options.time_cost_m_per_s = 2.0 if time else 0.0
	return options


## Points board 0 along a heading where it is (at rest, as reset() left it).
static func _point(env: RaceEnv, heading_deg: float) -> void:
	var sim: WindsurferSim = env.board(0).sim
	sim.reset(sim.telemetry.position, deg_to_rad(heading_deg))


## One decision and the ticks it is held for; returns the reward.
static func _decide(env: RaceEnv, action: PackedFloat32Array) -> float:
	env.act(0, action)
	for t: int in env.decision_ticks:
		env.tick()
	return env.reward(0)


static func _remaining(env: RaceEnv) -> float:
	var p: Vector3 = env.board(0).sim.telemetry.position
	return SailingDistance.remaining_m(env.race, 0, Vector2(p.x, p.z), env.course.axis_deg)


func test_every_observation_stays_within_minus_3_and_3_over_60_s_with_a_constant_action() -> void:
	# The stick: a steady turn, the sheet pulled in by hand, and the tack output held high.
	_check_the_observation_over_60_s(LearnedSkipper.ActionMode.STICK, PackedFloat32Array([0.4, 0.8, 1.0]))
	# The wind angle: 45 degrees on starboard, the sheet pulled in by hand, holding back a little.
	_check_the_observation_over_60_s(LearnedSkipper.ActionMode.TWA, PackedFloat32Array([0.25, 0.8, 0.3]))


func _check_the_observation_over_60_s(mode: LearnedSkipper.ActionMode, action: PackedFloat32Array) -> void:
	var options: RaceEnv.Options = RaceEnv.Options.new()
	options.episode_s = 70.0
	options.actions = mode
	var env: RaceEnv = RaceEnv.new(_course(), 1, 15.0, options)
	env.reset(3)
	var names: PackedStringArray = RaceObservation.names()
	var worst: float = 0.0
	var worst_name: String = ""
	while env.time_s < 60.0:
		var observation: PackedFloat32Array = env.observe(0)
		assert_eq(observation.size(), names.size())
		for k: int in observation.size():
			if absf(observation[k]) > worst:
				worst = absf(observation[k])
				worst_name = names[k]
			if is_nan(observation[k]):
				fail_test("%s is not a number" % names[k])
				return
		_decide(env, action)
	assert_true(worst <= 3.0, "every number stays within -3 and 3 (the largest is %s at %.2f)" % [worst_name, worst])


func test_the_progress_reward_is_the_fall_of_the_sailing_distance_still_to_go_over_100() -> void:
	var options: RaceEnv.Options = _options(true, false)
	options.prestart_s = 30.0
	var env: RaceEnv = RaceEnv.new(_course(), 1, 15.0, options)
	env.reset(1)
	_point(env, CLOSE_REACH_DEG)
	var at_start_m: float = _remaining(env)
	var total: float = 0.0
	while env.time_s < 15.0:
		total += _decide(env, PackedFloat32Array([0.0, 0.0, 0.0]))  # hold the heading
	var gained_m: float = at_start_m - _remaining(env)
	assert_eq(env.race.next_step_index(0), 0, "still sailing to the start line")
	assert_true(gained_m > 10.0, "the board came closer to the course: %.1f m" % gained_m)
	assert_almost_eq(total, gained_m / 100.0, 1e-3, "the reward is the metres gained / 100")
	assert_almost_eq(env.board(0).progress_m, gained_m, 1e-2)


func test_a_detour_pays_nothing_the_progress_is_the_same_whichever_way() -> void:
	# Two boards on the same race: one holds its heading, the other weaves. Each one's progress is
	# exactly the fall of its own remaining distance: the way between two places is what it is.
	var options: RaceEnv.Options = _options(true, false)
	options.prestart_s = 60.0
	var env: RaceEnv = RaceEnv.new(_course(), 2, 15.0, options)
	env.reset(2)
	var before: PackedFloat32Array = PackedFloat32Array()
	for i: int in 2:
		var p: Vector3 = env.board(i).sim.telemetry.position
		before.append(SailingDistance.remaining_m(env.race, i, Vector2(p.x, p.z), env.course.axis_deg))
	for k: int in 120:
		env.act(0, PackedFloat32Array([0.0, 0.0, 0.0]))
		env.act(1, PackedFloat32Array([0.6 * sin(k * 0.3), 0.0, 0.0]))
		for t: int in env.decision_ticks:
			env.tick()
	for i: int in 2:
		var p: Vector3 = env.board(i).sim.telemetry.position
		var now: float = SailingDistance.remaining_m(env.race, i, Vector2(p.x, p.z), env.course.axis_deg)
		assert_almost_eq(env.board(i).progress_m, before[i] - now, 0.05, "board %d: progress is the fall of its remaining distance" % i)


func test_a_completed_step_earns_its_bonus_and_never_a_loss() -> void:
	var options: RaceEnv.Options = _options(true, false)
	options.prestart_s = 0.0
	options.start_behind_m = 10.0  # close enough to reach the 60 m line close-hauled
	options.spot_jitter_m = 0.0
	options.heading_jitter_deg = 0.0
	var env: RaceEnv = RaceEnv.new(_course(), 1, 15.0, options)
	env.reset(1)
	_point(env, CLOSE_HAULED_DEG)
	var crossing_reward: float = 0.0
	var remaining_before: float = 0.0
	var remaining_after: float = 0.0
	while env.time_s < 30.0 and env.race.next_step_index(0) == 0:
		if env.ticks % env.decision_ticks == 0:
			env.act(0, PackedFloat32Array([0.0, 0.0, 0.0]))
		remaining_before = _remaining(env)
		env.tick()
		var earned: float = env.reward(0)
		if env.race.next_step_index(0) == 1:
			crossing_reward = earned
			remaining_after = _remaining(env)
	assert_eq(env.race.next_step_index(0), 1, "the board started")
	# The tick of the crossing earns the bonus (50 m) and the metres of that tick; the 556 m to
	# mark 1 that now lie ahead were in the yardstick all along, so they are no loss.
	assert_true(crossing_reward >= 0.5, "50 m for the start and the tick's progress: %.3f" % crossing_reward)
	assert_true(crossing_reward < 0.6, "and no windfall: %.3f" % crossing_reward)
	assert_true(remaining_after <= remaining_before + 1e-3, "the remaining distance did not grow at the crossing")
	assert_false(env.race.is_ocs(0))


func test_a_tack_costs_5_m() -> void:
	var options: RaceEnv.Options = _options(false, false)
	options.actions = LearnedSkipper.ActionMode.TWA
	options.prestart_s = 60.0
	var env: RaceEnv = RaceEnv.new(_course(), 1, 15.0, options)
	env.reset(1)
	# Close-hauled on starboard for 20 s, then the other tack asked for.
	var progress: float = 0.0
	for k: int in 40:
		progress += _decide(env, PackedFloat32Array([0.25, 0.0, 0.0]))
	var board: RaceEnv.Board = env.board(0)
	assert_eq(board.manoeuvres, 0)
	var manoeuvres_seen: int = 0
	var cost_tick: float = 0.0
	for k: int in 300:
		env.act(0, PackedFloat32Array([-0.25, 0.0, 0.0]))
		for t: int in env.decision_ticks:
			var before: int = board.manoeuvres
			env.tick()
			if board.manoeuvres > before:
				manoeuvres_seen += 1
				cost_tick = env.reward(0)
			else:
				env.reward(0)
		if manoeuvres_seen > 0:
			break
	assert_eq(manoeuvres_seen, 1, "one tack")
	# The tick of the tack: 5 m less, and whatever the board gained or lost in that tick (a bit).
	assert_almost_eq(cost_tick, -0.05, 0.01, "5 m for the tack")


func test_a_fall_costs_50_m() -> void:
	var env: RaceEnv = RaceEnv.new(_course(), 1, 15.0, _options(false, false))
	env.reset(1)
	for t: int in 30:
		env.tick()
	env.reward(0)
	env.board(0).sim.force_fall("catapult")
	env.tick()
	var earned: float = env.reward(0)
	assert_almost_eq(earned, -0.5, 0.01, "the fall (and the tick's progress, a bit)")
	assert_eq(env.board(0).falls, 1)
	for t: int in 60:
		env.tick()
	assert_true(env.reward(0) > -0.1, "a fall is counted once")


func test_being_over_the_line_at_the_gun_costs_50_m() -> void:
	var options: RaceEnv.Options = _options(false, false)
	options.prestart_s = 2.0
	options.start_behind_m = -15.0  # waiting on the course side of the line
	var env: RaceEnv = RaceEnv.new(_course(), 1, 15.0, options)
	env.reset(1)
	var total: float = 0.0
	while env.time_s < 4.0:
		total += _decide(env, PackedFloat32Array([0.0, 0.0, 0.0]))
	assert_true(env.race.is_ocs(0), "over the line at the gun")
	assert_almost_eq(total - env.board(0).progress_m / 100.0, -0.5, 1e-3, "OCS costs 50 m, once")


func test_each_second_costs_2_m() -> void:
	var options: RaceEnv.Options = _options(false, true)
	options.progress_per_m = 0.01
	var env: RaceEnv = RaceEnv.new(_course(), 1, 15.0, options)
	env.reset(1)
	var total: float = 0.0
	for k: int in 10:
		total += _decide(env, PackedFloat32Array([0.0, 0.0, 0.0]))
	var seconds: float = 10.0 * env.decision_ticks * DT
	assert_almost_eq(total - env.board(0).progress_m / 100.0, -0.02 * seconds, 1e-4)
	assert_eq(env.board(0).decisions, 10)


func test_the_same_seed_and_the_same_actions_give_the_same_rewards() -> void:
	for mode: LearnedSkipper.ActionMode in [LearnedSkipper.ActionMode.TWA, LearnedSkipper.ActionMode.STICK]:
		var first: PackedFloat32Array = _rewards_of_a_scripted_race(42, mode)
		var second: PackedFloat32Array = _rewards_of_a_scripted_race(42, mode)
		assert_eq(first.size(), second.size())
		assert_eq(first, second, "tick for tick the same race (%s)" % LearnedSkipper.mode_name(mode))
	var other_seed: PackedFloat32Array = _rewards_of_a_scripted_race(43, LearnedSkipper.ActionMode.TWA)
	assert_ne(_rewards_of_a_scripted_race(42, LearnedSkipper.ActionMode.TWA), other_seed, "another seed is another start")


## 20 s of a race with a fixed sequence of actions: a slow weave (in the wind-angle mode, a wind
## angle swinging from one tack to the other), and a tack asked for twice.
static func _rewards_of_a_scripted_race(seed: int, mode: LearnedSkipper.ActionMode) -> PackedFloat32Array:
	var options: RaceEnv.Options = RaceEnv.Options.new()
	options.actions = mode
	var env: RaceEnv = RaceEnv.new(_course(), 1, 15.0, options)
	env.reset(seed)
	var rewards: PackedFloat32Array = PackedFloat32Array()
	for k: int in 200:
		var tack: float = 1.0 if k % 80 == 40 else -1.0
		rewards.append(_decide(env, PackedFloat32Array([0.5 * sin(k * 0.1), 0.0, tack])))
	return rewards


func test_an_episode_ends_at_the_time_limit_and_the_board_is_parked() -> void:
	var options: RaceEnv.Options = RaceEnv.Options.new()
	options.episode_s = 2.0
	var env: RaceEnv = RaceEnv.new(_course(), 1, 15.0, options)
	env.reset(1)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2
	var brain: NeuralNet = NeuralNet.make([RaceObservation.size(), 8, 3], rng)
	var total: float = env.run_episode(brain)
	assert_true(env.done(0))
	assert_true(env.board(0).truncated, "cut by the time limit, not ended")
	assert_almost_eq(env.time_s, 2.0, DT, "it ran to the time limit")
	assert_almost_eq(total, env.board(0).total, 1e-4, "run_episode() returns the episode's reward")
	var parked_at: Vector3 = env.board(0).sim.telemetry.position
	env.tick()
	assert_eq(env.board(0).sim.telemetry.position, parked_at, "a board that is done no longer moves")
	assert_eq(env.reward(0), 0.0, "and earns nothing")


func test_a_board_far_from_the_course_is_done() -> void:
	var options: RaceEnv.Options = RaceEnv.Options.new()
	options.start_behind_m = 1700.0  # 1700 m east of the line: more than 1.5 km from every mark
	var env: RaceEnv = RaceEnv.new(_course(), 1, 15.0, options)
	env.reset(1)
	env.tick()
	assert_true(env.done(0))
	assert_true(env.board(0).out_of_bounds)
	assert_false(env.board(0).truncated)
	# Out early, it pays for the time it would have sailed to the limit (240 s at 2 m a second):
	# giving up must not be cheaper than sailing on.
	assert_almost_eq(env.reward(0) - env.board(0).progress_m / 100.0, -0.02 * 240.0, 0.05, "the rest of the time is charged")


func test_a_board_that_stops_gaining_is_done_when_asked() -> void:
	var options: RaceEnv.Options = RaceEnv.Options.new()
	options.actions = LearnedSkipper.ActionMode.STICK
	options.stall_s = 3.0
	var env: RaceEnv = RaceEnv.new(_course(), 1, 15.0, options)
	env.reset(1)
	_point(env, 180.0)  # a beam reach along the line, never closer to it
	while not env.done(0) and env.time_s < 20.0:
		_decide(env, PackedFloat32Array([0.0, 0.0, 0.0]))
	assert_true(env.done(0), "done")
	assert_true(env.board(0).stalled)
	assert_true(env.time_s < 10.0, "a few seconds after it stopped gaining: %.1f s" % env.time_s)


func test_a_dropped_board_starts_at_its_step_and_a_respawn_begins_a_new_episode() -> void:
	var options: RaceEnv.Options = RaceEnv.Options.new()
	options.actions = LearnedSkipper.ActionMode.TWA
	options.episode_s = 60.0
	options.prestart_s = 30.0
	var course: Course = _course()
	var env: RaceEnv = RaceEnv.new(course, 2, 15.0, options)
	var mark1: Vector2 = course.mark("1").position
	# Board 0 dropped 300 m east (downwind) of mark 1 on its way to it, the start behind it; board 1
	# at the pre-start spot with the start still to do.
	var drops: Array[RaceEnv.Drop] = [RaceEnv.Drop.at(mark1 + Vector2(300.0, 0.0), 225.0, 1),
		RaceEnv.Drop.at(RaceCourses.pre_start_spot(course), 180.0, 0)]
	env.reset_dropped(4, drops)
	assert_eq(env.race.next_step_index(0), 1, "board 0 is sailing to mark 1")
	assert_eq(env.race.next_step_index(1), 0, "board 1 has the start to do")
	assert_almost_eq(env.race.clock_s(), -30.0, 1e-3, "the countdown runs for board 1")
	var p: Vector3 = env.board(0).sim.telemetry.position
	assert_almost_eq(Vector2(p.x, p.z).distance_to(drops[0].position), 0.0, 0.5, "where it was dropped")
	for k: int in 100:
		env.act(0, PackedFloat32Array([0.25, 0.0, 0.0]))
		for t: int in env.decision_ticks:
			env.tick()
	# From a standstill, upwind in 15 kt: over 10 m on 0.1's sail, 7 m on the sail measured in the
	# wind tunnel (PH28), until the hull (PH16) wins the speed back.
	assert_true(env.board(0).progress_m > 5.0, "it sailed toward mark 1 in 10 s: %.0f m" % env.board(0).progress_m)
	assert_true(env.board(0).decisions == 100)
	# Dropped again, 200 m south of mark 1: a fresh board, its counters cleared, the race going on.
	var again: RaceEnv.Drop = RaceEnv.Drop.at(mark1 + Vector2(0.0, 200.0), 270.0, 1)
	var clock_before: float = env.race.clock_s()
	env.respawn(0, again, 9)
	p = env.board(0).sim.telemetry.position
	assert_almost_eq(Vector2(p.x, p.z).distance_to(again.position), 0.0, 0.5, "at the new drop")
	assert_eq(env.board(0).decisions, 0)
	assert_eq(env.board(0).progress_m, 0.0)
	assert_false(env.done(0))
	assert_almost_eq(env.board(0).episode_until_s, env.time_s + 60.0, 1e-3, "a new episode's time")
	assert_eq(env.race.clock_s(), clock_before, "the race clock is not touched")
	env.tick()
	assert_true(absf(env.reward(0)) < 0.1, "no windfall and no loss at the respawn")
	# With no board still to start, a dropped race has no countdown.
	var started: Array[RaceEnv.Drop] = [RaceEnv.Drop.at(mark1 + Vector2(300.0, 0.0), 225.0, 1)]
	env.reset_dropped(5, started)
	assert_eq(env.race.clock_s(), 0.0, "the gun has gone")


func test_with_the_shadows_on_a_board_in_anothers_wind_shadow_is_slower() -> void:
	# Two boards dropped close-hauled on starboard with the wind from the west: the second 6 m
	# east (downwind) of the first, in its shadow. 30 s later it is the slower one when the shadows
	# are on, and as fast when they are off.
	var speeds: Array[float] = []
	for shadows: bool in [false, true]:
		var options: RaceEnv.Options = RaceEnv.Options.new()
		options.actions = LearnedSkipper.ActionMode.TWA
		options.shadows = shadows
		options.prestart_s = 60.0
		var env: RaceEnv = RaceEnv.new(_course(), 2, 15.0, options)
		var spot: Vector2 = RaceCourses.pre_start_spot(_course())
		var drops: Array[RaceEnv.Drop] = [RaceEnv.Drop.at(spot, CLOSE_HAULED_DEG, 0), RaceEnv.Drop.at(spot + Vector2(6.0, 0.0), CLOSE_HAULED_DEG, 0)]
		env.reset_dropped(7, drops)
		assert_eq(env.board(1).shadows != null, shadows, "the shadows are there when asked")
		for k: int in 60:
			for i: int in 2:
				env.act(i, PackedFloat32Array([0.25, 0.0, 0.0]))
			for t: int in env.decision_ticks:
				env.tick()
		speeds.append(env.board(1).sim.telemetry.speed_ms - env.board(0).sim.telemetry.speed_ms)
		if shadows:
			var wind_at_sail: float = env.board(1).sim.sail.true_wind_at_ce_world.length()
			var clear_wind: float = env.board(0).sim.sail.true_wind_at_ce_world.length()
			assert_true(wind_at_sail < 0.95 * clear_wind, "less wind at the shadowed sail: %.2f against %.2f m/s" % [wind_at_sail, clear_wind])
	assert_true(absf(speeds[0]) < 0.2, "without shadows the two are as fast: %.2f m/s apart" % speeds[0])
	assert_true(speeds[1] < speeds[0] - 0.1, "in the shadow the second board is slower: %.2f m/s against %.2f without shadows" % [speeds[1], speeds[0]])


# ---------------------------------------------------------------- the ceiling: a hand-written wind-angle policy

## Close-hauled at this angle, broad reaching at RUN_TWA_DEG, and the other tack once the aim is this far
## past the wind on the other side (a little past the layline, for the leeway and the tack).
const BEAT_TWA_DEG: float = 45.0
const RUN_TWA_DEG: float = 150.0
const LAYLINE_DEG: float = 48.0


func test_a_hand_written_wind_angle_policy_starts_and_rounds_mark_1_within_270_s() -> void:
	var options: RaceEnv.Options = RaceEnv.Options.new()
	options.actions = LearnedSkipper.ActionMode.TWA
	options.start_behind_m = 25.0
	options.prestart_s = 5.0
	# 0.1's sail reached mark 1 inside the training's 240 s episode; the sail measured in the wind
	# tunnel (PH28) beats about 2 % slower in 15 kt and needs 245 s, until the hull (PH16) wins the
	# speed back. The training's episodes (RaceEnv.Options.episode_s) are for RA to check.
	options.episode_s = 270.0
	var env: RaceEnv = RaceEnv.new(_course(), 1, 15.0, options)
	env.reset(3)
	var tack: Array[float] = [0.0]  # the policy's own memory: the tack it means to be on
	while not env.done(0) and env.race.next_step_index(0) < 2:
		_decide(env, _wind_angle_policy(env, tack))
	var splits: PackedFloat32Array = env.race.splits_s(0)
	assert_eq(env.race.next_step_index(0), 2, "started and rounded mark 1")
	assert_eq(env.board(0).falls, 0, "without a fall")
	if splits.size() >= 2:
		gut.p("The wind-angle policy: start at %.1f s, mark 1 at %.1f s of race time (%.1f s after reset), reward %.2f" % [splits[0], splits[1], env.time_s, env.board(0).total])
		assert_true(env.time_s < 270.0, "within the 270 s of this episode: %.1f s" % env.time_s)


## Through act() as a network in the wind-angle mode answers: the wind angle to hold / 180. Upwind
## (start line, mark 1): close-hauled on the tack it is on, the other tack once the aim is past the
## layline, straight at the aim when it can be reached without beating. Downwind: RUN_TWA_DEG.
static func _wind_angle_policy(env: RaceEnv, tack: Array[float]) -> PackedFloat32Array:
	var t: Telemetry = env.board(0).sim.telemetry
	var here: Vector2 = Vector2(t.position.x, t.position.z)
	var step: RaceStep = env.race.next_step(0)
	if tack[0] == 0.0:
		tack[0] = LearnedSkipper.tack_of(t)
	# A mark is rounded 20 m outside it; a line crossed at least 10 m inside its ends.
	var aim: Vector2 = step.target()
	if step.kind == RaceStep.Kind.MARK:
		aim = step.points[0] + RoundingCheck.rounding_ray(step.in_dir, step.out_dir, step.side) * 20.0
	else:
		var inset: Vector2 = (step.points[1] - step.points[0]).normalized() * 10.0
		aim = Geometry2D.get_closest_point_to_segment(here, step.points[0] + inset, step.points[1] - inset)
	# Where the aim is from the wind: 0 straight upwind, positive to the right looking upwind.
	var from_wind_deg: float = Course.turn_deg(t.wind_from_bearing_deg, Course.bearing_deg(here, aim))
	var wanted_deg: float = RUN_TWA_DEG * tack[0]
	if absf(from_wind_deg) <= 90.0:
		# On starboard tack the board heads 45 degrees left of the wind; once the aim lies more than
		# LAYLINE_DEG to the right, port tack fetches it, and the other way round.
		if tack[0] > 0.0 and from_wind_deg > LAYLINE_DEG:
			tack[0] = -1.0
		elif tack[0] < 0.0 and from_wind_deg < -LAYLINE_DEG:
			tack[0] = 1.0
		wanted_deg = BEAT_TWA_DEG * tack[0]
		if absf(from_wind_deg) > BEAT_TWA_DEG + 10.0:
			# Reachable without beating: the wind angle that points at it (the wind from starboard is
			# the wind clockwise of the bow, so that angle is minus the aim's angle from the wind).
			wanted_deg = -from_wind_deg
	return PackedFloat32Array([wanted_deg / LearnedSkipper.TWA_FULL_SCALE_DEG, 0.0, 0.0])
