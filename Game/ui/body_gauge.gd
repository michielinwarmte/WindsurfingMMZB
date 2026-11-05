class_name BodyGauge
extends Control
## The body on the mouse on the screen (package B, GP2; Max, 6 November 2026: "make a gauge for the
## mouse controls, I cannot see it on the board"). A pad with a dot where the mouse is: sideways the
## rail, fore and aft the back foot, the way the mouse moves (pull it toward you and the dot goes
## down: weight on the tail, the nose up). The half of the pad that gives more leeward rail on this
## tack is tinted. Beside the pad, what the body adds now in degrees, and under each the board's own
## heel and trim, so you see how much of it the board takes. The corner says whether the body works:
## only planing in the straps and not in a tack or a gybe (MouseBody); otherwise the dot dims. The
## HUD (hud.gd) shows it beside the push gauge for the player's board with the setting on.

const GAUGE_SIZE: Vector2 = Vector2(230.0, 134.0)
const PAD: Rect2 = Rect2(14.0, 36.0, 84.0, 84.0)
const DOT_RADIUS: float = 6.5
const RAIL_COLOR: Color = Color(1.0, 0.76, 0.22)
const TRIM_COLOR: Color = Color(0.3, 0.84, 0.95)
const WORKING_COLOR: Color = Color(0.35, 0.9, 0.45)
## In the straps from this stance on (Telemetry.stance: 0 out of them, 1 hooked in and hiked out).
const IN_THE_STRAPS: float = 0.5

var _body: MouseBody = null
var _status: String = ""
var _heel_deg: float = 0.0
var _trim_deg: float = 0.0
## What was drawn last: redrawn only when it changes.
var _drawn: Array = []
var _card: StyleBoxFlat = HudStyle.card()


func _init() -> void:
	custom_minimum_size = GAUGE_SIZE
	size = GAUGE_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## The player's body this frame (PlayerController.body) and the board's telemetry; a null body hides
## the gauge.
func set_body(body: MouseBody, t: Telemetry) -> void:
	_body = body
	visible = body != null
	if body == null:
		return
	_status = status_for(body, t)
	_heel_deg = absf(t.heel_deg) if t != null else 0.0
	_trim_deg = t.trim_deg if t != null else 0.0
	var now: Array = [body.side, body.back, snappedf(body.rail_deg, 0.1), snappedf(body.trim_deg, 0.1),
		body.rail_side(), _status, roundi(_heel_deg), snappedf(_trim_deg, 0.1)]
	if now != _drawn:
		_drawn = now
		queue_redraw()


## "works" when the body's numbers reach the board, otherwise why not: in a tack or a gybe, or not
## planing in the straps (the simulation only aims for them there).
static func status_for(body: MouseBody, t: Telemetry) -> String:
	if not body.working:
		return "in a turn"
	if t != null and (not t.is_planing or t.stance < IN_THE_STRAPS):
		return "plane in the straps"
	return "works"


func _draw() -> void:
	draw_style_box(_card, Rect2(Vector2.ZERO, size))
	if _body == null:
		return
	var works: bool = _status == "works"
	_text("BODY", HudStyle.sans(700), 13, Vector2(PAD.position.x, 22.0), 60.0, HORIZONTAL_ALIGNMENT_LEFT, HudStyle.DIM_COLOR)
	_text(_status, HudStyle.sans(600), 12, Vector2(70.0, 22.0), size.x - 84.0, HORIZONTAL_ALIGNMENT_RIGHT,
		WORKING_COLOR if works else HudStyle.DIM_COLOR)
	# The pad: the half that gives more rail tinted, a cross through the middle (the sailor's own
	# technique), a line from the middle to the dot.
	draw_rect(PAD, Color(1.0, 1.0, 1.0, 0.06))
	var rail_side: float = _body.rail_side()
	if rail_side != 0.0:
		var half: Rect2 = Rect2(PAD.position + Vector2(PAD.size.x * 0.5 if rail_side > 0.0 else 0.0, 0.0), Vector2(PAD.size.x * 0.5, PAD.size.y))
		var tint: Color = RAIL_COLOR
		tint.a = 0.16
		draw_rect(half, tint)
	draw_rect(PAD, Color(1.0, 1.0, 1.0, 0.3), false, 1.5)
	var middle: Vector2 = PAD.get_center()
	draw_line(Vector2(PAD.position.x, middle.y), Vector2(PAD.end.x, middle.y), Color(1.0, 1.0, 1.0, 0.18), 1.0)
	draw_line(Vector2(middle.x, PAD.position.y), Vector2(middle.x, PAD.end.y), Color(1.0, 1.0, 1.0, 0.18), 1.0)
	_text("nose up", HudStyle.sans(600), 10, Vector2(PAD.position.x, PAD.end.y - 4.0), PAD.size.x, HORIZONTAL_ALIGNMENT_CENTER, Color(1.0, 1.0, 1.0, 0.45))
	var reach: Vector2 = PAD.size * 0.5 - Vector2.ONE * (DOT_RADIUS + 2.0)
	var dot: Vector2 = middle + Vector2(_body.side, _body.back) * reach
	var shade: float = 1.0 if works else 0.4
	draw_line(middle, dot, Color(1.0, 1.0, 1.0, 0.45 * shade), 2.0, true)
	draw_circle(dot, DOT_RADIUS + 1.5, Color(0.0, 0.0, 0.0, 0.5 * shade))
	draw_circle(dot, DOT_RADIUS, Color(1.0, 1.0, 1.0, shade))
	# The numbers: what the body adds, and what the board does.
	var column: float = PAD.end.x + 12.0
	var width: float = size.x - column - 12.0
	var rail_colour: Color = RAIL_COLOR if works else HudStyle.DIM_COLOR
	var trim_colour: Color = TRIM_COLOR if works else HudStyle.DIM_COLOR
	_text("RAIL", HudStyle.sans(700), 11, Vector2(column, 50.0), width, HORIZONTAL_ALIGNMENT_LEFT, HudStyle.DIM_COLOR)
	_text("%+.1f°" % _body.rail_deg, HudStyle.sans(800), 20, Vector2(column, 71.0), width, HORIZONTAL_ALIGNMENT_LEFT, rail_colour)
	_text("heel %.0f°" % _heel_deg, HudStyle.sans(600), 11, Vector2(column, 71.0), width, HORIZONTAL_ALIGNMENT_RIGHT, HudStyle.DIM_COLOR)
	_text("BACK FOOT", HudStyle.sans(700), 11, Vector2(column, 94.0), width, HORIZONTAL_ALIGNMENT_LEFT, HudStyle.DIM_COLOR)
	_text("%+.1f°" % _body.trim_deg, HudStyle.sans(800), 20, Vector2(column, 115.0), width, HORIZONTAL_ALIGNMENT_LEFT, trim_colour)
	_text("trim %.1f°" % _trim_deg, HudStyle.sans(600), 11, Vector2(column, 115.0), width, HORIZONTAL_ALIGNMENT_RIGHT, HudStyle.DIM_COLOR)


## A line of text in a box `width` wide from `at` (its baseline), with the HUD's outline.
func _text(text: String, font: Font, font_size: int, at: Vector2, width: float, alignment: HorizontalAlignment, colour: Color) -> void:
	draw_string_outline(font, at, text, alignment, width, font_size, 4, Color(0.0, 0.0, 0.0, 0.5))
	draw_string(font, at, text, alignment, width, font_size, colour)
