class_name Skipper
extends RaceSkipper
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
## Around the race it lives on the water (AI_FLEET_PLAN.md, D4): a small state machine driven by the
## race (state_for()). FREE_SAILING before the countdown (and after the race): legs on a point of
## sail, a tack or gybe, inside its SailingArea and clear of the others. PRE_START from the
## countdown until it has started: the start of rule 5, with the end of the line chosen from the
## line's bias and its character, its start plan (a timing loop or a hold with the hands'
## hold-back skill), and, over the line at the gun, back round the nearer end. RACING: rules 1 to 8.
## FINISHED: clear of the finish line, then free sailing again.
##
## Directions are compass bearings (0 north, 90 east, clockwise) and wind angles are positive with
## the wind from starboard (D4). Positions are game metres, Vector2(X east, Z south), as in Course.

## What it is doing around the race (D4; state_for()).
enum State { FREE_SAILING, PRE_START, RACING, FINISHED }

enum StartPhase {
	## Sailing to a point just behind the chosen spot on the line.
	TO_LINE,
	## Time to spare: sailing away from the line on a broad reach.
	AWAY,
	## The tack or gybe that turns it back toward the line.
	TURNING,
	## Running in to cross at the gun; crossing further along the line if it is still early.
	RUN_IN,
	## On the course side of the line or its extensions before it has started (over early, OCS at
	## the gun, or past an end of the line): back behind it before starting again.
	BACK_BEHIND,
}

## A line is aimed at this far beyond it, metres (see _target_point()).
const THROUGH_LINE_M: float = 30.0
## A mark that can be gone round without a tack or gybe from one tack only is approached on that
## tack. On the other tack the skipper makes for that tack's layline short of the mark by the way it
## sails in APPROACH_ROOM_S, but at least APPROACH_ROOM_M, so that it has room to tack and get going
## again (a tack stops the board, and it needs some 40 m to get going), or to gybe (a planing gybe
## swings wide). See _course_to().
const APPROACH_ROOM_M: float = 40.0
const APPROACH_ROOM_S: float = 6.0
## Rule 6: another board this close, metres, and getting closer, makes it bear away this much.
const KEEP_CLEAR_M: float = 15.0
const KEEP_CLEAR_BEAR_AWAY_DEG: float = 15.0
## The best downwind angle of POLAR_15KT.md, which the character sheets' downwind angles are
## measured from (see _downwind_twa_deg()).
const POLAR_15KT_DOWNWIND_TWA_DEG: float = 135.0
## Steering: inside the dead band the stick is let go and the controller holds the heading; beyond
## it the stick moves in proportion to the error, fully at FULL_STICK_ERROR_DEG (30 degrees of
## error asks for the controller's full turn rate, 30 degrees per second).
const STEER_DEAD_BAND_DEG: float = 2.0
## Faster than GENTLE_HEAD_UP_FROM_MS the dead band is this wide.
const STEER_DEAD_BAND_FAST_DEG: float = 4.0
const FULL_STICK_ERROR_DEG: float = 30.0
## Faster than this, it heads up with at most this much stick (a fifth of the full turn rate, some
## 6 degrees per second): see _steer_toward().
const GENTLE_HEAD_UP_FROM_MS: float = 12.0
const GENTLE_HEAD_UP_STICK: float = 0.2
## The steering noise wanders on about this time scale, seconds: a slow wobble, not a shake.
const NOISE_TIME_S: float = 4.0
## The head thinks this often, seconds (AI_FLEET_PLAN.md, D1: 1 or 2 Hz); the hands every tick.
const THINK_INTERVAL_S: float = 0.5
## A tack or gybe asked for this soon after the last one ended is not asked for: the board needs
## time to get going again.
const MIN_TACK_INTERVAL_S: float = 8.0
## The leeway and the speed it expects are smoothed over this long, seconds; the leeway is measured
## above MEASURE_LEEWAY_FROM_MS.
const MEASURE_SMOOTH_S: float = 3.0
const MEASURE_LEEWAY_FROM_MS: float = 2.5
## A sailor's feel for the board. Downwind, below OFF_PLANE_MS the board is off the plane and the
## sailor heads up RUN_HEAD_UP_DEG to get it planing again, and bears away once it is faster than
## ON_PLANE_MS. Upwind, a board slower than FOOT_BELOW_MS is sailed FOOT_DEG_PER_MS lower for each
## m/s it lacks, at most FOOT_MAX_DEG lower.
const OFF_PLANE_MS: float = 6.0
const ON_PLANE_MS: float = 7.0
const RUN_HEAD_UP_DEG: float = 10.0
const FOOT_BELOW_MS: float = 5.5
const FOOT_DEG_PER_MS: float = 4.0
const FOOT_MAX_DEG: float = 10.0
## Its memory of the mean wind direction, for the wind shifts, seconds.
const WIND_MEMORY_S: float = 90.0
## The start (rule 5). The run in to the spot on the line is a close reach at this wind angle when
## the first leg is a beat, or the first leg's own course. On a line square to the wind a board on
## a close reach sails further along the line than toward it (2.2 m per metre at 60 degrees and its
## leeway), and the line is only 60 m long; but closer to the wind a board getting going from a
## hold (slow, so slipping sideways and pointing low) could not lay its spot (at 50 degrees from 20
## m behind the line it ran along the line past its end).
const START_RUN_IN_TWA_DEG: float = 60.0
## Its waiting point is at least this far behind the start line, metres; within
## START_HOLD_REACHED_M of the way in from it to its spot, the board sails in.
const START_HOLD_BEHIND_M: float = 20.0
const START_HOLD_REACHED_M: float = 15.0
## A board holding back slows by about this much a second (m/s2): easing the sheet does not stop it
## at once (from 10.5 to 2.5 m/s took some 10 s on T2 at 18 kt).
const HOLD_DECEL_MS2: float = 0.9
## It joins the way in when holding back from where it is can use up its spare time but for this
## many seconds; with more time than that it sails on to the waiting point first.
const START_HOLD_TOLERANCE_S: float = 2.0
## Before the gun, a board that would cross the line within START_GUARD_S seconds at its speed
## toward it, and before the gun or less than START_GUARD_MARGIN_S after it, holds back as slow as it
## steers: over the line at the gun is OCS.
const START_GUARD_S: float = 6.0
const START_GUARD_MARGIN_S: float = 0.5
## Out past an end of the line by more than START_WALL_ENDS_M, within START_WALL_M of the line's
## extension and sailing toward it, it tacks or gybes away, metres.
const START_WALL_M: float = 12.0
const START_WALL_ENDS_M: float = 2.0
## It goes from its hold when the time left is the time it needs to cross, give or take this
## (seconds; a little less than nothing: it crosses just after the time it aims for, never before).
const HOLD_GO_SPARE_S: float = -0.25
## Going, a spot further along the line than this wind angle (degrees) is too shallow a run in: it
## crosses where a run in at START_GO_TWA_DEG (and its leeway) meets the line instead.
const START_GO_SHALLOWEST_TWA_DEG: float = 72.0
const START_GO_TWA_DEG: float = 62.0
## Too fast holding back, it luffs up no closer to the wind than this, degrees; nearly stopped
## (slower than the steerage speed and half a metre a second), it bears away this much to get the
## board moving again, degrees.
const HOLD_LUFF_TWA_DEG: float = 45.0
const HOLD_BEAR_AWAY_DEG: float = 15.0
## Holding back it steers for a point this far ahead on its way in, metres (so it keeps to it).
const HOLD_CARROT_M: float = 30.0
## What a tack or gybe costs, seconds: the turn and getting going again (a tack stops the board).
## The gybe back from the broad reach away from the line, at 10 m/s, costs START_GYBE_EXTRA_S
## more: the board comes out of it at 1 to 2 m/s (T2 at 18 kt), and the gybe and getting going
## again took some 15 s in the races from random spots.
const START_TURN_S: float = 6.5
const START_GYBE_EXTRA_S: float = 9.0
## It is on time when it has less than this to spare, seconds.
const START_GO_SPARE_S: float = 1.0
## Near the line it looks at this many points of the line to choose where to cross.
const START_CROSSING_SAMPLES: int = 21
## Over the line early: the point it goes back to is this far behind the nearest point of the line,
## metres.
const START_BACK_BEHIND_M: float = 15.0
## Over the line at the gun (OCS) it goes back round the nearer end of the line, as the rules say:
## out past the end by this much on the course side, then behind the line, metres.
const START_ROUND_END_M: float = 15.0
## The line's bias (line_bias_deg()): a line skewed this much from square to the wind, or more,
## sends a skipper keen on the favoured end (SkipperConfig.favoured_end_bias 1) all the way to it.
## 10 degrees on T1's 60 m line puts one end 10 m nearer the wind: two boat lengths and more.
const FULL_BIAS_DEG: float = 10.0
## Holding back, the board sails no closer to the wind than this, degrees, with the sheet eased to
## the hold speed (the hands' hold-back skill). Measured on the open water's sea, holding back to
## 2.5 m/s: at 45 degrees in 12 kt the sail was fully sheeted and the board still made 2.0 to 2.3
## m/s (it does not stop); at 60 degrees it holds 2.2 to 2.5 m/s in 12 to 24 kt and is back at 6 m/s
## 2 to 6 s after letting go. 50 keeps the way in on an upwind start steep enough to the line.
const HOLD_TWA_DEG: float = 50.0
## Slow, a board holding back slips sideways: its track runs about this much further off the wind
## than its bow (measured 6 to 16 degrees at 2 to 2.5 m/s, more the closer to the wind), degrees.
const HOLD_LEEWAY_DEG: float = 11.0
## Holding back, its track runs at least this far off the wind, degrees (see _hold_twa_deg()).
const HOLD_TRACK_MIN_TWA_DEG: float = 75.0
## It holds back no further off the wind than this, degrees: wider, the eased sail cannot slow the
## board (the boom goes out no further than 85 degrees, and a sail let out on a broad reach still
## drives).
const HOLD_WIDEST_TWA_DEG: float = 90.0
## In a strong wind on a reach the eased sail still drives the board faster than its hold speed
## (4.5 m/s at 24 kt): it then luffs up too, this much for each m/s too fast, degrees per m/s.
const HOLD_LUFF_DEG_PER_MS: float = 10.0
## It luffs so only after holding back this long, seconds, and by at most this much, degrees.
const HOLD_LUFF_AFTER_S: float = 4.0
const HOLD_LUFF_MOST_DEG: float = 15.0
## Going from its hold within START_GO_LATCH_M of the line it keeps going (further back it may still
## change its mind), metres; nearly stopped it does not go unless it is late by more than
## START_STALLED_GO_S, seconds.
const START_GO_LATCH_M: float = 40.0
const START_STALLED_GO_S: float = 3.0
## Further back, gone, it holds back again only with more than this to spare, seconds (as it gains
## speed the time it needs shrinks, and its spare time grows a little).
const START_GO_HYSTERESIS_S: float = 4.0
## The way in is long enough to hold back for up to HOLD_LONGEST_S seconds, as far as the sailing
## area allows. A skipper who holds (HOLD) never loops; one who loops (LOOP) sails its timing loop
## when it has more than START_LOOP_EXCESS_S to spare beyond what its way in can use up (a gybe at
## speed and getting going again cost some 15 s on the open water's sea, so a shorter loop would
## make it late).
const HOLD_LONGEST_S: float = 60.0
const START_LOOP_EXCESS_S: float = 35.0
## The way in from the waiting point is at most this long (and the way it needs to slow down),
## metres: held back at 2 m/s it uses up some 35 s.
const START_WAY_IN_MAX_M: float = 70.0
## Sailing out to its waiting point the other way along the way in, it holds back this near it,
## metres, to turn there at a moderate speed.
const START_SLOW_FOR_TURN_M: float = 50.0
## The timing loop's way away from the line is sailed held back to this speed, m/s, and it turns
## back with what the way in can use up still to spare plus START_LOOP_RETURN_S (the gybe back and
## getting going again, counted generously: early is put right by holding back, late is not).
const LOOP_AWAY_SPEED_MS: float = 5.0
const START_LOOP_RETURN_S: float = 20.0
## Free sailing (D4): legs on these points of sail (wind angles, degrees; never deeper than the
## angle it runs at), each sailed this long (seconds, at random between the two), then a tack (from
## closer to the wind than FREE_GYBE_FROM_TWA_DEG) or a gybe.
const FREE_TWAS_DEG: PackedFloat32Array = [55.0, 70.0, 90.0, 110.0, 125.0]
const FREE_LEG_MIN_S: float = 15.0
const FREE_LEG_MAX_S: float = 40.0
const FREE_GYBE_FROM_TWA_DEG: float = 80.0
## It ends a leg early when the course would leave the area within FREE_LOOKAHEAD_S, keeping
## FREE_EDGE_M inside it; and when choosing a new leg it looks FREE_LEG_CHECK_S ahead.
const FREE_LOOKAHEAD_S: float = 10.0
const FREE_EDGE_M: float = 35.0
const FREE_LEG_CHECK_S: float = 20.0
## A turn asked for that has not begun after this long is given up (the board had no speed, say).
const FREE_TURN_GIVE_UP_S: float = 15.0
## Outside the area it sails back to the area's middle, until it is this far inside again, metres.
const FREE_BACK_INSIDE_M: float = 60.0
## Beating or running back to the area, it keeps within this many metres across the wind of the
## straight way there (a long beat sailed to the layline would take it far to the side: on the lake,
## onto the shore).
const FREE_CORRIDOR_M: float = 60.0
## Finished: it sails on this far past the finish line (clear of the boards still finishing), then
## sails free.
const FINISH_CLEAR_M: float = 40.0
## A board getting up to speed gains about this much a second (m/s2): the time it expects to need
## includes the speed it still has to gain.
const ACCELERATION_MS2: float = 1.0
## What the skipper knows of its board, to say how long a stretch will take: the settled speed
## (m/s) at each true wind angle in 12, 18 and 24 kt, one row of POLAR_TWA_DEG's angles per wind.
## Measured on the open water's sea (the headless race's) under the beginner controller with a
## skipper's stick: 50 s from rest, the mean of the last 20 s (Documentation/racing_reports/
## skipper.md). 30, 165 and 180 degrees were not measured and are guesses. In 12 kt the board
## does not get planing from rest deeper than 125 degrees. It is not POLAR_15KT.md's polar (flat
## water, the plain autopilot), which the board does not reach on the sea: 74 % of it on a run at
## 18 kt, 119 % on a broad reach at 24 kt. The skipper also measures how fast it goes against
## this table, and uses that ratio too.
const POLAR_WINDS_KT: PackedFloat32Array = [12.0, 18.0, 24.0]
const POLAR_TWA_DEG: PackedFloat32Array = [30.0, 40.0, 45.0, 50.0, 55.0, 60.0, 70.0, 80.0, 90.0, 100.0, 110.0, 120.0, 125.0, 130.0, 135.0, 140.0, 150.0, 165.0, 180.0]
const POLAR_SPEED_MS: PackedFloat32Array = [
	0.8, 1.68, 4.29, 5.19, 5.91, 6.65, 7.54, 8.15, 8.66, 8.85, 8.22, 6.65, 6.58, 2.37, 2.09, 2.07, 1.94, 1.9, 1.9,
	1.0, 5.79, 6.35, 6.84, 7.37, 7.92, 8.88, 9.91, 10.66, 11.53, 11.84, 12.15, 12.08, 11.65, 10.34, 8.15, 4.98, 4.5, 4.5,
	1.2, 5.80, 6.51, 7.11, 7.70, 8.32, 9.64, 10.84, 11.86, 12.55, 13.73, 14.16, 14.33, 14.33, 14.19, 13.33, 8.76, 6.0, 6.0,
]

## The character sheet. (random_seed seeds its steering noise, and note says what it is doing:
## "beat", "run", "start: away", ...; both are RaceSkipper's.)
var config: SkipperConfig = SkipperConfig.new()
## Before its start: the seconds it has to spare (the time until it wants to cross, less the time
## it expects to need to get to its spot), for the tools.
var start_spare_s: float = 0.0
## The tacks and gybes it asked for, counted as the controller starts them.
var tacks: int = 0
var gybes: int = 0
## The tacks and gybes made while sailing to each step of the course, by the step's number.
var manoeuvres_by_step: PackedInt32Array = PackedInt32Array()
## What it is doing around the race (D4), and how often it went into each state (for the tests).
var state: State = State.FREE_SAILING
## The race time at which it crossed the start line (its start), and whether it was over the line
## at the gun; for the tools. NAN until it has started.
var started_at_s: float = NAN
var was_ocs: bool = false

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
## True once it is on its way in from the waiting point to its spot (it holds back and goes from
## there), and once it has gone from its hold.
var _reached_hold: bool = false
var _going: bool = false
## Whether the point of the line it chose near the line can be reached on its present tack.
var _crossing_on_this_tack: bool = true
## When it decided to turn back toward the line (the start's TURNING phase).
var _turn_back_from_s: float = 0.0
## Over the line at the gun: the end of the line it goes back round (0 the pin, 1 the boat; -1 not
## chosen yet), and whether it is out past that end.
var _round_end: int = -1
var _past_the_end: bool = false

## Free sailing: the leg's wind angle and when it ends; a turn asked for (and when); whether it is
## on its way back into the area, and the line across the wind it keeps near on the way.
var _free_twa_deg: float = 0.0
var _free_leg_until_s: float = -INF
var _free_turning: bool = false
var _free_turn_from_s: float = 0.0
var _free_returning: bool = false
var _free_corridor_from: Vector2 = Vector2.ZERO
## Finished: the point past the finish line it sails to, and whether it is clear of the line.
var _finish_clear_point: Vector2 = Vector2.INF
var _clear_of_finish: bool = false

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
## Downwind: true while the board is off the plane (see _downwind_twa_deg()).
var _off_plane: bool = false
## The speed it has found it holds back to in this wind (it learns it while holding back: in a
## strong wind the eased sail still drives the board faster than its hold speed), m/s; and since
## when it has been holding back (-1 when it is not).
var _held_ms: float = 0.0
var _holding_since_s: float = -1.0
## True while it goes from its hold for the start: it points at once (a board coming out of a hold
## at 2.5 m/s sailed the bear-away angle along the line past its end).
var _going_from_hold: bool = false

## What it has measured: its leeway (degrees), its speed against the polar's, the mean wind.
var _leeway_deg: float = 5.0
var _speed_ratio: float = 1.0
var _wind_memory_deg: float = 0.0
var _last_position: Vector2 = Vector2.ZERO
var _velocity: Vector2 = Vector2.ZERO
## The head's turns (THINK_INTERVAL_S): when it thinks next, its moment within the interval, and
## when it last looked at the other boards (and how long before this turn), for their velocities.
var _next_think_s: float = 0.0
var _think_phase_s: float = 0.0
var _others_time_s: float = 0.0
var _others_dt_s: float = THINK_INTERVAL_S
## The other boards' positions at the last tick, to see whether they are getting closer; and
## whether it is keeping clear of one this tick (for the note).
var _others_last: PackedVector2Array = PackedVector2Array()
var _keeping_clear: bool = false
## Its own copies of the polar's tables (see _polar_speed_ms()).
var _polar_winds: PackedFloat32Array = POLAR_WINDS_KT.duplicate()
var _polar_twa: PackedFloat32Array = POLAR_TWA_DEG.duplicate()
var _polar_speeds: PackedFloat32Array = POLAR_SPEED_MS.duplicate()


## The name on its character sheet.
func skipper_name() -> String:
	return config.name


func sail_colour() -> Color:
	return config.sail_colour


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
	if sailing_area == null:
		sailing_area = SailingArea.around_start(race.course)
	# The first update thinks at once; after that at this skipper's own moment of each interval.
	_think_phase_s = think_phase_s(index)
	_next_think_s = 0.0
	_others_time_s = 0.0
	_delay_times.clear()
	_delay_headings.clear()
	_forget_the_race()


## Forgets what it decided about an earlier race (RaceRunner.restart() sets it up again on a new
## race): the start's phases and choices, the free sailing's leg, the finish.
func _forget_the_race() -> void:
	state = State.FREE_SAILING
	started_at_s = NAN
	was_ocs = false
	_step_seen = -1
	_start_phase = StartPhase.TO_LINE
	_run_in_tack = 0.0
	_reached_hold = false
	_going = false
	_crossing_on_this_tack = true
	_round_end = -1
	_past_the_end = false
	_tack_due_s = -1.0
	_free_leg_until_s = -INF
	_free_turning = false
	_free_returning = false
	_finish_clear_point = Vector2.INF
	_clear_of_finish = false
	if _hands != null:
		_hands.hold_speed_ms = 0.0


## The state a skipper is in (D4), from the race: FREE_SAILING before the countdown, after the race
## has ended without it, and once it is clear of the finish line; PRE_START from the countdown until
## it has crossed the start line (late or back from being over early included); RACING until it
## finishes; FINISHED until it is clear of the finish line.
static func state_for(race: RaceSim, index: int, clear_of_finish: bool) -> State:
	if not race.is_started():
		return State.FREE_SAILING
	if race.is_finished(index):
		return State.FREE_SAILING if clear_of_finish else State.FINISHED
	if race.phase() == RaceSim.Phase.FINISHED:
		return State.FREE_SAILING
	if race.next_step_index(index) == 0:
		return State.PRE_START
	return State.RACING


## One tick, before controller.update(): sets hands.steer, hands.sheet and hands.tack (and the
## hold-back's hands.hold_speed_ms).
##
## The head thinks THINK_INTERVAL_S apart (AI_FLEET_PLAN.md, D1: at 1 or 2 Hz), each skipper at a
## moment of its own within the interval (think_phase_s()), so a fleet's skippers do not all think on
## the same tick: the state, the step's target, the laylines, the start plan, who to keep clear of.
## Every tick only the hands run: the decided heading reaches the stick after the reaction time,
## with the steering noise, and a tack asked for is pressed when it is due.
func update(telemetry: Telemetry, dt: float) -> void:
	_time_s += dt
	_watch_manoeuvres(telemetry)
	_measure(telemetry, dt)
	_watch_the_start()
	# The sheet is the auto-sheet's: the skipper never moves the sheet stick.
	_hands.sheet = 0.0
	if _sim.sailor_state != WindsurferSim.SailorState.SAILING:
		# In the water: hands off, and nothing decided keeps waiting.
		_hands.steer = 0.0
		_hands.tack = false
		_hands.hold_speed_ms = 0.0
		_tack_due_s = -1.0
		_settling = false
		note = "in the water (%s)" % telemetry.fall_kind
		return
	if _time_s >= _next_think_s:
		_think(telemetry)
		_next_think_s = (floorf((_time_s - _think_phase_s) / THINK_INTERVAL_S) + 1.0) * THINK_INTERVAL_S + _think_phase_s
	var wanted_deg: float = _after_reaction() + _wander(dt) + _gust_lean_deg()
	_steer_toward(telemetry, wanted_deg)
	_ask_when_due()


## The head's turn (THINK_INTERVAL_S apart): where the race stands, what to do, and the heading it
## wants, which goes into the reaction delay. The hold-back is asked for afresh each time (only the
## start's hold asks for it).
func _think(telemetry: Telemetry) -> void:
	_others_dt_s = maxf(_time_s - _others_time_s, 1e-3)
	state = state_for(_race, _index, _clear_of_finish)
	_hands.hold_speed_ms = 0.0
	_going_from_hold = false
	_new_step_check()
	_keeping_clear = false
	var decided_deg: float = _decide(telemetry)
	if _keeping_clear:
		note += ", keeping clear"
	_last_wanted_deg = decided_deg
	_delay_times.append(_time_s)
	_delay_headings.append(decided_deg)
	_remember_others()


## When within each THINK_INTERVAL_S this skipper thinks, seconds: spread over the interval by the
## board's number (by the golden ratio, so any number of boards spreads evenly).
static func think_phase_s(index: int) -> float:
	return fposmod(float(index) * 0.618034, 1.0) * THINK_INTERVAL_S


## The tacks and gybes made on the way to a step (the start is step 0, mark 1 step 1, ...).
func manoeuvres_on_step(step: int) -> int:
	return manoeuvres_by_step[step] if step < manoeuvres_by_step.size() else 0


# ---------------------------------------------------------------- deciding

## The heading it wants now, before its reaction time and its noise: free sailing, clearing the
## finish, or the next step of the race (the start included).
func _decide(telemetry: Telemetry) -> float:
	match state:
		State.FREE_SAILING:
			return _free_sail_heading(telemetry)
		State.FINISHED:
			return _clear_of_finish_heading(telemetry)
	var step: RaceStep = _race.next_step(_index)
	if step == null:
		note = "finished"
		return _last_wanted_deg
	if step.kind == RaceStep.Kind.START:
		var start_deg: float = _start_heading(telemetry, step)
		note += " (%+.1f s to spare)" % start_spare_s
		return start_deg
	var position: Vector2 = _position(telemetry)
	var target: Vector2 = _target_point(step, position)
	# A mark at the end of a beat or a run is approached on the tack it can be gone round from (until
	# the board is level with the mark and rounding it). At the end of a reach the board comes on the
	# reach's tack, and a gybe round the mark is part of the course (a slalom mark).
	var arrive_tack: float = 0.0
	if step.kind == RaceStep.Kind.MARK and not _level_with_mark:
		var wind_deg: float = telemetry.wind_from_bearing_deg
		var leg_twa: float = absf(wrapf(wind_deg - Course.bearing_deg(Vector2.ZERO, step.in_dir), -180.0, 180.0))
		var up_deg: float = _pointing_twa_deg()
		if leg_twa < up_deg + _leeway_deg or leg_twa > config.downwind_vmg_twa_deg + _leeway_deg:
			arrive_tack = _approach_tack(step, wind_deg, up_deg if leg_twa < 90.0 else _downwind_twa_deg())
	return _course_to(telemetry, target, arrive_tack)


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
	# Leaving a mark to port the board passes on its right: the leg's direction turned a quarter
	# clockwise, which is -orthogonal() in these axes; to starboard, on its left.
	var entry_side: Vector2 = step.in_dir.orthogonal() * way
	if not _level_with_mark:
		# Level with the mark (or within a margin of it: a board coming down on the mark from above,
		# having overstood, must not chase the entry point round in circles) on the side it is left
		# on. A board that comes level on the wrong side (it could not lay the entry point) still
		# sails for the entry point, round the mark's far side.
		_level_with_mark = (position - mark).dot(step.in_dir) >= -margin and (position - mark).dot(entry_side) > 0.0
	if not _level_with_mark:
		return mark + entry_side * margin
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


## The spot on the start line it makes for: its character's own spot (0 the pin, 1 the boat),
## pulled toward the end the line favours (chosen_start_share()), as it reads the line in its memory
## of the mean wind; kept a few metres in from the ends so it does not aim at a mark.
func _start_spot(step: RaceStep) -> Vector2:
	var inset: float = _line_inset(step)
	var share: float = chosen_start_share(config.start_spot, config.favoured_end_bias, line_bias_deg(step, _wind_memory_deg))
	return step.points[1].lerp(step.points[0], clampf(share, inset, 1.0 - inset))


## The line's bias (D4): how far the start line is turned from square to the wind (where it comes
## from, degrees), degrees: positive when the boat end is nearer the wind than the pin, negative
## when the pin is. A sailor reads it by heading head to wind on the line, or by sailing along it.
## The favoured end gains the line's length times the sine of the bias, toward the wind.
static func line_bias_deg(step: RaceStep, wind_deg: float) -> float:
	var boat: Vector2 = step.points[0]
	var pin: Vector2 = step.points[1]
	var length_m: float = boat.distance_to(pin)
	if length_m < 0.01:
		return 0.0
	var boat_upwind_m: float = (boat - pin).dot(Course.direction_of(wind_deg))
	return rad_to_deg(asin(clampf(boat_upwind_m / length_m, -1.0, 1.0)))


## The end of the line its bias favours: 1 the boat end, 0 the pin end, 0.5 for a square line.
static func favoured_end(bias_deg: float) -> float:
	if absf(bias_deg) < 0.5:
		return 0.5
	return 1.0 if bias_deg > 0.0 else 0.0


## Where on the line a skipper starts (0 the pin, 1 the boat): its own spot, pulled toward the
## favoured end by its keenness on it (0 to 1), and the more the more the line is skewed (all the
## way at FULL_BIAS_DEG).
static func chosen_start_share(own_spot: float, keenness: float, bias_deg: float) -> float:
	var end: float = favoured_end(bias_deg)
	if end == 0.5:
		return own_spot
	return lerpf(own_spot, end, clampf(keenness, 0.0, 1.0) * clampf(absf(bias_deg) / FULL_BIAS_DEG, 0.0, 1.0))


## Rules 2, 3 and 4: the heading toward a target point. Straight there if the wind allows; upwind
## of the polar's angle a beat with tacks on the laylines; downwind of it a run with gybes. The
## wanted heading always stays on the present tack: changing tack is a manoeuvre, asked for
## through the hands, never steered through the wind with the stick.
##
## A non-zero arrive_tack is the tack it must arrive on (a mark at the end of a beat or a run that
## can only be gone round from one tack, the start's run in). Until it lays the target on that tack
## it makes for the point of that tack's layline APPROACH_ROOM_M short of the target; so its last
## tack or gybe is onto the arriving tack, with room to get going on it.
##
## With turn_now (going to a point before the start or sailing free, not round a mark), a target
## on a reach on the other tack is a tack or gybe at once, not one at the layline.
func _course_to(telemetry: Telemetry, target: Vector2, arrive_tack: float = 0.0, turn_now: bool = false) -> float:
	var position: Vector2 = _position(telemetry)
	var wind_deg: float = telemetry.wind_from_bearing_deg
	var tack: float = _tack()
	var up_deg: float = _upwind_twa_deg()
	var down_deg: float = _downwind_twa_deg()
	# The track over the ground runs the leeway further off the wind than the bow points.
	var up_track_deg: float = _pointing_twa_deg() + _leeway_deg
	var down_track_deg: float = down_deg + _leeway_deg
	var aim: Vector2 = target
	if arrive_tack != 0.0:
		var target_twa: float = wrapf(wind_deg - Course.bearing_deg(position, target), -180.0, 180.0)
		# Laid: the target is a reach on the arriving tack, on or past that tack's layline.
		var laid: bool = signf(target_twa) == arrive_tack and absf(target_twa) >= up_track_deg and absf(target_twa) <= down_track_deg
		if not laid:
			# The arriving tack's layline runs back from the target along that tack's track. A board
			# already nearer the target than that point sails for the target.
			var track_deg: float = up_track_deg if absf(target_twa) < 90.0 else down_track_deg
			var room_m: float = maxf(APPROACH_ROOM_M, telemetry.speed_ms * APPROACH_ROOM_S)
			if position.distance_to(target) > room_m:
				aim = target - Course.direction_of(wind_deg - arrive_tack * track_deg) * room_m
	var bearing_deg: float = Course.bearing_deg(position, aim)
	# The wind angle of the track straight there, positive with the wind from starboard.
	var needed_deg: float = wrapf(wind_deg - bearing_deg, -180.0, 180.0)
	var needed_side: float = 1.0 if needed_deg >= 0.0 else -1.0
	var margin_m: float = config.layline_margin_m
	var heading_deg: float
	if absf(needed_deg) < up_track_deg:
		note = "beat"
		heading_deg = wind_deg - tack * up_deg
		if _past_layline_m(position, aim, wind_deg, tack, up_track_deg) >= margin_m:
			_ask_for_manoeuvre(true)
		elif _headed_deg(wind_deg, tack) > config.shift_sensitivity_deg and _manoeuvres_here() < config.max_tacks_per_beat - 1:
			# Rule 3's shift: headed on this tack is lifted on the other.
			_ask_for_manoeuvre(false)
	elif absf(needed_deg) > down_track_deg:
		note = "run"
		heading_deg = wind_deg - tack * down_deg
		if _past_layline_m(position, aim, wind_deg, tack, down_track_deg) >= margin_m:
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
		# Downwind the turn is a gybe, which the controller makes only from further off the wind than
		# its tacking angle: it is asked for once the board has borne away that far.
		var turn_ready: bool = upwind or absf(telemetry.twa_deg) > _controller.tack_up_to_twa_deg + 5.0
		# Going to a point rather than round a mark (turn_now), it turns onto the other tack at once:
		# the fewest manoeuvres (Navigation.route()).
		if turn_now and upwind and not _pointing:
			# Too slow to tack (and too slow to gybe well, off the plane): it first gets going on a
			# beam reach, then tacks.
			note = "reach, other tack (getting going to tack)"
			return wind_deg - tack * 90.0 + _keep_clear_deg(telemetry, tack)
		if turn_ready and (turn_now or _past_layline_m(position, aim, wind_deg, tack, up_track_deg if upwind else down_track_deg) >= margin_m):
			_ask_for_manoeuvre(true)
	if aim != target:
		note += " (for the layline)"
	return heading_deg + _keep_clear_deg(telemetry, tack)


## How far past the other tack's layline to a target the board is, metres: negative before it. The
## layline is the line the board would sail to the target on the other tack, track_twa_deg off the
## wind; "past" is the way the present tack carries it. When the target is not ahead on the other
## tack at all, -INF.
static func _past_layline_m(position: Vector2, target: Vector2, wind_deg: float, tack: float, track_twa_deg: float) -> float:
	# On starboard tack (tack +1) the bow is track_twa_deg to the left of the wind; on port to the right.
	var other: Vector2 = Course.direction_of(wind_deg + tack * track_twa_deg)
	var this: Vector2 = Course.direction_of(wind_deg - tack * track_twa_deg)
	if (target - position).dot(other) <= 0.0:
		return -INF
	var across: Vector2 = other.orthogonal()
	if across.dot(this) < 0.0:
		across = -across
	return (position - target).dot(across)


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


## The wind angle it sails upwind: _pointing_twa_deg(), or, while the board is too slow for the fin
## to grip, the autopilot's bear-away angle until it has speed (a sailor does not point high from a
## standstill).
func _upwind_twa_deg() -> float:
	if _going_from_hold and not _pointing:
		# Going from its hold it points at once, but a noisy helm no closer than its hold allows.
		return maxf(_pointing_twa_deg(), HOLD_TWA_DEG + 2.0 * config.steering_noise_deg)
	if not _pointing:
		return maxf(_pointing_twa_deg(), _controller.auto_sheet_pilot.bear_away_twa_deg)
	return _pointing_twa_deg()


## The wind angle it sails upwind once the board has speed, and draws its laylines at: the polar's
## plus its pointing offset, and a little lower for a board slower than FOOT_BELOW_MS
## (FOOT_DEG_PER_MS for each m/s it lacks, at most FOOT_MAX_DEG): in light wind the polar's angle is
## too high (at 12 kt on the open water's sea 50 to 55 degrees make the best way to windward, not 45).
func _pointing_twa_deg() -> float:
	var foot_deg: float = clampf((FOOT_BELOW_MS - _sim.telemetry.speed_ms) * FOOT_DEG_PER_MS, 0.0, FOOT_MAX_DEG)
	return config.upwind_vmg_twa_deg + config.pointing_offset_deg + foot_deg


## The wind angle it sails downwind (rule 4: its gybe angle read from the polar, not a constant):
## the angle with the most speed downwind in the board's polar at the wind of the moment (125
## degrees at 12 kt, 130 at 18, 140 at 24), moved by the character's own difference from
## POLAR_15KT.md's 135; and RUN_HEAD_UP_DEG higher while the board is off the plane (_off_plane),
## which is how a sailor gets it planing again. Deeper than that a board that has stopped planing
## does not plane again (at 12 kt on the open water's sea it does 6.6 m/s at 125 degrees and 2.4 m/s
## at 130).
func _downwind_twa_deg() -> float:
	var own_deg: float = config.downwind_vmg_twa_deg - POLAR_15KT_DOWNWIND_TWA_DEG
	return _best_downwind_twa_deg() + own_deg - (RUN_HEAD_UP_DEG if _off_plane else 0.0)


## The wind angle between 110 and 150 degrees with the most speed downwind (the speed times the
## cosine of the angle off dead downwind) in the polar at the wind of the moment, in 5 degree steps.
func _best_downwind_twa_deg() -> float:
	var best_twa: float = POLAR_15KT_DOWNWIND_TWA_DEG
	var best_vmg: float = -1.0
	var twa: float = 110.0
	while twa <= 150.0:
		var vmg: float = _polar_speed_ms(twa) * cos(deg_to_rad(180.0 - twa))
		if vmg > best_vmg:
			best_vmg = vmg
			best_twa = twa
		twa += 5.0
	return best_twa


## Rule 6: another board close and getting closer makes it bear away a little (to pass to leeward
## of it), never deeper than the angle it runs at (deeper the board stops planing). The change of
## heading, degrees.
func _keep_clear_deg(telemetry: Telemetry, tack: float) -> float:
	# Not while it goes from its hold for the start: bearing away there slides the board along the
	# line, and it misses its spot (no right of way yet: F3's rules).
	if _going_from_hold:
		return 0.0
	var position: Vector2 = _position(telemetry)
	for j: int in _race.board_count():
		if j == _index:
			continue
		var other: Vector2 = _race.board_position(j)
		var apart: Vector2 = other - position
		if apart.length() > KEEP_CLEAR_M:
			continue
		var other_velocity: Vector2 = (other - _others_last[j]) / _others_dt_s
		if apart.dot(other_velocity - _velocity) < 0.0:
			_keeping_clear = true
			var room_deg: float = clampf(_downwind_twa_deg() - absf(telemetry.twa_deg), 0.0, KEEP_CLEAR_BEAR_AWAY_DEG)
			# Bearing away on starboard tack turns the bow to the left (the heading decreases).
			return -tack * room_deg
	return 0.0


## Rule 7, gust hunting, is not built yet: it needs the wind on the water around the board (the
## lake's WindField.velocity_at, with its moving gusts), and the headless race sails the open
## water's even wind. This is where it goes: sample the wind 100 to 200 m ahead on both tacks and
## lean the heading toward the windier side by config.gust_appetite. Until then no lean.
func _gust_lean_deg() -> float:
	return 0.0


# ---------------------------------------------------------------- free sailing and the finish (D4)

## Free sailing, before the countdown and after the race: a leg on a point of sail (FREE_TWAS_DEG,
## chosen at random among those that keep it in the area), sailed FREE_LEG_MIN_S to FREE_LEG_MAX_S,
## then a tack or a gybe and a new leg on the other tack. A leg ends early when its course would take
## the board out of its SailingArea within FREE_LOOKAHEAD_S. Outside the area (after the finish, or
## it appeared at the edge) it sails back to the middle of it, keeping near the straight way there.
## It keeps clear of the other boards as it does racing (rule 6).
func _free_sail_heading(telemetry: Telemetry) -> float:
	var position: Vector2 = _position(telemetry)
	var wind_deg: float = telemetry.wind_from_bearing_deg
	var area: SailingArea = sailing_area
	if area.inside_m(position) < 0.0 and not _free_returning:
		_free_returning = true
		_free_corridor_from = position
		_free_turning = false
	if _free_returning:
		var back_inside_m: float = minf(FREE_BACK_INSIDE_M, 0.5 * minf(area.half_across_m, area.half_up_m))
		if area.inside_m(position) < back_inside_m:
			var back_deg: float = _course_within(telemetry, area.centre, _free_corridor_from)
			note = "free: back to the area (%s)" % note
			return back_deg
		_free_returning = false
		_free_leg_until_s = -INF
	if _free_turning:
		return _free_turn_heading(telemetry)
	var tack: float = _tack()
	if _free_leg_until_s == -INF:
		_pick_free_leg(telemetry, tack)
	var heading_deg: float = wind_deg - tack * _free_twa_deg
	# Time for a turn: the leg is over, or its course would soon take the board out of the area.
	var ahead: Vector2 = position + Course.direction_of(heading_deg) * maxf(telemetry.speed_ms, 3.0) * FREE_LOOKAHEAD_S
	var leaving: bool = area.inside_m(ahead) < FREE_EDGE_M and area.inside_m(ahead) < area.inside_m(position)
	if _time_s >= _free_leg_until_s or leaving:
		_free_turning = true
		_free_turn_from_s = _time_s
		return _free_turn_heading(telemetry)
	note = "free: %.0f deg off the wind" % _free_twa_deg
	return heading_deg + _keep_clear_deg(telemetry, tack)


## The turn at the end of a free-sailing leg: a tack from closer to the wind than
## FREE_GYBE_FROM_TWA_DEG, a gybe from further off (bearing away for it first). Once it is done, a
## new leg on the new tack; given up after FREE_TURN_GIVE_UP_S if it never began.
func _free_turn_heading(telemetry: Telemetry) -> float:
	var wind_deg: float = telemetry.wind_from_bearing_deg
	note = "free: turning"
	if _tack_due_s >= 0.0 or _controller.manoeuvre != PlayerController.Manoeuvre.NONE:
		return _last_wanted_deg
	if _manoeuvre_ended_s > _free_turn_from_s or _time_s - _free_turn_from_s > FREE_TURN_GIVE_UP_S:
		_free_turning = false
		_pick_free_leg(telemetry, _tack())
		return wind_deg - _tack() * _free_twa_deg
	if absf(telemetry.twa_deg) >= FREE_GYBE_FROM_TWA_DEG:
		return _gybe_now(telemetry)
	_ask_for_manoeuvre(true)
	return wind_deg - _tack() * _free_twa_deg


## A new free-sailing leg on a tack: a point of sail from FREE_TWAS_DEG (no deeper than the angle it
## runs at), the first of them in a random order whose course keeps it FREE_EDGE_M inside the area
## for FREE_LEG_CHECK_S; if none does, the one that ends furthest inside. Its length is random too.
func _pick_free_leg(telemetry: Telemetry, tack: float) -> void:
	var position: Vector2 = _position(telemetry)
	var wind_deg: float = telemetry.wind_from_bearing_deg
	var count: int = FREE_TWAS_DEG.size()
	var first: int = _rng.randi_range(0, count - 1)
	var best_twa: float = FREE_TWAS_DEG[first]
	var best_inside_m: float = -INF
	for k: int in count:
		var twa: float = minf(FREE_TWAS_DEG[(first + k) % count], _downwind_twa_deg())
		var heading_deg: float = wind_deg - tack * twa
		var speed_ms: float = maxf(_speed_ratio * _polar_speed_ms(twa), 2.0)
		var inside_m: float = sailing_area.inside_m(position + Course.direction_of(heading_deg) * speed_ms * FREE_LEG_CHECK_S)
		if inside_m > best_inside_m:
			best_inside_m = inside_m
			best_twa = twa
		if inside_m >= FREE_EDGE_M:
			break
	_free_twa_deg = best_twa
	_free_leg_until_s = _time_s + _rng.randf_range(FREE_LEG_MIN_S, FREE_LEG_MAX_S)


## The heading to a target as _course_to() sails it, but on a beat or a run kept within
## FREE_CORRIDOR_M across the straight way from `from` to the target: once it is further out than
## that, on the side its course is taking it, it tacks or gybes.
func _course_within(telemetry: Telemetry, target: Vector2, from: Vector2) -> float:
	var heading_deg: float = _course_to(telemetry, target)
	var way: Vector2 = target - from
	if way.length() < 1.0 or not (note.begins_with("beat") or note.begins_with("run")):
		return heading_deg
	var side: Vector2 = way.normalized().orthogonal()
	var out_m: float = (_position(telemetry) - from).dot(side)
	var going: float = Course.direction_of(telemetry.heading_deg).dot(side)
	if absf(out_m) > FREE_CORRIDOR_M and signf(going) == signf(out_m):
		_ask_for_manoeuvre(true)
	return heading_deg


## Finished: on past the finish line to a point FINISH_CLEAR_M beyond its middle, clear of the boards
## still finishing; then free sailing (state_for()).
func _clear_of_finish_heading(telemetry: Telemetry) -> float:
	var position: Vector2 = _position(telemetry)
	var finish: RaceStep = _race.steps()[-1]
	if _finish_clear_point == Vector2.INF:
		_finish_clear_point = finish.target() + finish.in_dir * FINISH_CLEAR_M
	var past_m: float = RoundingCheck.over_line_m(position, finish.points[0], finish.points[1], finish.in_dir)
	if past_m >= 0.75 * FINISH_CLEAR_M or position.distance_to(_finish_clear_point) < 15.0:
		_clear_of_finish = true
	var heading_deg: float = _course_to(telemetry, _finish_clear_point)
	note = "finished: clear of the line"
	return heading_deg


## Notes when it started (crossed the start line) and whether it was over the line at the gun.
func _watch_the_start() -> void:
	if not _race.is_started():
		return
	if not is_nan(started_at_s):
		return
	if _race.next_step_index(_index) > 0:
		started_at_s = _race.splits_s(_index)[0]
	elif _race.clock_s() >= 0.0 and _race.is_ocs(_index):
		was_ocs = true


# ---------------------------------------------------------------- the start

## Rule 5, the timed start (AI_FLEET_PLAN.md, D4), from wherever the countdown finds the board. It
## crosses its spot on the line (its character's spot, pulled toward the favoured end) at the time it
## aims for (the gun plus its timing error), at speed. The time it has to spare (that time less the
## time it expects to need, by the navigation skill) is used up so:
##   - it sails to its waiting point: behind its spot along the way a board holding back sails
##     (slow, luffed up, slipping sideways), far enough back that holding back from there (slowing
##     down first) uses up the spare time: a long way in for a skipper who holds (start_style HOLD),
##     a short one for a skipper who loops (LOOP), who first sails its timing loop when it has more
##     time than that: away on a broad reach, a gybe back when the way back takes the time left;
##   - from there, or from wherever it meets the way in close enough to use up its time, it sails
##     in holding back (the hands' hold-back skill: the sheet eased to the speed that brings it to
##     the line on time, never less than its hold speed); when the time left is the time it needs
##     to get going and cross, it lets the sheet go back in and goes (bearing away first: a slow
##     board sails no closer to the wind than the bear-away angle until it has speed);
##   - near the line and about to cross it before the gun, it luffs right up, as slow as it steers.
## Going, it crosses where it would arrive on time: of the points of the line it can reach on its
## present tack, the first one it would not reach early; when it would be early everywhere, the one
## it reaches last. On the course side before the gun (over early, or past an end of the line) it
## goes back behind the line; over it at the gun (OCS) it goes back round the nearer end; then it
## starts again.
func _start_heading(telemetry: Telemetry, step: RaceStep) -> float:
	var position: Vector2 = _position(telemetry)
	var wind_deg: float = telemetry.wind_from_bearing_deg
	var spot: Vector2 = _start_spot(step)
	var forward: Vector2 = step.in_dir
	var run_in_tack: float = _start_run_in_tack(step, wind_deg)
	var holds: bool = config.start_style == SkipperConfig.StartStyle.HOLD
	var before_gun: bool = _race.clock_s() < 0.0
	# How far behind the line (or its extensions) it is, metres; negative over it.
	var behind_m: float = -RoundingCheck.over_line_m(position, step.points[0], step.points[1], forward)
	# The seconds until it wants to cross: the gun plus its timing error (after the gun it counts down
	# past zero, so a late starter goes at once), and what it has to spare: that, less the time it
	# needs to get to its spot.
	var aim_s: float = -_race.clock_s() + config.start_timing_error_s
	var spare_s: float = aim_s - _time_to_s(telemetry, spot)
	start_spare_s = spare_s
	# On the course side of the line or its extensions, and not started: over early (OCS at the gun),
	# or past an end of the line. A start counts only from behind the line.
	if behind_m < 0.0:
		_start_phase = StartPhase.BACK_BEHIND
	if _start_phase == StartPhase.BACK_BEHIND:
		if _race.is_ocs(_index) and _race.clock_s() >= 0.0:
			# Over the line at the gun: back round the nearer end, as the rules say.
			return _round_the_end_heading(telemetry, step)
		if behind_m < 0.0:
			var back_deg: float = _course_to(telemetry, _nearest_on_line(step, position) - forward * START_BACK_BEHIND_M)
			note = "start: back behind the line"
			return back_deg
		_start_phase = StartPhase.RUN_IN
		_round_end = -1
		_reached_hold = false
		_going = false
	# The way in. The go point is on the run in, START_HOLD_BEHIND_M behind the line: from there the
	# board gets going and crosses at speed. Before it, it holds back on the run-in tack at the wind
	# angle whose track runs most nearly along the line (HOLD_TWA_DEG to HOLD_WIDEST_TWA_DEG: on an
	# upwind start a reach along the line, on a reaching start luffed up), so that waiting brings it
	# no nearer the line than it must. The waiting point is back along that track from the go point
	# by the way it sails holding back for the time it has to spare (at most its longest hold), and
	# the way it needs to slow down from full speed first; inside the area.
	var run_in: Vector2 = _run_in_direction(step, wind_deg)
	var go_point: Vector2 = spot - run_in * (START_HOLD_BEHIND_M / maxf(run_in.dot(forward), 0.3))
	var hold_twa: float = _hold_twa_deg(wind_deg, run_in_tack, forward)
	var track: Vector2 = Course.direction_of(wind_deg - run_in_tack * (hold_twa + HOLD_LEEWAY_DEG))
	var expected_ms: float = _run_in_speed_ms(step, wind_deg)
	var hold_ms: float = minf(_hold_speed_ms(), expected_ms)
	var slowing_m: float = maxf(expected_ms * expected_ms - hold_ms * hold_ms, 0.0) / (2.0 * HOLD_DECEL_MS2)
	var wait_s: float = clampf(spare_s - START_GO_SPARE_S, 0.0, _longest_hold_s())
	# No longer than START_WAY_IN_MAX_M (and the slowing down): a long wait is held back slower on it,
	# down to as slow as the board steers, rather than sailed far out and back.
	var wait_at: Vector2 = _inside_area(go_point - track * (minf(hold_ms * wait_s, START_WAY_IN_MAX_M) + slowing_m))
	# The time the way in can use up when it is sailed from the waiting point, held back as slowly as
	# the board steers well.
	var slowest_ms: float = minf(_controller.hold_back_steerage_ms + 0.5, hold_ms)
	var at_wait_s: float = wait_at.distance_to(go_point) * maxf(1.0 / slowest_ms - 1.0 / expected_ms, 0.0)
	# The timing loop: with more time to spare than the way in can use up, by more than a loop
	# costs; one who loops (LOOP) has a short way in, one who holds (HOLD) a long one.
	if _start_phase == StartPhase.RUN_IN and before_gun and not _reached_hold and not holds:
		if spare_s - START_GO_SPARE_S > at_wait_s + START_LOOP_EXCESS_S:
			_start_phase = StartPhase.AWAY
	if _start_phase == StartPhase.AWAY:
		# The time it needs counts a turn (the way back is a reach on the other tack); a gybe from the
		# broad reach at speed costs START_GYBE_EXTRA_S more. It turns back with what the way in can
		# use up still to spare.
		if spare_s - START_GO_SPARE_S <= at_wait_s + START_LOOP_RETURN_S:
			_start_phase = StartPhase.TURNING
			_turn_back_from_s = _time_s
		else:
			note = "start: away"
			return _away_heading(telemetry, step)
	if _start_phase == StartPhase.TURNING:
		var turning: bool = _tack_due_s >= 0.0 or _controller.manoeuvre != PlayerController.Manoeuvre.NONE
		if turning or _manoeuvre_ended_s <= _turn_back_from_s:
			# Held back through the turn too (bearing away for the gybe it would otherwise run off).
			_hands.hold_speed_ms = LOOP_AWAY_SPEED_MS
			note = "start: turning back"
			return _last_wanted_deg if turning else _gybe_now(telemetry)
	_start_phase = StartPhase.RUN_IN
	# On the way in: near the stretch from the waiting point to the go point, behind the line, with
	# enough of it ahead to hold back for the time it has to spare (else on to the waiting point).
	var on_way: Vector2 = Geometry2D.get_closest_point_to_segment(position, wait_at, go_point)
	var way_left_m: float = on_way.distance_to(go_point)
	var can_use_s: float = way_left_m * maxf(1.0 / hold_ms - 1.0 / expected_ms, 0.0)
	var at_waiting_point: bool = position.distance_to(wait_at) <= START_HOLD_REACHED_M
	# (Met on the way out to the waiting point, sailing the other way at speed, it does not count: it
	# would carry on far past it while slowing down.)
	var along_way: bool = _velocity.dot(track) > 0.3 * maxf(_velocity.length(), 0.1)
	if not _reached_hold and position.distance_to(on_way) <= START_HOLD_REACHED_M and behind_m > 0.0 \
			and (at_waiting_point or (along_way and spare_s - START_GO_SPARE_S <= can_use_s + START_HOLD_TOLERANCE_S)):
		_reached_hold = true
		_going = false
	if not _reached_hold:
		var free_deg: float
		if before_gun and spare_s > START_GO_SPARE_S:
			# To the waiting point by the navigation skill: the fewest manoeuvres.
			free_deg = _course_to(telemetry, wait_at, 0.0, true)
			note = "start: to the waiting point (%s)" % note
			# Out to it the other way along the way in (it will turn there): held back near it, so that
			# it does not run far past it while turning.
			if _velocity.dot(track) < 0.0 and position.distance_to(wait_at) < START_SLOW_FOR_TURN_M:
				_hands.hold_speed_ms = LOOP_AWAY_SPEED_MS
		else:
			# Late: straight for its spot.
			free_deg = _course_to(telemetry, _through(position, spot), 0.0, true)
			note = "start: for the spot"
		if before_gun:
			_keep_behind_the_line(telemetry, step, behind_m)
			if spare_s <= START_GO_SPARE_S and _too_early_at_the_line(telemetry, step, behind_m):
				# Late for its spot but about to cross the line elsewhere before the gun.
				_hands.hold_speed_ms = _controller.hold_back_steerage_ms
				note += ", holding back hard, early at the line"
		return free_deg
	# Where it will cross: its spot, when that is a reach on this tack (it came in on the way to it);
	# else where on the line it would arrive on time.
	# (Reachable at the angle it points once it has speed: a slow board's own angle is wider.)
	var spot_twa: float = Navigation.wind_angle_deg(position, spot, wind_deg)
	var cross_at: Vector2 = spot
	var at_speed_track_deg: float = config.upwind_vmg_twa_deg + config.pointing_offset_deg + _leeway_deg
	if signf(spot_twa) != _tack() or absf(spot_twa) < at_speed_track_deg:
		cross_at = _choose_crossing(telemetry, step, aim_s)
	elif absf(spot_twa) > START_GO_SHALLOWEST_TWA_DEG:
		# Far along the line from its spot: a run in that shallow would slide along the line and,
		# pushed off by its leeway and the boards it keeps clear of, come too close to it to lay any
		# point of it. It crosses where a run in at START_GO_TWA_DEG meets the line instead.
		cross_at = _crossing_at_angle(step, position, wind_deg, START_GO_TWA_DEG + _leeway_deg)
		_crossing_on_this_tack = true
		if cross_at == Vector2.INF:
			cross_at = spot
	else:
		_crossing_on_this_tack = true
	# Holding back until the time left is the time it needs to get going and cross there (worked out
	# from its speed now and how fast it gains speed): then it goes, so as to cross at the time it
	# aims for (HOLD_GO_SPARE_S). Past the go point, or about to cross the line before the gun, it
	# holds back as slow as it steers.
	var go_spare_s: float = aim_s - _time_to_cross_s(telemetry, cross_at)
	start_spare_s = go_spare_s
	var early_at_line: bool = before_gun and _too_early_at_the_line(telemetry, step, behind_m)
	# Once it has gone near the line it keeps going (its spare time jumps about as it gains speed),
	# unless it is about to cross early; further back it may still change its mind. It does not go
	# while it is nearly stopped (just turned, say: from a crawl the time it needs is guessed long)
	# unless it is late by more than START_STALLED_GO_S.
	var stalled: bool = telemetry.speed_ms < _controller.hold_back_steerage_ms + 0.5 and go_spare_s > -START_STALLED_GO_S
	if (go_spare_s <= HOLD_GO_SPARE_S and not stalled) or not before_gun:
		_going = true
	elif behind_m > START_GO_LATCH_M and go_spare_s > START_GO_HYSTERESIS_S:
		_going = false
	if before_gun and (not _going or early_at_line):
		if _tack() != run_in_tack:
			# On the other tack (it has just come to its waiting point, say): it turns onto the run-in
			# tack first, keeping its speed for the turn.
			note = "start: turning onto the way in (%+.1f s to spare)" % go_spare_s
			# Held back to LOOP_AWAY_SPEED_MS meanwhile: bearing away for a gybe in a strong wind, a board
			# runs off far before the gybe begins.
			_hands.hold_speed_ms = LOOP_AWAY_SPEED_MS
			if absf(telemetry.twa_deg) < 90.0:
				_ask_for_manoeuvre(true)
				return wind_deg - _tack() * absf(telemetry.twa_deg)
			return _gybe_now(telemetry)
		# No faster than its hold speed, and slower (down to as slow as it steers) when what is left
		# of the way to the go point is short for the time it has to spare.
		var to_go_point_m: float = (go_point - position).dot(track)
		var past_go_point: bool = to_go_point_m < 0.0
		_hands.hold_speed_ms = clampf(to_go_point_m / maxf(go_spare_s, 0.5), _controller.hold_back_steerage_ms, config.hold_speed_ms)
		note = "start: holding back (%+.1f s to spare)" % go_spare_s
		if past_go_point or early_at_line:
			_hands.hold_speed_ms = _controller.hold_back_steerage_ms
			note = "start: holding back hard, early (%+.1f s to spare)" % go_spare_s
		var hold_deg: float = _hold_heading(telemetry, hold_twa, run_in_tack, on_way + track * HOLD_CARROT_M)
		_keep_behind_the_line(telemetry, step, behind_m)
		return hold_deg
	_going_from_hold = true
	var go_deg: float = _course_to(telemetry, _through(position, cross_at))
	note = "start: go"
	if not _crossing_on_this_tack:
		# No point of the line can be reached on this tack: near the line, sailing on to the
		# layline would take it past the end of the line. It tacks (or gybes) now.
		_ask_for_manoeuvre(true)
		note += ", the line is on the other tack"
	elif before_gun:
		_keep_behind_the_line(telemetry, step, behind_m)
	return go_deg


## The speed it holds back to, m/s: its character's hold speed, or what it has found it gets down to
## in this wind if that is faster.
func _hold_speed_ms() -> float:
	return maxf(config.hold_speed_ms, _held_ms)


## The longest it plans to hold back on its way in, seconds (HOLD_LONGEST_S).
func _longest_hold_s() -> float:
	return HOLD_LONGEST_S


## Near the line: how long it needs to sail straight to a point on its present tack, seconds, from
## its speed now, gaining speed at _acceleration_ms2() up to the speed it expects there, plus the time
## to turn onto the course. (_time_to_s() counts a whole loss for the speed it lacks, which is right
## far from the line but too much over the last few metres, where a slow board is nearly there.)
func _time_to_cross_s(telemetry: Telemetry, target: Vector2) -> float:
	var position: Vector2 = _position(telemetry)
	var needed_twa: float = Navigation.wind_angle_deg(position, target, telemetry.wind_from_bearing_deg)
	var sail_deg: float = clampf(absf(needed_twa) - _leeway_deg, _pointing_twa_deg(), _downwind_twa_deg())
	if signf(needed_twa) != _tack() or absf(needed_twa) - _leeway_deg < _pointing_twa_deg():
		return _time_to_s(telemetry, target)
	var distance_m: float = position.distance_to(target)
	var expected_ms: float = maxf(_speed_ratio * _polar_speed_ms(sail_deg), 1.0)
	var speed_ms: float = clampf(telemetry.speed_ms, 0.5, expected_ms)
	var gain_ms2: float = _acceleration_ms2()
	var gaining_s: float = (expected_ms - speed_ms) / gain_ms2
	var gaining_m: float = speed_ms * gaining_s + 0.5 * gain_ms2 * gaining_s * gaining_s
	var takes_s: float
	if distance_m <= gaining_m:
		takes_s = (sqrt(speed_ms * speed_ms + 2.0 * gain_ms2 * distance_m) - speed_ms) / gain_ms2
	else:
		takes_s = gaining_s + (distance_m - gaining_m) / expected_ms
	# (No time for the turn onto the course: from a hold the board bears away as it gains speed.)
	return takes_s


## How fast the board gains speed when it sheets in from a hold, m/s2, in the wind of the moment:
## measured on the open water's sea from 2.5 to 6 m/s, 5.5 s at 12 kt, 2.4 s at 18, 2 s at 24.
func _acceleration_ms2() -> float:
	return clampf(lerpf(0.65, 1.45, (_sim.telemetry.tws_10m_kt - 12.0) / 6.0), 0.65, 1.75)


## True when the board, at the speed it has toward the start line, would cross it within
## START_GUARD_S, START_GUARD_MARGIN_S or more before the gun.
func _too_early_at_the_line(telemetry: Telemetry, step: RaceStep, behind_m: float) -> bool:
	var toward_ms: float = Course.direction_of(telemetry.heading_deg).dot(step.in_dir) * telemetry.speed_ms
	if toward_ms <= 0.3:
		return false
	var crossing_in_s: float = behind_m / toward_ms
	if crossing_in_s >= START_GUARD_S or crossing_in_s >= -_race.clock_s() + START_GUARD_MARGIN_S:
		return false
	# Only a crossing of the line itself: the extension past an end is _keep_behind_the_line()'s.
	var crossing: Vector2 = _position(telemetry) + Course.direction_of(telemetry.heading_deg) * telemetry.speed_ms * crossing_in_s
	return _off_the_ends_m(step, crossing) <= START_WALL_ENDS_M


## Before the gun, out past an end of the start line: the line's extension is a wall (over it, the
## board is on the course side and must come back; at the gun it is OCS). Within START_WALL_M of it
## and sailing toward it, the board tacks or gybes away (beating up behind the line to the boat
## end, it tacks off the extension).
func _keep_behind_the_line(telemetry: Telemetry, step: RaceStep, behind_m: float) -> void:
	if behind_m > START_WALL_M or _off_the_ends_m(step, _position(telemetry)) <= START_WALL_ENDS_M:
		return
	var heading: Vector2 = Course.direction_of(telemetry.heading_deg)
	var toward: float = heading.dot(step.in_dir)
	if toward <= 0.2:
		return
	# Heading for the line itself (it will cross between the ends): no wall.
	var crossing: Vector2 = _position(telemetry) + heading * behind_m / toward
	if _off_the_ends_m(step, crossing) <= START_WALL_ENDS_M:
		return
	_ask_for_manoeuvre(true)
	note += ", off the line's extension"


## The speed it expects on its run in, m/s (its polar at the run-in's wind angle, times what it has
## measured against the polar).
func _run_in_speed_ms(step: RaceStep, wind_deg: float) -> float:
	var run_in_twa: float = absf(Navigation.wind_angle_deg(Vector2.ZERO, _run_in_direction(step, wind_deg), wind_deg))
	return maxf(_speed_ratio * _polar_speed_ms(run_in_twa), 3.0)


## The wind angle it holds back at on a tack, degrees: of HOLD_TWA_DEG to HOLD_WIDEST_TWA_DEG (in 5
## degree steps), the one whose track (HOLD_LEEWAY_DEG further off the wind than the bow) runs most
## nearly along the start line, whose direction across is `forward`: on a line square to the wind a
## reach along it, on a line along the wind (a reaching start) as close to the wind as it holds.
static func _hold_twa_deg(wind_deg: float, tack: float, forward: Vector2) -> float:
	# Its track at least HOLD_TRACK_MIN_TWA_DEG off the wind, and of those the track least toward
	# the wind counts as more along the line: the waiting point lies back along the track, and a
	# track up toward the wind puts it downwind of the line (on a reaching start out past the
	# downwind end, from where the line is a beat that runs into its extension).
	var up: Vector2 = Course.direction_of(wind_deg)
	var first_twa: float = maxf(HOLD_TWA_DEG, HOLD_TRACK_MIN_TWA_DEG - HOLD_LEEWAY_DEG)
	var best_twa: float = first_twa
	var best_score: float = INF
	var twa: float = first_twa
	while twa <= HOLD_WIDEST_TWA_DEG + 0.01:
		var track: Vector2 = Course.direction_of(wind_deg - tack * (twa + HOLD_LEEWAY_DEG))
		var score: float = absf(track.dot(forward)) + 0.5 * maxf(track.dot(up), 0.0)
		if score < best_score - 0.01:
			best_score = score
			best_twa = twa
		twa += 5.0
	return best_twa


## The heading of a board holding back on the run-in tack: for a point `ahead` on its way in (so
## that it keeps to the way in, at its distance behind the line), at a wind angle between
## HOLD_TWA_DEG and HOLD_WIDEST_TWA_DEG, or at the hold's own wind angle when the point is not on a
## reach on this tack. Still faster than its hold speed with the sheet eased (a strong wind on a
## reach), it luffs up too, HOLD_LUFF_DEG_PER_MS for each m/s too fast, no closer than
## HOLD_LUFF_TWA_DEG. On the other tack it tacks or gybes onto the run-in tack.
func _hold_heading(telemetry: Telemetry, hold_twa: float, run_in_tack: float, ahead: Vector2) -> float:
	var tack: float = _tack()
	var needed_twa: float = Navigation.wind_angle_deg(_position(telemetry), ahead, telemetry.wind_from_bearing_deg)
	var twa_deg: float = hold_twa
	if signf(needed_twa) == tack:
		twa_deg = clampf(absf(needed_twa) - HOLD_LEEWAY_DEG, HOLD_TWA_DEG, HOLD_WIDEST_TWA_DEG)
	# A noisy helm holds further off the wind, by twice its wobble: luffed up at a crawl, a wobble
	# toward the wind puts the board in irons.
	twa_deg = maxf(twa_deg, HOLD_TWA_DEG + 2.0 * config.steering_noise_deg)
	if tack != run_in_tack:
		_ask_for_manoeuvre(true)
	# (Only after HOLD_LUFF_AFTER_S of holding back: slowing down from full speed takes a while, and
	# luffing at speed on an upwind start points the board at the line.)
	var too_fast_ms: float = telemetry.speed_ms - config.hold_speed_ms - 0.5
	var holding_s: float = _time_s - _holding_since_s if _holding_since_s >= 0.0 else 0.0
	if too_fast_ms > 0.0 and holding_s > HOLD_LUFF_AFTER_S:
		twa_deg = maxf(twa_deg - minf(too_fast_ms * HOLD_LUFF_DEG_PER_MS, HOLD_LUFF_MOST_DEG), minf(twa_deg, HOLD_LUFF_TWA_DEG))
	elif telemetry.speed_ms < _controller.hold_back_steerage_ms + 0.5:
		# Too slow to steer well: bear away to get the board moving again.
		twa_deg += HOLD_BEAR_AWAY_DEG
	return telemetry.wind_from_bearing_deg - tack * twa_deg + _keep_clear_deg(telemetry, tack)


## Where a track at a wind angle on the present tack (degrees, the leeway included) from a position
## meets the start line, kept a few metres in from the ends; Vector2.INF when it does not meet it
## ahead.
func _crossing_at_angle(step: RaceStep, position: Vector2, wind_deg: float, track_twa_deg: float) -> Vector2:
	var track: Vector2 = Course.direction_of(wind_deg - _tack() * track_twa_deg)
	var toward: float = track.dot(step.in_dir)
	var behind_m: float = -RoundingCheck.over_line_m(position, step.points[0], step.points[1], step.in_dir)
	if toward <= 0.05 or behind_m <= 0.0:
		return Vector2.INF
	var meets: Vector2 = position + track * (behind_m / toward)
	var inset: float = _line_inset(step)
	return step.points[1].lerp(step.points[0], clampf(_share_along_line(step, meets), inset, 1.0 - inset))


## A point moved inside the sailing area, at least 10 m from its sides.
func _inside_area(point: Vector2) -> Vector2:
	var here: Vector2 = sailing_area.local(point)
	var across_m: float = maxf(sailing_area.half_across_m - 10.0, 0.0)
	var up_m: float = maxf(sailing_area.half_up_m - 10.0, 0.0)
	return sailing_area.point_at(clampf(here.x, -across_m, across_m), clampf(here.y, -up_m, up_m))


## How far out past the nearer end of the start line a point is, along the line, metres: 0 between
## the ends.
static func _off_the_ends_m(step: RaceStep, point: Vector2) -> float:
	var length_m: float = step.points[0].distance_to(step.points[1])
	var share: float = _share_along_line(step, point)
	return maxf(maxf(-share, share - 1.0), 0.0) * length_m


## Over the line at the gun (OCS): back round the nearer end of the line, as the rules say. First out
## past that end on the course side (START_ROUND_END_M beyond it), then down behind the line beyond
## it; behind the line (the race clears it then) it starts again with the run in.
func _round_the_end_heading(telemetry: Telemetry, step: RaceStep) -> float:
	var position: Vector2 = _position(telemetry)
	if _round_end < 0:
		_round_end = 1 if _share_along_line(step, position) >= 0.5 else 0
		_past_the_end = false
	var end: Vector2 = step.points[0] if _round_end == 1 else step.points[1]
	var other: Vector2 = step.points[1] if _round_end == 1 else step.points[0]
	var outward: Vector2 = (end - other).normalized()
	var forward: Vector2 = step.in_dir
	if not _past_the_end and _off_the_ends_m(step, position) >= START_ROUND_END_M * 0.7 and (position - end).dot(outward) > 0.0:
		_past_the_end = true
	var target: Vector2 = end + outward * START_ROUND_END_M + forward * START_ROUND_END_M
	if _past_the_end:
		target = end + outward * START_ROUND_END_M - forward * START_BACK_BEHIND_M
	var heading_deg: float = _course_to(telemetry, target)
	note = "start: OCS, round the end and back" if _past_the_end else "start: OCS, out past the end"
	return heading_deg


## The point of the start line it makes for near the line, aiming to cross at aim_s from now: of
## the points it can reach on a reach on its present tack (no tack, no beat), the one it would reach
## soonest without being early; when it would be early at every one of them, the one it reaches
## last; with none on this tack, the nearest point of the line (on the other tack, or a beat).
func _choose_crossing(telemetry: Telemetry, step: RaceStep, aim_s: float) -> Vector2:
	var position: Vector2 = _position(telemetry)
	var wind_deg: float = telemetry.wind_from_bearing_deg
	var tack: float = _tack()
	var up_track_deg: float = _pointing_twa_deg() + _leeway_deg
	var inset: float = _line_inset(step)
	_crossing_on_this_tack = true
	var on_other_tack: bool = false
	var on_time: Vector2 = Vector2.INF
	var on_time_s: float = INF
	var latest: Vector2 = Vector2.INF
	var latest_s: float = -INF
	for i: int in START_CROSSING_SAMPLES:
		var point: Vector2 = step.points[1].lerp(step.points[0], lerpf(inset, 1.0 - inset, float(i) / (START_CROSSING_SAMPLES - 1)))
		var needed_twa: float = wrapf(wind_deg - Course.bearing_deg(position, point), -180.0, 180.0)
		if absf(needed_twa) < up_track_deg:
			continue  # a beat: neither tack reaches it straight
		if signf(needed_twa) != tack:
			on_other_tack = true
			continue
		var need_s: float = _time_to_cross_s(telemetry, point)
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
	# None on this tack. If the other tack reaches the line, the line needs the other tack (said by
	# _crossing_on_this_tack); if neither does, it is a beat, sailed as any beat is.
	_crossing_on_this_tack = not on_other_tack
	return _nearest_on_line(step, position)


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


## The tack of the run in, chosen once (at the countdown's first look): on a reaching start the first
## leg's tack; otherwise the tack whose way in to the spot comes from the board's side of it (its
## waiting point lies back along that tack's run in, toward where the board is), so that it does not
## cross the fleet's way in to get there. A tack on which the close reach would not cross the line is
## not chosen.
func _start_run_in_tack(step: RaceStep, wind_deg: float) -> float:
	if _run_in_tack != 0.0:
		return _run_in_tack
	var first_twa: float = wrapf(wind_deg - _first_leg_deg(step), -180.0, 180.0)
	if absf(first_twa) >= START_RUN_IN_TWA_DEG and absf(first_twa) <= config.downwind_vmg_twa_deg:
		_run_in_tack = signf(first_twa)
	else:
		var from_spot: Vector2 = _position(_sim.telemetry) - _start_spot(step)
		var on_starboard: float = from_spot.dot(Course.direction_of(wind_deg - START_RUN_IN_TWA_DEG))
		var on_port: float = from_spot.dot(Course.direction_of(wind_deg + START_RUN_IN_TWA_DEG))
		_run_in_tack = 1.0 if on_starboard <= on_port else -1.0
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
	# Held back to LOOP_AWAY_SPEED_MS: a loop sailed at full speed in a strong wind went far out of the
	# area, and its gybe back at 13 m/s took 12 s to begin.
	_hands.hold_speed_ms = LOOP_AWAY_SPEED_MS
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
## onto its course and to gain the speed it still lacks. The way is the navigation skill's
## (Navigation.route()): straight on a reach or a run; a point beyond the polar's angles in two
## legs, on this tack and the other, with a tack or gybe between them unless one of the legs is
## short; START_TURN_S for each tack or gybe.
func _time_to_s(telemetry: Telemetry, target: Vector2) -> float:
	var position: Vector2 = _position(telemetry)
	var wind_deg: float = telemetry.wind_from_bearing_deg
	var needed_twa: float = Navigation.wind_angle_deg(position, target, wind_deg)
	var up_deg: float = _pointing_twa_deg()
	var down_deg: float = _downwind_twa_deg()
	var sail_deg: float = clampf(absf(needed_twa) - _leeway_deg, up_deg, down_deg)
	var speed_ms: float = maxf(_speed_ratio * _polar_speed_ms(sail_deg), 1.0)
	var gaining_s: float = maxf(speed_ms - telemetry.speed_ms, 0.0) / (2.0 * ACCELERATION_MS2)
	var way: Navigation.Route = Navigation.route(position, target, wind_deg, _tack(), up_deg + _leeway_deg, down_deg + _leeway_deg)
	var turn_s: float = START_TURN_S * way.manoeuvres
	if not way.turn_first:
		# Onto the first leg's course on this tack (the beat, the run or the reach) first.
		turn_s += _turn_time_s(telemetry, sail_deg)
	return way.distance_m() / speed_ms + gaining_s + turn_s


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
		if telemetry.speed_ms > GENTLE_HEAD_UP_FROM_MS:
			rate_dps = minf(rate_dps, GENTLE_HEAD_UP_STICK * _controller.turn_rate_dps)
	# A big turn (coming back from off the line, say) loses most of its time.
	var lost: float = 0.5 if absf(turn_deg) < 30.0 else 0.8
	return lost * absf(turn_deg) / rate_dps


## The polar's speed at a wind angle (degrees, either tack) in the wind the board sails in now, m/s:
## between the table's angles and between its winds (below 12 kt the 12 kt row, above 24 kt the
## 24 kt row). It reads its own copies of the tables (_polar_winds and the others), not the
## constants every skipper shares: skippers sailed side by side on threads slowed each other down
## reading shared data.
func _polar_speed_ms(twa_deg: float) -> float:
	var winds: int = _polar_winds.size()
	var kt: float = clampf(_sim.telemetry.tws_10m_kt, _polar_winds[0], _polar_winds[winds - 1])
	var row: int = 0
	while row < winds - 2 and kt > _polar_winds[row + 1]:
		row += 1
	var share: float = (kt - _polar_winds[row]) / (_polar_winds[row + 1] - _polar_winds[row])
	return lerpf(_polar_row_speed_ms(row, twa_deg), _polar_row_speed_ms(row + 1, twa_deg), share)


## The speed at a wind angle in one wind's row of the polar, m/s, between the table's angles.
func _polar_row_speed_ms(row: int, twa_deg: float) -> float:
	var angles: int = _polar_twa.size()
	var base: int = row * angles
	var angle: float = clampf(absf(twa_deg), _polar_twa[0], _polar_twa[angles - 1])
	for i: int in range(1, angles):
		if angle <= _polar_twa[i]:
			var share: float = (angle - _polar_twa[i - 1]) / (_polar_twa[i] - _polar_twa[i - 1])
			return lerpf(_polar_speeds[base + i - 1], _polar_speeds[base + i], share)
	return _polar_speeds[base + angles - 1]


# ---------------------------------------------------------------- the hands

## Rule 8: the heading decided reaction_time_s ago (the first one until then).
func _after_reaction() -> float:
	while _delay_times.size() > 1 and _delay_times[1] <= _time_s - config.reaction_time_s:
		_delay_times.remove_at(0)
		_delay_headings.remove_at(0)
	return _delay_headings[0] if not _delay_headings.is_empty() else _last_wanted_deg


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
	# At speed the helm is held still for small errors and the controller's own heading hold does
	# the steadying (busy corrections at 14 m/s in 24 kt went with catapults on broad reaches).
	var dead_band_deg: float = STEER_DEAD_BAND_FAST_DEG if telemetry.speed_ms > GENTLE_HEAD_UP_FROM_MS else STEER_DEAD_BAND_DEG
	if absf(error_deg) < dead_band_deg:
		return
	var stick_limit: float = 1.0
	# Heading up turns right on starboard tack and left on port tack. At speed a sailor heads up
	# gently, so the sheet keeps up with the growing pull (heading up from a broad reach at 13 m/s
	# in 24 kt with the controller's full head-up rate pulled the sailor over the front).
	if signf(error_deg) == _tack() and telemetry.speed_ms > GENTLE_HEAD_UP_FROM_MS:
		stick_limit = GENTLE_HEAD_UP_STICK
	_hands.steer = clampf(error_deg / FULL_STICK_ERROR_DEG, -stick_limit, stick_limit)


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
			# Before the start a board that came out of a turn slow first gets going on a reach before
			# it points (heading up to the close reach at 4 m/s after a gybe stopped it dead).
			if state == State.PRE_START and telemetry.speed_ms < _controller.auto_sheet_pilot.pointing_speed_ms:
				_pointing = false
		_last_manoeuvre = now


## Its own measurements: the speed (for pointing), the leeway and the speed against the polar
## (smoothed, only while sailing steadily), its velocity over the ground, and the mean wind.
func _measure(telemetry: Telemetry, dt: float) -> void:
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
	# The leeway is measured whenever the board sails steadily with some speed: in light wind a beat
	# is slower than the pointing speed, and its leeway (8 degrees and more) is what the laylines need.
	# (Not while holding back: a board slipping sideways at a crawl says nothing of its leeway at speed.)
	if steady and telemetry.speed_ms > MEASURE_LEEWAY_FROM_MS and _hands.hold_speed_ms <= 0.0:
		_leeway_deg = lerpf(_leeway_deg, clampf(absf(telemetry.leeway_deg), 0.0, 12.0), share)
	# The speed against the polar, where the polar has the board planing (its slow rows, a board
	# that did not plane from rest, say little about a board that came in planing).
	var polar_ms: float = _polar_speed_ms(telemetry.twa_deg)
	if steady and telemetry.speed_ms > pilot.pointing_speed_ms and absf(telemetry.twa_deg) >= 40.0 and polar_ms > 4.0:
		_speed_ratio = lerpf(_speed_ratio, clampf(telemetry.speed_ms / polar_ms, 0.5, 2.0), share)
	# Downwind feel: off the plane below OFF_PLANE_MS, planing again above ON_PLANE_MS.
	if absf(telemetry.twa_deg) > 110.0 and telemetry.speed_ms < OFF_PLANE_MS:
		_off_plane = true
	elif telemetry.speed_ms > ON_PLANE_MS:
		_off_plane = false
	# How slow holding back really gets it, after 3 s of holding back (smoothed over 3 s).
	if _hands.hold_speed_ms > 0.0 and _controller.manoeuvre == PlayerController.Manoeuvre.NONE:
		if _holding_since_s < 0.0:
			_holding_since_s = _time_s
		elif _time_s - _holding_since_s > 3.0:
			_held_ms = lerpf(_held_ms if _held_ms > 0.0 else telemetry.speed_ms, telemetry.speed_ms, share)
	else:
		_holding_since_s = -1.0
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
	_others_time_s = _time_s
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
