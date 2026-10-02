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
