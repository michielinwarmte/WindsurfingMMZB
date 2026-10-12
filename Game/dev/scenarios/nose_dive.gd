extends SimScenario
## The nose-dive recovery of PHYSICS_SPEC.md section 14: the hull fully under water at
## 8 m/s with the bow 10 degrees down and the sail eased. Shows how the board slows down
## and comes back up (or how it bounces out).


func _init() -> void:
	super()
	start_heading_deg = 180.0
	seconds = 12.0
	pilot.hold_course = false
	pilot.trim_sheet = false


func setup(sim: WindsurferSim) -> void:
	sim.reset(Vector3.ZERO, deg_to_rad(start_heading_deg))
	sim.body.basis = sim.body.basis * Basis(Vector3.RIGHT, deg_to_rad(-10.0))  # about the board's own axis: bow down
	sim.body.set_origin_world(Vector3(0.0, -0.36, 0.0))
	sim.body.velocity = sim.body.basis * Vector3(0.0, 0.0, -8.0)
	controls.sheet = 0.0


func describe() -> String:
	return "nose dive: submerged at 8 m/s, bow 10 degrees down, sail eased"
