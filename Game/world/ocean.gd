class_name OceanNode
extends Node3D
## The water you see: a dense mesh that follows the camera, snapped to its own grid so the
## waves do not slide, drawn with res://world/water.gdshader from the same wave set the
## physics floats on (plan decision D5), and a flat far plane out to the horizon under
## the fog. The shader's clock is the simulation's clock (PHYSICS_SPEC.md 9.10), plus the
## fraction of a physics tick the renderer is at, so the water moves as smoothly as the
## interpolated board. Nothing here feeds back into the physics (rule 2).

## The near mesh: this wide, with cells this big. 400 m at 1 m is 160 000 vertices.
@export var near_size_m: float = 400.0
@export var near_cell_m: float = 1.0
## The far plane, flat, this wide; it sits below the deepest trough so it never shows
## through the near mesh.
@export var far_size_m: float = 6000.0
@export var far_cell_m: float = 25.0

var _sim: WindsurferSim
var _camera: Camera3D
var _near: MeshInstance3D
var _far: MeshInstance3D
var _near_material: ShaderMaterial
var _far_material: ShaderMaterial
var _base_height_m: float = 0.0
var _total_amplitude_m: float = 0.0


## Builds the meshes for this simulation's water and this camera.
func setup(sim: WindsurferSim, camera: Camera3D) -> void:
	_sim = sim
	_camera = camera
	_base_height_m = sim.water_config.base_height_m
	var shader: Shader = load("res://world/water.gdshader")
	_near_material = ShaderMaterial.new()
	_near_material.shader = shader
	_far_material = ShaderMaterial.new()
	_far_material.shader = shader
	_far_material.set_shader_parameter("grid_strength", 0.0)

	var field: WaveField = sim.water as WaveField
	if field != null:
		_total_amplitude_m = field.total_amplitude_m()
		var parameters: Dictionary[String, Variant] = field.shader_parameters()
		for key: String in parameters:
			if key != "base_height_m":
				_near_material.set_shader_parameter(key, parameters[key])
	_far_material.set_shader_parameter("wave_amplitudes", Vector4.ZERO)

	_near = _make_plane("NearWater", near_size_m, near_cell_m, _near_material)
	_far = _make_plane("FarWater", far_size_m, far_cell_m, _far_material)
	_follow_camera()


func _make_plane(node_name: String, size_m: float, cell_m: float, material: ShaderMaterial) -> MeshInstance3D:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(size_m, size_m)
	var subdivisions: int = maxi(int(round(size_m / cell_m)) - 1, 0)
	plane.subdivide_width = subdivisions
	plane.subdivide_depth = subdivisions
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = plane
	instance.material_override = material
	# The waves move the vertices up to the total amplitude: tell the culling.
	instance.extra_cull_margin = 2.0 + _total_amplitude_m
	add_child(instance)
	return instance


func _process(_delta: float) -> void:
	if _sim == null or _camera == null:
		return
	_follow_camera()
	var tick_s: float = 1.0 / float(Engine.physics_ticks_per_second)
	var time_s: float = _sim.time_s + Engine.get_physics_interpolation_fraction() * tick_s
	_near_material.set_shader_parameter("water_time_s", time_s)


## The near mesh is centred on the camera, snapped to its cell size (and the far plane to
## its own), so a vertex is always at the same world (x, z) and the waves do not swim.
func _follow_camera() -> void:
	var at: Vector3 = _camera.global_position
	_near.global_position = Vector3(snappedf(at.x, near_cell_m), _base_height_m, snappedf(at.z, near_cell_m))
	_far.global_position = Vector3(snappedf(at.x, far_cell_m), _base_height_m - _total_amplitude_m - 0.02, snappedf(at.z, far_cell_m))
