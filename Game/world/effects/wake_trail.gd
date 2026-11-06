class_name WakeTrail
extends MeshInstance3D
## The wake and foam trail behind the board: a ribbon on the water from the tail backward,
## built from points the tail leaves behind as it moves (one every POINT_SPACING_M), so a
## board at rest leaves nothing. Each point remembers when it was made, how strong the wake
## was there (wake_strength(): faster and planing makes more white water), how fast it spreads
## (faster boards leave a wake that widens faster) and how the board was carving (the inside,
## low rail leaves the whiter line). The ribbon widens as it ages and fades out after LIFETIME_S.
##
## Two more things are drawn in the same mesh, with the same material:
## - the bow wave of a board at displacement speed (bow_wave_strength()): a V of two thin lines
##   from the bow at Kelvin's angle, ARM_ANGLE_DEG either side of the track, the wave pattern of
##   any slow hull (it does not depend on the speed; Rabaud and Moisy 2013 measured 18.6 +/- 1.8
##   degrees up to a hull Froude number of about 0.5, about 2.4 m/s for a 2.4 m board; a planing
##   board's wake is much narrower, so the V fades as the board planes);
## - patches of foam where a hard landing or a fall splashed (add_foam_patch()), fading as the
##   foam of a whitecap does (FOAM_LIFE_FRESH_S on the lake, FOAM_LIFE_SEA_S at sea: Monahan and
##   Zietlow 1969, as in the water's own foam, wind_on_water.md).
##
## The vertices are rest positions on the still water; res://world/effects/wake_foam.gdshader
## lifts them onto the waves with the same wave formulas as the water, so the foam never
## floats above or sinks under a wave. A look only: nothing feeds back into the physics.

## A new point after the tail has moved this far.
const POINT_SPACING_M: float = 0.5
## The foam fades out over this time.
const LIFETIME_S: float = 7.0
## The wake starts this wide (a share of the board's width: the wet part of a planing
## bottom is narrower than the deck) and spreads by SPREAD_MS plus SPREAD_PER_SPEED times the
## board's speed per second (by eye: a slow board's wake hardly widens, a fast one's opens up,
## inside the narrow wave angle of a fast hull, Rabaud and Moisy 2013).
const START_WIDTH_SHARE: float = 0.7
const SPREAD_MS: float = 0.12
const SPREAD_PER_SPEED: float = 0.03
## The wake grows from nothing at WAKE_START_MS to full at WAKE_FULL_MS.
const WAKE_START_MS: float = 0.8
const WAKE_FULL_MS: float = 5.0
const MAX_POINTS: int = 256
## A carve: the board on its inside rail. Full at CARVE_FULL_HEEL_DEG of heel while turning at
## CARVE_FULL_TURN_DPS or more.
const CARVE_FULL_HEEL_DEG: float = 15.0
const CARVE_FULL_TURN_DPS: float = 15.0
## The bow wave's V: Kelvin's half-angle (asin(1/3)), its lines this long from the bow (m), this
## thick (m), living ARM_LIFETIME_S. It is there from BOW_START_MS, strongest about the hull
## speed (BOW_FULL_MS), gone at BOW_GONE_MS and as the board planes.
const ARM_ANGLE_DEG: float = 19.47
const ARM_LENGTH_M: float = 14.0
const ARM_WIDTH_M: float = 0.18
const ARM_LIFETIME_S: float = 5.0
const BOW_START_MS: float = 0.5
const BOW_FULL_MS: float = 2.0
const BOW_GONE_MS: float = 7.0
## Foam patches: at most this many; the whitecap foam's e-folding time on fresh and sea water (s);
## a patch is gone after FOAM_LIVES of it, and spreads by FOAM_SPREAD_MS.
const MAX_PATCHES: int = 8
const FOAM_LIFE_FRESH_S: float = 2.54
const FOAM_LIFE_SEA_S: float = 3.85
const FOAM_LIVES: float = 2.0
const FOAM_SPREAD_MS: float = 0.15
## Each patch is a grid of this many cells a side (so it bends with the waves).
const PATCH_CELLS: int = 4
## What kind of foam a vertex is, for the shader (the vertex colour's blue).
const KIND_TRAIL: float = 0.0
const KIND_ARM: float = 0.5
const KIND_PATCH: float = 1.0

var _sim: WindsurferSim
var _mesh: ImmediateMesh = ImmediateMesh.new()
var _material: ShaderMaterial = ShaderMaterial.new()
var _start_width_m: float = 0.5
var _patch_life_s: float = FOAM_LIFE_SEA_S * FOAM_LIVES
## The trail, oldest first: rest position (x, z), the time it was made, its strength, how fast it
## spreads (m/s), the carve (-1 port rail in, +1 starboard), the bow wave's strength.
var _positions: PackedVector2Array = PackedVector2Array()
var _born_s: PackedFloat64Array = PackedFloat64Array()
var _strengths: PackedFloat64Array = PackedFloat64Array()
var _spreads: PackedFloat64Array = PackedFloat64Array()
var _carves: PackedFloat64Array = PackedFloat64Array()
var _bows: PackedFloat64Array = PackedFloat64Array()
## The tail now (moves with the interpolated board every frame), and its values.
var _tail_xz: Vector2 = Vector2.ZERO
var _forward_xz: Vector2 = Vector2(0.0, -1.0)
var _board_length_m: float = 2.4
var _tail_strength: float = 0.0
var _tail_spread_ms: float = SPREAD_MS
var _tail_carve: float = 0.0
var _tail_bow: float = 0.0
var _has_tail: bool = false
## The foam patches: centre (x, z), when made, diameter (m), strength.
var _patch_xz: PackedVector2Array = PackedVector2Array()
var _patch_born_s: PackedFloat64Array = PackedFloat64Array()
var _patch_size_m: PackedFloat64Array = PackedFloat64Array()
var _patch_strength: PackedFloat64Array = PackedFloat64Array()


## How strong the wake is (0 to 1) at this speed and share of planing: a slow board pushes
## a little wave aside, a planing board leaves a broad trail of white water.
static func wake_strength(speed_ms: float, planing_ratio: float) -> float:
	var speed_share: float = smoothstep(WAKE_START_MS, WAKE_FULL_MS, speed_ms)
	return speed_share * lerpf(0.35, 1.0, clampf(planing_ratio, 0.0, 1.0))


## How strong the bow wave's V is (0 to 1): from BOW_START_MS, full about the hull speed, gone as
## the board planes (planing_ratio) or passes BOW_GONE_MS.
static func bow_wave_strength(speed_ms: float, planing_ratio: float) -> float:
	var rising: float = smoothstep(BOW_START_MS, BOW_FULL_MS, speed_ms)
	var going: float = 1.0 - smoothstep(BOW_FULL_MS + 1.0, BOW_GONE_MS, speed_ms)
	return rising * going * (1.0 - clampf(planing_ratio, 0.0, 1.0))


## The carve (-1 to +1, + the starboard rail in and down): the heel while the board turns, at speed.
static func carve_of(heel_deg: float, yaw_rate_dps: float, speed_ms: float) -> float:
	var turning: float = smoothstep(3.0, CARVE_FULL_TURN_DPS, absf(yaw_rate_dps))
	var moving: float = smoothstep(2.0, 5.0, speed_ms)
	return clampf(heel_deg / CARVE_FULL_HEEL_DEG, -1.0, 1.0) * turning * moving


## How far one arm of the bow wave's V is from the track, at a distance behind the bow (m).
static func arm_offset_m(behind_bow_m: float) -> float:
	return maxf(behind_bow_m, 0.0) * tan(deg_to_rad(ARM_ANGLE_DEG))


func setup(sim: WindsurferSim) -> void:
	_sim = sim
	name = "Wake"
	top_level = true
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The trail can be long: never cull it.
	extra_cull_margin = 16384.0
	_start_width_m = sim.board_config.width_m * START_WIDTH_SHARE
	_board_length_m = sim.board_config.length_m
	_patch_life_s = (FOAM_LIFE_FRESH_S if sim.water is LakeWaveField else FOAM_LIFE_SEA_S) * FOAM_LIVES
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


## Forgets the trail and the foam (after a reset: the board jumps back to the start).
func clear() -> void:
	_positions.clear()
	_born_s.clear()
	_strengths.clear()
	_spreads.clear()
	_carves.clear()
	_bows.clear()
	_patch_xz.clear()
	_patch_born_s.clear()
	_patch_size_m.clear()
	_patch_strength.clear()
	_has_tail = false


## One physics tick: the tail's world position, how strong the wake is now, the carve, the
## board's speed and the bow wave's strength.
func add_tail(tail_world: Vector3, strength: float, carve: float = 0.0, speed_ms: float = 0.0, bow: float = 0.0) -> void:
	var tail: Vector2 = Vector2(tail_world.x, tail_world.z)
	_tail_strength = strength
	_tail_carve = carve
	_tail_spread_ms = SPREAD_MS + SPREAD_PER_SPEED * speed_ms
	_tail_bow = bow
	if _positions.is_empty() or tail.distance_to(_positions[_positions.size() - 1]) >= POINT_SPACING_M:
		_positions.append(tail)
		_born_s.append(_sim.time_s)
		_strengths.append(strength)
		_spreads.append(_tail_spread_ms)
		_carves.append(carve)
		_bows.append(bow)
	while _positions.size() > MAX_POINTS or (not _born_s.is_empty() and _sim.time_s - _born_s[0] > LIFETIME_S):
		_positions.remove_at(0)
		_born_s.remove_at(0)
		_strengths.remove_at(0)
		_spreads.remove_at(0)
		_carves.remove_at(0)
		_bows.remove_at(0)
	while not _patch_born_s.is_empty() and _sim.time_s - _patch_born_s[0] > _patch_life_s:
		_patch_xz.remove_at(0)
		_patch_born_s.remove_at(0)
		_patch_size_m.remove_at(0)
		_patch_strength.remove_at(0)


## A patch of foam on the water where a splash came down: `diameter_m` across, as white as
## `strength` (0 to 1). The oldest goes when there are too many.
func add_foam_patch(at_world: Vector3, diameter_m: float, strength: float) -> void:
	if _sim == null:
		return
	if _patch_xz.size() >= MAX_PATCHES:
		_patch_xz.remove_at(0)
		_patch_born_s.remove_at(0)
		_patch_size_m.remove_at(0)
		_patch_strength.remove_at(0)
	_patch_xz.append(Vector2(at_world.x, at_world.z))
	_patch_born_s.append(_sim.time_s)
	_patch_size_m.append(diameter_m)
	_patch_strength.append(clampf(strength, 0.0, 1.0))


## Every frame: the newest end follows the tail as drawn (the interpolated board), the bow is
## `board_length_m` ahead of it along `forward_xz`, and the water's clock goes on as smoothly as
## the waves.
func follow_tail(tail_world: Vector3, forward_xz: Vector2, board_length_m: float, time_s: float) -> void:
	_tail_xz = Vector2(tail_world.x, tail_world.z)
	if forward_xz.length() > 1e-3:
		_forward_xz = forward_xz.normalized()
	_board_length_m = board_length_m
	_has_tail = true
	_material.set_shader_parameter("water_time_s", time_s)
	_rebuild(time_s)


func point_count() -> int:
	return _positions.size()


func patch_count() -> int:
	return _patch_xz.size()


func _rebuild(time_s: float) -> void:
	_mesh.clear_surfaces()
	var count: int = _positions.size()
	if count > 0 and _has_tail:
		_build_trail(time_s)
		if _bow_wave_shows():
			_build_arms(time_s)
	if not _patch_xz.is_empty():
		_build_patches(time_s)


func _build_trail(time_s: float) -> void:
	var count: int = _positions.size()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var along_m: float = 0.0
	var previous: Vector2 = _positions[0]
	for i: int in count + 1:
		# The points from the oldest to the newest, then the tail itself.
		var newest: bool = i == count
		var at: Vector2 = _tail_xz if newest else _positions[i]
		var age_s: float = 0.0 if newest else time_s - _born_s[i]
		var strength: float = _tail_strength if newest else _strengths[i]
		var spread_ms: float = _tail_spread_ms if newest else _spreads[i]
		var carve: float = _tail_carve if newest else _carves[i]
		along_m += at.distance_to(previous)
		previous = at
		_add_cross_section(at, _direction_at(i, count), age_s, strength, spread_ms, carve, along_m)
	_mesh.surface_end()


## The trail's direction at point i (toward the newer end), for its cross-section.
func _direction_at(i: int, count: int) -> Vector2:
	var before: Vector2 = _positions[maxi(i - 1, 0)]
	var after: Vector2 = _tail_xz if i + 1 >= count else _positions[i + 1]
	var direction: Vector2 = after - before
	return direction.normalized() if direction.length() > 1e-4 else _forward_xz


## Two vertices across the trail at a point, its width grown with age. Colour: red the age as a
## share of the life, green the carve (0.5 none, 1 starboard in, 0 port in), blue the kind, alpha
## the strength. UV.y is 0 on the starboard edge, 1 on the port edge.
func _add_cross_section(at: Vector2, toward: Vector2, age_s: float, strength: float, spread_ms: float, carve: float, along_m: float) -> void:
	var age_share: float = clampf(age_s / LIFETIME_S, 0.0, 1.0)
	var half_width: float = 0.5 * (_start_width_m + spread_ms * age_s)
	var side: Vector2 = Vector2(-toward.y, toward.x) * half_width
	var color: Color = Color(age_share, 0.5 + 0.5 * carve, KIND_TRAIL, strength)
	_mesh.surface_set_color(color)
	_mesh.surface_set_uv(Vector2(along_m, 0.0))
	_mesh.surface_add_vertex(Vector3(at.x + side.x, 0.0, at.y + side.y))
	_mesh.surface_set_color(color)
	_mesh.surface_set_uv(Vector2(along_m, 1.0))
	_mesh.surface_add_vertex(Vector3(at.x - side.x, 0.0, at.y - side.y))


## Whether any part of the last ARM_LENGTH_M of the trail has a bow wave to draw.
func _bow_wave_shows() -> bool:
	if _tail_bow > 0.01:
		return true
	var i: int = _positions.size() - 1
	var walked_m: float = 0.0
	while i >= 0 and walked_m < ARM_LENGTH_M:
		if _bows[i] > 0.01:
			return true
		walked_m += POINT_SPACING_M
		i -= 1
	return false


## The bow wave's V: from the bow (the apex) back past the tail along the trail, each arm
## arm_offset_m() out from the track, one strip a side.
func _build_arms(time_s: float) -> void:
	# The arm's points, from the bow back: (place on the track, direction, distance behind the bow,
	# age, strength).
	var places: PackedVector2Array = PackedVector2Array()
	var directions: PackedVector2Array = PackedVector2Array()
	var behind: PackedFloat64Array = PackedFloat64Array()
	var ages: PackedFloat64Array = PackedFloat64Array()
	var strengths: PackedFloat64Array = PackedFloat64Array()
	places.append(_tail_xz + _forward_xz * _board_length_m)
	directions.append(_forward_xz)
	behind.append(0.0)
	ages.append(0.0)
	strengths.append(_tail_bow)
	places.append(_tail_xz)
	directions.append(_forward_xz)
	behind.append(_board_length_m)
	ages.append(0.0)
	strengths.append(_tail_bow)
	var previous: Vector2 = _tail_xz
	var walked_m: float = _board_length_m
	var i: int = _positions.size() - 1
	while i >= 0 and walked_m < ARM_LENGTH_M:
		walked_m += _positions[i].distance_to(previous)
		previous = _positions[i]
		places.append(_positions[i])
		directions.append(_direction_at(i, _positions.size()))
		behind.append(walked_m)
		ages.append(time_s - _born_s[i])
		strengths.append(_bows[i])
		i -= 1
	for side: float in [1.0, -1.0]:
		_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for k: int in places.size():
			var across: Vector2 = Vector2(-directions[k].y, directions[k].x) * side
			var centre: Vector2 = places[k] + across * arm_offset_m(behind[k])
			var half_width: float = 0.5 * ARM_WIDTH_M + 0.03 * ages[k]
			var age_share: float = clampf(ages[k] / ARM_LIFETIME_S, 0.0, 1.0)
			# Red the age, green how far along the arm (0 at the bow, 1 at its end).
			var color: Color = Color(age_share, behind[k] / ARM_LENGTH_M, KIND_ARM, strengths[k])
			var inner: Vector2 = centre - across * half_width
			var outer: Vector2 = centre + across * half_width
			_mesh.surface_set_color(color)
			_mesh.surface_set_uv(Vector2(behind[k], 0.0))
			_mesh.surface_add_vertex(Vector3(inner.x, 0.0, inner.y))
			_mesh.surface_set_color(color)
			_mesh.surface_set_uv(Vector2(behind[k], 1.0))
			_mesh.surface_add_vertex(Vector3(outer.x, 0.0, outer.y))
		_mesh.surface_end()


## The foam patches: a small grid each (so it bends with the waves), UV from 0 to 1 across it.
func _build_patches(time_s: float) -> void:
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for p: int in _patch_xz.size():
		var age_s: float = time_s - _patch_born_s[p]
		var age_share: float = clampf(age_s / _patch_life_s, 0.0, 1.0)
		var size_m: float = _patch_size_m[p] + FOAM_SPREAD_MS * age_s
		var color: Color = Color(age_share, 0.5, KIND_PATCH, _patch_strength[p])
		var corner: Vector2 = _patch_xz[p] - Vector2(0.5, 0.5) * size_m
		var cell_m: float = size_m / float(PATCH_CELLS)
		for row: int in PATCH_CELLS:
			for column: int in PATCH_CELLS:
				var cells: Array[Vector2i] = [Vector2i(column, row), Vector2i(column + 1, row), Vector2i(column + 1, row + 1),
					Vector2i(column, row), Vector2i(column + 1, row + 1), Vector2i(column, row + 1)]
				for cell: Vector2i in cells:
					var uv: Vector2 = Vector2(cell) / float(PATCH_CELLS)
					_mesh.surface_set_color(color)
					_mesh.surface_set_uv(uv)
					var at: Vector2 = corner + Vector2(cell) * cell_m
					_mesh.surface_add_vertex(Vector3(at.x, 0.0, at.y))
	_mesh.surface_end()


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
