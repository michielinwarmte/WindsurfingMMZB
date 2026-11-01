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
##   S4 full laps      just past the start line, started, the whole course to sail; 8 min
##   S5 the start      a random spot in the sailing area round the line (F2), a countdown of 45 to
##                     90 s, the line's bias up to 10 degrees; the episode ends 120 s after the gun
##                     (how far up the beat the board is by then is the measure of its start), or
##                     at mark 1
##   S6 company        6 to 12 boards from random spots, the countdown, the whole race, the boards
##                     seeing each other; the race ends 60 s after the first finisher
##
## And the curriculum on the plan's two courses (Documentation/reports/fleet_speed/PLAN.md, RA14):
## T1, the training loop, and T2, the sprint slalom, at 12 to 24 kt, in the game's open water as the
## race tool sails it (its sea, its wind's gusts and shifts: game_conditions), so the brain learns
## exactly the races it is measured on:
##
##   C1 the legs       a random step of T1 or T2 as the goal (the next one or two steps), the board
##                     set down back along the course where the all-rounder would need a third to
##                     two thirds of the episode to get there (expected_leg_s()); 180 s
##   C2 the course     just past the start line of T1 or T2, started, the whole course alone against
##                     the clock; 1200 s (the all-rounder needs 850 s on T1 at 12 kt), stalled after
##                     90 s without a gain
##
## The drops of the first nights were 60 to 90 s on random courses: a brain that tacked every 15 s
## still rounded half of S2's and S3's marks, and no lap fitted S4's 480 s (nights_review.md).
## The conditions (Session 64, Michiel: "as fast as possible around all the courses with different
## wind and wave conditions"): every race of every stage is sailed in conditions drawn from the whole
## range the settings menu offers (SettingsValues), so the head learns every wind and sea a player
## can set (draw_conditions()): the wind from 4 to 35 kt; the sea one of the menu's five (flat, the
## swell, the medium and the strong chop, the sea made by the wind over a fetch) at a random height,
## from flat water up to a 0.6 m crest (SEA_HEIGHT_MAX_M: the menu goes rougher, the hands cannot
## yet); the gust patches from none to the menu's strongest; the shifts from none to the menu's
## largest, at a random period. On the lake the wind, its gusts and its shifts are the map's
## (below); the sea is drawn there too, as the game puts the player's sea on the lake.
##
## From S4 on, a share of the races (lake_share, 30 %) are sailed on Lake Silvaplana: the course
## (the saved T2, a template or a random shape) fitted to the water by CourseFitter, in the map's
## wind at a random hour of the Maloja's day, thin air and fresh water (D6), the sailing area kept
## off the shore; the rest on the open water in a random wind.
##
## The highest sea a training race is drawn in: its highest crest above the still water (the sum of
## the waves' amplitudes, WaveSetConfig.total_amplitude_m(): the sea_height the brain sees), metres.
## The menu goes up to about 1.8 m, but the hands cannot sail the rough end today: the all-rounder on
## the autopilot's margin fell 25 times in 4 minutes in a 0.55 m sea on the lake and stalled in 0.45
## to 0.83 m seas at 17 kt (Documentation/reports/fleet_gear/training.md), so a race in such a sea
## teaches the brain only falling (the lead's decision, 31 October 2026). The seas from 0.45 to 0.6 m
## stay: there the brain must learn to ease the push. Making the board sail rougher water is a
## physics and controller item for Michiel, who may raise this number once the hands can.
const SEA_HEIGHT_MAX_M: float = 0.6

## The stages' names are S1 to S6; make_env() builds a race for a stage from a seed, drop() sets a
## board down again for its next episode in the same race.

enum Kind { BEAT, ROUNDING, DOWNWIND, LAPS, START, COMPANY, COURSE_LEGS, COURSE_RACE }

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
const NAMES: PackedStringArray = ["S1", "S2", "S3", "S4", "S5", "S6", "C1", "C2"]
## The plan's two courses (C1, C2): T1 and T2 by the names the race tool knows them by.
const PLAN_COURSES: PackedStringArray = ["t1_loop", "t2_slalom"]
## The plan's winds, knots.
const PLAN_WIND_MIN_KT: float = 12.0
const PLAN_WIND_MAX_KT: float = 24.0
## How fast the all-rounder gains on a leg's straight line at 18 kt, m/s (sailing distance a second;
## its legs alone on T1 and T2 at 12, 18 and 24 kt, seed 1, 1 November 2026, a little under the
## measured): a beat (the leg within BEAT_WITHIN_DEG of upwind; T1's 556 m beat took 165 s, its 406 m
## beat 128 s), a run (within RUN_WITHIN_DEG of downwind; T1's runs 78 and 88 s for 406 m, T2's
## 500 m run 99 s) and a reach (the rest; T2's 360 m reach 31 s, its 240 m reaches 22 and 34 s).
const LEG_RATE_BEAT_MS: float = 3.0
const LEG_RATE_RUN_MS: float = 4.5
const LEG_RATE_REACH_MS: float = 7.0
## And how much that changes with the wind: (wind - 6 kt) / 12 kt, between these two. At 12 kt the
## all-rounder beats at 1.8 m/s and runs at 2.7 m/s (half of 18 kt's); at 24 kt about 1.2 times.
const LEG_RATE_WIND_LOW: float = 0.5
const LEG_RATE_WIND_HIGH: float = 1.2
## C1: the all-rounder's expected time to the drop's goal, as a share of the episode, is drawn
## between these two; so it reaches the goal well inside the episode, and the brain has the rest.
const LEG_BUDGET_MIN: float = 0.3
const LEG_BUDGET_MAX: float = 0.65
## A board is set down this far at most to either side of the leg's straight line, as a share of
## what is left of the leg (a sailor is seldom on the rhumb line).
const LEG_ACROSS_SHARE: float = 0.2
## A drop heading nearer the wind than this is turned to close-hauled on that side (a board set down
## head to wind only learns to get out of irons).
const DROP_IRONS_DEG: float = 40.0
const DROP_CLOSE_HAULED_DEG: float = 45.0
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
	## Whether the sea, the gusts and the shifts are drawn (draw_conditions()); off: flat water, a
	## steady wind, a wind that keeps its direction. Every stage draws all three (Session 64).
	var waves: bool = true
	var gusts: bool = true
	var shifts: bool = true
	## The sails shadow each other (F3's WindShadows), and the racing rules are kept (RaceRules):
	## the stages with company.
	var shadows: bool = false
	var rules: bool = false
	## The wind's strength, knots: the settings menu's whole range.
	var wind_min_kt: float = SettingsValues.WIND_SPEED_MIN_KT
	var wind_max_kt: float = SettingsValues.WIND_SPEED_MAX_KT
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
	## The tack discipline the brain sails with (RaceEnv.Options.manoeuvre_gap_s, LearnedSkipper
	## RA14), seconds; the trainer may set another (--manoeuvre_gap_s), the evaluation the brain's.
	var manoeuvre_gap_s: float = LearnedSkipper.MANOEUVRE_GAP_S
	## The closest to the wind the hands steer (RaceEnv.Options.closest_twa_deg), degrees; 0, none:
	## a floor at 35 degrees trapped the old brains pinched and slow (trainer_tacks.md, section 2).
	var closest_twa_deg: float = 0.0
	## What each tack and gybe costs in the reward, metres (RaceEnv.Options.manoeuvre_cost_m); the
	## trainer may set another (--manoeuvre_cost_m).
	var manoeuvre_cost_m: float = RaceEnv.Options.new().manoeuvre_cost_m
	## The game's open water as the race tool and the race page sail it, instead of drawn conditions:
	## the default sea (the swell) and the default wind file's gusts and shifts (C1, C2).
	var game_conditions: bool = false
	## Each board its own conditions (RaceEnv.Weather: its wind's strength, and unless
	## game_conditions its sea, gusts and shifts) instead of the race's: for the blind stages that
	## set boards down at once (S1 to S4, C1, C2), off the lake. The trainer's --own_conditions=1.
	var own_conditions: bool = false

	func describe() -> String:
		var water: String = "the game's open water (T1 and T2)"
		if not game_conditions:
			water = ("the sea from flat to %.2f m" % SEA_HEIGHT_MAX_M) if waves else "flat water"
			water += ", " + ("gusts and shifts drawn" if gusts and shifts else ("gusts drawn" if gusts else ("shifts drawn" if shifts else "a steady wind")))
		return "%s (%s): %d boards%s%s%s, %.0f s episodes, %.0f to %.0f kt, %s%s%s" % [name, Kind.keys()[kind].to_lower(),
			boards, " blind" if blind else "", " with wind shadows" if shadows else "", " and the rules" if rules else "", episode_s, wind_min_kt, wind_max_kt,
			water,
			(", a countdown of %.0f to %.0f s" % [prestart_min_s, prestart_max_s]) if prestart_max_s > 0.0 else "",
			(", %.0f %% on Lake Silvaplana" % (100.0 * lake_share)) if lake_share > 0.0 else ""]


## The conditions of one race (draw_conditions()): the wind's strength, the sea and the wind's gusts
## and shifts, each a number the settings menu offers, so the race is one a player could set up.
class Conditions:
	var wind_kt: float = 15.0
	## The sea: the menu's preset and its numbers (SettingsValues: the heights of all the waves and
	## of the swell alone; for the sea made by the wind, the fetch and the depth).
	var sea_preset: SettingsValues.WavePreset = SettingsValues.WavePreset.FLAT
	var wave_height_scale: float = 1.0
	var swell_height_scale: float = 1.0
	var fetch_km: float = 5.0
	var water_depth_m: float = SettingsValues.DEPTH_DEEP_M
	## The gust patches' strength (WindConfig.gust_intensity; 0: a steady wind), and the shifts'
	## swing either way (degrees; 0: none) and their period (seconds).
	var gust_intensity: float = 0.0
	var max_shift_deg: float = 0.0
	var shift_period_s: float = 60.0

	func waves() -> bool:
		return sea_preset != SettingsValues.WavePreset.FLAT

	func gusts() -> bool:
		return gust_intensity > 0.0

	func shifts() -> bool:
		return max_shift_deg > 0.0

	## The sea as the settings menu builds it (SettingsValues.build_wave_set_config()).
	func wave_set() -> WaveSetConfig:
		var menu: SettingsValues = settings()
		return menu.build_wave_set_config()

	## The open water's wind settings: the default wind file's, with these gusts (as patches) and
	## shifts. RaceEnv sets the speed, the direction and the two switches.
	func wind_config() -> WindConfig:
		var wind: WindConfig = (load(SettingsValues.WIND_DEFAULT_PATH) as WindConfig).duplicate()
		wind.speed_kt = wind_kt
		wind.gusts_enabled = gusts()
		wind.gust_patches = true
		wind.gust_intensity = gust_intensity
		wind.shifts_enabled = shifts()
		wind.max_shift_deg = max_shift_deg
		wind.shift_period_s = shift_period_s
		return wind

	## These conditions as the settings menu's values (the ones a player would set for them).
	func settings() -> SettingsValues:
		var menu: SettingsValues = SettingsValues.new()
		menu.wind_speed_kt = wind_kt
		menu.waves_enabled = waves()
		menu.wave_preset = sea_preset
		menu.wave_height_scale = wave_height_scale
		menu.swell_height_scale = swell_height_scale
		menu.fetch_km = fetch_km
		menu.water_depth_m = water_depth_m
		menu.gusts_enabled = gusts()
		menu.gust_intensity = gust_intensity
		menu.shifts_enabled = shifts()
		menu.max_shift_deg = max_shift_deg
		menu.shift_period_s = shift_period_s
		return menu

	## In words, for the logs: "18 kt, strong chop x1.4 (0.21 m), gusts 0.31, shifts 12 deg / 140 s".
	func describe() -> String:
		var sea: String = "flat water"
		if waves():
			sea = "%s x%.1f (%.2f m)" % [SettingsValues.wave_preset_name(sea_preset).to_lower(), wave_height_scale, wave_set().total_amplitude_m()]
		return "%.0f kt, %s, %s, %s" % [wind_kt, sea, ("gusts %.2f" % gust_intensity) if gusts() else "steady",
			("shifts %.0f deg / %.0f s" % [max_shift_deg, shift_period_s]) if shifts() else "no shifts"]


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
			stage.prestart_min_s = 60.0
			stage.prestart_max_s = 60.0
			stage.wind_bias_max_deg = 5.0
			stage.stall_s = 90.0
			stage.lake_share = 0.3
		"C1":
			stage.kind = Kind.COURSE_LEGS
			stage.episode_s = 180.0
			_plan_conditions(stage)
		"C2":
			stage.kind = Kind.COURSE_RACE
			stage.episode_s = 1200.0
			stage.stall_s = 90.0
			_plan_conditions(stage)
		_:
			return null
	return stage


## The plan's conditions (C1, C2): its winds, the game's open water.
static func _plan_conditions(stage: Stage) -> void:
	stage.wind_min_kt = PLAN_WIND_MIN_KT
	stage.wind_max_kt = PLAN_WIND_MAX_KT
	stage.game_conditions = true


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
	var conditions: Conditions = draw_conditions(stage, rng, wind_kt)
	options.actions = LearnedSkipper.ActionMode.TWA
	options.decision_ticks = 30
	options.manoeuvre_gap_s = stage.manoeuvre_gap_s
	options.closest_twa_deg = stage.closest_twa_deg
	options.manoeuvre_cost_m = stage.manoeuvre_cost_m
	options.waves = conditions.waves()
	options.sea = conditions.wave_set() if conditions.waves() else null
	options.gusts = conditions.gusts()
	options.shifts = conditions.shifts()
	options.wind = conditions.wind_config()
	if stage.game_conditions:
		# The race tool's open water: the default sea and the default wind file (its gusts and
		# shifts as the settings start: off), only the wind's strength and direction set.
		var wind_default: WindConfig = load(SettingsValues.WIND_DEFAULT_PATH) as WindConfig
		options.waves = true
		options.sea = null
		options.wind = null
		options.gusts = wind_default.gusts_enabled
		options.shifts = wind_default.shifts_enabled
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
			drops.append(drop_in_weather(stage, race, course, rng, wind_kt, on_lake))
	env.reset_dropped(seed, drops)
	return env


## A drop for a board of a blind stage that sets boards down at once: in its own conditions
## (weather_for()) when the stage says so and the race is on the open water, else in the race's
## (wind_kt). TrainBridge sets boards down again with it.
static func drop_in_weather(stage: Stage, race: RaceSim, course: Course, rng: RandomNumberGenerator, wind_kt: float, on_lake: bool = false) -> RaceEnv.Drop:
	var weather: RaceEnv.Weather = null if on_lake else weather_for(stage, rng)
	var placed: RaceEnv.Drop = drop(stage, race, course, rng, weather.wind_kt if weather != null else wind_kt)
	placed.weather = weather
	return placed


## A board's own conditions for a stage with own_conditions (null for the others): its wind's
## strength in the stage's range, and the game's open water (game_conditions) or the drawn sea,
## gusts and shifts (draw_conditions()).
static func weather_for(stage: Stage, rng: RandomNumberGenerator) -> RaceEnv.Weather:
	if not stage.own_conditions or not stage.respawn_alone or not stage.blind:
		return null
	var weather: RaceEnv.Weather = RaceEnv.Weather.new()
	weather.wind_kt = rng.randf_range(stage.wind_min_kt, stage.wind_max_kt)
	if stage.game_conditions:
		var wind_default: WindConfig = load(SettingsValues.WIND_DEFAULT_PATH) as WindConfig
		weather.waves = true
		weather.gusts = wind_default.gusts_enabled
		weather.shifts = wind_default.shifts_enabled
		return weather
	var c: Conditions = draw_conditions(stage, rng, weather.wind_kt)
	weather.waves = c.waves()
	weather.sea = c.wave_set() if c.waves() else null
	weather.gusts = c.gusts()
	weather.shifts = c.shifts()
	weather.wind = c.wind_config()
	return weather


## The conditions of a race of a stage, from the race's random numbers (the same seed, the same
## conditions): each number drawn evenly across the settings menu's range (SettingsValues), the
## sea's preset evenly among the menu's five (so flat water a fifth of the time), the sea's height
## kept at or under SEA_HEIGHT_MAX_M. The same count of numbers is drawn whatever the stage switches
## off, so the rest of a race's draws do not move.
static func draw_conditions(stage: Stage, rng: RandomNumberGenerator, wind_kt: float) -> Conditions:
	var c: Conditions = Conditions.new()
	c.wind_kt = wind_kt
	var preset: int = rng.randi_range(0, SettingsValues.WavePreset.size() - 1)
	c.sea_preset = (preset if stage.waves else SettingsValues.WavePreset.FLAT) as SettingsValues.WavePreset
	var height_share: float = rng.randf()
	c.swell_height_scale = rng.randf_range(SettingsValues.SWELL_SCALE_MIN, SettingsValues.SWELL_SCALE_MAX)
	c.fetch_km = rng.randf_range(SettingsValues.FETCH_MIN_KM, SettingsValues.FETCH_MAX_KM)
	c.water_depth_m = rng.randf_range(SettingsValues.DEPTH_MIN_M, SettingsValues.DEPTH_DEEP_M)
	var highest_scale: float = _highest_height_scale(c)
	c.wave_height_scale = lerpf(minf(SettingsValues.WAVE_SCALE_MIN, highest_scale), highest_scale, height_share)
	var gust_intensity: float = rng.randf_range(0.0, SettingsValues.GUST_INTENSITY_MAX)
	c.gust_intensity = gust_intensity if stage.gusts else 0.0
	var shift_deg: float = rng.randf_range(0.0, SettingsValues.SHIFT_MAX_DEG)
	c.max_shift_deg = shift_deg if stage.shifts else 0.0
	c.shift_period_s = rng.randf_range(SettingsValues.SHIFT_PERIOD_MIN_S, SettingsValues.SHIFT_PERIOD_MAX_S)
	return c


## The most the menu's height (wave_height_scale) may be for this sea and stay at or under
## SEA_HEIGHT_MAX_M: the menu's most (2 times) for a sea that stays low anyway, less for a rough one.
## Every wave's amplitude is the scale times its own, so the sea's height is the scale times its
## height at 1. In the one case where even the menu's least height (half) is too high, the scale goes
## below it: never with the menu's seas today (the roughest is about 0.9 m at 1, 0.45 m at half).
static func _highest_height_scale(c: Conditions) -> float:
	if not c.waves():
		return SettingsValues.WAVE_SCALE_MAX
	c.wave_height_scale = 1.0
	var height_at_one_m: float = c.wave_set().total_amplitude_m()
	if height_at_one_m * SettingsValues.WAVE_SCALE_MAX <= SEA_HEIGHT_MAX_M:
		return SettingsValues.WAVE_SCALE_MAX
	return SEA_HEIGHT_MAX_M / height_at_one_m


## A new drop for a board in a race of a stage (its next episode, in the same race); the race's wind
## sets how much of a leg C1 drops on.
static func drop(stage: Stage, race: RaceSim, course: Course, rng: RandomNumberGenerator, wind_kt: float = 18.0) -> RaceEnv.Drop:
	var steps: Array[RaceStep] = race.steps()
	match stage.kind:
		Kind.COURSE_LEGS:
			return _leg_drop(stage, steps, course.axis_deg, wind_kt, rng)
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
		Kind.LAPS, Kind.COURSE_RACE:
			var start: RaceStep = steps[0]
			var along: Vector2 = (start.points[1] - start.points[0]).normalized()
			var half_m: float = 0.5 * start.points[0].distance_to(start.points[1])
			var spot: Vector2 = start.target() + start.in_dir * rng.randf_range(10.0, 40.0) + along * rng.randf_range(-0.8, 0.8) * half_m
			var first_leg_deg: float = Course.bearing_deg(Vector2.ZERO, start.out_dir)
			var heading_deg: float = first_leg_deg + rng.randf_range(-30.0, 30.0)
			if stage.kind == Kind.COURSE_RACE:
				heading_deg = _out_of_irons(heading_deg, course.axis_deg, rng)
			return RaceEnv.Drop.at(spot, heading_deg, 1, 0)
	# START and COMPANY: a random spot in the sailing area, the start to do.
	return _spawn_drops(stage, course, 1, rng)[0]


## C1's drop: a random goal (the step after which the episode ends, the start never), and the board
## set down back along the course from it where the all-rounder would need a drawn share of the
## episode (LEG_BUDGET_MIN to LEG_BUDGET_MAX) to get there (expected_leg_s()): on a long leg part of
## the way along it, past a short one on the leg before (two legs at most: the goal is the next one
## or two steps). Up to LEG_ACROSS_SHARE of what is left to either side, heading along the leg give
## or take 40 degrees (out of irons). A drop at a short leg alone (T1's 109 m to the finish, 12 s)
## would teach little.
static func _leg_drop(stage: Stage, steps: Array[RaceStep], axis_deg: float, wind_kt: float, rng: RandomNumberGenerator) -> RaceEnv.Drop:
	var goal: int = rng.randi_range(2, steps.size())
	var budget_s: float = rng.randf_range(LEG_BUDGET_MIN, LEG_BUDGET_MAX) * stage.episode_s
	var k: int = goal - 1  # the leg the board is set down on: to step k
	var left_share: float = 1.0
	while true:
		var leg_s: float = expected_leg_s(steps[k - 1].target(), steps[k].target(), axis_deg, wind_kt)
		if leg_s >= budget_s:
			left_share = budget_s / leg_s
			break
		budget_s -= leg_s
		if k == 1 or k <= goal - 2:
			break  # at the start of the course, or two legs back: set down at this leg's beginning
		k -= 1
	var from: Vector2 = steps[k - 1].target()
	var to: Vector2 = steps[k].target()
	var along: Vector2 = (to - from).normalized()
	var across: Vector2 = Vector2(-along.y, along.x)
	var spot: Vector2 = to.lerp(from, left_share) + across * rng.randf_range(-LEG_ACROSS_SHARE, LEG_ACROSS_SHARE) * left_share * from.distance_to(to)
	var heading_deg: float = _out_of_irons(Course.bearing_deg(from, to) + rng.randf_range(-40.0, 40.0), axis_deg, rng)
	return RaceEnv.Drop.at(spot, heading_deg, k, goal)


## The all-rounder's time for a leg's straight line in a wind, seconds, roughly and a little long:
## its length over the leg's rate (LEG_RATE_*: beat, run or reach by the leg's angle to the wind)
## times the wind's factor.
static func expected_leg_s(from: Vector2, to: Vector2, axis_deg: float, wind_kt: float) -> float:
	var from_upwind_deg: float = absf(Course.turn_deg(axis_deg, Course.bearing_deg(from, to)))
	var rate_ms: float = LEG_RATE_REACH_MS
	if from_upwind_deg < BEAT_WITHIN_DEG:
		rate_ms = LEG_RATE_BEAT_MS
	elif from_upwind_deg > 180.0 - RUN_WITHIN_DEG:
		rate_ms = LEG_RATE_RUN_MS
	var wind_factor: float = clampf((wind_kt - 6.0) / 12.0, LEG_RATE_WIND_LOW, LEG_RATE_WIND_HIGH)
	return from.distance_to(to) / (rate_ms * wind_factor)


## A heading nearer the wind (the course's axis) than DROP_IRONS_DEG turned to close-hauled on a
## random side; any other as it is.
static func _out_of_irons(heading_deg: float, axis_deg: float, rng: RandomNumberGenerator) -> float:
	if absf(Course.turn_deg(axis_deg, heading_deg)) >= DROP_IRONS_DEG:
		return heading_deg
	return axis_deg + (DROP_CLOSE_HAULED_DEG if rng.randf() < 0.5 else -DROP_CLOSE_HAULED_DEG)


## T1 or T2, as the race tool lays them for the open water: T1 for the default wind's direction
## with its start line at the origin, T2 where the course maker saved it (on the lake's frame, sailed
## here on the open water, as tools/race.sh does).
static func plan_course(index: int) -> Course:
	if PLAN_COURSES[index] == "t1_loop":
		return RaceCourses.t1_loop((load(SettingsValues.WIND_DEFAULT_PATH) as WindConfig).from_bearing_deg, Vector2.ZERO)
	return RaceCourses.load_named(PLAN_COURSES[index], load(LAKE_MAP_CONFIG_PATH))


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


## A random course that has a step of the stage's kind (a slalom has no beat: another is drawn);
## for C1 and C2, T1 or T2 by a coin.
static func _course_for(stage: Stage, rng: RandomNumberGenerator, wind_kt: float) -> Course:
	if stage.kind == Kind.COURSE_LEGS or stage.kind == Kind.COURSE_RACE:
		var plan: Course = plan_course(rng.randi_range(0, PLAN_COURSES.size() - 1))
		if plan != null:
			return plan
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
