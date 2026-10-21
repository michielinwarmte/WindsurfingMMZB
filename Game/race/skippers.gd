class_name Skippers
extends RefCounted
## Makes a skipper from a name, for the tools and the race menu: the name of a character sheet in
## Game/race/skippers/ (allrounder, cautious, gambler, rookie), which becomes a scripted Skipper
## with that SkipperConfig; "persona:<name>" one of the personas in Game/race/personas/ (F4), a
## scripted Skipper whose sheet is drawn from the persona's skills for each race; "brain:<name>"
## a trained network.

const FOLDER: String = "res://race/skippers"
## The personas (Persona, AI_FLEET_PLAN.md D3): persona:<name> is Game/race/personas/<name>.tres.
const PERSONAS_FOLDER: String = "res://race/personas"
## The trained networks (RACING_PLAN.md, RD4): brain:<name> is Game/race/brains/<name>.json.
const BRAINS_FOLDER: String = "res://race/brains"


## A skipper for a name: a character sheet's name makes a scripted Skipper, "brain:<name>" a
## LearnedSkipper with that trained network; null (with an error) if there is neither.
static func make(skipper_name: String) -> RaceSkipper:
	if skipper_name.begins_with("persona:"):
		var persona: Persona = load_persona(skipper_name.trim_prefix("persona:"))
		if persona == null:
			push_error("No persona called '%s' (they are: %s)." % [skipper_name.trim_prefix("persona:"), ", ".join(persona_names())])
			return null
		var played: Skipper = Skipper.new()
		played.persona = persona
		played.config = persona.to_skipper_config(0)
		return played
	if skipper_name.begins_with("brain:"):
		var brain_name: String = skipper_name.trim_prefix("brain:")
		var brain: NeuralNet = NeuralNet.load_file(BRAINS_FOLDER.path_join(brain_name + ".json"))
		if brain == null:
			return null
		var learned: LearnedSkipper = LearnedSkipper.new()
		learned.brain = brain
		learned.brain_name = brain_name
		return learned
	var config: SkipperConfig = load_config(skipper_name)
	if config == null:
		push_error("No skipper called '%s' (the characters are: %s)." % [skipper_name, ", ".join(names())])
		return null
	var skipper: Skipper = Skipper.new()
	# A copy of its own: skippers sailed side by side on threads would otherwise all read the one
	# loaded resource, which slows each of them down.
	skipper.config = config.duplicate()
	return skipper


## A fleet: one skipper per name, in order (a name may come more than once: a fleet of 16 repeats
## the four characters). A character that sails more than once gets a numbered label on each of its
## boards ("Rookie 1", "Rookie 2"); each skipper has its own copy of its sheet. A name that is no
## skipper is left out (with an error). A night's brains are labelled by their generation ("gen 40",
## "best") and, two or more of them, coloured by it (Generations).
static func make_fleet(skipper_names: PackedStringArray) -> Array[RaceSkipper]:
	var fleet: Array[RaceSkipper] = []
	var seen: Dictionary[String, int] = {}
	for skipper_name: String in skipper_names:
		var skipper: RaceSkipper = make(skipper_name)
		if skipper == null:
			continue
		seen[skipper_name] = seen.get(skipper_name, 0) + 1
		if skipper_names.count(skipper_name) > 1:
			skipper.label = "%s %d" % [skipper.skipper_name(), seen[skipper_name]]
		fleet.append(skipper)
	# A night's generations on one line: their sails from red (the oldest) to green (the newest).
	Generations.colour_fleet(fleet)
	return fleet


## The character sheet of a name; null if there is none.
static func load_config(skipper_name: String) -> SkipperConfig:
	var path: String = FOLDER.path_join(skipper_name + ".tres")
	if skipper_name.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as SkipperConfig


## A persona by its file name; null if there is none.
static func load_persona(persona_name: String) -> Persona:
	var path: String = PERSONAS_FOLDER.path_join(persona_name + ".tres")
	if persona_name.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Persona


## The file names of every persona, in order.
static func persona_names() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for file: String in ResourceLoader.list_directory(PERSONAS_FOLDER):
		if file.get_extension() == "tres":
			found.append(file.get_basename())
	found.sort()
	return found


## The names of every character sheet, in order.
static func names() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for file: String in ResourceLoader.list_directory(FOLDER):
		if file.get_extension() == "tres":
			found.append(file.get_basename())
	found.sort()
	return found
