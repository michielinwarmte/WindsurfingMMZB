extends GutTest
## The integrator tests the plan asks for (Phase 2): free fall, no rotation from a force
## through the centre of mass, the torque of an off-centre force, conservation of angular
## momentum, and determinism.

const G: float = 9.81
const DT: float = 1.0 / 240.0


func _make_body() -> SimRigidBody:
	var body: SimRigidBody = SimRigidBody.new()
	# A 2 x 1 x 4 m box of 90 kg: distinct inertia about each axis.
	var inertia: Basis = Basis.IDENTITY.scaled(Vector3(
		90.0 / 12.0 * (1.0 + 16.0), 90.0 / 12.0 * (4.0 + 16.0), 90.0 / 12.0 * (4.0 + 1.0)))
	body.set_mass_properties(90.0, inertia, Vector3.ZERO)
	return body


func test_free_fall_matches_half_g_t_squared() -> void:
	var body: SimRigidBody = _make_body()
	var steps: int = 240
	for i: int in steps:
		body.add_force(Vector3(0.0, -G * body.mass_kg, 0.0))
		body.integrate(DT)
	var expected: float = -0.5 * G * 1.0
	assert_almost_eq(body.position.y, expected, absf(expected) * 0.01, "1 s of free fall, within 1 %")
	assert_almost_eq(body.velocity.y, -G, 1e-3)
	assert_eq(body.angular_velocity, Vector3.ZERO, "falling does not spin")


func test_force_through_the_centre_of_mass_causes_no_rotation() -> void:
	var body: SimRigidBody = _make_body()
	body.set_mass_properties(body.mass_kg, body.inertia_body, Vector3(0.1, 0.5, -0.2))
	for i: int in 100:
		body.add_force_at(body.position, Vector3(300.0, 100.0, -50.0))
		body.integrate(DT)
	assert_almost_eq(body.angular_velocity, Vector3.ZERO, Vector3.ONE * 1e-9)
	assert_almost_eq(body.basis.x, Vector3.RIGHT, Vector3.ONE * 1e-9)
	assert_almost_eq(body.basis.y, Vector3.UP, Vector3.ONE * 1e-9)
	assert_almost_eq(body.basis.z, Vector3.BACK, Vector3.ONE * 1e-9)


func test_off_centre_force_gives_the_expected_torque() -> void:
	var body: SimRigidBody = _make_body()
	# 100 N upward at 1 m aft of the centre of mass: torque = r x F = (0,0,1) x (0,100,0) = (-100, 0, 0).
	body.add_force_at(body.position + Vector3(0.0, 0.0, 1.0), Vector3(0.0, 100.0, 0.0))
	body.integrate(DT)
	var inertia_x: float = body.inertia_body.x.x
	assert_almost_eq(body.angular_velocity, Vector3(-100.0 / inertia_x * DT, 0.0, 0.0), Vector3.ONE * 1e-9,
		"negative pitch rate: the stern lifts and the bow drops")
	assert_almost_eq(body.velocity, Vector3(0.0, 100.0 / body.mass_kg * DT, 0.0), Vector3.ONE * 1e-9)


func test_yaw_sign_matches_the_conventions() -> void:
	# A negative torque about +Y must turn the bow to starboard (the heading increases).
	var body: SimRigidBody = _make_body()
	for i: int in 240:
		body.add_torque(Vector3(0.0, -10.0, 0.0))
		body.integrate(DT)
	assert_lt(body.angular_velocity.y, 0.0)
	var heading: float = rad_to_deg(SimMath.heading_rad(body.basis))
	assert_gt(heading, 0.0)
	assert_lt(heading, 90.0, "turned right, less than a quarter turn")


func test_torque_free_spin_keeps_its_angular_momentum() -> void:
	var body: SimRigidBody = _make_body()
	body.angular_velocity = Vector3(0.0, 2.0, 0.0)  # about a principal axis: exact
	var momentum_before: Vector3 = body.angular_momentum()
	for i: int in 480:
		body.integrate(DT)
	assert_almost_eq(body.angular_momentum(), momentum_before, Vector3.ONE * 1e-6)
	assert_almost_eq(body.angular_velocity, Vector3(0.0, 2.0, 0.0), Vector3.ONE * 1e-6)

	# About a tilted axis the body tumbles, but the momentum vector must stay the same.
	var tumbling: SimRigidBody = _make_body()
	tumbling.angular_velocity = Vector3(1.0, 0.5, 1.5)
	var momentum: Vector3 = tumbling.angular_momentum()
	for i: int in 480:
		tumbling.integrate(DT)
	var drift: float = (tumbling.angular_momentum() - momentum).length() / momentum.length()
	assert_lt(drift, 0.02, "angular momentum drifts less than 2 % in 2 s of tumbling")


func test_identical_inputs_give_identical_results() -> void:
	var a: SimRigidBody = _make_body()
	var b: SimRigidBody = _make_body()
	for i: int in 300:
		for body: SimRigidBody in [a, b]:
			body.add_force_at(body.position + Vector3(0.3, 0.0, -0.9), Vector3(120.0, -800.0, 40.0))
			body.add_force(Vector3(0.0, 800.0, 0.0))
			body.integrate(DT)
	assert_eq(a.position, b.position)
	assert_eq(a.velocity, b.velocity)
	assert_eq(a.angular_velocity, b.angular_velocity)
	assert_eq(a.basis, b.basis)


func test_changing_the_centre_of_mass_does_not_move_the_board() -> void:
	var body: SimRigidBody = _make_body()
	body.basis = Basis(Vector3.UP, deg_to_rad(-40.0))
	body.set_origin_world(Vector3(10.0, 0.0, -5.0))
	var origin_before: Vector3 = body.origin_world()
	body.set_mass_properties(body.mass_kg, body.inertia_body, Vector3(0.2, 1.0, 0.4))
	assert_almost_eq(body.origin_world(), origin_before, Vector3.ONE * 1e-9)
	assert_almost_eq(body.point_world(Vector3.ZERO), origin_before, Vector3.ONE * 1e-9)


func test_point_velocity_includes_rotation() -> void:
	var body: SimRigidBody = _make_body()
	body.angular_velocity = Vector3(0.0, 1.0, 0.0)
	# The bow point (0,0,-1) of a body spinning +1 rad/s about +Y moves toward port (-X).
	var v: Vector3 = body.point_velocity(body.position + Vector3(0.0, 0.0, -1.0))
	assert_almost_eq(v, Vector3(-1.0, 0.0, 0.0), Vector3.ONE * 1e-9)


func test_keeping_the_centre_of_mass_moves_the_board_instead() -> void:
	var body: SimRigidBody = SimRigidBody.new()
	body.set_mass_properties(90.0, Basis.IDENTITY.scaled(Vector3(50.0, 6.0, 46.0)), Vector3.ZERO)
	body.position = Vector3(1.0, 2.0, 3.0)
	body.set_mass_properties(90.0, body.inertia_body, Vector3(0.0, 0.5, 0.0), true)
	assert_eq(body.position, Vector3(1.0, 2.0, 3.0), "the centre of mass stays on its path")
	assert_almost_eq(body.origin_world(), Vector3(1.0, 1.5, 3.0), Vector3.ONE * 1e-9, "the board moved down under it")


func test_internal_velocity_moves_the_board_points_not_the_centre_of_mass() -> void:
	var body: SimRigidBody = SimRigidBody.new()
	body.set_mass_properties(90.0, Basis.IDENTITY.scaled(Vector3(50.0, 6.0, 46.0)), Vector3.ZERO)
	body.velocity = Vector3(0.0, 0.0, -5.0)
	body.internal_velocity = Vector3(0.0, 0.2, 0.0)
	assert_eq(body.point_velocity(body.point_world(Vector3(0.0, 0.0, 1.0))), Vector3(0.0, 0.2, -5.0))
	body.integrate(0.1)
	assert_almost_eq(body.position, Vector3(0.0, 0.0, -0.5), Vector3.ONE * 1e-9, "the centre of mass only moves with its own velocity")


func test_acceleration_at_a_point_includes_the_angular_part() -> void:
	var body: SimRigidBody = SimRigidBody.new()
	body.set_mass_properties(10.0, Basis.IDENTITY.scaled(Vector3(2.0, 2.0, 2.0)), Vector3.ZERO)
	# 20 N up at 1 m forward: 2 m/s2 up for the centre, and a pitch acceleration of 10 rad/s2.
	body.add_force_at(Vector3(0.0, 0.0, -1.0), Vector3(0.0, 20.0, 0.0))
	assert_almost_eq(body.acceleration_at(Vector3.ZERO), Vector3(0.0, 2.0, 0.0), Vector3.ONE * 1e-9)
	assert_almost_eq(body.acceleration_at(Vector3(0.0, 0.0, -1.0)).y, 12.0, 1e-9, "the point under the force accelerates up faster")
	assert_almost_eq(body.acceleration_at(Vector3(0.0, 0.0, 1.0)).y, -8.0, 1e-9, "the opposite end goes down")


func test_added_mass_slows_the_up_axis_only() -> void:
	var body: SimRigidBody = SimRigidBody.new()
	body.set_mass_properties(10.0, Basis.IDENTITY.scaled(Vector3(2.0, 2.0, 2.0)), Vector3.ZERO)
	body.added_mass_up_kg = 30.0
	body.add_force(Vector3(40.0, 40.0, 0.0))
	var acceleration: Vector3 = body.linear_acceleration()
	assert_almost_eq(acceleration.x, 4.0, 1e-9, "sideways: the body mass alone")
	assert_almost_eq(acceleration.y, 1.0, 1e-9, "up: body plus water, 40 kg")
	body.basis = Basis(Vector3.RIGHT, deg_to_rad(90.0))  # the body's up axis now points along world -z
	body.clear_forces()
	body.add_force(Vector3(0.0, 40.0, 0.0))
	assert_almost_eq(body.linear_acceleration().y, 4.0, 1e-9, "the added mass follows the body's axis, not the world's")
