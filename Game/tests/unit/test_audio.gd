extends GutTest
## The sounds (plan, Phase 8): the generated sounds (SoundBank), the buses, the mix that
## turns the telemetry into levels (SoundMix) and the sound node in the sailing scene
## (GameAudio). The AI cannot listen, so these check the numbers; the team checks by ear.

const FRAME_S: float = 1.0 / 60.0

var _saved_values: SettingsValues
var _saved_path: String


func before_each() -> void:
	_saved_values = GameSettings.values
	_saved_path = GameSettings.path
	GameSettings.values = SettingsValues.new()
	GameSettings.path = ""


func after_each() -> void:
	get_tree().paused = false
	GameSettings.values = _saved_values
	GameSettings.path = _saved_path
	GameAudio.apply_bus_volumes(GameSettings.values)


# --- Helpers --------------------------------------------------------------------------

## A telemetry snapshot of a board sailing along with a powered sail.
func _telemetry(aws_kt: float, speed_ms: float = 0.0, planing: float = 0.0) -> Telemetry:
	var t: Telemetry = Telemetry.new()
	t.aws_kt = aws_kt
	t.speed_ms = speed_ms
	t.planing_ratio = planing
	t.alpha_deg = 15.0
	t.sail_side = -1
	t.submersion_ratio = 0.3
	return t


## Runs the mix for a while on a telemetry snapshot, with the simulation's clock going on.
## Returns every one-shot of those frames.
func _run(mix: SoundMix, t: Telemetry, seconds: float, manoeuvre: String = "", in_menu: bool = false,
		camera_m: float = 5.0) -> Array[SoundMix.OneShot]:
	var shots: Array[SoundMix.OneShot] = []
	for i: int in int(round(seconds / FRAME_S)):
		t.time_s += FRAME_S
		mix.update(t, FRAME_S, manoeuvre, in_menu, camera_m)
		shots.append_array(mix.one_shots)
	return shots


func _count(shots: Array[SoundMix.OneShot], kind: SoundMix.OneShotKind) -> int:
	var count: int = 0
	for shot: SoundMix.OneShot in shots:
		if shot.kind == kind:
			count += 1
	return count


## The mix's settled levels for a snapshot.
func _settled(t: Telemetry) -> SoundMix:
	var mix: SoundMix = SoundMix.new()
	_run(mix, t, 3.0)
	return mix


# --- The generated sounds ---------------------------------------------------------------

func test_the_loops_have_the_right_length_and_loop() -> void:
	var bank: SoundBank = SoundBank.shared()
	var loops: Dictionary[String, float] = {
		"wind": SoundBank.WIND_LOOP_S, "hiss": SoundBank.HISS_LOOP_S, "whistle": SoundBank.WHISTLE_LOOP_S,
		"lapping": SoundBank.LAPPING_LOOP_S,
		"rumble": SoundBank.RUMBLE_LOOP_S, "flutter": SoundBank.FLUTTER_LOOP_S,
		"hum": SoundBank.HUM_LOOP_S, "creak": SoundBank.CREAK_LOOP_S}
	for loop_name: String in loops:
		var stream: AudioStreamWAV = bank.get(loop_name)
		var count: int = SoundBank.sample_count(stream)
		assert_eq(count, int(loops[loop_name] * SoundBank.MIX_RATE_HZ), "%s: its length" % loop_name)
		assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "%s loops" % loop_name)
		assert_eq(stream.loop_begin, 0)
		assert_eq(stream.loop_end, count, "%s loops over all of it" % loop_name)
		assert_eq(stream.format, AudioStreamWAV.FORMAT_16_BITS)
		assert_eq(stream.mix_rate, 44100)
		assert_false(stream.stereo)
		assert_gt(SoundBank.rms(stream), 0.05, "%s is not silent" % loop_name)
		# The seam: from the last sample back to the first is no bigger a step than the
		# loop takes anywhere else.
		var largest_step: float = 0.0
		for i: int in range(1, count, 7):
			largest_step = maxf(largest_step, absf(SoundBank.sample_at(stream, i) - SoundBank.sample_at(stream, i - 1)))
		var seam: float = absf(SoundBank.sample_at(stream, 0) - SoundBank.sample_at(stream, count - 1))
		assert_lt(seam, largest_step * 1.5 + 0.01, "%s has no click at the seam" % loop_name)


func test_the_one_shots_play_once_and_end_quietly() -> void:
	var bank: SoundBank = SoundBank.shared()
	var shots: Array[AudioStreamWAV] = []
	shots.append_array(bank.splashes)
	shots.append_array(bank.cracks)
	shots.append(bank.swoosh)
	assert_eq(bank.splashes.size(), SoundMix.SPLASH_VARIANTS)
	assert_eq(bank.cracks.size(), SoundMix.CRACK_VARIANTS)
	for stream: AudioStreamWAV in shots:
		assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_DISABLED)
		assert_gt(SoundBank.rms(stream), 0.02, "not silent")
		assert_lt(absf(SoundBank.sample_at(stream, SoundBank.sample_count(stream) - 1)), 0.01, "ends at zero, no click")
	assert_lt(SoundBank.sample_count(bank.cracks[0]), SoundBank.sample_count(bank.splashes[0]), "a crack is short, a splash longer")


func test_the_same_seed_makes_the_same_sound() -> void:
	var bank: SoundBank = SoundBank.shared()
	var again: AudioStreamWAV = bank._make_crack(1)
	assert_eq(again.data, bank.cracks[1].data, "repeatable")
	assert_ne(bank.cracks[0].data, bank.cracks[1].data, "the versions differ")


# --- A race's start (SO3) ---------------------------------------------------------------

## How strong a tone of `hz` is in a stretch of a sound (one bin of a Fourier sum), 0 to about 0.5.
func _tone_level(stream: AudioStreamWAV, hz: float, from_s: float, to_s: float) -> float:
	var first: int = int(from_s * SoundBank.MIX_RATE_HZ)
	var last: int = int(to_s * SoundBank.MIX_RATE_HZ)
	var along: float = 0.0
	var across: float = 0.0
	for i: int in range(first, last):
		var angle: float = TAU * hz * i / SoundBank.MIX_RATE_HZ
		along += SoundBank.sample_at(stream, i) * cos(angle)
		across += SoundBank.sample_at(stream, i) * sin(angle)
	return sqrt(along * along + across * across) / (last - first)


## The root-mean-square level of a stretch of a sound.
func _level(stream: AudioStreamWAV, from_s: float, to_s: float) -> float:
	var total: float = 0.0
	var first: int = int(from_s * SoundBank.MIX_RATE_HZ)
	var last: int = int(to_s * SoundBank.MIX_RATE_HZ)
	for i: int in range(first, last):
		total += SoundBank.sample_at(stream, i) ** 2
	return sqrt(total / (last - first))


func test_the_start_horns_are_a_400_hz_blare_long_and_short() -> void:
	var bank: SoundBank = SoundBank.shared()
	bank.make_start_sounds()
	assert_eq(SoundBank.sample_count(bank.horn_long), int(SoundBank.HORN_LONG_S * SoundBank.MIX_RATE_HZ), "2 s")
	assert_eq(SoundBank.sample_count(bank.horn_short), int(SoundBank.HORN_SHORT_S * SoundBank.MIX_RATE_HZ), "0.8 s")
	for horn: AudioStreamWAV in [bank.horn_long, bank.horn_short]:
		assert_eq(horn.loop_mode, AudioStreamWAV.LOOP_DISABLED)
		assert_lt(absf(SoundBank.sample_at(horn, 0)), 0.01, "starts at zero, no click")
		assert_lt(absf(SoundBank.sample_at(horn, SoundBank.sample_count(horn) - 1)), 0.01, "ends at zero")
	var tone: float = _tone_level(bank.horn_long, SoundBank.HORN_HZ, 0.5, 1.0)
	assert_gt(tone, 3.0 * _tone_level(bank.horn_long, 300.0, 0.5, 1.0), "the 400 Hz tone, not 300 Hz")
	assert_gt(tone, 3.0 * _tone_level(bank.horn_long, 500.0, 0.5, 1.0), "nor 500 Hz")
	assert_gt(_tone_level(bank.horn_long, 2.0 * SoundBank.HORN_HZ, 0.5, 1.0), 0.2 * tone, "bright: its harmonics are strong")
	assert_lt(_level(bank.horn_long, 0.0, 0.01), 0.5 * _level(bank.horn_long, 0.5, 1.0), "it swells in")


func test_the_start_watch_beeps_a_short_high_tone() -> void:
	SoundBank.shared().make_start_sounds()
	var beep: AudioStreamWAV = SoundBank.shared().beep
	assert_eq(SoundBank.sample_count(beep), int(SoundBank.BEEP_S * SoundBank.MIX_RATE_HZ), "0.12 s")
	var tone: float = _tone_level(beep, SoundBank.BEEP_HZ, 0.01, 0.11)
	assert_gt(tone, 5.0 * _tone_level(beep, 2000.0, 0.01, 0.11), "2.8 kHz")
	assert_gt(tone, 5.0 * _tone_level(beep, 400.0, 0.01, 0.11), "not the horn's tone")


func test_the_gun_cracks_at_once_booms_and_echoes() -> void:
	SoundBank.shared().make_start_sounds()
	var gun: AudioStreamWAV = SoundBank.shared().gun
	assert_eq(SoundBank.sample_count(gun), int(SoundBank.GUN_S * SoundBank.MIX_RATE_HZ))
	var loudest_at: int = 0
	for i: int in SoundBank.sample_count(gun):
		if absf(SoundBank.sample_at(gun, i)) > absf(SoundBank.sample_at(gun, loudest_at)):
			loudest_at = i
	assert_lt(loudest_at, int(0.01 * SoundBank.MIX_RATE_HZ), "the loudest moment is in the first 10 ms: the crack")
	assert_gt(_tone_level(gun, 60.0, 0.0, 0.15), _tone_level(gun, 1000.0, 0.0, 0.15), "a low boom under it")
	var echo_s: float = SoundBank.GUN_ECHO_S[0]
	assert_gt(_level(gun, echo_s, echo_s + 0.05), 1.5 * _level(gun, echo_s - 0.06, echo_s - 0.01), "the shore's echo comes back")
	assert_lt(_level(gun, SoundBank.GUN_S - 0.2, SoundBank.GUN_S), 0.1 * _level(gun, 0.0, 0.2), "and it dies away")


## The race in the sailing scene sounds its start: a 3 s countdown (its first moment is the 3 s
## beep, so no horn starts it), the beeps at 2 and 1 s, and the gun, on the Signals bus.
func test_a_race_in_the_scene_sounds_its_start_on_the_signals_bus() -> void:
	var setup: RaceSetup = RaceSetup.race("t1_loop")
	setup.prestart_s = 3.0  # shorter than the menu allows (5 s), so the test is quick
	RaceSetup.pending = setup
	var scene: SailingScene = (load("res://main.tscn") as PackedScene).instantiate()
	add_child_autofree(scene)
	var runner: RaceRunner = scene.get_node("RaceRunner")
	var audio: GameAudio = scene.get_node("GameAudio")
	var heard: Array[RaceStartSignals.Kind] = []
	runner.start_signal.connect(func(kind: RaceStartSignals.Kind) -> void: heard.append(kind))
	await wait_physics_frames(int(3.2 * 60.0))
	assert_eq(heard, [RaceStartSignals.Kind.BEEP, RaceStartSignals.Kind.BEEP, RaceStartSignals.Kind.BEEP,
		RaceStartSignals.Kind.GUN] as Array[RaceStartSignals.Kind], "three beeps, the gun")
	var gun_playing: bool = false
	for child: Node in audio.get_children():
		var player: AudioStreamPlayer = child as AudioStreamPlayer
		if player != null and player.stream == SoundBank.shared().gun:
			gun_playing = player.playing
			assert_eq(player.bus, GameAudio.SIGNALS_BUS, "on the Signals bus")
			assert_almost_eq(player.volume_db, audio.mix.config.gun_db, 1e-4, "at the mix's level")
	assert_true(gun_playing, "the gun is heard")


# --- The buses --------------------------------------------------------------------------

func test_the_buses_and_their_filters() -> void:
	var expected: Dictionary[String, String] = {
		"Wind": "Master", "Water": "Master", "Sail": "Master", "WindNoise": "Wind", "WindWhistle": "Wind",
		"WaterLap": "Water", "WaterHiss": "Water", "SailFlutter": "Sail", "Signals": "Master"}
	for bus_name: String in expected:
		var bus: int = AudioServer.get_bus_index(bus_name)
		assert_gt(bus, 0, "the %s bus exists" % bus_name)
		assert_eq(String(AudioServer.get_bus_send(bus)), expected[bus_name], "%s goes to %s" % [bus_name, expected[bus_name]])
	assert_true(AudioServer.get_bus_effect(AudioServer.get_bus_index("WindNoise"), 0) is AudioEffectLowPassFilter)
	assert_true(AudioServer.get_bus_effect(AudioServer.get_bus_index("WindWhistle"), 0) is AudioEffectBandPassFilter)
	assert_true(AudioServer.get_bus_effect(AudioServer.get_bus_index("WaterLap"), 0) is AudioEffectLowPassFilter)
	assert_true(AudioServer.get_bus_effect(AudioServer.get_bus_index("WaterHiss"), 0) is AudioEffectBandPassFilter)
	assert_true(AudioServer.get_bus_effect(AudioServer.get_bus_index("SailFlutter"), 0) is AudioEffectLowPassFilter)


## ROADMAP TE1: the editor's Audio panel (it also runs inside a headless import) loads the bus layout
## and saves it again 0.8 s later. The file must already be exactly what Godot's saver writes, or
## that save shows up as a change in git. So: loaded and saved again, the text is the same, and the
## file names its own uid (without one the editor makes one up and writes it in).
func test_the_bus_layout_file_is_what_godot_itself_would_write() -> void:
	var path: String = "res://default_bus_layout.tres"
	var copy_path: String = "user://bus_layout_resaved.tres"
	var layout: AudioBusLayout = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as AudioBusLayout
	assert_not_null(layout, "the bus layout loads")
	assert_eq(ResourceSaver.save(layout, copy_path), OK)
	var committed: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
	var resaved: PackedStringArray = FileAccess.get_file_as_string(copy_path).split("\n")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(copy_path))
	assert_string_contains(committed[0], "uid=\"uid://", "the file's first line names its uid")
	# The first line holds the uid, which belongs to the path; everything after it must match.
	committed.remove_at(0)
	resaved.remove_at(0)
	assert_eq("\n".join(committed), "\n".join(resaved),
		"default_bus_layout.tres differs from what Godot writes: change the buses in the editor's Audio tab, not by hand")


func test_the_volume_sliders_set_the_buses() -> void:
	var values: SettingsValues = SettingsValues.new()
	values.wind_volume = 0.5
	values.water_volume = 0.0
	values.sail_volume = 1.0
	GameAudio.apply_bus_volumes(values)
	var wind: int = AudioServer.get_bus_index("Wind")
	var water: int = AudioServer.get_bus_index("Water")
	var sail: int = AudioServer.get_bus_index("Sail")
	assert_almost_eq(AudioServer.get_bus_volume_db(wind), linear_to_db(0.5), 1e-4, "half the amplitude: -6 dB")
	assert_true(AudioServer.is_bus_mute(water), "0 is off")
	assert_false(AudioServer.is_bus_mute(sail))
	assert_almost_eq(AudioServer.get_bus_volume_db(sail), 0.0, 1e-4)


# --- The wind ---------------------------------------------------------------------------

func test_no_wind_is_silent() -> void:
	var mix: SoundMix = _settled(_telemetry(0.0))
	assert_eq(mix.wind.volume_db, SoundMix.SILENT_DB, "no wind, no wind noise")
	assert_eq(mix.whistle.volume_db, SoundMix.SILENT_DB)
	assert_eq(mix.flutter.volume_db, SoundMix.SILENT_DB, "a sail without wind does not flap")


func test_the_wind_gets_louder_higher_and_brighter_with_the_apparent_wind() -> void:
	var last: SoundMix = null
	for aws_kt: float in [3.0, 8.0, 14.0, 20.0, 26.0]:
		var mix: SoundMix = _settled(_telemetry(aws_kt))
		if last != null:
			assert_gt(mix.wind.volume_db, last.wind.volume_db + 2.0, "louder at %.0f kt" % aws_kt)
			assert_gt(mix.wind.pitch, last.wind.pitch, "higher at %.0f kt" % aws_kt)
			assert_gt(mix.wind.cutoff_hz, last.wind.cutoff_hz, "brighter at %.0f kt" % aws_kt)
		last = mix
	# About 12 dB per doubling: 10 kt to 20 kt.
	var at_10: float = _settled(_telemetry(10.0)).wind.volume_db
	var at_20: float = _settled(_telemetry(20.0)).wind.volume_db
	assert_almost_eq(at_20 - at_10, 12.0, 0.5)


func test_the_whistle_only_comes_in_at_speed() -> void:
	assert_eq(_settled(_telemetry(12.0)).whistle.volume_db, SoundMix.SILENT_DB, "no whistle in moderate wind")
	var fast: SoundMix = _settled(_telemetry(28.0))
	assert_gt(fast.whistle.volume_db, -40.0, "a whistle at 28 kt apparent")
	assert_lt(fast.whistle.volume_db, fast.wind.volume_db, "under the wind's roar")


# --- The water --------------------------------------------------------------------------

func test_the_water_crosses_over_from_lapping_to_hiss_as_the_board_planes() -> void:
	# The mix counts a smoothed planing ratio of planing_full_ratio (0.6) as fully planing.
	var lapping_db: Array[float] = []
	var hiss_db: Array[float] = []
	for planing: float in [0.0, 0.15, 0.3, 0.45, 0.6, 1.0]:
		var mix: SoundMix = _settled(_telemetry(18.0, 6.0, planing))
		lapping_db.append(mix.lapping.volume_db)
		hiss_db.append(mix.hiss.volume_db)
	for i: int in range(1, 5):
		assert_lt(lapping_db[i], lapping_db[i - 1], "the lapping fades as it planes (%d)" % i)
		assert_gt(hiss_db[i], hiss_db[i - 1], "the hiss rises as it planes (%d)" % i)
	assert_eq(hiss_db[0], SoundMix.SILENT_DB, "no hiss before it planes")
	assert_gt(lapping_db[0], hiss_db[0])
	assert_gt(hiss_db[4], lapping_db[4] + 6.0, "the hiss has taken over when planing")
	assert_almost_eq(hiss_db[5], hiss_db[4], 0.01, "and stays")
	var rumble_displacing: float = _settled(_telemetry(18.0, 3.0, 0.0)).rumble.volume_db
	var rumble_planing: float = _settled(_telemetry(18.0, 6.0, 1.0)).rumble.volume_db
	assert_gt(rumble_displacing, -30.0, "a rumble when pushing water")
	assert_eq(rumble_planing, SoundMix.SILENT_DB, "no rumble when planing")


func test_the_hiss_gets_louder_and_higher_with_speed() -> void:
	var slow: SoundMix = _settled(_telemetry(18.0, 5.0, 1.0))
	var fast: SoundMix = _settled(_telemetry(22.0, 11.0, 1.0))
	assert_gt(fast.hiss.volume_db, slow.hiss.volume_db + 3.0)
	assert_gt(fast.hiss.pitch, slow.hiss.pitch)
	assert_gt(fast.hiss.cutoff_hz, slow.hiss.cutoff_hz)


func test_a_board_at_rest_still_laps() -> void:
	var mix: SoundMix = _settled(_telemetry(0.0))
	assert_gt(mix.lapping.volume_db, -40.0, "the water knocks on a board at rest")
	assert_eq(mix.hiss.volume_db, SoundMix.SILENT_DB)


func test_the_wind_is_louder_than_the_water_on_a_planing_reach() -> void:
	# A beam reach in 18 kt: about 15 kt of board speed and 20 kt of apparent wind.
	var mix: SoundMix = _settled(_telemetry(20.0, 7.7, 1.0))
	assert_gt(mix.wind.volume_db, mix.hiss.volume_db, "the wind in the ears is the loudest")
	assert_gt(mix.hiss.volume_db, mix.lapping.volume_db)


# --- The sail ---------------------------------------------------------------------------

func test_the_sail_flaps_when_luffing_and_not_when_powered() -> void:
	var luffing: Telemetry = _telemetry(15.0, 2.0)
	luffing.is_luffing = true
	luffing.alpha_deg = 1.0
	var flapping: SoundMix = _settled(luffing)
	assert_gt(flapping.flutter.volume_db, -25.0, "a luffing sail flaps")
	var powered: SoundMix = _settled(_telemetry(15.0, 2.0))
	assert_eq(powered.flutter.volume_db, SoundMix.SILENT_DB, "a powered sail is quiet")
	var edge: Telemetry = _telemetry(15.0, 2.0)
	edge.is_luffing = true
	edge.alpha_deg = 3.0
	var half: SoundMix = _settled(edge)
	assert_lt(half.flutter.volume_db, flapping.flutter.volume_db - 9.0, "half way into the luff zone: a ripple, not a flog")
	assert_gt(half.flutter.volume_db, SoundMix.SILENT_DB)


func test_the_flutter_is_faster_and_louder_in_more_wind() -> void:
	var light: Telemetry = _telemetry(8.0)
	light.is_luffing = true
	light.alpha_deg = 0.0
	var strong: Telemetry = _telemetry(24.0)
	strong.is_luffing = true
	strong.alpha_deg = 0.0
	var light_mix: SoundMix = _settled(light)
	var strong_mix: SoundMix = _settled(strong)
	assert_gt(strong_mix.flutter.pitch, light_mix.flutter.pitch * 2.0, "the flapping rate follows the wind")
	assert_gt(strong_mix.flutter.volume_db, light_mix.flutter.volume_db)


func test_the_sail_flaps_during_a_tack() -> void:
	var mix: SoundMix = SoundMix.new()
	_run(mix, _telemetry(15.0, 2.0), 2.0, "tacking")
	assert_gt(mix.flutter.volume_db, -40.0)


func test_the_sail_cracks_once_when_it_fills_again() -> void:
	var mix: SoundMix = SoundMix.new()
	var t: Telemetry = _telemetry(16.0, 3.0)
	var shots: Array[SoundMix.OneShot] = _run(mix, t, 1.0)
	t.is_luffing = true
	t.alpha_deg = 0.0
	shots.append_array(_run(mix, t, 1.0))
	t.is_luffing = false
	t.alpha_deg = 15.0
	shots.append_array(_run(mix, t, 1.0))
	assert_eq(_count(shots, SoundMix.OneShotKind.CRACK), 2, "a soft crack as it collapsed, and one as it fills")
	var fill: SoundMix.OneShot = shots[shots.size() - 1]
	assert_eq(fill.kind, SoundMix.OneShotKind.CRACK)
	assert_gt(fill.volume_db, shots[0].volume_db, "filling cracks louder than collapsing")


func test_a_sail_on_the_edge_does_not_crack_every_frame() -> void:
	var mix: SoundMix = SoundMix.new()
	var t: Telemetry = _telemetry(16.0, 3.0)
	var shots: Array[SoundMix.OneShot] = []
	t.is_luffing = true
	for i: int in 120:
		t.alpha_deg = 3.0 + 1.5 * sin(float(i))
		shots.append_array(_run(mix, t, FRAME_S))
	assert_eq(_count(shots, SoundMix.OneShotKind.CRACK), 0, "between the two angles nothing changes")


func test_the_rig_swooshes_when_the_sail_changes_sides() -> void:
	var mix: SoundMix = SoundMix.new()
	var t: Telemetry = _telemetry(14.0, 2.0)
	var shots: Array[SoundMix.OneShot] = _run(mix, t, 0.5)
	t.sail_side = 1
	shots.append_array(_run(mix, t, 0.5))
	assert_eq(_count(shots, SoundMix.OneShotKind.SWOOSH), 1)


# --- Splashes and falls ---------------------------------------------------------------

func test_a_slam_makes_one_splash_and_not_a_second_one_on_the_next_frame() -> void:
	var mix: SoundMix = SoundMix.new()
	var t: Telemetry = _telemetry(20.0, 7.0, 1.0)
	_run(mix, t, 0.5)
	# The hull drops onto the water at 2 m/s for a few frames, then the water stops it.
	var shots: Array[SoundMix.OneShot] = []
	for i: int in 5:
		t.position.y -= 2.0 * FRAME_S
		shots.append_array(_run(mix, t, FRAME_S))
	assert_eq(shots.size(), 0, "nothing while it falls")
	shots.append_array(_run(mix, t, FRAME_S))
	assert_eq(_count(shots, SoundMix.OneShotKind.SPLASH), 1, "a splash as it lands")
	shots.append_array(_run(mix, t, FRAME_S))
	shots.append_array(_run(mix, t, 1.0))
	assert_eq(_count(shots, SoundMix.OneShotKind.SPLASH), 1, "and only one")


func test_a_harder_slam_is_louder() -> void:
	var levels: Array[float] = []
	for drop_ms: float in [1.2, 3.0]:
		var mix: SoundMix = SoundMix.new()
		var t: Telemetry = _telemetry(20.0, 7.0, 1.0)
		_run(mix, t, 0.5)
		for i: int in 3:
			t.position.y -= drop_ms * FRAME_S
			_run(mix, t, FRAME_S)
		var shots: Array[SoundMix.OneShot] = _run(mix, t, FRAME_S)
		assert_eq(shots.size(), 1)
		levels.append(shots[0].volume_db if shots.size() > 0 else SoundMix.SILENT_DB)
	assert_gt(levels[1], levels[0] + 6.0)


func test_a_teleport_or_a_reset_does_not_splash() -> void:
	var mix: SoundMix = SoundMix.new()
	var t: Telemetry = _telemetry(20.0, 7.0, 1.0)
	var shots: Array[SoundMix.OneShot] = _run(mix, t, 0.5)
	t.position.y += 3.0
	shots.append_array(_run(mix, t, 0.5))
	t.position.y = 0.0
	t.time_s = 0.0
	t.sail_side = 1
	shots.append_array(_run(mix, t, 0.5))
	assert_eq(shots.size(), 0, "no sound from a jump of the board or the clock")


func test_nothing_happens_while_the_clock_stands_still() -> void:
	var mix: SoundMix = SoundMix.new()
	var t: Telemetry = _telemetry(16.0, 3.0)
	_run(mix, t, 0.5)
	# Paused, or a fast screen showing the same physics step twice: the same time_s.
	t.position.y -= 0.5
	t.sail_side = 1
	mix.update(t, FRAME_S)
	assert_eq(mix.one_shots.size(), 0)


func test_a_fall_splashes_and_silences_the_sail() -> void:
	var mix: SoundMix = SoundMix.new()
	var t: Telemetry = _telemetry(18.0, 6.0, 1.0)
	t.is_luffing = true
	t.alpha_deg = 0.0
	_run(mix, t, 1.0)
	assert_gt(mix.flutter.volume_db, -30.0, "flapping before the fall")
	var wind_before_db: float = mix.wind.volume_db
	t.sailor_state = 1
	t.fall_kind = "catapult"
	t.sail_side = 1
	var shots: Array[SoundMix.OneShot] = _run(mix, t, FRAME_S)
	assert_eq(shots.size(), 1, "one sound as the sailor falls in")
	assert_eq(shots[0].kind, SoundMix.OneShotKind.SPLASH)
	assert_gt(shots[0].volume_db, -8.0, "a catapult is a big splash")
	t.speed_ms = 0.0
	t.planing_ratio = 0.0
	shots = _run(mix, t, 3.0)
	assert_eq(shots.size(), 0, "no cracks or swooshes from a sail in the water")
	assert_eq(mix.flutter.volume_db, SoundMix.SILENT_DB, "the sail is silent")
	assert_almost_eq(mix.wind.volume_db, wind_before_db, 0.5, "the wind goes on")
	assert_gt(mix.lapping.volume_db, -40.0, "and the water")
	t.sailor_state = 0
	shots = _run(mix, t, FRAME_S)
	assert_eq(_count(shots, SoundMix.OneShotKind.SPLASH), 1, "a small splash at the water start")


# --- Gains, smoothing and safety ----------------------------------------------------------

func test_the_levels_change_smoothly() -> void:
	var mix: SoundMix = SoundMix.new()
	var t: Telemetry = _telemetry(0.0)
	_run(mix, t, 1.0)
	t.aws_kt = 30.0
	_run(mix, t, FRAME_S)
	var target: float = db_to_linear(mix.config.wind_max_db)
	assert_lt(mix.wind.amplitude, 0.1 * target, "one frame moves only a little of the way: no click")
	_run(mix, t, 2.0)
	assert_almost_eq(mix.wind.volume_db, mix.config.wind_max_db, 0.5, "and gets there within two seconds")


func test_the_start_menu_and_a_far_camera_make_it_quieter() -> void:
	var t: Telemetry = _telemetry(18.0, 4.0, 0.5)
	var near: SoundMix = SoundMix.new()
	_run(near, t, 4.0, "", false, 5.0)
	var menu: SoundMix = SoundMix.new()
	_run(menu, _telemetry(18.0, 4.0, 0.5), 4.0, "", true, 5.0)
	assert_almost_eq(menu.wind.volume_db, near.wind.volume_db + menu.config.menu_db, 0.3, "behind the menu")
	var far: SoundMix = SoundMix.new()
	_run(far, _telemetry(18.0, 4.0, 0.5), 4.0, "", false, 45.0)
	assert_almost_eq(far.wind.volume_db, near.wind.volume_db, 0.01, "the wind in the ears does not depend on the camera")
	assert_lt(far.hiss.volume_db, near.hiss.volume_db - 6.0, "the board is quieter from far away")
	assert_gt(far.hiss.volume_db, near.hiss.volume_db + far.config.camera_min_db - 0.1, "but not silent")


func test_nothing_is_ever_louder_than_full_scale_or_not_a_number() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var mix: SoundMix = SoundMix.new()
	var t: Telemetry = Telemetry.new()
	var bad: Array[float] = [NAN, INF, -INF, 1e9, -1e9]
	for i: int in 1500:
		t.time_s += FRAME_S if i % 50 != 0 else -0.5
		t.aws_kt = rng.randf_range(0.0, 120.0)
		t.speed_ms = rng.randf_range(0.0, 40.0)
		t.planing_ratio = rng.randf_range(-0.5, 1.5)
		t.alpha_deg = rng.randf_range(-90.0, 90.0)
		t.is_luffing = rng.randf() < 0.3
		t.sail_side = -1 if rng.randf() < 0.5 else 1
		t.sailor_state = 1 if rng.randf() < 0.05 else 0
		t.position.y = rng.randf_range(-1.0, 1.0)
		t.bow_immersion_m = rng.randf_range(-0.5, 0.5)
		t.submersion_ratio = rng.randf()
		if i % 7 == 0:
			t.aws_kt = bad[i % bad.size()]
			t.speed_ms = bad[(i + 1) % bad.size()]
			t.position.y = bad[(i + 2) % bad.size()]
		mix.update(t, FRAME_S if i % 11 != 0 else NAN, "tacking" if i % 13 == 0 else "", i % 17 == 0, rng.randf_range(0.0, 500.0))
		for voice: SoundMix.Voice in mix.voices():
			assert_true(voice.volume_db <= 0.0 and voice.volume_db >= SoundMix.SILENT_DB, "a level in range")
			assert_false(is_nan(voice.pitch) or is_nan(voice.cutoff_hz), "numbers")
			assert_gt(voice.pitch, 0.0, "a pitch the player can use")
		for shot: SoundMix.OneShot in mix.one_shots:
			assert_true(shot.volume_db <= 0.0 and shot.volume_db >= SoundMix.SILENT_DB)
			assert_false(is_nan(shot.pitch))


# --- The sound node in the scene ---------------------------------------------------------

func test_the_sailing_scene_plays_the_mix() -> void:
	var scene: SailingScene = (load("res://main.tscn") as PackedScene).instantiate()
	add_child_autofree(scene)
	var audio: GameAudio = scene.get_node("GameAudio")
	assert_not_null(audio, "the sailing scene has its sound node")
	var playing: int = 0
	for child: Node in audio.get_children():
		var player: AudioStreamPlayer = child as AudioStreamPlayer
		if player != null and player.playing:
			playing += 1
			assert_ne(player.bus, &"Master", "every loop goes through its own bus")
	assert_eq(playing, 8, "the eight loops play from the start")
	audio._process(FRAME_S)
	get_tree().paused = true
	assert_false(audio.can_process(), "the sound stops while paused")
	get_tree().paused = false


func test_the_sound_is_quieter_behind_the_start_menu() -> void:
	var menu: Node = (load("res://ui/start_menu.tscn") as PackedScene).instantiate()
	add_child_autofree(menu)
	var audio: GameAudio = menu.get_node("Sailing/GameAudio")
	audio._process(FRAME_S)
	assert_almost_eq(audio.mix.menu_gain, db_to_linear(audio.mix.config.menu_db), 1e-4, "quieter behind the menu")
	(menu.get_node("%OpenWaterButton") as Button).pressed.emit()
	for i: int in 240:
		audio._process(FRAME_S)
	assert_almost_eq(audio.mix.menu_gain, 1.0, 0.05, "full sound when sailing")


# --- The fin's voice and the rig's strain (SO1) -------------------------------------------

func test_the_fin_hums_at_speed_louder_near_the_stall_and_higher_with_speed() -> void:
	var slow: Telemetry = _telemetry(15.0, 4.0, 0.3)
	slow.fin_load_share = 0.9
	assert_eq(_settled(slow).hum.volume_db, SoundMix.SILENT_DB, "no hum below planing speed")
	var easy: Telemetry = _telemetry(20.0, 12.0, 0.8)
	easy.fin_load_share = 0.3
	var loaded: Telemetry = _telemetry(20.0, 12.0, 0.8)
	loaded.fin_load_share = 0.95
	var easy_mix: SoundMix = _settled(easy)
	var loaded_mix: SoundMix = _settled(loaded)
	assert_gt(easy_mix.hum.volume_db, -40.0, "a quiet hum while the fin works easily")
	assert_gt(loaded_mix.hum.volume_db, easy_mix.hum.volume_db + 10.0, "much louder near the stall")
	assert_almost_eq(loaded_mix.fin_edge, 0.9, 0.01, "nine tenths of the way from half load to the stall")
	var faster: Telemetry = _telemetry(20.0, 16.0, 0.9)
	faster.fin_load_share = 0.95
	assert_gt(_settled(faster).hum.pitch, loaded_mix.hum.pitch, "higher at 16 m/s than at 12")


func test_a_stalled_fin_stutters_and_a_fallen_sailor_hears_none() -> void:
	var stalled: Telemetry = _telemetry(20.0, 12.0, 0.8)
	stalled.fin_load_share = 1.0
	stalled.fin_stalled = true
	var mix: SoundMix = SoundMix.new()
	_run(mix, stalled, 1.0)
	var lowest: float = 0.0
	var highest: float = SoundMix.SILENT_DB
	for i: int in 60:
		stalled.time_s += FRAME_S
		mix.update(stalled, FRAME_S)
		lowest = minf(lowest, mix.hum.volume_db)
		highest = maxf(highest, mix.hum.volume_db)
	assert_gt(highest - lowest, 6.0, "the hum comes and goes over the top (%.1f dB)" % (highest - lowest))
	stalled.sailor_state = 1
	_run(mix, stalled, 2.0)
	assert_eq(mix.hum.volume_db, SoundMix.SILENT_DB, "silent in the water")


func test_the_rig_creaks_as_the_sailor_nears_the_edge() -> void:
	var easy: Telemetry = _telemetry(20.0, 12.0, 0.8)
	easy.lean = 0.6
	assert_eq(_settled(easy).strain.volume_db, SoundMix.SILENT_DB, "no creak with the hike in hand")
	var hiked: Telemetry = _telemetry(20.0, 12.0, 0.8)
	hiked.lean = 0.95
	var hiked_mix: SoundMix = _settled(hiked)
	assert_gt(hiked_mix.strain.volume_db, -25.0, "a creak when hiked almost all the way out")
	var overloaded: Telemetry = _telemetry(20.0, 12.0, 0.8)
	overloaded.lean = 0.5
	overloaded.twa_deg = 60.0
	overloaded.feet_moment_excess_nm = 150.0
	var over_mix: SoundMix = _settled(overloaded)
	assert_almost_eq(over_mix.strain_amount, 1.0, 1e-6, "the feet's overload toward the sail is the edge")
	assert_gt(over_mix.strain.volume_db, hiked_mix.strain.volume_db, "louder than the hike alone")
	overloaded.feet_moment_excess_nm = -150.0
	assert_almost_eq(_settled(overloaded).strain_amount, 0.0, 1e-6, "an overload away from the sail is not it")
