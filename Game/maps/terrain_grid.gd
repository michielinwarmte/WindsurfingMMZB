class_name TerrainGrid
extends RefCounted
## A map's height grid for the game logic (Documentation/MAP_SILVAPLANA_PLAN.md, MD3: the
## meshes are for the looks, the grids for the logic). It answers "how high is the ground here?"
## for any game position, so the game can find the water depth under the board and the
## shoreline (M3) without looking at the meshes. A nicer mesh can then never change the sailing.
##
## Heights are metres above the lake surface, the game's Y: the water is at 0 and the lakebed
## is below it. The grid is regular in game X (east) and Z (south), and the heights in between
## are interpolated. Written by tools/map/heights.py as a .bin of 16-bit numbers and a .json that
## says how to read it.

## Number of values west to east and north to south.
var columns: int = 0
var rows: int = 0
## Distance between two values, in metres.
var cell_m: float = 0.0
## Game position of the first value, the north-west corner (north is -Z).
var x0_m: float = 0.0
var z0_m: float = 0.0

var _scale_m: float = 0.0
var _offset_m: float = 0.0
var _values: PackedByteArray


## Reads a grid from its .json file (the .bin file sits next to it). Returns null if it can't.
static func load_from(json_path: String) -> TerrainGrid:
	var text: String = FileAccess.get_file_as_string(json_path)
	var info: Variant = JSON.parse_string(text)
	if not info is Dictionary:
		push_error("TerrainGrid: can't read %s" % json_path)
		return null
	var grid: TerrainGrid = TerrainGrid.new()
	grid.columns = int(info["columns"])
	grid.rows = int(info["rows"])
	grid.cell_m = float(info["cell_m"])
	grid.x0_m = float(info["x0_m"])
	grid.z0_m = float(info["z0_m"])
	grid._scale_m = float(info["height_scale_m"])
	grid._offset_m = float(info["height_offset_m"])
	grid._values = FileAccess.get_file_as_bytes(json_path.get_base_dir().path_join(str(info["file"])))
	if grid._values.size() != grid.columns * grid.rows * 2:
		push_error("TerrainGrid: %s has %d bytes, expected %d" % [info["file"], grid._values.size(), grid.columns * grid.rows * 2])
		return null
	return grid


## Whether a game position (only X and Z count) lies on the grid.
func contains(x: float, z: float) -> bool:
	return x >= x0_m and x <= x0_m + (columns - 1) * cell_m and z >= z0_m and z <= z0_m + (rows - 1) * cell_m


## The ground height above the lake surface at a game position, interpolated between the four
## nearest values. NAN outside the grid.
func height_at(x: float, z: float) -> float:
	if not contains(x, z):
		return NAN
	var fx: float = (x - x0_m) / cell_m
	var fz: float = (z - z0_m) / cell_m
	var column: int = mini(int(fx), columns - 2)
	var row: int = mini(int(fz), rows - 2)
	var tx: float = fx - column
	var tz: float = fz - row
	var north: float = lerpf(_value(row, column), _value(row, column + 1), tx)
	var south: float = lerpf(_value(row + 1, column), _value(row + 1, column + 1), tx)
	return lerpf(north, south, tz)


func _value(row: int, column: int) -> float:
	return _offset_m + _values.decode_u16(2 * (row * columns + column)) * _scale_m
