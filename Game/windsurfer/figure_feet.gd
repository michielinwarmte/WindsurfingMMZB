class_name FigureFeet
extends RefCounted
## The sailor figure's feet (sailor polish, 6 November 2026): where each foot stands on the deck,
## and how it gets to a new place. A real sailor's foot is either planted (it does not slide over
## the deck: the weight moves with the hips and the knees) or it takes a step: it lifts, moves and
## is put down again, one foot at a time, the other one carrying the weight. Before this the
## figure's feet followed the simulation's feet point every tick, so they slid along the deck as
## the weight moved, and popped when it jumped.
##
## FigureSkeleton tells it every tick where each foot should stand (the straps while planing, near
## the mast at rest, round the front of the mast in a tack) and which way its toes should point;
## this decides when a foot steps and where it is during the step. Everything is in the board's
## own axes (x starboard, y up, z aft). Nothing here feeds back into the physics.

## A step takes this long (a quick step on a moving board: lift, swing, put down).
const STEP_TIME_S: float = 0.3
## How high the foot lifts at the middle of a step.
const STEP_HEIGHT_M: float = 0.07
## A foot steps when where it should stand is this far from where it stands. Smaller moves are
## the weight shifting over the feet, not a step.
const STEP_START_M: float = 0.08
## A planted foot turns on the ball of the foot (no step) at up to this rate, and steps instead
## when it has to turn further than STEP_TURN_RAD.
const PIVOT_RATE_RAD_S: float = 2.5
const STEP_TURN_RAD: float = 0.7
## A step passes at least this far from the mast foot (it goes round the front of it).
const MAST_CLEAR_M: float = 0.18

const LEFT: int = 0
const RIGHT: int = 1

## Where each foot is now: the point on the deck under the ankle (lifted during a step), and which
## way the toes point (a horizontal unit vector).
var ground: PackedVector3Array = PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
var dirs: PackedVector3Array = PackedVector3Array([Vector3.FORWARD, Vector3.FORWARD])
## How high each foot is lifted off the deck now (0 when planted).
var lift: PackedFloat64Array = PackedFloat64Array([0.0, 0.0])

# Where each foot stands (when planted) and the step under way: where it lifted, where it goes
# (chosen as it lifts: a step goes where the foot was meant to go then; if the place has moved on
# by the time it lands, the next step follows), and its progress (-1: planted).
var _planted: PackedVector3Array = PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
var _planted_dirs: PackedVector3Array = PackedVector3Array([Vector3.FORWARD, Vector3.FORWARD])
var _from: PackedVector3Array = PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
var _from_dirs: PackedVector3Array = PackedVector3Array([Vector3.FORWARD, Vector3.FORWARD])
var _to: PackedVector3Array = PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
var _to_dirs: PackedVector3Array = PackedVector3Array([Vector3.FORWARD, Vector3.FORWARD])
var _progress: PackedFloat64Array = PackedFloat64Array([-1.0, -1.0])
var _has_pose: bool = false


## Puts both feet where they should stand at once (the first pose, after a reset or a fall).
func snap(wanted: PackedVector3Array, wanted_dirs: PackedVector3Array) -> void:
	for side: int in [LEFT, RIGHT]:
		_planted[side] = wanted[side]
		_planted_dirs[side] = wanted_dirs[side]
		_progress[side] = -1.0
		ground[side] = wanted[side]
		dirs[side] = wanted_dirs[side]
		lift[side] = 0.0
	_has_pose = true


## One tick: `wanted` is where each foot should stand, `wanted_dirs` which way its toes should
## point, `dt` the time since the last tick (negative: put straight in place), `mast_foot` where the mast
## stands (steps go round it), and `front` the foot that leads (it steps first when both have to).
func update(wanted: PackedVector3Array, wanted_dirs: PackedVector3Array, dt: float, mast_foot: Vector3, front: int) -> void:
	if not _has_pose or dt < 0.0:
		snap(wanted, wanted_dirs)
		return
	# A step under way carries on to where it goes, and lands there.
	var stepping: int = -1
	for side: int in [LEFT, RIGHT]:
		if _progress[side] < 0.0:
			continue
		_progress[side] = minf(_progress[side] + dt / STEP_TIME_S, 1.0)
		if _progress[side] >= 1.0:
			_progress[side] = -1.0
			_planted[side] = _to[side]
			_planted_dirs[side] = _to_dirs[side]
		else:
			stepping = side
	# A new step only with both feet on the deck: the one further from its place goes, the front
	# foot first when both are as far.
	if stepping < 0:
		var gaps: PackedFloat64Array = PackedFloat64Array([0.0, 0.0])
		for side: int in [LEFT, RIGHT]:
			var turn: float = _planted_dirs[side].angle_to(wanted_dirs[side])
			gaps[side] = _planted[side].distance_to(wanted[side]) + (1.0 if turn > STEP_TURN_RAD else 0.0)
		var first: int = front if gaps[front] >= gaps[1 - front] - 0.02 else 1 - front
		if gaps[first] > STEP_START_M:
			_start_step(first, wanted[first], wanted_dirs[first])
			stepping = first
	# The feet that stand turn on the spot toward the way they should point.
	for side: int in [LEFT, RIGHT]:
		if _progress[side] < 0.0:
			_planted_dirs[side] = _turn_toward(_planted_dirs[side], wanted_dirs[side], PIVOT_RATE_RAD_S * dt)
			ground[side] = _planted[side]
			dirs[side] = _planted_dirs[side]
			lift[side] = 0.0
		else:
			_place_in_step(side, mast_foot)


## Whether a foot is in the air now.
func is_stepping(side: int) -> bool:
	return _progress[side] >= 0.0


func _start_step(side: int, to: Vector3, to_dir: Vector3) -> void:
	_progress[side] = 0.0
	_from[side] = _planted[side]
	_from_dirs[side] = _planted_dirs[side]
	_to[side] = to
	_to_dirs[side] = to_dir


## Where a foot is part way through its step: on a curve from where it lifted to where it goes,
## lifted most at the middle, and passing in front of the mast foot rather than through it. The
## progress is eased (slow off the deck, quick in the middle, slow onto the deck), as a foot moves.
func _place_in_step(side: int, mast_foot: Vector3) -> void:
	var t: float = smoothstep(0.0, 1.0, _progress[side])
	var from: Vector3 = _from[side]
	var to: Vector3 = _to[side]
	var to_dir: Vector3 = _to_dirs[side]
	var middle: Vector3 = 0.5 * (from + to)
	# Round the front of the mast: if the straight line passes the mast foot closer than
	# MAST_CLEAR_M, the middle of the curve goes ahead of the mast.
	var closest: Vector3 = _closest_on_segment(mast_foot, from, to)
	var off: Vector3 = Vector3(closest.x - mast_foot.x, 0.0, closest.z - mast_foot.z)
	if off.length() < MAST_CLEAR_M:
		var ahead_z: float = mast_foot.z - 1.6 * MAST_CLEAR_M
		middle.z = minf(middle.z, ahead_z)
	var curve: Vector3 = (1.0 - t) * (1.0 - t) * from + 2.0 * (1.0 - t) * t * middle + t * t * to
	var up: float = STEP_HEIGHT_M * sin(PI * _progress[side])
	ground[side] = curve + Vector3.UP * up
	lift[side] = up
	dirs[side] = _from_dirs[side].slerp(to_dir, t).normalized() if _from_dirs[side].dot(to_dir) > -0.99 else to_dir


static func _closest_on_segment(point: Vector3, a: Vector3, b: Vector3) -> Vector3:
	var ab: Vector3 = Vector3(b.x - a.x, 0.0, b.z - a.z)
	var length_squared: float = ab.length_squared()
	if length_squared < 1e-8:
		return a
	var t: float = clampf(Vector3(point.x - a.x, 0.0, point.z - a.z).dot(ab) / length_squared, 0.0, 1.0)
	return a + (b - a) * t


## A horizontal direction turned toward another by at most `max_rad`.
static func _turn_toward(from: Vector3, to: Vector3, max_rad: float) -> Vector3:
	var angle: float = from.signed_angle_to(to, Vector3.UP)
	return from.rotated(Vector3.UP, clampf(angle, -max_rad, max_rad)).normalized()
