class_name RaceSkipper
extends RefCounted
## What every skipper has in common, scripted (Skipper) or learned (LearnedSkipper), so the race
## tool, the tests and later the game can hold either without knowing which (RACING_PLAN.md, RD2).
## A skipper sits above the beginner PlayerController with its AiHands on the controls: setup()
## puts it on a board, update() runs every tick before the controller's own update and sets the
## hands. It never touches the physics (RD1).

## The seed of whatever randomness the skipper has (a scripted one's wander and reaction), so a
## race can be repeated.
var random_seed: int = 0
## A few words on what the skipper is doing right now, for the HUD and the race tool's CSV.
var note: String = ""
## Where it sails when it is not racing (AI_FLEET_PLAN.md, D4): given by whoever sets up the race
## (RaceRunner, the race tool) before setup(); null lets a skipper make its own round the course's
## start line, without a shore.
var sailing_area: SailingArea = null
## The racing rules' judge of the race it sails in (RaceRules, F3), given by whoever sets up the
## race; null: no rules (a scripted skipper then bears away from any board close by, as before).
var rules: RaceRules = null


## The board's own name in a fleet where a character sails more than once ("Rookie 2", set by
## Skippers.make_fleet()); empty for skipper_name().
var label: String = ""


## The name shown on the results and the labels.
func skipper_name() -> String:
	return "skipper"


## The name of this board in the race: its label, or the skipper's name.
func board_name() -> String:
	return label if not label.is_empty() else skipper_name()


## The sail's colour in the game, so the boards tell apart.
func sail_colour() -> Color:
	return Color(0.75, 0.75, 0.8)


## Puts the skipper on a board: its simulation, its controller (which gets these hands), the race
## and the board's number in it.
func setup(_sim: WindsurferSim, _controller: PlayerController, _hands: AiHands, _race: RaceSim, _index: int) -> void:
	pass


## One tick, before controller.update(): sets hands.steer, hands.sheet and hands.tack.
func update(_telemetry: Telemetry, _dt: float) -> void:
	pass


## The other boards (game X, Z, and m/s in X, Z), any order, without this one. A scripted
## skipper reads the race for them instead; a learned one looks at the nearest two.
func set_others(_positions: PackedVector2Array, _velocities: PackedVector2Array) -> void:
	pass
