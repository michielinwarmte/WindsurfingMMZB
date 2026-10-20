class_name WaterSurface
extends RefCounted
## What the physics asks the water: how high is the surface here, which way does it tilt,
## and how fast is the water moving (PHYSICS_SPEC.md section 9). Flat water answers with
## constants; Phase 5 replaces this with Gerstner waves without touching the models.
## Time is passed in by the caller (architecture rule 1).


## The water at one world point at one time: the three answers of the functions below, as
## sample_at() fills them in. The hull asks all three at its points every substep, and on
## waves each answer starts with the same search for the rest point (9.5), so asking once
## for all three is about three times cheaper. A model keeps one Sample per point it asks,
## so nothing is allocated per call, and the answer a Sample holds from the substep before
## is where a wave surface starts its next search (WaveField.sample_at).
class Sample:
	## The question: the world point (x, z) and the time.
	var x: float = 0.0
	var z: float = 0.0
	var time_s: float = 0.0
	## The answers: the height of the surface, its unit normal (up out of the water) and the
	## velocity of the water there.
	var height_m: float = 0.0
	var normal: Vector3 = Vector3.UP
	var velocity_ms: Vector3 = Vector3.ZERO
	## The rest point the answers belong to: where the surface point now at (x, z) started
	## (9.5); on flat water (x, z) itself.
	var rest_x: float = 0.0
	var rest_z: float = 0.0
	## False until the first answer, and again after forget().
	var is_set: bool = false

	## Drops the answer, so that the next search starts from scratch (a board put somewhere
	## else, a new run).
	func forget() -> void:
		is_set = false

	## Whether this holds the answer at world (x, z) at this time: the same question, asked
	## again in the same substep.
	func answers(at_x: float, at_z: float, at_time_s: float) -> bool:
		return is_set and at_x == x and at_z == z and at_time_s == time_s


## Height of the surface at a world (x, z).
func height_at(_x: float, _z: float, _time_s: float) -> float:
	return 0.0


## Unit normal of the surface, pointing up out of the water.
func normal_at(_x: float, _z: float, _time_s: float) -> Vector3:
	return Vector3.UP


## Velocity of the water at the surface (orbital velocity under waves, zero on flat water).
func velocity_at(_x: float, _z: float, _time_s: float) -> Vector3:
	return Vector3.ZERO


## The height, the normal and the velocity at a world (x, z) at once, written into `sample`
## (see Sample). The same answers as the three functions above; a surface that can share
## the work between them (WaveField) does so.
func sample_at(x: float, z: float, time_s: float, sample: Sample) -> void:
	sample.x = x
	sample.z = z
	sample.time_s = time_s
	sample.height_m = height_at(x, z, time_s)
	sample.normal = normal_at(x, z, time_s)
	sample.velocity_ms = velocity_at(x, z, time_s)
	sample.rest_x = x
	sample.rest_z = z
	sample.is_set = true


## How far below the surface a world point is (negative = in the air).
func depth_at(point: Vector3, time_s: float) -> float:
	return height_at(point.x, point.z, time_s) - point.y
