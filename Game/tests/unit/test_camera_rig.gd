extends GutTest
## The cameras (camera/camera_rig.gd) move every rendered frame, so Godot must not also
## interpolate the camera between physics ticks (GR9: the board shook in the picture).


func test_the_camera_is_not_physics_interpolated() -> void:
	var rig: CameraRig = CameraRig.new()
	add_child_autofree(rig)
	assert_eq(rig.camera.physics_interpolation_mode, Node.PHYSICS_INTERPOLATION_MODE_OFF)
