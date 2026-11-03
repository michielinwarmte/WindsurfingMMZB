class_name PushGauge
extends Control
## The push slider on the screen (Max, 3 November 2026: "a nice push dial"): a half circle like a
## rev counter, 0 % on the left to 100 % on the right, coloured by Michiel's ladder
## (push_curve_config.gd) from blue while cruising through green for planing with little risk to
## red where a crash is likely, lit up to the level, with a marker at the level, the level in the
## middle and the ladder's words under it. The HUD (hud.gd) shows it at the bottom in the middle
## for the board on the screen, free sailing and racing alike, and hides it for a board without a
## slider (NaN: the autopilot, a skipper that leaves the slider alone).

## Michiel's ladder (31 October 2026): its levels and what each means.
const STEP_LEVELS: PackedFloat64Array = [0.0, 0.25, 0.5, 0.75, 0.85, 0.95, 1.0]
const STEP_WORDS: PackedStringArray = ["sail let fly", "slowly moving", "cruising", "planing, little risk",
	"more speed, a little risk", "very fast, control in mind", "most speed, crash likely"]
## The colour from each step up to the next.
const ZONE_COLORS: PackedColorArray = [
	Color(0.5, 0.58, 0.7),  # let fly to slowly moving
	Color(0.35, 0.62, 1.0),  # slowly moving to cruising
	Color(0.3, 0.84, 0.95),  # cruising to planing
	Color(0.35, 0.9, 0.45),  # planing with little risk
	Color(1.0, 0.76, 0.22),  # more speed, a little risk
	Color(1.0, 0.32, 0.24),  # very fast to a crash likely
]
const GAUGE_SIZE: Vector2 = Vector2(250.0, 134.0)
const RADIUS: float = 78.0
const THICKNESS: float = 13.0
## How fast the shown level follows the slider (per second): smooth, with no lag you can feel.
const FOLLOW_RATE: float = 14.0

## The slider's level, 0 to 1; NaN hides the gauge.
var level: float = NAN
## What is drawn: the level, eased.
var _shown: float = 0.0
var _card: StyleBoxFlat = HudStyle.card()


func _init() -> void:
	custom_minimum_size = GAUGE_SIZE
	size = GAUGE_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## The board's slider this frame (PlayerController.push_level); NaN hides the gauge.
func set_level(value: float) -> void:
	if is_nan(value):
		level = NAN
		visible = false
		return
	if not visible:
		_shown = clampf(value, 0.0, 1.0)
		queue_redraw()
	level = clampf(value, 0.0, 1.0)
	visible = true


func _process(delta: float) -> void:
	if is_nan(level) or _shown == level:
		return
	_shown = level + (_shown - level) * exp(-FOLLOW_RATE * delta)
	if absf(_shown - level) < 0.001:
		_shown = level
	queue_redraw()


## The ladder's step a level has reached (0 to 6).
static func step_index(value: float) -> int:
	var index: int = 0
	for i: int in STEP_LEVELS.size():
		if value >= STEP_LEVELS[i] - 0.001:
			index = i
	return index


## What the level means, in the ladder's words: "planing, little risk" from 75 % to 85 %.
static func word_for(value: float) -> String:
	return STEP_WORDS[step_index(value)]


## The zone's colour at a level (100 % is in the last zone).
static func colour_for(value: float) -> Color:
	return ZONE_COLORS[mini(step_index(value), ZONE_COLORS.size() - 1)]


## Where a level lies on the half circle: 0 % on the left (pi), 100 % on the right (2 pi), over the top.
static func angle_for(value: float) -> float:
	return PI + clampf(value, 0.0, 1.0) * PI


func _draw() -> void:
	draw_style_box(_card, Rect2(Vector2.ZERO, size))
	var centre: Vector2 = Vector2(size.x * 0.5, 20.0 + RADIUS)
	# The track: every zone dim, then lit up to the level.
	for i: int in ZONE_COLORS.size():
		var from: float = STEP_LEVELS[i]
		var to: float = STEP_LEVELS[i + 1]
		var dim: Color = ZONE_COLORS[i]
		dim.a = 0.22
		_arc(centre, from, to, dim)
		if _shown > from:
			_arc(centre, from, minf(_shown, to), ZONE_COLORS[i])
	# The ladder's steps as ticks outside the track.
	for step: float in STEP_LEVELS:
		var out: Vector2 = Vector2.from_angle(angle_for(step))
		draw_line(centre + out * (RADIUS + THICKNESS * 0.5 + 2.0), centre + out * (RADIUS + THICKNESS * 0.5 + 7.0), Color(1.0, 1.0, 1.0, 0.6), 2.0, true)
	# The marker across the track at the level, with a dot where it meets the inside.
	var at: Vector2 = Vector2.from_angle(angle_for(_shown))
	draw_line(centre + at * (RADIUS - THICKNESS * 0.5 - 9.0), centre + at * (RADIUS + THICKNESS * 0.5 + 3.0), Color(0.0, 0.0, 0.0, 0.5), 7.0, true)
	draw_line(centre + at * (RADIUS - THICKNESS * 0.5 - 8.0), centre + at * (RADIUS + THICKNESS * 0.5 + 2.0), Color.WHITE, 4.0, true)
	draw_circle(centre + at * (RADIUS - THICKNESS * 0.5 - 8.0), 3.5, Color.WHITE)
	# The words: PUSH, the level, and what it means.
	var colour: Color = colour_for(_shown)
	_text("PUSH", HudStyle.sans(700), 13, centre.y - 44.0, HudStyle.DIM_COLOR)
	_text("%d %%" % roundi(_shown * 100.0), HudStyle.sans(800), 34, centre.y - 6.0, HudStyle.TEXT_COLOR if _shown < 0.95 else colour)
	_text(word_for(_shown), HudStyle.sans(600), 15, centre.y + 26.0, colour)


func _arc(centre: Vector2, from: float, to: float, colour: Color) -> void:
	if to - from <= 0.0001:
		return
	var points: int = maxi(3, ceili((to - from) * 64.0))
	draw_arc(centre, RADIUS, angle_for(from), angle_for(to), points, colour, THICKNESS, true)


## A line of text centred across the gauge, its baseline at `baseline`.
func _text(text: String, font: Font, font_size: int, baseline: float, colour: Color) -> void:
	var at: Vector2 = Vector2(0.0, baseline)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, 4, Color(0.0, 0.0, 0.0, 0.5))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, colour)
