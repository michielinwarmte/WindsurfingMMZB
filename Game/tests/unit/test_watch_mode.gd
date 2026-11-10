extends GutTest
## Watching the AI race as their race director (WatchMode; Max, 10 November 2026): the speeds keep a
## tick at 1/60 s of the race, the TV camera's choice of boards, the plain title of the TV screen,
## and the Race page's "You: Watch". The keys, the cards and the camera are checked in the game
## (screenshots with --screen=, --tv=, --speed=, --head=).


func after_each() -> void:
	RacePage.chosen_watch = false
	RacePage.chosen_fleet = 2


# ---------------------------------------------------------------- the speeds

func test_every_speed_keeps_a_tick_at_one_sixtieth_of_a_second_of_the_race() -> void:
	for speed: float in WatchMode.SPEEDS:
		var pace: Vector2 = WatchMode.pace_for(speed, 60)
		assert_almost_eq(pace.y / pace.x, 1.0 / 60.0, 1e-9, "a tick at %s times" % speed)
		assert_almost_eq(pace.x / 60.0, speed, 1e-9, "the race goes %s times as fast" % speed)


func test_the_normal_speed_is_the_projects_own_pace() -> void:
	assert_eq(WatchMode.SPEEDS[WatchMode.NORMAL], 1.0)
	assert_eq(WatchMode.pace_for(1.0, 60), Vector2(60.0, 1.0))


func test_a_speed_from_the_command_line_takes_the_nearest_offered() -> void:
	assert_eq(WatchMode.SPEEDS[WatchMode.nearest_speed(4.0)], 4.0)
	assert_eq(WatchMode.SPEEDS[WatchMode.nearest_speed(0.3)], 0.25)
	assert_eq(WatchMode.SPEEDS[WatchMode.nearest_speed(3.0)], 4.0, "3 is nearer 4 than 2 by ratio")
	assert_eq(WatchMode.nearest_speed(0.0), WatchMode.NORMAL, "nonsense: the normal speed")
	assert_eq(WatchMode.nearest_speed(-2.0), WatchMode.NORMAL)


func test_the_speeds_are_named_as_fractions_and_times() -> void:
	assert_eq(WatchMode.speed_name(0.25), "1/4")
	assert_eq(WatchMode.speed_name(0.5), "1/2")
	assert_eq(WatchMode.speed_name(4.0), "4")


# ---------------------------------------------------------------- the TV camera's boards

func test_a_board_near_its_mark_or_in_a_fight_is_worth_more_than_one_alone() -> void:
	# The leader alone far ahead; boards 1 and 2 side by side; board 3 at its mark; board 4 alone.
	var positions: PackedVector2Array = PackedVector2Array([Vector2(0, -500), Vector2(0, 0), Vector2(10, 0), Vector2(300, 0), Vector2(-300, 0)])
	var to_mark: PackedFloat32Array = PackedFloat32Array([400.0, 300.0, 300.0, 30.0, 300.0])
	var weights: PackedFloat32Array = WatchMode.story_weights(positions, to_mark, PackedByteArray([0, 0, 0, 0, 0]), -1)
	assert_gt(weights[0], weights[4], "the leader")
	assert_gt(weights[1], weights[4], "a fight")
	assert_gt(weights[3], weights[1], "a mark")


func test_the_board_on_the_screen_and_a_finished_board_are_seldom_picked() -> void:
	var positions: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(500, 0), Vector2(-500, 0)])
	var far: PackedFloat32Array = PackedFloat32Array([INF, INF, INF])
	var weights: PackedFloat32Array = WatchMode.story_weights(positions, far, PackedByteArray([0, 0, 1]), 1)
	assert_lt(weights[1], 0.5, "the one shown now")
	assert_lt(weights[2], 0.5, "finished")
	assert_gt(weights[0], 1.0)


func test_a_finished_board_close_by_is_no_fight() -> void:
	var positions: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(5, 0)])
	var far: PackedFloat32Array = PackedFloat32Array([INF, INF])
	var weights: PackedFloat32Array = WatchMode.story_weights(positions, far, PackedByteArray([1, 0]), -1)
	assert_eq(weights[1], 1.0, "only a racing board makes a fight")


# ---------------------------------------------------------------- the screens and the menu

func test_the_tv_screens_title_is_the_board_and_its_place_only() -> void:
	assert_eq(RaceHud.watch_title("Hana", "3rd", true, true), "Hana, 3rd")
	assert_string_starts_with(RaceHud.watch_title("Hana", "3rd", true), "Spectating Hana, 3rd")


func test_the_race_page_watches_with_the_fleet_and_never_alone() -> void:
	RacePage.chosen_watch = true
	RacePage.chosen_fleet = 0  # "You alone"
	var setup: RaceSetup = RacePage.make_setup("t1_loop")
	assert_true(setup.spectate)
	assert_false(setup.time_trial, "watching is no time trial")
	assert_eq(setup.skippers.size(), RacePage.WATCH_FLEET_IF_ALONE)
	RacePage.chosen_watch = false
	setup = RacePage.make_setup("t1_loop")
	assert_false(setup.spectate)
	assert_true(setup.time_trial, "racing alone is still the time trial")
