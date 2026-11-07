extends GutTest
## The mouse body and the capture (Max, 7 November 2026: at launch the body sat in the corner, heels
## 100 %, back foot 95 %, and the board could not get going at the start): captured() puts it in the
## middle and ignores the motion right after, and one event longer than the whole travel is a warp.


func test_a_capture_puts_the_body_in_the_middle_and_ignores_the_jump() -> void:
	var body: MouseBody = MouseBody.new()
	body.side = 1.0
	body.back = 1.0
	body.captured()
	assert_eq(body.side, 0.0)
	assert_eq(body.back, 0.0)
	body.move(Vector2(120.0, 120.0))
	assert_eq(body.side, 0.0, "the cursor's warp right after the capture does not move the body")
	assert_eq(body.back, 0.0)


func test_after_the_quiet_time_a_hand_moves_it() -> void:
	var body: MouseBody = MouseBody.new()
	body.captured()
	body._quiet_until_ms = 0
	body.move(Vector2(30.0, -15.0))
	assert_gt(body.side, 0.0, "a hand movement counts")
	assert_lt(body.back, 0.0)


func test_one_jump_longer_than_the_travel_is_ignored() -> void:
	var body: MouseBody = MouseBody.new()
	body.move(Vector2(body.travel_px + 50.0, 0.0))
	assert_eq(body.side, 0.0, "a warp is never a hand")
