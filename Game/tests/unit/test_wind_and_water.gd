extends GutTest
## The wind field (PHYSICS_SPEC.md section 8) and the flat water surface (section 9).

const TOL: float = 1e-6


func _constant_wind(speed_kt: float, bearing_deg: float) -> WindField:
	var config: WindConfig = WindConfig.new()
	config.speed_kt = speed_kt
	config.from_bearing_deg = bearing_deg
	config.height_gradient_enabled = false
	config.gusts_enabled = false
	config.shifts_enabled = false
	return WindField.new(config)


func test_cardinal_bearings() -> void:
	var one_ms: float = 1.0 / SimMath.KNOT_MS
	assert_almost_eq(_constant_wind(one_ms, 0.0).velocity_at(Vector3.ZERO), Vector3(0, 0, 1), Vector3.ONE * TOL, "a north wind blows South")
	assert_almost_eq(_constant_wind(one_ms, 90.0).velocity_at(Vector3.ZERO), Vector3(-1, 0, 0), Vector3.ONE * TOL)
	assert_almost_eq(_constant_wind(one_ms, 180.0).velocity_at(Vector3.ZERO), Vector3(0, 0, -1), Vector3.ONE * TOL)
	assert_almost_eq(_constant_wind(one_ms, 270.0).velocity_at(Vector3.ZERO), Vector3(1, 0, 0), Vector3.ONE * TOL, "a west wind blows East")
	assert_almost_eq(_constant_wind(one_ms, 270.0).from_direction(), Vector3(-1, 0, 0), Vector3.ONE * TOL)


func test_knots_and_constant_mode() -> void:
	var wind: WindField = _constant_wind(15.0, 270.0)
	assert_almost_eq(wind.current_speed_ms, 7.71667, 1e-4)
	for i: int in 500:
		wind.step(0.02)
	assert_almost_eq(wind.velocity_at(Vector3(100.0, 5.0, -300.0)), Vector3(7.71667, 0.0, 0.0), Vector3.ONE * 1e-4, "constant in time and space")
	assert_almost_eq(wind.velocity_at(Vector3(0.0, 0.05, 0.0)), Vector3(7.71667, 0.0, 0.0), Vector3.ONE * 1e-4)


func test_height_profile() -> void:
	var config: WindConfig = WindConfig.new()
	config.speed_kt = 15.0
	config.reference_height_m = 10.0
	config.shear_exponent = 0.11
	config.height_gradient_enabled = true
	config.gusts_enabled = false
	var wind: WindField = WindField.new(config)
	var base: float = 15.0 * SimMath.KNOT_MS
	assert_almost_eq(wind.speed_at_height(10.0), base, TOL, "the forecast height")
	assert_almost_eq(wind.speed_at_height(2.0) / base, pow(0.2, 0.11), TOL, "about 0.84 at the sail")
	assert_almost_eq(wind.speed_at_height(0.05), wind.speed_at_height(0.1), TOL, "held constant below the floor, no step")
	assert_lt(absf(wind.speed_at_height(0.0999) - wind.speed_at_height(0.1001)), 1e-3)


func test_gusts_are_deterministic_and_bounded() -> void:
	var config: WindConfig = WindConfig.new()
	config.speed_kt = 15.0
	config.height_gradient_enabled = false
	config.gusts_enabled = true
	config.gust_intensity = 0.2
	config.gust_period_s = 8.0
	var wind: WindField = WindField.new(config)
	var base: float = 15.0 * SimMath.KNOT_MS
	assert_almost_eq(wind.current_speed_ms, base, TOL, "exactly the base wind at t = 0")
	var lowest: float = INF
	var highest: float = -INF
	var sum: float = 0.0
	var steps: int = 4000
	for i: int in steps:
		wind.step(0.02)
		lowest = minf(lowest, wind.current_speed_ms)
		highest = maxf(highest, wind.current_speed_ms)
		sum += wind.current_speed_ms
	assert_gt(lowest, base * 0.80)
	assert_lt(highest, base * 1.20)
	assert_almost_eq(sum / steps / base, 1.0, 0.02, "the average is the base wind")
	# Hand value from the spec at t = 2 s: factor 1.10184.
	var again: WindField = WindField.new(config)
	for i: int in 100:
		again.step(0.02)
	assert_almost_eq(again.current_speed_ms / base, 1.10184, 1e-3)


func test_shift_example() -> void:
	var config: WindConfig = WindConfig.new()
	config.from_bearing_deg = 270.0
	config.height_gradient_enabled = false
	config.gusts_enabled = false
	config.shifts_enabled = true
	config.max_shift_deg = 15.0
	config.shift_period_s = 60.0
	var wind: WindField = WindField.new(config)
	for i: int in 750:
		wind.step(0.02)  # 15 s: phase pi/2
	assert_almost_eq(rad_to_deg(wind.current_from_bearing_rad), 287.4706, 0.01)


func test_flat_water() -> void:
	var config: WaterConfig = WaterConfig.new()
	config.base_height_m = 0.0
	var water: FlatWater = FlatWater.new(config)
	assert_eq(water.height_at(12.0, -3.0, 5.0), 0.0)
	assert_eq(water.normal_at(1.0, 1.0, 0.0), Vector3.UP)
	assert_eq(water.velocity_at(1.0, 1.0, 0.0), Vector3.ZERO)
	assert_almost_eq(water.depth_at(Vector3(1.0, -0.3, 2.0), 0.0), 0.3, TOL)
