class_name NativeSeaBench
extends RefCounted
## The test of 13 November 2026: Lake Silvaplana's wave query (LakeWaveField.sample_at) in GDScript
## against the same query in C++ (NativeLakeWaves, native/src/; built by tools/native.sh).
##
## It asks both the questions a board's hull asks: 48 points over the hull's bottom, a board sailing
## at 8 m/s from the lake's start spot, 180 substeps a second, each point warm-started from its own
## last answer, as WindsurferSim does. Twice: the lake's own view and the hull's view (its footprint,
## LakeWaveField.set_footprint). It prints:
##   1. whether every answer (the height, the normal, the water's velocity, the rest point) is the
##      same to the last bit, and if not the largest difference;
##   2. the time per query: GDScript; C++ asked point by point from GDScript (the hull's code still
##      GDScript); C++ asked for all 48 points of a substep in one call (the hull in C++ too).
##
## The editor engine: tools/native.sh test (dev/native_sea_bench_main.gd). The release engine, as the
## game runs: wsim_console.exe --headless -- --native_sea_bench=<seconds> (DevCapture; the release
## engine does not run -s scripts), with the library next to the exe.

const POINTS_ALONG: int = 8
const POINTS_ACROSS: int = 6
const HULL_LENGTH_M: float = 2.4
const HULL_BEAM_M: float = 0.65
const SPEED_MS: float = 8.0
const SUBSTEP_S: float = 1.0 / 180.0
const LAKE_ENVIRONMENT_PATH: String = "res://maps/silvaplana/environment_silvaplana.tres"
const LAKE_START: Vector2 = Vector2(380.0, -910.0)
const HEADING_DEG: float = 132.0
const TRAINS: int = 2  # the trains the physics floats on in the game


## Runs the test over `seconds` of sailing; true when every answer is the same to the last bit.
static func run(seconds: float = 10.0) -> bool:
	if not ClassDB.class_exists("NativeLakeWaves"):
		print("NativeLakeWaves is not there: build it first with tools/native.sh build.")
		return false
	var substeps: int = roundi(seconds / SUBSTEP_S)
	var fields: Dictionary[String, LakeWaveField] = _lake_fields()
	print("Lake Silvaplana's waves, the physics on its %d longest trains; %d points, %d substeps (%.0f s), %d queries per view (%s engine)" % [
		TRAINS, POINTS_ALONG * POINTS_ACROSS, substeps, seconds, POINTS_ALONG * POINTS_ACROSS * substeps,
		"the editor" if OS.has_feature("editor") else "the release"])
	var all_same: bool = true
	for view: String in fields:
		all_same = _compare(view, fields[view], substeps) and all_same
	print("RESULT: %s" % ("the same to the last bit" if all_same else "NOT the same (see above)"))
	return all_same


## The lake's own view and a hull's view, as the game builds them on the lake.
static func _lake_fields() -> Dictionary[String, LakeWaveField]:
	var environment: EnvironmentConfig = (load(LAKE_ENVIRONMENT_PATH) as EnvironmentConfig).duplicate()
	environment.lake_waves = environment.lake_waves.duplicate()
	environment.lake_waves.physics_trains = TRAINS
	var sim: WindsurferSim = WindsurferSim.create_for(environment, false, true)
	sim.wave_set_config = sim.wave_set_config.duplicate(true)
	sim.wave_set_config.place_waves = true
	sim.set_waves(true)
	sim.reset(Vector3(LAKE_START.x, 0.0, LAKE_START.y), deg_to_rad(HEADING_DEG))
	var lake_view: LakeWaveField = sim.water as LakeWaveField
	var hull_view: LakeWaveField = LakeWaveField.new(lake_view.lake)
	hull_view.base_height_m = lake_view.base_height_m
	var forward: Vector2 = WaveField.direction_for_bearing(HEADING_DEG)
	hull_view.set_footprint(HULL_LENGTH_M, HULL_BEAM_M, forward)
	return {"the lake's own view": lake_view, "the hull's view (footprint)": hull_view}


## Every substep's points, x and z after each other, as the hull moves along its heading.
static func _hull_points(substeps: int) -> Array[PackedFloat64Array]:
	var forward: Vector2 = WaveField.direction_for_bearing(HEADING_DEG)
	var across: Vector2 = Vector2(-forward.y, forward.x)
	var steps: Array[PackedFloat64Array] = []
	for step: int in substeps:
		var centre: Vector2 = LAKE_START + forward * SPEED_MS * SUBSTEP_S * step
		var xz: PackedFloat64Array = PackedFloat64Array()
		for a: int in POINTS_ALONG:
			for b: int in POINTS_ACROSS:
				var along_m: float = (float(a) / (POINTS_ALONG - 1) - 0.5) * HULL_LENGTH_M
				var across_m: float = (float(b) / (POINTS_ACROSS - 1) - 0.5) * HULL_BEAM_M
				var p: Vector2 = centre + forward * along_m + across * across_m
				xz.append(p.x)
				xz.append(p.y)
		steps.append(xz)
	return steps


static func _compare(view: String, field: LakeWaveField, substeps: int) -> bool:
	var points: int = POINTS_ALONG * POINTS_ACROSS
	var steps: Array[PackedFloat64Array] = _hull_points(substeps)
	var start_s: float = 30.0
	var native: Object = ClassDB.instantiate("NativeLakeWaves")
	native.setup_from(field, LakeWaves.MAX_STEEPNESS)

	# 1. The answers, every substep's records kept.
	var gd_samples: PackedFloat64Array = WaterSurface.new_samples(points)
	var gd_all: PackedFloat64Array = PackedFloat64Array()
	native.new_samples(points)
	var native_all: PackedFloat64Array = PackedFloat64Array()
	for step: int in substeps:
		var t: float = start_s + step * SUBSTEP_S
		var xz: PackedFloat64Array = steps[step]
		for i: int in points:
			field.sample_at(xz[2 * i], xz[2 * i + 1], t, gd_samples, i)
			native.sample_at(xz[2 * i], xz[2 * i + 1], t, i)
		gd_all.append_array(gd_samples)
		native_all.append_array(native.samples())
	var differing: int = 0
	var worst: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0, 0.0])  # rest point, height, normal, velocity
	for n: int in gd_all.size():
		if gd_all[n] != native_all[n]:
			differing += 1
			var field_index: int = n % WaterSurface.SAMPLE_SIZE
			var group: int = 0 if field_index < WaterSurface.SAMPLE_HEIGHT_M else (1 if field_index == WaterSurface.SAMPLE_HEIGHT_M else (2 if field_index < WaterSurface.SAMPLE_VELOCITY_MS else 3))
			worst[group] = maxf(worst[group], absf(gd_all[n] - native_all[n]))
	print("%s: %d of %d numbers differ%s" % [view, differing, gd_all.size(),
		"" if differing == 0 else " (largest: rest point %.3g m, height %.3g m, normal %.3g, velocity %.3g m/s)" % [worst[0], worst[1], worst[2], worst[3]]])

	# 2. The time, the same questions again without keeping the records.
	gd_samples = WaterSurface.new_samples(points)
	var t0: int = Time.get_ticks_usec()
	for step: int in substeps:
		var t: float = start_s + step * SUBSTEP_S
		var xz: PackedFloat64Array = steps[step]
		for i: int in points:
			field.sample_at(xz[2 * i], xz[2 * i + 1], t, gd_samples, i)
	var gd_us: float = float(Time.get_ticks_usec() - t0) / (substeps * points)
	native.new_samples(points)
	t0 = Time.get_ticks_usec()
	for step: int in substeps:
		var t: float = start_s + step * SUBSTEP_S
		var xz: PackedFloat64Array = steps[step]
		for i: int in points:
			native.sample_at(xz[2 * i], xz[2 * i + 1], t, i)
	var native_us: float = float(Time.get_ticks_usec() - t0) / (substeps * points)
	native.new_samples(points)
	t0 = Time.get_ticks_usec()
	for step: int in substeps:
		native.sample_points(steps[step], start_s + step * SUBSTEP_S)
	var batch_us: float = float(Time.get_ticks_usec() - t0) / (substeps * points)
	print("  a query: GDScript %.2f us; C++ point by point %.2f us (%.1f times faster); C++ a substep at once %.3f us (%.0f times faster)" % [
		gd_us, native_us, gd_us / native_us, batch_us, gd_us / batch_us])
	return differing == 0
