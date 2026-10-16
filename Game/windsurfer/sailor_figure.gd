class_name SailorFigure
extends Node3D
## The sailor you see: a figure posed every physics tick from the simulation's own sailor
## body (PHYSICS_SPEC.md section 7.5). The feet stand where they press the deck, the hips
## are at the body's centre of mass, two-segment legs bend at the knee as the legs give,
## the torso runs along the body line, the arms go to the hands on the boom either side
## of the grip, and the harness line is drawn from the hips to the boom when the sailor
## hangs in it. It only draws: nothing here feeds back into the physics (CLAUDE.md, rule 2).
##
## Everything is in the board's own axes (x starboard, y up, z aft; the bow is -z), because
## the figure is a child of the windsurfer node, which carries the board's transform.

## Body sizes for the figure (metres).
const FOOT_LENGTH_M: float = 0.26
const ANKLE_HEIGHT_M: float = 0.08
const THIGH_M: float = 0.45
const SHIN_M: float = 0.45
const TORSO_M: float = 0.5
const HEAD_M: float = 0.24
const FEET_APART_M: float = 0.4
const HANDS_APART_M: float = 0.6

## The figure's root, which the fall animates, and its limbs posed from the simulation.
var _root: Node3D
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

# Where the feet were at the last sailing tick: the pivot of a fall.
var _last_feet: Vector3 = Vector3(0.0, 0.06, 0.15)


## Builds the figure's parts.
func build(sailor_config: SailorConfig) -> void:
	_root = Node3D.new()
	_root.name = "Sailor"
	add_child(_root)
	var suit: Color = Color(0.12, 0.12, 0.14)
	var skin: Color = Color(0.85, 0.65, 0.5)
	_foot_front = VisualMath.add_box(_root, "FootFront", Vector3(FOOT_LENGTH_M, 0.06, 0.1), Vector3.ZERO, Color(0.05, 0.05, 0.05))
	_foot_back = VisualMath.add_box(_root, "FootBack", Vector3(FOOT_LENGTH_M, 0.06, 0.1), Vector3.ZERO, Color(0.05, 0.05, 0.05))
	_shin_front = VisualMath.add_limb(_root, "ShinFront", 0.055, suit)
	_shin_back = VisualMath.add_limb(_root, "ShinBack", 0.055, suit)
	_thigh_front = VisualMath.add_limb(_root, "ThighFront", 0.07, suit)
	_thigh_back = VisualMath.add_limb(_root, "ThighBack", 0.07, suit)
	_torso = VisualMath.add_limb(_root, "Torso", 0.9 * sailor_config.torso_radius_m, Color(0.75, 0.15, 0.1))
	_arm_front = VisualMath.add_limb(_root, "ArmFront", 0.04, suit)
	_arm_back = VisualMath.add_limb(_root, "ArmBack", 0.04, suit)
	_harness_line = VisualMath.add_limb(_root, "HarnessLine", 0.008, Color(0.2, 0.2, 0.2))
	_head = MeshInstance3D.new()
	_head.name = "Head"
	var skull: SphereMesh = SphereMesh.new()
	skull.radius = 0.5 * HEAD_M
	skull.height = HEAD_M
	_head.mesh = skull
	_head.material_override = VisualMath.plain_material(skin)
	_root.add_child(_head)


## The figure while sailing, from the simulation's sailor body: the hips at the centre of
## mass, the feet where they press the deck (the front foot forward of the stance point,
## the back foot behind it), the knees bent as far as the legs have given, the torso along
## the body line, the hands on the boom either side of the grip. `boom_dir` is the boom's
## direction from the mast in the board's axes (a unit vector).
func pose_sailing(sim: WindsurferSim, boom_dir: Vector3) -> void:
	_root.transform = Transform3D.IDENTITY
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
	VisualMath.lay_segment(_torso, hips, shoulders)
	_head.position = shoulders + body_line * (0.5 * HEAD_M + 0.05)

	# Arms from the shoulders to the hands on the boom, either side of the grip.
	var shoulder_front: Vector3 = shoulders - boom_dir * 0.18
	var shoulder_back: Vector3 = shoulders + boom_dir * 0.18
	VisualMath.lay_segment(_arm_front, shoulder_front, grip - boom_dir * (0.5 * HANDS_APART_M))
	VisualMath.lay_segment(_arm_back, shoulder_back, grip + boom_dir * (0.5 * HANDS_APART_M))

	# The harness line, from the hips to the boom, drawn when the sailor hangs in it.
	_harness_line.visible = sim.harness_tension_n > 20.0
	if _harness_line.visible:
		VisualMath.lay_segment(_harness_line, hips, grip)

	_last_feet = feet


## The fall on screen: the figure keeps its last pose and goes over as one, pivoting about
## its feet onto its side, carried toward the landing with a little arc: over the sail in
## a catapult (landing beyond the mast top), or backwards beside the board when falling to
## windward. `eased` runs from 0 to 1 as the fall progresses.
func pose_fallen(sim: WindsurferSim, eased: float) -> void:
	var side: float = float(sim.fall_side)
	var over: bool = sim.fall_kind == "catapult" or sim.fall_kind == "tipped over"
	var reach: float = sim.sail_config.mast_m + 1.0 if over else 1.8
	var landing: Vector3 = Vector3(side * reach, -0.9, 0.0)
	var arc: float = (1.5 if over else 0.3) * sin(PI * eased)
	var pivot: Vector3 = _last_feet
	var tip: Basis = Basis(Vector3.BACK, -side * eased * 0.5 * PI)
	var carried: Vector3 = landing * eased + Vector3(0.0, arc, 0.0)
	_root.transform = Transform3D(tip, pivot - tip * pivot + carried)


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
	VisualMath.lay_segment(shin, ankle, knee)
	VisualMath.lay_segment(thigh, knee, hip)
