class_name RaceRules
extends RefCounted
## The racing rules of sailing, in their simplest form (RACING_PLAN.md 9E; AI_FLEET_PLAN.md D5 and
## decision 2: "port and starboard, and room at the mark; a penalty turn for the AI, a warning and
## a time penalty for the player"). The judge: who keeps clear of whom, when a board broke a rule,
## and the penalties. A plain class fed every board's place, heading, tack and speed each tick
## (set_board()), then step(); the game, the race tool and the trainer all use the same one.
##
##   Rule 10   A board on port tack keeps clear of a board on starboard tack.
##   Rule 11   Two boards on the same tack, overlapped: the windward board keeps clear of the
##             leeward one.
##   Rule 12   Two boards on the same tack, not overlapped: the board clear astern keeps clear of
##             the board clear ahead.
##   Rule 18   Room at the mark: of two overlapped boards on the same tack inside the zone round
##             the mark they are both sailing to, the inside board (the one nearer the mark) gets
##             room, whatever rules 11 and 12 say.
## Two boards are overlapped when neither is clear astern of the other: a board is clear astern
## when its whole hull is behind the line across the other's stern.
##
## A breach: two boards come within CONTACT_M of each other (the boards pass through each other,
## so that stands for a touch), and the one that had to keep clear was closing on the other. It
## gets one penalty for the incident (not another from the same pair for INCIDENT_S). A penalty is
## cleared by a full turn (one tack and one gybe: the heading sweeping FULL_TURN_DEG since it was
## given, the way the sailing rules' one-turn penalty goes) or, uncleared at the finish, it costs
## TIME_PENALTY_S of race time (the player's choice; the scripted skippers turn).
##
## Positions are game metres (X east, Z south), headings compass degrees, tacks +1 for starboard
## (the wind over the right side) and -1 for port, as everywhere in the race.

## A board's hull length, metres: what "clear astern" and "a touch" are measured with.
const HULL_M: float = 2.4
## Two boards this close touch (their centres; about a hull length).
const CONTACT_M: float = 2.6
## The rules are looked at for pairs this close only, metres.
const NEAR_M: float = 15.0
## The zone round a mark where mark room applies, metres (the rules say three hull lengths;
## planing boards need more).
const ZONE_M: float = 15.0
## One incident, one penalty: the same pair gets no second one for this long, seconds.
const INCIDENT_S: float = 10.0
## A penalty turn is done when the heading has swept this much since the penalty was given, degrees
## (a full circle, with some slack for the wobble).
const FULL_TURN_DEG: float = 330.0
## An uncleared penalty at the finish, seconds of race time.
const TIME_PENALTY_S: float = 20.0

## What the burdened board must keep clear of, for the words on the screen and the notes.
enum Why { NONE, PORT_GIVES_WAY, WINDWARD_GIVES_WAY, ASTERN_GIVES_WAY, MARK_ROOM }
const WHY_TEXT: PackedStringArray = ["", "port gives way to starboard", "the windward board keeps clear",
	"the board clear astern keeps clear", "the inside board has room at the mark"]


## One board as the judge sees it this tick.
class BoardState:
	var position: Vector2 = Vector2.ZERO
	var last_position: Vector2 = Vector2.ZERO
	var heading_deg: float = 0.0
	var tack: float = 1.0
	var speed_ms: float = 0.0
	## A sail in the water keeps no rules and is kept clear of by nobody (it is in the water).
	var sailing: bool = true
	## Outstanding penalties, and the heading swept since the last one was given (the turn).
	var penalties: int = 0
	var turn_deg: float = 0.0
	var last_heading_deg: float = 0.0
	## Why it last had to keep clear (this tick), and of whom (-1: nobody).
	var burdened_by: int = -1
	var why: Why = Why.NONE
	## The last breach: why, and when (race time), for the warning.
	var last_breach_why: Why = Why.NONE
	var last_breach_s: float = -INF
	## Penalties taken by a turn, and the time penalty carried to the finish.
	var turns_done: int = 0


var _boards: Array[BoardState] = []
## When each pair last had an incident (seconds): pair (i, j) with i < j at i * 10000 + j.
var _incidents: Dictionary[int, float] = {}
var _time_s: float = 0.0
## Where the wind comes from, degrees: what windward means.
var wind_from_deg: float = 0.0


## The judge for a race of this many boards.
func _init(board_count: int = 0, wind_from_degrees: float = 0.0) -> void:
	wind_from_deg = wind_from_degrees
	for i: int in board_count:
		_boards.append(BoardState.new())


func board_count() -> int:
	return _boards.size()


## Where a board is and how it sails, this tick (before step()).
func set_board(index: int, position: Vector2, heading_deg: float, tack: float, speed_ms: float, sailing: bool = true) -> void:
	var b: BoardState = _boards[index]
	b.position = position
	b.heading_deg = heading_deg
	b.tack = 1.0 if tack >= 0.0 else -1.0
	b.speed_ms = speed_ms
	b.sailing = sailing


## One tick: the heading swept for the penalty turns, who must keep clear of whom among the
## boards near each other, and the breaches. `next_marks` is where each board's next mark is (for
## mark room; Vector2.INF for a board sailing to a line or finished).
func step(dt: float, next_marks: PackedVector2Array = PackedVector2Array()) -> void:
	_time_s += dt
	for b: BoardState in _boards:
		if b.penalties > 0:
			b.turn_deg += absf(wrapf(b.heading_deg - b.last_heading_deg, -180.0, 180.0))
			if b.turn_deg >= FULL_TURN_DEG:
				b.penalties -= 1
				b.turns_done += 1
				b.turn_deg = 0.0
		b.last_heading_deg = b.heading_deg
		b.burdened_by = -1
		b.why = Why.NONE
	for i: int in _boards.size():
		var a: BoardState = _boards[i]
		if not a.sailing:
			continue
		for j: int in range(i + 1, _boards.size()):
			var b: BoardState = _boards[j]
			if not b.sailing:
				continue
			var apart: Vector2 = b.position - a.position
			var distance_m: float = apart.length()
			if distance_m > NEAR_M:
				continue
			var mark: Vector2 = Vector2.INF
			if i < next_marks.size() and j < next_marks.size() and next_marks[i] == next_marks[j]:
				mark = next_marks[i]
			var why: Why = Why.NONE
			var burdened: int = who_keeps_clear(i, j, mark)
			why = _why_of(i, j, burdened, mark)
			if burdened >= 0:
				var other: int = j if burdened == i else i
				var loser: BoardState = _boards[burdened]
				# The nearest board it must keep clear of is the one it is told about.
				if loser.burdened_by < 0 or loser.position.distance_to(_boards[other].position) < loser.position.distance_to(_boards[loser.burdened_by].position):
					loser.burdened_by = other
					loser.why = why
				if distance_m <= CONTACT_M and _closing(loser, _boards[other]):
					_breach(i, j, burdened, why)
	for b: BoardState in _boards:
		b.last_position = b.position


## Which of two boards keeps clear of the other (its index), or -1 when the rules say nothing
## between them (not on the same water: the judge only asks for boards near each other). `mark`
## is the mark both are sailing to, for mark room, or Vector2.INF.
func who_keeps_clear(i: int, j: int, mark: Vector2 = Vector2.INF) -> int:
	var a: BoardState = _boards[i]
	var b: BoardState = _boards[j]
	if a.tack != b.tack:
		return i if a.tack < 0.0 else j  # rule 10: port keeps clear
	var overlapped: bool = not is_clear_astern(i, j) and not is_clear_astern(j, i)
	if overlapped:
		if mark != Vector2.INF and a.position.distance_to(mark) <= ZONE_M and b.position.distance_to(mark) <= ZONE_M:
			# Rule 18: the inside board (nearer the mark) gets room; the outside one keeps clear.
			return j if a.position.distance_to(mark) <= b.position.distance_to(mark) else i
		return i if is_windward(i, j) else j  # rule 11
	return i if is_clear_astern(i, j) else j  # rule 12


## True when board i is clear astern of board j: all of its hull behind the line across j's stern.
func is_clear_astern(i: int, j: int) -> bool:
	var forward: Vector2 = Course.direction_of(_boards[j].heading_deg)
	var along: float = (_boards[i].position - _boards[j].position).dot(forward)
	return along < -HULL_M


## True when board i is to windward of board j: nearer where the wind comes from.
func is_windward(i: int, j: int) -> bool:
	var toward_wind: Vector2 = Course.direction_of(wind_from_deg)
	return (_boards[i].position - _boards[j].position).dot(toward_wind) > 0.0


## The board a board must keep clear of right now (-1: none), and why.
func burdened_by(index: int) -> int:
	return _boards[index].burdened_by


func why(index: int) -> Why:
	return _boards[index].why


func why_text(index: int) -> String:
	return WHY_TEXT[_boards[index].why]


## A board's outstanding penalties (each cleared by a full turn, or 20 s at the finish).
func penalties(index: int) -> int:
	return _boards[index].penalties


## How many penalties a board cleared by turning.
func turns_done(index: int) -> int:
	return _boards[index].turns_done


## The race time a board's outstanding penalties cost at the finish.
func time_penalty_s(index: int) -> float:
	return TIME_PENALTY_S * _boards[index].penalties


## Why a board was last penalised, and when (race time; -INF for never).
func last_breach_why(index: int) -> Why:
	return _boards[index].last_breach_why


func last_breach_s(index: int) -> float:
	return _boards[index].last_breach_s


## The words for the screen when a board has just been penalised: what it should have done.
func breach_text(index: int) -> String:
	return WHY_TEXT[_boards[index].last_breach_why]


## Gives a board a penalty by hand (the tests, a referee).
func penalise(index: int, reason: Why = Why.NONE) -> void:
	var b: BoardState = _boards[index]
	b.penalties += 1
	b.turn_deg = 0.0
	b.last_breach_why = reason
	b.last_breach_s = _time_s


# ---------------------------------------------------------------- inside

func _why_of(i: int, j: int, burdened: int, mark: Vector2) -> Why:
	if burdened < 0:
		return Why.NONE
	var a: BoardState = _boards[i]
	var b: BoardState = _boards[j]
	if a.tack != b.tack:
		return Why.PORT_GIVES_WAY
	var overlapped: bool = not is_clear_astern(i, j) and not is_clear_astern(j, i)
	if overlapped:
		if mark != Vector2.INF and a.position.distance_to(mark) <= ZONE_M and b.position.distance_to(mark) <= ZONE_M:
			return Why.MARK_ROOM
		return Why.WINDWARD_GIVES_WAY
	return Why.ASTERN_GIVES_WAY


## True when a board moves toward another (the distance between them is shrinking by its own
## motion): it did not keep clear.
func _closing(loser: BoardState, other: BoardState) -> bool:
	var motion: Vector2 = loser.position - loser.last_position
	return motion.dot(other.position - loser.position) > 0.0


func _breach(i: int, j: int, burdened: int, why: Why) -> void:
	var key: int = mini(i, j) * 10000 + maxi(i, j)
	if _incidents.has(key) and _time_s - _incidents[key] < INCIDENT_S:
		return
	_incidents[key] = _time_s
	penalise(burdened, why)
