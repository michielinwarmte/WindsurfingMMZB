extends SceneTree
## The lake-speed suite's harness (Documentation/reports/autopilot/lake_speed/README.md; Max, 7
## November 2026): the player's beginner controller (PlayerController with the auto-sheet and the
## heading hold, the push at 75 %, the night-tuned steering on: the player's board as the autopilot
## drives it) on Lake Silvaplana in the Maloja afternoon's wind on the lake's full waves, on a gear
## combo from the catalogue. One case per process, one line "RESULT {json}" at the end, and a CSV of
## where the board sailed and the wind it had there. tools/lake_suite.py runs a pool of them and
## scores them; tools/lake_tuner.py tunes the controller's numbers with it. Nothing in Game/sim/ is
## changed.
##
## Arguments after "--":
##   --scenario=start|strong|reach
##       start   from rest, the lake's own wind (x1.0): the time to plane, and the balance in the
##               first 30 s (the sailor's lean, the board's heel and pitch swings), the falls
##       strong  from rest in a strong wind (--lake_wind_scale=1.3): the nose dives below the plane
##               (the bow buried: Telemetry.bow_immersion_m, or the nose pitched down), the falls
##       reach   a beam or broad reach (--twa) from rest, measured from --from on: the speed in the
##               gusts (the 90th percentile, and the mean while the wind at the board is in its top
##               quarter), the mean, the waves' control (pitch rate SD, the board in the air), falls
##   --gear=small|medium|big (the three combos below) or --board=<id> --sail=<id> --fin_cm=<depth>
##   --place=camping|between|middle|south or --x=<game x> --z=<game z>: the run passes through it
##   --hour=<13.0..16.0> the time of day (the map's wind of that hour)
##   --twa=<degrees off the wind> --tack=starboard|port --seconds=<n> --from=<s>
##   --lake_wind_scale=<x> --lake_wave_scale=<x> (read by the map's wind and the sim themselves)
##   --push=<0..1> (0.75) --night_tuning=1|0 (1: PlayerController.NIGHT_TUNING on, as the game's default)
##   --csv=<path> where the track goes (time, place, the wind at the board, the speed)
##   --pilot.<field>= --controller.<field>= the autopilot's and the controller's numbers

const DT: float = 1.0 / 60.0
const ENVIRONMENT_PATH: String = "res://maps/silvaplana/environment_silvaplana.tres"
const MAP_CONFIG_PATH: String = "res://maps/silvaplana/map_config.tres"
const GRID_PATH: String = "res://maps/silvaplana/terrain/shore_heights.json"
## The lake scene's start, 40 m off the camping beach (SilvaplanaSailing.START_LV95), and the lake's
## middle with at least 300 m of water all round (run_lake.gd). "between" is halfway; "south" is the
## middle moved 300 m toward Maloja along the wind (the upwind half of the sailed water).
const CAMPING_LV95: Vector2 = Vector2(2780880.0, 1147510.0)
const MIDDLE: Vector3 = Vector3(349.0, 0.0, -89.0)
## The gear combos (Max: a medium to big board with a 7 to 8 m sail; a smaller sail with the smaller
## board, the fin the catalogue recommends for the board's width).
const GEAR: Dictionary[String, PackedStringArray] = {
	"small": ["pj_new_sealand_freerace_111", "savanna_freerace_7_0"],
	"medium": ["pj_new_sealand_slalom_117", "savanna_slalom_7_5"],
	"big": ["moonboard_slalom_129", "savanna_slalom_8_0"],
}
## How far ahead each scenario wants open water (m).
const ROOM_WANTED_M: Dictionary[String, float] = {"start": 450.0, "strong": 350.0, "reach": 1400.0}
const BALANCE_WINDOW_S: float = 30.0
var CSV_EVERY_S: float = 0.5

var _options: Dictionary[String, String] = {}
## --forces=1: the CSV also has the apparent wind, the sheet and the forces along the board.
var _forces: bool = false
var _grid: TerrainGrid = null
var _map: MapConfig = null


func _initialize() -> void:
	_options = _read_user_args()
	var result: Dictionary = _run()
	print("RESULT " + JSON.stringify(result))
	quit(0)


func _run() -> Dictionary:
	var scenario: String = _options.get("scenario", "reach")
	var hour: float = _options.get("hour", "14.5").to_float()
	var twa_deg: float = _options.get("twa", "100").to_float()
	var tack: float = -1.0 if _options.get("tack", "starboard") == "port" else 1.0
	_grid = TerrainGrid.load_from(GRID_PATH)
	_map = load(MAP_CONFIG_PATH)
	var gear: GearChoice = _gear()
	var sim: WindsurferSim = gear.sim_with(_make_lake_sim(hour))
	# The references (not scored): the same lake without its waves, or in sea-level air.
	if _options.get("waves", "1") == "0":
		sim.set_waves(false)
	if _options.has("air"):
		sim.air_density_kg_m3 = _options["air"].to_float()
	var controller: PlayerController = PlayerController.new()
	var hands: AiHands = AiHands.new()
	controller.hands = hands
	controller.set_sail(sim.sail, sim.sailor_config, sim.air_density_kg_m3)
	if _options.get("night_tuning", "1") == "1":
		controller.use_night_tuning(true)
	controller.push_level = _options.get("push", "0.75").to_float()
	hands.push = controller.push_level
	var settings: Dictionary[String, float] = {}
	for key: String in _options:
		if key.contains("."):
			settings[key] = _options[key].to_float()
	_apply(settings, controller)
	var controls: SimControls = SimControls.new()
	controller.reset_controls(controls)

	var environment: EnvironmentConfig = load(ENVIRONMENT_PATH)
	var wind_from_deg: float = environment.map_wind().lake_from_deg(hour * 3600.0)
	# Starboard tack: the wind from the right, the heading the wind's bearing minus the angle.
	var heading_deg: float = fposmod(wind_from_deg - tack * twa_deg, 360.0)
	var course: Vector3 = SimMath.dir_from_bearing(deg_to_rad(heading_deg))
	var place: Vector3 = _place()
	var start: Vector3 = _start_for(place, course, ROOM_WANTED_M.get(scenario, 800.0), sim.fin_config.span_m)
	# A reach first, then bearing away (Max, 7 November 2026: "the apparent wind will keep the push"):
	# --twa_start=<deg> the start's heading, --bear_away_at=<s> when the hands turn to --twa (at
	# --bear_away_steer of the key, 1 the full key); the room and made good are along --twa's course.
	var start_twa_deg: float = _options.get("twa_start", str(twa_deg)).to_float()
	var start_heading_deg: float = fposmod(wind_from_deg - tack * start_twa_deg, 360.0)
	var bear_away_at_s: float = _options.get("bear_away_at", "-1").to_float()
	var bear_away_steer: float = _options.get("bear_away_steer", "1").to_float()
	var bore_away: bool = bear_away_at_s < 0.0
	_forces = _options.get("forces", "0") == "1"
	CSV_EVERY_S = _options.get("csv_every", "0.5").to_float()
	sim.reset(start, deg_to_rad(start_heading_deg))

	var seconds: float = _options.get("seconds", str(_default_seconds(scenario))).to_float()
	var from_s: float = _options.get("from", str(_default_from(scenario))).to_float()
	var r: Dictionary = {"scenario": scenario, "gear": gear.ids_text(), "hour": hour, "twa": twa_deg,
		"wind_scale": _options.get("lake_wind_scale", "1.0"), "falls": 0, "aground": false, "nan": false}
	var csv: FileAccess = _open_csv()
	var previous_state: WindsurferSim.SailorState = sim.sailor_state
	var planing_since_s: float = -1.0
	var plane_s: float = -1.0
	var speeds: PackedFloat64Array = []
	var winds: PackedFloat64Array = []
	var wind_all: PackedFloat64Array = []
	var twa_sum: float = 0.0
	var pitch_rates: PackedFloat64Array = []
	var balance: Dictionary[String, PackedFloat64Array] = {"heel": [], "pitch": [], "lean": [], "lean_rate": []}
	var last_lean: float = 0.0
	var air_events: int = 0
	var was_light: bool = false
	var dives: int = 0
	var dive_armed: bool = true
	var buried_s: float = 0.0
	var pitch_min_deg: float = 0.0
	var bow_max_m: float = 0.0
	var measured_from: Vector3 = start
	var ticks: int = 0
	var elapsed_s: float = 0.0
	var next_csv_s: float = 0.0
	var dive_bow_m: float = _options.get("dive_bow_m", "0.12").to_float()
	var dive_pitch_deg: float = _options.get("dive_pitch_deg", "-6").to_float()
	var dive_below_ms: float = _options.get("dive_below_ms", "8").to_float()
	var plane_ms: float = _options.get("plane_ms", "7.5").to_float()
	var map_wind: MapWindField = sim.wind as MapWindField
	var local_kt: float = 0.0
	var local_from_deg: float = 0.0
	for i: int in int(seconds / DT):
		var now_s: float = i * DT
		var t: Telemetry = sim.telemetry
		hands.steer = 0.0
		if not bore_away and now_s >= bear_away_at_s:
			# A right turn (positive steer) increases the heading.
			var still_deg: float = wrapf(heading_deg - t.heading_deg, -180.0, 180.0)
			if absf(still_deg) > 2.0:
				hands.steer = bear_away_steer * signf(still_deg)
			else:
				bore_away = true
		if sim.sailor_state == WindsurferSim.SailorState.SAILING:
			controller.update(t, controls, DT)
		sim.step(DT, controls)
		t = sim.telemetry
		elapsed_s = now_s + DT
		if sim.sailor_state == WindsurferSim.SailorState.SAILING and previous_state == WindsurferSim.SailorState.FALLEN:
			controller.reset_controls(controls)
		var fell_now: bool = sim.sailor_state == WindsurferSim.SailorState.FALLEN and previous_state == WindsurferSim.SailorState.SAILING
		previous_state = sim.sailor_state
		# The wind at the board: the map's wind at 10 m above the board's spot, with its gusts.
		var local: Vector3 = map_wind.velocity_at(Vector3(t.position.x, 10.0, t.position.z))
		local_kt = Vector2(local.x, local.z).length() / SimMath.KNOT_MS
		local_from_deg = fposmod(rad_to_deg(atan2(-local.x, local.z)), 360.0)
		if is_nan(t.speed_ms) or is_nan(t.position.y):
			r["nan"] = true
			break
		if ShoreCheck.is_aground(_grid, t.position, sim.fin_config.span_m):
			r["aground"] = true
			break
		if csv != null and now_s >= next_csv_s:
			_csv_row(csv, t, now_s, sim.sailor_state, local_kt, local_from_deg)
			next_csv_s += CSV_EVERY_S
		if fell_now:
			r["falls"] += 1
		var sailing: bool = sim.sailor_state == WindsurferSim.SailorState.SAILING
		# Planing: the speed held above plane_ms for 2 s on end (the hull's own flag flickers in chop).
		if t.speed_ms >= plane_ms and sailing:
			if planing_since_s < 0.0:
				planing_since_s = now_s
			if plane_s < 0.0 and now_s - planing_since_s >= 2.0:
				plane_s = planing_since_s
		else:
			planing_since_s = -1.0
		if not sailing:
			continue
		# The balance getting going: the first 30 s from rest.
		if now_s < BALANCE_WINDOW_S:
			balance["heel"].append(t.heel_deg)
			balance["pitch"].append(t.pitch_deg)
			balance["lean"].append(t.lean)
			balance["lean_rate"].append((t.lean - last_lean) / DT if i > 0 else 0.0)
		last_lean = t.lean
		# A nose dive: below the plane, the bow buried or the nose pitched down (1 s apart at least).
		if t.speed_ms < dive_below_ms:
			var buried: bool = t.bow_immersion_m > dive_bow_m or t.pitch_deg < dive_pitch_deg
			if buried:
				buried_s += DT
				if dive_armed:
					dives += 1
					dive_armed = false
			elif t.bow_immersion_m < 0.5 * dive_bow_m and t.pitch_deg > 0.5 * dive_pitch_deg:
				dive_armed = true
			pitch_min_deg = minf(pitch_min_deg, t.pitch_deg)
			bow_max_m = maxf(bow_max_m, t.bow_immersion_m)
		if now_s < from_s:
			measured_from = t.position
			continue
		ticks += 1
		speeds.append(t.speed_ms)
		winds.append(local_kt)
		twa_sum += absf(t.twa_deg)
		pitch_rates.append(t.pitch_rate_dps)
		var light: bool = t.buoyancy_n + t.planing_lift_n < 0.3 * t.total_mass_kg * 9.81
		if light and not was_light:
			air_events += 1
		was_light = light
	if csv != null:
		csv.close()
	var measured_s: float = maxf(ticks * DT, DT)
	r["seconds"] = snappedf(elapsed_s, 0.01)
	r["measured_s"] = snappedf(measured_s, 0.01)
	r["plane_s"] = snappedf(plane_s, 0.01)
	r["speed_kmh"] = snappedf(_mean(speeds) * 3.6, 0.01)
	r["p90_kmh"] = snappedf(_percentile(speeds, 0.9) * 3.6, 0.01)
	r["max_kmh"] = snappedf(_percentile(speeds, 1.0) * 3.6, 0.01)
	r["gust_kmh"] = snappedf(_mean_where_top(speeds, winds, 0.75) * 3.6, 0.01)
	r["made_good_kmh"] = snappedf((sim.telemetry.position - measured_from).dot(course) / measured_s * 3.6, 0.01)
	r["twa_mean_deg"] = snappedf(twa_sum / maxf(ticks, 1), 0.1)
	r["pitch_rate_sd"] = snappedf(_sd(pitch_rates), 0.01)
	r["air_per_min"] = snappedf(air_events * 60.0 / measured_s, 0.01)
	r["heel_sd"] = snappedf(_sd(balance["heel"]), 0.01)
	r["pitch_sd"] = snappedf(_sd(balance["pitch"]), 0.01)
	r["lean_sd"] = snappedf(_sd(balance["lean"]), 0.001)
	r["lean_rate_rms"] = snappedf(sqrt(_mean_square(balance["lean_rate"])), 0.001)
	r["dives"] = dives
	r["buried_s"] = snappedf(buried_s, 0.01)
	r["pitch_min_deg"] = snappedf(pitch_min_deg, 0.01)
	r["bow_max_m"] = snappedf(bow_max_m, 0.001)
	# Where it sailed and the wind it had there.
	var start_lv95: PackedFloat64Array = _map.game_to_lv95(start)
	var end_lv95: PackedFloat64Array = _map.game_to_lv95(sim.telemetry.position)
	r["start_xz"] = [snappedf(start.x, 0.1), snappedf(start.z, 0.1)]
	r["start_lv95"] = [snappedf(start_lv95[0], 1.0), snappedf(start_lv95[1], 1.0)]
	r["end_lv95"] = [snappedf(end_lv95[0], 1.0), snappedf(end_lv95[1], 1.0)]
	r["heading_deg"] = snappedf(heading_deg, 0.1)
	r["lake_wind_from_deg"] = snappedf(wind_from_deg, 0.1)
	r["lake_mean_kt"] = snappedf(sim.telemetry.tws_10m_kt, 0.01)
	r["wind_mean_kt"] = snappedf(_mean(winds), 0.01)
	r["wind_p75_kt"] = snappedf(_percentile(winds, 0.75), 0.01)
	r["wind_p90_kt"] = snappedf(_percentile(winds, 0.9), 0.01)
	r["wind_max_kt"] = snappedf(_percentile(winds, 1.0), 0.01)
	return r


func _gear() -> GearChoice:
	var ids: PackedStringArray = GEAR.get(_options.get("gear", "medium"), GEAR["medium"])
	var board_id: String = _options.get("board", ids[0])
	var sail_id: String = _options.get("sail", ids[1])
	var choice: GearChoice = GearChoice.from_ids(board_id, sail_id, GearCatalogue.DEFAULT_FIN_ID)
	var board: BoardConfig = choice.board.config as BoardConfig
	var depth_cm: int = _options.get("fin_cm", str(GearCatalogue.FIN_SIZES.recommended_depth_cm(board.width_m))).to_int()
	var fin: GearItem = GearCatalogue.fin_of(choice.board.brand.slug, depth_cm)
	if fin == null:
		# A brand without fins of its own: the default fin's brand at that depth.
		fin = GearCatalogue.fin_of(GearCatalogue.default_fin().brand.slug, depth_cm)
	if fin != null:
		choice.fin = fin
	return choice


func _place() -> Vector3:
	if _options.has("x") and _options.has("z"):
		return Vector3(_options["x"].to_float(), 0.0, _options["z"].to_float())
	var camping: Vector3 = _map.lv95_to_game(CAMPING_LV95.x, CAMPING_LV95.y, _map.lake_level_m)
	camping.y = 0.0
	match _options.get("place", "middle"):
		"camping":
			return camping
		"between":
			return (camping + MIDDLE) * 0.5
		"south":
			# 300 m from the middle toward Maloja (south-west, where the wind comes from).
			return MIDDLE + Vector3(-212.0, 0.0, 212.0)
	return MIDDLE


## Where the run starts: at the place, or set back along the course so there is room_wanted_m of
## water ahead (as far as the lake allows, keeping 40 m off the shore behind).
func _start_for(place: Vector3, course: Vector3, room_wanted_m: float, fin_m: float) -> Vector3:
	var ahead_m: float = _room(place, course, fin_m)
	var behind_m: float = _room(place, -course, fin_m)
	var wanted_m: float = minf(room_wanted_m, ahead_m + behind_m - 80.0)
	var back_m: float = clampf(wanted_m - ahead_m, 0.0, maxf(behind_m - 40.0, 0.0))
	return place - course * back_m


func _room(from: Vector3, direction: Vector3, fin_m: float) -> float:
	var room_m: float = 0.0
	while room_m < 2500.0 and not ShoreCheck.is_aground(_grid, from + direction * (room_m + 10.0), fin_m + 0.5):
		room_m += 10.0
	return room_m


## Lake Silvaplana at that hour in the map's wind on its own full waves (run_night.gd's lake).
func _make_lake_sim(hour: float) -> WindsurferSim:
	var environment: EnvironmentConfig = (load(ENVIRONMENT_PATH) as EnvironmentConfig).duplicate() as EnvironmentConfig
	environment.lake_waves = environment.lake_waves.duplicate()
	environment.start_hour = hour
	var sim: WindsurferSim = WindsurferSim.create_for(environment)
	(sim.wind as MapWindField).set_time_of_day(hour * 3600.0)
	sim.wave_set_config = sim.wave_set_config.duplicate(true)
	sim.wave_set_config.place_waves = true
	sim.set_waves(true)
	return sim


func _open_csv() -> FileAccess:
	var path: String = _options.get("csv", "")
	if path == "":
		return null
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return null
	file.store_line("time_s,x,z,east_lv95,north_lv95,wind_kt,wind_from_deg,wind_at_sail_kt,twa_deg,speed_kmh,heading_deg,pitch_deg,heel_deg,bow_immersion_m,planing,state"
		+ (",aws_kt,awa_deg,sheet,alpha_deg,drive_n,sail_drag_n,hull_resistance_n,fin_drag_n,bow_drag_n,fin_up_n,fin_tilt_deg,mast_foot_up_n,pitch_mast_foot_nm,pitch_feet_force_nm,pitch_feet_moment_nm,buoyancy_n,planing_lift_n,push_centre_m,wet_front_m" if _forces else ""))
	return file


func _csv_row(file: FileAccess, t: Telemetry, now_s: float, state: int, wind_kt: float, wind_from_deg: float) -> void:
	var lv95: PackedFloat64Array = _map.game_to_lv95(t.position)
	file.store_line("%.1f,%.1f,%.1f,%.0f,%.0f,%.2f,%.1f,%.2f,%.1f,%.2f,%.1f,%.2f,%.2f,%.3f,%d,%d" % [now_s, t.position.x, t.position.z,
		lv95[0], lv95[1], wind_kt, wind_from_deg, t.tws_at_sail_kt, t.twa_deg, t.speed_kmh, t.heading_deg,
		t.pitch_deg, t.heel_deg, t.bow_immersion_m, 1 if t.is_planing else 0, state]
		+ (",%.2f,%.1f,%.3f,%.1f,%.0f,%.0f,%.0f,%.0f,%.0f,%.0f,%.1f,%.0f,%.0f,%.0f,%.0f,%.0f,%.0f,%.3f,%.3f" % [t.aws_kt, t.awa_deg, t.sheet, t.alpha_deg, t.drive_n,
			t.sail_drag_n, t.hull_resistance_n, t.fin_drag_n, t.bow_drag_n, t.fin_up_n, t.fin_tilt_deg, t.mast_foot_force_up_n,
			t.pitch_from_mast_foot_nm, t.pitch_from_feet_force_nm, t.pitch_from_feet_moment_nm, t.buoyancy_n, t.planing_lift_n, t.push_centre_m, t.wet_front_m] if _forces else ""))


func _default_seconds(scenario: String) -> float:
	match scenario:
		"start":
			return 45.0
		"strong":
			return 35.0
	return 75.0


func _default_from(scenario: String) -> float:
	return 20.0 if scenario == "reach" else 0.0


func _mean(values: PackedFloat64Array) -> float:
	var total: float = 0.0
	for v: float in values:
		total += v
	return total / maxf(values.size(), 1)


func _mean_square(values: PackedFloat64Array) -> float:
	var total: float = 0.0
	for v: float in values:
		total += v * v
	return total / maxf(values.size(), 1)


func _sd(values: PackedFloat64Array) -> float:
	var mean: float = _mean(values)
	return sqrt(maxf(_mean_square(values) - mean * mean, 0.0))


func _percentile(values: PackedFloat64Array, share: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: PackedFloat64Array = values.duplicate()
	sorted.sort()
	return sorted[clampi(int(share * (sorted.size() - 1)), 0, sorted.size() - 1)]


## The mean of values while the matching key (the wind at the board) is at or above its share's percentile.
func _mean_where_top(values: PackedFloat64Array, keys: PackedFloat64Array, share: float) -> float:
	if values.is_empty():
		return 0.0
	var line: float = _percentile(keys, share)
	var total: float = 0.0
	var count: int = 0
	for i: int in values.size():
		if keys[i] >= line:
			total += values[i]
			count += 1
	return total / maxf(count, 1)


## Sets every "controller.<field>" on the controller; the pilot's go through its overrides.
func _apply(settings: Dictionary[String, float], controller: PlayerController) -> void:
	for key: String in settings:
		if key.begins_with("pilot."):
			controller.pilot_overrides[key.trim_prefix("pilot.")] = settings[key]
			continue
		if not key.begins_with("controller."):
			continue
		var field: String = key.trim_prefix("controller.")
		if not (field in controller):
			push_error("No field '%s' to set." % key)
			continue
		var current: Variant = controller.get(field)
		var value: float = settings[key]
		controller.set(field, (value != 0.0) if current is bool else (int(value) if current is int else value))


func _read_user_args() -> Dictionary[String, String]:
	var options: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
			options[parts[0]] = parts[1]
	return options
