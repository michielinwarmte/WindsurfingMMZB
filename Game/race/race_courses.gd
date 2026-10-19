class_name RaceCourses
extends RefCounted
## The courses races are sailed on (RACING_PLAN.md, "The two courses"), as the course maker's
## Course objects (RD5):
## - T1, the training loop on the open water: the windward-leeward course with a gate (LG2) at
##   30 % of the class's size, placed by code for the scene's wind;
## - T2, the sprint slalom on Lake Silvaplana: the course maker's save t2_slalom.json (fitted to
##   the water by CourseFitter), and until that file is there a sprint slalom (PD3) placed by code
##   as a stand-in;
## - any course saved by the course maker, by its file name.
## Where the boards wait before the start is here too: 150 m behind the start line, on a reach.

const RULES_PATH: String = "res://maps/course/iqfoil_courses.tres"
## The course maker's folder for Lake Silvaplana's courses (one JSON file each, in the project).
const SAVED_FOLDER: String = "res://maps/silvaplana/courses"
const T1_NAME: String = "t1_loop"
const T2_NAME: String = "t2_slalom"

## T1 is the class's course for 15 kt (mark 1 at 1 nautical mile), made 30 % as big: the beat is
## about 556 m, one lap about three minutes.
const T1_WIND_KT: float = 15.0
const T1_SIZE_PERCENT: float = 30.0
## The start line is set for four boards, and the class rule (boards x 2.2 m x 3) would give them
## 26 m; the skippers need room, so it is at least 60 m.
const T1_BOARDS: int = 4
const T1_START_LINE_M: float = 60.0
## The boards wait this far behind the start line before the start (the plan's pre-start).
const PRE_START_BEHIND_M: float = 150.0


## T1: the LG2 template set for a wind (where it comes from, degrees), so mark 1 lies straight
## upwind of the start, with the middle of the start line at a game point (X, Z).
static func t1_loop(wind_from_deg: float, start_middle: Vector2) -> Course:
	var rules: CourseRules = load(RULES_PATH) as CourseRules
	var course: Course = CourseTemplates.build("LG2", rules, T1_WIND_KT, T1_BOARDS, wind_from_deg, start_middle)
	course.set_size(T1_SIZE_PERCENT)
	var line_m: float = course.mark(CourseMark.START_BOAT).position.distance_to(course.mark(CourseMark.START_PIN).position)
	course.set_start_line_length(maxf(line_m, T1_START_LINE_M))
	_keep_the_gate_clear_of_the_start(course, rules)
	course.name = "T1 training loop"
	return course


## T2's stand-in, used only while t2_slalom.json is not there yet: the sprint slalom PD3 at the
## class's size, set for a wind (where it comes from, degrees), with the middle of the box around
## its marks at a game point (X, Z), as the course maker puts a new course in the middle of the view.
## It is not fitted to the water: some of it may lie on land.
static func t2_stand_in(wind_from_deg: float, centre: Vector2) -> Course:
	var rules: CourseRules = load(RULES_PATH) as CourseRules
	var course: Course = CourseTemplates.build("PD3", rules, T1_WIND_KT, CourseTemplates.default_boards("PD3"), wind_from_deg, Vector2.ZERO)
	course.move_by(centre - course.bounds().get_center())
	course.name = "T2 sprint slalom (stand-in, not fitted to the water)"
	return course


## A course saved by the course maker, by its file name (t2_slalom for t2_slalom.json), placed on
## the map with config; null if there is no such file. A file in game metres needs no map (null).
static func load_named(course_name: String, config: MapConfig) -> Course:
	var path: String = SAVED_FOLDER.path_join(course_name + ".json")
	if course_name.is_empty() or not FileAccess.file_exists(path):
		return null
	return Course.load_from(path, config)


## The names (file names without .json) of every course the course maker saved, in order.
static func saved_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	if not DirAccess.dir_exists_absolute(SAVED_FOLDER):
		return names
	for file: String in DirAccess.get_files_at(SAVED_FOLDER):
		if file.get_extension() == "json":
			names.append(file.get_basename())
	names.sort()
	return names


# ---------------------------------------------------------------- before the start

## Where a board waits before the start: PRE_START_BEHIND_M behind the middle of the start line,
## on the side away from the course (game X, Z).
static func pre_start_spot(course: Course) -> Vector2:
	return course.start_middle() - _course_side_of_start_line(course) * PRE_START_BEHIND_M


## The heading a board waits on before the start: a beam reach (90 degrees from the course's wind),
## the one of the two that heads toward mark 1; when both are as good (a start line across the
## wind, mark 1 straight upwind), starboard tack, the tack with right of way.
static func pre_start_heading_deg(course: Course) -> float:
	# The wind comes from the course's axis. On starboard tack it comes over the right side: the
	# board heads 90 degrees to the left of it.
	var starboard_deg: float = fposmod(course.axis_deg - 90.0, 360.0)
	var port_deg: float = fposmod(course.axis_deg + 90.0, 360.0)
	var legs: Array[Course.Leg] = course.legs()
	if legs.is_empty():
		return starboard_deg
	var first: Vector2 = (legs[0].to_point - legs[0].from_point).normalized()
	var toward_on_starboard: float = Course.direction_of(starboard_deg).dot(first)
	var toward_on_port: float = Course.direction_of(port_deg).dot(first)
	# A small margin, so a mark 1 a hair off the axis does not decide the tack.
	return port_deg if toward_on_port > toward_on_starboard + 0.1 else starboard_deg


## The direction across the start line (one metre long) toward the side the course is on: the side
## the first leg goes to. A line across the wind has the course upwind of it; a reaching start
## (PD3) has it on mark 1's side.
static func _course_side_of_start_line(course: Course) -> Vector2:
	var along: Vector2 = (course.mark(CourseMark.START_BOAT).position - course.mark(CourseMark.START_PIN).position).normalized()
	var across: Vector2 = along.orthogonal()
	var legs: Array[Course.Leg] = course.legs()
	var first: Vector2 = Course.direction_of(course.axis_deg)
	if not legs.is_empty():
		first = legs[0].to_point - legs[0].from_point
	return across if across.dot(first) >= 0.0 else -across


## The plan's T1 keeps the leeward gate 150 m above the start line (RACING_PLAN.md, T1), clear of
## the boards waiting to start, but scaling to 30 % brought it down to 45 m. The gate and the
## finish line move back up together, so the reach from the gate to the finish keeps its shape.
static func _keep_the_gate_clear_of_the_start(course: Course, rules: CourseRules) -> void:
	var upwind: Vector2 = Course.direction_of(course.axis_deg)
	var gate_above_m: float = (course.point_of("4S/4P") - course.start_middle()).dot(upwind)
	var lift: Vector2 = upwind * (rules.gate_above_start_m - gate_above_m)
	for id: String in ["4S", "4P", CourseMark.FINISH_BOAT, CourseMark.FINISH_PIN]:
		course.mark(id).position += lift
