class_name MassModel
extends RefCounted
## Mass, centre of mass and inertia of the whole windsurfer (board, rig and sailor) as one
## rigid body (PHYSICS_SPEC.md section 7). The sailor is a real part of the body: their
## stance (fore and aft) and lean (sideways) move the centre of mass, and with it the lever
## arm of every force.
##
## All positions are in body axes relative to the board origin (the centre of the hull box):
## x = starboard, y = up, z = aft.

var board: BoardConfig
var sail: SailConfig
var sailor: SailorConfig

## Results of the last update().
var total_mass_kg: float = 0.0
var com_offset_body: Vector3 = Vector3.ZERO
var inertia_body: Basis = Basis.IDENTITY
var sailor_position_body: Vector3 = Vector3.ZERO
var rig_position_body: Vector3 = Vector3.ZERO


func _init(board_config: BoardConfig, sail_config: SailConfig, sailor_config: SailorConfig) -> void:
	board = board_config
	sail = sail_config
	sailor = sailor_config
	update(0.0, 0.0)


## stance: 0 = feet near the mast foot, 1 = feet in the back straps.
## lean: -1 = sailor fully out to port, +1 = fully out to starboard, 0 = upright.
## hang_back_m: how far the sailor's weight hangs behind the feet against the sail's pull.
## knee_bend_m: how far the knees have flexed; positive lowers the sailor's body.
func update(stance: float, lean: float, hang_back_m: float = 0.0, knee_bend_m: float = 0.0) -> void:
	stance = clampf(stance, 0.0, 1.0)
	lean = clampf(lean, -1.0, 1.0)
	sailor_position_body = Vector3(
		lean * sailor.lean_max_m,
		sailor.com_height_m - absf(lean) * sailor.lean_height_drop_m - knee_bend_m,
		lerpf(sailor.stance_rest_z_m, sailor.stance_planing_z_m, stance) + hang_back_m)
	rig_position_body = sail.mast_foot_local + Vector3(0.0, sail.rig_com_height_m, 0.0)
	var board_position_body: Vector3 = Vector3.ZERO

	total_mass_kg = board.mass_kg + sail.rig_mass_kg + sailor.mass_kg
	com_offset_body = (board.mass_kg * board_position_body
		+ sail.rig_mass_kg * rig_position_body
		+ sailor.mass_kg * sailor_position_body) / total_mass_kg

	# Own inertia of each part about its own centre, in body axes (x across, y up, z along).
	var board_own: Vector3 = _box_inertia(board.mass_kg, board.width_m, board.thickness_m, board.length_m)
	var sailor_own: Vector3 = _vertical_cylinder_inertia(sailor.mass_kg, sailor.torso_radius_m, sailor.height_m)
	var rig_own: Vector3 = Vector3(
		sail.rig_mass_kg * sail.mast_m * sail.mast_m / 12.0,  # a thin vertical rod
		sail.rig_mass_kg * 0.3 * 0.3,  # the sail spreads about 0.3 m from the mast on average
		sail.rig_mass_kg * sail.mast_m * sail.mast_m / 12.0)

	inertia_body = Basis.IDENTITY.scaled(Vector3.ZERO)
	inertia_body = _add_part(inertia_body, board.mass_kg, board_own, board_position_body - com_offset_body)
	inertia_body = _add_part(inertia_body, sailor.mass_kg, sailor_own, sailor_position_body - com_offset_body)
	inertia_body = _add_part(inertia_body, sail.rig_mass_kg, rig_own, rig_position_body - com_offset_body)


## Maximum righting moment the sailor can produce by leaning: weight times full lean.
func max_righting_moment_nm(gravity_ms2: float) -> float:
	return sailor.mass_kg * gravity_ms2 * sailor.lean_max_m


## Diagonal inertia of a box with sides (size_x, size_y, size_z) about its centre.
static func _box_inertia(mass: float, size_x: float, size_y: float, size_z: float) -> Vector3:
	return Vector3(
		mass / 12.0 * (size_y * size_y + size_z * size_z),
		mass / 12.0 * (size_x * size_x + size_z * size_z),
		mass / 12.0 * (size_x * size_x + size_y * size_y))


## Diagonal inertia of a cylinder standing upright (axis along y) about its centre.
static func _vertical_cylinder_inertia(mass: float, radius: float, height: float) -> Vector3:
	var across: float = mass / 12.0 * (3.0 * radius * radius + height * height)
	return Vector3(across, 0.5 * mass * radius * radius, across)


## Adds one part to a tensor with the parallel axis theorem:
## I += I_own + m * ((d . d) * E - d (x) d), where d is the part's offset from the centre of mass.
static func _add_part(tensor: Basis, mass: float, own_diagonal: Vector3, d: Vector3) -> Basis:
	var dd: float = d.dot(d)
	var columns: Array[Vector3] = [tensor.x, tensor.y, tensor.z]
	var axes: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	for j: int in 3:
		var column: Vector3 = columns[j] + mass * (dd * axes[j] - d * d[j])
		column[j] += own_diagonal[j]
		columns[j] = column
	return Basis(columns[0], columns[1], columns[2])
