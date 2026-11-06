extends GutTest
## The race director (Documentation/reports/multiplayer/RACE_DIRECTOR.md): the race director's course
## taken into a race under way (only the marks' places; RaceSim.refresh_course()), a change of shape
## refused during a race and taken before the gun, a race abandoned, the next countdown planned after
## a race and moved (RaceDirector, with a stand-in for the race runner), the line on every screen,
## and a board's gear changed where it is (WindsurferNode.change_gear()).
##
## The course is small and drawn by hand, for a wind from the north (upwind is -Z): the start line
## on z = 0, mark 1 300 m upwind, the gate 4S/4P 50 m above the line, the finish line west of it.

const DT: float = 0.25
const PRESTART_S: float = 10.0
const SAIL_6_8_ID: String = "southsails_slalom_6_8"
const FREERACE_BOARD_ID: String = "forbidden_freerace_113"


## A race runner that only counts its starts (RaceDirector calls restart(true) for a race after a
## race); its race is a plain RaceSim.
class StandInRunner:
	extends RaceRunner
	var starts: int = 0
	var kept: bool = false
	var made: Course = null

	func restart(keep_places: bool = false) -> void:
		starts += 1
		kept = keep_places
		race = RaceSim.new(made, setup.laps, setup.prestart_s)
		race.add_board("Lena")
		race.start()
		restarted.emit()


# ---------------------------------------------------------------- the course in a race under way

func test_a_mark_moved_during_a_race_moves_the_step_and_every_board_keeps_its_progress() -> void:
	var race: RaceSim = _racing()
	var before: int = race.next_step_index(0)
	assert_eq(before, 1, "Lena has started and sails to mark 1")
	var moved: Course = _course()
	moved.mark("1").position = Vector2(40.0, -280.0)
	assert_true(race.has_same_steps_as(moved), "the same marks in the same order")
	assert_true(race.refresh_course(moved), "taken during the race")
	assert_eq(race.next_step_index(0), before, "still sailing to mark 1")
	assert_eq(race.next_step(0).points[0], Vector2(40.0, -280.0), "to mark 1 where it is now")
	assert_eq(race.next_target(0), Vector2(40.0, -280.0), "the HUD's arrow points there too")
	assert_eq(race.phase(), RaceSim.Phase.RACING)


func test_another_shape_is_refused_during_a_race_and_taken_before_the_gun() -> void:
	var race: RaceSim = _racing()
	var longer: Course = _course()
	longer.add_mark("2", Vector2(0.0, -150.0), CourseMark.Rounding.PORT)
	assert_eq(longer.set_sequence("Start-1-2-4S/4P-Finish"), "")
	assert_false(race.has_same_steps_as(longer), "a mark more")
	var steps_before: int = race.steps().size()
	assert_false(race.refresh_course(longer), "refused while racing")
	assert_eq(race.steps().size(), steps_before, "the race keeps its steps")
	var waiting: RaceSim = RaceSim.new(_course(), 1, PRESTART_S)
	waiting.add_board("Lena")
	waiting.start()
	waiting.step(DT)
	assert_true(waiting.refresh_course(longer), "taken in the countdown")
	assert_eq(waiting.steps().size(), steps_before + 1, "with its new mark")
	assert_eq(waiting.next_step_index(0), 0, "still on the way to the start")


func test_an_abandoned_race_is_over_with_nobody_finished() -> void:
	var race: RaceSim = _racing()
	race.end_now()
	assert_eq(race.phase(), RaceSim.Phase.FINISHED)
	assert_false(race.is_finished(0), "Lena did not finish")
	assert_eq(race.results().size(), 1)


func test_a_guest_shows_the_hosts_order_of_two_boards_nearly_level() -> void:
	var host: RaceSim = _racing()
	host.add_board("Joost")
	host.update_board(1, Vector2(-10.0, -5.2))  # 0.2 m further up than Lena: second on the host
	host.step(DT)
	var guest: RaceSim = RaceSim.new(_course(), 1, PRESTART_S)
	guest.add_board("Lena")
	guest.add_board("Joost")
	# The guest sees Joost a few ticks later than he is: ahead of Lena by its own measure.
	guest.update_board(0, Vector2(10.0, -5.0))
	guest.update_board(1, Vector2(-10.0, -9.0))
	guest.apply_state(host.to_state())
	assert_eq(guest.race_order(), host.race_order(), "the same places on every PC")
	assert_eq(guest.place(0), host.place(0))


# ---------------------------------------------------------------- the race after a race

func test_the_next_countdown_comes_the_gap_after_a_race_and_keeps_the_boards_where_they_are() -> void:
	var runner: StandInRunner = _stand_in_runner()
	var director: RaceDirector = _director(runner)
	director.set_gap_s(30.0)
	director._physics_process(DT)
	assert_eq(director.next_countdown_in_s, -1.0, "nothing planned while the race is on")
	runner.race.end_now()
	director._physics_process(DT)
	assert_almost_eq(director.next_countdown_in_s, 30.0, 1e-6, "planned the gap after the race")
	director.move_next_start(60.0)
	assert_almost_eq(director.next_countdown_in_s, 90.0, 1e-6, "a minute later")
	director.move_next_start(-600.0)
	assert_almost_eq(director.next_countdown_in_s, RaceDirector.SOONEST_S, 1e-6, "never sooner than in a few seconds")
	for _k: int in ceili(RaceDirector.SOONEST_S / DT) + 1:
		director._physics_process(DT)
	assert_eq(runner.starts, 1, "the new countdown has begun")
	assert_true(runner.kept, "with every board where it is")
	assert_eq(director.next_countdown_in_s, -1.0, "nothing planned while that race is on")


func test_the_director_starts_now_abandons_and_sets_the_next_race() -> void:
	var runner: StandInRunner = _stand_in_runner()
	var director: RaceDirector = _director(runner)
	director.abandon()
	assert_eq(runner.race.phase(), RaceSim.Phase.FINISHED, "abandoned")
	director._physics_process(DT)
	assert_true(director.next_countdown_in_s > 0.0, "the next one planned")
	director.set_countdown_s(180.0)
	director.set_laps(3)
	director.start_countdown_now()
	assert_eq(runner.starts, 1)
	assert_almost_eq(runner.race.prestart_s, 180.0, 1e-6, "the new countdown's length")
	assert_eq(runner.race.laps, 3, "the new laps")
	assert_eq(director.info()["laps"], 3, "the guests are told")


func test_the_line_on_every_screen() -> void:
	var waiting: Dictionary = {"next_in": 151.0, "note": ""}
	assert_eq(RaceDirector.notice_text(waiting, true, null), "Next race: the countdown begins in 2:31")
	assert_eq(RaceDirector.notice_text({"next_in": -1.0, "note": ""}, true, null), "", "nothing while racing")
	var joined_late: String = RaceDirector.notice_text({"next_in": -1.0, "note": ""}, false, null)
	assert_string_contains(joined_late, "you join it at the next start")
	assert_eq(RaceDirector.minutes(45.0), "45 s")
	assert_eq(RaceDirector.minutes(180.0), "3:00")


func test_the_director_refuses_a_course_without_its_lines() -> void:
	var runner: StandInRunner = _stand_in_runner()
	var director: RaceDirector = _director(runner)
	# The course maker never removes a line's end, but a course file edited by hand may lack one.
	var no_finish: Course = _course()
	no_finish.marks = no_finish.marks.filter(func(each: CourseMark) -> bool: return each.id != CourseMark.FINISH_PIN)
	assert_false(director.can_take(no_finish), "a race needs its finish line")
	var moved: Course = _course()
	moved.mark("1").position.x += 20.0
	assert_true(director.can_take(moved), "marks moved during a race")


# ---------------------------------------------------------------- gear between starts

func test_a_board_changes_gear_where_it_is() -> void:
	var node: WindsurferNode = (load(RaceRunner.WINDSURFER_SCENE) as PackedScene).instantiate()
	node.start_position = Vector3(120.0, 0.0, -40.0)
	node.start_heading_deg = 60.0
	add_child_autofree(node)
	node.sim.time_s = 12.5
	var heading_before: float = node.sim.telemetry.heading_deg
	node.change_gear(GearChoice.from_ids(FREERACE_BOARD_ID, SAIL_6_8_ID, ""))
	assert_almost_eq(node.sim.sail_config.area_m2, 6.8, 1e-6, "the new sail")
	assert_almost_eq(node.sim.board_config.volume_m3, 0.113, 1e-6, "the new board")
	assert_almost_eq(node.sim.telemetry.position.x, 120.0, 0.05, "where it was")
	assert_almost_eq(node.sim.telemetry.position.z, -40.0, 0.05, "where it was")
	assert_almost_eq(node.sim.telemetry.heading_deg, heading_before, 0.1, "heading the same way")
	assert_almost_eq(node.sim.time_s, 12.5, 1e-6, "on the same water clock")
	assert_eq(NetBoards.gear_ids(node), PackedStringArray([FREERACE_BOARD_ID, SAIL_6_8_ID, node.gear.fin.id()]))
	# The old rig and sailor go at the end of the frame.
	await get_tree().process_frame


# ---------------------------------------------------------------- helpers

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


## A race under way: Lena waited behind the line and crossed it after the gun.
func _racing() -> RaceSim:
	var race: RaceSim = RaceSim.new(_course(), 1, PRESTART_S)
	race.add_board("Lena")
	race.start()
	race.update_board(0, Vector2(10.0, 5.0))
	for _k: int in roundi(PRESTART_S / DT):
		race.step(DT)
	race.update_board(0, Vector2(10.0, -5.0))
	race.step(DT)
	return race


func _stand_in_runner() -> StandInRunner:
	var runner: StandInRunner = StandInRunner.new()
	runner.made = _course()
	runner.course = runner.made
	runner.setup = RaceSetup.race("t1_loop", PackedStringArray(), 1, 60.0)
	runner.race = _racing()
	autofree(runner)
	return runner


func _director(runner: RaceRunner) -> RaceDirector:
	var director: RaceDirector = RaceDirector.new()
	autofree(director)
	director.setup(runner, null)
	return director
