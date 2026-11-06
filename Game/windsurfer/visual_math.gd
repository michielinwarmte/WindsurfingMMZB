class_name VisualMath
extends RefCounted
## Small helpers shared by the things drawn in the windsurfer scene (the figure and the rig):
## laying a cylinder between two points, making boxes, limbs and plain materials. Nothing in
## here touches the physics.


## A rotation whose y axis points along `up` (for cylinders and capsules).
static func basis_with_up(up: Vector3) -> Basis:
	var y: Vector3 = up.normalized()
	var reference: Vector3 = Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x: Vector3 = y.cross(reference).normalized()
	var z: Vector3 = x.cross(y)
	return Basis(x, y, z)


## Lays a unit-height cylinder (or capsule) between two points by scaling it along y.
static func lay_segment(node: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	var length: float = maxf((to - from).length(), 0.01)
	var basis: Basis = basis_with_up(to - from)
	node.transform = Transform3D(basis.scaled(Vector3(1.0, length, 1.0)), 0.5 * (from + to))


## A box mesh of the given size, at a local position, under `parent`.
static func add_box(parent: Node3D, node_name: String, size: Vector3, position_local: Vector3, color: Color) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	instance.mesh = box
	instance.position = position_local
	instance.material_override = plain_material(color)
	parent.add_child(instance)
	return instance


## A unit-height cylinder for a limb; lay_segment() stretches it between two points.
static func add_limb(parent: Node3D, node_name: String, radius: float, color: Color) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.height = 1.0
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	instance.mesh = cylinder
	instance.material_override = plain_material(color)
	parent.add_child(instance)
	return instance


## A critically damped spring, one step of `dt` seconds: the value follows `target` like a weight
## on a spring with just enough damping not to overshoot, `omega` (radians a second) setting how
## fast (it closes most of a sudden gap in about 4 / omega seconds). Its speed changes smoothly, so
## a target that jumps or jitters comes out as an easy movement, never a jump. Exact for any time
## step (the closed form of x'' = -omega^2 x - 2 omega x'). Returns (the value, its speed).
static func spring_float(value: float, speed: float, target: float, omega: float, dt: float) -> Vector2:
	var offset: float = value - target
	var decay: float = exp(-omega * dt)
	var j: float = speed + omega * offset
	return Vector2(target + (offset + j * dt) * decay, (speed - omega * j * dt) * decay)


## The same spring for a point: returns [the point, its velocity].
static func spring_vector(value: Vector3, velocity: Vector3, target: Vector3, omega: float, dt: float) -> PackedVector3Array:
	var offset: Vector3 = value - target
	var decay: float = exp(-omega * dt)
	var j: Vector3 = velocity + omega * offset
	return PackedVector3Array([target + (offset + j * dt) * decay, (velocity - omega * j * dt) * decay])


## A plain, slightly rough material in one colour.
static func plain_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	return material
