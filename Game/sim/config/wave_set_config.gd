class_name WaveSetConfig
extends Resource
## The sea state: up to four Gerstner waves that both the physics (WaveField) and the
## ocean shader read, so the board floats on the surface the player sees (plan decision
## D5; PHYSICS_SPEC.md section 9). Change values in the .tres.

const MAX_WAVES: int = 4

## false: flat water, the whole wave model is skipped.
@export var enable_waves: bool = true
## true: the waves travel downwind (their offsets are measured from the downwind bearing);
## false: the offsets are measured from North.
@export var align_to_wind: bool = true
## The waves. Only the first four with an amplitude above zero are used.
@export var waves: Array[GerstnerWaveConfig] = []


## The waves that count: an amplitude above zero, at most MAX_WAVES of them.
func active_waves() -> Array[GerstnerWaveConfig]:
	var active: Array[GerstnerWaveConfig] = []
	for wave: GerstnerWaveConfig in waves:
		if wave != null and wave.amplitude_m > 0.0 and active.size() < MAX_WAVES:
			active.append(wave)
	return active


## The sum of the steepness of the active waves: above 1 the crests fold over and the
## height solve no longer converges (section 9.8).
func total_steepness() -> float:
	var total: float = 0.0
	for wave: GerstnerWaveConfig in active_waves():
		total += wave.steepness
	return total


## The largest possible crest above the still level: the sum of the amplitudes.
func total_amplitude_m() -> float:
	var total: float = 0.0
	for wave: GerstnerWaveConfig in active_waves():
		total += wave.amplitude_m
	return total


## What is wrong with this set, if anything (empty when it is fine).
func validate() -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	if waves.size() > MAX_WAVES:
		problems.append("more than %d waves: only the first %d are used" % [MAX_WAVES, MAX_WAVES])
	if total_steepness() > 1.0:
		problems.append("total steepness %.2f is above 1: the crests would fold over" % total_steepness())
	for wave: GerstnerWaveConfig in waves:
		if wave == null:
			continue
		if wave.wavelength_m < 0.5:
			problems.append("a wavelength below 0.5 m")
		if wave.amplitude_m < 0.0:
			problems.append("a negative amplitude")
		if wave.steepness < 0.0 or wave.steepness > 1.0:
			problems.append("a steepness outside 0 to 1")
	return problems
