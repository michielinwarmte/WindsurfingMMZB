extends Node3D
## A look around the Silvaplana map (MAP_SILVAPLANA_PLAN.md, M1 and M2): the terrain with its
## aerial photos, the map's sky, sun and haze, a flat stand-in for the lake (the map's see-through
## lake water; G switches to the game's water shader to compare), and a free camera. Not the
## game: the real water with its waves, and the sailing, come in M3.
##
## Keys: 1 to 4 jump to the viewpoints below; fly with W A S D, E and Q, Shift for speed; hold the
## right mouse button to look around; the mouse wheel changes the speed (see FlyCamera).
## The camera's near and far planes are the game camera's (0.05 m and 35 km, camera_rig.gd), so
## flickering on the far ridges would show here too.
## For screenshots: tools/screenshot.sh res://maps/silvaplana/dev/terrain_view.tscn out.png 90 --view=launch
## Any other viewpoint: --at=<east>,<north>,<metres above the lake> --look=<east>,<north>,<metres above the lake> (LV95).

const CONFIG_PATH: String = "res://maps/silvaplana/map_config.tres"
const GRID_PATH: String = "res://maps/silvaplana/terrain/shore_heights.json"
## The map's see-through lake water, and the game's water shader in the lake's colours.
const LAKE_PATH: String = "res://maps/silvaplana/lake.tres"
const GAME_WATER_PATH: String = "res://maps/silvaplana/lake_water.tres"

## Viewpoints: where the camera is (LV95 east, north, metres above the lake) and the point it looks at.
const VIEWPOINTS: Dictionary[String, Array] = {
	# On the water 40 m off the camping beach at the north end, 2 m up, looking down the lake to
	# the south-west, where the Maloja comes from.
	"launch": [Vector3(2780880.0, 1147510.0, 2.0), Vector3(2779200.0, 1145300.0, 40.0)],
	# Above Silvaplana village, looking south-west over the lake.
	"village": [Vector3(2781250.0, 1148250.0, 60.0), Vector3(2779300.0, 1145600.0, 0.0)],
	# High above the valley in the north-east, looking at the lake.
	"above": [Vector3(2785500.0, 1152500.0, 1400.0), Vector3(2780200.0, 1146300.0, 0.0)],
	# Straight down from 6 km above the lake (north at the top of the screen).
	"top": [Vector3(2780500.0, 1146600.0, 6000.0), Vector3(2780500.0, 1146601.0, 0.0)],
}
const VIEW_KEYS: Array[String] = ["launch", "village", "above", "top"]

@onready var _camera: FlyCamera = $FlyCamera
@onready var _info: Label = $Info/Label

var _config: MapConfig
var _grid: TerrainGrid
var _water: MeshInstance3D


func _ready() -> void:
	_config = load(CONFIG_PATH)
	_grid = TerrainGrid.load_from(GRID_PATH)
	_add_lake_stand_in()
	_go_to(_view_from_command_line())
	_place_from_command_line()
	if "--measure=1" in OS.get_cmdline_user_args():
		_measure_speed()


func _unhandled_input(event: InputEvent) -> void:
	for i: int in VIEW_KEYS.size():
		if event.is_action_pressed("camera_%d" % (i + 1)):
			_go_to(VIEW_KEYS[i])
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_G:
		_show_game_water(_water.material_override.resource_path == LAKE_PATH)


func _process(_delta: float) -> void:
	var at: Vector3 = _camera.global_position
	var lv95: PackedFloat64Array = _config.game_to_lv95(at)
	var ground: float = _grid.height_at(at.x, at.z)
	var ground_text: String = "%.1f m" % ground if not is_nan(ground) else "outside the shore band"
	_info.text = "LV95 %.0f / %.0f, %.0f m above the lake (%.0f m above sea level), ground here: %s\n" % [
		lv95[0], lv95[1], at.y, lv95[2], ground_text] \
		+ "%d fps, camera speed %.0f m/s | 1-4 viewpoints, W A S D E Q fly, Shift fast, right mouse look, wheel speed, G water" % [
		Engine.get_frames_per_second(), _camera.speed_ms]


func _go_to(view: String) -> void:
	var points: Array = VIEWPOINTS[view]
	var at: Vector3 = points[0]
	var target: Vector3 = points[1]
	_camera.place(_config.lv95_to_game(at.x, at.y, at.z + _config.lake_level_m),
		_config.lv95_to_game(target.x, target.y, target.z + _config.lake_level_m))
	_camera.speed_ms = clampf(at.z, 20.0, 1000.0)


## With --measure=1: how fast every viewpoint draws, without waiting for the screen (no vsync),
## printed to the console, then quits. Run with tools/godot.sh --path Game res://maps/silvaplana/dev/terrain_view.tscn -- --measure=1
func _measure_speed() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	print("Graphics card: %s (%s)" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor()])
	for view: String in VIEW_KEYS:
		_go_to(view)
		for i: int in 120:  # warm up: shaders, LODs, shadows
			await get_tree().process_frame
		var start_us: int = Time.get_ticks_usec()
		for i: int in 120:
			await get_tree().process_frame
		var seconds: float = (Time.get_ticks_usec() - start_us) / 1e6
		print("%-8s %4.0f fps" % [view, 120.0 / seconds])
	get_tree().quit()


## --at=e,n,h and --look=e,n,h: a viewpoint of your own, in LV95 and metres above the lake.
func _place_from_command_line() -> void:
	var at: Vector3 = Vector3.INF
	var look: Vector3 = Vector3.INF
	for arg: String in OS.get_cmdline_user_args():
		var numbers: PackedFloat64Array = arg.get_slice("=", 1).split_floats(",")
		if numbers.size() != 3:
			continue
		var point: Vector3 = _config.lv95_to_game(numbers[0], numbers[1], numbers[2] + _config.lake_level_m)
		if arg.begins_with("--at="):
			at = point
		elif arg.begins_with("--look="):
			look = point
	if at != Vector3.INF and look != Vector3.INF:
		_camera.place(at, look)


func _view_from_command_line() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--view="):
			var view: String = arg.trim_prefix("--view=")
			if VIEWPOINTS.has(view):
				return view
			push_warning("Unknown view '%s', use one of %s" % [view, VIEW_KEYS])
	return "launch"


## A flat plane at the water level over the shore band, so the lake reads as a lake; the terrain
## hides it on land. It shows the map's see-through lake water (lake.tres), or with G (or
## --water=game) the game's water shader in the lake's colours (lake_water.tres), to compare.
## Only for this view: the game's water, with its waves, comes in M3.
func _add_lake_stand_in() -> void:
	var plane: PlaneMesh = PlaneMesh.new()
	var width: float = (_grid.columns - 1) * _grid.cell_m
	var depth: float = (_grid.rows - 1) * _grid.cell_m
	plane.size = Vector2(width, depth)
	_water = MeshInstance3D.new()
	_water.name = "LakeStandIn"
	_water.mesh = plane
	_water.position = Vector3(_grid.x0_m + width / 2.0, 0.0, _grid.z0_m + depth / 2.0)
	# Render layer 2 only: the map's LakeReflections probe mirrors the mountains in this layer.
	_water.layers = 2
	add_child(_water)
	_show_game_water("--water=game" in OS.get_cmdline_user_args())


func _show_game_water(game_water: bool) -> void:
	_water.material_override = load(GAME_WATER_PATH if game_water else LAKE_PATH)
