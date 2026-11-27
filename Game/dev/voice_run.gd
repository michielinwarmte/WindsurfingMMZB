extends SceneTree
## The commentary's computer voice without ears (Documentation/reports/broadcast/commentary_voice.md):
## speaks a list of lines to WAV files through the game's own speech engine (SpeechEngine, the same
## program, voice, numbers and name spellings as the game), one line at a time, and writes for each
## line whether it was made, the seconds of sound and the seconds it took. The WAV files are then read
## back with Whisper (tools/tts/read_back.py) to see whether the words come out right.
##
##   tools/tts/speak_lines.sh --out=<folder> [--tts_dir=<folder>] [--names=<file>] [--count=<n>]
##
## The lines: every line of the commentary bank with its slots filled (the riders' names taken in turn
## from the game's 20 characters and the --names file, one name a line; the brands from the game's
## catalogue), then every name alone ("Hana.", his most said line is a name on its own) and every name
## in a sentence. --count=<n> speaks only the first n lines (a quick check). The program is found as
## the game finds it (SpeechEngine.find_dir: --tts_dir, MMZB_TTS_DIR, tts/ beside the executable).
## Writes <out>/manifest.json (a list: id, kind, name, text as shown, spoken as given to the voice,
## wav, made, sound_s, took_s) and prints a summary; the sounds are <out>/wav/<n>.wav. The cache of the
## game is not used: every line is made afresh, so took_s is the wait for a line not yet on the disk.

const CHARACTERS_FOLDER: String = "res://race/personas"
## The commentary's numbers (Commentary.CONFIG_PATH; not named here, so this tool needs no scene).
const CONFIG_PATH: String = "res://config/commentary_default.tres"

var _config: CommentaryConfig
var _engine: SpeechEngine = SpeechEngine.new()
var _out: String = ""
var _items: Array[Dictionary] = []
var _next: int = 0
var _asked_us: int = 0
var _started_us: int = 0
var _failed_start: bool = false


func _initialize() -> void:
	var options: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
			options[parts[0]] = parts[1]
	_out = options.get("out", ProjectSettings.globalize_path("res://../.sim_output/voice"))
	DirAccess.make_dir_recursive_absolute(_out.path_join("wav"))
	_config = load(CONFIG_PATH) as CommentaryConfig
	var names: PackedStringArray = character_names()
	if options.has("names"):
		for line: String in FileAccess.get_file_as_string(options["names"]).split("\n", false):
			if line.strip_edges() != "":
				names.append(line.strip_edges())
	_items = lines_to_speak(CommentaryBank.load_file(), names, sail_brands())
	if options.has("count"):
		_items = _items.slice(0, options["count"].to_int())
	var folder: String = SpeechEngine.find_dir(_config.voice_name)
	if folder == "" or not _engine.start(folder, _config.voice_name, _config.voice_length_scale,
			_config.voice_sentence_silence_s, _config.voice_noise_scale, _config.voice_noise_w):
		printerr("No speech program found (looked in %s)." % ", ".join(SpeechEngine.candidate_dirs()))
		_failed_start = true
		return
	print("Speaking %d lines with %s from %s into %s" % [_items.size(), _config.voice_name, folder, _out])
	_started_us = Time.get_ticks_usec()
	_ask_next()


func _process(_delta: float) -> bool:
	if _failed_start:
		quit(1)
		return true
	var done: PackedStringArray = _engine.finished()
	if not done.is_empty():
		_record(_next - 1, done[0])
		if _next >= _items.size():
			_finish()
			return true
		_ask_next()
	elif _next > 0 and (Time.get_ticks_usec() - _asked_us) / 1e6 > 30.0:
		_items[_next - 1]["made"] = false
		printerr("No answer for line %d in 30 s; stopping." % (_next - 1))
		_finish()
		return true
	return false


func _ask_next() -> void:
	var item: Dictionary = _items[_next]
	var wav: String = _out.path_join("wav").path_join("%04d.wav" % _next)
	item["wav"] = wav
	_next += 1
	_asked_us = Time.get_ticks_usec()
	_engine.say(item["spoken"], wav)


func _record(index: int, path: String) -> void:
	var item: Dictionary = _items[index]
	item["took_s"] = snappedf((Time.get_ticks_usec() - _asked_us) / 1e6, 0.001)
	var stream: AudioStreamWAV = AudioStreamWAV.load_from_file(path) if FileAccess.file_exists(path) else null
	item["made"] = stream != null
	item["sound_s"] = snappedf(stream.get_length(), 0.001) if stream != null else 0.0


func _finish() -> void:
	_engine.stop()
	var made: int = 0
	var took: PackedFloat32Array = PackedFloat32Array()
	var ratio: PackedFloat32Array = PackedFloat32Array()
	for item: Dictionary in _items:
		if item.get("made", false):
			made += 1
			took.append(item["took_s"])
			if item["kind"] == "bank" and item["his_s"] > 0.0:
				ratio.append(item["sound_s"] / item["his_s"])
	var file: FileAccess = FileAccess.open(_out.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_items, "  "))
	file.close()
	took.sort()
	ratio.sort()
	print("Made %d of %d lines in %.1f s." % [made, _items.size(), (Time.get_ticks_usec() - _started_us) / 1e6])
	if not took.is_empty():
		print("Time to make a line: middle %.3f s, 90 %% within %.3f s, worst %.3f s." % [took[took.size() / 2], took[int(took.size() * 0.9)], took[-1]])
	if not ratio.is_empty():
		print("The voice's length over his seconds (bank lines): middle %.2f, from %.2f to %.2f." % [ratio[ratio.size() / 2], ratio[0], ratio[-1]])
	print("Manifest: %s" % _out.path_join("manifest.json"))
	quit(0 if made == _items.size() else 1)


# ---------------------------------------------------------------- the lines

## The game's 20 characters' names (their persona files).
static func character_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for file: String in DirAccess.get_files_at(CHARACTERS_FOLDER):
		if file.ends_with(".tres"):
			var persona: Resource = load(CHARACTERS_FOLDER.path_join(file))
			var name: Variant = persona.get("name")
			if name is String and name != "":
				names.append(name)
	return names


## The brands of the game's sails.
static func sail_brands() -> PackedStringArray:
	var brands: PackedStringArray = PackedStringArray()
	for item: GearItem in GearCatalogue.sails():
		if item.brand != null and not brands.has(item.brand.name):
			brands.append(item.brand.name)
	return brands


## Every bank line with its slots filled (names in turn), then every name alone and in a sentence.
static func lines_to_speak(bank: CommentaryBank, names: PackedStringArray, brands: PackedStringArray) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	var turn: int = 0
	for line: CommentaryBank.Line in bank.lines:
		var text: String = line.text
		var name: String = ""
		for slot: String in line.slots:
			var word: String = ""
			match slot:
				"rider":
					name = names[turn % names.size()]
					word = name
					turn += 1
				"rider2":
					word = names[turn % names.size()]
					turn += 1
				"brand":
					word = brands[turn % maxi(brands.size(), 1)] if not brands.is_empty() else "Savanna"
				"place":
					word = "second"
				"mark":
					word = "first"
				"leg":
					word = "last"
				"colour":
					word = "red"
				"national":
					word = "Dutchman"
				"nation_adj":
					word = "Dutch"
			text = text.replace("{%s}" % slot, word)
		text = text.left(1).to_upper() + text.substr(1)
		items.append(_item("bank", line.id, name, text, line.seconds, line.level))
	for name: String in names:
		items.append(_item("name", "name:" + name, name, name + ".", 0.0, 2))
	for name: String in names:
		items.append(_item("name_sentence", "sentence:" + name, name, "And it's %s in first place." % name, 0.0, 2))
	return items


static func _item(kind: String, id: String, name: String, text: String, his_s: float, level: int) -> Dictionary:
	var config: CommentaryConfig = load(CONFIG_PATH) as CommentaryConfig
	return {"id": id, "kind": kind, "name": name, "text": text, "spoken": SpeechEngine.spoken_words(text, config.voice_spellings),
		"his_s": his_s, "level": level, "made": false, "sound_s": 0.0, "took_s": 0.0}
