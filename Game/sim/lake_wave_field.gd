class_name LakeWaveField
extends WaveField
## The water of a lake whose waves grow with the fetch (PHYSICS_SPEC.md 9.17; LakeWaves): the same
## Gerstner surface as WaveField (9.4 to 9.7), made of the lake's trains the physics floats on
## (LakeWaves.physics_count, the longest), with two differences.
##   1. Each train's amplitude comes from the lake's grid, read at the asked point between the four
##      nearest nodes (bilinear), and its steepness is the physical one, k·A (at most pi/7). The
##      lengths, directions and phases are the same over the whole lake.
##   2. Each train has its own phase at the origin (LakeWaves: seeded).
##   3. The trains travel at the speed of the lake's depth, omega^2 = g k tanh(k h) with the lake's
##      reference depth (9.18; deep water for these trains on Silvaplana).
##   4. The water's motion fades below the surface, e^(-k depth) per train (velocity_below(), the
##      fin; 9.18).
##   5. A view of the lake can stand for the water a hull feels (set_footprint()): each train's
##      height averaged over the hull's wet bottom (9.18), so a planing hull bridges the chop
##      shorter than its wet length, as a real one does. The fin, the picture and the telemetry
##      take the lake's own view (no footprint: every factor 1).
## The heights change slowly next to a wavelength (nodes 16 m apart), so within one query the
## amplitudes of the asked point are used for the whole solve for the rest point and for the
## answers: the rest point lies at most the sum of the amplitudes (about 0.1 m) away, where the
## amplitudes differ by well under a millimetre. The shader reads the grid at the vertex's rest
## point; the two differ by that same fraction of a millimetre (test_lake_waves.gd).
##
## Every number this reads is its own (copied from the LakeWaves when made, packed arrays shared
## until written): boards stepped side by side on threads take no engine lock here.
##
## The base class's amplitude and steepness arrays hold the trains' values at the last point asked:
## height_at, normal_at, velocity_at and sample_at set them first. displacement_at, normal_at_rest
## and velocity_at_rest used on their own answer with those (call amplitudes_for() first).

var lake: LakeWaves
var phase: PackedFloat64Array = PackedFloat64Array()

# The grid, copied from the lake.
var _columns: int = 0
var _rows: int = 0
var _x0_m: float = 0.0
var _z0_m: float = 0.0
var _per_cell: float = 1.0
var _grid: PackedFloat32Array = PackedFloat32Array()
## The grid holds every train's amplitude (LakeWaves.band_count a node); the physics reads its first.
var _stride: int = 1
## How much of each train the asker feels (set_footprint()): 1 for the lake's own view; for a
## hull's view, the train's height averaged over its wet bottom.
var footprint_factor: PackedFloat64Array = PackedFloat64Array()
## Per train, for the time last asked (_thetas_at()): its phase at the origin less omega t, so a
## query's passes and answers add only k (d . x) to it. Every sample of a substep asks at one time.
var _theta: PackedFloat64Array = PackedFloat64Array()
var _theta_time: float = NAN


func _init(lake_waves: LakeWaves, water_config: WaterConfig = null) -> void:
	super(null, water_config, 0.0)
	lake = lake_waves
	count = lake.physics_count
	fades_with_depth = true
	for i: int in count:
		var wave_k: float = lake.wave_number[i]
		var wave_omega: float = WaveField.angular_frequency(wave_k, lake.reference_depth_m)
		k.append(wave_k)
		c.append(wave_omega / wave_k)
		omega.append(wave_omega)
		dir_x.append(lake.dir_x[i])
		dir_z.append(lake.dir_z[i])
		wavelength.append(lake.wavelength_m[i])
		phase.append(lake.phase0[i])
	amplitude.resize(count)
	amplitude.fill(0.0)
	steepness.resize(count)
	steepness.fill(0.0)
	footprint_factor.resize(count)
	footprint_factor.fill(1.0)
	_theta.resize(count)
	_theta.fill(0.0)
	_columns = lake.map.columns
	_rows = lake.map.rows
	_x0_m = lake.map.x0_m
	_z0_m = lake.map.z0_m
	_per_cell = 1.0 / lake.map.cell_m
	_grid = lake.amplitudes
	_stride = lake.band_count


## The lake's trains keep the direction they were built with: a new wind direction means new lake
## waves (LakeWaves), never turned trains (9.12).
func set_wind_bearing(_wind_from_bearing_deg: float) -> void:
	pass


## Makes this view the water a hull feels: each train's height averaged over the hull's wet bottom,
## length_m along its bow's direction `forward` (x, z) and beam_m across (9.18). The pressure of a
## wave of wave number k under a flat bottom of length l is its mean over that length, which for a
## sine wave is sin(k l / 2) / (k l / 2) (linear theory: the wave's pressure integrated over the
## bottom); a bottom l long is taken as a Gaussian of the same spread, l^2 / 12, so the factor is
## exp(-k^2 s^2 / 2) with s^2 = (l cos a)^2 / 12 + (b sin a)^2 / 12 for a train running at an angle
## a to the bow, smooth and never negative. A wave longer than the bottom is felt nearly whole; a
## wave shorter than it is bridged.
func set_footprint(length_m: float, beam_m: float, forward: Vector2) -> void:
	var length_spread: float = length_m * length_m / 12.0
	var beam_spread: float = beam_m * beam_m / 12.0
	for i: int in count:
		var along: float = forward.x * dir_x[i] + forward.y * dir_z[i]
		var across_squared: float = maxf(1.0 - along * along, 0.0)
		var spread: float = along * along * length_spread + across_squared * beam_spread
		footprint_factor[i] = exp(-0.5 * k[i] * k[i] * spread)


## Sets the trains' amplitudes and steepness to those at a game position (bilinear between the
## grid's nodes; flat off the grid), times the view's footprint factors.
func amplitudes_for(x: float, z: float) -> void:
	var fx: float = (x - _x0_m) * _per_cell
	var fz: float = (z - _z0_m) * _per_cell
	if fx < 0.0 or fz < 0.0 or fx >= _columns - 1.0 or fz >= _rows - 1.0:
		amplitude.fill(0.0)
		steepness.fill(0.0)
		return
	var column: int = int(fx)
	var row: int = int(fz)
	var tx: float = fx - column
	var tz: float = fz - row
	var north: int = (row * _columns + column) * _stride
	var south: int = north + _columns * _stride
	for i: int in count:
		var top: float = lerpf(_grid[north + i], _grid[north + _stride + i], tx)
		var bottom: float = lerpf(_grid[south + i], _grid[south + _stride + i], tx)
		var wave_a: float = lerpf(top, bottom, tz) * footprint_factor[i]
		amplitude[i] = wave_a
		steepness[i] = minf(k[i] * wave_a, LakeWaves.MAX_STEEPNESS)


# height_at, normal_at and velocity_at as WaveField's, with the amplitudes read once (WaveField's
# would read them again through rest_point_at()).
func height_at(x: float, z: float, t: float) -> float:
	amplitudes_for(x, z)
	if count == 0:
		return base_height_m
	var rest: Vector2 = rest_point_from(x, z, t, Vector2(x, z))
	return base_height_m + displacement_at(rest.x, rest.y, t).y


## The rest point of the surface point at (x, z), with the amplitudes there (so the _rest functions
## that follow answer for this point).
func rest_point_at(x: float, z: float, t: float) -> Vector2:
	amplitudes_for(x, z)
	return super(x, z, t)


func normal_at(x: float, z: float, t: float) -> Vector3:
	amplitudes_for(x, z)
	if count == 0:
		return Vector3.UP
	var rest: Vector2 = rest_point_from(x, z, t, Vector2(x, z))
	return normal_at_rest(rest.x, rest.y, t)


func velocity_at(x: float, z: float, t: float) -> Vector3:
	amplitudes_for(x, z)
	if count == 0:
		return Vector3.ZERO
	var rest: Vector2 = rest_point_from(x, z, t, Vector2(x, z))
	return velocity_at_rest(rest.x, rest.y, t)


## WaveField.sample_at with the solve written out here (the same sums in the same order, so the
## same answers to the last bit): the hull asks this about fifty times a substep, and every function
## call costs GDScript about as much as a train's arithmetic.
func sample_at(x: float, z: float, time_s: float, samples: PackedFloat64Array, index: int) -> void:
	amplitudes_for(x, z)
	var at: int = index * SAMPLE_SIZE
	var rest: Vector2 = Vector2(x, z)
	if samples[at + SAMPLE_IS_SET] > 0.5:
		var sideways_x: float = samples[at + SAMPLE_X] - samples[at + SAMPLE_REST_X]
		var sideways_z: float = samples[at + SAMPLE_Z] - samples[at + SAMPLE_REST_Z]
		rest = Vector2(x - sideways_x, z - sideways_z)
	if count == 0:
		write_sample(samples, index, x, z, time_s, rest, base_height_m, Vector3.UP, Vector3.ZERO)
		return
	_thetas_at(time_s)
	for pass_index: int in SOLVE_MAX_ITERATIONS:
		var sideways: Vector2 = Vector2.ZERO
		for i: int in count:
			var wave_k: float = k[i]
			var wave_x: float = dir_x[i]
			var wave_z: float = dir_z[i]
			var horizontal: float = steepness[i] / wave_k * cos(wave_k * (wave_x * rest.x + wave_z * rest.y) + _theta[i])
			sideways.x += wave_x * horizontal
			sideways.y += wave_z * horizontal
		var next: Vector2 = Vector2(x - sideways.x, z - sideways.y)
		var moved: float = next.distance_to(rest)
		rest = next
		if moved < SOLVE_TOLERANCE_M:
			break
	_answers_at_rest(x, z, time_s, rest, samples, index)


func _phase_of_wave(i: int) -> float:
	return phase[i]


## Each train's phase at the origin less omega t, for time t (kept until another time is asked).
func _thetas_at(t: float) -> void:
	if t == _theta_time:
		return
	_theta_time = t
	for i: int in count:
		_theta[i] = phase[i] - omega[i] * t


## WaveField.rest_point_from with the trains' times worked out once for all the passes.
func rest_point_from(x: float, z: float, t: float, start: Vector2) -> Vector2:
	if count == 0:
		return Vector2(x, z)
	_thetas_at(t)
	var rest: Vector2 = start
	for pass_index: int in SOLVE_MAX_ITERATIONS:
		var sideways: Vector2 = _sideways_at_thetas(rest.x, rest.y)
		var next: Vector2 = Vector2(x - sideways.x, z - sideways.y)
		var moved: float = next.distance_to(rest)
		rest = next
		if moved < SOLVE_TOLERANCE_M:
			break
	return rest


## The sideways displacement at a rest point, with the trains' times already in _theta.
func _sideways_at_thetas(rest_x: float, rest_z: float) -> Vector2:
	var sideways: Vector2 = Vector2.ZERO
	for i: int in count:
		var wave_k: float = k[i]
		var wave_x: float = dir_x[i]
		var wave_z: float = dir_z[i]
		var horizontal: float = steepness[i] / wave_k * cos(wave_k * (wave_x * rest_x + wave_z * rest_z) + _theta[i])
		sideways.x += wave_x * horizontal
		sideways.y += wave_z * horizontal
	return sideways


## The highest crest at a game position: the sum of the trains' amplitudes there (the AI's sea
## height, RaceObservation.sea_height_m()).
func crest_height_at(x: float, z: float) -> float:
	amplitudes_for(x, z)
	var total: float = 0.0
	for i: int in count:
		total += amplitude[i]
	return total


## As WaveField.displacement_at, with each train's own phase.
func displacement_at(rest_x: float, rest_z: float, t: float) -> Vector3:
	_thetas_at(t)
	var displacement: Vector3 = Vector3.ZERO
	for i: int in count:
		var wave_phase: float = k[i] * (dir_x[i] * rest_x + dir_z[i] * rest_z) + _theta[i]
		var horizontal: float = steepness[i] / k[i] * cos(wave_phase)
		displacement.x += dir_x[i] * horizontal
		displacement.z += dir_z[i] * horizontal
		displacement.y += amplitude[i] * sin(wave_phase)
	return displacement


func _sideways_displacement_at(rest_x: float, rest_z: float, t: float) -> Vector2:
	_thetas_at(t)
	return _sideways_at_thetas(rest_x, rest_z)


func normal_at_rest(rest_x: float, rest_z: float, t: float) -> Vector3:
	_thetas_at(t)
	var tangent_x: Vector3 = Vector3(1.0, 0.0, 0.0)
	var tangent_z: Vector3 = Vector3(0.0, 0.0, 1.0)
	for i: int in count:
		var wave_phase: float = k[i] * (dir_x[i] * rest_x + dir_z[i] * rest_z) + _theta[i]
		var sin_phase: float = sin(wave_phase)
		var cos_phase: float = cos(wave_phase)
		tangent_x.x -= dir_x[i] * dir_x[i] * steepness[i] * sin_phase
		tangent_x.y += amplitude[i] * k[i] * dir_x[i] * cos_phase
		tangent_x.z -= dir_x[i] * dir_z[i] * steepness[i] * sin_phase
		tangent_z.x -= dir_x[i] * dir_z[i] * steepness[i] * sin_phase
		tangent_z.y += amplitude[i] * k[i] * dir_z[i] * cos_phase
		tangent_z.z -= dir_z[i] * dir_z[i] * steepness[i] * sin_phase
	return tangent_z.cross(tangent_x).normalized()


func velocity_at_rest(rest_x: float, rest_z: float, t: float) -> Vector3:
	_thetas_at(t)
	var velocity: Vector3 = Vector3.ZERO
	for i: int in count:
		var wave_phase: float = k[i] * (dir_x[i] * rest_x + dir_z[i] * rest_z) + _theta[i]
		var forward: float = steepness[i] * c[i] * sin(wave_phase)
		velocity.x += dir_x[i] * forward
		velocity.z += dir_z[i] * forward
		velocity.y -= amplitude[i] * omega[i] * cos(wave_phase)
	return velocity


## As WaveField._answers_at_rest, with each train's own phase.
func _answers_at_rest(x: float, z: float, t: float, rest: Vector2, samples: PackedFloat64Array, index: int) -> void:
	_thetas_at(t)
	var rest_x: float = rest.x
	var rest_z: float = rest.y
	var displacement: Vector3 = Vector3.ZERO  # only its vertical part, the height, is needed
	var tangent_x: Vector3 = Vector3(1.0, 0.0, 0.0)
	var tangent_z: Vector3 = Vector3(0.0, 0.0, 1.0)
	var velocity: Vector3 = Vector3.ZERO
	for i: int in count:
		var wave_k: float = k[i]
		var wave_x: float = dir_x[i]
		var wave_z: float = dir_z[i]
		var wave_a: float = amplitude[i]
		var wave_s: float = steepness[i]
		var wave_omega: float = omega[i]
		var wave_phase: float = wave_k * (wave_x * rest_x + wave_z * rest_z) + _theta[i]
		var sin_phase: float = sin(wave_phase)
		var cos_phase: float = cos(wave_phase)
		displacement.y += wave_a * sin_phase
		var cross_term: float = wave_x * wave_z * wave_s * sin_phase
		tangent_x.x -= wave_x * wave_x * wave_s * sin_phase
		tangent_x.y += wave_a * wave_k * wave_x * cos_phase
		tangent_x.z -= cross_term
		tangent_z.x -= cross_term
		tangent_z.y += wave_a * wave_k * wave_z * cos_phase
		tangent_z.z -= wave_z * wave_z * wave_s * sin_phase
		var forward: float = wave_s * c[i] * sin_phase
		velocity.x += wave_x * forward
		velocity.z += wave_z * forward
		velocity.y -= wave_a * wave_omega * cos_phase
	var normal: Vector3 = tangent_z.cross(tangent_x).normalized()
	write_sample(samples, index, x, z, t, rest, base_height_m + displacement.y, normal, velocity)


## The highest crest the lake can have anywhere.
func total_amplitude_m() -> float:
	return lake.max_total_amplitude_m


## The lake's waves as the shader wants them (9.17): wave_a to wave_d are (direction x, direction z,
## phase at the origin, wavelength) of all the lake's trains, lake_envelope their amplitudes per
## node, lake_shape_trains how many of them (the first) the physics floats on and the picture shows
## as shape (the rest as shading only), lake_grid where the nodes lie (x and z of the first,
## 1 / their spacing), lake_grid_size how many, and the picture's own short train (lake_look_band,
## lake_look_data). lake_waves_on switches the shader from wave_a to wave_d's own amplitudes to the
## grid's.
func shader_parameters() -> Dictionary[String, Variant]:
	var parameters: Dictionary[String, Variant] = {}
	var names: Array[String] = ["wave_a", "wave_b", "wave_c", "wave_d"]
	for slot: int in WaveSetConfig.MAX_WAVES:
		if slot < lake.band_count:
			parameters[names[slot]] = Vector4(lake.dir_x[slot], lake.dir_z[slot], lake.phase0[slot], lake.wavelength_m[slot])
		else:
			parameters[names[slot]] = Vector4(0.0, -1.0, 0.0, 10.0)
	parameters["wave_amplitudes"] = Vector4.ZERO
	parameters["base_height_m"] = base_height_m
	parameters["wave_depth_m"] = lake.reference_depth_m
	parameters["lake_waves_on"] = true
	parameters["lake_shape_trains"] = count
	parameters["lake_grid"] = Vector4(_x0_m, _z0_m, _per_cell, 0.0)
	parameters["lake_grid_size"] = Vector2i(_columns, _rows)
	parameters["lake_look_band"] = Vector4(lake.look_dir.x, lake.look_dir.y, lake.look_phase0, lake.config.look_wavelength_m)
	var textures: Dictionary[String, Texture2D] = lake.textures()
	for key: String in textures:
		parameters[key] = textures[key]
	return parameters
