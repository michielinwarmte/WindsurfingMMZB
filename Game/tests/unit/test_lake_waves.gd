extends GutTest
## A lake's own waves (PHYSICS_SPEC.md 9.17; PH44): the fetch map, the trains' amplitudes from the
## fetch-limited spectrum, the short train's answer to the gusts, the switch that leaves the old
## sea bit for bit, and that the same inputs always give the same sea.
## Most tests use a made-up lake: a rectangle of water 1000 m west to east and 300 m north to south,
## 10 m deep, with the wind from the west, so the expected fetch can be worked out by hand.

const ENVIRONMENT_PATH: String = "res://maps/silvaplana/environment_silvaplana.tres"
const LAKE_WEST_M: float = 0.0
const LAKE_EAST_M: float = 1000.0
const LAKE_NORTH_M: float = -150.0
const LAKE_SOUTH_M: float = 150.0


## The made-up lake's depth: 10 m inside the rectangle, land (-1) outside.
func _rectangle_depth(x: float, z: float) -> float:
	var inside: bool = x > LAKE_WEST_M and x < LAKE_EAST_M and z > LAKE_NORTH_M and z < LAKE_SOUTH_M
	return 10.0 if inside else -1.0


func _rectangle_map(cell_m: float, rays: int = 9, speed_factor: Callable = Callable()) -> FetchMap:
	if not speed_factor.is_valid():
		speed_factor = func(_x: float, _z: float) -> float: return 1.0
	return FetchMap.build(_rectangle_depth, Rect2(-100.0, -300.0, 1200.0, 600.0), cell_m, 270.0, speed_factor, rays, 6.0)


func _rectangle_lake(wind_kt: float = 18.0) -> LakeWaves:
	var config: LakeWavesConfig = load("res://maps/silvaplana/lake_waves_silvaplana.tres")
	var speed_factor: Callable = func(_x: float, _z: float) -> float: return 1.0
	return LakeWaves.build(config, _rectangle_depth, Rect2(-100.0, -300.0, 1200.0, 600.0), 270.0, wind_kt * SimMath.KNOT_MS, speed_factor)


## The SPM's fetch at a point on the made-up lake's centre line, x metres from the west shore: each
## of the nine rays (6 degrees apart) runs to the west shore or to a side shore, whichever is
## nearer, weighted by the cosine of its angle.
func _expected_fetch_m(x: float) -> float:
	var weighted: float = 0.0
	var weights: float = 0.0
	for ray: int in 9:
		var off: float = deg_to_rad((ray - 4) * 6.0)
		var to_west: float = x / cos(off)
		var to_side: float = 150.0 / sin(absf(off)) if ray != 4 else INF
		weighted += cos(off) * minf(to_west, to_side)
		weights += cos(off)
	return weighted / weights


# ---------------------------------------------------------------- the fetch map

func test_the_fetch_is_the_nine_rays_cosine_weighted() -> void:
	var map: FetchMap = _rectangle_map(10.0)
	for x: float in [100.0, 300.0, 600.0, 900.0]:
		var fetch: float = map.value_at(map.fetch_m, x, 0.0)
		assert_almost_eq(fetch, _expected_fetch_m(x), 12.0, "fetch %.0f m from the west shore" % x)


func test_one_ray_is_the_straight_distance_to_the_upwind_shore() -> void:
	var map: FetchMap = _rectangle_map(10.0, 1)
	for x: float in [50.0, 250.0, 750.0]:
		assert_almost_eq(map.value_at(map.fetch_m, x, 0.0), x, 6.0, "%.0f m from the shore" % x)


func test_the_fetch_is_nothing_at_the_upwind_shore_and_grows_downwind() -> void:
	var map: FetchMap = _rectangle_map(10.0)
	assert_lt(map.value_at(map.fetch_m, 5.0, 0.0), 10.0, "at the upwind shore")
	var before: float = -1.0
	for x: float in range(20, 1000, 20):
		var fetch: float = map.value_at(map.fetch_m, float(x), 0.0)
		assert_gt(fetch, before, "grows downwind at %d m" % x)
		before = fetch


func test_the_map_is_cropped_to_the_water_with_a_margin() -> void:
	# The nodes lie every 10 m from x = -100; water is strictly inside 0 to 1000 m, so the water's nodes
	# are x = 10 to 990 (99 of them), and two of land on each side.
	var map: FetchMap = _rectangle_map(10.0)
	assert_almost_eq(map.x0_m, -10.0, 0.001, "two nodes of land west of the water")
	assert_eq(map.columns, 103, "the water's 99 nodes and two of land on each side")
	assert_false(map.is_water(1, 10))
	assert_true(map.is_water(5, 15))


func test_the_wind_along_the_fetch_is_its_mean_over_the_water_upwind() -> void:
	# Half the wind over the western half of the lake: 750 m from the west shore the wind blew 500 m
	# at half strength and 250 m at full, a mean of 0.67 (one ray: the straight line).
	var half_west: Callable = func(x: float, _z: float) -> float: return 0.5 if x < 500.0 else 1.0
	var map: FetchMap = _rectangle_map(10.0, 1, half_west)
	assert_almost_eq(map.value_at(map.wind_factor, 750.0, 0.0), (500.0 * 0.5 + 250.0 * 1.0) / 750.0, 0.02)
	assert_almost_eq(map.value_at(map.wind_factor, 250.0, 0.0), 0.5, 0.01, "all of it in the half wind")


# ---------------------------------------------------------------- the growth laws and the spectrum

func test_the_band_amplitudes_are_the_researchs_table() -> void:
	# wave_system_research.md, table 1.4 (mm): the JONSWAP shape on the SPM's Hs and Tp.
	var cases: Array[Array] = [
		[16.0, 3000.0, [9.0, 17.0, 31.0, 62.0, 37.0]],
		[16.0, 1000.0, [10.0, 19.0, 37.0, 19.0, 1.0]],
		[12.0, 300.0, [10.0, 15.0, 4.0, 0.0, 0.0]],
		[25.0, 3000.0, [10.0, 20.0, 38.0, 67.0, 97.0]],
	]
	var lengths: Array[float] = [0.5, 1.0, 2.0, 4.0, 8.0]
	for case: Array in cases:
		var wind_ms: float = case[0] * SimMath.KNOT_MS
		var hs: float = WindWaves.significant_height_m(wind_ms, case[1])
		var tp: float = WindWaves.peak_period_s(wind_ms, case[1])
		for band: int in lengths.size():
			var expected_mm: float = (case[2] as Array)[band]
			assert_almost_eq(LakeWaves.band_amplitude_m(lengths[band], hs, tp) * 1000.0, expected_mm, 0.6,
				"%.0f kt over %.0f m, the %.1f m train" % [case[0], case[1], lengths[band]])


func test_the_bands_share_out_the_whole_spectrum() -> void:
	for tp: float in [0.5, 1.8, 4.0]:
		var total: float = 0.0
		var length: float = 0.0001
		while length < 10000.0:
			total += LakeWaves.band_share(length, length * 2.0, tp)
			length *= 2.0
		assert_almost_eq(total, 1.0, 1e-4, "every octave together, Tp %.1f s" % tp)


func test_the_cem_law_is_the_researchs() -> void:
	# wave_system_research.md 1.3, table 1.4: 16 kt over 3 km by the CEM, 0.221 m and 1.38 s.
	var wind_ms: float = 16.0 * SimMath.KNOT_MS
	assert_almost_eq(WindWaves.significant_height_cem_m(wind_ms, 3000.0), 0.221, 0.001)
	assert_almost_eq(WindWaves.peak_period_cem_s(wind_ms, 3000.0), 1.38, 0.01)
	assert_almost_eq(WindWaves.significant_height_cem_m(25.0 * SimMath.KNOT_MS, 100.0), 0.067, 0.001)


# ---------------------------------------------------------------- the lake's waves

func test_flat_at_the_upwind_shore_and_bigger_downwind() -> void:
	var lake: LakeWaves = _rectangle_lake()
	var near_shore: PackedFloat64Array = PackedFloat64Array()
	var far_down: PackedFloat64Array = PackedFloat64Array()
	lake.amplitudes_at(20.0, 0.0, near_shore)
	lake.amplitudes_at(950.0, 0.0, far_down)
	for band: int in lake.band_count:
		assert_lt(near_shore[band], 0.006, "the %.0f m train by the upwind shore" % lake.wavelength_m[band])
	assert_gt(far_down[1], 0.010, "the 4 m train 950 m downwind")
	assert_gt(lake.sea_at(950.0, 0.0).x, 3.0 * lake.sea_at(50.0, 0.0).x, "Hs grows downwind")
	assert_gt(lake.sea_at(950.0, 0.0).y, lake.sea_at(200.0, 0.0).y, "the peak moves to longer waves")


func test_the_peak_moves_from_short_to_long_trains() -> void:
	# Near the upwind shore the shortest physics train carries the most; far downwind a longer one.
	var lake: LakeWaves = _rectangle_lake(24.0)
	var near: PackedFloat64Array = PackedFloat64Array()
	var far: PackedFloat64Array = PackedFloat64Array()
	lake.amplitudes_at(100.0, 0.0, near)
	lake.amplitudes_at(950.0, 0.0, far)
	assert_gt(near[3], near[1], "100 m out: the 1 m train above the 4 m one")
	assert_gt(far[2], far[3], "950 m out: the 2 m train above the 1 m one")
	assert_gt(far[1], near[1] * 5.0, "the 4 m train has grown")


func test_the_shallows_hold_hs_below_six_tenths_of_the_depth() -> void:
	var config: LakeWavesConfig = load("res://maps/silvaplana/lake_waves_silvaplana.tres")
	# A lake 0.1 m deep: 18 kt over a kilometre makes 0.14 m in deep water, here at most 0.06 m.
	var shallow: Callable = func(x: float, z: float) -> float: return 0.1 if _rectangle_depth(x, z) > 0.0 else -1.0
	var one: Callable = func(_x: float, _z: float) -> float: return 1.0
	var lake: LakeWaves = LakeWaves.build(config, shallow, Rect2(-100.0, -300.0, 1200.0, 600.0), 270.0, 18.0 * SimMath.KNOT_MS, one)
	assert_almost_eq(lake.sea_at(900.0, 0.0).x, 0.06, 0.001)


func test_the_trains_keep_their_directions_and_follow_the_wind() -> void:
	var lake: LakeWaves = _rectangle_lake()
	# The wind from the west: downwind is east (+x); the 8 m train straight downwind.
	assert_almost_eq(lake.dir_x[0], 1.0, 1e-6)
	assert_almost_eq(lake.dir_z[0], 0.0, 1e-6)
	# The 4 m train 7 degrees anticlockwise of downwind: a little north (-z).
	assert_almost_eq(rad_to_deg(atan2(lake.dir_z[1], lake.dir_x[1])), -7.0, 1e-4)


# ---------------------------------------------------------------- the physics' water

func test_the_lake_field_reads_the_grid_and_floats_on_it() -> void:
	var field: LakeWaveField = LakeWaveField.new(_rectangle_lake(24.0))
	field.amplitudes_for(950.0, 0.0)
	var expected: PackedFloat64Array = PackedFloat64Array()
	field.lake.amplitudes_at(950.0, 0.0, expected)
	assert_eq(field.count, 2, "the physics floats on the 8 m and 4 m trains (physics_trains)")
	for band: int in field.count:
		assert_eq(field.amplitude[band], expected[band], "the grid's amplitude")
		assert_almost_eq(field.steepness[band], field.k[band] * expected[band], 1e-12, "the physical steepness")
	var highest: float = 0.0
	for i: int in 400:
		highest = maxf(highest, field.height_at(950.0 + i * 0.37, 0.0, i * 0.1))
	assert_gt(highest, 0.01, "waves 950 m downwind")
	assert_eq(field.height_at(5000.0, 0.0, 1.0), 0.0, "flat off the grid")


func test_sample_at_answers_as_the_three_queries() -> void:
	var field: LakeWaveField = LakeWaveField.new(_rectangle_lake(24.0))
	var samples: PackedFloat64Array = WaterSurface.new_samples(1)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for i: int in 200:
		var x: float = rng.randf_range(0.0, 1000.0)
		var z: float = rng.randf_range(-150.0, 150.0)
		var t: float = rng.randf_range(0.0, 600.0)
		WaterSurface.forget_samples(samples)
		field.sample_at(x, z, t, samples, 0)
		assert_eq(WaterSurface.sample_height(samples, 0), field.height_at(x, z, t), "height, cold")
		assert_eq(WaterSurface.sample_normal(samples, 0), field.normal_at(x, z, t), "normal, cold")
		assert_eq(WaterSurface.sample_velocity(samples, 0), field.velocity_at(x, z, t), "velocity, cold")


func test_the_picture_and_the_physics_agree_within_a_millimetre() -> void:
	# The shader reads the grid at the vertex's rest point, the physics at the asked point.
	var field: LakeWaveField = LakeWaveField.new(_rectangle_lake(24.0))
	var worst: float = 0.0
	for i: int in 300:
		var x: float = 30.0 + i * 3.1
		var t: float = i * 0.7
		var height: float = field.height_at(x, 7.0, t)
		var rest: Vector2 = field.rest_point_at(x, 7.0, t)
		field.amplitudes_for(rest.x, rest.y)
		var at_rest: Vector3 = field.displacement_at(rest.x, rest.y, t)
		# The point the shader's vertex lands on, and its height there.
		var landed: Vector2 = rest + Vector2(at_rest.x, at_rest.z)
		assert_almost_eq(landed.x, x, 0.002, "the vertex lands on the asked point")
		worst = maxf(worst, absf(at_rest.y - height))
	assert_lt(worst, 0.001, "worst height difference %.5f m" % worst)


func test_the_same_inputs_give_the_same_sea() -> void:
	var first: LakeWaves = _rectangle_lake()
	var second: LakeWaves = _rectangle_lake()
	assert_eq(first.amplitudes, second.amplitudes, "the trains' heights, bit for bit")
	assert_eq(first.look_data, second.look_data)
	assert_eq(first.phase0, second.phase0)
	var a: LakeWaveField = LakeWaveField.new(first)
	var b: LakeWaveField = LakeWaveField.new(second)
	for i: int in 50:
		assert_eq(a.height_at(800.0 + i, 3.0, i * 1.3), b.height_at(800.0 + i, 3.0, i * 1.3))


# ---------------------------------------------------------------- the gusts

func test_the_short_train_answers_the_wind_as_plants_growth_rate() -> void:
	# wave_system_research.md 1.5 (Plant 1982 with the CEM's u*): at 16 kt the energy of a 1 m wave
	# e-folds in 53 s, of 0.3 m in 8.7 s (there with surface tension, which adds about 1 % at 0.3 m).
	var lake: LakeWaves = _rectangle_lake()
	lake.config = lake.config.duplicate()
	lake.config.look_wavelength_m = 1.0
	assert_almost_eq(lake.look_response_time_s(16.0 * SimMath.KNOT_MS), 53.0, 2.0)
	lake.config.look_wavelength_m = 0.3
	assert_almost_eq(lake.look_response_time_s(16.0 * SimMath.KNOT_MS), 8.7, 0.3)
	lake.config.look_wavelength_m = 0.5
	assert_lt(lake.look_response_time_s(25.0 * SimMath.KNOT_MS), lake.look_response_time_s(12.0 * SimMath.KNOT_MS), "faster in more wind")


func test_the_short_train_grows_with_the_wind_by_the_spectrum() -> void:
	var lake: LakeWaves = _rectangle_lake()
	var growth: PackedFloat32Array = lake.look_values(1)
	var near: float = lake.map.value_at(growth, 60.0, 0.0)
	var far: float = lake.map.value_at(growth, 950.0, 0.0)
	assert_gt(near, 0.3, "near the upwind shore the 0.5 m train is near the peak and grows with the wind")
	assert_lt(far, near, "far downwind it is in the spectrum's saturated tail and grows less")
	assert_gt(far, 0.0)


func test_the_recent_wind_is_the_gust_picture_average() -> void:
	# The three Gauss-Laguerre weights add up to 1: a steady wind averages to itself.
	var environment: EnvironmentConfig = load(ENVIRONMENT_PATH)
	var wind: MapWind = environment.map_wind()
	var now: WindMoment = wind.moment(14.5 * 3600.0)
	var here: float = WindRippleMap.recent_ratio(wind, now, 300.0, -500.0, 0.0)
	assert_almost_eq(here, wind.velocity_in(now, Vector3(300.0, 0.0, -500.0)).length() / now.lake_speed_ms, 1e-9, "0 s: the wind of the moment")
	var averaged: float = WindRippleMap.recent_ratio(wind, now, 300.0, -500.0, 14.0)
	assert_gt(averaged, 0.5)
	assert_lt(averaged, 1.6)


# ---------------------------------------------------------------- the switch

func _lake_sim(place_waves: bool) -> WindsurferSim:
	var environment: EnvironmentConfig = (load(ENVIRONMENT_PATH) as EnvironmentConfig).duplicate()
	var sim: WindsurferSim = WindsurferSim.create_for(environment)
	sim.wave_set_config = sim.wave_set_config.duplicate(true)
	sim.wave_set_config.place_waves = place_waves
	sim.set_waves(true)
	sim.reset(Vector3(380.0, 0.0, -910.0), deg_to_rad(132.0))
	return sim


func test_on_the_lake_the_switch_brings_the_lakes_own_waves() -> void:
	assert_true(_lake_sim(true).water is LakeWaveField)
	var old: WindsurferSim = _lake_sim(false)
	assert_true(old.water is WaveField)
	assert_false(old.water is LakeWaveField, "off: the wave set's waves")


func test_off_the_lake_sails_bit_for_bit_as_before() -> void:
	# The old way: no environment for the sea (as before the switch existed). The new way with the
	# switch off. Every number of the board's state after 3 s must be the same.
	var old_way: WindsurferSim = _lake_sim(false)
	old_way.environment = null
	old_way.set_waves(true)
	old_way.reset(Vector3(380.0, 0.0, -910.0), deg_to_rad(132.0))
	var new_way: WindsurferSim = _lake_sim(false)
	var controls: SimControls = SimControls.new()
	controls.sheet = 0.6
	for tick: int in 180:
		old_way.step(1.0 / 60.0, controls)
		new_way.step(1.0 / 60.0, controls)
	assert_eq(BoardSnapshot.capture(new_way).values, BoardSnapshot.capture(old_way).values, "the whole state, bit for bit")


func test_the_open_water_ignores_the_switch() -> void:
	var waves: WaveSetConfig = (load("res://config/waves_default.tres") as WaveSetConfig).duplicate(true)
	waves.place_waves = true
	var sim: WindsurferSim = WindsurferSim.create_for(EnvironmentConfig.new(), false, true)
	sim.wave_set_config = waves
	sim.set_waves(true)
	assert_false(sim.water is LakeWaveField, "the open water has no lake")
	var reference: WaveField = WaveField.new(load("res://config/waves_default.tres"), sim.water_config, sim.wind_config.from_bearing_deg)
	var field: WaveField = sim.water as WaveField
	for i: int in 50:
		assert_eq(field.height_at(i * 1.7, -i * 0.9, i * 0.3), reference.height_at(i * 1.7, -i * 0.9, i * 0.3))


func test_the_settings_switch_reaches_the_wave_set_and_the_file() -> void:
	var settings: SettingsValues = SettingsValues.new()
	assert_true(settings.lake_waves, "on by default on this branch")
	assert_true(settings.build_wave_set_config().place_waves)
	var before: String = settings.sea_signature()
	settings.lake_waves = false
	assert_false(settings.build_wave_set_config().place_waves)
	assert_ne(settings.sea_signature(), before, "a new sea when it changes")
	var file: ConfigFile = ConfigFile.new()
	settings.write_to(file)
	var again: SettingsValues = SettingsValues.new()
	again.read_from(file)
	assert_false(again.lake_waves, "kept in the settings file")


func test_the_lake_builds_once_for_every_board_at_the_same_wind() -> void:
	var environment: EnvironmentConfig = (load(ENVIRONMENT_PATH) as EnvironmentConfig).duplicate()
	var first: WindsurferSim = WindsurferSim.create_for(environment)
	var second: WindsurferSim = WindsurferSim.create_for(environment)
	var a: LakeWaves = environment.lake_waves_for(first.wind, first.wind_config)
	var b: LakeWaves = environment.lake_waves_for(second.wind, second.wind_config)
	assert_same(a, b, "one sea for the race's boards")
	assert_almost_eq(a.from_deg, (first.wind as MapWindField).map_wind.lake_from_deg(14.5 * 3600.0), 1e-6, "the map's wind direction")
