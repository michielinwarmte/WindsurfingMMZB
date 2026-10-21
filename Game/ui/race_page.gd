class_name RacePage
extends MenuPage
## The Race page of the start menu (AI_FLEET_PLAN.md, F4: "the fleet picker in the menu (size,
## who)"; RACING_PLAN.md 9A's race_ui): the water and the course, how many boards, who sails them
## (the personas, the four characters, the night's brain), the countdown, the wind shadows and the
## rules. Start builds a RaceSetup and sends it with the water (start_race); the start menu starts
## the race the way its two race buttons did. The choices are kept for the session.

signal start_race(setup: RaceSetup, on_lake: bool)

const NAME_WIDTH: float = 200.0
const VALUE_WIDTH: float = 380.0
## How many AI boards the fleet row offers (the player's board comes on top).
const FLEET_SIZES: PackedInt32Array = [3, 7, 11, 15, 19, 23, 31]
const COUNTDOWNS_S: PackedFloat32Array = [30.0, 60.0, 180.0]
const COUNTDOWN_NAMES: PackedStringArray = ["30 s", "60 s", "3 min"]
## The templates on the open water are raced at this size (the class's full courses take 7 to 11
## minutes a lap for the scripted skippers; half is a race of a few minutes).
const TEMPLATE_PERCENT: int = 50

## Who sails the AI boards.
enum Who { PERSONAS, CHARACTERS, MIXED, BRAIN_AND_PERSONAS }
const WHO_NAMES: PackedStringArray = ["The twelve personas", "The four characters", "Personas and characters", "The trained brain and the personas"]

## The choices, kept for the session.
static var chosen_lake: bool = false
static var chosen_course: int = 0
static var chosen_fleet: int = 1
static var chosen_who: Who = Who.PERSONAS
static var chosen_countdown: int = 1
static var chosen_shadows: bool = true
static var chosen_rules: bool = true

@onready var _rows: GridContainer = %Rows
@onready var _start_button: Button = %StartButton
@onready var _back_button: Button = %BackButton
@onready var _who_card: Label = %WhoCard

var _water_list: OptionButton
var _course_list: OptionButton
var _who_list: OptionButton
## The course names behind the course list, for the water chosen.
var _course_names: PackedStringArray = PackedStringArray()


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_back_button.pressed.connect(close)
	_build_rows()


func first_focus() -> Control:
	return _start_button


## Opens the page on a water (the menu's two race buttons).
func open_on(lake: bool) -> void:
	chosen_lake = lake
	_water_list.select(1 if lake else 0)
	_fill_courses()
	open()


# ---------------------------------------------------------------- the rows

func _build_rows() -> void:
	_water_list = _add_list("Water", PackedStringArray(["Open water", "Lake Silvaplana"]), 1 if chosen_lake else 0,
		"The open water has T1 and every iQFOiL template; the lake its fitted courses.", _on_water_chosen)
	_course_list = _add_list("Course", PackedStringArray(["T1 training loop"]), 0, "", func(index: int) -> void: chosen_course = index)
	_fill_courses()
	var sizes: PackedStringArray = PackedStringArray()
	for size: int in FLEET_SIZES:
		sizes.append("%d boards and you" % size)
	_add_list("Fleet", sizes, chosen_fleet, "20 or fewer hold 60 fps on a laptop (tools/release.sh for a big fleet).",
		func(index: int) -> void: chosen_fleet = index)
	_who_list = _add_list("Who", WHO_NAMES, chosen_who, "", _on_who_chosen)
	_add_list("Countdown", COUNTDOWN_NAMES, chosen_countdown, "The boards gather from where they sail free.", func(index: int) -> void: chosen_countdown = index)
	_add_switch("Wind shadows", chosen_shadows, "A sail leaves slower air behind it: a pack slows itself.", func(on: bool) -> void: chosen_shadows = on)
	_add_switch("The rules", chosen_rules, "Port keeps clear of starboard, and more; a penalty is a turn or 20 s.", func(on: bool) -> void: chosen_rules = on)
	_on_who_chosen(chosen_who)


## The course list for the water chosen: T1 and the templates at half size on the open water; T2
## and the course maker's saved courses on the lake.
func _fill_courses() -> void:
	_course_names.clear()
	var titles: PackedStringArray = PackedStringArray()
	if chosen_lake:
		_course_names.append(RaceCourses.T2_NAME)
		titles.append("T2 sprint slalom")
		for saved: String in RaceCourses.saved_names():
			if saved != RaceCourses.T2_NAME:
				_course_names.append(saved)
				titles.append(saved)
	else:
		_course_names.append(RaceCourses.T1_NAME)
		titles.append("T1 training loop")
		for id: String in CourseTemplates.ALL:
			_course_names.append("template:%s@%d" % [id, TEMPLATE_PERCENT])
			titles.append("%s at %d %%" % [CourseTemplates.title(id), TEMPLATE_PERCENT])
	_course_list.clear()
	for title: String in titles:
		_course_list.add_item(title)
	chosen_course = clampi(chosen_course, 0, titles.size() - 1)
	_course_list.select(chosen_course)


func _on_water_chosen(index: int) -> void:
	chosen_lake = index == 1
	chosen_course = 0
	_fill_courses()


func _on_who_chosen(index: int) -> void:
	chosen_who = index as Who
	match chosen_who:
		Who.PERSONAS:
			_who_card.text = _persona_cards()
		Who.CHARACTERS:
			_who_card.text = "The all-rounder, the cautious one, the gambler and the rookie: the four scripted characters of Phase 9."
		Who.MIXED:
			_who_card.text = "The personas and the characters, turn and turn about."
		Who.BRAIN_AND_PERSONAS:
			var brain: String = latest_brain()
			_who_card.text = ("The trained head %s on one board, the personas on the rest." % brain) if not brain.is_empty() else "No trained brain yet (tools/train.sh makes one): the personas sail."


## The personas' cards, one line each.
static func _persona_cards() -> String:
	var lines: PackedStringArray = PackedStringArray()
	for persona_name: String in Skippers.persona_names():
		var persona: Persona = Skippers.load_persona(persona_name)
		if persona != null:
			lines.append(persona.card())
	return "\n".join(lines)


## The latest stage's best brain in Game/race/brains (s6_best before s5_best, ...); "" for none.
static func latest_brain() -> String:
	for stage: int in range(6, 0, -1):
		var name: String = "s%d_best" % stage
		if ResourceLoader.exists(Skippers.BRAINS_FOLDER.path_join(name + ".json")) or FileAccess.file_exists(Skippers.BRAINS_FOLDER.path_join(name + ".json")):
			return name
	return ""


# ---------------------------------------------------------------- the start

## The skippers for the choices: the names dealt round the fleet in order.
static func fleet_names(who: Who, count: int) -> PackedStringArray:
	var pool: PackedStringArray = PackedStringArray()
	var personas: PackedStringArray = PackedStringArray()
	for persona_name: String in Skippers.persona_names():
		personas.append("persona:" + persona_name)
	var characters: PackedStringArray = Skippers.names()
	match who:
		Who.PERSONAS:
			pool = personas
		Who.CHARACTERS:
			pool = characters
		Who.MIXED:
			for i: int in maxi(personas.size(), characters.size()):
				if i < personas.size():
					pool.append(personas[i])
				if i < characters.size():
					pool.append(characters[i])
		Who.BRAIN_AND_PERSONAS:
			var brain: String = latest_brain()
			if not brain.is_empty():
				pool.append("brain:" + brain)
			pool.append_array(personas)
	if pool.is_empty():
		pool = characters
	var names: PackedStringArray = PackedStringArray()
	for i: int in count:
		names.append(pool[i % pool.size()])
	return names


func _on_start_pressed() -> void:
	var count: int = FLEET_SIZES[clampi(chosen_fleet, 0, FLEET_SIZES.size() - 1)]
	var course: String = _course_names[clampi(chosen_course, 0, _course_names.size() - 1)]
	var setup: RaceSetup = RaceSetup.race(course, fleet_names(chosen_who, count), 1, COUNTDOWNS_S[chosen_countdown])
	setup.shadows = chosen_shadows
	setup.rules = chosen_rules
	hide()
	start_race.emit(setup, chosen_lake)


# ---------------------------------------------------------------- the rows' making (as the settings page)

func _add_list(title: String, items: PackedStringArray, selected: int, hint: String, store: Callable) -> OptionButton:
	_add_name(title)
	var list: OptionButton = OptionButton.new()
	for item: String in items:
		list.add_item(item)
	list.select(clampi(selected, 0, maxi(items.size() - 1, 0)))
	list.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	list.custom_minimum_size = Vector2(300.0, 0.0)
	_rows.add_child(list)
	_add_value(hint)
	list.item_selected.connect(func(index: int) -> void: store.call(index))
	return list


func _add_switch(title: String, on: bool, hint: String, store: Callable) -> CheckButton:
	_add_name(title)
	var switch: CheckButton = CheckButton.new()
	switch.button_pressed = on
	switch.text = "On" if on else "Off"
	switch.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_rows.add_child(switch)
	_add_value(hint)
	switch.toggled.connect(func(now_on: bool) -> void:
		store.call(now_on)
		switch.text = "On" if now_on else "Off")
	return switch


func _add_name(title: String) -> void:
	var label: Label = Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(NAME_WIDTH, 0.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rows.add_child(label)


func _add_value(text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.theme_type_variation = &"HintLabel"
	label.custom_minimum_size = Vector2(VALUE_WIDTH, 0.0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rows.add_child(label)
