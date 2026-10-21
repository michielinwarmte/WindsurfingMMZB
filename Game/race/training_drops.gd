class_name TrainingDrops
extends RefCounted
## The curriculum of the trained head (AI_FLEET_PLAN.md, D6b, "Training in parts"): each stage says
## where a board is set down, for how long, in what wind and on what water, and when its episode is
## over; the same brain is carried from stage to stage. Every episode is a new random course
## (RandomCourses) in a new random wind, and every board of a race gets its own drop:
##
##   S1 the beat       150 to 600 m below a windward mark, up to 200 m to either side, any heading;
##                     the episode ends when the mark is rounded, or after 90 s
##   S2 the rounding   60 to 150 m from any mark at any bearing (inside and outside the laylines,
##                     port and starboard roundings); ends at the rounding, or after 60 s
##   S3 the run        the same, at the marks reached downwind and at the gates
##   S4 full laps      just past the start line, started, the whole course to sail; 8 min; waves,
##                     gusts and shifts
##   S5 the start      a random spot in the sailing area round the line (F2), a countdown of 45 to
##                     90 s, the line's bias up to 10 degrees; the episode ends 120 s after the gun
##                     (how far up the beat the board is by then is the measure of its start), or
##                     at mark 1
##   S6 company        6 to 12 boards from random spots, the countdown, the whole race, the boards
##                     seeing each other; the race ends 60 s after the first finisher
##
## From S4 on, a share of the races (lake_share, 30 %) are sailed on Lake Silvaplana: the course
## (the saved T2, a template or a random shape) fitted to the water by CourseFitter, in the map's
## wind at a random hour of the Maloja's day, thin air and fresh water (D6), the sailing area kept
## off the shore; the rest on the open water in a random wind.
##
## The stages' names are S1 to S6; make_env() builds a race for a stage from a seed, drop() sets a
## board down again for its next episode in the same race.

enum Kind { BEAT, ROUNDING, DOWNWIND, LAPS, START, COMPANY }

const RULES_PATH: String = "res://maps/course/iqfoil_courses.tres"
## Lake Silvaplana (D6: "on the open water or on Lake Silvaplana, fitted to the water by
## CourseFitter, in the map's wind at a random hour"): its environment, its shore grid, its map.
const LAKE_ENVIRONMENT_PATH: String = "res://maps/silvaplana/environment_silvaplana.tres"
const LAKE_SHORE_PATH: String = "res://maps/silvaplana/terrain/shore_heights.json"
const LAKE_MAP_CONFIG_PATH: String = "res://maps/silvaplana/map_config.tres"
## The hours of the lake's day a race may be set at (the Maloja wind blows from late morning).
const LAKE_HOUR_MIN: float = 11.0
const LAKE_HOUR_MAX: float = 18.0
## The lake's fitter (the shore's clearance grid), built once.
static var _lake_fitter: CourseFitter = null
static var _lake_shore: TerrainGrid = null
const NAMES: PackedStringArray = ["S1", "S2", "S3", "S4", "S5", "S6"]
## A beat is a leg within this many degrees of straight upwind; a run within this of straight
## downwind (the cones of SailingDistance).
const BEAT_WITHIN_DEG: float = SailingDistance.UP_TRACK_DEG
const RUN_WITHIN_DEG: float = 180.0 - SailingDistance.DOWN_TRACK_DEG
## How many random courses are drawn before giving up on finding a step of the stage's kind (a
## slalom has no beat); then a windward-leeward is drawn, which has every kind.
const COURSE_TRIES: int = 12


## One stage's settings.
class Stage:
	var name: String = "S1"
	var kind: Kind = Kind.BEAT
	## The episode's length, seconds (for START and COMPANY: after the gun).
	var episode_s: float = 90.0
	## How many boards sail each race (the trainer may ask for another number).
	var boards: int = 4
	## Whether the boards see each other; whether every board gets its own fresh drop as soon as
	## it is done (the drops do not depend on the race's clock) or all wait for the race to end.
	var blind: bool = true
	var respawn_alone: bool = true
	var waves: bool = false
	var gusts: bool = false
	var shifts: bool = false
	## The sails shadow each other (F3's WindShadows), and the racing rules are kept (RaceRules):
	## the stages with company.
	var shadows: bool = false
	var rules: bool = false
	var wind_min_kt: float = 10.0
	var wind_max_kt: float = 24.0
	## The countdown, seconds, drawn between the two (0: no countdown; the boards are started).
	var prestart_min_s: float = 0.0
	var prestart_max_s: float = 0.0
	## The wind comes from the course's axis turned by up to this much either way: the line's bias.
	var wind_bias_max_deg: float = 0.0
	## A board that gains nothing for this long is done (0: off).
	var stall_s: float = 0.0
	## The share of the races sailed on Lake Silvaplana (the course fitted to the water, the map's
	## wind at a random hour, thin air and fresh water) instead of the open water.
	var lake_share: float = 0.0

	func describe() -> String:
		return "%s (%s): %d boards%s%s%s, %.0f s episodes, %.0f to %.0f kt, %s water, %s%s%s" % [name, Kind.keys()[kind].to_lower(),
			boards, " blind" if blind else "", " with wind shadows" if shadows else "", " and the rules" if rules else "", episode_s, wind_min_kt, wind_max_kt, "wavy" if waves else "flat",
			"gusts and shifts" if gusts and shifts else ("gusts" if gusts else ("shifts" if shifts else "a steady wind")),
			(", a countdown of %.0f to %.0f s" % [prestart_min_s, prestart_max_s]) if prestart_max_s > 0.0 else "",
			(", %.0f %% on Lake Silvaplana" % (100.0 * lake_share)) if lake_share > 0.0 else ""]


## The stage of a name (S1 to S6); null for any other name.
static func stage_named(name: String) -> Stage:
	var stage: Stage = Stage.new()
	stage.name = name.to_upper()
	match stage.name:
		"S1":
			stage.kind = Kind.BEAT
			stage.episode_s = 90.0
		"S2":
			stage.kind = Kind.ROUNDING
			stage.episode_s = 60.0
		"S3":
			stage.kind = Kind.DOWNWIND
			stage.episode_s = 60.0
		"S4":
			stage.kind = Kind.LAPS
			stage.episode_s = 480.0
			stage.waves = true
			stage.gusts = true
			stage.shifts = true
			stage.stall_s = 60.0
			stage.lake_share = 0.3
		"S5":
			stage.kind = Kind.START
			stage.episode_s = 120.0
			stage.boards = 6
			stage.blind = false
			stage.respawn_alone = false
			stage.shadows = true
			stage.rules = true
			stage.waves = true
			stage.gusts = true
			stage.prestart_min_s = 45.0
			stage.prestart_max_s = 90.0
			stage.wind_bias_max_deg = 10.0
			stage.lake_share = 0.3
		"S6":
			stage.kind = Kind.COMPANY
			stage.episode_s = 480.0
			stage.boards = 8
			stage.blind = false
			stage.respawn_alone = false
			stage.shadows = true
			stage.rules = true
			stage.waves = true
			stage.gusts = true
			stage.shifts = true
			stage.prestart_min_s = 60.0
			stage.prestart_max_s = 60.0
			stage.wind_bias_max_deg = 5.0
			stage.stall_s = 90.0
			stage.lake_share = 0.3
		_:
			return null
	return stage


## A race for a stage: a random course in a random wind (from the seed), the environment's options
## from the stage, and every board set down by the stage's rule. `boards` 0 takes the stage's number.
static func make_env(stage: Stage, seed: int, boards: int = 0) -> RaceEnv:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var count: int = boards if boards > 0 else stage.boards
	var wind_kt: float = rng.randf_range(stage.wind_min_kt, stage.wind_max_kt)
	var on_lake: bool = stage.lake_share > 0.0 and rng.randf() < stage.lake_share and lake_available()
	var options: RaceEnv.Options = RaceEnv.Options.new()
	var course: Course = null
	if on_lake:
		# The map's wind at a random hour sets the course's direction and the wind's strength.
		var environment: EnvironmentConfig = load(LAKE_ENVIRONMENT_PATH)
		options.environment = environment
		options.time_of_day_s = rng.randf_range(LAKE_HOUR_MIN, LAKE_HOUR_MAX) * 3600.0
		var map_wind: MapWind = environment.map_wind()
		var lake_from_deg: float = map_wind.lake_from_deg(options.time_of_day_s)
		wind_kt = map_wind.moment(options.time_of_day_s).lake_speed_ms / SimMath.KNOT_MS
		course = _lake_course_for(stage, rng, wind_kt, lake_from_deg)
		if course == null:
			on_lake = false
			options.environment = null
	if course == null:
		course = _course_for(stage, rng, wind_kt)
	options.actions = LearnedSkipper.ActionMode.TWA
	options.decision_ticks = 30
	options.waves = stage.waves
	options.gusts = stage.gusts
	options.shifts = stage.shifts
	options.blind = stage.blind
	options.shadows = stage.shadows
	options.rules = stage.rules
	options.stall_s = stage.stall_s
	options.laps = 1
	options.prestart_s = rng.randf_range(stage.prestart_min_s, stage.prestart_max_s) if stage.prestart_max_s > 0.0 else 0.0
	options.episode_s = stage.episode_s + options.prestart_s
	options.wind_bias_deg = rng.randf_range(-stage.wind_bias_max_deg, stage.wind_bias_max_deg)
	var env: RaceEnv = RaceEnv.new(course, count, wind_kt, options)
	var race: RaceSim = RaceSim.new(course, 1, 0.0)
	var drops: Array[RaceEnv.Drop] = []
	if stage.kind == Kind.START or stage.kind == Kind.COMPANY:
		drops = _spawn_drops(stage, course, count, rng, _lake_shore if on_lake else null)
	else:
		for i: int in count:
			drops.append(drop(stage, race, course, rng))
	env.reset_dropped(seed, drops)
	return env


## A new drop for a board in a race of a stage (its next episode, in the same race).
static func drop(stage: Stage, race: RaceSim, course: Course, rng: RandomNumberGenerator) -> RaceEnv.Drop:
	var steps: Array[RaceStep] = race.steps()
	match stage.kind:
		Kind.BEAT:
			var k: int = _pick(_steps_of_kind(steps, course.axis_deg, Kind.BEAT), rng)
			var mark: Vector2 = steps[k].points[0]
			var down: Vector2 = Course.direction_of(course.axis_deg + 180.0)
			var across: Vector2 = Course.direction_of(course.axis_deg + 90.0)
			var spot: Vector2 = mark + down * rng.randf_range(150.0, 600.0) + across * rng.randf_range(-200.0, 200.0)
			return RaceEnv.Drop.at(spot, rng.randf_range(0.0, 360.0), k, k + 1)
		Kind.ROUNDING, Kind.DOWNWIND:
			var k: int = _pick(_steps_of_kind(steps, course.axis_deg, stage.kind), rng)
			var spot: Vector2 = steps[k].target() + Course.direction_of(rng.randf_range(0.0, 360.0)) * rng.randf_range(60.0, 150.0)
			return RaceEnv.Drop.at(spot, rng.randf_range(0.0, 360.0), k, k + 1)
		Kind.LAPS:
			var start: RaceStep = steps[0]
			var along: Vector2 = (start.points[1] - start.points[0]).normalized()
			var half_m: float = 0.5 * start.points[0].distance_to(start.points[1])
			var spot: Vector2 = start.target() + start.in_dir * rng.randf_range(10.0, 40.0) + along * rng.randf_range(-0.8, 0.8) * half_m
			var first_leg_deg: float = Course.bearing_deg(Vector2.ZERO, start.out_dir)
			return RaceEnv.Drop.at(spot, first_leg_deg + rng.randf_range(-30.0, 30.0), 1, 0)
	# START and COMPANY: a random spot in the sailing area, the start to do.
	return _spawn_drops(stage, course, 1, rng)[0]


## The steps of a race a stage's drops are made at: the marks reached on a beat (BEAT), any mark
## (ROUNDING), the marks reached on a run and the gates (DOWNWIND).
static func _steps_of_kind(steps: Array[RaceStep], axis_deg: float, kind: Kind) -> Array[int]:
	var found: Array[int] = []
	for k: int in steps.size():
		var step: RaceStep = steps[k]
		if step.kind == RaceStep.Kind.START or step.kind == RaceStep.Kind.FINISH:
			continue
		var leg_deg: float = Course.bearing_deg(Vector2.ZERO, step.in_dir)
		var from_upwind_deg: float = absf(Course.turn_deg(axis_deg, leg_deg))
		match kind:
			Kind.BEAT:
				if step.kind == RaceStep.Kind.MARK and from_upwind_deg < BEAT_WITHIN_DEG:
					found.append(k)
			Kind.ROUNDING:
				if step.kind == RaceStep.Kind.MARK:
					found.append(k)
			Kind.DOWNWIND:
				if step.kind == RaceStep.Kind.GATE or (step.kind == RaceStep.Kind.MARK and from_upwind_deg > 180.0 - RUN_WITHIN_DEG):
					found.append(k)
			_:
				found.append(k)
	return found


static func _pick(choices: Array[int], rng: RandomNumberGenerator) -> int:
	return choices[rng.randi_range(0, choices.size() - 1)]


## A random course that has a step of the stage's kind (a slalom has no beat: another is drawn).
static func _course_for(stage: Stage, rng: RandomNumberGenerator, wind_kt: float) -> Course:
	var rules: CourseRules = load(RULES_PATH) as CourseRules
	for _try: int in COURSE_TRIES:
		var course: Course = RandomCourses.draw(rng, wind_kt, rules)
		if stage.kind == Kind.LAPS or stage.kind == Kind.START or stage.kind == Kind.COMPANY:
			return course
		if not _steps_of_kind(RaceSim.new(course, 1, 0.0).steps(), course.axis_deg, stage.kind).is_empty():
			return course
	return RandomCourses.windward_leeward(rng, rules, rng.randi_range(8, 24), rng.randf_range(0.0, 360.0))


## True when the lake's data is there (the map's big files come with Git LFS).
static func lake_available() -> bool:
	return ResourceLoader.exists(LAKE_ENVIRONMENT_PATH) and FileAccess.file_exists(LAKE_SHORE_PATH)


## The lake's fitter (built once from the shore grid: a fifth of a second) and its shore grid.
static func lake_fitter() -> CourseFitter:
	if _lake_fitter == null:
		_lake_shore = TerrainGrid.load_from(LAKE_SHORE_PATH)
		var t2: Course = RaceCourses.load_named(RaceCourses.T2_NAME, load(LAKE_MAP_CONFIG_PATH))
		var inside: Vector2 = t2.start_middle() if t2 != null else Vector2.ZERO
		_lake_fitter = CourseFitter.from_heights(_lake_shore.height_at, inside)
	return _lake_fitter


## A random course on the lake, fitted to the water in the lake's wind of the hour: the saved T2
## (a third of the time), a template, or a random shape, each fitted (shrunk, turned up to 15
## degrees, moved) so that every mark keeps 200 m of water; null when nothing fits or the stage's
## kind has no step on it.
static func _lake_course_for(stage: Stage, rng: RandomNumberGenerator, wind_kt: float, lake_from_deg: float) -> Course:
	var fitter: CourseFitter = lake_fitter()
	if not fitter.has_water():
		return null
	var rules: CourseRules = load(RULES_PATH) as CourseRules
	var t2: Course = RaceCourses.load_named(RaceCourses.T2_NAME, load(LAKE_MAP_CONFIG_PATH))
	var centre: Vector2 = t2.bounds().get_center() if t2 != null else Vector2.ZERO
	for _try: int in COURSE_TRIES:
		var fitted: Course = null
		var share: float = rng.randf()
		if share < 0.33 and t2 != null:
			fitted = fitter.fit_course(t2, lake_from_deg)
		elif share < 0.66:
			var id: String = CourseTemplates.ALL[rng.randi_range(0, CourseTemplates.ALL.size() - 1)]
			fitted = fitter.fit_template(id, rules, wind_kt, lake_from_deg, centre, rng.randi_range(8, 24))
		else:
			var shape: Course = RandomCourses.draw(rng, wind_kt, rules)
			shape.move_by(centre - shape.bounds().get_center())
			fitted = fitter.fit_course(shape, lake_from_deg)
		if fitted == null:
			continue
		var needs_step: bool = stage.kind == Kind.BEAT or stage.kind == Kind.ROUNDING or stage.kind == Kind.DOWNWIND
		if needs_step and _steps_of_kind(RaceSim.new(fitted, 1, 0.0).steps(), fitted.axis_deg, stage.kind).is_empty():
			continue
		return fitted
	return null


## Random spots in the sailing area round the start line (as the game spawns the fleet, F2; kept
## off the shore on the lake), the start to do. START's episodes end once mark 1 is rounded (goal
## step 2); COMPANY's at the finish.
static func _spawn_drops(stage: Stage, course: Course, count: int, rng: RandomNumberGenerator, shore: TerrainGrid = null) -> Array[RaceEnv.Drop]:
	var area: SailingArea = SailingArea.for_course(course, shore)
	var places: Array[Vector3] = area.spawn_places(count, rng.randi())
	var drops: Array[RaceEnv.Drop] = []
	for place: Vector3 in places:
		drops.append(RaceEnv.Drop.at(Vector2(place.x, place.y), place.z, 0, 2 if stage.kind == Kind.START else 0))
	return drops
