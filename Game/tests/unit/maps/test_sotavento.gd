extends GutTest
## Fuerteventura, Sotavento (backlog E04.S12, package P2; Documentation/reports/spots/sotavento/PLAN.md):
## the height grid and the water level (the tide), the terrain drawn from the grid (HeightTerrain), the
## spot's start on the water, the sailing scene, and the start menu's button.
## Points are in the spot's frame (REGCAN95 / UTM 28N, metres east and north).

const SPOT_PATH: String = "res://maps/sotavento/spot.tres"
const GRID_PATH: String = "res://maps/sotavento/terrain/near_heights.json"
const FAR_GRID_PATH: String = "res://maps/sotavento/terrain/far_heights.json"
const ENVIRONMENT_PATH: String = "res://maps/sotavento/environment_sotavento.tres"
const SAIL_SCENE: String = "res://maps/sotavento/sail_sotavento.tscn"
## The René Egli Center, the PWA event site: the game's origin.
const CENTRE: Vector2 = Vector2(574164.0, 3112474.0)
## 100 m out from the centre towards the sea (bearing 125): the lagoon's floor, about 0.45 m above mean
## sea level; 225 m out: the bar's crest, about 1.4 m (spot_build.py, the config's lagoon and bar heights,
## checked against photos at high and low tide: PLAN.md section 6).
const LAGOON_FLATS: Vector2 = Vector2(574246.0, 3112417.0)
const BAR: Vector2 = Vector2(574348.0, 3112345.0)

var _spot: Spot
var _saved_values: SettingsValues
var _saved_path: String


func before_all() -> void:
	_spot = load(SPOT_PATH)


func before_each() -> void:
	# The tests use their own settings and never write the player's settings file.
	_saved_values = GameSettings.values
	_saved_path = GameSettings.settings_path
	GameSettings.values = SettingsValues.new()
	GameSettings.settings_path = "user://test_sotavento_settings.cfg"


func after_each() -> void:
	GameSettings.values = _saved_values
	GameSettings.settings_path = _saved_path


func _height(grid: TerrainGrid, east_north: Vector2) -> float:
	var at: Vector3 = _spot.map_config.lv95_to_game(east_north.x, east_north.y, 0.0)
	return grid.height_at(at.x, at.z)


func test_the_origin_is_the_pwa_event_site() -> void:
	assert_eq(_spot.map_config.origin_east_m, CENTRE.x)
	assert_eq(_spot.map_config.origin_north_m, CENTRE.y)
	assert_eq(_spot.map_config.lake_level_m, 0.0, "the game's zero is mean sea level")


func test_the_water_level_floods_the_lagoon_and_not_the_bar() -> void:
	var grid: TerrainGrid = TerrainGrid.load_from(GRID_PATH)
	var flats_m: float = _height(grid, LAGOON_FLATS)
	var bar_m: float = _height(grid, BAR)
	assert_between(flats_m, 0.2, 0.86, "the lagoon's floor between mean sea level and mean high water")
	assert_gt(bar_m, 1.25, "the bar's crest above spring high water (a thin strip at high tide)")
	assert_lt(bar_m, 2.0, "and no higher: the high-tide photos show a low bar")
	grid.lower_by(1.1)
	assert_lt(_height(grid, LAGOON_FLATS), -0.3, "the lagoon one sheet of water at the session's high water")
	assert_gt(_height(grid, BAR), 0.0, "the bar stays dry")
	assert_almost_eq(_height(grid, BAR), bar_m - 1.1, 1e-4)


func test_the_lagoon_is_drained_at_low_water() -> void:
	var grid: TerrainGrid = TerrainGrid.load_from(GRID_PATH)
	grid.lower_by(-0.8)
	assert_gt(_height(grid, LAGOON_FLATS), 0.5, "dry at mean low water: you walk out to the sea")


func test_the_environment_applies_the_water_level() -> void:
	var environment: EnvironmentConfig = (load(ENVIRONMENT_PATH) as EnvironmentConfig).duplicate()
	environment.water_level_m = 0.4
	var lowered: TerrainGrid = environment.depth_grid()
	var plain: TerrainGrid = TerrainGrid.load_from(GRID_PATH)
	assert_almost_eq(_height(lowered, BAR), _height(plain, BAR) - 0.4, 1e-4)


func test_the_start_is_out_at_sea_past_the_bar() -> void:
	var environment: EnvironmentConfig = (load(ENVIRONMENT_PATH) as EnvironmentConfig).duplicate()
	environment.water_level_m = _spot.water_level_m
	var grid: TerrainGrid = environment.depth_grid()
	var start: Vector3 = _spot.start_position()
	assert_lt(grid.height_at(start.x, start.z), -3.0, "deep enough for the fin, room to bear away")
	assert_lt(start.distance_to(Vector3.ZERO), 600.0, "in front of the event site")
	# The start heading runs out to sea: deeper water 300 m ahead.
	var ahead: Vector3 = start + 300.0 * Vector3(sin(deg_to_rad(_spot.start_heading_deg)), 0.0, -cos(deg_to_rad(_spot.start_heading_deg)))
	assert_lt(grid.height_at(ahead.x, ahead.z), grid.height_at(start.x, start.z), "deeper ahead")


func test_the_far_grid_has_the_jandia_mountains_and_the_deep_sea() -> void:
	var far: TerrainGrid = TerrainGrid.load_from(FAR_GRID_PATH)
	assert_not_null(far)
	var lowest: float = INF
	var highest: float = -INF
	for row: int in range(0, far.rows, 16):
		for column: int in range(0, far.columns, 16):
			var height: float = far.height_at(far.x0_m + column * far.cell_m, far.z0_m + row * far.cell_m)
			lowest = minf(lowest, height)
			highest = maxf(highest, height)
	assert_gt(highest, 600.0, "the Jandia ridge (Pico de la Zarza, 807 m)")
	assert_lt(lowest, -1000.0, "the deep channel off the island")


func test_a_grid_mesh_has_its_squares_and_its_skirt() -> void:
	var quads: int = 4
	var mesh: ArrayMesh = HeightTerrain.grid_mesh(100.0, quads)
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var marks: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var border: int = 4 * quads
	assert_eq(vertices.size(), (quads + 1) * (quads + 1) + border, "the grid and a skirt vertex under each border vertex")
	assert_eq(indices.size(), quads * quads * 6 + border * 12, "two triangles a square, four a skirt piece (both faces)")
	var skirt: int = 0
	for mark: Vector2 in marks:
		if mark.x > 0.5:
			skirt += 1
	assert_eq(skirt, border)
	assert_almost_eq(vertices[0], Vector3(-50.0, 0.0, -50.0), Vector3.ONE * 1e-4, "centred on its origin")


func test_the_terrain_builds_its_chunks_from_the_grid() -> void:
	var terrain: HeightTerrain = HeightTerrain.new()
	terrain.heights_json = GRID_PATH
	terrain.chunk_m = 4000.0
	terrain.levels = [Vector2(100.0, 3000.0), Vector2(400.0, 0.0)]
	terrain.water_level_m = 1.1
	add_child_autofree(terrain)
	# 12 km a side in chunks of 4 km: 3 x 3, two detail levels each.
	assert_eq(terrain.get_child_count(), 18)
	var first: MeshInstance3D = terrain.get_child(0) as MeshInstance3D
	assert_eq(first.visibility_range_end, 3000.0)
	assert_gt(first.custom_aabb.size.y, 50.0, "the box holds the heights the shader lifts the mesh to")
	assert_almost_eq(terrain.material.get_shader_parameter("height_offset_m"), terrain.grid.height_offset_m(), 1e-6)
	assert_almost_eq(terrain.material.get_shader_parameter("water_level_m"), 1.1, 1e-6)


func test_the_sailing_scene_sails_at_sotavento() -> void:
	var scene: SailingScene = (load(SAIL_SCENE) as PackedScene).instantiate()
	add_child_autofree(scene)
	await wait_physics_frames(3)
	var windsurfer: WindsurferNode = scene.get_node("Windsurfer")
	assert_almost_eq(windsurfer.environment.water_level_m, _spot.water_level_m, 1e-6)
	assert_almost_eq(windsurfer.wind_config.from_bearing_deg, _spot.wind_from_deg, 1e-6, "the trade wind's direction")
	assert_true(windsurfer.sim.water is LakeWaveField, "the spot's own sea, grown over its fetch")
	assert_not_null(scene.shore_grid, "the shore check reads the depth grid")
	var terrain: HeightTerrain = scene.get_node("Map/NearTerrain")
	assert_almost_eq(terrain.water_level_m, _spot.water_level_m, 1e-6, "the terrain at the same water level")


func test_the_start_menu_offers_sotavento() -> void:
	var start_menu_script: GDScript = load("res://ui/start_menu.gd")
	var play_options: Dictionary = start_menu_script.get_script_constant_map()["PlayOption"]
	GameSettings.values.last_play_option = play_options["SAIL_SOTAVENTO"]
	var menu: Node = (load("res://ui/start_menu.tscn") as PackedScene).instantiate()
	add_child_autofree(menu)
	var button: Button = menu.get_node("%SailSotaventoButton")
	assert_eq(button.text, "Sotavento")
	assert_true(button.has_focus(), "the last choice has the focus")
	assert_eq(start_menu_script.get_script_constant_map()["SAIL_SOTAVENTO_SCENE"], SAIL_SCENE)


func test_the_settings_remember_the_sotavento_choice() -> void:
	var saved: SettingsValues = SettingsValues.new()
	saved.last_play_option = 6
	var config: ConfigFile = ConfigFile.new()
	saved.write_to(config)
	var loaded: SettingsValues = SettingsValues.new()
	loaded.read_from(config)
	assert_eq(loaded.last_play_option, 6)
