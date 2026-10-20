class_name RigFrame
extends RefCounted
## Where the rig is and which way it points. The mast foot is a joint on the hull: it
## carries the rig's position but passes no moment, so the rig's orientation is whatever
## the mast foot and the sailor's hands make it. The hands hold the boom still, and the
## mast foot sits on the hull's roll axis, so the rig does not roll with the hull: it is
## upright in the world, leaned sideways only as the controls ask. In pitch it goes with
## the hull: the mast foot is a metre forward of the hull's centre and rises and falls with
## the bow, which tips the rig the hands hold. A rig fixed to the deck in every axis swung
## its centre of effort at metres per second when the light hull snapped upright, the
## apparent wind at the sail jumped by 15 degrees from one step to the next and the sail's
## force with it, which spun the board at a tack's entry (PHYSICS_SPEC.md 7.5). The sail
## model takes its positions, velocities and axes from here; tests of the sail alone pin
## the rig to the hull with rigid_on().

## The rig's axes (x starboard, y up the unleaned mast, z aft), world.
var basis: Basis = Basis.IDENTITY
## The hull's centre of mass (world), for moments about it.
var position: Vector3 = Vector3.ZERO
## The mast foot: on the hull (body axes), in the world, and how fast it moves.
var foot_local: Vector3 = Vector3.ZERO
var foot_world: Vector3 = Vector3.ZERO
var foot_velocity: Vector3 = Vector3.ZERO
## How the rig turns (world): the hull's yaw and pitch rates, not its roll rate.
var angular_velocity: Vector3 = Vector3.ZERO


## Places the rig on the hull's mast foot, held in the given axes and turning at the
## given rate.
func hold_on_hull(body: SimRigidBody, mast_foot_local: Vector3, held_basis: Basis, held_angular_velocity: Vector3) -> void:
	basis = held_basis
	position = body.position
	foot_local = mast_foot_local
	foot_world = body.point_world(mast_foot_local)
	foot_velocity = body.point_velocity(foot_world)
	angular_velocity = held_angular_velocity


## A rig fixed to the hull, moving with it in every axis (for tests of the sail alone).
static func rigid_on(body: SimRigidBody, mast_foot_local: Vector3) -> RigFrame:
	var frame: RigFrame = RigFrame.new()
	frame.hold_on_hull(body, mast_foot_local, body.basis, body.angular_velocity)
	return frame


## A point given in the rig's axes relative to the hull's origin (as the sail's geometry
## is), in the world: measured from the mast foot along the rig's axes.
func point_world(local: Vector3) -> Vector3:
	return foot_world + basis * (local - foot_local)


## The velocity of a world point that moves with the rig.
func point_velocity(point: Vector3) -> Vector3:
	return foot_velocity + angular_velocity.cross(point - foot_world)


## The sail's axis questions, without handing the Basis over: every Basis a GDScript function
## takes as a parameter or keeps in a local variable comes from one engine-wide pool under a
## lock, and boards on threads wait for each other there (F1 no_wait, SimRigidBody). The same
## arithmetic as SimMath's functions of the basis.
## A vector in the rig's axes, in the world: basis * v (SimMath.to_world(basis, v)).
func to_world(v_rig: Vector3) -> Vector3:
	return basis * v_rig


## A world vector in the rig's axes: SimMath.to_body(basis, v_world).
func to_body(v_world: Vector3) -> Vector3:
	return v_world * basis


## The direction the rig's bow points (the board's heading), world: SimMath.forward(basis).
func forward() -> Vector3:
	return -basis.z


## SimMath.wind_angle_rad(basis, from_world).
func wind_angle_rad(from_world: Vector3) -> float:
	return SimMath.wind_angle_rad_of_bow(-basis.z, from_world)
