extends SceneTree
## The lake's waves measured (PHYSICS_SPEC.md 9.17; PH44): builds Lake Silvaplana's waves
## (LakeWaves) for the map's wind direction of a time of day at several wind speeds, and prints
## along a line down the lake, from the upwind shore: the fetch, the wind along it, the significant
## height Hs and the peak wavelength the model has there, next to what the growth law gives for the
## straight distance from the upwind shore in the lake's mean wind, and the four trains' amplitudes.
## Also how long a build takes. Run it with tools/godot.sh:
##   tools/godot.sh --headless --path Game -s res://dev/lake_waves_table.gd -- [--kts=12,18,24]
##       [--time=14:30] [--through=start|middle] [--step=250] [--law=spm|cem]
## The wind speeds are the lake's mean at 10 m; the map's pattern and lee make it differ from place
## to place, as in the game.
## --check=1 (PHYSICS_SPEC.md 9.18; the report's "Are the waves correct?"): at points along the line,
## the surface the physics floats on measured (Hs = 4 x the standard deviation of its height over
## 20 minutes at that point, the dominant period from the largest train) next to the SPM and CEM laws
## for the point's fetch and wind; then every train's steepness k a, the largest on the lake, at the
## growth law's height and at --scale=<x> (1.5), against the breaking limit pi/7 (H/L = 1/7).

const ENVIRONMENT_PATH: String = "res://maps/silvaplana/environment_silvaplana.tres"
const MAP_CONFIG_PATH: String = "res://maps/silvaplana/map_config.tres"
## The lake scene's start (SilvaplanaSailing.START_LV95) and the lake's middle (run_lake.gd).
const START_LV95: Vector2 = Vector2(2780880.0, 1147510.0)
const MIDDLE: Vector2 = Vector2(349.0, -89.0)


func _initialize() -> void:
	var options: Dictionary[String, String] = _options()
	var environment: EnvironmentConfig = (load(ENVIRONMENT_PATH) as EnvironmentConfig).duplicate()
	var config: LakeWavesConfig = environment.lake_waves.duplicate()
	if options.get("law", "spm") == "cem":
		config.growth_law = LakeWavesConfig.GrowthLaw.CEM
	var map_wind: MapWind = environment.map_wind()
	var time_s: float = _time_s(options.get("time", "14:30"))
	var from_deg: float = map_wind.lake_from_deg(time_s)
	var grid: TerrainGrid = environment.depth_grid()
	var area: Rect2 = Rect2(grid.x0_m, grid.z0_m, (grid.columns - 1) * grid.cell_m, (grid.rows - 1) * grid.cell_m)
	var depth_at: Callable = func(x: float, z: float) -> float: return ShoreCheck.depth_at(grid, Vector3(x, 0.0, z))
	var through: Vector2 = MIDDLE
	if options.get("through", "start") == "start":
		var map_config: MapConfig = load(MAP_CONFIG_PATH)
		var at: Vector3 = map_config.lv95_to_game(START_LV95.x, START_LV95.y, map_config.lake_level_m)
		through = Vector2(at.x, at.z)
	var step_m: float = options.get("step", "250").to_float()
	if options.get("check", "0") == "1":
		_check(environment, config, map_wind, from_deg, area, depth_at, through, options.get("scale", "1.5").to_float(), options.get("kts", "12,18,24"))
		quit(0)
		return
	print("Lake Silvaplana's waves (%s law), the wind from %.1f degrees (the map's lake direction at %s), along the line through %s" % [
		"CEM" if config.growth_law == LakeWavesConfig.GrowthLaw.CEM else "SPM", from_deg, options.get("time", "14:30"),
		"the start spot" if options.get("through", "start") == "start" else "the lake's middle"])
	for kt_text: String in options.get("kts", "12,18,24").split(","):
		var kt: float = kt_text.to_float()
		var wind_ms: float = kt * SimMath.KNOT_MS
		# The lee is fitted to the lake's wind at the pattern's 5 m: 10 m / 5 m to the power 0.11 is 1.079.
		var factor: Callable = environment.map_speed_factor.bind(map_wind, from_deg, kt / 1.079)
		var started_us: int = Time.get_ticks_usec()
		var lake: LakeWaves = LakeWaves.build(config, depth_at, area, from_deg, wind_ms, factor)
		var build_ms: float = (Time.get_ticks_usec() - started_us) / 1000.0
		_print_line(lake, through, step_m, kt, build_ms)
	quit(0)


## The line down the lake through `through`, along the wind, from the upwind shore to the downwind one.
func _print_line(lake: LakeWaves, through: Vector2, step_m: float, kt: float, build_ms: float) -> void:
	var downwind: Vector2 = WaveField.direction_for_bearing(lake.from_deg + 180.0)
	# Walk upwind from the point to the shore, then back down in steps.
	var upwind_end: Vector2 = through
	while lake.map.value_at(lake.map.depth_m, upwind_end.x - downwind.x, upwind_end.y - downwind.y) > 0.0:
		upwind_end -= downwind
	var downwind_end: Vector2 = through
	while lake.map.value_at(lake.map.depth_m, downwind_end.x + downwind.x, downwind_end.y + downwind.y) > 0.0:
		downwind_end += downwind
	var length_m: float = upwind_end.distance_to(downwind_end)
	print("\n%.0f kt at 10 m (the lake's mean): grid %d x %d nodes of %.0f m, built in %.0f ms; the line is %.0f m of water; the 0.5 m train answers the wind in %.0f s" % [
		kt, lake.map.columns, lake.map.rows, lake.map.cell_m, build_ms, length_m, lake.look_response_s])
	print("  from shore | fetch (9 rays) | wind x | depth | model Hs  Lp   | law, straight: Hs   Lp   | trains 8 / 4 / 2 / 1 m (mm) | look 0.5 m")
	var distances: Array[float] = [25.0, 50.0, 100.0]
	var d: float = step_m
	while d < length_m - 10.0:
		distances.append(d)
		d += step_m
	distances.append(length_m - 10.0)
	var amplitudes: PackedFloat64Array = PackedFloat64Array()
	var looks: PackedFloat32Array = lake.look_values(0)
	for distance: float in distances:
		var at: Vector2 = upwind_end + downwind * distance
		var sea: Vector3 = lake.sea_at(at.x, at.y)
		var wind_factor: float = lake.map.value_at(lake.map.wind_factor, at.x, at.y)
		var depth: float = lake.map.value_at(lake.map.depth_m, at.x, at.y)
		var law: Vector2 = lake.height_and_period(lake.wind_10m_ms, distance)
		lake.amplitudes_at(at.x, at.y, amplitudes)
		var look: float = lake.map.value_at(looks, at.x, at.y)
		print("  %7.0f m  | %8.0f m     | %5.2f  | %4.0f m | %5.3f m %4.1f m | %15.3f m %4.1f m | %4.0f %4.0f %4.0f %4.0f | %4.0f" % [
			distance, sea.z, wind_factor, depth, sea.x, _length_m(sea.y), law.x, _length_m(law.y),
			amplitudes[0] * 1000.0, amplitudes[1] * 1000.0, amplitudes[2] * 1000.0, amplitudes[3] * 1000.0, look * 1000.0])


## The check of --check=1 (see the top).
func _check(environment: EnvironmentConfig, config: LakeWavesConfig, map_wind: MapWind, from_deg: float, area: Rect2, depth_at: Callable,
		through: Vector2, scale: float, kts: String) -> void:
	var scaled: LakeWavesConfig = config.duplicate()
	scaled.height_scale = config.height_scale * scale
	for kt_text: String in kts.split(","):
		var kt: float = kt_text.to_float()
		var wind_ms: float = kt * SimMath.KNOT_MS
		var factor: Callable = environment.map_speed_factor.bind(map_wind, from_deg, kt / 1.079)
		var lake: LakeWaves = LakeWaves.build(config, depth_at, area, from_deg, wind_ms, factor)
		var field: LakeWaveField = LakeWaveField.new(lake)
		var downwind: Vector2 = WaveField.direction_for_bearing(lake.from_deg + 180.0)
		var upwind_end: Vector2 = through
		while lake.map.value_at(lake.map.depth_m, upwind_end.x - downwind.x, upwind_end.y - downwind.y) > 0.0:
			upwind_end -= downwind
		print("
%.0f kt (the lake's mean at 10 m), from %.0f degrees; reference depth %.1f m" % [kt, lake.from_deg, lake.reference_depth_m])
		print("| From the upwind shore | 9-ray fetch | Wind there | Surface Hs | Surface period | Model Hs / Tp | SPM law Hs / Tp | CEM law Hs / Tp |")
		print("|---|---|---|---|---|---|---|---|")
		for distance: float in [100.0, 300.0, 600.0, 1000.0, 1500.0, 2000.0]:
			var at: Vector2 = upwind_end + downwind * distance
			if lake.map.value_at(lake.map.depth_m, at.x, at.y) <= 0.0:
				continue
			var sea: Vector3 = lake.sea_at(at.x, at.y)
			var wind_there: float = wind_ms * lake.map.value_at(lake.map.wind_factor, at.x, at.y)
			var spm: Vector2 = Vector2(WindWaves.significant_height_m(wind_there, sea.z), WindWaves.peak_period_s(wind_there, sea.z))
			var cem: Vector2 = Vector2(WindWaves.significant_height_cem_m(wind_there, sea.z), WindWaves.peak_period_cem_s(wind_there, sea.z))
			var measured: Vector2 = _measure(field, at)
			print("| %.0f m | %.0f m | %.1f kt | %.3f m | %.2f s | %.3f m / %.2f s | %.3f m / %.2f s | %.3f m / %.2f s |" % [
				distance, sea.z, wind_there / SimMath.KNOT_MS, measured.x, measured.y, sea.x, sea.y, spm.x, spm.y, cem.x, cem.y])
		var steep_one: PackedFloat64Array = _steepest(lake)
		var lake_scaled: LakeWaves = LakeWaves.build(scaled, depth_at, area, from_deg, wind_ms, factor)
		var steep_scaled: PackedFloat64Array = _steepest(lake_scaled)
		print("Steepest k a of each train anywhere on the lake (breaking: pi/7 = %.3f); x1 / x%.1f:" % [LakeWaves.MAX_STEEPNESS, scale])
		for i: int in lake.band_count:
			print("  %.0f m: %.3f (H/L %.3f) / %.3f (H/L %.3f)" % [lake.wavelength_m[i], steep_one[i], steep_one[i] / PI, steep_scaled[i], steep_scaled[i] / PI])
		print("  all four summed (Gerstner folds at 1): %.3f / %.3f; trains held at the limit at x%.1f: %d" % [
			steep_one[lake.band_count], steep_scaled[lake.band_count], scale, lake_scaled.held_at_breaking])


## Hs (4 x the standard deviation of the surface's height at a point, 20 minutes every 0.1 s) and the
## period of the train with the most energy there (the trains are the spectrum's octaves).
func _measure(field: LakeWaveField, at: Vector2) -> Vector2:
	var sum: float = 0.0
	var sum_squares: float = 0.0
	var n: int = 12000
	for i: int in n:
		var h: float = field.height_at(at.x, at.y, i * 0.1)
		sum += h
		sum_squares += h * h
	var mean: float = sum / n
	var hs: float = 4.0 * sqrt(maxf(sum_squares / n - mean * mean, 0.0))
	field.amplitudes_for(at.x, at.y)
	var biggest: int = 0
	for i: int in field.count:
		if field.amplitude[i] > field.amplitude[biggest]:
			biggest = i
	return Vector2(hs, field.period_s(biggest))


## The largest k a of each train over the lake's nodes, and of their sum (the last value).
func _steepest(lake: LakeWaves) -> PackedFloat64Array:
	var steepest: PackedFloat64Array = PackedFloat64Array()
	steepest.resize(lake.band_count + 1)
	steepest.fill(0.0)
	for node: int in lake.amplitudes.size() / lake.band_count:
		var total: float = 0.0
		for i: int in lake.band_count:
			var ka: float = lake.wave_number[i] * lake.amplitudes[node * lake.band_count + i]
			steepest[i] = maxf(steepest[i], ka)
			total += ka
		steepest[lake.band_count] = maxf(steepest[lake.band_count], total)
	return steepest


## The deep-water length of a wave with this period.
func _length_m(period_s: float) -> float:
	return WindWaves.G * period_s * period_s / TAU


func _time_s(text: String) -> float:
	var parts: PackedStringArray = text.split(":")
	return parts[0].to_float() * 3600.0 + (parts[1].to_float() * 60.0 if parts.size() > 1 else 0.0)


func _options() -> Dictionary[String, String]:
	var options: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			options[arg.substr(2, arg.find("=") - 2)] = arg.get_slice("=", 1)
	return options
