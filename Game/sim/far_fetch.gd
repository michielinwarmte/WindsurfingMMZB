class_name FarFetch
extends RefCounted
## The open water upwind of a sea spot's map, beyond its edges (PHYSICS_SPEC.md 9.19): for points
## along the near grid's edges, the water the wind has blown over before it reaches the map, along
## every bearing the wind can come from, worked out once from the region's bathymetry
## (tools/map/spot_sea.py, the spot's sea.json, "far_fetch"). FetchMap starts a ray that leaves its
## grid with this, instead of zero, so a sea spot's wind sea grows over the whole channel and not
## only over the 12 km of its map (Fuerteventura, Sotavento: from the NE 71 km, the ENE 170 km).
## A lake has none (its shore is all inside its map).

## The bearings' spacing, degrees (the first is 0, north).
var bearing_step_deg: float = 5.0
## The edge points (game x, z) and, per point, the fetch (m) along each bearing.
var points: PackedVector2Array = PackedVector2Array()
var fetch_m: Array[PackedFloat32Array] = []


## Reads the far fetch from a spot's sea.json; null when the file has none.
static func load_from(json_path: String) -> FarFetch:
	var info: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if not info is Dictionary or not (info as Dictionary).has("far_fetch"):
		push_error("FarFetch: no far_fetch in %s" % json_path)
		return null
	var data: Dictionary = (info as Dictionary)["far_fetch"]
	var far: FarFetch = FarFetch.new()
	far.bearing_step_deg = float(data["bearing_step_deg"])
	for point: Array in data["points"]:
		far.points.append(Vector2(point[0], point[1]))
	for row: Array in data["fetch_m"]:
		far.fetch_m.append(PackedFloat32Array(row))
	return far


## The open water (m) upwind of a game position at the map's edge, for a wind from bearing_deg:
## from the nearest edge point, between the two nearest bearings.
func fetch_at(x: float, z: float, bearing_deg: float) -> float:
	var nearest: int = 0
	var nearest_m2: float = INF
	for i: int in points.size():
		var d2: float = points[i].distance_squared_to(Vector2(x, z))
		if d2 < nearest_m2:
			nearest_m2 = d2
			nearest = i
	var row: PackedFloat32Array = fetch_m[nearest]
	var steps: int = row.size()
	var at: float = fposmod(bearing_deg, 360.0) / bearing_step_deg
	var below: int = floori(at) % steps
	var above: int = (below + 1) % steps
	return lerpf(row[below], row[above], at - floorf(at))
