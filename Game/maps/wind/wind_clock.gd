class_name WindClock
extends RefCounted
## The wind viewer's clock (MAP_SILVAPLANA_PLAN.md, W2): the simulated time of day, which runs in
## real time or sped up, can be paused, and can be set anywhere in the day. The wind is worked out
## from this time, never from the computer's clock, so a moment of the day can be looked at again.

## The speeds the viewer offers: real time, 10 and 60 times faster.
const RATES: Array[float] = [1.0, 10.0, 60.0]
## The part of the day the slider covers: the Maloja's day, 10:00 to 21:30 (MALOJA_WIND_RESEARCH.md).
const DAY_START_S: float = 10.0 * 3600.0
const DAY_END_S: float = 21.5 * 3600.0

## Seconds since midnight, local summer time.
var time_of_day_s: float = 14.0 * 3600.0
## How many simulated seconds pass in one real second.
var rate: float = 1.0
var paused: bool = false


## Moves the clock on by a real time step. It stops at the end of the day.
func advance(real_delta_s: float) -> void:
	if paused:
		return
	time_of_day_s = minf(time_of_day_s + real_delta_s * rate, DAY_END_S)
	if time_of_day_s >= DAY_END_S:
		paused = true


## Jumps to a time of day (seconds since midnight), kept within the day.
func set_time(seconds: float) -> void:
	time_of_day_s = clampf(seconds, DAY_START_S, DAY_END_S)


## The time of day as text, like "14:05:30".
func text() -> String:
	var seconds: int = floori(time_of_day_s)
	return "%02d:%02d:%02d" % [floori(seconds / 3600.0), floori(seconds / 60.0) % 60, seconds % 60]
