class_name WindDisturbance
extends RefCounted
## Something that disturbs the air at a point on top of the wind field's own wind (PHYSICS_SPEC.md
## section 8): a WindField multiplies the velocity it would give at a point by factor_at() when one
## is set (WindField.disturbance). The field itself knows nothing of what disturbs it; the race
## gives it the other sails' wind shadows (Game/race/wind_shadows.gd, AI_FLEET_PLAN.md D5). None
## set, nothing changes: the base class disturbs nothing.
##
## Boards stepped side by side on worker threads call this from their physics: an implementation
## must read only its own fields (a read of another object's field waits on the engine's lock,
## F1 no_wait), so whoever makes one gives each board's field its own copy.


## How much of the undisturbed wind is left at a point (1: all of it), given the undisturbed
## velocity there (the direction the air moves, m/s).
func factor_at(_point: Vector3, _undisturbed: Vector3) -> float:
	return 1.0
