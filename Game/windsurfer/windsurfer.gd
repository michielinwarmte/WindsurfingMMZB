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

var sim: WindsurferSim
var controls: SimControls = SimControls.new()
var controller: PlayerController = PlayerController.new()
var autopilot: Autopilot = Autopilot.new()
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
var _name_label: Label3D = null
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

var _previous_state: WindsurferSim.SailorState = WindsurferSim.SailorState.SAILING

var _rig: RigVisuals
var _figure: SailorFigure
var _effects: WindsurferEffects


func _ready() -> void:
	sim = WindsurferSim.create_for(environment if environment != null else EnvironmentConfig.new(), true, own_config_copies)
	if wind_config != null or wave_set_config != null:
		set_sea(wind_config, wave_set_config)
	controller.set_sail(sim.sail, sim.sailor_config, sim.air_density_kg_m3)
	autopilot.sail = sim.sail
	autopilot.air_density_kg_m3 = sim.air_density_kg_m3
	_build_visuals()
	reset()


## Puts the board back at the start, at rest.
func reset() -> void:
	controls = SimControls.new()
	controller.reset_controls(controls)
	sim.reset(start_position, deg_to_rad(start_heading_deg))
	_previous_state = sim.sailor_state
	autopilot.target_twa_deg = autopilot_twa_deg
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
	var t0: int = Time.get_ticks_usec()
	if skipper != null:
		skipper.update(sim.telemetry, delta)
	if sim.sailor_state == WindsurferSim.SailorState.SAILING:
		if use_autopilot:
			autopilot.update(sim.telemetry, controls, delta)
		else:
			controller.update(sim.telemetry, controls, delta)
	_us_sailor += Time.get_ticks_usec() - t0


## The physics of a tick. It touches only this board's simulation, so a race may run several
## boards' steps side by side on worker threads (with own_config_copies).
func step_physics(delta: float) -> void:
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


## A race's opponent far from the camera (RaceRunner.FAR_DETAIL_M): its fin's bend is not
## updated every frame (the fin is under water, and a few pixels long that far away).
func set_far_away(far: bool) -> void:
	if far == _far_away:
		return
	_far_away = far
	_rig.set_process(not far)


func is_far_away() -> bool:
	return _far_away


func _after_waterstart() -> void:
	controller.reset_controls(controls)
	_previous_state = sim.sailor_state
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
		# A fall picks up speed: the progress is squared.
		var progress: float = clampf(sim.fallen_for_s / FALL_DURATION_S, 0.0, 1.0)
		var eased: float = progress * progress
		_rig.pose_fallen(eased, float(sim.fall_side))
		_figure.pose_fallen(sim, eased)
		return

	# The rig: the mast direction and the boom direction. The simulation holds the rig in
	# the sailor's frame, not the deck's (RigFrame), so its directions are brought into
	# the board's axes here.
	var rig_to_board: Basis = body.basis.transposed() * sim.rig.basis
	var mast_dir: Vector3 = rig_to_board * sim.sail.mast_direction()
	# The boom as the simulation has it: level at the sail's angle, or square to the raked mast
	# (SailConfig.boom_square_to_mast), so the hands stay on it.
	var boom_dir: Vector3 = rig_to_board * sim.sail.boom_direction_local
	_rig.pose_sailing(mast_dir, boom_dir)
	_rig.shape_sail(sim.sail, sim.time_s)
	# The sailor holds the windward arm of the wishbone boom, not the boom's centre line.
	_figure.pose_sailing(sim, boom_dir, _rig.windward_arm_offset())


func _build_visuals() -> void:
	_rig = RigVisuals.new()
	_rig.name = "Rig"
	add_child(_rig)
	_rig.build(sim.board_config, sim.sail_config, sim.fin_config)
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
	_rig.tint_sail(colour)


## A name above the mast head, seen from up to 300 m (an opponent in a race).
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
		_name_label.visibility_range_end = 300.0
		add_child(_name_label)
	_name_label.text = text


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
