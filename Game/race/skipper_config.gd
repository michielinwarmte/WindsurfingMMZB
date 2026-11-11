class_name SkipperConfig
extends Resource
## The character sheet of a scripted skipper (RACING_PLAN.md, "The scripted skipper (9B)"): the
## numbers that make one opponent different from another. A weaker skipper has worse numbers here
## (a longer reaction time, a noisier helm, bigger margins); nobody gets a lighter board or more
## wind (decision RD7). One .tres per character in Game/race/skippers/, so the team can edit a
## skipper in the inspector. The rules that use these numbers are in Skipper.

## The start plans (start_style below).
enum StartStyle { LOOP, HOLD }
## The tack it comes in to a course race's start on (start_tack below): EITHER by where it is, or its own choice.
enum StartTack { EITHER, STARBOARD, PORT }

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
## Before its start, while it is not holding back (going for the line, back to its spot) and not on a slalom's start,
## stuck in a crawl (slower than this, m/s, with the stick asking to head up for crawl_stuck_s), it lets go of the stick
## toward the wind: the board gathers speed on its heading (bearing away it still may) until
## Skipper.CRAWL_RELEASE_EXTRA_MS faster, and only then heads up (Skipper._steer_toward()); 0: off, as before. Phase S's baseline (9 November 2026, 200 starts): 24 of the 54 late starts crawled at the gun and more of
## the far ones crawled for minutes on their way back: a board at 1.5 to 2 m/s on a reach or a broad reach with the
## stick held hard toward the wind does not turn, and its sail draws at 1.5 to 4 deg (r0002 of baseline_S, 2 m/s for
## 75 s; r0007 of s1_on, 1.5 m/s on a broad reach in 16 kt for 80 s, 200 m behind the line at the gun). Taken (loop S2d,
## 9 November 2026, with crawl_stuck_s 4 and standing aside while the shore lookout steers): tune 50 starts (seed 16)
## on time 64 -> 78 %, 7 fixed, 0 broken; hold-out 100 (seed 23) 78 -> 83 %, 5 fixed, 0 broken (p 0.031), the median
## after the gun 5.8 -> 5.7 s, nothing else worse.
@export_range(0.0, 6.0) var crawl_no_head_up_ms: float = 2.5
## How long a crawl with the stick asking to head up must last before crawl_no_head_up_ms lets go of the stick, seconds:
## the trap lasted 75 to 80 s, while a head-up at a crawl that works (off the shore, back behind the line) turns the
## board in a few. 0: at once (the first on/off tests, s2 and s2b, which ran a board aground off the shore, r0017).
@export_range(0.0, 30.0) var crawl_stuck_s: float = 4.0
## In the go off its hold (Skipper._start_heading(): from the hold's speed, heading up for its crossing), how long the
## crawl must last before crawl_no_head_up_ms lets go, seconds; below 0: crawl_stuck_s, as everywhere. Phase S (9 November
## 2026, the crawl rule on, S3's off arms): 10 of 40 late starts still crawled at the gun, half of them 20 to 24 s late:
## gone from the hold at 1.6 to 2 m/s some 33 m back, the 4 s of crawl_stuck_s and the climb out of the crawl made them late.
## Taken at 0 with early_unlatches_go (loop S9, 10 November 2026): tune 50 starts (seed 24) 1 fixed, 0 broken; hold-out
## 100 (seed 28) on time 74 -> 81 %, 7 fixed, 0 broken (p 0.008), the median after the gun 7.2 -> 5.5 s, the speed at the
## gun 5.1 -> 6.2 m/s, nothing else worse. (Alone, S5: hold-out 9 fixed, 1 broken by an early arrival at speed.)
@export_range(-1.0, 30.0) var crawl_go_stuck_s: float = 0.0
## The time it reckons it needs to cross the start line (Skipper._time_to_cross_s()) counts crawl_stuck_s more when it is
## crawling (slower than crawl_no_head_up_ms) and the course to the line is more than Skipper.CRAWL_ERROR_DEG toward the
## wind of its heading: crawl_no_head_up_ms waits that long before it lets the board gather speed, so it goes that much
## sooner; false: not counted, as before. Phase S (10 November 2026, S7's off arms): boards gone from a hold along the
## line at about 2 m/s gathered speed along it after the wait, ran out of line ("the line is on the other tack"), crossed
## its extension and started 20 to 47 s late (r0017, r0034, r0050 of s7_off).
@export var crawl_in_timing: bool = false
## Going for the line and about to cross it early (Skipper._too_early_at_the_line()), with time to spare by its own
## timing, it stops going until that timing says go again (Skipper._start_heading()); false: near the line it keeps going
## once gone, as before, so the moment it has turned away from the line and is no longer early it heads for it again.
## Phase S (10 November 2026): boards at the line early at 7 to 8 m/s flipped between going and holding back hard every
## think and were over at the gun (r0018 of s8_hold_on, r0001 of s5_hold_on); the faster goes of S5 and S8 lost on it.
## Taken with crawl_go_stuck_s 0 (loop S9: the faster go and its safety, judged together; see there).
@export var early_unlatches_go: bool = true
## Early at the line (Skipper._too_early_at_the_line()) on the other tack than its way in's, it holds back hard on the
## tack it is on (Skipper._start_heading()); false: it turns onto the way in's tack first, as before, a tack or gybe a few
## metres from the line, often at speed. Phase S3's day run (11 November 2026): with start_go_lag_s 3, 8 of the 20 boards
## newly over early were turning onto the way in in the last seconds (13 of the night's 3465 boards without it).
@export var early_holds_its_tack: bool = false
## On a slalom's dive down onto the line, early (about to cross before the gun), it keeps the dive's heading and only
## eases the sheet, and luffs up only in the last Skipper.SLALOM_LAST_LUFF_S before it would cross (Skipper.
## _slalom_start_heading()); false: it luffs up to Skipper.HOLD_LUFF_TWA_DEG at once, as before. Phase S's baseline
## (9 November 2026): on T2 the luff from the broad reach (5.9 m/s) to 45 deg plus twice its noise went on through the
## wind and stopped the board dead in 5 s (r0024: 0.5 m/s at 258 deg in a 223 deg wind, then on the wrong side of its
## dive, 52 s late; r0191 never over); on a line along the wind a track 45 deg off it still runs at the line.
@export var slalom_early_ease: bool = false
## On a slalom's dive down onto the line, its crossing on the other tack, from Skipper.SLALOM_DIVE_GYBE_FROM_TWA_DEG or
## deeper it bears away and gybes (Skipper._gybe_now()) instead of asking for the turn at once (Skipper.
## _slalom_dive_deg()); false: at once, as before. Asked for at a beam reach, the controller tacks (it tacks up to 100
## deg): phase S's baseline (9 November 2026), r0024 on T2 at 6 m/s in 17 kt turned up through the wind's eye, stopped
## (0.5 m/s), came out on the far side of its dive and started 52 s late.
@export var slalom_dive_gybes: bool = false
## On a slalom's start, its waiting spot upwind of the boat moved this much further behind the line, metres (Skipper.
## _slalom_slot()); 0: where RaceCourses.slalom_slot() puts it, as before. That spot lies about 20 m from the line's
## extension past the boat, the parking circle's radius: boards on the way there or parked crossed the extension, turned
## back behind the line and were over at the gun or late (phase S, 10 November 2026: "to its spot upwind of the boat;
## off the line's extension", then "back behind the line", in 4 of 8 over-early slalom starts of the tune sets).
@export_range(0.0, 100.0) var slalom_slot_back_m: float = 0.0
## On a start line its hold's track runs at (Skipper.REACHING_HOLD_ACROSS or more of it toward the line: a reaching
## start, the line along the wind), a skipper who loops sails its timing loop once its time to spare beats what the way
## in can use up by this much, seconds, instead of Skipper.START_LOOP_EXCESS_S's 35; 0: always 35, as before. On an
## upwind start the leftover time is held back along the line; on a reaching start it brought the board to the line
## early: phase S (9 November 2026), the PM1 and SM1 templates, the line along the wind, held back at 1.6 to 1.9 m/s
## straight at the line from 150 m with 67 s to spare, 12 to 18 s early at the go point, over before the gun (s2b_on
## r0010, r0037; baseline_S r0045, r0049, r0166).
@export_range(0.0, 60.0) var reaching_loop_excess_s: float = 0.0
## The wind it reckons with, from its own sail (Skipper.wind_kt(), FeltWind): the mean of what its sail has felt over
## the last this many seconds, put on 10 m; 0: the telemetry's tws_10m_kt, as before, which on the lake is the lake's
## MEAN wind, not the wind where the board is. It sets the polar's speeds and best angles, the acceleration it reckons
## with off a hold and the push. Max, 10 November 2026, watching the AI start PD3 in the lull of the lake: "if the AIs
## do not have info about the current wind and average wind felt in the last minute or 2 ... give them that so they can
## adapt to wind speed in sail". Off until the suite has judged it (phase S3).
@export_range(0.0, 120.0) var felt_wind_s: float = 0.0
## Safe or risky at the start (Skipper._gust_lead_s()): in a wind that varies it goes for the line earlier, by this
## share of its reckoned time to the line for every unit of the felt wind's spread over its mean (FeltWind over the
## last 60 s: standard deviation / mean). A lull on the way in makes a board late and slow; going earlier with the early
## guard (_too_early_at_the_line()) to ease it costs a little speed at the line but not the start. 0: no lead, as
## before; 1 with a spread of 20 % of the mean and 10 s to the line goes 2 s earlier. Max, 10 November 2026: "in tricky
## situations they have to learn to be risky or safe". Off until the suite has judged it (phase S3).
@export_range(0.0, 4.0) var start_gust_lead: float = 0.0
## The dip at the start (Skipper._dip_deg()): before the gun, a board at a crawl that is early at the line (holding back
## hard cannot stop it: it creeps on and slides over), or one just over the line itself, bears away on its tack to the
## wind angle closest to the wind whose track runs away from the line, instead of creeping on (the hold) or sailing off
## on a reach to tack or gybe for a point behind the line (the way back). Where no angle on its tack runs away from the
## line (a reaching start, the line along the wind) it tacks or gybes away at once, slow or not. Phase S3, the night of
## 10-11 November 2026: of
## the 47 boards over early in the two baselines (s3_base, s3_hold_base), 19 slid over from "holding back hard, early"
## at 1.5 to 1.9 m/s, and 8 of those were 20 to 47 m over at the gun after the way back sailed off on a reach
## (s3_hold_base r0001/1: at the line at 1.7 m/s 12 s before the gun, 37.7 m over at it). Off until the suite has
## judged it.
@export var start_dip: bool = false
## Moving while it waits upwind of a slalom's committee boat (Skipper._slalom_wait_twa_deg()): the slower it goes, the
## further it bears away, from its luffed-up angle at Skipper.SLALOM_WAIT_LUFF_FROM_MS down to a beam reach at
## Skipper.SLALOM_WAIT_STALL_MS, instead of always luffed up as slow as it steers. Phase S3, the night of 10-11 November
## 2026: 54 of the 88 falls in the two baselines (s3_base, s3_hold_base) came while waiting there, at 0.2 to 0.4 m/s,
## most in 20 kt or more and often all three boards of a race (iq_pd3, iq_sd3). Off until the suite has judged it.
@export var slalom_wait_moving: bool = false
## With slalom_wait_moving: the speed from which it waits luffed up, m/s, and the widest angle it bears away to at a
## stall, degrees. 2.5 and 90 (the first try, 11 November 2026: the falls fixed beyond chance, but waiting at 1.6 m/s it
## went for the line from elsewhere and came early); lower and narrower keep it slower, nearer the old wait.
@export_range(1.0, 4.0) var slalom_wait_luff_from_ms: float = 2.5
@export_range(45.0, 90.0) var slalom_wait_widest_twa_deg: float = 90.0
## Safe but fast on a slalom (Max, 11 November 2026): the time it reckons its dive down onto the line takes is stretched
## by this share (1 is off). Measured on phase S3's slalom starts (the night of 10-11 November), dives not held back
## early: open water 1.18 to 1.35 times the reckoning (median), the lake 1.56 to 1.87 (its slalom start lies in a lull,
## and the board reached down at 7 to 8 m/s in 24 kt where it reckoned on 11 to 12). A little under the median is the
## safe side.
@export_range(1.0, 2.5) var slalom_dive_time_share: float = 1.0
## Max's slalom start (Max, 11 November 2026: "in a real slalom start ... we take the same direction as mark one ... then
## cross the line at a time ... if that is for example 100 s, we know that at around 50 s if we go back at the same speed
## we get a perfect start. But we have to gybe, so ... we add 5 s"): instead of waiting upwind of the committee boat and
## diving down, it sails a timed run behind its spot (Skipper._slalom_run_heading()): away from the line on the reciprocal
## of the reach to mark 1, a gybe when the time left is the way back at the speed it sailed out plus slalom_run_turn_s,
## and back at full speed; with more time than one run, out and back again. Off until the suite has judged it.
@export var slalom_timed_run: bool = false
## With slalom_timed_run: what the gybe at the far end costs, seconds: the turn and getting back to speed (Max's "add
## 5 s" on the water). 15.5 is what the game's starts measured for a gybe from a broad reach at 10 m/s (the board came
## out of it at 1 to 2 m/s; Skipper.START_TURN_S + START_GYBE_EXTRA_S); to be measured again on the run.
@export_range(0.0, 30.0) var slalom_run_turn_s: float = 15.5

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
## The tack it comes in to the line on at a course race's start (Skipper._start_run_in_tack(); Max, 11 November 2026: "i
## want the skippers decide starboard start and port start, so some will start the one way and others the other way";
## the most common start is on starboard, with right of way, just under the line, steering up at the gun). EITHER is the
## tack from its side of its spot, so that it does not cross the others' way in (as before); a reaching start keeps the
## first leg's tack whatever this says. EITHER until the suite has judged the others.
@export var start_tack: StartTack = StartTack.EITHER
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
## Safe but fast (Max, 11 November 2026: "going a little more safe but fast over the startline is better in real
## life"): the time getting going from a hold takes beyond its reckoning, seconds, added to the time it reckons it needs
## to cross (Skipper._go_lag_s()): the whole of it at 2 m/s and slower, none from 5 m/s up. 0 is off. Measured on phase
## S3's 1661 starts from a hold (the night of 10-11 November): going at 1 to 3 m/s the board crossed a median 2.8 to 3.7 s
## later than it reckoned, at 3 to 5 m/s 1.9 s, from 5 m/s up on time. A little under the median is the safe side.
@export_range(0.0, 8.0) var start_go_lag_s: float = 0.0
## Fast over the line (Max, 11 November 2026): of the points of the line it can reach on its tack, it makes for one at
## least this many degrees further off the wind than its beat's track, when there is one (a close reach, with room for a
## slow board's wider angle while it gets going); else as before (the angle it points once it has speed). 0 is off.
## Measured on phase S3's 1710 clean starts from a hold (the night of 10-11 November): 446 found the line on the other tack
## a median 9 s after they went (going from a crawl the board sails wider than its beat until it has speed, and sagged
## below the point it made for), tacked, and crossed a median 10 s later than they reckoned; the straight goes 1.5 to 3 s.
## Going from a crawl the board's track ran a median 13 degrees off its aim in the first 6 s.
@export_range(0.0, 40.0) var start_cross_room_deg: float = 0.0

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
## A skipper who loops starts its timing loop only nearer its spot than start_away_max_m (Skipper._start_heading());
## false: wherever it is, as before. From farther out the loop turned back at once (start_away_max_m) and on the way in
## began again: phase S (9 November 2026), r0099 of s3_hold_on on the lake flipped between away, turning back and to the
## waiting point for two minutes, each turn costing its speed, and came to the line 93 m short at the gun.
@export var loop_within_away_max: bool = false
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
