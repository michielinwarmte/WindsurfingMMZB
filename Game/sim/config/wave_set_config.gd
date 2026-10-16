class_name WaveSetConfig
extends Resource
## The sea state: up to four Gerstner waves that both the physics (WaveField) and the
## ocean shader read, so the board floats on the surface the player sees (plan decision
## D5; PHYSICS_SPEC.md section 9). Change values in the .tres.
##
## The waves come in two groups, each with its own direction (section 9.15):
##   - the swell: long waves made by wind far away. They can come from any direction:
##     with the local wind (an offset from downwind) or from a fixed compass bearing.
##   - the chop: the waves the local wind makes. They always travel with the wind, turned
##     by chop_offset_deg.
## Each wave says which group it belongs to (GerstnerWaveConfig.group), and its own
## direction_offset_deg spreads it a little around its group's direction.

const MAX_WAVES: int = 4

## false: flat water, the whole wave model is skipped.
@export var enable_waves: bool = true
## The waves, swell and chop together. Only the first four with an amplitude above zero
## are used (the shader has four slots), in this order.
@export var waves: Array[GerstnerWaveConfig] = []

@export_group("Swell")
## true: the swell travels downwind, turned by swell_offset_deg, and turns with the wind.
## false: it comes FROM the compass bearing swell_from_deg, whatever the wind does.
@export var swell_relative_to_wind: bool = true
## With swell_relative_to_wind: the swell's direction as an offset from the downwind
## bearing, degrees, positive = clockwise seen from above.
@export_range(-180.0, 180.0) var swell_offset_deg: float = 0.0
## Without swell_relative_to_wind: the compass bearing the swell comes FROM, degrees
## (0 = from the North, 270 = from the West), said the same way as the wind.
@export_range(0.0, 360.0) var swell_from_deg: float = 270.0

@export_group("Chop")
## The chop's direction as an offset from the downwind bearing, degrees, positive =
## clockwise seen from above (0: the chop travels straight downwind).
@export_range(-90.0, 90.0) var chop_offset_deg: float = 0.0


## The waves that count: an amplitude above zero, at most MAX_WAVES of them.
func active_waves() -> Array[GerstnerWaveConfig]:
	var active: Array[GerstnerWaveConfig] = []
	for wave: GerstnerWaveConfig in waves:
		if wave != null and wave.amplitude_m > 0.0 and active.size() < MAX_WAVES:
			active.append(wave)
	return active


## The waves of one group (all of them, also the ones without amplitude), in list order.
func waves_in_group(group: GerstnerWaveConfig.Group) -> Array[GerstnerWaveConfig]:
	var found: Array[GerstnerWaveConfig] = []
	for wave: GerstnerWaveConfig in waves:
		if wave != null and wave.group == group:
			found.append(wave)
	return found


## The compass bearing the swell travels TOWARD, degrees, for a wind from
## wind_from_bearing_deg. Travelling toward is from + 180: a swell from the North travels
## South.
func swell_travel_bearing_deg(wind_from_bearing_deg: float) -> float:
	if swell_relative_to_wind:
		return wind_from_bearing_deg + 180.0 + swell_offset_deg
	return swell_from_deg + 180.0


## The compass bearing the chop travels toward, degrees: downwind, turned by the offset.
func chop_travel_bearing_deg(wind_from_bearing_deg: float) -> float:
	return wind_from_bearing_deg + 180.0 + chop_offset_deg


## The compass bearing one wave travels toward, degrees: its group's direction plus its
## own offset.
func travel_bearing_deg(wave: GerstnerWaveConfig, wind_from_bearing_deg: float) -> float:
	var group_bearing_deg: float = chop_travel_bearing_deg(wind_from_bearing_deg)
	if wave.group == GerstnerWaveConfig.Group.SWELL:
		group_bearing_deg = swell_travel_bearing_deg(wind_from_bearing_deg)
	return group_bearing_deg + wave.direction_offset_deg


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
