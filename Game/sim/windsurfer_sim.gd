class_name WindsurferSim
extends RefCounted
## The whole windsurfer as one simulation: a rigid body (board, rig and sailor), the water
## under it, the wind over it, and the force models that connect them (PHYSICS_SPEC.md).
## step(dt, controls) advances the state; `telemetry` reports what happened. No Nodes:
## tests run this headless and the windsurfer scene copies the state onto the visuals.
##
## The sailor is part of the body and behaves like a person: the stance moves aft as the
## board speeds up (into the footstraps), and a balance reflex leans the sailor against the
## heel and the sail's pull, within what a real sailor can do (section 15).

var board_config: BoardConfig
var sail_config: SailConfig
var fin_config: FinConfig
var sailor_config: SailorConfig
var water_config: WaterConfig
var wind_config: WindConfig
var sim_config: SimConfig

var body: SimRigidBody = SimRigidBody.new()
var mass_model: MassModel
var buoyancy: BuoyancyModel
var hull: HullModel
var fin: FinModel
var sail: SailModel
var wind: WindField
var water: WaterSurface
var telemetry: Telemetry = Telemetry.new()

const RHO_AIR: float = 1.225

enum SailorState { SAILING, FALLEN }

var time_s: float = 0.0
## Whether the sailor is on the board or in the water. The board, rig and sailor are one
## body only while the sailor stands on it and balances the sail; when that balance is
## lost the sailor and the rig go over (the rig pivots freely at the mast foot, so the sail
## cannot roll the board over) and the body is the board alone until the waterstart.
var sailor_state: SailorState = SailorState.SAILING
## Which side the sailor and rig fell to (+1 starboard, -1 port), what kind of fall it
## was ("catapult" to leeward, "fell back" to windward), and for how long.
var fall_side: int = 0
var fall_kind: String = ""
var fallen_for_s: float = 0.0
var _tack_before_fall: float = 1.0
## 0 = standing near the mast foot, 1 = in the back straps.
var stance: float = 0.0
## -1 = sailor out to port, +1 = out to starboard.
var lean: float = 0.0
## How far the sailor's weight hangs back behind the feet, metres.
var hang_back_m: float = 0.0
## How far the sailor's knees have flexed (positive = the body sits lower), and how fast.
var knee_bend_m: float = 0.0
var knee_bend_rate_ms: float = 0.0


func _init(board: BoardConfig, sail_cfg: SailConfig, fin_cfg: FinConfig, sailor: SailorConfig,
		water_cfg: WaterConfig, wind_cfg: WindConfig, sim_cfg: SimConfig) -> void:
	board_config = board
	sail_config = sail_cfg
	fin_config = fin_cfg
	sailor_config = sailor
	water_config = water_cfg
	wind_config = wind_cfg
	sim_config = sim_cfg
	mass_model = MassModel.new(board_config, sail_config, sailor_config)
	buoyancy = BuoyancyModel.new(board_config, water_config)
	hull = HullModel.new(board_config, water_config)
	fin = FinModel.new(fin_config)
	sail = SailModel.new(sail_config)
	wind = WindField.new(wind_config)
	water = FlatWater.new(water_config)
	reset(Vector3.ZERO, 0.0)


## Loads the default configuration files.
static func create_default() -> WindsurferSim:
	return WindsurferSim.new(
		load("res://config/board_default.tres"),
		load("res://config/sail_default.tres"),
		load("res://config/fin_default.tres"),
		load("res://config/sailor_default.tres"),
		load("res://config/water_default.tres"),
		load("res://config/wind_default.tres"),
		load("res://config/sim_default.tres"))


## Puts the board at rest, level, floating at about its resting depth, pointing along a
## compass heading, with the sail on the leeward side of the current wind.
func reset(origin_xz: Vector3, heading_rad: float) -> void:
	time_s = 0.0
	sailor_state = SailorState.SAILING
	fall_side = 0
	fall_kind = ""
	fallen_for_s = 0.0
	stance = 0.0
	lean = 0.0
	hang_back_m = 0.0
	knee_bend_m = 0.0
	knee_bend_rate_ms = 0.0
	mass_model.update(stance, lean, hang_back_m, knee_bend_m)
	body = SimRigidBody.new()
	body.set_mass_properties(mass_model.total_mass_kg, mass_model.inertia_body, mass_model.com_offset_body)
	# A positive rotation about +Y turns the bow to port, so a compass heading is a negative angle.
	body.basis = Basis(Vector3.UP, -heading_rad)
	var rest_depth: float = mass_model.total_mass_kg / water_config.density_kg_m3 / board_config.volume_m3 * board_config.thickness_m
	body.set_origin_world(Vector3(origin_xz.x, water_config.base_height_m + 0.5 * board_config.thickness_m - rest_depth, origin_xz.z))
	body.velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	var twa: float = SimMath.wind_angle_rad(body.basis, wind.from_direction())
	sail.set_side_for_wind(twa)
	_fill_telemetry(SimControls.new())


## Advances the simulation by dt seconds (one physics tick), in fixed substeps.
func step(dt: float, controls: SimControls) -> void:
	var substeps: int = maxi(sim_config.substeps, 1)
	var sub_dt: float = dt / substeps
	for i: int in substeps:
		var sailing: bool = sailor_state == SailorState.SAILING
		if sailing:
			_update_sailor(sub_dt, controls)
		wind.step(sub_dt)
		body.add_force(Vector3(0.0, -sim_config.gravity_ms2 * body.mass_kg, 0.0))
		buoyancy.apply(body, water, time_s, sim_config.gravity_ms2, sub_dt)
		hull.compute(body, buoyancy, water, time_s, sim_config.gravity_ms2, body.mass_kg, sub_dt)
		body.added_mass_up_kg = hull.heave_added_mass_kg
		fin.compute(body, water, time_s, water_config.density_kg_m3)
		if sailing:
			sail.compute(body, wind, controls.sheet, controls.rake, RHO_AIR, _rig_lean_rad(controls))
			_apply_windage()
			_flex_legs(sub_dt)
		else:
			_apply_rig_in_water_drag()
		body.integrate(sub_dt)
		time_s += sub_dt
		if sailing:
			_check_balance()
		else:
			fallen_for_s += sub_dt
			if fallen_for_s >= sailor_config.waterstart_time_s:
				waterstart()
	_fill_telemetry(controls)


## A sailor keeps the board upright only as long as their weight can balance the sail's
## pull; the mast foot is a joint and passes no roll moment to the board. So when the board
## heels past what a standing person can recover, it is the sailor who goes, not the board:
## over the sail to leeward when overpowered (a catapult), backwards into the water to
## windward when the pull vanished while hiked out.
func _check_balance() -> void:
	var twa: float = SimMath.wind_angle_rad(body.basis, wind.from_direction())
	var tack: float = 1.0 if twa >= 0.0 else -1.0
	# Heel is positive with the starboard rail down; on starboard tack leeward is port.
	var leeward_heel: float = -SimMath.heel_rad(body.basis) * tack
	if leeward_heel > deg_to_rad(sailor_config.catapult_heel_deg):
		_fall(int(-tack), "catapult", tack)
	elif leeward_heel < -deg_to_rad(sailor_config.fall_back_heel_deg):
		_fall(int(tack), "fell back", tack)


## Makes the sailor fall now, as if they slipped: to leeward ("catapult") or to windward
## ("fell back"). For demos, screenshots and tests.
func force_fall(kind: String) -> void:
	if sailor_state != SailorState.SAILING:
		return
	var twa: float = SimMath.wind_angle_rad(body.basis, wind.from_direction())
	var tack: float = 1.0 if twa >= 0.0 else -1.0
	_fall(int(-tack) if kind == "catapult" else int(tack), kind, tack)


## The sailor and the rig leave the board. The rig floats on its own and the sailor swims,
## so from here the body is the board alone, keeping the speed it had.
func _fall(side: int, kind: String, tack: float) -> void:
	sailor_state = SailorState.FALLEN
	fall_side = side
	fall_kind = kind
	fallen_for_s = 0.0
	_tack_before_fall = tack
	var board_only: Vector3 = MassModel._box_inertia(board_config.mass_kg, board_config.width_m, board_config.thickness_m, board_config.length_m)
	body.set_mass_properties(board_config.mass_kg, Basis.IDENTITY.scaled(board_only), Vector3.ZERO)
	body.internal_velocity = Vector3.ZERO
	stance = 0.0
	lean = 0.0
	hang_back_m = 0.0
	knee_bend_m = 0.0
	knee_bend_rate_ms = 0.0
	sail.clear()


## Back on the board: level, at rest, across the wind on the tack the sailor fell from,
## where the board has drifted to. The sail starts eased (the caller resets its controls).
func waterstart() -> void:
	sailor_state = SailorState.SAILING
	fallen_for_s = 0.0
	stance = 0.0
	lean = 0.0
	hang_back_m = 0.0
	knee_bend_m = 0.0
	knee_bend_rate_ms = 0.0
	mass_model.update(stance, lean, hang_back_m, knee_bend_m)
	body.set_mass_properties(mass_model.total_mass_kg, mass_model.inertia_body, mass_model.com_offset_body)
	var origin: Vector3 = body.origin_world()
	var heading_rad: float = wind.current_from_bearing_rad - _tack_before_fall * PI / 2.0
	body.basis = Basis(Vector3.UP, -heading_rad)
	var rest_depth: float = mass_model.total_mass_kg / water_config.density_kg_m3 / board_config.volume_m3 * board_config.thickness_m
	body.set_origin_world(Vector3(origin.x, water_config.base_height_m + 0.5 * board_config.thickness_m - rest_depth, origin.z))
	body.velocity = Vector3.ZERO
	body.angular_velocity = Vector3.ZERO
	body.internal_velocity = Vector3.ZERO
	sail.set_side_for_wind(SimMath.wind_angle_rad(body.basis, wind.from_direction()))


## The rig lying in the water pulls on the mast foot like a sea anchor. It takes the rig
## about a second to fall onto the water, so the drag comes on over the first second.
func _apply_rig_in_water_drag() -> void:
	var in_the_water: float = smoothstep(0.4, 1.0, fallen_for_s)
	if in_the_water <= 0.0:
		return
	var foot: Vector3 = body.point_world(sail_config.mast_foot_local)
	var surface_height: float = water.height_at(foot.x, foot.z, time_s)
	var v: Vector3 = SimMath.horizontal(body.point_velocity(foot) - water.velocity_at(foot.x, foot.z, time_s))
	var speed: float = v.length()
	if speed < 0.01:
		return
	var drag: float = in_the_water * 0.5 * water_config.density_kg_m3 * sailor_config.rig_in_water_drag_m2 * speed * speed
	body.add_force_at(Vector3(foot.x, surface_height, foot.z), -v / speed * drag)


## Where the rig leans sideways: it hangs toward the sailor with the lean (the sailor pulls
## it over), and the arms tilt it further or back within their reach.
func _rig_lean_rad(controls: SimControls) -> float:
	var hanging: float = lean * deg_to_rad(sailor_config.max_rig_lean_deg)
	var tilted: float = clampf(controls.rig_tilt, -1.0, 1.0) * deg_to_rad(sailor_config.rig_tilt_range_deg)
	var limit: float = deg_to_rad(sailor_config.max_total_rig_lean_deg)
	return clampf(hanging + tilted, -limit, limit)


## The sailor's own movements: stepping back as the board accelerates, and leaning to
## balance. Both are rate-limited to what a person can do.
func _update_sailor(dt: float, controls: SimControls) -> void:
	var forward_speed: float = -SimMath.to_body(body.basis, body.velocity).z
	var stance_target: float = smoothstep(sailor_config.stance_speed_start_ms, sailor_config.stance_speed_full_ms, forward_speed)
	if not controls.freeze_fore_aft:
		stance = move_toward(stance, stance_target, sailor_config.stance_rate_per_s * dt)

	var lean_target: float = clampf(controls.lean, -1.0, 1.0)
	if controls.balance_reflex:
		var heel: float = SimMath.heel_rad(body.basis)
		var heel_rate: float = -body.angular_velocity_body().z
		var max_moment: float = mass_model.max_righting_moment_nm(sim_config.gravity_ms2)
		# A positive sail torque about the aft axis lifts the starboard rail (heels to port);
		# the sailor answers by moving to starboard (positive lean), and the other way round.
		var feed_forward: float = sailor_config.balance_moment_gain * sail.torque_body.z / max_moment
		lean_target += feed_forward - sailor_config.balance_heel_gain * heel - sailor_config.balance_rate_gain * heel_rate
		lean_target = clampf(lean_target, -1.0, 1.0)
	lean = move_toward(lean, lean_target, sailor_config.lean_rate_per_s * dt)

	# The boom pulls the sailor forward; the sailor leans back until their weight balances
	# the pull about the feet (the same balance as the sideways lean, fore and aft).
	var hang_target: float = clampf(maxf(sail.drive_n, 0.0) * sailor_config.hang_height_m / (sailor_config.mass_kg * sim_config.gravity_ms2), 0.0, sailor_config.hang_back_max_m)
	# Pitch reflex: when the nose rises fast the sailor moves their weight forward, and back
	# when it drops. This is how a sailor stops a planing board from porpoising.
	if controls.balance_reflex:
		var pitch_rate: float = body.angular_velocity_body().x
		hang_target = clampf(hang_target - sailor_config.pitch_reflex_m_per_rad_s * pitch_rate, -0.3, sailor_config.hang_back_max_m)
	if not controls.freeze_fore_aft:
		hang_back_m = move_toward(hang_back_m, hang_target, sailor_config.lean_rate_per_s * sailor_config.hang_back_max_m * dt)

	# These are slow moves: the board stays put and the weight shifts inside it.
	mass_model.update(stance, lean, hang_back_m, knee_bend_m)
	body.set_mass_properties(mass_model.total_mass_kg, _inertia_with_added_water(), mass_model.com_offset_body)


## The inertia of the body plus the water the hull drags along when it turns (yaw) and
## when it pitches (the wet bottom's added mass, from the last hull computation).
func _inertia_with_added_water() -> Basis:
	var inertia: Basis = mass_model.inertia_body
	inertia.x = Vector3(inertia.x.x + hull.pitch_added_inertia_kgm2, inertia.x.y, inertia.x.z)
	inertia.y = Vector3(inertia.y.x, inertia.y.y + buoyancy.yaw_added_inertia_kgm2(), inertia.y.z)
	return inertia


## The legs as a suspension. The sailor's upper body rides on the legs like a mass on a
## damped spring, moving along the board's up axis; what the board does (waves, planing
## lift, a gust) is the forcing. Written with the centre of mass of the whole windsurfer as
## the reference, the two-mass equations reduce to
##   flex_acceleration = (a_rigid - leg_force / m_sailor) * total / (total - m_sailor)
## where a_rigid is the upward acceleration the sailor's position would get if everything
## were rigid, and leg_force = stiffness * flex + damping * flex_rate is the spring. No
## outside force acts, so the centre of mass of the whole keeps its path: the board shifts
## the other way by m_sailor / total of the flex and moves with the matching velocity.
## This is what lets the board move under the sailor instead of carrying them rigidly.
func _flex_legs(dt: float) -> void:
	var m_sailor: float = sailor_config.mass_kg
	var total: float = body.mass_kg
	var up: Vector3 = body.basis.y
	var sailor_world: Vector3 = body.point_world(mass_model.sailor_position_body)
	var a_rigid: float = body.acceleration_at(sailor_world).dot(up)
	var omega: float = TAU * sailor_config.leg_natural_frequency_hz
	var stiffness: float = m_sailor * omega * omega
	var damping: float = 2.0 * sailor_config.leg_damping_ratio * m_sailor * omega
	var leg_force: float = stiffness * knee_bend_m + damping * knee_bend_rate_ms
	var flex_acceleration: float = (a_rigid - leg_force / m_sailor) * total / maxf(total - m_sailor, 1.0)
	knee_bend_rate_ms += flex_acceleration * dt
	knee_bend_m += knee_bend_rate_ms * dt
	if absf(knee_bend_m) > sailor_config.leg_travel_m:
		# The legs reach a stop: fully bent or fully stretched.
		knee_bend_m = signf(knee_bend_m) * sailor_config.leg_travel_m
		knee_bend_rate_ms = 0.0
	mass_model.update(stance, lean, hang_back_m, knee_bend_m)
	body.set_mass_properties(total, _inertia_with_added_water(), mass_model.com_offset_body, true)
	body.internal_velocity = up * (m_sailor / total * knee_bend_rate_ms)


## Air drag of the sailor's body, applied where the sailor is. Small but real: it is
## what keeps a sail's lift-to-drag ratio near what sailors actually get.
func _apply_windage() -> void:
	var sailor_world: Vector3 = body.point_world(mass_model.sailor_position_body)
	var apparent: Vector3 = wind.velocity_at(sailor_world) - body.point_velocity(sailor_world)
	var speed: float = apparent.length()
	if speed < 0.1:
		return
	var drag: float = 0.5 * RHO_AIR * sailor_config.windage_area_cd_m2 * speed * speed
	body.add_force_at(sailor_world, apparent / speed * drag)


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
	t.vmg_ms = v_h.dot(from_true)
	t.aws_kt = sail.aws_ms / SimMath.KNOT_MS
	t.awa_deg = rad_to_deg(sail.awa_rad)

	t.sail_side = sail.sail_side
	t.sheet = controls.sheet
	t.rake = controls.rake
	t.rig_tilt = controls.rig_tilt
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

	t.buoyancy_n = buoyancy.buoyancy_force_n
	t.submersion_ratio = buoyancy.submersion_ratio
	t.wetted_area_m2 = buoyancy.wetted_area_m2
	t.planing_lift_n = hull.planing_lift_n
	t.planing_ratio = hull.planing_ratio
	t.wetted_length_m = hull.wetted_length_m
	t.wetted_aft_m = hull.wetted_aft_m
	t.spray_root_factor = hull.spray_root_factor
	t.heave_added_mass_kg = hull.heave_added_mass_kg
	t.is_planing = hull.planing_ratio > 0.5
	t.trim_deg = hull.trim_deg
	t.hull_friction_n = hull.friction_n
	t.hull_residuary_n = hull.residuary_n
	t.hull_lateral_n = hull.lateral_n
	t.hull_resistance_n = hull.resistance_n

	t.sailor_state = sailor_state
	t.fall_kind = fall_kind
	t.waterstart_in_s = maxf(sailor_config.waterstart_time_s - fallen_for_s, 0.0) if sailor_state == SailorState.FALLEN else 0.0
	t.stance = stance
	t.lean = lean
	t.hang_back_m = hang_back_m
	t.knee_bend_m = knee_bend_m
	t.sailor_position_body = mass_model.sailor_position_body
	t.com_offset_body = mass_model.com_offset_body
	t.total_mass_kg = mass_model.total_mass_kg
