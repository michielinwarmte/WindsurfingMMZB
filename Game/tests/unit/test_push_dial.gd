extends GutTest
## The push slider's ladder (PushDial, PushCurveConfig; Documentation/reports/push_slider/PLAN.md):
## the points of the default curve, straight between them, applied to a pilot and a board's
## controls, never to a shared config.


func _curve() -> PushCurveConfig:
	return PushDial.default_curve()


func test_the_ladders_ends_and_the_old_dials_three_settings() -> void:
	var c: PushCurveConfig = _curve()
	assert_almost_eq(c.at(c.drive_share, 0.0), 0.0, 1e-9, "0 %: the sail let fly")
	assert_almost_eq(c.at(c.drive_share, 0.5), 0.85, 1e-9, "50 %: cruising, most of the drive")
	assert_almost_eq(c.at(c.hike_share, PushDial.EASED), 0.8, 1e-9, "eased holds 0.8 of the hike")
	assert_almost_eq(c.at(c.hike_share, PushDial.NEUTRAL), 1.0, 1e-9, "neutral 1.0")
	assert_almost_eq(c.at(c.hike_share, PushDial.PUSHED), 1.6, 1e-9, "pushed 1.6")
	assert_almost_eq(c.at(c.rig_lean_extra_deg, PushDial.NEUTRAL), 0.0, 1e-9, "the rig's lean is the sailor's at neutral")
	assert_almost_eq(c.at(c.rig_lean_extra_deg, PushDial.PUSHED), 10.0, 1e-9, "and 10 degrees more pushed (35)")
	assert_almost_eq(c.at(c.back_foot_push, PushDial.PUSHED), 0.0, 1e-9, "the fin's push is not in the ladder: held, the couple unloads the fin (round 1); the rail loads it")
	assert_almost_eq(c.at(c.rail_bank_extra_deg, PushDial.PUSHED), 2.0, 1e-9, "two degrees more rail at the top")
	assert_almost_eq(c.at(c.drive_share, 0.25), 0.3, 1e-9, "25 %: slowly moving")


func test_between_the_points_the_ladder_is_straight_and_held_at_the_ends() -> void:
	var c: PushCurveConfig = _curve()
	assert_almost_eq(c.at(c.drive_share, 0.125), 0.15, 1e-9, "halfway from 0 to 25 %")
	assert_almost_eq(c.at(c.hike_share, 0.8), 1.15, 1e-9, "halfway from 75 to 85 %: 1.0 to 1.3")
	assert_almost_eq(c.at(c.hike_share, 1.5), 1.6, 1e-9, "no further than the top")
	assert_almost_eq(c.at(c.hike_share, -1.0), 0.8, 1e-9, "no further than the bottom")


func test_apply_level_sets_the_pilot_and_the_controls_only() -> void:
	var pilot: Autopilot = Autopilot.new()
	var controls: SimControls = SimControls.new()
	PushDial.apply_level(PushDial.PUSHED, _curve(), pilot, controls)
	assert_almost_eq(pilot.hike_share, 1.6, 1e-9)
	assert_almost_eq(pilot.drive_share, 1.0, 1e-9)
	assert_almost_eq(pilot.back_foot_bias, 0.0, 1e-9)
	assert_almost_eq(controls.rig_lean_extra_deg, 10.0, 1e-9)
	assert_almost_eq(controls.rail_bank_extra_deg, 2.0, 1e-9)
	assert_almost_eq(controls.trim_aim_extra_deg, 0.5, 1e-9)
	PushDial.apply_level(0.0, _curve(), pilot, controls)
	assert_almost_eq(pilot.drive_share, 0.0, 1e-9, "0 %: the sail let fly")
	assert_almost_eq(pilot.hike_share, 0.8, 1e-9)
	assert_almost_eq(controls.rig_lean_extra_deg, 0.0, 1e-9)
	# The shared sailor config is never written: the slider works through the controls.
	assert_almost_eq((load("res://config/sailor_default.tres") as SailorConfig).max_rig_lean_deg, 25.0, 1e-9, "the .tres keeps its number")


func test_level_of_names_and_numbers() -> void:
	assert_almost_eq(PushDial.level_of("eased"), 0.5, 1e-9)
	assert_almost_eq(PushDial.level_of("neutral"), 0.75, 1e-9)
	assert_almost_eq(PushDial.level_of("Pushed"), 1.0, 1e-9)
	assert_almost_eq(PushDial.level_of("0.85"), 0.85, 1e-9, "a share")
	assert_almost_eq(PushDial.level_of("85"), 0.85, 1e-9, "a percentage")
	assert_almost_eq(PushDial.level_of("anything else"), 0.75, 1e-9, "neutral")
