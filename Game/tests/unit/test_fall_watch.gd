extends GutTest
## GP0's playtest: the HUD's frozen table of what came before the last fall (FallWatch), and the
## player controller's pilot overrides (the push dial's margin until GP1 builds the dial).

const DT: float = 1.0 / 60.0


func _telemetry(time_s: float, twa_deg: float, excess_nm: float, fin_share: float, yaw_dps: float) -> Telemetry:
	var t: Telemetry = Telemetry.new()
	t.time_s = time_s
	t.twa_deg = twa_deg
	t.feet_moment_excess_nm = excess_nm
	t.fin_load_share = fin_share
	t.yaw_rate_dps = yaw_dps
	t.sailor_state = WindsurferSim.SailorState.SAILING
	return t


func test_a_fall_freezes_what_came_one_second_before() -> void:
	var watch: FallWatch = FallWatch.new()
	# Starboard tack: 2 s quiet, then the last second overloaded toward the sail (to port, a
	# positive excess) and the bow heading up (a negative yaw rate).
	for i: int in 180:
		var time_s: float = i * DT
		var late: bool = time_s > 1.95
		watch.add(_telemetry(time_s, 120.0, 130.0 if late else 0.0, 0.2, -30.0 if late else 0.0))
	assert_eq(watch.last_fall_text, "", "nothing before the first fall")
	var fallen: Telemetry = _telemetry(3.0, 120.0, 0.0, 0.0, 0.0)
	fallen.sailor_state = WindsurferSim.SailorState.FALLEN
	fallen.fall_kind = "catapult"
	watch.add(fallen)
	var lines: PackedStringArray = watch.last_fall_text.split("\n")
	assert_eq(lines.size(), 4, "a heading and three rows")
	assert_string_contains(lines[0], "CATAPULT")
	assert_string_contains(lines[1], "1.0 s before")
	assert_string_contains(lines[1], "  130 N m", "overloaded a second before")
	assert_string_contains(lines[1], "   20 % of stall")
	assert_string_contains(lines[1], "   30 deg/s", "heading up")
	# Lying in the water keeps the table; the next fall replaces it.
	watch.add(fallen)
	assert_string_contains(watch.last_fall_text, "CATAPULT")


func test_port_tack_reads_the_same() -> void:
	var s: FallWatch.Sample = FallWatch.sample_of(_telemetry(1.0, -120.0, -130.0, 0.2, 30.0))
	assert_almost_eq(s.overload_nm, 130.0, 1e-6, "toward the sail, now to starboard")
	assert_almost_eq(s.heading_up_dps, 30.0, 1e-6, "heading up is a left turn on port tack")


func test_the_pilot_overrides_hold_through_a_waterstart() -> void:
	var controller: PlayerController = PlayerController.new()
	controller.hands = AiHands.new()
	controller.pilot_overrides = {"hike_share": 1.6, "catch_alpha_max_deg": 0.0}
	var controls: SimControls = SimControls.new()
	var t: Telemetry = _telemetry(0.0, 90.0, 0.0, 0.0, 0.0)
	controller.update(t, controls, DT)
	assert_almost_eq(controller.auto_sheet_pilot.hike_share, 1.6, 1e-6)
	assert_almost_eq(controller.auto_sheet_pilot.catch_alpha_max_deg, 0.0, 1e-6)
	controller.reset_controls(controls)  # a new pilot, as after a waterstart
	controller.update(t, controls, DT)
	assert_almost_eq(controller.auto_sheet_pilot.hike_share, 1.6, 1e-6, "set again on the new pilot")
	var plain: PlayerController = PlayerController.new()
	assert_almost_eq(plain.auto_sheet_pilot.hike_share, Autopilot.new().hike_share, 1e-6, "no overrides: 0.1's sailor")
