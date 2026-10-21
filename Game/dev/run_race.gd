extends SceneTree
## A headless race (RACING_PLAN.md, Parts 9A and 9B): boards on a course, the countdown, the gun, the
## race's own clock and checks (RaceSim), and one line per board at the end. Each board is sailed by
## a scripted skipper (Skipper, with a character sheet from Game/race/skippers/) on the beginner
## PlayerController, the player's own controls, or by the plain Autopilot of 9A holding one wind
## angle (it starts and sails on at that angle, and does not finish). Use tools/race.sh.
##
## Arguments after "--":
##   --course=test         a small loop made by code (the default): a start line 60 m long, mark 1
##                         300 m upwind (port), the gate 4S/4P 100 m above the line, and the finish
##                         line 150 m to the left of the gate
##   --course=t1_loop      the T1 training loop on open water (RaceCourses), the start line at the origin
##   --course=<name>       a course saved by the course maker, by name (t2_slalom, ...)
##   --course=<file.json>  a course saved by the course maker (a res:// path, a full path, or a path
##                         from the repository's folder), placed with the Silvaplana map's frame
##   [--skippers=autopilot] who sails the boards, by name, comma-separated: allrounder, cautious,
##                         gambler, rookie (the .tres files in Game/race/skippers/), or autopilot.
##                         The names are dealt round the boards in order.
##   [--boards=<n>]        how many boards (the default: one per name in --skippers)
##   [--seed=0]            the skippers' random seed (board i gets seed + i): the same seed, the same race
##   [--finish_window=60]  the race ends this long after the first board finishes, seconds (the game's
##                         rule; tools/race_matrix.sh waits longer, so every board gets a time)
##   [--laps=1] [--wind_kt=15]
##   [--seconds: the longest race time after the gun: 1200 with skippers, 300 with only autopilots]
##   [--prestart: the countdown, seconds: 60 (the game's) with skippers, 10 with only autopilots]
##   [--twa=50: the wind angle the autopilot holds]
##   [--spawn=line]        where the skippers' boards appear: line (behind the start line, below) or
##                         random (at random spots in the sailing area round the start line, as the
##                         game puts them: SailingArea; on the lake kept off the shore)
##   [--spawn_seed=0]      the seed of the random spots: the same seed, the same spots
##   [--free_sail=0]       seconds of free sailing before the countdown starts
##   [--behind=<m>]        how far behind the start line the skippers' boards wait (the usual is 1 m
##                         per second of countdown, 40 to 150 m); 150 with --prestart=30 is where the
##                         learned brains were trained
##   [--blind=1]           the learned brains see no other boards (as in their training)
##   [--stop_after_gun=<s>] stop the race this long after the gun (to look at the start only)
##   [--out_dir=<folder>: a CSV per board: race time, x, z, heading, speed, its next step, and what
##                         its skipper is doing]
## After the results it prints each skipper's start: how long after the gun it crossed the start
## line, whether it was over the line at the gun (OCS), and the boards outside the sailing area at the
## gun.
##
## Every board is the open water's default simulation with its waves, stepped at 1/60 s. The wind
## blows from the course's axis, so the course is square to it. After every tick the race is told
## where the boards are.
##
## Where the boards wait: a skipper sails the whole countdown itself, from RACING_PLAN.md's pre-start
## spot (RaceCourses.pre_start_spot(), 150 m behind the start line, spread across it, on a beam
## reach at rest), brought nearer the line for a countdown shorter than a minute, so that it can
## still get there. An autopilot cannot sail a countdown: it is put back along its approach so that
## it reaches the line at about the gun, and waits until SET_OFF_S before it.

const DT: float = 1.0 / 60.0
const MAP_CONFIG_PATH: String = "res://maps/silvaplana/map_config.tres"
## How far back along its approach an autopilot board is put for each second of the countdown,
## metres: about what a board starting from rest sails in that time in 15 kt (it averaged 4.8 m/s
## over its first 10 s), so that it reaches the line near the gun. More wind gets it there earlier,
## less later.
const APPROACH_M_PER_S: float = 4.5
## The autopilot boards are put back as if the countdown were this much longer, seconds: a
## fixed-angle pilot cannot go back behind the line, so a little late is better than over early.
const START_MARGIN_S: float = 3.0
## The autopilot boards set off this long before the gun, seconds; until then they wait where they
## were put (their simulations are not stepped). A fixed-angle pilot sailing a long countdown would
## drift far from the spot it was aimed at.
const SET_OFF_S: float = 10.0
## A skipper waits 150 m behind the line for a countdown of a minute (RaceCourses.PRE_START_BEHIND_M),
## and this much less per second of countdown short of that, but never nearer than SKIPPER_NEAREST_M.
## From 150 m behind the line of T1 (a beat) a skipper needs about 45 s to get to the line.
const SKIPPER_WAIT_M_PER_S: float = 2.5
const SKIPPER_NEAREST_M: float = 40.0
## The lake's shore grid, for the sailing area of a course on the lake (kept off the shore).
const SHORE_GRID_PATH: String = "res://maps/silvaplana/terrain/shore_heights.json"
## A CSV row every this many ticks (0.1 s).
const CSV_EVERY: int = 6


## One board in the race: its simulation, who sails it, and what is counted about it.
class Entry:
	var name: String = ""
	var sim: WindsurferSim
	var controls: SimControls
	## The 9A autopilot (--skippers=autopilot), or null.
	var pilot: Autopilot = null
	## A skipper on the beginner controller, with its hands on the controls (a scripted Skipper or a
	## LearnedSkipper); null for an autopilot.
	var skipper: RaceSkipper = null
	var controller: PlayerController = null
	var hands: AiHands = null
	## The race time from which the board is sailed (before it, it waits where it was put).
	var set_off_s: float = -INF
	var falls: int = 0
	var was_fallen: bool = false
	## The tacks and gybes the controller started.
	var tacks: int = 0
	var gybes: int = 0
	var last_manoeuvre: PlayerController.Manoeuvre = PlayerController.Manoeuvre.NONE
	var file: FileAccess = null


func _initialize() -> void:
	var options: Dictionary[String, String] = _read_user_args()
	var names: PackedStringArray = options.get("skippers", "autopilot").split(",", false)
	if names.is_empty():
		names = PackedStringArray(["autopilot"])
	var boards: int = maxi(options.get("boards", str(names.size())).to_int(), 1)
	var laps: int = maxi(options.get("laps", "1").to_int(), 1)
	var wind_kt: float = options.get("wind_kt", "15").to_float()
	# The skippers sail the game's whole countdown and the whole race (it ends when everyone is in);
	# the 9A autopilot only the last 10 s of the countdown, and it never finishes.
	var all_autopilot: bool = Array(names).all(func(skipper_name: String) -> bool: return skipper_name == "autopilot")
	var seconds: float = options.get("seconds", "300" if all_autopilot else "1200").to_float()
	var prestart_s: float = maxf(options.get("prestart", "10" if all_autopilot else "60").to_float(), 0.0)
	var twa_deg: float = options.get("twa", "50").to_float()
	var random_seed: int = options.get("seed", "0").to_int()
	var finish_window_s: float = options.get("finish_window", "60").to_float()
	var out_dir: String = options.get("out_dir", _repository_path(".sim_output/race"))
	var spawn: String = options.get("spawn", "line")
	var spawn_seed: int = options.get("spawn_seed", "0").to_int()
	var free_sail_s: float = maxf(options.get("free_sail", "0").to_float(), 0.0)
	var stop_after_gun_s: float = options["stop_after_gun"].to_float() if options.has("stop_after_gun") else INF
	var behind_m: float = options.get("behind", "-1").to_float()
	var blind: bool = options.get("blind", "0") != "0"

	var course_name: String = options.get("course", "test")
	var course: Course = course_named(course_name)
	if course == null:
		quit(2)
		return
	var race: RaceSim = RaceSim.new(course, laps, prestart_s)
	race.finish_window_s = finish_window_s
	if race.steps().is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	var area: SailingArea = sailing_area_for(course_name, course)

	var who: PackedStringArray = PackedStringArray()
	for i: int in boards:
		who.append(names[i % names.size()])
	var entries: Array[Entry] = make_entries(race, course, who, wind_kt, twa_deg, random_seed, spawn, area, spawn_seed, behind_m)
	if entries.is_empty():
		quit(2)
		return
	for entry: Entry in entries:
		entry.file = FileAccess.open(out_dir.path_join(_file_name(entry.name) + ".csv"), FileAccess.WRITE)
		if entry.file != null:
			entry.file.store_line("race_time_s,x_m,z_m,heading_deg,speed_ms,next_step,doing")
	race.start_in(free_sail_s)

	var outside_at_gun: PackedStringArray = PackedStringArray()
	var gun_seen: bool = false
	var ticks: int = roundi((free_sail_s + prestart_s + seconds) / DT)
	for tick: int in ticks:
		step_race(race, entries, blind)
		if tick % CSV_EVERY == 0:
			for i: int in entries.size():
				_write_row(entries[i], race, i)
		if not gun_seen and race.is_started() and race.clock_s() >= 0.0:
			gun_seen = true
			outside_at_gun = boards_outside(race, area)
		if race.phase() == RaceSim.Phase.FINISHED or race.clock_s() >= stop_after_gun_s:
			break
	for entry: Entry in entries:
		if entry.file != null:
			entry.file.close()

	print("Race on %s (%s, %d lap%s, %d steps): wind %.0f kt from %.0f deg, %s, seed %d, pre-start %.0f s, spawn %s (seed %d)" % [
		course.name, course.sequence, laps, "" if laps == 1 else "s", race.steps().size(), wind_kt, course.axis_deg,
		", ".join(who) + (" at TWA %.0f" % twa_deg if who.has("autopilot") else ""), random_seed, prestart_s, spawn, spawn_seed])
	for result: RaceResult in race.results():
		var entry: Entry = entries[result.index]
		# An unfinished board: how far it still is from its next step, so that boards that never
		# finish can still be compared (the generations of a night, tools/gens.sh).
		var to_next: String = "" if result.finished else "  to %s %.0f m" % [race.next_step_name(result.index), race.distance_to_next_m(result.index)]
		print("%s  falls %d  tacks %d  gybes %d%s" % [result.to_line(), entry.falls, entry.tacks, entry.gybes, to_next])
	print("%s at race time %s; CSV files in %s" % [
		"Finished" if race.phase() == RaceSim.Phase.FINISHED else "Stopped", RaceResult.format_time(race.race_time_s()), out_dir])
	print(start_report(race, entries, outside_at_gun))
	quit(0)


## The start of every skipper's board, one line each: how long after the gun it crossed the start
## line (its start delay; "-" if it has not started), whether it was over the line at the gun (OCS),
## and a summary: the longest delay, the OCS count, and the boards outside the area at the gun.
static func start_report(race: RaceSim, entries: Array[Entry], outside_at_gun: PackedStringArray) -> String:
	var lines: PackedStringArray = PackedStringArray(["Starts:"])
	var longest_s: float = 0.0
	var not_started: int = 0
	var ocs: int = 0
	for i: int in entries.size():
		var skipper: Skipper = entries[i].skipper as Skipper
		if skipper == null:
			continue
		var started: bool = race.next_step_index(i) > 0
		var delay_s: float = race.splits_s(i)[0] if started else NAN
		if started:
			longest_s = maxf(longest_s, delay_s)
		else:
			not_started += 1
		if skipper.was_ocs:
			ocs += 1
		lines.append("  %-16s start %s%s" % [entries[i].name, "%+6.1f s" % delay_s if started else "   -   ", "  OCS" if skipper.was_ocs else ""])
	lines.append("  longest start delay %.1f s, %d not started, %d OCS, %d outside the sailing area at the gun%s" % [
		longest_s, not_started, ocs, outside_at_gun.size(), (": " + ", ".join(outside_at_gun)) if not outside_at_gun.is_empty() else ""])
	return "\n".join(lines)


## The boards outside the sailing area now (by name).
static func boards_outside(race: RaceSim, area: SailingArea) -> PackedStringArray:
	var outside: PackedStringArray = PackedStringArray()
	if area == null:
		return outside
	for i: int in race.board_count():
		if not area.contains(race.board_position(i)):
			outside.append(race.board_name(i))
	return outside


## The sailing area of a course: round its start line, kept off the lake's shore for a course on the
## lake (any course but the test loop and T1).
static func sailing_area_for(course_name: String, course: Course) -> SailingArea:
	if course_name == "test" or course_name == "t1_loop":
		return SailingArea.for_course(course)
	return SailingArea.for_course(course, TerrainGrid.load_from(SHORE_GRID_PATH))


# ---------------------------------------------------------------- the race, for this tool and the tests

## The boards of a race, one per name (a character, or "autopilot"), added to the race in order and
## placed for its countdown; board i's skipper gets the seed random_seed + i. With spawn "random"
## the skippers' boards appear at random spots of the sailing area (SailingArea.spawn_places(), as
## in the game), seeded by spawn_seed; with "line" behind the start line. Every skipper sails free in
## the area (one round the start line when none is given). Empty if a name is not a skipper.
static func make_entries(race: RaceSim, course: Course, who: PackedStringArray, wind_kt: float, twa_deg: float = 50.0, random_seed: int = 0,
		spawn: String = "line", area: SailingArea = null, spawn_seed: int = 0, behind_m: float = -1.0) -> Array[Entry]:
	var entries: Array[Entry] = []
	var used: Dictionary[String, int] = {}
	if area == null:
		area = SailingArea.for_course(course)
	var places: Array[Vector3] = []
	if spawn == "random":
		places = area.spawn_places(who.size(), spawn_seed)
	for i: int in who.size():
		var share: float = float(i + 1) / (who.size() + 1)
		var entry: Entry
		if who[i] == "autopilot":
			entry = _make_autopilot_board(race, course.axis_deg, wind_kt, twa_deg, share)
			entry.name = "board%d" % (i + 1)
		else:
			entry = _make_skipper_board(who[i], race, course, wind_kt, share, behind_m)
			if entry == null:
				var none: Array[Entry] = []
				return none
			if not places.is_empty():
				entry.sim.reset(Vector3(places[i].x, 0.0, places[i].y), deg_to_rad(places[i].z))
				entry.controller.reset_controls(entry.controls)
			entry.skipper.sailing_area = area
			entry.skipper.random_seed = random_seed + i
			# Two of the same character are told apart by their number.
			used[entry.name] = used.get(entry.name, 0) + 1
			if who.count(who[i]) > 1:
				entry.name = "%s %d" % [entry.name, used[entry.name]]
		race.add_board(entry.name)
		race.update_board(i, _where(entry))
		entries.append(entry)
	# The skippers look at the whole fleet, so they are set up once every board is in the race.
	for i: int in entries.size():
		if entries[i].skipper != null:
			entries[i].skipper.setup(entries[i].sim, entries[i].controller, entries[i].hands, race, i)
	return entries


## One tick of the race: every board (its sailor, the physics, the falls and the manoeuvres
## counted), the race told where each one is, and the race clock moved on. With `blind` the
## skippers are not told where the others are (the learned brains were trained alone).
static func step_race(race: RaceSim, entries: Array[Entry], blind: bool = false) -> void:
	for i: int in entries.size():
		if entries[i].skipper != null and entries.size() > 1 and not blind:
			_tell_others(entries, i)
		if race.clock_s() >= entries[i].set_off_s:
			_sail(entries[i])
		race.update_board(i, _where(entries[i]))
	race.step(DT)


## The course to race: the test loop, T1, or a course file.
static func course_named(name: String) -> Course:
	if name == "test":
		return _test_course(EnvironmentConfig.new().wind_or_default().from_bearing_deg)
	# The built-in courses and the team's saved ones, by name (RaceCourses); anything else is a path.
	if name == "t1_loop":
		return RaceCourses.t1_loop(EnvironmentConfig.new().wind_or_default().from_bearing_deg, Vector2.ZERO)
	var named: Course = RaceCourses.load_named(name, load(MAP_CONFIG_PATH))
	if named != null:
		return named
	var path: String = name
	if not (path.begins_with("res://") or path.begins_with("user://") or path.is_absolute_path()):
		path = _repository_path(path)
	var course: Course = Course.load_from(path, load(MAP_CONFIG_PATH))
	if course == null:
		push_error("No course file at %s (--course=test, or the path of a course maker's .json file)." % path)
	return course


# ---------------------------------------------------------------- the course

## The small loop of --course=test, set for a wind direction (where it comes from), with the middle of
## its start line at the origin. Drawn in the frame of the course diagrams, as CourseTemplates does:
## up toward the wind, right to the right looking upwind.
static func _test_course(axis_deg: float) -> Course:
	var course: Course = Course.new()
	course.name = "the test loop"
	course.axis_deg = axis_deg
	course.boards = 4
	course.add_mark(CourseMark.START_BOAT, Vector2(30.0, 0.0))
	course.add_mark(CourseMark.START_PIN, Vector2(-30.0, 0.0))
	course.add_mark("1", Vector2(0.0, 300.0), CourseMark.Rounding.PORT)
	course.add_mark("4S", Vector2(-20.0, 100.0), CourseMark.Rounding.STARBOARD)
	course.add_mark("4P", Vector2(20.0, 100.0), CourseMark.Rounding.PORT)
	# The finish line along the wind, crossed going left from the gate; its boat at the upwind end.
	course.add_mark(CourseMark.FINISH_BOAT, Vector2(-150.0, 120.0))
	course.add_mark(CourseMark.FINISH_PIN, Vector2(-150.0, 80.0))
	var problem: String = course.set_sequence("Start-1-4S/4P-Finish")
	if problem != "":
		push_error(problem)
	var up: Vector2 = Course.direction_of(axis_deg)
	var right: Vector2 = Course.direction_of(axis_deg + 90.0)
	for mark: CourseMark in course.marks:
		mark.position = right * mark.position.x + up * mark.position.y
	return course


# ---------------------------------------------------------------- the boards

## The open water's default simulation with its waves (as WindsurferSim.create_default(true)
## builds it), in a wind of some knots from a direction. Every board gets copies of the
## configuration files of its own: boards stepped side by side on threads (tests/unit/
## test_skipper.gd) would otherwise all read the same objects, and that slowed each of them down
## several times over. The numbers are the same.
static func _make_sim(wind_from_deg: float, wind_kt: float) -> WindsurferSim:
	var environment: EnvironmentConfig = EnvironmentConfig.new()
	var wind_config: WindConfig = environment.wind_or_default().duplicate(true)
	wind_config.speed_kt = wind_kt
	wind_config.from_bearing_deg = wind_from_deg
	var sim: WindsurferSim = WindsurferSim.new(
		load("res://config/board_default.tres").duplicate(true),
		load("res://config/sail_default.tres").duplicate(true),
		load("res://config/fin_default.tres").duplicate(true),
		load("res://config/sailor_default.tres").duplicate(true),
		environment.water_or_default().duplicate(true),
		wind_config,
		load("res://config/sim_default.tres").duplicate(true),
		environment.waves_or_default().duplicate(true))
	sim.air_density_kg_m3 = environment.air_density_kg_m3
	sim.set_waves(true)
	return sim


## A skipper's board: at the pre-start spot (brought nearer the line for a short countdown), at
## `share` of the way across the line's width, on the pre-start's beam reach, at rest. Its skipper
## drives the beginner controller (auto-sheet on), as the player's board is set up in the game.
static func _make_skipper_board(skipper_name: String, race: RaceSim, course: Course, wind_kt: float, share: float, behind_m: float = -1.0) -> Entry:
	var skipper: RaceSkipper = Skippers.make(skipper_name)
	if skipper == null:
		return null
	var entry: Entry = Entry.new()
	entry.name = skipper.skipper_name()
	entry.skipper = skipper
	entry.sim = _make_sim(course.axis_deg, wind_kt)
	entry.controller = PlayerController.new()
	entry.controller.set_sail(entry.sim.sail, entry.sim.sailor_config, entry.sim.air_density_kg_m3)
	entry.hands = AiHands.new()
	entry.controller.hands = entry.hands
	entry.controls = _fresh_controls()
	var start: RaceStep = race.steps()[0]
	# Where it waits: --behind, or 1 m per second of countdown within the usual bounds.
	var behind: float = behind_m if behind_m > 0.0 else clampf(race.prestart_s * SKIPPER_WAIT_M_PER_S, SKIPPER_NEAREST_M, RaceCourses.PRE_START_BEHIND_M)
	var along: Vector2 = start.points[0] - start.points[1]
	var at: Vector2 = RaceCourses.pre_start_spot(course) + start.in_dir * (RaceCourses.PRE_START_BEHIND_M - behind) + along * (share - 0.5)
	entry.sim.reset(Vector3(at.x, 0.0, at.y), deg_to_rad(RaceCourses.pre_start_heading_deg(course)))
	entry.controller.reset_controls(entry.controls)
	return entry


## A 9A autopilot board behind the start line at `share` of the way along it (from the pin to the
## boat), on the tack that points nearer the first leg, far enough back to reach the line at about
## the gun.
static func _make_autopilot_board(race: RaceSim, wind_from_deg: float, wind_kt: float, twa_deg: float, share: float) -> Entry:
	var entry: Entry = Entry.new()
	entry.sim = _make_sim(wind_from_deg, wind_kt)
	entry.pilot = Autopilot.new()
	entry.pilot.target_twa_deg = twa_deg
	entry.pilot.sail = entry.sim.sail
	entry.pilot.sailor = entry.sim.sailor_config
	entry.pilot.air_density_kg_m3 = entry.sim.air_density_kg_m3
	entry.controls = _fresh_controls()
	entry.set_off_s = -SET_OFF_S
	# From standstill the pilot sails no closer than bear_away_twa_deg until it has speed, so the
	# board comes up to the line along that angle: put it back along that line from its spot.
	var start: RaceStep = race.steps()[0]
	var approach_twa_deg: float = maxf(twa_deg, entry.pilot.bear_away_twa_deg)
	var heading_deg: float = _heading_toward(Course.bearing_deg(Vector2.ZERO, start.in_dir), wind_from_deg, approach_twa_deg)
	var on_line: Vector2 = start.points[1].lerp(start.points[0], share)
	var sailing_s: float = minf(race.prestart_s, SET_OFF_S) + START_MARGIN_S
	var at: Vector2 = on_line - Course.direction_of(heading_deg) * sailing_s * APPROACH_M_PER_S
	entry.sim.reset(Vector3(at.x, 0.0, at.y), deg_to_rad(heading_deg))
	return entry


## One tick of a board: the sailor (while on the board), the physics, the falls and the manoeuvres
## counted.
static func _sail(entry: Entry) -> void:
	var sailing: bool = entry.sim.sailor_state == WindsurferSim.SailorState.SAILING
	if entry.skipper != null:
		# The skipper keeps watching from the water too (its clock runs, its hands come off).
		entry.skipper.update(entry.sim.telemetry, DT)
		if sailing:
			entry.controller.update(entry.sim.telemetry, entry.controls, DT)
		_count_manoeuvres(entry)
	elif sailing:
		entry.pilot.update(entry.sim.telemetry, entry.controls, DT)
	entry.sim.step(DT, entry.controls)
	var fallen: bool = entry.sim.sailor_state == WindsurferSim.SailorState.FALLEN
	if fallen and not entry.was_fallen:
		entry.falls += 1
	elif entry.was_fallen and not fallen:
		# Up again after the waterstart (the simulation does it after a while): the sail eased, as at
		# the start, and the controller starts afresh, as the game's board does (windsurfer.gd).
		if entry.controller != null:
			entry.controller.reset_controls(entry.controls)
		else:
			entry.controls = _fresh_controls()
	entry.was_fallen = fallen


## Counts a tack or a gybe when the controller starts one.
static func _count_manoeuvres(entry: Entry) -> void:
	var now: PlayerController.Manoeuvre = entry.controller.manoeuvre
	if now != entry.last_manoeuvre and entry.last_manoeuvre == PlayerController.Manoeuvre.NONE:
		if now == PlayerController.Manoeuvre.TACK_HEADING_UP or now == PlayerController.Manoeuvre.TACK_BEARING_AWAY:
			entry.tacks += 1
		else:
			entry.gybes += 1
	entry.last_manoeuvre = now


## The compass heading that holds a wind angle on the tack that points nearer a bearing. On
## starboard tack the wind comes over the right side, so the heading is the wind's direction less
## the angle; on port tack, plus it.
static func _heading_toward(bearing_deg: float, wind_from_deg: float, twa_deg: float) -> float:
	var starboard: float = fposmod(wind_from_deg - twa_deg, 360.0)
	var port: float = fposmod(wind_from_deg + twa_deg, 360.0)
	if absf(Course.turn_deg(starboard, bearing_deg)) <= absf(Course.turn_deg(port, bearing_deg)):
		return starboard
	return port


## A sailor starts with the sail eased and sheets in as the board gets going (as SimScenario does).
static func _fresh_controls() -> SimControls:
	var controls: SimControls = SimControls.new()
	controls.sheet = 0.0
	return controls


## Where a board is, game X and Z.
static func _where(entry: Entry) -> Vector2:
	var position: Vector3 = entry.sim.telemetry.position
	return Vector2(position.x, position.z)


## Board i's skipper is told where the other boards are and how they move (a learned skipper looks
## at the nearest two; a scripted one reads the race instead and ignores this).
static func _tell_others(entries: Array[Entry], i: int) -> void:
	var positions: PackedVector2Array = PackedVector2Array()
	var velocities: PackedVector2Array = PackedVector2Array()
	for j: int in entries.size():
		if j == i:
			continue
		positions.append(_where(entries[j]))
		var v: Vector3 = entries[j].sim.body.velocity
		velocities.append(Vector2(v.x, v.z))
	entries[i].skipper.set_others(positions, velocities)


func _write_row(entry: Entry, race: RaceSim, index: int) -> void:
	if entry.file == null:
		return
	var t: Telemetry = entry.sim.telemetry
	var doing: String = entry.skipper.note if entry.skipper != null else "autopilot"
	entry.file.store_line("%.2f,%.2f,%.2f,%.1f,%.2f,%d,%s" % [race.clock_s(), t.position.x, t.position.z, t.heading_deg, t.speed_ms, race.next_step_index(index), doing.replace(",", ";")])


## A board's name as a file name: "All-rounder 2" is all-rounder_2.
static func _file_name(board_name: String) -> String:
	return board_name.to_lower().replace(" ", "_")


# ---------------------------------------------------------------- arguments and paths

## A path in the repository's folder (the one above Game/).
static func _repository_path(relative: String) -> String:
	return ProjectSettings.globalize_path("res://").path_join("..").path_join(relative).simplify_path()


func _read_user_args() -> Dictionary[String, String]:
	var options: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
			options[parts[0]] = parts[1]
	return options
