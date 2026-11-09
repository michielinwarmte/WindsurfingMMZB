extends GutTest
## The race tool's phase S options (the training method, 9 November 2026): only drops that can reach the start line
## with 30 s to spare (--start_spare_s, Max's choice), the start measures at the gun, and the start-only race's end.

const RunRace: GDScript = preload("res://dev/run_race.gd")


func _race_with_one_board(at: Vector2, prestart_s: float) -> Array:
	var course: Course = RaceCourses.t1_loop(270.0, Vector2.ZERO)
	var race: RaceSim = RaceSim.new(course, 1, prestart_s)
	var entries: Array = RunRace.make_entries(race, course, PackedStringArray(["allrounder"]), 15.0, 50.0, 1)
	entries[0].sim.reset(Vector3(at.x, 0.0, at.y), 0.0)
	race.update_board(0, at)
	return [race, entries, course]


func test_a_drop_is_reachable_with_the_spare_seconds() -> void:
	assert_true(RunRace.start_reachable(90.0, 120.0, 30.0), "90 s of a 120 s countdown leaves 30 s")
	assert_false(RunRace.start_reachable(90.5, 120.0, 30.0), "half a second short of the spare")
	assert_true(RunRace.start_reachable(0.0, 120.0, 30.0))


func test_a_board_far_from_the_line_is_too_far_for_a_short_countdown() -> void:
	var near: Array = _race_with_one_board(Vector2(0.0, 60.0), 120.0)
	var course: Course = near[2]
	var target: Vector2 = (near[0] as RaceSim).steps()[0].target()
	var typed_near: Array[RunRace.Entry] = []
	typed_near.assign(near[1])
	assert_eq(RunRace.drop_too_far(near[0], typed_near, course.axis_deg, 15.0, 120.0, 30.0), "",
		"%.0f m from the line's middle: it can make a 2 minute countdown" % target.distance_to(Vector2(0.0, 60.0)))
	var far: Array = _race_with_one_board(target + Vector2(0.0, 3000.0), 120.0)
	var typed_far: Array[RunRace.Entry] = []
	typed_far.assign(far[1])
	var why: String = RunRace.drop_too_far(far[0], typed_far, course.axis_deg, 15.0, 120.0, 30.0)
	assert_string_contains(why, "needs", "3 km off: too far for a 2 minute countdown")
	assert_eq(RunRace.drop_too_far(far[0], typed_far, course.axis_deg, 15.0, 3000.0, 30.0), "", "but not for a 50 minute one")


func test_the_start_only_race_is_over_once_every_board_has_started() -> void:
	var setup: Array = _race_with_one_board(Vector2(0.0, 60.0), 10.0)
	var race: RaceSim = setup[0]
	var typed: Array[RunRace.Entry] = []
	typed.assign(setup[1])
	assert_false(RunRace.all_over_the_line(race, typed), "not started yet")
	typed[0].aground = true
	assert_true(RunRace.all_over_the_line(race, typed), "a board aground has nothing more to do")


func test_the_gun_notes_how_far_behind_the_line() -> void:
	var setup: Array = _race_with_one_board(Vector2.ZERO, 10.0)
	var race: RaceSim = setup[0]
	var line: RaceStep = race.steps()[0]
	# 40 m behind the line's middle, against the way the first leg goes.
	var behind: Vector2 = line.target() - line.in_dir.normalized() * 40.0
	var typed: Array[RunRace.Entry] = []
	typed.assign(setup[1])
	typed[0].sim.reset(Vector3(behind.x, 0.0, behind.y), 0.0)
	race.update_board(0, behind)
	RunRace.note_the_gun(typed[0], race, 0)
	assert_almost_eq(typed[0].gun_behind_m, 40.0, 0.5, "40 m behind the line")
	assert_almost_eq(typed[0].gun_to_line_m, 40.0, 0.5, "40 m from the line's segment")
	assert_false(typed[0].gun_ocs)
