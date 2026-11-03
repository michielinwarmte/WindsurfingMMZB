class_name NetClock
extends RefCounted
## The guest's estimate of the host's clock (LAN multiplayer, Documentation/reports/multiplayer/
## PLAN.md, D7). The host sends its tick, the water's clock and the wind's every tick. A message
## can only come late, never early, so the difference "host tick minus my tick" is largest for the
## quickest messages: the largest difference of the last WINDOW messages is taken as the offset
## between the two clocks. It follows a PC that falls behind (a long frame) at once, and one that
## runs ahead within WINDOW messages.

## How many of the host's messages the offset looks back over (2 s of ticks).
const WINDOW: int = 120

## How far the steady count may be from the offset's estimate before it is moved to it, ticks.
const STEADY_SLACK: int = 2

var _samples: PackedInt64Array = PackedInt64Array()
## The last answer of host_tick_now() and the tick of this PC it was for.
var _last_my_tick: int = -1
var _last_tick: int = 0
var _offset: int = 0
var _has_offset: bool = false
## The newest clock from the host: its tick, the water's time, the wind's time and travel, and the
## lake's time of day (-1 on the open water).
var host_tick: int = -1
var water_time_s: float = 0.0
var wind_time_s: float = 0.0
var wind_travel_m: float = 0.0
var time_of_day_s: float = -1.0
## How fast the wind's air travels (m per tick), from the last two messages, to move it on between them.
var _travel_per_tick_m: float = 0.0


## A clock message from the host, which arrived at this PC's tick `my_tick`.
func receive(tick: int, my_tick: int, water_s: float, wind_s: float, travel_m: float, day_s: float) -> void:
	_samples.append(tick - my_tick)
	if _samples.size() > WINDOW:
		_samples.remove_at(0)
	_offset = _samples[0]
	for sample: int in _samples:
		_offset = maxi(_offset, sample)
	_has_offset = true
	if tick <= host_tick:
		return  # an old message: the offset learns from it, the clock does not go back
	if host_tick >= 0:
		_travel_per_tick_m = (travel_m - wind_travel_m) / float(tick - host_tick)
	host_tick = tick
	water_time_s = water_s
	wind_time_s = wind_s
	wind_travel_m = travel_m
	time_of_day_s = day_s


## Whether a clock message has come yet.
func is_known() -> bool:
	return _has_offset


## The host's tick now, at this PC's tick. It goes up by exactly one each tick, as the host's does:
## the offset's estimate can move by a tick when its quickest message leaves the window, and a tick
## counted twice would give two of this PC's states the same number. Only a drift of more than
## STEADY_SLACK ticks from the estimate (a long frame, a clock that runs a little faster) moves it.
func host_tick_now(my_tick: int) -> int:
	if my_tick == _last_my_tick:
		return _last_tick
	var estimate: int = my_tick + _offset
	if _last_my_tick >= 0:
		var steady: int = _last_tick + (my_tick - _last_my_tick)
		if absi(steady - estimate) <= STEADY_SLACK:
			estimate = steady
	_last_my_tick = my_tick
	_last_tick = estimate
	return estimate


## The host's clocks at its tick `tick`, moved on from the newest message by the ticks between
## (dt seconds each): x the water's time, y the wind's time, z the wind's travel.
func clocks_at(tick: int, dt: float) -> Vector3:
	var ahead: int = tick - host_tick
	return Vector3(water_time_s + ahead * dt, wind_time_s + ahead * dt, wind_travel_m + ahead * _travel_per_tick_m)


## The lake's time of day at the host's tick `tick` (-1 on the open water): the map's clock runs in
## real time (sail_silvaplana.gd), one second a second.
func time_of_day_at(tick: int, dt: float) -> float:
	if time_of_day_s < 0.0:
		return -1.0
	return time_of_day_s + (tick - host_tick) * dt
