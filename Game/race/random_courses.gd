class_name RandomCourses
extends RefCounted
## A course drawn at random for a training race (AI_FLEET_PLAN.md, D6: "train randomly on all
## iQFOiL courses and random ones"): one of the ten templates at a random size between 40 and 100 %
## of the class's distances, or a random shape of the same families (a windward-leeward with a gate
## or a leeward mark, a trapezoid, a slalom with 2 to 5 marks after a reaching start), set to a
## random wind direction with its start line's middle at the origin. The head never sees the same
## race twice, so it learns racing, not a course.
##
## The shapes are drawn in the course diagrams' frame, as CourseTemplates draws them: up is toward
## the wind, right is to the right looking upwind, the middle of the start line at (0, 0); then the
## course is turned to its wind.

## The start line is never shorter than this, metres: the skippers need room (RaceCourses).
const MIN_START_LINE_M: float = 60.0
## The shares of the draw: a template at a random size, or one of the three random shapes.
const TEMPLATE_SHARE: float = 0.55
const WINDWARD_LEEWARD_SHARE: float = 0.2
const TRAPEZOID_SHARE: float = 0.1

const PORT: CourseMark.Rounding = CourseMark.Rounding.PORT
const STARBOARD: CourseMark.Rounding = CourseMark.Rounding.STARBOARD


## A random course for a wind (knots): a template at a random size, or a random shape, for a random
## number of boards (8 to 24), set to a random wind direction.
static func draw(rng: RandomNumberGenerator, wind_kt: float, rules: CourseRules) -> Course:
	var boards: int = rng.randi_range(8, 24)
	var axis_deg: float = rng.randf_range(0.0, 360.0)
	var share: float = rng.randf()
	var course: Course
	if share < TEMPLATE_SHARE:
		course = template(rng, wind_kt, rules, boards, axis_deg)
	elif share < TEMPLATE_SHARE + WINDWARD_LEEWARD_SHARE:
		course = windward_leeward(rng, rules, boards, axis_deg)
	elif share < TEMPLATE_SHARE + WINDWARD_LEEWARD_SHARE + TRAPEZOID_SHARE:
		course = trapezoid(rng, rules, boards, axis_deg)
	else:
		course = slalom(rng, rules, boards, axis_deg)
	return course


## One of the ten templates at a random size (40 to 100 %), set to a wind direction.
static func template(rng: RandomNumberGenerator, wind_kt: float, rules: CourseRules, boards: int, axis_deg: float) -> Course:
	var id: String = CourseTemplates.ALL[rng.randi_range(0, CourseTemplates.ALL.size() - 1)]
	var course: Course = CourseTemplates.build(id, rules, wind_kt, boards, axis_deg, Vector2.ZERO)
	var size: float = rng.randf_range(40.0, 100.0)
	course.set_size(size)
	_widen_the_start_line(course)
	course.name = "%s at %.0f %%" % [id, size]
	return course


## A windward-leeward: mark 1 300 to 1100 m upwind (a little to one side), a leeward gate or a
## single leeward mark 100 to 250 m above the start line, one or two rounds, and a reach to the
## finish to the left or the right.
static func windward_leeward(rng: RandomNumberGenerator, rules: CourseRules, boards: int, axis_deg: float) -> Course:
	var course: Course = _start(rules, boards, false, rng)
	course.template = "random windward-leeward"
	var up_m: float = rng.randf_range(300.0, 1100.0)
	course.add_mark("1", Vector2(rng.randf_range(-0.15, 0.15) * up_m, up_m), PORT)
	var leeward_up_m: float = rng.randf_range(100.0, 250.0)
	var rounds: int = 1 if rng.randf() < 0.5 else 2
	var finish_left: bool = rng.randf() < 0.5
	var last_id: String
	var inner: PackedStringArray = PackedStringArray()
	if rng.randf() < 0.6:
		_gate(course, "4", Vector2(0.0, leeward_up_m), rules.gate_m)
		last_id = "4S" if finish_left else "4P"
		for round_number: int in rounds:
			inner.append("1")
			inner.append("4S/4P" if round_number < rounds - 1 else last_id)
	else:
		course.add_mark("4", Vector2(rng.randf_range(-40.0, 40.0), leeward_up_m), PORT)
		last_id = "4"
		for round_number: int in rounds:
			inner.append("1")
			inner.append("4")
	course.sequence = "Start-" + "-".join(inner) + "-Finish"
	var last: Vector2 = course.mark(last_id).position
	_finish(course, rules, _reach(last, rng.randf_range(200.0, 450.0), rng.randf_range(80.0, 110.0), not finish_left), last)
	_place(course, axis_deg)
	course.name = "random windward-leeward, %d round%s" % [rounds, "" if rounds == 1 else "s"]
	return course


## A trapezoid: mark 1 upwind, a reach to the left to mark 2, the outer gate below mark 2, the inner
## gate above the start line; the outer loop twice (as O2) or the inner then the outer (as I2).
static func trapezoid(rng: RandomNumberGenerator, rules: CourseRules, boards: int, axis_deg: float) -> Course:
	var course: Course = _start(rules, boards, false, rng)
	course.template = "random trapezoid"
	var mark1: Vector2 = Vector2(0.0, rng.randf_range(400.0, 1000.0))
	course.add_mark("1", mark1, PORT)
	var mark2: Vector2 = _reach(mark1, rng.randf_range(300.0, 700.0), rng.randf_range(70.0, 110.0), false)
	course.add_mark("2", mark2, PORT)
	_gate(course, "3", Vector2(mark2.x, rng.randf_range(0.0, 150.0)), rules.gate_m)
	_gate(course, "4", Vector2(0.0, rng.randf_range(100.0, 200.0)), rules.gate_m)
	var outer: bool = rng.randf() < 0.5
	course.sequence = "Start-1-2-3S/3P-2-3P-Finish" if outer else "Start-1-4S/4P-1-2-3P-Finish"
	var last: Vector2 = course.mark("3P").position
	_finish(course, rules, _reach(last, rng.randf_range(250.0, 450.0), rng.randf_range(100.0, 130.0), true), last)
	_place(course, axis_deg)
	course.name = "random trapezoid, %s loop" % ("outer" if outer else "inner")
	return course


## A slalom: a reaching start, mark 1 across the wind 300 to 600 m from the pin, a run of 300 to 800
## m to mark 2, then 0 to 3 more marks on legs of 250 to 450 m that zigzag down the wind (15 to 40
## degrees below straight across, alternating sides), and the finish square to the last leg.
static func slalom(rng: RandomNumberGenerator, rules: CourseRules, boards: int, axis_deg: float) -> Course:
	var course: Course = _start(rules, boards, true, rng)
	course.template = "random slalom"
	var mirror: float = 1.0 if rng.randf() < 0.5 else -1.0
	var ids: PackedStringArray = PackedStringArray()
	var mark1: Vector2 = course.mark(CourseMark.START_PIN).position + Vector2(mirror * rng.randf_range(300.0, 600.0), rng.randf_range(-30.0, 30.0))
	course.add_mark("1", mark1, STARBOARD if mirror > 0.0 else PORT)
	ids.append("1")
	var last: Vector2 = mark1 + Vector2(0.0, -rng.randf_range(300.0, 800.0))
	course.add_mark("2", last, PORT if mirror > 0.0 else STARBOARD)
	ids.append("2")
	var extra: int = rng.randi_range(0, 3)
	var toward: float = -mirror  # the first slalom leg goes back across, under the start
	for n: int in extra:
		var below_deg: float = rng.randf_range(15.0, 40.0)
		var leg: Vector2 = rng.randf_range(250.0, 450.0) * Vector2(toward * cos(deg_to_rad(below_deg)), -sin(deg_to_rad(below_deg)))
		last = last + leg
		var id: String = str(3 + n)
		# Gybing round the mark to go back the other way: the mark is on the inside of the turn.
		course.add_mark(id, last, STARBOARD if toward < 0.0 else PORT)
		ids.append(id)
		toward = -toward
	course.sequence = "Start-" + "-".join(ids) + "-Finish"
	var below_deg: float = rng.randf_range(15.0, 40.0)
	var finish_middle: Vector2 = last + rng.randf_range(250.0, 450.0) * Vector2(toward * cos(deg_to_rad(below_deg)), -sin(deg_to_rad(below_deg)))
	_finish(course, rules, finish_middle, last)
	_place(course, axis_deg)
	course.name = "random slalom, %d marks" % ids.size()
	return course


# ---------------------------------------------------------------- the parts

## A new course with its start line: across the wind (the boat at the right end looking upwind) or,
## for a reaching start, along it (the boat at the upwind end); 60 to 150 m long, whatever the
## class says for that many boards.
static func _start(rules: CourseRules, boards: int, reaching: bool, rng: RandomNumberGenerator) -> Course:
	var course: Course = Course.new()
	course.boards = boards
	var length_m: float = maxf(rules.reaching_start_line_m(boards) if reaching else rules.upwind_start_line_m(boards), MIN_START_LINE_M)
	length_m = clampf(length_m * rng.randf_range(0.8, 1.2), MIN_START_LINE_M, 150.0)
	if reaching:
		course.add_mark(CourseMark.START_BOAT, Vector2(0.0, length_m / 2.0))
		course.add_mark(CourseMark.START_PIN, Vector2(0.0, -length_m / 2.0))
	else:
		course.add_mark(CourseMark.START_BOAT, Vector2(length_m / 2.0, 0.0))
		course.add_mark(CourseMark.START_PIN, Vector2(-length_m / 2.0, 0.0))
	return course


## A gate across the wind: number + "S" on the left (looking upwind), number + "P" on the right.
static func _gate(course: Course, number: String, middle: Vector2, width_m: float) -> void:
	course.add_mark(number + "S", middle - Vector2(width_m / 2.0, 0.0), STARBOARD)
	course.add_mark(number + "P", middle + Vector2(width_m / 2.0, 0.0), PORT)


## The finish line, square to the last leg, with the finish boat at its upwind end.
static func _finish(course: Course, rules: CourseRules, middle: Vector2, last_mark: Vector2) -> void:
	var across: Vector2 = (middle - last_mark).normalized().orthogonal()
	if across.y < 0.0:
		across = -across
	course.add_mark(CourseMark.FINISH_BOAT, middle + across * rules.finish_line_m / 2.0)
	course.add_mark(CourseMark.FINISH_PIN, middle - across * rules.finish_line_m / 2.0)


## The end of a reach from a point: a length, at an angle from the wind (0 straight upwind, 90
## across, 180 straight downwind), to the right or the left looking upwind.
static func _reach(from: Vector2, length_m: float, from_wind_deg: float, to_right: bool) -> Vector2:
	var angle: float = deg_to_rad(from_wind_deg)
	return from + length_m * Vector2(sin(angle) * (1.0 if to_right else -1.0), cos(angle))


## From the frame to the map: up toward the wind, right 90 degrees clockwise from it, the start
## line's middle at the origin.
static func _place(course: Course, axis_deg: float) -> void:
	course.axis_deg = fposmod(axis_deg, 360.0)
	var up: Vector2 = Course.direction_of(axis_deg)
	var right: Vector2 = Course.direction_of(axis_deg + 90.0)
	for mark: CourseMark in course.marks:
		mark.position = right * mark.position.x + up * mark.position.y


static func _widen_the_start_line(course: Course) -> void:
	var line_m: float = course.mark(CourseMark.START_BOAT).position.distance_to(course.mark(CourseMark.START_PIN).position)
	if line_m < MIN_START_LINE_M:
		course.set_start_line_length(MIN_START_LINE_M)
