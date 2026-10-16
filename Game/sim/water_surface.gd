class_name WaterSurface
extends RefCounted
## What the physics asks the water: how high is the surface here, which way does it tilt,
## and how fast is the water moving (PHYSICS_SPEC.md section 9). Flat water answers with
## constants; Phase 5 replaces this with Gerstner waves without touching the models.
## Time is passed in by the caller (architecture rule 1).


## Height of the surface at a world (x, z).
func height_at(_x: float, _z: float, _time_s: float) -> float:
	return 0.0


## Unit normal of the surface, pointing up out of the water.
func normal_at(_x: float, _z: float, _time_s: float) -> Vector3:
	return Vector3.UP


## Velocity of the water at the surface (orbital velocity under waves, zero on flat water).
func velocity_at(_x: float, _z: float, _time_s: float) -> Vector3:
	return Vector3.ZERO


## How far below the surface a world point is (negative = in the air).
func depth_at(point: Vector3, time_s: float) -> float:
	return height_at(point.x, point.z, time_s) - point.y
