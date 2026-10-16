extends GutTest
## The equipment's 3D models (res://assets/models/, built by tools/blender/build_rig_models.py)
## and RigVisuals, which poses them: each model has the size, place and orientation of the
## configured equipment, the rig poses where the simulation says without errors, and the
## sail's belly goes to the leeward side.

const BOARD_PATH: String = "res://assets/models/board.glb"
const FIN_PATH: String = "res://assets/models/fin.glb"
const MAST_PATH: String = "res://assets/models/mast.glb"
const SAIL_PATH: String = "res://assets/models/sail.glb"
const BOOM_PATH: String = "res://assets/models/boom.glb"

var board_config: BoardConfig = preload("res://config/board_default.tres")
var sail_config: SailConfig = preload("res://config/sail_default.tres")
var fin_config: FinConfig = preload("res://config/fin_default.tres")
var sailor_config: SailorConfig = preload("res://config/sailor_default.tres")


# --- The models --------------------------------------------------------------------------

func test_board_has_the_configured_size() -> void:
	var box: AABB = _bounds(_points(BOARD_PATH, "Hull"))
	assert_almost_eq(box.size.z, board_config.length_m, 0.03, "Length along z")
	assert_almost_eq(box.size.x, board_config.width_m, 0.02, "Width along x")
	assert_almost_eq(box.position.y, -0.5 * board_config.thickness_m, 0.005, "The bottom")
	assert_almost_eq(box.end.y, 0.5 * board_config.thickness_m, 0.005, "The deck in the middle")
	assert_almost_eq(box.get_center().z, 0.0, 0.01, "Centred on the board's origin")


func test_board_points_its_bow_to_minus_z() -> void:
	var hull: PackedVector3Array = _points(BOARD_PATH, "Hull")
	var half: float = 0.5 * board_config.length_m
	# The nose rocker lifts the bottom near the bow; the tail is squared off and wide.
	assert_gt(_lowest_y(hull, -half, -half + 0.3), _lowest_y(hull, half - 0.3, half) + 0.03, "The nose (at -z) rises")
	assert_gt(_widest_x(hull, half - 0.1, half), _widest_x(hull, -half, -half + 0.1) + 0.04, "The tail (at +z) is wider than the nose")


func test_deck_is_at_the_mast_foot_height() -> void:
	var foot: Vector3 = sail_config.mast_foot_local
	var deck_y: float = _highest_y(_points(BOARD_PATH, "Hull"), foot.z - 0.03, foot.z + 0.03)
	assert_almost_eq(deck_y, foot.y, 0.003, "The mast foot stands on the deck")


func test_fin_hangs_down_with_its_leading_edge_forward() -> void:
	var fin: PackedVector3Array = _points(FIN_PATH)
	var box: AABB = _bounds(fin)
	assert_almost_eq(-box.position.y, fin_config.span_m, 0.01, "Span below the root")
	assert_lt(box.end.y, 0.03, "Only a little of the root goes up into the board")
	# A swept fin: the tip's leading edge is behind the root's (aft is +z).
	var root_front: float = _front_z(fin, -0.02, 0.1)
	var tip_front: float = _front_z(fin, -fin_config.span_m, -fin_config.span_m + 0.04)
	assert_gt(tip_front, root_front + 0.05, "The fin sweeps back")
	assert_lt(box.size.x, 0.03, "A thin foil")


func test_mast_runs_up_from_the_foot() -> void:
	var box: AABB = _bounds(_points(MAST_PATH))
	assert_almost_eq(box.position.y, 0.0, 0.005, "The joint starts at the mast foot")
	assert_almost_eq(box.end.y, sail_config.mast_m, 0.01, "Mast length")
	assert_lt(box.size.x, 0.1, "Thin")
	assert_lt(box.size.z, 0.1, "Thin")


func test_sail_spans_the_luff_and_reaches_the_clew_at_the_boom() -> void:
	var cloth: PackedVector3Array = _points(SAIL_PATH, "SailCloth", "sail_cloth")
	var box: AABB = _bounds(cloth)
	assert_between(box.end.y, sail_config.mast_m - 0.1, sail_config.mast_m, "The head near the mast top")
	assert_lt(box.position.y, 0.3, "The foot comes down near the deck")
	assert_almost_eq(box.size.z, 0.0, 0.001, "Flat: the shader bends it")
	var clew: Vector3 = Vector3(sail_config.boom_m, sail_config.boom_height_m, 0.0)
	assert_lt(_nearest_distance(cloth, clew), 0.01, "A corner of the cloth at the clew")
	assert_almost_eq(box.end.x, sail_config.boom_m, 0.06, "Nothing much behind the clew")


func test_sail_has_about_the_configured_area() -> void:
	var area_m2: float = _surface_area(SAIL_PATH, "SailCloth", ["sail_cloth", "sail_window"])
	assert_almost_eq(area_m2, sail_config.area_m2, 0.1 * sail_config.area_m2, "Sail area")


func test_sail_has_the_surfaces_and_chords_the_shader_needs() -> void:
	var mesh: Mesh = _mesh(SAIL_PATH, "SailCloth")
	var names: Array[String] = []
	for surface: int in mesh.get_surface_count():
		names.append(mesh.surface_get_material(surface).resource_name)
	assert_has(names, "sail_cloth")
	assert_has(names, "sail_window")
	assert_has(names, "sail_sleeve")
	# UV2.x holds each batten line's chord: at the clew, the boom's length.
	var arrays: Array = mesh.surface_get_arrays(names.find("sail_cloth"))
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	assert_eq(uv2.size(), vertices.size(), "Every vertex has a chord")
	var clew_index: int = _nearest_index(vertices, Vector3(sail_config.boom_m, sail_config.boom_height_m, 0.0))
	assert_almost_eq(uv2[clew_index].x, sail_config.boom_m, 0.02, "The chord at the boom")


func test_boom_reaches_from_the_mast_to_the_clew() -> void:
	var box: AABB = _bounds(_points(BOOM_PATH))
	assert_between(box.position.x, -0.25, -0.1, "The boom head in front of the mast")
	assert_gt(box.end.x, sail_config.boom_m + 0.1, "The tail end behind the clew")
	assert_between(box.end.z, 0.25, 0.31, "A wishbone 0.5 to 0.6 m wide")
	assert_almost_eq(box.position.z, -box.end.z, 0.001, "Symmetric")


func test_boom_arm_width_at_the_grip_matches_rig_visuals() -> void:
	var grip: PackedVector3Array = _points(BOOM_PATH, "Boom", "boom_grip")
	var widest: float = 0.0
	for p: Vector3 in grip:
		if absf(p.x - sailor_config.hand_grip_m) < 0.02:
			widest = maxf(widest, absf(p.z))
	assert_almost_eq(widest, RigVisuals.BOOM_ARM_HALF_WIDTH_AT_GRIP_M + 0.0165, 0.01, "Arm centre plus the grip's radius")


func test_harness_lines_hang_under_the_grip() -> void:
	var hose: AABB = _bounds(_points(BOOM_PATH, "Boom", "harness_hose"))
	assert_lt(hose.position.y, -0.2, "They hang down")
	assert_almost_eq(hose.get_center().x, sailor_config.hand_grip_m, 0.05, "Centred on the hands")


# --- Posing the rig ----------------------------------------------------------------------

func test_board_and_fin_sit_in_board_axes() -> void:
	var rig: RigVisuals = _rig()
	assert_eq((rig.get_node("Board") as Node3D).transform, Transform3D.IDENTITY)
	assert_eq((rig.get_node("Fin") as Node3D).position, fin_config.root_local)


func test_rig_poses_where_the_simulation_says() -> void:
	var rig: RigVisuals = _rig()
	var foot: Vector3 = sail_config.mast_foot_local
	for pose: Array[Vector3] in _poses():
		var mast_dir: Vector3 = pose[0]
		var boom_dir: Vector3 = pose[1]
		rig.pose_sailing(mast_dir, boom_dir)
		var sail: Node3D = rig.get_node("Sail") as Node3D
		var boom: Node3D = rig.get_node("Sail/Boom") as Node3D
		var mast: Node3D = rig.get_node("Mast") as Node3D
		assert_true(sail.transform.is_finite() and mast.transform.is_finite(), "No NaN")
		var clew: Vector3 = sail.transform * Vector3(sail_config.boom_m, sail_config.boom_height_m, 0.0)
		var expected_clew: Vector3 = foot + mast_dir * sail_config.boom_height_m + boom_dir * sail_config.boom_m
		assert_almost_eq(clew, expected_clew, Vector3.ONE * 1e-4, "The clew at the boom's end")
		var boom_head: Vector3 = (sail.transform * boom.transform).origin
		assert_almost_eq(boom_head, foot + mast_dir * sail_config.boom_height_m, Vector3.ONE * 1e-4, "The boom on the mast")
		var mast_top: Vector3 = mast.transform * Vector3(0.0, sail_config.mast_m, 0.0)
		assert_almost_eq(mast_top, foot + mast_dir * sail_config.mast_m, Vector3.ONE * 1e-4, "The mast along mast_dir")


func test_belly_bulges_to_the_side_the_boom_is_on() -> void:
	var rig: RigVisuals = _rig()
	for sail_side: int in [-1, 1]:
		var boom_dir: Vector3 = Vector3(sail_side * sin(deg_to_rad(20.0)), 0.0, cos(deg_to_rad(20.0)))
		rig.pose_sailing(Vector3.UP, boom_dir)
		var sail_z: Vector3 = (rig.get_node("Sail") as Node3D).transform.basis.z
		var belly: Vector3 = sail_z * RigVisuals.belly_side_for(sail_side, false)
		assert_eq(signf(belly.x), float(sail_side), "Leeward: the boom's side (sail side %d)" % sail_side)
		var backwinded: Vector3 = sail_z * RigVisuals.belly_side_for(sail_side, true)
		assert_eq(signf(backwinded.x), -float(sail_side), "Backwinded: pushed inside out")


func test_shape_sail_follows_the_simulation() -> void:
	var rig: RigVisuals = _rig()
	var sail: SailModel = SailModel.new(sail_config)
	sail.sail_side = 1
	sail.alpha_rad = deg_to_rad(15.0)
	sail.aws_ms = 9.0
	sail.lift_n = 600.0
	rig.shape_sail(sail, 0.0)
	assert_eq(rig.cloth_value("belly_side"), -1.0, "Starts on the leeward side at once")
	assert_almost_eq(rig.cloth_value("flutter"), 0.0, 1e-6, "No flutter at 15 degrees")
	assert_almost_eq(rig.cloth_value("camber"), sail_config.camber, 1e-6, "Full belly")
	assert_between(rad_to_deg(rig.cloth_value("twist_head_rad")), RigVisuals.TWIST_LIGHT_DEG, RigVisuals.TWIST_LOADED_DEG)
	assert_lt(rig.cloth_value("mast_bend_across_m"), 0.0, "The mast bends to leeward with the belly")
	assert_gt(rig.cloth_value("mast_bend_aft_m"), 0.0, "The masthead falls back")
	# Luffing: the flutter builds up and the belly goes slack.
	sail.alpha_rad = 0.0
	for i: int in 30:
		rig.shape_sail(sail, 0.1 * (i + 1))
	assert_almost_eq(rig.cloth_value("flutter"), 1.0, 1e-6, "Luffing hard")
	assert_lt(rig.cloth_value("camber"), 0.5 * sail_config.camber, "Slack")
	# The sail goes over: the belly crosses smoothly, not in one tick.
	sail.sail_side = -1
	rig.shape_sail(sail, 3.1)
	assert_between(rig.cloth_value("belly_side"), -1.0, 0.99, "Still on its way")
	for i: int in 10:
		rig.shape_sail(sail, 3.2 + 0.1 * i)
	assert_eq(rig.cloth_value("belly_side"), 1.0, "On the new leeward side")


func test_windward_arm_is_on_the_side_the_wind_comes_from() -> void:
	var rig: RigVisuals = _rig()
	var sail: SailModel = SailModel.new(sail_config)
	var time_s: float = 0.0
	for sail_side: int in [-1, 1]:
		sail.sail_side = sail_side
		var boom_dir: Vector3 = Vector3(sail_side * sin(deg_to_rad(20.0)), 0.0, cos(deg_to_rad(20.0)))
		rig.pose_sailing(Vector3.UP, boom_dir)
		for i: int in 15:  # 1.5 s: the belly has gone over
			time_s += 0.1
			rig.shape_sail(sail, time_s)
		var offset: Vector3 = rig.windward_arm_offset()
		assert_eq(signf(offset.x), -float(sail_side), "Windward is away from the boom's side")
		assert_almost_eq(offset.length(), RigVisuals.BOOM_ARM_HALF_WIDTH_AT_GRIP_M, 1e-4)


func test_fall_lays_the_rig_on_the_water() -> void:
	var rig: RigVisuals = _rig()
	rig.pose_sailing(Vector3.UP, Vector3(0.3, 0.0, 0.95).normalized())
	for side: float in [-1.0, 1.0]:
		rig.pose_fallen(0.5, side)
		var mast: Node3D = rig.get_node("Mast") as Node3D
		assert_true(mast.transform.is_finite(), "No NaN half way down")
		rig.pose_fallen(1.0, side)
		var top: Vector3 = mast.transform * Vector3(0.0, sail_config.mast_m, 0.0)
		assert_lt(top.y, sail_config.mast_foot_local.y + 0.3, "The mast lies down")
		assert_eq(signf(top.x), side, "On the side of the fall")
		assert_true((rig.get_node("Sail") as Node3D).transform.is_finite(), "No NaN")


func test_luff_amount() -> void:
	assert_eq(RigVisuals.luff_amount(0.0, 5.0), 1.0)
	assert_eq(RigVisuals.luff_amount(-4.0, 5.0), 1.0)
	assert_eq(RigVisuals.luff_amount(13.0, 5.0), 0.0)
	assert_between(RigVisuals.luff_amount(8.0, 5.0), 0.01, 0.99)


# --- Helpers -----------------------------------------------------------------------------

func _rig() -> RigVisuals:
	var rig: RigVisuals = RigVisuals.new()
	add_child_autofree(rig)
	rig.build(board_config, sail_config, fin_config)
	return rig


## Mast and boom directions in board axes: upright, raked back, raked forward and leaning,
## the boom on either side and sheeted in or out.
func _poses() -> Array[Array]:
	var poses: Array[Array] = []
	for rake_deg: float in [0.0, 20.0, -15.0]:
		for lean_deg: float in [0.0, -25.0]:
			for boom_deg: float in [-60.0, -12.0, 12.0, 60.0]:
				var rake: float = deg_to_rad(rake_deg)
				var lean: float = deg_to_rad(lean_deg)
				var mast_dir: Vector3 = Vector3(sin(lean), cos(lean) * cos(rake), cos(lean) * sin(rake))
				var boom_dir: Vector3 = Vector3(sin(deg_to_rad(boom_deg)), 0.0, cos(deg_to_rad(boom_deg)))
				var pose: Array[Vector3] = [mast_dir, boom_dir]
				poses.append(pose)
	return poses


func _mesh(path: String, node_name: String) -> Mesh:
	var root: Node = (load(path) as PackedScene).instantiate()
	var mesh: Mesh = (root.find_child(node_name, true, false) as MeshInstance3D).mesh
	root.free()
	return mesh


## Every vertex of a model's meshes in the model's own axes, optionally only one mesh node
## and one material.
func _points(path: String, node_name: String = "", material_name: String = "") -> PackedVector3Array:
	var root: Node3D = (load(path) as PackedScene).instantiate() as Node3D
	var points: PackedVector3Array = PackedVector3Array()
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		if node_name != "" and node.name != node_name:
			continue
		var to_root: Transform3D = _transform_to(node as Node3D, root)
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for surface: int in mesh.get_surface_count():
			if material_name != "" and mesh.surface_get_material(surface).resource_name != material_name:
				continue
			var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in vertices:
				points.append(to_root * vertex)
	root.free()
	assert_gt(points.size(), 0, "%s has vertices (%s %s)" % [path, node_name, material_name])
	return points


## The area of some surfaces of one mesh node, m2.
func _surface_area(path: String, node_name: String, material_names: Array[String]) -> float:
	var mesh: Mesh = _mesh(path, node_name)
	var area: float = 0.0
	for surface: int in mesh.get_surface_count():
		if not material_names.has(mesh.surface_get_material(surface).resource_name):
			continue
		var arrays: Array = mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for i: int in range(0, indices.size(), 3):
			var a: Vector3 = vertices[indices[i]]
			area += 0.5 * (vertices[indices[i + 1]] - a).cross(vertices[indices[i + 2]] - a).length()
	return area


func _transform_to(node: Node3D, root: Node3D) -> Transform3D:
	var result: Transform3D = Transform3D.IDENTITY
	var current: Node3D = node
	while current != root and current != null:
		result = current.transform * result
		current = current.get_parent() as Node3D
	return result


func _bounds(points: PackedVector3Array) -> AABB:
	var box: AABB = AABB(points[0], Vector3.ZERO)
	for p: Vector3 in points:
		box = box.expand(p)
	return box


func _lowest_y(points: PackedVector3Array, z_from: float, z_to: float) -> float:
	var lowest: float = INF
	for p: Vector3 in points:
		if p.z >= z_from and p.z <= z_to:
			lowest = minf(lowest, p.y)
	return lowest


func _highest_y(points: PackedVector3Array, z_from: float, z_to: float) -> float:
	var highest: float = -INF
	for p: Vector3 in points:
		if p.z >= z_from and p.z <= z_to:
			highest = maxf(highest, p.y)
	return highest


func _widest_x(points: PackedVector3Array, z_from: float, z_to: float) -> float:
	var widest: float = 0.0
	for p: Vector3 in points:
		if p.z >= z_from and p.z <= z_to:
			widest = maxf(widest, absf(p.x))
	return widest


## The most forward z among the points between two heights.
func _front_z(points: PackedVector3Array, y_from: float, y_to: float) -> float:
	var front: float = INF
	for p: Vector3 in points:
		if p.y >= y_from and p.y <= y_to:
			front = minf(front, p.z)
	return front


func _nearest_index(points: PackedVector3Array, target: Vector3) -> int:
	var best: int = 0
	for i: int in points.size():
		if points[i].distance_to(target) < points[best].distance_to(target):
			best = i
	return best


func _nearest_distance(points: PackedVector3Array, target: Vector3) -> float:
	return points[_nearest_index(points, target)].distance_to(target)
