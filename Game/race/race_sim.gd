class_name RaceSim
extends RefCounted
## A race (RACING_PLAN.md, "How a race works"): the countdown and the gun, every board's way through
## the course's steps, the clock and the splits, the boards over the line early (OCS), and the
## finish. A plain class with no nodes, so the game, the headless race (tools/race.sh) and the tests
## all run the same race.
##
## Each tick the owner says where every board is (update_board()) and then moves the clock on
## (step()). For each board the race looks at its move since the last tick, and only at the next
## step of the course for that board: a mark further on cannot be rounded early. The geometry of
## every step is RoundingCheck's.
##
## The clock reads negative during the countdown: -prestart_s at start(), and the gun goes at 0.
## Crossings are timed between ticks (RoundingCheck's fraction), so two boards that cross in the
## same tick are told apart by which of them crossed first.
##
## The rules of version one (RD6): a board on the course side of the start line or its extensions
## at the gun is OCS ("on course side"); its start counts only once it has gone back behind the line
## and crossed it again. No right of way, no penalties.

enum Phase { PRE_START, RACING, FINISHED }

## How long the HUD's "wrong side" warning stays up after a wrong-side move, seconds.
const WRONG_SIDE_WARNING_S: float = 3.0


## One board's race.
class Board:
	var name: String = ""
	## Where the board is now and where it was at the last tick: the move between them is checked.
	var position: Vector2 = Vector2.ZERO
	var last_position: Vector2 = Vector2.ZERO
	var has_position: bool = false
	## The step of the course it is sailing to, as an index into steps(); steps().size() once it
	## has finished. It is also the number of steps it has completed.
	var next_step: int = 0
	## The race time at each step it completed, seconds.
	var splits: PackedFloat32Array = PackedFloat32Array()
	## -1 while it races.
	var finish_time_s: float = -1.0
	var ocs: bool = false
	## The race time until which its "wrong side" warning shows.
	var wrong_side_until_s: float = -INF


## The race ends this long after the first board finishes (seconds), if not every board is in.
var finish_window_s: float = 60.0
## The race ends at this race time whatever happens, seconds.
var time_limit_s: float = 1200.0
var course: Course
## How many times the steps between the start and the finish are sailed.
var laps: int = 1
## How long the countdown is, seconds.
var prestart_s: float = 60.0

var _steps: Array[RaceStep] = []
var _boards: Array[Board] = []
var _phase: Phase = Phase.PRE_START
## True once start() was called.
var _started: bool = false
## The race clock, seconds: negative during the countdown.
var _clock_s: float = 0.0
## When the first board finished, seconds; -1 until then.
var _first_finish_s: float = -1.0
## The race order, worked out once after the boards moved (see _order()): the boards' numbers
## first to last, and each board's place. A big fleet's HUD asks for the places every frame; a
## sort per question made 33 boards' fleet lines cost 0.3 s (F1 fleet_frame).
var _order_cache: Array[int] = []
var _places: PackedInt32Array = PackedInt32Array()
var _order_stale: bool = true


func _init(race_course: Course, lap_count: int = 1, prestart: float = 60.0, limit_s: float = 1200.0) -> void:
	course = race_course
	laps = maxi(lap_count, 1)
	prestart_s = maxf(prestart, 0.0)
	time_limit_s = limit_s
	_clock_s = -prestart_s
	_steps = _make_steps()


## Adds a board to the race; returns its number, which the other functions take.
func add_board(board_name: String) -> int:
	var board: Board = Board.new()
	board.name = board_name
	_boards.append(board)
	_order_stale = true
	return _boards.size() - 1


## Starts the countdown: the gun goes prestart_s from now.
func start() -> void:
	if _started:
		return
	_started = true
	_clock_s = -prestart_s
	if prestart_s == 0.0:
		# No countdown: the gun goes now, and whoever is over the line now is OCS.
		_phase = Phase.RACING
		for board: Board in _boards:
			if board.has_position and not _steps.is_empty():
				board.ocs = RoundingCheck.over_line_m(board.position, _steps[0].points[0], _steps[0].points[1], _steps[0].in_dir) >= 0.0


## Where a board is now (game X, Z, metres). Call it for every board, then step(), every tick.
func update_board(index: int, position: Vector2) -> void:
	var board: Board = _boards[index]
	if not board.has_position:
		board.last_position = position
		board.has_position = true
	board.position = position
	_order_stale = true


## Moves the race clock on by dt seconds and checks every board's move since the last step().
## Before start() and after the race has ended nothing is checked; the boards may sail about.
func step(dt: float) -> void:
	if _started and _phase != Phase.FINISHED and dt > 0.0:
		var from_s: float = _clock_s
		var to_s: float = _clock_s + dt
		for board: Board in _boards:
			if board.has_position:
				_check_move(board, from_s, to_s)
		_clock_s = to_s
		if _phase == Phase.PRE_START and _clock_s >= 0.0:
			_phase = Phase.RACING
		if _phase == Phase.RACING and _is_over():
			_phase = Phase.FINISHED
	for board: Board in _boards:
		board.last_position = board.position


# ---------------------------------------------------------------- the race

func phase() -> Phase:
	return _phase


## True once the countdown has been started.
func is_started() -> bool:
	return _started


## Seconds to the gun: prestart_s before start(), 0 from the gun on.
func countdown_s() -> float:
	return maxf(-_clock_s, 0.0)


## The race clock, seconds: 0 before the gun. It stops when the race ends.
func race_time_s() -> float:
	return maxf(_clock_s, 0.0)


## The race clock including the countdown, seconds: negative before the gun.
func clock_s() -> float:
	return _clock_s


## The steps of the race in the order they are sailed: the course's order with the steps between the
## start and the finish sailed `laps` times.
func steps() -> Array[RaceStep]:
	return _steps


func board_count() -> int:
	return _boards.size()


func board_name(index: int) -> String:
	return _boards[index].name


## Where a board is (game X, Z, metres), as update_board() last said: what a skipper sees of the
## other boards on the water.
func board_position(index: int) -> Vector2:
	return _boards[index].position


# ---------------------------------------------------------------- one board

## The step a board is sailing to (an index into steps()); steps().size() once it has finished.
## It is also the number of steps it has completed.
func next_step_index(index: int) -> int:
	return _boards[index].next_step


## The step a board is sailing to; null once it has finished.
func next_step(index: int) -> RaceStep:
	var number: int = _boards[index].next_step
	return _steps[number] if number < _steps.size() else null


## The name of the step a board is sailing to, for the HUD: "start", "mark 1", "gate 4S/4P",
## "finish"; "" once it has finished.
func next_step_name(index: int) -> String:
	var step: RaceStep = next_step(index)
	return step.name if step != null else ""


## Where the HUD's arrow points for a board: its next mark, or the middle of its next line. Once it
## has finished, the middle of the finish line.
func next_target(index: int) -> Vector2:
	var step: RaceStep = next_step(index)
	if step == null:
		return _steps[-1].target()
	return step.target()


## How far a board is from its next step, metres: from the mark, or from the nearest point of the
## line. 0 once it has finished.
func distance_to_next_m(index: int) -> float:
	var step: RaceStep = next_step(index)
	if step == null:
		return 0.0
	return step.distance_from(_boards[index].position)


## A board's place, 1 for the first: the boards that have finished by their finish time, then the
## others by the steps they have completed and then by their distance to the next step. A tie
## goes to the board added first.
func place(index: int) -> int:
	_order()
	return _places[index]


## The boards' numbers in race order, the first first (a copy: the caller may change it).
func race_order() -> Array[int]:
	return _order().duplicate()


## True while a board is over the start line early: before the gun while it is on the course side,
## and from the gun until it has gone back behind the line.
func is_ocs(index: int) -> bool:
	return _boards[index].ocs


## The race time at each step a board has completed, seconds.
func splits_s(index: int) -> PackedFloat32Array:
	return _boards[index].splits


## A board's race time at the finish line, seconds; -1 while it races.
func finish_time_s(index: int) -> float:
	return _boards[index].finish_time_s


func is_finished(index: int) -> bool:
	return _boards[index].finish_time_s >= 0.0


## True for WRONG_SIDE_WARNING_S after a board went round or past its next mark on the wrong side.
func wrong_side_warning(index: int) -> bool:
	return _clock_s < _boards[index].wrong_side_until_s


## The results in finishing order; the boards that did not finish last, by how far they got.
func results() -> Array[RaceResult]:
	var list: Array[RaceResult] = []
	var order: Array[int] = _order()
	if order.is_empty():
		return list
	var winner_s: float = _boards[order[0]].finish_time_s
	for rank: int in order.size():
		var board: Board = _boards[order[rank]]
		var result: RaceResult = RaceResult.new()
		result.name = board.name
		result.index = order[rank]
		result.place = rank + 1
		result.finished = board.finish_time_s >= 0.0
		result.finish_time_s = board.finish_time_s
		result.gap_s = board.finish_time_s - winner_s if result.finished else -1.0
		result.splits = board.splits.duplicate()
		result.steps_done = board.next_step
		result.steps_total = _steps.size()
		list.append(result)
	return list


# ---------------------------------------------------------------- checking the moves

## Checks a board's move during the tick from one race time to the next against its next step.
func _check_move(board: Board, from_s: float, to_s: float) -> void:
	if board.next_step >= _steps.size():
		return  # finished: it sails on, and nothing is checked
	var step: RaceStep = _steps[board.next_step]
	if step.kind == RaceStep.Kind.START:
		_check_start(board, step, from_s, to_s)
		return
	var outcome: RoundingCheck.Outcome = RoundingCheck.check(step, board.last_position, board.position)
	if outcome.wrong_side:
		board.wrong_side_until_s = to_s + WRONG_SIDE_WARNING_S
	if outcome.done:
		_complete_step(board, lerpf(from_s, to_s, outcome.fraction))


## The start. Before the gun a board on the course side of the line is over early, and may still
## go back. At the gun a board on the course side is OCS. An OCS board clears itself by going back
## behind the line; any other board starts when it crosses the line forward after the gun.
func _check_start(board: Board, step: RaceStep, from_s: float, to_s: float) -> void:
	if to_s < 0.0:
		board.ocs = _over_start_line(step, board.position)
		return
	# How much of this tick's move was made before the gun: none, unless the gun went during it.
	var before_gun: float = 0.0
	if from_s < 0.0:
		before_gun = -from_s / (to_s - from_s)
		board.ocs = _over_start_line(step, board.last_position.lerp(board.position, before_gun))
	if board.ocs:
		if not _over_start_line(step, board.position):
			board.ocs = false  # back behind the line: from now on a crossing counts
		return
	var fraction: float = RoundingCheck.across_line(board.last_position, board.position, step.points[0], step.points[1], step.in_dir)
	# Only a crossing after the gun is a start (no crossing gives -1).
	if fraction >= before_gun:
		_complete_step(board, lerpf(from_s, to_s, fraction))


## True on the course side of the start line or its extensions, or on the line.
func _over_start_line(step: RaceStep, position: Vector2) -> bool:
	return RoundingCheck.over_line_m(position, step.points[0], step.points[1], step.in_dir) >= 0.0


func _complete_step(board: Board, at_s: float) -> void:
	board.splits.append(at_s)
	board.next_step += 1
	_order_stale = true
	if board.next_step == _steps.size():
		board.finish_time_s = at_s
		if _first_finish_s < 0.0 or at_s < _first_finish_s:
			_first_finish_s = at_s


## The race is over when every board has finished, finish_window_s after the first finisher, or at
## the time limit.
func _is_over() -> bool:
	if _clock_s >= time_limit_s:
		return true
	if _first_finish_s < 0.0:
		return false
	if _clock_s >= _first_finish_s + finish_window_s:
		return true
	for board: Board in _boards:
		if board.finish_time_s < 0.0:
			return false
	return true


## The boards' numbers in race order (see place()), worked out again only when a board has moved or
## completed a step since the last time: at most once per tick however often the HUD asks. Each
## board's distance to its next step is measured once, before the sort, not at every comparison.
func _order() -> Array[int]:
	if not _order_stale:
		return _order_cache
	var distances: PackedFloat64Array = PackedFloat64Array()
	var order: Array[int] = []
	for i: int in _boards.size():
		order.append(i)
		distances.append(distance_to_next_m(i))
	order.sort_custom(func(a: int, b: int) -> bool: return _is_ahead(a, b, distances))
	_places.resize(order.size())
	for rank: int in order.size():
		_places[order[rank]] = rank + 1
	_order_cache = order
	_order_stale = false
	return _order_cache


## True when board a is ahead of board b in the race; `distances` holds every board's distance
## to its next step.
func _is_ahead(a: int, b: int, distances: PackedFloat64Array) -> bool:
	var board_a: Board = _boards[a]
	var board_b: Board = _boards[b]
	var finished_a: bool = board_a.finish_time_s >= 0.0
	var finished_b: bool = board_b.finish_time_s >= 0.0
	if finished_a != finished_b:
		return finished_a
	if finished_a:
		if board_a.finish_time_s != board_b.finish_time_s:
			return board_a.finish_time_s < board_b.finish_time_s
		return a < b
	if board_a.next_step != board_b.next_step:
		return board_a.next_step > board_b.next_step
	var distance_a: float = distances[a]
	var distance_b: float = distances[b]
	if distance_a != distance_b:
		return distance_a < distance_b
	return a < b


# ---------------------------------------------------------------- the steps

## The race's steps from the course: the lines with their ends, the gates with their two marks, the
## marks with their sides, and the directions of the legs in and out of each.
func _make_steps() -> Array[RaceStep]:
	var result: Array[RaceStep] = []
	for id: String in [CourseMark.START_BOAT, CourseMark.START_PIN, CourseMark.FINISH_BOAT, CourseMark.FINISH_PIN]:
		if course.mark(id) == null:
			push_error("A race needs a start line and a finish line, and this course has no %s." % id)
			return result
	var order: PackedStringArray = _lap_order()
	for i: int in order.size():
		var here: Vector2 = course.point_of(order[i])
		var before: Vector2 = course.point_of(order[i - 1]) if i > 0 else here
		var after: Vector2 = course.point_of(order[i + 1]) if i < order.size() - 1 else here
		var step: RaceStep = RaceStep.new()
		step.id = order[i]
		step.in_dir = (here - before).normalized()
		step.out_dir = (after - here).normalized()
		if order[i] == "Start":
			step.kind = RaceStep.Kind.START
			step.name = "start"
			step.points = PackedVector2Array([course.mark(CourseMark.START_BOAT).position, course.mark(CourseMark.START_PIN).position])
			# Nothing arrives at the start: it is crossed the way the first leg goes.
			step.in_dir = step.out_dir
		elif order[i] == "Finish":
			step.kind = RaceStep.Kind.FINISH
			step.name = "finish"
			step.points = PackedVector2Array([course.mark(CourseMark.FINISH_BOAT).position, course.mark(CourseMark.FINISH_PIN).position])
			# Nothing leaves the finish: the last leg's direction.
			step.out_dir = step.in_dir
		elif order[i].contains("/"):
			step.kind = RaceStep.Kind.GATE
			step.name = "gate " + order[i]
			var ids: PackedStringArray = order[i].split("/")
			step.points = PackedVector2Array([course.mark(ids[0]).position, course.mark(ids[1]).position])
		else:
			step.kind = RaceStep.Kind.MARK
			step.name = "mark " + order[i]
			var mark: CourseMark = course.mark(order[i])
			step.points = PackedVector2Array([mark.position])
			step.side = mark.side
			if step.side == CourseMark.Rounding.NONE:
				# A mark without a side (a course file edited by hand): the side the course bends round it.
				step.side = Course.natural_side(before, here, after)
		result.append(step)
	return result


## The order the race sails: the course's own order with the steps between the start and the finish
## sailed `laps` times. A step naming a mark the course does not have is left out (as Course.legs()
## does), and where a lap ends at the step the next one begins with, that step is sailed once.
func _lap_order() -> PackedStringArray:
	var inner: PackedStringArray = PackedStringArray()
	for id: String in course.sequence.split("-"):
		if id != "Start" and id != "Finish" and _marks_exist(id):
			inner.append(id)
	var order: PackedStringArray = PackedStringArray(["Start"])
	for _lap: int in laps:
		for id: String in inner:
			if id != order[-1]:
				order.append(id)
	order.append("Finish")
	return order


## True when every mark a step names ("1", or both of "4S/4P") is on the course.
func _marks_exist(id: String) -> bool:
	for part: String in id.split("/"):
		if course.mark(part) == null:
			return false
	return true
