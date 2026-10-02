extends GutTest
## The sail model against the worked examples of PHYSICS_SPEC.md section 2. The spec's
## coefficient numbers are for the legacy sail (6.5 m2, luff 4.7 m), so that sail is built
## explicitly where numbers are checked.

const TOL: float = 1e-6


func _legacy_sail() -> SailConfig:
	var config: SailConfig = load("res://config/sail_default.tres").duplicate()
	config.luff_m = 4.7
	config.boom_m = 2.0
	config.cd_parasitic = 0.015  # the spec's worked examples use the legacy clean-sail value
	return config


func _constant_wind(speed_ms: float, from_bearing_deg: float) -> WindField:
	var config: WindConfig = WindConfig.new()
	config.speed_kt = speed_ms / SimMath.KNOT_MS
	config.from_bearing_deg = from_bearing_deg
	config.height_gradient_enabled = false
	config.gusts_enabled = false
	config.shifts_enabled = false
	return WindField.new(config)


func _body() -> SimRigidBody:
	var body: SimRigidBody = SimRigidBody.new()
	body.set_mass_properties(92.0, Basis.IDENTITY.scaled(Vector3(50.0, 6.0, 46.0)), Vector3(0.0, 0.97, 0.0))
	return body


func test_aspect_ratio_and_slope() -> void:
	var sail: SailModel = SailModel.new(_legacy_sail())
	assert_almost_eq(sail.config.aspect_ratio(), 3.398, 0.001)
	assert_almost_eq(sail.lift_slope_per_rad(), 3.560, 0.002)


func test_lift_curve_matches_the_spec_table_and_is_continuous() -> void:
	var sail: SailModel = SailModel.new(_legacy_sail())
	var expected: Dictionary[float, float] = {5.0: 0.683, 10.0: 0.994, 12.0: 1.118, 15.0: 1.268, 18.0: 1.418, 20.0: 1.357, 25.0: 1.205, 30.0: 1.029, 45.0: 0.500, 60.0: 0.483, 90.0: 0.354}
	for angle_deg: float in expected:
		assert_almost_eq(sail.lift_coefficient(deg_to_rad(angle_deg)), expected[angle_deg], 0.002, "cl at %s degrees" % angle_deg)
	assert_almost_eq(sail.lift_coefficient(deg_to_rad(2.5)), 0.264, 0.002, "half of the unfaded lift while luffing")
	assert_eq(sail.lift_coefficient(0.0), 0.0, "no lift at zero angle of attack")
	assert_eq(sail.lift_coefficient(deg_to_rad(-10.0)), 0.0, "no lift when backwinded")
	var previous: float = sail.lift_coefficient(0.0)
	var step_deg: float = 0.01
	var angle: float = step_deg
	while angle <= 90.0:
		var current: float = sail.lift_coefficient(deg_to_rad(angle))
		assert_lt(absf(current - previous), 0.01, "continuous at %s degrees" % angle)
		previous = current
		angle += step_deg


func test_drag_curve() -> void:
	var sail: SailModel = SailModel.new(_legacy_sail())
	assert_almost_eq(sail.drag_coefficient(sail.lift_coefficient(deg_to_rad(15.0)), deg_to_rad(15.0)), 0.216, 0.002)
	assert_almost_eq(sail.drag_coefficient(sail.lift_coefficient(deg_to_rad(5.0)), deg_to_rad(5.0)), 0.073, 0.002)
	assert_almost_eq(sail.drag_coefficient(sail.lift_coefficient(deg_to_rad(90.0)), deg_to_rad(90.0)), 1.3, TOL, "capped at cd_max")
	assert_almost_eq(sail.drag_coefficient(0.0, 0.0), 0.015, TOL, "parasitic only when luffing")


func test_sheet_mapping() -> void:
	var sail: SailModel = SailModel.new(_legacy_sail())
	var body: SimRigidBody = _body()
	var wind: WindField = _constant_wind(0.0, 270.0)
	sail.compute(body, wind, 1.0, 0.0, 1.225)
	assert_almost_eq(rad_to_deg(sail.sheet_angle_rad), 12.0, 1e-4)
	sail.compute(body, wind, 0.0, 0.0, 1.225)
	assert_almost_eq(rad_to_deg(sail.sheet_angle_rad), 85.0, 1e-4)
	sail.compute(body, wind, 0.5, 0.0, 1.225)
	assert_almost_eq(rad_to_deg(sail.sheet_angle_rad), 48.5, 1e-4)


func test_worked_example_beam_wind_from_starboard() -> void:
	# Apparent wind 10 m/s from dead abeam to starboard on a stationary board heading North:
	# wind from the East. Boom at 75 degrees to port gives alpha = 15 degrees.
	var sail: SailModel = SailModel.new(_legacy_sail())
	var body: SimRigidBody = _body()
	var wind: WindField = _constant_wind(10.0, 90.0)
	var sheet: float = 1.0 - (75.0 - 12.0) / 73.0
	sail.compute(body, wind, sheet, 0.0, 1.225)
	assert_eq(sail.sail_side, -1, "boom to port when the wind is from starboard")
	assert_almost_eq(rad_to_deg(sail.awa_rad), 90.0, 1e-3)
	assert_almost_eq(rad_to_deg(sail.alpha_rad), 15.0, 1e-3)
	assert_almost_eq(sail.lift_n, 504.8, 1.0)
	assert_almost_eq(sail.drag_n, 85.9, 0.5)
	# Lift points straight forward (North = -Z), drag to port (West = -X).
	assert_almost_eq(sail.force_world.normalized().dot(Vector3(0, 0, -1)), 504.8 / sqrt(504.8 * 504.8 + 85.9 * 85.9), 1e-3)
	assert_almost_eq(sail.drive_n, 504.8, 1.0)
	assert_almost_eq(sail.side_force_n, -85.9, 0.5, "side force to port (leeward)")
	assert_false(sail.is_luffing)


func test_close_reach_drive_and_side_force() -> void:
	# Apparent wind from 45 degrees to starboard: with alpha = 15 degrees the drive is
	# L sin 45 - D cos 45 and the side force L cos 45 + D sin 45 (to port).
	var sail: SailModel = SailModel.new(_legacy_sail())
	var body: SimRigidBody = _body()
	var wind: WindField = _constant_wind(10.0, 45.0)
	var sheet: float = 1.0 - (30.0 - 12.0) / 73.0
	sail.compute(body, wind, sheet, 0.0, 1.225)
	assert_almost_eq(rad_to_deg(sail.awa_rad), 45.0, 1e-3)
	assert_almost_eq(rad_to_deg(sail.alpha_rad), 15.0, 1e-3)
	var l: float = sail.lift_n
	var d: float = sail.drag_n
	assert_almost_eq(sail.drive_n, (l - d) * sqrt(0.5), 0.5)
	assert_almost_eq(sail.side_force_n, -(l + d) * sqrt(0.5), 0.5)


func test_mirror_symmetry() -> void:
	var sail_a: SailModel = SailModel.new(_legacy_sail())
	var sail_b: SailModel = SailModel.new(_legacy_sail())
	var body: SimRigidBody = _body()
	var sheet: float = 1.0 - (30.0 - 12.0) / 73.0
	sail_a.compute(body, _constant_wind(10.0, 45.0), sheet, 0.0, 1.225)
	sail_b.compute(body, _constant_wind(10.0, 315.0), sheet, 0.0, 1.225)
	assert_eq(sail_b.sail_side, 1)
	assert_almost_eq(sail_b.drive_n, sail_a.drive_n, 1e-3)
	assert_almost_eq(sail_b.side_force_n, -sail_a.side_force_n, 1e-3)
	assert_almost_eq(sail_b.ce_local.x, -sail_a.ce_local.x, 1e-6, "the centre of effort mirrors with the boom")


func test_luffing_when_eased_too_far() -> void:
	var sail: SailModel = SailModel.new(_legacy_sail())
	var body: SimRigidBody = _body()
	# Wind from 60 degrees to starboard, boom eased to 75 degrees: alpha = -15, backwinded.
	sail.compute(body, _constant_wind(10.0, 60.0), 1.0 - (75.0 - 12.0) / 73.0, 0.0, 1.225)
	assert_almost_eq(rad_to_deg(sail.alpha_rad), -15.0, 1e-3)
	assert_true(sail.is_luffing)
	assert_eq(sail.lift_n, 0.0)
	assert_gt(sail.drag_n, 0.0)


func test_sail_side_hysteresis() -> void:
	var sail: SailModel = SailModel.new(_legacy_sail())
	var sequence: Array[float] = [10.0, 3.0, -3.0, -6.0]
	var expected: Array[int] = [-1, -1, -1, 1]
	for i: int in sequence.size():
		sail.update_side(deg_to_rad(sequence[i]))
		assert_eq(sail.sail_side, expected[i], "awa %s" % sequence[i])
	var downwind: Array[float] = [170.0, 178.0, -178.0, -170.0]
	var expected_downwind: Array[int] = [-1, -1, -1, 1]
	for i: int in downwind.size():
		sail.update_side(deg_to_rad(downwind[i]))
		assert_eq(sail.sail_side, expected_downwind[i], "awa %s" % downwind[i])


func test_centre_of_effort_moves_with_rake_and_boom() -> void:
	var sail: SailModel = SailModel.new(_legacy_sail())
	var body: SimRigidBody = _body()
	var wind: WindField = _constant_wind(10.0, 90.0)
	sail.compute(body, wind, 1.0, 0.0, 1.225)
	var neutral: Vector3 = sail.ce_local
	assert_almost_eq(neutral.y, 0.06 + 1.88, 1e-6, "0.40 of a 4.7 m luff above the mast foot")
	sail.compute(body, wind, 1.0, 1.0, 1.225)
	var raked_back: Vector3 = sail.ce_local
	assert_almost_eq(raked_back.z - neutral.z, 1.88 * sin(sail.config.max_rake_rad()), 1e-6, "rake back moves the centre of effort aft")
	assert_lt(raked_back.y, neutral.y)
	sail.compute(body, wind, 0.0, 0.0, 1.225)
	var eased: Vector3 = sail.ce_local
	assert_lt(eased.x, neutral.x, "easing the sheet swings the clew out to port")
	assert_lt(eased.z, neutral.z, "and forward")


func test_no_force_without_wind() -> void:
	var sail: SailModel = SailModel.new(_legacy_sail())
	var body: SimRigidBody = _body()
	sail.compute(body, _constant_wind(0.3, 90.0), 0.5, 0.0, 1.225)
	assert_eq(sail.force_world, Vector3.ZERO)
	assert_eq(sail.lift_n, 0.0)
