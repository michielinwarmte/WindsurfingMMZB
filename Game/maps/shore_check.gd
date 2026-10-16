class_name ShoreCheck
extends RefCounted
## The shore of a map, without collision physics (MAP_SILVAPLANA_PLAN.md, MD6): the depth grid
## (TerrainGrid) says how deep the water is under the board, and where it is shallower than the
## fin plus a margin, the board has run aground. The sailing scene (main.gd) then stops the
## simulation and offers the way back to the start. Nothing here pushes on the board: the map
## sets the scene, the physics stays the physics (rule 2).
## Off the grid counts as aground too, so you cannot sail off the map.

## Water this much deeper than the fin still counts as too shallow: room for the waves and for
## the board's heel, so the fin never looks as if it cuts through the lakebed.
const MARGIN_M: float = 0.12


## The water depth at a game position (only X and Z count), in metres: the lake surface is at
## Y = 0 and the grid's heights are negative under water. Negative on land, NAN off the grid.
static func depth_at(grid: TerrainGrid, at: Vector3) -> float:
	if not grid.contains(at.x, at.z):
		return NAN
	return -grid.height_at(at.x, at.z)


## Whether a board with a fin this deep (FinConfig.span_m) has run aground at this position.
static func is_aground(grid: TerrainGrid, at: Vector3, fin_depth_m: float) -> bool:
	var depth_m: float = depth_at(grid, at)
	if is_nan(depth_m):
		return true
	return depth_m < fin_depth_m + MARGIN_M
