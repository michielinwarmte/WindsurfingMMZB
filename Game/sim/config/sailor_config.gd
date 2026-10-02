class_name SailorConfig
extends Resource
## The sailor: mass, where they stand, how far they lean, and how the automatic balance
## of beginner mode behaves (PHYSICS_SPEC.md sections 7 and 15). Change values in the .tres.

@export_group("Body")
## Mass of the sailor with wetsuit and harness.
@export var mass_kg: float = 75.0
## Height of the sailor's centre of mass above the board origin when standing upright
## (about 0.55 times body height above the feet, plus the deck height).
@export var com_height_m: float = 1.0
## Radius and height of the cylinder that stands in for the sailor's own inertia.
@export var torso_radius_m: float = 0.2
@export var height_m: float = 1.75

@export_group("Stance (fore and aft)")
## Where the sailor's weight is at rest and at low speed, in the body frame (z aft): the
## front foot by the mast foot, the back foot half a metre behind it.
@export var stance_rest_z_m: float = 0.15
## Where the weight is when planing: in the back footstraps, about 0.6 m from the tail.
@export var stance_planing_z_m: float = 0.60
## The sailor starts stepping back at this forward speed and is in the straps at the second.
@export var stance_speed_start_ms: float = 3.5
@export var stance_speed_full_ms: float = 7.0
## How fast the sailor can move fore and aft (fraction of the full stance per second).
@export var stance_rate_per_s: float = 1.0
## Hanging back against the sail's pull: the boom pulls the sailor forward at about this
## height above the feet, and the sailor leans back until their weight balances it.
@export var hang_height_m: float = 1.0
## The furthest the sailor's weight can hang back behind the feet.
@export var hang_back_max_m: float = 0.5

@export_group("Legs")
## The legs are the sailor's suspension. A standing person on a moving floor behaves like
## a mass on a damped spring with a natural frequency of about 2 Hz and a damping ratio of
## about 0.4 (Matsumoto and Griffin 1998, standing posture); the knees flex to absorb what
## the board does, and that is what takes the bounce out of a planing board.
@export var leg_natural_frequency_hz: float = 2.0
@export var leg_damping_ratio: float = 0.4
## How far the knees can flex either way from the normal stance before the legs reach a stop.
@export var leg_travel_m: float = 0.25

@export_group("Lean (sideways)")
## Sideways distance of the sailor's centre of mass from the centreline at full lean:
## hooked in with the feet on the windward rail and the body stretched out, the body's
## centre is about a metre outboard.
@export var lean_max_m: float = 1.0
## The centre of mass drops by this much at full lean (the body goes nearly horizontal).
@export var lean_height_drop_m: float = 0.5
## How fast the sailor can change the lean (fraction of full lean per second).
@export var lean_rate_per_s: float = 2.0
## The rig tips toward the sailor who hangs on it: mast lean toward the sailor's side at
## full lean. Raking the rig to windward is what real sailors do when hooked in; it brings
## the sail's centre of effort back over the board and gives the sail an upward component.
@export var max_rig_lean_deg: float = 25.0

@export_group("Windage")
## Frontal area times drag coefficient of the sailor's body in the apparent wind (a hiked
## sailor shows about half a square metre; a standing body about 0.7 m2 with Cd near 1).
@export var windage_area_cd_m2: float = 0.5

@export_group("Automatic balance (beginner mode)")
## The sailor leans this many units of full lean per radian of heel.
@export var balance_heel_gain: float = 4.0
## And this many per radian per second of heel rate.
@export var balance_rate_gain: float = 0.8
## The sailor also leans against the sail's heeling moment directly: units of full lean
## per newton metre of heeling moment divided by the sailor's maximum righting moment.
@export var balance_moment_gain: float = 1.0
## Fore-and-aft weight shift against the pitch rate (metres per radian per second): the
## sailor's answer to a bouncing nose.
@export var pitch_reflex_m_per_rad_s: float = 0.5
