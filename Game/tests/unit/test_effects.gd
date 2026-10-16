extends GutTest
## The environment and effects of plan Phase 7 (and the force view of Phase 6): the spray
## grows with speed and planing, a hard landing gives one splash, the streamer follows the
## apparent wind, the force arrows point along their force with a length in proportion, the
## wake starts only when the board moves, the wind flag points downwind, and the water's
## looks load onto the one water shader.

const SEA_LOOK: String = "res://world/sea_water.tres"
const LAKE_LOOK: String = "res://maps/silvaplana/lake_water.tres"
const WATER_SHADER: String = "res://world/water.gdshader"

var board_config: BoardConfig = preload("res://config/board_default.tres")


# --- Spray ---------------------------------------------------------------------------------

func test_no_spray_at_rest() -> void:
	assert_eq(WindsurferEffects.spray_intensity(0.0, 0.0), 0.0, "Nothing when the board stands still")
	assert_eq(WindsurferEffects.spray_intensity(0.0, 1.0, 2.0), 0.0, "Nothing at rest, whatever the hull says")
	assert_eq(WindsurferEffects.spray_intensity(1.0, 0.0), 0.0, "Nothing at a walking pace")


func test_spray_grows_with_speed() -> void:
	var slow: float = WindsurferEffects.spray_intensity(4.0, 0.5)
	var medium: float = WindsurferEffects.spray_intensity(8.0, 0.5)
	var fast: float = WindsurferEffects.spray_intensity(11.0, 0.5)
	assert_gt(slow, 0.0, "Some spray at 4 m/s")
	assert_gt(medium, slow, "More at 8 m/s than at 4")
	assert_gt(fast, medium, "More at 11 m/s than at 8")
	assert_lte(WindsurferEffects.spray_intensity(30.0, 1.0, 3.0), 1.0, "Never more than full")


func test_spray_grows_with_planing() -> void:
	var displacing: float = WindsurferEffects.spray_intensity(8.0, 0.0)
	var half: float = WindsurferEffects.spray_intensity(8.0, 0.5)
	var planing: float = WindsurferEffects.spray_intensity(8.0, 1.0)
	assert_gt(half, displacing, "Half planing throws more than displacing")
	assert_gt(planing, half, "Fully planing throws the most")
	assert_gt(WindsurferEffects.spray_intensity(8.0, 1.0, 1.6), planing, "The nose meeting chop throws more")


func test_most_spray_comes_off_the_leeward_rail() -> void:
	# Wind from starboard (AWA > 0): port is to leeward.
	var shares: Vector2 = WindsurferEffects.spray_side_shares(40.0, 0.0)
	assert_gt(shares.x, shares.y, "Port (leeward) throws more")
	assert_almost_eq(shares.x + shares.y, 1.0, 1e-6, "The shares add up to the whole")
	var other_tack: Vector2 = WindsurferEffects.spray_side_shares(-40.0, 0.0)
	assert_gt(other_tack.y, other_tack.x, "On the other tack starboard is to leeward")


func test_spray_root_is_at_the_front_of_the_wet_bottom() -> void:
	# The wet part runs from 0.1 m to 1.1 m forward of the transom: the spray root is 1.2 m
	# from the tail, which is at +z = length / 2.
	var port: Vector3 = WindsurferEffects.spray_root_local(board_config, 0.1, 1.1, -1.0)
	assert_almost_eq(port.z, 0.5 * board_config.length_m - 1.2, 1e-6, "1.2 m forward of the transom")
	assert_lt(port.x, 0.0, "The port rail is at -x")
	assert_lt(absf(port.x), 0.5 * board_config.width_m + 1e-6, "At the edge of the bottom")
	assert_gt(absf(port.x), 0.3 * board_config.width_m, "Not in the middle")


# --- Splash --------------------------------------------------------------------------------

func test_splash_fires_once_on_a_landing() -> void:
	var trigger: SplashTrigger = SplashTrigger.new()
	var weight_n: float = 900.0
	var dt: float = 1.0 / 60.0
	for i: int in 30:
		assert_false(trigger.update(100.0, weight_n, dt), "Airborne: no splash")
	assert_true(trigger.update(3.0 * weight_n, weight_n, dt), "The hull lands: a splash")
	assert_gt(trigger.last_strength, 2.0, "A hard landing")
	assert_false(trigger.update(3.0 * weight_n, weight_n, dt), "Not again on the next frame")
	assert_false(trigger.update(3.0 * weight_n, weight_n, dt), "Nor the one after")


func test_no_splash_from_ordinary_waves() -> void:
	# The support swings by half the weight once a second, as riding over swell does.
	var trigger: SplashTrigger = SplashTrigger.new()
	var weight_n: float = 900.0
	var dt: float = 1.0 / 60.0
	var splashes: int = 0
	for i: int in 600:
		var support: float = weight_n * (1.0 + 0.5 * sin(TAU * float(i) * dt))
		if trigger.update(support, weight_n, dt):
			splashes += 1
	assert_eq(splashes, 0, "Waves alone throw no splash")


# --- Wind visuals --------------------------------------------------------------------------

func test_streamer_follows_the_apparent_wind() -> void:
	# Heading North (-Z), wind from dead ahead: the streamer blows aft, to the South (+Z).
	assert_true(Telltale.direction_for(0.0, 0.0).is_equal_approx(Vector3(0.0, 0.0, 1.0)), "Head to wind: blows aft")
	# Wind from starboard (AWA +90) on a board heading North: it blows to port, the West (-X).
	assert_true(Telltale.direction_for(90.0, 0.0).is_equal_approx(Vector3(-1.0, 0.0, 0.0)), "Wind from starboard: blows to port")
	assert_true(Telltale.direction_for(-90.0, 0.0).is_equal_approx(Vector3(1.0, 0.0, 0.0)), "Wind from port: blows to starboard")
	# Heading East (+X) with the wind 45 degrees off the starboard bow: it comes from the
	# South-East (bearing 135), so it blows to the North-West.
	var expected: Vector3 = Vector3(-1.0, 0.0, -1.0).normalized()
	assert_true(Telltale.direction_for(45.0, 90.0).is_equal_approx(expected), "Wind from 135 blows toward 315")


func test_streamer_droops_in_a_calm_and_streams_in_a_breeze() -> void:
	assert_gt(Telltale.droop_rad(0.0), deg_to_rad(60.0), "Hangs down in a calm")
	assert_lt(Telltale.droop_rad(20.0), deg_to_rad(10.0), "Flies almost flat in 20 knots")
	var points: PackedVector3Array = Telltale.ribbon_points(Vector3.RIGHT, 20.0, 0.0)
	var span: Vector3 = points[points.size() - 1] - points[0]
	assert_gt(span.x, 0.6 * Telltale.LENGTH_M, "It streams out along the wind")


func test_wind_flag_points_downwind() -> void:
	var flag: WindFlag = WindFlag.new()
	add_child_autofree(flag)
	var downwind: Vector3 = Vector3(1.0, 0.0, 1.0).normalized()
	flag.place(Vector3(3.0, 0.1, -2.0), downwind, 8.0)
	assert_true(flag.cloth_direction().is_equal_approx(downwind), "The cloth points the way the wind blows")
	assert_true(flag.global_position.is_equal_approx(Vector3(3.0, 0.1, -2.0)), "On its spot on the water")


# --- Force view ----------------------------------------------------------------------------

func test_force_arrow_has_the_force_direction_and_length() -> void:
	var arrows: ForceArrows = ForceArrows.new()
	add_child_autofree(arrows)
	var foot: Vector3 = Vector3(1.0, 2.0, 3.0)
	var force: Vector3 = Vector3(300.0, 400.0, 0.0)  # 500 N
	arrows.set_force("sail", foot, force)
	var drawn: Vector3 = arrows.arrow_tip("sail") - foot
	assert_almost_eq(drawn.length(), force.length() * ForceArrows.METRES_PER_NEWTON, 1e-4, "1 m per 500 N")
	assert_almost_eq(drawn.normalized().dot(force.normalized()), 1.0, 1e-5, "Along the force")
	# Twice the force, twice the arrow.
	arrows.set_force("fin", foot, force * 2.0)
	assert_almost_eq((arrows.arrow_tip("fin") - foot).length(), 2.0 * drawn.length(), 1e-4, "In proportion")
	arrows.set_force("weight", foot, Vector3(0.0, -735.0, 0.0))
	assert_almost_eq((arrows.arrow_tip("weight") - foot).normalized().y, -1.0, 1e-5, "Weight points down")


func test_force_view_draws_the_simulation_forces() -> void:
	var windsurfer: WindsurferNode = (load("res://windsurfer/windsurfer.tscn") as PackedScene).instantiate() as WindsurferNode
	add_child_autofree(windsurfer)
	var effects: WindsurferEffects = windsurfer.get_node("Effects") as WindsurferEffects
	effects.set_forces_visible(true)
	# A few ticks, so the models have worked out their forces.
	for i: int in 3:
		windsurfer.sim.step(1.0 / 60.0, windsurfer.controls)
	effects.update(windsurfer.sim)
	var arrows: ForceArrows = effects.force_arrows()
	var g: float = windsurfer.sim.sim_config.gravity_ms2
	var weight: Vector3 = arrows.arrow_vector("weight")
	assert_almost_eq(weight.length(), windsurfer.sim.sailor.mass_kg * g * ForceArrows.METRES_PER_NEWTON, 1e-3, "The sailor's weight")
	assert_gt(arrows.arrow_vector("buoyancy").y, 0.0, "Buoyancy pushes up")


# --- Wake ----------------------------------------------------------------------------------

func test_wake_is_made_only_when_moving() -> void:
	assert_eq(WakeTrail.wake_strength(0.0, 0.0), 0.0, "No wake at rest")
	assert_gt(WakeTrail.wake_strength(9.0, 1.0), WakeTrail.wake_strength(3.0, 0.0), "More when fast and planing")
	var sim: WindsurferSim = WindsurferSim.create_default(true)
	var wake: WakeTrail = WakeTrail.new()
	add_child_autofree(wake)
	wake.setup(sim)
	for i: int in 10:
		wake.add_tail(Vector3(0.0, 0.0, 0.0), 0.0)
	assert_eq(wake.point_count(), 1, "A board at rest leaves one point, no trail")
	for i: int in 10:
		wake.add_tail(Vector3(0.0, 0.0, float(i)), 1.0)
	assert_gt(wake.point_count(), 5, "A moving board leaves a trail")


# --- Water ---------------------------------------------------------------------------------

func test_water_looks_load_on_the_one_water_shader() -> void:
	for path: String in [SEA_LOOK, LAKE_LOOK]:
		var look: ShaderMaterial = load(path) as ShaderMaterial
		assert_not_null(look, path + " loads")
		if look == null:
			continue
		assert_eq(look.shader.resource_path, WATER_SHADER, path + " uses the game's water shader")
		assert_not_null(look.get_shader_parameter("ripple_normals"), path + " has its ripples")
		var absorption: Vector3 = look.get_shader_parameter("absorption_per_m")
		assert_gt(absorption.x, absorption.z, path + ": red is swallowed faster than blue")
		assert_eq(look.render_priority, -1, path + " is drawn before the see-through sail")
	var lake: ShaderMaterial = load(LAKE_LOOK) as ShaderMaterial
	assert_eq(lake.get_shader_parameter("grid_strength"), 0.0, "No grid on the lake")


func test_ocean_takes_a_look_and_the_render_layers() -> void:
	var sim: WindsurferSim = WindsurferSim.create_default(true)
	var camera: Camera3D = Camera3D.new()
	add_child_autofree(camera)
	var ocean: OceanNode = OceanNode.new()
	ocean.look = load(LAKE_LOOK) as ShaderMaterial
	ocean.render_layers = 2
	add_child_autofree(ocean)
	ocean.setup(sim, camera)
	var material: ShaderMaterial = ocean.near_material()
	assert_eq(material.shader.resource_path, WATER_SHADER)
	assert_eq(material.get_shader_parameter("absorption_per_m"), Vector3(0.4, 0.1, 0.08), "The lake's absorption")
	var amplitudes: Vector4 = material.get_shader_parameter("wave_amplitudes")
	assert_gt(amplitudes.x, 0.0, "The waves are on the near water")
	for child: Node in ocean.get_children():
		assert_eq((child as MeshInstance3D).layers, 2, "On the reflection probe's layer")
	# Switching back to the sea keeps the waves.
	ocean.set_look(null)
	var sea: ShaderMaterial = ocean.near_material()
	assert_eq(sea.get_shader_parameter("absorption_per_m"), Vector3(0.45, 0.07, 0.035), "The sea's absorption")
	assert_eq(sea.get_shader_parameter("wave_amplitudes"), amplitudes, "Same waves")


func test_ripples_grow_with_the_wind() -> void:
	assert_lt(OceanNode.ripple_factor_for_wind(1.0), 0.2, "Almost glassy in a calm")
	assert_gt(OceanNode.ripple_factor_for_wind(20.0), OceanNode.ripple_factor_for_wind(10.0), "More in more wind")
	assert_eq(OceanNode.ripple_factor_for_wind(60.0), OceanNode.RIPPLE_MAX_FACTOR, "Up to a limit")


func test_lake_far_water_stays_in_its_area() -> void:
	# On a map the far water covers the lake's area, fixed, wherever the camera goes.
	var sim: WindsurferSim = WindsurferSim.create_default(true)
	var camera: Camera3D = Camera3D.new()
	add_child_autofree(camera)
	camera.global_position = Vector3(900.0, 2.0, -300.0)
	var ocean: OceanNode = OceanNode.new()
	ocean.far_area_xz = Rect2(-2000.0, -1500.0, 4000.0, 3000.0)
	add_child_autofree(ocean)
	ocean.setup(sim, camera)
	var far: MeshInstance3D = ocean.get_node("FarWater") as MeshInstance3D
	assert_eq((far.mesh as PlaneMesh).size, Vector2(4000.0, 3000.0), "As big as the area")
	assert_almost_eq(far.global_position.x, 0.0, 1e-3, "Centred on the area, not on the camera")
	assert_almost_eq(far.global_position.z, 0.0, 1e-3, "Centred on the area, not on the camera")
	var near: MeshInstance3D = ocean.get_node("NearWater") as MeshInstance3D
	assert_almost_eq(near.global_position.x, 900.0, 1e-3, "The near water follows the camera")
