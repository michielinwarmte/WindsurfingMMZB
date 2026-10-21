class_name WindField
extends RefCounted
## The true wind: "what is the air doing at this point, right now?" (PHYSICS_SPEC.md section 8).
## Constant by default; with the toggles in WindConfig it adds the increase with height,
## deterministic gusts and slow direction shifts. It produces no force itself.
##
## Heights are measured from world y = 0, the still-water level.
##
## Boards on threads (F1 no_wait): reading a field of another object, as config.shear_exponent,
## takes a global engine lock, and boards stepped side by side on worker threads wait for each
## other there; calling a method of it does not. So the field keeps copies of the config's
## numbers in its own fields, taken by copy_config(): when it is made, when set_wind() changes
## the config, and at the start of every tick (WindsurferSim.step). The config is never changed
## inside a tick, so the copies are the config's numbers wherever they are used.

var config: WindConfig
## What else disturbs the air at a point, on top of this field's wind (WindDisturbance: the other
## sails' wind shadows in a race, AI_FLEET_PLAN.md D5); null disturbs nothing. Given by whoever
## runs the race, never by the physics; a board stepped on a thread must have its own.
var disturbance: WindDisturbance = null
## Simulation time since the field was created. Advanced by step(), never read from a clock.
var time_s: float = 0.0
## Wind speed at the reference height right now (base speed times the gust factor).
var current_speed_ms: float = 0.0
## Compass bearing the wind comes FROM right now (base bearing plus the shift), radians.
var current_from_bearing_rad: float = 0.0

## The config's numbers (copy_config()).
var _height_gradient_enabled: bool = false
var _min_height_m: float = 0.0
var _reference_height_m: float = 10.0
var _shear_exponent: float = 0.0
var _gusts_enabled: bool = false
var _gust_period_s: float = 1.0
var _gust_intensity: float = 0.0
var _shifts_enabled: bool = false
var _shift_period_s: float = 1.0
var _max_shift_deg: float = 0.0
var _from_bearing_deg: float = 0.0


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
	_shifts_enabled = config.shifts_enabled
	_shift_period_s = config.shift_period_s
	_max_shift_deg = config.max_shift_deg
	_from_bearing_deg = config.from_bearing_deg


func step(dt: float) -> void:
	time_s += dt
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
	if disturbance != null:
		return velocity * disturbance.factor_at(point, velocity)
	return velocity


## Changes the base wind while the game runs. The gust phase keeps running.
func set_wind(from_bearing_rad: float, speed_ms: float) -> void:
	config.from_bearing_deg = rad_to_deg(fposmod(from_bearing_rad, TAU))
	config.speed_kt = clampf(speed_ms, 0.0, 50.0 * SimMath.KNOT_MS) / SimMath.KNOT_MS
	copy_config()
	_update()


func _update() -> void:
	var gust_factor: float = 1.0
	if _gusts_enabled:
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
