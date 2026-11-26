# Reality fixes: progress (branch physics/reality-fixes)

Max, 25 Nov 2026: "fix the problems" (gaps 1 and 2 of the reality check first). Physics changes
need Michiel's OK before main; this branch prepares them. Worktree:
C:/Users/Max de Dikke/source/WindsurfingMMZB-reality. Measure with
`python tools/video/reality_check.py` and `python tools/video/reality_sweep.py [--chop]`.

## Where it stands

- Commit 4ed1d49: the video tools + reality check (first run on main: 1 of 10 strict pass).
- 26 Nov 2026 (second session): gap 2 step 1 IN: the legs set to 0.4 Hz / 0.4 in
  Game/config/sailor_default.tres and the SailorConfig defaults (comment with the reason),
  PHYSICS_SPEC.md 7.5 (the numbers, why, and the gybe cost) and 17.13 (a pointer); backlog
  E01.S07 T6 and E01.S09 T5. tools/check.sh: 522 files, 0 failed. See "Gap 2 step 1: checks".
- The Claude Doc "Windsurf video analysis" corrected (26 Nov): the "one body" paragraph under
  "The board over chop" and the four "rigid sailor" phrases now say the sailor has legs in
  heave, missing only in pitch and roll.
- Final checks with the new limits: tools/test_parallel.sh all 1165 tests, 9 failing, 2 pending
  = the same nine as main at the 13 Nov merge (8 known reds + the lake fleet start).

## To continue

0. DONE (26 Nov, late): the legs set to 0.8 Hz / 1.0 from the body tracker (Max: the choice is mine from the Max's play-test the same evening: "the small chop does good". NEXT: "the fin lifting straight up is frustrating me" (backlog E01.S08 T10, Q54).
   measurements, not his). Section 'The body tracker', 'Set'. Max play-tests the feel.
1. Max play-tests the softer legs on the lake chop (`tools/play.sh lake` in this worktree, or a
   play folder if he asks: launchers with the mouse body on).
2. Michiel's OK on the legs and the three moved test limits (all marked "for Michiel to confirm").
3. Then gap 1 (below): the lift of a realistically held rig, then rake-first steering for the
   player with the rake stop near 35 deg. Gybing (the soft legs' gybe falls) is for later.
4. Step 2 of gap 2 (legs that give in pitch and roll, spec 17.12 item 1) after the play-test;
   17.13 lists what failed sideways before (a sideways leg spring hunted the course).

## Gap 2 (the bounce): CORRECTION + the fix found

- My earlier claim "the sailor is one rigid body with the board" was WRONG. The sim already has a
  two-body sailor in heave (SailorBody point mass, legs = spring/damper, windsurfer_sim.gd
  _apply_leg_forces; knee_bend_m = the leg spring's compression). Across the deck (sideways,
  yaw) the body rides the hull and the feet pass the moments (spec 17.12 item 1: legs that give
  in pitch and roll are still missing). The Claude Doc section "The board over chop" still says
  "one rigid body": fix that sentence.
- Cause of the bounce: the legs (sailor_default.tres leg_natural_frequency_hz 1.2, leg_damping_ratio
  0.9) resonate with the lake's chop (0.8-1.25 Hz): the body moves ~1.1-1.3x the board.
- Fix found (switches only, lake chop 12:00/14:30/17:00, `reality_sweep.py --chop`):
  leg_natural_frequency_hz 0.4 + leg_damping_ratio 0.4 -> pitch 1.21/1.56/3.21 -> 0.61/0.86/1.06 deg,
  heave at the feet 3.3-6.1 -> 2.8-3.4 cm, knees 2.3-3.3 -> 4.7-5.8 cm (video 07: ~5 cm), wags
  fewer, speed +0.3 to +1.9 kn, no falls. Full matrix (27 cases, 12/18/24 kt): 0 falls, 0 NaN, all
  manoeuvres completed, same as now (.sim_output/legs_old vs legs_new).
- DONE 26 Nov (no persona or gear config overrides them): see "Gap 2 step 1: checks". The
  roll/pitch compliance (17.12 item 1) stays the second step, after Max's play-test of the legs.

## Gap 2 step 1: checks (26 Nov 2026)

- tools/test_parallel.sh all: 1165 tests, 13 failing. 9 of them fail the same with the old legs
  (the polar sweep x5, the waves at 120, the lake fleet start, the skipper's 12 kt time, the push
  warning: the known reds; checked by running those files with 1.2/0.9, .logs/tests_baseline/).
  The skipper's 12 kt T1 time: 12:18.3 -> 12:44.7 (red before too, limit 12:00).
- New with the soft legs, 4: (1) test_feet_press "left in the middle, exactly as before": recorded
  numbers; FIXED the way that test handles later changes (the old legs set inside it), 5/5 green.
  Three near misses; Max (26 Nov): move the limits and flag them for Michiel (catapult < standing
  limit + 5 deg, start <= 3.5 s, coupled rig lean < 12.5 deg; comments in the tests): (2) test_windsurfer_sim overpowered catapult: heel at the
  fall 44.4 -> 50.8 deg against < 50 (standing_fall_heel_deg; most likely the legs' roll stiffness
  k x offset^2, now a ninth; the roll after the fall 82 -> 66 deg, better); (3) test_skipper start
  3.03 s against <= 3.0; (4) test_rig_lean_and_fin_loading: the coupled helm's rig lean 11.99 ->
  12.016 deg against < 12 (noise; the rake-first run got steadier: pitch SD 0.28 -> 0.03).
- Reality check (.sim_output/reality/report.md): strict still 1 of 10 (heel). Legs 4.71/5.03/5.83
  cm, all "close" (were 2.3/2.3/3.3, "off"). Lake pitch 0.61/0.86/1.06 deg, now "off" BELOW video
  04's 1.7 +- 0.6 (indicative: Gruissan's chop is rougher, its height unmeasured). Wet length
  1.02/1.07 m (1.08/1.09). Planing gybes on race gear: 3 falls of 4 (1 of 4 before).
- Leg sweep (`python tools/video/leg_sweep.py <repo>`, .sim_output/leg_sweep/; strong_62 gybes = 97 l + 5.7 at 24/30 kt,
  6 cases; F = fell; numbers = s off the plane):

  | legs Hz/zeta | gybe falls of 6 | lake pitch deg 12:00/14:30/17:00 | knees cm |
  |---|---|---|---|
  | 1.2 / 0.9 (old) | 1 | 1.21/1.56/3.21 | 2.3/2.3/3.3 |
  | 0.4 / 0.4 (now) | 4 | 0.61/0.86/1.06 | 4.7/5.0/5.8 |
  | 0.4 / 0.7 | 5 | 0.79/0.94/1.57 | 4.0/4.1/4.9 |
  | 0.4 / 1.0 | 4 | 0.98/1.05/1.80 | 3.4/3.4/4.1 |
  | 0.6 / 0.4 | 5 | 0.92/1.03/1.68 | 4.4/4.8/5.5 |
  | 0.6 / 0.7 | (run failed: Godot class-cache clash, 10 at once) | 1.09/1.16/1.88 | 3.5/3.6/4.3 |
  | 0.6 / 1.0 | 4 | 0.94/1.49/1.99 | 3.0/3.2/4.0 |
  | 0.8 / 0.4 | 3 | 1.00/1.52/2.50 | 4.0/4.1/5.1 |
  | 0.8 / 0.7 | 4 | 1.39/1.51/2.56 | 3.2/3.2/4.2 |
  | 0.8 / 1.0 | 2 | 1.08/1.26/2.72 | 2.6/2.5/3.6 |

  Why the gybes fall (trace of gybe_beam_30): at the entry the knee bend jumps 0 -> 17 cm (old)
  or 24 cm (soft) in 0.25 s: the posture's own height steps (out of the hike). Soft legs with
  little damping overshoot (+24 -> -12 -> -29.5 cm, past leg_travel_m 0.25), the stop's 10 x k
  kicks the 9 kg hull out (wet length 0), it slams back (2.6 kN), pitches 20 deg, rolls over.
  Fix proposed, NOT built (Max, 26 Nov: "gybing is for later"): the posture's height as an
  active move (a rate-limited copy of it, its rate fed to the legs' damper), the soft spring only
  for the deck under the feet; a switch, off by default; then the sweep again.

## Would riding on the tail improve the game? (26 Nov 2026, Max's question)

Pitch budget, 18 kt beam reach, default gear (`Game/dev/pitch_budget.gd -- --wind=18 --twa=100` + switches; outputs in
.sim_output/sailor_forces/trim_*.txt):

| switches | trim deg | wet m | push m | speed m/s | friction N | pitch SD deg (bounce) |
|---|---|---|---|---|---|---|
| none (the game) | 1.22 | 0.96 | 0.82 | 15.46 | 174 | 0.06 |
| trim aim 2.5, 3.5 or 4.5 | 1.28 | 0.95 | 0.82 | 15.46 | 174 | (same: feet at the straps' 88.5 N m) |
| aim 3.5, fin.bends=false | 1.57 | 0.85 | 0.68 | 15.78 | 157 | 0.07 |
| aim 3.5, front_foot_pull_held_n=300 | 1.74 | 0.84 | 0.64 | 15.16 | 143 | 0.38 (0.4 Hz) |
| aim 3.5, pull 300, stiff fin | fell at 35.6 s | | | | | |
| aim 4.5, pull 450 | 2.02 | 0.82 | 0.65 | 14.49 | 130 | 1.24 |
| aim 4.5, pull 450, stiff fin | 3.09 | 0.44 | 0.39 | 15.28 | 69 | 0.24 |

- The trim aim alone does nothing: the front strap's held pull (150 N x 0.59 m = 88.5 N m) is the stop.
- Tail riding (0.44 m wet, as the videos) cuts the friction 60 % but not the speed: the autopilot rakes less to hold the course
  (rake 0.37 against 0.69), the drive falls 300 -> 222 N, the sail lifts 147 instead of 249 N, the planing lift rises 539 -> 832 N.
- The hull porpoises at the higher trim (0.24 to 1.24 deg SD), worst with the bending fin; one run fell. So a fix needs the hull's
  bounce (E01.S08 T3) and the fin's up-push with the sailor's limits, not a sailor setting alone; then the speeds and the AI's polar
  re-measured.

## The sheet-in (26 Nov 2026, Max: "the game is really wrong on sheet in amount" -> "not sheeted in enough", "how the sail looks"; his drone photo of a sail fully sheeted in: the boom straight back, the clew over the tail near the centreline)

- Boom angle = 85 - 73 x sheet (sail_model.gd, linear; the stop fully in 12 deg). The autopilot and the reality runs sheet 0.89-1.00 (boom 12-20 deg, alpha 14-16 deg, AWA 28-35 deg): fully in, as the photo.
- The player's controller (tools/push_check.sh, beam reach, no gusts or waves; run sheet_look and sheet_look_075):

  | push | 12 kt | 18 kt | 24 kt |
  |---|---|---|---|
  | 0 | sheet 0.00 (sail out, 1.3 m/s) | 0.00 | 0.00 |
  | 0.5 | 0.86 (boom 22), 7.2 m/s | 0.80 (27), 10.6 m/s | 0.70 (34), 12.6 m/s |
  | 0.75 (the game's start) | 0.94 (16), 8.0 m/s | 0.95 (16), 13.6 m/s | 0.85 (23), 15.5 m/s |
  | 1.0 | 0.92 (18), 7.5 m/s | 0.98 (13), 14.0 m/s | 0.89 (20), 16.2 m/s |

  So below full push, and in stronger wind even at the start's 0.75, the auto-sheet eases the sail 20-34 deg off the
  centreline: visibly not fully in. Real racers at speed stay fully sheeted in and control the power with the body, the
  rake and the lean; they ease only for a moment in a gust. A gameplay fix (the auto-sheet, Max's track), not physics.
- Front views can't give the real boom angle without a camera model (the leaned rig's clamp sits to windward and the far
  clew converges: the game's known 12 deg read as ~0.85 m); video 07 against the game from ahead: 0.56 against 0.45
  boom offset per mast length (.screenshots/sailor_forces/examples/sheet_in_front.png), within that error.
- Game/dev/rig_view.gd: views drone_front, --push=<level> (the autopilot at a push), and it prints sheet, AWA, lean, rake.

## The sheet-in fixed in the push ladder (26 Nov 2026, Max: "fix it")

Game/config/push_curve_default.tres: drive_share at 50 % 0.85 -> 1.0 (the sail fully in once planing; the eased
sail stays at 0 and 25 %, below planing), hike_share 50 % 0.8 -> 1.0 and 75 % 1.0 -> 1.2 (the pull held before the
auto-sheet eases; the ease in a gust stays). Push check, beam reach, gusts and waves (runs sheet_gusts -> sheet_gusts_new):

| wind | push | boom before -> after (deg) | speed before -> after (m/s) | falls |
|---|---|---|---|---|
| 12 | 0.5 | 31 -> 15 | 6.00 -> 8.42 | 0 -> 0 |
| 12 | 0.75 | 15 -> 15 | 8.42 -> 8.42 | 0 -> 0 |
| 18 | 0.5 | 29 -> 19 | 10.64 -> 13.10 | 0 -> 0 |
| 18 | 0.75 | 19 -> 17 | 13.10 -> 13.39 | 0 -> 0 |
| 24 | 0.5 | 39 -> 27 | 11.29 -> 14.51 | 0 -> 0 |
| 24 | 0.75 | 27 -> 26 | 14.51 -> 15.12 | 0 -> 0 |

Left for Michiel: at 24 kt the boom stays ~26 deg even fully trimmed: AWA 35 deg minus the sail's best alpha ~13 deg
(the twist law at high pressure, backlog E01.S20 T1); real race sails stay near fully in. The AI fleet sails the same
ladder (its polar, skipper_polar.tres, was measured on the old one).

## Full push sheets in further: the twisted sail stalls later (26 Nov 2026, Max: push 100 "clearly not enough sheet in")

Cause: the sail model's drive peaks at 18 deg of alpha at every pressure, so the auto-sheet holds the boom at AWA - 18 (15-24 deg
at full push); the 12 deg stop was not the limit in play. Change (physics, for Michiel): SailConfig.twist_stall_shift_deg (new,
12 in all sails): the curve's linear end, peak and stall end move up by 12 x (1 - twist_factor): ~2 deg light air, 6 at 120 Pa,
7 at 180 Pa (an estimate; E01.S20 T1). Sheet stop 12 -> 5 deg in all sails (catalogue regenerated); the autopilot takes the
stop from its sail and scans alpha to 30. Push check, gusts and waves, full push (run stall_base -> sheet_final):
beam 12/18/24 kt boom 15/16/24 -> 6/13/20 deg, speed 8.44/13.16/15.25 -> 10.21/13.31/15.79 m/s; broad 18/24 kt boom 40/26 -> 27/18,
9.04/15.02 -> 10.42/16.05 m/s; no falls (all levels 0.5-1.0). Superseded the same evening by the measured version below.

## The sail's flex measured (26 Nov 2026, evening; the scheduled run after Max's reset)

- Twist, video 07 at 3 s from ahead (tools/video/sail_flex.py, overlay checked): the sail's angle off the centreline 15 deg
  just above the boom -> 25 deg at 57 % of the luff; chord from the game's traced HGO outline (head 0.40 of the boom chord);
  head twist ~20 deg (16-26 with the outline and scale varied). The game draws 8-16 (RigVisuals). Calibration on the game's
  own sail failed (small, windowed): the number stands on its error range. Video 07 at 1/5/7 s not usable (luff off the crop).
- Mast bend: upper luff leans 15.6 deg less than the lower mast in the picture; ~half perspective -> ~0.2 m (+-0.15) to
  leeward at 1.8 m above the boom; the game 0.12 m at the head. Aft bend not checkable from these views (06 leech off-frame).
- Physics: the stall shift = mean twist ~0.24 x head twist (~4.8 deg at ~130 Pa). The first form (from 0 Pa) moved the wind
  tunnel's points (4 m/s, 16.5 deg: lift 1.06 vs 0.98 +-0.08, test_sail red) -> new SailConfig.twist_stall_shift_from_pa = 39
  (8 m/s: the tunnel's data stand as measured), twist_stall_shift_deg 12 -> 11 (tunnel sail assumed 8 deg at the head; 7-16).
  Stop 5 -> 10 deg: at 5 and 8 the overpowered catapult test rolled the board over (180 deg), at 10 it comes back.
  The autopilot's alpha scans/caps back at 24 (30 let the pull-limit scan land in the deep stall and skip the limit).
- Full push, gusts and waves (stall_base -> sail_measured): beam 12/18/24 kt boom 15/16/24 -> 14/14/21 deg, speed
  8.44/13.16/15.25 -> 8.64/13.34/16.17 m/s; broad 24 kt 26 -> 23 deg, 15.02 -> 15.32; no falls.
- All tests: 7 failing = 6 known reds + the old fleet-start test on T1 (one board of 16 late, Cautious 4; not reworked);
  three old reds now pass (polar shape, broad reach on waves, the AI's 12 kt T1 time). test_sail: the worked examples keep
  the 12 deg stop; test_feet_press keeps the old sail. Reality check: 1 of 10; wet length 1.00/1.05 (1.02/1.07); race-gear
  gybes 4 of 4 fall (gybing is for later). For Michiel: the twist -> stall link, the tunnel sail's twist, the 10 deg stop.

## Speed in the reality check (26 Nov 2026, Max: the videos' speeds are roughly 30-35 kn)

New strict case "speed" (32.5 +- 2.5 kn, tools/video/reality_cases.json): strong_62 (97 l + 5.7) at 24/30 kt 31.5/34.2 kn
pass; medium_72 (117 l + 7.4) at 18/22 kt 25.9/28.5 kn fail (12-20 % slow). Those runs use the player's controller
(Helm.steer, rig nearly upright); the autopilot's rake-first hold made 30 kn at 18 kt (pitch budget, 72 + 8.0), so gap 1
(rake-first steering for the player) is the likely first lever. Reality check now 3 of 14 strict.
CORRECTED the same evening (Max: "game is not right in strong winds. we do not measure in waves"): the videos are nearly
all in chop, so the speed case now reads runs in the game's sea (--waves=1, runs medium_72_waves, strong_62_waves): 72 + 7.4
at 18/22 kt 23.6/25.7 kn (27/21 % slow), 97 l + 5.7 at 24/30 kt 28.5/31.6 kn (12 % slow / just inside). The game's chop
costs 8-10 % on the beam reach (flat 25.9/28.5/31.5/34.2). Too slow in chop everywhere but 30 kt. Levers: the rig's hold
(rake-first), the waves' cost (backlog E01.S20 T3; the real cost needs a source or Max), the hull (E01.S08). 2 of 14 strict
(rows; after the speed case was made indicative below: 1 of 10, the heel).

## The measured stance tested on flat water (26 Nov 2026, Max: "is the body analysis good enough to test it?")

Speed case made NOT strict (Max: neither flat water nor the game's sea is the videos' real chop). Pitch budget, flat water,
beam reach, autopilot (.sim_output/sailor_forces/stance/):

| switches | 18 kt wet / CoM x / rake / speed / pitch SD | 24 kt |
|---|---|---|
| none | 0.97 m / -0.04 / 17.5 deg / 15.47 m/s / 0.05 | 0.97 / -0.13 / 16.8 / 17.24 / 0.08 |
| sail.max_rake_deg 35 | same (rake 0.50 x 35 = 17.5 deg) | same |
| + fin.bends false | 0.95 / +0.05 / 18 / 15.64 / 0.07 | 0.88 / -0.08 / 16.8 / 17.70 / 0.07 |
| + front foot 450 N, trim aim 4.5 | 0.39 / -0.10 / 8.8 / 15.40 / 0.87 (porpoises) | FELL |

Findings: (1) the board can ride on its tail (0.39 m, friction 176 -> 62 N) but the hull porpoises at the real trim and is
not faster; at 24 kt the sailor falls: the hull's stability at 3-4 deg (E01.S08 T3), Michiel. (2) The rake is the course's
helm: the game sails straight at ~17.5 deg (8.8 with the weight back) where real boards sail at ~31: the yaw balance. In the
game 551 of the sail's 572 N sideways goes through the hands and the feet at the back strap (yaw -651 N m) against the fin
(+614), the mast foot ~0; the real split between mast foot and feet at 31 deg rake is not measurable from these videos.
For Michiel: why a straight course needs only 17 deg of rake.

## The body tracker (26 Nov 2026, late; Max's yes to Q51)

Max (Q51): "yes of course, you are from now on authorized to install needed plugins or applications, but you cannot
delete anything outside of the source folder". MediaPipe 1.2.3 (`python -m pip install --user mediapipe`); the pose
model `pose_landmarker_heavy.task` (Google, Apache 2.0, about 30 MB) beside the videos in
`WindsurfingMMZB-videos/_models` (not in git). Tool `tools/video/pose_track.py` (run with `python -E -P`: `-I` hides
the user's site-packages):

- `check`: video 07's four by-eye frames against the tracker (`<videos>/07_unknown_front_drone/pose/check.png`, red
  by eye, green the tracker). Shoulders, knees, ankles within 8-51 px; the hips 30-90 px apart: the by-eye hips sat on
  the back of the seat, the tracker's are the hip joints (checked on the picture). With the tracker's joints the
  sideways pull is 0.82 of the weight on those four frames (by eye 0.94).
- `track 07_unknown_front_drone --start 0 --end 17.8 --crop 0,800,1000,700`: 513 of 534 frames found; the tracker
  loses the sailor after 16.5 s. `legs <csv> --front --until 16.4`: 459 frames kept; the scale follows the drone's
  zoom (the trunk 375 to 645 px/m over the clip).

Results (one camera, video 07, 15-20 kn, low chop):

| | value |
|---|---|
| sideways pull / weight, per frame (257 usable) | median 0.87 (10-90 %: 0.81-0.90); the game about 0.90: still a match |
| body line from the feet | median 60 deg (55-64) |
| the legs' work (fast part: minus the 1 s average, SD) | hips to the feet 1.6 cm (2.3 with the tracker's jitter of 1.6), hips above the feet 3.0 cm |
| the board at the feet / the hips, up and down against the shoreline (0-8.5 s) | 3.7 / 2.6 cm: the body moves 0.71 of the board, correlation 0.58 |

The 5 cm of 25 Nov (`front_bounce.py`) measured the shoulders against the centre of an ellipse fitted to the board's
underside seen from ahead, that is the nose area, which rises and falls with every pitch (1 deg = about 2.6 cm at the
nose); the tracker's ankles are the feet. The legs' tune of 26 Nov (0.4 Hz / 0.4) was chosen to match that 5 cm.

The game's lake chop (the leg sweep's runs, `.sim_output/leg_sweep/`, measured the same way: board = its height,
body = the board less the knee bend, 0.17 s average, minus 1 s average, last 20 s):

| legs Hz / damping | knees cm | body / board | correlation | gybe falls of 6 | lake pitch deg |
|---|---|---|---|---|---|
| real (07) | 1.6-3.0 | 0.71 | 0.58 | | (04: 1.7 +- 0.6) |
| 0.4 / 0.4 (26 Nov) | 4.5-5.6 | 0.91-1.10 | -0.27 to -0.56 | 4 | 0.61/0.86/1.06 |
| 0.4 / 1.0 | 3.2-3.9 | 0.70-0.89 | 0.22-0.37 | 4 | 0.98/1.05/1.80 |
| 0.6 / 1.0 | 2.8-3.8 | 0.84-1.03 | 0.37-0.65 | 4 | 0.94/1.49/1.99 |
| **0.8 / 1.0 (now)** | 2.3-3.3 | 0.90-1.13 | 0.58-0.81 | 2 | 1.08/1.26/2.72 |
| 1.2 / 0.9 (old) | 2.1-3.0 | 1.06-1.21 | 0.75-0.90 | 1 | 1.21/1.56/3.21 |

The soft legs fit worst: the knees work twice the real amount and the body bobs against the board (the negative
correlation), where the real body goes with the board, less. Damping 1.0 at 0.6-0.8 Hz fits best; 0.8 / 1.0 also
halves the gybe falls. The game's chop is not the video's (Max), so the pitch column is indicative.

Set (26 Nov, late; Max: "that's no question for me", the choice is mine from the measurements): 0.8 Hz / 1.0 in
`sailor_default.tres` and the `SailorConfig` defaults (the comment says why), PHYSICS_SPEC.md 7.5, 17.13 and a
section 16 row. Checks: `tools/matrix.sh` with the new legs, flat and `--waves=1`: 54 cases, 0 falls, 0 NaN, all
manoeuvres completed; tools/test_parallel.sh all: 1165 tests, 6 failing, all known reds (the polar sweep's four, the lake fleet start, the push warning); the old T1 fleet start now passes; the reality check: legs 2.75/2.77/3.47 cm (2 of 3 close, were all off at 4.6-5.8), the lake pitch 1.18/1.74/2.00 deg (all 3 close to video 04's 1.7, were off below), strict 1 of 10 (the heel). For Michiel's OK; Max play-tests the feel. The reality check's legs case now reads 2.3 +- 0.8 cm
from the tracker: the game 4.59/5.21/5.82, off (indicative).

Side views: 04 and 06 (a boat to leeward) do not track: the sail hides the sailor and the tracker jumps between
frames on the full picture (trunk 50-300 px frame to frame). A crop per shot or a view from windward (08) next.

Max's other answers (26 Nov, written into `Documentation/backlog/QUESTIONS.md`): Q52 no (not his GPS tracks); Q53
small chop with good timing costs almost nothing, big swell a lot (Sotavento 50-55 out against 65+ in on a downwind
reach, in km/h as Max confirmed; added to the speed case's note); Q54 the nose comes up 20+ deg mostly from the front foot's
pull with more side load on the fin (backlog E01.S08 T10; in the game the front foot holds 150 N and cannot change
the trim with the weight standing still).

## Gap 1 (rig upright, wet length): diagnosed, not fixed

- The player's controller steers with Helm.steer (rake + tilt together: tilt = -rake); the
  autopilot uses Helm.hold_rake_first (U1.3). Temporary test (undone): lean right (24-25 deg on
  117 l + 7.4) but on 97 l + 5.7 the board trims nose-down, wet length 1.22-1.32 m.
- Wet length ~1.0-1.1 m in every rig variant: the hull planing model (E01.S08).
- Board mast_track/fin_box in the gear table are unused by the physics.
- NEXT (after gap 2): the lift of a realistically held rig (the sail's upward part from the
  windward lean, the weight path, the hull lift), then rake-first for the player + rake stop ~35.
