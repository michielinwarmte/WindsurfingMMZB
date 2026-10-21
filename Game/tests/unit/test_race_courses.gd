extends GutTest
## The race courses (race/race_courses.gd, RACING_PLAN.md "The two courses"): T1 is the LG2 at 30 %
## set to the wind, with its 60 m start line and the gate 150 m above it; T2's stand-in is a PD3;
## saved courses load by name; and the boards wait 150 m behind the start line on a beam reach.

const CONFIG_PATH: String = "res://maps/silvaplana/map_config.tres"
const RULES_PATH: String = "res://maps/course/iqfoil_courses.tres"


func test_t1_mark_1_lies_upwind_of_the_start() -> void:
	for wind_from_deg: float in [270.0, 222.0, 15.0, 180.0]:
		var course: Course = RaceCourses.t1_loop(wind_from_deg, Vector2(40.0, -150.0))
		var bearing: float = Course.bearing_deg(course.start_middle(), course.mark("1").position)
		assert_almost_eq(Course.turn_deg(wind_from_deg, bearing), 0.0, 1.0, "Mark 1 upwind in a wind from %.0f" % wind_from_deg)
		assert_almost_eq(course.axis_deg, wind_from_deg, 0.001, "The course is set for the wind")


func test_t1_has_the_plan_s_sizes() -> void:
	var course: Course = RaceCourses.t1_loop(270.0, Vector2(40.0, -150.0))
	assert_almost_eq(course.start_middle().distance_to(Vector2(40.0, -150.0)), 0.0, 0.01, "The start line's middle is where it was asked")
	var beat_m: float = course.start_middle().distance_to(course.mark("1").position)
	assert_between(beat_m, 540.0, 570.0, "The beat is about 556 m (30 % of a nautical mile)")
	var line_m: float = course.mark(CourseMark.START_BOAT).position.distance_to(course.mark(CourseMark.START_PIN).position)
	assert_true(line_m >= 60.0 - 0.001, "The start line is at least 60 m (%.1f m)" % line_m)
	var upwind: Vector2 = Course.direction_of(270.0)
	var gate_above_m: float = (course.point_of("4S/4P") - course.start_middle()).dot(upwind)
	assert_almost_eq(gate_above_m, 150.0, 0.01, "The leeward gate 150 m above the start line")
	assert_almost_eq(course.mark("4S").position.distance_to(course.mark("4P").position), 75.0, 0.01, "The gate 75 m wide")
	assert_eq(course.size_percent, 30.0)
	assert_eq(course.name, "T1 training loop")


func test_t1_is_sailed_in_lg2_s_order() -> void:
	var rules: CourseRules = load(RULES_PATH)
	var lg2: Course = CourseTemplates.build("LG2", rules, 15.0, 4, 270.0, Vector2.ZERO)
	var course: Course = RaceCourses.t1_loop(270.0, Vector2.ZERO)
	assert_eq(course.sequence, lg2.sequence, "Start, 1, the gate, 1, 4S, finish")
	assert_eq(course.template, "LG2")
	assert_eq(course.mark("1").side, CourseMark.Rounding.PORT, "Mark 1 to port")
	# The reach from the last gate mark to the finish keeps the template's angle from the wind.
	var reach: Vector2 = course.finish_middle() - course.mark("4S").position
	var from_wind_deg: float = absf(Course.turn_deg(270.0, Course.bearing_deg(Vector2.ZERO, reach)))
	assert_almost_eq(from_wind_deg, 95.0, 2.0, "The reach to the finish")


func test_a_missing_course_is_null() -> void:
	var config: MapConfig = load(CONFIG_PATH)
	assert_null(RaceCourses.load_named("no_such_course_here", config))
	assert_null(RaceCourses.load_named("", config))


func test_every_saved_course_loads_by_its_name() -> void:
	var config: MapConfig = load(CONFIG_PATH)
	var names: PackedStringArray = RaceCourses.saved_names()
	for course_name: String in names:
		assert_false(course_name.ends_with(".json"), "Names without .json")
		var course: Course = RaceCourses.load_named(course_name, config)
		assert_not_null(course, course_name + " loads")
		if course != null:
			assert_gt(course.marks.size(), 3, course_name + " has its marks")
	var sorted: PackedStringArray = names.duplicate()
	sorted.sort()
	assert_eq(names, sorted, "In order")


func test_the_t2_stand_in() -> void:
	var course: Course = RaceCourses.t2_stand_in(222.0, Vector2(500.0, -300.0))
	assert_eq(course.template, "PD3")
	assert_eq(course.sequence, "Start-1-2-3-Finish")
	assert_string_contains(course.name, "stand-in")
	assert_eq(course.size_percent, 100.0)
	assert_almost_eq(course.axis_deg, 222.0, 0.001)
	assert_almost_eq(course.bounds().get_center().distance_to(Vector2(500.0, -300.0)), 0.0, 0.01, "Centred where asked")


func test_the_boards_wait_150_m_behind_the_line_on_a_beam_reach() -> void:
	var t1: Course = RaceCourses.t1_loop(270.0, Vector2(0.0, 0.0))
	var spot: Vector2 = RaceCourses.pre_start_spot(t1)
	assert_almost_eq(spot.distance_to(t1.start_middle()), 150.0, 0.01, "150 m from the line's middle")
	assert_almost_eq(Course.turn_deg(270.0, Course.bearing_deg(spot, t1.start_middle())), 0.0, 0.1, "Downwind of an upwind start line")
	assert_almost_eq(RaceCourses.pre_start_heading_deg(t1), 180.0, 0.001, "A wind from the west: south, on starboard tack")
	# A reaching start: the line along the wind, mark 1 on its right looking upwind (PD3). The board
	# waits on the side away from mark 1 and heads toward it, a beam reach on port tack.
	var pd3: Course = RaceCourses.t2_stand_in(222.0, Vector2.ZERO)
	var behind: Vector2 = RaceCourses.pre_start_spot(pd3)
	assert_almost_eq(behind.distance_to(pd3.start_middle()), 150.0, 0.01)
	assert_gt(behind.distance_to(pd3.mark("1").position), pd3.start_middle().distance_to(pd3.mark("1").position), "Behind the line, away from mark 1")
	assert_almost_eq(RaceCourses.pre_start_heading_deg(pd3), 312.0, 0.001, "Toward mark 1, 90 degrees from the wind")


func test_a_template_by_name_is_a_race_course_at_the_size_asked() -> void:
	var full: Course = RaceCourses.template_named("template:O2", 0.0, Vector2.ZERO)
	assert_not_null(full)
	assert_eq(full.template, "O2")
	assert_eq(full.name, "O2 at 100 %")
	assert_true(RaceSim.new(full, 1, 0.0).steps().size() >= 5, "a race with its steps")
	var small: Course = RaceCourses.template_named("template:pd3@60", 90.0, Vector2(100.0, 50.0))
	assert_not_null(small)
	assert_eq(small.template, "PD3")
	assert_almost_eq(small.size_percent, 60.0, 1e-6)
	assert_almost_eq(small.start_middle().x, 100.0, 1e-3)
	assert_almost_eq(small.axis_deg, 90.0, 1e-6)
	var line_m: float = small.mark(CourseMark.START_BOAT).position.distance_to(small.mark(CourseMark.START_PIN).position)
	assert_true(line_m >= RaceCourses.T1_START_LINE_M - 1e-3, "the start line is at least 60 m")
	assert_null(RaceCourses.template_named("t1_loop", 0.0, Vector2.ZERO), "not a template name")
