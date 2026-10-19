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
