class_name Autopilot
extends RefCounted
## A simple sailor for tests, scenarios and (later) the AI opponents: holds a wind angle
## with the rig, and trims the sheet to a chosen angle of attack. Everything it does is
## something a real sailor does with their arms; it never touches the physics directly.
##
## Steering: raking the mast back makes the board head up, raking it forward makes it
## bear away (PHYSICS_SPEC.md section 3). So when the board sails too far off the wind
## (the wind angle is larger than wanted) the rig goes back, and the other way round.

## Wanted true wind angle, in degrees, as a magnitude (the tack is whatever it is).
var target_twa_deg: float = 90.0
## Wanted angle of attack of the sail, in degrees, when the pilot does not know the sail.
var target_alpha_deg: float = 15.0
## The simulation's sail, when the pilot may use its lift and drag curves to sheet for the
## most drive at the current apparent wind angle, which is what a sailor does by feel:
## close to the wind that is a modest angle (drag costs), on a reach it is near the stall.
var sail: SailModel = null
## Rake per degree of wind-angle error.
var rake_gain_per_deg: float = 0.08
## Rake per degree per second of yaw rate, against overshoot.
var rake_yaw_damping: float = 0.02
## How fast the sailor moves the rig and the sheet (units per second).
var rake_rate_per_s: float = 3.0
var sheet_rate_per_s: float = 1.5
## Sheet and boom angle limits of the sail (from SailConfig).
var sheet_angle_in_deg: float = 12.0
var sheet_angle_out_deg: float = 85.0
var trim_sheet: bool = true
var hold_course: bool = true
## A real sailor does not try to point high from standstill: the fin only works with
## speed. Below this speed the pilot sails no closer than bear_away_twa_deg, then heads up.
var pointing_speed_ms: float = 5.0
var bear_away_twa_deg: float = 70.0
var _pointing: bool = false
## Depowering: the sheet is the throttle. As the sailor runs out of hike (lean above
## depower_lean_start) the wanted angle of attack is reduced smoothly toward min_alpha_deg,
## and leeward heel beyond a small allowance reduces it further.
var depower_lean_start: float = 0.75
var depower_heel_allowance_deg: float = 5.0
var depower_alpha_per_deg: float = 1.0
var min_alpha_deg: float = 3.0


## Updates controls.rake and controls.sheet from the last telemetry.
func update(telemetry: Telemetry, controls: SimControls, dt: float) -> void:
	if hold_course:
		if telemetry.speed_ms > pointing_speed_ms:
			_pointing = true
		elif telemetry.speed_ms < pointing_speed_ms - 1.5:
			_pointing = false
		var wanted_twa: float = target_twa_deg if _pointing else maxf(target_twa_deg, bear_away_twa_deg)
		var error_deg: float = absf(telemetry.twa_deg) - wanted_twa
		# A positive yaw rate turns the bow to port. On starboard tack (positive TWA) that is
		# bearing away, on port tack it is heading up: turn it into "rate of heading up".
		var heading_up_rate: float = -telemetry.yaw_rate_dps * signf(telemetry.twa_deg) if telemetry.twa_deg != 0.0 else 0.0
		var wanted_rake: float = clampf(rake_gain_per_deg * error_deg - rake_yaw_damping * heading_up_rate, -1.0, 1.0)
		controls.rake = move_toward(controls.rake, wanted_rake, rake_rate_per_s * dt)
	if trim_sheet:
		var alpha_deg: float = best_alpha_deg(deg_to_rad(telemetry.awa_deg))
		# Leeward heel is heel away from the wind: negative on starboard tack (wind from starboard).
		var leeward_heel_deg: float = -telemetry.heel_deg * signf(telemetry.twa_deg) if telemetry.twa_deg != 0.0 else 0.0
		var hike_used: float = clampf((absf(telemetry.lean) - depower_lean_start) / (1.0 - depower_lean_start), 0.0, 1.0)
		alpha_deg = lerpf(alpha_deg, min_alpha_deg, hike_used)
		if leeward_heel_deg > depower_heel_allowance_deg:
			alpha_deg = maxf(alpha_deg - depower_alpha_per_deg * (leeward_heel_deg - depower_heel_allowance_deg), min_alpha_deg)
		var boom_angle_deg: float = clampf(absf(telemetry.awa_deg) - alpha_deg, sheet_angle_in_deg, sheet_angle_out_deg)
		var wanted_sheet: float = 1.0 - (boom_angle_deg - sheet_angle_in_deg) / (sheet_angle_out_deg - sheet_angle_in_deg)
		controls.sheet = move_toward(controls.sheet, wanted_sheet, sheet_rate_per_s * dt)


## The angle of attack that gives the most drive at this apparent wind angle, from the
## sail's own lift and drag curves (drive = lift along the course minus drag against it).
func best_alpha_deg(awa_rad: float) -> float:
	if sail == null:
		return target_alpha_deg
	var awa: float = absf(awa_rad)
	var best_alpha: float = target_alpha_deg
	var best_drive: float = -INF
	var alpha_deg: float = 4.0
	while alpha_deg <= 24.0:
		var alpha: float = deg_to_rad(alpha_deg)
		var cl: float = sail.lift_coefficient(alpha)
		var cd: float = sail.drag_coefficient(cl, alpha)
		var drive: float = cl * sin(awa) - cd * cos(awa)
		if drive > best_drive:
			best_drive = drive
			best_alpha = alpha_deg
		alpha_deg += 1.0
	return best_alpha
