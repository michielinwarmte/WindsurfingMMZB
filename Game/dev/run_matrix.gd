extends SceneTree
## Runs a whole matrix of beginner-controller manoeuvres in one Godot process and prints
## one line per case: did the sailor fall, did the numbers blow up, when did the bow go
## through the wind, when was the new course reached, when did the board settle, and how
## calm was the sailing afterwards. One command checks tacks, gybes, turns on a run,
## getting out of irons and straight sailing at several wind strengths. Use tools/matrix.sh.
##
## Arguments after "--": [--only=<substring of the case name>[,<another>...]] [--winds=<kt,kt,...>]
## [--every=<steps between CSV rows>] [--out_dir=<dir for the per-case CSV files>]
## [--waves=1: the default wave set on the water] [--wave_scale=<factor> on its amplitudes]
## [--pilot.<field>=<number>] [--controller.<field>=<number>] [--sailor.<field>=<number>]
## [--sail.<field>=<number>]: try another value of a tuning field without editing code
## (the pilot is the controller's auto-sheet pilot; sailor and sail are the config
## resources, changed for the whole run).
## [--gear_board=<id>] [--gear_sail=<id>] [--gear_fin=<id>]: sail a gear page item instead of the
## default (Game/gear/; a fin of any depth, "nt8_slalom_28"; an id not given keeps the default),
## built as the game builds it (GearChoice.sim_with()). The fin's depth, area and stiffness are
## printed first.
## The player's hands in the manoeuvre (the interactive tacks and gybes, Max, 6 November 2026;
## Documentation/reports/gameplay/gp_manoeuvres_6nov.md), all off by default:
## [--hold_turn=1]: from Space to the manoeuvre's end the turn key toward the turn is held.
## [--body_carve=<-1..1>] [--body_back=<-1..1>]: a mouse body held by script through the manoeuvre,
## +1 carve the toes or heels toward the inside of the turn (-1 the outside: flatten), and the back
## foot (+) or the front foot (-); in the middle before Space and after the manoeuvre.
## [--cue=1] [--cue_delay=<s>]: Space pressed again this long after the "flip now" window opens.
## [--sharp=1]: with --hold_turn, Shift held with the key (the carve into the turn, 7 November 2026).
## [--shift=<s>]: every case's key times and Space this much later (another wave under the turn).
##
## The per-case CSV files have the same columns as tools/simulate.sh, so .scratch/trace.py
## works on them.

const DT: float = 1.0 / 60.0
## A board is "settled" once it has turned slower than this for a full second.
const SETTLED_YAW_DPS: float = 6.0
## The window of calm sailing judged after a manoeuvre: from this long after the new course
## was reached, for this long.
const WINDOW_START_S: float = 2.0
const WINDOW_LENGTH_S: float = 12.0

var _overrides: Dictionary[String, String] = {}
## The player's hands in the manoeuvre (see the top).
var _hold_turn: bool = false
var _body_carve: float = NAN
var _body_back: float = 0.0
var _cue: bool = false
var _cue_delay_s: float = 0.0
var _shift_s: float = 0.0
## Per case: the key held toward the turn ("" none), when the "flip now" window opened (-1 not yet)
## and whether the cue was given.
var _held_action: String = ""
var _sharp: bool = false
var _cue_open_since_s: float = -1.0
var _cue_given: bool = false
var _waves: bool = false
var _wave_scale: float = 1.0
## The gear sailed (--gear_board, --gear_sail, --gear_fin); null: the default.
var _gear: GearChoice = null


## One run: who starts where, which key is held when, and when Space is pressed.
class Case:
	var name: String
	## "tack", "gybe", "turn", "irons" or "straight": decides which milestones are measured.
	var kind: String
	var wind_kt: float
	var heading_deg: float
	var press: String
	var press_from_s: float
	var press_until_s: float
	var space_at_s: float
	var seconds: float

	func _init(case_name: String, case_kind: String, heading: float, action: String, from_s: float, until_s: float, space_s: float, length_s: float) -> void:
		name = case_name
		kind = case_kind
		heading_deg = heading
		press = action
		press_from_s = from_s
		press_until_s = until_s
		space_at_s = space_s
		seconds = length_s

	func with_wind(kt: float) -> Case:
		var copy: Case = Case.new(name, kind, heading_deg, press, press_from_s, press_until_s, space_at_s, seconds)
		copy.wind_kt = kt
		return copy


## What one run produced.
class Result:
	var fell_s: float = -1.0
	var fall_kind: String = ""
	var nan: bool = false
	var crossed_s: float = -1.0
	var done_s: float = -1.0
	var settled_s: float = -1.0
	var manoeuvre_end_s: float = -1.0
	var window_count: int = 0
	var window_speed_ms: float = 0.0
	var window_heading_range_deg: float = 0.0
	var window_max_heel_deg: float = 0.0
	var window_sheet_reversals: int = 0
	var window_lean_sd: float = 0.0
	var window_max_yaw_dps: float = 0.0
	var end_speed_ms: float = 0.0
	var end_twa_deg: float = 0.0


## The templates, each run at every wind strength asked for. Space at 25 s from a beam
## reach is a tack (the controller tacks up to 100 degrees of true wind angle); a gybe is
## a bear-away first and Space from the broad reach.
func _templates() -> Array[Case]:
	return [
		Case.new("tack_stb", "tack", 180.0, "none", 0.0, 0.0, 25.0, 48.0),
		Case.new("tack_port", "tack", 0.0, "none", 0.0, 0.0, 25.0, 48.0),
		Case.new("tack_held", "tack", 180.0, "steer_right", 25.0, 40.0, -1.0, 45.0),
		Case.new("gybe_broad", "gybe", 180.0, "steer_left", 25.0, 27.0, 30.0, 45.0),
		Case.new("gybe_beam", "gybe", 180.0, "steer_left", 25.0, 25.6, 27.0, 42.0),
		# Space with A held on a beam reach (starboard tack): away from the wind, a gybe where
		# Space alone tacks (Max, 6 November 2026).
		Case.new("gybe_beam_key", "gybe", 180.0, "steer_left", 26.95, 27.3, 27.0, 42.0),
		Case.new("run_left", "turn", 90.0, "steer_left", 25.0, 29.0, -1.0, 40.0),
		Case.new("irons", "irons", 270.0, "steer_right", 1.0, 21.0, -1.0, 22.0),
		Case.new("straight", "straight", 180.0, "none", 0.0, 0.0, -1.0, 45.0),
	]


func _initialize() -> void:
	var options: Dictionary[String, String] = _read_user_args()
	var only: String = options.get("only", "")
	var winds: PackedFloat64Array = PackedFloat64Array([12.0, 18.0, 24.0])
	if options.has("winds"):
		winds.clear()
		for part: String in options["winds"].split(","):
			winds.append(part.to_float())
	var every: int = maxi(options.get("every", "2").to_int(), 1)
	var out_dir: String = options.get("out_dir", "")
	_waves = options.get("waves", "0") == "1"
	_wave_scale = options.get("wave_scale", "1").to_float()
	_hold_turn = options.get("hold_turn", "0") == "1"
	_sharp = options.get("sharp", "0") == "1"
	if options.has("body_carve") or options.has("body_back"):
		_body_carve = options.get("body_carve", "0").to_float()
		_body_back = options.get("body_back", "0").to_float()
	_cue = options.get("cue", "0") == "1"
	_cue_delay_s = options.get("cue_delay", "0").to_float()
	_shift_s = options.get("shift", "0").to_float()
	for key: String in options:
		if key.contains("."):
			_overrides[key] = options[key]
	if not _overrides.is_empty():
		print("overrides: %s" % str(_overrides))
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
	if options.has("gear_board") or options.has("gear_sail") or options.has("gear_fin"):
		_gear = GearChoice.from_ids(options.get("gear_board", ""), options.get("gear_sail", ""), options.get("gear_fin", ""))
		print("gear: " + _gear.names_line())
		print(fin_line(_gear.fin_config()))

	var cases: Array[Case] = []
	for template: Case in _templates():
		if only != "" and not _named(template.name, only):
			continue
		for kt: float in winds:
			var c: Case = template.with_wind(kt)
			if _shift_s != 0.0 and c.kind != "straight" and c.kind != "irons":
				c.press_from_s += _shift_s
				c.press_until_s += _shift_s
				if c.space_at_s >= 0.0:
					c.space_at_s += _shift_s
				c.seconds += _shift_s
			cases.append(c)

	print("%-11s %4s | %-16s | %5s %5s %6s %6s | %6s %5s %5s %5s %4s %5s | %5s %6s" % [
		"case", "kt", "fall", "cross", "done", "settle", "m.end", "speed", "hdg", "heel", "yaw", "rev", "leanSD", "endV", "endTWA"])
	var falls: int = 0
	var nans: int = 0
	var unfinished: int = 0
	for c: Case in cases:
		var r: Result = _run_case(c, every, out_dir)
		if r.fell_s >= 0.0:
			falls += 1
		if r.nan:
			nans += 1
		if c.kind != "straight" and r.done_s < 0.0:
			unfinished += 1
		print(_format(c, r))
	print("%d cases: %d with a fall, %d with NaN, %d manoeuvres not completed" % [cases.size(), falls, nans, unfinished])
	quit(0)


func _run_case(c: Case, every: int, out_dir: String) -> Result:
	for action: String in ["steer_left", "steer_right", "steer_sharp", "tack", "sheet_in", "sheet_out", "rake_back", "rake_forward"]:
		Input.action_release(action)
	_held_action = ""
	_cue_open_since_s = -1.0
	_cue_given = false
	var sim: WindsurferSim = WindsurferSim.create_default()
	if _gear != null:
		sim = _gear.sim_with(sim)
	sim.wind_config = sim.wind_config.duplicate()
	sim.wind_config.speed_kt = c.wind_kt
	sim.wind = WindField.new(sim.wind_config)
	var controller: PlayerController = PlayerController.new()
	controller.set_sail(sim.sail, sim.sailor_config)
	_apply_overrides(sim, controller)
	var body: MouseBody = null
	if not is_nan(_body_carve):
		body = MouseBody.new()
		body.scripted = true
		controller.body = body
	if _waves and _wave_scale != 1.0:
		scale_waves(sim.wave_set_config, _wave_scale)
		_wave_scale = 1.0  # the shared resource is scaled once for the whole run
	sim.set_waves(_waves)
	var controls: SimControls = SimControls.new()
	controls.sheet = 0.0
	sim.reset(Vector3.ZERO, deg_to_rad(c.heading_deg))

	var file: FileAccess = null
	if out_dir != "":
		file = FileAccess.open("%s/%s_%02d.csv" % [out_dir, c.name, int(c.wind_kt)], FileAccess.WRITE)
		if file != null:
			file.store_line(Telemetry.csv_header())

	var r: Result = Result.new()
	# Every fall with the 2 s before it, for tools/fall_detail.py (the stay-on-the-board work).
	var fall_log: FallLog = FallLog.new("matrix", c.name, "-", "open%.0f%s" % [c.wind_kt, "w" if _waves else ""])
	var start_s: float = c.space_at_s if c.space_at_s >= 0.0 else c.press_from_s
	var tack_before: float = 0.0
	var heading_at_start: float = 0.0
	var manoeuvre_seen: bool = false
	var space_done: bool = false
	var calm_since: float = -1.0
	var window_from: float = c.seconds - 15.0 if c.kind == "straight" else INF
	var headings: PackedFloat64Array = PackedFloat64Array()
	var leans: PackedFloat64Array = PackedFloat64Array()
	var last_sheet: float = 0.0
	var sheet_direction: float = 0.0
	var steps: int = int(c.seconds / DT)
	for i: int in steps:
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
		_hands_in_the_manoeuvre(controller, body, space_done)
		controller.update(sim.telemetry, controls, DT)
		sim.step(DT, controls)
		var fall_line: String = fall_log.watch(sim)
		if fall_line != "":
			print(fall_line)
		var t: Telemetry = sim.telemetry
		if file != null and i % every == 0:
			file.store_line(t.to_csv_row())

		if is_nan(t.speed_ms) or is_nan(t.heel_deg) or is_nan(t.position.y):
			r.nan = true
		if sim.sailor_state == WindsurferSim.SailorState.FALLEN and r.fell_s < 0.0:
			r.fell_s = t.time_s
			r.fall_kind = sim.fall_kind
		if t.time_s < start_s:
			continue
		if tack_before == 0.0:
			tack_before = 1.0 if t.twa_deg >= 0.0 else -1.0
			heading_at_start = t.heading_deg
		var on_new_tack: bool = signf(t.twa_deg) == -tack_before
		var twa: float = absf(t.twa_deg)
		match c.kind:
			"tack":
				if r.crossed_s < 0.0 and on_new_tack and twa > 5.0:
					r.crossed_s = t.time_s
				if r.crossed_s >= 0.0 and r.done_s < 0.0 and on_new_tack and twa > 50.0:
					r.done_s = t.time_s
			"gybe":
				if r.crossed_s < 0.0 and on_new_tack and twa > 120.0:
					r.crossed_s = t.time_s
				if r.crossed_s >= 0.0 and r.done_s < 0.0 and on_new_tack and twa < 120.0:
					r.done_s = t.time_s
			"turn":
				if r.done_s < 0.0 and absf(wrapf(t.heading_deg - heading_at_start, -180.0, 180.0)) > 60.0:
					r.done_s = t.time_s
			"irons":
				if r.done_s < 0.0 and twa > 45.0 and t.speed_ms > 1.5:
					r.done_s = t.time_s
		if controller.manoeuvre != PlayerController.Manoeuvre.NONE:
			manoeuvre_seen = true
		elif manoeuvre_seen and r.manoeuvre_end_s < 0.0:
			r.manoeuvre_end_s = t.time_s
		if r.done_s >= 0.0:
			if absf(t.yaw_rate_dps) < SETTLED_YAW_DPS:
				if calm_since < 0.0:
					calm_since = t.time_s
				elif r.settled_s < 0.0 and t.time_s - calm_since >= 1.0:
					r.settled_s = calm_since
			else:
				calm_since = -1.0
			if window_from == INF:
				window_from = r.done_s + WINDOW_START_S
		if t.time_s >= window_from and t.time_s <= window_from + WINDOW_LENGTH_S and sim.sailor_state == WindsurferSim.SailorState.SAILING:
			if r.window_count == 0:
				last_sheet = t.sheet
			r.window_count += 1
			r.window_speed_ms += t.speed_ms
			r.window_max_heel_deg = maxf(r.window_max_heel_deg, absf(t.heel_deg))
			r.window_max_yaw_dps = maxf(r.window_max_yaw_dps, absf(t.yaw_rate_dps))
			headings.append(t.heading_deg)
			leans.append(t.lean)
			# A sheet reversal: the sheet changed direction by more than a few percent.
			var moved: float = t.sheet - last_sheet
			if absf(moved) > 0.03:
				var direction: float = signf(moved)
				if sheet_direction != 0.0 and direction != sheet_direction:
					r.window_sheet_reversals += 1
				sheet_direction = direction
				last_sheet = t.sheet
	if file != null:
		file.close()
	if r.window_count > 0:
		r.window_speed_ms /= float(r.window_count)
		var lowest: float = INF
		var highest: float = -INF
		for h: float in headings:
			var relative: float = wrapf(h - headings[0], -180.0, 180.0)
			lowest = minf(lowest, relative)
			highest = maxf(highest, relative)
		r.window_heading_range_deg = highest - lowest
		var mean: float = 0.0
		for l: float in leans:
			mean += l
		mean /= float(leans.size())
		var variance: float = 0.0
		for l: float in leans:
			variance += (l - mean) * (l - mean)
		r.window_lean_sd = sqrt(variance / float(leans.size()))
	r.end_speed_ms = sim.telemetry.speed_ms
	r.end_twa_deg = sim.telemetry.twa_deg
	return r


## The player's hands from Space to the manoeuvre's end (--hold_turn, --body_carve, --body_back,
## --cue): the turn key toward the turn held, the scripted body pressed, Space again for the flip.
func _hands_in_the_manoeuvre(controller: PlayerController, body: MouseBody, space_done: bool) -> void:
	var turn: float = controller.manoeuvre_turn_right()
	var in_it: bool = space_done and turn != 0.0
	if _hold_turn:
		if in_it:
			_held_action = "steer_right" if turn > 0.0 else "steer_left"
			Input.action_press(_held_action)
			if _sharp:
				Input.action_press("steer_sharp")
		elif _held_action != "":
			Input.action_release(_held_action)
			Input.action_release("steer_sharp")
			_held_action = ""
	if body != null:
		# As seen from behind the board (MouseBody.Sideways.AS_SEEN) the mouse toward the turn puts
		# the inside rail down.
		body.side = clampf(_body_carve * turn, -1.0, 1.0) if in_it else 0.0
		body.back = clampf(_body_back, -1.0, 1.0) if in_it else 0.0
	if _cue and not _cue_given and controller.flip_cue_open():
		if _cue_open_since_s < 0.0:
			_cue_open_since_s = controller.manoeuvre_time_s()
		if controller.manoeuvre_time_s() - _cue_open_since_s >= _cue_delay_s - 1e-6:
			Input.action_press("tack")
			_cue_given = true


## Whether a case's name contains one of the --only parts (comma-separated: --only=tack_stb,gybe).
func _named(case_name: String, only: String) -> bool:
	for part: String in only.split(","):
		if part != "" and case_name.contains(part):
			return true
	return false


## Scales every wave's amplitude and steepness (--wave_scale), in the shared resource.
## A fin's numbers in one line: its depth, area and root chord, and its stiffness as the flex test
## sees it (FinModel.point_load_deflection_m(): the test's load at the test's place on this fin) and
## as the beam's bending stiffness at the root (EI, N m²).
static func fin_line(fin_config: FinConfig) -> String:
	var fin: FinModel = FinModel.new(fin_config)
	var load_n: float = fin_config.flex_test_load_n
	var position: float = fin_config.flex_test_position
	var root_ei: float = fin.stiffness_scale * pow(fin_config.root_chord_m(), 4.0)
	return "fin: %.0f cm deep, %.0f cm², root chord %.1f cm; %.0f N at %.0f %% of its depth bends it %.1f mm (the test fin: %.1f mm); root EI %.0f N m²" % [
		fin_config.span_m * 100.0, fin_config.area_m2 * 10000.0, fin_config.root_chord_m() * 100.0, load_n, position * 100.0,
		fin.point_load_deflection_m(load_n, position) * 1000.0, fin_config.flex_test_deflection_m * 1000.0, root_ei]


static func scale_waves(wave_set: WaveSetConfig, factor: float) -> void:
	for wave: GerstnerWaveConfig in wave_set.waves:
		wave.amplitude_m *= factor
		wave.steepness *= factor


## --pilot.x=, --controller.x=, --sailor.x=, --sail.x=, --board.x= and --wave1.x= to
## --wave4.x= (the waves of the set, before they are put on the water) set a field by name.
func _apply_overrides(sim: WindsurferSim, controller: PlayerController) -> void:
	for key: String in _overrides:
		var parts: PackedStringArray = key.split(".", true, 1)
		if parts.size() != 2:
			continue
		var value: float = _overrides[key].to_float()
		var target: Object = null
		match parts[0]:
			"pilot":
				target = controller.auto_sheet_pilot
			"controller":
				target = controller
			"sailor":
				target = sim.sailor_config
			"sail":
				target = sim.sail_config
			"board":
				target = sim.board_config
			"wave1", "wave2", "wave3", "wave4":
				var index: int = parts[0].substr(4).to_int() - 1
				if index < sim.wave_set_config.waves.size():
					target = sim.wave_set_config.waves[index]
		if target == null or not (parts[1] in target):
			push_error("No field '%s' to override." % key)
			continue
		var current: Variant = target.get(parts[1])
		target.set(parts[1], (value != 0.0) if current is bool else (int(value) if current is int else value))


func _format(c: Case, r: Result) -> String:
	var fall: String = "-"
	if r.fell_s >= 0.0:
		fall = "%.1f %s" % [r.fell_s, r.fall_kind]
	if r.nan:
		fall += " NaN"
	var window: String = "%6s %5s %5s %5s %4s %5s" % ["-", "-", "-", "-", "-", "-"]
	if r.window_count > 0:
		window = "%6.2f %5.1f %5.1f %5.1f %4d %5.2f" % [r.window_speed_ms, r.window_heading_range_deg, r.window_max_heel_deg, r.window_max_yaw_dps, r.window_sheet_reversals, r.window_lean_sd]
	return "%-11s %4.0f | %-16s | %5s %5s %6s %6s | %s | %5.2f %6.1f" % [
		c.name, c.wind_kt, fall, _stamp(r.crossed_s), _stamp(r.done_s), _stamp(r.settled_s), _stamp(r.manoeuvre_end_s), window, r.end_speed_ms, r.end_twa_deg]


func _stamp(seconds: float) -> String:
	return "-" if seconds < 0.0 else "%.1f" % seconds


func _read_user_args() -> Dictionary[String, String]:
	var options: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
			options[parts[0]] = parts[1]
	return options
