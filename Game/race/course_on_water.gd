class_name CourseOnWater
extends Node3D
## A race course on the water (RACING_PLAN.md, 9A), for the eye only (CLAUDE.md rule 2: nothing
## here feeds back into the physics):
## - an orange inflatable buoy for every rounding mark, yellow for the two marks of a gate, with a
##   small white flag carrying the mark's name;
## - the committee boat at the start line's boat end and the finish boat at the finish line's:
##   simple white hulls with a short mast and the wind flag of Phase 7 (wind_flag.gd) streaming in
##   the true wind, orange on the committee boat and blue on the finish boat, as the course maker
##   draws them (Sailing Instructions 18.2 and 20); a small buoy at each pin end, with a flag in
##   its line's colour;
## - a faint line on the water between the two ends of the start line and of the finish line, off
##   by default (set_lines_visible; the mini-map always shows the lines).
## Everything floats: every physics tick it is put at the water's height at its spot and tilted
## with the water's slope under it. The boats lie head to wind, as boats at anchor do, and a buoy
## turns with the wind too, so its flag streams downwind.
##
## Cheap: every kind of part shares one mesh and one material between all the marks; no particles,
## no physics bodies, a few water heights per thing per tick.
##
## This node stays at the world origin (the lines are drawn in world coordinates). The scene adds
## it, then builds it (main.gd, --course=<name>):
##   var on_water: CourseOnWater = CourseOnWater.new()
##   add_child(on_water)
##   on_water.build(course, height_at, clock, wind_at)

enum Kind { BUOY, PIN, BOAT }

## A rounding mark: an inflatable cylinder about 1.5 m tall on a float ring, metres.
const BUOY_HEIGHT_M: float = 1.5
const BUOY_RADIUS_M: float = 0.55
## How deep it floats: the part under the water, metres.
const BUOY_DRAFT_M: float = 0.2
## A pin end: a smaller buoy.
const PIN_HEIGHT_M: float = 0.8
const PIN_RADIUS_M: float = 0.3
const PIN_DRAFT_M: float = 0.15
## The flag on a buoy: on a pole this tall above the buoy's top, this big (along the wind, high).
const FLAG_POLE_M: float = 0.9
const FLAG_SIZE_M: Vector2 = Vector2(0.6, 0.4)
## The boats: about 6 m long, with a cabin; the wind flag's pole (WindFlag.POLE_HEIGHT_M) is the
## short mast, standing on the cabin roof. In the boat's frame: +X starboard, -Z the bow, the
## origin on the waterline.
const BOAT_LENGTH_M: float = 6.0
const CABIN_SIZE_M: Vector3 = Vector3(1.6, 0.9, 2.0)
const CABIN_AT: Vector3 = Vector3(0.0, 1.05, 0.6)
const MAST_FOOT: Vector3 = Vector3(0.0, 1.5, 0.6)
## How far from its middle the water is read for a floating thing's tilt: across and along it, m.
const BUOY_FOOTPRINT_M: Vector2 = Vector2(0.6, 0.6)
const BOAT_FOOTPRINT_M: Vector2 = Vector2(1.1, 2.8)
## The lines on the water: a strip this wide, made of pieces this long, metres.
const LINE_WIDTH_M: float = 0.25
const LINE_STEP_M: float = 1.0
## Below this wind (m/s) the boats keep the way they lie.
const CALM_MS: float = 0.2

const MARK_COLOR: Color = Color(1.0, 0.42, 0.05)
const GATE_COLOR: Color = Color(1.0, 0.82, 0.1)
const FLOAT_COLOR: Color = Color(0.16, 0.16, 0.18)
const FLAG_COLOR: Color = Color(0.97, 0.97, 0.95)
const HULL_COLOR: Color = Color(0.95, 0.95, 0.93)
const CABIN_COLOR: Color = Color(0.72, 0.75, 0.78)


## One thing floating on the course: a buoy, a pin or a boat.
class Floater:
	var kind: Kind
	var mark_id: String
	var node: Node3D
	## Where it is: game X, Z.
	var at: Vector2
	## How far from its middle the water is read for its tilt (across, along), metres.
	var footprint_m: Vector2
	## The wind flag on a boat's mast (null on a buoy).
	var flag: WindFlag = null


var course: Course
var lines_visible: bool = false

## height_at(x, z, time_s) -> float: the height of the water you see, metres (the simulation's
## water, which the water's shader draws).
var _height_at: Callable
## clock() -> float: the simulation's time, seconds: the water's clock.
var _clock: Callable
## wind_at(point: Vector3) -> Vector3: the true wind at a point, the way it blows, m/s. Empty: the
## boats lie head to the course's axis and the flags hang in a calm.
var _wind_at: Callable
var _floaters: Array[Floater] = []
var _lines: Array[MeshInstance3D] = []
## The way into the wind (horizontal, one metre long), kept through a calm.
var _into_wind: Vector3 = Vector3.FORWARD

# The parts every mark shares.
var _buoy_mesh: CylinderMesh
var _pin_mesh: CylinderMesh
var _float_mesh: TorusMesh
var _pole_mesh: CylinderMesh
var _flag_mesh: QuadMesh
var _hull_mesh: ArrayMesh
var _cabin_mesh: BoxMesh
var _mark_material: StandardMaterial3D
var _gate_material: StandardMaterial3D
var _float_material: StandardMaterial3D
var _pole_material: StandardMaterial3D
var _flag_material: StandardMaterial3D
var _start_flag_material: StandardMaterial3D
var _finish_flag_material: StandardMaterial3D
var _hull_material: StandardMaterial3D
var _cabin_material: StandardMaterial3D
var _line_material: ShaderMaterial


## Builds the course's buoys, boats and lines and puts them on the water. Call it after the node is
## in the scene (the wind flags build their parts when they enter it). height_at, clock and wind_at
## are described with their variables above.
func build(race_course: Course, height_at: Callable, clock: Callable, wind_at: Callable = Callable()) -> void:
	course = race_course
	_height_at = height_at
	_clock = clock
	_wind_at = wind_at
	var axis: Vector2 = Course.direction_of(course.axis_deg)
	_into_wind = Vector3(axis.x, 0.0, axis.y)
	# Like the windsurfer: it stops while the game is paused. And it runs after the windsurfer
	# (priority 0) has stepped the simulation, so the water's clock is this tick's.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = 1
	_make_shared_parts()
	for mark: CourseMark in course.marks:
		if mark.is_boat():
			_add_boat(mark)
		elif mark.is_line_end():
			_add_pin(mark)
		else:
			_add_buoy(mark)
	_add_line(CourseMark.START_BOAT, CourseMark.START_PIN)
	_add_line(CourseMark.FINISH_BOAT, CourseMark.FINISH_PIN)
	set_lines_visible(lines_visible)
	update_now()
	# They were just put in place: no sliding in from the origin.
	reset_physics_interpolation()


## Shows or hides the lines on the water.
func set_lines_visible(shown: bool) -> void:
	lines_visible = shown
	for line: MeshInstance3D in _lines:
		line.visible = shown


## The waves the lines ride on: WaveField.shader_parameters() of the simulation's water (empty for
## flat water), and the still water's height. Again whenever the scene builds new water.
func set_wave_parameters(parameters: Dictionary[String, Variant], base_height_m: float) -> void:
	_line_material.set_shader_parameter("wave_amplitudes", Vector4.ZERO)
	for key: String in parameters:
		if key != "base_height_m":
			_line_material.set_shader_parameter(key, parameters[key])
	_line_material.set_shader_parameter("base_height_m", base_height_m)


## Puts everything on the water as it is now: every physics tick, and once when built.
func update_now() -> void:
	var time_s: float = _clock.call()
	for floater: Floater in _floaters:
		_float(floater, time_s)


## The floating parts of one kind, in the course's order of marks (for tests and the scene).
func parts_of_kind(kind: Kind) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for floater: Floater in _floaters:
		if floater.kind == kind:
			result.append(floater.node)
	return result


## The floating part at a mark (null if none).
func part_at(mark_id: String) -> Node3D:
	for floater: Floater in _floaters:
		if floater.mark_id == mark_id:
			return floater.node
	return null


## The wind flag on the boat at a line's end (null if none).
func flag_at(mark_id: String) -> WindFlag:
	for floater: Floater in _floaters:
		if floater.mark_id == mark_id:
			return floater.flag
	return null


func line_count() -> int:
	return _lines.size()


func _physics_process(_delta: float) -> void:
	if course != null:
		update_now()


## The lines ride on the water you see, so they take its clock as the water does (ocean.gd): the
## simulation's time plus the part of a tick the picture is at.
func _process(_delta: float) -> void:
	if not lines_visible or _clock.is_null():
		return
	var tick_s: float = 1.0 / float(Engine.physics_ticks_per_second)
	var time_s: float = _clock.call() + Engine.get_physics_interpolation_fraction() * tick_s
	_line_material.set_shader_parameter("water_time_s", time_s)


# ---------------------------------------------------------------- floating

## One floating thing on the water now: at the water's height at its spot, turned to the wind and
## tilted with the water's slope; a boat's flag on its mast.
func _float(floater: Floater, time_s: float) -> void:
	var height: float = _height_at.call(floater.at.x, floater.at.y, time_s)
	var on_water: Vector3 = Vector3(floater.at.x, height, floater.at.y)
	var wind_ms: Vector3 = _wind_at.call(on_water) if _wind_at.is_valid() else Vector3.ZERO
	var into_wind: Vector3 = Vector3(-wind_ms.x, 0.0, -wind_ms.z)
	if into_wind.length() > CALM_MS:
		_into_wind = into_wind.normalized()
	var turned: Basis = Basis.looking_at(_into_wind, Vector3.UP)
	var tilt: Quaternion = Quaternion(Vector3.UP, _water_up(floater, turned, time_s))
	floater.node.global_transform = Transform3D(Basis(tilt) * turned, on_water)
	if floater.flag != null:
		var mast_foot: Vector3 = floater.node.global_transform * MAST_FOOT
		var flag_wind_ms: Vector3 = Vector3.ZERO
		if _wind_at.is_valid():
			flag_wind_ms = _wind_at.call(mast_foot + Vector3.UP * WindFlag.POLE_HEIGHT_M)
		floater.flag.place(mast_foot, -_into_wind, flag_wind_ms.length())


## The way a floating thing's top leans: the water's normal, from the water's rise across it (its
## X) and along it (its Z), read at the ends of its footprint.
func _water_up(floater: Floater, turned: Basis, time_s: float) -> Vector3:
	var middle: Vector3 = Vector3(floater.at.x, 0.0, floater.at.y)
	var across: Vector3 = turned.x * floater.footprint_m.x
	var along: Vector3 = turned.z * floater.footprint_m.y
	var rise_across: float = (_height_at_point(middle + across, time_s) - _height_at_point(middle - across, time_s)) / (2.0 * floater.footprint_m.x)
	var rise_along: float = (_height_at_point(middle + along, time_s) - _height_at_point(middle - along, time_s)) / (2.0 * floater.footprint_m.y)
	# A surface that rises by r per metre along a direction leans its normal back against it.
	return (Vector3.UP - turned.x * rise_across - turned.z * rise_along).normalized()


func _height_at_point(point: Vector3, time_s: float) -> float:
	return _height_at.call(point.x, point.z, time_s)


# ---------------------------------------------------------------- the parts

func _add_buoy(mark: CourseMark) -> void:
	var node: Node3D = _add_floater(Kind.BUOY, mark, "Mark " + mark.id, BUOY_FOOTPRINT_M).node
	_add_part(node, "Body", _buoy_mesh, _gate_material if mark.is_gate_mark() else _mark_material,
		Vector3(0.0, BUOY_HEIGHT_M * 0.5 - BUOY_DRAFT_M, 0.0))
	_add_part(node, "Float", _float_mesh, _float_material, Vector3(0.0, 0.02, 0.0))
	var top_m: float = BUOY_HEIGHT_M - BUOY_DRAFT_M
	_add_flag(node, top_m, _flag_material)
	# The name on both sides of the flag, each a little in front of its side.
	var flag_middle: Vector3 = Vector3(0.0, top_m + FLAG_POLE_M - FLAG_SIZE_M.y * 0.5, FLAG_SIZE_M.x * 0.5)
	for side: float in [-1.0, 1.0]:
		var label: Label3D = Label3D.new()
		label.name = "Name left" if side < 0.0 else "Name right"
		label.text = mark.id
		label.font_size = 72
		label.pixel_size = 0.004
		label.outline_size = 0
		label.modulate = Color(0.05, 0.05, 0.05)
		label.double_sided = false
		label.position = flag_middle + Vector3(side * 0.02, 0.0, 0.0)
		# A label faces +Z; turned a quarter round it faces the side it sits on.
		label.rotation = Vector3(0.0, side * PI * 0.5, 0.0)
		node.add_child(label)


func _add_pin(mark: CourseMark) -> void:
	var node: Node3D = _add_floater(Kind.PIN, mark, "Pin " + mark.id, BUOY_FOOTPRINT_M).node
	_add_part(node, "Body", _pin_mesh, _mark_material, Vector3(0.0, PIN_HEIGHT_M * 0.5 - PIN_DRAFT_M, 0.0))
	var finish: bool = mark.id == CourseMark.FINISH_PIN
	_add_flag(node, PIN_HEIGHT_M - PIN_DRAFT_M, _finish_flag_material if finish else _start_flag_material)


func _add_boat(mark: CourseMark) -> void:
	var finish: bool = mark.id == CourseMark.FINISH_BOAT
	var boat: Floater = _add_floater(Kind.BOAT, mark, "Finish boat" if finish else "Committee boat", BOAT_FOOTPRINT_M)
	var node: Node3D = boat.node
	_add_part(node, "Hull", _hull_mesh, _hull_material, Vector3.ZERO)
	_add_part(node, "Cabin", _cabin_mesh, _cabin_material, CABIN_AT)
	# The wind flag of Phase 7 is the boat's mast and flag. It stands on its own buoy on the open
	# water; on the boat the cabin roof carries it, so its buoy is hidden.
	var flag: WindFlag = WindFlag.new()
	node.add_child(flag)
	var flag_buoy: Node3D = flag.get_node_or_null("Buoy")
	if flag_buoy != null:
		flag_buoy.visible = false
	var cloth: MeshInstance3D = flag.get_node_or_null("Cloth")
	if cloth != null:
		var color: Color = CourseOverlay.FINISH_FLAG if finish else CourseOverlay.START_FLAG
		(cloth.material_override as ShaderMaterial).set_shader_parameter("cloth_color", color)
	boat.flag = flag


func _add_floater(kind: Kind, mark: CourseMark, node_name: String, footprint_m: Vector2) -> Floater:
	var floater: Floater = Floater.new()
	floater.kind = kind
	floater.mark_id = mark.id
	floater.at = mark.position
	floater.footprint_m = footprint_m
	floater.node = Node3D.new()
	floater.node.name = node_name
	add_child(floater.node)
	_floaters.append(floater)
	return floater


## A small flag on a pole on top of a buoy (at top_m above the water), streaming downwind: the
## buoy's +Z, since the buoy is turned with its -Z into the wind.
func _add_flag(node: Node3D, top_m: float, material: StandardMaterial3D) -> void:
	_add_part(node, "Pole", _pole_mesh, _pole_material, Vector3(0.0, top_m + FLAG_POLE_M * 0.5, 0.0))
	# The quad lies in its X-Y plane from the pole: turned a quarter round, it points along +Z.
	var flag: MeshInstance3D = _add_part(node, "Flag", _flag_mesh, material, Vector3(0.0, top_m + FLAG_POLE_M, 0.0))
	flag.rotation = Vector3(0.0, -PI * 0.5, 0.0)


func _add_part(node: Node3D, part_name: String, mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var part: MeshInstance3D = MeshInstance3D.new()
	part.name = part_name
	part.mesh = mesh
	part.material_override = material
	part.position = at
	node.add_child(part)
	return part


## A faint strip on the water between a line's two ends (none if the course has no such line).
func _add_line(boat_id: String, pin_id: String) -> void:
	var boat: CourseMark = course.mark(boat_id)
	var pin: CourseMark = course.mark(pin_id)
	if boat == null or pin == null:
		return
	var line: MeshInstance3D = MeshInstance3D.new()
	line.name = "Line " + boat_id.get_slice(" ", 0)
	line.mesh = _strip_mesh(boat.position, pin.position)
	line.material_override = _line_material
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shader lifts it onto the waves: let the culling know.
	line.extra_cull_margin = 3.0
	add_child(line)
	_lines.append(line)


# ---------------------------------------------------------------- the shared meshes

func _make_shared_parts() -> void:
	_buoy_mesh = _cylinder(BUOY_RADIUS_M * 0.85, BUOY_RADIUS_M, BUOY_HEIGHT_M, 24)
	_pin_mesh = _cylinder(PIN_RADIUS_M * 0.85, PIN_RADIUS_M, PIN_HEIGHT_M, 16)
	_float_mesh = TorusMesh.new()
	_float_mesh.inner_radius = BUOY_RADIUS_M * 0.9
	_float_mesh.outer_radius = BUOY_RADIUS_M * 1.3
	_float_mesh.rings = 24
	_float_mesh.ring_segments = 8
	_pole_mesh = _cylinder(0.02, 0.02, FLAG_POLE_M, 6)
	_flag_mesh = QuadMesh.new()
	_flag_mesh.size = FLAG_SIZE_M
	# The pole edge at x = 0 and the top edge at y = 0, as on the wind flag.
	_flag_mesh.center_offset = Vector3(FLAG_SIZE_M.x * 0.5, -FLAG_SIZE_M.y * 0.5, 0.0)
	_hull_mesh = _hull()
	_cabin_mesh = BoxMesh.new()
	_cabin_mesh.size = CABIN_SIZE_M
	_mark_material = VisualMath.plain_material(MARK_COLOR)
	_gate_material = VisualMath.plain_material(GATE_COLOR)
	_float_material = VisualMath.plain_material(FLOAT_COLOR)
	_pole_material = VisualMath.plain_material(Color(0.85, 0.85, 0.82))
	_flag_material = _two_sided(FLAG_COLOR)
	_start_flag_material = _two_sided(CourseOverlay.START_FLAG)
	_finish_flag_material = _two_sided(CourseOverlay.FINISH_FLAG)
	_hull_material = VisualMath.plain_material(HULL_COLOR)
	_cabin_material = VisualMath.plain_material(CABIN_COLOR)
	_line_material = ShaderMaterial.new()
	_line_material.shader = load("res://race/course_line.gdshader") as Shader
	set_wave_parameters({}, 0.0)


static func _cylinder(top_radius: float, bottom_radius: float, height: float, segments: int) -> CylinderMesh:
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = top_radius
	cylinder.bottom_radius = bottom_radius
	cylinder.height = height
	cylinder.radial_segments = segments
	cylinder.rings = 1
	return cylinder


static func _two_sided(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = VisualMath.plain_material(color)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## A simple motorboat hull, BOAT_LENGTH_M long: a flat deck, sides that narrow toward a pointed bow
## and down to a narrower bottom, and a flat transom. Stations from the stern to the bow, each
## with the deck's half width and height and the bottom's (heights from the waterline).
static func _hull() -> ArrayMesh:
	var half_length: float = BOAT_LENGTH_M * 0.5
	var z: PackedFloat32Array = PackedFloat32Array([1.0, 0.5, 0.0, -0.5, -0.8, -1.0])
	var deck_half_m: PackedFloat32Array = PackedFloat32Array([1.0, 1.15, 1.15, 0.95, 0.55, 0.0])
	var deck_y: PackedFloat32Array = PackedFloat32Array([0.55, 0.55, 0.6, 0.68, 0.78, 0.85])
	var bottom_half_m: PackedFloat32Array = PackedFloat32Array([0.8, 0.9, 0.85, 0.6, 0.25, 0.0])
	var bottom_y: PackedFloat32Array = PackedFloat32Array([-0.3, -0.35, -0.35, -0.3, -0.12, 0.3])
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var centre: Vector3 = Vector3(0.0, 0.2, 0.0)
	for i: int in range(z.size() - 1):
		for side: float in [-1.0, 1.0]:
			_add_quad(vertices, normals, centre,
				Vector3(side * deck_half_m[i], deck_y[i], z[i] * half_length),
				Vector3(side * deck_half_m[i + 1], deck_y[i + 1], z[i + 1] * half_length),
				Vector3(side * bottom_half_m[i + 1], bottom_y[i + 1], z[i + 1] * half_length),
				Vector3(side * bottom_half_m[i], bottom_y[i], z[i] * half_length))
		for level: int in 2:
			var half: PackedFloat32Array = deck_half_m if level == 0 else bottom_half_m
			var y: PackedFloat32Array = deck_y if level == 0 else bottom_y
			_add_quad(vertices, normals, centre,
				Vector3(half[i], y[i], z[i] * half_length), Vector3(half[i + 1], y[i + 1], z[i + 1] * half_length),
				Vector3(-half[i + 1], y[i + 1], z[i + 1] * half_length), Vector3(-half[i], y[i], z[i] * half_length))
	# The transom.
	_add_quad(vertices, normals, centre,
		Vector3(deck_half_m[0], deck_y[0], half_length), Vector3(-deck_half_m[0], deck_y[0], half_length),
		Vector3(-bottom_half_m[0], bottom_y[0], half_length), Vector3(bottom_half_m[0], bottom_y[0], half_length))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Two flat triangles for four corners in order round a face of a convex shape, turned to face away
## from the shape's centre (Godot draws the side whose corners go clockwise, seen from outside).
static func _add_quad(vertices: PackedVector3Array, normals: PackedVector3Array, centre: Vector3,
		a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_add_triangle(vertices, normals, centre, a, b, c)
	_add_triangle(vertices, normals, centre, a, c, d)


static func _add_triangle(vertices: PackedVector3Array, normals: PackedVector3Array, centre: Vector3,
		a: Vector3, b: Vector3, c: Vector3) -> void:
	var across: Vector3 = (b - a).cross(c - a)
	if across.length() < 1e-6:
		return  # where the sides meet at the bow a corner is there twice: no triangle
	var outward: Vector3 = (a + b + c) / 3.0 - centre
	# (b - a) x (c - a) points away from the side that sees the corners go clockwise: it must point
	# inward for the triangle to face outward.
	if across.dot(outward) > 0.0:
		var swap: Vector3 = b
		b = c
		c = swap
		across = -across
	vertices.append_array([a, b, c])
	var normal: Vector3 = -across.normalized()
	normals.append_array([normal, normal, normal])


## A strip on the still water from one point to another (game X, Z), LINE_WIDTH_M wide, in pieces
## of LINE_STEP_M so it can bend with the waves. UV.y runs across it from 0 to 1.
static func _strip_mesh(from: Vector2, to: Vector2) -> ArrayMesh:
	var pieces: int = maxi(ceili(from.distance_to(to) / LINE_STEP_M), 1)
	var side: Vector2 = (to - from).normalized().orthogonal() * LINE_WIDTH_M * 0.5
	var vertices: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	for i: int in pieces + 1:
		var at: Vector2 = from.lerp(to, float(i) / pieces)
		for edge: int in 2:
			var corner: Vector2 = at + side * (1.0 if edge == 0 else -1.0)
			vertices.append(Vector3(corner.x, 0.0, corner.y))
			uvs.append(Vector2(float(i) / pieces, float(edge)))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLE_STRIP, arrays)
	return mesh
