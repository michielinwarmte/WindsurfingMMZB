extends SceneTree
## A headless race (RACING_PLAN.md, Part 9A): boards on a course, the countdown, the gun, the race's
## own clock and checks (RaceSim), and one line per board at the end. In 9A every board is the plain
## Autopilot holding one wind angle, so it starts and then sails on at that angle and does not
## finish: this is the plumbing that the scripted skippers of 9B make meaningful. Use tools/race.sh.
##
## Arguments after "--":
##   --course=test         a small loop made by code (the default): a start line 60 m long, mark 1
##                         300 m upwind (port), the gate 4S/4P 100 m above the line, and the finish
##                         line 150 m to the left of the gate
##   --course=t1_loop      the T1 training loop on open water (RaceCourses), the start line at the origin
##   --course=<name>       a course saved by the course maker, by name (t2_slalom, ...)
##   --course=<file.json>  a course saved by the course maker (a res:// path, a full path, or a path
##                         from the repository's folder), placed with the Silvaplana map's frame
##   [--boards=1] [--laps=1] [--wind_kt=15] [--seconds=300: race time after the gun]
##   [--prestart=10: the countdown, seconds] [--twa=50: the wind angle the autopilot holds]
##   [--out_dir=<folder>: a CSV per board: race time, x, z, heading, speed and its next step]
##
## Every board is the open water's default simulation with its waves, stepped at 1/60 s. The wind
## blows from the course's axis, so the course is square to it. The boards wait behind the line
## until SET_OFF_S before the gun, spread across it, then set off for it. After every tick the race
## is told where the boards are.

const DT: float = 1.0 / 60.0
const MAP_CONFIG_PATH: String = "res://maps/silvaplana/map_config.tres"
## How far back along its approach a board is put for each second of the countdown, metres: about
## what a board starting from rest sails in that time in 15 kt (it averaged 4.8 m/s over its first
## 10 s), so that it reaches the line near the gun. More wind gets it there earlier, less later.
const APPROACH_M_PER_S: float = 4.5
## The boards are put back as if the countdown were this much longer, seconds: a fixed-angle pilot
## cannot go back behind the line, so a little late is better than over early.
const START_MARGIN_S: float = 3.0
## The boards set off this long before the gun, seconds; until then they wait where they were put
## (their simulations are not stepped). A fixed-angle pilot sailing a long countdown would drift far
## from the spot it was aimed at. The skippers of 9B sail the pre-start themselves.
const SET_OFF_S: float = 10.0
## A CSV row every this many ticks (0.1 s).
const CSV_EVERY: int = 6


## One board in the race: its simulation, its sailor, and what is counted about it.
class Entry:
	var name: String = ""
	var sim: WindsurferSim
	var pilot: Autopilot
	var controls: SimControls
	var falls: int = 0
	var was_fallen: bool = false
	var file: FileAccess = null


func _initialize() -> void:
	var options: Dictionary[String, String] = _read_user_args()
	var boards: int = maxi(options.get("boards", "1").to_int(), 1)
	var laps: int = maxi(options.get("laps", "1").to_int(), 1)
	var wind_kt: float = options.get("wind_kt", "15").to_float()
	var seconds: float = options.get("seconds", "300").to_float()
	var prestart_s: float = maxf(options.get("prestart", "10").to_float(), 0.0)
	var twa_deg: float = options.get("twa", "50").to_float()
	var out_dir: String = options.get("out_dir", _repository_path(".sim_output/race"))

	var course: Course = _course(options.get("course", "test"))
	if course == null:
		quit(2)
		return
	var race: RaceSim = RaceSim.new(course, laps, prestart_s)
	if race.steps().is_empty():
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out_dir)

	var entries: Array[Entry] = []
	for i: int in boards:
		var entry: Entry = _make_board("board%d" % (i + 1), race, course.axis_deg, wind_kt, twa_deg, float(i + 1) / (boards + 1))
		entry.file = FileAccess.open(out_dir.path_join(entry.name + ".csv"), FileAccess.WRITE)
		if entry.file != null:
			entry.file.store_line("race_time_s,x_m,z_m,heading_deg,speed_ms,next_step")
		race.add_board(entry.name)
		race.update_board(i, _where(entry))
		entries.append(entry)
	race.start()

	var ticks: int = roundi((prestart_s + seconds) / DT)
	for tick: int in ticks:
		var set_off: bool = race.clock_s() >= -SET_OFF_S
		for i: int in entries.size():
			if set_off:
				_sail(entries[i])
			race.update_board(i, _where(entries[i]))
		race.step(DT)
		if tick % CSV_EVERY == 0:
			for i: int in entries.size():
				_write_row(entries[i], race, i)
		if race.phase() == RaceSim.Phase.FINISHED:
			break
	for entry: Entry in entries:
		if entry.file != null:
			entry.file.close()

	print("Race on %s (%s, %d lap%s, %d steps): wind %.0f kt from %.0f deg, %d board%s at TWA %.0f, pre-start %.0f s" % [
		course.name, course.sequence, laps, "" if laps == 1 else "s", race.steps().size(), wind_kt, course.axis_deg,
		boards, "" if boards == 1 else "s", twa_deg, prestart_s])
	for result: RaceResult in race.results():
		print("%s  falls %d" % [result.to_line(), entries[result.index].falls])
	print("%s at race time %s; CSV files in %s" % [
		"Finished" if race.phase() == RaceSim.Phase.FINISHED else "Stopped", RaceResult.format_time(race.race_time_s()), out_dir])
	quit(0)


# ---------------------------------------------------------------- the course

## The course to race: the test loop, or a course file.
func _course(name: String) -> Course:
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


## The small loop of --course=test, set for a wind direction (where it comes from), with the middle of
## its start line at the origin. Drawn in the frame of the course diagrams, as CourseTemplates does:
## up toward the wind, right to the right looking upwind.
func _test_course(axis_deg: float) -> Course:
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

## A board behind the start line at `share` of the way along it (from the pin to the boat), on the
## tack that points nearer the first leg, far enough back to reach the line at about the gun.
func _make_board(board_name: String, race: RaceSim, wind_from_deg: float, wind_kt: float, twa_deg: float, share: float) -> Entry:
	var entry: Entry = Entry.new()
	entry.name = board_name
	entry.sim = WindsurferSim.create_default(true)
	entry.sim.wind_config = entry.sim.wind_config.duplicate()
	entry.sim.wind_config.speed_kt = wind_kt
	entry.sim.wind_config.from_bearing_deg = wind_from_deg
	entry.sim.wind = WindField.new(entry.sim.wind_config)
	entry.sim.set_waves(true)  # again, so the waves run with the new wind
	entry.pilot = Autopilot.new()
	entry.pilot.target_twa_deg = twa_deg
	entry.pilot.sail = entry.sim.sail
	entry.pilot.sailor = entry.sim.sailor_config
	entry.pilot.air_density_kg_m3 = entry.sim.air_density_kg_m3
	entry.controls = _fresh_controls()
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


## One tick of a board: the sailor (while on the board), the physics, and the falls counted.
func _sail(entry: Entry) -> void:
	if entry.sim.sailor_state == WindsurferSim.SailorState.SAILING:
		entry.pilot.update(entry.sim.telemetry, entry.controls, DT)
	entry.sim.step(DT, entry.controls)
	var fallen: bool = entry.sim.sailor_state == WindsurferSim.SailorState.FALLEN
	if fallen and not entry.was_fallen:
		entry.falls += 1
	elif entry.was_fallen and not fallen:
		# Up again after the waterstart (the simulation does it after a while): the sail eased, as at
		# the start.
		entry.controls = _fresh_controls()
	entry.was_fallen = fallen


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


func _write_row(entry: Entry, race: RaceSim, index: int) -> void:
	if entry.file == null:
		return
	var t: Telemetry = entry.sim.telemetry
	entry.file.store_line("%.2f,%.2f,%.2f,%.1f,%.2f,%d" % [race.clock_s(), t.position.x, t.position.z, t.heading_deg, t.speed_ms, race.next_step_index(index)])


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
