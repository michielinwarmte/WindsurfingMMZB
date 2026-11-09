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
##   5. The start: a timed run (see _start_heading()); on a slalom a broad reach down onto the line
##      from upwind of the committee boat (_slalom_start_heading()).
##   6. Keep clear: another board within KEEP_CLEAR_M and closing makes it bear away a little; with
##      the racing rules (RaceRules, F3) only when it is the one that must keep clear (port of
##      starboard, windward of leeward, astern of ahead, outside at the mark); a right-of-way board
##      holds its course. A penalty from the judge (it touched a board it had to keep clear of) is
##      taken at once: a full turn, a tack and a gybe (_penalty_turn_heading()).
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
## A board whose own way in to a reach's mark is within this of a beat (the polar's beat and the leeway)
## comes in as on a beat: on the tack it can round from (_decide()), degrees.
const BEAT_IN_MARGIN_DEG: float = 5.0
## Within this of a mark's entry point on the tack it must arrive on, and still more than FETCH_SAG_DEG
## inside the angle it can lay, the board tacks: it would pass the mark on the wrong side (metres, degrees).
const FETCH_CHECK_M: float = 80.0
const FETCH_SAG_DEG: float = 3.0
## How far past dead downwind the bow may swing going round a mark on the tack it came in on (the leg out
## being a run), degrees (_approach_tack()).
const DOWNWIND_SWING_DEG: float = 20.0
const APPROACH_ROOM_S: float = 6.0
## Rule 6: another board within the sheet's keep_clear_m and getting closer makes it bear away this
## much, degrees.
const KEEP_CLEAR_BEAR_AWAY_DEG: float = 15.0
## How it keeps clear depends on the rule (the skipper's heads, 8 November 2026: 17 of 22 penalties in the
## start rounds on Silvaplana were the windward board's, because keeping clear always bore away, which
## turns a windward board onto the leeward one): the windward board heads up this much, no closer to the
## wind than KEEP_CLEAR_CLOSEST_TWA_DEG (pinching slows it too); a board clear astern (or outside at a mark)
## turns KEEP_CLEAR_SIDE_DEG away from the side the other board is on; port still bears away behind
## starboard, degrees.
const KEEP_CLEAR_HEAD_UP_DEG: float = 15.0
const KEEP_CLEAR_CLOSEST_TWA_DEG: float = 38.0
const KEEP_CLEAR_SIDE_DEG: float = 12.0
## Keeping clear by passing (_passing_heading_deg()): headings tried every PASS_STEP_DEG up to PASS_STEPS
## steps either way, no deeper than PASS_DEEPEST_TWA_DEG; room wanted PASS_CLEAR_M over the next PASS_LOOK_S;
## its own speed taken as at least PASS_MIN_SPEED_MS.
const PASS_STEP_DEG: float = 5.0
const PASS_STEPS: int = 8
const PASS_DEEPEST_TWA_DEG: float = 160.0
const PASS_CLEAR_M: float = 12.0
const PASS_LOOK_S: float = 6.0
const PASS_MIN_SPEED_MS: float = 3.0
## Looking ahead (_look_ahead_keep_clear(), SkipperConfig.keep_clear_by_passing): a board further than
## PASS_LOOK_S of both boards' speeds (the other taken as fast as PASS_OTHER_MAX_MS) is not looked at; a turn
## onto a heading with less than PASS_SHORE_M of open water ahead is not made, metres.
const PASS_OTHER_MAX_MS: float = 15.0
const PASS_SHORE_M: float = 60.0
## With SkipperConfig.pass_slow_down, when no heading passes with the full room: the smallest turn that still
## passes PASS_MIN_ROOM_M (rather than the widest, a 45-degree bear-away that met the next board), and the sail
## eased to PASS_SLOW_SHARE of its speed (never under PASS_SLOW_MIN_MS), as a sailor keeps clear by slowing.
const PASS_MIN_ROOM_M: float = 5.0
const PASS_SLOW_SHARE: float = 0.6
const PASS_SLOW_MIN_MS: float = 3.0
## The Shift carve (AiHands.sharp; Max, 8 November 2026: "the heads can also Shift steer for faster
## steering"): while keeping clear with this much or more still to turn, degrees (SkipperConfig.keep_clear_sharp).
const SHARP_ERROR_DEG: float = 8.0
## Shift only this fast and faster, m/s: two boards at 2 m/s heading up with it to keep clear fell off (the start
## rounds, 8 November 2026); a carve wants speed.
const SHARP_FROM_MS: float = 5.0
## With SkipperConfig.turn_sharp, any turn with this much or more still to go, degrees.
const SHARP_TURN_DEG: float = 20.0
## Tacking into traffic (SkipperConfig.tack_traffic_check): a tack or gybe onto port with a starboard board
## that would pass within PASS_CLEAR_M over the next PASS_LOOK_S (this board on the new tack's course, after a
## tack at TRAFFIC_TACK_SPEED_MS) waits, up to TRAFFIC_WAIT_MAX_S; a wait that has not been needed for
## TRAFFIC_FORGET_S starts afresh.
const TRAFFIC_TACK_SPEED_MS: float = 3.0
const TRAFFIC_WAIT_MAX_S: float = 6.0
const TRAFFIC_FORGET_S: float = 2.0
## The best upwind and downwind angles of POLAR_15KT.md (45 and 135 degrees), which the character
## sheets' angles are measured from: a sheet's difference from them moves the polar's best angle in
## every wind (see _pointing_twa_deg() and _downwind_twa_deg()).
const POLAR_15KT_UPWIND_TWA_DEG: float = 45.0
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
## SkipperConfig.crawl_no_head_up_ms: once crawling it lets the board gather speed until it is this much faster than
## that, m/s (so that heading up again, which costs speed, does not drop it straight back into the crawl).
const CRAWL_RELEASE_EXTRA_MS: float = 1.5
## ... and it counts as stuck in the crawl only while the stick asks to head up by more than this, degrees.
const CRAWL_ERROR_DEG: float = 10.0
## The steering noise wanders on about this time scale, seconds: a slow wobble, not a shake.
const NOISE_TIME_S: float = 4.0
## Racing toward a mark, it lets go of the push slider when the mark is this many seconds away at its
## speed (see _push_level()): it rounds at the pilot's own margin.
const PUSH_EASE_BEFORE_MARK_S: float = 4.0
## Closer to the wind than this, degrees, a character's push offset is not used: upwind the hands
## leave the slider to the pilot's own margin, which is the fastest and the safest there. Pushed
## upwind the polar gains at most 1 % at 18 kt and loses 1 to 4 % at 24 kt (skipper_speed.md); in
## the personas' races at 24 kt 22 of 23 falls were on the beat, nearly all of them the pushers'
## (characters.md).
const PUSH_UPWIND_TWA_DEG: float = 60.0
## While its heading is this far from the one it wants, degrees, a character's push offset is not
## used: it is turning onto a new course (the bear-away from the beat onto the run after a mark,
## where the step has already moved on). Alone on T1 at 24 kt the six falls left after the upwind
## rule were all pushers', all in that bear-away (122 to 139 degrees off the wind; characters.md).
const PUSH_TURN_DEG: float = 15.0
## How fast its hand moves the push slider, a share of the slider per second: as fast as the player's
## keys move it (PlayerController.push_rate_per_s, the whole slider in 2.5 s). Set at once, the jump
## from 95 % back to the pilot's own margin as the board bore away at 14 m/s threw the sailor over
## the front.
const PUSH_RATE_PER_S: float = 0.4
## The head thinks this often, seconds (AI_FLEET_PLAN.md, D1: 1 or 2 Hz); the hands every tick.
const THINK_INTERVAL_S: float = 0.5
## A tack or gybe asked for this soon after the last one ended is not asked for: the board needs
## time to get going again.
const MIN_TACK_INTERVAL_S: float = 8.0
## The shore (_keep_off_the_shore()): how far ahead it looks, as seconds of sailing at its speed, and
## at least and at most (metres); between these wind angles a board is reaching (it turns away rather
## than tacks or gybes); how far it tries turning at a time, degrees.
const SHORE_LOOK_S: float = 14.0
const SHORE_LOOK_MIN_M: float = 70.0
const SHORE_LOOK_MAX_M: float = 160.0
const SHORE_REACH_FROM_DEG: float = 70.0
const SHORE_REACH_TO_DEG: float = 125.0
const SHORE_TURN_STEP_DEG: float = 10.0
## With less open water ahead than this (metres) the board is at the edge already: it heads for the
## most open water near it (_escape_the_shore()).
const SHORE_ESCAPE_M: float = 25.0
## On a leg sailed with tacks or gybes (a beat, a run) it looks at least this far ahead, metres: room
## to make the manoeuvre and get going again before the shallows, where the wind often dies (the
## skipper's heads, 8 November 2026: a run on Silvaplana's SD3 at 16:30 slowed from 6 to 1.5 m/s in the
## last 100 m before the east shore and never made its gybe).
const SHORE_LOOK_TURNING_MIN_M: float = 120.0
## Slower than this at the edge, the board gets out on the tack it is on (up toward the wind or down
## away from it, whichever has more water ahead) instead of waiting for a tack or gybe it is too slow
## to make, m/s; it bears away no further than SHORE_SLOW_DOWN_TWA_DEG, which it can still steer slowly.
const SHORE_SLOW_MS: float = 3.0
const SHORE_SLOW_DOWN_TWA_DEG: float = 150.0
## A way out on this tack counts when it has at least this much open water ahead, metres.
const SHORE_SLOW_OPEN_M: float = 40.0
## The wind ahead (_avoid_the_holes(); Max, 8 November 2026: "give them enough information about wind,
## water and shore"): a sailor sees the dark water of more wind and the glassy patches where it dies.
## On a beat or a run it looks its character's wind_look_m ahead on both tacks; when its own tack sails
## into wind under its wind_hole_share of the wind where it is and the other tack has at least
## WIND_BETTER_SHARE of that, it tacks or gybes now (within its tacks for the leg) instead of sailing into
## the hole. Only with a map's wind (the lake); the open water's wind is the same everywhere.
const WIND_BETTER_SHARE: float = 1.2
## Closer than this to the next mark it no longer looks for holes, metres.
const WIND_NEAR_MARK_M: float = 250.0
## Dirty air (_clear_air(), SkipperConfig.dirty_air_share): in the shadow this long, seconds, before it tacks away;
## the other tack's air looked at this far ahead, metres (the shadows reach 30 m); not within this of the mark.
const DIRTY_AIR_S: float = 3.0
const DIRTY_AIR_LOOK_M: float = 25.0
const DIRTY_AIR_NEAR_MARK_M: float = 120.0
## Nearer than this to the finish line it runs for, on the gybe that reaches it, it steers straight at it, no
## deeper than DIRECT_RUN_DEEPEST_TWA_DEG: O2's 35 m finish line lay dead downwind of a board 47 m away, and
## the run's 135 degrees carried it past the end of the line, again and again for two minutes (the
## skipper's heads, 8 November 2026). Metres, degrees.
const DIRECT_RUN_M: float = 80.0
const DIRECT_RUN_DEEPEST_TWA_DEG: float = 175.0
## Past the layline by this much more than its margin, it tacks (or gybes) even when it is too slow to
## point, metres: on Silvaplana's O2 at 11:40 a board at 2 m/s sailed 280 m away from its mark for almost
## three minutes, past the layline, because a slow tack was refused (the skipper's heads, 8 November 2026).
const SLOW_TACK_PAST_M: float = 30.0
## Too slow to gybe (_slow_turn()): racing slower than SLOW_TURN_MS, a change of tack asked for from a
## broad reach (a gybe) is made as a tack instead: it heads up on its tack to SLOW_TURN_TWA_DEG and tacks
## once it is SLOW_TURN_MARGIN_DEG inside the controller's tacking angle, giving up after SLOW_TURN_MAX_S
## or once it is faster. A gybe at 1.5 m/s bore away, stalled and came back, again and again, while the
## board drifted onto Silvaplana's east shore at 17:20 (the skipper's heads, 8 November 2026).
const SLOW_TURN_MS: float = 3.0
const SLOW_TURN_TWA_DEG: float = 75.0
const SLOW_TURN_MARGIN_DEG: float = 10.0
const SLOW_TURN_MAX_S: float = 20.0
## Getting going (SkipperConfig.get_going_twa_deg): slower than GET_GOING_BELOW_MS on the board for
## GET_GOING_AFTER_S (not in a manoeuvre) it sails at its getting-going angle until it is faster than
## GET_GOING_UNTIL_MS, or for GET_GOING_MAX_S at most (then the race's angle again for as long).
const GET_GOING_BELOW_MS: float = 2.5
const GET_GOING_AFTER_S: float = 6.0
const GET_GOING_UNTIL_MS: float = 5.0
const GET_GOING_MAX_S: float = 25.0
## The leeway and the speed it expects are smoothed over this long, seconds; the leeway is measured
## above MEASURE_LEEWAY_FROM_MS.
const MEASURE_SMOOTH_S: float = 3.0
const MEASURE_LEEWAY_FROM_MS: float = 2.5
## A sailor's feel for the board, against what the polar says it makes. Downwind, slower than
## OFF_PLANE_SHARE of the polar's speed at the best downwind angle the board is off the plane, and
## the sailor heads up RUN_HEAD_UP_DEG to get it planing again; faster than ON_PLANE_SHARE of it the
## sailor bears away again. (Fixed speeds, 6 and 7 m/s, held the 12 kt run 10 degrees high all
## the way: there the board planes at 5.7 to 6.6 m/s.) Off the plane it sails no deeper than
## OFF_PLANE_TWA_DEG either: in 12 kt a board out of a gybe at 2 m/s planed again at 110 to 115
## degrees within 20 s, and at 119 it sat at 2.5 m/s for three minutes. Upwind, a board slower
## than FOOT_BELOW_SHARE of the polar's speed at the best upwind angle (just out of a tack, say) is
## sailed FOOT_DEG_PER_MS lower for each m/s it lacks, at most FOOT_MAX_DEG lower, to get going.
const OFF_PLANE_SHARE: float = 0.65
const ON_PLANE_SHARE: float = 0.8
const RUN_HEAD_UP_DEG: float = 10.0
const OFF_PLANE_TWA_DEG: float = 110.0
const FOOT_BELOW_SHARE: float = 0.85
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
## A slalom's start (_slalom_start_heading()): it waits within SLALOM_PARK_RADIUS_M of its spot upwind
## of the committee boat, slows down from SLALOM_SLOW_FROM_M before it, and goes when it has no more
## than SLALOM_GO_SPARE_S to spare: the time left less the time it needs to sail straight to its
## crossing (_time_to_cross_s()). The reach down is sailed straight between these wind angles.
const SLALOM_PARK_RADIUS_M: float = 20.0
const SLALOM_SLOW_FROM_M: float = 60.0
const SLALOM_GO_SPARE_S: float = 1.0
const SLALOM_DIVE_CLOSEST_TWA_DEG: float = 60.0
const SLALOM_DIVE_DEEPEST_TWA_DEG: float = 148.0
## SkipperConfig.slalom_early_ease: early on the dive it luffs up only when it would cross the line within this many
## seconds, metres apart at its speed (before that it eases and keeps the dive's heading).
const SLALOM_LAST_LUFF_S: float = 2.5
## SkipperConfig.slalom_dive_gybes: from this wind angle or deeper the dive turns onto the other tack by a gybe, degrees.
const SLALOM_DIVE_GYBE_FROM_TWA_DEG: float = 70.0
## SkipperConfig.reaching_loop_excess_s: a hold whose track runs at least this much across the start line (the share
## of its direction toward the line) counts as a reaching start's: holding back brings it nearer the line.
const REACHING_HOLD_ACROSS: float = 0.7
## The run in is this much wider than the angle the board beats at (the polar's, for the wind and its
## character), and no wider than START_RUN_IN_WIDEST_TWA_DEG, degrees: its track, with the leeway, must
## lay the spot. 60 was 15 above the old beat of 45; at the polar's 55 to 59 a run in at 60 could not be
## laid, and the board slid along behind the line past its end (the gambler on T1, over at the gun).
const START_RUN_IN_ABOVE_BEAT_DEG: float = 15.0
const START_RUN_IN_WIDEST_TWA_DEG: float = 72.0
## Its waiting point is at least this far behind the start line, metres; within
## START_HOLD_REACHED_M of the way in from it to its spot, the board sails in.
const START_HOLD_BEHIND_M: float = 20.0
const START_HOLD_REACHED_M: float = 15.0
## Its waiting point is at least this far behind the start line or its extensions, metres
## (_well_behind_the_line()).
const START_WAIT_BEHIND_M: float = 30.0
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
## Going from its hold within START_GO_LATCH_M of the line itself (not of its extension past an end) it
## keeps going (further back, or further out past an end than START_WALL_M, it may still
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
## A board that missed the finish line goes back to a point this far behind its middle, metres, and
## crosses again once it is FINISH_BACK_REACHED_M behind the line (see _finish_target()).
const FINISH_BACK_M: float = 30.0
const FINISH_BACK_REACHED_M: float = 20.0
## A board heading the wrong way round a mark (its heading more than 120 degrees from the way
## a rounding crosses the ray: the cosine below) is not level with it, however near: it goes back
## WRONG_WAY_BACK_M down the leg first, on the side the mark is left on, and comes up again. Coming
## back to the slalom template's mark 1 from the north (after two penalty turns beside it), Aiko was
## counted level, gybed the long way to the exit and went round the mark anticlockwise, again and
## again: 45 gybes and no finish (18 kt, characters.md).
const WRONG_WAY_COS: float = -0.5
const WRONG_WAY_BACK_M: float = 30.0
## round_early (_round_early_deg()): the arc it would sail turning onto the next leg now must pass the mark (or a
## gate's marks) at least this far, metres, and cross a mark's rounding ray no further out than mark_margin_m plus
## ROUND_EARLY_WIDE_M. It looks within ROUND_EARLY_LOOK_M of the mark, from ROUND_EARLY_FROM_MS, at a turn of at
## least ROUND_EARLY_MIN_TURN_DEG, working the arc out ROUND_EARLY_STEP_S at a time for ROUND_EARLY_HORIZON_S.
const ROUND_EARLY_CLEAR_M: float = 4.0
const ROUND_EARLY_WIDE_M: float = 10.0
const ROUND_EARLY_LOOK_M: float = 80.0
const ROUND_EARLY_FROM_MS: float = 3.0
const ROUND_EARLY_MIN_TURN_DEG: float = 10.0
const ROUND_EARLY_STEP_S: float = 0.2
const ROUND_EARLY_HORIZON_S: float = 14.0
## gybe_at_mark: the gybe's arc must pass the mark at least this far, metres (wider than ROUND_EARLY_CLEAR_M, less than
## mark_margin_m, which the way in passes the mark at: once the
## controller has begun the gybe the skipper cannot steer, and a board slowing in the gybe turns tighter), and a turn
## round the mark of at most ROUND_GYBE_MAX_TURN_DEG.
const ROUND_GYBE_CLEAR_M: float = 5.0
const ROUND_GYBE_MAX_TURN_DEG: float = 220.0
## The rate the gybe's carve down to dead downwind is worked out at, degrees a second (out of it at the controller's
## gybe_rate_dps). Measured in the suite's r0124 (SD3 at 50 %, 9 to 11 m/s): 52 degrees in 3.7 s, then 75 in 2.4 s;
## but worked out at 14 the turn began too early: two roundings 1 to 2 m off the mark, and r0105's mark 2 not rounded
## (the board came back round and fell: leg 2 in 146 s for 76). At 30 (the arc tighter than sailed, so it begins
## later) r0124's mark 3 came out 39 m off instead of 59, the race 5 s faster.
const ROUND_GYBE_ENTRY_DPS: float = 30.0
## Racing for the finish, within FINISH_EASE_WITHIN_S of the line at its speed, a board whose track
## over the ground would cross the line's extension more than FINISH_MISS_M beyond an end eases down
## to FINISH_EASE_SPEED_MS (the hold-back, as at the start), so that it can turn onto the line: at
## planing speed the head-up is gentle (GENTLE_HEAD_UP_STICK above GENTLE_HEAD_UP_FROM_MS). On T1 at
## 24 kt the board came out of the 4S rounding at 13 m/s heading 30 degrees off a 35 m line 109 m
## away, could not head up in time, and swept past the east end. A board that has missed the line
## sails at FINISH_AGAIN_SPEED_MS until it has crossed: its turns back are tight, not loops of 60 m
## at 11 m/s (24 tacks and gybes round the line, and no finish; see _finish_target()).
const FINISH_EASE_WITHIN_S: float = 12.0
const FINISH_MISS_M: float = 3.0
const FINISH_EASE_SPEED_MS: float = 8.0
const FINISH_AGAIN_SPEED_MS: float = 6.0
## The share of the finish line kept clear at each end when it aims at the nearest point of it.
const FINISH_END_SHARE: float = 0.25
## Finished: it sails on this far past the finish line (clear of the boards still finishing), then
## sails free.
const FINISH_CLEAR_M: float = 40.0
## A board getting up to speed gains about this much a second (m/s2): the time it expects to need
## includes the speed it still has to gain.
const ACCELERATION_MS2: float = 1.0
## The character sheet. (random_seed seeds its steering noise, and note says what it is doing:
## "beat", "run", "start: away", ...; both are RaceSkipper's.)
var config: SkipperConfig = SkipperConfig.new()
## Whether it sets the push slider (_push_level()); off, the hands leave it alone and the board sails
## the pilot's own margin, as every AI board did before (tools/race.sh --skipper_push=0 compares).
var push_wanted: bool = true
## Where its hand has the push slider now (0 to 1), NaN while it leaves the slider to the pilot's own
## margin (see _move_the_push()).
var _push_now: float = NAN
## The persona this skipper plays (F4), if any: its sheet is drawn afresh for every race in
## setup() (the day's form, seeded by random_seed, and its form in the wind of the race).
var persona: Persona = null
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
## With round_early: it has begun the turn onto the next leg before the step counted (_round_early_deg()).
var _rounding_early: bool = false
## With gybe_at_mark: it is bearing away to gybe round this mark (_round_early_deg()).
var _gybing_at_mark: bool = false
var _gate_end: int = -1
var _start_phase: StartPhase = StartPhase.TO_LINE
## The tack it runs in to the start line on, chosen at the first look (_start_run_in_tack()).
var _run_in_tack: float = 0.0
## The run in's wind angle, chosen with its tack (_run_in_twa_deg()); 0 until then.
var _run_in_twa: float = 0.0
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
## On its way back behind the finish line after missing it, and whether it has missed it once (see
## _finish_target()).
var _finish_going_back: bool = false
var _finish_missed: bool = false

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
## Crawling before its start (SkipperConfig.crawl_no_head_up_ms): no stick toward the wind until it has speed.
var _crawling: bool = false
## Since when it has crawled with the stick asking to head up (-1: not).
var _crawl_stuck_from_s: float = -1.0
## The shore lookout turned its last decided heading (_keep_off_the_shore()): crawl_no_head_up_ms stands aside.
var _shore_steers: bool = false
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
## Shift held for this think's turn (the carve): set while keeping clear with SkipperConfig.keep_clear_sharp.
var _sharp_wanted: bool = false
## Since when it has sailed in dirty air (another sail's shadow; -1: clear air).
var _dirty_since_s: float = -1.0
## Waiting for traffic before a tack (tack_traffic_check): since when, and when it last had to.
var _traffic_wait_from_s: float = -INF
var _traffic_seen_s: float = -INF
## A tack that does not go (SkipperConfig.change_slow_tack, _change_a_tack_that_does_not_go()): when each tack last
## sailed upwind at WENT_SHARE of the polar or better (0 port, 1 starboard); since when this tack has crawled (-1:
## not); the tack it keeps, and until when, after changing away from a tack that did not go.
var _went_at_s: PackedFloat32Array = PackedFloat32Array([-INF, -INF])
var _crawl_from_s: float = -1.0
var _prefer_tack: float = 0.0
var _prefer_until_s: float = -INF
## Whether the step it sails for is the finish (set at every decision, for the straight run in).
var _to_the_finish: bool = false
## Since when it heads up to tack because it is too slow to gybe (-1: not).
var _slow_turn_from_s: float = -1.0
## The point it last sailed for (_course_to()), for the race tool's track (Vector2.INF: none yet).
var aim_point: Vector2 = Vector2.INF
## Getting going: how long it has been slow, whether it is getting going now and since when.
var _slow_s: float = 0.0
var _getting_going: bool = false
var _getting_going_from_s: float = -INF
## Whether the leg it is sailing is one of tacks or gybes (a beat, a run, or the target on the other
## tack): set by _course_to() at every decision, read by _keep_off_the_shore().
var _leg_turns: bool = false
## The penalty turn (F3, _penalty_turn_heading()): its phase (0 none; PENALTY_EASING,
## PENALTY_FIRST, PENALTY_BETWEEN, PENALTY_SECOND), when it began, whether it gybes first, when it
## last pressed for a manoeuvre, and how many turns it has taken.
var _penalty_phase: int = 0
var _penalty_from_s: float = 0.0
var _penalty_gybe_first: bool = false
var _penalty_pressed_s: float = -INF
## Since when it owes a penalty it has not begun to turn (SkipperConfig.penalty_when_clear); -1: none owed.
var _penalty_owed_s: float = -1.0
## With penalty_when_clear the turn waits until no other sailing board is within PENALTY_CLEAR_M, metres, but no
## longer than PENALTY_WAIT_MAX_S after the penalty (a circle in the crowd after the gun set off more incidents:
## the skipper's heads, 8 November 2026).
const PENALTY_CLEAR_M: float = 30.0
const PENALTY_WAIT_MAX_S: float = 45.0
var penalty_turns: int = 0
const PENALTY_EASING: int = 1
const PENALTY_FIRST: int = 2
const PENALTY_BETWEEN: int = 3
const PENALTY_SECOND: int = 4
## A penalty turn that has not come round in this long is given up (the judge keeps the penalty,
## and the skipper tries again), seconds.
const PENALTY_TURN_GIVE_UP_S: float = 45.0
## Bearing away to this wind angle for the gybe of a penalty turn, degrees.
const PENALTY_GYBE_FROM_TWA_DEG: float = 120.0
## Before its penalty turn the board eases down, holding its course: held back to
## PENALTY_EASE_SPEED_MS, it begins the turn once slower than PENALTY_START_BELOW_MS, or after
## PENALTY_EASE_LONGEST_S at most (m/s, m/s, seconds). Begun at 6 to 11 m/s, the head-up and the tack
## stopped the board dead and the bear-away right after it put the sailor in the water: 6 of the 15
## falls of the twenty in a fleet (Documentation/reports/fleet_speed/start.md).
const PENALTY_EASE_SPEED_MS: float = 5.0
const PENALTY_START_BELOW_MS: float = 6.5
const PENALTY_EASE_LONGEST_S: float = 6.0
## Between the turn's two manoeuvres it gets going again first, on a reach no closer to the wind than
## the pilot's bear-away angle, until it sails this fast, m/s (a board stopped by the tack fell in
## when it bore away for the gybe at 0.5 m/s).
const PENALTY_GOING_MS: float = 4.0
## From a beam reach (this wind angle, degrees) and further off the wind it gybes first: there the bow
## is nearly round for the gybe already, and a tack would first head up 40 degrees and more at speed.
const PENALTY_GYBE_FIRST_FROM_TWA_DEG: float = 80.0
## A pressed manoeuvre the controller has not begun in this long is pressed again, seconds.
const PENALTY_PRESS_AGAIN_S: float = 3.0
## What the skipper knows of its board (SkipperPolar, Game/config/skipper_polar.tres): the speed at
## each wind angle and wind, the push that pays there, and the best angles to beat and to run at. Its
## own copies of the tables, not the loaded resource every skipper shares: skippers sailed side by
## side on threads slowed each other down reading shared data. The skipper also measures how fast it
## goes against the speeds, and uses that ratio too (_speed_ratio).
var _polar_winds: PackedFloat32Array = PackedFloat32Array()
var _polar_twa: PackedFloat32Array = PackedFloat32Array()
var _polar_speeds: PackedFloat32Array = PackedFloat32Array()
var _polar_push: PackedFloat32Array = PackedFloat32Array()
var _polar_upwind: PackedFloat32Array = PackedFloat32Array()
var _polar_downwind: PackedFloat32Array = PackedFloat32Array()


func _init() -> void:
	take_polar(SkipperPolar.default_polar())


## Sails with another polar (a test's, or another board's): copies of its tables.
func take_polar(polar: SkipperPolar) -> void:
	_polar_winds = polar.winds_kt.duplicate()
	_polar_twa = polar.twa_deg.duplicate()
	_polar_speeds = polar.speed_ms.duplicate()
	_polar_push = polar.push_level.duplicate()
	_polar_upwind = polar.best_upwind_twa_deg.duplicate()
	_polar_downwind = polar.best_downwind_twa_deg.duplicate()


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
	if persona != null:
		config = persona.to_skipper_config(random_seed, sim.telemetry.tws_10m_kt, level_spread)
	_rng.seed = random_seed
	# The skipper's own clock runs on across races (RaceRunner.restart() sets it up again at R), so every
	# "since" it keeps stays true. Set back to 0 here, the last manoeuvre's end from the race before lay
	# minutes ahead of it, and no tack or gybe came for as long as that race had lasted (Max, 8 November
	# 2026: "if I press R the AI lost their minds").
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
	_next_think_s = _time_s
	_others_time_s = _time_s
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
	_run_in_twa = 0.0
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
	_finish_going_back = false
	_finish_missed = false
	_penalty_phase = 0
	_slow_s = 0.0
	_getting_going = false
	_getting_going_from_s = -INF
	_slow_turn_from_s = -1.0
	# The controller is reset with the board (no manoeuvre under way), and nothing timed in the race
	# before is still waiting.
	_last_manoeuvre = PlayerController.Manoeuvre.NONE
	_manoeuvre_ended_s = -INF
	_settling = false
	_crawling = false
	_crawl_stuck_from_s = -1.0
	_shore_steers = false
	_penalty_owed_s = -1.0
	_penalty_pressed_s = -INF
	_dirty_since_s = -1.0
	_traffic_wait_from_s = -INF
	_traffic_seen_s = -INF
	_went_at_s = PackedFloat32Array([-INF, -INF])
	_crawl_from_s = -1.0
	_prefer_until_s = -INF
	_holding_since_s = -1.0
	_keeping_clear = false
	_sharp_wanted = false
	if _hands != null:
		_hands.hold_speed_ms = 0.0
		_hands.sharp = false
		_hands.tack = false


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
	# The sheet is the auto-sheet's: the skipper never moves the sheet stick. The push slider is its.
	_hands.sheet = 0.0
	_hands.push = _move_the_push(telemetry, dt)
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
	_sharp_wanted = false
	_leg_turns = false
	_to_the_finish = false
	# A penalty from the judge is taken at once, while racing (not in the pre-start crowd, where
	# a circle would be a danger to everyone; it is carried to the start and taken on the first leg).
	# With penalty_when_clear it first gets clear of the other boards (PENALTY_CLEAR_M), as sailors do.
	if rules != null and _penalty_phase == 0 and state == State.RACING and rules.penalties(_index) > 0:
		if _penalty_owed_s < 0.0:
			_penalty_owed_s = _time_s
		if not config.penalty_when_clear or _time_s - _penalty_owed_s >= PENALTY_WAIT_MAX_S 				or _nearest_board_m(telemetry) >= PENALTY_CLEAR_M:
			_penalty_phase = PENALTY_EASING
			_penalty_from_s = _time_s
			_penalty_pressed_s = -INF
			_penalty_owed_s = -1.0
	var course_deg: float = _decide(telemetry)
	var decided_deg: float = _keep_off_the_shore(telemetry, course_deg)
	# (For crawl_no_head_up_ms: the shore lookout turned it.)
	_shore_steers = absf(wrapf(decided_deg - course_deg, -180.0, 180.0)) > 1.0
	_avoid_the_holes(telemetry, decided_deg)
	_clear_air(telemetry, decided_deg)
	decided_deg = _get_going(telemetry, decided_deg)
	decided_deg = _slow_turn(telemetry, decided_deg)
	decided_deg = _look_ahead_keep_clear(telemetry, decided_deg)
	if _keeping_clear:
		note += ", keeping clear"
	_change_a_tack_that_does_not_go(telemetry)
	_last_wanted_deg = decided_deg
	_delay_times.append(_time_s)
	_delay_headings.append(decided_deg)
	_remember_others()


## The shore (a race on a lake: shore, a ShoreLookout; Max, 6 November 2026): the board never sails
## out of the open water. Before every decision it looks along the heading it wants as far as it
## sails in SHORE_LOOK_S (SHORE_LOOK_MIN_M to SHORE_LOOK_MAX_M):
## - a tack or a gybe it asked for that would point it at the shore sooner than its heading now does
##   is not made (a layline or a lift that lies over the land);
## - the shore ahead on a beat or a run: it tacks or gybes now (as a sailor does at the edge of the
##   water), if the other tack has more water ahead;
## - the shore ahead on a reach (or on both tacks): it turns, on the same tack, to the heading with the
##   most water ahead (no closer to the wind than it can sail).
## A penalty's circle is left alone (it is turned on the spot) unless it is out of the open water.
## Already at the edge (less than SHORE_ESCAPE_M ahead): _escape_the_shore().
func _keep_off_the_shore(telemetry: Telemetry, heading_deg: float) -> float:
	if shore == null:
		return heading_deg
	var position: Vector2 = _position(telemetry)
	var look_m: float = clampf(telemetry.speed_ms * SHORE_LOOK_S, SHORE_LOOK_TURNING_MIN_M if _leg_turns else SHORE_LOOK_MIN_M,
		SHORE_LOOK_MAX_M)
	var wind_deg: float = telemetry.wind_from_bearing_deg
	if _penalty_phase > 0:
		# The circle is turned where it is, unless that is out of the open water already.
		return heading_deg if shore.is_open(position) else _escape_the_shore(telemetry, position, heading_deg, wind_deg)
	var here_m: float = shore.water_ahead_m(position, heading_deg, look_m)
	if here_m < SHORE_ESCAPE_M:
		return _escape_the_shore(telemetry, position, heading_deg, wind_deg)
	# The same angle to the wind on the other tack.
	var other_deg: float = 2.0 * wind_deg - heading_deg
	if _tack_due_s >= 0.0:
		var there_m: float = shore.water_ahead_m(position, other_deg, look_m)
		if there_m < look_m and there_m < here_m:
			_tack_due_s = -1.0
			note += ", not toward the shore"
		return heading_deg
	if _controller.manoeuvre != PlayerController.Manoeuvre.NONE or here_m >= look_m:
		return heading_deg
	note += ", the shore %.0f m ahead" % here_m
	var twa_deg: float = absf(wrapf(wind_deg - heading_deg, -180.0, 180.0))
	# A beat or a run tacks or gybes away from the shore whatever its angle of the moment: its leg is
	# sailed in tacks anyway (the run at the polar's 130 degrees counted as a reach in a local wind a few
	# degrees round, turned along the shore and never gybed).
	var turning_leg: bool = _leg_turns or twa_deg < SHORE_REACH_FROM_DEG or twa_deg > SHORE_REACH_TO_DEG
	if turning_leg and shore.water_ahead_m(position, other_deg, look_m) > here_m:
		_ask_for_manoeuvre(true, true)
		return heading_deg
	# Turn away on this tack: the heading with the most water ahead, from as close to the wind as it
	# sails to almost dead downwind.
	var tack: float = 1.0 if wrapf(wind_deg - heading_deg, -180.0, 180.0) >= 0.0 else -1.0
	var best_deg: float = heading_deg
	var best_m: float = here_m
	for step: int in range(1, 9):
		for way: float in [1.0, -1.0]:
			var twa_try: float = clampf(twa_deg + way * SHORE_TURN_STEP_DEG * step, _upwind_twa_deg(), 170.0)
			var try_deg: float = wind_deg - tack * twa_try
			var water_m: float = shore.water_ahead_m(position, try_deg, look_m)
			if water_m > best_m + 1.0:
				best_m = water_m
				best_deg = try_deg
	return best_deg


## Getting going (SkipperConfig.get_going_twa_deg): how long the board has been slow on the board, and
## whether it gets going now (after the gun, not before: the start holds back on purpose).
func _watch_the_speed(telemetry: Telemetry, dt: float) -> void:
	var sailing: bool = _sim.sailor_state == WindsurferSim.SailorState.SAILING
	if not sailing or _controller.manoeuvre != PlayerController.Manoeuvre.NONE or telemetry.speed_ms >= GET_GOING_BELOW_MS:
		_slow_s = 0.0
	else:
		_slow_s += dt
	if _getting_going:
		var over: bool = telemetry.speed_ms > GET_GOING_UNTIL_MS or _time_s - _getting_going_from_s > GET_GOING_MAX_S or not sailing
		if over:
			_getting_going = false
			_slow_s = 0.0
			# The same wait again before the next try.
			_getting_going_from_s = _time_s
	elif config.get_going_twa_deg > 0.0 and _slow_s > GET_GOING_AFTER_S and _race.clock_s() >= 0.0 and state != State.FINISHED 			and _time_s - _getting_going_from_s > GET_GOING_MAX_S:
		_getting_going = true
		_getting_going_from_s = _time_s


## While getting going: the getting-going angle on the tack it is on. The shore, a penalty's turn and a
## manoeuvre under way come first.
func _get_going(telemetry: Telemetry, heading_deg: float) -> float:
	if not _getting_going or _penalty_phase > 0 or note.contains("shore") or _controller.manoeuvre != PlayerController.Manoeuvre.NONE:
		return heading_deg
	note += ", getting going"
	return telemetry.wind_from_bearing_deg - _tack() * config.get_going_twa_deg


## Too slow to gybe (SLOW_TURN_*): it heads up on its tack, then tacks.
func _slow_turn(telemetry: Telemetry, heading_deg: float) -> float:
	if _slow_turn_from_s < 0.0:
		return heading_deg
	if telemetry.speed_ms > SLOW_TURN_MS + 1.0 or _time_s - _slow_turn_from_s > SLOW_TURN_MAX_S or _penalty_phase > 0 			or _controller.manoeuvre != PlayerController.Manoeuvre.NONE or state != State.RACING:
		_slow_turn_from_s = -1.0
		return heading_deg
	if absf(telemetry.twa_deg) < _controller.tack_up_to_twa_deg - SLOW_TURN_MARGIN_DEG:
		# Up far enough: Space now makes it a tack.
		_slow_turn_from_s = -1.0
		_tack_due_s = _time_s + config.reaction_time_s
		note += ", tacking (too slow to gybe)"
		return telemetry.wind_from_bearing_deg - _tack() * SLOW_TURN_TWA_DEG
	note += ", heading up to tack (too slow to gybe)"
	return telemetry.wind_from_bearing_deg - _tack() * SLOW_TURN_TWA_DEG


## The wind ahead (SkipperConfig.wind_look_m): on a beat or a run, when this tack sails into a light patch and the
## other tack has more wind, it asks for the tack or gybe now. It never overrides the shore: a manoeuvre
## the shore check already asked for or refused stands.
func _avoid_the_holes(telemetry: Telemetry, heading_deg: float) -> void:
	if config.wind_look_m <= 0.0 or not _leg_turns or _tack_due_s >= 0.0 or _controller.manoeuvre != PlayerController.Manoeuvre.NONE 			or note.contains("shore"):
		return
	var position: Vector2 = _position(telemetry)
	# Near the mark the mark decides: a gybe away there only means a gybe back.
	if position.distance_to(_race.next_target(_index)) < WIND_NEAR_MARK_M:
		return
	var here_ms: float = wind_speed_at(position)
	if is_nan(here_ms) or here_ms < 0.5:
		return
	var wind_deg: float = telemetry.wind_from_bearing_deg
	var other_deg: float = 2.0 * wind_deg - heading_deg
	var ahead_ms: float = wind_speed_at(position + Course.direction_of(heading_deg) * config.wind_look_m)
	var other_ms: float = wind_speed_at(position + Course.direction_of(other_deg) * config.wind_look_m)
	if ahead_ms < config.wind_hole_share * here_ms and other_ms > WIND_BETTER_SHARE * ahead_ms:
		if shore != null and shore.water_ahead_m(position, other_deg, SHORE_LOOK_TURNING_MIN_M) < SHORE_LOOK_TURNING_MIN_M:
			return
		note += ", away from the light patch (%.0f kt ahead, %.0f kt on the other tack)" % [ahead_ms / SimMath.KNOT_MS, other_ms / SimMath.KNOT_MS]
		_ask_for_manoeuvre(false)


## Dirty air (SkipperConfig.dirty_air_share; Max, 8 November 2026: "make them race each other"): on a beat after
## the gun, sailing in other sails' wind shadows (the shadows' factor at its place under 1 - dirty_air_share) for
## DIRTY_AIR_S, with clearer air DIRTY_AIR_LOOK_M ahead on the other tack, it tacks away, as sailors do; not within
## DIRTY_AIR_NEAR_MARK_M of the mark, never toward the shore, within its tacks for the beat.
## On a run too with SkipperConfig.dirty_air_on_runs (the evening of 8 November 2026: on a run the shadows lie
## ahead of the sails, so the boards behind blanket the ones in front; in an 11-board fleet the first run cost
## 40 to 110 s against the same skipper alone): it gybes away the same way, if it is fast enough to gybe.
func _clear_air(telemetry: Telemetry, heading_deg: float) -> void:
	var shadows: WindDisturbance = _sim.wind.disturbance if _sim.wind != null else null
	var on_run: bool = absf(telemetry.twa_deg) > 90.0
	if config.dirty_air_share <= 0.0 or shadows == null or not _leg_turns or state != State.RACING \
			or (on_run and (not config.dirty_air_on_runs or telemetry.speed_ms < SLOW_TURN_MS + 1.0)):
		_dirty_since_s = -1.0
		return
	var position: Vector2 = _position(telemetry)
	var wind_deg: float = telemetry.wind_from_bearing_deg
	var downwind: Vector2 = Course.direction_of(wind_deg + 180.0)
	var undisturbed: Vector3 = Vector3(downwind.x, 0.0, downwind.y) * maxf(telemetry.tws_10m_kt * SimMath.KNOT_MS, 1.0)
	var here: float = shadows.factor_at(Vector3(position.x, 0.0, position.y), undisturbed)
	if here >= 1.0 - config.dirty_air_share:
		_dirty_since_s = -1.0
		return
	if _dirty_since_s < 0.0:
		_dirty_since_s = _time_s
	if _time_s - _dirty_since_s < DIRTY_AIR_S or _tack_due_s >= 0.0 or _controller.manoeuvre != PlayerController.Manoeuvre.NONE \
			or note.contains("shore") or position.distance_to(_race.next_target(_index)) < DIRTY_AIR_NEAR_MARK_M:
		return
	var other_deg: float = 2.0 * wind_deg - heading_deg
	var there: Vector2 = position + Course.direction_of(other_deg) * DIRTY_AIR_LOOK_M
	if shadows.factor_at(Vector3(there.x, 0.0, there.y), undisturbed) <= here + 0.5 * config.dirty_air_share:
		return
	if shore != null and shore.water_ahead_m(position, other_deg, SHORE_LOOK_TURNING_MIN_M) < SHORE_LOOK_TURNING_MIN_M:
		return
	note += ", out of dirty air (%.0f %% of the wind)%s" % [100.0 * here, " on the run" if on_run else ""]
	_ask_for_manoeuvre(false)


## A tack that does not go (SkipperConfig.change_slow_tack; the evening of 8 November 2026): in the lake's north-east
## corner boards on starboard crawled at a close reach in 15 kt for minutes and fell off at a standstill, while on
## port at the same spot they did 6 to 9 m/s; the skipper kept choosing starboard by its laylines. Upwind, sailing
## steadily (not in a manoeuvre, a hold-back or a penalty), it watches its speed against the polar's on each tack.
## Under SkipperConfig.slow_tack_share of it for CRAWL_S, with the other tack at WENT_SHARE or better within
## WENT_RECENT_S, it changes to the other tack, and keeps it for slow_tack_keep_s (no tack back by the laylines; the
## shore still decides).
const CRAWL_S: float = 12.0
const WENT_SHARE: float = 0.75
const WENT_RECENT_S: float = 120.0


func _change_a_tack_that_does_not_go(telemetry: Telemetry) -> void:
	if not config.change_slow_tack:
		return
	var steady: bool = _sim.sailor_state == WindsurferSim.SailorState.SAILING and _controller.manoeuvre == PlayerController.Manoeuvre.NONE \
			and not _settling and _hands.hold_speed_ms <= 0.0 and _penalty_phase == 0
	if not steady or absf(telemetry.twa_deg) >= 90.0:
		_crawl_from_s = -1.0
		return
	var slot: int = 1 if _tack() > 0.0 else 0
	var share: float = telemetry.speed_ms / maxf(_polar_speed_ms(maxf(absf(telemetry.twa_deg), _beat_twa_deg())), 1.0)
	if share >= WENT_SHARE:
		_went_at_s[slot] = _time_s
	if share >= config.slow_tack_share:
		_crawl_from_s = -1.0
		return
	if _crawl_from_s < 0.0:
		_crawl_from_s = _time_s
	if _time_s - _crawl_from_s < CRAWL_S or _time_s - _went_at_s[1 - slot] > WENT_RECENT_S or _tack_due_s >= 0.0:
		return
	var position: Vector2 = _position(telemetry)
	if shore != null and shore.water_ahead_m(position, 2.0 * telemetry.wind_from_bearing_deg - telemetry.heading_deg, SHORE_LOOK_TURNING_MIN_M) \
			< SHORE_LOOK_TURNING_MIN_M:
		return
	note += ", this tack does not go (%.0f %% of the polar): the other one" % (100.0 * share)
	_crawl_from_s = -1.0
	_ask_for_manoeuvre(true, true)
	if _tack_due_s >= 0.0:
		_prefer_tack = -_tack()
		_prefer_until_s = _time_s + config.slow_tack_keep_s


## The map's wind speed at a point (game X, Z), m/s, at the wind pattern's height: what a sailor reads on
## the water there (the lake's pattern, its lee and its gusts). NAN without a map's wind (the open water).
func wind_speed_at(point: Vector2) -> float:
	var field: MapWindField = _sim.wind as MapWindField
	if field == null or field.map_wind == null or field.moment() == null:
		return NAN
	var velocity: Vector3 = field.map_wind.velocity_in(field.moment(), Vector3(point.x, 0.0, point.y))
	return Vector2(velocity.x, velocity.z).length() if velocity.is_finite() else NAN


## Already at the edge of the open water (in the shallows, or close to the land: every heading looks
## the same from here, "0 m ahead"): it heads for the most open water near it (ShoreLookout.
## most_open_heading_deg()), as close to that heading as it can sail; when that water lies on the
## other side of the wind it tacks or gybes there (even slow), and meanwhile sails as near to it as
## this tack allows. A tack or gybe the race asked for that would not take it that way waits.
func _escape_the_shore(telemetry: Telemetry, position: Vector2, heading_deg: float, wind_deg: float) -> float:
	var way_out_deg: float = shore.most_open_heading_deg(position)
	note += ", away from the shore"
	var out_twa: float = wrapf(wind_deg - way_out_deg, -180.0, 180.0)
	var out_tack: float = 1.0 if out_twa >= 0.0 else -1.0
	var tack: float = 1.0 if wrapf(wind_deg - heading_deg, -180.0, 180.0) >= 0.0 else -1.0
	# No closer to the wind than it can sail, and not dead downwind.
	var out_abs: float = clampf(absf(out_twa), _upwind_twa_deg(), 170.0)
	if out_tack == tack:
		_tack_due_s = -1.0
		return wind_deg - tack * out_abs
	if telemetry.speed_ms < SHORE_SLOW_MS:
		# Too slow for a tack or gybe to come off: out on this tack, up toward the wind or down away from
		# it, whichever has more open water ahead.
		var up_deg: float = wind_deg - tack * _upwind_twa_deg()
		var down_deg: float = wind_deg - tack * SHORE_SLOW_DOWN_TWA_DEG
		var up_m: float = shore.water_ahead_m(position, up_deg, ShoreLookout.ESCAPE_LOOK_M)
		var down_m: float = shore.water_ahead_m(position, down_deg, ShoreLookout.ESCAPE_LOOK_M)
		var here_m: float = shore.water_ahead_m(position, heading_deg, ShoreLookout.ESCAPE_LOOK_M)
		# Out on this tack when that way has room, or at least more water than straight on: a board
		# drifting at 1.5 m/s at the lake's lee shore found neither way 40 m open and sailed on aground.
		if maxf(up_m, down_m) >= SHORE_SLOW_OPEN_M or maxf(up_m, down_m) > here_m + ShoreLookout.STEP_M:
			_tack_due_s = -1.0
			note += " (slow, on this tack)"
			return up_deg if up_m >= down_m else down_deg
	if _controller.manoeuvre == PlayerController.Manoeuvre.NONE:
		_ask_for_manoeuvre(true, true)
	# Until the tack or gybe: on this tack, as near to the way out as it sails (head up toward it if
	# it lies upwind, bear away if downwind), so the turn comes soon.
	return wind_deg - tack * (_upwind_twa_deg() if absf(out_twa) < 90.0 else 170.0)


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
	if _penalty_phase > 0:
		return _penalty_turn_heading(telemetry)
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
	_to_the_finish = step.kind == RaceStep.Kind.FINISH
	if (config.round_early or config.gybe_at_mark) and (step.kind == RaceStep.Kind.MARK or step.kind == RaceStep.Kind.GATE):
		var early_deg: float = _round_early_deg(telemetry, step, position)
		if not is_nan(early_deg):
			if not _gybing_at_mark:
				note = "rounding early"
			return early_deg + _keep_clear_deg(telemetry, _tack())
	var target: Vector2 = _target_point(step, position)
	# A mark at the end of a beat or a run is approached on the tack it can be gone round from (until
	# the board is level with the mark and rounding it). At the end of a reach the board comes on the
	# reach's tack, and a gybe round the mark is part of the course (a slalom mark).
	var arrive_tack: float = 0.0
	if step.kind == RaceStep.Kind.MARK and not _level_with_mark:
		var wind_deg: float = telemetry.wind_from_bearing_deg
		var leg_twa: float = absf(wrapf(wind_deg - Course.bearing_deg(Vector2.ZERO, step.in_dir), -180.0, 180.0))
		var up_deg: float = _pointing_twa_deg()
		if leg_twa < up_deg + _leeway_deg or leg_twa > _run_twa_deg() + _leeway_deg:
			arrive_tack = _approach_tack(step, wind_deg, up_deg if leg_twa < 90.0 else _downwind_twa_deg())
		elif absf(wrapf(wind_deg - Course.bearing_deg(position, target), -180.0, 180.0)) < up_deg + _leeway_deg + BEAT_IN_MARGIN_DEG 				and position.distance_to(step.points[0]) > APPROACH_ROOM_M:
			# The leg is a reach, but this board comes at the mark from below it (set back by a penalty,
			# the boards it kept clear of, a drop): a beat, so it arrives on the tack it can round from.
			# Aimed straight at the entry point it beat past the mark on the wrong side and circled it
			# for four minutes (the skipper's heads, 8 November 2026: Silvaplana's US4, mark 2, 15:20).
			arrive_tack = _approach_tack(step, wind_deg, up_deg)
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
		RaceStep.Kind.FINISH:
			return _finish_target(step, position)
	return _through(position, step.target())


## The finish: through the nearest point of the line, a quarter of the line in from the ends
## (FINISH_END_SHARE): the shortest way, and the least turn after the last mark, with room for the
## leeway. A board that missed the line (it swept past an end at speed and is on the course side
## without having finished) first goes back FINISH_BACK_M behind the middle of the line, until it is
## FINISH_BACK_REACHED_M behind it, and then crosses through the middle: aiming at the nearest point
## from beyond the line, or at one near an end after turning back wide, it chased the line round in
## circles (T1 at 24 kt, 25 tacks and 25 gybes and no finish). Having missed once it sails slowly
## (FINISH_AGAIN_SPEED_MS) until it has crossed, so the turns back are tight; and before any miss,
## near the line with its track carrying it past an end, it eases down to turn onto the line
## (_would_miss_the_line(), FINISH_EASE_SPEED_MS).
func _finish_target(step: RaceStep, position: Vector2) -> Vector2:
	var behind_m: float = -RoundingCheck.over_line_m(position, step.points[0], step.points[1], step.in_dir)
	if behind_m < 0.0:
		_finish_going_back = true
		_finish_missed = true
	elif behind_m > FINISH_BACK_REACHED_M:
		_finish_going_back = false
	if _finish_missed:
		_hands.hold_speed_ms = FINISH_AGAIN_SPEED_MS
	if _finish_going_back:
		return step.target() - step.in_dir * FINISH_BACK_M
	if _finish_missed:
		return _through(position, step.target())
	if _would_miss_the_line(step, position, behind_m):
		_hands.hold_speed_ms = FINISH_EASE_SPEED_MS
	var inset: float = maxf(_line_inset(step), FINISH_END_SHARE)
	return _through(position, step.points[1].lerp(step.points[0], clampf(_share_along_line(step, position), inset, 1.0 - inset)))


## Whether the board's track over the ground (its velocity, kept as it is) crosses the finish line's
## extension more than FINISH_MISS_M beyond an end, within FINISH_EASE_WITHIN_S from now; behind_m is
## how far behind the line the board is.
func _would_miss_the_line(step: RaceStep, position: Vector2, behind_m: float) -> bool:
	var toward_ms: float = _velocity.dot(step.in_dir)
	if toward_ms <= 0.5:
		return false
	var crossing_in_s: float = behind_m / toward_ms
	if crossing_in_s > FINISH_EASE_WITHIN_S:
		return false
	var crossing: Vector2 = position + _velocity * crossing_in_s
	return _off_the_ends_m(step, crossing) > FINISH_MISS_M


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
	var ray: Vector2 = RoundingCheck.rounding_ray(step.in_dir, step.out_dir, step.side)
	if not _level_with_mark:
		# Level with the mark (or within a margin of it: a board coming down on the mark from above,
		# having overstood, must not chase the entry point round in circles) on the side it is left
		# on, and still before the rounding ray (the half-way point, which it must cross going round
		# the right way). A board that comes level on the wrong side (it could not lay the entry
		# point), or that got past the ray without rounding (pushed the wrong side of the mark by the
		# boards it kept clear of), still sails for the entry point, round the mark's far side: going
		# for the exit from past the ray it never crossed the ray and circled the mark for twelve
		# minutes (Noor on the slalom template, 18 kt).
		var wrong_way: bool = going_round_the_wrong_way(_sim.telemetry.heading_deg, ray, way)
		_level_with_mark = (position - mark).dot(step.in_dir) >= -margin and (position - mark).dot(entry_side) > 0.0 \
				and before_rounding_ray(position, mark, ray, way) and not wrong_way
		if wrong_way and position.distance_to(mark) < WRONG_WAY_BACK_M:
			# Back down the leg first, on the entry side, so that it comes up to the mark again the
			# right way round instead of turning on the spot round the wrong side.
			return mark - step.in_dir * WRONG_WAY_BACK_M + entry_side * margin
	if not _level_with_mark:
		return mark + entry_side * margin
	# Vector2.rotated() turns clockwise on the map in these axes (X east, Z south), so way * 90
	# degrees is the direction the board moves when it crosses the ray going the right way round.
	return mark + ray * 2.0 * margin + ray.rotated(way * PI / 2.0) * margin


## Whether a board on this heading (degrees) goes the wrong way round a mark: more than 120 degrees
## (WRONG_WAY_COS) from the direction in which a rounding the right way crosses the ray.
static func going_round_the_wrong_way(heading_deg: float, ray: Vector2, way: float) -> bool:
	# Vector2.rotated() turns clockwise on the map (X east, Z south): way * 90 degrees is the way a
	# board moves when it crosses the ray going round the right way.
	return Course.direction_of(heading_deg).dot(ray.rotated(way * PI / 2.0)) < WRONG_WAY_COS


## Whether a position is still before a mark's rounding ray, going round it the way (1 clockwise, -1
## anticlockwise): on the side it crosses the ray from (RoundingCheck._across_ray()).
static func before_rounding_ray(position: Vector2, mark: Vector2, ray: Vector2, way: float) -> bool:
	return RoundingCheck.clockwise_of(ray, position - mark) * way < 0.0


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


## round_early and gybe_at_mark: the heading to steer when it is time to start the turn onto the next leg before the
## mark or the gate, NAN until then. It works out the track it would sail turning onto that leg now
## (_predict_rounding()): the turn starts as soon as that track still rounds the mark (RoundingCheck: across the
## rounding ray the right way, or through the gate between its ends) and passes every mark at least
## ROUND_EARLY_CLEAR_M off (ROUND_GYBE_CLEAR_M for a gybe, which it cannot steer once begun). Until then, and when the
## track would round wide (a mark's ray crossed beyond mark_margin_m + ROUND_EARLY_WIDE_M), it sails for the mark as
## before. round_early turns on the same tack and goes on unless the track would no longer round the mark or would
## touch it. gybe_at_mark, at a mark whose next leg is on the other gybe (a slalom mark): it bears away until it may
## gybe (past the controller's tacking angle) and asks for the gybe then, instead of after the rounding.
func _round_early_deg(telemetry: Telemetry, step: RaceStep, position: Vector2) -> float:
	var speed_ms: float = telemetry.speed_ms
	var marks: Array[Vector2] = []
	var way: float
	if step.kind == RaceStep.Kind.MARK:
		marks.append(step.points[0])
		way = RoundingCheck.turn_way(step.side)
	else:
		var _gate_aim: Vector2 = _gate_target(step, position)
		marks.append(step.points[_gate_end])
		marks.append(step.points[1 - _gate_end])
		# A gate is done by crossing its line: the turn after it goes whichever way is shorter onto the next leg
		# on this tack (round the nearer mark or away from it into the gate).
		way = 1.0
	if speed_ms < ROUND_EARLY_FROM_MS or position.distance_to(marks[0]) > ROUND_EARLY_LOOK_M:
		return NAN
	var wind_deg: float = telemetry.wind_from_bearing_deg
	var heading_deg: float = telemetry.heading_deg
	var tack: float = _tack()
	var out_deg: float = _heading_after(step.out_dir, wind_deg, heading_deg, way)
	if step.kind == RaceStep.Kind.GATE:
		var other_deg: float = _heading_after(step.out_dir, wind_deg, heading_deg, -1.0)
		var this_ok: bool = signf(wrapf(wind_deg - out_deg, -180.0, 180.0)) == tack and _turn_way_deg(heading_deg, out_deg, 1.0) <= 180.0
		var other_ok: bool = signf(wrapf(wind_deg - other_deg, -180.0, 180.0)) == tack and _turn_way_deg(heading_deg, other_deg, -1.0) <= 180.0
		if other_ok and (not this_ok or _turn_way_deg(heading_deg, other_deg, -1.0) < _turn_way_deg(heading_deg, out_deg, 1.0)):
			out_deg = other_deg
			way = -1.0
	var turn_deg: float = _turn_way_deg(heading_deg, out_deg, way)
	if signf(wrapf(wind_deg - out_deg, -180.0, 180.0)) != tack:
		# The next leg is on the other tack: a gybe round a slalom mark (gybe_at_mark), never a tack.
		var through_downwind: bool = _turn_way_deg(heading_deg, wind_deg + 180.0, way) < turn_deg \
				and turn_deg < _turn_way_deg(heading_deg, wind_deg, way)
		if not config.gybe_at_mark or step.kind != RaceStep.Kind.MARK or not through_downwind or turn_deg > ROUND_GYBE_MAX_TURN_DEG:
			return NAN
		var gybe_delay_s: float = config.reaction_time_s * 2.0 + 0.5 * THINK_INTERVAL_S
		var gybe: PackedFloat32Array = _predict_rounding(step, marks, position, speed_ms, heading_deg, out_deg, tack, gybe_delay_s, way, wind_deg)
		var gybe_rounds: bool = gybe[0] >= 0.0 and gybe[1] >= ROUND_GYBE_CLEAR_M
		if _gybing_at_mark:
			# Not gybing yet (refused: too soon after the last turn, too slow) and too late now: as before.
			if not gybe_rounds and _tack_due_s < 0.0 and _controller.manoeuvre == PlayerController.Manoeuvre.NONE:
				_gybing_at_mark = false
				return NAN
		elif not gybe_rounds or gybe[0] > config.mark_margin_m + ROUND_EARLY_WIDE_M:
			return NAN
		_gybing_at_mark = true
		note = "gybing at the mark"
		var may_gybe_deg: float = _controller.tack_up_to_twa_deg + 5.0
		if absf(telemetry.twa_deg) > may_gybe_deg:
			_ask_for_manoeuvre(true)
		# Off the wind on this gybe until the controller takes the turn over.
		return wind_deg - tack * maxf(may_gybe_deg + 5.0, _downwind_twa_deg())
	if not config.round_early or turn_deg < ROUND_EARLY_MIN_TURN_DEG or turn_deg > 180.0:
		return NAN
	# Already turning: the heading it asked for is on its way to the hands, so no straight run first.
	var delay_s: float = 0.0 if _rounding_early else config.reaction_time_s + 0.5 * THINK_INTERVAL_S
	var track: PackedFloat32Array = _predict_rounding(step, marks, position, speed_ms, heading_deg, out_deg, tack, delay_s, 0.0)
	var crossed_m: float = track[0]
	var rounds: bool = crossed_m >= 0.0 and track[1] >= ROUND_EARLY_CLEAR_M
	if step.kind == RaceStep.Kind.GATE:
		rounds = rounds and crossed_m >= ROUND_EARLY_CLEAR_M
	if _rounding_early:
		# Begun: it goes on round unless the track no longer rounds the mark or comes too near it.
		if not rounds:
			_rounding_early = false
			return NAN
	elif not rounds or (step.kind == RaceStep.Kind.MARK and crossed_m > config.mark_margin_m + ROUND_EARLY_WIDE_M):
		return NAN
	_rounding_early = true
	aim_point = Vector2(track[2], track[3])
	return out_deg


## The track it would sail from position turning onto out_deg after delay_s, as the controller turns: the bear-away at
## turn_rate_dps, the head-up at its budget over the speed (gentler above GENTLE_HEAD_UP_FROM_MS), both easing in the
## last FULL_STICK_ERROR_DEG; a gybe (gybe_way 1 clockwise, -1 anticlockwise; 0 steered) at ROUND_GYBE_ENTRY_DPS down
## to dead downwind (wind_deg + 180) and the controller's gybe_rate_dps out of it. Worked out
## ROUND_EARLY_STEP_S at a time for at most ROUND_EARLY_HORIZON_S, at the speed it has now. Returns how far from the
## nearest mark it crosses the step (a mark's rounding ray the right way round, or the gate's line between its ends;
## -1 when it does not, or goes round the wrong side first), the closest it passes any of the marks, and where it is
## when round onto the new heading (x, z).
func _predict_rounding(step: RaceStep, marks: Array[Vector2], position: Vector2, speed_ms: float, heading_deg: float,
		out_deg: float, tack: float, delay_s: float, gybe_way: float, wind_deg: float = 0.0) -> PackedFloat32Array:
	var head_up_dps: float = clampf(_controller.head_up_rate_budget_dps_ms / maxf(speed_ms, 0.1), _controller.head_up_rate_min_dps, _controller.turn_rate_dps)
	if speed_ms > GENTLE_HEAD_UP_FROM_MS:
		head_up_dps = minf(head_up_dps, GENTLE_HEAD_UP_STICK * _controller.turn_rate_dps)
	var gybe: bool = gybe_way != 0.0
	var p: Vector2 = position
	var h: float = heading_deg
	var left_deg: float = _turn_way_deg(heading_deg, out_deg, gybe_way) if gybe else 0.0
	# The gybe's carve down to dead downwind is slower than its exit (ROUND_GYBE_ENTRY_DPS).
	var to_downwind_deg: float = _turn_way_deg(heading_deg, wind_deg + 180.0, gybe_way) if gybe else 0.0
	var t: float = 0.0
	var crossed_m: float = -1.0
	var closest_m: float = INF
	var after_s: float = 0.0
	while t < ROUND_EARLY_HORIZON_S:
		if t >= delay_s:
			if gybe:
				var rate_dps: float = ROUND_GYBE_ENTRY_DPS if to_downwind_deg > 0.0 else _controller.gybe_rate_dps
				var step_deg: float = minf(rate_dps * ROUND_EARLY_STEP_S, left_deg)
				h += gybe_way * step_deg
				left_deg -= step_deg
				to_downwind_deg -= step_deg
			else:
				var error_deg: float = wrapf(out_deg - h, -180.0, 180.0)
				if absf(error_deg) >= STEER_DEAD_BAND_DEG:
					var rate_dps: float = minf(absf(error_deg) / FULL_STICK_ERROR_DEG, 1.0) * _controller.turn_rate_dps
					if signf(error_deg) == tack:
						rate_dps = minf(rate_dps, head_up_dps)
					h += signf(error_deg) * minf(rate_dps * ROUND_EARLY_STEP_S, absf(error_deg))
		var next: Vector2 = p + Course.direction_of(h) * speed_ms * ROUND_EARLY_STEP_S
		for mark: Vector2 in marks:
			closest_m = minf(closest_m, Geometry2D.get_closest_point_to_segment(mark, p, next).distance_to(mark))
		if crossed_m < 0.0:
			if step.kind == RaceStep.Kind.MARK:
				var outcome: RoundingCheck.Outcome = RoundingCheck.round_mark(p, next, marks[0], step.in_dir, step.out_dir, step.side)
				if outcome.wrong_side:
					break
				if outcome.done:
					crossed_m = p.lerp(next, outcome.fraction).distance_to(marks[0])
			else:
				var fraction: float = RoundingCheck.across_line(p, next, step.points[0], step.points[1], step.in_dir)
				if fraction >= 0.0:
					var crossing: Vector2 = p.lerp(next, fraction)
					crossed_m = minf(crossing.distance_to(step.points[0]), crossing.distance_to(step.points[1]))
		p = next
		t += ROUND_EARLY_STEP_S
		# Past the step and round onto the new heading: a second more for the closest pass, then done.
		var round_now: bool = left_deg <= 0.0 if gybe else absf(wrapf(out_deg - h, -180.0, 180.0)) < STEER_DEAD_BAND_DEG
		if crossed_m >= 0.0 and round_now:
			after_s += ROUND_EARLY_STEP_S
			if after_s >= 1.0:
				break
	return PackedFloat32Array([crossed_m, closest_m, p.x, p.y])


## The heading it will sail on a leg leaving in out_dir, reached turning way (1 clockwise, -1 anticlockwise) from
## from_deg: on a beat its upwind angle and on a run its downwind angle, on the tack the turn reaches first; on a
## reach the leg's own course, aimed up by the leeway (as _course_to() sails them).
func _heading_after(out_dir: Vector2, wind_deg: float, from_deg: float, way: float) -> float:
	var out_twa: float = wrapf(wind_deg - Course.bearing_deg(Vector2.ZERO, out_dir), -180.0, 180.0)
	var sail_deg: float
	if absf(out_twa) < _pointing_twa_deg() + _leeway_deg:
		sail_deg = _upwind_twa_deg()
	elif absf(out_twa) > _downwind_twa_deg() + _leeway_deg:
		sail_deg = _downwind_twa_deg()
	else:
		return wind_deg - signf(out_twa) * maxf(absf(out_twa) - _leeway_deg, _upwind_twa_deg())
	var starboard_deg: float = wind_deg - sail_deg
	var port_deg: float = wind_deg + sail_deg
	return starboard_deg if _turn_way_deg(from_deg, starboard_deg, way) <= _turn_way_deg(from_deg, port_deg, way) else port_deg


## The spot on the start line it makes for: its character's own spot (0 the pin, 1 the boat),
## pulled toward the end the line favours (chosen_start_share()), as it reads the line in its memory
## of the mean wind; kept a few metres in from the ends so it does not aim at a mark. On a slalom
## the crossing of its broad reach down from its waiting spot (_slalom_start_heading()).
func _start_spot(step: RaceStep) -> Vector2:
	if _race.course.starts_upwind_of_the_boat():
		# A slalom: where its broad reach down from its waiting spot meets the line. (The line's bias
		# to the wind means nothing on a reaching start: the line runs along the wind.)
		return RaceCourses.slalom_crossing(_race.course, _slalom_slot())
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
## on a reach on the other tack is a tack or gybe at once, not one at the layline. A layline_margin_m
## of 0 or more is the margin past the layline it tacks or gybes at, instead of its character's.
func _course_to(telemetry: Telemetry, target: Vector2, arrive_tack: float = 0.0, turn_now: bool = false, layline_margin_m: float = -1.0) -> float:
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
			if tack == arrive_tack and absf(target_twa) < 90.0 and position.distance_to(target) < FETCH_CHECK_M 					and absf(target_twa) < up_track_deg - FETCH_SAG_DEG:
				# On the arriving tack, near, and the target still to windward of what it can lay: it has
				# sagged below the layline and would pass the mark on the wrong side. Two tacks up instead.
				_ask_for_manoeuvre(true)
	aim_point = aim
	var bearing_deg: float = Course.bearing_deg(position, aim)
	# The wind angle of the track straight there, positive with the wind from starboard.
	var needed_deg: float = wrapf(wind_deg - bearing_deg, -180.0, 180.0)
	var needed_side: float = 1.0 if needed_deg >= 0.0 else -1.0
	var margin_m: float = config.layline_margin_m if layline_margin_m < 0.0 else layline_margin_m
	var heading_deg: float
	if absf(needed_deg) < up_track_deg:
		note = "beat"
		_leg_turns = true
		heading_deg = wind_deg - tack * up_deg
		var past_m: float = _past_layline_m(position, aim, wind_deg, tack, up_track_deg)
		if past_m >= margin_m:
			# Slow (not pointing) it tacks too once well past: in light wind a board may never reach the
			# pointing speed, and sailed on past the layline for minutes (SLOW_TACK_PAST_M).
			_ask_for_manoeuvre(true, past_m >= margin_m + SLOW_TACK_PAST_M)
		elif _headed_deg(wind_deg, tack) > config.shift_sensitivity_deg and _manoeuvres_here() < config.max_tacks_per_beat - 1:
			# Rule 3's shift: headed on this tack is lifted on the other.
			_ask_for_manoeuvre(false)
	elif absf(needed_deg) > down_track_deg:
		note = "run"
		_leg_turns = true
		heading_deg = wind_deg - tack * down_deg
		if _to_the_finish and position.distance_to(aim) < DIRECT_RUN_M and (needed_side == tack or absf(needed_deg) > DIRECT_RUN_DEEPEST_TWA_DEG):
			# Near and on this gybe's side: straight at it, as deep as it must (a run's angle is for long
			# legs; on a short line dead downwind it swept past the end, again and again).
			note = "run, straight in"
			heading_deg = wind_deg - tack * minf(absf(needed_deg) - _leeway_deg, DIRECT_RUN_DEEPEST_TWA_DEG)
		elif _past_layline_m(position, aim, wind_deg, tack, down_track_deg) >= margin_m:
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
		_leg_turns = true
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
		var past_other_m: float = _past_layline_m(position, aim, wind_deg, tack, up_track_deg if upwind else down_track_deg)
		# Past the layline of a beat into a mark (the mark now a reach on the other tack): the last tack at
		# mark_layline_margin_m, when it is set.
		var other_margin_m: float = margin_m
		if upwind and arrive_tack != 0.0 and layline_margin_m < 0.0 and config.mark_layline_margin_m >= 0.0:
			other_margin_m = config.mark_layline_margin_m
		if turn_ready and (turn_now or past_other_m >= other_margin_m):
			_ask_for_manoeuvre(true, past_other_m >= other_margin_m + SLOW_TACK_PAST_M)
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
		# A leg out straight downwind is reached at dead downwind, not swung far past it: a run out a few
		# degrees past dead downwind (DOWNWIND_SWING_DEG) is sailed on either gybe anyway. With 1 degree
		# a run out 2 degrees past dead downwind found neither tack and the board came in with no plan,
		# passed the mark on the wrong side and circled it (the skipper's heads, 8 November 2026, US4).
		var to_downwind: float = _turn_way_deg(heading_deg, wind_deg + 180.0, way) + DOWNWIND_SWING_DEG
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
## best angle in the wind of the moment (wider in light wind, where pinching makes the board slip
## sideways), moved by its character's own difference from POLAR_15KT.md's 45 and its pointing
## offset; and a little lower while the board is slower than FOOT_BELOW_SHARE of the polar's speed
## there (FOOT_DEG_PER_MS for each m/s it lacks, at most FOOT_MAX_DEG). Before its start too: the
## start plan (the way in, the crossing, the laylines to its spot) is drawn at the same angle.
func _pointing_twa_deg() -> float:
	var best_deg: float = _best_upwind_twa_deg()
	var foot_below_ms: float = FOOT_BELOW_SHARE * _polar_speed_ms(best_deg)
	var foot_deg: float = clampf((foot_below_ms - _sim.telemetry.speed_ms) * FOOT_DEG_PER_MS, 0.0, FOOT_MAX_DEG)
	return _beat_twa_deg() + foot_deg


## The wind angle it beats at once the board is up to speed, degrees: the polar's best in the wind
## of the moment, moved by its character's own difference from POLAR_15KT.md's 45 and its pointing
## offset (no footing off).
func _beat_twa_deg() -> float:
	var own_deg: float = config.upwind_vmg_twa_deg - POLAR_15KT_UPWIND_TWA_DEG
	return _best_upwind_twa_deg() + own_deg + config.pointing_offset_deg


## The polar's best wind angle to beat at in the wind of the moment, degrees (SkipperPolar).
func _best_upwind_twa_deg() -> float:
	return SkipperPolar.per_wind(_polar_winds, _polar_upwind, _sim.telemetry.tws_10m_kt)


## The wind angle it sails downwind (rule 4: its gybe angle read from the polar, not a constant):
## the polar's best angle to run at in the wind of the moment, moved by the character's own
## difference from POLAR_15KT.md's 135; and RUN_HEAD_UP_DEG higher while the board is off the plane
## (_off_plane), and no deeper than OFF_PLANE_TWA_DEG, which is how a sailor gets it planing again.
func _downwind_twa_deg() -> float:
	if _off_plane:
		return minf(_run_twa_deg() - RUN_HEAD_UP_DEG, OFF_PLANE_TWA_DEG)
	return _run_twa_deg()


## The wind angle it runs at once planing: the polar's best in the wind of the moment, moved by the
## character's own difference from POLAR_15KT.md's 135.
func _run_twa_deg() -> float:
	return _best_downwind_twa_deg() + config.downwind_vmg_twa_deg - POLAR_15KT_DOWNWIND_TWA_DEG


## The polar's best wind angle to run at in the wind of the moment, degrees (SkipperPolar).
func _best_downwind_twa_deg() -> float:
	return SkipperPolar.per_wind(_polar_winds, _polar_downwind, _sim.telemetry.tws_10m_kt)


## The penalty turn: a full circle, one tack and one gybe turning the same way round, so that the
## judge sees the heading sweep round and clears the penalty (RaceRules.FULL_TURN_DEG). First it eases
## down on its course (PENALTY_EASING); then the first manoeuvre: from a beam reach and further off the
## wind (PENALTY_GYBE_FIRST_FROM_TWA_DEG) the gybe, closer to the wind the tack
## (PENALTY_FIRST); then it gets going again on a reach (PENALTY_BETWEEN) and makes the other one
## (PENALTY_SECOND), bearing away for a gybe or heading up for a tack. The hands are pressed directly:
## the usual gating of manoeuvres (the reaction time, the tacks per beat) does not apply to a penalty.
func _penalty_turn_heading(telemetry: Telemetry) -> float:
	note = "penalty turn"
	var tack: float = _tack()
	var wind_deg: float = telemetry.wind_from_bearing_deg
	var free: bool = _controller.manoeuvre == PlayerController.Manoeuvre.NONE
	if _time_s - _penalty_from_s > PENALTY_TURN_GIVE_UP_S:
		_penalty_phase = 0  # given up for now; it is asked for again while the penalty stands
		return _last_wanted_deg
	match _penalty_phase:
		PENALTY_EASING:
			note = "penalty turn: easing down"
			_hands.hold_speed_ms = PENALTY_EASE_SPEED_MS
			if telemetry.speed_ms < PENALTY_START_BELOW_MS or _time_s - _penalty_from_s > PENALTY_EASE_LONGEST_S:
				_penalty_gybe_first = absf(telemetry.twa_deg) >= PENALTY_GYBE_FIRST_FROM_TWA_DEG
				_penalty_phase = PENALTY_FIRST
			return _last_wanted_deg
		PENALTY_FIRST:
			return _penalty_manoeuvre_heading(telemetry, _penalty_gybe_first, PENALTY_BETWEEN)
		PENALTY_BETWEEN:
			if not _penalty_manoeuvre_done(free):
				return _last_wanted_deg
			if telemetry.speed_ms < PENALTY_GOING_MS:
				# Getting going again on a reach before the other manoeuvre.
				note = "penalty turn: getting going"
				var reach_twa: float = maxf(absf(telemetry.twa_deg), _controller.auto_sheet_pilot.bear_away_twa_deg)
				return wind_deg - tack * minf(reach_twa, PENALTY_GYBE_FROM_TWA_DEG)
			_penalty_phase = PENALTY_SECOND
			return _penalty_manoeuvre_heading(telemetry, not _penalty_gybe_first, PENALTY_SECOND + 1)
		PENALTY_SECOND:
			return _penalty_manoeuvre_heading(telemetry, not _penalty_gybe_first, PENALTY_SECOND + 1)
		_:
			# The second manoeuvre pressed: round it comes; the judge clears the penalty when the circle
			# is complete, and the turn is over once the controller is done with it.
			if _penalty_manoeuvre_done(free):
				_penalty_phase = 0
				penalty_turns += 1
			return wind_deg - tack * (_upwind_twa_deg() if _penalty_gybe_first else PENALTY_GYBE_FROM_TWA_DEG)


## One manoeuvre of the penalty turn: the heading toward it, and the press once the board is there and
## the controller is free (then the phase becomes next_phase). A gybe: bearing away to
## PENALTY_GYBE_FROM_TWA_DEG held back to LOOP_AWAY_SPEED_MS (a gybe at 14 m/s put the sailor in the
## water), pressed from 15 degrees short of it. A tack: heading up to the beat's angle, pressed once
## closer to the wind than a beam reach and still moving at a walking pace and more (slower, it would
## stop in the tack).
func _penalty_manoeuvre_heading(telemetry: Telemetry, gybe: bool, next_phase: int) -> float:
	var tack: float = _tack()
	var wind_deg: float = telemetry.wind_from_bearing_deg
	var free: bool = _controller.manoeuvre == PlayerController.Manoeuvre.NONE
	if gybe:
		note = "penalty turn: the gybe"
		_hands.hold_speed_ms = LOOP_AWAY_SPEED_MS
		if free and absf(telemetry.twa_deg) >= PENALTY_GYBE_FROM_TWA_DEG - 15.0:
			_penalty_press(next_phase)
		return wind_deg - tack * maxf(PENALTY_GYBE_FROM_TWA_DEG, absf(telemetry.twa_deg))
	note = "penalty turn: the tack"
	if free and absf(telemetry.twa_deg) < 90.0 and telemetry.speed_ms > PENALTY_GOING_MS - 1.0:
		_penalty_press(next_phase)
	return wind_deg - tack * _upwind_twa_deg()


## Presses for the turn's manoeuvre now and moves on to the next phase.
func _penalty_press(next_phase: int) -> void:
	_hands.tack = true
	_penalty_pressed_s = _time_s
	_penalty_phase = next_phase


## Whether the manoeuvre last pressed for is over: the controller free again after it. One the
## controller did not begin (PENALTY_PRESS_AGAIN_S after the press, still free) is pressed again.
func _penalty_manoeuvre_done(free: bool) -> bool:
	if not free:
		return false
	if _manoeuvre_ended_s > _penalty_pressed_s:
		return true
	if _time_s - _penalty_pressed_s > PENALTY_PRESS_AGAIN_S:
		_penalty_phase -= 1
	return false


## Rule 6: another board close and getting closer makes it bear away a little (to pass to leeward
## of it), never deeper than the angle it runs at (deeper the board stops planing). The change of
## heading, degrees. With the judge (rules), only the board that must keep clear bears away, and
## only from the board it must keep clear of; a right-of-way board holds its course.
func _keep_clear_deg(telemetry: Telemetry, tack: float) -> float:
	# Not while it goes from its hold for the start: bearing away there slides the board along the
	# line, and it misses its spot (the rules apply, but a start is a start).
	if _going_from_hold:
		return 0.0
	# After the gun with the look-ahead on, keeping clear is _look_ahead_keep_clear()'s (in _think()).
	if config.keep_clear_by_passing and rules != null and _judged():
		return 0.0
	var position: Vector2 = _position(telemetry)
	var must_avoid: int = rules.burdened_by(_index) if rules != null else -2
	for j: int in _race.board_count():
		if j == _index:
			continue
		if must_avoid != -2 and j != must_avoid:
			continue
		var other: Vector2 = _race.board_position(j)
		var apart: Vector2 = other - position
		var other_velocity: Vector2 = (other - _others_last[j]) / _others_dt_s
		# It sees a board coming sooner the faster they close (its keep_clear_look_s of closing; 0: no), never later
		# than its character's keep_clear_m.
		var closing_ms: float = maxf(-apart.normalized().dot(other_velocity - _velocity), 0.0) if apart.length() > 0.01 else 0.0
		if apart.length() > maxf(config.keep_clear_m, closing_ms * config.keep_clear_look_s):
			continue
		if apart.dot(other_velocity - _velocity) < 0.0:
			_keeping_clear = true
			var up_room_deg: float = clampf(absf(telemetry.twa_deg) - KEEP_CLEAR_CLOSEST_TWA_DEG, 0.0, KEEP_CLEAR_HEAD_UP_DEG)
			var down_room_deg: float = clampf(_downwind_twa_deg() - absf(telemetry.twa_deg), 0.0, KEEP_CLEAR_BEAR_AWAY_DEG)
			var why: RaceRules.Why = rules.why(_index) if rules != null else RaceRules.Why.NONE
			if state == State.PRE_START:
				# Before the start it bears away whatever the rule: the course side is up the wind, and a
				# windward board heading up near the line went over it early (8 of 120 boards against 2).
				why = RaceRules.Why.NONE
			# Bearing away on starboard tack turns the bow to the left (the heading decreases); heading up
			# turns it to the right.
			if why == RaceRules.Why.WINDWARD_GIVES_WAY:
				return tack * up_room_deg
			if why == RaceRules.Why.ASTERN_GIVES_WAY or why == RaceRules.Why.MARK_ROOM:
				# Away from the side the other board is on: on the right (X east, Z south) the cross
				# product of the heading and the way to it is positive, so it turns left.
				var ahead: Vector2 = Course.direction_of(telemetry.heading_deg)
				var turn_right: bool = ahead.x * apart.y - ahead.y * apart.x < 0.0
				# A right turn on starboard tack is a head-up.
				var heading_up: bool = turn_right == (tack > 0.0)
				var turn_deg: float = minf(KEEP_CLEAR_SIDE_DEG, up_room_deg if heading_up else down_room_deg)
				return turn_deg if turn_right else -turn_deg
			return -tack * down_room_deg
	return 0.0


## Keeping clear by looking ahead (SkipperConfig.keep_clear_by_passing, after the gun; the skipper's heads,
## 8 November 2026: the judge names only boards within its NEAR_M, 15 m, a second and a half at the 10 m/s two
## crossing boards close at, so the old keep-clear always began too late): every board it must keep clear of by
## the rules as they stand (RaceRules.must_keep_clear_why(), at any distance) that would come within
## PASS_CLEAR_M over the next PASS_LOOK_S if both held their course (the other its velocity now, this one the
## heading it has decided at its speed, at least PASS_MIN_SPEED_MS). For those it turns just enough, on its tack,
## to pass them all with room (_passing_heading_deg()); with keep_clear_sharp it holds Shift for the turn. Not in
## a penalty turn, nor while a tack or gybe is asked for or under way. The heading, degrees.
func _look_ahead_keep_clear(telemetry: Telemetry, decided_deg: float) -> float:
	if not config.keep_clear_by_passing or rules == null or not _judged() or _penalty_phase > 0:
		return decided_deg
	if _tack_due_s >= 0.0 or _controller.manoeuvre != PlayerController.Manoeuvre.NONE:
		return decided_deg
	var tack: float = signf(wrapf(telemetry.wind_from_bearing_deg - decided_deg, -180.0, 180.0))
	if tack == 0.0:
		tack = _tack()
	var position: Vector2 = _position(telemetry)
	var speed_ms: float = maxf(telemetry.speed_ms, PASS_MIN_SPEED_MS)
	var mine: Vector2 = Course.direction_of(decided_deg) * speed_ms
	var my_mark: Vector2 = _mark_point(_index)
	# Every board it must keep clear of within reach counts for the heading it turns to (a board bearing away
	# behind one ran into another it had not counted: two penalties in the start rounds); the turn is made only
	# when one of them is in the way of the heading it decided.
	var aparts: PackedVector2Array = PackedVector2Array()
	var velocities: PackedVector2Array = PackedVector2Array()
	var in_the_way: bool = false
	for j: int in _race.board_count():
		if j == _index:
			continue
		var other: Vector2 = _race.board_position(j)
		var apart: Vector2 = other - position
		if apart.length() > PASS_LOOK_S * (speed_ms + PASS_OTHER_MAX_MS):
			continue
		var mark: Vector2 = my_mark if my_mark != Vector2.INF and _mark_point(j) == my_mark else Vector2.INF
		if rules.must_keep_clear_why(_index, j, mark) == RaceRules.Why.NONE:
			continue
		var other_velocity: Vector2 = (other - _others_last[j]) / _others_dt_s
		if _pass_room_m(apart, other_velocity - mine) < _pass_clear_m():
			in_the_way = true
		if config.pass_all_counted or _pass_room_m(apart, other_velocity - mine) < _pass_clear_m():
			aparts.append(apart)
			velocities.append(other_velocity)
	if not in_the_way:
		return decided_deg
	_keeping_clear = true
	_sharp_wanted = config.keep_clear_sharp
	note += ", passing clear"
	return _passing_heading_deg(telemetry, decided_deg, tack, speed_ms, aparts, velocities)


## Of the headings on its tack up to PASS_STEPS * PASS_STEP_DEG either way of the one it decided (no closer to
## the wind than KEEP_CLEAR_CLOSEST_TWA_DEG, no deeper than PASS_DEEPEST_TWA_DEG, none with less than
## PASS_SHORE_M of open water ahead), the one nearest it that passes every board in the way with PASS_CLEAR_M of
## room (bearing away first when two are as near); if none does, the one that passes widest. Degrees.
func _passing_heading_deg(telemetry: Telemetry, base_deg: float, tack: float, speed_ms: float,
		aparts: PackedVector2Array, velocities: PackedVector2Array) -> float:
	var wind_deg: float = telemetry.wind_from_bearing_deg
	var position: Vector2 = _position(telemetry)
	var best_deg: float = base_deg
	var best_k: int = 0
	var found: bool = false
	var widest_m: float = -1.0
	var widest_deg: float = base_deg
	# With pass_slow_down: the nearest heading that passes PASS_MIN_ROOM_M, for when none gives the full room.
	var some_k: int = 0
	var some_deg: float = base_deg
	var some_found: bool = false
	for k: int in range(-PASS_STEPS, PASS_STEPS + 1):
		var heading_deg: float = base_deg + k * PASS_STEP_DEG
		var twa_deg: float = wrapf(wind_deg - heading_deg, -180.0, 180.0)
		if absf(twa_deg) < KEEP_CLEAR_CLOSEST_TWA_DEG or absf(twa_deg) > PASS_DEEPEST_TWA_DEG or signf(twa_deg) != tack:
			continue
		if k != 0 and shore != null and shore.water_ahead_m(position, heading_deg, PASS_SHORE_M) < PASS_SHORE_M:
			continue
		var mine: Vector2 = Course.direction_of(heading_deg) * speed_ms
		var room_m: float = INF
		for n: int in aparts.size():
			room_m = minf(room_m, _pass_room_m(aparts[n], velocities[n] - mine))
		if room_m > widest_m:
			widest_m = room_m
			widest_deg = heading_deg
		if room_m >= PASS_MIN_ROOM_M and (not some_found or absi(k) < absi(some_k) or (absi(k) == absi(some_k) and k * tack < 0.0)):
			some_found = true
			some_k = k
			some_deg = heading_deg
		if room_m >= _pass_clear_m():
			# Bearing away on starboard tack lowers the heading (k < 0); on port it raises it.
			var nearer: bool = not found or absi(k) < absi(best_k) or (absi(k) == absi(best_k) and k * tack < 0.0)
			if nearer:
				found = true
				best_k = k
				best_deg = heading_deg
	if found:
		return best_deg
	if config.pass_slow_down:
		note += ", slowing"
		_hands.hold_speed_ms = maxf(PASS_SLOW_SHARE * telemetry.speed_ms, PASS_SLOW_MIN_MS)
		if some_found:
			return some_deg
	return widest_deg


## The room two boards pass with over the next PASS_LOOK_S, metres: the nearest they come, the other at
## `apart` moving at `closing` relative to this one; INF when they are not getting closer.
static func _pass_room_m(apart: Vector2, closing: Vector2) -> float:
	if apart.dot(closing) >= 0.0:
		return INF
	var at_s: float = clampf(-apart.dot(closing) / maxf(closing.length_squared(), 1e-6), 0.0, PASS_LOOK_S)
	return (apart + closing * at_s).length()


## How far the nearest other sailing board is, metres (INF: none).
func _nearest_board_m(telemetry: Telemetry) -> float:
	var position: Vector2 = _position(telemetry)
	var nearest_m: float = INF
	for j: int in _race.board_count():
		if j != _index and (rules == null or rules.is_sailing(j)):
			nearest_m = minf(nearest_m, position.distance_to(_race.board_position(j)))
	return nearest_m


## The room it passes another board with, metres: PASS_CLEAR_M, or its character's keep_clear_m with
## SkipperConfig.pass_room_from_sheet (a bold sailor passes close, a careful one wide: 8 to 20 m).
func _pass_clear_m() -> float:
	return config.keep_clear_m if config.pass_room_from_sheet else PASS_CLEAR_M


## True while the judge gives it penalties: racing or finished while the race goes on, and with
## SkipperConfig.keep_clear_from_gun also on its way to the start line after the gun (PRE_START lasts until the board crosses it; at the gun the boards going
## from their holds kept clear of nobody, and two of the first penalties came in the first two seconds; measured:
## as many penalties, the starts 2.7 s later).
func _judged() -> bool:
	if state == State.PRE_START:
		return config.keep_clear_from_gun and _race.clock_s() >= 0.0
	# Finished and sailing back while the others race, it still keeps clear (the judge still judges it: six of the
	# seven penalties of a T2 fleet race came after the boards had finished, though they no longer count).
	return _race.is_started() and _race.clock_s() >= 0.0 and _race.phase() != RaceSim.Phase.FINISHED


## Where a board's next mark is (Vector2.INF while it sails to a line or has finished): what mark room is
## judged by.
func _mark_point(index: int) -> Vector2:
	var step: RaceStep = _race.next_step(index)
	return step.points[0] if step != null and step.kind == RaceStep.Kind.MARK else Vector2.INF


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
	# With SkipperConfig.start_free_beyond_ends_m (the evening of 8 November 2026, boards dropped anywhere): far
	# out beyond an end the course side of the line's extension does not count as over. Beating up a slalom's
	# line along the wind from 300 m beyond its pin, every tack crossed the extension; each time the board
	# turned back behind it and dived again, and stalled at every turn. Over at the gun still counts.
	var over: bool = behind_m < 0.0
	if over and config.start_free_beyond_ends_m > 0.0 and _off_the_ends_m(step, position) > config.start_free_beyond_ends_m \
			and not (_race.is_ocs(_index) and not before_gun):
		over = false
	if over:
		_start_phase = StartPhase.BACK_BEHIND
	if _start_phase != StartPhase.BACK_BEHIND and _race.course.starts_upwind_of_the_boat():
		return _slalom_start_heading(telemetry, step, behind_m, spare_s)
	if _start_phase == StartPhase.BACK_BEHIND:
		if _race.is_ocs(_index) and _race.clock_s() >= 0.0:
			# Over the line at the gun: back round the nearer end, as the rules say.
			return _round_the_end_heading(telemetry, step)
		if over:
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
	var wait_at: Vector2 = _well_behind_the_line(step, _inside_area(go_point - track * (minf(hold_ms * wait_s, START_WAY_IN_MAX_M) + slowing_m)))
	# The time the way in can use up when it is sailed from the waiting point, held back as slowly as
	# the board steers well.
	var slowest_ms: float = minf(_controller.hold_back_steerage_ms + 0.5, hold_ms)
	var at_wait_s: float = wait_at.distance_to(go_point) * maxf(1.0 / slowest_ms - 1.0 / expected_ms, 0.0)
	# The timing loop: with more time to spare than the way in can use up, by more than a loop
	# costs; one who loops (LOOP) has a short way in, one who holds (HOLD) a long one.
	if _start_phase == StartPhase.RUN_IN and before_gun and not _reached_hold and not holds:
		# loop_within_away_max: not from start_away_max_m or farther from its spot (it would turn back at once).
		var beyond_away_max: bool = config.loop_within_away_max and config.start_away_max_m > 0.0 \
				and position.distance_to(spot) >= config.start_away_max_m
		if spare_s - START_GO_SPARE_S > at_wait_s + _loop_excess_s(track, forward) and not beyond_away_max:
			_start_phase = StartPhase.AWAY
	if _start_phase == StartPhase.AWAY:
		# The time it needs counts a turn (the way back is a reach on the other tack); a gybe from the
		# broad reach at speed costs START_GYBE_EXTRA_S more. It turns back with what the way in can
		# use up still to spare.
		# With start_away_max_m it turns back too once that far from its spot, however much time it has to spare.
		var too_far: bool = config.start_away_max_m > 0.0 and position.distance_to(spot) >= config.start_away_max_m
		if too_far or spare_s - START_GO_SPARE_S <= at_wait_s + START_LOOP_RETURN_S:
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
			if before_gun and behind_m < START_WALL_M and _velocity.dot(forward) > 0.3:
				# Its way to the waiting point runs at the line itself and it is near: it tacks (or gybes)
				# away, slow or not. On T2 in 12 kt the twenty, 60 m back in a column along a line that
				# runs with the wind, crawled at 1.5 m/s in each other's shadows beating up to their
				# waiting points, drifted over the line, could not tack back that slowly, and 9 of them
				# were over at the gun.
				_ask_for_manoeuvre(true, true)
				note += ", away from the line"
		else:
			free_deg = _late_for_the_spot_deg(telemetry, step, spot, behind_m)
		if before_gun:
			_keep_behind_the_line(telemetry, step, behind_m)
			if spare_s <= START_GO_SPARE_S and _too_early_at_the_line(telemetry, step, behind_m):
				# Late for its spot but about to cross the line elsewhere before the gun: it holds back
				# hard, and with the spot on the other tack it tacks (or gybes) there and then, slow or
				# not: holding back it soon sails too slowly to tack, and slid over the line instead (the
				# cautious one on T1 at 15 kt, 40 m behind the line for a 30 s countdown).
				_hands.hold_speed_ms = _slowest_hold_ms()
				note += ", holding back hard, early at the line"
				if signf(Navigation.wind_angle_deg(_position(telemetry), spot, telemetry.wind_from_bearing_deg)) != _tack() \
						or telemetry.speed_ms < _controller.hold_back_steerage_ms + 1.0:
					# (At a crawl, holding back cannot stop it: it turns away whichever side its spot is.
					# On T2 in 12 kt boards slowed to 1.5 m/s in the others' shadows drifted over the line.)
					_ask_for_manoeuvre(true, true)
		return free_deg
	# Where it will cross: its spot, when that is a reach on this tack (it came in on the way to it);
	# else where on the line it would arrive on time.
	# (Reachable at the angle it points once it has speed: a slow board's own angle is wider.)
	var spot_twa: float = Navigation.wind_angle_deg(position, spot, wind_deg)
	var cross_at: Vector2 = spot
	var at_speed_track_deg: float = _beat_twa_deg() + _leeway_deg
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
	elif (behind_m > START_GO_LATCH_M or _off_the_ends_m(step, position) > START_WALL_M) and go_spare_s > START_GO_HYSTERESIS_S:
		# (Out past an end of the line it is not near the line: 134 m past T1's end, 2 m behind the
		# extension, the rookie kept going at 12 m/s with 4 s to spare and slid over the line early.)
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
		_hands.hold_speed_ms = clampf(to_go_point_m / maxf(go_spare_s, 0.5), _slowest_hold_ms(), maxf(config.hold_speed_ms, _slowest_hold_ms()))
		note = "start: holding back (%+.1f s to spare)" % go_spare_s
		if past_go_point or early_at_line:
			_hands.hold_speed_ms = _slowest_hold_ms()
			note = "start: holding back hard, early (%+.1f s to spare)" % go_spare_s
		var hold_deg: float = _hold_heading(telemetry, hold_twa, run_in_tack, on_way + track * HOLD_CARROT_M)
		_keep_behind_the_line(telemetry, step, behind_m)
		return hold_deg
	_going_from_hold = true
	var go_deg: float = _course_to(telemetry, _through(position, cross_at))
	note = "start: go"
	# go_reach_twa_deg: slow off the hold, it first gets speed on a reach (no closer to the wind than that) and heads
	# up for the line once faster than GET_GOING_UNTIL_MS.
	if config.go_reach_twa_deg > 0.0 and telemetry.speed_ms < GET_GOING_UNTIL_MS:
		var go_twa: float = wrapf(wind_deg - go_deg, -180.0, 180.0)
		if signf(go_twa) == _tack() and absf(go_twa) < config.go_reach_twa_deg:
			go_deg = wind_deg - _tack() * config.go_reach_twa_deg
			note = "start: go, getting speed first"
	if not _crossing_on_this_tack:
		# No point of the line can be reached on this tack: near the line, sailing on to the
		# layline would take it past the end of the line. It tacks (or gybes) now.
		_ask_for_manoeuvre(true)
		note += ", the line is on the other tack"
	elif before_gun:
		_keep_behind_the_line(telemetry, step, behind_m)
	return go_deg


## A slalom's start (Course.RaceType.SLALOM; Max, 6 November 2026: "Start upwind of the startboat on a
## slalom race ... also easier for ai to train"): the race type tells it so; it does not guess from
## the line's shape. From its spot in the row upwind of the committee boat (RaceCourses.slalom_slot(),
## by its character's start spot: a boat-end skipper waits nearest the line), a broad reach down onto
## the line, crossing it where that reach meets it (_start_spot()). Before it is time it sails to its
## spot, slowing down as it comes near, and waits there luffed up, as slow as it steers; drifted
## SLALOM_PARK_RADIUS_M away it goes back. When the time it needs to its crossing is the time left
## (the gun plus its timing error) it bears away and goes, and it keeps going. Going and about to
## cross before the gun, it holds back hard and luffs up: on a line along the wind that runs it up
## along the line, not over it. On the course side before the gun, or over at the gun, the usual
## way back (_start_heading()).
##
## The reach down is sailed straight, as a broad reach on its tack (_slalom_dive_deg()), and timed as
## one (_time_to_cross_s()): steered by the navigation it was a run (deeper than the polar's best
## downwind angle in 17 kt), sailed off on the wrong gybe, and on T2 the fleet started 19 to 119 s late.
func _slalom_start_heading(telemetry: Telemetry, step: RaceStep, behind_m: float, _spare_s: float) -> float:
	var position: Vector2 = _position(telemetry)
	var wind_deg: float = telemetry.wind_from_bearing_deg
	var spot: Vector2 = _start_spot(step)
	var before_gun: bool = _race.clock_s() < 0.0
	var spare_s: float = -_race.clock_s() + config.start_timing_error_s - _time_to_cross_s(telemetry, spot)
	start_spare_s = spare_s
	if spare_s <= SLALOM_GO_SPARE_S or not before_gun:
		_going = true
	if _going:
		var go_deg: float = _slalom_dive_deg(telemetry, spot)
		note = "start: slalom, reaching down onto the line"
		if before_gun:
			if _too_early_at_the_line(telemetry, step, behind_m):
				_hands.hold_speed_ms = _slowest_hold_ms()
				# slalom_early_ease: it keeps the dive's heading and only eases, luffing up only in the last
				# SLALOM_LAST_LUFF_S before it would cross.
				var toward_ms: float = _velocity.dot(step.in_dir)
				var crossing_in_s: float = behind_m / toward_ms if toward_ms > 0.3 else INF
				if config.slalom_early_ease and crossing_in_s > SLALOM_LAST_LUFF_S:
					note += ", early: easing"
				else:
					go_deg = wind_deg - _tack() * (HOLD_LUFF_TWA_DEG + 2.0 * config.steering_noise_deg)
					note += ", early: luffing up"
			_keep_behind_the_line(telemetry, step, behind_m)
		return go_deg
	var slot: Vector2 = _slalom_slot()
	var to_slot_m: float = position.distance_to(slot)
	var heading_deg: float
	if to_slot_m > SLALOM_PARK_RADIUS_M:
		heading_deg = _course_to(telemetry, slot, 0.0, true)
		note = "start: to its spot upwind of the boat"
		if to_slot_m < SLALOM_SLOW_FROM_M:
			_hands.hold_speed_ms = clampf(to_slot_m / 6.0, _slowest_hold_ms() + 1.0, maxf(config.hold_speed_ms, 4.0))
	else:
		# Waiting: luffed up, as slow as it steers, on the tack of its reach down (so that going is a
		# bear-away, not a gybe at a crawl: waiting on the other tack, Greta gybed late, ran off on
		# the wrong gybe and started 17 s late on iq_pd3).
		_hands.hold_speed_ms = _slowest_hold_ms()
		heading_deg = wind_deg - _tack() * (HOLD_LUFF_TWA_DEG + 2.0 * config.steering_noise_deg) + _keep_clear_deg(telemetry, _tack())
		note = "start: waiting upwind of the boat"
		var dive_tack: float = signf(Navigation.wind_angle_deg(position, spot, wind_deg))
		if dive_tack != 0.0 and _tack() != dive_tack and behind_m > START_WALL_M:
			_ask_for_manoeuvre(true)
			note += ", onto the tack of its reach down"
	_keep_behind_the_line(telemetry, step, behind_m)
	return heading_deg


## The heading of a slalom's reach down onto the line: straight through its crossing when that is
## a reach on its present tack (between SLALOM_DIVE_CLOSEST_TWA_DEG and SLALOM_DIVE_DEEPEST_TWA_DEG
## from the wind), so that the navigation does not sail it as a run with gybes. Deeper than that it
## sails the deepest of them (a line along the wind is met a little further down); bearing away
## further, Hana's board went through the wind's eye onto the other gybe and started 15 s late on
## iq_pd3. On the other tack it turns onto the reach's tack at once; a beat is sailed the
## navigation's way.
func _slalom_dive_deg(telemetry: Telemetry, spot: Vector2) -> float:
	var position: Vector2 = _position(telemetry)
	var through: Vector2 = _through(position, spot)
	var wind_deg: float = telemetry.wind_from_bearing_deg
	var needed_twa: float = Navigation.wind_angle_deg(position, through, wind_deg)
	if absf(needed_twa) < SLALOM_DIVE_CLOSEST_TWA_DEG:
		return _course_to(telemetry, through)
	if signf(needed_twa) != _tack():
		# On the other tack: it turns onto the reach's tack now, not later on a run's layline.
		# slalom_dive_gybes: from a reach or deeper by a gybe (bearing away first): asked for at once at a beam reach
		# the controller tacked, and a tack at speed in a strong wind stopped in the wind's eye.
		if config.slalom_dive_gybes and absf(telemetry.twa_deg) >= SLALOM_DIVE_GYBE_FROM_TWA_DEG:
			return _gybe_now(telemetry)
		_ask_for_manoeuvre(true)
		return wind_deg - _tack() * absf(telemetry.twa_deg)
	if absf(needed_twa) > SLALOM_DIVE_DEEPEST_TWA_DEG:
		return wind_deg - _tack() * SLALOM_DIVE_DEEPEST_TWA_DEG + _keep_clear_deg(telemetry, _tack())
	return Course.bearing_deg(position, through) + _keep_clear_deg(telemetry, _tack())


## Its spot in a slalom's waiting row upwind of the committee boat, inside the sailing area.
func _slalom_slot() -> Vector2:
	return _inside_area(RaceCourses.slalom_slot(_race.course, config.start_spot))


## Late for its start, or with no time to spare: for its spot. When the spot is a reach on this tack
## it sails through it at speed. When it is a beat, it beats to the spot itself, as to a mark, and
## tacks on the spot's layline with no margin, because the line ends a few metres beyond the spot:
## aimed through the line (a point that moves with the board) and with its character's layline
## margin, a noisy skipper on the polar's wider beat overstood, ran up behind T1's line past its end
## and was over at the gun (the rookie from 150 m at 18 kt).
func _late_for_the_spot_deg(telemetry: Telemetry, step: RaceStep, spot: Vector2, behind_m: float) -> float:
	var position: Vector2 = _position(telemetry)
	var needed_twa: float = Navigation.wind_angle_deg(position, spot, telemetry.wind_from_bearing_deg)
	var laid: bool = signf(needed_twa) == _tack() and absf(needed_twa) >= _pointing_twa_deg() + _leeway_deg
	if laid:
		var through_deg: float = _course_to(telemetry, _through(position, spot), 0.0, true)
		note = "start: for the spot"
		return through_deg
	var beat_deg: float = _course_to(telemetry, spot, 0.0, true, 0.0)
	note = "start: for the spot, beating (%s)" % note
	return beat_deg


## How much more time to spare than the way in can use up makes a skipper who loops sail its timing loop, seconds:
## START_LOOP_EXCESS_S; with SkipperConfig.reaching_loop_excess_s, that on a line its hold's track runs at (a reaching
## start: the line along the wind), where the time the way in cannot use up brings it to the line early.
func _loop_excess_s(hold_track: Vector2, forward: Vector2) -> float:
	if config.reaching_loop_excess_s > 0.0 and absf(hold_track.dot(forward)) >= REACHING_HOLD_ACROSS:
		return config.reaching_loop_excess_s
	return START_LOOP_EXCESS_S


## The speed it holds back to, m/s: its character's hold speed, or what it has found it gets down to
## in this wind if that is faster.
func _hold_speed_ms() -> float:
	return maxf(config.hold_speed_ms, _held_ms)


## The slowest it holds back to before the start, m/s: the controller's steerage speed, or its
## character's hold_floor_ms if that is faster (boards held back to a standstill fell at the start).
func _slowest_hold_ms() -> float:
	return maxf(_controller.hold_back_steerage_ms, config.hold_floor_ms)


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
	# A beat only if it is one at speed (_beat_twa_deg(), no footing off): going from a hold the board
	# gains speed and points higher. Judged with the slow board's foot, a point a reach away was
	# counted a beat with a tack in it, the time to it came out 7 s long, and the gambler went 7 s
	# early and slid down the line past its end (16 boards from random spots on T1 at 15 kt).
	if signf(needed_twa) != _tack() or absf(needed_twa) - _leeway_deg < _beat_twa_deg():
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
	return clampf(lerpf(0.65, 1.45, (_sim.telemetry.tws_10m_kt - 12.0) / 6.0), 0.65, 1.75) * config.start_accel_share


## True when the board, at the speed it has toward the start line, would cross it within
## START_GUARD_S, START_GUARD_MARGIN_S or more before the gun.
func _too_early_at_the_line(telemetry: Telemetry, step: RaceStep, behind_m: float) -> bool:
	# The board's track over the ground, not its bow: held back to 2 m/s it slips sideways by 6 to 16
	# degrees, and on T2 in 24 kt the bow ran along the line while the track crossed it before the gun.
	var toward_ms: float = _velocity.dot(step.in_dir)
	if toward_ms <= 0.3:
		return false
	var crossing_in_s: float = behind_m / toward_ms
	if crossing_in_s >= START_GUARD_S or crossing_in_s >= -_race.clock_s() + START_GUARD_MARGIN_S:
		return false
	# Only a crossing of the line itself: the extension past an end is _keep_behind_the_line()'s.
	var crossing: Vector2 = _position(telemetry) + _velocity * crossing_in_s
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


## A waiting point moved back to at least START_WAIT_BEHIND_M behind the start line or its extensions,
## metres: a way in along the line, out past its end, put it 20 m behind the extension, and the turn
## onto the way in at speed (a tack, toward the wind) took 16 of them (the rookie on T1 at 24 kt).
func _well_behind_the_line(step: RaceStep, point: Vector2) -> Vector2:
	var behind_m: float = -RoundingCheck.over_line_m(point, step.points[0], step.points[1], step.in_dir)
	if behind_m >= START_WAIT_BEHIND_M:
		return point
	# Back against the leg's direction, which crosses the line at a slant on some courses.
	var across_share: float = RoundingCheck.over_line_m(point + step.in_dir, step.points[0], step.points[1], step.in_dir) + behind_m
	return _inside_area(point - step.in_dir * (START_WAIT_BEHIND_M - behind_m) / maxf(across_share, 0.3))


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
## the points it can reach on a reach on its present tack at speed (no tack, no beat), the one it would reach
## soonest without being early; when it would be early at every one of them, the one it reaches
## last; with none on this tack, the nearest point of the line (on the other tack, or a beat).
func _choose_crossing(telemetry: Telemetry, step: RaceStep, aim_s: float) -> Vector2:
	var position: Vector2 = _position(telemetry)
	var wind_deg: float = telemetry.wind_from_bearing_deg
	var tack: float = _tack()
	# (Reachable at the angle it points once it has speed, as in _time_to_cross_s().)
	var up_track_deg: float = _beat_twa_deg() + _leeway_deg
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


## The point of a line (the start or the finish) nearest a position, kept a few metres in from the
## ends.
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
	var run_in: Vector2 = Course.direction_of(wind_deg - _start_run_in_tack(step, wind_deg) * _run_in_twa_deg())
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
		var on_starboard: float = from_spot.dot(Course.direction_of(wind_deg - _run_in_twa_deg()))
		var on_port: float = from_spot.dot(Course.direction_of(wind_deg + _run_in_twa_deg()))
		_run_in_tack = 1.0 if on_starboard <= on_port else -1.0
		if Course.direction_of(wind_deg - _run_in_tack * _run_in_twa_deg()).dot(step.in_dir) <= 0.3:
			_run_in_tack = -_run_in_tack
	return _run_in_tack


## The wind angle of the run in on an upwind start, degrees: START_RUN_IN_ABOVE_BEAT_DEG wider than the
## angle it beats at, between START_RUN_IN_TWA_DEG and START_RUN_IN_WIDEST_TWA_DEG; chosen once, at the
## countdown's first look (a gust would otherwise move its go point about).
func _run_in_twa_deg() -> float:
	if _run_in_twa == 0.0:
		_run_in_twa = clampf(_beat_twa_deg() + START_RUN_IN_ABOVE_BEAT_DEG, START_RUN_IN_TWA_DEG, START_RUN_IN_WIDEST_TWA_DEG)
	return _run_in_twa


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
## 24 kt row).
func _polar_speed_ms(twa_deg: float) -> float:
	return SkipperPolar.value_at(_polar_winds, _polar_twa, _polar_speeds, _sim.telemetry.tws_10m_kt, twa_deg)


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
	_hands.sharp = false
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
	# crawl_no_head_up_ms: before its start, not holding back, stuck in the crawl (slower than that, the stick asking to
	# head up by more than CRAWL_ERROR_DEG for crawl_stuck_s) it lets go of the stick toward the wind until it has speed
	# (bearing away it still may). A head-up at a crawl that works (off the shore, back behind the line) is left alone.
	# Not on a slalom's start (waiting upwind of the boat, the dive down onto the line): its crawl comes after its own
	# luff-up, and the first on/off test (s2) broke three slalom starts there. Not while the shore lookout steers: let
	# go there, a board gathered speed on a heading into the shore (s2c's hold-out, r0091).
	var heading_up: bool = signf(error_deg) == _tack()
	if config.crawl_no_head_up_ms > 0.0 and state == State.PRE_START and _hands.hold_speed_ms <= 0.0 \
			and not _race.course.starts_upwind_of_the_boat() and not _shore_steers:
		if _crawling:
			if telemetry.speed_ms > config.crawl_no_head_up_ms + CRAWL_RELEASE_EXTRA_MS:
				_crawling = false
				_crawl_stuck_from_s = -1.0
		elif telemetry.speed_ms < config.crawl_no_head_up_ms and heading_up and absf(error_deg) > CRAWL_ERROR_DEG:
			if _crawl_stuck_from_s < 0.0:
				_crawl_stuck_from_s = _time_s
			elif _time_s - _crawl_stuck_from_s >= (config.crawl_go_stuck_s if _going_from_hold and config.crawl_go_stuck_s >= 0.0 else config.crawl_stuck_s):
				_crawling = true
		else:
			_crawl_stuck_from_s = -1.0
		if _crawling and heading_up:
			return
	else:
		_crawling = false
		_crawl_stuck_from_s = -1.0
	var stick_limit: float = 1.0
	# Heading up turns right on starboard tack and left on port tack. At speed a sailor heads up
	# gently, so the sheet keeps up with the growing pull (heading up from a broad reach at 13 m/s
	# in 24 kt with the controller's full head-up rate pulled the sailor over the front).
	if signf(error_deg) == _tack() and telemetry.speed_ms > GENTLE_HEAD_UP_FROM_MS:
		stick_limit = GENTLE_HEAD_UP_STICK
	_hands.steer = clampf(error_deg / FULL_STICK_ERROR_DEG, -stick_limit, stick_limit)
	# The Shift carve for a turn that must be quick (keeping clear): about twice the turn rate.
	_hands.sharp = _sharp_wanted and absf(error_deg) >= SHARP_ERROR_DEG
	if config.turn_sharp and absf(error_deg) >= SHARP_TURN_DEG and stick_limit >= 1.0:
		_hands.sharp = true
	if telemetry.speed_ms < SHARP_FROM_MS:
		_hands.sharp = false


## The push slider as a good sailor sets it (AiHands.push, 0 to 1): the polar's level for the wind
## angle it sails in the wind of the moment where the polar says pushing paid, moved by its
## character's push_offset; where the polar does not push, the level that holds the pilot's own pull
## moved by the offset (a character that pushes harder, or sails more carefully, off the wind: not
## closer than PUSH_UPWIND_TWA_DEG, where the pilot's margin is fastest and safest, and not while it
## turns onto a new course, PUSH_TURN_DEG). NaN, the
## pilot's own margin without the slider (which the hands hand back to the controller): where neither
## asks for a push, from the moment a tack or gybe is asked for until the board has settled after it,
## in the last PUSH_EASE_BEFORE_MARK_S before a mark, and when it does not set the push at all
## (push_wanted). (The game's polar pushes nowhere today: pushed on the 18 and 24 kt reaches, where
## the steady runs gained 4 to 5 %, the all-rounder fell two to seven times a race at 24 kt and won
## nothing at 18; at the pilot's own margin it did not fall. See skipper_speed.md.)
func _push_level(telemetry: Telemetry) -> float:
	if not push_wanted:
		return NAN
	var turning: bool = _tack_due_s >= 0.0 or _controller.manoeuvre != PlayerController.Manoeuvre.NONE or _settling
	if turning or _near_a_mark(telemetry):
		return NAN
	if config.push_everywhere >= 0.0:
		return clampf(config.push_everywhere, 0.0, 1.0)
	var level: float = SkipperPolar.push_at(_polar_winds, _polar_twa, _polar_push, telemetry.tws_10m_kt, telemetry.twa_deg)
	if is_nan(level):
		if config.push_offset == 0.0 or absf(telemetry.twa_deg) < PUSH_UPWIND_TWA_DEG or _turning_onto_a_course(telemetry):
			return NAN
		level = LearnedSkipper.pilot_margin_level()
	return clampf(level + config.push_offset, 0.0, 1.0)


## True while its heading is more than PUSH_TURN_DEG from the heading it decided on: it is turning.
func _turning_onto_a_course(telemetry: Telemetry) -> bool:
	return absf(wrapf(_last_wanted_deg - telemetry.heading_deg, -180.0, 180.0)) > PUSH_TURN_DEG


## Its hand on the push slider: toward the level it wants (_push_level()) at PUSH_RATE_PER_S. Taking
## the slider, it starts from the level that holds the pilot's own pull (LearnedSkipper.
## pilot_margin_level(), about 78 %); letting go, it brings the slider back down to that level first
## and then hands it back (NaN), so the pilot's numbers hardly jump either way.
func _move_the_push(telemetry: Telemetry, dt: float) -> float:
	var wanted: float = _push_level(telemetry)
	var margin: float = LearnedSkipper.pilot_margin_level()
	if is_nan(wanted):
		if is_nan(_push_now):
			return NAN
		_push_now = move_toward(_push_now, margin, PUSH_RATE_PER_S * dt)
		if absf(_push_now - margin) < 1e-4:
			_push_now = NAN
		return _push_now
	_push_now = move_toward(margin if is_nan(_push_now) else _push_now, wanted, PUSH_RATE_PER_S * dt)
	return _push_now


## Racing, within PUSH_EASE_BEFORE_MARK_S of the next mark at its speed.
func _near_a_mark(telemetry: Telemetry) -> bool:
	if state != State.RACING:
		return false
	var step: RaceStep = _race.next_step(_index)
	if step == null or step.kind != RaceStep.Kind.MARK:
		return false
	return _position(telemetry).distance_to(step.points[0]) < telemetry.speed_ms * PUSH_EASE_BEFORE_MARK_S


## Decides on a tack or gybe (the controller chooses which from the wind angle), to be asked for
## after the reaction time. Not while one is under way or waiting, not soon after the last, not past
## the cap on this leg unless it is needed to reach the target (a layline), and no tack while the board
## is too slow to point unless even_slow says so.
func _ask_for_manoeuvre(needed: bool, even_slow: bool = false) -> void:
	if _tack_due_s >= 0.0 or _controller.manoeuvre != PlayerController.Manoeuvre.NONE or _settling:
		return
	# Away from a tack that did not go (_change_a_tack_that_does_not_go()): it keeps this tack for a while, unless
	# the shore says otherwise.
	if _time_s < _prefer_until_s and _tack() == _prefer_tack and not note.contains("shore"):
		return
	if _time_s - _manoeuvre_ended_s < MIN_TACK_INTERVAL_S or not (_pointing or even_slow) and absf(_sim.telemetry.twa_deg) < 90.0:
		return
	if not needed and _manoeuvres_here() >= config.max_tacks_per_beat:
		return
	if state == State.RACING and _sim.telemetry.speed_ms < SLOW_TURN_MS 			and absf(_sim.telemetry.twa_deg) > _controller.tack_up_to_twa_deg - SLOW_TURN_MARGIN_DEG:
		# Too slow for a gybe to come off: head up and tack instead (_slow_turn()).
		if _slow_turn_from_s < 0.0:
			_slow_turn_from_s = _time_s
		return
	if config.tack_traffic_check and _judged() and rules != null and not note.contains("shore") \
			and _traffic_on_the_new_tack():
		if _time_s - _traffic_seen_s > TRAFFIC_FORGET_S:
			_traffic_wait_from_s = _time_s
		_traffic_seen_s = _time_s
		if _time_s - _traffic_wait_from_s < TRAFFIC_WAIT_MAX_S:
			note += ", waiting for traffic"
			return
	_tack_due_s = _time_s + config.reaction_time_s


## True when a tack or gybe now would put it on port tack in a starboard board's way (tack_traffic_check):
## on the new tack's course (the beat or the run), after a tack at TRAFFIC_TACK_SPEED_MS, after a gybe at its
## speed, it would pass a sailing starboard board with less than PASS_CLEAR_M over the next PASS_LOOK_S.
func _traffic_on_the_new_tack() -> bool:
	var telemetry: Telemetry = _sim.telemetry
	var tack: float = _tack()
	if tack < 0.0:
		return false
	var upwind: bool = absf(telemetry.twa_deg) < 90.0
	var new_deg: float = telemetry.wind_from_bearing_deg + tack * (_upwind_twa_deg() if upwind else _downwind_twa_deg())
	var speed_ms: float = TRAFFIC_TACK_SPEED_MS if upwind else maxf(telemetry.speed_ms, PASS_MIN_SPEED_MS)
	var mine: Vector2 = Course.direction_of(new_deg) * speed_ms
	var position: Vector2 = _position(telemetry)
	for j: int in _race.board_count():
		if j == _index or not rules.is_sailing(j) or rules.board_tack(j) < 0.0:
			continue
		var other: Vector2 = _race.board_position(j)
		var apart: Vector2 = other - position
		if apart.length() > PASS_LOOK_S * (speed_ms + PASS_OTHER_MAX_MS):
			continue
		var other_velocity: Vector2 = (other - _others_last[j]) / _others_dt_s
		if _pass_room_m(apart, other_velocity - mine) < _pass_clear_m():
			return true
	return false


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
	_watch_the_speed(telemetry, dt)
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
	# Downwind feel: off the plane below OFF_PLANE_SHARE of the polar's speed at the best downwind
	# angle, planing again above ON_PLANE_SHARE of it.
	var planing_ms: float = _polar_speed_ms(_best_downwind_twa_deg())
	if absf(telemetry.twa_deg) > 110.0 and telemetry.speed_ms < OFF_PLANE_SHARE * planing_ms:
		_off_plane = true
	elif telemetry.speed_ms > ON_PLANE_SHARE * planing_ms:
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
		_rounding_early = false
		_gate_end = -1
		# A tack decided for the last step is not one for this; but the gybe round a slalom mark (gybe_at_mark) is the
		# turn onto the next leg, and the rounding counts while it waits for the hands.
		if not _gybing_at_mark:
			_tack_due_s = -1.0
		_gybing_at_mark = false


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
