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


## A plain, slightly rough material in one colour.
static func plain_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	return material
