extends GutTest
## The book-keeping of a slalom event week (Game/race/event/): the ladder of 64, who goes through,
## the places, the points with the dropped results, the standings, the seeding of the next
## elimination, and the save (Documentation/reports/broadcast/EVENT_WEEK_PLAN.md).

const SAVE_PATH: String = "user://test_event_week.json"


func after_each() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _ids() -> PackedInt32Array:
	var ids: PackedInt32Array = PackedInt32Array()
	for i: int in 64:
		ids.append(i)
	return ids


## A heat's order with the better seed always ahead (the favourites win everything).
func _by_seed(ladder: EliminationLadder, heat: int) -> PackedInt32Array:
	var order: Array = Array(ladder.sailors_in(heat))
	order.sort_custom(func(a: int, b: int) -> bool: return ladder.seeds.find(a) < ladder.seeds.find(b))
	return PackedInt32Array(order)


## A heat's order turned by a number, so results differ from heat to heat but are the same every run.
func _turned(ladder: EliminationLadder, heat: int, by: int) -> PackedInt32Array:
	var order: PackedInt32Array = _by_seed(ladder, heat)
	var out: PackedInt32Array = PackedInt32Array()
	for i: int in order.size():
		out.append(order[(i + by) % order.size()])
	return out


func test_the_first_round_spreads_64_over_eight_heats_by_seed() -> void:
	var ladder: EliminationLadder = EliminationLadder.for_seeds(_ids())
	var seen: Dictionary[int, bool] = {}
	for heat: int in range(1, 9):
		var sailors: PackedInt32Array = ladder.sailors_in(heat)
		assert_eq(sailors.size(), 8, "heat %d has eight sailors" % heat)
		assert_eq(sailors[0], heat - 1, "seeds 1 to 8 open heats 1 to 8")
		for id: int in sailors:
			assert_false(seen.has(id), "sailor %d is in one heat only" % id)
			seen[id] = true
	assert_eq(seen.size(), 64)
	# The snake: seed 9 (id 8) goes into heat 8 beside seed 8, seed 16 into heat 1 beside seed 1.
	assert_true(ladder.sailors_in(8).has(8))
	assert_true(ladder.sailors_in(1).has(15))
	assert_true(ladder.sailors_in(9).is_empty(), "a quarter-final is unknown until its two heats are sailed")


func test_the_first_four_go_through_and_the_ladder_fills() -> void:
	var ladder: EliminationLadder = EliminationLadder.for_seeds(_ids())
	assert_eq(ladder.next_heat(), 1)
	assert_false(ladder.record(2, _by_seed(ladder, 2)), "heats are sailed in order")
	assert_false(ladder.record(1, PackedInt32Array([0, 1, 2])), "a result names every sailor of the heat")
	assert_true(ladder.record(1, _by_seed(ladder, 1)))
	assert_eq(ladder.through_from(1).size(), 4)
	assert_true(ladder.sailors_in(9).is_empty())
	assert_true(ladder.record(2, _by_seed(ladder, 2)))
	var quarter: PackedInt32Array = ladder.sailors_in(9)
	assert_eq(quarter.size(), 8, "quarter-final 1 is the first four of heats 1 and 2")
	for id: int in ladder.through_from(1) + ladder.through_from(2):
		assert_true(quarter.has(id))


func test_a_whole_elimination_places_everyone_once() -> void:
	var ladder: EliminationLadder = EliminationLadder.for_seeds(_ids())
	var sailed: int = 0
	while not ladder.is_over():
		var heat: int = ladder.next_heat()
		assert_eq(ladder.sailors_in(heat).size(), 8, "%s is full" % EliminationLadder.heat_name(heat))
		assert_true(ladder.record(heat, _by_seed(ladder, heat)))
		sailed += 1
	assert_eq(sailed, 16, "an elimination of 64 is 16 heats")
	var places: PackedInt32Array = ladder.places()
	assert_eq(places.size(), 64)
	for id: int in 64:
		assert_eq(places.count(id), 1, "sailor %d has one place" % id)
	# With the better seed always ahead, the favourite wins and the top eight are the winners' final.
	assert_eq(places[0], 0)
	for place: int in 8:
		assert_true(ladder.result_of(EliminationLadder.WINNERS_FINAL).has(places[place]))
	for place: int in range(8, 16):
		assert_true(ladder.result_of(EliminationLadder.LOSERS_FINAL).has(places[place]))
	# Places 17 to 32 were knocked out in a quarter-final, 33 to 64 in the first round.
	for place: int in range(16, 32):
		assert_true(ladder.result_of(9).has(places[place]) or ladder.result_of(10).has(places[place]) or ladder.result_of(11).has(places[place]) or ladder.result_of(12).has(places[place]))


func test_the_points_and_the_dropped_results() -> void:
	assert_almost_eq(EventWeek.points_for(1), 0.7, 1e-6)
	assert_almost_eq(EventWeek.points_for(2), 2.0, 1e-6)
	assert_almost_eq(EventWeek.points_for(33), 33.0, 1e-6)
	assert_eq(EventWeek.dropped_after(3), 0)
	assert_eq(EventWeek.dropped_after(4), 1)
	assert_eq(EventWeek.dropped_after(7), 2)
	assert_eq(EventWeek.dropped_after(11), 3)


func test_a_week_runs_to_a_champion_and_seeds_from_the_standings() -> void:
	var week: EventWeek = EventWeek.start("sotavento_2026")
	assert_not_null(week)
	if week == null:
		return
	assert_eq(week.roster.sailors.size(), 64)
	assert_eq(week.total_eliminations(), 11, "the real week had eleven eliminations")
	assert_eq(week.sailors_now().size(), 8)
	var heats: int = 0
	while week.elimination == 1:
		assert_true(week.record_heat(_turned(week.ladder, week.next_heat(), heats % 3)))
		heats += 1
	assert_eq(heats, 16)
	assert_eq(week.results.size(), 1)
	var leader: int = week.standings()[0]
	assert_eq(leader, week.results[0][0], "after one elimination its winner leads")
	assert_eq(week.ladder.seeds[0], leader, "the second elimination is seeded from the standings")
	assert_almost_eq(week.total_of(leader), 0.7, 1e-6)
	while not week.is_over():
		assert_true(week.record_heat(_turned(week.ladder, week.next_heat(), (heats + week.elimination) % 4)))
		heats += 1
	assert_eq(heats, 11 * 16)
	assert_eq(week.next_heat(), 0)
	assert_eq(week.results.size(), 11)
	# Eleven results, three dropped: the champion's total is the sum of his eight best.
	var champion: int = week.standings()[0]
	var points: Array = Array(week.points_of(champion))
	points.sort()
	var best_eight: float = 0.0
	for i: int in 8:
		best_eight += float(points[i])
	assert_almost_eq(week.total_of(champion), best_eight, 1e-4)


func test_a_saved_week_goes_on_to_the_same_champion() -> void:
	var straight: EventWeek = EventWeek.start("sotavento_2026")
	var halved: EventWeek = EventWeek.start("sotavento_2026")
	if straight == null or halved == null:
		fail_test("the week didn't start")
		return
	var heats: int = 0
	while not straight.is_over():
		var turn: int = (heats * 7 + straight.elimination) % 5
		assert_true(straight.record_heat(_turned(straight.ladder, straight.next_heat(), turn)))
		if halved != null and not halved.is_over():
			assert_true(halved.record_heat(_turned(halved.ladder, halved.next_heat(), turn)))
		heats += 1
		if heats == 70:
			# In the middle of the fifth elimination: save, forget, load.
			assert_true(halved.save_to(SAVE_PATH))
			halved = EventWeek.load_from(SAVE_PATH)
			assert_not_null(halved, "the saved week loads")
			if halved == null:
				return
			assert_eq(halved.elimination, straight.elimination)
			assert_eq(halved.next_heat(), straight.next_heat())
	assert_true(halved.is_over())
	assert_eq(Array(halved.standings()), Array(straight.standings()))


func test_a_broken_save_is_refused_without_a_crash() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string("{\"version\": 99, \"schedule\": \"sotavento_2026\"}")
	file.close()
	assert_null(EventWeek.load_from(SAVE_PATH))
	assert_null(EventWeek.load_from("user://no_such_event_week.json"))


func test_the_roster_has_favourites_and_tail_enders() -> void:
	var roster: EventRoster = EventRoster.provisional()
	assert_not_null(roster)
	if roster == null:
		return
	assert_eq(roster.sailors.size(), 64)
	var names: Dictionary[String, bool] = {}
	for sailor: EventRoster.Sailor in roster.sailors:
		assert_false(names.has(sailor.name), "%s is one sailor" % sailor.name)
		names[sailor.name] = true
		assert_ne(sailor.country, "")
		assert_not_null(sailor.persona)
		assert_eq(sailor.persona.name, sailor.name, "the name on the board is the sailor's")
	assert_gt(roster.sailors[0].persona.boat_speed, roster.sailors[63].persona.boat_speed + 0.2, "the favourite is clearly faster than the last of the ranking")
	assert_not_null(roster.sailors[0].make_skipper())
