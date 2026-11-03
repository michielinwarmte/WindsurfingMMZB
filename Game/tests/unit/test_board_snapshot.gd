extends GutTest
## The board's whole physics state for LAN multiplayer (BoardSnapshot, Documentation/reports/multiplayer/
## PLAN.md, D4 to D6): read from one simulation, sent as bytes, written into a puppet simulation that
## is never stepped; the puppet then holds what the visuals read, the same as the original.

const DT: float = 1.0 / 60.0


## A board sailed for a while with the controls a beginner would hold: a beam reach, sheeted in.
func _sailed_sim(seconds: float, heading_deg: float = 180.0) -> WindsurferSim:
	var sim: WindsurferSim = WindsurferSim.create_for(EnvironmentConfig.new(), true, true)
	sim.reset(Vector3(10.0, 0.0, -20.0), deg_to_rad(heading_deg))
	var controls: SimControls = SimControls.new()
	controls.sheet = 0.8
	for i: int in roundi(seconds / DT):
		sim.step(DT, controls)
	return sim


func _puppet() -> WindsurferSim:
	var sim: WindsurferSim = WindsurferSim.create_for(EnvironmentConfig.new(), true, true)
	sim.reset(Vector3.ZERO, 0.0)
	return sim


func test_the_layout_holds_the_parts_the_visuals_read_and_is_the_same_twice() -> void:
	var layout: BoardSnapshot.Layout = BoardSnapshot.layout()
	assert_gt(layout.slot_count, 300, "hundreds of numbers")
	assert_eq(BoardSnapshot._make_layout(_puppet()).hash_value, layout.hash_value, "the same scripts give the same layout")
	var names: PackedStringArray = PackedStringArray()
	for field: BoardSnapshot.Field in layout.fields:
		names.append("%s.%s" % [BoardSnapshot.PARTS[field.part], field.name])
	for wanted: String in [".sailor_state", ".fall_kind", ".lean", ".stance", ".feet_body", ".hand_grip_body", ".harness_tension_n",
			"body.basis", "body.position", "body.velocity", "rig.basis", "sail.boom_direction_local", "sail.lift_n", "fin.bend_tip_m",
			"telemetry.heading_deg", "telemetry.speed_ms"]:
		assert_has(names, wanted, "the state holds %s" % wanted)
	gut.p("A board's state: %d fields, %d float slots, %d strings" % [layout.fields.size(), layout.slot_count, layout.text_count])


func test_a_puppet_shows_what_the_original_sailed() -> void:
	var original: WindsurferSim = _sailed_sim(4.0)
	var puppet: WindsurferSim = _puppet()
	BoardSnapshot.capture(original).apply(puppet)
	assert_almost_eq(puppet.body.origin_world().distance_to(original.body.origin_world()), 0.0, 1e-3, "the board's place")
	assert_true(puppet.body.basis.is_equal_approx(original.body.basis), "the board's attitude")
	assert_true(puppet.rig.basis.is_equal_approx(original.rig.basis), "the rig's frame")
	assert_almost_eq(puppet.sail.mast_direction().distance_to(original.sail.mast_direction()), 0.0, 1e-4, "the mast")
	assert_almost_eq(puppet.sail.boom_direction_local.distance_to(original.sail.boom_direction_local), 0.0, 1e-4, "the boom")
	assert_almost_eq(puppet.lean, original.lean, 1e-5, "the sailor's lean")
	assert_almost_eq(puppet.feet_body.distance_to(original.feet_body), 0.0, 1e-5, "the feet")
	assert_almost_eq(puppet.telemetry.speed_ms, original.telemetry.speed_ms, 1e-4, "the speed on the HUD")
	assert_almost_eq(puppet.time_s, original.time_s, 1e-4, "the water's clock")
	assert_eq(puppet.sailor_state, original.sailor_state)
	# A method of a part works on the copied numbers: a point of the board in the world.
	var bow: Vector3 = Vector3(0.0, 0.1, -1.2)
	assert_almost_eq(puppet.body.point_world(bow).distance_to(original.body.point_world(bow)), 0.0, 1e-3)


func test_a_fall_and_its_kind_travel() -> void:
	var original: WindsurferSim = _sailed_sim(2.0)
	original.force_fall("catapult")
	original.step(DT, SimControls.new())
	var puppet: WindsurferSim = _puppet()
	var keyframe: BoardSnapshot = BoardSnapshot.capture(_sailed_sim(0.5))
	var sent: PackedByteArray = BoardSnapshot.capture(original).encode_diff(keyframe)
	BoardSnapshot.decode_diff(sent, keyframe).apply(puppet)
	assert_eq(puppet.sailor_state, WindsurferSim.SailorState.FALLEN, "fallen")
	assert_eq(puppet.fall_kind, original.fall_kind, "the fall's kind (a string)")
	assert_eq(puppet.fall_side, original.fall_side)


func test_the_keyframe_and_the_diff_round_trip_and_the_diff_is_small() -> void:
	var keyframe: BoardSnapshot = BoardSnapshot.capture(_sailed_sim(0.5))
	var full: PackedByteArray = keyframe.encode_full()
	var back: BoardSnapshot = BoardSnapshot.decode_full(full)
	assert_eq(back.values, keyframe.values, "the keyframe comes back bit for bit")
	assert_eq(back.texts, keyframe.texts)
	var later: BoardSnapshot = BoardSnapshot.capture(_sailed_sim(5.0))
	var diff: PackedByteArray = later.encode_diff(keyframe)
	var rebuilt: BoardSnapshot = BoardSnapshot.decode_diff(diff, keyframe)
	assert_eq(rebuilt.values, later.values, "the diff on the keyframe gives the state bit for bit")
	assert_eq(rebuilt.texts, later.texts)
	assert_lt(float(diff.size()), full.size() * 0.75, "the gear's constants do not travel again")
	gut.p("A board's keyframe %d bytes; a state later as a diff %d bytes (%.0f kB/s at 60 Hz)" % [full.size(), diff.size(), diff.size() * 60.0 / 1000.0])


func test_halfway_between_two_states() -> void:
	var a: BoardSnapshot = BoardSnapshot.capture(_sailed_sim(3.0))
	var b: BoardSnapshot = BoardSnapshot.capture(_sailed_sim(3.2))
	var half: BoardSnapshot = BoardSnapshot.interpolate(a, b, 0.5)
	var pa: Vector3 = a.get_field("body", "position")
	var pb: Vector3 = b.get_field("body", "position")
	var ph: Vector3 = half.get_field("body", "position")
	assert_almost_eq(ph.distance_to((pa + pb) * 0.5), 0.0, 1e-3, "the place in the middle")
	var basis_half: Basis = half.get_field("body", "basis")
	assert_almost_eq(basis_half.determinant(), 1.0, 1e-3, "the attitude stays a rotation")
	assert_eq(BoardSnapshot.interpolate(a, b, 0.0), a)
	assert_eq(BoardSnapshot.interpolate(a, b, 1.0), b)


func test_angles_go_the_short_way_round() -> void:
	assert_almost_eq(BoardSnapshot._short_way(359.0, 1.0, 0.5, 180.0), 0.0, 1e-4, "a heading through north")
	assert_almost_eq(BoardSnapshot._short_way(359.0, 1.0, 0.25, 180.0), 359.5, 1e-4, "and stays 0 to 360")
	assert_almost_eq(BoardSnapshot._short_way(179.0, -179.0, 0.25, 180.0), 179.5, 1e-4, "a wind angle through dead downwind")
	assert_almost_eq(BoardSnapshot._short_way(10.0, 20.0, 0.5, 180.0), 15.0, 1e-4, "an ordinary angle in between")
	assert_almost_eq(absf(BoardSnapshot._short_way(3.1, -3.1, 0.5, PI)), PI, 0.01, "radians the same (plus or minus pi is one angle)")
