extends Node
## Logs, every rendered frame and after every other node's _process, where the follow camera
## is drawn and where the board is drawn (both interpolated), as the board's place in the camera's view.
var rig: Node
var frame: int = 0
var rows: PackedStringArray = []
var out_path: String = ""
var interp_off: bool = false
var seconds: float = 12.0
var _t: float = 0.0

func _ready() -> void:
	process_priority = 100000

func _process(delta: float) -> void:
	frame += 1
	if rig == null:
		rig = get_tree().root.find_child("CameraRig", true, false)
		if rig == null:
			return
	if interp_off and rig.camera.physics_interpolation_mode != Node.PHYSICS_INTERPOLATION_MODE_OFF:
		rig.camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var target: Node3D = rig.target()
	if target == null:
		return
	_t += delta
	if _t < 3.0:
		return
	var cam: Transform3D = rig.camera.get_global_transform_interpolated()
	var b: Transform3D = target.get_global_transform_interpolated()
	var p: Vector3 = cam.affine_inverse() * b.origin
	var f: Vector3 = -cam.basis.z
	rows.append("%f,%f,%f,%f,%f,%f,%f,%f" % [delta, p.x, p.y, p.z, f.x, f.y, f.z, Engine.get_physics_interpolation_fraction()])
	if _t > 3.0 + seconds:
		var file := FileAccess.open(out_path, FileAccess.WRITE)
		file.store_string("dt,px,py,pz,fx,fy,fz,frac\n" + "\n".join(rows) + "\n")
		file.close()
		get_tree().quit()
