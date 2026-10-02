extends GutTest
## Mass, centre of mass and inertia of the composite body (PHYSICS_SPEC.md section 7).


func _defaults() -> MassModel:
	var board: BoardConfig = load("res://config/board_default.tres")
	var sail: SailConfig = load("res://config/sail_default.tres")
	var sailor: SailorConfig = load("res://config/sailor_default.tres")
	return MassModel.new(board, sail, sailor)


func test_total_mass_is_the_sum_of_the_parts() -> void:
	var model: MassModel = _defaults()
	assert_almost_eq(model.total_mass_kg, 92.0, 1e-9, "9 + 8 + 75 kg")


func test_centre_of_mass_at_rest() -> void:
	var model: MassModel = _defaults()
	# Hand calculation: board 9 kg at the origin, rig 8 kg at the mast foot plus 1.7 m up,
	# sailor 75 kg at 1.0 m up and at the resting stance.
	var rig: Vector3 = model.sail.mast_foot_local + Vector3(0.0, 1.7, 0.0)
	var sailor_pos: Vector3 = Vector3(0.0, 1.0, model.sailor.stance_rest_z_m)
	var expected: Vector3 = (8.0 * rig + 75.0 * sailor_pos) / 92.0
	assert_almost_eq(model.com_offset_body, expected, Vector3.ONE * 1e-6)
	assert_almost_eq(model.com_offset_body.y, 0.968, 1e-3, "the centre of mass is about a metre up")


func test_box_alone_matches_the_textbook_formula() -> void:
	var board: BoardConfig = BoardConfig.new()
	board.mass_kg = 8.0
	board.width_m = 0.6
	board.thickness_m = 0.12
	board.length_m = 2.5
	var sail: SailConfig = SailConfig.new()
	sail.rig_mass_kg = 0.0
	var sailor: SailorConfig = SailorConfig.new()
	sailor.mass_kg = 0.0
	var model: MassModel = MassModel.new(board, sail, sailor)
	assert_almost_eq(model.inertia_body.x.x, 8.0 / 12.0 * (0.12 * 0.12 + 2.5 * 2.5), 1e-6, "pitch")
	assert_almost_eq(model.inertia_body.y.y, 8.0 / 12.0 * (0.6 * 0.6 + 2.5 * 2.5), 1e-6, "yaw")
	assert_almost_eq(model.inertia_body.z.z, 8.0 / 12.0 * (0.6 * 0.6 + 0.12 * 0.12), 1e-6, "roll")
	assert_almost_eq(model.inertia_body.x.y, 0.0, 1e-9)


func test_parallel_axis_theorem() -> void:
	# Two point-like masses at (0, 1, 2) and (0, -1, -2): I_xx = 10, I_yy = 8, I_zz = 2, I_yz = -4.
	var tensor: Basis = Basis.IDENTITY.scaled(Vector3.ZERO)
	tensor = MassModel._add_part(tensor, 1.0, Vector3.ZERO, Vector3(0.0, 1.0, 2.0))
	tensor = MassModel._add_part(tensor, 1.0, Vector3.ZERO, Vector3(0.0, -1.0, -2.0))
	assert_almost_eq(tensor.x.x, 10.0, 1e-9)
	assert_almost_eq(tensor.y.y, 8.0, 1e-9)
	assert_almost_eq(tensor.z.z, 2.0, 1e-9)
	assert_almost_eq(tensor.y.z, -4.0, 1e-9, "off-diagonal term from the outer product")
	assert_almost_eq(tensor.z.y, -4.0, 1e-9, "symmetric")


func test_default_inertia_is_dominated_by_the_standing_sailor() -> void:
	var model: MassModel = _defaults()
	var pitch: float = model.inertia_body.x.x
	var yaw: float = model.inertia_body.y.y
	var roll: float = model.inertia_body.z.z
	assert_between(pitch, 45.0, 55.0, "pitch about 50 kg m2")
	assert_between(roll, 40.0, 50.0, "roll about 46 kg m2")
	assert_between(yaw, 5.0, 8.0, "yaw about 6 kg m2: a long light board with the heavy parts on the axis")
	assert_gt(roll, 10.0 * 0.25, "far more than the board slab alone")


func test_stance_moves_the_centre_of_mass_aft_and_lean_moves_it_sideways() -> void:
	var model: MassModel = _defaults()
	var rest: Vector3 = model.com_offset_body
	model.update(1.0, 0.0)
	assert_almost_eq(model.com_offset_body.z - rest.z, 75.0 / 92.0 * (model.sailor.stance_planing_z_m - model.sailor.stance_rest_z_m), 1e-6, "sailor steps back into the straps")
	model.update(0.0, 1.0)
	assert_almost_eq(model.com_offset_body.x, 75.0 / 92.0 * model.sailor.lean_max_m, 1e-6, "lean to starboard is +x")
	assert_lt(model.com_offset_body.y, rest.y, "leaning lowers the centre of mass")
	model.update(0.0, -1.0)
	assert_almost_eq(model.com_offset_body.x, -75.0 / 92.0 * model.sailor.lean_max_m, 1e-6)


func test_knee_bend_lowers_the_sailor() -> void:
	var model: MassModel = _defaults()
	var rest: Vector3 = model.com_offset_body
	model.update(0.0, 0.0, 0.0, 0.1)
	assert_almost_eq(model.sailor_position_body.y, model.sailor.com_height_m - 0.1, 1e-6, "the body sits 10 cm lower")
	assert_almost_eq(rest.y - model.com_offset_body.y, 75.0 / 92.0 * 0.1, 1e-6, "the whole centre of mass follows by the sailor's share")


func test_righting_moment_limit() -> void:
	var model: MassModel = _defaults()
	assert_almost_eq(model.max_righting_moment_nm(9.81), 75.0 * 9.81 * model.sailor.lean_max_m, 1e-6)
