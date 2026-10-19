class_name FinConfig
extends Resource
## The fin: an underwater wing under the tail (PHYSICS_SPEC.md section 4).
## Real 38 cm freeride fin. Change values in the .tres file.

@export_group("Geometry")
## Projected area of the fin.
@export var area_m2: float = 0.0365
## Depth of the fin from the hull bottom to the tip.
@export var span_m: float = 0.38
## Where the fin root sits on the hull bottom, in the body frame (x starboard, y up, z aft).
@export var root_local: Vector3 = Vector3(0.0, -0.06, 0.90)
## The fin's force acts this fraction of the span below the root.
@export var cop_span_fraction: float = 0.4
## The hull acts as an end plate for the fin, which raises the effective aspect ratio.
## For a keel under a hull the effective ratio is about twice the geometric one.
@export var end_plate_factor: float = 2.0

@export_group("Planform: the chord along the span")
## The chord narrows from the root to the tip and the tip is rounded, as in the 3-D model
## (tools/blender/build_rig_models.py, fin_chord): c(s) = c_root + (c_tip - c_root) * s^1.1
## at a span fraction s (0 = root, 1 = tip), times sqrt(1 - a^2) beyond tip_round_start.
## The root chord follows from the size (root_chord_m()), so the planform's area is area_m2.
## The tip's chord as a share of the root's.
@export var tip_chord_ratio: float = 0.37
## The power of s in the chord law.
@export var chord_taper_exponent: float = 1.1
## The span fraction where the tip's rounding starts.
@export var tip_round_start: float = 0.82
## Thickness of the section (NACA 00xx) as a share of the chord. The bend does not need it:
## for a constant ratio it is part of the stiffness scale (section 4, "The fin bends"). It is
## here so the physics and the 3-D model describe the same fin.
@export var thickness_ratio: float = 0.10

@export_group("Bending (U2)")
## The fin bends under its load, most at the tip, and its force tilts up toward the deck
## (section 4, "The fin bends"). Off: the stiff plate of before U2, exactly.
@export var bends: bool = true
## The flex test that sets the fin's stiffness: this load, hung at flex_test_position, moves
## the load point by flex_test_deflection_m. The default is a measured test: a 37 cm carbon
## slalom fin, 100 N at 80 % of the span, 20 mm (Nascimento 2017, IST Lisbon; section 14, U2).
@export var flex_test_load_n: float = 100.0
## Where the test load hangs, as a span fraction (1.0 = the tip).
@export var flex_test_position: float = 0.8
## How far the load point moved in the test.
@export var flex_test_deflection_m: float = 0.020
## The size of the fin the test was done on, drawn with this planform. The default is this
## game's own 38 cm fin standing in for the 37 cm test fin. A fin of another size (change
## span_m and area_m2, not these) is made of the same material: the same stiffness scale.
@export var flex_test_span_m: float = 0.38
@export var flex_test_area_m2: float = 0.0365
## The linear beam holds to about this slope; beyond it a real fin has long spun out. The
## slope of every part of the fin is capped here.
@export var max_bend_deg: float = 35.0

@export_group("Lift coefficient curve")
## End of the linear part of the lift curve.
@export var stall_linear_end_deg: float = 8.0
## Angle of maximum lift.
@export var stall_peak_deg: float = 12.0
## Extra lift gained between the linear end and the peak.
@export var stall_bump_cl: float = 0.15
## End of the stall drop; lift there is post_stall_fraction times the peak.
@export var stall_drop_end_deg: float = 16.0
@export var post_stall_fraction: float = 0.7
## From this angle the fin acts as a flat plate.
@export var deep_stall_deg: float = 25.0
@export var deep_stall_cl: float = 0.4
## The plate never gives less sideways force than this coefficient.
@export var min_cl: float = 0.1

@export_group("Drag coefficient")
## Profile drag of the section (NACA 0012 at Reynolds numbers of about one million).
@export var cd_profile: float = 0.008
## Span efficiency of the induced drag term.
@export var oswald_e: float = 0.9
## Small drag increase with lift from the thickening boundary layer.
@export var cd_viscous_factor: float = 0.5
## Drag coefficient of the fin as a flat plate square to the flow (applied as cd_plate * sin^2 of the slip).
@export var cd_plate: float = 1.2

@export_group("Limits")
## Below this flow speed the fin forces are zero (they would be below 0.01 N anyway).
@export var min_speed_ms: float = 0.05


## Geometric aspect ratio: span squared over area.
func aspect_ratio() -> float:
	return span_m * span_m / area_m2


## Aspect ratio used in the lift slope and the induced drag, including the hull end plate.
func effective_aspect_ratio() -> float:
	return aspect_ratio() * end_plate_factor


## Centre of pressure in the body frame.
func cop_local() -> Vector3:
	return root_local + Vector3(0.0, -cop_span_fraction * span_m, 0.0)


## The chord at span fraction s (0 = root, 1 = tip) as a share of the root chord.
func chord_shape(s: float) -> float:
	var shape: float = 1.0 + (tip_chord_ratio - 1.0) * pow(s, chord_taper_exponent)
	if s > tip_round_start and tip_round_start < 1.0:
		var a: float = (s - tip_round_start) / (1.0 - tip_round_start)
		shape *= sqrt(maxf(0.0, 1.0 - a * a))
	return shape


## The mean chord over the root chord: the chord law's average along the span (0.685 for the
## default law), by the midpoint rule over 200 strips.
func mean_to_root_chord() -> float:
	var strips: int = 200
	var total: float = 0.0
	for i: int in strips:
		total += chord_shape((i + 0.5) / strips)
	return total / strips


## The root chord of a fin of this span and area with this planform: area = mean chord * span.
func root_chord_for_m(fin_span_m: float, fin_area_m2: float) -> float:
	return fin_area_m2 / (mean_to_root_chord() * fin_span_m)


## The root chord of this fin (0.140 m for the default 38 cm fin).
func root_chord_m() -> float:
	return root_chord_for_m(span_m, area_m2)
