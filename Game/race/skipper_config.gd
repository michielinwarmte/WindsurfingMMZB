class_name SkipperConfig
extends Resource
## The character sheet of a scripted skipper (RACING_PLAN.md, "The scripted skipper (9B)"): the
## numbers that make one opponent different from another. A weaker skipper has worse numbers here
## (a longer reaction time, a noisier helm, bigger margins); nobody gets a lighter board or more
## wind (decision RD7). One .tres per character in Game/race/skippers/, so the team can edit a
## skipper in the inspector. The rules that use these numbers are in Skipper.

## The start plans (start_style below).
enum StartStyle { LOOP, HOLD }

## Shown on the label, the results and the mini-map. The four shipped characters have placeholder
## names; the team names them.
@export var name: String = "Skipper"
## The colour of its sail, for the scene and the mini-map.
@export var sail_colour: Color = Color(0.9, 0.3, 0.2)

@export_group("Angles")
## The best upwind wind angle at 15 kt: where the boat's speed toward the wind (VMG) is highest. From
## Documentation/POLAR_15KT.md: 45 degrees gives 8.0 kt of VMG at 15 kt of wind, more than 40
## (7.8 kt) or 60 (7.0 kt). The skipper beats at its polar's best angle for the wind of the moment
## (SkipperPolar: wider in light wind); this sheet's difference from 45 moves that angle.
@export_range(35.0, 70.0) var upwind_vmg_twa_deg: float = 45.0
## The best downwind wind angle at 15 kt: where the boat's speed away from the wind is highest. From
## Documentation/POLAR_15KT.md: 135 degrees gives 13.4 kt of VMG, more than 120 (12.7 kt) or 150
## (10.3 kt, the board comes off the plane). The skipper runs at its polar's best angle for the wind
## of the moment; this sheet's difference from 135 moves that angle.
@export_range(110.0, 170.0) var downwind_vmg_twa_deg: float = 135.0
## Sails higher than the polar's best upwind angle (negative) or lower and faster (positive).
@export_range(-4.0, 6.0) var pointing_offset_deg: float = 0.0

@export_group("Margins")
## How far past the layline it sails before tacking or gybing, metres. A small margin means a
## risk of not laying the mark (and two more tacks); a big one sails extra distance.
@export_range(0.0, 60.0) var layline_margin_m: float = 10.0
## The margin past the layline for the last tack of a beat into a mark only, metres (Skipper._course_to());
## -1: layline_margin_m, as before. The suite's baseline_A (8-9 November 2026, 212 beats into a mark): the last tack
## a median 31 m beyond the board's own layline (70 % over 25 m), of which layline_margin_m's 10 m is chosen.
@export_range(-1.0, 60.0) var mark_layline_margin_m: float = -1.0
## How close it rounds a mark, metres.
@export_range(4.0, 20.0) var mark_margin_m: float = 8.0
## Starts the turn round a mark or through a gate before it gets there, as a sailor goes wide in and tight out
## (Skipper._round_early_deg()): it works out the arc it would sail turning onto the next leg now, and turns as
## soon as that arc still rounds the mark (or crosses the gate) with Skipper.ROUND_EARLY_CLEAR_M to spare. Only a
## turn on the same tack (not the gybe round a slalom mark). Off: it turns only once the race has counted the
## rounding. The suite's baseline_A (8 November 2026, 94 races): about 5 degrees of the turn before the mark and
## the whole turn after it; out of the turn median 30 m (92 % over 15 m): 35 m at a windward mark, 51 m at a
## leeward mark or gate onto a beat.
@export var round_early: bool = false
## At a mark whose next leg is on the other gybe (a slalom mark), it gybes round the mark instead of after it
## (Skipper._round_early_deg()): once the gybe's arc (at the controller's gybe rate) would round the mark with
## Skipper.ROUND_GYBE_CLEAR_M to spare, it bears away past the controller's tacking angle and asks for the gybe. Off:
## after the rounding counted it bore away on the old gybe and gybed only past the gybing line by layline_margin_m.
## baseline_A (8 November 2026): 35 slalom roundings, out of the turn median 48 m; one (r0014, SD3 at 50 %) came out
## of the gybe 5 s after the mark at 1.3 m/s, from 10 m/s.
@export var gybe_at_mark: bool = false
## The most tacks (or gybes) it makes on one leg. The layline tack is always allowed, so the cap
## limits the extra ones (for wind shifts).
@export_range(2, 8) var max_tacks_per_beat: int = 4

@export_group("Push")
## Pushes harder (positive) or less (negative) than the polar's push slider level for each point of
## sail and wind (SkipperPolar.push_level), as a share of the slider (0.1 is ten points of it). More
## push is faster and falls more. The personas' risk and boat speed can set it (RA6).
@export_range(-0.5, 0.5) var push_offset: float = 0.0
## An experiment (Max, 8 November 2026: his 9:43 on SM1 at full push with the body, the fleet's best 11:30): the
## push slider held at this level on every point of sail, upwind too (not in a manoeuvre or before a mark, as
## the polar's push). -1: off, the polar's push as before.
@export var push_everywhere: float = -1.0

@export_group("Hands")
## The delay between seeing and doing, seconds: every decision reaches the stick this late.
@export_range(0.2, 1.0) var reaction_time_s: float = 0.3
## The wobble of its line: its wanted heading wanders by about this much (one standard
## deviation), slowly, degrees.
@export_range(0.0, 6.0) var steering_noise_deg: float = 0.5

@export_group("Getting going")
## The wind angle it sails on its tack while it is stuck slow (Skipper.GET_GOING_*: on the board but
## under 2.5 m/s for 6 s, after the gun), degrees, until it has speed again; 0 leaves the angle to the
## race as before. Light wind on Silvaplana stopped boards on a beat or a slow broad reach, and there the
## auto-sheet holds only as much sail as the sailor can hold at a standstill, so they never got going
## and fell again and again (the skipper's heads, 8 November 2026). Measured by tools/heads.
@export_range(0.0, 150.0) var get_going_twa_deg: float = 0.0
## At the start's go, slower than Skipper.GET_GOING_UNTIL_MS (just off its hold), it sails no closer to the wind than
## this angle on its tack, degrees, until it has speed, and only then heads up for the line (Skipper._start_heading());
## 0: straight onto the course for the line, as before. The suite (9 November 2026, r0007 of the hold-out, the lake,
## 15 kt): off the hold at 2 m/s on a beam reach, the course for the line was higher; the stick held hard toward the
## wind for 30 s did not turn the board at that speed and spilled the sail (angle of attack 3 to 5 deg): 2 m/s for 40 s,
## 58 s late. get_going_twa_deg (after the gun, any slow board) measured too: start 70 -> 72 %, but legs 92 -> 88 %.
@export_range(0.0, 150.0) var go_reach_twa_deg: float = 0.0

@export_group("Start")
## Where on the start line it wants to cross: 0 = the pin end, 1 = the boat end.
@export_range(0.0, 1.0) var start_spot: float = 0.5
## Its timing error at the start, seconds: negative aims to cross before the gun (a risk of being
## over early, OCS), positive after it (safe, but metres lost).
@export_range(-3.0, 6.0) var start_timing_error_s: float = 0.5
## How keen it is on the favoured end of the line (the end nearer the wind, AI_FLEET_PLAN.md D4),
## 0 to 1: 0 starts at its own start_spot whatever the line; 1 goes all the way to the favoured
## end once the line is skewed by Skipper.FULL_BIAS_DEG or more (less of the way on a line that is
## nearly square to the wind, where the ends are nearly as good).
@export_range(0.0, 1.0) var favoured_end_bias: float = 0.5
## Its start plan (AI_FLEET_PLAN.md, D4): a timing loop (sail away from the line on a reach and
## turn back to reach it at the gun at full speed), or a hold (come to the line early, luff and
## ease the sheet near it to wait without stopping, then bear away and sheet in for the gun).
@export var start_style: StartStyle = StartStyle.LOOP
## The slowest it holds back to before the start, m/s (2 to 3 m/s keeps the fin gripping: below
## 1.5 m/s the board cannot be steered and rounds up into the wind). A slower hold uses up more time
## on a shorter way in to the line.
@export_range(1.5, 4.0) var hold_speed_ms: float = 2.5
## The slowest it ever holds back to before the start, m/s; 0 is the controller's steerage speed (1.5).
## Held back that slowly in Silvaplana's chop, boards stopped and fell at the start (the skipper's heads,
## 8 November 2026); measured on the start suite (tools/heads).
@export_range(0.0, 4.0) var hold_floor_ms: float = 0.0
## How fast it reckons the board gains speed going from a hold, as a share of the open water's measured
## rate (Skipper._acceleration_ms2()): below 1 it goes earlier. On Silvaplana the sharp starters, aiming
## close to the gun, were the ones that crossed 30 to 50 s late (the skipper's heads, 8 November 2026).
@export_range(0.4, 1.5) var start_accel_share: float = 1.0

@export_group("Company")
## Another board this close, metres, and getting closer, makes it bear away to keep clear (when it
## is the one that must, under the rules). An aggressive skipper lets others come closer.
@export_range(5.0, 30.0) var keep_clear_m: float = 15.0
## It starts keeping clear this many seconds before a board closing on it would reach it (at least at
## keep_clear_m): two boards crossing at 8 m/s close 15 m in a second, too late to duck behind (the
## skipper's heads, 8 November 2026: port and starboard penalties in the fleet races). 0 is as before.
@export_range(0.0, 8.0) var keep_clear_look_s: float = 0.0
## After the gun, the board that must keep clear works out where the two boards will be over the next
## seconds and turns just enough (either way, on its tack) to pass with room (Skipper._passing_turn_deg())
## instead of a fixed head-up or bear-away. Off: as before. The skipper's heads, 8 November 2026: the port
## and starboard penalties were fast port boards running into a starboard board stopped in the crowd.
@export var keep_clear_by_passing: bool = true
## Holds Shift (the carve, about twice the turn rate; Max, 8 November 2026) for a keep-clear turn of more than a
## few degrees (Skipper.SHARP_ERROR_DEG). Off: as before.
@export var keep_clear_sharp: bool = true
## After the gun, a tack or gybe that would put it on port tack in a starboard board's way waits a few seconds
## (Skipper.TRAFFIC_WAIT_MAX_S; never at the shore). Off: as before.
@export var tack_traffic_check: bool = true
## Holds Shift (the carve) for any turn of Skipper.SHARP_TURN_DEG or more (the bear-away at a mark, a course
## change), except a head-up faster than Skipper.GENTLE_HEAD_UP_FROM_MS. Off: only keep_clear_sharp's turns.
@export var turn_sharp: bool = false
## With keep_clear_by_passing, the room it passes another board with is its keep_clear_m (a bold sailor close,
## a careful one wide) instead of Skipper.PASS_CLEAR_M. Off: as before.
@export var pass_room_from_sheet: bool = false
## With keep_clear_by_passing, the heading it turns to passes every board it must keep clear of within reach, not
## only the ones in the way of the heading it decided. Off: as before.
@export var pass_all_counted: bool = true
## A penalty turn waits until no other board is near (Skipper.PENALTY_CLEAR_M; at most Skipper.PENALTY_WAIT_MAX_S),
## as sailors get clear before turning their circle. Off: it turns at once.
@export var penalty_when_clear: bool = true
## The look-ahead and the traffic check also on its way to the start line after the gun (not only once it has
## crossed it). Off: from the line on.
@export var keep_clear_from_gun: bool = false
## With keep_clear_by_passing, when no heading passes with the full room: the smallest turn that still passes a few
## metres clear, and the sail eased to slow down (Skipper.PASS_SLOW_SHARE). Off: the heading that passes widest.
## Measured (22 start rounds): 32 penalties with it, 25 without (port and starboard 16 against 6: a port board that
## slows while crossing ahead is the one that gets hit). Off.
@export var pass_slow_down: bool = false
## Dirty air (Skipper._clear_air()): on a beat in another sail's wind shadow, the wind cut by this share or more for
## a few seconds, with clear air on the other tack, it tacks away. 0: it does not notice.
@export_range(0.0, 0.5) var dirty_air_share: float = 0.15
## Dirty air on the runs too (Skipper._clear_air()): it gybes out of the blanket of the boards behind.
@export var dirty_air_on_runs: bool = false
## Before its start, farther than this beyond an end of the start line, metres, the course side of the line's
## extension does not count as over (Skipper._start_heading()); 0: it always does, as before. Measured in the random suite
## (9 November 2026, 100 m, the tune set's 50 races of seed 3): 5 races changed, starts even (one better, one worse after
## a mid-race R), one leg and one race time worse, 95 s more racing: off.
@export var start_free_beyond_ends_m: float = 0.0
## In a long countdown, sailing away to use up the time to spare (Skipper._start_heading(), AWAY), it turns back once
## this far from its spot on the line, metres, whatever the time to spare says; 0: only by the time, as before 9 November. The
## suite's baseline_A (8-9 November 2026), lake races: the start failed in 45 % of the 44 that sailed away more than
## 300 m (r0137 went 520 m, to the shore, with 52 s to spare by its reckoning and came back 42 s short) against 22 %
## of the 58 that went 150 to 300 m. On since 9 November 2026 at 200 m (loop 3 of AI_TRAINING_METHOD.md): tune set 50
## races, start 66 -> 70 %, pass 56 -> 60 %; hold-out 100 races, start 69 -> 72 %, pass 63 -> 67 %, legs 89 -> 90 %,
## no check worse.
@export_range(0.0, 2000.0) var start_away_max_m: float = 200.0
## A tack that does not go (Skipper._change_a_tack_that_does_not_go()): crawling upwind on one tack while the other
## went well, it takes the other tack and keeps it for a while.
@export var change_slow_tack: bool = false
## Its speed against the polar's under which a tack counts as not going, and how long it keeps the other tack, seconds.
@export var slow_tack_share: float = 0.45
@export var slow_tack_keep_s: float = 45.0

@export_group("Tactics")
## How big a header (a wind shift that forces it away from the mark) makes it tack, degrees.
@export_range(5.0, 20.0) var shift_sensitivity_deg: float = 10.0
## How much more wind it goes looking for, 0 to 1 (the lake only; not used on the open water,
## which has no gusts to see).
@export_range(0.0, 1.0) var gust_appetite: float = 0.0
## How far ahead it reads the wind on the water on a beat or a run, metres (Skipper._avoid_the_holes(): on
## the lake it tacks or gybes away from a light patch toward more wind); 0 does not look.
@export_range(0.0, 500.0) var wind_look_m: float = 200.0
## A patch counts as a hole when its wind is under this share of the wind where the board is.
@export_range(0.3, 1.0) var wind_hole_share: float = 0.75
