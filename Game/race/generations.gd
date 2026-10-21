class_name Generations
extends RefCounted
## The brains of one night's training run, by generation (AI_FLEET_PLAN.md, F5: Max's "see the
## generations made in a night race each other"). The trainer (tools/race_evolve.sh) writes
## Game/race/brains/<run>_gen<N>.json every 10 generations and <run>_best.json; this class reads
## those names: which generation a brain is ("gen 40", "best"), and the colour of its sail, a ramp
## from red (the oldest generation in the race) through orange and yellow to green (the newest),
## with the best brain white. Skippers.make_fleet() labels and colours the boards with it.

## The generation number given to a run's best brain, so it sorts after every real generation.
const BEST: int = 1_000_000
## The generation number of a brain whose name says none (night_test.json, ...).
const NONE: int = -1
## The best brain's sail.
const BEST_COLOUR: Color = Color(0.97, 0.97, 0.97)


## The generation of a brain from its file name (without .json): N for "<run>_gen<N>", BEST for
## "<run>_best", NONE for anything else.
static func generation_of(brain_name: String) -> int:
	if brain_name.ends_with("_best"):
		return BEST
	var at: int = brain_name.rfind("_gen")
	if at <= 0:
		return NONE
	var digits: String = brain_name.substr(at + 4)
	if digits.is_empty() or not digits.is_valid_int() or digits.to_int() < 0:
		return NONE
	return digits.to_int()


## The training run a brain belongs to: "night2b" for "night2b_gen40" and "night2b_best"; "" when
## the name says no generation.
static func run_of(brain_name: String) -> String:
	if generation_of(brain_name) == NONE:
		return ""
	return brain_name.substr(0, brain_name.rfind("_"))


## The short name of a brain on the water and in the lists: "gen 40", "best"; "" when the name
## says no generation (the brain keeps its file name then).
static func label_of(brain_name: String) -> String:
	var generation: int = generation_of(brain_name)
	if generation == BEST:
		return "best"
	if generation == NONE:
		return ""
	return "gen %d" % generation


## The sail of a generation in a race whose generations go from `oldest` to `newest`: red for the
## oldest, through orange and yellow, to green for the newest (the hue from 0 to a third of the
## circle); white for the best brain.
static func ramp_colour(generation: int, oldest: int, newest: int) -> Color:
	if generation == BEST:
		return BEST_COLOUR
	var share: float = 0.0
	if newest > oldest:
		share = clampf(float(generation - oldest) / float(newest - oldest), 0.0, 1.0)
	return Color.from_hsv(share / 3.0, 0.85, 0.95)


## Colours the sails of a fleet's learned skippers by their generation (ramp_colour), the ramp from
## the generations in this fleet. Only when there are two or more brains with a generation: a single
## brain against the characters keeps its purple sail.
static func colour_fleet(fleet: Array[RaceSkipper]) -> void:
	var learned: Array[LearnedSkipper] = []
	var oldest: int = BEST
	var newest: int = NONE
	for skipper: RaceSkipper in fleet:
		var brain_skipper: LearnedSkipper = skipper as LearnedSkipper
		if brain_skipper == null or generation_of(brain_skipper.brain_name) == NONE:
			continue
		learned.append(brain_skipper)
		var generation: int = generation_of(brain_skipper.brain_name)
		if generation != BEST:
			oldest = mini(oldest, generation)
			newest = maxi(newest, generation)
	if learned.size() < 2:
		return
	for brain_skipper: LearnedSkipper in learned:
		brain_skipper.sail = ramp_colour(generation_of(brain_skipper.brain_name), oldest, newest)
