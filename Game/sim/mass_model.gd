class_name MassModel
extends RefCounted
## Mass, centre of mass and inertia of the windsurfer (PHYSICS_SPEC.md section 7). The
## sailor's posture (stance fore and aft, lean sideways, hang-back, knee bend) decides where
## the sailor's centre of mass is; the rig's lean decides where the rig's is.
##
## The simulation's rigid body is the hull alone (hull_mass_kg, hull_inertia_body): the
## sailor is a body of their own on the legs, and the rig is held between the mast foot and
## the hands (section 7.5). The composite figures (total_mass_kg, com_offset_body,
## inertia_body) describe the whole as if it were rigid: they set the hull's resting depth,
## the planing ratio, and the heeling moment the autopilot trims to.
##
## All positions are in body axes relative to the board origin (the centre of the hull box):
## x = starboard, y = up, z = aft.
##
## Boards on threads (F1 no_wait): reading a field of another object, as sailor.mass_kg, takes
## a global engine lock, and boards stepped side by side on worker threads wait for each other
## there. update() runs every substep, so it and feet_position_body() use copies of the
## configs' numbers kept in this model's own fields, taken by copy_config(): when the model is
## made and at the start of every tick (WindsurferSim.step). The configs are never changed
## inside a tick, so the copies are their numbers.

var board: BoardConfig
var sail: SailConfig
var sailor: SailorConfig

## The configs' numbers that update() and feet_position_body() use (copy_config()).
var _board_mass_kg: float = 0.0
var _board_width_m: float = 0.0
var _board_thickness_m: float = 0.0
var _board_length_m: float = 0.0
var _mast_foot_local: Vector3 = Vector3.ZERO
var _rig_mass_kg: float = 0.0
var _rig_com_height_m: float = 0.0
var _mast_m: float = 0.0
var _sailor_mass_kg: float = 0.0
var _lean_max_m: float = 0.0
var _com_height_m: float = 0.0
var _lean_height_drop_m: float = 0.0
var _stance_rest_z_m: float = 0.0
var _stance_planing_z_m: float = 0.0
var _stance_tack_z_m: float = 0.0
var _torso_radius_m: float = 0.0
var _sailor_height_m: float = 0.0
var _feet_out_from_lean: float = 0.0
var _feet_out_full_lean: float = 0.0
var _feet_rail_m: float = 0.0
var _rail_step_m: float = 0.0

## Results of the last update().
var total_mass_kg: float = 0.0
var com_offset_body: Vector3 = Vector3.ZERO
var inertia_body: Basis = Basis.IDENTITY
var sailor_position_body: Vector3 = Vector3.ZERO
var rig_position_body: Vector3 = Vector3.ZERO
## The hull alone: what the simulation's rigid body is.
var hull_mass_kg: float = 0.0
var hull_inertia_body: Basis = Basis.IDENTITY


func _init(board_config: BoardConfig, sail_config: SailConfig, sailor_config: SailorConfig) -> void:
	board = board_config
	sail = sail_config
	sailor = sailor_config
	copy_config()
	hull_mass_kg = board.mass_kg
	hull_inertia_body = Basis.IDENTITY.scaled(_box_inertia(board.mass_kg, board.width_m, board.thickness_m, board.length_m))
	update(0.0, 0.0)


## Copies the configs' numbers that update() and feet_position_body() use into this model's
## own (see the note at the top).
func copy_config() -> void:
	_board_mass_kg = board.mass_kg
	_board_width_m = board.width_m
	_board_thickness_m = board.thickness_m
	_board_length_m = board.length_m
	_mast_foot_local = sail.mast_foot_local
	_rig_mass_kg = sail.rig_mass_kg
	_rig_com_height_m = sail.rig_com_height_m
	_mast_m = sail.mast_m
	_sailor_mass_kg = sailor.mass_kg
	_lean_max_m = sailor.lean_max_m
	_com_height_m = sailor.com_height_m
	_lean_height_drop_m = sailor.lean_height_drop_m
	_stance_rest_z_m = sailor.stance_rest_z_m
	_stance_planing_z_m = sailor.stance_planing_z_m
	_stance_tack_z_m = sailor.stance_tack_z_m
	_torso_radius_m = sailor.torso_radius_m
	_sailor_height_m = sailor.height_m
	_feet_out_from_lean = sailor.feet_out_from_lean
	_feet_out_full_lean = sailor.feet_out_full_lean
	_feet_rail_m = sailor.feet_rail_m
	_rail_step_m = sailor.rail_step_m


## stance: 0 = feet near the mast foot, 1 = feet in the back straps, -1 = round the front of
## the mast (a tack).
## lean: -1 = sailor fully out to port, +1 = fully out to starboard, 0 = upright.
## hang_back_m: how far the sailor's weight hangs behind the feet against the sail's pull.
## knee_bend_m: how far the knees have flexed; positive lowers the sailor's body.
## rig_lean_rad: how far the rig leans sideways (positive toward starboard); its mass goes
## with it, which is part of what a sailor hanging the rig to windward gains.
func update(stance: float, lean: float, hang_back_m: float = 0.0, knee_bend_m: float = 0.0, rig_lean_rad: float = 0.0) -> void:
	stance = clampf(stance, -1.0, 1.0)
	lean = clampf(lean, -1.0, 1.0)
	sailor_position_body = Vector3(
		lean * _lean_max_m,
		_com_height_m - absf(lean) * _lean_height_drop_m - knee_bend_m,
		(lerpf(_stance_rest_z_m, _stance_planing_z_m, stance) if stance >= 0.0 else lerpf(_stance_rest_z_m, _stance_tack_z_m, -stance)) + hang_back_m)
	rig_position_body = _mast_foot_local + Vector3(sin(rig_lean_rad) * _rig_com_height_m, cos(rig_lean_rad) * _rig_com_height_m, 0.0)
	var board_position_body: Vector3 = Vector3.ZERO

	total_mass_kg = _board_mass_kg + _rig_mass_kg + _sailor_mass_kg
	com_offset_body = (_board_mass_kg * board_position_body
		+ _rig_mass_kg * rig_position_body
		+ _sailor_mass_kg * sailor_position_body) / total_mass_kg

	# Own inertia of each part about its own centre, in body axes (x across, y up, z along).
	var board_own: Vector3 = _box_inertia(_board_mass_kg, _board_width_m, _board_thickness_m, _board_length_m)
	var sailor_own: Vector3 = _vertical_cylinder_inertia(_sailor_mass_kg, _torso_radius_m, _sailor_height_m)
	var rig_own: Vector3 = Vector3(
		_rig_mass_kg * _mast_m * _mast_m / 12.0,  # a thin vertical rod
		_rig_mass_kg * 0.3 * 0.3,  # the sail spreads about 0.3 m from the mast on average
		_rig_mass_kg * _mast_m * _mast_m / 12.0)

	inertia_body = Basis.IDENTITY.scaled(Vector3.ZERO)
	inertia_body = _add_part(inertia_body, _board_mass_kg, board_own, board_position_body - com_offset_body)
	inertia_body = _add_part(inertia_body, _sailor_mass_kg, sailor_own, sailor_position_body - com_offset_body)
	inertia_body = _add_part(inertia_body, _rig_mass_kg, rig_own, rig_position_body - com_offset_body)


## Where the feet press the deck for a stance, a lean and a rail press, body axes: on the
## centreline up to feet_out_from_lean, out on the windward rail (feet_rail_m) from
## feet_out_full_lean on, shifted toward the pressed rail by the rail press (rail_step_m,
## never beyond the rails), at the stance's fore-and-aft position (the hang-back moves
## the body, not the feet).
func feet_position_body(stance: float, lean: float, rail_press: float = 0.0, trim_press_m: float = 0.0) -> Vector3:
	stance = clampf(stance, -1.0, 1.0)
	var feet_z: float = (lerpf(_stance_rest_z_m, _stance_planing_z_m, stance) if stance >= 0.0 else lerpf(_stance_rest_z_m, _stance_tack_z_m, -stance)) + trim_press_m
	var out: float = smoothstep(_feet_out_from_lean, _feet_out_full_lean, absf(lean))
	var standing_x: float = _feet_rail_m * out * signf(lean)
	var press: float = clampf(rail_press, -1.0, 1.0)
	var feet_x: float = lerpf(standing_x, _rail_step_m * signf(press), absf(press))
	return Vector3(feet_x, 0.5 * _board_thickness_m, feet_z)


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
## Column by column (x, y, z), without making Arrays: making one takes the engine's lock too.
static func _add_part(tensor: Basis, mass: float, own_diagonal: Vector3, d: Vector3) -> Basis:
	var dd: float = d.dot(d)
	var column_x: Vector3 = tensor.x + mass * (dd * Vector3.RIGHT - d * d[0])
	column_x[0] += own_diagonal[0]
	var column_y: Vector3 = tensor.y + mass * (dd * Vector3.UP - d * d[1])
	column_y[1] += own_diagonal[1]
	var column_z: Vector3 = tensor.z + mass * (dd * Vector3.BACK - d * d[2])
	column_z[2] += own_diagonal[2]
	return Basis(column_x, column_y, column_z)
