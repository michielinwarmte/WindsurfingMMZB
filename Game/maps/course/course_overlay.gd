class_name CourseOverlay
extends Control
## Draws a race course over the 3D view (MAP_SILVAPLANA_PLAN.md, W4a), in the style of the Notice of
## Race's diagrams:
## - the marks in salmon red with their names, and a curved arrow showing how they are rounded: it
##   comes in from the leg to the mark, goes round the mark's far side (anticlockwise for port,
##   clockwise for starboard, seen from above) and leaves along the next leg. So at a gate the boats
##   come down between the two marks and turn outwards, back upwind, as on the diagrams;
## - the committee and finish boats in green, with their orange and blue flags, and the pins;
## - the start and finish lines dashed;
## - the legs in black with an arrow, in the order they are sailed. Each leg is drawn a few pixels
##   to the right of its line (looking along it), so a beat and the run back down the same line
##   lie side by side, as on the diagrams.
## While a mark is being added, the legs it will go into are lit in yellow, and a pale mark with
## dashed lines shows where it will be. The selected mark has a yellow ring.
## It only draws and never takes the mouse: CourseEditor does the dragging.

const MARK_RADIUS_PX: float = 7.0
const PIN_RADIUS_PX: float = 5.0
const RING_RADIUS_PX: float = 11.0
const ROUNDING_RADIUS_PX: float = 15.0
## The rounding arrow starts this far before the board is abeam of the mark, where it starts to turn.
const ROUNDING_LEAD_DEG: float = 45.0
const LEG_OFFSET_PX: float = 6.0
const ARROW_PX: float = 9.0
const FONT_SIZE: int = 14
const MARK_COLOR: Color = Color("#f28b82")
const MARK_EDGE: Color = Color("#7a1f1a")
const BOAT_COLOR: Color = Color("#2fbf71")
const START_FLAG: Color = Color("#ff8c1a")
const FINISH_FLAG: Color = Color("#2f6fe0")
const LEG_COLOR: Color = Color(0.06, 0.06, 0.06)
const HALO: Color = Color(1.0, 1.0, 1.0, 0.7)
const LINE_COLOR: Color = Color(1.0, 1.0, 1.0)
const SHADOW: Color = Color(0.0, 0.0, 0.0, 0.55)
const PROBLEM_COLOR: Color = Color("#ff3b30")
const SELECTED_COLOR: Color = Color("#ffd60a")
const HIGHLIGHT_COLOR: Color = Color(1.0, 0.84, 0.04, 0.85)
## The marks float on the water: drawn this high above the lake, metres.
const DRAW_HEIGHT_M: float = 0.3

var course: Course
var camera: Camera3D
## The mark under the mouse, drawn with a white ring (null for none).
var hovered: CourseMark
## Marks drawn with a red ring: on land or off the map.
var marks_with_problems: Array[CourseMark] = []
## The selected mark, with a yellow ring (null for none).
var selected: CourseMark
## While a mark is being added: where it would go (Vector2.INF for nowhere) and the legs it would
## go into (their numbers in Course.legs()).
var new_mark_point: Vector2 = Vector2.INF
var new_mark_legs: Array[int] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Where a point on the lake (game X, Z) is on the screen, or Vector2.INF when it is behind the camera.
func screen_point(at: Vector2) -> Vector2:
	var point: Vector3 = Vector3(at.x, DRAW_HEIGHT_M, at.y)
	if camera == null or camera.is_position_behind(point):
		return Vector2.INF
	return camera.unproject_position(point)


## A leg as it is drawn on the screen: its two ends, shifted to the right of the way it is sailed;
## empty if it is behind the camera. The course maker picks legs by this, so the leg under the
## mouse is the one you see there.
func leg_on_screen(leg: Course.Leg) -> PackedVector2Array:
	var ends: PackedVector2Array = _on_screen(leg.from_point, leg.to_point)
	if ends.is_empty():
		return ends
	var along: Vector2 = (ends[1] - ends[0]).normalized()
	var right: Vector2 = _right_of(along) * LEG_OFFSET_PX
	return PackedVector2Array([ends[0] + right, ends[1] + right])


func _draw() -> void:
	if course == null or camera == null:
		return
	var legs: Array[Course.Leg] = course.legs()
	for number: int in new_mark_legs:
		if number < legs.size():
			var ends: PackedVector2Array = leg_on_screen(legs[number])
			if not ends.is_empty():
				draw_line(ends[0], ends[1], HIGHLIGHT_COLOR, 9.0, true)
	for leg: Course.Leg in legs:
		_draw_leg(leg)
	_draw_new_mark(legs)
	_draw_line_between(CourseMark.START_BOAT, CourseMark.START_PIN)
	_draw_line_between(CourseMark.FINISH_BOAT, CourseMark.FINISH_PIN)
	for mark: CourseMark in course.marks:
		var at: Vector2 = screen_point(mark.position)
		if not at.is_finite():
			continue
		if mark.is_boat():
			_draw_boat(at, START_FLAG if mark.id == CourseMark.START_BOAT else FINISH_FLAG,
				"Start" if mark.id == CourseMark.START_BOAT else "Finish")
		elif mark.is_line_end():
			draw_circle(at, PIN_RADIUS_PX, MARK_COLOR)
			draw_circle(at, PIN_RADIUS_PX, MARK_EDGE, false, 1.5, true)
		else:
			_draw_mark(at, mark)
		if mark in marks_with_problems:
			draw_circle(at, RING_RADIUS_PX, PROBLEM_COLOR, false, 2.5, true)
		if mark == selected:
			draw_circle(at, (RING_RADIUS_PX + 3.0), SELECTED_COLOR, false, 3.0, true)
		elif mark == hovered:
			draw_circle(at, (RING_RADIUS_PX + 3.0), LINE_COLOR, false, 2.0, true)


## A leg: a black line with a white halo, shifted to the right of the way it is sailed, with an
## arrow in its middle.
func _draw_leg(leg: Course.Leg) -> void:
	var ends: PackedVector2Array = leg_on_screen(leg)
	if ends.is_empty() or ends[0] == ends[1]:
		return
	var along: Vector2 = (ends[1] - ends[0]).normalized()
	draw_line(ends[0], ends[1], HALO, 4.5, true)
	draw_line(ends[0], ends[1], LEG_COLOR, 2.0, true)
	_arrow_head((ends[0] + ends[1]) / 2.0 + along * ARROW_PX / 2.0, along, ARROW_PX)


## While a mark is being added: a pale mark where it would go, with dashed lines from the ends of
## the legs it would go into, so you see the course it would make.
func _draw_new_mark(legs: Array[Course.Leg]) -> void:
	var at: Vector2 = screen_point(new_mark_point)
	if not at.is_finite():
		return
	for number: int in new_mark_legs:
		if number >= legs.size():
			continue
		for end: Vector2 in [legs[number].from_point, legs[number].to_point]:
			var ends: PackedVector2Array = _on_screen(end, new_mark_point)
			if not ends.is_empty():
				draw_dashed_line(ends[0], ends[1], SELECTED_COLOR, 2.0, 6.0, true, true)
	draw_circle(at, MARK_RADIUS_PX, Color(MARK_COLOR, 0.6))
	draw_circle(at, MARK_RADIUS_PX, SELECTED_COLOR, false, 2.0, true)


## A start or finish line: dashed, between its two ends.
func _draw_line_between(boat_id: String, pin_id: String) -> void:
	var boat: CourseMark = course.mark(boat_id)
	var pin: CourseMark = course.mark(pin_id)
	if boat == null or pin == null:
		return
	var ends: PackedVector2Array = _on_screen(boat.position, pin.position)
	if ends.is_empty():
		return
	draw_line(ends[0], ends[1], SHADOW, 3.5, true)
	draw_dashed_line(ends[0], ends[1], LINE_COLOR, 2.0, 7.0, true, true)


## A rounding mark: a salmon disc, its name, and a curved arrow round it the way it is rounded.
func _draw_mark(at: Vector2, mark: CourseMark) -> void:
	var arc: Vector2 = rounding_arc(at, mark)
	var radius: float = ROUNDING_RADIUS_PX
	draw_arc(at, radius, arc.x, arc.y, 32, HALO, 4.0, true)
	draw_arc(at, radius, arc.x, arc.y, 32, LEG_COLOR, 1.8, true)
	# The arrow at the end of the arc, pointing the way the board goes on round the mark.
	var turn: float = signf(arc.y - arc.x)
	var tip: Vector2 = at + radius * Vector2(cos(arc.y), sin(arc.y))
	var along: Vector2 = Vector2(-sin(arc.y), cos(arc.y)) * turn
	_arrow_head(tip + along * 4.0, along, 8.0)
	draw_circle(at, MARK_RADIUS_PX, MARK_COLOR)
	draw_circle(at, MARK_RADIUS_PX, MARK_EDGE, false, 1.5, true)
	_label(at + Vector2(radius + 3.0, -radius + 2.0), mark.id)


## The rounding arrow of a mark on the screen: Vector2(the angle it starts at, the angle it ends at),
## in the screen's angles (they grow clockwise, as the screen's Y points down).
## A board leaving a mark to port has it on its left, so it passes on the mark's right side (looking
## the way it sails) and turns round it anticlockwise; to starboard the other way round. So the
## arrow starts beside the mark on the side the board passes (a little before it is abeam), and
## ends on the side it leaves on, pointing along the next leg. A mark that is not in the order gets
## a plain three-quarter turn.
func rounding_arc(at: Vector2, mark: CourseMark) -> Vector2:
	var port: bool = mark.side != CourseMark.Rounding.STARBOARD
	var turn: float = -1.0 if port else 1.0
	var directions: PackedVector2Array = course.turn_at(mark.id)
	if directions.is_empty():
		return Vector2(-PI / 2.0, -PI / 2.0 + turn * 1.5 * PI)
	var coming: Vector2 = _screen_direction(mark.position, directions[0])
	var going: Vector2 = _screen_direction(mark.position, directions[1])
	if coming == Vector2.ZERO or going == Vector2.ZERO:
		return Vector2(-PI / 2.0, -PI / 2.0 + turn * 1.5 * PI)
	# Where the board is beside the mark: on its right (port) or left (starboard) side.
	var start: float = (_right_of(coming) if port else -_right_of(coming)).angle()
	var end: float = (_right_of(going) if port else -_right_of(going)).angle()
	# How far it goes round, the way it turns (anticlockwise on the screen is a falling angle).
	var sweep: float = fposmod((end - start) * turn, TAU)
	var lead: float = deg_to_rad(ROUNDING_LEAD_DEG)
	sweep = minf(sweep + lead, deg_to_rad(330.0))
	return Vector2(end - turn * sweep, end)


## The screen direction of a direction on the lake (game X, Z) at a point, one pixel long, or zero
## when it can't be seen.
func _screen_direction(at: Vector2, direction: Vector2) -> Vector2:
	var a: Vector2 = screen_point(at)
	var b: Vector2 = screen_point(at + direction * 10.0)
	if not a.is_finite() or not b.is_finite() or a == b:
		return Vector2.ZERO
	return (b - a).normalized()


## A committee or finish boat: a small green hull with its flag, and its name.
func _draw_boat(at: Vector2, flag: Color, text: String) -> void:
	var hull: PackedVector2Array = PackedVector2Array([
		at + Vector2(-10.0, -3.5), at + Vector2(6.0, -3.5), at + Vector2(11.0, 0.0),
		at + Vector2(6.0, 3.5), at + Vector2(-10.0, 3.5)])
	draw_colored_polygon(hull, BOAT_COLOR)
	draw_polyline(hull + PackedVector2Array([hull[0]]), Color(0.0, 0.25, 0.1), 1.2, true)
	draw_line(at + Vector2(0.0, -3.5), at + Vector2(0.0, -17.0), LEG_COLOR, 1.5, true)
	draw_colored_polygon(PackedVector2Array([at + Vector2(0.0, -17.0), at + Vector2(10.0, -14.0), at + Vector2(0.0, -11.0)]), flag)
	_label(at + Vector2(13.0, 4.0), text)


## A filled arrow head with its tip at a point, pointing along a direction.
func _arrow_head(tip: Vector2, along: Vector2, length: float) -> void:
	var side: Vector2 = _right_of(along) * length * 0.55
	draw_colored_polygon(PackedVector2Array([tip, tip - along * length + side, tip - along * length - side]), LEG_COLOR)


func _label(at: Vector2, text: String) -> void:
	var font: Font = ThemeDB.fallback_font
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 4, Color.BLACK)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color.WHITE)


## The right-hand side of a direction on the screen (the screen's Y points down).
static func _right_of(direction: Vector2) -> Vector2:
	return Vector2(-direction.y, direction.x)


## A straight piece of the lake between two points, on the screen: its two ends, cut where it goes
## behind the camera (the free camera close to the water); empty if it is all behind.
func _on_screen(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a: Vector3 = Vector3(from.x, DRAW_HEIGHT_M, from.y)
	var b: Vector3 = Vector3(to.x, DRAW_HEIGHT_M, to.y)
	var eye: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_basis.z
	var nearest_m: float = camera.near + 0.5
	var depth_a: float = (a - eye).dot(forward)
	var depth_b: float = (b - eye).dot(forward)
	if depth_a < nearest_m and depth_b < nearest_m:
		return PackedVector2Array()
	if depth_a < nearest_m:
		a = a.lerp(b, (nearest_m - depth_a) / (depth_b - depth_a))
	elif depth_b < nearest_m:
		b = b.lerp(a, (nearest_m - depth_b) / (depth_a - depth_b))
	return PackedVector2Array([camera.unproject_position(a), camera.unproject_position(b)])
