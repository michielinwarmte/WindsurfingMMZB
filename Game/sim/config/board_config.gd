class_name BoardConfig
extends Resource
## The board: its shape, volume and mass, and the few coefficients of the hull model.
## Every number is a real-world value for a 120 L freeride board (PHYSICS_SPEC.md section 14).
## Units are in the names. Change values in the .tres file, not here.

@export_group("Shape")
## Length from nose to tail.
@export var length_m: float = 2.40
## Width at the widest point.
@export var width_m: float = 0.72
## Thickness of the hull box. Also the depth over which one buoyancy sample point goes from
## dry to fully under water (section 6.3).
@export var thickness_m: float = 0.12
## Total volume of the board. A 120 L board is written as 0.120.
@export var volume_m3: float = 0.120
## Mass of the bare board with straps and fin.
@export var mass_kg: float = 9.0
## The rocker line of a freeride board: a flat planing section in the middle and tail, a
## short upward kick at the very tail, and a progressive curve up to the nose.
## How far the bottom curves up at the nose tip.
@export var nose_rocker_m: float = 0.08
## Over what length from the nose the nose rocker builds up (quadratic).
@export var nose_rocker_length_m: float = 0.9
## How far the bottom kicks up at the tail tip.
@export var tail_rocker_m: float = 0.01
## Over what length from the tail the kick builds up (quadratic).
@export var tail_rocker_length_m: float = 0.35

@export_group("Buoyancy sampling")
## Rows of sample points along the length (section 6.1).
@export var length_samples: int = 7
## Sample points across each row (rail, centre, rail).
@export var width_samples: int = 3
## The half-width at the tips is (1 - width_taper) times the half-width in the middle.
@export var width_taper: float = 0.3
## The volume per row at the tips is (1 - volume_taper) times the volume in the middle.
@export var volume_taper: float = 0.4

@export_group("Hull hydrodynamics")
## Sideways drag coefficient of the immersed hull side, like a flat plate (section 5 F10).
@export var lateral_drag_cd: float = 1.0
## Wave-making ("residuary") drag as a fraction of the weight carried by buoyancy, at the hump.
## Planing craft show about 9 % at the hump; this is the one fitted curve in the hull model.
@export var residuary_peak_fraction: float = 0.09
## Froude number (speed / sqrt(g * wetted length)) at which the hump peaks.
@export var residuary_peak_froude: float = 0.55
## Width of the hump in Froude number.
@export var residuary_froude_width: float = 0.25
## Deadrise angle of the bottom near the tail. Freeride boards are nearly flat.
@export var deadrise_deg: float = 2.0


## Height of the bottom above the flat planing section, at a distance forward of the transom.
func bottom_rise_m(from_transom_m: float) -> float:
	if from_transom_m < tail_rocker_length_m:
		var t: float = (tail_rocker_length_m - from_transom_m) / tail_rocker_length_m
		return tail_rocker_m * t * t
	var nose_start: float = length_m - nose_rocker_length_m
	if from_transom_m > nose_start:
		var n: float = (from_transom_m - nose_start) / nose_rocker_length_m
		return nose_rocker_m * n * n
	return 0.0


## Slope of the bottom (metres of rise per metre toward the bow) at a distance forward of
## the transom: the derivative of bottom_rise_m.
func bottom_slope(from_transom_m: float) -> float:
	if from_transom_m < tail_rocker_length_m:
		var t: float = (tail_rocker_length_m - from_transom_m) / tail_rocker_length_m
		return -2.0 * tail_rocker_m * t / tail_rocker_length_m
	var nose_start: float = length_m - nose_rocker_length_m
	if from_transom_m > nose_start:
		var n: float = (from_transom_m - nose_start) / nose_rocker_length_m
		return 2.0 * nose_rocker_m * n / nose_rocker_length_m
	return 0.0


## Planform area of the bottom, from the tapered width: the average width factor over the
## length is 1 - width_taper / 3 for a quadratic taper.
func planform_area_m2() -> float:
	return length_m * width_m * (1.0 - width_taper / 3.0)
