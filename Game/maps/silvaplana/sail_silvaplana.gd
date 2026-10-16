class_name SilvaplanaSailing
extends SailingScene
## Sailing on Lake Silvaplana (MAP_SILVAPLANA_PLAN.md, M3): the open-water sailing scene
## (main.gd: the windsurfer, the cameras, the HUD, the pause menu, the settings, the restart and
## the screenshot options) on the real map. What is different here:
## - the map (silvaplana.tscn) brings the terrain, the sky, the sun and the haze,
## - the wind is the lake's own (wind_silvaplana.tres: a Maloja afternoon from 222 degrees), not
##   the settings' wind; the settings' waves and sailing options still apply,
## - the board starts off the camping beach and runs aground in the shallows (main.gd's shore
##   check, with the map's depth grid),
## - the water has the lake's colours and mirrors the valley (render layer 2, which the map's
##   LakeReflections probe lights); far away it is a flat surface in the lake's shape (LakeArea)
##   instead of a plane to the horizon, so the land lower than the lake stays dry,
## - the HUD has a small map of the lake.
## The map's own wind model (MapWind), the thin air and the fresh water come later (W5, R5).
##
## Options for screenshots and checks, besides main.gd's (LV95 metres; heights above the lake):
##   --heading=<degrees>              start with this heading instead of 132
##   --start=<east>,<north>           start at this spot instead of off the camping beach
##   --overview=<east>,<north>,<height>  a fixed camera there, looking at the board
##   --measure=1                      print the frame rate (no vsync) and quit; run it with
##       tools/godot.sh --path Game res://maps/silvaplana/sail_silvaplana.tscn -- --measure=1
## tools/screenshot.sh res://maps/silvaplana/sail_silvaplana.tscn out.png 480 --autopilot=1 --camera=2

const MAP_CONFIG_PATH: String = "res://maps/silvaplana/map_config.tres"
const GRID_PATH: String = "res://maps/silvaplana/terrain/shore_heights.json"
const WIND_PATH: String = "res://maps/silvaplana/wind_silvaplana.tres"
## The game's water shader in the lake's colours (M2).
const LAKE_WATER_PATH: String = "res://maps/silvaplana/lake_water.tres"
## The lake water's look, copied onto the water with the waves (the rest is the waves' own).
const LAKE_LOOK_PARAMETERS: Array[String] = ["deep_color", "shallow_color", "roughness_value", "grid_strength"]
## The map's LakeReflections probe mirrors the valley into what is on this render layer only.
const LAKE_LAYER: int = 2

## The start: in the water 40 m off the camping beach at the north end of the lake (the terrain
## view's "launch" viewpoint), LV95 east and north in metres. The water there is 23 m deep.
const START_LV95: Vector2 = Vector2(2780880.0, 1147510.0)
## Across the wind (from 222) on starboard tack: out over the widest part of the lake, with
## 1.2 km of open water ahead. The other beam reach, 312, runs onto the beach 30 m away.
const START_HEADING_DEG: float = 132.0
## The flat far water: the lake found every 8 m and widened by two steps, so it reaches in
## under the shore (LakeArea.build_mesh).
const LAKE_STEP_M: float = 8.0
const LAKE_MARGIN_STEPS: int = 2

@onready var _map_sun: DirectionalLight3D = $Silvaplana/Sun

var _map_config: MapConfig
var _lake_area: LakeArea
var _lake_surface: MeshInstance3D
## The --overview camera position (Vector3.INF: none).
var _overview_at: Vector3 = Vector3.INF


func _enter_tree() -> void:
	_map_config = load(MAP_CONFIG_PATH)
	super()
	var windsurfer: WindsurferNode = $Windsurfer
	windsurfer.start_position = start_position()


func _ready() -> void:
	shore_grid = TerrainGrid.load_from(GRID_PATH)
	_lake_area = LakeArea.from_grid(shore_grid, start_position(), LAKE_STEP_M)
	_add_lake_surface()
	super()
	_dress_water()
	_hud.show_mini_map(_lake_area, start_position())
	_apply_map_options()


func _process(delta: float) -> void:
	super(delta)
	if _overview_at != Vector3.INF:
		_camera_rig.camera.global_position = _overview_at
		_camera_rig.camera.look_at(_windsurfer.get_global_transform_interpolated().origin)


## The start spot in game coordinates, on the water.
func start_position() -> Vector3:
	var lv95: Vector2 = START_LV95
	var numbers: PackedFloat64Array = _option_numbers("start")
	if numbers.size() == 2:
		lv95 = Vector2(numbers[0], numbers[1])
	var at: Vector3 = _map_config.lv95_to_game(lv95.x, lv95.y, _map_config.lake_level_m)
	return Vector3(at.x, 0.0, at.z)


## The lake's own wind, a copy so the file on disk (shared by everything that loads it) never
## changes.
func _build_wind_config() -> WindConfig:
	var lake_wind: WindConfig = load(WIND_PATH)
	return lake_wind.duplicate(true)


func _start_heading_deg() -> float:
	var numbers: PackedFloat64Array = _option_numbers("heading")
	return numbers[0] if numbers.size() == 1 else START_HEADING_DEG


## The lake keeps its own wind when the settings change (the settings' wind is the open water's).
func _apply_wind_settings_live() -> void:
	pass


## After main.gd builds new water (new waves after a restart), it gets the lake's look again.
func _rebuild_sea() -> void:
	super()
	_dress_water()


## The Shadows setting on the map's sun (main.gd sets it on the open water's sun).
func _apply_start_settings() -> void:
	super()
	_map_sun.shadow_enabled = GameSettings.values.shadow_quality > 0


func apply_settings_live() -> void:
	super()
	_map_sun.shadow_enabled = GameSettings.values.shadow_quality > 0


## The water with the waves (OceanNode's NearWater) in the lake's colours and on the lake's render
## layer, and the OceanNode's far plane hidden: the flat lake surface takes its place. ocean.gd has
## no settings for this yet, so it is done here, on its two meshes, after every OceanNode.setup().
func _dress_water() -> void:
	var lake_look: ShaderMaterial = load(LAKE_WATER_PATH)
	var near: MeshInstance3D = _ocean.get_node("NearWater")
	near.layers = LAKE_LAYER
	var near_material: ShaderMaterial = near.material_override
	for parameter: String in LAKE_LOOK_PARAMETERS:
		near_material.set_shader_parameter(parameter, lake_look.get_shader_parameter(parameter))
	var far: MeshInstance3D = _ocean.get_node("FarWater")
	far.visible = false
	# Just under the deepest wave trough, as the OceanNode's far plane was: the water with the
	# waves always covers it.
	_lake_surface.position.y = -_wave_amplitude_m() - 0.02


## The flat water far away, in the lake's shape, drawn with the lake's water without waves.
func _add_lake_surface() -> void:
	_lake_surface = MeshInstance3D.new()
	_lake_surface.name = "LakeSurface"
	_lake_surface.mesh = _lake_area.build_mesh(LAKE_MARGIN_STEPS)
	_lake_surface.material_override = load(LAKE_WATER_PATH)
	_lake_surface.layers = LAKE_LAYER
	add_child(_lake_surface)


## How far the waves reach above and below the still water (0 on flat water).
func _wave_amplitude_m() -> float:
	var waves: WaveField = _windsurfer.sim.water as WaveField
	return waves.total_amplitude_m() if waves != null else 0.0


## --overview and --measure (see the top of this file).
func _apply_map_options() -> void:
	var overview: PackedFloat64Array = _option_numbers("overview")
	if overview.size() == 3:
		_overview_at = _map_config.lv95_to_game(overview[0], overview[1], overview[2] + _map_config.lake_level_m)
		_camera_rig.set_process(false)
	if _option_numbers("measure").size() == 1:
		_measure_frame_rate()


## The numbers of a command-line option --name=a,b,c (empty when it is not given).
func _option_numbers(option: String) -> PackedFloat64Array:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % option):
			return arg.get_slice("=", 1).split_floats(",")
	return PackedFloat64Array()


## How fast the lake draws while sailing, without waiting for the screen (no vsync): printed to
## the console, then the game quits.
func _measure_frame_rate() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	print("Graphics card: %s (%s)" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor()])
	for i: int in 180:  # warm up: shaders, the probe, shadows
		await get_tree().process_frame
	var start_us: int = Time.get_ticks_usec()
	for i: int in 300:
		await get_tree().process_frame
	var seconds: float = (Time.get_ticks_usec() - start_us) / 1e6
	print("Sailing on Lake Silvaplana: %.0f fps (camera: %s)" % [300.0 / seconds, _camera_rig.mode_name()])
	get_tree().quit()
