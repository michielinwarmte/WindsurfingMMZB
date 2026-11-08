extends GutTest
## A skipper set up again on a new race (the game's R, RaceRunner.restart(); Max, 8 November 2026: "if I press R
## the AI lost their minds"): nothing timed in the race before still holds it back. Its own clock runs on across
## races, so a tack it asks for in the new race comes after its reaction time, however long the race before
## lasted. (Its clock used to start again at 0 while the last manoeuvre's end stayed where it was, minutes ahead:
## no tack or gybe came for as long as the race before had lasted.)

const RunRace: GDScript = preload("res://dev/run_race.gd")


func test_a_skipper_set_up_again_after_a_long_race_tacks_at_once() -> void:
	var course: Course = RaceCourses.t1_loop(270.0, Vector2.ZERO)
	var race: RaceSim = RaceSim.new(course, 1, 10.0)
	var entries: Array = RunRace.make_entries(race, course, PackedStringArray(["allrounder"]), 15.0, 50.0, 1)
	var skipper: Skipper = entries[0].skipper as Skipper
	# Ten minutes of the race before: its last gybe ended near the end of it, and its timers were running.
	skipper._time_s = 600.0
	skipper._manoeuvre_ended_s = 598.0
	skipper._traffic_seen_s = 599.0
	skipper._traffic_wait_from_s = 597.0
	skipper._dirty_since_s = 599.0
	skipper._penalty_owed_s = 590.0
	skipper._holding_since_s = 595.0
	# R: a new race on the same course, the board's controls reset, the same skipper set up again on it.
	var again: RaceSim = RaceSim.new(course, 1, 10.0)
	again.add_board("All-rounder")
	again.update_board(0, Vector2(skipper._sim.telemetry.position.x, skipper._sim.telemetry.position.z))
	skipper._controller.reset_controls(SimControls.new())
	skipper.setup(skipper._sim, skipper._controller, skipper._hands, again, 0)
	assert_gte(skipper._time_s, 600.0, "its clock runs on across the races")
	assert_eq(skipper._manoeuvre_ended_s, -INF, "no manoeuvre of the race before")
	assert_eq(skipper._dirty_since_s, -1.0, "no dirty air of the race before")
	assert_eq(skipper._penalty_owed_s, -1.0, "no penalty owed from the race before")
	assert_eq(skipper._holding_since_s, -1.0, "no hold-back of the race before")
	assert_eq(skipper.state, Skipper.State.FREE_SAILING, "the new race not started yet")
	# A tack or gybe asked for now is due after the reaction time.
	skipper._ask_for_manoeuvre(true, true)
	assert_gte(skipper._tack_due_s, 0.0, "a manoeuvre asked for in the new race is due")
	assert_lt(skipper._tack_due_s - skipper._time_s, 2.0, "after the reaction time, not minutes later")


func test_the_games_r_lets_the_ai_tack_at_once() -> void:
	var saved_values: SettingsValues = GameSettings.values
	var saved_path: String = GameSettings.path
	GameSettings.values = SettingsValues.new()
	GameSettings.path = ""
	RaceSetup.pending = RaceSetup.race("t1_loop", PackedStringArray(["allrounder"]))
	var scene: SailingScene = (load("res://main.tscn") as PackedScene).instantiate()
	add_child_autofree(scene)
	var runner: RaceRunner = scene.get_node("RaceRunner")
	await wait_physics_frames(2)
	var skipper: Skipper = runner.opponents[0].skipper as Skipper
	# As after ten minutes of racing, its last gybe just ended.
	skipper._time_s = 600.0
	skipper._manoeuvre_ended_s = 598.0
	# R, as the player presses it (the scene's own restart: RaceRunner.restart() sets the skipper up again).
	scene._restart_run()
	assert_gte(skipper._time_s, 600.0, "its clock runs on")
	assert_eq(skipper._manoeuvre_ended_s, -INF, "no manoeuvre of the race before")
	skipper._ask_for_manoeuvre(true, true)
	assert_gte(skipper._tack_due_s, 0.0, "after R a manoeuvre asked for is due")
	assert_lt(skipper._tack_due_s - skipper._time_s, 2.0, "after the reaction time")
	await wait_physics_frames(2)
	GameSettings.values = saved_values
	GameSettings.path = saved_path
	get_tree().paused = false
