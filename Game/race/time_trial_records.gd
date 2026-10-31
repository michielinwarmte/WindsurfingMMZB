class_name TimeTrialRecords
extends RefCounted
## The time trial's records (ROADMAP GP4, GD5): a course sailed alone against your own best, so
## practice shows as a number. The best time and its splits are kept per water, course and wind
## in a file in the user's folder (user://time_trials.cfg, a ConfigFile with one section per key,
## "water|course|wind"); every finish is compared with the best, and a faster one replaces it.
## The wind in the key is the settings' wind on the open water (whole knots) and the time of day
## on the lake, whose wind is the hour's (RaceRunner makes the key).

const PATH: String = "user://time_trials.cfg"

var path: String = PATH
var _file: ConfigFile = ConfigFile.new()


## The key of a record: the water ("open" or "lake"), the course's name and the wind.
static func make_key(water: String, course_name: String, wind: String) -> String:
	return "%s|%s|%s" % [water, course_name, wind]


## Loads the records from the file; no file is a fresh start.
func load_from(file_path: String = PATH) -> void:
	path = file_path
	_file = ConfigFile.new()
	if file_path != "" and FileAccess.file_exists(file_path):
		_file.load(file_path)


func save() -> void:
	if path != "":
		_file.save(path)


## The best time for a key, seconds; -1 without one.
func best_s(key: String) -> float:
	return float(_file.get_value(key, "best_s", -1.0))


## The race time at every step of the best run (the start, the marks, the finish).
func best_splits(key: String) -> PackedFloat32Array:
	return _file.get_value(key, "splits", PackedFloat32Array())


func best_date(key: String) -> String:
	return str(_file.get_value(key, "date", ""))


## A finish: kept and saved when it beats the best, or is the first. True for a new best.
func remember(key: String, time_s: float, splits: PackedFloat32Array, date: String = "") -> bool:
	var best: float = best_s(key)
	if best >= 0.0 and time_s >= best:
		return false
	_file.set_value(key, "best_s", time_s)
	_file.set_value(key, "splits", splits.duplicate())
	_file.set_value(key, "date", date if date != "" else Time.get_date_string_from_system())
	save()
	return true


## The gap to the best at the step just completed: "+2.3 s" behind the best run there, "-1.0 s"
## ahead of it; "" without a best for that step.
static func gap_text(splits: PackedFloat32Array, best: PackedFloat32Array) -> String:
	var done: int = splits.size()
	if done == 0 or best.size() < done:
		return ""
	return "%+.1f s" % (splits[done - 1] - best[done - 1])
