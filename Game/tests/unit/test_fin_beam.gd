extends GutTest
## The bending fin (PHYSICS_SPEC.md section 4, "The fin bends"; U2 in PLAYTEST_UPGRADES.md):
## the fin as a cantilever beam with EI = S * c^4, its stiffness scale set by a flex test, its
## lift spread elliptically, and the bent fin's force tilted up toward the deck.

const RHO: float = 1025.0
const SLIP_DEG: float = 4.0


func _default_config() -> FinConfig:
	return load("res://config/fin_default.tres") as FinConfig


func _fin_with(changes: Dictionary[String, Variant]) -> FinModel:
	var config: FinConfig = _default_config().duplicate() as FinConfig
	for field: String in changes:
		config.set(field, changes[field])
	return FinModel.new(config)


func _body_moving(v_body: Vector3) -> SimRigidBody:
	var body: SimRigidBody = SimRigidBody.new()
	body.set_mass_properties(92.0, Basis.IDENTITY.scaled(Vector3(50.0, 6.0, 46.0)), Vector3(0.0, 0.97, 0.0))
	body.set_origin_world(Vector3.ZERO)  # floating at the origin: the fin root is under water
	body.velocity = v_body  # identity basis: body axes are world axes
	return body


## 8 m/s, slipping SLIP_DEG to port (side = -1) or to starboard (side = +1).
func _slipping(side: float) -> SimRigidBody:
	var a: float = deg_to_rad(SLIP_DEG)
	return _body_moving(8.0 * Vector3(side * sin(a), 0.0, -cos(a)))


func test_the_planform_has_the_fins_area() -> void:
	var config: FinConfig = _default_config()
	assert_almost_eq(config.mean_to_root_chord(), 0.685, 0.002, "the chord law's mean over its root (the brief's 0.686)")
	assert_almost_eq(config.root_chord_m(), 0.140, 0.001, "the default root chord, as in the 3-D model (m)")
	var area: float = 0.0
	for i: int in 1000:
		area += config.root_chord_m() * config.chord_shape((i + 0.5) / 1000.0) * config.span_m / 1000.0
	assert_almost_eq(area, config.area_m2, 1e-4 * config.area_m2, "the planform's area is area_m2")
	assert_almost_eq(config.chord_shape(0.82), 1.0 - 0.63 * pow(0.82, 1.1), 1e-9, "the rounding starts at 0.82")
	assert_eq(config.chord_shape(1.0), 0.0, "a rounded tip")


func test_a_rectangle_with_a_tip_load_bends_as_the_textbook_says() -> void:
	# A constant chord, so a constant EI: delta = P L^3 / (3 EI).
	var fin: FinModel = _fin_with({"tip_chord_ratio": 1.0, "tip_round_start": 1.0})
	var length: float = fin.config.span_m
	var load_n: float = 50.0
	var ei: float = fin.stiffness_scale * pow(fin.config.root_chord_m(), 4.0)
	var expected: float = load_n * pow(length, 3.0) / (3.0 * ei)
	assert_almost_eq(fin.point_load_deflection_m(load_n, 1.0), expected, 0.01 * expected, "tip deflection, P L^3 / (3 EI)")


func test_the_flex_test_calibration_repeats_its_own_deflection() -> void:
	var fin: FinModel = FinModel.new(_default_config())
	assert_almost_eq(fin.point_load_deflection_m(100.0, 0.8), 0.020, 1e-9, "100 N at 80 % of the span moves the load point 20 mm")
	# A test at a span fraction between two strip edges, on a fin of another size.
	var other: FinModel = _fin_with({"span_m": 0.42, "area_m2": 0.040, "flex_test_span_m": 0.42,
		"flex_test_area_m2": 0.040, "flex_test_load_n": 60.0, "flex_test_position": 0.73, "flex_test_deflection_m": 0.011})
	assert_almost_eq(other.point_load_deflection_m(60.0, 0.73), 0.011, 1e-9, "a test between the strip edges")
	assert_gt(fin.stiffness_scale, 0.0)


func test_the_elliptic_loading_adds_up_and_has_its_root_moment() -> void:
	var shares: PackedFloat64Array = FinModel.elliptic_shares(FinModel.BEND_STRIPS)
	var total: float = 0.0
	for share: float in shares:
		total += share
	assert_almost_eq(total, 1.0, 1e-12, "the shares add up to the whole lift")
	assert_gt(shares[0], shares[FinModel.BEND_STRIPS - 1], "the root carries more than the tip")
	var span: float = 0.38
	var lift_n: float = 527.0
	var root_moment: float = lift_n * FinModel.elliptic_moments_per_n(span)[0]
	assert_almost_eq(root_moment, lift_n * 4.0 * span / (3.0 * PI), 1e-9, "the root moment, F 4 L / (3 pi) (N m)")
	assert_eq(FinModel.elliptic_moments_per_n(span)[FinModel.BEND_STRIPS], 0.0, "no moment at the tip")


func test_a_bent_fin_pushes_up_on_both_tacks() -> void:
	var fin: FinModel = FinModel.new(_default_config())
	for side: float in [-1.0, 1.0]:
		fin.compute(_slipping(side), FlatWater.new(), 0.0, RHO)
		assert_gt(fin.force_world.y, 0.0, "the bent fin's force points up toward the deck (slip side %.0f)" % side)
		assert_lt(fin.force_world.x * side, 0.0, "and sideways against the slip")
		assert_gt(rad_to_deg(fin.bend_tip_rad), 1.0, "the tip turns")
		assert_gt(fin.bend_tip_m, 0.0, "the tip moves")
		# The bend tilts the lift but does not change its size much: side^2 + up^2 <= 1.
		var tilted: float = sqrt(fin.side_share * fin.side_share + fin.up_share * fin.up_share)
		assert_between(tilted, 0.99, 1.0, "the tilted lift's size, as a share of the lift")
	fin.compute(_slipping(-1.0), FlatWater.new(), 0.0, RHO)
	var port_up: float = fin.force_world.y
	fin.compute(_slipping(1.0), FlatWater.new(), 0.0, RHO)
	assert_almost_eq(fin.force_world.y, port_up, 1e-6, "the same upward push on both tacks")


func test_no_lift_no_bend() -> void:
	var fin: FinModel = FinModel.new(_default_config())
	fin.compute(_body_moving(Vector3(0.0, 0.0, -8.0)), FlatWater.new(), 0.0, RHO)
	assert_eq(fin.lift_n, 0.0)
	assert_eq(fin.bend_tip_rad, 0.0, "no lift, no bend")
	assert_eq(fin.up_share, 0.0)
	assert_eq(fin.force_world.y, 0.0, "nothing up")


func test_the_stiff_limit_gives_the_old_force() -> void:
	# The stiff plate of before U2: lift square to the flow in the board's plane, drag along it.
	var a: float = deg_to_rad(SLIP_DEG)
	var flow_dir: Vector3 = Vector3(-sin(a), 0.0, -cos(a))
	var stiff: FinModel = _fin_with({"bends": false})
	stiff.compute(_slipping(-1.0), FlatWater.new(), 0.0, RHO)
	var lift_dir: Vector3 = signf(stiff.slip_rad) * Vector3(flow_dir.z, 0.0, -flow_dir.x)
	var old_force: Vector3 = lift_dir * stiff.lift_n - flow_dir * stiff.drag_n
	assert_almost_eq(stiff.force_world, old_force, Vector3.ONE * 1e-9, "switched off: the old force")
	assert_eq(stiff.force_world.y, 0.0, "nothing up")
	assert_eq(stiff.bend_tip_rad, 0.0)
	# A nearly rigid flex test (a nanometre) is the same limit.
	var rigid: FinModel = _fin_with({"flex_test_deflection_m": 1e-9})
	rigid.compute(_slipping(-1.0), FlatWater.new(), 0.0, RHO)
	assert_almost_eq(rigid.force_world, old_force, Vector3.ONE * 1e-4, "a very large S: the old force")


func test_a_longer_fin_of_the_same_material_bends_more() -> void:
	var short: FinModel = FinModel.new(_default_config())
	var long: FinModel = _fin_with({"span_m": 0.44, "area_m2": 0.0411})
	assert_almost_eq(long.stiffness_scale, short.stiffness_scale, 1e-6 * short.stiffness_scale, "the same S")
	assert_gt(long.tip_slope_per_n, short.tip_slope_per_n, "the 44 cm tip turns more")
	assert_gt(long.tip_deflection_per_n, short.tip_deflection_per_n, "and moves more")
	gut.p("per 100 N of lift: 38 cm tip %.2f deg %.1f mm; 44 cm tip %.2f deg %.1f mm; S %.0f N/m^2" % [
		rad_to_deg(100.0 * short.tip_slope_per_n), 1e5 * short.tip_deflection_per_n,
		rad_to_deg(100.0 * long.tip_slope_per_n), 1e5 * long.tip_deflection_per_n, short.stiffness_scale])


func test_the_slopes_are_capped_where_the_linear_beam_ends() -> void:
	var fin: FinModel = FinModel.new(_default_config())
	fin._bend(1.0e6)
	assert_almost_eq(rad_to_deg(fin.bend_tip_rad), 35.0, 1e-9, "the tip at the cap")
	var cap: float = deg_to_rad(35.0)
	assert_almost_eq(fin.up_share, sin(cap), 1e-9, "every strip at the cap")
	assert_almost_eq(fin.side_share, cos(cap), 1e-9)
