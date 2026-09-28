extends Node3D
## Placeholder scene that proves the Godot setup works: sky, sun, a flat water plane and
## the board and sail models carried over from the Unity project.
## Phase 3 of Documentation/REBUILD_PLAN.md replaces this with the playable prototype.

@onready var _camera: Camera3D = $Camera3D
@onready var _sun: DirectionalLight3D = $Sun


func _ready() -> void:
	_sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	_camera.look_at_from_position(Vector3(4.0, 2.5, 6.0), Vector3(0.0, 0.8, 0.0))
