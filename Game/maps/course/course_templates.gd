class_name CourseTemplates
extends RefCounted
## The iQFOiL's courses as templates for the course maker (MAP_SILVAPLANA_PLAN.md, W4a): the shapes,
## the mark order and the rounding sides of the diagrams in the Notice of Race (Addendum A,
## Documentation/Document_146274_20260925081258_en.pdf), with the class's distances (CourseRules,
## iqfoil_courses.tres).
##
## Each course is built in its own frame, as the diagrams are drawn: "up" is toward the wind, "right"
## is to the right when you look upwind, and the middle of the start line is at (0, 0). Then it is
## turned to the wind and put on the map, as a race committee sets a course.
##
## Gates: the S mark is on the left looking upwind, so a board running down leaves it to starboard.

## The templates, in the order the course maker lists them.
const ALL: PackedStringArray = ["LG2", "LR2", "O2", "I2", "US3", "US4", "PD3", "SD3", "PM1", "SM1"]

## The upwind sprints have no class distances: their marks as read from the Notice of Race's
## diagrams (not to scale), in the frame, in units of mark 1's distance from the start line.
const US3_MARKS: Dictionary[String, Vector2] = {
	"1": Vector2(0.0, 1.0), "2": Vector2(-1.16, 0.6), "3": Vector2(-1.16, -0.09), "Finish": Vector2(-1.55, -0.47)}
const US4_MARKS: Dictionary[String, Vector2] = {
	"1": Vector2(0.0, 1.0), "2": Vector2(-1.13, 0.6), "3": Vector2(-1.12, -0.1), "4": Vector2(-1.71, -0.44),
	"Finish": Vector2(-0.71, -0.7)}

const PORT: CourseMark.Rounding = CourseMark.Rounding.PORT
const STARBOARD: CourseMark.Rounding = CourseMark.Rounding.STARBOARD


## The name the course maker shows for a template.
static func title(id: String) -> String:
	match id:
		"LG2":
			return "Windward-leeward, finish left (LG2)"
		"LR2":
			return "Windward-leeward, finish right (LR2)"
		"O2":
			return "Trapezoid, outer loop (O2)"
		"I2":
			return "Trapezoid, inner loop (I2)"
		"US3":
			return "Upwind sprint, 3 marks (US3)"
		"US4":
			return "Upwind sprint, 4 marks (US4)"
		"PD3":
			return "Sprint slalom, start left (PD3, MR2)"
		"SD3":
			return "Sprint slalom, start right (SD3, MR2)"
		"PM1":
			return "Medal race MR1, finish right (PM1)"
		"SM1":
			return "Medal race MR1, finish left (SM1)"
	return id


## How many boards a new course's start line is set for: a course racing fleet (a setting, not a
## class number), a full sprint heat (24, the class's largest), or the four of a medal race final.
static func default_boards(id: String) -> int:
	if id in ["PM1", "SM1"]:
		return 4
	if id in ["US3", "US4", "PD3", "SD3"]:
		return 24
	return 40


## True for the courses with a reaching start (the start line along the wind).
static func has_reaching_start(id: String) -> bool:
	return id in ["PD3", "SD3", "PM1", "SM1"]


## How long a template's start line is for a number of boards, metres.
static func start_line_m(rules: CourseRules, id: String, boards: int) -> float:
	if has_reaching_start(id):
		return rules.reaching_start_line_m(boards)
	return rules.upwind_start_line_m(boards)


## A new course from a template: sized for a wind (knots), set for a wind direction (axis_deg,
## where the wind comes from) and with the middle of its start line at a game point (X, Z).
static func build(id: String, rules: CourseRules, wind_kt: float, boards: int, axis_deg: float, start_middle: Vector2) -> Course:
	var course: Course = Course.new()
	course.template = id
	course.name = title(id)
	course.boards = boards
	course.axis_deg = fposmod(axis_deg, 360.0)
	var line_m: float = start_line_m(rules, id, boards)
	match id:
		"LG2", "LR2":
			_upwind_start(course, line_m)
			_windward_leeward(course, rules, wind_kt, id == "LG2")
		"O2", "I2":
			_upwind_start(course, line_m)
			_trapezoid(course, rules, wind_kt, id == "O2")
		"US3", "US4":
			_upwind_start(course, line_m)
			_upwind_sprint(course, rules, US3_MARKS if id == "US3" else US4_MARKS)
		"PD3", "SD3":
			_reaching_start(course, line_m)
			_slalom(course, rules, 1.0 if id == "PD3" else -1.0)
		"PM1", "SM1":
			_reaching_start(course, line_m)
			_medal_race(course, rules, 1.0 if id == "PM1" else -1.0)
		_:
			push_error("No course template called " + id)
			return null
	# From the frame to the map: up toward the wind, right 90 degrees clockwise from it.
	var up: Vector2 = Course.direction_of(axis_deg)
	var right: Vector2 = Course.direction_of(axis_deg + 90.0)
	for mark: CourseMark in course.marks:
		mark.position = start_middle + right * mark.position.x + up * mark.position.y
	return course


# ---------------------------------------------------------------- the courses, in the frame

## LG2 and LR2: mark 1 straight upwind, the leeward gate just above the start line, and a reach to
## the finish after the last run, to the left (LG2, through 4S) or the right (LR2, through 4P).
static func _windward_leeward(course: Course, rules: CourseRules, wind_kt: float, finish_left: bool) -> void:
	course.sequence = "Start-1-4S/4P-1-4S-Finish" if finish_left else "Start-1-4S/4P-1-4P-Finish"
	course.add_mark("1", Vector2(0.0, rules.windward_leeward_mark1_m(wind_kt)), PORT)
	_gate(course, "4", Vector2(0.0, rules.gate_above_start_m), rules.gate_m)
	var last: Vector2 = course.mark("4S" if finish_left else "4P").position
	_finish(course, rules, _reach(last, rules.finish_reach_m, rules.finish_reach_deg, not finish_left), last)


## O2 and I2 share one course: mark 1 upwind, a reach to the left to mark 2, the outer gate 3S/3P
## below mark 2 and the inner gate 4S/4P above the start line. O2 sails the outer loop twice, I2 the
## inner loop and then the outer one; both finish with a reach from 3P.
static func _trapezoid(course: Course, rules: CourseRules, wind_kt: float, outer: bool) -> void:
	course.sequence = "Start-1-2-3S/3P-2-3P-Finish" if outer else "Start-1-4S/4P-1-2-3P-Finish"
	var mark1: Vector2 = Vector2(0.0, rules.trapezoid_mark1_m(wind_kt))
	course.add_mark("1", mark1, PORT)
	var mark2: Vector2 = _reach(mark1, rules.trapezoid_reach_nm * CourseRules.NAUTICAL_MILE_M, rules.trapezoid_reach_deg, false)
	course.add_mark("2", mark2, PORT)
	_gate(course, "3", Vector2(mark2.x, rules.outer_gate_above_start_m), rules.gate_m)
	_gate(course, "4", Vector2(0.0, rules.gate_above_start_m), rules.gate_m)
	var last: Vector2 = course.mark("3P").position
	_finish(course, rules, _reach(last, rules.trapezoid_finish_m, rules.trapezoid_finish_deg, true), last)


## US3 and US4: one beat, then reaches and a run down to the finish (shapes from the diagrams).
static func _upwind_sprint(course: Course, rules: CourseRules, shape: Dictionary[String, Vector2]) -> void:
	var ids: PackedStringArray = PackedStringArray()
	for id: String in shape:
		if id != "Finish":
			ids.append(id)
	course.sequence = "Start-" + "-".join(ids) + "-Finish"
	# The diagrams: 1 and 2 are left to port, 3 to starboard, 4 to port.
	var sides: Dictionary[String, CourseMark.Rounding] = {"1": PORT, "2": PORT, "3": STARBOARD, "4": PORT}
	for id: String in ids:
		course.add_mark(id, shape[id] * rules.upwind_sprint_mark1_m, sides[id])
	_finish(course, rules, shape["Finish"] * rules.upwind_sprint_mark1_m, course.mark(ids[-1]).position)


## PD3 (mirror 1) and SD3 (mirror -1): a reaching start to mark 1, 600 m from the pin at 90 degrees
## from the wind; straight downwind to mark 2; then two slalom legs with 25 degrees between them
## (each 12.5 degrees below straight across the wind), gybing round mark 3, to the finish.
static func _slalom(course: Course, rules: CourseRules, mirror: float) -> void:
	course.sequence = "Start-1-2-3-Finish"
	var mark1: Vector2 = course.mark(CourseMark.START_PIN).position + Vector2(mirror * rules.reaching_mark1_m, 0.0)
	course.add_mark("1", mark1, STARBOARD if mirror > 0.0 else PORT)
	var mark2: Vector2 = mark1 + Vector2(0.0, -rules.downwind_leg_nm * CourseRules.NAUTICAL_MILE_M)
	course.add_mark("2", mark2, PORT if mirror > 0.0 else STARBOARD)
	var half: float = deg_to_rad(rules.slalom_turn_deg / 2.0)
	var mark3: Vector2 = mark2 + rules.slalom_leg_m * Vector2(mirror * cos(half), -sin(half))
	course.add_mark("3", mark3, STARBOARD if mirror > 0.0 else PORT)
	_finish(course, rules, mark3 + rules.slalom_leg_m * Vector2(-mirror * cos(half), -sin(half)), mark3)


## PM1 (mirror 1) and SM1 (mirror -1): a reaching start to mark 1, a run to the gate 2S/2P, a beat
## back to mark 1, a run, and a reach to the finish: to the right through 2P (PM1) or to the left
## through 2S (SM1).
static func _medal_race(course: Course, rules: CourseRules, mirror: float) -> void:
	course.sequence = "Start-1-2S/2P-1-2P-Finish" if mirror > 0.0 else "Start-1-2S/2P-1-2S-Finish"
	var mark1: Vector2 = course.mark(CourseMark.START_PIN).position + Vector2(mirror * rules.reaching_mark1_m, 0.0)
	course.add_mark("1", mark1, STARBOARD if mirror > 0.0 else PORT)
	_gate(course, "2", mark1 + Vector2(0.0, -rules.downwind_leg_nm * CourseRules.NAUTICAL_MILE_M), rules.gate_m)
	var last: Vector2 = course.mark("2P" if mirror > 0.0 else "2S").position
	_finish(course, rules, _reach(last, rules.finish_reach_m, rules.finish_reach_deg, mirror > 0.0), last)


# ---------------------------------------------------------------- the parts

## A start line across the wind: the committee boat at the right end (looking upwind), the pin at
## the left end, as on the diagrams.
static func _upwind_start(course: Course, length_m: float) -> void:
	course.add_mark(CourseMark.START_BOAT, Vector2(length_m / 2.0, 0.0))
	course.add_mark(CourseMark.START_PIN, Vector2(-length_m / 2.0, 0.0))


## A start line along the wind, for a reaching start: the committee boat at the upwind end.
static func _reaching_start(course: Course, length_m: float) -> void:
	course.add_mark(CourseMark.START_BOAT, Vector2(0.0, length_m / 2.0))
	course.add_mark(CourseMark.START_PIN, Vector2(0.0, -length_m / 2.0))


## A gate across the wind: number + "S" on the left (looking upwind), number + "P" on the right.
static func _gate(course: Course, number: String, middle: Vector2, width_m: float) -> void:
	course.add_mark(number + "S", middle - Vector2(width_m / 2.0, 0.0), STARBOARD)
	course.add_mark(number + "P", middle + Vector2(width_m / 2.0, 0.0), PORT)


## The finish line, square to the last leg (from the last mark to its middle), with the finish boat
## at its upwind end, as on the diagrams.
static func _finish(course: Course, rules: CourseRules, middle: Vector2, last_mark: Vector2) -> void:
	var across: Vector2 = (middle - last_mark).normalized().orthogonal()
	if across.y < 0.0:
		across = -across
	course.add_mark(CourseMark.FINISH_BOAT, middle + across * rules.finish_line_m / 2.0)
	course.add_mark(CourseMark.FINISH_PIN, middle - across * rules.finish_line_m / 2.0)


## The end of a reach from a point: a length, at an angle from the wind (0 straight upwind, 90 across,
## 180 straight downwind), to the right or the left looking upwind.
static func _reach(from: Vector2, length_m: float, from_wind_deg: float, to_right: bool) -> Vector2:
	var angle: float = deg_to_rad(from_wind_deg)
	return from + length_m * Vector2(sin(angle) * (1.0 if to_right else -1.0), cos(angle))
