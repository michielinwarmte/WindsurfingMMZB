class_name SimRigidBody
extends RefCounted
## A rigid body with six degrees of freedom, integrated by our own code (plan decision D2).
## No Nodes and no engine physics: tests run it headless and the game copies its state
## onto the visuals.
##
## State: the centre of mass (position, velocity), the orientation (a Basis whose columns
## are the body axes in the world frame) and the angular velocity (world frame, rad/s).
## Forces are collected with add_force_at(), which turns a force at a point into a force
## plus a torque about the centre of mass, and integrate() advances one small time step
## with semi-implicit Euler.
##
## The "board origin" (the geometric centre of the hull, where the models measure their
## points) sits at com_offset_body from the centre of mass, in body axes. The sailor moves,
## so the offset changes; set_mass_properties() keeps the board origin still when it does.

var mass_kg: float = 1.0
## Inertia tensor about the centre of mass, in body axes.
var inertia_body: Basis = Basis.IDENTITY
var inertia_body_inv: Basis = Basis.IDENTITY
## Centre of mass in the world frame.
var position: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
## Body axes in the world frame: basis.x = starboard, basis.y = up, -basis.z = bow.
var basis: Basis = Basis.IDENTITY
## Angular velocity in the world frame.
var angular_velocity: Vector3 = Vector3.ZERO
## Centre of mass relative to the board origin, in body axes.
var com_offset_body: Vector3 = Vector3.ZERO
## Velocity of the board structure relative to the centre of mass, in the world frame, when
## a part of the body moves inside it (the sailor's legs flexing). Zero for a rigid body.
var internal_velocity: Vector3 = Vector3.ZERO
## Water that has to move with the hull when the hull moves along its own up axis (the heave
## added mass of the wetted bottom). It resists acceleration along that axis only; the hull
## model sets it every step.
var added_mass_up_kg: float = 0.0
## Mass that moves with the body along its own x and z axes (across and along the deck)
## but not up and down: the sailor, who rides the hull in the horizontal plane on legs that
## give vertically (WindsurferSim). The simulation sets it.
var added_mass_across_kg: float = 0.0
## Water that moves with the hull when it moves sideways (along its own x axis only): the
## sway added mass of the immersed hull sides and of the fin. The simulation sets it.
var added_mass_sway_kg: float = 0.0

var _force_sum: Vector3 = Vector3.ZERO
var _torque_sum: Vector3 = Vector3.ZERO


## keep_centre_of_mass = false: the board stays where it is and the centre of mass moves
## inside it (a sailor slowly shifting their weight). true: the centre of mass stays on its
## path and the board shifts instead (a fast internal motion, where momentum must be kept).
func set_mass_properties(new_mass_kg: float, new_inertia_body: Basis, new_com_offset_body: Vector3, keep_centre_of_mass: bool = false) -> void:
	if not keep_centre_of_mass:
		position += basis * (new_com_offset_body - com_offset_body)
	com_offset_body = new_com_offset_body
	mass_kg = new_mass_kg
	inertia_body = new_inertia_body
	inertia_body_inv = new_inertia_body.inverse()


## Water taken along keeps its momentum with the hull: when the water that moves with the
## hull grows (the wet bottom lengthens as the hull settles, a wave meets it), the hull's
## momentum along that axis is shared with it and the hull slows, which is the slam of a
## hull meeting water. Water left behind keeps its own momentum and gives none back, so
## nothing changes when the added mass or inertia falls. Without this the hull kept its
## angular velocity while its pitch inertia tripled on every immersion, and the energy
## that put in drove a planing hull into porpoising. Call before setting the new values.
func take_water_along(new_added_mass_up_kg: float, new_inertia_body: Basis) -> void:
	if new_added_mass_up_kg > added_mass_up_kg:
		var up: Vector3 = basis.y
		var v_up: float = velocity.dot(up)
		velocity += up * (v_up * ((mass_kg + added_mass_up_kg) / (mass_kg + new_added_mass_up_kg) - 1.0))
	var omega_body: Vector3 = angular_velocity_body()
	var changed: bool = false
	for i: int in 3:
		var old_i: float = inertia_body[i][i]
		var new_i: float = new_inertia_body[i][i]
		if new_i > old_i and old_i > 0.0:
			omega_body[i] *= old_i / new_i
			changed = true
	if changed:
		angular_velocity = basis * omega_body


## The same for the water taken along sideways (added_mass_sway_kg): when more of the hull
## side goes under (a landing), the sideways momentum is shared with that water. Call
## before setting the new value.
func take_water_along_sideways(new_added_mass_sway_kg: float) -> void:
	if new_added_mass_sway_kg <= added_mass_sway_kg:
		return
	var across: Vector3 = basis.x
	var v_across: float = velocity.dot(across)
	var before: float = mass_kg + added_mass_across_kg + added_mass_sway_kg
	var after: float = mass_kg + added_mass_across_kg + new_added_mass_sway_kg
	velocity += across * (v_across * (before / after - 1.0))


## World position of the board origin.
func origin_world() -> Vector3:
	return position - basis * com_offset_body


## Places the board origin at a world position (the centre of mass follows).
func set_origin_world(origin: Vector3) -> void:
	position = origin + basis * com_offset_body


## World position of a point given in body axes relative to the board origin.
func point_world(point_body: Vector3) -> Vector3:
	return origin_world() + basis * point_body


## Velocity of a world point that moves with the body.
func point_velocity(point: Vector3) -> Vector3:
	return velocity + internal_velocity + angular_velocity.cross(point - position)


## Acceleration a point of the body is about to get from the forces collected so far,
## as if the body were rigid: linear, angular and centripetal parts.
func acceleration_at(point: Vector3) -> Vector3:
	var r: Vector3 = point - position
	return linear_acceleration() + angular_acceleration().cross(r) + angular_velocity.cross(angular_velocity.cross(r))


## Angular acceleration (world frame) from the torques collected so far.
func angular_acceleration() -> Vector3:
	var inertia_world: Basis = basis * inertia_body * basis.transposed()
	var gyroscopic: Vector3 = angular_velocity.cross(inertia_world * angular_velocity)
	return inertia_world.inverse() * (_torque_sum - gyroscopic)


## Acceleration of the centre of mass from the forces collected so far. Along the body's up
## axis the water's added mass is accelerated too, and across the deck the sailor's, so
## those directions respond more slowly: in body axes a_i = F_i / (m + added_i).
func linear_acceleration() -> Vector3:
	var force_body: Vector3 = basis.transposed() * _force_sum
	return basis * (force_body * _inverse_mass_body())


## 1 / (m + added) along each body axis.
func _inverse_mass_body() -> Vector3:
	return Vector3(1.0 / (mass_kg + added_mass_across_kg + added_mass_sway_kg), 1.0 / (mass_kg + added_mass_up_kg), 1.0 / (mass_kg + added_mass_across_kg))


## Angular velocity expressed in body axes (x = pitch, y = yaw, z = roll).
func angular_velocity_body() -> Vector3:
	return basis.transposed() * angular_velocity


## The mass a force at a world point along a unit direction has to accelerate: the whole
## body in translation plus what the lever arm lets it rotate, 1 / m_eff = 1 / m +
## (r x n) . I^-1 (r x n). A rail far from the centre of a light board is "light" (easy to
## push), the centre of a heavy one is not. Dampers use it to know how much momentum a
## point really has (see BuoyancyModel and the rig-in-water drag).
func effective_mass_at(point: Vector3, direction: Vector3) -> float:
	var n_body: Vector3 = basis.transposed() * direction
	var inverse: Vector3 = _inverse_mass_body()
	var translational: float = n_body.x * n_body.x * inverse.x + n_body.y * n_body.y * inverse.y + n_body.z * n_body.z * inverse.z
	var r_cross_n: Vector3 = (point - position).cross(direction)
	var inertia_world_inv: Basis = basis * inertia_body_inv * basis.transposed()
	var rotational: float = r_cross_n.dot(inertia_world_inv * r_cross_n)
	return 1.0 / maxf(translational + rotational, 1e-9)


## How much a unit force along v at world point `at` accelerates world point `of` along
## u: the translational part along each body axis plus what the lever arms let it rotate,
## (r_of x u) . I^-1 (r_at x v). The mobility between two points; mobility(p, p, n, n)
## is 1 / effective_mass_at(p, n).
func mobility(of: Vector3, at: Vector3, u: Vector3, v: Vector3) -> float:
	var u_body: Vector3 = basis.transposed() * u
	var v_body: Vector3 = basis.transposed() * v
	var inverse: Vector3 = _inverse_mass_body()
	var translational: float = u_body.x * v_body.x * inverse.x + u_body.y * v_body.y * inverse.y + u_body.z * v_body.z * inverse.z
	var inertia_world_inv: Basis = basis * inertia_body_inv * basis.transposed()
	return translational + (of - position).cross(u).dot(inertia_world_inv * ((at - position).cross(v)))


## A force (world frame) acting at a world point. The torque about the centre of mass
## follows from the lever arm; nothing else decides which way the body turns.
## The torque collected so far this step (world), about the centre of mass.
func torque_sum() -> Vector3:
	return _torque_sum


func add_force_at(point: Vector3, force: Vector3) -> void:
	_force_sum += force
	_torque_sum += (point - position).cross(force)


## A force through the centre of mass (gravity): no torque.
func add_force(force: Vector3) -> void:
	_force_sum += force


## A pure torque (world frame). The physics models never need this; tests may.
func add_torque(torque: Vector3) -> void:
	_torque_sum += torque


func clear_forces() -> void:
	_force_sum = Vector3.ZERO
	_torque_sum = Vector3.ZERO


## Advances the state by dt seconds and clears the accumulated forces.
## Semi-implicit Euler: the velocity is updated first and the new velocity moves the position,
## which keeps oscillating systems (buoyancy) from gaining energy.
func integrate(dt: float) -> void:
	velocity += linear_acceleration() * dt
	position += velocity * dt

	# Rotation: I_world = B * I_body * B^T. The gyroscopic term omega x (I omega) is what
	# makes a tumbling body wobble; it is tiny for a windsurfer but costs nothing.
	var inertia_world: Basis = basis * inertia_body * basis.transposed()
	var inertia_world_inv: Basis = basis * inertia_body_inv * basis.transposed()
	var gyroscopic: Vector3 = angular_velocity.cross(inertia_world * angular_velocity)
	var angular_acceleration: Vector3 = inertia_world_inv * (_torque_sum - gyroscopic)
	angular_velocity += angular_acceleration * dt

	var angle: float = angular_velocity.length() * dt
	if angle > 1e-12:
		basis = Basis(angular_velocity / angular_velocity.length(), angle) * basis
	basis = basis.orthonormalized()

	clear_forces()


## Angular momentum about the centre of mass, world frame. Conserved without torques.
func angular_momentum() -> Vector3:
	var inertia_world: Basis = basis * inertia_body * basis.transposed()
	return inertia_world * angular_velocity


## Kinetic energy, for tests and telemetry.
func kinetic_energy() -> float:
	var omega_body: Vector3 = angular_velocity_body()
	return 0.5 * mass_kg * velocity.length_squared() + 0.5 * omega_body.dot(inertia_body * omega_body)
