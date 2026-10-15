class_name TopCamera
extends Camera3D
## A map camera: looks straight down with north at the top of the screen, like a paper map
## (the wind viewer, MAP_SILVAPLANA_PLAN.md W2).
## W A S D or the arrow keys move it, Shift five times faster; the mouse wheel (or E and Q) zooms;
## dragging with the right mouse button moves the map with the mouse.

## Height above the lake, in metres.
@export var height_m: float = 6000.0
@export var min_height_m: float = 150.0
@export var max_height_m: float = 30000.0

## The game position (X, Z) straight below the camera.
var centre: Vector2 = Vector2.ZERO


func _ready() -> void:
	# This camera moves in _process (every rendered frame), not in physics ticks: no interpolation.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_apply()


## Puts the camera above a game position (X, Z) at a height above the lake.
func look_down_at(point_xz: Vector2, height_above_lake_m: float) -> void:
	centre = point_xz
	height_m = clampf(height_above_lake_m, min_height_m, max_height_m)
	_apply()


## How many metres of ground one pixel of the screen shows, at the lake's level.
func metres_per_pixel() -> float:
	var screen_height_px: float = maxf(get_viewport().get_visible_rect().size.y, 1.0)
	return 2.0 * height_m * tan(deg_to_rad(fov) / 2.0) / screen_height_px


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var motion: InputEventMouseMotion = event
		# Screen right is east (+X) and screen down is south (+Z): the map follows the mouse.
		centre -= motion.relative * metres_per_pixel()
		_apply()
	elif event is InputEventMouseButton and event.is_pressed():
		var button: InputEventMouseButton = event
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(1.0 / 1.2)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(1.2)


func _process(delta: float) -> void:
	# While a text field on the screen has the keyboard (a name being typed), the keys aren't ours.
	if get_viewport().gui_get_focus_owner() != null:
		return
	var move: Vector2 = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		move.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		move.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		move.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		move.x += 1.0
	var fast: float = 5.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0
	if move != Vector2.ZERO:
		# Half the height per second: the same speed on the screen at every zoom.
		centre += move.normalized() * height_m * 0.5 * fast * delta
		_apply()
	if Input.is_physical_key_pressed(KEY_E):
		_zoom(pow(0.5, delta * fast))
	if Input.is_physical_key_pressed(KEY_Q):
		_zoom(pow(2.0, delta * fast))


func _zoom(factor: float) -> void:
	height_m = clampf(height_m * factor, min_height_m, max_height_m)
	_apply()


func _apply() -> void:
	global_position = Vector3(centre.x, height_m, centre.y)
	# Pitched straight down; the top of the screen is then north (-Z).
	global_rotation = Vector3(-PI / 2.0, 0.0, 0.0)
