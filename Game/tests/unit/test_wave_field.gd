extends GutTest
## The Gerstner wave field against the hand-calculated values of PHYSICS_SPEC.md section 9
## ("Tests Phase 2 should write"): one wave of 10 m, 0.1 m and steepness 0.25 travelling
## North unless a test says otherwise; the default set of waves_default.tres for the bounds.
## The swell and the chop each have their own direction (9.15).

const TOL: float = 1e-4


func _one_wave(wavelength_m: float = 10.0, amplitude_m: float = 0.1, steepness: float = 0.25, offset_deg: float = 0.0) -> WaveSetConfig:
	var wave: GerstnerWaveConfig = GerstnerWaveConfig.new()
	wave.wavelength_m = wavelength_m
	wave.amplitude_m = amplitude_m
	wave.steepness = steepness
	wave.direction_offset_deg = offset_deg
	wave.group = GerstnerWaveConfig.Group.SWELL
	var set_config: WaveSetConfig = WaveSetConfig.new()
	# A swell from the South travels North, so the offset is measured from North.
	set_config.swell_relative_to_wind = false
	set_config.swell_from_deg = 180.0
	set_config.waves = [wave]
	return set_config


func _north_wave() -> WaveField:
	return WaveField.new(_one_wave())


func _default_set() -> WaveField:
	var set_config: WaveSetConfig = load("res://config/waves_default.tres")
	return WaveField.new(set_config, null, 270.0)


func test_derived_quantities_of_the_10_m_wave() -> void:
	var field: WaveField = _north_wave()
	assert_eq(field.count, 1)
	assert_almost_eq(field.k[0], 0.628319, 1e-6, "wave number")
	assert_almost_eq(field.c[0], 3.951342, 1e-5, "phase speed")
	assert_almost_eq(field.omega[0], 2.482701, 1e-5, "angular frequency")
	assert_almost_eq(field.period_s(0), 2.530786, 1e-5, "period")
	assert_almost_eq(field.omega[0], field.k[0] * field.c[0], 1e-9, "omega = k c")
	assert_almost_eq(field.period_s(0), sqrt(TAU * 10.0 / 9.81), 1e-9, "T = sqrt(2 pi L / g)")


func test_bearings_become_d4_directions() -> void:
	assert_almost_eq(WaveField.direction_for_bearing(0.0).x, 0.0, 1e-9)
	assert_almost_eq(WaveField.direction_for_bearing(0.0).y, -1.0, 1e-9, "North is -Z")
	assert_almost_eq(WaveField.direction_for_bearing(90.0).x, 1.0, 1e-9, "East is +X")
	assert_almost_eq(WaveField.direction_for_bearing(90.0).y, 0.0, 1e-9)
	assert_almost_eq(WaveField.direction_for_bearing(180.0).y, 1.0, 1e-9, "South is +Z")
	assert_almost_eq(WaveField.direction_for_bearing(270.0).x, -1.0, 1e-9, "West is -X")
	# Wind from the West, offset +12: the wave travels at bearing 102, East and a little South.
	var field: WaveField = WaveField.new(_one_wave(10.0, 0.1, 0.25, 12.0), null, 270.0)
	field.config.swell_relative_to_wind = true
	field.set_wind_bearing(270.0)
	assert_almost_eq(field.dir_x[0], 0.9781, 1e-4)
	assert_almost_eq(field.dir_z[0], 0.2079, 1e-4)


func test_displacement_of_rest_points_at_t_zero() -> void:
	var field: WaveField = _north_wave()
	var crest: Vector3 = field.displacement_at(0.0, -2.5, 0.0)
	assert_almost_eq(crest.y, 0.1, TOL, "crest 2.5 m North of the origin")
	assert_almost_eq(crest.z, 0.0, TOL, "no sideways shift on the crest")
	var mean: Vector3 = field.displacement_at(0.0, 0.0, 0.0)
	assert_almost_eq(mean.y, 0.0, TOL)
	assert_almost_eq(mean.z, -0.397887, TOL, "at mean level the point has moved North, toward the crest")
	assert_almost_eq(field.displacement_at(0.0, -5.0, 0.0).z, 0.397887, TOL, "and South on the other side")
	assert_almost_eq(field.displacement_at(0.0, -7.5, 0.0).y, -0.1, TOL, "trough")
	assert_almost_eq(field.displacement_at(0.0, 2.5, 0.0).y, -0.1, TOL, "trough")
	assert_almost_eq(field.displacement_at(3.0, 0.0, 0.0).z, -0.397887, TOL, "x does not matter for a North-going wave")


func test_height_at_world_points() -> void:
	var field: WaveField = _north_wave()
	assert_almost_eq(field.height_at(0.0, -2.5, 0.0), 0.1, TOL, "the crest is where it started")
	assert_almost_eq(field.height_at(0.0, 0.0, 0.0), -0.02403, 1e-3, "the solve: the point at (0, 0) came from rest z = +0.386")
	assert_almost_eq(field.height_at(3.0, 0.0, 0.0), -0.02403, 1e-3)
	var period: float = field.period_s(0)
	assert_almost_eq(field.height_at(0.0, 0.0, period / 4.0), -0.1, TOL, "a quarter period later the trough is at the origin, unshifted")
	assert_almost_eq(field.height_at(0.0, 0.0, period), -0.02403, 1e-3, "and a period later it repeats")
	var sine: WaveField = WaveField.new(_one_wave(10.0, 0.1, 0.0))
	assert_almost_eq(sine.height_at(0.0, -5.0, 0.0), 0.0, TOL, "a pure sine needs no solve")
	assert_almost_eq(sine.height_at(4.0, -1.25, 0.0), 0.070711, TOL)
	assert_almost_eq(sine.height_at(0.0, -2.5, 0.0), 0.1, TOL)


func test_the_pattern_repeats_with_the_period() -> void:
	var field: WaveField = _default_set()
	seed(5)
	for i: int in 50:
		var x: float = randf_range(-50.0, 50.0)
		var z: float = randf_range(-50.0, 50.0)
		var t: float = randf_range(0.0, 30.0)
		var period: float = field.period_s(0)
		# Only the first wave repeats with its own period; check it alone.
		var one: WaveField = WaveField.new(_one_wave(14.0, 0.1, 0.2, 12.0))
		assert_almost_eq(one.height_at(x, z, t + one.period_s(0)), one.height_at(x, z, t), 1e-3, "one wave repeats")
		assert_true(period > 0.0)


func test_heights_stay_within_the_total_amplitude_and_the_solve_converges() -> void:
	var field: WaveField = _default_set()
	var bound: float = field.total_amplitude_m()
	assert_true(bound > 0.0)
	assert_almost_eq(bound, 0.107, 1e-6, "the default set's amplitudes add up to 0.107 m")
	seed(7)
	var worst_residual: float = 0.0
	for i: int in 500:
		var x: float = randf_range(-100.0, 100.0)
		var z: float = randf_range(-100.0, 100.0)
		var t: float = randf_range(0.0, 60.0)
		var height: float = field.height_at(x, z, t)
		assert_true(absf(height) <= bound + 1e-6, "height %.4f within %.3f" % [height, bound])
		var rest: Vector2 = field.rest_point_at(x, z, t)
		var displacement: Vector3 = field.displacement_at(rest.x, rest.y, t)
		worst_residual = maxf(worst_residual, Vector2(rest.x + displacement.x - x, rest.y + displacement.z - z).length())
	assert_lt(worst_residual, 0.0015, "rest + displacement lands on the world point within about a millimetre")


func test_flat_when_disabled_or_without_amplitude() -> void:
	var disabled: WaveSetConfig = _one_wave()
	disabled.enable_waves = false
	var flat: WaveField = WaveField.new(disabled)
	var still: WaveSetConfig = _one_wave(10.0, 0.0, 0.25)
	var no_height: WaveField = WaveField.new(still)
	for field: WaveField in [flat, no_height]:
		assert_eq(field.count, 0)
		assert_almost_eq(field.height_at(3.0, -7.0, 2.0), 0.0, 1e-9)
		assert_eq(field.normal_at(3.0, -7.0, 2.0), Vector3.UP)
		assert_eq(field.velocity_at(3.0, -7.0, 2.0), Vector3.ZERO)
	var level: WaterConfig = WaterConfig.new()
	level.base_height_m = 1.5
	assert_almost_eq(WaveField.new(disabled, level).height_at(0.0, 0.0, 0.0), 1.5, 1e-9, "the still level is the base height")


func test_normals() -> void:
	var field: WaveField = _north_wave()
	assert_almost_eq(field.normal_at_rest(0.0, -2.5, 0.0).distance_to(Vector3.UP), 0.0, TOL, "level on the crest")
	assert_almost_eq(field.normal_at_rest(0.0, -7.5, 0.0).distance_to(Vector3.UP), 0.0, TOL, "level in the trough")
	var front: Vector3 = field.normal_at_rest(0.0, 0.0, 0.0)
	assert_almost_eq(front.x, 0.0, TOL)
	assert_almost_eq(front.y, 0.99803, TOL)
	assert_almost_eq(front.z, 0.06270, TOL, "the face rising toward North tilts the normal South")
	assert_almost_eq(field.normal_at_rest(0.0, -5.0, 0.0).z, -0.06270, TOL)
	# The analytic normal agrees with a finite-difference normal of the height field.
	var waves: WaveField = _default_set()
	seed(11)
	var worst_deg: float = 0.0
	for i: int in 100:
		var rest_x: float = randf_range(-50.0, 50.0)
		var rest_z: float = randf_range(-50.0, 50.0)
		var t: float = randf_range(0.0, 20.0)
		var displacement: Vector3 = waves.displacement_at(rest_x, rest_z, t)
		var x: float = rest_x + displacement.x
		var z: float = rest_z + displacement.z
		var delta: float = 0.005
		var h0: float = waves.height_at(x, z, t)
		var hx: float = waves.height_at(x + delta, z, t)
		var hz: float = waves.height_at(x, z + delta, t)
		var numeric: Vector3 = Vector3(-(hx - h0) / delta, 1.0, -(hz - h0) / delta).normalized()
		var analytic: Vector3 = waves.normal_at_rest(rest_x, rest_z, t)
		worst_deg = maxf(worst_deg, rad_to_deg(acos(clampf(numeric.dot(analytic), -1.0, 1.0))))
	assert_lt(worst_deg, 0.3, "the exact normal and the finite-difference normal agree within 0.3 degrees (worst %.3f)" % worst_deg)


func test_orbital_velocity() -> void:
	var field: WaveField = _north_wave()
	var crest: Vector3 = field.velocity_at_rest(0.0, -2.5, 0.0)
	assert_almost_eq(crest.z, -0.987836, TOL, "forward with the wave on the crest (North)")
	assert_almost_eq(crest.y, 0.0, TOL)
	assert_almost_eq(field.velocity_at_rest(0.0, -7.5, 0.0).z, 0.987836, TOL, "backward in the trough")
	assert_almost_eq(field.velocity_at_rest(0.0, 0.0, 0.0).y, -0.248270, TOL, "falling at the mean level behind the crest")
	assert_almost_eq(field.velocity_at_rest(0.0, -5.0, 0.0).y, 0.248270, TOL, "rising ahead of it")
	var waves: WaveField = _default_set()
	seed(13)
	for i: int in 50:
		var rest_x: float = randf_range(-50.0, 50.0)
		var rest_z: float = randf_range(-50.0, 50.0)
		var t: float = randf_range(0.0, 20.0)
		var dt: float = 1e-3
		var numeric: Vector3 = (waves.displacement_at(rest_x, rest_z, t + dt) - waves.displacement_at(rest_x, rest_z, t - dt)) / (2.0 * dt)
		assert_almost_eq(numeric.distance_to(waves.velocity_at_rest(rest_x, rest_z, t)), 0.0, 5e-4, "the velocity is the time derivative of the displacement (single-precision rounding allows for)")


func test_steepness_limit() -> void:
	var cusp: WaveField = WaveField.new(_one_wave(10.0, 0.1, 1.0))
	var folded: WaveField = WaveField.new(_one_wave(10.0, 0.1, 1.2))
	var lowest_cusp: float = INF
	var lowest_folded: float = INF
	for i: int in 400:
		var rest_z: float = -10.0 + 20.0 * float(i) / 400.0
		var delta: float = 0.001
		lowest_cusp = minf(lowest_cusp, ((rest_z + delta + cusp.displacement_at(0.0, rest_z + delta, 0.0).z) - (rest_z + cusp.displacement_at(0.0, rest_z, 0.0).z)) / delta)
		lowest_folded = minf(lowest_folded, ((rest_z + delta + folded.displacement_at(0.0, rest_z + delta, 0.0).z) - (rest_z + folded.displacement_at(0.0, rest_z, 0.0).z)) / delta)
	assert_gt(lowest_cusp, -0.01, "at steepness 1 the surface just reaches a cusp")
	assert_lt(lowest_folded, -0.1, "above 1 it folds over")
	var too_steep: WaveSetConfig = _one_wave(10.0, 0.1, 1.2)
	assert_gt(too_steep.validate().size(), 0, "the validator refuses it")
	var with_a_silent_wave: WaveSetConfig = _one_wave(10.0, 0.1, 0.5)
	var silent: GerstnerWaveConfig = GerstnerWaveConfig.new()
	silent.amplitude_m = 0.0
	silent.steepness = 0.9
	with_a_silent_wave.waves.append(silent)
	assert_almost_eq(with_a_silent_wave.total_steepness(), 0.5, 1e-9, "a wave without amplitude does not count")
	assert_eq(with_a_silent_wave.validate().size(), 0)


func test_default_set_is_physical_and_the_shader_gets_the_same_numbers() -> void:
	var set_config: WaveSetConfig = load("res://config/waves_default.tres")
	assert_eq(set_config.validate().size(), 0, "the default set is valid")
	for wave: GerstnerWaveConfig in set_config.active_waves():
		assert_almost_eq(wave.steepness, wave.physical_steepness(), 0.005, "steepness is k A: a physically consistent trochoid (%.1f m)" % wave.wavelength_m)
	var field: WaveField = _default_set()
	var parameters: Dictionary[String, Variant] = field.shader_parameters()
	var wave_a: Vector4 = parameters["wave_a"]
	assert_almost_eq(wave_a.x, 0.9781, 1e-4, "wind from the West, offset +12: East and a little South")
	assert_almost_eq(wave_a.y, 0.2079, 1e-4)
	assert_almost_eq(wave_a.z, 0.036, 1e-6)
	assert_almost_eq(wave_a.w, 14.0, 1e-6)
	var amplitudes: Vector4 = parameters["wave_amplitudes"]
	assert_almost_eq(amplitudes.x, 0.08, 1e-6)
	assert_almost_eq(amplitudes.y, 0.02, 1e-6)
	assert_almost_eq(amplitudes.z, 0.005, 1e-6)
	assert_almost_eq(amplitudes.w, 0.002, 1e-6)
	set_config.enable_waves = false
	var off: WaveField = WaveField.new(set_config, null, 270.0)
	var off_amplitudes: Vector4 = off.shader_parameters()["wave_amplitudes"]
	assert_eq(off_amplitudes, Vector4.ZERO, "waves off: every slot empty")


## The default set as it was before the waves were split into a swell and a chop group
## (Session 37): the same four waves in the same directions, so the validation suite's sea
## runs do not move. Each row: the offset from downwind (deg), length, amplitude, steepness.
const SESSION_37_WAVES: Array[Array] = [
	[12.0, 14.0, 0.08, 0.036],
	[-28.0, 7.0, 0.02, 0.018],
	[40.0, 3.5, 0.005, 0.009],
	[-55.0, 1.8, 0.002, 0.007],
]


func test_the_default_set_has_the_same_four_waves_as_before_the_groups() -> void:
	var field: WaveField = _default_set()  # wind from 270: downwind is bearing 90 (East)
	assert_eq(field.count, 4)
	for i: int in SESSION_37_WAVES.size():
		var old: Array = SESSION_37_WAVES[i]
		var direction: Vector2 = WaveField.direction_for_bearing(90.0 + float(old[0]))
		assert_almost_eq(field.dir_x[i], direction.x, 1e-9, "wave %d direction x" % (i + 1))
		assert_almost_eq(field.dir_z[i], direction.y, 1e-9, "wave %d direction z" % (i + 1))
		assert_almost_eq(field.wavelength[i], float(old[1]), 1e-9, "wave %d length" % (i + 1))
		assert_almost_eq(field.amplitude[i], float(old[2]), 1e-9, "wave %d amplitude" % (i + 1))
		assert_almost_eq(field.steepness[i], float(old[3]), 1e-9, "wave %d steepness" % (i + 1))
	var set_config: WaveSetConfig = field.config
	assert_eq(set_config.waves_in_group(GerstnerWaveConfig.Group.SWELL).size(), 1, "one swell: the 14 m wave")
	assert_eq(set_config.waves_in_group(GerstnerWaveConfig.Group.CHOP).size(), 3, "three chop waves")
	assert_eq(set_config.waves[0].group, GerstnerWaveConfig.Group.SWELL)


func test_a_swell_from_a_compass_bearing_stays_when_the_wind_turns() -> void:
	var set_config: WaveSetConfig = _swell_and_chop()
	set_config.swell_relative_to_wind = false
	set_config.swell_from_deg = 0.0  # from the North: it travels South, +Z
	var field: WaveField = WaveField.new(set_config, null, 270.0)
	assert_almost_eq(field.dir_x[0], 0.0, 1e-9, "the swell travels South")
	assert_almost_eq(field.dir_z[0], 1.0, 1e-9)
	assert_almost_eq(field.dir_x[1], 1.0, 1e-9, "the chop travels East, downwind of a West wind")
	assert_almost_eq(field.dir_z[1], 0.0, 1e-9)
	field.set_wind_bearing(180.0)  # the wind turns to the South
	assert_almost_eq(field.dir_z[0], 1.0, 1e-9, "the swell has not moved")
	assert_almost_eq(field.dir_x[1], 0.0, 1e-9, "the chop now travels North")
	assert_almost_eq(field.dir_z[1], -1.0, 1e-9)


func test_a_swell_relative_to_the_wind_turns_with_it() -> void:
	var set_config: WaveSetConfig = _swell_and_chop()
	set_config.swell_relative_to_wind = true
	set_config.swell_offset_deg = 90.0  # a quarter turn clockwise from downwind
	var field: WaveField = WaveField.new(set_config, null, 270.0)
	assert_almost_eq(field.dir_z[0], 1.0, 1e-9, "downwind East + 90: South")
	field.set_wind_bearing(0.0)  # wind from the North: downwind is South, + 90 is West
	assert_almost_eq(field.dir_x[0], -1.0, 1e-9, "the swell turned with the wind")
	assert_almost_eq(field.dir_z[1], 1.0, 1e-9, "the chop travels South")


func test_the_chop_offset_turns_only_the_chop() -> void:
	var set_config: WaveSetConfig = _swell_and_chop()
	set_config.chop_offset_deg = -45.0
	var field: WaveField = WaveField.new(set_config, null, 270.0)
	assert_almost_eq(field.dir_x[0], 1.0, 1e-9, "the swell still travels East")
	var chop: Vector2 = WaveField.direction_for_bearing(45.0)
	assert_almost_eq(field.dir_x[1], chop.x, 1e-9, "the chop travels North-East: 45 degrees left of downwind")
	assert_almost_eq(field.dir_z[1], chop.y, 1e-9)
	assert_almost_eq(set_config.chop_travel_bearing_deg(270.0), 405.0, 1e-9)


## One swell wave and one chop wave, both without a per-wave offset.
func _swell_and_chop() -> WaveSetConfig:
	var swell: GerstnerWaveConfig = GerstnerWaveConfig.new()
	swell.group = GerstnerWaveConfig.Group.SWELL
	swell.wavelength_m = 20.0
	swell.amplitude_m = 0.1
	swell.steepness = 0.03
	var chop: GerstnerWaveConfig = GerstnerWaveConfig.new()
	chop.group = GerstnerWaveConfig.Group.CHOP
	chop.wavelength_m = 4.0
	chop.amplitude_m = 0.05
	chop.steepness = 0.08
	var set_config: WaveSetConfig = WaveSetConfig.new()
	set_config.waves = [swell, chop]
	return set_config



# F1, the sea query (AI_FLEET_PLAN.md, D2): the hull asks for the height, the normal and the
# velocity at once (WaterSurface.sample_at), from one solve started where the last substep's
# ended. The answers must be the three queries' answers: to the last bit when the solve
# starts cold, within the solver's own millimetre when it starts warm.


## The solve of 9.5 as the spec writes it and as rest_point_at did it until F1: each pass
## takes the whole displacement_at and keeps its sideways part.
func _rest_point_as_the_spec_solves_it(field: WaveField, x: float, z: float, t: float) -> Vector2:
	var rest: Vector2 = Vector2(x, z)
	for i: int in WaveField.SOLVE_MAX_ITERATIONS:
		var displacement: Vector3 = field.displacement_at(rest.x, rest.y, t)
		var next: Vector2 = Vector2(x - displacement.x, z - displacement.z)
		var moved: float = next.distance_to(rest)
		rest = next
		if moved < WaveField.SOLVE_TOLERANCE_M:
			break
	return rest


func test_the_solve_finds_the_same_rest_point_as_the_spec_s_solve() -> void:
	var field: WaveField = _default_set()
	seed(21)
	var differ: int = 0
	for i: int in 200:
		var x: float = randf_range(-100.0, 100.0)
		var z: float = randf_range(-100.0, 100.0)
		var t: float = randf_range(0.0, 60.0)
		if field.rest_point_at(x, z, t) != _rest_point_as_the_spec_solves_it(field, x, z, t):
			differ += 1
	assert_eq(differ, 0, "the sideways-only passes find the same rest point to the last bit")


func test_a_cold_sample_gives_the_three_queries_answers() -> void:
	var field: WaveField = _default_set()
	var samples: PackedFloat64Array = WaterSurface.new_samples(1)
	seed(17)
	var worst_height_m: float = 0.0
	var worst_normal: float = 0.0
	var worst_velocity_ms: float = 0.0
	var differ: int = 0
	for i: int in 200:
		var x: float = randf_range(-100.0, 100.0)
		var z: float = randf_range(-100.0, 100.0)
		var t: float = randf_range(0.0, 60.0)
		WaterSurface.forget_samples(samples)  # cold: the solve starts at (x, z), as the three queries' solves do
		field.sample_at(x, z, t, samples, 0)
		worst_height_m = maxf(worst_height_m, absf(WaterSurface.sample_height(samples, 0) - field.height_at(x, z, t)))
		worst_normal = maxf(worst_normal, WaterSurface.sample_normal(samples, 0).distance_to(field.normal_at(x, z, t)))
		worst_velocity_ms = maxf(worst_velocity_ms, WaterSurface.sample_velocity(samples, 0).distance_to(field.velocity_at(x, z, t)))
		if WaterSurface.sample_rest_point(samples, 0) != field.rest_point_at(x, z, t) or not WaterSurface.sample_answers(samples, 0, x, z, t):
			differ += 1
	assert_lt(worst_height_m, 1e-9, "the height of height_at (worst %s m)" % String.num_scientific(worst_height_m))
	assert_lt(worst_normal, 1e-9, "the normal of normal_at (worst %s)" % String.num_scientific(worst_normal))
	assert_lt(worst_velocity_ms, 1e-9, "the velocity of velocity_at (worst %s m/s)" % String.num_scientific(worst_velocity_ms))
	assert_eq(differ, 0, "the record keeps the question and the rest point")


func test_a_warm_sample_agrees_within_the_solver_s_millimetre() -> void:
	var field: WaveField = _default_set()
	var samples: PackedFloat64Array = WaterSurface.new_samples(1)
	seed(19)
	var worst_height_m: float = 0.0
	var worst_normal: float = 0.0
	var worst_velocity_ms: float = 0.0
	var worst_residual_m: float = 0.0
	for i: int in 200:
		var x: float = randf_range(-100.0, 100.0)
		var z: float = randf_range(-100.0, 100.0)
		var t: float = randf_range(0.0, 60.0)
		# The record holds an answer whose rest point is 4 cm from this point's: the solve
		# starts there.
		var rest: Vector2 = field.rest_point_at(x, z, t)
		var angle: float = randf_range(0.0, TAU)
		var start: Vector2 = rest + 0.04 * Vector2(cos(angle), sin(angle))
		WaterSurface.write_sample(samples, 0, x, z, t - 1.0 / 180.0, start, 0.0, Vector3.UP, Vector3.ZERO)
		field.sample_at(x, z, t, samples, 0)
		worst_height_m = maxf(worst_height_m, absf(WaterSurface.sample_height(samples, 0) - field.height_at(x, z, t)))
		worst_normal = maxf(worst_normal, WaterSurface.sample_normal(samples, 0).distance_to(field.normal_at(x, z, t)))
		worst_velocity_ms = maxf(worst_velocity_ms, WaterSurface.sample_velocity(samples, 0).distance_to(field.velocity_at(x, z, t)))
		var found: Vector2 = WaterSurface.sample_rest_point(samples, 0)
		var displacement: Vector3 = field.displacement_at(found.x, found.y, t)
		worst_residual_m = maxf(worst_residual_m, Vector2(found.x + displacement.x - x, found.y + displacement.z - z).length())
	assert_lt(worst_height_m, WaveField.SOLVE_TOLERANCE_M, "the height within the solver's millimetre (worst %.6f mm)" % (worst_height_m * 1000.0))
	assert_lt(worst_normal, 1e-4, "the normal within 1e-4 (worst %s)" % String.num_scientific(worst_normal))
	assert_lt(worst_velocity_ms, 1e-3, "the velocity within a millimetre per second (worst %s m/s)" % String.num_scientific(worst_velocity_ms))
	assert_lt(worst_residual_m, 0.0015, "rest + displacement lands on the world point within about a millimetre")


func test_a_sample_carried_along_with_a_moving_point_keeps_agreeing() -> void:
	# A point of a board at 10 m/s, asked every substep of 1/180 s for 3 s, each solve
	# started from the substep before's answer.
	var field: WaveField = _default_set()
	var samples: PackedFloat64Array = WaterSurface.new_samples(1)
	var worst_height_m: float = 0.0
	var worst_normal: float = 0.0
	var dt: float = 1.0 / 180.0
	for i: int in 540:
		var t: float = 5.0 + i * dt
		var x: float = 3.0 + 10.0 * cos(0.3) * i * dt
		var z: float = -7.0 + 10.0 * sin(0.3) * i * dt
		field.sample_at(x, z, t, samples, 0)
		worst_height_m = maxf(worst_height_m, absf(WaterSurface.sample_height(samples, 0) - field.height_at(x, z, t)))
		worst_normal = maxf(worst_normal, WaterSurface.sample_normal(samples, 0).distance_to(field.normal_at(x, z, t)))
	assert_lt(worst_height_m, WaveField.SOLVE_TOLERANCE_M, "worst %.6f mm" % (worst_height_m * 1000.0))
	assert_lt(worst_normal, 1e-4, "worst %s" % String.num_scientific(worst_normal))


func test_flat_water_samples_are_still_and_level() -> void:
	var level: WaterConfig = WaterConfig.new()
	level.base_height_m = 1.5
	var disabled: WaveSetConfig = _one_wave()
	disabled.enable_waves = false
	for surface: WaterSurface in [FlatWater.new(level), WaveField.new(disabled, level)]:
		var samples: PackedFloat64Array = WaterSurface.new_samples(2)
		surface.sample_at(3.0, -7.0, 2.0, samples, 1)
		assert_false(WaterSurface.sample_is_set(samples, 0), "only the record asked for is written")
		assert_true(WaterSurface.sample_is_set(samples, 1))
		assert_eq(WaterSurface.sample_height(samples, 1), surface.height_at(3.0, -7.0, 2.0))
		assert_eq(WaterSurface.sample_height(samples, 1), 1.5)
		assert_eq(WaterSurface.sample_normal(samples, 1), Vector3.UP)
		assert_eq(WaterSurface.sample_velocity(samples, 1), Vector3.ZERO)
		assert_eq(WaterSurface.sample_rest_point(samples, 1), Vector2(3.0, -7.0), "nothing is displaced")


func test_the_board_s_samples_on_the_waves_are_the_three_queries_answers() -> void:
	# A board sailing a beam reach on the default sea: every sample of the buoyancy grid,
	# every substep, against the three queries at the same point and time.
	var sim: WindsurferSim = WindsurferSim.create_default(true)
	sim.reset(Vector3.ZERO, deg_to_rad(180.0))
	var pilot: Autopilot = Autopilot.new()
	pilot.target_twa_deg = 90.0
	pilot.sail = sim.sail
	pilot.sailor = sim.sailor_config
	var controls: SimControls = SimControls.new()
	controls.sheet = 0.0
	var field: WaveField = sim.water as WaveField
	assert_not_null(field, "the default sea is on")
	var worst_height_m: float = 0.0
	var worst_normal: float = 0.0
	var worst_velocity_ms: float = 0.0
	var points: int = sim.buoyancy.sample_points.size()
	for tick: int in 480:
		pilot.update(sim.telemetry, controls, 1.0 / 60.0)
		sim.step(1.0 / 60.0, controls)
		var samples: PackedFloat64Array = sim.buoyancy.sea_samples
		for k: int in points:
			var at: int = k * WaterSurface.SAMPLE_SIZE
			var x: float = samples[at + WaterSurface.SAMPLE_X]
			var z: float = samples[at + WaterSurface.SAMPLE_Z]
			var t: float = samples[at + WaterSurface.SAMPLE_TIME_S]
			worst_height_m = maxf(worst_height_m, absf(WaterSurface.sample_height(samples, k) - field.height_at(x, z, t)))
			worst_normal = maxf(worst_normal, WaterSurface.sample_normal(samples, k).distance_to(field.normal_at(x, z, t)))
			worst_velocity_ms = maxf(worst_velocity_ms, WaterSurface.sample_velocity(samples, k).distance_to(field.velocity_at(x, z, t)))
	assert_gt(sim.telemetry.speed_ms, 7.0, "the board is sailing")
	assert_lt(worst_height_m, WaveField.SOLVE_TOLERANCE_M, "worst %.6f mm" % (worst_height_m * 1000.0))
	assert_lt(worst_normal, 1e-4, "worst %s" % String.num_scientific(worst_normal))
	assert_lt(worst_velocity_ms, 1e-3, "worst %s m/s" % String.num_scientific(worst_velocity_ms))
	# The hull asks the grid's centre column in the same substep: the same points at the same
	# time, so the grid's records answer its questions.
	sim.buoyancy.apply(sim.body, sim.water, sim.time_s, 9.81)
	var grid: PackedFloat64Array = sim.buoyancy.sea_samples_of(sim.water)
	var answered: int = 0
	for k: int in points:
		var point: Vector3 = sim.body.point_world(sim.buoyancy.sample_points[k])
		if WaterSurface.sample_answers(grid, k, point.x, point.z, sim.time_s):
			answered += 1
	assert_eq(answered, points)
	assert_true(sim.buoyancy.sea_samples_of(FlatWater.new()).is_empty(), "not on another surface")
	var first: Vector3 = sim.body.point_world(sim.buoyancy.sample_points[0])
	assert_false(WaterSurface.sample_answers(grid, 0, first.x, first.z, sim.time_s + 0.001), "not at another time")


func test_reset_forgets_the_water_s_answers() -> void:
	# The records remember the last answers, where the next solves start. reset() forgets
	# them, so a board put somewhere new solves from scratch, as a new board does: its first
	# answers are the cold ones, bit for bit.
	var sim: WindsurferSim = WindsurferSim.create_default(true)
	var controls: SimControls = SimControls.new()
	sim.reset(Vector3(20.0, 0.0, -30.0), deg_to_rad(90.0))
	for tick: int in 30:
		sim.step(1.0 / 60.0, controls)
	var points: int = sim.buoyancy.sample_points.size()
	assert_eq(_answered(sim.buoyancy.sea_samples), points, "after a run every grid point remembers")
	assert_eq(_answered(sim.hull._sea_at_wet_centroid), 1, "and so does the hull's wet centroid")
	sim.reset(Vector3.ZERO, deg_to_rad(180.0))
	# The hull's own records are private to it; the test looks at them all the same.
	var remembered: int = _answered(sim.buoyancy.sea_samples)
	for samples: PackedFloat64Array in [sim.hull._sea_at_wet_centroid, sim.hull._sea_at_spray_root, sim.hull._sea_at_centre_of_buoyancy, sim.hull._sea_at_strips, sim.hull._sea_at_rail_strips]:
		remembered += _answered(samples)
	assert_eq(remembered, 0, "after reset() nothing is remembered")
	# The first answers after the reset are the cold ones.
	sim.buoyancy.apply(sim.body, sim.water, 0.0, 9.81)
	var fresh: WindsurferSim = WindsurferSim.create_default(true)
	fresh.reset(Vector3.ZERO, deg_to_rad(180.0))
	fresh.buoyancy.apply(fresh.body, fresh.water, 0.0, 9.81)
	assert_eq(sim.buoyancy.sea_samples, fresh.buoyancy.sea_samples, "the same records as a new board's")


## How many records of `samples` hold an answer.
func _answered(samples: PackedFloat64Array) -> int:
	var answered: int = 0
	for index: int in samples.size() / WaterSurface.SAMPLE_SIZE:
		answered += 1 if WaterSurface.sample_is_set(samples, index) else 0
	return answered
