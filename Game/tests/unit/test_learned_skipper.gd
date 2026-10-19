extends GutTest
## LearnedSkipper, a network at the controls (RACING_PLAN.md, "The learned skipper"): a random brain
## moves the hands within their range, ten times a second, and holds them between; the network's
## numbers become the hands through the sheet's dead zone and the tack's rising edge; and a brain
## sails a board in the game's way (setup() and update() every tick) exactly as it sails in the
## trainer's RaceEnv.

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
	var brain: NeuralNet = _random_brain(8)
	var course: Course = _course()
	# The trainer's way: observe, act, six ticks.
	var trained: RaceEnv = RaceEnv.new(course, 1, 15.0)
	trained.reset(5)
	# The game's way: the same race, with the skipper setting the hands before every tick.
	var played: RaceEnv = RaceEnv.new(course, 1, 15.0)
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
	assert_true(a.speed_ms > 0.1 or b.speed_ms > 0.1, "the board moved")
	assert_eq(b.position, a.position, "the same track, to the last bit")
	assert_eq(b.heading_deg, a.heading_deg)
