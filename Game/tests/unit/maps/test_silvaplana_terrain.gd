extends GutTest
## The Silvaplana terrain (MAP_SILVAPLANA_PLAN.md, M1): the known points of MD1 land in the right
## place, the height grid has the right heights there, and the terrain meshes (thinned out in
## Blender) stay within half a metre of the grid. The points and published heights are the same
## as in tools/map/silvaplana_area.py (KNOWN_POINTS).

const CONFIG_PATH: String = "res://maps/silvaplana/map_config.tres"
const GRID_PATH: String = "res://maps/silvaplana/terrain/shore_heights.json"
const TERRAIN_DIR: String = "res://maps/silvaplana/terrain"
const TERRAIN_SCENE: String = "res://maps/silvaplana/terrain/terrain.tscn"
## How far the meshes may be from the grid (the plan's limit).
const MESH_TOLERANCE_M: float = 0.5

# LV95 east, north.
const STATION: Vector2 = Vector2(2778576.0, 1144976.0)  # MeteoSwiss Segl-Maria, stands at 1804 m
const CHURCH: Vector2 = Vector2(2781018.0, 1148074.0)  # Santa Maria, Silvaplana
const CAMPING: Vector2 = Vector2(2780866.0, 1147617.0)  # middle of the camping area
const CAMPING_SHORE: Vector2 = Vector2(2780866.0, 1147556.0)  # where the camping meets the water
const LAKE_MIDDLE: Vector2 = Vector2(2780500.0, 1146600.0)
const CORVATSCH: Vector2 = Vector2(2782788.5, 1142434.75)  # summit, 3451 m

var _config: MapConfig
var _grid: TerrainGrid


func before_all() -> void:
	_config = load(CONFIG_PATH)
	_grid = TerrainGrid.load_from(GRID_PATH)


func test_grid_loads() -> void:
	assert_not_null(_grid, "The shore band's height grid should load: " + GRID_PATH)
	if _grid == null:
		return
	assert_eq(_grid.columns, 2501, "5 km at 2 m")
	assert_eq(_grid.rows, 2501, "5 km at 2 m")
	assert_almost_eq(_grid.cell_m, 2.0, 0.001)


func test_known_points_land_in_the_right_place() -> void:
	var church: Vector3 = _game(CHURCH)
	assert_gt(church.x, 0.0, "The church is east of the lake's middle")
	assert_lt(church.z, 0.0, "The church is north of the lake's middle (north is -Z)")
	var corvatsch: Vector3 = _game(CORVATSCH)
	assert_gt(corvatsch.x, 0.0, "Piz Corvatsch is east of the lake's middle")
	assert_gt(corvatsch.z, 0.0, "Piz Corvatsch is south of the lake's middle")
	assert_almost_eq(Vector2(corvatsch.x, corvatsch.z).length(), 4750.0, 50.0, "Piz Corvatsch is 4.75 km from the lake's middle")


func test_grid_heights_at_known_points() -> void:
	var station: Vector3 = _game(STATION)
	assert_almost_eq(_grid.height_at(station.x, station.z), 1804.0 - _config.lake_level_m, 2.0, "The ground at the weather station")
	var camping: Vector3 = _game(CAMPING)
	assert_between(_grid.height_at(camping.x, camping.z), 0.5, 10.0, "The camping is a few metres above the lake")
	var shore: Vector3 = _game(CAMPING_SHORE)
	assert_almost_eq(_grid.height_at(shore.x, shore.z), 0.0, 1.5, "The camping's shore is at the water level")
	var middle: Vector3 = _game(LAKE_MIDDLE)
	assert_lt(_grid.height_at(middle.x, middle.z), -50.0, "The middle of the lake is deep")
	var church: Vector3 = _game(CHURCH)
	assert_between(_grid.height_at(church.x, church.z), 15.0, 40.0, "Silvaplana village is a little above the lake")
	var corvatsch: Vector3 = _game(CORVATSCH)
	assert_true(is_nan(_grid.height_at(corvatsch.x, corvatsch.z)), "Piz Corvatsch is outside the shore band's grid")


func test_meshes_match_the_grid() -> void:
	for point: Vector2 in [STATION, CHURCH, CAMPING, CAMPING_SHORE, LAKE_MIDDLE]:
		var at: Vector3 = _game(point)
		var mesh_height: float = _mesh_height(point)
		var grid_height: float = _grid.height_at(at.x, at.z)
		assert_false(is_nan(mesh_height), "A terrain mesh should be under LV95 %.0f / %.0f" % [point.x, point.y])
		assert_almost_eq(mesh_height, grid_height, MESH_TOLERANCE_M,
			"Mesh and grid at LV95 %.0f / %.0f" % [point.x, point.y])


func test_terrain_scene_has_every_chunk() -> void:
	var glb_count: int = 0
	for file: String in DirAccess.get_files_at(TERRAIN_DIR):
		if file.ends_with(".glb"):
			glb_count += 1
	var scene: PackedScene = load(TERRAIN_SCENE)
	assert_not_null(scene, "The terrain scene should load: " + TERRAIN_SCENE)
	if scene == null:
		return
	var terrain: Node = scene.instantiate()
	assert_eq(terrain.get_child_count(), glb_count, "terrain.tscn should have every .glb in " + TERRAIN_DIR)
	terrain.free()


func test_chunks_have_far_away_versions() -> void:
	# Godot's import makes simpler versions of every mesh for far away (LOD, plan M1).
	for chunk: String in ["near_2780_1146", "mid_2780_1142", "far_2780_1140"]:
		var mesh: Mesh = _chunk_mesh(chunk)
		assert_not_null(mesh, "Chunk %s should load" % chunk)
		if mesh == null:
			continue
		var surface: Dictionary = RenderingServer.mesh_get_surface(mesh.get_rid(), 0)
		assert_gt((surface.get("lods", []) as Array).size(), 0, "Chunk %s should have LODs" % chunk)


## A Swiss LV95 point on the lake surface, as a game position.
func _game(point: Vector2) -> Vector3:
	return _config.lv95_to_game(point.x, point.y, _config.lake_level_m)


## The height of the near-zone terrain mesh at an LV95 point: a ray straight down through the
## chunk (the 1 km tile) that contains it. NAN if it misses.
func _mesh_height(point: Vector2) -> float:
	var chunk: String = "near_%d_%d" % [int(point.x / 1000.0), int(point.y / 1000.0)]
	var mesh: Mesh = _chunk_mesh(chunk)
	if mesh == null:
		return NAN
	var at: Vector3 = _game(point)
	var hit: Dictionary = mesh.generate_triangle_mesh().intersect_ray(Vector3(at.x, 5000.0, at.z), Vector3.DOWN)
	if hit.is_empty():
		return NAN
	return (hit["position"] as Vector3).y


## The ground mesh of one chunk (not its skirt). The chunks are exported with their vertices in
## map coordinates and no transform, so the mesh's coordinates are game coordinates.
func _chunk_mesh(chunk: String) -> Mesh:
	var scene: PackedScene = load("%s/%s.glb" % [TERRAIN_DIR, chunk])
	if scene == null:
		return null
	var root: Node = scene.instantiate()
	var mesh: Mesh = null
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		if not node.name.ends_with("_skirt"):
			var instance: MeshInstance3D = node as MeshInstance3D
			assert_eq(instance.transform, Transform3D.IDENTITY, "Chunk %s should sit at the origin" % chunk)
			mesh = instance.mesh
	root.free()
	return mesh
