extends GutTest
## The course maker's courses (MAP_SILVAPLANA_PLAN.md, W4a): the iQFOiL templates have the class's
## distances for the wind, mark 1 dead upwind and the committee boat on the right; the rounding
## sides read from the diagrams agree with the way the course turns; the mirror-image courses are
## mirror images; gates and lines keep their size when a course is scaled; turning, moving, saving
## and loading; and the warnings when a course hits land.

const CONFIG_PATH: String = "res://maps/silvaplana/map_config.tres"
const RULES_PATH: String = "res://maps/course/iqfoil_courses.tres"
const SHORE_GRID_PATH: String = "res://maps/silvaplana/terrain/shore_heights.json"
const SAVE_PATH: String = "user://test_course.json"
const NM: float = 1852.0

var _config: MapConfig
var _rules: CourseRules


func before_all() -> void:
	_config = load(CONFIG_PATH)
	_rules = load(RULES_PATH)


func after_all() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func test_the_class_distances_for_the_wind() -> void:
	assert_almost_eq(_rules.windward_leeward_mark1_m(11.0), 0.9 * NM, 0.01, "Windward-leeward, 10 to 13 kt")
	assert_almost_eq(_rules.windward_leeward_mark1_m(13.0), 1.0 * NM, 0.01, "13 kt is in the 13 to 17 kt range")
	assert_almost_eq(_rules.windward_leeward_mark1_m(18.0), 1.05 * NM, 0.01, "17 kt and more")
	assert_almost_eq(_rules.trapezoid_mark1_m(11.0), 0.85 * NM, 0.01, "Trapezoid, 10 to 13 kt")
	assert_almost_eq(_rules.trapezoid_mark1_m(15.0), 0.95 * NM, 0.01)
	assert_almost_eq(_rules.trapezoid_mark1_m(25.0), 1.0 * NM, 0.01)
	assert_almost_eq(_rules.upwind_start_line_m(40), 40 * 2.2 * 3.0, 0.01, "Boards x 2.20 m x 3")
	assert_almost_eq(_rules.reaching_start_line_m(24), 168.0, 0.01, "About 7 m per board")
	assert_almost_eq(_rules.reaching_start_line_m(4), 40.0, 0.01, "At least 40 m")
	assert_almost_eq(_rules.reaching_start_line_m(30), 170.0, 0.01, "At most 170 m")


func test_mark_1_lies_dead_upwind_with_the_committee_boat_on_the_right() -> void:
	var start: Vector2 = Vector2(100.0, 200.0)
	var course: Course = CourseTemplates.build("LG2", _rules, 15.0, 40, 222.0, start)
	assert_almost_eq(course.start_middle().distance_to(start), 0.0, 0.01, "The start line's middle is where it was put")
	var mark1: Vector2 = course.mark("1").position
	assert_almost_eq(start.distance_to(mark1), 1.0 * NM, 0.01, "Mark 1 at 1.00 nm at 15 kt")
	assert_almost_eq(Course.bearing_deg(start, mark1), 222.0, 0.01, "Mark 1 lies the way the wind comes from")
	var boat: Vector2 = course.mark(CourseMark.START_BOAT).position
	assert_almost_eq(Course.bearing_deg(start, boat), 312.0, 0.01, "Looking upwind (222 degrees), the committee boat is on the right")
	assert_almost_eq(boat.distance_to(course.mark(CourseMark.START_PIN).position), 264.0, 0.01, "40 boards x 2.20 m x 3")
	assert_almost_eq(course.mark("4S").position.distance_to(course.mark("4P").position), 75.0, 0.01, "The gate is 75 m wide")
	assert_almost_eq(Course.bearing_deg(course.mark("4P").position, course.mark("4S").position), 132.0, 0.01,
		"4S is on the left looking upwind, so a board running down leaves it to starboard")
	assert_almost_eq(course.finish_middle().distance_to(course.mark("4S").position), 450.0, 0.01, "The reach to the finish")


func test_the_rounding_sides_agree_with_the_turns() -> void:
	for id: String in CourseTemplates.ALL:
		for axis_deg: float in [0.0, 222.0]:
			var course: Course = CourseTemplates.build(id, _rules, 15.0, CourseTemplates.default_boards(id), axis_deg, Vector2.ZERO)
			var legs: Array[Course.Leg] = course.legs()
			var checked: int = 0
			for i: int in range(1, legs.size()):
				var step: String = legs[i].from_name
				if step.contains("/"):
					continue  # a gate: either mark
				var turn: float = Course.turn_deg(legs[i - 1].bearing_deg(), legs[i].bearing_deg())
				if absf(turn) > 170.0:
					continue  # turning back the way it came: either side works geometrically
				var expected: CourseMark.Rounding = CourseMark.Rounding.STARBOARD if turn > 0.0 else CourseMark.Rounding.PORT
				assert_eq(course.mark(step).side, expected, "%s at %.0f degrees: mark %s, turning %.0f degrees" % [id, axis_deg, step, turn])
				checked += 1
			assert_gt(checked, 0, id + ": at least one rounding is checked")


func test_the_legs_follow_the_notice_of_race() -> void:
	var expected: Dictionary[String, String] = {
		"LG2": "Start-1-4S/4P-1-4S-Finish", "LR2": "Start-1-4S/4P-1-4P-Finish",
		"O2": "Start-1-2-3S/3P-2-3P-Finish", "I2": "Start-1-4S/4P-1-2-3P-Finish",
		"US3": "Start-1-2-3-Finish", "US4": "Start-1-2-3-4-Finish",
		"PD3": "Start-1-2-3-Finish", "SD3": "Start-1-2-3-Finish",
		"PM1": "Start-1-2S/2P-1-2P-Finish", "SM1": "Start-1-2S/2P-1-2S-Finish"}
	for id: String in expected:
		var course: Course = CourseTemplates.build(id, _rules, 15.0, 24, 0.0, Vector2.ZERO)
		assert_eq(course.sequence, expected[id], id)
		var legs: Array[Course.Leg] = course.legs()
		assert_eq(legs.size(), expected[id].split("-").size() - 1, id + ": one leg between each two steps")
		for leg: Course.Leg in legs:
			assert_gt(leg.length_m(), 10.0, "%s: the leg %s to %s has a length" % [id, leg.from_name, leg.to_name])


func test_the_mirror_courses() -> void:
	var left: Course = CourseTemplates.build("LG2", _rules, 15.0, 40, 0.0, Vector2.ZERO)
	var right: Course = CourseTemplates.build("LR2", _rules, 15.0, 40, 0.0, Vector2.ZERO)
	# Axis 0: the wind from the north, so looking upwind the right is east (+X).
	assert_lt(left.finish_middle().x, -300.0, "LG2 finishes to the left")
	assert_gt(right.finish_middle().x, 300.0, "LR2 finishes to the right")
	var pd3: Course = CourseTemplates.build("PD3", _rules, 15.0, 24, 0.0, Vector2.ZERO)
	var sd3: Course = CourseTemplates.build("SD3", _rules, 15.0, 24, 0.0, Vector2.ZERO)
	for id: String in ["1", "2", "3", CourseMark.FINISH_BOAT, CourseMark.FINISH_PIN, CourseMark.START_BOAT]:
		var a: Vector2 = pd3.mark(id).position
		var b: Vector2 = sd3.mark(id).position
		assert_almost_eq(Vector2(-a.x, a.y).distance_to(b), 0.0, 0.01, "SD3 is PD3 mirrored: " + id)
	assert_ne(pd3.mark("1").side, sd3.mark("1").side, "Mirrored, mark 1 is left on the other side")
	assert_gt(CourseTemplates.build("PM1", _rules, 15.0, 4, 0.0, Vector2.ZERO).finish_middle().x, 300.0, "PM1 finishes to the right")
	assert_lt(CourseTemplates.build("SM1", _rules, 15.0, 4, 0.0, Vector2.ZERO).finish_middle().x, -300.0, "SM1 finishes to the left")


func test_the_reaching_start() -> void:
	var course: Course = CourseTemplates.build("PD3", _rules, 15.0, 24, 0.0, Vector2.ZERO)
	var pin: Vector2 = course.mark(CourseMark.START_PIN).position
	var boat: Vector2 = course.mark(CourseMark.START_BOAT).position
	assert_almost_eq(Course.bearing_deg(pin, boat), 0.0, 0.01, "The line runs along the wind, the committee boat at the upwind end")
	assert_almost_eq(pin.distance_to(course.mark("1").position), 600.0, 0.01, "Mark 1 is 600 m from the pin")
	assert_almost_eq(Course.bearing_deg(pin, course.mark("1").position), 90.0, 0.01, "at 90 degrees from the wind")
	assert_almost_eq(course.mark("1").position.distance_to(course.mark("2").position), 0.45 * NM, 0.01, "Mark 1 to 2: 0.45 nm")
	var legs: Array[Course.Leg] = course.legs()
	assert_almost_eq(absf(Course.turn_deg(legs[2].bearing_deg(), legs[3].bearing_deg())), 180.0 - 25.0, 0.01,
		"25 degrees between the slalom legs")


func test_scaling_keeps_the_gates_and_lines() -> void:
	var course: Course = CourseTemplates.build("O2", _rules, 15.0, 40, 222.0, Vector2(50.0, -80.0))
	var mark1_m: float = course.start_middle().distance_to(course.mark("1").position)
	course.set_size(70.0)
	assert_almost_eq(course.size_percent, 70.0, 0.001)
	assert_almost_eq(course.start_middle().distance_to(course.mark("1").position), mark1_m * 0.7, 0.01, "70 %")
	assert_almost_eq(course.mark("3S").position.distance_to(course.mark("3P").position), 75.0, 0.01, "The gate keeps its width")
	assert_almost_eq(course.mark(CourseMark.START_BOAT).position.distance_to(course.mark(CourseMark.START_PIN).position), 264.0, 0.01, "The start line keeps its length")
	assert_almost_eq(course.mark(CourseMark.FINISH_BOAT).position.distance_to(course.mark(CourseMark.FINISH_PIN).position), 35.0, 0.01, "The finish line too")
	assert_almost_eq(course.start_middle().distance_to(Vector2(50.0, -80.0)), 0.0, 0.01, "Scaled about the start line's middle")


func test_turning_and_moving() -> void:
	var course: Course = CourseTemplates.build("LR2", _rules, 15.0, 40, 222.0, Vector2.ZERO)
	var mark1_m: float = course.mark("1").position.length()
	course.set_axis(240.0)
	assert_almost_eq(course.axis_deg, 240.0, 0.001)
	assert_almost_eq(Course.bearing_deg(course.start_middle(), course.mark("1").position), 240.0, 0.01, "Mark 1 follows the axis")
	assert_almost_eq(course.mark("1").position.length(), mark1_m, 0.01, "Turning keeps the distances")
	course.set_start_line_length(100.0)
	assert_almost_eq(course.mark(CourseMark.START_BOAT).position.distance_to(course.mark(CourseMark.START_PIN).position), 100.0, 0.01)
	assert_almost_eq(course.start_middle().length(), 0.0, 0.01, "The start line keeps its middle")
	var before: Vector2 = course.mark("4S").position
	course.move_by(Vector2(30.0, -40.0))
	assert_almost_eq(course.mark("4S").position.distance_to(before + Vector2(30.0, -40.0)), 0.0, 0.001)


func test_save_and_load() -> void:
	var course: Course = CourseTemplates.build("I2", _rules, 15.0, 40, 222.0, Vector2(123.4, -567.8))
	course.name = "Test course"
	course.set_size(80.0)
	assert_eq(course.save(SAVE_PATH, _config), OK)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	assert_almost_eq(float(data["marks"][0]["east"]), 2780500.0 + course.marks[0].position.x, 0.01, "Saved in LV95")
	var loaded: Course = Course.load_from(SAVE_PATH, _config)
	assert_not_null(loaded)
	if loaded == null:
		return
	assert_eq(loaded.name, "Test course")
	assert_eq(loaded.template, "I2")
	assert_eq(loaded.sequence, course.sequence)
	assert_almost_eq(loaded.axis_deg, 222.0, 0.05)
	assert_almost_eq(loaded.size_percent, 80.0, 0.001)
	assert_eq(loaded.boards, 40)
	assert_eq(loaded.marks.size(), course.marks.size())
	for mark: CourseMark in course.marks:
		var back: CourseMark = loaded.mark(mark.id)
		assert_almost_eq(back.position.distance_to(mark.position), 0.0, 0.01, mark.id + " to the centimetre")
		assert_eq(back.side, mark.side, mark.id + " keeps its side")


func test_the_land_warnings() -> void:
	# A made-up map: water west of x = 500, land east of it, nothing beyond z = -3000.
	var height_at: Callable = func(x: float, z: float) -> float:
		if z < -3000.0:
			return NAN
		return 5.0 if x > 500.0 else -10.0
	var course: Course = CourseTemplates.build("LG2", _rules, 15.0, 40, 0.0, Vector2.ZERO)
	assert_eq(course.problems(height_at).size(), 0, "All on the water")
	course.mark("1").position = Vector2(600.0, -1500.0)
	var problems: PackedStringArray = course.problems(height_at)
	assert_has(problems, "On land: 1")
	assert_has(problems, "Legs over land: Start → 1, 1 → 4S/4P, 4S/4P → 1, 1 → 4S")
	assert_eq(course.marks_not_on_water(height_at), [course.mark("1")] as Array[CourseMark])
	course.move_by(Vector2(0.0, -3500.0))
	assert_has(course.problems(height_at), "Off the map: start boat, start pin, 1, 4S, 4P, finish boat, finish pin")


func test_names_for_new_marks() -> void:
	var course: Course = CourseTemplates.build("LG2", _rules, 15.0, 40, 0.0, Vector2.ZERO)
	assert_eq(course.next_mark_id(), "5", "After mark 1 and gate 4")
	course.add_mark("5", Vector2(10.0, 10.0))
	assert_eq(course.next_mark_id(), "6")
	assert_eq(CourseTemplates.build("PD3", _rules, 15.0, 24, 0.0, Vector2.ZERO).next_mark_id(), "4")


func test_putting_a_mark_into_legs() -> void:
	var course: Course = CourseTemplates.build("LG2", _rules, 15.0, 40, 0.0, Vector2.ZERO)
	course.add_mark("5", Vector2(30.0, -1500.0))
	# The legs: 0 Start-1, 1 the first run 1-4S/4P, 2 the second beat, 3 the last run 1-4S, 4 the reach to the finish.
	course.insert_into_legs("5", [3, 1] as Array[int])
	assert_eq(course.sequence, "Start-1-5-4S/4P-1-5-4S-Finish", "Into both runs, in either order")
	assert_eq(course.legs().size(), 7)


func test_removing_marks() -> void:
	var trapezoid: Course = CourseTemplates.build("O2", _rules, 15.0, 40, 0.0, Vector2.ZERO)
	trapezoid.remove_mark("2")
	assert_null(trapezoid.mark("2"))
	assert_eq(trapezoid.sequence, "Start-1-3S/3P-3P-Finish")
	var course: Course = CourseTemplates.build("LG2", _rules, 15.0, 40, 0.0, Vector2.ZERO)
	course.remove_mark("4P")
	assert_null(course.mark("4S"), "A gate goes as a whole")
	assert_eq(course.sequence, "Start-1-Finish", "Mark 1 twice in a row is sailed once")
	course.remove_mark(CourseMark.START_PIN)
	assert_not_null(course.mark(CourseMark.START_PIN), "The lines stay")


func test_renaming_marks() -> void:
	var course: Course = CourseTemplates.build("LG2", _rules, 15.0, 40, 0.0, Vector2.ZERO)
	assert_eq(course.rename_mark("1", "1a"), "")
	assert_eq(course.sequence, "Start-1a-4S/4P-1a-4S-Finish", "Renamed in the order too")
	assert_ne(course.rename_mark("1a", "4S"), "", "Not the name of another mark")
	assert_ne(course.rename_mark("1a", "5P"), "", "Not a gate's name")
	assert_ne(course.rename_mark("1a", "start"), "", "Not Start")
	assert_ne(course.rename_mark("1a", "1-2"), "", "Letters and digits only")
	assert_ne(course.rename_mark("4S", "7"), "", "A gate's marks keep their names")
	assert_eq(course.sequence, "Start-1a-4S/4P-1a-4S-Finish", "A refused name changes nothing")


func test_typing_the_order() -> void:
	var course: Course = CourseTemplates.build("LG2", _rules, 15.0, 40, 0.0, Vector2.ZERO)
	assert_eq(course.set_sequence(" start - 1 - 4s/4p - 1 - 4P - finish "), "", "Spaces and small letters are fine")
	assert_eq(course.sequence, "Start-1-4S/4P-1-4P-Finish")
	for wrong: String in ["1-4S-Finish", "Start-1-4S", "Start-Finish", "Start-7-Finish", "Start-1-1-Finish",
			"Start-1-4S/1-Finish", "Start-1-4S/4P/1-Finish", "Start-start boat-Finish"]:
		assert_ne(course.set_sequence(wrong), "", "Refused: " + wrong)
	assert_eq(course.sequence, "Start-1-4S/4P-1-4P-Finish", "A refused order changes nothing")
	course.add_mark("5", Vector2(10.0, -900.0))
	assert_eq(course.marks_not_in_order(), PackedStringArray(["5"]))
	assert_eq(course.set_sequence("Start-1-5-4S/4P-Finish"), "")
	assert_eq(course.marks_not_in_order(), PackedStringArray())


func test_the_side_a_new_mark_is_left_on() -> void:
	# A leg from the south to the north (game Z goes south).
	var from: Vector2 = Vector2(0.0, 0.0)
	var to: Vector2 = Vector2(0.0, -1000.0)
	assert_eq(Course.natural_side(from, Vector2(-100.0, -500.0), to), CourseMark.Rounding.STARBOARD,
		"Bent out to the west: the board turns right round it, leaving it to starboard")
	assert_eq(Course.natural_side(from, Vector2(100.0, -500.0), to), CourseMark.Rounding.PORT, "Bent out to the east: port")
	assert_eq(Course.natural_side(from, Vector2(1.0, -500.0), to), CourseMark.Rounding.PORT, "On the line: port")


func test_on_lake_silvaplana() -> void:
	# The start line's middle in the north-east part of the lake, the Maloja from 222 degrees, 15 kt.
	var shore: TerrainGrid = TerrainGrid.load_from(SHORE_GRID_PATH)
	var height_at: Callable = func(x: float, z: float) -> float:
		return shore.height_at(x, z) if shore.contains(x, z) else NAN
	var at: Vector3 = _config.lv95_to_game(2781318.0, 1147209.0, _config.lake_level_m)
	var windward_leeward: Course = CourseTemplates.build("LG2", _rules, 15.0, 40, 222.0, Vector2(at.x, at.z))
	assert_eq(windward_leeward.problems(height_at), PackedStringArray(), "A full windward-leeward course fits along the lake")
	var trapezoid: Course = CourseTemplates.build("O2", _rules, 15.0, 40, 222.0, Vector2(at.x, at.z))
	assert_has(trapezoid.marks_not_on_water(height_at), trapezoid.mark("2"), "The full trapezoid's reach is wider than the lake")
