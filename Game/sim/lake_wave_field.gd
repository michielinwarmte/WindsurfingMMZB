class_name LakeWaveField
extends WaveField
## The water of a lake whose waves grow with the fetch (PHYSICS_SPEC.md 9.17; LakeWaves): the same
## Gerstner surface as WaveField (9.4 to 9.7), made of the lake's trains the physics floats on
## (LakeWaves.physics_count, the longest), with two differences.
##   1. Each train's amplitude comes from the lake's grid, read at the asked point between the four
##      nearest nodes (bilinear), and its steepness is the physical one, k·A (at most pi/7). The
##      lengths, directions and phases are the same over the whole lake.
##   2. Each train has its own phase at the origin (LakeWaves._phase_of()).
## The heights change slowly next to a wavelength (nodes 16 m apart), so within one query the
## amplitudes of the asked point are used for the whole solve for the rest point and for the
## answers: the rest point lies at most the sum of the amplitudes (some 0.3 m) away, where the
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


func _init(lake_waves: LakeWaves, water_config: WaterConfig = null) -> void:
	super(null, water_config, 0.0)
	lake = lake_waves
	count = lake.physics_count
	for i: int in count:
		var wave_k: float = lake.wave_number[i]
		k.append(wave_k)
		c.append(sqrt(G / wave_k))
		omega.append(sqrt(G * wave_k))
		dir_x.append(lake.dir_x[i])
		dir_z.append(lake.dir_z[i])
		wavelength.append(lake.wavelength_m[i])
		phase.append(lake.phase0[i])
	amplitude.resize(count)
	amplitude.fill(0.0)
	steepness.resize(count)
	steepness.fill(0.0)
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


## Sets the trains' amplitudes and steepness to those at a game position (bilinear between the
## grid's nodes; flat off the grid).
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
		var wave_a: float = lerpf(top, bottom, tz)
		amplitude[i] = wave_a
		steepness[i] = minf(k[i] * wave_a, LakeWaves.MAX_STEEPNESS)


func height_at(x: float, z: float, t: float) -> float:
	amplitudes_for(x, z)
	return super(x, z, t)


func normal_at(x: float, z: float, t: float) -> Vector3:
	amplitudes_for(x, z)
	return super(x, z, t)


func velocity_at(x: float, z: float, t: float) -> Vector3:
	amplitudes_for(x, z)
	return super(x, z, t)


func sample_at(x: float, z: float, time_s: float, samples: PackedFloat64Array, index: int) -> void:
	amplitudes_for(x, z)
	super(x, z, time_s, samples, index)


## As WaveField.displacement_at, with each train's own phase.
func displacement_at(rest_x: float, rest_z: float, t: float) -> Vector3:
	var displacement: Vector3 = Vector3.ZERO
	for i: int in count:
		var wave_phase: float = k[i] * (dir_x[i] * rest_x + dir_z[i] * rest_z) - omega[i] * t + phase[i]
		var horizontal: float = steepness[i] / k[i] * cos(wave_phase)
		displacement.x += dir_x[i] * horizontal
		displacement.z += dir_z[i] * horizontal
		displacement.y += amplitude[i] * sin(wave_phase)
	return displacement


func _sideways_displacement_at(rest_x: float, rest_z: float, t: float) -> Vector2:
	var sideways: Vector2 = Vector2.ZERO
	for i: int in count:
		var wave_k: float = k[i]
		var wave_x: float = dir_x[i]
		var wave_z: float = dir_z[i]
		var wave_phase: float = wave_k * (wave_x * rest_x + wave_z * rest_z) - omega[i] * t + phase[i]
		var horizontal: float = steepness[i] / wave_k * cos(wave_phase)
		sideways.x += wave_x * horizontal
		sideways.y += wave_z * horizontal
	return sideways


func normal_at_rest(rest_x: float, rest_z: float, t: float) -> Vector3:
	var tangent_x: Vector3 = Vector3(1.0, 0.0, 0.0)
	var tangent_z: Vector3 = Vector3(0.0, 0.0, 1.0)
	for i: int in count:
		var wave_phase: float = k[i] * (dir_x[i] * rest_x + dir_z[i] * rest_z) - omega[i] * t + phase[i]
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
	var velocity: Vector3 = Vector3.ZERO
	for i: int in count:
		var wave_phase: float = k[i] * (dir_x[i] * rest_x + dir_z[i] * rest_z) - omega[i] * t + phase[i]
		var forward: float = steepness[i] * c[i] * sin(wave_phase)
		velocity.x += dir_x[i] * forward
		velocity.z += dir_z[i] * forward
		velocity.y -= amplitude[i] * omega[i] * cos(wave_phase)
	return velocity


## As WaveField._answers_at_rest, with each train's own phase.
func _answers_at_rest(x: float, z: float, t: float, rest: Vector2, samples: PackedFloat64Array, index: int) -> void:
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
		var wave_phase: float = wave_k * (wave_x * rest_x + wave_z * rest_z) - wave_omega * t + phase[i]
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
	parameters["lake_waves_on"] = true
	parameters["lake_shape_trains"] = count
	parameters["lake_grid"] = Vector4(_x0_m, _z0_m, _per_cell, 0.0)
	parameters["lake_grid_size"] = Vector2i(_columns, _rows)
	parameters["lake_look_band"] = Vector4(lake.look_dir.x, lake.look_dir.y, lake.look_phase0, lake.config.look_wavelength_m)
	var textures: Dictionary[String, Texture2D] = lake.textures()
	for key: String in textures:
		parameters[key] = textures[key]
	return parameters
