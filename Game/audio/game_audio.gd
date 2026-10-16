class_name GameAudio
extends Node
## The sounds of the sailing scene. The sailing scene (main.gd) makes one with create();
## every frame it reads the windsurfer's telemetry, lets SoundMix (sound_mix.gd) work out
## the levels, and copies them onto its audio players and the filters on the buses. The
## sounds themselves are generated once by SoundBank (sound_bank.gd).
##
## The buses (default_bus_layout.tres; Godot's mixer, see the Audio tab at the bottom of the
## editor):
##   Master  <- Wind  <- WindNoise   (low-pass: the wind's tone)
##                    <- WindWhistle (narrow band-pass: the whistle at speed)
##           <- Water <- WaterLap    (low-pass: lapping), and the rumble and the splashes
##                    <- WaterHiss   (band-pass: the planing hiss)
##           <- Sail  <- SailFlutter (low-pass: the flapping), and the cracks and swooshes
## The player's volume sliders (settings, Audio tab) set Master, Wind, Water and Sail.
##
## The players are plain (not 3D) AudioStreamPlayers: the mix itself makes the board's sounds
## quieter with a far camera. They stop while the game is paused (this node is pausable), and
## they work with the Dummy audio driver of the tests and screenshots (no sound card needed).

const WIND_BUS: StringName = &"Wind"
const WATER_BUS: StringName = &"Water"
const SAIL_BUS: StringName = &"Sail"
const WIND_NOISE_BUS: StringName = &"WindNoise"
const WIND_WHISTLE_BUS: StringName = &"WindWhistle"
const WATER_LAP_BUS: StringName = &"WaterLap"
const WATER_HISS_BUS: StringName = &"WaterHiss"
const SAIL_FLUTTER_BUS: StringName = &"SailFlutter"
## How many of each one-shot can sound at the same time.
const SPLASH_PLAYERS: int = 3
const CRACK_PLAYERS: int = 3
const SWOOSH_PLAYERS: int = 2

var mix: SoundMix = SoundMix.new()

var _windsurfer: WindsurferNode
var _camera_rig: CameraRig
## Returns true while the scene is the start menu's backdrop (the sound is quieter then).
var _is_in_menu: Callable

var _bank: SoundBank
## Each looping voice of the mix with its player and the filter on its bus (or null).
var _loops: Array[LoopPlayer] = []
var _splash_players: Array[AudioStreamPlayer] = []
var _crack_players: Array[AudioStreamPlayer] = []
var _swoosh_players: Array[AudioStreamPlayer] = []


## A looping sound: the mix's voice, the player that plays it and the bus filter it moves.
class LoopPlayer:
	extends RefCounted
	var voice: SoundMix.Voice
	var player: AudioStreamPlayer
	var filter: AudioEffectFilter


## The sound node for a sailing scene. is_in_menu returns true behind the start menu.
static func create(windsurfer: WindsurferNode, camera_rig: CameraRig, is_in_menu: Callable) -> GameAudio:
	var audio: GameAudio = GameAudio.new()
	audio.name = "GameAudio"
	audio._windsurfer = windsurfer
	audio._camera_rig = camera_rig
	audio._is_in_menu = is_in_menu
	return audio


func _ready() -> void:
	# The sailing scene keeps running while paused (for its menus); the sound stops.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_bank = SoundBank.shared()
	_add_loop(mix.wind, _bank.wind, WIND_NOISE_BUS)
	_add_loop(mix.whistle, _bank.whistle, WIND_WHISTLE_BUS)
	_add_loop(mix.lapping, _bank.lapping, WATER_LAP_BUS)
	_add_loop(mix.rumble, _bank.rumble, WATER_BUS)
	_add_loop(mix.hiss, _bank.hiss, WATER_HISS_BUS)
	_add_loop(mix.flutter, _bank.flutter, SAIL_FLUTTER_BUS)
	_splash_players = _add_one_shot_players(SPLASH_PLAYERS, WATER_BUS)
	_crack_players = _add_one_shot_players(CRACK_PLAYERS, SAIL_BUS)
	_swoosh_players = _add_one_shot_players(SWOOSH_PLAYERS, SAIL_BUS)
	apply_bus_volumes(GameSettings.values)
	GameSettings.changed.connect(_on_settings_changed)


func _process(delta: float) -> void:
	if _windsurfer == null or _windsurfer.sim == null:
		return
	var manoeuvre: String = "" if _windsurfer.use_autopilot else _windsurfer.controller.manoeuvre_name()
	var in_menu: bool = _is_in_menu.is_valid() and bool(_is_in_menu.call())
	mix.update(_windsurfer.telemetry(), delta, manoeuvre, in_menu, _camera_distance_m())
	for loop: LoopPlayer in _loops:
		loop.player.volume_db = loop.voice.volume_db
		loop.player.pitch_scale = loop.voice.pitch
		if loop.filter != null:
			loop.filter.cutoff_hz = loop.voice.cutoff_hz
	for shot: SoundMix.OneShot in mix.one_shots:
		_play_one_shot(shot)


## The player's volume sliders on the buses (0 = off, 1 = full).
static func apply_bus_volumes(values: SettingsValues) -> void:
	_set_bus_volume(WIND_BUS, values.wind_volume)
	_set_bus_volume(WATER_BUS, values.water_volume)
	_set_bus_volume(SAIL_BUS, values.sail_volume)


static func _set_bus_volume(bus_name: StringName, volume: float) -> void:
	var bus: int = AudioServer.get_bus_index(bus_name)
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, volume <= 0.001)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.001)))


func _on_settings_changed() -> void:
	apply_bus_volumes(GameSettings.values)


func _camera_distance_m() -> float:
	if _camera_rig == null or _camera_rig.camera == null:
		return 0.0
	return _camera_rig.camera.global_position.distance_to(_windsurfer.global_position)


## A looping player on a bus, started at once (silent until the mix says otherwise).
func _add_loop(voice: SoundMix.Voice, stream: AudioStreamWAV, bus: StringName) -> void:
	var loop: LoopPlayer = LoopPlayer.new()
	loop.voice = voice
	loop.player = _new_player(stream, bus)
	loop.player.volume_db = SoundMix.SILENT_DB
	var bus_index: int = AudioServer.get_bus_index(bus)
	if bus_index >= 0 and AudioServer.get_bus_effect_count(bus_index) > 0:
		loop.filter = AudioServer.get_bus_effect(bus_index, 0) as AudioEffectFilter
	_loops.append(loop)
	loop.player.play()


func _add_one_shot_players(count: int, bus: StringName) -> Array[AudioStreamPlayer]:
	var players: Array[AudioStreamPlayer] = []
	for i: int in count:
		players.append(_new_player(null, bus))
	return players


func _new_player(stream: AudioStreamWAV, bus: StringName) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	# A bus that is missing (a broken layout) falls back to Master instead of failing.
	player.bus = bus if AudioServer.get_bus_index(bus) >= 0 else &"Master"
	add_child(player)
	return player


func _play_one_shot(shot: SoundMix.OneShot) -> void:
	match shot.kind:
		SoundMix.OneShotKind.SPLASH:
			_start(_splash_players, _bank.splashes[shot.variant % _bank.splashes.size()], shot)
		SoundMix.OneShotKind.CRACK:
			_start(_crack_players, _bank.cracks[shot.variant % _bank.cracks.size()], shot)
		SoundMix.OneShotKind.SWOOSH:
			_start(_swoosh_players, _bank.swoosh, shot)


## Plays a one-shot on a free player of the pool (or on the one that started first).
func _start(players: Array[AudioStreamPlayer], stream: AudioStreamWAV, shot: SoundMix.OneShot) -> void:
	var chosen: AudioStreamPlayer = players[0]
	var most_played_s: float = -1.0
	for player: AudioStreamPlayer in players:
		if not player.playing:
			chosen = player
			break
		if player.get_playback_position() > most_played_s:
			most_played_s = player.get_playback_position()
			chosen = player
	chosen.stream = stream
	chosen.volume_db = shot.volume_db
	chosen.pitch_scale = shot.pitch
	chosen.play()
