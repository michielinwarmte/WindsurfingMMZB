class_name OceanNode
extends Node3D
## The water you see: a dense mesh that follows the camera, snapped to its own grid so the
## waves do not slide, drawn with res://world/water.gdshader from the same wave set the
## physics floats on (plan decision D5), and a flat far plane out to the horizon under
## the fog. The shader's clock is the simulation's clock (PHYSICS_SPEC.md 9.10), plus the
## fraction of a physics tick the renderer is at, so the water moves as smoothly as the
## interpolated board. Nothing here feeds back into the physics (rule 2).
##
## The water's look (colours, how see-through it is, the ripples) is a material on the same
## shader that holds only those parameters: the open sea's by default, a map's own
## (res://maps/silvaplana/lake_water.tres) on a lake. Set `look` and `render_layers` before
## setup(), or call set_look() afterwards.

## The open sea's look.
const SEA_LOOK_PATH: String = "res://world/sea_water.tres"
## The ripples grow with the wind up to this many times the look's own strength, which is
## the strength at this wind speed (knots, 10 m up).
const RIPPLE_REFERENCE_WIND_KT: float = 15.0
## (Up to 30 kt: before 6 November 2026 they stopped growing at 21 kt, so 24 and 30 looked the same.)
const RIPPLE_MAX_FACTOR: float = 2.0
## Below about 2 knots the water is almost glassy.
const RIPPLE_MIN_FACTOR: float = 0.1

## The near mesh: this wide, with cells this big. 400 m at 1 m is 160 000 vertices.
@export var near_size_m: float = 400.0
@export var near_cell_m: float = 1.0
## A lake's waves (LakeWaveField, PHYSICS_SPEC.md 9.17) are shorter than the open sea's (1 to 8 m),
## too short for 1 m cells, so a lake's near mesh has cells that grow with the distance from its
## middle: LAKE_RINGS gives each ring's cell size and how far out it reaches (m). 0.25 m cells to
## 20 m out give the 1 m train four vertices a wave; each ring doubles both. The water shader shows a
## train as shape only where the cells are small enough for it (LAKE_LOD_REACH x its wavelength: the
## first ring's 20 m per metre of wavelength) and as shading everywhere. 439 x 439 vertices.
const LAKE_RINGS: Array[Vector2] = [Vector2(0.25, 20.0), Vector2(0.5, 40.0), Vector2(1.0, 80.0), Vector2(2.0, 160.0), Vector2(4.0, 240.0)]
const LAKE_LOD_REACH: float = 20.0
## The lake mesh, made once (its vertices never change).
static var _lake_mesh: ArrayMesh = null
## The far plane, flat, this wide; it sits below the deepest trough so it never shows
## through the near mesh. 20 km reaches past the horizon (5 km away for an eye 2 m up), so
## no sky shows between the water's edge and the horizon.
@export var far_size_m: float = 20000.0
@export var far_cell_m: float = 100.0
## On a map: the area the far water covers, fixed in the world (x and z of a corner, then
## the width and depth, m), instead of a plane around the camera. A lake needs this: its
## water must stay within its shore band (for Silvaplana the TerrainGrid's area, as in
## terrain_view.gd), or it would flood the valley below the lake's level. Empty = the open
## sea's plane around the camera.
@export var far_area_xz: Rect2 = Rect2()
## The water's look: a ShaderMaterial on res://world/water.gdshader (null = the open sea's).
@export var look: ShaderMaterial = null
## The render layers the water is drawn on. A map whose water mirrors the valley with a
## reflection probe (Silvaplana's LakeReflections: layer 2) puts the water on that layer.
@export_flags_3d_render var render_layers: int = 1
## The ripples drift downwind and grow with the simulation's wind. Off: the look's own
## direction and strength.
@export var ripples_follow_wind: bool = true

var _sim: WindsurferSim
var _camera: Camera3D
var _near: MeshInstance3D
var _far: MeshInstance3D
var _near_material: ShaderMaterial
var _far_material: ShaderMaterial
var _base_height_m: float = 0.0
var _total_amplitude_m: float = 0.0
var _look_ripple_strength: float = 0.7
## The look's grid, and whether it is hidden (set_grid_hidden()).
var _look_grid_strength: float = 0.12
var grid_hidden: bool = false
## Whether the water is a lake's own waves (LakeWaveField): the graded mesh and the lake's shader path.
var _lake: bool = false
## The water's foam and wind rows drift downwind with the surface (lake_look.gdshaderinc, 6. and 7.):
## at this share of the wind at 10 m (the wind-driven surface drift is a few % of the wind, the usual
## 3 % of oil-spill drift; an estimate for the foam), along the mean wind's direction of the run, fixed.
const FOAM_DRIFT_SHARE: float = 0.03
var _rows_along: Vector2 = Vector2(1.0, 0.0)
## How far the foam has drifted since the water was built (m), and the water's clock then.
var _foam_offset_m: Vector2 = Vector2.ZERO
var _foam_time_s: float = -1.0


## Builds the meshes for this simulation's water and this camera.
func setup(sim: WindsurferSim, camera: Camera3D) -> void:
	_sim = sim
	_camera = camera
	_base_height_m = sim.water_config.base_height_m
	var field: WaveField = sim.water as WaveField
	_total_amplitude_m = field.total_amplitude_m() if field != null else 0.0
	_lake = sim.water is LakeWaveField
	if _lake:
		_near = _make_instance("NearWater", lake_mesh())
	else:
		_near = _make_plane("NearWater", Vector2(near_size_m, near_size_m), near_cell_m)
	_far = _make_plane("FarWater", _far_size(), far_cell_m)
	_apply_look()
	_follow_camera()


## Changes the water's look (null = the open sea's) and draws it at once.
func set_look(new_look: ShaderMaterial) -> void:
	look = new_look
	if _near != null:
		_apply_look()


## The material of the near water (for tests).
func near_material() -> ShaderMaterial:
	return _near_material


## Sets a look parameter on all the water, near and far: for a scene that drives one, such
## as a map's gust picture (wind_ripple_map and wind_ripple_map_area in water.gdshader).
func set_water_parameter(parameter: String, value: Variant) -> void:
	_near_material.set_shader_parameter(parameter, value)
	_far_material.set_shader_parameter(parameter, value)


## The open sea's look, loaded when no other is given.
static func sea_look() -> ShaderMaterial:
	return load(SEA_LOOK_PATH) as ShaderMaterial


## How strong the ripples are in this wind, as a factor on the look's own strength: they
## grow with the wind and fade to almost nothing in a calm.
static func ripple_factor_for_wind(tws_kt: float) -> float:
	return clampf(tws_kt / RIPPLE_REFERENCE_WIND_KT, RIPPLE_MIN_FACTOR, RIPPLE_MAX_FACTOR)


## Gives both planes their own copy of the look, with the waves on the near one only. The
## far plane is drawn first and the near mesh over it (render_priority), both before the
## see-through sail.
func _apply_look() -> void:
	var chosen: ShaderMaterial = look if look != null else sea_look()
	_look_ripple_strength = float(chosen.get_shader_parameter("ripple_strength"))
	var grid: Variant = chosen.get_shader_parameter("grid_strength")
	_look_grid_strength = float(grid) if grid != null else 0.12
	_near_material = chosen.duplicate() as ShaderMaterial
	_near_material.render_priority = -1
	_far_material = chosen.duplicate() as ShaderMaterial
	_far_material.render_priority = -2
	_far_material.set_shader_parameter("grid_strength", 0.0)
	var field: WaveField = _sim.water as WaveField
	if field != null:
		var parameters: Dictionary[String, Variant] = field.shader_parameters()
		for key: String in parameters:
			if key != "base_height_m":
				# The far plane draws the waves as shading only (lake_displace and sea_displace off).
				_near_material.set_shader_parameter(key, parameters[key])
				_far_material.set_shader_parameter(key, parameters[key])
	# The far plane is flat. On the open sea it draws the waves as shading and keeps their whitecaps, and
	# the near mesh's outer part turns to the same shading (water.gdshader, sea_displace), so the near
	# mesh's edge does not show as a square from high up (Max, 12 November 2026, the TV camera).
	_far_material.set_shader_parameter("sea_displace", false)
	_near_material.set_shader_parameter("sea_near_half_m", near_size_m * 0.5)
	if _lake:
		_far_material.set_shader_parameter("wave_amplitudes", Vector4.ZERO)
		_near_material.set_shader_parameter("lake_lod_reach", LAKE_LOD_REACH)
		_far_material.set_shader_parameter("lake_displace", false)
		# The lake's look in the wind (res://world/lake_look.gdshaderinc): its short waves' directions and
		# a first wind (the lake scene sets the wind of every moment, set_water_parameter()).
		var look_parameters: Dictionary[String, Variant] = LakeLook.shader_parameters((_sim.water as LakeWaveField).lake)
		for key: String in look_parameters:
			set_water_parameter(key, look_parameters[key])
	# The direction the wind rows lie along and the foam drifts: the mean wind's, fixed while this water
	# lasts (a pattern turned with every shift would swing across the whole lake).
	var from_deg: float = _sim.wind_config.from_bearing_deg if _sim.wind_config != null else 270.0
	if _lake:
		from_deg = (_sim.water as LakeWaveField).lake.from_deg
	_rows_along = WaveField.direction_for_bearing(from_deg + 180.0)
	set_water_parameter("wind_rows_along", _rows_along)
	_near.material_override = _near_material
	_far.material_override = _far_material
	set_grid_hidden(grid_hidden)


## The faint grid on the water (a sailing aid: speed and heading on flat water) off or on again; the TV
## camera of a watched race hides it (TvCamera). It stays as set when the water is built again.
func set_grid_hidden(hidden: bool) -> void:
	grid_hidden = hidden
	if _near_material != null:
		_near_material.set_shader_parameter("grid_strength", 0.0 if hidden else _look_grid_strength)


func _far_size() -> Vector2:
	return far_area_xz.size if far_area_xz.has_area() else Vector2(far_size_m, far_size_m)


func _make_plane(node_name: String, size_m: Vector2, cell_m: float) -> MeshInstance3D:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = size_m
	plane.subdivide_width = maxi(int(round(size_m.x / cell_m)) - 1, 0)
	plane.subdivide_depth = maxi(int(round(size_m.y / cell_m)) - 1, 0)
	return _make_instance(node_name, plane)


## The lake's near mesh (see LAKE_RINGS): flat, centred on its origin, made once.
static func lake_mesh() -> ArrayMesh:
	if _lake_mesh != null:
		return _lake_mesh
	var lines: PackedFloat32Array = lake_mesh_lines()
	var count: int = lines.size()
	var vertices: PackedVector3Array = PackedVector3Array()
	vertices.resize(count * count)
	var normals: PackedVector3Array = PackedVector3Array()
	normals.resize(count * count)
	normals.fill(Vector3.UP)
	for row: int in count:
		for column: int in count:
			vertices[row * count + column] = Vector3(lines[column], 0.0, lines[row])
	var indices: PackedInt32Array = PackedInt32Array()
	indices.resize((count - 1) * (count - 1) * 6)
	var at: int = 0
	for row: int in count - 1:
		for column: int in count - 1:
			var corner: int = row * count + column
			# Two triangles a cell, wound so that they face up (Godot: clockwise from above is front).
			indices[at] = corner
			indices[at + 1] = corner + 1
			indices[at + 2] = corner + count
			indices[at + 3] = corner + 1
			indices[at + 4] = corner + count + 1
			indices[at + 5] = corner + count
			at += 6
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_lake_mesh = mesh
	return mesh


## Where the lake mesh's lines lie across one axis, from the outermost on one side to the other (m).
static func lake_mesh_lines() -> PackedFloat32Array:
	var outward: PackedFloat32Array = PackedFloat32Array()
	var at_m: float = 0.0
	for ring: Vector2 in LAKE_RINGS:
		while at_m + ring.x <= ring.y + 0.001:
			at_m += ring.x
			outward.append(at_m)
	var lines: PackedFloat32Array = PackedFloat32Array()
	for i: int in range(outward.size() - 1, -1, -1):
		lines.append(-outward[i])
	lines.append(0.0)
	lines.append_array(outward)
	return lines


func _make_instance(node_name: String, mesh: Mesh) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.layers = render_layers
	# The water takes the board's shadow but casts none (it would darken a lakebed).
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The waves move the vertices up to the total amplitude: tell the culling.
	instance.extra_cull_margin = 2.0 + _total_amplitude_m
	add_child(instance)
	return instance


func _process(_delta: float) -> void:
	if _sim == null or _camera == null:
		return
	_follow_camera()
	# A tick's length in the simulation's time: time_scale / ticks (1 / 60 s also when a watched race runs
	# slower or faster, WatchMode, or a LAN guest keeps the host's pace: both change the two together).
	var tick_s: float = Engine.time_scale / float(Engine.physics_ticks_per_second)
	var time_s: float = _sim.time_s + Engine.get_physics_interpolation_fraction() * tick_s
	_near_material.set_shader_parameter("water_time_s", time_s)
	# The far plane's shading moves with the waves too.
	_far_material.set_shader_parameter("water_time_s", time_s)
	if _lake:
		# The near mesh's shape follows the camera.
		var eye: Vector3 = _camera.global_position
		_near_material.set_shader_parameter("lake_lod_centre", Vector2(eye.x, eye.z))
		_near_material.set_shader_parameter("lake_lod_height_m", maxf(eye.y - _base_height_m, 0.0))
	_drift_the_foam(time_s)
	if ripples_follow_wind:
		_follow_wind()


## The foam and the wind rows drift downwind with the surface: the drift of this frame added to the
## offset (so a change of the wind never jumps them), on the water's own clock. On the open water the
## shader also gets the mean wind of the moment (the lake scene sets the lake's, sail_silvaplana.gd).
func _drift_the_foam(time_s: float) -> void:
	var wind_10m_ms: float = _sim.wind.speed_at_height(10.0)
	var drift_ms: Vector2 = _rows_along * wind_10m_ms * FOAM_DRIFT_SHARE
	if _foam_time_s >= 0.0:
		_foam_offset_m += drift_ms * clampf(time_s - _foam_time_s, 0.0, 0.5)
	_foam_time_s = time_s
	set_water_parameter("foam_drift_ms", drift_ms)
	set_water_parameter("foam_offset_m", _foam_offset_m)
	if not _lake:
		set_water_parameter("lake_wind_ms", Vector2(wind_10m_ms, _sim.wind.speed_at_height(LakeLook.COX_MUNK_HEIGHT_M)))


## The ripples drift downwind and grow with the true wind at the board.
func _follow_wind() -> void:
	var telemetry: Telemetry = _sim.telemetry
	var downwind: Vector2 = WaveField.direction_for_bearing(telemetry.wind_from_bearing_deg + 180.0)
	var strength: float = _look_ripple_strength * ripple_factor_for_wind(telemetry.tws_10m_kt)
	for material: ShaderMaterial in [_near_material, _far_material]:
		material.set_shader_parameter("ripple_drift_direction", downwind)
		material.set_shader_parameter("ripple_strength", strength)


## The near mesh is centred on the camera, snapped to its cell size (and the far plane to
## its own), so a vertex is always at the same world (x, z) and the waves do not swim.
func _follow_camera() -> void:
	var at: Vector3 = _camera.global_position
	# Snapped to its biggest cells, so every vertex stays on its own ring's grid and the waves do not
	# swim (the lake's mesh: 4 m; its finer rings' cells divide 4 m).
	var snap_m: float = LAKE_RINGS[LAKE_RINGS.size() - 1].x if _lake else near_cell_m
	_near.global_position = Vector3(snappedf(at.x, snap_m), _base_height_m, snappedf(at.z, snap_m))
	var far_height_m: float = _base_height_m - _total_amplitude_m - 0.02
	if far_area_xz.has_area():
		var centre: Vector2 = far_area_xz.get_center()
		_far.global_position = Vector3(centre.x, far_height_m, centre.y)
	else:
		_far.global_position = Vector3(snappedf(at.x, far_cell_m), far_height_m, snappedf(at.z, far_cell_m))
