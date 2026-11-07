# Plan: the downwind case in the lake suite (run after the training)

**How to start it:** when the lake tuner has stopped, tell Claude:
> Run the plan in Documentation/reports/autopilot/lake_speed/PLAN_downwind_case.md

**Why:** the lake suite's downwind cases start from rest on the downwind course, where no sailor gets going.
A sailor reaches across to get fast, then bears away in a gust. Max's decisions of 7 November 2026: build
this case (c: yes); the autopilot keeps its compass heading (a: no) and does not bear away in gusts by itself
(b: no); the probe's bear-away in a lull was the test's own fault and is fixed here.

**What to expect:** the physics issue (`ISSUE_downwind_physics.md`, E01.S17) caps the speed at 135 degrees:
in the strong afternoon wind the board slows after every bear-away. Until Michiel has worked through that
issue, this case can teach the autopilot to keep its speed longer after the bear-away; it cannot reach 55 km/h.

## Steps

0. **Before starting.** The tuner has stopped: the last line of `.sim_output/lake_speed/tuner.log` says so, or
   no Godot process runs from `.sim_output/lake_speed/project`. If it still runs, ask Max before stopping it.
   Work in `WindsurfingMMZB-fixes` on `autopilot/lake-speed`.

1. **Apply the training's best.** `tools/lake_tuner_apply.sh`: best.txt into `PlayerController.NIGHT_TUNING`,
   the unit tests, a commit, the release build, the play folder `WindsurfingMMZB-play-7nov2026-lake-<hhmm>`
   (+ zip, with the push-and-body launchers). Give Max the folder and the results table (before / after per
   scenario, the gust speeds, the falls) so he can play while the next steps run.

2. **The bear-away waits for a gust (the test's fix).** In `Game/dev/run_lake_speed.gd`: from `--bear_away_at`
   on, the hands bear away at the first moment the wind at the sail is at least `--gust_kt` (1.5) over its own
   10 s mean and rising; if no gust comes within `--gust_wait` (20 s), they bear away anyway and the result
   says `"gust": false`. The RESULT records the time, the place (game x/z and LV95) and the wind at the sail
   and at 10 m at the bear-away (Max: "keep track of where you do the test and track the wind").

3. **The cases** (`tools/lake_suite.py`, scenario `downwind`). A reach at 100 degrees, the bear-away in the
   gust to 135 degrees, and a second set to 125 degrees; the three gear combos; x1.0 and x1.3; the places
   middle and between; the lake's waves on (the game's water). One flat-water run per gear as an unscored
   reference. 12 scored cases (2 courses x 2 winds x 3 gears, the place alternating) plus 3 references.

4. **What each case measures.** The speed 5 s and 10 s after the bear-away, the gust speed after it, the
   seconds above 45 km/h, the speed made good along the course, the local true wind angle (the lake's wind
   turns; recorded, not corrected), the falls, the sail's angle of attack and the apparent wind.

5. **The cost.** The same form as the reach cases (the shortfall to the target in the gusts: 55 km/h downwind,
   Max's number) plus the speed lost in the 10 s after the bear-away; a fall costs 100.

6. **The baseline.** The suite with the applied best (step 1), the new cases included. Write the table into
   `README.md` (a new section) before tuning.

7. **The controller's angle of attack made settable.** The sail's 18 degrees comes from the controller, not
   from `Autopilot.target_alpha_deg` (the override does not reach it). Find it, make it a field, add it to the
   tuner's numbers (default unchanged).

8. **A tuner round.** `tools/lake_tuner.sh` with the new suite. The numbers: the sheet's pace, the angle of
   attack (step 7), the push, the rig's rake, the hike, the chop trim. Kept out: `gust_bear_away_deg` stays 0
   (Max: b no), no wind-angle hold (Max: a no). Time: the suite grows from 30 to 45 cases (about 6 to 7 min a
   candidate on this PC instead of 4.5); a round over about 45 numbers takes 8 to 10 h (an estimate): ask Max
   whether to run it overnight. Rounds stop by themselves when a round finds nothing better.

9. **Apply, check, document, push.** As step 1, then the full checks: `tools/test.sh`, `tools/check.sh`,
   `tools/test.sh validation` (the 8 known reds plus the lake fleet start), `tools/lan_test.sh --map=lake` (no
   live game on port 47520), the play folder with the launchers. The results in `README.md`, the ledger
   (`six_asks_6nov.md` on the play branch), ROADMAP and PROGRESS_LOG; push `autopilot/lake-speed`. Merging
   into `play/6nov-evening` and `main` only with Max.

## Not in this plan

The physics itself (E01.S17, Michiel's). The autopilot's own gust steering and a wind-angle hold (Max: no).
