class_name MiniMap
extends Control
## A small map of the lake in the HUD (MAP_SILVAPLANA_PLAN.md, M3), only in a map scene: the
## lake's outline (from LakeArea, drawn once), the start spot as a ring, the board as a dot with
## a tick toward its heading, and the wind as an arrow in the corner that points the way the
## wind blows. North is up, as on the compass (MD1: north is -Z in the game too).

## The longer side of the map on the screen, in pixels.
const SIZE_PX: float = 200.0
## Land shown around the lake, in metres.
const BORDER_M: float = 120.0
const WATER_COLOR: Color = Color(0.2, 0.42, 0.55, 0.85)
const LAND_COLOR: Color = Color(0.16, 0.2, 0.14, 0.6)
const BOARD_COLOR: Color = Color(1.0, 0.6, 0.1)
const START_COLOR: Color = Color(1.0, 1.0, 1.0, 0.85)
const WIND_COLOR: Color = Color(0.5, 0.85, 1.0)

var board_position: Vector3 = Vector3.ZERO
var heading_deg: float = 0.0
var wind_from_deg: float = 0.0

var _texture: ImageTexture
## The part of the world shown, in game metres: position = (west X, north Z).
var _shown: Rect2
## Where the image's top-left corner is in the world, and how many metres one pixel covers.
var _image_origin: Vector2
var _metres_per_pixel: float = 1.0
var _start: Vector3 = Vector3.ZERO


## Draws the lake once and sizes the map to the lake's shape.
func setup(area: LakeArea, start: Vector3) -> void:
	_texture = ImageTexture.create_from_image(area.make_image(WATER_COLOR, LAND_COLOR))
	_metres_per_pixel = area.step_m
	# A pixel stands for the square around its spot, so the image starts half a step earlier.
	_image_origin = Vector2(area.x0_m, area.z0_m) - Vector2.ONE * area.step_m * 0.5
	_shown = area.lake_bounds().grow(BORDER_M)
	_start = start
	var pixels_per_metre: float = SIZE_PX / maxf(_shown.size.x, _shown.size.y)
	custom_minimum_size = _shown.size * pixels_per_metre
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


## Where a game position is on the map, in pixels from the map's top-left corner.
func map_point(at: Vector3) -> Vector2:
	return (Vector2(at.x, at.z) - _shown.position) / _shown.size * size


func _draw() -> void:
	if _texture == null:
		return
	var source: Rect2 = Rect2((_shown.position - _image_origin) / _metres_per_pixel, _shown.size / _metres_per_pixel)
	draw_texture_rect_region(_texture, Rect2(Vector2.ZERO, size), source)
	draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 1.0, 1.0, 0.5), false, 1.0)
	draw_arc(map_point(_start), 5.0, 0.0, TAU, 16, START_COLOR, 1.5)
	_draw_board()
	_draw_wind_arrow()


## The board: a dot, and a tick toward its heading. Bearings are clockwise from North and the
## screen's y points down, so bearing b points along (sin b, -cos b).
func _draw_board() -> void:
	var at: Vector2 = map_point(board_position)
	var heading: Vector2 = Vector2(sin(deg_to_rad(heading_deg)), -cos(deg_to_rad(heading_deg)))
	draw_line(at, at + heading * 12.0, BOARD_COLOR, 2.0)
	draw_circle(at, 4.0, BOARD_COLOR)


## The wind in the top-left corner: the arrow points the way the wind blows (it comes FROM the tail).
func _draw_wind_arrow() -> void:
	var centre: Vector2 = Vector2(22.0, 22.0)
	var from: Vector2 = Vector2(sin(deg_to_rad(wind_from_deg)), -cos(deg_to_rad(wind_from_deg)))
	var tail: Vector2 = centre + from * 14.0
	var head: Vector2 = centre - from * 14.0
	draw_line(tail, head, WIND_COLOR, 2.5)
	var wing: Vector2 = Vector2(from.y, -from.x) * 5.0
	draw_colored_polygon(PackedVector2Array([head, head + from * 8.0 + wing, head + from * 8.0 - wing]), WIND_COLOR)
