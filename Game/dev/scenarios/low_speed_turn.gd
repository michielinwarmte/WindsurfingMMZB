extends SimScenario
## Low-speed handling: sheet in gently from rest, then swing the rig fully back for four
## seconds and fully forward for four seconds, to see how fast the board turns and how
## much it slides sideways when it is not planing yet.


func _init() -> void:
	super()
	start_heading_deg = 180.0
	controls.sheet = 0.0
	controls.rake = 0.0
	seconds = 14.0
	pilot.hold_course = false  # the sheet is trimmed for us, the rig is ours


func update(sim: WindsurferSim, dt: float) -> void:
	var t: float = sim.time_s
	controls.rake = 0.0
	if t > 3.0 and t <= 7.0:
		controls.rake = 1.0
	elif t > 7.0 and t <= 11.0:
		controls.rake = -1.0
	pilot.update(sim.telemetry, controls, dt)


func describe() -> String:
	return "sheet trimmed; rig back 3-7 s, forward 7-11 s"
