extends GutTest
## The sailing scene and the start menu with the player's settings (GameSettings): the
## scene builds its simulation from them, pausing stops the physics, and the start menu
## hands the board to the player.

var _saved_values: SettingsValues
var _saved_path: String


func before_each() -> void:
	# The tests use their own settings and never write the player's settings file.
	_saved_values = GameSettings.values
	_saved_path = GameSettings.path
	GameSettings.values = SettingsValues.new()
	GameSettings.path = ""


func after_each() -> void:
	get_tree().paused = false
	GameSettings.values = _saved_values
	GameSettings.path = _saved_path


func test_the_sailing_scene_sails_in_the_settings_wind_and_sea() -> void:
	GameSettings.values.wind_speed_kt = 24.0
	GameSettings.values.wind_from_deg = 0.0
	GameSettings.values.wave_preset = SettingsValues.WavePreset.STRONG_CHOP
	GameSettings.values.start_heading_deg = 270.0
	var scene: SailingScene = (load("res://main.tscn") as PackedScene).instantiate()
	add_child_autofree(scene)
	var windsurfer: WindsurferNode = scene.get_node("Windsurfer")
	assert_almost_eq(windsurfer.sim.wind.config.speed_kt, 24.0, 1e-6)
	assert_almost_eq(windsurfer.sim.wind_config.from_bearing_deg, 0.0, 1e-6)
	assert_true(windsurfer.sim.has_waves())
	assert_almost_eq((windsurfer.sim.water as WaveField).total_amplitude_m(), 0.182, 1e-5, "the strong chop")
	assert_almost_eq(windsurfer.sim.telemetry.heading_deg, 270.0, 0.5, "the start heading")
	assert_almost_eq(GameSettings.values.wind_speed_kt, 24.0, 1e-6)


func test_pausing_stops_the_physics_but_not_the_menus() -> void:
	var scene: SailingScene = (load("res://main.tscn") as PackedScene).instantiate()
	add_child_autofree(scene)
	var windsurfer: WindsurferNode = scene.get_node("Windsurfer")
	var pause_menu: PauseMenu = scene.get_node("PauseMenu")
	get_tree().paused = true
	assert_false(windsurfer.can_process(), "the windsurfer stops")
	assert_true(pause_menu.can_process(), "the pause menu keeps working")
	assert_true(scene.can_process(), "the scene keeps reading keys")
	get_tree().paused = false


func test_the_wind_and_the_sea_change_live_while_sailing() -> void:
	var scene: SailingScene = (load("res://main.tscn") as PackedScene).instantiate()
	add_child_autofree(scene)
	var windsurfer: WindsurferNode = scene.get_node("Windsurfer")
	GameSettings.values.wind_speed_kt = 30.0
	GameSettings.values.wind_from_deg = 180.0
	GameSettings.values.gusts_enabled = true
	GameSettings.values.wave_preset = SettingsValues.WavePreset.MEDIUM_CHOP
	scene.apply_settings_live()
	assert_almost_eq(windsurfer.sim.wind.config.speed_kt, 30.0, 1e-6, "the wind at once")
	assert_true(windsurfer.sim.wind.config.gusts_enabled)
	var water: WaveField = windsurfer.sim.water as WaveField
	assert_almost_eq(water.total_amplitude_m(), 0.08 + 0.04 + 0.015 + 0.006, 1e-5, "the medium chop at once, no restart needed")
	# The chop lines up with the wind you set: from the South, its 7 m wave (the file's -28
	# from downwind at the default spread) travels toward bearing 360 - 28 x spread.
	var expected: Vector2 = WaveField.direction_for_bearing(360.0 - 28.0 * SettingsValues.WAVE_SPREAD_DEFAULT)
	assert_almost_eq(water.dir_x[1], expected.x, 1e-6, "the waves follow the new wind direction")
	assert_almost_eq(water.dir_z[1], expected.y, 1e-6)
	assert_eq(scene.get_node("Ocean").get_child_count(), 2, "the old water meshes are gone")
	# Nothing left waiting for a restart (the pause menu's note).
	scene.get_node("PauseMenu").restart_requested.emit()
	assert_almost_eq((windsurfer.sim.water as WaveField).dir_x[1], expected.x, 1e-6, "the same sea after a restart")


## The route a player takes: Esc, Settings, the "Wind from" slider on the Wind tab, Back.
func test_a_wind_direction_set_in_the_pause_menu_turns_the_waves_at_once() -> void:
	var scene: SailingScene = (load("res://main.tscn") as PackedScene).instantiate()
	add_child_autofree(scene)
	var windsurfer: WindsurferNode = scene.get_node("Windsurfer")
	var pause_menu: PauseMenu = scene.get_node("PauseMenu")
	pause_menu.open("")
	pause_menu.open_page("settings")
	var settings: SettingsMenu = pause_menu.find_child("Settings", true, false) as SettingsMenu
	assert_not_null(settings, "the settings page of the pause menu")
	var slider: HSlider = _slider_after_label(settings.find_child("WindRows", true, false) as GridContainer, "Wind from")
	assert_not_null(slider, "the Wind from slider")
	slider.value = 90.0
	settings.close()
	assert_almost_eq(windsurfer.sim.wind.config.from_bearing_deg, 90.0, 1e-6, "the wind at once")
	var water: WaveField = windsurfer.sim.water as WaveField
	var expected: Vector2 = WaveField.direction_for_bearing(270.0 - 28.0 * SettingsValues.WAVE_SPREAD_DEFAULT)
	assert_almost_eq(water.dir_x[1], expected.x, 1e-6, "the chop runs downwind of the East wind, at once")
	assert_almost_eq(water.dir_z[1], expected.y, 1e-6)
	pause_menu.close()


## The chop set to a compass bearing in the settings stays there when the wind turns.
func test_a_chop_from_a_bearing_stays_when_the_player_turns_the_wind() -> void:
	GameSettings.values.chop_follows_wind = false
	GameSettings.values.chop_from_deg = 0.0  # from the North: it travels South
	GameSettings.values.wave_spread = 0.0
	var scene: SailingScene = (load("res://main.tscn") as PackedScene).instantiate()
	add_child_autofree(scene)
	var windsurfer: WindsurferNode = scene.get_node("Windsurfer")
	var water: WaveField = windsurfer.sim.water as WaveField
	assert_almost_eq(water.dir_z[1], 1.0, 1e-6, "the chop travels South under a West wind")
	GameSettings.values.wind_from_deg = 90.0
	scene.apply_settings_live()
	water = windsurfer.sim.water as WaveField
	assert_almost_eq(water.dir_z[1], 1.0, 1e-6, "and still South under an East wind")
	assert_almost_eq(water.dir_x[1], 0.0, 1e-6)


## The slider in the row whose name is `title` (the rows are a label, a control, a text).
func _slider_after_label(grid: GridContainer, title: String) -> HSlider:
	var found: bool = false
	for child: Node in grid.get_children():
		if child is Label and (child as Label).text == title:
			found = true
		elif found and child is HSlider:
			return child as HSlider
	return null


func test_in_a_race_a_new_sea_waits_for_the_restart() -> void:
	RaceSetup.pending = RaceSetup.race("t1_loop")
	var scene: SailingScene = (load("res://main.tscn") as PackedScene).instantiate()
	add_child_autofree(scene)
	var windsurfer: WindsurferNode = scene.get_node("Windsurfer")
	var amplitude_before: float = (windsurfer.sim.water as WaveField).total_amplitude_m()
	GameSettings.values.wave_preset = SettingsValues.WavePreset.MEDIUM_CHOP
	scene.apply_settings_live()
	assert_almost_eq((windsurfer.sim.water as WaveField).total_amplitude_m(), amplitude_before, 1e-6, "the fleet's sea stays until R")
	scene.get_node("PauseMenu").restart_requested.emit()
	assert_almost_eq((windsurfer.sim.water as WaveField).total_amplitude_m(), 0.08 + 0.04 + 0.015 + 0.006, 1e-5, "the medium chop after it")


func test_the_start_menu_hands_the_board_to_the_player() -> void:
	var menu: Node = (load("res://ui/start_menu.tscn") as PackedScene).instantiate()
	add_child_autofree(menu)
	var windsurfer: WindsurferNode = menu.get_node("Sailing/Windsurfer")
	var hud: Hud = menu.get_node("Sailing/HUD")
	assert_true(windsurfer.use_autopilot, "the autopilot sails behind the menu")
	assert_false(hud.visible, "no HUD behind the menu")
	(menu.get_node("%OpenWaterButton") as Button).pressed.emit()
	assert_false(windsurfer.use_autopilot, "the player sails")
	assert_true(hud.visible)
	assert_eq(GameSettings.values.last_play_option, 0, "the choice is remembered")


func test_every_settings_tab_can_be_walked_with_the_keyboard() -> void:
	# From the tabs, Down goes through every row to the buttons at the bottom (the way a
	# keyboard or gamepad player moves), on each tab.
	var settings: SettingsMenu = (load("res://ui/settings_menu.tscn") as PackedScene).instantiate()
	add_child_autofree(settings)
	settings.open()
	var tabs: TabContainer = settings.get_node("%Tabs")
	var reset_button: Button = settings.get_node("%ResetButton")
	for tab: int in tabs.get_tab_count():
		tabs.current_tab = tab
		await wait_frames(2)
		var at: Control = tabs.get_tab_bar()
		var steps: int = 0
		while at != null and at != reset_button and steps < 20:
			at = at.find_valid_focus_neighbor(SIDE_BOTTOM)
			steps += 1
		assert_eq(at, reset_button, "tab %s: Down reaches the buttons" % tabs.get_tab_title(tab))
		assert_gt(steps, 1, "and passes the rows on the way")
