extends SceneTree
## Fits the race courses to Lake Silvaplana (RACING_PLAN.md, T2 "Placed to fit the water";
## CourseFitter) and saves the sprint slalom as the team's course t2_slalom.json, so the game loads
## it instead of fitting at startup. Use tools/fit_courses.sh.
##
## - T2, the sprint slalom (template PD3), for 4 boards, square to the lake's mean wind of the
##   sailing's start time (14:30, environment_silvaplana.tres) and sized for its strength, as near
##   to the lake scene's start (off the camping beach) as it fits. Saved with Course.save, in LV95,
##   as the course maker saves.
## - As a check of the fitter, the windward-leeward course (LG2) the same way, not saved (the map
##   plan says a full one fits along the lake).
## For each: the size it ended at, its axis against the wind, the smallest clearance of the marks
## and of the legs, every leg's length and compass course, and how long the fit took.
##
## Arguments after "--":
##   --time=<hh:mm>   another time of day for the wind (the course then has that wind's axis)
##   --save=0         don't write t2_slalom.json (to try something out)
##   --mark_margin=<m> --leg_margin=<m> --min_size=<percent>   another rule than CourseFitter's
##                    (200 m, 50 m, 40 %), to see what it would give; then also add --save=0

const ENVIRONMENT_PATH: String = "res://maps/silvaplana/environment_silvaplana.tres"
const MAP_CONFIG_PATH: String = "res://maps/silvaplana/map_config.tres"
const GRID_PATH: String = "res://maps/silvaplana/terrain/shore_heights.json"
const RULES_PATH: String = "res://maps/course/iqfoil_courses.tres"
const T2_PATH: String = "res://maps/silvaplana/courses/t2_slalom.json"
const T2_NAME: String = "T2 sprint slalom"
## The lake scene's start (SilvaplanaSailing.START_LV95: 40 m off the camping beach), LV95 metres.
const START_LV95: Vector2 = Vector2(2780880.0, 1147510.0)
const BOARDS: int = 4


func _initialize() -> void:
	var options: Dictionary[String, String] = _read_user_args()
	var environment: EnvironmentConfig = load(ENVIRONMENT_PATH)
	var config: MapConfig = load(MAP_CONFIG_PATH)
	var grid: TerrainGrid = TerrainGrid.load_from(GRID_PATH)
	var rules: CourseRules = load(RULES_PATH)
	var wind: MapWind = environment.map_wind()
	if grid == null or wind == null:
		print("Could not load the lake's heights or its wind.")
		quit(1)
		return
	var time_s: float = environment.start_time_of_day_s()
	if options.has("time"):
		var parts: PackedStringArray = options["time"].split(":")
		time_s = parts[0].to_float() * 3600.0 + (parts[1].to_float() * 60.0 if parts.size() > 1 else 0.0)
	# The lake's mean wind of the moment, without the moving shifts, as the course maker's "Square
	# to wind": a race committee sets its course to the average wind, in whole degrees.
	var from_deg: float = fposmod(wind.lake_from_deg(time_s), 360.0)
	var axis_deg: float = roundf(from_deg)
	var wind_kt: float = wind.day.lake_speed_ms(time_s) / SimMath.KNOT_MS
	var start: Vector3 = config.lv95_to_game(START_LV95.x, START_LV95.y, config.lake_level_m)
	var preferred: Vector2 = Vector2(start.x, start.z)

	var fitter: CourseFitter = CourseFitter.from_heights(grid.height_at, preferred)
	fitter.mark_margin_m = options.get("mark_margin", str(fitter.mark_margin_m)).to_float()
	fitter.leg_margin_m = options.get("leg_margin", str(fitter.leg_margin_m)).to_float()
	fitter.min_size_percent = options.get("min_size", str(fitter.min_size_percent)).to_float()
	print("Lake Silvaplana at %s: the lake's wind %.1f kt from %.1f°, so the courses' axis is %03.0f°" % [
		_clock_text(time_s), wind_kt, from_deg, axis_deg])
	print("Shore clearance: %d x %d points %.0f m apart, built in %.0f ms; the most open water is %.0f m from the shore" % [
		fitter.columns, fitter.rows, CourseFitter.STEP_M, fitter.build_ms, fitter.most_open_m()])
	print("The rule: every mark %.0f m and every leg %.0f m from the shore, %.0f %% of the class's size at least, at most %.0f° off the wind" % [
		fitter.mark_margin_m, fitter.leg_margin_m, fitter.min_size_percent, fitter.axis_tolerance_deg])

	var failed: bool = false
	var t2: Course = fitter.fit_template("PD3", rules, wind_kt, axis_deg, preferred, BOARDS)
	print("")
	if t2 == null:
		print("T2, the sprint slalom (PD3): %s" % fitter.last_reason)
		failed = true
	else:
		t2.name = T2_NAME
		_print_course(t2, fitter, grid, axis_deg)
		if options.get("save", "1") != "0":
			var error: Error = t2.save(T2_PATH, config)
			print("  saved as %s%s" % [T2_PATH, "" if error == OK else ": FAILED, " + error_string(error)])
			failed = failed or error != OK

	var lg2: Course = fitter.fit_template("LG2", rules, wind_kt, axis_deg, preferred, BOARDS)
	print("")
	if lg2 == null:
		print("The check, a windward-leeward course (LG2): %s" % fitter.last_reason)
		failed = true
	else:
		print("The check, not saved:")
		_print_course(lg2, fitter, grid, axis_deg)
	quit(1 if failed else 0)


## The fitted course in a few lines (the last fit's tries and time are the fitter's).
func _print_course(course: Course, fitter: CourseFitter, grid: TerrainGrid, axis_deg: float) -> void:
	var off_deg: float = Course.turn_deg(axis_deg, course.axis_deg)
	var off_text: String = "square to the wind" if absf(off_deg) < 0.5 else "%.0f° %s of the wind" % [absf(off_deg), "right" if off_deg > 0.0 else "left"]
	print("%s (%s, %d boards): %.0f %% of the class's size, axis %03.0f° (%s); %d tries in %.0f ms" % [
		course.name, course.template, course.boards, course.size_percent, course.axis_deg, off_text, fitter.last_tries,
		fitter.last_fit_ms])
	var warnings: PackedStringArray = course.problems(grid.height_at)
	print("  smallest clearance: the marks %.0f m, the legs %.0f m; the course maker's land warnings: %s" % [
		fitter.smallest_mark_clearance_m(course), fitter.smallest_leg_clearance_m(course),
		"none" if warnings.is_empty() else "; ".join(warnings)])
	var total_m: float = 0.0
	for leg: Course.Leg in course.legs():
		total_m += leg.length_m()
		var to_wind: float = absf(Course.turn_deg(axis_deg, leg.bearing_deg()))
		print("  %-14s %5.0f m  %03.0f°  (%3.0f° from the wind)" % ["%s → %s" % [leg.from_name, leg.to_name], leg.length_m(),
			leg.bearing_deg(), to_wind])
	print("  %.2f km in all" % (total_m / 1000.0))


func _clock_text(seconds: float) -> String:
	return "%02d:%02d" % [floori(seconds / 3600.0), floori(seconds / 60.0) % 60]


func _read_user_args() -> Dictionary[String, String]:
	var options: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
			options[parts[0]] = parts[1]
	return options
