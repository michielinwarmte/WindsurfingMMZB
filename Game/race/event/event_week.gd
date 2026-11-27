class_name EventWeek
extends RefCounted
## A slalom event week (Max, 27 November 2026: "simulate the whole slalom week with eliminations
## with 64 people in brackets all live broadcasted"; Documentation/reports/broadcast/
## EVENT_WEEK_PLAN.md): the schedule's days and eliminations, the ladder of the elimination being
## sailed, the points and the standings, and the save. Plain book-keeping: every heat is sailed on
## the water by whoever drives this (EventBroadcast) and its finishing order is handed in.
##
## The schedule is data (res://race/event/schedules/<name>.json): the days, how many eliminations
## on each, each day's wind. The game's Sotavento week follows the real World Cup Fuerteventura
## 2026: eliminations 1 and 2 on the first day, 3 and 4 on the second, 5 to 7 on the third, 8 and 9
## on the fourth, 10 and 11 on the fifth.
##
## The points (checked against the streams' commentary on 27 November 2026, step W0 of the plan):
## the winner of an elimination 0.7, everyone else his place (2nd 2, 3rd 3 ...: the leader's "4.8
## points" after six eliminations is four wins and a second with one result dropped); the fewest
## points lead; the worst results are dropped as the week goes on (DROPPED_AFTER: "elimination 4
## ... the discard will come in", "we have had six eliminations, so this next one means two discards
## will come in", "this is elimination 12, and that's when three discards come in"; the game had the
## third at ten until then). A tie goes to the better last elimination (THE LEAD'S CHOICE: the
## tour's own tie-break was not said on the streams).

signal heat_called(elimination: int, heat: int, sailor_ids: PackedInt32Array)
signal heat_recorded(elimination: int, heat: int, order: PackedInt32Array)
signal elimination_finished(elimination: int, places: PackedInt32Array)
signal week_finished(champion_id: int)

const SCHEDULES_FOLDER: String = "res://race/event/schedules"
const SAVE_VERSION: int = 1
const WINNER_POINTS: float = 0.7
## Eliminations completed -> results dropped (the most that applies counts).
const DROPPED_AFTER: Dictionary[int, int] = {4: 1, 7: 2, 12: 3}

var roster: EventRoster = null
var schedule_name: String = ""
var title: String = ""
## The event as the commentator says it ("the Sotavento World Cup").
var spoken: String = ""
var course_name: String = ""
## One entry per day: {"day", "eliminations", "wind_kt", "wind_from_deg"}.
var days: Array[Dictionary] = []
## The elimination being sailed (1-based), 0 before the first, and its ladder.
var elimination: int = 0
var ladder: EliminationLadder = null
## Every finished elimination's places: the ids from 1st to 64th.
var results: Array[PackedInt32Array] = []


## A new week on a schedule, with the provisional roster. Null (with an error) when the schedule
## can't be read.
static func start(schedule: String) -> EventWeek:
	var week: EventWeek = EventWeek.new()
	if not week._read_schedule(schedule):
		return null
	week.roster = EventRoster.provisional()
	if week.roster == null or week.roster.sailors.size() != EliminationLadder.SAILORS:
		push_error("The event's roster doesn't have %d sailors." % EliminationLadder.SAILORS)
		return null
	week._next_elimination()
	return week


func _read_schedule(schedule: String) -> bool:
	var path: String = SCHEDULES_FOLDER.path_join(schedule + ".json")
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("The event's schedule %s can't be read." % path)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_error("The event's schedule %s is broken." % path)
		return false
	var data: Dictionary = parsed
	schedule_name = schedule
	title = String(data.get("name", schedule))
	spoken = String(data.get("spoken", "the " + title))
	course_name = String(data.get("course", ""))
	days.clear()
	for day: Variant in data.get("days", []):
		days.append(day as Dictionary)
	return total_eliminations() > 0


func total_eliminations() -> int:
	var total: int = 0
	for day: Dictionary in days:
		total += int(day.get("eliminations", 0))
	return total


## The day (its dictionary) on which an elimination (1-based) is sailed; empty when out of range.
func day_of(which: int) -> Dictionary:
	var count: int = 0
	for day: Dictionary in days:
		count += int(day.get("eliminations", 0))
		if which <= count:
			return day
	return {}


func is_over() -> bool:
	return elimination > total_eliminations()


## The heat to sail now (1 to 16) of the current elimination; 0 when the week is over.
func next_heat() -> int:
	return 0 if is_over() or ladder == null else ladder.next_heat()


## The sailors of the heat to sail now, in start order.
func sailors_now() -> Array[EventRoster.Sailor]:
	var out: Array[EventRoster.Sailor] = []
	if next_heat() == 0:
		return out
	for id: int in ladder.sailors_in(next_heat()):
		out.append(roster.sailor(id))
	return out


## Tells whoever listens which heat is up (after a load, and after every recorded heat).
func call_heat() -> void:
	if next_heat() > 0:
		heat_called.emit(elimination, next_heat(), ladder.sailors_in(next_heat()))


## The heat just sailed: its finishing order (every id of the heat once). The next heat is called,
## or the elimination closed and the next one's ladder made, or the week ended. False when the
## order doesn't fit the heat.
func record_heat(order: PackedInt32Array) -> bool:
	var heat: int = next_heat()
	if heat == 0 or not ladder.record(heat, order):
		return false
	heat_recorded.emit(elimination, heat, order)
	if ladder.is_over():
		results.append(ladder.places())
		elimination_finished.emit(elimination, ladder.places())
		_next_elimination()
		if is_over():
			week_finished.emit(standings()[0] if not standings().is_empty() else -1)
			return true
	call_heat()
	return true


## The next elimination's ladder: seeded by the ranking before the first one, by the standings
## after that.
func _next_elimination() -> void:
	elimination += 1
	if is_over():
		ladder = null
		return
	ladder = EliminationLadder.for_seeds(roster.ids_by_ranking() if results.is_empty() else standings())


## The points an elimination's place gives.
static func points_for(place: int) -> float:
	return WINNER_POINTS if place == 1 else float(place)


## How many results are dropped once this many eliminations are finished.
static func dropped_after(finished: int) -> int:
	var dropped: int = 0
	for needed: int in DROPPED_AFTER:
		if finished >= needed:
			dropped = maxi(dropped, DROPPED_AFTER[needed])
	return dropped


## A sailor's points in each finished elimination, in order.
func points_of(id: int) -> PackedFloat32Array:
	var points: PackedFloat32Array = PackedFloat32Array()
	for places: PackedInt32Array in results:
		points.append(points_for(places.find(id) + 1))
	return points


## A sailor's total: his points with the worst results dropped.
func total_of(id: int) -> float:
	var points: Array = Array(points_of(id))
	points.sort()
	var kept: int = maxi(points.size() - dropped_after(results.size()), 0)
	var total: float = 0.0
	for i: int in kept:
		total += float(points[i])
	return total


## The event's standings: the ids, the leader first (the ranking before the event while nothing is
## finished). The fewest points lead; a tie goes to the better last elimination.
func standings() -> PackedInt32Array:
	if results.is_empty():
		return roster.ids_by_ranking()
	var ids: Array = Array(roster.ids_by_ranking())
	var last: PackedInt32Array = results[results.size() - 1]
	ids.sort_custom(func(a: int, b: int) -> bool:
		var ta: float = total_of(a)
		var tb: float = total_of(b)
		if not is_equal_approx(ta, tb):
			return ta < tb
		return last.find(a) < last.find(b))
	return PackedInt32Array(ids)


## The week so far as plain text, for a file beside the save and for the log: the standings of all
## 64 with each elimination's points (a dropped result in brackets), then every finished
## elimination's first sixteen, then the ladder of the elimination being sailed.
func results_text() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append(title)
	var dropped: int = dropped_after(results.size())
	lines.append("Standings after %d of %d eliminations (%d dropped)" % [results.size(), total_eliminations(), dropped])
	var order: PackedInt32Array = standings()
	for place: int in order.size():
		var one: EventRoster.Sailor = roster.sailor(order[place])
		var points: PackedFloat32Array = points_of(one.id)
		# The dropped results: his worst, the later one first when two are the same.
		var worst: Array = range(points.size())
		worst.sort_custom(func(a: int, b: int) -> bool: return points[a] > points[b] if not is_equal_approx(points[a], points[b]) else a > b)
		var out: Array = worst.slice(0, mini(dropped, worst.size()))
		var cells: PackedStringArray = PackedStringArray()
		for i: int in points.size():
			cells.append(("(%s)" if out.has(i) else "%s") % String.num(points[i], 1))
		lines.append("%2d  %-24s %-8s %7s   %s" % [place + 1, one.name, one.sail_number,
			String.num(total_of(one.id), 1) if not results.is_empty() else "-", "  ".join(cells)])
	for i: int in results.size():
		var names: PackedStringArray = PackedStringArray()
		for place: int in mini(16, results[i].size()):
			names.append("%d %s" % [place + 1, roster.sailor(results[i][place]).name])
		lines.append("")
		lines.append("Elimination %d (%s): %s" % [i + 1, String(day_of(i + 1).get("day", "")), ", ".join(names)])
	if ladder != null and not is_over():
		lines.append("")
		lines.append("Elimination %d, being sailed:" % elimination)
		for heat: int in range(1, EliminationLadder.HEATS + 1):
			var result: PackedInt32Array = ladder.result_of(heat)
			if result.is_empty():
				continue
			var names: PackedStringArray = PackedStringArray()
			for id: int in result:
				names.append(roster.sailor(id).name)
			lines.append("  %-22s %s" % [EliminationLadder.heat_name(heat), ", ".join(names)])
	return "\n".join(lines) + "\n"


## The whole week as a dictionary (the save).
func to_data() -> Dictionary:
	var done: Array = []
	for places: PackedInt32Array in results:
		done.append(Array(places))
	var player: int = -1
	for one: EventRoster.Sailor in roster.sailors:
		if one.is_player:
			player = one.id
	return {"version": SAVE_VERSION, "schedule": schedule_name, "elimination": elimination,
		"ladder": ladder.to_data() if ladder != null else {}, "results": done, "player": player}


## Saves the week. True when written.
func save_to(path: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("The event week couldn't be saved to %s." % path)
		return false
	file.store_string(JSON.stringify(to_data(), "\t"))
	return true


## A saved week, or null (with a warning, never a crash) when the file is missing, broken, of
## another version or doesn't fit its schedule.
static func load_from(path: String) -> EventWeek:
	if not FileAccess.file_exists(path):
		return null
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file != null else null
	if not (parsed is Dictionary) or int((parsed as Dictionary).get("version", 0)) != SAVE_VERSION:
		push_warning("The saved event week %s is broken or of another version: a new week starts." % path)
		return null
	var data: Dictionary = parsed
	var week: EventWeek = EventWeek.new()
	if not week._read_schedule(String(data.get("schedule", ""))):
		return null
	week.roster = EventRoster.provisional()
	if week.roster == null:
		return null
	for places: Variant in data.get("results", []):
		var row: PackedInt32Array = PackedInt32Array(places as Array)
		if row.size() != EliminationLadder.SAILORS:
			push_warning("The saved event week %s has a broken result: a new week starts." % path)
			return null
		week.results.append(row)
	week.elimination = int(data.get("elimination", 1))
	if not week.is_over():
		week.ladder = EliminationLadder.from_data(data.get("ladder", {}) as Dictionary)
		if week.ladder == null:
			push_warning("The saved event week %s has a broken ladder: a new week starts." % path)
			return null
	var player: int = int(data.get("player", -1))
	if week.roster.sailor(player) != null:
		week.roster.sailor(player).is_player = true
	return week
