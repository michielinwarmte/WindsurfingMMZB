class_name SpotBuildings
extends Node3D
## A spot's buildings from OpenStreetMap's outlines (tools/map/spot_build.py --stage=buildings,
## Game/maps/<slug>/buildings.json): each outline raised as walls to its height with a flat roof, all
## in one mesh, drawn by spot_buildings.gdshader (white walls with rows of windows; tents plain
## fabric). Simple blocks, but they put the hotels and the town where they are, so the shore looks
## like the spot from the water (backlog E04.S16 is the real library of props). The bases are above
## mean sea level; water_level_m (the tide) lowers them with the terrain, as HeightTerrain does.

const SHADER: Shader = preload("res://maps/spots/spot_buildings.gdshader")

@export_file("*.json") var buildings_json: String = ""
## The session's water level above mean sea level, m (the sailing scene sets it).
@export var water_level_m: float = 0.0

## How many buildings the mesh holds (for the tests).
var count: int = 0


func _ready() -> void:
	build()


func build() -> void:
	for child: Node in get_children():
		child.queue_free()
	var info: Variant = JSON.parse_string(FileAccess.get_file_as_string(buildings_json))
	if not info is Dictionary:
		push_error("SpotBuildings: can't read %s" % buildings_json)
		return
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	count = 0
	for building: Dictionary in (info as Dictionary)["buildings"]:
		var outline: PackedVector2Array = PackedVector2Array()
		for point: Array in building["outline"]:
			outline.append(Vector2(point[0], point[1]))
		var base: float = float(building["base_m"]) - water_level_m
		var top: float = base + float(building["height_m"])
		var tent: bool = building.get("kind", "building") == "tent"
		_add_walls(outline, base, top, tent, vertices, normals, uvs, colors)
		_add_roof(outline, top, tent, vertices, normals, uvs, colors)
		count += 1
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = SHADER
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = "Buildings"
	instance.mesh = mesh
	instance.material_override = material
	add_child(instance)


## A wall per edge of the outline, from base to top, facing out (away from the outline's middle).
## UV: metres along the outline and up from the base (the windows' grid).
static func _add_walls(outline: PackedVector2Array, base: float, top: float, tent: bool, vertices: PackedVector3Array,
		normals: PackedVector3Array, uvs: PackedVector2Array, colors: PackedColorArray) -> void:
	var middle: Vector2 = Vector2.ZERO
	for point: Vector2 in outline:
		middle += point
	middle /= outline.size()
	var colour: Color = Color(1.0, 1.0 if tent else 0.0, 0.0)
	var along: float = 0.0
	for i: int in outline.size():
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % outline.size()]
		var edge: Vector2 = b - a
		if edge.length() < 0.01:
			continue
		var out: Vector2 = Vector2(edge.y, -edge.x).normalized()
		if out.dot((a + b) / 2.0 - middle) < 0.0:
			out = -out
		var normal: Vector3 = Vector3(out.x, 0.0, out.y)
		var height: float = top - base
		var corners: Array[Vector3] = [Vector3(a.x, base, a.y), Vector3(b.x, base, b.y), Vector3(b.x, top, b.y), Vector3(a.x, top, a.y)]
		var corner_uvs: Array[Vector2] = [Vector2(along, 0.0), Vector2(along + edge.length(), 0.0),
			Vector2(along + edge.length(), height), Vector2(along, height)]
		for k: int in [0, 1, 2, 0, 2, 3]:
			vertices.append(corners[k])
			normals.append(normal)
			uvs.append(corner_uvs[k])
			colors.append(colour)
		along += edge.length()


## The flat roof: the outline triangulated at the top.
static func _add_roof(outline: PackedVector2Array, top: float, tent: bool, vertices: PackedVector3Array,
		normals: PackedVector3Array, uvs: PackedVector2Array, colors: PackedColorArray) -> void:
	var triangles: PackedInt32Array = Geometry2D.triangulate_polygon(outline)
	var colour: Color = Color(0.0, 1.0 if tent else 0.0, 0.0)
	for index: int in triangles:
		var point: Vector2 = outline[index]
		vertices.append(Vector3(point.x, top, point.y))
		normals.append(Vector3.UP)
		uvs.append(point)
		colors.append(colour)
