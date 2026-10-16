class_name LakeArea
extends RefCounted
## Where a map's lake is, found once from its depth grid (TerrainGrid) at a coarse step, for the
## things you see (MAP_SILVAPLANA_PLAN.md, M3):
## - the flat water far away (build_mesh): the water with the waves (OceanNode) only covers the
##   400 m around the camera, and a flat plane out to the horizon would flood the land that lies
##   lower than the lake (Lake St. Moritz is 22 m lower, so is the Inn valley toward Samedan),
## - the lake's outline on the HUD's small map (make_image, MiniMap).
## A spot belongs to the lake when the ground there is below the lake surface (Y = 0) and it is
## joined to a spot known to be in the lake through other lake spots: a low field or a pond
## elsewhere stays land. Nothing here changes the sailing: the shore check reads the grid itself.

## Distance between two spots, in metres (a multiple of the grid's cell keeps it simple).
var step_m: float = 8.0
## Number of spots west to east and north to south.
var columns: int = 0
var rows: int = 0
## Game position of the first spot, the north-west corner (north is -Z).
var x0_m: float = 0.0
var z0_m: float = 0.0

## One byte per spot, row by row from the north: 1 = lake, 0 = land.
var _lake: PackedByteArray


## Finds the lake that contains the spot `inside` (only X and Z count). Returns an area with no
## lake spots when `inside` is not over water.
static func from_grid(grid: TerrainGrid, inside: Vector3, spot_step_m: float) -> LakeArea:
	var area: LakeArea = LakeArea.new()
	area.step_m = spot_step_m
	area.columns = int(floor((grid.columns - 1) * grid.cell_m / spot_step_m)) + 1
	area.rows = int(floor((grid.rows - 1) * grid.cell_m / spot_step_m)) + 1
	area.x0_m = grid.x0_m
	area.z0_m = grid.z0_m
	area._fill_from(area._spots_below_lake_level(grid), area._spot_near(inside))
	return area


## Whether the spot nearest to a game position is lake water.
func is_lake_at(x: float, z: float) -> bool:
	var column: int = roundi((x - x0_m) / step_m)
	var row: int = roundi((z - z0_m) / step_m)
	return _is_lake(column, row)


func lake_spot_count() -> int:
	return _lake.count(1)


## The lake's extent in game metres: position = (west X, north Z), size = (east-west, north-south).
func lake_bounds() -> Rect2:
	var first: Vector2i = Vector2i(columns, rows)
	var last: Vector2i = Vector2i(-1, -1)
	for row: int in rows:
		for column: int in columns:
			if _lake[row * columns + column] == 1:
				first = Vector2i(mini(first.x, column), mini(first.y, row))
				last = Vector2i(maxi(last.x, column), maxi(last.y, row))
	if last.x < 0:
		return Rect2()
	return Rect2(x0_m + first.x * step_m, z0_m + first.y * step_m,
		(last.x - first.x) * step_m, (last.y - first.y) * step_m)


## A flat mesh over the lake, with its vertices at world X and Z (place it at X = Z = 0). Each lake
## spot is covered by a square of step_m around it, and the lake is widened by `margin_spots`
## spots on every side, so the water reaches in under the shore: the terrain hides it there, and
## no strip of dry lakebed shows between the water and the land. Squares next to each other in a
## row are joined into one long strip, which keeps the mesh small (about 2 000 triangles).
func build_mesh(margin_spots: int) -> ArrayMesh:
	var wide: PackedByteArray = _widened(margin_spots)
	var vertices: PackedVector3Array = PackedVector3Array()
	var half: float = step_m * 0.5
	for row: int in rows:
		var column: int = 0
		while column < columns:
			if wide[row * columns + column] == 0:
				column += 1
				continue
			var run_start: int = column
			while column < columns and wide[row * columns + column] == 1:
				column += 1
			var west: float = x0_m + run_start * step_m - half
			var east: float = x0_m + (column - 1) * step_m + half
			var north: float = z0_m + row * step_m - half
			var south: float = z0_m + row * step_m + half
			_add_quad(vertices, west, east, north, south)
	var normals: PackedVector3Array = PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh: ArrayMesh = ArrayMesh.new()
	if not vertices.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## The area as a picture, one pixel per spot (north at the top): lake pixels in one colour, land
## in the other.
func make_image(water: Color, land: Color) -> Image:
	var image: Image = Image.create_empty(columns, rows, false, Image.FORMAT_RGBA8)
	image.fill(land)
	for row: int in rows:
		for column: int in columns:
			if _lake[row * columns + column] == 1:
				image.set_pixel(column, row, water)
	return image


## One byte per spot: 1 where the ground is below the lake surface.
func _spots_below_lake_level(grid: TerrainGrid) -> PackedByteArray:
	var below: PackedByteArray = PackedByteArray()
	below.resize(columns * rows)
	for row: int in rows:
		var z: float = z0_m + row * step_m
		for column: int in columns:
			var height: float = grid.height_at(x0_m + column * step_m, z)
			below[row * columns + column] = 1 if height < 0.0 else 0
	return below


## A flood fill: starting at one spot, every spot below the lake level that can be reached through
## its neighbours (north, south, east and west) is lake.
func _fill_from(below: PackedByteArray, start: Vector2i) -> void:
	_lake = PackedByteArray()
	_lake.resize(columns * rows)
	if not _inside(start.x, start.y) or below[start.y * columns + start.x] == 0:
		return
	var to_visit: PackedInt32Array = PackedInt32Array([start.y * columns + start.x])
	_lake[start.y * columns + start.x] = 1
	while not to_visit.is_empty():
		var index: int = to_visit[to_visit.size() - 1]
		to_visit.resize(to_visit.size() - 1)
		var column: int = index % columns
		var row: int = index / columns
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next_column: int = column + step.x
			var next_row: int = row + step.y
			if not _inside(next_column, next_row):
				continue
			var next: int = next_row * columns + next_column
			if below[next] == 1 and _lake[next] == 0:
				_lake[next] = 1
				to_visit.append(next)


## The lake, widened by `margin` spots in every direction (a square around each lake spot).
func _widened(margin: int) -> PackedByteArray:
	# First along the rows, then along the columns: the same as a square, but much faster.
	var across: PackedByteArray = PackedByteArray()
	across.resize(columns * rows)
	for row: int in rows:
		for column: int in columns:
			if _lake[row * columns + column] == 1:
				for c: int in range(maxi(column - margin, 0), mini(column + margin, columns - 1) + 1):
					across[row * columns + c] = 1
	var wide: PackedByteArray = PackedByteArray()
	wide.resize(columns * rows)
	for row: int in rows:
		for column: int in columns:
			if across[row * columns + column] == 1:
				for r: int in range(maxi(row - margin, 0), mini(row + margin, rows - 1) + 1):
					wide[r * columns + column] = 1
	return wide


## Two triangles for a flat rectangle facing up (Godot draws the side whose corners go clockwise).
func _add_quad(vertices: PackedVector3Array, west: float, east: float, north: float, south: float) -> void:
	var north_west: Vector3 = Vector3(west, 0.0, north)
	var north_east: Vector3 = Vector3(east, 0.0, north)
	var south_west: Vector3 = Vector3(west, 0.0, south)
	var south_east: Vector3 = Vector3(east, 0.0, south)
	vertices.append_array([north_west, north_east, south_east, north_west, south_east, south_west])


func _spot_near(at: Vector3) -> Vector2i:
	return Vector2i(roundi((at.x - x0_m) / step_m), roundi((at.z - z0_m) / step_m))


func _is_lake(column: int, row: int) -> bool:
	return _inside(column, row) and _lake[row * columns + column] == 1


func _inside(column: int, row: int) -> bool:
	return column >= 0 and column < columns and row >= 0 and row < rows
