extends Node3D
## View of the map pipeline's round-trip hill (MAP_SILVAPLANA_PLAN.md, M0), for
## tools/screenshot.sh res://maps/silvaplana/dev/roundtrip_view.tscn.
## The red ball marks where the hill's top should be (20 m east, 10 m up, 30 m north),
## the blue ball marks north (the far edge of the 100 m square).

@onready var _camera: Camera3D = $Camera3D
@onready var _sun: DirectionalLight3D = $Sun


func _ready() -> void:
	_sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	# From the south-east, looking north-west at the square.
	_camera.look_at_from_position(Vector3(70.0, 45.0, 80.0), Vector3(5.0, 2.0, -10.0))
