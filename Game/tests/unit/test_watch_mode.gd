extends GutTest
## Watching the AI race as their race director (WatchMode; Max, 10 November 2026): the speeds keep a
## tick at 1/60 s of the race, the TV camera's boards, shots and start (TvCamera), the plain title of the TV screen,
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


# ---------------------------------------------------------------- the TV camera (TvCamera)

const NOBODY: PackedByteArray = [0, 0, 0, 0, 0]


func test_the_tv_camera_follows_the_front_first() -> void:
	# Five boards in race order, all far apart and far from their marks: the leader most, then down the order.
	var positions: PackedVector2Array = PackedVector2Array([Vector2(0, -900), Vector2(0, -600), Vector2(0, -300), Vector2(0, 0), Vector2(0, 300)])
	var far: PackedFloat32Array = PackedFloat32Array([INF, INF, INF, INF, INF])
	var weights: PackedFloat32Array = TvCamera.story_weights(positions, far, NOBODY, NOBODY, NOBODY, -1)
	for i: int in 4:
		assert_gt(weights[i], weights[i + 1], "place %d before place %d" % [i + 1, i + 2])


func test_a_fight_a_mark_or_a_place_gained_lifts_a_board_at_the_back() -> void:
	# Boards 3 and 4 side by side at the back; the same fleet with board 4 alone at its mark; board 4 gained a place.
	var apart: PackedVector2Array = PackedVector2Array([Vector2(0, -900), Vector2(0, -600), Vector2(0, -300), Vector2(500, 0), Vector2(-500, 0)])
	var fight: PackedVector2Array = PackedVector2Array([Vector2(0, -900), Vector2(0, -600), Vector2(0, -300), Vector2(0, 0), Vector2(10, 0)])
	var far: PackedFloat32Array = PackedFloat32Array([INF, INF, INF, INF, INF])
	var at_mark: PackedFloat32Array = PackedFloat32Array([INF, INF, INF, INF, 30.0])
	var alone: float = TvCamera.story_weights(apart, far, NOBODY, NOBODY, NOBODY, -1)[4]
	assert_gt(TvCamera.story_weights(fight, far, NOBODY, NOBODY, NOBODY, -1)[4], alone, "a fight")
	assert_gt(TvCamera.story_weights(apart, at_mark, NOBODY, NOBODY, NOBODY, -1)[4], alone, "a mark")
	assert_gt(TvCamera.story_weights(apart, far, NOBODY, PackedByteArray([0, 0, 0, 0, 1]), NOBODY, -1)[4], alone, "a place gained")


func test_the_front_counts_more_than_a_fight_at_the_back_and_a_late_starter_little() -> void:
	# Eight boards: the leader alone; boards 6 and 7 side by side at the back; board 5 still to start after the gun.
	var positions: PackedVector2Array = PackedVector2Array([Vector2(0, -900), Vector2(0, -700), Vector2(0, -500), Vector2(0, -300),
		Vector2(400, 0), Vector2(-400, 0), Vector2(0, 300), Vector2(10, 300)])
	var far: PackedFloat32Array = PackedFloat32Array([INF, INF, INF, INF, INF, INF, INF, INF])
	var none: PackedByteArray = PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0])
	var late: PackedByteArray = PackedByteArray([0, 0, 0, 0, 0, 1, 0, 0])
	var weights: PackedFloat32Array = TvCamera.story_weights(positions, far, none, none, late, -1)
	assert_gt(weights[0], weights[6] + weights[7], "the leader alone beats the fight at the back")
	assert_lt(weights[5], weights[4], "a late starter less than a board alone")


func test_the_board_on_the_screen_and_a_finished_board_are_picked_less() -> void:
	var positions: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(500, 0), Vector2(-500, 0)])
	var far: PackedFloat32Array = PackedFloat32Array([INF, INF, INF])
	var none: PackedByteArray = PackedByteArray([0, 0, 0])
	var plain: PackedFloat32Array = TvCamera.story_weights(positions, far, none, none, none, -1)
	var shown: PackedFloat32Array = TvCamera.story_weights(positions, far, none, none, none, 1)
	assert_almost_eq(shown[1], plain[1] * 0.5, 1e-6, "the one on the screen: half")
	var finished: PackedFloat32Array = TvCamera.story_weights(positions, far, PackedByteArray([0, 0, 1]), none, none, -1)
	assert_lt(finished[2], 0.5, "finished")


func test_a_finished_board_close_by_is_no_fight() -> void:
	var positions: PackedVector2Array = PackedVector2Array([Vector2(0, 0), Vector2(5, 0)])
	var far: PackedFloat32Array = PackedFloat32Array([INF, INF])
	var none: PackedByteArray = PackedByteArray([0, 0])
	var weights: PackedFloat32Array = TvCamera.story_weights(positions, far, PackedByteArray([1, 0]), none, none, -1)
	assert_almost_eq(weights[1], 0.3 + TvCamera.FRONT_WORTH[1], 1e-6, "only a racing board makes a fight")


func test_the_tv_camera_never_shows_the_same_shot_twice_and_only_drones_while_racing() -> void:
	for last: TvCamera.Shot in TvCamera.DRONE_SHOTS:
		for near_mark: bool in [false, true]:
			for fight: bool in [false, true]:
				for step: int in 20:
					var next: TvCamera.Shot = TvCamera.pick_shot(near_mark, fight, last, step / 20.0)
					assert_ne(next, last, "not %s again" % last)
					assert_true(TvCamera.DRONE_SHOTS.has(next), "a drone or the helicopter")


func test_the_mark_shot_comes_only_near_a_mark_and_the_group_only_in_a_fight() -> void:
	var seen_mark: bool = false
	var seen_group: bool = false
	for step: int in 100:
		var dice: float = step / 100.0
		assert_ne(TvCamera.pick_shot(false, false, TvCamera.Shot.ORBIT, dice), TvCamera.Shot.MARK)
		assert_ne(TvCamera.pick_shot(false, false, TvCamera.Shot.ORBIT, dice), TvCamera.Shot.GROUP)
		seen_mark = seen_mark or TvCamera.pick_shot(true, false, TvCamera.Shot.ORBIT, dice) == TvCamera.Shot.MARK
		seen_group = seen_group or TvCamera.pick_shot(false, true, TvCamera.Shot.ORBIT, dice) == TvCamera.Shot.GROUP
	assert_true(seen_mark, "near a mark, the mark's shot")
	assert_true(seen_group, "in a fight, the group")


func test_the_start_is_the_wide_shot_then_the_committee_boat_then_the_leaders() -> void:
	assert_eq(TvCamera.start_part(false, -20.0), -1, "no countdown yet")
	assert_eq(TvCamera.start_part(true, -90.0), -1, "early in a long countdown: the usual shots")
	assert_eq(TvCamera.start_part(true, -30.0), 0, "the line from high behind it")
	assert_eq(TvCamera.start_part(true, -5.0), 1, "the committee boat's view down the line")
	assert_eq(TvCamera.start_part(true, 0.0), 1, "at the gun")
	assert_eq(TvCamera.start_part(true, 5.0), 1, "just after the gun: who is over early")
	assert_eq(TvCamera.start_part(true, 10.0), 2, "the leaders leaving the line")
	assert_eq(TvCamera.start_part(true, 60.0), -1, "racing")
	assert_eq(TvCamera.start_part(true, 0.0, true), -1, "a race that ended")


func test_the_committee_boat_looks_down_the_line_from_behind_the_boat() -> void:
	var boat: Vector3 = Vector3(100.0, 0.0, 0.0)
	var pin: Vector3 = Vector3(-100.0, 0.0, 0.0)
	var view: PackedVector3Array = TvCamera.line_view(boat, pin)
	assert_almost_eq(view[0].x, 100.0 + TvCamera.LINE_BEHIND_M, 1e-4, "behind the boat, on the line's line")
	assert_almost_eq(view[0].z, 0.0, 1e-4)
	assert_almost_eq(view[0].y, TvCamera.LINE_UP_M, 1e-4, "a few metres up")
	assert_almost_eq(view[1].x, -100.0, 1e-4, "looking at the pin")
	var down_the_line: Vector3 = (view[1] - view[0]).normalized()
	assert_gt(down_the_line.dot((pin - boat).normalized()), 0.99, "straight down the line")


func test_on_a_short_line_the_committee_boat_aims_past_the_pin_and_stays_level() -> void:
	# A 60 m line: aimed at the pin the camera would tilt down 10 degrees and show the boat's flag.
	var view: PackedVector3Array = TvCamera.line_view(Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, -60.0))
	assert_almost_eq(view[1].z, -TvCamera.LINE_AIM_M, 1e-4, "aimed down the line's line, past the pin")
	assert_almost_eq(view[1].x, 0.0, 1e-4)
	var tilt_deg: float = rad_to_deg(asin((view[0].y - view[1].y) / view[0].distance_to(view[1])))
	assert_lt(tilt_deg, 5.0, "nearly level")


func test_the_orbit_offset_sits_behind_a_board_at_its_heading() -> void:
	# A board heading north (-Z): the point behind it is to the south (+Z).
	var behind: Vector3 = TvCamera.orbit_offset(TvCamera._behind_rad(Vector3.FORWARD), 0.0, 10.0)
	assert_almost_eq(behind.z, 10.0, 1e-4)
	assert_almost_eq(behind.x, 0.0, 1e-4)
	var high: Vector3 = TvCamera.orbit_offset(0.0, TvCamera.ORBIT_ELEVATION_RAD, TvCamera.ORBIT_M)
	assert_almost_eq(high.length(), TvCamera.ORBIT_M, 1e-3)
	assert_gt(high.y, 50.0, "the helicopter is high")


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
