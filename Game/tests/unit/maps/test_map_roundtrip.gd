extends GutTest
## The map pipeline's round trip (MAP_SILVAPLANA_PLAN.md, M0): a test hill built in Blender by
## tools/blender/roundtrip_test.py must arrive in Godot with the map axes of plan MD1:
## X = east, Y = up, Z = -north. The script puts the hill's top 20 m east, 30 m north and
## 10 m up from the centre, so a swapped or mirrored axis moves it somewhere else.

const HILL_PATH: String = "res://maps/silvaplana/dev/roundtrip_hill.glb"
const EXPECTED_PEAK: Vector3 = Vector3(20.0, 10.0, -30.0)
## Godot compresses imported vertex positions to 16 bits over the mesh's bounds: about 2 mm here.
const TOLERANCE_M: float = 0.01


func test_hill_peak_lands_east_north_up() -> void:
	var scene: PackedScene = load(HILL_PATH)
	assert_not_null(scene, "The round-trip hill should be imported: " + HILL_PATH)
	if scene == null:
		return
	var root: Node = scene.instantiate()
	var peak: Vector3 = _highest_vertex(root)
	root.free()
	assert_almost_eq(peak.x, EXPECTED_PEAK.x, TOLERANCE_M, "Blender's east (X) should be Godot's +X")
	assert_almost_eq(peak.y, EXPECTED_PEAK.y, TOLERANCE_M, "Blender's up (Z) should be Godot's +Y")
	assert_almost_eq(peak.z, EXPECTED_PEAK.z, TOLERANCE_M, "Blender's north (Y) should be Godot's -Z")


## The highest vertex of all meshes under root, in root's coordinates.
func _highest_vertex(root: Node) -> Vector3:
	var highest: Vector3 = Vector3(0.0, -INF, 0.0)
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		var to_root: Transform3D = _transform_to(root, mesh_instance)
		for surface: int in mesh_instance.mesh.get_surface_count():
			var vertices: PackedVector3Array = mesh_instance.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in vertices:
				var point: Vector3 = to_root * vertex
				if point.y > highest.y:
					highest = point
	return highest


## The transform from node's local space to root's space (the scene isn't in the tree, so no
## global_transform).
func _transform_to(root: Node, node: Node3D) -> Transform3D:
	var result: Transform3D = Transform3D.IDENTITY
	var current: Node = node
	while current != root and current != null:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	if root is Node3D:
		result = (root as Node3D).transform * result
	return result
