extends Node3D
## Development view of the sailor figure: sails the simulation (fast, without drawing),
## stops at chosen moments and saves a contact sheet of the figure from six cameras at each
## one, so the pose can be checked against a real windsurfer. Nothing here is part of the
## game.
##
## Run it with (from the repo root; a window opens for a few seconds):
##   tools/godot.sh --path Game --resolution 1280x720 --audio-driver Dummy res://dev/figure_view.tscn -- <options>
## Options:
##   --wind=18          wind speed (kt at 10 m), from the West
##   --twa=90           wind angle the autopilot holds (degrees)
##   --tack=starboard   or port
##   --times=8          moments to capture (seconds of simulation time), comma-separated
##   --manoeuvre=tack   or gybe: the player's controller sails instead of the autopilot and
##                      starts the manoeuvre at --start (default 25 s); --times are then
##                      seconds after the start
##   --fall=1           a catapult at --start; --times are seconds after it
##   --views=close,stern  only these views (default all six)
##   --sequence=bow     instead of six views per moment, one view (bow, stern, windward,
##                      leeward, close, top, or high: above the starboard quarter, which
##                      does not change sides in a manoeuvre) at each of up to six moments
##   --out=<prefix>     where to save: <prefix>_<moment>.png, or <prefix>_<view>.png for a
##                      sequence (default ../.screenshots/figure)
##   --screenshot=<file> also save the first sheet there (lets tools/screenshot.sh run it)

const DT: float = 1.0 / 60.0
const VIEW_WIDTH: int = 640
const VIEW_HEIGHT: int = 360
## The cameras: name, where the camera is (board axes, metres, "windward" x is flipped to
## the sailor's side), and how far up the camera looks at the sailor's chest.
const VIEWS: Array[String] = ["bow", "stern", "windward", "leeward", "close", "top"]

@onready var _camera: Camera3D = $Camera
@onready var _label: Label = $Overlay/Label
@onready var _ocean: OceanNode = $Ocean

var _windsurfer: WindsurferNode
var _options: Dictionary[String, String] = {}
var _fall_done: bool = false


func _ready() -> void:
	_options = _read_user_args()
	# The figure is posed by hand below; the engine's smoothing between ticks would blur it.
	get_tree().physics_interpolation = false
	var twa: float = _options.get("twa", "90").to_float()
	var port: bool = _options.get("tack", "starboard") == "port"
	_windsurfer = (load("res://windsurfer/windsurfer.tscn") as PackedScene).instantiate() as WindsurferNode
	# The wind comes from the West (270): starboard tack has it over the right side.
	_windsurfer.start_heading_deg = 270.0 + twa if port else 270.0 - twa
	_windsurfer.autopilot_twa_deg = twa
	_windsurfer.use_autopilot = not _options.has("manoeuvre")
	add_child(_windsurfer)
	_windsurfer.set_physics_process(false)
	var sim: WindsurferSim = _windsurfer.sim
	sim.wind_config = sim.wind_config.duplicate()
	sim.wind_config.speed_kt = _options.get("wind", "18").to_float()
	sim.wind = WindField.new(sim.wind_config)
	_windsurfer.reset()
	_ocean.setup(sim, _camera)
	_run()


func _run() -> void:
	var start_s: float = _options.get("start", "25").to_float()
	var relative: bool = _options.has("manoeuvre") or _options.has("fall")
	var times: PackedFloat64Array = PackedFloat64Array()
	for part: String in _options.get("times", "8").split(","):
		times.append(part.to_float() + (start_s if relative else 0.0))
	times.sort()
	var out_prefix: String = _options.get("out", ProjectSettings.globalize_path("res://").path_join("../.screenshots/figure"))
	DirAccess.make_dir_recursive_absolute(out_prefix.get_base_dir())
	if _options.has("sequence"):
		await _save_sequence(times, start_s, relative, out_prefix)
	else:
		await _save_moments(times, start_s, relative, out_prefix)
	get_tree().quit(0)


## One sheet of six views for each moment.
func _save_moments(times: PackedFloat64Array, start_s: float, relative: bool, out_prefix: String) -> void:
	var first: bool = true
	for moment_s: float in times:
		_sail_until(moment_s, start_s)
		var views: PackedStringArray = _options.get("views", ",".join(VIEWS)).split(",")
		var sheet: Image = _new_sheet(views.size())
		for index: int in views.size():
			var view: Image = await _render_view(views[index], moment_s)
			_put_on_sheet(sheet, view, index)
		var path: String = "%s_%s.png" % [out_prefix, _moment_name(moment_s, start_s, relative)]
		_save(sheet, path, first)
		first = false


## One view at up to six moments, on one sheet.
func _save_sequence(times: PackedFloat64Array, start_s: float, relative: bool, out_prefix: String) -> void:
	var view_name: String = _options["sequence"]
	var sheet: Image = _new_sheet(mini(times.size(), 6))
	for index: int in mini(times.size(), 6):
		_sail_until(times[index], start_s)
		var view: Image = await _render_view(view_name, times[index])
		_put_on_sheet(sheet, view, index)
	_save(sheet, "%s_%s.png" % [out_prefix, view_name], true)


func _save(sheet: Image, path: String, first: bool) -> void:
	sheet.save_png(path)
	print("Saved ", path)
	if first and _options.has("screenshot"):
		sheet.save_png(_options["screenshot"])


## Steps the simulation (and the figure, so its smoothing sees every tick) up to `until_s`.
func _sail_until(until_s: float, start_s: float) -> void:
	var sim: WindsurferSim = _windsurfer.sim
	var manoeuvre: String = _options.get("manoeuvre", "")
	while sim.time_s < until_s - 0.5 * DT:
		var now: float = sim.time_s
		if manoeuvre != "":
			_press_keys(manoeuvre, now, start_s)
		if _options.has("fall") and now >= start_s and not _fall_done:
			sim.force_fall("catapult")
			_fall_done = true
		_windsurfer._physics_process(DT)


## The keys a player would press for a manoeuvre, as tools/matrix.sh does: Space for a tack
## at the start; for a gybe a short bear-away first, then Space.
func _press_keys(manoeuvre: String, now: float, start_s: float) -> void:
	var space_s: float = start_s if manoeuvre == "tack" else start_s + 2.0
	if manoeuvre == "gybe":
		if now >= start_s and now < start_s + 0.6:
			Input.action_press("steer_left" if _options.get("tack", "starboard") != "port" else "steer_right")
		else:
			Input.action_release("steer_left")
			Input.action_release("steer_right")
	if now >= space_s and now < space_s + 0.1:
		Input.action_press("tack")
	else:
		Input.action_release("tack")


## A blank sheet for `count` views, two to a row.
func _new_sheet(count: int) -> Image:
	var rows: int = maxi((count + 1) / 2, 1)
	return Image.create(2 * VIEW_WIDTH, rows * VIEW_HEIGHT, false, Image.FORMAT_RGBA8)


func _put_on_sheet(sheet: Image, view: Image, index: int) -> void:
	sheet.blit_rect(view, Rect2i(0, 0, VIEW_WIDTH, VIEW_HEIGHT), Vector2i((index % 2) * VIEW_WIDTH, (index / 2) * VIEW_HEIGHT))


## Renders one view, with its name and the state of the simulation written on it.
func _render_view(view: String, moment_s: float) -> Image:
	_place_camera(view)
	_label.text = "%s   %s" % [view, _status_line(moment_s)]
	var sail: GeometryInstance3D = _windsurfer.find_child("Sail", true, false) as GeometryInstance3D
	if sail != null:
		sail.transparency = 0.85 if view == "leeward" else 0.0
	for frame: int in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	image.resize(VIEW_WIDTH, VIEW_HEIGHT, Image.INTERPOLATE_LANCZOS)
	return image


## Puts the camera for one view, in the board's axes, aimed at the sailor's middle.
func _place_camera(view: String) -> void:
	var board: Transform3D = _windsurfer.global_transform
	var figure: FigureSkeleton = (_windsurfer.find_child("SailorFigure", true, false) as SailorFigure).skeleton
	var windward: float = -signf(figure.facing_side) if figure.facing_side != 0.0 else 1.0
	var middle: Vector3 = figure.pelvis.lerp(figure.neck, 0.5)
	var offset: Vector3 = Vector3.ZERO
	match view:
		"bow":
			offset = Vector3(0.6 * windward, 0.5, -4.2)
		"stern":
			offset = Vector3(0.6 * windward, 0.6, 4.2)
		"windward":
			offset = Vector3(4.2 * windward, 0.4, 0.3)
		"leeward":
			offset = Vector3(-4.2 * windward, 0.5, 0.3)
		"close":
			offset = Vector3(1.6 * windward, 0.5, -1.6)
		"top":
			offset = Vector3(0.3 * windward, 4.5, 0.6)
		"high":
			# Fixed to the starboard quarter, above: does not jump sides in a manoeuvre.
			offset = Vector3(2.6, 2.6, 2.6)
	var target: Vector3 = board * middle
	# Level cameras: the board's heading, not its heel and pitch.
	var yaw: Basis = Basis(Vector3.UP, board.basis.get_euler().y)
	var eye: Vector3 = target + yaw * offset
	var up: Vector3 = yaw * Vector3.FORWARD if view == "top" else Vector3.UP
	_camera.global_transform = Transform3D(Basis.IDENTITY, eye).looking_at(target, up)


func _status_line(moment_s: float) -> String:
	var sim: WindsurferSim = _windsurfer.sim
	var t: Telemetry = sim.telemetry
	var figure: FigureSkeleton = (_windsurfer.find_child("SailorFigure", true, false) as SailorFigure).skeleton
	var line: String = "t %.1f s  wind %d kt  speed %.1f kt  TWA %.0f  lean %.2f  stance %.2f" % [
		moment_s, int(sim.wind_config.speed_kt), t.speed_ms / SimMath.KNOT_MS, t.twa_deg, sim.lean, sim.stance]
	line += "\nharness %.0f N %s  hips %.2f m off the centre of mass  %s %s" % [
		sim.harness_tension_n, "hooked in" if figure.hooked else "unhooked", figure.pelvis_offset_m,
		_windsurfer.controller.manoeuvre_name(), "FALLEN" if _windsurfer.is_fallen() else ""]
	return line


func _moment_name(moment_s: float, start_s: float, relative: bool) -> String:
	var shown: float = moment_s - start_s if relative else moment_s
	return "t%05.1f" % shown


## Turns arguments like --wind=18 into {"wind": "18"}.
func _read_user_args() -> Dictionary[String, String]:
	var options: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
			options[parts[0]] = parts[1]
	return options
