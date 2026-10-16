extends SimScenario
## No sailor at all: sheet and rake stay where they are. Shows what the board does on its
## own (it rounds up at low speed, as a real board does). --lean=<x> leans the sailor
## from 3 s on (no reflex: the body goes where the lean says), --sheet=<x> sets the sheet.
var lean_from_3s: float = 0.0


func _init() -> void:
	super()
	start_heading_deg = 180.0
	controls.sheet = 0.6
	controls.rake = 0.0


func setup(_sim: WindsurferSim) -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--lean="):
			lean_from_3s = arg.trim_prefix("--lean=").to_float()
			controls.balance_reflex = false
		if arg.begins_with("--sheet="):
			controls.sheet = arg.trim_prefix("--sheet=").to_float()


func update(sim: WindsurferSim, _dt: float) -> void:
	controls.lean = lean_from_3s if sim.time_s >= 3.0 else 0.0


func describe() -> String:
	return "fixed sheet %.2f, rake %.2f" % [controls.sheet, controls.rake]
