class_name SoundBank
extends RefCounted
## Every sound of the game, made from numbers when the game starts: no sound files, no
## samples. Each sound is noise (random numbers) shaped by simple filters and a volume
## envelope, then stored as a 16-bit, 44.1 kHz AudioStreamWAV. The loops loop seamlessly;
## the one-shots (splash, crack, swoosh) play once. A seeded random generator makes the
## same sounds every time, so the tests are repeatable.
##
## What a windsurfer hears, and how each sound imitates it (from descriptions and the
## acoustics literature; the team checks it by ear):
## - The wind in the ears grows fast with speed: measured wind noise at a cyclist's ears
##   goes from 85 dB at 10 mph to 120 dB at 60 mph (Seidman et al. 2017), about 13.6 dB
##   per doubling of the speed, and gets brighter as it gets louder. At speed a whistle
##   comes in (the wind past the ears, the lines and the leech of the sail).
##   -> wind: pink noise (more low than high, like a real rush of air) with a slow random
##      buffeting; its bus's low-pass opens up with the apparent wind. whistle: a narrow band
##      of white noise.
## - A board that is not planing pushes water aside: a low rumble and the irregular slap
##   and gurgle of small waves on the hull.
##   -> lapping: low-passed pink noise with random soft slaps; rumble: deep brown noise.
## - A planing board skims the surface and the energy of its drag goes into spray (NACA
##   reports on planing surfaces): a continuous high hiss that rises with the speed.
##   -> hiss: white noise with a fine fizz, through a band-pass that moves up with speed.
## - A slamming hull or a body falling in: a broadband impact, then the low "whump" of the
##   bubble plume (tens of Hz to a few hundred Hz, from studies of breaking waves and jets
##   hitting water), and spray falling back.
##   -> splash: a thud at 50 to 80 Hz plus noise whose low-pass sweeps down as it decays.
## - A luffing sail flaps like a flag, and a flag's flapping frequency is proportional to
##   the wind speed (its Strouhal number stays nearly constant, Virot et al. 2013): a rattle
##   that gets faster and harder in more wind. When the sail fills again it cracks.
##   -> flutter: a fast train of short noise bursts; crack: one sharp burst with a rebound.
## - In a tack the rig swings through the wind: a short rising and falling rush of air.
##   -> swoosh: noise through a band-pass that sweeps up and down, in a smooth swell.

const MIX_RATE_HZ: int = 44100
## The loops' lengths (seconds). Longer loops repeat less audibly but take longer to make.
const WIND_LOOP_S: float = 4.0
const HISS_LOOP_S: float = 3.0
const WHISTLE_LOOP_S: float = 3.0
const LAPPING_LOOP_S: float = 4.0
const RUMBLE_LOOP_S: float = 3.0
const FLUTTER_LOOP_S: float = 2.0
## The end of each loop fades into its start over this long, so the seam cannot be heard.
const LOOP_CROSSFADE_S: float = 0.2
## Every loop is made equally loud on average (this root-mean-square level), so the levels
## in the mix's config compare fairly between the voices. A loop with sharp peaks (the
## flutter) is held lower so its peaks stay below LOOP_PEAK.
const LOOP_RMS: float = 0.16
const LOOP_PEAK: float = 0.98
## The flutter loop's flaps per second at pitch 1 (SoundMix plays it faster in more wind).
const FLUTTER_RATE_HZ: float = 9.0

## The sounds of one game run are made once and shared (see shared()).
static var _shared: SoundBank = null

var wind: AudioStreamWAV
var hiss: AudioStreamWAV
var whistle: AudioStreamWAV
var lapping: AudioStreamWAV
var rumble: AudioStreamWAV
var flutter: AudioStreamWAV
var splashes: Array[AudioStreamWAV] = []
var cracks: Array[AudioStreamWAV] = []
var swoosh: AudioStreamWAV

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _seed: int = 0


## Makes every sound from the seed (the same seed gives the same sounds).
func _init(seed_value: int = 1) -> void:
	_seed = seed_value
	wind = _make_wind_loop()
	hiss = _make_hiss_loop()
	whistle = _make_whistle_loop()
	lapping = _make_lapping_loop()
	rumble = _make_rumble_loop()
	flutter = _make_flutter_loop()
	for i: int in SoundMix.SPLASH_VARIANTS:
		splashes.append(_make_splash(i))
	for i: int in SoundMix.CRACK_VARIANTS:
		cracks.append(_make_crack(i))
	swoosh = _make_swoosh()


## The one bank of this game run, made the first time it is asked for (that takes a moment,
## so going back to the start menu does not make the sounds again).
static func shared() -> SoundBank:
	if _shared == null:
		_shared = SoundBank.new()
	return _shared


# --- The loops ------------------------------------------------------------------------

func _make_wind_loop() -> AudioStreamWAV:
	_start(1)
	var count: int = _loop_count(WIND_LOOP_S)
	var samples: PackedFloat32Array = _pink_noise(count)
	_high_pass(samples, 40.0)
	# Buffeting: the level wanders slowly (gusts and eddies around the head), 0.7 to 1.
	_multiply(samples, _slow_wobble(count, 1.2, 0.7, 1.0))
	return _to_loop(samples)


func _make_hiss_loop() -> AudioStreamWAV:
	_start(2)
	var count: int = _loop_count(HISS_LOOP_S)
	var samples: PackedFloat32Array = _white_noise(count)
	# Only the highs: the bus's band-pass (WaterHiss) picks its band from 1.8 kHz up, so
	# that is where the loop's energy is.
	_high_pass(samples, 800.0)
	_high_pass(samples, 800.0)
	# The fizz: the level flickers quickly, as drops of spray come off the rails.
	_multiply(samples, _slow_wobble(count, 30.0, 0.6, 1.0))
	return _to_loop(samples)


## The raw material of the whistle: noise between about 0.8 and 3.5 kHz, from which the
## bus's narrow band-pass (WindWhistle) picks a moving tone.
func _make_whistle_loop() -> AudioStreamWAV:
	_start(6)
	var count: int = _loop_count(WHISTLE_LOOP_S)
	var samples: PackedFloat32Array = _white_noise(count)
	_high_pass(samples, 800.0)
	_high_pass(samples, 800.0)
	_low_pass(samples, 3500.0)
	_low_pass(samples, 3500.0)
	# A whistle comes and goes with the eddies: a slow wobble of its level.
	_multiply(samples, _slow_wobble(count, 0.8, 0.4, 1.0))
	return _to_loop(samples)


func _make_lapping_loop() -> AudioStreamWAV:
	_start(3)
	var count: int = _loop_count(LAPPING_LOOP_S)
	var samples: PackedFloat32Array = _pink_noise(count)
	_low_pass(samples, 900.0)
	_high_pass(samples, 60.0)
	# A quiet bed of water noise with soft slaps of small waves at random moments.
	var envelope: PackedFloat32Array = _constant(count, 0.3)
	var time_s: float = _rng.randf_range(0.0, 0.2)
	while time_s < float(count) / MIX_RATE_HZ:
		_add_pulse(envelope, time_s, 0.015, 9.0, _rng.randf_range(0.4, 1.0))
		time_s += _rng.randf_range(0.18, 0.55)
	_multiply(samples, envelope)
	return _to_loop(samples)


func _make_rumble_loop() -> AudioStreamWAV:
	_start(4)
	var count: int = _loop_count(RUMBLE_LOOP_S)
	var samples: PackedFloat32Array = _brown_noise(count)
	_low_pass(samples, 160.0)
	_high_pass(samples, 35.0)
	_multiply(samples, _slow_wobble(count, 2.0, 0.6, 1.0))
	return _to_loop(samples)


func _make_flutter_loop() -> AudioStreamWAV:
	_start(5)
	var count: int = _loop_count(FLUTTER_LOOP_S)
	var samples: PackedFloat32Array = _pink_noise(count)
	_high_pass(samples, 250.0)
	_low_pass(samples, 2500.0)
	# A train of flaps, a little irregular in time and strength, every fourth one harder.
	var envelope: PackedFloat32Array = _constant(count, 0.05)
	var time_s: float = 0.0
	var flap: int = 0
	while time_s < float(count) / MIX_RATE_HZ:
		var strength: float = 1.0 if flap % 4 == 0 else _rng.randf_range(0.45, 0.85)
		_add_pulse(envelope, time_s, 0.002, 45.0, strength)
		time_s += (1.0 / FLUTTER_RATE_HZ) * _rng.randf_range(0.75, 1.25)
		flap += 1
	_multiply(samples, envelope)
	return _to_loop(samples)


# --- The one-shots --------------------------------------------------------------------

## A splash: an impact click, the low thud of the bubble plume and spray that darkens as
## it falls back.
func _make_splash(variant: int) -> AudioStreamWAV:
	_start(10 + variant)
	var count: int = int(0.9 * MIX_RATE_HZ)
	var spray: PackedFloat32Array = _white_noise(count)
	_swept_low_pass(spray, 6000.0, 600.0)
	var envelope: PackedFloat32Array = _constant(count, 0.0)
	_add_pulse(envelope, 0.0, 0.006, 4.5, 1.0)
	_multiply(spray, envelope)
	var thud_hz: float = _rng.randf_range(50.0, 80.0)
	for i: int in count:
		var time_s: float = float(i) / MIX_RATE_HZ
		spray[i] += 0.7 * sin(TAU * thud_hz * time_s) * exp(-14.0 * time_s) * minf(time_s / 0.004, 1.0)
	return _to_one_shot(spray)


## A crack: the cloth snapping taut, with a smaller rebound a few hundredths later.
func _make_crack(variant: int) -> AudioStreamWAV:
	_start(20 + variant)
	var count: int = int(0.18 * MIX_RATE_HZ)
	var samples: PackedFloat32Array = _pink_noise(count)
	_high_pass(samples, 300.0)
	_swept_low_pass(samples, 5000.0, 1200.0)
	var envelope: PackedFloat32Array = _constant(count, 0.0)
	_add_pulse(envelope, 0.0, 0.0015, 30.0, 1.0)
	_add_pulse(envelope, _rng.randf_range(0.025, 0.045), 0.0015, 40.0, 0.5)
	_multiply(samples, envelope)
	return _to_one_shot(samples)


## A swoosh: a rush of air that swells and fades while its pitch rises and falls.
func _make_swoosh() -> AudioStreamWAV:
	_start(30)
	var count: int = int(1.0 * MIX_RATE_HZ)
	var samples: PackedFloat32Array = _pink_noise(count)
	_swept_band_pass(samples, 350.0, 1500.0)
	for i: int in count:
		var share: float = float(i) / count
		# A smooth bell (sin squared) that peaks at 40 % of the sound: it swells, then fades.
		var phase: float = 0.5 * share / 0.4
		if share >= 0.4:
			phase = 0.5 + 0.5 * (share - 0.4) / 0.6
		var bell: float = sin(PI * phase)
		samples[i] *= bell * bell
	return _to_one_shot(samples)


# --- Noise ----------------------------------------------------------------------------

## Each sound starts its own random sequence, so changing one sound does not change others.
func _start(sound_number: int) -> void:
	_rng.seed = _seed * 1000 + sound_number


## Equal energy at every frequency: a bright hiss.
func _white_noise(count: int) -> PackedFloat32Array:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i: int in count:
		samples[i] = _rng.randf_range(-1.0, 1.0)
	return samples


## Equal energy in every octave (3 dB less per octave than white): the sound of wind, rain
## and surf. Paul Kellet's well-known filter: a few one-pole filters on white noise.
func _pink_noise(count: int) -> PackedFloat32Array:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var b: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
	for i: int in count:
		var white: float = _rng.randf_range(-1.0, 1.0)
		b[0] = 0.99886 * b[0] + white * 0.0555179
		b[1] = 0.99332 * b[1] + white * 0.0750759
		b[2] = 0.96900 * b[2] + white * 0.1538520
		b[3] = 0.86650 * b[3] + white * 0.3104856
		b[4] = 0.55000 * b[4] + white * 0.5329522
		b[5] = -0.7616 * b[5] - white * 0.0168980
		samples[i] = (b[0] + b[1] + b[2] + b[3] + b[4] + b[5] + b[6] + white * 0.5362) * 0.11
		b[6] = white * 0.115926
	return samples


## Even more weight in the lows (6 dB less per octave): a deep rumble. White noise summed
## up, with a small leak so it does not drift away.
func _brown_noise(count: int) -> PackedFloat32Array:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var level: float = 0.0
	for i: int in count:
		level = 0.995 * level + 0.1 * _rng.randf_range(-1.0, 1.0)
		samples[i] = level
	return samples


## A slowly wandering level between low and high: smoothed random steps.
func _slow_wobble(count: int, rate_hz: float, low: float, high: float) -> PackedFloat32Array:
	var wobble: PackedFloat32Array = _white_noise(count)
	_low_pass(wobble, rate_hz)
	_low_pass(wobble, rate_hz)
	_normalize(wobble, 1.0)
	for i: int in count:
		wobble[i] = lerpf(low, high, 0.5 + 0.5 * wobble[i])
	return wobble


# --- Filters and envelopes --------------------------------------------------------------

## A one-pole low-pass: keeps what is below cutoff_hz, softens what is above.
func _low_pass(samples: PackedFloat32Array, cutoff_hz: float) -> void:
	var share: float = _one_pole_share(cutoff_hz)
	var state: float = 0.0
	for i: int in samples.size():
		state += share * (samples[i] - state)
		samples[i] = state


## A one-pole high-pass: what the low-pass would remove is what stays.
func _high_pass(samples: PackedFloat32Array, cutoff_hz: float) -> void:
	var share: float = _one_pole_share(cutoff_hz)
	var state: float = 0.0
	for i: int in samples.size():
		state += share * (samples[i] - state)
		samples[i] -= state


## A low-pass whose cutoff glides from from_hz to to_hz (on a log scale) over the sound.
func _swept_low_pass(samples: PackedFloat32Array, from_hz: float, to_hz: float) -> void:
	var state: float = 0.0
	var count: int = samples.size()
	for i: int in count:
		var cutoff_hz: float = SoundMix.log_lerp(from_hz, to_hz, float(i) / count)
		state += _one_pole_share(cutoff_hz) * (samples[i] - state)
		samples[i] = state


## A band-pass whose centre rises from low_hz to high_hz and back down over the sound. A
## "state variable" filter: two running sums that ring at the centre frequency.
func _swept_band_pass(samples: PackedFloat32Array, low_hz: float, high_hz: float) -> void:
	var low: float = 0.0
	var band: float = 0.0
	var damping: float = 0.7
	var count: int = samples.size()
	for i: int in count:
		var centre_hz: float = SoundMix.log_lerp(low_hz, high_hz, sin(PI * float(i) / count))
		var f: float = 2.0 * sin(PI * centre_hz / MIX_RATE_HZ)
		low += f * band
		var high: float = samples[i] - low - damping * band
		band += f * high
		samples[i] = band


## How far a one-pole filter moves toward the input per sample, for a cutoff frequency.
func _one_pole_share(cutoff_hz: float) -> float:
	var dt: float = 1.0 / MIX_RATE_HZ
	var rc: float = 1.0 / (TAU * cutoff_hz)
	return dt / (rc + dt)


func _constant(count: int, value: float) -> PackedFloat32Array:
	var values: PackedFloat32Array = PackedFloat32Array()
	values.resize(count)
	values.fill(value)
	return values


## Adds a pulse to an envelope: a straight rise over attack_s from start_s, then an
## exponential decay (decay_per_s: the larger, the shorter).
func _add_pulse(envelope: PackedFloat32Array, start_s: float, attack_s: float, decay_per_s: float, height: float) -> void:
	var first: int = int(start_s * MIX_RATE_HZ)
	# After 7 / decay_per_s the pulse is below 0.1 % of its height: stop there.
	var last: int = mini(envelope.size(), first + int((attack_s + 7.0 / decay_per_s) * MIX_RATE_HZ))
	for i: int in range(first, last):
		var time_s: float = float(i - first) / MIX_RATE_HZ
		var rise: float = minf(time_s / attack_s, 1.0)
		envelope[i] += height * rise * exp(-decay_per_s * maxf(time_s - attack_s, 0.0))


func _multiply(samples: PackedFloat32Array, by: PackedFloat32Array) -> void:
	for i: int in samples.size():
		samples[i] *= by[i]


## Scales so the loudest sample is at peak (1 = full scale).
func _normalize(samples: PackedFloat32Array, peak: float) -> void:
	var loudest: float = 0.0
	for value: float in samples:
		loudest = maxf(loudest, absf(value))
	if loudest < 1e-9:
		return
	var scale: float = peak / loudest
	for i: int in samples.size():
		samples[i] *= scale


## Scales to an average (root-mean-square) level, but never so far that a peak passes peak.
func _normalize_rms(samples: PackedFloat32Array, target_rms: float, peak: float) -> void:
	var total: float = 0.0
	var loudest: float = 0.0
	for value: float in samples:
		total += value * value
		loudest = maxf(loudest, absf(value))
	var rms_now: float = sqrt(total / maxi(samples.size(), 1))
	if rms_now < 1e-9:
		return
	var scale: float = minf(target_rms / rms_now, peak / loudest)
	for i: int in samples.size():
		samples[i] *= scale


# --- To AudioStreamWAV ----------------------------------------------------------------

## The number of samples to make for a loop: its length plus the crossfade.
func _loop_count(length_s: float) -> int:
	return int((length_s + LOOP_CROSSFADE_S) * MIX_RATE_HZ)


## A seamless loop: the extra samples at the end fade into the start (equal power, as the
## two pieces of noise are unrelated), then they are cut off.
func _to_loop(samples: PackedFloat32Array) -> AudioStreamWAV:
	var fade: int = int(LOOP_CROSSFADE_S * MIX_RATE_HZ)
	var length: int = samples.size() - fade
	for i: int in fade:
		var share: float = float(i) / fade
		samples[i] = samples[length + i] * cos(share * PI * 0.5) + samples[i] * sin(share * PI * 0.5)
	samples.resize(length)
	_normalize_rms(samples, LOOP_RMS, LOOP_PEAK)
	var stream: AudioStreamWAV = _to_stream(samples)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = length
	return stream


func _to_one_shot(samples: PackedFloat32Array) -> AudioStreamWAV:
	_normalize(samples, 0.9)
	# The last few milliseconds fade to zero, so the sound cannot end with a click.
	var fade: int = mini(int(0.005 * MIX_RATE_HZ), samples.size())
	for i: int in fade:
		samples[samples.size() - 1 - i] *= float(i) / fade
	var stream: AudioStreamWAV = _to_stream(samples)
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return stream


## 16-bit mono at 44.1 kHz: each sample as a whole number from -32767 to 32767 in two bytes.
func _to_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE_HZ
	stream.stereo = false
	stream.data = bytes
	return stream


# --- For the tests ----------------------------------------------------------------------

## The number of samples in a stream (16-bit mono: two bytes each).
static func sample_count(stream: AudioStreamWAV) -> int:
	return stream.data.size() / 2


## A sample of a stream as a number from -1 to 1.
static func sample_at(stream: AudioStreamWAV, index: int) -> float:
	return stream.data.decode_s16(index * 2) / 32767.0


## The root-mean-square level (0 = silence, 0.7 = a full-scale sine).
static func rms(stream: AudioStreamWAV) -> float:
	var count: int = sample_count(stream)
	if count == 0:
		return 0.0
	var total: float = 0.0
	for i: int in count:
		var value: float = sample_at(stream, i)
		total += value * value
	return sqrt(total / count)
