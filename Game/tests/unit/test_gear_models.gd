extends GutTest
## The gear page's 3D models (tools/blender/build_gear_models.py; the report is
## Documentation/reports/fleet_gear/gear_models.md): every item of the gear table has its model and
## its pictures, with the nodes and materials RigVisuals looks for, built to the item's own numbers;
## and no real maker's or model's name is in the table (the game may not use them: copyright).

const TABLE_PATH: String = "res://assets/models/gear/gear_set.json"
## The gear table's source, from the project folder (Game/).
const GEAR_SET_SCRIPT: String = "../tools/blender/gear_set.py"
const ITEMS_PER_KIND: Dictionary[String, int] = {"board": 22, "sail": 36, "fin": 5}
## The node each kind's model must have (RigVisuals finds them by these names).
const MAIN_NODE: Dictionary[String, String] = {"board": "Hull", "sail": "SailCloth", "fin": "Fin"}
## The sport's real makers (as test_brands.gd) and the real models of
## Documentation/reports/fleet_gear/brand_research.md section 2 and the fins, lower case.
const REAL_NAMES: PackedStringArray = [
	"duotone", "severne", "point-7", "point 7", "starboard", "neilpryde", "neil pryde", "jp australia",
	"fmx", "north sails", "northsails", "s2maui", "tabou", "gaastra", "ga sails", "fanatic",
	"isonic", "futura", "falcon", "jag", "blitz", "warp", "s_pace", "x_pace", "e_pace", "e_type", "mach",
	"overdrive", "ncx", "fox", "ac-0", "ac-1", "ac-2", "ac-3", "ac-x", "ac-f", "rush-1", "rs:racing", "rs:x",
	"evo", "v8", "speedster", "s-tec", "super sport", "invictus", "hyperion", "veloce", "diablo", "gtr",
	"slalom race", "gen3", "3di", "prisma", "free speed", "x-over", "venom", "wicked", "banshee", "manta",
	"rocket", "bullitt", "vapor", "cosmic", "matrix", "rapido", "phantom", "alchemy", "carbon reflex",
	"racingblade", "skyblade", "slx", "fluido", "s-max", "evoq", "scross", "white tiger", "grand tour",
	"hgo", "iqfoil", "enigma", "rhino", "sonntag", "drake",
]

var _table: Array[Dictionary] = []


func before_all() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLE_PATH))
	if parsed is Array:
		for entry: Variant in parsed as Array:
			_table.append(entry as Dictionary)


func test_the_table_lists_the_gear_set() -> void:
	var counts: Dictionary[String, int] = {"board": 0, "sail": 0, "fin": 0}
	var ids: Dictionary[String, bool] = {}
	for entry: Dictionary in _table:
		var kind: String = str(entry["kind"])
		counts[kind] += 1
		var id: String = str(entry["id"])
		assert_false(ids.has(id), id + " is in the table once")
		ids[id] = true
		var size: String = ("%.1f" % float(entry["size"])).replace(".", "_") if kind == "sail" else "%d" % int(entry["size"])
		assert_eq(id, "%s_%s_%s" % [entry["brand"], entry["line"], size], id + ": the id is <brand>_<line>_<size>")
	for kind: String in ITEMS_PER_KIND:
		assert_eq(counts[kind], ITEMS_PER_KIND[kind], "the table has %d %ss" % [ITEMS_PER_KIND[kind], kind])


func test_every_item_has_its_model_with_the_node_rigvisuals_finds() -> void:
	for entry: Dictionary in _table:
		var model: Node = _instantiate(entry)
		assert_not_null(model, str(entry["id"]) + "'s model loads as a scene")
		if model == null:
			continue
		var node: Node = model.find_child(MAIN_NODE[str(entry["kind"])], true, false)
		assert_true(node is MeshInstance3D, "%s's model has its %s" % [entry["id"], MAIN_NODE[str(entry["kind"])]])


func test_every_board_and_sail_has_its_pictures() -> void:
	for entry: Dictionary in _table:
		var files: Dictionary = entry["files"]
		var wanted: Array[String] = []
		match str(entry["kind"]):
			"board":
				wanted = ["deck", "bottom"]
			"sail":
				wanted = ["panels"]
		for picture: String in wanted:
			var texture: Texture2D = load(str(files.get(picture, ""))) as Texture2D
			assert_not_null(texture, "%s has its %s picture" % [entry["id"], picture])
			if texture != null:
				assert_gt(texture.get_width(), 1, "%s's %s picture is a real picture" % [entry["id"], picture])


func test_the_boards_are_built_to_their_numbers() -> void:
	for entry: Dictionary in _items("board"):
		var config: Dictionary = entry["config"]
		var hull: MeshInstance3D = _instantiate(entry).find_child("Hull", true, false) as MeshInstance3D
		var box: AABB = hull.get_aabb()
		assert_almost_eq(box.size.z, float(config["length_m"]), 0.01, str(entry["id"]) + ": the hull is as long as the board")
		assert_almost_eq(box.size.x, float(config["width_m"]), 0.01, str(entry["id"]) + ": the hull is as wide as the board")
		assert_almost_eq(box.get_center().z, 0.0, 0.01, str(entry["id"]) + ": the origin is the board's middle, as the simulation's")
		var surfaces: PackedStringArray = _surface_names(hull)
		assert_true("board_deck" in surfaces and "board_bottom" in surfaces,
			str(entry["id"]) + ": the hull has the deck's and the bottom's materials RigVisuals paints")


func test_the_sails_are_built_to_their_numbers() -> void:
	for entry: Dictionary in _items("sail"):
		var config: Dictionary = entry["config"]
		var model: Node = _instantiate(entry)
		var cloth: MeshInstance3D = model.find_child("SailCloth", true, false) as MeshInstance3D
		var box: AABB = cloth.get_aabb()
		# The head just under the mast top (RigVisuals.SAIL_HEAD_BELOW_MAST_TOP_M), the clew at the
		# end of the boom: the aftmost point of the cloth.
		assert_almost_eq(box.end.y, float(config["mast_m"]) - RigVisuals.SAIL_HEAD_BELOW_MAST_TOP_M, 0.03,
			str(entry["id"]) + ": the head is just under the mast top")
		assert_almost_eq(box.end.x, float(config["boom_m"]), 0.03, str(entry["id"]) + ": the clew is at the boom's end")
		var ring: MeshInstance3D = model.find_child("SailClewRing", true, false) as MeshInstance3D
		assert_almost_eq(ring.get_aabb().get_center().y, float(config["boom_height_m"]), 0.01,
			str(entry["id"]) + ": the clew is at the boom's height")
		var surfaces: PackedStringArray = _surface_names(cloth)
		for surface: String in ["sail_cloth", "sail_window", "sail_sleeve"]:
			assert_true(surface in surfaces, "%s: the cloth has the %s material" % [entry["id"], surface])


func test_the_fins_are_as_deep_as_their_numbers() -> void:
	for entry: Dictionary in _items("fin"):
		var fin: MeshInstance3D = _instantiate(entry).find_child("Fin", true, false) as MeshInstance3D
		var span: float = float((entry["config"] as Dictionary)["span_m"])
		assert_almost_eq(-fin.get_aabb().position.y, span, 0.005, str(entry["id"]) + ": the tip is the span below the root")


func test_every_board_has_a_fin_of_the_table() -> void:
	var fins: Dictionary[String, bool] = {}
	for entry: Dictionary in _items("fin"):
		fins[str(entry["id"])] = true
	for entry: Dictionary in _items("board"):
		assert_true(fins.has(str(entry["fin"])), "%s's fin %s is in the table" % [entry["id"], entry["fin"]])


func test_no_real_name_in_the_gear_table() -> void:
	var table_text: String = FileAccess.get_file_as_string(TABLE_PATH).to_lower()
	for real: String in REAL_NAMES:
		assert_false(table_text.contains(real), "gear_set.json does not say '%s'" % real)
	# The model names in tools/blender/gear_set.py (the real gear each item is modelled on is
	# written in comments there, which are left out).
	var path: String = ProjectSettings.globalize_path("res://").path_join(GEAR_SET_SCRIPT)
	var code: PackedStringArray = PackedStringArray()
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		code.append(line.get_slice("#", 0))
	var names: PackedStringArray = _model_names("\n".join(code))
	assert_gt(names.size(), 50, "the gear table's model names are found")
	for name: String in names:
		for real: String in REAL_NAMES:
			assert_false(name.to_lower().contains(real), "the model name '%s' does not say '%s'" % [name, real])


## The model names given to board(), sail(), default_board() and default_sail() and the fins'.
static func _model_names(code: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var patterns: PackedStringArray = [
		"(?:board|sail)\\(\"[a-z0-9_]+\", \"(?:slalom|freerace)\", \"([^\"]+)\"",
		"default_(?:board|sail)\\(\"[a-z0-9_]+\", \"([^\"]+)\"",
		"\"model_name\": \"([^\"]+)\"",
	]
	for pattern: String in patterns:
		var expression: RegEx = RegEx.create_from_string(pattern)
		for found: RegExMatch in expression.search_all(code):
			names.append(found.get_string(1))
	return names


func _items(kind: String) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for entry: Dictionary in _table:
		if str(entry["kind"]) == kind:
			items.append(entry)
	return items


func _instantiate(entry: Dictionary) -> Node:
	var path: String = str((entry["files"] as Dictionary)["model"])
	if not ResourceLoader.exists(path):
		return null
	var scene: PackedScene = load(path) as PackedScene
	return autofree(scene.instantiate()) if scene != null else null


static func _surface_names(mesh_instance: MeshInstance3D) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for surface: int in mesh_instance.mesh.get_surface_count():
		var material: Material = mesh_instance.mesh.surface_get_material(surface)
		names.append(material.resource_name if material != null else "")
	return names
