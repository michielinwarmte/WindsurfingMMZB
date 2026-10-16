class_name SplashTrigger
extends RefCounted
## Decides when the hull lands hard enough to throw up a splash. It watches how hard the water
## holds the hull up (buoyancy plus planing lift): riding over ordinary waves changes that
## slowly and by less than the windsurfer's weight, but when the board comes down after a
## jump, or slams into a wave, it jumps by several times the weight within a few hundredths
## of a second. A splash then needs a rise of more than RISE_WEIGHTS times the weight within
## WINDOW_S, and after one it waits COOLDOWN_S, so one landing gives one splash.
##
## Measured with the autopilot at 18 knots, 60 s on each wave setting (October 2026): a rise of
## 2.5 weights happens about twice a minute on the default swell, every second or two on
## chop (where real boards bang through the waves too), never on flat water. A look only:
## nothing here feeds back into the physics.

## The rise must happen within this time...
const WINDOW_S: float = 0.2
## ...and be at least this many times the weight of board, rig and sailor.
const RISE_WEIGHTS: float = 2.5
## No new splash for this long after one.
const COOLDOWN_S: float = 0.5

## How hard the last landing was: the rise of the support, in weights (1 = just enough).
var last_strength: float = 0.0

var _time_s: float = 0.0
var _cooldown_s: float = 0.0
## (time, support) over the last WINDOW_S.
var _history: Array[Vector2] = []


## Feeds one physics tick: the water's support of the hull (N), the total weight (N) and the
## time step. True on the tick a splash should start.
func update(support_n: float, weight_n: float, dt: float) -> bool:
	_time_s += dt
	_cooldown_s = maxf(_cooldown_s - dt, 0.0)
	_history.append(Vector2(_time_s, support_n))
	while _history.size() > 1 and _history[0].x < _time_s - WINDOW_S:
		_history.pop_front()
	var rise: float = (support_n - _lowest_support()) / maxf(weight_n, 1.0)
	if rise < RISE_WEIGHTS or _cooldown_s > 0.0:
		return false
	_cooldown_s = COOLDOWN_S
	last_strength = rise
	return true


## Forgets the past, for example after a reset or a fall.
func clear() -> void:
	_history.clear()
	_cooldown_s = 0.0


func _lowest_support() -> float:
	var lowest: float = INF
	for sample: Vector2 in _history:
		lowest = minf(lowest, sample.y)
	return lowest
