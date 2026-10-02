extends GutTest
## The fin model (PHYSICS_SPEC.md section 4), with the default 38 cm fin.

const RHO: float = 1025.0


func _fin() -> FinModel:
	return FinModel.new(load("res://config/fin_default.tres"))


func _body_moving(v_body: Vector3) -> SimRigidBody:
	var body: SimRigidBody = SimRigidBody.new()
	body.set_mass_properties(92.0, Basis.IDENTITY.scaled(Vector3(50.0, 6.0, 46.0)), Vector3(0.0, 0.97, 0.0))
	body.set_origin_world(Vector3.ZERO)  # floating at the origin: the fin root is under water
	body.velocity = v_body  # identity basis: body axes are world axes
	return body


func test_aspect_ratio_and_slope() -> void:
	var fin: FinModel = _fin()
	assert_almost_eq(fin.config.aspect_ratio(), 3.956, 0.01)
	assert_almost_eq(fin.config.effective_aspect_ratio(), 7.912, 0.02)
	var ar: float = fin.config.effective_aspect_ratio()
	assert_almost_eq(fin.lift_slope_per_rad(), 2.0 * PI * ar / (ar + 2.0), 1e-6)


func test_lift_curve_shape() -> void:
	var fin: FinModel = _fin()
	var slope: float = fin.lift_slope_per_rad()
	assert_almost_eq(fin.lift_coefficient(deg_to_rad(4.0)), slope * deg_to_rad(4.0), 1e-6, "linear region")
	assert_almost_eq(fin.lift_coefficient(deg_to_rad(-4.0)), -slope * deg_to_rad(4.0), 1e-6, "antisymmetric")
	var cl_peak: float = fin.lift_coefficient(deg_to_rad(12.0))
	assert_almost_eq(cl_peak, slope * deg_to_rad(8.0) + 0.15, 1e-6)
	assert_lt(fin.lift_coefficient(deg_to_rad(16.0)), cl_peak, "stalls past the peak")
	assert_almost_eq(fin.lift_coefficient(deg_to_rad(25.0)), 0.4, 1e-6)
	assert_almost_eq(fin.lift_coefficient(deg_to_rad(90.0)), 0.1, 1e-6, "floor")
	var previous: float = 0.0
	var angle: float = 0.01
	while angle <= 90.0:
		var current: float = fin.lift_coefficient(deg_to_rad(angle))
		assert_lt(absf(current - previous), 0.01, "continuous at %s degrees" % angle)
		previous = current
		angle += 0.01


func test_induced_drag_is_quadratic() -> void:
	var fin: FinModel = _fin()
	var cl4: float = fin.lift_coefficient(deg_to_rad(4.0))
	var cl8: float = fin.lift_coefficient(deg_to_rad(8.0))
	var induced4: float = fin.drag_coefficient(cl4) - fin.drag_coefficient(0.0) - fin.config.cd_profile * cl4 * 0.5
	var induced8: float = fin.drag_coefficient(cl8) - fin.drag_coefficient(0.0) - fin.config.cd_profile * cl8 * 0.5
	assert_almost_eq(induced8 / induced4, 4.0, 1e-6)
	assert_almost_eq(fin.drag_coefficient(0.0), 0.008, 1e-9)


func test_zero_slip_gives_only_profile_drag() -> void:
	var fin: FinModel = _fin()
	var body: SimRigidBody = _body_moving(Vector3(0.0, 0.0, -8.0))
	fin.compute(body, FlatWater.new(), 0.0, RHO)
	assert_almost_eq(fin.slip_rad, 0.0, 1e-9)
	assert_eq(fin.lift_n, 0.0)
	var expected_drag: float = 0.5 * RHO * 64.0 * 0.0365 * 0.008
	assert_almost_eq(fin.drag_n, expected_drag, 1e-3)
	assert_almost_eq(fin.force_world, Vector3(0.0, 0.0, expected_drag), Vector3.ONE * 1e-3, "drag points aft (+Z)")


func test_slip_to_port_gives_lift_to_starboard_perpendicular_to_the_flow() -> void:
	var fin: FinModel = _fin()
	var v: Vector3 = 8.0 * Vector3(-sin(deg_to_rad(4.0)), 0.0, -cos(deg_to_rad(4.0)))
	var body: SimRigidBody = _body_moving(v)
	fin.compute(body, FlatWater.new(), 0.0, RHO)
	assert_almost_eq(rad_to_deg(fin.slip_rad), -4.0, 1e-4)
	assert_gt(fin.force_world.x, 0.0, "pushes to starboard, against the slip")
	var lift_part: Vector3 = fin.force_world + v.normalized() * fin.drag_n
	assert_almost_eq(lift_part.dot(v), 0.0, 1e-3 * lift_part.length() * v.length(), "lift is perpendicular to the flow")
	var expected_lift: float = 0.5 * RHO * 64.0 * 0.0365 * absf(fin.lift_coefficient(deg_to_rad(-4.0)))
	assert_almost_eq(fin.lift_n, expected_lift, 1e-3)


func test_lift_scales_with_speed_squared() -> void:
	var fin: FinModel = _fin()
	var direction: Vector3 = Vector3(-sin(deg_to_rad(4.0)), 0.0, -cos(deg_to_rad(4.0)))
	fin.compute(_body_moving(8.0 * direction), FlatWater.new(), 0.0, RHO)
	var lift8: float = fin.lift_n
	fin.compute(_body_moving(4.0 * direction), FlatWater.new(), 0.0, RHO)
	assert_almost_eq(fin.lift_n * 4.0, lift8, 1e-3)


func test_weathercock_torque_and_yaw_damping() -> void:
	var fin: FinModel = _fin()
	# Sliding to port at 8 m/s: the fin pushes the tail to starboard, which turns the bow
	# to port (toward the velocity): a positive torque about +Y.
	var v: Vector3 = 8.0 * Vector3(-sin(deg_to_rad(4.0)), 0.0, -cos(deg_to_rad(4.0)))
	var body: SimRigidBody = _body_moving(v)
	fin.compute(body, FlatWater.new(), 0.0, RHO)
	var torque: Vector3 = body._torque_sum
	assert_gt(torque.y, 0.0, "bow turns toward the direction of travel")
	# A board turning to port (positive yaw rate) sweeps its fin to starboard; the fin resists.
	var turning: SimRigidBody = _body_moving(Vector3(0.0, 0.0, -5.0))
	turning.angular_velocity = Vector3(0.0, 0.5, 0.0)
	fin.compute(turning, FlatWater.new(), 0.0, RHO)
	assert_gt(fin.slip_rad, 0.0, "the fin point moves to starboard")
	assert_lt(turning._torque_sum.y, 0.0, "torque opposes the turn")


func test_out_of_the_water_and_guards() -> void:
	var fin: FinModel = _fin()
	var body: SimRigidBody = _body_moving(Vector3(0.0, 0.0, -8.0))
	body.set_origin_world(Vector3(0.0, 0.5, 0.0))
	fin.compute(body, FlatWater.new(), 0.0, RHO)
	assert_false(fin.in_water)
	assert_eq(fin.force_world, Vector3.ZERO)
	var still: SimRigidBody = _body_moving(Vector3(0.01, 0.0, -0.02))
	fin.compute(still, FlatWater.new(), 0.0, RHO)
	assert_eq(fin.force_world, Vector3.ZERO)
	assert_eq(fin.slip_rad, 0.0)
