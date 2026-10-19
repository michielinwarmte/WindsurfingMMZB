extends GutTest
## RoundingCheck, the race's geometry (RACING_PLAN.md, "When a mark counts as rounded"): a windward
## mark rounded to port and to starboard, slalom bends both ways, the wrong side, a rounding too far
## out, a mark sailed straight past, a gate through either end and backwards, the finish backwards;
## then every turn from -180 to 180 degrees on both sides, and every mark of the iQFOiL templates,
## checked against Course.natural_side() and Course.turn_at().
##
## The mark is at the origin unless a test says otherwise. Game X is east, Z south: north is
## (0, -1). Tracks are sampled every metre, as a board's ticks are.

const RULES_PATH: String = "res://maps/course/iqfoil_courses.tres"
const NORTH: Vector2 = Vector2(0.0, -1.0)
const SOUTH: Vector2 = Vector2(0.0, 1.0)
const EAST: Vector2 = Vector2(1.0, 0.0)
const WEST: Vector2 = Vector2(-1.0, 0.0)
const PORT: CourseMark.Rounding = CourseMark.Rounding.PORT
const STARBOARD: CourseMark.Rounding = CourseMark.Rounding.STARBOARD
const MARK: Vector2 = Vector2.ZERO

var _rules: CourseRules


func before_all() -> void:
	_rules = load(RULES_PATH)


# ---------------------------------------------------------------- a windward mark: a 180 degree turn

func test_the_rounding_ray_points_out_of_the_turn() -> void:
	_assert_direction(RoundingCheck.rounding_ray(NORTH, SOUTH, PORT), NORTH, "A windward mark: straight upwind of it")
	_assert_direction(RoundingCheck.rounding_ray(NORTH, SOUTH, STARBOARD), NORTH, "The same for starboard: the side says which way round")
	_assert_direction(RoundingCheck.rounding_ray(NORTH, EAST, STARBOARD), Vector2(-1.0, -1.0).normalized(), "A right turn: north-west, outside it")
	_assert_direction(RoundingCheck.rounding_ray(NORTH, Course.direction_of(25.0), STARBOARD), Course.direction_of(282.5),
		"A 25 degree bend to the right: out of the bend, square to its middle")
	_assert_direction(RoundingCheck.rounding_ray(NORTH, NORTH, PORT), EAST, "Straight past, left to port: the board passes on the mark's right")
	_assert_direction(RoundingCheck.rounding_ray(NORTH, NORTH, STARBOARD), WEST, "Straight past, left to starboard: on its left")


func test_a_windward_mark_rounded_to_port() -> void:
	# Up the east side with the mark on the left, across the top going west, down the west side.
	var track: PackedVector2Array = _path([Vector2(20.0, 100.0), Vector2(20.0, -20.0), Vector2(-20.0, -20.0), Vector2(-20.0, 100.0)])
	assert_eq(_roundings(track, NORTH, SOUTH, PORT), 1, "Rounded once")
	assert_eq(_warnings(track, NORTH, SOUTH, PORT), 0, "No warning")
	var outcome: RoundingCheck.Outcome = RoundingCheck.round_mark(Vector2(20.0, -20.0), Vector2(-20.0, -20.0), MARK, NORTH, SOUTH, PORT)
	assert_true(outcome.done, "One long move across the top")
	assert_almost_eq(outcome.fraction, 0.5, 1e-6, "Crossing the upwind ray half-way along the move")


func test_a_windward_mark_rounded_to_starboard() -> void:
	var track: PackedVector2Array = _path([Vector2(-20.0, 100.0), Vector2(-20.0, -20.0), Vector2(20.0, -20.0), Vector2(20.0, 100.0)])
	assert_eq(_roundings(track, NORTH, SOUTH, STARBOARD), 1, "Up the west side, across the top going east: starboard")
	assert_eq(_warnings(track, NORTH, SOUTH, STARBOARD), 0)


func test_the_wrong_way_round_a_windward_mark() -> void:
	# Round to starboard a mark that is left to port.
	var track: PackedVector2Array = _path([Vector2(-20.0, 100.0), Vector2(-20.0, -20.0), Vector2(20.0, -20.0), Vector2(20.0, 100.0)])
	assert_eq(_roundings(track, NORTH, SOUTH, PORT), 0, "Not counted")
	assert_gt(_warnings(track, NORTH, SOUTH, PORT), 0, "Wrong side")


func test_tacking_up_under_a_windward_mark_is_not_the_wrong_side() -> void:
	# Straight downwind of the mark is the inside of its turn, and the beat crosses it: on starboard
	# going west 20 m below the mark, then back on port going east.
	assert_eq(_warnings(_path([Vector2(30.0, 50.0), Vector2(-10.0, 10.0)]), NORTH, SOUTH, PORT), 0, "Starboard tack under the mark")
	assert_eq(_warnings(_path([Vector2(-10.0, 30.0), Vector2(10.0, 10.0)]), NORTH, SOUTH, PORT), 0, "Port tack under the mark")
	assert_eq(_roundings(_path([Vector2(30.0, 50.0), Vector2(-10.0, 10.0)]), NORTH, SOUTH, PORT), 0)


func test_turning_back_short_of_a_windward_mark_is_the_wrong_side() -> void:
	# Up to 30 m below the mark, then off down the run without going round it.
	var track: PackedVector2Array = _path([Vector2(20.0, 100.0), Vector2(20.0, 30.0), Vector2(-20.0, 70.0)])
	assert_eq(_roundings(track, NORTH, SOUTH, PORT), 0)
	assert_gt(_warnings(track, NORTH, SOUTH, PORT), 0, "Sailing on down the next leg without the rounding")


func test_a_rounding_more_than_80_m_out_does_not_count() -> void:
	var far: PackedVector2Array = _path([Vector2(100.0, 100.0), Vector2(100.0, -100.0), Vector2(-100.0, -100.0), Vector2(-100.0, 100.0)])
	assert_eq(_roundings(far, NORTH, SOUTH, PORT), 0, "The right side, but 100 m out")
	assert_eq(_warnings(far, NORTH, SOUTH, PORT), 0, "and not the wrong side either")
	var near: PackedVector2Array = _path([Vector2(79.0, 100.0), Vector2(79.0, -79.0), Vector2(-79.0, -79.0), Vector2(-79.0, 100.0)])
	assert_eq(_roundings(near, NORTH, SOUTH, PORT), 1, "79 m out still counts")


# ---------------------------------------------------------------- slalom bends and marks sailed straight past

func test_a_25_degree_bend_to_the_right_rounded_to_starboard() -> void:
	var out_dir: Vector2 = Course.direction_of(25.0)
	# North on the mark's west side (the mark on the right), then on along the new leg.
	var track: PackedVector2Array = _path([Vector2(-15.0, 100.0), Vector2(-15.0, 0.0), Vector2(-15.0, 0.0) + out_dir * 100.0])
	assert_eq(_roundings(track, NORTH, out_dir, STARBOARD), 1)
	assert_eq(_warnings(track, NORTH, out_dir, STARBOARD), 0)


func test_a_25_degree_bend_to_the_left_rounded_to_port() -> void:
	var out_dir: Vector2 = Course.direction_of(-25.0)
	var track: PackedVector2Array = _path([Vector2(15.0, 100.0), Vector2(15.0, 0.0), Vector2(15.0, 0.0) + out_dir * 100.0])
	assert_eq(_roundings(track, NORTH, out_dir, PORT), 1)
	assert_eq(_warnings(track, NORTH, out_dir, PORT), 0)


func test_cutting_inside_a_slalom_mark_is_the_wrong_side() -> void:
	var out_dir: Vector2 = Course.direction_of(25.0)
	# A starboard mark passed with it on the left: inside the bend.
	var track: PackedVector2Array = _path([Vector2(15.0, 100.0), Vector2(15.0, 0.0), Vector2(15.0, 0.0) + out_dir * 100.0])
	assert_eq(_roundings(track, NORTH, out_dir, STARBOARD), 0, "Not counted")
	assert_gt(_warnings(track, NORTH, out_dir, STARBOARD), 0, "Wrong side")


func test_a_mark_sailed_straight_past() -> void:
	var east_of_it: PackedVector2Array = _path([Vector2(10.0, 50.0), Vector2(10.0, -50.0)])
	var west_of_it: PackedVector2Array = _path([Vector2(-10.0, 50.0), Vector2(-10.0, -50.0)])
	assert_eq(_roundings(east_of_it, NORTH, NORTH, PORT), 1, "Left to port: passed with the mark on the left")
	assert_eq(_roundings(west_of_it, NORTH, NORTH, PORT), 0)
	assert_gt(_warnings(west_of_it, NORTH, NORTH, PORT), 0, "Passed with the mark on the right: the wrong side")
	assert_eq(_roundings(west_of_it, NORTH, NORTH, STARBOARD), 1, "Left to starboard: the other way round")
	assert_gt(_warnings(east_of_it, NORTH, NORTH, STARBOARD), 0)


# ---------------------------------------------------------------- lines

func test_a_gate_through_either_end() -> void:
	var gate: RaceStep = _line_step(RaceStep.Kind.GATE, Vector2(-37.5, 0.0), Vector2(37.5, 0.0), SOUTH)
	var near_s: RoundingCheck.Outcome = RoundingCheck.check(gate, Vector2(-30.0, -10.0), Vector2(-30.0, 10.0))
	assert_true(near_s.done, "Running down past the starboard end, rounding 4S")
	assert_almost_eq(near_s.fraction, 0.5, 1e-6)
	assert_true(RoundingCheck.check(gate, Vector2(30.0, -10.0), Vector2(30.0, 10.0)).done, "Past the port end, rounding 4P")
	assert_false(RoundingCheck.check(gate, Vector2(45.0, -10.0), Vector2(45.0, 10.0)).done, "Outside the gate")
	assert_false(RoundingCheck.check(gate, Vector2(0.0, 10.0), Vector2(0.0, -10.0)).done, "Backwards")


func test_the_finish_line_crossed_backwards_does_not_count() -> void:
	# A finish line running north and south, finished going west.
	var finish: RaceStep = _line_step(RaceStep.Kind.FINISH, Vector2(-100.0, -70.0), Vector2(-100.0, -30.0), WEST)
	assert_true(RoundingCheck.check(finish, Vector2(-90.0, -50.0), Vector2(-110.0, -50.0)).done, "Going west: finished")
	assert_false(RoundingCheck.check(finish, Vector2(-110.0, -50.0), Vector2(-90.0, -50.0)).done, "Going east: not")
	assert_almost_eq(RoundingCheck.over_line_m(Vector2(-110.0, -50.0), Vector2(-100.0, -70.0), Vector2(-100.0, -30.0), WEST), 10.0, 1e-6,
		"10 m over the line")
	assert_almost_eq(RoundingCheck.over_line_m(Vector2(-90.0, -50.0), Vector2(-100.0, -30.0), Vector2(-100.0, -70.0), WEST), -10.0, 1e-6,
		"10 m behind it, whichever end is named first")


func test_a_board_stopping_on_a_line_crosses_it_once() -> void:
	var a: Vector2 = Vector2(-10.0, 0.0)
	var b: Vector2 = Vector2(10.0, 0.0)
	assert_almost_eq(RoundingCheck.across_line(Vector2(0.0, 1.0), Vector2(0.0, 0.0), a, b, NORTH), 1.0, 1e-6, "Onto the line: crossed")
	assert_eq(RoundingCheck.across_line(Vector2(0.0, 0.0), Vector2(0.0, -1.0), a, b, NORTH), -1.0, "and not again leaving it")


# ---------------------------------------------------------------- every turn, both sides

func test_every_turn_on_both_sides() -> void:
	# Straight on, turning back, and every bend from 10 degrees up. (Below 5 degrees a mark is passed,
	# not rounded, and the arc of _round_track() is not how a board passes it.)
	var turns: Array[float] = [0.0, 180.0, -180.0]
	for degrees: int in range(10, 180, 5):
		turns.append(float(degrees))
		turns.append(float(-degrees))
	for turn: float in turns:
		var out_dir: Vector2 = Course.direction_of(turn)
		for side: CourseMark.Rounding in [PORT, STARBOARD]:
			var other: CourseMark.Rounding = STARBOARD if side == PORT else PORT
			var label: String = "%.0f degrees, %s" % [turn, CourseMark.side_name(side)]
			var track: PackedVector2Array = _round_track(NORTH, out_dir, side, 20.0)
			assert_eq(_roundings(track, NORTH, out_dir, side), 1, label + ": rounded once")
			assert_eq(_warnings(track, NORTH, out_dir, side), 0, label + ": no warning")
			assert_eq(_roundings(track, NORTH, out_dir, other), 0, label + ": not a rounding to " + CourseMark.side_name(other))
			assert_gt(_warnings(track, NORTH, out_dir, other), 0, label + ": the wrong side for " + CourseMark.side_name(other))


func test_every_mark_of_the_templates() -> void:
	for id: String in CourseTemplates.ALL:
		for axis_deg: float in [0.0, 222.0]:
			var course: Course = CourseTemplates.build(id, _rules, 15.0, CourseTemplates.default_boards(id), axis_deg, Vector2(100.0, 200.0))
			var steps: Array[RaceStep] = RaceSim.new(course).steps()
			var first_visit: Dictionary[String, bool] = {}
			for k: int in range(1, steps.size() - 1):
				var step: RaceStep = steps[k]
				if step.kind != RaceStep.Kind.MARK:
					for part: String in step.id.split("/"):
						first_visit[part] = false
					continue
				var label: String = "%s at %.0f degrees, step %d (%s)" % [id, axis_deg, k, step.name]
				var mark: Vector2 = step.points[0]
				var track: PackedVector2Array = _round_track(step.in_dir, step.out_dir, step.side, 20.0, mark)
				assert_eq(_roundings(track, step.in_dir, step.out_dir, step.side, mark), 1, label + ": rounded once")
				assert_eq(_warnings(track, step.in_dir, step.out_dir, step.side, mark), 0, label + ": no warning")
				_check_against_the_course_code(course, steps, k, label)
				if not first_visit.has(step.id):
					first_visit[step.id] = true
					var turn: PackedVector2Array = course.turn_at(step.id)
					_assert_direction(step.in_dir, turn[0], label + ": the leg in, as Course.turn_at() has it")
					_assert_direction(step.out_dir, turn[1], label + ": the leg out")


## The side the course code gives a mark (Course.natural_side(), the template's own side) is the
## side the geometry goes round it: from the rounding ray's in side to its out side.
func _check_against_the_course_code(course: Course, steps: Array[RaceStep], k: int, label: String) -> void:
	var step: RaceStep = steps[k]
	var turn: float = Course.turn_deg(Course.bearing_deg(steps[k - 1].target(), step.target()),
		Course.bearing_deg(step.target(), steps[k + 1].target()))
	if absf(turn) < RoundingCheck.STRAIGHT_ON_DEG or absf(turn) > 170.0:
		return  # straight on, or turning back: either side goes round it (as test_course.gd has it)
	var ray: Vector2 = RoundingCheck.rounding_ray(step.in_dir, step.out_dir, step.side)
	# From the in side to the out side is clockwise when the leg out lies clockwise of the ray.
	var geometry_side: CourseMark.Rounding = STARBOARD if RoundingCheck.clockwise_of(ray, step.out_dir) > 0.0 else PORT
	var natural: CourseMark.Rounding = Course.natural_side(steps[k - 1].target(), step.target(), steps[k + 1].target())
	assert_eq(geometry_side, natural, label + ": the geometry and Course.natural_side()")
	assert_eq(step.side, course.mark(step.id).side, label + ": the template's side")
	assert_eq(step.side, natural, label + ": the template's side is the natural one")


# ---------------------------------------------------------------- helpers

## A track along a list of points, a point every metre.
func _path(points: Array[Vector2]) -> PackedVector2Array:
	var track: PackedVector2Array = PackedVector2Array([points[0]])
	for i: int in range(1, points.size()):
		var length: float = points[i - 1].distance_to(points[i])
		var pieces: int = maxi(ceili(length), 1)
		for k: int in range(1, pieces + 1):
			track.append(points[i - 1].lerp(points[i], float(k) / pieces))
	return track


## A track that goes round a mark the way a side says, radius_m off it: along the leg in, abeam of
## the mark, round it in an arc to abeam on the leg out, and away along the leg out. A board leaving
## a mark to starboard has it on its right, so it sails on the legs' left.
func _round_track(in_dir: Vector2, out_dir: Vector2, side: CourseMark.Rounding, radius_m: float, mark: Vector2 = MARK) -> PackedVector2Array:
	var way: float = RoundingCheck.turn_way(side)
	var abeam_in: Vector2 = in_dir.orthogonal() * way  # orthogonal(): a quarter turn anticlockwise, to the left
	var abeam_out: Vector2 = out_dir.orthogonal() * way
	var points: Array[Vector2] = [mark + abeam_in * radius_m - in_dir * 150.0]
	# Clockwise round the mark is a growing angle in these axes (Z south).
	var sweep: float = fposmod(way * (abeam_out.angle() - abeam_in.angle()), TAU)
	var pieces: int = maxi(ceili(rad_to_deg(sweep) / 5.0), 1)
	# The arc's ends exactly abeam, its middle in 5 degree pieces. (Vector2 is single precision: an
	# end worked out from its angle can land a hair behind the ray and cross it twice.)
	points.append(mark + abeam_in * radius_m)
	for k: int in range(1, pieces):
		points.append(mark + Vector2.from_angle(abeam_in.angle() + way * sweep * k / pieces) * radius_m)
	points.append(mark + abeam_out * radius_m)
	points.append(mark + abeam_out * radius_m + out_dir * 150.0)
	return _path(points)


## How many moves of a track rounded the mark.
func _roundings(track: PackedVector2Array, in_dir: Vector2, out_dir: Vector2, side: CourseMark.Rounding, mark: Vector2 = MARK) -> int:
	var count: int = 0
	for i: int in range(1, track.size()):
		if RoundingCheck.round_mark(track[i - 1], track[i], mark, in_dir, out_dir, side).done:
			count += 1
	return count


## How many moves of a track went the wrong side of the mark.
func _warnings(track: PackedVector2Array, in_dir: Vector2, out_dir: Vector2, side: CourseMark.Rounding, mark: Vector2 = MARK) -> int:
	var count: int = 0
	for i: int in range(1, track.size()):
		if RoundingCheck.round_mark(track[i - 1], track[i], mark, in_dir, out_dir, side).wrong_side:
			count += 1
	return count


func _line_step(kind: RaceStep.Kind, end_a: Vector2, end_b: Vector2, forward: Vector2) -> RaceStep:
	var step: RaceStep = RaceStep.new()
	step.kind = kind
	step.points = PackedVector2Array([end_a, end_b])
	step.in_dir = forward
	step.out_dir = forward
	return step


func _assert_direction(got: Vector2, expected: Vector2, message: String) -> void:
	assert_almost_eq(got.distance_to(expected), 0.0, 1e-4, "%s: %s, expected %s" % [message, got, expected])
