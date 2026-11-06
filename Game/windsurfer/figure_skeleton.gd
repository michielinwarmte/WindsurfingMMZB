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
## 1. The feet (FigureFeet): where each one should stand (in the footstraps while planing, near
##    the mast at rest, round the front of the mast in a tack) and which way the toes point;
##    a foot stays planted and takes a step (lift, move, put down) when it has to move.
## 2. The hands (FigureHands): where each one should hold the rig (the boom either side of the
##    harness lines, the mast in a tack, nothing while the rig flips); a hand holds on and
##    slides or regrips at a person's pace.
## 3. The hips: at the simulation's centre of mass, then moved only as far as the legs and
##    the arms need to reach the feet and the hands without stretching; then they follow that
##    place like a body on springy legs (a damped spring in the board's level frame): the knees
##    take the chop and the upper body stays steadier than the board.
## 4. The torso, the arms, the legs and the head, each limb by two-bone inverse kinematics
##    (solve_two_bone): the knee or the elbow sits where two bones of fixed length meet.
## The pose is worked out from the simulation's state and the figure's own state of the last
## tick (where each foot stands, what each hand holds, the springs); the first pose, and the first
## after a reset or a fall, is put straight in place.
##
## The sailor polish of 6 November 2026 (Documentation/reports/sailor/sailor_polish_6nov.md)
## measured the figure tick by tick (Game/dev/figure_motion.gd) and found what shook: the crouch
## of a turn followed the board's yaw rate, which jumps by 20 degrees a second from one tick to
## the next in the chop, so the hips bobbed by up to 10 cm a tick; the simulation's centre of mass
## alternates by a few centimetres from one tick to the next at 24 kt; the feet followed the feet's
## pressure point (the trim and the mouse's press), sliding up to half a metre out of the straps;
## the hands slid along the boom with the body and jumped across when the sail changed sides.

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
## The body turns round from one side to the other like a spring that does not overshoot (radians a
## second: from facing one side to facing the other in about 0.7 s, starting and ending gently).
const TURN_OMEGA: float = 9.0
## The boom has to be this far across the board before the body turns to face it.
const BOOM_SIDE_THRESHOLD: float = 0.15
## Rounds of the hips' reach correction (the legs and the arms pull alternately).
const REACH_ITERATIONS: int = 8

## How quickly the figure follows the simulation (critically damped springs, radians a second; a
## sudden change is followed within about 4 / omega seconds). The hips: about 2 Hz, so the body
## keeps the simulation's own movement (the hike, the weight shifts, the legs taking the chop,
## all slower than that) and drops the tick-to-tick jitter. The yaw rate behind the crouch of a
## turn and the look into it: a third of a second, as a sailor feels a turn rather than every
## twitch of the board. The hike and the stepping round the mast: a quarter of a second.
const BODY_OMEGA: float = 14.0
const NECK_OMEGA: float = 16.0
const CHEST_OMEGA: float = 12.0
const YAW_OMEGA: float = 6.0
## Whether the board is carving a turn is felt more slowly still (radians a second, about a second
## to take it in): in the chop the yaw rate swings by 30 degrees a second either way on a straight
## course, which the crouch of a carve took for a turn.
const CARVE_OMEGA: float = 2.5
const POSTURE_OMEGA: float = 10.0
const HAND_SLIDE_OMEGA: float = 4.0
const ELBOW_OMEGA: float = 20.0
## The feet go into the footstraps when the simulation's stance reaches the first value (the
## board planes and the feet have stepped back), and come out of them below the second, or in a
## turn. In between they stay in the straps: a planing sailor keeps both feet in them and moves the
## weight with the hips and the knees, downwind too.
const STRAPS_IN_STANCE: float = 0.9
const STRAPS_OUT_STANCE: float = 0.6
## In a carve the front hand moves up the boom toward the mast, ready for the rig flip (metres
## from the mast).
const CARVE_FRONT_HAND_M: float = 0.3
## After the hips' spring, an arm out of reach pulls the hips this share of the way each tick.
const ARM_PULL_SHARE: float = 0.3

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
var _facing_speed: float = 0.0
var _last_time_s: float = -1.0
## Whether the feet are in the footstraps now (see STRAPS_IN_STANCE).
var in_straps: bool = false
## The feet and the hands: where they stand and hold, and their steps and regrips.
var feet: FigureFeet = FigureFeet.new()
var grips: FigureHands = FigureHands.new()
## The springs' states: the hips in the board's level frame and their velocity, the smoothed yaw
## rate (degrees a second), the tack share, the hike, the hands' slide along the boom, the way
## each elbow points.
var _pelvis_level: Vector3 = Vector3.ZERO
var _pelvis_velocity: Vector3 = Vector3.ZERO
var _yaw_dps: Spring = Spring.new()
var _carve_yaw_dps: Spring = Spring.new()
var _tack: Spring = Spring.new()
var _hike: Spring = Spring.new()
var _slide: Spring = Spring.new()
var _look_rad: Spring = Spring.new()
var _elbow_out: PackedVector3Array = PackedVector3Array([Vector3.DOWN, Vector3.DOWN])
## From the board's axes to its level frame, this tick.
var _to_level: Basis = Basis.IDENTITY
## The neck's place from the hips in the level frame and its velocity (_steady_torso), and the
## shoulder line's way (_update_chest_right).
var _neck_level: Vector3 = Vector3.UP
var _neck_velocity: Vector3 = Vector3.ZERO
var _chest_right: Vector3 = Vector3.ZERO
## The hand that led (the front hand) when the sailor last sailed straight: the one that goes onto
## the mast in a tack.
var _lead_side: int = RIGHT
## The hand that lets go while the rig flips (-1 when it is not flipping).
var _flip_free_side: int = -1


## A number that follows a target through a critically damped spring (VisualMath.spring_float).
class Spring:
	var value: float = 0.0
	var speed: float = 0.0

	## One step toward `target`; a negative dt puts it on the target. Returns the new value.
	func follow(target: float, omega: float, dt: float) -> float:
		if dt < 0.0:
			value = target
			speed = 0.0
		else:
			var next: Vector2 = VisualMath.spring_float(value, speed, target, omega, dt)
			value = next.x
			speed = next.y
		return value


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


## Where the hands really hold: the physics puts the grip on the boom's centre line, but a
## wishbone boom has two arms and the sailor holds the windward one, about 0.28 m to
## windward of that line. The figure sets this from the rig (RigVisuals.windward_arm_offset);
## zero without a rig. Board axes.
var grip_offset_body: Vector3 = Vector3.ZERO


## Poses the whole skeleton from the simulation. `boom_dir` is the boom's direction from the
## mast in the board's axes (a unit vector), as the rig is drawn; `mast_dir` the mast's (zero: the
## simulation's own); `rig_flipping` whether the drawn boom is swinging across (DrawnRig).
func solve(sim: WindsurferSim, boom_dir: Vector3, mast_dir: Vector3 = Vector3.ZERO, rig_flipping: bool = false) -> void:
	var dt: float = _time_step(sim)
	if mast_dir == Vector3.ZERO:
		mast_dir = (sim.body.basis.transposed() * sim.rig.basis * sim.sail.mast_direction()).normalized()
	_update_facing(sim, boom_dir, dt)
	var body: SimRigidBody = sim.body
	var com: Vector3 = SimMath.to_body(body.basis, sim.sailor.position - body.origin_world())
	var stance: float = sim.stance
	# In a tack the sailor steps forward round the mast (the stance goes below zero).
	var tack: float = clampf(_tack.follow(clampf(-2.0 * stance, 0.0, 1.0), POSTURE_OMEGA, dt), 0.0, 1.0)
	# Carving a turn (a gybe, the start of a tack): the sailor bends the knees and sinks. The yaw
	# rate is felt over a third of a second: in the chop it jumps by 20 degrees a second from one
	# tick to the next, and the hips bobbed with it.
	var yaw_dps: float = _yaw_dps.follow(sim.telemetry.yaw_rate_dps, YAW_OMEGA, dt)
	var carve_dps: float = _carve_yaw_dps.follow(sim.telemetry.yaw_rate_dps, CARVE_OMEGA, dt)
	var carving: float = clampf((absf(carve_dps) - CARVE_START_DPS) / CARVE_FULL_DPS, 0.0, 1.0)
	var turning: float = maxf(maxf(tack, carving), 1.0 - absf(facing_side))
	# Hanging out in the harness: how far the body is out (0 standing, 1 fully hiked).
	var hike: float = clampf(_hike.follow(clampf(absf(sim.lean) * 1.2, 0.0, 1.0) * (1.0 - turning), POSTURE_OMEGA, dt), 0.0, 1.0)

	if tack < 0.05 and absf(facing_side) >= 1.0:
		_lead_side = front_side()
	_place_feet(sim, stance, turning, dt)
	_place_hands(sim, boom_dir, mast_dir, tack, carving, rig_flipping, com, dt)
	_update_chest_right(dt)
	var wanted: Vector3 = com - Vector3.UP * HIPS_BELOW_COM_M
	wanted.y = maxf(wanted.y, sim.feet_body.y + HIPS_MIN_HEIGHT_M) - MANOEUVRE_CROUCH_M * turning
	_place_pelvis(wanted, hike)
	_steady_pelvis(sim, dt)
	_keep_in_reach(hike)
	pelvis_offset_m = pelvis.distance_to(com - Vector3.UP * HIPS_BELOW_COM_M)
	_place_torso(hike)
	_steady_torso(hike, dt)
	_place_arms(dt)
	_place_legs()
	_place_head(yaw_dps, dt)
	_place_harness(sim, tack, rig_flipping)


## The time since the last pose by the simulation's clock (0: posed again in the same tick, which
## changes nothing); -1 for the first pose and after a reset or a fall (a gap longer than half a
## second, or the clock gone back): everything is then put straight in place.
func _time_step(sim: WindsurferSim) -> float:
	var dt: float = sim.time_s - _last_time_s
	var first: bool = _last_time_s < 0.0 or dt < 0.0 or dt > 0.5
	_last_time_s = sim.time_s
	return -1.0 if first else dt


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
## facing the bow, starting and stopping gently (a spring that does not overshoot).
func _update_facing(sim: WindsurferSim, boom_dir: Vector3, dt: float) -> void:
	if absf(boom_dir.x) > BOOM_SIDE_THRESHOLD:
		_facing_target = signf(boom_dir.x)
	if dt < 0.0:
		# The first pose, or the simulation was reset: no turning, face the sail now.
		if absf(boom_dir.x) <= BOOM_SIDE_THRESHOLD:
			_facing_target = float(sim.sail.sail_side)
		facing_side = _facing_target
		_facing_speed = 0.0
		return
	var next: Vector2 = VisualMath.spring_float(facing_side, _facing_speed, _facing_target, TURN_OMEGA, dt)
	facing_side = clampf(next.x, -1.0, 1.0)
	_facing_speed = next.y
	if absf(facing_side - _facing_target) < 1e-3:
		facing_side = _facing_target
		_facing_speed = 0.0


## The way the body faces, horizontal: across the board toward the sail, or toward the bow
## half way round in a tack or a gybe.
func facing_dir() -> Vector3:
	return Vector3(facing_side, 0.0, -(1.0 - absf(facing_side))).normalized()


## The sailor's front side: the right foot and hand lead with the sail to port (starboard tack),
## the left ones with the sail to starboard.
func front_side() -> int:
	return RIGHT if _facing_target < 0.0 else LEFT


## The side of the board the sailor stands on, away from the sail: +1 starboard, -1 port.
func windward_side() -> float:
	return -signf(_facing_target)


## The feet. Planing (the simulation's stance in the straps, not in a turn) they stand in the
## windward footstraps of the board (BoardConfig: the back and the front strap), and stay there
## while the simulation moves the weight between them (the trim, the rider's own press: that is
## the hips and the knees, not a step). Otherwise they stand about the simulation's stance point,
## without the feet's press: the front foot ahead of it, the back foot behind it; the sailor's
## right foot is the front foot when the sail is to port (starboard tack), the left foot when it
## is to starboard. Half way round in a tack the feet stand side by side, so as the body turns the
## feet step round each other (FigureFeet: one step at a time, round the front of the mast).
func _place_feet(sim: WindsurferSim, stance: float, turning: float, dt: float) -> void:
	var board: BoardConfig = sim.board_config
	var has_straps: bool = board.back_strap_from_tail_m > 0.0 and board.front_strap_from_tail_m > 0.0
	if dt < 0.0:
		in_straps = false
	if in_straps:
		in_straps = stance > STRAPS_OUT_STANCE and turning < 0.5
	else:
		in_straps = has_straps and stance >= STRAPS_IN_STANCE and turning < 0.2
	# Where the simulation stands the feet, without the feet's press (the press is weight, not a
	# step), and out toward the windward rail with the lean.
	var standing: Vector3 = sim.mass_model.feet_position_body(stance, sim.lean, 0.0, 0.0)
	var centre: Vector3 = Vector3(standing.x, sim.feet_body.y, standing.z)
	var standing_share: float = clampf(stance, 0.0, 1.0)
	var front_m: float = lerpf(FRONT_FOOT_STANDING_M, FRONT_FOOT_STRAPS_M, standing_share)
	var back_m: float = lerpf(BACK_FOOT_STANDING_M, BACK_FOOT_STRAPS_M, standing_share)
	if stance < 0.0:
		front_m = lerpf(front_m, FOOT_TACK_M, -stance)
		back_m = lerpf(back_m, FOOT_TACK_M, -stance)
	var facing: Vector3 = facing_dir()
	# The sailor stands on the windward side, away from the sail.
	var windward: float = -signf(_facing_target)
	var half_length: float = 0.5 * board.length_m
	var wanted: PackedVector3Array = PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
	var wanted_dirs: PackedVector3Array = PackedVector3Array([Vector3.FORWARD, Vector3.FORWARD])
	for side: int in [LEFT, RIGHT]:
		var sign_right: float = 1.0 if side == RIGHT else -1.0
		# +1 for the front foot, -1 for the back foot, in between while turning round.
		var frontness: float = -sign_right * facing_side
		var foot: Vector3
		if in_straps:
			var front: bool = frontness > 0.0
			var out_m: float = board.front_strap_out_m if front else board.back_strap_out_m
			var from_tail_m: float = board.front_strap_from_tail_m if front else board.back_strap_from_tail_m
			foot = Vector3(windward * out_m, centre.y, half_length - from_tail_m)
		else:
			var along_m: float = frontness * (front_m if frontness > 0.0 else back_m)
			var across_m: float = sign_right * FEET_SIDE_BY_SIDE_M * (1.0 - absf(facing_side))
			foot = centre + Vector3.FORWARD * along_m + Vector3.RIGHT * across_m
		var toes_forward: float = lerpf(BACK_TOES_FORWARD, FRONT_TOES_FORWARD, 0.5 * (frontness + 1.0))
		wanted[side] = foot
		wanted_dirs[side] = (facing + Vector3.FORWARD * toes_forward).normalized()
	feet.update(wanted, wanted_dirs, dt, sim.sail_config.mast_foot_local, front_side())
	for side: int in [LEFT, RIGHT]:
		foot_dirs[side] = feet.dirs[side]
		ankles[side] = feet.ground[side] + Vector3.UP * ankle_height_m
	feet_centre = 0.5 * (feet.ground[LEFT] + feet.ground[RIGHT])
	feet_centre.y = centre.y


## The hands (FigureHands). Sailing, the front hand (toward the mast; the right hand when the sail
## is to port) holds the boom FRONT_HAND_FROM_GRIP_M ahead of the harness lines and the back hand
## BACK_HAND_FROM_GRIP_M behind them, both a little toward where the body is. Carving a gybe the
## front hand moves up toward the mast. In a tack (`tack` 1) one hand holds the mast just below
## the boom and the other the boom near the mast, as a sailor does stepping round the front of the
## mast; the hand on the mast stays there until the tack is done. While the rig flips the back
## hand lets go (the other holds on near the mast), and afterwards takes the boom on the new side
## first, as the new front hand: the hands cross, as in a real gybe.
func _place_hands(sim: WindsurferSim, boom_dir: Vector3, mast_dir: Vector3, tack: float, carving: float,
		rig_flipping: bool, com: Vector3, dt: float) -> void:
	var sail: SailConfig = sim.sail_config
	grips.boom_dir = boom_dir
	grips.mast_dir = mast_dir
	grips.boom_m = sail.boom_m
	grips.boom_root = sail.mast_foot_local + mast_dir * sail.boom_height_m
	grips.arm_offset = grip_offset_body
	# A free hand waits in front of the chest, below the shoulders (where they were last tick).
	var forward: Vector3 = -chest_basis.z
	for side: int in [LEFT, RIGHT]:
		var sign_right: float = 1.0 if side == RIGHT else -1.0
		grips.free_places[side] = neck + forward * 0.3 + Vector3.DOWN * 0.3 + chest_basis.x * (sign_right * 0.15)
	# The hands go a little way along the boom toward the body (felt over a quarter of a second).
	var grip: Vector3 = grips.boom_root + boom_dir * sim.sailor_config.hand_grip_m
	var slide: float = _slide.follow(clampf((com - grip).dot(boom_dir), -HAND_SLIDE_MAX_M, HAND_SLIDE_MAX_M), HAND_SLIDE_OMEGA, dt)
	var grip_m: float = sim.sailor_config.hand_grip_m + slide
	var front_m: float = lerpf(grip_m - FRONT_HAND_FROM_GRIP_M, CARVE_FRONT_HAND_M, carving)
	var back_m: float = grip_m + BACK_HAND_FROM_GRIP_M
	var front: int = front_side()
	var back: int = 1 - front
	var wanted_holds: PackedInt32Array = PackedInt32Array([FigureHands.Hold.BOOM, FigureHands.Hold.BOOM])
	var wanted_along: PackedFloat64Array = PackedFloat64Array([0.0, 0.0])
	if tack > 0.3:
		# The hand that led before the tack goes onto the mast and stays there.
		var mast_hand: int = _lead_side
		for side: int in [LEFT, RIGHT]:
			if grips.holds[side] == FigureHands.Hold.MAST:
				mast_hand = side
		wanted_holds[mast_hand] = FigureHands.Hold.MAST
		wanted_along[mast_hand] = TACK_HAND_BELOW_BOOM_M
		wanted_along[1 - mast_hand] = TACK_BACK_HAND_ON_BOOM_M
	else:
		wanted_along[front] = front_m
		wanted_along[back] = back_m
	# The rig flipping: the hand that is not on the mast and not at the front lets go; the other
	# holds on where it is.
	if rig_flipping and dt >= 0.0:
		if _flip_free_side < 0:
			_flip_free_side = back
			for side: int in [LEFT, RIGHT]:
				if grips.holds[side] == FigureHands.Hold.MAST:
					_flip_free_side = 1 - side
		var holding: int = 1 - _flip_free_side
		wanted_holds[_flip_free_side] = FigureHands.Hold.FREE
		if grips.holds[holding] == FigureHands.Hold.BOOM and not grips.is_reaching(holding):
			wanted_along[holding] = grips.along_m[holding]
	else:
		_flip_free_side = -1
	var first: int = front
	if tack > 0.3:
		first = _lead_side
		for side: int in [LEFT, RIGHT]:
			if grips.holds[side] == FigureHands.Hold.MAST:
				first = 1 - side
	grips.update(wanted_holds, wanted_along, first, dt)
	for side: int in [LEFT, RIGHT]:
		hand_targets[side] = grips.positions[side]


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


## The hips follow the place worked out above (_place_pelvis) like a body on springy legs: a
## critically damped spring (BODY_OMEGA) in the board's level frame (its heading, upright:
## DrawnRig.level_basis). When the board pitches, rolls and heaves in the chop the body does not
## follow it tick by tick: the legs give (the knees bend and stretch) and the upper body stays
## steadier than the board, as a sailor rides the chop on soft knees. The simulation's own
## movements of the body (the hike, the weight going back, its legs taking a wave over half a
## second) are slower than the spring and come through; the tick-to-tick jitter does not.
func _steady_pelvis(sim: WindsurferSim, dt: float) -> void:
	var board_basis: Basis = sim.body.basis
	var to_level: Basis = DrawnRig.level_basis(board_basis).transposed() * board_basis
	var target: Vector3 = to_level * pelvis
	if dt < 0.0:
		_pelvis_level = target
		_pelvis_velocity = Vector3.ZERO
	else:
		var state: PackedVector3Array = VisualMath.spring_vector(_pelvis_level, _pelvis_velocity, target, BODY_OMEGA, dt)
		_pelvis_level = state[0]
		_pelvis_velocity = state[1]
	pelvis = to_level.transposed() * _pelvis_level
	_set_pelvis_axes()
	_to_level = to_level


## After the spring: the legs must still reach the feet (fixed limbs); if not, the hips move the
## rest of the way, and the spring carries on from there. An arm that cannot reach its hand pulls
## the hips only part of the way each tick (ARM_PULL_SHARE): pulled all the way, the arms and the
## legs pulled the hips back and forth every tick when both were at their limit, and the body shook.
func _keep_in_reach(hike: float) -> void:
	var before: Vector3 = pelvis
	_keep_legs_in_reach()
	var arm_reach: float = ARM_REACH_SHARE * arm_length_m()
	for side: int in [LEFT, RIGHT]:
		_place_torso(hike)
		var arm: Vector3 = hand_targets[side] - shoulders[side]
		if arm.length() > arm_reach:
			pelvis += arm.normalized() * (arm.length() - arm_reach) * ARM_PULL_SHARE
	_keep_legs_in_reach()
	var moved: Vector3 = _to_level * (pelvis - before)
	if moved.length_squared() > 1e-10:
		# The spring carries on from there, without its speed into the limit (else it pushed
		# against the leg's reach every tick and the hips shook).
		_pelvis_level = _to_level * pelvis
		var into_limit: Vector3 = -moved.normalized()
		_pelvis_velocity -= into_limit * maxf(_pelvis_velocity.dot(into_limit), 0.0)


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
	var chain: PackedVector3Array = solve_two_bone(pelvis, hands_middle, torso_m, _comfortable_reach_m(hike), Vector3.UP)
	neck = chain[0]
	_build_chest(hike)


## Which way the shoulder line runs (the sailor's right), once a tick: parallel to the line between
## the hands when the hands are where the body faces them (the chest leans a little sideways for
## it, as a body does, so both arms reach equally far), and across the way the body faces when they
## are not (crossed over in a gybe, one up on the mast in a tack). It turns smoothly: a shoulder
## line taken from the hands every tick flipped round whenever the hands crossed.
func _update_chest_right(dt: float) -> void:
	var body_right: Vector3 = facing_dir().cross(Vector3.UP).normalized()
	var wanted: Vector3 = body_right
	var across: Vector3 = hand_targets[RIGHT] - hand_targets[LEFT]
	if across.length() > 0.15:
		var along_hands: Vector3 = across.normalized()
		var share: float = smoothstep(0.1, 0.5, along_hands.dot(body_right))
		wanted = body_right.lerp(along_hands, share).normalized()
	if dt < 0.0 or _chest_right.length() < 0.5 or _chest_right.dot(wanted) < -0.5:
		_chest_right = wanted
	else:
		var turned: Vector3 = _chest_right.lerp(wanted, 1.0 - exp(-CHEST_OMEGA * dt))
		_chest_right = turned.normalized() if turned.length() > 1e-4 else wanted


## The chest on the neck (worked out by _place_torso or steadied by _steady_torso): the middle of
## the back, the chest's axes along the shoulder line, the shoulders, and the pelvis tilted half
## way between the legs and the torso.
func _build_chest(hike: float) -> void:
	# The middle of the back: half way up, the belly pushed toward the sail when hanging in
	# the harness (an arched back: the hips forward, the chest open and up).
	var spine_line: Vector3 = (neck - pelvis).normalized()
	var belly: Vector3 = facing_dir() - spine_line * facing_dir().dot(spine_line)
	spine = pelvis.lerp(neck, 0.5) + belly.normalized() * (SPINE_ARCH_M * hike)
	# The chest follows the upper half of the back.
	var right: Vector3 = _chest_right
	var up: Vector3 = (neck - spine) - right * (neck - spine).dot(right)
	up = up.normalized()
	right = (right - up * right.dot(up)).normalized()
	# The chest faces the way the body faces (z out of the back): the shoulder line comes from the
	# way the body faces, so it never turns the chest round (flipping it here when the torso leaned
	# far threw the shoulders from one side to the other in one tick).
	var back: Vector3 = right.cross(up)
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


## The upper body is steadied like the hips (_steady_pelvis): the neck's place from the hips follows
## through a spring in the board's level frame, so the chest does not whip about when the hands
## move with the rig (the rig flipping, the rake swung across at a tack). The torso keeps its length.
func _steady_torso(hike: float, dt: float) -> void:
	var target: Vector3 = _to_level * (neck - pelvis)
	if dt < 0.0:
		_neck_level = target
		_neck_velocity = Vector3.ZERO
	else:
		var state: PackedVector3Array = VisualMath.spring_vector(_neck_level, _neck_velocity, target, NECK_OMEGA, dt)
		_neck_level = state[0]
		_neck_velocity = state[1]
	var up_the_back: Vector3 = _to_level.transposed() * _neck_level
	if up_the_back.length() < 1e-4:
		up_the_back = Vector3.UP
	neck = pelvis + up_the_back.normalized() * torso_m
	_build_chest(hike)


## A point on the spine: one smooth curve (a quadratic Bezier curve) from the pelvis (t = 0)
## through the middle of the back (spine, t = 0.5) to the point between the shoulders (neck,
## t = 1). The figure lays the torso's pieces along it.
func spine_point(t: float) -> Vector3:
	# The curve's control point, chosen so that the curve passes through `spine` half way.
	var control: Vector3 = 2.0 * spine - 0.5 * (pelvis + neck)
	var u: float = 1.0 - t
	return u * u * pelvis + 2.0 * u * t * control + t * t * neck


## The torso's orientation along the piece of the spine from `t_from` to `t_to`: up along
## that piece of the curve, the right side turned gradually from the hip line (pelvis_basis)
## at the bottom to the shoulder line (chest_basis) at the top. A real back twists over its
## whole length, not at one joint.
func spine_basis(t_from: float, t_to: float) -> Basis:
	var up: Vector3 = spine_point(t_to) - spine_point(t_from)
	if up.length() < 1e-5:
		up = chest_basis.y
	up = up.normalized()
	var t_middle: float = 0.5 * (t_from + t_to)
	var turned: Basis = Basis(Quaternion(pelvis_basis).slerp(Quaternion(chest_basis), t_middle))
	var right: Vector3 = turned.x - up * turned.x.dot(up)
	if right.length() < 1e-5:
		right = turned.z.cross(up)
	right = right.normalized()
	return Basis(right, up, right.cross(up))


## The arms: from each shoulder to its hand, the elbow pointing down and out. The elbow's way is
## kept square to the arm and turned smoothly from tick to tick (ELBOW_OMEGA), and kept from the
## last tick when the arm points along it: an elbow never flips over from one side of the arm to
## the other in one tick.
func _place_arms(dt: float) -> void:
	for side: int in [LEFT, RIGHT]:
		var outward: Vector3 = (shoulders[side] - neck).normalized()
		var pole: Vector3 = Vector3.DOWN + outward * 0.6 + chest_basis.z * 0.2
		var arm: Vector3 = hand_targets[side] - shoulders[side]
		arm = arm.normalized() if arm.length() > 1e-4 else Vector3.DOWN
		var out: Vector3 = pole - arm * pole.dot(arm)
		if out.length() < 0.3:
			out = _elbow_out[side] - arm * _elbow_out[side].dot(arm)
		if out.length() < 1e-4:
			out = chest_basis.z - arm * chest_basis.z.dot(arm)
		out = out.normalized()
		if dt >= 0.0:
			out = _elbow_out[side].lerp(out, 1.0 - exp(-ELBOW_OMEGA * dt))
			out = out - arm * out.dot(arm)
			out = out.normalized() if out.length() > 1e-4 else _elbow_out[side]
		_elbow_out[side] = out
		var chain: PackedVector3Array = solve_two_bone(shoulders[side], hand_targets[side], upper_arm_m, forearm_m + hand_m, out)
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
## (over the front shoulder toward the bow, and into a turn: `yaw_dps`, the board's yaw rate as the
## sailor feels it), at most HEAD_TURN_MAX_RAD from the way the chest faces. The look turns
## smoothly (a sailor's eyes stay on where they go, not on every twitch of the board).
func _place_head(yaw_dps: float, dt: float) -> void:
	var up: Vector3 = (chest_basis.y + Vector3.UP).normalized()
	head = neck + up * neck_m
	# The board's yaw rate, positive turning to port (a turn about +y), carries the look
	# into the turn.
	var turn: float = clampf(deg_to_rad(yaw_dps) * LOOK_AHEAD_S, -LOOK_TURN_MAX_RAD, LOOK_TURN_MAX_RAD)
	var wanted: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, turn)
	var chest_forward: Vector3 = -chest_basis.z
	chest_forward.y = 0.0
	if chest_forward.length() < 0.05:
		chest_forward = facing_dir()
	chest_forward = chest_forward.normalized()
	var angle: float = clampf(chest_forward.signed_angle_to(wanted, Vector3.UP), -HEAD_TURN_MAX_RAD, HEAD_TURN_MAX_RAD)
	# The look, as an angle from the bow, follows smoothly.
	var look_rad: float = Vector3.FORWARD.signed_angle_to(chest_forward.rotated(Vector3.UP, angle), Vector3.UP)
	if dt >= 0.0:
		look_rad = _look_rad.value + angle_difference(_look_rad.value, look_rad)
	look_rad = _look_rad.follow(look_rad, POSTURE_OMEGA, dt)
	var look: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, look_rad)
	var back: Vector3 = -(look - up * look.dot(up)).normalized()
	var right: Vector3 = up.cross(back).normalized()
	head_basis = Basis(right, back.cross(right), back)


## The harness: the hook in front of the hips, the lines to the boom either side of the
## grip (on the windward arm of the boom as it is drawn). Hooked in while the line carries a real
## load, never in a tack or while the rig flips.
func _place_harness(sim: WindsurferSim, tack: float, rig_flipping: bool) -> void:
	if hooked:
		hooked = sim.harness_tension_n > HOOK_OUT_TENSION_N
	else:
		hooked = sim.harness_tension_n > HOOK_IN_TENSION_N
	# A sailor hooks in to hang out against the pull, not while standing up by the mast.
	hooked = hooked and absf(sim.lean) > HOOKED_MIN_LEAN and tack < 0.01 and absf(facing_side) > 0.99 and not rig_flipping
	hook = pelvis - pelvis_basis.z * HOOK_FORWARD_M + pelvis_basis.y * HOOK_UP_M
	var grip_m: float = sim.sailor_config.hand_grip_m
	for end: int in 2:
		var along: float = grip_m + (HARNESS_LINE_SPREAD_M if end == 1 else -HARNESS_LINE_SPREAD_M)
		harness_line_ends[end] = grips.point_of(FigureHands.Hold.BOOM, along, end)
