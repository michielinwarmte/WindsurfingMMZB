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

## The map's wind, loaded once and shared: it is a fixed function of the place and the time of
## day, so every simulation in this environment can ask the same one.
var _map_wind: MapWind = null


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
