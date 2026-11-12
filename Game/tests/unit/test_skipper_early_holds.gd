extends GutTest
## early_holds_its_tack (Skipper._start_heading(); the training method's phase S3, 11 November 2026): early at the line
## on the other tack than its way in's, it holds back hard on the tack it is on instead of turning onto the way in's tack
## a few metres from the line. With start_go_lag_s 3, 8 of the 20 boards newly over early were turning so.


func test_it_is_on_by_default() -> void:
	assert_true(SkipperConfig.new().early_holds_its_tack, "since Max's choice (12 November 2026: \"lag on course\")")


func test_the_hold_angle_on_either_tack_keeps_its_track_off_the_wind() -> void:
	# The angle it holds on the tack it is on comes from the same rule as the way in's (_hold_twa_deg()): its track at
	# least HOLD_TRACK_MIN_TWA_DEG off the wind, no wider than HOLD_WIDEST_TWA_DEG, on both tacks alike.
	var forward: Vector2 = Course.direction_of(0.0)
	for tack: float in [1.0, -1.0]:
		var twa: float = Skipper._hold_twa_deg(0.0, tack, forward)
		assert_gte(twa + Skipper.HOLD_LEEWAY_DEG, Skipper.HOLD_TRACK_MIN_TWA_DEG - 0.01, "track off the wind (tack %+.0f)" % tack)
		assert_lte(twa, Skipper.HOLD_WIDEST_TWA_DEG + 0.01, "no wider than the widest hold (tack %+.0f)" % tack)
