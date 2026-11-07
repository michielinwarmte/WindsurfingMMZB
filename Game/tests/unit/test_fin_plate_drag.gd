extends GutTest
## The fin's flat-plate drag past the stall only (the physics realism audit, 7 November 2026,
## Documentation/reports/physics/realism_audit_7nov2026.md): FinConfig.cd_plate_post_stall. A foil
## below its stall has its profile and induced drag; the plate's 1.2 sin^2(slip) is separated flow's
## (Viterna and Corrigan 1982). Off by default until the steering is retuned on it.


func _fin(post_stall: bool) -> FinModel:
	var config: FinConfig = (load("res://config/fin_default.tres") as FinConfig).duplicate() as FinConfig
	config.cd_plate_post_stall = post_stall
	return FinModel.new(config)


func test_off_by_default() -> void:
	assert_false(FinConfig.new().cd_plate_post_stall, "the old drag at every slip until Michiel's review")
	assert_false((load("res://config/fin_default.tres") as FinConfig).cd_plate_post_stall, "and in the default fin")


func test_on_there_is_no_plate_drag_below_the_stall() -> void:
	var on: FinModel = _fin(true)
	var off: FinModel = _fin(false)
	var slip: float = deg_to_rad(5.0)
	var cl: float = 0.5
	var plate: float = on.config.cd_plate * sin(slip) * sin(slip)
	assert_almost_eq(off.drag_coefficient(cl, slip) - on.drag_coefficient(cl, slip), plate, 1e-9, "at 5 deg the plate's share is gone")


func test_on_the_plate_drag_is_whole_past_the_stall() -> void:
	var on: FinModel = _fin(true)
	var off: FinModel = _fin(false)
	var slip: float = deg_to_rad(on.config.stall_peak_deg + on.config.cd_plate_blend_deg + 5.0)
	assert_almost_eq(on.drag_coefficient(0.3, slip), off.drag_coefficient(0.3, slip), 1e-9, "a stalled fin pushes like a plate either way")
