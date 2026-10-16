extends GutTest
## The sailor figure on screen (sailor_figure.gd, figure_skeleton.gd): the bones keep their
## length, the knees bend like hinges over the toes, the hands hold the boom, and nothing
## turns into NaN, sailing, in a tack and in a fall. The simulation is only read.

const DT: float = 1.0 / 60.0
const LENGTH_TOLERANCE_M: float = 0.002


func _sim(wind_kt: float, heading_deg: float) -> WindsurferSim:
	var sim: WindsurferSim = WindsurferSim.create_default()
	sim.wind_config = sim.wind_config.duplicate()
	sim.wind_config.speed_kt = wind_kt
	sim.wind = WindField.new(sim.wind_config)
	sim.reset(Vector3.ZERO, deg_to_rad(heading_deg))
	return sim


## Sails with the test autopilot for a while (heading 180 is starboard tack, 0 port tack).
func _sail(wind_kt: float, heading_deg: float, seconds: float) -> WindsurferSim:
	var sim: WindsurferSim = _sim(wind_kt, heading_deg)
	var pilot: Autopilot = Autopilot.new()
	pilot.sail = sim.sail
	var controls: SimControls = SimControls.new()
	for i: int in int(seconds / DT):
		pilot.update(sim.telemetry, controls, DT)
		sim.step(DT, controls)
	return sim


func _figure(sim: WindsurferSim) -> SailorFigure:
	var figure: SailorFigure = autofree(SailorFigure.new())
	figure.build(sim.sailor_config)
	return figure


## The boom's direction in the board's axes, as windsurfer.gd works it out.
func _boom_dir(sim: WindsurferSim) -> Vector3:
	var rig_to_board: Basis = sim.body.basis.transposed() * sim.rig.basis
	var angle: float = sim.sail.sail_angle_rad()
	return rig_to_board * Vector3(sin(angle), 0.0, cos(angle))


func _pose(sim: WindsurferSim, figure: SailorFigure) -> FigureSkeleton:
	figure.pose_sailing(sim, _boom_dir(sim))
	return figure.skeleton


func _assert_bones_keep_length(s: FigureSkeleton, where: String) -> void:
	for side: int in [FigureSkeleton.LEFT, FigureSkeleton.RIGHT]:
		assert_almost_eq(s.hips[side].distance_to(s.knees[side]), s.thigh_m, LENGTH_TOLERANCE_M, "thigh, " + where)
		assert_almost_eq(s.knees[side].distance_to(s.ankles[side]), s.shin_m, LENGTH_TOLERANCE_M, "shin, " + where)
		assert_almost_eq(s.shoulders[side].distance_to(s.elbows[side]), s.upper_arm_m, LENGTH_TOLERANCE_M, "upper arm, " + where)
		assert_almost_eq(s.elbows[side].distance_to(s.wrists[side]), s.forearm_m, LENGTH_TOLERANCE_M, "forearm, " + where)
		assert_almost_eq(s.wrists[side].distance_to(s.hands[side]), s.hand_m, LENGTH_TOLERANCE_M, "hand, " + where)
	assert_almost_eq(s.pelvis.distance_to(s.neck), s.torso_m, LENGTH_TOLERANCE_M, "hips to shoulders, " + where)
	assert_almost_eq(s.shoulders[0].distance_to(s.shoulders[1]), 2.0 * s.shoulder_half_m, LENGTH_TOLERANCE_M, "shoulder width, " + where)
	assert_almost_eq(s.hips[0].distance_to(s.hips[1]), 2.0 * s.hip_half_m, LENGTH_TOLERANCE_M, "hip width, " + where)
	assert_almost_eq(s.neck.distance_to(s.head), s.neck_m, LENGTH_TOLERANCE_M, "neck, " + where)


## A knee is a hinge: it lies in the plane of the leg line and the way the foot points, on
## the side the toes point to.
func _assert_knees_over_toes(s: FigureSkeleton, where: String) -> void:
	for side: int in [FigureSkeleton.LEFT, FigureSkeleton.RIGHT]:
		var leg: Vector3 = s.hips[side] - s.ankles[side]
		var normal: Vector3 = leg.cross(s.foot_dirs[side]).normalized()
		var knee: Vector3 = s.knees[side] - s.ankles[side]
		assert_almost_eq(knee.dot(normal), 0.0, 1e-3, "knee in the plane of the foot, " + where)
		var out_of_line: Vector3 = knee - leg.normalized() * knee.dot(leg.normalized())
		assert_gt(out_of_line.dot(s.foot_dirs[side]), 0.0, "knee forward over the toes, " + where)


## The hands are on the boom (or on the mast in a tack): within a few centimetres of where
## they reach for, and that is on the line of the boom.
func _assert_hands_on_boom(sim: WindsurferSim, s: FigureSkeleton, where: String) -> void:
	var boom_dir: Vector3 = _boom_dir(sim)
	var boom_root: Vector3 = sim.hand_grip_body - boom_dir * sim.sailor_config.hand_grip_m
	for side: int in [FigureSkeleton.LEFT, FigureSkeleton.RIGHT]:
		assert_almost_eq(s.hands[side].distance_to(s.hand_targets[side]), 0.0, 0.02, "hand reaches, " + where)
		var from_root: Vector3 = s.hands[side] - boom_root
		var along: float = from_root.dot(boom_dir)
		var off_the_boom: float = (from_root - boom_dir * along).length()
		assert_lt(off_the_boom, 0.03, "hand on the boom line, " + where)
		assert_between(along, 0.1, sim.sail_config.boom_m, "hand between the mast and the clew, " + where)


func _assert_finite(s: FigureSkeleton, where: String) -> void:
	var points: PackedVector3Array = PackedVector3Array([s.pelvis, s.spine, s.neck, s.head, s.hook])
	points.append_array(s.hips)
	points.append_array(s.knees)
	points.append_array(s.ankles)
	points.append_array(s.shoulders)
	points.append_array(s.elbows)
	points.append_array(s.wrists)
	points.append_array(s.hands)
	for point: Vector3 in points:
		assert_true(point.is_finite(), "joint is a number, " + where)
	for basis: Basis in [s.pelvis_basis, s.chest_basis, s.head_basis]:
		assert_true(basis.is_finite(), "orientation is a number, " + where)
		assert_almost_eq(basis.determinant(), 1.0, 1e-3, "orientation is a rotation, " + where)


func _assert_figure_finite(figure: SailorFigure, where: String) -> void:
	for child: Node in figure.find_children("*", "Node3D", true, false):
		assert_true((child as Node3D).transform.is_finite(), "%s is a number, %s" % [child.name, where])


func test_two_bone_limb_keeps_its_bones_and_bends_toward_the_pole() -> void:
	var a: float = 0.43
	var b: float = 0.43
	var cases: Array[Vector3] = [Vector3(0.0, -0.8, 0.0), Vector3(0.3, -0.5, 0.2), Vector3(0.0, -2.0, 0.0), Vector3(0.0, -0.01, 0.0)]
	for target: Vector3 in cases:
		var pole: Vector3 = Vector3.FORWARD
		var joints: PackedVector3Array = FigureSkeleton.solve_two_bone(Vector3.ZERO, target, a, b, pole)
		assert_almost_eq(joints[0].length(), a, 1e-4, "first bone keeps its length")
		assert_almost_eq(joints[0].distance_to(joints[1]), b, 1e-4, "second bone keeps its length")
		if target.length() < a + b and target.length() > absf(a - b):
			assert_almost_eq(joints[1].distance_to(target), 0.0, 1e-3, "the end reaches a target within reach")
			assert_gt(joints[0].dot(pole), 0.0, "the joint bends the way the pole points")
	# Out of reach: straight at the target, stopping short.
	var far: PackedVector3Array = FigureSkeleton.solve_two_bone(Vector3.ZERO, Vector3(0.0, -2.0, 0.0), a, b, Vector3.FORWARD)
	assert_almost_eq(far[1].length(), a + b, 1e-3, "out of reach the limb is straight")


func test_planing_hooked_in_on_both_tacks() -> void:
	for heading: float in [180.0, 0.0]:
		var where: String = "18 kt, heading %d" % int(heading)
		var sim: WindsurferSim = _sail(18.0, heading, 8.0)
		assert_true(sim.telemetry.is_planing, "planing, " + where)
		var figure: SailorFigure = _figure(sim)
		var s: FigureSkeleton = _pose(sim, figure)
		_assert_bones_keep_length(s, where)
		_assert_knees_over_toes(s, where)
		_assert_hands_on_boom(sim, s, where)
		_assert_finite(s, where)
		_assert_figure_finite(figure, where)
		# Hanging out to windward: the hips beyond the windward rail, toward the side the
		# simulation leans to, the body facing the sail, hooked in.
		var windward: float = signf(sim.lean)
		assert_gt(s.pelvis.x * windward, 0.5 * sim.board_config.width_m, "hips out over the water, " + where)
		assert_lt(s.facing_side * windward, 0.0, "facing the sail, " + where)
		assert_true(s.hooked, "hooked in, " + where)
		# The simulation's hiked centre of mass is lower and further from the boom than a
		# body of fixed size can be: the hips go about 0.3 m up and 0.25 m in (see
		# FigureSkeleton._place_pelvis), not more.
		assert_lt(s.pelvis_offset_m, 0.55, "hips near the centre of mass, " + where)
		# The front leg (toward the bow) nearly straight, the back leg bent more.
		var front: int = FigureSkeleton.RIGHT if s.facing_side < 0.0 else FigureSkeleton.LEFT
		var back: int = 1 - front
		assert_lt(s.ankles[front].z, s.ankles[back].z, "the front foot is forward, " + where)
		var front_reach: float = s.hips[front].distance_to(s.ankles[front])
		var back_reach: float = s.hips[back].distance_to(s.ankles[back])
		assert_gt(front_reach, 0.95 * s.leg_length_m(), "front leg nearly straight, " + where)
		assert_gt(front_reach, back_reach, "back leg bent more, " + where)


func test_standing_at_low_speed() -> void:
	var sim: WindsurferSim = _sail(6.0, 180.0, 6.0)
	assert_false(sim.telemetry.is_planing)
	var figure: SailorFigure = _figure(sim)
	var s: FigureSkeleton = _pose(sim, figure)
	_assert_bones_keep_length(s, "standing")
	_assert_knees_over_toes(s, "standing")
	_assert_hands_on_boom(sim, s, "standing")
	_assert_finite(s, "standing")
	# Upright over the board, knees soft, elbows bent, the shoulders below the boom's height.
	assert_lt(absf(s.pelvis.x), 0.5 * sim.board_config.width_m, "hips over the board")
	assert_gt(s.neck.y - s.pelvis.y, 0.85 * s.torso_m, "upright")
	for side: int in [FigureSkeleton.LEFT, FigureSkeleton.RIGHT]:
		var knee_angle: float = rad_to_deg((s.hips[side] - s.knees[side]).angle_to(s.ankles[side] - s.knees[side]))
		assert_between(knee_angle, 120.0, 172.0, "soft knee")
		var elbow_angle: float = rad_to_deg((s.shoulders[side] - s.elbows[side]).angle_to(s.hands[side] - s.elbows[side]))
		assert_between(elbow_angle, 70.0, 130.0, "elbow bent about a right angle")
	assert_false(s.hooked, "not hooked in standing")


func test_tack_turns_the_body_round_without_breaking_it() -> void:
	for action: String in ["steer_left", "steer_right", "tack"]:
		Input.action_release(action)
	var sim: WindsurferSim = _sim(18.0, 180.0)
	var controller: PlayerController = PlayerController.new()
	controller.set_sail(sim.sail, sim.sailor_config)
	var controls: SimControls = SimControls.new()
	controls.sheet = 0.0
	var figure: SailorFigure = _figure(sim)
	var facing_at_start: float = 0.0
	var saw_facing_bow: bool = false
	for i: int in int(40.0 / DT):
		if sim.time_s >= 25.0 and sim.time_s < 25.1:
			Input.action_press("tack")
		else:
			Input.action_release("tack")
		controller.update(sim.telemetry, controls, DT)
		sim.step(DT, controls)
		if sim.sailor_state != WindsurferSim.SailorState.SAILING:
			continue
		var s: FigureSkeleton = _pose(sim, figure)
		if i == int(20.0 / DT):
			facing_at_start = s.facing_side
		if absf(s.facing_side) < 0.2:
			saw_facing_bow = true
		# Checked twice a second (every tick would be thousands of asserts).
		if i % 30 == 0:
			var where: String = "t %.1f s" % sim.time_s
			_assert_bones_keep_length(s, where)
			_assert_knees_over_toes(s, where)
			_assert_finite(s, where)
	Input.action_release("tack")
	assert_eq(facing_at_start, -1.0, "faces port on starboard tack")
	assert_true(saw_facing_bow, "turns round through facing the bow")
	assert_eq(figure.skeleton.facing_side, 1.0, "faces starboard on port tack")


func test_odd_inputs_never_stretch_or_break_the_body() -> void:
	var sim: WindsurferSim = _sail(12.0, 180.0, 3.0)
	var figure: SailorFigure = _figure(sim)
	# The grip far out of reach, then right at the feet.
	sim.hand_grip_body = Vector3(-2.5, 3.0, 2.0)
	var s: FigureSkeleton = _pose(sim, figure)
	_assert_bones_keep_length(s, "grip out of reach")
	_assert_finite(s, "grip out of reach")
	sim.hand_grip_body = sim.feet_body
	s = _pose(sim, figure)
	_assert_bones_keep_length(s, "grip at the feet")
	_assert_finite(s, "grip at the feet")
	_assert_figure_finite(figure, "grip at the feet")


func test_fall_poses_without_error() -> void:
	var sim: WindsurferSim = _sail(18.0, 180.0, 6.0)
	var figure: SailorFigure = _figure(sim)
	_pose(sim, figure)
	sim.force_fall("catapult")
	var controls: SimControls = SimControls.new()
	for eased: float in [0.0, 0.25, 0.5, 1.0]:
		sim.step(DT, controls)
		figure.pose_fallen(sim, eased)
		_assert_figure_finite(figure, "fall at %.2f" % eased)
	assert_eq(sim.sailor_state, WindsurferSim.SailorState.FALLEN)
	assert_false(figure.find_child("HarnessLineLeft", true, false).visible, "no harness line in the water")
