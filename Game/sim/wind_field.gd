class_name WindField
extends RefCounted
## The true wind: "what is the air doing at this point, right now?" (PHYSICS_SPEC.md section 8).
## Constant by default; with the toggles in WindConfig it adds the increase with height,
## deterministic gusts and slow direction shifts. It produces no force itself.
##
## Heights are measured from world y = 0, the still-water level.

var config: WindConfig
## Simulation time since the field was created. Advanced by step(), never read from a clock.
var time_s: float = 0.0
## Wind speed at the reference height right now (base speed times the gust factor).
var current_speed_ms: float = 0.0
## Compass bearing the wind comes FROM right now (base bearing plus the shift), radians.
var current_from_bearing_rad: float = 0.0


func _init(wind_config: WindConfig) -> void:
	config = wind_config
	_update()


func step(dt: float) -> void:
	time_s += dt
	_update()


## Unit vector pointing to where the wind comes from, horizontal.
func from_direction() -> Vector3:
	return SimMath.dir_from_bearing(current_from_bearing_rad)


## Wind speed at a height above the still water.
func speed_at_height(height_m: float) -> float:
	if not config.height_gradient_enabled:
		return current_speed_ms
	# Power-law profile: friction with the water slows the air near the surface.
	var height: float = maxf(height_m, config.min_height_m)
	return current_speed_ms * pow(height / config.reference_height_m, config.shear_exponent)


## True wind velocity (the direction the air moves) at a world point.
func velocity_at(point: Vector3) -> Vector3:
	return -from_direction() * speed_at_height(point.y)


## Changes the base wind while the game runs. The gust phase keeps running.
func set_wind(from_bearing_rad: float, speed_ms: float) -> void:
	config.from_bearing_deg = rad_to_deg(fposmod(from_bearing_rad, TAU))
	config.speed_kt = clampf(speed_ms, 0.0, 50.0 * SimMath.KNOT_MS) / SimMath.KNOT_MS
	_update()


func _update() -> void:
	var gust_factor: float = 1.0
	if config.gusts_enabled:
		# Three sine waves whose periods are not simple multiples of each other, so the
		# result looks irregular while staying repeatable (section 8.3).
		var phase: float = fposmod(TAU * time_s / config.gust_period_s, TAU)
		var gust: float = 0.6 * sin(phase) + 0.3 * sin(2.3 * phase) + 0.1 * sin(5.7 * phase)
		gust_factor = 1.0 + gust * config.gust_intensity
	var shift_rad: float = 0.0
	if config.shifts_enabled:
		var shift_phase: float = TAU * time_s / config.shift_period_s
		shift_rad = deg_to_rad(config.max_shift_deg) * (sin(shift_phase) + 0.3 * sin(0.37 * shift_phase))
	current_speed_ms = config.speed_ms() * gust_factor
	current_from_bearing_rad = deg_to_rad(config.from_bearing_deg) + shift_rad
