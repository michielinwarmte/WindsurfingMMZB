class_name CommentarySubtitles
extends PanelContainer
## The commentator's line at the bottom of the screen, like TV subtitles (Documentation/reports/
## broadcast/PLAN.md, P6: subtitles first, the voice later). White words with a dark outline on a dark,
## half see-through band, so they read over the bright water and the dark land alike.
##
## Where it sits (any window size; it is a part of the HUD's screen, laid out for a window 720 pixels
## high and drawn as much bigger as the window is taller, hud.gd): centred along the bottom, above the
## keys, between the race's speed card on the left and the small map on the right, and above the push
## and body gauges when those are shown (the full screen). Its words wrap onto a second line rather than
## reach under a card. It never covers the race card, the standings or the results, which all end above
## the gauges' row.

## The words' size (in the 720-high layout's pixels) and the band's look.
const FONT_SIZE: int = 21
const BAND_COLOR: Color = Color(0.0, 0.0, 0.0, 0.55)
const GAP: float = 14.0
## The widest the band gets, as a share of the screen's width (TV subtitles keep to the middle).
const MOST_WIDTH_SHARE: float = 0.62
## The room kept for the speed card at the bottom left when the HUD cannot say (pixels).
const LEFT_CARD_ROOM: float = 260.0

var hud: Hud = null
var _words: Label
## How long the line shown stays up, seconds of the caller's clock (show_line(), step()).
var _left_s: float = 0.0


func _init() -> void:
	name = "CommentarySubtitles"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var band: StyleBoxFlat = StyleBoxFlat.new()
	band.bg_color = BAND_COLOR
	band.set_corner_radius_all(6)
	band.content_margin_left = 16.0
	band.content_margin_right = 16.0
	band.content_margin_top = 6.0
	band.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", band)
	_words = HudStyle.label(HudStyle.sans(600), FONT_SIZE)
	_words.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_words.add_theme_constant_override("outline_size", 6)
	_words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_words)
	visible = false


## Onto the HUD's screen (with its parts, scaled with them).
func put_on(hud_layer: Hud) -> void:
	hud = hud_layer
	hud.add_part(self)
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN


## A new line: its words, shown for `seconds` (the caller adds the reading time).
func show_line(text: String, seconds: float) -> void:
	_words.text = text
	_left_s = seconds
	_lay_out()
	visible = true


## The line goes (cut short, the commentary off, a new race).
func clear() -> void:
	_left_s = 0.0
	_words.text = ""
	visible = false


## The words shown now ("" when none).
func text() -> String:
	return _words.text if visible else ""


## Every frame, with the caller's seconds: the line goes when its time is up; the band follows the
## window and the cards.
func step(dt: float) -> void:
	if not visible:
		return
	_left_s -= dt
	if _left_s <= 0.0:
		clear()
		return
	_lay_out()


## As wide as the words need, at most as wide as the room between the cards at the bottom; centred, its
## bottom on the cards' bottom line (or on the gauges' top when they are shown).
func _lay_out() -> void:
	var room: Vector2 = room_for_band()
	var font: Font = _words.get_theme_font("font")
	var words_wide: float = font.get_string_size(_words.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x if font != null else room.x
	var band: StyleBox = get_theme_stylebox("panel")
	var inner: float = room.x - band.get_margin(SIDE_LEFT) - band.get_margin(SIDE_RIGHT)
	_words.custom_minimum_size.x = minf(words_wide + 2.0, inner)
	reset_size()
	var width: float = get_combined_minimum_size().x
	offset_left = -width * 0.5
	offset_right = width * 0.5
	offset_top = -room.y
	offset_bottom = -room.y


## The room the band may take: its widest (x) and how far above the screen's bottom edge its bottom
## sits (y), in the HUD's pixels.
func room_for_band() -> Vector2:
	if hud == null:
		var own: Vector2 = get_parent_area_size()
		return Vector2(own.x * MOST_WIDTH_SHARE, Hud.BOTTOM_INSET)
	var screen: Vector2 = hud.screen_size()
	var side: float = maxf(Hud.MARGIN + LEFT_CARD_ROOM, Hud.MARGIN + hud.mini_map_width()) + GAP
	var widest: float = minf(screen.x - 2.0 * side, screen.x * MOST_WIDTH_SHARE)
	var bottom: float = Hud.BOTTOM_INSET
	if hud.gauges_shown():
		bottom = screen.y - hud.bottom_middle_top() + 8.0
	return Vector2(maxf(widest, 240.0), bottom)
