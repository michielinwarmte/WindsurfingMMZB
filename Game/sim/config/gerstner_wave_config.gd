class_name GerstnerWaveConfig
extends Resource
## One Gerstner wave of the wave set (PHYSICS_SPEC.md section 9): which group it belongs
## to, where it travels, how long and how high it is, and how sharp its crests are.
## Change values in the .tres.

## SWELL: long waves made by wind far away, with their own direction (in the .tres: 0).
## CHOP: the waves the local wind makes, which travel with the wind (in the .tres: 1).
enum Group { SWELL, CHOP }

## The group this wave belongs to; the group sets its main direction (WaveSetConfig).
@export var group: Group = Group.CHOP
## Travel direction as a compass bearing offset from its group's direction, positive =
## clockwise seen from above. Spreads the waves of a group a little, as on real water.
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
