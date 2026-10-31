class_name PushDial
extends RefCounted
## The push slider (ROADMAP GP1; Documentation/reports/push_slider/PLAN.md) onto the sailor: a
## level from 0 (standing still, the sail let fly) to 1 (the most speed, a crash likely) is
## turned into what the sailor does, through the ladder in PushCurveConfig
## (Game/config/push_curve_default.tres): the sail's drive, the pull held, the rig's lean, the
## back foot against the fin, the rail and the trim. The pilot's part goes onto the Autopilot
## (the auto-sheet's margin, the sail's drive and the fin's push), the sailor's part onto this
## board's SimControls, so nothing writes a config while playing and every board has its own.
## The player's beginner controller and the AI boards sail through the same pilot, so the slider
## reaches both alike (rule 7). The three-setting dial of the autopilot suite (eased / neutral /
## pushed, measured as hike_share 0.8 / 1.0 / 1.6 with the rig's lean 25 / 25 / 35) is the
## slider at 0.5 / 0.75 / 1.

## The old dial's three settings as slider levels.
const EASED: float = 0.5
const NEUTRAL: float = 0.75
const PUSHED: float = 1.0

const DEFAULT_CURVE_PATH: String = "res://config/push_curve_default.tres"


## The game's ladder.
static func default_curve() -> PushCurveConfig:
	return load(DEFAULT_CURVE_PATH) as PushCurveConfig


## Sets the slider's level on a pilot (the auto-sheet's margin, the sail's drive, the fin's
## push) and on a board's controls (the rig's lean, the rail and the trim on top of the
## technique's). Either may be null.
static func apply_level(level: float, curve: PushCurveConfig, pilot: Autopilot, controls: SimControls) -> void:
	var t: float = clampf(level, 0.0, 1.0)
	if pilot != null:
		pilot.drive_share = curve.at(curve.drive_share, t)
		pilot.hike_share = curve.at(curve.hike_share, t)
		pilot.back_foot_bias = curve.at(curve.back_foot_push, t)
		pilot.wave_rail_max_deg = curve.at(curve.wave_rail_deg, t)
	if controls != null:
		controls.rig_lean_extra_deg = curve.at(curve.rig_lean_extra_deg, t)
		controls.rail_bank_extra_deg = curve.at(curve.rail_bank_extra_deg, t)
		controls.trim_aim_extra_deg = curve.at(curve.trim_aim_extra_deg, t)


## The level of a named setting: "eased", "neutral" or "pushed", or a number (0 to 1, or a
## percentage above 1); anything else is neutral.
static func level_of(name: String) -> float:
	match name.to_lower():
		"eased":
			return EASED
		"pushed":
			return PUSHED
		"neutral":
			return NEUTRAL
	if name.is_valid_float():
		var value: float = name.to_float()
		return clampf(value / 100.0 if value > 1.0 else value, 0.0, 1.0)
	return NEUTRAL


## One line for the HUD and the logs: the level and what it sets.
static func describe(level: float, curve: PushCurveConfig) -> String:
	var t: float = clampf(level, 0.0, 1.0)
	return "push %3.0f %%: drive %.2f, pull held %.2f, rig lean +%.0f deg, back foot %.2f, rail +%.1f deg (up to +%.0f more for the sea), trim +%.1f deg" % [
		t * 100.0, curve.at(curve.drive_share, t), curve.at(curve.hike_share, t), curve.at(curve.rig_lean_extra_deg, t),
		curve.at(curve.back_foot_push, t), curve.at(curve.rail_bank_extra_deg, t), curve.at(curve.wave_rail_deg, t), curve.at(curve.trim_aim_extra_deg, t)]
