class_name FlyCamera
extends Camera3D
## A free camera for looking around a map (the development views in Game/maps/*/dev/).
## W A S D fly forward, back and sideways, E and Q go up and down, Shift goes five times faster.
## Hold the right mouse button and move the mouse to look around; the mouse wheel changes the speed.

@export var speed_ms: float = 100.0
@export var mouse_sensitivity: float = 0.004

var _yaw_rad: float = 0.0
var _pitch_rad: float = 0.0


func _ready() -> void:
	# This camera moves in _process (every rendered frame), not in physics ticks: no interpolation.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_read_angles()


## Puts the camera at a position, looking at a point.
func place(at: Vector3, look_at_point: Vector3) -> void:
	look_at_from_position(at, look_at_point, Vector3.UP)
	_read_angles()


func _read_angles() -> void:
	var forward: Vector3 = -global_basis.z
	_yaw_rad = atan2(-forward.x, -forward.z)
	_pitch_rad = asin(clampf(forward.y, -1.0, 1.0))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var motion: InputEventMouseMotion = event
		_yaw_rad -= motion.relative.x * mouse_sensitivity
		_pitch_rad = clampf(_pitch_rad - motion.relative.y * mouse_sensitivity, -1.55, 1.55)
		rotation = Vector3(_pitch_rad, _yaw_rad, 0.0)
	elif event is InputEventMouseButton and event.is_pressed():
		var button: InputEventMouseButton = event
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			speed_ms = minf(speed_ms * 1.25, 5000.0)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			speed_ms = maxf(speed_ms / 1.25, 1.0)


func _process(delta: float) -> void:
	# While a text field on the screen has the keyboard (a name being typed), the keys aren't ours.
	if get_viewport().gui_get_focus_owner() != null:
		return
	var move: Vector3 = Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		move.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		move.z += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		move.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		move.x += 1.0
	var up: float = 0.0
	if Input.is_physical_key_pressed(KEY_E):
		up += 1.0
	if Input.is_physical_key_pressed(KEY_Q):
		up -= 1.0
	if move == Vector3.ZERO and up == 0.0:
		return
	var fast: float = 5.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0
	var step: Vector3 = global_basis * move.normalized() + Vector3.UP * up
	global_position += step * speed_ms * fast * delta
