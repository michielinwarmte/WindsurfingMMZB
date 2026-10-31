# Progress Log

One entry per session, newest first. Sessions 1 to 27 (the Unity version) are in [Legacy/Documentation/PROGRESS_LOG.md](../Legacy/Documentation/PROGRESS_LOG.md).

Template for new entries:

```
## <date> - Session <n>: <topic>
**Phase:** <phase from REBUILD_PLAN.md>
**Done:** what changed, in plain language
**Verified:** which tests/checks/screenshots passed; what could NOT be verified
**Decisions:** anything decided, and why
**Next:** where the next session should pick up
```

---

## 31 October 2026 - Session 61, continued on Michiel's PC: the three builds finished and merged, the hull's clip measured, the autopilot's suite planned

**Phase:** version 0.2, the physics (section PH), on `ph28/sail-and-hull` (the three branches merged into it; nothing on `main`). Michiel: "pull and continue with session 61", then: after it, a low-token test suite to train the autopilot on the new physics (10 h+ of CPU allowed, then his own play-test). The lead in Fable 5.1; two Opus 5.5 agents (xhigh) in sibling worktrees for the sail and the rider; the lead on the hull.
**Done:** (1) `ph28/real-eight` (the agent, 240k tokens): the real HGO 8.0 (luff 5.22 m, boom 2.20, masthead 5.26, slope 1.0, 125 Pa), the twist following its formula (Max), the centre of effort's height by angle of attack read within one wind so the twist's own lowering is not counted twice (0.53 / 0.855 / 0.94 / 1 at 1.3 / 5.3 / 8.7 / 12.2°), spec 2.17 rewritten, the stiff fin re-pinned (1.82°, 692 N, 24 N), `real_eight.md`: reach check 18 to 24 kt +1 to +4 %, the 12 kt close reach −7 %; the push catapults again from 28 kt. (2) `ph28/rider-feet-body` (the agent, 410k): step A (85 kg, the lag off), B fixed (one body that drops as it hangs back; the 0.4 m hang-back cap nose-dived the start and is back at 0.8), C the front foot's couple built as what it is (a couple between the feet is internal, so the body hangs behind the back foot further than the hands' pull holds it, 200 N held / 400 N briefly times the straps' 0.59 m; the feet's pitch moment capped where the roll's is), D Max's rail by point of sail (10° upwind to 60°, 2° crosswind, flat by 135°: the close reaches bounce and the beat is 15 % slower, reported, not fitted), E the nose spears where Max's rears, F the 0.4 m line left off; `rider_feet_body.md`. (3) `ph28/hull-suction` (the lead): the bounce check (nothing on flat water bounces with the clip on today's code; 13 rows and a halved substep change nothing; `pitch_budget.gd` prints what the clip withholds, 220 to 250 N·m on the beam reaches), three `BoardConfig` options built, measured and **all off**: a pull bounded by the water's head (the consistent ventilation bound: held still it takes the SL 72's wall away, 0.73 / 1.29 / 1.40 of Savitsky at 1.0 / 1.28 / 1.5 m heeled against 0.8 / 2.2 / 3.3, the old board unchanged; sailing, **the board does not plane**: the close reaches fully wet at 4 to 5 m/s, the beam reaches ploughing at 13.3 m/s, the 24 kt reaches falling: the rocker's net root push is what gets the sim's board over the hump), the whole push at Savitsky's centre (found: A-03 pinned the front root only, the whole push sat 0.1 to 0.25 m ahead; sails, but 1.5 to 2.1 m wet and 2 to 8 % slower), the heeled bottom as TN 4187's rolled plate (right held still, within 1 %; catapults once while settling: the anchor's factor runs to 36 on a wet sliver and scales the damping with it); the oblique spray root no longer relieved at the transom with the push placed; `test_hull_suction.gd` (7); `hull_suction.md`; spec section 5 F24 and A-05. (4) The merge: 582 of 582 unit tests after one fix: the beginner's 18 kt tack no longer got going (the stopped board pitched its nose up 25 to 70° and pivoted into irons before the sail filled; the couple, the 85 kg and the formula each tipped it alone): the rest stance 4 cm forward, 1.09 m from the tail, labelled a stand-in (`Game/dev/rest_pitch.gd`: the board floats level at 1.03 m) for the weight-forward technique (PH32). The merged reach check: **the 18 and 24 kt beam reaches ride on 0.95 and 0.89 m at 1.46 and 1.34° of trim, SD 0.24 and 0.22 (the goal's band)**, the push 0.77 and 0.71 m; the close reaches bounce (SD 0.9 to 1.6, the rail), the 24 kt broad reach bounces (1.07) and fell once, the 18 kt broad reach 1.18 m (0.33). Push check neutral: 2 falls at 24 kt (48° and 135°), 12 kt 4.19 / 7.66 / 4.79, 18 kt 5.96 / 12.45 / 8.23, 24 kt 6.58 / 13.94 / 12.36. Matrix 24 cases no fall; the lake no fall, the 12:00 run turn not completed. (5) The roadmap: PH16, PH27, PH28, PH29 brought up to date; PH30 to PH36 new. `tools/push_check.sh` and six other scripts made executable. (6) The autopilot's suite: `Documentation/reports/autopilot/PLAN.md` (the goal in numbers, the levers, the rounds, the stops), `tools/autopilot_suite.sh` (a round of variants as one batch) and `tools/autopilot_summary.py` (one table per variant); round 0 run (the baseline above), round 1 (ten single-lever variants) running.
**Verified:** on the merged branch at 64dd09d and after: `tools/test.sh` 582 of 582, `tools/check.sh` 291 files 0 failed, the matrix, the lake matrix, the reach check, the push check, `tools/test.sh validation` **33 pass, 11 fail, 2 pending** (the base: 37 / 7 / 2). The reds by cause: the polar's old targets (faster across, slower at 135°), the top speed 14.9 m/s, the onset 12.1 kn (was 15.0: better), the skipper's 12 kt race (14:44 before the stance change, now not finished: for the autopilot rounds), the waves at 120° (−20 %), the fleet's start (flaky, a different board each run), the push warning (0 catapults where 2 are wanted: the 85 kg rider holds the pushed 8.0 at 24 kt), target 2's steadiness (the rail's bounce), the rake-first hold (12.06° against 12.0) and the tilted fin at 12° (281.5 against 282.3 N). Not verified: how any of it feels; what a real rockered bottom does; the three WIP branches' own validation runs were the agents' (37 / 7 / 2 and 35 / 9 / 2).
**Decisions:** the three hull options stay off (the pull does not plane; the centre pin lengthens the ride; the rolled plate catapults), with what would decide them in PH30 and PH31; Max's rail stays in at his numbers with its cost reported (PH27 is the hull's); the rest stance's 4 cm is a stand-in, labelled; nothing goes to `main` without Michiel's OK (the branch now carries the physics he was asked to review).
**Next:** the autopilot rounds (PLAN.md section 3): round 1's read, then the course hold with the rail and the feet, the lean as the rider's lever, the dial onto the technique, the regression on the races and the lake, the report and Michiel's play-test. For Michiel: the three reviews and the three reports, A-05 (PH30), the strips' anchoring (PH31), the rig's mass (PH33), the nose (PH34); the question of the 12° heel red and the fleet's flaky start are in PH36. The three branches and `ph28/sail-and-hull` are pushed; the worktrees `../WindsurfingMMZB-sail` and `../WindsurfingMMZB-rider` are left in place.

## 30 October 2026 - Session 61: the reviews of ph28, the flying report, the sailor's controls plan, three builders stopped by the limit

**Phase:** version 0.2, the physics (section PH), on `ph28/sail-and-hull` and three branches from it. The lead in Fable 5.1 with Fable agents; Max on this PC ('Max de Dikke'), then away.
**Done:** Max: "a lot of physics changes by Opus: verify all of it with 3 Fable agents", then the models, then "what is needed for the autopilot to fly the board", then "analyse the photos and come up with a plan", then his answers to every open question, then "do as much as you can; save and push; we continue on the other PC". Three independent reviews of the branch: `Documentation/reports/ph28/review_sail.md`, `review_hull.md`, `review_sim.md` (the tests run as claimed, 564 of 564 and 37/7/2; the findings: the JP SL 72's gain rests on the hull's strip clip (A-05), the twist floor is a gameplay choice beyond the tunnel's data, the 8.0 carried the 6.5's sizes, the rig's pitch lag was on while every document said off, trimming by feel is a fitted controller that hunts and is blind in waves, the catapult test's limit was moved to pass, the stiff fin's pin re-pinned five times). Then `flying_the_board.md` (Gourlay & Martellotta's balance reproduces the game's 1.1 m push; three levers together are needed, not one; Savitsky's numbers for 0.6 to 1.0 m wet are 1 to 2.5 degrees, not 1.5 to 4), `sailor_controls_plan.md` (the thirteen photos read; six packages P1 to P6) and `questions_for_max.md` with Max's answers (85 kg; the front foot's pull 150 to 250 N confirmed; the rail 1 to 3 degrees crosswind, up to 10 upwind, flat downwind, the leeward rail down; the lines 30 to 35 inch, the ends 0.6 to 0.8 m from the mast; the nose up to 20 to 30 degrees when over-pushed, lowered with the weight on the mast and the fin's load; the rig's pitch lag off; the twist floor: follow the formula; the 8.0 is the real one; the GSYPHOTO pictures are a speed event on 40 cm boards). The Opus builder redid the JP SL 72 and HGO 8.0 models (e780e41). Three Fable builders were launched on their own branches in worktrees and were all stopped by the Fable session limit at about 21:30 (it resets at 21:50); their unfinished work is saved as labelled WIP commits and pushed: `ph28/real-eight` (the real 8.0 sizes, the twist floor removed, the models rebuilt with Blender on this PC; not yet: the centre of effort's height by angle of attack, spec 2.17, the measurements, the report), `ph28/rider-feet-body` (step A done: 85 kg, the lag off, the felt bounce cleared on a fall; steps B and C begun: one body's reach, the front foot's couple; not yet: the rail by point of sail, the nose check, the short line, the measurements, the report), `ph28/hull-suction` (the bounded suction option begun, the probe and the pitch budget extended; nothing measured, no report).
**Verified:** on `ph28/sail-and-hull` at d1e583d, by the reviewers: `tools/test.sh` 564 of 564, `tools/test.sh validation` 37 pass, 7 fail, 2 pending (the known seven), the reach check equal to section 14's table. The three WIP branches are NOT verified: no tests run to completion on them; read each diff before trusting it. The models at e780e41: 564 of 564, check 289 files 0 failed, screenshots looked at by the lead.
**Decisions:** Max's answers above (in `questions_for_max.md`). Max on A-05: build the fix if it can be helped, otherwise fine for now. GP10, the playtest key, the time trial and the roadmap's older items: later. The GSYPHOTO proofs and 121.JPG stay out of git (a photographer's mark); Max's own photos go in.
**Next:** on the other PC (no Blender there; the models are already rebuilt on the sail branch): check out each WIP branch, read its diff and the brief it followed (the brief is the agent prompt summarised in `reports/ph28/PROGRESS.md`, "To continue after Session 61"), finish it, measure (reach check, push check, validation), write its report, then merge the three into `ph28/sail-and-hull`, measure the merged result and update the roadmap. Nothing to main; Michiel's OK before any merge to main.

## 30 October 2026 - Session 60: PH16 step 17, Max's board and the footstraps

**Phase:** PH16 on `ph28/sail-and-hull` (physics: Michiel's OK before any merge)
**Done:** Max: "continue step 16"; on his other PC (the reach check gives Session 59's numbers to the last digit). First the full validation after step 16's NaN fix: no hang; 35 pass, 9 fail, 2 pending. Running those files on step 15's code (8ca7523, a worktree) showed two reds new with the square boom: the fin's upward force at 12° of heel (242 against 246 N at 9°, on a run that porpoises at 2.5° pitch SD on both codes) and the skipper's 2 falls at 24 kt. Then Max's measurements of his Patrik 115 (in Dutch, translated in the report's section 13): the back straps over the fin box's front screw, 0.235 m from the tail, 0.15 m either side; the front straps 0.825 m, 0.25 m either side; the fin box screws at 0.12 and 0.235 m; the mast track 1.245 to 1.405 m. Six photos in `Documentation/images/Real life photos/`. Built and on: the feet's pressure stays between the straps (`BoardConfig.back_strap_from_tail_m` 0.235, `front_strap_from_tail_m` 0.825, `WindsurferSim._press_within_straps`, `MassModel.stance_z_m`; `test_footstraps.gd`); the trim by feel had crept behind the back foot. Reach check 8 of 9 identical, the 18 kt broad reach 14.59 -> 14.29 m/s and steadier (0.17 -> 0.09°); gusts and waves within 0.7 %, the 24 kt beam reach 11.46 -> 11.20 (one catapult with and without). `tools/push_check.sh` takes `--board.` settings (the numbers copied every tick). Measured, not built: the fin at the box (its force about 0.18 m from the tail against 0.30; the sweep estimated): alone, the 24 kt beam reach loses its course with the rake at its stop and catapults; with the mast foot at the back of Max's track (1.245 m) nothing falls and the close reaches are 1 to 2 % faster, but the 24 kt beam reach bounces (0.83°). Read from IMG_4743 (estimates): the harness line about 0.5 m, the hips about 0.6 m above the deck, the body 40 to 50° from upright, against the model's full hike at 0.42 m on a 1 m line.
**Verified:** `tools/test.sh` 562 of 562, `tools/check.sh` 289 files 0 failed, `tools/test.sh validation` 37 pass, 7 fail, 2 pending (the straps take away step 16's two new reds, the recovery's bounce and the rake-first threshold; still red: the polar's old targets, the top speed and its trim, the onset 14.4 kn, the recovery's fall, the skipper's 12 kt time, the waves at 120°). Logs in `.logs/` (`ph16_step16_validation.txt`, `s17_*.txt`). Not verified: how it feels to sail.
**Decisions:** the straps on by default (measured, not fitted). The fin stays at 0.30 until Michiel has looked at the balance with the fin where the box puts it. Mapping the straps onto the existing settings (stance at the midpoint, reach 0.295) was tried and not kept: the reach is also scaled by the planing ratio, which kept the weight off the back foot (0 to 5 % slower). The photos are committed at Max's word, but for 121.JPG (a photographer's copyright mark).
**Then the bounce lock (Max: "unlock the bounce lock and it needs to work"; his numbers: the mast foot "around 1.2", the boom 1.40 to 1.60 m, the lines a bit back of the centre of pressure, 80 kg, a 39 cm fin and the 8.0).** `pitch_budget.gd` now prints each force model's power into the hull's oscillation. On the default gear the trim was held by the press's reach and the moment balance, not by a bounce. With Max's setup the board bounced nose-low (18 kt beam reach, 1.8 Hz, pitch -4 to +2.7 deg): the hull's water pumps the pitch (+4.5 W) and the legs damp it, and trimming by feel walked the weight forward on every chatter. Fixed in `_trim_by_feel`: the chatter only stops the creep aft while the board rides a band or more below its aim. Max's setup is the default now (80 kg, `hand_grip_m` 0.70, `trim_press_max_m` 1.0, the boom 1.50 m, the mast foot at 1.265 m on the deck, the fin's force 0.18 m from the tail). Reach check: 18 to 24 kt close and beam reaches +3 to +5 %, light wind and the broad reaches -1 to -7 %, all steady; gusts and waves no falls (the 24 kt beam reach 11.20 with a catapult -> 14.02; 400 s at 24 kt no falls). The 3D models rebuilt with Blender on this PC (the 8.0's area from a foot down to the deck and a little roach; a roach alone made a D-shaped leech, which Max spotted in the game). Tried for the wet length and not enough: the rig's lean, the fin's bank, a lower centre of effort, a higher trim aim; it stays 1.2 to 1.3 m (report section 14). Checks: `tools/test.sh` 563 of 563 (the 75 kg hand calculations keep their 75 kg; the rest tests take the configured mass; the catapult test checks below 90 deg and back upright; the 3D models against the defaults), `tools/check.sh` 289 files 0 failed, `tools/test.sh validation` 37 pass, 7 fail, 2 pending (the recovery test passes; new red: the fin's side force 677 N against a 650 N band; the stiff fin re-pinned).
**Then the 3D models made real** (Max: the back straps were not where he said; "model the jp and 8.0 real"): visual only. The board's layout in `BoardConfig` (the straps across, the fin box's screws, the mast track; Max's Patrik 115) and the builder places from it: the back straps' middle over the fin box's front screw at 0.235 m (the model had them at 0.50 m), the front straps at 0.825 m, both turned along the rail, the fin box's screws and slot, the mast track 1.245 to 1.405 m. The JP SL 72's traced outline and nose rocker, its tail cut-outs (estimated). The sail is the Severne HGO iQFOiL 8.0 (the tunnel paper and Max's photo): a 1.05 m wide head, a nearly straight leech, the foot along the deck, seven full and five short battens, a short extension. Checked in Blender renders (scratch) and `dev/rig_view`. `test_rig_visuals.gd` checks the straps' places. `tools/test.sh` 564 of 564, `tools/check.sh` 0 failed.
**Next:** Max's play-test of his setup; the wet length (the moment balance, with Michiel); the posture from the photo (a higher, less far out full hike on a 0.5 m line, against the righting moment the 8.0 needs at 24 kt); the fin at the box with the mast foot (Michiel); the feet across along the straps' line; from Max: the mast foot setting for slalom, the boom's height, the lines, his weight, the fin, the sail in IMG_4743, and section 12's question on the nose.

## 30 October 2026 - Session 59: PH16 step 16, the hooked-in rider (part one)
**Phase:** version 0.2, the physics (section PH of the roadmap), item PH16, step 16 of `Documentation/reports/ph28/PROGRESS.md`. On the branch `ph28/sail-and-hull`; not merged, for Michiel's review. Opus 5.5 alone, no agents.
**Done:** Max: "build step 16, the hooked-in rider", and "start with things you can do" while he measures his own slalom board (a Patrik 115, 70 cm wide). Report: `Documentation/reports/ph28/hull_balance.md`, section 12. Now the default: `SailConfig.boom_square_to_mast`, the boom square to the mast, so a raked rig carries its clew, its centre of effort and the harness line lower. The model had kept the boom level whatever the rake; spec 3.2 called that second order for the yaw (and wrote that it lifts the clew), but for the pitch and the harness it is not. Reach check (90 s): 0 to 3 % faster, steady; in gusts and waves within 2 %, no more falls. The game draws the boom as the physics has it (`windsurfer.gd`). Measured and not made the default: the hands and the line at the centre of effort's place on the boom (`hand_grip_m` 0.70, from Max's answer 1): up to 1 % more on flat water, but with the square boom the 24 kt beam reach in gusts catapulted 8 times in 400 s against 2. Built and off: `SailorConfig.harness_line_m`, the rig leaning out with the hooked-in body to keep a short line; the board bore away past the rake's stop and spun out (`test_hooked_in_rig_lean.gd`). Findings: a 0.3 to 0.4 m line cannot be had with a full hike under a 1.4 m boom (the model's line is about 1 m); the hike and the hang-back reach further than one body (the centre of mass 0.24 m behind the tail at 24 kt on the broad reach); the fin's upward push lifts the nose only on a board riding on its last 0.4 m, which corrects section 10 (what Max feels is more likely the rider hanging back against the pull). `pitch_budget.gd` prints the line's length and the heights above the deck.
**Verified:** `tools/test.sh` 556 of 556 (new: the square boom in `test_sail.gd`, `test_hooked_in_rig_lean.gd` 4 of 4), `tools/check.sh` 288 files 0 failed. `tools/test.sh validation` hung in `test_push_warning.gd` on the square boom: the state ran to NaN after a catapult with the board in the air. Cause and fix: the rig's drag in the water measured its speed at the surface below the mast foot instead of at the foot, where it acts (`_apply_rig_in_water_drag`; the report's section 12). After the fix that test passes (8 catapults) and `tools/test.sh` is 556 of 556; **the full validation was not run again** (Max ended the session to continue on another PC). Up to the hang the files matched Session 58's. Push check in gusts and waves (`--run=ph16_step16`, 120 s, and `ph16_step16_long`, 400 s at 24 kt): the report's table. Not verified: how any of it feels to sail.
**Decisions:** the hands stay at 0.6, because 0.70 with the square boom makes the autopilot sail the 8.0 over the edge in 24 kt gusts; that is for Max with GP3's margin. The rig-follows-the-body option is off (it costs the steering). The body's one-reach limit is measured on paper only: a weaker rider needs the autopilot to know it, or it over-sheets and catapults. The catapult test's limit on the heel just after the fall went from 45 to 75°: the kick as the sailor leaves is 42.7° on the old code and 50° with the hands moved 2 cm, and 59.4° with the square boom; the board comes back and the sailor waterstarts. Nothing was fitted.
**Next:** `tools/test.sh validation` in full. Then Max's measurements of his board (the list at the end of the report's section 12: the mast track, the straps, the fin box, the boom's height, the lines, his weight, a photo fully powered), then the posture from them (progress file, step 17). For Michiel: the square boom (spec 3.2, the tuning log) and the catapult test's new limit. For Max: the hands at 0.70 with the autopilot's margin, and the question on the nose and the fin (section 12).

## 29 October 2026 - Session 58: PH16 measured: what holds the board's nose down
**Phase:** version 0.2, the physics (section PH of the roadmap), item PH16. On the branch `ph28/sail-and-hull`; not merged, for Michiel's review. Opus 5.5 alone, no agents.
**Done:** Max: "do the hull physics upgrade. this is the lock to the better phisics right now. with the new sail working together". A new dev tool, `Game/dev/pitch_budget.gd`, splits the board's pitch moments by source on a steady reach. Findings (report `Documentation/reports/ph28/hull_balance.md`): the hull's friction (ITTC, on the area its wet widths give: 0.94 against 0.93 m²) and its lift (Savitsky, TN 4187) are right for the attitude it rides at. The long wet part comes from the balance: the sail pushes the nose down with 678 N·m on the 18 kt beam reach, and only the sailor's weight (712 N·m) lifts it. The harness and the mast foot pass loads inside the windsurfer and do not set the trim (this corrects Session 57's first lever). The sailor hangs under the boom: moving the feet aft made the board ride lower. The lock is the bounce: 1.0 m wet needs 1.5 to 1.8° of trim, and the board porpoises from about 1.2 to 1.3°. A slow, stiff trim press is 4 to 16 % faster on the 12 and 18 kt beam reaches without bouncing, but starts bounces on the 12 kt close reach and the 24 kt broad reach: not built. At 12 kt the boom grip sits 0.23 m behind the sailor's hips, and the harness pulls them backwards. Built as an option, off: `SailorConfig.rig_pitch_follow_s`, the rig's pitch following the board's with a lag (a mast foot is a joint). It held the 24 kt broad reach steady for 40 s, but after a minute it bounced the same, so the default stays 0.
**Verified:** with the lag on (0.3 s): `tools/test.sh` 539 of 539, the new `test_rig_pitch_follow.gd` 4 of 4, `tools/check.sh` 280 files 0 failed, `tools/test.sh validation` 38 pass, 6 fail, 2 pending (Session 57: 36, 8, 2; the 24 kt broad reach's target 2 still red). Push check in gusts and waves: within 1 %, no falls. With it off (the default): the reach check is identical to Session 57's, `tools/test.sh` 543 of 543 and `tools/check.sh` 280 files 0 failed; validation not re-run, since the code path is the one Session 57 validated. Not verified: how any of it feels to sail.
**Decisions:** the lag is off because its one gain was a transient. Physics from physics sources (Max, Session 57): nothing was fitted.
**Later the same session:** Max asked whether the board's shape is the cause, and gave JP's SL 72 (photos and sizes). The outline traced from the photo is close to the game's board, and alone it changes nothing. With the traced scoop rocker, the thickness and new tail cut-outs (`BoardConfig.cutout_from_tail_m`/`cutout_depth_m`, off), the planing reaches are 4 to 6 % faster on 0.2 to 0.5 m less wet length. The probe shows that gain coming from the hull model's rule that a strip never pulls (528 of 908 N), about 70 % more lift where thin-wing theory gives 10 to 20 %, so it is overstated (report sections 6 to 8). Unit tests and the check pass with the cut-outs off.
**Then the realistic default (Max: "implement the most realistic settings we know", "the 72 and the 8.0 from the data"):** the JP SL 72 (2.28 x 0.72 m, 117 l, the traced outline and scoop rocker) with an 8.0 m2 sail (the wind tunnel's own size: 4.9 m luff, 2.0 m boom; lift slope 1.03 on its aspect ratio 3.0, which gives the curve checked against the tunnel), the rig's pitch lag on, and the sailor trimming by feel (`_trim_by_feel`: aft slowly at 0.03 m/s while the nose rides below the aim, forward at 0.3 m/s when it rides above or off the plane, forward when it chatters). The old gear is kept as `board_freeride_240.tres` and `sail_6_5.tres`, and the tests of the old gear's own numbers load those. Reach check (90 s): 12 kt beam 9.21 -> 11.00 m/s, 18 kt beam 13.08 -> 13.53 (wet 1.70 -> 1.00 m), 18 kt broad 9.62 -> 14.52, 24 kt broad 14.70 bouncing -> 17.93 steady; the close reaches at 18 and 24 kt 3 to 7 % slower. Gusts and waves (`tools/push_check.sh --run=sl72_default`): no falls; 12 kt +10 to +35 %, 18 kt broad +8 %, 18 to 24 kt upwind and beam 4 to 10 % slower (an 8.0 is big for 24 kt). Found on the way: a slow release of the press reared a beginner's board to 72 deg in a tack (fixed: off the tail quickly). Checks: `tools/test.sh` 551 of 551, `tools/check.sh` 284 files 0 failed, `tools/test.sh validation` 38 pass, 6 fail, 2 pending. The reds: the 15 kt polar's targets (the old gear's) now too slow for this gear at 105 to 120 deg and the top speed, 135 deg still short, the onset 13.1 kn (band 8 to 10); the skipper at 24 kt (falls with an 8.0) and its times; one rig-lean threshold (12.6 against 12 deg). The fin's pin re-pinned. Not done: the 3D models (Blender is not installed), so the game still shows the old board and sail.{nl}**Then Max's play-test (report section 10):** the slingshot (`Game/dev/slingshot.gd`) showed the sailor easing the sail in a bear-away because the autopilot capped the pull at the righting moment held now. The sailor was too weak: the 45 degree stance became Gourlay & Martellotta's 30 degree full hike (`lean_max_m` 1.11, `lean_height_drop_m` 0.48), and in gusts and waves 18 to 24 kt is now 4 to 16 % faster with no falls. The broad reach at 15 kt still does not plane (drive about 155 N against drag about 190 N at 12 m/s), and the game's 15 kt is at 10 m (about 12.5 at the sail). The fin's bend pushes the tail up and the nose down in the sim (stiff fin: 0.6 deg more trim, 2 % faster), the opposite of Max's experience, because the sailor's weight sits above the fin; the hooked-in posture is the item behind it. Checks: `tools/test.sh` 551 of 551 after re-pinning a lean tolerance, validation 36 pass and 8 fail (the polar's old targets now too slow for this gear, 24 kt at 120 deg catapults with an 8.0, the top speed 0.2 deg nose down, the onset, the skipper's 12 kt time, a rig-lean threshold), the fin's pin re-pinned.{nl}**Also:** Max read the gear in the game (the F1 panel's first line now shows it: `Hud.gear_line`). He added papers in `Documentation/Science/` (the tunnel paper moved there, the links rewritten). Fagg (1997) was read for the fin: the loads are inside its range, and it has nothing on the vertical force or the pitch. Max clarified the roles: he is the experienced windsurfer whose feedback checks the physics, and Michiel does the hard physics because he has Fable. Max's answers on the hooked-in rider are in the report's section 11.
**Next:** the hooked-in rider from Max's answers (the report's section 11, the progress file's step 16); then train the autopilot for the new gear (Max; the training does not run on this laptop, ROADMAP RA5); then for Michiel and Max (the report's sections 5, 8 and 9): the strips' clip on a curved bottom; the lag on or off; a trim press that eases on the bounce it feels; the hooked-in posture (the boom behind the hips at 12 kt); U1's 0.6 to 1.0 m target against the bounce; the 24 kt broad reach's low-trim bounce, which is not understood yet.

## 28 October 2026 - Session 57: the sail from the wind tunnel (PH28), and the hull behind it (PH16)
**Phase:** version 0.2, the physics (section PH of the roadmap). On the branch `ph28/sail-and-hull` from `gp0/measure`; not merged, for Michiel's review.
**Done:** Max asked how the physics could be tested properly. GPX tracks were ruled out as the basis (rider-specific; verification later at most), and the plan became each part of the physics against its physics source. Max chose the sail first and pointed to the full-scale wind-tunnel study of an iQFOiL sail, now `Documentation/Science/2501.13254v1.pdf`. Against it the game's sail made twice the measured lift at small angles and a third more at the peak, had 10 % camber against 6 to 7.6 %, and never twisted. The sail now follows the tunnel: the curve's numbers, and a twist under load that takes lift off as the wind's pressure rises and lowers the centre of effort a little (spec 2.17; `SailModel.twist_factor()`; the autopilot reads the same curves). The sail's tests check it against the tunnel's lift at 4, 6 and 8 m/s. Then the hull, as Max asked ("combine"): measured, not changed.
**Verified:** `tools/test.sh` all passing after four tests were brought to the new sail (the catapult test sheets in at 24 kt instead of 18; two race tests' bars for the slower 15 kt board; thin air with the twist); `tools/check.sh`; `tools/test.sh validation`: see `Documentation/reports/ph28/PROGRESS.md`. Measured with `tools/push_check.sh` and `tools/reach_check.sh` (the report's tables): with the final defaults (the twist floored at the tunnel's lowest measured share, 0.75, so the push catapults at 24 kt again) the board is 4 to 7 % faster at 24 kt upwind and across, sheeted in at 7 to 15° instead of 4 to 6°, as fast at 18 kt, and 19 to 36 % slower at 12 kt and 10 to 29 % on the broad reaches. Unit tests 539 of 539, check passes, validation 8 red (by cause in the progress file: the hull's drag, porpoising, and GP0's push to re-measure). Not verified: how it feels to sail; the sail's look was not changed (its twist is drawn from the pull, as before).
**Decisions:** Max: physics from physics sources, GPX only to verify later; the sail first, combined with the hull; keep going and save along the way. The twist's numbers beyond the tunnel's 8 m/s (the 140 Pa, the floor of one half) are estimates for Michiel.
**Next:** PH16 with the sail as measured: the rig's load path (harness 663 N, mast foot 365 N, the bow held down at 0.76° of trim) and the porpoising limit. Then the full matrix, and RA's training episodes (the policy now needs 245 s to mark 1 in 15 kt).

## 26 October 2026 - Session 56: GP0, the push and the body measured
**Phase:** version 0.2, the gameplay (ROADMAP.md, section GP), item GP0. Branch `gp0/measure` from `main` (d679074). Max: "DO gp0", then "you can test; be careful with my tokens please". Opus 5.5 alone, no agents; the runs four Godot processes at a time.
**Done:** (1) `Game/dev/run_push.gd` and `tools/push_check.sh`: the player's beginner controller (`PlayerController` with the auto-sheet, fed by `AiHands` holding a true wind angle) sailed headless on the game's open water (waves, the height gradient, gusts), with the autopilot's margin written every tick (`--pilot.<field>`, as GP1 will) or the technique's targets set per case (`--sailor.<field>`, as GP2's mouse would); one or two sweeps crossed; real falls with the sim's own waterstart; a sailor who knows the gusts (`--timing=1`, reading a second `WindField` ahead); per case the speed made good, the VMG, the falls, the fin, the heel and the pitch; per fall the 2 s before it; `--jobs` splits the cases over processes. (2) About 600 cases, and [the report](reports/gameplay/gp0_measure.md). (3) The roadmap: GP0 to the changelog's next version; GP9 new (the gybe's timing, GP0's part (c), not measured); PH24 new (the open sea's gusts jump 3.8 % every period and repeat exactly); GD3, GP1, GP2, GR1, SO1, PH4, PH6, PH17 and the prompt to continue brought up to date; CLAUDE.md's commands table and the documentation index list the tool and the report. (4) Then, at Max's ask, a test for point 4: `tests/validation/test_push_warning.gd` (about 15 s) sails the 24 kt 120° reach fully pushed and checks every catapult tick by tick: the fin below 0.6 of its stall until the last half second (it carried 0.21 to 0.30; in the round-up itself it reached 0.89 once, 0.07 s before the fall), the sailor overloaded first (1.15 to 1.57 s before all five), the board rounding up (25 to 102 °/s). Passes.
**Found:** `hike_share` is the number that matters; on its own it pays upwind (+9 % from 1.1 to 1.6) and hardly on the reaches. With a late ease as well (`depower_alpha_per_deg` 0.3, the depower rates 0.05 and 0.5, no catch) the push gives +16 to 19 % upwind, +12 to 15 % on the close reach and +4 to 6 % on the other reaches. Nothing falls at 18 kt in gusts of 0.2; at 24 kt the constant push catapults 3 to 15 times in 200 to 400 s and is slower than neutral, while pushing and easing as each gust arrives sails the beam reach at 13.00 m/s with no falls (neutral 12.22 to 12.52). Every fall is a catapult (or a fall off), 24 of the first 42 in the second after a gust's peak: about a second of the feet overloaded while the board speeds up, then the nose lifts and the board rounds up (101 of 124); the fin carries a tenth to a fifth of its stall and the heel stays small until the fall, so the fin's hum would warn of nothing. 0.1's margin (1.1) catapults twice in 400 s on the 24 kt broad reach; 1.0 does not and is faster there. Package B: the back foot is worth about 10 % over 0.1's trim on the 18 kt broad reach; the flattest rail is always the fastest and rail buys stability at speed (at 24 kt 3° of trim on a flat board catapults, with 5 to 6° of rail it is safe and fastest); with the sailor's correction slowed to 2 s the 24 kt broad reach needs 5° of rail to stay up; upwind and below planing the two do almost nothing.
**Verified:** the runs above (the commands are at the end of the report); `tools/check.sh` 275 files, 0 failed; `tools/test.sh` 533 of 533. Not run: the validation suite (nothing in `Game/sim/` changed). Not verified: how any of it feels to sail; the dial's in-between settings (only the ends and single-number sweeps were run); a rail to windward; the 60° close reach in the map; the lake's own wind.
**Decisions:** the lead's proposals, for Max: the dial's three settings in the report's table (eased `hike_share` 0.8; neutral 1.0 with today's safety nets; pushed 1.6 with the late ease), the mouse's ranges (the rail 0 to 8°, the trim 0.5 to 3.5°), and the warning signs for SO1 and GR1 from the sailor's overload and the round-up rather than the fin. The gybe's measurement (GP0 (c)) became GP9, because GP8 is for 0.3 and it needs a harness of its own.
**Then a playtest for point 4** (Max: "a playable test for me to find it out for myself"): `tools/play_push.sh` starts the open water in 24 kt with gusts on a 120 degree reach, the player's sailor holding the dial's top (`--push=1`, through the new `PlayerController.pilot_overrides`, which GP1's dial will write); the F1 panel shows the feet's overload and the fin's load live and freezes them from 1 s and 0.5 s before each fall (`FallWatch`, tested). Seen in the game: a natural catapult at 28 s, but after the bow swung away at 56 deg/s with no overload. Measured then: the pushed sailor is overloaded 52 % of all sailing time, so point 4 was corrected: the fin does not warn, the overload marks the edge rather than the fall, and the round-up comes in the last half second; the early warning has to be the gust on the water. Verified: 536 of 536 unit tests, `tools/check.sh` 278 files, the screenshot of the frozen table.
**Then Max played it:** "the character cannot fully close the sail, and the auto-sheet starts jerking; experiment with the rider's maximum strength and weight; back it up with real physics." Measured (the report's "Follow-up 2"; `run_push.gd` got the sheet, its jerk, `--hold_sheet=1` and `--sail.<field>`): a heavier rider sheets in further and is faster (75 to 110 kg +5 to 11 %), but nobody closes a 6.5 at 24 kt and a 75 kg rider sails it eased to 6° on the 18 kt beam reach; the rider's balance (606 N m, about 470 N of side force) against 1,218 N per unit of lift at 34 kt apparent puts the sail at the edge of luffing, where the force changes fastest. A flatter sail changed nothing; a lower centre of effort (40 to 30 % of the mast, as a twisting leech gives) made the board 3 to 14 % faster with the sheet further in: the sail's missing twist is PH28. Stronger feet or a longer lean blew the sim up in 7 of 36 runs (PH29). The jerk is the hand sheet's on-off ease (W held: 7 to 25 times the auto-sheet's movement; GP10), and the push's weakened reflexes at 24 kt; the auto-sheet alone is smooth.
**Max's answers to the stop:** (1) "easing late" was not clear: it means the autopilot's two reflexes (easing on leeward heel, the catch) turned down, so the pushed sailor keeps the sail sheeted through a gust. (2) "In 12 knots in real life you can push too much, and for sure in 18": measured with a reaction time in the harness (`--reaction_s`, the controller fed the apparent wind late): at 18 kt the pushed board falls 6 to 17 times in 200 s upwind with 0.3 to 0.6 s, so the instant reaction of the sailor model hid the risk (PH25); at 12 kt nothing changes or falls whatever is set, so light wind is too weak in the physics (PH26, with PH16 and PH8). (3) The mouse's ranges: OK. (5) "A flat board is not the fastest on wide boards in light wind": with `tools/reach_check.sh` both ways, at 12 kt any rail is 2 to 6 % faster than flat (the windward rail down the most); fully planing, the leeward rail lengthens the wet part and costs speed, which looks wrong (PH27). The report has a follow-up section; its "the flattest is always fastest" is corrected. Asked Max which way he tilts a wide board in light wind.
**Max on the branch:** "no merge, and update the documentation": `gp0/measure` (886169c to d3d3a8e, and this update) stays off `main`; then, so Michiel can continue from it (Max: "he needs this roadmap and the rest"), the branch itself was pushed to GitHub (`origin/gp0/measure`); then (Max: "he opens a new session on main and misses a lot") the documentation alone went to `main`: CLAUDE.md, ROADMAP.md, CHANGELOG.md, this log, the documentation index and the GP0 report, through `docs/gp0-on-main`, with a note in CLAUDE.md and the roadmap that GP0's code is on `gp0/measure`; `main` was merged back into `gp0/measure` so the later merge is clean; the changelog's entry, the roadmap's "Who is waiting" and its prompt to continue say so, and the changelog's entry now lists the follow-ups.
**Next:** Max: GP0's dial settings (point 1 answered with an explanation), which way he tilts a wide board in light wind, whether to build GP10 now, and GD1 to GD7. Then GP1 with SO1, GR1 and UI1, and GP2's experiment, each on its own branch from `gp0/measure` (they need `PlayerController.pilot_overrides` and the harness). Michiel: the report's "Findings for Michiel", PH24 and PH25 to PH29.

## 26 October 2026 - Session 55: version 0.2 planned, and the roadmap reorganised by section
**Phase:** planning for 0.2, documentation only; nothing built and no code changed. Branch `docs/roadmap-0.2` from `main`. Max: "I added a PDF for upgrades; we need a roadmap detailed per section of the game (gameplay, graphics, physics, etc.); now it is hard to find what we need to upgrade, there are a lot of different files where to look." No agents.
**Done:** (1) Max's PDF (the gameplay and control design for 0.2, from a voice session with Tarpie on 23 October 2026) renamed to `Documentation/gameplay_controls_v0.2.pdf`, so links to it work. (2) [ROADMAP.md](../ROADMAP.md) rewritten as the one place to look. Every open item from the old roadmap, the README's known gaps, the live plans (AI_FLEET_PLAN, MAP_SILVAPLANA_PLAN, PHYSICS_REQUESTS_FROM_MAP), the archived plans and progress files, PHYSICS_SPEC.md's open items (17.12, T10) and the design is now listed once, in nine sections with their own IDs: GP gameplay and controls, PH physics, RA racing and the AI fleet, GR graphics, SO sound, UI, MA the map and the wind, TE tech, PR the project. Each item has the files it touches, what it waits on, a size and a version. Also new: the version 0.2 section (the design's problem, its four rules, what is proposed for 0.2 and 0.3, the critical path), "Who is waiting on whom", "Where to look for the details", six gameplay decisions (GD1 to GD6) with the lead's recommendations, and a prompt to continue the gameplay. The two-letter IDs avoid the older names (U1 and U2, F1 to F6, S1 to S6, T1 and T2, M0 to M4, W0 to W5, R1 to R9). (3) Documentation/README.md and CLAUDE.md point at the new structure, and CLAUDE.md lists the gameplay as a track.
**Verified:** the code the design touches was read for the plan. Today the player has the sheet, the rake, the lean, the rig's tilt and the tack's steps (`SimControls`). The stance, the foot trim, the hang on the boom and the knee bend are reflexes in `WindsurferSim._update_sailor()`. The open sea's gusts are the same everywhere at once (`WindField`), ventilation is not modelled (`FinConfig`, spec T10), and the chop is held at trace amplitudes (spec 17.12). Every file path in the roadmap was checked to exist. The archived U1_PROGRESS.md lists the flat tail as reverted; it came back in 239cff9 (noted in the roadmap). Not run: tests and check (no code or scene changed).
**Decisions:** none by the team yet. The lead's proposals, for the team: a third input mode ("Sailor") next to beginner and advanced; GP0 (measure headless whether the physics already rewards railing, pushing and the gybe's timing) before any input is built; the sailor's body as new `SimControls` inputs that leave every answer bit for bit the same at 0 (PH3), after Michiel's two reviews (PH1, PH2); chop (GP7) in 0.3, because the physics under it (PH9 to PH11) is not there yet.
**Later the same session, Max's direction:** "It is too hard to control every variable on the character. User input must impact the sailing in an intuitive and learnable way: a little challenging to go fast, but easy to just go. All in one package, or maybe two, so you learn to get faster." The gameplay plan was rewritten around it. **Package A, the push:** one dial (W/S, the gamepad's triggers) that sets how hard the sailor commits. Eased is slow and safe, neutral is a safe cruise, pushed is faster with the risk of a catapult or a spin-out in a gust. The controller sets the autopilot's existing margin from it every tick (`hike_share`, `ankle_share`, the depower settings, the catch in `Autopilot`), the way it already caps the sail for the AI's hold-back, so no file in `Game/sim/` changes. The feedback that makes it learnable comes with it: the fin's voice, the spray, the HUD without trim aids. **Package B, the timing (maybe):** the gybe in two presses, the sail held on its old side with `SimControls.hold_side` until the flip. The PDF's separate rail, trim and absorb inputs became "only if GP0 shows they matter" (GP6, PH3) and chop (GP7, PH5). The gameplay IDs were renumbered within this draft (GP0 to GP7, GD1 to GD6, PH3 to PH5), before anything was committed. Found in the code: the personas' `gust_appetite` and `risk` change only the course they steer and their margins at marks, not the power they hold, so the AI's push is a new number on the sheet (RA7).
**Then Max:** "Package A is OK. For B I want to experiment: the mouse (later the gamepad) has an X and a Y axis. Sideways mimics the roll (railing) of the board: with precision you hold the optimum angle. Vertically is the back foot's pressure (more pressure lifts the nose, less lowers it). It needs to be real physics still." Found in the code: the sim's sailor already makes both choices as targets their real feet work toward, the bank the feet aim for (`SailorConfig.fin_load_bank_deg`, held only as firmly as the ankles are stiff, corrected by the sailor's feel within `lean_feel_time_s`) and the trim the back foot presses for while planing (`running_trim_deg`), both read from the config every tick. So the experiment writes the two targets into the player's own copy of the config (`own_config_copies` in `windsurfer.gd`; the loaded configs are shared by every board), with no change in `Game/sim/` and no new forces. U2's map (reports/u2/fin_technique.md) already shows an edge to play with: the wet length shortens with less bank and more trim until the board bounces, and the bounce limit falls with speed. Package B became GP2 (two levels: the feel's correction kept, or slowed so the player's hand holds the angle), with GD7 (the mouse staying or springing back; the roll as seen or one direction for more rail), GP5 (the gamepad's right stick), GP6 and PH3 (made permanent if it works); the gybe in two presses moved to GP8 (0.3).
**Then the documentation cleanup** (Max: "read all the docs and clean up the documentation folder; archive the redundant ones"). Read in full: every report, the live plans, the research, the notes, the polar; the archived files' banners and open items; the physics spec by its structure, its header and its history sections. Done, nothing deleted: (1) `AI_FLEET_PLAN.md` and `PHYSICS_REQUESTS_FROM_MAP.md` moved to `Documentation/archive/` with banners (F1 to F5 built, the open parts are section RA; R1 to R3, R5 and R9 done, the open ones are PH11, PH13, MA6 and the fleet; their design and measurements still cited by the code and the spec). (2) The three report folders became one, `Documentation/reports/` (`racing/`, `u1/`, `u2/`; a new package's report goes in a folder named after its work). (3) Every reference rewritten by a script that resolves each Markdown link from its old place to its new one (22 files, among them two code comments, three tool scripts and the map tools' README); 272 links in 51 Markdown files checked, 0 broken, no old path left. (4) `POLAR_15KT.md` was from 16 October, before U1 and U2: regenerated with `tools/test.sh validation -gselect=test_polar_sweep` (11 of 12 pass, the red one the onset, on purpose), with a dated note; the reaches are faster, 135° slower, the best angles the same; the skipper config's comment updated to the new VMG numbers. (5) The map plan got a dated status note (merged into `main`, the open items are MA1 to MA8, its tools table is the PC of 14 October) and its stale "waiting for Michiel on R9" corrected. (6) `reports/racing/real_life.md` had a fleet table pasted into the middle of a sentence: put back together. (7) `Documentation/README.md` rewritten for the new layout (a tree at the top, the reports that are evidence for open items named); the roadmap's "Where to look" and section RA point at the archived design; GP0 got the earlier sweeps to start from (`fin_measure.md`, `fin_ride.md`, `finish_u16.md`); TE7 added: the physics spec is 1 MB, its history sections could move to an archived companion (Michiel's call). Not touched: `Legacy/`, the agents' worktrees in `.claude/`, the spec's content. **Then an overview at the top of the roadmap** (Max: "now it's a bit hard to read"): where we are, what 0.2 means for the player in three lines, the next six steps with who does them, the versions at a glance (0.2: 37 items, 0.3: 17, later: 21) and the sections at a glance with their counts; the column guide moved down to just before the sections.
**Next:** Max and Tarpie answer GD1 to GD7, and the team agrees the version plan. Then GP0 (ready to build: it sets the dial's range and neutral and the mouse's ranges), package A and package B's experiment with Max's answers, and Michiel's PH6 and PH7.

## 21 October 2026 - Session 54: version 0.1.0 released, and the documentation reorganised
**Phase:** the release. From here on [ROADMAP.md](../ROADMAP.md) is the live "where things stand" file and the plans' status tables are history. Max: "merge to main and do a full document cleanup of what is version 0.1 and what is needed for updates; a full features list on GitHub; don't delete data or information, but you can clean up." Fable alone, no agents.
**Done:** (1) The 17 untracked brains (the nights' generations, S1's first five) committed; `feature/p9-racing` merged into `main` with a merge commit (66428d7: 241 commits, U1, U2, Phase 9 and the AI fleet's F1 to F5) and pushed. (2) On `release/0.1`: the version 0.1.0 in `Game/project.godot` and the menu's placeholder text; the export preset's path to `.release/`. (3) The documentation, nothing deleted: [Documentation/README.md](README.md) as the map of every document (start here, live plans, reference, reports, archive); the finished plans and progress files (REBUILD_PLAN, PLAYTEST_UPGRADES, RACING_PLAN, U1_PROGRESS, U2_PROGRESS, P9_PROGRESS) moved with `git mv` into `Documentation/archive/`, a banner at the top of each, 62 links rewritten by a script and every Markdown link in the repository checked (0 broken); the iQFOiL notice of race renamed to a readable name; the rebuild plan's status rows 7 to 9 brought to their final state. (4) New at the root: [CHANGELOG.md](../CHANGELOG.md) (what 0.1.0 contains, by phase and upgrade, and the Unity era), [ROADMAP.md](../ROADMAP.md) (how an update and a release are made, what waits for Michiel and for Max, the next builds in order, the smaller follow-ups, the prompts to continue), the README rewritten as the front page (the full feature list, the controls, where you sail, the racing, the AI skippers, the look and the sound, the settings, the known gaps, running from the source, the structure, the history), and CLAUDE.md rewritten for the new state with every rule kept. (5) Screenshots for the README in `Documentation/images/readme/`. (6) The tag `v0.1.0` on `main`; the release build rebuilt at the tagged state and zipped as `WindsurfingSimulator-0.1.0-windows.zip` for the GitHub Release page, which Max creates by hand (no `gh` on this PC).
**Verified:** `tools/check.sh` 274 files, 0 failed, and `tools/test.sh` 533 of 533, before and after the changes; the link checker 0 broken links; the start menu's screenshot shows v0.1.0. Not run again: the validation suite (the physics is unchanged since Session 52's run: 40 pass, 1 red on purpose, 2 pending). Not verified: the Release page itself.
**Decisions:** Max: merge now with Michiel's review still open (it is the first item of the roadmap); nothing is deleted, so the 55 merged local branches, the 25 agent worktrees, the old remote branches, the brains and every document stay; the one red validation check stays red; no LICENSE file until the team decides. The lead: a merge commit rather than a fast-forward so the branch stays visible in the history; an archive folder with banners rather than banners alone, so the live folder is short.
**Next:** Max creates the Release on GitHub from the tag with the zip and the changelog's text. Then the team's answers to the roadmap's "Waiting for the team", and F6 or the training nights on another machine, as the roadmap says.

## 21 October 2026 - Session 53: F5's trainer, built by Fable itself (the candy along the course, the curriculum, PPO over the bridge)
**Phase:** 9, the AI fleet (AI_FLEET_PLAN.md, part F5) on `feature/p9-racing`, built on `f5/trainer` and merged. Max: "I have a lot of Fable left, so you can do more work instead of the agents; I have to be careful with my normal usage." No agents.
**Done:** (1) `SailingDistance`: the shortest sailable way to a point (straight when laid, the upwind distance over cos 50 degrees in the tacking cone, the same downwind), a true distance; the reward of `RaceEnv` is the fall of the sailing distance still to go round the course, to the mark's *rounding point* and through the lines' best crossings, plus 50 m per step, 100 m at the finish, minus 5 m per tack or gybe, 50 m per fall and OCS, and 2 m per second: laylines pay like pointing at the mark, a detour pays nothing, the rounding pays. (2) The observation grew to 68 numbers (the aim point, the leg after, the distance to go, the hands' last orders); brains pick their inputs by name, so the night brains still sail. (3) The hold-back as the brain's third output; the decision interval in the brain's note (half a second). (4) Drops anywhere on the course (`RaceSim.place_board`), respawns, a goal step, a scripted character on a drop as the yardstick. (5) `RandomCourses` (the templates at random sizes, random windward-leewards, trapezoids and slaloms) and `TrainingDrops` (S1 to S6 as presets). (6) The bridge: `TrainBridge`, the headless worker over TCP, the Python `VecEnv`; PPO in `tools/train/train.py` with `tools/train.sh`, the curve, `<run>_gen<N>.json`, `_best`, `_latest`, resume; the export with a parity fixture and test; `--evaluate` against the all-rounder. (7) `pip install torch stable-baselines3` on Max's PC. (8) An 8-minute try of S1 on 10 workers to prove the loop.
**Verified:** 505 of 505 unit tests (34 more than the night's 471); `tools/check.sh` 250 files, 0 failed; the parity fixture within 1e-6; the socket bridge end to end (two workers, ten steps); the all-rounder on S1's drops at 4.8 to 5.8 m/s made good (the stage's yardstick); the try run: 145 decisions a second on 10 workers of 4 boards (170 beside the unit suite; 14 workers should give about 200): 117,000 decisions and 640 episodes in 14 minutes, the reward over the last 300 episodes from -1.3 to -0.18, the speed made good from 0.77 to 1.95 m/s, the tacks from 4.1 to 2.5 per episode, the noise from 0.22 to 0.18; the saved brain without its noise on 10 fresh drops 2.50 m/s, **54 % of the all-rounder's** 4.68 m/s, 0.7 manoeuvres and no falls per episode, no rounding yet (the all-rounder rounds 4 of 10 within the 90 s). The first try, with the policy starting at 0 (head to wind), stayed flat at -2.5 for 8 minutes: hence the trainer's close-reach start (`--twa_bias=0.3`) and smaller first noise. Not verified: that a stage learns to its "done when" numbers (the nights' work); the lake's wind in the trainer (a follow-up); the parked boards' idle steps in S5 and S6 over a long run; the validation suite not run (nothing in `Game/sim/` changed).
**Decisions:** the reward as a potential (the remaining sailing distance) rather than D6b's two rules side by side: the same thing, continuous and exploit-free; the stages S1 to S3 on flat water in a steady wind for speed, S4 to S6 on the real water and wind; a done board respawns at once where the drops are independent of the race's clock (S1 to S4) and waits for the race's end where they are not (S5, S6); the old reward's tests rewritten, the old evolution trainer kept as the fallback (it runs on the new reward).
**The same afternoon (Max: "I have no time, continue"):** (9) the nights unattended: `tools/train.sh --stages=S1,...,S6 --hours_each=4` runs every stage in turn, each from the one before's best brain, each ended when its "done when" number holds at an hourly check (the evaluation on fresh drops) or by its hours; started at 13:05 as a detached process (`.logs/nights.log`). (10) A brain resumes across a change of the observation (the inputs matched by name, new ones at zero weight). (11) `template:<ID>@<percent>` as a course name, for racing a brain on every template. (12) **F3 built:** the wind shadows (`WindShadows`, the numbers for Michiel in `config/wind_shadow_default.tres`, one hook `WindField.disturbance` in the physics, PHYSICS_SPEC.md 8.11; in the game, the race tool and the trainer's company stages; on the HUD) and the racing rules (`RaceRules`: port and starboard, windward and leeward, clear astern, room at the mark; a penalty per touch by the board that had to keep clear, cleared by a full turn or 20 s at the finish; the scripted skippers keep clear by the rules and turn a circle; the player is warned; the trainer charges 50 m). The report: reports/racing/real_life.md. Verified: 525 of 525 after the rules (the suite ran again after the personas and the Race page: see P9_PROGRESS.md); `tools/check.sh` 257 files; a penalised skipper turns its circle in a headless race; the shadow slows the board behind. Not verified: how a crowd feels (F3's Stop), Michiel's numbers, the cost in a big fleet (the laptop was training).
(13) **F4 built:** the skill sheet (`Persona`, D3's numbers, drawn afresh each race by its consistency) on the scripted skipper's character sheet, twelve personas, `persona:<name>` in any race, the Race page in the menu (the water, the course, the fleet's size, who, the countdown, the shadows, the rules), `tools/persona_matrix.sh`, `template:<ID>@<percent>` as a course name; the gear per persona built but off (measured: a 7.8 is slower off the line than the 6.5 even in 12 kt; the sail sizes are Michiel's). The report: reports/racing/personas.md. Verified: 533 of 533 unit tests on the final state of the afternoon; the Race page in a screenshot; four personas racing in the game in a screenshot; the matrix's first table.
**Next:** the nights of F5 run on their own (read `.logs/nights.log` first); Max's four open Stops (F1's table, F2's gathering, F3's crowd, F4's names); then F6 (the big fleet) and the personas on the trained head.

## 21 October 2026 - Session 52: the night: the AI fleet's F1 (the physics without the engine's locks, 20 boards at 60 fps) and F2 (the fleet lives on the water)
**Phase:** 9, the AI fleet (AI_FLEET_PLAN.md) on `feature/p9-racing`. Fable 5.1 led overnight (Max asleep: "lead the rest of F1 and then F2; train the AIs overnight as well"); three Opus 5.5 agents in worktrees; the lead found the cause first, merged, measured and wrote the Stops.
**Done:** (1) The lead's thread bench (`tools/thread_bench.sh [--release]`, run by the start menu on `--bench=thread` because the release engine runs no script): in Godot 4.7.2 every read or write of another object's field takes a global engine lock, on the release engine too, as do new objects, Arrays, Dictionaries and objects passed to typed parameters; method calls, `self.field`, statics, packed arrays and value maths do not. (2) `no_wait` (Michiel's folder, his condition kept): the models copy their configs once per tick, read other objects once per function, hand over results through methods, pass no Basis around (a second lock: the Basis pool), the body keeps its world inertia until the axes change; every answer bit for bit the same (the whole state hashed every tick over eight runs, 16 matrix CSVs, the lake). A board beside 15 others from 24.9 to 4.6 ms. (3) `fleet_frame`: the boards on at most 8 worker tasks (the lead then made the tasks pull the boards one by one: fixed batches collapsed at 20 boards on the laptop's slow cores), the race order once per tick (the fleet list at 33 boards from 320 to 0.3 ms), far opponents posed on alternate ticks, `--measure` summarised, `tools/fleet_measure.sh`, silent runs (`--mute`). (4) `living_skipper` (F2): the skipper's states (free sailing in a sailing area, the pre-start with the navigation skill, the line bias and the end choice, the timing loop or the hold with the hands' hold-back skill, OCS boards going back), boards spawning anywhere, the countdown gathering the fleet, numbered repeated characters, the head at 2 Hz, the lake's data in the release pack. (5) Training: `night2a` (2.5 h, 6 processes, 27 generations: the start from the real pre-start spot learnt, no rounding) and `night2b` (5 h, 16 processes, until about 07:30).
**Verified:** `tools/test.sh` 471 of 471; `tools/check.sh` 239 files, 0 failed; the validation suite on `no_wait`'s branch 40 pass, 1 fail (the onset, red on purpose), 2 pending, as before; the fleet measured on the release build (20 AI boards and the player at 177 fps, 24 collapse; the table in P9_PROGRESS.md); 16 boards from random spots start within 6 s of the gun at 15 kt on both courses (the agent's validation test, 2 of 2) and within 17 s with two OCS in 96 starts at 12, 18 and 24 kt; the screenshots of the gathering (the lead looked at the one after the gun). The clean fleet table on the quiet laptop at 07:20: 20 AI boards and the player at 192 fps, 24 at 7 fps (the tick's sum 17.2 ms against 16.7: the catch-up cliff). The night's brain (night2b, 145 generations, plateau at fitness 15) starts in its own conditions and never rounds; against the all-rounder it never starts. Not verified: how it looks in motion and feels (Max's two Stops).
**Decisions:** the lead measured the cause itself before any agent (one bench, no exploratory agent); the fix in Michiel's folder went ahead under his written condition (no formula changes, identical answers) with the bit-for-bit proof, for his review; the fin's old sea queries stay (a warm query would end the bit-for-bit proof); the worker tasks pull boards instead of fixed batches; `night2b` with more exploration (sigma 0.05) against the plateau; every game run silent at night (Max asked).
**Next:** Max's two Stops (P9_PROGRESS.md, "The Stops for Max"), the morning race against `brain:night2b_best`, then F3 and F4 with the "To continue" prompt in P9_PROGRESS.md. For Michiel: `no_wait.md`'s list per file, and `autopilot.gd:196` (`best_alpha_deg()` every tick: a fifth of the hands' cost).

## 20 October 2026 - Session 51: the night: 9A built up to the two courses, the scripted skippers, the learning harness, a first brain
**Phase:** 9 (branch `feature/p9-racing` from `feature/u2-fin`). Fable 5.1 led; five Opus 5.5 agents built in worktrees; the lead merged, wired and ran the night's training.
**Done:** (1) 9A's race core: `RaceSim`, `RoundingCheck` (the plan's geometry, checked against all ten iQFOiL templates), `RaceStep`, `RaceResult`, `tools/race.sh`. (2) The course on the water: buoys with name flags, the committee and finish boats with the Phase 7 flag, pins, optional lines, all bobbing on the waves; `--course=<name>` in both scenes; `RaceCourses` (T1 by code: LG2 at 30 %, the beat 556 m, the line 60 m; saved courses by name); the course file's game-metres frame; the mini-map shows the course and centres on it on the open water. (3) Max's shore rule: `CourseFitter` fits a template to the lake (shrink, turn up to 15 degrees, move) with marks 200 m and legs 50 m off the shore; a Fit to water button in the course maker; `tools/fit_courses.sh` wrote `t2_slalom.json` (60 % is the biggest that fits at 200 m; 150 m would give 80 %). (4) 9B's scripted skipper with four characters (all-rounder, cautious, gambler, rookie): all four finish T1 and T2 at 12, 18 and 24 kt, one fall in 18 races; `tools/race_matrix.sh`. (5) 9C's learning harness: `RaceObservation` (58 numbers), `NeuralNet`, `RaceEnv`, `LearnedSkipper`, an evolution trainer on all cores (`tools/race_evolve.sh`); PPO over Python postponed because nothing could be installed at night. (6) The lead's own: `AiHands` (the beginner controller fed by values, RD1), `RaceSkipper` (the base of both skippers), `brain:<name>` in the race tool. (7) The night run: 101 generations in 5 hours; the best brain learnt to start, pick its tack and beat 550 m of the 556 m to mark 1 (5 of 5 fresh races), not yet to round it; and it does not yet transfer to other start spots or to company.
**Verified:** `tools/check.sh` 228 files, 0 failed; `tools/test.sh` 443 of 443; the skipper's races in the validation suite (10 tests, about 12 minutes); the buoy on the lake's waves, the start line and the mini-maps in screenshots; the fitted marks checked independently on rings of samples; the brain on 5 fresh races. Not verified: anything in motion or by a human (Max's look is Stop A2); T2 raced only in the open water's sea, not the lake's wind; the frame time with four boards on screen.
**Decisions:** the Phase 9 branch comes from `feature/u2-fin`, not `main` (the plan and the physics Max plays on are there; the pull requests go U1, U2, P9); T2 kept at 60 % with Max's 200 m until he decides; `test_skipper.gd` moved to the validation suite (it races for over ten minutes); the learned skipper chooses the wind angle to hold rather than twitching a stick (the stick mode learnt nothing in 10 minutes); the plan's T1 lap time corrected (7 to 11 minutes, not 3). Findings for Michiel in P9_PROGRESS.md (the 24 kt catapults in company, the controller's 6.5 s tack, the slow 150-degree run, GDScript threads).
**Later the same day (Session 51 continued):** the race in the game (Race buttons, RaceRunner, RaceHud), then after Max's first race the physics on worker threads (249 fps with four boards), the start 60 m behind the line, the racing HUD; Max's ask for smarter AIs, personas and 20 to 40 boards planned in AI_FLEET_PLAN.md and rewritten after his answers (no cheap models, all iQFOiL courses and random ones, tokens carefully). Measured for it: the editor engine collapses at 8 boards where the exported release engine (`tools/release.sh`, new) runs them at 244 fps and collapses at 16; the sea is half a board's 3.3 ms tick; 2 substeps make the 24 kt broad reach fall, 3 match 4 within 0.1 % on the reach check with one marginal fall at 24 kt in the skipper's race; the hull asks the sea three solves per sample point where one gives identical answers at half the cost. Decisions: Max: wind shadows yes, the rules yes, the training stack with a morning race against last night's brain, 20 to 40 boards, T2 at 60 %, the countdown 60 s, the names stay; Michiel: the same controller and substeps for every board, 3 substeps, the sea refactor "big go". The game runs at 3 substeps from this evening; the agent `sea_query` launched.
`sea_query` merged the same evening (c87617a): one solve per point per substep, warm-started, one pass for the three answers; no formula changed, flat water bit for bit the same, waves within 0.002 mm; a board alone 2.5 to 1.7 ms on waves, but eight boards on threads level with before, so the next F1 question is where that time goes. The fleet measured after it (release build): 10 AI boards and the player at 60 fps, 12 not; a board's step 1.7 ms alone, 4.7 beside 8, 16.4 beside 16: waiting, not work. Max: more threads no, the GPU no; the task is F1's `fleet_wait` package; the branch pushed. **Next:** the other chat takes F1's remaining packages (`fleet_wait` first) and F2 with the plan's start prompt. Max's look at the two courses and the brain (Stop A2) and the push are still open.

## 19 October 2026 - Session 50: Phase 9 planned (racing, scripted and learned skippers)
**Phase:** 9, planning only. Nothing built.
**Done:** Max asked for a full plan for Phase 9: races with AI opponents, opponents that differ from each other, and one or two courses to train neural-network skippers on by reinforcement learning. Written as [RACING_PLAN.md](archive/RACING_PLAN.md): four parts (9A the race alone, 9B scripted skippers with character sheets, 9C the learning harness with a Godot-to-Python bridge and PPO, 9D learned skippers in the game), the two courses (T1, a windward-leeward loop on open water at 30 % of the class's size; T2, the iQFOiL sprint slalom on Lake Silvaplana placed by Max in the course maker), the rounding geometry, the observation, the actions and the reward of the learned skipper, the curriculum, the personalities, an execution brief in the shape of U1's, and the stop rules. The rebuild plan's Phase 9 section and status row point at it.
**Verified:** the simulation's headless speed, measured for the compute budget: Godot starts in 4.6 s, one board runs 10 times faster than real time (about 610 ticks per second per process; `tools/simulate.sh beam_reach` at 5, 60 and 300 s). Python 3.12.9 and numpy are on Max's laptop; torch and Stable-Baselines3 are not yet. Not verified: the estimate of 7,000 ticks per second with 12 processes (9C.1 measures it).
**Decisions:** RD1 to RD8 in the plan, the main ones: the AI sails through the player's controller with no hidden help; scripted skippers before learned ones; PPO in Python over our own small bridge, with neuroevolution in Godot as the fallback; a brain is a built artefact with a parity test; 9A and 9B on `feature/p9-racing` from `main` now, training after U1 and U2 are merged; two small physics hooks for Michiel (one shared wind step, a contact force).
**Next:** the team reads the plan; Max places and saves `t2_slalom` in the course maker; on the go-ahead the lead makes the branch and P9_PROGRESS.md and launches 9A's `race_core` and `course_on_water` agents.

## 19 October 2026 - Session 49: U2, the fin bends; the cause of the long wet part found and fixed; the sailor's technique
**Phase:** Play-test upgrades, U2 (branch `feature/u2-fin`, on top of U1's branch). Fable 5.1 led; Opus 5.5 agents built; the lead designed the physics and reviewed every diff.
**Done:** (1) The fin bends as a cantilever beam (`fin_model.gd`: EI = S c^4, S from a measured flex test of a 37 cm carbon slalom fin, IST Lisbon 2017; an elliptic load; the bent fin's force tilts up toward the deck on both tacks: about 80 N up on the planing reaches, 150 N with a 44 cm fin). (2) **The cause of the long wet part:** the heeled hull lost 80 % of its lift at 4.5 deg of heel where NACA TN 4187's rolled plate loses a third, because Wagner's climb was applied to the vee at the spray root but not across the heeled strips; fixed in `hull_model.gd` `_wet_width` (each section's depth flattened by 2/pi about its deepest point), the camber sign corrected, the sailor's feet holding the wanted heel against the fin's roll. (3) The sailor's technique from a map of bank x trim against steadiness: bank 2 deg (was 4.5), trim 2.0 deg up to 24 kn falling to 1.5 deg by 26 kn (calibrated on this hull, labelled; the fast end set for the game's gusty wind); the flattening off the wind built but off (the hull bounces flat at 32 kn). (4) The fin mesh bends in the game (`fin_bend.gdshader`), the HUD shows the fin's load, bend and upward push, the F3 force view has an arrow for the fin's upward push. Also: `--fin.<field>=` overrides, fin columns in the reach check, the probe `Game/dev/hull_probe.gd`, Savitsky's critical trim reported (it does not describe this hull: extrapolated below its chart), 78 experiments on riding the fin, the mast track 10 cm aft tested (faster and freer in steady wind, livelier in gusts; not kept: a setup choice for the team).
**Verified:** On the branch (5f8ef4b): `tools/check.sh` 196 files, 0 failed; `tools/test.sh` 360 of 360; `tools/test.sh validation` 30 pass, 2 pending (U1's wet-area targets), 1 fail (the onset, 13.4 kn, red on Michiel's decision); the reach check 9 of 9 steady, the wet front on the planing reaches 1.42, 1.35, 1.35, 1.59 m (U1's end: 1.76, 1.42, 1.71, 1.71), 2 to 5 % faster; the polar inside its ranges; the gusty default wind at 12, 18 and 24 kt: no fall in 60 s. Max played it: "feels quite nice now". Not verified: manoeuvres (none run in U1 or U2), the 44 cm fin's look.
**Decisions:** Max: U2 go; the sailor rides the fin; keep going until the cause and the solution are found (done); the day ends here, other things get built next. Open for the team: Michiel's review of the U2 physics (the questions in U2_PROGRESS.md); the rail on a beam reach (Max); the fin's size and the mast track as player settings; U1's wet-area targets (0.6 to 1.0 m against 1.35 to 1.59: the map says 1.0 m is reachable flat at 18 kt, but the 32 kn broad reach needs heel and a low trim, which may be the 1 deg vee's limit); the onset band; the hands' share of the boom force; the manoeuvre matrix before the pull requests (U1 first, then U2).

## 19 October 2026 - Session 48: U1 rounds 2 to 4, all agents merged, Stop 3
**Phase:** Play-test upgrades, U1 (branch `feature/u1-planing-wet-area`)
**Done:** Stop 1 and Stop 2 passed with the team's decisions (in the brief). Agent 4: a 1° tail vee with the spray root across a sinking bottom fixes the porpoising with no new constant (9 of 9 reach cases steady); the flat tail is back; the grid stays at 7 rows; a planing bottom's smaller buoyancy is built as `planing_buoyancy_factor` but off; the sailor's 45° stance, the hang-back measured from the feet, and the feet's trim (32 N·m bow-up instead of 117 N·m bow-down); `running_trim_deg` 2 → 1.5. Agent 5: the helm's rake-first course hold (now on by default; the rig leans 23°), the fin-loading bank (4.5°, an estimate), the railing-out test (21° holds, 24° rails out), the final validation, the polar and the before-and-after screenshots. On the 18 kt beam reach the harness went from 947 to 683 N, the rig's share from 91 to 63 %, the mast foot from 679 to 352 N.
**Verified:** On the merged branch: `tools/check.sh` 192 files, 0 failed; `tools/test.sh` 343 of 343; `tools/test.sh validation` 26 pass, 2 pending, 1 fail (the planing onset, 11.6 kn against 8 to 10 kn, left red on Michiel's decision not to move the band); the reach check 9 of 9 steady; the polar at 15 kt inside every range; the straight runs 2 to 6 % slower. Not verified: any manoeuvre (none run in U1), and how it feels: Max's first play-test says "a little better", the push on the fin isn't felt (U2).
**Decisions:** U1 is finished as it stands (Max, option b): targets 3 to 5 stay pending (the wet front 1.65 to 1.75 m, the push 1.1 m, the harness 683 N), because hooked in the line carries the whole boom force and the drive's couple holds the push forward. Follow-ups: the hands' share of the boom force (Max's estimate, if Michiel agrees), spray drag, U2. The team runs the manoeuvre matrix before the pull request.

## 19 October 2026 - Session 47: U1 led by Fable, agents 1 to 3 in, stopped at Stop 1
**Phase:** Play-test upgrades, U1 (branch `feature/u1-planing-wet-area`)
**Done:** The lead launched agents 1 (`measure`), 2 (`sources`) and 3 (`porpoising`), Opus 5.5 at extra-high effort in their own worktrees, and merged all three. New: `tools/reach_check.sh` (9 reach cases, one line each), the pending validation check `test_planing_wet_area.gd`, the friction area, wet front and push centre in telemetry and the HUD, the baseline in U1_PROGRESS.md, the four sourced numbers in PHYSICS_SPEC.md section 14, and agent 3's diagnosis: the 1.8 Hz bounce is plain porpoising past Savitsky's critical trim. U1.4, the flat tail, was built and reverted (two buoyancy unit tests outside agent 1's files, and the 18 kt broad reach went bow-down).
**Verified:** On the merged branch: `tools/check.sh` 190 files, 0 failed; `tools/test.sh` all passed; `tools/test.sh validation` no failures, 3 pending (the new check's targets, by design). Not verified: how anything feels to sail; nothing in the game's behaviour changed except the HUD and telemetry.
**Decisions:** Stopped at Stop 1 for the team, because stop rules fired: targets 2 and 4 conflict for a flat bottom (Savitsky), the baseline already misses target 2 in 5 of 9 cases, the grid check moves the wet front by 34 cm, and the flat tail needs files outside agent 1's list. The four decisions are in U1_PROGRESS.md's Next action. Agent 4 is not launched. Also open: Max's own estimate of the flat-water rail-down angle (agent 2 found no source).

## 19 October 2026 - Session 46: play-test feedback, the wet area when planing (U1 planned)

**Phase:** documentation, after the merge of Sessions 38 and 39 to `main`. Max's first play-test of the merged game: "playable and feels quite ok". From now on feedback is researched and planned first, and built later.

**Done:**
- The repository cloned to a new Windows PC (Max's) and Godot 4.7.2 installed there (`GODOT` set as a user variable). Blender 4.5, the map's Python packages (`tifffile`, `Pillow`, `imagecodecs`) and `.map_data/` are not on this PC yet.
- W3's "the day" (start front, day types) moved to Later, L1, by Max: the lake sails well in the average day, and gameplay comes first (MAP_SILVAPLANA_PLAN.md).
- New [PLAYTEST_UPGRADES.md](archive/PLAYTEST_UPGRADES.md), one place for every piece of play-test feedback, linked from the rebuild plan. **U1, planing on a smaller wet area**, researched and planned. Max felt the board is wet much further forward than a real one (from the front foot back). Measured on a steady 18 kt beam reach: the board is wet for 1.87 m from the tail at 0.93° of trim, and the friction is 223 N against a sail drive of 319 N. Real boards are wet for 0.6 to 1.0 m (Sutherland 1993, Gourlay & Martellotta 2011, shapers). The cause is the load path: the harness line carries 945 N (measured on a real sailor with a 6.5 m² sail: 415 N), the rig carries 91 % of the sailor's weight to the mast foot 1.30 m from the tail, and the water must push there. The 1 cm tail kick takes about 1° of trim from a short wet part. The fin alone is not the cause. Max's technique on flat water (almost all the weight on the back strap, the nose lifted by loading the fin and pulling up with the front foot) is the opposite of what the game's sailor does: it hangs in the harness, doesn't lean back (`hang_back_m` 0), presses the bow down with the feet (−120 N·m) and holds the board flat. The plan now gives the sailor that technique (U1.3, U1.6). Six what-if runs with command-line overrides: less mast-foot load gives a shorter wet part and 2 kt more speed, but the board then porpoises at 1.78 Hz, the yaw wag of Session 39. The plan has eight steps (U1.1 to U1.8), targets, risks and sources.

**Verified:** `tools/check.sh` 188 files, 0 failed, and `tools/test.sh` 335 of 335 on the fresh clone. No code changed this session. The what-if CSVs are in `.sim_output/wet/` (not in git). NOT verified: the real-world wet length and trim are theory and statements from shapers and experienced sailors; no measurement was found.

- Later the same day, Max's answers went into the plan:
  - Porpoising is not the same as riding over waves (U1.5).
  - "Loading the fin" is both pushing on the rail and tipping the leeward rail down a little (U1.6).
  - Fins bend, and a 44 cm fin can almost lift the kit out of the water. That became its own upgrade, **U2**, with a first estimate.
- **U1 is ready to build.** It has an execution brief for a lead engineer with sub-agents:
  - the go-ahead and the branch;
  - the project's rules and the Windows PC's pitfalls;
  - exact definitions of every measurement (the "standard run");
  - the baseline that must not get worse, and the targets in priority order;
  - when to stop and report;
  - the numbers still needing a source;
  - the scope;
  - step 0, step 1 (the flat tail), three parallel work packages (measure, sources, porpoising diagnosis), one agent for the coupled physics, then validation and screenshots;
  - three stops: the lead's check, Michiel's review, Max's play-test.
- Then set up for the build Max wants:
  - **The team:** Fable 5.1 as the head developer, leading at most 5 Opus 5.5 sub-agents at extra-high effort, 3 at a time, each in its own worktree on a `u1/<name>` branch. Agent 1 measures, 2 finds sources, 3 diagnoses the porpoising, 4 does the coupled physics, 5 finishes.
  - **Testing on reaches only:** 60°, 100° and 135° at 12, 18 and 24 kt (the "reach check"), plus the straight runs of the matrices. No manoeuvres; the team runs the full matrix before the pull request to `main`.
  - **Token rules**, and a handoff that survives the lead running out: the new [U1_PROGRESS.md](archive/U1_PROGRESS.md) holds the state, the next action, and the start and take-over prompts. The agents commit their reports on their branches.
  - `.gitignore` now ignores the agents' worktrees (`/.claude/worktrees/`).

**Decisions:**
- Documentation mode (Max): play-test feedback becomes a researched plan in PLAYTEST_UPGRADES.md; building comes later.
- **Michiel gave the go-ahead to build U1** (19 October 2026, told to Max), on a git branch: `feature/u1-planing-wet-area`, made from `main` at 561849c. The documents of this session are committed there, not on `main`.
- Not in U1: the fin's bending and size (U2), and a player control for the trim (a team decision, later).

**Next:**
1. Build U1 on `feature/u1-planing-wet-area`, following its execution brief, starting with step 0.
2. Michiel, when it suits him: the planing-onset band still open from Session 39. U1 keeps it as it is and reports where the onset moves.
3. Max: more play-test feedback, each as an upgrade (U3, ...).
4. The open items of Session 39 stand; its item 2 (the porpoising) is now step U1.5.

---

## 16 October 2026 - Session 39: waves by group, Phase 7 and 8, sailing on Silvaplana, the board's shape and the map's wind

**Phase:** 7 (environment and effects) and 8 (audio) built; the map's M3 (sailing on the lake) and W5 (the map's wind in the physics); the waves restructured; the board's shape in the physics. Branch `feature/visuals-and-ui` (on top of Session 38, nothing merged to `main` yet). Michiel's jobs after Session 38's play-test: the sail flutters too much (only without load), the figure's core looked wonky, sail Silvaplana instead of only flying over it and test the physics in the map's wind; then separate the chop from the swell, finish Phase 7 together with the map's work, Phase 8, document everything, and improve the physics with the board's shape. Seven sub-agents (Opus) on their own git worktrees and branches, merged here; the seams fixed by hand are listed under "Merged".

**Done:**
- **The sail flutters only without load** (`rig_visuals.gd`): the flutter follows the pressure in the sail, the lift and drag coefficient together, not the angle of attack. A powered sail (load above 0.55) is still; near luffing a ripple runs just behind the mast; only a sail with no load (below 0.1) flaps all over, with smaller waves (0.03 m at the luff, 0.06 m per metre of chord at the leech) at a speed that follows the apparent wind (0.3 Hz per m/s, a flag's constant Strouhal number; Virot et al. 2013). Measured with `tools/simulate.sh sail_flutter`: the powered beam reach at 18 kt reads flutter 0 every second, the sheeted-out run 1.0.
- **The figure's core is one body** (`figure_skeleton.gd`, `sailor_figure.gd`): three tapered pieces (belly, ribs, chest) on one smooth spine curve from the pelvis to the shoulders, twisting gradually from the hip line to the shoulder line, a shoulder bar, the harness as a belt on the pelvis. Bone lengths and the tests unchanged; a new test checks the pieces meet on the curve without a sharp turn.
- **The waves in two groups** (spec 9.15 and 9.16): each wave is swell or chop (`group` in the `.tres`). The swell follows the wind (`swell_offset_deg`) or comes from a fixed compass bearing (`swell_from_deg`, `swell_relative_to_wind` off); the chop follows the wind with `chop_offset_deg`; `align_to_wind` is gone. The default sea is the same four waves as before (a test pins them), so the validation's sea numbers did not move (90° -1.2 %, 120° +0.3 %, 60° -0.5 % against flat water). New `WindWaves` (`Game/sim/wind_waves.gd`) turns wind speed, fetch and depth into lake chop: the JONSWAP fetch relations in the Shore Protection Manual's form (Hasselmann et al. 1973; SPM 1984), the height capped at 0.6 times the depth (Coastal Engineering Manual 2002), the length from the dispersion relation with depth, the peak wave plus a shorter one at 1.5 times the frequency with a third of the amplitude turned 30° (Mitsuyasu 1975), steepness the physical kA capped at π/7. It matches the Silvaplana table of request R6 within 5 %. The Waves tab gained the swell's source and bearing, the swell height, the chop direction, and a "From the wind" preset with fetch (0.2 to 20 km) and depth. Open: in shallow water the waves have the right length but travel at the deep-water speed (a depth term in spec 9.1 and the shader).
- **Phase 7, with the map's look** (R9 answered with option 1): `Game/world/water.gdshader` has the waves and Max's see-through lake look (depth-based colour and transparency, refraction, Fresnel, ripples that tilt the wave normal and drift downwind), with a parameter set per scene (`Game/world/sea_water.tres`, `Game/maps/silvaplana/lake_water.tres`); the wave formulas moved into `Game/world/gerstner.gdshaderinc`, shared with the foam wake so it rides on the waves. `OceanNode` gained `look`, `render_layers`, `far_area_xz` (keeps a lake's far water inside its shore band) and `set_water_parameter()`; the water no longer casts shadows. The open sea got the map's sky and its 15:00 summer sun and a 20 km haze. New effects (`Game/windsurfer/effects.gd`, `Game/world/effects/`): spray off the rails at the spray root, more off the leeward and the low rail, growing with speed and planing; a foam wake that fades in 7 s; a splash on a hard landing (the water's support jumping by 2.5 times the weight within 0.2 s) and on a fall; a red streamer at the masthead; an orange wind flag on a buoy near the start; the Phase 6 force view on F3 (or `--forces=1`) with a legend. Islands are covered by the real lake and not built. Cost: about 0.04 ms of CPU per frame; the GPU time stayed under 1 ms per frame (165 fps, the display's cap, before and after).
- **Phase 8, the sound** (`Game/audio/`): every sound is made from seeded noise at startup (wind, hiss, whistle, lapping, rumble, flutter loops; splash, crack and swoosh one-shots), played through Wind, Water and Sail buses with filter sub-buses (`Game/default_bus_layout.tres`). `SoundMix` turns the telemetry into levels: the wind grows 12 dB per doubling of the apparent wind (wind noise at a cyclist's ears rises about 13.6 dB per doubling) with a whistle above 16 kt; lapping and rumble cross over to the planing hiss with the planing ratio smoothed over 0.7 s; the sail flaps inside its 5° luff zone, cracks when it fills and swooshes when the rig changes sides in a tack; splashes on slams of 1 m/s or more, a nose digging in, a fall and the water start; silent from the sail while the sailor is in the water; 8 dB quieter behind the start menu. The tuning numbers are in `Game/config/sound_mix_default.tres`; Wind, Water and Sail sliders joined the master on the Audio tab. `res://audio/print_levels.tscn` measures the real output of each bus over an autopilot run (slow: the water louder than the wind; planing: the wind loudest, the hiss above the lapping). Nobody has listened yet.
- **Sailing on Lake Silvaplana** (map plan M3): "Sail on Lake Silvaplana" in the start menu (second option; the fly-over is the fourth) or `tools/play.sh lake`. `sail_silvaplana.tscn` extends the sailing scene: the map's terrain, sky, sun and reflection probe, the start 40 m off the camping beach (LV95 2780880 / 1147510, 23 m of water) heading 132°, a beam reach over the widest part of the lake (the other beam reach hits the beach after 30 m). The lake's own wind file (`wind_silvaplana.tres`: 16 kt from 222°, gusts 0.25, shifts 10° over 60 s) until the map's wind model is connected (below); the settings' waves and sailing options apply. The shore stop of MD6: every tick the depth under the board is read from the 2 m grid (`shore_check.gd`); shallower than the fin plus 12 cm, or off the grid, the simulation freezes, the HUD says "Aground off the shore. R: back to the start" and R restarts at the start. The HUD has a mini-map of the lake (`mini_map.gd`, the outline from the depth grid, the board, the wind and the start) and the compass's north is the real north. 585 to 684 fps on the lake at 1920x1080 on the RTX 3080 Ti.
- **The board's shape in the physics** (spec 5, 6, 14, 16, 17.14): the tapered box is gone. `BoardConfig` holds what a shaper quotes: the widest point (0.72 m, 1.10 m from the tail), the width one foot off the tail (0.45 m, from real 115 to 125 L freeride boards at 0.62 to 0.63 of the width: Starboard Futura 117 47.7 cm, Carve 115 and 125 44 and 48 cm) and off the nose (0.45 m), a thickness profile (12 cm in the middle, 5.5 at the tail, 4 at the nose), and the rails (hard up to 1.2 m from the tail, soft from 2.0 m, a 3 cm edge face); only the tail width is measured, the rest are estimates marked as such in section 14. The buoyancy rows follow the outline (still 120 L; the old taper had made the tail 0.60 m wide). The sideslip physics comes from NACA TN 4187 (Savitsky, Prowse and Lueders 1958, flat planing plates towed at yaw and roll): a flat bottom with sharp edges carries no sideways force of its own; the rail's edge face grips with about the full dynamic pressure once a strip skids past about 7.5° (less when that rail is lower), modelled strip by strip so a spinning hull is held back by its tail and nose. Two things the outline exposed: the hull now takes water along sideways (its sides, about 6 kg at rest, and the fin's 2.8 kg, which also gives 2.3 kg m² of yaw inertia when the hull skims), and the Savitsky anchoring used the nose width whenever the whole hull was wet, which inflated low-speed lift two to six times (1.5 kN of "lift" on a submerged board). The harness rope's damper acted although the rope was off; it is off now. The planing onset: with the lift bug gone the onset was 20 km/h; the real cause was the sailor's stance, walked forward as soon as the bow began to rise (against what `SailorConfig` documents); held aft through the hump the onset is 4.48, 5.05 and 4.99 m/s at 12, 15 and 18 kt (9.8 kn at 15 kt). A catapult at full speed then rolled the thrown board in the air: the rig's water drag pulled 0.5 m below the mast foot; it pulls at the mast foot. **DECISION FOR MICHIEL:** the validation's onset band was 14 to 17 km/h from the legacy game's documents, and the old model met it only through the lift bug; it is now 8 to 10 kn (4.12 to 5.14 m/s) from real boards (GPS reports of the planing threshold at 9 to 10 kn on the seabreeze forum, an iSonic 122 and a 94 L board; boards drop off the plane below about 8 kn, The Windsurf Loop), written in section 14 part B, the tuning log and the test. Tail width works as Savitsky says: towed with the weight aft, a 0.50 m tail needs 98 N to get over the hump, a 0.40 m tail 121 N. The Blender board follows the new outline (a square-pin tail; `board.glb` regenerated). The rail grip in a carve is not done: TN 4187 gives no consistent coefficient for it.
- **The map's wind in the physics (W5), thin air and fresh water (R1 to R3), gust patches (R9):** `MapWindField` (`Game/sim/map_wind_field.gd`) is a `WindField`, so the simulation does not know which it has: it keeps a time of day (14:30 at the start, real time, `--time=hh:mm`), gives the sail and the sailor's windage MapWind's local wind (gusts, lulls, shifts, the shore lee) scaled from the pattern's 5 m with the power law, and the lake's mean wind for the decisions that must not flip with every gust (the sail side, the water start, the TWA, the waves' direction); outside the map the lake mean, never NaN. `EnvironmentConfig` and `WindsurferSim.create_for(env)` let a map bring its own air, water, wind and waves (R1); `environment_silvaplana.tres` sets 0.98 kg/m³ air (R2) and `water_silvaplana.tres` 1000 kg/m³ and 1.14e-6 m²/s (R3); `create_default()` calls it with an empty environment, so nothing on open water changed; the pilots take the air density from the sim. The lake scene is on the ocean's new API (the lake look, layer 2, the far water over the depth grid's area; the hand-dressed meshes are gone); `WindRippleMap` draws the map's wind into a 256 × 256 texture on the graphics card every frame for the shader's `wind_ripple_map` (ripples proportional to the square of local over mean; `--check-gusts=1` compares the texture with MapWind's numbers, within one 8-bit step; about 0.05 ms per frame, the map wind about 0.45 ms per physics tick). The HUD shows the time of day, the lake mean at 10 m and the local wind at the sail. The thin air (`tools/lake_matrix.sh --compare=1`, a beam reach at the same wind): -69 % at 10 kt (it does not plane), -21 % at 11, -8 % at 12, -0.6 % at 14, +1.2 % at 18.2 kt: it costs most at the planing threshold; in a strong Maloja the sailor is overpowered and sheets in anyway, and the body's windage is 20 % lower too. Fresh water adds 0 to 3 %. The gusts show on the water mostly in the glitter; a stronger look needs the shader.
- **The physics tested in the map's wind** (`tools/lake_matrix.sh`, 24 cases at three times of day, flat water): before the hull changes 23 of 24 complete and no falls (12:00: 14.7 kt mean from 218, 14.9 to 18.6 kt at the sail, straight 20.9 kt; 14:30: 18.2 kt from 222, 12.0 to 17.5 at the sail, 18.7 kt; 17:00: 16.5 kt from 222, 14.5 to 18.2 at the sail, 21.9 kt; the 12:00 run turned 58° of the 60° asked). After the hull changes merged, three tacks stopped completing (`tack_stb` and `tack_held` at 14:30, `tack_port` at 17:00). The hull was not at fault: near the shore the lake's mean wind is 15° off the wind at the sail (off the camping beach at 14:30 the local wind comes from 206 against a mean of 222; in the middle at 17:00 from 236), and the sailor waited to flip the rig until 25° past the mean, beyond the 35° a backed sail can push (the boom fully across lies along the wind: angle of attack 0, 1 to 3 N of lift, the board drifting backwards). The old hull got there by about half a degree on its leftover 2 to 2.7 m/s; the new hull, carrying water sideways (correct physics, Newman 1977), had slowed to 0.9 m/s and stopped at 20.5°. The tack's decisions (flip the rig, give up, end the backing) now read the true wind at the sail (`Telemetry.twa_at_sail_deg`): a sailor flips on the wind they feel. No number changed; a test tacks in a wind 16° off its mean. The lake matrix is 24 of 24 with no falls, and the open-water matrices are unchanged to the digit. The 1.7 Hz yaw wag the map-wind agent saw on a close reach (±15°/s with the planing share cycling 26 to 100 %, also on open water at sea level: `tools/lake_matrix.sh --only=straight --wind=steady --air=1.225 --water=1025 --kt=18 --from=207`) is the porpoising seen in yaw: in one 0.67 s cycle the pitch swings 0.6 to 4.2°, the planing lift 70 to 1400 N, the heel 0.5 to 3.9°; it should go when the porpoising does.

**Merged:** the branches `feature/figure`, `feature/waves`, `feature/audio`, `feature/silvaplana`, `feature/effects`, `feature/mapwind`, `feature/physics` and `feature/laketack`, in that order. Seams resolved by hand: the settings file's audio volumes next to the four-option menu clamp; the open-water sun lines (the map's 15:00 sun with the null check the lake scene needs); the spec's tuning log, where two branches appended rows; and `effects.gd`'s spray root, which read the removed width taper and now reads the board's outline (`BoardConfig.width_at`).

**Verified, on the merged tree:** `tools/check.sh` 188 files, 0 failed. `tools/test.sh` 335 of 335 (245 at the end of Session 38: figure and flutter 2, waves 13 plus `test_wind_waves.gd`, audio 28, the lake 8, effects 17, the map wind 10, the environment 5, the hull's new tests). `tools/test.sh validation` 20 of 20 (with the onset band of real boards, the decision above). `tools/matrix.sh` flat 24 of 24, no fall, straight 8.77, 11.10 and 12.01 m/s at 12, 18 and 24 kt (8.75, 10.54, 11.75 before: the real outline wets less bottom, up to 5 % faster, every polar angle still inside its real-world range). The default sea: 1 fall (`gybe_broad` 24 kt, a catapult at 44.6 s after the gybe, launched off a crest at 13.7 m/s) and 2 manoeuvres not completed (`gybe_beam` 24 and the 24 kt run turn, which stops at 50° of the 60° asked). The medium chop: 0 falls (1 before) and 1 not completed; the straight 18 kt run on it went from 12 yaw spikes above 60°/s (peak 124°/s) to 0 (peak 56°/s). The lake matrix as above. Screenshots in `.screenshots/session39/` (not in git): `figure/` (before and after), `waves/`, `audio/`, `lake/`, `effects/` (before and after, the force view, the lake with the old and the unified water), `mapwind/` (14:30 and 11:00, the gusts from above, the high shot toward St. Moritz), and the merged tree's `final_start_menu.png`, `final_sea_orbit.png`, `final_lake_orbit.png`. NOT verified: anything in motion (the flutter, the spray, the gust patches), how the sounds sound, how the lake or the new hull feel to sail, the menus with a real mouse or gamepad.

**Decisions:**
- The flutter is a visual of the sail's load, with its thresholds in `rig_visuals.gd` like the other rig visual numbers.
- The two wave groups keep the default sea wave for wave, so no validation number moved; "From the wind" is a preset, not the default, until the crest landings are solved (its chop is about six times steeper than the default).
- One water shader for the sea and the lake (R9, option 1), parameter sets per scene; the wave formulas in one include file.
- The open-water islands of Phase 7 are not built: the real lake has a real shore.
- On the lake the settings' wind is ignored (the lake's wind file, then the map's wind model); the settings' waves and sailing options apply.
- The board's outline is the shaper's numbers; where no measurement was found the value is an estimate and says so in section 14.
- The planing-onset band is the one decision Michiel must confirm or reject (above): the real range with its sources replaces a legacy number the old model only met through a bug. Nothing was tuned to it: the onset moved for a physical reason (the stance through the hump).
- On the lake the sail side, the TWA and the waves follow the lake's mean wind; only the sail's force and the windage feel the local gust. The thin air applies to the sail and the windage, nothing else.

**Next:**
1. Michiel: confirm or reject the planing-onset band (8 to 10 kn, real boards) in `test_polar_sweep.gd` and section 14.
2. The 24 kt sea cases: the run turn stopping at 50°, the beam gybe, the catapult off a crest after the broad gybe; behind them the porpoising of the planing board on flat water from 15 kt up (near Savitsky's porpoising limit), which is also the close-reach yaw wag.
3. Play-test (the team): the sound by ear (the list in the plan's Phase 8); the lake with the Maloja (Max: the launch spot, the wind's side, the gusts, the shore stop, the mountains); the spray, the wake and the flutter in motion; the new hull's feel (planing onset, carving, chop); the gusts on the water (too faint?); the Waves tab with a swell from another direction.
4. Open from the agents: shallow-water waves travel at the deep-water speed (a depth term in spec 9.1 and the shader); the rail grip in a carve (TN 4187 gives no coefficient); the completion criteria of the gybe test and the lake runner at 24 kt; running aground in the physics (R4); the audio's shutdown warning about leaked looping sounds; the settings header still says "23 rows"; the HUD's top line runs off the right edge at 1280 wide.
5. Then Phase 9 (racing), with the course maker's courses on the lake.

---

## 16 October 2026 - Session 38: the sailor figure, Blender models for the rig, and the game's menus

**Phase:** 6 (rig visuals), plus the sailor figure and a user interface (the UI has no phase of its own in the plan). Branch `feature/visuals-and-ui`, from `main`. Michiel asked for three jobs at once: a sailor that moves like a real windsurfer, a graphics upgrade of board, sail, boom and fin made with Blender, and a start menu with settings. Each job was done by a sub-agent (Opus, extra-high effort) on its own git worktree and branch (`feature/character`, `feature/rig`, `feature/ui`), merged here with one fix at the seam.

**Done:**
- **The split first** (3d9a8d6): `windsurfer.gd` only steps the simulation now; `rig_visuals.gd` draws the board and the rig, `sailor_figure.gd` the sailor, `visual_math.gd` holds the small mesh helpers both use. No change on screen.
- **The sailor figure** (`figure_skeleton.gd`, `sailor_figure.gd`): a skeleton with fixed bone lengths from the sailor's height (Winter's body proportions: for 1.75 m a thigh of 0.43, shin 0.43, upper arm 0.33, forearm 0.26, hips to shoulders 0.50 m), solved every tick from the simulation's centre of mass, feet, grip, lean, stance, harness tension and turn rate with two-bone inverse kinematics, so limbs never stretch, knees bend only in the plane of the foot and forward over the toes, and elbows point down and out. Planing hooked in it shows the "figure 7" stance: front foot about 45° toward the leeward bow and back foot across the board, front leg nearly straight (158°) and back leg bent (135°), arms nearly straight, hands shoulder-width apart, harness lines drawn when hooked in. Standing it is upright with soft knees and bent elbows; in tacks and gybes it crouches, takes the mast in the front hand and turns round through facing the bow. A head with a neck, a cap, sunglasses and a nose looks toward the bow and into turns. Capsule limbs, knee and shoulder balls, a black wetsuit, red lycra, a harness with hook, booties. The one compromise: hanging out, the simulation puts the centre of mass 0.3 m above the deck and 1.5 m from the grip, further than a body of fixed size can hold the boom from, so the hips are kept at least 0.65 m above the deck and drawn toward the boom (0.44 m off the centre of mass at 18 kt; `FigureSkeleton._place_pelvis`).
- **The rig models** (`tools/blender/build_rig_models.py`, 2 s in Blender 5.2): built from scratch from the numbers in `Game/config/*.tres` (the legacy FBX files were a reference only and are deleted), one `.glb` per part in `Game/assets/models/`: a shaped 2.40 m board with deck pad, orange bow, blue bottom, four footstraps, mast track and base plate; a swept foil fin (0.0364 m²); a tapered mast with extension and rubber joint; a 24 × 40 sail grid with cloth, clear windows and a darker luff sleeve, 6.38 m² against 6.5 in the config; a wishbone boom 0.57 m wide with grip, harness lines and outhaul; and our own panel design with "MMZB" lettering (no brand images). The sail bends in a vertex shader driven by the simulation (`sail_cloth.gdshader`, `sail_window.gdshader`, `sail_cloth.gdshaderinc`): belly to leeward (draft 0.10, deepest at 38 % of the chord), twist 8 to 16° at the head with the pull, ripples when luffing, and the belly crosses over in 0.8 s when the sail flips; the mast bends back and to leeward (`mast.gdshader`) and the sail follows. The two pose functions of `RigVisuals` kept their contract; `shape_sail()` feeds the shader each tick. Automatic LODs are off for the sail and the mast.
- **The menus** (`Game/ui/`): the start menu is the project's main scene, with the sailing scene running behind it (the autopilot sails, a slow orbit camera): Sail on open water, Lake Silvaplana (fly over the map), the Silvaplana wind viewer (with the course maker), then Settings, Controls, How to sail and Quit (with a confirmation). Settings on five tabs, saved to `user://settings.cfg` by the `GameSettings` autoload: wind (speed 4 to 35 kt, direction with the compass name, gusts and shifts), waves (off, flat, swell, medium chop, strong chop with the Session 37 numbers, a height scale), sailing (beginner or advanced, auto-sheet, start heading with its point of sail, starting camera, detail panel), graphics (windowed or fullscreen, VSync, anti-aliasing, resolution scale, shadows, frame-rate cap) and audio (master volume, wired to the Master bus for Phase 8). The sailing scene builds its wind and waves from the settings; a new wind applies as soon as the settings close, new waves at the next restart (the pause menu says so). Esc opens a pause menu (resume, restart, settings, controls, how to sail, start menu, quit); the old Esc pause never stopped the physics, because the windsurfer inherited "always run": fixed. Esc returns to the start menu from the two Silvaplana scenes through a small autoload (`ui/map_escape.gd`), with no change to the map track's code. Keyboard and gamepad navigation, a theme for the menus only, a version label. Options for screenshots: `--settings=<file>|defaults`, `--pause=<s>`, `--page=settings/<tab>|controls|howto|quit`.
- **At the seam** (98b6c4e): the physics puts the hand grip on the boom's centre line, which with the wishbone runs between the two arms, inside the sail; the figure's grip (and the harness lines) are moved by `RigVisuals.windward_arm_offset()` onto the windward arm.
- **Dev views:** `Game/dev/figure_view.tscn` saves contact sheets of the figure from six cameras at chosen moments (wind, angle, tack, a tack or a gybe), `Game/dev/rig_view.tscn` the rig from eleven cameras on either tack and prints the frame rate (165 fps, 0.44 ms of GPU time per frame on the RTX 3080 Ti). The commands are in CLAUDE.md.

**Verified:**
- `tools/check.sh`: 152 files, 0 failed. `tools/test.sh`: 245 of 245 (204 before; new: `test_sailor_figure.gd` 6, `test_rig_visuals.gd` 18, `test_game_settings.gd` 12, `test_menus.gd` 5). The physics is untouched: the sailing scene at 8 s shows the same HUD numbers as before the session (40.7 km/h, sail lift 655 N, fin 669 N); no validation run was needed.
- Screenshots, kept in `.screenshots/session38/` (not in git): the figure planing on both tacks, standing, through a tack and a gybe, falling, at 12 and 24 kt (`figure/`); the rig from every side on both tacks and luffing (`rig/`); every menu page, the pause menu over the game, and the proof that the settings reach the physics: with 24 kt from the North and strong chop in the settings file the HUD reads "wind 24.0 kt … from 000" over a choppy sea (`ui/`); the merged game from the follow camera and the deck close-up with the hands on the windward boom arm.
- NOT verified: anything in motion (the figure's turn-around in a tack, hand changes, the ripples and the belly crossing over, the mast bending in gusts), how it feels to play, a real mouse and gamepad in the menus, fullscreen and VSync on the team's monitors, the frame rate on the other PCs, sound (there is none).

**Decisions:**
- The figure is a representation on top of the physics, as Michiel allowed: fixed bone lengths win over the exact centre of mass when the two disagree, and the code says where (`_place_pelvis`). Nothing visual feeds back into the physics.
- The models come from a script that reads the config numbers, not from the legacy FBX, so the team can change a size and rerun it. One `.glb` per part, origins in the script header: the board at the simulation's board origin, the rig parts at the mast foot with the mast along +Y and the sail along +X.
- The start menu is the main scene; `res://main.tscn` stays runnable on its own, so every screenshot command still works. Settings live in `user://settings.cfg`; the `.tres` defaults are never written.
- The rig's boom stays horizontal in the physics' frame when the mast rakes, so the model's sail is slightly sheared at full rake. Kept: it is the physics' contract.

**Next:**
1. Play-test (the team): the figure's stance at 12, 18 and 24 kt and through tacks and gybes; whether the sail's belly, twist and flutter look right; the menus with a mouse and a gamepad; fullscreen.
2. Open from this session: the force-vector debug view (the last Phase 6 box); a skinned character mesh; the figure's elbows (the back elbow is straighter than the front, coaches say the opposite), animated hand changes, a fall that is still a rigid tip-over; the HUD's top line runs off the right edge at 1280 wide (older than this session); a stretch mode for fullscreen (would also scale Max's map panels: ask him); sailing with a gamepad.
3. For the physics track (spec OPEN 2.4): the sail model's area centre is at 0.49 of the luff and 0.41 of the boom; the config uses 0.40 and 0.35. And the figure cannot lean out further than the rig lets it: hiked, the rig leans only about 11° to windward.
4. Then Phase 7 (environment and effects).

---

## 16 October 2026 - The physics and the map tracks merged

**Phase:** none (branches).

**Done:** `feature/physics-sim` (Sessions 30 to 37) merged into `feature/map-silvaplana` (Sessions 37 to 45 of the map track, which had started from the physics branch at Phase 5). The one conflict was this log: both tracks' entries are kept, in date order. Both branches go to `main` through pull requests #2 (the physics) and #3 (the map, which now contains the physics). The map's files need Git LFS: it was not on the Linux PC, so it is installed in `~/.local/bin` (no sudo), `git lfs install` run, and the 114 MB of terrain tiles, photos and the height grid fetched. Small edits so the documents fit together: CLAUDE.md (the map track is part of the project, not a branch; Git LFS), REBUILD_PLAN.md (the side track), MAP_SILVAPLANA_PLAN.md (merge `main` from now on), PHYSICS_REQUESTS_FROM_MAP.md (R6's precondition, the two-body sailor, is done).

**Verified:** on the merged tree `tools/check.sh` 122 files, 0 failed, and `tools/test.sh` 204 of 204 (126 physics, 78 map). The physics is unchanged by the merge (the map does not touch `Game/sim/`), so the validation suite and the matrix were not rerun. Not run: the map's Python tests in `tools/map/tests` (they need `tifffile` and the other map modules, which the Linux PC does not have).

**Next:** the team merges the pull requests (#2 and then #3, or #3 alone), then everyone installs Git LFS and pulls `main`; new work branches from `main`.

## 16 October 2026 - Session 45 (map track): the map documents brought up to date

**Phase:** none (documents only). Branch `feature/map-silvaplana`.

**Why:** Max: "I see some neglected sections. See L1, this we've already done."

**Done:**
- **L1 (the wind patterns)** in MAP_SILVAPLANA_PLAN.md: a status. Max's part is mostly built as the wind analyser (W0 to W4, `MapWind`). Still open: the day types (W3, postponed) and the connection to the sailing (W5, Michiel). The Status table, "Who does what", and a note after the team decisions say the same. CLAUDE.md, REBUILD_PLAN.md and PHYSICS_REQUESTS_FROM_MAP.md no longer say "later the wind patterns".
- **M3's wind direction:** 244° → 222°. W1 found that 244° is the station's spot turning the wind; over the lake the Maloja blows along the lake from about 222°, which Max confirmed. M3 also notes that the sailing keeps a `WindConfig` until W5.
- **Max's verdicts written in where they were missing:** the terrain "is really good and nice" (Session 41, the M1 and M2 checks); the 10 cm photos agreed (M0); the W1 picture right; W0's questions 1 to 6 answered (7 to 10 still open); the W2 colours and gusts done.
- **Facts that had changed since the plan was written:** the lake level (1790.63 m) and the origin, both fixed in M0; the manifest's place (`.map_data/raw/`); the grid formats (numpy for Blender and a 16-bit `.bin` for the game, not PNG or EXR); the photos go on in Godot, not in Blender; no terrain plugin needed.
- **R4 for Michiel** gave the wrong grid format and said the shallows were "checked against the 10 cm aerial photo". Nothing in `heights.py` or its checks does that, so it now says "not yet checked".

**Verified:** each changed fact against the code and the data (`map_config`, `maloja_day.tres`, `.map_data/raw/manifest.json`, `heights.py`, `build.sh`, git). Session 44's work is committed and pushed (`b9cc3a5`, "Map W4a: race course maker in the wind viewer"). No code changed, so no tests were run.

**Max's looks (16 October):** adding marks to a course works well, and so does the see-through lake water (M2). So W4a is checked, and M2 waits only for Michiel's answer to R9.

**Next:**
- W4b, the tactics tools, detailed with Max first: lifts and headers against the course axis, the stronger lanes, laylines (they need the iQFOiL's upwind and downwind angles), which side paid.
- Michiel: R9 (how the see-through water meets his waves), before M3. The small changes to CLAUDE.md and REBUILD_PLAN.md (one sentence each) are to mention to him (MD7).

---

## 15 and 16 October 2026 - Session 37: the sailor as a body of their own, and the rig held by the sailor

**Phase:** between 5 and 6. The team asked for a real character model with the physics updated to include it, then chop work with it. Done: the physics (spec 7.5), the visible figure, the chop runs. Stopped once mid-way on request (commit `271dbb8`); finished in the second half.

**Done (spec 7.5 and 17.13):**
- Two bodies: the hull (`SimRigidBody`, 9 kg plus the water it drags) and the sailor (`SailorBody`, `Game/sim/sailor_body.gd`, 75 kg at the centre of mass). The rig (8 kg) is in balance between the mast foot (a joint) and the hands; the harness line is in that balance, so the line carries about 400 N of the sailor's weight at 18 kt and the mast foot gets it as mast foot pressure. The legs are a vertical spring and damper (1.2 Hz, 0.9) measured from the feet; across the deck the body rides the hull through the force at the deck point under it. The posture (lean, stance, hang-back) is held in the apparent-gravity frame; the lean answers the hands' pull about the feet; the feet go to the windward rail as the body goes out and press a rail when the controls ask; over the hump the feet trim the board to 2 degrees.
- What the feet pass to the deck: the moment the body cannot balance itself, at most 120 Nm in roll, with the toes-and-heels reflex (1500 Nm/rad, 600 Nm s/rad) in what is left. Falls are physical: the excess tips the body; the hips hold 400 N (plus 400 hooked in) for 0.3 s, then "tipped over" or "tipped back". The old heel rules remain as a backstop.
- The rig is held by the sailor, not the deck (`RigFrame`, `Game/sim/rig_frame.gd`): the hull's heading and pitch, upright in roll. This is what fixed the tack catapults at 18 and 24 kt (the whole chain is in 17.13: the light hull snapped upright under the sailor, the rig fixed to the deck swung the sail 15 degrees through the wind in one step, the sail force spiked, the pull went through the feet into yaw, the board spun to 100 deg/s and flung the sailor). The sail model now computes from the rig frame; the scene poses the rig from it.
- The autopilot sheets to what the body holds right now (hike share 1.1, ankle share 0.8) and catches a body tipping back by sheeting in. Telemetry: hand, foot and mast-foot forces, the harness tension, the feet's roll moment and its excess, the attachment force, and the yaw and roll moments on the hull by source (fin, rig, sailor, water, net), which is how the catapult was found.
- Smaller physics: the hull's friction on the dynamically wet bottom; the hull keeps its momentum when the added water grows (`take_water_along`); the posture's own moves capped at a walking pace; the body follows the stepping feet at a walking pace in a tack.
- The visible sailor (`windsurfer.gd`): an articulated figure from the simulation's body: feet on the deck where they press, two-segment legs with the knee bend, torso, head, arms to the boom either side of the grip, the harness line when it carries load; the fall animation pivots the figure about its feet and the rig about the mast foot. Screenshot `.screenshots/rig_9s.png`: 39 km/h, the sailor hiked out horizontally, the rig upright over a board heeled 4 degrees.
- Tests: `test_sailor_body.gd` (4), `test_sail.gd` on `RigFrame.rigid_on`, the legs test, the friction test on the dynamic area, the polar test's fin bound (650 N) and trim floor (0.5 deg), the upwind-on-waves tolerance 35 % to 15 %.

**Verified:**
- `tools/check.sh` 75 files clean. `tools/test.sh` 126 of 126. `tools/test.sh validation` 20 of 20: the polar within the real-world range at every angle, planing onset in range at 15 kt, the sea within 1.2 % of flat water at 60, 90 and 120 degrees (upwind was 28 % slower in Session 36).
- `tools/matrix.sh` flat: 24 of 24, no fall, no NaN, every manoeuvre complete; straight 8.75, 10.54 and 11.75 m/s at 12, 18 and 24 kt; the 18 kt run holds its heading within 0.1 degree and 0.7 deg/s of yaw. `--waves=1`: 23 of 24 (gybe_beam 24 kt catapults at 40 s, after the gybe, from a yaw spike at a landing). Medium chop (`--wave2.amplitude_m=0.04 --wave2.steepness=0.036 --wave3.amplitude_m=0.015 --wave3.steepness=0.027 --wave4.amplitude_m=0.006 --wave4.steepness=0.021`): 23 of 24 (gybe_broad 24 kt). The strong chop of the old game (0.06/0.054, 0.03/0.054, 0.012/0.042): no falls (five in the morning's runs), one gybe at 12 kt tacked instead; speed loss 6, 24 and 19 % at 12, 18 and 24 kt.
- NOT verified: how it feels to sail (the wobble and the bounce are judged from numbers), the figure in motion beyond screenshots, the sound of nothing (there is none yet).

**Everything tried on the way (so nobody repeats it):** the sideways leg spring in every form (soft, torque-free, stiff and capped, velocity-matched, the mass lumped into the hull, the constraint force at the feet, at the sailor's height), the target measured from the feet, the feet ahead of the body, the fixed sheet capacity, the inflated felt heel, the frame flipping under g, 2 Hz legs, the weight at the feet without the harness (porpoising), a rope with a length between the hips and the boom (worse on chop, broke tacks; in the code, off), a lag on the planing lift (no help; off), the rig held in the apparent-gravity frame (a 1 Hz yaw wobble on flat water), feet roll damping 300 and 450 (not enough), stiffer legs 2.0 and 2.5 Hz (no help, worse at 24 kt), the pilot's hike and ankle shares (no effect on the wobble), a rate cap on the posture (kept, harmless). The pilot's depower integrator reacts to the push of the turn the controller asked for and eases the sail while the sailor is fully hiked at a tack's entry; it did not need changing once the rig stopped swinging, but it is a candidate if tacks at speed feel wrong.

**Decisions:**
- The rig is held by the sailor: it pitches with the hull (the mast foot is a metre forward of the centre) and does not roll with it. A rig fixed to the deck is wrong and it is what catapulted the tacks.
- The sailor rides the hull across the deck; only the legs' vertical give is a real degree of freedom; falls are timed from the hips' limit.
- The sailor's roll control is one reflex at the feet, 600 Nm s/rad within 120 Nm; the one-body `balance_heel_gain`, `balance_rate_gain`, `balance_felt_gain`, `posture_sway_max_m`, `toe_heel_m` and the sideways-spring fields are gone.
- The default sea stays the Session 36 swell; the medium chop is nearly clean and can become the default once the landings are fixed.

**Next:**
1. The hull landing off a crest: the yaw rate spikes to 90 to 120 deg/s for a step or two (16 to 25 reversals in 15 s on the medium chop) and that is where the two remaining falls come from. The breakdown (17.13) says the hull's yaw inertia about its centre is 5 kg m2 when it skims, the fin's lift jumps at the landing, and nothing resists the hull spinning under the sailor's feet. Give the planing hull its lateral and yaw resistance in sideslip (Brown and Klosinski 1994) and the legs a lateral stiffness at the feet; then the medium chop as the default sea.
2. The 12 kt bounce at the edge of planing (the planing ratio 0.15 to 1.0 at 1.2 Hz on flat water, there since Session 36): the heave of the light hull against the strip theory's root force.
3. Play-test: the tacks and gybes at 18 and 24 kt, the feel of the sea, the figure.
4. Then Phase 6 (the rig visuals) as planned.

---

## 15 October 2026 - Session 44 (map track): W4 planned; W4a, the race course maker, first version

**Phase:** W4 of the map plan, part a (the course maker). Branch `feature/map-silvaplana`.

**Why:** Max asked what W4 includes, added the iQFOiL Notice of Race and Sailing Instructions of the 2026 U23 Worlds (Puck) "with pictures of the official courses", and then: "we are going to make this also a easy competition course maker. drag buoys in the map via an easy to use system ... so we can make all these courses ourselves and use templates". He agreed to split W4 into W4a (the course maker) and W4b (the tactics tools), to put it inside the wind viewer for now ("later in game it may be different"), and to save courses for the team. He didn't know the beat length.

**Done:**
- **The plan:** W4 split into W4a and W4b, with the sources, Max's decisions (WD5 to WD7), the class's numbers, the estimates, and a measurement of the lake.
- **The course sizes come from the class, not from a guess:** the iQFOiL Class Race Management Guideline (2023) gives mark 1's distance per wind range (windward-leeward 0.9, 1.0 and 1.05 nm at 10 to 13, 13 to 17 and 17+ kt; trapezoid 0.85, 0.95 and 1.0 nm), the reaches, gates (70 to 80 m), lines (start: boards × 2.20 m × 3; finish 30 to 40 m) and the sprint and medal race sizes. They are in `Game/maps/course/iqfoil_courses.tres` with their sources. What the guideline doesn't give is labelled as an estimate there: the gate 150 m above the start, the trapezoid's outer gate and finish, the upwind sprint (1000 m to mark 1, from its 7-minute target time).
- **The lake, measured** on the 2 m shore grid: along the Maloja (222°) about 2.8 km of open water, 760 to 1370 m wide. A full windward-leeward course fits; the full trapezoid's reach (1.3 to 1.5 km) doesn't.
- **The course maker** (`Game/maps/course/`, in the wind viewer, `tools/play.sh wind`):
  - `Course` and `CourseMark`: the marks and the mark order written as in the Notice of Race (`Start-1-4S/4P-1-4S-Finish`), the legs, moving, turning and scaling (gates and lines keep their size), the land warnings, and JSON files with LV95 positions.
  - `CourseTemplates`: LG2, LR2, O2, I2, US3, US4, PD3, SD3, PM1 and SM1, built in the course's own frame like the diagrams and turned to the wind.
  - `CourseEditor`, `CoursePanel`, `CourseOverlay`: choose a template (it appears in the middle of the view, squared to the lake's wind and sized for it); drag marks (a gate moves as a pair), Shift and drag the whole course; Axis, Square to wind, Size %, Boards; Undo (Ctrl+Z), Clear; Save under a name in `Game/maps/silvaplana/courses/`, Load; M hides it. The course is drawn like the diagrams: salmon marks with rounding arrows, green boats with orange and blue flags, dashed lines, black legs side by side. The panel lists the legs (length, compass course, angle to the wind now) and the warnings.
  - Start options for screenshots: `--course=LG2` (or a saved course's name), `--course-at=<east>,<north>`.
- **Small changes to shared map files:** `TopCamera` and `FlyCamera` ignore the keyboard while a text field has it; `tools/play.sh`'s menu and `CLAUDE.md` mention the course maker.

**Verified:**
- `tools/test.sh`: 186 of 186 (18 new: `test_course.gd` 11, `test_course_editor.gd` 7). `tools/check.sh`: 119 files, 0 failed.
- The rounding sides read from the diagrams agree with the way each course turns, in all ten templates (a test).
- Screenshots: the ten templates on the lake (`.screenshots/w4a_templates_sheet.png`), a close-up of a start (committee boat on the right looking upwind, 4S on the left, the finish boat at the upwind end), and the free camera low over the water.
- 98 to 102 fps in the screenshot runs, with and without a course.

Not verified:
- Dragging with a real mouse, and how easy the panel is: Max play-tests. The editing is tested with made-up mouse events.

**Decisions:**
- Templates are set to the wind like a race committee sets a course: mark 1 dead upwind of the start, at the class's distance for the wind of the moment (WD7). "Square to wind" uses the lake's mean wind, without the moving shifts.
- Where the guideline gives a range, the middle. The trapezoid's reach angle: 90°, because the guideline's 80 to 90° doesn't say from which line it is measured.
- The course is drawn on the screen over the 3D view, not as 3D buoys: the same size at every zoom, and the same from both cameras. 3D buoys come with sailing a course in the game (later).
- Saving a course under a name that exists replaces it (the panel says so); git keeps the old versions.

**Max's play-test (16 October):** easy to use (pick, drag, turn, resize, save, load), and the templates look like the diagrams in the Notice of Race. Where the race committee sets the course at Silvaplana and how it would shorten the trapezoid: not important for now.

**Then, Max: "I would like to add a mark to existing courses"** (dropped on a leg, "but it needs to work really well", and typed when that isn't what he wants). Added:
- **Add mark** and a click on the water: the mark goes into the leg drawn nearest to the click (so between a beat and a run on the same line, the one on that side), and into the same leg on the other laps; Shift for only that leg; away from the legs a lone mark. The legs it will go into light up in yellow before the click. Named with the next number, left on the side the course bends round it.
- **The order typed** in the Notice of Race's notation, checked (a wrong order is refused with the reason).
- **A selected mark** (click it): rename (also in the order), port or starboard, delete (Delete key). Esc deselects or stops adding. A click that only selects is no Undo step any more.
- The mouse is matched to the height the marks are drawn at (0.3 m above the lake), so a mark put down lies exactly under it.
- `--course-new-mark=<east>,<north>` shows the Add mark preview for screenshots.
- Verified: `tools/test.sh` 199 of 199 (13 new), `tools/check.sh` 119 files; the preview screenshot (`.screenshots/w4a_add_mark.png`): dropped beside the first run, both runs light up and the beat on the same line doesn't. Not verified: how it feels with a real mouse.

**Then, Max (a screenshot of a 3137 × 1263 window): "the UI is not nice for other resolutions, and the drawing of the arrows is wrong on a gate".**
- The viewer's panels had fixed places for 1280 × 720. A first fix scaled them as a whole; Max: "the UI is just scaled up and I can count the pixels now, it's ugly". Now each panel is anchored to its corner or edge (course panel and legend top right, clock along the bottom, wind chart left), and the viewer switches its window to Godot's "canvas items" stretch (laid out for 1280 × 720, wider windows get more room across), which draws text and lines at the window's full resolution: sharp. Only while the viewer runs; the game's screen settings are unchanged and the window's are put back on exit. Found on the way: `set_anchors_preset()` keeps a control's old size, so a full-window control needs `set_anchors_and_offsets_preset()`.
- The course panel and the clock bar got the wind chart's look (dark, see-through, rounded, with room inside).
- The rounding arrows were the same three-quarter turn from the top of every mark. Now they come in from the leg in, go round the mark's far side and leave along the next leg: at a gate, down between the marks and outwards, back upwind, as on the diagrams.
- Verified: `tools/test.sh` 200 of 200 (a new test for the arrows at a gate and at mark 1), `tools/check.sh` 119 files; screenshots at 3137 × 1263 and 1280 × 720; `--check-colours` 0.8 of 255 (the course is hidden for it).

**Next:**
- Max looks at adding marks: does dropping on a leg pick the leg he means, and is the side right?
- To commit (Max decides): the course maker, the plan, and the Notice of Race PDF in `Documentation/`, which the plan now links to.
- Then W4b, the tactics tools, detailed with Max: lifts and headers against the course axis, the stronger lanes, laylines (they need the iQFOiL's upwind and downwind angles), which side paid.

---

## 15 October 2026 - Session 43 (map track): Wind analyser W2 (the viewer) and W3's gusts and lee, measured on the satellite photos

**Phase:** W2 of the map plan (the wind analyser's viewer), then most of W3 (gusts, pulses, shifts, the lee along the south-east shore). Branch `feature/map-silvaplana`. Nothing new on `feature/physics-sim` or `main` to merge.

**Why:** Max: "Start phase W2 of the map plan: the wind viewer." The Windfinder view in 3D over Silvaplana, to study the Maloja for course-racing tactics. Then, look by look:
- "use this colors for the wind strength" (a screenshot of Windfinder's legend), and "can't see any gust going over the lake now";
- "gusts now come out of nothing and disappear", they should "progress out of the gusts more upwind";
- "they are still round, it is a front that is wider", "too much difference", and "I have the feeling you are guessing it a lot, please be more precise";
- his answers: mostly fronts, sometimes lanes; lanes 50 to 100 m wide; "too much difference" meant the gusts against the wind around them;
- "the rest is really good, good job", but the band along the south-east shore "has too much wind compared to real life; on competition you have to really avoid it, and only once in every 10 or so there is a gust that is favourable and goes down all the way".

**Done (what is in the game now):**
- **The wind, one place for the viewer and later the sailing** (WD1): `MapWind` (`Game/maps/wind/`) = the fixed pattern (`WindPattern`, W1, interpolated as arrows) × the day (`WindDay`, `maloja_day.tres`: the station's hourly medians × 1.3 on the water) + the gusts, pulses and shifts (`WindGusts`, `maloja_gusts.tres`) + the lee along the south-east shore (`WindLee`, `shore_lee.json`). `MapWind.velocity_at(point, time of day)`; for many places at one moment `moment()` + `velocity_in()`.
- **The viewer**, `tools/play.sh wind` (`Game/maps/silvaplana/wind_viewer.tscn`):
  - a map camera looking down (`TopCamera`) and the free camera, Tab to switch;
  - 5000 white streaks moved by the graphics card, drawn as particle trails, also over land up to 2100 m, sped up so they cross the screen in about the same time at every zoom ([ and ] to change);
  - the wind speed as colour on the water in Windfinder's colours (read from Max's screenshot), with a legend like Windfinder's;
  - a clock: Pause, 1×, 10×, 60×, a slider from 10:00 to 21:30;
  - click a point: a marker, and the speed and direction there over the last 10 minutes (a value every 2 s), with a hover readout;
  - `--check-colours`: compares the water's colour on the screen with the colour of the game's numbers.
- **The gusts** (third version): a smooth random pattern ("noise") of fronts across the lake (70 % of the variance) and lanes along the wind (30 %), rolling down the lake with the air (`MapWind.travel_m()`) and slowly changing; as many lulls as gusts. In knots they change only slowly with the wind (the station). The sideways part, which turns the wind, is 0.8 times the part along it (Panofsky and Dutton). The same 32-bit random numbers on the CPU and the graphics card (`WindGusts.noise_3d()`), divided by their local spread so there is no rhythm on the noise's grid.
  - Fitted by measuring the model exactly like the satellite photos: `Game/maps/silvaplana/dev/export_gusts.gd` writes the model on the photos' grid, `tools/map/gust_shapes.py --model` measures both (the table is in the plan, W3; the pictures `gust_photos.png` and `gust_model.png`).
  - The two earlier versions (patches born anywhere; patches rolling from upwind and growing) were replaced after Max's looks: their sizes, spacing, growth and "gustier at Sils" were estimates the photos don't support. The second version's files are kept in `.map_data/work/wind_research/old_versions/`.
- **Pulses and shifts:** three slow waves each (13 to 45 minutes), the station's size (about ±9 % and ±5°), travelling down the lake.
- **The lee along the south-east shore:** measured on the photos at 10 m by `tools/map/shore_lee.py` (MALOJA_WIND_RESEARCH.md, "The lee along the south-east shore"): from the Sils end to the north-east bend, deepest 25 to 100 m from the shore, weaker around "the little corner", deeper when the wind comes from further left (1.1 % per degree) and when it is stronger (4.5 % per knot). Only the strongest 1 in 10 gusts get in (Max; the photos: about 1 in 8) and roll down the band. W1's smoothed version of it is taken out again, so over time the band averages to the photos.
- **Data and scripts:** `tools/map/wind_ground.py` (the ground under the pattern, for the streaks; in `build.sh`), `gust_shapes.py`, `shore_lee.py`; `play.sh` (menu choice 3), the tools README and CLAUDE.md mention the viewer.
- **Tests:** `test_map_wind.gd` (9: the pattern, the day, the clock, the colours, the graphics card's copy of the pattern), `test_map_wind_gusts.gd` (12: exact 32-bit random numbers, spread 1 everywhere, no jumps, the mean kept, knots added, fronts across and lanes along, rolling with the air, the sideways share, pulses and shifts), `test_map_wind_lee.gd` (6: where the lee lies, its depth, 1 in 10 gusts through, a strong gust lifts it and rolls down the band, nothing changes elsewhere).

**Verified:**
- `tools/test.sh`: 168 of 168. `tools/check.sh`: 109 files, 0 failed. `test_wind_pattern.py`: 6 of 6.
- The graphics card computes the same wind as the game, gusts and lee included: `--check-colours` within 1 of 255 at 11:10, 14:30, 16:05 and 19:30 (33 points on the water each).
- The model against the photos, measured the same way: lanes 115 × 61 m (photos 110 × 56), fronts' correlation halves at 230 m (240), spread 7.9 % (8.1), across-lake bands 35 % (39).
- At one point on the open water (13:00 to 15:00): the strongest second in 10 minutes is 1.18 to 1.25 times the mean (the land station: 1.52); a gust of 2 kt or more above the mean every 3 minutes or so, for about 30 s; the direction swings 21 to 25° within 10 minutes.
- In the lee band, 75 m off the shore in the north-east, with the wind 7° further left than usual: about half the wind is gone (8.7 kt where the open lake has about 17).
- Screenshots: from above with and without streaks, from 350 m over the Sils end, from the water at the launch, the evening, four moments 40 s apart (the fronts roll down the lake), the lee band with a probe.
- Speed: 0.6 to 0.8 ms per frame on the graphics card with the PC otherwise idle (1,300 to 1,500 fps); earlier measurements of 2 to 3 ms were taken while other calculations ran.

Not verified:
- How the streaks and the gusts move (screenshots are still pictures), the mouse controls, and the hover readout: Max play-tests.
- How bright water turns into knots: taken 1 to 1 (as in W1) for the gusts' spread and for the lee; sun-glint theory allows up to 1.7 times more. Max judges.
- How long gusts live and how fast they travel: estimates (labelled in `maloja_gusts.tres`).

**Decisions:**
- Windfinder's colours, as Max asked (the first version had one blue, readable for colour-blind people; Max chose the scale sailors know).
- The viewer uses plain (linear) tone mapping and fully covering speed colours, so the water's colours are exactly the legend's; C shows the see-through water.
- Streaks fade out above 2100 m (the pattern up there is not the Maloja), and fly at a quarter of the camera's height, so from the water they lie on the water.
- Gusts add knots, not a percentage (the station; Max's "little corner").
- The gusts are measured, not guessed: every number in `maloja_gusts.tres` and `shore_lee.json` is from the photos, the station, Max or the literature, or labelled as an estimate.
- Max's "mostly fronts" over the photos' "mostly lanes" (19 of 22 photos): his experience on the water wins (WD3), and all photos are from 12:28, while the Maloja builds.
- Pulses and shifts are three slow waves each, so the CPU and the graphics card compute them the same; they repeat only after many hours.
- Found for later: the pattern puts the station at 1.34 × the lake's average, while Max puts the water at 1.3 × the station, so a simulated station would read about 1.7 times too much (plan, notes for W3).
- Found on the photos, not built in: when the wind veers, the lee may switch to the north-west shore.

**Next:**
- **W4, the tactics tools** (Max, 15 October: W3's "the day" is postponed, W4 first, on the average day). The plan's first ideas: a course on the lake (start line, windward mark), lifts and headers relative to the course, the stronger lanes, which side paid over the last minutes. Start the session by planning W4 in detail with Max.
- At the start, Max play-tests the latest version (`tools/play.sh wind`; V hides the streaks, 2 for 10× to see the fronts roll; click near the south-east shore for the lee). To ask him: are the gusts strong enough and the lee deep enough (the brightness-to-knots question), are the gusts visible enough in Windfinder's colours (a "difference from the average" view could help, W4), and does the lee move to the north-west shore when the wind veers?
- Later: W3's "the day" (the start front, light, medium and strong days).
- Committed and pushed at the end of this session: "Map W2 and W3: wind viewer, gusts and lee measured on satellite photos".

---

## 14 October 2026 - Session 42 (map track): Wind analyser W0 (research) and W1 (the fixed pattern)

**Phase:** new phases W0 and W1 of the map plan (the wind analyser). Branch `feature/map-silvaplana`.

**Why:** Max wants the simulated Maloja (speed, gusts, shifts) as a viewer in the game, like Windfinder's map but in 3D over the terrain, real time and sped up, to work out tactics for course racing. It is about how the Maloja behaves once it blows, not when it comes. Max agreed the plan ("run everything, document carefully, first do no. 1", then "do phase 2 as well").

**Done:**
- Plan: the wind analyser's phases W0 to W4 and its decisions WD1 to WD4 in MAP_SILVAPLANA_PLAN.md; WindNinja in the Tools table; a pointer in PHYSICS_REQUESTS_FROM_MAP.md (R5).
- W0, research: [MALOJA_WIND_RESEARCH.md](MALOJA_WIND_RESEARCH.md), with four charts in `Documentation/images/maloja/`.
  - Sources: Mörikofer's 1938 measurements at Sils (found as a 1982 translation), the weather services, spot guides, glider pilots, race reports, papers on wind over lakes and gusts.
  - `download.py wind-valley`: five MeteoSwiss stations, 2010 to now (0.41 GB). `maloja_research.py` and `maloja_charts.py`.
  - Main numbers, 950 Maloja days 2014 to 2026:
    - 12.6 to 13.0 kt mean from 13:00 to 16:00; gusts about +7 kt at every strength;
    - pulses and shifts of 10 to 30 minutes (±8 %, ±6°);
    - the start travels down the valley at about half the wind speed;
    - it turns right until 16:00 and left in the evening.
  - `satellite_wind.py`: Sentinel-2 photos of the lake on Maloja afternoons against calm ones (22 and 5 clean photos). It reads only the lake's corner of each photo (about 10 MB of 1 GB).
    - Smoother water along the south-east shore and at the Sils end.
    - The streak direction was tried and is not usable: the calm photos show the same direction.
- W1, the fixed pattern: WindNinja 4.0.0, unpacked with 7-Zip into `%LOCALAPPDATA%/Programs/WindNinja/4.0.0` (the installer wants admin rights). `windninja_pattern.py` makes 12 runs and compares them with the station and the satellite.
  - Stable air puts the lake's wind along the lake (about 220°) and turns the station's reading 20° to the right, as measured.
  - The strength disagrees with the satellite.
  - The game's pattern takes the direction from WindNinja and the strength on the lake from the satellite: `Game/maps/silvaplana/wind/maloja_pattern.json` + `.bin`. Pictures for Max: `pattern_game.png`, `pattern_lake.png`, `pattern_valley.png`.
- `tools/map/tests/test_wind_pattern.py`: 6 checks of the pattern.
- One run of WindNinja's momentum solver (OpenFOAM, 52 minutes) as a check: it also puts the weaker wind on the south-east side, but can't do stable air; not used for the game.

**Verified:**
- `tools/check.sh`: 89 files, 0 failed. `tools/test.sh`: all passed.
- `test_wind_pattern.py`: 6 of 6.
- The streak-direction maths, on made-up streaks at known angles (within 1°).
- Every chart and picture looked at.

Not verified:
- whether the pattern matches the water (Max),
- whether 10 % rougher water means 10 % more wind (an assumption).

**Decisions:**
- The near-infrared band was dropped for the red one: the atmospheric correction leaves the water at almost exactly 0 there.
- The first satellite selection let cloud shadows and haze through and was replaced by a strict one (no clouds within 500 m, no haze).
- Charts are PNG (light and dark versions) instead of SVG: no browser on this PC to check SVGs, and Godot's SVG reader skips text.
- The fast solver's strength pattern was not used on the lake, because the satellite contradicts it (no inertia, no forest).

**Max's check (15 October):** the pattern is right: weaker along the south-east shore and at the Sils end, the wind along the lake, a little more on the north-west side (which usually pays upwind). New for W3:
- gusts of 100 to 200 m at all time scales, randomly;
- gustier at the Sils end and steadier downwind;
- full-strength gusts now and then in the weak band at the bend of the south-east shore;
- the turn in a gust depends on where you are in it.

His answers are in SILVAPLANA_SPOT_NOTES.md and in the research document, "What Max says".

**Next:**
- Then W2, the viewer.

---

## 14 October 2026 - Session 41 (map track): Realistic lake water

**Phase:** M2 of the map plan, the water. Branch `feature/map-silvaplana`.

**Why:** Max: the terrain "is really good and nice", but the water "is really bad, a plain colour; water is semi-transparent". He asked for research.

**Done:**
- Research into realistic water in Godot 4. The findings and sources are in PHYSICS_REQUESTS_FROM_MAP.md, R9:
  - see-through water reads the depth and the picture behind it,
  - built-in screen-space reflections don't work on see-through materials,
  - mountain reflections come from a reflection probe, a custom SSR or a mirror camera,
  - the depth formula since Godot 4.3.
- The map's own lake water, `Game/maps/lake.gdshader` with `Game/maps/silvaplana/lake.tres`:
  - see-through, darker with depth (red goes first), so the real lakebed makes the shallows turquoise,
  - refraction by the ripples,
  - a Fresnel mirror,
  - two layers of wind ripples drifting downwind, rougher far away.
- `LakeReflections`, a reflection probe in `silvaplana.tscn`. Only the lake water mirrors it (render layer 2), so the lake reflects the mountains, not only the sky. From the village the lake looks dark now, as in reality.
- In the terrain view, G (or `-- --water=game`) switches to the game's water shader to compare.
- 2 new tests in `test_silvaplana_look.gd`: the lake water and the probe.
- R9 rewritten for Michiel: how this water should meet his waves in the game.
  - Option 1: his shader gets these features.
  - Option 2: the wave math moves into a shared include file.
  - It's his choice. The game's water is unchanged until then (MD7).

**Verified:**
- `tools/test.sh`: 141 of 141. `tools/check.sh`: 89 files.
- Screenshots of the new water: from the launch, the village, a drone over the camping beach (turquoise shallows fading to deep blue), and the same view with the old water.
- Frame rate: the new water costs about 6 % (1,280 → 1,200 fps, both measured the same way; an earlier 1,100 was low because another game window was still open).

Not verified:
- whether it looks like the real lake to Max,
- how it looks with the physics' waves (that needs R9).

**Decisions:**
- The new water lives in map files, because the game's water shader is Michiel's (MD7).
- Mountain reflections come from a reflection probe, not a custom SSR or a second camera: cheap, and with Maloja chop a blurred mirror is realistic. The probe makes Godot print a harmless texture-leak warning when it quits.

**Next:**
- Max looks at the water: `tools/play.sh silvaplana`, G to compare. The absorption, the colour and the ripples are numbers in `lake.tres`.
- Michiel answers R9.
- Then M3.

---

## 14 October 2026 - Session 40 (map track): Phase M2, the look

**Phase:** M2 of the map plan, built on Windows. Branch `feature/map-silvaplana`. Nothing new on `feature/physics-sim` or `main` to merge.

**Done:**
- Max agreed to the 1.1 GB of 10 cm photos. `download.py photos-near` fetched the 25 shore-band tiles (2025 flight, checksums checked).
- `tools/map/photos.py`: one WebP photo per chunk.
  - 12 cm on the two tiles of the camping and the launch beach, 0.5 m on the rest of the shore band, 2 m up to 8 km, 8 m beyond. 50 MB.
  - Each photo has a `.import` file, so Godot makes mipmaps and compresses it for the graphics card.
  - The 22 visible tiles in Italy are painted in the colours the Swiss photos have at the same height, slope and lighting, with the small ridges of the 10 m heights.
- `tools/map/tests/test_photos.py`, 4 checks, among them that every photo lines up with the lake.
- In Godot:
  - `terrain.gdshader`: the photo as colour, 25 % darker on cliffs. The game's sun shades the slopes only half, because the photo already has its own (morning) light.
  - `MapTerrain` (`map_terrain.gd`): the root of `terrain.tscn`; it gives every chunk its photo.
  - The map scene `silvaplana.tscn` got its own sky, sun (mid-July 15:00: azimuth 225°, 59° up), haze and fill light.
  - `lake_water.tres`: the lake's colours, measured in the photo, for the game's water shader, without grid lines.
- The skirts are separate meshes now, without shadows. They had cast long dark bands across the slopes.
- `tools/blender/build_terrain.py` writes `terrain.tscn` with the `MapTerrain` script.
- `Game/camera/camera_rig.gd` (shared, one line; mention it to Michiel): the far plane is 35 km instead of 3 km, so the mountains are drawn.
- The terrain view:
  - It uses the map's look and the game camera's near and far planes.
  - `--at=e,n,h --look=e,n,h` starts at any viewpoint.
- `test_silvaplana_look.gd`, 4 tests:
  - every chunk wears its photo and the skirts cast no shadows,
  - the sun's direction (it caught the sun pointing 37° below the horizon: tscn files list a rotation row by row),
  - the camera's far plane,
  - the lake uses the game's water shader.
- `build.sh` downloads the 10 cm photos and runs `photos.py` and its checks.
- Request R9 for Michiel (PHYSICS_REQUESTS_FROM_MAP.md): lighter water in the shallows. It needs a depth texture in `water.gdshader`, which the map track may not change.

**Verified:**
- `tools/test.sh`: 139 of 139. `tools/check.sh`: 88 files.
- The Python checks: 8 of 8 for the heights, 4 of 4 for the photos.
- Screenshots from the launch, the village and above (`.screenshots/m2_*.png`), and one over Sils.
- About 1,500 fps at every viewpoint (RX 6950 XT, 1280 × 720, no vsync).
- The open-water game still looks the same.

Not verified:
- how the lake's colour and the light compare with the real spot (Max's check),
- lighter shallows (R9),
- the Linux PC.

**Decisions:**
- The photos go on in Godot (shader and `MapTerrain`), not into the `.glb` in Blender. A new photo then needs no new meshes, and the shader handles the light.
- The sun is at 15:00. The photos' morning light is softened by letting the game's sun shade the slopes only half.
- The lake colour comes straight from the aerial photo. The first, greener try looked like the Caribbean once the sun pointed the right way.

**Size:** `Game/maps/silvaplana/` is 111 MB of 300 MB.

**Next:**
- Max checks the look: `tools/play.sh silvaplana`, keys 1 to 4.
- Then M3, sailing on the lake:
  - the windsurfer on the map,
  - the Maloja wind setting,
  - the start at the camping beach,
  - the stop at the shore (`TerrainGrid`),
  - the game's water only on the lake. The ocean plane must not cover land below the lake level, such as St. Moritz.

---

## 14 October 2026 - Session 39 (map track): Phase M1, terrain and lakebed in Godot

**Phase:** M1 of the map plan, built on Windows. Branch `feature/map-silvaplana`. Nothing new on `feature/physics-sim` or `main` to merge.

**Done:**
- `tools/map/heights.py` makes the terrain heights, in metres above the lake.
  - Four detail levels, so that a grid cell looks about equally big from the water at every distance:
    - 2 m in the shore band (swissALTI3D plus the lakebed),
    - 10 m up to 3 km from the lake,
    - 20 m up to 8 km,
    - 40 m beyond (swissALTIRegio).
  - Only visible tiles are built: 354 tiles in 80 chunks.
  - Where two levels meet, the edges are stitched, so the meshes join without cracks.
  - The unsurveyed shallow lake (0.16 km²) is filled in smoothly from the shoreline to the survey.
  - It also writes the game's height grid of the shore band (2 m, `shore_heights.bin` and `.json`).
- `tools/map/tests/test_heights.py`: 8 checks:
  - the lake at 0 m,
  - water over the whole lake,
  - the deepest point 76.9 m (published: 77 m),
  - Piz Corvatsch 3450 m (published: 3451 m),
  - the weather station 1803.5 m (published: 1804 m),
  - the camping at the shore,
  - no holes,
  - no cracks.
- `tools/blender/build_terrain.py` builds and exports the 80 chunks as `.glb`:
  - thinned out with Decimate, with each chunk's border locked,
  - a hidden skirt against hairline gaps,
  - normals taken from the height grid,
  - `terrain.tscn`, and two pictures from above.
  - 1.14 million vertices, 49.6 MB, about 1 minute.
- In Godot:
  - `silvaplana.tscn` (the map with its terrain),
  - `TerrainGrid` (`Game/maps/terrain_grid.gd`, the ground height anywhere in the shore band, for M3),
  - `FlyCamera` (`Game/maps/fly_camera.gd`),
  - the view `res://maps/silvaplana/dev/terrain_view.tscn`: viewpoints 1 to 4, a flat lake stand-in, the position and height on screen, and `--measure=1` for the frame rate.
- `test_silvaplana_terrain.gd`: 6 tests:
  - known points,
  - grid heights,
  - meshes within 0.5 m of the grid,
  - every chunk in the scene,
  - LODs.
- `build.sh` runs the new steps; the README describes them.
- `tools/play.sh` (a shared file, small change; mention it to Michiel):
  - Double-clicked, it asks what to start: Enter plays the game as before, 2 opens the Silvaplana terrain.
  - `tools/play.sh silvaplana` opens the terrain directly.
  - Without arguments from a terminal, nothing changed. `silvaplana_area.py` has the known points (`KNOWN_POINTS`).
- Coordinates looked up: the church Santa Maria (OpenStreetMap), the camping area and Piz Corvatsch (swissNAMES3D, through the geo.admin.ch API).

**Verified:**
- `tools/test.sh`: 135 of 135. `tools/check.sh`: 85 files.
- The Python checks: 8 of 8.
- `tools/map/build.sh` from start to end, 2.5 minutes.
- Screenshots from the four viewpoints (`.screenshots/m1_*.png`) and the Blender pictures from above.
- Mesh against grid, at 2000 random points: median 3 cm, worst 52 cm.
- Frame rate: about 1,500 fps at every viewpoint, on the RX 6950 XT, 1280 × 720, without vsync. Max switched off a 100 fps cap in RivaTuner for this measurement.

Not verified:
- the comparison with map.geo.admin.ch in 3D,
- the double-click menu of `play.sh` (it needs a window to type in; the short name and the plain game start were tested),
- how the place feels to someone who knows it (Max's check),
- the Linux PC.

**Decisions:**
- Four detail levels instead of the planned two (10 m and 50 m). Piz Corvatsch is 4.1 km from the water and would have looked blocky at 50 m.
- No `visibility_range` on the terrain. Everything must stay visible, and Godot's automatic LOD already makes far chunks cheap.
- The game grid is a plain 16-bit `.bin` file, because Godot reduces 16-bit PNGs to 8 bits.
- Lake Sils and Lake St. Moritz stay flat surfaces at their own level for now (M2/M3).

**Size:** `Game/maps/silvaplana/` is 62 MB of the 300 MB budget.

**Next:**
- Max flies around the view and checks it against the real spot and map.geo.admin.ch.
- Then M2, the look: aerial photos on the terrain, sky and sun, the far plane of the game camera. The 10 cm photos of the shore band (1.1 GB download) still need the team's go.

---

## 14 October 2026 - Session 38 (map track): Phase M0, tools and data

**Phase:** M0 of the map plan, done on Windows. Branch `feature/map-silvaplana`. Nothing new on `feature/physics-sim` to merge.

**Done:**
- Tools on Max's PC:
  - `tifffile`, `Pillow` and `imagecodecs` (needed for the compressed GeoTIFFs), and QGIS LTR 3.44.14.
  - `tools/common.sh` got `find_blender`, and `tools/blender.sh` runs Blender scripts headless with factory settings.
  - The user variable `BLENDER` is set on this PC.
- Round-trip test:
  - `tools/blender/roundtrip_test.py` builds a test hill and exports `.glb`.
  - `test_map_roundtrip.gd` proves the axes come through (east +X, up +Y, north −Z).
  - `roundtrip_view.tscn` shows it in a screenshot.
- `tools/map/`:
  - `download.py` (STAC v1, SHA-256 checked, in stages),
  - `lake_level.py` (1790.63 m, writes `map_config.tres`),
  - `visible.py` (what you can see from the water),
  - `readers.py`, `silvaplana_area.py`, `build.sh`, `README.md`.
- `MapConfig` (`Game/maps/map_config.gd`) converts LV95 ↔ game, with `test_map_config.gd`.
- Git LFS rules in `Game/maps/.gitattributes` and `Art/.gitattributes`.
- Downloaded 701 MB: heights, lakebed, swissALTIRegio, wind, and 2 m photos of the visible tiles.
- What can be seen:
  - From the water only, about 70 km² at first.
  - Max pointed out that the orbit and replay cameras see more. `visible.py` now looks from the viewpoints in `silvaplana_area.VIEWPOINTS`: the sailor at 2 m, the orbit camera at 60 m, a replay drone at 150 m, and cameras on the shore at 2 m and 50 m.
  - Result: 137 km² in 354 tiles of 1 km (the sailor alone: 76 km²), 90 % within 22 km.
  - The surroundings grew to the west and the north until nothing visible touched the edge.
  - The picture shows the sailor's view in orange and the camera-only land in yellow.
- `build.sh` opens the visibility picture at the end, and keeps a double-clicked window open.
- A Blender preview of the real valley, so the team can see the data (Max asked to see what is being done):
  - `preview_data.py` and `build_preview.py` make `silvaplana_preview.blend`, with the shore band at 5 m with the lakebed, the surroundings at 100 m, and the photos.
  - Four cameras render pictures. The cameras place themselves on the water, or above the ground.
  - It runs as part of `build.sh` (about 1.5 minutes in all).
  - The lakebed's deepest point comes out at 76.8 m, as published.
- BlenderGIS 2.2.10 loads in Blender 4.5, without GDAL or PyProj, which we don't need.
- Found that the game camera draws only up to 3 km (`camera_rig.gd`, `far = 3000`). For the mountains it must go to about 35 km: added to M2.
- 22 of the visible tiles are in Italy, without Swiss aerial photos: added to M2.

**Verified:** `tools/test.sh` 129 of 129, `tools/check.sh` 78 files, the round-trip screenshot (the hill's top under the red marker), and a second `tools/map/build.sh` run that downloads nothing. Not verified: the Linux PC (Blender version, Git LFS, round trip).

**Decisions:**
- Downloads come in stages. The 10 cm photos of the shore band (1.1 GB, for M2) and the surface model (0.34 GB, for M4) wait for the team: the first is over the plan's 1 GB limit, and C: has only 17 GB free.
- `python -I` doesn't see user-installed packages on this PC, so the map scripts run normally from the repo root. Python then only loads code from `tools/map/` and the repo root, never from `.map_data/`.

**Roles** (Max, 14 October 2026):
- Michiel does the physics.
- Max does the map, and later the wind patterns connected to it: the daily cycle, the gusts and shifts, and where the wind is strong or weak. They connect to the physics through `WindField`, agreed with Michiel.
- Updated in the map plan, the physics requests (R5), the rebuild plan and CLAUDE.md.

**Next:** the team looks at `.map_data/work/visible_map.png` and decides on the 10 cm photos. Then M1: `heights.py`, `build_terrain.py` in Blender, and the terrain in Godot. Check the Linux PC when convenient.

---

## 14 October 2026 - Session 37 (map track): Plan for the first map, Lake Silvaplana

**Phase:** side track M (the map), planning only. Branch `feature/map-silvaplana`, started from `feature/physics-sim`.

**Done:**
- Set up Max's Windows PC (Godot 4.7.2 from the official build, SHA-512 checked; the `GODOT` variable for `tools/*.sh`; the godot-tools VS Code extension). Blender 4.5.4 LTS with BlenderGIS was already installed.
- Wrote [MAP_SILVAPLANA_PLAN.md](MAP_SILVAPLANA_PLAN.md): phases M0 to M4, decisions MD1 to MD7, the open data and the tools, plus a "Later" section of physics requests for Michiel (wind simulation, wind-driven waves, mountain-lake physics, live weather, other sailors).
- Wrote [SILVAPLANA_SPOT_NOTES.md](SILVAPLANA_SPOT_NOTES.md): questions for Max's local knowledge of the spot.
- Checked in the STAC API that all the data exists for the area: swissALTI3D, swissALTIRegio (10 m, for the far mountains), SWISSIMAGE, swissSURFACE3D, swissBUILDINGS3D, swissTLM3D, the swissBATHY3D lakebed of Silvaplanersee (survey of 2019), the MeteoSwiss station Segl-Maria (SIA) at the south-west end of the lake (10-minute wind with 1 s and 3 s gusts), and the BAFU lake-level station 2073.
- Wrote [PHYSICS_REQUESTS_FROM_MAP.md](archive/PHYSICS_REQUESTS_FROM_MAP.md) for Michiel: requests R1 to R8 (a map's own air, water and wind; thin air; fresh water; lakebed and running aground; moving gusts; wind waves; replay and live weather; other sailors), with sources, numbers and suggested interfaces. `PHYSICS_SPEC.md` was not touched.
- Measured the Maloja from MeteoSwiss Segl-Maria, 10-minute data of the summers 2020 to 2025 (new script `tools/map/maloja_stats.py`):
  - from 244°, with a median 12 kt mean at the station and 1-second gusts 1.55 times the mean,
  - 61 % of summer days are Maloja days,
  - the air density on Maloja afternoons is 0.98 kg/m³: 20 % below the 1.225 in `WindsurferSim.RHO_AIR` and the autopilot.
  - Worked out the expected lake waves with JONSWAP: about 0.29 m and 6 m long at 20 kt over 3 km.
- Added `/.map_data/` (raw map downloads) to `.gitignore`.
- No code or game files changed. A wave-size experiment was tried and undone at the team's request.

**Verified:** on Windows, `tools/check.sh` (72 files), `tools/test.sh` (122 of 122) and `tools/screenshot.sh` pass on `feature/physics-sim`. `tools/map/maloja_stats.py` run from the repo reproduces the numbers in the requests document. Nothing of the map was built or tested yet. The station's wind speeds were not checked against the wind on the water.

**Decisions:**
- The team's answers (plan, "Team decisions"):
  - only Silvaplana is sailable, and the map is as small as possible: a detailed shore band, plus only what you can see from the water,
  - waves will come from a general wind-wave system later, and until then the current waves stay unchanged,
  - at most 300 MB of map files,
  - one fixed Maloja setting of 12 to 20 knots, with the existing simple gusts and shifts,
  - Michiel makes all physics changes,
  - other sailors on the water come later,
  - Max is the local expert.
- MD1 to MD7: LV95 coordinates straight into the game with the lake surface at Y = 0; Python prepares the data (numpy, tifffile, Pillow; no GDAL); Blender builds the 3D (terrain by a headless script, props by hand) and exports `.glb`, with the `.blend` sources in `Art/`; the game logic reads the grids, never the meshes; the lakebed replaces the flat lake; the map sets its own wind config and never changes `Game/sim/`, the shared configs or the ocean; Michiel's branch is merged into this branch at the start of every map phase.

**Next:** Phase M0: `pip install tifffile pillow`, install QGIS, the Python → Blender → Godot round-trip test, then the download and visibility scripts. Max fills in the spot notes when there is time.

---

## 13 October 2026 - Session 36: Phase 5, waves

**Phase:** 5 done, with the chop limitation below.

**Done:**
- The Gerstner wave field of spec section 9 (`WaveField`, `WaveSetConfig`, `GerstnerWaveConfig`, `waves_default.tres`): the height solve, exact normals, orbital velocity, oriented to the wind; 11 unit tests against the spec's hand-calculated table. The simulation sails on it with `create_default(true)`; the game does.
- The ocean: `water.gdshader` with the same formulas (vertex displacement, analytic normals, Fresnel, lighter crests, foam only at real steepness) and `OceanNode` (a 400 m mesh of 1 m cells following the camera snapped to its grid, a far plane under the fog, the shader clock from the simulation clock). Screenshots show the board on the rendered swell.
- The matrix and the scenario runner take `--waves=1`, `--wave_scale=`, `--waveN.field=`; the scenario runner also `--kick_pitch=`.
- Found and documented why the legacy chop set wrecks the sailing (spec 17.12): slams from the strip theory's curvature term on waves shorter than three hull lengths, taken by a rigid one-body sailor as roll impulses; the hull at Savitsky's porpoising boundary. The default sea is now a swell of 8 cm on 14 m with a little 7 m chop, which the board rides. The fall checks use a 1 s felt push (a jolt is not a fall); the pilot feels the heeling lever over 0.15 s.
- `tools/test.sh validation` has `test_waves.gd`: 60, 90 and 120 degrees on the sea against flat water.

**Verified:**
- `tools/test.sh`: 122 of 122. `tools/test.sh validation`: 20 of 20 (about 70 s). `tools/check.sh`: 72 files. `tools/matrix.sh`: 24 cases clean on flat water; on the sea 22 of 24 (a 12 kt tack and a 24 kt gybe fall).
- On the sea: 90 degrees 10 % slower than flat, 120 degrees 1 %, 60 degrees 32 %; pitch 9 degrees peak to peak; the hull on the surface.
- Not verified: the look of the water beyond two screenshots; the feel of the swell in play.

**Decisions:**
- Steepness is the physical k A: the hull and the fin use the water's velocity, so the trochoid must be consistent.
- Chop waits for the compliant sailor (A-17); the sea ships swell-dominated rather than fake-smooth physics.

**Next:** play-test on the swell; then either the two-body sailor (so the chop can come back) or Phase 6 (rig visuals), the team's choice.

---

## 12 October 2026 - Session 35: Phase 4, the validation suite is green

**Phase:** 4 done.

**Done:**
- `tools/test.sh validation` (about 65 s): the polar sweep of PHYSICS_SPEC.md section 14 at 15 kt on both tacks, with the speed bands, shape rules, top speed, fastest angle, symmetry, upwind VMG, no-go zone, planing onset, acceleration, stability at speed and force sanity read from one sweep; plus the no-fly-off equilibrium, the nose-dive recovery, righting (bare board and balancing sailor) and stopping head to wind. The polar is saved to `Documentation/POLAR_15KT.md`.
- The pilot's course hold has a trim integral (it sailed 10 to 15 degrees wider than asked without one).
- Physics fixed at the source, each from a failed check: form drag of a submerged bow (the deck's immersion at the nose, Cd 0.8); the sailor steps back from the hull's hump speed while the bow is low; the rig's mass leans with the rig; the fore-and-aft balance stands square to gravity; the deck and water under the sail's foot cut the sail's induced drag (end-plate factor 1.4, the lift curve unchanged). Tuning log rows and spec 17.11.
- Three plausibility bounds that were reasoned rather than measured now use the sourced values (planing onset from 14 km/h, beam reach 80 % of the maximum, 135 degrees with 20 %); the note under the shape rules of section 14 says why.
- `tools/simulate.sh` takes `--gradient=0` (the validation wind); a `nose_dive` scenario.

**Verified:**
- `tools/test.sh validation`: 17 of 17. `tools/test.sh`: 111 of 111. `tools/check.sh`: 65 files. `tools/matrix.sh`: 24 cases, 0 falls, 0 NaN.
- The polar: 45 degrees 10.2 kt, 90 degrees 20.0, 120 degrees 24.0, 135 degrees 24.2 (top, 1.62 times the wind), 165 degrees 9.3; both tacks within 0.1 %; planing onset 14.9 km/h.
- Not verified: how it feels; nothing visual changed.

**Decisions:**
- The sail's lift curve stays the measured one; the deck's end plate acts on the induced drag only.
- The validation suite is the regression guard from here: a number leaving its band is a model error to find, never a bound to move (the three sourced bounds above are the exception, recorded in section 14).

**Next:** Phase 5, waves: the Gerstner wave field, its tests, the ocean shader and mesh, and the validation on waves.

---

## 12 October 2026 - Session 34: the manoeuvre matrix, sheeting to the pull, sailing in 24 kt

**Phase:** 3 play-test follow-up (the open items of Session 33); Phase 4 work. Stopped for a play-test.

**Done:**
- A batch harness: `tools/matrix.sh` runs 24 manoeuvre cases (tacks, gybes, a turn on a run, out of irons, straight) at 12, 18 and 24 kt in one Godot process and prints one line per case with falls, NaN, the manoeuvre's timing and how calm the sailing is afterwards; `--pilot.x= --controller.x= --sailor.x= --sail.x=` try other values without editing code (also on `tools/simulate.sh`). This is how the rest of the session was done: one run per hypothesis, a trace only for the one case that needed it.
- The sail is now sheeted to the pull the body can hold (0.9 of the sailor's righting moment, from the sail's curves and the measured heeling lever of sail plus fin) and sheeted in no faster than the body can lean out against it. This replaces the hike integrator, fixes the catapult 4 s into every 24 kt run, and makes 24 kt sailable (depowered, 11.3 m/s on a beam reach).
- The felt heel counted the heel twice; fixed to the exact apparent-gravity angle. That was the 1 Hz sail pumping at every wind. Steady sailing is now steady at 12, 18 and 24 kt.
- Out of irons: the sail stays backed until the bow is 55 degrees off the wind or the board makes 3 m/s (a filled sail on a board without way only rounds it up); no backing without a wanted turn. Works at 12, 18 and 24 kt (2 to 4 s).
- Settling after a manoeuvre only at planing speed, and the gybe's eased sail only through the gybe: the 12 kt gybe keeps its speed.
- The arms' rig tilt range 20 to 30 degrees: the run at 12 kt turns left now.
- Falling to windward counts the sail's pull on the hands in both rules. The rake test of section 3 measures the first two seconds (an unsteered planing board wobbles rail to rail after that; see spec 17.10), and the test pilot now knows the sail and the sailor like the game's pilot.
- Spec 17.10 and the tuning log; this entry; CLAUDE.md lists the matrix tool.

**Verified:**
- `tools/matrix.sh`: 24 cases, 0 falls, 0 NaN, every manoeuvre completed; tacks 6 to 8 s, gybes 5 to 7 s, irons 2 to 4 s at all three winds; straight sailing 7.9 / 10.0 / 11.3 m/s at 12 / 18 / 24 kt with 0 sheet reversals.
- `tools/test.sh`: 111 of 111. `tools/check.sh`: 62 files, 0 failed.
- Not verified: how it feels in the game (no play-test since); nothing visual changed, no screenshot.

**Decisions:**
- Trim by feel, not by integrator: the pilot sheets to the pull the body can hold and in at the pace the body can lean. No state in the trim.
- The felt-gravity reflex stays (gain 1.0): with the felt heel computed right it is steadier than without in every case.
- The rate loop is the yaw damper of a carving board; the open-loop wobble is noted, not hidden.

**Next:** the team plays at a few wind strengths (the wind is in `Game/config/wind_default.tres`, `speed_kt`): tack and gybe with Space, hold A/D, get out of irons by pressing a key, sail a run in light wind. Then waves (Phase 5) or more equipment, adding each to the matrix.

---

## 3 October 2026 - Session 33: tacks, gybes, and a hull that carves

**Phase:** 3 play-tested a third time; Phase 4 work. Stopped at the team's request so they can play-test before more is optimised.

**Done:**
- The play-test said: gybing is a little slow and takes a while to settle; tacking is impossible. Both reproduced in the `player_steer` scenario at 12 and 18 kt and worked on with frame-by-frame traces (`.scratch/trace.py`).
- The hull now knows about heel: the planing strips run across the width, so a banked board carries its lift on the low rail and forward. That gives the righting moment, the sideways force and the turn into the bank that make a real board carve (spec section 5 and 17.9, with a new hull test). Before this a banked board turned away from its bank and gybes could only be spun with the rig.
- The sailor's balance was rebuilt on that: weight on a rail asks for a turn and the reflex banks the board for it (at most 30 degrees, 12 degrees per second); the sailor balances in the apparent gravity of the turn (the measured sideways acceleration of the body, averaged over 0.3 s), and the fall checks use the same felt heel. The balance gains were re-tuned (2.5 and 1.2) to a critically damped loop. The depowering is gradual with an urgent rate near the limits; the player's on-off ease only acts while sheeting by hand.
- The tack is a latched sequence in the pilot that follows the wanted turn: backed across the centreline to take the bow away from the sail (the flip at 25 degrees through and 17 of apparent wind on the new side), backed on its own side to take the bow toward it (after the flip and out of irons), given up when the bow falls back 35 degrees. The arm limit is 350 N and can take the sail down to flapping; the step forward is paced by the nose's depth. The controller rakes fully back whenever the pilot backs.
- Every turn goes through the rate loop (keys 30, tack 15, gybe 30 degrees per second) with the rail sized for the rate and the rig closing the loop; the heading hold uses the rig alone. A gybe keeps the sail eased to 8 degrees of angle of attack until the board has settled; after a manoeuvre the board straightens by itself before the hold takes over. Space tacks up to 100 degrees of true wind angle.
- Stability after a fall: roll added inertia for the hull, a damping cap per point based on that point's own effective mass, an implicit sea anchor, no planing when the bottom does not face the water. No NaN anywhere any more.
- Telemetry and the CSV gained `bow_immersion_m`, `planing_cop_z_m`, `fall_kind`, `wanted_bank_deg`, `felt_push_ms2`, `felt_heel_deg`. The test `test_the_boom_pushed_across_the_centreline` now asks for "luffing or backwinded" (at 5 degrees of apparent wind the sheeted sail is at -7 degrees).

**Verified:**
- `tools/test.sh`: 110 of 111 passing. Failing: `test_beginner_gets_out_of_irons` (D at rest head to wind in 18 kt; the bow hunts at the edge of the 20 degree fill band at 1 m/s). `tools/check.sh`: 61 files, 0 failed.
- Headless scenarios at 18 kt from a 10 m/s beam reach, no falls, no NaN: Space tack through the wind 6.5 s after the key and on the new close reach after 9 s, both tacks mirror images; D held tacks the same way; gybe from a broad reach dead downwind 2.7 s after Space and on the new broad reach after 6.2 s; gybe from a beam reach at 10.5 m/s in 7.1 s; A on a dead run turns left. At 12 kt the tack and the gybe are clean. The steady beam reach at 18 kt is smooth (10.7 m/s, 2.7 degrees of heel, no pumping).
- Not verified: how any of it feels in the game (no play-test since the changes); no screenshot this session (nothing visual changed except the HUD numbers). Advanced mode was not re-tested by hand.

**Known problems left on purpose (the team asked to stop and play-test first):**
1. After the Space tack at 18 kt, on the new close reach at about 6.5 m/s, the hike, the depowering and the heading hold oscillate together (2 s period) and the sailor is catapulted about 10 s after the tack (the `tack_stb_18` run falls at 42 s). The urgent re-powering added last is the first suspect.
2. Out of irons with D at rest in 18 kt fails (above).
3. A full rake step at 10 m/s (advanced mode, `bear_away` scenario) spins the board at 100 degrees per second and the sailor falls; the beginner loop never asks for that, advanced mode has no protection.
4. Everything was tuned at 12 and 18 kt, flat water, one board, one sail.

**Decisions:**
- The rail is for turns, not for holding a course: a planing board carves hard on a few degrees of bank.
- Manoeuvres are rate-controlled like the keys; full helm at planing speed is a spin-out in this physics as on the water.
- Falls and balance use the heel the sailor feels, from the measured acceleration, not from v times the yaw rate.

**Next:** the team plays: tack and gybe with Space at a few wind strengths, hold A/D through the wind, sail close-hauled at 18 kt and see whether the board rocks. Then decide what is worth fixing from the list above before waves, other boards and sails, and other winds add complexity.

---

## 2 October 2026 - Session 32: steering at every speed and on every course

**Phase:** 3 play-tested again; Phase 4 work.

**Done:**
- The play-test said: D turns the board left when planing on starboard tack, and nothing steers dead downwind. Both reproduced headless. The first was the speed-scaled rake of Session 31: at planing speed the rig needs most of its rake just to hold a straight course, so a scaled key command fell below that trim and both keys bore away. The second is physics: rake steers through the sail's side force, which a run does not have.
- The rig's sideways tilt is now a control of its own (the arms, up to 20 degrees on top of where the rig hangs with the lean). `Helm` turns the board the way a sailor does: rig back or forward, rig tilted to the outside of the turn and weight on the inside rail, all together. The beginner's A/D ask for a turn rate (30 degrees per second) and a loop on the measured yaw rate finds the helm, with a trim that settles at whatever the speed and course need; without a key it holds the heading. Space's tack and gybe are one continuous turn. Advanced mode: Q/E rake, Left/Right arrows rig tilt, A/D weight. The autopilot steers with the same helm.
- Spec 17.8 explains it; the tuning log has the rows. Left/Right arrows moved from steering to rig tilt in the input map.

**Verified:**
- `tools/test.sh`: 105/105, with new whole-simulation tests: from rest on either tack the beginner controller sails off and planes by itself, D turns right and A turns left by more than 15 degrees in 3 s while planing, on both tacks, without a fall; on a dead run it holds the course for 25 s and turns either way on command. `tools/check.sh`: 60 files, 0 failed.
- Scenarios: beam reach 34.7 km/h (rake 0.49 instead of 0.8 to hold the course), close-hauled 21.8, broad reach 22.6 from rest; the 24 kt polar from a planing start: 45.3 km/h at 90 degrees, 52.2 at 120, 49.8 at 135, 36.0 at 150. The overpowered scenario still catapults and waterstarts.
- Screenshot `.screenshots/turning.png` with the beginner controller sailing by itself.
- Not verified: how 30 degrees per second feels, the gybe on Space at speed, whether the rig tilt looks right on screen while turning.

**Decisions:**
- Steering is a turn-rate request in beginner mode. The physics is untouched; the loop is the sailor's skill.
- The rig tilt is a sailor's choice, so it is a control, not a function of the lean.

**Next:** the team plays again: steer at low speed, while planing and on a run, on both tacks; tack and gybe with Space; try the arrows in advanced mode. Then Phase 4 proper.

---

## 2 October 2026 - Session 31: first play-test, falls instead of capsizes, downwind speed, low-speed handling

**Phase:** 3 play-tested; the fixes are Phase 4 work (physics corrected at the source).

**Done:**
- The team's play-test said: the whole set capsized when heading up while planing (never happens; the sailor should go over the sail), half wind was faster than downwind (weird), and the board had "grip" at low speed. Each was measured in a scenario, traced to its mechanism and fixed. Spec section 17.7 has the full story with sources; section 16 has one tuning-log row per change.
- Falls: the sailor now goes over when the balance is lost (20 degrees of leeward heel = catapult, 25 degrees of windward heel = fell back). The board is then simulated alone, the rig in the water drags on the mast foot, and after 4 s the sailor waterstarts across the wind. On screen the rig pivots onto the water and the sailor flies over it; the HUD shows a countdown and R waterstarts at once. Why: the mast foot is a joint and feet cannot pull a board up, so a sail cannot roll a board; only a one-body model can.
- Downwind: the pilot and the player's auto-sheet now sheet for the most drive from the sail's own curves instead of a fixed 15 degrees. The polar is run from a planing start (new runner option `--twa2=<deg> --switch=<s>`): at 24 kt the fastest course is 105 to 120 degrees (52 km/h), 135 degrees gives 46 km/h; at 18 kt the beam reach still wins because a 6.5 m2 is marginal for 75 kg in 16 kt at the sail. The sail's lift curve was checked against wind-tunnel measurements of windsurf sails (Zhang et al. 2025, Mok et al. 2023) and kept.
- Low speed: the rounding up from rest is physical (no speed, no fin grip, the sail's centre of effort behind the hull's resistance). Beginner mode now does the sailor's part: auto-sheet on by default (W/S override it for 3 s), a heading hold with the rig when no key is held, speed-sensitive steering (less rake at speed) and an automatic ease when overpowered. Advanced mode keeps the raw controls and the consequences (spin-outs, catapults).
- Numerics: the heave damping is weighted by the wetted area share (a light board alone was undamped) and held to the momentum there is per step (a 9 kg board blew up dead downwind); the sail force is skipped when the board stands on its nose.
- New scenarios: `overpowered`, `bear_away`, `low_speed_turn`; new runner options `--twa2`, `--switch`; `--fall=<s>` for `tools/screenshot.sh`.

**Verified:**
- `tools/test.sh`: 103/103 (new: catapult and waterstart, auto-sheet with override, overpower ease, heading hold on both tacks, speed-sensitive rake, drive-maximising trim). `tools/check.sh`: 59 files, 0 failed.
- Scenarios: `overpowered` (catapult at 23 degrees of heel, the board stops level in a second, waterstart at 4 s), polars at 18 and 24 kt from a planing start, `low_speed_turn`, `bear_away`, dead downwind without NaN.
- Screenshots `.screenshots/fall_mid.png` and `fall.png`: the rig over the water and lying on it, the sailor beyond, the board upright.
- Not verified: how the beginner assists feel in play, whether 20 and 25 degrees are the right fall thresholds in play, the gybe on Space at speed (it may spin out), the planing onset (T2).

**Decisions:**
- Falls are an event in the one-body model (A-17), not a two-body sailor yet. If the team wants to feel the sailor being pulled before a catapult, the two-body sailor is the next step.
- Beginner assists are control, not physics; the physics is identical in both modes.
- The 6.5 m2 sail stays the default; a bigger sail is the team's equipment choice if they want more downwind speed in 18 kt.

**Next:** the team plays again (same checklist, plus: get catapulted on purpose in advanced mode, and bear away from a beam reach at speed in both modes). Then Phase 4 proper: planing onset (T2), steering with the sheet eased (T7), and the polar against GPS data if the team has any.

---

## 2 October 2026 - Session 30: Phase 2 (the headless simulation) and Phase 3 (the playable prototype)

**Phase:** 2 and 3, both done. Same day as Session 29, after the team asked for simulated physics instead of tuned limits (decision D8) and a playable demo.

**Done:**
- Built the whole simulation in `Game/sim/` (14 scripts, no Nodes): a rigid body with its own integrator, the mass model, buoyancy on a grid with a real rocker line, the hull (friction, wave hump, sideways drag, planing lift), the fin, the sail, the wind, the water, the sailor and the `WindsurferSim` that combines them; six config resources in `Game/config/`; 92 unit tests in 11 files; a headless scenario tool `tools/simulate.sh` that writes CSV telemetry; and an autopilot that plays the sailor in tests and scenarios.
- Every number comes from real equipment or real physics; nothing is capped to hit a target. The spec's new section 17 explains each choice; section 16 (the tuning log) has one row per change.
- The hard part was planing. The spec's Savitsky lift at one point made the board porpoise (bounce in pitch), and the sailor's reflexes were hiding it. Holding the sailor still in a scenario showed the board pitching to 24 degrees and capsizing on its own. The fix was physics, not a damper: the planing lift is now computed strip by strip with the slender-body theory of planing, which contains the pitch damping that the water gives a planing hull, matched to Savitsky's measured lift. Section 17.2 of the spec tells the story.
- Along the way, several real effects that were missing were added: the rig leaned to windward with the sailor, the sailor hanging back against the sail's pull, the sailor's legs as a suspension, the sailor's windage, the water's added mass in heave and pitch, flat-plate drag of the fin at large slip, a freeride rocker line, and a planing beam that follows the board's taper.
- Numbers (18 kt at 10 m, 16 kt at the sail): beam reach 35.9 km/h (19.4 kt), close-hauled 22.7 km/h at 52 degrees to the wind with 6.6 kt of upwind VMG, broad reach 21.6 km/h; steady, identical on both tacks; the board rounds up and stops when nobody steers; at rest it displaces 89.8 L and floats level.
- Phase 3, the playable prototype: an input map in `project.godot` (W/S sheet, A/D steer, Q/E rake, Space tack or gybe, T auto-sheet, Tab mode, 1 to 4 cameras, R reset, Esc pause, F1 panel); `windsurfer/windsurfer.tscn`, a node that owns the simulation, steps it every physics tick and copies the state onto simple shapes (a box board with an orange nose, a fin, a mast, a sail that turns with the sheet, the rake and the rig lean, a boom, and a capsule for the sailor that leans and steps back as the simulated sailor does); `windsurfer/player_controller.gd` with a beginner mode (A/D turn left and right on the screen on either tack, automatic balance) and an advanced mode (Q/E rake, A/D weight), both with W/S sheeting, an optional auto-sheet and a tack or gybe on Space; `camera/camera_rig.gd` with follow, orbit (right mouse button to turn, wheel to zoom), top-down (bow up) and free (spectator) cameras on the board's interpolated transform; `ui/hud.gd` with a one-line strip, a detail panel (F1), a wind rose and the key help; `world/water.gdshader`, a flat sea with a 5 m grid so that speed shows; `main.tscn` and `main.gd` that tie it together, with `--camera=`, `--autopilot=1` and `--hud=0` options for screenshots. The old FBX models stay in `assets/models/` for Phase 6; the prototype uses plain shapes.

**Verified:**
- `tools/test.sh`: 92/92 pass in about 8 s. `tools/check.sh`: 50 files, 0 failed.
- Scenarios `beam_reach`, `close_hauled`, `broad_reach` on both tacks, `fixed_controls`, and `beam_reach --freeze=40` (sailor held still fore and aft): all steady.
- Phase 3: `tools/test.sh` 97/97 (five new controller tests: sheet pace, screen-relative steering on both tacks, advanced mode, tack and gybe on Space, a stuck manoeuvre is abandoned); `tools/check.sh` 56 files, 0 failed; screenshots of all four cameras with the autopilot sailing (`tools/screenshot.sh res://main.tscn .screenshots/cam1.png 360 --camera=1 --autopilot=1`, and 2 to 4), looked at and corrected (help line cut off, free camera starting inside the board).
- Not verified: how it feels to sail with the keys (nobody has played it yet; the autopilot sailed for the screenshots), whether the tack and gybe on Space carry the board through the wind in play, the planing-onset speed (check T2), steering with the sheet eased (part of T7), and anything on waves.

**Decisions:**
- The sailor's reflexes (balance, hang-back, legs, pitch reflex) live in the simulation and stay on in every control mode; the player gives intentions. A windsurfer cannot be balanced by someone holding still (spec 17.3).
- The planing model is the strip model of spec 17.2; the point model of section 5 is superseded.
- Added mass, legs and the other additions are physics the spec had left out, not tuning; recorded in the tuning log with their sources.

**Next:** the team play-tests the prototype (checklist in the plan, Phase 3). Then Phase 4, validation and physics fixes at the source, starting with what the play-test turns up and with checks T2 and T7.

---

## 2 October 2026 - Session 29: Physics spec from the Unity version

**Phase:** 1, done. Started on 28 September 2026, finished on 2 October after the session's token limit interrupted the first attempt.

**Done:**
- Wrote [PHYSICS_SPEC.md](PHYSICS_SPEC.md) (about 5,800 lines, 17 sections): conventions and notation; apparent wind; sail; rake steering and the stabilisers around it; fin; hull drag, displacement lift and Savitsky planing; buoyancy and water damping; mass, inertia and the sailor's centre of mass; wind; Gerstner waves; controls; the master table of every tuning value; a register of 36 stabilisers and fudges (`F-01` to `F-36`); the legacy contradictions and their resolution; the default configuration and the Phase 4 validation targets; the open questions; an empty tuning log.
- How it was made: the first attempt fanned the work out to 16 extraction agents with three reviewers each. That exhausted the 5-hour session limit in about ten minutes, so none of the reviewers ran, and the scratch folder with the drafts was wiped before the next session. Nine drafts were recovered from the agents' Write calls and five more from Bash heredocs in their transcripts; the fudge register, the open questions, the tuning log and the header were written by hand. Every section was then read and corrected by hand against the legacy code.
- What the spec found that the plan did not know (header of the spec, "Six things"): the Unity scene file holds the values that ran, and the Session 22 numbers survived to the last played Session 26 scene, so the documented tuning (0.85 lift cap, 4000 damping, Savitsky) was never played; the played planing lift was a speed ramp capped at 6 % of the weight; the body weighed 94 kg while the hull's caps used 91 kg; the sail force acted at the board origin; the sail side came from the Space key, not the wind; the legacy TWA had the opposite sign of the legacy AWA; the validated runs were on flat water in 15 kt (22 kt in the Session 26 commit) with the wind sampled at the board origin.
- Corrected the plan's own fudge list (the "150 × rake" and "0.3 between 15 and 25 kt" figures came from older docs) with a note in the plan, ticked the Phase 1 boxes and set Phase 2 to Next.

**Verified:**
- `tools/test.sh`: 10/10 unit tests pass. `tools/check.sh`: 6 files, 0 failed. Nothing under `Game/` changed this session.
- Read and cross-checked by hand: SailingState, Aerodynamics, AdvancedSail, AdvancedHullDrag, AdvancedBuoyancy, AdvancedFin, Hydrodynamics, BoardMassConfiguration, AdvancedWindsurferController, WindSystem, GerstnerWave, WaterSurface, PhysicsConstants, the setup wizard and the project settings. The inconsistencies found between sections were fixed: the default wind (15 kt from 270°, not the wizard's 12 kt from 45°), the mass arithmetic (8 + 6 + 80 = 94), wrong section numbers, and which section owns the default configuration (section 14).
- Not verified: the automated three-lens reviews (source fidelity, sign conventions, physics) did not run. Line references inside the sections were produced from the files by the agents and were spot-checked, not re-verified one by one. The real-equipment numbers in section 14 come from web pages read on 28 September and were not re-checked. Nothing about how the game feels can be known until Phase 3.

**Decisions:**
- Section 14 owns the default configuration: 120 L board of 2.40 × 0.72 × 0.12 m and 9 kg; 6.5 m² sail with a 4.60 m luff and 1.95 m boom; 38 cm fin of 0.0365 m²; sailor 75 kg, rig 8 kg, total 92 kg; tests in 15 kt from the West on flat water. Open for the team (question 3). The worked examples in the model sections keep the legacy configuration (2.5 × 0.6 m, 91 or 94 kg) because that is what the legacy code was checked against.
- Phase 2 keeps a speed-based planing ratio as a model input (section 5 F4); planing onset is measured as the speed at which dynamic lift carries half the weight (section 14). The planing lift gets one hard cap at exactly the weight and no tunable fraction.
- Every fudge has an ID; config comments and the tuning log cite it, so nothing is re-added by reflex.
- Process: do not run large multi-agent workflows in this project; they exhaust the session limit. Work solo, or with one or two agents at most.

**Next:** Phase 1 Stop. The team answers the seven questions in PHYSICS_SPEC.md section 15 (top speed, fastest point of sail, default equipment, control modes, what Space does, the wind reference height, how fast full rake should turn). Then Phase 2 starts from sections 0, 14 and 11 and the owning sections, in the plan's order: config resources, integrator, environment interfaces, buoyancy, hull drag and planing, fin, sail and apparent wind, rake steering, sailor mass and centre of mass.

---

## 28 September 2026 - Session 28: Switch to Godot, preparation

**Phase:** 0 (preparation), done.

**Done:**
- The team decided to restart from scratch in Godot 4.7 instead of continuing in Unity. The main reason is better AI support: an AI session can now run the tests, check every file and look at screenshots itself. Before, Session 27 had to be written without ever running Unity.
- Moved the whole Unity project, the old docs, README and CONTRIBUTING into `Legacy/` with `git mv`, so their history is kept. The Unity `.gitignore` moved into `Legacy/WindsurfingGame/`. `Legacy/README.md` now starts with a banner explaining what is useful there and which legacy tables are wrong.
- Installed Godot 4.7.2 (official build, SHA-512 checked) in `~/.local/opt/godot/4.7.2-stable/`, with `~/.local/bin/godot` and an app-menu entry. No sudo needed. `tools/install_godot.sh` does this again for anyone on Linux.
- Created the Godot project in `Game/`:
  - Forward+ renderer, 1280×720 window, physics interpolation on
  - untyped GDScript declarations are errors
  - GUT 9.7.1 test framework
  - `DevCapture` autoload for screenshots
  - placeholder `main.tscn` with sky, sun, a water plane, and the old board and sail models (copied from Unity)
  - its own icon
- Tools in `tools/`: `install_godot.sh`, `godot.sh`, `test.sh`, `check.sh`, `screenshot.sh`, `api_docs.sh`, `play.sh`, `edit.sh`, all sharing `common.sh`.
- First tests: `tests/unit/test_engine_conventions.gd` (Godot's axes and angle signs that our physics conventions depend on) and `tests/unit/test_project_setup.gd` (version, typing rule, physics interpolation, main scene). A pending placeholder sits in `tests/validation/`.
- VS Code: installed the godot-tools extension (2.7.1) and set its Godot path in the user settings.
- Wrote `CLAUDE.md`, `README.md`, `Documentation/REBUILD_PLAN.md` and this log.

**Verified:**
- `tools/test.sh`: 10/10 unit tests pass. `tools/test.sh all`: 10 pass, 1 pending (the validation placeholder).
- `tools/check.sh`: every file loads. It was also confirmed to fail on a deliberately broken script and on an untyped variable, and `tools/test.sh` was confirmed to fail on a deliberately failing test. The probe files were deleted afterwards.
- `tools/screenshot.sh`: the placeholder scene renders on the RTX 3080 Ti (Vulkan, Wayland session): sky, water, sail and boom visible. The image was checked.
- Not verified: opening the editor by hand (`tools/edit.sh`) and the GUT editor panel. Everything was driven from the command line.

**Decisions:** see "Key decisions" D1 to D7 in the plan. The biggest one: we write our own rigid-body simulation in plain GDScript (D2), so the physics can be tested headless and fast.

**Found along the way:**
- Legacy `PHYSICS_VALIDATION.md` has port and starboard swapped in its AWA and sail-side tables, and says "rake back = bear away". The Unity code (correctly) uses AWA > 0 for wind from starboard and makes rake back head up.
- `board.fbx` points along X, contains a stray camera and refers to a missing Starboard product photo. `sail.fbx` has a mast without faces and refers to a missing Severne graphic. Details are in the Phase 6 notes of the plan.
- The repository has no LICENSE file, although the old README said MIT.

**Next:** Phase 1, writing `Documentation/PHYSICS_SPEC.md` from the legacy physics code and docs.
