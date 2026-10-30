extends GutTest
## The hull's planing lift on a rockered bottom (PH28, the hull review's finding 1; the report
## Documentation/reports/ph28/hull_suction.md): what a strip behind the spray root may pull
## (BoardConfig.strip_suction_heads) and the heeled bottom as NACA TN 4187's rolled plate
## (BoardConfig.heel_as_rolled_plate). The hull is held still at a trim, a heel and a wet
## length, as Game/dev/hull_probe.gd holds it, and the strips' total is compared with
## Savitsky's (1964) lift for the same plate, computed here on its own.
##
## The numbers in the bands are what the theory gives on the shipped JP SL 72 at the 18 kt
## beam reach's speed (hull_suction.md, section 2): they are a record of the physics, not a
## target the model was fitted to.

const G: float = 9.81
const RHO: float = 1025.0
## The 18 kt beam reach of hull_balance.md section 14, where the review probed the hull.
const SPEED_MS: float = 14.97


func _water() -> WaterConfig:
	return load("res://config/water_default.tres")


## The shipped board (the JP SL 72) with the options set as asked.
func _sl72(suction_heads: float, rolled_plate: float, centre: bool = false) -> BoardConfig:
	var board: BoardConfig = (load("res://config/board_default.tres") as BoardConfig).duplicate()
	board.strip_suction_heads = suction_heads
	board.heel_as_rolled_plate = rolled_plate
	board.push_at_savitsky_centre = centre
	return board


## The old default (the 2.40 m freeride board), flat to 1.5 m from the tail.
func _freeride(suction_heads: float, rolled_plate: float, centre: bool = false) -> BoardConfig:
	var board: BoardConfig = (load("res://config/board_freeride_240.tres") as BoardConfig).duplicate()
	board.strip_suction_heads = suction_heads
	board.heel_as_rolled_plate = rolled_plate
	board.push_at_savitsky_centre = centre
	return board


## The hull and buoyancy models on a board, with a rigid body of about the windsurfer's mass
## that does not turn (the same body as test_hull.gd's).
func _models(board: BoardConfig) -> Dictionary:
	var body: SimRigidBody = SimRigidBody.new()
	body.set_mass_properties(102.0, Basis.IDENTITY.scaled(Vector3(50.0, 6.0, 46.0)), Vector3(0.0, 0.15, 0.1))
	return {
		"hull": HullModel.new(board, _water()),
		"buoyancy": BuoyancyModel.new(board, _water()),
		"body": body,
		"board": board,
	}


## Places the hull at a trim (bow up), a heel (the port rail down) and a height, moving level
## bow first, and evaluates the buoyancy and the hull once, as one substep does.
func _place(m: Dictionary, trim_deg: float, heel_deg: float, height_m: float, speed_ms: float) -> void:
	var body: SimRigidBody = m["body"]
	body.basis = Basis(Vector3.RIGHT, deg_to_rad(trim_deg)) * Basis(Vector3.BACK, deg_to_rad(heel_deg))
	body.set_origin_world(Vector3(0.0, height_m, 0.0))
	body.velocity = Vector3(0.0, 0.0, -speed_ms)
	body.angular_velocity = Vector3.ZERO
	body.internal_velocity = Vector3.ZERO
	body.clear_forces()
	var buoyancy: BuoyancyModel = m["buoyancy"]
	var hull: HullModel = m["hull"]
	buoyancy.apply(body, FlatWater.new(), 0.0, G)
	hull.compute(body, buoyancy, FlatWater.new(), 0.0, G, body.mass_kg, 1.0)


## Holds the hull at a wet length (the low rail's, HullModel.wetted_length_m) by moving it up
## or down until the model's own wet length is the one asked for (bisection, as the probe).
func _held_at(m: Dictionary, trim_deg: float, heel_deg: float, length_m: float, speed_ms: float = SPEED_MS) -> HullModel:
	var low: float = -0.3
	var high: float = 0.3
	var hull: HullModel = m["hull"]
	for i: int in 60:
		var middle: float = 0.5 * (low + high)
		_place(m, trim_deg, heel_deg, middle, speed_ms)
		if hull.wetted_length_m > length_m:
			low = middle
		else:
			high = middle
	_place(m, trim_deg, heel_deg, 0.5 * (low + high), speed_ms)
	assert_almost_eq(hull.wetted_length_m, length_m, 0.01, "held at %.2f m wet" % length_m)
	return hull


## Savitsky's (1964) lift normal to a planing plate: C_L = 0.012 tau^1.1 sqrt(lambda), less the
## deadrise's share, times the dynamic pressure on the beam squared. Computed here, not read
## from the model.
func _savitsky_n(hull: HullModel, lambda_value: float, deadrise_deg: float, heel_deg: float) -> float:
	var tau: float = minf(hull.reference_trim_deg, 15.0)
	var cl_flat: float = 0.012 * pow(tau, 1.1) * sqrt(lambda_value)
	var cl: float = maxf(cl_flat - 0.0065 * deadrise_deg * pow(cl_flat, 0.6), 0.0)
	var beam: float = hull.planing_beam_m * cos(deg_to_rad(heel_deg))
	var u: float = hull.forward_speed_ms
	return cl * 0.5 * RHO * u * u * beam * beam


## Savitsky's lift for the level plate the model anchors on: the low rail's wet length over
## the beam, the board's own vee.
func _savitsky_level_n(hull: HullModel, board: BoardConfig, heel_deg: float) -> float:
	return _savitsky_n(hull, hull.lambda_ratio, board.deadrise_deg, heel_deg)


## The heeled bottom as NACA TN 4187's rolled flat plate (Savitsky, Prowse and Lueders 1958):
## Savitsky's lift at the mean wetted length of the two rails (the high rail dry over
## 2 b tan(heel) / (pi tan(trim)) more than the low one, equation 2) with the heel as an
## added deadrise. The geometry is worked here from the hull's wet span.
func _tn_4187_n(hull: HullModel, board: BoardConfig, heel_deg: float) -> float:
	var aft: float = hull.wetted_aft_m
	var length: float = hull.wetted_length_m
	var beam: float = hull.planing_beam_m * cos(deg_to_rad(heel_deg))
	var body: SimRigidBody = hull._body
	var trim: float = maxf(body.pitch_rad() + hull._chord_angle(aft, aft + length), deg_to_rad(1.0))
	var dry: float = hull.chine_dry_length_m + 2.0 * beam * tan(deg_to_rad(heel_deg)) / (PI * tan(trim))
	var mean_length: float = length - 0.5 * dry if dry < length else 0.5 * length * length / dry
	var lambda_rolled: float = clampf(mean_length / beam, 0.2, board.length_m / beam)
	return _savitsky_n(hull, lambda_rolled, maxf(board.deadrise_deg, heel_deg), heel_deg)


## Where the push sits, metres forward of the aft wet end.
func _push_from_aft_m(hull: HullModel, board: BoardConfig) -> float:
	return 0.5 * board.length_m - hull.cop_local.z - hull.wetted_aft_m


func test_with_the_options_off_the_clip_is_the_old_rule() -> void:
	# The record of A-05 on the shipped board (review_hull.md finding 1): at 2 degrees of heel
	# the lift leaps from 0.8 to 2.2 to 3.3 times Savitsky's between 1.0, 1.28 and 1.5 m wet,
	# because the strips on the rocker that would pull are dropped and the root's push kept.
	var m: Dictionary = _models(_sl72(0.0, 0.0))
	var board: BoardConfig = m["board"]
	var ratios: Array[float] = []
	for length: float in [1.0, 1.28, 1.5]:
		var hull: HullModel = _held_at(m, 1.0, 2.0, length)
		ratios.append(hull.planing_normal_force_n / _savitsky_level_n(hull, board, 2.0))
		assert_eq(hull.planing_pull_n, 0.0, "no strip pulls with the clip")
	assert_between(ratios[0], 0.7, 0.9, "1.0 m: below Savitsky")
	assert_between(ratios[1], 2.0, 2.4, "1.28 m: twice Savitsky")
	assert_between(ratios[2], 3.0, 3.5, "1.5 m: three times Savitsky: the wall")
	# The old board rides on its flat and is Savitsky's or below there: the clip did nothing.
	var old: Dictionary = _models(_freeride(0.0, 0.0))
	var old_hull: HullModel = _held_at(old, 1.0, 0.0, 1.5)
	assert_almost_eq(old_hull.planing_normal_force_n / _savitsky_level_n(old_hull, old["board"], 0.0), 1.0, 0.03, "the freeride at 1.5 m level: Savitsky's")


func test_a_pull_bounded_by_the_waters_head_takes_the_wall_out_of_the_rocker() -> void:
	# strip_suction_heads 1: a strip may pull as hard as the still water's head above its
	# bottom and no harder (below that the air from the rails would get in). On the SL 72 at
	# 2 degrees of heel the lift then rises with the wet length as a planing plate's does,
	# 0.7 to 1.4 times Savitsky's flat plate at 1.0 to 1.5 m (the rocker's root pushes
	# harder than a flat plate's; the heeled under-count at 1.0 m is the rolled plate's
	# item, below), instead of 0.8, 2.2, 3.3.
	var m: Dictionary = _models(_sl72(1.0, 0.0))
	var board: BoardConfig = m["board"]
	var ratios: Array[float] = []
	var pulls: Array[float] = []
	for length: float in [1.0, 1.28, 1.5]:
		var hull: HullModel = _held_at(m, 1.0, 2.0, length)
		ratios.append(hull.planing_normal_force_n / _savitsky_level_n(hull, board, 2.0))
		pulls.append(hull.planing_pull_n)
	assert_between(ratios[0], 0.65, 0.85, "1.0 m heeled: 0.73 of Savitsky")
	assert_between(ratios[1], 1.15, 1.45, "1.28 m heeled: 1.29 of Savitsky")
	assert_between(ratios[2], 1.25, 1.55, "1.5 m heeled: 1.40 of Savitsky")
	assert_lt(ratios[2] / ratios[1], 1.15, "no wall between 1.28 and 1.5 m (the clip's was 1.5 times)")
	assert_gt(pulls[1], 10.0, "the strips on the rocker pull")
	assert_gt(pulls[2], pulls[1], "and more where more of the rocker is wet")
	# Level: 1.05, 1.20, 1.28 of Savitsky (the clip: 1.57, 1.23, 1.45).
	for length: float in [1.0, 1.28, 1.5]:
		var hull: HullModel = _held_at(m, 1.0, 0.0, length)
		assert_between(hull.planing_normal_force_n / _savitsky_level_n(hull, board, 0.0), 0.95, 1.35, "level at %.2f m: near Savitsky" % length)
	# The full strip theory (no bound) would give 1.04 to 1.17 level and 0.72 to 1.16 heeled:
	# the bound keeps part of the root's push that the theory would take back.
	var free: Dictionary = _models(_sl72(1000.0, 0.0))
	var free_hull: HullModel = _held_at(free, 1.0, 2.0, 1.5)
	assert_between(free_hull.planing_normal_force_n / _savitsky_level_n(free_hull, free["board"], 2.0), 1.05, 1.25, "unbounded at 1.5 m heeled: 1.17 of Savitsky")


func test_the_push_sits_at_savitskys_centre_with_the_pull_allowed() -> void:
	# With the strips allowed to pull, or with the clip kept and push_at_savitsky_centre set,
	# the root's push is spread so that the whole push (the strips and the root) has its centre
	# where Savitsky measured it, on both boards, level and heeled, from one to two and a half
	# beams of wet length. With the clip alone the SL 72's push sat 0.15 to 0.27 m ahead of it.
	for options: Array in [[1.0, false], [1000.0, false], [0.0, true]]:
		for board_name: String in ["sl72", "freeride"]:
			var board: BoardConfig = _sl72(options[0], 0.0, options[1]) if board_name == "sl72" else _freeride(options[0], 0.0, options[1])
			var m: Dictionary = _models(board)
			for heel: float in [0.0, 2.0]:
				for length: float in [0.8, 1.0, 1.28, 1.5, 1.8]:
					var hull: HullModel = _held_at(m, 1.0, heel, length)
					assert_almost_eq(_push_from_aft_m(hull, board), hull.savitsky_cop_from_aft_m, 0.05,
						"%s, heads %.0f, centre %s, heel %.0f, %.2f m: the push at Savitsky's centre" % [board_name, options[0], options[1], heel, length])
	var clipped: Dictionary = _models(_sl72(0.0, 0.0))
	var clipped_hull: HullModel = _held_at(clipped, 1.0, 2.0, 1.28)
	assert_gt(_push_from_aft_m(clipped_hull, clipped["board"]) - clipped_hull.savitsky_cop_from_aft_m, 0.1, "the clip's push sat well behind Savitsky's centre")


func test_the_old_boards_lift_is_unchanged_below_one_and_a_half_metres() -> void:
	# The freeride 2.40 is flat to 1.5 m from the tail: nothing there pulls, so the bound
	# changes nothing in its lift at the wet lengths it rode at. Its push does move: level,
	# the old rule had the vee's spray-root push on the forward strips (the chine-dry part),
	# 0.1 to 0.25 m forward of Savitsky's centre, and only the front root's triangle was
	# placed by it (A-03); now the whole push is at Savitsky's centre. Beyond 1.5 m the nose
	# rocker starts and the bound takes the clip's extra away there too (1295 -> 999 N at
	# 1.7 m level).
	var off: Dictionary = _models(_freeride(0.0, 0.0))
	var on: Dictionary = _models(_freeride(1.0, 0.0))
	for heel: float in [0.0, 2.0]:
		for length: float in [1.0, 1.28, 1.5]:
			var off_hull: HullModel = _held_at(off, 1.0, heel, length)
			var off_n: float = off_hull.planing_normal_force_n
			var off_push_ahead: float = _push_from_aft_m(off_hull, off["board"]) - off_hull.savitsky_cop_from_aft_m
			var on_hull: HullModel = _held_at(on, 1.0, heel, length)
			assert_almost_eq(on_hull.planing_normal_force_n, off_n, 0.005 * off_n, "heel %.0f, %.2f m: the same lift" % [heel, length])
			assert_almost_eq(_push_from_aft_m(on_hull, on["board"]), on_hull.savitsky_cop_from_aft_m, 0.02, "the push at Savitsky's centre")
			if heel == 0.0:
				assert_between(off_push_ahead, 0.1, 0.3, "level, %.2f m: the old rule's push sat forward of Savitsky's centre" % length)
			else:
				assert_between(off_push_ahead, -0.02, 0.06, "heeled, %.2f m: the old rule's push about at Savitsky's centre" % length)
	var long_off: HullModel = _held_at(off, 1.0, 0.0, 1.7)
	var long_off_n: float = long_off.planing_normal_force_n
	var long_on: HullModel = _held_at(on, 1.0, 0.0, 1.7)
	assert_lt(long_on.planing_normal_force_n, 0.85 * long_off_n, "on the nose rocker the clip's extra goes")


func test_a_flat_plates_lift_is_unchanged_by_either_option() -> void:
	# A prismatic planing plate has nothing to pull and is wet across from its transom: with
	# the pull allowed and the heel as a rolled plate it keeps Savitsky's lift (test_hull.gd's
	# known state: 7 m/s, 4 degrees, the transom 7.5 cm deep). Its push moves to Savitsky's
	# centre: the old rule had it 9 % of the wet length forward, the 2 degree vee's root push
	# on the chine-dry strips (within test_hull.gd's 10 % band, which is why it was not seen).
	var results: Array[Dictionary] = []
	for options: Array in [[0.0, 0.0], [1.0, 0.0], [1.0, 1.0]]:
		var board: BoardConfig = _freeride(options[0], options[1])
		board.nose_rocker_m = 0.0
		board.tail_rocker_m = 0.0
		board.tail_width_m = board.width_m
		board.nose_width_m = board.width_m
		board.tail_thickness_m = board.thickness_m
		board.nose_thickness_m = board.thickness_m
		var m: Dictionary = _models(board)
		var body: SimRigidBody = m["body"]
		# The transom 7.5 cm deep at 4 degrees of trim: the probe's bisection is not needed.
		var transom_local: Vector3 = Vector3(0.0, -0.5 * board.thickness_m, 0.5 * board.length_m)
		_place(m, 4.0, 0.0, 0.0, 7.0)
		var transom_y_at_zero: float = body.point_world(transom_local).y
		_place(m, 4.0, 0.0, -0.075 - transom_y_at_zero, 7.0)
		assert_almost_eq(body.point_world(transom_local).y, -0.075, 1e-6, "the transom 7.5 cm deep")
		var hull: HullModel = m["hull"]
		results.append({"lift": hull.planing_normal_force_n, "push": _push_from_aft_m(hull, board), "savitsky": _savitsky_level_n(hull, board, 0.0), "centre": hull.savitsky_cop_from_aft_m})
	for r: Dictionary in results:
		assert_almost_eq(float(r["lift"]), float(r["savitsky"]), 0.02 * float(r["savitsky"]), "Savitsky's lift")
		assert_almost_eq(float(r["lift"]), float(results[0]["lift"]), 0.01 * float(results[0]["lift"]), "the same as with the options off")
	assert_between(float(results[0]["push"]) - float(results[0]["centre"]), 0.05, 0.15, "off: the push 9 % of the wet length forward of Savitsky's centre")
	for i: int in [1, 2]:
		assert_almost_eq(float(results[i]["push"]), float(results[i]["centre"]), 0.01, "on: the push at Savitsky's centre")


func test_level_the_rolled_plate_anchor_gives_savitskys_lift_at_short_wet_parts() -> void:
	# At short wet parts the vee's chine-dry front was counted twice (in Savitsky's lambda and
	# again in the strips' narrower wet width), so level the lift was 0.81 and 0.89 of
	# Savitsky's at 0.6 and 0.8 m. With heel_as_rolled_plate the strips' total is anchored
	# on the widest wet strip, and level it is Savitsky's within 10 % at 0.6 and 0.8 m; at
	# 1.0 m the wet front is 0.3 m up the rocker and its root's push shows (1.10, as above).
	# The transom relief is not the cause level: it changes nothing on the flat tail, where
	# the strips' convective forces are nil (hull_suction.md, section 4).
	var off: Dictionary = _models(_sl72(1.0, 0.0))
	var on: Dictionary = _models(_sl72(1.0, 1.0))
	for trim: float in [1.0, 2.0]:
		for length: float in [0.6, 0.8]:
			var off_hull: HullModel = _held_at(off, trim, 0.0, length)
			assert_lt(off_hull.planing_normal_force_n / _savitsky_level_n(off_hull, off["board"], 0.0), 0.98, "trim %.0f, %.1f m: under Savitsky without the anchor on the wet width" % [trim, length])
			var on_hull: HullModel = _held_at(on, trim, 0.0, length)
			assert_almost_eq(on_hull.planing_normal_force_n / _savitsky_level_n(on_hull, on["board"], 0.0), 1.0, 0.1, "trim %.0f, %.1f m: Savitsky's within 10 %%" % [trim, length])
		var one_metre: HullModel = _held_at(on, trim, 0.0, 1.0)
		assert_almost_eq(one_metre.planing_normal_force_n / _savitsky_level_n(one_metre, on["board"], 0.0), 1.0, 0.15, "trim %.0f, 1.0 m: within 15 %% (the rocker's root)" % trim)


func test_heeled_the_lift_follows_tn_4187_at_short_wet_parts() -> void:
	# NACA TN 4187 measured a rolled flat plate: the high chine dry over 2 b tan(heel) /
	# (pi tan(trim)) more of the length, and the roll acting as an added deadrise. With
	# heel_as_rolled_plate the heeled SL 72 carries that lift within 15 % from 0.6 to 1.0 m
	# at 2 and 4.5 degrees of heel; without it, Savitsky's level lift scaled by the wet width
	# gave 0.3 to 0.6 of it at 2 degrees and next to nothing at 4.5.
	var off: Dictionary = _models(_sl72(1.0, 0.0))
	var on: Dictionary = _models(_sl72(1.0, 1.0))
	for trim: float in [1.0, 2.0]:
		for heel: float in [2.0, 4.5]:
			for length: float in [0.6, 0.8, 1.0]:
				var on_hull: HullModel = _held_at(on, trim, heel, length)
				var target: float = _tn_4187_n(on_hull, on["board"], heel)
				assert_almost_eq(on_hull.planing_normal_force_n, target, 0.15 * target, "trim %.0f, heel %.1f, %.1f m: TN 4187's rolled plate within 15 %%" % [trim, heel, length])
				assert_gt(on_hull.planing_normal_force_n, 50.0, "and carries something")
			var off_hull: HullModel = _held_at(off, trim, heel, 0.8)
			assert_lt(off_hull.planing_normal_force_n, 0.85 * _tn_4187_n(off_hull, off["board"], heel), "trim %.0f, heel %.1f, 0.8 m: the old heeled under-count (0.4 to 0.8 of TN 4187)" % [trim, heel])
	# The reported anchor agrees with the lift computed here when the option is on and the
	# board level (the model's own Savitsky at the low rail's wet length).
	var level: HullModel = _held_at(on, 1.0, 0.0, 0.8)
	assert_almost_eq(level.savitsky_lift_n, _savitsky_level_n(level, on["board"], 0.0), 1.0, "the reported anchor is Savitsky's")
