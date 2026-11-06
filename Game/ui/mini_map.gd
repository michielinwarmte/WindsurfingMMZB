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
## finish lines, and the marks as small dots with their names. show_course() again with a changed
## course (the LAN race director moves a mark) draws it at once; on the open water the map is framed
## anew only when a mark comes near its edge, so it does not jump while a mark is dragged.
##
## How big: size_px, the map's longer side; the HUD sets it from the setting "Mini-map size", a share
## of the window's height (size_for()), and changes it at once when the setting changes.

## The map's longer side by default, pixels (35 % of a 720-pixel-high layout; it was 200).
const SIZE_PX: float = 252.0
## The setting "Mini-map size": the map's longer side as a share of the window's height, percent.
## At most half: then a race's standings still have four lines above it (RaceHud.fleet_room_rows()).
const SIZE_MIN_PERCENT: float = 20.0
const SIZE_MAX_PERCENT: float = 50.0
const SIZE_DEFAULT_PERCENT: float = 35.0
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
const MARK_FONT_SIZE: int = 12
const MARK_RADIUS_PX: float = 4.0
const OTHER_BOARD_RADIUS_PX: float = 3.5
const BOARD_RADIUS_PX: float = 5.0
## On the open water a course's map is framed anew when a mark comes this near its edge, metres.
const REFRAME_MARGIN_M: float = 40.0
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
## The map's longer side on the screen, pixels (set it to resize the map).
var size_px: float = SIZE_PX:
	set(value):
		size_px = value
		if _shown.size != Vector2.ZERO:
			_size_to(_shown)

## The lake's picture; null on the open water.
var _texture: ImageTexture
## The part of the world shown, in game metres: position = (west X, north Z).
var _shown: Rect2
## Where the image's top-left corner is in the world, and how many metres one pixel covers.
var _image_origin: Vector2
var _metres_per_pixel: float = 1.0
## The start spot's ring (the lake only).
var _start: Vector3 = Vector3.INF
## The open water: the map shows the course's own water (setup_for_course()).
var _frames_course: bool = false


## A word for a size of the setting: small, medium, large, extra large.
static func size_name(percent: float) -> String:
	if percent < 30.0:
		return "small"
	if percent < 40.0:
		return "medium"
	if percent < 50.0:
		return "large"
	return "extra large"


## The map's longer side for the setting: `percent` of a window `screen_height_px` high.
static func size_for(percent: float, screen_height_px: float) -> float:
	return clampf(percent, SIZE_MIN_PERCENT, SIZE_MAX_PERCENT) * 0.01 * screen_height_px


## Draws the lake once and sizes the map to the lake's shape.
func setup(area: LakeArea, start: Vector3) -> void:
	_texture = ImageTexture.create_from_image(area.make_image(WATER_COLOR, LAND_COLOR))
	_metres_per_pixel = area.step_m
	# A pixel stands for the square around its spot, so the image starts half a step earlier.
	_image_origin = Vector2(area.x0_m, area.z0_m) - Vector2.ONE * area.step_m * 0.5
	_start = start
	_frames_course = false
	_size_to(area.lake_bounds().grow(BORDER_M))


## The open water's map: the course's marks and COURSE_BORDER_M of water around them.
func setup_for_course(race_course: Course) -> void:
	_texture = null
	_start = Vector3.INF
	_frames_course = true
	_size_to(race_course.bounds().grow(COURSE_BORDER_M))
	show_course(race_course)


## Draws a race course on the map (null: none), at once; again with a changed course. On the open
## water a mark that came near the map's edge frames the map anew (its size may change: `resized`).
func show_course(race_course: Course) -> void:
	course = race_course
	if _frames_course and course != null and not _shown.grow(-REFRAME_MARGIN_M).encloses(course.bounds()):
		_size_to(course.bounds().grow(COURSE_BORDER_M))
	queue_redraw()


## Where a game position is on the map, in pixels from the map's top-left corner.
func map_point(at: Vector3) -> Vector2:
	return _map_point_xz(Vector2(at.x, at.z))


func _size_to(shown: Rect2) -> void:
	_shown = shown
	var pixels_per_metre: float = size_px / maxf(_shown.size.x, _shown.size.y)
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
		draw_circle(at, MARK_RADIUS_PX, color)
		draw_circle(at, MARK_RADIUS_PX, Color(0.0, 0.0, 0.0, 0.6), false, 1.0, true)
		_label(at + Vector2(MARK_RADIUS_PX + 2.0, -MARK_RADIUS_PX), mark.id)


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
	var font: Font = HudStyle.sans(700)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, MARK_FONT_SIZE, 3, Color.BLACK)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, MARK_FONT_SIZE, Color.WHITE)


## The board: a dot, and a tick toward its heading. Bearings are clockwise from North and the
## screen's y points down, so bearing b points along (sin b, -cos b). On the open water the board
## can sail off the course's map: it then stays at the map's edge, so you see which way it is.
func _draw_board() -> void:
	for other: Vector3 in other_boards:
		var dot: Vector2 = map_point(other).clamp(Vector2.ZERO, size)
		draw_circle(dot, OTHER_BOARD_RADIUS_PX, OTHER_BOARD_COLOR)
		draw_circle(dot, OTHER_BOARD_RADIUS_PX, Color(0.0, 0.0, 0.0, 0.5), false, 1.0, true)
	var at: Vector2 = map_point(board_position).clamp(Vector2.ZERO, size)
	var heading: Vector2 = Vector2(sin(deg_to_rad(heading_deg)), -cos(deg_to_rad(heading_deg)))
	draw_line(at, at + heading * (BOARD_RADIUS_PX + 10.0), BOARD_COLOR, 2.5, true)
	draw_circle(at, BOARD_RADIUS_PX, BOARD_COLOR)
	draw_circle(at, BOARD_RADIUS_PX, Color(0.0, 0.0, 0.0, 0.6), false, 1.0, true)


## The wind in the top-left corner: the arrow points the way the wind blows (it comes FROM the tail).
func _draw_wind_arrow() -> void:
	var centre: Vector2 = Vector2(22.0, 22.0)
	var from: Vector2 = Vector2(sin(deg_to_rad(wind_from_deg)), -cos(deg_to_rad(wind_from_deg)))
	var tail: Vector2 = centre + from * 14.0
	var head: Vector2 = centre - from * 14.0
	draw_line(tail, head, WIND_COLOR, 2.5)
	var wing: Vector2 = Vector2(from.y, -from.x) * 5.0
	draw_colored_polygon(PackedVector2Array([head, head + from * 8.0 + wing, head + from * 8.0 - wing]), WIND_COLOR)
