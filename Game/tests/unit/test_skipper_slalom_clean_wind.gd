extends GutTest
## Max's slalom start in clean wind (SkipperConfig.slalom_run_clean_wind, Skipper.clean_gap_m(); 12 November 2026: "it's
## not wrong if they are close together but there is one with dirty wind"). The line here runs along the wind from the
## pin at (0, 0) to the boat end at (200, 0), the air moving along +X: the boat end is the leeward end.

const DOWNWIND: Vector2 = Vector2(1.0, 0.0)
const LINE_DIR: Vector2 = Vector2(1.0, 0.0)


func _gap(at_m: float, crossings: Array[Vector2], gap_m: float = 0.0) -> float:
	return Skipper.clean_gap_m(WindShadows.make(), Vector2.ZERO, LINE_DIR, at_m, gap_m, 6.0, 194.0,
		PackedVector2Array(crossings), DOWNWIND)


func test_off_by_default() -> void:
	assert_false(SkipperConfig.new().slalom_run_clean_wind, "off until the suite says it wins")


func test_no_boards_coming_in_keeps_its_spot() -> void:
	assert_eq(_gap(100.0, []), 0.0)


func test_level_just_to_leeward_of_a_board_it_drops_to_leeward_out_of_its_dirty_wind() -> void:
	# 10 m to leeward the shadow leaves 76 % of the wind; 15 m 82 %, 20 m 88 %, 25 m 94 % (clean from 92 %).
	assert_eq(_gap(100.0, [Vector2(90.0, 0.0)]), 15.0, "to 25 m to leeward of the other board's crossing")


func test_close_but_across_the_wind_is_clean() -> void:
	# 20 m from it across the wind (one ahead of the other on the reach): close, but in clean wind.
	assert_eq(_gap(100.0, [Vector2(100.0, 20.0)]), 0.0)


func test_the_board_to_windward_keeps_its_spot() -> void:
	# The other board 10 m to leeward is in this one's dirty wind, not the other way round.
	assert_eq(_gap(100.0, [Vector2(110.0, 0.0)]), 0.0)


func test_a_clean_gap_already_taken_is_kept() -> void:
	assert_eq(_gap(100.0, [Vector2(90.0, 0.0)], 15.0), 15.0)


func test_at_the_leeward_end_of_the_line_it_goes_to_windward_of_the_board_with_room() -> void:
	# No room to leeward (the line ends 6 m from the boat end): to windward, at least 8 m from the other's crossing.
	assert_eq(_gap(190.0, [Vector2(180.0, 0.0)]), -20.0)
