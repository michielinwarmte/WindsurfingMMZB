class_name WindMoment
extends RefCounted
## A map's wind at one moment of the day (MapWind.moment()): the day's mean wind on the lake and what
## the gusts need at that moment. MapWind.velocity_in() asks it for the wind at any number of
## places, and the viewer gives it to the shaders every frame (shader_parameters()).

## Seconds since midnight.
var time_of_day_s: float = 0.0
## The lake's mean wind: speed (m/s) and the bearing its air moves to (radians).
var lake_speed_ms: float = 0.0
var lake_to_rad: float = 0.0
## How fast gusts, pulses and shifts travel down the lake, m/s.
var drift_ms: float = 2.0
## How far the air has travelled down the lake since midnight, metres (MapWind.travel_m()): the
## gusts roll with it.
var travel_m: float = 0.0
## The spread of the gusts and lulls along the wind, m/s (WindGusts.spread_ms()).
var spread_ms: float = 0.0


## What the wind shaders need from this moment (see wind_pattern.gdshaderinc).
func shader_parameters() -> Dictionary[String, Variant]:
	return {
		"lake_speed_ms": lake_speed_ms,
		"lake_to_rad": lake_to_rad,
		"time_of_day_s": time_of_day_s,
		"drift_ms": drift_ms,
		"travel_m": travel_m,
		"gust_spread_ms": spread_ms,
	}
