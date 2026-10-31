extends GutTest
## How the pilot steers (Helm): the rake, the rig's sideways tilt and the weight on a rail.


func test_steer_moves_the_rake_and_the_tilt_together() -> void:
	var controls: SimControls = SimControls.new()
	# Heading up on starboard tack is a right turn: the rig back and tilted to port.
	Helm.steer(controls, 0.6, 1.0, 0.0, 1.0, 100.0)
	assert_almost_eq(controls.rake, 0.6, 1e-6, "raked back")
	assert_almost_eq(controls.rig_tilt, -0.6, 1e-6, "and tilted to leeward by as much: the rig stands up")


func test_hold_rake_first_uses_the_rake_before_the_tilt_on_both_tacks() -> void:
	var controls: SimControls = SimControls.new()
	Helm.hold_rake_first(controls, 0.6, 0.0, 1.0, 0.0, 1.0, 100.0)
	assert_almost_eq(controls.rake, 0.6, 1e-6, "a steady helm within the rake's range is all rake")
	assert_almost_eq(controls.rig_tilt, 0.0, 1e-6, "and the rig keeps the lean the hike gives it")
	Helm.hold_rake_first(controls, 1.4, 0.0, 1.0, 0.0, 1.0, 100.0)
	assert_almost_eq(controls.rake, 1.0, 1e-6, "the rake at its stop")
	assert_almost_eq(controls.rig_tilt, -0.4, 1e-6, "the rest tilts the rig to leeward (port on starboard tack)")
	Helm.hold_rake_first(controls, 1.4, 0.0, -1.0, 0.0, 1.0, 100.0)
	assert_almost_eq(controls.rake, 1.0, 1e-6, "rake back heads up on port tack too")
	assert_almost_eq(controls.rig_tilt, 0.4, 1e-6, "leeward is starboard on port tack")
	Helm.hold_rake_first(controls, 0.5, 0.2, 1.0, 0.0, 1.0, 100.0)
	assert_almost_eq(controls.rig_tilt, -0.2, 1e-6, "the quick correction also tilts the rig")


func test_the_rail_steers_only_toward_and_across_the_wind() -> void:
	# The autopilot plan, round 2: the weight on the inside rail as the steady helm shortened
	# the close reaches but broke the broad reaches, so the pilot applies lean_share in full up
	# to lean_share_twa_max_deg, fading to none over lean_share_fade_deg, on either tack.
	var pilot: Autopilot = Autopilot.new()
	pilot.lean_share_twa_max_deg = 110.0
	pilot.lean_share_fade_deg = 25.0
	var telemetry: Telemetry = Telemetry.new()
	var shares: Dictionary[float, float] = {60.0: 1.0, 100.0: 1.0, 110.0: 1.0, 122.5: 0.5, 135.0: 0.0, 160.0: 0.0, -60.0: 1.0, -122.5: 0.5, -150.0: 0.0}
	for twa_deg: float in shares:
		telemetry.twa_deg = twa_deg
		assert_almost_eq(pilot._rail_share_by_point_of_sail(telemetry), shares[twa_deg], 1e-6, "the rail's share of the helm at a true wind angle of %.1f deg" % twa_deg)
