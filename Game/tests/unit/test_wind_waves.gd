extends GutTest
## Waves made by the wind (sim/wind_waves.gd, PHYSICS_SPEC.md 9.16): the fetch-limited
## JONSWAP relations against the Lake Silvaplana table of PHYSICS_REQUESTS_FROM_MAP.md (R6),
## the depth limit, and the chop it makes for the wave set.

const KNOT_MS: float = 0.514444
## The R6 table, 3 km of fetch: wind (kt), Hs (m), peak period (s), peak wavelength (m).
const SILVAPLANA_3_KM: Array[Array] = [
	[12.0, 0.17, 1.65, 4.3],
	[16.0, 0.23, 1.82, 5.2],
	[20.0, 0.29, 1.96, 6.0],
	[25.0, 0.36, 2.11, 6.9],
]


func test_the_silvaplana_table_within_5_percent() -> void:
	for row: Array in SILVAPLANA_3_KM:
		var wind_ms: float = float(row[0]) * KNOT_MS
		var height_m: float = WindWaves.significant_height_m(wind_ms, 3000.0)
		var period_s: float = WindWaves.peak_period_s(wind_ms, 3000.0)
		var length_m: float = WindWaves.wavelength_m(period_s)
		var label: String = "%.0f kt over 3 km" % float(row[0])
		assert_almost_eq(height_m, float(row[1]), 0.05 * float(row[1]), label + ": Hs")
		assert_almost_eq(period_s, float(row[2]), 0.05 * float(row[2]), label + ": Tp")
		assert_almost_eq(length_m, float(row[3]), 0.05 * float(row[3]), label + ": L")


func test_shorter_fetch_smaller_waves() -> void:
	var wind_ms: float = 16.0 * KNOT_MS
	# R6 table: 16 kt over 1.5 km gives Hs 0.16 m and Tp 1.44 s.
	assert_almost_eq(WindWaves.significant_height_m(wind_ms, 1500.0), 0.16, 0.008)
	assert_almost_eq(WindWaves.peak_period_s(wind_ms, 1500.0), 1.44, 0.07)
	assert_lt(WindWaves.significant_height_m(wind_ms, 500.0), WindWaves.significant_height_m(wind_ms, 3000.0))
	assert_eq(WindWaves.significant_height_m(0.0, 3000.0), 0.0, "no wind, no waves")
	assert_eq(WindWaves.chop_waves(wind_ms, 0.0).size(), 0, "no fetch, no waves")


func test_a_long_fetch_stops_at_the_fully_developed_sea() -> void:
	var wind_ms: float = 4.0 * KNOT_MS
	var u_squared_over_g: float = wind_ms * wind_ms / WindWaves.G
	assert_almost_eq(WindWaves.significant_height_m(wind_ms, 20000.0), 0.2433 * u_squared_over_g, 1e-9, "capped")
	assert_almost_eq(WindWaves.peak_period_s(wind_ms, 20000.0), 8.134 * wind_ms / WindWaves.G, 1e-9, "capped")


func test_shallow_water_caps_the_height_and_shortens_the_wave() -> void:
	# 35 kt over 20 km: a 1.3 m sea in deep water, more than 2 m of water can carry.
	var wind_ms: float = 35.0 * KNOT_MS
	var deep_height_m: float = WindWaves.significant_height_m(wind_ms, 20000.0)
	assert_gt(deep_height_m, 1.2)
	assert_almost_eq(WindWaves.significant_height_m(wind_ms, 20000.0, 2.0), 1.2, 1e-9, "0.6 of the 2 m depth")
	var period_s: float = WindWaves.peak_period_s(wind_ms, 20000.0)
	var deep_length_m: float = WindWaves.wavelength_m(period_s)
	var shallow_length_m: float = WindWaves.wavelength_m(period_s, 2.0)
	assert_lt(shallow_length_m, 0.7 * deep_length_m, "the bottom makes the wave much shorter (30.8 m to 18.3 m)")
	assert_almost_eq(shallow_length_m, 18.32, 0.05)
	# The length solves the dispersion relation with depth: omega² = g k tanh(k d).
	var k: float = TAU / shallow_length_m
	var omega: float = TAU / period_s
	assert_almost_eq(WindWaves.G * k * tanh(k * 2.0), omega * omega, 1e-6)
	# Lake chop in 0.3 m of water (the shallows by a beach): capped at 0.18 m.
	assert_almost_eq(WindWaves.significant_height_m(16.0 * KNOT_MS, 3000.0, 0.3), 0.18, 1e-9)
	# Deep water against a depth much larger than the wave: the same length.
	assert_almost_eq(WindWaves.wavelength_m(1.82, 50.0), WindWaves.wavelength_m(1.82), 1e-4)


func test_the_chop_for_the_wave_set() -> void:
	var waves: Array[GerstnerWaveConfig] = WindWaves.chop_waves(16.0 * KNOT_MS, 3000.0)
	assert_eq(waves.size(), 2, "the peak wave and a shorter one")
	var peak: GerstnerWaveConfig = waves[0]
	var short: GerstnerWaveConfig = waves[1]
	for wave: GerstnerWaveConfig in waves:
		assert_eq(wave.group, GerstnerWaveConfig.Group.CHOP, "wind waves follow the wind")
		assert_almost_eq(wave.steepness, wave.physical_steepness(), 1e-9, "the physical steepness k A")
	assert_almost_eq(peak.wavelength_m, 5.16, 0.05, "the peak wavelength")
	assert_almost_eq(peak.direction_offset_deg, 0.0, 1e-9, "straight downwind")
	assert_almost_eq(short.wavelength_m, peak.wavelength_m / 2.25, 1e-6, "1.5 x the frequency: 1/2.25 of the length")
	assert_almost_eq(short.amplitude_m, 0.33 * peak.amplitude_m, 1e-9)
	# The energy of a regular wave of height Hs, split over the two.
	var hs: float = WindWaves.significant_height_m(16.0 * KNOT_MS, 3000.0)
	assert_almost_eq(peak.amplitude_m * peak.amplitude_m + short.amplitude_m * short.amplitude_m, hs * hs / 4.0, 1e-9)
	var set_config: WaveSetConfig = WaveSetConfig.new()
	set_config.waves = waves
	assert_eq(set_config.validate().size(), 0, "a valid wave set")


func test_every_wind_and_fetch_the_menu_allows_makes_a_valid_set() -> void:
	for wind_kt: float in [4.0, 12.0, 18.0, 25.0, 35.0]:
		for fetch_m: float in [200.0, 3000.0, 20000.0]:
			for depth_m: float in [0.5, 2.0, WindWaves.DEEP_WATER]:
				var set_config: WaveSetConfig = WaveSetConfig.new()
				set_config.waves = WindWaves.chop_waves(wind_kt * KNOT_MS, fetch_m, depth_m)
				var label: String = "%.0f kt, %.0f m fetch, %.1f m deep" % [wind_kt, fetch_m, depth_m]
				assert_eq(set_config.validate().size(), 0, label)
				for wave: GerstnerWaveConfig in set_config.waves:
					assert_true(wave.steepness <= WindWaves.MAX_WAVE_STEEPNESS + 1e-9, label + ": below the breaking limit")
					assert_true(wave.wavelength_m >= 0.5, label + ": not shorter than the set allows")
