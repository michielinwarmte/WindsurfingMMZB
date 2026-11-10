class_name CameraRig
extends Node3D
## The cameras: follow (behind the board), orbit (move the mouse while holding the look key,
## the right mouse button or C; zoom with the wheel), top-down (map view, bow up) and free (a fixed spectator that keeps
## looking at the board). All of them read the board's interpolated transform, so the
## picture is smooth even though the physics runs in fixed ticks.

enum Mode { FOLLOW, ORBIT, TOP_DOWN, FREE }

@export var target_path: NodePath
var mode: Mode = Mode.FOLLOW
var camera: Camera3D

## Follow camera: where it sits relative to the board (board axes, yaw only) and how
## quickly it catches up (seconds). Two framings (follow_close, a setting): the sailing one,
## low and close behind the board and looking ahead of it, so the rail, the spray and the
## water ahead (the gusts, the wave faces) fill the view (GR4); and the classic one, higher
## and further back, looking at the board.
const FOLLOW_CLOSE_OFFSET: Vector3 = Vector3(0.0, 1.6, 4.4)
const FOLLOW_CLOSE_LOOK_AHEAD_M: float = 7.0
const FOLLOW_CLOSE_LOOK_UP_M: float = 0.9
var follow_close: bool = true
var follow_offset: Vector3 = Vector3(0.0, 2.2, 6.0)
var follow_smoothing_s: float = 0.35
var _follow_position: Vector3 = Vector3.ZERO
var _follow_initialised: bool = false

## Orbit camera. The wheel zooms it out as far as orbit_max_m (watching an AI race: further, WatchMode);
## orbit_drift_rad_s circles it round the board by itself (the watcher's helicopter and TV shots; 0:
## still). The circling goes on while a watched race is frozen (WatchMode's P).
var orbit_azimuth_rad: float = 0.6
var orbit_elevation_rad: float = 0.35
var orbit_distance_m: float = 9.0
var orbit_max_m: float = 60.0
var orbit_drift_rad_s: float = 0.0

## Top-down camera.
var top_down_height_m: float = 45.0
var _top_down_heading_rad: float = 0.0

## Free camera: a fixed world position (a spectator). Until the camera has been placed by
## a first update it starts a little way from the board.
var _free_position: Vector3 = Vector3(12.0, 4.0, 12.0)
var _placed: bool = false

var _target: Node3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	camera = Camera3D.new()
	camera.name = "Camera3D"
	# This camera moves in _process (every rendered frame), not in physics ticks: no interpolation.
	# With it on, Godot drew the camera between its places at the last two ticks while the board
	# was drawn where it is now, and the board shook in the picture by up to 2.5 pixels a frame (GR9).
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.current = true
	# 35 km at the Normal draw distance, so a map's far mountains are drawn (MAP_SILVAPLANA_PLAN.md,
	# M2: the farthest visible land at Silvaplana is 32 km away). On open water the fog hides everything
	# past 1.5 km anyway. Settings > Graphics > Draw distance moves it (DrawDistance, _keep_far_plane()).
	camera.far = DrawDistance.camera_far_m()
	add_child(camera)
	_target = get_node_or_null(target_path) as Node3D


## The far plane at the draw distance's step, also when it changes in the settings while sailing.
func _keep_far_plane() -> void:
	var far_m: float = DrawDistance.camera_far_m()
	if camera.far != far_m:
		camera.far = far_m


## Another board to follow (a race's spectator moves the camera from board to board); the follow
## camera jumps to it instead of gliding across the water. Nothing changes for the same board.
func set_target(target: Node3D) -> void:
	if target == _target:
		return
	_target = target
	_follow_initialised = false
	# The free camera stands still in the world: it moves to the new board's side.
	if mode == Mode.FREE and target != null:
		_free_position = target.global_position + Vector3(12.0, 4.0, 12.0)


func target() -> Node3D:
	return _target


func set_mode(new_mode: Mode) -> void:
	if new_mode == Mode.FREE and mode != Mode.FREE:
		if _placed:
			_free_position = camera.global_position
		elif _target != null:
			_free_position = _target.global_position + Vector3(12.0, 4.0, 12.0)
	mode = new_mode
	_follow_initialised = false


func mode_name() -> String:
	match mode:
		Mode.FOLLOW:
			return "Follow"
		Mode.ORBIT:
			return "Orbit"
		Mode.TOP_DOWN:
			return "Top-down"
	return "Free"


func _unhandled_input(event: InputEvent) -> void:
	# The look key (the action camera_look: the right mouse button, or C held): with the body on the
	# mouse (package B) the mouse is the sailor's body, and only while the key is held does it turn
	# the camera (main.gd hands the movement to the body otherwise).
	if mode == Mode.ORBIT and event is InputEventMouseMotion and Input.is_action_pressed("camera_look"):
		var motion: InputEventMouseMotion = event
		# The mouse's own pixels (screen_relative), not the HUD's scaled ones: the camera turns as
		# far for a hand's move in any window size (project.godot scales the HUD with the window).
		orbit_azimuth_rad -= motion.screen_relative.x * 0.005
		orbit_elevation_rad = clampf(orbit_elevation_rad + motion.screen_relative.y * 0.005, 0.05, 1.4)
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			orbit_distance_m = maxf(orbit_distance_m * 0.9, 3.0)
			top_down_height_m = maxf(top_down_height_m * 0.9, 10.0)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			orbit_distance_m = minf(orbit_distance_m * 1.1, maxf(orbit_max_m, orbit_distance_m))
			top_down_height_m = minf(top_down_height_m * 1.1, 300.0)


func _process(delta: float) -> void:
	_keep_far_plane()
	if _target == null:
		return
	var board: Transform3D = _target.get_global_transform_interpolated()
	var origin: Vector3 = board.origin
	var look_point: Vector3 = origin + Vector3(0.0, 1.2, 0.0)
	_placed = true
	# The board's heading as a yaw-only frame (the camera should not heel with the board).
	var forward_h: Vector3 = -board.basis.z
	forward_h.y = 0.0
	forward_h = forward_h.normalized() if forward_h.length() > 0.01 else Vector3.FORWARD
	var yaw: float = atan2(-forward_h.x, -forward_h.z)
	var yaw_basis: Basis = Basis(Vector3.UP, yaw)

	match mode:
		Mode.FOLLOW:
			var wanted: Vector3 = origin + yaw_basis * (FOLLOW_CLOSE_OFFSET if follow_close else follow_offset)
			if not _follow_initialised:
				_follow_position = wanted
				_follow_initialised = true
			var blend: float = 1.0 - exp(-delta / follow_smoothing_s)
			_follow_position = _follow_position.lerp(wanted, blend)
			camera.global_position = _follow_position
			if follow_close:
				look_point = origin + forward_h * FOLLOW_CLOSE_LOOK_AHEAD_M + Vector3(0.0, FOLLOW_CLOSE_LOOK_UP_M, 0.0)
			camera.look_at(look_point, Vector3.UP)
		Mode.ORBIT:
			orbit_azimuth_rad += orbit_drift_rad_s * delta
			var offset: Vector3 = Vector3(
				cos(orbit_elevation_rad) * sin(orbit_azimuth_rad),
				sin(orbit_elevation_rad),
				cos(orbit_elevation_rad) * cos(orbit_azimuth_rad)) * orbit_distance_m
			camera.global_position = origin + offset
			camera.look_at(look_point, Vector3.UP)
		Mode.TOP_DOWN:
			_top_down_heading_rad = lerp_angle(_top_down_heading_rad, yaw, 1.0 - exp(-delta / 1.0))
			camera.global_position = origin + Vector3(0.0, top_down_height_m, 0.0)
			camera.look_at(origin, Basis(Vector3.UP, _top_down_heading_rad) * Vector3.FORWARD)
		Mode.FREE:
			if _free_position.distance_to(look_point) < 2.0:
				_free_position = look_point + Vector3(12.0, 4.0, 12.0)
			camera.global_position = _free_position
			camera.look_at(look_point, Vector3.UP)
