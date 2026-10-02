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


## A board with the default size but a flat bottom and no taper: a prismatic planing plate,
## for which Savitsky's formula is the reference.
func _flat_board() -> BoardConfig:
	var board: BoardConfig = _board().duplicate()
	board.nose_rocker_m = 0.0
	board.tail_rocker_m = 0.0
	board.width_taper = 0.0
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
	var re: float = 2.0 * maxf(buoyancy.wetted_length_m, 0.3) / 1.19e-6
	var cf: float = 0.075 / pow(log(re) / log(10.0) - 2.0, 2.0)
	assert_almost_eq(hull.friction_n, cf * 0.5 * 1025.0 * 4.0 * buoyancy.wetted_area_m2, 1e-3)
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
	var cl: float = cl_flat - 0.0065 * 2.0 * pow(cl_flat, 0.6)
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
	assert_lt(hull.planing_beam_m, 0.68, "narrower than the board's full width of 0.72 m")
	assert_gt(hull.planing_beam_m, 0.5, "but wider than the 0.504 m transom")
	var expected_added: float = 1025.0 * PI * hull.planing_beam_m * hull.planing_beam_m / 8.0 * hull.wetted_length_m
	assert_almost_eq(hull.heave_added_mass_kg, expected_added, 0.1 * expected_added, "about rho pi b^2 / 8 per metre")
	assert_gt(hull.pitch_added_inertia_kgm2, 0.0)
	# Level and deep in the water: the whole centreline is wet.
	var level: SimRigidBody = _floating_body(2.0)
	_evaluate(hull, buoyancy, level)
	assert_almost_eq(hull.wetted_length_m, 2.4, 1e-6)
	assert_almost_eq(hull.planing_beam_m, 0.72 * (1.0 - 0.3 / 3.0), 0.02, "the mean width of the whole tapered bottom (9-point average)")


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
