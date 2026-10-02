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
## turn_right runs from -1 (full left) to +1 (full right). Only the rake needs the tack:
## a right turn is heading up on starboard tack and bearing away on port tack.


static func steer(controls: SimControls, turn_right: float, tack_sign: float, lean_share: float, dt: float, rate_per_s: float) -> void:
	var helm: float = clampf(turn_right, -1.0, 1.0)
	controls.rake = move_toward(controls.rake, helm * tack_sign, rate_per_s * dt)
	controls.rig_tilt = move_toward(controls.rig_tilt, -helm, rate_per_s * dt)
	controls.lean = move_toward(controls.lean, helm * lean_share, rate_per_s * dt)
