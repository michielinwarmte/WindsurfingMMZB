extends GutTest
## The push dial onto the sailor's technique (PushDial; the autopilot suite, round 4): the three
## settings' numbers, straight between them, applied to a pilot and a sailor config.


func test_the_three_settings_are_the_measured_numbers() -> void:
	assert_almost_eq(PushDial.at_level(PushDial.HIKE_SHARE, PushDial.EASED), 0.8, 1e-9, "eased holds 0.8 of the hike")
	assert_almost_eq(PushDial.at_level(PushDial.HIKE_SHARE, PushDial.NEUTRAL), 1.0, 1e-9, "neutral 1.0")
	assert_almost_eq(PushDial.at_level(PushDial.HIKE_SHARE, PushDial.PUSHED), 1.6, 1e-9, "pushed 1.6")
	assert_almost_eq(PushDial.at_level(PushDial.RIG_LEAN_DEG, PushDial.EASED), 25.0, 1e-9, "the rig's lean 25 eased")
	assert_almost_eq(PushDial.at_level(PushDial.RIG_LEAN_DEG, PushDial.PUSHED), 35.0, 1e-9, "and 35 pushed")


func test_between_the_settings_the_dial_is_straight_and_clamped() -> void:
	assert_almost_eq(PushDial.at_level(PushDial.HIKE_SHARE, 0.5), 1.3, 1e-9, "half pushed")
	assert_almost_eq(PushDial.at_level(PushDial.HIKE_SHARE, -0.5), 0.9, 1e-9, "half eased")
	assert_almost_eq(PushDial.at_level(PushDial.HIKE_SHARE, 3.0), 1.6, 1e-9, "no further than pushed")
	assert_almost_eq(PushDial.at_level(PushDial.RIG_LEAN_DEG, -2.0), 25.0, 1e-9, "no further than eased")


func test_apply_sets_the_pilot_and_the_sailors_own_copy() -> void:
	var pilot: Autopilot = Autopilot.new()
	var sailor: SailorConfig = (load("res://config/sailor_default.tres") as SailorConfig).duplicate()
	PushDial.apply(PushDial.PUSHED, pilot, sailor)
	assert_almost_eq(pilot.hike_share, 1.6, 1e-9)
	assert_almost_eq(sailor.max_rig_lean_deg, 35.0, 1e-9)
	PushDial.apply(PushDial.level_of("eased"), pilot, sailor)
	assert_almost_eq(pilot.hike_share, 0.8, 1e-9)
	assert_almost_eq(sailor.max_rig_lean_deg, 25.0, 1e-9)
	assert_almost_eq(PushDial.level_of("neutral"), 0.0, 1e-9)
	assert_almost_eq(PushDial.level_of("anything else"), 0.0, 1e-9)
	# The shared resource is untouched: the dial works on a copy.
	assert_almost_eq((load("res://config/sailor_default.tres") as SailorConfig).max_rig_lean_deg, 25.0, 1e-9, "the .tres keeps its number")
