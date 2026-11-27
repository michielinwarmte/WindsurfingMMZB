class_name SpotSailing
extends SailingScene
## Sailing on a spot built from a height grid (Spot; tools/map/spot_build.py): the open-water
## sailing scene (main.gd: the windsurfer, the cameras, the HUD, the pause menu, the settings, the
## restart, races) on the spot's map. What is different from the open water:
## - the map scene brings the terrain (HeightTerrain), the sky, the sun and the haze,
## - the place is the spot's own (its EnvironmentConfig): the air, the sea water, the depth grid at
##   the session's water level (the tide), and the sea's waves grown by the wind over the spot's
##   fetch (the place's own waves, PHYSICS_SPEC.md 9.17), always on here,
## - the wind is the settings' (its strength, gusts and shifts) from the spot's usual direction,
## - the board starts at the spot's start and runs aground in the shallows (main.gd's shore check,
##   with the depth grid),
## - the HUD has a small map of the water.
##
## Options besides main.gd's (the spot's frame, metres):
##   --start=<east>,<north>   start at this spot instead of the spot's start
##   --heading=<degrees>      start with this heading
##   --wind_from=<degrees>    the wind from this direction instead of the spot's usual one
##   --water_level=<m>        the water this high above mean sea level (the tide) instead of the spot's
##   --course=<name>          race a course from the spot's courses folder (Sotavento: pwa_slalom_x)
##   --overview=<east>,<north>,<height>  a fixed camera there (height above mean sea level), looking
##       at the board, or with --overview_look=<east>,<north> at that point on the water;
##       --overview_fov=<degrees> gives it another lens (the vertical field of view)
## tools/screenshot.sh res://maps/sotavento/sail_sotavento.tscn out.png 480 --autopilot=1 --camera=2

## The water for the small map: found every this many metres.
const WATER_STEP_M: float = 24.0

@export var spot: Spot = null

@onready var _map_sun: DirectionalLight3D = get_node_or_null("Map/Sun") as DirectionalLight3D

var _water_area: LakeArea
## The --overview camera position (Vector3.INF: none), and the point it looks at (--overview_look;
## Vector3.INF: the board).
var _overview_at: Vector3 = Vector3.INF
var _overview_look: Vector3 = Vector3.INF


func _enter_tree() -> void:
	var windsurfer: WindsurferNode = $Windsurfer
	# This session's own copy of the spot's environment at the session's water level, so every
	# board (the race's too: they share the player's environment) floats on the same sea.
	var environment: EnvironmentConfig = (load(spot.environment_path) as EnvironmentConfig).duplicate()
	environment.water_level_m = water_level_m()
	environment.start_hour = spot.start_hour
	windsurfer.environment = environment
	# Every part of the map that stands on the ground (the terrain, the buildings, the event site)
	# at the same water level.
	for part: Node in find_children("*", "", true, false):
		if "water_level_m" in part and part != self:
			part.set("water_level_m", environment.water_level_m)
	# Before main.gd's part, which moves the start behind a race course's start line (--course).
	windsurfer.start_position = start_position()
	super()
	# The spot's own sea (its waves grown over its fetch), whatever the settings' Lake waves say.
	if windsurfer.wave_set_config != null:
		windsurfer.wave_set_config.place_waves = true


func _ready() -> void:
	shore_grid = _windsurfer.environment.depth_grid()
	if shore_grid != null:
		_water_area = LakeArea.from_grid(shore_grid, start_position(), WATER_STEP_M)
		_hud.show_mini_map(_water_area, _windsurfer.start_position)
	super()
	# A race on the PWA course draws its own marks: the event site's buoys step aside.
	var event_site: Node = get_node_or_null("Map/EventSite")
	if event_site != null and event_site.has_method("show_course_buoys"):
		event_site.call("show_course_buoys", _course == null)
	_apply_overview_options()
	print("%s: water level %.2f m above mean sea level, wind from %.0f degrees" % [
		spot.display_name, _windsurfer.environment.water_level_m, _windsurfer.wind_config.from_bearing_deg])
	_say_which_waves()


## Which waves the spot has, in the console and the logs of the checks.
func _say_which_waves() -> void:
	var sea: LakeWaveField = _windsurfer.sim.water as LakeWaveField
	if sea == null:
		print("%s: no waves of its own (the settings' waves)" % spot.display_name)
		return
	var waves: LakeWaves = sea.lake
	print("%s's sea (PHYSICS_SPEC.md 9.17): built for %.1f kt at 10 m from %.0f degrees on %d x %d cells of %.0f m; the physics floats on %d of %d trains; crests up to %.0f cm" % [
		spot.display_name, waves.wind_10m_ms / SimMath.KNOT_MS, waves.from_deg, waves.map.columns, waves.map.rows,
		waves.map.cell_m, waves.physics_count, waves.band_count, 100.0 * waves.max_total_amplitude_m])


func _process(delta: float) -> void:
	super(delta)
	if _overview_at != Vector3.INF:
		_camera_rig.camera.global_position = _overview_at
		var target: Vector3 = _overview_look if _overview_look != Vector3.INF else _windsurfer.get_global_transform_interpolated().origin
		_camera_rig.camera.look_at(target)


## --overview and --overview_look (see the top of this file). The heights are above mean sea level;
## the game's height 0 is the session's water.
func _apply_overview_options() -> void:
	var overview: PackedFloat64Array = _option_numbers("overview")
	if overview.size() != 3:
		return
	var level: float = _windsurfer.environment.water_level_m
	_overview_at = spot.map_config.lv95_to_game(overview[0], overview[1], overview[2] - level)
	_camera_rig.set_process(false)
	var look: PackedFloat64Array = _option_numbers("overview_look")
	if look.size() == 2:
		_overview_look = spot.map_config.lv95_to_game(look[0], look[1], 0.0)
	# --overview_fov=<degrees>: the fixed camera's lens (its vertical field of view), for pictures
	# to set beside a real camera's (the stream's drones: about 47 degrees).
	var fov: PackedFloat64Array = _option_numbers("overview_fov")
	if fov.size() == 1:
		_camera_rig.camera.fov = clampf(fov[0], 1.0, 120.0)


## The start spot in game coordinates, on the water.
func start_position() -> Vector3:
	var numbers: PackedFloat64Array = _option_numbers("start")
	if numbers.size() == 2:
		var at: Vector3 = spot.map_config.lv95_to_game(numbers[0], numbers[1], 0.0)
		return Vector3(at.x, 0.0, at.z)
	return spot.start_position()


## The session's water level above mean sea level: --water_level, or the spot's.
func water_level_m() -> float:
	var numbers: PackedFloat64Array = _option_numbers("water_level")
	return numbers[0] if numbers.size() == 1 else spot.water_level_m


## The settings' wind (or a race's), from the spot's usual direction (or --wind_from).
func _build_wind_config() -> WindConfig:
	var config: WindConfig = super()
	var numbers: PackedFloat64Array = _option_numbers("wind_from")
	config.from_bearing_deg = numbers[0] if numbers.size() == 1 else spot.wind_from_deg
	return config


func _start_heading_deg() -> float:
	var numbers: PackedFloat64Array = _option_numbers("heading")
	if numbers.size() == 1:
		return numbers[0]
	# With a race course: a beam reach behind its start line (main.gd).
	return super() if _course != null else spot.start_heading_deg


## The spot's race courses by name (main.gd's --course): the files in the spot's courses folder.
func _course_named(course_name: String, usual_start: Vector2) -> Course:
	if spot.courses_folder != "":
		var saved: Course = RaceCourses.load_named(course_name, spot.map_config, spot.courses_folder)
		if saved != null:
			return saved
	return super(course_name, usual_start)


## The spot keeps its own wind direction when the settings change (the settings' direction is the
## open water's).
func _apply_wind_settings_live() -> void:
	pass


## The Shadows setting on the map's sun (main.gd sets it on the open water's sun).
func _apply_start_settings() -> void:
	super()
	if _map_sun != null:
		_map_sun.shadow_enabled = GameSettings.values.shadow_quality > 0


func apply_settings_live() -> void:
	super()
	if _map_sun != null:
		_map_sun.shadow_enabled = GameSettings.values.shadow_quality > 0


## The spot's map configuration, for the race director's course maker.
func map_config() -> MapConfig:
	return spot.map_config


## The numbers of a command-line option --name=a,b,c (empty when it is not given).
func _option_numbers(option: String) -> PackedFloat64Array:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % option):
			return arg.get_slice("=", 1).split_floats(",")
	return PackedFloat64Array()
