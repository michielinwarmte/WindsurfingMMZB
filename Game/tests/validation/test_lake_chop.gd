extends GutTest
## The validation on the lake's chop (PHYSICS_SPEC.md 9.18; the research's stage 2): the beam reach
## from the lake scene's start spot off the camping beach, with the player's beginner controller,
## on Lake Silvaplana's full waves (all four trains in the physics, the hull's own view of them)
## against the same run on flat water. Harder to sail is expected, halving the speed is not.
##
## The bounds: an experienced speed sailer's top speed in mild chop is 7 to 14 % below flat water's
## (the report's reference, lake_waves_full.md); a beginner's mean speed loses more. In the map's
## gusty wind the board must keep 80 % of its flat-water speed (measured 94 %), in a steady 18 kt
## 60 % (measured 72 %: the 4 m waves set the hull pitching), and nobody falls in either.

const DT: float = 1.0 / 60.0
const RUN_S: float = 45.0
## The mean speed is taken over the last 15 s, as in tools/lake_matrix.sh.
const WINDOW_FROM_S: float = 30.0
const ENVIRONMENT_PATH: String = "res://maps/silvaplana/environment_silvaplana.tres"
const MAP_CONFIG_PATH: String = "res://maps/silvaplana/map_config.tres"
const START_LV95: Vector2 = Vector2(2780880.0, 1147510.0)
const TIME_OF_DAY_S: float = 14.5 * 3600.0


class Run:
	var speed_kt: float = 0.0
	var fell: bool = false
	var nan: bool = false
	var pitch_min_deg: float = INF
	var pitch_max_deg: float = -INF
	var lake: bool = false


func _sail(waves: bool, steady_kt: float) -> Run:
	for action: String in ["steer_left", "steer_right", "tack"]:
		Input.action_release(action)
	var environment: EnvironmentConfig = (load(ENVIRONMENT_PATH) as EnvironmentConfig).duplicate()
	environment.start_hour = TIME_OF_DAY_S / 3600.0
	var sim: WindsurferSim = WindsurferSim.create_for(environment)
	var field: MapWindField = sim.wind as MapWindField
	field.set_time_of_day(TIME_OF_DAY_S)
	var from_deg: float = environment.map_wind().lake_from_deg(TIME_OF_DAY_S)
	if steady_kt > 0.0:
		var steady: WindConfig = field.config.duplicate() as WindConfig
		steady.speed_kt = steady_kt
		steady.from_bearing_deg = rad_to_deg(field.current_from_bearing_rad)
		steady.gusts_enabled = false
		steady.shifts_enabled = false
		sim.wind_config = steady
		sim.wind = WindField.new(steady)
	sim.wave_set_config = sim.wave_set_config.duplicate(true)
	sim.wave_set_config.place_waves = true
	sim.set_waves(waves)
	var map_config: MapConfig = load(MAP_CONFIG_PATH)
	var start: Vector3 = map_config.lv95_to_game(START_LV95.x, START_LV95.y, map_config.lake_level_m)
	# The beam reach of the lake matrix: heading 180 in a wind from 270, turned to the lake's wind.
	sim.reset(Vector3(start.x, 0.0, start.z), deg_to_rad(fposmod(180.0 + from_deg - 270.0, 360.0)))
	var controller: PlayerController = PlayerController.new()
	controller.set_sail(sim.sail, sim.sailor_config, sim.air_density_kg_m3)
	var controls: SimControls = SimControls.new()
	var run: Run = Run.new()
	run.lake = sim.hull_water is LakeWaveField
	var sum: float = 0.0
	var count: int = 0
	for i: int in int(RUN_S / DT):
		controller.update(sim.telemetry, controls, DT)
		sim.step(DT, controls)
		var t: Telemetry = sim.telemetry
		if is_nan(t.speed_ms) or is_nan(t.position.y):
			run.nan = true
			break
		if sim.sailor_state == WindsurferSim.SailorState.FALLEN:
			run.fell = true
		if t.time_s >= WINDOW_FROM_S:
			sum += t.speed_kt
			count += 1
			run.pitch_min_deg = minf(run.pitch_min_deg, t.pitch_deg)
			run.pitch_max_deg = maxf(run.pitch_max_deg, t.pitch_deg)
	run.speed_kt = sum / maxf(count, 1)
	return run


func _flat_and_chop(steady_kt: float, keep: float) -> void:
	var flat: Run = _sail(false, steady_kt)
	var chop: Run = _sail(true, steady_kt)
	var wind: String = ("a steady %.0f kt" % steady_kt) if steady_kt > 0.0 else "the map's wind at 14:30"
	gut.p("%s: flat %.1f kt, the lake's chop %.1f kt (%.0f %%), pitch %.1f to %.1f deg" % [
		wind, flat.speed_kt, chop.speed_kt, 100.0 * chop.speed_kt / flat.speed_kt, chop.pitch_min_deg, chop.pitch_max_deg])
	assert_true(chop.lake, "the run was on the lake's own waves, with the hull's own view")
	assert_false(chop.nan, "no NaN")
	assert_false(flat.fell, "no fall on flat water in %s" % wind)
	assert_false(chop.fell, "no fall on the lake's chop in %s" % wind)
	assert_gt(chop.speed_kt, keep * flat.speed_kt, "the board keeps %.0f %% of its flat-water speed in %s" % [100.0 * keep, wind])


func test_beam_reach_on_the_lakes_chop_in_the_maps_wind() -> void:
	_flat_and_chop(-1.0, 0.8)


func test_beam_reach_on_the_lakes_chop_in_a_steady_18_kt() -> void:
	_flat_and_chop(18.0, 0.6)
