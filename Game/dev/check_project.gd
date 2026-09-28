extends SceneTree
## Loads every script, scene and resource in the project and reports the ones that fail.
## A quick "does everything still parse and load?" check. Run it with tools/check.sh.
##
## Shaders are only compiled when something is drawn with them, so this check cannot see
## shader errors. tools/screenshot.sh renders the game and reports those.

const CHECKED_EXTENSIONS: Array[String] = ["gd", "tscn", "scn", "tres", "res"]
const SKIPPED_FOLDERS: Array[String] = ["res://addons"]


func _initialize() -> void:
	var paths: Array[String] = []
	_collect_files("res://", paths)
	# Loading the script that is running right now again would crash Godot, so skip it.
	paths.erase((get_script() as Script).resource_path)

	var failed: Array[String] = []
	for path: String in paths:
		if not _loads_cleanly(path):
			failed.append(path)

	print("Checked %d files: %d failed." % [paths.size(), failed.size()])
	for path: String in failed:
		print("  FAILED: ", path)
	quit(1 if failed.size() > 0 else 0)


func _loads_cleanly(path: String) -> bool:
	var resource: Resource = ResourceLoader.load(path)
	if resource == null:
		return false
	if resource is Script:
		# A script with a parse error still loads, but cannot be instantiated.
		var script: Script = resource
		return script.can_instantiate() or script.is_abstract()
	if resource is PackedScene:
		var scene: PackedScene = resource
		return scene.can_instantiate()
	return true


func _collect_files(folder: String, paths: Array[String]) -> void:
	for sub_folder: String in DirAccess.get_directories_at(folder):
		var sub_path: String = folder.path_join(sub_folder)
		if sub_folder.begins_with(".") or sub_path in SKIPPED_FOLDERS:
			continue
		_collect_files(sub_path, paths)
	for file: String in DirAccess.get_files_at(folder):
		if file.get_extension() in CHECKED_EXTENSIONS:
			paths.append(folder.path_join(file))
