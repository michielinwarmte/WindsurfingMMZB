class_name Hud
extends CanvasLayer
## The telemetry on the screen, spread over the whole window (Max, 6 November 2026: "in the ui
## everything is in the left top corner, make it more over the whole screen"):
## - bottom left: a card with the wind, the tack and the state, the mode and the camera (free
##   sailing; a race shows its own card there, RaceHud);
## - bottom middle: the push gauge, and the body gauge beside it with package B on;
## - bottom right: on a map (sail_silvaplana.tscn) a small map of the lake, with a race course
##   (show_course()) the course on it and its name above it (on the open water a small map of the
##   course's water), as big as the setting "Mini-map size" says;
## - along the bottom edge: the keys, each key in a small chip;
## - top right: the compass rose (the heading, the wind and a race's next mark);
## - top left: the detail panel with the forces and the controls (F1), for the team; a race
##   director's panel (LAN) also comes up on the left;
## - top middle: a message for the shore ("Aground ..."); in a race, RaceHud's race card.
## The race's own parts (RaceHud: the race card at the top in the middle, the standings down the
## right side under the compass) are added to this layer by RaceRunner.
##
## Any window size: every part is anchored to its corner or edge, laid out for a window 720 pixels
## high, and the project's stretch (project.godot: "canvas_items", "expand") draws the whole layer
## as much bigger as the window is taller, sharp at the window's own resolution (no Control.scale);
## a wider window gives the parts more room across.
## On top of that, Settings > Graphics > UI scale (SettingsValues.ui_scale, 75 % to 150 %) makes the
## whole in-game screen bigger or smaller (Max, 6 November 2026: "a resolution based ui?"): every part
## sits in one control (_screen) as big as the window divided by the scale, and the layer draws it
## that much bigger, so the parts keep their places at the window's edges and corners. Parts from
## elsewhere (the race's RaceHud and RaceNotice) come in through add_part().
##
## Everything is read from the simulation's Telemetry; nothing is computed here. The pause menu
## (pause_menu.gd) is separate; the sailing scene (main.gd) hides this whole layer behind the start
## menu.

## The room kept free along the window's edges, pixels (of the 720-high layout).
const MARGIN: float = 16.0
## The key hints' strip along the bottom edge: its height, and how far up from the edge it sits.
const HINTS_HEIGHT: float = 26.0
const HINTS_BOTTOM: float = 6.0
## The bottom of the panels along the bottom (the cards, the gauges, the small map): above the keys.
const BOTTOM_INSET: float = HINTS_BOTTOM + HINTS_HEIGHT + 8.0
## The compass rose at the top right: its size and its gap to the window's top and right edge.
const ROSE_SIZE: float = 130.0
const ROSE_GAP: float = 20.0
## Where the space under the compass starts (RaceHud's standings), from the top.
const RIGHT_COLUMN_TOP: float = ROSE_GAP + ROSE_SIZE + 10.0
## The smallest screen, in its own pixels, the HUD's parts fit on side by side (the bottom row: the
## speed card, the push and body gauges, the mini-map; the right column: the compass, four lines of
## standings, the mini-map): a UI scale above 100 % stops where the screen would get smaller.
const SMALLEST_SCREEN: Vector2 = Vector2(1180.0, 560.0)
## The keys' text size: the most, and the least when a narrow window needs smaller (fit_hints()).
const HINTS_FONT_SIZE: int = 15
const HINTS_MIN_FONT_SIZE: int = 10
## The message in the middle (set_message()): from the top while sailing free, and in a race, under
## the race card, the countdown and the race's warnings.
const MESSAGE_TOP: float = 200.0
const MESSAGE_TOP_IN_RACE: float = 380.0

## The keys while sailing free, racing, spectating, and as the guest of a network game: each one the
## key, and what it does.
const FREE_KEYS: Array[Array] = [
	["W S", "push"],
	["↑ ↓", "sheet"],
	["A D", "turn / weight"],
	["Q E", "rake"],
	["← →", "rig tilt"],
	["Space + A/D", "tack toward the wind, gybe away"],
	["T", "auto-sheet"],
	["Tab", "mode"],
	["1-4", "camera"],
	["R", "reset"],
	["Esc", "menu"],
	["F1", "panel"],
]
const RACE_KEYS: Array[Array] = [
	["W S", "push"],
	["A D", "turn"],
	["↑ ↓", "sheet"],
	["Space + A/D", "tack toward the wind, gybe away"],
	["1-4", "camera"],
	["R", "race again"],
	["M", "race director"],
	["Esc", "menu"],
	["F1", "telemetry"],
]
## The "flip now" chip, first along the bottom while a second Space puts the rig across in a tack or
## a gybe (the interactive manoeuvres, Max, 6 November 2026).
const FLIP_KEY: Array = ["Space", "flip now"]
const SPECTATE_KEYS: Array[Array] = [
	["Tab", "next board"],
	["Shift+Tab", "previous"],
	["L", "follow the leader"],
	["1-4", "camera"],
	["R", "race again"],
	["Esc", "menu"],
	["F1", "telemetry"],
]
const GUEST_KEYS: Array[Array] = [
	["W S", "push"],
	["A D", "turn"],
	["↑ ↓", "sheet"],
	["Space + A/D", "tack toward the wind, gybe away"],
	["1-4", "camera"],
	["R", "after a fall: back on the board"],
	["Esc", "menu"],
	["F1", "telemetry"],
]

var detail_visible: bool = true
## The sailor's view (UI1, GD6): the card without the speed and the wind at the sail, so the
## player reads the water, the board and the sail instead; F1's panel keeps every number.
var sailor_view: bool = true
## The free-sailing card at the bottom left: a big line, a line, a small line (and a fourth without
## the sailor's view).
var _status_card: PanelContainer
var _status_lines: Array[Label] = []
var _panel: PanelContainer
var _detail: Label
## What came before the last fall, frozen for the detail panel (GP0's playtest).
var _fall_watch: FallWatch = FallWatch.new()
## The keys along the bottom edge, and the keys shown (FREE_KEYS, ... with the mouse's keys added).
var _hints: HBoxContainer
var _keys: Array[Array] = FREE_KEYS
## The keys of the moment (FREE_KEYS, RACE_KEYS, ...) before the mouse's are added, and the push on
## the mouse they were shown with (MouseBody.PushOnMouse; -1: no body on the mouse).
var _base_keys: Array[Array] = FREE_KEYS
var _mouse_push: int = -1
## Whether the "flip now" hint is shown (the window of a tack or gybe where a second Space puts the
## rig across: PlayerController.flip_cue_open()).
var _flip_hint: bool = false
var _rose: WindRose
## The gauges in a row at the bottom in the middle: the push, and the body beside it.
var _gauges: HBoxContainer
var _push_gauge: PushGauge
var _body_gauge: BodyGauge
## Only in a map scene (show_mini_map), or with a race course (show_course).
var _mini_map: MiniMap = null
## Whether the small map shows the course's own water (the open water, no lake's map).
var _mini_map_frames_course: bool = false
var _message: Label
## The race course's name, above the small map (show_course).
var _course_line: Label = null
## On a map with its own day of wind: the time of day, on the card ("" = none).
var clock_text: String = ""
## A race is on: the free-sailing card is hidden and the keys are the racing keys (set_race_mode).
var _race_mode: bool = false
## Whether the card shows a fall now (its line in orange).
var _fall_shown: bool = false
## The UI scale in use (Settings > Graphics), and the control every part of the screen sits in.
var ui_scale: float = 1.0
var _screen: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_screen = Control.new()
	_screen.name = "Screen"
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_screen)
	_apply_ui_scale()
	_build_status_card()

	# The detail panel (F1) at the top left, in the old monospace look: it is the team's. A little
	# smaller than it was (15), since it now grows with the window like the rest.
	var mono: SystemFont = SystemFont.new()
	mono.font_names = PackedStringArray(["DejaVu Sans Mono", "Liberation Mono", "monospace"])
	_panel = PanelContainer.new()
	_panel.position = Vector2(MARGIN, 12.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(_panel)
	_detail = _label(mono, 13)
	_panel.add_child(_detail)

	_hints = HBoxContainer.new()
	_hints.name = "Keys"
	_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hints.alignment = BoxContainer.ALIGNMENT_CENTER
	_hints.add_theme_constant_override("separation", 18)
	_screen.add_child(_hints)
	_hints.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_hints.offset_left = MARGIN
	_hints.offset_right = -MARGIN
	_hints.offset_top = -HINTS_BOTTOM - HINTS_HEIGHT
	_hints.offset_bottom = -HINTS_BOTTOM
	_show_keys(FREE_KEYS)

	# The push slider as a gauge, at the bottom in the middle (free sailing and racing alike, for the
	# board on the screen), and the body on the mouse (package B, with the setting on) beside it.
	_gauges = HBoxContainer.new()
	_gauges.name = "Gauges"
	_gauges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauges.add_theme_constant_override("separation", 12)
	_screen.add_child(_gauges)
	_push_gauge = PushGauge.new()
	_gauges.add_child(_push_gauge)
	_body_gauge = BodyGauge.new()
	_gauges.add_child(_body_gauge)
	_gauges.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_gauges.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_gauges.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# A gauge shown or hidden changes the row's width: out of the small map's way again.
	_gauges.minimum_size_changed.connect(_place_gauges)
	_place_gauges()

	_rose = WindRose.new()
	_screen.add_child(_rose)
	_rose.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_rose.offset_left = -ROSE_GAP - ROSE_SIZE
	_rose.offset_right = -ROSE_GAP
	_rose.offset_top = ROSE_GAP
	_rose.offset_bottom = ROSE_GAP + ROSE_SIZE

	# A message across the middle of the screen (set_message).
	_message = HudStyle.label(HudStyle.sans(700), 22, Color(1.0, 0.8, 0.4))
	_message.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_message.add_theme_constant_override("outline_size", 5)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_screen.add_child(_message)
	_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_message.offset_left = -450.0
	_message.offset_right = 450.0
	_place_message()
	_message.hide()

	get_viewport().size_changed.connect(_on_window_resized)
	# The mini-map's size applies at once when it changes in the settings (also from the pause menu).
	GameSettings.changed.connect(_on_settings_changed)


## The card at the bottom left while sailing free, anchored to that corner, growing upward.
func _build_status_card() -> void:
	_status_card = PanelContainer.new()
	_status_card.name = "StatusCard"
	_status_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_card.add_theme_stylebox_override("panel", HudStyle.card())
	_screen.add_child(_status_card)
	var lines: VBoxContainer = VBoxContainer.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_theme_constant_override("separation", 1)
	_status_card.add_child(lines)
	for line: int in 4:
		var label: Label = HudStyle.label(HudStyle.sans(700 if line == 0 else 500), 21 if line == 0 else (16 if line < 3 else 14),
			HudStyle.TEXT_COLOR if line < 2 else HudStyle.DIM_COLOR)
		lines.add_child(label)
		_status_lines.append(label)
	place_bottom_left(_status_card)


## A card at the bottom left, above the keys, growing upward as its lines need (also RaceHud's).
static func place_bottom_left(card: Control) -> void:
	card.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	card.offset_left = MARGIN
	card.offset_right = MARGIN
	card.offset_top = -BOTTOM_INSET
	card.offset_bottom = -BOTTOM_INSET


## A small map of the lake in the bottom right corner, above the keys (map scenes only).
## Before show_course(), which then puts the course on it.
func show_mini_map(area: LakeArea, start: Vector3) -> void:
	_make_mini_map()
	_mini_map.setup(area, start)
	_place_mini_map()


## A race course (RACING_PLAN.md, 9A): its name in a line above the small map, and its marks,
## lines and legs on it. Without a lake's map (the open water) the small map shows the course's
## water instead. Again with a changed course (the LAN race director): the map shows it at once.
func show_course(course: Course) -> void:
	if _mini_map == null:
		_make_mini_map()
		_mini_map_frames_course = true
		_mini_map.setup_for_course(course)
	else:
		_mini_map.show_course(course)
	if _course_line == null:
		_course_line = HudStyle.label(HudStyle.sans(600), 15)
		_course_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_screen.add_child(_course_line)
		_course_line.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_course_line.text = "Course: " + course.name
	_place_mini_map()


func course_text() -> String:
	return _course_line.text if _course_line != null else ""


func _make_mini_map() -> void:
	_mini_map = MiniMap.new()
	_mini_map.size_px = _mini_map_size_px()
	_screen.add_child(_mini_map)
	# A course that grows past the map's edge (the open water) makes the map new: put it in its corner.
	_mini_map.resized.connect(_place_mini_map)


## The small map's longer side for the setting "Mini-map size" (a share of the window's height).
func _mini_map_size_px() -> float:
	return MiniMap.size_for(GameSettings.values.minimap_size_percent, _screen_size().y)


## The small map in the bottom right corner, its course's name above it, and the gauges out of its way.
func _place_mini_map() -> void:
	if _mini_map == null:
		return
	var map_size: Vector2 = _mini_map.custom_minimum_size
	_mini_map.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_mini_map.offset_left = -MARGIN - map_size.x
	_mini_map.offset_right = -MARGIN
	_mini_map.offset_top = -BOTTOM_INSET - map_size.y
	_mini_map.offset_bottom = -BOTTOM_INSET
	if _course_line != null:
		_course_line.offset_left = -MARGIN - maxf(map_size.x, 420.0)
		_course_line.offset_right = -MARGIN
		_course_line.offset_top = -BOTTOM_INSET - map_size.y - 26.0
		_course_line.offset_bottom = -BOTTOM_INSET - map_size.y - 4.0
	_place_gauges()


## The gauges in the middle at the bottom; when a big small map in a narrow window would cover them,
## they move left out of its way.
func _place_gauges() -> void:
	var width: float = _gauges.get_combined_minimum_size().x
	var shift: float = 0.0
	if _mini_map != null:
		var map_left: float = _screen_size().x - MARGIN - _mini_map.custom_minimum_size.x
		shift = minf(0.0, map_left - 12.0 - (_screen_size().x + width) * 0.5)
	_gauges.offset_left = shift
	_gauges.offset_right = shift
	_gauges.offset_top = -BOTTOM_INSET
	_gauges.offset_bottom = -BOTTOM_INSET


## How far down from the top the space under the compass reaches before the small map (and its
## course's name) begins: RaceHud fits its standings in it. Pixels of the 720-high layout.
func right_column_bottom() -> float:
	var bottom: float = _screen_size().y - BOTTOM_INSET
	if _mini_map != null:
		bottom -= _mini_map.custom_minimum_size.y + (30.0 if _course_line != null else 4.0)
	else:
		bottom -= PushGauge.GAUGE_SIZE.y
	return bottom - 8.0


## The size of the screen the HUD's parts are laid out on (RaceHud places its results with it).
func screen_size() -> Vector2:
	return _screen_size()


## How far down from the top the space in the middle reaches before the gauges at the bottom begin
## (RaceHud's results end above them). Pixels of the 720-high layout.
func bottom_middle_top() -> float:
	return _screen_size().y - BOTTOM_INSET - PushGauge.GAUGE_SIZE.y


## The small map's width in the bottom right corner (0 without one).
func mini_map_width() -> float:
	return _mini_map.custom_minimum_size.x if _mini_map != null else 0.0


## The size of the screen the HUD is laid out on (the window, in the 720-high layout's pixels, divided
## by the UI scale).
func _screen_size() -> Vector2:
	if _screen != null and _screen.is_inside_tree():
		return _screen.size
	return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1280.0, 720.0)


## A part of the screen made elsewhere (RaceHud, RaceNotice): into the screen with the HUD's own parts,
## so it is laid out and scaled with them.
func add_part(part: Control) -> void:
	_screen.add_child(part)


## The UI scale from the settings: the layer drawn that much bigger, the screen inside it that much
## smaller than the window, so it fills the window exactly. Above 100 % only as much as fits: the
## screen keeps at least SMALLEST_SCREEN of its own pixels, so the speed card, the gauges, the mini-map
## and the keys never run into each other (at 1280 x 720 that is about 108 %; on Max's 3137 x 1263
## window about 129 %). Returns whether it changed.
func _apply_ui_scale() -> bool:
	var window: Vector2 = get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1280.0, 720.0)
	var wanted: float = ui_scale_for(GameSettings.values.ui_scale, window)
	var screen_size: Vector2 = window / wanted
	if is_equal_approx(wanted, ui_scale) and _screen.size.is_equal_approx(screen_size):
		return false
	ui_scale = wanted
	scale = Vector2(wanted, wanted)
	_screen.position = Vector2.ZERO
	_screen.size = screen_size
	return true


## The UI scale used for a setting in a window (in the 720-high layout's pixels): the setting, but
## above 100 % no more than fits (SMALLEST_SCREEN).
static func ui_scale_for(setting: float, window: Vector2) -> float:
	var wanted: float = clampf(setting, SettingsValues.UI_SCALE_MIN, SettingsValues.UI_SCALE_MAX)
	if wanted <= 1.0:
		return wanted
	var fits: float = minf(window.x / SMALLEST_SCREEN.x, window.y / SMALLEST_SCREEN.y)
	return maxf(1.0, minf(wanted, fits))


func _on_window_resized() -> void:
	_apply_ui_scale()
	_fit_hints()
	if _mini_map != null:
		_mini_map.size_px = _mini_map_size_px()
	_place_mini_map()


func _on_settings_changed() -> void:
	if _apply_ui_scale():
		_on_window_resized()
		return
	if _mini_map != null and not is_equal_approx(_mini_map.size_px, _mini_map_size_px()):
		_mini_map.size_px = _mini_map_size_px()
		_place_mini_map()


## The gear the board sails, one line for the F1 panel (set by the scene from the board's
## simulation: the configs it was built from).
var gear_text: String = ""


## The gear of a simulation as one line: what the panel shows and the game prints at its start.
static func gear_line(sim: WindsurferSim) -> String:
	return "gear  board %.2f x %.2f m %.0f l   sail %.1f m2 (luff %.1f m)   trim by feel %s   rig pitch lag %.1f s" % [
		sim.board_config.length_m, sim.board_config.width_m, sim.board_config.volume_m3 * 1000.0,
		sim.sail_config.area_m2, sim.sail_config.luff_m,
		"on" if sim.sailor_config.trim_feel_time_s > 0.0 else "off", sim.sailor_config.rig_pitch_follow_s]


## A short message in the middle of the screen; an empty text hides it.
func set_message(text: String) -> void:
	_message.text = text
	_message.visible = text != ""


func message() -> String:
	return _message.text if _message.visible else ""


func toggle_detail() -> void:
	set_detail_visible(not detail_visible)


## Shows or hides the detail panel and, while sailing free, the keys (F1).
func set_detail_visible(shown: bool) -> void:
	detail_visible = shown
	_panel.visible = shown
	_hints.visible = shown or _race_mode


## The keys along the bottom, as one line of text (for tests): "W S push   ↑ ↓ sheet ...".
func help_text() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for key: Array in _keys:
		parts.append("%s %s" % [key[0], key[1]])
	return "   ".join(parts)


## The keys along the bottom edge: each key in a small chip, then what it does.
func _show_keys(keys: Array[Array]) -> void:
	_base_keys = keys
	var shown: Array[Array] = with_mouse_keys(keys, _mouse_push)
	if _flip_hint:
		# The "flip now" window of a tack or gybe (PlayerController.flip_cue_open()): first in the row.
		var with_flip: Array[Array] = [FLIP_KEY]
		with_flip.append_array(shown)
		shown = with_flip
	if shown == _keys and _hints.get_child_count() > 0:
		return
	_keys = shown
	_build_hints()
	_fit_hints()


## The keys with the body on the mouse (mouse_push: MouseBody.PushOnMouse, -1 without a body): the
## wheel beside W and S for the push, the left button's burst after it, and the mouse as the body.
## Lists without the push (spectating) stay as they are.
static func with_mouse_keys(keys: Array[Array], mouse_push: int) -> Array[Array]:
	if mouse_push < 0:
		return keys
	var shown: Array[Array] = []
	for key: Array in keys:
		if key[0] != "W S":
			shown.append(key)
			continue
		if mouse_push == MouseBody.PushOnMouse.OFF:
			shown.append(key)
		else:
			shown.append(["W S  Wheel", "push"])
		if mouse_push == MouseBody.PushOnMouse.WHEEL_AND_BUTTON:
			shown.append(["Hold left", "burst"])
		shown.append(["Mouse", "body"])
	return shown


## The body on the mouse and its push, for the keys along the bottom (-1: no body on the mouse).
func _show_mouse_keys(mouse_push: int) -> void:
	if mouse_push == _mouse_push:
		return
	_mouse_push = mouse_push
	_show_keys(_base_keys)


## The "flip now" hint along the bottom while a second Space puts the rig across (on), or not.
func _show_flip_hint(on: bool) -> void:
	if on == _flip_hint:
		return
	_flip_hint = on
	_show_keys(_base_keys)


## The keys at the biggest text size that fits across the window (a narrow window: smaller).
func _fit_hints() -> void:
	var room: float = _screen_size().x - 2.0 * MARGIN
	var font_size: int = HINTS_FONT_SIZE
	while true:
		for pair: Node in _hints.get_children():
			for label: Node in pair.get_children():
				(label as Label).add_theme_font_size_override("font_size", font_size)
		if font_size <= HINTS_MIN_FONT_SIZE or _hints.get_combined_minimum_size().x <= room:
			return
		font_size -= 1


## A key in a small chip, then what it does, for every key; the old ones go.
func _build_hints() -> void:
	for child: Node in _hints.get_children():
		_hints.remove_child(child)
		child.free()
	var chip: StyleBoxFlat = StyleBoxFlat.new()
	chip.bg_color = Color(0.07, 0.15, 0.25, 0.85)
	chip.border_color = Color(1.0, 1.0, 1.0, 0.35)
	chip.set_border_width_all(1)
	chip.set_corner_radius_all(4)
	chip.content_margin_left = 6.0
	chip.content_margin_right = 6.0
	chip.content_margin_top = 0.0
	chip.content_margin_bottom = 1.0
	for key: Array in _keys:
		var pair: HBoxContainer = HBoxContainer.new()
		pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pair.add_theme_constant_override("separation", 6)
		var key_label: Label = HudStyle.label(HudStyle.sans(700), HINTS_FONT_SIZE)
		key_label.add_theme_stylebox_override("normal", chip)
		key_label.add_theme_constant_override("outline_size", 0)
		key_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		key_label.text = str(key[0])
		pair.add_child(key_label)
		var what: Label = HudStyle.label(HudStyle.sans(500), HINTS_FONT_SIZE)
		what.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.75))
		what.add_theme_constant_override("outline_size", 4)
		what.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		what.text = str(key[1])
		pair.add_child(what)
		_hints.add_child(pair)


func update_from(t: Telemetry, controller: PlayerController, camera_name: String, use_autopilot: bool) -> void:
	# The push slider on the gauge, when the controller has one: the level the sailor is at, and in a
	# burst (the left mouse button) the level chosen with the keys and the wheel.
	var push_now: float = controller.push_level if is_nan(controller.push_now) else controller.push_now
	_push_gauge.set_level(NAN if use_autopilot else push_now, controller.push_level if controller.is_bursting() else NAN)
	# The body on the mouse, when the player has it on, and its keys along the bottom.
	_body_gauge.set_body(null if use_autopilot else controller.body, t)
	_show_mouse_keys(-1 if use_autopilot or controller.body == null else controller.body.push_on_mouse)
	_show_flip_hint(not use_autopilot and controller.flip_cue_open())
	if not _race_mode:
		_fill_status_card(t, controller, camera_name, use_autopilot)
	_rose.heading_deg = t.heading_deg
	_rose.wind_from_deg = t.wind_from_bearing_deg
	_rose.queue_redraw()
	if _mini_map != null:
		_mini_map.board_position = t.position
		_mini_map.heading_deg = t.heading_deg
		_mini_map.wind_from_deg = t.wind_from_bearing_deg
		_mini_map.queue_redraw()
	_fall_watch.add(t)
	if not detail_visible:
		return
	var windward: float = 1.0 if t.twa_deg >= 0.0 else -1.0
	_detail.text = (
		(gear_text + "\n" if gear_text != "" else "")
		+ "heading %5.1f   TWA %6.1f   AWA %6.1f   AWS %4.1f kt   VMG %5.2f m/s   leeway %4.1f\n" % [t.heading_deg, t.twa_deg, t.awa_deg, t.aws_kt, t.vmg_ms, t.leeway_deg]
		+ "pitch %5.1f   heel %5.1f   yaw rate %5.1f deg/s\n" % [t.pitch_deg, t.heel_deg, t.yaw_rate_dps]
		+ "sheet %3.0f %%  boom %4.0f deg%s   rake %5.2f   rig tilt %5.2f (%4.0f deg)   alpha %5.1f deg%s   helm %5.2f\n" % [t.sheet * 100.0, t.sail_angle_deg, "  across %3.0f %%" % (t.boom_across * 100.0) if t.boom_across > 0.005 else "", t.rake, t.rig_tilt, t.rig_lean_deg, t.alpha_deg, "  BACKWINDED" if t.is_backwinded else "", controller.helm_right]
		+ "lean %5.2f   stance %4.2f   hang-back %4.2f m   knees %5.2f m   sway %4.2f m   hands %4.0f N   feet %4.0f N   feet moment %5.0f Nm\n" % [t.lean, t.stance, t.hang_back_m, t.knee_bend_m, t.leg_sway_m, t.hand_force_n, t.foot_force_n, t.feet_moment_roll_nm]
		# The feet's overload: the moment toward the sail the feet are asked to pass beyond what
		# they can, the pull that tips the sailor over it (GP0: it comes before a catapult).
		+ "feet overload %4.0f Nm toward the sail\n" % maxf(t.feet_moment_excess_nm * windward, 0.0)
		+ "sail  lift %5.0f N  drag %4.0f N  drive %5.0f N  side %5.0f N\n" % [t.sail_lift_n, t.sail_drag_n, t.drive_n, t.side_force_n]
		# "of stall" is the fin's lift coefficient as a share of its peak; "bend" is how far
		# its tip has turned under the load (U2); "up" is the upward part of its force, what
		# it lifts the kit by.
		+ "fin   lift %5.0f N  drag %4.0f N  slip %5.1f deg  load %3.0f %% of stall  bend %4.1f deg  up %4.0f N%s\n" % [t.fin_lift_n, t.fin_drag_n, t.fin_slip_deg, t.fin_load_share * 100.0, t.fin_bend_tip_deg, t.fin_up_n, "  STALLED" if t.fin_stalled else ""]
		# "wetted" is the area the friction acts on (the planing wet span times its width),
		# not the buoyancy grid's smaller area: it is the one that costs speed. "front" is how
		# far forward of the tail the wet part reaches.
		+ "hull  planing %3.0f %% (%4.0f N)  buoyancy %4.0f N  submersion %3.0f %%  wetted %4.2f m2 (front %4.2f m)  resistance %4.0f N  trim %4.1f deg\n" % [t.planing_ratio * 100.0, t.planing_lift_n, t.buoyancy_n, t.submersion_ratio * 100.0, t.friction_area_m2, t.wet_front_m, t.hull_resistance_n, t.trim_deg]
		+ "rig   harness %4.0f N   mast foot pushing down %4.0f N\n" % [t.harness_tension_n, -t.mast_foot_force_up_n]
		+ "auto-sheet %s%s" % ["on" if controller.auto_sheet else "off", "   pilot set from the command line (--pilot.)" if not controller.pilot_overrides.is_empty() else ""]
		# The push slider and what it asks of the sailor (PushDial.describe), with the legs' push.
		+ ("\n%s\nnow: sea rail +%.1f deg (bounce %.0f deg/s)   back foot %+.2f   %s" % [controller.push_text(), controller.auto_sheet_pilot.wave_rail_deg(), controller.auto_sheet_pilot.felt_bounce_dps(), t.back_foot_push, controller.burst_text()] if controller.push_text() != "" else "")
		# The body on the mouse (package B, an experiment): what it adds, for tuning only; the card
		# never shows it (the player reads the board, the spray and the sound).
		+ ("\n" + controller.body_text() if controller.body_text() != "" else "")
		+ ("\n" + _fall_watch.last_fall_text if _fall_watch.last_fall_text != "" else ""))


## The free-sailing card: with the sailor's view (GD6) the forecast wind large and no speed; without
## it the speed large and the wind at 10 m and at the sail. Then the tack and the state (a fall in
## orange, with the waterstart's count), then the time of day, the mode and the camera.
func _fill_status_card(t: Telemetry, controller: PlayerController, camera_name: String, use_autopilot: bool) -> void:
	var tack: String = "starboard tack" if t.twa_deg >= 0.0 else "port tack"
	var state: String = "planing" if t.is_planing else ("luffing" if t.is_luffing else "displacement")
	var fallen: bool = t.sailor_state == 1
	if fallen:
		state = "%s!  waterstart in %d s (R: now)" % [t.fall_kind.to_upper(), ceili(t.waterstart_in_s)]
	var manoeuvre: String = controller.manoeuvre_name()
	var doing: String = "%s  ·  %s%s" % [tack, state, ("  ·  " + manoeuvre) if manoeuvre != "" else ""]
	var who: String = "autopilot" if use_autopilot else controller.mode_name()
	var small: String = "%s%s  ·  camera %s" % [(clock_text + "  ·  ") if clock_text != "" else "", who, camera_name]
	var wind: String = "wind %.0f kt from %s (%03.0f°)" % [t.tws_10m_kt, SettingsValues.compass_name(t.wind_from_bearing_deg), t.wind_from_bearing_deg]
	var lines: PackedStringArray
	if sailor_view:
		lines = PackedStringArray([wind, doing, small, ""])
	else:
		lines = PackedStringArray(["%.1f km/h  ·  %.1f kt" % [t.speed_kmh, t.speed_kt],
			"wind %.1f kt at 10 m, %.1f kt at the sail, from %03.0f°" % [t.tws_10m_kt, t.tws_at_sail_kt, t.wind_from_bearing_deg],
			doing, small])
	for i: int in _status_lines.size():
		_status_lines[i].text = lines[i]
		_status_lines[i].visible = lines[i] != ""
	if fallen != _fall_shown:
		_fall_shown = fallen
		for i: int in 3:
			_status_lines[i].add_theme_color_override("font_color", HudStyle.TEXT_COLOR if i < 2 else HudStyle.DIM_COLOR)
	if fallen:
		(_status_lines[1] if sailor_view else _status_lines[2]).add_theme_color_override("font_color", HudStyle.HIGHLIGHT_COLOR)


## The free-sailing card's lines as one text (for tests).
func status_text() -> String:
	var lines: PackedStringArray = PackedStringArray()
	for label: Label in _status_lines:
		if label.visible:
			lines.append(label.text)
	return "\n".join(lines)


func _label(font: Font, size: int) -> Label:
	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	return label


## A compass rose: North up, the board's heading as a triangle, the wind as an arrow that
## points the way the wind blows (it comes FROM the tail of the arrow).
class WindRose:
	extends Control
	var heading_deg: float = 0.0
	var wind_from_deg: float = 270.0
	## The bearing of a race's next mark; NAN for none.
	var mark_bearing_deg: float = NAN

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var centre: Vector2 = size * 0.5
		var radius: float = minf(size.x, size.y) * 0.45
		draw_circle(centre, radius, Color(0.0, 0.0, 0.0, 0.35))
		draw_arc(centre, radius, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.8), 2.0)
		draw_string(HudStyle.sans(700), centre + Vector2(-5.0, -radius + 15.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		# Bearings are clockwise from North, screen y points down: bearing b is at (sin b, -cos b).
		var heading: Vector2 = Vector2(sin(deg_to_rad(heading_deg)), -cos(deg_to_rad(heading_deg)))
		var bow: Vector2 = centre + heading * radius * 0.8
		var side: Vector2 = Vector2(-heading.y, heading.x) * radius * 0.18
		draw_colored_polygon(PackedVector2Array([bow, centre - heading * radius * 0.3 + side, centre - heading * radius * 0.3 - side]), Color(1.0, 0.6, 0.1, 0.95))
		var from: Vector2 = Vector2(sin(deg_to_rad(wind_from_deg)), -cos(deg_to_rad(wind_from_deg)))
		var tail: Vector2 = centre + from * radius * 0.95
		var head: Vector2 = centre + from * radius * 0.35
		draw_line(tail, head, Color(0.5, 0.85, 1.0), 3.0, true)
		var dir: Vector2 = (head - tail).normalized()
		var wing: Vector2 = Vector2(-dir.y, dir.x) * 6.0
		draw_colored_polygon(PackedVector2Array([head, head - dir * 10.0 + wing, head - dir * 10.0 - wing]), Color(0.5, 0.85, 1.0))
		# The next mark of a race: an orange dot on the rim at its bearing.
		if not is_nan(mark_bearing_deg):
			var to_mark: Vector2 = Vector2(sin(deg_to_rad(mark_bearing_deg)), -cos(deg_to_rad(mark_bearing_deg)))
			draw_circle(centre + to_mark * radius * 0.88, 5.0, Color(1.0, 0.45, 0.1))


## The other boards of a race on the small map (RaceRunner).
func set_other_boards(positions: PackedVector3Array) -> void:
	if _mini_map != null:
		_mini_map.other_boards = positions


## A race (RaceRunner): the free-sailing card and the panel make way for the race's own card and
## standings (RaceHud); F1 still brings the panel back. The keys are the racing keys, or while
## spectating (the player's board parked) the keys that pick the board to watch.
func set_race_mode(on: bool, spectating: bool = false) -> void:
	_race_mode = on
	_status_card.visible = not on
	_place_message()
	if on:
		set_detail_visible(false)
		if spectating:
			_show_keys(SPECTATE_KEYS)
		elif Lan.in_game and not Lan.is_host():
			# The guest of a network game: only the host restarts the race (main.gd, _net_reset()).
			_show_keys(GUEST_KEYS)
		else:
			_show_keys(RACE_KEYS)
	else:
		_show_keys(FREE_KEYS)


## The message sits high while sailing free, and under the race card and its warnings in a race.
func _place_message() -> void:
	var top: float = MESSAGE_TOP_IN_RACE if _race_mode else MESSAGE_TOP
	_message.offset_top = top
	_message.offset_bottom = top + 34.0


## The bearing of a race's next mark, as a dot on the compass rose (NAN clears it).
func set_next_mark_bearing(bearing_deg: float) -> void:
	_rose.mark_bearing_deg = bearing_deg
