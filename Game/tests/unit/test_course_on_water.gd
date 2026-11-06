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


## Max, 6 November 2026: every buoy a plain cylinder 1.2 m high and 0.7 m wide in a bright colour;
## the pins the same buoy; the boats a bit bigger, mast and flag with them.
func test_the_buoys_are_max_s_cylinders_and_the_boats_are_bigger() -> void:
	var flat: Callable = func(_x: float, _z: float, _t: float) -> float: return 0.0
	var course: Course = RaceCourses.t1_loop(270.0, Vector2.ZERO)
	var on_water: CourseOnWater = _built(course, flat)
	var body: MeshInstance3D = on_water.part_at("1").get_node("Body")
	var cylinder: CylinderMesh = body.mesh as CylinderMesh
	assert_almost_eq(cylinder.height, 1.2, 1e-6, "1.2 m high")
	assert_almost_eq(cylinder.top_radius * 2.0, 0.7, 1e-6, "0.7 m wide")
	assert_eq(cylinder.top_radius, cylinder.bottom_radius, "straight up, not tapered")
	var box: AABB = body.global_transform * cylinder.get_aabb()
	assert_almost_eq(box.end.y, 1.2 - CourseOnWater.BUOY_DRAFT_M, 1e-4, "its top above the water")
	assert_same(on_water.part_at(CourseMark.START_PIN).get_node("Body").mesh, cylinder, "the pins are the same buoy")
	var material: StandardMaterial3D = body.material_override as StandardMaterial3D
	assert_true(material.emission_enabled, "fluorescent: it glows a little")
	var gate: StandardMaterial3D = on_water.part_at("4S").get_node("Body").material_override as StandardMaterial3D
	assert_gt(gate.albedo_color.g - material.albedo_color.g, 0.4, "a gate's yellow is told apart from the orange")
	# The committee boat: 1.4 times the 6 m boat, and its mast stands as much higher.
	var boat: Node3D = on_water.part_at(CourseMark.START_BOAT)
	var hull: MeshInstance3D = boat.get_node("Hull")
	var hull_box: AABB = hull.global_transform * hull.mesh.get_aabb()
	assert_almost_eq(maxf(hull_box.size.x, hull_box.size.z), CourseOnWater.BOAT_LENGTH_M * CourseOnWater.BOAT_SCALE, 0.05, "8.4 m long on the water")
	var flag: WindFlag = on_water.flag_at(CourseMark.START_BOAT)
	assert_almost_eq(flag.global_position.y, CourseOnWater.MAST_FOOT.y * CourseOnWater.BOAT_SCALE, 1e-4, "the mast on the bigger cabin's roof")
	assert_almost_eq(flag.global_transform.basis.y.length(), CourseOnWater.BOAT_SCALE, 1e-4, "mast and flag as much bigger")


# ---------------------------------------------------------------- the course changed while raced

## The LAN race director drags a mark: its buoy (the same node) follows, at the water's height there.
func test_set_course_moves_the_pieces_with_a_moved_mark() -> void:
	var course: Course = RaceCourses.t1_loop(270.0, Vector2.ZERO)
	var on_water: CourseOnWater = _built(course, _wavy_water)
	var buoy: Node3D = on_water.part_at("1")
	var boat: Node3D = on_water.part_at(CourseMark.START_BOAT)
	var children: int = on_water.get_child_count()
	course.mark("1").position += Vector2(30.0, -20.0)
	course.mark(CourseMark.START_BOAT).position += Vector2(0.0, 12.0)
	var old_line_mesh: Mesh = on_water.line_at(CourseMark.START_BOAT).mesh
	var finish_line_mesh: Mesh = on_water.line_at(CourseMark.FINISH_BOAT).mesh
	on_water.set_course(course)
	assert_same(on_water.part_at("1"), buoy, "the same buoy, moved")
	for id: String in ["1", CourseMark.START_BOAT]:
		var mark: CourseMark = course.mark(id)
		var at: Vector3 = on_water.part_at(id).global_position
		assert_almost_eq(Vector2(at.x, at.z).distance_to(mark.position), 0.0, 0.001, id + " at its new spot")
		assert_almost_eq(at.y, _wavy_water(mark.position.x, mark.position.y, _time_s), 0.01, id + " on the water there")
	assert_same(on_water.part_at(CourseMark.START_BOAT), boat)
	var flag: WindFlag = on_water.flag_at(CourseMark.START_BOAT)
	var flag_at: Vector2 = Vector2(flag.global_position.x, flag.global_position.z)
	assert_almost_eq(flag_at.distance_to(course.mark(CourseMark.START_BOAT).position), 0.0, 1.5, "its flag went with it")
	assert_ne(on_water.line_at(CourseMark.START_BOAT).mesh, old_line_mesh, "the start line is drawn again to the boat's new spot")
	assert_same(on_water.line_at(CourseMark.FINISH_BOAT).mesh, finish_line_mesh, "the finish line did not move: not drawn again")
	assert_eq(on_water.get_child_count(), children, "nothing added, nothing left behind")
	# A new Course object with the same marks (a copy) works the same way.
	var copy: Course = course.copy()
	copy.mark("1").position += Vector2(5.0, 0.0)
	on_water.set_course(copy)
	assert_same(on_water.part_at("1"), buoy)
	assert_almost_eq(on_water.part_at("1").global_position.x, copy.mark("1").position.x, 0.001)


## A removed mark's buoy is taken out of the scene and freed; so is a line that lost an end.
func test_set_course_frees_the_pieces_of_a_removed_mark() -> void:
	var course: Course = RaceCourses.t1_loop(270.0, Vector2.ZERO)
	var on_water: CourseOnWater = _built(course, _wavy_water)
	var buoy: Node3D = on_water.part_at("1")
	var children: int = on_water.get_child_count()
	course.remove_mark("1")
	on_water.set_course(course)
	assert_null(on_water.part_at("1"), "no buoy at mark 1 any more")
	assert_null(buoy.get_parent(), "out of the scene at once")
	assert_true(buoy.is_queued_for_deletion(), "and freed")
	assert_eq(on_water.get_child_count(), children - 1)
	assert_eq(on_water.parts_of_kind(CourseOnWater.Kind.BUOY).size(), 2, "the gate's two marks stay")
	# The finish pin gone (a course maker's mistake): its buoy and the finish line go.
	var pin: Node3D = on_water.part_at(CourseMark.FINISH_PIN)
	var line: MeshInstance3D = on_water.line_at(CourseMark.FINISH_BOAT)
	course.marks.erase(course.mark(CourseMark.FINISH_PIN))
	on_water.set_course(course)
	assert_true(pin.is_queued_for_deletion())
	assert_true(line.is_queued_for_deletion(), "the finish line goes with its pin")
	assert_eq(on_water.line_count(), 1)
	await wait_process_frames(1)
	assert_false(is_instance_valid(buoy), "nothing leaks")
	assert_false(is_instance_valid(line))


## A new mark gets a buoy at once; a renamed mark gets a new one with its new name on the flag.
func test_set_course_puts_a_new_mark_on_the_water() -> void:
	var course: Course = RaceCourses.t1_loop(270.0, Vector2.ZERO)
	var on_water: CourseOnWater = _built(course, _wavy_water)
	var at: Vector2 = course.mark("1").position + Vector2(-60.0, 40.0)
	course.add_mark("5", at, CourseMark.Rounding.PORT)
	on_water.set_course(course)
	var buoy: Node3D = on_water.part_at("5")
	assert_not_null(buoy, "a buoy at the new mark")
	assert_eq(on_water.parts_of_kind(CourseOnWater.Kind.BUOY).size(), 4)
	assert_almost_eq(Vector2(buoy.global_position.x, buoy.global_position.z).distance_to(at), 0.0, 0.001)
	assert_almost_eq(buoy.global_position.y, _wavy_water(at.x, at.y, _time_s), 0.01, "on the water")
	var mark_1_body: MeshInstance3D = on_water.part_at("1").get_node("Body")
	assert_same((buoy.get_node("Body") as MeshInstance3D).mesh, mark_1_body.mesh, "the shared buoy")
	assert_eq((buoy.get_node("Name left") as Label3D).text, "5")
	var old_one: Node3D = on_water.part_at("1")
	assert_eq(course.rename_mark("1", "7"), "")
	on_water.set_course(course)
	assert_null(on_water.part_at("1"))
	assert_eq((on_water.part_at("7").get_node("Name right") as Label3D).text, "7", "the new name on the flag")
	assert_true(old_one.is_queued_for_deletion())
	await wait_process_frames(1)
	assert_false(is_instance_valid(old_one), "freed at the end of the frame")
	# The order of the parts is the course's order of marks.
	var ids: PackedStringArray = PackedStringArray()
	for mark: CourseMark in course.marks:
		if not mark.is_line_end():
			ids.append(mark.id)
	var names: PackedStringArray = PackedStringArray()
	for part: Node3D in on_water.parts_of_kind(CourseOnWater.Kind.BUOY):
		names.append(String(part.name).trim_prefix("Mark "))
	assert_eq(names, ids)


## Ten calls a second while the host drags a mark: the same course again and again adds nothing,
## and each call costs well under a millisecond.
func test_set_course_is_cheap_and_leaks_nothing() -> void:
	var course: Course = RaceCourses.t1_loop(270.0, Vector2.ZERO)
	var on_water: CourseOnWater = _built(course, _wavy_water)
	var children: int = on_water.get_child_count()
	var buoy: Node3D = on_water.part_at("1")
	var started_us: int = Time.get_ticks_usec()
	for i: int in 100:
		course.mark("1").position += Vector2(0.5, 0.0)
		on_water.set_course(course)
	var each_ms: float = (Time.get_ticks_usec() - started_us) / 1000.0 / 100.0
	assert_lt(each_ms, 2.0, "a call takes %.3f ms" % each_ms)
	assert_eq(on_water.get_child_count(), children, "no new nodes")
	assert_same(on_water.part_at("1"), buoy)
