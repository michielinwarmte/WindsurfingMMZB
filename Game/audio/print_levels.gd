extends Node
## Prints the sound levels of a run of the sailing scene with the autopilot, once a second:
## what the mix asks for (SoundMix, in dB) and what actually comes out of the buses
## (measured with a capture effect, as the root-mean-square level in dB below full scale,
## dBFS: the wind noise, the whistle, the lapping, the hiss, all the water, the sail and
## everything together). It runs in real time, without a window and without a sound card
## (the Dummy audio driver still mixes). For tuning the levels with numbers:
##
##   tools/godot.sh --headless --path Game res://audio/print_levels.tscn -- --seconds=20 [--wind_kt=18] [--twa=90]
##
## --tack=<s>: at that time the player's controls take over and Space is pressed (a tack
## from upwind of a beam reach, a gybe from downwind of it). The sailing scene's own options
## work too, for example --fall=<s> (a catapult at that time).

const MEASURED_BUSES: Array[String] = ["WindNoise", "WindWhistle", "WaterLap", "WaterHiss", "Water", "Sail", "Master"]

var _windsurfer: WindsurferNode
var _audio: GameAudio
var _seconds: float = 20.0
var _captures: Dictionary[String, AudioEffectCapture] = {}
var _power: Dictionary[String, float] = {}
var _frames: Dictionary[String, int] = {}
var _causes: Array[String] = []
var _next_print_s: float = 1.0
var _tack_at_s: float = -1.0
var _release_tack: bool = false


func _ready() -> void:
	var options: Dictionary[String, String] = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
			options[parts[0]] = parts[1]
	_seconds = options.get("seconds", "20").to_float()
	_tack_at_s = options.get("tack", "-1").to_float()
	GameSettings.path = ""
	GameSettings.values.wind_speed_kt = options.get("wind_kt", "18").to_float()
	var scene: SailingScene = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(scene)
	_windsurfer = scene.get_node("Windsurfer")
	_windsurfer.use_autopilot = true
	_windsurfer.autopilot.target_twa_deg = options.get("twa", "90").to_float()
	_audio = scene.get_node("GameAudio")
	for bus_name: String in MEASURED_BUSES:
		var capture: AudioEffectCapture = AudioEffectCapture.new()
		AudioServer.add_bus_effect(AudioServer.get_bus_index(bus_name), capture)
		_captures[bus_name] = capture
	_clear()
	print("audio driver: %s, %.0f kt of wind" % [AudioServer.get_driver_name(), GameSettings.values.wind_speed_kt])
	print("                        what the mix asks for (dB)              | measured on the buses (dBFS)")
	print("   t  boat  plan  aws | wind whis  lap rumb hiss hissHz flut | wind whis  lap hiss water sail  all | one-shots")


func _process(_delta: float) -> void:
	_measure()
	var time_s: float = _windsurfer.sim.time_s
	if not _audio.mix.one_shots.is_empty():
		_causes.append("%.1f %s" % [time_s, _audio.mix.last_event])
	_press_tack(time_s)
	if time_s >= _next_print_s:
		_print_row(time_s)
		_next_print_s += 1.0
	if time_s >= _seconds:
		get_tree().quit()


## Space for one frame at --tack, with the player's controls instead of the autopilot.
func _press_tack(time_s: float) -> void:
	if _release_tack:
		Input.action_release("tack")
		_release_tack = false
	if _tack_at_s >= 0.0 and time_s >= _tack_at_s:
		_tack_at_s = -1.0
		_windsurfer.use_autopilot = false
		Input.action_press("tack")
		_release_tack = true


func _measure() -> void:
	for bus_name: String in MEASURED_BUSES:
		var capture: AudioEffectCapture = _captures[bus_name]
		var available: int = capture.get_frames_available()
		if available <= 0:
			continue
		for frame: Vector2 in capture.get_buffer(available):
			_power[bus_name] += 0.5 * (frame.x * frame.x + frame.y * frame.y)
		_frames[bus_name] += available


func _print_row(time_s: float) -> void:
	var t: Telemetry = _windsurfer.telemetry()
	var mix: SoundMix = _audio.mix
	var measured: String = ""
	for bus_name: String in MEASURED_BUSES:
		var mean_power: float = _power[bus_name] / maxi(_frames[bus_name], 1)
		measured += " %4.0f" % SoundMix.amplitude_to_db(sqrt(mean_power))
	print("%4.0f %5.1f %5.2f %4.1f | %4.0f %4.0f %4.0f %4.0f %4.0f %6.0f %4.0f | %s | %s" % [
		time_s, t.speed_kt, mix.planing_smoothed, t.aws_kt, mix.wind.volume_db, mix.whistle.volume_db,
		mix.lapping.volume_db, mix.rumble.volume_db, mix.hiss.volume_db, mix.hiss.cutoff_hz,
		mix.flutter.volume_db, measured.substr(1), ", ".join(_causes)])
	_clear()


func _clear() -> void:
	for bus_name: String in MEASURED_BUSES:
		_power[bus_name] = 0.0
		_frames[bus_name] = 0
	_causes.clear()
