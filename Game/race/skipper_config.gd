class_name SkipperConfig
extends Resource
## The character sheet of a scripted skipper (RACING_PLAN.md, "The scripted skipper (9B)"): the
## numbers that make one opponent different from another. A weaker skipper has worse numbers here
## (a longer reaction time, a noisier helm, bigger margins); nobody gets a lighter board or more
## wind (decision RD7). One .tres per character in Game/race/skippers/, so the team can edit a
## skipper in the inspector. The rules that use these numbers are in Skipper.

## Shown on the label, the results and the mini-map. The four shipped characters have placeholder
## names; the team names them.
@export var name: String = "Skipper"
## The colour of its sail, for the scene and the mini-map.
@export var sail_colour: Color = Color(0.9, 0.3, 0.2)

@export_group("Angles")
## The best upwind wind angle: where the boat's speed toward the wind (VMG) is highest. From
## Documentation/POLAR_15KT.md: 45 degrees gives 7.9 kt of VMG at 15 kt of wind, more than 40
## (7.6 kt) or 60 (7.1 kt).
@export_range(35.0, 70.0) var upwind_vmg_twa_deg: float = 45.0
## The best downwind wind angle: where the boat's speed away from the wind is highest. From
## Documentation/POLAR_15KT.md: 135 degrees gives 14.4 kt of VMG, more than 120 (12.4 kt) or 150
## (9.3 kt, the board stops planing).
@export_range(110.0, 170.0) var downwind_vmg_twa_deg: float = 135.0
## Sails higher than the polar's best upwind angle (negative) or lower and faster (positive).
@export_range(-4.0, 6.0) var pointing_offset_deg: float = 0.0

@export_group("Margins")
## How far past the layline it sails before tacking or gybing, metres. A small margin means a
## risk of not laying the mark (and two more tacks); a big one sails extra distance.
@export_range(0.0, 60.0) var layline_margin_m: float = 10.0
## How close it rounds a mark, metres.
@export_range(4.0, 20.0) var mark_margin_m: float = 8.0
## The most tacks (or gybes) it makes on one leg. The layline tack is always allowed, so the cap
## limits the extra ones (for wind shifts).
@export_range(2, 8) var max_tacks_per_beat: int = 4

@export_group("Hands")
## The delay between seeing and doing, seconds: every decision reaches the stick this late.
@export_range(0.2, 1.0) var reaction_time_s: float = 0.3
## The wobble of its line: its wanted heading wanders by about this much (one standard
## deviation), slowly, degrees.
@export_range(0.0, 6.0) var steering_noise_deg: float = 0.5

@export_group("Start")
## Where on the start line it wants to cross: 0 = the pin end, 1 = the boat end.
@export_range(0.0, 1.0) var start_spot: float = 0.5
## Its timing error at the start, seconds: negative aims to cross before the gun (a risk of being
## over early, OCS), positive after it (safe, but metres lost).
@export_range(-3.0, 6.0) var start_timing_error_s: float = 0.5

@export_group("Tactics")
## How big a header (a wind shift that forces it away from the mark) makes it tack, degrees.
@export_range(5.0, 20.0) var shift_sensitivity_deg: float = 10.0
## How much more wind it goes looking for, 0 to 1 (the lake only; not used on the open water,
## which has no gusts to see).
@export_range(0.0, 1.0) var gust_appetite: float = 0.0
