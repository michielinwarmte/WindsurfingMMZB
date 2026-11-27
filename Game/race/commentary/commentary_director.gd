class_name CommentaryDirector
extends RefCounted
## The commentator's choice of what to say and when (Documentation/reports/broadcast/PLAN.md, P6): the
## race story (RaceStory) tells it the moments as they happen (hear()), and every frame (step()) it
## decides whether to start a line, which moment it is about and which of the bank's lines it says.
## A plain class with its own clock (the seconds passed to step()), so the tests can drive it.
##
## The rules (Max and the plan):
## - One voice at a time: a line takes its `seconds`, then a breathing pause (pause_min_s to
##   pause_max_s) before the next; small talk waits a little longer (quiet_pause_min_s to _max_s).
## - New moments first, the biggest first (CommentaryConfig.priority, with the moment's level, the board
##   on the screen counting more and a board at the back less). A big moment (cut_in_from) cuts a
##   smaller line short (a lead change, a fall, the finish over an identify). A moment whose line would
##   come more than its late_s after it is dropped, not said late.
## - When nothing new is happening: small talk about the board the camera shows (identify, speed,
##   unsure), the leader, a rundown of the order (one line per board, down the places, stopped by
##   anything new), a filler, a word on the camera; each kind not again within its quiet_again_s.
## - No line twice in a short time: not the same line (repeat_line_s; a line with a slot, whose words
##   change with the board, repeat_slotted_line_s) and not the same words, whatever the line
##   (repeat_words_s). Among the lines that fit, the least used for how often he says it: a line's uses
##   are measured against the square root of its `count`, so the whole bank gets used and a staple of
##   his comes more often (a line he said 9 times about three times as often as one he said once).
## - The line's level fits the moment's: the nearest level first (a photo finish takes a shouted line if
##   there is one, a routine rounding a calm one).
## - A line's `needs` must hold, and every slot must be filled ({rider}, {brand}, {colour} ...), or the
##   line is skipped.
## - Pairs, said with no breath between them (pair_gap_s): his reaction first and then the line about
##   what happened ("Wow." then the pass, "Oh no." then the fall: the moments wow and oh_no, for a big
##   moment, reaction_chance of the time, when a reaction line fits); and in a rundown a place on its
##   own followed by the board's name ("Second." "Hana."). A bigger moment that cuts in drops the rest
##   of the pair.
## line_started is emitted when a line starts (its id, its words with the slots filled, its seconds and
## level), so the subtitles show it now and the voice says it (CommentaryVoice); line_stopped when a
## line is cut short; line_ahead when the second line of a pair is chosen, before it is said. When the
## computer voice takes longer than his seconds, the voice tells the director (line_lasts()) and the
## next line waits for it.

signal line_started(id: String, text: String, seconds: float, level: int)
signal line_stopped(id: String)
## A line chosen a moment before it is said (the second line of a pair), so its sound can be made ahead.
signal line_ahead(id: String, text: String, seconds: float, level: int)

const QUIET_MOMENTS: PackedStringArray = ["identify", "speed", "leader", "rundown", "filler", "camera", "unsure",
	"tactics", "tension", "form", "conditions"]

var bank: CommentaryBank
var config: CommentaryConfig

## The camera: the board on the screen (its race number, -1 none) and whether the picture is a wide or
## a close shot (the `camera_wide` and `camera_close` needs). Set by whoever has the camera, every frame.
var focus: int = -1
var camera_wide: bool = false
var camera_close: bool = false

## The line being said: its id ("" for none), its words and its moment.
var saying_id: String = ""
var saying_text: String = ""
var saying: RaceMoment = null
## What happened to the moments heard: heard, said, too late, no line fitted, cut short.
var counts: Dictionary[String, int] = {"heard": 0, "said": 0, "quiet": 0, "late": 0, "no_line": 0, "cut": 0, "reaction": 0}

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _clock_s: float = 0.0
var _talk_until_s: float = -INF
## When the line being said started (the director's clock).
var _said_at_s: float = -INF
var _free_s: float = -INF
var _quiet_free_s: float = -INF
var _pending: Array[RaceMoment] = []
## The boards still to name in a rundown, in order of place.
var _rundown: Array[int] = []
var _line_at: Dictionary[String, float] = {}
var _words_at: Dictionary[String, float] = {}
var _uses: Dictionary[String, int] = {}
var _quiet_at: Dictionary[String, float] = {}
var _named_at: Dictionary[int, float] = {}
var _last_moment: String = ""
var _last_moment_s: float = -INF
## The second line of a pair (its moment and its line, chosen with the first), said straight after it.
var _follow: RaceMoment = null
var _follow_pick: Dictionary = {}


## The bank's lines and the tuning; `dice` fixes the choices (the tests, a repeated transcript); -1
## chooses afresh each time.
func _init(lines: CommentaryBank, tuning: CommentaryConfig, dice: int = -1) -> void:
	bank = lines
	config = tuning
	if dice >= 0:
		_rng.seed = dice
	else:
		_rng.randomize()


## The director's clock, seconds.
func clock_s() -> float:
	return _clock_s


## Whether a line is being said now.
func is_saying() -> bool:
	return saying != null and _clock_s < _talk_until_s


## The moments the race story saw (RaceStory.look()); they wait for their turn, at most their late_s.
func hear(moments: Array[RaceMoment]) -> void:
	for moment: RaceMoment in moments:
		moment.heard_s = _clock_s
		_pending.append(moment)
		counts["heard"] += 1


## A new race: what was waiting is forgotten and the line being said stops. The lines said stay
## remembered (no line again soon, also across races).
func new_race() -> void:
	_pending.clear()
	_rundown.clear()
	stop()
	_last_moment = ""


## Silence: the line being said stops (the commentary switched off, a new race).
func stop() -> void:
	if is_saying():
		line_stopped.emit(saying_id)
	saying = null
	saying_id = ""
	saying_text = ""
	_follow = null
	_talk_until_s = _clock_s
	_free_s = _clock_s
	_quiet_free_s = _clock_s


## Every frame: `dt` seconds on (real seconds in the game), the race as it is now and its story (for the
## small talk). Starts a line when it is time; returns true when it did.
func step(dt: float, look: RaceLook, story: RaceStory) -> bool:
	_clock_s += dt
	_drop_the_late()
	if look == null:
		return false
	if is_saying():
		return _cut_in(look)
	if saying != null:
		saying = null
		saying_id = ""
	if _follow != null:
		# The second line of a pair, with no breath between.
		if _clock_s < _talk_until_s + config.pair_gap_s:
			return false
		var moment: RaceMoment = _follow
		_follow = null
		_start(moment, _follow_pick)
		return true
	if _clock_s < _free_s:
		return false
	if _say_the_news(look):
		return true
	if not _rundown.is_empty():
		return _go_on_with_the_rundown(look)
	if _clock_s < _quiet_free_s or story == null:
		return false
	return _small_talk(look, story)


# ---------------------------------------------------------------- what to say

## The moments waiting, biggest first: the first one a line fits is said (the others wait their turn).
func _say_the_news(look: RaceLook) -> bool:
	if _pending.is_empty():
		return false
	var waiting: Array[RaceMoment] = _by_weight(_pending, look)
	for moment: RaceMoment in waiting:
		if moment.moment == _last_moment and config.not_in_a_row.has(moment.moment) and _clock_s - _last_moment_s < config.not_in_a_row_s:
			continue  # not the same kind of moment twice in a row (it may still come after another)
		_pending.erase(moment)
		if _say(moment, look):
			_rundown.clear()  # the rundown stops for anything new
			return true
		counts["no_line"] += 1
	return false


## A big moment that arrives while a smaller line is said cuts it short.
func _cut_in(look: RaceLook) -> bool:
	if _pending.is_empty() or saying == null:
		return false
	var now_weight: float = _weight(saying, look)
	for moment: RaceMoment in _by_weight(_pending, look):
		var weight: float = _weight(moment, look)
		if weight < config.cut_in_from or weight < now_weight + config.cut_margin:
			return false
		var cut_id: String = saying_id
		_pending.erase(moment)
		var pick: Dictionary = choose_line(moment, look)
		if pick.is_empty():
			counts["no_line"] += 1
			continue
		counts["cut"] += 1
		line_stopped.emit(cut_id)
		_rundown.clear()
		_follow = null
		_start_with_a_reaction(moment, pick, look)
		return true
	return false


## The rundown goes on: the next board down the order.
func _go_on_with_the_rundown(look: RaceLook) -> bool:
	while not _rundown.is_empty():
		var index: int = _rundown.pop_front()
		if index >= look.boards.size() or not look.boards[index].present:
			continue
		var moment: RaceMoment = RaceMoment.make("rundown", index, 2, look.clock_s)
		moment.quiet = true
		moment.place = look.boards[index].place
		if _say(moment, look):
			return true
	return false


## Small talk: one of the quiet moments that fit now (RaceStory.quiet()), by their weights, not one
## said lately.
func _small_talk(look: RaceLook, story: RaceStory) -> bool:
	var offered: Array[RaceMoment] = []
	for moment: RaceMoment in story.quiet(look, focus, camera_wide):
		if _clock_s - _quiet_at.get(moment.moment, -INF) < config.quiet_again_s.get(moment.moment, 20.0):
			continue
		if (moment.moment == "identify" or moment.moment == "unsure") and _clock_s - _named_at.get(moment.board, -INF) < config.identify_again_s:
			continue
		if config.quiet_weight.get(moment.moment, 0.0) <= 0.0:
			continue  # a kind of small talk with no weight is never taken
		offered.append(moment)
	while not offered.is_empty():
		var weights: PackedFloat32Array = PackedFloat32Array()
		for moment: RaceMoment in offered:
			weights.append(config.quiet_weight.get(moment.moment, 0.0))
		var at: int = _rng.rand_weighted(weights)
		var moment: RaceMoment = offered[at]
		offered.remove_at(at)
		moment.heard_s = _clock_s
		if moment.moment == "rundown":
			if _start_the_rundown(look):
				return true
			continue
		if _say(moment, look):
			counts["quiet"] += 1
			return true
	return false


## A rundown: the boards down the order to rundown_places, one line each; the first now.
func _start_the_rundown(look: RaceLook) -> bool:
	_rundown.clear()
	for place: int in mini(config.rundown_places, look.order.size()):
		_rundown.append(look.order[place])
	_quiet_at["rundown"] = _clock_s
	if _go_on_with_the_rundown(look):
		counts["quiet"] += 1
		return true
	_rundown.clear()
	return false


## Says a line for a moment, if one fits; false when none does. A big moment may get his reaction
## first; a rundown's place said on its own gets the board's name after it.
func _say(moment: RaceMoment, look: RaceLook) -> bool:
	var pick: Dictionary = choose_line(moment, look)
	if pick.is_empty():
		return false
	_start_with_a_reaction(moment, pick, look)
	if moment.moment == "rundown" and _follow == null and not (pick["line"] as CommentaryBank.Line).slots.has("rider"):
		var named: RaceMoment = RaceMoment.make("identify", moment.board, moment.level, moment.race_s)
		named.quiet = true
		named.place = moment.place
		var name_pick: Dictionary = choose_line(named, look, true)
		if not name_pick.is_empty():
			_follow_with(named, name_pick)
	return true


## Starts a moment's line, or first his reaction to it (the line then follows as the pair's second).
func _start_with_a_reaction(moment: RaceMoment, pick: Dictionary, look: RaceLook) -> void:
	var kind: String = config.reaction.get(moment.moment, "")
	if kind != "" and not moment.quiet and moment.level >= config.reaction_from_level and _rng.randf() < config.reaction_chance:
		var reaction: RaceMoment = RaceMoment.make(kind, moment.board, moment.level, moment.race_s)
		reaction.board2 = moment.board2
		reaction.close = moment.close
		reaction.place = moment.place
		reaction.mark_word = moment.mark_word
		reaction.note = "before " + moment.moment
		var reaction_pick: Dictionary = choose_line(reaction, look)
		if not reaction_pick.is_empty() and words_key(reaction_pick["text"]) != words_key(pick["text"]):
			counts["reaction"] += 1
			_start(reaction, reaction_pick)
			_follow_with(moment, pick)
			return
	_start(moment, pick)


## The second line of a pair, said straight after the line now; told ahead (line_ahead) so its sound
## can be made while the first is said.
func _follow_with(moment: RaceMoment, pick: Dictionary) -> void:
	_follow = moment
	_follow_pick = pick
	var line: CommentaryBank.Line = pick["line"]
	line_ahead.emit(line.id, pick["text"], line.seconds, line.level)


## The line being said lasts `seconds` from its start, if that is longer than his own seconds (the
## computer voice is often slower than him): the pause after it and the next line move on with it, so
## the next line does not cut its sound off. Nothing happens when `id` is no longer being said.
func line_lasts(id: String, seconds: float) -> void:
	if saying == null or saying_id != id:
		return
	var until_s: float = _said_at_s + seconds
	if until_s <= _talk_until_s:
		return
	var more_s: float = until_s - _talk_until_s
	_talk_until_s = until_s
	_free_s += more_s
	_quiet_free_s += more_s


func _start(moment: RaceMoment, pick: Dictionary) -> void:
	var line: CommentaryBank.Line = pick["line"]
	var text: String = pick["text"]
	_said_at_s = _clock_s
	_line_at[line.id] = _clock_s
	_words_at[words_key(text)] = _clock_s
	_uses[line.id] = _uses.get(line.id, 0) + 1
	saying = moment
	saying_id = line.id
	saying_text = text
	_talk_until_s = _clock_s + line.seconds
	var pause_s: float = config.rundown_pause_s if moment.moment == "rundown" else _rng.randf_range(config.pause_min_s, config.pause_max_s)
	_free_s = _talk_until_s + pause_s
	_quiet_free_s = _talk_until_s + maxf(pause_s, _rng.randf_range(config.quiet_pause_min_s, config.quiet_pause_max_s))
	if moment.quiet:
		_quiet_at[moment.moment] = _clock_s
	if moment.board >= 0 and line.slots.has("rider"):
		_named_at[moment.board] = _clock_s
	if moment.moment == "identify" or moment.moment == "unsure":
		_named_at[moment.board] = _clock_s
	_last_moment = moment.moment
	_last_moment_s = _clock_s
	counts["said"] += 1
	line_started.emit(line.id, text, line.seconds, line.level)


## The moments waiting that are too late now are dropped.
func _drop_the_late() -> void:
	for i: int in range(_pending.size() - 1, -1, -1):
		var moment: RaceMoment = _pending[i]
		if _clock_s - moment.heard_s > config.late_of(moment.moment):
			_pending.remove_at(i)
			counts["late"] += 1


func _by_weight(moments: Array[RaceMoment], look: RaceLook) -> Array[RaceMoment]:
	var sorted: Array[RaceMoment] = moments.duplicate()
	sorted.sort_custom(func(a: RaceMoment, b: RaceMoment) -> bool: return _weight(a, look) > _weight(b, look))
	return sorted


func _weight(moment: RaceMoment, look: RaceLook) -> float:
	var place: int = look.boards[moment.board].place if moment.board >= 0 and moment.board < look.boards.size() else 0
	return config.weight_of(moment, focus, place)


# ---------------------------------------------------------------- which line

## The line for a moment now: {"line": CommentaryBank.Line, "text": the words with the slots filled},
## or empty when none fits. Of the lines whose needs hold, whose slots can be filled and that were not
## said lately: the nearest level, then the least used for how often he says it (uses over the square
## root of its count), then by chance, a staple more often.
## `naming`: only lines that say the board's name.
func choose_line(moment: RaceMoment, look: RaceLook, naming: bool = false) -> Dictionary:
	var fitting: Array[Dictionary] = []
	for line: CommentaryBank.Line in bank.lines_for(moment.moment):
		var again_s: float = config.repeat_slotted_line_s if not line.slots.is_empty() else config.repeat_line_s
		if _clock_s - _line_at.get(line.id, -INF) < again_s:
			continue
		if naming and not line.slots.has("rider"):
			continue
		if moment.moment == "rundown" and not line.slots.has("rider") and not line.slots.has("place"):
			continue  # a rundown's line names the board or its place
		if not needs_met(line, moment, look):
			continue
		var text: String = fill(line, moment, look)
		if text == "" or _clock_s - _words_at.get(words_key(text), -INF) < config.repeat_words_s:
			continue
		fitting.append({"line": line, "text": text})
	if fitting.is_empty():
		return {}
	var nearest: int = 99
	for pick: Dictionary in fitting:
		nearest = mini(nearest, absi((pick["line"] as CommentaryBank.Line).level - moment.level))
	var least_used: float = INF
	for pick: Dictionary in fitting:
		var line: CommentaryBank.Line = pick["line"]
		if absi(line.level - moment.level) == nearest:
			least_used = minf(least_used, _used_share(line))
	var best: Array[Dictionary] = []
	var weights: PackedFloat32Array = PackedFloat32Array()
	for pick: Dictionary in fitting:
		var line: CommentaryBank.Line = pick["line"]
		if absi(line.level - moment.level) == nearest and _used_share(line) <= least_used + 1e-6:
			best.append(pick)
			weights.append(sqrt(float(line.count)))
	return best[_rng.rand_weighted(weights)]


## How much a line has been used for how often he says it: its uses over the square root of its count.
func _used_share(line: CommentaryBank.Line) -> float:
	return float(_uses.get(line.id, 0)) / sqrt(float(maxi(line.count, 1)))


## Whether a line's needs hold for a moment now (BANK_FORMAT.md, "needs").
func needs_met(line: CommentaryBank.Line, moment: RaceMoment, look: RaceLook) -> bool:
	var place: int = look.boards[moment.board].place if moment.board >= 0 and moment.board < look.boards.size() else 0
	for need: String in line.needs:
		var met: bool = false
		match need:
			"leader":
				met = place == 1
			"not_leader":
				met = place > 1
			"podium":
				met = place >= 1 and place <= 3
			"big_lead":
				met = look.lead_m() >= config.big_lead_m and (moment.board < 0 or place == 1)
			"close":
				met = moment.close
			"camera_wide":
				met = camera_wide
			"camera_close":
				met = camera_close
			"many":
				met = look.fleet_size() >= config.many_boards
			"pair":
				met = moment.board2 >= 0
			"last_lap":
				met = moment.board >= 0 and look.on_last_leg(moment.board)
			"windward":
				met = moment.windward > 0
			"leeward":
				met = moment.windward < 0
			"dirty_air":
				met = moment.dirty
			"wind_strong":
				met = not is_nan(look.wind_mean_kt) and look.wind_mean_kt >= config.wind_strong_kt
			"wind_light":
				met = not is_nan(look.wind_mean_kt) and look.wind_mean_kt <= config.wind_light_kt
			"choppy":
				met = not is_nan(look.sea_hs_m) and look.sea_hs_m >= config.choppy_hs_m
			"flat":
				met = not is_nan(look.sea_hs_m) and look.sea_hs_m <= config.flat_hs_m
			_:
				# What only the moment knows (an event week's final or not).
				met = moment.tags.has(need)
		if not met:
			return false
	return true


## A line's words with its slots filled for a moment, or "" when a slot cannot be filled.
func fill(line: CommentaryBank.Line, moment: RaceMoment, look: RaceLook) -> String:
	var text: String = line.text
	for slot: String in line.slots:
		var word: String = slot_word(slot, moment, look)
		if word == "":
			return ""
		text = text.replace("{%s}" % slot, word)
	return text.left(1).to_upper() + text.substr(1)


## The word for a slot (BANK_FORMAT.md, "The slots"), or "" when the game cannot fill it now.
static func slot_word(slot: String, moment: RaceMoment, look: RaceLook) -> String:
	# A word the moment brings itself wins (an event week's {heat}, {round}, {elimination}, {event},
	# and its sailors who are not on the water: the event's leader, the champion).
	if moment.words.has(slot):
		return moment.words[slot]
	var board: RaceLook.Board = look.boards[moment.board] if moment.board >= 0 and moment.board < look.boards.size() else null
	match slot:
		"rider":
			return board.name if board != null else ""
		"rider2":
			return look.boards[moment.board2].name if moment.board2 >= 0 and moment.board2 < look.boards.size() else ""
		"place":
			return CommentaryWords.place_word(moment.place if moment.place > 0 else (board.place if board != null else 0))
		"brand":
			return board.brand if board != null else ""
		"colour":
			return CommentaryWords.colour_word(board.colour) if board != null else ""
		"mark":
			return moment.mark_word
		"leg":
			if board == null or board.finished:
				return ""
			return CommentaryWords.leg_word(look.leg_of(moment.board), look.leg_count())
		"national":
			return board.national if board != null else ""
		"nation_adj":
			return board.nation_adj if board != null else ""
	return ""


## The words as compared for "the same words": lower case, the punctuation and the spaces evened out.
static func words_key(text: String) -> String:
	var key: String = text.to_lower()
	for mark: String in [".", ",", "!", "?", ";", ":", "'"]:
		key = key.replace(mark, "")
	return " ".join(key.split(" ", false))
