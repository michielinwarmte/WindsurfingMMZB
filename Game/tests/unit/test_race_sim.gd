extends GutTest
## RaceSim, the race (RACING_PLAN.md, "How a race works"): the countdown and the gun; a clean start,
## a board over the line at the gun (OCS) and one that went back in time; a lap's splits and finish
## time; two laps; the wrong-side warning; the places; two boards finishing in the same tick; the end
## of the race 60 s after the first finisher and at the time limit; and the steps made from the
## iQFOiL templates LG2 and PD3.
##
## The course is small and drawn by hand, for a wind from the north (upwind is -Z, east is +X):
##   the start line on z = 0, 60 m long: the boat at x = 30, the pin at x = -30;
##   mark 1 300 m upwind at (0, -300), left to port;
##   the gate 4S/4P 50 m above the start line, 40 m wide (4S on the west, the left looking upwind);
##   the finish line 100 m west of the gate, running north and south at x = -100.
## The race ticks every 0.25 s and the boards sail 1 m a tick (4 m/s). A board that leaves at the gun
## is d metres along its path at race time d / 4 s. Every crossing is a corner of the paths, so the
## boards cross exactly on a tick.

const RULES_PATH: String = "res://maps/course/iqfoil_courses.tres"
const DT: float = 0.25
const STEP_M: float = 1.0
const PRESTART_S: float = 10.0
## The ticks of the countdown: the gun goes at the end of tick COUNTDOWN_TICKS - 1. So
## _run_to(race, tracks, COUNTDOWN_TICKS + d) runs until a board that left at the gun is d metres
## along its path, and the clock reads d / 4 s.
const COUNTDOWN_TICKS: int = 40
const NAMES: PackedStringArray = ["Lena", "Joost", "Mia"]

var _rules: CourseRules
## The next tick _run_to() runs.
var _tick: int = 0


func before_all() -> void:
	_rules = load(RULES_PATH)


func before_each() -> void:
	_tick = 0


# ---------------------------------------------------------------- the countdown and the start

func test_the_countdown_reaches_the_gun() -> void:
	var race: RaceSim = RaceSim.new(_course(), 1, PRESTART_S)
	race.add_board("Lena")
	assert_eq(race.phase(), RaceSim.Phase.PRE_START)
	race.step(DT)
	assert_almost_eq(race.countdown_s(), 10.0, 1e-6, "The countdown waits for start()")
	race.start()
	for _k: int in COUNTDOWN_TICKS - 1:
		race.step(DT)
	assert_almost_eq(race.countdown_s(), 0.25, 1e-6, "One tick to go")
	assert_eq(race.phase(), RaceSim.Phase.PRE_START)
	assert_almost_eq(race.race_time_s(), 0.0, 1e-6, "No race time before the gun")
	race.step(DT)
	assert_eq(race.phase(), RaceSim.Phase.RACING, "The gun")
	assert_almost_eq(race.countdown_s(), 0.0, 1e-6)
	race.step(DT)
	assert_almost_eq(race.race_time_s(), 0.25, 1e-6, "The race clock runs")


func test_a_clean_start_one_second_after_the_gun() -> void:
	var race: RaceSim = _race(1)
	var tracks: Array[PackedVector2Array] = [_from_the_gun(_lap())]
	_run_to(race, tracks, COUNTDOWN_TICKS)
	assert_eq(race.next_step_name(0), "start")
	assert_almost_eq(race.distance_to_next_m(0), 4.0, 1e-4, "4 m from the nearest point of the line")
	assert_eq(race.next_target(0), Vector2.ZERO, "The arrow points at the line's middle")
	_run_to(race, tracks, COUNTDOWN_TICKS + 3)
	assert_eq(race.next_step_index(0), 0, "3 m on: not over yet")
	_run_to(race, tracks, COUNTDOWN_TICKS + 4)
	assert_eq(race.next_step_index(0), 1, "Started")
	assert_eq(race.next_step_name(0), "mark 1")
	assert_eq(race.next_target(0), Vector2(0.0, -300.0))
	assert_almost_eq(race.splits_s(0)[0], 1.0, 1e-4, "4 m at 4 m/s: 1 s after the gun")
	assert_false(race.is_ocs(0))


func test_over_the_line_at_the_gun_is_ocs_until_it_goes_back() -> void:
	var race: RaceSim = _race(1)
	# Leaves 10 m behind the line half-way through the countdown, is over at the gun, goes on 5 m,
	# back to 5 m behind the line, and over again.
	var track: PackedVector2Array = _hold(Vector2(10.0, 10.0), 19)
	track.append_array(_path([Vector2(10.0, 10.0), Vector2(10.0, 0.0), Vector2(10.0, -15.0), Vector2(10.0, 0.0),
		Vector2(10.0, 5.0), Vector2(10.0, 0.0), Vector2(10.0, -400.0)]))
	var tracks: Array[PackedVector2Array] = [track]
	_run_to(race, tracks, 30)
	assert_eq(race.phase(), RaceSim.Phase.PRE_START)
	assert_true(race.is_ocs(0), "On the line 2.5 s before the gun: over early")
	_run_to(race, tracks, COUNTDOWN_TICKS)
	assert_eq(race.phase(), RaceSim.Phase.RACING)
	assert_true(race.is_ocs(0), "10 m over at the gun: OCS")
	_run_to(race, tracks, 60)
	assert_true(race.is_ocs(0), "Back on the line: still OCS")
	_run_to(race, tracks, 61)
	assert_false(race.is_ocs(0), "1 m behind the line: cleared")
	assert_eq(race.next_step_index(0), 0, "but not started")
	_run_to(race, tracks, 70)
	assert_eq(race.next_step_index(0), 1, "Started on the way back over")
	assert_almost_eq(race.splits_s(0)[0], 7.5, 1e-4, "30 ticks after the gun")


func test_back_behind_the_line_before_the_gun_is_not_ocs() -> void:
	var race: RaceSim = _race(1)
	var track: PackedVector2Array = _hold(Vector2(10.0, 5.0), 9)
	# Over by 5 m and back during the countdown, then a wait, and away 1.25 s after the gun.
	track.append_array(_path([Vector2(10.0, 5.0), Vector2(10.0, 0.0), Vector2(10.0, -5.0), Vector2(10.0, 0.0), Vector2(10.0, 5.0)]))
	track.append_array(_hold(Vector2(10.0, 5.0), 14))
	track.append_array(_path([Vector2(10.0, 5.0), Vector2(10.0, 0.0), Vector2(10.0, -100.0)]))
	var tracks: Array[PackedVector2Array] = [track]
	_run_to(race, tracks, 15)
	assert_true(race.is_ocs(0), "Over early during the countdown")
	_run_to(race, tracks, COUNTDOWN_TICKS)
	assert_false(race.is_ocs(0), "Behind the line again at the gun")
	_run_to(race, tracks, 50)
	assert_eq(race.next_step_index(0), 1)
	assert_almost_eq(race.splits_s(0)[0], 2.5, 1e-4, "Left at 1.25 s, 5 m to the line")


# ---------------------------------------------------------------- the race

func test_a_lap_with_its_splits_and_finish_time() -> void:
	var race: RaceSim = _race(1)
	var tracks: Array[PackedVector2Array] = [_from_the_gun(_lap())]
	_run_to(race, tracks, COUNTDOWN_TICKS + 720)
	_assert_times(race.splits_s(0), [1.0, 81.0, 148.5, 173.5], "Start at 4 m, mark 1 at 324 m, the gate at 594 m, the finish at 694 m")
	assert_true(race.is_finished(0))
	assert_almost_eq(race.finish_time_s(0), 173.5, 1e-4)
	assert_eq(race.phase(), RaceSim.Phase.FINISHED, "Every board is in")
	assert_almost_eq(race.race_time_s(), 173.5, 1e-4, "The clock stopped at the finish")
	assert_eq(race.next_step_name(0), "")
	var results: Array[RaceResult] = race.results()
	assert_eq(results[0].place, 1)
	assert_almost_eq(results[0].gap_s, 0.0, 1e-6)
	assert_eq(results[0].steps_done, 4)
	assert_string_contains(results[0].to_line(), "2:53.5")
	assert_string_contains(results[0].to_line(), "4/4 steps")


func test_two_laps_sail_the_steps_between_start_and_finish_twice() -> void:
	var race: RaceSim = _race(1, 2)
	var names: PackedStringArray = PackedStringArray()
	for step: RaceStep in race.steps():
		names.append(step.name)
	assert_eq(names, PackedStringArray(["start", "mark 1", "gate 4S/4P", "mark 1", "gate 4S/4P", "finish"]))
	var two_laps: Array[Vector2] = [Vector2(10.0, 4.0), Vector2(10.0, 0.0), Vector2(10.0, -310.0), Vector2(0.0, -310.0),
		Vector2(-10.0, -310.0), Vector2(-10.0, -50.0), Vector2(-10.0, -40.0), Vector2(10.0, -40.0),
		Vector2(10.0, -310.0), Vector2(0.0, -310.0), Vector2(-10.0, -310.0), Vector2(-10.0, -50.0),
		Vector2(-10.0, -40.0), Vector2(-100.0, -40.0), Vector2(-120.0, -40.0)]
	var tracks: Array[PackedVector2Array] = [_from_the_gun(two_laps)]
	_run_to(race, tracks, COUNTDOWN_TICKS + 1300)
	_assert_times(race.splits_s(0), [1.0, 81.0, 148.5, 226.0, 293.5, 318.5],
		"Mark 1 again at 904 m, the gate again at 1174 m, the finish at 1274 m")


func test_a_lap_that_ends_where_the_next_begins_sails_that_mark_once() -> void:
	var course: Course = Course.new()
	course.add_mark(CourseMark.START_BOAT, Vector2(30.0, 0.0))
	course.add_mark(CourseMark.START_PIN, Vector2(-30.0, 0.0))
	course.add_mark("1", Vector2(0.0, -300.0), CourseMark.Rounding.PORT)
	course.add_mark("2", Vector2(-200.0, -150.0), CourseMark.Rounding.PORT)
	course.add_mark(CourseMark.FINISH_BOAT, Vector2(30.0, -100.0))
	course.add_mark(CourseMark.FINISH_PIN, Vector2(-30.0, -100.0))
	assert_eq(course.set_sequence("Start-1-2-1-Finish"), "")
	var ids: PackedStringArray = PackedStringArray()
	for step: RaceStep in RaceSim.new(course, 2).steps():
		ids.append(step.id)
	assert_eq(ids, PackedStringArray(["Start", "1", "2", "1", "2", "1", "Finish"]), "Not 1 twice in a row")


func test_the_wrong_side_warning_lasts_3_s() -> void:
	var race: RaceSim = _race(1)
	# Up the west side of mark 1 and across its top going east: round to starboard a mark left to port.
	var track: PackedVector2Array = _from_the_gun([Vector2(10.0, 4.0), Vector2(10.0, 0.0), Vector2(10.0, -10.0),
		Vector2(-10.0, -30.0), Vector2(-10.0, -310.0), Vector2(10.0, -310.0), Vector2(10.0, -200.0)])
	var tracks: Array[PackedVector2Array] = [track]
	var warned_ticks: int = 0
	while _tick < track.size() + 20:
		_run_to(race, tracks, _tick + 1)
		if race.wrong_side_warning(0):
			warned_ticks += 1
		assert_true(race.next_step_index(0) <= 1, "Mark 1 is never counted")
	assert_eq(warned_ticks, 12, "3 s of 0.25 s ticks")
	assert_eq(race.next_step_name(0), "mark 1")


func test_the_places_go_by_steps_then_distance() -> void:
	var race: RaceSim = _race(2)
	var tracks: Array[PackedVector2Array] = [_from_the_gun(_lap()),
		_from_the_gun([Vector2(-10.0, 2.0), Vector2(-10.0, 0.0), Vector2(-10.0, -200.0)])]
	_run_to(race, tracks, 20)
	assert_eq(race.place(1), 1, "Before the gun: 2 m from the line beats 4 m")
	_run_to(race, tracks, COUNTDOWN_TICKS + 100)
	assert_eq(race.place(1), 1, "Up the first leg, 2 m nearer mark 1")
	assert_eq(race.place(0), 2)
	_run_to(race, tracks, COUNTDOWN_TICKS + 330)
	assert_eq(race.next_step_index(0), 2, "Lena has rounded mark 1")
	assert_eq(race.place(0), 1, "One step more beats being nearer")
	var results: Array[RaceResult] = race.results()
	assert_eq(results[0].name, "Lena")
	assert_eq(results[1].name, "Joost")
	assert_false(results[1].finished)
	assert_eq(results[1].gap_s, -1.0, "No gap while racing")


func test_board_position_is_where_the_board_was_last_put() -> void:
	# What a skipper sees of the others: each board where update_board() last put it, before and
	# after the race steps, and unchanged by another board's move.
	var race: RaceSim = _race(2)
	race.update_board(0, Vector2(10.0, 4.0))
	race.update_board(1, Vector2(-10.0, 2.0))
	assert_eq(race.board_position(0), Vector2(10.0, 4.0))
	race.step(DT)
	race.update_board(1, Vector2(-10.0, 1.0))
	assert_eq(race.board_position(0), Vector2(10.0, 4.0), "Lena has not moved")
	assert_eq(race.board_position(1), Vector2(-10.0, 1.0), "Joost's new place")


func test_two_boards_in_the_same_tick_the_one_over_first_wins() -> void:
	var race: RaceSim = _race(2)
	# Joost sails Lena's path half a metre ahead: in the tick both cross the finish, Joost crosses
	# half-way through it and Lena at its end.
	var tracks: Array[PackedVector2Array] = [_from_the_gun(_lap()), _from_the_gun(_lap(), 0.5)]
	_run_to(race, tracks, COUNTDOWN_TICKS + 693)
	assert_false(race.is_finished(0))
	assert_false(race.is_finished(1))
	_run_to(race, tracks, COUNTDOWN_TICKS + 694)
	assert_almost_eq(race.finish_time_s(0), 173.5, 1e-4)
	assert_almost_eq(race.finish_time_s(1), 173.375, 1e-4, "Half a tick earlier")
	assert_eq(race.place(1), 1, "Joost, further over the line, first")
	assert_eq(race.place(0), 2)
	assert_eq(race.phase(), RaceSim.Phase.FINISHED)
	var results: Array[RaceResult] = race.results()
	assert_eq(results[0].name, "Joost")
	assert_almost_eq(results[1].gap_s, 0.125, 1e-4)


func test_a_dead_heat_goes_to_the_board_added_first() -> void:
	var race: RaceSim = _race(2)
	var tracks: Array[PackedVector2Array] = [_from_the_gun(_lap()), _from_the_gun(_lap())]
	_run_to(race, tracks, COUNTDOWN_TICKS + 720)
	assert_eq(race.finish_time_s(0), race.finish_time_s(1))
	assert_eq(race.place(0), 1)
	assert_eq(race.place(1), 2)


func test_the_race_ends_60_s_after_the_first_finisher() -> void:
	var race: RaceSim = _race(2)
	var tracks: Array[PackedVector2Array] = [_from_the_gun(_lap()), _hold(Vector2(-10.0, 10.0), 1)]
	# Lena finishes at 173.5 s; the race ends at 233.5 s, at the end of tick 39 + 934.
	_run_to(race, tracks, COUNTDOWN_TICKS + 933)
	assert_eq(race.phase(), RaceSim.Phase.RACING, "233.25 s")
	_run_to(race, tracks, COUNTDOWN_TICKS + 934)
	assert_eq(race.phase(), RaceSim.Phase.FINISHED, "233.5 s")
	assert_almost_eq(race.race_time_s(), 233.5, 1e-4)
	race.step(DT)
	assert_almost_eq(race.race_time_s(), 233.5, 1e-4, "The clock has stopped")
	var results: Array[RaceResult] = race.results()
	assert_eq(results[0].name, "Lena")
	assert_true(results[0].finished)
	assert_eq(results[1].name, "Joost")
	assert_false(results[1].finished, "Never started")
	assert_eq(results[1].steps_done, 0)
	assert_eq(results[1].steps_total, 4)
	assert_string_contains(results[1].to_line(), "DNF")


func test_the_time_limit_ends_the_race() -> void:
	var race: RaceSim = RaceSim.new(_course(), 1, PRESTART_S, 30.0)
	race.add_board("Lena")
	race.start()
	var tracks: Array[PackedVector2Array] = [_hold(Vector2(10.0, 10.0), 1)]
	_run_to(race, tracks, COUNTDOWN_TICKS + 119)
	assert_eq(race.phase(), RaceSim.Phase.RACING, "29.75 s")
	_run_to(race, tracks, COUNTDOWN_TICKS + 120)
	assert_eq(race.phase(), RaceSim.Phase.FINISHED, "30 s")


# ---------------------------------------------------------------- the templates

func test_the_steps_of_lg2() -> void:
	var course: Course = CourseTemplates.build("LG2", _rules, 15.0, 40, 222.0, Vector2(100.0, 200.0))
	var steps: Array[RaceStep] = RaceSim.new(course).steps()
	_assert_steps(steps, ["Start", "1", "4S/4P", "1", "4S", "Finish"],
		[RaceStep.Kind.START, RaceStep.Kind.MARK, RaceStep.Kind.GATE, RaceStep.Kind.MARK, RaceStep.Kind.MARK, RaceStep.Kind.FINISH],
		[CourseMark.Rounding.NONE, CourseMark.Rounding.PORT, CourseMark.Rounding.NONE, CourseMark.Rounding.PORT,
			CourseMark.Rounding.STARBOARD, CourseMark.Rounding.NONE])
	assert_eq(steps[2].name, "gate 4S/4P")
	assert_eq(steps[4].name, "mark 4S")
	assert_eq(steps[0].points, PackedVector2Array([course.mark(CourseMark.START_BOAT).position, course.mark(CourseMark.START_PIN).position]))
	assert_eq(steps[2].points, PackedVector2Array([course.mark("4S").position, course.mark("4P").position]))
	assert_almost_eq(Course.bearing_deg(Vector2.ZERO, steps[0].in_dir), 222.0, 0.01, "The start is crossed toward mark 1, upwind")
	assert_almost_eq(Course.bearing_deg(Vector2.ZERO, steps[2].in_dir), 42.0, 0.01, "The gate is crossed running down")
	assert_eq(steps[5].out_dir, steps[5].in_dir, "The finish: the last leg's direction")
	assert_eq(RaceSim.new(course, 2).steps().size(), 10, "Two laps: 1, the gate, 1 and 4S twice")


func test_the_steps_of_pd3() -> void:
	var course: Course = CourseTemplates.build("PD3", _rules, 15.0, 24, 300.0, Vector2(100.0, 200.0))
	_assert_steps(RaceSim.new(course).steps(), ["Start", "1", "2", "3", "Finish"],
		[RaceStep.Kind.START, RaceStep.Kind.MARK, RaceStep.Kind.MARK, RaceStep.Kind.MARK, RaceStep.Kind.FINISH],
		[CourseMark.Rounding.NONE, CourseMark.Rounding.STARBOARD, CourseMark.Rounding.PORT, CourseMark.Rounding.STARBOARD,
			CourseMark.Rounding.NONE])


# ---------------------------------------------------------------- helpers

## The course of the header.
func _course() -> Course:
	var course: Course = Course.new()
	course.add_mark(CourseMark.START_BOAT, Vector2(30.0, 0.0))
	course.add_mark(CourseMark.START_PIN, Vector2(-30.0, 0.0))
	course.add_mark("1", Vector2(0.0, -300.0), CourseMark.Rounding.PORT)
	course.add_mark("4S", Vector2(-20.0, -50.0), CourseMark.Rounding.STARBOARD)
	course.add_mark("4P", Vector2(20.0, -50.0), CourseMark.Rounding.PORT)
	course.add_mark(CourseMark.FINISH_BOAT, Vector2(-100.0, -70.0))
	course.add_mark(CourseMark.FINISH_PIN, Vector2(-100.0, -30.0))
	assert_eq(course.set_sequence("Start-1-4S/4P-Finish"), "")
	return course


## A lap from 4 m behind the start line: over the line at 4 m, up the east side of mark 1 and across
## its top going west 10 m above it (324 m), down the west side through the gate (594 m), and west
## over the finish line (694 m).
func _lap() -> Array[Vector2]:
	return [Vector2(10.0, 4.0), Vector2(10.0, 0.0), Vector2(10.0, -310.0), Vector2(0.0, -310.0), Vector2(-10.0, -310.0),
		Vector2(-10.0, -50.0), Vector2(-10.0, -40.0), Vector2(-100.0, -40.0), Vector2(-120.0, -40.0)]


## A started race on the course of the header with some boards.
func _race(boards: int, laps: int = 1) -> RaceSim:
	var race: RaceSim = RaceSim.new(_course(), laps, PRESTART_S)
	for i: int in boards:
		race.add_board(NAMES[i])
	race.start()
	return race


## Runs the race on up to (not including) a tick. At tick k board i is at tracks[i][k], or at the
## end of its track once it has sailed it.
func _run_to(race: RaceSim, tracks: Array[PackedVector2Array], until_tick: int) -> void:
	while _tick < until_tick:
		for i: int in tracks.size():
			race.update_board(i, tracks[i][mini(_tick, tracks[i].size() - 1)])
		race.step(DT)
		_tick += 1


## A board that waits through the countdown and sails away at the gun along a path, starting
## offset_m along it.
func _from_the_gun(points: Array[Vector2], offset_m: float = 0.0) -> PackedVector2Array:
	var sailed: PackedVector2Array = _path(points, offset_m)
	var track: PackedVector2Array = _hold(sailed[0], COUNTDOWN_TICKS - 1)
	track.append_array(sailed)
	return track


## A board that stays at a point for some ticks.
func _hold(point: Vector2, ticks: int) -> PackedVector2Array:
	var track: PackedVector2Array = PackedVector2Array()
	for _k: int in ticks:
		track.append(point)
	return track


## A board's track along a path: a point every STEP_M, starting offset_m along it.
func _path(points: Array[Vector2], offset_m: float = 0.0) -> PackedVector2Array:
	var total_m: float = 0.0
	for i: int in range(1, points.size()):
		total_m += points[i - 1].distance_to(points[i])
	var track: PackedVector2Array = PackedVector2Array()
	var along_m: float = offset_m
	while along_m <= total_m + 1e-6:
		track.append(_point_along(points, along_m))
		along_m += STEP_M
	return track


func _point_along(points: Array[Vector2], along_m: float) -> Vector2:
	var left_m: float = along_m
	for i: int in range(1, points.size()):
		var length_m: float = points[i - 1].distance_to(points[i])
		if left_m <= length_m:
			return points[i - 1].lerp(points[i], left_m / length_m)
		left_m -= length_m
	return points[-1]


func _assert_times(got: PackedFloat32Array, expected: Array[float], message: String) -> void:
	assert_eq(got.size(), expected.size(), message + ": %s" % got)
	for i: int in mini(got.size(), expected.size()):
		assert_almost_eq(got[i], expected[i], 1e-3, "%s: split %d" % [message, i])


func _assert_steps(steps: Array[RaceStep], ids: Array[String], kinds: Array[RaceStep.Kind], sides: Array[CourseMark.Rounding]) -> void:
	assert_eq(steps.size(), ids.size())
	for i: int in mini(steps.size(), ids.size()):
		assert_eq(steps[i].id, ids[i])
		assert_eq(steps[i].kind, kinds[i], "%s: the kind" % ids[i])
		assert_eq(steps[i].side, sides[i], "%s: the side" % ids[i])
