class_name BoardConfig
extends Resource
## The board: its shape, volume and mass, and the few coefficients of the hull model.
## Every number is a real-world value for a 120 L freeride board (PHYSICS_SPEC.md section 14).
## Units are in the names. Change values in the .tres file, not here.

## Where a shaper measures the nose and tail widths: one foot (30.48 cm) in from the tip.
## Brands and test magazines quote the tail width there as "1ft off" (OFO).
const ONE_FOOT_M: float = 0.3048

@export_group("Shape")
## Length from nose to tail.
@export var length_m: float = 2.40
## Width at the widest point of the outline.
@export var width_m: float = 0.72
## Where the widest point is, measured forward from the tail. Freeride boards are widest a
## little behind the middle, under the front footstraps and the mast foot.
@export var widest_point_from_tail_m: float = 1.10
## The tail width one foot in from the tail ("1ft off", OFO): what sets how early and how
## loose a board planes. A wider tail lifts more at the same speed (Savitsky: lift grows
## with the beam squared) and planes earlier; a narrower one is more controlled in chop.
@export var tail_width_m: float = 0.45
## The nose width one foot in from the nose tip.
@export var nose_width_m: float = 0.45
## Thickness at the thickest point (at the widest point). Also the depth over which one
## buoyancy sample point goes from dry to fully under water (section 6.3).
@export var thickness_m: float = 0.12
## Thickness at the tail end (the transom).
@export var tail_thickness_m: float = 0.055
## Thickness at the nose tip.
@export var nose_thickness_m: float = 0.04
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

@export_group("Rails")
## A shaper calls a rail "hard" when the bottom meets the side in a sharp edge, and "soft"
## or "tucked" when the side curves round under the board. Freeride boards have hard rails
## in the tail (the water lets go cleanly at speed) that soften toward the nose (forgiving
## in chop). The rail is hard from the tail up to this distance from the tail...
@export var hard_rail_to_m: float = 1.2
## ...and fully soft from this distance from the tail to the nose, with a gradual change
## between the two.
@export var soft_rail_from_m: float = 2.0
## Height of the near-vertical face of a hard rail, from the bottom edge up to where the
## rail starts to round into the deck. When the board skids sideways, water meets this face
## (the "chine edge" of a planing hull, NACA TN 4187).
@export var rail_edge_height_m: float = 0.03

@export_group("Buoyancy sampling")
## Rows of sample points along the length (section 6.1).
@export var length_samples: int = 7
## Sample points across each row (rail, centre, rail).
@export var width_samples: int = 3

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
## Deadrise of the bottom: the vee across it, the angle each half rises from the keel
## toward its rail. Freeride boards carry a slight vee in the tail: surf-magazin's 2024
## freeride test measured 4 to 16.5 mm (median 8 mm) under a ruler laid on one half, 33 cm
## from the tail, which is 0.5 to 2 degrees (median 1) on a 0.47 m wide tail
## (PHYSICS_SPEC.md section 14). The hull model wets the vee (HullModel._wet_width) and
## takes it in Savitsky's lift; the buoyancy grid keeps a flat bottom.
@export var deadrise_deg: float = 1.0
## The tail cut-outs of a slalom board (PH16): over this distance forward of the tail the
## bottom is narrower than the deck's outline, by cutout_depth_m on each side at the tail,
## narrowing to nothing at the cut-out's front. The rail is stepped up there, so the water
## leaves the bottom at the step and wets only the narrower bottom (JP's Slalom: "the
## Cut-Out configuration reduces the outline width and the wetted surface of the bottom").
## Makers do not publish the sizes; 0 = no cut-outs (a freeride or wave tail).
@export var cutout_from_tail_m: float = 0.0
@export var cutout_depth_m: float = 0.0
## The footstraps the sailor stands in when planing, from the tail along the centreline, to
## the middle of each strap. While the feet are in them the feet's pressure stays between the
## two: at most all on the back foot, at most all on the front foot (the trim press is
## clamped there; PH16 step 17). Max's Patrik 115 slalom board (30 October 2026): the back
## straps over the fin box's front screw, 0.235 m; the front straps 0.825 m. 0 = no limit
## (the press reaches as far as SailorConfig.trim_press_max_m, as before).
@export var back_strap_from_tail_m: float = 0.0
@export var front_strap_from_tail_m: float = 0.0
## The rest of the board's layout, for its 3D model (tools/blender/build_rig_models.py; the
## physics' feet across are SailorConfig.feet_rail_m, its mast foot SailConfig.mast_foot_local).
## Max's Patrik 115 (30 October 2026): the middle of each back strap 0.15 m out from the
## centreline (30 cm apart), of each front strap 0.25 m (50 cm apart); the fin box's two screws
## on the deck 0.12 and 0.235 m from the tail (the back straps' middle over the front screw); the
## mast track from 1.245 to 1.405 m from the tail.
@export var back_strap_out_m: float = 0.0
@export var front_strap_out_m: float = 0.0
@export var fin_box_back_screw_from_tail_m: float = 0.0
@export var fin_box_front_screw_from_tail_m: float = 0.0
@export var mast_track_back_from_tail_m: float = 0.0
@export var mast_track_front_from_tail_m: float = 0.0
## The unsteady lift factor of the spray root running forward along a sinking hull (the
## slamming part of planing, section 5) is held at most at this: a flat bottom meeting
## rising water at a small angle would otherwise see an unbounded root speed.
@export var spray_root_factor_max: float = 2.0
## The planing lift answers a change of the water under the bottom over this time, not
## at once: a planing surface meeting waves at a reduced frequency near 1 (a 7 m chop at
## 10 m/s) lifts with a lag and well below its quasi-steady value (the unsteady planing
## models of Zarnick 1978 and Fridsma 1969 carry this). Zero takes it as instant.
@export var planing_lift_lag_s: float = 0.0
## The share of Archimedes' buoyancy a planing bottom still gets. At planing speed the
## water leaves the transom and the rails, so the pressure there is the air's, not the
## water's weight above it: the bottom carries about half its still-water buoyancy
## (Shuford 1958 for steady planing, used by Zarnick 1978; Savitsky's 1964 buoyant term
## gives 0.43 to 0.61 for wet lengths of 1.5 to 3 beams). HullModel phases it in across
## the semi-displacement range (Faltinsen 2005). 1.0 keeps Archimedes at every speed: the
## default until the team decides (PHYSICS_SPEC.md section 5, F21; 0.5 is the sourced value).
@export_range(0.0, 1.0) var planing_buoyancy_factor: float = 1.0
## Drag coefficient of the nose and deck when the bow goes under water (a blunt body
## meeting the water face-on: 0.8 to 1.0 for a box section; 0.8 as section 14 assumes).
## This is what stops a board that pearls, and what pitches it over the nose.
@export var bow_drag_cd: float = 0.8
## May a strip of the bottom behind the spray root pull, and how hard (PH28, the hull review's
## finding 1, Documentation/reports/ph28/hull_suction.md). The strip theory of the planing lift
## (Zarnick 1978) gives a pull wherever the bottom's angle to the flow shrinks going aft. On a
## scoop rocker that is every strip behind the spray root: the root meets the water at the
## rocker's own angle and pushes hard, the strips behind it take most of that back, and the
## whole follows the flat tail's angle (a convex, rockered bottom lifts less than a flat one,
## Savitsky 1964). 0 = no strip may pull (assumption A-05: the water has let go instead), as
## the model has always had it; on the JP SL 72's rocker that keeps the root's push and drops
## the pull, 2 to 3 times Savitsky's lift. Above 0 = a strip may pull, at most this many times
## the still water's head above the bottom there (rho g depth, over the strip's wet area): at
## 1 the pressure under the bottom may fall to the air's and no further, since air from the
## rails and the transom would get in (the hull reviewer's bound: geometry, an estimate of
## where the flow ventilates). A large number (1000) is the strip theory as written, no bound.
## With it on, the spray root's push is also spread so that the whole push sits where Savitsky
## measured it (HullModel step 5). Only 0, 1 and "no bound" have a source; anything in between
## is a fit. Off until Michiel decides (PHYSICS_SPEC.md section 5, A-05).
@export var strip_suction_heads: float = 0.0
## Where the whole of the water's push sits (PH28, hull_suction.md section 3). The root's push
## is spread behind the spray root as a triangle (HullModel step 5, A-03) so that its centre is
## Savitsky's (1964) measured centre of pressure; the push where the water reaches further
## across a vee or a heeled bottom (the oblique spray root) sat on its own strips, forward of
## it, so the push of the whole was 0.1 to 0.25 m forward of Savitsky's centre on the old
## board level and on the JP SL 72. true = that oblique push joins the root's, unrelieved, and
## the triangle is solved so that the whole push (strips and root) has Savitsky's centre
## (HullModel._spread_for_centroid). Always on with strip_suction_heads above 0. Off by
## default: measured in the reach check, for Michiel.
@export var push_at_savitsky_centre: bool = false
## The heeled bottom's lift as NACA TN 4187 measured it on a rolled flat plate (Savitsky,
## Prowse and Lueders 1958; PH28, hull_suction.md). 0 = as before: Savitsky's lift at the low
## rail's wet length, scaled by how much of the full width the strips wet, which at a short
## wet part gives 0.3 to 0.6 of Savitsky's at 2 degrees of heel and, level, 0.8 to 0.9 at 0.6 m
## because the vee's chine-dry front is counted in Savitsky's lambda and again in the strips'
## wet width. 1 = Savitsky's lift at the mean wetted length of the two rails (the high rail dry
## over 2 b tan(heel) / (pi tan(trim)) more than the low one, TN 4187 equation 2, Wagner's
## climb), with the heel as an added deadrise ("the effective deadrise of the surface is
## increased"), and the strips' total anchored on the widest wet strip, so the vee's front is
## counted once. Level, that is Savitsky's lift exactly at every wet length. Off until Michiel
## decides (PHYSICS_SPEC.md section 5, F23).
@export var heel_as_rolled_plate: float = 0.0


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


## Width of the outline at a distance forward of the transom. Between the widest point and
## the two one-foot points the outline is a parabola (flat at the widest point, curving more
## toward the ends); from the one-foot points to the tips it carries straight on along the
## parabola's tangent, as the nearly straight rail lines of a tail and nose do. Through the
## three numbers a shaper quotes: the widest point, the tail width and the nose width.
func width_at(from_transom_m: float) -> float:
	var reference_width: float = tail_width_m
	var reference_distance: float = widest_point_from_tail_m - ONE_FOOT_M
	var distance: float = widest_point_from_tail_m - from_transom_m
	if from_transom_m > widest_point_from_tail_m:
		reference_width = nose_width_m
		reference_distance = length_m - ONE_FOOT_M - widest_point_from_tail_m
		distance = from_transom_m - widest_point_from_tail_m
	reference_distance = maxf(reference_distance, 0.01)
	var narrowing: float = width_m - reference_width
	if distance <= reference_distance:
		var s: float = distance / reference_distance
		return width_m - narrowing * s * s
	var slope: float = 2.0 * narrowing / reference_distance
	return maxf(reference_width - slope * (distance - reference_distance), 0.0)


## Thickness of the board at a distance forward of the transom: full at the widest point,
## falling off as a parabola to the tail and nose thicknesses at the tips.
func thickness_at(from_transom_m: float) -> float:
	if from_transom_m <= widest_point_from_tail_m:
		var s: float = clampf((widest_point_from_tail_m - from_transom_m) / maxf(widest_point_from_tail_m, 0.01), 0.0, 1.0)
		return thickness_m - (thickness_m - tail_thickness_m) * s * s
	var n: float = clampf((from_transom_m - widest_point_from_tail_m) / maxf(length_m - widest_point_from_tail_m, 0.01), 0.0, 1.0)
	return thickness_m - (thickness_m - nose_thickness_m) * n * n


## How hard the rail is at a distance forward of the transom: 1 for a sharp edge, 0 for a
## soft (tucked) rail, changing linearly between hard_rail_to_m and soft_rail_from_m.
func rail_hardness(from_transom_m: float) -> float:
	if from_transom_m <= hard_rail_to_m:
		return 1.0
	if from_transom_m >= soft_rail_from_m:
		return 0.0
	return (soft_rail_from_m - from_transom_m) / maxf(soft_rail_from_m - hard_rail_to_m, 0.01)


## Width of the bottom at a distance forward of the transom: the outline less the tail
## cut-outs (cutout_from_tail_m, cutout_depth_m), what the water meets. The same as width_at
## on a board without cut-outs.
func bottom_width_at(from_transom_m: float) -> float:
	var width: float = width_at(from_transom_m)
	if cutout_from_tail_m > 0.0 and from_transom_m < cutout_from_tail_m:
		width -= 2.0 * cutout_depth_m * (1.0 - maxf(from_transom_m, 0.0) / cutout_from_tail_m)
	return maxf(width, 0.0)


## Planform area of the bottom: the bottom's width integrated over the length (midpoint
## rule; 1.346 m2 for the default board). Not cheap: models compute it once and keep it.
func planform_area_m2() -> float:
	var steps: int = 240
	var step_length: float = length_m / float(steps)
	var area: float = 0.0
	for i: int in steps:
		area += bottom_width_at((float(i) + 0.5) * step_length) * step_length
	return area
