class_name RaceNotice
extends Label
## The race director's notice for a player not in the race under way (RACE_DIRECTOR.md R2, R4):
## that they race from the next start, when the next countdown begins and a note from the director.
## Centred near the top (the race card, which carries these lines for a player in the race, is
## hidden then); empty text hides it. RaceMirror adds it on a guest's PC.

const FONT_SIZE: int = 22
## From the top of the screen, pixels (the race's clock and countdown are above it).
const FROM_TOP_PX: float = 150.0


func _ready() -> void:
	name = "RaceNotice"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", FONT_SIZE)
	add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	add_theme_constant_override("outline_size", 6)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	offset_left = -420.0
	offset_right = 420.0
	offset_top = FROM_TOP_PX
	offset_bottom = FROM_TOP_PX + 90.0
	visible = false


## Shows the text (hides the line when it is empty); unchanged text costs nothing.
func show_text(text: String) -> void:
	if text != self.text:
		self.text = text
	visible = text != ""
