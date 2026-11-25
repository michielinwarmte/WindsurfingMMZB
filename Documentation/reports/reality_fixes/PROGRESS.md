# Reality fixes: progress (branch physics/reality-fixes)

Max, 25 Nov 2026: "fix the problems" (gaps 1 and 2 of the reality check first). Physics changes
need Michiel's OK before main; this branch prepares them. Worktree:
C:/Users/Max de Dikke/source/WindsurfingMMZB-reality. Measure with
`python tools/video/reality_check.py` and `python tools/video/reality_sweep.py [--chop]`.

## Where it stands (session ran out of tokens here)

- Commit 4ed1d49: the video tools + reality check (first run on main: 1 of 10 strict pass).
- NOTHING in Game/ changed yet on this branch.

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
- NEXT: set those two values in Game/config/sailor_default.tres (check personas/gear configs that
  override them: grep leg_natural), run tools/test.sh, tools/test.sh validation, tools/check.sh,
  the reality check; update PHYSICS_SPEC.md section 7.5 (the legs) + the sailor_config.gd comment;
  commit; then the roll/pitch compliance (17.12 item 1) as the second step.

## Gap 1 (rig upright, wet length): diagnosed, not fixed

- The player's controller steers with Helm.steer (rake + tilt together: tilt = -rake); the
  autopilot uses Helm.hold_rake_first (U1.3). Temporary test (undone): lean right (24-25 deg on
  117 l + 7.4) but on 97 l + 5.7 the board trims nose-down, wet length 1.22-1.32 m.
- Wet length ~1.0-1.1 m in every rig variant: the hull planing model (E01.S08).
- Board mast_track/fin_box in the gear table are unused by the physics.
- NEXT (after gap 2): the lift of a realistically held rig (the sail's upward part from the
  windward lean, the weight path, the hull lift), then rake-first for the player + rake stop ~35.
