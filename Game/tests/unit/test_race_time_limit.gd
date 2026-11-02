extends GutTest
## The race's time limit (RaceTimeLimit, fleet_speed/start.md): 2.5 times the polar's time for the
## course and never less than 20 minutes; longer in light wind and with more laps.

func test_a_beat_takes_the_way_to_windward_over_the_vmg() -> void:
	var polar: SkipperPolar = SkipperPolar.default_polar()
	var up_deg: float = SkipperPolar.per_wind(polar.winds_kt, polar.best_upwind_twa_deg, 12.0)
	var beat_ms: float = SkipperPolar.value_at(polar.winds_kt, polar.twa_deg, polar.speed_ms, 12.0, up_deg)
	# 500 m straight to windward (the wind from the north, the leg going north).
	var beat_s: float = RaceTimeLimit.leg_time_s(Vector2.ZERO, Vector2(0.0, -500.0), 0.0, 12.0, polar)
	assert_almost_eq(beat_s, 500.0 / (beat_ms * cos(deg_to_rad(up_deg))), 0.5, "the way to windward over the VMG")
	# A beam reach is sailed straight at the polar's speed.
	var reach_s: float = RaceTimeLimit.leg_time_s(Vector2.ZERO, Vector2(500.0, 0.0), 0.0, 12.0, polar)
	var reach_ms: float = SkipperPolar.value_at(polar.winds_kt, polar.twa_deg, polar.speed_ms, 12.0, 90.0)
	assert_almost_eq(reach_s, 500.0 / reach_ms, 0.5, "straight on a reach")
	assert_gt(beat_s, reach_s, "a beat takes longer than a reach of the same length")


func test_the_limit_fits_the_course_the_wind_and_the_laps() -> void:
	var course: Course = RaceCourses.t1_loop(270.0, Vector2.ZERO)
	var light: float = RaceTimeLimit.for_race(RaceSim.new(course, 1, 60.0), 270.0, 12.0)
	var fresh: float = RaceTimeLimit.for_race(RaceSim.new(course, 1, 60.0), 270.0, 18.0)
	var two_laps: float = RaceTimeLimit.for_race(RaceSim.new(course, 2, 60.0), 270.0, 12.0)
	gut.p("T1's limit: %.0f s at 12 kt, %.0f s at 18 kt, %.0f s for two laps at 12 kt" % [light, fresh, two_laps])
	# Ravi was 126 m from the line after 20 minutes on T1 at 12 kt in the fleet of twenty.
	assert_gt(light, 1300.0, "T1 at 12 kt: room for a slow board in a crowd")
	assert_almost_eq(fresh, RaceTimeLimit.FLOOR_S, 0.01, "T1 at 18 kt: the 20 minutes")
	assert_gt(two_laps, 1.7 * light, "two laps nearly twice one")

