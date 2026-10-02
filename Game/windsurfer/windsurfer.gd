class_name WindsurferNode
extends Node3D
## The windsurfer in the scene. Owns a WindsurferSim, steps it once per physics tick with
## the player's (or the autopilot's) controls, and copies the result onto simple visuals:
## a box for the board, a fin, a mast, a sail that turns with the sheet, the rake and the
## rig lean, and a capsule for the sailor that stands where the sailor's weight is.
## Nothing visual feeds back into the physics (CLAUDE.md, architecture rule 2).

## Compass heading at the start, degrees. 180 (South) with the default wind from the West
## puts the board on a beam reach on starboard tack.
@export var start_heading_deg: float = 180.0
## Let the test autopilot sail instead of the keys (for screenshots and demos).
@export var use_autopilot: bool = false
@export var autopilot_twa_deg: float = 90.0

var sim: WindsurferSim
var controls: SimControls = SimControls.new()
var controller: PlayerController = PlayerController.new()
var autopilot: Autopilot = Autopilot.new()

var _board: MeshInstance3D
var _nose: MeshInstance3D
var _fin: MeshInstance3D
var _mast: MeshInstance3D
var _sail: MeshInstance3D
var _boom: MeshInstance3D
var _sailor: MeshInstance3D


func _ready() -> void:
	sim = WindsurferSim.create_default()
	_build_visuals()
	reset()


## Puts the board back at the start, at rest.
func reset() -> void:
	controls = SimControls.new()
	controls.sheet = 0.0
	controller.manoeuvre = PlayerController.Manoeuvre.NONE
	sim.reset(Vector3.ZERO, deg_to_rad(start_heading_deg))
	autopilot.target_twa_deg = autopilot_twa_deg
	_copy_state_to_visuals()
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if use_autopilot:
		autopilot.update(sim.telemetry, controls, delta)
	else:
		controller.update(sim.telemetry, controls, delta)
	sim.step(delta, controls)
	_copy_state_to_visuals()


func telemetry() -> Telemetry:
	return sim.telemetry


## The board's transform, smoothed between physics ticks, for cameras.
func interpolated_transform() -> Transform3D:
	return get_global_transform_interpolated()


func _copy_state_to_visuals() -> void:
	var body: SimRigidBody = sim.body
	global_transform = Transform3D(body.basis, body.origin_world())

	# The rig: mast from the mast foot along the mast direction, sail and boom in the plane
	# of the mast and the boom.
	var sail_config: SailConfig = sim.sail_config
	var mast_dir: Vector3 = sim.sail.mast_direction()
	var foot: Vector3 = sail_config.mast_foot_local
	_mast.transform = Transform3D(_basis_with_up(mast_dir), foot + mast_dir * (0.5 * sail_config.mast_m))
	var boom_angle: float = sim.sail.sail_angle_rad()
	var boom_dir: Vector3 = Vector3(sin(boom_angle), 0.0, cos(boom_angle))
	_sail.transform = Transform3D(Basis(boom_dir, mast_dir, boom_dir.cross(mast_dir).normalized()), foot)

	# The sailor: a capsule from the feet up to and beyond the centre of mass.
	var sailor_config: SailorConfig = sim.sailor_config
	var com: Vector3 = sim.mass_model.sailor_position_body
	var feet: Vector3 = Vector3(0.22 * clampf(sim.lean * 3.0, -1.0, 1.0), 0.06, lerpf(sailor_config.stance_rest_z_m, sailor_config.stance_planing_z_m, sim.stance))
	var axis: Vector3 = (com - feet).normalized()
	_sailor.transform = Transform3D(_basis_with_up(axis), feet + axis * (0.5 * sailor_config.height_m))


func _build_visuals() -> void:
	var board_config: BoardConfig = sim.board_config
	var sail_config: SailConfig = sim.sail_config
	var fin_config: FinConfig = sim.fin_config
	var sailor_config: SailorConfig = sim.sailor_config

	_board = _add_box("Board", Vector3(board_config.width_m, board_config.thickness_m, board_config.length_m), Vector3.ZERO, Color(0.93, 0.93, 0.9))
	_nose = _add_box("Nose", Vector3(0.45, board_config.thickness_m + 0.01, 0.5), Vector3(0.0, 0.0, -0.5 * board_config.length_m + 0.3), Color(0.95, 0.45, 0.1))
	var fin_root: Vector3 = fin_config.root_local
	_fin = _add_box("Fin", Vector3(0.012, fin_config.span_m, 0.12), fin_root + Vector3(0.0, -0.5 * fin_config.span_m, 0.0), Color(0.1, 0.1, 0.1))

	_mast = MeshInstance3D.new()
	_mast.name = "Mast"
	var mast_mesh: CylinderMesh = CylinderMesh.new()
	mast_mesh.height = sail_config.mast_m
	mast_mesh.top_radius = 0.02
	mast_mesh.bottom_radius = 0.035
	_mast.mesh = mast_mesh
	_mast.material_override = _material(Color(0.15, 0.15, 0.17))
	add_child(_mast)

	_sail = MeshInstance3D.new()
	_sail.name = "Sail"
	_sail.mesh = _sail_mesh(sail_config)
	var sail_material: StandardMaterial3D = _material(Color(0.97, 0.97, 1.0, 0.8))
	sail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sail_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_sail.material_override = sail_material
	add_child(_sail)
	_boom = _add_box("Boom", Vector3(sail_config.boom_m, 0.04, 0.04), Vector3(0.5 * sail_config.boom_m, sail_config.boom_height_m, 0.0), Color(0.05, 0.05, 0.05), _sail)

	_sailor = MeshInstance3D.new()
	_sailor.name = "Sailor"
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = 0.75 * sailor_config.torso_radius_m
	capsule.height = sailor_config.height_m
	_sailor.mesh = capsule
	_sailor.material_override = _material(Color(0.12, 0.12, 0.14))
	add_child(_sailor)


## The sail as a flat four-cornered cloth in its own frame: x along the boom, y up the mast.
func _sail_mesh(sail_config: SailConfig) -> ArrayMesh:
	var foot_height: float = 0.15
	var vertices: PackedVector3Array = PackedVector3Array([
		Vector3(0.0, foot_height, 0.0),
		Vector3(0.0, sail_config.luff_m, 0.0),
		Vector3(sail_config.boom_m, sail_config.boom_height_m, 0.0),
		Vector3(0.75 * sail_config.boom_m, foot_height + 0.35, 0.0),
	])
	var normals: PackedVector3Array = PackedVector3Array()
	for i: int in vertices.size():
		normals.append(Vector3(0.0, 0.0, 1.0))
	var indices: PackedInt32Array = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _add_box(node_name: String, size: Vector3, position_local: Vector3, color: Color, parent: Node3D = self) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	instance.mesh = box
	instance.position = position_local
	instance.material_override = _material(color)
	parent.add_child(instance)
	return instance


func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	return material


## A rotation whose y axis points along `up` (for cylinders and capsules).
static func _basis_with_up(up: Vector3) -> Basis:
	var y: Vector3 = up.normalized()
	var reference: Vector3 = Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x: Vector3 = y.cross(reference).normalized()
	var z: Vector3 = x.cross(y)
	return Basis(x, y, z)
