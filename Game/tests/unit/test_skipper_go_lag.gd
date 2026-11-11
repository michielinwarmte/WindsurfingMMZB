extends GutTest
## start_go_lag_s (Skipper._go_lag_s(); safe but fast, Max, 11 November 2026): the time getting going from a hold takes
## beyond the reckoning, the whole lag at a crawl, none from 5 m/s up. Measured on phase S3's 1661 starts from a hold.


func test_it_is_off_unless_switched_on() -> void:
	assert_eq(SkipperConfig.new().start_go_lag_s, 0.0, "off by default until the suite says it wins")
	assert_eq(Skipper._go_lag_s(0.0, 1.0), 0.0, "off: no lag, however slow")


func test_the_whole_lag_at_a_crawl_and_none_at_speed() -> void:
	assert_eq(Skipper._go_lag_s(3.0, 1.0), 3.0, "1 m/s: the whole lag")
	assert_eq(Skipper._go_lag_s(3.0, Skipper.START_LAG_CRAWL_MS), 3.0, "at the crawl speed: the whole lag")
	assert_eq(Skipper._go_lag_s(3.0, Skipper.START_LAG_AT_SPEED_MS), 0.0, "at speed: none")
	assert_eq(Skipper._go_lag_s(3.0, 9.0), 0.0, "going fast: none")
	var middle_ms: float = 0.5 * (Skipper.START_LAG_CRAWL_MS + Skipper.START_LAG_AT_SPEED_MS)
	assert_almost_eq(Skipper._go_lag_s(3.0, middle_ms), 1.5, 0.001, "half way: half the lag")
