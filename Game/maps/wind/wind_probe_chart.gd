class_name WindProbeChart
extends Control
## The wind at a clicked point over the last minutes (the wind viewer, MAP_SILVAPLANA_PLAN.md W2):
## the speed in knots and the direction it comes from, in two small charts, one above the other
## (they have different units, so they don't share an axis). Move the mouse over a chart to read
## the values at that moment.

const PADDING_PX: float = 10.0
const FONT_SIZE: int = 13
const TITLE_SIZE: int = 15
const LINE: Color = Color("#86b6ef")
const TEXT: Color = Color(1.0, 1.0, 1.0)
const MUTED: Color = Color(1.0, 1.0, 1.0, 0.6)
const GRID: Color = Color(1.0, 1.0, 1.0, 0.15)
const BACKGROUND: Color = Color(0.05, 0.07, 0.1, 0.78)

## The heading line, for example where the point is.
var title: String = ""
## The time span shown (seconds since midnight), and the moments in it that have a value, oldest
## first, with the wind at each. Moments still missing (just after a click) leave a gap.
var start_s: float = 0.0
var end_s: float = 1.0
var times_s: PackedFloat32Array = PackedFloat32Array()
var knots: PackedFloat32Array = PackedFloat32Array()
var from_deg: PackedFloat32Array = PackedFloat32Array()

var _hover_x: float = -1.0


## Shows a new history from first_s to last_s. The three arrays have one value per moment.
func show_history(heading: String, first_s: float, last_s: float, moments_s: PackedFloat32Array,
		speeds_kt: PackedFloat32Array, directions_deg: PackedFloat32Array) -> void:
	title = heading
	start_s = first_s
	end_s = maxf(last_s, first_s + 1.0)
	times_s = moments_s
	knots = speeds_kt
	from_deg = directions_deg
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_hover_x = (event as InputEventMouseMotion).position.x
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover_x = -1.0
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
	if times_s.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	var last: int = times_s.size() - 1
	var y: float = PADDING_PX + TITLE_SIZE
	draw_string(font, Vector2(PADDING_PX, y), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 2.0 * PADDING_PX, TITLE_SIZE, TEXT)
	y += FONT_SIZE + 8.0
	draw_string(font, Vector2(PADDING_PX, y), "Now: %.1f kt from %03.0f°" % [knots[last], from_deg[last]],
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, TEXT)
	var chart_height: float = (size.y - y - 3.0 * PADDING_PX - 3.0 * FONT_SIZE - 4.0) / 2.0
	var left: float = PADDING_PX + 34.0
	var width: float = size.x - left - PADDING_PX
	var speed_chart: Rect2 = Rect2(left, y + PADDING_PX + FONT_SIZE + 4.0, width, chart_height)
	var direction_chart: Rect2 = Rect2(left, speed_chart.end.y + PADDING_PX + FONT_SIZE, width, chart_height)
	_chart(font, speed_chart, knots, 4.0, "Speed (kt)", false)
	_chart(font, direction_chart, _unwrapped(from_deg), 10.0, "From (°)", true)
	# The time axis under the lower chart: minutes before now.
	var minutes: float = (end_s - start_s) / 60.0
	var axis_y: float = direction_chart.end.y + FONT_SIZE + 2.0
	draw_string(font, Vector2(left, axis_y), "-%.0f min" % minutes, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, MUTED)
	draw_string(font, Vector2(direction_chart.end.x - 30.0, axis_y), "now", HORIZONTAL_ALIGNMENT_RIGHT, 30.0, FONT_SIZE, MUTED)
	_hover(font, speed_chart, direction_chart)


## One chart: the values as a line, with the lowest and highest value of its scale on the left.
## The scale spans at least min_span, so a steady wind looks steady. Directions are labelled as
## compass bearings, 000 to 359.
func _chart(font: Font, rect: Rect2, values: PackedFloat32Array, min_span: float, label: String, is_direction: bool) -> void:
	var low: float = _min(values)
	var high: float = _max(values)
	var middle: float = (low + high) / 2.0
	var half: float = maxf((high - low) / 2.0 * 1.15, min_span / 2.0)
	low = middle - half
	high = middle + half
	draw_string(font, rect.position + Vector2(0.0, -4.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, MUTED)
	draw_line(Vector2(rect.position.x, rect.end.y), rect.end, GRID, 1.0)
	draw_line(rect.position, Vector2(rect.end.x, rect.position.y), GRID, 1.0)
	draw_string(font, Vector2(PADDING_PX, rect.position.y + FONT_SIZE), _scale_label(high, is_direction), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, MUTED)
	draw_string(font, Vector2(PADDING_PX, rect.end.y), _scale_label(low, is_direction), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, MUTED)
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in values.size():
		points.append(Vector2(_x_of(rect, times_s[i]), rect.end.y - (values[i] - low) / (high - low) * rect.size.y))
	if points.size() >= 2:
		draw_polyline(points, LINE, 2.0, true)


## A vertical line under the mouse, with the time and the values there.
func _hover(font: Font, speed_chart: Rect2, direction_chart: Rect2) -> void:
	if _hover_x < speed_chart.position.x or _hover_x > speed_chart.end.x:
		return
	# The moment nearest to the mouse.
	var i: int = 0
	for j: int in times_s.size():
		if absf(_x_of(speed_chart, times_s[j]) - _hover_x) < absf(_x_of(speed_chart, times_s[i]) - _hover_x):
			i = j
	var x: float = _x_of(speed_chart, times_s[i])
	draw_line(Vector2(x, speed_chart.position.y), Vector2(x, direction_chart.end.y), MUTED, 1.0)
	var seconds: int = floori(times_s[i])
	var text: String = "%02d:%02d:%02d  %.1f kt from %03.0f°" % [
		floori(seconds / 3600.0), floori(seconds / 60.0) % 60, seconds % 60, knots[i], from_deg[i]]
	var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var at: Vector2 = Vector2(clampf(x - text_width / 2.0, PADDING_PX, size.x - text_width - PADDING_PX),
		speed_chart.position.y + FONT_SIZE + 2.0)
	draw_rect(Rect2(at - Vector2(4.0, FONT_SIZE), Vector2(text_width + 8.0, FONT_SIZE + 6.0)), BACKGROUND)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, TEXT)


## Where a moment is across a chart.
func _x_of(rect: Rect2, time_s: float) -> float:
	return rect.position.x + rect.size.x * (time_s - start_s) / (end_s - start_s)


## Directions without the jump from 359 to 0 degrees, so the line stays connected.
func _unwrapped(degrees: PackedFloat32Array) -> PackedFloat32Array:
	var result: PackedFloat32Array = degrees.duplicate()
	for i: int in range(1, result.size()):
		result[i] = result[i - 1] + wrapf(result[i] - result[i - 1], -180.0, 180.0)
	return result


func _scale_label(value: float, is_direction: bool) -> String:
	return "%03.0f" % fposmod(value, 360.0) if is_direction else "%.0f" % value


func _min(values: PackedFloat32Array) -> float:
	var result: float = INF
	for value: float in values:
		result = minf(result, value)
	return result


func _max(values: PackedFloat32Array) -> float:
	var result: float = -INF
	for value: float in values:
		result = maxf(result, value)
	return result
