class_name Helm
extends RefCounted
## How a sailor turns the board: three things at once, all toward the same turn.
## - Rake: the rig back to head up, forward to bear away (PHYSICS_SPEC.md section 3). It
##   works through the sail's side force, so it fades away dead downwind.
## - Rig tilt: the rig toward the outside of the turn, so the sail's forward push acts
##   beside the centreline and swings the bow the other way. This is the lever that is left
##   when the sail only pushes forward.
## - Weight on the inside rail: the board heels toward the turn and carves that way (the
##   planing force tilts with the bottom, and its sideways part acts ahead of the centre of
##   mass; the fin's answer to the sideslip turns the bow the same way).
## - The legs (PH35, the push slider): in the straps the back foot pushes the sideways hold to
##   leeward against its strap (the tail to leeward, the bow to windward: heading up), or the
##   front foot does (bearing away). It needs no tack sign: the hold is to leeward on either
##   tack. legs_share is how much of the helm the legs carry, legs_bias a push held on top of
##   the steering (the slider loading the fin), both clamped to the straps' bound of 1.
## turn_right runs from -1 (full left) to +1 (full right). Only the rake needs the tack:
## a right turn is heading up on starboard tack and bearing away on port tack.


## tilt_share: how much of the rig tilt to use. The tilt steers through the sail's forward
## push; close to the wind, with the sail luffing, backed or stalled, that push is small or
## backwards and the drag of a tilted rig turns the bow the wrong way, so the rig is kept
## upright there (tilt_share 0).
static func steer(controls: SimControls, turn_right: float, tack_sign: float, lean_share: float, dt: float, rate_per_s: float, tilt_share: float = 1.0, legs_share: float = 0.0, legs_bias: float = 0.0) -> void:
	var helm: float = clampf(turn_right, -1.0, 1.0)
	controls.rake = move_toward(controls.rake, helm * tack_sign, rate_per_s * dt)
	controls.rig_tilt = move_toward(controls.rig_tilt, -helm * tilt_share, rate_per_s * dt)
	controls.lean = move_toward(controls.lean, helm * lean_share, rate_per_s * dt)
	# Heading up is a right turn on starboard tack: the back foot pushes with helm * tack_sign.
	controls.back_foot_push = move_toward(controls.back_foot_push, clampf(helm * tack_sign * legs_share + legs_bias, -1.0, 1.0), rate_per_s * dt)


## The course hold of a sailor hooked in (Autopilot.trim_with_rake_first). head_up is the
## whole helm toward the wind (positive heads up, on either tack), from -2 to 2; correction
## is its quick part (the error and the yaw rate). The rake carries the helm up to its stop
## and the rig's sideways tilt only the rest, plus the correction: the rig's windward lean
## stays the body's (the hike), as when a sailor hangs in the harness and steers with the
## rake. Steer() moves the rake and the tilt together instead, so a steady heading-up helm
## also stands the rig up toward leeward.
static func hold_rake_first(controls: SimControls, head_up: float, correction: float, tack_sign: float, lean_share: float, dt: float, rate_per_s: float, legs_share: float = 0.0, legs_bias: float = 0.0) -> void:
	var rake: float = clampf(head_up, -1.0, 1.0)
	var tilt: float = clampf(head_up - rake + correction, -1.0, 1.0)
	controls.rake = move_toward(controls.rake, rake, rate_per_s * dt)
	controls.rig_tilt = move_toward(controls.rig_tilt, -tilt * tack_sign, rate_per_s * dt)
	controls.lean = move_toward(controls.lean, clampf(head_up, -1.0, 1.0) * tack_sign * lean_share, rate_per_s * dt)
	# The legs head up on either tack: no tack sign.
	controls.back_foot_push = move_toward(controls.back_foot_push, clampf(clampf(head_up, -1.0, 1.0) * legs_share + legs_bias, -1.0, 1.0), rate_per_s * dt)


## True while the board is being pivoted through the wind rather than sailed: the sail
## backed, or the bow within pivot_deg of the wind.
static func pivoting(telemetry: Telemetry, controls: SimControls, pivot_deg: float) -> bool:
	return controls.hold_side != 0 or controls.boom_across > 0.0 or absf(telemetry.twa_deg) < pivot_deg
