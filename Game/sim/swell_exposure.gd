class_name SwellExposure
extends RefCounted
## How much of an ocean swell reaches each part of a sea spot (PHYSICS_SPEC.md 9.20): on a coarse grid
## over the spot's map, for every direction the swell can come from, the share of its energy that
## arrives from the open ocean over water, its directions spread as a real swell's are
## (cos^40((theta - theta0) / 2)), worked out once from the region's bathymetry
## (tools/map/spot_sea.py, the spot's sea.json, "swell_exposure"). Fuerteventura, Sotavento: the
## North Atlantic's N to NW swell 0 (the island is in the way), the trade wind's NE swell about 0.2,
## the ENE 0.47, the E to S about 1.

var cell_m: float = 200.0
var x0_m: float = 0.0
var z0_m: float = 0.0
var columns: int = 0
var rows: int = 0
var direction_step_deg: float = 10.0
## Per direction, the shares (0 to 255) row by row from the north.
var shares: Array[PackedByteArray] = []


## Reads the exposure from a spot's sea.json; null when the file has none.
static func load_from(json_path: String) -> SwellExposure:
	var info: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not info is Dictionary or not (info as Dictionary).has("swell_exposure"):
		push_error("SwellExposure: no swell_exposure in %s" % json_path)
		return null
	var data: Dictionary = (info as Dictionary)["swell_exposure"]
	var exposure: SwellExposure = SwellExposure.new()
	exposure.cell_m = float(data["cell_m"])
	exposure.x0_m = float(data["x0_m"])
	exposure.z0_m = float(data["z0_m"])
	exposure.columns = int(data["columns"])
	exposure.rows = int(data["rows"])
	exposure.direction_step_deg = float(data["direction_step_deg"])
	for values: Array in data["exposure_255"]:
		exposure.shares.append(PackedByteArray(values))
	return exposure


## The share (0 to 1) of a swell from from_deg that reaches a game position: between the four nearest
## nodes and the two nearest directions; at the grid's edge the edge's value.
func share_at(x: float, z: float, from_deg: float) -> float:
	var at: float = fposmod(from_deg, 360.0) / direction_step_deg
	var below: int = floori(at) % shares.size()
	var above: int = (below + 1) % shares.size()
	var t: float = at - floorf(at)
	return lerpf(_share_in(shares[below], x, z), _share_in(shares[above], x, z), t)


func _share_in(values: PackedByteArray, x: float, z: float) -> float:
	var fx: float = clampf((x - x0_m) / cell_m, 0.0, columns - 1.001)
	var fz: float = clampf((z - z0_m) / cell_m, 0.0, rows - 1.001)
	var column: int = int(fx)
	var row: int = int(fz)
	var tx: float = fx - column
	var tz: float = fz - row
	var north: float = lerpf(values[row * columns + column], values[row * columns + column + 1], tx)
	var south: float = lerpf(values[(row + 1) * columns + column], values[(row + 1) * columns + column + 1], tx)
	return lerpf(north, south, tz) / 255.0
