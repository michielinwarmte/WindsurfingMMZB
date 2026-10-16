extends GutTest
## The sailor as a body of their own (PHYSICS_SPEC.md section 7.5): the legs, the hands
## and the feet, and what they pass to the hull.

const DT: float = 1.0 / 60.0


func _sim(wind_kt: float) -> WindsurferSim:
	var sim: WindsurferSim = WindsurferSim.create_default()
	sim.wind_config = sim.wind_config.duplicate()
	sim.wind_config.speed_kt = wind_kt
	sim.wind = WindField.new(sim.wind_config)
	sim.reset(Vector3.ZERO, deg_to_rad(180.0))
	return sim


func _run(sim: WindsurferSim, seconds: float, controls: SimControls) -> void:
	for i: int in int(seconds / DT):
		sim.step(DT, controls)


func test_at_rest_the_legs_carry_the_weight_into_the_hull_and_nothing_else() -> void:
	var sim: WindsurferSim = _sim(0.0)
	var controls: SimControls = SimControls.new()
	_run(sim, 6.0, controls)
	assert_almost_eq(sim.leg_force_world.y, 75.0 * 9.81, 5.0, "the legs hold the sailor's weight")
	assert_lt(SimMath.horizontal(sim.leg_force_world).length(), 5.0, "and push nowhere else")
	assert_almost_eq(sim.mast_foot_force_world.y, -8.0 * 9.81, 2.0, "the rig's weight stands on the mast foot")
	assert_lt(sim.hand_force_world.length(), 2.0, "the hands hold nothing")
	assert_lt(absf(sim.knee_bend_m), 0.003, "the legs are at their posture")
	assert_lt(sim.leg_sway_m, 0.003)
	assert_lt(absf(sim.telemetry.heel_deg), 1.0, "level")
	assert_almost_eq(sim.buoyancy.submerged_volume_m3, 92.0 / 1025.0, 0.02 * 92.0 / 1025.0, "the hull displaces all three")


func test_a_sailor_leaning_to_starboard_at_rest_heels_the_board_to_starboard() -> void:
	# No reflex: the controls place the body 0.1 m to starboard. (Without a sail to hang
	# on, 0.2 m puts the rail of a 120 L board under with 3 cm of freeboard, and the sailor
	# swims: the feet can hold the body, the board cannot hold the feet.) The toes press
	# against the heel, so it stays small.
	var sim: WindsurferSim = _sim(0.0)
	var controls: SimControls = SimControls.new()
	controls.balance_reflex = false
	_run(sim, 3.0, controls)
	controls.lean = 0.1
	_run(sim, 4.0, controls)
	var t: Telemetry = sim.telemetry
	assert_eq(sim.sailor_state, WindsurferSim.SailorState.SAILING, "still standing")
	assert_almost_eq(t.sailor_position_body.x, 0.1, 0.04, "the body is 0.1 m to starboard")
	assert_between(t.heel_deg, 0.5, 15.0, "the starboard rail goes down (heel positive), held by the toes")
	# The sailor presses the starboard side down: the feet stand under the body, off the
	# centreline, and the toes press back against the heel. On the board's real outline
	# (narrow ends, a tippy 8 N m per degree at rest) the board heels about 2 degrees and
	# the toes' moment nearly cancels the legs' own, so the check is on all the sailor
	# puts into the hull in roll, which is what heels it.
	assert_lt(t.roll_sailor_nm, -5.0, "the sailor presses the starboard side")


func test_the_rig_balance_splits_the_sail_force_between_mast_foot_and_hands() -> void:
	var sim: WindsurferSim = _sim(15.0)
	var controls: SimControls = SimControls.new()
	controls.sheet = 0.6
	controls.balance_reflex = false
	sim.step(DT, controls)
	var rig_weight: Vector3 = Vector3(0.0, -8.0 * 9.81, 0.0)
	var total: Vector3 = sim.mast_foot_force_world + sim.hand_force_world
	assert_almost_eq(total, sim.sail.force_world + rig_weight, Vector3.ONE * 1.0, "mast foot plus hands is the sail force plus the rig's weight")
	assert_gt(sim.hand_force_world.length(), 0.5 * sim.sail.force_world.length(), "the hands take more than half of a pull high on the rig")
	# On starboard tack the sail is to port and pulls the hands to port.
	assert_lt(SimMath.to_body(sim.body.basis, sim.hand_force_world).x, 0.0, "pulled toward the sail")
	# The moment about the mast foot is balanced: the hands' moment plus the sail's and
	# the rig's is nothing but the twist about the grip line (which the body takes).
	var foot: Vector3 = sim.body.point_world(sim.sail_config.mast_foot_local)
	var grip: Vector3 = sim.body.point_world(sim.hand_grip_body)
	var mast_dir_world: Vector3 = sim.rig.basis * sim.sail.mast_direction()
	var rig_com: Vector3 = foot + mast_dir_world * sim.sail_config.rig_com_height_m
	var moment: Vector3 = (sim.sail.ce_world - foot).cross(sim.sail.force_world) + (rig_com - foot).cross(rig_weight) + (grip - foot).cross(-sim.hand_force_world)
	var along_grip: Vector3 = (grip - foot).normalized()
	var scale: float = maxf(sim.hand_force_world.length() * (grip - foot).length(), 1.0)
	assert_lt((moment - along_grip * moment.dot(along_grip)).length(), 0.002 * scale, "balanced about the mast foot except along the grip line (to float precision)")
	# Hooked in, the line from the hips to the boom pulls the sailor up: the harness
	# carries part of the weight and the rig presses the mast foot down.
	assert_gt(sim.harness_tension_n, 0.0, "the sailor hangs in the harness")
	assert_gt(sim.hand_force_world.y, 0.0, "pulled upward by the line")
	assert_lt(sim.mast_foot_force_world.y, -8.0 * 9.81, "the mast foot carries more than the rig's own weight")


func test_the_hull_is_kicked_but_the_body_is_not() -> void:
	var sim: WindsurferSim = _sim(0.0)
	var controls: SimControls = SimControls.new()
	_run(sim, 6.0, controls)
	sim.body.velocity.y = 0.5
	var body_peak_ms: float = 0.0
	for i: int in int(1.0 / DT):
		sim.step(DT, controls)
		body_peak_ms = maxf(body_peak_ms, absf(sim.sailor.velocity.y))
	# Soft, well damped legs (1.2 Hz, 0.9) pass a short jolt on nearly whole, with a
	# little overshoot as the spring gives it back; what they take out is the slam itself.
	assert_lt(body_peak_ms, 0.6, "the body is not thrown by the hull's 0.5 m/s jolt")
	assert_gt(body_peak_ms, 0.05, "but it does feel it")

