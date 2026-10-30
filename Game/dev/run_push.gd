extends SceneTree
## GP0, measure the push before it is built (ROADMAP.md, section GP). The board is sailed the way
## the player's board is in beginner mode: PlayerController with the auto-sheet, fed by AiHands
## that hold a true wind angle, on the game's open water (waves, the wind's height gradient,
## and gusts unless told otherwise). Every tick, before the controller runs, the harness sets the
## autopilot's margin (Autopilot.hike_share, ankle_share, the depower and catch settings), as
## package A's dial would; the sailor's technique targets (SailorConfig) are set once per case,
## as package B's mouse would. Falls are real: the sailor waterstarts after the sim's own delay
## and the controller starts again, so a fall costs what it costs in the game. Nothing in
## Game/sim/ is changed. Use tools/push_check.sh.
##
## Each case prints one line and appends one row to --out (a CSV); every fall appends a row to
## --falls_out with what the board did in the 2 s before it (the warning signs, for GR1 and SO1).
##
## Arguments after "--":
##   [--winds=12,18,24] [--twas=48,100,135] [--seconds=150] [--from=40]
##   [--waves=1] [--gusts=1] [--gust_intensity=0.2] [--gust_period=8] [--gradient=1]
##   [--sweep=<group>.<field>[+<group>.<field>]=<v1>,<v2>,...] [--sweep2=...]  (crossed)
##   [--pilot.<field>=<n>] [--sailor.<field>=<n>] [--board.<field>=<n>]   (fixed for every case;
##   board: only the numbers the sim copies every tick, such as the footstraps)
##   [--timing=1 --timing_lead_s=1 --timing_threshold=0.3 --timing_ease=<group.field>:<n>;...]
##      the sailor who knows the gusts: while the gust factor now or timing_lead_s ahead is above
##      1 + threshold x intensity, the timing_ease settings replace the case's own
##   [--slice=<i>/<n>] (run every n-th case from the i-th) [--out=<csv>] [--falls_out=<csv>]
##   [--label=<text>] (a column in the CSV, to tell runs apart)
##   [--hold_sheet=1] the player holds W (sheet in) all the time, over the auto-sheet
##   [--reaction_s=<s>] the sailor feels the apparent wind's strength this late: the controller
##      is handed the apparent wind speed of that long ago (only the controller; the physics sails
##      in the real wind). The autopilot otherwise answers a gust in the same tick
## The groups are pilot (the auto-sheet's Autopilot), sailor (SailorConfig), sail (SailConfig) and timing
## (timing.lead_s, timing.threshold: to sweep the timing itself).

const DT: float = 1.0 / 60.0
## The wind comes from the West; the board sails on starboard tack (wind from its right side).
const WIND_FROM_DEG: float = 270.0
## Below this speed the board is sailed between START_TWA_DEG and START_TWA_MAX_DEG, as a
## sailor getting going on a reach before pointing or bearing away (Autopilot.pointing_speed_ms
## and bear_away_twa_deg do the same upwind for the scenarios).
const POINTING_SPEED_MS: float = 5.0
const START_TWA_DEG: float = 70.0
const START_TWA_MAX_DEG: float = 100.0
## The fall's warning signs are read this far back.
const WARNING_BACK_S: PackedFloat64Array = [2.0, 1.0, 0.5, 0.25, 0.0]

var _options: Dictionary[String, String] = {}


## One case: the wind, the course and the settings.
class PushCase:
	var wind_kt: float = 18.0
	var twa_deg: float = 100.0
	## "group.field" -> value, applied as described at the top.
	var settings: Dictionary[String, float] = {}
	## The sweep's values, for the CSV.
	var sweep_text: String = ""


## The numbers kept per case.
class PushResult:
	var made_good_ms: float = 0.0
	var vmg_ms: float = 0.0
	var falls: int = 0
	var fall_kinds: Dictionary[String, int] = {}
	var sailing_share: float = 0.0
	var speed_sailing_ms: float = 0.0
	var samples: int = 0
	var sailing_samples: int = 0
	var heel_leeward_max_deg: float = 0.0
	var fin_share_max: float = 0.0
	var fin_share_p95: float = 0.0
	var fin_stalled_share: float = 0.0
	var slip_max_deg: float = 0.0
	var slip_p95_deg: float = 0.0
	var pitch_mean_deg: float = 0.0
	var pitch_sd_deg: float = 0.0
	var trim_mean_deg: float = 0.0
	var heel_mean_deg: float = 0.0
	var alpha_mean_deg: float = 0.0
	var lean_mean: float = 0.0
	var planing_share: float = 0.0
	var wet_front_m: float = 0.0
	## The sheet (0 eased out to 1 fully in), and how fast it moves back and forth: the root mean
	## square of its change per second, and the angle of attack's spread (both show a jerking trim).
	var sheet_mean: float = 0.0
	var sheet_rate_rms: float = 0.0
	var alpha_sd_deg: float = 0.0
	var eased_share: float = 0.0
	var nan: bool = false


func _initialize() -> void:
	_options = _read_user_args()
	var cases: Array[PushCase] = _build_cases()
	var slice: PackedStringArray = _options.get("slice", "0/1").split("/")
	var slice_index: int = slice[0].to_int()
	var slice_count: int = maxi(slice[1].to_int(), 1)
	var out_path: String = _options.get("out", "")
	var falls_path: String = _options.get("falls_out", "")
	print("GP0 push check: %d cases (this slice %d/%d), %s s per case, means over t >= %s s; waves %s, gusts %s (%.2f, %.0f s), gradient %s" % [
		cases.size(), slice_index, slice_count, _options.get("seconds", "150"), _options.get("from", "40"),
		_options.get("waves", "1"), _options.get("gusts", "1"), _gust_intensity(), _gust_period_s(), _options.get("gradient", "1")])
	print("wind TWA  sweep                         made  vmg   sail%  falls  speed  heelMax finMax finP95 stall%  slipMax slipP95  pitchSD trim  heel  alpha lean  plan% front eased%")
	for i: int in cases.size():
		if i % slice_count != slice_index:
			continue
		var case: PushCase = cases[i]
		var falls: Array[String] = []
		var result: PushResult = _run_case(case, falls)
		print(_format(case, result))
		if out_path != "":
			_append_row(out_path, _csv_header(), _csv_row(case, result))
		if falls_path != "":
			for row: String in falls:
				_append_row(falls_path, _falls_header(), row)
	quit(0)


## The cases: every wind and course, crossed with --sweep and --sweep2.
func _build_cases() -> Array[PushCase]:
	var fixed: Dictionary[String, float] = {}
	for key: String in _options:
		if key.begins_with("pilot.") or key.begins_with("sailor.") or key.begins_with("sail.") or key.begins_with("board."):
			fixed[key] = _options[key].to_float()
	var sweeps: Array[Array] = [_parse_sweep(_options.get("sweep", "")), _parse_sweep(_options.get("sweep2", ""))]
	var cases: Array[PushCase] = []
	for wind_kt: float in _number_list(_options.get("winds", "12,18,24")):
		for twa_deg: float in _number_list(_options.get("twas", "48,100,135")):
			for first: Dictionary in sweeps[0]:
				for second: Dictionary in sweeps[1]:
					var case: PushCase = PushCase.new()
					case.wind_kt = wind_kt
					case.twa_deg = twa_deg
					case.settings = fixed.duplicate()
					var texts: PackedStringArray = []
					for point: Dictionary in [first, second]:
						for key: String in point:
							if key == "_text":
								texts.append(point[key])
							else:
								case.settings[key] = point[key]
					case.sweep_text = " ".join(texts)
					cases.append(case)
	return cases


## "--sweep=pilot.hike_share=0.8,1.0" -> [{pilot.hike_share: 0.8, _text: ...}, ...]. Several
## fields joined by "+" take the same value. No sweep is one point with nothing set.
func _parse_sweep(text: String) -> Array[Dictionary]:
	var points: Array[Dictionary] = []
	if text == "":
		points.append({})
		return points
	var parts: PackedStringArray = text.split("=", true, 1)
	var fields: PackedStringArray = parts[0].split("+")
	for value: float in _number_list(parts[1]):
		var point: Dictionary = {}
		for field: String in fields:
			point[field] = value
		point["_text"] = "%s=%s" % [fields[0].get_slice(".", 1), _short(value)]
		points.append(point)
	return points


## One case, sailed from rest on starboard tack.
func _run_case(case: PushCase, falls: Array[String]) -> PushResult:
	var sim: WindsurferSim = _make_sim(case.wind_kt)
	_apply_settings(case.settings, "sailor.", sim.sailor_config)
	_apply_settings(case.settings, "sail.", sim.sail_config)
	# The board's numbers the sim copies every tick (the footstraps), on a copy of the shared
	# default; fields that build the hull or the buoyancy grid are not for this.
	sim.board_config = sim.board_config.duplicate()
	_apply_settings(case.settings, "board.", sim.board_config)
	var controller: PlayerController = PlayerController.new()
	var hands: AiHands = AiHands.new()
	controller.hands = hands
	controller.set_sail(sim.sail, sim.sailor_config, sim.air_density_kg_m3)
	var controls: SimControls = SimControls.new()
	controller.reset_controls(controls)
	sim.reset(Vector3.ZERO, deg_to_rad(_heading_for_twa(clampf(case.twa_deg, START_TWA_DEG, START_TWA_MAX_DEG))))

	# The sailor who knows the gusts: a second wind field on the same config, read ahead.
	var timing: bool = _options.get("timing", "0") == "1"
	var lead_s: float = case.settings.get("timing.lead_s", _options.get("timing_lead_s", "1").to_float())
	var threshold: float = case.settings.get("timing.threshold", _options.get("timing_threshold", "0.3").to_float())
	var ease_settings: Dictionary[String, float] = _parse_settings(_options.get("timing_ease", ""))
	var probe: WindField = WindField.new(sim.wind_config)
	var gust_line: float = 1.0 + threshold * _gust_intensity()

	var result: PushResult = PushResult.new()
	var seconds: float = _options.get("seconds", "150").to_float()
	var from_s: float = _options.get("from", "40").to_float()
	var steps: int = int(seconds / DT)
	var course: Vector3 = SimMath.dir_from_bearing(deg_to_rad(_heading_for_twa(case.twa_deg)))
	var upwind: Vector3 = SimMath.dir_from_bearing(deg_to_rad(WIND_FROM_DEG))
	var start_position: Vector3 = Vector3.ZERO
	var fin_shares: PackedFloat32Array = PackedFloat32Array()
	var slips: PackedFloat32Array = PackedFloat32Array()
	var pitch_square_sum: float = 0.0
	var history: Array[Dictionary] = []
	var pointing: bool = false
	var previous_state: WindsurferSim.SailorState = sim.sailor_state
	var reaction_ticks: int = int(round(_options.get("reaction_s", "0").to_float() / DT))
	var felt_aws: PackedFloat64Array = PackedFloat64Array()
	var hold_sheet: bool = _options.get("hold_sheet", "0") == "1"
	var last_sheet: float = 0.0
	var sheet_rate_square_sum: float = 0.0
	var alpha_square_sum: float = 0.0
	for i: int in steps:
		var t: Telemetry = sim.telemetry
		var easing: bool = false
		if timing:
			probe.time_s = sim.wind.time_s + lead_s
			probe.step(0.0)
			var ahead: float = probe.current_speed_ms / maxf(sim.wind_config.speed_ms(), 0.01)
			var now: float = sim.wind.current_speed_ms / maxf(sim.wind_config.speed_ms(), 0.01)
			easing = maxf(ahead, now) > gust_line
		# The dial: the margin set every tick, as GP1 will (the pilot is a new one after a
		# waterstart, PlayerController.reset_controls).
		_apply_settings(case.settings, "pilot.", controller.auto_sheet_pilot)
		if easing:
			_apply_settings(ease_settings, "pilot.", controller.auto_sheet_pilot)
		if t.speed_ms > POINTING_SPEED_MS:
			pointing = true
		elif t.speed_ms < POINTING_SPEED_MS - 1.5:
			pointing = false
		var wanted_twa: float = case.twa_deg if pointing else clampf(case.twa_deg, START_TWA_DEG, START_TWA_MAX_DEG)
		hands.steer = LearnedSkipper.steer_toward_twa(t.twa_deg, 1.0, wanted_twa)
		hands.sheet = 1.0 if hold_sheet else 0.0
		if reaction_ticks > 0:
			# The telemetry is written afresh by the next step, so this changes only what the
			# controller reads now.
			felt_aws.append(t.aws_kt)
			if felt_aws.size() > reaction_ticks + 1:
				felt_aws.remove_at(0)
			t.aws_kt = felt_aws[0]
		if sim.sailor_state == WindsurferSim.SailorState.SAILING:
			controller.update(t, controls, DT)
		sim.step(DT, controls)
		t = sim.telemetry
		if sim.sailor_state == WindsurferSim.SailorState.SAILING and previous_state == WindsurferSim.SailorState.FALLEN:
			controller.reset_controls(controls)
		var fell_now: bool = sim.sailor_state == WindsurferSim.SailorState.FALLEN and previous_state == WindsurferSim.SailorState.SAILING
		previous_state = sim.sailor_state
		var sheet_before: float = last_sheet
		last_sheet = controls.sheet
		history.append(_warning_sample(t))
		if history.size() > int(WARNING_BACK_S[0] / DT) + 2:
			history.pop_front()
		if is_nan(t.speed_ms) or is_nan(t.position.y):
			result.nan = true
			break
		if t.time_s < from_s:
			start_position = t.position
			continue
		if fell_now:
			result.falls += 1
			result.fall_kinds[sim.fall_kind] = result.fall_kinds.get(sim.fall_kind, 0) + 1
			falls.append(_falls_row(case, sim.fall_kind, t.time_s, history))
		result.samples += 1
		if easing:
			result.eased_share += 1.0
		if sim.sailor_state != WindsurferSim.SailorState.SAILING:
			continue
		result.sailing_samples += 1
		result.speed_sailing_ms += t.speed_ms
		var leeward_heel_deg: float = -t.heel_deg  # starboard tack: leeward is port, negative heel
		result.heel_leeward_max_deg = maxf(result.heel_leeward_max_deg, leeward_heel_deg)
		result.heel_mean_deg += leeward_heel_deg
		result.fin_share_max = maxf(result.fin_share_max, t.fin_load_share)
		fin_shares.append(t.fin_load_share)
		slips.append(absf(t.fin_slip_deg))
		result.slip_max_deg = maxf(result.slip_max_deg, absf(t.fin_slip_deg))
		if t.fin_stalled:
			result.fin_stalled_share += 1.0
		result.pitch_mean_deg += t.pitch_deg
		pitch_square_sum += t.pitch_deg * t.pitch_deg
		result.trim_mean_deg += t.trim_deg
		result.alpha_mean_deg += t.alpha_deg
		result.lean_mean += absf(t.lean)
		result.planing_share += 1.0 if t.is_planing else 0.0
		result.wet_front_m += t.wet_front_m
		result.sheet_mean += controls.sheet
		var sheet_rate: float = (controls.sheet - sheet_before) / DT
		sheet_rate_square_sum += sheet_rate * sheet_rate
		alpha_square_sum += t.alpha_deg * t.alpha_deg
	var elapsed_s: float = maxf(result.samples * DT, DT)
	var moved: Vector3 = sim.telemetry.position - start_position
	result.made_good_ms = moved.dot(course) / elapsed_s
	result.vmg_ms = moved.dot(upwind) / elapsed_s
	_finish(result, fin_shares, slips, pitch_square_sum)
	var n: float = float(maxi(result.sailing_samples, 1))
	result.sheet_mean /= n
	result.sheet_rate_rms = sqrt(sheet_rate_square_sum / n)
	result.alpha_sd_deg = sqrt(maxf(alpha_square_sum / n - result.alpha_mean_deg * result.alpha_mean_deg, 0.0))
	return result


## The game's open water: the default board, sail, fin and sailor on their own copies of the
## configs (a case's settings must not reach the next), the settings' wind and the waves.
func _make_sim(wind_kt: float) -> WindsurferSim:
	var waves: bool = _options.get("waves", "1") == "1"
	var sim: WindsurferSim = WindsurferSim.create_for(EnvironmentConfig.new(), waves, true)
	var wind: WindConfig = sim.wind_config
	wind.speed_kt = wind_kt
	wind.from_bearing_deg = WIND_FROM_DEG
	wind.height_gradient_enabled = _options.get("gradient", "1") == "1"
	wind.gusts_enabled = _options.get("gusts", "1") == "1"
	wind.gust_intensity = _gust_intensity()
	wind.gust_period_s = _gust_period_s()
	wind.shifts_enabled = false
	sim.wind = WindField.new(wind)
	return sim


func _gust_intensity() -> float:
	return _options.get("gust_intensity", "0.2").to_float()


func _gust_period_s() -> float:
	return _options.get("gust_period", "8").to_float()


## The compass heading of a starboard-tack course at this true wind angle (the wind from the
## West: 90 degrees is due South).
func _heading_for_twa(twa_deg: float) -> float:
	return fposmod(WIND_FROM_DEG - twa_deg, 360.0)


## Sets every "<prefix>field" of the settings on the target object.
func _apply_settings(settings: Dictionary[String, float], prefix: String, target: Object) -> void:
	for key: String in settings:
		if not key.begins_with(prefix):
			continue
		var field: String = key.trim_prefix(prefix)
		if not (field in target):
			push_error("No field '%s' to set." % key)
			continue
		var current: Variant = target.get(field)
		var value: float = settings[key]
		target.set(field, (value != 0.0) if current is bool else (int(value) if current is int else value))


## "pilot.hike_share:1.0;pilot.ankle_share:0.8" -> {pilot.hike_share: 1.0, ...}.
func _parse_settings(text: String) -> Dictionary[String, float]:
	var settings: Dictionary[String, float] = {}
	for part: String in text.split(";", false):
		var pair: PackedStringArray = part.split(":", true, 1)
		if pair.size() == 2:
			settings[pair[0]] = pair[1].to_float()
	return settings


## What the board was doing at one tick, for the warning signs before a fall.
func _warning_sample(t: Telemetry) -> Dictionary:
	return {
		"fin_share": t.fin_load_share, "slip_deg": absf(t.fin_slip_deg), "heel_lee_deg": -t.heel_deg,
		"lean": absf(t.lean), "feet_excess_nm": t.feet_moment_excess_nm, "alpha_deg": t.alpha_deg,
		"tws_kt": t.tws_at_sail_kt, "speed_ms": t.speed_ms, "pitch_deg": t.pitch_deg,
		"yaw_rate_dps": t.yaw_rate_dps, "stalled": 1.0 if t.fin_stalled else 0.0}


const WARNING_FIELDS: PackedStringArray = ["fin_share", "slip_deg", "heel_lee_deg", "lean", "feet_excess_nm", "alpha_deg", "tws_kt", "speed_ms", "pitch_deg", "yaw_rate_dps", "stalled"]


func _falls_header() -> String:
	var columns: PackedStringArray = ["label", "wind_kt", "twa_deg", "sweep", "kind", "time_s"]
	for back_s: float in WARNING_BACK_S:
		for field: String in WARNING_FIELDS:
			columns.append("%s_m%s" % [field, _short(back_s)])
	return ",".join(columns)


## The fall and the board's state at each of WARNING_BACK_S before it (the last sample is the
## tick it fell on).
func _falls_row(case: PushCase, kind: String, time_s: float, history: Array[Dictionary]) -> String:
	var values: PackedStringArray = [_options.get("label", ""), _short(case.wind_kt), _short(case.twa_deg), case.sweep_text, kind, "%.2f" % time_s]
	for back_s: float in WARNING_BACK_S:
		var index: int = clampi(history.size() - 1 - int(round(back_s / DT)), 0, history.size() - 1)
		var sample: Dictionary = history[index]
		for field: String in WARNING_FIELDS:
			values.append("%.3f" % float(sample[field]))
	return ",".join(values)


func _finish(r: PushResult, fin_shares: PackedFloat32Array, slips: PackedFloat32Array, pitch_square_sum: float) -> void:
	var all: float = float(maxi(r.samples, 1))
	var n: float = float(maxi(r.sailing_samples, 1))
	r.sailing_share = r.sailing_samples / all
	r.eased_share /= all
	r.speed_sailing_ms /= n
	r.heel_mean_deg /= n
	r.fin_stalled_share /= n
	r.pitch_mean_deg /= n
	r.pitch_sd_deg = sqrt(maxf(pitch_square_sum / n - r.pitch_mean_deg * r.pitch_mean_deg, 0.0))
	r.trim_mean_deg /= n
	r.alpha_mean_deg /= n
	r.lean_mean /= n
	r.planing_share /= n
	r.wet_front_m /= n
	r.fin_share_p95 = _percentile(fin_shares, 0.95)
	r.slip_p95_deg = _percentile(slips, 0.95)


func _percentile(values: PackedFloat32Array, share: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: PackedFloat32Array = values.duplicate()
	sorted.sort()
	return sorted[clampi(int(share * (sorted.size() - 1)), 0, sorted.size() - 1)]


func _kinds_text(r: PushResult) -> String:
	var parts: PackedStringArray = []
	for kind: String in r.fall_kinds:
		parts.append("%s:%d" % [kind.replace(" ", "_"), r.fall_kinds[kind]])
	return " ".join(parts)


func _format(c: PushCase, r: PushResult) -> String:
	return "%3.0f  %3.0f  %-28s  %5.2f %5.2f  %4.0f   %3d   %5.2f   %5.1f   %4.2f   %4.2f   %4.1f    %5.1f   %5.1f     %4.2f   %4.2f %5.1f %5.1f %4.2f  %4.0f  %4.2f  %4.0f  %s%s" % [
		c.wind_kt, c.twa_deg, c.sweep_text, r.made_good_ms, r.vmg_ms, r.sailing_share * 100.0, r.falls,
		r.speed_sailing_ms, r.heel_leeward_max_deg, r.fin_share_max, r.fin_share_p95, r.fin_stalled_share * 100.0,
		r.slip_max_deg, r.slip_p95_deg, r.pitch_sd_deg, r.trim_mean_deg, r.heel_mean_deg, r.alpha_mean_deg,
		r.lean_mean, r.planing_share * 100.0, r.wet_front_m, r.eased_share * 100.0, _kinds_text(r), " NaN" if r.nan else ""]


func _csv_header() -> String:
	return "label,wind_kt,twa_deg,sweep,made_good_ms,vmg_ms,sailing_share,falls,fall_kinds,speed_sailing_ms,heel_leeward_max_deg,fin_share_max,fin_share_p95,fin_stalled_share,slip_max_deg,slip_p95_deg,pitch_sd_deg,trim_mean_deg,heel_mean_deg,alpha_mean_deg,lean_mean,planing_share,wet_front_m,eased_share,nan,sheet_mean,sheet_rate_rms,alpha_sd_deg"


func _csv_row(c: PushCase, r: PushResult) -> String:
	return ",".join(PackedStringArray([_options.get("label", ""), _short(c.wind_kt), _short(c.twa_deg), c.sweep_text,
		"%.3f" % r.made_good_ms, "%.3f" % r.vmg_ms, "%.3f" % r.sailing_share, str(r.falls), _kinds_text(r),
		"%.3f" % r.speed_sailing_ms, "%.2f" % r.heel_leeward_max_deg, "%.3f" % r.fin_share_max, "%.3f" % r.fin_share_p95,
		"%.3f" % r.fin_stalled_share, "%.2f" % r.slip_max_deg, "%.2f" % r.slip_p95_deg, "%.3f" % r.pitch_sd_deg,
		"%.2f" % r.trim_mean_deg, "%.2f" % r.heel_mean_deg, "%.2f" % r.alpha_mean_deg, "%.3f" % r.lean_mean,
		"%.3f" % r.planing_share, "%.3f" % r.wet_front_m, "%.3f" % r.eased_share, "1" if r.nan else "0", "%.3f" % r.sheet_mean, "%.3f" % r.sheet_rate_rms, "%.2f" % r.alpha_sd_deg]))


## Appends a line, writing the header first when the file is new (several processes may share
## the file one after another, never at once: each slice has its own when run in parallel).
func _append_row(path: String, header: String, row: String) -> void:
	var exists: bool = FileAccess.file_exists(path)
	if not exists:
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE if exists else FileAccess.WRITE)
	if file == null:
		push_error("Cannot write %s" % path)
		return
	if exists:
		file.seek_end()
	else:
		file.store_line(header)
	file.store_line(row)
	file.close()


func _short(value: float) -> String:
	return str(snappedf(value, 0.001))


func _number_list(text: String) -> PackedFloat64Array:
	var numbers: PackedFloat64Array = PackedFloat64Array()
	for part: String in text.split(",", false):
		numbers.append(part.to_float())
	return numbers


func _read_user_args() -> Dictionary[String, String]:
	var options: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
			options[parts[0]] = parts[1]
	return options
