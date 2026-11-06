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
## For pictures of the board's effects (Documentation/reports/waves/board_fx.md), also without --screenshot:
## --side_view=<degrees>[,<elevation degrees>,<distance m>] holds the orbit camera at that angle from the
## board's stern as the board turns (0 behind, 90 the starboard side, -90 port; "lee" the leeward side
## just ahead of the beam, where photographers stand); --twa_at=<seconds>,<degrees> gives the autopilot a new wind angle then (from
## the beam reach to 150: a bear-away carve).

const DEFAULT_FRAMES: int = 60
const DEFAULT_EVERY: int = 60

## --side_view and --twa_at (see above): the camera's angle, and when and to what the autopilot turns.
var _side_view: String = ""
var _twa_at_s: float = -1.0
var _twa_deg: float = 150.0
var _clock_s: float = 0.0
var _rig: CameraRig = null


func _ready() -> void:
	var options: Dictionary[String, String] = _read_user_args()
	if options.has("render_size"):
		_render_at(options["render_size"])
	_side_view = options.get("side_view", "")
	if options.has("twa_at"):
		var parts: PackedStringArray = options["twa_at"].split(",")
		_twa_at_s = parts[0].to_float()
		_twa_deg = parts[1].to_float() if parts.size() > 1 else 150.0
	if not options.has("screenshot"):
		if _side_view == "" and _twa_at_s < 0.0:
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


## The side view and the autopilot's new wind angle, every frame (before the cameras move: the
## autoloads process first).
func _process(delta: float) -> void:
	_clock_s += delta
	var rig: CameraRig = _camera_rig()
	if rig == null:
		return
	var board: WindsurferNode = rig.target() as WindsurferNode
	if board == null:
		return
	if _twa_at_s >= 0.0 and _clock_s >= _twa_at_s:
		board.autopilot.target_twa_deg = _twa_deg
		_twa_at_s = -1.0
	if _side_view != "":
		_hold_side_view(rig, board)


## The orbit camera at a fixed angle from the board's stern (CameraRig: azimuth 0 looks from +Z).
func _hold_side_view(rig: CameraRig, board: WindsurferNode) -> void:
	var parts: PackedStringArray = _side_view.split(",")
	var forward: Vector3 = -board.get_global_transform_interpolated().basis.z
	var yaw: float = atan2(-forward.x, -forward.z)
	var from_stern_deg: float = 0.0
	if parts[0] == "lee":
		# The wind from starboard (AWA > 0): port is to leeward.
		from_stern_deg = -100.0 if board.sim.telemetry.awa_deg > 0.0 else 100.0
	else:
		from_stern_deg = parts[0].to_float()
	rig.mode = CameraRig.Mode.ORBIT
	rig.orbit_azimuth_rad = yaw + deg_to_rad(from_stern_deg)
	if parts.size() > 1:
		rig.orbit_elevation_rad = deg_to_rad(parts[1].to_float())
	if parts.size() > 2:
		rig.orbit_distance_m = parts[2].to_float()


func _camera_rig() -> CameraRig:
	if is_instance_valid(_rig):
		return _rig
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	for node: Node in scene.find_children("*", "Node3D", true, false):
		if node is CameraRig:
			_rig = node as CameraRig
			return _rig
	return null


## Turns arguments like --frames=90 into {"frames": "90"}.
func _read_user_args() -> Dictionary[String, String]:
	var options: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
			options[parts[0]] = parts[1]
	return options
