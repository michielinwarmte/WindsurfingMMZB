class_name HeightTerrain
extends Node3D
## A spot's terrain drawn from its height grid on the graphics card (height_terrain.gdshader): the
## area is cut into square chunks, and each chunk is a flat grid mesh, fine near the camera and
## coarser further away, lifted by the shader to the grid's heights and coloured with the aerial
## photos. No terrain meshes are built offline (no Blender): the height grid tools/map/spot_build.py
## writes is drawn as it is, and it is the same file the game logic reads (TerrainGrid; MD3: a nicer
## look can never change the sailing).
##
## The grid's heights are above mean sea level; water_level_m (the session's tide) lowers them, so
## the water, always at the game's height 0, stands at that level.

const SHADER: Shader = preload("res://maps/height_terrain.gdshader")

## The height grid (TerrainGrid's .json).
@export_file("*.json") var heights_json: String = ""
## The photos' boxes (spot_build.py's photos.json) and which of them this terrain uses.
@export_file("*.json") var photos_json: String = ""
@export var photo: Texture2D = null
@export var photo_key: String = "near"
## A sharper photo over part of the area (the launch and the lagoon), blended in; null for none.
@export var detail_photo: Texture2D = null
@export var detail_key: String = "detail"
## Leave out the area of this other grid (the far terrain leaves out the near one's); "" for none.
@export_file("*.json") var hole_heights_json: String = ""
## The session's water level above mean sea level, m (the tide).
@export var water_level_m: float = 0.0
## The chunks' size, m.
@export var chunk_m: float = 1000.0
## The detail levels: (the grid mesh's spacing in m, the distance it is drawn to in m; 0 = always),
## finest first. The spacings must divide chunk_m.
@export var levels: Array[Vector2] = [Vector2(5.0, 1500.0), Vector2(20.0, 5000.0), Vector2(100.0, 0.0)]
## Whether the chunks cast shadows (the near terrain: its dunes and hotels; the far one: no).
@export var casts_shadows: bool = true
## Nothing deeper than this is drawn, m.
@export var lowest_m: float = -60.0
## The photo's colours times this (white sand in an aerial photo is near pure white).
@export var photo_brightness: float = 1.0

var grid: TerrainGrid = null
var material: ShaderMaterial = null


func _ready() -> void:
	build()


## Builds the chunks (again, if they were built before).
func build() -> void:
	for child: Node in get_children():
		child.queue_free()
	grid = TerrainGrid.load_from(heights_json)
	if grid == null:
		return
	grid.lower_by(water_level_m)
	material = _make_material()
	var meshes: Array[ArrayMesh] = []
	for level: Vector2 in levels:
		meshes.append(grid_mesh(chunk_m, int(round(chunk_m / level.x))))
	var area: Rect2 = grid_area(grid)
	var columns: int = ceili(area.size.x / chunk_m)
	var rows: int = ceili(area.size.y / chunk_m)
	for row: int in rows:
		for column: int in columns:
			var centre: Vector2 = area.position + Vector2((column + 0.5) * chunk_m, (row + 0.5) * chunk_m)
			_add_chunk(centre, meshes)


## The grid's area in game x, z (from its first node to its last).
static func grid_area(terrain_grid: TerrainGrid) -> Rect2:
	return Rect2(terrain_grid.x0_m, terrain_grid.z0_m, (terrain_grid.columns - 1) * terrain_grid.cell_m,
		(terrain_grid.rows - 1) * terrain_grid.cell_m)


## A flat square grid mesh `size_m` wide with `quads` squares a side, centred on its origin, and a
## skirt round its border: a copy of each border vertex marked UV2.x = 1, which the shader hangs
## down, joined to the border by triangles facing both ways.
static func grid_mesh(size_m: float, quads: int) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var skirt_marks: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var step: float = size_m / quads
	var half: float = size_m / 2.0
	var per_row: int = quads + 1
	for j: int in per_row:
		for i: int in per_row:
			vertices.append(Vector3(-half + i * step, 0.0, -half + j * step))
			skirt_marks.append(Vector2.ZERO)
	for j: int in quads:
		for i: int in quads:
			var a: int = j * per_row + i
			var b: int = a + 1
			var c: int = a + per_row
			var d: int = c + 1
			# Clockwise seen from above: Godot's front faces.
			indices.append_array([a, b, c, b, d, c])
	# The border, in order round the square, and a skirt vertex under each.
	var border: PackedInt32Array = PackedInt32Array()
	for i: int in per_row:
		border.append(i)
	for j: int in range(1, per_row):
		border.append(j * per_row + quads)
	for i: int in range(quads - 1, -1, -1):
		border.append(quads * per_row + i)
	for j: int in range(quads - 1, 0, -1):
		border.append(j * per_row)
	var first_skirt: int = vertices.size()
	for index: int in border:
		vertices.append(vertices[index])
		skirt_marks.append(Vector2(1.0, 0.0))
	for k: int in border.size():
		var top_a: int = border[k]
		var top_b: int = border[(k + 1) % border.size()]
		var low_a: int = first_skirt + k
		var low_b: int = first_skirt + (k + 1) % border.size()
		indices.append_array([top_a, top_b, low_a, top_b, low_b, low_a])
		indices.append_array([top_a, low_a, top_b, top_b, low_a, low_b])
	var normals: PackedVector3Array = PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV2] = skirt_marks
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _make_material() -> ShaderMaterial:
	var made: ShaderMaterial = ShaderMaterial.new()
	made.shader = SHADER
	var image: Image = Image.create_from_data(grid.columns, grid.rows, false, Image.FORMAT_RG8, grid.raw_values())
	made.set_shader_parameter("heights", ImageTexture.create_from_image(image))
	made.set_shader_parameter("grid_origin", Vector2(grid.x0_m, grid.z0_m))
	made.set_shader_parameter("grid_cell_m", grid.cell_m)
	made.set_shader_parameter("grid_nodes", Vector2(grid.columns, grid.rows))
	made.set_shader_parameter("height_offset_m", grid.height_offset_m())
	made.set_shader_parameter("height_scale_m", grid.height_scale_m())
	made.set_shader_parameter("lowest_m", lowest_m)
	made.set_shader_parameter("photo_brightness", photo_brightness)
	made.set_shader_parameter("water_level_m", water_level_m)
	var rects: Dictionary = _photo_rects()
	made.set_shader_parameter("photo", photo)
	made.set_shader_parameter("photo_rect", rects.get(photo_key, Vector4(grid.x0_m, grid.z0_m, 1.0, 1.0)))
	if detail_photo != null and rects.has(detail_key):
		made.set_shader_parameter("detail_photo", detail_photo)
		made.set_shader_parameter("detail_rect", rects[detail_key])
		made.set_shader_parameter("has_detail", true)
	if hole_heights_json != "":
		var other: TerrainGrid = TerrainGrid.load_from(hole_heights_json)
		if other != null:
			var hole: Rect2 = grid_area(other).grow(-grid.cell_m)
			made.set_shader_parameter("hole_rect", Vector4(hole.position.x, hole.position.y, hole.size.x, hole.size.y))
			made.set_shader_parameter("has_hole", true)
	return made


## The photos' boxes from photos.json as Vector4(x, z, width, depth), by name.
func _photo_rects() -> Dictionary:
	var rects: Dictionary = {}
	if photos_json == "":
		return rects
	var info: Variant = JSON.parse_string(FileAccess.get_file_as_string(photos_json))
	if not info is Dictionary:
		push_error("HeightTerrain: can't read %s" % photos_json)
		return rects
	for key: String in (info as Dictionary).keys():
		var value: Variant = info[key]
		if value is Array and (value as Array).size() == 4:
			rects[key] = Vector4(value[0], value[1], value[2], value[3])
	return rects


## One chunk: a mesh instance per detail level at its centre, each drawn over its range of distances.
func _add_chunk(centre: Vector2, meshes: Array[ArrayMesh]) -> void:
	var height_range: Vector2 = _height_range(Rect2(centre - Vector2(chunk_m, chunk_m) / 2.0, Vector2(chunk_m, chunk_m)))
	var begin_m: float = 0.0
	for k: int in levels.size():
		var instance: MeshInstance3D = MeshInstance3D.new()
		instance.name = "Chunk_%d_%d_L%d" % [int(centre.x), int(centre.y), k]
		instance.mesh = meshes[k]
		instance.material_override = material
		instance.position = Vector3(centre.x, 0.0, centre.y)
		# The flat mesh's box would be culled as soon as its middle left the view: the box of the
		# heights the shader lifts it to, with the skirt under it.
		instance.custom_aabb = AABB(Vector3(-chunk_m / 2.0, height_range.x - 30.0, -chunk_m / 2.0),
			Vector3(chunk_m, height_range.y - height_range.x + 31.0, chunk_m))
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts_shadows and k < 2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.visibility_range_begin = begin_m
		instance.visibility_range_end = levels[k].y
		instance.visibility_range_begin_margin = 30.0 if begin_m > 0.0 else 0.0
		instance.visibility_range_end_margin = 30.0 if levels[k].y > 0.0 else 0.0
		add_child(instance)
		begin_m = levels[k].y


## The lowest and highest height the shader draws in a rectangle (every 4th node is looked at;
## at least lowest_m).
func _height_range(rect: Rect2) -> Vector2:
	var low: float = INF
	var high: float = -INF
	var step_m: float = grid.cell_m * 4.0
	var z: float = rect.position.y
	while z <= rect.end.y:
		var x: float = rect.position.x
		while x <= rect.end.x:
			var height: float = grid.height_at(clampf(x, grid.x0_m, grid.x0_m + (grid.columns - 1) * grid.cell_m),
				clampf(z, grid.z0_m, grid.z0_m + (grid.rows - 1) * grid.cell_m))
			low = minf(low, height)
			high = maxf(high, height)
			x += step_m
		z += step_m
	return Vector2(maxf(low, lowest_m), maxf(high, lowest_m + 1.0))
