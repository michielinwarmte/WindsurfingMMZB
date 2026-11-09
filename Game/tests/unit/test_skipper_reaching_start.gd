extends GutTest
## reaching_loop_excess_s (Skipper._loop_excess_s(); the training method's phase S, 9 November 2026): on a start line
## its hold's track runs at (a reaching start: the line along the wind, as on the PM1 and SM1 templates), a skipper who
## loops sails its timing loop with less time to spare than START_LOOP_EXCESS_S: held back straight at the line from
## 150 m with 67 s to spare, the board came to the line 12 to 18 s early and was over at the gun.

const RunRace: GDScript = preload("res://dev/run_race.gd")
const WIND_DEG: float = 270.0


func _skipper() -> Skipper:
	var course: Course = RaceCourses.t1_loop(WIND_DEG, Vector2.ZERO)
	var race: RaceSim = RaceSim.new(course, 1, 60.0)
	var entries: Array = RunRace.make_entries(race, course, PackedStringArray(["allrounder"]), 17.0, 50.0, 1)
	return entries[0].skipper as Skipper


func test_it_is_off_unless_switched_on() -> void:
	assert_eq(SkipperConfig.new().reaching_loop_excess_s, 0.0, "off by default until the suite says it wins")


func test_a_reaching_starts_hold_loops_with_less_to_spare() -> void:
	var skipper: Skipper = _skipper()
	var forward: Vector2 = Vector2(0.0, -1.0)  # the first leg north, the line east-west along a west wind
	var at_the_line: Vector2 = Course.direction_of(0.0)  # a beam reach north: straight at the line
	var along_the_line: Vector2 = Course.direction_of(85.0)  # nearly along it
	assert_eq(skipper._loop_excess_s(at_the_line, forward), Skipper.START_LOOP_EXCESS_S, "off: as before")
	skipper.config.reaching_loop_excess_s = 5.0
	assert_eq(skipper._loop_excess_s(at_the_line, forward), 5.0, "a hold straight at the line: the reaching start's excess")
	assert_eq(skipper._loop_excess_s(along_the_line, forward), Skipper.START_LOOP_EXCESS_S,
		"a hold along the line (an upwind start): as before")


func test_no_timing_loop_from_beyond_start_away_max_m() -> void:
	var skipper: Skipper = _skipper()
	var spot: Vector2 = Vector2.ZERO
	assert_false(skipper._too_far_to_loop(Vector2(0.0, 250.0), spot), "off: a loop from anywhere, as before")
	skipper.config.loop_within_away_max = true
	assert_true(skipper._too_far_to_loop(Vector2(0.0, 250.0), spot), "250 m out: no loop (it would turn back at once)")
	assert_false(skipper._too_far_to_loop(Vector2(0.0, 150.0), spot), "150 m out: a loop")
	assert_false(SkipperConfig.new().loop_within_away_max, "off by default until the suite says it wins")
