extends GutTest
## The lake technique of 7 November 2026 (Documentation/reports/autopilot/lake_speed/): getting going
## (the sheet's cap and pace, the pull held, the rig raked back), the nose dive below the plane, heading
## up to get going on a broad reach, bearing away in a gust, the feet's trim in chop. Everything is off
## by default, so the AI fleet sails as before.

const DT: float = 1.0 / 60.0


func _telemetry(twa_deg: float, speed_ms: float = 1.0) -> Telemetry:
	var t: Telemetry = Telemetry.new()
	t.twa_deg = twa_deg
	t.awa_deg = twa_deg
	t.speed_ms = speed_ms
	t.sail_side = -1 if twa_deg >= 0.0 else 1
	t.tws_at_sail_kt = 15.0
	return t


func _run(controller: PlayerController, telemetry: Telemetry, controls: SimControls, seconds: float) -> void:
	for i: int in int(seconds / DT):
		controller.update(telemetry, controls, DT)


func test_everything_is_off_by_default() -> void:
	var c: PlayerController = PlayerController.new()
	assert_eq(c.start_alpha_deg, 90.0)
	assert_eq(c.start_sheet_in_share, 0.0)
	assert_eq(c.start_hike_share, 0.0)
	assert_eq(c.start_rake_back, 0.0)
	assert_eq(c.plane_head_up_deg, 0.0)
	assert_eq(c.nose_dive_bow_m, 0.0)
	assert_eq(c.nose_dive_rake_back, 0.0)
	assert_eq(c.gust_bear_away_deg, 0.0)
	assert_eq(c.chop_trim_aim_deg, 0.0)


func test_the_sheet_is_capped_while_getting_going_and_not_on_the_plane() -> void:
	var c: PlayerController = PlayerController.new()
	c.start_alpha_deg = 10.0
	var controls: SimControls = SimControls.new()
	_run(c, _telemetry(100.0, 0.5), controls, 0.2)
	assert_almost_eq(c.auto_sheet_pilot.max_alpha_deg, 10.0, 0.01, "standing still: the cap")
	_run(c, _telemetry(100.0, 12.0), controls, 0.2)
	assert_eq(c.auto_sheet_pilot.max_alpha_deg, 90.0, "planing: no cap")


func test_the_pull_held_while_getting_going() -> void:
	var c: PlayerController = PlayerController.new()
	c.start_hike_share = 0.8
	var controls: SimControls = SimControls.new()
	_run(c, _telemetry(100.0, 0.5), controls, 0.2)
	assert_almost_eq(c.auto_sheet_pilot.hike_share, 0.8, 0.01)


func test_a_buried_nose_eases_the_sail_and_rakes_the_rig_back_without_adding_up() -> void:
	var plain: PlayerController = PlayerController.new()
	var plain_controls: SimControls = SimControls.new()
	var c: PlayerController = PlayerController.new()
	c.nose_dive_bow_m = 0.1
	c.nose_dive_alpha_deg = 5.0
	c.nose_dive_rake_back = 0.3
	var controls: SimControls = SimControls.new()
	var t: Telemetry = _telemetry(100.0, 3.0)
	t.bow_immersion_m = 0.25
	_run(plain, t, plain_controls, 2.0)
	_run(c, t, controls, 2.0)
	assert_almost_eq(c.auto_sheet_pilot.max_alpha_deg, 5.0, 0.01, "eased")
	assert_almost_eq(controls.rake - plain_controls.rake, 0.3, 0.05, "raked back by the set amount, not more each tick")
	# Above nose_dive_below_ms it is not a low-speed dive.
	var fast: PlayerController = PlayerController.new()
	fast.nose_dive_bow_m = 0.1
	var t_fast: Telemetry = _telemetry(100.0, 10.0)
	t_fast.bow_immersion_m = 0.25
	_run(fast, t_fast, SimControls.new(), 0.5)
	assert_eq(fast.auto_sheet_pilot.max_alpha_deg, 90.0)


func test_after_the_player_steers_the_head_up_leaves_the_course_alone() -> void:
	# 7 November 2026: after a key turn away at low speed the head-up turned the board back up (a 30 degree
	# turn kept 3 to 7, the course wandering 9 to 10 degrees). It helps after a start only, until the player
	# steers.
	var c: PlayerController = PlayerController.new()
	c.plane_head_up_deg = 20.0
	var controls: SimControls = SimControls.new()
	Input.action_press("steer_left")
	_run(c, _telemetry(140.0, 2.0), controls, 0.2)
	Input.action_release("steer_left")
	_run(c, _telemetry(140.0, 2.0), controls, 1.0)
	assert_almost_eq(c.wanted_rate_dps, 0.0, 0.5, "the course the player chose is held")
	c.reset_controls(controls)
	_run(c, _telemetry(140.0, 2.0), controls, 0.5)
	assert_gt(c.wanted_rate_dps * c.tack_sign(_telemetry(140.0)), 1.0, "after a new start it helps again")


func test_a_slow_broad_reach_heads_up_to_get_going() -> void:
	var c: PlayerController = PlayerController.new()
	c.plane_head_up_deg = 20.0
	var controls: SimControls = SimControls.new()
	_run(c, _telemetry(140.0, 2.0), controls, 0.5)
	assert_gt(c.wanted_rate_dps * c.tack_sign(_telemetry(140.0)), 1.0, "toward the wind")
	var off: PlayerController = PlayerController.new()
	_run(off, _telemetry(140.0, 2.0), SimControls.new(), 0.5)
	assert_almost_eq(off.wanted_rate_dps, 0.0, 0.5, "off: the course held")


func test_a_gust_bears_away_on_the_plane() -> void:
	var c: PlayerController = PlayerController.new()
	c.gust_bear_away_deg = 10.0
	var controls: SimControls = SimControls.new()
	var t: Telemetry = _telemetry(100.0, 12.0)
	t.is_planing = true
	_run(c, t, controls, 2.0)
	assert_almost_eq(c.wanted_rate_dps, 0.0, 0.5, "no gust: the course held")
	t.tws_at_sail_kt = 19.0
	_run(c, t, controls, 0.3)
	assert_lt(c.wanted_rate_dps * c.tack_sign(t), -1.0, "in the gust: away from the wind")


func test_the_chop_trim_does_not_add_up_without_the_slider() -> void:
	var c: PlayerController = PlayerController.new()
	c.chop_trim_aim_deg = 3.0
	c.chop_bounce_from_dps = 0.0
	c.chop_bounce_full_dps = 1.0
	c.auto_sheet_pilot.wave_rail_max_deg = 1.0
	var controls: SimControls = SimControls.new()
	var t: Telemetry = _telemetry(100.0, 12.0)
	for i: int in 180:
		t.pitch_rate_dps = 20.0 if i % 20 < 10 else -20.0
		c.update(t, controls, DT)
		assert_true(controls.trim_aim_extra_deg <= 3.0 + 1e-6, "never more than the set trim")
	assert_gt(controls.trim_aim_extra_deg, 0.5, "the chop felt adds trim")
