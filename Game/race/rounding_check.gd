class_name RoundingCheck
extends RefCounted
## When a board has done a step of a race course (RACING_PLAN.md, "When a mark counts as
## rounded"): crossed a line the right way, or gone round a mark on the side it is left on. All of
## the race's geometry is here, in one place, so that a board can neither cut a corner nor be
## refused a fair rounding, and the tests can check every case.
##
## Each check looks at one move of a board: the straight line from where it was at the last tick to
## where it is now (game metres, Vector2(X east, Z south), as in Course). A board moves well under a
## metre in a tick, so the moves together are its track.
##
## "Clockwise" is as seen from above with north up, as on the course maker's map. A board leaving a
## mark to starboard (on its right) goes round it clockwise; leaving it to port, anticlockwise
## (CourseMark.Rounding).
##
## The start line's gun and the boards over it early are the race's business (RaceSim): here the
## start is a line like the others.

## A rounding counts only where the board crosses the rounding ray this close to the mark, metres:
## a board that goes round further out has not rounded the mark.
const ROUNDING_REACH_M: float = 80.0
## A course that bends less than this at a mark (degrees) goes straight past it: the mark is
## passed, not rounded, as Course.natural_side() treats it.
const STRAIGHT_ON_DEG: float = 5.0


## What one move of a board did at a step of the course.
class Outcome:
	## True when the move completed the step.
	var done: bool = false
	## Where along the move the board crossed: 0 at the last position, 1 at this one, -1 when it
	## did not. The race clock uses it to time the crossing between two ticks.
	var fraction: float = -1.0
	## True when the move went round or past the mark on the wrong side, for the HUD's warning.
	## A wrong-side move never completes the step.
	var wrong_side: bool = false


## Checks one move against one step of the course.
static func check(step: RaceStep, previous: Vector2, current: Vector2) -> Outcome:
	if step.kind == RaceStep.Kind.MARK:
		return round_mark(previous, current, step.points[0], step.in_dir, step.out_dir, step.side)
	var outcome: Outcome = Outcome.new()
	outcome.fraction = across_line(previous, current, step.points[0], step.points[1], step.in_dir)
	outcome.done = outcome.fraction >= 0.0
	return outcome


# ---------------------------------------------------------------- lines: the start, the finish, a gate

## Where a move crosses the line between two ends going forward (the leg's direction), as a
## fraction of the move; -1 if it does not. Crossing beyond the ends, or backwards, does not count.
static func across_line(previous: Vector2, current: Vector2, end_a: Vector2, end_b: Vector2, forward: Vector2) -> float:
	var before: float = over_line_m(previous, end_a, end_b, forward)
	var after: float = over_line_m(current, end_a, end_b, forward)
	# From behind the line to on it or over it. A point exactly on the line counts as over, so a
	# board that stops on the line has crossed it once, not twice.
	if not (before < 0.0 and after >= 0.0):
		return -1.0
	var fraction: float = before / (before - after)
	var crossing: Vector2 = previous.lerp(current, fraction)
	# Where the crossing is along the line: 0 at one end, 1 at the other.
	var along: float = (crossing - end_a).dot(end_b - end_a) / end_a.distance_squared_to(end_b)
	if along < 0.0 or along > 1.0:
		return -1.0
	return fraction


## How far a point is over the line or its extensions, metres: positive on the side the leg goes
## on (the course side of the start line), negative behind it.
static func over_line_m(point: Vector2, end_a: Vector2, end_b: Vector2, forward: Vector2) -> float:
	var across: Vector2 = (end_b - end_a).normalized().orthogonal()
	# The line's normal, turned to point the way the leg goes (whichever end is called a).
	if across.dot(forward) < 0.0:
		across = -across
	return (point - end_a).dot(across)


# ---------------------------------------------------------------- a mark with a rounding side

## Whether a move rounded a mark: crossed its rounding ray (rounding_ray()), at most
## ROUNDING_REACH_M from the mark, going round the mark the way its side says. in_dir and out_dir
## are the directions of the legs arriving at the mark and leaving it.
##
## The outcome also says when the move went the wrong side of the mark: round it the other way
## (across the same ray, the other way round), or past it on the inside of the turn while sailing
## on along the next leg (across the opposite ray, the other way round).
static func round_mark(previous: Vector2, current: Vector2, mark: Vector2, in_dir: Vector2, out_dir: Vector2, side: CourseMark.Rounding) -> Outcome:
	var outcome: Outcome = Outcome.new()
	var way: float = turn_way(side)
	var ray: Vector2 = rounding_ray(in_dir, out_dir, side)
	outcome.fraction = _across_ray(previous, current, mark, ray, way)
	outcome.done = outcome.fraction >= 0.0
	if outcome.done:
		return outcome
	var wrong_way_round: bool = _across_ray(previous, current, mark, ray, -way) >= 0.0
	# On the inside of the turn only a board sailing on along the next leg is warned. At a windward
	# mark the inside ray lies along the beat, straight downwind of the mark, and boards tacking up
	# to the mark cross it all the time; they move against the leg out, which runs downwind.
	var sailing_on: bool = (current - previous).dot(out_dir) > 0.0
	var cut_inside: bool = sailing_on and _across_ray(previous, current, mark, -ray, -way) >= 0.0
	outcome.wrong_side = wrong_way_round or cut_inside
	return outcome


## The direction of a mark's rounding ray from the mark, one metre long: where a board is when it is
## half-way round. A board comes along the leg in and leaves along the leg out, going round the
## mark on the outside of the turn, so half-way round it is along in - out: straight upwind of a
## windward mark where the course turns back, out of the turn at a slalom mark. A mark the course
## goes straight past (bending less than STRAIGHT_ON_DEG) is passed, not rounded: half-way past,
## the board is abeam of it, on the side away from the side the mark is left on.
static func rounding_ray(in_dir: Vector2, out_dir: Vector2, side: CourseMark.Rounding) -> Vector2:
	if in_dir.dot(out_dir) <= cos(deg_to_rad(STRAIGHT_ON_DEG)):
		return (in_dir - out_dir).normalized()
	# A board going round clockwise (the mark to starboard, on its right) is on the mark's left:
	# the leg's direction turned a quarter anticlockwise, which orthogonal() does in these axes.
	return in_dir.orthogonal() * turn_way(side)


## The way a board goes round a mark: 1 for clockwise (the mark left to starboard), -1 for
## anticlockwise (to port). A mark with no side is taken as port, as Course.natural_side() does.
static func turn_way(side: CourseMark.Rounding) -> float:
	return 1.0 if side == CourseMark.Rounding.STARBOARD else -1.0


## How far a point (given from the mark) lies clockwise of a ray from the mark, metres: positive
## clockwise of it, negative anticlockwise. With X east and Z south, east is clockwise of north:
## for the ray (0, -1) and the point (1, 0) this gives 0 * 0 - (-1) * 1 = 1.
static func clockwise_of(ray: Vector2, offset: Vector2) -> float:
	return ray.x * offset.y - ray.y * offset.x


## Where a move crosses the ray from a mark along a direction (one metre long), at most
## ROUNDING_REACH_M out, going round the mark one way (1 clockwise, -1 anticlockwise): as a fraction
## of the move, or -1 if it does not.
static func _across_ray(previous: Vector2, current: Vector2, mark: Vector2, ray: Vector2, way: float) -> float:
	# Going round the mark clockwise carries a board from the ray's anticlockwise side to its
	# clockwise side; anticlockwise the other way. Multiplied by the way, both read "from below 0
	# to 0 or above".
	var before: float = clockwise_of(ray, previous - mark) * way
	var after: float = clockwise_of(ray, current - mark) * way
	if not (before < 0.0 and after >= 0.0):
		return -1.0
	var fraction: float = before / (before - after)
	# How far out along the ray the board crossed. Negative is the opposite ray, on the mark's other
	# side: that is another ray.
	var out_m: float = (previous.lerp(current, fraction) - mark).dot(ray)
	if out_m < 0.0 or out_m > ROUNDING_REACH_M:
		return -1.0
	return fraction
