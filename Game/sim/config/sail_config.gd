class_name SailConfig
extends Resource
## The sail and rig: geometry, mass, the sheeting range, and the aerodynamic coefficient
## curves (PHYSICS_SPEC.md sections 2, 3 and 14). Change values in the .tres file.

@export_group("Geometry")
## Sail area.
@export var area_m2: float = 6.5
## Luff length (the mast edge of the sail).
@export var luff_m: float = 4.60
## Boom length from the mast to the clew.
@export var boom_m: float = 1.95
## Height of the boom above the mast foot, along the mast.
@export var boom_height_m: float = 1.40
## Where the mast foot sits on the board, in the body frame (x starboard, y up, z aft).
## Real mast tracks are centred about 1.30 to 1.35 m from the tail of a 2.40 m board,
## that is 0.10 to 0.15 m forward of the centre.
@export var mast_foot_local: Vector3 = Vector3(0.0, 0.06, -0.10)
## Fraction of the luff above the mast foot at which the centre of effort sits (section 2.13).
@export var ce_height_fraction: float = 0.40
## Fraction of the boom behind the mast at which the centre of effort sits (section 2.13).
@export var ce_boom_fraction: float = 0.35
## Camber: depth of the sail's curve divided by its chord.
@export var camber: float = 0.10

@export_group("Rig mass")
## Mass of mast, boom, sail, extension and base together.
@export var rig_mass_kg: float = 8.0
## Height of the rig's centre of mass above the mast foot.
@export var rig_com_height_m: float = 1.7
## Length of the mast, used for the rig's own inertia (a thin rod).
@export var mast_m: float = 4.60

@export_group("Controls")
## Boom angle from the centreline when the sheet is fully in.
@export var sheet_angle_in_deg: float = 12.0
## Boom angle from the centreline when the sheet is fully out.
@export var sheet_angle_out_deg: float = 85.0
## Mast rake at full input, positive = raked back. Sailors swing the rig through about
## 25 degrees each way from upright when steering hard.
@export var max_rake_deg: float = 25.0
## The sail keeps its side until the wind is this close to dead ahead or dead astern.
@export var side_hysteresis_deg: float = 5.0

@export_group("Lift coefficient curve")
## Reduction of the thin-airfoil lift slope for a soft sail with gaps.
@export var lift_slope_factor: float = 0.9
## Zero-lift angle in degrees per unit of camber (a cambered sail lifts at zero angle).
@export var zero_lift_deg_per_camber: float = 60.0
## End of the linear part of the curve.
@export var cl_linear_end_deg: float = 12.0
## Angle of maximum lift.
@export var cl_peak_deg: float = 18.0
## Extra lift gained between the linear end and the peak.
@export var cl_transition_gain: float = 0.3
## End of the stall drop; lift there is stall_retention times the peak.
@export var cl_stall_end_deg: float = 25.0
@export var stall_retention: float = 0.85
## Angle from which the sail acts as a flat plate.
@export var cl_deep_stall_deg: float = 45.0
@export var deep_stall_cl: float = 0.5
## Below this angle of attack the sail is luffing and its lift fades to zero (section 2.9).
@export var alpha_luff_deg: float = 5.0

@export_group("Drag coefficient")
## Drag with no lift: cloth friction, mast, boom and battens. Rig coefficient sets in the
## yacht-design literature (Larsson and Eliasson, Marchaj) put this at about 0.04 for a
## complete rig; the legacy 0.015 was a bare clean sail.
@export var cd_parasitic: float = 0.04
## Span efficiency of the induced drag term.
@export var oswald_e: float = 0.75
## Separation drag grows as ((alpha - start) / span)^2 times this gain.
@export var cd_separation_start_deg: float = 15.0
@export var cd_separation_span_deg: float = 30.0
@export var cd_separation_gain: float = 0.5
## Flat-plate drag above the deep-stall angle: cd_form_gain * sin(alpha).
@export var cd_form_gain: float = 1.2
## A sail square to the wind has a drag coefficient of about 1.2 to 1.5 (section 2.8).
@export var cd_max: float = 1.3

@export_group("Limits")
## Below this apparent wind speed the sail produces no force (avoids dividing by zero).
@export var min_apparent_wind_ms: float = 0.5


## Aspect ratio as the lift-slope formula wants it: luff squared over area.
func aspect_ratio() -> float:
	return luff_m * luff_m / area_m2


func max_rake_rad() -> float:
	return deg_to_rad(max_rake_deg)
