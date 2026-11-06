class_name CourseOnWater
extends Node3D
## A race course on the water (RACING_PLAN.md, 9A), for the eye only (CLAUDE.md rule 2: nothing
## here feeds back into the physics):
## - a buoy at every mark: a plain upright cylinder, 1.2 m high and 0.7 m wide, in a fluorescent
##   colour that stands out on the water and against the mountains (Max, 6 November 2026: "a
##   cylinder in a bright colour 1,2 m high and 0,7 m wide"): orange for a rounding mark, yellow for
##   the two marks of a gate, each with a small white flag carrying the mark's name; the pin end of
##   the start and the finish line is the same orange buoy, its flag in its line's colour;
## - the committee boat at the start line's boat end and the finish boat at the finish line's:
##   simple white hulls with a short mast and the wind flag of Phase 7 (wind_flag.gd) streaming in
##   the true wind, orange on the committee boat and blue on the finish boat, as the course maker
##   draws them (Sailing Instructions 18.2 and 20); drawn 1.4 times as big as a 6 m boat, mast and
##   flag included, so they are easy to see (Max, 6 November 2026);
## - a faint line on the water between the two ends of the start line and of the finish line, off
##   by default (set_lines_visible; the mini-map always shows the lines).
## Everything floats: every physics tick it is put at the water's height at its spot and tilted
## with the water's slope under it. The boats lie head to wind, as boats at anchor do, and a buoy
## turns with the wind too, so its flag streams downwind.
##
## Cheap: every kind of part shares one mesh and one material between all the marks; no particles,
## no physics bodies, a few water heights per thing per tick.
##
## The course can change while it is raced (the LAN race director moves, adds, removes and renames
## marks): set_course() again with the changed course moves what moved, builds what is new and frees
## what is gone, cheaply enough for ten calls a second while a mark is dragged.
##
## This node stays at the world origin (the lines are drawn in world coordinates). The scene adds
## it, then builds it (main.gd, --course=<name>):
##   var on_water: CourseOnWater = CourseOnWater.new()
##   add_child(on_water)
##   on_water.build(course, height_at, clock, wind_at)
## and later, for a changed course: on_water.set_course(course)

enum Kind { BUOY, PIN, BOAT }

## Every buoy (a rounding mark, a gate's mark, a line's pin end): a plain cylinder this high and
## this wide across (Max's numbers), metres.
const BUOY_HEIGHT_M: float = 1.2
const BUOY_RADIUS_M: float = 0.35
## How deep it floats: the part of its height under the water, metres (1.1 m stands out of it).
const BUOY_DRAFT_M: float = 0.1
## The flag on a buoy: on a pole this tall above the buoy's top, this big (along the wind, high).
const FLAG_POLE_M: float = 0.9
const FLAG_SIZE_M: Vector2 = Vector2(0.6, 0.4)
## The boats: drawn as a 6 m boat with a cabin, then shown BOAT_SCALE times as big (Max, 6 November
## 2026: "just a bit bigger so it's better to see": 8.4 m long), its mast and flag growing with it so
## they stay in proportion. The wind flag's pole (WindFlag.POLE_HEIGHT_M) is the short mast, standing
## on the cabin roof. In the boat's frame: +X starboard, -Z the bow, the origin on the waterline.
const BOAT_SCALE: float = 1.4
const BOAT_LENGTH_M: float = 6.0
const CABIN_SIZE_M: Vector3 = Vector3(1.6, 0.9, 2.0)
const CABIN_AT: Vector3 = Vector3(0.0, 1.05, 0.6)
const MAST_FOOT: Vector3 = Vector3(0.0, 1.5, 0.6)
## How far from its middle the water is read for a floating thing's tilt: across and along it, m
## (a boat's as drawn; times BOAT_SCALE on the water).
const BUOY_FOOTPRINT_M: Vector2 = Vector2(0.4, 0.4)
const BOAT_FOOTPRINT_M: Vector2 = Vector2(1.1, 2.8)
## The lines on the water: a strip this wide, made of pieces this long, metres.
const LINE_WIDTH_M: float = 0.25
const LINE_STEP_M: float = 1.0
## Below this wind (m/s) the boats keep the way they lie.
const CALM_MS: float = 0.2

## Fluorescent orange and yellow, the colours of real inflatable race marks.
const MARK_COLOR: Color = Color(1.0, 0.36, 0.0)
const GATE_COLOR: Color = Color(1.0, 0.9, 0.0)
## Fluorescent paint gives back more light than it gets: the buoys glow a little, so they stay
## bright on their shaded side and far away (the share of their own colour they give off).
const BUOY_GLOW: float = 0.45
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
	## How many times as big as drawn it is shown (a boat: BOAT_SCALE; a buoy: 1).
	var size: float = 1.0
	## The wind flag on a boat's mast (null on a buoy).
	var flag: WindFlag = null


## A line on the water and the two ends it was drawn between (game X, Z).
class Line:
	var node: MeshInstance3D
	var from: Vector2
	var to: Vector2


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
## Everything floating, in the course's order of marks.
var _floaters: Array[Floater] = []
## The lines on the water, by the name of the boat at their end (CourseMark.START_BOAT, FINISH_BOAT).
var _lines: Dictionary[String, Line] = {}
## The way into the wind (horizontal, one metre long), kept through a calm.
var _into_wind: Vector3 = Vector3.FORWARD

# The parts every mark shares.
var _buoy_mesh: CylinderMesh
var _pole_mesh: CylinderMesh
var _flag_mesh: QuadMesh
var _hull_mesh: ArrayMesh
var _cabin_mesh: BoxMesh
var _mark_material: StandardMaterial3D
var _gate_material: StandardMaterial3D
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
	_height_at = height_at
	_clock = clock
	_wind_at = wind_at
	var axis: Vector2 = Course.direction_of(race_course.axis_deg)
	_into_wind = Vector3(axis.x, 0.0, axis.y)
	# Like the windsurfer: it stops while the game is paused. And it runs after the windsurfer
	# (priority 0) has stepped the simulation, so the water's clock is this tick's.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = 1
	_make_shared_parts()
	set_course(race_course)


## The course on the water again, changed or not (the LAN race director edits it while the fleet
## races). Each mark is known by its name: a mark that moved is moved (its buoy or boat stays the
## same node), a new name gets a new buoy or boat, a name that is gone has its pieces freed; a line
## whose ends moved is drawn again. A renamed mark is a new one (its name is on its flag). The
## course may be the same object changed in place, or a new one. Cheap: a few lookups and transforms
## per mark, a new line strip only when an end of it moved. build() must have run first.
func set_course(race_course: Course) -> void:
	if _buoy_mesh == null:
		push_error("CourseOnWater.set_course(): build() the course on the water first.")
		return
	course = race_course
	var old: Dictionary[String, Floater] = {}
	for floater: Floater in _floaters:
		old[floater.mark_id] = floater
	var placed: Array[Floater] = []
	var jumped: Array[Floater] = []
	for mark: CourseMark in course.marks:
		var floater: Floater = null
		if old.has(mark.id):
			floater = old[mark.id]
			old.erase(mark.id)
			if floater.at != mark.position:
				floater.at = mark.position
				jumped.append(floater)
		else:
			floater = _add_mark(mark)
			jumped.append(floater)
		placed.append(floater)
	for gone: Floater in old.values():
		_free_floater(gone)
	_floaters = placed
	_update_line(CourseMark.START_BOAT, CourseMark.START_PIN)
	_update_line(CourseMark.FINISH_BOAT, CourseMark.FINISH_PIN)
	update_now()
	# New and moved pieces are put straight at their spot: no sliding in from the old one (or from
	# the origin) over the next tick.
	for floater: Floater in jumped:
		floater.node.reset_physics_interpolation()
		if floater.flag != null:
			floater.flag.reset_physics_interpolation()


## Shows or hides the lines on the water.
func set_lines_visible(shown: bool) -> void:
	lines_visible = shown
	for line: Line in _lines.values():
		line.node.visible = shown


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


## The line on the water that ends at this boat (CourseMark.START_BOAT or FINISH_BOAT; null if none).
func line_at(boat_id: String) -> MeshInstance3D:
	return _lines[boat_id].node if _lines.has(boat_id) else null


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
	floater.node.global_transform = Transform3D((Basis(tilt) * turned).scaled_local(Vector3.ONE * floater.size), on_water)
	if floater.flag != null:
		var mast_foot: Vector3 = floater.node.global_transform * MAST_FOOT
		var flag_wind_ms: Vector3 = Vector3.ZERO
		if _wind_at.is_valid():
			flag_wind_ms = _wind_at.call(mast_foot + Vector3.UP * WindFlag.POLE_HEIGHT_M * floater.size)
		floater.flag.place(mast_foot, -_into_wind, flag_wind_ms.length(), floater.size)


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

## The buoy or the boat for a mark, by its kind.
func _add_mark(mark: CourseMark) -> Floater:
	if mark.is_boat():
		return _add_boat(mark)
	if mark.is_line_end():
		return _add_pin(mark)
	return _add_buoy(mark)


## A mark's pieces go: out of the scene now, freed at the end of the frame (a boat's wind flag with it).
func _free_floater(floater: Floater) -> void:
	remove_child(floater.node)
	floater.node.queue_free()


func _add_buoy(mark: CourseMark) -> Floater:
	var buoy: Floater = _add_floater(Kind.BUOY, mark, "Mark " + mark.id, BUOY_FOOTPRINT_M)
	var node: Node3D = buoy.node
	_add_part(node, "Body", _buoy_mesh, _gate_material if mark.is_gate_mark() else _mark_material,
		Vector3(0.0, BUOY_HEIGHT_M * 0.5 - BUOY_DRAFT_M, 0.0))
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
	return buoy


## A line's pin end: the rounding marks' orange buoy (one look for everything you sail to or round),
## with a flag in its line's colour, as the boat at the line's other end flies (orange: the start,
## blue: the finish). It was a small buoy, the hardest thing to see at the start.
func _add_pin(mark: CourseMark) -> Floater:
	var pin: Floater = _add_floater(Kind.PIN, mark, "Pin " + mark.id, BUOY_FOOTPRINT_M)
	_add_part(pin.node, "Body", _buoy_mesh, _mark_material, Vector3(0.0, BUOY_HEIGHT_M * 0.5 - BUOY_DRAFT_M, 0.0))
	var finish: bool = mark.id == CourseMark.FINISH_PIN
	_add_flag(pin.node, BUOY_HEIGHT_M - BUOY_DRAFT_M, _finish_flag_material if finish else _start_flag_material)
	return pin


func _add_boat(mark: CourseMark) -> Floater:
	var finish: bool = mark.id == CourseMark.FINISH_BOAT
	var boat: Floater = _add_floater(Kind.BOAT, mark, "Finish boat" if finish else "Committee boat", BOAT_FOOTPRINT_M * BOAT_SCALE)
	boat.size = BOAT_SCALE
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
	return boat


## A new floating thing for a mark, in the scene (set_course() keeps the list).
func _add_floater(kind: Kind, mark: CourseMark, node_name: String, footprint_m: Vector2) -> Floater:
	var floater: Floater = Floater.new()
	floater.kind = kind
	floater.mark_id = mark.id
	floater.at = mark.position
	floater.footprint_m = footprint_m
	floater.node = Node3D.new()
	floater.node.name = node_name
	add_child(floater.node)
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


## The faint strip on the water between a line's two ends, as the course has them now: made when the
## course gets the line, drawn again when an end moved, freed when the course loses an end.
func _update_line(boat_id: String, pin_id: String) -> void:
	var boat: CourseMark = course.mark(boat_id)
	var pin: CourseMark = course.mark(pin_id)
	var line: Line = _lines[boat_id] if _lines.has(boat_id) else null
	if boat == null or pin == null:
		if line != null:
			remove_child(line.node)
			line.node.queue_free()
			_lines.erase(boat_id)
		return
	if line == null:
		line = Line.new()
		line.node = MeshInstance3D.new()
		line.node.name = "Line " + boat_id.get_slice(" ", 0)
		line.node.material_override = _line_material
		line.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# The shader lifts it onto the waves: let the culling know.
		line.node.extra_cull_margin = 3.0
		line.node.visible = lines_visible
		add_child(line.node)
		_lines[boat_id] = line
	elif line.from == boat.position and line.to == pin.position:
		return
	line.from = boat.position
	line.to = pin.position
	line.node.mesh = _strip_mesh(boat.position, pin.position)


# ---------------------------------------------------------------- the shared meshes

func _make_shared_parts() -> void:
	_buoy_mesh = _cylinder(BUOY_RADIUS_M, BUOY_RADIUS_M, BUOY_HEIGHT_M, 24)
	_pole_mesh = _cylinder(0.02, 0.02, FLAG_POLE_M, 6)
	_flag_mesh = QuadMesh.new()
	_flag_mesh.size = FLAG_SIZE_M
	# The pole edge at x = 0 and the top edge at y = 0, as on the wind flag.
	_flag_mesh.center_offset = Vector3(FLAG_SIZE_M.x * 0.5, -FLAG_SIZE_M.y * 0.5, 0.0)
	_hull_mesh = _hull()
	_cabin_mesh = BoxMesh.new()
	_cabin_mesh.size = CABIN_SIZE_M
	_mark_material = _fluorescent(MARK_COLOR)
	_gate_material = _fluorescent(GATE_COLOR)
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


## A buoy's skin: the colour, a little glossy, glowing with BUOY_GLOW of its own colour.
static func _fluorescent(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = VisualMath.plain_material(color)
	material.roughness = 0.45
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = BUOY_GLOW
	return material


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
