extends SceneTree
## The slingshot (Max, 29 October 2026): sail a beam reach until the board is up to speed, then
## bear away to a broad reach and watch what the speed, the apparent wind and the sheet do,
## second by second, next to a board that starts on the broad reach. A dev tool; it changes
## nothing in the game.
##
## The board is sailed by the autopilot the reach check uses (the beam_reach scenario), in a
## steady wind on flat water unless --waves=1 / --gusts=1.
##
## Run from the repo root (Git Bash):
##   tools/godot.sh --path Game --headless -s res://dev/slingshot.gd -- --wind=15
## Options: --wind=15 --from_twa=100 --to_twa=135 --before=60 --after=40 --waves=0 --gusts=0
## and --pilot.<field>= --sailor.<field>= --sail.<field>= overrides.

const DT: float = 1.0 / 60.0

var _options: Dictionary[String, String] = {}


func _initialize() -> void:
	_options = _read_user_args()
	var wind_kt: float = _options.get("wind", "15").to_float()
	var from_twa: float = _options.get("from_twa", "100").to_float()
	var to_twa: float = _options.get("to_twa", "135").to_float()
	var before_s: float = _options.get("before", "60").to_float()
	var after_s: float = _options.get("after", "40").to_float()
	print("Slingshot: %.0f kt, %.0f s at TWA %.0f, then TWA %.0f for %.0f s; against a board that starts at TWA %.0f. Waves %s, gusts %s." % [wind_kt, before_s, from_twa, to_twa, after_s, to_twa, _options.get("waves", "0"), _options.get("gusts", "0")])
	var sling: Array = _make(wind_kt, from_twa)
	var direct: Array = _make(wind_kt, to_twa)
	print("   t  | slingshot: TWA  speed  AWA   AWS   boom  alpha  drive  sheet | direct: speed  AWA   AWS   boom  alpha  sheet")
	var steps: int = int((before_s + after_s) / DT)
	for i: int in steps:
		var t_s: float = float(i) * DT
		if t_s >= before_s:
			(sling[1] as SimScenario).pilot.target_twa_deg = to_twa
		for pair: Array in [sling, direct]:
			var scenario: SimScenario = pair[1]
			var sim: WindsurferSim = pair[0]
			scenario.update(sim, DT)
			sim.step(DT, scenario.controls)
		if _options.get("limits", "0") == "1" and i % 15 == 0 and t_s >= before_s - 1.0 and t_s <= before_s + 6.0:
			var sim_a: WindsurferSim = sling[0]
			var pilot: Autopilot = (sling[1] as SimScenario).pilot
			var ta: Telemetry = sim_a.telemetry
			var best: float = pilot.best_alpha_deg(deg_to_rad(ta.awa_deg), pilot._sail_pressure_pa(ta))
			var torque: float = pilot._alpha_for_torque_deg(ta, pilot._righting_moment_now_nm(ta))
			print("   limits t %.2f: best %.1f  torque %.1f  depower %.2f  heel %.1f  felt heel %.1f  wanted bank %.1f  alpha %.1f  lean %.2f  feet excess %.0f" % [t_s, best, torque, pilot._depower, ta.heel_deg, ta.felt_heel_deg, ta.wanted_bank_deg, ta.alpha_deg, sim_a.lean, sim_a.feet_moment_excess_nm])
		if i % 60 == 0 and t_s >= before_s - 10.0:
			var a: Telemetry = (sling[0] as WindsurferSim).telemetry
			var b: Telemetry = (direct[0] as WindsurferSim).telemetry
			print("%5.0f | %5.0f  %5.2f  %5.0f  %4.1f  %5.0f  %5.1f  %5.0f  %4.2f | %5.2f  %5.0f  %4.1f  %5.0f  %5.1f  %4.2f%s" % [
				t_s, absf(a.twa_deg), a.speed_ms, absf(a.awa_deg), a.aws_kt, absf(a.sail_angle_deg), a.alpha_deg, a.drive_n, a.sheet,
				b.speed_ms, absf(b.awa_deg), b.aws_kt, absf(b.sail_angle_deg), b.alpha_deg, b.sheet,
				"   (bear away)" if absf(t_s - before_s) < 0.5 else ""])
	quit(0)


## A board on the beam_reach scenario's autopilot at this true wind angle: [sim, scenario].
func _make(wind_kt: float, twa_deg: float) -> Array:
	var scenario: SimScenario = (load("res://dev/scenarios/beam_reach.gd") as GDScript).new()
	scenario.wind_kt = wind_kt
	scenario.pilot.target_twa_deg = twa_deg
	var waves: bool = _options.get("waves", "0") == "1"
	var sim: WindsurferSim = WindsurferSim.create_default(waves)
	sim.wind_config = sim.wind_config.duplicate()
	sim.wind_config.speed_kt = wind_kt
	sim.wind_config.height_gradient_enabled = false
	sim.wind_config.gusts_enabled = _options.get("gusts", "0") == "1"
	sim.wind_config.shifts_enabled = false
	sim.wind = WindField.new(sim.wind_config)
	scenario.pilot.sail = sim.sail
	scenario.pilot.sailor = sim.sailor_config
	for key: String in _options:
		var parts: PackedStringArray = key.split(".", true, 1)
		var targets: Dictionary = {"pilot": scenario.pilot, "sailor": sim.sailor_config, "sail": sim.sail_config}
		if parts.size() == 2 and targets.has(parts[0]) and parts[1] in targets[parts[0]]:
			(targets[parts[0]] as Object).set(parts[1], _options[key].to_float())
	sim.set_waves(waves)
	sim.reset(Vector3.ZERO, deg_to_rad(scenario.start_heading_deg))
	scenario.setup(sim)
	return [sim, scenario]


func _read_user_args() -> Dictionary[String, String]:
	var options: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts: PackedStringArray = arg.substr(2).split("=", true, 1)
			options[parts[0]] = parts[1]
	return options
