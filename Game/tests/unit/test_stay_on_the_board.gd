extends GutTest
## The bar of the fall moved and the autopilot's recovery reflex (Max, 6 November 2026: "The detection
## of what a crash would be is too strict. Move this bar and make the autopilot try harder to stay on
## the board"; Documentation/reports/autopilot/stay_on_the_board.md).
## 1. The fall rule (WindsurferSim._check_balance): the old numbers still give the old fall, a catapult
##    now needs a pull the body cannot hold and a heel that lasts, and a sheeted sail at 24 kt still
##    throws the sailor over it.
## 2. The reflex (PlayerController.reflex_on): it eases the sheet fast near the leeward limit, sheets in
##    near the windward one, bears away, and fades out at the top of the push slider.

const DT: float = 1.0 / 60.0
## The fall rule's numbers until 6 November 2026.
const OLD_RULE: Dictionary[String, float] = {"catapult_heel_deg": 20.0, "fall_back_heel_deg": 25.0, "standing_fall_heel_deg": 40.0,
	"catapult_pull_share": 0.0, "catapult_time_s": 0.0, "fall_back_time_s": 0.0, "tip_time_s": 0.3, "fall_feel_time_s": 1.0}


func after_each() -> void:
	for action: String in ["steer_left", "steer_right", "tack", "sheet_in", "sheet_out"]:
		Input.action_release(action)


## A board planing on a beam reach on starboard tack in this wind, with its own copy of the sailor's
## numbers set as given (the shared default config is left alone).
func _planing(wind_kt: float, rule: Dictionary[String, float]) -> WindsurferSim:
	var sim: WindsurferSim = WindsurferSim.create_default()
	sim.sailor_config = sim.sailor_config.duplicate()
	for field: String in rule:
		sim.sailor_config.set(field, rule[field])
	sim.wind_config = sim.wind_config.duplicate()
	sim.wind_config.speed_kt = wind_kt
	sim.wind = WindField.new(sim.wind_config)
	sim.reset(Vector3.ZERO, deg_to_rad(180.0))
	var controls: SimControls = SimControls.new()
	controls.sheet = 0.0
	var pilot: Autopilot = Autopilot.new()
	pilot.target_twa_deg = 90.0
	pilot.sail = sim.sail
	pilot.sailor = sim.sailor_config
	for i: int in int(15.0 / DT):
		pilot.update(sim.telemetry, controls, DT)
		sim.step(DT, controls)
	return sim


## Rolls the board about its fore-and-aft axis until the heel the fall check reads is this far to
## leeward (degrees; negative: to windward), and returns the heel it reads then. The felt heel holds the
## body's push too, so it is found in a few steps rather than in one turn.
func _heel_to_leeward(sim: WindsurferSim, lee_deg: float) -> float:
	var axis: Vector3 = sim.body.aft_axis()
	# Which way a roll about the aft axis moves the leeward heel: a small trial.
	var before: float = _lee_now(sim)
	sim.body.basis = Basis(axis, deg_to_rad(1.0)) * sim.body.basis
	var sign: float = 1.0 if _lee_now(sim) > before else -1.0
	for i: int in 40:
		var error_deg: float = lee_deg - _lee_now(sim)
		if absf(error_deg) < 0.05:
			break
		sim.body.basis = Basis(axis, deg_to_rad(error_deg) * sign) * sim.body.basis
	return _lee_now(sim)


## The heel the fall check reads, to leeward positive (degrees).
func _lee_now(sim: WindsurferSim) -> float:
	var tack: float = 1.0 if sim.body.wind_angle_rad(sim.wind.from_direction()) >= 0.0 else -1.0
	return -rad_to_deg(sim._fall_heel_rad()) * tack


## How long the fall check takes to throw the sailor with the heel held there (s), or -1 within max_s.
func _time_to_fall(sim: WindsurferSim, max_s: float) -> float:
	var step_s: float = 0.005
	var elapsed: float = 0.0
	while elapsed < max_s:
		sim._check_balance(step_s)
		elapsed += step_s
		if sim.sailor_state == WindsurferSim.SailorState.FALLEN:
			return elapsed
	return -1.0


func test_the_old_numbers_throw_the_sailor_at_once_past_20_degrees() -> void:
	var sim: WindsurferSim = _planing(18.0, OLD_RULE)
	assert_eq(sim.sailor_state, WindsurferSim.SailorState.SAILING, "planing at 18 kt")
	assert_gt(absf(sim.sail.side_force_n), 120.0, "hanging on a pulling sail")
	var lee: float = _heel_to_leeward(sim, 22.0)
	assert_almost_eq(lee, 22.0, 1.0, "the board rolled to 22 degrees to leeward")
	assert_almost_eq(_time_to_fall(sim, 1.0), 0.005, 1e-6, "the old rule: over the sail at the first check")
	assert_eq(sim.fall_kind, "catapult")


func test_the_new_numbers_ride_out_a_heel_and_a_jolt_but_not_a_lasting_heel() -> void:
	var rule: Dictionary[String, float] = OLD_RULE.duplicate()
	rule["catapult_heel_deg"] = 30.0
	rule["catapult_time_s"] = 0.25
	var sim: WindsurferSim = _planing(18.0, rule)
	_heel_to_leeward(sim, 25.0)
	assert_eq(_time_to_fall(sim, 2.0), -1.0, "25 degrees to leeward is ridden out with the knees")
	_heel_to_leeward(sim, 34.0)
	var fell_after: float = _time_to_fall(sim, 2.0)
	assert_almost_eq(fell_after, 0.25, 0.006, "34 degrees held: over the sail after catapult_time_s")
	assert_eq(sim.fall_kind, "catapult")


func test_a_catapult_needs_a_pull_the_body_cannot_hold() -> void:
	var rule: Dictionary[String, float] = OLD_RULE.duplicate()
	rule["catapult_heel_deg"] = 30.0
	rule["standing_fall_heel_deg"] = 50.0
	var sim: WindsurferSim = _planing(18.0, rule)
	var pull_share: float = SimMath.horizontal(sim.hand_force_world).length() / (sim.sailor_config.mass_kg * 9.81)
	assert_gt(pull_share, 0.05, "the sail pulls on the hands")
	sim.sailor_config.catapult_pull_share = pull_share * 1.5
	sim._copy_configs()
	_heel_to_leeward(sim, 35.0)
	assert_eq(_time_to_fall(sim, 1.0), -1.0, "past the catapult's heel with a pull the body holds: ridden out")
	_heel_to_leeward(sim, 52.0)
	assert_gt(_time_to_fall(sim, 0.1), 0.0, "past standing_fall_heel_deg the sailor goes anyway")
	assert_eq(sim.fall_kind, "fell off")
	var pulled: WindsurferSim = _planing(18.0, rule)
	pulled.sailor_config.catapult_pull_share = pull_share * 0.5
	pulled._copy_configs()
	_heel_to_leeward(pulled, 35.0)
	assert_gt(_time_to_fall(pulled, 0.1), 0.0, "with more pull than the share: a catapult")
	assert_eq(pulled.fall_kind, "catapult")


func test_a_fall_back_needs_the_pull_gone_for_longer_than_a_jolt() -> void:
	var rule: Dictionary[String, float] = OLD_RULE.duplicate()
	rule["fall_back_heel_deg"] = 32.0
	rule["fall_back_time_s"] = 0.3
	var sim: WindsurferSim = _planing(18.0, rule)
	var tack: float = 1.0 if sim.telemetry.twa_deg >= 0.0 else -1.0
	var held_deg: float = rad_to_deg(atan2(SimMath.horizontal(sim.hand_force_world).length(), sim.sailor_config.mass_kg * 9.81))
	# A windward tip of 36 degrees: the board heeled to windward that much plus what the pull holds.
	_heel_to_leeward(sim, -(36.0 + held_deg))
	assert_eq(_time_to_fall(sim, 0.25), -1.0, "a jolt shorter than fall_back_time_s is ridden out")
	var fell_after: float = _time_to_fall(sim, 1.0)
	assert_gt(fell_after, 0.0, "held longer: in backwards")
	assert_eq(sim.fall_kind, "fell back")
	assert_eq(sim.fall_side, int(tack), "to windward")


func test_the_balance_sense_reads_the_share_of_the_limit() -> void:
	var rule: Dictionary[String, float] = OLD_RULE.duplicate()
	rule["catapult_heel_deg"] = 30.0
	rule["catapult_time_s"] = 1.0
	var sim: WindsurferSim = _planing(18.0, rule)
	_heel_to_leeward(sim, 15.0)
	sim._check_balance(DT)
	assert_almost_eq(sim.lee_fall_share, 0.5, 0.04, "15 of 30 degrees: half way to the catapult")
	assert_eq(sim.windward_fall_share, 0.0, "nothing to windward")


func test_a_sheeted_sail_at_24_kt_still_throws_the_sailor_with_the_new_bar() -> void:
	# The defaults (the bar as moved): head up with the sail pulled fully in and held there at 24 kt,
	# as test_windsurfer_sim's catapult test; the sailor still goes over the sail (falls stay possible).
	var sim: WindsurferSim = WindsurferSim.create_default()
	sim.wind_config = sim.wind_config.duplicate()
	sim.wind_config.speed_kt = 24.0
	sim.wind = WindField.new(sim.wind_config)
	sim.reset(Vector3.ZERO, deg_to_rad(180.0))
	var controls: SimControls = SimControls.new()
	controls.sheet = 0.0
	var pilot: Autopilot = Autopilot.new()
	pilot.target_twa_deg = 90.0
	pilot.sail = sim.sail
	pilot.sailor = sim.sailor_config
	for i: int in int(20.0 / DT):
		pilot.update(sim.telemetry, controls, DT)
		sim.step(DT, controls)
	assert_eq(sim.sailor_state, WindsurferSim.SailorState.SAILING)
	pilot.target_twa_deg = 60.0
	pilot.trim_sheet = false
	var fell_at: float = -1.0
	while sim.time_s < 40.0 and fell_at < 0.0:
		controls.sheet = 1.0
		pilot.update(sim.telemetry, controls, DT)
		sim.step(DT, controls)
		if sim.sailor_state == WindsurferSim.SailorState.FALLEN:
			fell_at = sim.time_s
	gut.p("the sheeted sail at 24 kt: %s at %.1f s" % [sim.fall_kind, fell_at])
	assert_gt(fell_at, 20.0, "the sailor went over")
	assert_true(sim.fall_kind == "catapult" or sim.fall_kind == "tipped over", "to leeward, over the sail (%s)" % sim.fall_kind)


# ---------------------------------------------------------------- the reflex

## A board on starboard tack (the wind from starboard, the boom to port) planing at 10 m/s, carried by
## the water, with the sheet at 0.9 and the sail at 15 degrees of angle of attack.
func _telemetry() -> Telemetry:
	var t: Telemetry = Telemetry.new()
	t.twa_deg = 90.0
	t.twa_at_sail_deg = 90.0
	t.awa_deg = 40.0
	t.aws_kt = 25.0
	t.tws_at_sail_kt = 20.0
	t.sail_side = -1
	t.speed_ms = 10.0
	t.total_mass_kg = 100.0
	t.buoyancy_n = 300.0
	t.planing_lift_n = 700.0
	t.sheet = 0.9
	t.alpha_deg = 15.0
	return t


func _reflex() -> PlayerController:
	var controller: PlayerController = PlayerController.new()
	controller.reflex_on = true
	return controller


func test_no_danger_no_reflex() -> void:
	var controller: PlayerController = _reflex()
	var t: Telemetry = _telemetry()
	t.lee_fall_share = 0.5
	controller._feel_the_fall(t, DT)
	assert_eq(controller.lee_danger, 0.0, "half way to the limit: nothing felt yet (reflex_from_share 0.65)")
	var controls: SimControls = SimControls.new()
	controls.sheet = 0.9
	controller._recover_with_the_sheet(t, controls, true, DT)
	assert_eq(controls.sheet, 0.9, "the sheet as the pilot set it")


func test_near_the_leeward_limit_the_sheet_goes_fast_and_far() -> void:
	var controller: PlayerController = _reflex()
	var t: Telemetry = _telemetry()
	t.lee_fall_share = 0.9
	controller._feel_the_fall(t, DT)
	assert_almost_eq(controller.lee_danger, 1.0, 1e-6, "at reflex_full_share: the whole reflex")
	var controls: SimControls = SimControls.new()
	controls.sheet = 0.9
	controller._recover_with_the_sheet(t, controls, true, DT)
	assert_almost_eq(controls.sheet, 0.9 - controller.reflex_sheet_rate_per_s * DT, 1e-6, "eased at the hands' quick pace")
	var cap: float = controller._sheet_for_alpha(40.0, controller.reflex_alpha_deg)
	for i: int in 30:
		t.sheet = controls.sheet
		controls.sheet = 0.9
		controller._recover_with_the_sheet(t, controls, true, DT)
	assert_almost_eq(controls.sheet, cap, 1e-6, "down to reflex_alpha_deg of angle of attack and no further")
	assert_almost_eq(controller.wanted_sheet, cap, 1e-6, "the pilot carries on from there")
	t.lee_fall_share = 0.97
	for i: int in 30:
		t.sheet = controls.sheet
		controller._recover_with_the_sheet(t, controls, true, DT)
	assert_almost_eq(controls.sheet, controller._sheet_for_alpha(40.0, controller.reflex_last_alpha_deg), 1e-6, "the last chance: nearly let fly")


func test_the_body_tipping_toward_the_sail_counts_as_the_leeward_danger() -> void:
	var controller: PlayerController = _reflex()
	var t: Telemetry = _telemetry()
	t.tipping_share = 1.0
	t.feet_moment_excess_nm = 50.0  # positive: tipped to port, the leeward side on starboard tack
	controller._feel_the_fall(t, DT)
	assert_almost_eq(controller.lee_danger, 1.0, 1e-6, "tipped toward the sail at the hips' limit")
	assert_eq(controller.windward_danger, 0.0)
	var back: PlayerController = _reflex()
	t.feet_moment_excess_nm = -50.0
	back._feel_the_fall(t, DT)
	assert_almost_eq(back.windward_danger, 1.0, 1e-6, "tipped away from the sail: falling back")


func test_near_the_windward_limit_the_sheet_comes_in() -> void:
	var controller: PlayerController = _reflex()
	var t: Telemetry = _telemetry()
	t.windward_fall_share = 0.9
	t.sheet = 0.3
	controller._feel_the_fall(t, DT)
	var controls: SimControls = SimControls.new()
	controls.sheet = 0.3
	controller._recover_with_the_sheet(t, controls, true, DT)
	assert_almost_eq(controls.sheet, 0.3 + controller.reflex_sheet_rate_per_s * DT, 1e-6, "sheeted in at the hands' quick pace")
	# A backed sail (in irons) is not sheeted in: that would push the sailor further over backwards.
	t.is_backwinded = true
	controls.sheet = 0.3
	controller._recover_with_the_sheet(t, controls, true, DT)
	assert_eq(controls.sheet, 0.3, "the backed sail left alone")


func test_pulled_over_the_steering_bears_away() -> void:
	var controller: PlayerController = _reflex()
	var t: Telemetry = _telemetry()
	t.lee_fall_share = 0.9
	controller._feel_the_fall(t, DT)
	# Starboard tack: a right turn heads up.
	assert_almost_eq(controller._bear_away_from_the_fall(t, 10.0), -controller.reflex_bear_away_dps, 1e-6, "a head-up taken back, the board borne away")
	assert_almost_eq(controller._bear_away_from_the_fall(t, -20.0), -20.0, 1e-6, "a faster bear-away is kept")
	t.twa_deg = 150.0
	assert_almost_eq(controller._bear_away_from_the_fall(t, 10.0), 10.0, 1e-6, "not on a run")


func test_the_reflex_fades_at_the_top_of_the_push_slider() -> void:
	var controller: PlayerController = _reflex()
	assert_eq(controller.reflex_strength(), 1.0, "without a slider: all of it")
	controller.push_level = PushDial.NEUTRAL
	assert_eq(controller.reflex_strength(), 1.0, "at the neutral dial: all of it")
	controller.push_level = PushDial.PUSHED
	assert_eq(controller.reflex_strength(), 0.0, "pushed to the top: none (the pushed dial keeps its risk)")


func test_the_whole_controller_eases_more_with_the_reflex_near_the_limit() -> void:
	var with_reflex: PlayerController = _reflex()
	var without: PlayerController = PlayerController.new()
	without.reflex_on = false
	var a: SimControls = SimControls.new()
	var b: SimControls = SimControls.new()
	var t: Telemetry = _telemetry()
	for i: int in int(2.0 / DT):
		t.time_s += DT
		with_reflex.update(t, a, DT)
		without.update(t, b, DT)
	assert_almost_eq(a.sheet, b.sheet, 1e-6, "far from the limit: the same sheet")
	t.lee_fall_share = 0.9
	for i: int in int(0.3 / DT):
		t.time_s += DT
		t.sheet = a.sheet
		with_reflex.update(t, a, DT)
		without.update(t, b, DT)
	assert_lt(a.sheet, b.sheet - 0.1, "near the limit the reflex has eased the sail (%.2f against %.2f)" % [a.sheet, b.sheet])
	assert_lt(a.feet_roll_press, -0.5, "and the heels flatten the board")


func test_at_walking_pace_a_rising_nose_brings_the_weight_forward() -> void:
	var controller: PlayerController = _reflex()
	var t: Telemetry = _telemetry()
	t.speed_ms = 1.0
	t.pitch_deg = 15.0
	var controls: SimControls = SimControls.new()
	controller._step_forward_on_a_rising_nose(t, controls, 0.5)
	assert_eq(controls.step_forward, 0.0, "a nose up for half a second: not yet (reflex_nose_up_hold_s)")
	controller._step_forward_on_a_rising_nose(t, controls, 0.6)
	assert_almost_eq(controls.step_forward, 0.5, 1e-6, "15 degrees nose-up at walking pace for a second: half way toward the mast")
	t.pitch_deg = 25.0
	controller._step_forward_on_a_rising_nose(t, controls, DT)
	assert_almost_eq(controls.step_forward, 1.0, 1e-6, "from 20 degrees: all the way")
	t.speed_ms = 6.0
	controls.step_forward = 0.0
	controller._step_forward_on_a_rising_nose(t, controls, DT)
	assert_eq(controls.step_forward, 0.0, "at speed the trim is the feet's, not this")
