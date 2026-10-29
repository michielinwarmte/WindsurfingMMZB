extends GutTest
## Buoyancy and heave damping (PHYSICS_SPEC.md section 6). The tests use the default board
## (2.40 x 0.72 x 0.12 m, 120 L, with its real outline and thickness profile); the grid and
## stiffness numbers were computed independently of the code for that board (section 6.7).
## The equilibrium tests use the default water.

const DT: float = 1.0 / 240.0
const G: float = 9.81


func _board() -> BoardConfig:
	return (load("res://config/board_freeride_240.tres") as BoardConfig).duplicate()


func _water() -> WaterConfig:
	return load("res://config/water_default.tres")


## A body with the legacy centre of mass 0.15 m above the origin and 0.10 m aft, which is
## stable in roll on its own, so the buoyancy model can be tested without a sailor.
func _body(mass_kg: float) -> SimRigidBody:
	var body: SimRigidBody = SimRigidBody.new()
	var inertia: Basis = Basis.IDENTITY.scaled(Vector3(50.0, 52.0, 46.0))
	body.set_mass_properties(mass_kg, inertia, Vector3(0.0, 0.15, 0.10))
	return body


func _settle(body: SimRigidBody, model: BuoyancyModel, seconds: float) -> void:
	var water: FlatWater = FlatWater.new()
	var steps: int = int(seconds / DT)
	for i: int in steps:
		body.add_force(Vector3(0.0, -G * body.mass_kg, 0.0))
		model.apply(body, water, i * DT, G)
		body.integrate(DT)


func test_grid_geometry_matches_the_spec() -> void:
	var board: BoardConfig = _board()
	var model: BuoyancyModel = BuoyancyModel.new(board, _water())
	assert_eq(model.sample_points.size(), 21)
	var total: float = 0.0
	for v: float in model.sample_volumes_m3:
		total += v
	assert_almost_eq(total, 0.120, 1e-9, "the point volumes add up to the board volume")
	var tail: Vector3 = model.sample_points[model.tail_centre_index]
	var bow: Vector3 = model.sample_points[model.bow_centre_index]
	assert_almost_eq(tail, Vector3(0.0, -0.06, 1.2), Vector3.ONE * 1e-6, "tail row: z aft, the bottom flat to the tail (U1.4)")
	assert_almost_eq(bow, Vector3(0.0, 0.02, -1.2), Vector3.ONE * 1e-6, "bow row: z forward, raised by the nose rocker")
	# Middle row (row 3, 1.2 m from the tail, 0.1 m forward of the widest point): the rails
	# at +-0.3586 m. The nose tip is thin and narrow (1.31 L per point), the middle thick and
	# wide (9.85 L), as section 6.1's table has it.
	var middle_rail: Vector3 = model.sample_points[9]
	assert_almost_eq(middle_rail, Vector3(-0.3586, -0.06, 0.0), Vector3.ONE * 1e-4)
	assert_almost_eq(model.sample_volumes_m3[model.bow_centre_index] * 1000.0, 1.308, 0.01)
	assert_almost_eq(model.sample_volumes_m3[10] * 1000.0, 9.852, 0.01, "middle point")
	assert_almost_eq(model.planform_area_m2, 1.346, 0.002, "the outline's area")


func test_the_outline_has_the_shapers_widths() -> void:
	# A shaper's three numbers: the widest point (0.72 m, 1.10 m from the tail), the width
	# one foot off the tail (0.45 m) and one foot off the nose (0.45 m). The outline is
	# widest there and narrows toward both ends; the thickness peaks there too.
	var board: BoardConfig = _board()
	assert_almost_eq(board.width_at(1.10), 0.72, 1e-6, "widest point")
	assert_almost_eq(board.width_at(0.3048), 0.45, 1e-6, "one foot off the tail")
	assert_almost_eq(board.width_at(2.4 - 0.3048), 0.45, 1e-6, "one foot off the nose")
	assert_lt(board.width_at(1.0), 0.72)
	assert_lt(board.width_at(1.2), 0.72)
	assert_between(board.width_at(0.0), 0.2, 0.3, "a square pin tail: the transom about a quarter metre")
	assert_between(board.width_at(2.4), 0.2, 0.35, "a rounded nose")
	assert_almost_eq(board.thickness_at(1.10), 0.12, 1e-6)
	assert_almost_eq(board.thickness_at(0.0), 0.055, 1e-6)
	assert_almost_eq(board.thickness_at(2.4), 0.04, 1e-6)
	# A wider tail is wider behind the widest point only.
	var wide: BoardConfig = _board()
	wide.tail_width_m = 0.55
	assert_gt(wide.width_at(0.3), board.width_at(0.3) + 0.09)
	assert_almost_eq(wide.width_at(1.5), board.width_at(1.5), 1e-9, "the nose half is unchanged")
	# The rail is hard in the tail and soft in the nose.
	assert_eq(board.rail_hardness(0.5), 1.0)
	assert_eq(board.rail_hardness(2.2), 0.0)
	assert_almost_eq(board.rail_hardness(1.6), 0.5, 1e-6)


func test_single_point_archimedes() -> void:
	var model: BuoyancyModel = BuoyancyModel.new(_board(), _water())
	var body: SimRigidBody = SimRigidBody.new()
	body.set_mass_properties(1.0, Basis.IDENTITY, Vector3.ZERO)
	# Put the board so high that only the middle row's deepest points matter: instead,
	# check the force of the whole grid at a known immersion against a direct sum.
	body.set_origin_world(Vector3(0.0, 0.0, 0.0))  # bottom at -0.06, middle row 0.06 m under
	model.apply(body, FlatWater.new(), 0.0, G)
	var expected: float = 0.0
	for k: int in model.sample_points.size():
		var depth: float = -model.sample_points[k].y
		if depth > 0.0:
			expected += 1025.0 * G * model.sample_volumes_m3[k] * clampf(depth / 0.12, 0.0, 1.0)
	assert_almost_eq(model.buoyancy_force_n, expected, expected * 1e-5)
	assert_true(model.is_floating)
	assert_gt(model.wetted_area_m2, 0.5)


func test_dry_board() -> void:
	var model: BuoyancyModel = BuoyancyModel.new(_board(), _water())
	var body: SimRigidBody = _body(94.0)
	body.set_origin_world(Vector3(0.0, 1.0, 0.0))
	model.apply(body, FlatWater.new(), 0.0, G)
	assert_false(model.is_floating)
	assert_eq(model.submersion_ratio, 0.0)
	assert_eq(model.buoyancy_force_n, 0.0)
	assert_eq(model.wetted_area_m2, 0.0)


func test_static_equilibrium_is_archimedes() -> void:
	var model: BuoyancyModel = BuoyancyModel.new(_board(), _water())
	var body: SimRigidBody = _body(94.0)
	body.set_origin_world(Vector3(0.0, 0.5, 0.0))
	_settle(body, model, 6.0)
	var expected_volume: float = 94.0 / 1025.0
	assert_almost_eq(model.submerged_volume_m3, expected_volume, expected_volume * 0.02, "94 kg displaces 91.7 L")
	assert_almost_eq(model.submersion_ratio, 0.764, 0.015)
	assert_almost_eq(body.origin_world().y, -0.038, 0.004, "origin about 4 cm under")
	assert_lt(absf(rad_to_deg(SimMath.pitch_rad(body.basis))), 0.5, "level in pitch")
	assert_lt(absf(rad_to_deg(SimMath.heel_rad(body.basis))), 0.1, "level in roll")
	assert_lt(body.velocity.length(), 0.01, "at rest")
	# The 90 kg of the plan's example: 87.8 L, 73 %.
	var lighter: SimRigidBody = _body(90.0)
	lighter.set_origin_world(Vector3(0.0, 0.5, 0.0))
	_settle(lighter, model, 6.0)
	assert_almost_eq(model.submersion_ratio, 0.732, 0.015)


func test_pitch_and_roll_stiffness() -> void:
	var model: BuoyancyModel = BuoyancyModel.new(_board(), _water())
	var body: SimRigidBody = _body(94.0)
	body.set_origin_world(Vector3(0.0, 0.5, 0.0))
	_settle(body, model, 6.0)
	var level_origin: Vector3 = body.origin_world()
	var com: Vector3 = body.position
	# Hold the body still, pitch it 1 degree bow up about the centre of mass and read the torque.
	var pitched: SimRigidBody = _body(94.0)
	pitched.basis = Basis(Vector3.RIGHT, deg_to_rad(1.0))
	pitched.position = com
	var torque_up: Vector3 = _buoyancy_torque(pitched, model)
	pitched.basis = Basis(Vector3.RIGHT, deg_to_rad(-1.0))
	var torque_down: Vector3 = _buoyancy_torque(pitched, model)
	var pitch_stiffness: float = (torque_down.x - torque_up.x) / deg_to_rad(2.0)
	assert_almost_eq(pitch_stiffness, 3100.0, 3100.0 * 0.08, "pitch stiffness about 3100 N m per rad, restoring")
	assert_lt(torque_up.x, torque_down.x, "bow up gives a bow-down torque")
	# Roll: 1 degree to starboard gives a restoring torque of about +8.0 N m about +Z.
	pitched.basis = Basis(Vector3.FORWARD, deg_to_rad(1.0))
	var torque_roll: Vector3 = _buoyancy_torque(pitched, model)
	assert_almost_eq(torque_roll.z, 8.0, 8.0 * 0.1)
	assert_almost_eq(level_origin.y, -0.038, 0.004)


func _buoyancy_torque(body: SimRigidBody, model: BuoyancyModel) -> Vector3:
	body.velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.clear_forces()
	model.apply(body, FlatWater.new(), 0.0, G)
	var torque: Vector3 = body._torque_sum
	body.clear_forces()
	return torque


func test_rights_itself_and_settles() -> void:
	var model: BuoyancyModel = BuoyancyModel.new(_board(), _water())
	var body: SimRigidBody = _body(94.0)
	body.set_origin_world(Vector3(0.0, 0.5, 0.0))
	_settle(body, model, 6.0)
	body.basis = Basis(Vector3.FORWARD, deg_to_rad(10.0)) * body.basis
	_settle(body, model, 8.0)
	assert_lt(absf(rad_to_deg(SimMath.heel_rad(body.basis))), 1.5, "heel decays from 10 degrees")
	body.basis = Basis(Vector3.RIGHT, deg_to_rad(5.0)) * body.basis
	_settle(body, model, 5.0)
	assert_lt(absf(rad_to_deg(SimMath.pitch_rad(body.basis))), 0.5, "pitch decays from 5 degrees")


func test_drop_test_damping() -> void:
	var model: BuoyancyModel = BuoyancyModel.new(_board(), _water())
	var body: SimRigidBody = _body(94.0)
	body.set_origin_world(Vector3(0.0, 0.5, 0.0))
	var water: FlatWater = FlatWater.new()
	var lowest: float = INF
	var crossings: int = 0
	var previous_velocity: float = 0.0
	for i: int in int(4.0 / DT):
		body.add_force(Vector3(0.0, -G * body.mass_kg, 0.0))
		model.apply(body, water, i * DT, G)
		body.integrate(DT)
		lowest = minf(lowest, body.origin_world().y)
		if i > 0 and previous_velocity < 0.0 and body.velocity.y >= 0.0:
			crossings += 1
		previous_velocity = body.velocity.y
	assert_lt(crossings, 8, "a handful of bounces, not a trampoline")
	assert_almost_eq(body.origin_world().y, -0.038, 0.01, "within a centimetre of equilibrium after 4 s")
	assert_gt(lowest, -0.3, "does not dive deeper than 30 cm")


## Potential energy stored in the buoyancy "spring" of every sample point: the integral of
## the Archimedes force over the depth (quadratic while the column fills, then linear).
func _buoyancy_energy(model: BuoyancyModel, board: BoardConfig, water_config: WaterConfig) -> float:
	var energy: float = 0.0
	for k: int in model.sample_points.size():
		var depth: float = model.point_depths_m[k]
		if depth <= 0.0:
			continue
		var thickness: float = board.thickness_m
		var integral: float = depth * depth / (2.0 * thickness) if depth < thickness else 0.5 * thickness + (depth - thickness)
		energy += water_config.density_kg_m3 * G * model.sample_volumes_m3[k] * integral
	return energy


func test_no_damping_conserves_energy() -> void:
	# Without the damping terms the buoyancy forces are a conservative spring, so the sum of
	# kinetic, gravitational and buoyancy energy must stay constant: nothing in the model or
	# the integrator may quietly take energy out (or put it in). The board keeps bouncing.
	var board: BoardConfig = _board()
	var water_config: WaterConfig = WaterConfig.new()
	water_config.damping_linear_ns_m = 0.0
	water_config.damping_quadratic_ns2_m2 = 0.0
	var model: BuoyancyModel = BuoyancyModel.new(board, water_config)
	var body: SimRigidBody = _body(94.0)
	var water: FlatWater = FlatWater.new()
	# Rest energy, from a damped settle.
	var damped: BuoyancyModel = BuoyancyModel.new(board, _water())
	_settle(body, damped, 8.0)
	var rest_y: float = body.origin_world().y
	body.clear_forces()
	model.apply(body, water, 0.0, G)
	var rest_energy: float = body.mass_kg * G * body.position.y + _buoyancy_energy(model, board, water_config)
	body.clear_forces()
	# Released 10 cm above the rest height, from rest.
	body.set_origin_world(Vector3(0.0, rest_y + 0.10, 0.0))
	body.velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	var initial_energy: float = -INF
	var lowest_energy: float = INF
	var highest_energy: float = -INF
	var late_heights: Vector2 = Vector2(INF, -INF)  # lowest, highest
	var late_pitches_deg: Vector2 = Vector2(INF, -INF)
	for i: int in int(6.0 / DT):
		body.add_force(Vector3(0.0, -G * body.mass_kg, 0.0))
		model.apply(body, water, i * DT, G)
		var energy: float = body.kinetic_energy() + body.mass_kg * G * body.position.y + _buoyancy_energy(model, board, water_config)
		if i == 0:
			initial_energy = energy
		lowest_energy = minf(lowest_energy, energy)
		highest_energy = maxf(highest_energy, energy)
		body.integrate(DT)
		if i * DT > 4.0:
			var height: float = body.origin_world().y
			var pitch_deg: float = rad_to_deg(SimMath.pitch_rad(body.basis))
			late_heights = Vector2(minf(late_heights.x, height), maxf(late_heights.y, height))
			late_pitches_deg = Vector2(minf(late_pitches_deg.x, pitch_deg), maxf(late_pitches_deg.y, pitch_deg))
	var excess: float = initial_energy - rest_energy
	assert_gt(excess, 1.0, "the release stores a few joules")
	assert_lt(highest_energy - initial_energy, 0.03 * excess, "no energy appears")
	assert_lt(initial_energy - lowest_energy, 0.03 * excess, "no energy disappears")
	# Undamped, the bounce turns into a pitch tumble of 30 to 40 degrees, so whether the
	# height still swings 2 cm after 4 s depends on the phase (U1.4, the flat tail); the
	# board must still swing in height or in pitch.
	var height_swing: float = late_heights.y - late_heights.x
	var pitch_swing_deg: float = late_pitches_deg.y - late_pitches_deg.x
	gut.p("after 4 s: height swing %.3f m, pitch swing %.1f deg" % [height_swing, pitch_swing_deg])
	assert_true(height_swing > 0.02 or pitch_swing_deg > 2.0, "it is still moving after 4 s (height swing %.3f m, pitch swing %.1f deg)" % [height_swing, pitch_swing_deg])


func test_identical_runs() -> void:
	var a: SimRigidBody = _body(94.0)
	var b: SimRigidBody = _body(94.0)
	var model_a: BuoyancyModel = BuoyancyModel.new(_board(), _water())
	var model_b: BuoyancyModel = BuoyancyModel.new(_board(), _water())
	a.set_origin_world(Vector3(0.0, 0.5, 0.0))
	b.set_origin_world(Vector3(0.0, 0.5, 0.0))
	_settle(a, model_a, 2.0)
	_settle(b, model_b, 2.0)
	assert_eq(a.position, b.position)
	assert_eq(a.basis, b.basis)
