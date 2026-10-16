class_name FigureSkeleton
extends RefCounted
## The skeleton of the sailor you see: where every joint of the figure is, worked out each
## tick from the simulation's sailor body. The simulation gives the anchors (the centre of
## mass, where the feet stand, where the hands hold the boom, the lean and the stance);
## this builds a body with FIXED bone lengths and real joints around them. Nothing here
## feeds back into the physics (CLAUDE.md, rule 2): it is a picture of what the simulation
## does, not a second simulation.
##
## Everything is in the board's own axes (x starboard, y up, z aft; the bow is -z).
##
## How it works, in order (solve()):
## 1. The feet: where they stand and which way the toes point (the front foot about 45
##    degrees toward the leeward bow, the back foot across the board).
## 2. The hands: on the boom either side of the grip, or the front hand on the mast in a tack.
## 3. The hips: at the simulation's centre of mass, then moved only as far as the legs and
##    the arms need to reach the feet and the hands without stretching.
## 4. The torso, the arms, the legs and the head, each limb by two-bone inverse kinematics
##    (solve_two_bone): the knee or the elbow sits where two bones of fixed length meet.
##
## What a real windsurfer looks like, which the choices below follow:
## - Planing in the harness: front leg extended, back leg slightly bent, arms nearly straight
##   (bending them too much, the front one especially, is the common mistake), hands about
##   shoulder-width apart, hips dropped down and back into the harness, look where you want
##   to go. (boards.co.uk, "Speed and control", https://boards.co.uk/features/speed-and-control.html;
##   the "figure 7" stance, seabreeze.com.au forum, "My sharing of super 7 stance learning".)
## - Standing at low speed: back foot across the board, front foot by the mast pointing
##   forward (about 45 degrees), knees bent, upright. (surfertoday.com, "How to get the
##   right windsurfing stance"; seabreeze.com.au, "Feet posi on the board"; cal-sailing.org,
##   "The 10-step guide to windsurfing".)
## - The boom between shoulder and chin height, the harness loop about a forearm and a hand
##   (0.4 m) from the boom (seabreeze.com.au, "Harness lines length quandary").
## - Body proportions as fractions of the height, from Winter, "Biomechanics and Motor
##   Control of Human Movement" (4th ed., 2009), figure 4.1, after Drillis and Contini (1966).

## Bone lengths as fractions of the body height (Winter 2009, figure 4.1). For a 1.75 m
## sailor: thigh 0.43, shin 0.43, upper arm 0.33, forearm 0.26, hips to shoulders 0.50 m.
const THIGH_RATIO: float = 0.245
const SHIN_RATIO: float = 0.246
const ANKLE_RATIO: float = 0.039  # the ankle joint above the sole
const FOOT_RATIO: float = 0.152  # heel to toes
const UPPER_ARM_RATIO: float = 0.186
const FOREARM_RATIO: float = 0.146
const HAND_RATIO: float = 0.035  # the wrist to the middle of the fist round the boom
const TORSO_RATIO: float = 0.288  # hip joints (0.530 H) to shoulder joints (0.818 H)
const SHOULDER_WIDTH_RATIO: float = 0.215  # between the shoulder joints (the shoulders are 0.259 H wide)
const HIP_WIDTH_RATIO: float = 0.1  # between the hip joints
const NECK_RATIO: float = 0.115  # shoulder line to the middle of the head

## The hip joints sit this far below the centre of mass: a standing person's centre of
## mass is a few centimetres above the hip joints, more with the arms up at the boom.
const HIPS_BELOW_COM_M: float = 0.06
## Hanging out in the harness the simulation's centre of mass is only about 0.3 m above the
## deck (com_height_m falls to half at full lean), while the boom stays at standing height:
## a body of fixed size with its hips there could only sit on the deck with its arms up
## over its head. A hiked windsurfer's hips are higher, with the legs reaching out from the
## rail, so the figure's hips are kept at least this high above the deck.
const HIPS_MIN_HEIGHT_M: float = 0.65
## The hips go at most this far from where the simulation's centre of mass (and the
## minimum height and the crouch) put them.
const HIPS_OFFSET_MAX_M: float = 0.4
## The hips stay within this share of the full reach of the torso and the arms from the
## hands, so the torso can stay fairly upright and the arms reach forward to the boom
## (at full reach the torso and the arms would make one straight line up to the boom).
const UPPER_REACH_SHARE: float = 0.9
## Where the feet stand, fore and aft of the stance point: standing at rest the front foot
## is just behind the mast foot and the back foot across the board behind it; in the straps
## the front strap is about 0.55 m ahead of the back strap; in a tack the feet are
## close together by the mast.
const FRONT_FOOT_STANDING_M: float = 0.2
const BACK_FOOT_STANDING_M: float = 0.28
const FRONT_FOOT_STRAPS_M: float = 0.28
const BACK_FOOT_STRAPS_M: float = 0.28
const FOOT_TACK_M: float = 0.15
## When the sailor faces the bow (half way round in a tack or a gybe) the feet stand side
## by side, this far either side of the centre.
const FEET_SIDE_BY_SIDE_M: float = 0.15
## How far the toes turn toward the bow: the front foot about 45 degrees (1.0), the back
## foot nearly straight across the board (0.25 = 14 degrees forward of across).
const FRONT_TOES_FORWARD: float = 1.0
const BACK_TOES_FORWARD: float = 0.25
## The hands on the boom: the front hand this far toward the mast from the grip (where the
## harness lines are), the back hand this far toward the clew; about shoulder-width apart.
const FRONT_HAND_FROM_GRIP_M: float = 0.2
const BACK_HAND_FROM_GRIP_M: float = 0.24
## The hands hold the boom up to this far toward the mast or the clew from where the harness
## lines are, so that they are across from the body (hanging out to windward, the body is
## well toward the mast, measured along a boom that points to leeward).
const HAND_SLIDE_MAX_M: float = 0.25
## In a tack the front hand goes onto the mast this far below the boom and the back hand
## onto the boom this far from the mast.
const TACK_HAND_BELOW_BOOM_M: float = 0.2
const TACK_BACK_HAND_ON_BOOM_M: float = 0.3
## The legs and arms reach at most this share of their full length (a soft knee, a soft
## elbow: 0.985 is still a bend of about 20 degrees).
const LEG_REACH_SHARE: float = 0.985
const ARM_REACH_SHARE: float = 0.985
## How far the shoulders stay from the hands, as a share of the arm's full reach: standing
## with the elbows bent about 90 degrees (0.71), hanging in the harness with the arms
## nearly straight (0.97 is a bend of about 25 degrees: near full reach the elbow angle
## changes fast with the reach).
const ARM_STANDING_SHARE: float = 0.71
const ARM_HIKED_SHARE: float = 0.97
## Hanging in the harness the back arches: the middle of the back comes this far toward the sail.
const SPINE_ARCH_M: float = 0.06
## In a tack or a gybe the sailor crouches this much lower than the centre of mass says:
## stepping round the mast, turning round, or carving at more than CARVE_START_DPS of
## yaw rate (fully at CARVE_START_DPS + CARVE_FULL_DPS).
const MANOEUVRE_CROUCH_M: float = 0.12
const CARVE_START_DPS: float = 6.0
const CARVE_FULL_DPS: float = 14.0
## The harness: the hook this far in front of the hips and above them, the two lines this
## far either side of the grip on the boom. Hooked in above the first tension, unhooked
## below the second (the gap stops it flickering).
const HOOK_FORWARD_M: float = 0.13
const HOOK_UP_M: float = 0.05
const HARNESS_LINE_SPREAD_M: float = 0.11
const HOOK_IN_TENSION_N: float = 250.0
const HOOK_OUT_TENSION_N: float = 150.0
const HOOKED_MIN_LEAN: float = 0.3
## The head turns at most this far from the way the chest faces, and looks this many
## seconds ahead into a turn.
const HEAD_TURN_MAX_RAD: float = 1.396  # 80 degrees
const LOOK_AHEAD_S: float = 1.0
const LOOK_TURN_MAX_RAD: float = 1.047  # 60 degrees
## The body turns round from one side to the other at this rate (a full turn in 0.8 s).
const TURN_RATE_PER_S: float = 2.5
## The boom has to be this far across the board before the body turns to face it.
const BOOM_SIDE_THRESHOLD: float = 0.15
## Rounds of the hips' reach correction (the legs and the arms pull alternately).
const REACH_ITERATIONS: int = 8

const LEFT: int = 0
const RIGHT: int = 1

## Bone lengths for this sailor (metres), from the height.
var thigh_m: float
var shin_m: float
var ankle_height_m: float
var foot_length_m: float
var upper_arm_m: float
var forearm_m: float
var hand_m: float
var torso_m: float
var shoulder_half_m: float
var hip_half_m: float
var neck_m: float

## The joints after solve(), board axes. Arrays are indexed [LEFT, RIGHT] (the sailor's own
## left and right).
var pelvis: Vector3 = Vector3.ZERO  # between the hip joints
var spine: Vector3 = Vector3.ZERO  # the middle of the back
var neck: Vector3 = Vector3.ZERO  # between the shoulder joints
var head: Vector3 = Vector3.ZERO  # the middle of the head
var hips: PackedVector3Array = PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
var knees: PackedVector3Array = PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
var ankles: PackedVector3Array = PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
var shoulders: PackedVector3Array = PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
var elbows: PackedVector3Array = PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
var wrists: PackedVector3Array = PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
var hands: PackedVector3Array = PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
## Which way each foot points (horizontal unit vectors).
var foot_dirs: PackedVector3Array = PackedVector3Array([Vector3.FORWARD, Vector3.FORWARD])
## Where the hands want to be (on the boom or the mast); `hands` is where they got to.
var hand_targets: PackedVector3Array = PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
## The orientation of the pelvis, the chest and the head: x to the sailor's right, y up the
## body, z out of the back (so -z is the way the body faces).
var pelvis_basis: Basis = Basis.IDENTITY
var chest_basis: Basis = Basis.IDENTITY
var head_basis: Basis = Basis.IDENTITY
## The harness: hooked in or not, the hook, and where the two lines meet the boom.
var hooked: bool = false
var hook: Vector3 = Vector3.ZERO
var harness_line_ends: PackedVector3Array = PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
## How far the hip joints are from where the simulation's centre of mass puts them
## (metres): the price of fixed limbs (see _place_pelvis), and the crouch in a manoeuvre.
var pelvis_offset_m: float = 0.0
## Where the feet stand on the deck, between the two feet: the pivot of the fall.
var feet_centre: Vector3 = Vector3(0.0, 0.06, 0.15)

## The side the body faces, -1 (the sail to port) to +1 (the sail to starboard), turned
## round smoothly in a tack or a gybe; 0 = facing the bow.
var facing_side: float = -1.0
var _facing_target: float = -1.0
var _last_time_s: float = -1.0


func _init(height_m: float = 1.75) -> void:
	thigh_m = THIGH_RATIO * height_m
	shin_m = SHIN_RATIO * height_m
	ankle_height_m = ANKLE_RATIO * height_m
	foot_length_m = FOOT_RATIO * height_m
	upper_arm_m = UPPER_ARM_RATIO * height_m
	forearm_m = FOREARM_RATIO * height_m
	hand_m = HAND_RATIO * height_m
	torso_m = TORSO_RATIO * height_m
	shoulder_half_m = 0.5 * SHOULDER_WIDTH_RATIO * height_m
	hip_half_m = 0.5 * HIP_WIDTH_RATIO * height_m
	neck_m = NECK_RATIO * height_m


## The full reach of a leg (hip to ankle) and of an arm (shoulder to the middle of the fist).
func leg_length_m() -> float:
	return thigh_m + shin_m


func arm_length_m() -> float:
	return upper_arm_m + forearm_m + hand_m


## Poses the whole skeleton from the simulation. `boom_dir` is the boom's direction from the
## mast in the board's axes (a unit vector), as the rig is drawn.
func solve(sim: WindsurferSim, boom_dir: Vector3) -> void:
	_update_facing(sim, boom_dir)
	var body: SimRigidBody = sim.body
	var com: Vector3 = SimMath.to_body(body.basis, sim.sailor.position - body.origin_world())
	var stance: float = sim.stance
	# In a tack the sailor steps forward round the mast (the stance goes below zero).
	var tack: float = clampf(-2.0 * stance, 0.0, 1.0)
	# Carving a turn (a gybe, the start of a tack): the sailor bends the knees and sinks.
	var carving: float = clampf((absf(sim.telemetry.yaw_rate_dps) - CARVE_START_DPS) / CARVE_FULL_DPS, 0.0, 1.0)
	var turning: float = maxf(maxf(tack, carving), 1.0 - absf(facing_side))
	# Hanging out in the harness: how far the body is out (0 standing, 1 fully hiked).
	var hike: float = clampf(absf(sim.lean) * 1.2, 0.0, 1.0) * (1.0 - turning)

	_place_feet(sim, stance)
	_place_hands(sim, boom_dir, tack, com)
	var wanted: Vector3 = com - Vector3.UP * HIPS_BELOW_COM_M
	wanted.y = maxf(wanted.y, sim.feet_body.y + HIPS_MIN_HEIGHT_M) - MANOEUVRE_CROUCH_M * turning
	_place_pelvis(wanted, hike)
	pelvis_offset_m = pelvis.distance_to(com - Vector3.UP * HIPS_BELOW_COM_M)
	_place_torso(hike)
	_place_arms()
	_place_legs()
	_place_head(sim)
	_place_harness(sim, boom_dir, tack)


## Two-bone inverse kinematics: a limb from `root` toward `target` with a bone of length `a`
## on the root side and one of length `b` on the target side (a thigh and a shin, an upper
## arm and a forearm). The middle joint (the knee, the elbow) lies on the circle where a
## sphere of radius a round the root meets a sphere of radius b round the target; `pole`
## chooses the point on that circle: the joint goes the way `pole` points, as a knee goes
## the way the toes point. Out of reach, the limb points straight at the target and its end
## stops short; too close, it folds as far as it can. The bones never change length.
## Returns [the middle joint, where the end of the limb got to].
static func solve_two_bone(root: Vector3, target: Vector3, a: float, b: float, pole: Vector3) -> PackedVector3Array:
	var to_target: Vector3 = target - root
	var distance: float = to_target.length()
	var along: Vector3 = to_target / distance if distance > 1e-6 else Vector3.DOWN
	distance = clampf(distance, absf(a - b) + 1e-4, a + b - 1e-4)
	# The law of cosines: how far along the root-to-end line the middle joint is, and how
	# far out from that line.
	var x: float = (a * a - b * b + distance * distance) / (2.0 * distance)
	var h: float = sqrt(maxf(a * a - x * x, 0.0))
	var out: Vector3 = pole - along * pole.dot(along)
	if out.length() < 1e-4:
		# The pole points along the limb: any side will do, take one that is never parallel.
		var spare: Vector3 = Vector3.RIGHT if absf(along.x) < 0.9 else Vector3.BACK
		out = spare - along * spare.dot(along)
	out = out.normalized()
	var middle: Vector3 = root + along * x + out * h
	var end: Vector3 = root + along * distance
	return PackedVector3Array([middle, end])


## Which side the body faces. The sailor faces the sail, which is on the side the boom
## points to; when the boom swings across (a tack or a gybe) the body turns round through
## facing the bow at TURN_RATE_PER_S.
func _update_facing(sim: WindsurferSim, boom_dir: Vector3) -> void:
	if absf(boom_dir.x) > BOOM_SIDE_THRESHOLD:
		_facing_target = signf(boom_dir.x)
	var dt: float = sim.time_s - _last_time_s
	if _last_time_s < 0.0 or dt < 0.0 or dt > 0.5:
		# The first pose, or the simulation was reset: no turning, face the sail now.
		if absf(boom_dir.x) <= BOOM_SIDE_THRESHOLD:
			_facing_target = float(sim.sail.sail_side)
		facing_side = _facing_target
	else:
		facing_side = move_toward(facing_side, _facing_target, TURN_RATE_PER_S * dt)
	_last_time_s = sim.time_s


## The way the body faces, horizontal: across the board toward the sail, or toward the bow
## half way round in a tack or a gybe.
func facing_dir() -> Vector3:
	return Vector3(facing_side, 0.0, -(1.0 - absf(facing_side))).normalized()


## The feet. The stance point is where the simulation stands the feet (feet_body), without
## the trim press (that is pressure, not a step). The front foot stands ahead of it and the
## back foot behind it; the sailor's right foot is the front foot when the sail is to port
## (starboard tack), the left foot when it is to starboard. Half way round in a tack the
## feet stand side by side, so as the body turns the feet step round each other.
func _place_feet(sim: WindsurferSim, stance: float) -> void:
	var feet: Vector3 = sim.feet_body
	var centre: Vector3 = Vector3(feet.x, feet.y, feet.z - sim.trim_press_m)
	var in_straps: float = clampf(stance, 0.0, 1.0)
	var front_m: float = lerpf(FRONT_FOOT_STANDING_M, FRONT_FOOT_STRAPS_M, in_straps)
	var back_m: float = lerpf(BACK_FOOT_STANDING_M, BACK_FOOT_STRAPS_M, in_straps)
	if stance < 0.0:
		front_m = lerpf(front_m, FOOT_TACK_M, -stance)
		back_m = lerpf(back_m, FOOT_TACK_M, -stance)
	var facing: Vector3 = facing_dir()
	for side: int in [LEFT, RIGHT]:
		var sign_right: float = 1.0 if side == RIGHT else -1.0
		# +1 for the front foot, -1 for the back foot, in between while turning round.
		var frontness: float = -sign_right * facing_side
		var along_m: float = frontness * (front_m if frontness > 0.0 else back_m)
		var across_m: float = sign_right * FEET_SIDE_BY_SIDE_M * (1.0 - absf(facing_side))
		var foot: Vector3 = centre + Vector3.FORWARD * along_m + Vector3.RIGHT * across_m
		var toes_forward: float = lerpf(BACK_TOES_FORWARD, FRONT_TOES_FORWARD, 0.5 * (frontness + 1.0))
		foot_dirs[side] = (facing + Vector3.FORWARD * toes_forward).normalized()
		ankles[side] = foot + Vector3.UP * ankle_height_m
	feet_centre = centre


## The hands: on the boom either side of the grip (slid a little toward the body), the
## front hand (toward the mast) on the sailor's right when the sail is to port. In a tack (`tack` 1) the front hand holds the
## mast just below the boom and the back hand the boom near the mast, as a sailor does
## stepping round the front of the mast.
func _place_hands(sim: WindsurferSim, boom_dir: Vector3, tack: float, com: Vector3) -> void:
	var grip: Vector3 = sim.hand_grip_body
	var boom_root: Vector3 = grip - boom_dir * sim.sailor_config.hand_grip_m
	# The hands go a little way along the boom toward the body.
	grip += boom_dir * clampf((com - grip).dot(boom_dir), -HAND_SLIDE_MAX_M, HAND_SLIDE_MAX_M)
	var mast_foot: Vector3 = sim.sail_config.mast_foot_local
	var mast_dir: Vector3 = (boom_root - mast_foot).normalized()
	var front_on_boom: Vector3 = grip - boom_dir * FRONT_HAND_FROM_GRIP_M
	var back_on_boom: Vector3 = grip + boom_dir * BACK_HAND_FROM_GRIP_M
	var front_on_mast: Vector3 = boom_root - mast_dir * TACK_HAND_BELOW_BOOM_M
	var back_near_mast: Vector3 = boom_root + boom_dir * TACK_BACK_HAND_ON_BOOM_M
	var front_hand: Vector3 = front_on_boom.lerp(front_on_mast, tack)
	var back_hand: Vector3 = back_on_boom.lerp(back_near_mast, tack)
	# The right hand is the front hand with the sail to port; half way round the hands
	# change over (they slide past each other: the hand change, not drawn in detail).
	var right_is_back: float = smoothstep(-0.3, 0.3, facing_side)
	hand_targets[RIGHT] = front_hand.lerp(back_hand, right_is_back)
	hand_targets[LEFT] = back_hand.lerp(front_hand, right_is_back)


## The hips. They start at the simulation's centre of mass (a little below it, at the hip
## joints; at least HIPS_MIN_HEIGHT_M above the deck), and move only as far as fixed limbs
## need: the legs must reach the ankles and the torso and the arms the hands. Hanging out
## in the harness at speed the simulation puts the centre of mass about a metre out and
## only a third of a metre above the deck, further from the boom than a torso and two arms
## reach; the hips then end up about 0.3 m higher and 0.25 m further in (at 18 kt). That
## is the one place the figure leaves the simulation's numbers, so that the hands stay on
## the boom and the limbs keep their length; pelvis_offset_m says how far it went.
func _place_pelvis(wanted: Vector3, hike: float) -> void:
	pelvis = wanted
	_set_pelvis_axes()
	var hands_middle: Vector3 = 0.5 * (hand_targets[LEFT] + hand_targets[RIGHT])
	var upper_reach: float = UPPER_REACH_SHARE * (torso_m + _comfortable_reach_m(hike))
	# The hips go to the nearest place within reach of both the hands and the feet: pulled
	# toward the hands, then back toward the feet, a few times over (each pull is small).
	for pass_index: int in REACH_ITERATIONS:
		var to_hands: Vector3 = hands_middle - pelvis
		if to_hands.length() > upper_reach:
			pelvis += to_hands.normalized() * (to_hands.length() - upper_reach)
		_keep_legs_in_reach()
	# A last check arm by arm (the shoulders sit either side of the middle): if one still
	# cannot reach its hand, the hips move the rest of the way, one arm at a time.
	var arm_reach: float = ARM_REACH_SHARE * arm_length_m()
	for side: int in [LEFT, RIGHT]:
		_place_torso(hike)
		var arm: Vector3 = hand_targets[side] - shoulders[side]
		if arm.length() > arm_reach:
			pelvis += arm.normalized() * (arm.length() - arm_reach)
	# Never further than HIPS_OFFSET_MAX_M from the centre of mass: when the boom swings
	# across in a gybe the hands let go and reach for it (they stop short) rather than drag
	# the body after it.
	pelvis = wanted + (pelvis - wanted).limit_length(HIPS_OFFSET_MAX_M)
	_keep_legs_in_reach()


## Moves the hips so each hip joint is within reach of its ankle and the legs are not
## folded flat, one leg at a time.
func _keep_legs_in_reach() -> void:
	var leg_reach: float = LEG_REACH_SHARE * leg_length_m()
	var leg_fold: float = 0.45 * leg_length_m()
	for side: int in [LEFT, RIGHT]:
		var leg: Vector3 = _hip_joint(side) - ankles[side]
		if leg.length() > leg_reach:
			pelvis -= leg.normalized() * (leg.length() - leg_reach)
		elif leg.length() < leg_fold:
			pelvis += leg.normalized() * (leg_fold - leg.length())


## How far the shoulders stay from the hands: elbows bent standing, nearly straight hanging
## in the harness.
func _comfortable_reach_m(hike: float) -> float:
	return lerpf(ARM_STANDING_SHARE, ARM_HIKED_SHARE, hike) * arm_length_m()


## The pelvis turns with the feet: its right hip toward the sailor's right foot, opened a
## little toward the bow.
func _set_pelvis_axes() -> void:
	var facing: Vector3 = facing_dir()
	var forward: Vector3 = (facing + Vector3.FORWARD * 0.35 * absf(facing_side)).normalized()
	var right: Vector3 = forward.cross(Vector3.UP).normalized()
	pelvis_basis = Basis(right, Vector3.UP, right.cross(Vector3.UP))


func _hip_joint(side: int) -> Vector3:
	var sign_right: float = 1.0 if side == RIGHT else -1.0
	return pelvis + pelvis_basis.x * (sign_right * hip_half_m)


## The torso, from the hips to the shoulders, solved like a limb: the "bones" are the torso
## and the arm's comfortable reach (elbows bent 90 degrees standing, nearly straight hanging
## in the harness), toward the point between the hands. The shoulders go up (the pole):
## standing that leans the body back a little against the pull, hanging out it points the
## torso at the boom. The shoulder line runs along the boom (shoulders square to it).
func _place_torso(hike: float) -> void:
	var hands_middle: Vector3 = 0.5 * (hand_targets[LEFT] + hand_targets[RIGHT])
	# The sailor's right: the right shoulder toward the front hand when the sail is to
	# port, toward the back hand when it is to starboard. The shoulder line runs parallel
	# to the line between the hands (the chest leans a little sideways for it, as a body
	# does), so both arms reach equally far.
	var across_hands: Vector3 = hand_targets[RIGHT] - hand_targets[LEFT]
	var right: Vector3 = across_hands.normalized() if across_hands.length() > 0.05 else facing_dir().cross(Vector3.UP)
	var chain: PackedVector3Array = solve_two_bone(pelvis, hands_middle, torso_m, _comfortable_reach_m(hike), Vector3.UP)
	neck = chain[0]
	# The middle of the back: half way up, the belly pushed toward the sail when hanging in
	# the harness (an arched back: the hips forward, the chest open and up).
	var spine_line: Vector3 = (neck - pelvis).normalized()
	var belly: Vector3 = facing_dir() - spine_line * facing_dir().dot(spine_line)
	spine = pelvis.lerp(neck, 0.5) + belly.normalized() * (SPINE_ARCH_M * hike)
	# The chest follows the upper half of the back.
	var up: Vector3 = (neck - spine) - right * (neck - spine).dot(right)
	up = up.normalized()
	# The chest faces the way the body faces (z out of the back).
	var back: Vector3 = right.cross(up)
	if back.dot(facing_dir()) > 0.0:
		right = -right
		back = -back
	chest_basis = Basis(right, up, back)
	shoulders[RIGHT] = neck + right * shoulder_half_m
	shoulders[LEFT] = neck - right * shoulder_half_m
	# The pelvis tilts half way between the legs and the torso.
	var legs_up: Vector3 = (pelvis - 0.5 * (ankles[LEFT] + ankles[RIGHT])).normalized()
	var pelvis_up: Vector3 = (legs_up + (spine - pelvis).normalized()).normalized()
	var pelvis_right: Vector3 = pelvis_basis.x - pelvis_up * pelvis_basis.x.dot(pelvis_up)
	pelvis_right = pelvis_right.normalized()
	var pelvis_back: Vector3 = pelvis_right.cross(pelvis_up)
	pelvis_basis = Basis(pelvis_right, pelvis_up, pelvis_back)


## The arms: from each shoulder to its hand, the elbow pointing down and out.
func _place_arms() -> void:
	for side: int in [LEFT, RIGHT]:
		var outward: Vector3 = (shoulders[side] - neck).normalized()
		var pole: Vector3 = Vector3.DOWN + outward * 0.6 + chest_basis.z * 0.2
		var chain: PackedVector3Array = solve_two_bone(shoulders[side], hand_targets[side], upper_arm_m, forearm_m + hand_m, pole)
		elbows[side] = chain[0]
		hands[side] = chain[1]
		wrists[side] = elbows[side] + (hands[side] - elbows[side]).normalized() * forearm_m


## The legs: from each hip joint to its ankle, the knee over the toes. A knee is a hinge:
## it bends only in the plane of the leg line and the way the foot points.
func _place_legs() -> void:
	for side: int in [LEFT, RIGHT]:
		hips[side] = _hip_joint(side)
		var chain: PackedVector3Array = solve_two_bone(hips[side], ankles[side], thigh_m, shin_m, foot_dirs[side])
		knees[side] = chain[0]
		# The ankle stays where it stands (the hips were placed within reach of it).
		ankles[side] = chain[1]


## The head: on a neck held more upright than the torso, looking where the board goes
## (over the front shoulder toward the bow, and into a turn), at most HEAD_TURN_MAX_RAD
## from the way the chest faces.
func _place_head(sim: WindsurferSim) -> void:
	var up: Vector3 = (chest_basis.y + Vector3.UP).normalized()
	head = neck + up * neck_m
	# The board's yaw rate, positive turning to port (a turn about +y), carries the look
	# into the turn.
	var turn: float = clampf(deg_to_rad(sim.telemetry.yaw_rate_dps) * LOOK_AHEAD_S, -LOOK_TURN_MAX_RAD, LOOK_TURN_MAX_RAD)
	var wanted: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, turn)
	var chest_forward: Vector3 = -chest_basis.z
	chest_forward.y = 0.0
	if chest_forward.length() < 0.05:
		chest_forward = facing_dir()
	chest_forward = chest_forward.normalized()
	var angle: float = clampf(chest_forward.signed_angle_to(wanted, Vector3.UP), -HEAD_TURN_MAX_RAD, HEAD_TURN_MAX_RAD)
	var look: Vector3 = chest_forward.rotated(Vector3.UP, angle)
	var back: Vector3 = -(look - up * look.dot(up)).normalized()
	var right: Vector3 = up.cross(back).normalized()
	head_basis = Basis(right, back.cross(right), back)


## The harness: the hook in front of the hips, the lines to the boom either side of the
## grip. Hooked in while the line carries a real load, never in a tack.
func _place_harness(sim: WindsurferSim, boom_dir: Vector3, tack: float) -> void:
	if hooked:
		hooked = sim.harness_tension_n > HOOK_OUT_TENSION_N
	else:
		hooked = sim.harness_tension_n > HOOK_IN_TENSION_N
	# A sailor hooks in to hang out against the pull, not while standing up by the mast.
	hooked = hooked and absf(sim.lean) > HOOKED_MIN_LEAN and tack < 0.01 and absf(facing_side) > 0.99
	hook = pelvis - pelvis_basis.z * HOOK_FORWARD_M + pelvis_basis.y * HOOK_UP_M
	var grip: Vector3 = sim.hand_grip_body
	harness_line_ends[0] = grip - boom_dir * HARNESS_LINE_SPREAD_M
	harness_line_ends[1] = grip + boom_dir * HARNESS_LINE_SPREAD_M
