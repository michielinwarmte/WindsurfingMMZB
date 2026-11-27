class_name EventRoster
extends RefCounted
## The sailors of an event week (Documentation/reports/broadcast/EVENT_WEEK_PLAN.md): 64, each
## with a name, a country, a sail number, a place in the ranking before the event, and a persona
## (the skills and the gear the game sails him with).
##
## Until the team's own roster exists (backlog E10.S02: Max's names), this is a provisional one:
## the names and countries come from res://race/event/provisional_roster.json (made-up placeholder
## names, the favourite first), and each sailor's persona is one of the game's twenty characters
## with its skills moved by his ranking place: the favourites near the top of every skill, the
## tail-enders well below, each character's own strengths and weaknesses kept. The same every
## time: nothing is drawn at random here.

const ROSTER_PATH: String = "res://race/event/provisional_roster.json"
## The sailing skills a ranking place moves (Persona's 0 to 1 numbers).
const SKILLS: PackedStringArray = ["start_timing", "start_nerve", "tacking", "gybing", "boat_speed",
	"upwind_sense", "downwind_sense", "consistency"]
## A skill's level for the favourite and for the last of the ranking, before the character's own
## shape is added (the lead's choice: a clear favourite, a field that can still finish a heat).
const BEST_LEVEL: float = 0.95
const LAST_LEVEL: float = 0.55
## How much of a character's own shape (its skill against its own mean) a sailor keeps.
const SHAPE_SHARE: float = 0.5


class Sailor:
	extends RefCounted
	var id: int = 0                 ## 0 to 63, his place in the roster file
	var name: String = ""
	var country: String = ""        ## "Italy"
	var national: String = ""       ## "Italian": the commentator's "the Italian"
	var nation_adj: String = ""     ## "Polish": "the Polish rider"
	var sail_number: String = ""    ## "ITA-47"
	var ranking: int = 0            ## 1 the favourite
	var persona: Persona = null
	var is_player: bool = false     ## this sailor is the player (he sails his own heats)

	## His sailor on the water: a scripted skipper with his persona.
	func make_skipper() -> RaceSkipper:
		var skipper: Skipper = Skipper.new()
		skipper.persona = persona
		skipper.config = persona.to_skipper_config(0)
		return skipper


var sailors: Array[Sailor] = []


## The provisional roster, or null (with an error) when the file is missing or broken.
static func provisional() -> EventRoster:
	var file: FileAccess = FileAccess.open(ROSTER_PATH, FileAccess.READ)
	if file == null:
		push_error("The event's roster %s can't be read." % ROSTER_PATH)
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary) or not ((parsed as Dictionary).get("sailors") is Array):
		push_error("The event's roster %s isn't a list of sailors." % ROSTER_PATH)
		return null
	var rows: Array = (parsed as Dictionary)["sailors"]
	var characters: PackedStringArray = Skippers.persona_names()
	var roster: EventRoster = EventRoster.new()
	for i: int in rows.size():
		var row: Dictionary = rows[i]
		var sailor: Sailor = Sailor.new()
		sailor.id = i
		sailor.name = String(row.get("name", "Sailor %d" % (i + 1)))
		sailor.country = String(row.get("country", ""))
		sailor.national = String(row.get("national", ""))
		sailor.nation_adj = String(row.get("nation_adj", ""))
		sailor.sail_number = String(row.get("sail_number", ""))
		sailor.ranking = i + 1
		var base: Persona = Skippers.load_persona(characters[i % characters.size()])
		sailor.persona = _persona_for(base, sailor, rows.size())
		roster.sailors.append(sailor)
	return roster


## A character's sheet moved to a ranking place: his own name and sail colour, the character's
## style, wind skills and gear, and the sailing skills at the place's level with half of the
## character's own shape on top.
static func _persona_for(base: Persona, sailor: Sailor, count: int) -> Persona:
	var persona: Persona = base.duplicate() as Persona
	persona.name = sailor.name
	persona.profile = "%s, %s" % [sailor.sail_number, sailor.country]
	# A colour per sailor, spread round the wheel, so eight in a heat are told apart.
	persona.sail_colour = Color.from_hsv(fmod(sailor.id * 0.381966, 1.0), 0.75, 0.95)
	var level: float = lerpf(BEST_LEVEL, LAST_LEVEL, float(sailor.ranking - 1) / maxf(count - 1, 1.0))
	var mean: float = 0.0
	for skill: String in SKILLS:
		mean += float(base.get(skill))
	mean /= SKILLS.size()
	for skill: String in SKILLS:
		persona.set(skill, clampf(level + SHAPE_SHARE * (float(base.get(skill)) - mean), 0.05, 1.0))
	return persona


func sailor(id: int) -> Sailor:
	return sailors[id] if id >= 0 and id < sailors.size() else null


## The ids in ranking order, the favourite first (the first elimination's seeding).
func ids_by_ranking() -> PackedInt32Array:
	var ids: PackedInt32Array = PackedInt32Array()
	for one: Sailor in sailors:
		ids.append(one.id)
	return ids
