extends GutTest
## The race's smart order (RaceSim.set_wind(), time_to_finish_s(); Max, 12 November 2026: "the leaderboard
## is not correctly calculated. please keep the wind polar in consideration. make a smart leaderboard with
## laylines kept in mind"): once the gun has gone and the race knows the wind, the boards still racing are
## ranked by the polar's time to the finish, with the laylines; the standings' gaps are the differences of
## the expected finishes (RaceHud.gap_between()).
##
## The course, for a wind from the north (upwind is -Z): the start line on z = 0 (60 m), mark 1 400 m
## upwind at (0, -400), mark 2 back down at (0, -50), the finish line across z = 0 again. The polar is the
## game's (Game/config/skipper_polar.tres): in 18 kt the best beating angle 55 degrees (the laylines run
## 55 degrees off the wind from the mark), the best running angle 130 degrees. The boards' places are single
## precision, so times that are the same agree to a millisecond.

const WIND_FROM_DEG: float = 0.0
const WIND_KT: float = 18.0


func test_inside_the_laylines_a_boards_sideways_place_costs_nothing() -> void:
	# Both 300 m below mark 1, one straight below it, one 150 m out to the side (the layline is 428 m out).
	var race: RaceSim = _racing([Vector2(0.0, -100.0), Vector2(150.0, -100.0)])
	assert_almost_eq(race.time_to_finish_s(0), race.time_to_finish_s(1), 1e-3, "both tacks get there in the same time")
	assert_gt(race.time_to_finish_s(0), 0.0)


func test_a_board_out_to_the_side_but_higher_is_ahead_though_farther_from_the_mark() -> void:
	# Board 0 straight below the mark, 300 m from it; board 1 120 m out to the side and 20 m higher:
	# 305 m from the mark in a straight line but only 280 m to go toward the wind. The plain distance put it behind.
	var race: RaceSim = _racing([Vector2(0.0, -100.0), Vector2(120.0, -120.0)])
	assert_gt(race.distance_to_next_m(1), race.distance_to_next_m(0), "farther from the mark")
	assert_eq(race.race_order(), [1, 0] as Array[int], "the higher board leads")
	assert_lt(race.time_to_finish_s(1), race.time_to_finish_s(0))


func test_a_board_past_the_layline_is_behind_one_inside_at_the_same_height() -> void:
	# Both 100 m below the mark; board 0 is 300 m out, past the layline (143 m out at that height), so it
	# must sail a wider, slower angle to the mark than the polar's best.
	var race: RaceSim = _racing([Vector2(300.0, -300.0), Vector2(100.0, -300.0)])
	assert_eq(race.race_order(), [1, 0] as Array[int], "inside the layline leads")
	assert_gt(race.time_to_finish_s(0), race.time_to_finish_s(1) + 3.0, "overstanding costs seconds")


func test_a_board_that_rounded_the_mark_is_ahead_of_one_that_has_not() -> void:
	# Board 0 has rounded mark 1 and runs down to mark 2, 5 m below it; board 1 is still 10 m below mark 1.
	var race: RaceSim = _racing([Vector2(5.0, -395.0), Vector2(0.0, -390.0)], [2, 1])
	assert_eq(race.race_order(), [0, 1] as Array[int])


func test_a_standing_penalty_counts_in_the_order() -> void:
	# Two boards level; board 0 has a 20 s penalty standing.
	var race: RaceSim = _racing([Vector2(0.0, -100.0), Vector2(10.0, -100.0)])
	race.set_time_penalty_s(0, 20.0)
	assert_eq(race.race_order(), [1, 0] as Array[int])
	assert_almost_eq(race.time_to_finish_s(0) - race.time_to_finish_s(1), 20.0, 1e-3)


func test_the_countdown_and_a_race_without_the_wind_keep_the_plain_order() -> void:
	var race: RaceSim = _race_with_boards(2, 10.0)
	race.set_wind(WIND_FROM_DEG, WIND_KT)
	race.start()
	race.place_board(0, Vector2(0.0, 5.0), 0)
	race.place_board(1, Vector2(20.0, 30.0), 0)
	assert_false(race.ranks_by_time(), "not before the gun")
	assert_true(is_nan(race.time_to_finish_s(0)))
	assert_eq(race.race_order(), [0, 1] as Array[int], "nearest the line first")
	var no_wind: RaceSim = _race_with_boards(2, 0.0)
	no_wind.start()
	no_wind.place_board(0, Vector2(0.0, -100.0), 1)
	no_wind.place_board(1, Vector2(120.0, -120.0), 1)
	assert_false(no_wind.ranks_by_time(), "the race tool's races do not know the wind")
	assert_eq(no_wind.race_order(), [0, 1] as Array[int], "by the distance to the mark, as before")


func test_the_expected_finish_is_the_finish_once_in_and_the_gaps_are_their_differences() -> void:
	var race: RaceSim = _racing([Vector2(0.0, -100.0), Vector2(0.0, -200.0), Vector2(0.0, 0.0)], [1, 1, 4])
	assert_true(race.is_finished(2))
	assert_almost_eq(race.expected_finish_s(2), race.finish_time_s(2), 1e-6, "the finish, once in")
	assert_almost_eq(race.expected_finish_s(0), race.race_time_s() + race.time_to_finish_s(0), 1e-6)
	var gap: String = RaceHud.gap_between(race, 0, 1)
	assert_eq(gap, "%+.1f s" % (race.expected_finish_s(0) - race.expected_finish_s(1)))
	assert_string_starts_with(gap, "+", "100 m lower on the beat: behind")
	assert_string_starts_with(RaceHud.gap_between(race, 2, 1), "-", "the finished board: ahead")


func test_a_run_counts_the_way_away_from_the_wind() -> void:
	# Both running down to mark 2 at (0, -50) from 300 m above it: one straight above, one 150 m out (the
	# run's laylines are 50 degrees either side of dead downwind: 358 m out at that height).
	var race: RaceSim = _racing([Vector2(0.0, -350.0), Vector2(150.0, -350.0)], [2, 2])
	assert_almost_eq(race.time_to_finish_s(0), race.time_to_finish_s(1), 1e-3, "inside the run's laylines: the same")


func test_the_legs_after_each_step_add_up_to_the_course() -> void:
	var race: RaceSim = _race_with_boards(1, 0.0)
	var polar: SkipperPolar = SkipperPolar.default_polar()
	var after: PackedFloat64Array = RaceSim.legs_after_s(race.steps(), WIND_FROM_DEG, WIND_KT, polar)
	assert_eq(after.size(), race.steps().size())
	assert_almost_eq(after[after.size() - 1], 0.0, 1e-9, "nothing after the finish")
	assert_almost_eq(after[0], RaceTimeLimit.course_time_s(race.steps(), WIND_FROM_DEG, WIND_KT, polar), 1e-6, "the whole course from the start")


# ---------------------------------------------------------------- helpers

func _course() -> Course:
	var course: Course = Course.new()
	course.add_mark(CourseMark.START_BOAT, Vector2(30.0, 0.0))
	course.add_mark(CourseMark.START_PIN, Vector2(-30.0, 0.0))
	course.add_mark("1", Vector2(0.0, -400.0), CourseMark.Rounding.PORT)
	course.add_mark("2", Vector2(0.0, -50.0), CourseMark.Rounding.PORT)
	course.add_mark(CourseMark.FINISH_BOAT, Vector2(30.0, 10.0))
	course.add_mark(CourseMark.FINISH_PIN, Vector2(-30.0, 10.0))
	assert_eq(course.set_sequence("Start-1-2-Finish"), "")
	return course


func _race_with_boards(count: int, prestart_s: float) -> RaceSim:
	var race: RaceSim = RaceSim.new(_course(), 1, prestart_s)
	for i: int in count:
		race.add_board("Board %d" % i)
	return race


## A race under way (no countdown: the gun has gone) that knows the 18 kt north wind, its boards at these
## places, each sailing to its step (`next_steps`; mark 1 by default; the steps' count: finished).
func _racing(places: Array[Vector2], next_steps: Array[int] = []) -> RaceSim:
	var race: RaceSim = _race_with_boards(places.size(), 0.0)
	race.set_wind(WIND_FROM_DEG, WIND_KT)
	race.start()
	for i: int in places.size():
		race.place_board(i, places[i], next_steps[i] if i < next_steps.size() else 1)
	assert_true(race.ranks_by_time())
	return race
