class_name WindFlag
extends Node3D
## A wind flag on a small buoy at the start, so you see where the true wind blows: the
## orange cloth streams downwind and waves faster in more wind (flag_cloth.gdshader, no cloth
## physics). The buoy rides up and down on the waves. It shows the wind of the simulation
## at the board (one wind for the whole sea); a map's wind that varies from place to place
## would ask its own wind field here instead. A look only.

const POLE_HEIGHT_M: float = 2.6
const FLAG_SIZE_M: Vector2 = Vector2(0.9, 0.6)
const BUOY_RADIUS_M: float = 0.35

var _cloth_material: ShaderMaterial = ShaderMaterial.new()
var _cloth: MeshInstance3D


## The rotation about the vertical that turns the flag's +X (from the pole to the free end)
## toward the direction the wind blows to (a horizontal world direction).
static func yaw_toward(downwind: Vector3) -> float:
	return atan2(-downwind.z, downwind.x)


func _ready() -> void:
	name = "WindFlag"
	top_level = true
	_add_part("Buoy", _sphere(BUOY_RADIUS_M), Vector3(0.0, 0.05, 0.0), Color(0.95, 0.4, 0.05))
	_add_part("Pole", _cylinder(0.025, POLE_HEIGHT_M), Vector3(0.0, POLE_HEIGHT_M * 0.5, 0.0), Color(0.85, 0.85, 0.82))
	var quad: QuadMesh = QuadMesh.new()
	quad.size = FLAG_SIZE_M
	quad.subdivide_width = 14
	quad.subdivide_depth = 6
	# The pole edge at x = 0, the top edge at y = 0.
	quad.center_offset = Vector3(FLAG_SIZE_M.x * 0.5, -FLAG_SIZE_M.y * 0.5, 0.0)
	_cloth_material.shader = load("res://world/effects/flag_cloth.gdshader") as Shader
	_cloth_material.set_shader_parameter("flag_width_m", FLAG_SIZE_M.x)
	_cloth = MeshInstance3D.new()
	_cloth.name = "Cloth"
	_cloth.mesh = quad
	_cloth.material_override = _cloth_material
	_cloth.position = Vector3(0.0, POLE_HEIGHT_M - 0.02, 0.0)
	# The cloth bends a little out of its plane: keep it from being culled at the edge.
	_cloth.extra_cull_margin = 0.5
	add_child(_cloth)


## One physics tick: the buoy's spot on the water (with the wave height) and the true wind
## (the direction it blows toward and its speed).
func place(on_water: Vector3, downwind: Vector3, wind_speed_ms: float) -> void:
	global_transform = Transform3D(Basis(Vector3.UP, yaw_toward(downwind)), on_water)
	_cloth_material.set_shader_parameter("wind_speed_ms", wind_speed_ms)


## The direction the cloth points from the pole, in the world (for tests).
func cloth_direction() -> Vector3:
	return global_transform.basis.x


func _add_part(part_name: String, part_mesh: Mesh, at: Vector3, color: Color) -> void:
	var part: MeshInstance3D = MeshInstance3D.new()
	part.name = part_name
	part.mesh = part_mesh
	part.position = at
	part.material_override = VisualMath.plain_material(color)
	add_child(part)


static func _sphere(radius: float) -> SphereMesh:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	return sphere


static func _cylinder(radius: float, height: float) -> CylinderMesh:
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 8
	return cylinder
