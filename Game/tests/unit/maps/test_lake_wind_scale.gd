extends GutTest
## The lake wind multiplier (Max, 6 November 2026: "Silvaplana changable wind (multiplier)";
## MapWind.set_lake_wind_scale()): at 1 nothing changes, bit for bit; at 1.5 the lake's wind is 1.5
## times as strong at a point and a time, and what is made from it follows (the gusts' spread, the
## simulation's wind and the HUD's number, the lake's own waves); the settings keep it in [wind],
## clamped; the command line overrides the settings; the measured day's file is never changed.

const CONFIG_PATH: String = "res://maps/silvaplana/map_config.tres"
const PATTERN_PATH: String = "res://maps/silvaplana/wind/maloja_pattern.json"
const DAY_PATH: String = "res://maps/silvaplana/wind/maloja_day.tres"
const GUSTS_PATH: String = "res://maps/silvaplana/wind/maloja_gusts.tres"
const LEE_PATH: String = "res://maps/silvaplana/wind/shore_lee.json"
const ENVIRONMENT_PATH: String = "res://maps/silvaplana/environment_silvaplana.tres"
const AFTERNOON_S: float = 14.5 * 3600.0
## Spots on the lake (game metres): off the camping beach, the middle, toward Sils, by the south-east shore.
const SPOTS: Array[Vector3] = [Vector3(300.0, 0.0, -600.0), Vector3(349.0, 0.0, -89.0), Vector3(-600.0, 0.0, 700.0), Vector3(700.0, 0.0, 200.0)]

var _config: MapConfig


func before_all() -> void:
	_config = load(CONFIG_PATH)


func _full_wind() -> MapWind:
	return MapWind.load_from(PATTERN_PATH, DAY_PATH, _config, GUSTS_PATH, LEE_PATH)


func test_at_one_nothing_changes_bit_for_bit() -> void:
	var measured: MapWind = _full_wind()
	var scaled: MapWind = _full_wind()
	scaled.set_lake_wind_scale(1.0)
	assert_eq(scaled.lake_wind_scale(), 1.0)
	assert_eq(scaled.day, measured.day, "the measured day itself, not a copy")
	for spot: Vector3 in SPOTS:
		for t: float in [AFTERNOON_S, AFTERNOON_S + 37.0, 17.0 * 3600.0]:
			assert_eq(scaled.velocity_at(spot, t), measured.velocity_at(spot, t), "the same wind at %s, %.0f s" % [spot, t])
	# And back to 1 after another multiplier: exactly the measured wind again (the gusts' travel too).
	scaled.set_lake_wind_scale(1.5)
	scaled.set_lake_wind_scale(1.0)
	for spot: Vector3 in SPOTS:
		assert_eq(scaled.velocity_at(spot, AFTERNOON_S), measured.velocity_at(spot, AFTERNOON_S))
	assert_eq(scaled.travel_m(AFTERNOON_S), measured.travel_m(AFTERNOON_S))


func test_at_one_and_a_half_the_wind_is_one_and_a_half_times() -> void:
	# Without gusts the wind at a point is the pattern times the day's mean: exactly 1.5 times.
	var day: WindDay = load(DAY_PATH) as WindDay
	var pattern: WindPattern = _full_wind().pattern
	var plain: MapWind = MapWind.new(pattern, day)
	var stronger: MapWind = MapWind.new(pattern, day)
	stronger.set_lake_wind_scale(1.5)
	for spot: Vector3 in SPOTS:
		assert_almost_eq(stronger.velocity_at(spot, AFTERNOON_S), 1.5 * plain.velocity_at(spot, AFTERNOON_S), Vector3.ONE * 1e-5,
			"the wind at %s" % spot)
	assert_almost_eq(stronger.moment(AFTERNOON_S).lake_speed_ms, 1.5 * plain.moment(AFTERNOON_S).lake_speed_ms, 1e-6, "the lake's mean")
	assert_eq(day.lake_wind_scale, 1.0, "the measured day's resource (shared) is never changed")


func test_the_gusts_lee_and_drift_follow() -> void:
	var measured: MapWind = _full_wind()
	var stronger: MapWind = _full_wind()
	stronger.set_lake_wind_scale(1.5)
	var now: WindMoment = measured.moment(AFTERNOON_S)
	var then: WindMoment = stronger.moment(AFTERNOON_S)
	assert_almost_eq(then.lake_speed_ms, 1.5 * now.lake_speed_ms, 1e-6, "the mean")
	assert_almost_eq(then.drift_ms, 1.5 * now.drift_ms, 1e-6, "the gusts roll down the lake 1.5 times as fast")
	assert_gt(then.spread_ms, 1.3 * now.spread_ms, "the gusts and lulls are bigger in knots (0.48 kt + 0.087 per knot)")
	# With the gusts the wind at a point moves (they have drifted further), but over the lake it is
	# 1.5 times on average.
	var sum_measured: float = 0.0
	var sum_stronger: float = 0.0
	for i: int in 40:
		for j: int in 40:
			var spot: Vector3 = Vector3(-1500.0 + 75.0 * i, 0.0, -1500.0 + 75.0 * j)
			if measured.pattern.contains(spot.x, spot.z):
				sum_measured += measured.velocity_in(now, spot).length()
				sum_stronger += stronger.velocity_in(then, spot).length()
	assert_almost_eq(sum_stronger / sum_measured, 1.5, 0.05, "the lake's wind 1.5 times on average, with gusts and lee")


func test_the_simulations_wind_and_the_hud_follow() -> void:
	var environment: EnvironmentConfig = (load(ENVIRONMENT_PATH) as EnvironmentConfig).duplicate()
	var plain: MapWindField = MapWindField.new(environment.map_wind(), environment.wind_or_default(), AFTERNOON_S, environment.map_wind_height_m)
	var at_10m: float = plain.speed_at_height(10.0)
	assert_almost_eq(at_10m / SimMath.KNOT_MS, 18.2, 0.2, "the measured day at 14:30: about 18 kt at 10 m")
	var other: EnvironmentConfig = (load(ENVIRONMENT_PATH) as EnvironmentConfig).duplicate()
	other.map_wind().set_lake_wind_scale(1.5)
	var stronger: MapWindField = MapWindField.new(other.map_wind(), other.wind_or_default(), AFTERNOON_S, other.map_wind_height_m)
	assert_almost_eq(stronger.speed_at_height(10.0), 1.5 * at_10m, 1e-5, "the mean at 10 m")
	assert_almost_eq(stronger.current_speed_ms, 1.5 * plain.current_speed_ms, 1e-5, "the HUD's and the controller's number")
	assert_eq(environment.map_wind().lake_wind_scale(), 1.0, "each environment its own map wind")


func test_the_lake_waves_grow_from_the_scaled_wind() -> void:
	var environment: EnvironmentConfig = (load(ENVIRONMENT_PATH) as EnvironmentConfig).duplicate()
	environment.map_wind().set_lake_wind_scale(1.5)
	var sim: WindsurferSim = WindsurferSim.create_for(environment)
	var plain_environment: EnvironmentConfig = (load(ENVIRONMENT_PATH) as EnvironmentConfig).duplicate()
	var plain_sim: WindsurferSim = WindsurferSim.create_for(plain_environment)
	var lake: LakeWaves = environment.lake_waves_for(sim.wind, sim.wind_config)
	var plain: LakeWaves = plain_environment.lake_waves_for(plain_sim.wind, plain_sim.wind_config)
	assert_almost_eq(lake.wind_10m_ms, 1.5 * plain.wind_10m_ms, 1e-4, "built for 1.5 times the wind")
	assert_gt(lake.max_total_amplitude_m, 1.3 * plain.max_total_amplitude_m, "higher waves")


func test_the_multiplier_is_kept_within_its_range() -> void:
	var wind: MapWind = _full_wind()
	wind.set_lake_wind_scale(10.0)
	assert_eq(wind.lake_wind_scale(), MapWind.LAKE_WIND_SCALE_MAX)
	wind.set_lake_wind_scale(0.01)
	assert_eq(wind.lake_wind_scale(), MapWind.LAKE_WIND_SCALE_MIN)
	var file: ConfigFile = ConfigFile.new()
	file.set_value("wind", "lake_wind_scale", 7.0)
	var settings: SettingsValues = SettingsValues.new()
	assert_eq(settings.lake_wind_scale, 1.0, "the measured day by default")
	settings.read_from(file)
	assert_eq(settings.lake_wind_scale, SettingsValues.LAKE_WIND_SCALE_MAX, "a hand-edited file is clamped")
	file.set_value("wind", "lake_wind_scale", 0.0)
	settings.read_from(file)
	assert_eq(settings.lake_wind_scale, SettingsValues.LAKE_WIND_SCALE_MIN)


func test_the_settings_keep_it_in_the_wind_section_and_the_sea_follows() -> void:
	var settings: SettingsValues = SettingsValues.new()
	var before: String = settings.sea_signature()
	settings.lake_wind_scale = 1.35
	assert_ne(settings.sea_signature(), before, "the lake's waves grow from it: a new sea")
	var file: ConfigFile = ConfigFile.new()
	settings.write_to(file)
	assert_eq(float(file.get_value("wind", "lake_wind_scale")), 1.35, "in [wind], which a LAN guest gets from the host")
	var again: SettingsValues = SettingsValues.new()
	again.read_from(file)
	assert_eq(again.lake_wind_scale, 1.35)


func test_the_command_line_overrides_the_settings() -> void:
	assert_eq(MapWind.lake_wind_scale_from_arguments(PackedStringArray(["--lake_wind_scale=1.7"])), 1.7)
	assert_eq(MapWind.lake_wind_scale_from_arguments(PackedStringArray(["--time=14:30"])), -1.0, "none given")
	assert_eq(MapWind.scale_chosen(1.2, PackedStringArray(["--x=1", "--lake_wind_scale=0.5"])), 0.5, "the command line wins")
	assert_eq(MapWind.scale_chosen(1.2, PackedStringArray()), 1.2, "else the settings'")
	assert_eq(MapWind.command_line_lake_wind_scale(), -1.0, "the tests run without one")
