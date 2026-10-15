extends GutTest
## The course maker's editing (MAP_SILVAPLANA_PLAN.md, W4a; CourseEditor), with made-up mouse and
## key events on a camera looking straight down: a dragged mark follows the mouse, a gate moves as
## a pair, Shift and drag moves the whole course, a click away from the marks is left to the
## viewer, Ctrl+Z goes back step by step, M hides the course, and a saved course loads back.
## Adding marks: dropped beside a run it goes into the runs of both laps, beside a beat into the
## beats, with Shift into one leg only, far away it is a lone mark that can be typed into the order;
## a selected mark can be renamed, turned to the other side and deleted.

const CONFIG_PATH: String = "res://maps/silvaplana/map_config.tres"
const FOLDER: String = "user://test_courses"

var _editor: CourseEditor
var _camera: Camera3D


func before_each() -> void:
	var world: Node3D = Node3D.new()
	add_child_autofree(world)
	_camera = Camera3D.new()
	_camera.far = 10000.0
	world.add_child(_camera)
	# 300 m up: about 7 m per pixel in the test runner's small window (the course reaches far
	# outside it, which doesn't matter for the sums).
	_camera.global_position = Vector3(0.0, 300.0, 0.0)
	_camera.global_rotation = Vector3(-PI / 2.0, 0.0, 0.0)
	_camera.make_current()
	# The camera's new place only counts from the next frame.
	await wait_process_frames(1)
	var layer: CanvasLayer = CanvasLayer.new()
	world.add_child(layer)
	var panels: Control = Control.new()
	layer.add_child(panels)
	_editor = CourseEditor.new()
	world.add_child(_editor)
	var all_water: Callable = func(_x: float, _z: float) -> float: return -10.0
	var wind_now: Callable = func() -> Vector2: return Vector2(222.0, 15.0)
	var view_centre: Callable = func() -> Vector2: return Vector2.ZERO
	_editor.setup(layer, panels, load(CONFIG_PATH), all_water, FOLDER, wind_now, view_centre)
	_editor.place_template("LG2", Vector2.ZERO)
	# One update, so the drawing knows the camera.
	_editor._process(0.0)


func after_all() -> void:
	for file: String in DirAccess.get_files_at(FOLDER):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FOLDER.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FOLDER))


func test_a_dragged_mark_follows_the_mouse() -> void:
	var start: Vector2 = _screen("1")
	var gate_before: Vector2 = _editor.course.mark("4S").position
	assert_true(_press(start), "Grabbing mark 1")
	assert_true(_move(start + Vector2(40.0, -20.0)))
	assert_true(_release(start + Vector2(40.0, -20.0)))
	assert_almost_eq(_screen("1").distance_to(start + Vector2(40.0, -20.0)), 0.0, 0.5, "Mark 1 is under the mouse")
	assert_eq(_editor.course.mark("4S").position, gate_before, "Nothing else moved")


func test_a_gate_moves_as_a_pair() -> void:
	var starboard: Vector2 = _editor.course.mark("4S").position
	var port: Vector2 = _editor.course.mark("4P").position
	var start: Vector2 = _screen("4S")
	_press(start)
	_move(start + Vector2(0.0, 30.0))
	_release(start + Vector2(0.0, 30.0))
	var moved: Vector2 = _editor.course.mark("4S").position - starboard
	assert_gt(moved.length(), 1.0, "4S moved")
	assert_almost_eq((_editor.course.mark("4P").position - port).distance_to(moved), 0.0, 0.01, "4P moved with it")


func test_shift_and_drag_moves_the_whole_course() -> void:
	var before: Course = _editor.course.copy()
	var start: Vector2 = _screen("1")
	_press(start, true)
	_move(start + Vector2(25.0, 25.0))
	_release(start + Vector2(25.0, 25.0))
	var moved: Vector2 = _editor.course.mark("1").position - before.mark("1").position
	assert_gt(moved.length(), 1.0)
	for mark: CourseMark in before.marks:
		assert_almost_eq((_editor.course.mark(mark.id).position - mark.position).distance_to(moved), 0.0, 0.01, mark.id + " moved the same way")


func test_a_click_away_from_the_marks_is_the_viewers() -> void:
	assert_false(_press(Vector2(3.0, 3.0)), "The viewer gets the click (the wind at that point)")


func test_undo_goes_back_step_by_step() -> void:
	var mark1: Vector2 = _editor.course.mark("1").position
	var gate: Vector2 = _editor.course.mark("4S").position
	for id: String in ["1", "4S"]:
		var start: Vector2 = _screen(id)
		_press(start)
		_move(start + Vector2(30.0, 0.0))
		_release(start + Vector2(30.0, 0.0))
	assert_true(_key(KEY_Z, true), "Ctrl+Z")
	assert_eq(_editor.course.mark("4S").position, gate, "The gate is back")
	assert_ne(_editor.course.mark("1").position, mark1, "Mark 1 is still moved")
	_key(KEY_Z, true)
	assert_eq(_editor.course.mark("1").position, mark1, "Mark 1 is back")
	_key(KEY_Z, true)
	assert_null(_editor.course, "Before the template there was no course")


func test_m_hides_the_course() -> void:
	assert_true(_key(KEY_M, false))
	assert_false(_editor.shown)
	assert_false(_press(_screen("1")), "A hidden course can't be dragged")
	_key(KEY_M, false)
	assert_true(_editor.shown)


func test_a_saved_course_loads_back() -> void:
	_editor.course.set_axis(230.0)
	var saved: Course = _editor.course.copy()
	assert_true(_editor.save_course("Test course, start off the camping"))
	assert_true(FileAccess.file_exists(FOLDER.path_join("test_course_start_off_the_camping.json")), "A file named after the course")
	_editor.place_template("PD3", Vector2.ZERO)
	assert_true(_editor.load_course("Test course, start off the camping"))
	assert_eq(_editor.course.template, "LG2")
	assert_almost_eq(_editor.course.axis_deg, 230.0, 0.05)
	for mark: CourseMark in saved.marks:
		assert_almost_eq(_editor.course.mark(mark.id).position.distance_to(mark.position), 0.0, 0.01, mark.id)
	assert_false(_editor.load_course("No such course"))


func test_a_mark_dropped_beside_a_run_goes_into_both_runs() -> void:
	# A third of the way down the first run (leg 1, from mark 1 to the gate), 40 m to its right
	# looking down it: the side the run is drawn on, away from the beat on the same line.
	var drop: Vector2 = _beside_leg(1, 0.3, 40.0)
	_editor.start_adding_mark()
	_move(_screen_of(drop))
	assert_true(_press(_screen_of(drop)))
	assert_eq(_editor.course.sequence, "Start-1-5-4S/4P-1-5-4S-Finish", "Into the run of both laps")
	assert_almost_eq(_editor.course.mark("5").position.distance_to(drop), 0.0, 0.5, "Where it was dropped")
	assert_eq(_editor.course.mark("5").side, CourseMark.Rounding.PORT,
		"The run bends out to its right round it, then turns left: port")
	assert_eq(_editor.selected_mark(), _editor.course.mark("5"), "The new mark is selected, to rename or turn it")
	assert_false(_press(Vector2(3.0, 3.0)), "One mark per Add mark: the next click is the viewer's again")


func test_a_mark_dropped_beside_a_beat_goes_into_both_beats() -> void:
	var drop: Vector2 = _beside_leg(0, 0.5, 40.0)
	_editor.start_adding_mark()
	_press(_screen_of(drop))
	assert_eq(_editor.course.sequence, "Start-5-1-4S/4P-5-1-4S-Finish", "Into the beat of both laps")


func test_with_shift_a_new_mark_goes_into_one_leg() -> void:
	_editor.start_adding_mark()
	_press(_screen_of(_beside_leg(1, 0.3, 40.0)), true)
	assert_eq(Array(_editor.course.sequence.split("-")).count("5"), 1, "Only once in the order")


func test_far_from_the_legs_a_new_mark_is_on_its_own() -> void:
	_editor.start_adding_mark()
	_press(_screen_of(_beside_leg(1, 0.5, 600.0)))
	assert_eq(_editor.course.sequence, "Start-1-4S/4P-1-4S-Finish", "Not in the order")
	assert_eq(_editor.course.marks_not_in_order(), PackedStringArray(["5"]))
	assert_true(_editor.set_order("Start-1-5-4S/4P-1-4S-Finish"), "Typed into the order")
	assert_eq(_editor.course.legs().size(), 6)
	assert_false(_editor.set_order("Start-1-6-Finish"), "No mark 6: refused")
	assert_eq(_editor.course.sequence, "Start-1-5-4S/4P-1-4S-Finish", "and nothing changed")


func test_esc_stops_adding_a_mark() -> void:
	_editor.start_adding_mark()
	assert_true(_key(KEY_ESCAPE, false))
	assert_false(_press(Vector2(3.0, 3.0)), "The click is the viewer's again")
	assert_null(_editor.course.mark("5"))


func test_a_selected_mark_can_be_renamed_turned_and_deleted() -> void:
	var at: Vector2 = _screen("1")
	_press(at)
	_release(at)
	assert_eq(_editor.selected_mark().id, "1", "A click selects the mark")
	assert_true(_editor.rename_selected_mark("1a"))
	assert_eq(_editor.course.sequence, "Start-1a-4S/4P-1a-4S-Finish", "Renamed in the order too")
	assert_false(_editor.rename_selected_mark("4P"), "Not another mark's name")
	_editor.set_selected_side(CourseMark.Rounding.STARBOARD)
	assert_eq(_editor.course.mark("1a").side, CourseMark.Rounding.STARBOARD)
	assert_true(_key(KEY_DELETE, false), "The Delete key")
	assert_null(_editor.course.mark("1a"))
	assert_eq(_editor.course.sequence, "Start-4S/4P-4S-Finish", "Out of the order")
	_key(KEY_Z, true)
	assert_eq(_editor.course.mark("1a").side, CourseMark.Rounding.STARBOARD, "Undo brings it back")


func test_a_click_that_only_selects_is_not_an_undo_step() -> void:
	var at: Vector2 = _screen("1")
	_press(at)
	_release(at)
	_key(KEY_Z, true)
	assert_null(_editor.course, "The only step to undo is putting the template on the lake")


func test_the_rounding_arrows_follow_the_course() -> void:
	var overlay: CourseOverlay = CourseOverlay.new()
	add_child_autofree(overlay)
	overlay.camera = _camera
	overlay.course = _editor.course
	var upwind: Vector2 = Course.direction_of(222.0)
	var gate_middle: Vector2 = _editor.course.point_of("4S/4P")
	for id: String in ["4S", "4P"]:
		var mark: Vector2 = _editor.course.mark(id).position
		var arc: Vector2 = overlay.rounding_arc(_screen_of(mark), _editor.course.mark(id))
		# The arrow goes round the gate mark's downwind side and leaves on its outer side (away
		# from the gate's middle), pointing back upwind, as on the diagrams.
		assert_gt(_on_screen(mark, -upwind).dot(_angle_direction((arc.x + arc.y) / 2.0)), 0.7, id + ": round the downwind side")
		assert_gt(_on_screen(mark, (mark - gate_middle).normalized()).dot(_angle_direction(arc.y)), 0.9, id + ": leaves on the outer side")
		var heading: Vector2 = Vector2(-sin(arc.y), cos(arc.y)) * signf(arc.y - arc.x)
		assert_gt(_on_screen(mark, upwind).dot(heading), 0.9, id + ": the arrow points back upwind")
	var mark1: Vector2 = _editor.course.mark("1").position
	var arc1: Vector2 = overlay.rounding_arc(_screen_of(mark1), _editor.course.mark("1"))
	assert_gt(_on_screen(mark1, upwind).dot(_angle_direction((arc1.x + arc1.y) / 2.0)), 0.7, "Mark 1: round its upwind side")
	assert_lt(arc1.y, arc1.x, "Mark 1 is left to port: anticlockwise, a falling angle on the screen")


# ---------------------------------------------------------------- made-up events

## A direction on the lake (game X, Z) at a point, as a direction on the screen.
func _on_screen(at: Vector2, direction: Vector2) -> Vector2:
	return (_screen_of(at + direction * 10.0) - _screen_of(at)).normalized()


## The screen direction of an angle on the screen (the screen's Y points down).
func _angle_direction(angle: float) -> Vector2:
	return Vector2(cos(angle), sin(angle))

func _screen(id: String) -> Vector2:
	return _screen_of(_editor.course.mark(id).position)


func _screen_of(at: Vector2) -> Vector2:
	return _camera.unproject_position(Vector3(at.x, CourseOverlay.DRAW_HEIGHT_M, at.y))


## A point on the water beside a leg: a fraction of the way along it, and some metres to its right
## looking along it (to its left for negative metres).
func _beside_leg(number: int, fraction: float, right_m: float) -> Vector2:
	var leg: Course.Leg = _editor.course.legs()[number]
	var along: Vector2 = (leg.to_point - leg.from_point).normalized()
	# A quarter turn clockwise seen from above (X east, Z south) is to the right.
	return leg.from_point.lerp(leg.to_point, fraction) + along.rotated(PI / 2.0) * right_m


func _press(at: Vector2, shift: bool = false) -> bool:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = at
	event.shift_pressed = shift
	return _editor.handle_input(event)


func _move(at: Vector2) -> bool:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = at
	return _editor.handle_input(event)


func _release(at: Vector2) -> bool:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	event.position = at
	return _editor.handle_input(event)


func _key(code: Key, ctrl: bool) -> bool:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	event.ctrl_pressed = ctrl
	return _editor.handle_input(event)
