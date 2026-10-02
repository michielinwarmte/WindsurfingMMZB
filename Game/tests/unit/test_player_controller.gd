extends GutTest
## The keys become sheet, rake, rig tilt and lean the way PHYSICS_SPEC.md section 10 and
## the Helm say, on both tacks. The tests press the actions through the Input singleton.

const DT: float = 1.0 / 60.0


func after_each() -> void:
	for action: String in ["sheet_in", "sheet_out", "steer_left", "steer_right", "tilt_left", "tilt_right", "rake_back", "rake_forward", "tack", "toggle_mode"]:
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
	# (the outside of the turn) and weight to starboard (the inside rail).
	var controller: PlayerController = PlayerController.new()
	var controls: SimControls = SimControls.new()
	Input.action_press("steer_right")
	_run(controller, _telemetry(90.0), controls, 0.6)
	assert_gt(controls.rake, 0.5, "starboard tack, right: rig back")
	assert_lt(controls.rig_tilt, -0.5, "rig tilted to port, the outside of a right turn")
	assert_gt(controls.lean, 0.2, "weight to starboard, the inside rail")
	Input.action_release("steer_right")
	# Port tack: a right turn is bearing away, so the rig goes forward; tilt and weight as before.
	var port: PlayerController = PlayerController.new()
	var port_controls: SimControls = SimControls.new()
	Input.action_press("steer_right")
	_run(port, _telemetry(-90.0), port_controls, 0.6)
	assert_lt(port_controls.rake, -0.5, "port tack, right: rig forward")
	assert_lt(port_controls.rig_tilt, -0.5)
	assert_gt(port_controls.lean, 0.2)
	Input.action_release("steer_right")
	# A left turn mirrors all three.
	var left: PlayerController = PlayerController.new()
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
