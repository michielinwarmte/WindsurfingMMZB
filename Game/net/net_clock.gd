class_name NetClock
extends RefCounted
## The guest's estimate of the host's clock (LAN multiplayer, Documentation/reports/multiplayer/
## PLAN.md, D7). It also measures how fast the host's game really runs (host_ticks_per_second()): a
## host with a big AI fleet on a slow PC may run slower than real time, and the guest then slows its
## own game to the same pace (NetBoards), so both sail in the same moment. The host sends its tick, the water's clock and the wind's every tick. A message
## can only come late, never early, so the difference "host tick minus my tick" is largest for the
## quickest messages: the largest difference of the last WINDOW messages is taken as the offset
## between the two clocks. It follows a PC that falls behind (a long frame) at once, and one that
## runs ahead within WINDOW messages.

## How many of the host's messages the offset looks back over (2 s of ticks).
const WINDOW: int = 120

## How far the steady count may be from the offset's estimate before it is moved to it, ticks.
const STEADY_SLACK: int = 2
## The host's pace is measured over this much real time, seconds.
const PACE_WINDOW_S: float = 2.0
## The newest messages' host tick and the host's real time when it sent them (seconds), for the
## pace: the host's own clock, so a message that is late or comes in a burst does not count.
var _pace_real_s: PackedFloat64Array = PackedFloat64Array()
var _pace_ticks: PackedInt64Array = PackedInt64Array()

var _samples: PackedInt64Array = PackedInt64Array()
## The last answer of host_tick_now() and the tick of this PC it was for.
var _last_my_tick: int = -1
var _last_tick: int = 0
var _lead: int = 0
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


## A clock message from the host, which arrived at this PC's tick `my_tick`; `host_real_s` is the
## host's real time when it sent it (-1: not known, then this PC's time of arrival is used).
func receive(tick: int, my_tick: int, water_s: float, wind_s: float, travel_m: float, day_s: float, host_real_s: float = -1.0) -> void:
	_samples.append(tick - my_tick)
	if _samples.size() > WINDOW:
		_samples.remove_at(0)
	_offset = _samples[0]
	for sample: int in _samples:
		_offset = maxi(_offset, sample)
	_has_offset = true
	if tick <= host_tick:
		return  # an old message: the offset learns from it, the clock does not go back
	var real_s: float = host_real_s if host_real_s >= 0.0 else Time.get_ticks_usec() / 1e6
	_pace_real_s.append(real_s)
	_pace_ticks.append(tick)
	while _pace_real_s.size() > 2 and real_s - _pace_real_s[0] > PACE_WINDOW_S:
		_pace_real_s.remove_at(0)
		_pace_ticks.remove_at(0)
	if host_tick >= 0:
		_travel_per_tick_m = (travel_m - wind_travel_m) / float(tick - host_tick)
	host_tick = tick
	water_time_s = water_s
	wind_time_s = wind_s
	wind_travel_m = travel_m
	time_of_day_s = day_s


## How many ticks a second the host's game runs, measured on the host's own clock over the last
## PACE_WINDOW_S of its real time; `normal` (the physics' rate) until a second has been measured.
func host_ticks_per_second(normal: float) -> float:
	if _pace_real_s.size() < 2:
		return normal
	var span_s: float = _pace_real_s[_pace_real_s.size() - 1] - _pace_real_s[0]
	if span_s < 1.0:
		return normal
	return float(_pace_ticks[_pace_ticks.size() - 1] - _pace_ticks[0]) / span_s


## Whether a clock message has come yet.
func is_known() -> bool:
	return _has_offset


## The host's tick now, at this PC's tick. It goes up by exactly one each tick, as the host's does,
## and never goes back: the offset's estimate can move by a tick when its quickest message leaves
## the window, and a tick counted twice would give two of this PC's states the same number. When it
## falls more than STEADY_SLACK behind the estimate (a long frame here) it jumps forward; when it is
## ahead (the host is slower than this PC) it stays steady and lead() tells NetBoards to slow down.
func host_tick_now(my_tick: int) -> int:
	if my_tick == _last_my_tick:
		return _last_tick
	var estimate: int = my_tick + _offset
	if _last_my_tick >= 0:
		var steady: int = _last_tick + (my_tick - _last_my_tick)
		_lead = steady - estimate
		if _lead >= -STEADY_SLACK:
			estimate = steady
	_last_my_tick = my_tick
	_last_tick = estimate
	return estimate


## How many ticks the steady count is ahead of the estimate (0 or less: not ahead).
func lead() -> int:
	return _lead


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
