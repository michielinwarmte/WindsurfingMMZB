# Video analysis: progress (pitstops)

Max, 25 Nov 2026: "do it all. with pitstops. for the token limit. but the quality needs to be
high!" Every video from 02 to 08 is brought to video 01's depth, one at a time. After each video
(a pitstop) its section in the Claude Doc "Windsurf video analysis" is rewritten in full, the
comparison tables get its numbers, and this file says what is done and what comes next.

**The bar (video 01's depth):** dense grids per shot; frame-by-frame zooms on every key moment;
every manoeuvre timed to the frame; numbers with a scale where the view allows (board length,
luff); sail details on zoomed frames (rake, twist, mast bend, foot); wind direction from several
clues; colours from several frames that agree; the sailor's control per manoeuvre; every number
labelled measured or estimate; the pipeline's labels checked and corrected.

**Doc:** https://claude.ai/artifact/XBjFrrT4r9poau2DYbGnQP (doc id
f471a388-e1ff-40d3-acd7-053d2daf0af8, body node 27a67c4c-5983). Videos and frames:
`C:/Users/Max de Dikke/source/WindsurfingMMZB-videos/<nn>_<name>/`.

| Order | Video | Focus (Max's "look at" + what the view allows) | Status |
|---|---|---|---|
| 1 | 07 front drone | railing (heel), wet area, nose height, rig lean from the front, stance | done (pitstop 1) |
| 2 | 04 Gruissan (boat, side) | wet length and nose height scaled by the board (E01.S08), rig rake, sail shape | done (pitstop 2) |
| 3 | 06 boat, side | same as 04; GER-7 on 5.6 at 20-25 kn | done (pitstop 3) |
| 4 | 03 NL dam | the gybe timed (off the plane?), fetch picture, posture | done (pitstop 4) |
| 5 | 02 drone beside | nose height, posture on the edge of control, the gybe at the end timed | done (pitstop 5) |
| 6 | 08 Bonaire | the gybe, the fly-by, colours from several frames | done (pitstop 6) |
| 7 | 05 Tenerife explainer | board camera and boom camera frame by frame | done (pitstop 7) |

## Log

- **Pitstop 1, 07 done (25 Nov 2026).** One continuous shot (the analyser's 8 cuts were fake:
  cut detection is now relative, `CUT_RATIO` 2.5 x the last second's change; 01 keeps its 6
  cuts). New tools: `grid_overlay.py` (labelled pixel grid on frames, for reading points) and
  `front_view.py` (rig lean through the orange luff sleeve, board tilt by an ellipse on the
  dark underside; overlays checked). Results: rig lean to windward median 27.9 deg (22.9 at 2-6.5 s,
  28.9 at 6.5-14.5 s), board about level (median 1 deg, middle half -4.7 to +7, 0-3.9 s), body
  line 53-59 deg, nose clear. Corrected my earlier "heels to leeward" in the doc (section,
  comparison table, ideas table). Files in `WindsurfingMMZB-videos/07_unknown_front_drone/measure/`.

- **Pitstop 2, 04 done.** One continuous shot (pipeline's jump/gybe/airtime false: motion
  blur). Rig rake (luff chord head to mast foot, side view, beach line level) 33 deg at 16 s, 36 deg at
  20 s. Wet length about 0.5-0.7 m from the tail (spray span 170 px at 6 s; board ~665 px =
  233 cm; rough, blurred water line). Deck line ~3 deg nose-up incl. rocker. Colours: water
  #2c7063/#3c7463 (12, 20 s), sand #c0a383, pines #273038, hills #6a829d. Probably GER-7 again
  (same RS:Racing sail + SURFCENTER logo as 06/07; not confirmed). The comparison table still
  has the old 04/07 wording in places: rewrite all comparison tables once at the end.

- **Pitstop 3, 06 done.** One shot, straight. Rake (luff chord, side view, shoreline level)
  38/40/41 deg at 3/7/11 s. Wet length about 0.5 m (11 s; board ~440 px = 233 cm; one frame).
  Nose 20-25 cm above water incl. rocker. Colours: water #3e687e/#436c82/#456f85, hills
  #817a78-#a28e83, sky #bfc5cc.

- **Pitstop 4, 03 done.** One shot. Gybe 17.2-21.4 s (~4 s): board points at the camera mid-gybe
  = dead downwind, so wind from beyond the dam (broad reach before/after: fairly sure). Flip
  ~1.6 s (18.8-20.4, rig nearly flat across the nose), off the plane ~1.5 s (19.0-20.6).
  Whitecap pixels at 10 s: his side 0.7-1.3 %, beyond the dam 14.3 % (fetch, measured). Colours
  near water #979da2/#989da5/#878e9d, beyond #91989d, rocks #353941, trees #6c7685.

- **Pitstop 5, 02 done.** One shot. Body line (front foot to shoulders, drone's view) 34 deg at
  5 s, 43-45 deg at 10/13/14.5 s (same drone position: ~10 deg further out = edge of control). Mast
  angle not readable from this view (left out). Gybe: planing carve 22.6-23.8, wide arc to
  24.6, flip ~0.6 s (24.6-25.2), new tack 25.4. Colours: near water #3e7463, further #6a8388/
  #667f89, mountains #7e899c, mangroves #5e612e, sand #baaaa5, shallow water #556262.

- **Pitstop 6, 08 done.** One hand-held shot. Fly-by side view at water level (2.8-3.2 s): rake
  33.4/35.7/32.6 deg (matches 04; 06's 38-41 likely camera height), body line 60-65 deg. Gybe
  8.0-9.25 s, flip ~0.75 s +-0.25 (far). Broad reach towards the beach (Lac Bay trade wind,
  general knowledge). Colours: water #84ca9f/#74b68e/#66ab8b, by the beach #89bba6, sand
  #a7a589, palms #4b4427. Left after 05: rewrite the comparison tables (rake, wet length, flip,
  body line columns) and the ideas table with the new numbers.

- **Pitstop 7, 05 done.** 11 clips (cuts match the grids). Body line 38 deg ("sheet in", 8 s) vs
  67 deg ("sit down in your harness", 34.5/36.5 s). Board camera: horizon steady 13.2-13.9 s (by
  eye; the automatic horizon fit failed on the coast strip, not used). Boom camera: lines carry
  the load, light grip. Colours: water #5d6a7a/#567171, misty #b6b5ba, sky #80a0d2.
  Next: rewrite the comparison tables + ideas table (then this work is complete).

- **Done (25 Nov 2026).** Comparison tables rewritten (conditions; a new "Board, rig and sailor
  (measured)" table; gybes with all four flips) and the ideas table (harness lines down, wet
  length, rig angles, heel, fetch, planing vs off-plane gybe, flip times). All seven videos 02-08
  are at video 01's depth. Open for Max: the spots of 02, 06, 07; speed needs a crossing shot
  with a fixed point or GPS.

- **Videos against the game's physics (25 Nov 2026).** `tools/matrix.sh --only=straight,gybe
  --winds=18,24` on main 19ec1cc (beginner controller, default gear, beam reach). Game: rake 0.42
  x 25 = ~10 deg, rig lean 12.3 deg, wetted length 1.02-1.04 m, heel 2 deg, speed 25.4/28.6 kn; gybes
  off the plane (planing_ratio < 0.5) 1.0-2.0 s, min speed 5.6-9.9 kn. Videos: rake ~31 deg (side
  views corrected for the windward lean), windward lean ~24 deg (07), wet length 0.5-0.7 m, planing
  gybes with 0.6 s flip. New doc section "The videos against the game's physics" for Michiel.

- **Board over chop (25 Nov 2026, Max: "very bouncy in the game, the rider controls it in real
  life").** New tool `front_bounce.py` (07: shoreline as reference, board ellipse, the shoulder
  line = first row where the body is shoulder-wide; overlays checked). Video 07: the
  shoulders-to-board distance changes ~5 cm spread (up to ~9 cm) at 1.5-1.7 Hz; board heave
  <= ~6 cm (incl. drone). Game, lake chop (`tools/lake_matrix.sh --only=straight --lake_waves=1
  --csv=1`): pitch 1.2/1.6/3.2 deg spread, heave 3.1/4.1/5.9 cm, knee bend 2.3-3.3 cm, wet length
  jumps +-0.35 to +-0.7 m, 17-30 yaw-rate reversals per 12 s. Code: `mass_model.gd` = one rigid
  body (board + rig + sailor), knee_bend only shifts the CoM: the cause. -> E01.S07 T1 (two-body
  sailor's legs), T2 (strip slam), T3 (knees as input). Doc section "The board over chop".
  Wake-based yaw from video 01 too noisy for a wag count (upper limit 2 deg spread).

- **Board pitch from video 04 (Max: "this you can measure good in the Gruissan vid").** New tool
  `side_pitch.py`: the board's line through its purple shape against the beach's sand line
  (the boat's roll cancels), overlays checked at 12/16/25 s. 313 of 518 frames (9.5-30.2 s).
  Pitch changes faster than 1 s: 2.17 deg measured, frame-to-frame jitter ~1.0 deg -> real about
  1.5-1.9 deg spread, middle 90 % about +-2.5 deg, rhythm ~1.5 Hz (rough: longest gap-free stretch
  1.4 s). Absolute median 7.4 deg (includes rocker/outline, not a clean number). Same as the game
  on lake chop (1.2-3.2 deg), so the bouncy feel is mainly the rigid sailor + slapping wet length.
  05's "+-1 deg" was too optimistic; doc rows and 04's findings updated.

- **Reality check built (Max: "do 1").** `tools/video/reality_check.py` + `tools/video/reality_cases.json`:
  3 game runs (matrix with the nearest gear: pj_new_sealand_slalom_97 + gg_sails_slalom_5_7 at 24/30 kt,
  pj_new_sealand_slalom_117 + nielstrots_slalom_7_4 at 18/22 kt; lake chop), 7 cases, 10 strict rows.
  First run (main 19ec1cc): 1 of 10 pass (heel). Rake 14.2/11.9 deg vs 31, lean 10.2 vs 24, wet length
  1.08-1.09 m vs 0.6, gybes off the plane 0.37-1.40 s and one fall (gybe_beam 24 kt on race gear).
  Indicative: pitch close at 12:00/14:30, legs off. Row added to CLAUDE.md's commands table; doc
  subsection "The reality check: first run".

- **Gaps 1 and 2 diagnosed (Max: "1 and 2 have prio").** New tool `reality_sweep.py` (straight case,
  one override at a time). Gap 1: the player's controller steers with `Helm.steer` (rake + tilt
  together: tilt = -rake in every run, 25 deg hanging - 18 deg tilt = 7 deg lean); the autopilot uses
  `Helm.hold_rake_first` (default since U1.3). Temporary test (player_controller.gd line 1113 ->
  hold_rake_first; backed up, restored, 0 diff vs git): 117+7.4 lean 24-25 deg (real 24), rake 19-20;
  97+5.7 rake 25 (at its stop), lean 18, but wet length 1.22-1.32 m and trim ~0 (nose pressed down),
  -1.4 kn at 24 kt. CE fore-aft sweep: rake up but lean down, 31 deg needs CE at 10 % (unreal).
  max_rig_lean 40/55: lean 15-22, rake 19-24, one fall at 55. Wet length ~1.0-1.1 m in all: not the
  rig. Board mast_track/fin_box in the gear table are NOT used by the physics. Gap 2: spec 17.12 item 1
  + A-17 + the decision log already call for the two-body sailor; the default sea is swell-only
  because of the rigid sailor. Proposal order: (1) two-body sailor, (2) the lift of a realistically
  held rig / trim, (3) rake-first steering for the player + rake stop ~35 deg. Doc subsection
  "Gaps 1 and 2: the diagnosis".

- **26 Nov 2026, the sailor's forces (Max: "analyze the sailor more deeply, where the forces and moments are").** New tool `tools/video/sailor_forces.py` (joints read by eye on grids, overlays drawn back and checked, body segments after Winter 2009, moments about the feet; the whole windsurfer's pitch balance from the game's `Game/dev/pitch_budget.gd`, checked: -0.05 against the game's -0.04 m). Video 07 (1/3/5/7 s): body line 60 deg, pull 780 N = 0.94 x 85 kg, rig carries 68 %, feet 600 N at 64 deg (540 sideways, 270 down); 08 at 2.8 s: knee 129, hip 102, trunk back 20 deg. Game matches sideways; fore and aft the centre of mass must be ~0.25 m behind the tail for 0.6 m wet (game -0.04/-0.13). Max's fin note: the game's fin pushes 126-132 N up (bend tilt); stiff fin test: sailor 0.09 m forward, same wet length. MediaPipe install blocked by the permission check (asked Max). Doc tab "The sailor's forces"; backlog E01.S08 T7.

- **26 Nov 2026, evening: the sheet-in, the sail's flex, the speed.** Max's drone photo of a sail fully in; the sheet-in measured in the game (the player's auto-sheet eased the boom 20 to 39 deg below full push) and fixed in the push ladder; video 07 from ahead read for the twist (`tools/video/sail_flex.py`: 15 deg off the centreline just above the boom to 25 deg at 57 % of the luff, a head twist of about 20 deg, 16 to 26) and the mast's bend (about 0.2 m to leeward at 1.8 m above the boom); the game's sail now stalls later above 8 m/s from it. Max: the videos' boards do roughly 30 to 35 kn (an indicative case in the reality check: neither the game's flat water nor its sea is the videos' chop). Seven marked side views for the fore-and-aft balance. All in the Claude Doc's tab "The sailor's forces" and `Documentation/reports/reality_fixes/PROGRESS.md`.
