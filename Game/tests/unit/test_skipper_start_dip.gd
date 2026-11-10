extends GutTest
## start_dip (Skipper._dip_deg(); the training method's phase S3, the night of 10-11 November 2026): before the gun, a
## board at a crawl early at the line, or just over the line, bears away on its tack to the wind angle closest to the
## wind whose track runs away from the line. Of 47 boards over early in the two baselines, 19 slid over from "holding
## back hard, early" at 1.5 to 1.9 m/s, and 8 were then 20 to 47 m over at the gun.


func test_it_is_off_unless_switched_on() -> void:
	assert_false(SkipperConfig.new().start_dip, "off by default until the suite says it wins")


func test_an_upwind_start_dips_on_a_broad_reach_on_either_tack() -> void:
	# The wind from the north, the line east-west, the course side north of it.
	var forward: Vector2 = Course.direction_of(0.0)
	# The first angle whose track (HOLD_LEEWAY_DEG, 11 degrees, further off the wind) runs away from the line by
	# DIP_AWAY_SHARE: cos(twa + 11) <= -0.3 first at 100 in 5 degree steps from 50.
	assert_eq(Skipper._dip_twa_deg(0.0, 1.0, forward, 140.0), 100.0, "starboard tack: a broad reach of 100 degrees")
	assert_eq(Skipper._dip_twa_deg(0.0, -1.0, forward, 140.0), 100.0, "port tack: the same")


func test_a_reaching_start_dips_only_on_the_tack_that_runs_away_from_the_line() -> void:
	# The wind from the west, the line along it (east-west, the course side north): on the tack heading south of west
	# the hold's own angle already runs away from the line; on the other tack no angle does.
	var forward: Vector2 = Course.direction_of(0.0)
	assert_eq(Skipper._dip_twa_deg(270.0, 1.0, forward, 140.0), Skipper.HOLD_TWA_DEG,
		"the tack heading away from the line: the hold's own angle")
	assert_true(is_nan(Skipper._dip_twa_deg(270.0, -1.0, forward, 140.0)),
		"the tack heading at the line: no dip (it does what it did before)")


func test_no_deeper_than_its_downwind_angle() -> void:
	var forward: Vector2 = Course.direction_of(0.0)
	assert_true(is_nan(Skipper._dip_twa_deg(0.0, 1.0, forward, 90.0)),
		"an upwind start with a downwind angle of 90 at most: no angle runs away far enough")
