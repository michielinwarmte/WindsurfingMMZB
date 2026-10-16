extends SceneTree
## The physics in the map's wind (MAP_SILVAPLANA_PLAN.md W5): the manoeuvres of run_matrix.gd
## (straight, tacks, gybes, a turn on a run, out of irons, with the beginner controller) sailed
## on Lake Silvaplana, in the lake's environment (thin air, fresh water, the map's wind with its
## gusts, lulls, shifts and lee), at several times of day. One line per case. Use
## tools/lake_matrix.sh.
##
## Arguments after "--":
##   --times=12:00,14:30,17:00   the times of day (the day's cycle makes them different winds)
##   --only=<part of a case name>
##   --wind=map|steady           steady: the lake's mean of that time everywhere, no gusts (to
##                               see what the gusts and the place do); --kt=<at 10 m> and
##                               --from=<degrees> set another steady wind
##   --air=<kg/m3> --water=<kg/m3>  another air or water density (default: the lake's 0.98, 1000)
##   --waves=1                   the default wave set on the water (flat water otherwise)
##   --compare=1                 instead: the thin-air comparison (a straight beam reach on open
##                               water at sea level, in thin air, and on the lake)
##   --out_dir=<dir>             a CSV per case (the columns of tools/simulate.sh)
##
## The cases start where the lake scene starts (off the camping beach, sail_silvaplana.gd) when
## their course leads out over the lake; the port-tack starts and the run would reach the shore
## within seconds there, so they start in the lake's middle. The headings of run_matrix.gd (for a
## wind from 270) are turned to the lake's wind of the moment. A case that runs aground stops.

const DT: float = 1.0 / 60.0
const ENVIRONMENT_PATH: String = "res://maps/silvaplana/environment_silvaplana.tres"
const MAP_CONFIG_PATH: String = "res://maps/silvaplana/map_config.tres"
const GRID_PATH: String = "res://maps/silvaplana/terrain/shore_heights.json"
## The lake scene's start (SilvaplanaSailing.START_LV95: 40 m off the camping beach), and a spot
## in the lake's middle with at least 300 m of water all round (game metres).
const START_LV95: Vector2 = Vector2(2780880.0, 1147510.0)
const MIDDLE: Vector3 = Vector3(349.0, 0.0, -89.0)
## run_matrix.gd's cases are written for a wind from the west.
const MATRIX_WIND_FROM_DEG: float = 270.0
const SETTLED_YAW_DPS: float = 6.0
const WINDOW_START_S: float = 2.0
const WINDOW_LENGTH_S: float = 12.0
## A yaw-rate reversal: the turn rate swings from above this on one side to above it on the other.
const REVERSAL_YAW_DPS: float = 5.0
## The wind at the sail is recorded from this time on (the start-up is left out).
const RECORD_FROM_S: float = 3.0

var _environment: EnvironmentConfig
var _grid: TerrainGrid
var _start: Vector3
var _steady: bool = false
var _waves: bool = false
var _air: float = -1.0
var _water: float = -1.0
var _steady_kt: float = -1.0
var _steady_from_deg: float = -1.0


## One run, as in run_matrix.gd: the start heading (for a wind from 270), which key is held
## when, when Space is pressed, how long, and where it starts ("start" or "middle").
class Case:
	var name: String
	var kind: String
	var heading_deg: float
	var press: String
	var press_from_s: float
	var press_until_s: float
	var space_at_s: float
	var seconds: float
	var spot: String
	var time_of_day_s: float = 0.0

	func _init(case_name: String, case_kind: String, heading: float, action: String, from_s: float, until_s: float, space_s: float, length_s: float, start_spot: String) -> void:
		name = case_name
		kind = case_kind
		heading_deg = heading
		press = action
		press_from_s = from_s
		press_until_s = until_s
		space_at_s = space_s
		seconds = length_s
		spot = start_spot

	func at(time_s: float) -> Case:
		var copy: Case = Case.new(name, kind, heading_deg, press, press_from_s, press_until_s, space_at_s, seconds, spot)
		copy.time_of_day_s = time_s
		return copy


class Result:
	var fell_s: float = -1.0
	var fall_kind: String = ""
	var nan: bool = false
	var aground_s: float = -1.0
	var done_s: float = -1.0
	var top_speed_kt: float = 0.0
	var window_count: int = 0
	var window_speed_kt: float = 0.0
	var window_max_yaw_dps: float = 0.0
	var yaw_reversals: int = 0
	var sail_wind_min_kt: float = INF
	var sail_wind_max_kt: float = 0.0
	var sail_wind_sum_kt: float = 0.0
	var sail_wind_count: int = 0
	var lake_10m_kt: float = 0.0
	var lake_from_deg: float = 0.0
	var end_twa_deg: float = 0.0


func _templates() -> Array[Case]:
	return [
		Case.new("straight", "straight", 180.0, "none", 0.0, 0.0, -1.0, 45.0, "start"),
		Case.new("tack_stb", "tack", 180.0, "none", 0.0, 0.0, 25.0, 48.0, "start"),
		Case.new("tack_port", "tack", 0.0, "none", 0.0, 0.0, 25.0, 48.0, "middle"),
		Case.new("tack_held", "tack", 180.0, "steer_right", 25.0, 40.0, -1.0, 45.0, "start"),
		Case.new("gybe_broad", "gybe", 180.0, "steer_left", 25.0, 27.0, 30.0, 45.0, "start"),
		Case.new("gybe_beam", "gybe", 180.0, "steer_left", 25.0, 25.6, 27.0, 42.0, "start"),
		Case.new("run_left", "turn", 90.0, "steer_left", 25.0, 29.0, -1.0, 40.0, "middle"),
		Case.new("irons", "irons", 270.0, "steer_right", 1.0, 21.0, -1.0, 22.0, "start"),
	]


func _initialize() -> void:
	var options: Dictionary[String, String] = _read_user_args()
	_environment = load(ENVIRONMENT_PATH)
	_grid = TerrainGrid.load_from(GRID_PATH)
	var map_config: MapConfig = load(MAP_CONFIG_PATH)
	_start = map_config.lv95_to_game(START_LV95.x, START_LV95.y, map_config.lake_level_m)
	_start.y = 0.0
	_steady = options.get("wind", "map") == "steady"
	_waves = options.get("waves", "0") == "1"
	_air = options.get("air", "-1").to_float()
	_water = options.get("water", "-1").to_float()
	_steady_kt = options.get("kt", "-1").to_float()
	_steady_from_deg = options.get("from", "-1").to_float()
	if options.get("compare", "0") == "1":
		_compare_thin_air()
		quit(0)
		return
	var times: Array[float] = []
	for text: String in options.get("times", "12:00,14:30,17:00").split(","):
		times.append(_seconds_of(text))
	var only: String = options.get("only", "")
	var out_dir: String = options.get("out_dir", "")
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)

	print("Lake Silvaplana, %s wind, air %.3f kg/m3, water %.0f kg/m3%s" % [
		"steady" if _steady else "the map's", _air_density(), _water_config().density_kg_m3, ", waves" if _waves else ", flat water"])
	print("%-10s %5s %-6s | %5s %4s | %-15s | %5s %5s | %5s %5s %5s | %3s %5s | %5s" % [
		"case", "time", "spot", "10m", "from", "fall", "done", "top", "sail", "min", "max", "rev", "yaw", "mean"])
	var falls: int = 0
	var unfinished: int = 0
	var problems: int = 0
	for time_s: float in times:
		for template: Case in _templates():
			if only != "" and not template.name.contains(only):
				continue
			var c: Case = template.at(time_s)
			var r: Result = _run_case(c, out_dir)
			if r.fell_s >= 0.0:
				falls += 1
			if c.kind != "straight" and r.done_s < 0.0:
				unfinished += 1
			if r.nan or r.aground_s >= 0.0:
				problems += 1
			print(_format(c, r))
	print("%d with a fall, %d manoeuvres not completed, %d with NaN or aground" % [falls, unfinished, problems])
	quit(0)


## The simulation for a case: the lake's environment at the case's time of day (or the steady
## lake mean of that time), the controller, the start.
func _make_sim(time_of_day_s: float) -> WindsurferSim:
	var environment: EnvironmentConfig = _environment.duplicate() as EnvironmentConfig
	environment.air_density_kg_m3 = _air_density()
	environment.water = _water_config()
	environment.start_hour = time_of_day_s / 3600.0
	var sim: WindsurferSim = WindsurferSim.create_for(environment)
	var field: MapWindField = sim.wind as MapWindField
	field.set_time_of_day(time_of_day_s)
	if _steady:
		sim.wind_config = _steady_wind(field)
		sim.wind = WindField.new(sim.wind_config)
	sim.set_waves(_waves)
	return sim


## The lake's mean wind of the moment as one steady wind (at 10 m, from the lake's direction).
func _steady_wind(field: MapWindField) -> WindConfig:
	var config: WindConfig = field.config.duplicate() as WindConfig
	config.speed_kt = field.speed_at_height(config.reference_height_m) / SimMath.KNOT_MS
	config.from_bearing_deg = rad_to_deg(field.current_from_bearing_rad)
	if _steady_kt > 0.0:
		config.speed_kt = _steady_kt
	if _steady_from_deg >= 0.0:
		config.from_bearing_deg = _steady_from_deg
	config.gusts_enabled = false
	config.shifts_enabled = false
	return config


func _air_density() -> float:
	return _air if _air > 0.0 else _environment.air_density_kg_m3


func _water_config() -> WaterConfig:
	var water: WaterConfig = _environment.water_or_default()
	if _water <= 0.0:
		return water
	var changed: WaterConfig = water.duplicate() as WaterConfig
	changed.density_kg_m3 = _water
	return changed


func _run_case(c: Case, out_dir: String) -> Result:
	for action: String in ["steer_left", "steer_right", "tack", "sheet_in", "sheet_out", "rake_back", "rake_forward"]:
		Input.action_release(action)
	var sim: WindsurferSim = _make_sim(c.time_of_day_s)
	var controller: PlayerController = PlayerController.new()
	controller.set_sail(sim.sail, sim.sailor_config, sim.air_density_kg_m3)
	var controls: SimControls = SimControls.new()
	# The start heading is turned to the lake's mean wind of the moment (also with a steady wind
	# from elsewhere, --from: then the board starts on the same course in another wind).
	var lake_mean_from_deg: float = _environment.map_wind().lake_from_deg(c.time_of_day_s)
	var heading_deg: float = fposmod(c.heading_deg + lake_mean_from_deg - MATRIX_WIND_FROM_DEG, 360.0)
	var lake_from_deg: float = rad_to_deg(sim.wind.current_from_bearing_rad)
	sim.reset(_start if c.spot == "start" else MIDDLE, deg_to_rad(heading_deg))

	var file: FileAccess = null
	if out_dir != "":
		file = FileAccess.open("%s/%s_%s.csv" % [out_dir, c.name, _clock_text(c.time_of_day_s).replace(":", "")], FileAccess.WRITE)
		if file != null:
			file.store_line(Telemetry.csv_header())

	var r: Result = Result.new()
	r.lake_10m_kt = sim.wind.speed_at_height(10.0) / SimMath.KNOT_MS
	r.lake_from_deg = lake_from_deg
	var start_s: float = c.space_at_s if c.space_at_s >= 0.0 else c.press_from_s
	var tack_before: float = 0.0
	var heading_at_start: float = 0.0
	var space_done: bool = false
	var window_from: float = c.seconds - 15.0 if c.kind == "straight" else INF
	var last_yaw_side: int = 0
	for i: int in int(c.seconds / DT):
		var now: float = sim.time_s
		if c.press != "none":
			if now >= c.press_from_s and now < c.press_until_s:
				Input.action_press(c.press)
			else:
				Input.action_release(c.press)
		if c.space_at_s >= 0.0 and now >= c.space_at_s and not space_done:
			Input.action_press("tack")
			space_done = true
		elif space_done:
			Input.action_release("tack")
		controller.update(sim.telemetry, controls, DT)
		sim.step(DT, controls)
		var t: Telemetry = sim.telemetry
		if file != null and i % 2 == 0:
			file.store_line(t.to_csv_row())
		if is_nan(t.speed_ms) or is_nan(t.heel_deg) or is_nan(t.position.y):
			r.nan = true
			break
		if ShoreCheck.is_aground(_grid, t.position, sim.fin_config.span_m):
			r.aground_s = t.time_s
			break
		if sim.sailor_state == WindsurferSim.SailorState.FALLEN and r.fell_s < 0.0:
			r.fell_s = t.time_s
			r.fall_kind = sim.fall_kind
		r.top_speed_kt = maxf(r.top_speed_kt, t.speed_kt)
		if t.time_s >= RECORD_FROM_S and sim.sailor_state == WindsurferSim.SailorState.SAILING:
			r.sail_wind_min_kt = minf(r.sail_wind_min_kt, t.tws_at_sail_kt)
			r.sail_wind_max_kt = maxf(r.sail_wind_max_kt, t.tws_at_sail_kt)
			r.sail_wind_sum_kt += t.tws_at_sail_kt
			r.sail_wind_count += 1
		if t.time_s < start_s:
			continue
		if tack_before == 0.0:
			tack_before = 1.0 if t.twa_deg >= 0.0 else -1.0
			heading_at_start = t.heading_deg
		_check_done(c, r, t, tack_before, heading_at_start)
		if r.done_s >= 0.0 and window_from == INF:
			window_from = r.done_s + WINDOW_START_S
		if t.time_s >= window_from and t.time_s <= window_from + WINDOW_LENGTH_S and sim.sailor_state == WindsurferSim.SailorState.SAILING:
			_record_window(r, t, last_yaw_side)
			last_yaw_side = _yaw_side(t, last_yaw_side)
	if file != null:
		file.close()
	if r.window_count > 0:
		r.window_speed_kt /= float(r.window_count)
	r.end_twa_deg = sim.telemetry.twa_deg
	return r


## The milestones of run_matrix.gd: through the wind and onto the new tack, or turned 60 degrees,
## or out of irons and moving.
func _check_done(c: Case, r: Result, t: Telemetry, tack_before: float, heading_at_start: float) -> void:
	if r.done_s >= 0.0:
		return
	var on_new_tack: bool = signf(t.twa_deg) == -tack_before
	var twa: float = absf(t.twa_deg)
	match c.kind:
		"tack":
			if on_new_tack and twa > 50.0:
				r.done_s = t.time_s
		"gybe":
			if on_new_tack and twa < 120.0:
				r.done_s = t.time_s
		"turn":
			if absf(wrapf(t.heading_deg - heading_at_start, -180.0, 180.0)) > 60.0:
				r.done_s = t.time_s
		"irons":
			if twa > 45.0 and t.speed_ms > 1.5:
				r.done_s = t.time_s


## The calm sailing after a manoeuvre (or the last 15 s of a straight run): the mean speed, the
## largest turn rate, and the yaw-rate reversals (the board wagging from side to side).
func _record_window(r: Result, t: Telemetry, last_yaw_side: int) -> void:
	r.window_count += 1
	r.window_speed_kt += t.speed_kt
	r.window_max_yaw_dps = maxf(r.window_max_yaw_dps, absf(t.yaw_rate_dps))
	var side: int = _yaw_side(t, last_yaw_side)
	if last_yaw_side != 0 and side != last_yaw_side:
		r.yaw_reversals += 1


## Which way the board turns (+1, -1), holding the last side inside the dead band.
func _yaw_side(t: Telemetry, last_side: int) -> int:
	if t.yaw_rate_dps > REVERSAL_YAW_DPS:
		return 1
	if t.yaw_rate_dps < -REVERSAL_YAW_DPS:
		return -1
	return last_side


func _format(c: Case, r: Result) -> String:
	var fall: String = "-"
	if r.fell_s >= 0.0:
		fall = "%.1f %s" % [r.fell_s, r.fall_kind]
	if r.nan:
		fall += " NaN"
	if r.aground_s >= 0.0:
		fall += " AGROUND %.0f" % r.aground_s
	var mean_sail: float = r.sail_wind_sum_kt / maxf(r.sail_wind_count, 1)
	var window: String = "%3s %5s %5s" % ["-", "-", "-"]
	if r.window_count > 0:
		window = "%3d %5.1f %5.1f" % [r.yaw_reversals, r.window_max_yaw_dps, r.window_speed_kt]
	return "%-10s %5s %-6s | %5.1f %4.0f | %-15s | %5s %5.1f | %5.1f %5.1f %5.1f | %s" % [
		c.name, _clock_text(c.time_of_day_s), c.spot, r.lake_10m_kt, r.lake_from_deg, fall,
		"-" if r.done_s < 0.0 else "%.1f" % r.done_s, r.top_speed_kt,
		mean_sail, r.sail_wind_min_kt if r.sail_wind_count > 0 else 0.0, r.sail_wind_max_kt, window]


## The thin-air comparison: a straight beam reach (the controller's own sheeting), the mean speed
## over the last 30 of 60 seconds. In the same steady wind (10 to 14 kt and the lake's mean at 14:30,
## 18.2 kt at 10 m): sea-level air and sea water, thin air only, thin air and fresh water (the
## lake's environment). Then the lake itself at 14:30 (the map's wind, from the start).
func _compare_thin_air() -> void:
	var field: MapWindField = _make_sim(14.5 * 3600.0).wind as MapWindField
	var lake_mean: WindConfig = _steady_wind(field)
	var sea_water: WaterConfig = load(EnvironmentConfig.DEFAULT_WATER_PATH)
	print("A straight beam reach, the means over seconds 30 to 60 (wind from %.0f)" % lake_mean.from_bearing_deg)
	print("%-50s | %6s %6s %6s %6s" % ["", "speed", "sail", "drive", "heel"])
	for speed_kt: float in [10.0, 11.0, 12.0, 14.0, lake_mean.speed_kt]:
		var steady: WindConfig = lake_mean.duplicate() as WindConfig
		steady.speed_kt = speed_kt
		var reference_kt: float = 0.0
		for row: Array in [["%.1f kt, open water: 1.225 kg/m3, sea water" % speed_kt, 1.225, sea_water],
				["%.1f kt, thin air: 0.98 kg/m3, sea water" % speed_kt, 0.98, sea_water],
				["%.1f kt, the lake: 0.98 kg/m3, fresh water" % speed_kt, 0.98, _environment.water_or_default()]]:
			var environment: EnvironmentConfig = EnvironmentConfig.new()
			environment.air_density_kg_m3 = row[1]
			environment.water = row[2]
			environment.wind = steady
			var means: PackedFloat64Array = _straight_means(WindsurferSim.create_for(environment), Vector3.ZERO, steady.from_bearing_deg - 90.0)
			if reference_kt == 0.0:
				reference_kt = means[0]
			print("%-50s | %6.2f %6.1f %6.0f %6.1f   (%+.1f %%)" % [row[0], means[0], means[1], means[2], means[3], 100.0 * (means[0] / reference_kt - 1.0)])
	var on_the_lake: PackedFloat64Array = _straight_means(_make_sim(14.5 * 3600.0), _start, lake_mean.from_bearing_deg - 90.0)
	print("%-50s | %6.2f %6.1f %6.0f %6.1f" % ["the lake at 14:30: the map's wind, from the start", on_the_lake[0], on_the_lake[1], on_the_lake[2], on_the_lake[3]])


## Sails straight for 60 s with the beginner controller; returns the means over the last 30 s:
## speed (kt), the wind at the sail (kt), the sail's drive (N) and the heel (degrees).
func _straight_means(sim: WindsurferSim, start: Vector3, heading_deg: float) -> PackedFloat64Array:
	for action: String in ["steer_left", "steer_right", "tack"]:
		Input.action_release(action)
	var controller: PlayerController = PlayerController.new()
	controller.set_sail(sim.sail, sim.sailor_config, sim.air_density_kg_m3)
	var controls: SimControls = SimControls.new()
	sim.reset(start, deg_to_rad(heading_deg))
	var sums: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
	var count: int = 0
	for i: int in int(60.0 / DT):
		controller.update(sim.telemetry, controls, DT)
		sim.step(DT, controls)
		var t: Telemetry = sim.telemetry
		if t.time_s >= 30.0:
			sums[0] += t.speed_kt
			sums[1] += t.tws_at_sail_kt
			sums[2] += t.drive_n
			sums[3] += absf(t.heel_deg)
			count += 1
	for k: int in sums.size():
		sums[k] /= float(maxi(count, 1))
	return sums


func _seconds_of(text: String) -> float:
	var parts: PackedStringArray = text.split(":")
	return parts[0].to_float() * 3600.0 + (parts[1].to_float() * 60.0 if parts.size() > 1 else 0.0)


func _clock_text(seconds: float) -> String:
	return "%02d:%02d" % [floori(seconds / 3600.0), floori(seconds / 60.0) % 60]


func _read_user_args() -> Dictionary[String, String]:
	var options: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
			options[parts[0]] = parts[1]
	return options
