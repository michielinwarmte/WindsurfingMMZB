extends Node
## Development helper for screenshots, used by tools/screenshot.sh.
##
## Start the game with the extra arguments  -- --screenshot=<file.png> [--frames=<n>]
## and it waits <n> rendered frames (default 60), saves what is on screen to <file.png>
## and quits. Without --screenshot it removes itself straight away, so normal play is
## not affected.
## A sequence, to see something move (the gusts on the water): --sequence=<count> --every=<frames>
## saves <count> pictures, the first after <n> frames and then one every <frames> frames (default 60),
## as <file>_1.png, <file>_2.png, ...
## A picture bigger than the screen (Max's 3137 x 1263 on a PC with a 1920 x 1080 screen, where the
## window cannot be that big): --render_size=<width>x<height> draws the game at that size and shows it
## shrunk in the window; the screenshot (and --measure's graphics card time) is of the full size. Also
## without --screenshot, for a measurement.

const DEFAULT_FRAMES: int = 60
const DEFAULT_EVERY: int = 60


func _ready() -> void:
	var options: Dictionary[String, String] = _read_user_args()
	if options.has("render_size"):
		_render_at(options["render_size"])
	if not options.has("screenshot"):
		queue_free()
		return

	var frames: int = DEFAULT_FRAMES
	if options.has("frames"):
		frames = maxi(1, options["frames"].to_int())
	var count: int = maxi(1, options.get("sequence", "1").to_int())
	var every: int = maxi(1, options.get("every", str(DEFAULT_EVERY)).to_int())
	_capture_after(frames, options["screenshot"], count, every)


func _capture_after(frames: int, path: String, count: int, every: int) -> void:
	var error: Error = OK
	for shot: int in count:
		for i: int in (frames if shot == 0 else every):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var file: String = path if count == 1 else "%s_%d.%s" % [path.get_basename(), shot + 1, path.get_extension()]
		var image: Image = get_viewport().get_texture().get_image()
		error = image.save_png(file)
		if error == OK:
			print("Screenshot saved: ", file)
		else:
			push_error("Could not save the screenshot to %s (error %d)." % [file, error])
			break
	get_tree().quit(0 if error == OK else 1)


## Draws the game at `size_text` (for example "3137x1263") whatever the window's size.
## When the window already has that size (the screen is big enough) nothing changes, so the picture
## is what a player sees: the HUD drawn as big as the game's own stretch makes it (project.godot,
## "canvas_items"). In a smaller window the game is drawn at that size in a viewport and shown shrunk;
## the HUD then keeps the pixel sizes it has in a 1280 x 720 window, not scaled up as in play (it says so).
func _render_at(size_text: String) -> void:
	var parts: PackedStringArray = size_text.split("x")
	if parts.size() != 2:
		push_warning("--render_size wants <width>x<height>, not %s." % size_text)
		return
	var window: Window = get_tree().root
	var wanted: Vector2i = Vector2i(parts[0].to_int(), parts[1].to_int())
	if window.size == wanted:
		return
	print("--render_size: the window is %s, not %s: drawn in a viewport, the HUD not scaled as in play." % [window.size, wanted])
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	window.content_scale_size = Vector2i(parts[0].to_int(), parts[1].to_int())


## Turns arguments like --frames=90 into {"frames": "90"}.
func _read_user_args() -> Dictionary[String, String]:
	var options: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
			options[parts[0]] = parts[1]
	return options
