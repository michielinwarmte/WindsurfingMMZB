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
## Camber: depth of the sail's curve divided by its chord. The full-scale iQFOiL sail in the
## wind tunnel (Zhang et al. 2025, Documentation/2501.13254v1.pdf, Fig. 5d) has 6.3 to 6.6 %
## at its third batten with the outhaul on and 7.1 to 7.6 % with it eased (PH28).
@export var camber: float = 0.07

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
@export var side_hysteresis_deg: float = 15.0

@export_group("Lift coefficient curve")
## Share of the finite-wing lift slope 2 pi AR / (AR + 2) the sail keeps before it twists.
## The wind-tunnel sail at 4 m/s, where it barely twists, has the full slope (0.069 per
## degree against the formula's 0.068 for its aspect ratio of 3.36; PH28).
@export var lift_slope_factor: float = 1.0
## Zero-lift angle in degrees per unit of camber (a cambered sail lifts at zero angle). The
## wind-tunnel sail, flexible at full scale and rigid at a quarter scale alike, still lifts
## 0.12 to 0.18 at 1 degree: its lift starts at about -2 degrees at 6.4 % camber, so 28 here
## (the legacy 60 started it at -6 degrees and made twice the measured lift at small angles).
@export var zero_lift_deg_per_camber: float = 28.0
## End of the linear part of the curve.
@export var cl_linear_end_deg: float = 12.0
## Angle of maximum lift (the rigid quarter-scale model stalls at about 17 to 18 degrees).
@export var cl_peak_deg: float = 18.0
## Extra lift gained between the linear end and the peak: a peak of about 1.1 untwisted,
## between the rigid model's 1.21 and the full-scale sail's 0.98 to 1.08 in light wind.
@export var cl_transition_gain: float = 0.15
## End of the stall drop; lift there is stall_retention times the peak.
@export var cl_stall_end_deg: float = 25.0
@export var stall_retention: float = 0.85
## Angle from which the sail acts as a flat plate.
@export var cl_deep_stall_deg: float = 45.0
@export var deep_stall_cl: float = 0.5
## Below this angle of attack the sail is luffing and its lift fades to zero (section 2.9).
## The wind-tunnel sail still carries 0.15 to 0.18 at 1.3 degrees, so the fade is narrow.
@export var alpha_luff_deg: float = 2.0
## A backwinded sail (the wind on its leeward face) inverts its camber against the battens
## and still works, less well: its lift is this share of the normal sail's at the same angle.
@export var backwind_efficiency: float = 0.7
## How far the sailor can push the clew across the centreline toward the windward side
## beyond the fully sheeted position (backing the sail to get through a tack), degrees.
@export var boom_across_max_deg: float = 47.0

@export_group("Twist under load (PH28)")
## A real sail's top twists open as the wind pushes harder: the leech is loose on purpose and
## the mast bends, so the upper sections meet the wind at a smaller angle and the sail carries
## less than a rigid one at the same boom angle. In the wind tunnel (Zhang et al. 2025, Fig. 6
## and 8) the twist grows with the angle and the wind, and the lift at a fixed angle falls
## by the same share at every angle below the stall: to 0.94, 0.85 and 0.75 of the untwisted
## curve at 4, 6 and 8 m/s, which is 1 / (1 + q / q_twist) with q_twist about 125 Pa for that
## 8 m2 sail. A smaller sail loads its mast less at the same pressure (about 154 Pa scaled by
## area) on a softer mast (back toward 125): 140 here. The share is twist_factor() in the
## sail model. 0 switches the twist off: a rigid sail, as before PH28.
@export var twist_pressure_pa: float = 140.0
## The twist's share is not allowed below this. The tunnel only went to 8 m/s (39 Pa); beyond
## it this is an extrapolation, held at the point where the top of a real sail luffs and
## flutters at the top of its range (half the rigid lift, about 31 kt of apparent wind).
@export var twist_min_factor: float = 0.5
## Near the stall the twisted top carries the load the bottom has lost, so less of the lift is
## lost: at 8 m/s the peak fell to 0.89 of the light-wind peak where the linear part fell to
## 0.75, so this share (0.45) of the linear part's loss remains at the peak and beyond.
@export var twist_peak_share: float = 0.45
## The twisted top carries less, so the centre of effort comes down: in the tunnel it sat
## about 6 % lower at 8 m/s than at 4 m/s at the angles a sailor uses (Fig. 8d). The height
## is ce_height_fraction times (1 - this times (1 - the twist's share)).
@export var twist_ce_drop: float = 0.32

@export_group("Drag coefficient")
## Drag with no lift: cloth friction, mast, boom and battens. Rig coefficient sets in the
## yacht-design literature (Larsson and Eliasson, Marchaj) put this at about 0.04 for a
## complete rig; the legacy 0.015 was a bare clean sail.
@export var cd_parasitic: float = 0.04
## Span efficiency of the induced drag term.
@export var oswald_e: float = 0.75
## The deck and the water under the sail's foot act as a partial end plate: a wing with
## one end on a wall behaves like a wing of twice the aspect ratio, and a sail whose foot
## runs a few percent of its span above the deck keeps roughly half of that gain (Larsson
## and Eliasson, Principles of Yacht Design, ch. 7, the "gap" effect; Marchaj, Sail
## Performance: why racers pull the foot down to the deck). The fin has the same factor
## of 2 for the hull above it (FinConfig.end_plate_factor).
@export var end_plate_factor: float = 1.4
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


## Geometric aspect ratio: luff squared over area (3.26 for the default sail).
func geometric_aspect_ratio() -> float:
	return luff_m * luff_m / area_m2


## The aspect ratio the induced drag sees: the geometric one times the end-plate factor
## of the deck under the foot. The lift slope keeps the geometric one (the measured curves
## of section 2 are of a sail in a tunnel, and the lift data stand as measured).
func aspect_ratio() -> float:
	return geometric_aspect_ratio() * end_plate_factor


func max_rake_rad() -> float:
	return deg_to_rad(max_rake_deg)
