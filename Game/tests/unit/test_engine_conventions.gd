extends GutTest
## Pins down the Godot facts our physics conventions depend on (see CLAUDE.md, "Conventions").
## Godot is right-handed and Unity was left-handed, so formulas copied from Legacy/ can come
## out mirrored. If one of these tests fails, stop and find out why before changing anything.


func test_forward_is_negative_z() -> void:
	assert_eq(Vector3.FORWARD, Vector3(0.0, 0.0, -1.0), "The bow points along -Z")


func test_right_is_positive_x() -> void:
	assert_eq(Vector3.RIGHT, Vector3(1.0, 0.0, 0.0), "Starboard is +X")


func test_up_is_positive_y() -> void:
	assert_eq(Vector3.UP, Vector3(0.0, 1.0, 0.0), "Up is +Y")


func test_positive_rotation_about_up_turns_the_bow_to_port() -> void:
	# Right-handed: a positive angle about +Y turns -Z (bow) toward -X (port), i.e. to the left.
	var turned: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(90.0))
	assert_almost_eq(turned, Vector3.LEFT, Vector3.ONE * 1e-6)


func test_signed_angle_to_is_positive_toward_port() -> void:
	# Trap: our apparent wind angle is positive for wind from STARBOARD, the opposite of
	# signed_angle_to. Use atan2(local.x, -local.z) for it, as CLAUDE.md describes.
	var angle: float = Vector3.FORWARD.signed_angle_to(Vector3.LEFT, Vector3.UP)
	assert_almost_eq(angle, deg_to_rad(90.0), 1e-6)


func test_atan2_formula_gives_positive_angle_for_starboard() -> void:
	var from_starboard: Vector3 = Vector3.RIGHT
	var from_ahead: Vector3 = Vector3.FORWARD
	var from_port: Vector3 = Vector3.LEFT
	assert_almost_eq(atan2(from_starboard.x, -from_starboard.z), deg_to_rad(90.0), 1e-6)
	assert_almost_eq(atan2(from_ahead.x, -from_ahead.z), 0.0, 1e-6)
	assert_almost_eq(atan2(from_port.x, -from_port.z), deg_to_rad(-90.0), 1e-6)
