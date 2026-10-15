extends Node3D
## The wind analyser's viewer for Lake Silvaplana (MAP_SILVAPLANA_PLAN.md, W2): the Windfinder map
## in 3D. White streaks move with the wind over the real terrain, the water is coloured by the wind
## speed, a clock runs the day in real time or faster, and a click on the map shows the wind at
## that point over the last minutes. The wind is MapWind: the fixed Maloja pattern (W1) carried by
## the average Maloja day, with gusts and lulls, pulses and shifts on top (W3).
##
## The course maker (W4a, CourseEditor) puts an iQFOiL race course on the lake: its panel is at the
## top right; drag a mark to move it, Shift and drag the whole course.
##
## Keys: Tab switches between the map camera (looking down) and the free camera; Space pauses the
## clock, 1, 2 and 3 run it at 1x, 10x and 60x; C switches the speed colours on the water off and on,
## V the streaks; [ and ] make the streaks slower and faster; M shows and hides the course, Ctrl+Z
## undoes a change to it. Left click away from the course's marks: the wind at that point.
## Map camera: W A S D (or the arrows) move, the wheel (or E and Q) zooms, right mouse drags the map.
## Free camera: W A S D, E and Q fly, Shift is faster, hold the right mouse button to look around.
##
## Start it with tools/play.sh wind. Options for screenshots (after --):
##   --camera=free  --at=<east>,<north>,<m above the lake> --look=<east>,<north>,<m>  (LV95)
##   --top=<east>,<north>,<m above the lake>  --time=14:30  --probe=<east>,<north>  --colours=off
##   --streaks=off  --paused  --course=<template, like LG2, or a saved course's name>
##   --course-at=<east>,<north> (where a template's middle goes; else the middle of the view)
##   --course-new-mark=<east>,<north> (Add mark, with its preview there as if the mouse were there)
## And a check that the graphics card computes the same wind as the game's numbers (WD1):
##   tools/godot.sh --path Game res://maps/silvaplana/wind_viewer.tscn -- --check-colours --time=14:30
## compares the water's colour on the screen with the colour MapWind gives, prints the result and quits.

const CONFIG_PATH: String = "res://maps/silvaplana/map_config.tres"
const SHORE_GRID_PATH: String = "res://maps/silvaplana/terrain/shore_heights.json"
const GROUND_PATH: String = "res://maps/silvaplana/wind/ground.json"
const PATTERN_PATH: String = "res://maps/silvaplana/wind/maloja_pattern.json"
const DAY_PATH: String = "res://maps/silvaplana/wind/maloja_day.tres"
const GUSTS_PATH: String = "res://maps/silvaplana/wind/maloja_gusts.tres"
const LEE_PATH: String = "res://maps/silvaplana/wind/shore_lee.json"
const LAKE_PATH: String = "res://maps/silvaplana/lake.tres"
## The team's race courses (W4a, WD6): in the project, so git shares them.
const COURSES_PATH: String = "res://maps/silvaplana/courses"
const SPEED_WATER_SHADER: Shader = preload("res://maps/wind/wind_speed_water.gdshader")

## Where the cameras start: the map camera above the middle of the lake, the free camera above the
## Sils end, looking down the lake the way the Maloja blows (LV95 east, north, metres above the lake).
const TOP_START: Vector3 = Vector3(2780300.0, 1146500.0, 4500.0)
const FREE_START: Vector3 = Vector3(2778700.0, 1144300.0, 350.0)
const FREE_LOOK: Vector3 = Vector3(2781100.0, 1147700.0, 0.0)
## The click history: the last 10 minutes, a value every 2 seconds. After a jump the values are
## worked out HISTORY_PER_FRAME per frame, so a jump never makes the viewer stutter.
const HISTORY_S: float = 600.0
const HISTORY_STEP_S: float = 2.0
const HISTORY_PER_FRAME: int = 50
## The streak speed-up changes by this factor with the [ and ] keys.
const STREAK_SPEED_STEP: float = 1.5
## The window height the screen's panels are laid out for, pixels (see _build_ui()).
const UI_HEIGHT_PX: float = 720.0

@onready var _top_camera: TopCamera = $TopCamera
@onready var _fly_camera: FlyCamera = $FlyCamera
@onready var _streaks: WindStreaks = $WindStreaks

var _config: MapConfig
var _shore: TerrainGrid
var _ground: TerrainGrid
var _wind: MapWind
var _clock: WindClock = WindClock.new()
var _speed_layer: MeshInstance3D
var _speed_material: ShaderMaterial
var _probe_point: Vector3 = Vector3.INF
var _probe_marker: Node3D
## The click history: speed (kt) and direction (degrees) per step number (time / HISTORY_STEP_S).
var _history: Dictionary[int, Vector2] = {}

var _course_editor: CourseEditor

var _ui_layer: CanvasLayer
## All the screen's panels, each anchored to its corner or edge (see _fit_ui()).
var _panels: Control
## The window's scaling before the viewer changed it: mode, aspect, size (put back on exit).
var _window_before: Array = []
var _info: Label
var _pause_button: Button
var _rate_buttons: Array[Button] = []
var _slider: HSlider
var _time_label: Label
var _probe_chart: WindProbeChart


func _ready() -> void:
	_config = load(CONFIG_PATH)
	_shore = TerrainGrid.load_from(SHORE_GRID_PATH)
	_ground = TerrainGrid.load_from(GROUND_PATH)
	_wind = MapWind.load_from(PATTERN_PATH, DAY_PATH, _config, GUSTS_PATH, LEE_PATH)
	var pattern_texture: ImageTexture = ImageTexture.create_from_image(_wind.pattern.to_image(_ground))
	var lee_texture: ImageTexture = ImageTexture.create_from_image(_wind.lee.to_image())
	_streaks.setup(_wind, pattern_texture, lee_texture)
	_add_water(pattern_texture, lee_texture)
	_use_plain_colours()
	_probe_marker = _make_probe_marker()
	add_child(_probe_marker)
	_build_ui()
	_add_course_editor()

	var top: Vector3 = _game_point(TOP_START)
	_top_camera.look_down_at(Vector2(top.x, top.z), TOP_START.z)
	_fly_camera.place(_game_point(FREE_START), _game_point(FREE_LOOK))
	_fly_camera.speed_ms = 100.0
	_read_command_line()
	if "--check-colours" in OS.get_cmdline_user_args():
		_check_colours()


func _unhandled_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed:
		# A click in the view takes the keyboard back from the course panel's text fields.
		get_viewport().gui_release_focus()
	if _course_editor.handle_input(event):
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo:
		match key.physical_keycode:
			KEY_TAB:
				_use_top_camera(not _top_camera.current)
			KEY_SPACE:
				_set_paused(not _clock.paused)
			KEY_1, KEY_2, KEY_3:
				_set_rate(key.physical_keycode - KEY_1)
			KEY_C:
				_speed_layer.visible = not _speed_layer.visible
			KEY_V:
				_streaks.visible = not _streaks.visible
			KEY_BRACKETLEFT:
				_streaks.speed_up_per_metre /= STREAK_SPEED_STEP
			KEY_BRACKETRIGHT:
				_streaks.speed_up_per_metre *= STREAK_SPEED_STEP
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		_probe_point = _pick(button.position)
		_history.clear()


func _process(delta: float) -> void:
	_clock.advance(delta)
	var now: WindMoment = _wind.moment(_clock.time_of_day_s)
	var parameters: Dictionary[String, Variant] = now.shader_parameters()
	_streaks.set_wind(parameters)
	_set_parameters(_speed_material, parameters)
	_follow_with_streaks(get_viewport().get_camera_3d())
	_update_probe(now)
	_update_ui()


# ---------------------------------------------------------------- the scene

## The lake: the map's see-through water (as in the terrain view), and on top of it a layer with
## the wind speed as colour. Both cover the shore band; the terrain hides them on land.
func _add_water(pattern_texture: Texture2D, lee_texture: Texture2D) -> void:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2((_shore.columns - 1) * _shore.cell_m, (_shore.rows - 1) * _shore.cell_m)
	var middle: Vector3 = Vector3(_shore.x0_m + plane.size.x / 2.0, 0.0, _shore.z0_m + plane.size.y / 2.0)
	var water: MeshInstance3D = MeshInstance3D.new()
	water.name = "LakeWater"
	water.mesh = plane
	water.position = middle
	water.material_override = load(LAKE_PATH)
	# Render layer 2 only: the map's LakeReflections probe mirrors the mountains in this layer.
	water.layers = 2
	add_child(water)

	_speed_material = ShaderMaterial.new()
	_speed_material.shader = SPEED_WATER_SHADER
	_speed_material.set_shader_parameter("speed_colors", WindColors.texture())
	_speed_material.set_shader_parameter("max_knots", WindColors.MAX_KNOTS)
	_wind.pattern.set_shader_pattern(_speed_material, pattern_texture)
	_wind.lee.set_shader_lee(_speed_material, lee_texture)
	_set_parameters(_speed_material, _wind.shader_constants())
	# Drawn after the water and before the streaks.
	_speed_material.render_priority = 1
	_speed_layer = MeshInstance3D.new()
	_speed_layer.name = "WindSpeedColours"
	_speed_layer.mesh = plane
	_speed_layer.position = middle + Vector3(0.0, 0.05, 0.0)
	_speed_layer.material_override = _speed_material
	_speed_layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_speed_layer)


func _set_parameters(material: ShaderMaterial, parameters: Dictionary[String, Variant]) -> void:
	for key: String in parameters:
		material.set_shader_parameter(key, parameters[key])


## The map's light is tuned with filmic tone mapping (M2), which brightens and flattens the colours.
## Here the water's colours must be exactly the legend's, so this view maps them one to one
## (linear): the terrain looks a little harsher than in the terrain view.
func _use_plain_colours() -> void:
	var world: WorldEnvironment = $Silvaplana/WorldEnvironment
	world.environment = world.environment.duplicate()
	world.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR


## An orange pole with a ball on top that marks the clicked point. It is scaled with its distance
## to the camera every frame, so it looks the same size at every zoom.
func _make_probe_marker() -> Node3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("#f08a32")
	var pole: CylinderMesh = CylinderMesh.new()
	pole.top_radius = 0.06
	pole.bottom_radius = 0.06
	pole.height = 1.0
	var ball: SphereMesh = SphereMesh.new()
	ball.radius = 0.15
	ball.height = 0.3
	var marker: Node3D = Node3D.new()
	marker.name = "ProbeMarker"
	for part: Array in [[pole, 0.5], [ball, 1.0]]:
		var mesh: MeshInstance3D = MeshInstance3D.new()
		mesh.mesh = part[0]
		mesh.position.y = part[1]
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		marker.add_child(mesh)
	marker.visible = false
	return marker


func _use_top_camera(top: bool) -> void:
	_top_camera.current = top
	_fly_camera.current = not top
	# Only the camera in use listens to the keys and the mouse.
	for camera: Camera3D in [_top_camera, _fly_camera]:
		camera.set_process(camera.current)
		camera.set_process_unhandled_input(camera.current)


# ---------------------------------------------------------------- the course maker (W4a)

func _add_course_editor() -> void:
	_course_editor = CourseEditor.new()
	_course_editor.name = "CourseEditor"
	add_child(_course_editor)
	# The land check reads the shore band's 2 m grid, which holds the whole lake.
	var height_at: Callable = func(x: float, z: float) -> float:
		return _shore.height_at(x, z) if _shore.contains(x, z) else NAN
	_course_editor.setup(_ui_layer, _panels, _config, height_at, COURSES_PATH, _lake_wind_now, _view_centre)


## The lake's wind now (the day's mean, without the moving shifts): Vector2(where it comes from in
## degrees, its speed in knots). A race committee sets its course to this.
func _lake_wind_now() -> Vector2:
	var t: float = _clock.time_of_day_s
	return Vector2(fposmod(_wind.lake_from_deg(t), 360.0), _wind.day.lake_speed_ms(t) / SimMath.KNOT_MS)


## The game point (X, Z) in the middle of the view: below the map camera, or where the free camera
## looks at the lake (at most 3 km ahead).
func _view_centre() -> Vector2:
	if _top_camera.current:
		return _top_camera.centre
	var at: Vector3 = _fly_camera.global_position
	var forward: Vector3 = -_fly_camera.global_basis.z
	var ahead_m: float = 3000.0
	if forward.y < -0.01:
		ahead_m = minf(at.y / -forward.y, 3000.0)
	var point: Vector3 = at + forward * ahead_m
	return Vector2(point.x, point.z)


# ---------------------------------------------------------------- the clock

func _set_paused(paused: bool) -> void:
	_clock.paused = paused


func _set_rate(index: int) -> void:
	_clock.rate = WindClock.RATES[index]
	_clock.paused = false


func _on_slider_moved(seconds: float) -> void:
	_clock.set_time(seconds)


# ---------------------------------------------------------------- what the camera looks at

## Tells the streaks where to start and how big the view is. The map camera looks at a square
## below it. The free camera looks at a square from where it is to as far ahead as it looks: where
## the middle of the view meets the lake's level, at most 6 km; looking level or up, 3 km. Its view
## size is between its height and that distance, so from the water the streaks move at about the
## real speed, and from high up much faster.
func _follow_with_streaks(camera: Camera3D) -> void:
	var at: Vector3 = camera.global_position
	var below: float = _surface_height(at.x, at.z)
	var height_m: float = maxf(at.y - (below if not is_nan(below) else 0.0), 1.0)
	if camera == _top_camera:
		_streaks.follow(camera, Vector3(at.x, 0.0, at.z), height_m, height_m, height_m)
		return
	var forward: Vector3 = -camera.global_basis.z
	var ahead_m: float = 3000.0
	if forward.y < -0.01:
		ahead_m = clampf(at.y / -forward.y, 200.0, 6000.0)
	var level: Vector3 = Vector3(forward.x, 0.0, forward.z)
	level = level.normalized() if level.length() > 0.01 else Vector3.FORWARD
	var half_size_m: float = ahead_m / 2.0
	_streaks.follow(camera, at + level * half_size_m, half_size_m, sqrt(height_m * ahead_m), height_m)


## The height of the surface (ground, or the water of a lake) at a game position, metres above the
## lake. Fine (2 m) in the shore band, coarse (50 m) elsewhere; NAN outside the wind pattern.
func _surface_height(x: float, z: float) -> float:
	if _shore.contains(x, z):
		return maxf(_shore.height_at(x, z), 0.0)
	return _ground.height_at(x, z)


## The point of the ground or water under a screen position, or Vector3.INF if there is none
## (the sky, or beyond the wind pattern). It walks along the line of sight until it is under the
## surface, then halves the last step until it is within a few centimetres.
func _pick(screen_point: Vector2) -> Vector3:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var from: Vector3 = camera.project_ray_origin(screen_point)
	var direction: Vector3 = camera.project_ray_normal(screen_point)
	var before_m: float = 0.0
	var along_m: float = 1.0
	while along_m < 40000.0:
		var point: Vector3 = from + direction * along_m
		var surface: float = _surface_height(point.x, point.z)
		if not is_nan(surface) and point.y <= surface:
			for i: int in 20:
				var middle_m: float = (before_m + along_m) / 2.0
				var middle: Vector3 = from + direction * middle_m
				if middle.y <= _surface_height(middle.x, middle.z):
					along_m = middle_m
				else:
					before_m = middle_m
			return from + direction * along_m
		before_m = along_m
		along_m += maxf(5.0, along_m * 0.002)
	return Vector3.INF


# ---------------------------------------------------------------- the clicked point

func _update_probe(now: WindMoment) -> void:
	_probe_marker.visible = _probe_point != Vector3.INF
	_probe_chart.visible = _probe_marker.visible
	if not _probe_marker.visible:
		return
	var camera: Camera3D = get_viewport().get_camera_3d()
	_probe_marker.position = _probe_point
	_probe_marker.scale = Vector3.ONE * camera.global_position.distance_to(_probe_point) * 0.06

	# Keep the steps of the last 10 minutes; work out the missing ones, newest first.
	var first: int = ceili((now.time_of_day_s - HISTORY_S) / HISTORY_STEP_S)
	var last: int = floori(now.time_of_day_s / HISTORY_STEP_S)
	for step: int in _history.keys():
		if step < first or step > last:
			_history.erase(step)
	var budget: int = HISTORY_PER_FRAME
	for step: int in range(last, first - 1, -1):
		if budget == 0:
			break
		if not _history.has(step):
			_history[step] = _probe_sample(_wind.moment(step * HISTORY_STEP_S))
			budget -= 1

	var times: PackedFloat32Array = PackedFloat32Array()
	var speeds_kt: PackedFloat32Array = PackedFloat32Array()
	var directions: PackedFloat32Array = PackedFloat32Array()
	for step: int in range(first, last + 1):
		if _history.has(step):
			times.append(step * HISTORY_STEP_S)
			speeds_kt.append(_history[step].x)
			directions.append(_history[step].y)
	var current: Vector2 = _probe_sample(now)
	times.append(now.time_of_day_s)
	speeds_kt.append(current.x)
	directions.append(current.y)
	var lv95: PackedFloat64Array = _config.game_to_lv95(_probe_point)
	var where: String = "on the water" if _probe_point.y < 0.5 else "on land, %.0f m above the lake" % _probe_point.y
	_probe_chart.show_history("LV95 %.0f / %.0f, %s" % [lv95[0], lv95[1], where],
		now.time_of_day_s - HISTORY_S, now.time_of_day_s, times, speeds_kt, directions)


## The wind at the clicked point at a moment: Vector2(knots, degrees it comes from).
func _probe_sample(moment: WindMoment) -> Vector2:
	var velocity: Vector3 = _wind.velocity_in(moment, _probe_point)
	return Vector2(velocity.length() / SimMath.KNOT_MS, MapWind.from_deg_of(velocity))


# ---------------------------------------------------------------- the screen

## The screen's panels are laid out for a window 720 pixels high, each keeping to its corner or
## edge. In a bigger window the window's content scale makes them all as much bigger (see _fit_ui()).
func _build_ui() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	_ui_layer = layer
	_panels = Control.new()
	_panels.name = "Panels"
	_panels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_panels)
	_panels.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_info = Label.new()
	_info.position = Vector2(12.0, 8.0)
	_info.add_theme_color_override("font_color", Color.WHITE)
	_info.add_theme_color_override("font_outline_color", Color.BLACK)
	_info.add_theme_constant_override("outline_size", 4)
	_panels.add_child(_info)

	# The speed legend at the top right.
	var legend: WindLegend = WindLegend.new()
	_panels.add_child(legend)
	legend.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	legend.offset_left = -48.0
	legend.offset_right = -12.0
	legend.offset_top = 90.0
	legend.offset_bottom = 425.0

	_probe_chart = WindProbeChart.new()
	_probe_chart.position = Vector2(12.0, 300.0)
	_probe_chart.size = Vector2(380.0, 330.0)
	_probe_chart.visible = false
	_panels.add_child(_probe_chart)

	# The clock along the bottom: pause, the speeds, the slider through the day, the time.
	var bar: PanelContainer = PanelContainer.new()
	var bar_style: StyleBoxFlat = CoursePanel.background()
	bar_style.content_margin_top = 6.0
	bar_style.content_margin_bottom = 6.0
	bar.add_theme_stylebox_override("panel", bar_style)
	_panels.add_child(bar)
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.offset_left = 12.0
	bar.offset_right = -12.0
	bar.offset_top = -56.0
	bar.offset_bottom = -12.0
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	bar.add_child(row)
	_pause_button = _button("Pause", row)
	_pause_button.pressed.connect(func() -> void: _set_paused(not _clock.paused))
	for i: int in WindClock.RATES.size():
		var rate_button: Button = _button("%d×" % WindClock.RATES[i], row)
		rate_button.toggle_mode = true
		rate_button.pressed.connect(_set_rate.bind(i))
		_rate_buttons.append(rate_button)
	_slider = HSlider.new()
	_slider.min_value = WindClock.DAY_START_S
	_slider.max_value = WindClock.DAY_END_S
	_slider.step = 60.0
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slider.focus_mode = Control.FOCUS_NONE
	_slider.value_changed.connect(_on_slider_moved)
	row.add_child(_slider)
	_time_label = Label.new()
	_time_label.custom_minimum_size = Vector2(430.0, 0.0)
	row.add_child(_time_label)
	_fit_ui()


## Makes the screen's panels and the course's drawing as big, compared to the window, as in a
## 1280 x 720 window: Godot's "canvas items" stretch, for this window and only while the viewer
## runs (the game's own screen settings stay as they are). The panels are laid out for a window
## 720 pixels high, a wider window gives them more room across, and Godot draws the text, lines
## and panels at the window's full resolution, so they stay sharp.
func _fit_ui() -> void:
	var window: Window = get_window()
	_window_before = [window.content_scale_mode, window.content_scale_aspect, window.content_scale_size]
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.content_scale_size = Vector2i(roundi(UI_HEIGHT_PX * 16.0 / 9.0), roundi(UI_HEIGHT_PX))


## Puts the window's scaling back as it was before the viewer.
func _exit_tree() -> void:
	if _window_before.size() == 3:
		var window: Window = get_window()
		window.content_scale_mode = _window_before[0]
		window.content_scale_aspect = _window_before[1]
		window.content_scale_size = _window_before[2]


func _button(text: String, parent: Control) -> Button:
	var button: Button = Button.new()
	button.text = text
	# The keyboard stays with the viewer (Space pauses, it doesn't press the last clicked button).
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(56.0, 0.0)
	parent.add_child(button)
	return button


func _update_ui() -> void:
	_pause_button.text = "Play" if _clock.paused else "Pause"
	for i: int in _rate_buttons.size():
		_rate_buttons[i].set_pressed_no_signal(not _clock.paused and _clock.rate == WindClock.RATES[i])
	_slider.set_value_no_signal(_clock.time_of_day_s)
	var lake_kt: float = _wind.day.lake_speed_ms(_clock.time_of_day_s) / SimMath.KNOT_MS
	_time_label.text = "%s  %s   Lake average: %.1f kt from %03.0f°" % [
		_clock.text(), "(paused)" if _clock.paused else "(%d×)" % _clock.rate,
		lake_kt, fposmod(_wind.lake_from_deg(_clock.time_of_day_s), 360.0)]
	var camera_name: String = "map camera" if _top_camera.current else "free camera"
	_info.text = "Wind viewer, Lake Silvaplana: the Maloja's average day, with gusts and lulls (from satellite photos), pulses and shifts\n" \
		+ "%s, streaks %.0f× real speed, %d fps\n" % [camera_name, _streaks.speed_up, Engine.get_frames_per_second()] \
		+ "Tab camera | click: wind at a point | Space pause, 1 2 3 speed | C colours, V streaks | [ ] streak speed | M course"


# ---------------------------------------------------------------- start options

func _read_command_line() -> void:
	var top: bool = true
	var at: Vector3 = Vector3.INF
	var look: Vector3 = Vector3.INF
	var course: String = ""
	var course_at: Vector3 = Vector3.INF
	var new_mark: Vector3 = Vector3.INF
	for arg: String in OS.get_cmdline_user_args():
		var value: String = arg.get_slice("=", 1)
		var numbers: PackedFloat64Array = value.split_floats(",")
		if arg == "--camera=free":
			top = false
		elif arg.begins_with("--at=") and numbers.size() == 3:
			at = _game_point(Vector3(numbers[0], numbers[1], numbers[2]))
		elif arg.begins_with("--look=") and numbers.size() == 3:
			look = _game_point(Vector3(numbers[0], numbers[1], numbers[2]))
		elif arg.begins_with("--top=") and numbers.size() == 3:
			var point: Vector3 = _game_point(Vector3(numbers[0], numbers[1], 0.0))
			_top_camera.look_down_at(Vector2(point.x, point.z), numbers[2])
		elif arg.begins_with("--time="):
			var hh_mm: PackedStringArray = value.split(":")
			_clock.set_time(hh_mm[0].to_float() * 3600.0 + (hh_mm[1].to_float() * 60.0 if hh_mm.size() > 1 else 0.0))
		elif arg.begins_with("--probe=") and numbers.size() == 2:
			var point: Vector3 = _game_point(Vector3(numbers[0], numbers[1], 0.0))
			point.y = _surface_height(point.x, point.z)
			_probe_point = point
			_history.clear()
		elif arg == "--colours=off":
			_speed_layer.visible = false
		elif arg == "--streaks=off":
			_streaks.visible = false
		elif arg == "--paused":
			_clock.paused = true
		elif arg.begins_with("--course="):
			course = value
		elif arg.begins_with("--course-at=") and numbers.size() == 2:
			course_at = _game_point(Vector3(numbers[0], numbers[1], 0.0))
		elif arg.begins_with("--course-new-mark=") and numbers.size() == 2:
			new_mark = _game_point(Vector3(numbers[0], numbers[1], 0.0))
	if at != Vector3.INF and look != Vector3.INF:
		_fly_camera.place(at, look)
	_use_top_camera(top)
	if course in CourseTemplates.ALL:
		_course_editor.place_template(course, Vector2(course_at.x, course_at.z) if course_at != Vector3.INF else _view_centre())
	elif not course.is_empty():
		# A saved course stays where it was saved.
		_course_editor.load_course(course)
	if new_mark != Vector3.INF:
		_course_editor.show_new_mark_preview(Vector2(new_mark.x, new_mark.z))


## --check-colours: the water's colour on the screen against the colour of the speed MapWind gives
## there, at points 40 pixels apart, clearly on the water (no shore within 10 m) and not under the
## screen's panels. Prints the largest difference and quits (exit code 1 if over 3 of 255).
func _check_colours() -> void:
	_clock.paused = true
	_streaks.visible = false
	_probe_point = Vector3.INF
	_course_editor.set_shown(false)
	for i: int in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var now: WindMoment = _wind.moment(_clock.time_of_day_s)
	var checked: int = 0
	var worst: float = 0.0
	var worst_at: String = ""
	for y: int in range(120, 640, 40):
		for x: int in range(20, 1200, 40):
			var point: Vector3 = _pick(Vector2(x + 0.5, y + 0.5))  # the middle of the pixel
			if point == Vector3.INF or not _clearly_water(point):
				continue
			var knots: float = _wind.velocity_in(now, point).length() / SimMath.KNOT_MS
			var expected: Color = WindColors.color_for(knots)
			var actual: Color = image.get_pixel(x, y)
			var difference: float = maxf(absf(expected.r - actual.r), maxf(absf(expected.g - actual.g), absf(expected.b - actual.b))) * 255.0
			checked += 1
			if difference > worst:
				worst = difference
				worst_at = "pixel (%d, %d), %.1f kt: expected %s, on screen %s" % [x, y, knots, expected.to_html(false), actual.to_html(false)]
	print("Colour check at %s: %d points on the water, the largest difference is %.1f of 255 (%s)" % [
		_clock.text(), checked, worst, worst_at])
	get_tree().quit(0 if checked > 0 and worst <= 3.0 else 1)


func _clearly_water(point: Vector3) -> bool:
	for offset: Vector2 in [Vector2.ZERO, Vector2(10.0, 0.0), Vector2(-10.0, 0.0), Vector2(0.0, 10.0), Vector2(0.0, -10.0)]:
		var x: float = point.x + offset.x
		var z: float = point.z + offset.y
		if not _shore.contains(x, z) or _shore.height_at(x, z) > -0.5:
			return false
	return true


## A point given as LV95 east, north and metres above the lake, as a game position.
func _game_point(lv95: Vector3) -> Vector3:
	return _config.lv95_to_game(lv95.x, lv95.y, lv95.z + _config.lake_level_m)
