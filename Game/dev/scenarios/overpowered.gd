extends "res://dev/scenarios/beam_reach.gd"
## What the team saw: planing on a beam reach, then heading up with the sail sheeted in
## hard and held there. From 25 s the pilot steers to 60 degrees off the wind, the sheet
## is pulled fully in and no longer trimmed.


func update(sim: WindsurferSim, dt: float) -> void:
	if sim.time_s > 25.0:
		pilot.target_twa_deg = 60.0
		pilot.trim_sheet = false
		controls.sheet = 1.0
	super(sim, dt)


func describe() -> String:
	return "beam reach, then head up to 60 deg with the sheet fully in from 25 s"
