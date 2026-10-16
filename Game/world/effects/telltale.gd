class_name Telltale
extends MeshInstance3D
## A streamer at the masthead: a thin red ribbon that blows downwind of the apparent wind,
## the wind the sailor feels (the true wind plus the wind of the board's own speed). Sailors
## read the apparent wind from it. Posed from the simulation's apparent wind angle and speed,
## not simulated: it droops in a calm, streams out flat in a breeze and flutters faster as
## the wind rises. The node sits at the masthead with the world's axes (set every tick, so
## physics interpolation moves it smoothly); the ribbon is rebuilt every frame.

const LENGTH_M: float = 0.7
const WIDTH_M: float = 0.05
const SEGMENTS: int = 10
## Fully streaming from this apparent wind; below it the ribbon droops.
const STREAMING_KT: float = 8.0
const COLOR: Color = Color(0.9, 0.12, 0.1)

## The apparent wind now (set every tick by effects.gd).
var awa_deg: float = 0.0
var heading_deg: float = 0.0
var aws_kt: float = 0.0

var _mesh: ImmediateMesh = ImmediateMesh.new()
var _time_s: float = 0.0


## The horizontal world direction the streamer blows toward, for an apparent wind angle
## (positive = wind from starboard, CLAUDE.md D4) on a board with this compass heading. The
## wind comes from awa_deg off the bow, so the streamer points the opposite way.
static func direction_for(apparent_angle_deg: float, board_heading_deg: float) -> Vector3:
	var heading: float = deg_to_rad(board_heading_deg)
	var awa: float = deg_to_rad(apparent_angle_deg)
	# The board's forward and starboard directions in the world (North is -Z, East +X).
	var forward: Vector3 = Vector3(sin(heading), 0.0, -cos(heading))
	var starboard: Vector3 = Vector3(cos(heading), 0.0, sin(heading))
	# The wind comes from cos(awa) ahead and sin(awa) to starboard; downwind is minus that.
	return -(forward * cos(awa) + starboard * sin(awa))


## How far the ribbon hangs below the horizontal, radians: almost straight down in a calm,
## nearly flat in a breeze.
static func droop_rad(apparent_speed_kt: float) -> float:
	var streaming: float = clampf(apparent_speed_kt / STREAMING_KT, 0.0, 1.0)
	return lerpf(deg_to_rad(80.0), deg_to_rad(6.0), streaming)


## The points along the ribbon from the masthead, relative to it: out along the wind, hanging
## by the droop, with a wave running down it that grows toward the free end.
static func ribbon_points(direction: Vector3, apparent_speed_kt: float, time_s: float) -> PackedVector3Array:
	var droop: float = droop_rad(apparent_speed_kt)
	var along: Vector3 = (direction * cos(droop) + Vector3.DOWN * sin(droop)).normalized()
	var sideways: Vector3 = direction.cross(Vector3.UP).normalized()
	var flutter_hz: float = 1.5 + 0.12 * apparent_speed_kt
	var points: PackedVector3Array = PackedVector3Array()
	for i: int in SEGMENTS + 1:
		var share: float = float(i) / float(SEGMENTS)
		var wave: float = sin(TAU * (share * 1.3 - flutter_hz * time_s)) * 0.06 * share
		points.append(along * (LENGTH_M * share) + sideways * wave)
	return points


func _ready() -> void:
	name = "Telltale"
	mesh = _mesh
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = COLOR
	material_override = material


## One physics tick: where the masthead is and what the apparent wind does.
func place(masthead_world: Vector3, apparent_angle_deg: float, board_heading_deg: float, apparent_speed_kt: float) -> void:
	global_transform = Transform3D(Basis.IDENTITY, masthead_world)
	awa_deg = apparent_angle_deg
	heading_deg = board_heading_deg
	aws_kt = apparent_speed_kt


func _process(delta: float) -> void:
	if not visible:
		return
	_time_s += delta
	var points: PackedVector3Array = ribbon_points(direction_for(awa_deg, heading_deg), aws_kt, _time_s)
	# The ribbon's flat side stands upright, its width hanging below the line of points.
	var half: Vector3 = Vector3.UP * (0.5 * WIDTH_M)
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for point: Vector3 in points:
		_mesh.surface_add_vertex(point + half)
		_mesh.surface_add_vertex(point - half)
	_mesh.surface_end()
