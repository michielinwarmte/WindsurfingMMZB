extends GutTest
## The keys become sheet, rake, rig tilt and lean the way PHYSICS_SPEC.md section 10 and
## the Helm say, on both tacks. The tests press the actions through the Input singleton.

const DT: float = 1.0 / 60.0


func after_each() -> void:
	for action: String in ["sheet_in", "sheet_out", "steer_left", "steer_right", "tilt_left", "tilt_right", "rake_back", "rake_forward", "tack", "toggle_mode", "push_more", "push_less"]:
		Input.action_release(action)


func _telemetry(twa_deg: float) -> Telemetry:
	var t: Telemetry = Telemetry.new()
	t.twa_deg = twa_deg
	t.awa_deg = twa_deg
	t.sail_side = -1 if twa_deg >= 0.0 else 1  # the boom is on the leeward side
	return t


func _run(controller: PlayerController, telemetry: Telemetry, controls: SimControls, seconds: float) -> void:
	for i: int in int(seconds / DT):
		controller.update(telemetry, controls, DT)


func test_sheet_keys_move_the_sheet_at_a_human_pace() -> void:
	var controller: PlayerController = PlayerController.new()
	var controls: SimControls = SimControls.new()
	controls.sheet = 0.0
	Input.action_press("sheet_in")
	_run(controller, _telemetry(90.0), controls, 0.5)
	assert_almost_eq(controls.sheet, 0.3, 0.02, "0.6 per second")
	Input.action_release("sheet_in")
	Input.action_press("sheet_out")
	_run(controller, _telemetry(90.0), controls, 2.0)
	assert_eq(controls.sheet, 0.0, "fully eased, never below zero")


func test_beginner_mode_has_the_auto_sheet_on_and_the_keys_override_it() -> void:
	var controller: PlayerController = PlayerController.new()
	assert_true(controller.auto_sheet, "beginners get the sheet trimmed for them")
	var controls: SimControls = SimControls.new()
	controls.sheet = 0.0
	var t: Telemetry = _telemetry(90.0)
	t.awa_deg = 40.0
	var trimmed: float = 1.0 - ((40.0 - 15.0) - 12.0) / 73.0  # boom 25 degrees: 15 degrees of angle of attack
	_run(controller, t, controls, 3.0)
	assert_almost_eq(controls.sheet, trimmed, 0.05, "trimmed to 15 degrees of angle of attack")
	Input.action_press("sheet_out")
	_run(controller, t, controls, 1.0)
	Input.action_release("sheet_out")
	assert_lt(controls.sheet, 0.4, "S eases it")
	_run(controller, t, controls, 1.0)
	assert_lt(controls.sheet, 0.4, "and the auto-sheet waits a few seconds")
	_run(controller, t, controls, 4.0)
	assert_almost_eq(controls.sheet, trimmed, 0.05, "then trims again")


func test_overpowered_beginner_eases_the_sheet() -> void:
	var controller: PlayerController = PlayerController.new()
	controller.auto_sheet = false
	var controls: SimControls = SimControls.new()
	var t: Telemetry = _telemetry(90.0)
	Input.action_press("sheet_in")
	_run(controller, t, controls, 2.0)
	Input.action_release("sheet_in")
	assert_almost_eq(controls.sheet, 1.0, 1e-6)
	t.lean = 0.95  # hiked out to the limit
	_run(controller, t, controls, 0.5)
	assert_lt(controls.sheet, 0.6, "the sailor lets the sail out rather than going over it")
	t.lean = 0.3
	_run(controller, t, controls, 3.0)
	assert_almost_eq(controls.sheet, 1.0, 0.01, "and sheets back in when the pull is bearable")
	controller.set_mode(PlayerController.Mode.ADVANCED)
	controller.auto_sheet = false
	t.lean = 0.95
	_run(controller, t, controls, 2.0)
	assert_almost_eq(controls.sheet, 1.0, 1e-6, "advanced sailors are on their own")


func test_beginner_turn_key_moves_the_whole_helm_the_right_way_on_both_tacks() -> void:
	# Starboard tack: a right turn is heading up, so D means rig back, rig tilted to port
	# (the outside of the turn) and weight to starboard (the inside rail). The telemetry is a board at
	# rest, and the rail fades in with speed since the lake's training (PlayerController.rail_from_ms,
	# rail_full_ms): this test of the directions has the rail at every speed (rail_full_ms 0).
	var controller: PlayerController = PlayerController.new()
	controller.rail_full_ms = 0.0
	var controls: SimControls = SimControls.new()
	Input.action_press("steer_right")
	_run(controller, _telemetry(90.0), controls, 0.6)
	assert_gt(controls.rake, 0.5, "starboard tack, right: rig back")
	assert_lt(controls.rig_tilt, -0.5, "rig tilted to port, the outside of a right turn")
	assert_gt(controls.lean, 0.2, "weight to starboard, the inside rail")
	Input.action_release("steer_right")
	# Port tack: a right turn is bearing away, so the rig goes forward; tilt and weight as before.
	var port: PlayerController = PlayerController.new()
	port.rail_full_ms = 0.0
	var port_controls: SimControls = SimControls.new()
	Input.action_press("steer_right")
	_run(port, _telemetry(-90.0), port_controls, 0.6)
	assert_lt(port_controls.rake, -0.5, "port tack, right: rig forward")
	assert_lt(port_controls.rig_tilt, -0.5)
	assert_gt(port_controls.lean, 0.2)
	Input.action_release("steer_right")
	# A left turn mirrors all three.
	var left: PlayerController = PlayerController.new()
	left.rail_full_ms = 0.0
	var left_controls: SimControls = SimControls.new()
	Input.action_press("steer_left")
	_run(left, _telemetry(90.0), left_controls, 0.6)
	assert_lt(left_controls.rake, -0.5, "starboard tack, left: bear away, rig forward")
	assert_gt(left_controls.rig_tilt, 0.5, "rig to starboard, the outside of a left turn")
	assert_lt(left_controls.lean, -0.2, "weight to port")


func test_beginner_loop_eases_the_helm_once_the_board_turns_as_asked() -> void:
	# While the board does not respond the trim winds up; when it turns at the asked rate the
	# proportional part vanishes and the helm stops growing.
	var controller: PlayerController = PlayerController.new()
	var controls: SimControls = SimControls.new()
	var t: Telemetry = _telemetry(90.0)
	Input.action_press("steer_right")
	_run(controller, t, controls, 0.3)
	var pushing: float = controller.helm_right
	t.yaw_rate_dps = -controller.turn_rate_dps  # turning right at exactly the asked rate
	_run(controller, t, controls, 0.3)
	var settled: float = controller.helm_right
	assert_lt(settled, pushing, "the proportional push is gone once the board turns as asked")
	_run(controller, t, controls, 0.3)
	assert_almost_eq(controller.helm_right, settled, 1e-6, "and the trim stops growing")


func test_beginner_mode_holds_the_heading_when_no_key_is_pressed() -> void:
	var controller: PlayerController = PlayerController.new()
	var controls: SimControls = SimControls.new()
	# Starboard tack, heading South, rounded up to 195 (a right turn): the loop asks for a
	# left turn, which on starboard tack is bearing away: rig forward.
	var t: Telemetry = _telemetry(90.0)
	t.heading_deg = 180.0
	_run(controller, t, controls, 0.2)
	t.heading_deg = 195.0
	t.twa_deg = 75.0
	_run(controller, t, controls, 1.5)
	assert_lt(controls.rake, -0.4, "starboard tack: rounded up, so the rig goes forward")
	assert_gt(controls.rig_tilt, 0.3, "and tilts to starboard, the outside of the left turn")
	# Port tack, heading North, rounded up to 345 (a left turn): a right turn is asked, which
	# on port tack is bearing away: rig forward again, tilt to port.
	var port: PlayerController = PlayerController.new()
	var port_controls: SimControls = SimControls.new()
	var p: Telemetry = _telemetry(-90.0)
	p.heading_deg = 0.0
	_run(port, p, port_controls, 0.2)
	p.heading_deg = 345.0
	p.twa_deg = -75.0
	_run(port, p, port_controls, 1.5)
	assert_lt(port_controls.rake, -0.4, "port tack: rounded up, so the rig goes forward")
	assert_lt(port_controls.rig_tilt, -0.3)


func test_advanced_mode_rakes_with_q_and_e_tilts_with_the_arrows_and_shifts_weight_with_a_and_d() -> void:
	var controller: PlayerController = PlayerController.new()
	controller.set_mode(PlayerController.Mode.ADVANCED)
	var controls: SimControls = SimControls.new()
	Input.action_press("rake_back")
	_run(controller, _telemetry(-90.0), controls, 0.6)
	assert_gt(controls.rake, 0.9, "E is rig back on either tack")
	Input.action_release("rake_back")
	Input.action_press("steer_right")
	_run(controller, _telemetry(-90.0), controls, 1.0)
	assert_almost_eq(controls.lean, 1.0, 1e-6, "D moves the weight to starboard")
	assert_almost_eq(controls.rake, 0.0, 1e-6, "and does not steer with the rig")
	Input.action_release("steer_right")
	Input.action_press("tilt_left")
	_run(controller, _telemetry(-90.0), controls, 1.0)
	assert_almost_eq(controls.rig_tilt, -1.0, 1e-6, "the left arrow tilts the rig to port")


func test_space_starts_a_tack_upwind_and_a_gybe_downwind() -> void:
	var controller: PlayerController = PlayerController.new()
	var controls: SimControls = SimControls.new()
	Input.action_press("tack")
	controller.update(_telemetry(60.0), controls, DT)
	Input.action_release("tack")
	assert_eq(controller.manoeuvre, PlayerController.Manoeuvre.TACK_HEADING_UP)
	_run(controller, _telemetry(60.0), controls, 2.5)
	assert_gt(controls.rake, 0.7, "rig back to head up")
	assert_lt(controls.rig_tilt, -0.7, "rig to port, the outside of the right turn")
	# Through the wind: once the rig has flipped the turn goes on, now bearing away.
	_run(controller, _telemetry(-20.0), controls, 0.1)
	assert_eq(controller.manoeuvre, PlayerController.Manoeuvre.TACK_BEARING_AWAY)
	_run(controller, _telemetry(-30.0), controls, 2.5)
	assert_lt(controls.rake, -0.7, "rig forward to bear away on the new tack")
	_run(controller, _telemetry(-70.0), controls, 0.1)
	assert_eq(controller.manoeuvre, PlayerController.Manoeuvre.NONE, "done past 60 degrees")

	var downwind: PlayerController = PlayerController.new()
	Input.action_press("tack")
	downwind.update(_telemetry(140.0), controls, DT)
	Input.action_release("tack")
	assert_eq(downwind.manoeuvre, PlayerController.Manoeuvre.GYBE_BEARING_AWAY)


func test_a_manoeuvre_that_never_completes_is_abandoned() -> void:
	var controller: PlayerController = PlayerController.new()
	var controls: SimControls = SimControls.new()
	Input.action_press("tack")
	controller.update(_telemetry(60.0), controls, DT)
	Input.action_release("tack")
	_run(controller, _telemetry(60.0), controls, 21.0)
	assert_eq(controller.manoeuvre, PlayerController.Manoeuvre.NONE)


func test_ai_hands_drive_the_beginner_controller_like_the_keys() -> void:
	# An AI skipper's stick turns the board as the key does, and its tack request is taken once.
	var controller: PlayerController = PlayerController.new()
	var hands: AiHands = AiHands.new()
	controller.hands = hands
	var controls: SimControls = SimControls.new()
	Input.action_press("steer_left")  # the keyboard is ignored while the hands are on
	hands.steer = 1.0
	_run(controller, _telemetry(90.0), controls, 0.5)
	assert_true(controller.wanted_rate_dps > 5.0, "the stick asks for a right turn: %.1f deg/s" % controller.wanted_rate_dps)
	assert_true(controller.helm_right > 0.0, "the helm goes right, not left as the ignored key asks")
	hands.steer = 0.0
	_run(controller, _telemetry(90.0), controls, 1.0)
	assert_true(absf(controller.wanted_rate_dps) < 5.0, "the stick released, the heading is held")
	hands.tack = true
	controller.update(_telemetry(60.0), controls, DT)
	assert_true(controller.manoeuvre != PlayerController.Manoeuvre.NONE, "a tack request starts a manoeuvre")
	assert_false(hands.tack, "the request is taken once")
	# Half a stick is a gentle turn: the rate is half the full rate.
	var gentle: PlayerController = PlayerController.new()
	var gentle_hands: AiHands = AiHands.new()
	gentle.hands = gentle_hands
	gentle_hands.steer = 0.5
	var gentle_controls: SimControls = SimControls.new()
	_run(gentle, _telemetry(90.0), gentle_controls, 0.5)
	assert_almost_eq(gentle.wanted_rate_dps, 0.5 * gentle.turn_rate_dps, 1.0, "half the stick, half the rate")


func test_the_push_keys_move_the_slider_at_a_human_pace_and_set_the_pilot() -> void:
	var controller: PlayerController = PlayerController.new()
	var controls: SimControls = SimControls.new()
	controller.push_level = 0.75
	Input.action_press("push_more")
	_run(controller, _telemetry(90.0), controls, 0.5)
	Input.action_release("push_more")
	assert_almost_eq(controller.push_level, 0.95, 0.02, "0.4 per second: a full range in 2.5 s")
	var curve: PushCurveConfig = PushDial.default_curve()
	assert_almost_eq(controller.auto_sheet_pilot.hike_share, curve.at(curve.hike_share, controller.push_level), 1e-6, "the pilot holds the ladder's pull")
	assert_almost_eq(controller.auto_sheet_pilot.back_foot_bias, curve.at(curve.back_foot_push, controller.push_level), 1e-6, "and the fin's push")
	assert_gt(controls.rig_lean_extra_deg, 0.0, "the controls carry the rig's extra lean")
	Input.action_press("push_less")
	_run(controller, _telemetry(90.0), controls, 5.0)
	Input.action_release("push_less")
	assert_eq(controller.push_level, 0.0, "never below 0")
	assert_almost_eq(controller.auto_sheet_pilot.drive_share, 0.0, 1e-9, "at 0 % the sail is let fly")
	assert_eq(controls.rig_lean_extra_deg, 0.0, "and the technique is its own again")


func test_without_a_slider_the_pilot_keeps_its_own_numbers() -> void:
	var controller: PlayerController = PlayerController.new()
	var controls: SimControls = SimControls.new()
	var hike_before: float = controller.auto_sheet_pilot.hike_share
	Input.action_press("push_more")
	_run(controller, _telemetry(90.0), controls, 0.5)
	Input.action_release("push_more")
	assert_true(is_nan(controller.push_level), "NaN: no slider, the keys do nothing")
	assert_eq(controller.auto_sheet_pilot.hike_share, hike_before, "the pilot's own margin")
	assert_eq(controls.rig_lean_extra_deg, 0.0)
	assert_eq(controls.back_foot_push, 0.0)


func test_ai_hands_set_the_slider_or_leave_it_alone() -> void:
	var controller: PlayerController = PlayerController.new()
	var hands: AiHands = AiHands.new()
	controller.hands = hands
	var controls: SimControls = SimControls.new()
	_run(controller, _telemetry(90.0), controls, 0.1)
	assert_true(is_nan(controller.push_level), "hands that say nothing leave the controller as before")
	hands.push = 0.85
	_run(controller, _telemetry(90.0), controls, 0.1)
	assert_almost_eq(controller.push_level, 0.85, 1e-9)
	assert_almost_eq(controller.auto_sheet_pilot.hike_share, 1.3, 1e-6, "85 %: the pull held 1.3")
	assert_almost_eq(controls.rig_lean_extra_deg, 3.0, 1e-6, "and three degrees more lean")


func test_the_slider_survives_a_waterstart_and_the_legs_follow_the_helm() -> void:
	var controller: PlayerController = PlayerController.new()
	var controls: SimControls = SimControls.new()
	controller.push_level = 0.85
	controller.legs_share = 0.5
	var t: Telemetry = _telemetry(90.0)
	t.stance = 1.0
	Input.action_press("steer_right")  # heading up on starboard tack
	_run(controller, t, controls, 1.0)
	Input.action_release("steer_right")
	assert_gt(controls.back_foot_push, 0.3, "the back foot pushes the tail to leeward to head up")
	controller.reset_controls(controls)
	assert_almost_eq(controller.push_level, 0.85, 1e-9, "the level is kept through a waterstart")
	assert_eq(controls.back_foot_push, 0.0, "the controls start clean")


func test_the_controller_adds_the_seas_rail_to_the_sliders() -> void:
	var controller: PlayerController = PlayerController.new()
	var controls: SimControls = SimControls.new()
	controller.push_level = 0.85  # no rail from the ladder, three degrees for the sea
	var t: Telemetry = _telemetry(90.0)
	for i: int in 600:
		t.time_s = i / 60.0
		t.pitch_rate_dps = 14.0 if i % 2 == 0 else -14.0  # wild
		controller.update(t, controls, DT)
	assert_almost_eq(controls.rail_bank_extra_deg, 3.0, 0.05, "the sea's three degrees")
	for i: int in 900:
		t.time_s = 10.0 + i / 60.0
		t.pitch_rate_dps = 0.0  # flat
		controller.update(t, controls, DT)
	assert_almost_eq(controls.rail_bank_extra_deg, 0.0, 0.05, "none again on flat water")
	# An override of the pilot's sea rail counts (the harnesses switch it off that way).
	controller.pilot_overrides["wave_rail_max_deg"] = 0.0
	for i: int in 600:
		t.time_s = 25.0 + i / 60.0
		t.pitch_rate_dps = 14.0 if i % 2 == 0 else -14.0
		controller.update(t, controls, DT)
	assert_almost_eq(controls.rail_bank_extra_deg, 0.0, 1e-6, "switched off by the override")


func test_planing_in_the_straps_the_legs_push_the_turn_first() -> void:
	# The planing technique (Documentation/reports/push_slider/steering.md): above 35 to 40 km/h
	# with the feet in the straps a turn is pushed with the legs first, the back foot to head up and
	# the front foot to bear away, on either tack. Below it the legs are left as they were.
	var cases: Array[Array] = [[90.0, "steer_right", 1.0], [90.0, "steer_left", -1.0], [-90.0, "steer_left", 1.0], [-90.0, "steer_right", -1.0]]
	for c: Array in cases:
		var controller: PlayerController = PlayerController.new()
		var controls: SimControls = SimControls.new()
		var t: Telemetry = _telemetry(c[0])
		t.stance = 1.0
		t.speed_ms = 14.0
		Input.action_press(c[1])
		_run(controller, t, controls, 0.6)
		Input.action_release(c[1])
		assert_almost_eq(controls.back_foot_push, c[2], 1e-6, "TWA %.0f, %s: a full push, %s" % [c[0], c[1], "the back foot" if c[2] > 0.0 else "the front foot"])
	var slow: PlayerController = PlayerController.new()
	var slow_controls: SimControls = SimControls.new()
	var s: Telemetry = _telemetry(90.0)
	s.stance = 1.0
	s.speed_ms = 8.0  # the 12 kt reach, 29 km/h
	Input.action_press("steer_right")
	_run(slow, s, slow_controls, 0.6)
	assert_eq(slow_controls.back_foot_push, 0.0, "below the plane the rig and the rail steer, as before")


## The push on W and S, the sheet on the arrows Up and Down (the evening play-test of 6 November
## 2026), in the input map and on the screen's key line, sailing free and racing.
func test_the_push_is_on_w_and_s_and_the_sheet_on_the_arrows() -> void:
	assert_eq(_key_of("push_more"), KEY_W)
	assert_eq(_key_of("push_less"), KEY_S)
	assert_eq(_key_of("sheet_in"), KEY_UP)
	assert_eq(_key_of("sheet_out"), KEY_DOWN)
	var hud: Hud = Hud.new()
	add_child_autofree(hud)
	for racing: bool in [false, true]:
		hud.set_race_mode(racing)
		assert_string_contains(hud.help_text(), "W S push")
		assert_string_contains(hud.help_text(), "↑ ↓ sheet")


## The one key an action has in the input map (project.godot).
func _key_of(action: String) -> Key:
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	assert_eq(events.size(), 1, action)
	var key: InputEventKey = events[0] as InputEventKey if not events.is_empty() else null
	return key.physical_keycode if key != null else KEY_NONE


## Max, 6 November 2026: "downwind button (a/d) while pressing space to gybe instead of heading".
## Space with A or D held: toward the wind a tack, away from it a gybe, on both tacks and from
## either side of the beam reach (where the heading alone picks the other one).
func test_space_with_a_turn_key_tacks_toward_the_wind_and_gybes_away_from_it() -> void:
	# [true wind angle, key, the manoeuvre]. Starboard tack (+): D (right) heads up; port tack (-): A.
	var cases: Array[Array] = [
		[90.0, "steer_right", PlayerController.Manoeuvre.TACK_HEADING_UP],
		[90.0, "steer_left", PlayerController.Manoeuvre.GYBE_BEARING_AWAY],
		[-90.0, "steer_left", PlayerController.Manoeuvre.TACK_HEADING_UP],
		[-90.0, "steer_right", PlayerController.Manoeuvre.GYBE_BEARING_AWAY],
		# Near the beam reach the heading alone would tack at 95 and gybe at 105.
		[95.0, "steer_left", PlayerController.Manoeuvre.GYBE_BEARING_AWAY],
		[-95.0, "steer_right", PlayerController.Manoeuvre.GYBE_BEARING_AWAY],
		[105.0, "steer_right", PlayerController.Manoeuvre.TACK_HEADING_UP],
		[-105.0, "steer_left", PlayerController.Manoeuvre.TACK_HEADING_UP],
		# From any course: a gybe from close-hauled, a tack from a broad reach.
		[50.0, "steer_left", PlayerController.Manoeuvre.GYBE_BEARING_AWAY],
		[-150.0, "steer_left", PlayerController.Manoeuvre.TACK_HEADING_UP],
	]
	for c: Array in cases:
		var controller: PlayerController = PlayerController.new()
		var controls: SimControls = SimControls.new()
		var telemetry: Telemetry = _telemetry(c[0])
		controller.update(telemetry, controls, DT)  # the tack is known before Space
		Input.action_press(c[1])
		Input.action_press("tack")
		controller.update(telemetry, controls, DT)
		Input.action_release("tack")
		Input.action_release(c[1])
		assert_eq(controller.manoeuvre, c[2], "TWA %.0f with %s" % [c[0], c[1]])
	assert_eq(PlayerController.manoeuvre_for_turn(1.0, 1.0), PlayerController.Manoeuvre.TACK_HEADING_UP, "right on starboard: toward the wind")
	assert_eq(PlayerController.manoeuvre_for_turn(1.0, -1.0), PlayerController.Manoeuvre.GYBE_BEARING_AWAY, "right on port: away from it")


## Space alone keeps the heading's rule, and A or D pressed within the grace window after it still
## decides; a key pressed later does not turn the manoeuvre into the other one.
func test_a_turn_key_just_after_space_still_chooses() -> void:
	var controller: PlayerController = PlayerController.new()
	var controls: SimControls = SimControls.new()
	var beam: Telemetry = _telemetry(90.0)
	controller.update(beam, controls, DT)
	Input.action_press("tack")
	controller.update(beam, controls, DT)
	Input.action_release("tack")
	assert_eq(controller.manoeuvre, PlayerController.Manoeuvre.TACK_HEADING_UP, "Space alone at a beam reach: the heading's rule, a tack")
	_run(controller, beam, controls, 0.2)
	Input.action_press("steer_left")  # away from the wind on starboard tack, 0.2 s after Space
	controller.update(beam, controls, DT)
	assert_eq(controller.manoeuvre, PlayerController.Manoeuvre.GYBE_BEARING_AWAY, "A within the grace window: a gybe")
	Input.action_release("steer_left")

	var late: PlayerController = PlayerController.new()
	var broad: Telemetry = _telemetry(-140.0)
	late.update(broad, controls, DT)
	Input.action_press("tack")
	late.update(broad, controls, DT)
	Input.action_release("tack")
	assert_eq(late.manoeuvre, PlayerController.Manoeuvre.GYBE_BEARING_AWAY, "Space alone at a broad reach: a gybe")
	_run(late, broad, controls, 0.5)
	Input.action_press("steer_left")  # toward the wind on port tack, but 0.5 s after Space
	late.update(broad, controls, DT)
	assert_ne(late.manoeuvre, PlayerController.Manoeuvre.TACK_HEADING_UP, "too late to turn the gybe into a tack")


## An AI skipper's hands keep the heading's rule whatever the stick does: the fleet's manoeuvres
## stay as they were.
func test_ai_hands_keep_the_headings_rule_for_space() -> void:
	var controller: PlayerController = PlayerController.new()
	var hands: AiHands = AiHands.new()
	controller.hands = hands
	var controls: SimControls = SimControls.new()
	var beam: Telemetry = _telemetry(90.0)
	controller.update(beam, controls, DT)
	hands.steer = -1.0  # away from the wind on starboard tack
	hands.tack = true
	controller.update(beam, controls, DT)
	assert_eq(controller.manoeuvre, PlayerController.Manoeuvre.TACK_HEADING_UP, "the hands' stick does not choose")
	_run(controller, beam, controls, 0.1)
	assert_eq(controller.manoeuvre, PlayerController.Manoeuvre.TACK_HEADING_UP, "nor just after")


## Starts a manoeuvre on this course with this key held at Space (the key stays held; "" none).
func _start(controller: PlayerController, controls: SimControls, telemetry: Telemetry, key: String) -> void:
	controller.update(telemetry, controls, DT)
	if key != "":
		Input.action_press(key)
	Input.action_press("tack")
	controller.update(telemetry, controls, DT)
	Input.action_release("tack")


## The interactive tacks and gybes (Max, 6 November 2026), part 1: the turn key held toward the turn
## tightens it, let go the turn goes on at its own rate, on both kinds of manoeuvre.
func test_the_turn_key_toward_the_turn_tightens_it() -> void:
	var controller: PlayerController = PlayerController.new()
	var controls: SimControls = SimControls.new()
	var broad: Telemetry = _telemetry(140.0)  # starboard tack: A turns away from the wind
	_start(controller, controls, broad, "steer_left")
	assert_eq(controller.manoeuvre, PlayerController.Manoeuvre.GYBE_BEARING_AWAY)
	_run(controller, broad, controls, 0.3)
	assert_almost_eq(controller.wanted_rate_dps, -controller.key_gybe_rate_dps, 0.01, "A held: the gybe at the key's rate, to the left")
	Input.action_release("steer_left")
	_run(controller, broad, controls, 0.1)
	assert_almost_eq(controller.wanted_rate_dps, -controller.gybe_rate_dps, 0.01, "let go: the gybe's own rate")

	var tacking: PlayerController = PlayerController.new()
	var close: Telemetry = _telemetry(60.0)
	_start(tacking, controls, close, "steer_right")
	assert_eq(tacking.manoeuvre, PlayerController.Manoeuvre.TACK_HEADING_UP)
	_run(tacking, close, controls, 0.3)
	assert_almost_eq(tacking.wanted_rate_dps, tacking.key_tack_rate_dps, 0.01, "D held: the tack's carve at the key's rate")
	Input.action_release("steer_right")
	_run(tacking, close, controls, 0.1)
	assert_almost_eq(tacking.wanted_rate_dps, tacking.tack_rate_dps, 0.01, "let go: the tack's own rate")

	var off: PlayerController = PlayerController.new()
	off.turn_follows_key = false
	_start(off, controls, broad, "steer_left")
	_run(off, broad, controls, 0.3)
	assert_almost_eq(off.wanted_rate_dps, -off.gybe_rate_dps, 0.01, "the setting off: the key changes nothing")


## Part 1: the other key, after the choosing window, gives the manoeuvre up and steers as on a reach.
func test_the_other_key_gives_the_manoeuvre_up() -> void:
	var controller: PlayerController = PlayerController.new()
	var controls: SimControls = SimControls.new()
	var broad: Telemetry = _telemetry(140.0)
	_start(controller, controls, broad, "steer_left")
	Input.action_release("steer_left")
	_run(controller, broad, controls, 0.5)
	assert_eq(controller.manoeuvre, PlayerController.Manoeuvre.GYBE_BEARING_AWAY)
	Input.action_press("steer_right")  # toward the wind: against the gybe
	_run(controller, broad, controls, 0.3)
	assert_eq(controller.manoeuvre, PlayerController.Manoeuvre.NONE, "the gybe is given up")
	assert_gt(controller.wanted_rate_dps, 5.0, "and D turns the board right, back toward the wind")
	Input.action_release("steer_right")

	var off: PlayerController = PlayerController.new()
	off.turn_follows_key = false
	_start(off, controls, broad, "steer_left")
	Input.action_release("steer_left")
	_run(off, broad, controls, 0.5)
	Input.action_press("steer_right")
	_run(off, broad, controls, 0.3)
	assert_eq(off.manoeuvre, PlayerController.Manoeuvre.GYBE_BEARING_AWAY, "the setting off: the gybe goes on")


## Part 2: the mouse body toward the inside of the turn carves harder, toward the outside flattens,
## and the back foot presses through the turn; the body keeps its place until the manoeuvre's end.
func test_the_body_carves_the_manoeuvre() -> void:
	# [the mouse sideways, the carve: +1 harder, -1 flatter]. A gybe from starboard tack turns left:
	# as seen from behind, the mouse to the left puts the inside (port) rail down.
	for c: Array in [[-1.0, 1.0], [0.0, 0.0], [1.0, -1.0]]:
		var controller: PlayerController = PlayerController.new()
		var controls: SimControls = SimControls.new()
		controller.body = MouseBody.new()
		controller.body.side = c[0]
		controller.body.back = 1.0
		var broad: Telemetry = _telemetry(140.0)
		_start(controller, controls, broad, "")
		assert_eq(controller.manoeuvre, PlayerController.Manoeuvre.GYBE_BEARING_AWAY)
		_run(controller, broad, controls, 0.3)
		assert_almost_eq(controller.wanted_rate_dps, -minf(controller.gybe_rate_dps * (1.0 + controller.body_carve_share * c[1]), controller.gybe_rate_max_dps), 0.01, "mouse at %+.0f" % c[0])
		assert_almost_eq(controls.feet_pitch_press, 1.0, 1e-6, "the back foot presses in the gybe")
		assert_almost_eq(controller.body.side, c[0], 1e-6, "the body keeps its place through the gybe")
		# Round onto port tack: the way out at the gybe's own rate, then the body goes back to the middle.
		_run(controller, _telemetry(-150.0), controls, 0.1)
		assert_almost_eq(controller.wanted_rate_dps, -controller.gybe_rate_dps, 0.01, "the exit at its own rate")
		_run(controller, _telemetry(-110.0), controls, 0.1)
		assert_eq(controller.manoeuvre, PlayerController.Manoeuvre.NONE)
		assert_almost_eq(controller.body.side, 0.0, 1e-6, "back to the middle at the gybe's end")
	# A tack from starboard tack turns right: the mouse to the right carves it (the heels).
	var tacking: PlayerController = PlayerController.new()
	var tack_controls: SimControls = SimControls.new()
	tacking.body = MouseBody.new()
	tacking.body.side = 1.0
	tacking.body.back = 1.0
	_start(tacking, tack_controls, _telemetry(60.0), "")
	_run(tacking, _telemetry(60.0), tack_controls, 0.3)
	assert_almost_eq(tacking.wanted_rate_dps, minf(tacking.tack_rate_dps * (1.0 + tacking.body_carve_share), tacking.tack_rate_max_dps), 0.01, "the tack carved harder, up to its limit")
	assert_gt(tacking.wanted_rate_dps, tacking.tack_rate_dps, "harder than on its own")
	assert_eq(tack_controls.feet_pitch_press, 0.0, "no back foot in a tack")
	# The setting off: the body rests in the turn, as before.
	var off: PlayerController = PlayerController.new()
	var off_controls: SimControls = SimControls.new()
	off.body_in_manoeuvres = false
	off.body = MouseBody.new()
	off.body.side = -1.0
	off.body.back = 1.0
	_start(off, off_controls, _telemetry(140.0), "")
	assert_almost_eq(off.body.side, 0.0, 1e-6, "back to the middle at Space, as before")
	_run(off, _telemetry(140.0), off_controls, 0.3)
	assert_almost_eq(off.wanted_rate_dps, -off.gybe_rate_dps, 0.01)
	assert_eq(off_controls.feet_pitch_press, 0.0)


## Part 3: in the window before the rig goes across by itself a second Space puts it across now; the
## window opens near dead downwind in a gybe and once the bow is through the wind in a tack.
func test_a_second_space_flips_the_rig_on_cue() -> void:
	var controller: PlayerController = PlayerController.new()
	var controls: SimControls = SimControls.new()
	_start(controller, controls, _telemetry(140.0), "")
	_run(controller, _telemetry(140.0), controls, 0.5)
	assert_false(controller.flip_cue_open(), "a broad reach: too early")
	var near_downwind: Telemetry = _telemetry(177.0)
	_run(controller, near_downwind, controls, 0.1)
	assert_true(controller.flip_cue_open(), "near dead downwind: flip now")
	assert_eq(controls.hold_side, 0, "no cue yet: the wind decides, as before")
	Input.action_press("tack")
	controller.update(near_downwind, controls, DT)
	Input.action_release("tack")
	assert_eq(controls.hold_side, 1, "the cue: the rig held on the new (starboard) side")
	assert_false(controller.flip_cue_open(), "one cue a manoeuvre")
	# The sail across and the wind behind it on the new side: the hold lets go.
	var across: Telemetry = _telemetry(-170.0)
	_run(controller, across, controls, 0.1)
	assert_eq(controls.hold_side, 0, "across and kept there by the wind")

	var tacking: PlayerController = PlayerController.new()
	var tack_controls: SimControls = SimControls.new()
	_start(tacking, tack_controls, _telemetry(60.0), "")
	var through: Telemetry = _telemetry(60.0)
	through.awa_deg = -30.0  # the apparent wind on the new side, wide enough for the sail to fill there
	through.twa_at_sail_deg = -10.0  # the bow 10 degrees through the wind: too early
	tacking.update(through, tack_controls, DT)
	assert_false(tacking.flip_cue_open(), "10 degrees through: not yet")
	through.twa_at_sail_deg = -20.0  # 20 degrees through, the rig still on the old side
	tacking.update(through, tack_controls, DT)
	assert_true(tacking.flip_cue_open(), "the bow through the wind: flip now")
	through.awa_deg = -8.0
	tacking.update(through, tack_controls, DT)
	assert_false(tacking.flip_cue_open(), "the sail would luff on the new side: not yet")
	through.awa_deg = -30.0
	tacking.update(through, tack_controls, DT)
	Input.action_press("tack")
	tacking.update(through, tack_controls, DT)
	Input.action_release("tack")
	assert_lt(tacking.auto_sheet_pilot.flip_twa_deg, 20.0, "the cue: the pilot flips the rig now, where the bow is")
	# Round onto the new tack and out of it: the pilot's own flip angle comes back.
	_run(tacking, _telemetry(-30.0), tack_controls, 0.1)
	_run(tacking, _telemetry(-70.0), tack_controls, 0.1)
	assert_eq(tacking.manoeuvre, PlayerController.Manoeuvre.NONE)
	assert_almost_eq(tacking.auto_sheet_pilot.flip_twa_deg, 25.0, 1e-6, "the pilot's own flip angle again")

	var off: PlayerController = PlayerController.new()
	off.flip_on_cue = false
	_start(off, controls, _telemetry(140.0), "")
	_run(off, near_downwind, controls, 0.1)
	assert_false(off.flip_cue_open(), "the setting off: no window")


## An AI skipper's hands sail the manoeuvres as before: the stick does not tighten or give up the
## turn, and there is no flip window.
func test_ai_hands_sail_the_manoeuvres_as_before() -> void:
	var controller: PlayerController = PlayerController.new()
	var hands: AiHands = AiHands.new()
	controller.hands = hands
	var controls: SimControls = SimControls.new()
	var broad: Telemetry = _telemetry(140.0)
	controller.update(broad, controls, DT)
	hands.tack = true
	controller.update(broad, controls, DT)
	assert_eq(controller.manoeuvre, PlayerController.Manoeuvre.GYBE_BEARING_AWAY)
	hands.steer = -1.0  # along the gybe's turn
	_run(controller, broad, controls, 0.3)
	assert_almost_eq(controller.wanted_rate_dps, -controller.gybe_rate_dps, 0.01, "the gybe's own rate")
	hands.steer = 1.0  # against it
	_run(controller, broad, controls, 0.6)
	assert_eq(controller.manoeuvre, PlayerController.Manoeuvre.GYBE_BEARING_AWAY, "not given up")
	_run(controller, _telemetry(177.0), controls, 0.1)
	assert_false(controller.flip_cue_open(), "no flip window for the AI")


## The HUD shows "flip now" first along the bottom while the window is open.
func test_the_hud_shows_flip_now_in_the_window() -> void:
	var hud: Hud = Hud.new()
	add_child_autofree(hud)
	var controller: PlayerController = PlayerController.new()
	var controls: SimControls = SimControls.new()
	_start(controller, controls, _telemetry(140.0), "")
	hud.update_from(Telemetry.new(), controller, "stern", false)
	assert_false(hud.help_text().begins_with("Space flip now"), "not before the window")
	_run(controller, _telemetry(177.0), controls, 0.1)
	hud.update_from(Telemetry.new(), controller, "stern", false)
	assert_true(hud.help_text().begins_with("Space flip now"), hud.help_text())
	hud.update_from(Telemetry.new(), controller, "stern", true)
	assert_false(hud.help_text().begins_with("Space flip now"), "not behind the autopilot")
