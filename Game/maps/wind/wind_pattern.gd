class_name WindPattern
extends RefCounted
## The fixed part of a map's wind (MAP_SILVAPLANA_PLAN.md, W1 and WD2): where the terrain makes
## the wind stronger or weaker, and where it turns it. It was computed once, offline (WindNinja and
## the satellite, tools/map/windninja_pattern.py), and is stored per 50 m cell as
## - the speed factor: the wind speed there divided by the lake's average speed,
## - the turn: how many degrees the wind there comes from further clockwise (further right) than
##   the lake's average direction.
##
## In between the cells the pattern is interpolated as an arrow (the factor pointing in the turned
## direction), not as an angle: halfway between -179 and +179 degrees is 180, not 0. The arrow is
## in the lake's own frame: Vector2(1, 0) is exactly the lake's average wind, +y is turned
## clockwise. The graphics card gets the same arrows (to_image), so the streaks on the screen and
## the numbers in the game agree (WD1).

## Number of cells west to east and north to south.
var columns: int = 0
var rows: int = 0
## Size of a cell, in metres.
var cell_m: float = 0.0
## Game position (X, Z) of the centre of the first cell, the north-west one.
var x0_m: float = 0.0
var z0_m: float = 0.0
## The lake's average direction the turns are relative to: where the wind comes from, degrees.
var lake_from_deg: float = 0.0

## Per cell, row by row from the north: the arrow's part along the lake's average wind
## (factor * cos(turn)) and its part turned clockwise (factor * sin(turn)).
var _along: PackedFloat32Array
var _clockwise: PackedFloat32Array


## Reads a pattern from its .json file (the .bin file sits next to it). The config places the
## pattern's Swiss coordinates in the game. Returns null if it can't.
static func load_from(json_path: String, config: MapConfig) -> WindPattern:
	var info: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not info is Dictionary:
		push_error("WindPattern: can't read %s" % json_path)
		return null
	var pattern: WindPattern = WindPattern.new()
	pattern.columns = int(info["columns"])
	pattern.rows = int(info["rows"])
	pattern.cell_m = float(info["cell_m"])
	pattern.lake_from_deg = float(info["lake_direction_deg"])
	# The file gives the north-west corner of the first cell; the game samples the cells' centres.
	var first_centre: Vector3 = config.lv95_to_game(
		float(info["west_m"]) + pattern.cell_m / 2.0, float(info["north_m"]) - pattern.cell_m / 2.0, config.lake_level_m)
	pattern.x0_m = first_centre.x
	pattern.z0_m = first_centre.z

	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(json_path.get_base_dir().path_join(str(info["file"])))
	var cells: int = pattern.columns * pattern.rows
	if bytes.size() != cells * 2 * 4:
		push_error("WindPattern: %s has %d bytes, expected %d" % [info["file"], bytes.size(), cells * 2 * 4])
		return null
	# Two layers of 32-bit floats: first all the speed factors, then all the turns.
	var factors: PackedFloat32Array = bytes.slice(0, cells * 4).to_float32_array()
	var turns_deg: PackedFloat32Array = bytes.slice(cells * 4).to_float32_array()
	pattern._along.resize(cells)
	pattern._clockwise.resize(cells)
	for i: int in cells:
		var turn_rad: float = deg_to_rad(turns_deg[i])
		pattern._along[i] = factors[i] * cos(turn_rad)
		pattern._clockwise[i] = factors[i] * sin(turn_rad)
	return pattern


## Whether a game position (only X and Z count) lies between the pattern's cell centres.
func contains(x: float, z: float) -> bool:
	return x >= x0_m and x <= x0_m + (columns - 1) * cell_m and z >= z0_m and z <= z0_m + (rows - 1) * cell_m


## The pattern's arrow at a game position, in the lake's frame (see the top of this file),
## interpolated between the four nearest cell centres. Outside the pattern it keeps the value
## of the nearest edge.
func arrow_at(x: float, z: float) -> Vector2:
	var fx: float = clampf((x - x0_m) / cell_m, 0.0, columns - 1.0)
	var fz: float = clampf((z - z0_m) / cell_m, 0.0, rows - 1.0)
	var column: int = mini(int(fx), columns - 2)
	var row: int = mini(int(fz), rows - 2)
	var tx: float = fx - column
	var tz: float = fz - row
	var i: int = row * columns + column
	var north: Vector2 = Vector2(_along[i], _clockwise[i]).lerp(Vector2(_along[i + 1], _clockwise[i + 1]), tx)
	i += columns
	var south: Vector2 = Vector2(_along[i], _clockwise[i]).lerp(Vector2(_along[i + 1], _clockwise[i + 1]), tx)
	return north.lerp(south, tz)


## The wind speed at a game position divided by the lake's average speed.
func speed_factor_at(x: float, z: float) -> float:
	return arrow_at(x, z).length()


## How many degrees the wind at a game position comes from further clockwise than the lake's
## average direction.
func turn_deg_at(x: float, z: float) -> float:
	var arrow: Vector2 = arrow_at(x, z)
	return rad_to_deg(atan2(arrow.y, arrow.x))


## The pattern for the graphics card, one pixel per cell, north row first: red is the arrow's
## part along the lake's wind, green its clockwise part, blue the height of the ground there
## (metres above the lake; the streaks fly over it), alpha 1. Shaders sample it with
## pattern_uv() in wind_pattern.gdshaderinc, which matches arrow_at().
func to_image(ground: TerrainGrid) -> Image:
	var data: PackedFloat32Array = PackedFloat32Array()
	data.resize(columns * rows * 4)
	for row: int in rows:
		for column: int in columns:
			var i: int = row * columns + column
			var ground_m: float = ground.height_at(x0_m + column * cell_m, z0_m + row * cell_m)
			data[4 * i] = _along[i]
			data[4 * i + 1] = _clockwise[i]
			data[4 * i + 2] = ground_m if not is_nan(ground_m) else 0.0
			data[4 * i + 3] = 1.0
	return Image.create_from_data(columns, rows, false, Image.FORMAT_RGBAF, data.to_byte_array())


## Gives a wind shader (one that includes wind_pattern.gdshaderinc) this pattern: the texture made
## from to_image(), and where the cells lie in the game.
func set_shader_pattern(material: ShaderMaterial, texture: Texture2D) -> void:
	material.set_shader_parameter("wind_pattern", texture)
	material.set_shader_parameter("pattern_origin_m", Vector2(x0_m, z0_m))
	material.set_shader_parameter("pattern_cell_m", cell_m)
	material.set_shader_parameter("pattern_cells", Vector2(columns, rows))
