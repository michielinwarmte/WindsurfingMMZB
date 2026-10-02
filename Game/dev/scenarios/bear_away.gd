extends "res://dev/scenarios/beam_reach.gd"
## Planing on a beam reach, then the rig goes fully forward for four seconds (bear away)
## with the sheet still trimmed by the pilot. Shows how the sailor's balance copes with
## the sail's pull dropping away.


func update(sim: WindsurferSim, dt: float) -> void:
	if sim.time_s > 20.0:
		pilot.hold_course = false
		controls.rake = -1.0 if sim.time_s < 24.0 else 0.0
	super(sim, dt)


func describe() -> String:
	return "beam reach, rig fully forward from 20 to 24 s"
