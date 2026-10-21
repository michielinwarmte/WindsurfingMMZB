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
## The stages' names are S1 to S6; make_env() builds a race for a stage from a seed, drop() sets a
## board down again for its next episode in the same race.

enum Kind { BEAT, ROUNDING, DOWNWIND, LAPS, START, COMPANY }

const RULES_PATH: String = "res://maps/course/iqfoil_courses.tres"
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
	## The sails shadow each other (F3's WindShadows): the stages with company.
	var shadows: bool = false
	var wind_min_kt: float = 10.0
	var wind_max_kt: float = 24.0
	## The countdown, seconds, drawn between the two (0: no countdown; the boards are started).
	var prestart_min_s: float = 0.0
	var prestart_max_s: float = 0.0
	## The wind comes from the course's axis turned by up to this much either way: the line's bias.
	var wind_bias_max_deg: float = 0.0
	## A board that gains nothing for this long is done (0: off).
	var stall_s: float = 0.0

	func describe() -> String:
		return "%s (%s): %d boards%s%s, %.0f s episodes, %.0f to %.0f kt, %s water, %s%s" % [name, Kind.keys()[kind].to_lower(),
			boards, " blind" if blind else "", " with wind shadows" if shadows else "", episode_s, wind_min_kt, wind_max_kt, "wavy" if waves else "flat",
			"gusts and shifts" if gusts and shifts else ("gusts" if gusts else ("shifts" if shifts else "a steady wind")),
			(", a countdown of %.0f to %.0f s" % [prestart_min_s, prestart_max_s]) if prestart_max_s > 0.0 else ""]


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
		"S5":
			stage.kind = Kind.START
			stage.episode_s = 120.0
			stage.boards = 6
			stage.blind = false
			stage.respawn_alone = false
			stage.shadows = true
			stage.waves = true
			stage.gusts = true
			stage.prestart_min_s = 45.0
			stage.prestart_max_s = 90.0
			stage.wind_bias_max_deg = 10.0
		"S6":
			stage.kind = Kind.COMPANY
			stage.episode_s = 480.0
			stage.boards = 8
			stage.blind = false
			stage.respawn_alone = false
			stage.shadows = true
			stage.waves = true
			stage.gusts = true
			stage.shifts = true
			stage.prestart_min_s = 60.0
			stage.prestart_max_s = 60.0
			stage.wind_bias_max_deg = 5.0
			stage.stall_s = 90.0
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
	var course: Course = _course_for(stage, rng, wind_kt)
	var options: RaceEnv.Options = RaceEnv.Options.new()
	options.actions = LearnedSkipper.ActionMode.TWA
	options.decision_ticks = 30
	options.waves = stage.waves
	options.gusts = stage.gusts
	options.shifts = stage.shifts
	options.blind = stage.blind
	options.shadows = stage.shadows
	options.stall_s = stage.stall_s
	options.laps = 1
	options.prestart_s = rng.randf_range(stage.prestart_min_s, stage.prestart_max_s) if stage.prestart_max_s > 0.0 else 0.0
	options.episode_s = stage.episode_s + options.prestart_s
	options.wind_bias_deg = rng.randf_range(-stage.wind_bias_max_deg, stage.wind_bias_max_deg)
	var env: RaceEnv = RaceEnv.new(course, count, wind_kt, options)
	var race: RaceSim = RaceSim.new(course, 1, 0.0)
	var drops: Array[RaceEnv.Drop] = []
	if stage.kind == Kind.START or stage.kind == Kind.COMPANY:
		drops = _spawn_drops(stage, course, count, rng)
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


## Random spots in the sailing area round the start line (as the game spawns the fleet, F2), the
## start to do. START's episodes end once mark 1 is rounded (goal step 2); COMPANY's at the finish.
static func _spawn_drops(stage: Stage, course: Course, count: int, rng: RandomNumberGenerator) -> Array[RaceEnv.Drop]:
	var area: SailingArea = SailingArea.around_start(course)
	var places: Array[Vector3] = area.spawn_places(count, rng.randi())
	var drops: Array[RaceEnv.Drop] = []
	for place: Vector3 in places:
		drops.append(RaceEnv.Drop.at(Vector2(place.x, place.y), place.z, 0, 2 if stage.kind == Kind.START else 0))
	return drops
