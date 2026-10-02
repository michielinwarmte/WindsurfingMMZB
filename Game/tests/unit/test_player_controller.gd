extends GutTest
## The keys become sheet, rake and lean the way PHYSICS_SPEC.md section 10 says, on both
## tacks. The tests press the actions through the Input singleton.

const DT: float = 1.0 / 60.0


func after_each() -> void:
	for action: String in ["sheet_in", "sheet_out", "steer_left", "steer_right", "rake_back", "rake_forward", "tack", "toggle_mode"]:
		Input.action_release(action)


func _telemetry(twa_deg: float) -> Telemetry:
	var t: Telemetry = Telemetry.new()
	t.twa_deg = twa_deg
	t.awa_deg = twa_deg
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


func test_beginner_steering_is_screen_relative_on_both_tacks() -> void:
	var controller: PlayerController = PlayerController.new()
	controller.mode = PlayerController.Mode.BEGINNER
	var controls: SimControls = SimControls.new()
	Input.action_press("steer_right")
	_run(controller, _telemetry(90.0), controls, 0.5)
	assert_gt(controls.rake, 0.9, "starboard tack: right is toward the wind, so the rig goes back")
	controls.rake = 0.0
	_run(controller, _telemetry(-90.0), controls, 0.5)
	assert_lt(controls.rake, -0.9, "port tack: right is away from the wind, so the rig goes forward")
	Input.action_release("steer_right")
	_run(controller, _telemetry(-90.0), controls, 1.0)
	assert_almost_eq(controls.rake, 0.0, 1e-6, "the rig comes back to neutral when the key is released")
	assert_eq(controls.lean, 0.0, "beginner mode leaves the weight to the balance reflex")


func test_beginner_mode_holds_the_heading_when_no_key_is_pressed() -> void:
	var controller: PlayerController = PlayerController.new()
	var controls: SimControls = SimControls.new()
	# Starboard tack, heading South. The board rounds up to 195 (a right turn): the rig
	# must go forward to bring it back.
	var t: Telemetry = _telemetry(90.0)
	t.heading_deg = 180.0
	_run(controller, t, controls, 0.2)
	t.heading_deg = 195.0
	t.twa_deg = 75.0
	_run(controller, t, controls, 0.6)
	assert_lt(controls.rake, -0.5, "starboard tack: rounded up, so the rig goes forward")
	# Port tack, heading North, rounded up to 345 (a left turn): also forward.
	var port: PlayerController = PlayerController.new()
	var p: Telemetry = _telemetry(-90.0)
	p.heading_deg = 0.0
	_run(port, p, controls, 0.2)
	p.heading_deg = 345.0
	p.twa_deg = -75.0
	_run(port, p, controls, 0.6)
	assert_lt(controls.rake, -0.5, "port tack: rounded up, so the rig goes forward")
	# A steering key takes over and the hold re-arms on the new heading afterwards.
	Input.action_press("steer_left")
	_run(port, p, controls, 1.2)
	Input.action_release("steer_left")
	assert_gt(controls.rake, 0.5, "port tack, left is toward the wind: rig back")
	_run(port, p, controls, 1.0)
	assert_almost_eq(controls.rake, 0.0, 0.05, "holding the heading it has now")


func test_beginner_steering_uses_less_rake_at_speed() -> void:
	var controller: PlayerController = PlayerController.new()
	var controls: SimControls = SimControls.new()
	var fast: Telemetry = _telemetry(90.0)
	fast.speed_ms = 10.0
	Input.action_press("steer_right")
	_run(controller, fast, controls, 1.0)
	assert_almost_eq(controls.rake, 0.4, 0.01, "4 m/s over 10 m/s of the full swing")
	var crawling: Telemetry = _telemetry(90.0)
	crawling.speed_ms = 1.0
	_run(controller, crawling, controls, 1.0)
	assert_almost_eq(controls.rake, 1.0, 1e-6, "the full swing below 4 m/s")


func test_advanced_mode_rakes_with_q_and_e_and_shifts_weight_with_a_and_d() -> void:
	var controller: PlayerController = PlayerController.new()
	controller.mode = PlayerController.Mode.ADVANCED
	var controls: SimControls = SimControls.new()
	Input.action_press("rake_back")
	_run(controller, _telemetry(-90.0), controls, 0.5)
	assert_gt(controls.rake, 0.9, "E is rig back on either tack")
	Input.action_release("rake_back")
	Input.action_press("steer_right")
	_run(controller, _telemetry(-90.0), controls, 1.0)
	assert_almost_eq(controls.lean, 1.0, 1e-6, "D moves the weight to starboard")
	assert_almost_eq(controls.rake, 0.0, 1e-6, "and does not steer with the rig")


func test_space_starts_a_tack_upwind_and_a_gybe_downwind() -> void:
	var controller: PlayerController = PlayerController.new()
	var controls: SimControls = SimControls.new()
	Input.action_press("tack")
	controller.update(_telemetry(60.0), controls, DT)
	Input.action_release("tack")
	assert_eq(controller.manoeuvre, PlayerController.Manoeuvre.TACK_HEADING_UP)
	_run(controller, _telemetry(60.0), controls, 0.5)
	assert_gt(controls.rake, 0.9, "rig back to head up")
	# Through the wind: on the new tack and past 5 degrees the rig goes forward.
	_run(controller, _telemetry(-10.0), controls, 0.1)
	assert_eq(controller.manoeuvre, PlayerController.Manoeuvre.TACK_BEARING_AWAY)
	_run(controller, _telemetry(-30.0), controls, 1.0)
	assert_lt(controls.rake, -0.9, "rig forward to bear away on the new tack")
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
	_run(controller, _telemetry(60.0), controls, 11.0)
	assert_eq(controller.manoeuvre, PlayerController.Manoeuvre.NONE)
	assert_almost_eq(controls.rake, 0.0, 1e-6, "the rig is back to neutral")
