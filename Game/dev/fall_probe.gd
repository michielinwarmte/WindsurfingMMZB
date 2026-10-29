extends SceneTree
## Sails one validation run (ValidationRun.sail) and prints how and when the sailor fell, with
## the second before it. A dev tool for PH16. Run:
##   tools/godot.sh --path Game --headless -s res://dev/fall_probe.gd -- --twa=120 --wind=24 --seconds=50


func _initialize() -> void:
	var args: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts: PackedStringArray = arg.substr(2).split("=", true, 1)
			args[parts[0]] = parts[1]
	var twa: float = args.get("twa", "120").to_float()
	var wind: float = args.get("wind", "24").to_float()
	var seconds: float = args.get("seconds", "50").to_float()
	var run: ValidationRun = ValidationRun.sail(twa, seconds, wind)
	var sim: WindsurferSim = run.sim
	print("fell: %s, kind %s, side %d, settled speed %.2f m/s" % [str(run.fell), sim.fall_kind, sim.fall_side, run.settled_speed_ms()])
	quit(0)
