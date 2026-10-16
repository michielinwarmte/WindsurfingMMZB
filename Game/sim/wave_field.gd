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


## wind_from_bearing_deg: the base wind's compass bearing, which orients the set when it
## is aligned to the wind (never the gust or shift term: changing directions while the
## game runs makes the whole surface jump, 9.12).
func _init(wave_set: WaveSetConfig, water_config: WaterConfig = null, wind_from_bearing_deg: float = 0.0) -> void:
	config = wave_set
	if water_config != null:
		base_height_m = water_config.base_height_m
	set_wind_bearing(wind_from_bearing_deg)


## Computes the derived values from the config and the base wind bearing.
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
	var base_bearing_deg: float = wind_from_bearing_deg + 180.0 if config.align_to_wind else 0.0
	for wave: GerstnerWaveConfig in config.active_waves():
		var wave_k: float = wave.wave_number()
		var direction: Vector2 = direction_for_bearing(base_bearing_deg + wave.direction_offset_deg)
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
	var rest: Vector2 = Vector2(x, z)
	if count == 0:
		return rest
	for i: int in SOLVE_MAX_ITERATIONS:
		var displacement: Vector3 = displacement_at(rest.x, rest.y, t)
		var next: Vector2 = Vector2(x - displacement.x, z - displacement.z)
		var moved: float = next.distance_to(rest)
		rest = next
		if moved < SOLVE_TOLERANCE_M:
			break
	return rest


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
