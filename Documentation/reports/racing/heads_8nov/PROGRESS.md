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
