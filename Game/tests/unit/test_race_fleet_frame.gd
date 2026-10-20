extends GutTest
## The frame's work with a big fleet (F1 fleet_frame, AI_FLEET_PLAN.md D2): the boards shared over
## at most eight worker-thread tasks (RaceRunner.batches), and the race order worked out once per
## tick instead of a sort per question (RaceSim.race_order, place; RaceHud.fleet_text).

const BOARDS: int = 33


# ---------------------------------------------------------------- the batches

func test_33_boards_over_8_tasks_are_5_then_4_each_with_the_player_first() -> void:
	var shared: Array[PackedInt32Array] = RaceRunner.batches(BOARDS, 8)
	assert_eq(shared.size(), 8, "eight tasks")
	var sizes: Array[int] = []
	for batch: PackedInt32Array in shared:
		sizes.append(batch.size())
	assert_eq(sizes, [5, 4, 4, 4, 4, 4, 4, 4] as Array[int], "shared as evenly as can be")
	assert_eq(shared[0][0], 0, "the player's board is in the first batch")
	_assert_every_board_once(shared, BOARDS)


func test_even_and_small_fleets() -> void:
	var even: Array[PackedInt32Array] = RaceRunner.batches(32, 8)
	for batch: PackedInt32Array in even:
		assert_eq(batch.size(), 4, "32 boards: four per task")
	_assert_every_board_once(even, 32)
	var small: Array[PackedInt32Array] = RaceRunner.batches(3, 8)
	assert_eq(small.size(), 3, "fewer boards than tasks: one task each")
	_assert_every_board_once(small, 3)
	assert_eq(RaceRunner.batches(0, 8).size(), 0, "no boards, no tasks")
	assert_eq(RaceRunner.batches(5, 0).size(), 1, "no thread count: one batch, never none")
	_assert_every_board_once(RaceRunner.batches(41, 8), 41)


func _assert_every_board_once(shared: Array[PackedInt32Array], count: int) -> void:
	var seen: Array[int] = []
	for batch: PackedInt32Array in shared:
		for i: int in batch:
			seen.append(i)
	var expected: Array[int] = []
	for i: int in count:
		expected.append(i)
	assert_eq(seen, expected, "every board once, in order")


func test_the_median_and_the_worst() -> void:
	assert_eq(RaceRunner.median(PackedFloat64Array([3.0, 1.0, 2.0])), 2.0)
	assert_eq(RaceRunner.median(PackedFloat64Array([4.0, 1.0, 2.0, 3.0])), 2.5)
	assert_eq(RaceRunner.median(PackedFloat64Array()), 0.0)
	assert_eq(RaceRunner.worst(PackedFloat64Array([3.0, 7.5, 2.0])), 7.5)


# ---------------------------------------------------------------- the race order

func test_the_order_is_by_distance_on_the_same_step_and_follows_the_boards() -> void:
	var race: RaceSim = _big_race()
	var order: Array[int] = race.race_order()
	assert_eq(order.size(), BOARDS)
	for rank: int in order.size():
		assert_eq(race.place(order[rank]), rank + 1, "place() and race_order() agree")
		if rank > 0:
			assert_true(race.distance_to_next_m(order[rank - 1]) <= race.distance_to_next_m(order[rank]), "nearer the line first")
	# The last board moves to the front: the order is worked out again.
	var last: int = order[BOARDS - 1]
	var first: int = order[0]
	race.update_board(last, race.board_position(first) + race.steps()[0].in_dir * 0.5)
	assert_eq(race.place(last), 1, "moved to the front")
	assert_eq(race.place(first), 2)


func test_the_fleet_lines_at_33_boards_are_cheap() -> void:
	var race: RaceSim = _big_race()
	var t0: int = Time.get_ticks_usec()
	var text: String = RaceHud.fleet_text(race, 0)
	var fleet_ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	for frame: int in 60:
		race.place(0)
	var places_ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	# Before fleet_frame the lines took about 320 ms here (a sort for every comparison of the sort)
	# and a place() 0.6 ms; generous limits, for a busy machine.
	gut.p("the fleet's lines %.2f ms; the player's place 60 times %.2f ms" % [fleet_ms, places_ms])
	assert_lt(fleet_ms, 20.0, "the fleet's lines at 33 boards")
	assert_lt(places_ms, 5.0, "a second of frames asking for the place, the order worked out once")
	var lines: PackedStringArray = text.split("\n")
	assert_eq(lines.size(), BOARDS)
	assert_true(lines[0].begins_with("1. "), "the leader first")


## A race on T1 with BOARDS boards spread behind the start line, in the countdown.
func _big_race() -> RaceSim:
	var course: Course = RaceCourses.t1_loop(270.0, Vector2.ZERO)
	var race: RaceSim = RaceSim.new(course, 1, 30.0)
	var start: RaceStep = race.steps()[0]
	var along: Vector2 = (start.points[0] - start.points[1]).normalized()
	for i: int in BOARDS:
		race.add_board("Board %d" % i)
		var behind_m: float = 20.0 + float((i * 7) % 13)
		race.update_board(i, course.start_middle() + along * (float(i) - 16.0) - start.in_dir * behind_m)
	race.start()
	race.step(0.1)
	return race
