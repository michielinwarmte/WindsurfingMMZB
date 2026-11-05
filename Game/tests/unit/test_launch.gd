extends GutTest
## A launch off a crest (PH43; Documentation/reports/playtest/feedback_5_november_2026.md section
## 6): as the water lets go, board and rider go as one in pitch (SailorConfig.launch_carry_share),
## the front foot pulls up when the nose starts dropping fast (front_foot_react_dps), the trim
## press holds in the air, and the air under the dry bottom pushes the nose up
## (BoardConfig.air_lift).

const DT: float = 1.0 / 180.0


func _sim() -> WindsurferSim:
	var sim: WindsurferSim = WindsurferSim.create_default()
	sim.sailor_config = sim.sailor_config.duplicate()
	sim.board_config = sim.board_config.duplicate()
	sim.reset(Vector3.ZERO, deg_to_rad(180.0))
	sim.step(1.0 / 60.0, SimControls.new())
	sim.body.angular_velocity = Vector3.ZERO
	return sim


## Holds the hull at this pitch (degrees, bow up) and pitch rate (degrees a second).
func _hold(sim: WindsurferSim, pitch_deg: float, rate_dps: float) -> void:
	var heading: Basis = Basis(Vector3.UP, deg_to_rad(-180.0))
	sim.body.basis = Basis(heading * Vector3.RIGHT, deg_to_rad(pitch_deg)) * heading
	sim.body.angular_velocity = sim.body.starboard_axis() * deg_to_rad(rate_dps)


## The hull carrying this share of what it has been carrying lately (1 000 N).
func _carried(sim: WindsurferSim, share: float) -> void:
	sim._hull_load_avg_n = 1000.0
	sim.hull.hull_load_n = share * 1000.0


func test_the_rider_joins_the_hull_as_the_water_lets_go() -> void:
	var sim: WindsurferSim = _sim()
	sim.stance = 1.0
	_carried(sim, 1.0)
	assert_eq(sim._launch_coupling(), 0.0, "the hull carries what it did: the hull alone, as before")
	_carried(sim, 0.5)
	assert_almost_eq(sim._launch_coupling(), 0.0, 1e-9, "half of it: the fade starts here")
	_carried(sim, 0.25)
	assert_almost_eq(sim._launch_coupling(), 0.5, 1e-9, "a quarter: half joined")
	_carried(sim, 0.0)
	assert_almost_eq(sim._launch_coupling(), 1.0, 1e-9, "in the air: as one")
	sim.stance = 0.5
	assert_almost_eq(sim._launch_coupling(), 0.5, 1e-9, "half in the straps: half joined")
	sim.stance = 1.0
	sim._hull_load_avg_n = 0.0
	assert_eq(sim._launch_coupling(), 0.0, "before the hull has carried anything: nothing to let go of")
	_carried(sim, 0.0)
	sim.sailor_config.launch_carry_share = 0.0
	sim._copy_configs()
	assert_eq(sim._launch_coupling(), 0.0, "the option off: never")


func test_the_rider_remembers_the_hulls_load_slowly_and_not_in_the_air() -> void:
	var sim: WindsurferSim = _sim()
	sim._hull_load_avg_n = 0.0
	sim.launch_coupling = 0.0
	sim.hull.hull_load_n = 1000.0
	for i: int in int(2.0 / DT):
		sim._remember_hull_load(DT)
	assert_almost_eq(sim._hull_load_avg_n, 1000.0 * (1.0 - exp(-1.0)), 15.0, "after one memory time, 63 % of the way")
	for i: int in int(10.0 / DT):
		sim._remember_hull_load(DT)
	assert_almost_eq(sim._hull_load_avg_n, 1000.0, 10.0, "and settled on it")
	# In steady planing the hull carries a third of the weight and the rig and the fin the rest:
	# the hull's own load is the yardstick, so nothing joins.
	sim.stance = 1.0
	sim.hull.hull_load_n = 1000.0
	assert_eq(sim._launch_coupling(), 0.0, "carrying what it did: nothing joins, whatever the rig carries")
	# In the air the memory holds, so the flight does not forget the load that let go.
	sim.hull.hull_load_n = 0.0
	sim.launch_coupling = sim._launch_coupling()
	for i: int in int(1.0 / DT):
		sim._remember_hull_load(DT)
	assert_almost_eq(sim._hull_load_avg_n, 1000.0, 10.0, "held through the flight")


func test_the_joined_inertia_is_the_whole_kits() -> void:
	var sim: WindsurferSim = _sim()
	var hull_alone: float = sim.mass_model.hull_inertia_body.x.x
	var whole_kit: float = sim.mass_model.inertia_body.x.x
	assert_almost_eq(hull_alone, 3.39, 0.05, "the 7.8 kg hull: about 3.4 kg m2 in pitch")
	assert_gt(whole_kit, 40.0, "the kit with the rider and the rig: tens of kg m2")
	assert_eq(sim._rider_pitch_inertia_kgm2(0.0), 0.0, "on the water nothing joins")
	assert_almost_eq(sim._rider_pitch_inertia_kgm2(1.0), whole_kit - hull_alone, 1e-9, "in the air the rest of the kit")
	assert_almost_eq(sim._rider_pitch_inertia_kgm2(0.5), 0.5 * (whole_kit - hull_alone), 1e-9, "half joined: half of it")
	var base: Basis = Basis.IDENTITY.scaled(Vector3(3.0, 20.0, 30.0))
	var with_rider: Basis = sim._with_rider_pitch_inertia(base, 50.0)
	assert_almost_eq(with_rider.x.x, 53.0, 1e-9, "added to the pitch axis")
	assert_almost_eq(with_rider.y.y, 20.0, 1e-9, "yaw untouched")
	assert_almost_eq(with_rider.z.z, 30.0, 1e-9, "roll untouched")
	assert_eq(sim._with_rider_pitch_inertia(base, 0.0), base, "nothing to add: the same")


func test_a_launched_hull_keeps_its_pitch_rate_instead_of_flipping() -> void:
	# The hull in the air with the feet in the straps, a nose-down moment on it (the mast foot's
	# push): with the rider joined it turns at the kit's pace, with the hull alone within a step.
	var sim: WindsurferSim = _sim()
	sim.stance = 1.0
	_carried(sim, 0.0)
	sim.hull.pitch_added_inertia_kgm2 = 0.0  # in the air the hull drags no water along
	sim.launch_coupling = 0.0
	var coupling: float = sim._launch_coupling()
	var joined: float = sim._rider_pitch_inertia_kgm2(coupling)
	var inertia: Basis = sim._with_rider_pitch_inertia(sim._inertia_with_added_water(sim.mass_model.hull_inertia_body), joined)
	var alone: Basis = sim._inertia_with_added_water(sim.mass_model.hull_inertia_body)
	var moment_nm: float = 60.0
	var rate_joined: float = rad_to_deg(moment_nm / inertia.x.x)
	var rate_alone: float = rad_to_deg(moment_nm / alone.x.x)
	assert_lt(rate_joined, 60.0, "60 N m turns the kit at less than 60 deg/s^2")
	assert_gt(rate_alone, 500.0, "and the bare hull at hundreds")


func test_the_front_foot_pulls_when_the_nose_drops_fast() -> void:
	var sim: WindsurferSim = _sim()
	sim.stance = 1.0
	sim.felt_trim_deg = 6.0  # above the aim: no pull for the trim
	var spread_m: float = sim.board_config.front_strap_from_tail_m - sim.board_config.back_strap_from_tail_m
	var held_nm: float = sim.sailor_config.front_foot_pull_held_n * spread_m
	_hold(sim, 6.0, 0.0)
	assert_eq(sim._front_foot_couple_nm(true, 13.0), 0.0, "the nose high and steady: no pull")
	_hold(sim, 6.0, -10.0)
	assert_almost_eq(sim._front_foot_couple_nm(true, 13.0), 0.5 * held_nm, 1e-3, "dropping at half the reaction rate: half the pull")
	_hold(sim, 6.0, -40.0)
	assert_almost_eq(sim._front_foot_couple_nm(true, 13.0), held_nm, 1e-6, "dropping fast: the whole held pull, no more")
	_hold(sim, 6.0, 10.0)
	assert_eq(sim._front_foot_couple_nm(true, 13.0), 0.0, "the nose rising: no pull")
	sim.felt_trim_deg = -2.0
	_hold(sim, -2.0, -10.0)
	assert_almost_eq(sim._front_foot_couple_nm(true, 13.0), held_nm, 1e-6, "below the aim as well: the larger of the two, not the sum")
	sim.sailor_config.front_foot_react_dps = 0.0
	sim._copy_configs()
	sim.felt_trim_deg = 6.0
	_hold(sim, 6.0, -40.0)
	assert_eq(sim._front_foot_couple_nm(true, 13.0), 0.0, "the reaction off: as before PH43")


func test_the_trim_press_holds_in_the_air() -> void:
	var sim: WindsurferSim = _sim()
	sim.trim_press_m = 0.2
	sim.hull.planing_ratio = 0.6
	sim.launch_coupling = 1.0
	_hold(sim, 6.0, 0.0)  # far above the aim: on the water the press would release quickly
	for i: int in int(1.0 / DT):
		sim._trim_by_feel(true, 13.0, DT)
	assert_almost_eq(sim.trim_press_m, 0.2, 1e-9, "in the air the weight stays where it is")
	sim.launch_coupling = 0.0
	for i: int in int(1.0 / DT):
		sim._trim_by_feel(true, 13.0, DT)
	assert_lt(sim.trim_press_m, 0.2, "landed, the rider moves the weight again")


func _flying(sim: WindsurferSim, pitch_deg: float, speed_ms: float) -> void:
	# The whole bottom dry, the board moving ahead at speed_ms with its nose this high.
	sim.hull.wetted_length_m = 0.0
	sim.hull.wetted_aft_m = 0.0
	_hold(sim, pitch_deg, 0.0)
	sim.body.velocity = -sim.body.aft_axis() * speed_ms
	sim.body.velocity.y = 0.0
	sim.body.clear_forces()


func test_the_air_under_a_flying_board_pushes_the_nose_up() -> void:
	var sim: WindsurferSim = _sim()
	_flying(sim, 15.0, 15.0)
	sim._apply_air_under_the_board()
	assert_gt(sim.air_lift_n, 20.0, "a board flying nose-high at 15 m/s: tens of newtons up")
	assert_lt(sim.air_lift_n, 400.0, "but not a wing")
	assert_gt(sim.air_pitch_nm, 0.0, "ahead of the centre of mass: nose-up")
	var up_at_15: float = sim.air_lift_n
	_flying(sim, 5.0, 15.0)
	sim._apply_air_under_the_board()
	assert_lt(sim.air_lift_n, up_at_15, "the nose lower: less")
	assert_gt(sim.air_lift_n, 0.0, "but still up")
	_flying(sim, -10.0, 15.0)
	sim._apply_air_under_the_board()
	assert_eq(sim.air_lift_n, 0.0, "the nose down, the air flowing off the bottom: nothing")
	_flying(sim, 15.0, 0.0)
	sim._apply_air_under_the_board()
	gut.p("still, in the wind alone: %.1f N up" % sim.air_lift_n)


func test_the_air_force_is_off_with_the_option_and_small_on_the_water() -> void:
	var sim: WindsurferSim = _sim()
	sim.board_config.air_lift = false
	sim._copy_configs()
	_flying(sim, 15.0, 15.0)
	sim._apply_air_under_the_board()
	assert_eq(sim.air_force_world, Vector3.ZERO, "the option off: no air force on the hull")
	assert_eq(sim.air_lift_n, 0.0)
	sim.board_config.air_lift = true
	sim._copy_configs()
	# Planing at 1.5 degrees with 1.2 m wet: the dry nose part at the rocker's angle, a few newtons.
	sim.hull.wetted_length_m = 1.2
	sim.hull.wetted_aft_m = 0.0
	_hold(sim, 1.5, 0.0)
	sim.body.velocity = -sim.body.aft_axis() * 13.0
	sim.body.clear_forces()
	sim._apply_air_under_the_board()
	assert_lt(absf(sim.air_lift_n), 60.0, "on the water the air's push on the dry nose is small")
	gut.p("planing, 1.2 m wet at 13 m/s: %.1f N up, %.1f N m nose-up" % [sim.air_lift_n, sim.air_pitch_nm])
