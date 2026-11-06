extends GutTest
## The race types (Course.RaceType; Max, 6 November 2026: "on the course builder a option for slalom
## race, course race and iq hybrid race and then also free sailing. also easier for ai to train" and
## "Start upwind of the startboat on a slalom race"): the type of every template, saved with the
## course and sent with it, chosen in the course maker; a slalom's boards waiting upwind of the
## committee boat and reaching down onto the line; free sailing with no countdown.

const MAP_CONFIG_PATH: String = "res://maps/silvaplana/map_config.tres"


func _rules() -> CourseRules:
	return load(RaceCourses.RULES_PATH) as CourseRules


# ---------------------------------------------------------------- the type of every template

func test_every_template_has_its_race_type() -> void:
	var expected: Dictionary[String, Course.RaceType] = {
		"PD3": Course.RaceType.SLALOM, "SD3": Course.RaceType.SLALOM,
		"LG2": Course.RaceType.COURSE, "LR2": Course.RaceType.COURSE, "O2": Course.RaceType.COURSE, "I2": Course.RaceType.COURSE,
		"US3": Course.RaceType.HYBRID, "US4": Course.RaceType.HYBRID, "PM1": Course.RaceType.HYBRID, "SM1": Course.RaceType.HYBRID}
	assert_eq(expected.size(), CourseTemplates.ALL.size(), "every template is listed here")
	for id: String in CourseTemplates.ALL:
		assert_eq(CourseTemplates.race_type_of(id), expected[id], id)
		var course: Course = CourseTemplates.build(id, _rules(), 15.0, 24, 0.0, Vector2.ZERO)
		assert_eq(course.race_type, expected[id], id + " built with its type")
	assert_eq(RaceCourses.t1_loop(270.0, Vector2.ZERO).race_type, Course.RaceType.COURSE, "T1 is course racing")
	assert_eq(RaceCourses.t2_stand_in(270.0, Vector2.ZERO).race_type, Course.RaceType.SLALOM, "T2 is a slalom")


func test_the_saved_courses_have_their_types() -> void:
	var config: MapConfig = load(MAP_CONFIG_PATH) as MapConfig
	var expected: Dictionary[String, Course.RaceType] = {
		"iq_pd3": Course.RaceType.SLALOM, "iq_sd3": Course.RaceType.SLALOM, "t2_slalom": Course.RaceType.SLALOM,
		"iq_lg2": Course.RaceType.COURSE, "iq_o2": Course.RaceType.COURSE,
		"iq_us3": Course.RaceType.HYBRID, "iq_pm1": Course.RaceType.HYBRID}
	for saved: String in expected:
		var course: Course = RaceCourses.load_named(saved, config)
		assert_not_null(course, saved)
		if course != null:
			assert_eq(course.race_type, expected[saved], saved)


func test_the_type_is_saved_copied_and_read_back() -> void:
	var course: Course = CourseTemplates.build("LG2", _rules(), 15.0, 24, 0.0, Vector2.ZERO)
	course.race_type = Course.RaceType.FREE
	assert_eq(course.copy().race_type, Course.RaceType.FREE, "a copy keeps it (undo, the director's course)")
	# The LAN race director sends the course as this dictionary (NetBoards.send_course()).
	var data: Dictionary = course.to_dict(null)
	assert_eq(data["race_type"], "free")
	var back: Course = Course.from_dict(JSON.parse_string(JSON.stringify(data)), null)
	assert_eq(back.race_type, Course.RaceType.FREE, "it travels through JSON")
	# A file from before the race types: the type its template has.
	data.erase("race_type")
	data["template"] = "SD3"
	assert_eq(Course.from_dict(data, null).race_type, Course.RaceType.SLALOM)
	data["template"] = "my own"
	assert_eq(Course.from_dict(data, null).race_type, Course.RaceType.COURSE, "no template: course racing")
	for type: Course.RaceType in Course.RACE_TYPES:
		assert_eq(Course.race_type_from_name(Course.race_type_name(type)), type, Course.race_type_title(type))


func test_the_course_maker_chooses_the_type() -> void:
	var panel: CoursePanel = CoursePanel.new()
	add_child_autofree(panel)
	var course: Course = CourseTemplates.build("PD3", _rules(), 15.0, 24, 0.0, Vector2.ZERO)
	panel.show_course(course, "", PackedStringArray(["a", "b", "c", "d"]), [], PackedStringArray())
	assert_eq(panel.race_type_text(), "Slalom race", "the selector shows the course's type")
	var chosen: Array[Course.RaceType] = []
	panel.race_type_chosen.connect(func(type: Course.RaceType) -> void: chosen.append(type))
	panel.choose_race_type(Course.RaceType.FREE)
	assert_eq(chosen, [Course.RaceType.FREE] as Array[Course.RaceType], "the choice goes to the course maker")
	assert_eq(panel.race_type_text(), "Free sailing")


# ---------------------------------------------------------------- the slalom's start

func test_a_slalom_waits_upwind_of_the_committee_boat_spread_across_the_wind() -> void:
	var course: Course = CourseTemplates.build("PD3", _rules(), 15.0, 24, 0.0, Vector2.ZERO)
	var race: RaceSim = RaceSim.new(course, 1, 60.0)
	var start: RaceStep = race.steps()[0]
	var spots: PackedVector2Array = RaceRunner.pre_start_spots(course, start, 12, 60.0)
	assert_eq(spots.size(), 12)
	var boat: Vector2 = course.mark(CourseMark.START_BOAT).position
	var up: Vector2 = Course.direction_of(course.axis_deg)
	var across: Vector2 = Course.direction_of(course.axis_deg + 90.0)
	var across_m: PackedFloat32Array = PackedFloat32Array()
	for spot: Vector2 in spots:
		assert_almost_eq((spot - boat).dot(up), RaceCourses.SLALOM_WAIT_UPWIND_M, 0.5, "upwind of the committee boat")
		var behind_m: float = -RoundingCheck.over_line_m(spot, start.points[0], start.points[1], start.in_dir)
		assert_gte(behind_m, RaceCourses.SLALOM_WAIT_CLEAR_M - 0.5, "behind the line's extension, not over it")
		across_m.append((spot - boat).dot(across))
	var sorted: PackedFloat32Array = across_m.duplicate()
	sorted.sort()
	assert_gt(sorted[-1] - sorted[0], 60.0, "spread across the wind")
	assert_almost_eq(across_m[0], (sorted[5] + sorted[6]) / 2.0, 10.0, "the player in the middle")
	# From each spot the broad reach down meets the line between its ends.
	var dive: Vector2 = RaceCourses.slalom_dive_direction(course)
	assert_almost_eq(absf(Navigation.wind_angle_deg(Vector2.ZERO, dive, course.axis_deg)), RaceCourses.SLALOM_DIVE_TWA_DEG, 0.5, "a broad reach")
	assert_gt(dive.dot(start.in_dir), 0.5, "toward the course")
	var line_m: float = start.points[0].distance_to(start.points[1])
	for spot: Vector2 in spots:
		var crossing: Vector2 = RaceCourses.slalom_crossing(course, spot)
		assert_almost_eq(RoundingCheck.over_line_m(crossing, start.points[0], start.points[1], start.in_dir), 0.0, 0.01, "on the line")
		assert_lte(crossing.distance_to(boat), line_m, "between its ends")
		assert_almost_eq((crossing - spot).normalized().dot(dive), 1.0, 0.001, "straight down the broad reach")
	# The boat's end of the row crosses nearest the boat.
	assert_lt(RaceCourses.slalom_crossing(course, RaceCourses.slalom_slot(course, 1.0)).distance_to(boat),
		RaceCourses.slalom_crossing(course, RaceCourses.slalom_slot(course, 0.0)).distance_to(boat))


func test_a_course_race_still_waits_behind_the_line() -> void:
	for id: String in ["LG2", "US3"]:
		var course: Course = CourseTemplates.build(id, _rules(), 15.0, 24, 0.0, Vector2.ZERO)
		var start: RaceStep = RaceSim.new(course, 1, 60.0).steps()[0]
		for spot: Vector2 in RaceRunner.pre_start_spots(course, start, 6, 60.0):
			assert_almost_eq(-RoundingCheck.over_line_m(spot, start.points[0], start.points[1], start.in_dir), 60.0, 1.0, id + ": 60 m behind the line")
	# The same course set to slalom waits upwind of its boat: the type decides, not the shape.
	var slalom: Course = CourseTemplates.build("LG2", _rules(), 15.0, 24, 0.0, Vector2.ZERO)
	slalom.race_type = Course.RaceType.SLALOM
	var boat: Vector2 = slalom.mark(CourseMark.START_BOAT).position
	var first: RaceStep = RaceSim.new(slalom, 1, 60.0).steps()[0]
	for spot: Vector2 in RaceRunner.pre_start_spots(slalom, first, 6, 60.0):
		assert_almost_eq((spot - boat).dot(Course.direction_of(slalom.axis_deg)), RaceCourses.SLALOM_WAIT_UPWIND_M, 0.5)


## The scripted skipper on a slalom makes for the crossing of its own broad reach, not a spot pulled
## to the boat end by the line's "bias" (a line along the wind reads as 90 degrees of bias).
func test_a_slalom_skipper_aims_down_its_broad_reach() -> void:
	var course: Course = CourseTemplates.build("PD3", _rules(), 15.0, 24, 0.0, Vector2.ZERO)
	var race: RaceSim = RaceSim.new(course, 1, 60.0)
	race.add_board("Kofi")
	var skipper: Skipper = Skippers.make("persona:kofi") as Skipper
	assert_not_null(skipper)
	if skipper == null:
		return
	skipper.sailing_area = SailingArea.around_start(course)
	var sim: WindsurferSim = WindsurferSim.create_default(false)
	var controller: PlayerController = PlayerController.new()
	var hands: AiHands = AiHands.new()
	controller.hands = hands
	skipper.setup(sim, controller, hands, race, 0)
	var start: RaceStep = race.steps()[0]
	var slot: Vector2 = RaceCourses.slalom_slot(course, skipper.config.start_spot)
	assert_eq(skipper.call("_start_spot", start), RaceCourses.slalom_crossing(course, slot), "its own crossing")


# ---------------------------------------------------------------- free sailing

## A course set to free sailing: the boards are placed, no countdown starts, the race card is hidden;
## set back to a race type, the next start has its countdown again.
func test_free_sailing_has_no_countdown_and_no_race_card() -> void:
	var saved_values: SettingsValues = GameSettings.values
	var saved_path: String = GameSettings.path
	GameSettings.values = SettingsValues.new()
	GameSettings.path = ""
	RaceSetup.pending = RaceSetup.race("t1_loop", PackedStringArray(["allrounder"]))
	var scene: SailingScene = (load("res://main.tscn") as PackedScene).instantiate()
	add_child_autofree(scene)
	var runner: RaceRunner = scene.get_node("RaceRunner")
	assert_true(runner.race.is_started(), "a course race counts down at once")
	var free: Course = scene.live_course().copy()
	free.race_type = Course.RaceType.FREE
	scene.apply_course(free)
	runner.restart(true)
	await wait_physics_frames(3)
	assert_true(runner.is_free_sailing())
	assert_false(runner.race.is_started(), "no countdown")
	assert_false(runner.hud.visible, "no race card")
	assert_eq(runner.race.phase(), RaceSim.Phase.PRE_START, "and so no result")
	assert_not_null(scene.get_node_or_null("CourseOnWater"), "the marks stay on the water")
	var raced: Course = free.copy()
	raced.race_type = Course.RaceType.COURSE
	scene.apply_course(raced)
	runner.restart(true)
	assert_true(runner.race.is_started(), "a race type again: the countdown")
	assert_true(runner.hud.visible, "with the race card")
	GameSettings.values = saved_values
	GameSettings.path = saved_path
	get_tree().paused = false


## The race director follows the type: free sailing stops the race (a start with no countdown);
## a race type again plans the next countdown after the director's gap.
func test_the_director_follows_the_race_type() -> void:
	var runner: FreeAwareRunner = FreeAwareRunner.new()
	autofree(runner)
	runner.course = RaceCourses.t1_loop(0.0, Vector2.ZERO)
	runner.setup = RaceSetup.race("t1_loop", PackedStringArray(), 1, 60.0)
	var director: RaceDirector = RaceDirector.new()
	autofree(director)
	director.setup(runner, null)
	var free: Course = runner.course.copy()
	free.race_type = Course.RaceType.FREE
	runner.course = free
	director.call("_follow_the_race_type", false, free)
	assert_eq(runner.starts, 1, "the race stopped: a start without a countdown")
	assert_lt(director.next_countdown_in_s, 0.0, "no countdown planned")
	director.start_countdown_now()
	assert_eq(runner.starts, 1, "no countdown while sailing free")
	var slalom: Course = free.copy()
	slalom.race_type = Course.RaceType.SLALOM
	runner.course = slalom
	director.call("_follow_the_race_type", true, slalom)
	assert_almost_eq(director.next_countdown_in_s, director.gap_s, 0.01, "the next countdown after the gap")
	assert_string_contains(director.note, "Slalom race")


## A race runner that only counts its starts.
class FreeAwareRunner:
	extends RaceRunner
	var starts: int = 0

	func restart(_keep_places: bool = false) -> void:
		starts += 1
		race = RaceSim.new(course, setup.laps, setup.prestart_s)
		restarted.emit()
