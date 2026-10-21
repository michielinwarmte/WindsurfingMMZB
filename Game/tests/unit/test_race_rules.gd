extends GutTest
## The racing rules (RACING_PLAN.md 9E, AI_FLEET_PLAN.md D5): port keeps clear of starboard; on
## the same tack the windward board keeps clear when overlapped and the board clear astern when
## not; inside the zone the inside board gets room at the mark; a board that touches another it had
## to keep clear of gets one penalty per incident; a full turn clears a penalty; an uncleared one
## costs 20 s at the finish; a sail in the water keeps no rules; and only boards near each other
## are judged.
##
## The wind is from the north (0): starboard tack heads north-west (315), port tack north-east (45).

const DT: float = 1.0 / 60.0


static func _two() -> RaceRules:
	return RaceRules.new(2, 0.0)


func test_port_keeps_clear_of_starboard() -> void:
	var rules: RaceRules = _two()
	rules.set_board(0, Vector2(0.0, 0.0), 315.0, 1.0, 8.0)  # starboard
	rules.set_board(1, Vector2(5.0, 5.0), 45.0, -1.0, 8.0)  # port, 7 m away
	rules.step(DT)
	assert_eq(rules.who_keeps_clear(0, 1), 1, "the port-tack board keeps clear")
	assert_eq(rules.burdened_by(1), 0)
	assert_eq(rules.burdened_by(0), -1, "starboard has right of way")
	assert_eq(rules.why(1), RaceRules.Why.PORT_GIVES_WAY)
	assert_eq(rules.why_text(1), "port gives way to starboard")


func test_on_the_same_tack_the_windward_board_keeps_clear_when_overlapped() -> void:
	var rules: RaceRules = _two()
	# Both on starboard heading north-west; board 1 is 4 m abeam on the windward side (north-east:
	# the wind comes over the right side on starboard tack), level with board 0.
	rules.set_board(0, Vector2(0.0, 0.0), 315.0, 1.0, 8.0)
	rules.set_board(1, Course.direction_of(45.0) * 4.0, 315.0, 1.0, 8.0)
	rules.step(DT)
	assert_true(rules.is_windward(1, 0))
	assert_eq(rules.who_keeps_clear(0, 1), 1, "the windward board")
	assert_eq(rules.why(1), RaceRules.Why.WINDWARD_GIVES_WAY)


func test_on_the_same_tack_the_board_clear_astern_keeps_clear() -> void:
	var rules: RaceRules = _two()
	var forward: Vector2 = Course.direction_of(315.0)
	rules.set_board(0, Vector2.ZERO, 315.0, 1.0, 8.0)
	rules.set_board(1, -forward * 6.0 + Vector2(0.0, -1.0), 315.0, 1.0, 9.0)  # 6 m behind, a little to windward
	rules.step(DT)
	assert_true(rules.is_clear_astern(1, 0))
	assert_false(rules.is_clear_astern(0, 1))
	assert_eq(rules.who_keeps_clear(0, 1), 1, "the board behind, windward or not")
	assert_eq(rules.why(1), RaceRules.Why.ASTERN_GIVES_WAY)
	# 2 m behind and 3 m to windward is overlapped (the hull is 2.4 m): back to the windward rule.
	rules.set_board(1, -forward * 2.0 + Course.direction_of(45.0) * 3.0, 315.0, 1.0, 9.0)
	rules.step(DT)
	assert_false(rules.is_clear_astern(1, 0))
	assert_eq(rules.why(1), RaceRules.Why.WINDWARD_GIVES_WAY)


func test_inside_the_zone_the_inside_board_gets_room_at_the_mark() -> void:
	var rules: RaceRules = _two()
	var mark: Vector2 = Vector2(0.0, -10.0)  # 10 m north of board 0
	# Overlapped on starboard heading north-west; board 1 is 3 m abeam to leeward (south-west).
	rules.set_board(0, Vector2(0.0, 0.0), 315.0, 1.0, 8.0)
	rules.set_board(1, Course.direction_of(225.0) * 3.0, 315.0, 1.0, 8.0)
	var marks: PackedVector2Array = PackedVector2Array([mark, mark])
	rules.step(DT, marks)
	# Outside the zone board 0 is windward: it keeps clear. Inside the zone board 0 is nearer the
	# mark: the inside board, with room.
	assert_eq(rules.who_keeps_clear(0, 1), 0, "windward keeps clear in open water")
	assert_eq(rules.who_keeps_clear(0, 1, mark), 1, "but at the mark the outside board keeps clear")
	assert_eq(rules.why(0), RaceRules.Why.NONE)
	assert_eq(rules.why(1), RaceRules.Why.MARK_ROOM)
	# Sailing to different marks: no mark room.
	rules.step(DT, PackedVector2Array([mark, Vector2.INF]))
	assert_eq(rules.why(0), RaceRules.Why.WINDWARD_GIVES_WAY)


func test_a_touch_by_the_board_that_had_to_keep_clear_is_one_penalty_per_incident() -> void:
	var rules: RaceRules = _two()
	# Starboard board 0 holds its course; port board 1 sails straight into it over 2 s.
	var from: Vector2 = Vector2(6.0, 6.0)
	var ticks: int = 120
	for t: int in ticks:
		var share: float = float(t) / ticks
		rules.set_board(0, Vector2.ZERO, 315.0, 1.0, 8.0)
		rules.set_board(1, from.lerp(Vector2(0.5, 0.5), share), 225.0, -1.0, 8.0)
		rules.step(DT)
	assert_eq(rules.penalties(1), 1, "the port-tack board is penalised once")
	assert_eq(rules.penalties(0), 0, "the right-of-way board is not")
	assert_eq(rules.last_breach_why(1), RaceRules.Why.PORT_GIVES_WAY)
	assert_eq(rules.breach_text(1), "port gives way to starboard")
	assert_true(rules.last_breach_s(1) > 0.0)
	assert_almost_eq(rules.time_penalty_s(1), 20.0, 1e-6, "20 s if it never turns")
	# Another 5 s touching: still one incident.
	for t: int in 300:
		rules.set_board(0, Vector2.ZERO, 315.0, 1.0, 8.0)
		rules.set_board(1, Vector2(0.5, 0.5), 225.0, -1.0, 8.0)
		rules.step(DT)
	assert_eq(rules.penalties(1), 1)


func test_no_penalty_before_the_gun_nor_for_drifting_in_slowly() -> void:
	# The same port-tack board sailing into the starboard one, during the countdown: judged, not
	# penalised.
	var rules: RaceRules = _two()
	var from: Vector2 = Vector2(6.0, 6.0)
	for t: int in 120:
		rules.set_board(0, Vector2.ZERO, 315.0, 1.0, 8.0)
		rules.set_board(1, from.lerp(Vector2(0.5, 0.5), float(t) / 120.0), 225.0, -1.0, 8.0)
		rules.step(DT, PackedVector2Array(), false)
	assert_eq(rules.burdened_by(1), 0, "it still knows who keeps clear")
	assert_eq(rules.penalties(1), 0, "no penalty before the gun")
	# After the gun, drifting in at 0.3 m/s (slower than CLOSING_MS): no penalty either.
	var slow: RaceRules = _two()
	for t: int in 600:
		slow.set_board(0, Vector2.ZERO, 315.0, 1.0, 8.0)
		slow.set_board(1, Vector2(1.5, 1.5) - Vector2(0.3, 0.3) * 0.7071 * (t * DT), 225.0, -1.0, 0.3)
		slow.step(DT)
	assert_eq(slow.penalties(1), 0, "drifting in slowly is not sailing into it")


func test_one_board_gets_no_second_penalty_within_20_s() -> void:
	# Board 1 (port) sails into board 0, then straight on into a third starboard board 4 m further.
	var rules: RaceRules = RaceRules.new(3, 0.0)
	var from: Vector2 = Vector2(6.0, 6.0)
	for t: int in 240:
		var share: float = float(t) / 240.0
		rules.set_board(0, Vector2.ZERO, 315.0, 1.0, 8.0)
		rules.set_board(2, Vector2(-4.0, -4.0), 315.0, 1.0, 8.0)
		rules.set_board(1, from.lerp(Vector2(-4.5, -4.5), share), 225.0, -1.0, 8.0)
		rules.step(DT)
	assert_eq(rules.penalties(1), 1, "one penalty for the two touches within 4 s")


func test_the_right_of_way_board_sailing_into_a_board_keeping_clear_gives_no_penalty() -> void:
	var rules: RaceRules = _two()
	# The port-tack board 1 holds still (keeping clear by stopping, say); starboard board 0 sails
	# into it: no penalty for anyone (the board that kept clear is not the one closing).
	var from: Vector2 = Vector2(-6.0, 6.0)
	for t: int in 120:
		rules.set_board(0, from.lerp(Vector2(-0.3, 0.3), float(t) / 120.0), 45.0, 1.0, 8.0)
		rules.set_board(1, Vector2.ZERO, 45.0, -1.0, 0.0)
		rules.step(DT)
	assert_eq(rules.penalties(0), 0)
	assert_eq(rules.penalties(1), 0, "it was not closing on the other")


func test_a_full_turn_clears_a_penalty() -> void:
	var rules: RaceRules = _two()
	rules.set_board(0, Vector2.ZERO, 0.0, 1.0, 5.0)
	rules.set_board(1, Vector2(100.0, 0.0), 0.0, 1.0, 5.0)
	rules.step(DT)
	rules.penalise(0, RaceRules.Why.WINDWARD_GIVES_WAY)
	assert_eq(rules.penalties(0), 1)
	# Half a turn: not yet.
	var heading: float = 0.0
	for t: int in 90:
		heading += 2.0
		rules.set_board(0, Vector2.ZERO, fposmod(heading, 360.0), 1.0, 5.0)
		rules.step(DT)
	assert_eq(rules.penalties(0), 1, "180 degrees is not a turn")
	for t: int in 90:
		heading += 2.0
		rules.set_board(0, Vector2.ZERO, fposmod(heading, 360.0), 1.0, 5.0)
		rules.step(DT)
	assert_eq(rules.penalties(0), 0, "a full circle clears it")
	assert_eq(rules.turns_done(0), 1)
	assert_eq(rules.time_penalty_s(0), 0.0)


func test_a_sail_in_the_water_keeps_no_rules_and_far_boards_are_not_judged() -> void:
	var rules: RaceRules = _two()
	rules.set_board(0, Vector2.ZERO, 315.0, 1.0, 8.0)
	rules.set_board(1, Vector2(3.0, 3.0), 45.0, -1.0, 0.0, false)  # port, fallen
	rules.step(DT)
	assert_eq(rules.burdened_by(1), -1, "in the water: not judged")
	assert_eq(rules.burdened_by(0), -1)
	rules.set_board(1, Vector2(30.0, 30.0), 45.0, -1.0, 8.0, true)  # port, 42 m away
	rules.step(DT)
	assert_eq(rules.burdened_by(1), -1, "too far away to be judged")
	rules.set_board(1, Vector2(8.0, 8.0), 45.0, -1.0, 8.0, true)  # 11 m away
	rules.step(DT)
	assert_eq(rules.burdened_by(1), 0)
