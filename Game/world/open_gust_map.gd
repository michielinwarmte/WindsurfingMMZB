class_name OpenGustMap
extends SubViewport
## The gusts on the open water (ROADMAP GR2 and PH7): a small picture of the wind's patches
## (WindField with WindConfig.gust_patches) over an area around the board, drawn by the graphics
## card every frame (open_gusts.gdshader), that the game's water uses to make its ripples stronger
## and its mirror rougher in a gust and weaker in a lull (water.gdshader's wind_ripple_map;
## OceanNode.set_water_parameter()). Seen from the board, the gusts come down the water as darker,
## rougher patches, the way sailors spot them. The lake has its own picture over its fixed area
## (WindRippleMap); this one follows the board, because the open water has no edges.
##
## The graphics card computes the same sums as WindField.patch_unit_at(), so the patches are where
## the physics feels the gusts; main.gd --check-gusts=1 reads the picture back and compares.
##
## Use: setup() once, follow() every frame with the field and the board's position, and
## put_on_water() whenever the water is built (it hands the water the texture and the area).

const SHADER: Shader = preload("res://world/open_gusts.gdshader")
## The picture's side (m) and its pixels: 10 m per pixel, with the lanes 100 m across. Beyond the
## edge the water keeps the edge's value (the texture does not repeat), which is far away.
const AREA_SIDE_M: float = 2560.0
const PIXELS: int = 256

## The area the picture covers: x and z of its north-west corner, its width and depth (m).
var area_xz: Rect2 = Rect2()
var _material: ShaderMaterial
## The pattern the shader's constants were set for (null: a flat picture).
var _constants_of: WindGusts = null
var _constants_set: bool = false


## Makes the picture: PIXELS x PIXELS, drawn every frame.
func setup() -> void:
	size = Vector2i(PIXELS, PIXELS)
	disable_3d = true
	transparent_bg = false
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	var canvas: ColorRect = ColorRect.new()
	canvas.name = "GustPicture"
	canvas.material = _material
	canvas.size = Vector2(PIXELS, PIXELS)
	add_child(canvas)


## The wind of this moment and where the board is, for the next frame's picture: the area is
## centred on the board. Without patches (the gusts off, or the sines) the picture is flat: the
## water's normal ripples everywhere.
func follow(wind: WindField, centre: Vector3) -> void:
	area_xz = Rect2(centre.x - AREA_SIDE_M / 2.0, centre.z - AREA_SIDE_M / 2.0, AREA_SIDE_M, AREA_SIDE_M)
	var pattern: WindGusts = wind.pattern()
	if not _constants_set or pattern != _constants_of:
		_set_constants(pattern)
	_material.set_shader_parameter("area_m", area_vector())
	_material.set_shader_parameter("spread_share", wind.patch_spread_share())
	_material.set_shader_parameter("lake_axis", wind.downwind_axis())
	_material.set_shader_parameter("travel_m", wind.travel_m)
	_material.set_shader_parameter("time_of_day_s", wind.time_s)


## The area as the water shader's wind_ripple_map_area wants it.
func area_vector() -> Vector4:
	return Vector4(area_xz.position.x, area_xz.position.y, area_xz.size.x, area_xz.size.y)


## Hands the water the picture and its area: once, and again whenever the water is built anew.
func put_on_water(ocean: OceanNode) -> void:
	ocean.set_water_parameter("wind_ripple_map", get_texture())
	move_on_water(ocean)


## The area moves with the board: every frame after follow().
func move_on_water(ocean: OceanNode) -> void:
	ocean.set_water_parameter("wind_ripple_map_area", area_vector())


## What the shader needs of the pattern, set once per pattern (the gusts' part of
## MapWind.shader_constants()). With no pattern the weights are zero: the picture is flat.
func _set_constants(pattern: WindGusts) -> void:
	_constants_of = pattern
	_constants_set = true
	if pattern == null:
		_material.set_shader_parameter("gust_weights", Vector2.ZERO)
		return
	_material.set_shader_parameter("gust_sideways_share", pattern.sideways_share)
	_material.set_shader_parameter("gust_weights", Vector2(sqrt(pattern.front_share), sqrt(1.0 - pattern.front_share)))
	_material.set_shader_parameter("front_cells", Vector3(pattern.front_cell_along_m, pattern.front_cell_across_m, pattern.front_life_s))
	_material.set_shader_parameter("lane_cells", Vector3(pattern.lane_cell_along_m, pattern.lane_cell_across_m, pattern.lane_life_s))
	_material.set_shader_parameter("gust_stream", pattern.seed * 4)
