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


static func _random_brain(seed: int) -> NeuralNet:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	return NeuralNet.make([RaceObservation.size(), 16, 16, 3], rng)


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


func _sail_both_ways(mode: LearnedSkipper.ActionMode) -> void:
	var brain: NeuralNet = _random_brain(8)
	brain.meta["actions"] = LearnedSkipper.mode_name(mode)
	# A wind-angle brain with a hold output, as the trainer makes them.
	brain.action_names = LearnedSkipper.TWA_ACTION_NAMES if mode == LearnedSkipper.ActionMode.TWA else LearnedSkipper.ACTION_NAMES
	var course: Course = _course()
	var options: RaceEnv.Options = RaceEnv.Options.new()
	options.actions = mode
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
