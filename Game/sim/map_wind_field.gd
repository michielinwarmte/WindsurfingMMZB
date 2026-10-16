class_name MapWindField
extends WindField
## A map's own wind, for the simulation (PHYSICS_SPEC.md 8.6; MAP_SILVAPLANA_PLAN.md W5;
## PHYSICS_REQUESTS_FROM_MAP.md R5). The simulation asks it the same questions as the one wind
## for the whole world (WindField), and gets the map's answer: MapWind, the terrain's pattern
## carried by the day's mean wind, with the gusts and lulls that roll down the lake, the pulses,
## the shifts and the lee under the shore. The simulation does not know which of the two it has.
##
## Time: MapWind is a function of the place and the time of day. This field keeps the time of
## day in a WindClock and moves it on with the simulation's time (real time by default; the
## clock's rate makes it faster for tests). It starts where the environment says (14:30).
##
## Height: MapWind gives the wind at one height above the water (the pattern's, 5 m). The
## simulation needs it at the sail (about 2 m) and at 10 m for the forecast-style number, so the
## WindConfig's power-law profile is applied from that height: speed(h) = speed(5 m) *
## (h / 5 m) ^ shear_exponent.
##
## Which way the wind comes from: from_direction() and current_from_bearing_rad are the lake's
## MEAN wind of the moment, not the local gust's. The simulation uses them for decisions about
## "where is the wind from, out on this lake": the side the sail is set to at a start and after
## a water start, the heading a fallen board is put at, the true wind angle the controller and
## the HUD read, the line-up of the waves. A sailor judges that from the wind over the whole
## water, and those decisions must not flip back and forth when a gust's local direction swings
## a few degrees. The forces use the local wind (velocity_at(): the sail and the sailor's
## windage), so the board feels every gust, lull and shift where it is.

## Within this distance (m) of the last point asked in the same step, the wind at the
## pattern's height is taken as the same. The sail's mast point, its centre of effort and the
## sailor are within a few metres of each other, and the map's wind changes over tens of
## metres (the pattern's cells are 50 m, the gusts' lanes 100 m across), so this changes the
## wind they feel by far less than 1 %, and asks the map once per step instead of three times
## (MapWind is about 0.1 ms per question in GDScript).
const SAME_SPOT_M: float = 3.0

var map_wind: MapWind
## The time of day (seconds since midnight, local summer time) and how fast it runs.
var clock: WindClock = WindClock.new()
## The height above the water the map's wind is given for (the pattern's height), m.
var pattern_height_m: float = 5.0

## The map's wind of this moment (MapWind.moment()), renewed every step.
var _now: WindMoment = null
## The last answer at the pattern's height, and where it was asked (see SAME_SPOT_M).
var _cached_xz: Vector2 = Vector2.ZERO
var _cached_velocity: Vector3 = Vector3.ZERO
var _cache_valid: bool = false


func _init(wind: MapWind, wind_config: WindConfig, start_time_of_day_s: float, height_m: float = 5.0) -> void:
	map_wind = wind
	pattern_height_m = height_m
	clock.set_time(start_time_of_day_s)
	super(wind_config)


## Moves the time of day on by a simulation time step.
func step(dt: float) -> void:
	time_s += dt
	clock.advance(dt)
	_update()


## Seconds since midnight.
func time_of_day_s() -> float:
	return clock.time_of_day_s


## Jumps to a time of day (seconds since midnight; the clock keeps it within the Maloja's day,
## 10:00 to 21:30).
func set_time_of_day(seconds: float) -> void:
	clock.set_time(seconds)
	_update()


## The time of day as text, like "14:30:05".
func time_of_day_text() -> String:
	return clock.text()


## The lake's mean wind speed at a height above the still water.
func speed_at_height(height_m: float) -> float:
	return _now.lake_speed_ms * _profile_from_pattern(height_m)


## The map's wind at a world point (the direction the air moves), with the height profile.
func velocity_at(point: Vector3) -> Vector3:
	return map_velocity_at(point) * _profile_from_pattern(point.y)


## The map's wind at a point at the pattern's height, horizontal, m/s. Outside the map's
## pattern (and for a point that is not a number) it is the lake's mean wind of the moment.
func map_velocity_at(point: Vector3) -> Vector3:
	var xz: Vector2 = Vector2(point.x, point.z)
	if _cache_valid and xz.distance_to(_cached_xz) <= SAME_SPOT_M:
		return _cached_velocity
	var velocity: Vector3 = _lake_mean_velocity()
	if map_wind.pattern.contains(point.x, point.z):
		var local: Vector3 = map_wind.velocity_in(_now, point)
		if local.is_finite():
			velocity = local
	_cached_xz = xz
	_cached_velocity = velocity
	_cache_valid = true
	return velocity


## The map decides the wind: the settings' wind does not change it.
func set_wind(_from_bearing_rad: float, _speed_ms: float) -> void:
	pass


func _update() -> void:
	# The parent's constructor calls this before map_wind is set; the first real update comes
	# from this class's constructor.
	if map_wind == null:
		return
	_now = map_wind.moment(clock.time_of_day_s)
	current_from_bearing_rad = deg_to_rad(map_wind.lake_from_deg(clock.time_of_day_s))
	current_speed_ms = speed_at_height(config.reference_height_m)
	_cache_valid = false


## The lake's mean wind at the pattern's height: where the air moves, m/s.
func _lake_mean_velocity() -> Vector3:
	return -from_direction() * _now.lake_speed_ms


## How much stronger the wind is at a height than at the pattern's height (the power law of
## WindField.speed_at_height(), measured from the pattern's height instead of 10 m).
func _profile_from_pattern(height_m: float) -> float:
	if not config.height_gradient_enabled:
		return 1.0
	var height: float = maxf(height_m, config.min_height_m)
	return pow(height / pattern_height_m, config.shear_exponent)
