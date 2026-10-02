extends GutTest
## Pins the shared formulas of SimMath to the worked examples of PHYSICS_SPEC.md section 0.

const TOL: float = 1e-6


func test_knot() -> void:
	assert_almost_eq(SimMath.KNOT_MS, 0.514444, 1e-6)
	assert_almost_eq(15.0 * SimMath.KNOT_MS, 7.71667, 1e-4, "15 kt")


func test_bearing_to_direction() -> void:
	assert_almost_eq(SimMath.dir_from_bearing(0.0), Vector3(0, 0, -1), Vector3.ONE * TOL, "North")
	assert_almost_eq(SimMath.dir_from_bearing(deg_to_rad(90.0)), Vector3(1, 0, 0), Vector3.ONE * TOL, "East")
	assert_almost_eq(SimMath.dir_from_bearing(deg_to_rad(180.0)), Vector3(0, 0, 1), Vector3.ONE * TOL, "South")
	assert_almost_eq(SimMath.dir_from_bearing(deg_to_rad(270.0)), Vector3(-1, 0, 0), Vector3.ONE * TOL, "West")


func test_direction_to_bearing_round_trip() -> void:
	for degrees: float in [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]:
		var dir: Vector3 = SimMath.dir_from_bearing(deg_to_rad(degrees))
		assert_almost_eq(rad_to_deg(SimMath.bearing_from_dir(dir)), degrees, 1e-4, "bearing %s" % degrees)


func test_heading() -> void:
	assert_almost_eq(rad_to_deg(SimMath.heading_rad(Basis.IDENTITY)), 0.0, 1e-4, "identity faces North")
	# A right turn of 90 degrees is a NEGATIVE rotation about +Y in Godot.
	var east: Basis = Basis(Vector3.UP, deg_to_rad(-90.0))
	assert_almost_eq(rad_to_deg(SimMath.heading_rad(east)), 90.0, 1e-4, "right turn faces East")
	var west: Basis = Basis(Vector3.UP, deg_to_rad(90.0))
	assert_almost_eq(rad_to_deg(SimMath.heading_rad(west)), 270.0, 1e-4, "left turn faces West")


func test_wind_angle_examples_from_the_spec() -> void:
	# Example 1: wind from the North at 8 m/s, board heading East at 5 m/s.
	var heading_east: Basis = Basis(Vector3.UP, deg_to_rad(-90.0))
	var v_wind_true: Vector3 = -SimMath.dir_from_bearing(0.0) * 8.0
	var v_boat: Vector3 = Vector3(5.0, 0.0, 0.0)
	var v_apparent: Vector3 = v_wind_true - v_boat
	assert_almost_eq(v_apparent, Vector3(-5.0, 0.0, 8.0), Vector3.ONE * TOL)
	var awa: float = SimMath.wind_angle_rad(heading_east, -v_apparent)
	assert_almost_eq(rad_to_deg(awa), -57.9946, 1e-3, "wind from port ahead of the beam")
	var twa: float = SimMath.wind_angle_rad(heading_east, -v_wind_true)
	assert_almost_eq(rad_to_deg(twa), -90.0, 1e-4, "true wind on the port beam")
	# Example 2, the mirror: heading West.
	var heading_west: Basis = Basis(Vector3.UP, deg_to_rad(90.0))
	var awa_west: float = SimMath.wind_angle_rad(heading_west, -(v_wind_true - Vector3(-5.0, 0.0, 0.0)))
	assert_almost_eq(rad_to_deg(awa_west), 57.9946, 1e-3, "mirror case is positive (from starboard)")
	# Example 3: beam reach on starboard tack, wind from the East at 10 m/s, heading North at 6 m/s.
	var v_wind_east: Vector3 = -SimMath.dir_from_bearing(deg_to_rad(90.0)) * 10.0
	var awa_north: float = SimMath.wind_angle_rad(Basis.IDENTITY, -(v_wind_east - Vector3(0.0, 0.0, -6.0)))
	assert_almost_eq(rad_to_deg(awa_north), 59.0362, 1e-3)


func test_wind_angle_ignores_heel_and_pitch() -> void:
	var from_world: Vector3 = Vector3(1.0, 0.0, 0.0)
	var level: float = SimMath.wind_angle_rad(Basis.IDENTITY, from_world)
	var heeled: Basis = Basis(Vector3.FORWARD, deg_to_rad(30.0))
	var pitched: Basis = Basis(Vector3.RIGHT, deg_to_rad(10.0))
	assert_almost_eq(SimMath.wind_angle_rad(heeled, from_world), level, 1e-6)
	assert_almost_eq(SimMath.wind_angle_rad(pitched, from_world), level, 1e-6)
	assert_almost_eq(rad_to_deg(level), 90.0, 1e-4)


func test_pitch_and_heel_signs() -> void:
	var bow_up: Basis = Basis(Vector3.RIGHT, deg_to_rad(10.0))
	assert_almost_eq(rad_to_deg(SimMath.pitch_rad(bow_up)), 10.0, 1e-4, "positive rotation about +X lifts the bow")
	assert_almost_eq(SimMath.heel_rad(bow_up), 0.0, 1e-6)
	var starboard_down: Basis = Basis(Vector3.FORWARD, deg_to_rad(10.0))
	assert_almost_eq(rad_to_deg(SimMath.heel_rad(starboard_down)), 10.0, 1e-4, "rotation about the bow axis drops the starboard rail")
	assert_almost_eq(SimMath.pitch_rad(starboard_down), 0.0, 1e-6)
	var about_plus_z: Basis = Basis(Vector3(0, 0, 1), deg_to_rad(10.0))
	assert_almost_eq(rad_to_deg(SimMath.heel_rad(about_plus_z)), -10.0, 1e-4, "rotation about +Z (aft) heels to port")


func test_body_and_world_conversions() -> void:
	var turned: Basis = Basis(Vector3.UP, deg_to_rad(-90.0))  # facing East
	var forward_world: Vector3 = SimMath.to_world(turned, Vector3.FORWARD)
	assert_almost_eq(forward_world, Vector3(1, 0, 0), Vector3.ONE * TOL, "bow points East")
	var back: Vector3 = SimMath.to_body(turned, forward_world)
	assert_almost_eq(back, Vector3.FORWARD, Vector3.ONE * TOL)


func test_slip_angle() -> void:
	assert_almost_eq(SimMath.slip_angle_rad(Vector3(0, 0, -5)), 0.0, TOL, "straight ahead")
	assert_almost_eq(SimMath.slip_angle_rad(Vector3(1, 0, -5)), atan2(1.0, 5.0), TOL, "sliding to starboard is positive")
	assert_almost_eq(SimMath.slip_angle_rad(Vector3(-1, 0, -5)), -atan2(1.0, 5.0), TOL)
