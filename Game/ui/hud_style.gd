class_name HudStyle
extends RefCounted
## The look the sailing HUD's newer parts share (the race block, the push gauge): the menus' deep
## sea-blue cards with rounded corners and their sans font (ui/theme.tres), light text with a dark
## outline so it reads over the bright sky and the water, and the clocks' digits in a monospace
## font so they do not jump while they count.

const CARD_COLOR: Color = Color(0.07, 0.15, 0.25, 0.78)
const CARD_BORDER: Color = Color(1.0, 1.0, 1.0, 0.1)
const TEXT_COLOR: Color = Color(0.95, 0.97, 1.0)
const DIM_COLOR: Color = Color(0.7, 0.79, 0.88)
## The wind arrow's sky blue and the board triangle's orange (hud.gd's WindRose), as in the menus.
const ACCENT_COLOR: Color = Color(0.5, 0.85, 1.0)
const HIGHLIGHT_COLOR: Color = Color(1.0, 0.6, 0.1)
const SANS_NAMES: PackedStringArray = ["Fira Sans", "Cantarell", "Noto Sans", "Ubuntu", "Segoe UI", "Helvetica Neue", "DejaVu Sans", "sans-serif"]
const MONO_NAMES: PackedStringArray = ["Fira Mono", "DejaVu Sans Mono", "Liberation Mono", "Consolas", "monospace"]

static var _fonts: Dictionary[String, Font] = {}


## The menus' sans font at this weight (500 body, 700 bold, 800 title).
static func sans(weight: int = 500) -> Font:
	return _font("sans%d" % weight, SANS_NAMES, weight)


## A monospace font for numbers that count (the clocks, the gaps).
static func mono(weight: int = 700) -> Font:
	return _font("mono%d" % weight, MONO_NAMES, weight)


static func _font(key: String, names: PackedStringArray, weight: int) -> Font:
	if not _fonts.has(key):
		var font: SystemFont = SystemFont.new()
		font.font_names = names
		font.font_weight = weight
		_fonts[key] = font
	return _fonts[key]


## A card: the menus' panel, a little see-through so the water shows.
static func card(margin: float = 12.0) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = CARD_COLOR
	style.border_color = CARD_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = margin + 2.0
	style.content_margin_right = margin + 2.0
	style.content_margin_top = margin - 2.0
	style.content_margin_bottom = margin - 2.0
	return style


## A label in this look, with a dark outline.
static func label(font: Font, size: int, colour: Color = TEXT_COLOR) -> Label:
	var made: Label = Label.new()
	made.add_theme_font_override("font", font)
	made.add_theme_font_size_override("font_size", size)
	made.add_theme_color_override("font_color", colour)
	made.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.55))
	made.add_theme_constant_override("outline_size", 3)
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return made
