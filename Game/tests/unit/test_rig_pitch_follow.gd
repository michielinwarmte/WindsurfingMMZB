extends GutTest
## The rig follows the board's pitch a little behind (PH16, SailorConfig.rig_pitch_follow_s):
## the mast foot is a joint, so a board that pitches quickly under the rig does not pitch it,
## and the rig takes up the board's new attitude over a few tenths of a second.

const DT: float = 1.0 / 60.0


func _sailing_sim(follow_s: float) -> WindsurferSim:
	var sim: WindsurferSim = WindsurferSim.create_default()
	sim.sailor_config = sim.sailor_config.duplicate()
	sim.sailor_config.rig_pitch_follow_s = follow_s
	sim.reset(Vector3.ZERO, deg_to_rad(180.0))
	sim.step(DT, SimControls.new())
	return sim


## The rig's pitch (degrees, bow up): the angle of its forward axis to the horizontal.
func _rig_pitch_deg(sim: WindsurferSim) -> float:
	return rad_to_deg(asin(clampf(-sim.rig.basis.z.y, -1.0, 1.0)))


## Pitches the hull bow up by this many degrees at once, about its own across axis.
func _pitch_hull_up(sim: WindsurferSim, degrees: float) -> void:
	sim.body.basis = Basis(sim.body.starboard_axis(), deg_to_rad(degrees)) * sim.body.basis


## The bow's rise in the world (degrees): what the rig, held upright in roll, follows.
func _bow_rise_deg(sim: WindsurferSim) -> float:
	return rad_to_deg(asin(clampf(sim.body.forward().y, -1.0, 1.0)))


func test_a_quick_pitch_of_the_board_does_not_pitch_the_rig_at_once() -> void:
	var sim: WindsurferSim = _sailing_sim(0.3)
	var before_deg: float = _rig_pitch_deg(sim)
	var hull_before_deg: float = rad_to_deg(sim.body.pitch_rad())
	_pitch_hull_up(sim, 1.0)
	assert_almost_eq(rad_to_deg(sim.body.pitch_rad()) - hull_before_deg, 1.0, 0.01, "the hull is a degree bow up")
	sim._hold_the_rig(DT / 3.0)
	# One substep of the 0.3 s lag moves the rig about 2 % of the way.
	assert_lt(_rig_pitch_deg(sim) - before_deg, 0.05, "the rig has hardly moved")


func test_the_rig_takes_up_the_board_s_new_attitude_within_a_second_or_so() -> void:
	var sim: WindsurferSim = _sailing_sim(0.3)
	var before_deg: float = _rig_pitch_deg(sim)
	_pitch_hull_up(sim, 1.0)
	var step_deg: float = _bow_rise_deg(sim) - before_deg
	for i: int in 90:  # 0.5 s of substeps (three to a frame)
		sim._hold_the_rig(DT / 3.0)
	# A first-order lag of 0.3 s: 1 - exp(-0.5 / 0.3) = 0.81 of the way after 0.5 s.
	assert_almost_eq((_rig_pitch_deg(sim) - before_deg) / step_deg, 0.81, 0.02, "most of the way after half a second")
	for i: int in 180:  # another 1.0 s: 1.5 s in all, five times the lag
		sim._hold_the_rig(DT / 3.0)
	assert_almost_eq((_rig_pitch_deg(sim) - before_deg) / step_deg, 1.0, 0.02, "the rig has followed the board")


func test_with_no_lag_the_rig_pitches_with_the_board_at_once() -> void:
	var sim: WindsurferSim = _sailing_sim(0.0)
	_pitch_hull_up(sim, 1.0)
	sim._hold_the_rig(DT / 3.0)
	assert_almost_eq(_rig_pitch_deg(sim), _bow_rise_deg(sim), 0.001, "as before PH16")


func test_a_board_put_back_on_the_water_takes_the_rig_with_it_at_once() -> void:
	# After a fall the sailor climbs back on and holds the rig at the board's attitude: no
	# lag left over from before.
	var sim: WindsurferSim = _sailing_sim(0.3)
	_pitch_hull_up(sim, 3.0)
	sim._place_sailor()
	assert_almost_eq(_rig_pitch_deg(sim), rad_to_deg(sim.body.pitch_rad()), 0.01)
