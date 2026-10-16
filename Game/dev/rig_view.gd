extends Node3D
## A development view of the board and the rig (plan Phase 6, "Rig visuals"). The test
## autopilot sails a beam reach for a few seconds, then the windsurfer is frozen and pictures
## are saved from cameras all around it: both sides, the bow, the stern, from above, the
## deck, close-ups of the boom and the mast foot, and the fin from under the water. It also
## prints the frame rate, the GPU time per frame and the number of draw calls.
##
## Run it through tools/screenshot.sh (which saves the last view as well):
##   tools/screenshot.sh res://dev/rig_view.tscn .screenshots/rig/view.png 600 --tack=port
## The pictures land next to that file as rig_<tack>_<view>.png. Options after the frame
## count: --tack=starboard|port (default starboard), --settle=<seconds of sailing, 6>,
## --figure=0 (hide the sailor), --views=port,bow,... (only these views), --flutter=1 (show
## the cloth luffing hard, whatever the simulation says: the pictures get "_luff" in their name).

const WINDSURFER_SCENE: PackedScene = preload("res://windsurfer/windsurfer.tscn")
const OCEAN_SCRIPT: Script = preload("res://world/ocean.gd")

## Camera spots in the board's axes (x starboard, y up, z aft; the bow is -z): where the eye
## is and the point it looks at, m, and the field of view, degrees.
const VIEWS: Dictionary[String, Array] = {
	"port": [Vector3(-7.5, 2.4, -0.6), Vector3(0.0, 1.8, 0.3), 50.0],
	"starboard": [Vector3(7.5, 2.4, -0.6), Vector3(0.0, 1.8, 0.3), 50.0],
	"bow": [Vector3(0.3, 2.2, -8.5), Vector3(0.0, 1.8, 0.0), 50.0],
	"stern": [Vector3(-0.3, 2.6, 8.5), Vector3(0.0, 1.8, 0.0), 50.0],
	"above": [Vector3(0.0, 11.0, 0.6), Vector3(0.0, 0.0, 0.0), 45.0],
	"three_quarter": [Vector3(-5.0, 3.2, -5.5), Vector3(0.0, 1.7, 0.3), 50.0],
	"deck": [Vector3(0.4, 2.6, 2.4), Vector3(0.0, 0.0, -0.1), 45.0],
	"boom": [Vector3(-1.7, 2.1, -1.2), Vector3(0.3, 1.3, 0.2), 45.0],
	"mast_foot": [Vector3(-0.9, 0.75, -1.0), Vector3(0.0, 0.15, -0.1), 40.0],
	"fin": [Vector3(-1.3, -0.9, 1.6), Vector3(0.0, -0.25, 0.8), 45.0],
	# Looking down the mast from above the masthead: the batten lines show the belly's curve.
	# The spot is worked out from the rig's pose (see _masthead_spot).
	"masthead": [],
}
## Views from under the water: the water is hidden for them.
const UNDERWATER_VIEWS: Array[String] = ["fin"]

var _windsurfer: WindsurferNode
var _camera: Camera3D
var _ocean: Node3D


func _ready() -> void:
	var options: Dictionary[String, String] = _read_user_args()
	_add_world()
	var tack: String = options.get("tack", "starboard")
	_windsurfer = WINDSURFER_SCENE.instantiate() as WindsurferNode
	# The wind blows from the West: sailing South puts it on the right (starboard tack),
	# sailing North on the left (port tack). The autopilot holds a beam reach.
	_windsurfer.start_heading_deg = 0.0 if tack == "port" else 180.0
	_windsurfer.use_autopilot = true
	add_child(_windsurfer)
	_ocean.call("setup", _windsurfer.sim, _camera)
	if options.get("figure", "1") == "0":
		_windsurfer.get_node("SailorFigure").visible = false
	var views: PackedStringArray = PackedStringArray(VIEWS.keys())
	if options.has("views"):
		views = options["views"].split(",")
	var screenshot: String = options.get("screenshot", "")
	var out_dir: String = screenshot.get_base_dir() if screenshot != "" else "user://"
	var suffix: String = "_luff" if options.get("flutter", "0") == "1" else ""
	_capture_views(options.get("settle", "6").to_float(), views, out_dir, tack, suffix)


func _capture_views(settle_s: float, views: PackedStringArray, out_dir: String, tack: String, suffix: String) -> void:
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	_place_camera(VIEWS["three_quarter"])
	await get_tree().create_timer(settle_s, true, true).timeout
	_print_performance()
	# Freeze the windsurfer where it is, so every view shows the same moment.
	_windsurfer.process_mode = Node.PROCESS_MODE_DISABLED
	var t: Telemetry = _windsurfer.telemetry()
	print("rig_view: %s tack, %.1f kt, sail side %d, boom %.0f deg, alpha %.1f deg, heel %.1f deg" % [
		tack, t.speed_kt, t.sail_side, t.sail_angle_deg, t.alpha_deg, t.heel_deg])
	if suffix == "_luff":
		var cloth: MeshInstance3D = (_windsurfer.get_node("Rig") as RigVisuals).sail_cloth()
		cloth.set_instance_shader_parameter("flutter", 1.0)
		cloth.set_instance_shader_parameter("camber", 0.04)
	for view: String in views:
		if not VIEWS.has(view):
			push_warning("rig_view: no view called '%s'." % view)
			continue
		_ocean.visible = not UNDERWATER_VIEWS.has(view)
		_place_camera(_masthead_spot() if view == "masthead" else VIEWS[view])
		for i: int in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path: String = out_dir.path_join("rig_%s_%s%s.png" % [tack, view, suffix])
		get_viewport().get_texture().get_image().save_png(path)
		print("rig_view: saved ", path)
	print("rig_view: done")


## Puts the camera at a view's spot, in the board's axes, keeping the picture level.
func _place_camera(spot: Array) -> void:
	var board: Transform3D = _windsurfer.global_transform
	var eye: Vector3 = board * (spot[0] as Vector3)
	var target: Vector3 = board * (spot[1] as Vector3)
	_camera.fov = spot[2] as float
	_camera.global_transform = Transform3D(Basis.looking_at(target - eye, Vector3.UP), eye)
	_camera.reset_physics_interpolation()


## Above the masthead, looking down the mast to the boom, in the board's axes.
func _masthead_spot() -> Array:
	var sail: Node3D = _windsurfer.get_node("Rig/Sail") as Node3D
	var mast_dir: Vector3 = sail.transform.basis.y.normalized()
	var foot: Vector3 = sail.transform.origin
	return [foot + mast_dir * 8.0 + Vector3(0.0, 0.0, -0.8), foot + mast_dir * 1.4 + Vector3(0.0, 0.0, 0.8), 40.0]


func _print_performance() -> void:
	var viewport: RID = get_viewport().get_viewport_rid()
	print("rig_view: %.0f fps, GPU %.2f ms and CPU %.2f ms per frame, %d draw calls, %d objects, %d primitives" % [
		Engine.get_frames_per_second(),
		RenderingServer.viewport_get_measured_render_time_gpu(viewport),
		RenderingServer.viewport_get_measured_render_time_cpu(viewport),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])


## The sky, the sun (with shadows), the camera and the water, as in the main scene.
func _add_world() -> void:
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.22, 0.47, 0.82)
	sky_material.sky_horizon_color = Color(0.68, 0.8, 0.9)
	sky_material.ground_bottom_color = Color(0.06, 0.2, 0.33)
	sky_material.ground_horizon_color = Color(0.68, 0.8, 0.9)
	var sky: Sky = Sky.new()
	sky.sky_material = sky_material
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = environment
	add_child(world)

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	add_child(sun)

	_camera = Camera3D.new()
	add_child(_camera)
	_camera.make_current()

	_ocean = Node3D.new()
	_ocean.name = "Ocean"
	_ocean.set_script(OCEAN_SCRIPT)
	add_child(_ocean)


## Turns arguments like --tack=port into {"tack": "port"}.
func _read_user_args() -> Dictionary[String, String]:
	var options: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
			options[parts[0]] = parts[1]
	return options
