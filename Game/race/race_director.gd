class_name RaceDirector
extends Node
## The race director (Documentation/reports/multiplayer/RACE_DIRECTOR.md, R4 and R6): races one
## after the other without reloading, and the course changed while everyone sails. The LAN host has
## it (and the player in a race alone); the guests see what it decided through the race's state
## (info(), RaceMirror) and the course messages (NetBoards).
##
## - When a race ends (every board in, the finish window, the time limit, or abandoned), the next
##   countdown is planned gap_s later (3 minutes by default, Max's answer of 6 November 2026). When
##   it is due, RaceRunner.restart(true) builds a new race with every board where it is: the AI
##   boards sail free until then and to the line in the countdown; the players who joined since race
##   too, and the AI takes the gear for the wind of the moment.
## - The director can start the countdown now, move it a minute either way, change the gap, the
##   countdown's length and the laps (for the next race), abandon the race under way, or put every
##   board back behind the line with a new countdown (the old R).
## - The course: publish_course() takes the course maker's course (RaceDirectorView). During a race
##   only the marks' places may change (RaceSim.has_same_steps_as()); a change of shape is refused
##   then. A taken course goes onto this PC's water, minimap and race at once and to the guests at
##   most PUBLISH_EVERY_S apart (a mark dragged sends many changes a second; the last one always
##   goes).

## The gaps and countdowns the director can choose, seconds.
const GAP_CHOICES_S: Array[float] = [60.0, 120.0, 180.0, 300.0, 600.0]
const COUNTDOWN_CHOICES_S: Array[float] = [30.0, 60.0, 120.0, 180.0, 300.0]
const DEFAULT_GAP_S: float = 180.0
## The nearest the next countdown can be moved to, seconds.
const SOONEST_S: float = 5.0
## The course goes out at most this often while the director drags (seconds).
const PUBLISH_EVERY_S: float = 0.1
## How long a director's note stays on everyone's screen, seconds.
const NOTE_SHOWN_S: float = 6.0

## The new course reached this PC's race (the view redraws, the scene sends it to the guests).
signal course_published(course: Course)

var runner: RaceRunner = null
## The sailing scene, which puts a course on the water, the minimap and into the race (apply_course).
var scene: SailingScene = null
## Seconds from the end of a race to the next countdown.
var gap_s: float = DEFAULT_GAP_S
## Seconds until the next countdown begins; -1 while a race (or its countdown) is on.
var next_countdown_in_s: float = -1.0
## A short note for every screen ("The course has changed"), and how long it has left.
var note: String = ""
var note_left_s: float = 0.0
## The course waiting to go out (the last one the director made), and how long until it may.
var _pending: Course = null
var _publish_wait_s: float = 0.0
## --director_move: [the mark, its move (east, south m), the race clock at which]; empty: none.
var _scripted_move: Array = []


func _init() -> void:
	name = "RaceDirector"
	# The schedule stops with the race when a game alone is paused.
	process_mode = Node.PROCESS_MODE_PAUSABLE


func setup(race_runner: RaceRunner, sailing_scene: SailingScene) -> void:
	runner = race_runner
	scene = sailing_scene
	# A start made elsewhere (R, the pause menu's restart) plans nothing more: its race is on.
	runner.restarted.connect(func() -> void: next_countdown_in_s = -1.0)
	var options: Dictionary[String, String] = LanSession.command_line_options()
	if options.has("director_gap"):
		gap_s = maxf(options["director_gap"].to_float(), 1.0)
	if options.has("director_move"):
		_read_scripted_move(options["director_move"])


## --director_move=<mark>,<east m>,<south m>@<race clock s> (tests: tools/lan_test.sh --host_options):
## once, at that moment of a race (the clock is negative in the countdown), the mark moves that far,
## as if the race director had dragged it ("start_boat" for a line's end).
func _read_scripted_move(text: String) -> void:
	var parts: PackedStringArray = text.split("@")
	var what: PackedStringArray = parts[0].split(",")
	if parts.size() != 2 or what.size() != 3:
		push_warning("--director_move=<mark>,<east m>,<south m>@<s>, not \"%s\"" % text)
		return
	_scripted_move = [what[0].replace("_", " "), Vector2(what[1].to_float(), what[2].to_float()), parts[1].to_float()]


func _do_scripted_move(race: RaceSim) -> void:
	if _scripted_move.is_empty() or not race.is_started() or race.clock_s() < float(_scripted_move[2]):
		return
	var moved: Course = scene.live_course().copy()
	var mark: CourseMark = moved.mark(String(_scripted_move[0]))
	var offset: Vector2 = _scripted_move[1]
	_scripted_move = []
	if mark == null:
		push_warning("--director_move: the course has no such mark.")
		return
	mark.position += offset
	print("RACE DIRECTOR: %s moved by script to (%.1f, %.1f): %s" % [mark.id, mark.position.x, mark.position.y, "taken" if publish_course(moved) else "refused"])


func _physics_process(delta: float) -> void:
	note_left_s = maxf(note_left_s - delta, 0.0)
	var race: RaceSim = runner.race if runner != null else null
	if race == null:
		return
	_do_scripted_move(race)
	if next_countdown_in_s < 0.0:
		if race.phase() == RaceSim.Phase.FINISHED:
			next_countdown_in_s = gap_s
			print("RACE DIRECTOR: the race is over; the next countdown in %.0f s" % gap_s)
		return
	next_countdown_in_s -= delta
	if next_countdown_in_s <= 0.0:
		start_countdown_now()


func _process(delta: float) -> void:
	_publish_wait_s -= delta
	if _pending != null and _publish_wait_s <= 0.0:
		_send(_pending)


# ---------------------------------------------------------------- the schedule (R4)

## Whether a race is under way (from the gun to its end): no gear changes, no change of the course's
## shape.
func is_racing() -> bool:
	return runner != null and runner.race != null and runner.race.phase() == RaceSim.Phase.RACING


## Whether the countdown of the next race is running.
func is_counting_down() -> bool:
	return runner != null and runner.race != null and runner.race.is_started() and runner.race.phase() == RaceSim.Phase.PRE_START


## The next race's countdown begins now: a new race with every board where it is.
func start_countdown_now() -> void:
	if runner == null:
		return
	next_countdown_in_s = -1.0
	runner.restart(true)
	say("The countdown has begun: %s to the start." % RaceDirector.minutes(runner.race.prestart_s))
	print("RACE DIRECTOR: countdown %.0f s, %d lap(s), %d boards" % [runner.race.prestart_s, runner.race.laps, runner.race.board_count()])


## The next countdown a minute (or `by_s`) later or sooner; only while one is planned.
func move_next_start(by_s: float) -> void:
	if next_countdown_in_s < 0.0:
		return
	next_countdown_in_s = maxf(next_countdown_in_s + by_s, SOONEST_S)
	say("Next countdown in %s." % RaceDirector.minutes(next_countdown_in_s))


## The race under way (or its countdown) ends now; the next countdown is planned after the gap.
func abandon() -> void:
	if runner == null or runner.race == null or runner.race.phase() == RaceSim.Phase.FINISHED:
		return
	runner.race.end_now()
	say("The race director has abandoned the race.")


## Every board back behind the line and a new countdown at once (the old R).
func everyone_to_the_line() -> void:
	if runner == null:
		return
	next_countdown_in_s = -1.0
	runner.restart(false)
	say("Everyone back to the line: a new countdown.")


func set_gap_s(seconds: float) -> void:
	gap_s = maxf(seconds, SOONEST_S)


## The countdown's length, from the next race on.
func set_countdown_s(seconds: float) -> void:
	if runner != null:
		runner.setup.prestart_s = maxf(seconds, 5.0)


## The laps, from the next race on.
func set_laps(count: int) -> void:
	if runner != null:
		runner.setup.laps = clampi(count, 1, 9)


## A note for every screen for a few seconds.
func say(text: String) -> void:
	note = text
	note_left_s = NOTE_SHOWN_S


## What the guests' screens show of the director (in the race's state, ten times a second).
func info() -> Dictionary:
	return {"next_in": next_countdown_in_s, "gap": gap_s, "countdown": runner.setup.prestart_s if runner != null else 0.0,
		"laps": runner.setup.laps if runner != null else 1, "note": note if note_left_s > 0.0 else ""}


# ---------------------------------------------------------------- the course (R6)

## Whether the race would take this course now: always between races and in the countdown; during a
## race only if it keeps the race's steps (the marks moved, not added, removed or reordered).
func can_take(course: Course) -> bool:
	if course == null:
		return false
	for line_end: String in [CourseMark.START_BOAT, CourseMark.START_PIN, CourseMark.FINISH_BOAT, CourseMark.FINISH_PIN]:
		if course.mark(line_end) == null:
			return false  # a race needs both lines
	return not is_racing() or runner.race.has_same_steps_as(course)


## The course maker's course for everyone (a copy is kept: the maker goes on changing its own). False
## when the race cannot take it now (can_take()).
func publish_course(course: Course) -> bool:
	if not can_take(course):
		return false
	_pending = course.copy()
	if _publish_wait_s <= 0.0:
		_send(_pending)
	return true


func _send(course: Course) -> void:
	_pending = null
	_publish_wait_s = PUBLISH_EVERY_S
	scene.apply_course(course)
	course_published.emit(course)


# ---------------------------------------------------------------- text for the screens

## "3:00", "45 s".
static func minutes(seconds: float) -> String:
	var whole: int = maxi(ceili(seconds), 0)
	if whole < 60:
		return "%d s" % whole
	return "%d:%02d" % [whole / 60, whole % 60]


## The line under the race clock on every screen: the next countdown, or the director's note; for a
## player not in this race (joined during it) that they race from the next start.
static func notice_text(director: Dictionary, in_race: bool, race: RaceSim) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var next_in: float = float(director.get("next_in", -1.0))
	if next_in >= 0.0:
		lines.append("Next race: the countdown begins in %s" % RaceDirector.minutes(next_in))
	if not in_race:
		if race != null and race.phase() == RaceSim.Phase.FINISHED and next_in >= 0.0:
			lines.append("You race in the next one.")
		else:
			lines.append("A race is on: you join it at the next start.")
	var said: String = String(director.get("note", ""))
	if said != "":
		lines.append(said)
	return "\n".join(lines)
