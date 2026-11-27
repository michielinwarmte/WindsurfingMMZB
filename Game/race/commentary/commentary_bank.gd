class_name CommentaryBank
extends RefCounted
## The commentator's lines (Documentation/reports/broadcast/BANK_FORMAT.md): one JSON file the stream
## tools write (tools/broadcast/) and the game only reads. A line is what he says in one go, his own
## words, with a real rider's or maker's name turned into a slot ("{rider} takes the lead"); each line
## belongs to one moment of the race and may ask for extra conditions (`needs`).
##
## Loading checks every line against the contract below. A line with an unknown moment, an unknown slot,
## an unknown `needs` word, slots that do not match its text, or a missing number is left out, and the
## reason is kept in `problems` (the game warns once; the tests fail on any). The good lines are kept by
## moment, so the commentary director finds a moment's lines at once.

## The bank's format number this game reads.
const FORMAT: int = 1
## Where the game's bank is (a .json file: the release build's export filter takes every *.json).
const PATH: String = "res://race/commentary/commentary_bank.json"

## The moments of BANK_FORMAT.md, in its order. The bank's builders use only these.
const MOMENTS: PackedStringArray = [
	"pre_start", "start_gun", "start_good", "start_bad", "over_early",
	"identify", "speed", "leader", "rundown", "lead_change", "overtake", "chase", "fight", "airtime", "filler",
	"tactics", "tension", "form", "conditions",
	"mark_approach", "gybe_good", "gybe_safe", "gybe_bad",
	"fall", "near_miss", "trouble",
	"wow", "oh_no",
	"last_leg", "finish_win", "finish_place", "photo_finish", "after_race",
	"camera", "unsure",
	# An event week (EventBroadcast): the heat called, its favourite, who goes through, who is out,
	# the elimination won, the standings, the week won.
	"heat_called", "heat_favourite", "heat_through", "heat_out", "final_win", "standings", "event_win",
]
## The slots of BANK_FORMAT.md ("The slots"). The game fills all but the sailor's nation ({national},
## {nation_adj}: the game's sailors have no country yet), so a line with one of those is skipped.
const SLOTS: PackedStringArray = ["rider", "rider2", "place", "brand", "colour", "mark", "leg", "national", "nation_adj",
	"heat", "round", "elimination", "event"]
## The lines written for the game's event week (the heat called, who goes through, the standings):
## read on top of the stream's bank, so a rebuilt bank keeps them.
const EVENT_PATH: String = "res://race/commentary/commentary_bank_event.json"
## The extra conditions the director knows (BANK_FORMAT.md, "needs").
const NEEDS: PackedStringArray = ["leader", "not_leader", "podium", "big_lead", "close", "camera_wide", "camera_close", "many", "pair", "last_lap",
	"wind_strong", "wind_light", "choppy", "flat", "windward", "leeward", "dirty_air",
	# An event week's heat (RaceMoment.tags): one of the two finals, or a heat four go through from.
	"final", "not_final"]
## The levels of excitement: 1 calm, 2 the normal race voice, 3 lifted, 4 shouting.
const LOWEST_LEVEL: int = 1
const HIGHEST_LEVEL: int = 4


## One line of the bank.
class Line:
	## Never reused: "used lately" follows a line through a rebuilt bank.
	var id: String = ""
	var moment: String = ""
	## His words, with the slots in braces.
	var text: String = ""
	## The slots in the text, in order.
	var slots: PackedStringArray = PackedStringArray()
	## How excited he says it, 1 to 4.
	var level: int = 2
	## How long he takes to say it, seconds.
	var seconds: float = 1.0
	## How often he said these words in the streams read so far (a staple of his is said more).
	var count: int = 1
	var needs: PackedStringArray = PackedStringArray()
	## Where it was said: video id @ seconds. Not shown in the game.
	var src: String = ""


## Where the bank came from (its path, or what the tests call it).
var origin: String = ""
## What the file says of itself.
var made: String = ""
var source: String = ""
## Every line that passed the checks, in the file's order.
var lines: Array[Line] = []
## Why lines (or the whole file) were left out: one sentence each, the line's id first.
var problems: PackedStringArray = PackedStringArray()

var _by_moment: Dictionary[String, Array] = {}
var _by_id: Dictionary[String, Line] = {}


## The game's bank (or another file), read and checked. A missing or broken file gives an empty bank
## with the reason in `problems`.
static func load_file(path: String = PATH) -> CommentaryBank:
	if not FileAccess.file_exists(path):
		var empty: CommentaryBank = CommentaryBank.new()
		empty.origin = path
		empty.problems.append("No commentary bank at %s." % path)
		return empty
	return from_json(FileAccess.get_file_as_string(path), path)


## A bank from the text of a bank file (the tests make small ones).
static func from_json(text: String, from: String = "") -> CommentaryBank:
	var bank: CommentaryBank = CommentaryBank.new()
	bank.origin = from
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		bank.problems.append("The bank is not valid JSON (line %d: %s)." % [json.get_error_line(), json.get_error_message()])
		return bank
	var data: Dictionary = json.data as Dictionary if json.data is Dictionary else {}
	if data.is_empty():
		bank.problems.append("The bank is not a JSON object.")
		return bank
	bank._read(data)
	return bank


## Another file's lines on top of this bank's (the same format and checks; an id used twice is left
## out with its problem noted). False when the file is missing or broken.
func add_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not (json.data is Dictionary):
		problems.append("The extra bank %s is not valid JSON." % path)
		return false
	var kept_made: String = made
	var kept_source: String = source
	_read(json.data as Dictionary)
	made = kept_made
	source = kept_source
	return true


## The good lines of a moment, in the file's order (empty for a moment with none).
func lines_for(moment: String) -> Array[Line]:
	var found: Array[Line] = []
	found.assign(_by_moment.get(moment, []))
	return found


## The line with this id, or null.
func line(id: String) -> Line:
	return _by_id.get(id, null)


func size() -> int:
	return lines.size()


## Every problem as a warning on the console (the game's way; the tests fail on them instead).
func warn_problems() -> void:
	for problem: String in problems:
		push_warning("Commentary bank %s: %s" % [origin, problem])


# ---------------------------------------------------------------- reading and checking

func _read(data: Dictionary) -> void:
	var format: Variant = data.get("format", null)
	if not (format is float or format is int) or int(format) != FORMAT:
		problems.append("The bank's format is %s; this game reads format %d." % [str(format), FORMAT])
		return
	made = str(data.get("made", ""))
	source = str(data.get("source", ""))
	var moments: Variant = data.get("moments", {})
	if moments is Dictionary:
		for moment: Variant in (moments as Dictionary).keys():
			if not MOMENTS.has(str(moment)):
				problems.append("The moments list names an unknown moment '%s'." % str(moment))
	var raw_lines: Variant = data.get("lines", null)
	if not raw_lines is Array:
		problems.append("The bank has no list of lines.")
		return
	for raw: Variant in raw_lines as Array:
		if not raw is Dictionary:
			problems.append("A line that is not a JSON object was left out.")
			continue
		var made_line: Line = _line_from(raw as Dictionary)
		if made_line == null:
			continue
		lines.append(made_line)
		_by_id[made_line.id] = made_line
		if not _by_moment.has(made_line.moment):
			_by_moment[made_line.moment] = []
		_by_moment[made_line.moment].append(made_line)


## One line checked; null (and its problem noted) when it breaks the contract.
func _line_from(raw: Dictionary) -> Line:
	var made_line: Line = Line.new()
	made_line.id = str(raw.get("id", ""))
	var tag: String = made_line.id if made_line.id != "" else "(a line without an id)"
	if made_line.id == "":
		problems.append("%s: no id." % tag)
		return null
	if _by_id.has(made_line.id):
		problems.append("%s: the id is used twice." % tag)
		return null
	made_line.moment = str(raw.get("moment", ""))
	if not MOMENTS.has(made_line.moment):
		problems.append("%s: unknown moment '%s'." % [tag, made_line.moment])
		return null
	made_line.text = str(raw.get("text", "")).strip_edges()
	if made_line.text == "":
		problems.append("%s: no words." % tag)
		return null
	if not _read_words(raw, "slots", SLOTS, made_line.slots, tag, "slot"):
		return null
	if not _read_words(raw, "needs", NEEDS, made_line.needs, tag, "needs word"):
		return null
	var why: String = slots_problem(made_line.text, made_line.slots)
	if why != "":
		problems.append("%s: %s" % [tag, why])
		return null
	var level: Variant = raw.get("level", null)
	if not (level is float or level is int) or float(level) != roundf(float(level)) or int(level) < LOWEST_LEVEL or int(level) > HIGHEST_LEVEL:
		problems.append("%s: the level must be a whole number from %d to %d, not %s." % [tag, LOWEST_LEVEL, HIGHEST_LEVEL, str(level)])
		return null
	made_line.level = int(level)
	var seconds: Variant = raw.get("seconds", null)
	if not (seconds is float or seconds is int) or float(seconds) <= 0.0:
		problems.append("%s: the seconds must be a number above 0, not %s." % [tag, str(seconds)])
		return null
	made_line.seconds = float(seconds)
	var count: Variant = raw.get("count", 1)
	made_line.count = maxi(int(count), 1) if (count is float or count is int) else 1
	made_line.src = str(raw.get("src", ""))
	return made_line


## A list of words (the slots, the needs), each one known; false (and the problem noted) otherwise.
func _read_words(raw: Dictionary, key: String, known: PackedStringArray, into: PackedStringArray, tag: String, what: String) -> bool:
	var value: Variant = raw.get(key, [])
	if not value is Array:
		problems.append("%s: '%s' is not a list." % [tag, key])
		return false
	for word: Variant in value as Array:
		if not known.has(str(word)):
			problems.append("%s: unknown %s '%s'." % [tag, what, str(word)])
			return false
		into.append(str(word))
	return true


## Why the slots in a text do not match the list of slots ("" when they do): every {slot} in the text
## must be in the list and every slot of the list in the text, and a brace stands only round a slot.
static func slots_problem(text: String, slots: PackedStringArray) -> String:
	var in_text: PackedStringArray = slots_in(text)
	for slot: String in in_text:
		if not SLOTS.has(slot):
			return "unknown slot '{%s}' in the words." % slot
		if not slots.has(slot):
			return "the words have {%s} but the slots do not list it." % slot
	for slot: String in slots:
		if not in_text.has(slot):
			return "the slot '%s' is listed but not in the words." % slot
	var bare: String = text
	for slot: String in in_text:
		bare = bare.replace("{%s}" % slot, "")
	if bare.contains("{") or bare.contains("}"):
		return "a brace in the words that is not round a slot."
	return ""


## The slots written in a text, in order ("{rider} and {rider2}" gives rider, rider2).
static func slots_in(text: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var regex: RegEx = RegEx.create_from_string("\\{([a-z0-9_]+)\\}")
	for match_found: RegExMatch in regex.search_all(text):
		found.append(match_found.get_string(1))
	return found
