extends SceneTree
## Records the lake's water surface at a few points over 20 minutes (PH44; the report
## Documentation/reports/waves/swan_silvaplana.md, "What the eye sees"), for the statistics of the
## individual waves (tools/map/wave_statistics.py): how high each wave is, how high its crest, the
## largest against Hs, the steepness.
##
## The surface is the lake's own view of LakeWaveField (no hull footprint): the four trains the
## physics floats on, which is also the shape the picture draws near the camera (gerstner.gdshaderinc,
## lake_wave_surface(); test_lake_waves.gd checks the two agree). With --hull=1 it also records the
## hull's view of a planing board on a beam reach (its wet bottom 1.1 m long and 0.55 m wide, the
## waves crossing it), which is what the board's buoyancy and planing strips feel.
##
## The lake is built as lake_waves_table.gd builds it: the map's wind direction of a time of day,
## the lake's mean wind at 10 m, the map's pattern and lee along the fetch.
##   tools/godot.sh --headless --path Game -s res://dev/lake_wave_record.gd -- --out=<folder>
##       [--kts=12,18,24] [--time=14:30] [--minutes=20] [--step=0.05] [--hull=1]
## Files: <folder>/record.json (the points, the trains' amplitudes there, the model's Hs and Tp) and
## one float32 little-endian file of heights (m) per wind, point and view.

const ENVIRONMENT_PATH: String = "res://maps/silvaplana/environment_silvaplana.tres"
const MAP_CONFIG_PATH: String = "res://maps/silvaplana/map_config.tres"
const START_LV95: Vector2 = Vector2(2780880.0, 1147510.0)
const MIDDLE: Vector2 = Vector2(349.0, -89.0)
## The points along the line through the lake's middle, from the upwind shore (m): those of
## lake_waves_full.md's tables where the board sails.
const MIDDLE_DISTANCES_M: Array[float] = [600.0, 1000.0, 1500.0, 2000.0]
## A planing board's wet bottom (lake_waves_full.md: about 1.1 m long and 0.55 m wide).
const PLANING_LENGTH_M: float = 1.1
const PLANING_BEAM_M: float = 0.55
const TEN_TO_FIVE: float = 1.079


func _initialize() -> void:
	var options: Dictionary[String, String] = _options()
	var out: String = options.get("out", "")
	if out == "":
		push_error("lake_wave_record: give --out=<folder>")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out)
	var environment: EnvironmentConfig = (load(ENVIRONMENT_PATH) as EnvironmentConfig).duplicate()
	var config: LakeWavesConfig = environment.lake_waves.duplicate()
	var map_config: MapConfig = load(MAP_CONFIG_PATH)
	var map_wind: MapWind = environment.map_wind()
	var time_text: String = options.get("time", "14:30")
	var from_deg: float = map_wind.lake_from_deg(_time_s(time_text))
	var grid: TerrainGrid = environment.depth_grid()
	var area: Rect2 = Rect2(grid.x0_m, grid.z0_m, (grid.columns - 1) * grid.cell_m, (grid.rows - 1) * grid.cell_m)
	var depth_at: Callable = func(x: float, z: float) -> float: return ShoreCheck.depth_at(grid, Vector3(x, 0.0, z))
	var step_s: float = options.get("step", "0.05").to_float()
	var samples: int = int(round(options.get("minutes", "20").to_float() * 60.0 / step_s))
	var with_hull: bool = options.get("hull", "1") == "1"
	var start: Vector3 = map_config.lv95_to_game(START_LV95.x, START_LV95.y, map_config.lake_level_m)
	var record: Dictionary = {"about": "written by Game/dev/lake_wave_record.gd", "from_deg": from_deg, "time_of_day": time_text,
		"step_s": step_s, "samples": samples, "views": ["lake"] + (["hull_beam_reach"] if with_hull else []), "winds": []}
	for kt_text: String in options.get("kts", "12,18,24").split(","):
		var kt: float = kt_text.to_float()
		var factor: Callable = environment.map_speed_factor.bind(map_wind, from_deg, kt / TEN_TO_FIVE)
		var lake: LakeWaves = LakeWaves.build(config, depth_at, area, from_deg, kt * SimMath.KNOT_MS, factor)
		var points: Array = [{"name": "start", "x": start.x, "z": start.z}]
		var downwind: Vector2 = WaveField.direction_for_bearing(from_deg + 180.0)
		var upwind_end: Vector2 = MIDDLE
		while lake.map.value_at(lake.map.depth_m, upwind_end.x - downwind.x, upwind_end.y - downwind.y) > 0.0:
			upwind_end -= downwind
		for distance: float in MIDDLE_DISTANCES_M:
			var at: Vector2 = upwind_end + downwind * distance
			points.append({"name": "middle_%d" % int(distance), "x": at.x, "z": at.y})
		var wind: Dictionary = {"kt": kt, "points": []}
		for point: Dictionary in points:
			wind["points"].append(_record_point(lake, point, kt, step_s, samples, with_hull, downwind, out))
		record["winds"].append(wind)
		print("%.0f kt: recorded %d points" % [kt, points.size()])
	var file: FileAccess = FileAccess.open(out.path_join("record.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(record, "  "))
	file.close()
	quit(0)


## One point's surface over time, in the lake's own view and (with_hull) the hull's view of a board
## on a beam reach (its bow across the wind, so the waves cross its beam).
func _record_point(lake: LakeWaves, point: Dictionary, kt: float, step_s: float, samples: int, with_hull: bool,
		downwind: Vector2, out: String) -> Dictionary:
	var x: float = point["x"]
	var z: float = point["z"]
	var sea: Vector3 = lake.sea_at(x, z)
	var amplitudes: PackedFloat64Array = PackedFloat64Array()
	lake.amplitudes_at(x, z, amplitudes)
	var info: Dictionary = {"name": point["name"], "x": x, "z": z, "model_hs_m": sea.x, "model_tp_s": sea.y, "fetch_m": sea.z,
		"amplitudes_m": Array(amplitudes), "wavelengths_m": Array(lake.wavelength_m), "physics_trains": lake.physics_count,
		"files": {}}
	var views: Array[String] = ["lake"]
	if with_hull:
		views.append("hull_beam_reach")
	for view: String in views:
		var field: LakeWaveField = LakeWaveField.new(lake)
		if view == "hull_beam_reach":
			# The bow at right angles to the wind: the waves run across the board.
			field.set_footprint(PLANING_LENGTH_M, PLANING_BEAM_M, Vector2(-downwind.y, downwind.x))
		var heights: PackedFloat32Array = PackedFloat32Array()
		heights.resize(samples)
		for i: int in samples:
			heights[i] = field.height_at(x, z, i * step_s)
		var name: String = "h_%d_%s_%s.f32" % [int(kt), point["name"], view]
		var file: FileAccess = FileAccess.open(out.path_join(name), FileAccess.WRITE)
		file.store_buffer(heights.to_byte_array())
		file.close()
		info["files"][view] = name
	return info


func _time_s(text: String) -> float:
	var parts: PackedStringArray = text.split(":")
	return parts[0].to_float() * 3600.0 + (parts[1].to_float() * 60.0 if parts.size() > 1 else 0.0)


func _options() -> Dictionary[String, String]:
	var options: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			options[arg.substr(2, arg.find("=") - 2)] = arg.get_slice("=", 1)
	return options
