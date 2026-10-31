extends Node3D
## A development view of the gear page's 3D models (built by tools/blender/build_gear_models.py):
## each item still on a plain sky, through straight-on (orthographic) cameras, for the contact
## sheets (tools/gear/contact_sheets.sh). A board from above, from below and from its starboard
## side (the bow to the right), with its recommended fin; a sail side on from the port side (its
## front: the prints read) and from the starboard side (its back: the prints show mirrored),
## rigged on a board. The mast and the boom are the default models stretched to the sail's
## numbers, as the gear page does; the cloth is bent by the game's own shader.
##
## Run it through tools/screenshot.sh (a frame count large enough for every item):
##   tools/screenshot.sh res://dev/gear_view.tscn .screenshots/gear/view.png 3000 --items=moonboard_slalom_111
## The pictures land next to that file as <item id>_<view>.png ("deck", "bottom", "side" for a
## board, "port" and "starboard" for a sail). Options: --items=<id>,<id>,... (the items of
## res://assets/models/gear/gear_set.json, or "all"), --board=<id> (the board the sails stand on;
## the default board otherwise), --camber=<0 to 0.12> (the sails' belly, the item's own otherwise).

const TABLE_PATH: String = "res://assets/models/gear/gear_set.json"
const DEFAULT_BOARD_MODEL: String = "res://assets/models/board.glb"
const DEFAULT_DECK: String = "res://assets/models/board_deck.png"
const DEFAULT_BOTTOM: String = "res://assets/models/board_bottom.png"
const MAST_MODEL: PackedScene = preload("res://assets/models/mast.glb")
const BOOM_MODEL: PackedScene = preload("res://assets/models/boom.glb")
const SAIL_CLOTH_SHADER: Shader = preload("res://windsurfer/sail_cloth.gdshader")
const SAIL_WINDOW_SHADER: Shader = preload("res://windsurfer/sail_window.gdshader")
const MAST_SHADER: Shader = preload("res://windsurfer/mast.gdshader")
## The default sail's mast and boom, which the mast and boom models were built for (m).
const MODEL_MAST_M: float = 5.26
const MODEL_BOOM_M: float = 2.2
## The default board's mast foot (SailConfig.mast_foot_local of sail_default.tres).
const DEFAULT_MAST_FOOT: Vector3 = Vector3(0.0, 0.081, -0.125)

## The views: the camera's direction, its up, the middle of the picture (in the stand's axes), the
## picture's height in metres, and the part of the 1280 x 720 picture kept (x, y, width, height).
const BOARD_VIEWS: Dictionary[String, Array] = {
	"deck": [Vector3.DOWN, Vector3.LEFT, Vector3(0.0, 0.0, 0.0), 1.5, Rect2i(0, 150, 1280, 420)],
	"bottom": [Vector3.UP, Vector3.RIGHT, Vector3(0.0, 0.0, 0.0), 1.5, Rect2i(0, 150, 1280, 420)],
	"side": [Vector3.LEFT, Vector3.UP, Vector3(0.0, -0.16, 0.0), 1.5, Rect2i(0, 200, 1280, 330)],
}

var _camera: Camera3D
var _entries: Dictionary[String, Dictionary] = {}
var _order: PackedStringArray = PackedStringArray()


func _ready() -> void:
	var options: Dictionary[String, String] = _read_user_args()
	_read_table()
	_add_world()
	var wanted: PackedStringArray = _order if options.get("items", "all") == "all" else options["items"].split(",")
	var screenshot: String = options.get("screenshot", "")
	var out_dir: String = screenshot.get_base_dir() if screenshot != "" else "user://"
	_capture_all(wanted, out_dir, options, screenshot)


func _capture_all(wanted: PackedStringArray, out_dir: String, options: Dictionary[String, String], screenshot: String) -> void:
	for id: String in wanted:
		if not _entries.has(id):
			push_warning("gear_view: no item called '%s'." % id)
			continue
		var entry: Dictionary = _entries[id]
		match str(entry["kind"]):
			"board":
				await _capture_board(entry, out_dir)
			"sail":
				await _capture_sail(entry, out_dir, options)
	print("gear_view: done")
	if screenshot != "":
		get_viewport().get_texture().get_image().save_png(screenshot)
	get_tree().quit(0)


func _capture_board(entry: Dictionary, out_dir: String) -> void:
	var stand: Node3D = Node3D.new()
	add_child(stand)
	var files: Dictionary = entry["files"]
	_add_board(stand, str(files["model"]), str(files["deck"]), str(files["bottom"]))
	var fin: Dictionary = _entries.get(str(entry["fin"]), {})
	if not fin.is_empty() and ResourceLoader.exists(str((fin["files"] as Dictionary)["model"])):
		var fin_node: Node3D = (load(str((fin["files"] as Dictionary)["model"])) as PackedScene).instantiate() as Node3D
		fin_node.position = _vector(entry["fin_root_local"])
		stand.add_child(fin_node)
	for view: String in BOARD_VIEWS:
		var spot: Array = BOARD_VIEWS[view]
		await _save_view(spot[0] as Vector3, spot[1] as Vector3, spot[2] as Vector3, spot[3] as float,
			spot[4] as Rect2i, out_dir.path_join("%s_%s.png" % [entry["id"], view]))
	stand.queue_free()
	await get_tree().process_frame


func _capture_sail(entry: Dictionary, out_dir: String, options: Dictionary[String, String]) -> void:
	var stand: Node3D = Node3D.new()
	add_child(stand)
	var config: Dictionary = entry["config"]
	var foot: Vector3 = DEFAULT_MAST_FOOT
	var board_id: String = options.get("board", "")
	if _entries.has(board_id):
		var board: Dictionary = _entries[board_id]
		var files: Dictionary = board["files"]
		_add_board(stand, str(files["model"]), str(files["deck"]), str(files["bottom"]))
		foot = _vector(board["mast_foot_local"])
	else:
		_add_board(stand, DEFAULT_BOARD_MODEL, DEFAULT_DECK, DEFAULT_BOTTOM)
	var camber: float = options.get("camber", str(config["camber"])).to_float()
	_add_rig(stand, entry, foot, camber)
	var mast_m: float = float(config["mast_m"])
	var height: float = mast_m + 0.7
	var middle: Vector3 = Vector3(0.0, 0.5 * mast_m, 0.5 * float(config["boom_m"]) + foot.z)
	var width: int = 470
	var region: Rect2i = Rect2i(640 - width / 2, 0, width, 720)
	await _save_view(Vector3.RIGHT, Vector3.UP, middle, height, region, out_dir.path_join("%s_port.png" % entry["id"]))
	await _save_view(Vector3.LEFT, Vector3.UP, middle, height, region, out_dir.path_join("%s_starboard.png" % entry["id"]))
	stand.queue_free()
	await get_tree().process_frame


## The board's model with its deck and bottom pictures on the hull, as RigVisuals paints them.
func _add_board(stand: Node3D, model_path: String, deck_path: String, bottom_path: String) -> void:
	var board: Node3D = (load(model_path) as PackedScene).instantiate() as Node3D
	stand.add_child(board)
	var hull: MeshInstance3D = board.find_child("Hull", true, false) as MeshInstance3D
	var pictures: Dictionary[String, Texture2D] = {"board_deck": load(deck_path), "board_bottom": load(bottom_path)}
	for surface: int in hull.mesh.get_surface_count():
		var imported: BaseMaterial3D = hull.mesh.surface_get_material(surface) as BaseMaterial3D
		if imported == null or not pictures.has(imported.resource_name):
			continue
		var material: BaseMaterial3D = imported.duplicate() as BaseMaterial3D
		material.albedo_color = Color.WHITE
		material.albedo_texture = pictures[imported.resource_name]
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		hull.set_surface_override_material(surface, material)


## The mast, the sail and the boom upright on the mast foot, the boom along the board to the
## stern, the cloth bent by the game's shaders (as RigVisuals sets them up).
func _add_rig(stand: Node3D, entry: Dictionary, foot: Vector3, camber: float) -> void:
	var config: Dictionary = entry["config"]
	var mast_m: float = float(config["mast_m"])
	var boom_height: float = float(config["boom_height_m"])
	var stretch: float = mast_m / MODEL_MAST_M
	var mast: Node3D = MAST_MODEL.instantiate() as Node3D
	stand.add_child(mast)
	mast.transform = Transform3D(Basis(Vector3.BACK, Vector3.UP * stretch, Vector3.LEFT), foot)
	var tube: MeshInstance3D = mast.find_child("Mast", true, false) as MeshInstance3D
	var mast_material: ShaderMaterial = ShaderMaterial.new()
	mast_material.shader = MAST_SHADER
	mast_material.set_shader_parameter("mast_length_m", MODEL_MAST_M)
	mast_material.set_shader_parameter("mast_bend_start_m", boom_height / stretch)
	for surface: int in tube.mesh.get_surface_count():
		var imported: Material = tube.mesh.surface_get_material(surface)
		if imported != null and imported.resource_name == "carbon":
			tube.set_surface_override_material(surface, mast_material)
	tube.set_instance_shader_parameter("mast_bend_aft_m", RigVisuals.MAST_BEND_AFT_M)
	tube.set_instance_shader_parameter("mast_bend_across_m", 0.0)

	var sail: Node3D = (load(str((entry["files"] as Dictionary)["model"])) as PackedScene).instantiate() as Node3D
	stand.add_child(sail)
	# The sail's own axes: x along the boom (aft), y up the mast, z to port.
	sail.transform = Transform3D(Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT), foot)
	var boom: Node3D = BOOM_MODEL.instantiate() as Node3D
	sail.add_child(boom)
	boom.position = Vector3(0.0, boom_height, 0.0)
	boom.scale = Vector3(float(config["boom_m"]) / MODEL_BOOM_M, 1.0, 1.0)
	var cloth: MeshInstance3D = sail.find_child("SailCloth", true, false) as MeshInstance3D
	var panels: Texture2D = load(str((entry["files"] as Dictionary)["panels"]))
	_set_up_cloth(cloth, panels, mast_m, boom_height)
	var values: Dictionary[String, float] = {
		"belly_side": -1.0, "camber": camber, "twist_head_rad": deg_to_rad(RigVisuals.TWIST_LIGHT_DEG),
		"flutter": 0.0, "flutter_phase_rad": 0.0, "mast_bend_aft_m": RigVisuals.MAST_BEND_AFT_M,
		"mast_bend_across_m": 0.0,
	}
	for parameter: String in values:
		cloth.set_instance_shader_parameter(parameter, values[parameter])
	cloth.extra_cull_margin = 1.2


## The cloth's three surfaces (cloth, clear film, sleeve) with the game's shaders, the panel
## picture and the colours the model was built with (RigVisuals._set_up_cloth).
func _set_up_cloth(cloth: MeshInstance3D, panels: Texture2D, mast_m: float, boom_height: float) -> void:
	for surface: int in cloth.mesh.get_surface_count():
		var imported: BaseMaterial3D = cloth.mesh.surface_get_material(surface) as BaseMaterial3D
		var surface_name: String = imported.resource_name if imported != null else ""
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = SAIL_WINDOW_SHADER if surface_name == "sail_window" else SAIL_CLOTH_SHADER
		material.set_shader_parameter("panel_texture", panels)
		material.set_shader_parameter("mast_length_m", mast_m)
		material.set_shader_parameter("mast_bend_start_m", boom_height)
		material.set_shader_parameter("boom_height_m", boom_height)
		material.set_shader_parameter("head_height_m", mast_m - RigVisuals.SAIL_HEAD_BELOW_MAST_TOP_M)
		if surface_name == "sail_sleeve":
			material.set_shader_parameter("is_sleeve", true)
			material.set_shader_parameter("sleeve_color", imported.albedo_color)
		cloth.set_surface_override_material(surface, material)
	# The cloth's own colour is the reference for a race's tint (none here), on every surface.
	for surface: int in cloth.mesh.get_surface_count():
		var imported: BaseMaterial3D = cloth.mesh.surface_get_material(surface) as BaseMaterial3D
		if imported != null and imported.resource_name == "sail_cloth":
			for other: int in cloth.mesh.get_surface_count():
				var material: ShaderMaterial = cloth.get_surface_override_material(other) as ShaderMaterial
				material.set_shader_parameter("main_colour", imported.albedo_color)


## Points the straight-on camera along `direction` at `middle`, `height` metres of the scene in
## the picture's height, and saves the `region` of the picture.
func _save_view(direction: Vector3, up: Vector3, middle: Vector3, height: float, region: Rect2i, path: String) -> void:
	_camera.size = height
	_camera.global_transform = Transform3D(Basis.looking_at(direction, up), middle - direction * 20.0)
	for i: int in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var kept: Rect2i = region.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	image.get_region(kept).save_png(path)
	print("gear_view: saved ", path)


## A plain sky, a sun from above and a softer light from below (so the bottom shows), and the
## straight-on camera.
func _add_world() -> void:
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.80, 0.86, 0.92)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.85, 0.88, 0.92)
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	sun.light_energy = 1.1
	add_child(sun)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(60.0, 150.0, 0.0)
	fill.light_energy = 0.55
	add_child(fill)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.near = 0.1
	_camera.far = 60.0
	add_child(_camera)
	_camera.make_current()


func _read_table() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLE_PATH))
	if not parsed is Array:
		push_error("gear_view: %s is not a list of items." % TABLE_PATH)
		return
	for item: Variant in parsed as Array:
		var entry: Dictionary = item as Dictionary
		_entries[str(entry["id"])] = entry
		_order.append(str(entry["id"]))


static func _vector(values: Variant) -> Vector3:
	var list: Array = values as Array
	return Vector3(float(list[0]), float(list[1]), float(list[2]))


## Turns arguments like --items=a,b into {"items": "a,b"}.
func _read_user_args() -> Dictionary[String, String]:
	var options: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
			options[parts[0]] = parts[1]
	return options
