extends GutTest
## The trainer's random courses and drops (AI_FLEET_PLAN.md, D6b): every random course has a start,
## a finish and a sailable order and makes a race; the templates at random sizes do too; each stage's
## drops are where the stage says (below a windward mark for the beat, near a mark for the rounding,
## near a downwind mark or a gate for the run, just past the line for the laps, in the sailing area
## with the countdown for the start); the same seed gives the same race; and a scripted skipper can
## sail a stage's drop.


func test_every_kind_of_random_course_makes_a_race() -> void:
	var rules: CourseRules = load(TrainingDrops.RULES_PATH) as CourseRules
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	var kinds: Dictionary[String, int] = {}
	for k: int in 60:
		var course: Course = RandomCourses.draw(rng, rng.randf_range(10.0, 24.0), rules)
		assert_not_null(course.mark(CourseMark.START_BOAT), "a start line")
		assert_not_null(course.mark(CourseMark.FINISH_PIN), "a finish line")
		var race: RaceSim = RaceSim.new(course, 1, 0.0)
		assert_true(race.steps().size() >= 3, "%s: a start, a mark and a finish at least" % course.name)
		var line_m: float = course.mark(CourseMark.START_BOAT).position.distance_to(course.mark(CourseMark.START_PIN).position)
		assert_true(line_m >= RandomCourses.MIN_START_LINE_M - 0.01, "%s: the start line is at least 60 m: %.0f" % [course.name, line_m])
		var length: float = SailingDistance.course_length_m(race, course.axis_deg)
		assert_true(length > 400.0 and length < 12000.0, "%s: a sensible length by water: %.0f m" % [course.name, length])
		kinds[course.template] = kinds.get(course.template, 0) + 1
	assert_true(kinds.size() >= 6, "the draw gives templates and all three random shapes: %s" % str(kinds.keys()))


func test_a_stage_is_known_by_its_name_and_an_unknown_one_is_not() -> void:
	for name: String in TrainingDrops.NAMES:
		var stage: TrainingDrops.Stage = TrainingDrops.stage_named(name)
		assert_not_null(stage, name)
		assert_eq(stage.name, name)
		assert_true(stage.describe().begins_with(name))
	assert_null(TrainingDrops.stage_named("S9"))


func test_the_beats_drops_are_below_a_windward_mark_and_end_at_its_rounding() -> void:
	var stage: TrainingDrops.Stage = TrainingDrops.stage_named("S1")
	for seed: int in range(1, 9):
		var env: RaceEnv = TrainingDrops.make_env(stage, seed)
		assert_eq(env.board_count(), stage.boards)
		assert_eq(env.race.clock_s(), 0.0, "no countdown: the boards are started")
		for i: int in env.board_count():
			var k: int = env.race.next_step_index(i)
			var step: RaceStep = env.race.steps()[k]
			assert_eq(step.kind, RaceStep.Kind.MARK, "seed %d board %d: sailing to a mark" % [seed, i])
			var p: Vector3 = env.board(i).sim.telemetry.position
			var offset: Vector2 = Vector2(p.x, p.z) - step.points[0]
			var up: Vector2 = Course.direction_of(env.course.axis_deg)
			var across: Vector2 = Course.direction_of(env.course.axis_deg + 90.0)
			assert_between(-offset.dot(up), 150.0, 600.0, "150 to 600 m below the mark")
			assert_between(absf(offset.dot(across)), 0.0, 200.0, "up to 200 m to either side")
			assert_eq(env.board(i).goal_step, k + 1, "the episode ends at the rounding")
		assert_eq(env.options.episode_s, 90.0)
		assert_between(env.wind_kt, 10.0, 24.0)


func test_the_roundings_and_the_runs_drops_are_near_their_marks() -> void:
	for name: String in ["S2", "S3"]:
		var stage: TrainingDrops.Stage = TrainingDrops.stage_named(name)
		var gates: int = 0
		for seed: int in range(1, 9):
			var env: RaceEnv = TrainingDrops.make_env(stage, seed)
			for i: int in env.board_count():
				var k: int = env.race.next_step_index(i)
				var step: RaceStep = env.race.steps()[k]
				if step.kind == RaceStep.Kind.GATE:
					gates += 1
				assert_true(step.kind == RaceStep.Kind.MARK or (name == "S3" and step.kind == RaceStep.Kind.GATE), "%s: a mark, or a gate on the run" % name)
				var p: Vector3 = env.board(i).sim.telemetry.position
				assert_between(Vector2(p.x, p.z).distance_to(step.target()), 59.0, 151.0, "%s seed %d: 60 to 150 m from it" % [name, seed])
				if name == "S3" and step.kind == RaceStep.Kind.MARK:
					var leg_deg: float = Course.bearing_deg(Vector2.ZERO, step.in_dir)
					assert_true(absf(Course.turn_deg(env.course.axis_deg, leg_deg)) > 130.0, "S3: reached on a run")
		if name == "S3":
			assert_true(gates > 0, "S3 drops at gates too")


func test_the_laps_drops_are_just_past_the_start_line_with_the_whole_course_to_go() -> void:
	var stage: TrainingDrops.Stage = TrainingDrops.stage_named("S4")
	for seed: int in range(1, 6):
		var env: RaceEnv = TrainingDrops.make_env(stage, seed)
		assert_true(env.options.waves and env.options.gusts and env.options.shifts, "the real water and wind")
		for i: int in env.board_count():
			assert_eq(env.race.next_step_index(i), 1, "started")
			var start: RaceStep = env.race.steps()[0]
			var p: Vector3 = env.board(i).sim.telemetry.position
			var over_m: float = RoundingCheck.over_line_m(Vector2(p.x, p.z), start.points[0], start.points[1], start.in_dir)
			assert_between(over_m, 10.0, 40.0, "10 to 40 m on the course side of the line")
			assert_eq(env.board(i).goal_step, 0, "the finish ends it")
		assert_eq(env.options.episode_s, 480.0)


func test_the_starts_drops_are_in_the_sailing_area_with_a_countdown_and_the_lines_bias() -> void:
	var stage: TrainingDrops.Stage = TrainingDrops.stage_named("S5")
	var biased: int = 0
	for seed: int in range(1, 6):
		var env: RaceEnv = TrainingDrops.make_env(stage, seed)
		assert_eq(env.board_count(), 6)
		assert_false(env.options.blind, "the boards see each other at the start")
		assert_between(-env.race.clock_s(), 45.0, 90.0, "the countdown runs")
		assert_almost_eq(env.options.episode_s, -env.race.clock_s() + 120.0, 1e-3, "120 s after the gun")
		var area: SailingArea = SailingArea.around_start(env.course)
		for i: int in env.board_count():
			assert_eq(env.race.next_step_index(i), 0, "the start to do")
			var p: Vector3 = env.board(i).sim.telemetry.position
			assert_true(area.contains(Vector2(p.x, p.z)), "in the sailing area")
			assert_eq(env.board(i).goal_step, 2, "mark 1 ends it")
		if absf(env.options.wind_bias_deg) > 1.0:
			biased += 1
		assert_between(absf(env.options.wind_bias_deg), 0.0, 10.0)
	assert_true(biased > 0, "the line is skewed in some races")


func test_the_same_seed_gives_the_same_race_and_another_seed_another() -> void:
	var stage: TrainingDrops.Stage = TrainingDrops.stage_named("S2")
	var a: RaceEnv = TrainingDrops.make_env(stage, 21)
	var b: RaceEnv = TrainingDrops.make_env(stage, 21)
	var c: RaceEnv = TrainingDrops.make_env(stage, 22)
	assert_eq(a.course.name, b.course.name)
	assert_eq(a.wind_kt, b.wind_kt)
	assert_eq(a.board(0).sim.telemetry.position, b.board(0).sim.telemetry.position)
	assert_ne(a.board(0).sim.telemetry.position, c.board(0).sim.telemetry.position)


func test_a_respawn_drop_fits_the_stage_and_a_scripted_skipper_can_sail_a_drop() -> void:
	var stage: TrainingDrops.Stage = TrainingDrops.stage_named("S1")
	var env: RaceEnv = TrainingDrops.make_env(stage, 3, 2)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 4
	var again: RaceEnv.Drop = TrainingDrops.drop(stage, env.race, env.course, rng)
	env.respawn(1, again, 5)
	assert_eq(env.race.next_step_index(1), again.next_step)
	assert_eq(env.board(1).goal_step, again.next_step + 1)
	# The all-rounder on board 0's drop: it beats up toward the mark on its own.
	env.set_scripted(0, Skippers.make("allrounder"))
	for k: int in 40:
		env.act(0, PackedFloat32Array([0.0, 0.0, 0.0]))  # ignored: the skipper has the hands
		for t: int in env.decision_ticks:
			env.tick()
	assert_true(env.board(0).progress_m > 30.0, "the all-rounder made progress on its drop in 20 s: %.0f m" % env.board(0).progress_m)
	assert_eq(env.board(0).decisions, 0, "the network's decisions are not counted for a scripted board")
