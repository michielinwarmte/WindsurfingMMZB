class_name FeltWind
extends RefCounted
## The wind a skipper has felt at its own sail lately: the wind now, its mean over the last minute or two, and how much
## it has varied (Max, 10 November 2026, watching the AI start PD3 in the lull of the lake: "if the AIs do not have
## info about the current wind and average wind felt in the last minute or 2 ... give them that so they can adapt to
## wind speed in sail").
##
## Why: on the lake the telemetry's tws_10m_kt is the lake's MEAN wind of the moment (MapWindField: the mean carries
## the decisions "where is the wind from, out on this lake"), not the wind where the board is. The sail feels the local
## wind: the map's pattern, its gusts and lulls, the lee under the shore, and the other sails' wind shadows
## (WindField.velocity_at() with its disturbance). In the lee of T2's and PD3's start areas that is 8 to 10 kt when the
## mean is 14 or more (the phase S log, 9-10 November 2026), and a skipper timing its run in to the line with the
## mean's speeds and acceleration goes too late and crosses slow.
##
## The felt wind is the sail's own (Telemetry.tws_at_sail_kt), put on the 10 m height the skipper's polar is measured
## at the way the spray does it (Effects._update_crest_spray()): the 10 m mean times the sail's wind over the mean at
## the sail's height. It is sampled every SAMPLE_EVERY_S while the sailor sails (a fallen rig's wind says nothing) and
## kept for KEEP_S.

## A sample every this many seconds of the skipper's clock.
const SAMPLE_EVERY_S: float = 0.5
## The samples are kept this long, seconds (Max: "the last minute or 2").
const KEEP_S: float = 120.0
## The wind "now": the mean over this many seconds (one sample is a gust's edge).
const NOW_S: float = 3.0
## The sail's height for the mean's profile, metres (as Effects.SAIL_HEIGHT_M).
const SAIL_HEIGHT_M: float = 2.0
## The felt wind against the mean is kept within these shares (a sail lying flat for a moment, a sample at a gust's
## core): the map's own pattern runs from about 0.4 to 1.6 of the mean.
const LEAST_SHARE: float = 0.2
const MOST_SHARE: float = 2.0

var _times: PackedFloat32Array = PackedFloat32Array()
var _kts: PackedFloat32Array = PackedFloat32Array()
var _first: int = 0


## The wind at the sail now as a wind at 10 m, knots: the 10 m mean times the sail's wind over the mean at the sail's
## height (the gust, the lull, the lee, a shadow). Without a mean (a calm), the 10 m mean.
static func felt_10m_kt(telemetry: Telemetry, wind: WindField) -> float:
	if wind == null:
		return telemetry.tws_10m_kt
	var mean_at_sail_kt: float = wind.speed_at_height(SAIL_HEIGHT_M) / SimMath.KNOT_MS
	if mean_at_sail_kt < 0.1:
		return telemetry.tws_10m_kt
	return telemetry.tws_10m_kt * clampf(telemetry.tws_at_sail_kt / mean_at_sail_kt, LEAST_SHARE, MOST_SHARE)


## Forget everything (a new race, the board somewhere else).
func clear() -> void:
	_times = PackedFloat32Array()
	_kts = PackedFloat32Array()
	_first = 0


## A sample at time_s (the skipper's clock, rising), knots; ignored until SAMPLE_EVERY_S after the last one. The
## samples older than KEEP_S go.
func add(time_s: float, kt: float) -> void:
	if not is_finite(kt):
		return
	if count() > 0 and time_s - _times[_times.size() - 1] < SAMPLE_EVERY_S - 1e-4:
		return
	_times.append(time_s)
	_kts.append(kt)
	while _first < _times.size() and _times[_first] < time_s - KEEP_S:
		_first += 1
	# Drop the old ones now and then, not at every sample.
	if _first > 256:
		_times = _times.slice(_first)
		_kts = _kts.slice(_first)
		_first = 0


## How many samples it has.
func count() -> int:
	return _times.size() - _first


## How many seconds the samples cover (0 with one or none).
func span_s() -> float:
	return _times[_times.size() - 1] - _times[_first] if count() > 1 else 0.0


## The mean of the last window_s seconds' samples, knots; NAN with none.
func mean_kt(window_s: float) -> float:
	var from: int = _from(window_s)
	var n: int = _times.size() - from
	if n <= 0:
		return NAN
	var total: float = 0.0
	for k: int in range(from, _times.size()):
		total += _kts[k]
	return total / n


## The wind now (the mean of the last NOW_S seconds), knots; NAN with none.
func now_kt() -> float:
	return mean_kt(NOW_S)


## How much the wind has varied over the last window_s seconds: the samples' standard deviation, knots; 0 with fewer
## than two.
func spread_kt(window_s: float) -> float:
	var from: int = _from(window_s)
	var n: int = _times.size() - from
	if n < 2:
		return 0.0
	var mean: float = mean_kt(window_s)
	var total: float = 0.0
	for k: int in range(from, _times.size()):
		total += (_kts[k] - mean) * (_kts[k] - mean)
	return sqrt(total / (n - 1))


## The lightest it has felt over the last window_s seconds, knots; NAN with none.
func lowest_kt(window_s: float) -> float:
	var from: int = _from(window_s)
	if from >= _times.size():
		return NAN
	var lowest: float = INF
	for k: int in range(from, _times.size()):
		lowest = minf(lowest, _kts[k])
	return lowest


## The first sample within window_s of the newest.
func _from(window_s: float) -> int:
	if count() == 0:
		return _times.size()
	var newest_s: float = _times[_times.size() - 1]
	var k: int = _times.size() - 1
	while k > _first and _times[k - 1] >= newest_s - window_s - 1e-4:
		k -= 1
	return k
