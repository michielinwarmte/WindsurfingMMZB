class_name WindField
extends RefCounted
## The true wind: "what is the air doing at this point, right now?" (PHYSICS_SPEC.md section 8).
## Constant by default; with the toggles in WindConfig it adds the increase with height, the
## gusts and slow direction shifts. It produces no force itself.
##
## The gusts come in two kinds (WindConfig.gust_patches, section 8.3). As patches, the game's
## open water (ROADMAP PH7): the gusts and lulls are a pattern of stronger and lighter air, fronts
## across the wind and lanes along it, rolling downwind with the air, so a gust can be seen coming
## on the water (the gust picture, OpenGustMap) and sailed into or eased for. The pattern is the
## lake's (WindGusts: the Maloja's shapes measured from satellite photos, MAP_SILVAPLANA_PLAN.md
## W3), laid along the wind's direction with this field's time as its clock and the settings'
## gust strength as its spread (Game/config/open_gusts_default.tres). As sines, the older tests
## and measurements: three sine waves in time, the same everywhere at once.
##
## Heights are measured from world y = 0, the still-water level.
##
## Boards on threads (F1 no_wait): reading a field of another object, as config.shear_exponent,
## takes a global engine lock, and boards stepped side by side on worker threads wait for each
## other there; calling a method of it does not. So the field keeps copies of the config's
## numbers in its own fields, taken by copy_config(): when it is made, when set_wind() changes
## the config, and at the start of every tick (WindsurferSim.step). The config is never changed
## inside a tick, so the copies are the config's numbers wherever they are used. The patches'
## pattern is asked through its methods only.

## Within this distance (m) of the last point asked in the same step, the patch is taken as the
## same: the sail, the mast and the sailor are within a few metres of each other, and the lanes
## are 100 m across (as MapWindField.SAME_SPOT_M).
const PATCH_SPOT_M: float = 3.0
## The patches' spread (their standard deviation) as a share of the mean wind, per unit of the
## gust strength: the strongest usual gusts, two spreads above the mean, are gust_intensity
## stronger than it, so the settings' "up to ± 20 % of the wind" keeps its meaning. At 0.2 the
## spread is 10 % of the wind, close to the lake's measured 11 % at 18 kt (WindGusts.spread_ms()).
const PATCH_SPREAD_PER_INTENSITY: float = 0.5
## The pattern used when the config names none.
const DEFAULT_PATTERN_PATH: String = "res://config/open_gusts_default.tres"
## Below this share of the mean a lull does not go (as MapWind.velocity_in()).
const LULL_FLOOR: float = 0.05

var config: WindConfig
## What else disturbs the air at a point, on top of this field's wind (WindDisturbance: the other
## sails' wind shadows in a race, AI_FLEET_PLAN.md D5); null disturbs nothing. Given by whoever
## runs the race, never by the physics; a board stepped on a thread must have its own.
var disturbance: WindDisturbance = null
## Simulation time since the field was created. Advanced by step(), never read from a clock.
var time_s: float = 0.0
## Wind speed at the reference height right now: the base speed times the sines' gust factor;
## with the patches the mean wind, which the HUD and the decisions "where is the wind from, out
## here" use (the patches are local: velocity_at()).
var current_speed_ms: float = 0.0
## Compass bearing the wind comes FROM right now (base bearing plus the shift), radians.
var current_from_bearing_rad: float = 0.0
## How far the air has travelled downwind since the field was made, m: the patches roll with it
## (WindGusts.drift_ms(): 1.1 times the mean wind).
var travel_m: float = 0.0

## The config's numbers (copy_config()).
var _height_gradient_enabled: bool = false
var _min_height_m: float = 0.0
var _reference_height_m: float = 10.0
var _shear_exponent: float = 0.0
var _gusts_enabled: bool = false
var _gust_period_s: float = 1.0
var _gust_intensity: float = 0.0
var _gust_patches: bool = false
var _shifts_enabled: bool = false
var _shift_period_s: float = 1.0
var _max_shift_deg: float = 0.0
var _from_bearing_deg: float = 0.0

## The patches' pattern and its sideways share, and the axis the patches lie along: the direction
## the air moves in (from the base bearing, without the shifts; game X and Z) and the one
## 90 degrees clockwise from it, seen from above.
var _pattern: WindGusts = null
var _patch_sideways_share: float = 0.8
var _downwind_axis: Vector2 = Vector2.ZERO
var _across_axis: Vector2 = Vector2.ZERO
## The last patch asked this step, and where it was asked (PATCH_SPOT_M).
var _patch_cached_xz: Vector2 = Vector2.ZERO
var _patch_cached_unit: Vector2 = Vector2.ZERO
var _patch_cache_valid: bool = false


func _init(wind_config: WindConfig) -> void:
	config = wind_config
	copy_config()
	_update()


## Copies the config's numbers into this field's own (see the note at the top).
func copy_config() -> void:
	_height_gradient_enabled = config.height_gradient_enabled
	_min_height_m = config.min_height_m
	_reference_height_m = config.reference_height_m
	_shear_exponent = config.shear_exponent
	_gusts_enabled = config.gusts_enabled
	_gust_period_s = config.gust_period_s
	_gust_intensity = config.gust_intensity
	_gust_patches = config.gust_patches
	_shifts_enabled = config.shifts_enabled
	_shift_period_s = config.shift_period_s
	_max_shift_deg = config.max_shift_deg
	_from_bearing_deg = config.from_bearing_deg
	if _gusts_enabled and _gust_patches:
		if config.gust_pattern != null:
			_pattern = config.gust_pattern
		elif _pattern == null:
			_pattern = load(DEFAULT_PATTERN_PATH) as WindGusts
		_patch_sideways_share = _pattern.sideways_share
	var from: Vector3 = SimMath.dir_from_bearing(deg_to_rad(_from_bearing_deg))
	_downwind_axis = Vector2(-from.x, -from.z)
	_across_axis = Vector2(-_downwind_axis.y, _downwind_axis.x)
	_patch_cache_valid = false


func step(dt: float) -> void:
	time_s += dt
	if uses_patches():
		travel_m += _pattern.drift_ms(config.speed_ms()) * dt
	_update()


## Unit vector pointing to where the wind comes from, horizontal.
func from_direction() -> Vector3:
	return SimMath.dir_from_bearing(current_from_bearing_rad)


## Wind speed at a height above the still water.
func speed_at_height(height_m: float) -> float:
	if not _height_gradient_enabled:
		return current_speed_ms
	# Power-law profile: friction with the water slows the air near the surface.
	var height: float = maxf(height_m, _min_height_m)
	return current_speed_ms * pow(height / _reference_height_m, _shear_exponent)


## True wind velocity (the direction the air moves) at a world point, less what disturbs it there.
func velocity_at(point: Vector3) -> Vector3:
	var velocity: Vector3 = -from_direction() * speed_at_height(point.y)
	if uses_patches():
		velocity = _in_the_patches(point, velocity)
	if disturbance != null:
		return velocity * disturbance.factor_at(point, velocity)
	return velocity


## Whether the gusts are patches rolling over the water (gusts on, as patches).
func uses_patches() -> bool:
	return _gusts_enabled and _gust_patches


## The patch over a point, with a spread of 1: x along the wind (above 0 a gust, below a lull),
## y sideways (WindGusts.gusts_at(), with the air's travel taken off so the patches roll). Zero
## without patches. The same within PATCH_SPOT_M of the last point asked this step.
func patch_unit_at(point: Vector3) -> Vector2:
	if not uses_patches():
		return Vector2.ZERO
	var xz: Vector2 = Vector2(point.x, point.z)
	if _patch_cache_valid and xz.distance_to(_patch_cached_xz) <= PATCH_SPOT_M:
		return _patch_cached_unit
	var unit: Vector2 = _pattern.gusts_at(xz.dot(_downwind_axis) - travel_m, xz.dot(_across_axis), time_s)
	_patch_cached_xz = xz
	_patch_cached_unit = unit
	_patch_cache_valid = true
	return unit


## The patches' spread as a share of the mean wind (0 without patches).
func patch_spread_share() -> float:
	return _gust_intensity * PATCH_SPREAD_PER_INTENSITY if uses_patches() else 0.0


## The patches' pattern (null without patches), and the direction the air moves in (game X, Z)
## that the patches lie along: for the picture of them (OpenGustMap).
func pattern() -> WindGusts:
	return _pattern if uses_patches() else null


func downwind_axis() -> Vector2:
	return _downwind_axis


## Changes the base wind while the game runs. The gust phase keeps running, and the patches keep
## rolling from where they are.
func set_wind(from_bearing_rad: float, speed_ms: float) -> void:
	config.from_bearing_deg = rad_to_deg(fposmod(from_bearing_rad, TAU))
	config.speed_kt = clampf(speed_ms, 0.0, 50.0 * SimMath.KNOT_MS) / SimMath.KNOT_MS
	copy_config()
	_update()


func _update() -> void:
	var gust_factor: float = 1.0
	if _gusts_enabled and not _gust_patches:
		# Three sine waves whose periods are not simple multiples of each other, so the
		# result looks irregular while staying repeatable (section 8.3).
		var phase: float = fposmod(TAU * time_s / _gust_period_s, TAU)
		var gust: float = 0.6 * sin(phase) + 0.3 * sin(2.3 * phase) + 0.1 * sin(5.7 * phase)
		gust_factor = 1.0 + gust * _gust_intensity
	var shift_rad: float = 0.0
	if _shifts_enabled:
		var shift_phase: float = TAU * time_s / _shift_period_s
		shift_rad = deg_to_rad(_max_shift_deg) * (sin(shift_phase) + 0.3 * sin(0.37 * shift_phase))
	current_speed_ms = config.speed_ms() * gust_factor
	current_from_bearing_rad = deg_to_rad(_from_bearing_deg) + shift_rad
	_patch_cache_valid = false


## The wind in the patches at a point: the mean wind there, stronger or lighter along the wind
## and pushed sideways, by the patch rolling over this spot (MapWind.velocity_in(), step 3, with
## the spread as a share of the mean instead of metres per second, so the same share holds at
## every height). A lull never takes more than 95 % of the wind away.
func _in_the_patches(point: Vector3, mean: Vector3) -> Vector3:
	var speed: float = mean.length()
	if speed < 0.001:
		return mean
	var unit: Vector2 = patch_unit_at(point)
	var sigma: float = _gust_intensity * PATCH_SPREAD_PER_INTENSITY
	var direction: Vector3 = mean / speed
	var side: Vector3 = Vector3(-direction.z, 0.0, direction.x)
	var along: float = maxf(1.0 + unit.x * sigma, LULL_FLOOR)
	return direction * speed * along + side * speed * unit.y * sigma * _patch_sideways_share
