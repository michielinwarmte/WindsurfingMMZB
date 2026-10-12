class_name GerstnerWaveConfig
extends Resource
## One Gerstner wave of the wave set (PHYSICS_SPEC.md section 9): where it travels, how
## long and how high it is, and how sharp its crests are. Change values in the .tres.

## Travel direction as a compass bearing offset from the base direction of the set
## (downwind when the set is aligned to the wind), positive = clockwise seen from above.
@export_range(-180.0, 180.0) var direction_offset_deg: float = 0.0
## Crest-to-crest distance. The deep-water dispersion relation gives the speed from this.
@export_range(0.5, 1000.0) var wavelength_m: float = 10.0
## Half the crest-to-trough height.
@export_range(0.0, 10.0) var amplitude_m: float = 0.1
## Crest sharpness: 0 is a sine, 1 a cusp (the sum over the set must stay at or below 1).
## A physically consistent trochoid has steepness = wave number x amplitude (2 pi A / L),
## which also makes the orbital velocity of the water the physical one.
@export_range(0.0, 1.0) var steepness: float = 0.25


## Wave number, rad/m.
func wave_number() -> float:
	return TAU / maxf(wavelength_m, 0.5)


## The steepness of a physically consistent trochoid of this length and height.
func physical_steepness() -> float:
	return wave_number() * amplitude_m
