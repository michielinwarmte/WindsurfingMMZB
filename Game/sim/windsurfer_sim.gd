class_name WindsurferSim
extends RefCounted
## The whole windsurfer as one simulation: the hull as a rigid body, the sailor as a body
## of their own standing on it, the rig held between the two, the water under them, the
## wind over them, and the force models that connect them (PHYSICS_SPEC.md).
## step(dt, controls) advances the state; `telemetry` reports what happened. No Nodes:
## tests run this headless and the windsurfer scene copies the state onto the visuals.
##
## Two bodies (section 7.5). `body` is the hull (9 kg, plus the water it drags along).
## `sailor` is the sailor's centre of mass (75 kg). The legs connect them: a spring and
## damper from the posture the sailor wants (stance, lean and hang-back, set by the
## balance reflexes of section 15) to where the body actually is, carrying the weight and
## the pull of the sail into the feet, and giving under a jolt. The rig (8 kg, taken as
## weightless in motion) is held at the mast foot by the hull and at the boom by the hands:
## the sail force splits between the two, and what the hands hold is what the sailor leans
## against. The moments the sailor's body passes to the deck through the feet are worked
## out from where the hands and the feet are, so a sailor in balance sails the board flat
## and an overpowered one heels it, as on the water. The rig stands on the mast foot (a
## joint) and points the way the mast foot and the hands make it (`rig`): it pitches with
## the hull but does not roll with it, so the light hull can roll under the sailor without
## swinging the sail through the wind.

var board_config: BoardConfig
var sail_config: SailConfig
var fin_config: FinConfig
var sailor_config: SailorConfig
var water_config: WaterConfig
## The sea state (Phase 5); null or disabled means flat water.
var wave_set_config: WaveSetConfig = null
var wind_config: WindConfig
var sim_config: SimConfig

## The hull.
var body: SimRigidBody = SimRigidBody.new()
## The sailor's centre of mass.
var sailor: SailorBody = SailorBody.new()
var mass_model: MassModel
var buoyancy: BuoyancyModel
var hull: HullModel
var fin: FinModel
var sail: SailModel
## Where the rig is and which way it points: on the mast foot, held in the sailor's frame.
var rig: RigFrame = RigFrame.new()
var wind: WindField
var water: WaterSurface
var telemetry: Telemetry = Telemetry.new()

## Density of the air (kg/m3): 1.225 at sea level; a place brings its own (EnvironmentConfig,
## create_for()). The sail's force and the sailor's windage scale with it.
var air_density_kg_m3: float = 1.225

enum SailorState { SAILING, FALLEN }

var time_s: float = 0.0
## Whether the sailor is on the board or in the water. While the sailor stands on the board
## and balances the sail, the sailor and the rig load the hull through the feet and the mast
## foot; when that balance is lost the sailor and the rig go over (the rig pivots freely at
## the mast foot, so the sail cannot roll the board over) and only the hull is simulated
## until the waterstart.
var sailor_state: SailorState = SailorState.SAILING
## Where the rig leans right now (rad, positive toward starboard), for the mass model.
var _rig_lean_now_rad: float = 0.0
## The sailor's own acceleration along the deck (m/s2, x toward starboard, y up the mast),
## averaged over balance_feel_time_s: what a hard turn or a slam adds to gravity.
var _felt_push_ms2: float = 0.0
var _felt_lift_ms2: float = 0.0
## The same, averaged over fall_feel_time_s, for the fall checks: a jolt of a few tenths
## of a second (a slam on a wave) is taken by the legs and does not throw a sailor; a push
## that lasts does.
var _fall_push_ms2: float = 0.0
var _fall_lift_ms2: float = 0.0
## The sailor's own acceleration in the world frame, averaged over balance_feel_time_s:
## what sets the apparent gravity the posture is held in.
var _felt_acceleration_world: Vector3 = Vector3.ZERO
## The bank the sailor is working toward (rad, positive = starboard rail down).
var _wanted_bank_rad: float = 0.0
## Which side the sailor and rig fell to (+1 starboard, -1 port), what kind of fall it
## was ("catapult" to leeward, "fell back" to windward), and for how long.
var fall_side: int = 0
var fall_kind: String = ""
var fallen_for_s: float = 0.0
var _tack_before_fall: float = 1.0
## The sideways weight the controls asked for at the last step (the deliberate part of
## the heel, which is not a loss of balance).
var _asked_lean: float = 0.0
var _asked_across: float = 0.0
## The posture. 0 = standing near the mast foot, 1 = in the back straps: where the feet
## are (they step quickly), and where the body's centre has got to (it follows at a
## walking pace: a body dragged along at the feet's stepping speed, 2 m/s in a tack,
## kicked the hull into a spin with its inertia).
var stance: float = 0.0
var body_stance: float = 0.0
## -1 = sailor out to port, +1 = out to starboard.
var lean: float = 0.0
## How far the sailor's weight hangs back behind the feet, metres.
var hang_back_m: float = 0.0
## Weight on a rail: -1 = the feet press the port rail, +1 the starboard rail (the lean the
## controls ask for, taken up at the sailor's pace). This is what banks the board.
var rail_press: float = 0.0
## Trimming with the feet: how far aft (positive) of the stance the feet's pressure is.
var trim_press_m: float = 0.0
## Where the posture puts the centre of mass, where the feet stand and where the hands hold
## the boom, all in body axes (relative to the board origin). The posture is measured from
## the deck's centreline at the stance (posture_centre_body), at the feet's deck height.
var posture_target_body: Vector3 = Vector3.ZERO
var posture_centre_body: Vector3 = Vector3.ZERO
var feet_body: Vector3 = Vector3.ZERO
var hand_grip_body: Vector3 = Vector3.ZERO
## How far the legs have given along their line (positive = the body sits closer to the
## feet than the posture wants: the knees have bent) and how far the body has swayed from
## the posture across the legs.
var knee_bend_m: float = 0.0
var leg_sway_m: float = 0.0
## The forces of the last substep, world frame: of the rig on the sailor through the hands,
## of the rig on the hull at the mast foot, of the legs on the sailor, of the air on the
## sailor; and the moment the body passes to the deck at the feet.
var hand_force_world: Vector3 = Vector3.ZERO
var mast_foot_force_world: Vector3 = Vector3.ZERO
var leg_force_world: Vector3 = Vector3.ZERO
var windage_force_world: Vector3 = Vector3.ZERO
var feet_moment_world: Vector3 = Vector3.ZERO
## The hands' pull as a moment about the feet, body axes (z = roll): the pull the sailor
## has to lean against.
var hand_moment_body: Vector3 = Vector3.ZERO
## The harness line's tension (N): how hard the sailor hangs in it, and the extra pull of
## a jolt (the board rising under the sailor) on top of it.
var harness_tension_n: float = 0.0
var harness_jolt_n: float = 0.0
## The roll moment the body wanted to pass to the deck beyond what the feet can hold
## (feet_moment_max_nm), the force with which it would tip the body, and for how long
## that has been more than the hips can hold.
var feet_moment_excess_nm: float = 0.0
var _tipping_force_world: Vector3 = Vector3.ZERO
var _tipping_for_s: float = 0.0
## The hull's acceleration under the feet at the last substep (world): what the body's
## inertia pushes back with, and part of what the sense of balance feels. And the force
## that carries the body with the deck (the body's inertia force, reversed).
var _hull_acceleration_at_feet: Vector3 = Vector3.ZERO
var _attachment_force_world: Vector3 = Vector3.ZERO
## The twist about the grip line that one force at the grip cannot supply: the two hands
## take it as a couple and the body passes it to the feet.
var _hand_twist_world: Vector3 = Vector3.ZERO
## Where the hands hold the boom (world), from the last rig balance.
var _hands_world: Vector3 = Vector3.ZERO
## The pull the body has taken up (hands and windage), averaged over hold_feel_time_s,
## and the hands' roll moment about the feet felt the same way (what the lean answers).
var _held_force_world: Vector3 = Vector3.ZERO
var _felt_hand_moment_nm: float = 0.0
var _felt_hand_pitch_moment_nm: float = 0.0
## The posture's horizontal offset from the feet at the last substep (world), for its rate.
var _offset_prev: Vector3 = Vector3.ZERO
var _offset_prev_valid: bool = false
## The net torque on the hull at the last substep (world), for the telemetry's breakdown
## of what turns and heels the board.
var _net_torque_world: Vector3 = Vector3.ZERO


func _init(board: BoardConfig, sail_cfg: SailConfig, fin_cfg: FinConfig, sailor_cfg: SailorConfig,
		water_cfg: WaterConfig, wind_cfg: WindConfig, sim_cfg: SimConfig, wave_set: WaveSetConfig = null) -> void:
	board_config = board
	sail_config = sail_cfg
	fin_config = fin_cfg
	sailor_config = sailor_cfg
	water_config = water_cfg
	wind_config = wind_cfg
	sim_config = sim_cfg
	wave_set_config = wave_set
	mass_model = MassModel.new(board_config, sail_config, sailor_config)
	buoyancy = BuoyancyModel.new(board_config, water_config)
	hull = HullModel.new(board_config, water_config)
	fin = FinModel.new(fin_config)
	sail = SailModel.new(sail_config)
	wind = WindField.new(wind_config)
	water = FlatWater.new(water_config)
	reset(Vector3.ZERO, 0.0)


## Loads the default configuration files: the open water at sea level. with_waves = true
## puts the default wave set on the water (the game); tests and the validation sail on flat
## water unless they ask.
static func create_default(with_waves: bool = false) -> WindsurferSim:
	return create_for(EnvironmentConfig.new(), with_waves)


## Builds the simulation for a place (PHYSICS_REQUESTS_FROM_MAP.md, R1): its air, its water,
## its wind and its waves, and what it leaves empty from the open water's default files. With
## the map's wind on, the wind is the map's own (MapWindField, PHYSICS_SPEC.md 8.10). The board,
## the sail, the fin and the sailor are the default ones everywhere.
static func create_for(environment: EnvironmentConfig, with_waves: bool = false) -> WindsurferSim:
	var wind_cfg: WindConfig = environment.wind_or_default()
	var sim: WindsurferSim = WindsurferSim.new(
		load("res://config/board_default.tres"),
		load("res://config/sail_default.tres"),
		load("res://config/fin_default.tres"),
		load("res://config/sailor_default.tres"),
		environment.water_or_default(),
		wind_cfg,
		load("res://config/sim_default.tres"),
		environment.waves_or_default())
	sim.air_density_kg_m3 = environment.air_density_kg_m3
	var map_wind: MapWind = environment.map_wind()
	if map_wind != null:
		sim.wind = MapWindField.new(map_wind, wind_cfg, environment.start_time_of_day_s(), environment.map_wind_height_m)
		# Again, so the sail side and the telemetry come from the map's wind.
		sim.reset(Vector3.ZERO, 0.0)
	sim.set_waves(with_waves)
	return sim


## Puts the wave set on the water (oriented to the base wind of the moment) or takes it
## off. The models never notice: they ask the water surface for heights, normals and
## velocities either way.
func set_waves(enabled: bool) -> void:
	if enabled and wave_set_config != null and wave_set_config.enable_waves:
		water = WaveField.new(wave_set_config, water_config, wind_config.from_bearing_deg)
	else:
		water = FlatWater.new(water_config)


## Whether the water has waves on it.
func has_waves() -> bool:
	return water is WaveField


## Puts the board at rest, level, floating at about its resting depth, pointing along a
## compass heading, with the sail on the leeward side of the current wind and the sailor
## standing on the board.
func reset(origin_xz: Vector3, heading_rad: float) -> void:
	time_s = 0.0
	sailor_state = SailorState.SAILING
	fall_side = 0
	fall_kind = ""
	fallen_for_s = 0.0
	_felt_push_ms2 = 0.0
	_felt_lift_ms2 = 0.0
	_fall_push_ms2 = 0.0
	_fall_lift_ms2 = 0.0
	_felt_acceleration_world = Vector3.ZERO
	_wanted_bank_rad = 0.0
	_rig_lean_now_rad = 0.0
	stance = 0.0
	body_stance = 0.0
	lean = 0.0
	hang_back_m = 0.0
	rail_press = 0.0
	trim_press_m = 0.0
	body = SimRigidBody.new()
	_set_hull_mass_properties()
	# A positive rotation about +Y turns the bow to port, so a compass heading is a negative angle.
	body.basis = Basis(Vector3.UP, -heading_rad)
	body.set_origin_world(Vector3(origin_xz.x, water_config.base_height_m + 0.5 * board_config.thickness_m - _rest_depth_m(), origin_xz.z))
	body.velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	var twa: float = SimMath.wind_angle_rad(body.basis, wind.from_direction())
	sail.set_side_for_wind(twa)
	_place_sailor()
	_fill_telemetry(SimControls.new())


## How deep the hull floats at rest under the whole weight (board, rig and sailor).
func _rest_depth_m() -> float:
	return mass_model.total_mass_kg / water_config.density_kg_m3 / board_config.volume_m3 * board_config.thickness_m


## Advances the simulation by dt seconds (one physics tick), in fixed substeps.
func step(dt: float, controls: SimControls) -> void:
	var substeps: int = maxi(sim_config.substeps, 1)
	var sub_dt: float = dt / substeps
	for i: int in substeps:
		var sailing: bool = sailor_state == SailorState.SAILING
		if sailing:
			_update_sailor(sub_dt, controls)
		wind.step(sub_dt)
		# Gravity on each body: the hull's own, and the sailor's (which reaches the hull
		# through the feet). The rig's weight comes in at the mast foot.
		body.add_force(Vector3(0.0, -sim_config.gravity_ms2 * body.mass_kg, 0.0))
		if sailing:
			sailor.add_force(Vector3(0.0, -sim_config.gravity_ms2 * sailor.mass_kg, 0.0))
		buoyancy.apply(body, water, time_s, sim_config.gravity_ms2, sub_dt)
		hull.compute(body, buoyancy, water, time_s, sim_config.gravity_ms2, mass_model.total_mass_kg, sub_dt)
		body.take_water_along(hull.heave_added_mass_kg, _inertia_with_added_water(mass_model.hull_inertia_body))
		body.added_mass_up_kg = hull.heave_added_mass_kg
		body.take_water_along_sideways(_sway_added_mass_kg())
		body.added_mass_sway_kg = _sway_added_mass_kg()
		_set_hull_mass_properties()
		fin.compute(body, water, time_s, water_config.density_kg_m3)
		if sailing:
			_hold_the_rig()
			sail.compute(rig, wind, controls.sheet, controls.rake, air_density_kg_m3, _rig_lean_rad(controls), controls.boom_across, controls.hold_side)
			_apply_rig_forces()
			_apply_windage()
			_apply_leg_forces(sub_dt)
			_attach_sailor_across_the_deck()
			_feel_the_turn(sub_dt)
			sailor.integrate(sub_dt)
		else:
			_apply_rig_in_water_drag(sub_dt)
		_net_torque_world = body.torque_sum()
		body.integrate(sub_dt)
		if sailing:
			_ride_the_hull(sub_dt)
		time_s += sub_dt
		if sailing:
			_check_balance()
		else:
			fallen_for_s += sub_dt
			if fallen_for_s >= sailor_config.waterstart_time_s:
				waterstart()
	_fill_telemetry(controls)


## The hull's mass and inertia, with the water it drags along (the added inertias of the
## last hull computation). The hull box is centred on the board origin. The sailor's mass
## is not in here: across the deck the body is carried by the force that keeps it on its
## posture (_attach_sailor_across_the_deck), which is what lets the hull and the sailor
## turn about their common centre of mass, out near the sailor.
func _set_hull_mass_properties() -> void:
	body.set_mass_properties(mass_model.hull_mass_kg, _inertia_with_added_water(mass_model.hull_inertia_body), Vector3.ZERO)


## A sailor keeps the board upright only as long as their weight can balance the sail's
## pull; the mast foot is a joint and passes no roll moment to the board. So when the board
## heels past what a standing person can recover, it is the sailor who goes, not the board:
## over the sail to leeward when overpowered (a catapult), backwards into the water to
## windward when the pull vanished while hiked out.
func _check_balance() -> void:
	var twa: float = SimMath.wind_angle_rad(body.basis, wind.from_direction())
	var tack: float = 1.0 if twa >= 0.0 else -1.0
	# Heel is positive with the starboard rail down; on starboard tack leeward is port.
	var leeward_heel: float = -_fall_heel_rad() * tack
	# A sailor who presses the leeward rail on purpose (carving into a gybe) banks the
	# board that far by choice; only the heel beyond that is a loss of balance.
	var deliberate: float = maxf(-_wanted_bank_rad * tack, 0.0)
	# Hanging on a pulling sail, the sailor is levered over it (catapult) or dropped behind
	# it (fell back) at modest heels. Standing with a sail that pulls little, they ride the
	# heel with their knees and only fall off a board tipped a long way.
	# A backed sail is pushed with the arms from a standing position, not hung on.
	var hanging: bool = absf(sail.side_force_n) > sailor_config.catapult_min_sail_force_n and _asked_across <= 0.0
	var standing_limit: float = deg_to_rad(sailor_config.standing_fall_heel_deg)
	# Falling to windward: the board (or the push of a fast bear-away) tips the sailor to
	# windward and the sail's pull is not enough to hold them. The pull on the hands tilts
	# the apparent gravity the sailor hangs in toward leeward by atan(pull / weight), so a
	# sailor hanging on a pulling sail rides out a fling that would drop a standing one.
	var pull_on_hands: float = SimMath.horizontal(hand_force_world).length()
	var held_by_the_sail: float = atan2(pull_on_hands, sailor_config.mass_kg * sim_config.gravity_ms2)
	var windward_tip: float = -leeward_heel - held_by_the_sail
	# The body itself: when the feet cannot pass the moment of the sail's pull or of the
	# weight to the deck, the body tips off its posture, and past posture_sway_max_m it
	# is gone: toward the sail (a catapult) or away from it (fell back).
	if _tipping_for_s > sailor_config.tip_time_s:
		# The excess is positive when the body is tipped to port.
		var to_leeward: bool = feet_moment_excess_nm * tack > 0.0
		if to_leeward:
			_fall(int(-tack), "tipped over", tack)
		else:
			_fall(int(tack), "tipped back", tack)
	elif hanging and leeward_heel > deg_to_rad(sailor_config.catapult_heel_deg) + deliberate:
		_fall(int(-tack), "catapult", tack)
	elif hanging and windward_tip > deg_to_rad(sailor_config.fall_back_heel_deg):
		_fall(int(tack), "fell back", tack)
	elif leeward_heel > standing_limit:
		_fall(int(-tack), "fell off", tack)
	elif windward_tip > standing_limit:
		_fall(int(tack), "fell off", tack)


## Makes the sailor fall now, as if they slipped: to leeward ("catapult") or to windward
## ("fell back"). For demos, screenshots and tests.
func force_fall(kind: String) -> void:
	if sailor_state != SailorState.SAILING:
		return
	var twa: float = SimMath.wind_angle_rad(body.basis, wind.from_direction())
	var tack: float = 1.0 if twa >= 0.0 else -1.0
	_fall(int(-tack) if kind == "catapult" else int(tack), kind, tack)


## The sailor and the rig leave the board. The rig floats on its own and the sailor swims,
## so from here only the hull is simulated, keeping the speed it had.
func _fall(side: int, kind: String, tack: float) -> void:
	sailor_state = SailorState.FALLEN
	fall_side = side
	fall_kind = kind
	fallen_for_s = 0.0
	_tack_before_fall = tack
	stance = 0.0
	body_stance = 0.0
	lean = 0.0
	hang_back_m = 0.0
	rail_press = 0.0
	trim_press_m = 0.0
	knee_bend_m = 0.0
	leg_sway_m = 0.0
	sail.clear()
	_clear_sailor_forces()


## Back on the board: level, at rest, across the wind on the tack the sailor fell from,
## where the board has drifted to. The sail starts eased (the caller resets its controls).
func waterstart() -> void:
	sailor_state = SailorState.SAILING
	fallen_for_s = 0.0
	stance = 0.0
	body_stance = 0.0
	lean = 0.0
	hang_back_m = 0.0
	rail_press = 0.0
	trim_press_m = 0.0
	_felt_push_ms2 = 0.0
	_felt_lift_ms2 = 0.0
	_fall_push_ms2 = 0.0
	_fall_lift_ms2 = 0.0
	_felt_acceleration_world = Vector3.ZERO
	_wanted_bank_rad = 0.0
	_rig_lean_now_rad = 0.0
	var origin: Vector3 = body.origin_world()
	var heading_rad: float = wind.current_from_bearing_rad - _tack_before_fall * PI / 2.0
	body.basis = Basis(Vector3.UP, -heading_rad)
	body.set_origin_world(Vector3(origin.x, water_config.base_height_m + 0.5 * board_config.thickness_m - _rest_depth_m(), origin.z))
	body.velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	sail.set_side_for_wind(SimMath.wind_angle_rad(body.basis, wind.from_direction()))
	_place_sailor()


## Stands the sailor on the board in the current posture, moving with it, holding nothing.
func _place_sailor() -> void:
	_set_posture()
	_hold_the_rig()
	sailor.mass_kg = sailor_config.mass_kg
	var at: Vector3 = body.point_world(posture_target_body)
	sailor.place(at, body.point_velocity(at))
	knee_bend_m = 0.0
	leg_sway_m = 0.0
	_clear_sailor_forces()


func _clear_sailor_forces() -> void:
	hand_force_world = Vector3.ZERO
	harness_tension_n = 0.0
	harness_jolt_n = 0.0
	mast_foot_force_world = Vector3.ZERO
	leg_force_world = Vector3.ZERO
	windage_force_world = Vector3.ZERO
	feet_moment_world = Vector3.ZERO
	hand_moment_body = Vector3.ZERO
	feet_moment_excess_nm = 0.0
	_tipping_for_s = 0.0
	_tipping_force_world = Vector3.ZERO
	_hull_acceleration_at_feet = Vector3.ZERO
	_attachment_force_world = Vector3.ZERO
	_offset_prev_valid = false
	_hand_twist_world = Vector3.ZERO
	_held_force_world = Vector3.ZERO
	_felt_hand_moment_nm = 0.0
	_felt_hand_pitch_moment_nm = 0.0


## The rig in the water pulls on the mast foot like a sea anchor, from the moment the
## sailor lets go (the sail is on the water within a fraction of a second at speed).
## A sea anchor on a 9 kg board at 10 m/s would stop it within one step, so the drag is
## integrated implicitly: over the step, quadratic drag takes the point's speed from v to
## v / (1 + k v dt / m), never past zero, with m the effective mass of the mast foot.
func _apply_rig_in_water_drag(dt: float) -> void:
	var foot: Vector3 = body.point_world(sail_config.mast_foot_local)
	var surface_height: float = water.height_at(foot.x, foot.z, time_s)
	var at: Vector3 = Vector3(foot.x, surface_height, foot.z)
	var v: Vector3 = SimMath.horizontal(body.point_velocity(at) - water.velocity_at(foot.x, foot.z, time_s))
	var speed: float = v.length()
	if speed < 0.01:
		return
	var direction: Vector3 = v / speed
	var k: float = 0.5 * water_config.density_kg_m3 * sailor_config.rig_in_water_drag_m2
	# The rig in the water moves with the water under the mast foot, but it pulls on the
	# board through the mast foot, a joint: a force there and no moment. (Applied at the
	# water surface below the foot, as until Session 39, a board thrown clear of the water
	# after a catapult got the drag on a lever of half a metre and was spun over in the air.)
	var m_eff: float = body.effective_mass_at(foot, direction)
	var speed_after: float = speed / (1.0 + k * speed * dt / m_eff)
	var impulse: float = m_eff * (speed - speed_after)
	body.add_force_at(foot, -direction * impulse / dt)


## The bank a sailor who leans this much wants: the bank of a coordinated turn at
## lean times carve_rate_dps at this speed, atan(v w / g), at most bank_max_deg. At rest
## it is nothing (a lean at rest is just a lean), at planing speed a full lean is a carve.
func _bank_for_turn(lean_asked: float, forward_speed: float) -> float:
	var turn_rate: float = lean_asked * deg_to_rad(sailor_config.carve_rate_dps)
	var bank: float = atan2(maxf(forward_speed, 0.0) * turn_rate, sim_config.gravity_ms2)
	var limit: float = deg_to_rad(sailor_config.bank_max_deg)
	return clampf(bank, -limit, limit)


## Loading the fin (SailorConfig.fin_load_bank_deg): a sailor in the back straps (the
## stance, which goes there with the planing speed) who hangs out to one side tips the board
## the other way, the leeward rail down, as far as they hike, and not while the controls ask
## for a turn (that bank is the turn's). The lean is positive with the weight out to
## starboard, so the bank is to port: negative.
func _fin_load_bank_rad(asked: float) -> float:
	var in_the_straps: float = clampf(stance, 0.0, 1.0)
	var not_turning: float = 1.0 - clampf(absf(asked), 0.0, 1.0)
	return -clampf(lean, -1.0, 1.0) * deg_to_rad(sailor_config.fin_load_bank_deg) * in_the_straps * not_turning


## The heel the sailor feels: the board's heel less the bank that the turn asks for. In a
## turn the water pushes the board sideways (v times the yaw rate) and gravity plus that
## push, the apparent gravity, is what a standing person balances against, as a cyclist
## leans into a bend. A board banked into its turn by exactly atan(v w / g) feels level;
## that is the bank of a carved turn, and a sailor neither fights it nor falls off it.
func _felt_heel_rad() -> float:
	return _apparent_heel_rad(_felt_push_ms2, _felt_lift_ms2)


## The felt heel for the fall checks, with the slower push (fall_feel_time_s).
func _fall_heel_rad() -> float:
	return _apparent_heel_rad(_fall_push_ms2, _fall_lift_ms2)


## The apparent gravity is gravity less the body's own acceleration (a plumb line held
## by the sailor hangs along it); the felt heel is its angle from the deck's normal.
func _apparent_heel_rad(push_ms2: float, lift_ms2: float) -> float:
	var gravity_body: Vector3 = SimMath.to_body(body.basis, Vector3(0.0, -sim_config.gravity_ms2, 0.0))
	var apparent_x: float = gravity_body.x - push_ms2
	var apparent_down: float = -(gravity_body.y - lift_ms2)
	return atan2(apparent_x, maxf(apparent_down, 0.1))


## Updates the felt acceleration: the acceleration the sailor's body is about to get from
## the forces of this step, in deck axes, averaged over balance_feel_time_s (the sense of
## balance does not follow a quick wobble). It is the sailor's own acceleration, through
## the legs: a board that skids round on a stalled fin turns without pushing its sailor
## sideways, and a slam that the legs take up is hardly felt. Called with the step's
## forces on the sailor collected.
func _feel_the_turn(dt: float) -> void:
	# Across the deck the body is accelerated with the hull under its feet: by the hull's
	# own acceleration, its turn and its yaw, not by its roll and pitch (the light hull
	# twitches in roll at a hundred radians per second squared under a slam; that moves
	# the feet a few millimetres, which the ankles take, and throws nobody). Up and down
	# the body is accelerated by its own forces on its legs.
	var feet_world: Vector3 = body.point_world(feet_body)
	var r: Vector3 = feet_world - body.position
	var up: Vector3 = body.basis.y
	var alpha_yaw: Vector3 = up * body.angular_acceleration().dot(up)
	_hull_acceleration_at_feet = body.linear_acceleration() + alpha_yaw.cross(r) + body.angular_velocity.cross(body.angular_velocity.cross(r))
	var acceleration_world: Vector3 = SimMath.horizontal(_hull_acceleration_at_feet)
	acceleration_world.y = sailor.acceleration_now().y
	var acceleration_body: Vector3 = SimMath.to_body(body.basis, acceleration_world)
	var blend: float = clampf(dt / maxf(sailor_config.balance_feel_time_s, dt), 0.0, 1.0)
	_felt_push_ms2 = lerpf(_felt_push_ms2, acceleration_body.x, blend)
	_felt_lift_ms2 = lerpf(_felt_lift_ms2, acceleration_body.y, blend)
	var slow_blend: float = clampf(dt / maxf(sailor_config.fall_feel_time_s, dt), 0.0, 1.0)
	_fall_push_ms2 = lerpf(_fall_push_ms2, acceleration_body.x, slow_blend)
	_fall_lift_ms2 = lerpf(_fall_lift_ms2, acceleration_body.y, slow_blend)
	_felt_acceleration_world = _felt_acceleration_world.lerp(acceleration_world, blend)


## The frame the sailor stands in: up along the apparent gravity (gravity less the body's
## own felt acceleration, the plumb line in the sailor's hand), x across the board squared
## to that, z aft. The posture is held in this frame, not the deck's: a standing person
## stays upright when the floor tilts under them, and leans into a turn with its push.
func _posture_frame() -> Basis:
	# Only the sideways push counts, and no more than 0.6 g of it (a 31 degree lean): a
	# hull dropping away faster than gravity for a moment must not turn the frame over.
	var push: Vector3 = SimMath.horizontal(_felt_acceleration_world).limit_length(0.6 * sim_config.gravity_ms2)
	var apparent_gravity: Vector3 = Vector3(0.0, -sim_config.gravity_ms2, 0.0) - push
	return _frame_with_up(-apparent_gravity.normalized())


## Puts the rig on the mast foot, pointing the way the mast foot and the hands make it
## (RigFrame): with the hull's heading and pitch, but upright in roll, leaned and raked
## from there as the controls ask. The rig turns with the hull's yaw and pitch rates, not
## its roll rate. (Held in the apparent gravity like the posture, every sideways jolt of
## the hull leaned the rig, the sail's force swung with it and pushed the hull again, and
## the board wobbled in yaw at about 1 Hz on flat water.)
func _hold_the_rig() -> void:
	var forward: Vector3 = SimMath.forward(body.basis)
	var z: Vector3 = -forward
	var x: Vector3 = Vector3.UP.cross(z)
	if x.length() < 0.2:
		# Standing on its nose or tail: no heading to speak of; keep the deck's across.
		x = body.basis.x
	x = x.normalized()
	var rig_basis: Basis = Basis(x, z.cross(x), z)
	var spin: Vector3 = body.angular_velocity - forward * body.angular_velocity.dot(forward)
	rig.hold_on_hull(body, sail_config.mast_foot_local, rig_basis, spin)


## A frame with the given up and the hull's heading: x across the board squared to up,
## z aft.
func _frame_with_up(up: Vector3) -> Basis:
	var x: Vector3 = body.basis.x - up * body.basis.x.dot(up)
	if x.length() < 0.2:
		x = body.basis.z.cross(up)
	x = x.normalized()
	return Basis(x, up, x.cross(up))


## Where the feet stand and where the posture puts the centre of mass: the mass model's
## posture (lean, stance, hang-back), taken from the deck at the stance on the centreline
## in the apparent-gravity frame. The feet follow the body out to the rail, but never get
## ahead of it (a sailor whose feet are outboard of their weight falls inboard) and never
## further than the lean the sailor means to have; the rail press shifts them without
## moving the body: the legs angle instead.
func _set_posture() -> void:
	mass_model.update(body_stance, lean, hang_back_m, 0.0, _rig_lean_now_rad)
	var body_lean: float = SimMath.to_body(body.basis, sailor.position - body.origin_world()).x / sailor_config.lean_max_m
	var feet_lean: float = body_lean
	if absf(lean) < absf(body_lean) or signf(lean) != signf(body_lean):
		feet_lean = lean if signf(lean) == signf(body_lean) else 0.0
	feet_body = mass_model.feet_position_body(stance, feet_lean, rail_press, trim_press_m)
	# The body stands at its own stance (the feet may have stepped ahead of it); the trim
	# press moves only the feet's pressure.
	posture_centre_body = Vector3(0.0, feet_body.y, mass_model.sailor_position_body.z - hang_back_m)
	var from_centre: Vector3 = mass_model.sailor_position_body - posture_centre_body
	var target_world: Vector3 = body.point_world(posture_centre_body) + _posture_frame() * from_centre
	posture_target_body = SimMath.to_body(body.basis, target_world - body.origin_world())


## Where the rig leans sideways: it hangs toward the sailor with the lean (the sailor pulls
## it over), and the arms tilt it further or back within their reach.
func _rig_lean_rad(controls: SimControls) -> float:
	var hanging: float = lean * deg_to_rad(sailor_config.max_rig_lean_deg)
	var tilted: float = clampf(controls.rig_tilt, -1.0, 1.0) * deg_to_rad(sailor_config.rig_tilt_range_deg)
	var limit: float = deg_to_rad(sailor_config.max_total_rig_lean_deg)
	return clampf(hanging + tilted, -limit, limit)


## The sailor's own movements: stepping back as the board accelerates, and leaning to
## balance. Both are rate-limited to what a person can do. They set the posture: where
## the feet stand and where the body's centre is held over them.
func _update_sailor(dt: float, controls: SimControls) -> void:
	var forward_speed: float = -SimMath.to_body(body.basis, body.velocity).z
	var stance_target: float = smoothstep(sailor_config.stance_speed_start_ms, sailor_config.stance_speed_full_ms, forward_speed)
	# Through the hump the weight goes aft as long as the bow is below the hump attitude
	# (SailorConfig.hump_trim_deg), and stays there once the bow is up: a sailor steps back
	# until the nose lifts and does not walk forward again while the board climbs onto the
	# plane. (Until Session 39 the stance followed the bow in proportion, so the sailor
	# walked forward as soon as the bow began to rise and pressed it down again mid-hump.)
	var hump_speed: float = board_config.residuary_peak_froude * sqrt(sim_config.gravity_ms2 * board_config.length_m)
	if forward_speed > hump_speed:
		var bow_low: bool = rad_to_deg(SimMath.pitch_rad(body.basis)) < sailor_config.hump_trim_deg
		stance_target = maxf(stance_target, 1.0 if bow_low else stance)
	# In a tack the sailor steps round the front of the mast instead, and quickly, but only
	# as far as the nose allows: a board still carrying speed buries its nose under a sailor
	# who steps forward too early, so the sailor stops stepping (and backs off) as the
	# bottom at the nose sinks toward deck depth, where the water would come over the nose.
	var stepping: bool = controls.step_forward > 0.0
	var nose_depth: float = buoyancy.point_depths_m[buoyancy.bow_centre_index]
	var nose_room: float = clampf((board_config.thickness_m - nose_depth) / sailor_config.nose_dive_ramp_m, 0.0, 1.0)
	stance_target = lerpf(stance_target, -1.0, clampf(controls.step_forward, 0.0, 1.0) * nose_room)
	var stance_rate: float = sailor_config.step_rate_per_s if stepping else sailor_config.stance_rate_per_s
	if not controls.freeze_fore_aft:
		stance = move_toward(stance, stance_target, stance_rate * dt)
		body_stance = move_toward(body_stance, stance, sailor_config.stance_rate_per_s * dt)
	# Trimming with the feet over the hump: the back foot presses when the bow is below
	# hump_trim_deg, the front foot when it is above (nothing below hump speed, where the
	# stance does the work; nothing while stepping round the mast in a tack).
	var press_target: float = 0.0
	if forward_speed > hump_speed and not stepping and controls.balance_reflex:
		# Only as far as the board is planing: standing on the tail of a board that has
		# dropped off the plane sinks the stern and rears the nose.
		press_target = clampf((sailor_config.running_trim_deg - rad_to_deg(SimMath.pitch_rad(body.basis))) / sailor_config.trim_press_band_deg, -1.0, 1.0) * sailor_config.trim_press_max_m * clampf(hull.planing_ratio, 0.0, 1.0)
	if not controls.freeze_fore_aft:
		trim_press_m = move_toward(trim_press_m, press_target, sailor_config.trim_press_rate_ms * dt)

	var asked: float = clampf(controls.lean, -1.0, 1.0)
	_asked_lean = asked
	_asked_across = controls.boom_across
	# The lean the controls ask for is weight on a rail: the feet press it (rail_press),
	# which banks the board, and a banked planing board carves. The bank that asks for
	# is the one a coordinated turn at carve_rate_dps (times the lean) needs at this
	# speed, atan(v w / g), capped at bank_max_deg: the fall checks allow that much heel
	# on purpose. The body itself is leaned to balance, not to bank.
	rail_press = move_toward(rail_press, asked, sailor_config.rail_press_rate_per_s * dt)
	var lean_target: float = asked
	if controls.balance_reflex:
		var bank_target: float = _bank_for_turn(asked, forward_speed) + _fin_load_bank_rad(asked)
		_wanted_bank_rad = move_toward(_wanted_bank_rad, bank_target, deg_to_rad(sailor_config.bank_rate_dps) * dt)
		# The sailor leans against the pull in the hands: the hands' moment about the feet
		# (positive = the body is being pulled over to port) is answered by moving the
		# weight to starboard (positive lean) until the weight's moment about the feet
		# matches it: the centre of mass at (moment / weight) outboard of the feet.
		var weight_n: float = sailor_config.mass_kg * sim_config.gravity_ms2
		var feed_forward: float = sailor_config.balance_moment_gain * (_felt_hand_moment_nm / weight_n + feet_body.x) / sailor_config.lean_max_m
		lean_target = clampf(feed_forward, -1.0, 1.0)
	else:
		_wanted_bank_rad = 0.0
	lean = move_toward(lean, lean_target, sailor_config.lean_rate_per_s * dt)

	# The boom pulls the sailor forward; the sailor leans back until their weight balances
	# the pull about the feet (the same balance as the sideways lean, fore and aft). A
	# positive moment about the starboard axis tips the body's top aft, so a forward pull
	# at the hands is a negative one, answered by the weight that far behind the feet.
	var weight_n: float = sailor_config.mass_kg * sim_config.gravity_ms2
	var hang_target: float = clampf(-sailor_config.balance_moment_gain * _felt_hand_pitch_moment_nm / weight_n, 0.0, sailor_config.hang_back_max_m)
	# Pitch reflex: when the nose rises fast the sailor moves their weight forward, and back
	# when it drops. This is how a sailor stops a planing board from porpoising. (On a
	# pitched deck the body stands square to gravity by itself: the posture is held in the
	# apparent gravity, so the weight stays over the feet and does not push the low end
	# further down.)
	if controls.balance_reflex:
		var pitch_rate: float = body.angular_velocity_body().x
		hang_target = clampf(hang_target - sailor_config.pitch_reflex_m_per_rad_s * pitch_rate, -0.3, sailor_config.hang_back_max_m)
	if not controls.freeze_fore_aft:
		hang_back_m = move_toward(hang_back_m, hang_target, sailor_config.lean_rate_per_s * sailor_config.hang_back_max_m * dt)

	# The posture: where the body's centre is held and where the feet stand. The rig's own
	# mass leans with the rig.
	_rig_lean_now_rad = _rig_lean_rad(controls)
	_set_posture()


## The water the fin carries when it moves broadside: a flat plate of chord c moving
## normal to itself carries rho pi c^2 / 4 per metre of span (Newman, Marine Hydrodynamics,
## 1977, table 4.3, a = c / 2); the hull bottom is a wall at its root, a mirror, so the
## two-dimensional value holds along the span. 2.8 kg for the 38 cm fin: about a third of
## the board's own mass, and the one part of the water around the hull that is still
## there when the hull skims. Times the part of the span under water.
func _fin_added_mass_kg() -> float:
	var chord: float = fin_config.area_m2 / maxf(fin_config.span_m, 0.01)
	return water_config.density_kg_m3 * PI * chord * chord / 4.0 * fin_config.span_m * fin.immersed_fraction


## All the water that moves with the hull sideways: its immersed sides and the fin.
func _sway_added_mass_kg() -> float:
	return hull.sway_added_mass_kg + _fin_added_mass_kg()


## The inertia of the hull plus the water it drags along when it turns (yaw), pitches and
## rolls (the wet bottom's added inertias, from the last hull computation).
func _inertia_with_added_water(base: Basis) -> Basis:
	var inertia: Basis = base
	inertia.x = Vector3(inertia.x.x + hull.pitch_added_inertia_kgm2, inertia.x.y, inertia.x.z)
	var fin_lever: float = fin_config.root_local.z - body.com_offset_body.z
	var yaw_added: float = hull.yaw_added_inertia_kgm2 + _fin_added_mass_kg() * fin_lever * fin_lever
	inertia.y = Vector3(inertia.y.x, inertia.y.y + yaw_added, inertia.y.z)
	inertia.z = Vector3(inertia.z.x, inertia.z.y, inertia.z.z + hull.roll_added_inertia_kgm2)
	return inertia


## The rig is held at the mast foot (a joint: force, no moment) and at the boom by the
## hands and the harness line. Taken as weightless in motion (8 kg against the sailor's
## 75), it is in balance at every instant: the moment of the sail force and of the rig's
## weight about the mast foot is what the hands hold. A force at the grip balances it
## only across the grip line r (from the mast foot to the grip): H_perp = (M x r) / |r|^2;
## along r the sailor may pull or push as they like (that only loads the mast), and the
## part of the moment about r itself, which no force there can supply, is the twist the
## two hands take as a couple and pass through the body to the feet.
##
## The pull along r is the harness. Hooked in, the sailor hangs in a line from the hips
## to the boom, and lets it carry as much of the pull as its direction allows, the arms
## taking only what is left: the line's tension T along d (from the hips to the grip) and
## the pull s along r are the least-squares fit of T d to H_perp + s r. With the hips
## below and outboard of the boom the line pulls upward: the harness carries a good part
## of the sailor's weight, the feet go light, and the rig presses the mast foot down (the
## mast foot pressure every windsurfer feels, which holds the nose down at speed). With
## the line slack (T would be negative) the arms hold the rig and nothing changes. What
## is left of the sail force and the rig's weight goes into the hull at the mast foot.
func _apply_rig_forces() -> void:
	var foot_world: Vector3 = rig.foot_world
	var mast_dir: Vector3 = sail.mast_direction()
	# From the mast foot to the grip, along the rig's own axes (the sailor's frame).
	var grip: Vector3 = rig.basis * (mast_dir * sail_config.boom_height_m + sail.boom_direction_local * sailor_config.hand_grip_m)
	_hands_world = foot_world + grip
	hand_grip_body = SimMath.to_body(body.basis, _hands_world - body.origin_world())
	var rig_weight: Vector3 = Vector3(0.0, -sim_config.gravity_ms2 * sail_config.rig_mass_kg, 0.0)
	var rig_com: Vector3 = rig.basis * (mast_dir * sail_config.rig_com_height_m)
	var moment: Vector3 = (sail.ce_world - foot_world).cross(sail.force_world) + rig_com.cross(rig_weight)
	var grip_length_squared: float = maxf(grip.length_squared(), 0.01)
	var hand_perp: Vector3 = moment.cross(grip) / grip_length_squared
	_hand_twist_world = grip * (moment.dot(grip) / grip_length_squared)
	var along_grip: float = 0.0
	harness_tension_n = 0.0
	var line: Vector3 = foot_world + grip - sailor.position
	if line.length() > 0.3:
		var r_hat: Vector3 = grip / sqrt(grip_length_squared)
		var d_hat: Vector3 = line.normalized()
		var c: float = r_hat.dot(d_hat)
		if 1.0 - c * c > 0.05:
			harness_tension_n = maxf(hand_perp.dot(d_hat) / (1.0 - c * c), 0.0)
			along_grip = c * harness_tension_n
	hand_force_world = hand_perp + grip * (along_grip / sqrt(grip_length_squared))
	mast_foot_force_world = sail.force_world + rig_weight - hand_force_world
	body.add_force_at(foot_world, mast_foot_force_world)
	sailor.add_force(hand_force_world)


## Air drag of the sailor's body, on the sailor. Small but real: it is what keeps a sail's
## lift-to-drag ratio near what sailors actually get.
func _apply_windage() -> void:
	windage_force_world = Vector3.ZERO
	var apparent: Vector3 = wind.velocity_at(sailor.position) - sailor.velocity
	var speed: float = apparent.length()
	if speed < 0.1:
		return
	var drag: float = 0.5 * air_density_kg_m3 * sailor_config.windage_area_cd_m2 * speed * speed
	windage_force_world = apparent / speed * drag
	sailor.add_force(windage_force_world)


## The legs, between the feet on the deck and the body's centre of mass. Across the deck
## the body rides the hull (its mass is in the hull's sideways and yaw inertia, see
## _set_hull_mass_properties, and _ride_the_hull keeps it on the posture). Up and down
## the legs are a spring and damper at leg_natural_frequency_hz (the knees) with a soft
## stop at the end of their travel: what the board does under the feet (a wave, a slam)
## the knees take, and the body hardly moves. The steady loads, the weight and the pull
## the body has taken up (hold_feel_time_s), the legs carry outright, as a person braced
## against a pull does; across the deck the pull goes straight through.
##
## The deck gets the same force back at the feet, and a moment. A point mass carries no
## moment, so the steady loads on the body (the weight the legs hold, the pull at the
## boom, the body's own inertia as the hull accelerates under it, the hands' twist) have
## to balance about the centre of mass, and what is left over is what the feet pass to
## the deck. With it goes the toes-and-heels reflex that holds the board at the bank the
## sailor wants (feet_roll_stiffness_nm_per_rad). In roll the feet can pass at most
## feet_moment_max_nm; the rest would tip the body sideways, which the hips, the knees
## and the arms on the boom can hold up to hip_force_max_n (and the harness line more):
## tipped harder than that for longer than tip_time_s, the sailor goes. A sailor in
## balance passes nothing beyond where the feet stand; an overpowered one heels the
## board a little, then goes over the sail.
func _apply_leg_forces(dt: float) -> void:
	var m: float = sailor.mass_kg
	var g: float = sim_config.gravity_ms2
	var weight: Vector3 = Vector3(0.0, -g * m, 0.0)
	var feet_world: Vector3 = body.point_world(feet_body)
	var target_world: Vector3 = body.point_world(posture_target_body)

	# The pull taken up by the body: at once across the deck, over hold_feel_time_s in
	# the vertical. The lean answers the pull averaged over lean_feel_time_s.
	var pull: Vector3 = hand_force_world + windage_force_world
	var blend: float = clampf(dt / maxf(sailor_config.hold_feel_time_s, dt), 0.0, 1.0)
	_held_force_world = _held_force_world.lerp(pull, blend)
	var lean_blend: float = clampf(dt / maxf(sailor_config.lean_feel_time_s, dt), 0.0, 1.0)
	_felt_hand_moment_nm = lerpf(_felt_hand_moment_nm, hand_moment_body.z, lean_blend)
	_felt_hand_pitch_moment_nm = lerpf(_felt_hand_pitch_moment_nm, hand_moment_body.x, lean_blend)
	var hold: Vector3 = Vector3(-pull.x, g * m - _held_force_world.y, -pull.z)

	# The knees: the spring and damper in the vertical, posture minus body, with the
	# damper on the body's speed relative to the deck under the feet, held to the
	# impulse that would bring the two to the same speed (the exact result for a damper
	# integrated implicitly: the hull end is light). The legs run from the feet, so their
	# length is the body's height above the feet, not above the deck's centreline: when
	# the hull rolls and the windward rail rises under the feet, the legs are pressed and
	# press the rail back down (the legs' roll stiffness, k times the rail offset squared).
	var feet_above_centre: float = feet_world.y - body.point_world(posture_centre_body).y
	var along: float = target_world.y + feet_above_centre - sailor.position.y
	var omega_leg: float = TAU * sailor_config.leg_natural_frequency_hz
	var k_leg: float = m * omega_leg * omega_leg
	var c_leg: float = 2.0 * sailor_config.leg_damping_ratio * m * omega_leg
	var spring_n: float = k_leg * along
	if absf(along) > sailor_config.leg_travel_m:
		spring_n += 10.0 * k_leg * (along - signf(along) * sailor_config.leg_travel_m)
	var relative_v: float = body.point_velocity(feet_world).y - sailor.velocity.y
	var knees: Vector3 = Vector3(0.0, spring_n + _damper_force(c_leg, relative_v, feet_world, Vector3.UP, dt), 0.0)

	# The moment the legs' force leaves about the centre of mass, which the feet pass to
	# the deck, plus the toes-and-heels reflex holding the bank. The legs' force here is
	# the hold and the knees, plus the body's height times the force that carries it with
	# the deck (the last substep's: the body's inertia at its height above the deck, the
	# part of that lever the attachment does not apply itself).
	var hands_world: Vector3 = _hands_world
	var com_from_feet: Vector3 = sailor.position - feet_world
	var legs_force: Vector3 = hold + knees
	var height_lever: Vector3 = Vector3(0.0, -com_from_feet.y, 0.0).cross(_attachment_force_world)
	var moment_to_deck: Vector3 = (-com_from_feet).cross(legs_force) + height_lever + (hands_world - sailor.position).cross(hand_force_world) + _hand_twist_world
	var roll_axis: Vector3 = body.basis.z
	var heel_error: float = SimMath.heel_rad(body.basis) - _wanted_bank_rad
	var heel_rate: float = -body.angular_velocity_body().z
	# A positive torque about the aft axis lifts the starboard rail (less heel).
	var reflex: float = sailor_config.feet_roll_stiffness_nm_per_rad * heel_error + sailor_config.feet_roll_damping_nms_per_rad * heel_rate
	# The body's balance comes first; the bank is held with what the feet have left.
	var feet_max: float = sailor_config.feet_moment_max_nm
	var residual: float = moment_to_deck.dot(roll_axis)
	var residual_passed: float = clampf(residual, -feet_max, feet_max)
	feet_moment_excess_nm = residual - residual_passed
	var roll_passed: float = residual_passed + clampf(reflex, -feet_max - residual_passed, feet_max - residual_passed)
	# What the feet cannot pass would tip the body about them: a force across the leg
	# line at the centre of mass, excess / leg length. The hips hold it up to hip_max;
	# more than that for longer than a jolt and the body goes.
	var leg_length: float = maxf(com_from_feet.length(), 0.3)
	var leg_dir: Vector3 = com_from_feet / leg_length
	var lever: float = maxf(1.0 - leg_dir.dot(roll_axis) * leg_dir.dot(roll_axis), 0.3)
	_tipping_force_world = roll_axis.cross(leg_dir) * (feet_moment_excess_nm / (leg_length * lever))
	var hip_max: float = sailor_config.hip_force_max_n + sailor_config.harness_hold_max_n * clampf(absf(lean), 0.0, 1.0)
	if _tipping_force_world.length() > hip_max:
		_tipping_for_s += dt
	else:
		_tipping_for_s = 0.0

	leg_force_world = hold + knees
	feet_moment_world = moment_to_deck + roll_axis * (roll_passed - residual)
	sailor.add_force(leg_force_world)
	body.add_force_at(feet_world, -leg_force_world)
	body.add_torque(feet_moment_world)
	hand_moment_body = SimMath.to_body(body.basis, (hands_world - feet_world).cross(hand_force_world))
	_pull_the_harness_line(hands_world, target_world, dt)

	knee_bend_m = along
	leg_sway_m = 0.0


## The harness line as a rope between the hips and the boom. Its length is what the
## posture gives it; hooked in, it pulls the body toward the boom when the boom has moved
## further away than that (the board rising under the sailor) and does nothing when the
## boom is closer (the board dropping away). The pull goes into the rig and so into the
## hull at the mast foot. The steady part of the sailor's hanging weight is already in
## the rig balance (_apply_rig_forces); this is only the jolt.
func _pull_the_harness_line(hands_world: Vector3, target_world: Vector3, dt: float) -> void:
	harness_jolt_n = 0.0
	# A line without stiffness is not there (the rope is off, section 7.5): its damper on
	# its own acted as a rigid strut against the boom rising and jolted the body with up
	# to 700 N when the board was kicked up at rest.
	if harness_tension_n <= 0.0 or sailor_config.harness_line_stiffness_n_m <= 0.0:
		return
	var line: Vector3 = hands_world - sailor.position
	var length: float = line.length()
	var rest: float = (hands_world - target_world).length()
	if length < 0.05 or length <= rest:
		return
	var direction: Vector3 = line / length
	var separating: float = (body.point_velocity(hands_world) - sailor.velocity).dot(direction)
	var pull: float = sailor_config.harness_line_stiffness_n_m * (length - rest)
	if separating > 0.0:
		pull += _damper_force(sailor_config.harness_line_damping_ns_m, separating, hands_world, direction, dt)
	harness_jolt_n = pull
	sailor.add_force(direction * pull)
	body.add_force_at(body.point_world(sail_config.mast_foot_local), -direction * pull)



## Across the deck the body goes with the deck under its feet: the force that makes the
## body's horizontal acceleration the same as the feet's is found from the hull's
## response to it and applied to both: F on the body, -F on the hull. The hull feels it
## at the deck under the body's mass: the body's horizontal offset from the feet (hiked
## out, hanging back) is a lever on the hull's yaw and pitch, which is what lets a hull
## with a sailor hiked out a metre to windward turn about their common centre of mass,
## near the sailor, not about the hull's own (a lumped sailor at the hull's centre made
## the board seven times too sluggish in yaw). The body's height above the deck is a
## lever too, but that one goes through the ankles (_apply_leg_forces), bounded: put
## here, a metre of lever on a hull with next to no roll inertia blew up.
##   a_feet = A - B F,  m a_sailor = F (the other horizontal forces on the body cancel in
##   the hold),  a_sailor = a_feet  =>  (I + m B) F = m A
## with A the feet's acceleration from the forces collected so far and B the 2 x 2
## horizontal mobility of the feet for a force at the deck under the body.
func _attach_sailor_across_the_deck() -> void:
	var m: float = sailor.mass_kg
	var feet_world: Vector3 = body.point_world(feet_body)
	var under_body: Vector3 = feet_world + SimMath.horizontal(sailor.position - feet_world)
	var a: Vector3 = SimMath.horizontal(body.acceleration_at(feet_world))
	var ex: Vector3 = Vector3.RIGHT
	var ez: Vector3 = Vector3.BACK
	var bxx: float = 1.0 + m * body.mobility(feet_world, under_body, ex, ex)
	var bxz: float = m * body.mobility(feet_world, under_body, ex, ez)
	var bzx: float = m * body.mobility(feet_world, under_body, ez, ex)
	var bzz: float = 1.0 + m * body.mobility(feet_world, under_body, ez, ez)
	var det: float = bxx * bzz - bxz * bzx
	if absf(det) < 1e-9:
		return
	var fx: float = (bzz * m * a.x - bxz * m * a.z) / det
	var fz: float = (-bzx * m * a.x + bxx * m * a.z) / det
	_attachment_force_world = Vector3(fx, 0.0, fz)
	sailor.add_force(_attachment_force_world)
	body.add_force_at(under_body, -_attachment_force_world)


## The body rides the hull across the deck: after the hull has moved, the body's
## horizontal position and speed are those of its posture (the deck under the feet plus
## the posture's own, slow moves). Up and down it is on its legs.
func _ride_the_hull(dt: float) -> void:
	var feet_world: Vector3 = body.point_world(feet_body)
	var target_world: Vector3 = body.point_world(posture_target_body)
	var offset: Vector3 = SimMath.horizontal(target_world - feet_world)
	# The posture's own moves are at the sailor's pace (lean_rate_per_s of lean_max_m, a
	# walking pace); a jump of the frame is a jump, not a speed. Faster than that, a body
	# moved into the apparent gravity of a turn kicked the hull round with its inertia,
	# the push grew, and the board spun up to 100 degrees a second at a tack's entry.
	var offset_rate: Vector3 = Vector3.ZERO
	if _offset_prev_valid:
		offset_rate = ((offset - _offset_prev) / dt).limit_length(sailor_config.lean_rate_per_s * sailor_config.lean_max_m)
	_offset_prev = offset
	_offset_prev_valid = true
	var v_target: Vector3 = SimMath.horizontal(body.point_velocity(feet_world)) + offset_rate
	sailor.position.x = target_world.x
	sailor.position.z = target_world.z
	sailor.velocity.x = v_target.x
	sailor.velocity.z = v_target.z


## A damper's force c v along a direction, held to what would bring the sailor and the
## hull point to the same speed within the step: m_reduced v / dt, with the reduced mass
## of the two ends (1 / m_sailor + 1 / m_hull_effective at the feet).
func _damper_force(c: float, relative_speed: float, feet_world: Vector3, direction: Vector3, dt: float) -> float:
	var m_hull: float = body.effective_mass_at(feet_world, direction)
	var m_reduced: float = 1.0 / (1.0 / sailor.mass_kg + 1.0 / maxf(m_hull, 0.1))
	var force: float = c * relative_speed
	var limit: float = m_reduced * absf(relative_speed) / dt
	return clampf(force, -limit, limit)


func _fill_telemetry(controls: SimControls) -> void:
	var t: Telemetry = telemetry
	t.time_s = time_s
	t.position = body.origin_world()
	var v_h: Vector3 = SimMath.horizontal(body.velocity)
	t.speed_ms = v_h.length()
	t.speed_kmh = t.speed_ms * 3.6
	t.speed_kt = t.speed_ms / SimMath.KNOT_MS
	t.heading_deg = rad_to_deg(SimMath.heading_rad(body.basis))
	t.pitch_deg = rad_to_deg(SimMath.pitch_rad(body.basis))
	t.heel_deg = rad_to_deg(SimMath.heel_rad(body.basis))
	t.yaw_rate_dps = rad_to_deg(body.angular_velocity_body().y)
	t.leeway_deg = rad_to_deg(SimMath.slip_angle_rad(SimMath.to_body(body.basis, v_h)))

	var from_true: Vector3 = wind.from_direction()
	t.wind_from_bearing_deg = rad_to_deg(wind.current_from_bearing_rad)
	t.tws_10m_kt = wind.speed_at_height(wind.config.reference_height_m) / SimMath.KNOT_MS
	t.tws_at_sail_kt = sail.true_wind_at_ce_world.length() / SimMath.KNOT_MS
	t.twa_deg = rad_to_deg(SimMath.wind_angle_rad(body.basis, from_true))
	# The wind the sail meets comes from where the air at the sail comes from (a map's local
	# wind); before the sail has been computed, the mean wind.
	var at_sail: Vector3 = sail.true_wind_at_ce_world
	t.twa_at_sail_deg = rad_to_deg(SimMath.wind_angle_rad(body.basis, -at_sail)) if at_sail.length_squared() > 1e-6 else t.twa_deg
	t.vmg_ms = v_h.dot(from_true)
	t.aws_kt = sail.aws_ms / SimMath.KNOT_MS
	t.awa_deg = rad_to_deg(sail.awa_rad)

	t.sail_side = sail.sail_side
	t.sheet = controls.sheet
	t.rake = controls.rake
	t.rig_tilt = controls.rig_tilt
	t.boom_across = controls.boom_across
	t.is_backwinded = sail.is_backwinded
	t.rig_lean_deg = rad_to_deg(sail.rig_lean_rad)
	t.sail_angle_deg = rad_to_deg(sail.sail_angle_rad())
	t.alpha_deg = rad_to_deg(sail.alpha_rad)
	t.sail_lift_n = sail.lift_n
	t.sail_drag_n = sail.drag_n
	t.drive_n = sail.drive_n
	t.side_force_n = sail.side_force_n
	t.is_luffing = sail.is_luffing
	t.ce_local = sail.ce_local

	t.fin_slip_deg = rad_to_deg(fin.slip_rad)
	t.fin_lift_n = fin.lift_n
	t.fin_drag_n = fin.drag_n
	t.fin_stalled = fin.is_stalled
	t.fin_immersed = fin.immersed_fraction

	t.buoyancy_n = buoyancy.buoyancy_force_n
	t.submersion_ratio = buoyancy.submersion_ratio
	t.wetted_area_m2 = buoyancy.wetted_area_m2
	t.planing_lift_n = hull.planing_lift_n
	t.planing_ratio = hull.planing_ratio
	t.wetted_length_m = hull.wetted_length_m
	t.wetted_aft_m = hull.wetted_aft_m
	t.friction_area_m2 = hull.friction_area_m2
	t.wet_front_m = hull.wetted_aft_m + hull.wetted_length_m
	t.spray_root_factor = hull.spray_root_factor
	t.heave_added_mass_kg = hull.heave_added_mass_kg
	# The heeling moment the sailor has to hold: the hands' pull about the feet (what the
	# autopilot trims the sheet to).
	t.heeling_torque_nm = hand_moment_body.z
	t.planing_cop_z_m = hull.cop_local.z
	# The hull's origin is the middle of the board and body z points aft, so the tail is at
	# z = +length / 2.
	t.push_centre_m = 0.5 * board_config.length_m - hull.cop_local.z
	t.bow_immersion_m = buoyancy.point_depths_m[buoyancy.bow_centre_index]
	t.is_planing = hull.planing_ratio > 0.5
	t.trim_deg = hull.trim_deg
	t.hull_friction_n = hull.friction_n
	t.hull_residuary_n = hull.residuary_n
	t.hull_lateral_n = hull.lateral_n
	t.hull_resistance_n = hull.resistance_n
	t.bow_drag_n = hull.bow_drag_n
	t.rail_grip_n = hull.rail_grip_n
	t.rail_yaw_nm = hull.rail_yaw_nm
	var origin: Vector3 = body.origin_world()
	t.water_height_m = water.height_at(origin.x, origin.z, time_s)

	t.sailor_state = sailor_state
	t.fall_kind = fall_kind
	t.waterstart_in_s = maxf(sailor_config.waterstart_time_s - fallen_for_s, 0.0) if sailor_state == SailorState.FALLEN else 0.0
	t.stance = stance
	t.wanted_bank_deg = rad_to_deg(_wanted_bank_rad)
	t.felt_push_ms2 = _felt_push_ms2
	t.felt_heel_deg = rad_to_deg(_felt_heel_rad())
	t.lean = lean
	t.rail_press = rail_press
	t.hang_back_m = hang_back_m
	t.knee_bend_m = knee_bend_m
	t.leg_sway_m = leg_sway_m
	t.sailor_position_body = SimMath.to_body(body.basis, sailor.position - origin)
	t.posture_target_body = posture_target_body
	t.feet_body = feet_body
	t.hand_grip_body = hand_grip_body
	t.com_offset_body = mass_model.com_offset_body
	t.total_mass_kg = mass_model.total_mass_kg
	t.hand_force_n = hand_force_world.length()
	t.hand_force_body = SimMath.to_body(body.basis, hand_force_world)
	t.hand_force_up_n = hand_force_world.y
	t.mast_foot_force_up_n = mast_foot_force_world.y
	var foot_arm: Vector3 = body.point_world(sail_config.mast_foot_local) - body.position
	var feet_arm: Vector3 = body.point_world(feet_body) - body.position
	t.pitch_from_mast_foot_nm = SimMath.to_body(body.basis, foot_arm.cross(mast_foot_force_world)).x
	var under_arm: Vector3 = feet_arm + SimMath.horizontal(sailor.position - body.point_world(feet_body))
	t.pitch_from_feet_force_nm = SimMath.to_body(body.basis, feet_arm.cross(-leg_force_world) + under_arm.cross(-_attachment_force_world)).x
	t.pitch_from_feet_moment_nm = SimMath.to_body(body.basis, feet_moment_world).x
	t.attachment_x_n = _attachment_force_world.x
	t.attachment_z_n = _attachment_force_world.z
	t.harness_tension_n = harness_tension_n
	t.foot_force_n = leg_force_world.length()
	t.mast_foot_force_n = mast_foot_force_world.length()
	t.feet_moment_roll_nm = SimMath.to_body(body.basis, feet_moment_world).z
	t.hand_moment_roll_nm = hand_moment_body.z
	t.feet_moment_excess_nm = feet_moment_excess_nm
	# What turns (yaw) and heels (roll) the hull, by source: the fin, the rig at the mast
	# foot, the sailor through the feet, and the water on the hull (everything else).
	var centre: Vector3 = body.position
	var fin_torque: Vector3 = (fin.cop_world - centre).cross(fin.force_world)
	var rig_torque: Vector3 = (body.point_world(sail_config.mast_foot_local) - centre).cross(mast_foot_force_world)
	var feet_world: Vector3 = body.point_world(feet_body)
	var under_body: Vector3 = feet_world + SimMath.horizontal(sailor.position - feet_world)
	var sailor_torque: Vector3 = (feet_world - centre).cross(-leg_force_world) + (under_body - centre).cross(-_attachment_force_world) + feet_moment_world
	var water_torque: Vector3 = _net_torque_world - fin_torque - rig_torque - sailor_torque
	var fin_body: Vector3 = SimMath.to_body(body.basis, fin_torque)
	var rig_body: Vector3 = SimMath.to_body(body.basis, rig_torque)
	var sailor_body_t: Vector3 = SimMath.to_body(body.basis, sailor_torque)
	var water_body: Vector3 = SimMath.to_body(body.basis, water_torque)
	var net_body: Vector3 = SimMath.to_body(body.basis, _net_torque_world)
	t.yaw_fin_nm = fin_body.y
	t.yaw_rig_nm = rig_body.y
	t.yaw_sailor_nm = sailor_body_t.y
	t.yaw_water_nm = water_body.y
	t.yaw_net_nm = net_body.y
	t.roll_fin_nm = fin_body.z
	t.roll_rig_nm = rig_body.z
	t.roll_sailor_nm = sailor_body_t.z
	t.roll_water_nm = water_body.z
	t.roll_net_nm = net_body.z
