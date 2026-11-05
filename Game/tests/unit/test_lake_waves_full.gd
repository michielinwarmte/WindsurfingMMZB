extends GutTest
## The lake's full waves (PHYSICS_SPEC.md 9.17 and 9.18; PH44, stage 2 of the research): all four
## trains in the physics, the hull feeling the water averaged over its wet bottom, the fin feeling
## the water's motion fade with depth, the dispersion with depth, the seeded phases, and the
## wave-height multiplier of the settings and the command line.
## The made-up lake is test_lake_waves.gd's: a rectangle of water 1000 m west to east and 300 m
## north to south, 10 m deep, the wind from the west.

const ENVIRONMENT_PATH: String = "res://maps/silvaplana/environment_silvaplana.tres"


func _rectangle_depth(x: float, z: float) -> float:
	var inside: bool = x > 0.0 and x < 1000.0 and z > -150.0 and z < 150.0
	return 10.0 if inside else -1.0


func _rectangle_lake(wind_kt: float = 18.0, config: LakeWavesConfig = null) -> LakeWaves:
	if config == null:
		config = load("res://maps/silvaplana/lake_waves_silvaplana.tres")
	var speed_factor: Callable = func(_x: float, _z: float) -> float: return 1.0
	return LakeWaves.build(config, _rectangle_depth, Rect2(-100.0, -300.0, 1200.0, 600.0), 270.0, wind_kt * SimMath.KNOT_MS, speed_factor)


# ---------------------------------------------------------------- all four trains

func test_the_physics_floats_on_all_four_trains() -> void:
	var field: LakeWaveField = LakeWaveField.new(_rectangle_lake(24.0))
	assert_eq(field.count, 4, "the 8, 4, 2 and 1 m trains (physics_trains = 4)")
	assert_eq(field.wavelength, PackedFloat64Array([8.0, 4.0, 2.0, 1.0]))
	var shader: Dictionary[String, Variant] = field.shader_parameters()
	assert_eq(shader["lake_shape_trains"], 4, "the picture moves the surface by the same four")


# ---------------------------------------------------------------- dispersion with depth

func test_the_dispersion_with_depth_is_coastal_engineerings() -> void:
	# omega^2 = g k tanh(k h) (coastalwiki): spec 9.16's example, the 18.3 m wave of a 4.44 s
	# period in 2 m of water, travels at 4.1 m/s.
	var k: float = TAU / 18.3
	var omega: float = WaveField.angular_frequency(k, 2.0)
	assert_almost_eq(omega, TAU / 4.44, 0.002, "the period's frequency")
	assert_almost_eq(omega / k, 4.12, 0.01, "4.1 m/s, not the deep water's 5.3")
	assert_eq(WaveField.angular_frequency(k, 0.0), sqrt(WaveField.G * k), "0: deep water, as before")


func test_the_lake_is_deep_for_its_trains() -> void:
	var lake: LakeWaves = _rectangle_lake()
	assert_almost_eq(lake.reference_depth_m, 10.0, 1e-6, "the made-up lake is 10 m deep everywhere")
	var field: LakeWaveField = LakeWaveField.new(lake)
	for i: int in field.count:
		var deep: float = sqrt(WaveField.G * field.k[i])
		assert_almost_eq(field.omega[i], deep, deep * 1e-5, "deep water for the %.0f m train in 10 m" % field.wavelength[i])
		assert_almost_eq(field.c[i], field.omega[i] / field.k[i], 1e-12, "the phase speed is omega / k")


func test_a_shallow_lake_slows_its_long_trains() -> void:
	var config: LakeWavesConfig = (load("res://maps/silvaplana/lake_waves_silvaplana.tres") as LakeWavesConfig).duplicate()
	config.reference_depth_m = 1.0
	var field: LakeWaveField = LakeWaveField.new(_rectangle_lake(18.0, config))
	assert_almost_eq(field.omega[0], sqrt(WaveField.G * field.k[0] * tanh(field.k[0] * 1.0)), 1e-9, "the 8 m train in 1 m of water")
	assert_lt(field.c[0], 0.85 * sqrt(WaveField.G / field.k[0]), "noticeably slower than in deep water (0.81 of it)")


# ---------------------------------------------------------------- seeded phases

func test_the_phases_are_seeded() -> void:
	var first: LakeWaves = _rectangle_lake()
	var again: LakeWaves = _rectangle_lake()
	assert_eq(first.phase0, again.phase0, "the same seed, the same phases (both PCs of a LAN game)")
	for phase: float in first.phase0:
		assert_between(phase, 0.0, TAU)
	var config: LakeWavesConfig = (load("res://maps/silvaplana/lake_waves_silvaplana.tres") as LakeWavesConfig).duplicate()
	config.phase_seed += 1
	assert_ne(_rectangle_lake(18.0, config).phase0, first.phase0, "another seed, other phases")


# ---------------------------------------------------------------- the fin: the water's motion fades with depth

func test_the_fins_water_fades_with_depth_per_train() -> void:
	var field: LakeWaveField = LakeWaveField.new(_rectangle_lake(24.0))
	var x: float = 900.0
	var z: float = 10.0
	var t: float = 37.0
	assert_eq(field.velocity_below(x, z, 0.0, t), field.velocity_at(x, z, t), "at the surface: the surface's")
	# By hand: each train's orbital velocity times e^(-k depth) at the rest point of (x, z).
	var depth: float = 0.15
	var rest: Vector2 = field.rest_point_at(x, z, t)
	var expected: Vector3 = Vector3.ZERO
	for i: int in field.count:
		var phase: float = field.k[i] * (field.dir_x[i] * rest.x + field.dir_z[i] * rest.y) - field.omega[i] * t + field.phase[i]
		var fade: float = exp(-field.k[i] * depth)
		var forward: float = field.steepness[i] * field.c[i] * sin(phase) * fade
		expected += Vector3(field.dir_x[i] * forward, -field.amplitude[i] * field.omega[i] * cos(phase) * fade, field.dir_z[i] * forward)
	var below: Vector3 = field.velocity_below(x, z, depth, t)
	assert_almost_eq(below.x, expected.x, 1e-6)
	assert_almost_eq(below.y, expected.y, 1e-6)
	assert_almost_eq(below.z, expected.z, 1e-6)
	# The 1 m train keeps 39 % of its motion 0.15 m down, the 8 m train 89 %.
	assert_almost_eq(exp(-TAU / 1.0 * depth), 0.39, 0.01)
	assert_almost_eq(exp(-TAU / 8.0 * depth), 0.89, 0.01)


func test_the_open_seas_fin_feels_the_surface_as_before() -> void:
	var field: WaveField = WaveField.new(load("res://config/waves_default.tres"), null, 270.0)
	for i: int in 20:
		assert_eq(field.velocity_below(i * 1.3, -i * 0.7, 0.2, i * 0.4), field.velocity_at(i * 1.3, -i * 0.7, i * 0.4), "bit for bit")


# ---------------------------------------------------------------- the hull: the water averaged over its wet bottom

func test_the_hull_averages_each_train_over_its_wet_bottom() -> void:
	var lake: LakeWaves = _rectangle_lake(24.0)
	var full: LakeWaveField = LakeWaveField.new(lake)
	var hull: LakeWaveField = LakeWaveField.new(lake)
	# A wet bottom 1.2 m long and 0.6 m wide, its bow pointing the way the 8 m train travels.
	var forward: Vector2 = Vector2(hull.dir_x[0], hull.dir_z[0])
	hull.set_footprint(1.2, 0.6, forward)
	for i: int in hull.count:
		var along: float = forward.dot(Vector2(hull.dir_x[i], hull.dir_z[i]))
		var across: float = sqrt(maxf(1.0 - along * along, 0.0))
		var spread: float = (1.2 * along) * (1.2 * along) / 12.0 + (0.6 * across) * (0.6 * across) / 12.0
		assert_almost_eq(hull.footprint_factor[i], exp(-0.5 * hull.k[i] * hull.k[i] * spread), 1e-9,
			"the %.0f m train: a box of the wet bottom's size, as a Gaussian of the same spread" % hull.wavelength[i])
	assert_gt(hull.footprint_factor[0], 0.95, "the 8 m train is felt nearly whole")
	assert_lt(hull.footprint_factor[3], 0.15, "the 1 m train is bridged")
	full.amplitudes_for(900.0, 0.0)
	hull.amplitudes_for(900.0, 0.0)
	for i: int in hull.count:
		assert_almost_eq(hull.amplitude[i], full.amplitude[i] * hull.footprint_factor[i], 1e-12)
		assert_almost_eq(hull.steepness[i], hull.k[i] * hull.amplitude[i], 1e-12)


func test_a_short_train_across_the_board_is_averaged_over_its_beam_only() -> void:
	var hull: LakeWaveField = LakeWaveField.new(_rectangle_lake(24.0))
	var across: Vector2 = Vector2(-hull.dir_z[3], hull.dir_x[3])  # the bow along the 1 m train's crests
	hull.set_footprint(1.2, 0.6, across)
	assert_almost_eq(hull.footprint_factor[3], exp(-0.5 * hull.k[3] * hull.k[3] * 0.6 * 0.6 / 12.0), 1e-9)


func test_without_a_footprint_the_field_is_the_surface_itself() -> void:
	var field: LakeWaveField = LakeWaveField.new(_rectangle_lake(24.0))
	for factor: float in field.footprint_factor:
		assert_eq(factor, 1.0)


func test_the_sim_gives_the_hull_its_own_view_and_the_fin_the_whole_sea() -> void:
	var environment: EnvironmentConfig = (load(ENVIRONMENT_PATH) as EnvironmentConfig).duplicate()
	var sim: WindsurferSim = WindsurferSim.create_for(environment)
	sim.wave_set_config = sim.wave_set_config.duplicate(true)
	sim.wave_set_config.place_waves = true
	sim.set_waves(true)
	sim.reset(Vector3(380.0, 0.0, -910.0), deg_to_rad(132.0))
	assert_true(sim.water is LakeWaveField)
	assert_true(sim.hull_water is LakeWaveField)
	assert_ne(sim.hull_water, sim.water, "two views of one lake")
	assert_same((sim.hull_water as LakeWaveField).lake, (sim.water as LakeWaveField).lake)
	var controls: SimControls = SimControls.new()
	controls.sheet = 0.6
	for tick: int in 120:
		sim.step(1.0 / 60.0, controls)
	var hull: LakeWaveField = sim.hull_water as LakeWaveField
	assert_lt(hull.footprint_factor[3], 1.0, "the hull's view follows its wet bottom")
	for factor: float in (sim.water as LakeWaveField).footprint_factor:
		assert_eq(factor, 1.0, "the fin, the picture and the telemetry see the whole sea")


func test_off_the_lake_the_hull_sees_the_same_water() -> void:
	var sim: WindsurferSim = WindsurferSim.create_default(true)
	assert_same(sim.hull_water, sim.water, "the open sea: one surface for every model, as before")


# ---------------------------------------------------------------- the wave-height multiplier

func test_the_command_line_scale_is_read() -> void:
	assert_eq(LakeWaves.scale_from_arguments(PackedStringArray(["--lake_wave_scale=1.5"])), 1.5)
	assert_eq(LakeWaves.scale_from_arguments(PackedStringArray(["--other=2"])), -1.0, "none given")


func test_the_scale_multiplies_every_train() -> void:
	var one: LakeWaves = _rectangle_lake(18.0)
	var config: LakeWavesConfig = (load("res://maps/silvaplana/lake_waves_silvaplana.tres") as LakeWavesConfig).duplicate()
	config.height_scale = 1.5
	var more: LakeWaves = _rectangle_lake(18.0, config)
	for i: int in one.amplitudes.size():
		assert_almost_eq(more.amplitudes[i], 1.5 * one.amplitudes[i], 1e-6)


func test_the_settings_scale_reaches_the_lake() -> void:
	var settings: SettingsValues = SettingsValues.new()
	assert_eq(settings.lake_wave_scale, 1.0, "the growth law's waves by default")
	settings.lake_wave_scale = 1.5
	assert_eq(settings.build_wave_set_config().place_height_scale, 1.5)
	var file: ConfigFile = ConfigFile.new()
	settings.write_to(file)
	var again: SettingsValues = SettingsValues.new()
	again.read_from(file)
	assert_eq(again.lake_wave_scale, 1.5, "kept in the settings file's [waves] (the LAN guest gets the host's)")
	var environment: EnvironmentConfig = (load(ENVIRONMENT_PATH) as EnvironmentConfig).duplicate()
	var sim: WindsurferSim = WindsurferSim.create_for(environment)
	var normal: LakeWaves = environment.lake_waves_for(sim.wind, sim.wind_config)
	var higher: LakeWaves = environment.lake_waves_for(sim.wind, sim.wind_config, 1.5)
	assert_ne(normal, higher, "a lake of its own")
	var index: int = normal.amplitudes.size() / 2
	while normal.amplitudes[index] < 0.005:
		index += 1
	assert_almost_eq(higher.amplitudes[index], 1.5 * normal.amplitudes[index], 1e-6)


func test_the_trains_stay_below_the_breaking_steepness_at_one_and_a_half() -> void:
	# H/L < 1/7 (coastalwiki; Michell 1893): k a < pi / 7 for each train, anywhere on the lake.
	var config: LakeWavesConfig = (load("res://maps/silvaplana/lake_waves_silvaplana.tres") as LakeWavesConfig).duplicate()
	config.height_scale = 1.5
	var lake: LakeWaves = _rectangle_lake(30.0, config)
	for node: int in lake.amplitudes.size() / lake.band_count:
		var sum: float = 0.0
		for i: int in lake.band_count:
			var steepness: float = lake.wave_number[i] * lake.amplitudes[node * lake.band_count + i]
			assert_lt(steepness, LakeWaves.MAX_STEEPNESS, "a train steeper than a wave can be")
			sum += steepness
		assert_lt(sum, 1.0, "the crests never fold (9.8)")


# ---------------------------------------------------------------- the AI's view of the sea

func test_the_ais_sea_height_on_the_lake_is_the_lakes() -> void:
	var environment: EnvironmentConfig = (load(ENVIRONMENT_PATH) as EnvironmentConfig).duplicate()
	var sim: WindsurferSim = WindsurferSim.create_for(environment)
	sim.wave_set_config = sim.wave_set_config.duplicate(true)
	sim.wave_set_config.place_waves = true
	sim.set_waves(true)
	sim.reset(Vector3(380.0, 0.0, -910.0), deg_to_rad(132.0))
	var field: LakeWaveField = sim.water as LakeWaveField
	field.amplitudes_for(380.0, -910.0)
	var crest: float = 0.0
	for a: float in field.amplitude:
		crest += a
	assert_gt(crest, 0.03, "waves at the start")
	assert_almost_eq(RaceObservation.sea_height_m(sim), crest, 1e-9, "the highest crest where the board sails")
