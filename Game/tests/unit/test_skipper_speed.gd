extends GutTest
## The scripted skipper's speed (Documentation/reports/fleet_speed/skipper_speed.md): its polar
## (SkipperPolar, Game/config/skipper_polar.tres) reads between its winds and angles; the skipper beats
## and runs at the polar's best angles for the wind of the moment (wider in light wind), moved by its
## character's own difference from 45 and 135; it sets the push slider from the polar for the angle it
## sails where pushing paid, moved by its character's push_offset, and hands the slider back (NaN: the
## pilot's own margin) elsewhere, through a tack or gybe and before a mark; the controller then sails
## the pilot's own numbers again; and with push_wanted off it never sets the slider.

const RunRace: GDScript = preload("res://dev/run_race.gd")


func test_the_polar_reads_between_its_winds_and_angles() -> void:
	var winds: PackedFloat32Array = PackedFloat32Array([10.0, 20.0])
	var angles: PackedFloat32Array = PackedFloat32Array([40.0, 60.0, 90.0])
	var table: PackedFloat32Array = PackedFloat32Array([4.0, 6.0, 8.0, 6.0, 8.0, 12.0])
	assert_almost_eq(SkipperPolar.value_at(winds, angles, table, 10.0, 60.0), 6.0, 1e-5, "a measured point")
	assert_almost_eq(SkipperPolar.value_at(winds, angles, table, 10.0, 50.0), 5.0, 1e-5, "between two angles")
	assert_almost_eq(SkipperPolar.value_at(winds, angles, table, 15.0, 90.0), 10.0, 1e-5, "between two winds")
	assert_almost_eq(SkipperPolar.value_at(winds, angles, table, 15.0, -90.0), 10.0, 1e-5, "either tack")
	assert_almost_eq(SkipperPolar.value_at(winds, angles, table, 30.0, 120.0), 12.0, 1e-5, "held beyond the table")
	assert_almost_eq(SkipperPolar.per_wind(winds, PackedFloat32Array([55.0, 45.0]), 12.5), 52.5, 1e-5, "a per-wind number")
	assert_almost_eq(SkipperPolar.per_wind(winds, PackedFloat32Array([55.0, 45.0]), 5.0), 55.0, 1e-5, "held below the first wind")


func test_the_push_is_only_where_the_polar_says_it_paid() -> void:
	var winds: PackedFloat32Array = PackedFloat32Array([12.0, 18.0])
	var angles: PackedFloat32Array = PackedFloat32Array([50.0, 90.0, 110.0, 130.0])
	# 12 kt: nowhere; 18 kt: on the reaches (90 and 110 degrees).
	var table: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.9, 0.95, 0.0])
	assert_almost_eq(SkipperPolar.push_at(winds, angles, table, 18.0, 100.0), 0.925, 1e-5, "between two pushed angles")
	assert_almost_eq(SkipperPolar.push_at(winds, angles, table, 18.0, -90.0), 0.9, 1e-5, "either tack")
	assert_true(is_nan(SkipperPolar.push_at(winds, angles, table, 18.0, 50.0)), "not on the beat")
	assert_true(is_nan(SkipperPolar.push_at(winds, angles, table, 18.0, 120.0)), "not where one side did not pay")
	assert_true(is_nan(SkipperPolar.push_at(winds, angles, table, 15.0, 100.0)), "not where the lighter wind did not pay")
	assert_true(is_nan(SkipperPolar.push_at(winds, angles, table, 12.0, 100.0)), "not in 12 kt")
	assert_almost_eq(SkipperPolar.push_at(winds, angles, table, 30.0, 110.0), 0.95, 1e-5, "held above the last wind")


func test_the_games_polar_is_whole() -> void:
	var polar: SkipperPolar = SkipperPolar.default_polar()
	assert_not_null(polar)
	var cells: int = polar.winds_kt.size() * polar.twa_deg.size()
	assert_eq(polar.speed_ms.size(), cells, "a speed for every wind and angle")
	assert_eq(polar.push_level.size(), cells, "a push level for every wind and angle")
	assert_eq(polar.best_upwind_twa_deg.size(), polar.winds_kt.size(), "a beat's angle per wind")
	assert_eq(polar.best_downwind_twa_deg.size(), polar.winds_kt.size(), "a run's angle per wind")
	for level: float in polar.push_level:
		assert_between(level, 0.0, 1.0, "a push level is a slider position (0: not pushed)")


func test_the_beat_and_the_run_follow_the_wind() -> void:
	var light: Skipper = _allrounder_at(12.0)
	var strong: Skipper = _allrounder_at(24.0)
	var polar: SkipperPolar = SkipperPolar.default_polar()
	assert_almost_eq(light._best_upwind_twa_deg(), polar.best_upwind_twa_deg[0], 1e-3, "the polar's beat in 12 kt")
	assert_almost_eq(strong._best_upwind_twa_deg(), polar.best_upwind_twa_deg[2], 1e-3, "and in 24 kt")
	assert_almost_eq(light._best_downwind_twa_deg(), polar.best_downwind_twa_deg[0], 1e-3, "the polar's run in 12 kt")
	assert_almost_eq(strong._best_downwind_twa_deg(), polar.best_downwind_twa_deg[2], 1e-3, "and in 24 kt")
	# A character that points 3 degrees higher than POLAR_15KT.md's 45 does so in every wind.
	strong.config.upwind_vmg_twa_deg = 42.0
	strong.config.downwind_vmg_twa_deg = 140.0
	strong._off_plane = false
	assert_almost_eq(strong._run_twa_deg(), polar.best_downwind_twa_deg[2] + 5.0, 1e-3, "5 degrees deeper than the polar's best")
	var at_speed: float = strong._polar_speed_ms(strong._best_upwind_twa_deg())
	strong._sim.telemetry.speed_ms = at_speed
	assert_almost_eq(strong._pointing_twa_deg(), polar.best_upwind_twa_deg[2] - 3.0, 1e-3, "3 degrees higher than the polar's best, at speed")


func test_a_slow_board_foots_off_to_get_going() -> void:
	var skipper: Skipper = _allrounder_at(18.0)
	var best: float = skipper._best_upwind_twa_deg()
	skipper._sim.telemetry.speed_ms = skipper._polar_speed_ms(best)
	assert_almost_eq(skipper._pointing_twa_deg(), best, 1e-3, "at the polar's speed it sails the polar's angle")
	skipper._sim.telemetry.speed_ms = 2.0
	assert_gt(skipper._pointing_twa_deg(), best + 4.0, "just out of a tack it sails lower to get going")
	assert_lte(skipper._pointing_twa_deg(), best + Skipper.FOOT_MAX_DEG + 1e-3, "but no more than FOOT_MAX_DEG lower")


func test_the_skipper_pushes_on_the_reach_and_lets_go_to_turn() -> void:
	var skipper: Skipper = _allrounder_at(18.0)
	var polar: SkipperPolar = _pushing_polar()
	skipper.take_polar(polar)
	var telemetry: Telemetry = skipper._sim.telemetry
	telemetry.twa_deg = 100.0
	var wanted: float = SkipperPolar.push_at(polar.winds_kt, polar.twa_deg, polar.push_level, telemetry.tws_10m_kt, 100.0)
	assert_false(is_nan(wanted), "the polar pushes the 18 kt reach")
	assert_almost_eq(skipper._push_level(telemetry), wanted, 1e-4, "the polar's level on the reach")
	skipper.config.push_offset = 0.1
	assert_almost_eq(skipper._push_level(telemetry), minf(wanted + 0.1, 1.0), 1e-4, "its character pushes harder")
	skipper.config.push_offset = -2.0
	assert_eq(skipper._push_level(telemetry), 0.0, "never below the slider's bottom")
	skipper.config.push_offset = 0.0
	skipper._tack_due_s = 1.0
	assert_true(is_nan(skipper._push_level(telemetry)), "let go from the moment a gybe is asked for")
	skipper._tack_due_s = -1.0
	telemetry.twa_deg = 50.0
	assert_true(is_nan(skipper._push_level(telemetry)), "the beat at the pilot's own margin")
	telemetry.twa_deg = 100.0
	skipper.push_wanted = false
	assert_true(is_nan(skipper._push_level(telemetry)), "off: the pilot's own margin, as before")


func test_the_controller_gives_the_pilot_its_own_margin_back() -> void:
	var controller: PlayerController = PlayerController.new()
	var hands: AiHands = AiHands.new()
	controller.hands = hands
	var controls: SimControls = SimControls.new()
	controller.reset_controls(controls)
	var telemetry: Telemetry = Telemetry.new()
	var own: Autopilot = Autopilot.new()
	hands.push = 0.95
	controller._move_the_slider(telemetry, controls, 1.0 / 60.0)
	assert_almost_eq(controller.push_level, 0.95, 1e-6, "the hands set the slider")
	assert_gt(controller.auto_sheet_pilot.hike_share, own.hike_share, "pushed: more pull held")
	assert_gt(controls.rig_lean_extra_deg, 0.0, "and the rig leaned further")
	hands.push = NAN
	controller._move_the_slider(telemetry, controls, 1.0 / 60.0)
	assert_true(is_nan(controller.push_level), "let go: no slider")
	assert_eq(controller.auto_sheet_pilot.hike_share, own.hike_share, "the pilot's own pull")
	assert_eq(controller.auto_sheet_pilot.drive_share, own.drive_share, "its own drive")
	assert_eq(controller.auto_sheet_pilot.wave_rail_max_deg, own.wave_rail_max_deg, "no sea rail")
	assert_eq(controls.rig_lean_extra_deg, 0.0, "the rig's lean its own")
	assert_eq(controls.rail_bank_extra_deg, 0.0, "the rail its own")
	assert_eq(controls.trim_aim_extra_deg, 0.0, "the trim its own")


func test_the_games_polar_pushes_nowhere_but_a_character_can() -> void:
	var skipper: Skipper = _allrounder_at(18.0)
	var telemetry: Telemetry = skipper._sim.telemetry
	telemetry.twa_deg = 100.0
	assert_true(is_nan(skipper._push_level(telemetry)), "the game's polar: the pilot's own margin on the reach")
	skipper.config.push_offset = 0.1
	assert_almost_eq(skipper._push_level(telemetry), LearnedSkipper.pilot_margin_level() + 0.1, 1e-5, "a character that pushes harder: from the pilot's own level")
	skipper.config.push_offset = -0.1
	assert_almost_eq(skipper._push_level(telemetry), LearnedSkipper.pilot_margin_level() - 0.1, 1e-5, "or more carefully")
	# Upwind the slider is the pilot's, whatever the character: pushed on the 24 kt beat the personas
	# fell (characters.md).
	for twa_deg: float in [45.0, -52.0]:
		telemetry.twa_deg = twa_deg
		skipper.config.push_offset = 0.1
		assert_true(is_nan(skipper._push_level(telemetry)), "no push on the beat at %.0f degrees" % twa_deg)
		skipper.config.push_offset = -0.1
		assert_true(is_nan(skipper._push_level(telemetry)), "no easing on the beat either")
	telemetry.twa_deg = -130.0
	skipper.config.push_offset = 0.1
	skipper._last_wanted_deg = telemetry.heading_deg + 5.0
	assert_false(is_nan(skipper._push_level(telemetry)), "it pushes on the run")
	skipper._last_wanted_deg = telemetry.heading_deg + 40.0
	assert_true(is_nan(skipper._push_level(telemetry)), "but not while it bears away onto it")


## The game's polar with a push table that pushes the 18 and 24 kt reaches (70 to 110 degrees) at 95 %,
## as the measurement's steady runs suggested.
func _pushing_polar() -> SkipperPolar:
	var polar: SkipperPolar = SkipperPolar.default_polar().duplicate()
	var count: int = polar.twa_deg.size()
	var table: PackedFloat32Array = PackedFloat32Array()
	table.resize(polar.winds_kt.size() * count)
	table.fill(0.0)
	for row: int in range(1, polar.winds_kt.size()):
		for col: int in count:
			if polar.twa_deg[col] >= 70.0 and polar.twa_deg[col] <= 110.0:
				table[row * count + col] = 0.95
	polar.push_level = table
	return polar


## The all-rounder on a board at rest in a wind, set up in a race on T1 (its telemetry read as the
## board sails; the tests write the speed and the angle into it).
func _allrounder_at(wind_kt: float) -> Skipper:
	var course: Course = RaceCourses.t1_loop(270.0, Vector2.ZERO)
	var race: RaceSim = RaceSim.new(course, 1, 10.0)
	var entries: Array = RunRace.make_entries(race, course, PackedStringArray(["allrounder"]), wind_kt, 50.0, 1)
	var skipper: Skipper = entries[0].skipper as Skipper
	skipper._sim.telemetry.tws_10m_kt = wind_kt
	return skipper


func test_a_board_past_the_rounding_ray_goes_back_round_before_it_rounds() -> void:
	# The slalom template's mark 1 (PD3 at 60 %, the wind from the west): the leg in runs north, the leg
	# out east, the mark left to starboard. Half-way round a board is north-west of the mark.
	var mark: Vector2 = Vector2(50.4, -360.0)
	var in_dir: Vector2 = Vector2(0.138648, -0.990342)
	var ray: Vector2 = RoundingCheck.rounding_ray(in_dir, Vector2(1.0, 0.0), CourseMark.Rounding.STARBOARD)
	var way: float = RoundingCheck.turn_way(CourseMark.Rounding.STARBOARD)
	assert_true(Skipper.before_rounding_ray(mark + Vector2(-8.0, 0.0), mark, ray, way), "abeam on the west side: before the ray")
	assert_true(Skipper.before_rounding_ray(mark + Vector2(-8.0, 20.0), mark, ray, way), "coming up from the south: before it")
	assert_false(Skipper.before_rounding_ray(mark + Vector2(-5.0, -15.0), mark, ray, way), "back down the west side from the north: past it")
	assert_false(Skipper.before_rounding_ray(mark + Vector2(5.0, -22.0), mark, ray, way), "past the mark on its east side: past it")


func test_a_board_heading_the_wrong_way_round_a_mark_goes_back_down_the_leg() -> void:
	# The same mark: Aiko came back to it from the north on its west side, heading south (181), and
	# was counted level with it at (40.9, -369.9), before the ray by a hair; she then went round it
	# anticlockwise, the wrong way, 45 gybes long.
	var mark: Vector2 = Vector2(50.4, -360.0)
	var in_dir: Vector2 = Vector2(0.138648, -0.990342)
	var ray: Vector2 = RoundingCheck.rounding_ray(in_dir, Vector2(1.0, 0.0), CourseMark.Rounding.STARBOARD)
	var way: float = RoundingCheck.turn_way(CourseMark.Rounding.STARBOARD)
	assert_true(Skipper.before_rounding_ray(Vector2(40.9, -369.9), mark, ray, way), "she was before the ray, by a hair")
	assert_true(Skipper.going_round_the_wrong_way(181.0, ray, way), "heading south past it: the wrong way")
	assert_true(Skipper.going_round_the_wrong_way(240.0, ray, way), "south-west: the wrong way")
	assert_false(Skipper.going_round_the_wrong_way(0.0, ray, way), "coming up the leg: the right way")
	assert_false(Skipper.going_round_the_wrong_way(330.0, ray, way), "coming up a little west of north: the right way")
	assert_false(Skipper.going_round_the_wrong_way(300.0, ray, way), "west-north-west to the entry point from the east: not the wrong way")
	assert_false(Skipper.going_round_the_wrong_way(90.0, ray, way), "east across the mark's foot: not the wrong way")
	# A windward mark left to port, the run after it (the wind from the north): a board that overstood
	# and comes down on it from the east, heading south-west, is going the right way.
	var up: Vector2 = Vector2(0.0, -1.0)
	var windward_ray: Vector2 = RoundingCheck.rounding_ray(up, -up, CourseMark.Rounding.PORT)
	var port: float = RoundingCheck.turn_way(CourseMark.Rounding.PORT)
	assert_false(Skipper.going_round_the_wrong_way(225.0, windward_ray, port), "overstood, coming down from the east")
	assert_false(Skipper.going_round_the_wrong_way(315.0, windward_ray, port), "on starboard tack up to it")


func test_the_hand_moves_the_slider_gradually_and_hands_it_back() -> void:
	var skipper: Skipper = _allrounder_at(18.0)
	skipper.take_polar(_pushing_polar())
	var telemetry: Telemetry = skipper._sim.telemetry
	var margin: float = LearnedSkipper.pilot_margin_level()
	var dt: float = 1.0 / 60.0
	telemetry.twa_deg = 50.0
	assert_true(is_nan(skipper._move_the_push(telemetry, dt)), "on the beat it leaves the slider alone")
	telemetry.twa_deg = 100.0
	var first: float = skipper._move_the_push(telemetry, dt)
	assert_almost_eq(first, margin + Skipper.PUSH_RATE_PER_S * dt, 1e-5, "it takes the slider from the pilot's own pull")
	for t: int in 120:
		skipper._move_the_push(telemetry, dt)
	assert_almost_eq(skipper._move_the_push(telemetry, dt), skipper._push_level(telemetry), 1e-5, "and gets to the polar's level")
	telemetry.twa_deg = 50.0
	var easing: float = skipper._move_the_push(telemetry, dt)
	assert_false(is_nan(easing), "letting go, it first brings the slider down")
	assert_gt(easing, margin, "down, not at once to the pilot's margin")
	for t: int in 120:
		skipper._move_the_push(telemetry, dt)
	assert_true(is_nan(skipper._move_the_push(telemetry, dt)), "then hands it back")


func test_a_board_that_missed_the_finish_line_goes_back_behind_it() -> void:
	var skipper: Skipper = _allrounder_at(24.0)
	var finish: RaceStep = skipper._race.steps()[skipper._race.steps().size() - 1]
	assert_eq(finish.kind, RaceStep.Kind.FINISH)
	var middle: Vector2 = finish.target()
	var along: Vector2 = (finish.points[1] - finish.points[0]).normalized()
	var length_m: float = finish.points[0].distance_to(finish.points[1])
	# Behind the line, off to one side: through the nearest point of the line.
	var behind: Vector2 = middle - finish.in_dir * 40.0 + along * length_m
	var aim: Vector2 = skipper._finish_target(finish, behind)
	assert_gt(RoundingCheck.over_line_m(aim, finish.points[0], finish.points[1], finish.in_dir), 0.0, "it aims through the line")
	# Past an end of the line on the course side, not finished: back behind the middle first.
	var missed: Vector2 = middle + finish.in_dir * 20.0 + along * length_m
	assert_almost_eq(skipper._finish_target(finish, missed), middle - finish.in_dir * Skipper.FINISH_BACK_M, Vector2(1e-3, 1e-3), "back behind the middle")
	var half_way: Vector2 = middle - finish.in_dir * 10.0
	assert_almost_eq(skipper._finish_target(finish, half_way), middle - finish.in_dir * Skipper.FINISH_BACK_M, Vector2(1e-3, 1e-3), "until it is far enough behind")
	var far_enough: Vector2 = middle - finish.in_dir * (Skipper.FINISH_BACK_REACHED_M + 5.0) + along * length_m
	aim = skipper._finish_target(finish, far_enough)
	assert_gt(RoundingCheck.over_line_m(aim, finish.points[0], finish.points[1], finish.in_dir), 0.0, "then through the line again")
	var on_line: Vector2 = far_enough + (aim - far_enough) * (Skipper.FINISH_BACK_REACHED_M + 5.0) / (aim - far_enough).dot(finish.in_dir)
	assert_almost_eq(on_line.distance_to(middle), 0.0, 2.0, "through its middle, not near an end")


func test_a_fast_board_off_the_finish_line_eases_down_to_turn_onto_it() -> void:
	var skipper: Skipper = _allrounder_at(24.0)
	var finish: RaceStep = skipper._race.steps()[skipper._race.steps().size() - 1]
	var middle: Vector2 = finish.target()
	var along: Vector2 = (finish.points[1] - finish.points[0]).normalized()
	# 100 m behind the line, its track 30 degrees off the leg at 13 m/s: that track crosses the line's
	# extension 58 m from its middle, well past an end of the 35 m line, 8 s from now.
	var behind: Vector2 = middle - finish.in_dir * 100.0
	skipper._velocity = finish.in_dir.rotated(deg_to_rad(30.0)) * 13.0
	skipper._hands.hold_speed_ms = 0.0
	skipper._finish_target(finish, behind)
	assert_almost_eq(skipper._hands.hold_speed_ms, Skipper.FINISH_EASE_SPEED_MS, 1e-6, "eases down to turn onto the line")
	# The track straight at the line: full speed.
	skipper._velocity = finish.in_dir * 13.0
	skipper._hands.hold_speed_ms = 0.0
	skipper._finish_target(finish, behind)
	assert_almost_eq(skipper._hands.hold_speed_ms, 0.0, 1e-6, "full speed when the track crosses the line")
	# Off the line but far from it (more than FINISH_EASE_WITHIN_S away): not yet.
	skipper._velocity = finish.in_dir.rotated(deg_to_rad(30.0)) * 13.0
	skipper._finish_target(finish, middle - finish.in_dir * 300.0)
	assert_almost_eq(skipper._hands.hold_speed_ms, 0.0, 1e-6, "not from far away")
	# Having missed the line once (past an end on the course side), it sails slowly until it has crossed.
	skipper._finish_target(finish, middle + finish.in_dir * 20.0 + along * 40.0)
	assert_almost_eq(skipper._hands.hold_speed_ms, Skipper.FINISH_AGAIN_SPEED_MS, 1e-6, "slow to come back")
	skipper._hands.hold_speed_ms = 0.0
	skipper._finish_target(finish, middle - finish.in_dir * (Skipper.FINISH_BACK_REACHED_M + 5.0))
	assert_almost_eq(skipper._hands.hold_speed_ms, Skipper.FINISH_AGAIN_SPEED_MS, 1e-6, "and across the line again")


## The start plan at the polar's beat (fleet_speed/start.md, RA16): before its start the skipper
## points at the polar's angle for the wind, as it does racing; its run in to the line is 15 degrees
## wider than that (60 at least, 72 at most), so that its track lays its spot; its waiting point is at
## least 30 m behind the line or its extensions; and the race tool waits where the game puts the boards.
func test_the_start_plan_is_drawn_at_the_polars_beat() -> void:
	var skipper: Skipper = _allrounder_at(18.0)
	skipper.state = Skipper.State.PRE_START
	skipper._sim.telemetry.speed_ms = 10.0
	var best_deg: float = SkipperPolar.per_wind(skipper._polar_winds, skipper._polar_upwind, 18.0)
	assert_almost_eq(skipper._pointing_twa_deg(), best_deg, 0.01, "before the start too it points at the polar's angle, not 45")
	assert_almost_eq(skipper._run_in_twa_deg(), best_deg + Skipper.START_RUN_IN_ABOVE_BEAT_DEG, 0.01, "the run in 15 degrees wider")
	var gambler: Skipper = _allrounder_at(18.0)
	gambler.config.pointing_offset_deg = 4.0
	assert_almost_eq(gambler._run_in_twa_deg(), Skipper.START_RUN_IN_WIDEST_TWA_DEG, 0.01, "no wider than 72")
	var start: RaceStep = skipper._race.steps()[0]
	var near: Vector2 = start.target() - start.in_dir * 5.0
	var moved: Vector2 = skipper._well_behind_the_line(start, near)
	var behind_m: float = -RoundingCheck.over_line_m(moved, start.points[0], start.points[1], start.in_dir)
	assert_almost_eq(behind_m, Skipper.START_WAIT_BEHIND_M, 0.5, "a waiting point 5 m behind the line goes back to 30 m")
	var far: Vector2 = start.target() - start.in_dir * 50.0
	assert_almost_eq(skipper._well_behind_the_line(start, far), far, Vector2(1e-3, 1e-3), "one far enough back stays")
	assert_almost_eq(RunRace.wait_behind_m(60.0), 60.0, 0.01, "the race tool waits 60 m back for a 60 s countdown, as the game")
	assert_almost_eq(RunRace.wait_behind_m(30.0), RaceRunner.NEAREST_M, 0.01, "and never nearer than 40 m")
