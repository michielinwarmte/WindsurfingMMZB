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
## Let the test autopilot sail instead of the keys (for screenshots and demos).
@export var use_autopilot: bool = false
@export var autopilot_twa_deg: float = 90.0

## The wind and the sea to sail in. null = the default config files. The sailing scene
## (main.gd) sets them from the player's settings before this node is ready.
var wind_config: WindConfig = null
var wave_set_config: WaveSetConfig = null

var sim: WindsurferSim
var controls: SimControls = SimControls.new()
var controller: PlayerController = PlayerController.new()
var autopilot: Autopilot = Autopilot.new()

## The fall takes this long on screen (the physics has already let go).
const FALL_DURATION_S: float = 0.9

var _previous_state: WindsurferSim.SailorState = WindsurferSim.SailorState.SAILING

var _rig: RigVisuals
var _figure: SailorFigure


func _ready() -> void:
	sim = WindsurferSim.create_default(true)
	if wind_config != null or wave_set_config != null:
		set_sea(wind_config, wave_set_config)
	controller.set_sail(sim.sail, sim.sailor_config)
	autopilot.sail = sim.sail
	_build_visuals()
	reset()


## Puts the board back at the start, at rest.
func reset() -> void:
	controls = SimControls.new()
	controller.reset_controls(controls)
	sim.reset(Vector3.ZERO, deg_to_rad(start_heading_deg))
	_previous_state = sim.sailor_state
	autopilot.target_twa_deg = autopilot_twa_deg
	_copy_state_to_visuals()
	reset_physics_interpolation()


## Puts the simulation in another wind and on another sea (null keeps the current one).
## The waves are lined up with the new wind. Call reset() afterwards: the water changes
## under the board.
func set_sea(wind: WindConfig, waves: WaveSetConfig) -> void:
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
	if sim.sailor_state == WindsurferSim.SailorState.SAILING:
		if use_autopilot:
			autopilot.update(sim.telemetry, controls, delta)
		else:
			controller.update(sim.telemetry, controls, delta)
	sim.step(delta, controls)
	if sim.sailor_state == WindsurferSim.SailorState.SAILING and _previous_state == WindsurferSim.SailorState.FALLEN:
		_after_waterstart()
	_previous_state = sim.sailor_state
	_copy_state_to_visuals()


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


func _copy_state_to_visuals() -> void:
	var body: SimRigidBody = sim.body
	global_transform = Transform3D(body.basis, body.origin_world())
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
	var boom_angle: float = sim.sail.sail_angle_rad()
	var boom_dir: Vector3 = rig_to_board * Vector3(sin(boom_angle), 0.0, cos(boom_angle))
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
