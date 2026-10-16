class_name WindsurferNode
extends Node3D
## The windsurfer in the scene. Owns a WindsurferSim, steps it once per physics tick with
## the player's (or the autopilot's) controls, and copies the result onto simple visuals:
## a box for the board, a fin, a mast, a sail that turns with the sheet, the rake and the
## rig lean, and a sailor built from the simulation's own sailor body (section 7.5): the
## feet where they press the deck, two-segment legs that bend at the knee as the legs
## give, the hips at the body's centre of mass, a torso along the body line, arms to the
## hands on the boom, a head, and the harness line from the hips to the boom when the
## sailor hangs in it. Nothing visual feeds back into the physics (CLAUDE.md, rule 2).

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

## The fall takes this long on screen (the physics has already let go).
const FALL_DURATION_S: float = 0.9

var _previous_state: WindsurferSim.SailorState = WindsurferSim.SailorState.SAILING
# The pose at the last sailing tick, from which a fall starts.
var _last_mast_dir: Vector3 = Vector3.UP
var _last_boom_dir: Vector3 = Vector3.BACK
var _last_feet: Vector3 = Vector3(0.0, 0.06, 0.15)

## Body sizes for the figure (metres).
const FOOT_LENGTH_M: float = 0.26
const ANKLE_HEIGHT_M: float = 0.08
const THIGH_M: float = 0.45
const SHIN_M: float = 0.45
const TORSO_M: float = 0.5
const HEAD_M: float = 0.24
const FEET_APART_M: float = 0.4
const HANDS_APART_M: float = 0.6

var _board: MeshInstance3D
var _nose: MeshInstance3D
var _fin: MeshInstance3D
var _mast: MeshInstance3D
var _sail: MeshInstance3D
var _boom: MeshInstance3D
## The figure: a root the fall animates, and its limbs posed from the simulation.
var _sailor_root: Node3D
var _foot_front: MeshInstance3D
var _foot_back: MeshInstance3D
var _shin_front: MeshInstance3D
var _shin_back: MeshInstance3D
var _thigh_front: MeshInstance3D
var _thigh_back: MeshInstance3D
var _torso: MeshInstance3D
var _arm_front: MeshInstance3D
var _arm_back: MeshInstance3D
var _head: MeshInstance3D
var _harness_line: MeshInstance3D


func _ready() -> void:
	sim = WindsurferSim.create_default(true)
	controller.set_sail(sim.sail, sim.sailor_config)
	autopilot.sail = sim.sail
	_build_visuals()
	reset()


## Puts the board back at the start, at rest.
func reset() -> void:
	controls = SimControls.new()
	controller.reset_controls(controls)
	sim.reset(Vector3.ZERO, deg_to_rad(start_heading_deg))
	_previous_state = sim.sailor_state
	autopilot.target_twa_deg = autopilot_twa_deg
	_copy_state_to_visuals()
	reset_physics_interpolation()


## Skips the rest of the time in the water.
func waterstart_now() -> void:
	if sim.sailor_state == WindsurferSim.SailorState.FALLEN:
		sim.waterstart()
		_after_waterstart()


func is_fallen() -> bool:
	return sim.sailor_state == WindsurferSim.SailorState.FALLEN


func _physics_process(delta: float) -> void:
	if sim.sailor_state == WindsurferSim.SailorState.SAILING:
		if use_autopilot:
			autopilot.update(sim.telemetry, controls, delta)
		else:
			controller.update(sim.telemetry, controls, delta)
	sim.step(delta, controls)
	if sim.sailor_state == WindsurferSim.SailorState.SAILING and _previous_state == WindsurferSim.SailorState.FALLEN:
		_after_waterstart()
	_previous_state = sim.sailor_state
	_copy_state_to_visuals()


func _after_waterstart() -> void:
	controller.reset_controls(controls)
	_previous_state = sim.sailor_state
	_copy_state_to_visuals()
	reset_physics_interpolation()


func telemetry() -> Telemetry:
	return sim.telemetry


## The board's transform, smoothed between physics ticks, for cameras.
func interpolated_transform() -> Transform3D:
	return get_global_transform_interpolated()


func _copy_state_to_visuals() -> void:
	var body: SimRigidBody = sim.body
	global_transform = Transform3D(body.basis, body.origin_world())
	if sim.sailor_state == WindsurferSim.SailorState.FALLEN:
		_pose_fallen()
		return

	# The rig: mast from the mast foot along the mast direction, sail and boom in the plane
	# of the mast and the boom. The simulation holds the rig in the sailor's frame, not the
	# deck's (RigFrame), so its directions are brought into the board's axes here.
	var rig_to_board: Basis = body.basis.transposed() * sim.rig.basis
	var mast_dir: Vector3 = rig_to_board * sim.sail.mast_direction()
	var boom_angle: float = sim.sail.sail_angle_rad()
	var boom_dir: Vector3 = rig_to_board * Vector3(sin(boom_angle), 0.0, cos(boom_angle))
	_pose_rig(mast_dir, boom_dir)

	_sailor_root.transform = Transform3D.IDENTITY
	_pose_sailor(boom_dir)

	_last_mast_dir = mast_dir
	_last_boom_dir = boom_dir
	_last_feet = sim.feet_body


## The figure, in the board's own axes, from the simulation's sailor body: the hips at the
## centre of mass, the feet where they press the deck (the front foot forward of the
## stance point, the back foot behind it), the knees bent as far as the legs have given,
## the torso along the body line, the hands on the boom either side of the grip.
func _pose_sailor(boom_dir: Vector3) -> void:
	var body: SimRigidBody = sim.body
	var hips: Vector3 = SimMath.to_body(body.basis, sim.sailor.position - body.origin_world())
	var feet: Vector3 = sim.feet_body
	var foot_front: Vector3 = feet + Vector3(0.0, 0.0, -0.5 * FEET_APART_M)
	var foot_back: Vector3 = feet + Vector3(0.0, 0.0, 0.5 * FEET_APART_M)
	var grip: Vector3 = sim.hand_grip_body
	# The sailor faces the sail: the knees bend toward the boom.
	var facing: Vector3 = grip - hips
	facing.y = 0.0
	if facing.length() < 0.1:
		facing = Vector3(-float(sim.sail.sail_side), 0.0, 0.0) * -1.0
	facing = facing.normalized()

	# Feet: flat on the deck, pointing across the board toward the sail.
	var foot_basis: Basis = Basis(facing, Vector3.UP, facing.cross(Vector3.UP))
	_foot_front.transform = Transform3D(foot_basis, foot_front + Vector3(0.0, 0.03, 0.0) + facing * (0.3 * FOOT_LENGTH_M))
	_foot_back.transform = Transform3D(foot_basis, foot_back + Vector3(0.0, 0.03, 0.0) + facing * (0.3 * FOOT_LENGTH_M))

	# Legs: two segments from the ankle to the hips, the knee out toward the sail.
	_pose_leg(_shin_front, _thigh_front, foot_front + Vector3(0.0, ANKLE_HEIGHT_M, 0.0), hips, facing)
	_pose_leg(_shin_back, _thigh_back, foot_back + Vector3(0.0, ANKLE_HEIGHT_M, 0.0), hips, facing)

	# Torso along the body line (feet to hips, carried on), head above it.
	var body_line: Vector3 = (hips - feet).normalized()
	var shoulders: Vector3 = hips + body_line * TORSO_M
	_segment(_torso, hips, shoulders)
	_head.position = shoulders + body_line * (0.5 * HEAD_M + 0.05)

	# Arms from the shoulders to the hands on the boom, either side of the grip.
	var shoulder_front: Vector3 = shoulders - boom_dir * 0.18
	var shoulder_back: Vector3 = shoulders + boom_dir * 0.18
	_segment(_arm_front, shoulder_front, grip - boom_dir * (0.5 * HANDS_APART_M))
	_segment(_arm_back, shoulder_back, grip + boom_dir * (0.5 * HANDS_APART_M))

	# The harness line, from the hips to the boom, drawn when the sailor hangs in it.
	_harness_line.visible = sim.harness_tension_n > 20.0
	if _harness_line.visible:
		_segment(_harness_line, hips, grip)


## A leg from the ankle to the hip with the knee where a thigh and a shin of fixed length
## meet, bulged out along `bend_dir` when the leg is shorter than straight.
func _pose_leg(shin: MeshInstance3D, thigh: MeshInstance3D, ankle: Vector3, hip: Vector3, bend_dir: Vector3) -> void:
	var leg: Vector3 = hip - ankle
	var length: float = minf(leg.length(), THIGH_M + SHIN_M - 0.01)
	var along: Vector3 = leg.normalized()
	var side: Vector3 = bend_dir - along * bend_dir.dot(along)
	if side.length() < 0.05:
		side = Vector3.FORWARD - along * Vector3.FORWARD.dot(along)
	side = side.normalized()
	# With the thigh and the shin equal, the knee sits halfway along the leg line, out by
	# the height of the isosceles triangle.
	var half: float = 0.5 * length
	var out: float = sqrt(maxf(THIGH_M * THIGH_M - half * half, 0.0))
	var knee: Vector3 = ankle + along * half + side * out
	_segment(shin, ankle, knee)
	_segment(thigh, knee, hip)


## Lays a unit-height cylinder between two points.
func _segment(node: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	var length: float = maxf((to - from).length(), 0.01)
	var basis: Basis = _basis_with_up(to - from)
	node.transform = Transform3D(basis.scaled(Vector3(1.0, length, 1.0)), 0.5 * (from + to))


## Mast and sail from the mast foot, both directions in the board's axes.
func _pose_rig(mast_dir: Vector3, boom_dir: Vector3) -> void:
	var sail_config: SailConfig = sim.sail_config
	var foot: Vector3 = sail_config.mast_foot_local
	_mast.transform = Transform3D(_basis_with_up(mast_dir), foot + mast_dir * (0.5 * sail_config.mast_m))
	var sail_normal: Vector3 = boom_dir.cross(mast_dir)
	if sail_normal.length() < 0.05:
		sail_normal = Vector3.UP
	_sail.transform = Transform3D(Basis(boom_dir, mast_dir, sail_normal.normalized()), foot)


## The fall on screen: the rig pivots about the mast foot until it lies on the water on the
## side of the fall, and the sailor goes with it: over the sail in a catapult (landing
## beyond the mast top), or backwards beside the board when falling to windward.
func _pose_fallen() -> void:
	var progress: float = clampf(sim.fallen_for_s / FALL_DURATION_S, 0.0, 1.0)
	var eased: float = progress * progress  # a fall picks up speed
	var side: float = float(sim.fall_side)
	var flat: Vector3 = Vector3(side, 0.03, 0.0).normalized()
	var mast_dir: Vector3 = _last_mast_dir.slerp(flat, eased).normalized()
	_pose_rig(mast_dir, _last_boom_dir)

	# The figure keeps its last pose and goes over as one: pivoting about the feet onto
	# its side, carried toward the landing with a little arc.
	var over: bool = sim.fall_kind == "catapult" or sim.fall_kind == "tipped over"
	var reach: float = sim.sail_config.mast_m + 1.0 if over else 1.8
	var landing: Vector3 = Vector3(side * reach, -0.9, 0.0)
	var arc: float = (1.5 if over else 0.3) * sin(PI * eased)
	var pivot: Vector3 = _last_feet
	var tip: Basis = Basis(Vector3.BACK, -side * eased * 0.5 * PI)
	var carried: Vector3 = landing * eased + Vector3(0.0, arc, 0.0)
	_sailor_root.transform = Transform3D(tip, pivot - tip * pivot + carried)


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

	_sailor_root = Node3D.new()
	_sailor_root.name = "Sailor"
	add_child(_sailor_root)
	var suit: Color = Color(0.12, 0.12, 0.14)
	var skin: Color = Color(0.85, 0.65, 0.5)
	_foot_front = _add_box("FootFront", Vector3(FOOT_LENGTH_M, 0.06, 0.1), Vector3.ZERO, Color(0.05, 0.05, 0.05), _sailor_root)
	_foot_back = _add_box("FootBack", Vector3(FOOT_LENGTH_M, 0.06, 0.1), Vector3.ZERO, Color(0.05, 0.05, 0.05), _sailor_root)
	_shin_front = _add_limb("ShinFront", 0.055, suit)
	_shin_back = _add_limb("ShinBack", 0.055, suit)
	_thigh_front = _add_limb("ThighFront", 0.07, suit)
	_thigh_back = _add_limb("ThighBack", 0.07, suit)
	_torso = _add_limb("Torso", 0.9 * sailor_config.torso_radius_m, Color(0.75, 0.15, 0.1))
	_arm_front = _add_limb("ArmFront", 0.04, suit)
	_arm_back = _add_limb("ArmBack", 0.04, suit)
	_harness_line = _add_limb("HarnessLine", 0.008, Color(0.2, 0.2, 0.2))
	_head = MeshInstance3D.new()
	_head.name = "Head"
	var skull: SphereMesh = SphereMesh.new()
	skull.radius = 0.5 * HEAD_M
	skull.height = HEAD_M
	_head.mesh = skull
	_head.material_override = _material(skin)
	_sailor_root.add_child(_head)


## A unit-height cylinder for a limb; _segment() stretches it between two points.
func _add_limb(node_name: String, radius: float, color: Color) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.height = 1.0
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	instance.mesh = cylinder
	instance.material_override = _material(color)
	_sailor_root.add_child(instance)
	return instance


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
