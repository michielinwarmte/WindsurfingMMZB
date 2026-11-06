extends SceneTree
## How close the boards of a lake race came to the shore (Max, 6 November 2026: the AI races every
## iQFOiL course on Silvaplana without going onto the shore): for every track a race wrote
## (Game/dev/run_race.gd's CSV files, a row every half second), the shallowest water under the board,
## when and where, and how many half seconds it spent in water under 2 m deep. Use with
## tools/lake_courses_check.sh's output:
##   tools/godot.sh --headless --path Game -s res://dev/track_depths.gd -- --dir=<.sim_output/lake_iq/<run>>
## (every csv_* folder in it).

const ENVIRONMENT_PATH: String = "res://maps/silvaplana/environment_silvaplana.tres"
const SHALLOW_M: float = 2.0


func _initialize() -> void:
	var folder: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--dir="):
			folder = arg.get_slice("=", 1)
	var environment: EnvironmentConfig = load(ENVIRONMENT_PATH)
	var grid: TerrainGrid = environment.depth_grid()
	if grid == null or folder == "" or not DirAccess.dir_exists_absolute(folder):
		print("Usage: --dir=<a folder of tools/lake_courses_check.sh> (and the lake's depth grid)")
		quit(2)
		return
	var shallowest_all: float = INF
	for run: String in DirAccess.get_directories_at(folder):
		if not run.begins_with("csv_"):
			continue
		for file: String in DirAccess.get_files_at(folder.path_join(run)):
			if file.get_extension() != "csv":
				continue
			var line: String = _track_line(grid, folder.path_join(run).path_join(file))
			print("%-10s %s" % [run.trim_prefix("csv_"), line])
			shallowest_all = minf(shallowest_all, line.get_slice(" ", 1).to_float())
	print("The shallowest water under any board: %.1f m" % shallowest_all)
	quit(0)


## One track's line: "<board> <shallowest m> at <time> (x, z), <n> half seconds under 2 m".
func _track_line(grid: TerrainGrid, path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	file.get_line()  # the header
	var shallowest_m: float = INF
	var at_s: float = 0.0
	var where: Vector2 = Vector2.ZERO
	var shallow_rows: int = 0
	var doing: String = ""
	while not file.eof_reached():
		var parts: PackedStringArray = file.get_csv_line()
		if parts.size() < 3:
			continue
		var x: float = parts[1].to_float()
		var z: float = parts[2].to_float()
		var depth_m: float = -grid.height_at(x, z) if grid.contains(x, z) else -INF
		if depth_m < SHALLOW_M:
			shallow_rows += 1
		if depth_m < shallowest_m:
			shallowest_m = depth_m
			at_s = parts[0].to_float()
			where = Vector2(x, z)
			doing = parts[6] if parts.size() > 6 else ""
	return "%s %.1f m at %.0f s (%.0f, %.0f), %d half seconds under %.0f m; doing: %s" % [
		path.get_file().get_basename(), shallowest_m, at_s, where.x, where.y, shallow_rows, SHALLOW_M, doing]
