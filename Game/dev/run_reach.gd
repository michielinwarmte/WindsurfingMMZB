extends SceneTree
## The reach check of U1 (PLAYTEST_UPGRADES.md, execution brief): the beam-reach scenario on
## flat water in a steady wind, 40 s per case, at 12, 18 and 24 kt and at true wind angles
## of 60, 100 and 135 degrees, all in one Godot process. It prints one line per case with
## the means over the last 15 s (t >= 25 s). Use tools/reach_check.sh.
##
## Each case is set up the way `tools/simulate.sh beam_reach 40 --wind_kt=<W> --twa=<A>
## --steady=1 --gradient=0` sets it up (run_scenario.gd), so the numbers are the same.
## One difference: a --board.<field> override is applied before the simulation is built,
## so the buoyancy grid sees it too (simulate.sh changes it afterwards, when the grid
## already has its shape). That also makes --board.length_samples=<n> work: the grid check.
##
## Arguments after "--": [--winds=12,18,24] [--twas=60,100,135] [--seconds=40] [--from=25]
## [--out_dir=<absolute dir>: write each case's CSV there, one row per 0.1 s]
## [--pilot.<field>=<n> --sailor.<field>=<n> --sail.<field>=<n> --board.<field>=<n>]

const DT: float = 1.0 / 60.0
const CSV_EVERY_STEPS: int = 6

var _options: Dictionary[String, String] = {}


## The numbers the brief's table asks for, averaged over the window.
class CaseResult:
	var wind_kt: float = 0.0
	var twa_deg: float = 0.0
	var fell: bool = false
	var nan: bool = false
	var count: int = 0
	var speed_ms: float = 0.0
	var planing_ratio: float = 0.0
	var wet_front_m: float = 0.0
	var wet_length_m: float = 0.0
	var push_centre_m: float = 0.0
	var trim_deg: float = 0.0
	var pitch_sd_deg: float = 0.0
	var harness_n: float = 0.0
	var rig_share: float = 0.0
	var mast_foot_down_n: float = 0.0
	var friction_n: float = 0.0
	var drive_n: float = 0.0
	var friction_area_m2: float = 0.0


func _initialize() -> void:
	_options = _read_user_args()
	var winds: PackedFloat64Array = _number_list(_options.get("winds", "12,18,24"))
	var twas: PackedFloat64Array = _number_list(_options.get("twas", "60,100,135"))
	var seconds: float = _options.get("seconds", "40").to_float()
	var from_s: float = _options.get("from", "25").to_float()
	var overrides: PackedStringArray = PackedStringArray()
	for key: String in _options:
		if key.contains("."):
			overrides.append("%s=%s" % [key, _options[key]])
	print("Reach check: beam_reach scenario, flat water, steady wind, %.0f s per case, means over t >= %.0f s%s" % [seconds, from_s, ("; overrides " + ", ".join(overrides)) if not overrides.is_empty() else ""])
	print("wind  TWA   speed m/s (kt)  plan  front  wet   push  trim  pitchSD  harness  rig%  mast   fric  drive  area   fell/NaN")
	var bad: bool = false
	for wind_kt: float in winds:
		for twa_deg: float in twas:
			var result: CaseResult = _run_case(wind_kt, twa_deg, seconds, from_s)
			print(_format(result))
			bad = bad or result.fell or result.nan
	print("Columns: front = front of the wet part from the tail (m), wet = wet length (m), push = centre of the water's push from the tail (m), trim (deg), pitchSD = steadiness (deg), harness = harness tension (N), rig% = the rig's share of the sailor's weight, mast = mast foot pushing down (N), fric/drive (N), area = the area the friction acts on (m2).")
	quit(1 if bad else 0)


## One case, set up as run_scenario.gd sets up `beam_reach --steady=1 --gradient=0`.
func _run_case(wind_kt: float, twa_deg: float, seconds: float, from_s: float) -> CaseResult:
	var scenario: SimScenario = (load("res://dev/scenarios/beam_reach.gd") as GDScript).new()
	scenario.seconds = seconds
	scenario.wind_kt = wind_kt
	scenario.pilot.target_twa_deg = twa_deg

	var sim: WindsurferSim = _make_sim()
	sim.wind_config = sim.wind_config.duplicate()
	sim.wind_config.speed_kt = scenario.wind_kt
	sim.wind = WindField.new(sim.wind_config)
	scenario.pilot.sail = sim.sail
	scenario.pilot.sailor = sim.sailor_config
	_apply_overrides({"pilot": scenario.pilot, "sailor": sim.sailor_config, "sail": sim.sail_config})
	# --steady=1 --gradient=0: the validation suite's wind (no gradient, gusts or shifts).
	sim.wind_config.height_gradient_enabled = false
	sim.wind_config.gusts_enabled = false
	sim.wind_config.shifts_enabled = false
	sim.wind = WindField.new(sim.wind_config)
	sim.set_waves(false)
	sim.reset(Vector3.ZERO, deg_to_rad(scenario.start_heading_deg))
	scenario.setup(sim)

	var file: FileAccess = _open_csv(wind_kt, twa_deg)
	var result: CaseResult = CaseResult.new()
	result.wind_kt = wind_kt
	result.twa_deg = twa_deg
	var half_length_m: float = 0.5 * sim.board_config.length_m
	var sailor_weight_n: float = sim.sailor_config.mass_kg * sim.sim_config.gravity_ms2
	var pitch_sum: float = 0.0
	var pitch_square_sum: float = 0.0
	var steps: int = int(scenario.seconds / DT)
	for i: int in steps:
		scenario.update(sim, DT)
		sim.step(DT, scenario.controls)
		var t: Telemetry = sim.telemetry
		if file != null and i % CSV_EVERY_STEPS == 0:
			file.store_line(t.to_csv_row())
		if sim.sailor_state == WindsurferSim.SailorState.FALLEN:
			result.fell = true
		if is_nan(t.speed_ms) or is_nan(t.position.y) or is_nan(t.pitch_deg):
			result.nan = true
		if t.time_s < from_s:
			continue
		result.count += 1
		result.speed_ms += t.speed_ms
		result.planing_ratio += t.planing_ratio
		result.wet_front_m += t.wetted_aft_m + t.wetted_length_m
		result.wet_length_m += t.wetted_length_m
		result.push_centre_m += half_length_m - t.planing_cop_z_m
		result.trim_deg += t.trim_deg
		result.harness_n += t.harness_tension_n
		result.rig_share += t.hand_force_up_n / sailor_weight_n
		result.mast_foot_down_n -= t.mast_foot_force_up_n
		result.friction_n += t.hull_friction_n
		result.drive_n += t.drive_n
		result.friction_area_m2 += t.friction_area_m2
		pitch_sum += t.pitch_deg
		pitch_square_sum += t.pitch_deg * t.pitch_deg
	if file != null:
		file.close()
	_finish_means(result, pitch_sum, pitch_square_sum)
	return result


## The default open-water simulation, as tools/simulate.sh builds it. With --board.<field>
## overrides it is built again on a copy of the board with those values, so that the
## buoyancy grid (built in the constructor) has the overridden shape too.
func _make_sim() -> WindsurferSim:
	var sim: WindsurferSim = WindsurferSim.create_default(false)
	var board: BoardConfig = sim.board_config.duplicate() as BoardConfig
	if not _apply_overrides({"board": board}):
		return sim
	var rebuilt: WindsurferSim = WindsurferSim.new(board, sim.sail_config, sim.fin_config, sim.sailor_config,
		sim.water_config, sim.wind_config, sim.sim_config, sim.wave_set_config)
	rebuilt.air_density_kg_m3 = sim.air_density_kg_m3
	return rebuilt


## Sets every --<group>.<field>=<number> option whose group is in `targets`, the way
## run_scenario.gd does. Returns true when it changed something.
func _apply_overrides(targets: Dictionary) -> bool:
	var changed: bool = false
	for key: String in _options:
		var parts: PackedStringArray = key.split(".", true, 1)
		if parts.size() != 2 or not targets.has(parts[0]):
			continue
		var target: Object = targets[parts[0]]
		if not (parts[1] in target):
			push_error("No field '%s' to override." % key)
			continue
		var current: Variant = target.get(parts[1])
		var number: float = _options[key].to_float()
		target.set(parts[1], (number != 0.0) if current is bool else (int(number) if current is int else number))
		changed = true
	return changed


## Turns the sums into means, and the pitch sums into a standard deviation.
func _finish_means(result: CaseResult, pitch_sum: float, pitch_square_sum: float) -> void:
	var n: float = float(maxi(result.count, 1))
	result.speed_ms /= n
	result.planing_ratio /= n
	result.wet_front_m /= n
	result.wet_length_m /= n
	result.push_centre_m /= n
	result.trim_deg /= n
	result.harness_n /= n
	result.rig_share /= n
	result.mast_foot_down_n /= n
	result.friction_n /= n
	result.drive_n /= n
	result.friction_area_m2 /= n
	var mean_pitch: float = pitch_sum / n
	result.pitch_sd_deg = sqrt(maxf(pitch_square_sum / n - mean_pitch * mean_pitch, 0.0))


func _format(r: CaseResult) -> String:
	return "%4.0f  %3.0f   %5.2f (%4.1f)    %4.2f  %5.2f  %4.2f  %4.2f  %4.2f  %5.2f    %5.0f    %3.0f   %5.0f  %4.0f  %5.0f  %4.2f   %s" % [
		r.wind_kt, r.twa_deg, r.speed_ms, r.speed_ms / SimMath.KNOT_MS, r.planing_ratio,
		r.wet_front_m, r.wet_length_m, r.push_centre_m, r.trim_deg, r.pitch_sd_deg,
		r.harness_n, r.rig_share * 100.0, r.mast_foot_down_n, r.friction_n, r.drive_n,
		r.friction_area_m2, _health(r)]


## "ok", or what went wrong: the sailor fell, or a number blew up.
func _health(r: CaseResult) -> String:
	if r.fell and r.nan:
		return "FELL NaN"
	if r.fell:
		return "FELL"
	if r.nan:
		return "NaN"
	return "ok"


func _open_csv(wind_kt: float, twa_deg: float) -> FileAccess:
	var out_dir: String = _options.get("out_dir", "")
	if out_dir == "":
		return null
	DirAccess.make_dir_recursive_absolute(out_dir)
	var path: String = "%s/reach_%d_%d.csv" % [out_dir, int(wind_kt), int(twa_deg)]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write %s" % path)
		return null
	file.store_line(Telemetry.csv_header())
	return file


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
