class_name SoundMix
extends RefCounted
## The sound logic: from the simulation's telemetry to the volume, pitch and filter of each
## sound. Plain data with no nodes, so the unit tests can check it (tests/unit/test_audio.gd);
## GameAudio (game_audio.gd) copies the results onto the audio players every frame.
##
## The looping voices (generated in SoundBank, sound_bank.gd):
##   wind     the apparent wind in the sailor's ears: louder, higher and brighter with it.
##   whistle  a narrow whistle on top of the wind that only comes in at speed.
##   lapping  water knocking on the hull, the sound of a board that is not planing.
##   rumble   the low rumble of the hull pushing water aside in displacement mode.
##   hiss     the spray off a planing hull. Lapping and rumble fade out as the hiss comes in,
##            following the planing ratio (an equal-power crossfade, so the total stays even).
##   flutter  the sail flapping while it luffs (and during a tack or a gybe).
## The one-shot sounds, as events of this frame in one_shots:
##   splash   the hull slamming onto the water, the nose digging into a wave, a fall, a
##            water start.
##   crack    the sail filling with a snap after luffing (and softer as the luff collapses).
##   swoosh   the rig swinging through the wind as the sail changes sides.
## While the sailor is in the water the sail is silent; the wind and the water go on.
##
## Everything is smoothed in time (time constants of tens to hundreds of milliseconds), so
## the sound never jumps from one frame to the next (a jump in a level is heard as a click).
## The numbers are in SoundMixConfig (res://config/sound_mix_default.tres).

const CONFIG_PATH: String = "res://config/sound_mix_default.tres"
## The quietest level a voice is given: silence.
const SILENT_DB: float = -80.0
## A change of the hull's height above the water larger than this in one physics step is a
## reset or a teleport (the water start), not a movement.
const TELEPORT_M: float = 1.0
## How many versions of each one-shot SoundBank makes (the mix picks one at random).
const SPLASH_VARIANTS: int = 3
const CRACK_VARIANTS: int = 3

enum OneShotKind { SPLASH, CRACK, SWOOSH }


## One looping sound, as the players should play it this frame.
class Voice:
	extends RefCounted
	## The level for AudioStreamPlayer.volume_db (SILENT_DB when silent, never above 0).
	var volume_db: float = -80.0
	## The playback speed for AudioStreamPlayer.pitch_scale (1 = as generated).
	var pitch: float = 1.0
	## The cutoff (or centre) frequency of the filter on this voice's bus.
	var cutoff_hz: float = 1000.0
	## The smoothed amplitude (0 to 1) before the menu and camera gains.
	var amplitude: float = 0.0

	## Moves the voice a step toward its targets: the amplitude with its own time constant,
	## the pitch and the filter with the tone's.
	func follow(target_amplitude: float, target_pitch: float, target_cutoff_hz: float, dt: float,
			smoothing_s: float, tone_smoothing_s: float) -> void:
		amplitude = lerpf(amplitude, target_amplitude, SoundMix.smoothing_factor(dt, smoothing_s))
		var tone_step: float = SoundMix.smoothing_factor(dt, tone_smoothing_s)
		pitch = lerpf(pitch, target_pitch, tone_step)
		cutoff_hz = lerpf(cutoff_hz, target_cutoff_hz, tone_step)

	## The final level, with the menu and camera gains on top.
	func set_output(gain: float) -> void:
		volume_db = SoundMix.amplitude_to_db(amplitude * gain)


## A sound to start this frame.
class OneShot:
	extends RefCounted
	var kind: SoundMix.OneShotKind = SoundMix.OneShotKind.SPLASH
	var volume_db: float = -80.0
	var pitch: float = 1.0
	## Which of the generated versions to play.
	var variant: int = 0


var config: SoundMixConfig

var wind: Voice = Voice.new()
var whistle: Voice = Voice.new()
var lapping: Voice = Voice.new()
var rumble: Voice = Voice.new()
var hiss: Voice = Voice.new()
var flutter: Voice = Voice.new()
## The one-shot sounds to start this frame (cleared at every update).
var one_shots: Array[OneShot] = []

## How much the sail flaps right now (0 to 1, before smoothing), for the HUD or a printout.
var luff_amount: float = 0.0
## The planing ratio after smoothing, and how far the water sounds have crossed over to the
## hiss (0 = all lapping, 1 = all hiss).
var planing_smoothed: float = 0.0
var planing_share: float = 0.0
## What made the last one-shot, in words ("slam 1.4 m/s", "sail fills"), for printouts.
var last_event: String = ""
## The gains on top of every voice: quieter behind the start menu, and the board's sounds
## quieter with a far camera.
var menu_gain: float = 1.0
var camera_gain: float = 1.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _first_update: bool = true

# What the last physics step looked like, to see changes (splashes, the sail filling).
var _has_history: bool = false
var _last_time_s: float = 0.0
var _last_heave_m: float = 0.0
var _last_vertical_speed_ms: float = 0.0
var _last_bow_m: float = 0.0
var _last_bow_rate_ms: float = 0.0
var _last_sailing: bool = true
var _last_sail_side: int = 0
var _time_since_splash_s: float = 100.0
## The sail is luffing (with some hysteresis), and since how long it is in that state.
var _sail_luffing: bool = false
var _sail_state_s: float = 0.0


func _init(mix_config: SoundMixConfig = null, seed_value: int = 7) -> void:
	config = mix_config if mix_config != null else load(CONFIG_PATH)
	_rng.seed = seed_value


## Works out every voice and the one-shots of this frame. dt is the frame time (seconds);
## manoeuvre is PlayerController.manoeuvre_name() ("tacking", "gybing" or ""); in_menu is
## true behind the start menu; camera_distance_m is how far the camera is from the board.
func update(t: Telemetry, dt: float, manoeuvre: String = "", in_menu: bool = false,
		camera_distance_m: float = 0.0) -> void:
	one_shots.clear()
	dt = maxf(_finite(dt), 0.0)
	var aws_kt: float = maxf(_finite(t.aws_kt), 0.0)
	var speed_ms: float = maxf(_finite(t.speed_ms), 0.0)
	var sailing: bool = t.sailor_state == 0
	_update_gains(in_menu, _finite(camera_distance_m), dt)
	_update_planing(clampf(_finite(t.planing_ratio), 0.0, 1.0), dt)
	_detect_events(t, aws_kt, sailing)
	_update_wind(aws_kt, dt)
	_update_water(speed_ms, planing_share, _finite(t.bow_immersion_m), dt)
	_update_flutter(t, aws_kt, sailing, manoeuvre, dt)
	var board_gain: float = menu_gain * camera_gain
	wind.set_output(menu_gain)
	whistle.set_output(menu_gain)
	for voice: Voice in [lapping, rumble, hiss, flutter]:
		voice.set_output(board_gain)
	for shot: OneShot in one_shots:
		shot.volume_db = amplitude_to_db(db_to_linear(shot.volume_db) * board_gain)
	_first_update = false


## Every looping voice, for the player node and the tests.
func voices() -> Array[Voice]:
	return [wind, whistle, lapping, rumble, hiss, flutter]


# --- The looping voices -------------------------------------------------------------

## The wind in the ears: a level that rises a fixed number of dB per doubling of the
## apparent wind, a low-pass that opens up, and a little more pitch.
func _update_wind(aws_kt: float, dt: float) -> void:
	var c: SoundMixConfig = config
	var amplitude: float = db_to_linear(level_db(aws_kt, c.wind_full_kt, c.wind_max_db, c.wind_db_per_doubling, c.wind_max_db))
	var strength: float = _ramp(aws_kt, c.wind_cutoff_low_kt, c.wind_cutoff_high_kt)
	var cutoff_hz: float = log_lerp(c.wind_cutoff_low_hz, c.wind_cutoff_high_hz, strength)
	var pitch: float = lerpf(c.wind_pitch_low, c.wind_pitch_high, strength)
	wind.follow(amplitude, pitch, cutoff_hz, dt, c.wind_smoothing_s, c.tone_smoothing_s)
	# The whistle comes in gently (a square curve) above its start speed.
	var whistle_share: float = _ramp(aws_kt, c.whistle_start_kt, c.wind_full_kt)
	var whistle_amplitude: float = db_to_linear(c.whistle_max_db) * whistle_share * whistle_share
	var whistle_hz: float = log_lerp(c.whistle_low_hz, c.whistle_high_hz, whistle_share)
	whistle.follow(whistle_amplitude, 1.0, whistle_hz, dt, c.wind_smoothing_s, c.tone_smoothing_s)


## The planing ratio, smoothed (it flickers on the swell) and scaled so its average at full
## planing speed counts as fully planing.
func _update_planing(planing_ratio: float, dt: float) -> void:
	var step: float = 1.0 if _first_update else smoothing_factor(dt, config.planing_smoothing_s)
	planing_smoothed = lerpf(planing_smoothed, planing_ratio, step)
	planing_share = clampf(planing_smoothed / config.planing_full_ratio, 0.0, 1.0)


## The water: lapping and rumble while the hull displaces water, the hiss while it planes.
## planing is the share of planing, 0 to 1.
func _update_water(speed_ms: float, planing: float, bow_m: float, dt: float) -> void:
	var c: SoundMixConfig = config
	# Equal-power crossfade: cos and sin of the same angle, so the sum of the two powers
	# (cos^2 + sin^2) stays 1 while the sound changes from one to the other.
	var displacing: float = cos(planing * PI * 0.5)
	var planing_share: float = sin(planing * PI * 0.5)

	var pace: float = clampf(speed_ms / c.lapping_full_speed_ms, 0.0, 1.0)
	var lap: float = lerpf(db_to_linear(c.lapping_rest_db), db_to_linear(c.lapping_max_db), pace)
	lap *= lerpf(c.lapping_planing_residual, 1.0, displacing)
	lapping.follow(lap, lerpf(c.lapping_pitch_rest, c.lapping_pitch_fast, pace),
		log_lerp(c.lapping_cutoff_rest_hz, c.lapping_cutoff_fast_hz, pace),
		dt, c.water_smoothing_s, c.tone_smoothing_s)

	# The nose ploughing into the water (bow immersion) makes the rumble louder, up to 3x.
	var plough: float = clampf(1.0 + maxf(bow_m, 0.0) / c.rumble_bow_depth_m, 1.0, 3.0)
	var rumble_amplitude: float = db_to_linear(c.rumble_max_db) * clampf(speed_ms / c.rumble_full_speed_ms, 0.0, 1.0)
	rumble_amplitude = minf(rumble_amplitude * plough * displacing, 1.0)
	rumble.follow(rumble_amplitude, lerpf(0.9, 1.1, pace), 200.0, dt, c.water_smoothing_s, c.tone_smoothing_s)

	var hiss_amplitude: float = db_to_linear(level_db(speed_ms, c.hiss_ref_speed_ms, c.hiss_ref_db, c.hiss_db_per_doubling, c.hiss_max_db))
	var hiss_tone: float = _ramp(speed_ms, c.hiss_low_speed_ms, c.hiss_high_speed_ms)
	hiss.follow(hiss_amplitude * planing_share, lerpf(c.hiss_pitch_low, c.hiss_pitch_high, hiss_tone),
		log_lerp(c.hiss_low_hz, c.hiss_high_hz, hiss_tone), dt, c.water_smoothing_s, c.tone_smoothing_s)


## The sail's flutter: full while it luffs, fading out as the angle of attack grows, louder
## and faster in more wind, silent while the sailor is in the water.
func _update_flutter(t: Telemetry, aws_kt: float, sailing: bool, manoeuvre: String, dt: float) -> void:
	var c: SoundMixConfig = config
	luff_amount = 0.0
	if sailing and aws_kt >= c.flutter_min_aws_kt:
		luff_amount = _luff_share(t)
		if manoeuvre != "":
			luff_amount = maxf(luff_amount, c.manoeuvre_flutter)
	var target: float = luff_amount * db_to_linear(level_db(aws_kt, c.flutter_full_kt, c.flutter_max_db, c.flutter_db_per_doubling, c.flutter_max_db))
	# Quick to start (the flapping starts at once), a little slower to stop.
	var smoothing_s: float = c.flutter_attack_s if target > flutter.amplitude else c.flutter_release_s
	var pitch: float = clampf(aws_kt / c.flutter_ref_kt, c.flutter_pitch_min, c.flutter_pitch_max)
	var strength: float = _ramp(aws_kt, c.wind_cutoff_low_kt, c.wind_cutoff_high_kt)
	flutter.follow(target, pitch, log_lerp(c.flutter_cutoff_low_hz, c.flutter_cutoff_high_hz, strength),
		dt, smoothing_s, c.tone_smoothing_s)


## How much the sail luffs: nothing unless the simulation says it luffs; then 1 below the
## full-flutter angle of attack, 0 at the edge of the luff zone, a straight line between.
## A sail pressed from the wrong side (backwinded) is full and does not flap.
func _luff_share(t: Telemetry) -> float:
	if not t.is_luffing:
		return 0.0
	var alpha_deg: float = absf(_finite(t.alpha_deg))
	return 1.0 - _ramp(alpha_deg, config.flutter_full_below_alpha_deg, config.flutter_none_above_alpha_deg)


# --- The one-shots --------------------------------------------------------------------

## Compares this physics step with the last one: a slam, a dig, a fall, the water start,
## the sail filling or collapsing, the sail changing sides. Rates come from the simulation's
## own clock, so a frame without a new physics step (paused, or a fast screen) sees nothing.
func _detect_events(t: Telemetry, aws_kt: float, sailing: bool) -> void:
	var time_s: float = _finite(t.time_s)
	var heave_m: float = _finite(t.position.y) - _finite(t.water_height_m)
	var bow_m: float = _finite(t.bow_immersion_m)
	var reset: bool = not _has_history or time_s < _last_time_s or absf(heave_m - _last_heave_m) > TELEPORT_M
	if reset:
		_remember(t, time_s, heave_m, bow_m, sailing, 0.0, 0.0)
		_sail_luffing = false
		_sail_state_s = 0.0
		return
	var step_s: float = time_s - _last_time_s
	if step_s <= 0.0:
		return
	var vertical_speed_ms: float = (heave_m - _last_heave_m) / step_s
	var bow_rate_ms: float = (bow_m - _last_bow_m) / step_s
	_time_since_splash_s += step_s
	_sail_state_s += step_s

	if sailing and not _last_sailing:
		_add_splash(config.waterstart_db, 1.05, "water start")
	elif not sailing and _last_sailing:
		_add_splash(config.fall_catapult_db if t.fall_kind == "catapult" else config.fall_db, 0.85, "fall (%s)" % t.fall_kind)
	elif sailing:
		_detect_slam(t, vertical_speed_ms, bow_m, bow_rate_ms)
		_detect_sail_events(t, aws_kt)
	_remember(t, time_s, heave_m, bow_m, sailing, vertical_speed_ms, bow_rate_ms)


## A slam: the hull was falling toward the water fast and the water has just stopped it.
## The nose digging in: the bow going down into the water fast (counted once per dig).
func _detect_slam(t: Telemetry, vertical_speed_ms: float, bow_m: float, bow_rate_ms: float) -> void:
	var c: SoundMixConfig = config
	if _time_since_splash_s < c.splash_cooldown_s:
		return
	var was_falling_fast: bool = _last_vertical_speed_ms < -c.slam_speed_ms
	var stopped: bool = vertical_speed_ms > _last_vertical_speed_ms + c.slam_stop_ms
	if was_falling_fast and stopped and t.submersion_ratio > 0.0:
		var impact: float = _ramp(-_last_vertical_speed_ms, c.slam_speed_ms, c.splash_full_speed_ms)
		# A harder slam is louder and a little lower (more water moves).
		_add_splash(lerpf(c.splash_min_db, c.splash_max_db, impact), lerpf(1.1, 0.9, impact),
			"slam %.1f m/s" % -_last_vertical_speed_ms)
		return
	var digging: bool = bow_m > 0.0 and bow_rate_ms > c.bow_dig_rate_ms
	if digging and _last_bow_rate_ms <= c.bow_dig_rate_ms:
		_add_splash(c.bow_dig_db, 1.15, "nose dig %.1f m/s" % bow_rate_ms)


## The sail filling with a crack, collapsing with a softer one, and the swoosh of the rig
## swinging through the wind when the sail changes sides.
func _detect_sail_events(t: Telemetry, aws_kt: float) -> void:
	var c: SoundMixConfig = config
	if t.sail_side != _last_sail_side and _last_sail_side != 0 and aws_kt >= c.flutter_min_aws_kt:
		var swoosh: OneShot = _new_shot(OneShotKind.SWOOSH, level_db(aws_kt, c.swoosh_full_kt, c.swoosh_max_db, 12.0, c.swoosh_max_db))
		swoosh.pitch = clampf(aws_kt / c.swoosh_full_kt, 0.8, 1.25)
		last_event = "sail changes sides"
	# The luffing state has some hysteresis (it starts below one angle and ends above a
	# larger one), so a sail on the edge does not crack every frame.
	var luffing_now: bool = _sail_luffing
	if not _sail_luffing and _luff_share(t) >= 1.0:
		luffing_now = true
	elif _sail_luffing and _luff_share(t) <= 0.0:
		luffing_now = false
	if luffing_now == _sail_luffing:
		return
	var long_enough: bool = _sail_state_s >= c.crack_min_state_s
	_sail_luffing = luffing_now
	_sail_state_s = 0.0
	if not long_enough or aws_kt < c.crack_min_aws_kt:
		return
	var level: float = level_db(aws_kt, c.crack_full_kt, c.crack_max_db, 12.0, c.crack_max_db)
	if luffing_now:
		level += c.crack_collapse_db
	var crack: OneShot = _new_shot(OneShotKind.CRACK, level)
	last_event = "luff collapses" if luffing_now else "sail fills"
	crack.variant = _rng.randi_range(0, CRACK_VARIANTS - 1)
	crack.pitch = clampf(0.9 + 0.3 * _ramp(aws_kt, c.crack_min_aws_kt, c.crack_full_kt), 0.9, 1.2) * _rng.randf_range(0.95, 1.05)


func _add_splash(volume_db: float, pitch: float, cause: String) -> void:
	var splash: OneShot = _new_shot(OneShotKind.SPLASH, volume_db)
	last_event = cause
	splash.variant = _rng.randi_range(0, SPLASH_VARIANTS - 1)
	splash.pitch = pitch * _rng.randf_range(0.93, 1.07)
	_time_since_splash_s = 0.0


func _new_shot(kind: OneShotKind, volume_db: float) -> OneShot:
	var shot: OneShot = OneShot.new()
	shot.kind = kind
	shot.volume_db = minf(volume_db, 0.0)
	one_shots.append(shot)
	return shot


func _remember(t: Telemetry, time_s: float, heave_m: float, bow_m: float, sailing: bool,
		vertical_speed_ms: float, bow_rate_ms: float) -> void:
	_has_history = true
	_last_time_s = time_s
	_last_heave_m = heave_m
	_last_bow_m = bow_m
	_last_sailing = sailing
	_last_sail_side = t.sail_side
	_last_vertical_speed_ms = vertical_speed_ms
	_last_bow_rate_ms = bow_rate_ms


# --- Gains ----------------------------------------------------------------------------

## Behind the start menu everything fades down; a far camera makes the board quieter.
func _update_gains(in_menu: bool, camera_distance_m: float, dt: float) -> void:
	var c: SoundMixConfig = config
	var menu_target: float = db_to_linear(c.menu_db) if in_menu else 1.0
	var camera_db: float = 0.0
	if camera_distance_m > c.camera_near_m:
		camera_db = maxf(c.camera_db_per_doubling * doublings(camera_distance_m, c.camera_near_m), c.camera_min_db)
	var camera_target: float = db_to_linear(camera_db)
	if _first_update:
		menu_gain = menu_target
		camera_gain = camera_target
		return
	menu_gain = lerpf(menu_gain, menu_target, smoothing_factor(dt, c.menu_fade_s))
	camera_gain = lerpf(camera_gain, camera_target, smoothing_factor(dt, c.tone_smoothing_s))


# --- Small maths helpers (static, so the voices and the tests can use them) ------------

## A level in dB that is ref_db at ref_value and changes per_doubling dB for each doubling
## of value (12 dB per doubling: twice the wind, four times the amplitude), never above
## max_db; silence at zero.
static func level_db(value: float, ref_value: float, ref_db: float, per_doubling: float, max_db: float) -> float:
	if value <= 1e-3 or ref_value <= 0.0:
		return SILENT_DB
	var level: float = ref_db + per_doubling * doublings(value, ref_value)
	return clampf(level, SILENT_DB, max_db)


## How many times value is double (or half, negative) the reference: log2(value / reference).
static func doublings(value: float, reference: float) -> float:
	return log(value / reference) / log(2.0)


## A linear amplitude (0 to 1) as decibels for a player, clamped to SILENT_DB..0 dB.
static func amplitude_to_db(amplitude: float) -> float:
	if not (amplitude > db_to_linear(SILENT_DB)):
		return SILENT_DB
	return clampf(linear_to_db(amplitude), SILENT_DB, 0.0)


## The share of a step to move toward a target with a time constant smoothing_s: the
## exponential smoothing that does not depend on the frame rate.
static func smoothing_factor(dt: float, smoothing_s: float) -> float:
	if smoothing_s <= 0.0:
		return 1.0
	return 1.0 - exp(-dt / smoothing_s)


## Between two frequencies on a log scale (as the ear hears them): share 0.5 between 500 Hz
## and 2000 Hz is 1000 Hz, not 1250 Hz.
static func log_lerp(from_value: float, to_value: float, share: float) -> float:
	return from_value * pow(to_value / from_value, clampf(share, 0.0, 1.0))


## 0 at from_value, 1 at to_value, a straight line between, clamped.
static func _ramp(value: float, from_value: float, to_value: float) -> float:
	if to_value == from_value:
		return 1.0 if value >= to_value else 0.0
	return clampf((value - from_value) / (to_value - from_value), 0.0, 1.0)


## A number that is not a number (NaN) or infinite becomes 0, so one bad value from the
## physics cannot make the sound go wrong.
static func _finite(value: float) -> float:
	if is_nan(value) or is_inf(value):
		return 0.0
	return value
