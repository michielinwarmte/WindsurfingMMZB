extends GutTest
## Hooked in on a short line (PH16 step 16, SailorConfig.harness_line_m): the body holds the
## boom within the line's length, so a body that hikes out pulls the rig over with it, never
## past max_total_rig_lean_deg. Off (0), the rig leans with the hike by max_rig_lean_deg alone.

const DT: float = 1.0 / 60.0


func _sailing_sim(line_m: float) -> WindsurferSim:
	var sim: WindsurferSim = WindsurferSim.create_default()
	sim.sailor_config = sim.sailor_config.duplicate()
	sim.sailor_config.harness_line_m = line_m
	sim.reset(Vector3.ZERO, deg_to_rad(180.0))
	sim.step(DT, SimControls.new())
	return sim


## Puts the sailor at full lean to starboard, hiked out as the mass model puts them, with the
## rig upright and no tilt from the arms.
func _hike_out(sim: WindsurferSim) -> void:
	sim.lean = 1.0
	sim._controls_rig_tilt = 0.0
	sim.mass_model.update(sim.body_stance, sim.lean, 0.0, 0.0, 0.0)
	sim.sailor.place(sim.body.point_world(sim.mass_model.sailor_position_body), Vector3.ZERO)


## The distance from the line's point on the boom to the centre of mass with the rig leaned so.
func _line_gap_m(sim: WindsurferSim, lean_rad: float) -> float:
	var com: Vector3 = sim.rig.to_body(sim.sailor.position - sim.rig.foot_world)
	var chord: Vector3 = Vector3(sim.sail.sail_side * sin(sim.sail.sheet_angle_rad), 0.0, cos(sim.sail.sheet_angle_rad))
	return sim._line_gap_m(lean_rad, com, sim.sail.rake_rad, chord)


func test_off_the_rig_leans_with_the_hike_alone() -> void:
	var sim: WindsurferSim = _sailing_sim(0.0)
	_hike_out(sim)
	assert_almost_eq(sim._rig_lean_rad(), deg_to_rad(sim.sailor_config.max_rig_lean_deg), 1e-9)


func test_hooked_in_the_rig_comes_over_to_the_body() -> void:
	var sim: WindsurferSim = _sailing_sim(1.0)
	_hike_out(sim)
	# A line between the gap at the hike's own lean and the closest the rig can come (a scan).
	var closest: float = INF
	for degrees: int in 46:
		closest = minf(closest, _line_gap_m(sim, deg_to_rad(degrees)))
	var line: float = 0.5 * (closest + _line_gap_m(sim, deg_to_rad(sim.sailor_config.max_rig_lean_deg)))
	sim.sailor_config.harness_line_m = line
	sim._copy_configs()
	var held: float = sim._rig_lean_rad()
	assert_gt(held, deg_to_rad(sim.sailor_config.max_rig_lean_deg), "further over than the hike alone leans it")
	assert_lt(held, deg_to_rad(sim.sailor_config.max_total_rig_lean_deg), "inside the limit")
	assert_almost_eq(_line_gap_m(sim, held), line, 0.005, "the boom just within the line of the body")
	assert_gt(_line_gap_m(sim, held - deg_to_rad(1.0)), line, "a degree less and the line would not reach")


func test_a_line_too_short_to_reach_stops_at_the_limit_or_the_closest_lean() -> void:
	var sim: WindsurferSim = _sailing_sim(0.1)
	_hike_out(sim)
	var held: float = sim._rig_lean_rad()
	assert_lte(held, deg_to_rad(sim.sailor_config.max_total_rig_lean_deg) + 1e-6, "never past the limit")
	var gap: float = _line_gap_m(sim, held)
	assert_gt(gap, 0.1, "it does not reach")
	assert_lte(gap, _line_gap_m(sim, held - deg_to_rad(2.0)) + 1e-6, "but no smaller lean comes closer")


func test_a_body_already_within_the_line_keeps_the_rig_as_the_hike_leans_it() -> void:
	var sim: WindsurferSim = _sailing_sim(3.0)
	_hike_out(sim)
	assert_almost_eq(sim._rig_lean_rad(), deg_to_rad(sim.sailor_config.max_rig_lean_deg), 1e-9)
