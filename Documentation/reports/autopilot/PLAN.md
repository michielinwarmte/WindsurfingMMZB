# The autopilot on the new physics: the test suite and the rework

For Michiel and Max. Written 31 October 2026 by the lead (Fable 5.1) at Michiel's request: "oversee a low token use test suite to train the autopilot to use all the newly updated physics; plan many tests running on the CPU, review and retest later; many tests at once or in series before reconsidering; the testing may take 10 hours or more; then let me test it for confirmation." The physics is the branch `ph28/sail-and-hull` after Session 61 (the real 8.0 with the twist's formula, the 85 kg rider with one body and the front foot's couple, Max's rail by point of sail, the hull as before with its three options off). Nothing in `Game/sim/` changes in this work; the autopilot (`Game/sim/autopilot.gd`), the helm (`Game/sim/helm.gd`) and the sailor's technique settings the autopilot sets (`SailorConfig`, through the sim's copy as package B does) are what is reworked. The progress and the token ledger are in [PROGRESS.md](PROGRESS.md).

## 1. The goal, in numbers

What the autopilot is to achieve is what the reviews, [flying_the_board.md](../ph28/flying_the_board.md) (sections 1, 2, 6 and 8), [sailor_controls_plan.md](../ph28/sailor_controls_plan.md) (P3 and P6) and Max's answers ([questions_for_max.md](../ph28/questions_for_max.md)) describe: a slalom sailor's ride, and a push dial that turns that ride up until the physics punishes it.

| What | Target | Source | Where it is measured |
|---|---|---|---|
| The wet part on the 18 and 24 kt beam and broad reaches | the wet front 0.6 to 1.0 m from the tail | Gourlay & Martellotta 2011 (0.8 m), Sutherland 1993 (about 1.0), the shapers (0.8) | the reach check (`front`), validation target 3 |
| The trim there | 1.0 to 2.5 degrees, falling with speed | Savitsky's equations for this load and width; Gourlay's curve | the reach check (`trim`), validation target 4 |
| The push's centre | 0.45 to 0.75 m from the tail | Gourlay 0.6 m | the reach check (`push`), validation target 4 |
| Steadiness on flat water | pitch SD below 0.3 degrees on all nine reaches | the team's own limit (U1 target 2) | the reach check (`pitchSD`), validation target 2 |
| The rake on a reach | not at its stop; the photos' 15 to 25 degrees | the photos (sailor_controls_plan.md section 2); the tunnel's rig-back 18 | the reach check's CSV (`rake`), the budget tool |
| The rig's lean to windward | 15 to 35 degrees, more when more powered | the photos | the reach check's CSV (`rig_lean_deg`) |
| The rail | the leeward rail down 1 to 3 degrees crosswind, up to 10 upwind, flat downwind | Max, 30 October 2026 | built in the sailor (`fin_load_bank_*`); the reach check (`heel`) |
| The sheet | closed on the planing reaches, the top spilling | the formula's sail; review_sail.md finding 11 | the reach check's CSV (`sheet`, `alpha_deg`) |
| The harness | 300 to 500 N for 85 kg on a planing reach | Walls & Gale 2001, scaled | the reach check (`harness`) |
| Gusts and waves, the neutral dial | no falls in 120 s at 12, 18 and 24 kt on 48, 100 and 135 degrees; the speed made good not below today's | the push check (today's table in [rider_feet_body.md](../ph28/rider_feet_body.md)) | `tools/push_check.sh` |
| The push, eased 0.8 / neutral 1.0 / pushed 1.6 | pushing pays only with the late ease; pushed, the board bounces, spins out or catapults at 18 and 24 kt (Max: at 12 kt too, in real life) | GP0's report, Max's answers 15 to 17 | `tools/push_check.sh --sweep=pilot.hike_share=0.8,1.0,1.6` |
| The manoeuvres | tack, gybe, run, out of irons and straight all complete at 12, 18 and 24 kt, no falls | the matrix as it stands | `tools/matrix.sh` |
| Lake Silvaplana | the same in the map's thin air and fresh water | the lake matrix as it stands | `tools/lake_matrix.sh` |
| The races | the skipper test's times not worse than today's; the fleet starts | validation (`test_skipper.gd`, `test_living_skipper_fleet.gd`) | `tools/test.sh validation` |
| Validation | the known reds not growing; no new red without a reason written down | the list in PROGRESS_LOG.md | `tools/test.sh validation` |

The first three rows are the goal; the rest are what must not get worse while reaching for it. If the goal cannot be reached with the levers below, the suite says which lever is missing, in numbers, and that is the result.

## 2. The levers

What the autopilot can move today without a physics change, from the reviews:

1. **Steering with the feet and the rail before the rake** (P6.1). `Autopilot.lean_share` is 0 ("a flat board") and `trim_with_rake_first` runs the rake to its stop on a reach, which drags the sail's upward pull to the tail (flying_the_board.md section 3). The helm's third lever (the weight on the inside rail, `Helm.steer`'s `lean`) exists. Rework: hold the steady part of the course with the rail and the feet, the rake for the quick part and never at its stop on a reach.
2. **The rig's lean as the rider's own input** (P3.1). `SimControls.rig_tilt` is used only for steering. Rework: the pilot sets it from the power (more powered, more lean, 15 to 35 degrees), on top of the hike's own lean, and the push dial raises it.
3. **The technique the pilot asks of the sailor** (P6.4): the trim aimed for by speed (`running_trim_deg`, `running_trim_fast_deg`; Gourlay's curve: 3 degrees at 12 kn, 2 at 14, about 1 at 20), the front foot's couple (`front_foot_pull_held_n`, built), the rail (`fin_load_bank_deg`, `fin_load_bank_upwind_deg`, Max's), the bounce tolerated (`bounce_tolerance_dps`), the hike (`hike_share`, `ankle_share`). These are `SailorConfig` numbers set on the sim's own copy, as package B's mouse does; the AI boards get the same (rule 7).
4. **The margin**: `hike_share`, the depower reflexes, `catch_alpha_max_deg`, `sheet_in_share`, and `alpha_luff_deg` read from the sail (it is 5 where the sail's is 2: review_sail.md 7b).
5. **The rake's stop** (`SailConfig.max_rake_deg`, 25): the tunnel's rig-back was 18 and the photos read 15 to 25. A number of the rig's geometry: measured as a variant here, Michiel's to change.

Not a lever here: anything in `Game/sim/` beyond the settings above (the back foot's push against the fin, the hull's clip, the bounce felt in waves: the roadmap's PH items).

## 3. The suite

One script runs a whole round and one script reads it, so a round costs one launch and one read:

- `tools/autopilot_suite.sh --round=<name> --variants=<file>`: for each variant (a label and its overrides, one per line of the file) it runs, in one Godot process each, the reach check (nine cases, 90 s, the means from 60 s, the CSVs kept), the push check at the neutral dial (nine cases, 120 s, three processes) and at the pushed dial (18 and 24 kt, six cases), and the manoeuvre matrix; the outputs go to `.sim_output/autopilot/<round>/<label>/`. About 8 minutes a variant; six variants an hour. The lake matrix, validation and the races are run once per round that changes code, at the end of it.
- `tools/autopilot_summary.py <round>`: one table per variant, forty lines: per reach case the speed, the wet front, the push, the trim, the pitch SD, the rake, the lean, the harness and a fall; per push case the speed made good and the falls; the matrix's completed cases. The goal's rows are marked met or not.

The rounds:

| Round | What | Code change | Hours |
|---|---|---|---|
| 0 | The baseline on the merged physics (Session 61's measurements) and the suite itself | the two scripts | 1 |
| 1 | The existing levers swept, no code: `lean_share` 0 / 0.2 / 0.4; `max_rake_deg` 18 / 25; `running_trim_deg` 1.5 / 2 / 3; `fin_load_bank_deg` 1 / 2 / 3; `front_foot_pull_held_n` 0 / 200 / 250; `max_rig_lean_deg` 25 / 35; crossed where the first pass says they interact | none | 2 |
| 2 | The course hold reworked: the rail and the feet carry the steady helm, the rake the quick part and never at its stop on a reach; `alpha_luff_deg` from the sail | `autopilot.gd`, `helm.gd` | 2 |
| 3 | The lean as the rider's lever from the power; the technique set by the pilot by speed and point of sail | `autopilot.gd` | 2 |
| 4 | The dial onto the technique: eased / neutral / pushed through the same fields; GP0's sweep rerun; the catapult, the bounce and the spin-out as the failures | `autopilot.gd`, the push check's dial | 2 |
| 5 | Regression: the matrix, the lake, validation, the races; the known reds by cause | none | 1 to 2 |
| 6 | The report, the roadmap, the hand-over to Michiel's play-test | none | 1 |

Each round is launched as one background batch, read once as one summary, and decided on once. Variants that fail the "must not get worse" rows are dropped at the read, not re-run. No trace is pulled unless one case decides a round.

## 4. Stops

- A variant that makes a flat-water reach fall or bounce (pitch SD above 0.3) is reported, not tuned around.
- Nothing fitted to a number: every setting kept has its source line in the summary and in `PROGRESS.md`.
- A change that needs `Game/sim/` is written down as an open item for Michiel, with the measurement that asks for it.
- The token ledger in `PROGRESS.md` after every round; the work stops for the day when a round's read shows the levers exhausted, or at the budget.

## 5. Hand-over

When the rounds are done: the report `Documentation/reports/autopilot/autopilot_rework.md` (the goal's table with the numbers before and after, each lever's effect, what is open), the roadmap's RA and GP rows, the progress log, and a play-test list for Michiel: `tools/play.sh res://main.tscn` with the autopilot (`--autopilot=1`), `tools/play_push.sh` for the dial, and `tools/play.sh lake`.
