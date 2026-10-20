class_name WaveField
extends WaterSurface
## The water surface as a sum of Gerstner waves (PHYSICS_SPEC.md section 9). Every point
## of the surface moves on a circle: up and down by the amplitude, and along the travel
## direction by steepness / wave number, which gives the pointed crests and flat troughs
## of real waves. The same formulas are in res://world/water.gdshader (plan decision D5):
## change one, change the other.
##
## Because the surface points also move sideways, the height at a world point is found by
## a fixed-point solve for the rest point that ended up there (9.5). The normal (9.6a) and
## the orbital velocity (9.7) are evaluated at that rest point.

const G: float = 9.81
## The solve stops when the rest point moves less than this (m), or after the cap.
const SOLVE_TOLERANCE_M: float = 0.001
const SOLVE_MAX_ITERATIONS: int = 8

var config: WaveSetConfig
var base_height_m: float = 0.0
## Derived per active wave (9.1, 9.2): wave number, angular frequency, phase speed, the
## amplitude, the steepness and the unit travel direction (x, z).
var count: int = 0
var k: PackedFloat64Array = PackedFloat64Array()
var omega: PackedFloat64Array = PackedFloat64Array()
var c: PackedFloat64Array = PackedFloat64Array()
var amplitude: PackedFloat64Array = PackedFloat64Array()
var steepness: PackedFloat64Array = PackedFloat64Array()
var dir_x: PackedFloat64Array = PackedFloat64Array()
var dir_z: PackedFloat64Array = PackedFloat64Array()
var wavelength: PackedFloat64Array = PackedFloat64Array()


## wind_from_bearing_deg: the base wind's compass bearing, which orients the chop, and the
## swell when it is relative to the wind (never the gust or shift term: changing
## directions while the game runs makes the whole surface jump, 9.12).
func _init(wave_set: WaveSetConfig, water_config: WaterConfig = null, wind_from_bearing_deg: float = 0.0) -> void:
	config = wave_set
	if water_config != null:
		base_height_m = water_config.base_height_m
	set_wind_bearing(wind_from_bearing_deg)


## Computes the derived values from the config and the base wind bearing. A new wind
## direction turns the chop, and the swell only when it is relative to the wind: a swell
## from a compass bearing stays where it is (9.15).
func set_wind_bearing(wind_from_bearing_deg: float) -> void:
	k.clear()
	omega.clear()
	c.clear()
	amplitude.clear()
	steepness.clear()
	dir_x.clear()
	dir_z.clear()
	wavelength.clear()
	count = 0
	if config == null or not config.enable_waves:
		return
	for wave: GerstnerWaveConfig in config.active_waves():
		var wave_k: float = wave.wave_number()
		var direction: Vector2 = direction_for_bearing(config.travel_bearing_deg(wave, wind_from_bearing_deg))
		k.append(wave_k)
		c.append(sqrt(G / wave_k))
		omega.append(sqrt(G * wave_k))
		amplitude.append(wave.amplitude_m)
		steepness.append(wave.steepness)
		dir_x.append(direction.x)
		dir_z.append(direction.y)
		wavelength.append(maxf(wave.wavelength_m, 0.5))
		count += 1


## A compass bearing as a unit vector in the horizontal plane, (x, z): North is (0, -1)
## because North is world -Z (plan decision D4), East (1, 0). Never build this by rotating
## a vector about +Y: that flips the sign of the offset in Godot (9.2).
static func direction_for_bearing(bearing_deg: float) -> Vector2:
	var bearing: float = deg_to_rad(bearing_deg)
	return Vector2(sin(bearing), -cos(bearing))


## Period of wave i, seconds.
func period_s(i: int) -> float:
	return TAU / omega[i]


## Where the surface point whose rest position is (rest_x, rest_z) is at time t, relative
## to the rest position and the still level: (dx, dy, dz) (9.4).
func displacement_at(rest_x: float, rest_z: float, t: float) -> Vector3:
	var displacement: Vector3 = Vector3.ZERO
	for i: int in count:
		var phase: float = k[i] * (dir_x[i] * rest_x + dir_z[i] * rest_z) - omega[i] * t
		var horizontal: float = steepness[i] / k[i] * cos(phase)
		displacement.x += dir_x[i] * horizontal
		displacement.z += dir_z[i] * horizontal
		displacement.y += amplitude[i] * sin(phase)
	return displacement


## The rest point whose surface point is at world (x, z) now: the fixed-point solve of
## 9.5. With a total steepness below 1 each pass shrinks the error by at least that
## factor; the default set needs about six passes for a millimetre.
func rest_point_at(x: float, z: float, t: float) -> Vector2:
	return rest_point_from(x, z, t, Vector2(x, z))


## The solve of rest_point_at started from a guess instead of from (x, z) itself: the same
## passes, the same tolerance and the same cap. A guess near the answer needs fewer passes,
## and where the solve stops the answer is as close to the exact rest point as
## rest_point_at's: the last pass moved it less than the solver's millimetre.
func rest_point_from(x: float, z: float, t: float, start: Vector2) -> Vector2:
	if count == 0:
		return Vector2(x, z)
	var rest: Vector2 = start
	for i: int in SOLVE_MAX_ITERATIONS:
		var sideways: Vector2 = _sideways_displacement_at(rest.x, rest.y, t)
		var next: Vector2 = Vector2(x - sideways.x, z - sideways.y)
		var moved: float = next.distance_to(rest)
		rest = next
		if moved < SOLVE_TOLERANCE_M:
			break
	return rest


## The sideways part (x, z) of displacement_at, all a pass of the solve needs: the same
## sums in the same order without the height's sine. Vector2 holds 32-bit floats as Vector3
## does, so the sums are rounded the same way and the rest point is the same to the last bit.
func _sideways_displacement_at(rest_x: float, rest_z: float, t: float) -> Vector2:
	var sideways: Vector2 = Vector2.ZERO
	for i: int in count:
		var wave_k: float = k[i]
		var wave_x: float = dir_x[i]
		var wave_z: float = dir_z[i]
		var phase: float = wave_k * (wave_x * rest_x + wave_z * rest_z) - omega[i] * t
		var horizontal: float = steepness[i] / wave_k * cos(phase)
		sideways.x += wave_x * horizontal
		sideways.y += wave_z * horizontal
	return sideways


func height_at(x: float, z: float, t: float) -> float:
	if count == 0:
		return base_height_m
	var rest: Vector2 = rest_point_at(x, z, t)
	return base_height_m + displacement_at(rest.x, rest.y, t).y


func normal_at(x: float, z: float, t: float) -> Vector3:
	if count == 0:
		return Vector3.UP
	var rest: Vector2 = rest_point_at(x, z, t)
	return normal_at_rest(rest.x, rest.y, t)


## The exact normal of the displaced surface at a rest point: the cross product of the
## two tangent vectors of 9.4 (9.6a). Flat water gives (0, 1, 0).
func normal_at_rest(rest_x: float, rest_z: float, t: float) -> Vector3:
	var tangent_x: Vector3 = Vector3(1.0, 0.0, 0.0)
	var tangent_z: Vector3 = Vector3(0.0, 0.0, 1.0)
	for i: int in count:
		var phase: float = k[i] * (dir_x[i] * rest_x + dir_z[i] * rest_z) - omega[i] * t
		var sin_phase: float = sin(phase)
		var cos_phase: float = cos(phase)
		tangent_x.x -= dir_x[i] * dir_x[i] * steepness[i] * sin_phase
		tangent_x.y += amplitude[i] * k[i] * dir_x[i] * cos_phase
		tangent_x.z -= dir_x[i] * dir_z[i] * steepness[i] * sin_phase
		tangent_z.x -= dir_x[i] * dir_z[i] * steepness[i] * sin_phase
		tangent_z.y += amplitude[i] * k[i] * dir_z[i] * cos_phase
		tangent_z.z -= dir_z[i] * dir_z[i] * steepness[i] * sin_phase
	return tangent_z.cross(tangent_x).normalized()


func velocity_at(x: float, z: float, t: float) -> Vector3:
	if count == 0:
		return Vector3.ZERO
	var rest: Vector2 = rest_point_at(x, z, t)
	return velocity_at_rest(rest.x, rest.y, t)


## The velocity of the surface at a rest point: the time derivative of 9.4 (9.7). On a
## crest the water moves forward with the wave at steepness x phase speed, in the trough
## backward, on the front face up. With a physical steepness (k A) the forward speed is
## the orbital speed A omega of a real wave.
func velocity_at_rest(rest_x: float, rest_z: float, t: float) -> Vector3:
	var velocity: Vector3 = Vector3.ZERO
	for i: int in count:
		var phase: float = k[i] * (dir_x[i] * rest_x + dir_z[i] * rest_z) - omega[i] * t
		var forward: float = steepness[i] * c[i] * sin(phase)
		velocity.x += dir_x[i] * forward
		velocity.z += dir_z[i] * forward
		velocity.y -= amplitude[i] * omega[i] * cos(phase)
	return velocity


## The height, the normal and the velocity at a world (x, z) at once (WaterSurface.Sample):
## one solve for the rest point and one pass over the waves, where height_at, normal_at and
## velocity_at take a solve and a pass each. Started cold (a new or forgotten sample) the
## solve starts at (x, z), as theirs does, and the answers are theirs to the last bit.
##
## Started warm (the sample holds the answer at the same point of the hull a substep ago):
## the surface point now at (x, z) has been carried sideways by nearly the same amount as
## the one found then, a few centimetres away and a fraction of a second earlier. So the
## search starts at (x, z) less that displacement, within a few millimetres of the answer,
## and one or two passes reach the solver's millimetre instead of three. The answer is the
## same within the solver's millimetre (9.5): it can differ from the cold one by a small
## part of a millimetre in the rest point, a few micrometres in the height.
func sample_at(x: float, z: float, time_s: float, sample: WaterSurface.Sample) -> void:
	var start: Vector2 = Vector2(x, z)
	if sample.is_set:
		start = Vector2(x - (sample.x - sample.rest_x), z - (sample.z - sample.rest_z))
	var rest: Vector2 = rest_point_from(x, z, time_s, start)
	sample.x = x
	sample.z = z
	sample.time_s = time_s
	sample.rest_x = rest.x
	sample.rest_z = rest.y
	sample.is_set = true
	if count == 0:
		sample.height_m = base_height_m
		sample.normal = Vector3.UP
		sample.velocity_ms = Vector3.ZERO
		return
	_answers_at_rest(rest.x, rest.y, time_s, sample)


## The height (9.4), the normal (9.6a) and the velocity (9.7) at a rest point in one pass
## over the waves: the formulas of displacement_at, normal_at_rest and velocity_at_rest,
## with each wave's sine and cosine computed once for all three, and its numbers read from
## the arrays once (reading an array costs GDScript more than the arithmetic). The products
## are the same in the same order, and the sums are kept in Vector3s as those functions keep
## them, so they are rounded the same way and the answers are the same to the last bit.
func _answers_at_rest(rest_x: float, rest_z: float, t: float, sample: WaterSurface.Sample) -> void:
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
		var phase: float = wave_k * (wave_x * rest_x + wave_z * rest_z) - wave_omega * t
		var sin_phase: float = sin(phase)
		var cos_phase: float = cos(phase)
		# The height of the surface point (displacement_at).
		displacement.y += wave_a * sin_phase
		# The two tangents of the displaced surface (normal_at_rest); the cross term is the
		# same in both.
		var cross_term: float = wave_x * wave_z * wave_s * sin_phase
		tangent_x.x -= wave_x * wave_x * wave_s * sin_phase
		tangent_x.y += wave_a * wave_k * wave_x * cos_phase
		tangent_x.z -= cross_term
		tangent_z.x -= cross_term
		tangent_z.y += wave_a * wave_k * wave_z * cos_phase
		tangent_z.z -= wave_z * wave_z * wave_s * sin_phase
		# The velocity of the surface point (velocity_at_rest).
		var forward: float = wave_s * c[i] * sin_phase
		velocity.x += wave_x * forward
		velocity.z += wave_z * forward
		velocity.y -= wave_a * wave_omega * cos_phase
	sample.height_m = base_height_m + displacement.y
	sample.normal = tangent_z.cross(tangent_x).normalized()
	sample.velocity_ms = velocity


## The largest height above the still level the set can reach.
func total_amplitude_m() -> float:
	var total: float = 0.0
	for i: int in count:
		total += amplitude[i]
	return total


## The wave set as the shader wants it (9.13): wave_a to wave_d are (direction x,
## direction z, steepness, wavelength), wave_amplitudes the four amplitudes (0 = an empty
## slot), so the shader never converts bearings itself.
func shader_parameters() -> Dictionary[String, Variant]:
	var parameters: Dictionary[String, Variant] = {}
	var names: Array[String] = ["wave_a", "wave_b", "wave_c", "wave_d"]
	var amplitudes: Vector4 = Vector4.ZERO
	for slot: int in WaveSetConfig.MAX_WAVES:
		if slot < count:
			parameters[names[slot]] = Vector4(dir_x[slot], dir_z[slot], steepness[slot], wavelength[slot])
			amplitudes[slot] = amplitude[slot]
		else:
			parameters[names[slot]] = Vector4(0.0, -1.0, 0.0, 10.0)
	parameters["wave_amplitudes"] = amplitudes
	parameters["base_height_m"] = base_height_m
	return parameters
