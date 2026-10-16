class_name WindRippleMap
extends SubViewport
## The gusts on the water (MAP_SILVAPLANA_PLAN.md W5; PHYSICS_REQUESTS_FROM_MAP.md R9): a small
## picture of the map's wind over the lake, drawn by the graphics card every frame
## (wind_ripple_map.gdshader), that the game's water uses to make its ripples stronger in a gust
## and weaker in a lull (water.gdshader's wind_ripple_map; OceanNode.set_water_parameter()). Seen
## from the board, the gusts come down the lake as darker, rougher patches, the way sailors spot
## them. The graphics card computes the same sums as MapWind.velocity_in(), so the patches are
## where the physics feels the gusts; in GDScript the 16 000 points of a 128 x 128 picture would
## take about 1.5 seconds.
##
## Use: setup() once, then show_moment() every frame with the wind of the moment, and hand
## get_texture() and area_vector() to the water.

const SHADER: Shader = preload("res://maps/wind/wind_ripple_map.gdshader")

## The area the picture covers: x and z of its north-west corner, its width and depth (m).
var area_xz: Rect2 = Rect2()
var _material: ShaderMaterial


## Draws the picture of `wind` over `area` with `pixels` x `pixels` pixels. The pattern texture
## (WindPattern.to_image(); its blue channel, the ground's height, is not used here) and the lee
## texture are uploaded once.
func setup(wind: MapWind, area: Rect2, ground: TerrainGrid, pixels: int = 256) -> void:
	area_xz = area
	size = Vector2i(pixels, pixels)
	disable_3d = true
	transparent_bg = false
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	wind.pattern.set_shader_pattern(_material, ImageTexture.create_from_image(wind.pattern.to_image(ground)))
	if wind.lee != null:
		wind.lee.set_shader_lee(_material, ImageTexture.create_from_image(wind.lee.to_image()))
	_set_parameters(wind.shader_constants())
	_material.set_shader_parameter("area_m", area_vector())
	var canvas: ColorRect = ColorRect.new()
	canvas.name = "WindPicture"
	canvas.material = _material
	canvas.size = Vector2(pixels, pixels)
	add_child(canvas)


## The wind of this moment (MapWind.moment()), for the next frame's picture.
func show_moment(now: WindMoment) -> void:
	_set_parameters(now.shader_parameters())


## The area as the water shader's wind_ripple_map_area wants it.
func area_vector() -> Vector4:
	return Vector4(area_xz.position.x, area_xz.position.y, area_xz.size.x, area_xz.size.y)


func _set_parameters(parameters: Dictionary[String, Variant]) -> void:
	for key: String in parameters:
		_material.set_shader_parameter(key, parameters[key])
