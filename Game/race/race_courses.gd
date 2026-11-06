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
## Where the boards wait before the start is here too: 150 m behind the start line, on a reach; on a
## slalom (Course.RaceType.SLALOM) upwind of the committee boat, to reach down onto the line.

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
## A slalom's start (Max, 6 November 2026: "Start upwind of the startboat on a slalom race"): the
## boards wait in a row SLALOM_WAIT_UPWIND_M upwind of the committee boat, spread across the wind
## on the side away from the course. At the gun each bears away onto a broad reach
## SLALOM_DIVE_TWA_DEG from the wind and reaches down onto the line. Each spot of the row is set back
## up that broad reach from a point of the line: the row's near end crosses the line by the boat,
## its far end SLALOM_FARTHEST_CROSSING_M down the line (or at its pin end if the line is shorter).
## On a reaching line (along the wind) the row then runs 30 to 115 m out from the line. It stays
## inside the sailing area (SailingArea.UPWIND_M above the boat, ACROSS_M across). ESTIMATES of a
## slalom's waiting area, not class numbers; 140 degrees is a broad reach a slalom board sails at full
## speed. (A row of fixed spots 35 to 120 m out put the far end's broad reach past the pin of a short
## line: its boards aimed at the pin from too far up, ran over the line's extension and started 15 s
## late, on iq_pd3.)
const SLALOM_WAIT_UPWIND_M: float = 35.0
const SLALOM_FARTHEST_CROSSING_M: float = 100.0
const SLALOM_DIVE_TWA_DEG: float = 140.0
## The crossing is kept this far in from the line's ends, metres.
const SLALOM_LINE_INSET_M: float = 6.0


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
	course.name = "T2 sprint slalom (stand-in)"
	return course


## A template as a race course, from a name "template:<ID>" or "template:<ID>@<percent>" (template:O2,
## template:PD3@60): the iQFOiL template at that size (the class's full size without one), set for a
## wind direction with the middle of its start line at a point, for 24 boards; the start line at
## least T1's 60 m. Null for any other name, or an unknown template. This is how the trained head is
## raced on every template (AI_FLEET_PLAN.md, D6: "the test before the game").
static func template_named(course_name: String, wind_from_deg: float, start_middle: Vector2) -> Course:
	if not course_name.begins_with("template:"):
		return null
	var spec: PackedStringArray = course_name.trim_prefix("template:").split("@", true, 1)
	var id: String = spec[0].strip_edges().to_upper()
	if not CourseTemplates.ALL.has(id):
		push_error("No course template called '%s' (they are %s)." % [id, ", ".join(CourseTemplates.ALL)])
		return null
	var rules: CourseRules = load(RULES_PATH) as CourseRules
	var course: Course = CourseTemplates.build(id, rules, T1_WIND_KT, 24, wind_from_deg, start_middle)
	var percent: float = clampf(spec[1].to_float(), 10.0, 200.0) if spec.size() > 1 and spec[1].to_float() > 0.0 else 100.0
	if percent != 100.0:
		course.set_size(percent)
	var line_m: float = course.mark(CourseMark.START_BOAT).position.distance_to(course.mark(CourseMark.START_PIN).position)
	course.set_start_line_length(maxf(line_m, T1_START_LINE_M))
	course.name = "%s at %.0f %%" % [id, percent]
	return course


## A course saved by the course maker, by its file name (t2_slalom for t2_slalom.json), placed on
## the map with config; null if there is no such file. A file in game metres needs no map (null).
static func load_named(course_name: String, config: MapConfig) -> Course:
	var path: String = SAVED_FOLDER.path_join(course_name + ".json")
	if course_name.is_empty() or not FileAccess.file_exists(path):
		return null
	return Course.load_from(path, config)


## A saved course's title for the menus: the name it was saved under ("iQFOiL Trapezoid, outer loop
## (O2)"), or its file name when the file has none.
static func saved_title(course_name: String) -> String:
	var path: String = SAVED_FOLDER.path_join(course_name + ".json")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if data is Dictionary and String((data as Dictionary).get("name", "")) != "":
		return String((data as Dictionary)["name"])
	return course_name


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

## Where `count` boards wait before the start: on a slalom in the row upwind of the committee boat
## (slalom_slot()), otherwise `behind_m` behind the start line, spread along it; the first spot is
## the middle one (the player's), then the others in order.
static func wait_spots(course: Course, count: int, behind_m: float) -> PackedVector2Array:
	var spots: PackedVector2Array = PackedVector2Array()
	var player_slot: int = count / 2
	var order: Array[int] = [player_slot]
	for i: int in count:
		if i != player_slot:
			order.append(i)
	for i: int in order:
		spots.append(wait_spot(course, float(i + 1) / float(count + 1), behind_m))
	return spots


## Where one board waits, at `share` (0 to 1) of the way across the waiting area: on a slalom the
## row upwind of the committee boat (share 1 nearest the line, 0 farthest out); otherwise behind
## the middle of the start line by `behind_m`, at `share` of the line's length from the pin (0) to
## the boat (1).
static func wait_spot(course: Course, share: float, behind_m: float) -> Vector2:
	if course.starts_upwind_of_the_boat():
		return slalom_slot(course, share)
	var boat: Vector2 = course.mark(CourseMark.START_BOAT).position
	var pin: Vector2 = course.mark(CourseMark.START_PIN).position
	var back: Vector2 = -_course_side_of_start_line(course)
	return course.start_middle() + back * behind_m + (boat - pin) * (share - 0.5)


## A slalom's waiting spot (SLALOM_WAIT_UPWIND_M upwind of the committee boat), at `share` of the
## row: 1 at its end nearest the line (its broad reach crosses the line by the boat), 0 at its far
## end (crossing SLALOM_FARTHEST_CROSSING_M down the line, or by the pin of a shorter line). The spot
## is that point of the line, moved back up the broad reach (slalom_dive_direction()) to the row's
## height.
static func slalom_slot(course: Course, share: float) -> Vector2:
	var boat: Vector2 = course.mark(CourseMark.START_BOAT).position
	var pin: Vector2 = course.mark(CourseMark.START_PIN).position
	var length_m: float = boat.distance_to(pin)
	var inset: float = minf(SLALOM_LINE_INSET_M, 0.4 * length_m)
	# Where its broad reach would cross a line SLALOM_FARTHEST_CROSSING_M long, and where it crosses
	# this one (no further than the pin).
	var wanted_m: float = lerpf(maxf(SLALOM_FARTHEST_CROSSING_M, inset), inset, clampf(share, 0.0, 1.0))
	var along_m: float = clampf(wanted_m, inset, maxf(length_m - inset, inset))
	var crossing: Vector2 = boat.lerp(pin, along_m / maxf(length_m, 0.01))
	var up: Vector2 = Course.direction_of(course.axis_deg)
	var dive: Vector2 = slalom_dive_direction(course)
	# Back up the broad reach until it is SLALOM_WAIT_UPWIND_M above the boat; on a line shorter than
	# the row needs, the far spots further up their reach (by as much as the line falls short), so
	# that the row keeps its width and every reach still meets the line (a short line's row of fixed
	# height had its boards 3 m apart on T2).
	var line_falls_m: float = (pin - boat).normalized().dot(-up)
	var climb_m: float = SLALOM_WAIT_UPWIND_M + (boat - crossing).dot(up) + (wanted_m - along_m) * maxf(line_falls_m, 0.0)
	return crossing - dive * climb_m / maxf(-dive.dot(up), 0.2)


## The direction of a slalom's dive onto the line (one metre long): a broad reach SLALOM_DIVE_TWA_DEG
## from the course's wind, on the tack that crosses the line toward the course.
static func slalom_dive_direction(course: Course) -> Vector2:
	var toward_course: Vector2 = _course_side_of_start_line(course)
	var one: Vector2 = Course.direction_of(course.axis_deg + SLALOM_DIVE_TWA_DEG)
	var other: Vector2 = Course.direction_of(course.axis_deg - SLALOM_DIVE_TWA_DEG)
	return one if one.dot(toward_course) >= other.dot(toward_course) else other


## Where a slalom's dive from a waiting spot meets the start line, kept SLALOM_LINE_INSET_M in from
## its ends (the nearer end if the dive would miss the line).
static func slalom_crossing(course: Course, from: Vector2) -> Vector2:
	var boat: Vector2 = course.mark(CourseMark.START_BOAT).position
	var pin: Vector2 = course.mark(CourseMark.START_PIN).position
	var dive: Vector2 = slalom_dive_direction(course)
	var length_m: float = boat.distance_to(pin)
	var along: Vector2 = (pin - boat) / maxf(length_m, 0.01)
	# The dive's ray against the line through the boat: from + dive * t = boat + along * u.
	# (Crossed with the dive: (from - boat) x dive = u (along x dive).)
	var across: float = along.cross(dive)
	var u: float = 0.0
	if absf(across) > 1e-4:
		u = (from - boat).cross(dive) / across
	var inset: float = minf(SLALOM_LINE_INSET_M, 0.4 * length_m)
	return boat + along * clampf(u, inset, length_m - inset)


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
