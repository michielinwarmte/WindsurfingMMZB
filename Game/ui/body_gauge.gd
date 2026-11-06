class_name BodyGauge
extends Control
## The body on the mouse on the screen (package B, GP2; Max, 6 November 2026: "make a gauge for the
## mouse controls, I cannot see it on the board"; the feet's press of the same day:
## Documentation/reports/gameplay/gp2_feet_pressure.md). A pad with a dot where the mouse is:
## sideways the toes against the heels, fore and aft the front foot against the back foot, the way
## the mouse moves (pull it toward you and the dot goes down: the weight onto the back foot). The
## half of the pad where the toes press (the leeward rail down) on this tack is tinted.
##
## Beside the pad, how the feet press now, whoever asks (the sailor's own technique in the middle,
## the mouse as far as it presses): the toes or the heels as a share of the feet's roll moment, with a
## bar from the middle toward the toes (on the pad's tinted side) or the heels, and the board's heel
## to leeward; and the share of the weight on the back foot, with a bar from the front strap (left) to
## the back strap (right) and the board's trim. The corner says whether the mouse works: only planing in the straps and not in a tack or a
## gybe; otherwise why not, and the dot dims. The HUD (hud.gd) shows it beside the push gauge for
## the player's board with the setting on.

const GAUGE_SIZE: Vector2 = Vector2(270.0, 134.0)
const PAD: Rect2 = Rect2(14.0, 36.0, 84.0, 84.0)
const DOT_RADIUS: float = 6.5
const ROLL_COLOR: Color = Color(1.0, 0.76, 0.22)
const PITCH_COLOR: Color = Color(0.3, 0.84, 0.95)
const WORKING_COLOR: Color = Color(0.35, 0.9, 0.45)
## The body works from this share of its press reaching the board (Telemetry.feet_press_reach: 1
## planing in the straps).
const PRESS_REACHES: float = 0.5
## The bars under the numbers.
const BAR_HEIGHT: float = 5.0

var _body: MouseBody = null
var _status: String = ""
var _heel_deg: float = 0.0
var _trim_deg: float = 0.0
## How the feet press now (Telemetry.toes_share, back_foot_share).
var _toes: float = 0.0
var _back_foot: float = 0.5
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
	_heel_deg = leeward_heel_deg(t, body.last_tack)
	_trim_deg = t.trim_deg if t != null else 0.0
	_toes = t.toes_share if t != null else 0.0
	_back_foot = t.back_foot_share if t != null else 0.5
	var now: Array = [snappedf(body.side, 0.01), snappedf(body.back, 0.01), body.rail_side(), _status, roundi(_heel_deg),
		snappedf(_trim_deg, 0.1), roundi(_toes * 100.0), roundi(_back_foot * 100.0)]
	if now != _drawn:
		_drawn = now
		queue_redraw()


## "works" when the body's press reaches the board, otherwise why not: in a tack or a gybe, or not
## planing in the straps (the simulation presses only there: Telemetry.feet_press_reach).
static func status_for(body: MouseBody, t: Telemetry) -> String:
	if not body.working:
		return "in a turn"
	if t != null and t.feet_press_reach < PRESS_REACHES:
		return "plane in the straps"
	return "works"


## The board's heel to leeward on this tack (degrees, + the leeward rail down; starboard tack, +1,
## has the leeward rail to port, a negative heel). Before the first tack is known, the heel's size.
static func leeward_heel_deg(t: Telemetry, tack: float) -> float:
	if t == null:
		return 0.0
	return -t.heel_deg * tack if tack != 0.0 else absf(t.heel_deg)


## The words for the feet's roll press: the toes (the leeward rail down) or the heels.
static func toes_word(toes: float) -> String:
	return "TOES" if toes >= 0.0 else "HEELS"


func _draw() -> void:
	draw_style_box(_card, Rect2(Vector2.ZERO, size))
	if _body == null:
		return
	var works: bool = _status == "works"
	_text("BODY", HudStyle.sans(700), 13, Vector2(PAD.position.x, 22.0), 60.0, HORIZONTAL_ALIGNMENT_LEFT, HudStyle.DIM_COLOR)
	_text(_status, HudStyle.sans(600), 12, Vector2(70.0, 22.0), size.x - 84.0, HORIZONTAL_ALIGNMENT_RIGHT,
		WORKING_COLOR if works else HudStyle.DIM_COLOR)
	_draw_pad(works)
	# The feet: how they press now, and what the board does.
	var column: float = PAD.end.x + 14.0
	var width: float = size.x - column - 12.0
	var roll_colour: Color = ROLL_COLOR if works else HudStyle.DIM_COLOR
	var pitch_colour: Color = PITCH_COLOR if works else HudStyle.DIM_COLOR
	_text(toes_word(_toes), HudStyle.sans(700), 11, Vector2(column, 48.0), width, HORIZONTAL_ALIGNMENT_LEFT, HudStyle.DIM_COLOR)
	_text("%.0f %%" % (absf(_toes) * 100.0), HudStyle.sans(800), 18, Vector2(column, 68.0), width, HORIZONTAL_ALIGNMENT_LEFT, roll_colour)
	_text("heel %.0f°" % _heel_deg, HudStyle.sans(600), 11, Vector2(column, 68.0), width, HORIZONTAL_ALIGNMENT_RIGHT, HudStyle.DIM_COLOR)
	# The bar runs the way the pad does: the toes on the tinted side (right before the tack is known).
	var toes_side: float = _body.rail_side() if _body.rail_side() != 0.0 else 1.0
	_draw_bar(Rect2(column, 74.0, width, BAR_HEIGHT), _toes * toes_side, true, roll_colour)
	_text("BACK FOOT", HudStyle.sans(700), 11, Vector2(column, 94.0), width, HORIZONTAL_ALIGNMENT_LEFT, HudStyle.DIM_COLOR)
	_text("%.0f %%" % (_back_foot * 100.0), HudStyle.sans(800), 18, Vector2(column, 114.0), width, HORIZONTAL_ALIGNMENT_LEFT, pitch_colour)
	_text("trim %.1f°" % _trim_deg, HudStyle.sans(600), 11, Vector2(column, 114.0), width, HORIZONTAL_ALIGNMENT_RIGHT, HudStyle.DIM_COLOR)
	_draw_bar(Rect2(column, 120.0, width, BAR_HEIGHT), _back_foot, false, pitch_colour)


## The pad: the toes' half tinted, a cross through the middle (the sailor's own technique), the
## words at its edges, a line from the middle to the dot.
func _draw_pad(works: bool) -> void:
	draw_rect(PAD, Color(1.0, 1.0, 1.0, 0.06))
	var rail_side: float = _body.rail_side()
	if rail_side != 0.0:
		var half: Rect2 = Rect2(PAD.position + Vector2(PAD.size.x * 0.5 if rail_side > 0.0 else 0.0, 0.0), Vector2(PAD.size.x * 0.5, PAD.size.y))
		var tint: Color = ROLL_COLOR
		tint.a = 0.16
		draw_rect(half, tint)
	draw_rect(PAD, Color(1.0, 1.0, 1.0, 0.3), false, 1.5)
	var middle: Vector2 = PAD.get_center()
	draw_line(Vector2(PAD.position.x, middle.y), Vector2(PAD.end.x, middle.y), Color(1.0, 1.0, 1.0, 0.18), 1.0)
	draw_line(Vector2(middle.x, PAD.position.y), Vector2(middle.x, PAD.end.y), Color(1.0, 1.0, 1.0, 0.18), 1.0)
	var faint: Color = Color(1.0, 1.0, 1.0, 0.45)
	_text("back foot", HudStyle.sans(600), 10, Vector2(PAD.position.x, PAD.end.y - 4.0), PAD.size.x, HORIZONTAL_ALIGNMENT_CENTER, faint)
	_text("front foot", HudStyle.sans(600), 10, Vector2(PAD.position.x, PAD.position.y + 12.0), PAD.size.x, HORIZONTAL_ALIGNMENT_CENTER, faint)
	if rail_side != 0.0:
		# "toes" on the tinted half, at the side's edge.
		var align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_RIGHT if rail_side > 0.0 else HORIZONTAL_ALIGNMENT_LEFT
		_text("toes", HudStyle.sans(600), 10, Vector2(PAD.position.x + 3.0, middle.y - 4.0), PAD.size.x - 6.0, align, faint)
	var reach: Vector2 = PAD.size * 0.5 - Vector2.ONE * (DOT_RADIUS + 2.0)
	var dot: Vector2 = middle + Vector2(_body.side, _body.back) * reach
	var shade: float = 1.0 if works else 0.4
	draw_line(middle, dot, Color(1.0, 1.0, 1.0, 0.45 * shade), 2.0, true)
	draw_circle(dot, DOT_RADIUS + 1.5, Color(0.0, 0.0, 0.0, 0.5 * shade))
	draw_circle(dot, DOT_RADIUS, Color(1.0, 1.0, 1.0, shade))


## A thin bar. centred: -1 (the left end) to +1 (the right end), filled from the middle; otherwise
## 0 (the left end) to 1 (the right end), filled from the left, with a tick at the middle.
func _draw_bar(rect: Rect2, value: float, centred: bool, colour: Color) -> void:
	draw_rect(rect, Color(1.0, 1.0, 1.0, 0.12))
	var mid_x: float = rect.position.x + rect.size.x * 0.5
	var fill: Rect2
	if centred:
		var v: float = clampf(value, -1.0, 1.0)
		var w: float = absf(v) * rect.size.x * 0.5
		fill = Rect2(mid_x if v >= 0.0 else mid_x - w, rect.position.y, w, rect.size.y)
	else:
		fill = Rect2(rect.position, Vector2(clampf(value, 0.0, 1.0) * rect.size.x, rect.size.y))
	draw_rect(fill, colour)
	draw_line(Vector2(mid_x, rect.position.y - 2.0), Vector2(mid_x, rect.end.y + 2.0), Color(1.0, 1.0, 1.0, 0.5), 1.0)


## A line of text in a box `width` wide from `at` (its baseline), with the HUD's outline.
func _text(text: String, font: Font, font_size: int, at: Vector2, width: float, alignment: HorizontalAlignment, colour: Color) -> void:
	draw_string_outline(font, at, text, alignment, width, font_size, 4, Color(0.0, 0.0, 0.0, 0.5))
	draw_string(font, at, text, alignment, width, font_size, colour)
