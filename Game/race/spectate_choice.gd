class_name SpectateChoice
extends RefCounted
## Which board the camera follows while spectating a race (--spectate=1, RaceRunner): at first the
## leader, and the leader again whenever the lead changes, but only once the new leader has led for
## HOLD_S, so the camera does not flick between two boards side by side in a close pack. Tab and
## Shift+Tab step to the next and the previous board in race order and stop following the leader;
## L follows the leader again (at once). Plain logic with the race order handed in, so the tests can
## drive it without a scene.

## How long a new leader has to lead before the camera goes to it, seconds.
const HOLD_S: float = 3.0

## The board followed (its number in the race); -1 before the first update.
var followed: int = -1
## Whether the camera follows the leader by itself (Tab turns it off, L on).
var follows_leader: bool = true
## The board that has led since the camera last moved, and for how long (seconds).
var _new_leader: int = -1
var _led_s: float = 0.0


## Every frame (or tick): the race order now (board numbers, the leader first) and the time since
## the last call. Returns the board to follow.
func update(order: Array[int], dt: float) -> int:
	if order.is_empty():
		return followed
	if followed < 0 or not order.has(followed):
		followed = order[0]
		_new_leader = -1
		_led_s = 0.0
		return followed
	if not follows_leader or order[0] == followed:
		_new_leader = -1
		_led_s = 0.0
		return followed
	if order[0] != _new_leader:
		_new_leader = order[0]
		_led_s = 0.0
	_led_s += dt
	if _led_s >= HOLD_S:
		followed = _new_leader
		_new_leader = -1
		_led_s = 0.0
	return followed


## Tab (+1) and Shift+Tab (-1): the next or the previous board in race order, round the end; the
## camera stops following the leader.
func step(order: Array[int], by: int) -> int:
	follows_leader = false
	_new_leader = -1
	_led_s = 0.0
	if order.is_empty():
		return followed
	var at: int = order.find(followed)
	followed = order[wrapi(at + by, 0, order.size())] if at >= 0 else order[0]
	return followed


## L: follow the leader again, from now on and at once.
func follow_leader(order: Array[int]) -> int:
	follows_leader = true
	_new_leader = -1
	_led_s = 0.0
	if not order.is_empty():
		followed = order[0]
	return followed
