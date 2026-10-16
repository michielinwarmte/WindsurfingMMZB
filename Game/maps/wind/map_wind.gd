class_name MapWind
extends RefCounted
## A map's wind: "what is the air doing at this point, at this time of day?" (MAP_SILVAPLANA_PLAN.md,
## the wind analyser). WD2: the fixed pattern of the terrain (WindPattern), carried by the day's
## mean wind (WindDay), with the moving weather on top (WindGusts: gusts and lulls, pulses and shifts)
## and the lee along a shore that only the strongest gusts get into (WindLee).
##
## WD1, one wind for two users: the wind viewer asks this class, and the sailing will too (W5, with
## Michiel, through WindField). The viewer's shaders compute the same sums on the graphics card
## (wind_pattern.gdshaderinc), from shader_constants() and WindMoment.shader_parameters();
## test_map_wind.gd and the viewer's --check-colours check they agree.
##
## Conventions as in the physics (CLAUDE.md, D4): north is -Z, east is +X, a direction is where the
## wind comes FROM, a velocity is where the air moves TO, in m/s.

var pattern: WindPattern
var day: WindDay
## The moving weather; null for none (only the pattern and the day's mean).
var gusts: WindGusts
## The lee along a shore that the strongest gusts get into; null for none (only with gusts).
var lee: WindLee
## The lake's downwind direction (game X, Z): the pattern's average direction, fixed. "Along the
## lake" is measured along it from the game's origin, the lake's middle; "across" 90 degrees clockwise.
var lake_axis: Vector2

## How far the air has travelled down the lake since midnight, every TRAVEL_STEP_S of the day (with
## gusts only). The gusts roll with it, so they move at the wind's speed of the moment.
const TRAVEL_STEP_S: float = 10.0
var _travel_m: PackedFloat64Array = PackedFloat64Array()


func _init(wind_pattern: WindPattern, wind_day: WindDay, wind_gusts: WindGusts = null, wind_lee: WindLee = null) -> void:
	pattern = wind_pattern
	day = wind_day
	gusts = wind_gusts
	lee = wind_lee
	var to_rad: float = deg_to_rad(pattern.lake_from_deg + 180.0)
	lake_axis = Vector2(sin(to_rad), -cos(to_rad))
	if gusts != null:
		_add_up_travel()


## Loads a map's wind from its files: the pattern's .json, the day's .tres and, if given, the gusts'
## .tres and the lee's .json.
static func load_from(pattern_json_path: String, day_path: String, config: MapConfig, gusts_path: String = "",
		lee_json_path: String = "") -> MapWind:
	var wind_pattern: WindPattern = WindPattern.load_from(pattern_json_path, config)
	var wind_day: WindDay = load(day_path) as WindDay
	var wind_gusts: WindGusts = load(gusts_path) as WindGusts if gusts_path != "" else null
	var wind_lee: WindLee = WindLee.load_from(lee_json_path, config) if lee_json_path != "" else null
	var failed: bool = wind_pattern == null or wind_day == null
	failed = failed or (gusts_path != "" and wind_gusts == null) or (lee_json_path != "" and wind_lee == null)
	if failed:
		push_error("MapWind: can't load %s, %s, %s or %s" % [pattern_json_path, day_path, gusts_path, lee_json_path])
		return null
	return MapWind.new(wind_pattern, wind_day, wind_gusts, wind_lee)


## The wind at a time of day (seconds since midnight): the day's mean and what the gusts need then.
## Ask it with velocity_in() for many places at the same moment.
func moment(time_of_day_s: float) -> WindMoment:
	var now: WindMoment = WindMoment.new()
	now.time_of_day_s = time_of_day_s
	var lake: Vector2 = _lake_wind(time_of_day_s)
	now.lake_speed_ms = lake.x
	now.lake_to_rad = lake.y
	if gusts != null:
		now.drift_ms = gusts.drift_ms(lake.x)
		now.travel_m = travel_m(time_of_day_s)
		now.spread_ms = gusts.spread_ms(lake.x)
	return now


## How far the air has travelled down the lake since midnight at a time of day, metres: the sum of
## the gusts' drift speed over the day so far. The gusts are fixed to the air, so a gust that was at
## a place along the lake is now this much further down.
func travel_m(time_of_day_s: float) -> float:
	var f: float = clampf(time_of_day_s / TRAVEL_STEP_S, 0.0, _travel_m.size() - 1.0)
	var i: int = mini(floori(f), _travel_m.size() - 2)
	return lerpf(_travel_m[i], _travel_m[i + 1], f - i)


## The air's velocity at a game position (only X and Z count) and a time of day: where it moves to,
## in m/s. Horizontal.
func velocity_at(point: Vector3, time_of_day_s: float) -> Vector3:
	return velocity_in(moment(time_of_day_s), point)


## The air's velocity at a game position at a moment (from moment()). Step by step:
## 1. the pulse and the shift, which travel down the lake: what started upwind arrives here later;
## 2. the pattern, carried by the lake's mean wind, pulsed and shifted;
## 3. the gusts and lulls (WindGusts.gusts_at()), rolling down the lake with the air: more or less
##    speed along the wind, and a push sideways that turns it, times how gusty this place is;
## 4. the lee along the shore (WindLee), except where a strong gust gets into it.
func velocity_in(now: WindMoment, point: Vector3) -> Vector3:
	var xz: Vector2 = Vector2(point.x, point.z)
	var along_m: float = xz.dot(lake_axis)
	var speed_ms: float = now.lake_speed_ms
	var to_rad: float = now.lake_to_rad
	if gusts != null:
		var tau_s: float = now.time_of_day_s - along_m / now.drift_ms
		speed_ms *= 1.0 + gusts.pulse(tau_s)
		to_rad += gusts.shift_rad(tau_s)

	var arrow: Vector2 = pattern.arrow_at(point.x, point.z)
	var downwind: Vector2 = Vector2(sin(to_rad), -cos(to_rad))
	var clockwise: Vector2 = Vector2(-downwind.y, downwind.x)
	var flow: Vector2 = (downwind * arrow.x + clockwise * arrow.y) * speed_ms
	var base_ms: float = flow.length()
	if gusts == null or base_ms < 0.001:
		return Vector3(flow.x, 0.0, flow.y)

	var across_m: float = xz.dot(Vector2(-lake_axis.y, lake_axis.x))
	var unit: Vector2 = gusts.gusts_at(along_m - now.travel_m, across_m, now.time_of_day_s)
	var gust: Vector2 = unit * now.spread_ms * gusts.gustiness(along_m)
	var direction: Vector2 = flow / base_ms
	var side: Vector2 = Vector2(-direction.y, direction.x)
	var new_speed_ms: float = maxf(base_ms + gust.x, 0.05 * base_ms)
	var result: Vector2 = direction * new_speed_ms + side * gust.y * gusts.sideways_share
	if lee != null:
		result *= lee_factor(point, rad_to_deg(to_rad) - 180.0, speed_ms / SimMath.KNOT_MS, unit.x)
	return Vector3(result.x, 0.0, result.y)


## How much of the wind is left in the lee at a game position (1 away from it): the band's lee for
## the lake's wind of the moment (where it comes from, degrees; its speed, knots), times the lee's
## shape there, except as far as the gust there gets in (unit_along: the gust with a spread of 1);
## divided by what the fixed pattern already took off there. The deeper lee without reaching gusts
## (band_lee / (1 - reach_share)) makes the average over time the photos'.
func lee_factor(point: Vector3, from_deg: float, lake_kt: float, unit_along: float) -> float:
	var shape_held: Vector2 = lee.at(point.x, point.z)
	if shape_held == Vector2.ZERO:
		return 1.0
	var depth: float = lee.band_lee(from_deg, lake_kt) / (1.0 - gusts.reach_share)
	var left: float = 1.0 - shape_held.x * depth * (1.0 - gusts.reach(unit_along))
	return maxf(left, 0.05) / (1.0 - shape_held.y)


## The wind speed at a game position and a time of day, in m/s.
func speed_ms_at(point: Vector3, time_of_day_s: float) -> float:
	return velocity_at(point, time_of_day_s).length()


## Where the wind comes from at a game position and a time of day: a compass bearing, 0 to 360 degrees.
func from_deg_at(point: Vector3, time_of_day_s: float) -> float:
	return from_deg_of(velocity_at(point, time_of_day_s))


## Where a velocity's wind comes from: a compass bearing, 0 to 360 degrees (north is -Z, east +X).
static func from_deg_of(velocity: Vector3) -> float:
	return fposmod(rad_to_deg(atan2(-velocity.x, velocity.z)), 360.0)


## Where the lake's mean wind comes from at a time of day, degrees (without the shifts).
func lake_from_deg(time_of_day_s: float) -> float:
	return pattern.lake_from_deg + day.turn_deg(time_of_day_s)


## What the wind shaders need that never changes (see wind_pattern.gdshaderinc). Without gusts,
## everything that makes them is zero.
func shader_constants() -> Dictionary[String, Variant]:
	var constants: Dictionary[String, Variant] = {"lake_axis": lake_axis}
	if gusts == null:
		return constants
	var shifts_rad: Vector3 = Vector3(gusts.shift_amplitudes_deg[0], gusts.shift_amplitudes_deg[1], gusts.shift_amplitudes_deg[2]) * PI / 180.0
	constants["pulse_amplitudes"] = Vector3(gusts.pulse_amplitudes[0], gusts.pulse_amplitudes[1], gusts.pulse_amplitudes[2])
	constants["pulse_periods_s"] = Vector3(gusts.pulse_periods_s[0], gusts.pulse_periods_s[1], gusts.pulse_periods_s[2])
	constants["pulse_phases"] = gusts.phases(1)
	constants["shift_amplitudes_rad"] = shifts_rad
	constants["shift_periods_s"] = Vector3(gusts.shift_periods_s[0], gusts.shift_periods_s[1], gusts.shift_periods_s[2])
	constants["shift_phases"] = gusts.phases(2)
	constants["gustiness_ends"] = Vector4(gusts.gustiness_upwind, gusts.gustiness_downwind, gusts.upwind_end_m, gusts.downwind_end_m)
	constants["gust_sideways_share"] = gusts.sideways_share
	# The two parts' weights (their spread scaled to 1, shared as in WindGusts.gusts_at()), the
	# noise's cell sizes (along, across, metres) and lives (seconds), and its streams.
	constants["gust_weights"] = Vector2(sqrt(gusts.front_share), sqrt(1.0 - gusts.front_share))
	constants["front_cells"] = Vector3(gusts.front_cell_along_m, gusts.front_cell_across_m, gusts.front_life_s)
	constants["lane_cells"] = Vector3(gusts.lane_cell_along_m, gusts.lane_cell_across_m, gusts.lane_life_s)
	constants["gust_stream"] = gusts.seed * 4
	constants["lee_reach"] = Vector3(gusts.reach_centre(), gusts.reach_width, gusts.reach_share)
	return constants


## The lake's mean wind at a time of day: Vector2(speed m/s, bearing the air moves to in radians).
func _lake_wind(time_of_day_s: float) -> Vector2:
	return Vector2(day.lake_speed_ms(time_of_day_s), deg_to_rad(lake_from_deg(time_of_day_s) + 180.0))


## The table behind travel_m(): the drift speed added up over the whole day, step by step.
func _add_up_travel() -> void:
	var steps: int = int(24.0 * 3600.0 / TRAVEL_STEP_S) + 1
	_travel_m.resize(steps)
	_travel_m[0] = 0.0
	var before_ms: float = gusts.drift_ms(day.lake_speed_ms(0.0))
	for i: int in range(1, steps):
		var now_ms: float = gusts.drift_ms(day.lake_speed_ms(i * TRAVEL_STEP_S))
		_travel_m[i] = _travel_m[i - 1] + (before_ms + now_ms) / 2.0 * TRAVEL_STEP_S
		before_ms = now_ms
