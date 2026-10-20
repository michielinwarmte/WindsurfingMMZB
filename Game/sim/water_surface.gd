class_name WaterSurface
extends RefCounted
## What the physics asks the water: how high is the surface here, which way does it tilt,
## and how fast is the water moving (PHYSICS_SPEC.md section 9). Flat water answers with
## constants; Phase 5 replaces this with Gerstner waves without touching the models.
## Time is passed in by the caller (architecture rule 1).

## sample_at() gives all three answers at once and writes them into a record of numbers in a
## PackedFloat64Array the caller keeps, one record of SAMPLE_SIZE numbers per point it asks
## (point i's record starts at i * SAMPLE_SIZE). The numbers in a record, by their place:
const SAMPLE_X: int = 0  # the question: the world point (x, z) and the time
const SAMPLE_Z: int = 1
const SAMPLE_TIME_S: int = 2
const SAMPLE_IS_SET: int = 3  # 1 once the record holds an answer, 0 when it is forgotten
const SAMPLE_REST_X: int = 4  # the rest point the answers belong to (9.5)
const SAMPLE_REST_Z: int = 5
const SAMPLE_HEIGHT_M: int = 6  # the answers: the height of the surface,
const SAMPLE_NORMAL: int = 7  # its unit normal (x, y, z),
const SAMPLE_VELOCITY_MS: int = 10  # and the velocity of the water (x, y, z)
const SAMPLE_SIZE: int = 13
# Why numbers and not an object per point: when GDScript reads a field of another object, or
# hands an object to a typed parameter, the engine looks the object up in its global table
# under a lock, and boards stepped side by side on threads wait for each other there (eight
# boards ran twice as slowly with an object per point, F1). A packed array passes for free.


## Height of the surface at a world (x, z).
func height_at(_x: float, _z: float, _time_s: float) -> float:
	return 0.0


## Unit normal of the surface, pointing up out of the water.
func normal_at(_x: float, _z: float, _time_s: float) -> Vector3:
	return Vector3.UP


## Velocity of the water at the surface (orbital velocity under waves, zero on flat water).
func velocity_at(_x: float, _z: float, _time_s: float) -> Vector3:
	return Vector3.ZERO


## The height, the normal and the velocity at a world (x, z) at once, written into record
## `index` of `samples`: the answers the hull asks at each of its points every substep. The
## same answers as the three functions above; a surface that can share the work between them
## does (WaveField: one search for the rest point instead of three, started from the answer
## the record already holds).
func sample_at(x: float, z: float, time_s: float, samples: PackedFloat64Array, index: int) -> void:
	write_sample(samples, index, x, z, time_s, Vector2(x, z), height_at(x, z, time_s), normal_at(x, z, time_s), velocity_at(x, z, time_s))


## Records for this many points, none of them answered yet.
static func new_samples(points: int) -> PackedFloat64Array:
	var samples: PackedFloat64Array = PackedFloat64Array()
	samples.resize(points * SAMPLE_SIZE)
	samples.fill(0.0)
	return samples


## Forgets every answer, so that the next searches start from scratch (a board put somewhere
## new).
static func forget_samples(samples: PackedFloat64Array) -> void:
	for at: int in range(SAMPLE_IS_SET, samples.size(), SAMPLE_SIZE):
		samples[at] = 0.0


## Writes a whole record: the question, the rest point and the answers.
static func write_sample(samples: PackedFloat64Array, index: int, x: float, z: float, time_s: float, rest: Vector2, height_m: float, normal: Vector3, velocity_ms: Vector3) -> void:
	var at: int = index * SAMPLE_SIZE
	samples[at + SAMPLE_X] = x
	samples[at + SAMPLE_Z] = z
	samples[at + SAMPLE_TIME_S] = time_s
	samples[at + SAMPLE_IS_SET] = 1.0
	samples[at + SAMPLE_REST_X] = rest.x
	samples[at + SAMPLE_REST_Z] = rest.y
	samples[at + SAMPLE_HEIGHT_M] = height_m
	samples[at + SAMPLE_NORMAL] = normal.x
	samples[at + SAMPLE_NORMAL + 1] = normal.y
	samples[at + SAMPLE_NORMAL + 2] = normal.z
	samples[at + SAMPLE_VELOCITY_MS] = velocity_ms.x
	samples[at + SAMPLE_VELOCITY_MS + 1] = velocity_ms.y
	samples[at + SAMPLE_VELOCITY_MS + 2] = velocity_ms.z


## Whether record `index` holds an answer.
static func sample_is_set(samples: PackedFloat64Array, index: int) -> bool:
	return samples[index * SAMPLE_SIZE + SAMPLE_IS_SET] > 0.5


## Whether record `index` holds the answer at world (x, z) at this time: the same question,
## asked again in the same substep.
static func sample_answers(samples: PackedFloat64Array, index: int, x: float, z: float, time_s: float) -> bool:
	var at: int = index * SAMPLE_SIZE
	return samples[at + SAMPLE_IS_SET] > 0.5 and samples[at + SAMPLE_X] == x and samples[at + SAMPLE_Z] == z and samples[at + SAMPLE_TIME_S] == time_s


static func sample_height(samples: PackedFloat64Array, index: int) -> float:
	return samples[index * SAMPLE_SIZE + SAMPLE_HEIGHT_M]


## The normal and the velocity are kept as the 32-bit numbers of a Vector3 (a double holds
## them exactly), so they come back out bit for bit.
static func sample_normal(samples: PackedFloat64Array, index: int) -> Vector3:
	var at: int = index * SAMPLE_SIZE + SAMPLE_NORMAL
	return Vector3(samples[at], samples[at + 1], samples[at + 2])


static func sample_velocity(samples: PackedFloat64Array, index: int) -> Vector3:
	var at: int = index * SAMPLE_SIZE + SAMPLE_VELOCITY_MS
	return Vector3(samples[at], samples[at + 1], samples[at + 2])


static func sample_rest_point(samples: PackedFloat64Array, index: int) -> Vector2:
	var at: int = index * SAMPLE_SIZE
	return Vector2(samples[at + SAMPLE_REST_X], samples[at + SAMPLE_REST_Z])


## How far below the surface a world point is (negative = in the air).
func depth_at(point: Vector3, time_s: float) -> float:
	return height_at(point.x, point.z, time_s) - point.y
