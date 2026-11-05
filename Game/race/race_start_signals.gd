class_name RaceStartSignals
extends RefCounted
## The sounds of a race's start (ROADMAP SO3; the archived RACING_PLAN.md, 9A: "Sounds at 60, 30, 10
## and 5 to 1, and the gun"): which signal is due as the countdown runs. A plain class that only
## counts; the race (RaceRunner, and RaceMirror on a LAN guest) asks it every tick and hands what is
## due to the sounds (GameAudio.play_race_signal()).
##
## The signals, as at a real start:
##   a long horn from the start boat at every whole minute before the gun (3:00, 2:00 and 1:00 with
##   a 3 minute countdown), and at the countdown's first moment when that is not a whole minute;
##   a short horn at 30 s;
##   a beep of the sailor's start watch at 10 s and at 5, 4, 3, 2 and 1 s;
##   the gun at 0.
## Each signal sounds once per start. A signal more than LATE_S late is skipped, not played late:
## a LAN guest's race clock is set to the host's once a second and may jump, and a guest that
## joins during the countdown must not hear every signal it missed at once.

enum Kind { LONG_HORN, SHORT_HORN, BEEP, GUN }

const SHORT_HORN_AT_S: float = 30.0
const BEEPS_AT_S: PackedFloat64Array = [10.0, 5.0, 4.0, 3.0, 2.0, 1.0]
## A signal is played up to this long after its moment, seconds (a few ticks; see above).
const LATE_S: float = 0.5

## The signals of this start, earliest first: seconds before the gun, and what sounds then.
var _times_s: PackedFloat64Array = PackedFloat64Array()
var _kinds: Array[Kind] = []
## 1 for each signal that has sounded (or was skipped as too late).
var _done: PackedByteArray = PackedByteArray()


## The signals of a countdown this long (RaceSim.prestart_s, seconds).
func _init(countdown_s: float) -> void:
	if not _is_signal_time(countdown_s):
		_add(countdown_s, Kind.LONG_HORN)
	var minute: int = floori(countdown_s / 60.0 + 1e-6)
	while minute >= 1:
		_add(minute * 60.0, Kind.LONG_HORN)
		minute -= 1
	if SHORT_HORN_AT_S <= countdown_s + 1e-6:
		_add(SHORT_HORN_AT_S, Kind.SHORT_HORN)
	for at_s: float in BEEPS_AT_S:
		if at_s <= countdown_s + 1e-6:
			_add(at_s, Kind.BEEP)
	_add(0.0, Kind.GUN)


## The signals due now, in order, for the race clock (RaceSim.clock_s(): negative in the countdown,
## 0 at the gun); nothing before the countdown has started (RaceSim.is_started()).
func update(started: bool, clock_s: float) -> Array[Kind]:
	var due: Array[Kind] = []
	if not started:
		return due
	for i: int in _times_s.size():
		if _done[i] == 1:
			continue
		var at_s: float = -_times_s[i]
		if clock_s < at_s - 1e-9:
			continue
		_done[i] = 1
		if clock_s < at_s + LATE_S:
			due.append(_kinds[i])
	return due


## The seconds before the gun of every signal of this start, earliest first (for the tests).
func times_s() -> PackedFloat64Array:
	return _times_s


func _add(at_s: float, kind: Kind) -> void:
	_times_s.append(at_s)
	_kinds.append(kind)
	_done.append(0)


## Whether a whole minute, the short horn, a beep or the gun already sounds at this moment.
static func _is_signal_time(at_s: float) -> bool:
	if at_s <= 1e-6:
		return true
	if absf(at_s / 60.0 - roundf(at_s / 60.0)) < 1e-6:
		return true
	if absf(at_s - SHORT_HORN_AT_S) < 1e-6:
		return true
	for beep_s: float in BEEPS_AT_S:
		if absf(at_s - beep_s) < 1e-6:
			return true
	return false
