class_name EliminationLadder
extends RefCounted
## One slalom elimination of 64 sailors: 16 heats of 8 (Max, 27 November 2026: "the whole slalom
## week with eliminations with 64 people in brackets"; Documentation/reports/broadcast/
## EVENT_WEEK_PLAN.md). Plain book-keeping: who is in which heat, who goes through, everyone's
## place at the end. No sailing here: a heat's finishing order is handed in (record()).
##
## The heats, in the order they are sailed:
## - 1 to 8: the first round. The 64 are spread by their seed in a snake (seeds 1 to 8 open heats
##   1 to 8, seeds 9 to 16 go into heats 8 back to 1, and so on), so every heat has a favourite
##   and a tail-ender.
## - 9 to 12: the quarter-finals (heats 1+2, 3+4, 5+6 and 7+8: the first four of each).
## - 13 and 14: the semi-finals (quarter-finals 9+10 and 11+12: the first four of each).
## - 15: the losers' final (places 9 to 16: the last four of each semi-final).
## - 16: the winners' final (places 1 to 8: the first four of each semi-final).
## The first THROUGH of a heat go through. Places 17 to 32 go to those knocked out in the
## quarter-finals and 33 to 64 to those knocked out in the first round: by their place in their
## heat, then by their seed.
##
## THE FORMAT IS THE LEAD'S READING OF THE SPORT, NOT YET CHECKED against the tour's rule book or
## the 2026 streams' commentary (step W0 of the plan): the snake, which heats feed which, and how
## the knocked-out are ranked are kept in this one file so they are easy to set right.

const SAILORS: int = 64
const HEAT_SIZE: int = 8
const THROUGH: int = 4
const HEATS: int = 16
const LOSERS_FINAL: int = 15
const WINNERS_FINAL: int = 16

## Each later heat's two feeding heats.
const FEEDS: Dictionary[int, Array] = {
	9: [1, 2], 10: [3, 4], 11: [5, 6], 12: [7, 8], 13: [9, 10], 14: [11, 12]}

## The sailors' ids by seed, the best first.
var seeds: PackedInt32Array = PackedInt32Array()
## heat number -> the ids in it, in start order (the better seed first); empty until it is known.
var _in_heat: Dictionary[int, PackedInt32Array] = {}
## heat number -> the ids in finishing order; missing until the heat is sailed.
var _result: Dictionary[int, PackedInt32Array] = {}


## A ladder for 64 ids in seed order (the favourite first).
static func for_seeds(ids_by_seed: PackedInt32Array) -> EliminationLadder:
	assert(ids_by_seed.size() == SAILORS, "an elimination takes %d sailors" % SAILORS)
	var ladder: EliminationLadder = EliminationLadder.new()
	ladder.seeds = ids_by_seed.duplicate()
	for heat: int in range(1, 9):
		ladder._in_heat[heat] = PackedInt32Array()
	for seed_index: int in SAILORS:
		var row: int = seed_index / 8
		var column: int = seed_index % 8
		var heat: int = (column if row % 2 == 0 else 7 - column) + 1
		ladder._in_heat[heat].append(ids_by_seed[seed_index])
	return ladder


## The heat to sail now (1 to 16), or 0 when the elimination is over.
func next_heat() -> int:
	for heat: int in range(1, HEATS + 1):
		if not _result.has(heat):
			return heat
	return 0


func is_over() -> bool:
	return next_heat() == 0


## The ids in a heat, in start order; empty while the heats that feed it are not sailed.
func sailors_in(heat: int) -> PackedInt32Array:
	return _in_heat.get(heat, PackedInt32Array())


## A heat's finishing order, or empty when it is not sailed yet.
func result_of(heat: int) -> PackedInt32Array:
	return _result.get(heat, PackedInt32Array())


## The ids that went through from a sailed heat (the finals have none).
func through_from(heat: int) -> PackedInt32Array:
	if heat >= LOSERS_FINAL or not _result.has(heat):
		return PackedInt32Array()
	return _result[heat].slice(0, THROUGH)


## What a heat is called.
static func heat_name(heat: int) -> String:
	if heat <= 8:
		return "First round, heat %d" % heat
	if heat <= 12:
		return "Quarter-final %d" % (heat - 8)
	if heat <= 14:
		return "Semi-final %d" % (heat - 12)
	return "Losers' final" if heat == LOSERS_FINAL else "Winners' final"


## A sailed heat's finishing order handed in: every id of the heat once, the first home first
## (a board that retired, fell out or never started comes last, in the order the race had them).
## Fills the heats it feeds. False (and nothing changes) when the order doesn't fit the heat.
func record(heat: int, order: PackedInt32Array) -> bool:
	if heat != next_heat():
		return false
	var expected: PackedInt32Array = sailors_in(heat)
	if order.size() != expected.size():
		return false
	for id: int in expected:
		if order.count(id) != 1:
			return false
	_result[heat] = order.duplicate()
	for later: int in FEEDS:
		var pair: Array = FEEDS[later]
		if _result.has(pair[0]) and _result.has(pair[1]) and not _in_heat.has(later):
			_in_heat[later] = _by_seed(_result[pair[0]].slice(0, THROUGH) + _result[pair[1]].slice(0, THROUGH))
	if _result.has(13) and _result.has(14) and not _in_heat.has(LOSERS_FINAL):
		_in_heat[LOSERS_FINAL] = _by_seed(_result[13].slice(THROUGH) + _result[14].slice(THROUGH))
		_in_heat[WINNERS_FINAL] = _by_seed(_result[13].slice(0, THROUGH) + _result[14].slice(0, THROUGH))
	return true


## Everyone's place when the elimination is over: the ids from 1st to 64th. Empty before that.
func places() -> PackedInt32Array:
	if not is_over():
		return PackedInt32Array()
	var out: PackedInt32Array = _result[WINNERS_FINAL] + _result[LOSERS_FINAL]
	out += _knocked_out([9, 10, 11, 12])
	out += _knocked_out([1, 2, 3, 4, 5, 6, 7, 8])
	return out


## The place of an id so far: its final place when its fate is known (knocked out, or the finals
## sailed), else 0.
func place_of(id: int) -> int:
	var done: PackedInt32Array = places()
	if not done.is_empty():
		return done.find(id) + 1
	return 0


## Those knocked out of these heats: by their place in their heat, then by their seed.
func _knocked_out(heats: Array) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for place: int in range(THROUGH, HEAT_SIZE):
		var same: PackedInt32Array = PackedInt32Array()
		for heat: int in heats:
			same.append(_result[heat][place])
		out += _by_seed(same)
	return out


func _by_seed(ids: PackedInt32Array) -> PackedInt32Array:
	var sorted: Array = Array(ids)
	sorted.sort_custom(func(a: int, b: int) -> bool: return seeds.find(a) < seeds.find(b))
	return PackedInt32Array(sorted)


func to_data() -> Dictionary:
	var heats: Dictionary = {}
	for heat: int in _in_heat:
		heats[str(heat)] = Array(_in_heat[heat])
	var results: Dictionary = {}
	for heat: int in _result:
		results[str(heat)] = Array(_result[heat])
	return {"seeds": Array(seeds), "heats": heats, "results": results}


static func from_data(data: Dictionary) -> EliminationLadder:
	var ladder: EliminationLadder = EliminationLadder.new()
	ladder.seeds = PackedInt32Array(data.get("seeds", []))
	if ladder.seeds.size() != SAILORS:
		return null
	for key: String in data.get("heats", {}):
		ladder._in_heat[key.to_int()] = PackedInt32Array(data["heats"][key])
	for key: String in data.get("results", {}):
		ladder._result[key.to_int()] = PackedInt32Array(data["results"][key])
	return ladder
