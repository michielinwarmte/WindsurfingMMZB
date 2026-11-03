class_name StateBuffer
extends RefCounted
## The states of one board sailed on another PC, as they arrive, by the host's tick they belong to
## (LAN multiplayer, Documentation/reports/multiplayer/PLAN.md, D6). The board is shown a few ticks
## behind its newest state, between the two states around that moment (state_at()), so a message
## that comes a little late or not at all does not make it jump.

## States older than this many ticks behind the newest are dropped.
const KEEP_TICKS: int = 90

var _ticks: PackedInt64Array = PackedInt64Array()
var _states: Array[BoardSnapshot] = []


## Keeps a state for a tick (a late one goes in its place; a tick already held is not taken twice).
func add(tick: int, state: BoardSnapshot) -> void:
	if state == null:
		return
	var at: int = _ticks.bsearch(tick)
	if at < _ticks.size() and _ticks[at] == tick:
		return
	_ticks.insert(at, tick)
	_states.insert(at, state)
	while _ticks.size() > 0 and _ticks[0] < _ticks[_ticks.size() - 1] - KEEP_TICKS:
		_ticks.remove_at(0)
		_states.remove_at(0)


func is_empty() -> bool:
	return _ticks.is_empty()


## The newest tick held (-1 for none).
func newest_tick() -> int:
	return _ticks[_ticks.size() - 1] if not _ticks.is_empty() else -1


func size() -> int:
	return _ticks.size()


## The state to show at a tick (a fraction is a moment between two ticks): between the two held
## states around it; the newest when it is newer than all (the board holds still rather than guess),
## the oldest when it is older than all. null when nothing is held.
func state_at(tick: float) -> BoardSnapshot:
	if _ticks.is_empty():
		return null
	var last: int = _ticks.size() - 1
	if tick >= float(_ticks[last]):
		return _states[last]
	if tick <= float(_ticks[0]):
		return _states[0]
	var after: int = _ticks.bsearch(ceili(tick))
	var before: int = after - 1
	if float(_ticks[after]) == tick or before < 0:
		return _states[after]
	var share: float = (tick - float(_ticks[before])) / float(_ticks[after] - _ticks[before])
	return BoardSnapshot.interpolate(_states[before], _states[after], share)
