class_name FigureHands
extends RefCounted
## The sailor figure's hands on the rig (sailor polish, 6 November 2026). A real sailor's hand
## holds the boom at one place and moves with it; it slides along the boom a little at a time, or
## lets go and takes hold again further along (a regrip), one hand at a time, the other holding
## on. In a tack the front hand goes onto the mast below the boom while the sailor steps round; in
## a gybe the back hand lets go as the rig flips, crosses over and takes the boom on the new side,
## and then the other hand follows. Before this the figure's hands were put on the boom where the
## simulation's grip was every tick, so they slid back and forth along it as the body moved, and
## jumped across when the sail changed sides.
##
## Each hand holds the boom at a distance from the mast (along the windward arm of the wishbone),
## or the mast at a distance below the boom, or nothing (free, while the rig flips). FigureSkeleton
## says every tick where each hand should hold; this decides how the hand gets there and where it
## is on the way. Everything is in the board's own axes. Nothing here feeds back into the physics.

enum Hold { BOOM, MAST, FREE }

## A holding hand slides along the boom at up to this speed (m/s), toward where it should hold.
const SLIDE_RATE_MS: float = 0.35
## Further than this from where it should hold, the hand lets go and takes a new hold instead.
const REGRIP_M: float = 0.12
## A regrip: let go, move, take hold; quicker for a short move. The hand lifts this far off the
## boom on the way (toward the sailor), so it is seen to let go.
const REACH_MIN_S: float = 0.18
const REACH_MAX_S: float = 0.4
const REACH_SPEED_MS: float = 2.2
const LET_GO_M: float = 0.06
## The windward arm of the wishbone (BOOM_ARM_HALF_WIDTH in RigVisuals, the arm's shape in
## tools/blender/build_rig_models.py): how far out from the boom's centre line it is at these
## distances from the mast, as a share of how far out it is at the grip (0.285 m).
const ARM_ALONG_M: PackedFloat64Array = [0.0, 0.05, 0.25, 0.7, 1.14, 1.65, 2.1]
const ARM_SHARE: PackedFloat64Array = [0.5, 0.65, 0.88, 1.0, 0.95, 0.72, 0.37]

const LEFT: int = 0
const RIGHT: int = 1

## The rig as it is drawn this tick (set before update()): the boom's root on the mast, the boom's
## and the mast's directions, how long the boom is, and the way out to the windward arm at the
## grip (RigVisuals.windward_arm_offset()).
var boom_root: Vector3 = Vector3.ZERO
var boom_dir: Vector3 = Vector3.BACK
var mast_dir: Vector3 = Vector3.UP
var boom_m: float = 2.2
var arm_offset: Vector3 = Vector3.ZERO
## Where a free hand waits (set by the skeleton: in front of the chest).
var free_places: PackedVector3Array = PackedVector3Array([Vector3.ZERO, Vector3.ZERO])

## What each hand holds and where (metres from the mast along the boom, or below the boom down
## the mast), and where each hand is now.
var holds: PackedInt32Array = PackedInt32Array([Hold.BOOM, Hold.BOOM])
var along_m: PackedFloat64Array = PackedFloat64Array([0.5, 0.9])
var positions: PackedVector3Array = PackedVector3Array([Vector3.ZERO, Vector3.ZERO])

# A regrip under way: what the hand reaches for, from where, how long it takes and how far it has
# got (-1: holding).
var _target_holds: PackedInt32Array = PackedInt32Array([Hold.BOOM, Hold.BOOM])
var _target_along: PackedFloat64Array = PackedFloat64Array([0.5, 0.9])
var _from: PackedVector3Array = PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
var _reach_s: PackedFloat64Array = PackedFloat64Array([0.25, 0.25])
var _progress: PackedFloat64Array = PackedFloat64Array([-1.0, -1.0])
var _has_pose: bool = false


## Both hands where they should hold at once (the first pose, after a reset or a fall).
func snap(wanted_holds: PackedInt32Array, wanted_along: PackedFloat64Array) -> void:
	for side: int in [LEFT, RIGHT]:
		holds[side] = wanted_holds[side]
		along_m[side] = wanted_along[side]
		_progress[side] = -1.0
		positions[side] = point_of(holds[side], along_m[side], side)
	_has_pose = true


## One tick. `wanted_holds` and `wanted_along` are where each hand should hold, `first` the hand
## that moves first when both have to (the new front hand), `dt` the time since the last tick
## (negative: put straight in place).
func update(wanted_holds: PackedInt32Array, wanted_along: PackedFloat64Array, first: int, dt: float) -> void:
	if not _has_pose or dt < 0.0:
		snap(wanted_holds, wanted_along)
		return
	# Regrips under way carry on; a hand that arrives takes hold.
	var reaching: int = -1
	for side: int in [LEFT, RIGHT]:
		if _progress[side] < 0.0:
			continue
		# A hand reaching for a hold it should no longer take turns to the new one.
		if _target_holds[side] != wanted_holds[side]:
			_start_reach(side, wanted_holds[side], wanted_along[side])
		else:
			_target_along[side] = wanted_along[side]
		_progress[side] = minf(_progress[side] + dt / _reach_s[side], 1.0)
		if _progress[side] >= 1.0:
			_progress[side] = -1.0
			holds[side] = _target_holds[side]
			along_m[side] = _target_along[side]
		else:
			reaching = side
	# Letting go is at once (the rig flipping): it does not wait for the other hand.
	for side: int in [LEFT, RIGHT]:
		if _progress[side] < 0.0 and wanted_holds[side] == Hold.FREE and holds[side] != Hold.FREE:
			_start_reach(side, Hold.FREE, 0.0)
	# A new regrip with both hands holding: the hand that should move first, then the other.
	if reaching < 0:
		for side: int in [first, 1 - first]:
			if _progress[side] >= 0.0:
				break
			if _needs_regrip(side, wanted_holds[side], wanted_along[side]):
				_start_reach(side, wanted_holds[side], wanted_along[side])
				break
	# Holding hands slide along toward where they should hold.
	for side: int in [LEFT, RIGHT]:
		if _progress[side] < 0.0 and holds[side] == wanted_holds[side] and holds[side] != Hold.FREE:
			along_m[side] = move_toward(along_m[side], wanted_along[side], SLIDE_RATE_MS * dt)
	for side: int in [LEFT, RIGHT]:
		positions[side] = _place(side)


## Whether a hand is moving to a new hold now.
func is_reaching(side: int) -> bool:
	return _progress[side] >= 0.0


## A point on the rig: on the windward arm of the boom `along` metres from the mast, on the mast
## `along` metres below the boom, or where a free hand waits.
func point_of(hold: int, along: float, side: int) -> Vector3:
	match hold:
		Hold.BOOM:
			return boom_root + boom_dir * along + arm_offset * arm_share(along)
		Hold.MAST:
			return boom_root - mast_dir * along
	return free_places[side]


## How far out the windward arm is at `along` metres from the mast, as a share of how far out it
## is at the grip.
func arm_share(along: float) -> float:
	var x: float = along * 2.2 / maxf(boom_m, 0.5)
	if x <= ARM_ALONG_M[0]:
		return ARM_SHARE[0]
	for i: int in range(1, ARM_ALONG_M.size()):
		if x <= ARM_ALONG_M[i]:
			var t: float = (x - ARM_ALONG_M[i - 1]) / (ARM_ALONG_M[i] - ARM_ALONG_M[i - 1])
			return lerpf(ARM_SHARE[i - 1], ARM_SHARE[i], t)
	return ARM_SHARE[ARM_SHARE.size() - 1]


func _needs_regrip(side: int, hold: int, along: float) -> bool:
	if holds[side] != hold:
		return true
	return hold != Hold.FREE and absf(along_m[side] - along) > REGRIP_M


func _start_reach(side: int, hold: int, along: float) -> void:
	var start: Vector3 = positions[side]
	_target_holds[side] = hold
	_target_along[side] = along
	_from[side] = start
	_progress[side] = 0.0
	var distance: float = start.distance_to(point_of(hold, along, side))
	_reach_s[side] = clampf(distance / REACH_SPEED_MS + REACH_MIN_S * 0.5, REACH_MIN_S, REACH_MAX_S)


## Where a hand is: on its hold, or on its way to a new one (eased, and a little off the rig toward
## the body in the middle of the move).
func _place(side: int) -> Vector3:
	if _progress[side] < 0.0:
		return point_of(holds[side], along_m[side], side)
	var t: float = smoothstep(0.0, 1.0, _progress[side])
	var target: Vector3 = point_of(_target_holds[side], _target_along[side], side)
	var path: Vector3 = _from[side].lerp(target, t)
	var toward_body: Vector3 = free_places[side] - path
	if toward_body.length() > 1e-4:
		path += toward_body.normalized() * (LET_GO_M * sin(PI * _progress[side]))
	return path
