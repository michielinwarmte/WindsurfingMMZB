class_name CameraRig
extends Node3D
## The cameras: follow (behind the board), orbit (drag with the right mouse button, zoom
## with the wheel), top-down (map view, bow up) and free (a fixed spectator that keeps
## looking at the board). All of them read the board's interpolated transform, so the
## picture is smooth even though the physics runs in fixed ticks.

enum Mode { FOLLOW, ORBIT, TOP_DOWN, FREE }

@export var target_path: NodePath
var mode: Mode = Mode.FOLLOW
var camera: Camera3D

## Follow camera: where it sits relative to the board (board axes, yaw only) and how
## quickly it catches up (seconds).
var follow_offset: Vector3 = Vector3(0.0, 2.2, 6.0)
var follow_smoothing_s: float = 0.35
var _follow_position: Vector3 = Vector3.ZERO
var _follow_initialised: bool = false

## Orbit camera.
var orbit_azimuth_rad: float = 0.6
var orbit_elevation_rad: float = 0.35
var orbit_distance_m: float = 9.0

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
	camera.current = true
	camera.far = 3000.0
	add_child(camera)
	_target = get_node_or_null(target_path) as Node3D


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
	if mode == Mode.ORBIT and event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var motion: InputEventMouseMotion = event
		orbit_azimuth_rad -= motion.relative.x * 0.005
		orbit_elevation_rad = clampf(orbit_elevation_rad + motion.relative.y * 0.005, 0.05, 1.4)
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
			orbit_distance_m = maxf(orbit_distance_m * 0.9, 3.0)
			top_down_height_m = maxf(top_down_height_m * 0.9, 10.0)
		elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			orbit_distance_m = minf(orbit_distance_m * 1.1, 60.0)
			top_down_height_m = minf(top_down_height_m * 1.1, 300.0)


func _process(delta: float) -> void:
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
			var wanted: Vector3 = origin + yaw_basis * follow_offset
			if not _follow_initialised:
				_follow_position = wanted
				_follow_initialised = true
			var blend: float = 1.0 - exp(-delta / follow_smoothing_s)
			_follow_position = _follow_position.lerp(wanted, blend)
			camera.global_position = _follow_position
			camera.look_at(look_point, Vector3.UP)
		Mode.ORBIT:
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
