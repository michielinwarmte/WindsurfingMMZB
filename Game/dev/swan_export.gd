extends SceneTree
## Hands Lake Silvaplana to SWAN (TU Delft's spectral wave model; the report
## Documentation/reports/waves/swan_silvaplana.md): writes, on one regular grid over the lake,
## everything SWAN needs and everything its answer is compared with, all from the game's own data:
##   - the water's depth (the game's depth grid, swissBATHY3D at 2 m, the mean of the 2 m samples in
##     each cell),
##   - the map's wind at 10 m relative to the lake's mean (its fixed pattern and the lee along the
##     south-east shore, as the lake's waves use it: EnvironmentConfig.map_speed_factor) and how far
##     the pattern turns it, per wind speed,
##   - the game's own wave model there (LakeWaves: the SPM law at the 9-ray fetch): Hs, Tp, the fetch
##     and the wind along it, per wind speed,
##   - the points of the line through the lake's middle and through the start spot (the same points as
##     lake_waves_table.gd --check=1).
## The grid: x east and y NORTH (SWAN's), in metres from the game's origin (y = -z of the game).
## Run it with tools/godot.sh; tools/map/swan_silvaplana.py does it for you:
##   tools/godot.sh --headless --path Game -s res://dev/swan_export.gd -- --out=<folder>
##       [--kts=12,18,24] [--time=14:30] [--cell=10]
## Files: meta.json, and float32 little-endian arrays row by row from the SOUTH edge (SWAN's first
## row), each row from west to east: depth.f32, and per wind speed wind_factor_<kt>.f32,
## wind_turn.f32, game_hs_<kt>.f32, game_tp_<kt>.f32, game_fetch_<kt>.f32, game_wind_<kt>.f32.

const ENVIRONMENT_PATH: String = "res://maps/silvaplana/environment_silvaplana.tres"
const MAP_CONFIG_PATH: String = "res://maps/silvaplana/map_config.tres"
## The lake scene's start and the lake's middle (as lake_waves_table.gd).
const START_LV95: Vector2 = Vector2(2780880.0, 1147510.0)
const MIDDLE: Vector2 = Vector2(349.0, -89.0)
## The distances from the upwind shore of lake_waves_table.gd --check=1 (m), and more for the plots.
const LINE_DISTANCES_M: Array[float] = [25.0, 50.0, 100.0, 200.0, 300.0, 400.0, 600.0, 800.0, 1000.0, 1250.0, 1500.0, 1750.0, 2000.0, 2250.0, 2500.0, 2750.0, 3000.0]
## The pattern's 5 m speed from the lake's 10 m one (the lee is fitted to the lake's wind at the
## pattern's 5 m: 10 m / 5 m to the power 0.11 is 1.079; as lake_waves_table.gd).
const TEN_TO_FIVE: float = 1.079
## Samples of the 2 m depth grid averaged into one cell, per side.
const DEPTH_SAMPLES: int = 5
## A margin of land round the lake's water, m.
const MARGIN_M: float = 40.0


func _initialize() -> void:
	var options: Dictionary[String, String] = _options()
	var out: String = options.get("out", "")
	if out == "":
		push_error("swan_export: give --out=<folder>")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out)
	var environment: EnvironmentConfig = (load(ENVIRONMENT_PATH) as EnvironmentConfig).duplicate()
	var config: LakeWavesConfig = environment.lake_waves.duplicate()
	var map_config: MapConfig = load(MAP_CONFIG_PATH)
	var map_wind: MapWind = environment.map_wind()
	var time_text: String = options.get("time", "14:30")
	var time_s: float = _time_s(time_text)
	var from_deg: float = map_wind.lake_from_deg(time_s)
	var grid: TerrainGrid = environment.depth_grid()
	var area: Rect2 = Rect2(grid.x0_m, grid.z0_m, (grid.columns - 1) * grid.cell_m, (grid.rows - 1) * grid.cell_m)
	var depth_at: Callable = func(x: float, z: float) -> float: return ShoreCheck.depth_at(grid, Vector3(x, 0.0, z))
	var cell: float = options.get("cell", "10").to_float()
	var kts: PackedStringArray = options.get("kts", "12,18,24").split(",")

	# The lake's extent: the game's own fetch map (cropped to the water with a margin).
	var probe: LakeWaves = LakeWaves.build(config, depth_at, area, from_deg, 9.0, func(_x: float, _z: float) -> float: return 1.0)
	var west: float = probe.map.x0_m - MARGIN_M
	var east: float = probe.map.x0_m + (probe.map.columns - 1) * probe.map.cell_m + MARGIN_M
	var north_z: float = probe.map.z0_m - MARGIN_M
	var south_z: float = probe.map.z0_m + (probe.map.rows - 1) * probe.map.cell_m + MARGIN_M
	var columns: int = int(ceil((east - west) / cell)) + 1
	var rows: int = int(ceil((south_z - north_z) / cell)) + 1
	# SWAN's y is north: its first row is the southern one.
	var south_y: float = -(north_z + (rows - 1) * cell)
	print("swan_export: wind from %.2f degrees (the lake's at %s), grid %d x %d cells of %.0f m, x %.0f..%.0f, y %.0f..%.0f" % [
		from_deg, time_text, columns, rows, cell, west, west + (columns - 1) * cell, south_y, south_y + (rows - 1) * cell])

	var depth: PackedFloat32Array = PackedFloat32Array()
	var turn: PackedFloat32Array = PackedFloat32Array()
	depth.resize(columns * rows)
	turn.resize(columns * rows)
	for row: int in rows:
		for column: int in columns:
			var x: float = west + column * cell
			var z: float = -(south_y + row * cell)
			depth[row * columns + column] = _mean_depth(depth_at, x, z, cell)
			turn[row * columns + column] = map_wind.pattern.turn_deg_at(x, z)
	_write(out.path_join("depth.f32"), depth)
	_write(out.path_join("wind_turn.f32"), turn)

	var meta: Dictionary = {
		"about": "Lake Silvaplana for SWAN, written by Game/dev/swan_export.gd from the game's own data: don't edit",
		"time_of_day": time_text,
		"from_deg": from_deg,
		"columns": columns,
		"rows": rows,
		"cell_m": cell,
		"x0_m": west,
		"y0_m": south_y,
		"order": "float32 little-endian, row by row from the south edge, each row from west to east; y is north (game z = -y)",
		"origin_lv95": [map_config.origin_east_m, map_config.origin_north_m],
		"depth_grid": environment.depth_grid_path,
		"reference_depth_m": probe.reference_depth_m,
		"knot_ms": SimMath.KNOT_MS,
		"kts": [],
		"lines": {},
	}

	for kt_text: String in kts:
		var kt: float = kt_text.to_float()
		var wind_ms: float = kt * SimMath.KNOT_MS
		var factor: Callable = environment.map_speed_factor.bind(map_wind, from_deg, kt / TEN_TO_FIVE)
		var lake: LakeWaves = LakeWaves.build(config, depth_at, area, from_deg, wind_ms, factor)
		var wind_factor: PackedFloat32Array = PackedFloat32Array()
		var hs: PackedFloat32Array = PackedFloat32Array()
		var tp: PackedFloat32Array = PackedFloat32Array()
		var fetch: PackedFloat32Array = PackedFloat32Array()
		var along: PackedFloat32Array = PackedFloat32Array()
		for array: PackedFloat32Array in [wind_factor, hs, tp, fetch, along]:
			array.resize(columns * rows)
		for row: int in rows:
			for column: int in columns:
				var x: float = west + column * cell
				var z: float = -(south_y + row * cell)
				var i: int = row * columns + column
				wind_factor[i] = factor.call(x, z)
				var sea: Vector3 = lake.sea_at(x, z)
				hs[i] = sea.x
				tp[i] = sea.y
				fetch[i] = sea.z
				along[i] = lake.map.value_at(lake.map.wind_factor, x, z)
		var tag: String = "%d" % int(kt)
		_write(out.path_join("wind_factor_%s.f32" % tag), wind_factor)
		_write(out.path_join("game_hs_%s.f32" % tag), hs)
		_write(out.path_join("game_tp_%s.f32" % tag), tp)
		_write(out.path_join("game_fetch_%s.f32" % tag), fetch)
		_write(out.path_join("game_wind_%s.f32" % tag), along)
		(meta["kts"] as Array).append(kt)
		var lines: Dictionary = meta["lines"]
		var start: Vector3 = map_config.lv95_to_game(START_LV95.x, START_LV95.y, map_config.lake_level_m)
		for line_name: String in ["middle", "start"]:
			var through: Vector2 = MIDDLE if line_name == "middle" else Vector2(start.x, start.z)
			lines["%s_%s" % [line_name, tag]] = _line(lake, through, wind_ms)
		print("  %s kt: written (the game's Hs at the start %.3f m)" % [tag, lake.sea_at(start.x, start.z).x])
	var start_spot: Vector3 = map_config.lv95_to_game(START_LV95.x, START_LV95.y, map_config.lake_level_m)
	meta["start_xy"] = [start_spot.x, -start_spot.z]
	meta["middle_xy"] = [MIDDLE.x, -MIDDLE.y]
	var file: FileAccess = FileAccess.open(out.path_join("meta.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(meta, "  "))
	file.close()
	quit(0)


## The points of the line along the wind through `through`, measured from the upwind shore (as
## lake_waves_table.gd): distance, x, y (north), the game's fetch, wind there, Hs and Tp, and the
## SPM and CEM laws at that fetch and wind.
func _line(lake: LakeWaves, through: Vector2, wind_ms: float) -> Array:
	var downwind: Vector2 = WaveField.direction_for_bearing(lake.from_deg + 180.0)
	var upwind_end: Vector2 = through
	while lake.map.value_at(lake.map.depth_m, upwind_end.x - downwind.x, upwind_end.y - downwind.y) > 0.0:
		upwind_end -= downwind
	var points: Array = []
	for distance: float in LINE_DISTANCES_M:
		var at: Vector2 = upwind_end + downwind * distance
		if lake.map.value_at(lake.map.depth_m, at.x, at.y) <= 0.0:
			continue
		var sea: Vector3 = lake.sea_at(at.x, at.y)
		var wind_there: float = wind_ms * lake.map.value_at(lake.map.wind_factor, at.x, at.y)
		points.append({
			"distance_m": distance,
			"x": at.x,
			"y": -at.y,
			"fetch_m": sea.z,
			"wind_along_ms": wind_there,
			"depth_m": lake.map.value_at(lake.map.depth_m, at.x, at.y),
			"game_hs_m": sea.x,
			"game_tp_s": sea.y,
			"spm_hs_m": WindWaves.significant_height_m(wind_there, sea.z),
			"spm_tp_s": WindWaves.peak_period_s(wind_there, sea.z),
			"cem_hs_m": WindWaves.significant_height_cem_m(wind_there, sea.z),
			"cem_tp_s": WindWaves.peak_period_cem_s(wind_there, sea.z),
		})
	return points


## The mean depth of a cell from the 2 m grid (land counts as negative depth, so the shore is where
## the mean crosses 0).
func _mean_depth(depth_at: Callable, x: float, z: float, cell: float) -> float:
	var total: float = 0.0
	var count: int = 0
	var step: float = cell / DEPTH_SAMPLES
	for i: int in DEPTH_SAMPLES:
		for j: int in DEPTH_SAMPLES:
			var d: float = depth_at.call(x + (i - (DEPTH_SAMPLES - 1) / 2.0) * step, z + (j - (DEPTH_SAMPLES - 1) / 2.0) * step)
			if is_nan(d):
				d = -10.0
			total += d
			count += 1
	return total / count


func _write(path: String, values: PackedFloat32Array) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(values.to_byte_array())
	file.close()


func _time_s(text: String) -> float:
	var parts: PackedStringArray = text.split(":")
	return parts[0].to_float() * 3600.0 + (parts[1].to_float() * 60.0 if parts.size() > 1 else 0.0)


func _options() -> Dictionary[String, String]:
	var options: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			options[arg.substr(2, arg.find("=") - 2)] = arg.get_slice("=", 1)
	return options
