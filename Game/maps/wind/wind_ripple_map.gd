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


## The green channel's average: the wind of the last `seconds` (the lake's short wave train's response
## time, LakeWaves.look_response_s); 0: the wind of the moment.
func set_recent_time(seconds: float) -> void:
	_material.set_shader_parameter("recent_s", seconds)


## The wind relative to the lake's mean over the last `seconds` at a game position, as the green
## channel computes it (for the check against MapWind): the same three points downwind and weights.
static func recent_ratio(wind: MapWind, now: WindMoment, x: float, z: float, seconds: float) -> float:
	var nodes: Vector3 = Vector3(0.415775, 2.294280, 6.289945)
	var weights: Vector3 = Vector3(0.711093, 0.278518, 0.0103893)
	var at: Vector3 = Vector3(x, 0.0, z)
	if seconds <= 0.0:
		return wind.velocity_in(now, at).length() / maxf(now.lake_speed_ms, 0.1)
	var back: Vector2 = wind.lake_axis * now.drift_ms * seconds
	var ratio: float = 0.0
	for i: int in 3:
		var point: Vector3 = at + Vector3(back.x, 0.0, back.y) * nodes[i]
		ratio += weights[i] * wind.velocity_in(now, point).length() / maxf(now.lake_speed_ms, 0.1)
	return ratio


## The area as the water shader's wind_ripple_map_area wants it.
func area_vector() -> Vector4:
	return Vector4(area_xz.position.x, area_xz.position.y, area_xz.size.x, area_xz.size.y)


func _set_parameters(parameters: Dictionary[String, Variant]) -> void:
	for key: String in parameters:
		_material.set_shader_parameter(key, parameters[key])
