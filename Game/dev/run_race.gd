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
##   --course=template:O2  an iQFOiL template at the class's full size, or template:PD3@60 at 60 % (any of
##                         LG2, LR2, O2, I2, US3, US4, PD3, SD3, PM1, SM1): the trained head on every template
##   --course=<name>       a course saved by the course maker, by name (t2_slalom, ...)
##   --course=<file.json>  a course saved by the course maker (a res:// path, a full path, or a path
##                         from the repository's folder), placed with the Silvaplana map's frame
##   [--skippers=autopilot] who sails the boards, by name, comma-separated: allrounder, cautious,
##                         gambler, rookie (the .tres files in Game/race/skippers/), or autopilot.
##                         The names are dealt round the boards in order.
##   [--boards=<n>]        how many boards (the default: one per name in --skippers)
##   [--seed=0]            the skippers' random seed (board i gets seed + i): the same seed, the same race
##   [--spread=1]          the personas' levels (RaceSkipper.level_spread): 1 the sheets as written, the
##                         game's RaceSetup.LEVEL_CLOSE closer together
##   [--finish_window=60]  the race ends this long after the first board finishes, seconds (the game's
##                         rule; tools/race_matrix.sh waits longer, so every board gets a time)
##   [--laps=1] [--wind_kt=15]
##   [--seconds: how long the race is sailed after the gun: with skippers the race's own time limit
##                         for its course and wind (RaceTimeLimit: 2.5 times the polar's time, at least
##                         1200 s); a longer --seconds raises that limit, a shorter one stops the race
##                         early; 300 with only autopilots]
##   [--prestart: the countdown, seconds: 60 (the game's) with skippers, 10 with only autopilots]
##   [--twa=50: the wind angle the autopilot holds]
##   [--spawn=line]        where the skippers' boards appear: line (behind the start line, below) or
##                         random (at random spots in the sailing area round the start line, as the
##                         game puts them: SailingArea; on the lake kept off the shore)
##   [--spawn_seed=0]      the seed of the random spots: the same seed, the same spots
##   [--free_sail=0]       seconds of free sailing before the countdown starts
##   [--behind=<m>]        how far behind the start line the skippers' boards wait (the game's: 1 m
##                         per second of countdown, 40 to 100 m, RaceRunner); 150 with --prestart=30 is
##                         where the learned brains were trained (tools/gens.sh passes it)
##   [--blind=1]           the learned brains see no other boards (as in their training)
##   [--manoeuvre_gap_s=<s>] the learned brains' tack discipline (LearnedSkipper, RA14): the least time
##                         between two manoeuvres; without it each brain keeps the one it was trained
##                         with (6 s for the brains before RA14)
##   [--closest_twa_deg=<deg>] the closest to the wind the learned brains' hands steer; without it each
##                         keeps its own (none for the brains before RA14)
##   [--shadows=1]         the sails cast wind shadows on each other (F3, WindShadows); 0 turns them off
##   [--rules=1]           the racing rules are kept (F3, RaceRules): a scripted skipper turns a circle for a
##                         penalty, a learned one carries 20 s to the finish; 0 turns them off
##   [--gear=1]            each persona sails its own board, sail and fin from the gear catalogue, sized
##                         for the wind (Persona.gear_for()), as in the game (RaceSetup.gear); 0: the
##                         default gear for every board. The other skippers keep the default gear. The
##                         gear is printed before the race
##   [--steady_hands=0]    1: every scripted skipper's hands as quick and steady as the all-rounder's
##                         (STEADY_REACTION_S, STEADY_NOISE_DEG), to measure what the personas' noise costs
##   [--skipper_push=1]    0: the scripted skippers leave the push slider alone and sail the pilot's own
##                         margin, as every AI board did before the skipper set it (to compare)
##   [--polar=<file.tres>] the scripted skippers sail with another polar (SkipperPolar; a res:// path or a
##                         path from the repository's folder) instead of Game/config/skipper_polar.tres
##   [--stop_after_gun=<s>] stop the race this long after the gun (to look at the start only)
##   [--map=lake]          the boards sail on Lake Silvaplana as the game sails it there: the lake's
##                         air and water, the map's wind of the hour (its gusts, lulls, shifts and lee)
##                         and the lake's own waves (PHYSICS_SPEC.md 9.17, 9.18), at --time=14:30 (any
##                         hh:mm); --wind_kt is then the lake's mean wind of that hour. With a course
##                         on the lake (t2_slalom). --lake_wave_scale=<x> sets the waves' height.
##                         --lake_wind_scale=<x> the map's wind times x (and the waves grown from it).
##                         On the lake a board whose fin touches the bottom has run aground: it stops
##                         where it is (as in the game, RaceRunner) and an AGROUND line says where and
##                         what its skipper was doing; the count is printed at the end. The skippers
##                         look out for the shore (ShoreLookout); --shore_guard=0 races without.
##                         Without it every board sails the open water (below)
##   [--pilot.<field>=<n>] [--controller.<field>=<n>] a tuning number of every skipper's beginner
##                         controller (PlayerController) or its auto-sheet pilot (Autopilot, through
##                         the controller's pilot_overrides), for the autopilot's suite
##   [--trace=<board name>] that board's whole telemetry, a row every 0.05 s, to <out_dir>/trace_<name>.csv
##   [--sailor.<field>=<n>] a number of every skipper's sailor (SailorConfig, on its own gear too):
##                         the fall rule's, for the stay-on-the-board work
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
## Where the boards wait: a skipper sails the whole countdown itself, from where the game puts the
## boards with its spawn on the line (RaceRunner: 1 m behind the start line per second of countdown,
## 40 to 100 m; spread across it, on a beam reach at rest), or --behind. An autopilot cannot sail a countdown: it is put back along its approach so that
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
## The lake's shore grid, for the sailing area of a course on the lake (kept off the shore).
const SHORE_GRID_PATH: String = "res://maps/silvaplana/terrain/shore_heights.json"
## The all-rounder's hands (Game/race/skippers/allrounder.tres), for --steady_hands=1.
const STEADY_REACTION_S: float = 0.25
const STEADY_NOISE_DEG: float = 0.5
## A CSV row every this many ticks (0.1 s).
const CSV_EVERY: int = 6
const LAKE_ENVIRONMENT_PATH: String = "res://maps/silvaplana/environment_silvaplana.tres"

## --map=lake: the lake's environment and the hour of its wind (null: the open water).
static var _lake: EnvironmentConfig = null
static var _lake_time_s: float = 14.5 * 3600.0
## --pilot.<field> and --controller.<field> for every skipper's controller.
static var _controller_overrides: Dictionary[String, float] = {}
## --sailor.<field> for every skipper's sailor.
static var _sailor_overrides: Dictionary[String, float] = {}
static var _overrides_read: bool = false


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
	## On the lake: it ran aground and has stopped (_check_the_bottom()).
	var aground: bool = false
	## The tacks and gybes the controller started.
	var tacks: int = 0
	var gybes: int = 0
	var last_manoeuvre: PlayerController.Manoeuvre = PlayerController.Manoeuvre.NONE
	## The other sails' wind shadows on this board's wind (--shadows=1), or null.
	var shadows: WindShadows = null
	var file: FileAccess = null
	## Every fall with the 2 s before it (FallLog; null: not watched).
	var fall_log: FallLog = null
	## The whole telemetry, a row every 3 ticks (--trace=<board name>), or null.
	var trace_file: FileAccess = null


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
	var seconds: float = options.get("seconds", "300" if all_autopilot else "0").to_float()
	var prestart_s: float = maxf(options.get("prestart", "10" if all_autopilot else "60").to_float(), 0.0)
	var twa_deg: float = options.get("twa", "50").to_float()
	var random_seed: int = options.get("seed", "0").to_int()
	var level_spread: float = clampf(options.get("spread", "1").to_float(), 0.0, 1.0)
	var finish_window_s: float = options.get("finish_window", "60").to_float()
	var out_dir: String = options.get("out_dir", _repository_path(".sim_output/race"))
	var spawn: String = options.get("spawn", "line")
	var spawn_seed: int = options.get("spawn_seed", "0").to_int()
	var free_sail_s: float = maxf(options.get("free_sail", "0").to_float(), 0.0)
	var stop_after_gun_s: float = options["stop_after_gun"].to_float() if options.has("stop_after_gun") else INF
	var behind_m: float = options.get("behind", "-1").to_float()
	var blind: bool = options.get("blind", "0") != "0"
	var shadows: bool = options.get("shadows", "1") != "0"
	var with_rules: bool = options.get("rules", "1") != "0"
	var with_gear: bool = options.get("gear", "1") != "0"
	var shore_guard: bool = options.get("shore_guard", "1") != "0"
	var skipper_push: bool = options.get("skipper_push", "1") != "0"
	var steady_hands: bool = options.get("steady_hands", "0") == "1"
	var polar_path: String = options.get("polar", "")
	if options.get("map", "open") == "lake":
		_lake = load(LAKE_ENVIRONMENT_PATH)
		var clock: PackedStringArray = options.get("time", "14:30").split(":")
		_lake_time_s = clock[0].to_float() * 3600.0 + (clock[1].to_float() * 60.0 if clock.size() > 1 else 0.0)
		wind_kt = _lake.map_wind().moment(_lake_time_s).lake_speed_ms / SimMath.KNOT_MS
		print("On Lake Silvaplana at %s: the lake's mean wind %.1f kt from %.0f deg, its own waves" % [
			options.get("time", "14:30"), wind_kt, _lake.map_wind().lake_from_deg(_lake_time_s)])
	for key: String in options:
		if key.begins_with("pilot.") or key.begins_with("controller."):
			_controller_overrides[key] = options[key].to_float()
		elif key.begins_with("sailor."):
			_sailor_overrides[key.trim_prefix("sailor.")] = options[key].to_float()

	var course_name: String = options.get("course", "test")
	var course: Course = course_named(course_name)
	if course == null:
		quit(2)
		return
	var race: RaceSim = RaceSim.new(course, laps, prestart_s)
	race.finish_window_s = finish_window_s
	# The race's own time limit for its course and wind, as the game sets it; --seconds raises it.
	race.time_limit_s = maxf(RaceTimeLimit.for_race(race, course.axis_deg, wind_kt), seconds)
	if not all_autopilot and not options.has("seconds"):
		seconds = race.time_limit_s
	if race.steps().is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	var area: SailingArea = sailing_area_for(course_name, course)

	var who: PackedStringArray = PackedStringArray()
	for i: int in boards:
		who.append(names[i % names.size()])
	var entries: Array[Entry] = make_entries(race, course, who, wind_kt, twa_deg, random_seed, spawn, area, spawn_seed, behind_m, with_gear, level_spread)
	if entries.is_empty():
		quit(2)
		return
	if options.has("manoeuvre_gap_s"):
		for entry: Entry in entries:
			var learned: LearnedSkipper = entry.skipper as LearnedSkipper
			if learned != null:
				learned.manoeuvre_gap_s = maxf(options["manoeuvre_gap_s"].to_float(), 0.0)
	if options.has("closest_twa_deg"):
		for entry: Entry in entries:
			var learned: LearnedSkipper = entry.skipper as LearnedSkipper
			if learned != null:
				learned.closest_twa_deg = clampf(options["closest_twa_deg"].to_float(), 0.0, 90.0)
	if shadows:
		give_shadows(entries)
	# The lake's bottom: where a board runs aground, and what the skippers see of the shore.
	var bottom: TerrainGrid = null
	if _lake != null:
		bottom = _lake.depth_grid()
		if bottom == null:
			bottom = TerrainGrid.load_from(SHORE_GRID_PATH)
		if shore_guard:
			var lookout: ShoreLookout = ShoreLookout.for_lake(bottom, course.start_middle())
			for entry: Entry in entries:
				if entry.skipper != null:
					entry.skipper.shore = lookout
	var rules: RaceRules = give_rules(entries, race, course) if with_rules else null
	if steady_hands:
		steady_the_hands(entries)
	if not tune_skippers(entries, skipper_push, polar_path):
		quit(2)
		return
	print_sheets(entries)
	var file_names: Dictionary[String, int] = {}
	for entry: Entry in entries:
		# One file per board, whatever the names: a second board of the same name gets _2.
		var file_name: String = _file_name(entry.name)
		file_names[file_name] = file_names.get(file_name, 0) + 1
		if file_names[file_name] > 1:
			file_name += "_%d" % file_names[file_name]
		entry.file = FileAccess.open(out_dir.path_join(file_name + ".csv"), FileAccess.WRITE)
		if entry.file != null:
			entry.file.store_line("race_time_s,x_m,z_m,heading_deg,speed_ms,next_step,doing")
		# Every fall with the 2 s before it and what the skipper was doing (FALL_DETAIL lines, for
		# tools/fall_detail.py).
		var clock_text: String = options.get("time", "14:30") if _lake != null else "-"
		entry.fall_log = FallLog.new("race", entry.name.replace(",", ";"), clock_text, "lake" if _lake != null else "open%.0f" % wind_kt)
		if options.get("trace", "") == entry.name:
			entry.trace_file = FileAccess.open(out_dir.path_join("trace_%s.csv" % file_name), FileAccess.WRITE)
			if entry.trace_file != null:
				entry.trace_file.store_line(Telemetry.csv_header())
	race.start_in(free_sail_s)

	var outside_at_gun: PackedStringArray = PackedStringArray()
	var gun_seen: bool = false
	var ticks: int = roundi((free_sail_s + prestart_s + seconds) / DT)
	var aground_count: int = 0
	for tick: int in ticks:
		step_race(race, entries, blind, rules)
		if bottom != null:
			aground_count += _check_the_bottom(bottom, race, entries)
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

	print("Race on %s (%s, %d lap%s, %d steps): wind %.0f kt from %.0f deg, %s, seed %d, pre-start %.0f s, spawn %s (seed %d)%s" % [
		course.name, course.sequence, laps, "" if laps == 1 else "s", race.steps().size(), wind_kt, course.axis_deg,
		", ".join(who) + (" at TWA %.0f" % twa_deg if who.has("autopilot") else ""), random_seed, prestart_s, spawn, spawn_seed,
		(", wind shadows" if shadows else "") + (", the rules" if with_rules else "")])
	for result: RaceResult in race.results():
		var entry: Entry = entries[result.index]
		# An unfinished board: how far it still is from its next step, so that boards that never
		# finish can still be compared (the generations of a night, tools/gens.sh).
		var to_next: String = "" if result.finished else "  to %s %.0f m" % [race.next_step_name(result.index), race.distance_to_next_m(result.index)]
		print("%s  falls %d  tacks %d  gybes %d%s" % [result.to_line(), entry.falls, entry.tacks, entry.gybes, to_next])
	print("%s at race time %s; CSV files in %s" % [
		"Finished" if race.phase() == RaceSim.Phase.FINISHED else "Stopped", RaceResult.format_time(race.race_time_s()), out_dir])
	print(start_report(race, entries, outside_at_gun))
	if rules != null:
		print(penalty_report(rules, entries))
	if bottom != null:
		print("Aground: %d of %d boards%s" % [aground_count, entries.size(), " (the skippers look out for the shore)" if shore_guard else " (no shore lookout)"])
	quit(0)


## The boards whose fin has touched the lake's bottom this tick (ShoreCheck, as the game's): stopped
## where they are, each with an AGROUND line. How many ran aground now.
static func _check_the_bottom(bottom: TerrainGrid, race: RaceSim, entries: Array[Entry]) -> int:
	var count: int = 0
	for i: int in entries.size():
		var entry: Entry = entries[i]
		if entry.aground or race.is_finished(i) and race.phase() == RaceSim.Phase.FINISHED:
			continue
		if ShoreCheck.is_aground(bottom, entry.sim.body.origin_world(), entry.sim.fin_config.span_m):
			entry.aground = true
			count += 1
			var at: Vector2 = _where(entry)
			print("AGROUND %s at race time %.1f s, (%.0f, %.0f), heading %.0f deg, %.1f m/s, sailing to %s: %s" % [
				entry.name.replace(" ", "_"), race.clock_s(), at.x, at.y, entry.sim.telemetry.heading_deg, entry.sim.telemetry.speed_ms,
				race.next_step_name(i), entry.skipper.note if entry.skipper != null else "autopilot"])
	return count


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


## The penalties: one line per board that got any (how many, how many it cleared by turning, the
## time it carried), and the total.
static func penalty_report(rules: RaceRules, entries: Array[Entry]) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var total: int = 0
	for i: int in entries.size():
		var given: int = rules.penalties(i) + rules.turns_done(i)
		total += given
		if given > 0:
			lines.append("  %-16s %d penalt%s, %d turned, %.0f s carried" % [entries[i].name, given, "y" if given == 1 else "ies", rules.turns_done(i), rules.time_penalty_s(i)])
	lines.insert(0, "Penalties: %d" % total)
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
		spawn: String = "line", area: SailingArea = null, spawn_seed: int = 0, behind_m: float = -1.0, gear: bool = false,
		level_spread: float = 1.0) -> Array[Entry]:
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
			entry = _make_skipper_board(who[i], race, course, wind_kt, share, behind_m, gear)
			if entry == null:
				var none: Array[Entry] = []
				return none
			if not places.is_empty():
				entry.sim.reset(Vector3(places[i].x, 0.0, places[i].y), deg_to_rad(places[i].z))
				entry.controller.reset_controls(entry.controls)
			entry.skipper.sailing_area = area
			entry.skipper.random_seed = random_seed + i
			entry.skipper.level_spread = level_spread
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


## The other sails' wind shadows on every board's wind (F3): one WindShadows per board, its own
## copy of the fleet's places each tick (cast_shadows()).
static func give_shadows(entries: Array[Entry]) -> void:
	for entry: Entry in entries:
		entry.shadows = WindShadows.make()
		entry.sim.wind.disturbance = entry.shadows


## Each scripted skipper's sheet for this race, one line each (a persona's is drawn for the race's
## seed and wind): its hands (reaction and noise), its push offset, its beat and run angles as
## differences from the polar's best, and its layline margin.
static func print_sheets(entries: Array[Entry]) -> void:
	for entry: Entry in entries:
		var scripted: Skipper = entry.skipper as Skipper
		if scripted == null:
			continue
		var c: SkipperConfig = scripted.config
		print("sheet %-12s hands %.2f s %.1f deg  push %+.2f  beat %+.1f deg  run %+.0f deg  layline %.0f m" % [entry.name,
			c.reaction_time_s, c.steering_noise_deg, c.push_offset, c.upwind_vmg_twa_deg - Skipper.POLAR_15KT_UPWIND_TWA_DEG + c.pointing_offset_deg,
			c.downwind_vmg_twa_deg - Skipper.POLAR_15KT_DOWNWIND_TWA_DEG, c.layline_margin_m])


## Every scripted skipper's hands as quick and steady as the all-rounder's (--steady_hands=1): the
## rest of its sheet (drawn for the race in its setup()) stays.
static func steady_the_hands(entries: Array[Entry]) -> void:
	for entry: Entry in entries:
		var scripted: Skipper = entry.skipper as Skipper
		if scripted != null:
			scripted.config.reaction_time_s = STEADY_REACTION_S
			scripted.config.steering_noise_deg = STEADY_NOISE_DEG


## The scripted skippers' push and polar from the options (--skipper_push, --polar): false if the
## polar file cannot be loaded.
static func tune_skippers(entries: Array[Entry], skipper_push: bool, polar_path: String) -> bool:
	var polar: SkipperPolar = null
	if polar_path != "":
		var path: String = polar_path
		if not (path.begins_with("res://") or path.is_absolute_path()):
			path = _repository_path(path)
		polar = load(path) as SkipperPolar if ResourceLoader.exists(path) else null
		if polar == null:
			push_error("No skipper polar at %s." % path)
			return false
	for entry: Entry in entries:
		var scripted: Skipper = entry.skipper as Skipper
		if scripted == null:
			continue
		scripted.push_wanted = skipper_push
		if polar != null:
			scripted.take_polar(polar)
	return true


## The racing rules' judge for the race, given to every scripted skipper (it keeps clear by the
## rules and turns a circle for a penalty).
static func give_rules(entries: Array[Entry], race: RaceSim, course: Course) -> RaceRules:
	var rules: RaceRules = RaceRules.new(race.board_count(), course.axis_deg)
	for entry: Entry in entries:
		if entry.skipper != null:
			entry.skipper.rules = rules
	return rules


## The judge told where everyone is after the tick, and every board's time penalty as it stands
## handed to the race.
static func judge(rules: RaceRules, race: RaceSim, entries: Array[Entry]) -> void:
	var marks: PackedVector2Array = PackedVector2Array()
	for i: int in entries.size():
		var t: Telemetry = entries[i].sim.telemetry
		rules.set_board(i, Vector2(t.position.x, t.position.z), t.heading_deg, 1.0 if t.twa_deg >= 0.0 else -1.0, t.speed_ms,
			t.sailor_state == WindsurferSim.SailorState.SAILING)
		var step: RaceStep = race.next_step(i)
		marks.append(step.points[0] if step != null and step.kind == RaceStep.Kind.MARK else Vector2.INF)
	rules.step(DT, marks, race.clock_s() >= 0.0)
	for i: int in entries.size():
		race.set_time_penalty_s(i, rules.time_penalty_s(i))


## Every board's place and whether its sail is up, into every board's shadows, before the physics.
static func cast_shadows(entries: Array[Entry]) -> void:
	var xs: PackedFloat32Array = PackedFloat32Array()
	var zs: PackedFloat32Array = PackedFloat32Array()
	var casts: PackedByteArray = PackedByteArray()
	for entry: Entry in entries:
		var position: Vector3 = entry.sim.telemetry.position
		xs.append(position.x)
		zs.append(position.z)
		casts.append(1 if entry.sim.sailor_state == WindsurferSim.SailorState.SAILING else 0)
	for i: int in entries.size():
		if entries[i].shadows != null:
			entries[i].shadows.set_fleet(xs, zs, casts, i)


## One tick of the race: every board (its sailor, the physics, the falls and the manoeuvres
## counted), the race told where each one is, and the race clock moved on. With `blind` the
## skippers are not told where the others are (the learned brains were trained alone).
static func step_race(race: RaceSim, entries: Array[Entry], blind: bool = false, rules: RaceRules = null) -> void:
	if entries.size() > 1 and entries[0].shadows != null:
		cast_shadows(entries)
	for i: int in entries.size():
		if entries[i].skipper != null and entries.size() > 1 and not blind:
			_tell_others(entries, i)
		if race.clock_s() >= entries[i].set_off_s and not entries[i].aground:
			_sail(entries[i], not race.is_finished(i))
		race.update_board(i, _where(entries[i]))
	race.step(DT)
	if rules != null:
		judge(rules, race, entries)


## The course to race: the test loop, T1, or a course file.
static func course_named(name: String) -> Course:
	if name == "test":
		return _test_course(EnvironmentConfig.new().wind_or_default().from_bearing_deg)
	# The built-in courses and the team's saved ones, by name (RaceCourses); anything else is a path.
	if name == "t1_loop":
		return RaceCourses.t1_loop(EnvironmentConfig.new().wind_or_default().from_bearing_deg, Vector2.ZERO)
	if name.begins_with("template:"):
		return RaceCourses.template_named(name, EnvironmentConfig.new().wind_or_default().from_bearing_deg, Vector2.ZERO)
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
	if _lake != null:
		return _make_lake_sim()
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


## A board on Lake Silvaplana (--map=lake), as the AI's training builds one there (RaceEnv with the
## lake's environment): its own copies of every config, the map's wind at the hour, and the menu's
## default sea with the lake's own waves on (TrainingDrops.lake_sea()).
static func _make_lake_sim() -> WindsurferSim:
	var sim: WindsurferSim = WindsurferSim.create_for(_lake, true, true)
	var map_field: MapWindField = sim.wind as MapWindField
	if map_field != null:
		map_field.set_time_of_day(_lake_time_s)
	sim.wave_set_config = TrainingDrops.lake_sea()
	sim.set_waves(true)
	return sim


## The --pilot. and --controller. settings on a skipper's controller.
static func _apply_controller_overrides(controller: PlayerController) -> void:
	if not _overrides_read:
		# Also when the harness is used by a test (test_living_skipper_fleet.gd uses make_entries()):
		# the environment variable WSIM_CONTROLLER ("controller.rail_full_ms=0;pilot.hike_share=1.0"),
		# to try a setting on a validation test (GUT refuses options it does not know).
		_overrides_read = true
		for item: String in OS.get_environment("WSIM_CONTROLLER").split(";", false):
			if (item.begins_with("pilot.") or item.begins_with("controller.")) and item.contains("="):
				var parts: PackedStringArray = item.split("=", true, 1)
				_controller_overrides[parts[0]] = parts[1].to_float()
	for key: String in _controller_overrides:
		var parts: PackedStringArray = key.split(".", true, 1)
		if parts[0] == "pilot":
			if parts[1] in controller.auto_sheet_pilot:
				controller.pilot_overrides[parts[1]] = _controller_overrides[key]
			else:
				push_error("No field '%s' to override." % key)
		elif parts[1] in controller:
			var current: Variant = controller.get(parts[1])
			var value: float = _controller_overrides[key]
			controller.set(parts[1], (value != 0.0) if current is bool else (int(value) if current is int else value))
		else:
			push_error("No field '%s' to override." % key)


## A skipper's board: at the pre-start spot (brought nearer the line for a short countdown), at
## `share` of the way across the line's width, on the pre-start's beam reach, at rest. Its skipper
## drives the beginner controller (auto-sheet on), as the player's board is set up in the game.
## With `gear` a persona sails its own board, sail and fin for the wind (Skippers.gear_for()).
static func _make_skipper_board(skipper_name: String, race: RaceSim, course: Course, wind_kt: float, share: float, behind_m: float = -1.0,
		gear: bool = false) -> Entry:
	var skipper: RaceSkipper = Skippers.make(skipper_name)
	if skipper == null:
		return null
	var entry: Entry = Entry.new()
	entry.name = skipper.skipper_name()
	entry.skipper = skipper
	entry.sim = _make_sim(course.axis_deg, wind_kt)
	var own_gear: GearChoice = Skippers.gear_for(skipper, wind_kt) if gear else null
	if own_gear != null:
		# The same wind and sea on its own gear (copies of the items' numbers); before the
		# controller is given the sail, so that it trims this one.
		entry.sim = own_gear.sim_with(entry.sim)
		print("%s sails %s" % [entry.name, own_gear.names_line()])
	for field: String in _sailor_overrides:
		if field in entry.sim.sailor_config:
			entry.sim.sailor_config.set(field, _sailor_overrides[field])
		else:
			push_error("No field 'sailor.%s' to override." % field)
	entry.controller = PlayerController.new()
	entry.controller.set_sail(entry.sim.sail, entry.sim.sailor_config, entry.sim.air_density_kg_m3)
	_apply_controller_overrides(entry.controller)
	entry.hands = AiHands.new()
	entry.controller.hands = entry.hands
	entry.controls = _fresh_controls()
	var start: RaceStep = race.steps()[0]
	# Where it waits: --behind, or where the game puts the boards on the line (RaceRunner: 1 m per
	# second of countdown, 40 to 100 m; 60 m for the 60 s countdown). It waited 150 m back before
	# (2.5 m per second), which in 12 kt no board could sail to the line in a minute: its best way to
	# windward is 2.3 m/s (fleet_speed/start.md).
	var behind: float = behind_m if behind_m > 0.0 else wait_behind_m(race.prestart_s)
	var along: Vector2 = start.points[0] - start.points[1]
	var at: Vector2 = RaceCourses.pre_start_spot(course) + start.in_dir * (RaceCourses.PRE_START_BEHIND_M - behind) + along * (share - 0.5)
	entry.sim.reset(Vector3(at.x, 0.0, at.y), deg_to_rad(RaceCourses.pre_start_heading_deg(course)))
	entry.controller.reset_controls(entry.controls)
	return entry


## How far behind the start line a skipper's board waits for a countdown of this many seconds, metres:
## as the game puts them (RaceSetup.wait_behind_m() with no --behind).
static func wait_behind_m(prestart_s: float) -> float:
	return clampf(prestart_s * RaceRunner.WAIT_M_PER_S, RaceRunner.NEAREST_M, RaceRunner.FARTHEST_M)


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
## counted until it has finished (after the finish it sails free while the others finish, and that is
## not the race's).
static func _sail(entry: Entry, counting: bool = true) -> void:
	var sailing: bool = entry.sim.sailor_state == WindsurferSim.SailorState.SAILING
	if entry.skipper != null:
		# The skipper keeps watching from the water too (its clock runs, its hands come off).
		entry.skipper.update(entry.sim.telemetry, DT)
		if sailing:
			entry.controller.update(entry.sim.telemetry, entry.controls, DT)
		if counting:
			_count_manoeuvres(entry)
		else:
			entry.last_manoeuvre = entry.controller.manoeuvre
	elif sailing:
		entry.pilot.update(entry.sim.telemetry, entry.controls, DT)
	entry.sim.step(DT, entry.controls)
	if entry.trace_file != null and roundi(entry.sim.time_s / DT) % 3 == 0:
		entry.trace_file.store_line(entry.sim.telemetry.to_csv_row())
	if entry.fall_log != null and counting:
		var fall_line: String = entry.fall_log.watch(entry.sim)
		if fall_line != "":
			var doing: String = entry.skipper.note if entry.skipper != null else "autopilot"
			print(fall_line + "," + doing.replace(",", ";"))
	var fallen: bool = entry.sim.sailor_state == WindsurferSim.SailorState.FALLEN
	if fallen and not entry.was_fallen and counting:
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
