extends GutTest
## TrainBridge, the Godot side of the bridge to the Python trainer (AI_FLEET_PLAN.md, D6b): the
## hello says what the observation and the actions are; a reset gives every board an observation of
## the right size; a step gives each board an observation, a reward, a done flag and, when an
## episode ends, its stats and its last observation, with the board set down again at once in the
## stages whose drops do not depend on the race (S1 to S4) and parked in the ones with a countdown
## (S5, S6) until the race is new; and a brain can be run through the bridge the way the trainer
## does, decision by decision.


func test_the_hello_says_what_goes_over_the_bridge() -> void:
	var bridge: TrainBridge = TrainBridge.new("S2", 3)
	var hello: Dictionary = bridge.hello()
	assert_eq(hello["obs_size"], RaceObservation.size())
	assert_eq(hello["obs_names"].size(), RaceObservation.size())
	assert_eq(hello["action_size"], 3)
	assert_eq(hello["action_names"], Array(LearnedSkipper.TWA_ACTION_NAMES))
	assert_eq(hello["boards"], 3)
	assert_eq(hello["stage"], "S2")
	assert_eq(hello["decision_ticks"], 30)
	var unknown: TrainBridge = TrainBridge.new("S9", 0)
	assert_eq(unknown.stage.name, "S1", "an unknown stage falls back to S1")
	assert_eq(unknown.boards, 4, "with the stage's boards")


func test_a_reset_and_a_step_give_every_board_its_numbers() -> void:
	var bridge: TrainBridge = TrainBridge.new("S1", 3)
	var first: Dictionary = bridge.reset(5)
	assert_eq(first["obs"].size(), 3)
	for o: Array in first["obs"]:
		assert_eq(o.size(), RaceObservation.size())
	assert_true(first["race"]["length_m"] > 0.0)
	var actions: Array = [[0.25, 0.0, 0.0], [-0.25, 0.0, 0.0], [0.5, 0.0, 0.5]]
	var reply: Dictionary = bridge.step(actions, 6)
	assert_eq(reply["obs"].size(), 3)
	assert_eq(reply["rew"].size(), 3)
	assert_eq(reply["done"].size(), 3)
	assert_eq(reply["trunc"].size(), 3)
	assert_eq(reply["info"].size(), 3)
	assert_eq(reply["terminal_obs"].size(), 3)
	for i: int in 3:
		assert_false(reply["done"][i], "nobody is done after half a second")
		assert_null(reply["info"][i])
		assert_null(reply["terminal_obs"][i])
	assert_eq(bridge.env.ticks, 30, "a step is 30 ticks: half a second")
	assert_eq(bridge.steps, 1)
	var no_race: TrainBridge = TrainBridge.new("S1", 1)
	assert_true(no_race.step(actions, 1).has("error"), "a step before a reset is an error")


func test_an_ended_episode_reports_its_end_and_the_board_is_set_down_again_at_once() -> void:
	# A short episode: S1 with the time limit cut to 2 s through the environment's options.
	var bridge: TrainBridge = TrainBridge.new("S1", 2)
	bridge.reset(7)
	for i: int in 2:
		bridge.env.board(i).episode_until_s = 2.0
	var ended: int = 0
	var reply: Dictionary = {}
	for k: int in 6:
		reply = bridge.step([[0.25, 0.0, 0.0], [0.25, 0.0, 0.0]], 100 + k)
		for i: int in 2:
			if reply["done"][i]:
				ended += 1
				assert_true(reply["trunc"][i], "cut by the time limit")
				assert_not_null(reply["info"][i])
				assert_eq(reply["info"][i]["truncated"], true)
				assert_eq(reply["terminal_obs"][i].size(), RaceObservation.size(), "the episode's last observation")
				assert_false(bridge.env.done(i), "set down again at once: the next episode is on")
				assert_eq(bridge.env.board(i).decisions, 0)
	assert_eq(ended, 2, "both boards ended once in 3 s")
	assert_eq(bridge.episodes, 2)


func test_in_a_stage_with_a_countdown_a_done_board_waits_for_the_race_to_end() -> void:
	var bridge: TrainBridge = TrainBridge.new("S5", 2)
	var first: Dictionary = bridge.reset(8)
	var countdown_s: float = first["race"]["prestart_s"]
	# Board 0's time is cut short; board 1 sails on. Board 0 ends once, then waits, parked.
	bridge.env.board(0).episode_until_s = 1.0
	var reply: Dictionary = bridge.step([[0.3, 0.0, 0.0], [0.3, 0.0, 0.0]], 1)
	reply = bridge.step([[0.3, 0.0, 0.0], [0.3, 0.0, 0.0]], 2)
	assert_true(reply["done"][0], "board 0 ended")
	assert_false(reply["done"][1])
	assert_true(bridge.env.done(0), "and waits")
	var parked_obs: Array = reply["obs"][0]
	reply = bridge.step([[0.3, 0.0, 0.0], [0.3, 0.0, 0.0]], 3)
	assert_false(reply["done"][0], "not ended again while it waits")
	assert_eq(reply["rew"][0], 0.0, "and earns nothing")
	assert_eq(reply["obs"][0], parked_obs, "it keeps reporting where it ended")
	# When board 1's time is up too, the race is new for both.
	bridge.env.board(1).episode_until_s = bridge.env.time_s + 0.5
	reply = bridge.step([[0.3, 0.0, 0.0], [0.3, 0.0, 0.0]], 4)
	assert_true(reply["done"][1], "board 1 ended")
	assert_true(reply.has("race"), "a new race")
	assert_false(bridge.env.done(0))
	assert_false(bridge.env.done(1))
	assert_true(-bridge.env.race.clock_s() >= 45.0, "with a new countdown")
	assert_true(countdown_s >= 45.0 and countdown_s <= 90.0)


func test_a_brain_runs_through_the_bridge_decision_by_decision() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2
	var brain: NeuralNet = NeuralNet.make([RaceObservation.size(), 8, 3], rng)
	var bridge: TrainBridge = TrainBridge.new("S2", 2)
	var reply: Dictionary = bridge.reset(3)
	var total: float = 0.0
	for k: int in 10:
		var actions: Array = []
		for o: Array in reply["obs"]:
			actions.append(Array(brain.forward(PackedFloat32Array(o))))
		reply = bridge.step(actions, 10 + k)
		for r: float in reply["rew"]:
			total += r
	assert_eq(bridge.env.ticks, 300, "5 s sailed")
	assert_true(total != 0.0, "something was earned or lost: %.3f" % total)
