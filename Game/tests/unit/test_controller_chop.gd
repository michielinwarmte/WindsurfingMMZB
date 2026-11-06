extends GutTest
## The beginner controller's chop technique (Documentation/reports/autopilot/lake_chop_training.md):
## the sheet eased while carving up at speed and while the board is light over a crest, no rail at
## walking pace, less pull held when the board bounces, and a tack timed on the waves. Each setting
## is tested on its own, set here, so the tests hold whatever the defaults are; the last test pins
## the defaults the lake's training chose.

const DT: float = 1.0 / 60.0


func after_each() -> void:
	for action: String in ["steer_left", "steer_right", "tack", "sheet_in", "sheet_out"]:
		Input.action_release(action)


## A board on starboard tack (the wind from starboard, the boom to port) at a speed, carried by the
## water (its whole weight on the hull: 100 kg).
func _telemetry(speed_ms: float, twa_deg: float = 90.0) -> Telemetry:
	var t: Telemetry = Telemetry.new()
	t.twa_deg = twa_deg
	t.twa_at_sail_deg = twa_deg
	t.awa_deg = 35.0
	t.aws_kt = 20.0
	t.sail_side = -1
	t.speed_ms = speed_ms
	t.total_mass_kg = 100.0
	t.buoyancy_n = 300.0
	t.planing_lift_n = 700.0
	return t


## The ease in the air at any wind and in any sea (its gates off), for the tests of the ease itself.
func _without_gates(controller: PlayerController) -> void:
	controller.airborne_wind_full_kt = 0.0
	controller.airborne_bounce_full_dps = 0.0


func _run(controller: PlayerController, telemetry: Telemetry, controls: SimControls, seconds: float) -> void:
	for i: int in int(seconds / DT):
		telemetry.time_s += DT
		controller.update(telemetry, controls, DT)


func test_no_rail_at_walking_pace_when_the_rail_fades_in_with_speed() -> void:
	var slow: PlayerController = PlayerController.new()
	slow.rail_from_ms = 2.0
	slow.rail_full_ms = 5.0
	var controls: SimControls = SimControls.new()
	Input.action_press("steer_right")  # heading up on starboard tack
	_run(slow, _telemetry(1.0), controls, 1.0)
	assert_almost_eq(controls.lean, 0.0, 0.01, "at 1 m/s no weight on the rail")
	var fast: PlayerController = PlayerController.new()
	fast.rail_from_ms = 2.0
	fast.rail_full_ms = 5.0
	var fast_controls: SimControls = SimControls.new()
	_run(fast, _telemetry(6.0), fast_controls, 1.0)
	assert_gt(fast_controls.lean, 0.2, "at 6 m/s the rail carves the turn as before")
	var before: PlayerController = PlayerController.new()
	before.rail_full_ms = 0.0
	var before_controls: SimControls = SimControls.new()
	_run(before, _telemetry(1.0), before_controls, 1.0)
	assert_gt(before_controls.lean, 0.2, "off (rail_full_ms 0): the rail at every speed, as before")


func test_the_sheet_is_eased_while_carving_up_at_speed() -> void:
	var controller: PlayerController = PlayerController.new()
	controller.head_up_alpha_deg = 9.0
	var controls: SimControls = SimControls.new()
	_run(controller, _telemetry(12.0), controls, 0.5)
	assert_eq(controller.auto_sheet_pilot.max_alpha_deg, 90.0, "sailing straight: no ease")
	Input.action_press("steer_right")
	_run(controller, _telemetry(12.0), controls, 0.5)
	assert_eq(controller.auto_sheet_pilot.max_alpha_deg, 9.0, "heading up at 12 m/s: eased to 9 degrees")
	Input.action_release("steer_right")
	Input.action_press("steer_left")
	_run(controller, _telemetry(12.0), controls, 0.5)
	assert_eq(controller.auto_sheet_pilot.max_alpha_deg, 90.0, "bearing away: no ease")
	Input.action_release("steer_left")
	Input.action_press("steer_right")
	_run(controller, _telemetry(4.0), controls, 0.5)
	assert_eq(controller.auto_sheet_pilot.max_alpha_deg, 90.0, "heading up slowly: no ease")


func test_the_sheet_is_eased_in_a_tacks_carve_at_speed() -> void:
	var controller: PlayerController = PlayerController.new()
	controller.head_up_alpha_deg = 9.0
	var controls: SimControls = SimControls.new()
	var t: Telemetry = _telemetry(12.0, 90.0)
	_run(controller, t, controls, 0.2)
	Input.action_press("tack")
	_run(controller, t, controls, 0.1)
	Input.action_release("tack")
	_run(controller, t, controls, 0.1)
	assert_eq(controller.manoeuvre, PlayerController.Manoeuvre.TACK_HEADING_UP, "Space at a beam reach tacks")
	assert_eq(controller.auto_sheet_pilot.max_alpha_deg, 9.0, "carving up at speed: eased")


func test_the_sheet_is_eased_while_the_board_is_light_over_a_crest() -> void:
	var controller: PlayerController = PlayerController.new()
	controller.airborne_alpha_deg = 6.0
	controller.airborne_hold_s = 0.3
	_without_gates(controller)
	var controls: SimControls = SimControls.new()
	var t: Telemetry = _telemetry(12.0)
	_run(controller, t, controls, 0.2)
	assert_eq(controller.auto_sheet_pilot.max_alpha_deg, 90.0, "on the water: no ease")
	t.buoyancy_n = 20.0
	t.planing_lift_n = 0.0
	_run(controller, t, controls, 0.1)
	assert_eq(controller.auto_sheet_pilot.max_alpha_deg, 6.0, "the water carries 2 % of the weight: eased")
	t.buoyancy_n = 300.0
	t.planing_lift_n = 700.0
	_run(controller, t, controls, 0.15)
	assert_eq(controller.auto_sheet_pilot.max_alpha_deg, 6.0, "still eased just after landing")
	_run(controller, t, controls, 0.3)
	assert_eq(controller.auto_sheet_pilot.max_alpha_deg, 90.0, "trimmed again once it has landed")


func test_less_pull_is_held_when_the_board_bounces() -> void:
	var controller: PlayerController = PlayerController.new()
	controller.chop_hike_drop = 0.2
	var own: float = Autopilot.new().hike_share
	var controls: SimControls = SimControls.new()
	var t: Telemetry = _telemetry(12.0)
	_run(controller, t, controls, 2.0)
	assert_almost_eq(controller.auto_sheet_pilot.hike_share, own, 1e-6, "flat water: the pilot's own pull")
	# Bouncing: the pitch rate swings 20 degrees a second each way, for longer than the pilot feels.
	for i: int in int(10.0 / DT):
		t.time_s += DT
		t.pitch_rate_dps = 20.0 if i % 30 < 15 else -20.0
		controller.update(t, controls, DT)
	assert_almost_eq(controller.chop_share(), 1.0, 0.01, "wild")
	assert_almost_eq(controller.auto_sheet_pilot.hike_share, own * 0.8, 1e-6, "a fifth less pull held")


func test_a_tack_at_speed_waits_for_the_bow_to_drop_off_a_crest() -> void:
	var controller: PlayerController = PlayerController.new()
	controller.manoeuvre_wait_max_s = 0.8
	var controls: SimControls = SimControls.new()
	var t: Telemetry = _telemetry(12.0)
	t.pitch_rate_dps = 3.0  # the bow rising onto a crest
	Input.action_press("tack")
	_run(controller, t, controls, 0.1)
	Input.action_release("tack")
	_run(controller, t, controls, 0.3)
	assert_eq(controller.manoeuvre, PlayerController.Manoeuvre.NONE, "waiting while the bow rises")
	t.pitch_rate_dps = -8.0
	_run(controller, t, controls, 0.05)
	assert_eq(controller.manoeuvre, PlayerController.Manoeuvre.TACK_HEADING_UP, "the bow drops: the tack starts")
	var patient: PlayerController = PlayerController.new()
	patient.manoeuvre_wait_max_s = 0.8
	var t2: Telemetry = _telemetry(12.0)
	t2.pitch_rate_dps = 3.0
	Input.action_press("tack")
	_run(patient, t2, controls, 0.1)
	Input.action_release("tack")
	_run(patient, t2, controls, 0.9)
	assert_ne(patient.manoeuvre, PlayerController.Manoeuvre.NONE, "never longer than manoeuvre_wait_max_s")


func test_the_sail_comes_back_in_faster_after_a_jump() -> void:
	var controller: PlayerController = PlayerController.new()
	controller.airborne_alpha_deg = 6.0
	controller.airborne_hold_s = 0.3
	controller.airborne_sheet_in_share = 3.0
	controller.airborne_resheet_s = 1.0
	_without_gates(controller)
	var own: float = Autopilot.new().sheet_in_share
	var controls: SimControls = SimControls.new()
	var t: Telemetry = _telemetry(12.0)
	_run(controller, t, controls, 0.2)
	assert_eq(controller.auto_sheet_pilot.sheet_in_share, own, "on the water: the pilot's own pace")
	t.buoyancy_n = 0.0
	t.planing_lift_n = 0.0
	_run(controller, t, controls, 0.2)
	assert_eq(controller.auto_sheet_pilot.sheet_in_share, 3.0, "in the air: ready to sheet back in fast")
	t.buoyancy_n = 300.0
	t.planing_lift_n = 700.0
	_run(controller, t, controls, 0.8)
	assert_eq(controller.auto_sheet_pilot.sheet_in_share, 3.0, "and for a while after landing")
	_run(controller, t, controls, 1.0)
	assert_eq(controller.auto_sheet_pilot.sheet_in_share, own, "then the pilot's own pace again")


func test_the_heading_holds_corrections_ease_only_when_asked() -> void:
	for on_hold: bool in [true, false]:
		var controller: PlayerController = PlayerController.new()
		controller.head_up_alpha_deg = 9.0
		controller.head_up_ease_on_hold = on_hold
		controller.head_up_ease_from_dps = 5.0
		var controls: SimControls = SimControls.new()
		var t: Telemetry = _telemetry(12.0)
		t.heading_deg = 180.0
		_run(controller, t, controls, 0.5)
		# The board has been knocked 10 degrees to port: the hold turns it back to the right, which on
		# starboard tack is toward the wind.
		t.heading_deg = 170.0
		_run(controller, t, controls, 0.2)
		assert_eq(controller.auto_sheet_pilot.max_alpha_deg, 9.0 if on_hold else 90.0,
			"the hold's correction toward the wind eases the sheet only with head_up_ease_on_hold")


func test_the_ease_in_the_air_only_in_strong_wind_when_gated() -> void:
	for wind_kt: float in [15.0, 19.0, 21.0]:
		var controller: PlayerController = PlayerController.new()
		controller.airborne_alpha_deg = 6.0
		controller.airborne_wind_from_kt = 18.0
		controller.airborne_wind_full_kt = 20.0
		controller.airborne_bounce_full_dps = 0.0
		var controls: SimControls = SimControls.new()
		var t: Telemetry = _telemetry(12.0)
		t.tws_at_sail_kt = wind_kt
		t.buoyancy_n = 0.0
		t.planing_lift_n = 0.0
		_run(controller, t, controls, 0.1)
		var expected: float = 90.0 if wind_kt < 18.0 else (15.0 if wind_kt < 20.0 else 6.0)
		assert_almost_eq(controller.auto_sheet_pilot.max_alpha_deg, expected, 0.01,
			"%.0f kt at the sail: none below 18, halfway at 19 (24 to 6), the full ease from 20" % wind_kt)


func test_the_ease_in_the_air_only_in_short_chop_when_gated() -> void:
	for bounce_dps: float in [5.0, 20.0]:
		var controller: PlayerController = PlayerController.new()
		controller.airborne_alpha_deg = 6.0
		controller.airborne_bounce_from_dps = 8.0
		controller.airborne_bounce_full_dps = 12.0
		controller.airborne_wind_full_kt = 0.0
		var controls: SimControls = SimControls.new()
		var t: Telemetry = _telemetry(12.0)
		# The board pitching at bounce_dps (RMS) for 10 s, on the water.
		for i: int in int(10.0 / DT):
			t.time_s += DT
			t.pitch_rate_dps = bounce_dps if i % 30 < 15 else -bounce_dps
			controller.update(t, controls, DT)
		t.buoyancy_n = 0.0
		t.planing_lift_n = 0.0
		_run(controller, t, controls, 0.1)
		assert_eq(controller.auto_sheet_pilot.max_alpha_deg, 90.0 if bounce_dps < 8.0 else 6.0,
			"light at a bounce of %.0f degrees a second: %s" % [bounce_dps, "no ease (the open sea)" if bounce_dps < 8.0 else "eased (chop)"])


func test_a_small_turn_toward_the_wind_is_not_a_head_up_from_the_threshold() -> void:
	var controller: PlayerController = PlayerController.new()
	controller.head_up_alpha_deg = 9.0
	controller.head_up_ease_from_dps = 10.0
	var hands: AiHands = AiHands.new()
	controller.hands = hands
	var controls: SimControls = SimControls.new()
	hands.steer = 0.2  # a stick nudged toward the wind (starboard tack: right)
	_run(controller, _telemetry(12.0), controls, 0.5)
	assert_eq(controller.auto_sheet_pilot.max_alpha_deg, 90.0, "a nudge (6 degrees a second) does not ease")
	hands.steer = 1.0
	_run(controller, _telemetry(12.0), controls, 0.5)
	assert_eq(controller.auto_sheet_pilot.max_alpha_deg, 9.0, "a real head-up (12 degrees a second) does")


func test_the_pilots_hands_on_the_sheet_are_the_controllers() -> void:
	var controller: PlayerController = PlayerController.new()
	controller.pilot_sheet_rate_per_s = 2.5
	var controls: SimControls = SimControls.new()
	_run(controller, _telemetry(12.0), controls, 0.1)
	assert_eq(controller.auto_sheet_pilot.sheet_rate_per_s, 2.5, "set on the pilot")
	controller.reset_controls(controls)
	_run(controller, _telemetry(12.0), controls, 0.1)
	assert_eq(controller.auto_sheet_pilot.sheet_rate_per_s, 2.5, "and on the new pilot after a reset")
	controller.pilot_overrides["sheet_rate_per_s"] = 1.0
	_run(controller, _telemetry(12.0), controls, 0.1)
	assert_eq(controller.auto_sheet_pilot.sheet_rate_per_s, 1.0, "an override still wins")


func test_the_defaults_are_the_lake_trainings_choice() -> void:
	# Documentation/reports/autopilot/lake_chop_training.md: round 4's c2hu10, shipped. On the lake's
	# 130 cases of rounds 1 to 3 it fell in none (the controller before: 26), on six other hours in 6 of
	# 180 (before: 29), the open water's push check and matrix as before.
	var controller: PlayerController = PlayerController.new()
	assert_eq(controller.head_up_alpha_deg, 9.0, "the ease while carving up at speed")
	assert_false(controller.head_up_ease_on_hold, "for a key or a tack, not the hold's corrections")
	assert_eq(controller.head_up_ease_from_dps, 10.0, "from a real head-up")
	assert_eq(controller.rail_from_ms, 2.0, "no rail at walking pace")
	assert_eq(controller.rail_full_ms, 5.0)
	assert_eq(controller.airborne_alpha_deg, 6.0, "the ease in the air")
	assert_eq(controller.airborne_sheet_in_share, 3.0, "back in faster on landing")
	assert_eq(controller.airborne_wind_from_kt, 18.0, "only in strong wind")
	assert_eq(controller.airborne_wind_full_kt, 20.0)
	assert_eq(controller.airborne_bounce_from_dps, 8.0, "and in short chop")
	assert_eq(controller.airborne_bounce_full_dps, 12.0)
	assert_eq(controller.chop_hike_drop, 0.0, "less pull in chop: not used (it cost the afternoons 2.6 kt)")
	assert_eq(controller.manoeuvre_wait_max_s, 0.0, "waiting for the wave: not used (it changed nothing)")
	assert_eq(controller.pilot_sheet_rate_per_s, 1.5, "the pilot's own hands (faster cost the pushed broad reach at 24 kt)")
