class_name DrawnRig
extends RefCounted
## The rig as it is drawn, one step behind the physics' rig (sailor polish, 6 November 2026). Two
## things looked wrong when the rig was drawn exactly where the simulation holds it:
## - In the chop the physics' rig (RigFrame) jitters from one tick to the next: at 24 kt on the
##   lake the mast's top moved 27 cm in one tick a hundredth of the time (figure_motion.gd's
##   measurement), and the hands on the boom shook with it.
## - When the sail changes sides the physics turns the boom over in one tick (SailModel.sail_side
##   flips): in a gybe the clew jumped 4.4 m from one side to the other.
## So the drawn mast and boom follow the physics' through a critically damped spring (VisualMath.
## spring_vector): the tick-to-tick jitter goes, the real swings of the rig (the sheeting, the rig
## pulled to windward, a second or so) stay. The spring works in the board's level frame (its
## heading, not its heel and pitch), so the rig stays upright in the world as the board rolls
## under it, as the physics means. And when the sail changes sides the boom swings across round
## the mast: in a tack through the back of the board (the sail is sheeted in, the clew passes over
## the tail), in a gybe through the front (the rig flip: the clew goes round the nose), in about
## half a second to three quarters of a second, as a sailor flips a rig. It only draws: nothing
## here feeds back into the physics (CLAUDE.md, rule 2).

## How quickly the drawn rig follows the physics' (radians a second: a jump is followed within
## about a fifth of a second; the tick-to-tick jitter, 30 times a second, is gone).
const FOLLOW_OMEGA: float = 22.0
## The drawn mast and boom turn at most this fast (radians a second). The physics' rig can turn in
## one tick: at a tack's flip the beginner's helm swings the rake from full back to full forward
## at once (PlayerController, the rake follows the tack), which moved the mast's top 3.6 m in a
## fifth of a second even through the spring. A sailor throws a rig across in about half a second.
const MAST_MAX_RATE_RAD_S: float = 2.5
const BOOM_MAX_RATE_RAD_S: float = 4.0
## A change of sides: the boom on the other side of the board by at least this much (the x of its
## direction in the board's axes) and this far round from where it is drawn.
const FLIP_SIDE_X: float = 0.1
const FLIP_MIN_RAD: float = 0.5
## The boom swings round at this rate (radians a second), taking at least FLIP_MIN_S.
const FLIP_RATE_RAD_S: float = 5.0
const FLIP_MIN_S: float = 0.35
## A boom within this angle of the board's tail swings across through the tail (a tack); further
## out, through the nose (a gybe's rig flip).
const TACK_SWING_MAX_RAD: float = 0.9

## The drawn mast and boom, unit vectors in the board's axes, and whether the boom is swinging
## across now.
var mast_dir: Vector3 = Vector3.UP
var boom_dir: Vector3 = Vector3.BACK
var flipping: bool = false

# The state in the level frame (the board's heading, upright).
var _mast_level: Vector3 = Vector3.UP
var _mast_speed: Vector3 = Vector3.ZERO
var _boom_level: Vector3 = Vector3.BACK
var _boom_speed: Vector3 = Vector3.ZERO
var _has_pose: bool = false
# The swing across: where the boom started (level frame), the angle to go round the mast
# (signed), how long it takes and how far it has got.
var _flip_start: Vector3 = Vector3.BACK
var _flip_angle_rad: float = 0.0
var _flip_time_s: float = 0.0
var _flip_progress: float = 0.0


## Draws the rig exactly where the physics has it from now on (a reset, a waterstart).
func snap() -> void:
	_has_pose = false
	flipping = false


## One tick: the physics' mast and boom directions in the board's axes, the board's orientation in
## the world, and the time since the last tick (negative, or a gap over half a second: put
## straight where the physics has it).
func update(physics_mast: Vector3, physics_boom: Vector3, board_basis: Basis, dt: float) -> void:
	var level: Basis = level_basis(board_basis)
	# From the board's axes to the level frame and back.
	var to_level: Basis = level.transposed() * board_basis
	var mast_target: Vector3 = (to_level * physics_mast).normalized()
	var boom_target: Vector3 = (to_level * physics_boom).normalized()
	if not _has_pose or dt < 0.0 or dt > 0.5:
		_mast_level = mast_target
		_boom_level = boom_target
		_mast_speed = Vector3.ZERO
		_boom_speed = Vector3.ZERO
		flipping = false
		_has_pose = true
	else:
		var mast_state: PackedVector3Array = VisualMath.spring_vector(_mast_level, _mast_speed, mast_target, FOLLOW_OMEGA, dt)
		var mast_now: Vector3 = _limited_turn(_mast_level, mast_state[0].normalized(), MAST_MAX_RATE_RAD_S * dt)
		_mast_speed = mast_state[1] if mast_now.is_equal_approx(mast_state[0].normalized()) else (mast_now - _mast_level) / dt
		_mast_level = mast_now
		_follow_boom(boom_target, physics_boom, to_level, dt)
	var to_board: Basis = to_level.transposed()
	mast_dir = (to_board * _mast_level).normalized()
	boom_dir = (to_board * _boom_level).normalized()


## The board's heading as a frame: its forward direction made level, y straight up.
static func level_basis(board_basis: Basis) -> Basis:
	var aft: Vector3 = board_basis.z
	aft.y = 0.0
	if aft.length() < 1e-4:
		aft = board_basis.y.cross(board_basis.x)
		aft.y = 0.0
	aft = aft.normalized()
	var right: Vector3 = Vector3.UP.cross(aft).normalized()
	return Basis(right, Vector3.UP, aft)


## The boom: following the physics' through the spring, or swinging across round the mast when the
## sail has changed sides.
func _follow_boom(boom_target: Vector3, physics_boom: Vector3, to_level: Basis, dt: float) -> void:
	var drawn_board: Vector3 = to_level.transposed() * _boom_level
	var other_side: bool = signf(physics_boom.x) != signf(drawn_board.x) and absf(physics_boom.x) > FLIP_SIDE_X
	if not flipping and other_side and _boom_level.angle_to(boom_target) > FLIP_MIN_RAD:
		_start_flip(boom_target)
	if flipping:
		_flip_progress = minf(_flip_progress + dt / _flip_time_s, 1.0)
		var eased: float = smoothstep(0.0, 1.0, _flip_progress)
		var round_the_mast: Vector3 = _flip_start.rotated(_mast_level, _flip_angle_rad * eased)
		# The last part blends onto the physics' boom (its dip and its angle of the moment).
		_boom_level = round_the_mast.slerp(boom_target, smoothstep(0.75, 1.0, _flip_progress)).normalized()
		_boom_speed = Vector3.ZERO
		if _flip_progress >= 1.0:
			flipping = false
		return
	var boom_state: PackedVector3Array = VisualMath.spring_vector(_boom_level, _boom_speed, boom_target, FOLLOW_OMEGA, dt)
	var boom_now: Vector3 = _limited_turn(_boom_level, boom_state[0].normalized(), BOOM_MAX_RATE_RAD_S * dt)
	_boom_speed = boom_state[1] if boom_now.is_equal_approx(boom_state[0].normalized()) else (boom_now - _boom_level) / dt
	_boom_level = boom_now


## A direction turned from `from` toward `to` by at most `max_rad`.
static func _limited_turn(from: Vector3, to: Vector3, max_rad: float) -> Vector3:
	var angle: float = from.angle_to(to)
	if angle <= max_rad or angle < 1e-6:
		return to
	return from.slerp(to, max_rad / angle).normalized()


## Starts the swing across: round the mast through the tail (a tack, the boom near the
## centreline) or through the nose (a gybe's rig flip, the boom well out).
func _start_flip(boom_target: Vector3) -> void:
	flipping = true
	_flip_progress = 0.0
	_flip_start = _boom_level
	var axis: Vector3 = _mast_level
	var from_flat: Vector3 = (_boom_level - axis * _boom_level.dot(axis)).normalized()
	var to_flat: Vector3 = (boom_target - axis * boom_target.dot(axis)).normalized()
	var short_way: float = from_flat.signed_angle_to(to_flat, axis)
	# The short way round passes the tail when both ends are aft of the mast's line across the
	# board; the boom of a tack is within TACK_SWING_MAX_RAD of the tail.
	var aft_now: float = from_flat.angle_to(Vector3.BACK)
	var through_tail: bool = aft_now < TACK_SWING_MAX_RAD
	var mid_way: Vector3 = from_flat.rotated(axis, 0.5 * short_way)
	var short_passes_tail: bool = mid_way.z > 0.0
	var angle: float = short_way
	if through_tail != short_passes_tail:
		angle = short_way - signf(short_way) * TAU
	_flip_angle_rad = angle
	_flip_time_s = maxf(absf(angle) / FLIP_RATE_RAD_S, FLIP_MIN_S)
