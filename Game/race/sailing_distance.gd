class_name SailingDistance
extends RefCounted
## How far a point is from another by water, for a board that cannot sail straight into the wind and
## has no speed straight down it (AI_FLEET_PLAN.md, D6b: "the candy follows the course"). It is the
## length of the shortest way the board can sail:
##   - straight, when the target lies between the beat's track and the run's track off the wind
##     (it can be laid);
##   - inside the tacking cone (the target nearer the wind than UP_TRACK_DEG), two legs along the
##     two tacks' tracks, whose total is the upwind distance divided by the cosine of the track
##     angle, whichever tack is sailed first;
##   - inside the gybing cone (deeper than DOWN_TRACK_DEG), the same with the run's track.
## It is a true distance (the shortest sailable path), so it obeys the triangle inequality: going
## somewhere by way of a third point is never shorter. The trainer's reward (RaceEnv) is the fall
## of the remaining distance round the course, remaining_m(), each tick, which pays a board the same
## for going out to a layline as for pointing at the mark, pays nothing for a detour, and pays the
## rounding itself (the way to the mark's rounding point, past the mark on its correct side).
##
## The wind it reckons with is a direction (where the wind comes from, degrees: the course's axis,
## not the wind of the moment, so that a shift moves the board's progress and not the yardstick).
## Positions are game metres, Vector2(X east, Z south), as in Course.

## The beat's track over the ground, off the wind, degrees: the all-rounder's pointing angle and its
## leeway (SkipperConfig and Skipper's measurements: about 45 plus 5).
const UP_TRACK_DEG: float = 50.0
## The run's track over the ground, off the wind, degrees: the best downwind angle in 12 to 24 kt
## (Skipper.POLAR_SPEED_MS: 125 to 130) and the leeway.
const DOWN_TRACK_DEG: float = 130.0
## A mark's rounding point lies this far from the mark along its rounding ray (RoundingCheck): about
## where a skipper with a 10 m mark margin is half-way round.
const ROUNDING_M: float = 20.0
## The best point of a line to cross is looked for by a ternary search this many times: the point
## is found to within a millionth of the line's length.
const LINE_SEARCH_STEPS: int = 24
## The remaining distance is given to the network in units of this (metres): the longest course,
## about one iQFOiL course at full size.
const REMAINING_SCALE_M: float = 5000.0


## The sailing distance from one point to another in a wind (where it comes from, degrees).
static func to_point(from: Vector2, to: Vector2, wind_from_deg: float) -> float:
	var way: Vector2 = to - from
	var straight_m: float = way.length()
	if straight_m < 1e-6:
		return 0.0
	# How much of the way is toward the wind (positive) or down it (negative).
	var upwind_m: float = way.dot(Course.direction_of(wind_from_deg))
	var by_beating_m: float = upwind_m / cos(deg_to_rad(UP_TRACK_DEG))
	var by_running_m: float = -upwind_m / cos(deg_to_rad(180.0 - DOWN_TRACK_DEG))
	return maxf(straight_m, maxf(by_beating_m, by_running_m))


## The point a board makes for to do a step: a mark's rounding point, ROUNDING_M out along its
## rounding ray (past the mark, on the side it is left on); a line's middle (the representative
## point of a line for the chain of legs after the next step; the point to cross from a board's own
## position is best_crossing()).
static func representative(step: RaceStep) -> Vector2:
	if step.kind == RaceStep.Kind.MARK:
		return rounding_point(step)
	return step.target()


## Where a board is half-way round a mark: ROUNDING_M from it along its rounding ray.
static func rounding_point(step: RaceStep) -> Vector2:
	return step.points[0] + RoundingCheck.rounding_ray(step.in_dir, step.out_dir, step.side) * ROUNDING_M


## The best point of a line step to cross from a point, on the way to the next step's representative
## point (the finish line, with nothing after it: the nearest point by sailing distance): the point
## of the line that makes the sailing distance there and on the shortest. The distance is convex
## along the line, so a ternary search finds its lowest point.
static func best_crossing(from: Vector2, line: RaceStep, next_point: Vector2, has_next: bool, wind_from_deg: float) -> Vector2:
	var a: Vector2 = line.points[0]
	var b: Vector2 = line.points[1]
	var low: float = 0.0
	var high: float = 1.0
	for _k: int in LINE_SEARCH_STEPS:
		var t1: float = low + (high - low) / 3.0
		var t2: float = high - (high - low) / 3.0
		if _through_cost(from, a.lerp(b, t1), next_point, has_next, wind_from_deg) <= _through_cost(from, a.lerp(b, t2), next_point, has_next, wind_from_deg):
			high = t2
		else:
			low = t1
	return a.lerp(b, (low + high) / 2.0)


## The sailing distance from a point to the next step's point of a race (a mark's rounding point, or
## a line's best crossing on the way to the step after), as the board gains or loses it tick by
## tick; for a line with a step after it, less the chain's own leg from the line's middle to that
## step's representative point, which remaining_m() counts in its constant part. 0 once the board
## has finished.
static func to_next_step_m(race: RaceSim, index: int, from: Vector2, wind_from_deg: float) -> float:
	var steps: Array[RaceStep] = race.steps()
	var k: int = race.next_step_index(index)
	if k >= steps.size():
		return 0.0
	return _to_step_m(steps, k, from, wind_from_deg)


## The point the sailing distance to the next step is measured to: the rounding point of a mark,
## the best crossing of a line. The middle of the finish line once the board has finished.
static func next_point(race: RaceSim, index: int, from: Vector2, wind_from_deg: float) -> Vector2:
	var steps: Array[RaceStep] = race.steps()
	var k: int = mini(race.next_step_index(index), steps.size() - 1)
	var step: RaceStep = steps[k]
	if step.kind == RaceStep.Kind.MARK:
		return rounding_point(step)
	var has_next: bool = k + 1 < steps.size()
	var next_rep: Vector2 = representative(steps[k + 1]) if has_next else Vector2.ZERO
	return best_crossing(from, step, next_rep, has_next, wind_from_deg)


## How far a board still has to sail round the course, metres: the sailing distance to its next
## step's point, and from there the legs between the representative points of the steps after it.
## The fall of this number from one tick to the next is the trainer's progress reward: it is the
## same whichever way the board goes between two places, it never rewards a detour, and completing
## a step can only ever raise it by what the board saved by crossing where it did (the triangle
## inequality). 0 once the board has finished.
static func remaining_m(race: RaceSim, index: int, from: Vector2, wind_from_deg: float) -> float:
	var steps: Array[RaceStep] = race.steps()
	var k: int = race.next_step_index(index)
	if k >= steps.size():
		return 0.0
	return _to_step_m(steps, k, from, wind_from_deg) + chain_m(steps, k + 1, wind_from_deg)


## The length of the chain of legs between the representative points of the steps from `first` on
## (the leg from the step before `first` to it, and so on to the finish), metres. 0 when `first` is
## past the last step.
static func chain_m(steps: Array[RaceStep], first: int, wind_from_deg: float) -> float:
	var sum: float = 0.0
	for j: int in range(maxi(first, 1), steps.size()):
		sum += to_point(representative(steps[j - 1]), representative(steps[j]), wind_from_deg)
	return sum


## The course's length by water from the middle of the start line to the finish, through every step's
## representative point: what a board earns in progress over a clean race.
static func course_length_m(race: RaceSim, wind_from_deg: float) -> float:
	return chain_m(race.steps(), 1, wind_from_deg)


# ---------------------------------------------------------------- inside

static func _to_step_m(steps: Array[RaceStep], k: int, from: Vector2, wind_from_deg: float) -> float:
	var step: RaceStep = steps[k]
	if step.kind == RaceStep.Kind.MARK:
		return to_point(from, rounding_point(step), wind_from_deg)
	var has_next: bool = k + 1 < steps.size()
	var next_rep: Vector2 = representative(steps[k + 1]) if has_next else Vector2.ZERO
	var crossing: Vector2 = best_crossing(from, step, next_rep, has_next, wind_from_deg)
	var through_m: float = _through_cost(from, crossing, next_rep, has_next, wind_from_deg)
	if has_next:
		# The chain counts the leg from this line's middle to the next step; here only what crossing
		# at the best point from here costs beyond (or saves against) that leg.
		through_m -= to_point(step.target(), next_rep, wind_from_deg)
	return through_m


## The sailing distance from a point to a point of a line and on to the next step's point (just to
## the point of the line when there is no next step).
static func _through_cost(from: Vector2, on_line: Vector2, next_point: Vector2, has_next: bool, wind_from_deg: float) -> float:
	var cost: float = to_point(from, on_line, wind_from_deg)
	if has_next:
		cost += to_point(on_line, next_point, wind_from_deg)
	return cost
