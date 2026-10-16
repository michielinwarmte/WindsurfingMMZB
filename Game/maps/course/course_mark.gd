class_name CourseMark
extends RefCounted
## One mark of a race course (MAP_SILVAPLANA_PLAN.md, W4a): a buoy that is rounded, or one end of
## the start or finish line (a boat or a pin).

## Port: the mark is left on the board's left, so the board goes round it anticlockwise (seen from
## above). Starboard: on its right, clockwise. The ends of the start and finish lines have no side.
enum Rounding { NONE, PORT, STARBOARD }

## The ends of the start and finish lines. The committee boat flies an orange flag, the finish boat
## a blue one (Sailing Instructions 18.2 and 20).
const START_BOAT: String = "start boat"
const START_PIN: String = "start pin"
const FINISH_BOAT: String = "finish boat"
const FINISH_PIN: String = "finish pin"

## The name, as on the course diagrams ("1", "2", "3S", "4P"), or one of the line ends above.
var id: String = ""
## Where it is: game X and Z (east and south), metres, on the lake's surface.
var position: Vector2 = Vector2.ZERO
var side: Rounding = Rounding.NONE


func _init(mark_id: String, at: Vector2, rounding_side: Rounding = Rounding.NONE) -> void:
	id = mark_id
	position = at
	side = rounding_side


## True for the ends of the start and finish lines.
func is_line_end() -> bool:
	return id in [START_BOAT, START_PIN, FINISH_BOAT, FINISH_PIN]


## True for the boats at the ends of the lines (the race committee's vessels).
func is_boat() -> bool:
	return id == START_BOAT or id == FINISH_BOAT


## True for one of the two marks of a gate: a number with S or P after it, like "4S".
func is_gate_mark() -> bool:
	return id.length() >= 2 and id.left(-1).is_valid_int() and id.right(1) in ["S", "P"]


## The side as a word, for the course files: "port", "starboard" or "".
static func side_name(rounding_side: Rounding) -> String:
	match rounding_side:
		Rounding.PORT:
			return "port"
		Rounding.STARBOARD:
			return "starboard"
	return ""


## The side from its word in a course file.
static func side_from_name(text: String) -> Rounding:
	match text:
		"port":
			return Rounding.PORT
		"starboard":
			return Rounding.STARBOARD
	return Rounding.NONE
