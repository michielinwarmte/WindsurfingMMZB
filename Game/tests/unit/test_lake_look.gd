extends GutTest
## A lake's look in the wind (res://world/lake_look.gdshaderinc, LakeLook; lake_wind_shading.md): the
## short waves' roughness from Cox and Munk, the Donelan-Banner spreading of the picture's parts, the
## whitecaps' share from Zhao and Toba and the threshold that gives that share, and the water shader's
## numbers for Lake Silvaplana. Only the picture: the physics' sea is test_lake_waves.gd's.

const ENVIRONMENT_PATH: String = "res://maps/silvaplana/environment_silvaplana.tres"
const SHADER_INCLUDE_PATH: String = "res://world/lake_look.gdshaderinc"


func test_cox_and_munk_slope_grows_with_the_wind() -> void:
	# Cox and Munk 1954: mss = 0.003 + 5.12e-3 U (U at 12.5 m).
	assert_almost_eq(LakeLook.cox_munk_mss(0.0), 0.003, 1e-9)
	assert_almost_eq(LakeLook.cox_munk_mss(10.0), 0.0542, 1e-9)
	# A gust 10 % stronger than the lake's 9.4 m/s is about 9 % rougher.
	var rougher: float = LakeLook.cox_munk_mss(9.4 * 1.1) / LakeLook.cox_munk_mss(9.4) - 1.0
	assert_almost_eq(rougher, 0.094, 0.002)


func test_donelan_banner_spreading() -> void:
	# Horvath 2015 eq. 38: the branches nearly meet at 0.95 and 1.6, and short waves spread wider.
	assert_almost_eq(LakeLook.donelan_banner_beta(0.9499), LakeLook.donelan_banner_beta(0.9501), 0.1, "the branches at 0.95")
	assert_almost_eq(LakeLook.donelan_banner_beta(1.5999), LakeLook.donelan_banner_beta(1.6001), 0.1, "the branches at 1.6")
	assert_gt(LakeLook.donelan_banner_beta(1.0), LakeLook.donelan_banner_beta(3.0), "shorter waves spread wider")
	var beta: float = LakeLook.donelan_banner_beta(1.6)
	assert_almost_eq(rad_to_deg(LakeLook.donelan_banner_angle(0.0, beta)), 0.0, 1e-6, "the middle part runs with the wind")
	# The quantile's inverse: the share of the waves within the angle of quantile u is u.
	for u: float in [0.2, 0.5, 0.8]:
		var angle: float = LakeLook.donelan_banner_angle(u, beta)
		assert_almost_eq(LakeLook.donelan_banner_share_within(angle, beta), u, 1e-4, "quantile %.1f" % u)
	# At 1.6 times the peak frequency half the waves travel within about 25 degrees of the wind.
	assert_between(rad_to_deg(LakeLook.donelan_banner_angle(0.5, beta)), 20.0, 30.0)


func test_the_tail_of_a_sum_of_sine_waves() -> void:
	# One sine wave of steepness 1 never exceeds 1; its kurtosis pulls the 0.1 % point from the Gaussian's
	# 3.09 spreads (4.4 in steepness) down toward it.
	var variance: float = 0.5
	var one: float = sqrt(variance) * LakeLook.sines_exceeded(0.001, variance, 1.0)
	assert_lt(one, sqrt(variance) * LakeLook.gaussian_exceeded(0.001))
	# Many small waves: the Gaussian's.
	assert_almost_eq(LakeLook.sines_exceeded(0.001, 50.0, 100.0), LakeLook.gaussian_exceeded(0.001), 0.02)


func test_the_gaussian_tail() -> void:
	# Abramowitz and Stegun 26.2.23 against the normal table: P(Z > 2) = 0.02275, P(Z > 3) = 0.00135.
	assert_almost_eq(LakeLook.gaussian_exceeded(0.02275), 2.0, 0.005)
	assert_almost_eq(LakeLook.gaussian_exceeded(0.00135), 3.0, 0.005)
	assert_almost_eq(LakeLook.gaussian_exceeded(0.5), 0.0, 0.005)


func test_whitecaps_by_zhao_and_toba() -> void:
	# Worked by hand: U10 10 m/s over waves of 1.5 s: C_D 0.00145, u*^2 0.145 m2/s2, omega_p 4.189 rad/s,
	# R_B = 0.145 / (1.8e-5 x 4.189) = 1923; W = 3.88e-5 x 1923^1.09 % = 0.147 %.
	assert_almost_eq(LakeLook.breaking_wave_parameter(10.0, 1.5), 1923.1, 0.5)
	assert_almost_eq(LakeLook.whitecap_fraction(10.0, 1.5), 0.001474, 0.00001)
	assert_eq(LakeLook.whitecap_fraction(0.0, 1.5), 0.0, "no wind, no whitecaps")
	assert_eq(LakeLook.whitecap_fraction(6.0, 1.5), 0.0, "below the onset (R_B 1000)")
	assert_gt(LakeLook.whitecap_fraction(12.0, 1.5), LakeLook.whitecap_fraction(10.0, 1.5), "more in more wind")
	assert_gt(LakeLook.whitecap_fraction(10.0, 1.7), LakeLook.whitecap_fraction(10.0, 1.0), "more on the longer waves downwind")
	# The onset: about 15 kt on the camping beach's 1.5 s waves, later on the young waves near Sils.
	assert_almost_eq(LakeLook.whitecap_onset_ms(1.48) / SimMath.KNOT_MS, 14.9, 0.3)
	assert_almost_eq(LakeLook.whitecap_onset_ms(1.01) / SimMath.KNOT_MS, 17.5, 0.3)


## The whitecaps' threshold (lake_whitecap()): the squeeze of the lake's trains at the start spot (the
## 8 m and 4 m trains whole, the 2 m, 1 m and 0.5 m as Donelan-Banner parts, as the shader draws them),
## sampled at many places and moments, is above spread x sines_exceeded(W) on about W of the water.
func test_the_threshold_covers_the_whitecaps_share() -> void:
	var lengths: Array[float] = [8.0, 4.0, 2.0, 1.0, 0.5]
	var amplitudes: Array[float] = [0.009, 0.047, 0.034, 0.019, 0.009]
	var stretch: Array[float] = [1.0, 1.15, 0.87, 1.07, 0.93]
	var peak_omega: float = TAU / 1.4
	var parts: Array[Vector4] = []  # direction x, direction z, wave number, steepness
	for i: int in lengths.size():
		if i < 2:
			parts.append(Vector4(0.0, -1.0, TAU / lengths[i], TAU / lengths[i] * amplitudes[i]))
			continue
		var beta: float = LakeLook.donelan_banner_beta(sqrt(9.81 * TAU / lengths[i]) / peak_omega)
		for j: int in 5:
			var angle: float = LakeLook.donelan_banner_angle((2.0 * j + 1.0) / 5.0 - 1.0, beta)
			var k: float = TAU / (lengths[i] * stretch[j])
			parts.append(Vector4(sin(angle), -cos(angle), k, k * amplitudes[i] / sqrt(5.0)))
	var variance: float = 0.0
	var fourth: float = 0.0
	for part: Vector4 in parts:
		variance += 0.5 * part.w * part.w
		fourth += pow(part.w, 4.0)
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 7
	var phases: PackedFloat64Array = PackedFloat64Array()
	for part: Vector4 in parts:
		phases.append(random.randf() * TAU)
	var samples: int = 80000
	var squeezes: PackedFloat64Array = PackedFloat64Array()
	squeezes.resize(samples)
	for n: int in samples:
		var x: float = random.randf() * 400.0
		var z: float = random.randf() * 400.0
		var t: float = random.randf() * 600.0
		var squeeze: float = 0.0
		for i: int in parts.size():
			var part: Vector4 = parts[i]
			squeeze += part.w * sin(part.z * (part.x * x + part.y * z) - sqrt(9.81 * part.z) * t + phases[i])
		squeezes[n] = squeeze
	for share: float in [0.001, 0.002, 0.005, 0.01]:
		var threshold: float = sqrt(variance) * LakeLook.sines_exceeded(share, variance, fourth)
		var above: int = 0
		for squeeze: float in squeezes:
			if squeeze > threshold:
				above += 1
		assert_almost_eq(float(above) / samples, share, 0.2 * share, "whitecaps on %.1f %% of the water" % (100.0 * share))


func test_the_lakes_numbers_for_the_water() -> void:
	var environment: EnvironmentConfig = (load(ENVIRONMENT_PATH) as EnvironmentConfig).duplicate()
	var sim: WindsurferSim = WindsurferSim.create_for(environment)
	var lake: LakeWaves = environment.lake_waves_for(sim.wind, sim.wind_config)
	var omega: float = LakeLook.typical_peak_omega(lake)
	assert_between(TAU / omega, 0.8, 2.0, "the lake's typical peak period, s")
	var parameters: Dictionary[String, Variant] = LakeLook.shader_parameters(lake)
	var wind: Vector2 = parameters["lake_wind_ms"]
	assert_almost_eq(wind.x, lake.wind_10m_ms, 1e-5, "the wind the waves were built for, at 10 m")
	assert_gt(wind.y, wind.x, "a little more at 12.5 m")
	# The shader's arrays: 5 parts for each of the 4 trains and the look train, 4 for each of 2 octaves.
	var spread: PackedVector4Array = parameters["lake_spread_parts"]
	var short: PackedVector4Array = parameters["lake_short_parts"]
	assert_eq(spread.size(), 25)
	assert_eq(short.size(), 8)
	for part: Vector4 in spread + short:
		assert_almost_eq(Vector2(part.x, part.y).length(), 1.0, 1e-5, "a direction")
		assert_almost_eq(part.w, LakeLook.angular_frequency(TAU / part.z) / TAU, 1e-4, "its frequency")
	# A train's middle part runs along the train, its outer parts fan out to either side.
	for train: int in lake.band_count:
		var middle: Vector4 = spread[train * 5 + 2]
		assert_almost_eq(Vector2(middle.x, middle.y).dot(Vector2(lake.dir_x[train], lake.dir_z[train])), 1.0, 1e-5)
		assert_almost_eq(middle.z, lake.wavelength_m[train] * LakeLook.SPREAD_STRETCH[2], 1e-4, "its length within the octave")
	# The short parts fan out around the lake's wind (the Maloja blows toward the north-east: +x, -z).
	var downwind: Vector2 = Vector2.ZERO
	for part: Vector4 in short:
		downwind += Vector2(part.x, part.y)
	assert_gt(downwind.x, 0.0)
	assert_lt(downwind.y, 0.0)
	# The short waves spread wider than the 2 m train: the outer parts' angle to the middle.
	var two_m_outer: float = Vector2(spread[2 * 5].x, spread[2 * 5].y).angle_to(Vector2(spread[2 * 5 + 2].x, spread[2 * 5 + 2].y))
	var short_outer: float = Vector2(short[0].x, short[0].y).angle_to(downwind.normalized())
	assert_gt(absf(short_outer), absf(two_m_outer), "short waves fan out wider")


func test_the_shader_has_the_same_numbers() -> void:
	# The per-pixel formulas are in the shader and in LakeLook: the shader must carry the same coefficients.
	var text: String = FileAccess.get_file_as_string(SHADER_INCLUDE_PATH)
	for number: String in ["0.003 + 0.00512", "3.88e-5", "1.09", "0.0008 + 0.000065", "AIR_VISCOSITY = 1.8e-5",
			"800.0, 1200.0", "SHORT_PARTS = 4", "SPREAD_PARTS = 5", "lake_spread_parts[25]", "lake_short_parts[8]",
			"SHORT_LONGEST_M = 0.25", "SHORT_LONGEST_PART = 1.12"]:
		assert_true(text.contains(number), "the shader has %s" % number)
