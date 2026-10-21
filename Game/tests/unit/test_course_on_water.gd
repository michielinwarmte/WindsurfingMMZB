extends GutTest
## The course on the water (race/course_on_water.gd): a buoy for every rounding mark, the boats and
## pins at the ends of the lines; everything at the water's height at its spot (within 1 cm), tilted
## with the water's slope; the boats head to wind with their flags streaming downwind; the lines on
## the water off until asked for.

var _time_s: float = 3.7


## Waves of a few tens of metres, as a stand-in for the simulation's water.
static func _wavy_water(x: float, z: float, time_s: float) -> float:
	return 0.4 * sin(0.05 * x + time_s) + 0.2 * cos(0.07 * z - 0.5 * time_s)


func _clock() -> float:
	return _time_s


func _built(course: Course, height_at: Callable, wind_at: Callable = Callable()) -> CourseOnWater:
	var on_water: CourseOnWater = CourseOnWater.new()
	add_child_autofree(on_water)
	on_water.build(course, height_at, _clock, wind_at)
	return on_water


func test_a_buoy_for_every_rounding_mark_and_the_ends_of_the_lines() -> void:
	var course: Course = RaceCourses.t1_loop(270.0, Vector2(30.0, -150.0))
	var on_water: CourseOnWater = _built(course, _wavy_water)
	var rounding: int = 0
	for mark: CourseMark in course.marks:
		if not mark.is_line_end():
			rounding += 1
		assert_not_null(on_water.part_at(mark.id), "Something floats at " + mark.id)
	assert_eq(on_water.parts_of_kind(CourseOnWater.Kind.BUOY).size(), rounding, "One buoy per rounding mark (1, 4S, 4P)")
	assert_eq(rounding, 3)
	assert_eq(on_water.parts_of_kind(CourseOnWater.Kind.BOAT).size(), 2, "The committee boat and the finish boat")
	assert_eq(on_water.parts_of_kind(CourseOnWater.Kind.PIN).size(), 2, "A pin at each line's other end")
	assert_eq(on_water.part_at(CourseMark.START_BOAT).name, "Committee boat")
	assert_not_null(on_water.flag_at(CourseMark.START_BOAT), "The committee boat flies the wind flag")
	assert_not_null(on_water.flag_at(CourseMark.FINISH_BOAT))
	assert_eq(on_water.line_count(), 2, "A line for the start and one for the finish")


func test_everything_floats_at_the_water_s_height() -> void:
	var course: Course = RaceCourses.t1_loop(222.0, Vector2(-80.0, 40.0))
	var on_water: CourseOnWater = _built(course, _wavy_water)
	for step: int in 3:
		_time_s = 3.7 + 1.3 * step
		on_water.update_now()
		for mark: CourseMark in course.marks:
			var at: Vector3 = on_water.part_at(mark.id).global_position
			assert_almost_eq(at.y, _wavy_water(mark.position.x, mark.position.y, _time_s), 0.01, "%s on the water at %.1f s" % [mark.id, _time_s])
			assert_almost_eq(Vector2(at.x, at.z).distance_to(mark.position), 0.0, 0.001, mark.id + " stays at its mark")


func test_a_buoy_leans_with_the_water_s_slope() -> void:
	# Water rising 0.1 m per metre to the east: the surface's normal leans to the west.
	var slope: Callable = func(x: float, _z: float, _t: float) -> float: return 0.1 * x
	var course: Course = RaceCourses.t1_loop(270.0, Vector2.ZERO)
	var on_water: CourseOnWater = _built(course, slope)
	var up: Vector3 = on_water.part_at("1").global_transform.basis.y.normalized()
	var expected: Vector3 = Vector3(-0.1, 1.0, 0.0).normalized()
	assert_almost_eq(up.angle_to(expected), 0.0, 0.01, "Tilted as the water is (%s)" % up)
	var flat: Callable = func(_x: float, _z: float, _t: float) -> float: return -0.25
	var on_flat: CourseOnWater = _built(course, flat)
	assert_almost_eq(on_flat.part_at("1").global_transform.basis.y.angle_to(Vector3.UP), 0.0, 0.001, "Upright on flat water")
	assert_almost_eq(on_flat.part_at("1").global_position.y, -0.25, 0.001)


func test_the_boats_lie_head_to_wind_with_their_flags_downwind() -> void:
	var flat: Callable = func(_x: float, _z: float, _t: float) -> float: return 0.0
	# The wind from the west, blowing east at 7 m/s.
	var from_west: Callable = func(_at: Vector3) -> Vector3: return Vector3(7.0, 0.0, 0.0)
	var course: Course = RaceCourses.t1_loop(270.0, Vector2.ZERO)
	var on_water: CourseOnWater = _built(course, flat, from_west)
	var boat: Node3D = on_water.part_at(CourseMark.START_BOAT)
	var bow: Vector3 = -boat.global_transform.basis.z
	assert_almost_eq(bow.angle_to(Vector3.LEFT), 0.0, 0.01, "The bow points west, into the wind")
	var flag: WindFlag = on_water.flag_at(CourseMark.START_BOAT)
	assert_almost_eq(flag.cloth_direction().angle_to(Vector3.RIGHT), 0.0, 0.01, "The flag streams east")
	assert_gt(flag.global_position.y, 1.0, "The flag stands on the cabin roof")


func test_the_lines_on_the_water_are_off_until_asked_for() -> void:
	var course: Course = RaceCourses.t1_loop(270.0, Vector2.ZERO)
	var on_water: CourseOnWater = _built(course, _wavy_water)
	assert_false(on_water.lines_visible)
	var shown: int = 0
	for child: Node in on_water.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).visible:
			shown += 1
	assert_eq(shown, 0, "No line drawn")
	on_water.set_lines_visible(true)
	for child: Node in on_water.get_children():
		if child is MeshInstance3D:
			assert_true((child as MeshInstance3D).visible, child.name + " drawn")


func test_the_parts_share_their_meshes() -> void:
	var course: Course = RaceCourses.t1_loop(270.0, Vector2.ZERO)
	var on_water: CourseOnWater = _built(course, _wavy_water)
	var gate_s: MeshInstance3D = on_water.part_at("4S").get_node("Body")
	var mark_1: MeshInstance3D = on_water.part_at("1").get_node("Body")
	assert_same(gate_s.mesh, mark_1.mesh, "One buoy mesh for all the marks")
	assert_ne(gate_s.material_override, mark_1.material_override, "The gate's marks are yellow, the others orange")
	assert_same(on_water.part_at("4S").get_node("Body").material_override, on_water.part_at("4P").get_node("Body").material_override)
	var boat_hull: MeshInstance3D = on_water.part_at(CourseMark.START_BOAT).get_node("Hull")
	var finish_hull: MeshInstance3D = on_water.part_at(CourseMark.FINISH_BOAT).get_node("Hull")
	assert_same(boat_hull.mesh, finish_hull.mesh, "One hull mesh for both boats")


## The HUD (ui/hud.gd) names the course, and on the open water (no lake's map) it makes a small map
## of the course's water: the course and 200 m around it.
func test_the_hud_names_the_course_and_maps_it_on_the_open_water() -> void:
	var hud: Hud = Hud.new()
	add_child_autofree(hud)
	var course: Course = RaceCourses.t1_loop(270.0, Vector2(0.0, -150.0))
	hud.show_course(course)
	assert_eq(hud.course_text(), "Course: T1 training loop")
	var maps: Array[Node] = hud.find_children("*", "MiniMap", false, false)
	assert_eq(maps.size(), 1, "One small map")
	if maps.is_empty():
		return
	var mini_map: MiniMap = maps[0] as MiniMap
	assert_same(mini_map.course, course, "The course is on it")
	# Every mark lies inside the map, at least 200 m from its edges.
	for mark: CourseMark in course.marks:
		var at: Vector2 = mini_map.map_point(Vector3(mark.position.x, 0.0, mark.position.y))
		assert_true(Rect2(Vector2.ZERO, mini_map.size).has_point(at), mark.id + " on the map")
	var box: Rect2 = course.bounds()
	var top_left: Vector2 = mini_map.map_point(Vector3(box.position.x, 0.0, box.position.y))
	var pixels_per_metre: float = mini_map.size.x / (box.size.x + 400.0)
	assert_almost_eq(top_left.x, 200.0 * pixels_per_metre, 0.5, "200 m of water west of the course")
	assert_almost_eq(top_left.y, 200.0 * pixels_per_metre, 0.5, "and north of it")
