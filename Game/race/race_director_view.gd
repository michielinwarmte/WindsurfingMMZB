class_name RaceDirectorView
extends Node
## The race director's view (Documentation/reports/multiplayer/RACE_DIRECTOR.md R5): M in a race
## (the LAN host, or the player of a race alone) lifts the camera above the water, as in the wind
## viewer, with the course maker on the right and the race director's panel on the left. Every
## change to the course goes into the race and to every PC at once (RaceDirector.publish_course());
## during a race only the marks' places may change, and the course maker says so when it refuses
## a change. On the lake the wind viewer's white streaks show the map's wind (V), and its speed
## colours can be put on the water (C). Every board is a dot with its name.
##
## While the view is open an all-rounder skipper sails and races this PC's board (Max's answer of 6
## November 2026); M or Esc closes the view and gives the board back. The game's HUD is hidden
## meanwhile: the panel shows the race.
##
## Keys: W A S D (or the arrows) move the map, the wheel (or E and Q) zooms, the right mouse drags
## it; the course maker's own keys (Delete, Ctrl+Z, Esc to deselect); V the streaks, C the colours.

## The window height the panels are laid out for (as the wind viewer: canvas_items stretch while the
## view is open, see _fit_ui()).
const UI_HEIGHT_PX: float = 720.0
const GROUND_PATH: String = "res://maps/silvaplana/wind/ground.json"
const SPEED_WATER_SHADER: Shader = preload("res://maps/wind/wind_speed_water.gdshader")
## Where the open water's courses are kept (the lake's are the team's, in the project).
const OPEN_WATER_COURSES: String = "user://courses_open_water"
## The skipper that sails this PC's board while the view is open.
const PILOT: String = "allrounder"
const PANEL_WIDTH_PX: float = 300.0
const FONT_SIZE: int = 13
## The boards on the map: a dot this big (pixels), this PC's in orange, the others white.
const DOT_PX: float = 4.0
const OWN_COLOR: Color = Color(1.0, 0.6, 0.1)
const OTHER_COLOR: Color = Color(1.0, 1.0, 1.0, 0.95)
const LABEL_FONT_SIZE: int = 11
## The panel's status is written this often (seconds).
const STATUS_EVERY_S: float = 0.25

var director: RaceDirector = null
var scene: SailingScene = null
var is_open: bool = false

var _own: WindsurferNode = null
var _layer: CanvasLayer = null
var _panels: Control = null
var _camera: TopCamera = null
var _camera_before: Camera3D = null
var _editor: CourseEditor = null
var _boards_drawing: BoardsOnMap = null
var _status: Label = null
var _gap: OptionButton = null
var _countdown: OptionButton = null
var _laps: SpinBox = null
var _status_in_s: float = 0.0
## The window's scaling before the view changed it: mode, aspect, size (put back on close).
var _window_before: Array = []
## The lake's wind picture (null on the open water).
var _map_wind: MapWindField = null
var _streaks: WindStreaks = null
var _speed_layer: MeshInstance3D = null
var _speed_material: ShaderMaterial = null
## The skipper sailing this PC's board while the view is open (null when closed).
var _pilot: RaceSkipper = null
## True while the view hands the race's course to the course maker (that change is not a new one).
var _taking_course: bool = false


## The boards as dots with their names over the 3D view.
class BoardsOnMap:
	extends Control
	var view: RaceDirectorView = null

	func _draw() -> void:
		view.draw_boards(self)


func _init() -> void:
	name = "RaceDirectorView"
	process_mode = Node.PROCESS_MODE_ALWAYS


## Builds the view (hidden): the camera, the course maker, the panel, the lake's wind picture.
func setup(race_director: RaceDirector, sailing_scene: SailingScene, own: WindsurferNode) -> void:
	director = race_director
	scene = sailing_scene
	_own = own
	_layer = CanvasLayer.new()
	_layer.name = "DirectorLayer"
	# Above the HUD (1), under the pause menu (10).
	_layer.layer = 5
	add_child(_layer)
	_boards_drawing = BoardsOnMap.new()
	_boards_drawing.view = self
	_boards_drawing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_boards_drawing)
	_boards_drawing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panels = Control.new()
	_panels.name = "Panels"
	_panels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_panels)
	_panels.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_camera = TopCamera.new()
	_camera.name = "DirectorCamera"
	_camera.far = 40000.0
	add_child(_camera)
	_set_camera_active(false)
	_editor = CourseEditor.new()
	_editor.name = "CourseEditor"
	add_child(_editor)
	_editor.setup(_layer, _panels, scene.map_config(), _height_at, _courses_folder(), _wind_now, func() -> Vector2: return _camera.centre)
	_editor.course_changed.connect(_on_course_maker_changed)
	_build_panel()
	director.runner.restarted.connect(_on_new_start)
	_layer.visible = false
	_editor.process_mode = Node.PROCESS_MODE_DISABLED


# ---------------------------------------------------------------- opening and closing

func open() -> void:
	if is_open:
		return
	is_open = true
	_fit_ui()
	_camera_before = get_viewport().get_camera_3d()
	_look_at_the_course()
	_set_camera_active(true)
	_layer.visible = true
	_editor.process_mode = Node.PROCESS_MODE_INHERIT
	_taking_course = true
	_editor.edit_course(scene.live_course().copy())
	_taking_course = false
	_editor.show_message("Drag the marks; during a race only their places can change.")
	if _map_wind == null and scene.map_wind_field() != null:
		# Built at the first opening, shown at once: particles' trails made while hidden come out
		# wrong (long streaks all pointing the same way).
		_add_wind_picture()
	elif _streaks != null:
		_streaks.restart()
		_streaks.visible = true
	_give_the_board_to_the_pilot()
	_update_status()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_restore_window()
	_set_camera_active(false)
	if _camera_before != null and is_instance_valid(_camera_before):
		_camera_before.current = true
	_layer.visible = false
	_editor.process_mode = Node.PROCESS_MODE_DISABLED
	if _streaks != null:
		_streaks.visible = false
	if _speed_layer != null:
		_speed_layer.visible = false
	_take_the_board_back()
	get_viewport().gui_release_focus()


func _set_camera_active(on: bool) -> void:
	_camera.current = on
	_camera.set_process(on)
	_camera.set_process_unhandled_input(on)


## The camera straight above the course, high enough to see all of it with room for the panels.
func _look_at_the_course() -> void:
	var course: Course = scene.live_course()
	if course == null:
		return
	var box: Rect2 = course.bounds().grow(150.0)
	var half_view: float = tan(deg_to_rad(_camera.fov * 0.5))
	var window: Vector2 = get_viewport().get_visible_rect().size
	var across_share: float = window.y / maxf(window.x, 1.0)
	var height_m: float = maxf(box.size.y, box.size.x * across_share * 1.6) * 0.5 / half_view
	_camera.look_down_at(box.get_center(), height_m)


## The panels as big, against the window, as in a 1280 x 720 window (the wind viewer's way, for the
## time the view is open; the game's own screen comes back on close).
func _fit_ui() -> void:
	var window: Window = get_window()
	_window_before = [window.content_scale_mode, window.content_scale_aspect, window.content_scale_size]
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.content_scale_size = Vector2i(roundi(UI_HEIGHT_PX * 16.0 / 9.0), roundi(UI_HEIGHT_PX))


func _restore_window() -> void:
	if _window_before.size() == 3:
		var window: Window = get_window()
		window.content_scale_mode = _window_before[0]
		window.content_scale_aspect = _window_before[1]
		window.content_scale_size = _window_before[2]
	_window_before = []


func _exit_tree() -> void:
	_restore_window()


# ---------------------------------------------------------------- the board on the autopilot

## An all-rounder sails and races this PC's board while the view is open (as the AI boards are
## sailed: its hands on the controller).
func _give_the_board_to_the_pilot() -> void:
	if _own == null or _own.skipper != null:
		return
	_pilot = Skippers.make(PILOT)
	if _pilot == null:
		return
	_own.hands = AiHands.new()
	_own.controller.hands = _own.hands
	_own.skipper = _pilot
	_set_up_the_pilot()


func _set_up_the_pilot() -> void:
	var runner: RaceRunner = director.runner
	if _pilot == null or runner.race == null:
		return
	_pilot.random_seed = 11
	_pilot.sailing_area = runner.sailing_area()
	_pilot.rules = runner.rules
	_pilot.shore = runner.shore_lookout
	_pilot.setup(_own.sim, _own.controller, _own.hands, runner.race, 0)


func _take_the_board_back() -> void:
	if _pilot == null or _own == null:
		return
	if _own.skipper == _pilot:
		_own.skipper = null
		_own.hands = null
		_own.controller.hands = null
	_pilot = null


## A new race began while the view is open: the pilot races it.
func _on_new_start() -> void:
	if is_open:
		_set_up_the_pilot()


# ---------------------------------------------------------------- the keys and the mouse

## The scene passes every unhandled event here while the view is open; M closes it, and Esc when
## the course maker has nothing to stop or deselect.
func handle_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_M:
		scene.close_race_director()
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed:
		# A click in the view takes the keyboard back from the panels' fields.
		get_viewport().gui_release_focus()
	if _editor.handle_input(event):
		return
	if key != null and key.pressed and not key.echo:
		match key.physical_keycode:
			KEY_ESCAPE:
				scene.close_race_director()
			KEY_V:
				if _streaks != null:
					_streaks.visible = not _streaks.visible
			KEY_C:
				if _speed_layer != null:
					_speed_layer.visible = not _speed_layer.visible


# ---------------------------------------------------------------- the course

## Every change in the course maker goes to the race and to everyone; a change the race cannot
## take now (another shape during a race) is undone with a message.
func _on_course_maker_changed(course: Course) -> void:
	if _taking_course or not is_open or course == null:
		return
	if director.publish_course(course):
		return
	_taking_course = true
	_editor.edit_course(scene.live_course().copy())
	_taking_course = false
	if director.is_racing():
		_editor.show_message("During a race only the marks' places can change. Change the course's shape between races.")
	else:
		_editor.show_message("A race needs a start line and a finish line (start boat and pin, finish boat and pin).")


func _height_at(x: float, z: float) -> float:
	var grid: TerrainGrid = scene.shore_grid
	if grid == null:
		return -10.0  # the open water: water everywhere
	return grid.height_at(x, z) if grid.contains(x, z) else NAN


func _courses_folder() -> String:
	return RaceCourses.SAVED_FOLDER if scene.map_config() != null else OPEN_WATER_COURSES


## The wind a race committee sets its course to: on the lake the lake's mean of the moment, on the
## open water the wind over the water. Vector2(where it comes from in degrees, its speed in knots).
func _wind_now() -> Vector2:
	if _map_wind != null:
		var t: float = _map_wind.time_of_day_s()
		var wind: MapWind = _map_wind.map_wind
		return Vector2(fposmod(wind.lake_from_deg(t), 360.0), wind.day.lake_speed_ms(t) / SimMath.KNOT_MS)
	var telemetry: Telemetry = _own.sim.telemetry
	return Vector2(telemetry.wind_from_bearing_deg, telemetry.tws_10m_kt)


# ---------------------------------------------------------------- the lake's wind picture

## The wind viewer's streaks over the lake, and its speed colours (off until C), from the lake's
## own wind (MapWind, the same the boards sail in).
func _add_wind_picture() -> void:
	_map_wind = scene.map_wind_field()
	var wind: MapWind = _map_wind.map_wind
	var ground: TerrainGrid = TerrainGrid.load_from(GROUND_PATH)
	if ground == null:
		return
	var pattern_texture: ImageTexture = ImageTexture.create_from_image(wind.pattern.to_image(ground))
	var lee_texture: ImageTexture = ImageTexture.create_from_image(wind.lee.to_image())
	_streaks = WindStreaks.new()
	_streaks.name = "DirectorStreaks"
	add_child(_streaks)
	_streaks.setup(wind, pattern_texture, lee_texture)
	var grid: TerrainGrid = scene.shore_grid
	if grid == null:
		return
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2((grid.columns - 1) * grid.cell_m, (grid.rows - 1) * grid.cell_m)
	_speed_material = ShaderMaterial.new()
	_speed_material.shader = SPEED_WATER_SHADER
	_speed_material.set_shader_parameter("speed_colors", WindColors.texture())
	_speed_material.set_shader_parameter("max_knots", WindColors.MAX_KNOTS)
	wind.pattern.set_shader_pattern(_speed_material, pattern_texture)
	wind.lee.set_shader_lee(_speed_material, lee_texture)
	_set_parameters(_speed_material, wind.shader_constants())
	_speed_material.render_priority = 1
	_speed_layer = MeshInstance3D.new()
	_speed_layer.name = "DirectorWindColours"
	_speed_layer.mesh = plane
	# Above the waves' crests, so the colours cover the water seen from above.
	_speed_layer.position = Vector3(grid.x0_m + plane.size.x / 2.0, 0.6, grid.z0_m + plane.size.y / 2.0)
	_speed_layer.material_override = _speed_material
	_speed_layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_speed_layer.visible = false
	add_child(_speed_layer)


func _set_parameters(material: ShaderMaterial, parameters: Dictionary[String, Variant]) -> void:
	for key: String in parameters:
		material.set_shader_parameter(key, parameters[key])


# ---------------------------------------------------------------- every frame

func _process(delta: float) -> void:
	if not is_open:
		return
	if _map_wind != null:
		var parameters: Dictionary[String, Variant] = _map_wind.moment().shader_parameters()
		if _streaks != null and _streaks.visible:
			_streaks.set_wind(parameters)
			var at: Vector3 = _camera.global_position
			_streaks.follow(_camera, Vector3(at.x, 0.0, at.z), at.y, at.y, at.y)
		if _speed_layer != null and _speed_layer.visible:
			_set_parameters(_speed_material, parameters)
	_boards_drawing.queue_redraw()
	_status_in_s -= delta
	if _status_in_s <= 0.0:
		_status_in_s = STATUS_EVERY_S
		_update_status()


## Every board as a dot with its name (this PC's board orange).
func draw_boards(canvas: Control) -> void:
	var font: Font = ThemeDB.fallback_font
	for child: Node in scene.get_children():
		var node: WindsurferNode = child as WindsurferNode
		if node == null or not node.visible:
			continue
		var at: Vector3 = node.get_global_transform_interpolated().origin
		if _camera.is_position_behind(at):
			continue
		# As the course maker's overlay draws the marks (CourseOverlay.screen_point()).
		var point: Vector2 = _camera.unproject_position(at)
		var own: bool = node == _own
		canvas.draw_circle(point, DOT_PX + (1.5 if own else 0.0), Color(0.0, 0.0, 0.0, 0.6))
		canvas.draw_circle(point, DOT_PX, OWN_COLOR if own else OTHER_COLOR)
		var label: String = "You (autopilot)" if own else node.label_text()
		if label != "":
			canvas.draw_string_outline(font, point + Vector2(7.0, 4.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, LABEL_FONT_SIZE, 3, Color(0.0, 0.0, 0.0, 0.8))
			canvas.draw_string(font, point + Vector2(7.0, 4.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, LABEL_FONT_SIZE, OWN_COLOR if own else OTHER_COLOR)


# ---------------------------------------------------------------- the race director's panel

func _build_panel() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "DirectorPanel"
	panel.add_theme_stylebox_override("panel", CoursePanel.background())
	_panels.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 12.0
	panel.offset_top = 12.0
	panel.offset_right = 12.0 + PANEL_WIDTH_PX
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	var title: Label = _label("Race director", column)
	title.add_theme_font_size_override("font_size", FONT_SIZE + 5)
	_status = _label("", column)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(PANEL_WIDTH_PX - 24.0, 0.0)
	column.add_child(HSeparator.new())
	_label("The next race", column)
	var start_now: Button = _button("Start the countdown now", column)
	start_now.pressed.connect(func() -> void: director.start_countdown_now())
	var move_row: HBoxContainer = _row(column)
	_button("1 minute sooner", move_row).pressed.connect(func() -> void: director.move_next_start(-60.0))
	_button("1 minute later", move_row).pressed.connect(func() -> void: director.move_next_start(60.0))
	var gap_row: HBoxContainer = _row(column)
	_label("Countdown begins after a race:", gap_row)
	_gap = _choice(gap_row, RaceDirector.GAP_CHOICES_S, director.gap_s)
	_gap.item_selected.connect(func(index: int) -> void: director.set_gap_s(RaceDirector.GAP_CHOICES_S[index]))
	var countdown_row: HBoxContainer = _row(column)
	_label("Countdown:", countdown_row)
	_countdown = _choice(countdown_row, RaceDirector.COUNTDOWN_CHOICES_S, director.runner.setup.prestart_s)
	_countdown.item_selected.connect(func(index: int) -> void: director.set_countdown_s(RaceDirector.COUNTDOWN_CHOICES_S[index]))
	var laps_row: HBoxContainer = _row(column)
	_label("Laps:", laps_row)
	_laps = SpinBox.new()
	_laps.min_value = 1
	_laps.max_value = 9
	_laps.value = director.runner.setup.laps
	_laps.add_theme_font_size_override("font_size", FONT_SIZE)
	_laps.value_changed.connect(func(value: float) -> void: director.set_laps(roundi(value)))
	laps_row.add_child(_laps)
	_label("Countdown, gap and laps count from the next race.", column).modulate = Color(1.0, 1.0, 1.0, 0.65)
	column.add_child(HSeparator.new())
	_label("This race", column)
	var race_row: HBoxContainer = _row(column)
	_button("Abandon it", race_row).pressed.connect(func() -> void: director.abandon())
	_button("Everyone to the line", race_row).pressed.connect(func() -> void: director.everyone_to_the_line())
	column.add_child(HSeparator.new())
	var help: Label = _label("Your board races on the autopilot while this view is open.\nM or Esc: back to your board.\nW A S D, wheel, right mouse: move the map." + ("\nV streaks, C wind colours." if scene.map_wind_field() != null else ""), column)
	help.modulate = Color(1.0, 1.0, 1.0, 0.75)


## The panel's status: the race and the next start.
func _update_status() -> void:
	var race: RaceSim = director.runner.race
	var lines: PackedStringArray = PackedStringArray()
	if race == null:
		lines.append("No race.")
	elif director.next_countdown_in_s >= 0.0:
		lines.append("Race %d is over." % director.runner.race_number)
		lines.append("The next countdown begins in %s." % RaceDirector.minutes(director.next_countdown_in_s))
	elif not race.is_started():
		lines.append("Sailing free; the countdown begins in %s." % RaceDirector.minutes(race.seconds_to_countdown()))
	elif race.phase() == RaceSim.Phase.PRE_START:
		lines.append("Race %d: the countdown, %s to the gun." % [director.runner.race_number, RaceDirector.minutes(race.countdown_s())])
	else:
		var finished: int = 0
		for i: int in race.board_count():
			if race.is_finished(i):
				finished += 1
		lines.append("Race %d: %s raced, %d of %d boards in." % [director.runner.race_number, RaceDirector.minutes(race.race_time_s()), finished, race.board_count()])
		var order: Array[int] = race.race_order()
		if not order.is_empty():
			lines.append("Leading: %s" % race.board_name(order[0]))
	lines.append("%d laps, %s countdown, then %s between races." % [director.runner.setup.laps, RaceDirector.minutes(director.runner.setup.prestart_s), RaceDirector.minutes(director.gap_s)])
	_status.text = "\n".join(lines)


func _label(text: String, parent: Control) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	parent.add_child(label)
	return label


func _button(text: String, parent: Control) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(button)
	return button


func _row(parent: Control) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	return row


## A drop-down of times ("1:00", "3:00"), the nearest to `now` chosen.
func _choice(parent: Control, seconds: Array[float], now: float) -> OptionButton:
	var choice: OptionButton = OptionButton.new()
	choice.focus_mode = Control.FOCUS_NONE
	choice.add_theme_font_size_override("font_size", FONT_SIZE)
	var nearest: int = 0
	for i: int in seconds.size():
		choice.add_item(RaceDirector.minutes(seconds[i]))
		if absf(seconds[i] - now) < absf(seconds[nearest] - now):
			nearest = i
	choice.select(nearest)
	parent.add_child(choice)
	return choice
