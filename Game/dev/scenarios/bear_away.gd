extends "res://dev/scenarios/beam_reach.gd"
## Planing on a beam reach, then the rig goes fully forward for four seconds (bear away)
## with the sheet still trimmed by the pilot. Shows how the sailor's balance copes with
## the sail's pull dropping away.


## --rake=<step> (default -1.0, added to the pilot's rake at 20 s) and --zero_helm=1
## (the pilot's tilt and lean are zeroed, as in the rake test) are read from the command line.
var rake_step: float = -1.0
var zero_helm: bool = false
var _rake_before: float = 0.0
var _stepped: bool = false


func setup(_sim: WindsurferSim) -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--rake="):
			rake_step = arg.trim_prefix("--rake=").to_float()
		elif arg.begins_with("--zero_helm="):
			zero_helm = arg.trim_prefix("--zero_helm=").to_int() != 0


func update(sim: WindsurferSim, dt: float) -> void:
	if sim.time_s > 20.0:
		if not _stepped:
			pilot.hold_course = false
			_rake_before = controls.rake
			if zero_helm:
				controls.rig_tilt = 0.0
				controls.lean = 0.0
			_stepped = true
		controls.rake = clampf(_rake_before + rake_step, -1.0, 1.0) if sim.time_s < 24.0 else _rake_before
	super(sim, dt)


func describe() -> String:
	return "beam reach, rake stepped by %.2f from 20 to 24 s%s" % [rake_step, ", tilt and lean zeroed" if zero_helm else ""]
