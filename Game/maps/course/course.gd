class_name Course
extends RefCounted
## A race course on a map (MAP_SILVAPLANA_PLAN.md, W4a): its marks and the order in which they are
## sailed. The order is written as in the iQFOiL Notice of Race: "Start-1-4S/4P-1-4S-Finish" means
## start, round mark 1, through the gate 4S/4P (round either of its marks), round mark 1 again,
## round 4S, finish. A mark is left on the same side every time it is rounded.
##
## Positions are game metres (X east, Z south) on the lake's surface. Saved as JSON with Swiss
## LV95 coordinates (MD1), so a saved course stays where it is (WD6). A course on the open water
## has no Swiss coordinates: saved without a map (a null MapConfig), its file says
## "frame": "game" and keeps the game metres themselves (RACING_PLAN.md, RD5).
##
## Directions are compass bearings: 0 is north, 90 east. The course's axis is the wind direction it
## is set for: where the wind comes from, which is also where mark 1 lies from the start.

## One leg: from a point to the next, with the names of both ends ("Start", "1", "4S/4P").
class Leg:
	var from_point: Vector2
	var to_point: Vector2
	var from_name: String
	var to_name: String

	func length_m() -> float:
		return from_point.distance_to(to_point)

	## The compass course of the leg: the direction you sail, degrees.
	func bearing_deg() -> float:
		return Course.bearing_deg(from_point, to_point)


## How finely a leg is checked for land, metres.
const LAND_CHECK_STEP_M: float = 10.0
## The "frame" of a course file whose positions are game metres (x east, z south) instead of
## Swiss LV95. A file without a frame is in LV95, as every lake course saved before it.
const GAME_FRAME: String = "game"

var name: String = ""
## The template the course was made from, as in the Notice of Race (for example "LG2").
var template: String = ""
## The order the marks are sailed in, as in the Notice of Race.
var sequence: String = ""
## The wind direction the course is set for (where the wind comes from), degrees.
var axis_deg: float = 0.0
## How big the course is against the class's distances, percent.
var size_percent: float = 100.0
## How many boards the start line is set for.
var boards: int = 40
var marks: Array[CourseMark] = []


func add_mark(id: String, at: Vector2, side: CourseMark.Rounding = CourseMark.Rounding.NONE) -> CourseMark:
	var mark: CourseMark = CourseMark.new(id, at, side)
	marks.append(mark)
	return mark


## The mark with this name, or null.
func mark(id: String) -> CourseMark:
	for each: CourseMark in marks:
		if each.id == id:
			return each
	return null


## The mark that belongs with this one: the other mark of its gate, or the other end of its line.
## Null for a single mark.
func partner(of: CourseMark) -> CourseMark:
	match of.id:
		CourseMark.START_BOAT:
			return mark(CourseMark.START_PIN)
		CourseMark.START_PIN:
			return mark(CourseMark.START_BOAT)
		CourseMark.FINISH_BOAT:
			return mark(CourseMark.FINISH_PIN)
		CourseMark.FINISH_PIN:
			return mark(CourseMark.FINISH_BOAT)
	if of.is_gate_mark():
		return mark(of.id.left(-1) + ("P" if of.id.ends_with("S") else "S"))
	return null


func start_middle() -> Vector2:
	return _middle(CourseMark.START_BOAT, CourseMark.START_PIN)


func finish_middle() -> Vector2:
	return _middle(CourseMark.FINISH_BOAT, CourseMark.FINISH_PIN)


## The legs in the order they are sailed. A gate is sailed through its middle; the start and the
## finish are the middles of their lines. A step naming a mark that isn't there (a course file
## edited by hand) is left out.
func legs() -> Array[Leg]:
	var result: Array[Leg] = []
	var steps: PackedStringArray = PackedStringArray()
	for step: String in sequence.split("-"):
		if _step_exists(step):
			steps.append(step)
	for i: int in range(1, steps.size()):
		var leg: Leg = Leg.new()
		leg.from_name = steps[i - 1]
		leg.to_name = steps[i]
		leg.from_point = point_of(steps[i - 1])
		leg.to_point = point_of(steps[i])
		result.append(leg)
	return result


## Which way the course comes to a mark and goes on from it, the first time the mark is rounded:
## [the direction of the leg in, the direction of the leg out] (game X, Z, one metre long). For a
## gate's mark, the legs into and out of the gate. Empty if the mark is not in the order.
func turn_at(id: String) -> PackedVector2Array:
	var all_legs: Array[Leg] = legs()
	for i: int in range(all_legs.size() - 1):
		if id in all_legs[i].to_name.split("/"):
			return PackedVector2Array([
				(all_legs[i].to_point - all_legs[i].from_point).normalized(),
				(all_legs[i + 1].to_point - all_legs[i + 1].from_point).normalized()])
	return PackedVector2Array()


## Where a step of the sequence is: "Start", "Finish", a mark ("1") or a gate ("4S/4P").
func point_of(step: String) -> Vector2:
	if step == "Start":
		return start_middle()
	if step == "Finish":
		return finish_middle()
	var ids: PackedStringArray = step.split("/")
	var sum: Vector2 = Vector2.ZERO
	for id: String in ids:
		sum += mark(id).position
	return sum / ids.size()


# ---------------------------------------------------------------- changing the course

func move_by(offset: Vector2) -> void:
	for each: CourseMark in marks:
		each.position += offset


## Turns the whole course about a point. Positive degrees turn it clockwise seen from above, so
## every compass bearing in it grows by that much.
func turn_about(pivot: Vector2, degrees: float) -> void:
	# Seen from above with north up, X is east and Z south: a clockwise turn is a positive
	# rotation in the X-Z plane.
	for each: CourseMark in marks:
		each.position = pivot + (each.position - pivot).rotated(deg_to_rad(degrees))


## Makes the course bigger or smaller about a point. Gates and the start and finish lines keep
## their width: only their middles move.
func scale_about(pivot: Vector2, factor: float) -> void:
	var new_positions: Array[Vector2] = []
	for each: CourseMark in marks:
		var other: CourseMark = partner(each)
		if other == null:
			new_positions.append(pivot + (each.position - pivot) * factor)
		else:
			var middle: Vector2 = (each.position + other.position) / 2.0
			new_positions.append(pivot + (middle - pivot) * factor + (each.position - middle))
	for i: int in marks.size():
		marks[i].position = new_positions[i]


## Turns the course (about the middle of its start line) to be set for another wind direction.
func set_axis(new_axis_deg: float) -> void:
	turn_about(start_middle(), new_axis_deg - axis_deg)
	axis_deg = fposmod(new_axis_deg, 360.0)


## Makes the course a size (percent of the class's distances), about the middle of its start line.
func set_size(new_percent: float) -> void:
	scale_about(start_middle(), new_percent / size_percent)
	size_percent = new_percent


## Makes the start line a length, keeping its middle and its direction.
func set_start_line_length(length_m: float) -> void:
	var boat: CourseMark = mark(CourseMark.START_BOAT)
	var pin: CourseMark = mark(CourseMark.START_PIN)
	var middle: Vector2 = (boat.position + pin.position) / 2.0
	var along: Vector2 = (boat.position - pin.position).normalized()
	boat.position = middle + along * length_m / 2.0
	pin.position = middle - along * length_m / 2.0


# ---------------------------------------------------------------- adding and removing marks, the order

## A name for a new mark: the next number after the highest one in the course ("5" after 4S/4P).
func next_mark_id() -> String:
	var highest: int = 0
	for each: CourseMark in marks:
		var digits: String = ""
		for character: String in each.id:
			if not character.is_valid_int():
				break
			digits += character
		if not digits.is_empty():
			highest = maxi(highest, digits.to_int())
	return str(highest + 1)


## Puts a mark into legs: between the two ends of each leg (by its number in legs()).
func insert_into_legs(id: String, leg_numbers: Array[int]) -> void:
	var steps: PackedStringArray = sequence.split("-")
	var numbers: Array[int] = leg_numbers.duplicate()
	numbers.sort()
	numbers.reverse()
	# From the last leg back, so the earlier legs' places in the order don't shift.
	for number: int in numbers:
		steps.insert(number + 1, id)
	sequence = "-".join(steps)


## Takes a mark off the course, and out of the order. A gate goes as a whole; the start and finish
## lines stay. Where the order then has the same step twice in a row, it is sailed once.
func remove_mark(id: String) -> void:
	var target: CourseMark = mark(id)
	if target == null or target.is_line_end():
		return
	var removed: PackedStringArray = PackedStringArray([id])
	var other: CourseMark = partner(target)
	if target.is_gate_mark() and other != null:
		removed.append(other.id)
	var kept: Array[CourseMark] = []
	for each: CourseMark in marks:
		if not (each.id in removed):
			kept.append(each)
	marks = kept
	var steps: PackedStringArray = PackedStringArray()
	for step: String in sequence.split("-"):
		var uses_removed: bool = false
		for part: String in step.split("/"):
			uses_removed = uses_removed or part in removed
		if uses_removed or (not steps.is_empty() and steps[-1] == step):
			continue
		steps.append(step)
	sequence = "-".join(steps)


## Gives a mark a new name, also in the order. Returns what is wrong with the name, or "" when it
## was renamed.
func rename_mark(id: String, new_id: String) -> String:
	new_id = new_id.strip_edges()
	var target: CourseMark = mark(id)
	if target == null or new_id == id:
		return ""
	if target.is_line_end() or target.is_gate_mark():
		return "The marks of the lines and the gates keep their names."
	if new_id.is_empty() or new_id.length() > 6 or not _is_letters_and_digits(new_id):
		return "A mark's name is 1 to 6 letters or digits, like 5 or 1a."
	if new_id.to_lower() in ["start", "finish"] or mark(new_id) != null:
		return "There is already a mark called %s." % new_id
	if CourseMark.new(new_id, Vector2.ZERO).is_gate_mark():
		return "Names like 5S and 5P are for the two marks of a gate."
	target.id = new_id
	var steps: PackedStringArray = PackedStringArray()
	for step: String in sequence.split("-"):
		var parts: PackedStringArray = step.split("/")
		for i: int in parts.size():
			if parts[i] == id:
				parts[i] = new_id
		steps.append("/".join(parts))
	sequence = "-".join(steps)
	return ""


## Sets the order the marks are sailed in, typed as in the Notice of Race: "Start-1-4S/4P-1-4S-Finish".
## Spaces and small or capital letters don't matter. Returns what is wrong with it, or "" when it
## was set.
func set_sequence(text: String) -> String:
	var steps: PackedStringArray = text.replace(" ", "").split("-")
	if steps.size() < 3:
		return "The order needs Start, at least one mark, and Finish, with - between them."
	if steps[0].to_lower() != "start" or steps[-1].to_lower() != "finish":
		return "The order begins with Start and ends with Finish."
	steps[0] = "Start"
	steps[-1] = "Finish"
	for i: int in range(1, steps.size() - 1):
		var parts: PackedStringArray = steps[i].split("/")
		if parts.size() > 2:
			return "%s: a gate has two marks, like 4S/4P." % steps[i]
		for j: int in parts.size():
			var found: CourseMark = _mark_named(parts[j])
			if found == null or found.is_line_end():
				return "There is no mark called %s." % parts[j]
			parts[j] = found.id
		if parts.size() == 2:
			var first: CourseMark = mark(parts[0])
			if not first.is_gate_mark() or partner(first) == null or partner(first).id != parts[1]:
				return "%s: only the two marks of one gate go together, like 4S/4P." % steps[i]
		steps[i] = "/".join(parts)
	for i: int in range(1, steps.size()):
		if steps[i] == steps[i - 1]:
			return "%s twice in a row." % steps[i]
	sequence = "-".join(steps)
	return ""


## The rounding marks that are not in the order (yet).
func marks_not_in_order() -> PackedStringArray:
	var used: PackedStringArray = PackedStringArray()
	for step: String in sequence.split("-"):
		used.append_array(step.split("/"))
	var result: PackedStringArray = PackedStringArray()
	for each: CourseMark in marks:
		if not each.is_line_end() and not (each.id in used):
			result.append(each.id)
	return result


## The side a mark is naturally left on when a leg from one point to another is bent round it: a
## board turning right goes round it clockwise, leaving it to starboard. On the line (bent less
## than 5 degrees) port, the side iQFOiL courses mostly use.
static func natural_side(from: Vector2, at: Vector2, to: Vector2) -> CourseMark.Rounding:
	var turn: float = turn_deg(bearing_deg(from, at), bearing_deg(at, to))
	if absf(turn) < 5.0:
		return CourseMark.Rounding.PORT
	return CourseMark.Rounding.STARBOARD if turn > 0.0 else CourseMark.Rounding.PORT


## The smallest rectangle (game X, Z) around all marks.
func bounds() -> Rect2:
	var box: Rect2 = Rect2(marks[0].position, Vector2.ZERO)
	for each: CourseMark in marks:
		box = box.expand(each.position)
	return box


## What is wrong with the course on a map, in a few short lines: the marks on land, the marks off
## the map, and the legs that cross land. height_at(x, z) gives the ground's height above the lake's
## surface (negative in the lake), or NAN off the map.
func problems(height_at: Callable) -> PackedStringArray:
	var on_land: PackedStringArray = PackedStringArray()
	var off_map: PackedStringArray = PackedStringArray()
	for each: CourseMark in marks_not_on_water(height_at):
		if is_nan(height_at.call(each.position.x, each.position.y)):
			off_map.append(each.id)
		else:
			on_land.append(each.id)
	var crossing: PackedStringArray = PackedStringArray()
	for leg: Leg in legs_over_land(height_at):
		crossing.append("%s → %s" % [leg.from_name, leg.to_name])
	var found: PackedStringArray = PackedStringArray()
	if not on_land.is_empty():
		found.append("On land: " + ", ".join(on_land))
	if not off_map.is_empty():
		found.append("Off the map: " + ", ".join(off_map))
	if not crossing.is_empty():
		found.append("Legs over land: " + ", ".join(crossing))
	return found


## The marks on land or off the map (see problems()).
func marks_not_on_water(height_at: Callable) -> Array[CourseMark]:
	var result: Array[CourseMark] = []
	for each: CourseMark in marks:
		var height: float = height_at.call(each.position.x, each.position.y)
		if is_nan(height) or height > 0.0:
			result.append(each)
	return result


## The legs that cross land somewhere between their ends, checked every LAND_CHECK_STEP_M.
func legs_over_land(height_at: Callable) -> Array[Leg]:
	var result: Array[Leg] = []
	for leg: Leg in legs():
		var steps: int = maxi(ceili(leg.length_m() / LAND_CHECK_STEP_M), 1)
		for i: int in range(1, steps):
			var point: Vector2 = leg.from_point.lerp(leg.to_point, float(i) / steps)
			if height_at.call(point.x, point.y) > 0.0:
				result.append(leg)
				break
	return result


## A copy that can be changed without changing this one (for undo).
func copy() -> Course:
	var result: Course = Course.new()
	result.name = name
	result.template = template
	result.sequence = sequence
	result.axis_deg = axis_deg
	result.size_percent = size_percent
	result.boards = boards
	for each: CourseMark in marks:
		result.add_mark(each.id, each.position, each.side)
	return result


# ---------------------------------------------------------------- course files

## The course as a dictionary for a JSON file, with LV95 positions to the centimetre. Without a map
## (config null: the open water) the positions are game metres, and the file says so.
func to_dict(config: MapConfig) -> Dictionary:
	if config == null:
		return _to_game_frame_dict()
	var mark_list: Array[Dictionary] = []
	for each: CourseMark in marks:
		var lv95: PackedFloat64Array = config.game_to_lv95(Vector3(each.position.x, 0.0, each.position.y))
		mark_list.append({
			"id": each.id,
			"side": CourseMark.side_name(each.side),
			"east": snappedf(lv95[0], 0.01),
			"north": snappedf(lv95[1], 0.01),
		})
	return {
		"about": "A race course for the course maker (MAP_SILVAPLANA_PLAN.md, W4a). Positions are Swiss LV95 metres; sides are the side each mark is left on.",
		"name": name,
		"map": config.map_name,
		"template": template,
		"sequence": sequence,
		"axis_deg": snappedf(axis_deg, 0.1),
		"size_percent": size_percent,
		"boards": boards,
		"marks": mark_list,
	}


## The open water's file: the same course, with game metres (x east, z south) to the centimetre.
func _to_game_frame_dict() -> Dictionary:
	var mark_list: Array[Dictionary] = []
	for each: CourseMark in marks:
		mark_list.append({
			"id": each.id,
			"side": CourseMark.side_name(each.side),
			"x": snappedf(each.position.x, 0.01),
			"z": snappedf(each.position.y, 0.01),
		})
	return {
		"about": "A race course on the open water (RACING_PLAN.md, RD5). Positions are game metres, x east and z south; sides are the side each mark is left on.",
		"frame": GAME_FRAME,
		"name": name,
		"template": template,
		"sequence": sequence,
		"axis_deg": snappedf(axis_deg, 0.1),
		"size_percent": size_percent,
		"boards": boards,
		"marks": mark_list,
	}


## A course from its file's dictionary. A file in game metres needs no map (config may be null);
## a file in LV95 needs the map it was made on, and without one there is no course (null).
static func from_dict(data: Dictionary, config: MapConfig) -> Course:
	var in_game_metres: bool = str(data.get("frame", "")) == GAME_FRAME
	if not in_game_metres and config == null:
		push_error("The course \"%s\" is in Swiss coordinates: it needs its map to be placed." % str(data.get("name", "")))
		return null
	var course: Course = Course.new()
	course.name = str(data.get("name", ""))
	course.template = str(data.get("template", ""))
	course.sequence = str(data.get("sequence", ""))
	course.axis_deg = float(data.get("axis_deg", 0.0))
	course.size_percent = float(data.get("size_percent", 100.0))
	course.boards = int(data.get("boards", 40))
	for item: Dictionary in data.get("marks", []):
		var side: CourseMark.Rounding = CourseMark.side_from_name(str(item.get("side", "")))
		if in_game_metres:
			course.add_mark(str(item["id"]), Vector2(float(item["x"]), float(item["z"])), side)
		else:
			var at: Vector3 = config.lv95_to_game(float(item["east"]), float(item["north"]), config.lake_level_m)
			course.add_mark(str(item["id"]), Vector2(at.x, at.z), side)
	return course


## Saves the course as JSON: in LV95 on a map, in game metres without one (config null).
func save(path: String, config: MapConfig) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(to_dict(config), "\t", false) + "\n")
	return OK


## Reads a course file; null if it can't be read. config may be null for a file in game metres.
static func load_from(path: String, config: MapConfig) -> Course:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary):
		return null
	return from_dict(data, config)


# ---------------------------------------------------------------- directions

## The compass bearing from one game point (X, Z) to another, 0 to 360 degrees.
static func bearing_deg(from: Vector2, to: Vector2) -> float:
	var step: Vector2 = to - from
	# North is -Z and east +X.
	return fposmod(rad_to_deg(atan2(step.x, -step.y)), 360.0)


## The game direction (X, Z) of a compass bearing, one metre long.
static func direction_of(bearing: float) -> Vector2:
	var radians: float = deg_to_rad(bearing)
	return Vector2(sin(radians), -cos(radians))


## How far a bearing is turned clockwise from another, -180 to 180 degrees.
static func turn_deg(from_bearing: float, to_bearing: float) -> float:
	return fposmod(to_bearing - from_bearing + 180.0, 360.0) - 180.0


func _middle(a: String, b: String) -> Vector2:
	return (mark(a).position + mark(b).position) / 2.0


func _step_exists(step: String) -> bool:
	if step in ["Start", "Finish"]:
		return true
	for id: String in step.split("/"):
		if mark(id) == null:
			return false
	return true


## The mark with this name, also when it is typed in small letters ("4s" for 4S); null if none.
func _mark_named(text: String) -> CourseMark:
	var exact: CourseMark = mark(text)
	if exact != null:
		return exact
	for each: CourseMark in marks:
		if each.id.to_lower() == text.to_lower():
			return each
	return null


static func _is_letters_and_digits(text: String) -> bool:
	for character: String in text:
		var letter: bool = character.to_lower() != character.to_upper()
		if not letter and not character.is_valid_int():
			return false
	return true
