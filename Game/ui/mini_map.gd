class_name MiniMap
extends Control
## A small map in the HUD (MAP_SILVAPLANA_PLAN.md, M3). In a map scene it shows the lake: its
## outline (from LakeArea, drawn once) and the start spot as a ring. On the open water, with a race
## course, it shows the course's water instead (setup_for_course(): the course's marks and 200 m
## around them, no outline). Both show the board as a dot with a tick toward its heading, and the
## wind as an arrow in the corner that points the way the wind blows. North is up, as on the
## compass (MD1: north is -Z in the game too).
##
## A race course (show_course(), RACING_PLAN.md 9A) is drawn as the course maker draws it
## (course_overlay.gd), scaled down: the legs faintly in the order they are sailed, the start and
## finish lines, and the marks as small dots with their names.

## The longer side of the map on the screen, in pixels.
const SIZE_PX: float = 200.0
## Land shown around the lake, in metres.
const BORDER_M: float = 120.0
## Water shown around a course on the open water, in metres.
const COURSE_BORDER_M: float = 200.0
const WATER_COLOR: Color = Color(0.2, 0.42, 0.55, 0.85)
const LAND_COLOR: Color = Color(0.16, 0.2, 0.14, 0.6)
const BOARD_COLOR: Color = Color(1.0, 0.6, 0.1)
const OTHER_BOARD_COLOR: Color = Color(0.9, 0.9, 0.95)
const START_COLOR: Color = Color(1.0, 1.0, 1.0, 0.85)
const WIND_COLOR: Color = Color(0.5, 0.85, 1.0)
## The course, in the colours of the marks on the water (course_on_water.gd).
const LEG_COLOR: Color = Color(0.05, 0.05, 0.05, 0.45)
const LEG_HALO: Color = Color(1.0, 1.0, 1.0, 0.3)
const LINE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.95)
const MARK_FONT_SIZE: int = 10
## Each leg is drawn this many pixels to the right of its line, so a beat and the run back down
## the same line lie side by side (as in the course maker).
const LEG_OFFSET_PX: float = 2.0

var board_position: Vector3 = Vector3.ZERO
var heading_deg: float = 0.0
var wind_from_deg: float = 0.0
## The other boards of a race, as smaller dots (Hud.set_other_boards).
var other_boards: PackedVector3Array = PackedVector3Array()
## The race course drawn on the map (null: none).
var course: Course = null

## The lake's picture; null on the open water.
var _texture: ImageTexture
## The part of the world shown, in game metres: position = (west X, north Z).
var _shown: Rect2
## Where the image's top-left corner is in the world, and how many metres one pixel covers.
var _image_origin: Vector2
var _metres_per_pixel: float = 1.0
## The start spot's ring (the lake only).
var _start: Vector3 = Vector3.INF


## Draws the lake once and sizes the map to the lake's shape.
func setup(area: LakeArea, start: Vector3) -> void:
	_texture = ImageTexture.create_from_image(area.make_image(WATER_COLOR, LAND_COLOR))
	_metres_per_pixel = area.step_m
	# A pixel stands for the square around its spot, so the image starts half a step earlier.
	_image_origin = Vector2(area.x0_m, area.z0_m) - Vector2.ONE * area.step_m * 0.5
	_start = start
	_size_to(area.lake_bounds().grow(BORDER_M))


## The open water's map: the course's marks and COURSE_BORDER_M of water around them.
func setup_for_course(race_course: Course) -> void:
	_texture = null
	_start = Vector3.INF
	_size_to(race_course.bounds().grow(COURSE_BORDER_M))
	show_course(race_course)


## Draws a race course on the map (null: none).
func show_course(race_course: Course) -> void:
	course = race_course
	queue_redraw()


## Where a game position is on the map, in pixels from the map's top-left corner.
func map_point(at: Vector3) -> Vector2:
	return _map_point_xz(Vector2(at.x, at.z))


func _size_to(shown: Rect2) -> void:
	_shown = shown
	var pixels_per_metre: float = SIZE_PX / maxf(_shown.size.x, _shown.size.y)
	custom_minimum_size = _shown.size * pixels_per_metre
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _map_point_xz(at: Vector2) -> Vector2:
	return (at - _shown.position) / _shown.size * size


func _draw() -> void:
	if _shown.size == Vector2.ZERO:
		return
	if _texture != null:
		var source: Rect2 = Rect2((_shown.position - _image_origin) / _metres_per_pixel, _shown.size / _metres_per_pixel)
		draw_texture_rect_region(_texture, Rect2(Vector2.ZERO, size), source)
	else:
		draw_rect(Rect2(Vector2.ZERO, size), WATER_COLOR)
	draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 1.0, 1.0, 0.5), false, 1.0)
	if _start.is_finite():
		draw_arc(map_point(_start), 5.0, 0.0, TAU, 16, START_COLOR, 1.5)
	if course != null:
		_draw_course()
	_draw_board()
	_draw_wind_arrow()


## The course, as the course maker draws it but small: the legs faint, under the lines and marks.
func _draw_course() -> void:
	for leg: Course.Leg in course.legs():
		_draw_leg(leg)
	for ends: PackedStringArray in [
			PackedStringArray([CourseMark.START_BOAT, CourseMark.START_PIN]),
			PackedStringArray([CourseMark.FINISH_BOAT, CourseMark.FINISH_PIN])]:
		var boat: CourseMark = course.mark(ends[0])
		var pin: CourseMark = course.mark(ends[1])
		if boat != null and pin != null:
			var a: Vector2 = _map_point_xz(boat.position)
			var b: Vector2 = _map_point_xz(pin.position)
			draw_line(a, b, Color(0.0, 0.0, 0.0, 0.5), 3.0, true)
			draw_line(a, b, LINE_COLOR, 1.5, true)
	for mark: CourseMark in course.marks:
		if mark.is_line_end():
			continue
		var at: Vector2 = _map_point_xz(mark.position)
		var color: Color = CourseOnWater.GATE_COLOR if mark.is_gate_mark() else CourseOnWater.MARK_COLOR
		draw_circle(at, 3.0, color)
		draw_circle(at, 3.0, Color(0.0, 0.0, 0.0, 0.6), false, 1.0, true)
		_label(at + Vector2(4.0, -3.0), mark.id)


## A leg: a faint dark line with a light halo, a little to the right of the way it is sailed, with
## a small arrow in its middle.
func _draw_leg(leg: Course.Leg) -> void:
	var a: Vector2 = _map_point_xz(leg.from_point)
	var b: Vector2 = _map_point_xz(leg.to_point)
	if a.distance_to(b) < 1.0:
		return
	var along: Vector2 = (b - a).normalized()
	# The screen's y points down: the right of a direction (x, y) is (-y, x).
	var right: Vector2 = Vector2(-along.y, along.x) * LEG_OFFSET_PX
	draw_line(a + right, b + right, LEG_HALO, 2.5, true)
	draw_line(a + right, b + right, LEG_COLOR, 1.0, true)
	var tip: Vector2 = (a + b) / 2.0 + right + along * 2.5
	var side: Vector2 = Vector2(-along.y, along.x) * 2.5
	draw_colored_polygon(PackedVector2Array([tip, tip - along * 5.0 + side, tip - along * 5.0 - side]), LEG_COLOR)


func _label(at: Vector2, text: String) -> void:
	var font: Font = ThemeDB.fallback_font
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, MARK_FONT_SIZE, 3, Color.BLACK)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, MARK_FONT_SIZE, Color.WHITE)


## The board: a dot, and a tick toward its heading. Bearings are clockwise from North and the
## screen's y points down, so bearing b points along (sin b, -cos b). On the open water the board
## can sail off the course's map: it then stays at the map's edge, so you see which way it is.
func _draw_board() -> void:
	for other: Vector3 in other_boards:
		draw_circle(map_point(other).clamp(Vector2.ZERO, size), 3.0, OTHER_BOARD_COLOR)
	var at: Vector2 = map_point(board_position).clamp(Vector2.ZERO, size)
	var heading: Vector2 = Vector2(sin(deg_to_rad(heading_deg)), -cos(deg_to_rad(heading_deg)))
	draw_line(at, at + heading * 12.0, BOARD_COLOR, 2.0)
	draw_circle(at, 4.0, BOARD_COLOR)


## The wind in the top-left corner: the arrow points the way the wind blows (it comes FROM the tail).
func _draw_wind_arrow() -> void:
	var centre: Vector2 = Vector2(22.0, 22.0)
	var from: Vector2 = Vector2(sin(deg_to_rad(wind_from_deg)), -cos(deg_to_rad(wind_from_deg)))
	var tail: Vector2 = centre + from * 14.0
	var head: Vector2 = centre - from * 14.0
	draw_line(tail, head, WIND_COLOR, 2.5)
	var wing: Vector2 = Vector2(from.y, -from.x) * 5.0
	draw_colored_polygon(PackedVector2Array([head, head + from * 8.0 + wing, head + from * 8.0 - wing]), WIND_COLOR)
