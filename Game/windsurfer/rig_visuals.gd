class_name RigVisuals
extends Node3D
## What the board and the rig look like: the board, its nose, the fin, the mast, the sail
## and the boom. It only draws: the windsurfer node tells it where the simulation holds the
## mast and the boom (pose_sailing) or how far a fall has got (pose_fallen). Everything is
## in the board's own axes (x starboard, y up, z aft; the bow is -z). Nothing here feeds
## back into the physics (CLAUDE.md, rule 2).
##
## Phase 6 of the plan replaces the placeholder shapes below (a box board, a cylinder
## mast, a flat four-cornered sail) with real models; the two pose functions are the
## interface the rest of the scene relies on.

var _board: MeshInstance3D
var _nose: MeshInstance3D
var _fin: MeshInstance3D
var _mast: MeshInstance3D
var _sail: MeshInstance3D
var _boom: MeshInstance3D

var _sail_config: SailConfig
# The pose at the last sailing tick, from which a fall starts.
var _last_mast_dir: Vector3 = Vector3.UP
var _last_boom_dir: Vector3 = Vector3.BACK


## Builds the meshes from the equipment's dimensions.
func build(board_config: BoardConfig, sail_config: SailConfig, fin_config: FinConfig) -> void:
	_sail_config = sail_config
	_board = VisualMath.add_box(self, "Board", Vector3(board_config.width_m, board_config.thickness_m, board_config.length_m), Vector3.ZERO, Color(0.93, 0.93, 0.9))
	_nose = VisualMath.add_box(self, "Nose", Vector3(0.45, board_config.thickness_m + 0.01, 0.5), Vector3(0.0, 0.0, -0.5 * board_config.length_m + 0.3), Color(0.95, 0.45, 0.1))
	var fin_root: Vector3 = fin_config.root_local
	_fin = VisualMath.add_box(self, "Fin", Vector3(0.012, fin_config.span_m, 0.12), fin_root + Vector3(0.0, -0.5 * fin_config.span_m, 0.0), Color(0.1, 0.1, 0.1))

	_mast = MeshInstance3D.new()
	_mast.name = "Mast"
	var mast_mesh: CylinderMesh = CylinderMesh.new()
	mast_mesh.height = sail_config.mast_m
	mast_mesh.top_radius = 0.02
	mast_mesh.bottom_radius = 0.035
	_mast.mesh = mast_mesh
	_mast.material_override = VisualMath.plain_material(Color(0.15, 0.15, 0.17))
	add_child(_mast)

	_sail = MeshInstance3D.new()
	_sail.name = "Sail"
	_sail.mesh = _sail_mesh(sail_config)
	var sail_material: StandardMaterial3D = VisualMath.plain_material(Color(0.97, 0.97, 1.0, 0.8))
	sail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sail_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_sail.material_override = sail_material
	add_child(_sail)
	_boom = VisualMath.add_box(_sail, "Boom", Vector3(sail_config.boom_m, 0.04, 0.04), Vector3(0.5 * sail_config.boom_m, sail_config.boom_height_m, 0.0), Color(0.05, 0.05, 0.05))


## The rig while sailing: the mast from the mast foot along `mast_dir`, the sail and the
## boom in the plane of the mast and `boom_dir`. Both directions are unit vectors in the
## board's axes.
func pose_sailing(mast_dir: Vector3, boom_dir: Vector3) -> void:
	_pose_rig(mast_dir, boom_dir)
	_last_mast_dir = mast_dir
	_last_boom_dir = boom_dir


## The fall on screen: the rig pivots about the mast foot until it lies on the water on the
## side of the fall. `eased` runs from 0 (the fall starts) to 1 (the rig is down), `side`
## is -1 for port and +1 for starboard.
func pose_fallen(eased: float, side: float) -> void:
	var flat: Vector3 = Vector3(side, 0.03, 0.0).normalized()
	var mast_dir: Vector3 = _last_mast_dir.slerp(flat, eased).normalized()
	_pose_rig(mast_dir, _last_boom_dir)


## Mast and sail from the mast foot, both directions in the board's axes.
func _pose_rig(mast_dir: Vector3, boom_dir: Vector3) -> void:
	var foot: Vector3 = _sail_config.mast_foot_local
	_mast.transform = Transform3D(VisualMath.basis_with_up(mast_dir), foot + mast_dir * (0.5 * _sail_config.mast_m))
	var sail_normal: Vector3 = boom_dir.cross(mast_dir)
	if sail_normal.length() < 0.05:
		sail_normal = Vector3.UP
	_sail.transform = Transform3D(Basis(boom_dir, mast_dir, sail_normal.normalized()), foot)


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
