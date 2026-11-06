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
## The most room to the land that counts (openness_m()), metres: beyond it all water is as good.
const MOST_ROOM_M: float = 250.0
## Finding the way out (most_open_heading_deg()): how many headings are tried, and how far ahead
## their water is looked at, metres.
const HEADINGS: int = 24
const ESCAPE_LOOK_M: float = 60.0

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


## How open the water at a point is, metres: its room to the nearest land (at most MOST_ROOM_M); 0 on
## land, off the grid, or where it is too shallow.
func openness_m(point: Vector2) -> float:
	if not _grid.contains(point.x, point.y) or -_grid.height_at(point.x, point.y) < DEEP_M:
		return 0.0
	if _clearance == null:
		return MOST_ROOM_M
	return minf(_clearance.clearance_m(point), MOST_ROOM_M)


## The compass heading from a point toward the most open water near it: of HEADINGS headings round
## the compass, the one whose water is most open ESCAPE_LOOK_M and twice that ahead (a board that has
## got into the shallows or close to the land heads that way).
func most_open_heading_deg(from: Vector2) -> float:
	var best_deg: float = 0.0
	var best_m: float = -1.0
	for i: int in HEADINGS:
		var heading_deg: float = 360.0 * i / HEADINGS
		var way: Vector2 = Course.direction_of(heading_deg)
		var open_m: float = openness_m(from + way * ESCAPE_LOOK_M) + openness_m(from + way * ESCAPE_LOOK_M * 2.0)
		if open_m > best_m:
			best_m = open_m
			best_deg = heading_deg
	return best_deg


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
