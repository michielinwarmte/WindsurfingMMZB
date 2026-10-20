extends GutTest
## The living skipper (AI_FLEET_PLAN.md, D4 and F2): the parts of a skipper's life on the water
## around the race, each on its own:
##   - the navigation skill (Navigation.route()): a point on a reach is sailed straight, a point
##     upwind or dead downwind in two legs with one tack or gybe at the layline;
##   - the line's bias and the end a skipper chooses from it and its character;
##   - the sailing area round the start line: its size, on the lake inside the water and off the
##     shore, the time from its farthest corner to the line, and the random spots the boards appear at;
##   - the state machine's transitions (free sailing, pre-start, racing, finished);
##   - a fleet of repeated characters gets numbered labels;
##   - the hold-back skill of the hands: a short run on flat water, the board slows to the wanted
##     speed without stalling and gets going again.
## Directions are compass bearings; the wind comes from the north (0) unless a test says otherwise.

const DT: float = 1.0 / 60.0
const SHORE_GRID_PATH: String = "res://maps/silvaplana/terrain/shore_heights.json"
const MAP_CONFIG_PATH: String = "res://maps/silvaplana/map_config.tres"
## The beat's and the run's tracks over the ground (the angle sailed plus the leeway), degrees.
const UP_TRACK_DEG: float = 50.0
const DOWN_TRACK_DEG: float = 140.0
## What the skipper's polar says the board makes at 12 kt (the lightest wind of the tests) on a beat
## (50 degrees), a beam reach and a run (125 degrees), m/s (Skipper.POLAR_SPEED_MS).
const SLOW_BEAT_MS: float = 5.19
const SLOW_REACH_MS: float = 8.66
const SLOW_RUN_MS: float = 6.58


# ---------------------------------------------------------------- the navigation skill

func test_a_point_on_a_reach_is_sailed_straight() -> void:
	# East with the wind from the north is a beam reach on port tack (the wind over the left side).
	var target: Vector2 = Vector2(300.0, 0.0)
	var on_port: Navigation.Route = Navigation.route(Vector2.ZERO, target, 0.0, -1.0, UP_TRACK_DEG, DOWN_TRACK_DEG)
	assert_eq(on_port.manoeuvres, 0, "Straight there on port tack")
	assert_false(on_port.upwind or on_port.downwind, "A reach")
	assert_eq(on_port.corner, target, "No corner: the target itself")
	assert_almost_eq(on_port.distance_m(), 300.0, 0.01)
	var on_starboard: Navigation.Route = Navigation.route(Vector2.ZERO, target, 0.0, 1.0, UP_TRACK_DEG, DOWN_TRACK_DEG)
	assert_eq(on_starboard.manoeuvres, 1, "On starboard tack it tacks or gybes first")
	assert_true(on_starboard.turn_first, "The turn is made at once")
	assert_almost_eq(on_starboard.distance_m(), 300.0, 0.01, "Then straight there")


func test_a_point_upwind_takes_one_tack_at_the_layline() -> void:
	# 300 m straight upwind: two legs of the same length, one on each tack.
	var target: Vector2 = Course.direction_of(0.0) * 300.0
	var way: Navigation.Route = Navigation.route(Vector2.ZERO, target, 0.0, 1.0, UP_TRACK_DEG, DOWN_TRACK_DEG)
	assert_true(way.upwind, "A beat")
	assert_eq(way.manoeuvres, 1, "One tack")
	assert_false(way.turn_first, "On this tack first")
	var leg_m: float = 300.0 / (2.0 * cos(deg_to_rad(UP_TRACK_DEG)))
	assert_almost_eq(way.first_m, leg_m, 0.5, "Half the way on starboard tack")
	assert_almost_eq(way.second_m, leg_m, 0.5, "and half on port")
	# On starboard tack the board heads to the left of the wind: the corner is west of the target.
	assert_lt(way.corner.x, -100.0, "The tack is made out to the west, on the port layline")
	assert_almost_eq(Course.bearing_deg(way.corner, target), UP_TRACK_DEG, 0.5, "From the corner the target is on port tack's track")


func test_a_point_on_the_layline_needs_no_tack() -> void:
	# The target straight along starboard tack's track: laid.
	var laid: Vector2 = Course.direction_of(-UP_TRACK_DEG) * 200.0 + Course.direction_of(UP_TRACK_DEG) * 5.0
	var way: Navigation.Route = Navigation.route(Vector2.ZERO, laid, 0.0, 1.0, UP_TRACK_DEG, DOWN_TRACK_DEG)
	assert_true(way.upwind, "Still a beat")
	assert_eq(way.manoeuvres, 0, "Laid: a last leg of 5 m needs no tack")
	# Along port tack's track from a board on starboard: one tack, at once.
	var other: Vector2 = Course.direction_of(UP_TRACK_DEG) * 200.0
	var turn: Navigation.Route = Navigation.route(Vector2.ZERO, other, 0.0, 1.0, UP_TRACK_DEG, DOWN_TRACK_DEG)
	assert_eq(turn.manoeuvres, 1, "One tack")
	assert_true(turn.turn_first, "Made at once")


func test_a_point_dead_downwind_takes_one_gybe() -> void:
	var target: Vector2 = Course.direction_of(180.0) * 300.0
	var way: Navigation.Route = Navigation.route(Vector2.ZERO, target, 0.0, 1.0, UP_TRACK_DEG, DOWN_TRACK_DEG)
	assert_true(way.downwind, "A run")
	assert_eq(way.manoeuvres, 1, "One gybe")
	var leg_m: float = 300.0 / (2.0 * cos(deg_to_rad(180.0 - DOWN_TRACK_DEG)))
	assert_almost_eq(way.first_m, leg_m, 0.5)
	assert_almost_eq(way.second_m, leg_m, 0.5)
	# A broad reach (120 degrees off the wind) is sailed straight.
	var broad: Navigation.Route = Navigation.route(Vector2.ZERO, Course.direction_of(240.0) * 300.0, 0.0, 1.0, UP_TRACK_DEG, DOWN_TRACK_DEG)
	assert_eq(broad.manoeuvres, 0, "A broad reach on starboard: straight")


# ---------------------------------------------------------------- the line's bias and the end

func test_the_line_bias_and_the_favoured_end() -> void:
	# A 60 m line, the boat at the east end; the wind from the north is square to it.
	var square: RaceStep = _line(Vector2(30.0, 0.0), Vector2(-30.0, 0.0))
	assert_almost_eq(Skipper.line_bias_deg(square, 0.0), 0.0, 0.01, "Square to the wind: no bias")
	assert_eq(Skipper.favoured_end(0.0), 0.5, "Neither end")
	assert_eq(Skipper.chosen_start_share(0.3, 1.0, 0.0), 0.3, "On a square line its own spot")
	# The boat end 10 m further upwind (north is -Z) than the pin.
	var boat_up: RaceStep = _line(Vector2(30.0, -5.0), Vector2(-30.0, 5.0))
	var bias_deg: float = Skipper.line_bias_deg(boat_up, 0.0)
	assert_almost_eq(bias_deg, rad_to_deg(asin(10.0 / boat_up.points[0].distance_to(boat_up.points[1]))), 0.01, "The boat end 10 m nearer the wind")
	assert_gt(bias_deg, 9.0)
	assert_eq(Skipper.favoured_end(bias_deg), 1.0, "The boat end is favoured")
	assert_almost_eq(Skipper.line_bias_deg(boat_up, 180.0), -bias_deg, 0.01, "With the wind from the south the pin is")
	# The choice: a keen skipper goes most of the way to the favoured end, a skipper who does not
	# care stays at its spot, one in between goes part of the way.
	var keen: float = Skipper.chosen_start_share(0.3, 1.0, bias_deg)
	var careless: float = Skipper.chosen_start_share(0.3, 0.0, bias_deg)
	var halfway: float = Skipper.chosen_start_share(0.3, 0.5, bias_deg)
	assert_gt(keen, 0.9, "Keen: nearly at the boat end")
	assert_eq(careless, 0.3, "Not keen: its own spot")
	assert_between(halfway, 0.55, 0.7, "Half keen: half way")
	assert_eq(Skipper.chosen_start_share(0.3, 1.0, 30.0), 1.0, "A big bias sends the keen skipper all the way")
	assert_almost_eq(Skipper.chosen_start_share(0.7, 1.0, -30.0), 0.0, 1e-6, "A pin-end bias, all the way to the pin")


func test_the_lakes_reaching_start_favours_the_upwind_end() -> void:
	# T2's line runs along the wind, the boat end upwind: a bias of nearly 90 degrees.
	var t2: Course = RaceCourses.load_named(RaceCourses.T2_NAME, load(MAP_CONFIG_PATH))
	var start: RaceStep = RaceSim.new(t2).steps()[0]
	var bias_deg: float = Skipper.line_bias_deg(start, t2.axis_deg)
	assert_gt(absf(bias_deg), 60.0, "Along the wind: %.0f degrees" % bias_deg)
	assert_eq(Skipper.favoured_end(bias_deg), 1.0 if bias_deg > 0.0 else 0.0)


# ---------------------------------------------------------------- the sailing area

func test_the_sailing_area_round_t1s_start_line() -> void:
	var course: Course = RaceCourses.t1_loop(270.0, Vector2.ZERO)
	var area: SailingArea = SailingArea.around_start(course)
	var line_m: float = course.mark(CourseMark.START_BOAT).position.distance_to(course.mark(CourseMark.START_PIN).position)
	assert_almost_eq(area.half_across_m * 2.0, line_m + 2.0 * SailingArea.ACROSS_M, 0.01, "Across the wind: the line and 150 m beyond each end")
	assert_almost_eq(area.half_up_m * 2.0, SailingArea.DOWNWIND_M + SailingArea.UPWIND_M, 0.01, "100 m below the line and 50 m above it")
	for id: String in [CourseMark.START_BOAT, CourseMark.START_PIN]:
		assert_true(area.contains(course.mark(id).position), "The start line is in it")
	var upwind: Vector2 = Course.direction_of(270.0)
	assert_true(area.contains(course.start_middle() - upwind * 95.0), "95 m below the line")
	assert_false(area.contains(course.start_middle() - upwind * 105.0), "not 105 m")
	assert_true(area.contains(course.start_middle() + upwind * 45.0), "45 m above it")
	assert_false(area.contains(course.mark("1").position), "Mark 1, 556 m upwind, is far outside")
	assert_almost_eq(area.inside_m(course.start_middle()), 50.0, 0.01, "The line's middle is 50 m from the upwind side")


func test_from_the_farthest_corner_a_board_gets_to_the_line_in_time() -> void:
	# The menu's countdown is 60 s and starts as the boards appear. From each corner of T1's area, at
	# 12 kt (the slowest wind), from rest: the navigation skill's way to the waiting point 20 m behind
	# the middle of the line, at the polar's speeds, with 6.5 s for each tack or gybe and the time
	# to get going. The waiting point is where the start's own run in begins.
	var course: Course = RaceCourses.t1_loop(0.0, Vector2.ZERO)
	var area: SailingArea = SailingArea.around_start(course)
	var waiting: Vector2 = course.start_middle() - Course.direction_of(0.0) * 20.0
	var longest_s: float = 0.0
	for corner: Vector2 in area.corners():
		var best_s: float = INF
		for tack: float in [1.0, -1.0]:
			best_s = minf(best_s, _time_at_12_kt_s(corner, waiting, tack))
		longest_s = maxf(longest_s, best_s)
	gut.p("The farthest corner of T1's sailing area is %.0f s from the waiting point at 12 kt" % longest_s)
	assert_lt(longest_s, 50.0, "Every corner within 50 s of the line: 10 s for the run in")


func test_the_lakes_sailing_area_stays_on_the_water() -> void:
	var t2: Course = RaceCourses.load_named(RaceCourses.T2_NAME, load(MAP_CONFIG_PATH))
	var grid: TerrainGrid = TerrainGrid.load_from(SHORE_GRID_PATH)
	var area: SailingArea = SailingArea.for_course(t2, grid)
	var fitter: CourseFitter = CourseFitter.from_heights(grid.height_at, t2.start_middle())
	for id: String in [CourseMark.START_BOAT, CourseMark.START_PIN]:
		assert_true(area.contains(t2.mark(id).position), "The start line is in it")
	# Every 10 m over the area: water, with room to the shore (the clearance field is up to 11 m
	# careful, so a little less than SHORE_ROOM_M is allowed between its points).
	var nearest_m: float = INF
	var on_land: int = 0
	var across_m: float = -area.half_across_m
	while across_m <= area.half_across_m:
		var up_m: float = -area.half_up_m
		while up_m <= area.half_up_m:
			var point: Vector2 = area.point_at(across_m, up_m)
			nearest_m = minf(nearest_m, fitter.clearance_m(point))
			if grid.height_at(point.x, point.y) > -0.5:
				on_land += 1
			up_m += 10.0
		across_m += 10.0
	gut.p("T2's sailing area: %.0f x %.0f m, at least %.0f m from the shore" % [area.half_across_m * 2.0, area.half_up_m * 2.0, nearest_m])
	assert_eq(on_land, 0, "No point of it on land or in the shallows")
	assert_gt(nearest_m, SailingArea.SHORE_ROOM_M - 15.0, "Room to the shore everywhere")
	assert_gt(area.half_across_m * 2.0, 200.0, "Still a few hundred metres across the wind")
	assert_gt(area.half_up_m * 2.0, 100.0, "and more than a hundred along it")
	# Without the shore it would reach onto the shallows behind the line (the camping side).
	var open: SailingArea = SailingArea.around_start(t2)
	assert_gt(open.half_across_m, area.half_across_m - 0.01, "The shore made it smaller (or kept it)")


func test_the_boards_appear_at_random_spots_apart_and_seeded() -> void:
	var course: Course = RaceCourses.t1_loop(270.0, Vector2.ZERO)
	var area: SailingArea = SailingArea.around_start(course)
	var player: Vector2 = course.start_middle() - Course.direction_of(270.0) * 60.0
	var places: Array[Vector3] = area.spawn_places(16, 7, player)
	assert_eq(places.size(), 16, "One place per board")
	for i: int in places.size():
		var spot: Vector2 = Vector2(places[i].x, places[i].y)
		assert_true(area.inside_m(spot) >= 19.9, "Inside the area, 20 m from its sides")
		assert_true(spot.distance_to(player) >= SailingArea.SPAWN_APART_M, "Clear of the player's spot")
		for j: int in i:
			assert_true(spot.distance_to(Vector2(places[j].x, places[j].y)) >= SailingArea.SPAWN_APART_M - 0.01, "Boards %d and %d apart" % [i, j])
		var twa_deg: float = absf(wrapf(270.0 - places[i].z, -180.0, 180.0))
		assert_between(twa_deg, 69.9, 110.1, "On a reach, to get going at once")
	var again: Array[Vector3] = area.spawn_places(16, 7, player)
	assert_eq(again, places, "The same seed, the same spots")
	assert_ne(area.spawn_places(16, 8, player), places, "Another seed, other spots")


# ---------------------------------------------------------------- the state machine

func test_the_state_follows_the_race() -> void:
	# A start line on z = 0 (the wind from the north), mark 1 50 m upwind of it (to port), and a
	# finish line running north and south 100 m west of the mark.
	var course: Course = Course.new()
	course.axis_deg = 0.0
	course.add_mark(CourseMark.START_BOAT, Vector2(30.0, 0.0))
	course.add_mark(CourseMark.START_PIN, Vector2(-30.0, 0.0))
	course.add_mark("1", Vector2(0.0, -50.0), CourseMark.Rounding.PORT)
	course.add_mark(CourseMark.FINISH_BOAT, Vector2(-100.0, -40.0))
	course.add_mark(CourseMark.FINISH_PIN, Vector2(-100.0, -60.0))
	assert_eq(course.set_sequence("Start-1-Finish"), "")
	var race: RaceSim = RaceSim.new(course, 1, 10.0)
	race.add_board("a")
	race.update_board(0, Vector2(0.0, 20.0))
	race.start_in(5.0)
	assert_eq(Skipper.state_for(race, 0, false), Skipper.State.FREE_SAILING, "Before the countdown: free sailing")
	_run(race, Vector2(0.0, 20.0), 4.0)
	assert_eq(Skipper.state_for(race, 0, false), Skipper.State.FREE_SAILING, "Still sailing free a second before it")
	_run(race, Vector2(0.0, 20.0), 2.0)
	assert_true(race.is_started(), "The countdown started by itself")
	assert_eq(Skipper.state_for(race, 0, false), Skipper.State.PRE_START, "The countdown gathers the fleet")
	_run(race, Vector2(0.0, 20.0), 10.0)
	assert_eq(race.phase(), RaceSim.Phase.RACING, "The gun has gone")
	assert_eq(Skipper.state_for(race, 0, false), Skipper.State.PRE_START, "Not started yet: still the start")
	_run(race, Vector2(10.0, -10.0), 1.0)
	assert_eq(Skipper.state_for(race, 0, false), Skipper.State.RACING, "Across the line: racing")
	# Up the east side of mark 1, round its top leaving it to port, and west across the finish.
	for point: Vector2 in [Vector2(10.0, -30.0), Vector2(10.0, -50.0), Vector2(7.0, -57.0), Vector2(0.0, -60.0),
			Vector2(-7.0, -57.0), Vector2(-30.0, -52.0), Vector2(-80.0, -50.0), Vector2(-110.0, -50.0)]:
		_run(race, point, 0.25)
	assert_eq(race.next_step_index(0), 3, "Round the mark and across the finish")
	assert_true(race.is_finished(0))
	assert_eq(Skipper.state_for(race, 0, false), Skipper.State.FINISHED, "Across the finish: finished")
	assert_eq(Skipper.state_for(race, 0, true), Skipper.State.FREE_SAILING, "Clear of the line: free sailing again")
	# A race that ended without the board: free sailing.
	var other: RaceSim = RaceSim.new(course, 1, 0.0, 30.0)
	other.add_board("b")
	other.update_board(0, Vector2(0.0, 20.0))
	other.start()
	_run(other, Vector2(0.0, 20.0), 31.0)
	assert_eq(other.phase(), RaceSim.Phase.FINISHED, "The time limit ended it")
	assert_eq(Skipper.state_for(other, 0, false), Skipper.State.FREE_SAILING, "Not finished, race over: free sailing")


func test_a_fleet_of_repeated_characters_gets_numbered_labels() -> void:
	var fleet: Array[RaceSkipper] = Skippers.make_fleet(PackedStringArray(["rookie", "allrounder", "rookie", "rookie"]))
	assert_eq(fleet.size(), 4)
	var labels: PackedStringArray = PackedStringArray()
	for skipper: RaceSkipper in fleet:
		labels.append(skipper.board_name())
	assert_eq(labels, PackedStringArray(["Rookie 1", "All-rounder", "Rookie 2", "Rookie 3"]))
	assert_ne((fleet[0] as Skipper).config, (fleet[2] as Skipper).config, "Each has a sheet of its own")


# ---------------------------------------------------------------- the hold-back skill

func test_the_hold_back_slows_the_board_without_stalling() -> void:
	# Flat water, 15 kt from the west: a beam reach on starboard tack from rest to get going, then
	# luffed up to 60 degrees with the hold-back at 2.5 m/s, then let go.
	var sim: WindsurferSim = WindsurferSim.create_for(EnvironmentConfig.new(), false, true)
	sim.wind_config.speed_kt = 15.0
	sim.wind_config.from_bearing_deg = 270.0
	sim.wind = WindField.new(sim.wind_config)
	var controller: PlayerController = PlayerController.new()
	controller.set_sail(sim.sail, sim.sailor_config, sim.air_density_kg_m3)
	var hands: AiHands = AiHands.new()
	controller.hands = hands
	var controls: SimControls = SimControls.new()
	sim.reset(Vector3.ZERO, deg_to_rad(180.0))
	controller.reset_controls(controls)
	_sail_at(sim, controller, hands, controls, 90.0, 12.0)
	assert_gt(sim.telemetry.speed_ms, 7.0, "Going on the reach first")
	hands.hold_speed_ms = 2.5
	_sail_at(sim, controller, hands, controls, Skipper.HOLD_TWA_DEG, 10.0)
	assert_true(controller.is_holding_back(), "Holding back")
	var slowest_ms: float = INF
	var speeds: PackedFloat32Array = PackedFloat32Array()
	var shown: PackedStringArray = PackedStringArray()
	for i: int in 8:
		_sail_at(sim, controller, hands, controls, Skipper.HOLD_TWA_DEG, 1.0)
		slowest_ms = minf(slowest_ms, sim.telemetry.speed_ms)
		speeds.append(sim.telemetry.speed_ms)
		shown.append("%.2f" % sim.telemetry.speed_ms)
	gut.p("Holding back to 2.5 m/s at 60 degrees: %s m/s" % ", ".join(shown))
	assert_eq(sim.sailor_state, WindsurferSim.SailorState.SAILING, "Still on the board")
	assert_gt(slowest_ms, controller.hold_back_steerage_ms, "Never so slow that it cannot steer (no stall)")
	for speed_ms: float in speeds:
		assert_almost_eq(speed_ms, 2.5, 0.7, "About the wanted speed")
	assert_almost_eq(absf(sim.telemetry.twa_deg), Skipper.HOLD_TWA_DEG, 8.0, "Still pointing where it is steered")
	# Let go: bear away to the bear-away angle and sheet in; it is planing again within a few seconds.
	hands.hold_speed_ms = 0.0
	_sail_at(sim, controller, hands, controls, 70.0, 8.0)
	assert_false(controller.is_holding_back())
	assert_gt(sim.telemetry.speed_ms, 5.5, "Going again 8 s after letting go")


# ---------------------------------------------------------------- helpers

func _line(boat: Vector2, pin: Vector2) -> RaceStep:
	var step: RaceStep = RaceStep.new()
	step.kind = RaceStep.Kind.START
	step.points = PackedVector2Array([boat, pin])
	step.in_dir = Vector2(0.0, -1.0)
	step.out_dir = step.in_dir
	return step


func _run(race: RaceSim, position: Vector2, seconds: float) -> void:
	for _i: int in roundi(seconds / 0.25):
		race.update_board(0, position)
		race.step(0.25)


## The time a board from rest needs at 12 kt from one point to another on a tack, seconds: the
## navigation skill's way at the polar's speeds (the beat, the run, or a reach in between), 6.5 s per
## tack or gybe, and 5 s to get going.
func _time_at_12_kt_s(from: Vector2, to: Vector2, tack: float) -> float:
	var way: Navigation.Route = Navigation.route(from, to, 0.0, tack, 55.0, 130.0)
	var speed_ms: float = SLOW_REACH_MS
	if way.upwind:
		speed_ms = SLOW_BEAT_MS
	elif way.downwind:
		speed_ms = SLOW_RUN_MS
	else:
		var twa_deg: float = absf(Navigation.wind_angle_deg(from, to, 0.0))
		speed_ms = SLOW_BEAT_MS if twa_deg < 70.0 else (SLOW_RUN_MS if twa_deg > 115.0 else SLOW_REACH_MS)
	return way.distance_m() / speed_ms + Skipper.START_TURN_S * way.manoeuvres + 5.0


## Sails for some seconds at a wind angle on starboard tack (the wind from the west), steering with
## the hands' stick as a skipper does.
func _sail_at(sim: WindsurferSim, controller: PlayerController, hands: AiHands, controls: SimControls, twa_deg: float, seconds: float) -> void:
	for _i: int in roundi(seconds / DT):
		var error_deg: float = wrapf(270.0 - twa_deg - sim.telemetry.heading_deg, -180.0, 180.0)
		hands.steer = clampf(error_deg / 30.0, -1.0, 1.0) if absf(error_deg) > 2.0 else 0.0
		if sim.sailor_state == WindsurferSim.SailorState.SAILING:
			controller.update(sim.telemetry, controls, DT)
		sim.step(DT, controls)
