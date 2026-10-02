class_name WindConfig
extends Resource
## The wind: speed and direction, the increase with height, and optional gusts and shifts
## (PHYSICS_SPEC.md sections 8 and 15). Change values in the .tres file.
##
## The speed is given at the reference height, 10 m by convention (that is what a forecast
## or an anemometer reports). The sail, at about 2 m, sees less: with the open-water profile
## about 0.84 times the 10 m speed.

@export_group("Base wind")
## Wind speed at the reference height, in knots because that is how sailors read forecasts.
@export var speed_kt: float = 18.0
## Compass bearing the wind comes FROM: 0 = from the North, 90 = from the East, 270 = from the West.
@export var from_bearing_deg: float = 270.0

@export_group("Height profile")
## Multiply the speed by (height / reference_height) ^ shear_exponent.
@export var height_gradient_enabled: bool = true
## Height at which speed_kt is defined.
@export var reference_height_m: float = 10.0
## About 0.11 over open water (Hsu et al. 1994), 0.14 over flat land.
@export var shear_exponent: float = 0.11
## Below this height the profile is held constant (it would otherwise go to zero).
@export var min_height_m: float = 0.1

@export_group("Gusts")
## Deterministic gusts: a sum of three sine waves (section 8.3).
@export var gusts_enabled: bool = false
## Gust amplitude as a fraction of the base speed.
@export var gust_intensity: float = 0.2
## Period of the slowest gust component.
@export var gust_period_s: float = 8.0

@export_group("Shifts")
## Slow swings of the wind direction (section 8.4).
@export var shifts_enabled: bool = false
@export var max_shift_deg: float = 15.0
@export var shift_period_s: float = 60.0


func speed_ms() -> float:
	return speed_kt * SimMath.KNOT_MS
