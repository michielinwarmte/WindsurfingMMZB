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
## [--controller.<field>=<n>] [--out=<csv>] [--label=<text>]

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
	var rake_mean: float = 0.0
	var legs_mean: float = 0.0
	var samples: int = 0


func _initialize() -> void:
	_options = _read_user_args()
	var winds: PackedFloat64Array = _number_list(_options.get("winds", "12,18,24"))
	print("steering check: TWA %s, from %s s, the stick over for %s s; legs %s, push %s; waves %s, gusts %s" % [
		_options.get("twa", "100"), _options.get("from", "40"), _options.get("hold", "8"), _options.get("legs", "0"),
		_options.get("push", "-"), _options.get("waves", "0"), _options.get("gusts", "0")])
	print("wind  turn        v0     t30    t60    v30   peakYaw  turned  rake   legs  fell")
	for wind_kt: float in winds:
		for direction: float in [1.0, -1.0]:
			var r: SteerResult = _run_case(wind_kt, direction)
			print(_format(r))
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
	var t_over: float = 0.0
	var steps: int = int((from_s + hold_s) / DT)
	# The pilot's numbers through the controller's overrides, applied after the slider every
	# update (written straight onto the pilot they would be overwritten by --push).
	for key: String in fixed:
		if key.begins_with("pilot."):
			controller.pilot_overrides[key.trim_prefix("pilot.")] = fixed[key]
	for i: int in steps:
		var t: Telemetry = sim.telemetry
		var over: bool = t.time_s >= from_s
		if not over:
			hands.steer = LearnedSkipper.steer_toward_twa(t.twa_deg, 1.0, twa_deg)
		else:
			if r.samples == 0:
				heading0 = t.heading_deg
				t_over = t.time_s
				r.speed_start_ms = t.speed_ms
			hands.steer = direction
		if sim.sailor_state == WindsurferSim.SailorState.SAILING:
			controller.update(t, controls, DT)
		sim.step(DT, controls)
		t = sim.telemetry
		if not over:
			continue
		if sim.sailor_state != WindsurferSim.SailorState.SAILING:
			r.fell = true
			break
		r.samples += 1
		r.rake_mean += t.rake
		r.legs_mean += absf(controls.back_foot_push)
		# A right turn raises the compass heading.
		var turned: float = wrapf(t.heading_deg - heading0, -180.0, 180.0) * direction
		r.turned_deg = maxf(r.turned_deg, turned)
		r.peak_yaw_dps = maxf(r.peak_yaw_dps, absf(t.yaw_rate_dps))
		if r.time_to_30_s < 0.0 and turned >= 30.0:
			r.time_to_30_s = t.time_s - t_over
			r.speed_at_30_ms = t.speed_ms
		if r.time_to_60_s < 0.0 and turned >= 60.0:
			r.time_to_60_s = t.time_s - t_over
			break
	var n: float = float(maxi(r.samples, 1))
	r.rake_mean /= n
	r.legs_mean /= n
	return r


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


func _time_text(seconds: float) -> String:
	return "%5.2f" % seconds if seconds >= 0.0 else "   - "


func _format(r: SteerResult) -> String:
	return "%3.0f   %-9s  %5.2f  %s  %s  %5.2f   %5.1f   %5.1f   %5.2f  %4.2f  %s" % [
		r.wind_kt, r.direction, r.speed_start_ms, _time_text(r.time_to_30_s), _time_text(r.time_to_60_s), r.speed_at_30_ms,
		r.peak_yaw_dps, r.turned_deg, r.rake_mean, r.legs_mean, "FELL" if r.fell else "ok"]


func _csv_header() -> String:
	return "label,wind_kt,direction,speed_start_ms,time_to_30_s,time_to_60_s,speed_at_30_ms,peak_yaw_dps,turned_deg,rake_mean,legs_mean,fell"


func _csv_row(r: SteerResult) -> String:
	return ",".join(PackedStringArray([_options.get("label", ""), str(r.wind_kt), r.direction, "%.3f" % r.speed_start_ms,
		"%.3f" % r.time_to_30_s, "%.3f" % r.time_to_60_s, "%.3f" % r.speed_at_30_ms, "%.2f" % r.peak_yaw_dps,
		"%.2f" % r.turned_deg, "%.3f" % r.rake_mean, "%.3f" % r.legs_mean, "1" if r.fell else "0"]))


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
