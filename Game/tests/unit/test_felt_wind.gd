extends GutTest
## The wind a skipper has felt at its sail (FeltWind; Max, 10 November 2026: "if the AIs do not have info about the
## current wind and average wind felt in the last minute or 2 ... give them that"): the samples, the means over a
## window, the spread, the lightest, and the felt wind put on 10 m.


func test_an_empty_memory_has_no_wind() -> void:
	var felt: FeltWind = FeltWind.new()
	assert_eq(felt.count(), 0)
	assert_true(is_nan(felt.mean_kt(60.0)))
	assert_true(is_nan(felt.now_kt()))
	assert_eq(felt.spread_kt(60.0), 0.0)
	assert_eq(felt.span_s(), 0.0)


func test_samples_closer_than_the_step_are_skipped() -> void:
	var felt: FeltWind = FeltWind.new()
	for k: int in 60:
		felt.add(k / 60.0, 10.0)  # one second at 60 ticks
	assert_eq(felt.count(), 2, "one sample every half second")


func test_the_means_cover_their_windows() -> void:
	var felt: FeltWind = FeltWind.new()
	# 60 s at 16 kt, then 60 s at 10 kt (a lull), a sample every half second.
	for k: int in 240:
		felt.add(k * 0.5, 16.0 if k < 120 else 10.0)
	assert_almost_eq(felt.now_kt(), 10.0, 0.01, "now: the lull")
	assert_almost_eq(felt.mean_kt(30.0), 10.0, 0.01)
	assert_almost_eq(felt.mean_kt(120.0), 13.0, 0.05, "two minutes: half and half")
	assert_almost_eq(felt.lowest_kt(120.0), 10.0, 0.01)
	assert_almost_eq(felt.spread_kt(120.0), 3.0, 0.05, "half at +3, half at -3")
	assert_almost_eq(felt.spread_kt(20.0), 0.0, 0.01, "steady in the lull")


func test_old_samples_are_forgotten() -> void:
	var felt: FeltWind = FeltWind.new()
	for k: int in 1000:
		felt.add(k * 0.5, 20.0 if k < 500 else 12.0)
	assert_almost_eq(felt.span_s(), FeltWind.KEEP_S, 0.51, "only the last two minutes kept")
	assert_almost_eq(felt.mean_kt(1000.0), 12.0, 0.01, "the 20 kt of four minutes ago is gone")
	felt.clear()
	assert_eq(felt.count(), 0)


func test_the_felt_wind_is_the_mean_times_the_gust_at_the_sail() -> void:
	var config: WindConfig = WindConfig.new()
	var wind: WindField = WindField.new(config)
	var telemetry: Telemetry = Telemetry.new()
	telemetry.tws_10m_kt = 18.0
	var mean_at_sail_kt: float = wind.speed_at_height(FeltWind.SAIL_HEIGHT_M) / SimMath.KNOT_MS
	if mean_at_sail_kt < 0.1:
		pass_test("a calm wind field: nothing to compare")
		return
	telemetry.tws_at_sail_kt = mean_at_sail_kt * 0.8
	assert_almost_eq(FeltWind.felt_10m_kt(telemetry, wind), 18.0 * 0.8, 0.01, "a lull of 20 % at the sail is 14.4 kt at 10 m")
	telemetry.tws_at_sail_kt = 0.0
	assert_almost_eq(FeltWind.felt_10m_kt(telemetry, wind), 18.0 * FeltWind.LEAST_SHARE, 0.01, "kept within the shares")
	assert_eq(FeltWind.felt_10m_kt(telemetry, null), 18.0, "no wind field: the mean")
