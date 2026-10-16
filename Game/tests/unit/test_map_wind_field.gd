extends GutTest
## The map's wind in the simulation (PHYSICS_SPEC.md 8.10, MAP_SILVAPLANA_PLAN.md W5): MapWindField
## answers what MapWind says, with the height profile from the pattern's 5 m; its direction is the
## lake's mean; it never gives NaN, even far off the map; its clock runs with the simulation; and
## the day's cycle changes the wind.

const ENVIRONMENT_PATH: String = "res://maps/silvaplana/environment_silvaplana.tres"
const AFTERNOON_S: float = 14.5 * 3600.0
## A spot on the lake, out from the camping beach (game metres).
const ON_THE_LAKE: Vector3 = Vector3(300.0, 2.0, -600.0)

var _environment: EnvironmentConfig
var _map_wind: MapWind


func before_all() -> void:
	_environment = load(ENVIRONMENT_PATH)
	_map_wind = _environment.map_wind()


func _field(time_of_day_s: float = AFTERNOON_S) -> MapWindField:
	return MapWindField.new(_map_wind, _environment.wind_or_default(), time_of_day_s, _environment.map_wind_height_m)


func test_the_map_wind_loads() -> void:
	assert_not_null(_map_wind, "the Silvaplana environment brings the map's wind")
	assert_not_null(_map_wind.gusts, "with the gusts")
	assert_not_null(_map_wind.lee, "and the lee")
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_environment.map_wind_pattern_path))
	assert_almost_eq(_environment.map_wind_height_m, float(info["height_above_ground_m"]), 1e-6, "the pattern's own height")


func test_the_velocity_is_the_maps_with_the_height_profile() -> void:
	var field: MapWindField = _field()
	var at_pattern_height: Vector3 = Vector3(ON_THE_LAKE.x, 5.0, ON_THE_LAKE.z)
	var expected: Vector3 = _map_wind.velocity_at(at_pattern_height, AFTERNOON_S)
	assert_gt(expected.length(), 3.0, "a Maloja afternoon")
	assert_almost_eq(field.velocity_at(at_pattern_height), expected, Vector3.ONE * 1e-4, "at 5 m: the map's own number")
	# At the sail, 2 m up: less, by the power law from 5 m (exponent 0.11 over open water).
	var shear: float = _environment.wind_or_default().shear_exponent
	var at_sail: Vector3 = _field().velocity_at(ON_THE_LAKE)
	assert_almost_eq(at_sail, expected * pow(2.0 / 5.0, shear), Vector3.ONE * 1e-4, "at 2 m")
	assert_almost_eq(at_sail.length() / expected.length(), 0.904, 0.002, "about 10 % less at the sail")
	assert_eq(at_sail.y, 0.0, "horizontal")


func test_the_mean_is_the_lakes_and_the_ten_metre_speed_follows_the_profile() -> void:
	var field: MapWindField = _field()
	assert_almost_eq(rad_to_deg(field.current_from_bearing_rad), _map_wind.lake_from_deg(AFTERNOON_S), 1e-4, "the lake's mean direction")
	assert_almost_eq(rad_to_deg(field.current_from_bearing_rad), 222.0, 1.0, "along the lake (W1)")
	assert_almost_eq(field.from_direction(), SimMath.dir_from_bearing(deg_to_rad(_map_wind.lake_from_deg(AFTERNOON_S))), Vector3.ONE * 1e-6)
	var lake_ms: float = _map_wind.day.lake_speed_ms(AFTERNOON_S)
	assert_almost_eq(field.speed_at_height(5.0), lake_ms, 1e-5, "the day's mean at the pattern's height")
	assert_almost_eq(field.speed_at_height(10.0), lake_ms * pow(2.0, 0.11), 1e-5, "and at 10 m")
	assert_almost_eq(field.current_speed_ms, field.speed_at_height(10.0), 1e-6, "the forecast-style number is at 10 m")


func test_no_nan_far_off_the_map() -> void:
	var field: MapWindField = _field()
	var lake_mean: Vector3 = -field.from_direction() * field.speed_at_height(5.0)
	var far_away: Array[Vector3] = [Vector3(1e6, 5.0, -1e6), Vector3(-3e7, 5.0, 2e5), Vector3(0.0, 5.0, 1e9),
		Vector3(INF, 5.0, 0.0), Vector3(NAN, 5.0, NAN)]
	for point: Vector3 in far_away:
		var velocity: Vector3 = field.velocity_at(point)
		assert_true(velocity.is_finite(), "a number at %s" % str(point))
		assert_almost_eq(velocity, lake_mean, Vector3.ONE * 1e-4, "outside the map: the lake's mean at %s" % str(point))
	# Near and under the water, too.
	for height_m: float in [0.0, -2.0, 0.05, 50.0]:
		assert_true(field.velocity_at(Vector3(ON_THE_LAKE.x, height_m, ON_THE_LAKE.z)).is_finite(), "at %.2f m" % height_m)


func test_step_moves_the_time_of_day_on() -> void:
	var field: MapWindField = _field()
	for i: int in 600:
		field.step(1.0 / 60.0)
	assert_almost_eq(field.time_of_day_s(), AFTERNOON_S + 10.0, 1e-3, "real time: 10 s of steps is 10 s of the day")
	assert_almost_eq(field.time_s, 10.0, 1e-3)
	field.clock.rate = 60.0
	field.step(1.0)
	assert_almost_eq(field.time_of_day_s(), AFTERNOON_S + 70.0, 1e-3, "a faster clock for tests")
	assert_eq(field.time_of_day_text(), "14:31:10")
	field.set_time_of_day(11.0 * 3600.0)
	assert_eq(field.time_of_day_text(), "11:00:00")


func test_the_wind_moves_with_the_time() -> void:
	# The gusts roll down the lake and the pulses come and go: a minute later the wind at the same
	# spot is different.
	var field: MapWindField = _field()
	var before: Vector3 = field.velocity_at(ON_THE_LAKE)
	for i: int in 60 * 60:
		field.step(1.0 / 60.0)
	assert_gt((field.velocity_at(ON_THE_LAKE) - before).length(), 0.05, "a minute later")


func test_the_day_cycle_changes_the_speed() -> void:
	var morning: MapWindField = _field(11.0 * 3600.0)
	var afternoon: MapWindField = _field(AFTERNOON_S)
	var morning_kt: float = morning.speed_at_height(10.0) / SimMath.KNOT_MS
	var afternoon_kt: float = afternoon.speed_at_height(10.0) / SimMath.KNOT_MS
	assert_between(morning_kt, 8.0, 13.0, "11:00, the Maloja is building (station 8.7 kt times 1.3 at 5 m)")
	assert_between(afternoon_kt, 16.0, 20.0, "14:30, the strongest of the day")
	assert_lt(morning.velocity_at(ON_THE_LAKE).length(), afternoon.velocity_at(ON_THE_LAKE).length())


func test_points_close_together_in_one_step_share_the_maps_answer() -> void:
	var field: MapWindField = _field()
	var at_mast: Vector3 = field.velocity_at(ON_THE_LAKE)
	var two_metres_on: Vector3 = ON_THE_LAKE + Vector3(2.0, 0.0, 0.0)
	assert_almost_eq(field.velocity_at(two_metres_on), at_mast, Vector3.ONE * 1e-6, "the sail and the sailor: one question")
	var direct: Vector3 = _map_wind.velocity_at(Vector3(two_metres_on.x, 5.0, two_metres_on.z), AFTERNOON_S) * pow(2.0 / 5.0, 0.11)
	assert_almost_eq(at_mast, direct, Vector3.ONE * 0.01 * direct.length(), "within 1 % of asking again")
	var far: Vector3 = ON_THE_LAKE + Vector3(400.0, 0.0, 0.0)
	assert_almost_eq(field.velocity_at(far), _map_wind.velocity_at(Vector3(far.x, 5.0, far.z), AFTERNOON_S) * pow(2.0 / 5.0, 0.11),
		Vector3.ONE * 1e-4, "further away: asked again")


func test_the_settings_do_not_change_the_maps_wind() -> void:
	var field: MapWindField = _field()
	var before: Vector3 = field.velocity_at(ON_THE_LAKE)
	field.set_wind(deg_to_rad(90.0), 20.0)
	assert_almost_eq(field.velocity_at(ON_THE_LAKE), before, Vector3.ONE * 1e-6)
	assert_almost_eq(rad_to_deg(field.current_from_bearing_rad), _map_wind.lake_from_deg(AFTERNOON_S), 1e-4)


func test_a_board_sails_in_the_maps_wind() -> void:
	var sim: WindsurferSim = WindsurferSim.create_for(_environment)
	assert_true(sim.wind is MapWindField)
	var start: Vector3 = Vector3(380.0, 0.0, -910.0)  # the lake scene's start, off the camping beach
	sim.reset(start, deg_to_rad(132.0))
	var pilot: Autopilot = Autopilot.new()
	pilot.target_twa_deg = 90.0
	pilot.sail = sim.sail
	pilot.sailor = sim.sailor_config
	pilot.air_density_kg_m3 = sim.air_density_kg_m3
	var controls: SimControls = SimControls.new()
	var sail_kt_low: float = INF
	var sail_kt_high: float = 0.0
	for i: int in 60 * 30:
		pilot.update(sim.telemetry, controls, 1.0 / 60.0)
		sim.step(1.0 / 60.0, controls)
		if i > 60 * 5:
			sail_kt_low = minf(sail_kt_low, sim.telemetry.tws_at_sail_kt)
			sail_kt_high = maxf(sail_kt_high, sim.telemetry.tws_at_sail_kt)
	var t: Telemetry = sim.telemetry
	assert_false(is_nan(t.speed_ms) or is_nan(t.position.x), "no NaN")
	assert_eq(sim.sailor_state, WindsurferSim.SailorState.SAILING, "still sailing after 30 s")
	assert_gt(t.speed_kt, 8.0, "sailing on a beam reach")
	assert_almost_eq(t.wind_from_bearing_deg, _map_wind.lake_from_deg(AFTERNOON_S + 30.0), 0.01, "the HUD's 'from' is the lake's mean")
	assert_almost_eq(t.tws_10m_kt, sim.wind.speed_at_height(10.0) / SimMath.KNOT_MS, 1e-4, "the HUD's 10 m wind is the lake's mean")
	assert_gt(sail_kt_high - sail_kt_low, 0.3, "the wind at the sail changes as the board sails through the gusts")
