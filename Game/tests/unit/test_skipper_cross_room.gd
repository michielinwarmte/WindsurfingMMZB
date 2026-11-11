extends GutTest
## start_cross_room_deg (Skipper._choose_crossing(); the training method's phase S3, 11 November 2026): of the points of
## the start line it can reach on its tack, it makes for one at least that many degrees further off the wind than its
## beat's track when there is one, else as before. Of the night's 1710 clean starts from a hold, 446 found the line on
## the other tack a median 9 s after they went (from a crawl the board sails wider than its beat until it has speed),
## tacked, and crossed a median 10 s late.

const RunRace: GDScript = preload("res://dev/run_race.gd")


## A skipper before its start at the origin, at a crawl on its +1 tack (the wind from the north, heading west).
func _skipper_at_a_crawl() -> Skipper:
	var course: Course = RaceCourses.t1_loop(0.0, Vector2.ZERO)
	var race: RaceSim = RaceSim.new(course, 1, 60.0)
	var entries: Array = RunRace.make_entries(race, course, PackedStringArray(["allrounder"]), 15.0, 50.0, 1)
	var skipper: Skipper = entries[0].skipper as Skipper
	skipper.state = Skipper.State.PRE_START
	skipper._settling = false
	var telemetry: Telemetry = skipper._sim.telemetry
	telemetry.position = Vector3.ZERO
	telemetry.speed_ms = 2.0
	telemetry.heading_deg = 270.0
	telemetry.twa_deg = 90.0
	telemetry.wind_from_bearing_deg = 0.0
	telemetry.tws_10m_kt = 15.0
	return skipper


## A start line 60 m out from the origin with its ends at these wind angles on the +1 tack (the wind from the north:
## the bearing is 360 less the angle).
func _line_between(twa_a_deg: float, twa_b_deg: float) -> RaceStep:
	var step: RaceStep = RaceStep.new()
	step.kind = RaceStep.Kind.START
	step.points = PackedVector2Array([Course.direction_of(360.0 - twa_a_deg) * 60.0, Course.direction_of(360.0 - twa_b_deg) * 60.0])
	step.in_dir = Course.direction_of(270.0)
	return step


func _twa_of(point: Vector2) -> float:
	return absf(wrapf(0.0 - Course.bearing_deg(Vector2.ZERO, point), -180.0, 180.0))


func test_it_is_off_unless_switched_on() -> void:
	assert_eq(SkipperConfig.new().start_cross_room_deg, 0.0, "off by default until the suite says it wins")


func test_with_room_it_makes_for_a_point_that_far_off_the_wind() -> void:
	var skipper: Skipper = _skipper_at_a_crawl()
	var up_track_deg: float = skipper._beat_twa_deg() + skipper._leeway_deg
	var step: RaceStep = _line_between(up_track_deg + 2.0, up_track_deg + 40.0)
	skipper.config.start_cross_room_deg = 15.0
	for aim_s: float in [0.0, 1000.0]:
		var point: Vector2 = skipper._choose_crossing(skipper._sim.telemetry, step, aim_s)
		assert_true(skipper._crossing_on_this_tack, "on this tack")
		assert_gte(_twa_of(point), up_track_deg + 15.0 - 0.5, "at least the room further off the wind (aim %.0f s)" % aim_s)


func test_with_no_point_that_far_off_the_wind_it_chooses_as_before() -> void:
	var skipper: Skipper = _skipper_at_a_crawl()
	var up_track_deg: float = skipper._beat_twa_deg() + skipper._leeway_deg
	var step: RaceStep = _line_between(up_track_deg + 2.0, up_track_deg + 10.0)
	for aim_s: float in [0.0, 1000.0]:
		skipper.config.start_cross_room_deg = 0.0
		var before: Vector2 = skipper._choose_crossing(skipper._sim.telemetry, step, aim_s)
		skipper.config.start_cross_room_deg = 15.0
		var now: Vector2 = skipper._choose_crossing(skipper._sim.telemetry, step, aim_s)
		assert_true(skipper._crossing_on_this_tack, "still on this tack: no new tack")
		assert_almost_eq(now.distance_to(before), 0.0, 0.01, "the same point as before (aim %.0f s)" % aim_s)
