class_name CommentaryRun
extends RefCounted

## The stand-in camera below follows the 12 November director's rules (TvCamera's old logic), with its
## numbers from their resource: the transcript only needs to know which board and shot are on the
## screen. The stream's director (TvStreamDirector) is not modelled here yet.
const OLD_DIRECTOR: TvDirector12NovConfig = preload("res://config/tv_director_12nov.tres")
## The commentary of a headless race, written down (tools/race.sh ... --commentary=1): the same race
## story (RaceStory) and the same commentary director (CommentaryDirector) as in the game's watch mode,
## on the race tool's boards, and a time-coded transcript of what he said: the race time, the moment,
## the line's id and its words, then in brackets the shot and the board on the screen, and what the
## story measured. At the end what the director heard and what became of it, and the pace.
## The transcript goes to .sim_output/commentary/ (ignored by git), to read the pace and the choices of
## a whole race without watching it.
##
## There is no camera headless, so a stand-in for the TV director (Camera, below) picks the board and
## the shot the way TvCamera does, with its own rules and numbers: the start's wide shot and the
## committee boat, the leaders leaving the line, the finish line, the front at a mark, and between them
## a cut every 7 to 12 s to the board worth watching. The director's clock is the race clock here.

var config: CommentaryConfig
var bank: CommentaryBank
var story: RaceStory
var director: CommentaryDirector
var camera: Camera = Camera.new()
var path: String = ""

var _file: FileAccess = null
var _look: RaceLook = null
var _look_left_s: float = 0.0
var _names: PackedStringArray
var _brands: PackedStringArray
var _colours: PackedColorArray
## What was heard and said, by moment; the seconds he talked.
var _heard: Dictionary[String, int] = {}
var _said: Dictionary[String, int] = {}
var _talk_s: float = 0.0
var _first_s: float = INF
var _last_s: float = -INF
## The roundings of the races before an R (each race has its own story).
var _rounding_notes: PackedStringArray = PackedStringArray()


## The transcript at `out_path`, headed by `heading`; the boards' names, their sails' brands and colours
## (by race number); `dice` fixes the director's choices (the same race, the same commentary).
func _init(out_path: String, heading: String, names: PackedStringArray, brands: PackedStringArray, colours: PackedColorArray, dice: int) -> void:
	path = out_path
	_names = names
	_brands = brands
	_colours = colours
	config = load(Commentary.CONFIG_PATH) as CommentaryConfig
	bank = CommentaryBank.load_file()
	bank.warn_problems()
	story = RaceStory.new(config)
	director = CommentaryDirector.new(bank, config, dice)
	director.line_started.connect(_on_line_started)
	camera.seed_with(dice)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	_file = FileAccess.open(path, FileAccess.WRITE)
	if _file == null:
		push_error("Cannot write the commentary transcript to %s." % path)
		return
	_file.store_line("# The commentary of a headless race (tools/race.sh --commentary=1), %s" % Time.get_datetime_string_from_system(false, true))
	_file.store_line("# " + heading)
	_file.store_line("# The bank: %s, %d lines (%s)%s" % [bank.origin, bank.size(), bank.source, "" if bank.problems.is_empty() else "; %d problems" % bank.problems.size()])
	_file.store_line("# race time | moment | line | the words   [the shot on the board on the screen; what the story measured]")
	_file.store_line("")


## One tick of the race (dt race seconds), after the race has stepped: the story looks every
## look_every_s, the camera stand-in cuts, the director speaks.
func tick(race: RaceSim, telemetry: Array[Telemetry], dirty: PackedFloat32Array, dt: float) -> void:
	_look_left_s -= dt
	if _look_left_s <= 0.0:
		_look_left_s = config.look_every_s
		_look = RaceLook.of_race(race, telemetry, _names, _brands, _colours, dirty)
		var moments: Array[RaceMoment] = story.look(_look)
		for moment: RaceMoment in moments:
			_heard[moment.moment] = _heard.get(moment.moment, 0) + 1
		director.hear(moments)
		camera.step(config.look_every_s, _look)
	if _look == null:
		return
	director.focus = camera.focus
	director.camera_wide = Commentary.is_wide(camera.shot)
	director.camera_close = Commentary.is_close(camera.shot)
	director.step(dt, _look, story)


## The game's R (--restart_after): a new race, a new story and camera; the lines said stay remembered.
func new_race() -> void:
	_rounding_notes.append_array(story.rounding_notes)
	story = RaceStory.new(config)
	director.new_race()
	var dice: int = camera._rng.seed
	camera = Camera.new()
	camera._rng.seed = dice
	_look = null
	if _file != null:
		_file.store_line("")
		_file.store_line("# ---- R: a new race")


## The summary at the end: the moments heard and said, what was dropped, the pace.
func finish() -> void:
	if _file == null:
		return
	var counts: Dictionary[String, int] = director.counts
	_file.store_line("")
	_file.store_line("# ---- The summary")
	var span_s: float = maxf(_last_s - _first_s, 1.0)
	_file.store_line("# Lines said: %d (%d of them small talk) from %s to %s: %.1f a minute; he talked %.0f %% of that time." % [
		counts["said"], counts["quiet"], clock(_first_s), clock(_last_s), counts["said"] * 60.0 / span_s, 100.0 * _talk_s / span_s])
	_file.store_line("# Moments heard: %d; dropped as too late: %d; no line fitted: %d; lines cut short by a bigger moment: %d." % [
		counts["heard"], counts["late"], counts["no_line"], counts["cut"]])
	var moments: PackedStringArray = PackedStringArray()
	for moment: String in CommentaryBank.MOMENTS:
		if _heard.has(moment) or _said.has(moment):
			moments.append("%s %d/%d" % [moment, _said.get(moment, 0), _heard.get(moment, 0)])
	_file.store_line("# Said / heard by moment (small talk is not heard, only said): " + ", ".join(moments))
	_file.store_line("# The day as the story measured it at the end: the wind's mean %.1f kt (wind_strong from %.0f, wind_light to %.0f), the sea's significant wave height %.2f m (choppy from %.2f, flat to %.2f)." % [
		story.wind_mean_kt, config.wind_strong_kt, config.wind_light_kt, story.sea_hs_m, config.choppy_hs_m, config.flat_hs_m])
	_file.store_line("# The roundings watched (RaceStory: from %.0f m before the mark to %.0f s after the stern went through the wind, or %.0f s after the mark without a gybe):" % [
		config.rounding_from_m, config.gybe_exit_s, config.gybe_wait_s])
	for note: String in _rounding_notes + story.rounding_notes:
		_file.store_line("#   " + note)
	_file.close()
	_file = null
	print("COMMENTARY transcript: %s (%d lines)" % [ProjectSettings.globalize_path(path), counts["said"]])


func _on_line_started(id: String, text: String, seconds: float, _level: int) -> void:
	var moment: RaceMoment = director.saying
	var race_s: float = _look.clock_s if _look != null else 0.0
	_said[moment.moment] = _said.get(moment.moment, 0) + 1
	_talk_s += seconds
	_first_s = minf(_first_s, race_s)
	_last_s = maxf(_last_s, race_s + seconds)
	var shown: String = "%s on %s" % [TvCamera.Shot.keys()[camera.shot], _look.name_of(camera.focus) if camera.focus >= 0 else "-"]
	var about: String = moment.describe(_look)
	var note: String = "; " + moment.note if moment.note != "" else ""
	if _file != null:
		_file.store_line("%8s  %-13s %-8s %-62s [%s; %s%s]" % [clock(race_s), moment.moment, id, text, shown, about, note])


## A race time as the transcript writes it: "-0:52.3" in the countdown, "3:07.9" after the gun.
static func clock(seconds: float) -> String:
	return RaceStory.clock_text(seconds)


## The board and the shot on the screen, chosen as TvCamera chooses them (its rules and numbers), from
## the race alone: there is no camera headless. Its clock is the race clock.
class Camera:
	var shot: TvCamera.Shot = TvCamera.Shot.ORBIT
	var focus: int = -1
	var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var _clock_s: float = 0.0
	var _age_s: float = 0.0
	var _left_s: float = 0.0
	var _start_part: int = -1
	var _finish_hold_s: float = 0.0
	var _mark_steps: int = 0
	var _rounded_age_s: float = -1.0
	var _marks_shown: Dictionary[int, int] = {}
	var _places: Dictionary[int, int] = {}
	var _gained_at: Dictionary[int, float] = {}

	func seed_with(dice: int) -> void:
		_rng.seed = dice + 7

	func step(dt: float, look: RaceLook) -> void:
		_clock_s += dt
		_age_s += dt
		_left_s -= dt
		if look.order.is_empty():
			return
		_note_places(look)
		var part: int = TvCamera.start_part(look.started, look.clock_s, look.over, OLD_DIRECTOR)
		if part != _start_part:
			_start_part = part
			if part >= 0:
				_cut_to_the_start(look, part)
				return
			_left_s = 0.0
		if part >= 0:
			return
		if _finish_line(look, dt) or _front_at_a_mark(look):
			return
		var gone: bool = focus < 0 or not look.order.has(focus)
		if shot == TvCamera.Shot.MARK and not gone and _mark_shot_goes_on(look):
			return
		if _left_s > 0.0 and not gone:
			return
		_cut_to_a_story(look)

	func _cut(next: TvCamera.Shot, board: int, look: RaceLook) -> void:
		shot = next
		focus = board
		_age_s = 0.0
		_rounded_age_s = -1.0
		if board >= 0:
			_mark_steps = look.boards[board].next_step

	func _cut_to_the_start(look: RaceLook, part: int) -> void:
		if part == 2:
			var leader: int = look.order[0]
			_cut(TvCamera.Shot.GROUP if _has_company(look, leader) else TvCamera.Shot.ORBIT, leader, look)
			return
		var middle: Vector2 = (look.step_points[0][0] + look.step_points[0][1]) * 0.5
		var best: int = look.order[0]
		for index: int in look.order:
			if look.boards[index].position.distance_to(middle) < look.boards[best].position.distance_to(middle):
				best = index
		_cut(TvCamera.Shot.START_WIDE if part == 0 else TvCamera.Shot.COMMITTEE, best, look)

	func _finish_line(look: RaceLook, dt: float) -> bool:
		if not look.racing:
			return false
		var leader: int = look.order[0]
		if shot == TvCamera.Shot.FINISH_LINE:
			if look.boards[focus].finished:
				_finish_hold_s += dt
				if _finish_hold_s > OLD_DIRECTOR.finish_hold_s:
					_left_s = 0.0
					return false
			return true
		if look.on_last_leg(leader) and look.boards[leader].to_next_m < OLD_DIRECTOR.finish_m:
			_finish_hold_s = 0.0
			_cut(TvCamera.Shot.FINISH_LINE, leader, look)
			return true
		return false

	func _front_at_a_mark(look: RaceLook) -> bool:
		if not look.racing or _age_s < OLD_DIRECTOR.mark_cut_after_s:
			return false
		if shot == TvCamera.Shot.MARK and focus >= 0 and _mark_shot_goes_on(look):
			return false
		for place: int in mini(OLD_DIRECTOR.mark_front, look.order.size()):
			var index: int = look.order[place]
			var board: RaceLook.Board = look.boards[index]
			if board.finished or not look.next_is_a_mark(index):
				continue
			if board.to_next_m >= OLD_DIRECTOR.mark_soon_m or _marks_shown.get(index, -1) == board.next_step:
				continue
			for other: int in look.order:
				if look.boards[other].next_step == board.next_step and look.boards[other].position.distance_to(board.position) < OLD_DIRECTOR.group_m:
					_marks_shown[other] = board.next_step
			_cut(TvCamera.Shot.MARK, index, look)
			return true
		return false

	func _mark_shot_goes_on(look: RaceLook) -> bool:
		if _age_s > OLD_DIRECTOR.mark_max_s:
			return false
		if look.boards[focus].next_step > _mark_steps:
			if _rounded_age_s < 0.0:
				_rounded_age_s = _age_s
			return _age_s - _rounded_age_s < OLD_DIRECTOR.mark_after_s
		return true

	func _cut_to_a_story(look: RaceLook) -> void:
		var positions: PackedVector2Array = PackedVector2Array()
		var to_mark: PackedFloat32Array = PackedFloat32Array()
		var finished: PackedByteArray = PackedByteArray()
		var gained: PackedByteArray = PackedByteArray()
		var late: PackedByteArray = PackedByteArray()
		for index: int in look.order:
			var board: RaceLook.Board = look.boards[index]
			positions.append(board.position)
			to_mark.append(board.to_next_m if look.racing and look.next_is_a_mark(index) else INF)
			finished.append(1 if board.finished or board.retired else 0)
			gained.append(1 if _gained_at.has(index) and _clock_s - _gained_at[index] < OLD_DIRECTOR.gained_s else 0)
			late.append(1 if look.racing and board.next_step == 0 else 0)
		var weights: PackedFloat32Array = TvCamera.story_weights(positions, to_mark, finished, gained, late, look.order.find(focus), OLD_DIRECTOR)
		var at: int = _rng.rand_weighted(weights)
		var pick: int = look.order[at]
		_cut(TvCamera.pick_shot(to_mark[at] < OLD_DIRECTOR.mark_m, _has_company(look, pick), shot, _rng.randf(), OLD_DIRECTOR), pick, look)
		_left_s = _rng.randf_range(OLD_DIRECTOR.shot_min_s, OLD_DIRECTOR.shot_max_s)

	func _has_company(look: RaceLook, index: int) -> bool:
		for other: int in look.order:
			if other != index and not look.boards[other].finished and look.boards[other].position.distance_to(look.boards[index].position) < OLD_DIRECTOR.close_m:
				return true
		return false

	func _note_places(look: RaceLook) -> void:
		if not look.racing:
			_places.clear()
			return
		for place: int in look.order.size():
			var index: int = look.order[place]
			if _places.has(index) and place < _places[index] and not look.boards[index].finished:
				_gained_at[index] = _clock_s
			_places[index] = place
