extends SimScenario
## The sail's flutter on screen (RigVisuals.flutter_for) along a run, printed once a second:
## the autopilot sails a beam reach; --ease_at=<s> lets the sheet go right out (sheet 0) from
## that time on, --luff_at=<s> eases the sheet only until the sail luffs (the pilot trims
## for an angle of attack of 0). The flutter is eased from tick to tick as RigVisuals does.
##   tools/simulate.sh sail_flutter 20 --wind_kt=18 [--ease_at=8] [--luff_at=8]
var ease_at_s: float = -1.0
var luff_at_s: float = -1.0
var _flutter: float = 0.0
var _next_print_s: float = 0.0


func _init() -> void:
	super()
	start_heading_deg = 180.0
	pilot.target_twa_deg = 90.0


func setup(_sim: WindsurferSim) -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--ease_at="):
			ease_at_s = arg.trim_prefix("--ease_at=").to_float()
		if arg.begins_with("--luff_at="):
			luff_at_s = arg.trim_prefix("--luff_at=").to_float()


func update(sim: WindsurferSim, dt: float) -> void:
	if luff_at_s >= 0.0 and sim.time_s >= luff_at_s:
		pilot.sail = null  # trim for target_alpha_deg instead of for the most drive
		pilot.target_alpha_deg = 0.0
		pilot.min_alpha_deg = 0.0
	pilot.update(sim.telemetry, controls, dt)
	if ease_at_s >= 0.0 and sim.time_s >= ease_at_s:
		controls.sheet = 0.0
	_flutter = move_toward(_flutter, RigVisuals.flutter_for(sim.sail), RigVisuals.FLUTTER_RATE * dt)
	if sim.time_s >= _next_print_s:
		_next_print_s += 1.0
		var t: Telemetry = sim.telemetry
		print("t %4.1f s  speed %4.1f kt  aws %4.1f kt  sheet %.2f  alpha %6.1f deg  lift %5.0f N  load %.2f  flutter %.2f%s" % [
			sim.time_s, t.speed_kt, t.aws_kt, t.sheet, t.alpha_deg, t.sail_lift_n,
			RigVisuals.sail_load(sim.sail.cl, sim.sail.cd), _flutter,
			"  backwinded" if t.is_backwinded else ("  luffing" if t.is_luffing else "")])


func describe() -> String:
	return "beam reach, sheet out from %.0f s, luffing from %.0f s" % [ease_at_s, luff_at_s]
