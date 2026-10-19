extends GutTest
## RaceEnv, a race as a learning environment (RACING_PLAN.md, Part 9C): what a board sees stays
## within -3 and 3; the progress reward is the metres gained toward the next step / 100, and a step
## completed is not counted as a loss of the next leg; a fall costs 20 and being over the line at
## the gun 10; the same seed and the same actions give the same rewards; and an episode ends at the
## time limit, far from the course, or (if asked) when the board stops gaining.
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


## Options with only the parts of the reward a test looks at.
static func _options(progress: bool, decisions: bool) -> RaceEnv.Options:
	var options: RaceEnv.Options = RaceEnv.Options.new()
	options.progress_per_m = 0.01 if progress else 0.0
	options.decision_cost = 0.01 if decisions else 0.0
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


func test_every_observation_stays_within_minus_3_and_3_over_60_s_with_a_constant_action() -> void:
	var options: RaceEnv.Options = RaceEnv.Options.new()
	options.episode_s = 70.0
	var env: RaceEnv = RaceEnv.new(_course(), 1, 15.0, options)
	env.reset(3)
	# A steady turn, the sheet pulled in by hand, and the tack output held high.
	var action: PackedFloat32Array = PackedFloat32Array([0.4, 0.8, 1.0])
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


func test_the_progress_reward_is_the_metres_gained_toward_the_next_step_over_100() -> void:
	var options: RaceEnv.Options = _options(true, false)
	options.prestart_s = 30.0
	var env: RaceEnv = RaceEnv.new(_course(), 1, 15.0, options)
	env.reset(1)
	_point(env, CLOSE_REACH_DEG)
	var start_m: float = env.race.distance_to_next_m(0)
	var total: float = 0.0
	while env.time_s < 15.0:
		total += _decide(env, PackedFloat32Array([0.0, 0.0, 0.0]))  # hold the heading
	var gained_m: float = start_m - env.race.distance_to_next_m(0)
	assert_eq(env.race.next_step_index(0), 0, "still sailing to the start line")
	assert_true(gained_m > 10.0, "the board came closer to the line: %.1f m" % gained_m)
	assert_almost_eq(total, gained_m / 100.0, 1e-4, "the reward is the metres gained / 100")
	assert_almost_eq(env.board(0).progress_m, gained_m, 1e-3)


func test_a_completed_step_earns_its_bonus_and_the_next_leg_is_not_a_loss() -> void:
	var options: RaceEnv.Options = _options(true, false)
	options.prestart_s = 0.0
	options.start_behind_m = 10.0  # close enough to reach the 60 m line close-hauled
	options.spot_jitter_m = 0.0
	options.heading_jitter_deg = 0.0
	var env: RaceEnv = RaceEnv.new(_course(), 1, 15.0, options)
	env.reset(1)
	_point(env, CLOSE_HAULED_DEG)
	var at_start: float = 0.0
	var crossing_reward: float = 0.0
	while env.time_s < 30.0 and env.race.next_step_index(0) == 0:
		if env.ticks % env.decision_ticks == 0:
			env.act(0, PackedFloat32Array([0.0, 0.0, 0.0]))
		var distance_before_m: float = env.race.distance_to_next_m(0)
		env.tick()
		var earned: float = env.reward(0)
		if env.race.next_step_index(0) == 1:
			crossing_reward = earned
			at_start = distance_before_m
	assert_eq(env.race.next_step_index(0), 1, "the board started")
	# The tick of the crossing earns the bonus and the last metres to the line; the 556 m to mark 1
	# that now lie ahead are not a loss.
	assert_almost_eq(crossing_reward, 50.0 + at_start / 100.0, 1e-4, "50 for the start and the last metres")
	assert_false(env.race.is_ocs(0))


func test_a_fall_costs_20() -> void:
	var env: RaceEnv = RaceEnv.new(_course(), 1, 15.0, _options(false, false))
	env.reset(1)
	for t: int in 30:
		env.tick()
	assert_eq(env.reward(0), 0.0, "nothing earned with only the fall counted")
	env.board(0).sim.force_fall("catapult")
	env.tick()
	assert_eq(env.reward(0), -20.0, "the fall")
	assert_eq(env.board(0).falls, 1)
	for t: int in 60:
		env.tick()
	assert_eq(env.reward(0), 0.0, "a fall is counted once")


func test_being_over_the_line_at_the_gun_costs_10() -> void:
	var options: RaceEnv.Options = _options(false, false)
	options.prestart_s = 2.0
	options.start_behind_m = -15.0  # waiting on the course side of the line
	var env: RaceEnv = RaceEnv.new(_course(), 1, 15.0, options)
	env.reset(1)
	var total: float = 0.0
	while env.time_s < 4.0:
		total += _decide(env, PackedFloat32Array([0.0, 0.0, 0.0]))
	assert_true(env.race.is_ocs(0), "over the line at the gun")
	assert_eq(total, -10.0, "OCS costs 10, once")


func test_each_decision_costs_a_hundredth() -> void:
	var env: RaceEnv = RaceEnv.new(_course(), 1, 15.0, _options(false, true))
	env.reset(1)
	var total: float = 0.0
	for k: int in 10:
		total += _decide(env, PackedFloat32Array([0.0, 0.0, 0.0]))
	assert_almost_eq(total, -0.1, 1e-6)
	assert_eq(env.board(0).decisions, 10)


func test_the_same_seed_and_the_same_actions_give_the_same_rewards() -> void:
	var first: PackedFloat32Array = _rewards_of_a_scripted_race(42)
	var second: PackedFloat32Array = _rewards_of_a_scripted_race(42)
	assert_eq(first.size(), second.size())
	assert_eq(first, second, "tick for tick the same race")
	var other_seed: PackedFloat32Array = _rewards_of_a_scripted_race(43)
	assert_ne(first, other_seed, "another seed is another start")


## 20 s of a race with a fixed sequence of actions: a slow weave, and a tack asked for twice.
static func _rewards_of_a_scripted_race(seed: int) -> PackedFloat32Array:
	var env: RaceEnv = RaceEnv.new(_course(), 1, 15.0)
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
	# Out early, it pays for the decisions it would have made up to the time limit (240 s, ten a
	# second): giving up must not be cheaper than sailing on.
	assert_almost_eq(env.reward(0), -0.01 * 2400.0, 0.011, "the rest of the time is charged")


func test_a_board_that_stops_gaining_is_done_when_asked() -> void:
	var options: RaceEnv.Options = RaceEnv.Options.new()
	options.stall_s = 3.0
	var env: RaceEnv = RaceEnv.new(_course(), 1, 15.0, options)
	env.reset(1)
	_point(env, 180.0)  # a beam reach along the line, never closer to it
	while not env.done(0) and env.time_s < 20.0:
		_decide(env, PackedFloat32Array([0.0, 0.0, 0.0]))
	assert_true(env.done(0), "done")
	assert_true(env.time_s < 10.0, "a few seconds after it stopped gaining: %.1f s" % env.time_s)
