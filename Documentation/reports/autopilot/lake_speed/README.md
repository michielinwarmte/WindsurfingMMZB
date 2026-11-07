# The autopilot on the lake: speed, balance and the nose dive (7 November 2026)

Max's asks of 10:15, built by an Opus builder on branch `autopilot/lake-speed` (worktree
`WindsurfingMMZB-fixes`), with a tuner left running on its own:

> "better balance and control at low speeds, so it will be easier to get onto the plane; that the
> board doesn't nose dive in stronger winds at low speeds; going downwind and crosswind in waves is
> slow; in the conditions in Silvaplana with a 7-8 metre sail and a medium to big board we need to hit
> 50-55 km/h crosswind and 55-60 downwind in the gusts; keep track of where you do the test and track
> the wind at that moment; the waves need to be controlled better; I need the best quality autopilot."

His answers: technique first, and where the targets stay out of reach, physics questions for Michiel
with numbers; a spread of gear; Silvaplana only, the lake's full waves; the Maloja afternoon's wind
(13:00 to 16:00) at x1.0 and a stronger day at x1.3; the speed counted in the gusts.

Only technique was changed: `Game/windsurfer/player_controller.gd` (new numbers, all off by default),
a test, a harness in `Game/dev/` and tools. No physics, no `Game/sim/` file, no config number. The
tuned numbers go on the player's board only (`PlayerController.NIGHT_TUNING`, Settings > Sailing >
Night-tuned steering); the AI fleet keeps the code's defaults.

## What was built

1. **The lake suite**: `tools/lake_suite.sh --label=<name> [--cases=1] [--refs=1] [--controller.<field>=<n> ...]`
   (the scoring in `tools/lake_suite.py`, the harness `Game/dev/run_lake_speed.gd`). The player's
   controller sails every case the way the autopilot drives it: the heading hold and the auto-sheet,
   the push at 75 %, the night-tuned steering on. Every case is seeded and the same every run, one
   headless Godot each, 12 at a time; a suite takes about 2.7 minutes. 30 lake cases (10 per gear) and
   25 guards:

   | Scenario | Cases (each on the three gear combos) | What counts (cost, lower is better) |
   |---|---|---|
   | start | from rest at x1.0: camping beach 13:30 at 100 degrees, between 14:30 at 120, middle 15:30 at 90 on port | the time to plane (the speed above 7.5 m/s for 2 s), 2 x the heel SD and 2 x the pitch SD in the first 30 s, 20 x how fast the sailor's lean moves (RMS), 5 per nose dive |
   | strong | from rest at x1.3: middle 14:30 at 100, between 13:30 at 130 | 15 per nose dive (below 8 m/s, the bow more than 0.12 m under or the nose more than 6 degrees down), 5 x the seconds buried, 2 x every degree of nose-down past 4, half the time to plane |
   | reach | beam (90) at x1.0 middle 14:30 and south 15:00 on port, at x1.3 between 13:30; broad (135) at x1.0 between 15:30 and x1.3 middle 14:30 | the speed in the gusts (the mean of the 90th percentile and the mean speed while the wind at the board is in its top quarter, measured from 20 s to 75 s) against the target, 50 km/h beam and 55 broad: 2 per km/h short, a bonus of 0.5 per km/h beyond (up to 10); minus half the mean speed; half the pitch rate SD; 0.05 per time a minute the board goes light |
   | guards | last night's taps, Shift carve, the reflex, tacks and gybes (`tools/night_suite.py`'s 25 cases and costs, with the night-tuned steering) | their night costs at half weight |

   Every fall costs 100 in its scenario. The total is the sum of the four. The tuner never keeps a
   set with more falls than the baseline in any scenario.

   **Where and in what wind**: every lake case writes a CSV of its track every 0.5 s (time, game x
   and z, the Swiss LV95 east and north, the wind at the board: the map's wind 10 m above the board's
   spot, speed and direction, the wind at the sail, the TWA, the board's speed, pitch, heel, the bow's
   depth, planing, the sailor's state) next to its log, and its summary (`results.json`) has the
   start's and end's LV95, the heading, the lake's wind direction, the wind at the board along the
   track (mean, 75th and 90th percentile, max) and the speeds. The places: the lake scene's start 40 m
   off the camping beach (LV95 2780880, 1147510), the lake's middle (game 349, -89), halfway between,
   and "south", 300 m from the middle toward Maloja. A reach's start is set back along its course
   (the place stays on the track) so there is up to 1.4 km of water ahead.
   `--refs=1` adds four cases that are not scored: the same beam and broad reaches on flat water, and
   on flat water in sea-level air, to show what the waves and the thin air cost.
2. **The gear** (Max: about 108 to 130 L slalom or free race with 7.0 to 8.0 m, the smaller sail on
   the smaller board, the recommended fin):

   | combo | board | sail | fin (recommended for the width) |
   |---|---|---|---|
   | small | PJ New Sealand free race 111 L | Savanna free race 7.0 m | 36 cm |
   | medium | PJ New Sealand slalom 117 L (the game's default) | Savanna slalom 7.5 m | 38 cm |
   | big | Moonboard slalom 129 L | Savanna slalom 8.0 m | 41 cm (PJ New Sealand's, Moonboard makes none) |
3. **The technique hooks** in `player_controller.gd` (the block "The lake technique"), all off or
   neutral by default, seven unit tests in `Game/tests/unit/test_controller_lake_speed.gd`:
   - getting going: below `start_help_until_ms` the auto-sheet trims to at most `start_alpha_deg`,
     sheets in at `start_sheet_in_share` of the body's pace and holds `start_hike_share` of the pull,
     and the rig is raked back by `start_rake_back` on top of the helm;
   - heading up to get going on a slow broad reach: `plane_head_up_deg`, beyond
     `plane_head_up_from_twa_deg` (the mirror of last night's `plane_bear_away_deg`);
   - the nose dive below the plane: below `nose_dive_below_ms`, with the bow deeper than
     `nose_dive_bow_m` or the nose down past `nose_dive_pitch_deg`, the sail eased to
     `nose_dive_alpha_deg` and the rig raked back by `nose_dive_rake_back`, for `nose_dive_hold_s`;
   - riding a gust on the plane: `gust_bear_away_deg` further off the wind while the wind at the
     sail is `gust_from_kt` to `gust_full_kt` above its own 8 s mean;
   - the feet's trim in chop: `chop_trim_aim_deg` times the chop felt.
   The sailor's weight cannot be moved back below the plane from the controller: the stance is the
   sailor model's (the sim steps back with the speed). The rake and the sheet are the levers.
4. **The tuner** `tools/lake_tuner.sh` (Python `tools/lake_tuner.py`) and the interim build
   `tools/lake_tuner_apply.sh`, below.

## The baseline against Max's targets

The whole table, with every case's place and wind: [baseline.md](baseline.md). The speed in the
gusts, km/h:

| course, wind | wind at the board (kt, mean) | small | medium | big | target |
|---|---|---:|---:|---:|---:|
| beam, x1.0, middle 14:30 | 16 | 33.6 | 35.7 | 36.5 | 50 |
| beam, x1.0, south 15:00 (port) | 22 | 40.8 | 45.4 | 46.0 | 50 |
| beam, x1.3, between 13:30 | 24 | 44.4 | 41.2 | 41.2 | 50 |
| broad, x1.0, between 15:30 | 15 | 7.8 (never planes) | 8.4 (never) | 8.4 (never) | 55 |
| broad, x1.3, middle 14:30 | 23 | 29.7 | 31.7 | 35.2 | 55 |
| *beam, x1.0, flat water* | 16 | 37.6 | 40.9 | 43.1 | |
| *beam, x1.0, flat, sea-level air* | 16 | 41.5 | 45.1 | 44.2 | |
| *beam, x1.3, flat water* | 22 | 56.4 | 55.2 | 52.0 | |
| *broad, x1.3, flat water* | 22 | 34.1 | 37.9 | 44.9 | |

No case reaches its target with waves. On flat water the beam reach at x1.3 does (52 to 56 km/h),
so across the wind the gap is mostly the waves. Downwind the board is slow on flat water too.
Getting going, the bow dives in the first 1 to 3 s from rest in every case (at x1.3 on 130 degrees
the nose 13 to 20 degrees down and the bow 0.43 to 0.52 m under). No falls anywhere. The baseline's
cost: start 286.9, strong 278.7, reach 479.3, guards 161.1, total 1206.0.

## The tuner

`tools/lake_tuner.sh` copies `Game/` once to `.sim_output/lake_speed/project` and sails that frozen
copy, so the worktree can be edited while it runs. Coordinate descent from the player's set (the
code's defaults with this morning's NIGHT_TUNING on top): for one number at a time it scores the best
set so far with that number a step up and a step down (both in one pool of 12 Godot processes) and
keeps the better one when the total drops by more than 0.5 and no scenario has more falls than the
baseline. The steps start at a quarter of each range; after a round that keeps nothing they are
halved, down to 1/32 of the range; a round at 1/32 that keeps nothing means it has converged and it
stops by itself. No AI in the loop. A pair takes about 5.5 minutes, a round over the 43 numbers about
4 hours; expect it to converge after 5 to 8 rounds (a day or more). The best so far is always in
`best.txt`, so an interim build can be made at any time.

The numbers (PlayerController fields), in the order they are tried; the start is the player's value:

| Group | Number | Start | Range |
|---|---|---:|---|
| getting going | start_alpha_deg | 90 (off) | 6 to 90 |
| | start_help_until_ms | 7.0 | 4 to 9 |
| | start_sheet_in_share | 0 (the pilot's own) | 0 to 1.0 |
| | start_hike_share | 0 (the pilot's own) | 0 to 1.4 |
| | start_rake_back | 0 | 0 to 0.5 |
| | plane_head_up_deg | 0 | 0 to 30 |
| | plane_head_up_from_twa_deg | 110 | 95 to 125 |
| nose dive | nose_dive_bow_m | 0 (off) | 0 to 0.3 |
| | nose_dive_pitch_deg | 12 | 3 to 20 |
| | nose_dive_below_ms | 8 | 4 to 10 |
| | nose_dive_alpha_deg | 8 | 2 to 16 |
| | nose_dive_rake_back | 0 | 0 to 0.6 |
| | nose_dive_hold_s | 0.5 | 0.1 to 1.5 |
| waves, across and downwind | gust_bear_away_deg | 0 | 0 to 15 |
| | gust_from_kt | 1.0 | 0 to 3 |
| | gust_full_kt | 3.0 | 1.5 to 6 |
| | chop_trim_aim_deg | 0 | -3 to 4 |
| | chop_hike_drop | 0 | 0 to 0.5 |
| | pilot_sheet_rate_per_s | 1.5 | 0.8 to 3.0 |
| | airborne_alpha_deg | 12 | 2 to 24 |
| | airborne_support_share | 0.2125 | 0.15 to 0.5 |
| | airborne_hold_s | 0.05 | 0.05 to 0.8 |
| | airborne_helm_hold | 0 | 0 to 1 |
| | airborne_wind_from_kt | 18 | 12 to 26 |
| | airborne_wind_full_kt | 20 | 13 to 30 |
| getting on the plane, steering below it (last night's) | plane_bear_away_deg | 0 | 0 to 25 |
| | plane_bear_away_to_twa_deg | 125 | 100 to 145 |
| | plane_help_full_ms | 4.0 | 2 to 6 |
| | plane_help_until_ms | 8.5 | 6 to 9.6 |
| | helm_rate_per_s | 2.625 | 1.0 to 3.5 |
| | slow_rate_gain_scale | 1.675 | 0.3 to 3.0 |
| | slow_integral_scale | 0.325 | 0.3 to 3.0 |
| | slow_hold_scale | 1.4 | 0.4 to 2.0 |
| | hold_lead_s | 0 | 0 to 0.8 |
| | hold_rate_per_deg | 0.8 | 0.3 to 1.5 |
| | hold_rate_limit_dps | 20 | 8 to 30 |
| | rate_gain | 0.01525 | 0.004 to 0.025 |
| | rate_integral_gain | 0.02 | 0.005 to 0.05 |
| the reflex (last night's) | reflex_from_share | 0.5 | 0.5 to 0.85 |
| | reflex_full_share | 0.9 | 0.75 to 0.99 |
| | reflex_alpha_deg | 6 | 2 to 14 |
| | reflex_bear_away_dps | 12 | 0 to 16 |
| | reflex_hold_s | 0.3 | 0.1 to 0.8 |

The key and manoeuvre numbers of last night (Shift carve, the key ramp, tacks and gybes) are not
turned: the lake cases press no keys, and the guards keep them honest.

### Reading its output

- `.sim_output/lake_speed/tuner.log`: one line per candidate (the number changed, its total, KEPT
  when it became the best, the speed in the gusts per course and wind).
- `.sim_output/lake_speed/leaderboard.md`: the 40 best candidates by total, then every candidate in
  order, each scenario's cost, the falls and the speeds in the gusts.
- `Documentation/reports/autopilot/lake_speed/best.txt`: the best set as the whole NIGHT_TUNING it
  would make, with its scores and speeds against the baseline in the comment lines; rewritten
  whenever the best improves.
- Each candidate: `.sim_output/lake_speed/candidates/<cNNNN>/` (a log and a track CSV per case,
  `results.json`, `scores.json`).

### Stopping and resuming

It stops by itself when it has converged. To stop it sooner: `touch .sim_output/lake_speed/STOP` (it
stops after the pair it is scoring, within about 6 minutes), or end its Python and Godot processes.
To resume: start it again (it carries on from `.sim_output/lake_speed/tuner_state.json`; `--fresh=1`
starts over). Detached, as it was started (PowerShell):

    Start-Process -FilePath "C:\Program Files\Git\usr\bin\bash.exe" -ArgumentList @('-l', '/c/Users/MAXDED~1/source/WindsurfingMMZB-fixes/tools/lake_tuner_detached.sh') -WindowStyle Minimized

It uses 12 Godot processes of the 16 cores, so Max can still play on the PC (a little slower).

### An interim build for Max

`tools/lake_tuner_apply.sh` (from the worktree root, with GODOT set) writes the current `best.txt`
into `PlayerController.NIGHT_TUNING`, runs the night-tuning and lake unit tests and the load check,
commits it, runs `tools/release.sh build` and makes the play folder
`C:/Users/Max de Dikke/source/WindsurfingMMZB-play-7nov2026-lake-<hhmm>` with the morning folder's
launchers, cfgs and README. The running tuner is not disturbed. Before handing it over, glance at
`best.txt`: the gains should be spread over the scenarios, not one case.

## Questions for Michiel (the physics)

The technique cannot close these gaps alone; the numbers are the baseline's (with the night-tuned
steering, push 75 %).

1. **The waves cost a quarter of the speed across the wind.** Beam reach at x1.3 (22 to 24 kt at the
   board): flat water 52 to 56 km/h in the gusts, the lake's full waves 41 to 44 km/h, so 11 to 14
   km/h (20 to 25 %) lost; at x1.0 (16 kt) 4 to 7 km/h (11 to 15 %). In the waves the pitch rate's SD
   is 12 to 16 degrees a second (flat: 0.2 to 0.6) and the board goes light over a crest 50 to 90
   times a minute at 22 to 24 kt. Silvaplana sailors make 50 to 55 km/h across in that chop. Which
   part of the physics takes it: the hull's drag over the 1 to 4 m trains (the averaged wet bottom of
   PH44), the board following the short trains where a planing board skims over them, the fin's
   immersion and ventilation, or the sail's drive lost while the board pitches? A run with one of
   them off would show which.
2. **The broad reach is slow on flat water too.** At x1.3 on flat water, 135 degrees makes 34 to 45
   km/h in the gusts where 90 degrees makes 52 to 56 in the same wind; the 117 L / 7.5 m board settles
   at 28 to 31 km/h with 17 to 18 kt at the sail (heel 0, nose 2 degrees up), just above the planing
   onset (7.4 m/s). The validation's polar at 24 kt at sea level has 135 degrees as fast as 120 (14.7
   m/s), so it may be the thin air (0.98 kg/m3) with this wind putting the broad reach under the
   threshold where the apparent wind can build. Real slalom gear does 55 to 65 km/h at 135 degrees in
   20 kt. Is the sail's drive at an apparent wind of 70 to 80 degrees, and the hull's drag just above
   the hump, as intended?
3. **A broad reach from rest at x1.0 never planes** (15 kt at the board, 12.5 at the sail: 8 km/h
   after 75 s with the nose 3 degrees down; 100 to 120 degrees planes after 6 to 34 s). The tuner can
   head up to get going (`plane_head_up_deg`); pumping is not modelled.
4. **The nose dive from rest.** In the first 1 to 3 s after the sail fills, the nose goes 5 to 9
   degrees down and the bow 0.16 to 0.3 m under at x1.0, and at x1.3 on 130 degrees 13 to 20 degrees
   and 0.43 to 0.52 m (the bigger the board, the deeper). The sailor's stance is the sim's (forward at
   low speed, stepping back with the speed), so the controller can only ease the sheet and rake the
   rig back. Is the mast foot's push down plus a forward stance at standstill meant to bury the bow
   that far? A sailor starting in a strong wind stands back and the nose stays up.
5. **(For Max, the map.)** At x1.0 the wind at the board is 15 to 19 kt in most places and 22 kt at
   the south spot at 15:00, and its gusts along a 1 km track are small (the 90th percentile 1 to 2 kt
   over the mean). Max's Maloja afternoon (18 kt mean, gusts to 24) lies between x1.0 and x1.3.

## Not verified

- How it feels to play: the suite sails the player's controller headless with the autopilot's hands;
  the keys, the mouse and the camera are not in it.
- The gusts in the map's wind are mostly the place, not time: the "speed in the gusts" is measured
  where the wind at the board is in its top quarter along each track.
- The AI fleet is untouched (its defaults did not change), so no race was rerun.

## The downwind probe (7 November 2026, afternoon; not fixed yet, Max: "find the issue, do not fix it right away")

Runs in `.sim_output/downwind_probe/` (`run.sh`; new harness options `--twa_start`, `--bear_away_at`,
`--bear_away_steer`, `--forces=1` for the apparent wind, the sheet and the forces in the CSV). The 117 L /
7.5 m, the lake's middle at 14:30, flat water unless said.

| run | wind at the sail | what happened |
|---|---|---|
| x1.3, 100 degrees, then bear away to 135 at 25 s | 17 to 20 kt | 56 km/h on the reach (apparent 32 kt from 33 deg); after the bear-away the drive 290 -> 157 N against 240 N of drag: 47 -> 26 km/h in 20 s, off the plane at 50 s |
| the same, sea-level air | 17 to 20 kt | a little better (max 38 km/h), the same shape |
| x1.5, the same | 20 to 24 kt, bear-away in a lull | 59 -> 32 km/h in 15 s |
| x1.5, from rest at 135 | 20 to 24 kt | 46 to 55 km/h while the wind at the sail is 23 to 24 kt, 39 to 42 at 20 kt |
| x1.3, bear away to 125 only | 17 to 20 kt | max 48 km/h, still slowing |

Findings, in order of weight:
1. **Downwind needs real wind; across the wind the board makes its own.** On the reach the board's speed
   gives it 32 to 35 kt of apparent wind; at 135 degrees it only gets 15 to 19 kt. In the sim, 50 to 55
   km/h at 135 degrees holds with about 22 to 24 kt at the sail (about 26 to 28 kt at 10 m: the profile is
   0.84 from 10 m to the sail, shear exponent 0.11). The map at x1.3 gives 17 to 20 kt at the sail with
   gusts of 1 to 2 kt over the mean. The sail's pull at 16 kt apparent from 46 degrees (159 N) matches a
   textbook lift and drag estimate (the lead's estimate, not measured); the board's drag (hull + fin about
   200 N at 42 km/h, 220 at 55 downwind) is unverified. For Michiel: is that drag right? Max: "save this
   as an issue", core physics, 100 % right, check upwind too: [ISSUE_downwind_physics.md](ISSUE_downwind_physics.md)
   (backlog E01.S17).
2. **The map's wind turns along the lake; the autopilot holds a compass heading.** Sailing east from the
   middle the local wind veers from 223 to 241 degrees in 350 m (the lake's mean stays 222). The heading
   hold keeps the compass course, so 135 degrees to the wind becomes 145 to 160 (dead downwind, the sail
   stalled at 40 to 59 degrees of attack). Max: the turn is real, and the compass hold stays (fine for
   downwind tactics).
3. **Bearing away in a lull.** In two runs the bear-away came as the wind dropped 3 to 4 kt. A sailor bears
   away in the gust and heads up in the lull. Max: that is the test's own timing (a fixed 25 s), not the
   autopilot's; the autopilot does not get its own gust steering, the map's gusts are fine. The downwind case
   that waits for a gust: [PLAN_downwind_case.md](PLAN_downwind_case.md), to run after the training.
4. The waves (20 to 25 % across the wind, known) and the thin air (from rest at 135: max 33.5 km/h, 44.6 at
   sea level) come on top.

Not tested: another sail angle of attack (`--pilot.target_alpha_deg` did not reach the sail; the
controller sets its own 18 degrees).

## Stopped (7 November 2026, 23:25)

Max: "stop the AI training. It's good now, save it." The tuner's runs are kept in `.sim_output/lake_speed/`: `oldphysics_run_7nov1058` (184 candidates, 1206.0 -> 1068.1 with the gust bear-away at 3.75), `run_7nov2025_nogust`, `run_7nov2218_push`, `run_7nov2228_headup`, `run_7nov2234_headup60` and `run_7nov2321_stopped` (stopped before its baseline). The player's board sails `PlayerController.NIGHT_TUNING` as of commit d70cd1e and after (the low-speed steering fix: Documentation/reports/physics/realism_audit_7nov2026.md); best.txt is not applied again. The lake suite's guards now include the night's low-speed steering cases. Next: `PLAN_downwind_case.md`, when Max wants more training.
