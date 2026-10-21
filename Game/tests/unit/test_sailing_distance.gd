extends GutTest
## SailingDistance (AI_FLEET_PLAN.md, D6b): the shortest way a board can sail to a point is straight
## when the point can be laid, the upwind distance over the cosine of the beat's track angle inside
## the tacking cone, the same with the run's track inside the gybing cone, and continuous at the
## cones' edges; it obeys the triangle inequality, so completing a step of a race never lowers the
## remaining distance by less than nothing; a line is crossed at its best point for the step after;
## and the remaining distance round T1 is its length and falls to 0 at the finish.

## T1 for a wind from the north: mark 1 lies 556 m north of the start line's middle at the origin.
const WIND_DEG: float = 0.0


static func _course() -> Course:
	return RaceCourses.t1_loop(WIND_DEG, Vector2.ZERO)


func test_straight_when_the_point_can_be_laid() -> void:
	# A point 100 m east (a beam reach) and one 100 m up at 60 degrees off the wind.
	assert_almost_eq(SailingDistance.to_point(Vector2.ZERO, Vector2(100.0, 0.0), WIND_DEG), 100.0, 1e-6)
	var reach: Vector2 = Course.direction_of(60.0) * 100.0
	assert_almost_eq(SailingDistance.to_point(Vector2.ZERO, reach, WIND_DEG), 100.0, 1e-6)
	assert_almost_eq(SailingDistance.to_point(reach, reach, WIND_DEG), 0.0, 1e-9, "nowhere to go")


func test_inside_the_tacking_cone_it_is_the_upwind_distance_over_the_cosine_of_the_track_angle() -> void:
	# Straight upwind 100 m: two legs at 50 degrees off the wind, 50 m of upwind progress each.
	var expected: float = 100.0 / cos(deg_to_rad(SailingDistance.UP_TRACK_DEG))
	assert_almost_eq(SailingDistance.to_point(Vector2.ZERO, Vector2(0.0, -100.0), WIND_DEG), expected, 1e-6)
	# 20 degrees off the wind: still inside the cone, the upwind part counts.
	var inside: Vector2 = Course.direction_of(20.0) * 100.0
	assert_almost_eq(SailingDistance.to_point(Vector2.ZERO, inside, WIND_DEG), 100.0 * cos(deg_to_rad(20.0)) / cos(deg_to_rad(50.0)), 1e-3)


func test_inside_the_gybing_cone_it_is_the_downwind_distance_over_the_cosine_of_the_runs_track() -> void:
	var expected: float = 100.0 / cos(deg_to_rad(180.0 - SailingDistance.DOWN_TRACK_DEG))
	assert_almost_eq(SailingDistance.to_point(Vector2.ZERO, Vector2(0.0, 100.0), WIND_DEG), expected, 1e-6)


func test_continuous_at_the_edges_of_the_cones() -> void:
	for edge_deg: float in [SailingDistance.UP_TRACK_DEG, SailingDistance.DOWN_TRACK_DEG]:
		var just_inside: Vector2 = Course.direction_of(edge_deg - 0.01 if edge_deg < 90.0 else edge_deg + 0.01) * 300.0
		var just_outside: Vector2 = Course.direction_of(edge_deg + 0.01 if edge_deg < 90.0 else edge_deg - 0.01) * 300.0
		var difference: float = absf(SailingDistance.to_point(Vector2.ZERO, just_inside, WIND_DEG) - SailingDistance.to_point(Vector2.ZERO, just_outside, WIND_DEG))
		assert_true(difference < 0.1, "a hair either side of %.0f degrees: %.3f m apart" % [edge_deg, difference])


func test_it_obeys_the_triangle_inequality() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for k: int in 500:
		var a: Vector2 = Vector2(rng.randf_range(-500.0, 500.0), rng.randf_range(-500.0, 500.0))
		var b: Vector2 = Vector2(rng.randf_range(-500.0, 500.0), rng.randf_range(-500.0, 500.0))
		var c: Vector2 = Vector2(rng.randf_range(-500.0, 500.0), rng.randf_range(-500.0, 500.0))
		var wind: float = rng.randf_range(0.0, 360.0)
		var direct: float = SailingDistance.to_point(a, c, wind)
		var by_way_of_b: float = SailingDistance.to_point(a, b, wind) + SailingDistance.to_point(b, c, wind)
		if direct > by_way_of_b + 1e-3:
			fail_test("by way of a third point was shorter: %.3f against %.3f" % [by_way_of_b, direct])
			return
	pass_test("500 random triangles")


func test_a_marks_point_is_past_it_on_its_rounding_ray() -> void:
	var race: RaceSim = RaceSim.new(_course(), 1, 0.0)
	var mark1: RaceStep = race.steps()[1]
	var point: Vector2 = SailingDistance.rounding_point(mark1)
	# At a windward mark the course turns back: the ray points straight upwind of the mark.
	assert_almost_eq(point.x, mark1.points[0].x, 1e-3)
	assert_almost_eq(point.y, mark1.points[0].y - SailingDistance.ROUNDING_M, 1e-3, "20 m north (upwind) of mark 1")


func test_a_line_is_crossed_where_the_way_on_is_shortest() -> void:
	var race: RaceSim = RaceSim.new(_course(), 1, 0.0)
	var steps: Array[RaceStep] = race.steps()
	# The gate (step 2) lies across the wind; the way on is back up to mark 1, straight upwind, so
	# from straight below the gate's middle every point of it is as good: the crossing is below the
	# board, within the gate.
	var gate: RaceStep = steps[2]
	var below: Vector2 = gate.target() + Vector2(0.0, 300.0)
	var crossing: Vector2 = SailingDistance.best_crossing(below, gate, SailingDistance.representative(steps[3]), true, WIND_DEG)
	var along: float = (crossing - gate.points[0]).dot((gate.points[1] - gate.points[0]).normalized())
	assert_between(along, 0.0, gate.points[0].distance_to(gate.points[1]), "on the gate")
	# From 100 m below and 300 m east of it (the gate can be laid on a reach), the crossing is at the
	# gate's eastern end: nearer by water, and no further from mark 1 straight upwind.
	var east: Vector2 = gate.target() + Vector2(300.0, 100.0)
	var east_end: Vector2 = gate.points[0] if gate.points[0].x > gate.points[1].x else gate.points[1]
	crossing = SailingDistance.best_crossing(east, gate, SailingDistance.representative(steps[3]), true, WIND_DEG)
	assert_almost_eq(crossing.distance_to(east_end), 0.0, 0.5, "the eastern mark of the gate")


func test_the_remaining_distance_round_t1_is_its_length_and_0_at_the_finish() -> void:
	var race: RaceSim = RaceSim.new(_course(), 1, 0.0)
	race.add_board("a")
	var start: Vector2 = race.course.start_middle()
	race.update_board(0, start)
	var remaining: float = SailingDistance.remaining_m(race, 0, start, WIND_DEG)
	var length: float = SailingDistance.course_length_m(race, WIND_DEG)
	assert_almost_eq(remaining, length, 1e-3, "from the middle of the start line the whole course is left")
	# Two beats of about 556 m at the track angle, two runs, the reach to the finish: over 2 km.
	assert_true(length > 2000.0 and length < 4000.0, "T1 by water: %.0f m" % length)
	# Once finished, nothing is left.
	var finish: Vector2 = race.course.finish_middle()
	for k: int in race.steps().size():
		race.place_board(0, finish, k + 1)
	assert_eq(race.next_step_index(0), race.steps().size())
	assert_eq(SailingDistance.remaining_m(race, 0, finish, WIND_DEG), 0.0)


func test_completing_a_step_never_lowers_the_remaining_distance() -> void:
	# A board placed just before each step's crossing, then just after it: the remaining distance
	# after is never more than before (the chain is a true distance).
	var race: RaceSim = RaceSim.new(_course(), 1, 0.0)
	race.add_board("a")
	var steps: Array[RaceStep] = race.steps()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	for k: int in steps.size() - 1:
		for trial: int in 20:
			# A random point near the step's representative point, as "before"; the same point,
			# with the next step, as "after".
			var near: Vector2 = SailingDistance.representative(steps[k]) + Vector2(rng.randf_range(-60.0, 60.0), rng.randf_range(-60.0, 60.0))
			race.place_board(0, near, k)
			var before: float = SailingDistance.remaining_m(race, 0, near, WIND_DEG)
			race.place_board(0, near, k + 1)
			var after: float = SailingDistance.remaining_m(race, 0, near, WIND_DEG)
			if after > before + 1e-3:
				fail_test("step %d (%s) at %s: %.2f m left before, %.2f after" % [k, steps[k].name, near, before, after])
				return
	pass_test("every step of T1, 20 points each")
