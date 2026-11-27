class_name RaceStory
extends RefCounted
## The race as a story for the commentator: it looks at the race again and again (look(), a RaceLook
## each time, the race clock in it) and says what has just happened, as the moments of BANK_FORMAT.md
## (RaceMoment): the fleet lining up, the gun, who started well or badly or over early, a lead change,
## an overtake, a board closing on the one ahead (a chase), two boards close together for a while (a
## fight), the front coming up to a mark, the gybe at a mark judged good, safe or bad, a fall, trouble
## without a fall (off the plane for long while the fleet planes, or places lost quickly), a near
## miss, airtime, the leader's last leg, a photo finish, the winner, the places, and the verdict after
## the race. (His reactions, wow and oh_no, are the director's: they come with a big moment.) The
## small talk also has the line a board takes (tactics: to windward or to leeward of the board beside
## it or of its straight line to the mark, in dirty wind), a race not yet decided late on (tension), a
## board on a run of places or long in the lead (form), and the day's wind and water (conditions; the
## story measures the wind's mean and the sea's wave height for the `wind_strong`, `wind_light`,
## `choppy` and `flat` needs). Between them quiet() offers the small talk that fills the time (who is on the screen, how
## fast, who leads, a rundown of the order, a filler, the camera, not sure who it is).
##
## A plain class with no nodes and the time passed in (the race clock of each look), so the tests can
## drive it with small made-up races. It never touches the race or the physics. The numbers that decide
## what counts as a chase, a fight, a good gybe ... are in CommentaryConfig. A new race needs a new story.
##
## How a gybe at a mark is judged: the rounding is watched from rounding_from_m before the mark until
## gybe_exit_s after the board's stern went through the wind (the gybe and the way out of it), or, when
## it does not gybe, gybe_wait_s after the race counted the mark: the speed it went in with, the least
## speed through the turn, the time it was off the plane, how near the mark it went (its nearest
## distance to the mark, or to the nearer end of a gate) and whether it fell. A rounding counts as a
## gybe when the board's stern went through the wind: its wind angle changed sides beyond
## gybe_twa_deg (from +170 to -175 degrees, say; a tack changes sides through 0). The sail's own flip
## comes later than that in the game's gybe, often after the watch, so it is not the measure. A
## rounding without a gybe (a bear-away at a windward mark, a head-up) gets no gybe line. Good: it kept good_kept
## of its speed, stayed on the plane and went in tight; bad: it all but stopped (less than bad_kept of
## its speed) or went wide; a fall is told as a fall; safe: the rest.

var config: CommentaryConfig

## The last look (null before the first: the first look only takes note, it tells nothing).
var _last: RaceLook = null
var _was_fallen: Dictionary[int, bool] = {}
## The order: each board's place as last seen and since when, and the place it has held (told).
var _seen_place: Dictionary[int, int] = {}
var _seen_since: Dictionary[int, float] = {}
var _held_place: Dictionary[int, int] = {}
var _leader: int = -1
var _leader_seen: int = -1
var _leader_since: float = 0.0
## When each board last gained a place (race seconds): a board on the move is talked about as fast.
var _gained_at: Dictionary[int, float] = {}
## The start: the pre-start times told, the gun, who was over the line at the gun, the start judged.
var _pre_start_told: int = 0
var _gun_told: bool = false
var _ocs_at_gun: Dictionary[int, bool] = {}
var _start_judged: bool = false
## The finish: the boards whose finish was told, when the winner crossed, the verdicts.
var _finish_told: Dictionary[int, bool] = {}
var _winner: int = -1
var _win_at_s: float = -1.0
var _after_win_told: bool = false
var _after_race_told: bool = false
var _last_leg_told: bool = false
## Pairs of boards (pair_key()): when each kind of moment was last told about them, and since when two
## boards have been close (a fight).
var _pair_told_at: Dictionary[String, float] = {}
var _close_since: Dictionary[String, float] = {}
## A chaser's gaps to the board ahead lately: (race seconds, metres, the board ahead).
var _gaps: Dictionary[int, PackedVector3Array] = {}
## The mark approach told: the step each board was told coming up to.
var _approach_told: Dictionary[int, int] = {}
## The roundings being watched, by board.
var _roundings: Dictionary[int, Rounding] = {}
## The boards' flights: since when each is in the air (-1: on the water), when it landed, how long it flew.
var _air_since: Dictionary[int, float] = {}
var _landed_at: Dictionary[int, float] = {}
var _flight_s: Dictionary[int, float] = {}
## Trouble: when each board last fell, since when it is off the plane, the places it held before it
## lost places lately (race seconds, the place).
var _fell_at: Dictionary[int, float] = {}
var _off_plane_since: Dictionary[int, float] = {}
var _drops: Dictionary[int, PackedVector2Array] = {}
## When each board's last rounding watch ended (race seconds): the slow way out of a gybe is the gybe's.
var _rounding_ended_at: Dictionary[int, float] = {}
## Every rounding watched, judged or not, one line each (the transcript's list, to check the numbers).
var rounding_notes: PackedStringArray = PackedStringArray()
## The day as measured (conditions): the wind's mean (knots), and each board's water height's mean and
## variance over about the last day_smooth_s (m, m2), smoothed look by look; the sea's significant
## wave height is four times the root of the boards' mean variance (m).
var wind_mean_kt: float = NAN
var sea_hs_m: float = NAN
var _sea_mean_m: Dictionary[int, float] = {}
var _sea_var_m2: Dictionary[int, float] = {}
var _sea_s: float = 0.0
## Form: each board's held place as it changed (race seconds, the place), and since when the leader
## has led.
var _place_history: Dictionary[int, PackedVector2Array] = {}
var _led_since_s: float = 0.0


## A rounding being watched (see the class's doc).
class Rounding:
	var step: int = 0
	var began_s: float = 0.0
	var speed_in_ms: float = 0.0
	var least_ms: float = 0.0
	var planing_in: bool = false
	var off_plane_s: float = 0.0
	var nearest_m: float = INF
	var side_in: int = 0
	var widest_twa_deg: float = 0.0
	## The wind angle at the last look, and whether the stern has gone through the wind since.
	var last_twa_deg: float = 0.0
	var stern_crossed: bool = false
	## When the stern went through the wind, race seconds; -1 before.
	var crossed_s: float = -1.0
	var fell: bool = false
	## When it rounded (its step done), race seconds; -1 before.
	var rounded_s: float = -1.0
	## When the sail first changed sides in the watch, race seconds; -1: it did not.
	var flipped_s: float = -1.0


func _init(tuning: CommentaryConfig) -> void:
	config = tuning


## What has happened since the last look. The first look of a race only takes note.
func look(now: RaceLook) -> Array[RaceMoment]:
	var moments: Array[RaceMoment] = []
	_measure_the_day(now)
	if now.started:
		_watch_the_start(now, moments)
		for index: int in now.boards.size():
			if now.boards[index].present:
				_watch_a_fall(now, index, moments)
				_watch_the_air(now, index, moments)
	if now.racing or now.over:
		_watch_the_order(now, moments)
		_watch_the_finish(now, moments)
	if now.racing:
		for index: int in now.order:
			if now.is_racing(index):
				_watch_a_rounding(now, index, moments)
		_watch_the_pairs(now, moments)
		_watch_the_marks(now, moments)
		_watch_the_last_leg(now, moments)
		_watch_off_the_plane(now, moments)
	var first_look: bool = _last == null
	_last = now
	if first_look:
		moments.clear()
	return moments


## The small talk that fits now (quiet moments), about the board on the screen (`focus`, its race
## number; -1 none) where it is about a board. `wide`: the picture is a wide shot. The director picks
## among them and keeps them from coming too often.
func quiet(now: RaceLook, focus: int, wide: bool) -> Array[RaceMoment]:
	var moments: Array[RaceMoment] = []
	if now == null or not now.started or now.over:
		return moments
	var shown: bool = focus >= 0 and focus < now.boards.size() and now.boards[focus].present and not now.boards[focus].finished
	if shown:
		moments.append(_quiet("identify", focus, now))
		if wide:
			moments.append(_quiet("unsure", focus, now, 1))
	moments.append(_quiet("camera", -1, now, 1))
	moments.append(_quiet("conditions", -1, now, 3 if wind_mean_kt >= config.wind_strong_kt else 2))
	if not now.racing or now.clock_s < config.order_from_s:
		return moments  # the countdown and the start's shuffle: no order to talk about yet
	if shown:
		var line: RaceMoment = tactics_of(now, focus)
		if line != null:
			moments.append(line)
		var on_form: RaceMoment = form_of(now, focus)
		if on_form != null:
			moments.append(on_form)
	var close_call: RaceMoment = tension_of(now)
	if close_call != null:
		moments.append(close_call)
	if shown and is_fast(now, focus):
		moments.append(_quiet("speed", focus, now, 3 if now.boards[focus].place <= 3 else 2))
	if not now.order.is_empty() and not now.boards[now.order[0]].finished:
		moments.append(_quiet("leader", now.order[0], now, 3 if now.lead_m() >= config.big_lead_m else 2))
	if now.fleet_size() >= 3:
		moments.append(_quiet("rundown", now.order[0], now))
	moments.append(_quiet("filler", -1, now, 1))
	return moments


## The line a board takes (tactics), or null when there is nothing to say about it: in another sail's
## dirty wind (the share of its wind lost at least dirty_air_share), to windward or to leeward of the
## board next to it in the order (within tactics_near_m of it, at least tactics_side_m up or down the
## wind), or else of its straight line to its next mark (at least tactics_line_m).
func tactics_of(now: RaceLook, index: int) -> RaceMoment:
	var board: RaceLook.Board = now.boards[index]
	if not now.is_racing(index) or board.fallen or board.next_step < 1:
		return null
	var moment: RaceMoment = _quiet("tactics", index, now)
	var said: PackedStringArray = PackedStringArray()
	if board.dirty_share >= config.dirty_air_share:
		moment.dirty = true
		said.append("in dirty wind (%d %% of it lost)" % roundi(board.dirty_share * 100.0))
	var beside: int = -1
	for other: int in [now.at_place(board.place - 1), now.at_place(board.place + 1)]:
		if other < 0 or not now.is_racing(other) or now.boards[other].fallen:
			continue
		var apart_m: float = board.position.distance_to(now.boards[other].position)
		if apart_m <= config.tactics_near_m and (beside < 0 or apart_m < board.position.distance_to(now.boards[beside].position)):
			beside = other
	if beside >= 0:
		var up_m: float = now.windward_of_m(index, now.boards[beside].position)
		if absf(up_m) >= config.tactics_side_m:
			moment.windward = 1 if up_m > 0.0 else -1
			moment.board2 = beside
			said.append("%.0f m to %s of %s" % [absf(up_m), "windward" if up_m > 0.0 else "leeward", now.name_of(beside)])
	if moment.windward == 0:
		var line_m: float = now.line_offset_m(index)
		if absf(line_m) >= config.tactics_line_m:
			moment.windward = 1 if line_m > 0.0 else -1
			said.append("%.0f m %s its straight line to the mark" % [absf(line_m), "above" if line_m > 0.0 else "below"])
	if said.is_empty():
		return null
	moment.note = ", ".join(said)
	return moment


## A race not yet decided late on (tension), or null: a place that matters (tension_places: the lead,
## the last place on the podium) on its last tension_legs legs, the board behind within tension_s of it
## (the gap on the water over the chaser's speed).
func tension_of(now: RaceLook) -> RaceMoment:
	for place: int in config.tension_places:
		var holder: int = now.at_place(place)
		var chaser: int = now.at_place(place + 1)
		if holder < 0 or chaser < 0 or not now.is_racing(holder) or not now.is_racing(chaser):
			continue
		if now.boards[holder].next_step < now.step_count() - config.tension_legs:
			continue
		var gap_m: float = now.boards[holder].position.distance_to(now.boards[chaser].position)
		var gap_s: float = gap_m / maxf(now.boards[chaser].speed_ms, 3.0)
		if gap_s > config.tension_s:
			continue
		var moment: RaceMoment = _quiet("tension", holder, now, 3)
		moment.board2 = chaser
		moment.place = place
		moment.close = gap_m <= config.close_m
		moment.note = "%s %.1f s ahead of %s for %s, %d legs to go" % [now.name_of(holder), gap_s, now.name_of(chaser),
			CommentaryWords.place_word(place), now.step_count() - now.boards[holder].next_step]
		return moment
	return null


## A board in form, or null: leading for form_lead_s or more, or up form_places places or more over
## the last form_window_s (its held places).
func form_of(now: RaceLook, index: int) -> RaceMoment:
	var board: RaceLook.Board = now.boards[index]
	if not now.is_racing(index) or board.fallen:
		return null
	if board.place == 1 and _leader == index and now.clock_s - _led_since_s >= config.form_lead_s:
		var leading: RaceMoment = _quiet("form", index, now)
		leading.note = "leading for %.0f s" % (now.clock_s - _led_since_s)
		return leading
	var gained: int = held_at(index, now.clock_s - config.form_window_s) - _held_place.get(index, board.place)
	if gained < config.form_places:
		return null
	var running: RaceMoment = _quiet("form", index, now)
	running.note = "up %d places in %.0f s" % [gained, config.form_window_s]
	return running


## The place a board held at a race time (the earliest known before its first change).
func held_at(index: int, at_s: float) -> int:
	var history: PackedVector2Array = _place_history.get(index, PackedVector2Array())
	if history.is_empty():
		return _held_place.get(index, 0)
	var held: int = int(history[0].y)
	for change: Vector2 in history:
		if change.x <= at_s:
			held = int(change.y)
	return held


## A board's place held from now (noted in its history when it changes).
func _hold(index: int, place: int, at_s: float) -> void:
	if _held_place.get(index, -1) == place:
		return
	_held_place[index] = place
	if not _place_history.has(index):
		_place_history[index] = PackedVector2Array()
	_place_history[index].append(Vector2(at_s, place))


## The day's wind and water, measured look by look: the wind's mean over the fleet (smoothed over
## day_smooth_s), and the sea's significant wave height from the water's height under each board
## (Hs = 4 x the standard deviation of the surface's height, the usual measure), its mean and variance
## smoothed over the same time. Written into the look for the needs.
func _measure_the_day(now: RaceLook) -> void:
	var dt: float = clampf(now.clock_s - _last.clock_s, 0.0, 1.0) if _last != null else 0.0
	var blend: float = clampf(dt / config.day_smooth_s, 0.0, 1.0)
	if not now.order.is_empty():
		wind_mean_kt = now.wind_kt if is_nan(wind_mean_kt) else lerpf(wind_mean_kt, now.wind_kt, blend)
	var variances: float = 0.0
	var counted: int = 0
	for index: int in now.order:
		var height_m: float = now.boards[index].water_height_m
		if not _sea_mean_m.has(index):
			_sea_mean_m[index] = height_m
			_sea_var_m2[index] = 0.0
			continue
		_sea_mean_m[index] = lerpf(_sea_mean_m[index], height_m, blend)
		var off_m: float = height_m - _sea_mean_m[index]
		_sea_var_m2[index] = lerpf(_sea_var_m2[index], off_m * off_m, blend)
		variances += _sea_var_m2[index]
		counted += 1
	_sea_s += dt
	if counted > 0 and _sea_s >= config.day_smooth_s * 0.5:
		sea_hs_m = 4.0 * sqrt(variances / counted)
	now.wind_mean_kt = wind_mean_kt
	now.sea_hs_m = sea_hs_m


## A board worth calling fast: planing at fast_share of the fleet's median planing speed or more, or it
## gained a place in the last 20 s.
func is_fast(now: RaceLook, index: int) -> bool:
	var board: RaceLook.Board = now.boards[index]
	if board.fallen or not now.is_racing(index):
		return false
	if _gained_at.has(index) and now.clock_s - _gained_at[index] < 20.0:
		return true
	if not board.planing:
		return false
	var speeds: PackedFloat64Array = PackedFloat64Array()
	for other: int in now.order:
		var them: RaceLook.Board = now.boards[other]
		if now.is_racing(other) and them.planing and not them.fallen:
			speeds.append(them.speed_ms)
	if speeds.size() < 2:
		return false
	speeds.sort()
	var median: float = speeds[speeds.size() / 2] if speeds.size() % 2 == 1 else 0.5 * (speeds[speeds.size() / 2 - 1] + speeds[speeds.size() / 2])
	return board.speed_ms >= config.fast_share * median


func _quiet(what: String, about: int, now: RaceLook, size: int = 2) -> RaceMoment:
	var made: RaceMoment = RaceMoment.make(what, about, size, now.clock_s)
	made.quiet = true
	if about >= 0:
		made.place = now.boards[about].place
		made.close = now.nearest_other_m(about) <= config.close_m
	return made


# ---------------------------------------------------------------- the start

func _watch_the_start(now: RaceLook, moments: Array[RaceMoment]) -> void:
	# The fleet lining up: the latest of the pre-start times passed (those passed before it are skipped).
	var told_now: bool = false
	while _pre_start_told < config.pre_start_at_s.size() and now.clock_s >= config.pre_start_at_s[_pre_start_told]:
		_pre_start_told += 1
		told_now = true
	if told_now and now.clock_s < 0.0:
		moments.append(RaceMoment.make("pre_start", -1, 1, now.clock_s))
	if not _gun_told and now.clock_s >= 0.0:
		_gun_told = true
		if now.clock_s < 2.0:
			moments.append(RaceMoment.make("start_gun", -1, 2, now.clock_s))
		_over_early_at_the_gun(now, moments)
	if not _start_judged and now.clock_s >= config.start_judge_s:
		_start_judged = true
		_judge_the_start(now, moments)


## The boards over the line at the gun: one moment, about the first of them (and the second, if two).
func _over_early_at_the_gun(now: RaceLook, moments: Array[RaceMoment]) -> void:
	var over: Array[int] = []
	for index: int in now.order:
		if now.boards[index].ocs:
			over.append(index)
			_ocs_at_gun[index] = true
	if over.is_empty() or now.clock_s >= 2.0:
		return
	var moment: RaceMoment = RaceMoment.make("over_early", over[0], 3, now.clock_s)
	if over.size() >= 2:
		moment.board2 = over[1]
	moment.place = now.boards[over[0]].place
	moment.note = "%d over the line at the gun" % over.size()
	moments.append(moment)


## The start judged start_judge_s after the gun: the first over the line within good_start_within_s and
## planing (a good start), and the board farthest from the line that has not crossed it yet and was not
## over early (a bad start).
func _judge_the_start(now: RaceLook, moments: Array[RaceMoment]) -> void:
	if now.fleet_size() < 2:
		return
	var good: int = -1
	var late: int = -1
	for index: int in now.order:
		var board: RaceLook.Board = now.boards[index]
		if board.start_s >= 0.0 and board.start_s <= config.good_start_within_s and board.planing:
			if good < 0 or board.start_s < now.boards[good].start_s:
				good = index
		elif board.start_s < 0.0 and not _ocs_at_gun.has(index) and not board.ocs:
			if late < 0 or board.to_next_m > now.boards[late].to_next_m:
				late = index
	if good >= 0:
		var moment: RaceMoment = RaceMoment.make("start_good", good, 2, now.clock_s)
		moment.place = now.boards[good].place
		moment.note = "over the line %.1f s after the gun, planing" % now.boards[good].start_s
		moments.append(moment)
	if late >= 0:
		var moment: RaceMoment = RaceMoment.make("start_bad", late, 2, now.clock_s)
		moment.place = now.boards[late].place
		moment.note = "not over the line %.0f s after the gun, %.0f m from it" % [now.clock_s, now.boards[late].to_next_m]
		moments.append(moment)


# ---------------------------------------------------------------- the order

## Places that have held for order_hold_s: a new leader is a lead change, a board up a place (not to
## the lead) an overtake of the board now behind it. Nothing is told before order_from_s after the gun.
func _watch_the_order(now: RaceLook, moments: Array[RaceMoment]) -> void:
	var telling: bool = now.racing and now.clock_s >= config.order_from_s
	var moved_up: Array[int] = []
	var held_before: Dictionary[int, int] = _held_place.duplicate()
	for index: int in now.order:
		var place: int = now.boards[index].place
		if _seen_place.get(index, -1) != place:
			_seen_place[index] = place
			_seen_since[index] = now.clock_s
		if not _held_place.has(index) or not telling:
			_hold(index, place, now.clock_s)
			continue
		if now.clock_s - _seen_since[index] >= config.order_hold_s and _held_place[index] != place:
			if place < _held_place[index]:
				moved_up.append(index)
				_gained_at[index] = now.clock_s
			else:
				_note_places_lost(now, index, _held_place[index], place, moments)
			_hold(index, place, now.clock_s)
	for index: int in moved_up:
		var place: int = now.boards[index].place
		if place == 1 or now.boards[index].finished:
			continue  # the lead is told as a lead change; a finish as a finish
		var behind: int = now.at_place(place + 1)
		var overtake: RaceMoment = RaceMoment.make("overtake", index, 3 if place <= 3 else 2, now.clock_s)
		if behind >= 0 and held_before.get(behind, 99) < held_before.get(index, 0):
			overtake.board2 = behind
			overtake.close = now.boards[index].position.distance_to(now.boards[behind].position) <= config.close_m
		overtake.place = place
		overtake.note = "up from %s to %s" % [CommentaryWords.place_word(held_before.get(index, 0)), CommentaryWords.place_word(place)]
		moments.append(overtake)
	_watch_the_lead(now, telling, moments)


func _watch_the_lead(now: RaceLook, telling: bool, moments: Array[RaceMoment]) -> void:
	if now.order.is_empty():
		return
	var first: int = now.order[0]
	if first != _leader_seen:
		_leader_seen = first
		_leader_since = now.clock_s
	if _leader == first or now.clock_s - _leader_since < config.order_hold_s and _leader >= 0:
		return
	var old: int = _leader
	_leader = first
	_led_since_s = now.clock_s
	if not telling or old < 0 or now.boards[first].finished:
		return
	var moment: RaceMoment = RaceMoment.make("lead_change", first, 4 if now.on_last_leg(first) else 3, now.clock_s)
	moment.board2 = old
	moment.place = 1
	moment.close = now.boards[first].position.distance_to(now.boards[old].position) <= config.close_m
	moments.append(moment)


# ---------------------------------------------------------------- falls and flights

func _watch_a_fall(now: RaceLook, index: int, moments: Array[RaceMoment]) -> void:
	var fallen: bool = now.boards[index].fallen
	var was: bool = _was_fallen.get(index, false)
	_was_fallen[index] = fallen
	if not fallen or was or now.boards[index].finished:
		return
	var place: int = now.boards[index].place
	var size: int = 2
	if now.racing:
		size = 4 if place == 1 else (3 if place <= 3 else 2)
	_fell_at[index] = now.clock_s
	var moment: RaceMoment = RaceMoment.make("fall", index, size, now.clock_s)
	moment.place = place
	moment.close = now.nearest_other_m(index) <= config.close_m
	moments.append(moment)


## Airtime: the board's water share under air_share for air_min_s or more, then on the water again and
## still sailing air_land_s after it landed.
func _watch_the_air(now: RaceLook, index: int, moments: Array[RaceMoment]) -> void:
	var board: RaceLook.Board = now.boards[index]
	if board.fallen:
		_air_since[index] = -1.0
		_landed_at[index] = -1.0
		return
	var since: float = _air_since.get(index, -1.0)
	if board.water_share < config.air_share:
		if since < 0.0:
			_air_since[index] = now.clock_s
	elif since >= 0.0:
		_air_since[index] = -1.0
		if now.clock_s - since >= config.air_min_s:
			_landed_at[index] = now.clock_s
			_flight_s[index] = now.clock_s - since
	var landed: float = _landed_at.get(index, -1.0)
	if landed >= 0.0 and now.clock_s - landed >= config.air_land_s:
		_landed_at[index] = -1.0
		if not now.racing or board.finished:
			return
		var moment: RaceMoment = RaceMoment.make("airtime", index, 4 if board.place <= 3 else 3, now.clock_s)
		moment.place = board.place
		moment.note = "%.1f s in the air" % _flight_s.get(index, 0.0)
		moments.append(moment)


# ---------------------------------------------------------------- trouble without a fall

## A board down trouble_places places or more within trouble_window_s, without a fall in that time.
func _note_places_lost(now: RaceLook, index: int, held: int, place: int, moments: Array[RaceMoment]) -> void:
	var drops: PackedVector2Array = _drops.get(index, PackedVector2Array())
	drops.append(Vector2(now.clock_s, held))
	while not drops.is_empty() and now.clock_s - drops[0].x > config.trouble_window_s:
		drops.remove_at(0)
	_drops[index] = drops
	var best: int = place
	for drop: Vector2 in drops:
		best = mini(best, int(drop.y))
	if place - best >= config.trouble_places and now.clock_s - _fell_at.get(index, -INF) > config.trouble_window_s and not now.boards[index].finished:
		_trouble(now, index, "down from %s to %s" % [CommentaryWords.place_word(best), CommentaryWords.place_word(place)], best, moments)


## A board off the plane for trouble_off_plane_s while most of the racing fleet planes: not round a
## mark nor within trouble_window_s after it (the way out of a gybe is the gybe's), not soon after a
## fall or the start.
func _watch_off_the_plane(now: RaceLook, moments: Array[RaceMoment]) -> void:
	var sailing: int = 0
	var planing: int = 0
	for index: int in now.order:
		if now.is_racing(index) and not now.boards[index].fallen:
			sailing += 1
			if now.boards[index].planing:
				planing += 1
	var fleet_planes: bool = sailing >= 2 and planing * 2 >= sailing
	for index: int in now.order:
		var board: RaceLook.Board = now.boards[index]
		var calm: bool = not now.is_racing(index) or board.fallen or board.planing or board.start_s < 0.0
		var excused: bool = _roundings.has(index) or now.clock_s < config.order_from_s or now.clock_s - _fell_at.get(index, -INF) < config.trouble_window_s 			or now.clock_s - _rounding_ended_at.get(index, -INF) < config.trouble_window_s
		if calm or excused or not fleet_planes:
			_off_plane_since.erase(index)
			continue
		if not _off_plane_since.has(index):
			_off_plane_since[index] = now.clock_s
		elif now.clock_s - _off_plane_since[index] >= config.trouble_off_plane_s:
			var off_s: float = now.clock_s - _off_plane_since[index]
			_off_plane_since.erase(index)
			_trouble(now, index, "off the plane %.0f s at %.0f kt while %d of %d plane" % [off_s, board.speed_ms / SimMath.KNOT_MS, planing, sailing], board.place, moments)


func _trouble(now: RaceLook, index: int, note: String, place_before: int, moments: Array[RaceMoment]) -> void:
	if not _pair_free(now, "trouble", index, index, config.trouble_again_s):
		return
	var moment: RaceMoment = RaceMoment.make("trouble", index, 3 if place_before <= 3 else 2, now.clock_s)
	moment.place = now.boards[index].place
	moment.close = now.nearest_other_m(index) <= config.close_m
	moment.note = note
	moments.append(moment)


# ---------------------------------------------------------------- the marks

## The front (the first mark_front) coming within mark_approach_m of their next mark or gate: once per
## board and mark.
func _watch_the_marks(now: RaceLook, moments: Array[RaceMoment]) -> void:
	for place: int in mini(config.mark_front, now.order.size()):
		var index: int = now.order[place]
		var board: RaceLook.Board = now.boards[index]
		if not now.is_racing(index) or board.fallen or not now.next_is_a_mark(index):
			continue
		if board.to_next_m > config.mark_approach_m or _approach_told.get(index, -1) == board.next_step:
			continue
		_approach_told[index] = board.next_step
		var moment: RaceMoment = RaceMoment.make("mark_approach", index, 2, now.clock_s)
		moment.place = place + 1
		moment.close = now.nearest_other_m(index) <= config.close_m
		moment.mark_word = CommentaryWords.mark_word(now.mark_number(board.next_step), now.mark_count())
		moments.append(moment)


## A rounding watched from rounding_from_m before the mark to its end (see the class's doc), then judged.
func _watch_a_rounding(now: RaceLook, index: int, moments: Array[RaceMoment]) -> void:
	var board: RaceLook.Board = now.boards[index]
	var rounding: Rounding = _roundings.get(index, null)
	if rounding == null:
		if now.next_is_a_mark(index) and not board.fallen and now.distance_to_mark_m(index, board.next_step) <= config.rounding_from_m:
			rounding = Rounding.new()
			rounding.step = board.next_step
			rounding.began_s = now.clock_s
			rounding.speed_in_ms = board.speed_ms
			rounding.least_ms = board.speed_ms
			rounding.planing_in = board.planing
			rounding.nearest_m = now.distance_to_mark_m(index, board.next_step)
			rounding.side_in = board.sail_side
			rounding.widest_twa_deg = absf(board.twa_deg)
			rounding.last_twa_deg = board.twa_deg
			_roundings[index] = rounding
		return
	var dt: float = now.clock_s - _last.clock_s if _last != null else 0.0
	rounding.least_ms = minf(rounding.least_ms, board.speed_ms)
	if rounding.planing_in and not board.planing:
		rounding.off_plane_s += dt
	rounding.nearest_m = minf(rounding.nearest_m, now.distance_to_mark_m(index, rounding.step))
	rounding.widest_twa_deg = maxf(rounding.widest_twa_deg, absf(board.twa_deg))
	if not rounding.stern_crossed and absf(board.twa_deg) >= config.gybe_twa_deg and absf(rounding.last_twa_deg) >= config.gybe_twa_deg \
			and signf(board.twa_deg) != signf(rounding.last_twa_deg):
		rounding.stern_crossed = true
		rounding.crossed_s = now.clock_s
	rounding.last_twa_deg = board.twa_deg
	rounding.fell = rounding.fell or board.fallen
	if rounding.flipped_s < 0.0 and board.sail_side != rounding.side_in:
		rounding.flipped_s = now.clock_s
	if board.next_step > rounding.step and rounding.rounded_s < 0.0:
		rounding.rounded_s = now.clock_s
	# The watch ends gybe_exit_s after the stern went through the wind, or gybe_wait_s after the mark without a gybe.
	var done: bool = rounding.rounded_s >= 0.0 and (now.clock_s - rounding.crossed_s >= config.gybe_exit_s if rounding.stern_crossed
		else now.clock_s - rounding.rounded_s >= config.gybe_wait_s)
	if done:
		_roundings.erase(index)
		_rounding_ended_at[index] = now.clock_s
		var judged: RaceMoment = judge_the_gybe(rounding, config)
		rounding_notes.append("%s  %s at mark %d: %s; the widest wind angle %.0f deg, the stern %s, the sail %s%s -> %s" % [
			clock_text(now.clock_s), now.name_of(index), now.mark_number(rounding.step), rounding_text(rounding), rounding.widest_twa_deg,
			"through the wind %.1f s after the mark" % (rounding.crossed_s - rounding.rounded_s) if rounding.stern_crossed else "not through the wind",
			"across %.1f s %s the rounding" % [absf(rounding.flipped_s - rounding.rounded_s), "before" if rounding.flipped_s < rounding.rounded_s else "after"] if rounding.flipped_s >= 0.0 else "not across yet",
			", fell" if rounding.fell else "", judged.moment if judged != null else "no gybe line"])
		if judged != null:
			judged.board = index
			judged.race_s = now.clock_s
			judged.place = board.place
			if judged.moment == "gybe_safe" and board.place > 3:
				judged.level = 1
			judged.close = now.nearest_other_m(index) <= config.close_m
			judged.mark_word = CommentaryWords.mark_word(now.mark_number(rounding.step), now.mark_count())
			moments.append(judged)
	elif rounding.rounded_s < 0.0 and (now.clock_s - rounding.began_s > 60.0 or now.distance_to_mark_m(index, rounding.step) > 2.0 * config.rounding_from_m):
		_roundings.erase(index)  # it went away from the mark without rounding it: nothing to judge
		rounding_notes.append("%s  %s at mark %d: went away without rounding it" % [clock_text(now.clock_s), now.name_of(index), now.mark_number(rounding.step)])


## A rounding judged (see the class's doc): gybe_good, gybe_safe or gybe_bad, or null when the board
## did not gybe there (its stern never went through the wind) or fell (the fall is told as a fall).
static func judge_the_gybe(rounding: Rounding, tuning: CommentaryConfig) -> RaceMoment:
	if not rounding.stern_crossed or rounding.fell:
		return null
	var kept: float = rounding.least_ms / maxf(rounding.speed_in_ms, 0.1)
	var what: String = "gybe_safe"
	var size: int = 2
	if kept < tuning.bad_kept or rounding.nearest_m > tuning.wide_m:
		what = "gybe_bad"
		size = 3
	elif kept >= tuning.good_kept and rounding.off_plane_s <= tuning.good_off_plane_s and rounding.nearest_m <= tuning.tight_m:
		what = "gybe_good"
		size = 3
	var moment: RaceMoment = RaceMoment.make(what, -1, size)
	moment.note = rounding_text(rounding)
	return moment


## What a rounding measured, in a few words: "kept 84 % of its speed (20.1 to 16.9 kt), 0.0 s off the
## plane, 6 m from the mark".
static func rounding_text(rounding: Rounding) -> String:
	var kept: float = rounding.least_ms / maxf(rounding.speed_in_ms, 0.1)
	return "kept %d %% of its speed (%.1f to %.1f kt), %.1f s off the plane, %.0f m from the mark" % [
		roundi(kept * 100.0), rounding.speed_in_ms / SimMath.KNOT_MS, rounding.least_ms / SimMath.KNOT_MS, rounding.off_plane_s, rounding.nearest_m]


## A race time as "1:07.3" ("-0:12.0" before the gun).
static func clock_text(seconds: float) -> String:
	var whole: float = absf(seconds)
	return "%s%d:%04.1f" % ["-" if seconds < 0.0 else "", floori(whole / 60.0), fmod(whole, 60.0)]


# ---------------------------------------------------------------- two boards

## Next to each other in the order: a chase (closing on the one ahead) and a fight (close for a
## while). Any two boards: a near miss.
func _watch_the_pairs(now: RaceLook, moments: Array[RaceMoment]) -> void:
	for place: int in range(0, now.order.size() - 1):
		var ahead: int = now.order[place]
		var behind: int = now.order[place + 1]
		if not now.is_racing(ahead) or not now.is_racing(behind) or now.boards[ahead].fallen or now.boards[behind].fallen:
			_gaps.erase(behind)
			continue
		var gap_m: float = now.boards[ahead].position.distance_to(now.boards[behind].position)
		_watch_a_chase(now, ahead, behind, gap_m, moments)
		_watch_a_fight(now, ahead, behind, gap_m, moments)
	if now.clock_s >= config.near_from_s:
		_watch_near_misses(now, moments)


func _watch_a_chase(now: RaceLook, ahead: int, behind: int, gap_m: float, moments: Array[RaceMoment]) -> void:
	var samples: PackedVector3Array = _gaps.get(behind, PackedVector3Array())
	if not samples.is_empty() and int(samples[samples.size() - 1].z) != ahead:
		samples.clear()  # another board ahead now: start again
	samples.append(Vector3(now.clock_s, gap_m, ahead))
	while samples.size() > 1 and now.clock_s - samples[0].x > config.chase_window_s:
		samples.remove_at(0)
	_gaps[behind] = samples
	if gap_m > config.chase_near_m or gap_m <= config.fight_m or now.clock_s < config.order_from_s:
		return
	var gained_m: float = samples[0].y - gap_m
	if now.clock_s - samples[0].x < 0.5 * config.chase_window_s or gained_m < config.chase_gain_m:
		return
	if not _pair_free(now, "chase", ahead, behind, config.chase_again_s):
		return
	var place: int = now.boards[behind].place
	var moment: RaceMoment = RaceMoment.make("chase", behind, 3 if place <= 2 else 2, now.clock_s)
	moment.board2 = ahead
	moment.place = place
	moment.close = gap_m <= config.close_m
	moment.note = "%.0f m behind, %.0f m nearer than %.0f s ago" % [gap_m, gained_m, now.clock_s - samples[0].x]
	moments.append(moment)


func _watch_a_fight(now: RaceLook, ahead: int, behind: int, gap_m: float, moments: Array[RaceMoment]) -> void:
	var key: String = pair_key(ahead, behind)
	if gap_m > config.fight_m:
		_close_since.erase(key)
		return
	if not _close_since.has(key):
		_close_since[key] = now.clock_s
		return
	if now.clock_s - _close_since[key] < config.fight_after_s or not _pair_free(now, "fight", ahead, behind, config.fight_again_s):
		return
	var place: int = now.boards[ahead].place
	# {rider} needs to hold off {rider2}: the board ahead first; the battle is for its place.
	var moment: RaceMoment = RaceMoment.make("fight", ahead, 3 if place <= 3 else 2, now.clock_s)
	moment.board2 = behind
	moment.place = place
	moment.close = true
	moment.note = "%.0f m apart for %.0f s" % [gap_m, now.clock_s - _close_since[key]]
	moments.append(moment)


func _watch_near_misses(now: RaceLook, moments: Array[RaceMoment]) -> void:
	for a: int in now.order.size():
		var one: int = now.order[a]
		if not now.is_racing(one) or now.boards[one].fallen:
			continue
		for b: int in range(a + 1, now.order.size()):
			var other: int = now.order[b]
			if not now.is_racing(other) or now.boards[other].fallen:
				continue
			var apart: Vector2 = now.boards[other].position - now.boards[one].position
			if apart.length() > config.near_miss_m:
				continue
			var closing_ms: float = (now.boards[one].velocity() - now.boards[other].velocity()).length()
			if closing_ms < config.near_speed_ms or not _pair_free(now, "near_miss", one, other, config.near_again_s):
				continue
			# The board that came at the other is the one that nearly took it out.
			var first: int = one
			var second: int = other
			if now.boards[other].velocity().dot(-apart) > now.boards[one].velocity().dot(apart):
				first = other
				second = one
			var best_place: int = mini(now.boards[one].place, now.boards[other].place)
			var moment: RaceMoment = RaceMoment.make("near_miss", first, 4 if best_place <= 3 else 3, now.clock_s)
			moment.board2 = second
			moment.place = now.boards[first].place
			moment.close = true
			moment.note = "%.1f m apart, %.1f m/s between them" % [apart.length(), closing_ms]
			moments.append(moment)


## Whether a kind of moment about two boards may be told now (not within `again_s` of the last); if so,
## it is noted as told.
func _pair_free(now: RaceLook, what: String, a: int, b: int, again_s: float) -> bool:
	var key: String = what + ":" + pair_key(a, b)
	if now.clock_s - _pair_told_at.get(key, -INF) < again_s:
		return false
	_pair_told_at[key] = now.clock_s
	return true


## The same key for two boards whichever comes first.
static func pair_key(a: int, b: int) -> String:
	return "%d:%d" % [mini(a, b), maxi(a, b)]


# ---------------------------------------------------------------- the finish

func _watch_the_last_leg(now: RaceLook, moments: Array[RaceMoment]) -> void:
	if _last_leg_told or now.order.is_empty() or now.leg_count() < 2:
		return
	var leader: int = now.order[0]
	if now.on_last_leg(leader) and not now.boards[leader].finished:
		_last_leg_told = true
		var moment: RaceMoment = RaceMoment.make("last_leg", leader, 3, now.clock_s)
		moment.place = 1
		moments.append(moment)


## The winner, the places, a photo finish (two boards coming in together, or crossing within photo_s
## of each other), and the verdict after_win_s after the winner and when the race is over.
func _watch_the_finish(now: RaceLook, moments: Array[RaceMoment]) -> void:
	if now.racing:
		_watch_a_photo_finish(now, moments)
	var crossed: Array[int] = []
	for index: int in now.order:
		if now.boards[index].finished and not _finish_told.has(index):
			crossed.append(index)
	for index: int in crossed:
		_finish_told[index] = true
		var board: RaceLook.Board = now.boards[index]
		if _winner < 0:
			_winner = index
			_win_at_s = now.clock_s
			var win: RaceMoment = RaceMoment.make("finish_win", index, 4, now.clock_s)
			win.place = 1
			moments.append(win)
			continue
		var place_moment: RaceMoment = RaceMoment.make("finish_place", index, 3 if board.place <= 3 else 2, now.clock_s)
		place_moment.place = board.place
		moments.append(place_moment)
		# Crossing right after the board ahead: a photo finish, if the two were not told as coming in together.
		var ahead: int = now.at_place(board.place - 1)
		if ahead >= 0 and now.boards[ahead].finished and absf(board.finish_s - now.boards[ahead].finish_s) <= config.photo_s:
			_photo(now, ahead, index, moments)
	if _winner >= 0 and not _after_win_told and now.clock_s >= _win_at_s + config.after_win_s:
		_after_win_told = true
		moments.append(RaceMoment.make("after_race", _winner, 2, now.clock_s))
	if now.over and not _after_race_told:
		_after_race_told = true
		if _winner >= 0:
			moments.append(RaceMoment.make("after_race", _winner, 2, now.clock_s))


func _watch_a_photo_finish(now: RaceLook, moments: Array[RaceMoment]) -> void:
	for place: int in range(0, now.order.size() - 1):
		var ahead: int = now.order[place]
		var behind: int = now.order[place + 1]
		if not now.on_last_leg(ahead) or not now.on_last_leg(behind):
			continue
		if now.boards[ahead].to_next_m > config.photo_m or now.boards[behind].to_next_m > config.photo_m:
			continue
		if now.boards[ahead].position.distance_to(now.boards[behind].position) <= config.photo_close_m:
			_photo(now, ahead, behind, moments)


func _photo(now: RaceLook, ahead: int, behind: int, moments: Array[RaceMoment]) -> void:
	if not _pair_free(now, "photo_finish", ahead, behind, INF):
		return
	var moment: RaceMoment = RaceMoment.make("photo_finish", ahead, 4, now.clock_s)
	moment.board2 = behind
	moment.place = now.boards[ahead].place
	moment.close = true
	moments.append(moment)
