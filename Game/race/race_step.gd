class_name RaceStep
extends RefCounted
## One step of a race course (RACING_PLAN.md, Part 9A): the start line, a mark to round, a gate to
## sail through (between its two marks, like a line), or the finish line. RaceSim makes the list
## from a Course's order, lap by lap, and RoundingCheck says when a board has done a step.
##
## Positions and directions are game metres, Vector2(X east, Z south), as in Course.

enum Kind { START, MARK, GATE, FINISH }

## The step as the course's order writes it: "Start", "1", "4S/4P", "Finish".
var id: String = ""
## The step as the HUD says it: "start", "mark 1", "gate 4S/4P", "finish".
var name: String = ""
var kind: Kind = Kind.MARK
## A mark's position, or the two ends of a line: the start boat and pin, the finish boat and pin,
## or a gate's two marks.
var points: PackedVector2Array = PackedVector2Array()
## The side a mark is left on (port or starboard). NONE for the lines and the gates.
var side: CourseMark.Rounding = CourseMark.Rounding.NONE
## The direction of the leg arriving at the step, one metre long. No leg arrives at the start, so
## there it is the first leg's direction. A line is crossed in this direction.
var in_dir: Vector2 = Vector2.ZERO
## The direction of the leg leaving the step, one metre long. No leg leaves the finish, so there it
## is the last leg's direction.
var out_dir: Vector2 = Vector2.ZERO


## True for the start, the finish and the gates: steps done by crossing a line.
func is_line() -> bool:
	return kind != Kind.MARK


## Where the HUD's arrow points: the mark, or the middle of the line.
func target() -> Vector2:
	if is_line():
		return (points[0] + points[1]) / 2.0
	return points[0]


## How far a point is from the step, metres: from the mark, or from the nearest point of the line
## (a board heading for one end of a gate is as close as the end it is heading for).
func distance_from(point: Vector2) -> float:
	if is_line():
		return point.distance_to(Geometry2D.get_closest_point_to_segment(point, points[0], points[1]))
	return point.distance_to(points[0])
