class_name SailorFigure
extends Node3D
## The sailor you see. Every physics tick FigureSkeleton (figure_skeleton.gd) works out the
## joints from the simulation's sailor body (PHYSICS_SPEC.md section 7.5): the hips at the
## centre of mass, the feet where they stand, the hands on the boom, with bones of fixed
## length and knees and elbows that bend like real ones. This script builds the body parts
## once and lays them on those joints. It only draws: nothing here feeds back into the
## physics (CLAUDE.md, rule 2).
##
## The limbs are capsules (a cylinder with round ends) of their bone's length, laid from
## joint to joint and never scaled, so they cannot stretch; their round ends make the bends
## at the knees and the elbows look continuous.
##
## The torso is one body: three tapered tubes (belly, ribs, chest) laid end to end along one
## smooth curve of the spine from the pelvis to the shoulders (FigureSkeleton.spine_point),
## turning gradually from the hips' line to the shoulders' line, with a ball at each joint
## between them (as at the knees) so the bends stay closed, a bar across the shoulders and
## the harness belt round the bottom of the belly. A torso is wider than it is deep, so these
## parts are stretched sideways by TORSO_WIDTH.
##
## Everything is in the board's own axes (x starboard, y up, z aft; the bow is -z), because
## the figure is a child of the windsurfer node, which carries the board's transform.

const WETSUIT: Color = Color(0.07, 0.08, 0.1)
const LYCRA: Color = Color(0.85, 0.13, 0.1)
const SKIN: Color = Color(0.86, 0.66, 0.52)
const BOOTIE: Color = Color(0.04, 0.04, 0.045)
const SOLE: Color = Color(0.45, 0.45, 0.48)
const HARNESS: Color = Color(0.16, 0.2, 0.3)
const HOOK: Color = Color(0.8, 0.8, 0.82)
const CAP: Color = Color(0.98, 0.78, 0.12)
const GLASSES: Color = Color(0.02, 0.02, 0.03)
const LINE: Color = Color(0.1, 0.1, 0.1)

## The torso's pieces along the spine (t = 0 at the pelvis, 1 at the shoulder line): piece
## i runs from TORSO_STATIONS_T[i] to TORSO_STATIONS_T[i + 1], tapering from the radius at
## one station to the next (half the body's depth, front to back, m: a narrow waist, a full
## chest). The chest stops below the shoulder line so that the ball on its top makes the
## top of the shoulders.
const TORSO_NAMES: Array[String] = ["Belly", "Ribs", "Chest"]
const TORSO_STATIONS_T: Array[float] = [0.0, 0.38, 0.68, 0.84]
const TORSO_RADII_M: Array[float] = [0.105, 0.1, 0.118, 0.115]
## How much wider than deep the torso is (a man's chest is about 0.33 m wide and 0.23 m
## deep, his waist about 0.29 m by 0.2 m).
const TORSO_WIDTH: float = 1.42
## The harness belt: around the belly this far up the spine, this much bigger than the belly
## all round, m, and this tall, m.
const BELT_T: float = 0.1
const BELT_MARGIN_M: float = 0.02
const BELT_HEIGHT_M: float = 0.11
## The bar across the shoulders, between the two shoulder balls: its radius, m.
const SHOULDER_BAR_RADIUS_M: float = 0.062

## The skeleton the figure is posed from (public so the tests can measure it).
var skeleton: FigureSkeleton

## The figure's root, which the fall animates, and its parts.
var _root: Node3D
var _pelvis: MeshInstance3D
var _torso: Array[MeshInstance3D] = []
var _torso_joints: Array[MeshInstance3D] = []
var _shoulder_bar: MeshInstance3D
var _neck: MeshInstance3D
var _head: Node3D
var _harness: MeshInstance3D
var _hook: MeshInstance3D
var _harness_lines: Array[MeshInstance3D] = []
var _thighs: Array[MeshInstance3D] = []
var _shins: Array[MeshInstance3D] = []
var _knees: Array[MeshInstance3D] = []
var _feet: Array[Node3D] = []
var _upper_arms: Array[MeshInstance3D] = []
var _forearms: Array[MeshInstance3D] = []
var _shoulder_balls: Array[MeshInstance3D] = []
var _hands: Array[MeshInstance3D] = []

# Where the feet were at the last sailing tick: the pivot of a fall.
var _last_feet: Vector3 = Vector3(0.0, 0.06, 0.15)


## Builds the figure's parts for a sailor of this height.
func build(sailor_config: SailorConfig) -> void:
	skeleton = FigureSkeleton.new(sailor_config.height_m)
	_root = Node3D.new()
	_root.name = "Sailor"
	add_child(_root)
	var s: FigureSkeleton = skeleton
	_pelvis = _add_capsule("Pelvis", 0.1, 2.0 * s.hip_half_m, WETSUIT)
	for piece: int in TORSO_NAMES.size():
		_torso.append(_add_tube(TORSO_NAMES[piece], TORSO_RADII_M[piece], TORSO_RADII_M[piece + 1], _torso_piece_length_m(piece), LYCRA))
	for station: int in TORSO_STATIONS_T.size():
		# The ball at the bottom is in the shorts, under the harness belt.
		var color: Color = WETSUIT if station == 0 else LYCRA
		_torso_joints.append(_add_sphere("TorsoJoint%d" % station, TORSO_RADII_M[station], color))
	_shoulder_bar = _add_capsule("Shoulders", SHOULDER_BAR_RADIUS_M, 2.0 * s.shoulder_half_m, LYCRA)
	_neck = _add_capsule("Neck", 0.05, 0.6 * s.neck_m, SKIN)
	_harness = _add_belt()
	_hook = _add_box("Hook", Vector3(0.12, 0.035, 0.05), HOOK)
	_head = _build_head()
	for side: int in [FigureSkeleton.LEFT, FigureSkeleton.RIGHT]:
		var label: String = "Left" if side == FigureSkeleton.LEFT else "Right"
		_thighs.append(_add_capsule("Thigh" + label, 0.075, s.thigh_m, WETSUIT))
		_shins.append(_add_capsule("Shin" + label, 0.055, s.shin_m, WETSUIT))
		_knees.append(_add_sphere("Knee" + label, 0.062, WETSUIT))
		_feet.append(_build_foot("Foot" + label))
		_upper_arms.append(_add_capsule("UpperArm" + label, 0.045, s.upper_arm_m, WETSUIT))
		_forearms.append(_add_capsule("Forearm" + label, 0.037, s.forearm_m, WETSUIT))
		_shoulder_balls.append(_add_sphere("Shoulder" + label, 0.068, LYCRA))
		_hands.append(_add_sphere("Hand" + label, 0.045, SKIN))
		var line: MeshInstance3D = VisualMath.add_limb(_root, "HarnessLine" + label, 0.007, LINE)
		_harness_lines.append(line)


## The figure while sailing, from the simulation's sailor body. `boom_dir` is the boom's
## direction from the mast in the board's axes (a unit vector); `grip_offset` moves the
## hands from the boom's centre line onto the windward arm of the wishbone (zero without a rig).
func pose_sailing(sim: WindsurferSim, boom_dir: Vector3, grip_offset: Vector3 = Vector3.ZERO) -> void:
	_root.transform = Transform3D.IDENTITY
	var s: FigureSkeleton = skeleton
	s.grip_offset_body = grip_offset
	s.solve(sim, boom_dir)

	# The pelvis lies across the hips; the torso follows the spine up to the shoulders.
	_place_between(_pelvis, s.hips[FigureSkeleton.LEFT], s.hips[FigureSkeleton.RIGHT])
	_place_torso(s)
	_place_between(_shoulder_bar, s.shoulders[FigureSkeleton.LEFT], s.shoulders[FigureSkeleton.RIGHT])
	_place_from(_neck, s.neck, s.head, 0.6 * s.neck_m)
	_head.transform = Transform3D(s.head_basis, s.head)
	var belt_basis: Basis = s.spine_basis(0.0, TORSO_STATIONS_T[1])
	_harness.transform = Transform3D(_wider(belt_basis), s.spine_point(BELT_T))
	var hook_basis: Basis = s.pelvis_basis
	_hook.transform = Transform3D(hook_basis, s.hook)

	for side: int in [FigureSkeleton.LEFT, FigureSkeleton.RIGHT]:
		_place_from(_thighs[side], s.hips[side], s.knees[side], s.thigh_m)
		_place_from(_shins[side], s.knees[side], s.ankles[side], s.shin_m)
		_knees[side].position = s.knees[side]
		_pose_foot(_feet[side], s.ankles[side] - Vector3.UP * s.ankle_height_m, s.foot_dirs[side])
		_place_from(_upper_arms[side], s.shoulders[side], s.elbows[side], s.upper_arm_m)
		_place_from(_forearms[side], s.elbows[side], s.wrists[side], s.forearm_m)
		_shoulder_balls[side].position = s.shoulders[side]
		_hands[side].position = s.hands[side]
		# The harness lines: from the hook to the boom, taut while the sailor hangs in them.
		_harness_lines[side].visible = s.hooked
		if s.hooked:
			VisualMath.lay_segment(_harness_lines[side], s.hook, s.harness_line_ends[side])
	_last_feet = s.feet_centre


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
	_harness_lines[0].visible = false
	_harness_lines[1].visible = false


## The torso's pieces, each laid from station to station on the spine's curve and turned
## with it, and the balls at the stations.
func _place_torso(s: FigureSkeleton) -> void:
	for piece: int in _torso.size():
		var t_from: float = TORSO_STATIONS_T[piece]
		var t_to: float = TORSO_STATIONS_T[piece + 1]
		var bottom: Vector3 = s.spine_point(t_from)
		var top: Vector3 = s.spine_point(t_to)
		# An arched back makes the curve a few millimetres longer than straight: the tube
		# follows, so the pieces always meet.
		var stretch: float = bottom.distance_to(top) / _torso_piece_length_m(piece)
		var basis: Basis = _wider(s.spine_basis(t_from, t_to)).scaled_local(Vector3(1.0, stretch, 1.0))
		_torso[piece].transform = Transform3D(basis, 0.5 * (bottom + top))
	for station: int in _torso_joints.size():
		var t: float = TORSO_STATIONS_T[station]
		var around: Basis = s.spine_basis(maxf(t - 0.1, 0.0), minf(t + 0.1, 1.0))
		_torso_joints[station].transform = Transform3D(_wider(around), s.spine_point(t))


## The length of a torso piece along a straight back, m.
func _torso_piece_length_m(piece: int) -> float:
	return (TORSO_STATIONS_T[piece + 1] - TORSO_STATIONS_T[piece]) * skeleton.torso_m


## A torso part's orientation, stretched sideways: the body is wider than it is deep.
func _wider(basis: Basis) -> Basis:
	return basis.scaled_local(Vector3(TORSO_WIDTH, 1.0, 1.0))


## A capsule of fixed `length` (between the centres of its round ends) laid from `from`
## toward `toward`. Its length never changes, so the bone does not stretch.
func _place_from(node: MeshInstance3D, from: Vector3, toward: Vector3, length: float) -> void:
	var direction: Vector3 = toward - from
	if direction.length() < 1e-5:
		direction = Vector3.UP
	direction = direction.normalized()
	node.transform = Transform3D(VisualMath.basis_with_up(direction), from + direction * (0.5 * length))


## A capsule laid between two points whose distance is fixed by the skeleton (the hips).
func _place_between(node: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	_place_from(node, a, b, (b - a).length())


## A foot standing on the deck at `ground` (under the ankle), pointing along `direction`:
## the heel a little behind the ankle, the toes ahead of it.
func _pose_foot(foot: Node3D, ground: Vector3, direction: Vector3) -> void:
	var back: Vector3 = -direction
	var right: Vector3 = Vector3.UP.cross(back).normalized()
	foot.transform = Transform3D(Basis(right, Vector3.UP, back), ground)


func _build_foot(node_name: String) -> Node3D:
	var foot: Node3D = Node3D.new()
	foot.name = node_name
	_root.add_child(foot)
	var length: float = skeleton.foot_length_m
	# The ankle is about a quarter of the foot from the heel; local -z is toward the toes.
	var middle_z: float = -(0.5 * length - 0.25 * length)
	VisualMath.add_box(foot, "Bootie", Vector3(0.1, 0.075, length), Vector3(0.0, 0.055, middle_z), BOOTIE)
	VisualMath.add_box(foot, "Sole", Vector3(0.11, 0.02, length + 0.01), Vector3(0.0, 0.01, middle_z), SOLE)
	return foot


## The head: a skull, a cap with its brim forward, sunglasses and a nose, so you can see
## which way the sailor looks. Local -z is the way the face looks.
func _build_head() -> Node3D:
	var head: Node3D = Node3D.new()
	head.name = "Head"
	_root.add_child(head)
	var skull: MeshInstance3D = MeshInstance3D.new()
	skull.name = "Skull"
	var skull_mesh: SphereMesh = SphereMesh.new()
	skull_mesh.radius = 0.105
	skull_mesh.height = 0.23
	skull.mesh = skull_mesh
	skull.material_override = VisualMath.plain_material(SKIN)
	head.add_child(skull)
	var cap: MeshInstance3D = MeshInstance3D.new()
	cap.name = "Cap"
	var cap_mesh: SphereMesh = SphereMesh.new()
	cap_mesh.radius = 0.112
	cap_mesh.height = 0.112
	cap_mesh.is_hemisphere = true
	cap.mesh = cap_mesh
	cap.position = Vector3(0.0, 0.025, 0.0)
	cap.material_override = VisualMath.plain_material(CAP)
	head.add_child(cap)
	VisualMath.add_box(head, "Brim", Vector3(0.17, 0.014, 0.11), Vector3(0.0, 0.03, -0.14), CAP)
	VisualMath.add_box(head, "Glasses", Vector3(0.16, 0.035, 0.03), Vector3(0.0, 0.0, -0.095), GLASSES)
	VisualMath.add_box(head, "Nose", Vector3(0.025, 0.045, 0.04), Vector3(0.0, -0.035, -0.105), SKIN)
	return head


func _add_capsule(node_name: String, radius: float, length: float, color: Color) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = radius
	# A capsule's height includes both round ends.
	capsule.height = length + 2.0 * radius
	instance.mesh = capsule
	instance.material_override = VisualMath.plain_material(color)
	_root.add_child(instance)
	return instance


func _add_sphere(node_name: String, radius: float, color: Color) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = radius
	sphere.height = 2.0 * radius
	instance.mesh = sphere
	instance.material_override = VisualMath.plain_material(color)
	_root.add_child(instance)
	return instance


## The harness belt: a short tube round the bottom of the belly (made round here, stretched
## sideways like the belly when it is placed).
func _add_belt() -> MeshInstance3D:
	var radius: float = TORSO_RADII_M[0] + BELT_MARGIN_M
	return _add_tube("Harness", radius, radius, BELT_HEIGHT_M, HARNESS)


## A tube along its y axis, `length` long, from `bottom_radius` to `top_radius`, open at
## both ends (the balls at the torso's joints close it).
func _add_tube(node_name: String, bottom_radius: float, top_radius: float, length: float, color: Color) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	var tube: CylinderMesh = CylinderMesh.new()
	tube.bottom_radius = bottom_radius
	tube.top_radius = top_radius
	tube.height = length
	tube.cap_top = false
	tube.cap_bottom = false
	instance.mesh = tube
	instance.material_override = VisualMath.plain_material(color)
	_root.add_child(instance)
	return instance


func _add_box(node_name: String, size: Vector3, color: Color) -> MeshInstance3D:
	return VisualMath.add_box(_root, node_name, size, Vector3.ZERO, color)
