extends GutTest
## LearnedSkipper, a network at the controls (RACING_PLAN.md, "The learned skipper"): a random brain
## moves the hands within their range, ten times a second, and holds them between; the network's
## numbers become the hands through the sheet's dead zone and the tack's rising edge (the stick
## mode), or through a wind angle to hold, steered for on both tacks, with a tack or gybe asked for
## when the angle wanted is on the other tack (the wind-angle mode); a brain is read in the mode it
## was trained in; and a brain sails a board in the game's way (setup() and update() every tick)
## exactly as it sails in the trainer's RaceEnv, in both modes.

const DT: float = 1.0 / 60.0


static func _course() -> Course:
	return RaceCourses.t1_loop(270.0, Vector2.ZERO)


static func _random_brain(seed: int, outputs: int = 3) -> NeuralNet:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	return NeuralNet.make([RaceObservation.size(), 16, 16, outputs], rng)


func test_a_random_brain_moves_the_hands_within_their_range_ten_times_a_second() -> void:
	var course: Course = _course()
	var race: RaceSim = RaceSim.new(course, 1, 10.0)
	var sim: WindsurferSim = WindsurferSim.create_default(false)
	var spot: Vector2 = RaceCourses.pre_start_spot(course)
	sim.reset(Vector3(spot.x, 0.0, spot.y), deg_to_rad(RaceCourses.pre_start_heading_deg(course)))
	var controller: PlayerController = PlayerController.new()
	controller.set_sail(sim.sail, sim.sailor_config, sim.air_density_kg_m3)
	var hands: AiHands = AiHands.new()
	var controls: SimControls = SimControls.new()
	race.add_board("learner")
	race.update_board(0, spot)
	race.start()
	var skipper: LearnedSkipper = LearnedSkipper.new()
	skipper.setup(sim, controller, hands, race, 0)
	skipper.brain = _random_brain(4)
	assert_eq(controller.hands, hands, "setup() puts the hands on the controller")
	var steers: Dictionary[float, bool] = {}
	var changes: int = 0
	var last_steer: float = INF
	var ticks: int = 300
	for t: int in ticks:
		skipper.update(sim.telemetry, DT)
		assert_between(hands.steer, -1.0, 1.0, "the steer stick")
		assert_between(hands.sheet, -1.0, 1.0, "the sheet stick")
		if hands.steer != last_steer:
			changes += 1
			last_steer = hands.steer
		steers[hands.steer] = true
		controller.update(sim.telemetry, controls, DT)
		sim.step(DT, controls)
		race.update_board(0, Vector2(sim.telemetry.position.x, sim.telemetry.position.z))
		race.step(DT)
	assert_true(steers.size() >= 5, "the steer changes over time: %d different values" % steers.size())
	assert_true(changes <= ticks / LearnedSkipper.DECISION_TICKS + 1, "and only at a decision, ten times a second (%d changes)" % changes)


func test_without_a_brain_the_hands_stay_still() -> void:
	var course: Course = _course()
	var race: RaceSim = RaceSim.new(course)
	race.add_board("nobody")
	var sim: WindsurferSim = WindsurferSim.create_default(false)
	var controller: PlayerController = PlayerController.new()
	var hands: AiHands = AiHands.new()
	var skipper: LearnedSkipper = LearnedSkipper.new()
	skipper.setup(sim, controller, hands, race, 0)
	for t: int in 30:
		skipper.update(sim.telemetry, DT)
	assert_eq(hands.steer, 0.0)
	assert_eq(hands.sheet, 0.0)
	assert_false(hands.tack)


func test_the_networks_numbers_become_the_hands() -> void:
	var hands: AiHands = AiHands.new()
	# The steer as it is; a sheet inside the dead zone leaves the auto-sheet trimming; the tack output
	# rising past 0.5 asks for one tack.
	var high: bool = LearnedSkipper.apply_action(hands, PackedFloat32Array([0.25, 0.3, 0.6]), false, false)
	assert_almost_eq(hands.steer, 0.25, 1e-6)
	assert_eq(hands.sheet, 0.0, "inside the dead zone the auto-sheet trims")
	assert_true(hands.tack, "the tack output went high: a tack is asked for")
	assert_true(high)
	hands.tack = false
	LearnedSkipper.apply_action(hands, PackedFloat32Array([0.0, 0.0, 0.9]), true, false)
	assert_false(hands.tack, "held high, it asks only once")
	LearnedSkipper.apply_action(hands, PackedFloat32Array([0.0, 0.0, 0.9]), false, true)
	assert_false(hands.tack, "never while a manoeuvre is under way")
	# Beyond the dead zone the rest is stretched to the full stick.
	LearnedSkipper.apply_action(hands, PackedFloat32Array([0.0, 0.75, 0.0]), false, false)
	assert_almost_eq(hands.sheet, 0.5, 1e-6)
	LearnedSkipper.apply_action(hands, PackedFloat32Array([-2.0, -1.0, 0.0]), false, false)
	assert_almost_eq(hands.sheet, -1.0, 1e-6)
	assert_almost_eq(hands.steer, -1.0, 1e-6, "the steer is clipped to the stick's range")


func test_a_brain_sails_through_the_skipper_exactly_as_in_the_trainer() -> void:
	_sail_both_ways(LearnedSkipper.ActionMode.STICK)
	_sail_both_ways(LearnedSkipper.ActionMode.TWA)
	# A brain trained with the tack discipline (RA14): its note's gap in the game, the stage's in
	# the trainer.
	_sail_both_ways(LearnedSkipper.ActionMode.TWA, LearnedSkipper.MANOEUVRE_GAP_S)


func _sail_both_ways(mode: LearnedSkipper.ActionMode, gap_s: float = NAN) -> void:
	var brain: NeuralNet = _random_brain(8, LearnedSkipper.TWA_ACTION_NAMES.size() if mode == LearnedSkipper.ActionMode.TWA else 3)
	brain.meta["actions"] = LearnedSkipper.mode_name(mode)
	if not is_nan(gap_s):
		brain.meta[LearnedSkipper.GAP_NOTE] = gap_s
		brain.meta[LearnedSkipper.CLOSEST_NOTE] = LearnedSkipper.CLOSEST_TWA_DEG
	# A wind-angle brain with the hold and the push outputs, as the trainer makes them.
	brain.action_names = LearnedSkipper.TWA_ACTION_NAMES if mode == LearnedSkipper.ActionMode.TWA else LearnedSkipper.ACTION_NAMES
	var course: Course = _course()
	var options: RaceEnv.Options = RaceEnv.Options.new()
	options.actions = mode
	if not is_nan(gap_s):
		options.manoeuvre_gap_s = gap_s
		options.closest_twa_deg = LearnedSkipper.CLOSEST_TWA_DEG
	# The trainer's way: observe, act, six ticks.
	var trained: RaceEnv = RaceEnv.new(course, 1, 15.0, options)
	trained.reset(5)
	# The game's way: the same race, with the skipper setting the hands before every tick.
	var played: RaceEnv = RaceEnv.new(course, 1, 15.0, options)
	played.reset(5)
	var board: RaceEnv.Board = played.board(0)
	var skipper: LearnedSkipper = LearnedSkipper.new()
	skipper.setup(board.sim, board.controller, board.hands, played.race, 0)
	skipper.brain = brain
	for decision: int in 100:
		trained.act(0, brain.forward(trained.observe(0)))
		for t: int in trained.decision_ticks:
			trained.tick()
			skipper.update(board.sim.telemetry, DT)
			played.tick()
	var a: Telemetry = trained.board(0).sim.telemetry
	var b: Telemetry = board.sim.telemetry
	var name: String = LearnedSkipper.mode_name(mode)
	assert_true(a.speed_ms > 0.1 or b.speed_ms > 0.1, "the board moved (%s)" % name)
	if mode == LearnedSkipper.ActionMode.TWA:
		assert_false(is_nan(board.hands.push), "the brain's push is on the hands")
		assert_eq(board.hands.push, trained.board(0).hands.push, "the same push both ways")
	assert_eq(b.position, a.position, "the same track, to the last bit (%s)" % name)
	assert_eq(b.heading_deg, a.heading_deg)


# ---------------------------------------------------------------- the wind-angle mode

func test_steering_for_a_wind_angle_turns_the_right_way_on_both_tacks() -> void:
	# Starboard tack (the wind from starboard, +1), 60 degrees off the wind, 45 wanted: head up, which
	# on starboard tack is a right turn. 15 degrees of error is three quarters of the stick.
	assert_almost_eq(LearnedSkipper.steer_toward_twa(60.0, 1.0, 45.0), 0.75, 1e-6, "starboard, too far off: right")
	assert_almost_eq(LearnedSkipper.steer_toward_twa(30.0, 1.0, 45.0), -0.75, 1e-6, "starboard, too high: left")
	# Port tack: heading up is a left turn.
	assert_almost_eq(LearnedSkipper.steer_toward_twa(-60.0, -1.0, 45.0), -0.75, 1e-6, "port, too far off: left")
	assert_almost_eq(LearnedSkipper.steer_toward_twa(-30.0, -1.0, 45.0), 0.75, 1e-6, "port, too high: right")
	# Within the dead band the stick is let go (the heading hold keeps the course); 20 degrees or
	# more is a full stick.
	assert_eq(LearnedSkipper.steer_toward_twa(46.5, 1.0, 45.0), 0.0, "within 2 degrees: let go")
	assert_eq(LearnedSkipper.steer_toward_twa(100.0, 1.0, 45.0), 1.0, "a full stick at most")
	# Just past head to wind on starboard tack (the sail still on the port side): bear away, left.
	assert_true(LearnedSkipper.steer_toward_twa(-10.0, 1.0, 45.0) < -0.9, "past head to wind: bear away")
	# By the lee on starboard tack (175 degrees from port): head up, right, back to 150.
	assert_true(LearnedSkipper.steer_toward_twa(-175.0, 1.0, 150.0) > 0.9, "by the lee: head up")


func test_the_tack_comes_from_the_wind_angle_or_near_head_to_wind_from_the_sail() -> void:
	var t: Telemetry = Telemetry.new()
	t.twa_deg = 60.0
	t.sail_side = -1
	assert_eq(LearnedSkipper.tack_of(t), 1.0, "60 degrees from starboard: starboard tack")
	t.twa_deg = -120.0
	t.sail_side = 1
	assert_eq(LearnedSkipper.tack_of(t), -1.0, "120 from port: port tack")
	# In irons, a few degrees the other side of the wind: still the tack the sail is set for.
	t.twa_deg = -8.0
	t.sail_side = -1
	assert_eq(LearnedSkipper.tack_of(t), 1.0, "in irons: the sail says starboard")
	t.twa_deg = 178.0
	t.sail_side = 1
	assert_eq(LearnedSkipper.tack_of(t), -1.0, "dead downwind: the sail says port")


func test_a_wind_angle_on_the_other_tack_asks_for_one_tack_and_not_again_for_3_s() -> void:
	var hands: AiHands = AiHands.new()
	var driver: LearnedSkipper.Driver = LearnedSkipper.Driver.new(hands, LearnedSkipper.ActionMode.TWA)
	var t: Telemetry = Telemetry.new()
	t.twa_deg = 50.0
	t.sail_side = -1
	# 45 degrees on starboard, the tack it is on: no tack, a little right to head up 5 degrees.
	driver.decide(PackedFloat32Array([0.25, 0.0, 1.0]), false)
	driver.steer(t, false, DT)
	assert_false(hands.tack, "the third output is not a tack in this mode")
	assert_almost_eq(hands.steer, 0.25, 1e-6, "5 degrees off: a quarter of the stick, right")
	assert_eq(hands.sheet, 0.0, "the sheet left to the auto-sheet")
	# 45 degrees on port: ask for the tack once.
	driver.decide(PackedFloat32Array([-0.25, 0.0, 0.0]), false)
	driver.steer(t, false, DT)
	assert_true(hands.tack, "the other tack is asked for")
	hands.tack = false  # the controller took it
	for k: int in 60:  # a second later, the board still on starboard (the tack did not start)
		driver.steer(t, false, DT)
	assert_false(hands.tack, "not asked again within 3 s")
	for k: int in 150:
		driver.steer(t, false, DT)
	assert_true(hands.tack, "asked again after 3 s")
	hands.tack = false
	for k: int in 200:
		driver.steer(t, true, DT)
	assert_false(hands.tack, "never while a manoeuvre is under way")
	for k: int in 300:  # 5 s after the manoeuvre ended
		driver.steer(t, false, DT)
	assert_false(hands.tack, "nor in the first 6 s after one, while the board gets its speed back")
	for k: int in 120:
		driver.steer(t, false, DT)
	assert_true(hands.tack, "and then it is asked for")
	hands.tack = false
	# A wish near head to wind, or dead downwind, on the other side is not clearly the other tack:
	# it means as high (or as deep) as it goes on this one.
	var later: LearnedSkipper.Driver = LearnedSkipper.Driver.new(hands, LearnedSkipper.ActionMode.TWA)
	later.decide(PackedFloat32Array([-10.0 / 180.0, 0.0, 0.0]), false)
	later.steer(t, false, DT)
	assert_false(hands.tack, "10 degrees on port, from starboard: no tack")
	assert_eq(hands.steer, 1.0, "but head up as far as it goes: right, on starboard")
	later.decide(PackedFloat32Array([-0.95, 0.0, 0.0]), false)
	later.steer(t, false, DT)
	assert_false(hands.tack, "171 degrees on port, from starboard: no gybe")


func test_the_tack_discipline_holds_this_tack_until_the_gap_has_passed_and_a_rounding_cuts_it() -> void:
	var hands: AiHands = AiHands.new()
	var driver: LearnedSkipper.Driver = LearnedSkipper.Driver.new(hands, LearnedSkipper.ActionMode.TWA)
	driver.manoeuvre_gap_s = 20.0
	var t: Telemetry = Telemetry.new()
	t.twa_deg = 50.0
	t.sail_side = -1
	# A tack just ended (a second of it under way), and the wish is now 45 degrees on port.
	for k: int in 60:
		driver.steer(t, true, DT)
	driver.decide(PackedFloat32Array([-0.25, 0.0, 0.0]), false)
	var asked_at_s: float = -1.0
	for k: int in 30 * 60:
		driver.steer(t, false, DT)
		if hands.tack:
			asked_at_s = (k + 1) * DT
			break
		if k == 10 * 60:
			assert_almost_eq(hands.steer, 0.25, 1e-6, "meanwhile close-hauled on this tack: 45 degrees, 5 degrees up")
	assert_almost_eq(asked_at_s, 20.0, 0.05, "the other tack asked for 20 s after the last manoeuvre, not before")
	hands.tack = false
	# Another manoeuvre, then a mark rounded 2 s after it: the 18 s left are cut to 6.
	for k: int in 60:
		driver.steer(t, true, DT)
	for k: int in 120:
		driver.steer(t, false, DT)
	driver.leg_done()
	asked_at_s = -1.0
	for k: int in 30 * 60:
		driver.steer(t, false, DT)
		if hands.tack:
			asked_at_s = (k + 1) * DT
			break
	assert_almost_eq(asked_at_s, 6.0, 0.05, "a rounding leaves at most TACK_HOLD_S to wait")
	# The old rule (a gap of TACK_HOLD_S): a rounding changes nothing.
	var old: LearnedSkipper.Driver = LearnedSkipper.Driver.new(hands, LearnedSkipper.ActionMode.TWA)
	old.since_manoeuvre_s = 2.0
	old.leg_done()
	assert_eq(old.since_manoeuvre_s, 2.0, "the brains before RA14 sail as they did")


func test_a_wish_nearer_the_wind_than_the_floor_is_close_hauled_on_this_tack() -> void:
	var hands: AiHands = AiHands.new()
	var t: Telemetry = Telemetry.new()
	t.twa_deg = 50.0
	t.sail_side = -1
	var old: LearnedSkipper.Driver = LearnedSkipper.Driver.new(hands, LearnedSkipper.ActionMode.TWA)
	old.decide(PackedFloat32Array([10.0 / 180.0, 0.0, 0.0]), false)
	old.steer(t, false, DT)
	assert_eq(hands.steer, 1.0, "no floor (the brains before RA14): 10 degrees asked, a full stick up into irons")
	var floored: LearnedSkipper.Driver = LearnedSkipper.Driver.new(hands, LearnedSkipper.ActionMode.TWA)
	floored.closest_twa_deg = LearnedSkipper.CLOSEST_TWA_DEG
	floored.decide(PackedFloat32Array([10.0 / 180.0, 0.0, 0.0]), false)
	floored.steer(t, false, DT)
	assert_almost_eq(hands.steer, 15.0 / LearnedSkipper.TWA_FULL_STICK_DEG, 1e-6, "with it: up to 35 degrees only")
	# Near head to wind on the other side: still no tack (the raw wish decides that), close-hauled here.
	floored.decide(PackedFloat32Array([-10.0 / 180.0, 0.0, 0.0]), false)
	floored.steer(t, false, DT)
	assert_false(hands.tack, "10 degrees on port is not clearly the other tack")
	assert_almost_eq(hands.steer, 0.75, 1e-6)
	# A wish further off the wind is left alone.
	floored.decide(PackedFloat32Array([0.25, 0.0, 0.0]), false)
	floored.steer(t, false, DT)
	assert_almost_eq(hands.steer, 0.25, 1e-6, "45 degrees asked, 45 steered")


func test_a_brain_sails_by_the_tack_discipline_it_was_trained_with() -> void:
	var brain: NeuralNet = _random_brain(3, LearnedSkipper.TWA_ACTION_NAMES.size())
	brain.meta["actions"] = "twa"
	assert_eq(LearnedSkipper.gap_of(brain), LearnedSkipper.TACK_HOLD_S, "a brain from before RA14: the old 6 s")
	var skipper: LearnedSkipper = LearnedSkipper.new()
	skipper.brain = brain
	assert_eq(skipper.manoeuvre_gap_s, LearnedSkipper.TACK_HOLD_S)
	assert_eq(LearnedSkipper.closest_of(brain), 0.0, "and no floor")
	brain.meta[LearnedSkipper.GAP_NOTE] = 25.0
	brain.meta[LearnedSkipper.CLOSEST_NOTE] = 38.0
	assert_eq(LearnedSkipper.gap_of(brain), 25.0, "its note says the gap it learned with")
	assert_eq(LearnedSkipper.closest_of(brain), 38.0, "and the floor")
	skipper.brain = brain
	assert_eq(skipper.manoeuvre_gap_s, 25.0)
	assert_eq(skipper.closest_twa_deg, 38.0)
	# In a race: the skipper hands its gap to the driver, and a step of the course done (here the
	# board set past the start) cuts the wait as RaceEnv does.
	var options: RaceEnv.Options = RaceEnv.Options.new()
	var env: RaceEnv = RaceEnv.new(_course(), 1, 15.0, options)
	env.reset(2)
	var board: RaceEnv.Board = env.board(0)
	var played: LearnedSkipper = LearnedSkipper.new()
	played.setup(board.sim, board.controller, board.hands, env.race, 0)
	played.brain = brain
	played.manoeuvre_gap_s = 30.0  # the race tool's --manoeuvre_gap_s, after the brain
	played.update(board.sim.telemetry, DT)
	assert_eq(played.driver().manoeuvre_gap_s, 30.0, "the override reaches the hands")
	played.driver().since_manoeuvre_s = 0.0
	var spot: Vector3 = board.sim.telemetry.position
	env.race.place_board(0, Vector2(spot.x, spot.z), 1)
	played.update(board.sim.telemetry, DT)
	assert_true(played.driver().since_manoeuvre_s >= 30.0 - LearnedSkipper.TACK_HOLD_S, "the rounding cut the wait to 6 s: %.2f" % played.driver().since_manoeuvre_s)


func test_a_brain_is_read_in_the_mode_it_was_trained_in() -> void:
	var brain: NeuralNet = _random_brain(1)
	assert_eq(LearnedSkipper.mode_of(brain), LearnedSkipper.ActionMode.STICK, "no note: a stick brain")
	brain.meta["actions"] = "twa"
	assert_eq(LearnedSkipper.mode_of(brain), LearnedSkipper.ActionMode.TWA)
	brain.meta["actions"] = "stick"
	assert_eq(LearnedSkipper.mode_of(brain), LearnedSkipper.ActionMode.STICK)


func test_the_hold_output_becomes_the_hands_hold_back_speed_when_the_brain_has_one() -> void:
	# The mapping: nothing at 0 or below, 8 m/s just above 0, 1.5 m/s at 1.
	assert_eq(LearnedSkipper.hold_from_output(-0.3), 0.0)
	assert_eq(LearnedSkipper.hold_from_output(0.0), 0.0)
	assert_almost_eq(LearnedSkipper.hold_from_output(0.001), LearnedSkipper.HOLD_FASTEST_MS, 0.01)
	assert_almost_eq(LearnedSkipper.hold_from_output(1.0), LearnedSkipper.HOLD_SLOWEST_MS, 1e-6)
	assert_almost_eq(LearnedSkipper.hold_from_output(0.5), 0.5 * (LearnedSkipper.HOLD_FASTEST_MS + LearnedSkipper.HOLD_SLOWEST_MS), 1e-6)
	# A driver with the hold puts it on the hands; one without leaves them alone.
	var hands: AiHands = AiHands.new()
	var driver: LearnedSkipper.Driver = LearnedSkipper.Driver.new(hands, LearnedSkipper.ActionMode.TWA)
	driver.uses_hold = true
	driver.decide(PackedFloat32Array([0.25, 0.0, 1.0]), false)
	assert_almost_eq(hands.hold_speed_ms, LearnedSkipper.HOLD_SLOWEST_MS, 1e-6)
	driver.decide(PackedFloat32Array([0.25, 0.0, -1.0]), false)
	assert_eq(hands.hold_speed_ms, 0.0)
	driver.uses_hold = false
	driver.decide(PackedFloat32Array([0.25, 0.0, 1.0]), false)
	assert_eq(hands.hold_speed_ms, 0.0, "a brain without a hold output never holds back")
	# A brain says so by the name of its third output.
	var brain: NeuralNet = _random_brain(2)
	assert_false(LearnedSkipper.uses_hold_of(brain), "no names")
	brain.action_names = LearnedSkipper.TWA_ACTION_NAMES
	assert_true(LearnedSkipper.uses_hold_of(brain))
	brain.action_names = PackedStringArray(["twa", "sheet", "unused"])
	assert_false(LearnedSkipper.uses_hold_of(brain), "the night's brains")


func test_the_push_output_sets_the_hands_push_slider_and_a_brain_without_one_leaves_it_alone() -> void:
	# The mapping: -1 is the slider at 0, 1 at 1, 0 in the middle; and back.
	assert_eq(LearnedSkipper.push_from_output(-1.0), 0.0)
	assert_eq(LearnedSkipper.push_from_output(-3.0), 0.0, "clipped")
	assert_eq(LearnedSkipper.push_from_output(0.0), 0.5)
	assert_eq(LearnedSkipper.push_from_output(1.0), 1.0)
	assert_almost_eq(LearnedSkipper.push_from_output(LearnedSkipper.output_for_push(0.3)), 0.3, 1e-6)
	# The pilot's own margin: the level where the ladder's pull held is the autopilot's default
	# (1.1 between 75 % at 1.0 and 85 % at 1.3: a third of the way, 78.3 %).
	var level: float = LearnedSkipper.pilot_margin_level()
	var curve: PushCurveConfig = PushDial.default_curve()
	assert_almost_eq(curve.at(curve.hike_share, level), Autopilot.new().hike_share, 1e-6, "the pilot's pull held")
	assert_almost_eq(level, 0.75 + 0.1 / 3.0, 1e-4)
	# A brain finds its push output by name.
	var brain: NeuralNet = _random_brain(3, 4)
	assert_eq(LearnedSkipper.push_index_of(brain), -1, "no names: no push")
	brain.action_names = LearnedSkipper.TWA_ACTION_NAMES
	assert_eq(LearnedSkipper.push_index_of(brain), LearnedSkipper.PUSH)
	brain.action_names = PackedStringArray(["twa", "sheet", "hold"])
	assert_eq(LearnedSkipper.push_index_of(brain), -1, "the brains before Session 64")
	# A driver with a push output puts it on the hands; one without leaves them at NaN.
	var hands: AiHands = AiHands.new()
	var driver: LearnedSkipper.Driver = LearnedSkipper.Driver.new(hands, LearnedSkipper.ActionMode.TWA)
	driver.decide(PackedFloat32Array([0.25, 0.0, 0.0, 0.6]), false)
	assert_true(is_nan(hands.push), "no push output: the pilot's own margin")
	driver.push_index = LearnedSkipper.PUSH
	driver.decide(PackedFloat32Array([0.25, 0.0, 0.0, 0.6]), false)
	assert_almost_eq(hands.push, 0.8, 1e-6)
	driver.decide(PackedFloat32Array([0.25, 0.0, 0.0]), false)
	assert_almost_eq(hands.push, 0.8, 1e-6, "three numbers leave the push where it was")


func test_a_skipper_with_a_push_brain_drives_the_controllers_slider_and_an_old_brain_does_not() -> void:
	for outputs: int in [4, 3]:
		var course: Course = _course()
		var options: RaceEnv.Options = RaceEnv.Options.new()
		var env: RaceEnv = RaceEnv.new(course, 1, 15.0, options)
		env.reset(5)
		var board: RaceEnv.Board = env.board(0)
		var brain: NeuralNet = _random_brain(6, outputs)
		brain.meta["actions"] = "twa"
		brain.action_names = LearnedSkipper.TWA_ACTION_NAMES.slice(0, outputs)
		var skipper: LearnedSkipper = LearnedSkipper.new()
		skipper.setup(board.sim, board.controller, board.hands, env.race, 0)
		skipper.brain = brain
		for t: int in 3:
			skipper.update(board.sim.telemetry, DT)
			board.controller.update(board.sim.telemetry, board.controls, DT)
		if outputs == 4:
			assert_false(is_nan(board.hands.push), "the brain's push is on the hands")
			assert_almost_eq(board.controller.push_level, board.hands.push, 1e-6, "and on the controller's slider")
			assert_almost_eq(board.hands.push, LearnedSkipper.push_from_output(skipper.last_action[LearnedSkipper.PUSH]), 1e-6)
		else:
			assert_true(is_nan(board.hands.push), "an old brain leaves the hands' push at NaN")
			assert_true(is_nan(board.controller.push_level), "and the controller sails the pilot's own margin")


func test_a_brain_picks_its_inputs_by_name_and_decides_as_often_as_its_note_says() -> void:
	var names: PackedStringArray = RaceObservation.names()
	# A brain from before the last ten numbers were added: it takes the first names only.
	var old_names: PackedStringArray = names.slice(0, names.size() - 10)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var old: NeuralNet = NeuralNet.make([old_names.size(), 4, 3], rng)
	old.obs_names = old_names
	var observation: PackedFloat32Array = PackedFloat32Array()
	for k: int in names.size():
		observation.append(float(k))
	var picked: PackedFloat32Array = old.select_inputs(observation, names)
	assert_eq(picked.size(), old_names.size())
	assert_eq(picked[0], 0.0)
	assert_eq(picked[picked.size() - 1], float(old_names.size() - 1))
	# A brain with the inputs in another order gets them in its order.
	var shuffled: NeuralNet = NeuralNet.make([3, 2, 3], rng)
	shuffled.obs_names = PackedStringArray([names[5], names[0], names[2]])
	assert_eq(shuffled.select_inputs(observation, names), PackedFloat32Array([5.0, 0.0, 2.0]))
	# The same names: the observation as it is.
	var current: NeuralNet = NeuralNet.make([names.size(), 2, 3], rng)
	current.obs_names = names.duplicate()
	assert_eq(current.select_inputs(observation, names), observation)
	# The note's decision_ticks is how often the skipper asks it.
	current.meta["decision_ticks"] = 30
	var skipper: LearnedSkipper = LearnedSkipper.new()
	skipper.brain = current
	assert_eq(skipper.decision_ticks, 30)
