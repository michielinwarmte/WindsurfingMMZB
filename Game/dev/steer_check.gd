extends SceneTree
## The steering check (Documentation/reports/push_slider/PLAN.md, round 3; Michiel: "when planing
## at high speed the steering becomes sluggish; in the straps the steering comes from pushing
## and pulling with the two legs, less from moving the sail"). The board is sailed by the
## player's beginner controller (PlayerController with AiHands holding a true wind angle, the
## auto-sheet on) on the game's open water, flat and steady unless asked, until it planes
## steadily (--from seconds); then the stick goes hard over one way for --hold seconds (+1: a
## right turn on the screen, heading up on starboard tack; -1: bearing away). Measured: the time
## to turn 30 and 60 degrees of heading, the peak yaw rate, the speed at the start and at 30
## degrees, the helm's rake and legs over the turn, and whether the sailor fell. One line per
## wind and direction. The legs (PlayerController.legs_share, --legs) and the slider (--push) are
## the levers. Use tools/steer_check.sh.
##
## Arguments after "--": [--winds=12,18,24] [--twa=100] [--from=40] [--hold=8] [--legs=<share>]
## [--push=<level>] [--waves=0] [--gusts=0] [--pilot.<field>=<n>] [--sailor.<field>=<n>]
## [--controller.<field>=<n>] [--out=<csv>] [--label=<text>] [--trace=1] (a per-tick CSV of every
## case next to the results, from 2 s before the stick goes over: the helm, the yaw moments by
## source, the sail, the fin, the speed) [--probe=<rake|legs|rail>:<step>] (the physics alone: at
## --from the helm is frozen where the controller left it (the auto-sheet keeps trimming) and one
## lever is stepped toward the turn: the rake by <step> of its range (+ is the rig back), the back
## foot's push to <step>, the weight on the inside rail to <step>. The line then also gives the
## yaw rate toward the turn 0.5 s after it (y0.5). The board left alone at speed is not steady in
## yaw, so compare with --probe=rake:0.)
##
## Columns: the speed at the start (v0), the time to turn 30 and 60 degrees (t30, t60), the speed
## at 30 degrees (v30), the peak yaw rate, the most turned, the mean rake and legs' push, how far
## the rig was moved from where it was, on average (rig: the rake's distance from its start), the yaw
## rate toward the turn 1 s after the stick went over (y1s), the lowest speed in the turn (vmin),
## the auto-sheet pilot's largest depowering (dep, 0 to 1: how far the sail was eased for the
## felt heel), and a fall.

const DT: float = 1.0 / 60.0
const WIND_FROM_DEG: float = 270.0

var _options: Dictionary[String, String] = {}


class SteerResult:
	var wind_kt: float = 0.0
	var direction: String = ""
	var speed_start_ms: float = 0.0
	var speed_at_30_ms: float = 0.0
	var time_to_30_s: float = -1.0
	var time_to_60_s: float = -1.0
	var peak_yaw_dps: float = 0.0
	var turned_deg: float = 0.0
	var fell: bool = false
	var fall_kind: String = ""
	var fall_after_s: float = 0.0
	var rake_mean: float = 0.0
	var legs_mean: float = 0.0
	var rig_move_mean: float = 0.0
	var yaw_at_1s_dps: float = 0.0
	var speed_min_ms: float = INF
	var depower_max: float = 0.0
	var yaw_at_half_s_dps: float = 0.0
	var samples: int = 0


func _initialize() -> void:
	_options = _read_user_args()
	var winds: PackedFloat64Array = _number_list(_options.get("winds", "12,18,24"))
	print("steering check: TWA %s, from %s s, the stick over for %s s; legs %s, push %s; waves %s, gusts %s" % [
		_options.get("twa", "100"), _options.get("from", "40"), _options.get("hold", "8"), _options.get("legs", "0"),
		_options.get("push", "-"), _options.get("waves", "0"), _options.get("gusts", "0")])
	print("wind  turn        v0     t30    t60    v30   peakYaw  turned  rake   legs   rig    y1s   vmin   dep  fell")
	for wind_kt: float in winds:
		for direction: float in [1.0, -1.0]:
			var r: SteerResult = _run_case(wind_kt, direction)
			print(_format(r) + ("   y0.5 %5.1f" % r.yaw_at_half_s_dps if _options.has("probe") else ""))
			if _options.has("out"):
				_append_row(_options["out"], _csv_header(), _csv_row(r))
	quit(0)


func _run_case(wind_kt: float, direction: float) -> SteerResult:
	var sim: WindsurferSim = _make_sim(wind_kt)
	var fixed: Dictionary[String, float] = {}
	for key: String in _options:
		if key.begins_with("pilot.") or key.begins_with("sailor.") or key.begins_with("controller."):
			fixed[key] = _options[key].to_float()
	_apply_settings(fixed, "sailor.", sim.sailor_config)
	var controller: PlayerController = PlayerController.new()
	var hands: AiHands = AiHands.new()
	controller.hands = hands
	controller.set_sail(sim.sail, sim.sailor_config, sim.air_density_kg_m3)
	controller.legs_share = _options.get("legs", "0").to_float()
	if _options.has("push"):
		hands.push = PushDial.level_of(_options["push"])
	_apply_settings(fixed, "controller.", controller)
	# The pilot's settings go through the controller, which applies them after the push slider
	# every update (the slider would otherwise overwrite hike_share, drive_share, back_foot_bias).
	for key: String in fixed:
		if key.begins_with("pilot."):
			controller.pilot_overrides[key.trim_prefix("pilot.")] = fixed[key]
	var controls: SimControls = SimControls.new()
	controller.reset_controls(controls)
	var twa_deg: float = _options.get("twa", "100").to_float()
	sim.reset(Vector3.ZERO, deg_to_rad(fposmod(WIND_FROM_DEG - twa_deg, 360.0)))
	var r: SteerResult = SteerResult.new()
	r.wind_kt = wind_kt
	r.direction = "head up" if direction > 0.0 else "bear away"
	var from_s: float = _options.get("from", "40").to_float()
	var hold_s: float = _options.get("hold", "8").to_float()
	var heading0: float = 0.0
	var rake0: float = 0.0
	var t_over: float = 0.0
	var steps: int = int((from_s + hold_s) / DT)
	var trace: FileAccess = _open_trace(wind_kt, r.direction)
	var probe: PackedStringArray = _options.get("probe", "").split(":")
	var probing: bool = probe.size() == 2
	var held: SimControls = SimControls.new()
	for i: int in steps:
		var t: Telemetry = sim.telemetry
		var over: bool = t.time_s >= from_s
		if not over:
			hands.steer = LearnedSkipper.steer_toward_twa(t.twa_deg, 1.0, twa_deg)
		else:
			if r.samples == 0:
				heading0 = t.heading_deg
				rake0 = t.rake
				t_over = t.time_s
				r.speed_start_ms = t.speed_ms
				if probing:
					held.rake = controls.rake
					held.rig_tilt = controls.rig_tilt
					held.lean = controls.lean
					held.back_foot_push = controls.back_foot_push
					_step_the_lever(held, probe[0], probe[1].to_float() * direction, controller.tack_sign(t))
			hands.steer = direction
		if sim.sailor_state == WindsurferSim.SailorState.SAILING:
			controller.update(t, controls, DT)
		if over and probing:
			# The helm stays where it was, with the one lever stepped; the sheet is the pilot's.
			controls.rake = held.rake
			controls.rig_tilt = held.rig_tilt
			controls.lean = held.lean
			controls.back_foot_push = held.back_foot_push
		sim.step(DT, controls)
		t = sim.telemetry
		if trace != null and t.time_s >= from_s - 2.0:
			_trace_row(trace, t, controller, controls, heading0 if over else t.heading_deg, direction)
		if not over:
			continue
		if sim.sailor_state != WindsurferSim.SailorState.SAILING:
			r.fell = true
			r.fall_kind = t.fall_kind
			r.fall_after_s = t.time_s - t_over
			break
		r.samples += 1
		r.rake_mean += t.rake
		r.legs_mean += absf(controls.back_foot_push)
		r.rig_move_mean += absf(t.rake - rake0)
		# A right turn raises the compass heading.
		var turned: float = wrapf(t.heading_deg - heading0, -180.0, 180.0) * direction
		r.turned_deg = maxf(r.turned_deg, turned)
		r.peak_yaw_dps = maxf(r.peak_yaw_dps, absf(t.yaw_rate_dps))
		r.speed_min_ms = minf(r.speed_min_ms, t.speed_ms)
		r.depower_max = maxf(r.depower_max, controller.auto_sheet_pilot._depower)
		if r.yaw_at_half_s_dps == 0.0 and t.time_s - t_over >= 0.5:
			r.yaw_at_half_s_dps = -t.yaw_rate_dps * direction
		if r.yaw_at_1s_dps == 0.0 and t.time_s - t_over >= 1.0:
			# A right turn is a negative yaw rate (a positive one turns the bow to port).
			r.yaw_at_1s_dps = -t.yaw_rate_dps * direction
		if r.time_to_30_s < 0.0 and turned >= 30.0:
			r.time_to_30_s = t.time_s - t_over
			r.speed_at_30_ms = t.speed_ms
		if r.time_to_60_s < 0.0 and turned >= 60.0:
			r.time_to_60_s = t.time_s - t_over
			break
	if trace != null:
		trace.close()
	var n: float = float(maxi(r.samples, 1))
	r.rake_mean /= n
	r.legs_mean /= n
	r.rig_move_mean /= n
	return r


## The probe (--probe): one lever stepped toward the turn from where the controller left it. The
## rake and the legs head up when positive on either tack; the weight on the inside rail heads up
## on the windward side, which is the tack's side.
func _step_the_lever(controls: SimControls, lever: String, step: float, tack: float) -> void:
	match lever:
		"rake":
			controls.rake = clampf(controls.rake + step, -1.0, 1.0)
		"legs":
			controls.back_foot_push = clampf(step, -1.0, 1.0)
		"rail":
			controls.lean = clampf(step * tack, -1.0, 1.0)
		_:
			push_error("No lever '%s' to probe (rake, legs, rail)." % lever)


## The game's open water on the sim's own copies of the configs: steady wind and flat water
## unless asked, with the height gradient.
func _make_sim(wind_kt: float) -> WindsurferSim:
	var waves: bool = _options.get("waves", "0") == "1"
	var sim: WindsurferSim = WindsurferSim.create_for(EnvironmentConfig.new(), waves, true)
	var wind: WindConfig = sim.wind_config
	wind.speed_kt = wind_kt
	wind.from_bearing_deg = WIND_FROM_DEG
	wind.gusts_enabled = _options.get("gusts", "0") == "1"
	wind.shifts_enabled = false
	sim.wind = WindField.new(wind)
	return sim


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


## The per-tick trace of one case (--trace=1), or null.
func _open_trace(wind_kt: float, direction_name: String) -> FileAccess:
	if _options.get("trace", "0") != "1" or not _options.has("out"):
		return null
	var path: String = "%s/trace_%d_%s.csv" % [_options["out"].get_base_dir(), int(wind_kt), direction_name.replace(" ", "_")]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return null
	file.store_line("t,turned_deg,yaw_right_dps,wanted_dps,helm_right,trim_up,rake,rig_tilt,lean,legs,speed_ms,heel_deg,wanted_bank_deg,"
		+ "sheet,alpha_deg,awa_deg,aws_kt,twa_deg,fin_slip_deg,fin_lift_n,fin_stalled,leeway_deg,yaw_fin_nm,yaw_rig_nm,yaw_sailor_nm,"
		+ "yaw_water_nm,yaw_net_nm,back_foot_yaw_nm,rail_yaw_nm,stance,hike,drive_n,side_force_n,planing_ratio,wet_front_m,depower,rig_lean_deg,felt_heel_deg,felt_push_ms2,feet_excess_nm,hand_force_n,harness_n")
	return file


func _trace_row(file: FileAccess, t: Telemetry, controller: PlayerController, controls: SimControls, heading0: float, direction: float) -> void:
	var turned: float = wrapf(t.heading_deg - heading0, -180.0, 180.0) * direction
	var values: Array[float] = [t.time_s, turned, -t.yaw_rate_dps, controller.wanted_rate_dps, controller.helm_right,
		controller._helm_trim_up, t.rake, t.rig_tilt, controls.lean, controls.back_foot_push, t.speed_ms, t.heel_deg, t.wanted_bank_deg,
		t.sheet, t.alpha_deg, t.awa_deg, t.aws_kt, t.twa_deg, t.fin_slip_deg, t.fin_lift_n, 1.0 if t.fin_stalled else 0.0, t.leeway_deg,
		t.yaw_fin_nm, t.yaw_rig_nm, t.yaw_sailor_nm, t.yaw_water_nm, t.yaw_net_nm, t.back_foot_yaw_nm, t.rail_yaw_nm, t.stance, t.lean,
		t.drive_n, t.side_force_n, t.planing_ratio, t.wet_front_m, controller.auto_sheet_pilot._depower, t.rig_lean_deg,
		t.felt_heel_deg, t.felt_push_ms2, t.feet_moment_excess_nm, t.hand_force_n, t.harness_tension_n]
	var parts: PackedStringArray = PackedStringArray()
	for v: float in values:
		parts.append("%.4f" % v)
	file.store_line(",".join(parts))


func _time_text(seconds: float) -> String:
	return "%5.2f" % seconds if seconds >= 0.0 else "   - "


func _format(r: SteerResult) -> String:
	return "%3.0f   %-9s  %5.2f  %s  %s  %5.2f   %5.1f   %5.1f   %5.2f  %4.2f  %4.2f  %5.1f  %5.2f  %4.2f  %s" % [
		r.wind_kt, r.direction, r.speed_start_ms, _time_text(r.time_to_30_s), _time_text(r.time_to_60_s), r.speed_at_30_ms,
		r.peak_yaw_dps, r.turned_deg, r.rake_mean, r.legs_mean, r.rig_move_mean, r.yaw_at_1s_dps, r.speed_min_ms if r.samples > 0 else 0.0,
		r.depower_max, ("FELL (%s, %.1f s)" % [r.fall_kind, r.fall_after_s]) if r.fell else "ok"]


func _csv_header() -> String:
	return "label,wind_kt,direction,speed_start_ms,time_to_30_s,time_to_60_s,speed_at_30_ms,peak_yaw_dps,turned_deg,rake_mean,legs_mean,rig_move_mean,yaw_at_1s_dps,speed_min_ms,depower_max,fell"


func _csv_row(r: SteerResult) -> String:
	return ",".join(PackedStringArray([_options.get("label", ""), str(r.wind_kt), r.direction, "%.3f" % r.speed_start_ms,
		"%.3f" % r.time_to_30_s, "%.3f" % r.time_to_60_s, "%.3f" % r.speed_at_30_ms, "%.2f" % r.peak_yaw_dps,
		"%.2f" % r.turned_deg, "%.3f" % r.rake_mean, "%.3f" % r.legs_mean, "%.3f" % r.rig_move_mean, "%.2f" % r.yaw_at_1s_dps,
		"%.3f" % (r.speed_min_ms if r.samples > 0 else 0.0), "%.3f" % r.depower_max, "1" if r.fell else "0"]))


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
