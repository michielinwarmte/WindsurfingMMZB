class_name WindsurferEffects
extends Node3D
## What the water and the wind do around the windsurfer, for the eye only (CLAUDE.md rule 2:
## nothing here feeds back into the physics). The windsurfer creates this node in
## _build_visuals() and hands it the simulation every physics tick (update()):
## - spray thrown off the rails at the spray root, growing with speed and planing, and a plume
##   behind the tail at speed (water_particles.gd; none beyond FAR_OFF_M from the camera),
## - the wake and foam trail behind the tail, with the bow wave's V at displacement speed
##   (res://world/effects/wake_trail.gd),
## - a splash when the hull lands hard (splash_trigger.gd), as big as the landing, and when the
##   sailor falls in, each leaving a patch of foam on the water,
## - on the player's own board (wind_flag_wanted), spray torn off the crests around it in a
##   wind above CREST_SPRAY_FROM_KT,
## - a streamer at the masthead showing the apparent wind (telltale.gd),
## - a wind flag on a buoy near the start showing the true wind (wind_flag.gd),
## - the debug view of the forces, switched with F3 or --forces=1 (force_arrows.gd).
## This node rides on the board, so the spray emitters sit in the board's axes (+X starboard,
## -Z the bow); everything that belongs to the water stays in the world (top_level).

## Spray starts at this speed and is full at this speed (m/s; 12 m/s is about 23 knots).
const SPRAY_START_MS: float = 1.5
const SPRAY_FULL_MS: float = 12.0
## The board at the limit, seen (GR1): a fin near its peak lift throws this much more spray
## (the sheet off the leeward rail of a loaded board), and a board on its rail this much more
## at RAIL_SPRAY_HEEL_DEG of heel.
const FIN_LOAD_SPRAY: float = 0.6
const RAIL_SPRAY: float = 0.4
const RAIL_SPRAY_HEEL_DEG: float = 10.0
## The chatter of the board and the rig as the fin nears its limit (GR1): nothing until the
## fin's lift passes CHATTER_FROM_LOAD of its peak, up to CHATTER_MAX_DEG of roll (and half of
## it in pitch) at the peak, at CHATTER_HZ; a fin that has let go shakes fully.
const CHATTER_FROM_LOAD: float = 0.8
const CHATTER_MAX_DEG: float = 0.6
const CHATTER_HZ: float = 14.0
## The flag buoy is placed this far to port and this far ahead of the start.
const FLAG_TO_PORT_M: float = 10.0
const FLAG_AHEAD_M: float = 6.0
## The falling sailor on screen hits the water near the end of the fall
## (WindsurferNode.FALL_DURATION_S): the splash comes then.
const FALL_SPLASH_AT_S: float = 0.75
## How many splashes can be in the air at once.
const SPLASH_POOL: int = 3
## The plume behind the tail (the "rooster tail" of a board at speed): none below planing, growing
## from PLUME_START_MS to full at PLUME_FULL_MS (12 to 27 knots of board speed), more with the fin
## loaded (by eye, the photos: the white water behind the tail of a slalom board at full speed).
const PLUME_START_MS: float = 6.0
const PLUME_FULL_MS: float = 14.0
const PLUME_FIN_LOAD: float = 0.5
## A far board's spray is cheap: full up to FAR_FADE_FROM_M from the camera, fading to none at
## FAR_OFF_M (a 2 m spray sheet is about 20 pixels across there at 1280 x 720), splashes up to
## FAR_SPLASH_M. A 20-board race draws spray only round the few boards near the camera.
const FAR_FADE_FROM_M: float = 40.0
const FAR_OFF_M: float = 80.0
const FAR_SPLASH_M: float = 150.0
## The splash of a landing: by how much the water's support jumped (in weights above the
## trigger's SplashTrigger.RISE_WEIGHTS: full at SPLASH_FULL_EXTRA_WEIGHTS more) or by how fast the
## hull came down (full at SPLASH_FULL_SINK_MS: a drop from 0.46 m), whichever is more.
const SPLASH_FULL_EXTRA_WEIGHTS: float = 3.0
const SPLASH_SINK_FROM_MS: float = 0.5
const SPLASH_FULL_SINK_MS: float = 3.0
## The foam a splash leaves on the water: this wide at full strength (m).
const SPLASH_FOAM_M: float = 2.2
## Spray torn off the crests by the wind (the wind agent's leftover, wind_on_water.md): from
## CREST_SPRAY_FROM_KT at 10 m (Beaufort 6, 22 to 27 kt: "probably some spray"; the brief's 25 kt)
## to full at CREST_SPRAY_FULL_KT (Beaufort 8, 34 kt: "edges of crests break into spindrift"), and
## only as much as there are whitecaps (LakeLook's measured law, the water shader's): a breaking
## crest of about WHITECAP_AREA_M2 that breaks for about WHITECAP_LIFE_S (both estimates) throws
## one burst. Over a circle of CREST_SPRAY_RADIUS_M around a point CREST_SPRAY_AHEAD_M ahead of the
## board (in the follow camera's view); at most CREST_POOL bursts at once.
const CREST_SPRAY_FROM_KT: float = 25.0
const CREST_SPRAY_FULL_KT: float = 34.0
const WHITECAP_AREA_M2: float = 1.5
const WHITECAP_LIFE_S: float = 1.0
const CREST_SPRAY_RADIUS_M: float = 14.0
const CREST_SPRAY_AHEAD_M: float = 8.0
const CREST_POOL: int = 8
## The sail's centre of effort is about this high above the water: the wind there (telemetry's
## tws_at_sail_kt, with the gusts) against the mean there tells how gusty it is at the board.
const SAIL_HEIGHT_M: float = 2.0

var _sim: WindsurferSim
var _spray_port: GPUParticles3D
var _spray_starboard: GPUParticles3D
var _plume: GPUParticles3D
var _crest_bursts: Array[GPUParticles3D] = []
var _next_crest: int = 0
var _crest_random: RandomNumberGenerator = RandomNumberGenerator.new()
## How far the camera is (m), every tick; how fast the hull has come down lately (m/s).
var _camera_distance_m: float = 0.0
var _sink_ms: float = 0.0
var _splashes: Array[GPUParticles3D] = []
var _next_splash: int = 0
var _splash_trigger: SplashTrigger = SplashTrigger.new()
var _wake: WakeTrail
var _telltale: Telltale
var _flag: WindFlag
## Whether the flag buoy is made at all (the opponents of a race have none, WindsurferNode).
var wind_flag_wanted: bool = true
var _forces: ForceArrows
var _flag_placed: bool = false
var _fall_splashed: bool = false
var _last_time_s: float = -1.0


## How much spray the rails throw, 0 to 1. Nothing below SPRAY_START_MS; then it grows with
## the square of the speed (the spray sheet carries the energy of the water the hull pushes
## aside) up to SPRAY_FULL_MS. A board that is not yet planing pushes a bow wave rather than
## a sheet, so it throws only a quarter as much. When the spray root runs forward along the
## hull (the nose meeting chop: the hull model's spray_root_factor above 1) there is more.
## A fin near its peak lift (fin_load_share toward 1) and a board on its rail (heel_deg)
## throw more (GR1): the board at the limit is seen in its spray.
static func spray_intensity(speed_ms: float, planing_ratio: float, spray_root_factor: float = 1.0,
		fin_load_share: float = 0.0, heel_deg: float = 0.0) -> float:
	var speed_share: float = clampf((speed_ms - SPRAY_START_MS) / (SPRAY_FULL_MS - SPRAY_START_MS), 0.0, 1.0)
	var sheet: float = speed_share * speed_share * lerpf(0.25, 1.0, clampf(planing_ratio, 0.0, 1.0))
	var chop: float = clampf(spray_root_factor - 1.0, 0.0, 1.0) * speed_share
	var loaded: float = 1.0 + FIN_LOAD_SPRAY * clampf(fin_load_share, 0.0, 1.0)
	var railed: float = 1.0 + RAIL_SPRAY * clampf(absf(heel_deg) / RAIL_SPRAY_HEEL_DEG, 0.0, 1.0)
	return clampf((sheet + 0.5 * chop) * loaded * railed, 0.0, 1.0)


## How much white water the tail throws up and back (the plume), 0 to 1: nothing below
## PLUME_START_MS or off the plane, full at PLUME_FULL_MS, more with the fin loaded.
static func plume_intensity(speed_ms: float, planing_ratio: float, fin_load_share: float = 0.0) -> float:
	var speed_share: float = smoothstep(PLUME_START_MS, PLUME_FULL_MS, speed_ms)
	var planing: float = smoothstep(0.5, 1.0, planing_ratio)
	return clampf(speed_share * planing * (1.0 + PLUME_FIN_LOAD * clampf(fin_load_share, 0.0, 1.0)), 0.0, 1.0)


## How much of a board's spray is drawn at this distance from the camera (1 near, 0 far).
static func distance_share(distance_m: float) -> float:
	return 1.0 - smoothstep(FAR_FADE_FROM_M, FAR_OFF_M, distance_m)


## How big a landing's splash is (0.2 to 1), from the jump in the water's support (weights, as
## SplashTrigger.last_strength) and how fast the hull was coming down (m/s).
static func splash_strength(rise_weights: float, sink_ms: float) -> float:
	var by_load: float = clampf((rise_weights - SplashTrigger.RISE_WEIGHTS) / SPLASH_FULL_EXTRA_WEIGHTS, 0.0, 1.0)
	var by_sink: float = smoothstep(SPLASH_SINK_FROM_MS, SPLASH_FULL_SINK_MS, sink_ms)
	return clampf(0.2 + 0.8 * maxf(by_load, by_sink), 0.2, 1.0)


## How many bursts of spray the wind tears off the crests a second over `area_m2` of water, in a
## wind of `wind_10m_ms` at 10 m: the whitecaps' cover (LakeLook.sea_whitecap_percent, Callaghan et
## al. 2008, times `water_factor` for fresh water) shared into crests, from CREST_SPRAY_FROM_KT.
static func crest_spray_rate(wind_10m_ms: float, area_m2: float, water_factor: float = 1.0) -> float:
	var cover: float = LakeLook.sea_whitecap_percent(wind_10m_ms) / 100.0 * water_factor
	var onset: float = smoothstep(CREST_SPRAY_FROM_KT, CREST_SPRAY_FULL_KT, wind_10m_ms / SimMath.KNOT_MS)
	return cover * area_m2 / WHITECAP_AREA_M2 / WHITECAP_LIFE_S * onset


## How the spray divides between the rails, (port, starboard), adding up to 1. Most comes off
## the leeward rail, which leads into the water as the board slips sideways, and off the low
## rail (the photos: nearly all of it off the leeward rail of a planing board). A wind from starboard (AWA > 0) makes port the leeward side; heel > 0 puts the
## starboard rail down.
static func spray_side_shares(awa_deg: float, heel_deg: float) -> Vector2:
	var leeward_is_port: float = clampf(awa_deg / 20.0, -1.0, 1.0)
	var starboard_down: float = clampf(heel_deg / 10.0, -1.0, 1.0)
	var port: float = clampf(0.5 + 0.38 * leeward_is_port - 0.2 * starboard_down, 0.05, 0.95)
	return Vector2(port, 1.0 - port)


## Where the spray root meets a rail (side -1 port, +1 starboard), in the board's axes: the
## forward end of the wet part of the bottom, wetted_aft_m + wetted_length_m forward of the
## transom (hull_model.gd), at the edge of the bottom there (the board's outline, BoardConfig.width_at).
static func spray_root_local(board: BoardConfig, wetted_aft_m: float, wetted_length_m: float, side: float) -> Vector3:
	var from_transom: float = clampf(wetted_aft_m + wetted_length_m, 0.3, board.length_m * 0.85)
	var half_width: float = 0.5 * board.width_at(from_transom)
	return Vector3(side * half_width, -0.5 * board.thickness_m, 0.5 * board.length_m - from_transom)


## The chatter of the board and the rig as the fin nears its limit (GR1): a small, fast
## shiver, for the eye only, as Vector2(pitch, roll) in degrees. Nothing until the fin's lift
## passes CHATTER_FROM_LOAD of its peak, then growing with the square up to CHATTER_MAX_DEG at
## the peak; a fin that has let go (fin_stalled) shakes fully whatever its load.
static func chatter_deg(fin_load_share: float, fin_stalled: bool, time_s: float) -> Vector2:
	var edge: float = clampf((fin_load_share - CHATTER_FROM_LOAD) / (1.0 - CHATTER_FROM_LOAD), 0.0, 1.0)
	if fin_stalled:
		edge = 1.0
	if edge <= 0.0:
		return Vector2.ZERO
	var amount: float = CHATTER_MAX_DEG * edge * edge
	var phase: float = TAU * CHATTER_HZ * time_s
	return Vector2(0.5 * amount * sin(phase * 1.37), amount * sin(phase))


## Builds the effects for this simulation. Called once, by the windsurfer.
func setup(sim: WindsurferSim) -> void:
	_sim = sim
	name = "Effects"
	_spray_port = WaterParticles.make_spray(-1.0)
	_spray_starboard = WaterParticles.make_spray(1.0)
	add_child(_spray_port)
	add_child(_spray_starboard)
	_plume = WaterParticles.make_plume()
	add_child(_plume)
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
	if wind_flag_wanted:
		# The spray off the crests is the water around the camera: only the player's own board.
		for i: int in CREST_POOL:
			var burst: GPUParticles3D = WaterParticles.make_crest_spray()
			world.add_child(burst)
			_crest_bursts.append(burst)
	_telltale = Telltale.new()
	add_child(_telltale)
	if wind_flag_wanted:
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
	_camera_distance_m = _distance_to_camera(t.position)
	_update_spray(t, sailing)
	var wake_strength: float = WakeTrail.wake_strength(t.speed_ms, t.planing_ratio) if sailing else 0.0
	var bow_strength: float = WakeTrail.bow_wave_strength(t.speed_ms, t.planing_ratio) if sailing else 0.0
	_wake.add_tail(_tail_world(), wake_strength, WakeTrail.carve_of(t.heel_deg, t.yaw_rate_dps, t.speed_ms), t.speed_ms, bow_strength)
	_check_landing(t, sailing, dt)
	_check_fall(sailing)
	_update_crest_spray(t, dt)
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


## How much each spray emitter throws now (x the port rail, y the starboard rail, z the tail's
## plume; 0 when it is off), for tests.
func spray_amounts() -> Vector3:
	return Vector3(_spray_port.amount_ratio if _spray_port.emitting else 0.0,
		_spray_starboard.amount_ratio if _spray_starboard.emitting else 0.0,
		_plume.amount_ratio if _plume.emitting else 0.0)


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
	var forward: Vector3 = -board.basis.z
	_wake.follow_tail(board * _tail_local(), Vector2(forward.x, forward.z), _sim.board_config.length_m, time_s)


func _update_spray(t: Telemetry, sailing: bool) -> void:
	var near: float = distance_share(_camera_distance_m)
	var intensity: float = spray_intensity(t.speed_ms, t.planing_ratio, t.spray_root_factor, t.fin_load_share, t.heel_deg) if sailing else 0.0
	var shares: Vector2 = spray_side_shares(t.awa_deg, t.heel_deg)
	_set_spray(_spray_port, intensity * shares.x * near, -1.0, t)
	_set_spray(_spray_starboard, intensity * shares.y * near, 1.0, t)
	var plume: float = plume_intensity(t.speed_ms, t.planing_ratio, t.fin_load_share) * near if sailing else 0.0
	_plume.amount_ratio = plume
	_plume.emitting = plume > 0.02
	if _plume.emitting:
		_plume.position = _tail_local() + Vector3(0.0, 0.0, 0.05)
		WaterParticles.set_plume_speed(_plume, t.speed_ms)


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
	# How fast the hull has come down lately: the fastest sinking of the last moments, fading.
	_sink_ms = maxf(-_sim.body.velocity.y, maxf(_sink_ms - 6.0 * dt, 0.0))
	if _splash_trigger.update(t.buoyancy_n + t.planing_lift_n, weight_n, dt):
		# A small low splash for a slap on chop, a tall one for a hard landing.
		var strength: float = splash_strength(_splash_trigger.last_strength, _sink_ms)
		# Where the hull meets the water: the front of its wet part.
		var front_of_wet: Vector3 = spray_root_local(_sim.board_config, t.wetted_aft_m, t.wetted_length_m, 0.0)
		var at: Vector3 = _on_water(_sim.body.point_world(front_of_wet))
		_splash(at, strength)
		if strength > 0.4:
			_wake.add_foam_patch(at, SPLASH_FOAM_M * strength, strength)
		_sink_ms = 0.0


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
	var sailor_at: Vector3 = _on_water(_sim.body.point_world(landing_local))
	_splash(sailor_at, 1.0)
	_wake.add_foam_patch(sailor_at, SPLASH_FOAM_M * 1.3, 1.0)
	var rig_local: Vector3 = _sim.sail_config.mast_foot_local + Vector3(side * 2.0, 0.0, 0.0)
	var rig_at: Vector3 = _on_water(_sim.body.point_world(rig_local))
	_splash(rig_at, 0.6)
	_wake.add_foam_patch(rig_at, SPLASH_FOAM_M, 0.6)


func _splash(at: Vector3, strength: float) -> void:
	if _camera_distance_m > FAR_SPLASH_M:
		return
	WaterParticles.splash(_splashes[_next_splash], at, strength)
	_next_splash = (_next_splash + 1) % _splashes.size()


## How far the camera that draws the picture is from a point (0 without one: headless and tests
## draw everything).
func _distance_to_camera(point: Vector3) -> float:
	if not is_inside_tree():
		return 0.0
	var camera: Camera3D = get_viewport().get_camera_3d()
	return camera.global_position.distance_to(point) if camera != null else 0.0


## Spray torn off the crests near the board in a strong wind (crest_spray_rate()), the player's own
## board only. The wind at the board with its gusts: the sail's wind against the mean at its height
## gives the gust, put on the wind at 10 m.
func _update_crest_spray(t: Telemetry, dt: float) -> void:
	if _crest_bursts.is_empty() or dt <= 0.0:
		return
	var mean_at_sail_kt: float = _sim.wind.speed_at_height(SAIL_HEIGHT_M) / SimMath.KNOT_MS
	var gust: float = t.tws_at_sail_kt / mean_at_sail_kt if mean_at_sail_kt > 0.1 else 1.0
	var wind_10m_ms: float = t.tws_10m_kt * clampf(gust, 0.5, 2.0) * SimMath.KNOT_MS
	var water_factor: float = LakeLook.FRESH_WATER_FACTOR if _sim.water is LakeWaveField else 1.0
	var rate: float = crest_spray_rate(wind_10m_ms, PI * CREST_SPRAY_RADIUS_M * CREST_SPRAY_RADIUS_M, water_factor)
	if _crest_random.randf() >= rate * dt:
		return
	var heading: float = deg_to_rad(t.heading_deg)
	var ahead: Vector3 = t.position + Vector3(sin(heading), 0.0, -cos(heading)) * CREST_SPRAY_AHEAD_M
	# Of a few places tried, the highest: most likely on a crest.
	var best: Vector3 = Vector3.ZERO
	var best_height_m: float = -INF
	for i: int in 4:
		var angle: float = _crest_random.randf() * TAU
		var radius_m: float = sqrt(_crest_random.randf()) * CREST_SPRAY_RADIUS_M
		var x: float = ahead.x + cos(angle) * radius_m
		var z: float = ahead.z + sin(angle) * radius_m
		var height_m: float = _sim.water.height_at(x, z, _sim.time_s)
		if height_m > best_height_m:
			best_height_m = height_m
			best = Vector3(x, height_m, z)
	var downwind_xz: Vector2 = WaveField.direction_for_bearing(t.wind_from_bearing_deg + 180.0)
	WaterParticles.crest_spray(_crest_bursts[_next_crest], best, downwind_xz, wind_10m_ms)
	_next_crest = (_next_crest + 1) % _crest_bursts.size()


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
	if _flag == null:
		return
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
