class_name MapConfig
extends Resource
## Where a real-world map sits in the game (Documentation/MAP_SILVAPLANA_PLAN.md, MD1).
## Swiss LV95 coordinates are metres east and north, so the game uses them directly, moved to
## an origin near the middle of the lake: X = east, Y = up from the lake surface, Z = -north
## (main-plan D4). Each map has one .tres, written by its tools/map scripts.

@export var map_name: String = ""
## LV95 east of the game's origin, in metres.
@export var origin_east_m: float = 0.0
## LV95 north of the game's origin, in metres.
@export var origin_north_m: float = 0.0
## Height of the lake surface above sea level: the game's Y = 0, where the simulation's water is.
@export var lake_level_m: float = 0.0


## A Swiss LV95 point (east, north, height above sea level, all in metres) as a game position.
func lv95_to_game(east_m: float, north_m: float, height_m: float) -> Vector3:
	return Vector3(east_m - origin_east_m, height_m - lake_level_m, -(north_m - origin_north_m))


## A game position back in Swiss LV95: [east, north, height above sea level], in metres.
## A Vector3 has only 32-bit floats, too coarse for LV95's millions of metres, hence the array.
func game_to_lv95(point: Vector3) -> PackedFloat64Array:
	return PackedFloat64Array([
		origin_east_m + point.x,
		origin_north_m - point.z,
		lake_level_m + point.y,
	])
