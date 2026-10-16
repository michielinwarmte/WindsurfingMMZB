extends SceneTree
## Writes the wind analyser's gusts on the satellite photos' 10 m grid, so tools/map/gust_shapes.py
## can measure the model exactly as it measures the photos (MAP_SILVAPLANA_PLAN.md, W3;
## MALOJA_WIND_RESEARCH.md, "Gusts seen from space"). For 40 moments around 12:28, five minutes
## apart (the photos' time of day): |wind| / |wind without the gusts| - 1 on the water, NaN elsewhere.
## Three versions: lanes only, fronts only, and both (the model as it is).
##
## Run from the repo root (about 10 minutes for all three):
##   tools/godot.sh --headless --path Game -s res://maps/silvaplana/dev/export_gusts.gd -- <folder> [setting=value ...]
##   python tools/map/gust_shapes.py --model <folder>
## Settings of WindGusts can be changed for a try, for example front_share=0.7; and
## variants=both only writes that version.

const CONFIG_PATH: String = "res://maps/silvaplana/map_config.tres"
const PATTERN_PATH: String = "res://maps/silvaplana/wind/maloja_pattern.json"
const DAY_PATH: String = "res://maps/silvaplana/wind/maloja_day.tres"
const GUSTS_PATH: String = "res://maps/silvaplana/wind/maloja_gusts.tres"
const SHORE_GRID_PATH: String = "res://maps/silvaplana/terrain/shore_heights.json"
## The photos' grid (tools/map/satellite_wind.py): LV95 cell centres, 10 m, from the north-west.
const WEST_M: float = 2778400.0
const NORTH_M: float = 1148700.0
const CELL_M: float = 10.0
const COLUMNS: int = 420
const ROWS: int = 450
const MOMENTS: int = 40
const PHOTO_TIME_S: float = 12.0 * 3600.0 + 28.0 * 60.0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Give the folder to write to: ... -- <folder> [setting=value ...]")
		quit(1)
		return
	var folder: String = args[0]
	DirAccess.make_dir_recursive_absolute(folder)
	var config: MapConfig = load(CONFIG_PATH)
	var wind: MapWind = MapWind.load_from(PATTERN_PATH, DAY_PATH, config, GUSTS_PATH)
	var variants: PackedStringArray = PackedStringArray(["lanes", "fronts", "both"])
	for arg: String in args.slice(1):
		var parts: PackedStringArray = arg.split("=")
		if parts[0] == "variants":
			variants = parts[1].split(",")
		else:
			wind.gusts.set(parts[0], float(parts[1]))
			print("Changed for this try: %s = %s" % [parts[0], parts[1]])
	var water: Array[Vector3] = []
	var cells: PackedInt32Array = PackedInt32Array()
	var shore: TerrainGrid = TerrainGrid.load_from(SHORE_GRID_PATH)
	for row: int in ROWS:
		for column: int in COLUMNS:
			var point: Vector3 = config.lv95_to_game(WEST_M + (column + 0.5) * CELL_M, NORTH_M - (row + 0.5) * CELL_M, config.lake_level_m)
			if shore.contains(point.x, point.z) and shore.height_at(point.x, point.z) < -0.3:
				water.append(point)
				cells.append(row * COLUMNS + column)
	var front_share: float = wind.gusts.front_share
	for variant: String in variants:
		wind.gusts.front_share = {"lanes": 0.0, "fronts": 1.0, "both": front_share}[variant]
		var data: PackedFloat32Array = PackedFloat32Array()
		for m: int in MOMENTS:
			var now: WindMoment = wind.moment(PHOTO_TIME_S + (m - MOMENTS / 2.0) * 300.0)
			var calm: WindMoment = wind.moment(now.time_of_day_s)
			calm.spread_ms = 0.0
			var field: PackedFloat32Array = PackedFloat32Array()
			field.resize(ROWS * COLUMNS)
			field.fill(NAN)
			for i: int in water.size():
				field[cells[i]] = wind.velocity_in(now, water[i]).length() / wind.velocity_in(calm, water[i]).length() - 1.0
			data.append_array(field)
		var file: FileAccess = FileAccess.open(folder.path_join("model_%s.bin" % variant), FileAccess.WRITE)
		file.store_buffer(data.to_byte_array())
		file.close()
		print("Wrote %s: %d moments, %d water cells" % [variant, MOMENTS, water.size()])
	quit()
