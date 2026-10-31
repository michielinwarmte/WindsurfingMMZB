class_name PushDial
extends RefCounted
## The push dial (ROADMAP GP1, package A) onto the sailor's technique: what "eased", "neutral"
## and "pushed" set on the autopilot's margin and the sailor's technique, as measured on the
## PH28 physics by the autopilot suite (Documentation/reports/autopilot/PROGRESS.md, round 4).
## The player's beginner controller and the AI boards sail through the same pilot, so the dial
## reaches both alike (rule 7). The level runs from -1 (eased) through 0 (neutral) to +1
## (pushed), straight between the three settings.
##
## What each setting is, in numbers (the push check, gusts and waves, 120 s):
##   hike_share 0.8 / 1.0 / 1.6: the pull the sailor holds as a share of what the hike carries;
##     pushed pays +4 % across the wind at 18 kt, +7 % at 24 kt and +5 % upwind at 24 kt, with
##     no falls at 18 kt; the 24 kt broad reach falls when pushed (the physics' own failure:
##     the catapult). GP0's "late ease" (the depower and catch nets weakened) adds nothing on
##     this physics and catapults the 24 kt close reach: not part of the dial.
##   the rig's lean 25 / 25 / 35 degrees (SailorConfig.max_rig_lean_deg): more lean to windward
##     when powered, as the photos show (15 to 35, more when more powered); it pays +2 to 3 %
##     across the wind at both winds and the broad reaches do not mind it at neutral.
##   At 12 kt the dial changes nothing: the 85 kg rider is never overpowered by the 8.0 (PH26).

const EASED: float = -1.0
const NEUTRAL: float = 0.0
const PUSHED: float = 1.0

## The three settings' numbers, eased / neutral / pushed.
const HIKE_SHARE: PackedFloat64Array = [0.8, 1.0, 1.6]
const RIG_LEAN_DEG: PackedFloat64Array = [25.0, 25.0, 35.0]


## The value of a setting at a dial level (-1 to 1), straight between its three numbers.
static func at_level(numbers: PackedFloat64Array, level: float) -> float:
	var t: float = clampf(level, -1.0, 1.0)
	if t < 0.0:
		return lerpf(numbers[1], numbers[0], -t)
	return lerpf(numbers[1], numbers[2], t)


## Sets the dial on a pilot and on a sailor config: the pilot's own, and the sim's own copy of
## the sailor (WindsurferSim.sailor_config when own_copies is on, as the game has it), never
## the shared resource of a .tres file.
static func apply(level: float, pilot: Autopilot, sailor: SailorConfig) -> void:
	if pilot != null:
		pilot.hike_share = at_level(HIKE_SHARE, level)
	if sailor != null:
		sailor.max_rig_lean_deg = at_level(RIG_LEAN_DEG, level)


## The level of a named setting: "eased", "neutral" or "pushed" (anything else is neutral).
static func level_of(name: String) -> float:
	match name.to_lower():
		"eased":
			return EASED
		"pushed":
			return PUSHED
		_:
			return NEUTRAL
