class_name CommentaryVoice
extends Node
## The commentary heard (Documentation/reports/broadcast/commentary_voice.md): every line the
## commentary director starts (Commentary.line_started) is spoken by a computer voice and played, at
## the same time as its subtitle as closely as it can.
##
## NOT the commentator's voice: a ready-made, neutral British voice (SpeechEngine), until the real
## commentator says yes (PLAN.md, "When the commentator is asked").
##
## How a line becomes sound:
## - The words are spelled for the voice (CommentaryConfig.voice_spellings: a name the voice says badly
##   gets a spelling it says well; the subtitle keeps the real name).
## - A line already spoken once is on the disk (user://commentary_voice/<voice>/<hash>.wav, by the
##   words and the voice): it plays at once. Otherwise the speech program makes it (a short wait).
## - A line the director has chosen a moment early (the second line of a pair) is made ahead
##   (Commentary.line_ahead), and, when nothing else is waiting, the race's names on their own
##   ("Hana.") and the bank's lines without a slot are made one by one in the background
##   (voice_warm_up_lines), so most lines are on the disk.
## - Too late is dropped, not said late: when the sound is not ready within the line's wait
##   (voice_wait_share of his seconds, between voice_wait_min_s and voice_wait_max_s), the line stays
##   silent (its subtitle shows as always).
## - One voice at a time: a new line, or a line cut short (Commentary.line_stopped), fades the sound
##   out in voice_fade_s (no click).
## - The level changes how it is said: a calm line (1) a little slower, lower and softer, a shouted
##   one (4) a little faster, higher and louder (voice_rate_by_level, voice_db_by_level).
## - The computer voice is often slower than him: when its sound is longer than his `seconds`, the
##   director is told (Commentary.line_lasts), so the next line waits and does not cut it off.
## Its own audio bus, "Commentary" (the volume in Settings > Audio). Frozen (P), it pauses with the race.
## In the race's real seconds: watching at 4x, the voice still speaks at its own pace.

## A line's sound started: its id, the wait since the line started and the sound's length, seconds.
signal sound_started(id: String, wait_s: float, sound_s: float)

const BUS: StringName = &"Commentary"
const CACHE_ROOT: String = "user://commentary_voice"

var commentary: Commentary = null
var config: CommentaryConfig = null
var engine: SpeechEngine = null
## The voice on (it speaks) or off (only the subtitles). The commentary itself switches with V.
var on: bool = true
## The folder of the lines already spoken (an absolute path), for this voice and its numbers.
var cache_dir: String = ""
## The counts: lines heard, played from the disk, made and played, dropped as too late, failed.
var counts: Dictionary[String, int] = {"heard": 0, "from_disk": 0, "made": 0, "late": 0, "failed": 0, "cut": 0}
## The wait from a line's start to its sound, seconds, for every line that was played.
var waits_s: PackedFloat32Array = PackedFloat32Array()

## The line wanted now: its id, the file it waits for, its level and when it started (real µs).
var _want_id: String = ""
var _want_path: String = ""
var _want_level: int = 2
var _want_seconds: float = 0.0
var _want_from_us: int = 0
## The files asked of the speech program and not yet back (path -> true).
var _asked: Dictionary[String, bool] = {}
## The bank's lines to make in the background (their words, the most said first).
var _warm_up: PackedStringArray = PackedStringArray()
## Two players: the one speaking, and the one fading out under the start of the next line.
var _players: Array[AudioStreamPlayer] = []
var _speaking: int = -1
var _speaking_id: String = ""
var _fade_db_per_s: Array[float] = [0.0, 0.0]
var _last_us: int = 0
## --voice_log=1: a line in the log for every line spoken (its wait and its length).
var _log_lines: bool = false


func _init() -> void:
	name = "CommentaryVoice"
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for i: int in 2:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.name = "Voice%d" % i
		player.bus = BUS
		add_child(player)
		_players.append(player)


## Listens to a commentary and speaks with this engine (null: the program is looked for and started
## with the config's voice; when it is not found, the voice stays silent and says so once in the log).
func setup(listen_to: Commentary, speech: SpeechEngine = null) -> void:
	commentary = listen_to
	config = commentary.config
	_log_lines = OS.get_cmdline_user_args().has("--voice_log=1")
	for player: AudioStreamPlayer in _players:
		if AudioServer.get_bus_index(BUS) < 0:
			player.bus = &"Master"
	commentary.line_started.connect(_on_line_started)
	commentary.line_stopped.connect(_on_line_stopped)
	commentary.line_ahead.connect(_on_line_ahead)
	# The volume slider (Settings > Audio > Commentary) on the voice's bus, also outside the sailing
	# scene's own sounds.
	GameAudio.apply_bus_volumes(GameSettings.values)
	engine = speech if speech != null else start_engine(config)
	cache_dir = ProjectSettings.globalize_path(CACHE_ROOT).path_join(cache_name(config))
	DirAccess.make_dir_recursive_absolute(cache_dir)
	if engine != null and config.voice_warm_up_lines > 0 and commentary.bank != null:
		_warm_up = warm_up_list(commentary.bank, config.voice_warm_up_lines)


## The speech program started with the config's voice, or null (and a line in the log) when it is
## not found or does not start.
static func start_engine(tuning: CommentaryConfig) -> SpeechEngine:
	var folder: String = SpeechEngine.find_dir(tuning.voice_name)
	if folder == "":
		print("Commentary voice: no speech program found (looked in %s); the commentary is shown as subtitles only." % ", ".join(SpeechEngine.candidate_dirs()))
		return null
	var speech: SpeechEngine = SpeechEngine.new()
	if not speech.start(folder, tuning.voice_name, tuning.voice_length_scale, tuning.voice_sentence_silence_s, tuning.voice_noise_scale, tuning.voice_noise_w):
		print("Commentary voice: %s; the commentary is shown as subtitles only." % speech.problem)
		return null
	print("Commentary voice: %s with the voice %s (a computer voice, not the commentator's)." % [folder.path_join(SpeechEngine.PROGRAM), tuning.voice_name])
	return speech


## The race's sailors' names on their own ("Hana."), made first in the background: his most said line
## is a name alone, and it is short, so it has the least time to wait for its sound.
func warm_up_names(names: PackedStringArray) -> void:
	var first: PackedStringArray = PackedStringArray()
	for name_said: String in names:
		if name_said != "":
			first.append(name_said.left(1).to_upper() + name_said.substr(1) + ".")
	first.append_array(_warm_up)
	_warm_up = first


## The voice on or off (the subtitles stay as they are).
func set_on(speaking: bool) -> void:
	on = speaking
	if not on:
		_fade_out()
		_want_id = ""


## Whether the voice can speak (the program runs, or a stand-in is there).
func can_speak() -> bool:
	return engine != null


func _exit_tree() -> void:
	if engine != null:
		engine.stop()
		if counts["heard"] > 0:
			print("Commentary voice: %s" % summary())


## The counts and the waits in one line, for the log.
func summary() -> String:
	var sorted: PackedFloat32Array = waits_s.duplicate()
	sorted.sort()
	var waits: String = "no line played"
	if not sorted.is_empty():
		waits = "wait before the sound: middle %.3f s, worst %.3f s" % [sorted[sorted.size() / 2], sorted[-1]]
	return "%d lines heard, %d from the disk, %d made, %d too late (silent), %d failed, %d cut short; %s." % [
		counts["heard"], counts["from_disk"], counts["made"], counts["late"], counts["failed"], counts["cut"], waits]


# ---------------------------------------------------------------- the lines

func _on_line_started(id: String, text: String, seconds: float, level: int) -> void:
	_fade_out()
	_want_id = ""
	if not on or engine == null:
		return
	counts["heard"] += 1
	var spoken: String = SpeechEngine.spoken_words(text, config.voice_spellings)
	var path: String = cache_path(spoken)
	_want_id = id
	_want_path = path
	_want_level = level
	_want_seconds = seconds
	_want_from_us = Time.get_ticks_usec()
	if FileAccess.file_exists(path):
		counts["from_disk"] += 1
		_play_wanted("from the disk")
		return
	_ask(spoken, path)


## The director has chosen a line a moment early (the second of a pair): it is made now.
func _on_line_ahead(_id: String, text: String, _seconds: float, _level: int) -> void:
	if not on or engine == null:
		return
	var spoken: String = SpeechEngine.spoken_words(text, config.voice_spellings)
	var path: String = cache_path(spoken)
	if not FileAccess.file_exists(path):
		_ask(spoken, path)


## A line cut short by a bigger moment (or the commentary switched off): its sound fades out.
func _on_line_stopped(id: String) -> void:
	if id == _want_id:
		_want_id = ""
	if id == _speaking_id:
		counts["cut"] += 1
		_fade_out()


func _ask(spoken: String, path: String) -> void:
	if _asked.has(path):
		return
	_asked[path] = true
	engine.say(spoken, part_path(path))


# ---------------------------------------------------------------- every frame

func _process(_delta: float) -> void:
	# Real seconds (the race may run at 4x; the voice speaks at its own pace).
	var now_us: int = Time.get_ticks_usec()
	var real_dt: float = clampf((now_us - _last_us) / 1e6, 0.0, 0.1) if _last_us > 0 else 0.0
	_last_us = now_us
	_fade(real_dt)
	if engine == null:
		return
	for done: String in engine.finished():
		_file_made(done)
	if _want_id != "" and _want_path != "" and _waited_s() > wait_most_s(_want_seconds, config):
		# Too late to be said with its subtitle: dropped (it is kept on the disk for the next time).
		counts["late"] += 1
		if _log_lines:
			print("Commentary voice: %s too late after %.3f s: silent" % [_want_id, _waited_s()])
		_want_id = ""
	if not _warm_up.is_empty() and _asked.is_empty() and _want_id == "" and engine.waiting() == 0:
		_warm_up_one()


## A file the program finished: it gets its real name (a file is only ever taken from the disk when
## complete) and plays if it is the line wanted now.
func _file_made(part: String) -> void:
	var path: String = part.trim_suffix(".part.wav") + ".wav"
	if FileAccess.file_exists(part):
		DirAccess.rename_absolute(part, path)
	_asked.erase(path)
	if path == _want_path and _want_id != "":
		if FileAccess.file_exists(path):
			counts["made"] += 1
			_play_wanted("made")
		else:
			counts["failed"] += 1
			_want_id = ""


## Plays the wanted line, at its level; tells the commentary how long it really lasts.
func _play_wanted(how: String) -> void:
	var stream: AudioStreamWAV = AudioStreamWAV.load_from_file(_want_path)
	if stream == null:
		counts["failed"] += 1
		DirAccess.remove_absolute(_want_path)  # a broken file is made again the next time
		_want_id = ""
		return
	var wait_s: float = _waited_s()
	var rate: float = level_value(config.voice_rate_by_level, _want_level, 1.0)
	_speaking = 0 if _speaking != 0 else 1
	var player: AudioStreamPlayer = _players[_speaking]
	_fade_db_per_s[_speaking] = 0.0
	player.stream = stream
	player.pitch_scale = rate
	player.volume_db = level_value(config.voice_db_by_level, _want_level, 0.0)
	player.play()
	_speaking_id = _want_id
	var sound_s: float = stream.get_length() / rate
	waits_s.append(wait_s)
	if commentary != null:
		commentary.line_lasts(_want_id, wait_s + sound_s)
	sound_started.emit(_want_id, wait_s, sound_s)
	if _log_lines:
		print("Commentary voice: %s after %.3f s (%s), %.2f s of sound at level %d" % [_want_id, wait_s, how, sound_s, _want_level])
	_want_id = ""


## The sound speaking now fades out (a new line, a line cut short).
func _fade_out() -> void:
	if _speaking >= 0 and _players[_speaking].playing:
		_fade_db_per_s[_speaking] = 60.0 / maxf(config.voice_fade_s if config != null else 0.06, 0.005)
	_speaking_id = ""


## The fading player goes down 60 dB over voice_fade_s, then stops.
func _fade(delta: float) -> void:
	for i: int in _players.size():
		if _fade_db_per_s[i] <= 0.0:
			continue
		var player: AudioStreamPlayer = _players[i]
		player.volume_db -= _fade_db_per_s[i] * maxf(delta, 1.0 / 240.0)  # at least a step a frame
		if player.volume_db <= -60.0 or not player.playing:
			player.stop()
			_fade_db_per_s[i] = 0.0


func _waited_s() -> float:
	return (Time.get_ticks_usec() - _want_from_us) / 1e6


func _warm_up_one() -> void:
	while not _warm_up.is_empty():
		var spoken: String = SpeechEngine.spoken_words(_warm_up[0], config.voice_spellings)
		_warm_up.remove_at(0)
		var path: String = cache_path(spoken)
		if not FileAccess.file_exists(path):
			_ask(spoken, path)
			return


# ---------------------------------------------------------------- the rules, for the tests

## The file of a line's sound on the disk: by its words, the voice and the voice's numbers.
func cache_path(spoken: String) -> String:
	return cache_dir.path_join(line_key(spoken, config) + ".wav")


## The file the program writes first (renamed when it is complete).
static func part_path(path: String) -> String:
	return path.trim_suffix(".wav") + ".part.wav"


## A line's name on the disk: a hash of its words with the voice and the numbers that change its sound.
static func line_key(spoken: String, tuning: CommentaryConfig) -> String:
	var key: String = "%s|%.3f|%.3f|%.3f|%.3f|%s" % [tuning.voice_name, tuning.voice_length_scale,
		tuning.voice_sentence_silence_s, tuning.voice_noise_scale, tuning.voice_noise_w, spoken]
	return key.sha256_text().left(32)


## The cache's folder name for a voice.
static func cache_name(tuning: CommentaryConfig) -> String:
	return tuning.voice_name.validate_filename()


## How long a line's sound may be waited for: voice_wait_share of his seconds, between the least and
## the most wait (a short "Wow." late is wrong; a long sentence a little late is still right).
static func wait_most_s(seconds: float, tuning: CommentaryConfig) -> float:
	return clampf(seconds * tuning.voice_wait_share, tuning.voice_wait_min_s, tuning.voice_wait_max_s)


## A level's value from a table of four (levels 1 to 4), or `fallback`.
static func level_value(table: PackedFloat32Array, level: int, fallback: float) -> float:
	var at: int = clampi(level, 1, 4) - 1
	return table[at] if at < table.size() else fallback


## The bank's lines without a slot, the most said first, at most `most` of them: the lines worth
## making before they are needed.
static func warm_up_list(bank: CommentaryBank, most: int) -> PackedStringArray:
	var lines: Array[CommentaryBank.Line] = []
	for line: CommentaryBank.Line in bank.lines:
		if line.slots.is_empty():
			lines.append(line)
	lines.sort_custom(func(a: CommentaryBank.Line, b: CommentaryBank.Line) -> bool: return a.count > b.count)
	var words: PackedStringArray = PackedStringArray()
	for line: CommentaryBank.Line in lines.slice(0, most):
		words.append(line.text.left(1).to_upper() + line.text.substr(1))
	return words
