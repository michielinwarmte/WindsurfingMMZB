class_name FetchMap
extends RefCounted
## How far the wind has blown over open water before it reaches each point of a lake (the fetch),
## and how strong it blew on the way (PHYSICS_SPEC.md 9.17, steps 1 and 2). Worked out once, when
## the lake's waves are built, on a grid of nodes `cell_m` apart; never per query.
##
## The fetch at a node is the Shore Protection Manual's (1984): the open water upwind along nine
## rays 6 degrees apart around the wind, averaged with the cosine of each ray's angle off the wind
## as its weight (the `lakefetch` documentation's description of the SPM method; the research,
## wave_system_research.md 1.2). On a narrow lake it is smooth from place to place where one
## straight ray would jump as it grazes a headland, and about 30 % shorter along the lake's axis.
##
## The wind along the fetch: the lake measurements suggest averaging the wind along the fetch
## (Casas, Bleninger and Stips 2025; the research, 1.3). So each node also gets the mean of the
## local wind (relative to the lake's mean) over the same rays, each metre of upwind water counting
## the same.
##
## How a ray is followed, for every node at once: the open water upwind of a node is one step to
## the next node upwind plus that node's open water. The step goes one whole column (or row) toward
## the wind, and the point it lands on lies between two nodes of that column, so their values are
## mixed by distance. Starting from the upwind edge, every node's upwind neighbours are done before
## it. Land and the grid's edge count as zero open water; the shore is taken halfway between a land
## node and the first water node, so a node's fetch is its steps less half a step.

## The nodes: this many west to east and north to south, this far apart, the first (north-west)
## one at this game position (north is -Z).
var columns: int = 0
var rows: int = 0
var cell_m: float = 16.0
var x0_m: float = 0.0
var z0_m: float = 0.0
## The direction the wind comes from that the map was made for, degrees.
var from_deg: float = 0.0
## Per node, row by row from the north: the water's depth (m, 0 or less on land), the fetch (m) and
## the mean wind along it (a factor on the lake's mean wind).
var depth_m: PackedFloat32Array = PackedFloat32Array()
var fetch_m: PackedFloat32Array = PackedFloat32Array()
var wind_factor: PackedFloat32Array = PackedFloat32Array()


## Builds the map for a wind from `from_deg` over `area` (game x, z of its north-west corner and
## its size), cropped to the water in it with a margin of land.
## depth_at: Callable(x: float, z: float) -> float, the water's depth (m; 0 or less on land, NAN
## off the map). speed_factor_at: Callable(x, z) -> float, the local mean wind relative to the
## lake's mean (1 everywhere for a wind the same everywhere).
static func build(depth_at: Callable, area: Rect2, cell: float, wind_from_deg: float, speed_factor_at: Callable,
		ray_count: int = 9, ray_spacing_deg: float = 6.0) -> FetchMap:
	var map: FetchMap = FetchMap.new()
	map.cell_m = cell
	map.from_deg = wind_from_deg
	map._sample_depths(depth_at, area)
	map._crop_to_water()
	var water_wind: PackedFloat32Array = map._local_winds(speed_factor_at)
	map._average_rays(water_wind, ray_count, ray_spacing_deg)
	return map


## Whether a node is water.
func is_water(column: int, row: int) -> bool:
	return depth_m[row * columns + column] > 0.0


## The game position of a node.
func node_position(column: int, row: int) -> Vector2:
	return Vector2(x0_m + column * cell_m, z0_m + row * cell_m)


## A per-node value at a game position, between the four nearest nodes (bilinear); 0 off the map.
func value_at(values: PackedFloat32Array, x: float, z: float) -> float:
	var fx: float = (x - x0_m) / cell_m
	var fz: float = (z - z0_m) / cell_m
	if fx < 0.0 or fz < 0.0 or fx > columns - 1.0 or fz > rows - 1.0:
		return 0.0
	var column: int = mini(int(fx), columns - 2)
	var row: int = mini(int(fz), rows - 2)
	var tx: float = fx - column
	var tz: float = fz - row
	var i: int = row * columns + column
	var north: float = lerpf(values[i], values[i + 1], tx)
	var south: float = lerpf(values[i + columns], values[i + columns + 1], tx)
	return lerpf(north, south, tz)


# ---------------------------------------------------------------- building

## The depth at every node of the area (land where the map has nothing).
func _sample_depths(depth_at: Callable, area: Rect2) -> void:
	x0_m = area.position.x
	z0_m = area.position.y
	columns = int(floor(area.size.x / cell_m)) + 1
	rows = int(floor(area.size.y / cell_m)) + 1
	depth_m.resize(columns * rows)
	for row: int in rows:
		for column: int in columns:
			var depth: float = depth_at.call(x0_m + column * cell_m, z0_m + row * cell_m)
			depth_m[row * columns + column] = depth if not is_nan(depth) else -1.0


## Keeps the nodes around the water, with two rows and columns of land on every side.
func _crop_to_water() -> void:
	var first_column: int = columns
	var last_column: int = -1
	var first_row: int = rows
	var last_row: int = -1
	for row: int in rows:
		for column: int in columns:
			if depth_m[row * columns + column] > 0.0:
				first_column = mini(first_column, column)
				last_column = maxi(last_column, column)
				first_row = mini(first_row, row)
				last_row = maxi(last_row, row)
	if last_column < 0:
		columns = 0
		rows = 0
		depth_m = PackedFloat32Array()
		return
	const MARGIN: int = 2
	var new_columns: int = last_column - first_column + 1 + 2 * MARGIN
	var new_rows: int = last_row - first_row + 1 + 2 * MARGIN
	var cropped: PackedFloat32Array = PackedFloat32Array()
	cropped.resize(new_columns * new_rows)
	for row: int in new_rows:
		for column: int in new_columns:
			var old_column: int = column + first_column - MARGIN
			var old_row: int = row + first_row - MARGIN
			var inside: bool = old_column >= 0 and old_column < columns and old_row >= 0 and old_row < rows
			cropped[row * new_columns + column] = depth_m[old_row * columns + old_column] if inside else -1.0
	x0_m += (first_column - MARGIN) * cell_m
	z0_m += (first_row - MARGIN) * cell_m
	columns = new_columns
	rows = new_rows
	depth_m = cropped


## The local mean wind at every water node (0 on land).
func _local_winds(speed_factor_at: Callable) -> PackedFloat32Array:
	var winds: PackedFloat32Array = PackedFloat32Array()
	winds.resize(columns * rows)
	for row: int in rows:
		for column: int in columns:
			var i: int = row * columns + column
			winds[i] = speed_factor_at.call(x0_m + column * cell_m, z0_m + row * cell_m) if depth_m[i] > 0.0 else 0.0
	return winds


## The cosine-weighted fetch and the wind along it, over the rays around the wind.
func _average_rays(water_wind: PackedFloat32Array, ray_count: int, ray_spacing_deg: float) -> void:
	var nodes: int = columns * rows
	var fetch_sum: PackedFloat64Array = PackedFloat64Array()  # sum of cos x fetch
	var length_sum: PackedFloat64Array = PackedFloat64Array()  # sum of cos x the ray's water
	var wind_sum: PackedFloat64Array = PackedFloat64Array()  # sum of cos x the wind along it
	fetch_sum.resize(nodes)
	length_sum.resize(nodes)
	wind_sum.resize(nodes)
	fetch_sum.fill(0.0)
	length_sum.fill(0.0)
	wind_sum.fill(0.0)
	var weight_sum: float = 0.0
	var ray_length: PackedFloat32Array = PackedFloat32Array()
	var ray_wind: PackedFloat32Array = PackedFloat32Array()
	for ray: int in ray_count:
		var off_deg: float = (ray - (ray_count - 1) * 0.5) * ray_spacing_deg
		var weight: float = cos(deg_to_rad(off_deg))
		weight_sum += weight
		var step_m: float = _follow_ray(from_deg + off_deg, water_wind, ray_length, ray_wind)
		for i: int in nodes:
			if ray_length[i] <= 0.0:
				continue
			fetch_sum[i] += weight * maxf(ray_length[i] - 0.5 * step_m, 0.0)
			length_sum[i] += weight * ray_length[i]
			wind_sum[i] += weight * ray_wind[i]
	fetch_m.resize(nodes)
	wind_factor.resize(nodes)
	for i: int in nodes:
		fetch_m[i] = fetch_sum[i] / weight_sum
		wind_factor[i] = wind_sum[i] / length_sum[i] if length_sum[i] > 0.0 else water_wind[i]


## One ray, for every node: `length` gets the water upwind of each node along a wind from
## `bearing_deg` (in whole steps, the node's own step included), `wind` the sum of the local wind
## over those steps (factor x metres). Returns the step's length (m).
func _follow_ray(bearing_deg: float, water_wind: PackedFloat32Array, length: PackedFloat32Array, wind: PackedFloat32Array) -> float:
	length.resize(columns * rows)
	wind.resize(columns * rows)
	length.fill(0.0)
	wind.fill(0.0)
	# Toward where the wind comes from (north is -Z, east +X): (sin b, -cos b).
	var bearing: float = deg_to_rad(bearing_deg)
	var upwind: Vector2 = Vector2(sin(bearing), -cos(bearing))
	if absf(upwind.x) >= absf(upwind.y):
		# Whole columns toward the wind; the rows the step lands between.
		var toward: int = 1 if upwind.x > 0.0 else -1
		var step_m: float = cell_m / absf(upwind.x)
		var rows_per_step: float = upwind.y / absf(upwind.x)
		for n: int in columns:
			var column: int = columns - 1 - n if toward > 0 else n
			var upwind_column: int = column + toward
			for row: int in rows:
				_step(row * columns + column, upwind_column, 0, row + rows_per_step, true, step_m, water_wind, length, wind)
		return step_m
	var toward_rows: int = 1 if upwind.y > 0.0 else -1
	var step_rows_m: float = cell_m / absf(upwind.y)
	var columns_per_step: float = upwind.x / absf(upwind.y)
	for n: int in rows:
		var row: int = rows - 1 - n if toward_rows > 0 else n
		var upwind_row: int = row + toward_rows
		for column: int in columns:
			_step(row * columns + column, 0, upwind_row, column + columns_per_step, false, step_rows_m, water_wind, length, wind)
	return step_rows_m


## One node of a ray: its own step plus the water upwind of the point the step lands on, mixed
## from the two nodes of the next column (along_columns) or row there.
func _step(i: int, upwind_column: int, upwind_row: int, lands_at: float, along_columns: bool, step_m: float,
		water_wind: PackedFloat32Array, length: PackedFloat32Array, wind: PackedFloat32Array) -> void:
	if depth_m[i] <= 0.0:
		return
	var before_length: float = 0.0
	var before_wind: float = 0.0
	var first: int = floori(lands_at)
	var share: float = lands_at - first
	if along_columns and upwind_column >= 0 and upwind_column < columns:
		if first >= 0 and first < rows:
			var j: int = first * columns + upwind_column
			before_length += (1.0 - share) * length[j]
			before_wind += (1.0 - share) * wind[j]
		if first + 1 >= 0 and first + 1 < rows:
			var j: int = (first + 1) * columns + upwind_column
			before_length += share * length[j]
			before_wind += share * wind[j]
	elif not along_columns and upwind_row >= 0 and upwind_row < rows:
		if first >= 0 and first < columns:
			var j: int = upwind_row * columns + first
			before_length += (1.0 - share) * length[j]
			before_wind += (1.0 - share) * wind[j]
		if first + 1 >= 0 and first + 1 < columns:
			var j: int = upwind_row * columns + first + 1
			before_length += share * length[j]
			before_wind += share * wind[j]
	length[i] = before_length + step_m
	wind[i] = before_wind + step_m * water_wind[i]
