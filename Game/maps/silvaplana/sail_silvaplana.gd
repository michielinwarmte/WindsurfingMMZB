class_name SilvaplanaSailing
extends SailingScene
## Sailing on Lake Silvaplana (MAP_SILVAPLANA_PLAN.md, M3): the open-water sailing scene
## (main.gd: the windsurfer, the cameras, the HUD, the pause menu, the settings, the restart and
## the screenshot options) on the real map. What is different here:
## - the map (silvaplana.tscn) brings the terrain, the sky, the sun and the haze,
## - the place is the lake's own (environment_silvaplana.tres, PHYSICS_REQUESTS_FROM_MAP.md R1 to
##   R3 and W5): thin air (0.98 kg/m3), fresh water, and the map's own wind (MapWind: the Maloja
##   over the terrain, the day's cycle, the gusts rolling down the lake, the lee under the shore),
##   not the settings' wind; the settings' waves and sailing options still apply,
## - the time of day runs (from 14:30, in real time) and the HUD shows it: the Maloja builds
##   until about 14:30 and fades in the evening,
## - the board starts off the camping beach and runs aground in the shallows (main.gd's shore
##   check, with the map's depth grid),
## - the water has the lake's look (lake_water.tres) and mirrors the valley (render layer 2, which
##   the map's LakeReflections probe lights); the far water covers only the depth grid's area,
##   where the terrain hides it on land, so the land lower than the lake stays dry,
## - the gusts show on the water as patches of stronger ripples (WindRippleMap),
## - the HUD has a small map of the lake.
##
## Options for screenshots and checks, besides main.gd's (LV95 metres; heights above the lake):
##   --time=<hh:mm>                   start at this time of day instead of 14:30
##   --heading=<degrees>              start with this heading instead of 132
##   --start=<east>,<north>           start at this spot instead of off the camping beach
##   --overview=<east>,<north>,<height>  a fixed camera there, looking at the board
##   --measure=<seconds>              print the frame rate and the frame times (main.gd) and quit
##   --check-gusts=1                  compare the gust picture the graphics card drew with
##       MapWind's numbers, print the result and quit (run it the same way)
##   --course=<name>                  a race course on the lake (main.gd): t2_slalom, or any course
##       the course maker saved; until t2_slalom.json is saved, t2_slalom is a stand-in placed by
##       code at the start spot (RaceCourses.t2_stand_in(), not fitted to the water)
## tools/screenshot.sh res://maps/silvaplana/sail_silvaplana.tscn out.png 480 --autopilot=1 --camera=2

const MAP_CONFIG_PATH: String = "res://maps/silvaplana/map_config.tres"
const GRID_PATH: String = "res://maps/silvaplana/terrain/shore_heights.json"
## The lake's air, water and wind (R1 to R3, W5).
const ENVIRONMENT_PATH: String = "res://maps/silvaplana/environment_silvaplana.tres"
## The gust picture on the water: this many pixels a side over the lake's area (about 15 m each).
const GUST_PICTURE_PIXELS: int = 256

## The start: in the water 40 m off the camping beach at the north end of the lake (the terrain
## view's "launch" viewpoint), LV95 east and north in metres. The water there is 23 m deep.
const START_LV95: Vector2 = Vector2(2780880.0, 1147510.0)
## Across the wind (from 222) on starboard tack: out over the widest part of the lake, with
## 1.2 km of open water ahead. The other beam reach, 312, runs onto the beach 30 m away.
const START_HEADING_DEG: float = 132.0
## The lake for the small map: found every 8 m (LakeArea).
const LAKE_STEP_M: float = 8.0

@onready var _map_sun: DirectionalLight3D = $Silvaplana/Sun

var _map_config: MapConfig
var _lake_area: LakeArea
## The gusts on the water (null when the map's wind is off).
var _gust_picture: WindRippleMap = null
## The --overview camera position (Vector3.INF: none).
var _overview_at: Vector3 = Vector3.INF


func _enter_tree() -> void:
	_map_config = load(MAP_CONFIG_PATH)
	var windsurfer: WindsurferNode = $Windsurfer
	windsurfer.environment = load(ENVIRONMENT_PATH)
	# Before main.gd's part, which moves the start behind a race course's start line (--course).
	windsurfer.start_position = start_position()
	super()


func _ready() -> void:
	shore_grid = TerrainGrid.load_from(GRID_PATH)
	_lake_area = LakeArea.from_grid(shore_grid, start_position(), LAKE_STEP_M)
	# The far water covers the depth grid's area only (OceanNode.far_area_xz): where the land in
	# it is higher than the lake the terrain hides it, and outside it there is no water at all.
	_ocean.far_area_xz = Rect2(shore_grid.x0_m, shore_grid.z0_m,
		(shore_grid.columns - 1) * shore_grid.cell_m, (shore_grid.rows - 1) * shore_grid.cell_m)
	# The small map of the lake, before main.gd's part puts a race course on it (--course). Its
	# ring is where the board starts: behind the start line when there is a course.
	_hud.show_mini_map(_lake_area, _windsurfer.start_position)
	super()
	_start_the_clock()
	_add_gust_picture()
	_apply_map_options()


func _process(delta: float) -> void:
	super(delta)
	_show_the_wind_of_the_moment()
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


## No wind from the settings: the lake's environment brings its own (the map's wind).
func _build_wind_config() -> WindConfig:
	return null


func _start_heading_deg() -> float:
	var numbers: PackedFloat64Array = _option_numbers("heading")
	if numbers.size() == 1:
		return numbers[0]
	# With a race course: a beam reach behind its start line (main.gd).
	return super() if _course != null else START_HEADING_DEG


## The lake's race courses by name (main.gd's --course): any course the course maker saved; and
## t2_slalom, until Max's fitted one is saved, as a stand-in placed by code for the lake's wind at
## the start spot.
func _course_named(course_name: String, usual_start: Vector2) -> Course:
	var saved: Course = RaceCourses.load_named(course_name, _map_config)
	if saved != null or course_name != RaceCourses.T2_NAME:
		return saved
	var windsurfer: WindsurferNode = $Windsurfer
	return RaceCourses.t2_stand_in(windsurfer.environment.wind.from_bearing_deg, usual_start)


## The lake keeps its own wind when the settings change (the settings' wind is the open water's).
func _apply_wind_settings_live() -> void:
	pass


## After main.gd builds new water (new waves after a restart), the gusts go on it again.
func _rebuild_sea() -> void:
	super()
	_put_gusts_on_water()


## The Shadows setting on the map's sun (main.gd sets it on the open water's sun).
func _apply_start_settings() -> void:
	super()
	_map_sun.shadow_enabled = GameSettings.values.shadow_quality > 0


func apply_settings_live() -> void:
	super()
	_map_sun.shadow_enabled = GameSettings.values.shadow_quality > 0


## The map's wind field of the simulation (null when the environment has the map's wind off).
func map_wind_field() -> MapWindField:
	return _windsurfer.sim.wind as MapWindField


## The time of day the sailing starts at: 14:30, or --time=<hh:mm>.
func _start_the_clock() -> void:
	var field: MapWindField = map_wind_field()
	if field == null:
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--time="):
			var parts: PackedStringArray = arg.get_slice("=", 1).split(":")
			var minutes: float = parts[1].to_float() if parts.size() > 1 else 0.0
			field.set_time_of_day(parts[0].to_float() * 3600.0 + minutes * 60.0)
	_hud.clock_text = field.time_of_day_text().left(5)  # hours and minutes: the strip is full


## The gust picture (WindRippleMap) over the depth grid's area, on the water.
func _add_gust_picture() -> void:
	var field: MapWindField = map_wind_field()
	if field == null:
		return
	_gust_picture = WindRippleMap.new()
	_gust_picture.name = "GustPicture"
	add_child(_gust_picture)
	_gust_picture.setup(field.map_wind, _ocean.far_area_xz, shore_grid, GUST_PICTURE_PIXELS)
	_gust_picture.show_moment(field.moment())
	_put_gusts_on_water()


func _put_gusts_on_water() -> void:
	if _gust_picture == null:
		return
	_ocean.set_water_parameter("wind_ripple_map", _gust_picture.get_texture())
	_ocean.set_water_parameter("wind_ripple_map_area", _gust_picture.area_vector())


## Every frame: the time on the HUD and the gusts of the moment on the water.
func _show_the_wind_of_the_moment() -> void:
	var field: MapWindField = map_wind_field()
	if field == null:
		return
	_hud.clock_text = field.time_of_day_text().left(5)  # hours and minutes: the strip is full
	if _gust_picture != null:
		_gust_picture.show_moment(field.moment())


## --overview and --measure (see the top of this file).
func _apply_map_options() -> void:
	var overview: PackedFloat64Array = _option_numbers("overview")
	if overview.size() == 3:
		_overview_at = _map_config.lv95_to_game(overview[0], overview[1], overview[2] + _map_config.lake_level_m)
		_camera_rig.set_process(false)
	if _option_numbers("check-gusts").size() == 1:
		_check_gust_picture()


## The numbers of a command-line option --name=a,b,c (empty when it is not given).
func _option_numbers(option: String) -> PackedFloat64Array:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % option):
			return arg.get_slice("=", 1).split_floats(",")
	return PackedFloat64Array()


## How fast the lake draws while sailing, without waiting for the screen (no vsync): printed to
## the console, then the game quits.
## --check-gusts: reads the gust picture back from the graphics card and compares it, every 8th
## pixel, with MapWind.velocity_in() for the same moment (as the picture's red channel: the wind
## relative to the lake's mean, to the shader's contrast, halved, in 8-bit steps of 0.004). Prints
## the result and quits.
func _check_gust_picture() -> void:
	const GUST_CONTRAST: float = 2.0  # wind_ripple_map.gdshader's contrast
	for i: int in 10:
		await get_tree().process_frame
	var field: MapWindField = map_wind_field()
	var image: Image = _gust_picture.get_texture().get_image()
	var now: WindMoment = field.moment()
	var area: Rect2 = _gust_picture.area_xz
	var pixels: int = image.get_width()
	var worst: float = 0.0
	var lowest: float = INF
	var highest: float = 0.0
	for column: int in range(0, pixels, 8):
		for row: int in range(0, pixels, 8):
			var x: float = area.position.x + (column + 0.5) / pixels * area.size.x
			var z: float = area.position.y + (row + 0.5) / pixels * area.size.y
			var wind_ms: float = field.map_wind.velocity_in(now, Vector3(x, 0.0, z)).length()
			var expected: float = clampf(pow(wind_ms / now.lake_speed_ms, GUST_CONTRAST) / 2.0, 0.0, 1.0)
			var drawn: float = image.get_pixel(column, row).r
			worst = maxf(worst, absf(drawn - expected))
			if _lake_area.is_lake_at(x, z):
				lowest = minf(lowest, 2.0 * drawn)
				highest = maxf(highest, 2.0 * drawn)
	print("Gust picture at %s: largest difference from MapWind %.4f (one 8-bit step is 0.0039); ripples on the lake x%.2f to x%.2f" % [
		field.time_of_day_text(), worst, lowest, highest])
	get_tree().quit()
