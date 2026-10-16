class_name SimScenario
extends RefCounted
## Base class of the headless scenarios run by tools/simulate.sh. A scenario sets up the
## simulation and plays the sailor each step; the runner writes the telemetry to a CSV file
## and prints a summary. Subclasses live in res://dev/scenarios/.

## Wind at 10 m in knots; the runner can override it with --wind_kt.
var wind_kt: float = 15.0
## Compass heading the board starts on, degrees.
var start_heading_deg: float = 180.0
## Default length of the run; the runner can override it with --seconds.
var seconds: float = 60.0
## The sailor for scenarios that hold a course.
var pilot: Autopilot = Autopilot.new()
var controls: SimControls = SimControls.new()


func _init() -> void:
	controls.sheet = 0.0  # a sailor starts with the sail eased and sheets in as the board gets going


## Called once before the run. Override to change configs or the pilot.
func setup(_sim: WindsurferSim) -> void:
	pass


## Called every step before sim.step(). Default: let the pilot sail.
func update(sim: WindsurferSim, dt: float) -> void:
	pilot.update(sim.telemetry, controls, dt)


## One line for the summary at the end.
func describe() -> String:
	return "TWA %.0f deg, alpha %.0f deg" % [pilot.target_twa_deg, pilot.target_alpha_deg]
