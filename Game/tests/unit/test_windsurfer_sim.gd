extends GutTest
## Behaviour of the whole simulation on flat water (plan, Phase 2). The wind is 15 kt at
## 10 m from the West (270 degrees); the sail sees about 12.6 kt. A simple autopilot
## plays the sailor where a real sailor would have to act (holding a course with the rig,
## trimming the sheet); the physics is untouched.

const DT: float = 1.0 / 60.0


func _sim(wind_kt: float = 15.0) -> WindsurferSim:
	var sim: WindsurferSim = WindsurferSim.create_default()
	sim.wind_config = sim.wind_config.duplicate()
	sim.wind_config.speed_kt = wind_kt
	sim.wind = WindField.new(sim.wind_config)
	return sim


func _run(sim: WindsurferSim, seconds: float, controls: SimControls, pilot: Autopilot = null) -> void:
	for i: int in int(seconds / DT):
		if pilot != null:
			pilot.update(sim.telemetry, controls, DT)
		sim.step(DT, controls)


func _pilot(twa_deg: float) -> Autopilot:
	var pilot: Autopilot = Autopilot.new()
	pilot.target_twa_deg = twa_deg
	return pilot


func _eased() -> SimControls:
	var controls: SimControls = SimControls.new()
	controls.sheet = 0.0
	return controls


func test_floats_at_rest_level_and_at_archimedes_depth() -> void:
	var sim: WindsurferSim = _sim(0.0)
	sim.reset(Vector3.ZERO, 0.0)
	var controls: SimControls = SimControls.new()
	controls.sheet = 0.0
	_run(sim, 8.0, controls)
	var t: Telemetry = sim.telemetry
	assert_almost_eq(sim.buoyancy.submerged_volume_m3, 92.0 / 1025.0, 92.0 / 1025.0 * 0.02, "89.8 L displaced")
	assert_lt(absf(t.heel_deg), 2.0, "the sailor keeps it upright")
	assert_lt(absf(t.pitch_deg), 3.0)
	assert_lt(t.speed_ms, 0.05)


func test_legs_flex_on_a_kick_and_settle_again() -> void:
	var sim: WindsurferSim = _sim(0.0)
	sim.reset(Vector3.ZERO, 0.0)
	var controls: SimControls = SimControls.new()
	_run(sim, 8.0, controls)
	assert_lt(absf(sim.knee_bend_m), 0.002, "straight legs at rest")
	# The board is kicked upward at 0.5 m/s, as a wave would do.
	sim.body.velocity.y = 0.5
	var deepest_flex: float = 0.0
	for i: int in int(1.0 / DT):
		sim.step(DT, controls)
		deepest_flex = maxf(deepest_flex, absf(sim.knee_bend_m))
	assert_gt(deepest_flex, 0.01, "the legs stretch or give by at least a centimetre")
	_run(sim, 4.0, controls)
	assert_lt(absf(sim.knee_bend_m), 0.002, "and are straight again four seconds later")
	assert_lt(absf(sim.knee_bend_rate_ms), 0.01)
	assert_lt(absf(sim.telemetry.pitch_deg), 3.0, "still level")


func test_overpowered_sailor_is_catapulted_and_the_board_stays_upright() -> void:
	var sim: WindsurferSim = _sim(18.0)
	sim.reset(Vector3.ZERO, deg_to_rad(180.0))
	var controls: SimControls = _eased()
	var pilot: Autopilot = _pilot(90.0)
	_run(sim, 20.0, controls, pilot)
	assert_eq(sim.sailor_state, WindsurferSim.SailorState.SAILING)
	# Head up with the sail pulled fully in and held there: more than a 75 kg sailor holds.
	pilot.target_twa_deg = 60.0
	pilot.trim_sheet = false
	var fell_at: float = -1.0
	var heel_at_fall: float = 0.0
	var max_heel_after: float = 0.0
	while sim.time_s < 40.0 and (fell_at < 0.0 or sim.time_s < fell_at + 6.0):
		controls.sheet = 1.0 if fell_at < 0.0 else 0.0
		pilot.update(sim.telemetry, controls, DT)
		sim.step(DT, controls)
		var heel: float = absf(sim.telemetry.heel_deg)
		if sim.sailor_state == WindsurferSim.SailorState.FALLEN:
			if fell_at < 0.0:
				fell_at = sim.time_s
				heel_at_fall = heel
			else:
				max_heel_after = maxf(max_heel_after, heel)
	assert_gt(fell_at, 20.0, "the sailor went over")
	assert_eq(sim.fall_kind, "catapult", "to leeward, over the sail")
	assert_lt(heel_at_fall, 30.0, "the board had heeled only a little when the sailor let go")
	assert_lt(max_heel_after, 45.0, "and did not roll over afterwards")
	assert_eq(sim.sailor_state, WindsurferSim.SailorState.SAILING, "back on the board after the waterstart")
	var t: Telemetry = sim.telemetry
	assert_lt(absf(t.heel_deg), 5.0, "level")
	assert_lt(t.speed_ms, 1.0, "at rest")
	assert_between(t.twa_deg, 70.0, 110.0, "across the wind, on the same tack as before")


func test_autopilot_sheets_for_the_most_drive_when_it_knows_the_sail() -> void:
	var sim: WindsurferSim = _sim()
	var pilot: Autopilot = Autopilot.new()
	assert_almost_eq(pilot.best_alpha_deg(deg_to_rad(90.0)), 15.0, 1e-9, "a fixed angle without the sail")
	pilot.sail = sim.sail
	var reaching: float = pilot.best_alpha_deg(deg_to_rad(90.0))
	var pointing: float = pilot.best_alpha_deg(deg_to_rad(25.0))
	assert_between(reaching, 16.0, 22.0, "on a reach the most drive is near the stall")
	assert_between(pointing, 10.0, 22.0, "close to the wind the drag counts, so no further than the stall")
	assert_true(pointing <= reaching)
	assert_lt(pilot.best_alpha_deg(deg_to_rad(8.0)), reaching, "very close to the wind the sail is feathered")


func test_beam_reach_sets_off_and_planes() -> void:
	var sim: WindsurferSim = _sim()
	sim.reset(Vector3.ZERO, deg_to_rad(180.0))  # heading South, wind from the West: starboard tack
	var controls: SimControls = _eased()
	var pilot: Autopilot = _pilot(90.0)
	_run(sim, 10.0, controls, pilot)
	var t: Telemetry = sim.telemetry
	assert_gt(t.speed_ms, 2.0, "making way after 10 s")
	assert_eq(t.sail_side, -1, "boom to port on starboard tack")
	_run(sim, 35.0, controls, pilot)
	t = sim.telemetry
	assert_between(t.twa_deg, 70.0, 110.0, "holding the beam reach")
	assert_gt(t.speed_kmh, 18.0, "fast after 45 s")
	assert_gt(t.planing_ratio, 0.5, "planing: the dynamic lift carries more than half the weight")
	assert_lt(absf(t.heel_deg), 25.0, "not capsized")
	assert_between(t.pitch_deg, -3.0, 10.0, "sensible trim")
	assert_lt(t.submersion_ratio, 0.5, "riding high")


func test_close_hauled_makes_progress_upwind() -> void:
	var sim: WindsurferSim = _sim()
	sim.reset(Vector3.ZERO, deg_to_rad(180.0))
	var controls: SimControls = _eased()
	var pilot: Autopilot = _pilot(45.0)
	_run(sim, 45.0, controls, pilot)
	var t: Telemetry = sim.telemetry
	assert_between(t.twa_deg, 35.0, 60.0, "close-hauled")
	assert_gt(t.vmg_ms, 1.0, "gaining to windward")
	assert_gt(t.speed_ms, 3.0)


func test_head_to_wind_stops() -> void:
	var sim: WindsurferSim = _sim()
	sim.reset(Vector3.ZERO, deg_to_rad(270.0))  # bow into the wind
	sim.body.velocity = SimMath.to_world(sim.body.basis, Vector3(0.0, 0.0, -4.0))
	var controls: SimControls = SimControls.new()
	controls.sheet = 1.0
	_run(sim, 15.0, controls)
	assert_lt(sim.telemetry.speed_ms, 1.0, "no drive head to wind")


func _twa_change_with_rake(start_heading_deg: float, rake: float) -> float:
	var sim: WindsurferSim = _sim()
	sim.reset(Vector3.ZERO, deg_to_rad(start_heading_deg))
	var controls: SimControls = _eased()
	var pilot: Autopilot = _pilot(90.0)
	_run(sim, 20.0, controls, pilot)  # get going on a beam reach
	pilot.hold_course = false
	var twa_before: float = sim.telemetry.twa_deg
	controls.rake = rake
	_run(sim, 4.0, controls, pilot)
	return absf(sim.telemetry.twa_deg) - absf(twa_before)


func test_rake_back_heads_up_and_rake_forward_bears_away_on_both_tacks() -> void:
	# Starboard tack: heading South with the wind from the West (TWA +90).
	assert_lt(_twa_change_with_rake(180.0, 1.0), -8.0, "starboard tack, rake back: the wind angle gets smaller (heading up)")
	assert_gt(_twa_change_with_rake(180.0, -1.0), 8.0, "starboard tack, rake forward: bearing away")
	# Port tack: heading North (TWA -90).
	assert_lt(_twa_change_with_rake(0.0, 1.0), -8.0, "port tack, rake back heads up")
	assert_gt(_twa_change_with_rake(0.0, -1.0), 8.0, "port tack, rake forward bears away")


func test_both_tacks_are_mirror_images() -> void:
	var starboard: WindsurferSim = _sim()
	starboard.reset(Vector3.ZERO, deg_to_rad(180.0))
	_run(starboard, 30.0, _eased(), _pilot(90.0))
	var port: WindsurferSim = _sim()
	port.reset(Vector3.ZERO, deg_to_rad(0.0))
	_run(port, 30.0, _eased(), _pilot(90.0))
	assert_almost_eq(port.telemetry.speed_ms, starboard.telemetry.speed_ms, 0.03 * starboard.telemetry.speed_ms + 0.05, "same speed within a few %")
	assert_almost_eq(port.telemetry.heel_deg, -starboard.telemetry.heel_deg, 2.0)
	assert_eq(port.telemetry.sail_side, 1)
	assert_eq(starboard.telemetry.sail_side, -1)


func test_identical_runs_are_identical() -> void:
	var a: WindsurferSim = _sim()
	a.reset(Vector3.ZERO, deg_to_rad(180.0))
	var b: WindsurferSim = _sim()
	b.reset(Vector3.ZERO, deg_to_rad(180.0))
	_run(a, 5.0, _eased(), _pilot(90.0))
	_run(b, 5.0, _eased(), _pilot(90.0))
	assert_eq(a.body.position, b.body.position)
	assert_eq(a.body.basis, b.body.basis)
