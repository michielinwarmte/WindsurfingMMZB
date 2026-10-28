extends GutTest
## A place brings its own air, water and wind (PHYSICS_REQUESTS_FROM_MAP.md R1 to R3):
## WindsurferSim.create_for() builds the simulation with an EnvironmentConfig, the open water's
## create_default() stays as it was, and the thin air of a mountain lake takes 20 % off the
## sail's force in the same wind.

const ENVIRONMENT_PATH: String = "res://maps/silvaplana/environment_silvaplana.tres"


func test_the_open_water_is_unchanged() -> void:
	var sim: WindsurferSim = WindsurferSim.create_default()
	assert_almost_eq(sim.air_density_kg_m3, 1.225, 1e-9, "sea-level air")
	assert_almost_eq(sim.water_config.density_kg_m3, 1025.0, 1e-9, "sea water")
	assert_false(sim.wind is MapWindField, "one wind for the whole world")
	assert_almost_eq(sim.wind_config.speed_kt, 18.0, 1e-9)
	assert_almost_eq(sim.wind_config.from_bearing_deg, 270.0, 1e-9)
	assert_true(sim.water is FlatWater, "flat water unless asked")
	assert_true(WindsurferSim.create_default(true).water is WaveField, "the default waves when asked")


func test_an_empty_environment_is_the_open_water() -> void:
	var sim: WindsurferSim = WindsurferSim.create_for(EnvironmentConfig.new())
	var reference: WindsurferSim = WindsurferSim.create_default()
	assert_almost_eq(sim.air_density_kg_m3, reference.air_density_kg_m3, 1e-9)
	assert_eq(sim.water_config, reference.water_config, "the same water_default.tres")
	assert_eq(sim.wind_config, reference.wind_config, "the same wind_default.tres")
	assert_false(sim.wind is MapWindField)


func test_silvaplana_brings_thin_air_fresh_water_and_its_own_wind() -> void:
	var environment: EnvironmentConfig = load(ENVIRONMENT_PATH)
	var sim: WindsurferSim = WindsurferSim.create_for(environment)
	assert_almost_eq(sim.air_density_kg_m3, 0.98, 1e-9, "Segl-Maria's Maloja afternoons (R2)")
	assert_almost_eq(sim.water_config.density_kg_m3, 1000.0, 1e-9, "a lake: fresh water (R3)")
	assert_true(sim.wind is MapWindField, "the map's wind (W5)")
	assert_almost_eq(sim.wind_config.from_bearing_deg, 222.0, 1e-6, "the lake's WindConfig: the waves line up with it")
	var field: MapWindField = sim.wind as MapWindField
	assert_almost_eq(field.time_of_day_s(), 14.5 * 3600.0, 1e-6, "from 14:30")
	# The models were built with the lake's water, not just handed it afterwards.
	assert_eq(sim.buoyancy.water, sim.water_config, "the buoyancy floats in fresh water")


func test_thin_air_takes_a_fifth_off_the_sail_force() -> void:
	# Two boards in the same wind, at rest, sheeted in the same: the sail's lift and drag scale
	# with the air's density, 0.98 / 1.225 = 0.80. One very short step, so that neither board nor
	# sailor has started to move (the apparent wind is the same for both).
	var thin_air: EnvironmentConfig = EnvironmentConfig.new()
	thin_air.air_density_kg_m3 = 0.98
	var sea_level: WindsurferSim = WindsurferSim.create_default()
	var mountain: WindsurferSim = WindsurferSim.create_for(thin_air)
	var controls: SimControls = SimControls.new()
	controls.sheet = 0.6
	for sim: WindsurferSim in [sea_level, mountain]:
		sim.reset(Vector3.ZERO, deg_to_rad(180.0))
		sim.step(1e-4, controls)
	assert_gt(sea_level.telemetry.sail_lift_n, 50.0, "the sail pulls")
	# The thinner air also presses less on the sail, so it twists open a little less (PH28):
	# the lift falls by the density times the change of the twist's share.
	var aws_ms: float = sea_level.sail.aws_ms  # at the sail's own height, below the 10 m wind
	var q_sea_pa: float = 0.5 * 1.225 * aws_ms * aws_ms
	var alpha: float = sea_level.sail.alpha_rad
	var twist_change: float = mountain.sail.lift_coefficient(alpha, q_sea_pa * 0.8) / sea_level.sail.lift_coefficient(alpha, q_sea_pa)
	assert_almost_eq(mountain.telemetry.sail_lift_n / sea_level.telemetry.sail_lift_n, 0.8 * twist_change, 0.01, "lift")
	assert_almost_eq(mountain.telemetry.sail_drag_n / sea_level.telemetry.sail_drag_n, 0.8, 0.01, "drag")
	# The sailor's windage uses the same density, but the sailor's body starts to move at once
	# (the legs take up the sail's pull), so its apparent wind is not the same on the two boards.
	assert_lt(mountain.windage_force_world.length(), sea_level.windage_force_world.length(), "less windage, too")


func test_the_pilots_expect_the_thin_air() -> void:
	var windsurfer: WindsurferNode = (load("res://windsurfer/windsurfer.tscn") as PackedScene).instantiate()
	windsurfer.environment = load(ENVIRONMENT_PATH)
	add_child_autofree(windsurfer)
	assert_almost_eq(windsurfer.sim.air_density_kg_m3, 0.98, 1e-9)
	assert_true(windsurfer.sim.wind is MapWindField)
	assert_almost_eq(windsurfer.autopilot.air_density_kg_m3, 0.98, 1e-9, "the test autopilot")
	assert_almost_eq(windsurfer.controller.auto_sheet_pilot.air_density_kg_m3, 0.98, 1e-9, "the player's auto-sheet")
	windsurfer.controller.reset_controls(SimControls.new())
	assert_almost_eq(windsurfer.controller.auto_sheet_pilot.air_density_kg_m3, 0.98, 1e-9, "also after a reset")
