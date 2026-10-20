class_name Skippers
extends RefCounted
## Makes a skipper from a name, for the tools and the race menu: the name of a character sheet in
## Game/race/skippers/ (allrounder, cautious, gambler, rookie), which becomes a scripted Skipper
## with that SkipperConfig.

const FOLDER: String = "res://race/skippers"


## A skipper for a name; null (with an error) if there is no such character.
static func make(skipper_name: String) -> Skipper:
	# ---- The learned skippers (RACING_PLAN.md, 9C) go here after the merge: "brain:<name>" makes
	# ---- a learned skipper from Game/race/brains/<name>.json, with the same setup() and update().
	if skipper_name.begins_with("brain:"):
		push_error("Learned skippers (%s) are not in this build yet." % skipper_name)
		return null
	var config: SkipperConfig = load_config(skipper_name)
	if config == null:
		push_error("No skipper called '%s' (the characters are: %s)." % [skipper_name, ", ".join(names())])
		return null
	var skipper: Skipper = Skipper.new()
	# A copy of its own: skippers sailed side by side on threads would otherwise all read the one
	# loaded resource, which slows each of them down.
	skipper.config = config.duplicate()
	return skipper


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
