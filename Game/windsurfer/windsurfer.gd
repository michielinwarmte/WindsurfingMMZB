class_name WindsurferNode
extends Node3D
## The windsurfer in the scene. Owns a WindsurferSim, steps it once per physics tick with
## the player's (or the autopilot's) controls, and copies the result onto what you see:
## the board and the rig (RigVisuals, rig_visuals.gd) and the sailor (SailorFigure,
## sailor_figure.gd). This node carries the board's transform; the two parts draw in the
## board's own axes. Nothing visual feeds back into the physics (CLAUDE.md, rule 2).

## Compass heading at the start, degrees. 180 (South) with the default wind from the West
## puts the board on a beam reach on starboard tack.
@export var start_heading_deg: float = 180.0
## Where the board starts (only X and Z count; it floats at the water level). The open water
## starts at the origin; a map scene sets its start spot (sail_silvaplana.gd).
@export var start_position: Vector3 = Vector3.ZERO
## Let the test autopilot sail instead of the keys (for screenshots and demos).
@export var use_autopilot: bool = false
@export var autopilot_twa_deg: float = 90.0

## The place to sail in: its air, water, wind and waves (null = the open water's default
## config files). A map scene sets it before this node is ready (sail_silvaplana.gd).
var environment: EnvironmentConfig = null
## The wind and the sea to sail in, on top of the environment's. null = keep the
## environment's. The sailing scene (main.gd) sets them from the player's settings before
## this node is ready.
var wind_config: WindConfig = null
var wave_set_config: WaveSetConfig = null
## The board, sail and fin this board sails and shows (the gear page's choice, GearChoice). null =
## the default gear of Game/config/ (the AI fleet's boards). The sailing scene (main.gd) sets it
## from the player's settings before this node is ready.
var gear: GearChoice = null
## How much stiffer this board's fin is than the measured one (SettingsValues.fin_stiffness,
## FinConfig.stiffness_factor; PH43). 1 = the fin's own numbers.
var fin_stiffness: float = 1.0

var sim: WindsurferSim
var controls: SimControls = SimControls.new()
var controller: PlayerController = PlayerController.new()
var autopilot: Autopilot = Autopilot.new()
## The push slider on this board's own autopilot (use_autopilot; main.gd's --push with
## --autopilot=1): NaN = the autopilot's own numbers. The player's controller keeps its own level
## (controller.push_level).
var autopilot_push_level: float = NAN
var _push_curve: PushCurveConfig = null
## An AI skipper on this board (RACING_PLAN.md, 9B): every tick it sets `hands`, which the
## controller then reads in place of the keyboard. Null on the player's board.
var skipper: RaceSkipper = null
var hands: AiHands = null
## Whether this board's effects put the wind-flag buoy near its start (the player's does; the
## opponents of a race would each add one, so theirs do not). Set before the node is added.
var wind_flag_wanted: bool = true
## Whether this board gets spray, wake, splashes and the rest of the effects (an opponent in a race
## may do without them, for the frame time). Set before the node is added.
var effects_wanted: bool = true
## In a race the runner steps this board (RaceRunner, on a worker thread with the others): the
## node's own _physics_process does nothing then. Set before the node is added.
var stepped_by_runner: bool = false
## Whether the simulation gets its own copies of the config resources (a board stepped on a
## thread beside others must share nothing with them). Set before the node is added. The
## player's board has it on in its scenes (main.tscn, sail_silvaplana.tscn), so the push dial
## (main.gd, --dial=) can set the sailor's numbers without writing the shared .tres files.
@export var own_config_copies: bool = false
## A board sailed on another PC (LAN multiplayer, Documentation/reports/multiplayer/PLAN.md, D4): a
## puppet. Its simulation is never stepped here and no one sails it here; show_state() writes the
## other PC's state into it, and the visuals pose it as usual. Set before the node is added.
var is_puppet: bool = false
## A puppet's state is this old (seconds): the race moves its place on by its speed for that long
## (RaceRunner._where(), D8). 0 for a board sailed here.
var state_age_s: float = 0.0
## The sailor's own time to correct the rail (SailorConfig.lean_feel_time_s) before package B's
## level 2 slowed it; -1 until use_body_level() first runs.
var _own_lean_feel_time_s: float = -1.0
var _name_label: Label3D = null
## The sail's colour from set_sail_colour() (TRANSPARENT: the sail's own), kept for change_gear().
var _sail_colour: Color = Color.TRANSPARENT
## Far from the camera in a race (set_far_away).
var _far_away: bool = false
## What a tick costs, microseconds summed since the last cost_text(): the skipper and the
## controller, the physics step, and the visuals (for --measure, main.gd).
var _us_sailor: int = 0
var _us_sim: int = 0
var _us_visuals: int = 0
var _ticks_counted: int = 0

## The fall takes this long on screen (the physics has already let go).
const FALL_DURATION_S: float = 0.9
## The sailor reaches the windward side of the board, ready to waterstart, this long before the
## physics waterstarts (SailorConfig.waterstart_time_s).
const SWIM_READY_BEFORE_S: float = 0.3

var _previous_state: WindsurferSim.SailorState = WindsurferSim.SailorState.SAILING

var _rig: RigVisuals
var _figure: SailorFigure
var _effects: WindsurferEffects
## The rig as it is drawn: the physics' mast and boom, smoothed, and swung across round the mast
## when the sail changes sides (DrawnRig). The sailor's hands hold this rig.
var _drawn_rig: DrawnRig = DrawnRig.new()
var _drawn_time_s: float = -1.0
## When the last waterstart was (simulation time; -1: none to show): the sailor and the rig get up
## from the water over SailorFigure.RISE_S after it.
var _rise_start_s: float = -1.0


func _ready() -> void:
	sim = WindsurferSim.create_for(environment if environment != null else EnvironmentConfig.new(), true, own_config_copies)
	if gear != null:
		# The same place, wind and sea on the chosen board, sail and fin (copies of their numbers).
		sim = gear.sim_with(sim)
	if not is_equal_approx(fin_stiffness, 1.0):
		# The player's fin stiffer or softer than the measured one (Settings > Sailing, PH43).
		sim.set_fin_stiffness(fin_stiffness)
	if wind_config != null or wave_set_config != null:
		set_sea(wind_config, wave_set_config)
	controller.set_sail(sim.sail, sim.sailor_config, sim.air_density_kg_m3)
	autopilot.sail = sim.sail
	autopilot.air_density_kg_m3 = sim.air_density_kg_m3
	_build_visuals()
	reset()


## Package B's level (the body on the mouse, MouseBody.feel_time_s()): the sailor's feet correct the
## rail at their own pace (level 1, or no body) or slowed (level 2), written into this board's own
## copy of the sailor's config (SailorConfig.lean_feel_time_s; the simulation copies it every tick).
## A board that shares its configs with others (own_config_copies off) is never changed.
func use_body_level(body: MouseBody) -> void:
	if not own_config_copies or sim == null:
		return
	if _own_lean_feel_time_s < 0.0:
		_own_lean_feel_time_s = sim.sailor_config.lean_feel_time_s
	sim.sailor_config.lean_feel_time_s = body.feel_time_s(_own_lean_feel_time_s) if body != null else _own_lean_feel_time_s


## The balance stance (the physics realism audit, 7 November 2026, finding B) on the player's own copy of
## the sailor's config: the sailor steps back for a nose driven down by the rig while getting going.
func use_balance_stance(on: bool) -> void:
	if not own_config_copies or sim == null:
		return
	sim.sailor_config.stance_dive_full_deg = SailorConfig.BALANCE_STANCE_FULL_DEG if on else 0.0


## Puts the board back at the start, at rest.
func reset() -> void:
	controls = SimControls.new()
	controller.reset_controls(controls)
	sim.reset(start_position, deg_to_rad(start_heading_deg))
	_previous_state = sim.sailor_state
	autopilot.target_twa_deg = autopilot_twa_deg
	_drawn_rig.snap()
	_rise_start_s = -1.0
	_copy_state_to_visuals()
	reset_physics_interpolation()


## Puts the simulation in another wind and on another sea (null keeps the current one).
## The waves are lined up with the new wind. Call reset() afterwards: the water changes
## under the board.
func set_sea(wind: WindConfig, waves: WaveSetConfig) -> void:
	if own_config_copies:
		wind = wind.duplicate(true) if wind != null else null
		waves = waves.duplicate(true) if waves != null else null
	if wind != null:
		wind_config = wind
		sim.wind_config = wind
		sim.wind = WindField.new(wind)
	if waves != null:
		wave_set_config = waves
		sim.wave_set_config = waves
	sim.set_waves(true)


## Other gear for this board where it is (LAN multiplayer's gear between starts, and the AI's gear
## for the wind at each new countdown: Documentation/reports/multiplayer/RACE_DIRECTOR.md, R3): a
## new simulation on the new board, sail and fin in the same place, wind and sea
## (GearChoice.sim_with()), at rest where the board is, heading the same way, on the same water
## clock; the rig is built again. null sails the default gear. A skipper on this board must be set
## up again on the new simulation (RaceRunner does it at the new start).
func change_gear(new_gear: GearChoice) -> void:
	var place: Vector3 = Vector3(sim.telemetry.position.x, 0.0, sim.telemetry.position.z)
	var heading_rad: float = deg_to_rad(sim.telemetry.heading_deg)
	var water_time_s: float = sim.time_s
	gear = new_gear
	sim = (new_gear if new_gear != null else GearChoice.defaults()).sim_with(sim)
	if not is_equal_approx(fin_stiffness, 1.0):
		sim.set_fin_stiffness(fin_stiffness)
	controller.set_sail(sim.sail, sim.sailor_config, sim.air_density_kg_m3)
	autopilot.sail = sim.sail
	autopilot.air_density_kg_m3 = sim.air_density_kg_m3
	controls = SimControls.new()
	controller.reset_controls(controls)
	sim.reset(place, heading_rad)
	sim.time_s = water_time_s
	_previous_state = sim.sailor_state
	# The rig and the effects hold the old simulation's gear: built again (the sailor stays).
	remove_child(_rig)
	_rig.queue_free()
	if _effects != null:
		remove_child(_effects)
		_effects.queue_free()
		_effects = null
	_figure.queue_free()
	remove_child(_figure)
	_build_visuals()
	if _sail_colour != Color.TRANSPARENT:
		_rig.tint_sail(_sail_colour)
	_rig.set_process(not _far_away)
	# The drawn rig (DrawnRig) starts where the new rig is, as at a reset, not swinging in from the old.
	_drawn_rig.snap()
	_drawn_time_s = -1.0
	_rise_start_s = -1.0
	_copy_state_to_visuals()
	reset_physics_interpolation()


## Skips the rest of the time in the water.
func waterstart_now() -> void:
	if sim.sailor_state == WindsurferSim.SailorState.FALLEN:
		sim.waterstart()
		_after_waterstart()


func is_fallen() -> bool:
	return sim.sailor_state == WindsurferSim.SailorState.FALLEN


func _physics_process(delta: float) -> void:
	if stepped_by_runner:
		return
	sail(delta)
	step_physics(delta)
	after_step()


## The sailor's part of a tick: the skipper (who keeps watching from the water too: its clock
## runs, its hands come off) and the controller or the autopilot set the controls.
func sail(delta: float) -> void:
	if is_puppet:
		return
	var t0: int = Time.get_ticks_usec()
	if skipper != null:
		skipper.update(sim.telemetry, delta)
	if sim.sailor_state == WindsurferSim.SailorState.SAILING:
		if use_autopilot:
			if not is_nan(autopilot_push_level):
				if _push_curve == null:
					_push_curve = PushDial.default_curve()
				PushDial.apply_level(autopilot_push_level, _push_curve, autopilot, controls)
			autopilot.update(sim.telemetry, controls, delta)
		else:
			controller.update(sim.telemetry, controls, delta)
	_us_sailor += Time.get_ticks_usec() - t0


## The physics of a tick. It touches only this board's simulation, so a race may run several
## boards' steps side by side on worker threads (with own_config_copies).
func step_physics(delta: float) -> void:
	if is_puppet:
		return
	var t1: int = Time.get_ticks_usec()
	sim.step(delta, controls)
	_us_sim += Time.get_ticks_usec() - t1


## After the physics, on the main thread: the water start noticed, the visuals posed. With `pose`
## false only the board's place on the water is set and the sailor, the rig and the sail keep
## their pose of the last tick (a race's far opponents, posed on alternate ticks: RaceRunner).
func after_step(pose: bool = true) -> void:
	if sim.sailor_state == WindsurferSim.SailorState.SAILING and _previous_state == WindsurferSim.SailorState.FALLEN:
		_after_waterstart()
	_previous_state = sim.sailor_state
	var t3: int = Time.get_ticks_usec()
	if pose:
		_copy_state_to_visuals()
	else:
		_copy_place_to_visuals()
	_us_visuals += Time.get_ticks_usec() - t3
	_ticks_counted += 1


## A puppet (is_puppet): the other PC's state of this board written into its simulation, `age_s`
## old. The visuals follow at after_step() (the board's own tick, or the race's).
func show_state(state: BoardSnapshot, age_s: float) -> void:
	state.apply(sim)
	state_age_s = age_s


## A race's opponent far from the camera (RaceRunner.FAR_DETAIL_M): its fin's bend is not
## updated every frame (the fin is under water, and a few pixels long that far away).
func set_far_away(far: bool) -> void:
	_keep_label_range()
	if far == _far_away:
		return
	_far_away = far
	_rig.set_process(not far)


func is_far_away() -> bool:
	return _far_away


func _after_waterstart() -> void:
	controller.reset_controls(controls)
	_previous_state = sim.sailor_state
	_rise_start_s = sim.time_s
	_copy_state_to_visuals()
	reset_physics_interpolation()


func telemetry() -> Telemetry:
	return sim.telemetry


## The board's transform, smoothed between physics ticks, for cameras.
func interpolated_transform() -> Transform3D:
	return get_global_transform_interpolated()


## The board's place and orientation on the water, and its effects (every tick).
func _copy_place_to_visuals() -> void:
	var body: SimRigidBody = sim.body
	global_transform = Transform3D(body.basis, body.origin_world())
	if _effects != null:
		_effects.update(sim)


func _copy_state_to_visuals() -> void:
	_copy_place_to_visuals()
	var body: SimRigidBody = sim.body
	if sim.sailor_state == WindsurferSim.SailorState.FALLEN:
		# A fall picks up speed: the progress is squared. Then the sailor swims to the windward
		# side of the board and pulls the rig round there, ready to waterstart.
		var progress: float = clampf(sim.fallen_for_s / FALL_DURATION_S, 0.0, 1.0)
		var eased: float = progress * progress
		var swim_time_s: float = maxf(sim.sailor_config.waterstart_time_s - FALL_DURATION_S - SWIM_READY_BEFORE_S, 0.3)
		var swim: float = clampf((sim.fallen_for_s - FALL_DURATION_S) / swim_time_s, 0.0, 1.0)
		_rig.pose_fallen(eased, float(sim.fall_side), swim, _figure.skeleton.windward_side())
		_rig.rotation_degrees = Vector3.ZERO
		_figure.pose_fallen(sim, eased, swim)
		_drawn_rig.snap()
		return

	# The rig: the mast direction and the boom direction. The simulation holds the rig in
	# the sailor's frame, not the deck's (RigFrame), so its directions are brought into
	# the board's axes here.
	var rig_to_board: Basis = body.basis.transposed() * sim.rig.basis
	var mast_dir: Vector3 = rig_to_board * sim.sail.mast_direction()
	# The boom as the simulation has it: level at the sail's angle, or square to the raked mast
	# (SailConfig.boom_square_to_mast), so the hands stay on it.
	var boom_dir: Vector3 = rig_to_board * sim.sail.boom_direction_local
	# Drawn smoothed, and swung across round the mast when the sail changes sides (DrawnRig).
	_drawn_rig.update(mast_dir, boom_dir, body.basis, sim.time_s - _drawn_time_s if _drawn_time_s >= 0.0 else -1.0)
	_drawn_time_s = sim.time_s
	mast_dir = _drawn_rig.mast_dir
	boom_dir = _drawn_rig.boom_dir
	# Getting up after a waterstart: the rig rises from the water as the sailor does.
	var raised: float = 1.0
	if _rise_start_s >= 0.0:
		raised = clampf((sim.time_s - _rise_start_s) / SailorFigure.RISE_S, 0.0, 1.0)
		if raised >= 1.0:
			_rise_start_s = -1.0
	if raised < 1.0:
		_rig.pose_rising(mast_dir, boom_dir, raised)
	else:
		_rig.pose_sailing(mast_dir, boom_dir)
	_rig.shape_sail(sim.sail, sim.time_s)
	# The chatter at the fin's limit (GR1): a shiver of the board and the rig, for the eye only;
	# the node the cameras follow does not move with it.
	var chatter: Vector2 = WindsurferEffects.chatter_deg(sim.telemetry.fin_load_share, sim.telemetry.fin_stalled, sim.time_s)
	_rig.rotation_degrees = Vector3(chatter.x, 0.0, chatter.y)
	# The sailor holds the windward arm of the wishbone boom, not the boom's centre line.
	_figure.pose_sailing(sim, boom_dir, _rig.windward_arm_offset(), mast_dir, _drawn_rig.flipping, raised)


func _build_visuals() -> void:
	_rig = RigVisuals.new()
	_rig.name = "Rig"
	add_child(_rig)
	_rig.build(sim.board_config, sim.sail_config, sim.fin_config, gear)
	_figure = SailorFigure.new()
	_figure.name = "SailorFigure"
	add_child(_figure)
	_figure.build(sim.sailor_config)
	# Spray, wake, splashes, the streamer, the wind flag and the force view (F3).
	if effects_wanted:
		_effects = WindsurferEffects.new()
		add_child(_effects)
		_effects.wind_flag_wanted = wind_flag_wanted
		_effects.setup(sim)


## The sail's colour, so the boards of a race tell apart (RaceRunner).
func set_sail_colour(colour: Color) -> void:
	_sail_colour = colour
	_rig.tint_sail(colour)


## A name above the mast head, seen from up to 300 m at the Normal draw distance (an opponent in a race).
func set_name_label(text: String) -> void:
	if _name_label == null:
		_name_label = Label3D.new()
		_name_label.name = "NameLabel"
		_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_name_label.no_depth_test = true
		_name_label.font_size = 64
		_name_label.pixel_size = 0.008
		_name_label.outline_size = 12
		_name_label.position = Vector3(0.0, 5.8, 0.0)
		_name_label.visibility_range_end = DrawDistance.full_detail_m()
		add_child(_name_label)
	_name_label.text = text


## The name is seen as far as the board is drawn with full care (the draw distance, which may change
## in the settings while sailing).
func _keep_label_range() -> void:
	if _name_label != null and _name_label.visibility_range_end != DrawDistance.full_detail_m():
		_name_label.visibility_range_end = DrawDistance.full_detail_m()


## The name above the mast head ("" without one): the race director's map writes it by the board.
func label_text() -> String:
	return _name_label.text if _name_label != null else ""


## What a tick of this board costs on average since the last call, milliseconds: the sailor (the
## skipper and the controller), the physics and the visuals. For --measure (main.gd).
func cost_text() -> String:
	var cost: Vector3 = take_cost_ms()
	return "sailor %.2f, physics %.2f, visuals %.2f ms per tick" % [cost.x, cost.y, cost.z]


## The same as numbers, and the counting starts again: x the sailor, y the physics, z the
## visuals, milliseconds per tick on average.
func take_cost_ms() -> Vector3:
	var ticks: float = maxf(float(_ticks_counted), 1.0)
	var cost: Vector3 = Vector3(_us_sailor, _us_sim, _us_visuals) / ticks / 1000.0
	_us_sailor = 0
	_us_sim = 0
	_us_visuals = 0
	_ticks_counted = 0
	return cost
