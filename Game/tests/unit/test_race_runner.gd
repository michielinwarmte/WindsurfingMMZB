extends GutTest
## The race in a scene (RaceRunner): where the boards wait before the start, and the start menu's
## hand-over (RaceSetup). The runner itself needs the scene tree and the windsurfer scenes, and is
## checked with screenshots (RACING_PLAN.md, 9A).


func test_boards_wait_behind_the_line_spread_along_it_with_the_player_in_the_middle() -> void:
	var course: Course = RaceCourses.t1_loop(270.0, Vector2.ZERO)
	var race: RaceSim = RaceSim.new(course, 1, 30.0)
	var start: RaceStep = race.steps()[0]
	var spots: PackedVector2Array = RaceRunner.pre_start_spots(course, start, 4, 75.0)
	assert_eq(spots.size(), 4, "one spot per board")
	var middle: Vector2 = course.start_middle()
	var line_dir: Vector2 = (start.points[0] - start.points[1]).normalized()
	for spot: Vector2 in spots:
		var behind_m: float = (middle - spot).dot(start.in_dir)
		assert_almost_eq(behind_m, 75.0, 2.0, "75 m behind the line")
		var along_m: float = absf((spot - middle).dot(line_dir))
		assert_true(along_m <= 30.0, "within the 60 m line: %.1f m from its middle" % along_m)
	for i: int in range(1, spots.size()):
		assert_true(spots[0].distance_to(middle) <= spots[i].distance_to(middle) + 0.01, "the player nearest the middle")
	# Two boards are apart along the line.
	assert_true(spots[0].distance_to(spots[1]) > 5.0, "the boards do not share a spot")


func test_a_pending_race_setup_is_taken_once() -> void:
	RaceSetup.pending = RaceSetup.race("t1_loop")
	var taken: RaceSetup = RaceSetup.take()
	assert_eq(taken.course_name, "t1_loop")
	assert_eq(taken.skippers.size(), 3, "three opponents by default")
	assert_eq(taken.prestart_s, 60.0)
	assert_null(RaceSetup.take(), "taken once")
