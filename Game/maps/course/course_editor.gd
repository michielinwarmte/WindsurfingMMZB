class_name CourseEditor
extends Node
## The course maker (MAP_SILVAPLANA_PLAN.md, W4a): put an iQFOiL course on the lake from a template,
## drag its marks, add and remove marks, turn it, resize it, and save it for the team. It lives in
## the wind viewer for now (WD5); the viewer gives it its screen layer, the map, the wind and the
## mouse (handle_input()).
##
## - Choosing a template puts the course in the middle of the view, set to the lake's wind of the
##   moment and sized for its strength (WD7).
## - Dragging a mark moves it; a gate moves as a pair, the ends of the start and finish lines one by
##   one. Shift and drag moves the whole course. A click away from the marks is the viewer's
##   (the wind at that point).
## - Clicking a mark selects it: rename it, choose port or starboard, delete it (also the Delete
##   key). Esc deselects.
## - Add mark, then a click on the water: the new mark goes into the leg nearest to the click, as
##   that leg is drawn (so between a beat and a run on the same line, the one on that side), and into
##   the same leg on every lap: the legs running the same way close by. Shift: only the leg under the
##   mouse. Before the click the legs it will go into are lit in yellow. Far from every leg it is a
##   lone mark, which can be typed into the order. It is left on the side the course bends round it.
## - The order can also be typed, as in the Notice of Race ("Start-1-5-4S/4P-1-5-4S-Finish").
## - Every change can be undone (Ctrl+Z), also Clear. M shows and hides the course.
## - Courses are saved as JSON in the map's courses folder, in the project, so the team shares
##   them through git (WD6).

## How close (pixels) the mouse must be to a mark to grab it.
const PICK_RADIUS_PX: float = 14.0
## How close (pixels) to a drawn leg a new mark must be dropped to go into it.
const NEAR_LEG_PX: float = 60.0
## The same leg on another lap: running within this many degrees of the same way, and at most this
## many metres further from the new mark than the leg it was dropped on.
const SAME_LEG_DEG: float = 15.0
const SAME_LEG_M: float = 40.0
## How many changes Undo remembers.
const UNDO_LIMIT: int = 200
## How often the panel's angles to the wind are brought up to date, seconds (the wind turns slowly).
const PANEL_REFRESH_S: float = 1.0
const RULES_PATH: String = "res://maps/course/iqfoil_courses.tres"

## The course on the lake, or null.
var course: Course
## False while M has hidden the course.
var shown: bool = true

var _rules: CourseRules
var _config: MapConfig
## (x, z) -> the ground's height above the lake's surface at a game position, NAN off the map.
var _height_at: Callable
var _folder: String
## () -> Vector2(where the lake's wind comes from now (degrees), its speed (knots)).
var _wind_now: Callable
## () -> the game point (X, Z) in the middle of the view.
var _view_centre: Callable
var _overlay: CourseOverlay
var _panel: CoursePanel
## Earlier versions of the course, newest last; null where there was no course.
var _undo: Array[Course] = []
var _dragging: CourseMark
var _drag_whole: bool = false
var _drag_from: Vector2 = Vector2.ZERO
## A click on a mark only selects it: the drag is remembered for Undo once the mark really moves.
var _drag_remembered: bool = false
## The selected mark's name ("" for none). A name, because Undo puts back another copy of the course.
var _selected_id: String = ""
## True after Add mark, until the click on the water (or Esc).
var _adding: bool = false
## For screenshots: a point (game X, Z) the new mark's preview is shown at, instead of the mouse.
var _preview_at: Vector2 = Vector2.INF
var _refresh_left_s: float = 0.0
## The saved courses by name, with their files.
var _saved: Dictionary[String, String] = {}


## Connects the course maker to the viewer: its screen layer (the course is drawn in it, under
## everything already there), the screen's panels (the course panel goes in at the top right, under
## the viewer's info lines and left of the speed legend), the map's configuration, the ground (see
## _height_at), the courses folder, and where the wind and the view are (see _wind_now and
## _view_centre).
func setup(layer: CanvasLayer, panels: Control, config: MapConfig, height_at: Callable, folder: String, wind_now: Callable,
		view_centre: Callable) -> void:
	_rules = load(RULES_PATH)
	_config = config
	_height_at = height_at
	_folder = folder
	_wind_now = wind_now
	_view_centre = view_centre
	_overlay = CourseOverlay.new()
	_overlay.name = "CourseOverlay"
	layer.add_child(_overlay)
	layer.move_child(_overlay, 0)
	_panel = CoursePanel.new()
	_panel.name = "CoursePanel"
	panels.add_child(_panel)
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.offset_right = -58.0
	_panel.offset_left = -58.0 - CoursePanel.WIDTH_PX
	_panel.offset_top = 92.0
	_panel.template_chosen.connect(_on_template_chosen)
	_panel.boards_changed.connect(_on_boards_changed)
	_panel.size_changed.connect(_on_size_changed)
	_panel.axis_changed.connect(_on_axis_changed)
	_panel.square_to_wind_pressed.connect(_on_square_to_wind)
	_panel.undo_pressed.connect(_on_undo)
	_panel.clear_pressed.connect(_on_clear)
	_panel.add_mark_pressed.connect(func() -> void:
		if _adding:
			_stop_adding()
		else:
			start_adding_mark())
	_panel.order_submitted.connect(set_order)
	_panel.mark_renamed.connect(rename_selected_mark)
	_panel.mark_side_chosen.connect(set_selected_side)
	_panel.delete_mark_pressed.connect(delete_selected_mark)
	_panel.save_pressed.connect(func(course_name: String) -> void: save_course(course_name))
	_panel.load_chosen.connect(func(course_name: String) -> void: load_course(course_name))
	_read_saved_courses()
	_changed()


func _process(delta: float) -> void:
	_overlay.camera = get_viewport().get_camera_3d()
	if _adding and _preview_at.is_finite():
		_preview_new_mark(_overlay.screen_point(_preview_at), false)
	_overlay.queue_redraw()
	_refresh_left_s -= delta
	if _refresh_left_s <= 0.0:
		_refresh_left_s = PANEL_REFRESH_S
		_update_panel()


## The viewer passes every unhandled event here first. True if the course maker used it.
func handle_input(event: InputEvent) -> bool:
	var key: InputEventKey = event as InputEventKey
	if key != null:
		return _handle_key(key)
	if not shown or course == null:
		return false
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		return _handle_left_button(button)
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		return _handle_motion(motion)
	return false


## Puts a new course from a template on the lake, its middle at a game point (X, Z).
func place_template(id: String, centre: Vector2) -> void:
	var wind: Vector2 = _wind_now.call()
	var built: Course = CourseTemplates.build(id, _rules, wind.y, CourseTemplates.default_boards(id), wind.x, Vector2.ZERO)
	if built == null:
		return
	_remember()
	_stop_adding()
	built.move_by(centre - built.bounds().get_center())
	course = built
	_changed()


## Loads a saved course by its name (or the name of its file). False if there is none.
func load_course(course_name: String) -> bool:
	var path: String = _saved.get(course_name, _folder.path_join(_file_name(course_name) + ".json"))
	var loaded: Course = Course.load_from(path, _config) if FileAccess.file_exists(path) else null
	if loaded == null:
		_panel.show_message("Could not read the course \"%s\"." % course_name)
		return false
	_remember()
	_stop_adding()
	course = loaded
	_panel.set_course_name(course.name)
	_panel.show_message("Loaded \"%s\"." % course.name)
	_changed()
	return true


## Saves the course under a name, in the courses folder (a file named after it). False if there is
## no course, no usable name, or the file can't be written.
func save_course(course_name: String) -> bool:
	course_name = course_name.strip_edges()
	if course == null:
		return false
	if _file_name(course_name).is_empty():
		_panel.show_message("Type a name for the course first (with letters or digits).")
		return false
	var path: String = _folder.path_join(_file_name(course_name) + ".json")
	var replacing: bool = FileAccess.file_exists(path)
	course.name = course_name
	var error: Error = course.save(path, _config)
	if error != OK:
		_panel.show_message("Could not save: %s" % error_string(error))
		return false
	_panel.show_message("Saved \"%s\"%s, in %s. Commit it to share it with the team." % [
		course_name, " (it replaces the earlier one)" if replacing else "", path.get_file()])
	_read_saved_courses()
	return true


# ---------------------------------------------------------------- adding, changing and removing marks

## Starts adding a mark: the next click on the water puts it there (Esc stops).
func start_adding_mark() -> void:
	if course == null:
		return
	_adding = true
	_select("")
	_panel.set_adding(true)
	_panel.show_message("Click on the water where the new mark goes. It goes into the leg lit in yellow, on every lap; hold Shift for only the leg under the mouse. Away from the legs it is a lone mark, to type into the order. Esc stops.")


## Shows or hides the course and its panel (M).
func set_shown(on: bool) -> void:
	shown = on
	_overlay.visible = on
	_panel.visible = on
	_dragging = null
	if not on:
		_stop_adding()


## For screenshots: Add mark, with the preview at a point on the lake (game X, Z) as if the mouse
## were there.
func show_new_mark_preview(at: Vector2) -> void:
	start_adding_mark()
	_preview_at = at


## The selected mark, or null.
func selected_mark() -> CourseMark:
	return course.mark(_selected_id) if course != null and not _selected_id.is_empty() else null


## Sets the order the marks are sailed in, typed as in the Notice of Race. False (and a message
## saying why, with the text kept to put it right) if it can't be sailed.
func set_order(text: String) -> bool:
	if course == null:
		return false
	var before: Course = course.copy()
	var problem: String = course.set_sequence(text)
	if not problem.is_empty():
		_panel.show_message("The order is not changed: " + problem)
		_panel.keep_typing_order()
		return false
	if course.sequence != before.sequence:
		_remember_version(before)
	_panel.show_message("The order is now %s." % course.sequence)
	_changed()
	return true


## Takes the selected mark off the course (a gate goes as a whole). The lines' ends stay.
func delete_selected_mark() -> void:
	var mark: CourseMark = selected_mark()
	if mark == null or mark.is_line_end():
		return
	_remember()
	course.remove_mark(mark.id)
	_panel.show_message("%s deleted, and taken out of the order (Undo brings it back)." % (
		"Gate " + mark.id.left(-1) if mark.is_gate_mark() else "Mark " + mark.id))
	_select("")
	_changed()


## Gives the selected mark a new name, also in the order. False (and a message saying why) if the
## name can't be used.
func rename_selected_mark(new_name: String) -> bool:
	var mark: CourseMark = selected_mark()
	if mark == null:
		return false
	var before: Course = course.copy()
	var old_name: String = mark.id
	var problem: String = course.rename_mark(old_name, new_name)
	if not problem.is_empty():
		_panel.show_message("Not renamed: " + problem)
		_panel.keep_typing_name()
		return false
	if mark.id != old_name:
		_remember_version(before)
		_selected_id = mark.id
		_panel.show_message("Mark %s is now called %s." % [old_name, mark.id])
	_changed()
	return true


## Sets the side the selected mark is left on (not for gates and the lines' ends).
func set_selected_side(side: CourseMark.Rounding) -> void:
	var mark: CourseMark = selected_mark()
	if mark == null or mark.side == side or mark.is_line_end() or mark.is_gate_mark():
		return
	_remember()
	mark.side = side
	_changed()


## The new mark at a point on the water (game X, Z), dropped at a screen point: into the legs found
## there (see _legs_for_new_mark), left on the side the first of them bends round it.
func _add_mark(water: Vector2, screen: Vector2, only_this_leg: bool) -> void:
	var numbers: Array[int] = _legs_for_new_mark(screen, water, only_this_leg)
	var legs: Array[Course.Leg] = course.legs()
	_remember()
	var id: String = course.next_mark_id()
	var side: CourseMark.Rounding = CourseMark.Rounding.PORT
	if not numbers.is_empty():
		side = Course.natural_side(legs[numbers[0]].from_point, water, legs[numbers[0]].to_point)
	course.add_mark(id, water, side)
	course.insert_into_legs(id, numbers)
	_stop_adding()
	_select(id)
	if numbers.is_empty():
		_panel.show_message("Mark %s is on its own, not in the order yet: type it into the Order field." % id)
	else:
		var leg: Course.Leg = legs[numbers[0]]
		_panel.show_message("Mark %s goes between %s and %s%s, left to %s. Change its name or side here, or the Order above." % [
			id, leg.from_name, leg.to_name, " (%d laps)" % numbers.size() if numbers.size() > 1 else "",
			CourseMark.side_name(side)])
	_changed()


## The legs a new mark dropped at a screen point (on the water at "water") goes into, by their
## numbers in Course.legs(), the leg it was dropped on first:
## - the leg drawn nearest to the screen point, within NEAR_LEG_PX. Legs are drawn to the right of
##   the way they are sailed, so of a beat and a run on the same line, it is the one on the side
##   of the line where the mark is dropped;
## - unless only_this_leg, also the same leg on the other laps: legs running the same way (within
##   SAME_LEG_DEG) and close by (at most SAME_LEG_M further from the new mark);
## - none when it is dropped away from every leg.
func _legs_for_new_mark(screen: Vector2, water: Vector2, only_this_leg: bool) -> Array[int]:
	var result: Array[int] = []
	var legs: Array[Course.Leg] = course.legs()
	var nearest: int = -1
	var nearest_px: float = NEAR_LEG_PX
	for i: int in legs.size():
		var ends: PackedVector2Array = _overlay.leg_on_screen(legs[i])
		if ends.is_empty():
			continue
		var distance_px: float = screen.distance_to(Geometry2D.get_closest_point_to_segment(screen, ends[0], ends[1]))
		if distance_px < nearest_px:
			nearest = i
			nearest_px = distance_px
	if nearest < 0:
		return result
	result.append(nearest)
	if only_this_leg:
		return result
	var chosen: Course.Leg = legs[nearest]
	var direction: Vector2 = (chosen.to_point - chosen.from_point).normalized()
	var within_m: float = _distance_to_leg(water, chosen) + SAME_LEG_M
	for i: int in legs.size():
		if i == nearest:
			continue
		var other_direction: Vector2 = (legs[i].to_point - legs[i].from_point).normalized()
		if direction.dot(other_direction) >= cos(deg_to_rad(SAME_LEG_DEG)) and _distance_to_leg(water, legs[i]) <= within_m:
			result.append(i)
	return result


func _distance_to_leg(point: Vector2, leg: Course.Leg) -> float:
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point, leg.from_point, leg.to_point))


func _stop_adding() -> void:
	_adding = false
	_preview_at = Vector2.INF
	var no_legs: Array[int] = []
	_overlay.new_mark_point = Vector2.INF
	_overlay.new_mark_legs = no_legs
	_panel.set_adding(false)


func _select(id: String) -> void:
	_selected_id = id
	_overlay.selected = selected_mark()
	_panel.show_selected(_overlay.selected)


# ---------------------------------------------------------------- the panel's other buttons

func _on_template_chosen(id: String) -> void:
	place_template(id, _view_centre.call())
	_panel.show_message("")


func _on_boards_changed(boards: int) -> void:
	if course == null:
		return
	_remember()
	course.boards = boards
	course.set_start_line_length(CourseTemplates.start_line_m(_rules, course.template, boards))
	_changed()


func _on_size_changed(percent: float) -> void:
	if course == null:
		return
	_remember()
	course.set_size(percent)
	_changed()


func _on_axis_changed(degrees: float) -> void:
	if course == null:
		return
	_remember()
	course.set_axis(degrees)
	_changed()


func _on_square_to_wind() -> void:
	if course == null:
		return
	_remember()
	var wind: Vector2 = _wind_now.call()
	course.set_axis(roundf(wind.x))
	_changed()


func _on_undo() -> void:
	if _undo.is_empty():
		_panel.show_message("Nothing to undo.")
		return
	_dragging = null
	_stop_adding()
	course = _undo.pop_back()
	_changed()


func _on_clear() -> void:
	if course == null:
		return
	_remember()
	_stop_adding()
	course = null
	_changed()


# ---------------------------------------------------------------- the mouse and the keys

func _handle_key(key: InputEventKey) -> bool:
	if not key.pressed:
		return false
	match key.physical_keycode:
		KEY_M:
			if not key.echo:
				set_shown(not shown)
			return true
		KEY_Z:
			if key.ctrl_pressed:
				_on_undo()
				return true
		KEY_ESCAPE:
			if _adding:
				_stop_adding()
				_panel.show_message("")
				return true
			if not _selected_id.is_empty():
				_select("")
				return true
		KEY_DELETE:
			if selected_mark() != null and not key.echo:
				delete_selected_mark()
				return true
	return false


func _handle_left_button(button: InputEventMouseButton) -> bool:
	if not button.pressed:
		if _dragging == null:
			return false
		_dragging = null
		_changed()
		return true
	var water: Vector2 = _water_point(button.position)
	if _adding:
		if water.is_finite():
			_add_mark(water, button.position, button.shift_pressed)
		return true
	var mark: CourseMark = _mark_at(button.position)
	if mark == null or not water.is_finite():
		_select("")
		return false
	_select(mark.id)
	_dragging = mark
	_drag_whole = button.shift_pressed
	_drag_from = water
	_drag_remembered = false
	return true


func _handle_motion(motion: InputEventMouseMotion) -> bool:
	if _dragging != null:
		var water: Vector2 = _water_point(motion.position)
		if water.is_finite() and water != _drag_from:
			if not _drag_remembered:
				_remember()
				_drag_remembered = true
			_drag_to(water)
		return true
	if _adding:
		_preview_at = Vector2.INF
		_preview_new_mark(motion.position, motion.shift_pressed)
		return false
	_overlay.hovered = _mark_at(motion.position)
	return false


## While adding a mark: where it would go under a screen point, and the legs it would go into.
func _preview_new_mark(screen: Vector2, only_this_leg: bool) -> void:
	var water: Vector2 = _water_point(screen) if screen.is_finite() else Vector2.INF
	var no_legs: Array[int] = []
	_overlay.new_mark_point = water
	_overlay.new_mark_legs = _legs_for_new_mark(screen, water, only_this_leg) if water.is_finite() else no_legs


## The mark nearest to a screen point, if it is within PICK_RADIUS_PX; rounding marks before the
## line ends when they overlap.
func _mark_at(screen: Vector2) -> CourseMark:
	if course == null or _overlay.camera == null:
		return null
	var best: CourseMark = null
	var best_px: float = PICK_RADIUS_PX
	for mark: CourseMark in course.marks:
		var at: Vector2 = _overlay.screen_point(mark.position)
		if not at.is_finite():
			continue
		var distance_px: float = at.distance_to(screen) - (2.0 if not mark.is_line_end() else 0.0)
		if distance_px < best_px:
			best = mark
			best_px = distance_px
	return best


## The point of the lake (game X, Z) under a screen point, or Vector2.INF if the view doesn't go
## down to it there. At the height the marks are drawn, so a mark put down lies under the mouse.
func _water_point(screen: Vector2) -> Vector2:
	var camera: Camera3D = _overlay.camera
	if camera == null:
		return Vector2.INF
	var origin: Vector3 = camera.project_ray_origin(screen)
	var direction: Vector3 = camera.project_ray_normal(screen)
	if direction.y > -0.0001:
		return Vector2.INF
	var hit: Vector3 = origin + direction * ((CourseOverlay.DRAW_HEIGHT_M - origin.y) / direction.y)
	return Vector2(hit.x, hit.z)


## Moves what is being dragged by as much as the mouse moved on the water, so the mark keeps the
## spot where it was grabbed.
func _drag_to(water: Vector2) -> void:
	var offset: Vector2 = water - _drag_from
	_drag_from = water
	if _drag_whole:
		course.move_by(offset)
	else:
		_dragging.position += offset
		var other: CourseMark = course.partner(_dragging)
		if _dragging.is_gate_mark() and other != null:
			other.position += offset
	_changed()


# ---------------------------------------------------------------- keeping everything up to date

func _remember() -> void:
	_remember_version(course.copy() if course != null else null)


func _remember_version(version: Course) -> void:
	_undo.append(version)
	if _undo.size() > UNDO_LIMIT:
		_undo.pop_front()


## After every change: what the overlay draws and the panel shows.
func _changed() -> void:
	_overlay.course = course
	var marks_with_problems: Array[CourseMark] = []
	if course != null:
		marks_with_problems = course.marks_not_on_water(_height_at)
	_overlay.marks_with_problems = marks_with_problems
	if selected_mark() == null:
		_selected_id = ""
	_select(_selected_id)
	_update_panel()


## The panel: a summary line, the legs and the warnings.
func _update_panel() -> void:
	var rows: Array[PackedStringArray] = []
	if course == null:
		_panel.show_course(null, "", PackedStringArray(), rows, PackedStringArray())
		return
	var wind: Vector2 = _wind_now.call()
	var total_m: float = 0.0
	for leg: Course.Leg in course.legs():
		total_m += leg.length_m()
		# The angle between the way the leg is sailed and where the wind comes from: 0 straight upwind.
		var to_wind: float = absf(Course.turn_deg(wind.x, leg.bearing_deg()))
		var kind: String = "upwind" if to_wind < 60.0 else ("reach" if to_wind <= 120.0 else "downwind")
		rows.append(PackedStringArray([
			"%s → %s" % [leg.from_name, leg.to_name],
			"%.0f m" % leg.length_m(),
			"%03.0f°" % leg.bearing_deg(),
			"%s %.0f°" % [kind, to_wind]]))
	var off_axis: float = Course.turn_deg(course.axis_deg, wind.x)
	var summary: String = "%s, %.1f km\nWind now %.1f kt from %03.0f°, %.0f° %s of the axis (%03.0f°)" % [
		course.template, total_m / 1000.0, wind.y, wind.x, absf(off_axis),
		"right" if off_axis >= 0.0 else "left", course.axis_deg]
	var warnings: PackedStringArray = course.problems(_height_at)
	var lone: PackedStringArray = course.marks_not_in_order()
	if not lone.is_empty():
		warnings.append("Not in the order yet: %s (type it into the Order field)" % ", ".join(lone))
	_panel.show_course(course, summary, PackedStringArray(["Leg", "Length", "Course", "To the wind"]), rows, warnings)


func _read_saved_courses() -> void:
	_saved.clear()
	var names: PackedStringArray = PackedStringArray()
	if DirAccess.dir_exists_absolute(_folder):
		for file: String in DirAccess.get_files_at(_folder):
			if file.get_extension() != "json":
				continue
			var path: String = _folder.path_join(file)
			var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			var course_name: String = str((data as Dictionary).get("name", file.get_basename())) if data is Dictionary else file.get_basename()
			_saved[course_name] = path
			names.append(course_name)
	names.sort()
	_panel.set_saved_courses(names)


## A file name for a course name: lower case letters, digits and underscores.
static func _file_name(course_name: String) -> String:
	var result: String = ""
	for character: String in course_name.to_lower():
		var allowed: bool = (character >= "a" and character <= "z") or (character >= "0" and character <= "9")
		result += character if allowed else "_"
	while result.contains("__"):
		result = result.replace("__", "_")
	return result.trim_prefix("_").trim_suffix("_")
