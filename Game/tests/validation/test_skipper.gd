extends GutTest
## The scripted skipper (RACING_PLAN.md, Part 9B): its character sheets, the geometry of its
## decisions, its steering, and real races sailed the way tools/race.sh sails them (the open water's
## default simulation with its waves, the beginner controller with the skipper's hands on it):
##   - the all-rounder alone on T1 at 12, 18 and 24 kt finishes, never falls, and lays mark 1 within
##     its cap of tacks; at 18 kt it crosses the start line within 3 s after the gun;
##   - the same race with the same seed gives the same finish time;
##   - the rookie on T1 at 18 kt finishes after the all-rounder;
##   - the all-rounder on T2 rounds every mark within 20 m of it and finishes;
##   - the cautious skipper is not over the line at the gun, in 3 seeds.
## The races are sailed once, together, on worker threads (before_all()), and the tests look at
## them: each race is a set of objects of its own, so they can be stepped side by side. The longest
## (T1 at 12 kt, about 12 minutes of racing) sets the time this file takes.
##
## The finish times allowed are what this board can do on T1, not RACING_PLAN.md's guess of three
## minutes a lap: T1 is two beats of 556 m and 405 m and two runs of 405 m, and on the open water's
## sea the best way to windward is 2.9 m/s at 12 kt and 3.9 to 4.1 m/s at 18 and 24 kt, so the beats
## alone take 5.6 and 4 minutes.

const RunRace: GDScript = preload("res://dev/run_race.gd")
const DT: float = 1.0 / 60.0
## The game's countdown: the skippers wait 150 m behind the line.
const PRESTART_S: float = 60.0
## The longest any of these races may take after the gun, seconds.
const RACE_LIMIT_S: float = 900.0
## The finish times allowed for the all-rounder on T1, seconds, by wind (kt).
const T1_LIMIT_S: Dictionary[int, float] = {12: 720.0, 18: 480.0, 24: 510.0}


## One race: what is raced, and what the tests need to know of it afterwards.
class Run:
	var course: Course
	var who: PackedStringArray
	var wind_kt: float = 18.0
	var random_seed: int = 0
	## Stop this long after the gun, seconds (the start tests need no more); INF races to the end.
	var stop_after_gun_s: float = INF
	var race: RaceSim
	var entries: Array[RunRace.Entry] = []
	## For each board, for each step: the nearest it came to the step's mark while sailing to it,
	## metres (INF for a line).
	var nearest_m: Array[PackedFloat32Array] = []
	## For each board: whether it was over the line at the gun or after it (OCS).
	var ever_ocs: Array[bool] = []

	## The race set up for its countdown, on the main thread (it loads the configuration files).
	func setup() -> void:
		race = RaceSim.new(course, 1, PRESTART_S)
		race.finish_window_s = RACE_LIMIT_S
		entries = RunRace.make_entries(race, course, who, wind_kt, 50.0, random_seed)
		for i: int in entries.size():
			var nearest: PackedFloat32Array = PackedFloat32Array()
			nearest.resize(race.steps().size())
			nearest.fill(INF)
			nearest_m.append(nearest)
			ever_ocs.append(false)
		race.start()

	## Sails the race to its end (or to stop_after_gun_s): on a worker thread.
	func sail() -> void:
		var ticks: int = roundi((PRESTART_S + RACE_LIMIT_S) / DT)
		for _tick: int in ticks:
			RunRace.step_race(race, entries)
			for i: int in entries.size():
				_watch(i)
			if race.phase() == RaceSim.Phase.FINISHED or race.clock_s() >= stop_after_gun_s:
				break

	func _watch(i: int) -> void:
		if race.clock_s() >= 0.0 and race.is_ocs(i):
			ever_ocs[i] = true
		var step: RaceStep = race.next_step(i)
		if step != null and step.kind == RaceStep.Kind.MARK:
			var number: int = race.next_step_index(i)
			nearest_m[i][number] = minf(nearest_m[i][number], race.board_position(i).distance_to(step.points[0]))

	func skipper(i: int) -> Skipper:
		return entries[i].skipper

	func falls(i: int) -> int:
		return entries[i].falls


var _runs: Dictionary[String, Run] = {}


func before_all() -> void:
	var t1: Course = RunRace.course_named("t1_loop")
	var t2: Course = RunRace.course_named("t2_slalom")
	_add("t1 12", t1, ["allrounder"], 12.0)
	_add("t1 18", t1, ["allrounder"], 18.0)
	_add("t1 18 again", t1, ["allrounder"], 18.0)
	_add("t1 24", t1, ["allrounder"], 24.0)
	_add("rookie t1 18", t1, ["rookie"], 18.0)
	_add("t2 18", t2, ["allrounder"], 18.0)
	for random_seed: int in [1, 2, 3]:
		_add("cautious start %d" % random_seed, t1, ["cautious"], 18.0, random_seed, 10.0)
	# All the races at once, each on a worker thread of its own.
	var tasks: Array[int] = []
	for key: String in _runs:
		tasks.append(WorkerThreadPool.add_task(_runs[key].sail, true, key))
	for task: int in tasks:
		WorkerThreadPool.wait_for_task_completion(task)
	# The results, for the log: what the tests below look at.
	for key: String in _runs:
		var run: Run = _runs[key]
		for result: RaceResult in run.race.results():
			print("%-18s %s  falls %d" % [key, result.to_line(), run.falls(result.index)])


func _add(key: String, course: Course, who: PackedStringArray, wind_kt: float, random_seed: int = 0, stop_after_gun_s: float = INF) -> void:
	var run: Run = Run.new()
	run.course = course
	run.who = who
	run.wind_kt = wind_kt
	run.random_seed = random_seed
	run.stop_after_gun_s = stop_after_gun_s
	run.setup()
	_runs[key] = run


# ---------------------------------------------------------------- the character sheets

func test_the_four_characters_load_with_the_polars_angles() -> void:
	var names: PackedStringArray = Skippers.names()
	for wanted: String in ["allrounder", "cautious", "gambler", "rookie"]:
		assert_true(names.has(wanted), "There is a character sheet called %s" % wanted)
	var shown: PackedStringArray = PackedStringArray()
	for skipper_name: String in names:
		var config: SkipperConfig = Skippers.load_config(skipper_name)
		assert_not_null(config, skipper_name)
		# POLAR_15KT.md: the best way to windward at 45 degrees, the best way downwind at 135.
		assert_eq(config.upwind_vmg_twa_deg, 45.0, "%s sails the polar's best upwind angle" % skipper_name)
		assert_eq(config.downwind_vmg_twa_deg, 135.0, "%s sails the polar's best downwind angle" % skipper_name)
		assert_false(shown.has(config.name), "Each character has a name of its own: %s" % config.name)
		shown.append(config.name)
	var rookie: SkipperConfig = Skippers.load_config("rookie")
	var allrounder: SkipperConfig = Skippers.load_config("allrounder")
	assert_gt(rookie.reaction_time_s, allrounder.reaction_time_s, "The rookie reacts later")
	assert_gt(rookie.steering_noise_deg, allrounder.steering_noise_deg, "The rookie's helm is noisier")
	assert_gt(Skippers.load_config("cautious").start_timing_error_s, 2.0, "The cautious one starts late")
	assert_lt(Skippers.load_config("gambler").start_timing_error_s, 0.0, "The gambler starts early")


func test_a_skipper_is_made_from_a_character_sheets_name() -> void:
	var skipper: Skipper = Skippers.make("allrounder")
	assert_not_null(skipper)
	assert_eq(skipper.config.name, "All-rounder")


# ---------------------------------------------------------------- the geometry of its decisions

func test_a_port_windward_mark_is_approached_on_starboard_and_a_starboard_leeward_mark_too() -> void:
	# T1's mark 1, the wind from the west: the beat comes in going west and leaves going east, the
	# mark to port. On port tack going round it to the left would be a tack; on starboard it is
	# bearing away.
	var windward: RaceStep = _mark_step(Vector2(-1.0, 0.0), Vector2(1.0, 0.0), CourseMark.Rounding.PORT)
	assert_eq(Skipper._approach_tack(windward, 270.0, 45.0), 1.0, "Starboard tack into a port windward mark")
	# T1's 4S: the run comes in going east and leaves going south, the mark to starboard. On port tack
	# the turn to the right would be a gybe.
	var leeward: RaceStep = _mark_step(Vector2(1.0, 0.0), Vector2(0.0, 1.0), CourseMark.Rounding.STARBOARD)
	assert_eq(Skipper._approach_tack(leeward, 270.0, 135.0), 1.0, "Starboard tack into a starboard leeward mark")
	# A mark passed going north on a beam reach in a west wind: the reach's own tack, port (the
	# starboard tack's beam reach goes south).
	var straight: RaceStep = _mark_step(Vector2(0.0, -1.0), Vector2(0.0, -1.0), CourseMark.Rounding.PORT)
	assert_eq(Skipper._approach_tack(straight, 270.0, 90.0), -1.0, "The beam reach's own tack")


func test_the_layline_is_where_the_other_tack_would_lay_the_target() -> void:
	# The wind from the north (0 degrees), the target 100 m upwind, tracks 45 degrees off the wind.
	# On starboard tack (heading north-west) the board passes the port tack's layline at x = -100.
	var target: Vector2 = Vector2(0.0, -100.0)
	assert_almost_eq(Skipper._past_layline_m(Vector2(-50.0, 0.0), target, 0.0, 1.0, 45.0), -50.0 * cos(PI / 4.0), 0.01, "Half-way there")
	assert_almost_eq(Skipper._past_layline_m(Vector2(-100.0, 0.0), target, 0.0, 1.0, 45.0), 0.0, 0.01, "On the layline")
	assert_gt(Skipper._past_layline_m(Vector2(-120.0, 0.0), target, 0.0, 1.0, 45.0), 0.0, "Past it")


# ---------------------------------------------------------------- the races

func test_the_allrounder_finishes_t1_without_a_fall_in_12_18_and_24_kt() -> void:
	for wind: int in [12, 18, 24]:
		var run: Run = _runs["t1 %d" % wind]
		var skipper: Skipper = run.skipper(0)
		assert_true(run.race.is_finished(0), "Finished at %d kt" % wind)
		assert_lt(run.race.finish_time_s(0), T1_LIMIT_S[wind], "In time at %d kt: %s" % [wind, RaceResult.format_time(run.race.finish_time_s(0))])
		assert_eq(run.falls(0), 0, "No fall at %d kt" % wind)
		assert_lte(skipper.manoeuvres_on_step(1), skipper.config.max_tacks_per_beat, "Mark 1 laid within the cap of tacks at %d kt" % wind)


func test_the_allrounder_crosses_the_start_line_within_3_s_after_the_gun() -> void:
	var run: Run = _runs["t1 18"]
	var start_s: float = run.race.splits_s(0)[0]
	assert_between(start_s, 0.0, 3.0, "Started at %.1f s" % start_s)
	assert_false(run.ever_ocs[0], "Not over the line at the gun")


func test_the_same_seed_gives_the_same_race() -> void:
	var first: Run = _runs["t1 18"]
	var second: Run = _runs["t1 18 again"]
	assert_eq(first.race.finish_time_s(0), second.race.finish_time_s(0), "The same finish time")
	assert_eq(first.race.board_position(0), second.race.board_position(0), "And the same place at the end")


func test_the_rookie_finishes_after_the_allrounder_in_18_kt() -> void:
	var rookie: Run = _runs["rookie t1 18"]
	var allrounder: Run = _runs["t1 18"]
	assert_true(rookie.race.is_finished(0), "The rookie finishes")
	assert_gt(rookie.race.finish_time_s(0), allrounder.race.finish_time_s(0), "After the all-rounder: %s against %s" % [
		RaceResult.format_time(rookie.race.finish_time_s(0)), RaceResult.format_time(allrounder.race.finish_time_s(0))])


func test_on_t2_the_allrounder_rounds_every_mark_within_20_m_and_finishes() -> void:
	var run: Run = _runs["t2 18"]
	assert_true(run.race.is_finished(0), "Finished")
	assert_eq(run.falls(0), 0, "No fall")
	var steps: Array[RaceStep] = run.race.steps()
	for number: int in steps.size():
		if steps[number].kind == RaceStep.Kind.MARK:
			assert_lt(run.nearest_m[0][number], 20.0, "%s rounded %.1f m from it" % [steps[number].name, run.nearest_m[0][number]])


func test_the_cautious_skipper_is_not_over_the_line_at_the_gun_in_3_seeds() -> void:
	for random_seed: int in [1, 2, 3]:
		var run: Run = _runs["cautious start %d" % random_seed]
		assert_false(run.ever_ocs[0], "Seed %d: not over the line at the gun" % random_seed)


# ---------------------------------------------------------------- helpers

## A mark step at the origin with the legs in and out going the given ways (game X, Z).
static func _mark_step(in_dir: Vector2, out_dir: Vector2, side: CourseMark.Rounding) -> RaceStep:
	var step: RaceStep = RaceStep.new()
	step.kind = RaceStep.Kind.MARK
	step.points = PackedVector2Array([Vector2.ZERO])
	step.in_dir = in_dir
	step.out_dir = out_dir
	step.side = side
	return step
