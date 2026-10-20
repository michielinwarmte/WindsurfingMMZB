extends SceneTree
## Times the sea's queries (WaveField) and a whole board's physics tick on the waves, so the
## cost of the sea is on record before and after a change to it (AI_FLEET_PLAN.md, D2: "The
## sea query, measured"). Use tools/sea_bench.sh.
##
## 1. The queries on 20 000 random points of the default sea, microseconds each:
##    - height_at alone;
##    - the height, the normal and the velocity as the hull asked them until F1 (three
##      queries, each with its own fixed-point solve for the rest point);
##    - one solve, then the three answers at that rest point (the _rest functions);
##    - one displacement_at, which is one sum over the waves.
##    It also checks that the two ways give the same height.
## 2. A board's physics per tick: WindsurferSim with the default waves on a beam reach with
##    the autopilot (as tools/simulate.sh beam_reach sets it up), 600 ticks of 1/60 s after
##    600 ticks to get it sailing; the same on flat water, so the sea's share shows.
##
## Arguments after "--": [--points=20000] [--ticks=600]

const DT: float = 1.0 / 60.0


func _initialize() -> void:
	var options: Dictionary[String, String] = _read_user_args()
	var n: int = options.get("points", "20000").to_int()
	var ticks: int = options.get("ticks", "600").to_int()
	_time_the_queries(n)
	var waves_ms: float = _time_a_board(true, ticks)
	var flat_ms: float = _time_a_board(false, ticks)
	print("a board's physics per tick (%d ticks of 1/60 s on a beam reach, after %d to get going): %.3f ms with the waves, %.3f ms on flat water, the sea %.3f ms" % [
		ticks, ticks, waves_ms, flat_ms, waves_ms - flat_ms])
	quit(0)


func _default_sea() -> WaveField:
	var waves: WaveSetConfig = load("res://config/waves_default.tres")
	var water: WaterConfig = load("res://config/water_default.tres")
	return WaveField.new(waves, water, 270.0)


func _random_points(n: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1
	for i: int in n:
		points.append(Vector2(rng.randf_range(-50.0, 50.0), rng.randf_range(-50.0, 50.0)))
	return points


func _time_the_queries(n: int) -> void:
	var field: WaveField = _default_sea()
	var points: PackedVector2Array = _random_points(n)
	var t: float = 12.3
	var sink: float = 0.0  # every answer is added here, so nothing can be skipped

	var t0: int = Time.get_ticks_usec()
	for p: Vector2 in points:
		sink += field.height_at(p.x, p.y, t)
	var height_us: float = float(Time.get_ticks_usec() - t0) / n

	t0 = Time.get_ticks_usec()
	for p: Vector2 in points:
		sink += field.height_at(p.x, p.y, t)
		sink += field.normal_at(p.x, p.y, t).y
		sink += field.velocity_at(p.x, p.y, t).x
	var three_us: float = float(Time.get_ticks_usec() - t0) / n

	t0 = Time.get_ticks_usec()
	for p: Vector2 in points:
		var rest: Vector2 = field.rest_point_at(p.x, p.y, t)
		sink += field.displacement_at(rest.x, rest.y, t).y
		sink += field.normal_at_rest(rest.x, rest.y, t).y
		sink += field.velocity_at_rest(rest.x, rest.y, t).x
	var once_us: float = float(Time.get_ticks_usec() - t0) / n

	t0 = Time.get_ticks_usec()
	for p: Vector2 in points:
		sink += field.displacement_at(p.x, p.y, t).y
	var displacement_us: float = float(Time.get_ticks_usec() - t0) / n

	# Do the two ways agree? The same rest point gives the same answers.
	var worst_mm: float = 0.0
	for i: int in mini(200, n):
		var p: Vector2 = points[i]
		var rest: Vector2 = field.rest_point_at(p.x, p.y, t)
		var h1: float = field.height_at(p.x, p.y, t)
		var h2: float = field.displacement_at(rest.x, rest.y, t).y + field.base_height_m
		worst_mm = maxf(worst_mm, absf(h1 - h2) * 1000.0)

	print("sea queries, microseconds each (%d waves, %d points): height_at %.2f; height+normal+velocity as the hull asked them %.2f; one solve then the three _rest answers %.2f; one displacement_at (one wave sum) %.2f; worst height difference between the two ways %.3f mm (sink %.1f)" % [
		field.count, n, height_us, three_us, once_us, displacement_us, worst_mm, sink])


## Milliseconds of physics per tick of one board, the way tools/simulate.sh beam_reach sails.
func _time_a_board(with_waves: bool, ticks: int) -> float:
	var scenario: SimScenario = load("res://dev/scenarios/beam_reach.gd").new()
	var sim: WindsurferSim = WindsurferSim.create_default(with_waves)
	sim.wind_config = sim.wind_config.duplicate()
	sim.wind_config.speed_kt = scenario.wind_kt
	sim.wind = WindField.new(sim.wind_config)
	scenario.pilot.sail = sim.sail
	scenario.pilot.sailor = sim.sailor_config
	sim.set_waves(with_waves)
	sim.reset(Vector3.ZERO, deg_to_rad(scenario.start_heading_deg))
	scenario.setup(sim)
	for i: int in ticks:
		scenario.update(sim, DT)
		sim.step(DT, scenario.controls)
	var physics_us: int = 0
	for i: int in ticks:
		scenario.update(sim, DT)
		var t0: int = Time.get_ticks_usec()
		sim.step(DT, scenario.controls)
		physics_us += Time.get_ticks_usec() - t0
	print("  %s: %.2f m/s, planing ratio %.2f after %.0f s" % [
		"waves" if with_waves else "flat", sim.telemetry.speed_ms, sim.telemetry.planing_ratio, sim.time_s])
	return float(physics_us) / 1000.0 / float(ticks)


func _read_user_args() -> Dictionary[String, String]:
	var options: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
			options[parts[0]] = parts[1]
	return options
