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
