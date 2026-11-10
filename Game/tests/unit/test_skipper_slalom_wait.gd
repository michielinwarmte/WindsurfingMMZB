extends GutTest
## slalom_wait_moving (Skipper._slalom_wait_twa_deg(); the training method's phase S3, the night of 10-11 November
## 2026): waiting upwind of a slalom's committee boat, the slower the board goes the further it bears away, from its
## luffed-up angle at 2.5 m/s to a beam reach at 0.8 m/s. 54 of the 88 falls in the two baselines came while waiting
## there luffed up at 0.2 to 0.4 m/s.


func test_it_is_off_unless_switched_on() -> void:
	assert_false(SkipperConfig.new().slalom_wait_moving, "off by default until the suite says it wins")


func test_luffed_up_with_speed_and_borne_away_at_a_stall() -> void:
	var luff: float = Skipper.HOLD_LUFF_TWA_DEG
	assert_eq(Skipper._slalom_wait_twa_deg(luff, 3.0), luff, "with steerage: luffed up, as before")
	assert_eq(Skipper._slalom_wait_twa_deg(luff, Skipper.SLALOM_WAIT_LUFF_FROM_MS), luff, "at the luff-from speed: luffed up")
	assert_eq(Skipper._slalom_wait_twa_deg(luff, 0.3), Skipper.HOLD_WIDEST_TWA_DEG, "nearly stopped: a beam reach")
	var middle_ms: float = 0.5 * (Skipper.SLALOM_WAIT_LUFF_FROM_MS + Skipper.SLALOM_WAIT_STALL_MS)
	assert_almost_eq(Skipper._slalom_wait_twa_deg(luff, middle_ms), 0.5 * (luff + Skipper.HOLD_WIDEST_TWA_DEG), 0.01,
		"half way between the speeds: half way between the angles")
