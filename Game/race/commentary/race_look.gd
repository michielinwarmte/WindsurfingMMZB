class_name RaceLook
extends RefCounted
## What the commentator sees of the race at one moment: the race clock, the course's steps, and for
## every board its place, where it is on the course, how it sails (speed, planing, fallen, in the air)
## and what it looks like (its name, its sail's brand and colour). Plain numbers copied out of the race
## (RaceSim) and the boards' telemetry, so the race story (RaceStory) works the same in the game, in
## the headless race tool and in the tests, which make small looks by hand.

## One board as the commentator sees it.
class Board:
	## Its race number.
	var index: int = -1
	## On the water and in the race (false: a parked player's board, a guest not yet in).
	var present: bool = true
	## Its name for the slots ("" when it must not be said: the player's own board, "You").
	var name: String = ""
	## Its place, 1 the first.
	var place: int = 0
	## The step it is sailing to (RaceSim.next_step_index(): also the steps it has done).
	var next_step: int = 0
	## How far it is from that step, metres.
	var to_next_m: float = INF
	var finished: bool = false
	var finish_s: float = -1.0
	var retired: bool = false
	## Over the start line early.
	var ocs: bool = false
	## When its start counted (race seconds after the gun), -1 before.
	var start_s: float = -1.0
	## Game X, Z (metres), compass heading (degrees), speed (m/s).
	var position: Vector2 = Vector2.ZERO
	var heading_deg: float = 0.0
	var speed_ms: float = 0.0
	var planing: bool = false
	## The sailor is in the water after a fall.
	var fallen: bool = false
	## The side the sail is on (-1 or +1: it changes in a tack or a gybe), and the wind angle (degrees,
	## + from starboard): through about 180 in a gybe.
	var sail_side: int = -1
	var twa_deg: float = 0.0
	## The share of the board's whole weight the water carries now (buoyancy and planing lift): about 1
	## on the water, near 0 with the board in the air off a crest.
	var water_share: float = 1.0
	## The height of the water's surface under it (m; the waves), and the share of its wind the other
	## sails' shadows take now (0 clear air; the race's WindShadows).
	var water_height_m: float = 0.0
	var dirty_share: float = 0.0
	## Its sail's brand as the game names it ("" when it has none) and its sail's colour (TRANSPARENT:
	## not known).
	var brand: String = ""
	var colour: Color = Color.TRANSPARENT

	## Its velocity, game X, Z, metres a second.
	func velocity() -> Vector2:
		return Course.direction_of(heading_deg) * speed_ms


## The race clock, seconds: negative in the countdown, 0 at the gun.
var clock_s: float = 0.0
## The countdown has started (the race is on its way to the gun).
var started: bool = false
## Racing: from the gun until the race is over.
var racing: bool = false
## The race is over.
var over: bool = false
## The course's steps, as RaceSim.steps() has them: their kinds (RaceStep.Kind) and their points (a
## mark's position, or a line's or a gate's two ends).
var step_kinds: Array[RaceStep.Kind] = []
var step_points: Array[PackedVector2Array] = []
## Every board, by race number.
var boards: Array[Board] = []
## The race numbers in race order, the first first (only boards present).
var order: Array[int] = []
## The wind now: the fleet's mean true wind at 10 m (knots, gusts in it) and where it blows from
## (degrees).
var wind_kt: float = 0.0
var wind_from_deg: float = 0.0
## The day as the race story has measured it over the last while (RaceStory fills these in): the
## wind's mean (knots) and the sea's significant wave height (m; NAN until it is known).
var wind_mean_kt: float = NAN
var sea_hs_m: float = NAN


## How many steps the course has (the start and the finish included).
func step_count() -> int:
	return step_kinds.size()


## How many legs: from the start to the first mark is leg 1, into the finish the last.
func leg_count() -> int:
	return maxi(step_count() - 1, 0)


## The leg a board is on now, 1 the first (0 before its start, leg_count() + 1 once it has finished).
func leg_of(index: int) -> int:
	return boards[index].next_step


## True when a board's next step is a mark or a gate (not a line it starts or finishes on).
func next_is_a_mark(index: int) -> bool:
	var step: int = boards[index].next_step
	return step < step_count() and (step_kinds[step] == RaceStep.Kind.MARK or step_kinds[step] == RaceStep.Kind.GATE)


## Whether a board is on its last leg (sailing to the finish).
func on_last_leg(index: int) -> bool:
	return boards[index].next_step == step_count() - 1 and step_count() > 1


## The number of a step among the course's marks and gates (1 the first), and how many there are.
func mark_number(step: int) -> int:
	var number: int = 0
	for k: int in mini(step + 1, step_count()):
		if step_kinds[k] == RaceStep.Kind.MARK or step_kinds[k] == RaceStep.Kind.GATE:
			number += 1
	return number


func mark_count() -> int:
	return mark_number(step_count() - 1)


## How near a board is to a mark it rounds: to the mark, or to the nearer end of a gate, metres.
func distance_to_mark_m(index: int, step: int) -> float:
	if step >= step_count():
		return INF
	var points: PackedVector2Array = step_points[step]
	var nearest: float = INF
	for point: Vector2 in points:
		nearest = minf(nearest, boards[index].position.distance_to(point))
	return nearest


## The way the wind comes from, game X, Z, one metre long (to windward).
func upwind() -> Vector2:
	return Course.direction_of(wind_from_deg)


## How far a board is to windward of a point, metres (negative: to leeward).
func windward_of_m(index: int, point: Vector2) -> float:
	return (boards[index].position - point).dot(upwind())


## How far a board is to windward of its straight line to its next mark (from the step before it),
## metres (negative: below the line); 0 before its start and after its finish.
func line_offset_m(index: int) -> float:
	var step: int = boards[index].next_step
	if step < 1 or step >= step_count():
		return 0.0
	var from: Vector2 = _target(step - 1)
	var to: Vector2 = _target(step)
	var on_line: Vector2 = Geometry2D.get_closest_point_to_segment(boards[index].position, from, to)
	return (boards[index].position - on_line).dot(upwind())


## A step's mark, or the middle of its line.
func _target(step: int) -> Vector2:
	var points: PackedVector2Array = step_points[step]
	return points[0] if points.size() == 1 else (points[0] + points[1]) * 0.5


## The board's name, or "board <n>" for one with no name to say.
func name_of(index: int) -> String:
	if index < 0 or index >= boards.size():
		return "-"
	return boards[index].name if boards[index].name != "" else "board %d" % index


## A board is racing: present, started or waiting for the gun, not finished, not retired.
func is_racing(index: int) -> bool:
	var board: Board = boards[index]
	return board.present and not board.finished and not board.retired


## How many boards are in the race (present).
func fleet_size() -> int:
	return order.size()


## The board at a place (1 the first), or -1.
func at_place(place: int) -> int:
	return order[place - 1] if place >= 1 and place <= order.size() else -1


## How far the leader is ahead of the second on the water, metres (INF when there is no second, or it
## has not yet done as many steps: then the gap is a whole leg or more).
func lead_m() -> float:
	if order.size() < 2:
		return INF
	var first: Board = boards[order[0]]
	var second: Board = boards[order[1]]
	if first.finished or second.next_step < first.next_step:
		return INF
	return first.position.distance_to(second.position)


## The nearest other racing board to this one, metres (INF: none).
func nearest_other_m(index: int) -> float:
	var nearest: float = INF
	for other: int in order:
		if other != index and is_racing(other):
			nearest = minf(nearest, boards[index].position.distance_to(boards[other].position))
	return nearest


# ---------------------------------------------------------------- made from a race

## The look of a race: the race's own facts, and for each board its telemetry (null for a board that is
## not on the water), its name to say ("" to say none), its sail's brand and its sail's colour, and the
## share of its wind the other sails' shadows take (none given: clear air).
static func of_race(race: RaceSim, telemetry: Array[Telemetry], names: PackedStringArray, brands: PackedStringArray, colours: PackedColorArray,
		dirty: PackedFloat32Array = PackedFloat32Array()) -> RaceLook:
	var look: RaceLook = RaceLook.new()
	look.clock_s = race.clock_s()
	look.started = race.is_started()
	look.racing = race.phase() == RaceSim.Phase.RACING
	look.over = race.phase() == RaceSim.Phase.FINISHED
	for step: RaceStep in race.steps():
		look.step_kinds.append(step.kind)
		look.step_points.append(step.points)
	for i: int in race.board_count():
		var board: Board = Board.new()
		board.index = i
		var t: Telemetry = telemetry[i] if i < telemetry.size() else null
		board.present = t != null and not race.is_retired(i)
		board.name = names[i] if i < names.size() else race.board_name(i)
		board.next_step = race.next_step_index(i)
		board.to_next_m = race.distance_to_next_m(i)
		board.finished = race.is_finished(i)
		board.finish_s = race.finish_time_s(i)
		board.retired = race.is_retired(i)
		board.ocs = race.is_ocs(i)
		var splits: PackedFloat32Array = race.splits_s(i)
		board.start_s = splits[0] if not splits.is_empty() else -1.0
		board.brand = brands[i] if i < brands.size() else ""
		board.colour = colours[i] if i < colours.size() else Color.TRANSPARENT
		if t != null:
			board.position = Vector2(t.position.x, t.position.z)
			board.heading_deg = t.heading_deg
			board.speed_ms = t.speed_ms
			board.planing = t.is_planing
			board.fallen = t.sailor_state != 0
			board.sail_side = t.sail_side
			board.twa_deg = t.twa_deg
			board.water_share = water_share_of(t)
			board.water_height_m = t.water_height_m
			board.dirty_share = dirty[i] if i < dirty.size() else 0.0
		look.boards.append(board)
	for index: int in race.race_order():
		if look.boards[index].present:
			look.order.append(index)
	for place: int in look.order.size():
		look.boards[look.order[place]].place = place + 1
	# The wind: the fleet's mean at 10 m, and its direction from the first board on the water.
	var winds: float = 0.0
	for index: int in look.order:
		var t: Telemetry = telemetry[index]
		if winds == 0.0:
			look.wind_from_deg = t.wind_from_bearing_deg
		winds += t.tws_10m_kt
	look.wind_kt = winds / look.order.size() if not look.order.is_empty() else 0.0
	return look


## The share of the board's weight the water carries (its buoyancy and its planing lift over the whole
## windsurfer's weight; PlayerController's "light over a crest" reads the same two).
static func water_share_of(t: Telemetry) -> float:
	var weight_n: float = t.total_mass_kg * 9.81
	if weight_n <= 0.0:
		return 1.0
	return (t.buoyancy_n + t.planing_lift_n) / weight_n
