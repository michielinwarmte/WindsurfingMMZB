extends GutTest
## Sailing on Lake Silvaplana (MAP_SILVAPLANA_PLAN.md, M3): the shore stops the board (MD6), the
## start spot is in deep water with open water ahead, the lake's own wind, the lake's water area,
## the compass's north on the map, and the lake scene and its start menu option.

const SAIL_SCENE: String = "res://maps/silvaplana/sail_silvaplana.tscn"
const GRID_PATH: String = "res://maps/silvaplana/terrain/shore_heights.json"
const CONFIG_PATH: String = "res://maps/silvaplana/map_config.tres"
const WIND_PATH: String = "res://maps/silvaplana/wind_silvaplana.tres"
const FIN_DEPTH_M: float = 0.38


## A depth grid for the tests: the same depth everywhere inside a 200 m square around the origin.
class FakeGrid:
	extends TerrainGrid
	var depth_m: float = 5.0

	func _init(depth: float) -> void:
		depth_m = depth

	func contains(x: float, z: float) -> bool:
		return absf(x) <= 100.0 and absf(z) <= 100.0

	func height_at(x: float, z: float) -> float:
		return -depth_m if contains(x, z) else NAN


var _saved_values: SettingsValues
var _saved_path: String
var _grid: TerrainGrid
var _config: MapConfig


func before_all() -> void:
	_grid = TerrainGrid.load_from(GRID_PATH)
	_config = load(CONFIG_PATH)


func before_each() -> void:
	# The tests use their own settings and never write the player's settings file.
	_saved_values = GameSettings.values
	_saved_path = GameSettings.path
	GameSettings.values = SettingsValues.new()
	GameSettings.path = ""


func after_each() -> void:
	get_tree().paused = false
	GameSettings.values = _saved_values
	GameSettings.path = _saved_path


func test_the_shore_check_reads_the_depth_against_the_fin() -> void:
	var at: Vector3 = Vector3(10.0, 0.0, -20.0)
	assert_false(ShoreCheck.is_aground(FakeGrid.new(5.0), at, FIN_DEPTH_M), "5 m of water: sailing")
	assert_false(ShoreCheck.is_aground(FakeGrid.new(0.55), at, FIN_DEPTH_M), "0.55 m: the fin and the margin fit")
	assert_true(ShoreCheck.is_aground(FakeGrid.new(0.45), at, FIN_DEPTH_M), "0.45 m: less than the fin plus 0.12 m")
	assert_true(ShoreCheck.is_aground(FakeGrid.new(-1.0), at, FIN_DEPTH_M), "on land")
	assert_true(ShoreCheck.is_aground(FakeGrid.new(5.0), Vector3(150.0, 0.0, 0.0), FIN_DEPTH_M), "off the map")
	assert_almost_eq(ShoreCheck.depth_at(FakeGrid.new(5.0), at), 5.0, 1e-6)


func test_deep_water_sails_on_and_shallow_water_stops() -> void:
	var scene: SailingScene = (load("res://main.tscn") as PackedScene).instantiate()
	add_child_autofree(scene)
	var windsurfer: WindsurferNode = scene.get_node("Windsurfer")
	var hud: Hud = scene.get_node("HUD")
	scene.shore_grid = FakeGrid.new(5.0)
	await wait_physics_frames(10)
	assert_false(scene.is_aground(), "deep water")
	assert_gt(windsurfer.sim.time_s, 0.0, "the simulation steps")

	scene.shore_grid = FakeGrid.new(0.3)
	await wait_physics_frames(3)
	assert_true(scene.is_aground(), "0.3 m of water is too shallow for the fin")
	assert_false(windsurfer.is_physics_processing(), "the simulation stops")
	assert_string_contains(hud.message(), "Aground")
	var stopped_at_s: float = windsurfer.sim.time_s
	await wait_physics_frames(5)
	assert_eq(windsurfer.sim.time_s, stopped_at_s, "and stays stopped")

	# R (here the pause menu's Restart) takes the board back to the start, in deep water again.
	scene.shore_grid = FakeGrid.new(5.0)
	scene.get_node("PauseMenu").restart_requested.emit()
	assert_false(scene.is_aground())
	assert_eq(hud.message(), "", "the message goes away")
	await wait_physics_frames(5)
	assert_gt(windsurfer.sim.time_s, 0.0, "sailing again")
	assert_false(scene.is_aground())


func test_the_start_spot_is_deep_with_open_water_ahead() -> void:
	var start: Vector3 = _config.lv95_to_game(SilvaplanaSailing.START_LV95.x, SilvaplanaSailing.START_LV95.y, _config.lake_level_m)
	assert_gt(ShoreCheck.depth_at(_grid, start), 1.0, "more than a metre of water at the start")
	assert_lt(_distance_to_shore_m(start, SilvaplanaSailing.START_HEADING_DEG), 0.0, "no shore within 1 km on the start heading")
	assert_between(_distance_to_shore_m(start, 312.0), 0.0, 60.0, "the other beam reach runs onto the camping beach")
	# Across the wind (from 222): a beam reach on starboard tack.
	var wind: WindConfig = load(WIND_PATH)
	assert_almost_eq(wind.from_bearing_deg - SilvaplanaSailing.START_HEADING_DEG, 90.0, 0.1)


func test_the_lake_wind() -> void:
	var wind: WindConfig = load(WIND_PATH)
	assert_almost_eq(wind.speed_kt, 16.0, 1e-6)
	assert_almost_eq(wind.from_bearing_deg, 222.0, 1e-6, "along the lake from the south-west (W1)")
	assert_true(wind.gusts_enabled)
	assert_almost_eq(wind.gust_intensity, 0.25, 1e-6, "12 to 20 kt")
	assert_true(wind.shifts_enabled)
	assert_almost_eq(wind.max_shift_deg, 10.0, 1e-6)
	assert_almost_eq(wind.shift_period_s, 60.0, 1e-6)


func test_the_lake_area_is_the_lake_and_nothing_else() -> void:
	var start: Vector3 = _config.lv95_to_game(SilvaplanaSailing.START_LV95.x, SilvaplanaSailing.START_LV95.y, _config.lake_level_m)
	var area: LakeArea = LakeArea.from_grid(_grid, start, 8.0)
	assert_true(area.is_lake_at(start.x, start.z), "the start spot")
	assert_true(area.is_lake_at(0.0, 0.0), "the middle of the lake")
	var camping: Vector3 = _config.lv95_to_game(2780866.0, 1147617.0, 0.0)
	assert_false(area.is_lake_at(camping.x, camping.z), "the camping is land")
	# Lake Silvaplana and Lake Champfer together are about 2.9 km2.
	assert_between(area.lake_spot_count() * 64.0, 2.6e6, 3.2e6, "the lake's area in m2")
	# A puddle at the Inn's mouth, a few centimetres below the lake level but not joined to it.
	assert_false(area.is_lake_at(-788.0, 560.0), "a low spot that is not joined to the lake")
	var mesh: ArrayMesh = area.build_mesh(2)
	assert_eq(mesh.get_surface_count(), 1)
	var triangles: int = mesh.surface_get_array_len(0) / 3
	assert_between(triangles, 500, 10000, "joined into strips: a small mesh")


func test_the_compass_north_is_the_real_north() -> void:
	# MD1: LV95 north is the game's -Z, so a compass heading in the game is a real bearing.
	var north_100m: Vector3 = _config.lv95_to_game(2780500.0, 1146700.0, 1790.63)
	assert_almost_eq(north_100m, Vector3(0.0, 0.0, -100.0), Vector3.ONE * 1e-3)
	var sim: WindsurferSim = WindsurferSim.create_default(false)
	sim.reset(Vector3.ZERO, deg_to_rad(132.0))
	var forward: Vector3 = sim.body.basis * Vector3.FORWARD
	var lv95_from: PackedFloat64Array = _config.game_to_lv95(Vector3.ZERO)
	var lv95_to: PackedFloat64Array = _config.game_to_lv95(forward * 100.0)
	var bearing_deg: float = fposmod(rad_to_deg(atan2(lv95_to[0] - lv95_from[0], lv95_to[1] - lv95_from[1])), 360.0)
	assert_almost_eq(bearing_deg, 132.0, 0.01, "heading 132 sails toward the real south-east")


func test_the_lake_scene() -> void:
	var scene: SilvaplanaSailing = (load(SAIL_SCENE) as PackedScene).instantiate()
	add_child_autofree(scene)
	var windsurfer: WindsurferNode = scene.get_node("Windsurfer")
	assert_almost_eq(windsurfer.sim.wind_config.from_bearing_deg, 222.0, 1e-6, "the lake's wind, not the settings'")
	assert_almost_eq(windsurfer.sim.wind_config.speed_kt, 16.0, 1e-6)
	var start: Vector3 = scene.start_position()
	assert_almost_eq(start, Vector3(380.0, 0.0, -910.0), Vector3.ONE * 0.01, "off the camping beach")
	assert_almost_eq(windsurfer.sim.body.origin_world().x, start.x, 0.01)
	assert_almost_eq(windsurfer.sim.body.origin_world().z, start.z, 0.01)
	assert_almost_eq(windsurfer.sim.telemetry.heading_deg, 132.0, 0.5)
	assert_not_null(scene.shore_grid)
	assert_false(scene.is_aground())
	# The water: the lake's colours on render layer 2 (the reflection probe's), no far plane.
	var near: MeshInstance3D = scene.get_node("Ocean/NearWater")
	assert_eq(near.layers, 2)
	var lake_look: ShaderMaterial = load("res://maps/silvaplana/lake_water.tres")
	assert_eq((near.material_override as ShaderMaterial).get_shader_parameter("deep_color"), lake_look.get_shader_parameter("deep_color"))
	assert_false((scene.get_node("Ocean/FarWater") as MeshInstance3D).visible)
	var surface: MeshInstance3D = scene.get_node("LakeSurface")
	assert_eq(surface.layers, 2)
	assert_lt(surface.position.y, 0.0, "under the wave troughs")
	assert_eq(scene.get_node("HUD").find_children("*", "MiniMap", true, false).size(), 1, "a small map of the lake")
	# The settings' wind is the open water's: the lake keeps its own.
	GameSettings.values.wind_from_deg = 90.0
	scene.apply_settings_live()
	assert_almost_eq(windsurfer.sim.wind.config.from_bearing_deg, 222.0, 1e-6)
	# A restart builds the water again when the waves changed, and it keeps the lake's look.
	GameSettings.values.wave_preset = SettingsValues.WavePreset.STRONG_CHOP
	scene.get_node("PauseMenu").restart_requested.emit()
	near = scene.get_node("Ocean/NearWater")
	assert_eq(near.layers, 2)
	assert_almost_eq(surface.position.y, -0.182 - 0.02, 1e-4, "the strong chop's troughs")


func test_the_start_menu_offers_the_lake() -> void:
	var start_menu_script: GDScript = load("res://ui/start_menu.gd")
	var play_options: Dictionary = start_menu_script.get_script_constant_map()["PlayOption"]
	GameSettings.values.last_play_option = play_options["SAIL_SILVAPLANA"]
	var menu: Node = (load("res://ui/start_menu.tscn") as PackedScene).instantiate()
	add_child_autofree(menu)
	var lake_button: Button = menu.get_node("%SailSilvaplanaButton")
	assert_eq(lake_button.text, "Sail on Lake Silvaplana")
	assert_true(lake_button.has_focus(), "the last choice has the focus")
	var layout: Node = lake_button.get_parent()
	assert_eq(lake_button.get_index(), layout.get_node("OpenWaterHint").get_index() + 1, "the second option")
	# Esc in the lake scene opens the pause menu: the map scenes' Esc-to-menu stays out of it.
	var escape: GDScript = load("res://ui/map_escape.gd")
	var map_scenes: Array = escape.get_script_constant_map()["MAP_SCENES"]
	assert_false(SAIL_SCENE in map_scenes)


## How far along a heading the board would run aground (-1: not within 1 km).
func _distance_to_shore_m(from: Vector3, heading_deg: float) -> float:
	var direction: Vector3 = Vector3(sin(deg_to_rad(heading_deg)), 0.0, -cos(deg_to_rad(heading_deg)))
	for step: int in 101:
		var distance_m: float = step * 10.0
		if ShoreCheck.is_aground(_grid, from + direction * distance_m, FIN_DEPTH_M):
			return distance_m
	return -1.0
