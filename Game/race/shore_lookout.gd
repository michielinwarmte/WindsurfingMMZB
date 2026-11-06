class_name ShoreLookout
extends RefCounted
## What an AI skipper sees of a lake's shore while it races (Max, 6 November 2026: "be sure that the
## ai can race all the iq courses on silvaplana without going onto the shore"): how far it can sail
## on a heading before the water gets too shallow or too near the land. The skipper looks ahead along
## its heading before every decision and tacks, gybes or turns away in time (Skipper's
## _keep_off_the_shore()). One lookout serves the whole fleet; it only reads the lake's depth grid.
##
## Open water is water at least DEEP_M deep (a fin is 0.4 to 0.5 m long; ShoreCheck calls a board
## aground under its fin's depth and a margin) and at least ROOM_M from the nearest land: the
## shallows off the deltas reach far out from the shoreline, so the depth decides there, and the
## distance where the bottom drops steeply. On the open water there is no lookout (null).

## The least depth a board sails into, metres.
const DEEP_M: float = 2.0
## The least room to the nearest land, metres.
const ROOM_M: float = 40.0
## The path ahead is looked at every this many metres.
const STEP_M: float = 10.0

var _grid: TerrainGrid = null
var _clearance: CourseFitter = null


## A lookout for the lake around a point on it (the course's start), from its depth grid.
static func for_lake(grid: TerrainGrid, inside: Vector2) -> ShoreLookout:
	if grid == null:
		return null
	var lookout: ShoreLookout = ShoreLookout.new()
	lookout._grid = grid
	var fitter: CourseFitter = CourseFitter.from_heights(grid.height_at, inside)
	lookout._clearance = fitter if fitter.has_water() else null
	return lookout


## Whether a board may sail at this point (game X, Z): deep enough, with room to the land.
func is_open(point: Vector2) -> bool:
	if not _grid.contains(point.x, point.y):
		return false
	if -_grid.height_at(point.x, point.y) < DEEP_M:
		return false
	return _clearance == null or _clearance.clearance_m(point) >= ROOM_M


## How far a board can sail from a point on a compass heading before the open water ends, metres;
## `look_m` (or more) when it does not end that soon.
func water_ahead_m(from: Vector2, heading_deg: float, look_m: float) -> float:
	var way: Vector2 = Course.direction_of(heading_deg)
	var distance_m: float = STEP_M
	while distance_m <= look_m:
		if not is_open(from + way * distance_m):
			return distance_m - STEP_M
		distance_m += STEP_M
	return look_m
