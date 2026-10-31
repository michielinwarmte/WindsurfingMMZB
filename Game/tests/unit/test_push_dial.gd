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
	assert_almost_eq(c.at(c.rail_bank_extra_deg, PushDial.PUSHED), 1.0, 1e-9, "a degree more rail at the top")
	assert_almost_eq(c.at(c.wave_rail_deg, PushDial.NEUTRAL), 3.0, 1e-9, "and up to three more for the sea from 50 % up")
	assert_almost_eq(c.at(c.wave_rail_deg, 0.0), 0.0, 1e-9, "none at 0 %")
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
	assert_almost_eq(controls.rail_bank_extra_deg, 1.0, 1e-9)
	assert_almost_eq(controls.trim_aim_extra_deg, 0.5, 1e-9)
	assert_almost_eq(pilot.wave_rail_max_deg, 3.0, 1e-9, "the sea's rail available")
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


func test_the_rail_for_the_sea_follows_the_bounce_felt() -> void:
	var pilot: Autopilot = Autopilot.new()
	var t: Telemetry = Telemetry.new()
	assert_eq(pilot.wave_rail_deg(), 0.0, "off without the slider")
	pilot.wave_rail_max_deg = 3.0
	# Flat water: a pitch rate of 2 deg/s either way, below the 4 deg/s the rail starts at.
	for i: int in 600:
		t.time_s = i / 60.0
		t.pitch_rate_dps = 2.0 if i % 2 == 0 else -2.0
		pilot.feel_the_sea(t, 1.0 / 60.0)
	assert_almost_eq(pilot.felt_bounce_dps(), 2.0, 0.05, "the bounce felt is the pitch rate's RMS")
	assert_eq(pilot.wave_rail_deg(), 0.0, "no extra rail in flat water")
	# The sea: 8 deg/s, halfway from 4 to 12.
	for i: int in 600:
		t.time_s = 10.0 + i / 60.0
		t.pitch_rate_dps = 8.0 if i % 2 == 0 else -8.0
		pilot.feel_the_sea(t, 1.0 / 60.0)
	assert_almost_eq(pilot.wave_rail_deg(), 1.5, 0.1, "half the sea's rail on the default sea")
	# Wild: 14 deg/s, beyond the full level.
	for i: int in 600:
		t.time_s = 20.0 + i / 60.0
		t.pitch_rate_dps = 14.0 if i % 2 == 0 else -14.0
		pilot.feel_the_sea(t, 1.0 / 60.0)
	assert_almost_eq(pilot.wave_rail_deg(), 3.0, 1e-6, "all of it when it is wild")
	# The same telemetry time twice feels nothing new (the controller and the pilot both call it).
	var before: float = pilot.felt_bounce_dps()
	t.pitch_rate_dps = 0.0
	pilot.feel_the_sea(t, 1.0 / 60.0)
	assert_almost_eq(pilot.felt_bounce_dps(), before, 1e-9, "once per telemetry time")
