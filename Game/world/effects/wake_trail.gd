class_name WakeTrail
extends MeshInstance3D
## The wake and foam trail behind the board: a ribbon on the water from the tail backward,
## built from points the tail leaves behind as it moves (one every POINT_SPACING_M), so a
## board at rest leaves nothing. Each point remembers when it was made and how strong the
## wake was there (wake_strength(): faster and planing makes more white water). The ribbon
## widens as it ages (the turbulent wake spreads) and fades out after LIFETIME_S.
##
## The vertices are rest positions on the still water; res://world/effects/wake_foam.gdshader
## lifts them onto the waves with the same wave formulas as the water, so the foam never
## floats above or sinks under a wave. A look only: nothing feeds back into the physics.

## A new point after the tail has moved this far.
const POINT_SPACING_M: float = 0.5
## The foam fades out over this time.
const LIFETIME_S: float = 7.0
## The wake starts this wide (a share of the board's width: the wet part of a planing
## bottom is narrower than the deck) and spreads by this much per second.
const START_WIDTH_SHARE: float = 0.7
const SPREAD_MS: float = 0.25
## The wake grows from nothing at WAKE_START_MS to full at WAKE_FULL_MS.
const WAKE_START_MS: float = 0.8
const WAKE_FULL_MS: float = 5.0
const MAX_POINTS: int = 256

var _sim: WindsurferSim
var _mesh: ImmediateMesh = ImmediateMesh.new()
var _material: ShaderMaterial = ShaderMaterial.new()
var _start_width_m: float = 0.5
## The trail, oldest first: rest position (x, z), the time it was made, its strength.
var _positions: PackedVector2Array = PackedVector2Array()
var _born_s: PackedFloat64Array = PackedFloat64Array()
var _strengths: PackedFloat64Array = PackedFloat64Array()
## The tail now (moves with the interpolated board every frame).
var _tail_xz: Vector2 = Vector2.ZERO
var _tail_strength: float = 0.0
var _has_tail: bool = false


## How strong the wake is (0 to 1) at this speed and share of planing: a slow board pushes
## a little wave aside, a planing board leaves a broad trail of white water.
static func wake_strength(speed_ms: float, planing_ratio: float) -> float:
	var speed_share: float = smoothstep(WAKE_START_MS, WAKE_FULL_MS, speed_ms)
	return speed_share * lerpf(0.35, 1.0, clampf(planing_ratio, 0.0, 1.0))


func setup(sim: WindsurferSim) -> void:
	_sim = sim
	name = "Wake"
	top_level = true
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The trail can be long: never cull it.
	extra_cull_margin = 16384.0
	_start_width_m = sim.board_config.width_m * START_WIDTH_SHARE
	_material.shader = load("res://world/effects/wake_foam.gdshader") as Shader
	_material.set_shader_parameter("foam_noise", _foam_noise())
	_material.set_shader_parameter("base_height_m", sim.water_config.base_height_m)
	var field: WaveField = sim.water as WaveField
	if field != null:
		var parameters: Dictionary[String, Variant] = field.shader_parameters()
		for key: String in parameters:
			if key != "base_height_m":
				_material.set_shader_parameter(key, parameters[key])
	material_override = _material


## Forgets the trail (after a reset: the board jumps back to the start).
func clear() -> void:
	_positions.clear()
	_born_s.clear()
	_strengths.clear()
	_has_tail = false


## One physics tick: the tail's world position and how strong the wake is now.
func add_tail(tail_world: Vector3, strength: float) -> void:
	var tail: Vector2 = Vector2(tail_world.x, tail_world.z)
	_tail_strength = strength
	if _positions.is_empty() or tail.distance_to(_positions[_positions.size() - 1]) >= POINT_SPACING_M:
		_positions.append(tail)
		_born_s.append(_sim.time_s)
		_strengths.append(strength)
	while _positions.size() > MAX_POINTS or (not _born_s.is_empty() and _sim.time_s - _born_s[0] > LIFETIME_S):
		_positions.remove_at(0)
		_born_s.remove_at(0)
		_strengths.remove_at(0)


## Every frame: the newest end follows the tail as drawn (the interpolated board), and the
## water's clock goes on as smoothly as the waves.
func follow_tail(tail_world: Vector3, time_s: float) -> void:
	_tail_xz = Vector2(tail_world.x, tail_world.z)
	_has_tail = true
	_material.set_shader_parameter("water_time_s", time_s)
	_rebuild(time_s)


func point_count() -> int:
	return _positions.size()


func _rebuild(time_s: float) -> void:
	_mesh.clear_surfaces()
	var count: int = _positions.size()
	if count == 0 or not _has_tail:
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var along_m: float = 0.0
	var previous: Vector2 = _positions[0]
	for i: int in count + 1:
		# The points from the oldest to the newest, then the tail itself.
		var at: Vector2 = _tail_xz if i == count else _positions[i]
		var age_s: float = 0.0 if i == count else time_s - _born_s[i]
		var strength: float = _tail_strength if i == count else _strengths[i]
		along_m += at.distance_to(previous)
		previous = at
		_add_cross_section(at, _direction_at(i, count), age_s, strength, along_m)
	_mesh.surface_end()


## The trail's direction at point i (toward the newer end), for its cross-section.
func _direction_at(i: int, count: int) -> Vector2:
	var before: Vector2 = _positions[maxi(i - 1, 0)]
	var after: Vector2 = _tail_xz if i + 1 >= count else _positions[i + 1]
	var direction: Vector2 = after - before
	return direction.normalized() if direction.length() > 1e-4 else Vector2(0.0, -1.0)


## Two vertices across the trail at a point, its width grown with age.
func _add_cross_section(at: Vector2, toward: Vector2, age_s: float, strength: float, along_m: float) -> void:
	var age_share: float = clampf(age_s / LIFETIME_S, 0.0, 1.0)
	var half_width: float = 0.5 * (_start_width_m + SPREAD_MS * age_s)
	var side: Vector2 = Vector2(-toward.y, toward.x) * half_width
	var color: Color = Color(age_share, 0.0, 0.0, strength)
	_mesh.surface_set_color(color)
	_mesh.surface_set_uv(Vector2(along_m, 0.0))
	_mesh.surface_add_vertex(Vector3(at.x + side.x, 0.0, at.y + side.y))
	_mesh.surface_set_color(color)
	_mesh.surface_set_uv(Vector2(along_m, 1.0))
	_mesh.surface_add_vertex(Vector3(at.x - side.x, 0.0, at.y - side.y))


## A seamless cloudy noise for breaking the foam into patches.
static func _foam_noise() -> NoiseTexture2D:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.03
	noise.fractal_octaves = 3
	var texture: NoiseTexture2D = NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.generate_mipmaps = true
	texture.noise = noise
	return texture
