extends GutTest
## The recovery and equilibrium checks of PHYSICS_SPEC.md section 14, Part B: no flying
## off at speed, the nose-dive recovery, righting from a heel, and stopping head to wind.

const DT: float = ValidationRun.DT


func _step(sim: WindsurferSim, controls: SimControls, seconds: float, pilot: Autopilot = null) -> void:
	for i: int in int(seconds / DT):
		if pilot != null:
			pilot.update(sim.telemetry, controls, DT)
		sim.step(DT, controls)


func test_no_flying_off_at_speed() -> void:
	# Sailed to 12 m/s and more in 24 kt on a broad reach, the centre of mass settles at a
	# height that a planing hull supports: the lift falls as the board rises, so there is
	# an equilibrium and no cap is needed.
	var run: ValidationRun = ValidationRun.sail(120.0, 50.0, 24.0)
	assert_false(run.fell, "no fall")
	assert_gt(run.settled_speed_ms(), 11.0, "fast: %.2f m/s = %.1f km/h" % [run.settled_speed_ms(), run.settled_speed_ms() * 3.6])
	var base: float = run.sim.water_config.base_height_m
	assert_lt(run.settled(run.height_m) - base, 0.25, "the centre of mass stays within 0.25 m of the water (%.3f m)" % (run.settled(run.height_m) - base))
	assert_lt(run.settled_spread(run.height_m), 0.10, "and does not bounce (%.3f m peak to peak)" % run.settled_spread(run.height_m))
	assert_lt(absf(run.sim.body.velocity.y), 0.05, "vertical velocity within 5 cm/s (%.3f)" % run.sim.body.velocity.y)
	assert_gt(run.settled(run.submersion), 0.02, "still touching the water (submersion %.3f)" % run.settled(run.submersion))


func test_nose_dive_recovery() -> void:
	# Fully under water at 8 m/s with the bow 10 degrees down and the sail eased: the hull's
	# drag stops it within 3 s, buoyancy brings it back up within 8 s without a bounce.
	var sim: WindsurferSim = ValidationRun.make_sim(15.0)
	sim.reset(Vector3.ZERO, deg_to_rad(180.0))
	var rest_height: float = sim.body.origin_world().y
	sim.body.basis = sim.body.basis * Basis(Vector3.RIGHT, deg_to_rad(-10.0))  # about the board's own axis: bow down
	sim.body.set_origin_world(Vector3(0.0, -0.36, 0.0))  # the deck 0.3 m under
	sim.body.velocity = sim.body.basis * Vector3(0.0, 0.0, -8.0)
	var controls: SimControls = SimControls.new()
	controls.sheet = 0.0
	var run: ValidationRun = ValidationRun.new()
	run.sim = sim
	run.record_steps(null, controls, 12.0)
	assert_false(run.nan, "no NaN")
	var stopped_s: float = run.first_time_below(run.speed_ms, 2.0)
	assert_between(stopped_s, 0.0, 3.0, "below 2 m/s within 3 s (%.1f s)" % stopped_s)
	var back_up_s: float = -1.0
	for i: int in run.submersion.size():
		if absf(run.submersion[i] - 0.75) <= 0.05 and run.time_s[i] > 1.0:
			back_up_s = run.time_s[i]
			break
	assert_between(back_up_s, 0.0, 8.0, "submersion back to 0.75 +/- 0.05 within 8 s (%.1f s)" % back_up_s)
	var highest: float = -INF
	for h: float in run.height_m:
		highest = maxf(highest, h)
	assert_lt(highest - rest_height, 0.10, "no bounce above the rest height (%.3f m)" % (highest - rest_height))
	assert_lt(absf(run.value_at(run.pitch_deg, 10.0)), 3.0, "level again at 10 s (pitch %.1f)" % run.value_at(run.pitch_deg, 10.0))


func test_the_board_rights_itself_from_20_degrees_of_heel() -> void:
	# The board alone (the sailor in the water after a fall), heeled and released without
	# wind: the hull's buoyancy brings it back level within 5 s without swinging more than
	# 10 degrees past level. With the sailor standing rigidly on the deck the whole thing
	# would fall over, as it does on the water: a sailor balances, or is in the water.
	var sim: WindsurferSim = ValidationRun.make_sim(0.0)
	sim.sailor_config = sim.sailor_config.duplicate()
	sim.sailor_config.waterstart_time_s = 100.0
	sim.reset(Vector3.ZERO, deg_to_rad(180.0))
	sim.force_fall("fell off")
	sim.body.basis = sim.body.basis * Basis(Vector3.FORWARD, deg_to_rad(20.0))  # about the board's own axis
	var controls: SimControls = SimControls.new()
	var run: ValidationRun = ValidationRun.new()
	run.sim = sim
	run.record_steps(null, controls, 6.0)
	_assert_rights(run, "the bare board")


func test_the_sailor_rights_the_board_from_20_degrees_of_heel() -> void:
	# The same with the sailor on the board, balancing (beginner mode): the weight comes
	# across and the board is level again within 5 s.
	var sim: WindsurferSim = ValidationRun.make_sim(0.0)
	sim.reset(Vector3.ZERO, deg_to_rad(180.0))
	sim.body.basis = sim.body.basis * Basis(Vector3.FORWARD, deg_to_rad(20.0))
	var controls: SimControls = SimControls.new()
	controls.sheet = 0.0
	var run: ValidationRun = ValidationRun.new()
	run.sim = sim
	run.record_steps(null, controls, 6.0)
	assert_false(run.fell, "the sailor stays on")
	_assert_rights(run, "the balancing sailor")


func _assert_rights(run: ValidationRun, who: String) -> void:
	var lowest: float = INF
	var level_since: float = -1.0
	for i: int in run.heel_deg.size():
		lowest = minf(lowest, run.heel_deg[i])
		if absf(run.heel_deg[i]) < 2.0:
			if level_since < 0.0:
				level_since = run.time_s[i]
		else:
			level_since = -1.0
	assert_between(level_since, 0.0, 5.0, "%s: within 2 degrees of level from %.1f s on" % [who, level_since])
	assert_gt(lowest, -10.0, "%s: overshoot the other way at most 10 degrees (%.1f)" % [who, lowest])


func test_head_to_wind_stops() -> void:
	var sim: WindsurferSim = ValidationRun.make_sim(15.0)
	sim.reset(Vector3.ZERO, deg_to_rad(270.0))  # bow into the wind from the West
	sim.body.velocity = sim.body.basis * Vector3(0.0, 0.0, -5.0)
	var controls: SimControls = SimControls.new()
	controls.sheet = 0.0
	var run: ValidationRun = ValidationRun.new()
	run.sim = sim
	run.record_steps(null, controls, 15.0)
	var slow_s: float = run.first_time_below(run.speed_ms, 1.0)
	assert_between(slow_s, 0.0, 15.0, "below 1 m/s within 15 s (%.1f s)" % slow_s)
