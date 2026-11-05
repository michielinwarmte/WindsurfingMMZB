extends SceneTree
## Runs main.tscn (sailing, the follow camera) at a fixed frame rate and logs the camera.
func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var fps: int = 144
	var logger: Node = load(OS.get_environment("CAM_DIR") + "/cam_logger.gd").new()
	for a: String in args:
		if a.begins_with("--fps="):
			fps = int(a.get_slice("=", 1))
		elif a.begins_with("--out="):
			logger.out_path = a.get_slice("=", 1)
		elif a == "--interp_off":
			logger.interp_off = true
	Engine.max_fps = fps
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	root.add_child(logger)
