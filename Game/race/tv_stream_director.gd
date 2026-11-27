class_name TvStreamDirector
extends RefCounted
## The TV director set to the real World Tour slalom stream (TvCamera's default; its numbers are
## TvDirectorConfig, Game/config/tv_director.tres; the report: Documentation/reports/broadcast/
## tv_director_stream.md). What the stream does, phase by phase, measured on nine heats:
## - before the start: the beach cam wide and still on the fleet milling and on the line, now and
##   then a drone on the line;
## - the start (10 s before the gun to 12 s after it): the beach cam wide on the line, then 1 to 4 s
##   before the gun the low drone at the end of the line, the fleet sailing at it (the view down the
##   line, the line drawn); just after the gun a drone runs with the fleet off the line for 10 to 14 s;
## - the race: drones that travel with the boards (from behind and to the side, from ahead and to the
##   side, from the side), on the leader or the lead group most, then the pack and the fleet, and now
##   and then the beach cam tight on the leader; takes of 8 s in the middle, a quarter under 5 s and a
##   quarter over 12 s. A drone waits at each mark: the cut comes 2 to 5 s before the leader arrives
##   and holds on the gybe; often the chasers at the same mark next, then back to the leader. At the
##   finish the drone flies through the line with the winner, or a drone hovers side-on at the line and
##   holds the finish area while the places come in;
## - after the race: the long lens close on the winner sailing in, a drone with the finishers, a high
##   drone pulling out.
## The stream never looks straight down and does not circle: the overhead drone and the helicopter are
## by hand only (keys 9 and 5). The phase comes from the race clock (heat_phase()); seconds are the
## picture's (TvCamera.step()). Plain-number helpers for the tests: heat_phase(), draw_picture(),
## pack_weights(), lead_group_size().

enum Phase { PRE_START, START, RACE, AFTER_RACE }

const PHASE_NAMES: PackedStringArray = ["pre_start", "start", "race", "after_race"]

var tv: TvCamera = null
var config: TvDirectorConfig = null
var _rng: RandomNumberGenerator = null

## The phase on the screen; false until the first step looked at the race.
var phase: Phase = Phase.PRE_START
var _entered: bool = false
## Seconds left in the take on the screen (a free take; the start's, the marks' and the finish's keep
## their own time).
var _left_s: float = 0.0
## The start: when the line drone comes and when the runner (race clock, s), how long the runner runs,
## and how far the sequence is (0 the beach cam on the line, 1 the line drone, 2 the runner).
var _line_at_s: float = -3.0
var _runner_at_s: float = 1.0
var _runner_s: float = 11.0
var _start_step: int = 0
## The marks: the rounding shown for each board (its step number at that mark), each mark's cut
## before the leader arrives (s, by step number), the mark on the screen (its step number, -1 none),
## its take's length and when its board rounded (take age, s).
var _shown: Dictionary[int, int] = {}
var _cut_before_s: Dictionary[int, float] = {}
var _mark_step: int = -1
var _mark_take_s: float = 0.0
var _rounded_at_s: float = -1.0
## The nearest the board of a mark's take has come to the buoy, m.
var _mark_nearest_m: float = INF
## The chasers awaited at a mark after the leader's take there (its step number, -1 none), for how
## much longer (s), the marks whose chasers were weighed already; then back to the leader.
var _chasers_step: int = -1
var _chasers_left_s: float = 0.0
var _chasers_weighed: Dictionary[int, bool] = {}
var _back_to_leader: bool = false
## The finish: 0 not yet, 1 the drone flies through the line with the winner, 2 the hover holds the
## finish area, 3 done. Its cut before the leader finishes (s).
var _finish: int = 0
var _finish_cut_s: float = 3.0
## After the race: whether the winner's close-up has been on.
var _winner_shown: bool = false
## For screenshots and checks (--tv_only=<shot>, e.g. FRONT_SIDE): the director takes this camera
## whenever the phase or the mark has a picture made by it; -1: the stream's mix.
var only_shot: int = -1
## The places as last seen and when each board last gained one (seconds of the director's clock).
var _places: Dictionary[int, int] = {}
var _gained_at: Dictionary[int, float] = {}
var _clock_s: float = 0.0


func _init(camera: TvCamera, numbers: TvDirectorConfig, rng: RandomNumberGenerator) -> void:
	tv = camera
	config = numbers
	_rng = rng


## T: the director takes over; the phase's pictures start afresh.
func begin() -> void:
	_entered = false
	_left_s = 0.0


## A new race: every sequence from the start again.
func new_race() -> void:
	_entered = false
	_left_s = 0.0
	_shown.clear()
	_cut_before_s.clear()
	_mark_step = -1
	_chasers_step = -1
	_chasers_weighed.clear()
	_back_to_leader = false
	_finish = 0
	_winner_shown = false
	_places.clear()
	_gained_at.clear()


## The heat's phase at a moment: before the countdown and until start_from_s the pre-start, then the
## start until start_until_s after the gun, then the race until the race has ended, then after the
## race (until the next countdown makes a new race). Plain numbers, for the tests.
static func heat_phase(started: bool, clock_s: float, finished: bool, start_from_s: float, start_until_s: float) -> Phase:
	if finished:
		return Phase.AFTER_RACE
	if not started or clock_s < start_from_s:
		return Phase.PRE_START
	if clock_s <= start_until_s:
		return Phase.START
	return Phase.RACE


## The picture for a key by hand (TvCamera.hold()): the chase drone (7) and the drone beside the board
## (8) as the race's pictures on the front, the view down the start line (6) as the start's line
## drone; null for the helicopter (5) and the overhead drone (9), which stay the 12 November ones.
func hand_picture(shot: TvCamera.Shot) -> TvPicture:
	if shot == TvCamera.Shot.COMMITTEE:
		return config.start_line_drone
	if config.race != null:
		return config.race.picture_of(shot, "front")
	return null


# ---------------------------------------------------------------- every step

## Every frame while the director cuts (seconds of the picture).
func step(dt: float) -> void:
	var race: RaceSim = tv.runner.race
	if race == null or tv.runner.watch_order().is_empty():
		return
	_clock_s += dt
	_left_s -= dt
	_chasers_left_s -= dt
	_note_places(race)
	if tv.view_lost:
		_cut_away_from_land(race)
	var now: Phase = heat_phase(race.is_started(), race.clock_s(), race.phase() == RaceSim.Phase.FINISHED, config.start_from_s, config.start_until_s)
	if now != phase or not _entered:
		_enter(now, race)
	match phase:
		Phase.PRE_START:
			_free(race, config.pre_start)
		Phase.START:
			_start(race)
		Phase.RACE:
			_race(race)
		Phase.AFTER_RACE:
			_after_race(race)


func _enter(now: Phase, race: RaceSim) -> void:
	var first: bool = not _entered
	phase = now
	_entered = true
	match now:
		Phase.START:
			var times: Vector3 = start_times(config, _rng)
			_line_at_s = times.x
			_runner_at_s = times.y
			_runner_s = times.z
			_start_step = 0
			# The beach cam wide on the line, unless it is on the screen already.
			var on_the_line: bool = tv.picture != null and tv.picture.shot == TvCamera.Shot.BEACH_WIDE and tv.picture.on == "line"
			if not on_the_line:
				_cut_on_the_line(config.start_beach, race, INF)
		Phase.RACE:
			if first or _start_step < 2:
				_left_s = 0.0  # no runner on the screen: a story at once
		_:
			_left_s = 0.0


## The start's sequence for one race, drawn from the stream's spread: Vector3(when the line drone comes,
## when the runner comes, both on the race clock (s, the gun at 0), how long the runner runs (s)): the
## line drone a few seconds before the gun, the runner just after it.
static func start_times(numbers: TvDirectorConfig, rng: RandomNumberGenerator) -> Vector3:
	var line_at_s: float = -TvFraming.from_spread(numbers.line_drone_before_gun_s, rng.randfn(), true, 0.5, 9.0)
	var runner_at_s: float = TvFraming.from_spread(numbers.runner_after_gun_s, rng.randfn(), true, 0.2, numbers.runner_latest_s)
	var runner_s: float = TvFraming.from_spread(numbers.runner_take_s, rng.randfn(), true, 4.0, 18.0)
	return Vector3(line_at_s, runner_at_s, runner_s)


## The start: the beach cam on the line, the line drone, the runner (it carries on into the race).
func _start(race: RaceSim) -> void:
	var clock_s: float = race.clock_s()
	if _start_step < 1 and clock_s >= _line_at_s and clock_s < _runner_at_s:
		_start_step = 1
		_cut_on_the_line(config.start_line_drone, race, INF)
	elif _start_step < 2 and clock_s >= _runner_at_s:
		_start_step = 2
		_left_s = _runner_s
		var runner: TvPicture = draw_picture(config.start_runners, null, _rng.randf())
		_cut(runner, _first_racing(race), _runner_s)


## A picture on the start line, about the board nearest its middle (the race card names it).
func _cut_on_the_line(picture: TvPicture, race: RaceSim, take_s: float) -> void:
	var board: int = tv.board_nearest(race, tv.runner.course.start_middle()) if tv.runner.course != null else _first_racing(race)
	_cut(picture, board, take_s)


func _race(race: RaceSim) -> void:
	if _at_the_finish(race):
		return
	if _at_a_mark(race):
		return
	if _left_s > 0.0 and tv.runner.watch_order().has(tv.focus):
		return
	if tv.runner.watch_order().has(tv.focus) and _leader_due_within(race, config.hold_for_mark_s):
		return  # the take runs on: the cut to the mark comes in a moment
	_free(race, config.race)


## Whether the leader's cut to its mark (or the finish) is due within this many seconds.
func _leader_due_within(race: RaceSim, seconds: float) -> bool:
	var leader: int = _first_racing(race)
	if race.is_finished(leader):
		return false
	var next: RaceStep = race.next_step(leader)
	if next == null:
		return false
	var cut_before_s: float = _finish_cut_s if next.kind == RaceStep.Kind.FINISH else _cut_before(race.next_step_index(leader))
	if next.kind != RaceStep.Kind.FINISH and _shown.get(leader, -1) == race.next_step_index(leader):
		return false
	return _seconds_to_next(race, leader) - cut_before_s < seconds


func _after_race(race: RaceSim) -> void:
	if not _winner_shown:
		_winner_shown = true
		var take_s: float = TvFraming.from_spread(config.after_winner_take_s, _rng.randfn(), false, 10.0, 45.0)
		_left_s = take_s
		_cut(config.after_winner, race.race_order()[0], take_s)
		return
	_free(race, config.after_race)


# ---------------------------------------------------------------- free takes

## When the take's time is up (or its board has gone): a new picture from the phase's mix, drawn by
## the stream's shares, never the one just on the screen; after the chasers at a mark, the leader.
func _free(race: RaceSim, mix: TvPhaseMix) -> void:
	if mix == null or (_left_s > 0.0 and tv.runner.watch_order().has(tv.focus)):
		return
	var only_on: String = "front" if _back_to_leader else ""
	_back_to_leader = false
	var pool: Array[TvPicture] = _pool(mix.pictures)
	if not _fleet_together(race):
		# A spread fleet is no picture: its pictures wait for the next race's first reach.
		var together_only: Array[TvPicture] = []
		for picture: TvPicture in pool:
			if picture.on != "fleet":
				together_only.append(picture)
		pool = together_only
	var next: TvPicture = draw_picture(pool, tv.picture, _rng.randf(), only_on)
	if next == null:
		return
	var board: int = _subject(race, next.on)
	if board < 0:
		next = draw_picture(mix.pictures, tv.picture, _rng.randf(), "front")
		board = _subject(race, "front")
	if next == null or board < 0:
		return
	var take_s: float = TvFraming.from_spread(mix.take_s, _rng.randfn(), true, mix.shortest_s, mix.longest_s)
	_left_s = take_s
	_cut(next, board, take_s)


## The pictures to draw from: all of them, or with --tv_only those made by that camera (when there are any).
func _pool(pictures: Array[TvPicture]) -> Array[TvPicture]:
	if only_shot < 0:
		return pictures
	var only: Array[TvPicture] = []
	for picture: TvPicture in pictures:
		if picture.shot == only_shot:
			only.append(picture)
	return only if not only.is_empty() else pictures


## A picture drawn from a list by the stream's shares (weight_pct): `dice` from 0 to 1, never `last`
## (unless it is the only one), only pictures on `only_on` when it is given. Null for an empty list.
## Plain numbers in, so the tests can drive it.
static func draw_picture(pictures: Array[TvPicture], last: TvPicture, dice: float, only_on: String = "") -> TvPicture:
	var weights: PackedFloat32Array = PackedFloat32Array()
	var total: float = 0.0
	for picture: TvPicture in pictures:
		var weight: float = picture.weight_pct
		if picture == last or (only_on != "" and picture.on != only_on):
			weight = 0.0
		weights.append(weight)
		total += weight
	if total <= 0.0:
		return pictures[0] if not pictures.is_empty() else null
	var left: float = clampf(dice, 0.0, 0.999999) * total
	for i: int in pictures.size():
		left -= weights[i]
		if left < 0.0:
			return pictures[i]
	return pictures[pictures.size() - 1]


## The board a picture on a subject is about: the front (the first board still racing; after the race
## the winner), the pack (a fight, a board that gained a place, the front of the rest; never the lead
## group), the fleet (the board nearest the middle of the boats on the water), the line (the board
## nearest the start line's middle). -1 when there is none (the pack of a fleet that is all front).
func _subject(race: RaceSim, on: String) -> int:
	match on:
		"pack":
			return _pack_board(race)
		"fleet":
			var middle: Vector3 = tv.fleet_middle(0.0)
			return tv.board_nearest(race, Vector2(middle.x, middle.z))
		"line":
			return tv.board_nearest(race, tv.runner.course.start_middle()) if tv.runner.course != null else _first_racing(race)
	if phase == Phase.AFTER_RACE:
		return race.race_order()[0]
	return _first_racing(race)


## Whether the boards still racing are together (all within fleet_together_m of their middle).
func _fleet_together(race: RaceSim) -> bool:
	var racing: PackedVector2Array = PackedVector2Array()
	for index: int in tv.runner.watch_order():
		if not race.is_finished(index) and not race.is_retired(index):
			racing.append(race.board_position(index))
	if racing.size() < 2:
		return false
	var middle: Vector2 = Vector2.ZERO
	for at: Vector2 in racing:
		middle += at
	middle /= racing.size()
	for at: Vector2 in racing:
		if at.distance_to(middle) > config.fleet_together_m:
			return false
	return true


## The first board in race order that is still racing (the winner once every board is in).
func _first_racing(race: RaceSim) -> int:
	var order: Array[int] = tv.runner.watch_order()
	for index: int in order:
		if not race.is_finished(index) and not race.is_retired(index):
			return index
	return order[0]


## A board of the pack: drawn by pack_weights(), the lead group left out.
func _pack_board(race: RaceSim) -> int:
	var order: Array[int] = tv.runner.watch_order()
	var positions: PackedVector2Array = PackedVector2Array()
	var finished: PackedByteArray = PackedByteArray()
	var gained: PackedByteArray = PackedByteArray()
	var late: PackedByteArray = PackedByteArray()
	var racing: bool = race.phase() == RaceSim.Phase.RACING
	for index: int in order:
		positions.append(race.board_position(index))
		finished.append(1 if race.is_finished(index) or race.is_retired(index) else 0)
		gained.append(1 if _gained_at.has(index) and _clock_s - _gained_at[index] < config.gained_s else 0)
		var next: RaceStep = race.next_step(index)
		late.append(1 if racing and next != null and next.kind == RaceStep.Kind.START else 0)
	var front: int = lead_group_size(positions, finished, config.lead_group_m, config.lead_group_most)
	var weights: PackedFloat32Array = pack_weights(positions, finished, gained, late, front, config.close_m)
	var total: float = 0.0
	for weight: float in weights:
		total += weight
	if total <= 0.0:
		return -1
	return order[_rng.rand_weighted(weights)]


## How many boards make the lead group: the first racing board and those after it in race order that
## are within lead_m of it, at most `most`. Finished boards are left out of the counting (0 when none
## is racing). Plain numbers in, race order.
static func lead_group_size(positions: PackedVector2Array, finished: PackedByteArray, lead_m: float, most: int) -> int:
	var first: int = -1
	for i: int in positions.size():
		if finished[i] == 0:
			first = i
			break
	if first < 0:
		return positions.size()
	var size: int = first + 1
	for i: int in range(first + 1, positions.size()):
		if size - first >= most or finished[i] != 0 or positions[i].distance_to(positions[first]) > lead_m:
			break
		size = i + 1
	return size


## What each board is worth as the pack's story (race order): nothing for the lead group (the first
## `front`) and the finished; for the rest one, more for a fight (another racing board within close_m)
## and a place just gained, and more the nearer the front; a board still to start after the gun
## (`late`: back over the line, or a late starter) a tenth. Plain numbers in.
static func pack_weights(positions: PackedVector2Array, finished: PackedByteArray, gained: PackedByteArray, late: PackedByteArray, front: int, close_m: float) -> PackedFloat32Array:
	var weights: PackedFloat32Array = PackedFloat32Array()
	for i: int in positions.size():
		if i < front or finished[i] != 0:
			weights.append(0.0)
			continue
		var weight: float = 1.0 + 2.0 / float(i - front + 1)
		for j: int in positions.size():
			if j != i and finished[j] == 0 and positions[i].distance_to(positions[j]) < close_m:
				weight += 3.0
				break
		if gained[i] != 0:
			weight += 3.0
		if late[i] != 0:
			weight *= 0.1
		weights.append(weight)
	return weights


# ---------------------------------------------------------------- the marks

## The marks: a drone already waits at the buoy and the cut comes a few seconds before the leader gets
## there; the take holds on the gybe; then often the chasers at the same mark, and back to the leader.
## True while a mark's take is on or when it cut to one.
func _at_a_mark(race: RaceSim) -> bool:
	if _mark_step >= 0:
		if _mark_goes_on(race):
			return true
		_after_a_mark()
	var leader: int = _first_racing(race)
	if not race.is_finished(leader) and _due_at_its_mark(race, leader):
		_cut_to_the_mark(race, leader)
		return true
	if _chasers_step >= 0:
		if _chasers_left_s <= 0.0:
			_chasers_step = -1
		elif tv.take_age_s() >= config.shortest_take_s:
			for index: int in tv.runner.watch_order():
				if race.is_finished(index) or race.next_step_index(index) != _chasers_step or _shown.get(index, -1) == _chasers_step:
					continue
				if _seconds_to_next(race, index) <= _cut_before(_chasers_step):
					_chasers_step = -1
					_back_to_leader = true
					_cut_to_the_mark(race, index)
					return true
	return false


## Whether a board is due at its next mark: the mark's rounding not shown yet, and the board this
## mark's cut-before seconds or less away.
func _due_at_its_mark(race: RaceSim, index: int) -> bool:
	if not TvCamera.next_is_a_mark(race, index):
		return false
	var step_number: int = race.next_step_index(index)
	return _shown.get(index, -1) != step_number and _seconds_to_next(race, index) <= _cut_before(step_number)


## Seconds before a board reaches its next step, at its speed (at least 3 m/s).
func _seconds_to_next(race: RaceSim, index: int) -> float:
	var node: WindsurferNode = tv.runner.board_node(index)
	var speed_ms: float = node.telemetry().speed_ms if node != null else 0.0
	return race.distance_to_next_m(index) / maxf(speed_ms, 3.0)


## A mark's cut before the leader arrives, drawn once per mark.
func _cut_before(step_number: int) -> float:
	if not _cut_before_s.has(step_number):
		_cut_before_s[step_number] = _rng.randf_range(config.mark_cut_before_s.x, config.mark_cut_before_s.y)
	return _cut_before_s[step_number]


## The mark's drone on a board: the rounding is shown for it and for its group at the same mark.
func _cut_to_the_mark(race: RaceSim, index: int) -> void:
	var step_number: int = race.next_step_index(index)
	for other: int in tv.runner.watch_order():
		if race.next_step_index(other) == step_number and race.board_position(other).distance_to(race.board_position(index)) < config.lead_group_m:
			_shown[other] = step_number
	_mark_take_s = TvFraming.from_spread(config.mark_take_s, _rng.randfn(), true, config.mark_shortest_s, config.mark_longest_s)
	var next: TvPicture = draw_picture(_pool(config.mark_pictures), null, _rng.randf())
	_cut(next, index, _mark_take_s, step_number)
	_rounded_at_s = -1.0
	_mark_nearest_m = INF


## A mark's take goes on for its drawn length and until its board has rounded and a little more, never
## past mark_longest_s.
func _mark_goes_on(race: RaceSim) -> bool:
	if tv.focus < 0:
		return false
	var age_s: float = tv.take_age_s()
	var to_buoy_m: float = race.board_position(tv.focus).distance_to(tv.mark_point())
	_mark_nearest_m = minf(_mark_nearest_m, to_buoy_m)
	# Gybed: the race has the rounding, or the board came near the buoy and is going away again.
	var gybed: bool = _mark_nearest_m < config.mark_near_m and to_buoy_m > _mark_nearest_m + 5.0
	var rounded: bool = race.is_finished(tv.focus) or race.next_step_index(tv.focus) > _mark_step or gybed
	if rounded and _rounded_at_s < 0.0:
		_rounded_at_s = age_s
	return mark_take_goes_on(age_s, _rounded_at_s, _mark_take_s, config.mark_longest_s, config.mark_after_rounding_s)


## Whether a take at a mark goes on: at its age (s), its board rounded at that age (negative: not yet),
## drawn to last take_s, never past longest_s, and until after_s after the rounding. Plain numbers in.
static func mark_take_goes_on(age_s: float, rounded_at_s: float, take_s: float, longest_s: float, after_s: float) -> bool:
	if age_s >= longest_s:
		return false
	if rounded_at_s < 0.0:
		return true
	return age_s < take_s or age_s - rounded_at_s < after_s


## A mark's take has ended: the chasers at the same mark come next (often), once per mark.
func _after_a_mark() -> void:
	if _mark_step >= 0 and not _chasers_weighed.has(_mark_step):
		_chasers_weighed[_mark_step] = true
		if _rng.randf() < config.chasers_at_mark_chance:
			_chasers_step = _mark_step
			_chasers_left_s = config.chasers_within_s
	_mark_step = -1
	_left_s = 0.0


# ---------------------------------------------------------------- the finish

## The finish: when the leader is a few seconds from the line, either the drone on the screen that
## follows it flies through the line with it, or the drone hovering side-on at the line takes over and
## holds the finish area while the places come in. True while that is on.
func _at_the_finish(race: RaceSim) -> bool:
	if race.phase() != RaceSim.Phase.RACING or tv.runner.course == null or tv.runner.course.mark(CourseMark.FINISH_BOAT) == null:
		return false
	match _finish:
		1:
			var winner: int = race.race_order()[0]
			if race.is_finished(winner) or tv.take_age_s() > config.mark_longest_s * 2.0:
				_hover(race)
			return true
		2:
			if _left_s > 0.0:
				return true
			_finish = 3
			return false
		3:
			return false
	var leader: int = race.race_order()[0]
	if race.is_finished(leader):
		_finish = 3  # the director came in after the winner finished
		return false
	var next: RaceStep = race.next_step(leader)
	if next == null or next.kind != RaceStep.Kind.FINISH:
		return false
	if _finish_cut_s <= 0.0 or _finish_cut_s > config.finish_cut_before_s.y:
		_finish_cut_s = _rng.randf_range(config.finish_cut_before_s.x, config.finish_cut_before_s.y)
	if _seconds_to_next(race, leader) > _finish_cut_s:
		return false
	var following: bool = tv.picture != null and tv.picture.move == "follows" and tv.focus == leader
	if following and _rng.randf() < config.finish_follow_through_chance:
		_finish = 1
		_left_s = INF
		return true
	_hover(race)
	return true


## The drone hovering side-on at the finish line, on the next board to come in (the winner once all
## are in).
func _hover(race: RaceSim) -> void:
	_finish = 2
	var take_s: float = TvFraming.from_spread(config.finish_take_s, _rng.randfn(), true, config.finish_shortest_s, config.finish_longest_s)
	_left_s = take_s
	_cut(config.finish_picture, _first_racing(race), take_s)


# ---------------------------------------------------------------- helpers

## A cut to a picture on a board (a mark's picture at that mark's step number; any other cut ends a
## mark's take). When land stands between that picture's camera and what it films (the beach cam on a
## coast, a drone off a headland), a drone picture on the same subject instead (the lead's rule, 27
## November 2026: never a picture through land).
func _cut(next: TvPicture, board: int, take_s: float, mark_step: int = -1) -> void:
	if next == null or board < 0:
		return
	_mark_step = mark_step
	if tv.cut_to(next, board, take_s, mark_step):
		return
	var instead: TvPicture = _drone_instead_of(next, mark_step >= 0)
	tv.cut_to(instead if instead != null else next, board, take_s, mark_step, true)


## A drone picture for a picture whose camera can't see its subject: at a mark another mark drone, on
## the line the line drone, otherwise a drone of the phase's mix on the same subject (the front when it
## has none), never the same picture.
func _drone_instead_of(blocked: TvPicture, at_a_mark: bool) -> TvPicture:
	var pool: Array[TvPicture] = []
	if at_a_mark:
		pool = config.mark_pictures
	elif blocked.on == "line":
		return config.start_line_drone if blocked != config.start_line_drone else null
	else:
		var mix: TvPhaseMix = config.mix_of(phase)
		pool = mix.pictures if mix != null else config.race.pictures
	var drones: Array[TvPicture] = []
	for picture: TvPicture in pool:
		if picture != blocked and not picture.is_lens_camera() and (picture.on == blocked.on or blocked.on == "mark"):
			drones.append(picture)
	if drones.is_empty():
		for picture: TvPicture in pool:
			if picture != blocked and not picture.is_lens_camera() and picture.on == "front":
				drones.append(picture)
	return draw_picture(drones, null, _rng.randf())


## Land has come between the camera on the screen and what it films: at the start the beach cam gives way
## to the line drone, at a mark the take ends, any other take ends now.
func _cut_away_from_land(race: RaceSim) -> void:
	tv.view_lost = false
	if phase == Phase.START and _start_step == 0:
		_start_step = 1
		_cut_on_the_line(config.start_line_drone, race, INF)
		return
	if _mark_step >= 0:
		_after_a_mark()
	if _finish == 2:
		_finish = 3
	_left_s = 0.0


## The places in race order now; a board that moved up while racing has gained a place.
func _note_places(race: RaceSim) -> void:
	if race.phase() != RaceSim.Phase.RACING:
		_places.clear()
		return
	var order: Array[int] = race.race_order()
	for place: int in order.size():
		var index: int = order[place]
		if _places.has(index) and place < _places[index] and not race.is_finished(index):
			_gained_at[index] = _clock_s
		_places[index] = place
