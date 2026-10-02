extends SceneTree
## Runs one scenario of res://dev/scenarios/ without a window and writes its telemetry to a
## CSV file, so the physics can be checked with numbers and charts. Use tools/simulate.sh.
##
## Arguments after "--": --scenario=<name> --out=<file.csv> [--seconds=<n>] [--wind_kt=<n>]
## [--twa=<deg>] [--heading=<deg>] [--every=<steps>] [--freeze=<s>: the sailor stops moving fore and aft from then on]
## [--twa2=<deg> --switch=<s>: the pilot steers to a second wind angle from that time on]

const DT: float = 1.0 / 60.0


func _initialize() -> void:
	var options: Dictionary[String, String] = _read_user_args()
	var name: String = options.get("scenario", "beam_reach")
	var out_path: String = options.get("out", "")
	var script: GDScript = load("res://dev/scenarios/%s.gd" % name)
	if script == null:
		push_error("No scenario called '%s' in res://dev/scenarios/." % name)
		quit(2)
		return
	var scenario: SimScenario = script.new()
	if options.has("seconds"):
		scenario.seconds = options["seconds"].to_float()
	if options.has("wind_kt"):
		scenario.wind_kt = options["wind_kt"].to_float()
	if options.has("twa"):
		scenario.pilot.target_twa_deg = options["twa"].to_float()
	if options.has("heading"):
		scenario.start_heading_deg = options["heading"].to_float()
	var every: int = maxi(options.get("every", "6").to_int(), 1)
	var freeze_s: float = options.get("freeze", "-1").to_float()
	var switch_s: float = options.get("switch", "-1").to_float()

	var sim: WindsurferSim = WindsurferSim.create_default()
	sim.wind_config = sim.wind_config.duplicate()
	sim.wind_config.speed_kt = scenario.wind_kt
	sim.wind = WindField.new(sim.wind_config)
	scenario.pilot.sail = sim.sail
	scenario.setup(sim)
	sim.reset(Vector3.ZERO, deg_to_rad(scenario.start_heading_deg))

	var file: FileAccess = null
	if out_path != "":
		file = FileAccess.open(out_path, FileAccess.WRITE)
		if file == null:
			push_error("Cannot write %s" % out_path)
			quit(3)
			return
		file.store_line(Telemetry.csv_header())

	var steps: int = int(scenario.seconds / DT)
	var max_speed: float = 0.0
	var max_heel: float = 0.0
	var max_pitch: float = -INF
	var min_pitch: float = INF
	var planing_since: float = -1.0
	var speed_sum_last: float = 0.0
	var count_last: int = 0
	for i: int in steps:
		if freeze_s >= 0.0 and sim.time_s >= freeze_s:
			scenario.controls.freeze_fore_aft = true
		if switch_s >= 0.0 and sim.time_s >= switch_s and options.has("twa2"):
			scenario.pilot.target_twa_deg = options["twa2"].to_float()
		scenario.update(sim, DT)
		sim.step(DT, scenario.controls)
		var t: Telemetry = sim.telemetry
		max_speed = maxf(max_speed, t.speed_ms)
		max_heel = maxf(max_heel, absf(t.heel_deg))
		max_pitch = maxf(max_pitch, t.pitch_deg)
		min_pitch = minf(min_pitch, t.pitch_deg)
		if planing_since < 0.0 and t.planing_ratio > 0.5:
			planing_since = t.time_s
		if t.time_s > scenario.seconds - 10.0:
			speed_sum_last += t.speed_ms
			count_last += 1
		if file != null and i % every == 0:
			file.store_line(t.to_csv_row())
	if file != null:
		file.close()

	var t: Telemetry = sim.telemetry
	var settled: float = speed_sum_last / maxi(count_last, 1)
	print("Scenario %s (%s), wind %.1f kt at 10 m (%.1f kt at the sail), %.0f s" % [name, scenario.describe(), scenario.wind_kt, t.tws_at_sail_kt, scenario.seconds])
	print("  final: speed %.2f m/s = %.1f km/h = %.1f kt, TWA %.1f, AWA %.1f, heading %.1f" % [t.speed_ms, t.speed_kmh, t.speed_kt, t.twa_deg, t.awa_deg, t.heading_deg])
	print("  last 10 s mean speed %.2f m/s (%.1f km/h), max speed %.2f m/s (%.1f km/h), VMG %.2f m/s" % [settled, settled * 3.6, max_speed, max_speed * 3.6, t.vmg_ms])
	print("  pitch %.1f deg (min %.1f, max %.1f), heel %.1f deg (max %.1f), submersion %.0f %%, planing ratio %.2f%s" % [t.pitch_deg, min_pitch, max_pitch, t.heel_deg, max_heel, t.submersion_ratio * 100.0, t.planing_ratio, (" since %.1f s" % planing_since) if planing_since >= 0.0 else ""])
	print("  sail: side %d, sheet %.2f (boom %.0f deg), alpha %.1f deg, lift %.0f N, drag %.0f N, drive %.0f N, side %.0f N; rake %.2f; lean %.2f, stance %.2f" % [t.sail_side, t.sheet, absf(t.sail_angle_deg), t.alpha_deg, t.sail_lift_n, t.sail_drag_n, t.drive_n, t.side_force_n, t.rake, t.lean, t.stance])
	print("  fin: slip %.1f deg, lift %.0f N, drag %.0f N; hull: friction %.0f N, residuary %.0f N, lateral %.0f N, planing lift %.0f N at trim %.1f deg; buoyancy %.0f N, wetted %.2f m2" % [t.fin_slip_deg, t.fin_lift_n, t.fin_drag_n, t.hull_friction_n, t.hull_residuary_n, t.hull_lateral_n, t.planing_lift_n, t.trim_deg, t.buoyancy_n, t.wetted_area_m2])
	if out_path != "":
		print("  CSV: %s" % out_path)
	quit(0)


func _read_user_args() -> Dictionary[String, String]:
	var options: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
			options[parts[0]] = parts[1]
	return options
