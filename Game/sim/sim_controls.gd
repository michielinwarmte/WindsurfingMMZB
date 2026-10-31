class_name SimControls
extends RefCounted
## What the sailor does, as the simulation sees it. The controller (Phase 3) turns key
## presses into these numbers; the autopilot (Phase 4) sets them from a course.

## Sheet: 0 = boom fully out (85 degrees from the centreline), 1 = fully in (12 degrees).
var sheet: float = 0.5
## Mast rake: -1 = fully forward (bear away), +1 = fully back (head up).
var rake: float = 0.0
## Where the sailor puts their weight sideways on top of the balance reflex:
## -1 = out to port, +1 = out to starboard. Advanced mode only; 0 in beginner mode.
var lean: float = 0.0
## Sideways tilt of the rig with the arms, on top of where it hangs with the sailor's lean:
## -1 = mast top toward port, +1 = toward starboard. Tilting the rig moves the sail's push
## off the centreline, which turns the board; it is the lever that still works dead downwind.
var rig_tilt: float = 0.0
## The boom pushed across the centreline toward the windward side, beyond fully sheeted:
## 0 = not at all, 1 = as far as the arms reach (35 degrees past the centreline). This is
## how a sailor backs the sail to get the bow through the wind in a tack.
var boom_across: float = 0.0
## Which side the sailor holds the rig on: 0 = the wind decides (the sail blows over when
## the wind is clearly across), +1 / -1 = held on that side. Set through a tack: the backed
## sail stays on the old side until the sailor flips the rig.
var hold_side: int = 0
## The sailor stepping round the front of the mast, 0 to 1 (a tack). With the weight that
## far forward the tail and the fin lift and the board pivots on its nose.
var step_forward: float = 0.0
## The sailor's balance reflex: lean against the heel and the sail's heeling moment.
## Part of the sailor model, on by default (PHYSICS_SPEC.md section 15).
var balance_reflex: bool = true
## The back foot against the fin (PH35, the push slider): which foot carries the sideways hold
## against the sail's pull into the hull, once the feet are in the straps. 0 = the feet's
## pressure point between the straps, as before; +1 = the back foot pushes it all to leeward
## against its strap (the tail goes to leeward, the bow to windward, the fin carries more of the
## side force); -1 = the front foot does. The sailor's weight does not move with it.
var back_foot_push: float = 0.0
## The technique's own targets, moved by the rider (PH3, the push slider): degrees added to the
## bank the feet aim for while planing in the straps (the leeward rail down is positive), to the
## trim the feet press for, and to the rig's lean toward the sailor at full hike. 0 = the
## technique as in SailorConfig, bit for bit.
var rail_bank_extra_deg: float = 0.0
var trim_aim_extra_deg: float = 0.0
var rig_lean_extra_deg: float = 0.0


func duplicate_controls() -> SimControls:
	var copy: SimControls = SimControls.new()
	copy.sheet = sheet
	copy.rake = rake
	copy.lean = lean
	copy.rig_tilt = rig_tilt
	copy.boom_across = boom_across
	copy.hold_side = hold_side
	copy.step_forward = step_forward
	copy.balance_reflex = balance_reflex
	copy.back_foot_push = back_foot_push
	copy.rail_bank_extra_deg = rail_bank_extra_deg
	copy.trim_aim_extra_deg = trim_aim_extra_deg
	copy.rig_lean_extra_deg = rig_lean_extra_deg
	return copy
## Testing aid: when true the sailor stops moving fore and aft (stance and hang-back hold
## still) while still balancing sideways, so a scenario can show whether the board's pitch
## is steady on its own.
var freeze_fore_aft: bool = false
