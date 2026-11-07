extends GutTest
## The rider's new controls (Documentation/reports/push_slider/PLAN.md; PH35 and PH3): the back
## foot against the fin (SimControls.back_foot_push) and the technique's targets moved by the
## rider (the rail, the trim and the rig's lean extras). At 0 every one of them leaves the
## physics as it was (the reach check's nine CSVs and the manoeuvre matrix were identical bit for
## bit before and after they were built, 31 October 2026). Here: what each does and which way,
## on a planing 18 kt beam reach.

const DT: float = 1.0 / 60.0


## An 18 kt beam reach on starboard tack (the wind from the West), the autopilot holding the
## course on flat water in a steady wind, set up as the reach check's case (the sail eased at the
## start, no height gradient, from heading 180), sailed for `seconds`: planing in the straps by
## 20 s.
func _planing_sim(seconds: float, controls: SimControls, pilot: Autopilot, balance: bool = true) -> WindsurferSim:
	var sim: WindsurferSim = WindsurferSim.create_for(EnvironmentConfig.new(), false, true)
	if not balance:
		# The stance by speed alone, as before the balance stance (7 November 2026, the realism audit B).
		sim.sailor_config.stance_balance_share = 0.0
		sim.sailor_config.stance_dive_full_deg = 0.0
		sim.sailor_config.stance_bow_high_deg = 0.0
	sim.wind_config.speed_kt = 18.0
	sim.wind_config.from_bearing_deg = 270.0
	sim.wind_config.height_gradient_enabled = false
	sim.wind_config.gusts_enabled = false
	sim.wind_config.shifts_enabled = false
	sim.wind = WindField.new(sim.wind_config)
	controls.sheet = 0.0
	pilot.sail = sim.sail
	pilot.sailor = sim.sailor_config
	pilot.air_density_kg_m3 = sim.air_density_kg_m3
	pilot.target_twa_deg = 100.0
	sim.reset(Vector3.ZERO, deg_to_rad(180.0))
	for i: int in int(seconds / DT):
		pilot.update(sim.telemetry, controls, DT)
		sim.step(DT, controls)
	return sim


func test_the_back_foot_pushes_the_tail_to_leeward_within_the_straps_bound() -> void:
	var controls: SimControls = SimControls.new()
	var pilot: Autopilot = Autopilot.new()
	var sim: WindsurferSim = _planing_sim(25.0, controls, pilot)
	assert_gt(sim.telemetry.speed_ms, 12.0, "planing by 25 s (15 m/s on the 18 kt beam reach)")
	assert_almost_eq(sim.stance, 1.0, 1e-3, "in the straps")
	assert_eq(sim.back_foot_yaw_nm, 0.0, "nothing asked, nothing: bit for bit")
	# The couple: the strap's sideways hold times the straps' spread, from the configs.
	var full_nm: float = sim.sailor_config.back_foot_push_n * (sim.board_config.front_strap_from_tail_m - sim.board_config.back_strap_from_tail_m)
	assert_almost_eq(full_nm, 88.5, 1e-3, "150 N times Max's 0.59 m")
	# On starboard tack the sail pulls to port; the back foot pushes the tail that way and the
	# bow to starboard, to windward: a negative yaw moment (positive turns the bow to port).
	controls.back_foot_push = 1.0
	sim.step(DT, controls)
	assert_almost_eq(sim.back_foot_yaw_nm, -full_nm, 1e-6, "the back foot heads up on starboard tack: the whole couple, no more")
	assert_almost_eq(sim.telemetry.back_foot_yaw_nm, -full_nm, 1e-6, "reported in the telemetry")
	controls.back_foot_push = -1.0
	sim.step(DT, controls)
	assert_almost_eq(sim.back_foot_yaw_nm, full_nm, 1e-6, "the front foot turns the bow the other way")
	controls.back_foot_push = 0.5
	sim.step(DT, controls)
	assert_almost_eq(sim.back_foot_yaw_nm, -0.5 * full_nm, 1e-6, "half the push, half the couple")
	controls.back_foot_push = 2.0
	sim.step(DT, controls)
	assert_almost_eq(sim.back_foot_yaw_nm, -full_nm, 1e-6, "asked for more than the straps hold: the bound")


func test_the_back_foot_heads_up_on_port_tack_too() -> void:
	var controls: SimControls = SimControls.new()
	var pilot: Autopilot = Autopilot.new()
	# The mirror image: the wind from the East, heading South, the wind from port.
	var sim: WindsurferSim = WindsurferSim.create_for(EnvironmentConfig.new(), false, true)
	sim.wind_config.speed_kt = 18.0
	sim.wind_config.from_bearing_deg = 90.0
	sim.wind_config.height_gradient_enabled = false
	sim.wind_config.gusts_enabled = false
	sim.wind_config.shifts_enabled = false
	sim.wind = WindField.new(sim.wind_config)
	controls.sheet = 0.0
	pilot.sail = sim.sail
	pilot.sailor = sim.sailor_config
	pilot.target_twa_deg = 100.0
	sim.reset(Vector3.ZERO, deg_to_rad(180.0))
	for i: int in int(25.0 / DT):
		pilot.update(sim.telemetry, controls, DT)
		sim.step(DT, controls)
	assert_lt(sim.telemetry.twa_deg, 0.0, "port tack")
	assert_gt(sim.telemetry.speed_ms, 12.0, "planing")
	controls.back_foot_push = 1.0
	sim.step(DT, controls)
	assert_gt(sim.back_foot_yaw_nm, 80.0, "on port tack the bow to port is to windward: a positive yaw moment")


func test_out_of_the_straps_the_back_foot_has_little_to_push_against() -> void:
	var controls: SimControls = SimControls.new()
	var pilot: Autopilot = Autopilot.new()
	# 2 s: the board is getting going, the feet still stepping back (the stance about half). With the
	# balance stance the sailor is in the straps by then; this test is about the push's share, so the
	# stance follows the speed alone here.
	var sim: WindsurferSim = _planing_sim(2.0, controls, pilot, false)
	assert_between(sim.stance, 0.2, 0.8, "between the rest stance and the straps")
	controls.back_foot_push = 1.0
	sim.step(DT, controls)
	var full_nm: float = sim.sailor_config.back_foot_push_n * (sim.board_config.front_strap_from_tail_m - sim.board_config.back_strap_from_tail_m)
	assert_almost_eq(absf(sim.back_foot_yaw_nm), sim.stance * full_nm, 0.05 * full_nm, "only as far as the feet are in the straps")


func test_more_rail_asked_banks_the_board_further_to_leeward() -> void:
	var controls: SimControls = SimControls.new()
	var pilot: Autopilot = Autopilot.new()
	var sim: WindsurferSim = _planing_sim(25.0, controls, pilot)
	# The bank the feet aim for (wanted_bank_deg) is the technique's leeward rail less what the
	# feet hold against the fin's roll, so its sign is not simply leeward; what the extra does is
	# shift it, and the board's heel with it (leeward is port, negative, on starboard tack).
	var bank_before: float = sim.telemetry.wanted_bank_deg
	var heel_before: float = sim.telemetry.heel_deg
	controls.rail_bank_extra_deg = 3.0
	for i: int in int(3.0 / DT):
		pilot.update(sim.telemetry, controls, DT)
		sim.step(DT, controls)
	assert_lt(sim.telemetry.wanted_bank_deg, bank_before - 2.0, "3 degrees more asked: the feet aim at least 2 more to leeward (the hike scales it)")
	assert_lt(sim.telemetry.heel_deg, heel_before - 1.0, "and the board heels further to leeward")


func test_more_trim_asked_raises_the_aim_and_more_lean_leans_the_rig() -> void:
	var controls: SimControls = SimControls.new()
	var pilot: Autopilot = Autopilot.new()
	var sim: WindsurferSim = _planing_sim(25.0, controls, pilot)
	var aim_before: float = sim.telemetry.trim_aim_deg
	var forward_speed: float = -sim.body.to_body(sim.body.velocity).z
	assert_almost_eq(aim_before, sim._running_trim_target_deg(forward_speed), 1e-6, "the technique's aim by speed")
	controls.trim_aim_extra_deg = 1.0
	sim.step(DT, controls)
	assert_almost_eq(sim.telemetry.trim_aim_deg - aim_before, 1.0, 0.05, "one degree more")
	var lean_before: float = sim.telemetry.rig_lean_deg
	var hike: float = sim.lean
	assert_gt(hike, 0.5, "hiked out on the reach")
	controls.rig_lean_extra_deg = 10.0
	sim.step(DT, controls)
	assert_almost_eq(sim.telemetry.rig_lean_deg - lean_before, hike * 10.0, 0.5, "ten degrees more at full hike, in proportion to the hike")
