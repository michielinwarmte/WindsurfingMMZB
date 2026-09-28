extends Node
## Development helper for screenshots, used by tools/screenshot.sh.
##
## Start the game with the extra arguments  -- --screenshot=<file.png> [--frames=<n>]
## and it waits <n> rendered frames (default 60), saves what is on screen to <file.png>
## and quits. Without --screenshot it removes itself straight away, so normal play is
## not affected.

const DEFAULT_FRAMES: int = 60


func _ready() -> void:
	var options: Dictionary[String, String] = _read_user_args()
	if not options.has("screenshot"):
		queue_free()
		return

	var frames: int = DEFAULT_FRAMES
	if options.has("frames"):
		frames = maxi(1, options["frames"].to_int())
	_capture_after(frames, options["screenshot"])


func _capture_after(frames: int, path: String) -> void:
	for i: int in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(path)
	if error == OK:
		print("Screenshot saved: ", path)
	else:
		push_error("Could not save the screenshot to %s (error %d)." % [path, error])
	get_tree().quit(0 if error == OK else 1)


## Turns arguments like --frames=90 into {"frames": "90"}.
func _read_user_args() -> Dictionary[String, String]:
	var options: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
			options[parts[0]] = parts[1]
	return options
