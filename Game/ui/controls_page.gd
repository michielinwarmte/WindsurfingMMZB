class_name ControlsPage
extends MenuPage
## The key help as a table (the same keys as the HUD's help line and project.godot's
## input map), with the two control modes explained beside it (controls_page.tscn).

## The table: the keys of each row, and what they do.
const KEY_ROWS: Array[Array] = [
	[["W", "S"], "Sheet in / out (the arrows Up / Down too)"],
	[["A", "D"], "Turn left / right (advanced: move your weight)"],
	[["Q", "E"], "Rake the rig forward / back"],
	[["←", "→"], "Tilt the rig sideways (advanced)"],
	[["Space"], "Tack or gybe"],
	[["T"], "Auto-sheet on / off"],
	[["Tab"], "Beginner / advanced mode"],
	[["1", "2", "3", "4"], "Camera: follow, orbit, top-down, free"],
	[["Right mouse", "Wheel"], "Orbit camera: look around, zoom"],
	[["R"], "Back to the start (after a fall: climb on now)"],
	[["F1"], "Detail panel on / off"],
	[["Esc"], "Pause menu"],
]

@onready var _key_table: GridContainer = %KeyTable
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	_back_button.pressed.connect(close)
	for row: Array in KEY_ROWS:
		_add_row(row[0], row[1])


func first_focus() -> Control:
	return _back_button


## One row: the keys as key caps on the left, what they do on the right.
func _add_row(keys: Array, action: String) -> void:
	var caps: HBoxContainer = HBoxContainer.new()
	caps.alignment = BoxContainer.ALIGNMENT_END
	caps.add_theme_constant_override("separation", 6)
	for key: String in keys:
		var cap: Label = Label.new()
		cap.theme_type_variation = &"KeyLabel"
		cap.text = key
		caps.add_child(cap)
	_key_table.add_child(caps)
	var label: Label = Label.new()
	label.text = action
	label.add_theme_font_size_override("font_size", 18)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_key_table.add_child(label)
