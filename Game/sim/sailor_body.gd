class_name SailorBody
extends RefCounted
## The sailor as a body of their own (PHYSICS_SPEC.md section 7.5): a point mass at the
## sailor's centre of mass. The board carries the feet; the legs (see WindsurferSim) carry
## the weight and the pull of the sail into the board and give under a jolt. No Nodes; the
## simulation integrates it with the hull in the same substeps, with semi-implicit Euler.

var mass_kg: float = 75.0
## Centre of mass in the world frame.
var position: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
## The acceleration of the last integrate(), world frame: what the sense of balance feels.
var acceleration: Vector3 = Vector3.ZERO

var _force_sum: Vector3 = Vector3.ZERO


## A force on the body, world frame. A point mass has no lever arms: where it acts does
## not matter here (the moments the body passes to the board are worked out by the
## simulation from where the hands and the feet are).
func add_force(force: Vector3) -> void:
	_force_sum += force


func force_sum() -> Vector3:
	return _force_sum


## The acceleration the forces collected so far would give.
func acceleration_now() -> Vector3:
	return _force_sum / mass_kg


## Puts the body somewhere at a velocity, forgetting any forces collected.
func place(new_position: Vector3, new_velocity: Vector3) -> void:
	position = new_position
	velocity = new_velocity
	acceleration = Vector3.ZERO
	_force_sum = Vector3.ZERO


## Moves the body across the deck with the hull: its horizontal position and speed are set,
## the vertical ones kept (WindsurferSim._ride_the_hull). A method rather than writing the
## fields from outside: writing another object's field takes a global engine lock on worker
## threads, a method call does not (F1 no_wait, WindsurferSim).
func ride(position_x: float, position_z: float, velocity_x: float, velocity_z: float) -> void:
	position.x = position_x
	position.z = position_z
	velocity.x = velocity_x
	velocity.z = velocity_z


## Advances by dt seconds and clears the forces: the velocity first, then the position
## with the new velocity, which keeps the leg spring from gaining energy.
func integrate(dt: float) -> void:
	acceleration = _force_sum / mass_kg
	velocity += acceleration * dt
	position += velocity * dt
	_force_sum = Vector3.ZERO
