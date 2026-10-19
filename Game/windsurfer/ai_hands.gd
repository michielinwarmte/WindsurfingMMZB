class_name AiHands
extends RefCounted
## The hands of an AI skipper on the controls, in place of the keyboard (RACING_PLAN.md,
## decision RD1): the same beginner controller the player uses, fed values instead of keys,
## so a skipper can do nothing a player could not. Set PlayerController.hands to one of
## these and the controller stops reading the keyboard.
##
## steer and sheet are a stick, not a key: they run from -1 to 1, and the beginner's turn
## loop takes the fraction as its turn rate (a half-pressed stick is a gentle turn).

## +1 turns right on the screen, -1 left, on either tack (the controller sorts out the rake).
var steer: float = 0.0
## +1 sheets in, -1 eases. With the auto-sheet on this overrides it for a few seconds, as the
## player's W and S keys do.
var sheet: float = 0.0
## A tack or gybe asked for (the player's Space). The controller takes it on its next update
## and clears it, so one request is one manoeuvre.
var tack: bool = false


## What the controller reads for a key pair: the stick value for the pairs a skipper has, 0
## for the ones it does not (the advanced mode's rake and tilt keys, which an AI never uses).
func axis(positive: String) -> float:
	match positive:
		"steer_right":
			return clampf(steer, -1.0, 1.0)
		"sheet_in":
			return clampf(sheet, -1.0, 1.0)
	return 0.0


## True once per request: the controller calls this where it would check a key press.
func take_press(action: String) -> bool:
	if action == "tack" and tack:
		tack = false
		return true
	return false
