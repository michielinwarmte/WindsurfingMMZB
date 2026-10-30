extends GutTest
## The footstraps (PH16 step 17, BoardConfig.back_strap_from_tail_m and
## front_strap_from_tail_m, measured on Max's Patrik 115): while the feet are in the straps the
## trim press keeps their pressure between the back and the front strap.


func _sim(back_m: float = 0.235, front_m: float = 0.825) -> WindsurferSim:
	var sim: WindsurferSim = WindsurferSim.create_default()
	sim.board_config = sim.board_config.duplicate()
	sim.board_config.back_strap_from_tail_m = back_m
	sim.board_config.front_strap_from_tail_m = front_m
	sim.reset(Vector3.ZERO, deg_to_rad(180.0))
	return sim


## Distance from the tail of the feet's pressure for the sim's stance and this press.
func _feet_from_tail(sim: WindsurferSim, press_m: float) -> float:
	return 0.5 * sim.board_config.length_m - (sim.mass_model.stance_z_m(sim.stance) + press_m)


func test_the_default_board_has_the_measured_straps() -> void:
	var board: BoardConfig = WindsurferSim.create_default().board_config
	assert_almost_eq(board.back_strap_from_tail_m, 0.235, 0.001, "the back straps over the fin box's front screw")
	assert_almost_eq(board.front_strap_from_tail_m, 0.825, 0.001, "the front straps 0.59 m ahead of them")


func test_in_the_straps_the_press_stops_at_the_back_strap() -> void:
	var sim: WindsurferSim = _sim()
	sim.stance = 1.0
	var press: float = sim._press_within_straps(0.6)
	assert_almost_eq(_feet_from_tail(sim, press), 0.235, 0.001, "all the weight on the back foot, no further aft")


func test_in_the_straps_the_press_stops_at_the_front_strap() -> void:
	var sim: WindsurferSim = _sim()
	sim.stance = 1.0
	var press: float = sim._press_within_straps(-0.6)
	assert_almost_eq(_feet_from_tail(sim, press), 0.825, 0.001, "all the weight on the front foot, no further forward")


func test_between_the_straps_the_press_is_free() -> void:
	var sim: WindsurferSim = _sim()
	sim.stance = 1.0
	assert_almost_eq(sim._press_within_straps(0.2), 0.2, 1e-6, "aft, short of the back strap")
	assert_almost_eq(sim._press_within_straps(-0.1), -0.1, 1e-6, "forward, short of the front strap")


func test_a_stance_by_the_mast_is_not_held_back_by_the_front_straps() -> void:
	var sim: WindsurferSim = _sim()
	sim.stance = 0.0
	assert_gt(_feet_from_tail(sim, 0.0), 0.825, "the rest stance is forward of the front straps")
	assert_almost_eq(sim._press_within_straps(-0.3), -0.3, 1e-6, "the feet are not in the straps yet")


func test_a_board_without_straps_leaves_the_press_alone() -> void:
	var sim: WindsurferSim = _sim(0.0, 0.0)
	sim.stance = 1.0
	assert_almost_eq(sim._press_within_straps(0.6), 0.6, 1e-6, "aft")
	assert_almost_eq(sim._press_within_straps(-0.6), -0.6, 1e-6, "forward")
