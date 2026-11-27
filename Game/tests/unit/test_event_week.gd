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
	assert_eq(EventWeek.dropped_after(11), 2)
	assert_eq(EventWeek.dropped_after(12), 3)


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
	# Eleven results, two dropped: the champion's total is the sum of his nine best.
	var champion: int = week.standings()[0]
	var points: Array = Array(week.points_of(champion))
	points.sort()
	var best_nine: float = 0.0
	for i: int in 9:
		best_nine += float(points[i])
	assert_almost_eq(week.total_of(champion), best_nine, 1e-4)


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
	# The favourite is good in a strong wind whatever his character (Sotavento blows 30 knots): his
	# form there is no worse than a middling sailor's, and well above the last of the ranking's.
	assert_gt(roster.sailors[0].persona.strong_wind, 0.69)
	assert_gt(roster.sailors[0].persona.wind_form(30.0), roster.sailors[63].persona.wind_form(30.0) + 0.05)


func test_the_results_text_names_everyone_and_marks_the_dropped() -> void:
	var week: EventWeek = EventWeek.start("sotavento_2026")
	if week == null:
		fail_test("the week didn't start")
		return
	var heats: int = 0
	while week.results.size() < 4:
		assert_true(week.record_heat(_turned(week.ladder, week.next_heat(), heats % 3)))
		heats += 1
	# Three heats into the fifth elimination.
	for i: int in 3:
		assert_true(week.record_heat(_turned(week.ladder, week.next_heat(), i)))
	var text: String = week.results_text()
	var rows: PackedStringArray = text.split("\n")
	assert_eq(rows[0], week.title)
	assert_string_contains(rows[1], "after 4 of 11 eliminations (1 dropped)")
	for sailor: EventRoster.Sailor in week.roster.sailors:
		assert_string_contains(text, sailor.name)
	# Every sailor's row has four results, one of them in brackets (the dropped one).
	for row: int in range(2, 66):
		assert_eq(rows[row].count("("), 1, "one dropped result in: %s" % rows[row])
	var leader: EventRoster.Sailor = week.roster.sailor(week.standings()[0])
	assert_string_contains(rows[2], leader.name)
	assert_string_contains(text, "Elimination 4 (")
	assert_string_contains(text, "Elimination 5, being sailed:")
	assert_string_contains(text, "First round, heat 3")
	assert_false(text.contains("First round, heat 4"), "a heat not sailed yet is not listed")


# ---------------------------------------------------------------- the event in the commentary

func test_the_heats_are_said_in_words() -> void:
	assert_eq(EventBroadcast.heat_words(3), "heat three of the first round")
	assert_eq(EventBroadcast.heat_words(9), "the first quarter-final")
	assert_eq(EventBroadcast.heat_words(12), "the fourth quarter-final")
	assert_eq(EventBroadcast.heat_words(14), "the second semi-final")
	assert_eq(EventBroadcast.heat_words(15), "the losers' final")
	assert_eq(EventBroadcast.heat_words(16), "the winners' final")
	assert_eq(EventBroadcast.round_words(8), "the quarter-finals")
	assert_eq(EventBroadcast.round_words(11), "the semi-finals")
	assert_eq(EventBroadcast.round_words(13), "the winners' final")
	assert_eq(EventBroadcast.elimination_words(11), "elimination eleven")


func test_a_slot_that_opens_a_sentence_gets_a_capital() -> void:
	assert_eq(CommentaryDirector.capitalised("this is it. the winners' final of elimination one."), "This is it. The winners' final of elimination one.")
	assert_eq(CommentaryDirector.capitalised("no! he's down? yes."), "No! He's down? Yes.")
	assert_eq(CommentaryDirector.capitalised("You've got Mara on that Point.9 sail."), "You've got Mara on that Point.9 sail.")
	assert_eq(CommentaryDirector.capitalised(""), "")


func test_the_event_lines_load_clean_on_top_of_the_bank() -> void:
	var bank: CommentaryBank = CommentaryBank.load_file()
	var before: int = bank.size()
	assert_true(bank.add_file(CommentaryBank.EVENT_PATH), "the event's lines are read")
	assert_eq(bank.problems.size(), 0, "no line of the two files is refused: %s" % ", ".join(bank.problems))
	assert_gt(bank.size(), before + 30)
	for moment: String in ["heat_called", "heat_favourite", "heat_through", "heat_out", "final_win", "standings", "event_win"]:
		assert_gt(bank.lines_for(moment).size(), 3, "%s has lines" % moment)


func test_an_event_moment_is_said_with_its_own_words() -> void:
	var bank: CommentaryBank = CommentaryBank.load_file()
	bank.add_file(CommentaryBank.EVENT_PATH)
	var config: CommentaryConfig = load("res://config/commentary_default.tres") as CommentaryConfig
	var director: CommentaryDirector = CommentaryDirector.new(bank, config, 7)
	var look: RaceLook = RaceLook.new()
	# A heat four go through from, about a sailor who is not on the water (no board): every slot is
	# filled from the moment's own words, and no final's line is taken.
	var seen: Dictionary[String, bool] = {}
	for line: CommentaryBank.Line in bank.lines_for("heat_called") + bank.lines_for("heat_through") + bank.lines_for("standings"):
		var moment: RaceMoment = RaceMoment.make(line.moment)
		moment.words = {"heat": "heat three of the first round", "round": "the quarter-finals", "elimination": "elimination two",
			"event": "the Sotavento World Cup", "rider": "Koen Zeilstra", "rider2": "Gian Baumann"}
		moment.tags.append("not_final")
		if not director.needs_met(line, moment, look):
			assert_true(line.needs.has("final"), "%s: only a final's line is refused for a heat" % line.id)
			continue
		var words: String = director.fill(line, moment, look)
		assert_ne(words, "", "%s is filled" % line.id)
		assert_false(words.contains("{"), "%s has no slot left: %s" % [line.id, words])
		seen[line.moment] = true
	assert_eq(seen.size(), 3)
	var called: RaceMoment = RaceMoment.make("heat_called", -1, 3)
	called.words = {"heat": "the winners' final", "elimination": "elimination one", "event": "the Sotavento World Cup"}
	called.tags.append("final")
	var pick: Dictionary = director.choose_line(called, look)
	assert_false(pick.is_empty(), "a final is called")
	if not pick.is_empty():
		assert_false((pick["line"] as CommentaryBank.Line).needs.has("not_final"))
	# A country word comes from the board's sailor, or from the moment.
	var favourite: RaceMoment = RaceMoment.make("heat_favourite")
	favourite.words = {"rider": "Lorenzo Serra", "national": "Italian", "nation_adj": "Italian"}
	favourite.place = 3
	for line: CommentaryBank.Line in bank.lines_for("heat_favourite"):
		assert_ne(director.fill(line, favourite, look), "", "%s is filled" % line.id)
