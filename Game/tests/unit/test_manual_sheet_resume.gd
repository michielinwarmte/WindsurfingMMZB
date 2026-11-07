extends GutTest
## The sheet keys and the auto-sheet (Max's recording, 7 November 2026): Up held half a second sheeted
## to 0.85, the sail stalled (48 to 71 degrees of attack) for the 3 s the keys keep the auto-sheet away,
## then the auto-sheet dumped it (0.85 to 0.32 in 0.3 s): "it sheets off totally for no reason". A
## stalled sail ends the hold at once, and the auto-sheet eases back at manual_resume_rate_per_s.

const DT: float = 1.0 / 60.0


func after_each() -> void:
	Input.action_release("sheet_in")


func _telemetry(awa_deg: float, alpha_deg: float) -> Telemetry:
	var t: Telemetry = Telemetry.new()
	t.awa_deg = awa_deg
	t.twa_deg = awa_deg + 20.0
	t.alpha_deg = alpha_deg
	t.speed_ms = 3.0
	t.sail_side = -1
	return t


func _sheeted_in(c: PlayerController, controls: SimControls) -> void:
	c.reset_controls(controls)
	Input.action_press("sheet_in")
	for i: int in 30:
		c.update(_telemetry(60.0, 20.0), controls, DT)
	Input.action_release("sheet_in")


func test_the_keys_hold_keeps_the_sheet_while_the_sail_draws() -> void:
	var c: PlayerController = PlayerController.new()
	var controls: SimControls = SimControls.new()
	_sheeted_in(c, controls)
	var held: float = c.wanted_sheet
	for i: int in 30:
		c.update(_telemetry(60.0, 20.0), controls, DT)
	assert_almost_eq(c.wanted_sheet, held, 1e-6, "the player's sheet is kept for the hold")


func test_a_stalled_sail_ends_the_hold_and_the_sheet_eases_gently() -> void:
	var c: PlayerController = PlayerController.new()
	var controls: SimControls = SimControls.new()
	_sheeted_in(c, controls)
	var before: float = c.wanted_sheet
	for i: int in 30:
		c.update(_telemetry(85.0, 55.0), controls, DT)
	assert_lt(c.wanted_sheet, before - 0.05, "the auto-sheet takes the stalled sail over")
	assert_gt(c.wanted_sheet, before - c.manual_resume_rate_per_s * 0.5 - 0.02, "and eases it, not dumps it")
