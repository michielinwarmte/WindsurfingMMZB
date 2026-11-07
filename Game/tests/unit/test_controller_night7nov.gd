extends GutTest
## The night of 7 November 2026 (Documentation/reports/autopilot/night_7nov/): Shift + A/D carves
## about twice as sharp, a short tap asks for a small smooth turn with little rail, the heading hold
## bears away to get going below the plane, and an AI's hands can hold Shift.

const DT: float = 1.0 / 60.0


func after_each() -> void:
	for action: String in ["steer_left", "steer_right", "steer_sharp", "tack"]:
		Input.action_release(action)


func _telemetry(twa_deg: float, speed_ms: float = 3.0) -> Telemetry:
	var t: Telemetry = Telemetry.new()
	t.twa_deg = twa_deg
	t.awa_deg = twa_deg
	t.speed_ms = speed_ms
	t.sail_side = -1 if twa_deg >= 0.0 else 1
	return t


func _run(controller: PlayerController, telemetry: Telemetry, controls: SimControls, seconds: float) -> void:
	for i: int in int(seconds / DT):
		controller.update(telemetry, controls, DT)


func test_the_input_map_has_shift_for_the_carve() -> void:
	assert_true(InputMap.has_action("steer_sharp"), "Shift + A/D needs the steer_sharp action")


func test_shift_asks_for_about_twice_the_turn_rate() -> void:
	# Bearing away on starboard tack (A, a left turn) at a slow speed: no head-up limit in the way.
	var plain: PlayerController = PlayerController.new()
	var controls: SimControls = SimControls.new()
	Input.action_press("steer_left")
	_run(plain, _telemetry(90.0), controls, 0.6)
	var plain_rate: float = absf(plain.wanted_rate_dps)
	var sharp: PlayerController = PlayerController.new()
	var sharp_controls: SimControls = SimControls.new()
	Input.action_press("steer_sharp")
	_run(sharp, _telemetry(90.0), sharp_controls, 0.6)
	assert_gt(plain_rate, 0.0)
	assert_almost_eq(absf(sharp.wanted_rate_dps), plain_rate * sharp.sharp_turn_factor, 0.5, "Shift: the rate times sharp_turn_factor")


func test_an_ai_can_hold_shift_too() -> void:
	var controller: PlayerController = PlayerController.new()
	var hands: AiHands = AiHands.new()
	controller.hands = hands
	hands.steer = -1.0
	hands.sharp = true
	var controls: SimControls = SimControls.new()
	_run(controller, _telemetry(90.0), controls, 0.6)
	assert_almost_eq(absf(controller.wanted_rate_dps), controller.turn_rate_dps * controller.sharp_turn_factor, 0.5)


func test_a_short_tap_asks_for_a_small_turn_with_little_rail() -> void:
	# A 0.1 s tap ramps to a fraction of the key (steer_rise_s 0.2: half of it), and the rail's share
	# of a key held that briefly is small (tap_rail_full_s), so the weight hardly moves. The ramp is the
	# player's (NIGHT_TUNING); an AI board's fresh controller steers without it.
	var controller: PlayerController = PlayerController.new()
	controller.steer_rise_s = 0.2
	controller.tap_rail_full_s = 0.4
	controller.rail_full_ms = 0.0
	var controls: SimControls = SimControls.new()
	Input.action_press("steer_right")
	var peak_rate: float = 0.0
	var peak_lean: float = 0.0
	for i: int in 6:
		controller.update(_telemetry(90.0), controls, DT)
		peak_rate = maxf(peak_rate, absf(controller.wanted_rate_dps))
		peak_lean = maxf(peak_lean, absf(controls.lean))
	Input.action_release("steer_right")
	for i: int in 30:
		controller.update(_telemetry(90.0), controls, DT)
		peak_lean = maxf(peak_lean, absf(controls.lean))
	assert_lt(peak_rate, controller.turn_rate_dps * 0.7, "a tap asks for part of the rate")
	assert_lt(peak_lean, 0.05, "a tap puts almost no weight on the rail")
	# Held for a second the key gets its full rate and the rail as before.
	var held: PlayerController = PlayerController.new()
	held.rail_full_ms = 0.0
	var held_controls: SimControls = SimControls.new()
	Input.action_press("steer_right")
	_run(held, _telemetry(90.0), held_controls, 1.0)
	assert_gt(held_controls.lean, 0.2, "a held key still rails the turn")


func test_the_ramp_off_gives_the_key_as_it_was() -> void:
	var controller: PlayerController = PlayerController.new()
	controller.steer_rise_s = 0.0
	var controls: SimControls = SimControls.new()
	Input.action_press("steer_left")
	controller.update(_telemetry(90.0), controls, DT)
	assert_almost_eq(absf(controller.wanted_rate_dps), controller.turn_rate_dps, 0.01)


func test_the_hold_bears_away_to_get_going_below_the_plane() -> void:
	# Starboard tack, slow, no key: the hold aims plane_bear_away_deg off the wind, which is a left
	# turn (heading down); fast, it holds the heading as before.
	var controller: PlayerController = PlayerController.new()
	controller.plane_bear_away_deg = 15.0
	var controls: SimControls = SimControls.new()
	var slow: Telemetry = _telemetry(90.0, 2.0)
	slow.heading_deg = 180.0
	controller.update(slow, controls, DT)
	assert_lt(controller.wanted_rate_dps, -1.0, "slow: the hold turns away from the wind")
	var fast_controller: PlayerController = PlayerController.new()
	fast_controller.plane_bear_away_deg = 15.0
	var fast: Telemetry = _telemetry(90.0, 10.0)
	fast.heading_deg = 180.0
	fast_controller.update(fast, controls, DT)
	assert_almost_eq(fast_controller.wanted_rate_dps, 0.0, 0.5, "at speed the hold keeps the heading")
