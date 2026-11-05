class_name EnvironmentConfig
extends Resource
## Where the board sails: the air, the water, the wind and the waves of a place
## (PHYSICS_REQUESTS_FROM_MAP.md, R1). WindsurferSim.create_for() builds the simulation with
## it. Every field left empty (null) takes the open water's default config file, so an empty
## EnvironmentConfig sails exactly like WindsurferSim.create_default().
##
## A map brings its own (for Lake Silvaplana: res://maps/silvaplana/environment_silvaplana.tres):
## thinner air at altitude, fresh water, and the map's own wind (MapWind) instead of the
## WindConfig's one wind for the whole world.

const DEFAULT_WATER_PATH: String = "res://config/water_default.tres"
const DEFAULT_WIND_PATH: String = "res://config/wind_default.tres"
const DEFAULT_WAVES_PATH: String = "res://config/waves_default.tres"

## Density of the air. 1.225 is the standard atmosphere at sea level and 15 degrees. The sail's
## force and the sailor's windage scale with it (q = 0.5 rho v^2).
@export var air_density_kg_m3: float = 1.225
## The water: density and viscosity (null = the sea, water_default.tres).
@export var water: WaterConfig = null
## The wind (null = wind_default.tres). With the map's wind on, only its height profile (the
## shear exponent, the reference height and the lowest height) and its direction (which the
## waves are lined up with) are used.
@export var wind: WindConfig = null
## The sea state (null = waves_default.tres; the game puts the player's choice on top).
@export var waves: WaveSetConfig = null

@export_group("Map wind")
## Use the map's own wind (MapWind: the terrain's pattern, the day's cycle, the moving gusts and
## the lee under the shore) instead of the WindConfig's one wind for the whole world (W5).
@export var map_wind_enabled: bool = false
## The map's files, as the wind viewer loads them (MapWind.load_from()).
@export_file("*.tres") var map_config_path: String = ""
@export_file("*.json") var map_wind_pattern_path: String = ""
@export_file("*.tres") var map_wind_day_path: String = ""
@export_file("*.tres") var map_wind_gusts_path: String = ""
@export_file("*.json") var map_wind_lee_path: String = ""
## The height above the water the map's wind is computed for (the pattern's
## height_above_ground_m). The height profile is applied from there.
@export var map_wind_height_m: float = 5.0
## The time of day the simulation starts at, in hours of local time (14.5 = 14:30, the
## strongest Maloja of the average day).
@export var start_hour: float = 14.5

@export_group("Lake waves")
## The lake's own waves, grown by its wind over its fetch (LakeWavesConfig, PHYSICS_SPEC.md 9.17),
## on the depth grid below. Used only when the wave set asks for the place's own waves
## (WaveSetConfig.place_waves); otherwise, and when this is null, the wave set's waves.
@export var lake_waves: LakeWavesConfig = null
## The map's depth grid (TerrainGrid's .json): where the water is and how deep.
@export_file("*.json") var depth_grid_path: String = ""

## The map's wind, loaded once and shared: it is a fixed function of the place and the time of
## day, so every simulation in this environment can ask the same one.
var _map_wind: MapWind = null
## The depth grid, loaded once and shared (null until asked).
var _depth_grid: TerrainGrid = null
## The lake waves built so far, by the wind they were built for (a few at most; see
## lake_waves_for()). Built on the main thread when a simulation's water is made.
var _lake_waves_built: Dictionary[String, LakeWaves] = {}
const LAKE_WAVES_KEPT: int = 4


func water_or_default() -> WaterConfig:
	return water if water != null else load(DEFAULT_WATER_PATH) as WaterConfig


func wind_or_default() -> WindConfig:
	return wind if wind != null else load(DEFAULT_WIND_PATH) as WindConfig


func waves_or_default() -> WaveSetConfig:
	return waves if waves != null else load(DEFAULT_WAVES_PATH) as WaveSetConfig


## The map's wind (null when it is off, or when its files can't be loaded).
func map_wind() -> MapWind:
	if not map_wind_enabled:
		return null
	if _map_wind == null:
		var map_config: MapConfig = load(map_config_path) as MapConfig
		if map_config == null:
			push_error("EnvironmentConfig: can't load the map config %s" % map_config_path)
			return null
		_map_wind = MapWind.load_from(map_wind_pattern_path, map_wind_day_path, map_config,
			map_wind_gusts_path, map_wind_lee_path)
	return _map_wind


## The start time as seconds since midnight.
func start_time_of_day_s() -> float:
	return start_hour * 3600.0


## The map's depth grid (null without one, or when it can't be loaded).
func depth_grid() -> TerrainGrid:
	if _depth_grid == null and depth_grid_path != "":
		_depth_grid = TerrainGrid.load_from(depth_grid_path)
	return _depth_grid


## The lake's waves for a simulation's wind (null when this place has none): built for the lake's
## mean wind of that moment (9.17). With the map's wind: its direction and speed at the field's
## time of day, the local wind from its pattern and the lee's average; with one wind for the whole
## world (the map's wind off): that wind, the same everywhere. Every simulation asking at the same
## wind gets the same LakeWaves, so the boards of a race sail on one sea.
func lake_waves_for(wind: WindField, wind_config: WindConfig) -> LakeWaves:
	if lake_waves == null or depth_grid() == null or wind_config == null:
		return null
	var from_deg: float = wind_config.from_bearing_deg
	var wind_10m_ms: float = wind_config.speed_kt * SimMath.KNOT_MS
	var speed_factor_at: Callable = func(_x: float, _z: float) -> float: return 1.0
	var map_field: MapWindField = wind as MapWindField
	if map_field != null:
		var time_s: float = map_field.time_of_day_s()
		var map_wind: MapWind = map_field.map_wind
		from_deg = map_wind.lake_from_deg(time_s)
		var pattern_ms: float = map_wind.day.lake_speed_ms(time_s)
		wind_10m_ms = pattern_ms * map_field.speed_at_height(10.0) / maxf(map_field.speed_at_height(map_field.pattern_height_m), 1e-6)
		speed_factor_at = map_speed_factor.bind(map_wind, from_deg, pattern_ms / SimMath.KNOT_MS)
	var key: String = "%.2f/%.3f" % [from_deg, wind_10m_ms]
	if _lake_waves_built.has(key):
		return _lake_waves_built[key]
	var grid: TerrainGrid = depth_grid()
	var area: Rect2 = Rect2(grid.x0_m, grid.z0_m, (grid.columns - 1) * grid.cell_m, (grid.rows - 1) * grid.cell_m)
	var depth_at: Callable = func(x: float, z: float) -> float: return ShoreCheck.depth_at(grid, Vector3(x, 0.0, z))
	var built: LakeWaves = LakeWaves.build(lake_waves, depth_at, area, from_deg, wind_10m_ms, speed_factor_at)
	if _lake_waves_built.size() >= LAKE_WAVES_KEPT:
		_lake_waves_built.erase(_lake_waves_built.keys()[0])
	_lake_waves_built[key] = built
	return built


## The map's mean wind at a game position relative to the lake's mean (9.17, step 2): the pattern's
## speed there times the lee's average (MapWind.velocity_in() without the gusts: the lee lets 1 in
## 10 gusts in, so over time it takes the band's lee times its shape off, W3), divided by what the
## pattern already holds of the lee (WindLee).
func map_speed_factor(x: float, z: float, map_wind: MapWind, from_deg: float, lake_kt: float) -> float:
	var factor: float = map_wind.pattern.speed_factor_at(x, z)
	if map_wind.lee == null:
		return factor
	var shape_held: Vector2 = map_wind.lee.at(x, z)
	if shape_held == Vector2.ZERO:
		return factor
	var lee_left: float = maxf(1.0 - shape_held.x * map_wind.lee.band_lee(from_deg, lake_kt), 0.05)
	return factor * lee_left / (1.0 - shape_held.y)
