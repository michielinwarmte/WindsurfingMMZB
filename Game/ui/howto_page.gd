class_name HowToPage
extends MenuPage
## A few tips for a first sail, in two columns (howto_page.tscn). Each tip is a short title
## and a sentence or two; they follow the order a beginner meets things on the water.

const TIPS: Array[Array] = [
	["Read the wind", "The wind rose at the top right shows it: the blue arrow blows the way the wind blows, the orange triangle is your board."],
	["Start across the wind", "You start on a beam reach, the wind from the side. Sheet in with W until the sail fills; ease out with S if it pulls you over."],
	["Steer", "Turning toward the wind (heading up) slows you down, and straight into it you stop. Turning away from it (bearing away) speeds you up."],
	["Get planing", "In a good breeze, bear away a little and keep the sail in: the board lifts onto the water and the strip at the top says planing. The sailor hangs in the harness by themselves."],
	["Turn around", "Space tacks when you sail upwind of a beam reach and gybes when you sail downwind of it."],
	["Fell in?", "The sailor climbs back on by themselves after a few seconds (a waterstart); R does it at once."],
	["Ready for more", "Tab switches to advanced mode: steer with the rig and your weight, like on real water. The Controls page has every key."],
	["Change the day", "Settings: more or less wind, gusts and shifts, and the waves from flat water to strong chop."],
]

@onready var _tips: GridContainer = %Tips
@onready var _back_button: Button = %BackButton


func _ready() -> void:
	_back_button.pressed.connect(close)
	for tip: Array in TIPS:
		_add_tip(tip[0], tip[1])


func first_focus() -> Control:
	return _back_button


func _add_tip(title: String, text: String) -> void:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.custom_minimum_size = Vector2(480.0, 0.0)
	var heading: Label = Label.new()
	heading.theme_type_variation = &"SectionLabel"
	heading.text = title
	box.add_child(heading)
	var body: Label = Label.new()
	body.text = text
	body.add_theme_font_size_override("font_size", 17)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(480.0, 0.0)
	box.add_child(body)
	_tips.add_child(box)
