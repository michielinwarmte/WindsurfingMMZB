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
