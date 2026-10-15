class_name WindLee
extends RefCounted
## The lee along Lake Silvaplana's south-east shore (MAP_SILVAPLANA_PLAN.md, W3), measured on the
## satellite photos by tools/map/shore_lee.py (MALOJA_WIND_RESEARCH.md, "The lee along the
## south-east shore"). Max: "on competition you have to really avoid it, and only once in every 10
## or so there is a gust that is favourable and goes down all the way".
##
## The photos show the band from the Sils end to the north-east bend, deepest 25 to 100 m from the
## shore and gone about 450 m out, weaker around the middle ("the little corner"). Its depth changes
## with the wind: a wind from further left (more off the south-east shore) and a stronger wind give
## a deeper lee (a straight-line fit over 21 photos). MapWind uses this; the shaders do the same.
##
## The fixed pattern (W1) already holds the photos' average of this lee, smoothed. So the lee here
## is put on top of the pattern with W1's share taken out again ("held"), and over time it averages
## out to what the photos show.

## The grid: number of cells west to east and north to south, their size, and the game position
## (X, Z) of the first cell's centre (the north-west one).
var columns: int = 0
var rows: int = 0
var cell_m: float = 0.0
var x0_m: float = 0.0
var z0_m: float = 0.0
## The band's lee (a share of the wind, 50 to 250 m from the shore on average) at the reference
## wind, how it changes per degree the lake's wind comes from further right and per knot more
## wind, around the reference (the lake's wind from that direction at that strength), and the
## ranges the photos cover (degrees and knots around the reference). Outside those ranges the fit
## keeps its last value.
var band_lee_at_reference: float = 0.0
var per_degree_right: float = 0.0
var per_lake_knot: float = 0.0
var reference_from_deg: float = 0.0
var reference_kt: float = 0.0
var degrees_measured: Vector2 = Vector2.ZERO
var knots_measured: Vector2 = Vector2.ZERO
## The photos' average lee in the band.
var band_lee_average: float = 0.0

## Per cell, row by row from the north: the lee's shape (1 = the band's average) and the share of
## the wind the fixed pattern already takes off there.
var _shape: PackedFloat32Array
var _held: PackedFloat32Array


## Reads the lee from its .json file (the .bin file sits next to it). The config places its Swiss
## coordinates in the game. Returns null if it can't.
static func load_from(json_path: String, config: MapConfig) -> WindLee:
	var info: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not info is Dictionary:
		push_error("WindLee: can't read %s" % json_path)
		return null
	var lee: WindLee = WindLee.new()
	lee.columns = int(info["columns"])
	lee.rows = int(info["rows"])
	lee.cell_m = float(info["cell_m"])
	var first_centre: Vector3 = config.lv95_to_game(float(info["west_m"]) + lee.cell_m / 2.0,
		float(info["north_m"]) - lee.cell_m / 2.0, config.lake_level_m)
	lee.x0_m = first_centre.x
	lee.z0_m = first_centre.z
	lee.band_lee_at_reference = float(info["band_lee_at_reference"])
	lee.per_degree_right = float(info["band_lee_per_degree_right"])
	lee.per_lake_knot = float(info["band_lee_per_lake_knot"])
	lee.reference_from_deg = float(info["reference_lake_from_deg"])
	lee.reference_kt = float(info["reference_lake_kt"])
	lee.degrees_measured = Vector2(info["degrees_measured"][0], info["degrees_measured"][1])
	lee.knots_measured = Vector2(info["lake_knots_measured"][0], info["lake_knots_measured"][1])
	lee.band_lee_average = float(info["band_lee_average"])
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(json_path.get_base_dir().path_join(str(info["file"])))
	var cells: int = lee.columns * lee.rows
	if bytes.size() != cells * 2 * 4:
		push_error("WindLee: %s has %d bytes, expected %d" % [info["file"], bytes.size(), cells * 2 * 4])
		return null
	lee._shape = bytes.slice(0, cells * 4).to_float32_array()
	lee._held = bytes.slice(cells * 4).to_float32_array()
	return lee


## The lee's shape and what the fixed pattern holds of it at a game position:
## Vector2(shape, held), interpolated between the four nearest cell centres; 0 outside the grid.
func at(x: float, z: float) -> Vector2:
	var fx: float = (x - x0_m) / cell_m
	var fz: float = (z - z0_m) / cell_m
	if fx < 0.0 or fz < 0.0 or fx > columns - 1.0 or fz > rows - 1.0:
		return Vector2.ZERO
	var column: int = mini(int(fx), columns - 2)
	var row: int = mini(int(fz), rows - 2)
	var tx: float = fx - column
	var tz: float = fz - row
	var i: int = row * columns + column
	var north: Vector2 = Vector2(_shape[i], _held[i]).lerp(Vector2(_shape[i + 1], _held[i + 1]), tx)
	i += columns
	var south: Vector2 = Vector2(_shape[i], _held[i]).lerp(Vector2(_shape[i + 1], _held[i + 1]), tx)
	return north.lerp(south, tz)


## The band's lee for the lake's wind at a moment (where it comes from, degrees; its speed, knots),
## from the photos' fit, as a share of the wind; never below 0.
func band_lee(from_deg: float, lake_kt: float) -> float:
	var degrees: float = clampf(wrapf(from_deg - reference_from_deg, -180.0, 180.0), degrees_measured.x, degrees_measured.y)
	var knots: float = clampf(lake_kt - reference_kt, knots_measured.x, knots_measured.y)
	return maxf(band_lee_at_reference + per_degree_right * degrees + per_lake_knot * knots, 0.0)


## The lee for the graphics card, one pixel per cell, north row first: red the shape, green held.
func to_image() -> Image:
	var data: PackedFloat32Array = PackedFloat32Array()
	data.resize(columns * rows * 2)
	for i: int in columns * rows:
		data[2 * i] = _shape[i]
		data[2 * i + 1] = _held[i]
	return Image.create_from_data(columns, rows, false, Image.FORMAT_RGF, data.to_byte_array())


## Gives a wind shader (one that includes wind_pattern.gdshaderinc) this lee: the texture made from
## to_image(), where the cells lie, and the photos' fit.
func set_shader_lee(material: ShaderMaterial, texture: Texture2D) -> void:
	material.set_shader_parameter("shore_lee", texture)
	material.set_shader_parameter("lee_origin_m", Vector2(x0_m, z0_m))
	material.set_shader_parameter("lee_cell_m", cell_m)
	material.set_shader_parameter("lee_cells", Vector2(columns, rows))
	material.set_shader_parameter("lee_fit", Vector3(band_lee_at_reference, per_degree_right, per_lake_knot))
	material.set_shader_parameter("lee_reference", Vector2(reference_from_deg, reference_kt))
	material.set_shader_parameter("lee_ranges", Vector4(degrees_measured.x, degrees_measured.y, knots_measured.x, knots_measured.y))
	material.set_shader_parameter("lee_enabled", 1.0)
