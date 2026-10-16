class_name WindLegend
extends Control
## The wind viewer's legend (MAP_SILVAPLANA_PLAN.md, W2), drawn like Windfinder's: a bar with the
## wind-speed colours of the water (WindColors), the knots written inside it at each colour stop,
## the strongest wind at the top. The stops are evenly spaced, as on Windfinder.

const HEADER_PX: float = 20.0
const FONT_SIZE: int = 13
const TEXT: Color = Color(1.0, 1.0, 1.0)
const HEADER_BACKGROUND: Color = Color(0.24, 0.55, 0.62, 0.9)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, HEADER_PX)), HEADER_BACKGROUND)
	draw_string(font, Vector2(0.0, HEADER_PX - 5.0), "kts", HORIZONTAL_ALIGNMENT_CENTER, size.x, FONT_SIZE, TEXT)
	var stops: int = WindColors.STOP_KNOTS.size()
	var bar: Rect2 = Rect2(Vector2(0.0, HEADER_PX), Vector2(size.x, size.y - HEADER_PX))
	var step_px: float = bar.size.y / stops
	# The bar, one line of pixels at a time: each stop's colour sits in the middle of its band,
	# and in between the knots (and so the colour) change evenly.
	for i: int in int(bar.size.y):
		var stop: float = clampf((bar.end.y - (bar.position.y + i + 0.5)) / step_px - 0.5, 0.0, stops - 1.0)
		var below: int = mini(int(stop), stops - 2)
		var knots: float = lerpf(WindColors.STOP_KNOTS[below], WindColors.STOP_KNOTS[below + 1], stop - below)
		draw_rect(Rect2(Vector2(0.0, bar.position.y + i), Vector2(bar.size.x, 1.0)), WindColors.color_for(knots))
	for i: int in stops:
		var centre_y: float = bar.end.y - (i + 0.5) * step_px
		draw_string(font, Vector2(0.0, centre_y + FONT_SIZE * 0.35), "%d" % WindColors.STOP_KNOTS[i],
			HORIZONTAL_ALIGNMENT_CENTER, size.x, FONT_SIZE, TEXT)
