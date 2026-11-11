extends GutTest
## Max's slalom start (SkipperConfig.slalom_timed_run, Skipper._slalom_run_heading(); 11 November 2026): instead of waiting
## upwind of the committee boat and diving down, the board sails a timed run behind its spot: away from the line on the
## reciprocal of the reach to mark 1, a gybe when the time left is the way back at the speed it sailed out plus the gybe's
## cost, and back at full speed.

const RunRace: GDScript = preload("res://dev/run_race.gd")
const DT: float = 1.0 / 60.0


func test_it_is_off_unless_switched_on() -> void:
	var config: SkipperConfig = SkipperConfig.new()
	assert_false(config.slalom_timed_run, "off by default until the suite says it wins")
	assert_eq(config.slalom_run_turn_s, 12.0, "the gybe's cost measured on the run (the night of 11-12 November)")


func test_maxs_example_the_gybe_falls_just_after_half_time() -> void:
	# Max: out through the line at 100 s to go, back at the same speed, a gybe that costs 5 s. Sailing out at 8 m/s, the
	# way back is the way out; the gybe is due once the time left is no more than that way back plus the 5 s: at 52.5 s.
	var speed_ms: float = 8.0
	var turn_s: float = 5.0
	var turned_at_left_s: float = NAN
	for tenth: int in 1001:
		var time_left_s: float = 100.0 - 0.1 * tenth
		var way_back_m: float = speed_ms * (100.0 - time_left_s)
		if time_left_s <= way_back_m / speed_ms + turn_s:
			turned_at_left_s = time_left_s
			break
	assert_almost_eq(turned_at_left_s, 52.5, 0.11, "gybe at 52.5 s to go: 47.5 s out, 5 s gybing, 47.5 s back")


func test_the_reach_in_crosses_the_line_toward_the_course_on_a_reach() -> void:
	var parts: Dictionary = _slalom_race(18.0, 120.0)
	var skipper: Skipper = (parts["entries"] as Array)[0].skipper as Skipper
	var race: RaceSim = parts["race"]
	var step: RaceStep = race.steps()[0]
	var wind_deg: float = (parts["entries"] as Array)[0].sim.telemetry.wind_from_bearing_deg
	var run_in: Vector2 = skipper._slalom_run_in(step, wind_deg)
	assert_gt(run_in.dot(step.in_dir), 0.3, "it crosses the line toward the course")
	var twa: float = absf(Navigation.wind_angle_deg(Vector2.ZERO, run_in, wind_deg))
	var dive_twa: float = absf(Navigation.wind_angle_deg(Vector2.ZERO, RaceCourses.slalom_dive_direction(race.course), wind_deg))
	var on_a_reach: bool = twa >= Skipper.SLALOM_RUN_CLOSEST_TWA_DEG - 0.5 and twa <= Skipper.SLALOM_RUN_DEEPEST_TWA_DEG + 0.5
	assert_true(on_a_reach or is_equal_approx(twa, dive_twa), "a reach toward mark 1 (or the dive's): %.0f deg" % twa)


func test_a_slalom_start_sails_out_gybes_and_crosses_after_the_gun() -> void:
	# T2's slalom, 18 kt, a 120 s countdown: the board runs out and back (it never waits at a crawl), and it crosses the
	# line after the gun, within the start check's 20 s, not over early.
	var parts: Dictionary = _slalom_race(18.0, 120.0)
	var race: RaceSim = parts["race"]
	var entries: Array = parts["entries"]
	var rules: RaceRules = parts["rules"]
	var skipper: Skipper = entries[0].skipper as Skipper
	var sailed_out: bool = false
	var gybed: bool = false
	while race.clock_s() < 25.0:
		RunRace.step_race(race, entries, false, rules)
		sailed_out = sailed_out or skipper.note.begins_with("start: slalom run, away")
		gybed = gybed or skipper.note.begins_with("start: slalom run, gybing")
	assert_true(sailed_out, "it sailed out on its run")
	assert_true(gybed, "it gybed to come back")
	assert_true(race.next_step_index(0) >= 1, "started")
	assert_false(skipper.was_ocs, "not over at the gun")
	if race.next_step_index(0) >= 1:
		assert_lt(race.splits_s(0)[0], 20.0, "crossed within 20 s of the gun")


static func _slalom_race(wind_kt: float, prestart_s: float) -> Dictionary:
	var course: Course = RunRace.course_named("t2_slalom")
	var race: RaceSim = RaceSim.new(course, 1, prestart_s)
	var entries: Array = RunRace.make_entries(race, course, PackedStringArray(["allrounder"]), wind_kt, 50.0, 1)
	var skipper: Skipper = entries[0].skipper as Skipper
	# Its own copy of the settings, so that the switch does not reach another test's skipper.
	skipper.config = skipper.config.duplicate()
	skipper.config.slalom_timed_run = true
	var rules: RaceRules = RunRace.give_rules(entries, race, course)
	race.start()
	return {"race": race, "entries": entries, "rules": rules}
