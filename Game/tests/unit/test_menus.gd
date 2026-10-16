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


func test_the_wind_changes_live_and_the_waves_wait_for_a_restart() -> void:
	var scene: SailingScene = (load("res://main.tscn") as PackedScene).instantiate()
	add_child_autofree(scene)
	var windsurfer: WindsurferNode = scene.get_node("Windsurfer")
	var amplitude_before: float = (windsurfer.sim.water as WaveField).total_amplitude_m()
	GameSettings.values.wind_speed_kt = 30.0
	GameSettings.values.gusts_enabled = true
	GameSettings.values.wave_preset = SettingsValues.WavePreset.MEDIUM_CHOP
	scene.apply_settings_live()
	assert_almost_eq(windsurfer.sim.wind.config.speed_kt, 30.0, 1e-6, "the wind at once")
	assert_true(windsurfer.sim.wind.config.gusts_enabled)
	assert_almost_eq((windsurfer.sim.water as WaveField).total_amplitude_m(), amplitude_before, 1e-6, "the old waves until the restart")
	scene.get_node("PauseMenu").restart_requested.emit()
	assert_almost_eq((windsurfer.sim.water as WaveField).total_amplitude_m(), 0.08 + 0.04 + 0.015 + 0.006, 1e-5, "the medium chop after it")
	assert_eq(scene.get_node("Ocean").get_child_count(), 2, "the old water meshes are gone")


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
