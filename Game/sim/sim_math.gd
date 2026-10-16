class_name SimMath
extends RefCounted
## The handful of formulas every physics model shares: compass bearings, wind angles,
## heading, heel and pitch. All of them follow the conventions of PHYSICS_SPEC.md section 0:
## world +Y up, North = -Z, East = +X; body frame bow = -Z, starboard = +X, up = +Y;
## wind angles positive when the wind comes from starboard.

## One knot in metres per second (1852 m per hour).
const KNOT_MS: float = 1852.0 / 3600.0


## Unit vector pointing TOWARD a compass bearing (0 = North = -Z, 90 = East = +X).
## For the wind this is the direction the wind comes FROM.
static func dir_from_bearing(bearing_rad: float) -> Vector3:
	return Vector3(sin(bearing_rad), 0.0, -cos(bearing_rad))


## Compass bearing of a horizontal direction, in radians, 0 to 2 pi.
static func bearing_from_dir(dir: Vector3) -> float:
	return fposmod(atan2(dir.x, -dir.z), TAU)


## The direction the bow points, in the world frame.
static func forward(basis: Basis) -> Vector3:
	return -basis.z


## Horizontal part of a vector (y set to zero), not normalised.
static func horizontal(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Compass heading of the bow, in radians, 0 to 2 pi (0 = North, pi/2 = East).
static func heading_rad(basis: Basis) -> float:
	var fwd: Vector3 = horizontal(forward(basis))
	if fwd.length_squared() < 1e-12:
		return 0.0
	return bearing_from_dir(fwd)


## Angle between the bow and a horizontal direction the wind (or the water) comes FROM,
## measured in the horizontal plane, positive when it comes from starboard. Used for the
## true wind angle, the apparent wind angle and the fin's slip angle alike. Never use
## signed_angle_to for this: in Godot it is positive toward port (see test_engine_conventions).
static func wind_angle_rad(basis: Basis, from_world: Vector3) -> float:
	var fwd_h: Vector3 = horizontal(forward(basis))
	var from_h: Vector3 = horizontal(from_world)
	if fwd_h.length_squared() < 1e-12 or from_h.length_squared() < 1e-12:
		return 0.0
	fwd_h = fwd_h.normalized()
	var right_h: Vector3 = fwd_h.cross(Vector3.UP)
	return atan2(from_h.dot(right_h), from_h.dot(fwd_h))


## Pitch of the board, positive = bow up.
static func pitch_rad(basis: Basis) -> float:
	return asin(clampf(forward(basis).y, -1.0, 1.0))


## Heel of the board, positive = heeled to starboard (starboard rail down).
static func heel_rad(basis: Basis) -> float:
	return atan2(-basis.x.y, basis.y.y)


## Expresses a world vector in the body frame. The basis is orthonormal, so its transpose
## is its inverse.
static func to_body(basis: Basis, v_world: Vector3) -> Vector3:
	return basis.transposed() * v_world


## Expresses a body vector in the world frame.
static func to_world(basis: Basis, v_body: Vector3) -> Vector3:
	return basis * v_body


## Slip (leeway) angle of a body-frame velocity: positive when sliding toward starboard.
static func slip_angle_rad(v_body: Vector3) -> float:
	if v_body.x * v_body.x + v_body.z * v_body.z < 1e-12:
		return 0.0
	return atan2(v_body.x, -v_body.z)


## Wraps an angle to the range -pi .. pi.
static func wrap_angle(angle_rad: float) -> float:
	return wrapf(angle_rad, -PI, PI)
