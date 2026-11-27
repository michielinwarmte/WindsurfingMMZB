class_name SpeechEngine
extends RefCounted
## The speech program beside the game (Documentation/reports/broadcast/commentary_voice.md): a
## ready-made computer voice that turns a line of words into a sound file, on this PC, offline. The
## game cannot run a speech model itself, so it starts the program once and keeps it running: it loads
## its voice once and then takes one line after another (Piper's JSON mode: one line of JSON in, the
## path of the finished WAV file out). Nothing is sent to the internet.
##
## NOT the commentator's voice: a neutral British voice of the Piper project, until the real
## commentator says yes (PLAN.md, "When the commentator is asked").
##
## Where the program is looked for (find_dir()), the first that has it:
##   1. --tts_dir=<folder> on the command line (after "--");
##   2. the environment variable MMZB_TTS_DIR (the development tree: the downloads of
##      tools/tts/fetch_tts.py, e.g. C:/Users/Max de Dikke/source/pwa_broadcast/tts);
##   3. the folder "tts" next to the game's own executable (a play folder: <play folder>/tts/).
## The folder holds piper/piper.exe (with its DLLs and espeak-ng-data) and voices/<voice>.onnx with
## its .onnx.json. Without it the game stays silent and shows the subtitles as before.
##
## A plain class, so the tests can put a stand-in in its place (the same methods, no program).

const PROGRAM: String = "piper/piper.exe"
const VOICES: String = "voices"
const ENV_DIR: String = "MMZB_TTS_DIR"
const OPTION: String = "--tts_dir="

## The folder the program was found in, and the voice it speaks with ("" before start()).
var dir: String = ""
var voice: String = ""
## Why it is not running, for the log ("" when it is).
var problem: String = ""

var _pid: int = -1
var _pipe: FileAccess = null
var _reader: Thread = null
var _mutex: Mutex = Mutex.new()
## The files finished since the last finished(), filled by the reader thread.
var _done: PackedStringArray = PackedStringArray()
## How many lines were asked for and not yet finished.
var _waiting: int = 0


## The folder with the speech program and this voice, or "" when there is none (see the top).
static func find_dir(voice_name: String) -> String:
	for folder: String in candidate_dirs():
		if has_program(folder, voice_name):
			return folder
	return ""


## The folders looked in, in order: the command line's, the environment's, the one beside the game.
static func candidate_dirs() -> PackedStringArray:
	var folders: PackedStringArray = PackedStringArray()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(OPTION):
			folders.append(arg.trim_prefix(OPTION))
	var from_env: String = OS.get_environment(ENV_DIR)
	if from_env != "":
		folders.append(from_env)
	folders.append(OS.get_executable_path().get_base_dir().path_join("tts"))
	return folders


## Whether a folder has the program and the voice's two files.
static func has_program(folder: String, voice_name: String) -> bool:
	if folder == "":
		return false
	var model: String = folder.path_join(VOICES).path_join(voice_name + ".onnx")
	return FileAccess.file_exists(folder.path_join(PROGRAM)) and FileAccess.file_exists(model) \
		and FileAccess.file_exists(model + ".json")


## Starts the program with a voice, kept running; false (and `problem` says why) when it cannot.
## The numbers are Piper's own: length_scale above 1 speaks slower, sentence_silence is the pause
## after each sentence (s), noise_scale and noise_w how much the voice and its timing vary.
func start(folder: String, voice_name: String, length_scale: float, sentence_silence_s: float,
		noise_scale: float, noise_w: float) -> bool:
	stop()
	dir = folder
	voice = voice_name
	if not has_program(folder, voice_name):
		problem = "no speech program or voice in %s" % folder
		return false
	var model: String = folder.path_join(VOICES).path_join(voice_name + ".onnx")
	var arguments: PackedStringArray = PackedStringArray([
		"--model", model, "--json-input", "--quiet",
		"--length_scale", "%.3f" % length_scale,
		"--sentence_silence", "%.3f" % sentence_silence_s,
		"--noise_scale", "%.3f" % noise_scale,
		"--noise_w", "%.3f" % noise_w,
	])
	var process: Dictionary = OS.execute_with_pipe(folder.path_join(PROGRAM), arguments, true)
	if process.is_empty():
		problem = "the speech program did not start (%s)" % folder.path_join(PROGRAM)
		return false
	_pid = process["pid"]
	_pipe = process["stdio"]
	_reader = Thread.new()
	_reader.start(_read_answers)
	problem = ""
	return true


## Whether the program is running.
func is_running() -> bool:
	return _pid > 0 and OS.is_process_running(_pid)


## Asks for a line: `text` spoken into the WAV file `out_path` (an absolute path on the disk). The
## answer comes in finished() when the file is written.
func say(text: String, out_path: String) -> void:
	if _pipe == null:
		return
	var request: Dictionary = {"text": text, "output_file": out_path}
	_pipe.store_line(JSON.stringify(request))
	_pipe.flush()
	_mutex.lock()
	_waiting += 1
	_mutex.unlock()


## The files written since the last call (their paths as asked for).
func finished() -> PackedStringArray:
	_mutex.lock()
	var done: PackedStringArray = _done
	_done = PackedStringArray()
	_mutex.unlock()
	return done


## How many lines are asked for and not finished yet.
func waiting() -> int:
	_mutex.lock()
	var count: int = _waiting
	_mutex.unlock()
	return count


## Stops the program (the game closes, the commentary's scene ends).
func stop() -> void:
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
	_pid = -1
	if _reader != null and _reader.is_started():
		_reader.wait_to_finish()
	_reader = null
	if _pipe != null:
		_pipe.close()
	_pipe = null
	_mutex.lock()
	_waiting = 0
	_mutex.unlock()


## The reader thread: the program writes the path of each finished file on a line of its own; the
## thread waits for those lines and hands them over. It ends when the program ends.
func _read_answers() -> void:
	while true:
		var line: String = _pipe.get_line().strip_edges()
		if line == "":
			if _pipe.get_error() != OK or not OS.is_process_running(_pid):
				return
			continue
		_mutex.lock()
		_done.append(line.replace("\\", "/"))
		_waiting = maxi(_waiting - 1, 0)
		_mutex.unlock()


# ---------------------------------------------------------------- the words

## The words as the voice is given them: each name in the spelling table replaced, whole words only.
static func spoken_words(text: String, spellings: Dictionary[String, String]) -> String:
	var spoken: String = text
	for written: String in spellings:
		var pattern: RegEx = RegEx.create_from_string("\\b%s\\b" % escape_regex(written))
		if pattern != null:
			spoken = pattern.sub(spoken, spellings[written], true)
	return spoken


static func escape_regex(text: String) -> String:
	var out: String = ""
	for c: String in text:
		out += ("\\" + c) if ".^$*+?()[]{}|\\-".contains(c) else c
	return out
