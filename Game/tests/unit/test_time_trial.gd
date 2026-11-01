extends GutTest
## The time trial (ROADMAP GP4, GD5): a course sailed alone against your own best, the best kept
## per water, course and wind (TimeTrialRecords), the Race page's "You alone" fleet, and the race
## HUD's words. The runner's finish check needs the scene and is looked at with a screenshot.

const TEST_PATH: String = "user://test_time_trials.cfg"


func after_each() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


func test_the_first_finish_is_the_best_and_only_a_faster_one_replaces_it() -> void:
	var records: TimeTrialRecords = TimeTrialRecords.new()
	records.load_from(TEST_PATH)
	var key: String = TimeTrialRecords.make_key("open", "template:slalom_2@50", "18 kt")
	assert_lt(records.best_s(key), 0.0, "no best yet")
	assert_true(records.remember(key, 480.5, PackedFloat32Array([0.0, 120.0, 480.5]), "2026-10-31"), "the first time is the best")
	assert_false(records.remember(key, 490.0, PackedFloat32Array([0.0, 130.0, 490.0]), "2026-11-01"), "a slower one is not")
	assert_almost_eq(records.best_s(key), 480.5, 1e-6)
	assert_eq(records.best_date(key), "2026-10-31", "the first date stays while nobody is faster")
	# The dates are given, not today's: the test must pass on any day.
	assert_true(records.remember(key, 470.0, PackedFloat32Array([0.0, 118.0, 470.0]), "2026-11-02"), "a faster one is")
	assert_almost_eq(records.best_s(key), 470.0, 1e-6)
	assert_eq(records.best_splits(key), PackedFloat32Array([0.0, 118.0, 470.0]))
	# Saved: a fresh load reads it back, and another wind is its own record.
	var again: TimeTrialRecords = TimeTrialRecords.new()
	again.load_from(TEST_PATH)
	assert_almost_eq(again.best_s(key), 470.0, 1e-6, "kept in the file")
	assert_eq(again.best_splits(key).size(), 3)
	assert_eq(again.best_date(key), "2026-11-02", "the faster run brings its own date")
	assert_lt(again.best_s(TimeTrialRecords.make_key("open", "template:slalom_2@50", "24 kt")), 0.0, "another wind is another record")


func test_the_gap_to_the_best_at_a_step() -> void:
	var best: PackedFloat32Array = PackedFloat32Array([0.0, 120.0, 480.0])
	assert_eq(TimeTrialRecords.gap_text(PackedFloat32Array([0.0, 122.3]), best), "+2.3 s", "behind the best at the first mark")
	assert_eq(TimeTrialRecords.gap_text(PackedFloat32Array([0.0, 118.0, 470.0]), best), "-10.0 s", "ahead at the finish")
	assert_eq(TimeTrialRecords.gap_text(PackedFloat32Array(), best), "", "nothing yet")
	assert_eq(TimeTrialRecords.gap_text(PackedFloat32Array([0.0, 1.0, 2.0, 3.0]), best), "", "a step the best never recorded")


func test_the_race_pages_first_fleet_is_you_alone_and_the_setup_says_time_trial() -> void:
	assert_eq(RacePage.FLEET_SIZES[0], 0, "the first choice is you alone")
	assert_true(RacePage.fleet_names(RacePage.Who.PERSONAS, 0).is_empty(), "no AI boards")
	assert_eq(RacePage.fleet_names(RacePage.Who.PERSONAS, 3).size(), 3)
	var setup: RaceSetup = RaceSetup.race("t1_loop", PackedStringArray(), 1, 30.0)
	assert_false(setup.time_trial, "a race setup is not a time trial by itself")
	setup.time_trial = true
	assert_true(setup.skippers.is_empty())


func test_the_huds_words_for_a_time_trial() -> void:
	assert_eq(RaceHud.time_trial_race_text(201.4, -1.0), "time trial   3:21.4   no best yet")
	assert_eq(RaceHud.time_trial_race_text(201.4, 478.1), "time trial   3:21.4   best 7:58.1")
	assert_eq(RaceHud.time_trial_finish_text(470.3, true, 478.1), "finished in 7:50.3   a new best! (was 7:58.1)")
	assert_eq(RaceHud.time_trial_finish_text(470.3, true, -1.0), "finished in 7:50.3   your first time here: the one to beat")
	assert_eq(RaceHud.time_trial_finish_text(485.2, false, 478.1), "finished in 8:05.2   +7.1 s on your best 7:58.1")


func test_the_runner_keeps_the_best_at_the_finish() -> void:
	var setup: RaceSetup = RaceSetup.race("t1_loop", PackedStringArray(), 1, 5.0)
	setup.time_trial = true
	setup.records_path = TEST_PATH
	RaceSetup.pending = setup
	var scene: SailingScene = (load("res://main.tscn") as PackedScene).instantiate()
	add_child_autofree(scene)
	var runner: RaceRunner = scene.get_node("RaceRunner")
	assert_not_null(runner, "a race of one is set up")
	assert_true(runner.setup.time_trial)
	assert_eq(runner.record_key, "open|T1 training loop|18 kt", "the water, the course and the settings' wind")
	assert_eq(runner.race.board_count(), 1, "you alone")
	# Teleported over the finish: the runner checks the time against the best (none yet) and keeps it.
	runner.race.place_board(0, Vector2.ZERO, runner.race.steps().size())
	runner._process(1.0 / 60.0)
	var records: TimeTrialRecords = TimeTrialRecords.new()
	records.load_from(TEST_PATH)
	assert_almost_eq(records.best_s(runner.record_key), runner.race.finish_time_s(0), 1e-6, "the first finish is the best")
	assert_true(runner.hud._record_is_best, "the HUD is told it is the best")
	runner._process(1.0 / 60.0)
	assert_true(runner._record_checked, "checked once per run")
