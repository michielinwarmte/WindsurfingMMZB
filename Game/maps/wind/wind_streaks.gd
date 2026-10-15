class_name WindStreaks
extends GPUParticles3D
## The wind viewer's white streaks (MAP_SILVAPLANA_PLAN.md, W2), like on the Windfinder map: a few
## thousand particles that ride the map's wind a little above the ground and the water, each drawn
## as a short ribbon along its recent path. The graphics card moves them (wind_streaks.gdshader),
## with the same wind as MapWind (WD1).
##
## They start in a square around what the camera looks at, and move faster than the real wind
## (speed_up) so you can follow them: the bigger the view, the faster, so they cross the screen in
## about the same time at every zoom. Seen from the water they move at about the real speed.

const MOVE_SHADER: Shader = preload("res://maps/wind/wind_streaks.gdshader")
const DRAW_SHADER: Shader = preload("res://maps/wind/wind_streak.gdshader")
## Seen from the water the streaks still move at least this many times faster than the wind, or
## they would be dots.
const MIN_SPEED_UP: float = 4.0

## How many streaks are on the screen at once.
@export var streak_count: int = 5000
## How long one streak lives, in seconds, before it starts again somewhere else.
@export var life_s: float = 3.0
## How long the white tail behind a streak is, in seconds of its path.
@export var tail_s: float = 0.3
## How wide a streak is on the screen, in pixels.
@export var width_px: float = 2.0
## The speed-up for each metre of the view's size (see follow()). Changed with the [ and ] keys in
## the wind viewer.
@export var speed_up_per_metre: float = 1.0 / 40.0

## How many times faster than the real wind the streaks move right now.
var speed_up: float = 1.0

var _move: ShaderMaterial


## Sets the streaks up for a map's wind: its pattern and its lee, each as a texture (to_image()),
## and what never changes about its gusts.
func setup(wind: MapWind, pattern_texture: Texture2D, lee_texture: Texture2D) -> void:
	_move = ShaderMaterial.new()
	_move.shader = MOVE_SHADER
	wind.pattern.set_shader_pattern(_move, pattern_texture)
	if wind.lee != null:
		wind.lee.set_shader_lee(_move, lee_texture)
	set_wind(wind.shader_constants())
	process_material = _move

	var draw: ShaderMaterial = ShaderMaterial.new()
	draw.shader = DRAW_SHADER
	# Drawn after the speed colours on the water, so the streaks lie on top of them.
	draw.render_priority = 2
	var ribbon: RibbonTrailMesh = RibbonTrailMesh.new()
	ribbon.shape = RibbonTrailMesh.SHAPE_CROSS
	ribbon.size = 1.0  # the particle's X axis (and Z axis) sets the real width
	ribbon.sections = 8
	ribbon.section_segments = 2
	ribbon.material = draw
	draw_pass_1 = ribbon

	amount = streak_count
	lifetime = life_s
	trail_enabled = true
	trail_lifetime = tail_s
	fixed_fps = 60
	interpolate = true
	# The streaks are spread over the whole valley: never cull them as "off screen".
	visibility_aabb = AABB(Vector3(-30000.0, -2000.0, -30000.0), Vector3(60000.0, 6000.0, 60000.0))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	emitting = true


## The wind at the moment (WindMoment.shader_parameters()), or what never changes (MapWind.shader_constants()).
func set_wind(parameters: Dictionary[String, Variant]) -> void:
	for key: String in parameters:
		_move.set_shader_parameter(key, parameters[key])


## Moves the square where new streaks start (its centre, a game position, and half its width) to
## what the camera looks at. view_size_m says how big the view is: the camera's height for a map
## camera, more for a camera looking into the distance; it sets the speed-up. camera_height_m is
## the camera's height above the ground or water below it. Call it every frame.
func follow(camera: Camera3D, centre: Vector3, half_size_m: float, view_size_m: float, camera_height_m: float) -> void:
	speed_up = clampf(view_size_m * speed_up_per_metre, MIN_SPEED_UP, 500.0)
	_move.set_shader_parameter("spawn_centre_m", Vector2(centre.x, centre.z))
	_move.set_shader_parameter("spawn_half_size_m", half_size_m)
	_move.set_shader_parameter("speed_up", speed_up)
	_move.set_shader_parameter("camera_position", camera.global_position)
	# Metres per pixel at 1 m from the camera: the screen's height covers 2 tan(fov / 2) there.
	var screen_height_px: float = maxf(get_viewport().get_visible_rect().size.y, 1.0)
	_move.set_shader_parameter("width_per_metre", width_px * 2.0 * tan(deg_to_rad(camera.fov) / 2.0) / screen_height_px)
	# Well below the camera's eye, so seen from the water they lie on the water, not in the sky.
	_move.set_shader_parameter("lift_m", clampf(camera_height_m * 0.25, 0.3, 15.0))
