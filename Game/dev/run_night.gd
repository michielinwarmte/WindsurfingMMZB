extends SceneTree
## The night of 7 November 2026's scenarios (Documentation/reports/autopilot/night_7nov/README.md):
## the player's beginner controller (PlayerController with the auto-sheet and the heading hold, fed
## by AiHands that press keys the way a player does) on the open water or on Lake Silvaplana, one
## case per process, one line "RESULT {json}" at the end. tools/night_suite.py runs a pool of them
## and scores them; tools/night_tuner.py tunes the controller's numbers with it. Nothing in
## Game/sim/ is changed.
##
## Arguments after "--":
##   --scenario=plane|steer|taps|carve|fly|reflex
##       plane   from rest on a course (--twa), no key: the hold sails it; the time until the board
##               planes for 2 s on end, and the speed made good along the first course
##       steer   below the plane: the heading hold (its error), then a 30 degree turn away and one
##               back up with the key held until the heading has turned 30 degrees (overshoot,
##               settle time, the heel, lean and rake jumps)
##       taps    A/D taps of 0.1, 0.2 and 0.3 s, away and up (the heading change, the jumps)
##       carve   Shift + A/D away for 0.8 s and up for 0.6 s, then the same without Shift (the rate
##               turned, the falls)
##       fly     at speed in waves: falls, the board leaving the water, the speed
##       reflex  gusty reaches: how much of the time the recovery reflex eases, the falls, the speed
##   --map=open|lake  --kt=<the open water's wind>  --twa=<degrees off the wind, starboard tack>
##   --seconds=<n> --from=<s>  --waves=1 --wave_scale=1 --gusts=1 --gust_intensity=0.2 --gust_period=8
##   --lake_wind_scale=<x> --lake_wave_scale=<x> (read by the map's wind and the sim themselves)
##   --push=<0..1> the push slider; --body.side=<n> --body.back=<n> a mouse body held there
##   --pilot.<field>= --controller.<field>= the autopilot's and the controller's numbers

const DT: float = 1.0 / 60.0
const WIND_FROM_DEG: float = 270.0
const LAKE_TIME_S: float = 14.5 * 3600.0
const ENVIRONMENT_PATH: String = "res://maps/silvaplana/environment_silvaplana.tres"
const GRID_PATH: String = "res://maps/silvaplana/terrain/shore_heights.json"
## The lake's middle with at least 300 m of water all round (run_lake.gd).
const LAKE_MIDDLE: Vector3 = Vector3(349.0, 0.0, -89.0)

var _options: Dictionary[String, String] = {}
var _grid: TerrainGrid = null


## One scripted press of the hands: from start_s for duration_s, steer (-1..1; +1 heads up on this
## starboard tack course) and Shift; "return" phases steer back to the case's course instead;
## until_turn_deg > 0 holds the key until the heading has turned that far.
class Press:
	var start_s: float = 0.0
	var duration_s: float = 0.0
	var steer: float = 0.0
	var sharp: bool = false
	var back_to_course: bool = false
	var until_turn_deg: float = 0.0
	var name: String = ""

	func _init(p_name: String, p_start: float, p_duration: float, p_steer: float, p_sharp: bool = false) -> void:
		name = p_name
		start_s = p_start
		duration_s = p_duration
		steer = p_steer
		sharp = p_sharp


## What a press did: measured from its start for watch_s.
class Watch:
	var press: Press = null
	var heading0_deg: float = 0.0
	var heel0_deg: float = 0.0
	var lean0: float = 0.0
	var rake0: float = 0.0
	var turn_deg: float = 0.0
	var turn_max_deg: float = 0.0
	var heel_jump_deg: float = 0.0
	var lean_jump: float = 0.0
	var rake_jump: float = 0.0
	var yaw_peak_dps: float = 0.0
	var released_s: float = -1.0
	var settled_s: float = -1.0
	var calm_s: float = 0.0
	var rate_sum_dps: float = 0.0
	var rate_samples: int = 0
	var fell: bool = false


func _initialize() -> void:
	_options = _read_user_args()
	var result: Dictionary = _run()
	print("RESULT " + JSON.stringify(result))
	quit(0)


func _run() -> Dictionary:
	var scenario: String = _options.get("scenario", "plane")
	var lake: bool = _options.get("map", "open") == "lake"
	var twa_deg: float = _options.get("twa", "100").to_float()
	var sim: WindsurferSim = _make_lake_sim() if lake else _make_open_sim()
	var controller: PlayerController = PlayerController.new()
	var hands: AiHands = AiHands.new()
	controller.hands = hands
	controller.set_sail(sim.sail, sim.sailor_config, sim.air_density_kg_m3)
	if _options.has("push"):
		controller.push_level = _options["push"].to_float()
	hands.push = controller.push_level
	var settings: Dictionary[String, float] = {}
	for key: String in _options:
		if key.contains("."):
			settings[key] = _options[key].to_float()
	_apply(settings, "controller.", controller)
	_put_on_a_body(settings, controller, sim)
	var controls: SimControls = SimControls.new()
	controller.reset_controls(controls)
	var wind_from_deg: float = WIND_FROM_DEG
	var start: Vector3 = Vector3.ZERO
	if lake:
		var environment: EnvironmentConfig = load(ENVIRONMENT_PATH)
		wind_from_deg = environment.map_wind().lake_from_deg(LAKE_TIME_S)
		start = LAKE_MIDDLE
	var heading_deg: float = fposmod(wind_from_deg - twa_deg, 360.0)
	sim.reset(start, deg_to_rad(heading_deg))
	var course: Vector3 = SimMath.dir_from_bearing(deg_to_rad(heading_deg))

	var presses: Array[Press] = _presses(scenario)
	var watches: Array[Watch] = []
	var watch_s: float = 4.0 if scenario == "taps" else 7.0
	var seconds: float = _options.get("seconds", str(_default_seconds(scenario, lake))).to_float()
	var from_s: float = _options.get("from", str(_default_from(scenario, lake))).to_float()
	var r: Dictionary = {"scenario": scenario, "map": "lake" if lake else "open", "kt": _options.get("kt", ""), "twa": twa_deg,
		"falls": 0, "aground": false, "nan": false}
	var previous_state: WindsurferSim.SailorState = sim.sailor_state
	var planing_since_s: float = -1.0
	var plane_s: float = -1.0
	var start_position: Vector3 = sim.telemetry.position
	var measured_from: Vector3 = start_position
	var speed_sum: float = 0.0
	var sailing_ticks: int = 0
	var ticks: int = 0
	var reflex_ticks: int = 0
	var reflex_sum: float = 0.0
	var air_events: int = 0
	var was_light: bool = false
	var hold_error_square: float = 0.0
	var hold_ticks: int = 0
	var elapsed_s: float = 0.0
	for i: int in int(seconds / DT):
		var t: Telemetry = sim.telemetry
		var now_s: float = i * DT
		_hands_for(presses, watches, now_s, t, hands, twa_deg)
		if sim.sailor_state == WindsurferSim.SailorState.SAILING:
			controller.update(t, controls, DT)
		sim.step(DT, controls)
		t = sim.telemetry
		elapsed_s = now_s + DT
		if sim.sailor_state == WindsurferSim.SailorState.SAILING and previous_state == WindsurferSim.SailorState.FALLEN:
			controller.reset_controls(controls)
		var fell_now: bool = sim.sailor_state == WindsurferSim.SailorState.FALLEN and previous_state == WindsurferSim.SailorState.SAILING
		previous_state = sim.sailor_state
		if is_nan(t.speed_ms) or is_nan(t.position.y):
			r["nan"] = true
			break
		if lake and ShoreCheck.is_aground(_grid, t.position, sim.fin_config.span_m):
			r["aground"] = true
			break
		for w: Watch in watches:
			_watch(w, t, now_s, fell_now, watch_s)
		# The time to plane counts from the start.
		if t.is_planing and sim.sailor_state == WindsurferSim.SailorState.SAILING:
			if planing_since_s < 0.0:
				planing_since_s = now_s
			if plane_s < 0.0 and now_s - planing_since_s >= 2.0:
				plane_s = planing_since_s
		else:
			planing_since_s = -1.0
		if now_s < from_s:
			measured_from = t.position
			continue
		ticks += 1
		if fell_now:
			r["falls"] += 1
		if sim.sailor_state != WindsurferSim.SailorState.SAILING:
			continue
		sailing_ticks += 1
		speed_sum += t.speed_ms
		# The reflex at work: the fall it feels coming, after its fade by speed and push.
		var danger: float = maxf(controller.lee_danger, controller.windward_danger)
		reflex_sum += danger
		if danger > 0.02:
			reflex_ticks += 1
		var light: bool = t.buoyancy_n + t.planing_lift_n < 0.3 * t.total_mass_kg * 9.81
		if light and not was_light:
			air_events += 1
		was_light = light
		if controller.held_heading_deg >= 0.0 and absf(controller.wanted_rate_dps) < 25.0 and _no_press_now(presses, now_s):
			var error_deg: float = wrapf(controller.held_heading_deg - t.heading_deg, -180.0, 180.0)
			hold_error_square += error_deg * error_deg
			hold_ticks += 1
	var measured_s: float = maxf(ticks * DT, DT)
	r["seconds"] = snappedf(elapsed_s, 0.01)
	r["measured_s"] = snappedf(measured_s, 0.01)
	r["speed_ms"] = snappedf(speed_sum / maxf(sailing_ticks, 1), 0.001)
	r["made_good_ms"] = snappedf((sim.telemetry.position - measured_from).dot(course) / measured_s, 0.001)
	r["plane_s"] = snappedf(plane_s, 0.01)
	r["reflex_share"] = snappedf(float(reflex_ticks) / maxf(sailing_ticks, 1), 0.0001)
	r["reflex_mean"] = snappedf(reflex_sum / maxf(sailing_ticks, 1), 0.0001)
	r["air_per_min"] = snappedf(air_events * 60.0 / measured_s, 0.01)
	r["hold_rms_deg"] = snappedf(sqrt(hold_error_square / maxf(hold_ticks, 1)), 0.01)
	var presses_out: Array = []
	for w: Watch in watches:
		presses_out.append({"name": w.press.name, "turn_deg": snappedf(w.turn_deg, 0.01), "turn_max_deg": snappedf(w.turn_max_deg, 0.01),
			"heel_jump_deg": snappedf(w.heel_jump_deg, 0.01), "lean_jump": snappedf(w.lean_jump, 0.001), "rake_jump": snappedf(w.rake_jump, 0.001),
			"yaw_peak_dps": snappedf(w.yaw_peak_dps, 0.01), "settle_s": snappedf(w.settled_s - w.released_s if w.settled_s >= 0.0 else -1.0, 0.01),
			"rate_dps": snappedf(w.rate_sum_dps / maxf(w.rate_samples, 1), 0.01), "fell": w.fell})
	r["presses"] = presses_out
	return r


## The scripted presses of each scenario (starboard tack: +1 heads up, -1 bears away). Between the
## presses the hands steer back to the course for 4 s, then let go (the heading hold).
func _presses(scenario: String) -> Array[Press]:
	var list: Array[Press] = []
	match scenario:
		"steer":
			var away: Press = Press.new("turn30_away", 40.0, 8.0, -1.0)
			away.until_turn_deg = 30.0
			list.append(away)
			list.append(_back(56.0))
			var up: Press = Press.new("turn30_up", 64.0, 8.0, 1.0)
			up.until_turn_deg = 30.0
			list.append(up)
		"taps":
			var at_s: float = 30.0
			for tap_s: float in [0.1, 0.2, 0.3]:
				for steer: float in [-1.0, 1.0]:
					list.append(Press.new("tap%.1f_%s" % [tap_s, "away" if steer < 0.0 else "up"], at_s, tap_s, steer))
					list.append(_back(at_s + 4.0))
					at_s += 9.0
		"carve":
			list.append(Press.new("sharp_away", 30.0, 0.8, -1.0, true))
			list.append(_back(37.0))
			list.append(Press.new("sharp_up", 45.0, 0.6, 1.0, true))
			list.append(_back(52.0))
			list.append(Press.new("plain_away", 60.0, 0.8, -1.0))
			list.append(_back(67.0))
			list.append(Press.new("plain_up", 75.0, 0.6, 1.0))
			list.append(_back(82.0))
	return list


func _back(at_s: float) -> Press:
	var p: Press = Press.new("back", at_s, 4.0, 0.0)
	p.back_to_course = true
	return p


## The hands at this moment: a press, a return to the course, or nothing (the hold sails).
func _hands_for(presses: Array[Press], watches: Array[Watch], now_s: float, t: Telemetry, hands: AiHands, twa_deg: float) -> void:
	hands.steer = 0.0
	hands.sharp = false
	for p: Press in presses:
		if now_s < p.start_s or now_s >= p.start_s + p.duration_s:
			continue
		if p.back_to_course:
			hands.steer = LearnedSkipper.steer_toward_twa(t.twa_deg, 1.0, twa_deg)
			return
		var w: Watch = _watch_of(p, watches, t)
		if p.until_turn_deg > 0.0 and absf(w.turn_deg) >= p.until_turn_deg:
			return
		hands.steer = p.steer
		hands.sharp = p.sharp
		return


func _no_press_now(presses: Array[Press], now_s: float) -> bool:
	for p: Press in presses:
		if now_s >= p.start_s and now_s < p.start_s + p.duration_s + 5.0:
			return false
	return true


func _watch_of(p: Press, watches: Array[Watch], t: Telemetry) -> Watch:
	for w: Watch in watches:
		if w.press == p:
			return w
	var w2: Watch = Watch.new()
	w2.press = p
	w2.heading0_deg = t.heading_deg
	w2.heel0_deg = t.heel_deg
	w2.lean0 = t.lean
	w2.rake0 = t.rake
	watches.append(w2)
	return w2


## What a press does: the heading turned (signed toward the press: + = the way it was pressed), the
## largest jumps of heel, lean and rake from where they were, and after the key is let go the time
## until the yaw stays below 5 degrees a second for 1 s.
func _watch(w: Watch, t: Telemetry, now_s: float, fell_now: bool, watch_s: float) -> void:
	var since_s: float = now_s - w.press.start_s
	if since_s > watch_s + w.press.duration_s:
		return
	# Starboard tack: heading up (+1) is a right turn, the heading growing.
	var turned_right_deg: float = wrapf(t.heading_deg - w.heading0_deg, -180.0, 180.0)
	w.turn_deg = turned_right_deg * signf(w.press.steer)
	w.turn_max_deg = maxf(w.turn_max_deg, w.turn_deg)
	w.heel_jump_deg = maxf(w.heel_jump_deg, absf(t.heel_deg - w.heel0_deg))
	w.lean_jump = maxf(w.lean_jump, absf(t.lean - w.lean0))
	w.rake_jump = maxf(w.rake_jump, absf(t.rake - w.rake0))
	w.yaw_peak_dps = maxf(w.yaw_peak_dps, absf(t.yaw_rate_dps))
	w.fell = w.fell or fell_now
	var pressing: bool = since_s < w.press.duration_s and not (w.press.until_turn_deg > 0.0 and w.released_s >= 0.0)
	if w.press.until_turn_deg > 0.0 and w.released_s < 0.0 and absf(w.turn_deg) >= w.press.until_turn_deg:
		pressing = false
	if pressing:
		w.rate_sum_dps += absf(t.yaw_rate_dps)
		w.rate_samples += 1
		return
	if w.released_s < 0.0:
		w.released_s = now_s
	if w.settled_s >= 0.0:
		return
	w.calm_s = w.calm_s + DT if absf(t.yaw_rate_dps) < 5.0 else 0.0
	if w.calm_s >= 1.0:
		w.settled_s = now_s - 1.0


func _default_seconds(scenario: String, lake: bool) -> float:
	if lake:
		return 50.0
	match scenario:
		"plane":
			return 60.0
		"steer":
			return 80.0
		"taps":
			return 85.0
		"carve":
			return 88.0
		"fly":
			return 100.0
	return 90.0


func _default_from(scenario: String, lake: bool) -> float:
	if scenario == "plane":
		return 0.0
	return 15.0 if lake else 25.0


## The game's open water: waves, gusts, the wind's height gradient, no shifts.
func _make_open_sim() -> WindsurferSim:
	var waves: bool = _options.get("waves", "1") == "1"
	var sim: WindsurferSim = WindsurferSim.create_for(EnvironmentConfig.new(), waves, true)
	var wind: WindConfig = sim.wind_config
	wind.speed_kt = _options.get("kt", "18").to_float()
	wind.from_bearing_deg = WIND_FROM_DEG
	wind.gusts_enabled = _options.get("gusts", "1") == "1"
	wind.gust_patches = true
	wind.gust_intensity = _options.get("gust_intensity", "0.2").to_float()
	wind.gust_period_s = _options.get("gust_period", "8").to_float()
	wind.shifts_enabled = false
	sim.wind = WindField.new(wind)
	var wave_scale: float = _options.get("wave_scale", "1").to_float()
	if waves and wave_scale != 1.0 and sim.wave_set_config != null:
		for wave: GerstnerWaveConfig in sim.wave_set_config.waves:
			wave.amplitude_m *= wave_scale
			wave.steepness = minf(wave.steepness * wave_scale, 1.0)
		sim.set_waves(true)
	return sim


## Lake Silvaplana at 14:30 in the map's wind on its own waves (run_lake.gd --lake_waves=1).
func _make_lake_sim() -> WindsurferSim:
	_grid = TerrainGrid.load_from(GRID_PATH)
	var environment: EnvironmentConfig = (load(ENVIRONMENT_PATH) as EnvironmentConfig).duplicate() as EnvironmentConfig
	environment.lake_waves = environment.lake_waves.duplicate()
	environment.start_hour = LAKE_TIME_S / 3600.0
	var sim: WindsurferSim = WindsurferSim.create_for(environment)
	(sim.wind as MapWindField).set_time_of_day(LAKE_TIME_S)
	sim.wave_set_config = sim.wave_set_config.duplicate(true)
	sim.wave_set_config.place_waves = true
	sim.set_waves(true)
	return sim


func _put_on_a_body(settings: Dictionary[String, float], controller: PlayerController, sim: WindsurferSim) -> void:
	var wanted: bool = false
	for key: String in settings:
		wanted = wanted or key.begins_with("body.")
	if not wanted:
		return
	var body: MouseBody = MouseBody.new()
	body.scripted = true
	body.sideways = MouseBody.Sideways.RIGHT_IS_MORE_RAIL
	_apply(settings, "body.", body)
	controller.body = body
	sim.sailor_config.lean_feel_time_s = body.feel_time_s(sim.sailor_config.lean_feel_time_s)


## Sets every "<prefix>field" on the target; the pilot's go through the controller's overrides.
func _apply(settings: Dictionary[String, float], prefix: String, target: Object) -> void:
	for key: String in settings:
		if key.begins_with("pilot.") and target is PlayerController:
			(target as PlayerController).pilot_overrides[key.trim_prefix("pilot.")] = settings[key]
			continue
		if not key.begins_with(prefix):
			continue
		var field: String = key.trim_prefix(prefix)
		if not (field in target):
			push_error("No field '%s' to set." % key)
			continue
		var current: Variant = target.get(field)
		var value: float = settings[key]
		target.set(field, (value != 0.0) if current is bool else (int(value) if current is int else value))


func _read_user_args() -> Dictionary[String, String]:
	var options: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
			options[parts[0]] = parts[1]
	return options
