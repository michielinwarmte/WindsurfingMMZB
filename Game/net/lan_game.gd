class_name LanGame
extends RefCounted
## What the host of a LAN game chose (LAN multiplayer, Documentation/reports/multiplayer/PLAN.md, D2):
## the map, free sailing or a race, the race's course, laps, countdown and AI fleet, the lake's time
## of day, and the host's wind and waves. The host fills it in the lobby; the start message carries
## it to the guest, whose game then sails exactly these (D11: the guest's own settings file is not
## changed, see apply_conditions()).

enum Map { OPEN_WATER, LAKE }

const OPEN_WATER_SCENE: String = "res://main.tscn"
const LAKE_SCENE: String = "res://maps/silvaplana/sail_silvaplana.tscn"
## The courses each map knows (main.gd's and sail_silvaplana.gd's _course_named()).
const OPEN_WATER_COURSES: PackedStringArray = ["t1_loop"]
const LAKE_COURSES: PackedStringArray = ["t2_slalom"]
## The lake's usual start time (sail_silvaplana.gd), seconds since midnight: 14:30.
const LAKE_DEFAULT_TIME_S: float = 14.5 * 3600.0
## The settings' sections that make the conditions: the host's travel, the guest's stay its own.
const CONDITION_SECTIONS: PackedStringArray = ["wind", "waves"]

var map: Map = Map.OPEN_WATER
## A race (with the AI fleet), or free sailing together.
var race: bool = true
var course_name: String = "t1_loop"
## The AI fleet: the characters or personas on the line (RaceSetup.skippers); empty for none.
var skippers: PackedStringArray = RaceSetup.DEFAULT_SKIPPERS
var laps: int = 1
var prestart_s: float = RaceSetup.DEFAULT_PRESTART_S
var level_spread: float = RaceSetup.LEVEL_CLOSE
var rules: bool = true
var shadows: bool = true
## The lake's time of day at the start, seconds since midnight.
var lake_time_s: float = LAKE_DEFAULT_TIME_S
## The host's wind and waves: its settings file's [wind] and [waves] sections (ConfigFile text),
## and its start heading.
var conditions_text: String = ""
## Who plays, the host first (filled when the host presses Start).
var players: Array[LanPlayer] = []


## The scene both PCs load.
func scene_path() -> String:
	return LAKE_SCENE if map == Map.LAKE else OPEN_WATER_SCENE


## The courses the chosen map knows.
func courses() -> PackedStringArray:
	return LAKE_COURSES if map == Map.LAKE else OPEN_WATER_COURSES


## The map's name for the lobby.
func map_text() -> String:
	return "Lake Silvaplana" if map == Map.LAKE else "Open water"


## One line for the lobby: "Race on Open water: t1_loop, 1 lap, 3 AI boards" or "Free sailing on ...".
func summary() -> String:
	if not race:
		return "Free sailing on %s" % map_text()
	var fleet: String = "no AI boards" if skippers.is_empty() else "%d AI board%s" % [skippers.size(), "" if skippers.size() == 1 else "s"]
	return "Race on %s: %s, %d lap%s, %d s countdown, %s" % [map_text(), course_name, laps, "" if laps == 1 else "s", roundi(prestart_s), fleet]


## The race for RaceSetup.pending (null for free sailing). The AI's gear follows the personas, the
## dice are new each start, as in a race from the menu.
func race_setup() -> RaceSetup:
	if not race:
		return null
	var setup: RaceSetup = RaceSetup.race(course_name, skippers, laps, prestart_s)
	setup.level_spread = level_spread
	setup.rules = rules
	setup.shadows = shadows
	return setup


## The host's settings' conditions as text (the [wind] and [waves] sections, and the start heading).
static func conditions_of(values: SettingsValues) -> String:
	var all: ConfigFile = ConfigFile.new()
	values.write_to(all)
	var kept: ConfigFile = ConfigFile.new()
	for section: String in CONDITION_SECTIONS:
		for key: String in all.get_section_keys(section):
			kept.set_value(section, key, all.get_value(section, key))
	kept.set_value("sailing", "start_heading_deg", values.start_heading_deg)
	return kept.encode_to_text()


## Sails the host's conditions with these settings (the guest's, for the session): only the wind,
## the waves and the start heading change.
func apply_conditions(values: SettingsValues) -> void:
	if conditions_text == "":
		return
	var config: ConfigFile = ConfigFile.new()
	if config.parse(conditions_text) != OK:
		push_warning("The host's conditions could not be read.")
		return
	values.read_from(config)


## The player in a slot, or null.
func player_in(slot: int) -> LanPlayer:
	for player: LanPlayer in players:
		if player.slot == slot:
			return player
	return null


func to_dict() -> Dictionary:
	var people: Array = []
	for player: LanPlayer in players:
		people.append(player.to_dict())
	return {"map": int(map), "race": race, "course": course_name, "skippers": skippers, "laps": laps, "prestart_s": prestart_s,
		"level_spread": level_spread, "rules": rules, "shadows": shadows, "lake_time_s": lake_time_s,
		"conditions": conditions_text, "players": people}


static func from_dict(data: Dictionary) -> LanGame:
	var game: LanGame = LanGame.new()
	game.map = clampi(int(data.get("map", 0)), 0, Map.size() - 1) as Map
	game.race = bool(data.get("race", true))
	game.course_name = String(data.get("course", game.courses()[0]))
	game.skippers = PackedStringArray(data.get("skippers", PackedStringArray()))
	game.laps = maxi(int(data.get("laps", 1)), 1)
	game.prestart_s = maxf(float(data.get("prestart_s", RaceSetup.DEFAULT_PRESTART_S)), 5.0)
	game.level_spread = clampf(float(data.get("level_spread", RaceSetup.LEVEL_CLOSE)), 0.0, 1.0)
	game.rules = bool(data.get("rules", true))
	game.shadows = bool(data.get("shadows", true))
	game.lake_time_s = float(data.get("lake_time_s", LAKE_DEFAULT_TIME_S))
	game.conditions_text = String(data.get("conditions", ""))
	for entry: Variant in data.get("players", []):
		if entry is Dictionary:
			game.players.append(LanPlayer.from_dict(entry))
	return game
