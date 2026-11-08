# The skipper's heads, the night of 8 November 2026: progress

Max's ask (00:30, 8 November 2026): train the rule-based skipper's heads, one at a time, until 9:30:
1 course sailing, 2 the start, 3 the racing rules, 4 tactics, 5 the personas. His conditions:
- slightly randomised starting locations, so the skipper is no one-trick pony (before: tuned on fixed
  spots, and after a restart they could not race);
- the courses not too close to the shore;
- the skipper gets enough information about the wind, the water and the shore;
- runs that fail in weird ways are investigated and fixed;
- all training on Silvaplana; with time left, also in more wind;
- his 5-hour limit resets at 1:30: carry on after it. Take it seriously: sail everything in every condition.

The lead works alone (no agents), on branch `ai/skipper-heads-8nov` from `physics/realism-7nov`
(7753fce) in the worktree `WindsurfingMMZB-fixes`. Disk C: had 9.8 GB free at 00:35: keep outputs small.

## How to resume (for the lead after a break)

Read this file's log from the bottom; check running jobs (`tasklist | grep -i godot`, the suite's
output folder); carry on with the next open step. Stop starting new work at 9:15 and write the summary.

## Plan

- [ ] H1 course sailing: the suite (random drops on every Silvaplana course, jittered, random hour and wind),
      the failure finder, the fixes, the tuner, a held-out check on new seeds
- [ ] H2 the start
- [ ] H3 the racing rules in a fleet
- [ ] H4 tactics (shifts, gusts)
- [ ] H5 the personas on the tuned all-rounder
- [ ] more wind (x1.3)
- [ ] summary for Max, play folder

## Log

- 00:35 branch made, this file.
- 00:50 the tools: `run_race.gd` got a drop mode (`--drop_step=random --drop_seed=N --goal_steps=2`: a board
  set down at a random open-water spot on a random leg, heading roughly along it, two steps to sail) and a
  HEADS_RESULT line per board (reached, time against the all-rounder's rough expected time, falls, aground,
  stuck, slow, least open water, turning); `tools/heads/pool.py` (jobs side by side, on the frozen copy
  `.sim_output/heads/frozen/Game` made by `tools/heads/freeze.sh`), `tools/heads/make_jobs.py` (races at
  set hours with a random spawn, drops at random hours; every --seed new spots), `tools/heads/suite.py`
  (the score and every failure). Lesson: edit while a pool runs on Game/ = broken jobs: always the frozen copy.
- 01:58 baseline `base1` (seed 1: 33 races, 11 courses x 12:00/14:00/16:30, + 88 drops), 24 min on 15 cores:
  **111 of 121 clean**, cost 1.635, races 0.97 x expected, drops 1.26 x; aground 2, not reached 2, falls 26.
  Failures: SD3 and SM1 at 16:30 aground on the east shore on the run to mark 2 (the run on starboard at the
  polar's 130 deg heads for the shore, the wind dies there 12 -> 7 kt, the shore check took it for a reach
  and turned along the shore, then at 1.3 m/s the gybe never came); LG2 16:30 stuck at the start in light
  wind (8-12 kt, NE end), 14 falls at walking pace on a broad reach; LR2 drop 11:40 6 falls near the shore.
- 02:15 fix 1 (skipper.gd): a beat or a run always tacks/gybes away from the shore (`_leg_turns`), looks
  120 m ahead on such legs; slow (< 3 m/s) at the edge it gets out on this tack (up or down, whichever has
  more water) instead of waiting for a manoeuvre. `Game/dev/course_check.gd`: every lake course's room to
  water under 2 m (marks ~190-340 m, but the beats' tacking zones reach the shallows on 6 courses).
- 02:00 fix 1 checked on the failing cases: SD3 and SM1 at 16:30 now clean (1.07-1.08 x expected).
- 02:05 the wind lookout (skipper.gd `_avoid_the_holes()`, `wind_speed_at()`): on a beat or run it reads the map's
  wind 200 m ahead on both tacks; into a patch under 75 % of its wind, with 1.2 x that on the other tack, it
  tacks/gybes now (not within 400 m of the mark, never toward the shore).
- 02:10 the courses refitted (Max's ask): `fit_courses.gd --shallow_m=2` (the shallows count as land),
  marks 250 m, legs 150 m, min size 25 %: every iQFOiL course now 250+ m from water under 2 m at the marks,
  150+ m along the legs (before ~190 m and 108 m); O2/I2 now 30 % (were 40 %), PD3/PM1 50 %, US3/US4 40 %,
  SM1 70 %, SD3 80 %, LG2/LR2 100 % (their 1.8 km beats still reach the shore: short tacks).
  Old files in `courses_before/`. T2 kept as it was (a unit test and every older baseline use it; the refit
  copy is in `courses_not_used/`). The fitter's output: `fit_courses_8nov.txt`.
- 02:20 the start's first try (LG2 12:00, 8 personas from random spots): all within 5.7 s of the gun, median
  1.0 s, 0 OCS, 3 penalties. `run_race.gd`: penalties and falls before the gun in the result line,
  `--skipper.<field>=` overrides; `make_jobs.py --starts=N` and `--fleet_races=N`; suite.py judges starts.
- 02:35 unit tests 1006/1007: the one failure was the T2 refit (passes with the old T2, so T2 restored).
- 02:40 **round 2 (r2)**, same seed as the baseline, all fixes, new courses: **116 of 121 clean**, cost 1.302
  (base 1.635), aground 0 (2), falls 5 (26), races 0.95 x, drops 1.20 x. Left: falls at a standstill in
  light wind (PM1 16:30 beat in 10 kt), a fall waiting at a slalom start, a fall bearing away at 17 kt (PD3).
- 02:45 the light-wind crawl found: at 1.5 m/s the auto-sheet holds only the sail the sailor can hold at a
  standstill (`_alpha_for_torque_deg`, alpha 2-5 deg in 12-15 kt), so the board never gets going and falls
  (not the push, not the night tuning: both A/B'd). Hands and physics are Max's approved autopilot and
  Michiel's: not changed. The skipper gets `SkipperConfig.get_going_twa_deg` (0 = off): slow under 2.5 m/s
  for 6 s after the gun, it sails that angle until 5 m/s (25 s at most). A/B on 44 light-wind drops per
  angle (0, 95, 115, 135) running.
- 02:50 the US4 drop (r2's one not reached) read with the skipper's aim point in the track (new CSV columns
  aim_x_m, aim_z_m): coming at a reach's mark from below (a beat in), the board had no plan for the tack to
  arrive on: `_approach_tack()` refused any rounding that swings past dead downwind by more than 1 deg, and
  the leg out ran 2 deg past it, so neither tack; then it sagged 20 m below the layline, passed the mark on
  the wrong side and circled it for 4 minutes. Three fixes in skipper.gd: a swing of up to 20 deg past dead
  downwind allowed (`DOWNWIND_SWING_DEG`; this also hits windward marks with a run out just past dead
  downwind); a beat in to a reach's mark arrives on the rounding tack (`BEAT_IN_MARGIN_DEG`); within 80 m on
  the arriving tack and unable to lay the entry point, it tacks twice up (`FETCH_CHECK_M`). The drop now
  rounds (284 s, 2 tacks, 2 gybes).
- 02:55 the getting-going A/B (44 light-wind drops each, seeds 3 and 4, 11:30-12:30 and 16:30-17:30):
  off 44/44 clean (cost 1.159), 95 deg 43/44 (1.198), 115 deg 43/44 (1.228), 135 deg worse. On the refitted
  courses the light-wind trap mostly went away; the angle does not help: **left off** (0, the default).
- 03:00 unit tests 1007/1007; commit 926b49e. Round 3 (r3: seed 2 fresh, races at 12:30/15:00/17:00 + 88
  drops, and seed 1's 88 drops again) started, and its twin with the wind lookout off (r3off, seed 2) for the
  lookout's A/B (head 4). The lookout fired in 44 of r2's 121 cases. Its numbers are now on the sheet
  (`wind_look_m` 200, `wind_hole_share` 0.75; 0 m switches it off).
- 03:15 r3's 33 races: 0.88 x expected, no groundings, 7 single falls, every one at a standstill (< 1 kt),
  five of them in the start (holding back, reaching down onto a slalom line, waiting upwind of the boat).
  r3off's LG2 12:30 ran aground on the lee shore at 1.5 m/s (the lookout-on twin was clean).
- 03:20 the start: `SkipperConfig.hold_floor_ms` (0 = the controller's steerage, 1.5 m/s), the slowest the
  start holds back to; A/B on 22 start rounds of 8 personas (seed 5) at 0 and 2.5 running (h2, h2f25).
  The fleet races (h3: 11 courses, 8 personas, the whole race, seed 6) running at low priority
  (`pool.py --low=1`). The slow escape now also takes a way with more water than straight on.
- 03:43 **round 3 done: 195 of 209 clean** (seed 2 never seen + seed 1's drops), races 0.88 x expected,
  drops 1.13 x; aground 3, not reached 5, falls 11 (all single falls at a standstill). Read and fixed:
  - US3 and US4 at 17:20 aground on the east shore (the wind dies there late): the gybe at 1.5 m/s bore away,
    stalled and came back, again and again. **Too slow to gybe, it heads up and tacks** (`_slow_turn()`,
    `SLOW_TURN_*`: under 3 m/s, racing). The wind lookout's no-look zone near a mark 400 -> 250 m (it was
    290 m from the mark when it should have seen the hole). Both drops now clean (1.3 x and 1.13 x).
  - O2 at 11:40: at 2 m/s the board sailed 280 m away from its mark for three minutes, past the layline,
    because a tack is refused while not "pointing" (under 5 m/s), and in light wind it never got there.
    **Well past the layline (30 m beyond its margin) it tacks even slow** (`SLOW_TACK_PAST_M`; on a beat and
    on a reach for the other tack). The drop now finishes (2.8 x, 6 tacks, a light patch).
  - LR2 at 11:40 aground on the SE lee shore: now finishes (slowly, 1572 s, light wind).
  - LG2 12:30 without the lookout still runs aground on the lee shore (with the lookout, the default, clean).
- 03:55 round 4 (r4: seed 3 never seen, races 11:45/14:15/16:45 + 88 drops, + r3's failures) running with
  every fix; unit tests running.
- 04:05 **head 4 (tactics), the wind lookout's A/B** on seed 2 (121 cases each, same code otherwise): on 109
  clean, cost 1.406, races 0.878 x, drops 1.062 x; off 109 clean, cost 1.405, races 0.902 x, drops 1.100 x.
  As robust either way, ~3 % faster with it, and its two groundings are fixed since; without it LG2 12:30
  ran aground. **Kept on.** (The slow-tack rule alone also saves that LG2 case now: it finishes.)
- 04:05 **head 2 (the start)**, the slowest hold's A/B at half time (96 boards each): floor 0 59 clean, 27
  penalties, median 3.8 s, 15 late; floor 2.5 m/s 48 clean, 37 penalties: **left at 0**. No falls and no
  OCS in either. The start's trouble is penalties after the gun (17 of 22 "the windward board keeps clear")
  and late starters (up to 50 s).
- 04:10 **head 3 (the rules)**: keeping clear always bore away, which turns a windward board onto the
  leeward one. Now by the rule: the windward board heads up (no closer than 38 deg), a board clear astern
  or outside at a mark turns away from the side the other is on, port still bears away behind starboard
  (`KEEP_CLEAR_HEAD_UP_DEG`, `KEEP_CLEAR_SIDE_DEG`). Its A/B on the 22 start rounds running (h2kc; h2's
  jobs finished before the change are listed in h2/done_before_kc.txt).
- 04:15 the start's late boards read: OCS at the gun is rare (2 of 120, from the start report; the result
  line counted only boards still over at the end, now `was_ocs` too). Hana ("the pro, sharp starts") was
  over by planing to the line faster than reckoned; Mara (timing 0.85) went at the last moment, lost speed
  turning and crossed 37 s late. The sharp starters are the late ones: they aim close to the gun, and the
  acceleration from a hold was measured on the open water, not in the lake's chop and a crowd.
  `SkipperConfig.start_accel_share` (1.0 = as before); A/B at 0.7 on the 22 start rounds running (h2acc).
- 04:20 unit tests 1007/1007 (before the keep-clear change); commit bfae9ce.
- 04:35 **round 4 (seed 3, never seen, every fix to 03:55): 118 of 128 clean**, races 1.00 x expected (lighter
  hours: 11:45), drops 1.14 x, aground 1, falls 5. Read:
  - O2 at 15:30: its 35 m finish line lay dead downwind 47 m away; the run's 135 deg swept the board past the
    end of the line again and again. **Near the finish (80 m), on the gybe that reaches it, it runs straight
    in** (`DIRECT_RUN_M`, only for the finish: into a mark the deep run cost the plane). Now 10 s.
  - T2 at 11:50 (the old T2, kept): mark 3 lies in a light patch by the shore; two drops crawl at 1.8 m/s and
    one runs aground although the slow-tack rule fires: at that speed the board neither heads up nor gybes
    (heading 311-322 for 16 s). The new T2 (250 m from the shallows) is in `courses_not_used/`, waiting for
    the team (every yardstick and a unit test use T2).
  - PD3 at 15:20 and PM1 at 16:00: the same crawl in light patches at the NE end (2 m/s on a broad reach in
    15 kt). **A finding for the hands/physics (not changed): below about 2 m/s the board can hardly be steered
    and the auto-sheet holds only the sail a standing sailor can hold (`_alpha_for_torque_deg`, 2-5 deg), so a
    board that gets that slow stays that slow.** The skipper's defences: the wind lookout and the courses.
- 04:45 round 4 complete: on its fresh seed 3, **115 of 121 clean (95.0 %), no falls**, 1 aground (old T2).
  The trend on seeds never seen: baseline seed 1 111/121 (91.7 %), r3 seed 2 109/121 (90.1 %, before the
  slow-turn and slow-tack rules), r4 seed 3 115/121 (95.0 %). The stronger-wind round (x1.3, seed 7: 33
  races at 13:30/15:30/16:30 + 66 drops) running; unit tests on the newest code running.
- 04:50 unit tests 1007/1007 on the newest code; commit 2f22c27.
- 04:55 the keep-clear A/B on the same 15 start rounds (120 boards): old 65 clean, 39 penalties (33 windward),
  2 OCS at the gun; by the rule 62 clean, 37 penalties (28 windward, 9 port), **8 OCS**. Before the gun the
  boards reach along the line with the course side up the wind: a windward board heading up went over.
  **Before the gun it bears away as before; the rule's way only after the gun.** Its A/B running (h2kc2).
  (h2acc's rounds before this change are listed in h2acc/done_before_kc2.txt.)
- 05:05 **more wind (x1.3, seed 7: 33 races, 66 drops): 86 of 99 clean, every race and drop got there, no
  groundings**, races 1.18 x, drops 1.33 x. All 13 failures are falls (18 falls): 13 of them within 25 s of
  a tack or gybe that stalled (e.g. LG2 13:30: a tack at 6 m/s in ~18 kt stopped head to wind, the board sat
  at 0.5 m/s swinging round for 10 s and the sailor fell), the rest standing still in the start's holds.
  **A finding for the hands (not changed): in the stronger wind the tacks stall.**
- 05:05 the start's acceleration A/B (both with the first keep-clear, 168 boards): 0.7 gives 91 clean against
  87, median 3.7 s against 4.8 s, but the late starters it was meant for are unchanged (40 vs 39) and 2 more
  OCS: inside the noise, **left at 1.0**.
- 05:10 the fleet races restarted on the current code at normal priority (the old ones, at low priority, had
  only sailed 3 minutes each; their logs in h3_old_code/).
- 05:30 **head 3, the keep-clear A/B** on the same 15 start rounds (120 boards): old (always bear away) 65
  clean, 39 penalties (33 windward), 2 OCS at the gun, median 3.8 s; by the rule everywhere 62, 37, 8 OCS;
  **by the rule after the gun only: 69 clean, 29 penalties (20 windward, 9 port), 2 OCS, median 3.8 s**.
  Penalties -26 %, the windward board's -39 %. Kept. The final check (seed 8) and the fleet races running.
- 05:35 **head 5, the fleet races** (current code, 8 personas): the five short ones done (PD3, SD3, US3, US4,
  T2): **all 40 boards finished, no falls, no groundings**, 22 penalties, a few OCS. The winners vary
  (Hana, Mara, Hana, Lena, Jonas); Hana, the pro, was last twice (penalties and tacks). Mid-race penalties
  are mostly port/starboard: the skipper only reacts inside its keep_clear_m (15 m), a second of closing
  for two boards crossing at 8 m/s. `SkipperConfig.keep_clear_look_s` (0 = as before): it reacts that many
  seconds of closing ahead; A/B at 4 s on the 22 start rounds running (h2la).
- 06:00 the look-ahead's A/B (20 start rounds, 160 boards, against the kept keep-clear): 97 clean against 90,
  late 27 against 30, OCS 2 and 2, but penalties 45 against 43 and port/starboard 18 against 17: its target
  untouched. Bearing away a fixed 15 deg earlier is not a duck. **Port now ducks**: it bears away as far as
  passing 10 m behind the starboard board's stern needs (`KEEP_CLEAR_DUCK_BEHIND_M`), or holds its course if
  it passes behind already. A/B of the duck with the 4 s look-ahead running (h2duck).
  The final check (seed 8) at 70 of 77: all 70 clean.
- 06:00 **the final check (seed 8, never seen, everything to 05:35): 75 of 77 clean (97.4 %)**: all 33 races
  on all 11 courses clean, 44 drops 42 clean, no groundings; the two failures are both on T2 (the old course,
  kept) at its finish, stuck in the light patch (12:20 and 16:40).
- 06:20 the duck's A/B (with the 4 s look-ahead, 22 start rounds, 176 boards): 101 clean against 97, but
  penalties 51 against 46 (port/starboard 22 against 19); the look-ahead alone: 104 clean, 48 penalties (20).
  Neither cuts the penalties: **the duck taken out again, the look-ahead left at 0** (measured, harmless).
  The port/starboard penalties want a look at single incidents with full traces (the next step for head 3).
  Unit tests and the load check on the final code running; then the play folder.
- 06:30 the fleet races (11, current code, 8 personas): **88 of 88 boards finished, no grounding, 1 fall**,
  82 penalties, 4 OCS. Mean places Kofi 3.6, Hana 3.9, Mara 4.1, Jonas (the rookie) 4.1, Lena 4.1, Liv 4.2,
  Elin 5.4, Bruno 6.6: the levels do not spread enough; the penalty turns shuffle the order.
- 06:35 repeatability: one start round run twice with the same code gives identical tracks; but any change,
  even a reordered sum, moves a heading by 0.1 deg and a crowd's incidents come out differently (the slalom
  rounds: 9 and 14 penalties with code that should act the same). Fleet A/Bs need many rounds.
- 06:40 `run_race.gd` prints a PENALTY line per incident (both boards). Read: the port/starboard ones are
  fast port boards (7-9 m/s, already keeping clear) running into a starboard board nearly stopped in the
  crowd. `SkipperConfig.keep_clear_by_passing` (off): the burdened board turns just enough, either way, to
  pass 12 m clear over the next 6 s. Its A/B against the identical code without it on the 22 start rounds
  running (h2pass, h2base). The slalom dive change and the duck: taken out (no effect shown).
- 07:05 passing clear's A/B (22 start rounds, the same code with and without): 100 clean against 97, penalties
  45 against 46, port/starboard 17 against 19, the rest identical (the base reproduced h2kc2 exactly, so the
  code is otherwise the same). No real gain: **left off** (`keep_clear_by_passing` false). The incidents are
  not the head's choice: the board does not turn in time at 9 m/s, or the crowd is too close at the gun.
  A light-wind round (x0.8, seed 9) running.
- 07:30 **less wind (x0.8, seed 9, final code): 95 of 99 clean, no groundings, no falls**, races 0.93 x;
  one T2 drop not finished (the old course), three slalom starts over early with no other board (PD3 and
  T2 at 14:30, SD3 at 12:00): the board crossed the line's extension going to its waiting spot upwind of the
  boat. Turning back at once (turn_now) did not change it: taken out, the cause is in the slalom start's
  geometry in light wind (open).

## The day session (8 November 2026, 10:30 to 14:00): racing each other, without penalties

Max (10:40): "the heads can also Shift steer for faster steering. make them race each other and avoid
penalties. keep improving until 14:00".

- 10:35 **why last night's three keep-clear ideas could not work**: the skipper only looked at the board the
  judge names (`rules.burdened_by()`), and the judge names boards only within its `NEAR_M`, 15 m. A longer
  look-ahead, the duck and passing clear were all cut off at 15 m: a second and a half at the 10 m/s two
  crossing boards close at, half of it gone in the think interval and the reaction time. So they were never
  really tested.
- 10:40 the look-ahead rebuilt (`Skipper._look_ahead_keep_clear()`, `keep_clear_by_passing`): the skipper asks
  the rules itself, at any distance (`RaceRules.must_keep_clear_why()`, a question that changes nothing in the
  judge), for every board within six seconds of closing; for those that would come within 12 m if both held
  their course it turns just enough, on its tack, to pass them all (bearing away first when two are as near;
  no turn toward the shore). The Shift carve (`AiHands.sharp`, which the skipper never pressed):
  `keep_clear_sharp` holds it for a keep-clear turn of 8 degrees or more. A/B on the 22 start rounds of last
  night (seed 5): kcA as before, kcB the look-ahead, kcC the look-ahead and Shift.
- 10:50 measured next (off by default): `tack_traffic_check` (a tack or gybe onto port with a starboard board in
  the way waits up to 6 s, never at the shore), `turn_sharp` (Shift for any turn of 20 degrees or more, not a
  head-up above 12 m/s). The personas now read the wind by their sense (`Persona.to_skipper_config()`:
  `wind_look_m` 0 for the rookie up to 250 m for the best sense, 40 % further for a gust hunter).
- 11:00 the first A/B was void: `--skipper.keep_clear_by_passing=true` reads "true" as the number 0 (off), so
  the three arms were identical (last night's A/Bs used `=1` and stand). `apply_skipper_overrides()` now takes
  true/false too. kcA (as before) reproduces last night's h2base exactly: the new code changes nothing while
  its switches are off. B and C restarted on a second frozen copy (`frozen2`, without the persona change).
- 11:15 on 10 rounds: penalties A 14, B (look-ahead) 13, C (look-ahead and Shift) 13; port/starboard 9 -> 5-6,
  the windward board's 5 -> 7-8. Read one by one: many in the first 25 s after the gun with the boards still
  "start: go" (PRE_START lasts until a board crosses the line, and the look-ahead only ran while RACING; going
  from its hold a board kept clear of nobody); a board bearing away behind one ran into another it had not
  counted; boards in a penalty turn are hard to read; and at I2 a crowd tacking at the same layline point
  66-85 s after the gun, colliding in the tacks. Built and running: from the gun on (`_judged()`, kcD with
  `tack_traffic_check`), and every board it must keep clear of counted for the heading it turns to
  (`pass_all_counted`, kcE). Also ready: `pass_room_from_sheet` (the room from the character's keep_clear_m).
- 11:30 on 10 common rounds: A 14, B 13, C 13, D 13 penalties, but D's starts 2.7 s later (median 6.6 s against
  3.9): keeping clear on the way to the line after the gun costs the start and did not cut the penalties; now
  its own switch `keep_clear_from_gun` (off). B and D stopped (kept as far as they ran) to make room. Built:
  `penalty_when_clear` (a penalty circle waits until no board is within 30 m, at most 45 s: several start
  penalties were a circle in the crowd setting off the next), `dirty_air_share` (on a beat in another sail's
  shadow, the wind cut by that share for 3 s and clearer air on the other tack: it tacks away; the shadows'
  own factor, `WindDisturbance.factor_at()`, read through the board's wind field). The fleet races (fl1:
  9 courses, seed 60 as last night's h3, without LG2/LR2 at 90 minutes each) running with the package:
  look-ahead, Shift, all counted, penalty when clear, traffic check, dirty air 0.15, the personas' wind reading.
- 11:40 **kcC complete (22 rounds): penalties 46 -> 40** (port/starboard 19 -> 15, the windward board's 27 -> 25),
  the starts unchanged (median 4.4 s), but falls 1 -> 3: both new falls were a board at 2 m/s heading up with
  Shift held to keep clear. Shift now only from 5 m/s (`SHARP_FROM_MS`). An incident traced (LR2, Mara on
  Jonas): with no heading passing the full 12 m, Mara took the widest, a 45-degree bear-away over 3 s while
  Jonas, to leeward and keeping clear of another board, bore away too, and Mara grew faster than the
  prediction (7.4 -> 10.4 m/s). `pass_slow_down`: then the smallest turn that still passes 5 m clear, and the
  sail eased to 60 % of its speed. kcG (look-ahead, Shift, all counted, slow down, penalty when clear) running.
- 11:50 on 12 common rounds: penalties A 23, C 21, E 16 (+ all counted, traffic check, from the gun), **F 12**
  (+ penalty when clear); E and F 4 falls each, every one a board at about 2 m/s keeping clear with Shift (fixed
  at 11:40); their starts 0.8 s later (the from-the-gun part, which ran unconditionally on their frozen copies).
  kcG (no from-the-gun, no traffic check, + slow down) on 4 rounds: 4 against 7, the starts as A. The first two
  fleet races (PD3, T2) as many penalties as last night (1 and 3). E and F stopped at 12 rounds.
  **The final set, on by default** (`SkipperConfig`): keep_clear_by_passing, keep_clear_sharp (from 5 m/s),
  pass_all_counted, penalty_when_clear, tack_traffic_check, pass_slow_down, dirty_air_share 0.15 (the personas
  by their upwind sense: the rookie does not notice, the best sense tacks out of a 12 % cut). Off:
  keep_clear_from_gun (the starts), turn_sharp (not measured). The final check running: flFinal (9 fleet
  races, seed 61, never used), then kcFinal (the 22 start rounds against kcA), the unit tests.
- 12:05 committed 9acce9b (the final set on by default); unit tests 1007/1007; release build; **LAN sync check on
  the lake with three personas: PASS**. Play folder WindsurfingMMZB-play-8nov2026-racing (with an I2 launcher:
  the short, crowded line).
- 12:20 **fl1 complete (the package with Shift at any speed, 9 fleet races, seed 60 as h3): penalties 61 -> 29**,
  every board finished; mean places Hana 3.1, Kofi 3.6, Mara 3.6, Lena 3.7, Liv 4.6, Jonas (the rookie) 5.3 (was
  3.8), Bruno 6.0, Elin 6.2; but 14 falls (h3: 1), nearly all a board at 1.2-2 m/s keeping clear with Shift (the
  5 m/s floor, in the final set, removes them), and Bruno at a standstill in the light PM1/SM1.
- 12:30 **kcFinal complete (22 rounds, the final set): penalties 46 -> 32**, the starts as before (median 4.5 s
  against 4.4), OCS 5 and 5, falls 1 and 1 (the same pre-gun fall). keep_clear_from_gun on top (12 rounds): 18
  against 16 and the starts later: stays off. F (no slow down, Shift at any speed) had 12 on the same 12 rounds,
  so kcFinalNoSlow (the final set without pass_slow_down, 22 rounds) is running to settle the slow-down.
- 12:35 flFinal (seed 61): six of the seven T2 penalties came after the boards had finished ("free: back to the
  area"): the look-ahead only ran while racing. A finished board's time is frozen, so they do not count, but
  boards running into each other look wrong: `_judged()` now also covers a finished board while the race goes on.
- 12:45 **flFinal complete (seed 61, never used; the final set with the slow-down): 38 penalties, 12 of them after
  the burdened board had finished** (26 while racing, against 61 for last night's set), 1 fall, 70 of 72
  finished (Mara and Jonas on T2 at 16:30, the old course's light patch, as in the morning's report). Mean
  places: Hana 2.6, Liv 2.8, Kofi 3.1, Mara 3.4, Lena 4.8, Elin 5.4, Bruno 6.8, **Jonas (the rookie) 7.2, last**.
- 12:50 **kcFinalNoSlow complete (22 rounds): 25 penalties against the final set's 32** (port and starboard 6
  against 16), everything else the same: **pass_slow_down off**. Against the code before today: **46 -> 25**.
  Committed f2c722b (the slow-down off, keeping clear after the finish), rebuilt, the play folder updated, LAN
  sync check PASS again. The last checks: flFinal2 (the shipping code, seed 61) and kc7 (11 start rounds on seed
  7, never used today, the code before today against the shipping code).
- 13:10 unit tests on the shipping code (f2c722b) 1007/1007. **kc7 (seed 7, start spots never used today, the
  code before today against the shipping code), 6 rounds: penalties 14 -> 6, port and starboard 7 -> 0**, the
  starts the same. `pass_room_from_sheet` (the passing room from each character, 8 to 20 m) on the 22 rounds:
  7 against 2 on the first 7: stopped, off. The play folder zipped (292 MB).
