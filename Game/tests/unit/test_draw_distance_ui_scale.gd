extends GutTest
## Two settings of Settings > Graphics (Max, 6 November 2026; Documentation/reports/ui/
## small_fixes_6nov_evening.md): the Draw distance (DrawDistance: the camera's far plane, the far
## meshes' detail, the open water's waves, the boards drawn with full care), whose Normal step is what
## the game drew before; and the UI scale (Hud.ui_scale), the in-game screen bigger or smaller, every
## part still inside the window.

var _saved_values: SettingsValues
var _saved_path: String
var _window_before: Vector2i = Vector2i.ZERO


func before_each() -> void:
	# The tests use their own settings and never write the player's settings file.
	_saved_values = GameSettings.values
	_saved_path = GameSettings.path
	GameSettings.values = SettingsValues.new()
	GameSettings.path = ""
	DrawDistance.level = DrawDistance.Level.NORMAL
	_window_before = get_window().size
	get_window().size = Vector2i(1280, 720)


func after_each() -> void:
	GameSettings.values = _saved_values
	GameSettings.path = _saved_path
	DrawDistance.level = DrawDistance.clamp_level(GameSettings.values.draw_distance)
	get_window().size = _window_before


# --- The draw distance ------------------------------------------------------------------------

func test_normal_is_what_the_game_drew_before() -> void:
	var values: SettingsValues = SettingsValues.new()
	assert_eq(values.draw_distance, DrawDistance.Level.NORMAL, "the default")
	assert_eq(DrawDistance.camera_far_m(DrawDistance.Level.NORMAL), 35000.0, "the camera's 35 km")
	assert_eq(DrawDistance.lod_threshold_px(DrawDistance.Level.NORMAL), 1.0, "Godot's own mesh detail")
	assert_eq(DrawDistance.open_waves_m(DrawDistance.Level.NORMAL), (autofree(OceanNode.new()) as OceanNode).near_size_m, "the water's 400 m")
	assert_eq(DrawDistance.full_detail_m(DrawDistance.Level.NORMAL), RaceRunner.FAR_DETAIL_M, "the boards' 300 m")
	for step: int in DrawDistance.Level.size() - 1:
		assert_lt(DrawDistance.camera_far_m(step), DrawDistance.camera_far_m(step + 1), "each step draws farther")
		assert_gt(DrawDistance.lod_threshold_px(step), DrawDistance.lod_threshold_px(step + 1))
		assert_lt(DrawDistance.open_waves_m(step), DrawDistance.open_waves_m(step + 1))
		assert_lt(DrawDistance.full_detail_m(step), DrawDistance.full_detail_m(step + 1))


func test_the_steps_from_words_and_numbers_and_the_file() -> void:
	assert_eq(DrawDistance.level_of("near"), DrawDistance.Level.NEAR)
	assert_eq(DrawDistance.level_of("Far"), DrawDistance.Level.FAR)
	assert_eq(DrawDistance.level_of("very_far"), DrawDistance.Level.VERY_FAR)
	assert_eq(DrawDistance.level_of("very far"), DrawDistance.Level.VERY_FAR)
	assert_eq(DrawDistance.level_of("3"), DrawDistance.Level.VERY_FAR)
	assert_eq(DrawDistance.level_of("9"), DrawDistance.Level.VERY_FAR, "clamped")
	assert_eq(DrawDistance.level_of("nonsense"), DrawDistance.Level.NORMAL)
	var values: SettingsValues = SettingsValues.new()
	values.draw_distance = DrawDistance.Level.FAR
	values.ui_scale = 1.25
	var file: ConfigFile = ConfigFile.new()
	values.write_to(file)
	var read: SettingsValues = SettingsValues.new()
	read.read_from(file)
	assert_eq(read.draw_distance, DrawDistance.Level.FAR)
	assert_almost_eq(read.ui_scale, 1.25, 1e-6)
	file.set_value("graphics", "draw_distance", 7)
	file.set_value("graphics", "ui_scale", 4.0)
	read.read_from(file)
	assert_eq(read.draw_distance, DrawDistance.Level.VERY_FAR, "a hand-edited file is clamped")
	assert_eq(read.ui_scale, SettingsValues.UI_SCALE_MAX)
	# A settings file from before has no such keys: the defaults, nothing changes.
	var old: ConfigFile = ConfigFile.new()
	old.set_value("graphics", "msaa", 1)
	var from_old: SettingsValues = SettingsValues.new()
	from_old.read_from(old)
	assert_eq(from_old.draw_distance, DrawDistance.Level.NORMAL)
	assert_eq(from_old.ui_scale, 1.0)


func test_the_camera_and_the_open_water_follow_the_setting_while_sailing() -> void:
	var scene: SailingScene = (load("res://main.tscn") as PackedScene).instantiate()
	add_child_autofree(scene)
	var rig: CameraRig = scene.get_node("CameraRig")
	var ocean: OceanNode = scene.get_node("Ocean")
	await wait_process_frames(2)
	assert_eq(rig.camera.far, 35000.0, "Normal: the far plane as before")
	assert_eq(ocean.near_size_m, 400.0, "and the waves' mesh")
	GameSettings.values.draw_distance = DrawDistance.Level.VERY_FAR
	GameSettings.notify_changed()
	scene.apply_settings_live()
	await wait_process_frames(2)
	assert_eq(rig.camera.far, DrawDistance.camera_far_m(DrawDistance.Level.VERY_FAR), "the far plane at once")
	assert_eq(ocean.near_size_m, DrawDistance.open_waves_m(DrawDistance.Level.VERY_FAR), "the waves' mesh built again")
	var near: MeshInstance3D = ocean.get_node("NearWater")
	assert_almost_eq((near.mesh as PlaneMesh).size.x, 800.0, 1e-3, "800 m across")


func test_the_settings_graphics_tab_has_both_rows() -> void:
	var settings: SettingsMenu = (load("res://ui/settings_menu.tscn") as PackedScene).instantiate()
	add_child_autofree(settings)
	settings.open()
	var rows: GridContainer = settings.get_node("%GraphicsRows")
	var list: OptionButton = null
	var slider: HSlider = null
	var children: Array[Node] = rows.get_children()
	for i: int in children.size():
		var label: Label = children[i] as Label
		if label != null and label.text == "Draw distance":
			list = children[i + 1] as OptionButton
		elif label != null and label.text == "UI scale":
			slider = children[i + 1] as HSlider
	assert_not_null(list, "a row called Draw distance with a list")
	assert_not_null(slider, "a row called UI scale with a slider")
	if list == null or slider == null:
		return
	assert_eq(list.item_count, 4)
	assert_eq(list.get_item_text(list.selected), "Normal")
	list.select(2)
	list.item_selected.emit(2)
	assert_eq(GameSettings.values.draw_distance, DrawDistance.Level.FAR, "into the settings")
	assert_eq(DrawDistance.level, DrawDistance.Level.FAR, "and in use at once")
	slider.value = 1.2
	assert_almost_eq(GameSettings.values.ui_scale, 1.2, 1e-6)
	await wait_process_frames(1)  # the settings page built its rows twice (open()): the first ones go


# --- The UI scale -----------------------------------------------------------------------------

## A racing HUD at a UI scale, as RaceRunner makes it (the race's block through add_part()), with the
## body gauge beside the push gauge (the widest bottom row).
func _racing_hud(ui_scale: float) -> Array:
	GameSettings.values.ui_scale = ui_scale
	var hud: Hud = Hud.new()
	add_child_autofree(hud)
	hud.show_course(RaceCourses.t1_loop(270.0, Vector2(0.0, -150.0)))
	var race_hud: RaceHud = RaceHud.new()
	hud.add_part(race_hud)
	hud.set_race_mode(true)
	var controller: PlayerController = PlayerController.new()
	controller.push_level = 0.75
	controller.body = MouseBody.new()
	hud.update_from(Telemetry.new(), controller, "Follow", false)
	return [hud, race_hud]


## A part's rectangle on the window: the layer draws the screen ui_scale times bigger.
func _on_window(hud: Hud, part: Control) -> Rect2:
	var rect: Rect2 = part.get_global_rect()
	return Rect2(rect.position * hud.ui_scale, rect.size * hud.ui_scale)


## Above 100 % the screen grows only as much as fits: at 1280 x 720 (16:9) about 108 %, in Max's
## 3137 x 1263 window (1788 x 720 of the layout's pixels) about 129 %; below 100 % always.
func test_the_ui_scale_stops_where_the_screen_would_not_fit() -> void:
	assert_almost_eq(Hud.ui_scale_for(1.5, Vector2(1280.0, 720.0)), 1280.0 / Hud.SMALLEST_SCREEN.x, 1e-4)
	assert_almost_eq(Hud.ui_scale_for(1.5, Vector2(1788.0, 720.0)), 720.0 / Hud.SMALLEST_SCREEN.y, 1e-4)
	assert_almost_eq(Hud.ui_scale_for(1.2, Vector2(1788.0, 720.0)), 1.2, 1e-6, "what fits is given")
	assert_almost_eq(Hud.ui_scale_for(0.75, Vector2(1280.0, 720.0)), 0.75, 1e-6, "smaller always")
	assert_almost_eq(Hud.ui_scale_for(1.5, Vector2(900.0, 720.0)), 1.0, 1e-6, "never below 100 % for a big setting")
	assert_almost_eq(Hud.ui_scale_for(9.0, Vector2(4000.0, 2000.0)), SettingsValues.UI_SCALE_MAX, 1e-6)


func test_every_part_stays_inside_the_window_and_apart_at_every_ui_scale() -> void:
	for window_size: Vector2i in [Vector2i(1280, 720), Vector2i(1788, 720)]:
		get_window().size = window_size
		var window: Rect2 = get_viewport().get_visible_rect()
		for ui_scale: float in [0.75, 1.0, 1.25, 1.5]:
			var made: Array = _racing_hud(ui_scale)
			var hud: Hud = made[0]
			var race_hud: RaceHud = made[1]
			# The standings of a big fleet: as many lines as fit above the mini-map (RaceHud._fill_fleet()).
			var rows: int = race_hud.fleet_room_rows()
			for cell: int in race_hud._fleet_cells.size():
				race_hud._fleet_cells[cell].text = "x"
				race_hud._fleet_cells[cell].visible = cell / 4 < rows
			race_hud._fleet_card.show()
			await wait_process_frames(2)
			var used: float = Hud.ui_scale_for(ui_scale, window.size)
			assert_almost_eq(hud.ui_scale, used, 1e-6)
			assert_eq(hud.scale, Vector2(used, used), "the layer drawn that much bigger")
			var parts: Dictionary[String, Rect2] = {"race card": _on_window(hud, race_hud._card), "standings": _on_window(hud, race_hud._fleet_card),
				"speed card": _on_window(hud, race_hud._speed_card), "gauges": _on_window(hud, hud._gauges), "mini-map": _on_window(hud, hud._mini_map),
				"compass": _on_window(hud, hud._rose)}
			var at: String = "%s at %.0f %% (%.0f %% used)" % [window_size, ui_scale * 100.0, used * 100.0]
			for name: String in parts:
				assert_true(window.grow(1.0).encloses(parts[name]), "%s inside the window, %s: %s" % [name, at, parts[name]])
			var names: Array[String] = parts.keys()
			for i: int in names.size():
				for j: int in range(i + 1, names.size()):
					assert_false(parts[names[i]].intersects(parts[names[j]]), "%s and %s apart, %s" % [names[i], names[j], at])
			assert_lte(hud._hints.get_combined_minimum_size().x, hud.screen_size().x - 2.0 * Hud.MARGIN, "the keys fit across, " + at)
			assert_almost_eq(parts["gauges"].size.y, PushGauge.GAUGE_SIZE.y * used, 1.0, "the gauge as much bigger, " + at)
			hud.queue_free()
			await wait_process_frames(1)


func test_the_ui_scale_changes_at_once_from_the_settings() -> void:
	get_window().size = Vector2i(1788, 720)  # Max's 3137 x 1263 window in the layout's pixels
	var made: Array = _racing_hud(1.0)
	var hud: Hud = made[0]
	await wait_process_frames(1)
	var compass_before: Rect2 = _on_window(hud, hud._rose)
	GameSettings.values.ui_scale = 1.25
	GameSettings.notify_changed()
	await wait_process_frames(2)
	assert_almost_eq(hud.ui_scale, 1.25, 1e-6)
	var compass: Rect2 = _on_window(hud, hud._rose)
	assert_almost_eq(compass.size.x, compass_before.size.x * 1.25, 0.5, "the compass a quarter bigger")
	var window: Rect2 = get_viewport().get_visible_rect()
	assert_almost_eq(compass.end.x, window.end.x - Hud.ROSE_GAP * 1.25, 0.5, "still at the window's right edge, its gap grown too")
