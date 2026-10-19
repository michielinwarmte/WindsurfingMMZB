class_name Skipper
extends RefCounted
## The scripted skipper (RACING_PLAN.md, "The scripted skipper (9B)"): the course layer above the
## beginner PlayerController and its auto-sheet Autopilot. It decides where to go next and moves
## the same stick the player has (AiHands): steer, sheet, and Space for a tack or gybe. It never
## writes to SimControls and never touches the physics (decision RD1); what makes one skipper
## weaker than another is its character sheet (SkipperConfig, decision RD7).
##
## Every tick, before controller.update(), update() looks at the race and the board and sets the
## hands. Its rules, in the plan's order:
##   1. The target point of the next step: a mark offset by the mark margin on its side, a gate's
##      nearer mark offset inward, the character's spot on the start line, the finish's middle.
##   2. Straight there, when the wind angle that needs lies between the polar's upwind angle (plus
##      the pointing offset) and its downwind angle.
##   3. Upwind: the polar's angle on the present tack until the layline to the target plus the
##      layline margin, then a tack; earlier on a big header (shift sensitivity), a few times per
##      beat at most (max_tacks_per_beat).
##   4. Downwind: the same with the polar's downwind angle and gybes.
##   5. The start: a timed run (see _start_heading()).
##   6. Keep clear: another board within KEEP_CLEAR_M and closing makes it bear away a little.
##   7. Gust hunting: a hook only (_gust_lean_deg()), for the lake's wind field.
##   8. Reaction and noise: the wanted heading reaches the stick reaction_time_s late, plus a slow
##      random wander of steering_noise_deg; the tack requests wait the reaction time too.
## A wanted heading becomes the stick by a proportional rule with a dead band: inside the band the
## stick is let go and the controller's own heading hold does the steady part.
##
## Directions are compass bearings (0 north, 90 east, clockwise) and wind angles are positive with
## the wind from starboard (D4). Positions are game metres, Vector2(X east, Z south), as in Course.

enum StartPhase {
	## Sailing to a point just behind the chosen spot on the line.
	TO_LINE,
	## Time to spare: sailing away from the line on a broad reach.
	AWAY,
	## The tack or gybe that turns it back toward the line.
	TURNING,
	## Heading for the spot to cross at the gun; luffing up if it is still early.
	RUN_IN,
	## Over the line at the gun (OCS): back behind it before starting again.
	BACK_BEHIND,
}

## A line is aimed at this far beyond it, metres (see _target_point()).
const THROUGH_LINE_M: float = 30.0
## A mark that can be gone round without a tack or gybe from one tack only is approached on that
## tack: on it, the skipper sails this much further past the other tack's layline before tacking,
## metres, so that on the other tack it meets its own layline this far below the mark, with room
## to tack and get going again (a tack stops the board, and it needs some 40 m to get going).
const APPROACH_ROOM_M: float = 40.0
## Rule 6: another board this close, metres, and getting closer, makes it bear away this much.
const KEEP_CLEAR_M: float = 15.0
const KEEP_CLEAR_BEAR_AWAY_DEG: float = 15.0
## Keeping clear never takes it deeper than this wind angle: past 150 degrees the board stops
## planing (POLAR_15KT.md).
const KEEP_CLEAR_DEEPEST_TWA_DEG: float = 145.0
## Steering: inside the dead band the stick is let go and the controller holds the heading; beyond
## it the stick moves in proportion to the error, fully at FULL_STICK_ERROR_DEG (30 degrees of
## error asks for the controller's full turn rate, 30 degrees per second).
const STEER_DEAD_BAND_DEG: float = 2.0
const FULL_STICK_ERROR_DEG: float = 30.0
## The steering noise wanders on about this time scale, seconds: a slow wobble, not a shake.
const NOISE_TIME_S: float = 4.0
## A tack or gybe asked for this soon after the last one ended is not asked for: the board needs
## time to get going again.
const MIN_TACK_INTERVAL_S: float = 8.0
## The leeway and the speed it expects are smoothed over this long, seconds.
const MEASURE_SMOOTH_S: float = 3.0
## Its memory of the mean wind direction, for the wind shifts, seconds.
const WIND_MEMORY_S: float = 90.0
## The start (rule 5). The run in to the spot on the line is a close reach at this wind angle when
## the first leg is a beat, or the first leg's own course. Not wider: on a line square to the wind
## a board on a close reach sails further along the line than toward it (1.4 m per metre at 50
## degrees and its leeway, 2.2 m at 60), and the line is only 60 m long.
const START_RUN_IN_TWA_DEG: float = 50.0
## It waits on the run-in line this far behind the start line, metres, before deciding what to do
## with the time left; close enough to that point is within START_HOLD_REACHED_M. Nearer the line
## than the two together, it runs in.
const START_HOLD_BEHIND_M: float = 20.0
const START_HOLD_REACHED_M: float = 15.0
## What a tack or gybe costs, seconds: the turn and getting going again (a tack stops the board).
const START_TURN_S: float = 6.5
## With more time than this to spare at the line it sails away and comes back (two gybes and the
## legs between them); with less it loses the time by crossing further along the line.
const START_LOOP_SPARE_S: float = 2.0 * START_TURN_S + 6.0
## It is on time when it has less than this to spare, seconds.
const START_GO_SPARE_S: float = 1.0
## Near the line it looks at this many points of the line to choose where to cross.
const START_CROSSING_SAMPLES: int = 21
## Crossing further along the line to lose time moves the board along it; the waiting point leaves
## this much room for that, metres.
const START_DRIFT_ROOM_M: float = 15.0
## A leg of a beat or a run shorter than this needs no tack or gybe of its own, metres: the board
## lays its point.
const LAID_WITHIN_M: float = 10.0
## Over the line early: the point it goes back to is this far behind the spot, metres.
const START_BACK_BEHIND_M: float = 15.0
## A board getting up to speed gains about this much a second (m/s2): the time it expects to need
## includes the speed it still has to gain.
const ACCELERATION_MS2: float = 1.0
## The polar at 15 kt (Documentation/POLAR_15KT.md): the settled speed at each true wind angle
## (180 degrees is not in the table; it is taken as 165's). The skipper measures how fast it goes
## compared with this (the wind today is not 15 kt) and uses the ratio to say how long a stretch
## will take.
const POLAR_TWA_DEG: PackedFloat32Array = [30.0, 40.0, 45.0, 60.0, 75.0, 90.0, 105.0, 120.0, 135.0, 150.0, 165.0, 180.0]
const POLAR_SPEED_MS: PackedFloat32Array = [0.99, 5.74, 6.54, 8.38, 9.86, 11.07, 12.03, 11.92, 10.20, 5.61, 4.60, 4.60]

## The character sheet.
var config: SkipperConfig = SkipperConfig.new()
## The seed of its steering noise: the same seed, the same race.
var random_seed: int = 0
## What it is doing, a word or two for the tools' CSV ("beat", "run", "start: away", ...).
var note: String = ""
## Before its start: the seconds it has to spare (the time until it wants to cross, less the time
## it expects to need to get to its spot), for the tools.
var start_spare_s: float = 0.0
## The tacks and gybes it asked for, counted as the controller starts them.
var tacks: int = 0
var gybes: int = 0
## The tacks and gybes made while sailing to each step of the course, by the step's number.
var manoeuvres_by_step: PackedInt32Array = PackedInt32Array()

var _sim: WindsurferSim
var _controller: PlayerController
var _hands: AiHands
var _race: RaceSim
var _index: int = 0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _time_s: float = 0.0

## The step it is sailing to, and what it decided about that step.
var _step_seen: int = -1
var _level_with_mark: bool = false
var _gate_end: int = -1
var _start_phase: StartPhase = StartPhase.TO_LINE
## The tack it runs in to the start line on, chosen at the first look (_start_run_in_tack()).
var _run_in_tack: float = 0.0
## True once it has reached its waiting point behind the start line (it runs in from there).
var _reached_hold: bool = false
## When it decided to turn back toward the line (the start's TURNING phase).
var _turn_back_from_s: float = 0.0

## Rule 8: the wanted headings of the last reaction time, oldest first, with their times.
var _delay_headings: PackedFloat32Array = PackedFloat32Array()
var _delay_times: PackedFloat32Array = PackedFloat32Array()
var _noise_deg: float = 0.0
## A tack or gybe decided and waiting for the reaction time; the time it is due, -1 for none.
var _tack_due_s: float = -1.0
var _last_wanted_deg: float = 0.0

## The controller's manoeuvre at the last tick, to count manoeuvres and see them end.
var _last_manoeuvre: PlayerController.Manoeuvre = PlayerController.Manoeuvre.NONE
var _manoeuvre_ended_s: float = -INF
var _settling: bool = false
## Pointing: a board without speed is sailed no closer than the autopilot's bear-away angle, as the
## autopilot does (Autopilot.pointing_speed_ms).
var _pointing: bool = false

## What it has measured: its leeway (degrees), its speed against the polar's, the mean wind.
var _leeway_deg: float = 5.0
var _speed_ratio: float = 1.0
var _wind_memory_deg: float = 0.0
var _last_position: Vector2 = Vector2.ZERO
var _velocity: Vector2 = Vector2.ZERO
## The length of the last tick, seconds, for the other boards' velocities.
var _tick_s: float = 1.0 / 60.0
## The other boards' positions at the last tick, to see whether they are getting closer.
var _others_last: PackedVector2Array = PackedVector2Array()


## Puts the skipper on a board: its simulation (to see whether the sailor is up), its controller
## and the hands on it, and the race with the board's number in it.
func setup(sim: WindsurferSim, controller: PlayerController, hands: AiHands, race: RaceSim, index: int) -> void:
	_sim = sim
	_controller = controller
	_hands = hands
	_race = race
	_index = index
	_controller.hands = hands
	_rng.seed = random_seed
	_time_s = 0.0
	_wind_memory_deg = sim.telemetry.wind_from_bearing_deg
	_last_position = _position(sim.telemetry)
	_last_wanted_deg = sim.telemetry.heading_deg
	manoeuvres_by_step.resize(race.steps().size() + 1)
	manoeuvres_by_step.fill(0)
	_others_last.resize(race.board_count())
	for j: int in race.board_count():
		_others_last[j] = race.board_position(j)


## One tick, before controller.update(): sets hands.steer, hands.sheet and hands.tack.
func update(telemetry: Telemetry, dt: float) -> void:
	_time_s += dt
	_watch_manoeuvres(telemetry)
	_measure(telemetry, dt)
	# The sheet is the auto-sheet's: the skipper never moves the sheet stick.
	_hands.sheet = 0.0
	if _sim.sailor_state != WindsurferSim.SailorState.SAILING:
		# In the water: hands off, and nothing decided keeps waiting.
		_hands.steer = 0.0
		_hands.tack = false
		_tack_due_s = -1.0
		_settling = false
		note = "in the water"
		_remember_others()
		return
	_new_step_check()
	var decided_deg: float = _decide(telemetry)
	_last_wanted_deg = decided_deg
	var wanted_deg: float = _after_reaction(decided_deg) + _wander(dt) + _gust_lean_deg()
	_steer_toward(telemetry, wanted_deg)
	_ask_when_due()
	_remember_others()


## The tacks and gybes made on the way to a step (the start is step 0, mark 1 step 1, ...).
func manoeuvres_on_step(step: int) -> int:
	return manoeuvres_by_step[step] if step < manoeuvres_by_step.size() else 0


# ---------------------------------------------------------------- deciding

## The heading it wants now, before its reaction time and its noise.
func _decide(telemetry: Telemetry) -> float:
	var step: RaceStep = _race.next_step(_index)
	if step == null:
		note = "finished"
		return _last_wanted_deg
	if step.kind == RaceStep.Kind.START:
		var start_deg: float = _start_heading(telemetry, step)
		note += " (%+.1f s to spare; ratio %.2f leeway %.1f)" % [start_spare_s, _speed_ratio, _leeway_deg]
		return start_deg
	return _course_to(telemetry, _target_point(step, _position(telemetry)), step)


## Rule 1: the point it sails for to do a step. A line (the start, a gate, the finish) is aimed at
## THROUGH_LINE_M beyond the point on it, straight on from the board (_through()), so the board
## sails through the line instead of arriving at a point on it, where the bearing to the point
## swings round.
func _target_point(step: RaceStep, position: Vector2) -> Vector2:
	match step.kind:
		RaceStep.Kind.MARK:
			return _mark_target(step, position)
		RaceStep.Kind.GATE:
			return _through(position, _gate_target(step, position))
		RaceStep.Kind.START:
			return _through(position, _start_spot(step))
	return _through(position, step.target())


## A mark is rounded by crossing its rounding ray (RoundingCheck) going round it the right way.
## Until the board is level with the mark along the leg in, it aims for the entry point: abeam of
## the mark, mark_margin_m out on the side the mark is left on. From then on it aims for a point
## past the ray, so that it crosses the ray going round the right way about mark_margin_m from the
## mark. The race says when the rounding counted; then the next step's target takes over.
func _mark_target(step: RaceStep, position: Vector2) -> Vector2:
	var mark: Vector2 = step.points[0]
	var margin: float = config.mark_margin_m
	var way: float = RoundingCheck.turn_way(step.side)
	if not _level_with_mark:
		_level_with_mark = (position - mark).dot(step.in_dir) >= 0.0
	if not _level_with_mark:
		# Leaving a mark to port the board passes on its right: the leg's direction turned a
		# quarter clockwise, which is -orthogonal() in these axes; to starboard, on its left.
		return mark + step.in_dir.orthogonal() * way * margin
	var ray: Vector2 = RoundingCheck.rounding_ray(step.in_dir, step.out_dir, step.side)
	# Vector2.rotated() turns clockwise on the map in these axes (X east, Z south), so way * 90
	# degrees is the direction the board moves when it crosses the ray going the right way round.
	return mark + ray * 2.0 * margin + ray.rotated(way * PI / 2.0) * margin


## A gate is a line between two marks: it aims mark_margin_m inside the nearer mark, chosen when
## the leg begins and changed only if the other one becomes much nearer.
func _gate_target(step: RaceStep, position: Vector2) -> Vector2:
	var to_a: float = position.distance_to(step.points[0])
	var to_b: float = position.distance_to(step.points[1])
	if _gate_end < 0:
		_gate_end = 0 if to_a <= to_b else 1
	elif _gate_end == 0 and to_b < 0.7 * to_a:
		_gate_end = 1
	elif _gate_end == 1 and to_a < 0.7 * to_b:
		_gate_end = 0
	var near: Vector2 = step.points[_gate_end]
	var far: Vector2 = step.points[1 - _gate_end]
	return near + (far - near).normalized() * config.mark_margin_m


## The character's spot on the start line: 0 the pin, 1 the boat, kept a few metres in from the
## ends so it does not aim at a mark.
func _start_spot(step: RaceStep) -> Vector2:
	var inset: float = _line_inset(step)
	return step.points[1].lerp(step.points[0], clampf(config.start_spot, inset, 1.0 - inset))


## Rules 2, 3 and 4: the heading toward a target point. Straight there if the wind allows; upwind
## of the polar's angle a beat with tacks on the laylines; downwind of it a run with gybes. The
## wanted heading always stays on the present tack: changing tack is a manoeuvre, asked for
## through the hands, never steered through the wind with the stick. When the target belongs to a
## mark (step), the beat or run is planned to arrive on the tack the mark is rounded from; a
## non-zero arrive_tack asks for that tack instead (the start's run in).
func _course_to(telemetry: Telemetry, target: Vector2, step: RaceStep = null, arrive_tack: float = 0.0) -> float:
	var position: Vector2 = _position(telemetry)
	var wind_deg: float = telemetry.wind_from_bearing_deg
	var tack: float = _tack()
	var up_deg: float = _upwind_twa_deg()
	var down_deg: float = config.downwind_vmg_twa_deg
	# The track over the ground runs the leeway further off the wind than the bow points.
	var up_track_deg: float = config.upwind_vmg_twa_deg + config.pointing_offset_deg + _leeway_deg
	var down_track_deg: float = down_deg + _leeway_deg
	var bearing_deg: float = Course.bearing_deg(position, target)
	# The wind angle of the track straight there, positive with the wind from starboard.
	var needed_deg: float = wrapf(wind_deg - bearing_deg, -180.0, 180.0)
	var needed_side: float = 1.0 if needed_deg >= 0.0 else -1.0
	var heading_deg: float
	if absf(needed_deg) < up_track_deg:
		note = "beat"
		heading_deg = wind_deg - tack * up_deg
		var margin_m: float = _layline_margin_m(step, arrive_tack, wind_deg, up_deg, tack)
		if _past_layline_m(position, target, wind_deg, tack, up_track_deg) >= margin_m:
			_ask_for_manoeuvre(true)
		elif _headed_deg(wind_deg, tack) > config.shift_sensitivity_deg and _manoeuvres_here() < config.max_tacks_per_beat - 1:
			# Rule 3's shift: headed on this tack is lifted on the other.
			_ask_for_manoeuvre(false)
	elif absf(needed_deg) > down_track_deg:
		note = "run"
		heading_deg = wind_deg - tack * down_deg
		var margin_m: float = _layline_margin_m(step, arrive_tack, wind_deg, down_deg, tack)
		if _past_layline_m(position, target, wind_deg, tack, down_track_deg) >= margin_m:
			_ask_for_manoeuvre(true)
	elif needed_side == tack:
		note = "reach"
		# Aimed up by the leeway, so the track goes to the target; but without speed no closer to the
		# wind than the upwind angle allows (the bear-away angle until the fin grips).
		heading_deg = wind_deg - tack * maxf(absf(needed_deg) - _leeway_deg, up_deg)
	else:
		# The target is a reach on the other tack: the board is past the other tack's layline (or,
		# downwind, its gybing line). It tacks or gybes once it is past by the margin, as on a beat or
		# a run; until then it sails on at the beat's or the run's angle.
		note = "reach, other tack"
		var upwind: bool = absf(needed_deg) < 90.0
		heading_deg = wind_deg - tack * (up_deg if upwind else down_deg)
		var sail_deg: float = up_deg if upwind else down_deg
		var margin_m: float = _layline_margin_m(step, arrive_tack, wind_deg, sail_deg, tack)
		var past_m: float = _past_layline_m(position, target, wind_deg, tack, up_track_deg if upwind else down_track_deg)
		if past_m >= margin_m:
			_ask_for_manoeuvre(true)
	return heading_deg + _keep_clear_deg(telemetry, tack)


## How far past the other tack's layline to a target the board is, metres: negative before it. The
## layline is the line the board would sail to the target on the other tack, track_twa_deg off the
## wind; "past" is the way the present tack carries it. When the target is not ahead on the other
## tack at all, -INF.
func _past_layline_m(position: Vector2, target: Vector2, wind_deg: float, tack: float, track_twa_deg: float) -> float:
	# On starboard tack (tack +1) the bow is track_twa_deg to the left of the wind; on port to the right.
	var other: Vector2 = Course.direction_of(wind_deg + tack * track_twa_deg)
	var this: Vector2 = Course.direction_of(wind_deg - tack * track_twa_deg)
	if (target - position).dot(other) <= 0.0:
		return -INF
	var across: Vector2 = other.orthogonal()
	if across.dot(this) < 0.0:
		across = -across
	return (position - target).dot(across)


## How far past the other tack's layline it sails before tacking or gybing, metres: the
## character's margin, and on the tack it must arrive on (arrive_tack, or the tack a mark must be
## approached on), APPROACH_ROOM_M more.
func _layline_margin_m(step: RaceStep, arrive_tack: float, wind_deg: float, sail_twa_deg: float, tack: float) -> float:
	var wanted_tack: float = arrive_tack
	if wanted_tack == 0.0 and step != null:
		wanted_tack = _approach_tack(step, wind_deg, sail_twa_deg)
	if wanted_tack == tack:
		return config.layline_margin_m + APPROACH_ROOM_M
	return config.layline_margin_m


## The tack a mark must be approached on, beating or running at sail_twa_deg, so that going round
## it needs no tack or gybe: from the heading on that tack, turning the way the mark is rounded, the
## bow reaches the leg out before it swings through the wind or past dead downwind. A port-rounded
## windward mark, for one, is approached on starboard tack: on port tack the turn round it is a
## tack. 0 when either tack will do, and for the lines.
static func _approach_tack(step: RaceStep, wind_deg: float, sail_twa_deg: float) -> float:
	if step.kind != RaceStep.Kind.MARK:
		return 0.0
	var way: float = RoundingCheck.turn_way(step.side)
	var out_deg: float = Course.bearing_deg(Vector2.ZERO, step.out_dir)
	var good: Array[float] = []
	for tack: float in [1.0, -1.0]:
		var heading_deg: float = wind_deg - tack * sail_twa_deg
		var to_out: float = _turn_way_deg(heading_deg, out_deg, way)
		var to_wind: float = _turn_way_deg(heading_deg, wind_deg, way)
		# A leg out straight downwind is reached at dead downwind, not swung past it.
		var to_downwind: float = _turn_way_deg(heading_deg, wind_deg + 180.0, way) + 1.0
		if to_wind > to_out and to_downwind > to_out:
			good.append(tack)
	return good[0] if good.size() == 1 else 0.0


## How far the bow swings from one bearing to another turning one way (1 clockwise, -1
## anticlockwise), 0 to 360 degrees.
static func _turn_way_deg(from_deg: float, to_deg: float, way: float) -> float:
	return fposmod((to_deg - from_deg) * way, 360.0)


## How much the wind has headed the board on its present tack against its memory of the mean
## wind, degrees: positive is a header (the wind further ahead, the mark further away), negative a
## lift. On starboard tack a wind that backs (turns anticlockwise) is a header.
func _headed_deg(wind_deg: float, tack: float) -> float:
	return -tack * wrapf(wind_deg - _wind_memory_deg, -180.0, 180.0)


## The wind angle it sails upwind: the polar's plus its pointing offset, or, while the board is too
## slow for the fin to grip, the autopilot's bear-away angle until it has speed (a sailor does not
## point high from a standstill).
func _upwind_twa_deg() -> float:
	var pointing_deg: float = config.upwind_vmg_twa_deg + config.pointing_offset_deg
	if _pointing:
		return pointing_deg
	return maxf(pointing_deg, _controller.auto_sheet_pilot.bear_away_twa_deg)


## Rule 6: another board close and getting closer makes it bear away a little (to pass to leeward
## of it), never deeper than KEEP_CLEAR_DEEPEST_TWA_DEG. The change of heading, degrees.
func _keep_clear_deg(telemetry: Telemetry, tack: float) -> float:
	var position: Vector2 = _position(telemetry)
	for j: int in _race.board_count():
		if j == _index:
			continue
		var other: Vector2 = _race.board_position(j)
		var apart: Vector2 = other - position
		if apart.length() > KEEP_CLEAR_M:
			continue
		var other_velocity: Vector2 = (other - _others_last[j]) / maxf(_tick_s, 1e-6)
		if apart.dot(other_velocity - _velocity) < 0.0:
			note += ", keeping clear"
			var room_deg: float = clampf(KEEP_CLEAR_DEEPEST_TWA_DEG - absf(telemetry.twa_deg), 0.0, KEEP_CLEAR_BEAR_AWAY_DEG)
			# Bearing away on starboard tack turns the bow to the left (the heading decreases).
			return -tack * room_deg
	return 0.0


## Rule 7, gust hunting, is not built yet: it needs the wind on the water around the board (the
## lake's WindField.velocity_at, with its moving gusts), and the headless race sails the open
## water's even wind. This is where it goes: sample the wind 100 to 200 m ahead on both tacks and
## lean the heading toward the windier side by config.gust_appetite. Until then no lean.
func _gust_lean_deg() -> float:
	return 0.0


# ---------------------------------------------------------------- the start

## Rule 5, the timed start. The spot on the line is approached along a run-in line (a close reach
## when the first leg is a beat, the first leg's own course on a reaching start), from a waiting
## point on it just behind the start line. Beating up to that point with time to spare, it sails
## on past the layline before its last tack, which uses the time at full speed. With plenty of time
## to spare at the line it sails away on a broad reach and gybes back when the time left equals the
## way back (the gybe, and the distance over the speed it expects) plus its timing error. Near the
## line it crosses where it would arrive on time: of the points of the line it can reach on its
## present tack, the first one it would not reach early; when it would be early everywhere, the
## one it reaches last (further along the line, which is how a board that cannot stop loses time
## without losing speed). Over the line at the gun (OCS) it goes back behind the line and starts
## again.
func _start_heading(telemetry: Telemetry, step: RaceStep) -> float:
	var position: Vector2 = _position(telemetry)
	var wind_deg: float = telemetry.wind_from_bearing_deg
	var spot: Vector2 = _start_spot(step)
	var forward: Vector2 = step.in_dir
	var run_in: Vector2 = _run_in_direction(step, wind_deg)
	# The waiting point is on the run-in line, START_HOLD_BEHIND_M behind the start line, and moved
	# START_DRIFT_ROOM_M back along the line against the way the run in drifts, so that a board that
	# crosses further along the line to lose time still crosses near its spot.
	var drift: Vector2 = (run_in - forward * run_in.dot(forward)).normalized()
	var hold: Vector2 = spot - run_in * (START_HOLD_BEHIND_M / maxf(run_in.dot(forward), 0.3)) - drift * START_DRIFT_ROOM_M
	# How far behind the line (or its extensions) it is, metres; negative over it.
	var behind_m: float = -RoundingCheck.over_line_m(position, step.points[0], step.points[1], forward)
	# At the waiting point, or nearer the line than it: from here it runs in (until it sails away
	# for another loop).
	if position.distance_to(hold) <= START_HOLD_REACHED_M or behind_m <= START_HOLD_BEHIND_M:
		_reached_hold = true
	# The seconds until it wants to cross: the gun plus its timing error (after the gun it counts down
	# past zero, so a late starter goes at once). What it has to spare is that, less the time it
	# needs to get to the line: to its spot from afar, to the point it chooses near the line.
	var aim_s: float = -_race.clock_s() + config.start_timing_error_s
	var cross_at: Vector2 = spot
	if _reached_hold:
		cross_at = _choose_crossing(telemetry, step, aim_s)
	var spare_s: float = aim_s - _time_to_s(telemetry, cross_at)
	start_spare_s = spare_s
	if _race.clock_s() >= 0.0 and _race.is_ocs(_index):
		_start_phase = StartPhase.BACK_BEHIND
	match _start_phase:
		StartPhase.BACK_BEHIND:
			if _race.is_ocs(_index):
				var back_deg: float = _course_to(telemetry, spot - forward * START_BACK_BEHIND_M)
				note = "start: back behind the line"
				return back_deg
			_start_phase = StartPhase.RUN_IN
		StartPhase.TO_LINE:
			if spare_s > START_GO_SPARE_S and not _reached_hold:
				return _to_the_line_deg(telemetry, step, hold, spot, aim_s)
			_start_phase = StartPhase.AWAY if spare_s > START_LOOP_SPARE_S else StartPhase.RUN_IN
		StartPhase.AWAY:
			# The time it needs counts the gybe back (the way back is a reach on the other tack).
			if spare_s <= START_GO_SPARE_S:
				_start_phase = StartPhase.TURNING
				_turn_back_from_s = _time_s
	if _start_phase == StartPhase.AWAY:
		note = "start: away"
		return _away_heading(telemetry, step)
	if _start_phase == StartPhase.TURNING:
		var turning: bool = _tack_due_s >= 0.0 or _controller.manoeuvre != PlayerController.Manoeuvre.NONE
		if turning:
			note = "start: turning back"
			return _last_wanted_deg
		if _manoeuvre_ended_s <= _turn_back_from_s:
			note = "start: turning back"
			return _gybe_now(telemetry)
		_start_phase = StartPhase.RUN_IN
	# RUN_IN.
	var before_gun: bool = _race.clock_s() < 0.0
	if not _reached_hold:
		if before_gun and spare_s > START_GO_SPARE_S:
			return _to_the_line_deg(telemetry, step, hold, spot, aim_s)
		# Late: straight for its spot.
		var late_deg: float = _course_to(telemetry, _through(position, spot))
		note = "start: for the spot"
		return late_deg
	if before_gun and spare_s > START_LOOP_SPARE_S + 4.0:
		_start_phase = StartPhase.AWAY
		_reached_hold = false
		note = "start: away again"
		return _away_heading(telemetry, step)
	var go_deg: float = _course_to(telemetry, _through(position, cross_at))
	note = "start: run in" if before_gun and spare_s > START_GO_SPARE_S else "start: go"
	return go_deg


## The point of the start line it makes for near the line, aiming to cross at aim_s from now: of
## the points it can reach on a reach on its present tack (no tack, no beat), the one it would reach
## soonest without being early; when it would be early at every one of
## them, the one it reaches last; with none on this tack, the nearest point of the line.
func _choose_crossing(telemetry: Telemetry, step: RaceStep, aim_s: float) -> Vector2:
	var position: Vector2 = _position(telemetry)
	var wind_deg: float = telemetry.wind_from_bearing_deg
	var tack: float = _tack()
	var up_track_deg: float = config.upwind_vmg_twa_deg + config.pointing_offset_deg + _leeway_deg
	var inset: float = _line_inset(step)
	var on_time: Vector2 = Vector2.INF
	var on_time_s: float = INF
	var latest: Vector2 = Vector2.INF
	var latest_s: float = -INF
	for i: int in START_CROSSING_SAMPLES:
		var point: Vector2 = step.points[1].lerp(step.points[0], lerpf(inset, 1.0 - inset, float(i) / (START_CROSSING_SAMPLES - 1)))
		var needed_twa: float = wrapf(wind_deg - Course.bearing_deg(position, point), -180.0, 180.0)
		if signf(needed_twa) != tack or absf(needed_twa) < up_track_deg:
			continue
		var need_s: float = _time_to_s(telemetry, point)
		if need_s >= aim_s and need_s < on_time_s:
			on_time = point
			on_time_s = need_s
		if need_s > latest_s:
			latest = point
			latest_s = need_s
	if on_time_s < INF:
		return on_time
	if latest_s > -INF:
		return latest
	return _nearest_on_line(step, position)


## On the way to the waiting point behind the line, with time to spare, arriving on the run-in
## tack. When that is a beat, it sails on past the layline on the other tack and tacks when the way
## from there (the tack, the reach to the waiting point, the run in from it) takes the time it has
## left: the longer way uses the time at full speed.
func _to_the_line_deg(telemetry: Telemetry, step: RaceStep, hold: Vector2, spot: Vector2, aim_s: float) -> float:
	var position: Vector2 = _position(telemetry)
	var wind_deg: float = telemetry.wind_from_bearing_deg
	var tack: float = _tack()
	var run_in_tack: float = _start_run_in_tack(step, wind_deg)
	note = "start: to the line"
	var needed_twa: float = wrapf(wind_deg - Course.bearing_deg(position, hold), -180.0, 180.0)
	var up_track_deg: float = config.upwind_vmg_twa_deg + config.pointing_offset_deg + _leeway_deg
	if tack != run_in_tack and signf(needed_twa) == run_in_tack and absf(needed_twa) >= up_track_deg and absf(needed_twa) < 90.0:
		# Past the layline: the waiting point is a reach on the run-in tack.
		var reach_ms: float = maxf(_speed_ratio * _polar_speed_ms(absf(needed_twa) - _leeway_deg), 1.0)
		var run_in_deg: float = Course.bearing_deg(Vector2.ZERO, _run_in_direction(step, wind_deg))
		var run_in_ms: float = maxf(_speed_ratio * _polar_speed_ms(wrapf(wind_deg - run_in_deg, -180.0, 180.0)), 1.0)
		var after_s: float = START_TURN_S + position.distance_to(hold) / reach_ms + hold.distance_to(spot) / run_in_ms
		if after_s >= aim_s - START_GO_SPARE_S:
			_ask_for_manoeuvre(true)
		note = "start: to the line, timing the tack"
		return wind_deg - tack * _upwind_twa_deg() + _keep_clear_deg(telemetry, tack)
	var heading_deg: float = _course_to(telemetry, hold, null, run_in_tack)
	note = "start: to the line (%s)" % note
	return heading_deg


## A point THROUGH_LINE_M beyond a point on the line, straight on from a position: the straight
## course from the position to it crosses the line at that point and nowhere else (aimed beyond the
## line in its own direction instead, a board coming in at a slant would cross the line's extension
## first).
static func _through(position: Vector2, on_line: Vector2) -> Vector2:
	return on_line + (on_line - position).normalized() * THROUGH_LINE_M


## The point of the start line nearest a position, kept a few metres in from the ends.
func _nearest_on_line(step: RaceStep, position: Vector2) -> Vector2:
	var inset: float = _line_inset(step)
	return step.points[1].lerp(step.points[0], clampf(_share_along_line(step, position), inset, 1.0 - inset))


## Where a point is along the start line: 0 level with the pin, 1 with the boat.
static func _share_along_line(step: RaceStep, point: Vector2) -> float:
	var boat: Vector2 = step.points[0]
	var pin: Vector2 = step.points[1]
	return (point - pin).dot(boat - pin) / maxf(pin.distance_squared_to(boat), 1e-6)


## The share of the start line's length kept clear at each end: 6 m, at most 40 % of the line.
static func _line_inset(step: RaceStep) -> float:
	return clampf(6.0 / maxf(step.points[0].distance_to(step.points[1]), 1.0), 0.0, 0.4)


## The direction of the run in to the spot on the start line, one metre long: the first leg's
## course when that is a reach (a reaching start), otherwise a close reach of START_RUN_IN_TWA_DEG
## on the run-in tack (_start_run_in_tack()).
func _run_in_direction(step: RaceStep, wind_deg: float) -> Vector2:
	var first_deg: float = _first_leg_deg(step)
	var first_twa: float = absf(wrapf(wind_deg - first_deg, -180.0, 180.0))
	if first_twa >= START_RUN_IN_TWA_DEG and first_twa <= config.downwind_vmg_twa_deg:
		return Course.direction_of(first_deg)
	var run_in: Vector2 = Course.direction_of(wind_deg - _start_run_in_tack(step, wind_deg) * START_RUN_IN_TWA_DEG)
	return run_in if run_in.dot(step.in_dir) > 0.3 else step.in_dir


## The tack of the run in, chosen once: on a reaching start the first leg's tack; otherwise the
## tack other than the one the board waits on before the start, so that the beat up to the line
## needs one tack only (the boards wait downwind of the line). A tack on which the close reach would
## not cross the line is not chosen.
func _start_run_in_tack(step: RaceStep, wind_deg: float) -> float:
	if _run_in_tack != 0.0:
		return _run_in_tack
	var first_twa: float = wrapf(wind_deg - _first_leg_deg(step), -180.0, 180.0)
	if absf(first_twa) >= START_RUN_IN_TWA_DEG and absf(first_twa) <= config.downwind_vmg_twa_deg:
		_run_in_tack = signf(first_twa)
	else:
		_run_in_tack = -_tack()
		if Course.direction_of(wind_deg - _run_in_tack * START_RUN_IN_TWA_DEG).dot(step.in_dir) <= 0.3:
			_run_in_tack = -_run_in_tack
	return _run_in_tack


## The course from the start spot to the first leg's target, degrees.
func _first_leg_deg(step: RaceStep) -> float:
	var first: RaceStep = _race.steps()[1] if _race.steps().size() > 1 else step
	return Course.bearing_deg(_start_spot(step), first.target())


## The broad reach away from the line, on the tack other than the run in's, so that the turn back
## (a gybe) puts the board on the run-in tack: back along the run-in line (its reciprocal), but at
## least 10 degrees deeper than the angle up to which the controller tacks, so that the turn back is
## a gybe, which keeps the board's speed. On the run-in tack it first bears away to that angle, so
## that the turn onto the away tack is a gybe too.
func _away_heading(telemetry: Telemetry, step: RaceStep) -> float:
	var wind_deg: float = telemetry.wind_from_bearing_deg
	var tack: float = _tack()
	var away_tack: float = -_start_run_in_tack(step, wind_deg)
	if tack != away_tack:
		return _gybe_now(telemetry)
	var back_deg: float = Course.bearing_deg(Vector2.ZERO, -_run_in_direction(step, wind_deg))
	var back_twa: float = absf(wrapf(wind_deg - back_deg, -180.0, 180.0))
	return wind_deg - tack * clampf(back_twa, config.upwind_vmg_twa_deg + 15.0, config.downwind_vmg_twa_deg)


## Asks for a gybe, and the heading to hold for it: the controller gybes from beyond its tacking
## angle (PlayerController.tack_up_to_twa_deg) and tacks from closer, so the board first bears away
## 10 degrees past that angle and asks only once it is nearly there.
func _gybe_now(telemetry: Telemetry) -> float:
	var gybe_from_deg: float = _controller.tack_up_to_twa_deg + 10.0
	var tack: float = _tack()
	if absf(telemetry.twa_deg) > gybe_from_deg - 5.0:
		_ask_for_manoeuvre(true)
		return telemetry.wind_from_bearing_deg - tack * absf(telemetry.twa_deg)
	return telemetry.wind_from_bearing_deg - tack * gybe_from_deg


## How long it expects to need from here to a point, seconds: the way there over the speed it
## expects (the polar's speed times what it has measured against the polar), plus the time to turn
## onto its course and to gain the speed it still lacks. A point beyond the polar's angles is
## reached in two legs, on this tack and the other (or the other way round), with a tack or gybe
## between them unless one of the legs is short.
func _time_to_s(telemetry: Telemetry, target: Vector2) -> float:
	var position: Vector2 = _position(telemetry)
	var wind_deg: float = telemetry.wind_from_bearing_deg
	var tack: float = _tack()
	var needed_twa: float = wrapf(wind_deg - Course.bearing_deg(position, target), -180.0, 180.0)
	var up_deg: float = config.upwind_vmg_twa_deg + config.pointing_offset_deg
	var down_deg: float = config.downwind_vmg_twa_deg
	var sail_deg: float = clampf(absf(needed_twa) - _leeway_deg, up_deg, down_deg)
	var speed_ms: float = maxf(_speed_ratio * _polar_speed_ms(sail_deg), 1.0)
	var gaining_s: float = maxf(speed_ms - telemetry.speed_ms, 0.0) / (2.0 * ACCELERATION_MS2)
	var track_deg: float = sail_deg + _leeway_deg
	if absf(needed_twa) < up_deg + _leeway_deg or absf(needed_twa) > down_deg + _leeway_deg:
		# Two legs: the way to the point split along this tack's track and the other tack's.
		var this: Vector2 = Course.direction_of(wind_deg - tack * track_deg)
		var other: Vector2 = Course.direction_of(wind_deg + tack * track_deg)
		var legs: Vector2 = _split_along(target - position, this, other)
		var turn_s: float = START_TURN_S if legs.x > LAID_WITHIN_M and legs.y > LAID_WITHIN_M else 0.0
		if legs.x <= LAID_WITHIN_M and legs.y > LAID_WITHIN_M:
			turn_s = START_TURN_S  # all of it on the other tack: a tack or gybe first
		return (legs.x + legs.y) / speed_ms + gaining_s + turn_s
	var distance_m: float = position.distance_to(target)
	if signf(needed_twa) != tack:
		return distance_m / speed_ms + gaining_s + START_TURN_S
	# A reach on this tack: the time to turn onto it too.
	return distance_m / speed_ms + gaining_s + _turn_time_s(telemetry, absf(needed_twa) - _leeway_deg)


## The time turning onto a wind angle on the present tack costs, seconds. Heading up at speed is
## slow (the controller holds it to head_up_rate_budget_dps_ms over the speed); bearing away goes at
## its turn rate. The board keeps sailing while it turns, about half the way in the new direction,
## so half the turn is lost.
func _turn_time_s(telemetry: Telemetry, to_twa_deg: float) -> float:
	var turn_deg: float = to_twa_deg - absf(telemetry.twa_deg)
	if absf(turn_deg) < STEER_DEAD_BAND_DEG:
		return 0.0
	var rate_dps: float = _controller.turn_rate_dps
	if turn_deg < 0.0:
		rate_dps = clampf(_controller.head_up_rate_budget_dps_ms / maxf(telemetry.speed_ms, 0.1), _controller.head_up_rate_min_dps, _controller.turn_rate_dps)
	return 0.5 * absf(turn_deg) / rate_dps


## A way split into two legs along two directions (one metre long each): the lengths (along a,
## along b), metres, each at least 0.
static func _split_along(way: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var det: float = a.x * b.y - a.y * b.x
	if absf(det) < 1e-6:
		return Vector2(way.length(), 0.0)
	var along_a: float = (way.x * b.y - way.y * b.x) / det
	var along_b: float = (a.x * way.y - a.y * way.x) / det
	return Vector2(maxf(along_a, 0.0), maxf(along_b, 0.0))


## The polar's speed at a wind angle (degrees, either tack), m/s, between the table's rows.
static func _polar_speed_ms(twa_deg: float) -> float:
	var angle: float = clampf(absf(twa_deg), POLAR_TWA_DEG[0], POLAR_TWA_DEG[-1])
	for i: int in range(1, POLAR_TWA_DEG.size()):
		if angle <= POLAR_TWA_DEG[i]:
			var share: float = (angle - POLAR_TWA_DEG[i - 1]) / (POLAR_TWA_DEG[i] - POLAR_TWA_DEG[i - 1])
			return lerpf(POLAR_SPEED_MS[i - 1], POLAR_SPEED_MS[i], share)
	return POLAR_SPEED_MS[-1]


# ---------------------------------------------------------------- the hands

## Rule 8: the heading decided reaction_time_s ago (the first one until then).
func _after_reaction(decided_deg: float) -> float:
	_delay_times.append(_time_s)
	_delay_headings.append(decided_deg)
	while _delay_times.size() > 1 and _delay_times[1] <= _time_s - config.reaction_time_s:
		_delay_times.remove_at(0)
		_delay_headings.remove_at(0)
	return _delay_headings[0]


## Rule 8: the slow wander of the wanted heading, degrees: a random drift pulled back toward zero
## over NOISE_TIME_S, steering_noise_deg on average either way. Seeded, so a race repeats.
func _wander(dt: float) -> float:
	if config.steering_noise_deg <= 0.0:
		return 0.0
	var kick: float = config.steering_noise_deg * sqrt(2.0 * dt / NOISE_TIME_S) * _rng.randfn(0.0, 1.0)
	_noise_deg += -_noise_deg / NOISE_TIME_S * dt + kick
	return _noise_deg


## The stick from the wanted heading: let go inside the dead band (the controller holds the
## heading), in proportion to the error beyond it. Hands off during a manoeuvre, which the
## controller sails by itself, and after it until the board has stopped carving, as the
## controller's own settling does (PlayerController.settle_rate_dps).
func _steer_toward(telemetry: Telemetry, wanted_deg: float) -> void:
	_hands.steer = 0.0
	if _controller.manoeuvre != PlayerController.Manoeuvre.NONE:
		return
	if _settling:
		if absf(telemetry.yaw_rate_dps) > _controller.settle_rate_dps and telemetry.speed_ms > _controller.settle_speed_ms:
			return
		_settling = false
	# Positive turns right (the heading increases).
	var error_deg: float = wrapf(wanted_deg - telemetry.heading_deg, -180.0, 180.0)
	if absf(error_deg) < STEER_DEAD_BAND_DEG:
		return
	_hands.steer = clampf(error_deg / FULL_STICK_ERROR_DEG, -1.0, 1.0)


## Decides on a tack or gybe (the controller chooses which from the wind angle), to be asked for
## after the reaction time. Not while one is under way or waiting, not soon after the last, and not
## past the cap on this leg unless it is needed to reach the target (a layline).
func _ask_for_manoeuvre(needed: bool) -> void:
	if _tack_due_s >= 0.0 or _controller.manoeuvre != PlayerController.Manoeuvre.NONE or _settling:
		return
	if _time_s - _manoeuvre_ended_s < MIN_TACK_INTERVAL_S or not _pointing and absf(_sim.telemetry.twa_deg) < 90.0:
		return
	if not needed and _manoeuvres_here() >= config.max_tacks_per_beat:
		return
	_tack_due_s = _time_s + config.reaction_time_s


## Presses Space once the reaction time is up.
func _ask_when_due() -> void:
	if _tack_due_s >= 0.0 and _time_s >= _tack_due_s:
		_tack_due_s = -1.0
		if _controller.manoeuvre == PlayerController.Manoeuvre.NONE:
			_hands.tack = true


# ---------------------------------------------------------------- what it sees

## Counts the manoeuvres as the controller starts them, and notes when one ends.
func _watch_manoeuvres(telemetry: Telemetry) -> void:
	var now: PlayerController.Manoeuvre = _controller.manoeuvre
	if now != _last_manoeuvre:
		if _last_manoeuvre == PlayerController.Manoeuvre.NONE:
			if now == PlayerController.Manoeuvre.TACK_HEADING_UP or now == PlayerController.Manoeuvre.TACK_BEARING_AWAY:
				tacks += 1
			else:
				gybes += 1
			var step: int = _race.next_step_index(_index)
			if step < manoeuvres_by_step.size():
				manoeuvres_by_step[step] += 1
		elif now == PlayerController.Manoeuvre.NONE:
			_manoeuvre_ended_s = _time_s
			_settling = absf(telemetry.yaw_rate_dps) > _controller.settle_rate_dps
		_last_manoeuvre = now


## Its own measurements: the speed (for pointing), the leeway and the speed against the polar
## (smoothed, only while sailing steadily), its velocity over the ground, and the mean wind.
func _measure(telemetry: Telemetry, dt: float) -> void:
	_tick_s = dt
	var position: Vector2 = _position(telemetry)
	_velocity = (position - _last_position) / maxf(dt, 1e-6)
	_last_position = position
	var pilot: Autopilot = _controller.auto_sheet_pilot
	if telemetry.speed_ms > pilot.pointing_speed_ms:
		_pointing = true
	elif telemetry.speed_ms < pilot.pointing_speed_ms - 1.5:
		_pointing = false
	var steady: bool = _controller.manoeuvre == PlayerController.Manoeuvre.NONE and absf(telemetry.yaw_rate_dps) < 5.0
	var share: float = clampf(dt / MEASURE_SMOOTH_S, 0.0, 1.0)
	if steady and telemetry.speed_ms > pilot.pointing_speed_ms:
		_leeway_deg = lerpf(_leeway_deg, clampf(absf(telemetry.leeway_deg), 0.0, 12.0), share)
		if absf(telemetry.twa_deg) >= 40.0:
			_speed_ratio = lerpf(_speed_ratio, clampf(telemetry.speed_ms / _polar_speed_ms(telemetry.twa_deg), 0.5, 2.0), share)
	var memory_share: float = clampf(dt / WIND_MEMORY_S, 0.0, 1.0)
	_wind_memory_deg = wrapf(_wind_memory_deg + memory_share * wrapf(telemetry.wind_from_bearing_deg - _wind_memory_deg, -180.0, 180.0), 0.0, 360.0)


## Forgets the per-step decisions when the race moves it on to the next step.
func _new_step_check() -> void:
	var step: int = _race.next_step_index(_index)
	if step != _step_seen:
		_step_seen = step
		_level_with_mark = false
		_gate_end = -1
		# A tack decided for the last step is not one for this.
		_tack_due_s = -1.0


func _remember_others() -> void:
	for j: int in _race.board_count():
		_others_last[j] = _race.board_position(j)


## The tacks and gybes made so far on the way to the present step.
func _manoeuvres_here() -> int:
	return manoeuvres_on_step(_race.next_step_index(_index))


## +1 on starboard tack (the wind from starboard), -1 on port: read from the side the sail is on,
## as the controller's autopilot reads it (Autopilot.update_tack), so the skipper and the
## controller agree on the tack. (The controller's own copy is only brought up to date in its
## update, which runs after the skipper's.)
func _tack() -> float:
	var telemetry: Telemetry = _sim.telemetry
	if telemetry.sail_side != 0:
		return -float(telemetry.sail_side)
	return 1.0 if telemetry.twa_deg >= 0.0 else -1.0


static func _position(telemetry: Telemetry) -> Vector2:
	return Vector2(telemetry.position.x, telemetry.position.z)
