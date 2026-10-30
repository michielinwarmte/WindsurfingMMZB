extends GutTest
## The sail model against the worked examples of PHYSICS_SPEC.md section 2. The spec's
## coefficient numbers are for the legacy sail (6.5 m2, luff 4.7 m), so that sail is built
## explicitly where numbers are checked. The default sail is checked against the full-scale
## wind-tunnel measurements of an iQFOiL sail (PH28; Zhang et al. 2025) at the end.

const TOL: float = 1e-6


func _legacy_sail() -> SailConfig:
	var config: SailConfig = load("res://config/sail_6_5.tres").duplicate()
	config.luff_m = 4.7
	config.boom_m = 2.0
	config.cd_parasitic = 0.015  # the spec's worked examples use the legacy clean-sail value
	# The sail of the worked examples stands alone in a wind tunnel: no deck under its foot.
	config.end_plate_factor = 1.0
	# The legacy lift curve, rigid, as the worked examples were made with (before PH28).
	config.camber = 0.10
	config.zero_lift_deg_per_camber = 60.0
	config.lift_slope_factor = 0.9
	config.cl_transition_gain = 0.3
	config.alpha_luff_deg = 5.0
	config.twist_pressure_pa = 0.0
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
	assert_almost_eq(sail.config.geometric_aspect_ratio(), 3.398, 0.001, "luff squared over area")
	assert_almost_eq(sail.config.aspect_ratio(), 3.398, 0.002, "in the tunnel the induced drag sees the geometric wing")
	var on_the_water: SailConfig = load("res://config/sail_default.tres")
	assert_almost_eq(on_the_water.aspect_ratio(), on_the_water.geometric_aspect_ratio() * 1.4, 0.01, "on the water the deck's end plate cuts the induced drag")
	assert_almost_eq(sail.lift_slope_per_rad(), 3.560, 0.002, "the lift slope is the measured one of the geometric wing")


func test_lift_curve_matches_the_spec_table_and_is_continuous() -> void:
	var sail: SailModel = SailModel.new(_legacy_sail())
	var expected: Dictionary[float, float] = {5.0: 0.683, 10.0: 0.994, 12.0: 1.118, 15.0: 1.268, 18.0: 1.418, 20.0: 1.357, 25.0: 1.205, 30.0: 1.029, 45.0: 0.500, 60.0: 0.483, 90.0: 0.354}
	for angle_deg: float in expected:
		assert_almost_eq(sail.lift_coefficient(deg_to_rad(angle_deg)), expected[angle_deg], 0.002, "cl at %s degrees" % angle_deg)
	assert_almost_eq(sail.lift_coefficient(deg_to_rad(2.5)), 0.264, 0.002, "half of the unfaded lift while luffing")
	assert_eq(sail.lift_coefficient(0.0), 0.0, "no lift at zero angle of attack")
	assert_almost_eq(sail.lift_coefficient(deg_to_rad(-10.0)), 0.7 * 0.994, 0.002, "backwinded: 0.7 of the lift at the same angle, the other way (see compute)")
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
	sail.compute(RigFrame.rigid_on(body, sail.config.mast_foot_local), wind, 1.0, 0.0, 1.225)
	assert_almost_eq(rad_to_deg(sail.sheet_angle_rad), 12.0, 1e-4)
	sail.compute(RigFrame.rigid_on(body, sail.config.mast_foot_local), wind, 0.0, 0.0, 1.225)
	assert_almost_eq(rad_to_deg(sail.sheet_angle_rad), 85.0, 1e-4)
	sail.compute(RigFrame.rigid_on(body, sail.config.mast_foot_local), wind, 0.5, 0.0, 1.225)
	assert_almost_eq(rad_to_deg(sail.sheet_angle_rad), 48.5, 1e-4)


func test_worked_example_beam_wind_from_starboard() -> void:
	# Apparent wind 10 m/s from dead abeam to starboard on a stationary board heading North:
	# wind from the East. Boom at 75 degrees to port gives alpha = 15 degrees.
	var sail: SailModel = SailModel.new(_legacy_sail())
	var body: SimRigidBody = _body()
	var wind: WindField = _constant_wind(10.0, 90.0)
	var sheet: float = 1.0 - (75.0 - 12.0) / 73.0
	sail.compute(RigFrame.rigid_on(body, sail.config.mast_foot_local), wind, sheet, 0.0, 1.225)
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
	sail.compute(RigFrame.rigid_on(body, sail.config.mast_foot_local), wind, sheet, 0.0, 1.225)
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
	sail_a.compute(RigFrame.rigid_on(body, sail_a.config.mast_foot_local), _constant_wind(10.0, 45.0), sheet, 0.0, 1.225)
	sail_b.compute(RigFrame.rigid_on(body, sail_b.config.mast_foot_local), _constant_wind(10.0, 315.0), sheet, 0.0, 1.225)
	assert_eq(sail_b.sail_side, 1)
	assert_almost_eq(sail_b.drive_n, sail_a.drive_n, 1e-3)
	assert_almost_eq(sail_b.side_force_n, -sail_a.side_force_n, 1e-3)
	assert_almost_eq(sail_b.ce_local.x, -sail_a.ce_local.x, 1e-6, "the centre of effort mirrors with the boom")


func test_backwinded_when_eased_too_far() -> void:
	var sail: SailModel = SailModel.new(_legacy_sail())
	var body: SimRigidBody = _body()
	# Wind from 60 degrees to starboard, boom eased to 75 degrees: alpha = -15, the wind on
	# the sail's leeward face. The sail inverts and pushes to windward with 0.7 of its lift.
	sail.compute(RigFrame.rigid_on(body, sail.config.mast_foot_local), _constant_wind(10.0, 60.0), 1.0 - (75.0 - 12.0) / 73.0, 0.0, 1.225)
	assert_almost_eq(rad_to_deg(sail.alpha_rad), -15.0, 1e-3)
	assert_true(sail.is_backwinded)
	assert_false(sail.is_luffing)
	var backwinded_side: float = sail.side_force_n
	var backwinded_lift: float = sail.lift_n
	# The same wind with the boom at 45 degrees: alpha = +15, the normal face.
	var normal: SailModel = SailModel.new(_legacy_sail())
	normal.compute(RigFrame.rigid_on(_body(), normal.config.mast_foot_local), _constant_wind(10.0, 60.0), 1.0 - (45.0 - 12.0) / 73.0, 0.0, 1.225)
	assert_almost_eq(rad_to_deg(normal.alpha_rad), 15.0, 1e-3)
	assert_lt(normal.side_force_n, 0.0, "a sail on port tack... wind from starboard pushes to port (leeward)")
	assert_gt(backwinded_side, 0.0, "backwinded it pushes to starboard (windward)")
	assert_almost_eq(backwinded_lift, 0.7 * normal.lift_n, 1e-3)


func test_the_boom_pushed_across_the_centreline() -> void:
	var sail: SailModel = SailModel.new(_legacy_sail())
	var body: SimRigidBody = _body()
	# Wind from 5 degrees to starboard: head to wind, nearly. Fully sheeted the boom sits at
	# 12 degrees to port and the sail luffs. Pushed all the way across it is 35 degrees to
	# starboard, the wind meets its starboard face at 40 degrees and it pushes to port and aft:
	# the push that takes the bow through the wind in a tack.
	sail.compute(RigFrame.rigid_on(body, sail.config.mast_foot_local), _constant_wind(8.0, 5.0), 1.0, 0.0, 1.225, 0.0, 0.0)
	assert_true(sail.is_luffing or sail.is_backwinded, "nearly head to wind the sheeted sail cannot fill (alpha -7)")
	assert_almost_eq(rad_to_deg(sail.sail_angle_rad()), -12.0, 1e-6, "clew 12 degrees to port")
	sail.compute(RigFrame.rigid_on(body, sail.config.mast_foot_local), _constant_wind(8.0, 5.0), 1.0, 0.0, 1.225, 0.0, 1.0)
	assert_almost_eq(rad_to_deg(sail.sail_angle_rad()), 35.0, 1e-6, "clew 35 degrees to starboard")
	assert_almost_eq(rad_to_deg(sail.alpha_rad), 40.0, 1e-3)
	assert_gt(sail.ce_local.x, 0.0, "the centre of effort went to starboard with the clew")
	assert_lt(sail.side_force_n, -50.0, "pushes to port")
	assert_lt(sail.drive_n, 0.0, "and backwards")


func test_sail_side_hysteresis() -> void:
	var sail: SailModel = SailModel.new(_legacy_sail())
	# The sail keeps its side until the wind is 15 degrees across: the sailor holds the rig
	# through a tack and the sail only blows over once the wind clearly has the other face.
	var sequence: Array[float] = [10.0, 3.0, -3.0, -6.0, -14.0, -16.0]
	var expected: Array[int] = [-1, -1, -1, -1, -1, 1]
	for i: int in sequence.size():
		sail.update_side(deg_to_rad(sequence[i]))
		assert_eq(sail.sail_side, expected[i], "awa %s" % sequence[i])
	var downwind: Array[float] = [160.0, 170.0, 178.0, -178.0, -170.0, -160.0]
	var expected_downwind: Array[int] = [-1, -1, -1, -1, -1, 1]
	for i: int in downwind.size():
		sail.update_side(deg_to_rad(downwind[i]))
		assert_eq(sail.sail_side, expected_downwind[i], "awa %s" % downwind[i])


func test_centre_of_effort_moves_with_rake_and_boom() -> void:
	var sail: SailModel = SailModel.new(_legacy_sail())
	var body: SimRigidBody = _body()
	var wind: WindField = _constant_wind(10.0, 90.0)
	sail.compute(RigFrame.rigid_on(body, sail.config.mast_foot_local), wind, 1.0, 0.0, 1.225)
	var neutral: Vector3 = sail.ce_local
	assert_almost_eq(neutral.y, 0.06 + 1.88, 1e-6, "0.40 of a 4.7 m luff above the mast foot")
	sail.compute(RigFrame.rigid_on(body, sail.config.mast_foot_local), wind, 1.0, 1.0, 1.225)
	var raked_back: Vector3 = sail.ce_local
	assert_almost_eq(raked_back.z - neutral.z, 1.88 * sin(sail.config.max_rake_rad()), 1e-6, "rake back moves the centre of effort aft")
	assert_lt(raked_back.y, neutral.y)
	sail.compute(RigFrame.rigid_on(body, sail.config.mast_foot_local), wind, 0.0, 0.0, 1.225)
	var eased: Vector3 = sail.ce_local
	assert_lt(eased.x, neutral.x, "easing the sheet swings the clew out to port")
	assert_lt(eased.z, neutral.z, "and forward")


## SailConfig.boom_square_to_mast (PH16 step 16): the boom is fixed square to the mast, so a
## rig raked back carries its clew, its centre of effort and the harness line lower; upright,
## the level boom is square to the mast already and nothing changes. The force is the same.
func test_a_boom_square_to_the_mast_drops_the_centre_of_effort_when_raked() -> void:
	var level: SailConfig = _legacy_sail()
	var square: SailConfig = _legacy_sail()
	square.boom_square_to_mast = true
	var wind: WindField = _constant_wind(10.0, 90.0)
	var sail_level: SailModel = SailModel.new(level)
	var sail_square: SailModel = SailModel.new(square)
	sail_level.compute(RigFrame.rigid_on(_body(), level.mast_foot_local), wind, 1.0, 0.0, 1.225)
	sail_square.compute(RigFrame.rigid_on(_body(), square.mast_foot_local), wind, 1.0, 0.0, 1.225)
	assert_almost_eq(sail_square.ce_local.distance_to(sail_level.ce_local), 0.0, TOL, "upright: the same centre of effort")
	sail_level.compute(RigFrame.rigid_on(_body(), level.mast_foot_local), wind, 1.0, 1.0, 1.225)
	sail_square.compute(RigFrame.rigid_on(_body(), square.mast_foot_local), wind, 1.0, 1.0, 1.225)
	var mast: Vector3 = sail_square.mast_direction()
	var boom: Vector3 = sail_square.boom_direction_local
	assert_almost_eq(boom.dot(mast), 0.0, TOL, "the boom is square to the raked mast")
	assert_almost_eq(boom.length(), 1.0, TOL)
	assert_lt(boom.y, 0.0, "raked back, the boom points aft and down")
	# The drop of the centre of effort: its distance along the boom times the boom's slope,
	# cos(sheet) sin(rake) cos(rake) over the length of the level chord made square.
	var rake: float = level.max_rake_rad()
	var sheet: float = deg_to_rad(level.sheet_angle_in_deg)
	var along: float = level.ce_boom_fraction * level.boom_m
	var slope: float = cos(sheet) * sin(rake) * cos(rake) / sqrt(sin(sheet) * sin(sheet) + cos(sheet) * cos(sheet) * cos(rake) * cos(rake))
	assert_almost_eq(sail_level.ce_local.y - sail_square.ce_local.y, along * slope, 1e-6, "lower by the boom's slope")
	assert_almost_eq(sail_square.force_world.distance_to(sail_level.force_world), 0.0, TOL, "the force does not change")


func test_no_force_without_wind() -> void:
	var sail: SailModel = SailModel.new(_legacy_sail())
	var body: SimRigidBody = _body()
	sail.compute(RigFrame.rigid_on(body, sail.config.mast_foot_local), _constant_wind(0.3, 90.0), 0.5, 0.0, 1.225)
	assert_eq(sail.force_world, Vector3.ZERO)
	assert_eq(sail.lift_n, 0.0)


# The default sail against the full-scale iQFOiL 8 m2 sail in the wind tunnel (PH28; Zhang et
# al. 2025, Documentation/Science/2501.13254v1.pdf, Fig. 8a, the outhaul on). Lift at the bottom
# section's angle of attack, read off the figure at 4, 6 and 8 m/s of wind.
const TUNNEL_ANGLES_DEG: Array[float] = [5.3, 8.7, 12.2, 16.5]
const TUNNEL_LIFT: Dictionary[float, Array] = {
	4.0: [0.50, 0.66, 0.96, 0.98],
	6.0: [0.42, 0.60, 0.82, 0.98],
	8.0: [0.37, 0.54, 0.73, 0.90],
}


func _pressure_pa(wind_ms: float) -> float:
	return 0.5 * 1.225 * wind_ms * wind_ms


func test_the_default_sail_lifts_as_the_wind_tunnel_sail() -> void:
	var sail: SailModel = SailModel.new(load("res://config/sail_default.tres"))
	for wind_ms: float in TUNNEL_LIFT:
		var measured: Array = TUNNEL_LIFT[wind_ms]
		for i: int in TUNNEL_ANGLES_DEG.size():
			var alpha_deg: float = TUNNEL_ANGLES_DEG[i]
			var cl: float = sail.lift_coefficient(deg_to_rad(alpha_deg), _pressure_pa(wind_ms))
			assert_almost_eq(cl, float(measured[i]), 0.08, "lift at %.1f degrees in %.0f m/s" % [alpha_deg, wind_ms])
	# Its lift starts near -2 degrees, as both the full-scale and the rigid model's did: at
	# 1.3 degrees the tunnel sail still carried 0.15 to 0.18 (inside the narrow luff fade).
	assert_almost_eq(sail.lift_coefficient(deg_to_rad(1.3), _pressure_pa(4.0)), 0.16, 0.05, "a little lift just above zero")


func test_the_sail_twists_open_as_the_wind_rises() -> void:
	var sail: SailModel = SailModel.new(load("res://config/sail_default.tres"))
	var alpha: float = deg_to_rad(10.0)
	var light: float = sail.lift_coefficient(alpha, _pressure_pa(4.0))
	var fresh: float = sail.lift_coefficient(alpha, _pressure_pa(8.0))
	assert_almost_eq(fresh / light, 0.80, 0.05, "the tunnel lost a fifth of the lift from 4 to 8 m/s")
	assert_eq(sail.lift_coefficient(alpha), sail.lift_coefficient(alpha, 0.0), "no pressure: the rigid curve")
	# Beyond the tunnel's 39 Pa the share follows the fitted formula, not a floor (Max, 30 October
	# 2026): 1 / (1 + q / 125 Pa) at the game's 18 and 24 kt of apparent wind, and the guard
	# (twist_min_factor) is numerical only: the formula meets it at about 83 kt of apparent wind.
	var q_18_kt: float = _pressure_pa(18.0 * SimMath.KNOT_MS)
	var q_24_kt: float = _pressure_pa(24.0 * SimMath.KNOT_MS)
	assert_almost_eq(sail.twist_factor(q_18_kt), 1.0 / (1.0 + q_18_kt / 125.0), 1e-6, "18 kt apparent: the formula, about 0.70")
	assert_almost_eq(sail.twist_factor(q_24_kt), 1.0 / (1.0 + q_24_kt / 125.0), 1e-6, "24 kt apparent: the formula, about 0.57")
	assert_lt(sail.twist_factor(q_24_kt), 0.75, "no floor at the tunnel's last share")
	assert_lt(sail.config.twist_min_factor, 0.2, "the guard is far below any sailing pressure")
	assert_gt(sail.twist_factor(_pressure_pa(34.0 * SimMath.KNOT_MS)), sail.config.twist_min_factor, "34 kt apparent (the sim's most): still the formula")
	assert_almost_eq(sail.twist_factor(1e6), sail.config.twist_min_factor, 1e-9, "a storm's gust: the numerical guard")
	# Past the linear part less is lost: the twisted top takes up the load near the stall.
	var peak: float = deg_to_rad(sail.config.cl_peak_deg)
	assert_gt(sail.lift_coefficient(peak, _pressure_pa(8.0)) / sail.lift_coefficient(peak), fresh / sail.lift_coefficient(alpha))
	# The separation drag of the twisted sail falls too (the tunnel's drag at 20 degrees fell).
	var stalled: float = deg_to_rad(20.0)
	assert_lt(sail.drag_coefficient(1.0, stalled, _pressure_pa(8.0)), sail.drag_coefficient(1.0, stalled))


func test_the_twisted_sail_pulls_lower_on_the_mast() -> void:
	var sail: SailModel = SailModel.new(load("res://config/sail_default.tres"))
	var sheet: float = 1.0 - (75.0 - 12.0) / 73.0
	sail.compute(RigFrame.rigid_on(_body(), sail.config.mast_foot_local), _constant_wind(4.0, 90.0), sheet, 0.0, 1.225)
	var light_height: float = sail.ce_local.y
	sail.compute(RigFrame.rigid_on(_body(), sail.config.mast_foot_local), _constant_wind(8.0, 90.0), sheet, 0.0, 1.225)
	assert_lt(sail.twist_share, 0.85)
	assert_almost_eq(sail.ce_local.y / light_height, 0.95, 0.015, "about 6 % lower in the tunnel from 4 to 8 m/s")
	var rigid: SailConfig = sail.config.duplicate()
	rigid.twist_pressure_pa = 0.0
	var stiff: SailModel = SailModel.new(rigid)
	stiff.compute(RigFrame.rigid_on(_body(), rigid.mast_foot_local), _constant_wind(8.0, 90.0), sheet, 0.0, 1.225)
	assert_eq(stiff.twist_share, 1.0)
	assert_almost_eq(stiff.ce_local.y, rigid.mast_foot_local.y + rigid.ce_height_fraction * rigid.luff_m, 1e-6, "a rigid sail keeps its centre of effort")


func test_the_sail_keeps_twisting_at_the_games_winds() -> void:
	# A real compute(): on a board at rest the apparent wind is the true wind. At 24 kt the
	# share is the formula's (about 0.57), below the tunnel's last measured 0.75.
	var sail: SailModel = SailModel.new(load("res://config/sail_default.tres"))
	var sheet: float = 1.0 - (75.0 - 12.0) / 73.0
	sail.compute(RigFrame.rigid_on(_body(), sail.config.mast_foot_local), _constant_wind(24.0 * SimMath.KNOT_MS, 90.0), sheet, 0.0, 1.225)
	var q: float = _pressure_pa(24.0 * SimMath.KNOT_MS)
	assert_almost_eq(sail.twist_share, 1.0 / (1.0 + q / sail.config.twist_pressure_pa), 1e-6)
	assert_lt(sail.twist_share, 0.75)
	assert_gt(sail.lift_n, 0.0)


# The centre of effort's height by angle of attack (PH28; Fig. 8d of Zhang et al. 2025): eased,
# the force sits low on the sail. The tunnel's heights on the 8.0 (outhaul on), as a share of the
# same wind's height at 12.2 degrees and averaged over 4, 6 and 8 m/s: 0.53 at 1.3 degrees, 0.855
# at 5.3, 0.94 at 8.7 (SailConfig, "Centre of effort by angle of attack").
func test_the_centre_of_effort_sits_lower_when_the_sail_is_eased() -> void:
	var config: SailConfig = load("res://config/sail_default.tres")
	assert_almost_eq(config.ce_height_share(12.2), 1.0, 1e-6, "powered: the full height")
	assert_almost_eq(config.ce_height_share(20.0), 1.0, 1e-6, "held beyond the table")
	assert_almost_eq(config.ce_height_share(8.7), 0.94, 1e-6, "Fig. 8d: 1.8 to 2.0 m at 8.7 degrees, 0.94 of 12.2's")
	assert_almost_eq(config.ce_height_share(5.3), 0.855, 1e-6, "Fig. 8d: 1.6 to 1.8 m at 5.3 degrees, 0.855 of 12.2's")
	assert_almost_eq(config.ce_height_share(1.3), 0.53, 1e-6, "Fig. 8d: 0.9 to 1.2 m at 1.3 degrees, 0.53 of 12.2's")
	assert_almost_eq(config.ce_height_share(0.3), 0.53, 1e-6, "held below the table")
	assert_almost_eq(config.ce_height_share(7.0), 0.5 * (0.855 + 0.94), 1e-6, "straight between the table's angles")
	assert_almost_eq(config.ce_height_share(-5.3), 0.855, 1e-6, "a backwinded sail: the same height")
	# In a compute(): the wind from abeam, the boom at 85 degrees gives 5 degrees of attack, at
	# 77 degrees 13. The same wind, so the twist lowers both alike; the ratio is the table's.
	var sail: SailModel = SailModel.new(config)
	var foot_y: float = config.mast_foot_local.y
	sail.compute(RigFrame.rigid_on(_body(), config.mast_foot_local), _constant_wind(8.0, 90.0), 1.0 - (77.0 - 12.0) / 73.0, 0.0, 1.225)
	assert_almost_eq(rad_to_deg(sail.alpha_rad), 13.0, 1e-3)
	var powered_height: float = sail.ce_local.y - foot_y
	sail.compute(RigFrame.rigid_on(_body(), config.mast_foot_local), _constant_wind(8.0, 90.0), 0.0, 0.0, 1.225)
	assert_almost_eq(rad_to_deg(sail.alpha_rad), 5.0, 1e-3)
	var eased_height: float = sail.ce_local.y - foot_y
	var share_at_5: float = 0.53 + (0.855 - 0.53) * (5.0 - 1.3) / (5.3 - 1.3)
	assert_almost_eq(eased_height / powered_height, share_at_5, 1e-3, "at 5 degrees the force sits at 0.83 of its powered height")
	assert_almost_eq(powered_height, config.ce_height_fraction * config.luff_m * (1.0 - config.twist_ce_drop * (1.0 - sail.twist_share)), 1e-6, "powered: the twist's drop only")
	# An empty table keeps the height fixed, as before PH28.
	var fixed: SailConfig = config.duplicate()
	fixed.ce_height_table_deg = []
	fixed.ce_height_table_share = []
	assert_almost_eq(fixed.ce_height_share(5.0), 1.0, 1e-6)


func test_mirror_symmetry_of_the_default_sail() -> void:
	# The twist and the square boom on (the default), raked and leaned, on both tacks.
	var sail_a: SailModel = SailModel.new(load("res://config/sail_default.tres"))
	var sail_b: SailModel = SailModel.new(load("res://config/sail_default.tres"))
	var sheet: float = 1.0 - (30.0 - 12.0) / 73.0
	var lean: float = deg_to_rad(20.0)
	sail_a.compute(RigFrame.rigid_on(_body(), sail_a.config.mast_foot_local), _constant_wind(12.0, 45.0), sheet, 0.8, 1.225, lean)
	sail_b.compute(RigFrame.rigid_on(_body(), sail_b.config.mast_foot_local), _constant_wind(12.0, 315.0), sheet, 0.8, 1.225, -lean)
	assert_eq(sail_a.sail_side, -1)
	assert_eq(sail_b.sail_side, 1)
	assert_lt(sail_a.twist_share, 1.0, "the twist is on")
	assert_almost_eq(sail_b.twist_share, sail_a.twist_share, 1e-9)
	assert_almost_eq(sail_b.drive_n, sail_a.drive_n, 1e-3)
	assert_almost_eq(sail_b.side_force_n, -sail_a.side_force_n, 1e-3)
	assert_almost_eq(sail_b.force_world.y, sail_a.force_world.y, 1e-3, "the leaned rig lifts the same on both tacks")
	assert_almost_eq(sail_b.ce_local.x, -sail_a.ce_local.x, 1e-6, "the centre of effort mirrors with the boom")
	assert_almost_eq(sail_b.ce_local.y, sail_a.ce_local.y, 1e-6)
	assert_almost_eq(sail_b.ce_local.z, sail_a.ce_local.z, 1e-6)
	assert_almost_eq(sail_b.boom_direction_local.y, sail_a.boom_direction_local.y, 1e-6, "the square boom drops the same on both tacks")
