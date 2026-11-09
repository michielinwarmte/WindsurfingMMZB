extends GutTest
## crawl_no_head_up_ms (Skipper._steer_toward(); the training method's phase S, 9 November 2026): before its start, a
## board crawling (not holding back) does not steer toward the wind until it has speed. At 1.5 to 2 m/s on a reach
## with the stick held hard toward the wind the board did not turn and its sail drew at 1.5 to 4 deg: 24 of
## baseline_S's 54 late starts crawled at the gun.

const RunRace: GDScript = preload("res://dev/run_race.gd")


## A skipper before its start, crawling on its +1 tack (the wind from the north, heading west: TWA +90) at
## speed_ms, not holding back.
func _crawling_skipper(speed_ms: float) -> Skipper:
	var course: Course = RaceCourses.t1_loop(0.0, Vector2.ZERO)
	var race: RaceSim = RaceSim.new(course, 1, 60.0)
	var entries: Array = RunRace.make_entries(race, course, PackedStringArray(["allrounder"]), 15.0, 50.0, 1)
	var skipper: Skipper = entries[0].skipper as Skipper
	skipper.state = Skipper.State.PRE_START
	skipper._settling = false
	skipper._hands.hold_speed_ms = 0.0
	var telemetry: Telemetry = skipper._sim.telemetry
	telemetry.speed_ms = speed_ms
	telemetry.heading_deg = 270.0
	telemetry.twa_deg = 90.0
	telemetry.sail_side = 0
	return skipper


func test_it_is_on_by_default() -> void:
	assert_eq(SkipperConfig.new().crawl_no_head_up_ms, 2.5, "taken in loop S2d (9 November 2026)")
	assert_eq(SkipperConfig.new().crawl_stuck_s, 4.0)


func test_off_it_steers_hard_toward_the_wind_at_a_crawl() -> void:
	var skipper: Skipper = _crawling_skipper(2.0)
	skipper.config.crawl_no_head_up_ms = 0.0
	skipper._time_s = 100.0
	skipper._steer_toward(skipper._sim.telemetry, 320.0)
	skipper._time_s = 110.0
	# Heading up on the +1 tack is a turn to the right (Skipper: heading = wind - tack * TWA): wanted 320 deg.
	skipper._steer_toward(skipper._sim.telemetry, 320.0)
	assert_gt(skipper._hands.steer, 0.9, "the old way: the full stick toward the wind")


func test_on_it_lets_go_only_once_stuck_in_the_crawl() -> void:
	var skipper: Skipper = _crawling_skipper(2.0)
	skipper.config.crawl_no_head_up_ms = 2.5
	skipper.config.crawl_stuck_s = 4.0
	skipper._time_s = 100.0
	skipper._steer_toward(skipper._sim.telemetry, 320.0)
	assert_gt(skipper._hands.steer, 0.9, "a head-up at a crawl is tried first (it may work: off the shore, say)")
	skipper._time_s = 103.0
	skipper._steer_toward(skipper._sim.telemetry, 320.0)
	assert_gt(skipper._hands.steer, 0.9, "3 s of it: still trying")
	skipper._time_s = 104.5
	skipper._steer_toward(skipper._sim.telemetry, 320.0)
	assert_eq(skipper._hands.steer, 0.0, "stuck in the crawl for 4 s: it lets go of the stick toward the wind")


func test_on_it_does_not_head_up_until_it_has_speed() -> void:
	var skipper: Skipper = _crawling_skipper(2.0)
	skipper.config.crawl_no_head_up_ms = 2.5
	skipper.config.crawl_stuck_s = 0.0
	skipper._steer_toward(skipper._sim.telemetry, 320.0)
	skipper._steer_toward(skipper._sim.telemetry, 320.0)
	assert_eq(skipper._hands.steer, 0.0, "crawling: no stick toward the wind")
	skipper._steer_toward(skipper._sim.telemetry, 220.0)
	assert_lt(skipper._hands.steer, -0.5, "bearing away it still may")
	# Faster, but not yet the release speed (2.5 + 1.5): still gathering speed.
	skipper._sim.telemetry.speed_ms = 3.5
	skipper._steer_toward(skipper._sim.telemetry, 320.0)
	assert_eq(skipper._hands.steer, 0.0, "still crawling below the release speed")
	skipper._sim.telemetry.speed_ms = 4.5
	skipper._steer_toward(skipper._sim.telemetry, 320.0)
	assert_gt(skipper._hands.steer, 0.9, "with speed it heads up again")


func test_on_it_leaves_holding_back_and_racing_alone() -> void:
	var skipper: Skipper = _crawling_skipper(2.0)
	skipper.config.crawl_no_head_up_ms = 2.5
	skipper._hands.hold_speed_ms = 2.0
	skipper._steer_toward(skipper._sim.telemetry, 320.0)
	assert_gt(skipper._hands.steer, 0.9, "holding back (slow on purpose): it luffs as before")
	skipper._hands.hold_speed_ms = 0.0
	skipper.state = Skipper.State.RACING
	skipper._steer_toward(skipper._sim.telemetry, 320.0)
	assert_gt(skipper._hands.steer, 0.9, "after its start: as before")


func test_on_it_stands_aside_while_the_shore_lookout_steers() -> void:
	var skipper: Skipper = _crawling_skipper(2.0)
	skipper.config.crawl_no_head_up_ms = 2.5
	skipper.config.crawl_stuck_s = 0.0
	skipper._shore_steers = true
	skipper._steer_toward(skipper._sim.telemetry, 320.0)
	skipper._steer_toward(skipper._sim.telemetry, 320.0)
	assert_gt(skipper._hands.steer, 0.9, "turned off the shore: it heads up as asked (let go, it ran aground: r0091)")
