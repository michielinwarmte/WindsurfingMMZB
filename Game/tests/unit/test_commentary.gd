extends GutTest
## The commentary (Documentation/reports/broadcast/commentary_director.md): the bank and its checks (the
## real file too), the words for the slots, the director's picking rules (needs, slots, not twice, the
## least used, the level, one voice with pauses, a big moment cutting in, a late moment dropped, the
## board on the screen, the rundown), and the race story's moments on small made-up races (RaceLook).
## The subtitles on the screen are checked with screenshots (watch mode, --tv=1).

const NAMES: PackedStringArray = ["Mara", "Hana", "Kofi", "Liv", "Sven", "Noor", "Tobias"]
const ORANGE: Color = Color(0.95, 0.55, 0.1)


# ---------------------------------------------------------------- the bank

func test_the_real_bank_loads_without_a_problem() -> void:
	var bank: CommentaryBank = CommentaryBank.load_file()
	assert_eq(bank.problems, PackedStringArray(), "every line of the starter bank keeps the contract")
	assert_eq(bank.size(), 76, "the starter bank's 76 lines")
	assert_eq(CommentaryBank.MOMENTS.size(), 42, "the 42 moments of BANK_FORMAT.md (35 of the race, 7 of an event week)")
	var text: String = FileAccess.get_file_as_string(CommentaryBank.PATH)
	var data: Dictionary = JSON.parse_string(text)
	var counted: Dictionary = data["moments"]
	for moment: String in counted.keys():
		assert_true(CommentaryBank.MOMENTS.has(moment), "%s is a known moment" % moment)
		assert_eq(bank.lines_for(moment).size(), int(counted[moment]["lines"]), "the moments list counts %s's lines" % moment)


func test_the_real_banks_lines_fill_and_are_not_too_long() -> void:
	var bank: CommentaryBank = CommentaryBank.load_file()
	for line: CommentaryBank.Line in bank.lines:
		assert_true(line.seconds > 0.2 and line.seconds < 10.0, "%s: %.1f s" % [line.id, line.seconds])
		assert_eq(CommentaryBank.slots_in(line.text), line.slots, "%s: its slots in order" % line.id)


func test_a_broken_line_is_left_out_with_its_reason() -> void:
	var bank: CommentaryBank = CommentaryBank.from_json(JSON.stringify({"format": 1, "moments": {"dance": {}}, "lines": [
		_line("A1", "fall", "{rider}'s gone.", ["rider"]),
		_line("A2", "dance", "Look at him go."),
		_line("A3", "fall", "{team} is down.", ["team"]),
		_line("A4", "fall", "In the drink.", [], ["sunny"]),
		_line("A5", "fall", "{rider} is down.", []),
		_line("A6", "fall", "Down he goes.", ["rider"]),
		_line("A1", "fall", "Twice the same id."),
		_line("A7", "fall", "Too loud.", [], [], 5),
		_line("A8", "fall", "{rider} {and down.", ["rider"]),
	]}), "made up")
	assert_eq(bank.size(), 1, "only the good line is kept")
	assert_not_null(bank.line("A1"))
	var problems: String = "\n".join(bank.problems)
	assert_string_contains(problems, "unknown moment 'dance'")
	assert_string_contains(problems, "A2: unknown moment 'dance'")
	assert_string_contains(problems, "A3: unknown slot 'team'")
	assert_string_contains(problems, "A4: unknown needs word 'sunny'")
	assert_string_contains(problems, "A5: the words have {rider} but the slots do not list it")
	assert_string_contains(problems, "A6: the slot 'rider' is listed but not in the words")
	assert_string_contains(problems, "A1: the id is used twice")
	assert_string_contains(problems, "A7: the level must be")
	assert_string_contains(problems, "A8: a brace")


func test_a_broken_file_is_an_empty_bank_with_its_reason() -> void:
	assert_string_contains("\n".join(CommentaryBank.from_json("{ not json").problems), "not valid JSON")
	assert_string_contains("\n".join(CommentaryBank.from_json(JSON.stringify({"format": 2, "lines": []})).problems), "format is 2")
	assert_string_contains("\n".join(CommentaryBank.load_file("res://nowhere.json").problems), "No commentary bank")


# ---------------------------------------------------------------- the words

func test_places_marks_and_legs_as_he_says_them() -> void:
	assert_eq(CommentaryWords.place_word(1), "first")
	assert_eq(CommentaryWords.place_word(12), "twelfth")
	assert_eq(CommentaryWords.place_word(25), "", "no word: the line is skipped")
	assert_eq(CommentaryWords.mark_word(1, 4), "first")
	assert_eq(CommentaryWords.mark_word(4, 4), "last")
	assert_eq(CommentaryWords.leg_word(1, 5), "first")
	assert_eq(CommentaryWords.leg_word(4, 5), "penultimate")
	assert_eq(CommentaryWords.leg_word(5, 5), "last")
	assert_eq(CommentaryWords.leg_word(1, 2), "first", "two legs: no penultimate")


func test_the_fleets_sail_colours_are_named_only_when_sure() -> void:
	var named: Dictionary[String, Color] = {
		"orange": Color(0.95, 0.55, 0.1), "blue": Color(0.2, 0.45, 0.9), "red": Color(0.85, 0.1, 0.15),
		"green": Color(0.3, 0.75, 0.25), "purple": Color(0.55, 0.2, 0.8), "yellow": Color(1.0, 0.85, 0.1),
		"brown": Color(0.35, 0.25, 0.15), "pink": Color(1.0, 0.6, 0.8), "light blue": Color(0.6, 0.85, 1.0),
		"turquoise": Color(0.1, 0.85, 0.75), "grey": Color(0.5, 0.5, 0.5), "white": Color(0.95, 0.95, 0.95),
	}
	for word: String in named:
		assert_eq(CommentaryWords.colour_word(named[word]), word, "%s" % named[word])
	assert_eq(CommentaryWords.colour_word(Color(0.95, 0.85, 0.6)), "", "a pale cream: not sure")
	assert_eq(CommentaryWords.colour_word(Color(0.15, 0.6, 0.7)), "", "between turquoise and blue: not sure")
	assert_eq(CommentaryWords.colour_word(Color.TRANSPARENT), "", "not known")


# ---------------------------------------------------------------- the director: which line

func test_the_needs_are_honoured() -> void:
	var director: CommentaryDirector = _director([
		_line("L1", "leader", "{rider} leads.", ["rider"], ["leader"]),
		_line("N1", "leader", "{rider} is behind.", ["rider"], ["not_leader"]),
		_line("P1", "leader", "In the money.", [], ["podium"]),
		_line("C1", "fight", "Close.", [], ["close"]),
		_line("W1", "camera", "Wide.", [], ["camera_wide"]),
		_line("M1", "filler", "A big fleet.", [], ["many"]),
		_line("R1", "fight", "{rider} and {rider2}.", ["rider", "rider2"], ["pair"]),
		_line("T1", "speed", "Last leg.", [], ["last_lap"]),
		_line("B1", "leader", "Clear.", [], ["big_lead"]),
	])
	var look: RaceLook = _look(30.0, [{"at": Vector2(0, -200)}, {"at": Vector2(0, -100)}, {"at": Vector2(0, 0)}, {"at": Vector2(0, 50)}])
	var line: Callable = func(id: String) -> CommentaryBank.Line: return director.bank.line(id)
	var leader: RaceMoment = RaceMoment.make("leader", 0)
	var fourth: RaceMoment = RaceMoment.make("leader", 3)
	assert_true(director.needs_met(line.call("L1"), leader, look))
	assert_false(director.needs_met(line.call("L1"), fourth, look))
	assert_true(director.needs_met(line.call("N1"), fourth, look))
	assert_false(director.needs_met(line.call("P1"), fourth, look), "fourth is off the podium")
	assert_true(director.needs_met(line.call("B1"), leader, look), "100 m clear of the second")
	var fight: RaceMoment = RaceMoment.make("fight", 0)
	assert_false(director.needs_met(line.call("C1"), fight, look))
	assert_false(director.needs_met(line.call("R1"), fight, look), "no second board")
	fight.close = true
	fight.board2 = 1
	assert_true(director.needs_met(line.call("C1"), fight, look))
	assert_true(director.needs_met(line.call("R1"), fight, look))
	assert_false(director.needs_met(line.call("W1"), RaceMoment.make("camera"), look))
	director.camera_wide = true
	assert_true(director.needs_met(line.call("W1"), RaceMoment.make("camera"), look))
	assert_false(director.needs_met(line.call("M1"), RaceMoment.make("filler"), look), "four boards are not many")
	assert_false(director.needs_met(line.call("T1"), RaceMoment.make("speed", 0), look))
	look.boards[0].next_step = 3
	assert_true(director.needs_met(line.call("T1"), RaceMoment.make("speed", 0), look), "sailing to the finish")


func test_the_slots_are_filled_or_the_line_is_skipped() -> void:
	var director: CommentaryDirector = _director([
		_line("F1", "identify", "{rider} in {place} on the {colour} {brand}, {leg} leg.", ["rider", "place", "colour", "brand", "leg"]),
		_line("F2", "chase", "{rider} after {rider2}.", ["rider", "rider2"]),
		_line("F3", "mark_approach", "{rider} at the {mark} mark.", ["rider", "mark"]),
	])
	var look: RaceLook = _look(30.0, [{}, {"brand": "Savanna"}])
	var moment: RaceMoment = RaceMoment.make("identify", 1)
	assert_eq(director.fill(director.bank.line("F1"), moment, look), "Hana in second on the orange Savanna, first leg.")
	look.boards[1].brand = ""
	assert_eq(director.fill(director.bank.line("F1"), moment, look), "", "no brand to say: skipped")
	look.boards[1].brand = "Savanna"
	look.boards[1].colour = Color(0.15, 0.6, 0.7)
	assert_eq(director.fill(director.bank.line("F1"), moment, look), "", "a colour not named for sure: skipped")
	assert_eq(director.fill(director.bank.line("F2"), RaceMoment.make("chase", 1), look), "", "no second board")
	var at_mark: RaceMoment = RaceMoment.make("mark_approach", 0)
	assert_eq(director.fill(director.bank.line("F3"), at_mark, look), "", "no mark word")
	at_mark.mark_word = "last"
	assert_eq(director.fill(director.bank.line("F3"), at_mark, look), "Mara at the last mark.")
	look.boards[0].name = ""
	assert_eq(director.fill(director.bank.line("F3"), at_mark, look), "", "a board whose name is not said (the player's)")


func test_no_line_twice_in_a_short_time_nor_the_same_words() -> void:
	var director: CommentaryDirector = _director([
		_line("S1", "filler", "Hardcore racing."),
		_line("S2", "filler", "Hardcore racing!"),
		_line("S3", "filler", "Look at them go."),
	])
	var look: RaceLook = _look(30.0, [{}, {}])
	var said: PackedStringArray = PackedStringArray()
	for k: int in 3:
		var pick: Dictionary = director.choose_line(RaceMoment.make("filler"), look)
		if pick.is_empty():
			break
		said.append(pick["text"])
		director.call("_start", RaceMoment.make("filler"), pick)
	assert_eq(said.size(), 2, "the third has the same words as one said: none left")
	assert_true(said.has("Look at them go."))
	assert_true(director.choose_line(RaceMoment.make("filler"), look).is_empty(), "nothing again soon")
	director.step(director.config.repeat_line_s + 1.0, look, null)
	assert_false(director.choose_line(RaceMoment.make("filler"), look).is_empty(), "after a while they may come again")


func test_the_least_used_line_comes_first_so_the_whole_bank_is_used() -> void:
	var config: CommentaryConfig = CommentaryConfig.new()
	config.repeat_line_s = 0.0
	config.repeat_words_s = 0.0
	var director: CommentaryDirector = _director([_line("U1", "filler", "One."), _line("U2", "filler", "Two."), _line("U3", "filler", "Three.")], config)
	var look: RaceLook = _look(30.0, [{}, {}])
	var seen: Dictionary[String, int] = {}
	for k: int in 9:
		var pick: Dictionary = director.choose_line(RaceMoment.make("filler"), look)
		director.call("_start", RaceMoment.make("filler"), pick)
		var id: String = (pick["line"] as CommentaryBank.Line).id
		seen[id] = seen.get(id, 0) + 1
	assert_eq(seen, {"U1": 3, "U2": 3, "U3": 3} as Dictionary[String, int], "each line three times in nine")


func test_a_staple_of_his_comes_more_often() -> void:
	var config: CommentaryConfig = CommentaryConfig.new()
	config.repeat_line_s = 0.0
	config.repeat_words_s = 0.0
	var staple: Dictionary = _line("C9", "filler", "Hardcore racing.")
	staple["count"] = 9
	var director: CommentaryDirector = _director([staple, _line("C1", "filler", "What a race.")], config)
	var look: RaceLook = _look(30.0, [{}, {}])
	var said: Dictionary[String, int] = {}
	for k: int in 12:
		var pick: Dictionary = director.choose_line(RaceMoment.make("filler"), look)
		director.call("_start", RaceMoment.make("filler"), pick)
		var id: String = (pick["line"] as CommentaryBank.Line).id
		said[id] = said.get(id, 0) + 1
	assert_between(said.get("C9", 0), 8, 10, "said 9 times to once in the streams: about three times as often (%s)" % [said])
	assert_between(said.get("C1", 0), 2, 4, "but the other line too")


func test_a_line_with_a_slot_comes_again_sooner_for_another_board() -> void:
	var director: CommentaryDirector = _director([_line("N1", "identify", "{rider}.", ["rider"])])
	var look: RaceLook = _look(30.0, [{}, {}])
	director.call("_start", RaceMoment.make("identify", 0), director.choose_line(RaceMoment.make("identify", 0), look))
	assert_true(director.choose_line(RaceMoment.make("identify", 1), look).is_empty(), "not straight away")
	director.step(director.config.repeat_slotted_line_s + 0.1, look, null)
	assert_eq(director.choose_line(RaceMoment.make("identify", 1), look)["text"], "Hana.", "another board soon after")
	assert_true(director.choose_line(RaceMoment.make("identify", 0), look).is_empty(), "the same words not yet")


func test_the_lines_level_fits_the_moment() -> void:
	var director: CommentaryDirector = _director([
		_line("V1", "finish_win", "{rider} wins.", ["rider"], [], 2),
		_line("V4", "finish_win", "{rider} WINS IT.", ["rider"], [], 4),
		_line("V3", "finish_win", "{rider} gets the bullet.", ["rider"], [], 3),
	])
	var look: RaceLook = _look(300.0, [{}, {}])
	assert_eq((director.choose_line(RaceMoment.make("finish_win", 0, 4), look)["line"] as CommentaryBank.Line).id, "V4", "a big moment: the shouted line")
	assert_eq((director.choose_line(RaceMoment.make("finish_win", 0, 2), look)["line"] as CommentaryBank.Line).id, "V1", "a calm one: the calm line")
	assert_eq((director.choose_line(RaceMoment.make("finish_win", 0, 3), look)["line"] as CommentaryBank.Line).id, "V3")


# ---------------------------------------------------------------- the director: when

func test_one_voice_at_a_time_with_a_breath_between_lines() -> void:
	var config: CommentaryConfig = CommentaryConfig.new()
	config.pause_min_s = 1.0
	config.pause_max_s = 1.0
	var director: CommentaryDirector = _director([
		_line("O1", "overtake", "{rider} goes past.", ["rider"], [], 2, 2.0),
		_line("O2", "overtake", "And {rider} too.", ["rider"], [], 2, 2.0),
	], config)
	var look: RaceLook = _look(60.0, [{}, {}, {}])
	var started: Array[String] = []
	director.line_started.connect(func(id: String, _text: String, _seconds: float, _level: int) -> void: started.append(id))
	director.hear([RaceMoment.make("overtake", 1), RaceMoment.make("overtake", 2)])
	assert_true(director.step(0.1, look, null), "the first line at once")
	for k: int in 28:
		director.step(0.1, look, null)
	assert_eq(started.size(), 1, "2 s of words and 1 s to breathe: not yet")
	for k: int in 3:
		director.step(0.1, look, null)
	assert_eq(started.size(), 2, "then the next")


func test_a_big_moment_cuts_in_over_small_talk_and_a_small_one_waits() -> void:
	var director: CommentaryDirector = _director([
		_line("I1", "identify", "You've got {rider} in the middle.", ["rider"], [], 2, 3.0),
		_line("X1", "lead_change", "It's {rider} that's now taking the lead.", ["rider"], [], 3, 2.0),
		_line("G1", "gybe_safe", "Rounds safely.", [], [], 2, 1.0),
	])
	var look: RaceLook = _look(60.0, [{}, {}, {}])
	var stopped: Array[String] = []
	director.line_stopped.connect(func(id: String) -> void: stopped.append(id))
	director.focus = 2
	var story: RaceStory = RaceStory.new(director.config)
	assert_true(director.step(5.0, look, story), "small talk about the board on the screen")
	assert_eq(director.saying_id, "I1")
	assert_eq(director.saying_text, "You've got Kofi in the middle.")
	director.hear([RaceMoment.make("gybe_safe", 1, 1)])
	director.step(0.1, look, story)
	assert_eq(director.saying_id, "I1", "a routine rounding waits")
	director.hear([RaceMoment.make("lead_change", 1, 3)])
	director.step(0.1, look, story)
	assert_eq(director.saying_id, "X1", "the lead change cuts in")
	assert_eq(stopped, ["I1"] as Array[String])


func test_a_moment_too_late_for_its_line_is_dropped_not_said_late() -> void:
	var config: CommentaryConfig = CommentaryConfig.new()
	config.late_s["overtake"] = 2.0
	var director: CommentaryDirector = _director([
		_line("Y1", "fight", "A long line about a fight that goes on and on.", [], [], 2, 6.0),
		_line("Y2", "overtake", "{rider} goes past.", ["rider"]),
	], config)
	var look: RaceLook = _look(60.0, [{}, {}])
	director.hear([RaceMoment.make("fight", 0)])
	director.step(0.1, look, null)
	director.hear([RaceMoment.make("overtake", 1)])
	for k: int in 80:
		director.step(0.1, look, null)
	assert_eq(director.counts["late"], 1, "the overtake waited 2 s, then went")
	assert_eq(director.counts["said"], 1, "never said late")


func test_the_bigger_moment_and_the_board_on_the_screen_go_first() -> void:
	var director: CommentaryDirector = _director([
		_line("Z1", "fall", "{rider}'s gone.", ["rider"]),
		_line("Z2", "overtake", "{rider} goes past.", ["rider"]),
		_line("Z3", "chase", "{rider} closing.", ["rider"]),
		_line("Z4", "fight", "{rider} in a fight.", ["rider"]),
	])
	var look: RaceLook = _look(60.0, [{}, {}, {}, {}])
	director.hear([RaceMoment.make("overtake", 1), RaceMoment.make("fall", 2)])
	director.step(0.1, look, null)
	assert_eq(director.saying_id, "Z1", "a fall before an overtake")
	var other: CommentaryDirector = _director(director.bank.lines.map(func(l: CommentaryBank.Line) -> Dictionary: return _line(l.id, l.moment, l.text, l.slots)))
	other.focus = 3
	other.hear([RaceMoment.make("chase", 1), RaceMoment.make("fight", 3)])
	other.step(0.1, look, null)
	assert_eq(other.saying_id, "Z4", "the fight on the screen before a chase elsewhere")


func test_a_rundown_goes_down_the_order_and_stops_for_news() -> void:
	var config: CommentaryConfig = CommentaryConfig.new()
	config.quiet_weight = {"rundown": 1.0}
	config.rundown_places = 4
	var director: CommentaryDirector = _director([
		_line("D1", "rundown", "So {rider} in {place}.", ["rider", "place"], [], 2, 1.0),
		_line("D2", "rundown", "Then we've got {rider}.", ["rider"], ["not_leader"], 2, 1.0),
		_line("D3", "rundown", "{rider} in {place} place.", ["rider", "place"], [], 2, 1.0),
		_line("D4", "rundown", "He's right up there.", [], ["not_leader"], 2, 1.0),
		_line("E1", "fall", "{rider}'s gone.", ["rider"], [], 2, 1.0),
	], config)
	var look: RaceLook = _look(60.0, [{}, {}, {}, {}, {}])
	var story: RaceStory = RaceStory.new(config)
	var said: Array[String] = []
	director.line_started.connect(func(_id: String, text: String, _seconds: float, _level: int) -> void: said.append(text))
	director.step(5.0, look, story)
	for k: int in 30:
		director.step(0.1, look, story)
	assert_eq(said.size(), 3, "three boards down the order (each line names its board)")
	assert_string_contains(said[0], "Mara")
	assert_string_contains(said[1], "Hana")
	assert_string_contains(said[2], "Kofi")
	director.hear([RaceMoment.make("fall", 4)])
	for k: int in 30:
		director.step(0.1, look, story)
	assert_eq(said[3], "Sven's gone.", "the fall stops the rundown")
	assert_eq(said.size(), 4, "and the rundown does not go on")


func test_his_reaction_comes_first_and_the_line_straight_after() -> void:
	var config: CommentaryConfig = CommentaryConfig.new()
	config.reaction_chance = 1.0
	config.pair_gap_s = 0.15
	var director: CommentaryDirector = _director([
		_line("W1", "wow", "Wow.", [], [], 3, 0.6),
		_line("H1", "oh_no", "Oh no.", [], [], 3, 0.6),
		_line("K1", "lead_change", "It's {rider} that's now taking the lead.", ["rider"], [], 3, 2.0),
		_line("K2", "fall", "{rider}'s gone.", ["rider"], [], 3, 1.5),
		_line("K3", "overtake", "{rider} goes past.", ["rider"], [], 2, 1.5),
	], config)
	var look: RaceLook = _look(60.0, [{}, {}, {}])
	var said: Array[String] = []
	director.line_started.connect(func(_id: String, text: String, _seconds: float, _level: int) -> void: said.append(text))
	director.hear([RaceMoment.make("lead_change", 1, 3)])
	director.step(0.1, look, null)
	for k: int in 10:
		director.step(0.1, look, null)
	assert_eq(said, ["Wow.", "It's Hana that's now taking the lead."] as Array[String], "the pair, no breath between")
	for k: int in 40:
		director.step(0.1, look, null)
	director.hear([RaceMoment.make("fall", 2, 3)])
	for k: int in 10:
		director.step(0.1, look, null)
	assert_eq(said.slice(2), ["Oh no.", "Kofi's gone."] as Array[String])
	for k: int in 40:
		director.step(0.1, look, null)
	director.hear([RaceMoment.make("overtake", 2, 2)])
	for k: int in 10:
		director.step(0.1, look, null)
	assert_eq(said.slice(4), ["Kofi goes past."] as Array[String], "a small moment: no reaction")


func test_a_rundown_place_said_on_its_own_is_followed_by_the_name() -> void:
	var config: CommentaryConfig = CommentaryConfig.new()
	config.quiet_weight = {"rundown": 1.0}
	config.rundown_places = 2
	var director: CommentaryDirector = _director([
		_line("R1", "rundown", "{place}.", ["place"], [], 2, 0.6),
		_line("R2", "rundown", "{place} place.", ["place"], [], 2, 0.8),
		_line("N1", "identify", "{rider}.", ["rider"], [], 2, 0.5),
		_line("N2", "identify", "Who's on that?", [], [], 2, 0.5),
	], config)
	var look: RaceLook = _look(60.0, [{}, {}, {}])
	var said: Array[String] = []
	director.line_started.connect(func(_id: String, text: String, _seconds: float, _level: int) -> void: said.append(text))
	director.step(5.0, look, RaceStory.new(config))
	for k: int in 40:
		director.step(0.1, look, RaceStory.new(config))
	assert_eq(said.size(), 3, "a place, its name, the next place (one name line: not twice soon)")
	assert_eq(said[1], "Mara.", "the board in that place named, not the line without a name")
	assert_true(said[0] == "First." or said[0] == "First place.")


func test_a_line_with_a_slot_the_game_cannot_fill_yet_is_skipped() -> void:
	var director: CommentaryDirector = _director([
		_line("Q1", "identify", "The {national} on the {nation_adj} board.", ["national", "nation_adj"]),
		_line("Q2", "identify", "{rider}.", ["rider"]),
	])
	var pick: Dictionary = director.choose_line(RaceMoment.make("identify", 0), _look(60.0, [{}, {}]))
	assert_eq((pick["line"] as CommentaryBank.Line).id, "Q2")


# ---------------------------------------------------------------- the race story

func test_the_first_look_only_takes_note() -> void:
	var story: RaceStory = RaceStory.new(CommentaryConfig.new())
	assert_eq(story.look(_look(30.0, [{"fallen": true}, {}])).size(), 0, "a board already down is not news")
	assert_eq(story.look(_look(30.1, [{"fallen": true}, {}])).size(), 0)


func test_the_fleet_lining_up_and_the_gun() -> void:
	var story: RaceStory = RaceStory.new(CommentaryConfig.new())
	story.look(_look(-55.0, [{"step": 0}, {"step": 0}]))
	assert_eq(_names_of(story.look(_look(-49.9, [{"step": 0}, {"step": 0}]))), ["pre_start"] as Array[String])
	assert_eq(_names_of(story.look(_look(-49.8, [{"step": 0}, {"step": 0}]))), [] as Array[String])
	var gun: Array[RaceMoment] = story.look(_look(0.05, [{"step": 0, "ocs": true}, {"step": 0}]))
	assert_eq(_names_of(gun), ["start_gun", "over_early"] as Array[String])
	assert_eq(gun[1].board, 0)


func test_a_good_start_and_a_bad_start() -> void:
	var story: RaceStory = RaceStory.new(CommentaryConfig.new())
	var boards: Array[Dictionary] = [{"start_s": 2.0}, {"start_s": 1.0, "planing": false}, {"step": 0, "start_s": -1.0, "at": Vector2(0, 40)}]
	story.look(_look(7.9, boards))
	var judged: Array[RaceMoment] = story.look(_look(8.0, boards))
	assert_eq(_names_of(judged), ["start_good", "start_bad"] as Array[String])
	assert_eq(judged[0].board, 0, "the first over the line planing")
	assert_eq(judged[1].board, 2, "not over the line 8 s after the gun")


func test_a_lead_change_once_the_new_leader_has_held() -> void:
	var story: RaceStory = RaceStory.new(CommentaryConfig.new())
	story.look(_look(30.0, [{}, {}]))
	story.look(_look(30.5, [{"place": 2}, {"place": 1}]))
	assert_eq(_names_of(story.look(_look(31.0, [{"place": 2}, {"place": 1}]))), [] as Array[String], "not yet held")
	var told: Array[RaceMoment] = story.look(_look(33.1, [{"place": 2}, {"place": 1}]))
	assert_eq(_names_of(told), ["lead_change"] as Array[String])
	assert_eq(told[0].board, 1)
	assert_eq(told[0].board2, 0, "the old leader")
	assert_eq(_names_of(story.look(_look(40.0, [{"place": 2}, {"place": 1}]))), [] as Array[String], "told once")


func test_a_brief_swap_in_the_order_is_no_overtake() -> void:
	var story: RaceStory = RaceStory.new(CommentaryConfig.new())
	story.look(_look(30.0, [{}, {}, {}]))
	story.look(_look(31.0, [{}, {"place": 3}, {"place": 2}]))
	story.look(_look(32.0, [{}, {}, {}]))
	assert_eq(_names_of(story.look(_look(36.0, [{}, {}, {}]))), [] as Array[String])


func test_an_overtake_names_the_board_passed() -> void:
	var story: RaceStory = RaceStory.new(CommentaryConfig.new())
	story.look(_look(30.0, [{}, {}, {}]))
	story.look(_look(31.0, [{}, {"place": 3}, {"place": 2}]))
	var told: Array[RaceMoment] = story.look(_look(34.0, [{}, {"place": 3}, {"place": 2}]))
	assert_eq(_names_of(told), ["overtake"] as Array[String])
	assert_eq(told[0].board, 2)
	assert_eq(told[0].board2, 1)
	assert_eq(told[0].place, 2)


func test_nothing_in_the_order_is_told_in_the_starts_shuffle() -> void:
	var story: RaceStory = RaceStory.new(CommentaryConfig.new())
	story.look(_look(2.0, [{}, {}]))
	story.look(_look(3.0, [{"place": 2}, {"place": 1}]))
	var told: Array[String] = _names_of(story.look(_look(10.0, [{"place": 2}, {"place": 1}])))
	assert_false(told.has("lead_change") or told.has("overtake"), "%s" % [told])


func test_a_chase_is_a_board_closing_on_the_one_ahead() -> void:
	var story: RaceStory = RaceStory.new(CommentaryConfig.new())
	var told: Array[String] = []
	for k: int in 21:
		var gap_m: float = 45.0 - k * 1.0
		for moment: RaceMoment in story.look(_look(30.0 + k * 0.5, [{"at": Vector2(0, -200)}, {"at": Vector2(0, -200 + gap_m)}])):
			told.append(moment.moment)
	assert_eq(told, ["chase"] as Array[String], "8 m nearer within 8 s, told once")


func test_a_fight_is_two_boards_close_for_a_while() -> void:
	var story: RaceStory = RaceStory.new(CommentaryConfig.new())
	var told: Array[RaceMoment] = []
	for k: int in 20:
		told.append_array(story.look(_look(30.0 + k * 0.5, [{"at": Vector2(0, -200)}, {"at": Vector2(8, -195)}])))
	assert_eq(_names_of(told), ["fight"] as Array[String])
	assert_eq(told[0].board, 0, "the board ahead holds off the other")
	assert_eq(told[0].board2, 1)
	assert_eq(told[0].place, 1, "the battle for first")
	assert_true(told[0].close)


func test_a_fall_is_told_once_and_bigger_for_the_leader() -> void:
	var story: RaceStory = RaceStory.new(CommentaryConfig.new())
	story.look(_look(30.0, [{}, {}, {}, {}]))
	var falls: Array[RaceMoment] = story.look(_look(30.1, [{"fallen": true}, {}, {}, {"fallen": true}]))
	assert_eq(_names_of(falls), ["fall", "fall"] as Array[String])
	assert_eq(falls[0].level, 4, "the leader down")
	assert_eq(falls[1].level, 2, "fourth down")
	assert_eq(story.look(_look(30.2, [{"fallen": true}, {}, {}, {"fallen": true}])).size(), 0, "told once")


func test_trouble_is_a_board_off_the_plane_while_the_fleet_planes() -> void:
	var story: RaceStory = RaceStory.new(CommentaryConfig.new())
	var told: Array[RaceMoment] = []
	for k: int in 9:
		told.append_array(story.look(_look(40.0 + k * 0.5, [{}, {"planing": false, "speed": 4.0}, {}])))
	assert_eq(_names_of(told), ["trouble"] as Array[String], "3 s off the plane while the others plane")
	assert_eq(told[0].board, 1)
	var lull: RaceStory = RaceStory.new(CommentaryConfig.new())
	told.clear()
	for k: int in 9:
		told.append_array(lull.look(_look(40.0 + k * 0.5, [{"planing": false}, {"planing": false}, {}])))
	assert_eq(told.size(), 0, "most of the fleet off the plane: a lull, not trouble")


func test_trouble_is_a_board_losing_places_quickly_without_a_fall() -> void:
	var story: RaceStory = RaceStory.new(CommentaryConfig.new())
	story.look(_look(30.0, [{}, {}, {}]))
	var told: Array[RaceMoment] = []
	told.append_array(story.look(_look(31.0, [{"place": 3}, {"place": 1}, {"place": 2}])))
	told.append_array(story.look(_look(34.0, [{"place": 3}, {"place": 1}, {"place": 2}])))
	assert_true(_names_of(told).has("trouble"), "first to third")
	var trouble: RaceMoment = told.filter(func(m: RaceMoment) -> bool: return m.moment == "trouble")[0]
	assert_eq(trouble.board, 0)
	assert_eq(trouble.level, 3, "it was at the front")
	assert_eq(trouble.note, "down from first to third")


func test_a_near_miss_is_two_boards_closing_fast_not_two_side_by_side() -> void:
	var story: RaceStory = RaceStory.new(CommentaryConfig.new())
	story.look(_look(30.0, [{"at": Vector2(0, -200), "heading": 0.0}, {"at": Vector2(3, -200), "heading": 0.0}]))
	assert_false(_names_of(story.look(_look(30.1, [{"at": Vector2(0, -200), "heading": 0.0}, {"at": Vector2(3, -200), "heading": 0.0}]))).has("near_miss"), "side by side, the same way")
	var crossing: Array[RaceMoment] = story.look(_look(30.2, [{"at": Vector2(0, -200), "heading": 90.0}, {"at": Vector2(2, -202), "heading": 0.0}]))
	assert_eq(_names_of(crossing).count("near_miss"), 1, "crossing 3 m apart at 10 m/s each")


func test_airtime_after_a_clean_landing_and_not_after_a_fall() -> void:
	var story: RaceStory = RaceStory.new(CommentaryConfig.new())
	var told: Array[String] = []
	var water: PackedFloat32Array = [1.0, 0.02, 0.01, 0.03, 0.02, 0.01, 0.02, 1.0, 1.0]
	for k: int in water.size():
		for moment: RaceMoment in story.look(_look(30.0 + k * 0.1, [{"water": water[k]}, {}])):
			told.append(moment.moment)
	assert_eq(told, [] as Array[String], "not until it is clear it landed it")
	for moment: RaceMoment in story.look(_look(31.8, [{}, {}])):
		told.append(moment.moment)
	assert_eq(told, ["airtime"] as Array[String])
	var crash: RaceStory = RaceStory.new(CommentaryConfig.new())
	told.clear()
	for k: int in water.size():
		crash.look(_look(30.0 + k * 0.1, [{"water": water[k]}, {}]))
	for moment: RaceMoment in crash.look(_look(31.8, [{"fallen": true}, {}])):
		told.append(moment.moment)
	assert_eq(told, ["fall"] as Array[String], "it fell on landing: a fall, no airtime")


func test_the_front_coming_up_to_a_mark() -> void:
	var story: RaceStory = RaceStory.new(CommentaryConfig.new())
	story.look(_look(60.0, [{"at": Vector2(0, -200)}, {"at": Vector2(0, -150)}]))
	var told: Array[RaceMoment] = story.look(_look(60.1, [{"at": Vector2(0, -240)}, {"at": Vector2(0, -150)}]))
	assert_eq(_names_of(told), ["mark_approach"] as Array[String])
	assert_eq(told[0].mark_word, "first")
	assert_eq(story.look(_look(60.2, [{"at": Vector2(0, -250)}, {"at": Vector2(0, -150)}])).size(), 0, "once per mark")


func test_a_gybe_is_judged_good_safe_or_bad_from_the_rounding() -> void:
	var config: CommentaryConfig = CommentaryConfig.new()
	var rounding: RaceStory.Rounding = RaceStory.Rounding.new()
	rounding.stern_crossed = true
	rounding.speed_in_ms = 10.0
	rounding.planing_in = true
	rounding.widest_twa_deg = 170.0
	rounding.least_ms = 8.5
	rounding.nearest_m = 6.0
	assert_eq(RaceStory.judge_the_gybe(rounding, config).moment, "gybe_good", "kept 85 %, tight, planing")
	rounding.nearest_m = 18.0
	assert_eq(RaceStory.judge_the_gybe(rounding, config).moment, "gybe_safe", "a little wide")
	rounding.nearest_m = 25.0
	assert_eq(RaceStory.judge_the_gybe(rounding, config).moment, "gybe_bad", "wide")
	rounding.nearest_m = 6.0
	rounding.least_ms = 4.0
	assert_eq(RaceStory.judge_the_gybe(rounding, config).moment, "gybe_safe", "kept 40 %: off the plane, not stopped")
	rounding.least_ms = 1.0
	assert_eq(RaceStory.judge_the_gybe(rounding, config).moment, "gybe_bad", "all but stopped")
	rounding.least_ms = 8.5
	rounding.off_plane_s = 2.5
	assert_eq(RaceStory.judge_the_gybe(rounding, config).moment, "gybe_safe", "fast but long off the plane: not good")
	rounding.off_plane_s = 0.0
	rounding.stern_crossed = false
	assert_null(RaceStory.judge_the_gybe(rounding, config), "the stern never went through the wind (a bear-away, a tack): no gybe")
	rounding.stern_crossed = true
	rounding.fell = true
	assert_null(RaceStory.judge_the_gybe(rounding, config), "a fall is told as a fall")


func test_a_rounding_watched_through_the_mark_ends_in_a_gybe_line() -> void:
	var story: RaceStory = RaceStory.new(CommentaryConfig.new())
	var told: Array[RaceMoment] = []
	# Mark 1 at (0, -300): in from the south at 10 m/s, round it to the east, out at 9 m/s, the sail across.
	var path: Array[Dictionary] = [
		{"at": Vector2(0, -250), "speed": 10.0, "side": 1, "twa": 140.0},
		{"at": Vector2(0, -270), "speed": 10.0, "side": 1, "twa": 150.0},
		{"at": Vector2(0, -292), "speed": 9.0, "side": 1, "twa": 170.0},
		{"at": Vector2(5, -302), "speed": 8.6, "side": -1, "twa": -175.0},
		{"at": Vector2(20, -305), "speed": 8.8, "side": -1, "twa": -150.0, "step": 2},
		{"at": Vector2(40, -305), "speed": 9.0, "side": -1, "twa": -140.0, "step": 2},
		{"at": Vector2(60, -305), "speed": 9.0, "side": -1, "twa": -140.0, "step": 2},
		{"at": Vector2(80, -305), "speed": 9.0, "side": -1, "twa": -140.0, "step": 2},
	]
	for k: int in path.size():
		told.append_array(story.look(_look(60.0 + k * 1.0, [path[k], {"at": Vector2(400, 0)}])))
	assert_eq(_names_of(told).filter(func(name: String) -> bool: return name.begins_with("gybe")), ["gybe_good"] as Array[String])
	var gybe: RaceMoment = told.filter(func(m: RaceMoment) -> bool: return m.moment == "gybe_good")[0]
	assert_eq(gybe.board, 0)
	assert_eq(gybe.mark_word, "first")
	assert_string_contains(gybe.note, "kept 86 %")


func test_the_last_leg_the_winner_the_places_and_a_photo_finish() -> void:
	var story: RaceStory = RaceStory.new(CommentaryConfig.new())
	story.look(_look(200.0, [{"step": 2}, {"step": 2}, {"step": 2}]))
	assert_eq(_names_of(story.look(_look(201.0, [{"step": 3, "at": Vector2(200, -100)}, {"step": 2}, {"step": 2}]))), ["last_leg"] as Array[String])
	var photo: Array[RaceMoment] = story.look(_look(230.0, [{"step": 3, "at": Vector2(200, -150)}, {"step": 3, "at": Vector2(195, -40)}, {"step": 3, "at": Vector2(198, -36)}]))
	assert_eq(_names_of(photo), ["photo_finish"] as Array[String], "second and third 40 m out, 5 m apart")
	assert_eq(photo[0].place, 2)
	var finish: Array[RaceMoment] = story.look(_look(240.0, [{"step": 4, "finished": true, "finish_s": 239.0}, {"step": 4, "finished": true, "finish_s": 239.5}, {"step": 3, "at": Vector2(200, -5)}]))
	assert_eq(_names_of(finish), ["finish_win", "finish_place", "photo_finish"] as Array[String], "the first two crossed 0.5 s apart")
	assert_eq(finish[1].place, 2)
	var after: Array[RaceMoment] = story.look(_look(248.5, [{"step": 4, "finished": true, "finish_s": 239.0}, {"step": 4, "finished": true, "finish_s": 239.5}, {"step": 4, "finished": true, "finish_s": 248.4}]))
	assert_eq(_names_of(after), ["finish_place", "after_race"] as Array[String])


func test_the_small_talk_offered_is_about_the_board_on_the_screen() -> void:
	var story: RaceStory = RaceStory.new(CommentaryConfig.new())
	var look: RaceLook = _look(60.0, [{"speed": 10.0}, {"speed": 10.0}, {"speed": 12.0}])
	var offered: Array[RaceMoment] = story.quiet(look, 2, false)
	var kinds: Array[String] = _names_of(offered)
	for kind: String in ["identify", "speed", "leader", "rundown", "filler", "camera"]:
		assert_true(kinds.has(kind), kind)
	assert_false(kinds.has("unsure"), "only on a wide shot")
	assert_eq(offered[kinds.find("identify")].board, 2)
	assert_eq(offered[kinds.find("speed")].board, 2, "the fastest board is on the screen")
	assert_eq(offered[kinds.find("leader")].board, 0)
	assert_true(_names_of(story.quiet(look, 2, true)).has("unsure"))
	assert_false(_names_of(story.quiet(look, 0, false)).has("speed"), "the leader is not faster than the rest")
	assert_true(kinds.has("conditions"), "the day can always be talked about")
	assert_false(kinds.has("tactics"), "nothing to say about its line")


func test_tactics_to_windward_of_the_board_beside_it() -> void:
	var story: RaceStory = RaceStory.new(CommentaryConfig.new())
	# The wind from the north (-Z): Mara 10 m higher than Hana, 11 m apart.
	var look: RaceLook = _look(60.0, [{"at": Vector2(0, -200)}, {"at": Vector2(5, -190)}])
	var line: RaceMoment = story.tactics_of(look, 0)
	assert_not_null(line)
	assert_eq(line.windward, 1)
	assert_eq(line.board2, 1)
	assert_false(line.dirty)
	assert_eq(story.tactics_of(look, 1).windward, -1, "Hana below Mara")
	assert_true(_names_of(story.quiet(look, 0, false)).has("tactics"))


func test_tactics_in_dirty_wind_and_off_the_straight_line() -> void:
	var story: RaceStory = RaceStory.new(CommentaryConfig.new())
	var dirty: RaceLook = _look(60.0, [{"at": Vector2(0, -200), "dirty": 0.05}, {"at": Vector2(0, 100)}])
	assert_true(story.tactics_of(dirty, 0).dirty, "5 % of its wind gone")
	assert_null(story.tactics_of(_look(60.0, [{"at": Vector2(0, -200), "dirty": 0.02}, {"at": Vector2(0, 100)}]), 0), "2 %: clear enough")
	# On the leg from mark 1 (0, -300) to mark 2 (200, -300), 30 m below it.
	var low: RaceLook = _look(90.0, [{"at": Vector2(100, -270), "step": 2}, {"at": Vector2(0, 100)}])
	assert_eq(low.line_offset_m(0), -30.0)
	assert_eq(story.tactics_of(low, 0).windward, -1, "a lower line")


func test_tension_a_small_gap_for_the_lead_late_in_the_race() -> void:
	var story: RaceStory = RaceStory.new(CommentaryConfig.new())
	var close: RaceLook = _look(200.0, [{"step": 3, "at": Vector2(200, -150)}, {"step": 3, "at": Vector2(200, -130)}, {"step": 3, "at": Vector2(200, -60)}])
	var moment: RaceMoment = story.tension_of(close)
	assert_not_null(moment, "20 m at 10 m/s: 2 s")
	assert_eq(moment.board, 0)
	assert_eq(moment.board2, 1)
	assert_eq(moment.place, 1)
	assert_null(story.tension_of(_look(200.0, [{"step": 3, "at": Vector2(200, -150)}, {"step": 3, "at": Vector2(200, -90)}, {"step": 3, "at": Vector2(200, -60)}])), "6 s: not close")
	assert_null(story.tension_of(_look(60.0, [{"step": 1, "at": Vector2(0, -200)}, {"step": 1, "at": Vector2(0, -180)}, {"step": 1}])), "early in the race")
	var podium: RaceMoment = story.tension_of(_look(200.0, [{"step": 3, "at": Vector2(200, -250)}, {"step": 3, "at": Vector2(200, -200)}, {"step": 3, "at": Vector2(200, -150)}, {"step": 3, "at": Vector2(200, -135)}]))
	assert_eq(podium.place, 3, "the last place on the podium")


func test_form_a_long_lead_or_a_run_of_places() -> void:
	var story: RaceStory = RaceStory.new(CommentaryConfig.new())
	var boards: Array[Dictionary] = [{}, {}, {}, {}]
	story.look(_look(20.0, boards))
	assert_null(story.form_of(_look(40.0, boards), 0), "leading 20 s")
	story.look(_look(90.0, boards))
	assert_eq(story.form_of(_look(90.0, boards), 0).note, "leading for 70 s")
	var running: RaceStory = RaceStory.new(CommentaryConfig.new())
	running.look(_look(30.0, boards))
	var passed: Array[Dictionary] = [{"place": 1}, {"place": 3}, {"place": 4}, {"place": 2}]
	running.look(_look(31.0, passed))
	running.look(_look(34.0, passed))
	assert_eq(running.form_of(_look(34.0, passed), 3).note, "up 2 places in 60 s")
	assert_null(running.form_of(_look(34.0, passed), 1), "down, not up")


func test_the_days_wind_and_water_for_the_conditions_needs() -> void:
	var director: CommentaryDirector = _director([
		_line("D1", "conditions", "It's absolutely howling out there.", [], ["wind_strong"]),
		_line("D2", "conditions", "Light today.", [], ["wind_light"]),
		_line("D3", "conditions", "So choppy and so long.", [], ["choppy"]),
		_line("D4", "conditions", "Flat as a pond.", [], ["flat"]),
	])
	var line: Callable = func(id: String) -> CommentaryBank.Line: return director.bank.line(id)
	var story: RaceStory = RaceStory.new(director.config)
	var look: RaceLook = null
	for k: int in 40:
		look = _look(-40.0 + k * 0.5, [{"step": 0, "water_h": 0.15 if k % 2 == 0 else -0.15}, {"step": 0, "water_h": -0.15 if k % 2 == 0 else 0.15}])
		look.wind_kt = 25.0
		story.look(look)
	var moment: RaceMoment = RaceMoment.make("conditions")
	assert_almost_eq(look.wind_mean_kt, 25.0, 0.01)
	assert_true(director.needs_met(line.call("D1"), moment, look), "25 kt: howling")
	assert_false(director.needs_met(line.call("D2"), moment, look))
	assert_true(look.sea_hs_m > 0.3, "the water up and down 0.15 m: about 0.6 m significant (%.2f)" % look.sea_hs_m)
	assert_true(director.needs_met(line.call("D3"), moment, look))
	assert_false(director.needs_met(line.call("D4"), moment, look))
	var calm: RaceStory = RaceStory.new(director.config)
	for k: int in 40:
		look = _look(-40.0 + k * 0.5, [{"step": 0}, {"step": 0}])
		look.wind_kt = 11.0
		calm.look(look)
	assert_true(director.needs_met(line.call("D2"), moment, look), "11 kt: light")
	assert_true(director.needs_met(line.call("D4"), moment, look), "no waves: flat")
	assert_false(director.needs_met(line.call("D1"), moment, look))


func test_the_tactics_needs() -> void:
	var director: CommentaryDirector = _director([
		_line("T1", "tactics", "Pushing hard above {rider2} though.", ["rider2"], ["windward", "pair"]),
		_line("T2", "tactics", "He's got a lower line.", [], ["leeward"]),
		_line("T3", "tactics", "Oh and he's got some dirty air there.", [], ["dirty_air"]),
	])
	var look: RaceLook = _look(60.0, [{}, {}])
	var line: Callable = func(id: String) -> CommentaryBank.Line: return director.bank.line(id)
	var above: RaceMoment = RaceMoment.make("tactics", 0)
	above.windward = 1
	above.board2 = 1
	assert_true(director.needs_met(line.call("T1"), above, look))
	assert_false(director.needs_met(line.call("T2"), above, look))
	assert_false(director.needs_met(line.call("T3"), above, look))
	assert_eq(director.fill(line.call("T1"), above, look), "Pushing hard above Hana though.")
	var shadowed: RaceMoment = RaceMoment.make("tactics", 0)
	shadowed.dirty = true
	shadowed.windward = -1
	assert_true(director.needs_met(line.call("T2"), shadowed, look))
	assert_true(director.needs_met(line.call("T3"), shadowed, look))


# ---------------------------------------------------------------- the race as the commentator sees it

func test_the_look_of_a_real_race() -> void:
	var race: RaceSim = RaceSim.new(RaceCourses.t1_loop(0.0, Vector2.ZERO), 1, 10.0)
	race.add_board("Mara")
	race.add_board("Hana")
	race.update_board(0, Vector2(0, 30))
	race.update_board(1, Vector2(0, 20))
	race.start()
	race.step(0.1)
	var telemetry: Array[Telemetry] = [Telemetry.new(), null]
	telemetry[0].speed_ms = 7.0
	telemetry[0].total_mass_kg = 100.0
	telemetry[0].buoyancy_n = 490.5
	var look: RaceLook = RaceLook.of_race(race, telemetry, PackedStringArray(["", "Hana"]), PackedStringArray(["Point.9"]), PackedColorArray([ORANGE]))
	assert_true(look.started)
	assert_false(look.racing)
	assert_almost_eq(look.clock_s, -9.9, 1e-4)
	assert_eq(look.boards.size(), 2)
	assert_false(look.boards[1].present, "no telemetry: not on the water")
	assert_eq(look.order, [0] as Array[int])
	assert_eq(look.boards[0].place, 1)
	assert_eq(look.boards[0].brand, "Point.9")
	assert_eq(look.name_of(0), "board 0", "a board without a name to say")
	assert_almost_eq(look.boards[0].water_share, 0.5, 1e-6)
	assert_eq(look.step_count(), race.steps().size())


# ---------------------------------------------------------------- the game's parts

func test_the_config_knows_every_moment() -> void:
	var config: CommentaryConfig = load(Commentary.CONFIG_PATH)
	assert_not_null(config)
	for moment: String in CommentaryBank.MOMENTS:
		assert_true(config.priority.has(moment), "%s has a priority" % moment)
	for moment: String in config.priority:
		assert_true(CommentaryBank.MOMENTS.has(moment), "%s is a moment" % moment)
	for moment: String in config.late_s:
		assert_true(CommentaryBank.MOMENTS.has(moment), "%s is a moment" % moment)
	for moment: String in CommentaryDirector.QUIET_MOMENTS:
		assert_true(config.quiet_weight.has(moment), "%s has a weight" % moment)
		assert_true(config.quiet_again_s.has(moment), "%s has a time before it comes again" % moment)
	assert_eq(config.pre_start_at_s.size(), 3)


func test_the_shots_are_wide_or_close() -> void:
	assert_true(Commentary.is_wide(TvCamera.Shot.ORBIT))
	assert_true(Commentary.is_wide(TvCamera.Shot.COMMITTEE))
	assert_true(Commentary.is_close(TvCamera.Shot.CHASE))
	assert_true(Commentary.is_close(TvCamera.Shot.GROUP))
	assert_false(Commentary.is_wide(TvCamera.Shot.MARK) or Commentary.is_close(TvCamera.Shot.MARK), "the mark's drone: neither")


func test_watch_mode_has_a_key_for_the_commentary() -> void:
	var keys: Array[String] = []
	for key: Array in WatchMode.KEYS:
		keys.append(str(key[0]))
	assert_true(keys.has("V, Shift+V"), "V: the commentary; Shift+V: its voice")
	var with_v: int = 0
	for key: String in keys:
		if key.begins_with("V"):
			with_v += 1
	assert_eq(with_v, 1)


func test_the_transcripts_clock() -> void:
	assert_eq(CommentaryRun.clock(-52.34), "-0:52.3")
	assert_eq(CommentaryRun.clock(187.9), "3:07.9")


# ---------------------------------------------------------------- helpers

## A line of a made-up bank.
func _line(id: String, moment: String, text: String, slots: Array = [], needs: Array = [], level: int = 2, seconds: float = 1.5) -> Dictionary:
	return {"id": id, "moment": moment, "text": text, "slots": slots, "level": level, "seconds": seconds, "count": 1, "needs": needs, "src": "test"}


func _director(lines: Array, config: CommentaryConfig = null) -> CommentaryDirector:
	var bank: CommentaryBank = CommentaryBank.from_json(JSON.stringify({"format": 1, "lines": lines}), "test")
	assert_eq(bank.problems, PackedStringArray(), "the made-up bank is good")
	return CommentaryDirector.new(bank, config if config != null else CommentaryConfig.new(), 1)


## A made-up race: the start line on z = 0 (60 m long), mark 1 at (0, -300), mark 2 at (200, -300), the
## finish line on z = 0 from x = 170 to 230. Each board's spec (all optional): "at", "step" (the step it
## sails to; 1 = mark 1), "place" (else the list's order), "speed", "planing", "fallen", "heading",
## "side", "twa", "water", "water_h", "dirty", "finished", "finish_s", "ocs", "start_s", "brand", "colour",
## "name". The wind 18 kt from the north (-Z: the start to mark 1 is a beat).
func _look(clock_s: float, specs: Array[Dictionary]) -> RaceLook:
	var look: RaceLook = RaceLook.new()
	look.clock_s = clock_s
	look.wind_kt = 18.0
	look.wind_from_deg = 0.0
	look.started = true
	look.racing = clock_s >= 0.0
	look.step_kinds.assign([RaceStep.Kind.START, RaceStep.Kind.MARK, RaceStep.Kind.MARK, RaceStep.Kind.FINISH])
	look.step_points.assign([PackedVector2Array([Vector2(30, 0), Vector2(-30, 0)]), PackedVector2Array([Vector2(0, -300)]),
		PackedVector2Array([Vector2(200, -300)]), PackedVector2Array([Vector2(170, 0), Vector2(230, 0)])])
	var places: Array[int] = []
	for i: int in specs.size():
		var spec: Dictionary = specs[i]
		var board: RaceLook.Board = RaceLook.Board.new()
		board.index = i
		board.name = str(spec.get("name", NAMES[i]))
		board.position = spec.get("at", Vector2(i * 50.0, -100.0))
		board.next_step = int(spec.get("step", 1))
		board.speed_ms = float(spec.get("speed", 10.0))
		board.planing = bool(spec.get("planing", true))
		board.fallen = bool(spec.get("fallen", false))
		board.heading_deg = float(spec.get("heading", 0.0))
		board.sail_side = int(spec.get("side", 1))
		board.twa_deg = float(spec.get("twa", 90.0))
		board.water_share = float(spec.get("water", 1.0))
		board.water_height_m = float(spec.get("water_h", 0.0))
		board.dirty_share = float(spec.get("dirty", 0.0))
		board.finished = bool(spec.get("finished", false))
		board.finish_s = float(spec.get("finish_s", -1.0))
		board.ocs = bool(spec.get("ocs", false))
		board.start_s = float(spec.get("start_s", 1.0))
		board.brand = str(spec.get("brand", "Point.9"))
		board.colour = spec.get("colour", ORANGE)
		if board.next_step < look.step_count():
			var points: PackedVector2Array = look.step_points[board.next_step]
			board.to_next_m = board.position.distance_to(points[0]) if points.size() == 1 \
				else board.position.distance_to(Geometry2D.get_closest_point_to_segment(board.position, points[0], points[1]))
		else:
			board.to_next_m = 0.0
		look.boards.append(board)
		places.append(int(spec.get("place", i + 1)))
	look.order.resize(specs.size())
	for i: int in specs.size():
		look.order[places[i] - 1] = i
		look.boards[i].place = places[i]
	return look


func _names_of(moments: Array[RaceMoment]) -> Array[String]:
	var names: Array[String] = []
	for moment: RaceMoment in moments:
		names.append(moment.moment)
	return names
