extends GutTest
## The hull model (PHYSICS_SPEC.md section 5 as decided in section 15): friction, the
## wave-making hump, sideways drag and Savitsky's dynamic planing lift.

const G: float = 9.81
const DT: float = 1.0 / 240.0


func _board() -> BoardConfig:
	return load("res://config/board_default.tres")


func _water() -> WaterConfig:
	return load("res://config/water_default.tres")


## A body floating level at its resting depth, with the default mass and a low centre of
## mass so it is stable without a sailor model.
func _floating_body(speed_forward: float, mass_kg: float = 92.0) -> SimRigidBody:
	var body: SimRigidBody = SimRigidBody.new()
	body.set_mass_properties(mass_kg, Basis.IDENTITY.scaled(Vector3(50.0, 6.0, 46.0)), Vector3(0.0, 0.15, 0.1))
	var board: BoardConfig = _board()
	var rest_depth: float = mass_kg / 1025.0 / board.volume_m3 * board.thickness_m
	body.set_origin_world(Vector3(0.0, 0.5 * board.thickness_m - rest_depth, 0.0))
	body.velocity = Vector3(0.0, 0.0, -speed_forward)
	return body


func _models() -> Array:
	var buoyancy: BuoyancyModel = BuoyancyModel.new(_board(), _water())
	var hull: HullModel = HullModel.new(_board(), _water())
	return [buoyancy, hull]


## A board with the default size but a flat bottom and a straight outline: a prismatic
## planing plate, for which Savitsky's formula is the reference.
func _flat_board() -> BoardConfig:
	var board: BoardConfig = _board().duplicate()
	board.nose_rocker_m = 0.0
	board.tail_rocker_m = 0.0
	board.tail_width_m = board.width_m
	board.nose_width_m = board.width_m
	board.tail_thickness_m = board.thickness_m
	board.nose_thickness_m = board.thickness_m
	return board


func _flat_models() -> Array:
	var board: BoardConfig = _flat_board()
	return [BuoyancyModel.new(board, _water()), HullModel.new(board, _water())]


## Evaluates the forces once. The planing lift builds up over about one wetted length of
## travel; a one-second step lets it reach its steady value, so the tests see the
## quasi-steady Savitsky lift unless they ask for a real time step.
func _evaluate(hull: HullModel, buoyancy: BuoyancyModel, body: SimRigidBody, dt: float = 1.0) -> void:
	body.clear_forces()
	buoyancy.apply(body, FlatWater.new(), 0.0, G)
	hull.compute(body, buoyancy, FlatWater.new(), 0.0, G, body.mass_kg, dt)


## A body pitched bow-up by trim_deg and moving horizontally at speed_forward, so that the
## water meets the bottom at that trim angle (the velocity is horizontal, not along the
## board's axis).
func _trimmed_body(speed_forward: float, trim_deg: float) -> SimRigidBody:
	var body: SimRigidBody = _floating_body(speed_forward)
	body.basis = Basis(Vector3.RIGHT, deg_to_rad(trim_deg))
	body.velocity = Vector3(0.0, 0.0, -speed_forward)
	return body


func test_friction_follows_the_ittc_line() -> void:
	var models: Array = _models()
	var body: SimRigidBody = _floating_body(2.0)
	_evaluate(models[1], models[0], body)
	var hull: HullModel = models[1]
	var buoyancy: BuoyancyModel = models[0]
	# The friction acts on the dynamically wetted bottom (the wet span of the strip theory
	# times its mean width) when that is more than the still-water grid wets.
	var area: float = maxf(buoyancy.wetted_area_m2, hull.wetted_length_m * hull.planing_beam_m)
	var re: float = 2.0 * maxf(maxf(buoyancy.wetted_length_m, hull.wetted_length_m), 0.3) / 1.19e-6
	var cf: float = 0.075 / pow(log(re) / log(10.0) - 2.0, 2.0)
	assert_almost_eq(hull.friction_n, cf * 0.5 * 1025.0 * 4.0 * area, 1e-3)
	assert_between(hull.friction_n, 3.0, 20.0, "a few newtons at 2 m/s")


func test_residuary_hump_peaks_near_froude_0_55_and_fades_when_planing() -> void:
	var models: Array = _models()
	var hull: HullModel = models[1]
	var buoyancy: BuoyancyModel = models[0]
	var previous_fraction: float = 0.0
	var peak_speed: float = 0.0
	var peak_fraction: float = 0.0
	for i: int in 40:
		var speed: float = 0.25 * (i + 1)
		var body: SimRigidBody = _floating_body(speed)
		_evaluate(hull, buoyancy, body)
		var fraction: float = hull.residuary_n / buoyancy.buoyancy_force_n
		if fraction > peak_fraction:
			peak_fraction = fraction
			peak_speed = speed
		previous_fraction = fraction
	assert_almost_eq(peak_fraction, 0.09, 0.005, "9 percent of the carried weight at the hump")
	var expected_peak_speed: float = 0.55 * sqrt(G * 2.4)
	assert_almost_eq(peak_speed, expected_peak_speed, 0.3)
	assert_lt(previous_fraction, 0.001, "nothing left at 10 m/s")


func test_planing_lift_matches_savitsky_at_a_known_state() -> void:
	# A flat plate (no rocker, no taper) at 7 m/s, trimmed 4 degrees, transom 7.5 cm deep:
	# the strip model must give Savitsky's measured lift and centre of pressure.
	var models: Array = _flat_models()
	var hull: HullModel = models[1]
	var buoyancy: BuoyancyModel = models[0]
	var body: SimRigidBody = _trimmed_body(7.0, 4.0)
	var board: BoardConfig = hull.board
	var transom_local: Vector3 = Vector3(0.0, -0.5 * board.thickness_m, 0.5 * board.length_m)
	var transom_world_y: float = body.point_world(transom_local).y
	body.position.y -= transom_world_y + 0.075
	_evaluate(hull, buoyancy, body)
	assert_almost_eq(buoyancy.transom_immersion_m, 0.075, 1e-3)
	assert_almost_eq(hull.wetted_length_m, 0.075 / tan(deg_to_rad(4.0)), 0.02, "wet up to where the bottom crosses the surface")
	assert_almost_eq(hull.trim_deg, 4.0, 0.05, "the water meets the flat bottom at the pitch angle")
	var lambda: float = hull.lambda_ratio
	var cl_flat: float = 0.012 * pow(4.0, 1.1) * sqrt(lambda)
	var cl: float = cl_flat - 0.0065 * board.deadrise_deg * pow(cl_flat, 0.6)
	# Savitsky's speed is the speed along the keel: 7 m/s horizontal at 4 degrees of trim.
	var u: float = hull.forward_speed_ms
	assert_almost_eq(u, 7.0 * cos(deg_to_rad(4.0)), 1e-3)
	var expected: float = cl * 0.5 * 1025.0 * u * u * 0.72 * 0.72
	assert_almost_eq(hull.planing_normal_force_n, expected, 0.02 * expected, "the strips add up to Savitsky's lift")
	assert_almost_eq(hull.planing_lift_n, expected * cos(deg_to_rad(4.0)), 0.02 * expected, "vertical part")
	assert_between(hull.planing_lift_n, 600.0, 1100.0, "about the weight of the whole windsurfer at 7 m/s")
	assert_almost_eq(hull.planing_drag_n, expected * sin(deg_to_rad(4.0)), 0.02 * expected, "the pressure drag is the lift tilted back by the trim")
	var cop_from_transom: float = 0.5 * board.length_m - hull.cop_local.z
	var cv: float = u / sqrt(G * 0.72)
	var savitsky_cop: float = (0.75 - 1.0 / (5.21 * cv * cv / (lambda * lambda) + 2.39)) * hull.wetted_length_m
	assert_almost_eq(cop_from_transom, savitsky_cop, 0.1 * hull.wetted_length_m, "the centre of pressure is where Savitsky measured it")


func test_bow_up_pitch_rate_is_damped_by_the_water_under_the_hull() -> void:
	# The same plate, now pitching bow-up at 0.3 rad/s. The stern moves down into the water,
	# the water flowing aft under the hull gains momentum, the lift grows, and the extra
	# force sits aft of the centre of mass: a nose-down change of moment, which is damping.
	var still: Array = _flat_models()
	var steady: SimRigidBody = _trimmed_body(7.0, 4.0)
	_evaluate(still[1], still[0], steady)
	var moving: Array = _flat_models()
	var pitching: SimRigidBody = _trimmed_body(7.0, 4.0)
	pitching.angular_velocity = Vector3(0.3, 0.0, 0.0)
	_evaluate(moving[1], moving[0], pitching)
	assert_gt((moving[1] as HullModel).planing_lift_n, (still[1] as HullModel).planing_lift_n, "more lift")
	assert_lt(pitching._torque_sum.x, steady._torque_sum.x, "and a nose-down change of moment")
	var nose_dropping: Array = _flat_models()
	var dropping: SimRigidBody = _trimmed_body(7.0, 4.0)
	dropping.angular_velocity = Vector3(-0.3, 0.0, 0.0)
	_evaluate(nose_dropping[1], nose_dropping[0], dropping)
	assert_gt(dropping._torque_sum.x, steady._torque_sum.x, "a dropping nose is held up")


func test_planing_lift_grows_with_speed_and_trim_and_needs_a_wet_transom() -> void:
	var models: Array = _models()
	var hull: HullModel = models[1]
	var buoyancy: BuoyancyModel = models[0]
	var lift_at: Dictionary[float, float] = {}
	for speed: float in [4.0, 6.0, 8.0]:
		var body: SimRigidBody = _trimmed_body(speed, 4.0)
		_evaluate(hull, buoyancy, body)
		lift_at[speed] = hull.planing_lift_n
	assert_gt(lift_at[6.0], lift_at[4.0])
	assert_gt(lift_at[8.0], lift_at[6.0])
	var flat: SimRigidBody = _floating_body(8.0)
	_evaluate(hull, buoyancy, flat)
	var trimmed: SimRigidBody = _trimmed_body(8.0, 5.0)
	_evaluate(hull, buoyancy, trimmed)
	assert_gt(hull.planing_lift_n, 0.0)
	var airborne: SimRigidBody = _floating_body(8.0)
	airborne.set_origin_world(Vector3(0.0, 1.0, 0.0))
	_evaluate(hull, buoyancy, airborne)
	assert_eq(hull.planing_lift_n, 0.0, "no water, no lift")


func test_downward_motion_adds_angle_of_attack() -> void:
	var models: Array = _models()
	var hull: HullModel = models[1]
	var buoyancy: BuoyancyModel = models[0]
	var steady: SimRigidBody = _trimmed_body(7.0, 4.0)
	_evaluate(hull, buoyancy, steady)
	var lift_steady: float = hull.planing_lift_n
	var sinking: SimRigidBody = _floating_body(7.0)
	sinking.basis = steady.basis
	sinking.velocity = steady.velocity + Vector3(0.0, -0.3, 0.0)
	_evaluate(hull, buoyancy, sinking)
	assert_gt(hull.planing_lift_n, lift_steady, "sinking into the water increases the lift: heave damping")
	var rising: SimRigidBody = _floating_body(7.0)
	rising.basis = steady.basis
	rising.velocity = steady.velocity + Vector3(0.0, 0.3, 0.0)
	_evaluate(hull, buoyancy, rising)
	assert_lt(hull.planing_lift_n, lift_steady)


func test_lateral_drag_opposes_sideslip_and_a_turn() -> void:
	var models: Array = _models()
	var hull: HullModel = models[1]
	var buoyancy: BuoyancyModel = models[0]
	var body: SimRigidBody = _floating_body(0.0)
	body.velocity = Vector3(0.5, 0.0, 0.0)  # sliding to starboard
	_evaluate(hull, buoyancy, body)
	assert_lt(body._force_sum.x, 0.0, "pushes back to port")
	assert_gt(hull.lateral_n, 0.0)
	var turning: SimRigidBody = _floating_body(0.0)
	turning.angular_velocity = Vector3(0.0, 1.0, 0.0)
	_evaluate(hull, buoyancy, turning)
	assert_lt(turning._torque_sum.y, 0.0, "the water resists the yaw")


func test_resistance_is_continuous_over_speed() -> void:
	var models: Array = _models()
	var hull: HullModel = models[1]
	var buoyancy: BuoyancyModel = models[0]
	var previous: float = -1.0
	var speed: float = 0.2
	while speed <= 12.0:
		var body: SimRigidBody = _floating_body(speed)
		_evaluate(hull, buoyancy, body)
		var total: float = hull.resistance_n
		if previous >= 0.0:
			assert_lt(absf(total - previous), maxf(0.35 * previous, 6.0), "no cliff at %s m/s" % speed)
		previous = total
		speed += 0.1


func test_wet_bottom_near_the_tail_is_narrower_and_carries_added_water() -> void:
	var models: Array = _models()
	var hull: HullModel = models[1]
	var buoyancy: BuoyancyModel = models[0]
	# Trimmed up 6 degrees and riding high: only the last part of the bottom is wet.
	var body: SimRigidBody = _trimmed_body(8.0, 6.0)
	body.position.y += 0.08
	_evaluate(hull, buoyancy, body)
	assert_lt(hull.wetted_length_m, 1.5, "a short wet length")
	assert_eq(hull.wetted_aft_m, 0.0, "starting at the transom")
	assert_lt(hull.planing_beam_m, 0.6, "narrower than the board's full width of 0.72 m")
	assert_gt(hull.planing_beam_m, 0.3, "but wider than the 0.243 m transom")
	# rho pi b^2 / 8 per metre, with b the outline's width along the wet length.
	var expected_added: float = 0.0
	var pieces: int = 100
	for k: int in pieces:
		var b: float = hull.board.width_at(hull.wetted_aft_m + (float(k) + 0.5) / float(pieces) * hull.wetted_length_m)
		expected_added += 1025.0 * PI * b * b / 8.0 * hull.wetted_length_m / float(pieces)
	assert_almost_eq(hull.heave_added_mass_kg, expected_added, 0.05 * expected_added, "about rho pi b^2 / 8 per metre")
	assert_gt(hull.pitch_added_inertia_kgm2, 0.0)
	# Level and deep in the water: the whole centreline is wet.
	var level: SimRigidBody = _floating_body(2.0)
	_evaluate(hull, buoyancy, level)
	assert_almost_eq(hull.wetted_length_m, 2.4, 1e-6)
	assert_almost_eq(hull.planing_beam_m, 0.524, 0.005, "the mean width of the whole outline (9-point average)")


func test_bow_down_board_planes_on_its_middle_with_a_dry_tail() -> void:
	var models: Array = _models()
	var hull: HullModel = models[1]
	var buoyancy: BuoyancyModel = models[0]
	# Nose down 2 degrees, tail lifted clear: the middle and the nose rocker are wet.
	var body: SimRigidBody = _trimmed_body(8.0, -2.0)
	body.position.y += 0.06
	_evaluate(hull, buoyancy, body)
	assert_gt(hull.wetted_aft_m, 0.1, "the transom is dry")
	assert_gt(hull.wetted_length_m, 0.5)
	assert_gt(hull.planing_lift_n, 0.0, "the rockered nose still lifts")


func test_identical_inputs_identical_outputs() -> void:
	var first_models: Array = _models()
	var second_models: Array = _models()
	var a: SimRigidBody = _floating_body(6.0)
	var b: SimRigidBody = _floating_body(6.0)
	_evaluate(first_models[1], first_models[0], a)
	_evaluate(second_models[1], second_models[0], b)
	assert_eq(b._force_sum, a._force_sum)


## The Savitsky plate again, level or heeled (starboard rail down), with only the hull's
## own forces summed. Returns the heel it ended up with, the lift, the sideways force in
## the world (the board heads along world -Z, so +X is to starboard), the roll torque about
## the bow axis (positive heels to starboard) and where the planing force acts along the
## board.
## The flat plate at 7 m/s, trimmed 4 degrees, its transom 7.5 cm deep, heeled heel_deg to
## starboard and sinking at sink_ms (negative: rising). Without a vee, so that the heel is
## all there is to the shape of its wet bottom.
func _heeled_plate(heel_deg: float, sink_ms: float = 0.0) -> Dictionary:
	var board_config: BoardConfig = _flat_board()
	board_config.deadrise_deg = 0.0
	var hull: HullModel = HullModel.new(board_config, _water())
	var buoyancy: BuoyancyModel = BuoyancyModel.new(board_config, _water())
	var body: SimRigidBody = _trimmed_body(7.0, 4.0)
	body.velocity.y = -sink_ms
	body.basis = Basis(Vector3.RIGHT, deg_to_rad(4.0)) * Basis(Vector3.FORWARD, deg_to_rad(heel_deg))
	var board: BoardConfig = hull.board
	var transom_local: Vector3 = Vector3(0.0, -0.5 * board.thickness_m, 0.5 * board.length_m)
	body.position.y -= body.point_world(transom_local).y + 0.075
	body.clear_forces()
	buoyancy.apply(body, FlatWater.new(), 0.0, G)
	body.clear_forces()
	hull.compute(body, buoyancy, FlatWater.new(), 0.0, G, body.mass_kg, 1.0)
	return {
		"heel_deg": rad_to_deg(SimMath.heel_rad(body.basis)),
		"lift": hull.planing_lift_n,
		"side_force": body._force_sum.x,
		"roll_torque": body._torque_sum.dot(-body.basis.z),
		"cop_z": hull.cop_local.z,
	}


func test_a_heeled_planing_plate_carries_its_lift_on_the_low_rail() -> void:
	# Heeled 15 degrees to starboard, the plate is wet further forward on its low rail and
	# the lift moves there: the planing force rights the board, pushes it sideways toward
	# the low rail (the centripetal force of a carved turn) and acts further forward than
	# on the level plate. Level, none of that happens.
	var level: Dictionary = _heeled_plate(0.0)
	var heeled: Dictionary = _heeled_plate(15.0)
	assert_almost_eq(float(heeled["heel_deg"]), 15.0, 0.2, "the test body is heeled 15 degrees")
	assert_almost_eq(float(level["side_force"]), 0.0, 1.0, "level: no sideways force")
	assert_almost_eq(float(level["roll_torque"]), 0.0, 1.0, "level: no roll torque from the planing lift")
	# Held at the same transom depth, the heeled plate's low rail is twice as deep and wet
	# twice as far forward, and the water climbs from it across the bottom (Wagner's pi/2,
	# NACA TN 4187 equation 2), so it carries a little more than the level plate: 1.32
	# times since U2 (0.91 with the still surface's wet width).
	assert_between(float(heeled["lift"]), 0.6 * float(level["lift"]), 1.4 * float(level["lift"]), "heeled: about the same lift")
	assert_gt(float(heeled["side_force"]), 0.1 * float(heeled["lift"]), "heeled: pushed toward the low rail")
	assert_lt(float(heeled["roll_torque"]), -50.0, "heeled: the lift on the low rail rights the board")
	assert_lt(float(heeled["cop_z"]), float(level["cop_z"]) - 0.1, "heeled: the force acts further forward")


func test_a_heeled_plate_meets_more_water_when_it_sinks_as_a_level_one_does() -> void:
	# Heeled 10 degrees, the spray root runs obliquely across the bottom, and most strips
	# are wet only toward the low rail. Sinking, the water reaches further across every one
	# of them, as it runs further along a level plate's root (Zarnick 1978: a section's
	# added mass grows with its immersion). So the lift grows with the sinking speed about
	# as much as on the level plate, and falls as much when the plate rises.
	var level: float = float(_heeled_plate(0.0)["lift"])
	var level_sinking: float = float(_heeled_plate(0.0, 0.1)["lift"])
	var heeled: float = float(_heeled_plate(10.0)["lift"])
	var heeled_sinking: float = float(_heeled_plate(10.0, 0.1)["lift"])
	var heeled_rising: float = float(_heeled_plate(10.0, -0.1)["lift"])
	var level_gain: float = level_sinking / level - 1.0
	var heeled_gain: float = heeled_sinking / heeled - 1.0
	gut.p("sinking at 0.1 m/s: level +%.0f %%, heeled 10 deg +%.0f %%; rising heeled %.0f %%" % [100.0 * level_gain, 100.0 * heeled_gain, 100.0 * (heeled_rising / heeled - 1.0)])
	assert_gt(level_gain, 0.2, "level: sinking adds lift (the root runs forward)")
	assert_between(heeled_gain, 0.75 * level_gain, 1.25 * level_gain, "heeled: about as much")
	assert_lt(heeled_rising, heeled * (1.0 - 0.5 * heeled_gain), "and rising takes it away")


## The flat plate of the Savitsky test with a vee of deadrise_deg, at 7 m/s and trim_deg,
## its transom 7.5 cm deep.
func _vee_plate(deadrise_deg: float, trim_deg: float) -> HullModel:
	var board: BoardConfig = _flat_board()
	board.deadrise_deg = deadrise_deg
	var hull: HullModel = HullModel.new(board, _water())
	var buoyancy: BuoyancyModel = BuoyancyModel.new(board, _water())
	var body: SimRigidBody = _trimmed_body(7.0, trim_deg)
	var transom_local: Vector3 = Vector3(0.0, -0.5 * board.thickness_m, 0.5 * board.length_m)
	body.position.y -= body.point_world(transom_local).y + 0.075
	_evaluate(hull, buoyancy, body)
	return hull


func test_a_vee_bottom_is_wet_near_its_keel_behind_the_spray_root() -> void:
	# A vee meets the water at its keel first: just behind the spray root only the middle
	# of the bottom is wet, and the chines are reached where the keel is deep enough for
	# the water piled up the vee (pi/2 of the still surface's cut, Wagner) to get there.
	# Savitsky (1964): the keel is wet b tan(beta) / (pi tan(tau)) further forward than the
	# chines, and his lift takes the mean of the two lengths. A flat bottom has none of it.
	var flat: HullModel = _vee_plate(0.0, 4.0)
	var vee: HullModel = _vee_plate(3.0, 4.0)
	var beam: float = 0.72
	var expected: float = beam * tan(deg_to_rad(3.0)) / (PI * tan(deg_to_rad(4.0)))
	assert_almost_eq(flat.chine_dry_length_m, 0.0, 1e-9, "flat: the chines are wet as far forward as the keel")
	assert_almost_eq(vee.chine_dry_length_m, expected, 0.02 * expected, "vee: Savitsky's L_k - L_c")
	assert_almost_eq(vee.wetted_length_m, flat.wetted_length_m, 0.01, "the keel is wet as far forward on both")
	assert_almost_eq(vee.lambda_ratio, flat.lambda_ratio - 0.5 * expected / beam, 0.01, "the mean wetted length is half the chine-dry part shorter")
	var front: float = vee.wetted_aft_m + vee.wetted_length_m
	var buoyancy: BuoyancyModel = BuoyancyModel.new(vee.board, _water())
	var body: SimRigidBody = _trimmed_body(7.0, 4.0)
	var transom_local: Vector3 = Vector3(0.0, -0.5 * vee.board.thickness_m, 0.5 * vee.board.length_m)
	body.position.y -= body.point_world(transom_local).y + 0.075
	_evaluate(vee, buoyancy, body)
	var near_root: Vector2 = vee._wet_width(buoyancy, front - 0.25 * expected)
	var behind: Vector2 = vee._wet_width(buoyancy, front - 1.5 * expected)
	assert_almost_eq(near_root.x, 0.25, 0.05, "a quarter of the chine-dry part behind the root: a quarter of the width wet")
	assert_almost_eq(near_root.y, 0.0, 1e-6, "around the keel")
	assert_almost_eq(behind.x, 1.0, 1e-6, "further aft: the whole width")


## A board planing at 8 m/s, trimmed 4 degrees with its transom 7.5 cm deep, skidding at
## slip_deg (its velocity turned toward starboard) and turning at yaw_rate_rads (positive
## turns the bow to port), heeled heel_deg (positive: starboard rail down). Returns the
## rails' force and yaw moment and the hull's sideways force in the world.
func _skidding_board(slip_deg: float, yaw_rate_rads: float = 0.0, heel_deg: float = 0.0, board: BoardConfig = null) -> Dictionary:
	var b: BoardConfig = board if board != null else _board()
	var buoyancy: BuoyancyModel = BuoyancyModel.new(b, _water())
	var hull: HullModel = HullModel.new(b, _water())
	var body: SimRigidBody = _trimmed_body(8.0, 4.0)
	body.basis = Basis(Vector3.RIGHT, deg_to_rad(4.0)) * Basis(Vector3.FORWARD, deg_to_rad(heel_deg))
	var transom_local: Vector3 = Vector3(0.0, -0.5 * b.thickness_m, 0.5 * b.length_m)
	body.position.y -= body.point_world(transom_local).y + 0.075
	var slip: float = deg_to_rad(slip_deg)
	body.velocity = Vector3(8.0 * sin(slip), 0.0, -8.0 * cos(slip))
	body.angular_velocity = Vector3(0.0, yaw_rate_rads, 0.0)
	body.clear_forces()
	buoyancy.apply(body, FlatWater.new(), 0.0, G, DT)
	body.clear_forces()
	hull.compute(body, buoyancy, FlatWater.new(), 0.0, G, body.mass_kg, DT)
	return {"grip": hull.rail_grip_n, "yaw": hull.rail_yaw_nm, "side": body._force_sum.x}


func test_the_rails_carry_nothing_until_the_board_skids_past_the_inception_angle() -> void:
	# NACA TN 4187: a flat planing bottom at a yaw angle carries no sideways force of its
	# own; the flow wets the leading rail's edge from about 7.5 degrees of yaw (level).
	assert_eq(float(_skidding_board(0.0)["grip"]), 0.0, "no skid, no grip")
	assert_eq(float(_skidding_board(5.0)["grip"]), 0.0, "5 degrees: the flow breaks clear of the edge")
	var nine: Dictionary = _skidding_board(9.0)
	var twelve: Dictionary = _skidding_board(12.0)
	assert_gt(float(nine["grip"]), 50.0, "9 degrees: the leading rail grips")
	assert_gt(float(twelve["grip"]), float(nine["grip"]), "and more at 12")
	# Fully engaged, about the dynamic pressure on the wetted edge (Ce' 1.0 to 1.3): at
	# 8 m/s, 1.15 x 33 kPa x the 3 cm edge wet over most of a metre of tail.
	assert_between(float(twelve["grip"]), 400.0, 1500.0)
	assert_lt(float(twelve["side"]), float(_skidding_board(5.0)["side"]) - 300.0, "it pushes back against the skid (to port)")
	gut.p("rail grip at 9 and 12 degrees of skid: %.0f and %.0f N" % [float(nine["grip"]), float(twelve["grip"])])


func test_a_spinning_hull_is_damped_by_its_rails() -> void:
	# Turning at 2 rad/s (115 degrees a second) at 8 m/s, the tail skids at up to 15
	# degrees: its rail grips and the moment opposes the spin, whichever way it turns.
	var to_port: Dictionary = _skidding_board(0.0, 2.0)
	var to_starboard: Dictionary = _skidding_board(0.0, -2.0)
	assert_lt(float(to_port["yaw"]), -100.0, "a spin to port is held back")
	assert_gt(float(to_starboard["yaw"]), 100.0, "a spin to starboard too")
	assert_almost_eq(float(to_port["yaw"]), -float(to_starboard["yaw"]), 0.05 * absf(float(to_port["yaw"])), "symmetric")
	gut.p("rail moment against a spin of 2 rad/s: %.0f N m (grip %.0f N)" % [float(to_port["yaw"]), float(to_port["grip"])])
	assert_eq(float(_skidding_board(0.0, 0.3)["grip"]), 0.0, "a slow carve (17 degrees a second) does not skid the rail")


func test_a_lowered_rail_grips_earlier_and_a_soft_rail_not_at_all() -> void:
	# TN 4187 figure 26a: with the leading edge rolled down the flow reaches it at a
	# smaller yaw angle (7.5 degrees level, about 5.7 with 5 degrees of roll).
	assert_eq(float(_skidding_board(6.5)["grip"]), 0.0, "level: not yet at 6.5 degrees")
	assert_gt(float(_skidding_board(6.5, 0.0, 5.0)["grip"]), 0.0, "starboard rail down, skidding to starboard: it grips")
	var soft: BoardConfig = _board().duplicate()
	soft.hard_rail_to_m = 0.0
	soft.soft_rail_from_m = 0.01
	assert_eq(float(_skidding_board(12.0, 0.0, 0.0, soft)["grip"]), 0.0, "a tucked rail lets the flow wrap round it")


## The default board with its tail one foot off (OFO) set to tail_width_m, planing at
## 7 m/s, trimmed 4 degrees with the transom 7.5 cm deep: the planing lift and the wetted
## length-to-beam ratio.
func _planing_with_tail(tail_width_m: float) -> Dictionary:
	var board: BoardConfig = _board().duplicate()
	board.tail_width_m = tail_width_m
	var buoyancy: BuoyancyModel = BuoyancyModel.new(board, _water())
	var hull: HullModel = HullModel.new(board, _water())
	var body: SimRigidBody = _trimmed_body(7.0, 4.0)
	body.position.y -= body.point_world(Vector3(0.0, -0.5 * board.thickness_m, 0.5 * board.length_m)).y + 0.075
	body.clear_forces()
	buoyancy.apply(body, FlatWater.new(), 0.0, G)
	hull.compute(body, buoyancy, FlatWater.new(), 0.0, G, body.mass_kg, 1.0)
	return {"lift": hull.planing_lift_n, "lambda": hull.lambda_ratio, "beam": hull.planing_beam_m}


func test_a_wider_tail_lifts_more_at_the_same_speed_and_trim() -> void:
	# Savitsky: the lift of a planing surface grows with its beam (C_L is per beam squared
	# and grows with the root of the wetted length-to-beam ratio, so at a given wetted
	# length the lift goes with the beam to the power 1.5), and a wider surface has a lower
	# length-to-beam ratio. Two boards 10 cm apart in tail width, the same in everything
	# else, at the same speed, trim and transom depth.
	var narrow: Dictionary = _planing_with_tail(0.40)
	var wide: Dictionary = _planing_with_tail(0.50)
	assert_gt(float(wide["beam"]), float(narrow["beam"]) + 0.04, "the wet bottom is wider")
	assert_lt(float(wide["lambda"]), float(narrow["lambda"]), "with a lower length-to-beam ratio")
	var beam_ratio: float = float(wide["beam"]) / float(narrow["beam"])
	assert_gt(float(wide["lift"]) / float(narrow["lift"]), pow(beam_ratio, 1.2), "and lifts more, about as the beam to the power 1.5 (%.0f against %.0f N)" % [float(wide["lift"]), float(narrow["lift"])])


## The bare hull loaded like the windsurfer getting onto the plane (92 kg, the centre of
## mass 0.15 m up and 0.45 m aft: the sailor back in the straps), towed at a steady speed
## on a straight course, free to rise and pitch: its resistance once settled (the mean
## over the last second of three).
func _towed_resistance_n(board: BoardConfig, speed_ms: float) -> float:
	var buoyancy: BuoyancyModel = BuoyancyModel.new(board, _water())
	var hull: HullModel = HullModel.new(board, _water())
	var body: SimRigidBody = _floating_body(speed_ms)
	body.set_mass_properties(92.0, Basis.IDENTITY.scaled(Vector3(50.0, 6.0, 46.0)), Vector3(0.0, 0.15, 0.45))
	var water: FlatWater = FlatWater.new()
	var drag_sum: float = 0.0
	var samples: int = 0
	for i: int in int(3.0 / DT):
		body.add_force(Vector3(0.0, -G * body.mass_kg, 0.0))
		buoyancy.apply(body, water, i * DT, G, DT)
		hull.compute(body, buoyancy, water, i * DT, G, body.mass_kg, DT)
		body.integrate(DT)
		# The tow holds the course and the speed; heave and pitch are free.
		body.velocity.x = 0.0
		body.velocity.z = -speed_ms
		body.angular_velocity = Vector3(body.angular_velocity.x, 0.0, 0.0)
		if i * DT >= 2.0:
			drag_sum += hull.resistance_n
			samples += 1
	return drag_sum / float(samples)


## The highest resistance between 3 and 5 m/s: the hump a sail has to pull the board over.
func _hump_resistance_n(board: BoardConfig) -> float:
	var hump: float = 0.0
	for speed: float in [3.0, 3.5, 4.0, 4.5, 5.0]:
		hump = maxf(hump, _towed_resistance_n(board, speed))
	return hump


func test_a_wider_tail_needs_less_thrust_over_the_hump() -> void:
	# "A wider tail planes earlier": with the same sail, a board gets onto the plane when
	# the sail's drive exceeds the hull's resistance through the hump. Two boards 10 cm
	# apart in tail width (one foot off the tail), the same in everything else, towed with
	# the sailor's weight aft as when getting going: the wider tail lifts more, sits less
	# deep and trims less steeply (a narrow tail squats to 12 to 14 degrees at 3 m/s), and
	# needs less thrust.
	var narrow: BoardConfig = _board().duplicate()
	narrow.tail_width_m = 0.40
	var wide: BoardConfig = _board().duplicate()
	wide.tail_width_m = 0.50
	var narrow_hump: float = _hump_resistance_n(narrow)
	var wide_hump: float = _hump_resistance_n(wide)
	gut.p("hump resistance 3 to 5 m/s: tail 0.40 m %.0f N, tail 0.50 m %.0f N" % [narrow_hump, wide_hump])
	assert_lt(wide_hump, 0.9 * narrow_hump, "the wide tail needs at least 10 %% less thrust (%.0f against %.0f N)" % [wide_hump, narrow_hump])


## The flat plate of the Savitsky test at a forward speed, its transom 7.5 cm deep, with a
## given planing_buoyancy_factor.
func _plate_with_buoyancy_factor(speed_ms: float, factor: float) -> Array:
	var board: BoardConfig = _flat_board()
	board.planing_buoyancy_factor = factor
	var buoyancy: BuoyancyModel = BuoyancyModel.new(board, _water())
	var hull: HullModel = HullModel.new(board, _water())
	var body: SimRigidBody = _trimmed_body(speed_ms, 4.0)
	var transom_local: Vector3 = Vector3(0.0, -0.5 * board.thickness_m, 0.5 * board.length_m)
	body.position.y -= body.point_world(transom_local).y + 0.075
	_evaluate(hull, buoyancy, body)
	return [hull, buoyancy]


func test_a_planing_bottom_keeps_only_its_share_of_the_buoyancy() -> void:
	# Default (factor 1): Archimedes at every speed, nothing taken away.
	var archimedes: Array = _plate_with_buoyancy_factor(7.0, 1.0)
	assert_eq((archimedes[0] as HullModel).buoyancy_correction_n, 0.0, "the default keeps Archimedes")
	# Shuford's half (Zarnick 1978): none of it below the semi-displacement range (Froude
	# 0.4 on the 2.4 m hull is 1.94 m/s), all of it once planing (Froude 1.0, 4.85 m/s),
	# half of it half-way.
	var slow: Array = _plate_with_buoyancy_factor(1.5, 0.5)
	assert_eq((slow[0] as HullModel).buoyancy_correction_n, 0.0, "a displacement hull floats on Archimedes")
	var planing: Array = _plate_with_buoyancy_factor(7.0, 0.5)
	var grid_n: float = (planing[1] as BuoyancyModel).buoyancy_force_n
	assert_almost_eq((planing[0] as HullModel).buoyancy_correction_n, 0.5 * grid_n, 1e-6 * grid_n, "a planing bottom keeps half")
	var middle_ms: float = 0.7 * sqrt(G * 2.4) / cos(deg_to_rad(4.0))  # along the keel
	var middle: Array = _plate_with_buoyancy_factor(middle_ms, 0.5)
	var middle_grid_n: float = (middle[1] as BuoyancyModel).buoyancy_force_n
	assert_almost_eq((middle[0] as HullModel).buoyancy_correction_n, 0.25 * middle_grid_n, 1e-3 * middle_grid_n, "half of the loss at Froude 0.7")


## U2: the hull's own planing share is its planing lift over what it carries (the lift plus
## the buoyancy it keeps), whoever carries the rest of the weight; the planing ratio is the
## same lift over the whole weight, so it falls when the fin and the rig carry part of it.
func test_the_planing_share_counts_only_what_the_hull_carries() -> void:
	var plate: Array = _plate_with_buoyancy_factor(7.0, 1.0)
	var hull: HullModel = plate[0] as HullModel
	var buoyancy: BuoyancyModel = plate[1] as BuoyancyModel
	assert_gt(hull.planing_lift_n, 0.0, "the plate planes")
	assert_almost_eq(hull.hull_load_n, hull.planing_lift_n + buoyancy.buoyancy_force_n, 1e-6, "the hull carries its lift and its buoyancy")
	assert_almost_eq(hull.planing_share, hull.planing_lift_n / hull.hull_load_n, 1e-9, "the share of it that is dynamic")
	# The same hull in a kit three times as heavy (the rest carried by the fin and the rig):
	# the ratio to the whole weight drops to a third, the hull's own share does not move.
	var share: float = hull.planing_share
	var ratio: float = hull.planing_ratio
	var body: SimRigidBody = _trimmed_body(7.0, 4.0)
	var transom_local: Vector3 = Vector3(0.0, -0.5 * _flat_board().thickness_m, 0.5 * _flat_board().length_m)
	body.position.y -= body.point_world(transom_local).y + 0.075
	body.clear_forces()
	buoyancy.apply(body, FlatWater.new(), 0.0, G)
	hull.compute(body, buoyancy, FlatWater.new(), 0.0, G, 3.0 * body.mass_kg, 1.0)
	assert_almost_eq(hull.planing_share, share, 1e-9, "the hull's own share does not see the rest of the weight")
	assert_almost_eq(hull.planing_ratio, ratio / 3.0, 1e-6, "the ratio to the whole weight does")


## U2: Savitsky's porpoising limit as OpenPlaning fits his chart: at x = sqrt(C_L / 2) =
## 0.2 the three cubics give 3.823, 4.970 and 5.782 degrees for 0, 10 and 20 degrees of
## deadrise (worked by hand from the coefficients), and the quadratic through them 3.953 at
## the board's 1 degree. The limit falls as the speed rises at the same load.
func test_the_critical_trim_follows_savitskys_chart_as_openplaning_fits_it() -> void:
	# C_L = 0.08 at 10 m/s on a 0.5 m beam: 0.08 * 0.5 * 1025 * 100 * 0.25 = 1025 N.
	assert_almost_eq(HullModel.critical_trim_deg_for(1025.0, 10.0, 0.5, 0.0, 1025.0), 3.823, 0.001, "flat bottom")
	assert_almost_eq(HullModel.critical_trim_deg_for(1025.0, 10.0, 0.5, 10.0, 1025.0), 4.970, 0.001, "10 degrees of deadrise")
	assert_almost_eq(HullModel.critical_trim_deg_for(1025.0, 10.0, 0.5, 20.0, 1025.0), 5.782, 0.001, "20 degrees of deadrise")
	assert_almost_eq(HullModel.critical_trim_deg_for(1025.0, 10.0, 0.5, 1.0, 1025.0), 3.953, 0.001, "the tail's 1 degree vee")
	var previous: float = 90.0
	for speed_ms: float in [8.0, 10.0, 12.0, 14.0, 16.0]:
		var limit: float = HullModel.critical_trim_deg_for(700.0, speed_ms, 0.57, 1.0, 1025.0)
		assert_lt(limit, previous, "the limit falls with speed (%.0f m/s)" % speed_ms)
		previous = limit
	# Beyond the fit's ends it is held, never turned round.
	var light: float = HullModel.critical_trim_deg_for(50.0, 20.0, 0.57, 1.0, 1025.0)
	var lighter: float = HullModel.critical_trim_deg_for(10.0, 20.0, 0.57, 1.0, 1025.0)
	assert_almost_eq(light, lighter, 1e-9, "held at x = 0.07 below it")
