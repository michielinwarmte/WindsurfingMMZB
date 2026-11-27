extends GutTest
## The commentary's voice (Documentation/reports/broadcast/commentary_voice.md): a line asked of the
## speech program and played when its sound is made; a line on the disk played at once; too late
## dropped, not said late; a new line or a line cut short fading the sound out; the level's rate and
## loudness; a pair's second line made ahead; the names spelled for the voice; the director waiting
## for a voice slower than him; the missing program (silent, no error). A stand-in takes the speech
## program's place (FakeSpeech): no program runs and no real sound is heard here.

const TEST_DIR: String = "user://test_commentary_voice"

## The speech program's stand-in: it notes what it is asked, and finish() writes a short silent WAV
## where the program would and answers with its path.
class FakeSpeech:
	extends SpeechEngine
	var asked: Array[Dictionary] = []
	var answers: PackedStringArray = PackedStringArray()
	var open: int = 0

	func say(text: String, out_path: String) -> void:
		asked.append({"text": text, "path": out_path})
		open += 1

	func finished() -> PackedStringArray:
		var out: PackedStringArray = answers
		answers = PackedStringArray()
		return out

	func waiting() -> int:
		return open

	func stop() -> void:
		pass

	## The n-th line asked is made: `seconds` of silence in its file.
	func finish(n: int, seconds: float = 0.5) -> void:
		write_silence(asked[n]["path"], seconds)
		answers.append(asked[n]["path"])
		open -= 1

	static func write_silence(path: String, seconds: float) -> void:
		var stream: AudioStreamWAV = AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = 22050
		stream.stereo = false
		var data: PackedByteArray = PackedByteArray()
		data.resize(int(22050 * seconds) * 2)
		stream.data = data
		stream.save_to_wav(path)


var _speech: FakeSpeech
var _commentary: Commentary
var _voice: CommentaryVoice


func before_each() -> void:
	_speech = FakeSpeech.new()
	_commentary = Commentary.new()
	_commentary.config = (load(Commentary.CONFIG_PATH) as CommentaryConfig).duplicate(true)
	_commentary.config.voice_warm_up_lines = 0
	_commentary.config.voice_spellings = {} as Dictionary[String, String]
	_commentary.config.voice_wait_min_s = 5.0
	_commentary.config.voice_wait_max_s = 5.0
	_commentary.bank = CommentaryBank.from_json(JSON.stringify({"format": 1, "lines": []}), "test")
	_commentary.director = CommentaryDirector.new(_commentary.bank, _commentary.config, 1)
	add_child_autofree(_commentary)
	_voice = _commentary.add_voice(_speech)
	_voice.cache_dir = ProjectSettings.globalize_path(TEST_DIR)
	DirAccess.make_dir_recursive_absolute(_voice.cache_dir)
	_empty_the_test_folder()


func after_each() -> void:
	_empty_the_test_folder()


func _empty_the_test_folder() -> void:
	var folder: String = ProjectSettings.globalize_path(TEST_DIR)
	for file: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file))


func _say(id: String, text: String, level: int = 2, seconds: float = 2.0) -> void:
	_commentary.line_started.emit(id, text, seconds, level)


func _playing() -> Array[AudioStreamPlayer]:
	var players: Array[AudioStreamPlayer] = []
	for player: AudioStreamPlayer in _voice._players:
		if player.playing:
			players.append(player)
	return players


# ---------------------------------------------------------------- a line becomes sound

func test_a_line_is_asked_of_the_program_and_played_when_made() -> void:
	_say("L1", "Here we go. Look at that.")
	assert_eq(_speech.asked.size(), 1, "asked of the speech program")
	assert_eq(_speech.asked[0]["text"], "Here we go. Look at that.")
	assert_true(String(_speech.asked[0]["path"]).ends_with(".part.wav"), "written under a temporary name first")
	assert_eq(_playing().size(), 0, "nothing to play before it is made")
	_speech.finish(0, 0.8)
	_voice._process(0.016)
	assert_eq(_playing().size(), 1, "played when made")
	assert_eq(_voice.counts["made"], 1)
	var kept: String = _voice.cache_path("Here we go. Look at that.")
	assert_true(FileAccess.file_exists(kept), "kept on the disk under its real name")
	assert_false(FileAccess.file_exists(CommentaryVoice.part_path(kept)), "the temporary name is gone")


func test_a_line_on_the_disk_plays_at_once_without_the_program() -> void:
	FakeSpeech.write_silence(_voice.cache_path("Hana gets the bullet."), 0.6)
	_say("L1", "Hana gets the bullet.")
	assert_eq(_speech.asked.size(), 0, "not asked again")
	assert_eq(_playing().size(), 1, "played at once")
	assert_eq(_voice.counts["from_disk"], 1)
	assert_almost_eq(_voice.waits_s[0], 0.0, 0.05, "no wait")


func test_the_same_words_are_the_same_file_and_other_numbers_another() -> void:
	var config: CommentaryConfig = _commentary.config
	var key: String = CommentaryVoice.line_key("Wow.", config)
	assert_eq(CommentaryVoice.line_key("Wow.", config), key, "the same words: the same file")
	assert_ne(CommentaryVoice.line_key("Oh no.", config), key, "other words: another file")
	var slower: CommentaryConfig = config.duplicate(true)
	slower.voice_length_scale = 1.2
	assert_ne(CommentaryVoice.line_key("Wow.", slower), key, "the voice's numbers changed: made again")


func test_too_late_is_dropped_not_said_late() -> void:
	_commentary.config.voice_wait_min_s = 0.0
	_commentary.config.voice_wait_max_s = 0.0
	_say("L1", "Oh no. Noor has just nearly took out Mara.")
	OS.delay_usec(2000)
	_voice._process(0.016)
	assert_eq(_voice.counts["late"], 1, "not made in time: dropped")
	_speech.finish(0, 0.5)
	_voice._process(0.016)
	assert_eq(_playing().size(), 0, "not said late")
	assert_true(FileAccess.file_exists(_voice.cache_path("Oh no. Noor has just nearly took out Mara.")), "kept for the next time")


func test_the_wait_allowed_grows_with_the_line_between_its_limits() -> void:
	var config: CommentaryConfig = CommentaryConfig.new()
	config.voice_wait_share = 0.3
	config.voice_wait_min_s = 0.3
	config.voice_wait_max_s = 0.8
	assert_almost_eq(CommentaryVoice.wait_most_s(0.5, config), 0.3, 1e-6, "a short 'Wow.': the least")
	assert_almost_eq(CommentaryVoice.wait_most_s(2.0, config), 0.6, 1e-6, "a 2 s line: 30 %")
	assert_almost_eq(CommentaryVoice.wait_most_s(6.0, config), 0.8, 1e-6, "a long line: the most")


# ---------------------------------------------------------------- one voice at a time

func test_a_new_line_fades_the_one_before_out() -> void:
	FakeSpeech.write_silence(_voice.cache_path("First line."), 3.0)
	FakeSpeech.write_silence(_voice.cache_path("Second line."), 3.0)
	_say("A", "First line.")
	var first: AudioStreamPlayer = _playing()[0]
	_say("B", "Second line.")
	assert_eq(_playing().size(), 2, "the first fades under the start of the second")
	_voice._fade(0.03)
	assert_true(first.playing, "half way through the fade")
	assert_lt(first.volume_db, -20.0, "and quieter")
	_voice._fade(0.05)
	assert_false(first.playing, "faded out")
	assert_eq(_playing().size(), 1, "one voice")


func test_a_line_cut_short_fades_out() -> void:
	FakeSpeech.write_silence(_voice.cache_path("Then we've got Kofi."), 3.0)
	_say("A", "Then we've got Kofi.")
	_commentary.line_stopped.emit("A")
	_voice._fade(0.1)
	assert_eq(_playing().size(), 0, "cut short with a fade, no click")
	assert_eq(_voice.counts["cut"], 1)


func test_a_line_cut_before_its_sound_came_is_not_played() -> void:
	_say("A", "Then we've got Kofi.")
	_commentary.line_stopped.emit("A")
	_speech.finish(0)
	_voice._process(0.016)
	assert_eq(_playing().size(), 0)


func test_the_voice_switched_off_is_silent_and_the_subtitles_go_on() -> void:
	_voice.set_on(false)
	_say("A", "Here we go.")
	assert_eq(_speech.asked.size(), 0, "nothing asked")
	assert_eq(_playing().size(), 0)
	assert_false(_commentary.voice_on())


# ---------------------------------------------------------------- how it is said

func test_the_level_sets_the_rate_and_the_loudness() -> void:
	var config: CommentaryConfig = _commentary.config
	FakeSpeech.write_silence(_voice.cache_path("Calm."), 1.0)
	FakeSpeech.write_silence(_voice.cache_path("Shouting!"), 1.0)
	_say("A", "Calm.", 1)
	var calm: AudioStreamPlayer = _playing()[0]
	assert_almost_eq(calm.pitch_scale, config.voice_rate_by_level[0], 1e-5)
	assert_almost_eq(calm.volume_db, config.voice_db_by_level[0], 1e-5)
	_commentary.line_stopped.emit("A")
	_voice._fade(1.0)
	_say("B", "Shouting!", 4)
	var shout: AudioStreamPlayer = _playing()[0]
	assert_almost_eq(shout.pitch_scale, config.voice_rate_by_level[3], 1e-5)
	assert_almost_eq(shout.volume_db, config.voice_db_by_level[3], 1e-5)
	assert_gt(config.voice_rate_by_level[3], config.voice_rate_by_level[0], "a shout a little faster and higher")
	assert_gt(config.voice_db_by_level[3], config.voice_db_by_level[0], "and louder")
	assert_lt(config.voice_rate_by_level[3], 1.15, "modest: not a cartoon")


func test_a_pairs_second_line_is_made_ahead() -> void:
	_commentary.line_ahead.emit("P2", "Hana gets the bullet.", 1.5, 3)
	assert_eq(_speech.asked.size(), 1, "made while the first line is said")
	_speech.finish(0)
	_voice._process(0.016)
	_say("P2", "Hana gets the bullet.", 3)
	assert_eq(_voice.counts["from_disk"], 1, "ready when its turn comes")
	assert_eq(_playing().size(), 1)


func test_names_are_spelled_for_the_voice_and_shown_as_they_are() -> void:
	var spellings: Dictionary[String, String] = {"Noe": "Noah", "Guivarc": "Gee-varc"}
	assert_eq(SpeechEngine.spoken_words("Noe Roussel gets the bullet.", spellings), "Noah Roussel gets the bullet.")
	assert_eq(SpeechEngine.spoken_words("Lucien Guivarc.", spellings), "Lucien Gee-varc.")
	assert_eq(SpeechEngine.spoken_words("Noel is not Noe.", spellings), "Noel is not Noah.", "whole words only")
	_commentary.config.voice_spellings = spellings
	_say("A", "Noe Roussel gets the bullet.")
	assert_eq(_speech.asked[0]["text"], "Noah Roussel gets the bullet.", "the voice gets the spelling")


func test_the_warm_up_takes_the_lines_without_a_slot_most_said_first() -> void:
	var bank: CommentaryBank = CommentaryBank.from_json(JSON.stringify({"format": 1, "lines": [
		{"id": "A", "moment": "filler", "text": "hardcore racing.", "slots": [], "level": 2, "seconds": 1.0, "count": 2, "needs": [], "src": "t"},
		{"id": "B", "moment": "identify", "text": "{rider}.", "slots": ["rider"], "level": 2, "seconds": 1.0, "count": 9, "needs": [], "src": "t"},
		{"id": "C", "moment": "start_gun", "text": "Here we go.", "slots": [], "level": 3, "seconds": 1.0, "count": 5, "needs": [], "src": "t"},
	]}), "test")
	var words: PackedStringArray = CommentaryVoice.warm_up_list(bank, 10)
	assert_eq(words, PackedStringArray(["Here we go.", "Hardcore racing."]), "no slot, the most said first, as said")
	assert_eq(CommentaryVoice.warm_up_list(bank, 1).size(), 1, "at most the number asked")


func test_the_warm_up_makes_one_line_at_a_time_when_nothing_waits() -> void:
	_voice._warm_up = PackedStringArray(["Here we go.", "Hardcore racing."])
	_voice._process(0.016)
	assert_eq(_speech.asked.size(), 1, "one line")
	_voice._process(0.016)
	assert_eq(_speech.asked.size(), 1, "not the next while it is made")
	_speech.finish(0)
	_voice._process(0.016)
	_voice._process(0.016)
	assert_eq(_speech.asked.size(), 2, "then the next")


func test_the_race_names_alone_are_made_first() -> void:
	_voice._warm_up = PackedStringArray(["Here we go."])
	_voice.warm_up_names(PackedStringArray(["Hana", "", "noor"]))
	assert_eq(_voice._warm_up, PackedStringArray(["Hana.", "Noor.", "Here we go."]), "as the director says them, before the bank's lines")


# ---------------------------------------------------------------- the director waits for the voice

func test_the_director_waits_for_a_voice_slower_than_him() -> void:
	var config: CommentaryConfig = CommentaryConfig.new()
	config.pause_min_s = 0.5
	config.pause_max_s = 0.5
	var bank: CommentaryBank = CommentaryBank.from_json(JSON.stringify({"format": 1, "lines": [
		{"id": "G", "moment": "start_gun", "text": "Here we go.", "slots": [], "level": 3, "seconds": 1.0, "count": 1, "needs": [], "src": "t"},
		{"id": "F", "moment": "after_race", "text": "What a race.", "slots": [], "level": 2, "seconds": 1.0, "count": 1, "needs": [], "src": "t"},
	]}), "test")
	var director: CommentaryDirector = CommentaryDirector.new(bank, config, 1)
	var look: RaceLook = RaceLook.new()
	var started: Array[String] = []
	director.line_started.connect(func(id: String, _text: String, _seconds: float, _level: int) -> void: started.append(id))
	director.hear([RaceMoment.make("start_gun", -1), RaceMoment.make("after_race", -1)])
	director.step(0.1, look, null)
	assert_eq(started, ["G"] as Array[String])
	director.line_lasts("G", 2.0)  # the voice's sound: 2 s, his: 1 s
	for k: int in 19:
		director.step(0.1, look, null)
	assert_true(director.is_saying(), "still saying it at 2 s")
	for k: int in 4:
		director.step(0.1, look, null)
	assert_eq(started.size(), 1, "the breath after the voice's end, not his")
	for k: int in 3:
		director.step(0.1, look, null)
	assert_eq(started, ["G", "F"] as Array[String], "then the next line")
	director.line_lasts("G", 9.0)
	assert_eq(director.saying_id, "F", "a line no longer said is not lengthened")


func test_the_voice_tells_the_director_how_long_its_sound_lasts() -> void:
	var told: Array[float] = []
	_voice.sound_started.connect(func(_id: String, wait_s: float, sound_s: float) -> void: told.append(wait_s + sound_s))
	FakeSpeech.write_silence(_voice.cache_path("Here we go."), 1.25)
	_say("G", "Here we go.", 2)
	assert_eq(told.size(), 1)
	assert_almost_eq(told[0], 1.25 / _commentary.config.voice_rate_by_level[1], 0.05, "its sound's length at its rate")


# ---------------------------------------------------------------- no program

func test_without_the_program_the_commentary_is_silent_without_an_error() -> void:
	var config: CommentaryConfig = CommentaryConfig.new()
	config.voice_name = "no_such_voice"
	assert_null(CommentaryVoice.start_engine(config), "not found: no engine")
	assert_false(SpeechEngine.has_program("", "no_such_voice"))
	assert_eq(SpeechEngine.find_dir("no_such_voice"), "")
	var engine: SpeechEngine = SpeechEngine.new()
	assert_false(engine.start(ProjectSettings.globalize_path(TEST_DIR), "no_such_voice", 1.0, 0.2, 0.667, 0.8), "an empty folder does not start")
	assert_ne(engine.problem, "", "and says why")
	var silent: Commentary = Commentary.new()
	silent.config = _commentary.config.duplicate(true)
	silent.config.voice_name = "no_such_voice"
	silent.bank = _commentary.bank
	add_child_autofree(silent)
	var voice: CommentaryVoice = silent.add_voice(null)
	assert_false(voice.can_speak(), "found no program: cannot speak")
	silent.line_started.emit("A", "Here we go.", 1.0, 2)
	voice._process(0.016)
	assert_eq(voice.counts["heard"], 0, "the line is not even waited for")
	assert_false(silent.voice_on())


func test_the_game_looks_beside_its_executable_last() -> void:
	var folders: PackedStringArray = SpeechEngine.candidate_dirs()
	assert_eq(folders[-1], OS.get_executable_path().get_base_dir().path_join("tts"), "a play folder's tts/")
