extends GutTest
## The player's settings (ui/settings_values.gd): the defaults, saving and loading them, and
## the wind and wave configs the sailing scene builds from them.

const TOL: float = 1e-6
const TEMP_PATH: String = "user://test_settings_tmp.cfg"


func after_each() -> void:
	if FileAccess.file_exists(TEMP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH))


func test_defaults_match_the_default_wind_file() -> void:
	var settings: SettingsValues = SettingsValues.new()
	var wind: WindConfig = load("res://config/wind_default.tres")
	assert_almost_eq(settings.wind_speed_kt, wind.speed_kt, TOL)
	assert_almost_eq(settings.wind_from_deg, wind.from_bearing_deg, TOL)
	assert_eq(settings.gusts_enabled, wind.gusts_enabled)
	assert_eq(settings.shifts_enabled, wind.shifts_enabled)
	assert_eq(settings.wave_preset, SettingsValues.WavePreset.SWELL, "the default sea is the default wave file")
	assert_true(settings.waves_enabled)
	assert_almost_eq(settings.wave_height_scale, 1.0, TOL)
	assert_true(settings.swell_follows_wind, "the default file's swell follows the wind")
	assert_almost_eq(settings.swell_height_scale, 1.0, TOL)
	assert_almost_eq(settings.chop_offset_deg, 0.0, TOL)
	assert_almost_eq(settings.fetch_km, 3.0, TOL)
	assert_almost_eq(settings.water_depth_m, SettingsValues.DEPTH_DEEP_M, TOL, "deep water")
	assert_eq(settings.control_mode, PlayerController.Mode.BEGINNER)
	assert_true(settings.auto_sheet)
	assert_almost_eq(settings.start_heading_deg, 180.0, TOL)
	assert_false(settings.fullscreen)


func test_reset_to_defaults_undoes_changes() -> void:
	var settings: SettingsValues = SettingsValues.new()
	settings.wind_speed_kt = 30.0
	settings.wave_preset = SettingsValues.WavePreset.STRONG_CHOP
	settings.master_volume = 0.1
	settings.reset_to_defaults()
	assert_almost_eq(settings.wind_speed_kt, 18.0, TOL)
	assert_eq(settings.wave_preset, SettingsValues.WavePreset.SWELL)
	assert_almost_eq(settings.master_volume, 1.0, TOL)


func test_round_trip_through_a_file() -> void:
	var saved: SettingsValues = SettingsValues.new()
	saved.wind_speed_kt = 24.0
	saved.wind_from_deg = 0.0
	saved.gusts_enabled = true
	saved.gust_intensity = 0.3
	saved.gust_period_s = 12.0
	saved.shifts_enabled = true
	saved.max_shift_deg = 20.0
	saved.shift_period_s = 90.0
	saved.wave_preset = SettingsValues.WavePreset.STRONG_CHOP
	saved.wave_height_scale = 1.5
	saved.swell_follows_wind = false
	saved.swell_from_deg = 0.0
	saved.swell_height_scale = 2.5
	saved.chop_offset_deg = -30.0
	saved.fetch_km = 1.5
	saved.water_depth_m = 2.0
	saved.control_mode = PlayerController.Mode.ADVANCED
	saved.auto_sheet = false
	saved.start_heading_deg = 90.0
	saved.start_camera = CameraRig.Mode.ORBIT
	saved.show_hud_panel = false
	saved.fullscreen = true
	saved.vsync = false
	saved.msaa = 2
	saved.render_scale = 0.75
	saved.shadow_quality = 1
	saved.max_fps = 60
	saved.master_volume = 0.4
	saved.wind_volume = 0.3
	saved.water_volume = 0.6
	saved.sail_volume = 0.0
	saved.last_play_option = 2
	assert_eq(saved.save_file(TEMP_PATH), OK)

	var loaded: SettingsValues = SettingsValues.new()
	assert_eq(loaded.load_file(TEMP_PATH), OK)
	assert_almost_eq(loaded.wind_speed_kt, 24.0, TOL)
	assert_almost_eq(loaded.wind_from_deg, 0.0, TOL)
	assert_true(loaded.gusts_enabled)
	assert_almost_eq(loaded.gust_intensity, 0.3, TOL)
	assert_almost_eq(loaded.gust_period_s, 12.0, TOL)
	assert_true(loaded.shifts_enabled)
	assert_almost_eq(loaded.max_shift_deg, 20.0, TOL)
	assert_almost_eq(loaded.shift_period_s, 90.0, TOL)
	assert_eq(loaded.wave_preset, SettingsValues.WavePreset.STRONG_CHOP)
	assert_almost_eq(loaded.wave_height_scale, 1.5, TOL)
	assert_false(loaded.swell_follows_wind)
	assert_almost_eq(loaded.swell_from_deg, 0.0, TOL)
	assert_almost_eq(loaded.swell_height_scale, 2.5, TOL)
	assert_almost_eq(loaded.chop_offset_deg, -30.0, TOL)
	assert_almost_eq(loaded.fetch_km, 1.5, TOL)
	assert_almost_eq(loaded.water_depth_m, 2.0, TOL)
	assert_eq(loaded.control_mode, PlayerController.Mode.ADVANCED)
	assert_false(loaded.auto_sheet)
	assert_almost_eq(loaded.start_heading_deg, 90.0, TOL)
	assert_eq(loaded.start_camera, CameraRig.Mode.ORBIT)
	assert_false(loaded.show_hud_panel)
	assert_true(loaded.fullscreen)
	assert_false(loaded.vsync)
	assert_eq(loaded.msaa, 2)
	assert_almost_eq(loaded.render_scale, 0.75, TOL)
	assert_eq(loaded.shadow_quality, 1)
	assert_eq(loaded.max_fps, 60)
	assert_almost_eq(loaded.master_volume, 0.4, TOL)
	assert_almost_eq(loaded.wind_volume, 0.3, TOL)
	assert_almost_eq(loaded.water_volume, 0.6, TOL)
	assert_almost_eq(loaded.sail_volume, 0.0, TOL)
	assert_eq(loaded.last_play_option, 2)


func test_a_missing_file_keeps_the_defaults() -> void:
	var settings: SettingsValues = SettingsValues.new()
	assert_eq(settings.load_file("user://no_such_settings_file.cfg"), ERR_FILE_NOT_FOUND)
	assert_almost_eq(settings.wind_speed_kt, 18.0, TOL)


func test_a_broken_file_is_clamped_and_falls_back() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value("wind", "speed_kt", 500.0)
	config.set_value("wind", "from_deg", -90.0)
	config.set_value("wind", "gusts_enabled", "yes please")
	config.set_value("waves", "preset", 99)
	config.set_value("waves", "chop_offset_deg", 400.0)
	config.set_value("waves", "fetch_km", 0.0)
	config.set_value("waves", "swell_from_deg", -45.0)
	var settings: SettingsValues = SettingsValues.new()
	settings.read_from(config)
	assert_almost_eq(settings.wind_speed_kt, SettingsValues.WIND_SPEED_MAX_KT, TOL, "clamped to the slider's range")
	assert_almost_eq(settings.wind_from_deg, 270.0, TOL, "-90 is 270")
	assert_false(settings.gusts_enabled, "not a bool: the old value stays")
	assert_eq(settings.wave_preset, SettingsValues.WavePreset.FROM_WIND, "clamped to the last preset")
	assert_almost_eq(settings.chop_offset_deg, SettingsValues.CHOP_OFFSET_MAX_DEG, TOL)
	assert_almost_eq(settings.fetch_km, SettingsValues.FETCH_MIN_KM, TOL)
	assert_almost_eq(settings.swell_from_deg, 315.0, TOL, "-45 is 315")


func test_wind_config_from_the_settings() -> void:
	var settings: SettingsValues = SettingsValues.new()
	settings.wind_speed_kt = 24.0
	settings.wind_from_deg = 0.0
	settings.gusts_enabled = true
	settings.gust_intensity = 0.3
	settings.gust_period_s = 12.0
	var wind: WindConfig = settings.build_wind_config()
	assert_almost_eq(wind.speed_kt, 24.0, TOL)
	assert_almost_eq(wind.from_bearing_deg, 0.0, TOL)
	assert_true(wind.gusts_enabled)
	assert_almost_eq(wind.gust_intensity, 0.3, TOL)
	assert_almost_eq(wind.gust_period_s, 12.0, TOL)
	assert_true(wind.height_gradient_enabled, "the rest comes from the default file")
	var default_wind: WindConfig = load("res://config/wind_default.tres")
	assert_almost_eq(default_wind.speed_kt, 18.0, TOL, "the default file is not changed")
	assert_ne(wind, default_wind, "a copy, not the shared default")
	# And the wind field built from it blows 24 kt from the North (towards the South, +Z).
	# (The gust sum is zero at time 0, so the field starts at the base speed.)
	var field: WindField = WindField.new(wind)
	assert_almost_eq(field.current_speed_ms, 24.0 * SimMath.KNOT_MS, 1e-4)
	assert_gt(field.velocity_at(Vector3(0.0, 10.0, 0.0)).z, 0.0, "a North wind blows South")


func test_swell_preset_is_the_default_wave_file() -> void:
	var settings: SettingsValues = SettingsValues.new()
	var waves: WaveSetConfig = settings.build_wave_set_config()
	var default_waves: WaveSetConfig = load("res://config/waves_default.tres")
	assert_true(waves.enable_waves)
	assert_eq(waves.waves.size(), default_waves.waves.size())
	for i: int in waves.waves.size():
		assert_almost_eq(waves.waves[i].amplitude_m, default_waves.waves[i].amplitude_m, TOL)
		assert_almost_eq(waves.waves[i].steepness, default_waves.waves[i].steepness, TOL)
		assert_almost_eq(waves.waves[i].wavelength_m, default_waves.waves[i].wavelength_m, TOL)


func test_chop_presets_have_the_session_37_numbers() -> void:
	var settings: SettingsValues = SettingsValues.new()
	settings.wave_preset = SettingsValues.WavePreset.MEDIUM_CHOP
	var medium: WaveSetConfig = settings.build_wave_set_config()
	_assert_wave(medium, 0, 0.08, 0.036, "the swell stays")
	_assert_wave(medium, 1, 0.04, 0.036, "medium: long chop")
	_assert_wave(medium, 2, 0.015, 0.027, "medium: chop")
	_assert_wave(medium, 3, 0.006, 0.021, "medium: ripple")

	settings.wave_preset = SettingsValues.WavePreset.STRONG_CHOP
	var strong: WaveSetConfig = settings.build_wave_set_config()
	_assert_wave(strong, 0, 0.08, 0.036, "the swell stays")
	_assert_wave(strong, 1, 0.06, 0.054, "strong: long chop")
	_assert_wave(strong, 2, 0.03, 0.054, "strong: chop")
	_assert_wave(strong, 3, 0.012, 0.042, "strong: ripple")
	assert_eq(strong.validate().size(), 0, "a valid wave set")

	var default_waves: WaveSetConfig = load("res://config/waves_default.tres")
	assert_almost_eq(default_waves.waves[1].amplitude_m, 0.02, TOL, "the default file's waves are not changed")


func test_flat_and_off_give_flat_water() -> void:
	var settings: SettingsValues = SettingsValues.new()
	settings.wave_preset = SettingsValues.WavePreset.FLAT
	assert_false(settings.build_wave_set_config().enable_waves)
	settings.wave_preset = SettingsValues.WavePreset.SWELL
	settings.waves_enabled = false
	assert_false(settings.build_wave_set_config().enable_waves)


func test_height_scale_scales_amplitude_and_steepness() -> void:
	var settings: SettingsValues = SettingsValues.new()
	settings.wave_preset = SettingsValues.WavePreset.STRONG_CHOP
	settings.wave_height_scale = 2.0
	var waves: WaveSetConfig = settings.build_wave_set_config()
	_assert_wave(waves, 0, 0.16, 0.072, "swell doubled")
	_assert_wave(waves, 1, 0.12, 0.108, "long chop doubled")
	assert_lt(waves.total_steepness(), 1.0, "the crests do not fold over")


func test_the_simulation_sails_in_the_chosen_wind_and_sea() -> void:
	# What the sailing scene does with the settings: 24 kt from the North on strong chop.
	var settings: SettingsValues = SettingsValues.new()
	settings.wind_speed_kt = 24.0
	settings.wind_from_deg = 0.0
	settings.wave_preset = SettingsValues.WavePreset.STRONG_CHOP
	var windsurfer: WindsurferNode = WindsurferNode.new()
	windsurfer.wind_config = settings.build_wind_config()
	windsurfer.wave_set_config = settings.build_wave_set_config()
	add_child_autofree(windsurfer)
	assert_almost_eq(windsurfer.sim.wind.config.speed_kt, 24.0, TOL)
	assert_almost_eq(windsurfer.sim.wind_config.from_bearing_deg, 0.0, TOL)
	assert_true(windsurfer.sim.has_waves(), "waves on the water")
	assert_almost_eq((windsurfer.sim.water as WaveField).total_amplitude_m(), 0.08 + 0.06 + 0.03 + 0.012, 1e-5)


func test_the_swell_and_the_chop_get_their_own_directions_and_heights() -> void:
	var settings: SettingsValues = SettingsValues.new()
	settings.wind_from_deg = 270.0
	settings.swell_follows_wind = false
	settings.swell_from_deg = 0.0
	settings.swell_height_scale = 2.0
	settings.chop_offset_deg = 20.0
	var waves: WaveSetConfig = settings.build_wave_set_config()
	assert_false(waves.swell_relative_to_wind)
	assert_almost_eq(waves.swell_from_deg, 0.0, TOL)
	assert_almost_eq(waves.chop_offset_deg, 20.0, TOL)
	_assert_wave(waves, 0, 0.16, 0.072, "the swell doubled")
	_assert_wave(waves, 1, 0.02, 0.018, "the chop unchanged")
	var field: WaveField = WaveField.new(waves, null, settings.wind_from_deg)
	assert_almost_eq(field.dir_z[0], 1.0, 1e-9, "a swell from the North travels South")
	var chop: Vector2 = WaveField.direction_for_bearing(90.0 + 20.0 - 28.0)
	assert_almost_eq(field.dir_x[1], chop.x, 1e-9, "the long chop: downwind + 20 - 28")
	assert_almost_eq(field.dir_z[1], chop.y, 1e-9)
	settings.swell_height_scale = 0.0
	assert_eq(WaveField.new(settings.build_wave_set_config(), null, 270.0).count, 3, "no swell: only the chop")


func test_the_from_the_wind_preset_makes_the_chop_of_this_wind() -> void:
	var settings: SettingsValues = SettingsValues.new()
	settings.wave_preset = SettingsValues.WavePreset.FROM_WIND
	settings.wind_speed_kt = 16.0
	settings.fetch_km = 3.0
	var waves: WaveSetConfig = settings.build_wave_set_config()
	assert_true(waves.enable_waves)
	assert_eq(waves.validate().size(), 0, "a valid wave set")
	assert_eq(waves.waves.size(), 3, "the swell and two wind waves")
	assert_eq(waves.waves[0].group, GerstnerWaveConfig.Group.SWELL)
	var made: Array[GerstnerWaveConfig] = WindWaves.chop_waves(16.0 * SimMath.KNOT_MS, 3000.0)
	for i: int in made.size():
		assert_eq(waves.waves[i + 1].group, GerstnerWaveConfig.Group.CHOP)
		assert_almost_eq(waves.waves[i + 1].wavelength_m, made[i].wavelength_m, TOL)
		assert_almost_eq(waves.waves[i + 1].amplitude_m, made[i].amplitude_m, TOL)
	settings.water_depth_m = 0.5
	var shallow: WaveSetConfig = settings.build_wave_set_config()
	assert_lt(shallow.waves[1].wavelength_m, waves.waves[1].wavelength_m, "shallow water: shorter waves")
	# The strongest wind over the shortest fetch at twice the height: still no folded crests.
	settings.wind_speed_kt = SettingsValues.WIND_SPEED_MAX_KT
	settings.fetch_km = SettingsValues.FETCH_MIN_KM
	settings.wave_height_scale = SettingsValues.WAVE_SCALE_MAX
	settings.swell_height_scale = SettingsValues.SWELL_SCALE_MAX
	var extreme: WaveSetConfig = settings.build_wave_set_config()
	assert_true(extreme.total_steepness() <= SettingsValues.MAX_TOTAL_STEEPNESS + 1e-9, "the steepness is kept below 0.9")
	assert_eq(extreme.validate().size(), 0)


func test_the_sea_signature_changes_with_every_wave_setting() -> void:
	var settings: SettingsValues = SettingsValues.new()
	var signatures: Array[String] = [settings.sea_signature()]
	settings.wind_speed_kt = 25.0
	assert_eq(settings.sea_signature(), signatures[0], "the wind speed does not change the default sea")
	settings.swell_follows_wind = false
	signatures.append(settings.sea_signature())
	settings.swell_from_deg = 10.0
	signatures.append(settings.sea_signature())
	settings.swell_height_scale = 0.5
	signatures.append(settings.sea_signature())
	settings.chop_offset_deg = 15.0
	signatures.append(settings.sea_signature())
	settings.wave_preset = SettingsValues.WavePreset.FROM_WIND
	signatures.append(settings.sea_signature())
	settings.wind_speed_kt = 12.0
	signatures.append(settings.sea_signature())
	settings.fetch_km = 1.0
	signatures.append(settings.sea_signature())
	settings.water_depth_m = 2.0
	signatures.append(settings.sea_signature())
	for i: int in signatures.size():
		for j: int in range(i + 1, signatures.size()):
			assert_ne(signatures[i], signatures[j], "signatures %d and %d differ" % [i, j])


func test_compass_names_and_points_of_sail() -> void:
	assert_eq(SettingsValues.compass_name(0.0), "N")
	assert_eq(SettingsValues.compass_name(270.0), "W")
	assert_eq(SettingsValues.compass_name(225.0), "SW")
	assert_eq(SettingsValues.compass_name(359.0), "N")
	assert_eq(SettingsValues.point_of_sail(180.0, 270.0), "beam reach (across the wind)")
	assert_eq(SettingsValues.point_of_sail(90.0, 270.0), "run (downwind)")
	assert_eq(SettingsValues.point_of_sail(260.0, 270.0), "into the wind (you will stop)")


func _assert_wave(waves: WaveSetConfig, index: int, amplitude_m: float, steepness: float, text: String) -> void:
	assert_almost_eq(waves.waves[index].amplitude_m, amplitude_m, TOL, text + " (amplitude)")
	assert_almost_eq(waves.waves[index].steepness, steepness, TOL, text + " (steepness)")
