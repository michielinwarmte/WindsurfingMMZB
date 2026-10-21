extends GutTest
## Watching a night's generations race (tools/gens.sh, AI_FLEET_PLAN.md F5): the brains' labels and
## sail colours (Generations), the race options --behind, --wind, --blind
## and --spectate (RaceSetup), and which board the camera follows (SpectateChoice).


func test_the_generation_and_the_label_come_from_the_file_name() -> void:
	assert_eq(Generations.generation_of("night2b_gen140"), 140)
	assert_eq(Generations.generation_of("night2b_gen1"), 1)
	assert_eq(Generations.generation_of("night2b_best"), Generations.BEST)
	assert_eq(Generations.generation_of("night_test"), Generations.NONE)
	assert_eq(Generations.generation_of("night_genx"), Generations.NONE)
	assert_eq(Generations.label_of("night2b_gen40"), "gen 40")
	assert_eq(Generations.label_of("night2b_best"), "best")
	assert_eq(Generations.label_of("night_test"), "", "no generation: no label")
	assert_eq(Generations.run_of("night2b_gen40"), "night2b")
	assert_eq(Generations.run_of("night_best"), "night")


func test_the_sails_go_from_red_through_yellow_to_green_and_the_best_is_white() -> void:
	var oldest: Color = Generations.ramp_colour(1, 1, 141)
	var middle: Color = Generations.ramp_colour(71, 1, 141)
	var newest: Color = Generations.ramp_colour(141, 1, 141)
	assert_almost_eq(oldest.h, 0.0, 0.01, "the oldest red")
	assert_almost_eq(middle.h, 1.0 / 6.0, 0.01, "the middle yellow")
	assert_almost_eq(newest.h, 1.0 / 3.0, 0.01, "the newest green")
	assert_eq(Generations.ramp_colour(Generations.BEST, 1, 141), Generations.BEST_COLOUR, "the best white")
	# The ramp is from this race's generations: generation 50 is green when it is the newest here.
	assert_almost_eq(Generations.ramp_colour(50, 1, 50).h, 1.0 / 3.0, 0.01)


func test_a_fleet_of_generations_is_labelled_and_coloured_by_generation() -> void:
	var fleet: Array[RaceSkipper] = Skippers.make_fleet(PackedStringArray(["brain:night_gen1", "brain:night_gen50", "brain:night_best", "allrounder"]))
	assert_eq(fleet.size(), 4)
	assert_eq(fleet[0].board_name(), "gen 1")
	assert_eq(fleet[1].board_name(), "gen 50")
	assert_eq(fleet[2].board_name(), "best")
	assert_almost_eq(fleet[0].sail_colour().h, 0.0, 0.01, "the oldest red")
	assert_almost_eq(fleet[1].sail_colour().h, 1.0 / 3.0, 0.01, "the newest green")
	assert_eq(fleet[2].sail_colour(), Generations.BEST_COLOUR, "the best white")
	# One brain alone against the characters keeps its purple sail.
	var alone: Array[RaceSkipper] = Skippers.make_fleet(PackedStringArray(["brain:night2b_best", "allrounder"]))
	assert_eq(alone[0].sail_colour(), Color(0.6, 0.35, 0.9))


func test_the_race_options_behind_wind_blind_and_spectate() -> void:
	var setup: RaceSetup = RaceSetup.race("t1_loop", PackedStringArray(["brain:night_best"]), 1, 30.0)
	assert_almost_eq(setup.wait_behind_m(), 40.0, 0.01, "30 s of countdown: the nearest 40 m")
	assert_false(setup.blind)
	assert_false(setup.spectate)
	setup.read_options_from(PackedStringArray(["--behind=150", "--wind=15", "--blind=1", "--spectate=1", "--spawn=line"]))
	assert_almost_eq(setup.wait_behind_m(), 150.0, 0.01, "--behind overrides")
	assert_almost_eq(setup.wind_kt, 15.0, 0.01)
	assert_true(setup.blind)
	assert_true(setup.spectate)
	var usual: RaceSetup = RaceSetup.race("t1_loop")
	assert_almost_eq(usual.wait_behind_m(), 60.0, 0.01, "the menu's 60 s countdown: 60 m")


func test_a_blind_brain_sees_no_one() -> void:
	var skipper: LearnedSkipper = Skippers.make("brain:night_best") as LearnedSkipper
	var others: PackedVector2Array = PackedVector2Array([Vector2(5.0, 5.0)])
	skipper.set_others(others, others)
	assert_eq(skipper._others_positions.size(), 1, "seeing: it takes the others")
	var blind: LearnedSkipper = Skippers.make("brain:night_best") as LearnedSkipper
	blind.blind = true
	blind.set_others(others, others)
	assert_eq(blind._others_positions.size(), 0, "blind: it sees no one, as in training")


func test_twenty_boards_wait_in_order_along_the_line_150_m_behind_it() -> void:
	var course: Course = RaceCourses.t1_loop(270.0, Vector2.ZERO)
	var race: RaceSim = RaceSim.new(course, 1, 30.0)
	var start: RaceStep = race.steps()[0]
	var spots: PackedVector2Array = RaceRunner.line_spots(course, start, 20, 150.0)
	assert_eq(spots.size(), 20)
	var middle: Vector2 = course.start_middle()
	var line_dir: Vector2 = (start.points[0] - start.points[1]).normalized()
	for i: int in spots.size():
		assert_almost_eq((middle - spots[i]).dot(start.in_dir), 150.0, 2.0, "150 m behind the line")
		if i > 0:
			assert_true((spots[i] - spots[i - 1]).dot(line_dir) > 1.0, "in order along the line")


func test_the_camera_follows_the_leader_after_it_has_led_for_three_seconds() -> void:
	var choice: SpectateChoice = SpectateChoice.new()
	assert_eq(choice.update([4, 2, 7], 0.1), 4, "the leader at first")
	# Board 2 takes the lead: the camera waits 3 s.
	# Steps of 1/8 s (exact in binary): 23 of them are 2.875 s, the 24th makes 3 s.
	for i: int in 23:
		assert_eq(choice.update([2, 4, 7], 0.125), 4, "not yet")
	assert_eq(choice.update([2, 4, 7], 0.125), 2, "after 3 s of leading")
	# A close pack: the lead swaps every second, the camera stays.
	var seven_leads: Array[int] = [7, 2, 4]
	var two_leads: Array[int] = [2, 7, 4]
	for i: int in 10:
		choice.update(seven_leads if i % 2 == 0 else two_leads, 1.0)
		assert_eq(choice.followed, 2, "no flicker in a close pack")


func test_tab_steps_through_the_race_order_and_l_follows_the_leader_again() -> void:
	var choice: SpectateChoice = SpectateChoice.new()
	var order: Array[int] = [4, 2, 7]
	choice.update(order, 0.1)
	assert_eq(choice.step(order, 1), 2, "Tab: the next board")
	assert_false(choice.follows_leader, "Tab stops following the leader")
	assert_eq(choice.step(order, 1), 7)
	assert_eq(choice.step(order, 1), 4, "round the end")
	assert_eq(choice.step(order, -1), 7, "Shift+Tab: the previous one")
	for i: int in 50:
		choice.update(order, 0.1)
	assert_eq(choice.followed, 7, "by hand, the camera stays on its board")
	assert_eq(choice.follow_leader(order), 4, "L: the leader, at once")
	assert_true(choice.follows_leader)
