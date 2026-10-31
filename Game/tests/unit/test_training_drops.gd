extends GutTest
## The trainer's random courses and drops (AI_FLEET_PLAN.md, D6b): every random course has a start,
## a finish and a sailable order and makes a race; the templates at random sizes do too; each stage's
## drops are where the stage says (below a windward mark for the beat, near a mark for the rounding,
## near a downwind mark or a gate for the run, just past the line for the laps, in the sailing area
## with the countdown for the start); every stage draws its conditions from the settings menu's
## whole range (the wind, the five seas at every height, the gusts, the shifts) and the race sails
## in them; the same seed gives the same race; and a scripted skipper can sail a stage's drop.


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
		assert_between(env.wind_kt, SettingsValues.WIND_SPEED_MIN_KT, SettingsValues.WIND_SPEED_MAX_KT)


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


## Every stage draws the conditions of its races evenly across the settings menu's ranges: over
## many seeds the smallest and the largest seen are near the ends of each range and never past them,
## every one of the five seas comes up (flat water about a fifth of the time), and the roughest sea
## is the menu's roughest. The lake from S4 on only.
func test_every_stage_draws_the_settings_whole_range_of_conditions() -> void:
	const DRAWS: int = 400
	for name: String in TrainingDrops.NAMES:
		var stage: TrainingDrops.Stage = TrainingDrops.stage_named(name)
		assert_eq(stage.wind_min_kt, SettingsValues.WIND_SPEED_MIN_KT, "%s: the menu's lightest wind" % name)
		assert_eq(stage.wind_max_kt, SettingsValues.WIND_SPEED_MAX_KT, "%s: the menu's strongest wind" % name)
		assert_true(stage.waves and stage.gusts and stage.shifts, "%s draws the sea, the gusts and the shifts" % name)
		assert_eq(stage.lake_share, 0.3 if name in ["S4", "S5", "S6"] else 0.0, "%s: the lake from S4 on" % name)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 7
		var lowest: Dictionary[String, float] = {}
		var highest: Dictionary[String, float] = {}
		var presets: Dictionary[int, int] = {}
		for k: int in DRAWS:
			var wind_kt: float = rng.randf_range(stage.wind_min_kt, stage.wind_max_kt)
			var c: TrainingDrops.Conditions = TrainingDrops.draw_conditions(stage, rng, wind_kt)
			presets[c.sea_preset] = presets.get(c.sea_preset, 0) + 1
			var seen: Dictionary[String, float] = {"wind_kt": c.wind_kt, "height": c.wave_height_scale, "swell": c.swell_height_scale,
				"fetch_km": c.fetch_km, "depth_m": c.water_depth_m, "gusts": c.gust_intensity, "shift_deg": c.max_shift_deg,
				"shift_period_s": c.shift_period_s, "sea_m": c.wave_set().total_amplitude_m() if c.waves() else 0.0}
			for key: String in seen:
				lowest[key] = minf(lowest.get(key, INF), seen[key])
				highest[key] = maxf(highest.get(key, -INF), seen[key])
		_assert_spans(name, "wind_kt", lowest, highest, SettingsValues.WIND_SPEED_MIN_KT, SettingsValues.WIND_SPEED_MAX_KT)
		_assert_spans(name, "height", lowest, highest, SettingsValues.WAVE_SCALE_MIN, SettingsValues.WAVE_SCALE_MAX)
		_assert_spans(name, "swell", lowest, highest, SettingsValues.SWELL_SCALE_MIN, SettingsValues.SWELL_SCALE_MAX)
		_assert_spans(name, "fetch_km", lowest, highest, SettingsValues.FETCH_MIN_KM, SettingsValues.FETCH_MAX_KM)
		_assert_spans(name, "depth_m", lowest, highest, SettingsValues.DEPTH_MIN_M, SettingsValues.DEPTH_DEEP_M)
		_assert_spans(name, "gusts", lowest, highest, 0.0, SettingsValues.GUST_INTENSITY_MAX)
		_assert_spans(name, "shift_deg", lowest, highest, 0.0, SettingsValues.SHIFT_MAX_DEG)
		_assert_spans(name, "shift_period_s", lowest, highest, SettingsValues.SHIFT_PERIOD_MIN_S, SettingsValues.SHIFT_PERIOD_MAX_S)
		assert_eq(presets.size(), SettingsValues.WavePreset.size(), "%s: all five seas: %s" % [name, str(presets)])
		assert_between(float(presets.get(SettingsValues.WavePreset.FLAT, 0)) / DRAWS, 0.12, 0.28, "%s: flat water about a fifth of the time" % name)
		assert_eq(lowest["sea_m"], 0.0, "%s: flat water" % name)
		assert_true(highest["sea_m"] > 0.5, "%s: the roughest sea seen is %.2f m high" % [name, highest["sea_m"]])
		gut.p("%s: the sea from %.2f to %.2f m, the wind %.1f to %.1f kt, gusts %.3f to %.3f, shifts %.1f to %.1f deg; seas %s" % [name,
			lowest["sea_m"], highest["sea_m"], lowest["wind_kt"], highest["wind_kt"], lowest["gusts"], highest["gusts"],
			lowest["shift_deg"], highest["shift_deg"], str(presets)])


## The smallest and the largest seen are within a range and within 4 % of its ends.
func _assert_spans(stage: String, key: String, lowest: Dictionary[String, float], highest: Dictionary[String, float], low: float, high: float) -> void:
	var margin: float = 0.04 * (high - low)
	assert_between(lowest[key], low, low + margin, "%s: the smallest %s seen, %.3f, near the range's %.3f" % [stage, key, lowest[key], low])
	assert_between(highest[key], high - margin, high, "%s: the largest %s seen, %.3f, near the range's %.3f" % [stage, key, highest[key], high])


func test_a_race_sails_in_the_conditions_it_drew() -> void:
	var stage: TrainingDrops.Stage = TrainingDrops.stage_named("S1")
	var wavy: int = 0
	for seed: int in range(1, 13):
		var env: RaceEnv = TrainingDrops.make_env(stage, seed, 2)
		var sim: WindsurferSim = env.board(0).sim
		assert_eq(sim.has_waves(), env.options.waves, "seed %d: waves as drawn" % seed)
		if env.options.waves:
			wavy += 1
			assert_almost_eq(sim.wave_set_config.total_amplitude_m(), env.options.sea.total_amplitude_m(), 1e-6, "the drawn sea on the water")
			assert_ne(sim.wave_set_config, env.board(1).sim.wave_set_config, "each board its own copy of the sea")
		assert_eq(sim.wind_config.speed_kt, env.wind_kt)
		assert_eq(sim.wind_config.gusts_enabled, env.options.gusts)
		assert_true(sim.wind_config.gust_patches, "the gusts as patches")
		assert_almost_eq(sim.wind_config.gust_intensity, env.options.wind.gust_intensity, 1e-6, "the drawn gusts")
		assert_eq(sim.wind_config.shifts_enabled, env.options.shifts)
		assert_almost_eq(sim.wind_config.max_shift_deg, env.options.wind.max_shift_deg, 1e-6, "the drawn shifts")
		assert_eq(sim.wind.uses_patches(), env.options.gusts)
	assert_true(wavy > 0 and wavy < 12, "some races on waves, some on flat water: %d of 12" % wavy)


func test_the_same_seed_gives_the_same_race_and_another_seed_another() -> void:
	var stage: TrainingDrops.Stage = TrainingDrops.stage_named("S2")
	var a: RaceEnv = TrainingDrops.make_env(stage, 21)
	var b: RaceEnv = TrainingDrops.make_env(stage, 21)
	var c: RaceEnv = TrainingDrops.make_env(stage, 22)
	assert_eq(a.course.name, b.course.name)
	assert_eq(a.wind_kt, b.wind_kt)
	assert_eq(a.options.waves, b.options.waves, "the same sea")
	assert_eq(a.options.wind.gust_intensity, b.options.wind.gust_intensity, "the same gusts")
	assert_eq(a.options.wind.max_shift_deg, b.options.wind.max_shift_deg, "the same shifts")
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


func test_a_race_on_the_lake_has_the_maps_wind_and_a_course_fitted_to_the_water() -> void:
	if not TrainingDrops.lake_available():
		pending("the lake's data is not here (Git LFS)")
		return
	var stage: TrainingDrops.Stage = TrainingDrops.stage_named("S4")
	stage.lake_share = 1.0
	var env: RaceEnv = TrainingDrops.make_env(stage, 3, 2)
	assert_not_null(env.options.environment, "the lake's environment")
	assert_true(env.board(0).sim.wind is MapWindField, "the map's wind")
	assert_between(env.options.time_of_day_s / 3600.0, TrainingDrops.LAKE_HOUR_MIN, TrainingDrops.LAKE_HOUR_MAX)
	assert_true(env.wind_kt > 3.0 and env.wind_kt < 40.0, "the lake's wind of the hour: %.1f kt" % env.wind_kt)
	# The course keeps 200 m of water at every mark, and its axis is the lake's wind of the hour.
	var fitter: CourseFitter = TrainingDrops.lake_fitter()
	assert_true(fitter.smallest_mark_clearance_m(env.course) >= fitter.mark_margin_m - 1.0, "every mark %.0f m from the shore" % fitter.smallest_mark_clearance_m(env.course))
	var lake_from_deg: float = env.options.environment.map_wind().lake_from_deg(env.options.time_of_day_s)
	assert_true(absf(Course.turn_deg(env.course.axis_deg, lake_from_deg)) <= fitter.axis_tolerance_deg + 0.1, "set to the lake's wind")
	# It sails: a board dropped past the line makes progress in 10 s.
	for k: int in 20:
		env.act(0, PackedFloat32Array([0.3, 0.0, 0.0]))
		for t: int in env.decision_ticks:
			env.tick()
	assert_true(absf(env.board(0).progress_m) > 1.0, "the board moved on the lake: %.1f m" % env.board(0).progress_m)
	# The stages without a lake share stay on the open water.
	var open: RaceEnv = TrainingDrops.make_env(TrainingDrops.stage_named("S1"), 3, 1)
	assert_null(open.options.environment)
