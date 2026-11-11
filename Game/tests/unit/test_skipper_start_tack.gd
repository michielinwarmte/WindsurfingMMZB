extends GutTest
## start_tack (SkipperConfig.start_tack, Skipper._start_run_in_tack(); Max, 11 November 2026: "i want the skippers decide
## starboard start and port start, so some will start the one way and others the other way"): the tack a skipper comes in
## to a course race's start line on. EITHER is the tack from its side of its spot (as before); STARBOARD and PORT are its
## own choice wherever it is.

const RunRace: GDScript = preload("res://dev/run_race.gd")


func test_either_is_the_default() -> void:
	assert_eq(SkipperConfig.new().start_tack, SkipperConfig.StartTack.EITHER, "by where it is, until the suite says otherwise")


func test_either_takes_the_tack_from_its_side_of_the_spot() -> void:
	var left: Skipper = _skipper_behind_an_upwind_line(-80.0, SkipperConfig.StartTack.EITHER)
	var right: Skipper = _skipper_behind_an_upwind_line(80.0, SkipperConfig.StartTack.EITHER)
	var step: RaceStep = left._race.steps()[0]
	assert_ne(left._start_run_in_tack(step, 0.0), right._start_run_in_tack(step, 0.0), "the two sides come in on different tacks")


func test_starboard_and_port_are_its_own_choice_from_either_side() -> void:
	for side_m: float in [-80.0, 80.0]:
		var starboard: Skipper = _skipper_behind_an_upwind_line(side_m, SkipperConfig.StartTack.STARBOARD)
		var port: Skipper = _skipper_behind_an_upwind_line(side_m, SkipperConfig.StartTack.PORT)
		var step: RaceStep = starboard._race.steps()[0]
		assert_eq(starboard._start_run_in_tack(step, 0.0), 1.0, "starboard (+1) from %+.0f m" % side_m)
		assert_eq(port._start_run_in_tack(step, 0.0), -1.0, "port (-1) from %+.0f m" % side_m)


func test_the_race_tool_deals_each_board_its_own_tack() -> void:
	# run_race --start_tacks=1,2,0: board 0 starboard, board 1 port, board 2 either.
	var course: Course = RaceCourses.t1_loop(0.0, Vector2.ZERO)
	var race: RaceSim = RaceSim.new(course, 1, 60.0)
	var entries: Array = RunRace.make_entries(race, course, PackedStringArray(["allrounder", "allrounder", "allrounder"]), 15.0, 50.0, 1)
	var tacks: PackedStringArray = "1,2,0".split(",")
	for i: int in entries.size():
		var board: Skipper = entries[i].skipper as Skipper
		board.config = board.config.duplicate()
		board.config.start_tack = clampi(tacks[i].to_int(), 0, 2) as SkipperConfig.StartTack
	assert_eq((entries[0].skipper as Skipper).config.start_tack, SkipperConfig.StartTack.STARBOARD)
	assert_eq((entries[1].skipper as Skipper).config.start_tack, SkipperConfig.StartTack.PORT)
	assert_eq((entries[2].skipper as Skipper).config.start_tack, SkipperConfig.StartTack.EITHER)


## A skipper 60 m behind the middle of T1's start line (the wind from the north, an upwind start), side_m to the east (+)
## or west (-), with its own copy of the settings and this start tack.
func _skipper_behind_an_upwind_line(side_m: float, tack: SkipperConfig.StartTack) -> Skipper:
	var course: Course = RaceCourses.t1_loop(0.0, Vector2.ZERO)
	var race: RaceSim = RaceSim.new(course, 1, 60.0)
	var entries: Array = RunRace.make_entries(race, course, PackedStringArray(["allrounder"]), 15.0, 50.0, 1)
	var skipper: Skipper = entries[0].skipper as Skipper
	skipper.config = skipper.config.duplicate()
	skipper.config.start_tack = tack
	skipper._run_in_tack = 0.0
	var step: RaceStep = race.steps()[0]
	var middle: Vector2 = step.points[0].lerp(step.points[1], 0.5)
	var at: Vector2 = middle - step.in_dir * 60.0 + Vector2(side_m, 0.0)
	skipper._sim.telemetry.position = Vector3(at.x, 0.0, at.y)
	skipper._sim.telemetry.wind_from_bearing_deg = 0.0
	return skipper
