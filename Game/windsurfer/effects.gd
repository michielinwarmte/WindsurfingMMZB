class_name WindsurferEffects
extends Node3D
## What the water and the wind do around the windsurfer, for the eye only (CLAUDE.md rule 2:
## nothing here feeds back into the physics). The windsurfer creates this node in
## _build_visuals() and hands it the simulation every physics tick (update()):
## - spray thrown off the rails at the spray root, growing with speed and planing,
## - the wake and foam trail behind the tail (res://world/effects/wake_trail.gd),
## - a splash when the hull lands hard (splash_trigger.gd) and when the sailor falls in,
## - a streamer at the masthead showing the apparent wind (telltale.gd),
## - a wind flag on a buoy near the start showing the true wind (wind_flag.gd),
## - the debug view of the forces, switched with F3 or --forces=1 (force_arrows.gd).
## This node rides on the board, so the spray emitters sit in the board's axes (+X starboard,
## -Z the bow); everything that belongs to the water stays in the world (top_level).

## Spray starts at this speed and is full at this speed (m/s; 12 m/s is about 23 knots).
const SPRAY_START_MS: float = 1.5
const SPRAY_FULL_MS: float = 12.0
## The flag buoy is placed this far to port and this far ahead of the start.
const FLAG_TO_PORT_M: float = 10.0
const FLAG_AHEAD_M: float = 6.0
## The falling sailor on screen hits the water near the end of the fall
## (WindsurferNode.FALL_DURATION_S): the splash comes then.
const FALL_SPLASH_AT_S: float = 0.75
## How many splashes can be in the air at once.
const SPLASH_POOL: int = 3

var _sim: WindsurferSim
var _spray_port: GPUParticles3D
var _spray_starboard: GPUParticles3D
var _splashes: Array[GPUParticles3D] = []
var _next_splash: int = 0
var _splash_trigger: SplashTrigger = SplashTrigger.new()
var _wake: WakeTrail
var _telltale: Telltale
var _flag: WindFlag
var _forces: ForceArrows
var _flag_placed: bool = false
var _fall_splashed: bool = false
var _last_time_s: float = -1.0


## How much spray the rails throw, 0 to 1. Nothing below SPRAY_START_MS; then it grows with
## the square of the speed (the spray sheet carries the energy of the water the hull pushes
## aside) up to SPRAY_FULL_MS. A board that is not yet planing pushes a bow wave rather than
## a sheet, so it throws only a quarter as much. When the spray root runs forward along the
## hull (the nose meeting chop: the hull model's spray_root_factor above 1) there is more.
static func spray_intensity(speed_ms: float, planing_ratio: float, spray_root_factor: float = 1.0) -> float:
	var speed_share: float = clampf((speed_ms - SPRAY_START_MS) / (SPRAY_FULL_MS - SPRAY_START_MS), 0.0, 1.0)
	var sheet: float = speed_share * speed_share * lerpf(0.25, 1.0, clampf(planing_ratio, 0.0, 1.0))
	var chop: float = clampf(spray_root_factor - 1.0, 0.0, 1.0) * speed_share
	return clampf(sheet + 0.5 * chop, 0.0, 1.0)


## How the spray divides between the rails, (port, starboard), adding up to 1. Most comes off
## the leeward rail, which leads into the water as the board slips sideways, and off the low
## rail. A wind from starboard (AWA > 0) makes port the leeward side; heel > 0 puts the
## starboard rail down.
static func spray_side_shares(awa_deg: float, heel_deg: float) -> Vector2:
	var leeward_is_port: float = clampf(awa_deg / 20.0, -1.0, 1.0)
	var starboard_down: float = clampf(heel_deg / 10.0, -1.0, 1.0)
	var port: float = clampf(0.5 + 0.3 * leeward_is_port - 0.2 * starboard_down, 0.1, 0.9)
	return Vector2(port, 1.0 - port)


## Where the spray root meets a rail (side -1 port, +1 starboard), in the board's axes: the
## forward end of the wet part of the bottom, wetted_aft_m + wetted_length_m forward of the
## transom (hull_model.gd), at the edge of the bottom there (the board's outline, BoardConfig.width_at).
static func spray_root_local(board: BoardConfig, wetted_aft_m: float, wetted_length_m: float, side: float) -> Vector3:
	var from_transom: float = clampf(wetted_aft_m + wetted_length_m, 0.3, board.length_m * 0.85)
	var half_width: float = 0.5 * board.width_at(from_transom)
	return Vector3(side * half_width, -0.5 * board.thickness_m, 0.5 * board.length_m - from_transom)


## Builds the effects for this simulation. Called once, by the windsurfer.
func setup(sim: WindsurferSim) -> void:
	_sim = sim
	name = "Effects"
	_spray_port = WaterParticles.make_spray(-1.0)
	_spray_starboard = WaterParticles.make_spray(1.0)
	add_child(_spray_port)
	add_child(_spray_starboard)
	var world: Node3D = Node3D.new()
	world.name = "InTheWorld"
	world.top_level = true
	add_child(world)
	for i: int in SPLASH_POOL:
		var splash: GPUParticles3D = WaterParticles.make_splash()
		world.add_child(splash)
		_splashes.append(splash)
	_wake = WakeTrail.new()
	world.add_child(_wake)
	_wake.setup(sim)
	_telltale = Telltale.new()
	add_child(_telltale)
	_flag = WindFlag.new()
	world.add_child(_flag)
	_forces = ForceArrows.new()
	world.add_child(_forces)
	_forces.visible = "--forces=1" in OS.get_cmdline_user_args()


## One physics tick, after the simulation stepped.
func update(sim: WindsurferSim) -> void:
	_sim = sim
	var t: Telemetry = sim.telemetry
	if sim.time_s < _last_time_s:
		# A reset: the board is back at the start.
		_wake.clear()
		_splash_trigger.clear()
	var dt: float = sim.time_s - _last_time_s if _last_time_s >= 0.0 else 0.0
	_last_time_s = sim.time_s
	var sailing: bool = sim.sailor_state == WindsurferSim.SailorState.SAILING
	_update_spray(t, sailing)
	_wake.add_tail(_tail_world(), WakeTrail.wake_strength(t.speed_ms, t.planing_ratio) if sailing else 0.0)
	_check_landing(t, sailing, dt)
	_check_fall(sailing)
	_update_telltale(t, sailing)
	_update_flag(t)
	if _forces.visible:
		_update_forces()


## Is the force view on? (F3)
func forces_visible() -> bool:
	return _forces.visible


func set_forces_visible(on: bool) -> void:
	_forces.visible = on
	if on and _sim != null:
		_update_forces()


func force_arrows() -> ForceArrows:
	return _forces


func wake() -> WakeTrail:
	return _wake


func telltale() -> Telltale:
	return _telltale


func wind_flag() -> WindFlag:
	return _flag


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug_forces"):
		set_forces_visible(not _forces.visible)
		get_viewport().set_input_as_handled()


## Every frame: the wake's newest end follows the tail as it is drawn, and its waves keep
## time with the water's.
func _process(_delta: float) -> void:
	if _sim == null:
		return
	var tick_s: float = 1.0 / float(Engine.physics_ticks_per_second)
	var time_s: float = _sim.time_s + Engine.get_physics_interpolation_fraction() * tick_s
	var board: Transform3D = get_global_transform_interpolated()
	_wake.follow_tail(board * _tail_local(), time_s)


func _update_spray(t: Telemetry, sailing: bool) -> void:
	var intensity: float = spray_intensity(t.speed_ms, t.planing_ratio, t.spray_root_factor) if sailing else 0.0
	var shares: Vector2 = spray_side_shares(t.awa_deg, t.heel_deg)
	_set_spray(_spray_port, intensity * shares.x, -1.0, t)
	_set_spray(_spray_starboard, intensity * shares.y, 1.0, t)


func _set_spray(particles: GPUParticles3D, amount: float, side: float, t: Telemetry) -> void:
	# Each rail's share is at most 0.9 of the whole: at full spray the leeward rail is full.
	particles.amount_ratio = clampf(amount * 1.6, 0.0, 1.0)
	particles.emitting = particles.amount_ratio > 0.02
	if particles.emitting:
		particles.position = spray_root_local(_sim.board_config, t.wetted_aft_m, t.wetted_length_m, side)
		WaterParticles.set_spray_speed(particles, t.speed_ms)


## The middle of the transom, in the board's axes and in the world.
func _tail_local() -> Vector3:
	var board: BoardConfig = _sim.board_config
	return Vector3(0.0, -0.5 * board.thickness_m, 0.5 * board.length_m)


func _tail_world() -> Vector3:
	return _sim.body.point_world(_tail_local())


## A hard landing: the water's support of the hull jumps (splash_trigger.gd).
func _check_landing(t: Telemetry, sailing: bool, dt: float) -> void:
	if not sailing or dt <= 0.0:
		_splash_trigger.clear()
		return
	var weight_n: float = maxf(t.total_mass_kg, 1.0) * _sim.sim_config.gravity_ms2
	if _splash_trigger.update(t.buoyancy_n + t.planing_lift_n, weight_n, dt):
		# A small splash for a slap on chop, a full one for a landing 3 weights harder.
		var strength: float = clampf(0.25 + 0.25 * (_splash_trigger.last_strength - SplashTrigger.RISE_WEIGHTS), 0.25, 1.0)
		# Where the hull meets the water: the front of its wet part.
		var front_of_wet: Vector3 = spray_root_local(_sim.board_config, t.wetted_aft_m, t.wetted_length_m, 0.0)
		_splash(_on_water(_sim.body.point_world(front_of_wet)), strength)


## The fall: a big splash where the sailor lands and a smaller one where the rig hits the
## water, as the figure and the rig fall on screen (sailor_figure.gd and rig_visuals.gd lay
## them toward the fall side: beyond the mast top in a catapult, beside the board otherwise).
func _check_fall(sailing: bool) -> void:
	if sailing:
		_fall_splashed = false
		return
	if _fall_splashed or _sim.fallen_for_s < FALL_SPLASH_AT_S:
		return
	_fall_splashed = true
	var side: float = float(_sim.fall_side)
	var over: bool = _sim.fall_kind == "catapult" or _sim.fall_kind == "tipped over"
	var reach_m: float = _sim.sail_config.mast_m + 1.0 if over else 1.8
	var landing_local: Vector3 = _sim.feet_body + Vector3(side * reach_m, 0.0, 0.0)
	_splash(_on_water(_sim.body.point_world(landing_local)), 1.0)
	var rig_local: Vector3 = _sim.sail_config.mast_foot_local + Vector3(side * 2.0, 0.0, 0.0)
	_splash(_on_water(_sim.body.point_world(rig_local)), 0.6)


func _splash(at: Vector3, strength: float) -> void:
	WaterParticles.splash(_splashes[_next_splash], at, strength)
	_next_splash = (_next_splash + 1) % _splashes.size()


## The point on the water surface above or below a world point.
func _on_water(point: Vector3) -> Vector3:
	return Vector3(point.x, _sim.water.height_at(point.x, point.z, _sim.time_s), point.z)


func _update_telltale(t: Telemetry, sailing: bool) -> void:
	_telltale.visible = sailing
	if not sailing:
		return
	var mast_world: Vector3 = _sim.rig.basis * _sim.sail.mast_direction()
	var masthead: Vector3 = _sim.rig.foot_world + mast_world * _sim.sail_config.mast_m
	_telltale.place(masthead, t.awa_deg, t.heading_deg, t.aws_kt)


## The flag stands near the start (placed at the first tick, which is the start) and shows
## the true wind there.
func _update_flag(t: Telemetry) -> void:
	if not _flag_placed:
		var heading: float = deg_to_rad(t.heading_deg)
		var forward: Vector3 = Vector3(sin(heading), 0.0, -cos(heading))
		var port: Vector3 = -Vector3(cos(heading), 0.0, sin(heading))
		_flag.global_position = t.position + port * FLAG_TO_PORT_M + forward * FLAG_AHEAD_M
		_flag_placed = true
	var downwind_xz: Vector2 = WaveField.direction_for_bearing(t.wind_from_bearing_deg + 180.0)
	var wind_ms: float = _sim.wind.speed_at_height(WindFlag.POLE_HEIGHT_M)
	_flag.place(_on_water(_flag.global_position), Vector3(downwind_xz.x, 0.0, downwind_xz.y), wind_ms)


## The arrows of the debug view, from the simulation's models (read only).
func _update_forces() -> void:
	var sim: WindsurferSim = _sim
	var g: float = sim.sim_config.gravity_ms2
	_forces.set_force("sail", sim.sail.ce_world, sim.sail.force_world)
	_forces.set_force("fin", sim.fin.cop_world, sim.fin.force_world)
	# The fin force tilts up by only 8 to 12 degrees, too little to see on its own arrow:
	# its upward part gets an arrow of its own (U2).
	_forces.set_force("fin up", sim.fin.cop_world, Vector3.UP * maxf(sim.fin.force_world.y, 0.0))
	# Buoyancy pushes along the water's normal, at the centre of the immersed volume.
	var centre: Vector3 = sim.buoyancy.centre_of_buoyancy_world
	var normal: Vector3 = sim.water.normal_at(centre.x, centre.z, sim.time_s)
	_forces.set_force("buoyancy", centre, normal * sim.buoyancy.buoyancy_force_n)
	# The planing lift is the upward part of the planing force, at its centre of pressure.
	var pressure_centre: Vector3 = sim.body.point_world(sim.hull.cop_local)
	_forces.set_force("planing", pressure_centre, Vector3.UP * sim.hull.planing_lift_n)
	# The hull's drag acts against the flow past the wet bottom.
	var wet: Vector3 = sim.buoyancy.wet_centroid_world
	var flow: Vector3 = SimMath.horizontal(sim.body.point_velocity(wet) - sim.water.velocity_at(wet.x, wet.z, sim.time_s))
	var against_flow: Vector3 = -flow.normalized() if flow.length() > 0.01 else Vector3.ZERO
	_forces.set_force("drag", wet, against_flow * sim.hull.resistance_n)
	_forces.set_force("weight", sim.sailor.position, Vector3.DOWN * sim.sailor.mass_kg * g)
