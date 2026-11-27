class_name EventBroadcast
extends Node
## An event week sailed live, heat after heat, on a watched race's boards (Max, 27 November 2026:
## "simulate the whole slalom week with eliminations with 64 people in brackets all live
## broadcasted"; Documentation/reports/broadcast/EVENT_WEEK_PLAN.md). The sailing scene makes one
## when a race is watched with --event=<schedule> (main.gd), for example
##   --course=pwa_slalom_x --skippers=<eight names> --spectate=1 --tv=1 --event=sotavento_2026
##
## What it does: the week's book-keeping (EventWeek) says which eight sailors are in the next
## heat; they are put on the race's eight AI boards (RaceRunner.change_skippers()) and the race is
## started again with a short countdown. Max: "all live", "as little time between races as
## possible, our sailors do not need a pause": as soon as a heat is decided (its fourth board is
## home: the four who go through are known) the result stays on the screen for HOLD_S, is handed
## to the book-keeping, saved, and the next heat's countdown begins. The TV director and the
## commentary follow by themselves: for them it is a new race with new names.
##
## On the screen: a card with the event, the elimination, the heat and its eight sailors (after
## the heat: who goes through), and with B the ladder so far and the standings.
##
## NOT BUILT YET (the plan's later steps): the next heat waiting on the water while this one races
## (sixteen boards: today every heat is the same eight boards with other sailors, put at the
## line); the player sailing his own heats (the book-keeping knows the player's sailor, this node
## only runs a watched week); each day's own wind (the race keeps the wind it was started with).
##
## --event_new=1 starts a new week even when a saved one exists; --event_heats=<n> stops after n
## heats (for tests and screenshots); --event_countdown=<s> another countdown than COUNTDOWN_S;
## --event_trace=<s> writes every board's place, speed and what its skipper is doing to the log
## every <s> seconds of the race (to see where a heat goes wrong).

## The countdown before every heat, seconds: the game's own minute. The AI's slalom start is a timed
## run (away from the line, a gybe, back in at full speed) that needs it: with 60 s the eight came to
## the line within 5 s of the gun at 8 to 17 m/s; with 30 s half of them were still turning (measured
## at Sotavento, 30 kt, 27 November 2026).
const COUNTDOWN_S: float = 60.0
## How long a decided heat's result stays before the next heat is called, seconds of the race
## (a final's longer: its winner, the elimination's result and the standings are said).
const HOLD_S: float = 8.0
const FINAL_HOLD_S: float = 14.0
## A favourite knocked out is news: among the first SHOCK_SEEDS of the elimination's seeding a
## shout, among the first UPSET_SEEDS a lifted voice.
const SHOCK_SEEDS: int = 8
const UPSET_SEEDS: int = 16
const NUMBER_WORDS: PackedStringArray = ["one", "two", "three", "four", "five", "six", "seven", "eight",
	"nine", "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen"]
const ORDER_WORDS: PackedStringArray = ["first", "second", "third", "fourth"]
## A heat that isn't decided by its time limit is closed with the order on the water.
const SAVE_PATH: String = "user://event_week_%s.json"
## The week's results as plain text, written beside the save after every heat (to read in a text
## editor: the standings of all 64, every elimination's first sixteen, the ladder being sailed).
const RESULTS_PATH: String = "user://event_week_%s_results.txt"

var week: EventWeek = null
var runner: RaceRunner = null
var hud: Hud = null
## Watch mode, whose corner of cards the event's card joins (null: the card stands by itself).
var watch: WatchMode = null

## The sailors on the boards now, by AI board.
var _on_boards: Array[EventRoster.Sailor] = []
## Seconds since the heat on the water was decided; negative while it isn't.
var _decided_s: float = -1.0
var _heats_left: int = -1
## The countdown of every heat (COUNTDOWN_S, or --event_countdown=<s>).
var countdown_s: float = COUNTDOWN_S
var _stopped: bool = false
## --event_trace=<s>: seconds between two trace lines (0: none), and the race clock of the next.
var _trace_every_s: float = 0.0
var _trace_next_s: float = -INF
## Each board's falls in the heat on the water (after the gun), and whether it was down last frame.
var _falls: PackedInt32Array = PackedInt32Array()
var _was_down: PackedByteArray = PackedByteArray()

var _card: PanelContainer = null
var _text: Label = null
var _board: PanelContainer = null
var _board_text: Label = null
## The ladder and the standings asked for with B; they also come up by themselves while a final's
## result is held and when the week is over.
var _board_by_hand: bool = false


## Starts or picks up the week of a schedule on a watched race. False (with a warning) when the
## race can't carry it (it needs eight AI boards and nobody playing).
func setup(race_runner: RaceRunner, hud_layer: Hud, schedule: String, watch_mode: WatchMode = null) -> bool:
	runner = race_runner
	hud = hud_layer
	watch = watch_mode
	var fresh: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--event_new=1":
			fresh = true
		if arg.begins_with("--event_heats="):
			_heats_left = arg.get_slice("=", 1).to_int()
		if arg.begins_with("--event_trace="):
			_trace_every_s = maxf(arg.get_slice("=", 1).to_float(), 0.0)
		if arg.begins_with("--event_countdown="):
			countdown_s = maxf(arg.get_slice("=", 1).to_float(), 5.0)
	if runner == null or not runner.spectating or runner.opponents.size() != EliminationLadder.HEAT_SIZE:
		push_warning("An event week needs a watched race of %d AI boards (--spectate=1 and eight --skippers); this race has %d." % [EliminationLadder.HEAT_SIZE, runner.opponents.size() if runner != null else 0])
		_stopped = true
		return false
	var path: String = SAVE_PATH % schedule
	week = null if fresh else EventWeek.load_from(path)
	if week == null:
		week = EventWeek.start(schedule)
	if week == null:
		_stopped = true
		return false
	_build_cards()
	_tell_the_commentary_the_countries()
	_start_heat()
	return true


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_B and _board != null:
		_board_by_hand = not _board_by_hand
		_show_the_board()


func _process(delta: float) -> void:
	if _stopped or week == null or runner == null or runner.race == null:
		return
	if week.is_over():
		return
	var race: RaceSim = runner.race
	_count_falls(race)
	if _trace_every_s > 0.0 and race.clock_s() >= _trace_next_s:
		_trace_next_s = race.clock_s() + _trace_every_s
		_trace(race)
	var final: bool = week.next_heat() >= EliminationLadder.LOSERS_FINAL
	if _decided_s < 0.0:
		# A heat is decided when its four who go through are home; a final when everyone is (every
		# place counts), or when the race closes its finish.
		var needed: int = race.board_count() if final else EliminationLadder.THROUGH
		if _finished_count(race) >= needed or race.phase() == RaceSim.Phase.FINISHED:
			_decided_s = 0.0
			_update_card()
			_show_the_board()
			_say_the_result()
		return
	_decided_s += delta
	if _decided_s >= (FINAL_HOLD_S if final else HOLD_S):
		_close_heat()


## The ladder and the standings on the screen: asked for (B), or by themselves while a final's result
## is held (the elimination's result and the standings) and when the week is over.
func _show_the_board() -> void:
	if _board == null or week == null:
		return
	var by_itself: bool = week.is_over() or (_decided_s >= 0.0 and week.next_heat() >= EliminationLadder.LOSERS_FINAL)
	var wanted: bool = _board_by_hand or by_itself
	if wanted != _board.visible:
		_board.visible = wanted
		_update_board()


## Counts each board's falls once the gun has gone (the heat's report and the result card).
func _count_falls(race: RaceSim) -> void:
	for i: int in mini(runner.opponents.size(), _falls.size()):
		var down: bool = runner.opponents[i].sim.sailor_state == WindsurferSim.SailorState.FALLEN
		if down and _was_down[i] == 0 and race.phase() == RaceSim.Phase.RACING:
			_falls[i] += 1
		_was_down[i] = 1 if down else 0


## One line per board on the log: where it is, how fast, on the board or in the water, where it is
## going and what its skipper says it is doing.
func _trace(race: RaceSim) -> void:
	for i: int in mini(runner.opponents.size(), _on_boards.size()):
		var node: WindsurferNode = runner.opponents[i]
		var at: Vector2 = race.board_position(i)
		var note: String = str(node.skipper.get("note")) if node.skipper != null and "note" in node.skipper else ""
		print("TRACE %6.1f %d %-18s (%6.0f, %6.0f) hdg %3.0f %4.1f m/s %s to %s %4.0f m%s%s | %s" % [
			race.clock_s(), i, _on_boards[i].name.left(18), at.x, at.y, node.sim.telemetry.heading_deg, node.sim.telemetry.speed_ms,
			"DOWN" if node.sim.sailor_state == WindsurferSim.SailorState.FALLEN else "up  ",
			race.next_step_name(i), race.distance_to_next_m(i),
			" FINISHED" if race.is_finished(i) else "", " AGROUND" if runner.is_aground(node) else "", note.left(90)])


## How many of the heat's boards have finished.
func _finished_count(race: RaceSim) -> int:
	var count: int = 0
	for i: int in race.board_count():
		if race.is_finished(i):
			count += 1
	return count


## The heat's order now: the finishers by their time, then the others as they lie on the water.
func _order_now() -> Array[EventRoster.Sailor]:
	var race: RaceSim = runner.race
	var finished: Array[int] = []
	var others: Array[int] = []
	for i: int in race.race_order():
		if race.is_finished(i):
			finished.append(i)
		else:
			others.append(i)
	finished.sort_custom(func(a: int, b: int) -> bool: return race.finish_time_s(a) < race.finish_time_s(b))
	var order: Array[EventRoster.Sailor] = []
	for i: int in finished + others:
		if i < _on_boards.size():
			order.append(_on_boards[i])
	return order


## The next heat's eight sailors onto the boards, and the countdown.
func _start_heat() -> void:
	_on_boards = week.sailors_now()
	_decided_s = -1.0
	_falls.resize(_on_boards.size())
	_falls.fill(0)
	_was_down.resize(_on_boards.size())
	_was_down.fill(0)
	_trace_next_s = -INF
	if _on_boards.size() != runner.opponents.size():
		push_warning("The event's heat has %d sailors for %d boards: the week stops." % [_on_boards.size(), runner.opponents.size()])
		_stopped = true
		return
	var skippers: Array[RaceSkipper] = []
	for sailor: EventRoster.Sailor in _on_boards:
		skippers.append(sailor.make_skipper())
	# Behind the line with a short countdown: no sail out to the start, no wait (Max).
	runner.setup.prestart_s = countdown_s
	runner.setup.free_sail_s = 0.0
	runner.setup.spawn = RaceSetup.Spawn.LINE
	runner.change_skippers(skippers)
	runner.restart()
	_update_card()
	_show_the_board()
	_update_board()
	_say_the_heat()


## The heat on the water is over for the book-keeping: its order handed in, the week saved, the
## next heat called (or the week closed).
func _close_heat() -> void:
	var ids: PackedInt32Array = PackedInt32Array()
	for sailor: EventRoster.Sailor in _order_now():
		ids.append(sailor.id)
	_log_heat()
	if not week.record_heat(ids):
		push_warning("The event's heat result didn't fit its heat: the week stops.")
		_stopped = true
		return
	week.save_to(SAVE_PATH % week.schedule_name)
	_write_the_results()
	if week.is_over() or week.next_heat() == 1:
		# An elimination is over: its first eight and the standings' first eight on the log.
		var last: PackedInt32Array = week.results[week.results.size() - 1]
		var first: PackedStringArray = PackedStringArray()
		var top: PackedStringArray = PackedStringArray()
		for place: int in 8:
			first.append("%d %s" % [place + 1, week.roster.sailor(last[place]).name])
			top.append("%d %s (%s)" % [place + 1, week.roster.sailor(week.standings()[place]).name, String.num(week.total_of(week.standings()[place]), 1)])
		print("EVENT elimination %d is over: %s" % [week.results.size(), ", ".join(first)])
		print("EVENT standings after %d of %d: %s" % [week.results.size(), week.total_eliminations(), ", ".join(top)])
	if _heats_left > 0:
		_heats_left -= 1
		if _heats_left == 0:
			_stopped = true
			_update_card()
			return
	if week.is_over():
		_update_card()
		_show_the_board()
		_update_board()
		_say_the_champion()
		return
	_start_heat()


## The heat's result on the log: the order, each finisher's time, the others' place on the water.
func _log_heat() -> void:
	var race: RaceSim = runner.race
	var words: PackedStringArray = PackedStringArray()
	var order: Array[EventRoster.Sailor] = _order_now()
	for place: int in order.size():
		var board: int = _on_boards.find(order[place])
		var time: String = "%.1f s" % race.finish_time_s(board) if race.is_finished(board) else "racing to %s" % race.next_step_name(board)
		var splits: PackedStringArray = PackedStringArray()
		for split: float in race.splits_s(board):
			splits.append("%.0f" % split)
		words.append("%d %s (seed %d, %s, falls %d, splits %s)" % [place + 1, order[place].name, week.ladder.seeds.find(order[place].id) + 1, time, _falls[board] if board < _falls.size() else 0, " ".join(splits)])
	print("EVENT elimination %d, %s: %s" % [week.elimination, EliminationLadder.heat_name(week.next_heat()), "; ".join(words)])


## The results file beside the save (RESULTS_PATH), rewritten whole.
func _write_the_results() -> void:
	var file: FileAccess = FileAccess.open(RESULTS_PATH % week.schedule_name, FileAccess.WRITE)
	if file != null:
		file.store_string(week.results_text())


# ---------------------------------------------------------------- the commentary

## The commentary of the watched race, or null when there is none.
func _commentary() -> Commentary:
	return watch.commentary if watch != null else null


## Every sailor's country words, for the commentator's "the Italian" and "the Polish rider".
func _tell_the_commentary_the_countries() -> void:
	var commentary: Commentary = _commentary()
	if commentary == null:
		return
	for sailor: EventRoster.Sailor in week.roster.sailors:
		if sailor.national != "" and sailor.nation_adj != "":
			commentary.nations[sailor.name] = PackedStringArray([sailor.national, sailor.nation_adj])


## A heat as the commentator says it: "heat three of the first round", "the second semi-final".
static func heat_words(heat: int) -> String:
	if heat <= 8:
		return "heat %s of the first round" % NUMBER_WORDS[heat - 1]
	if heat <= 12:
		return "the %s quarter-final" % ORDER_WORDS[heat - 9]
	if heat <= 14:
		return "the %s semi-final" % ORDER_WORDS[heat - 13]
	return "the losers' final" if heat == EliminationLadder.LOSERS_FINAL else "the winners' final"


## Where a heat's first four go: "the quarter-finals", "the semi-finals", "the winners' final".
static func round_words(heat: int) -> String:
	if heat <= 8:
		return "the quarter-finals"
	if heat <= 12:
		return "the semi-finals"
	return "the winners' final"


static func elimination_words(number: int) -> String:
	return "elimination %s" % (NUMBER_WORDS[number - 1] if number >= 1 and number <= NUMBER_WORDS.size() else str(number))


## A moment of the event for the commentary: its words for the heat, the elimination and the event,
## and whether the heat is a final.
func _moment(what: String, level: int, heat: int, elimination: int) -> RaceMoment:
	var moment: RaceMoment = RaceMoment.make(what, -1, level, runner.race.clock_s() if runner.race != null else 0.0)
	moment.words["heat"] = heat_words(heat)
	moment.words["round"] = round_words(heat)
	moment.words["elimination"] = elimination_words(elimination)
	moment.words["event"] = week.spoken
	moment.tags.append("final" if heat >= EliminationLadder.LOSERS_FINAL else "not_final")
	return moment


## The sailor a moment is about: his board when he is on the water, and his name and country as words
## (so a sailor who is not in this heat, the event's leader, can be named too).
func _about(moment: RaceMoment, sailor: EventRoster.Sailor, second: EventRoster.Sailor = null) -> void:
	moment.board = _on_boards.find(sailor)
	moment.words["rider"] = sailor.name
	if sailor.national != "":
		moment.words["national"] = sailor.national
	if sailor.nation_adj != "":
		moment.words["nation_adj"] = sailor.nation_adj
	if second != null:
		moment.board2 = _on_boards.find(second)
		moment.words["rider2"] = second.name


## The heat called (and, at an elimination's first heat after the first, the standings), and its
## favourite: the best of the elimination's seeding in it.
func _say_the_heat() -> void:
	var commentary: Commentary = _commentary()
	if commentary == null or week.is_over() or _stopped:
		return
	var heat: int = week.next_heat()
	var final: bool = heat >= EliminationLadder.LOSERS_FINAL
	var moments: Array[RaceMoment] = []
	if heat == 1 and not week.results.is_empty():
		var order: PackedInt32Array = week.standings()
		var standings: RaceMoment = _moment("standings", 2, heat, week.results.size())
		_about(standings, week.roster.sailor(order[0]), week.roster.sailor(order[1]))
		moments.append(standings)
	moments.append(_moment("heat_called", 3 if final else 2, heat, week.elimination))
	var best: EventRoster.Sailor = null
	for sailor: EventRoster.Sailor in _on_boards:
		if best == null or week.ladder.seeds.find(sailor.id) < week.ladder.seeds.find(best.id):
			best = sailor
	if best != null:
		var favourite: RaceMoment = _moment("heat_favourite", 2, heat, week.elimination)
		_about(favourite, best)
		# His place in the event so far (before the first result: in the ranking he came with).
		favourite.place = week.standings().find(best.id) + 1
		moments.append(favourite)
	commentary.hear(moments)


## A decided heat: who goes through and the favourite who doesn't; a winners' final: who won the
## elimination.
func _say_the_result() -> void:
	var commentary: Commentary = _commentary()
	if commentary == null:
		return
	var heat: int = week.next_heat()
	var order: Array[EventRoster.Sailor] = _order_now()
	if order.size() < EliminationLadder.HEAT_SIZE:
		return
	var moments: Array[RaceMoment] = []
	if heat == EliminationLadder.WINNERS_FINAL:
		var won: RaceMoment = _moment("final_win", 4, heat, week.elimination)
		_about(won, order[0], order[1])
		moments.append(won)
	elif heat < EliminationLadder.LOSERS_FINAL:
		var through: RaceMoment = _moment("heat_through", 2, heat, week.elimination)
		_about(through, order[0], order[1])
		moments.append(through)
		var best_out: EventRoster.Sailor = null
		for place: int in range(EliminationLadder.THROUGH, order.size()):
			if best_out == null or week.ladder.seeds.find(order[place].id) < week.ladder.seeds.find(best_out.id):
				best_out = order[place]
		if best_out != null:
			var seed: int = week.ladder.seeds.find(best_out.id)
			var out: RaceMoment = _moment("heat_out", 4 if seed < SHOCK_SEEDS else (3 if seed < UPSET_SEEDS else 2), heat, week.elimination)
			_about(out, best_out)
			moments.append(out)
	commentary.hear(moments)


## The week is over: the champion.
func _say_the_champion() -> void:
	var commentary: Commentary = _commentary()
	if commentary == null or week.standings().is_empty():
		return
	var won: RaceMoment = _moment("event_win", 4, EliminationLadder.WINNERS_FINAL, week.total_eliminations())
	_about(won, week.roster.sailor(week.standings()[0]), week.roster.sailor(week.standings()[1]))
	commentary.hear([won])


# ---------------------------------------------------------------- the cards

func _build_cards() -> void:
	_card = PanelContainer.new()
	_card.name = "EventCard"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_theme_stylebox_override("panel", HudStyle.card(10.0))
	if watch != null:
		# Under watch mode's own cards, in their corner.
		watch.add_card(_card)
	else:
		hud.add_part(_card)
		_card.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, int(Hud.MARGIN))
	_text = HudStyle.label(HudStyle.sans(500), 13)
	_card.add_child(_text)
	_board = PanelContainer.new()
	_board.name = "EventBoard"
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.add_theme_stylebox_override("panel", HudStyle.card(14.0))
	hud.add_part(_board)
	_board.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_board.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_board.grow_vertical = Control.GROW_DIRECTION_BOTH
	_board_text = HudStyle.label(HudStyle.mono(500), 12)
	_board.add_child(_board_text)
	_board.visible = false


## The card's words: the event, the elimination, the heat, and the eight (after the heat: the order
## and who goes through).
func card_text() -> String:
	if week == null:
		return ""
	var lines: PackedStringArray = PackedStringArray()
	lines.append(week.title)
	if week.is_over():
		var champion: EventRoster.Sailor = week.roster.sailor(week.standings()[0])
		lines.append("The week is over")
		lines.append("Champion: %s (%s)" % [champion.name, champion.sail_number])
		return "\n".join(lines)
	var heat: int = week.next_heat()
	lines.append("%s  ·  Elimination %d of %d" % [String(week.day_of(week.elimination).get("day", "")), week.elimination, week.total_eliminations()])
	lines.append("%s  (heat %d of %d)" % [EliminationLadder.heat_name(heat), heat, EliminationLadder.HEATS])
	lines.append("")
	if _decided_s >= 0.0:
		var order: Array[EventRoster.Sailor] = _order_now()
		var finals: bool = heat >= EliminationLadder.LOSERS_FINAL
		for place: int in order.size():
			var mark: String = ""
			if not finals:
				mark = "   through" if place < EliminationLadder.THROUGH else "   out"
			lines.append("%d  %s%s" % [place + 1, order[place].name, mark])
	else:
		for sailor: EventRoster.Sailor in _on_boards:
			lines.append("%s  %s" % [sailor.sail_number, sailor.name])
	# The key's hint only on the full screen (the TV screen shows what a viewer needs).
	if watch == null or watch.screen == WatchMode.Screen.FULL:
		lines.append("")
		lines.append("B: the ladder and the standings")
	return "\n".join(lines)


## The ladder of the elimination being sailed and the standings' first twelve.
func board_text() -> String:
	if week == null:
		return ""
	var lines: PackedStringArray = PackedStringArray()
	if week.ladder != null:
		lines.append("ELIMINATION %d" % week.elimination)
		for heat: int in range(1, EliminationLadder.HEATS + 1):
			var result: PackedInt32Array = week.ladder.result_of(heat)
			var sailors: PackedInt32Array = result if not result.is_empty() else week.ladder.sailors_in(heat)
			var names: PackedStringArray = PackedStringArray()
			for i: int in sailors.size():
				var surname: String = week.roster.sailor(sailors[i]).name.get_slice(" ", 1)
				names.append(surname if result.is_empty() or i >= EliminationLadder.THROUGH or heat >= EliminationLadder.LOSERS_FINAL else surname.to_upper())
			var state: String = "to come" if sailors.is_empty() else (", ".join(names))
			lines.append("%-22s %s" % [EliminationLadder.heat_name(heat), state])
		lines.append("")
	lines.append("STANDINGS after %d of %d eliminations (%d dropped)" % [week.results.size(), week.total_eliminations(), EventWeek.dropped_after(week.results.size())])
	var order: PackedInt32Array = week.standings()
	for place: int in mini(12, order.size()):
		var sailor: EventRoster.Sailor = week.roster.sailor(order[place])
		lines.append("%2d  %-22s %-8s %6.1f" % [place + 1, sailor.name, sailor.sail_number, week.total_of(sailor.id)])
	return "\n".join(lines)


func _update_card() -> void:
	if _text != null:
		_text.text = card_text()


func _update_board() -> void:
	if _board_text != null and _board.visible:
		_board_text.text = board_text()
