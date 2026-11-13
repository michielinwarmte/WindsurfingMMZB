extends GutTest
## round_early (Skipper._round_early_deg(), _predict_rounding()): the skipper starts its turn round a mark before it
## gets there, as soon as the arc it would sail still rounds the mark (the suite's baseline_A, 8 November 2026: about
## 5 degrees of the turn before the mark and the whole turn after it, out of the turn median 30 m).

const RunRace: GDScript = preload("res://dev/run_race.gd")


func _skipper_and_mark() -> Array:
	var course: Course = RaceCourses.t1_loop(270.0, Vector2.ZERO)
	var race: RaceSim = RaceSim.new(course, 1, 10.0)
	var entries: Array = RunRace.make_entries(race, course, PackedStringArray(["allrounder"]), 15.0, 50.0, 1)
	var skipper: Skipper = entries[0].skipper as Skipper
	for step: RaceStep in race.steps():
		if step.kind == RaceStep.Kind.MARK and rad_to_deg(step.in_dir.angle_to(step.out_dir)) != 0.0 \
				and absf(rad_to_deg(step.in_dir.angle_to(step.out_dir))) > 30.0:
			return [skipper, step]
	return [skipper, null]


## The arc from a point on the leg in, before_m before the mark and mark_margin_m out on the side it is left on,
## turning onto the leg out at once: [crossed_m, closest_m, x, z] (Skipper._predict_rounding()).
func _arc(skipper: Skipper, step: RaceStep, before_m: float) -> PackedFloat32Array:
	var mark: Vector2 = step.points[0]
	var way: float = RoundingCheck.turn_way(step.side)
	var position: Vector2 = mark - step.in_dir * before_m + step.in_dir.orthogonal() * way * skipper.config.mark_margin_m
	var marks: Array[Vector2] = [mark]
	var heading_deg: float = Course.bearing_deg(Vector2.ZERO, step.in_dir)
	var out_deg: float = Course.bearing_deg(Vector2.ZERO, step.out_dir)
	return skipper._predict_rounding(step, marks, position, 10.0, heading_deg, out_deg, 1.0, 0.0, 0.0)


func test_the_rounding_switches_are_on_by_default() -> void:
	# Max's choice, 13 November 2026 ("if its better with the switches on than do it"): the rounding drills and 140
	# full races (AI_TRAINING_METHOD.md rows R-1 to R-7).
	var config: SkipperConfig = SkipperConfig.new()
	assert_true(config.round_early, "the turn begins before the mark")
	assert_true(config.gybe_at_mark, "the slalom gybe through the mark")
	assert_eq(config.mark_layline_margin_m, 3.0, "the last tack into a mark 3 m past its layline")


func test_turning_far_before_the_mark_does_not_round_it() -> void:
	var found: Array = _skipper_and_mark()
	assert_not_null(found[1], "the course has a mark the course turns at")
	var arc: PackedFloat32Array = _arc(found[0], found[1], 80.0)
	assert_true(arc[0] < 0.0 or arc[1] < Skipper.ROUND_EARLY_CLEAR_M, "80 m early the arc cuts inside the mark")


func test_the_turn_starts_before_the_mark_and_comes_out_tighter() -> void:
	var found: Array = _skipper_and_mark()
	var skipper: Skipper = found[0]
	var step: RaceStep = found[1]
	# The earliest point on the way in from which the arc still rounds the mark with room to spare.
	var earliest_m: float = -1.0
	var before_m: float = 60.0
	while before_m >= 0.0:
		var arc: PackedFloat32Array = _arc(skipper, step, before_m)
		if arc[0] >= 0.0 and arc[1] >= Skipper.ROUND_EARLY_CLEAR_M:
			earliest_m = before_m
			break
		before_m -= 1.0
	assert_gt(earliest_m, 2.0, "the turn can start metres before the mark")
	var early: PackedFloat32Array = _arc(skipper, step, earliest_m)
	assert_lte(early[0], skipper.config.mark_margin_m + Skipper.ROUND_EARLY_WIDE_M, "begun early it still rounds the mark close")
