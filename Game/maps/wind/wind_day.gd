class_name WindDay
extends Resource
## A day of a map's wind, hour by hour: how strong the wind is on the lake on average, and how its
## direction changes through the day (MAP_SILVAPLANA_PLAN.md, W2). Between the hours it is
## interpolated in a straight line; before the first and after the last hour it keeps their values.
##
## First version (W2): the average Maloja day, measured at the station and scaled to the water.
## Phase W3 replaces it with days that have a start front, gusts, pulses and shifts, and light,
## medium and strong days.

## When each value applies, in hours of local (summer) time, for example 14.5 for 14:30.
@export var hours: PackedFloat32Array = PackedFloat32Array()
## The measured mean wind speed at the station at those hours, in knots.
@export var station_speed_kt: PackedFloat32Array = PackedFloat32Array()
## The measured direction at the station at those hours: where the wind comes from, degrees.
@export var station_from_deg: PackedFloat32Array = PackedFloat32Array()
## The station's usual afternoon direction. The lake's direction turns by as much as the
## station's turns away from it (the pattern already holds how the lake differs from the station).
@export var station_afternoon_from_deg: float = 0.0
## How much stronger the wind is on the water (the lake's average) than at the station.
@export var water_vs_station: float = 1.0


## The lake's average wind speed at a time of day (seconds since midnight), in m/s.
func lake_speed_ms(time_of_day_s: float) -> float:
	return _interpolate(station_speed_kt, time_of_day_s) * water_vs_station * SimMath.KNOT_MS


## How many degrees the wind comes from further clockwise than in the afternoon, at a time of day
## (seconds since midnight). Negative: turned left (backed), as in the evening.
func turn_deg(time_of_day_s: float) -> float:
	return _interpolate(station_from_deg, time_of_day_s) - station_afternoon_from_deg


func _interpolate(values: PackedFloat32Array, time_of_day_s: float) -> float:
	var hour: float = time_of_day_s / 3600.0
	if hour <= hours[0]:
		return values[0]
	for i: int in range(1, hours.size()):
		if hour <= hours[i]:
			return lerpf(values[i - 1], values[i], (hour - hours[i - 1]) / (hours[i] - hours[i - 1]))
	return values[values.size() - 1]
