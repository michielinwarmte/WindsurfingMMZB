class_name ForceArrows
extends Node3D
## The debug view of the forces (F3, plan Phase 6): one arrow per force, from the point where
## the force acts, pointing the way it pushes, METRES_PER_NEWTON long per newton, in its own
## colour, drawn through everything so none hides behind the sail or under the water. A small
## legend names the colours. The arrows live in the world's axes (top_level) and are set
## every physics tick, so physics interpolation moves them smoothly with the board.

## 1 m of arrow per 500 N.
const METRES_PER_NEWTON: float = 1.0 / 500.0
const SHAFT_RADIUS_M: float = 0.03
const HEAD_LENGTH_M: float = 0.2
const HEAD_RADIUS_M: float = 0.08

## The forces, in the order of the legend: name, colour, what it is.
const FORCES: Array[Array] = [
	["sail", Color(1.0, 0.55, 0.1), "sail force, at the centre of effort"],
	["fin", Color(0.1, 0.85, 0.95), "fin force, at the fin"],
	["fin up", Color(0.6, 1.0, 1.0), "the upward part of the fin force (the heel and the bend, U2)"],
	["buoyancy", Color(0.3, 0.45, 1.0), "buoyancy, at the centre of buoyancy"],
	["planing", Color(0.35, 0.9, 0.3), "planing lift, at its centre of pressure"],
	["drag", Color(0.95, 0.2, 0.2), "hull drag, at the wet bottom"],
	["weight", Color(0.9, 0.35, 0.9), "sailor's weight"],
]

var _arrows: Dictionary[String, Node3D] = {}
var _vectors: Dictionary[String, Vector3] = {}
var _legend: CanvasLayer


func _ready() -> void:
	name = "ForceArrows"
	top_level = true
	for entry: Array in FORCES:
		_arrows[entry[0]] = _make_arrow(entry[0], entry[1])
	_legend = _make_legend()
	add_child(_legend)
	visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()


## Lays the arrow of one force: from where it acts, along the force, its length in proportion.
func set_force(force_name: String, at_world: Vector3, force_n: Vector3) -> void:
	var arrow: Node3D = _arrows[force_name]
	var vector: Vector3 = force_n * METRES_PER_NEWTON
	_vectors[force_name] = vector
	var length_m: float = vector.length()
	arrow.visible = length_m > 0.01
	if not arrow.visible:
		return
	arrow.global_transform = Transform3D(VisualMath.basis_with_up(vector), at_world)
	var head_m: float = minf(HEAD_LENGTH_M, length_m * 0.5)
	var shaft: Node3D = arrow.get_node("Shaft") as Node3D
	shaft.scale = Vector3(1.0, length_m - head_m, 1.0)
	shaft.position = Vector3(0.0, 0.5 * (length_m - head_m), 0.0)
	var head: Node3D = arrow.get_node("Head") as Node3D
	head.scale = Vector3.ONE * (head_m / HEAD_LENGTH_M)
	head.position = Vector3(0.0, length_m - 0.5 * head_m, 0.0)


## The arrow of one force as drawn, from its foot to its tip, in metres (world).
func arrow_vector(force_name: String) -> Vector3:
	return _vectors.get(force_name, Vector3.ZERO)


## Where the arrow's tip is drawn (world), from the arrow's own nodes.
func arrow_tip(force_name: String) -> Vector3:
	var arrow: Node3D = _arrows[force_name]
	var head: Node3D = arrow.get_node("Head") as Node3D
	return arrow.global_transform * (head.position + Vector3.UP * (0.5 * HEAD_LENGTH_M * head.scale.y))


func _make_arrow(force_name: String, color: Color) -> Node3D:
	var arrow: Node3D = Node3D.new()
	arrow.name = force_name.capitalize()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	# Drawn through the sail and the water, after everything else.
	material.no_depth_test = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.render_priority = 10
	var shaft_mesh: CylinderMesh = CylinderMesh.new()
	shaft_mesh.top_radius = SHAFT_RADIUS_M
	shaft_mesh.bottom_radius = SHAFT_RADIUS_M
	shaft_mesh.height = 1.0
	shaft_mesh.radial_segments = 8
	var head_mesh: CylinderMesh = CylinderMesh.new()
	head_mesh.top_radius = 0.0
	head_mesh.bottom_radius = HEAD_RADIUS_M
	head_mesh.height = HEAD_LENGTH_M
	head_mesh.radial_segments = 10
	for part: Array in [["Shaft", shaft_mesh], ["Head", head_mesh]]:
		var instance: MeshInstance3D = MeshInstance3D.new()
		instance.name = part[0]
		instance.mesh = part[1]
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arrow.add_child(instance)
	add_child(arrow)
	return arrow


## The legend at the right of the screen: each colour and what it shows, and the scale.
func _make_legend() -> CanvasLayer:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "Legend"
	layer.layer = 5
	var panel: PanelContainer = PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -330.0
	panel.offset_right = -16.0
	# Below the compass and the HUD's detail panel.
	panel.offset_top = 230.0
	var label: RichTextLabel = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.add_theme_font_size_override("normal_font_size", 13)
	var lines: PackedStringArray = PackedStringArray(["[b]Forces[/b] (F3), 1 m = %d N" % roundi(1.0 / METRES_PER_NEWTON)])
	for entry: Array in FORCES:
		lines.append("[color=#%s]■[/color] %s" % [(entry[1] as Color).to_html(false), entry[2]])
	label.text = "\n".join(lines)
	panel.add_child(label)
	layer.add_child(panel)
	return layer


func _on_visibility_changed() -> void:
	if _legend != null:
		_legend.visible = is_visible_in_tree()
