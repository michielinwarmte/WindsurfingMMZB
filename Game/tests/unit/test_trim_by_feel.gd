extends GutTest
## Trimming by feel (PH16, SailorConfig.trim_feel_time_s): the rider presses the tail slowly
## while the board rides below the trim aimed for, eases off when it starts to chatter, and
## lets go off the plane.

const DT: float = 1.0 / 180.0


func _sim() -> WindsurferSim:
	var sim: WindsurferSim = WindsurferSim.create_default()
	sim.sailor_config = sim.sailor_config.duplicate()
	sim.sailor_config.trim_feel_time_s = 1.5
	sim.reset(Vector3.ZERO, deg_to_rad(180.0))
	sim.step(1.0 / 60.0, SimControls.new())
	sim.trim_press_m = 0.0
	# Planing: the hull carries 60 % of the weight on its lift.
	sim.hull.planing_ratio = 0.6
	return sim


## Holds the hull at this pitch (degrees, bow up) and pitch rate (degrees a second).
func _hold(sim: WindsurferSim, pitch_deg: float, rate_dps: float) -> void:
	var heading: Basis = Basis(Vector3.UP, deg_to_rad(-180.0))
	sim.body.basis = Basis(heading * Vector3.RIGHT, deg_to_rad(pitch_deg)) * heading
	sim.body.angular_velocity = sim.body.starboard_axis() * deg_to_rad(rate_dps)


func _feel(sim: WindsurferSim, seconds: float, trimming: bool = true) -> void:
	for i: int in int(seconds / DT):
		sim._trim_by_feel(trimming, 13.0, DT)


func test_a_board_riding_low_gets_the_weight_moved_aft_slowly() -> void:
	var sim: WindsurferSim = _sim()
	_hold(sim, 0.5, 0.0)
	_feel(sim, 5.0)
	# 0.03 m/s for 5 s, as long as the board rides more than the band below the aim.
	assert_almost_eq(sim.trim_press_m, 0.15, 0.01, "the press grows at its rate")
	assert_almost_eq(sim.felt_trim_deg, 0.5, 0.05, "the rider feels the board's attitude")


func test_the_press_stops_at_its_reach() -> void:
	var sim: WindsurferSim = _sim()
	_hold(sim, 0.5, 0.0)
	_feel(sim, 40.0)
	assert_almost_eq(sim.trim_press_m, sim.sailor_config.trim_press_max_m * 0.6, 0.001, "trim_press_max_m times the planing share")


func test_a_board_chattering_at_its_aim_gets_the_weight_moved_forward() -> void:
	var sim: WindsurferSim = _sim()
	sim.trim_press_m = 0.2
	_hold(sim, 1.8, 10.0)  # at the aim of about 1.7 degrees, bouncing hard (10 deg/s against 1.7)
	_feel(sim, 5.0)
	assert_lt(sim.trim_press_m, 0.2, "the rider eases off the porpoise")
	assert_gt(sim.felt_bounce_dps, 5.0, "and feels the chatter")


func test_a_board_chattering_with_its_nose_low_is_not_walked_forward() -> void:
	# PH16 step 17: riding well below the aim, a chattering board is spearing with its nose low;
	# walking forward drives the nose in. The chatter only stops the creep aft.
	var sim: WindsurferSim = _sim()
	sim.trim_press_m = 0.2
	_hold(sim, 0.5, 10.0)  # riding low and bouncing hard
	_feel(sim, 5.0)
	assert_between(sim.trim_press_m, 0.2, 0.21, "neither forward nor further onto the tail (a few millimetres before the chatter is felt)")
	assert_gt(sim.felt_bounce_dps, 5.0, "and feels the chatter")


func test_a_nose_riding_high_gets_the_weight_off_the_tail_quickly() -> void:
	var sim: WindsurferSim = _sim()
	sim.trim_press_m = 0.3
	_hold(sim, 6.0, 0.0)  # far above the aim of about 1.7 degrees
	_feel(sim, 3.0)
	assert_lt(sim.trim_press_m, 0.0, "off the tail within a few seconds, not at the trimming rate")


func test_a_fall_clears_what_the_rider_felt_of_the_board() -> void:
	# review_sim 3.1: after a catapult the rider climbed back on still "feeling" the bounce of the
	# fall for a second or two. In the water the rider feels nothing of the board.
	var sim: WindsurferSim = _sim()
	_hold(sim, 1.8, 10.0)
	_feel(sim, 2.0)
	assert_gt(sim.felt_bounce_dps, 5.0, "bouncing hard before the fall")
	sim.force_fall("catapult")
	assert_eq(sim.felt_bounce_dps, 0.0, "in the water the rider feels nothing of the board")
	assert_eq(sim.felt_trim_deg, 0.0)
	sim.felt_bounce_dps = 3.0
	sim.waterstart()
	assert_eq(sim.felt_bounce_dps, 0.0, "and climbs back on with a clean feel")
	assert_eq(sim.felt_trim_deg, 0.0)


func test_the_shipped_sailor_lists_the_release_rate() -> void:
	# Rule 3: tuning numbers live in the .tres, not in the code's defaults (review_sim 3.1).
	var text: String = FileAccess.get_file_as_string("res://config/sailor_default.tres")
	assert_true(text.contains("trim_press_release_ms = "), "trim_press_release_ms is listed in sailor_default.tres")


func test_off_the_plane_the_press_lets_go() -> void:
	var sim: WindsurferSim = _sim()
	sim.trim_press_m = 0.1
	_hold(sim, 0.5, 0.0)
	_feel(sim, 0.5, false)
	assert_almost_eq(sim.trim_press_m, 0.0, 0.001, "the rider steps off the tail at once (0.3 m/s)")
