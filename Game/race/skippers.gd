class_name Skippers
extends RefCounted
## Makes a skipper from a name, for the tools and the race menu: the name of a character sheet in
## Game/race/skippers/ (allrounder, cautious, gambler, rookie), which becomes a scripted Skipper
## with that SkipperConfig.

const FOLDER: String = "res://race/skippers"
## The trained networks (RACING_PLAN.md, RD4): brain:<name> is Game/race/brains/<name>.json.
const BRAINS_FOLDER: String = "res://race/brains"


## A skipper for a name: a character sheet's name makes a scripted Skipper, "brain:<name>" a
## LearnedSkipper with that trained network; null (with an error) if there is neither.
static func make(skipper_name: String) -> RaceSkipper:
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
## skipper is left out (with an error).
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
	return fleet


## The character sheet of a name; null if there is none.
static func load_config(skipper_name: String) -> SkipperConfig:
	var path: String = FOLDER.path_join(skipper_name + ".tres")
	if skipper_name.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as SkipperConfig


## The names of every character sheet, in order.
static func names() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for file: String in ResourceLoader.list_directory(FOLDER):
		if file.get_extension() == "tres":
			found.append(file.get_basename())
	found.sort()
	return found
