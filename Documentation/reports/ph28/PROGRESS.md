# PH28 + PH16: progress (the live state of the branch `ph28/sail-and-hull`)

Max, 28 October 2026: build the sail from the iQFOiL wind-tunnel study, combine it with the hull's wet length, "test and improve until tokens run out, save along the way". Nothing is merged without Michiel's OK. The findings and numbers are in [sail_wind_tunnel.md](sail_wind_tunnel.md).

## Steps

| # | Step | State |
|---|---|---|
| 1 | The paper committed (`Documentation/2501.13254v1.pdf`) | done, a71c5bf |
| 2 | The sail's numbers and its twist (sail model, config, autopilot, spec 2.17, tests) | done, 8584330. Four tests brought to the new sail: the catapult test sheets in at 24 kt (a 75 kg sailor now holds the 6.5 at 18 kt, as in real life); `test_race_env.gd`'s dropped board 5 m in 10 s (7 m now, 10 before) and the course policy within 270 s (245 s now, under 240 before); thin air with the twist. `tools/check.sh` passes. The validation run is in `.logs/ph28_valid.txt` |
| 3 | The measurements: push check, reach check A to D, drag budget | done (the report). The twist on against off in gusts and waves: `tools/push_check.sh --sweep=sail.twist_pressure_pa=140,0 --seconds=120 --jobs=2 --run=ph28_twist` |
| 4 | The hull: why the board rides at 1° of trim with 1.7 m wet | measured, not changed (the report's "What this means"); the levers are the rig's load path (U1.2: harness 663 N, mast foot 365 N) and the porpoising limit, both in Michiel's sailor and hull models, where U1's stop rules fired. The roadmap's PH16 has it |
| 5 | Roadmap, progress log, docs index | done, 63754be |
| 6 | `tools/test.sh validation` | run: 36 pass, 8 fail, 2 pending (before PH28: only the onset, red on purpose). The fin's pin re-pinned (below); the rest are kept red as the evidence, not loosened |
| 7 | The twist's floor (`twist_min_factor`) and the push's catapult at 24 kt | done, 1b1f2d5: the floor is 0.75, the tunnel's lowest measured share (the report's measurement 5); the push catapults again in the push check |
| 8 | The final set with the final defaults: `push_check --seconds=120 --run=ph28_final`, `reach_check`, `test.sh`, `check.sh`, `test.sh validation` (logs `.logs/ph28_final_*.txt`, status in `.logs/ph28_final_status.txt`) | done: unit 539 of 539, check passes, validation 36 pass, 8 red (the same causes; the fin re-pinned to the final floor: slip 1.74°, lift 526 N, up 18 N), the report's measurement 6 |
| 9 | Max's intuition: the flex spills upwind and keeps the power on the broad reach | checked, the report's measurement 7 (`flow_twist.py`): partly in the model already (less apparent wind on the broad reach, so less twist); the wind's own twist with height (2° upwind, 12° broad) would add about 3 % peak lift on the broad reach. Not built; with PH16 if the broad reach stays short |
| 10 | PH16, Session 58 (29 October): what holds the nose down. The tool `Game/dev/pitch_budget.gd` (the hull's and the whole windsurfer's pitch moments by source) | done, [hull_balance.md](hull_balance.md): the hull's friction and lift check out for its attitude; the trim is set by the sail's push against the sailor hanging under the boom (the harness and the mast foot do not set it); the lock is the bounce from about 1.2 to 1.3° of trim, where a 1.0 m wet part needs 1.5 to 1.8° |
| 11 | The rig's pitch following the board's with a lag (`SailorConfig.rig_pitch_follow_s`; spec 7.5, the tuning log; `test_rig_pitch_follow.gd`) | built as an option, **off** (0): at 0.3 s the 24 kt broad reach stayed steady for 40 s, but bounced the same after a minute; gusts, waves and the other reaches unchanged within 1 %. Checks with it on: unit 539 of 539 and the new test 4 of 4, check 0 failed, validation 38 pass, 6 fail (target 2 still red at 0.82°). With it off the game is the Session 57 code path bit for bit (the reach check is identical): unit 543 of 543, check 0 failed |
| 12 | The trim press that eases on the bounce it feels | measured, not built (the report's section 3): slow and stiff it is 4 to 16 % faster on the 12 and 18 kt beam reaches, steady, but bounces on the 12 kt close reach and the 24 kt broad reach. For Michiel, with the hooked-in posture (the report's section 5) |
| 13 | A slalom board (JP SL 72, Max): the outline, the scoop rocker and the thickness traced from JP's photos; tail cut-outs in the model (`BoardConfig.cutout_from_tail_m`, `cutout_depth_m`, `bottom_width_at`, off; `test_board_cutouts.gd`); `run_reach.gd` takes a point override, `hull_probe.gd` board overrides | measured (the report's sections 6 and 7): the outline alone changes nothing; with the rocker the planing reaches are 4 to 6 % faster, but from the strips' clip (528 of 908 N), against Savitsky and Brown's measured rocker loss: not trusted, for Michiel (section 8) |

## The validation run (Session 57), red tests by cause

| Cause | Test | What it says |
|---|---|---|
| The hull's drag (PH16): slower in light wind and on broad reaches | `test_skipper.gd`, the all-rounder on T1 | does not finish at 12 kt (with the floor at 0.5 also 8:04.6 at 18 kt against 8:00; in time with 0.75) |
| | `test_polar_sweep.gd`, real-world range | 7.41 m/s at 135° against 10.80 ± 20 % |
| | `test_polar_sweep.gd`, planing onset (red on purpose before) | 15.6 kn, was 13.4 (band 8 to 10) |
| | `test_living_skipper_fleet.gd`, the fleet starts | one board ("Gambler 4"; with the final floor "All-rounder 4") starts more than 20 s after the gun |
| Porpoising (Savitsky's limit for this light board, U1 agent 3) | `test_planing_wet_area.gd`, target 2 | 24 kt 135°: pitch SD 0.87° (limit 0.30) |
| | `test_rig_lean_and_fin_loading.gd`, steady on course | pitch SD 0.49° against 0.30 (0.314° with the floor at 0.5) |
| The push, measured on the legacy sail | `test_push_warning.gd` | its one run does not catapult (0 against at least 2), while the push check at the same settings catapults twice in 150 s at 100° and 120°: GP3 re-measures the dial (step 7) |
| The sail pulls harder on the 18 kt reach | `test_fin_bend.gd`, the stiff fin's pin | 559 N against 475: re-pinned (slip 1.81°, lift 559 N, up 19 N), as Session 49 did for U2 |

## Commands used

```
export GODOT=/c/Users/maxba/AppData/Local/Programs/Godot/Godot_v4.7.2-stable_win64_console.exe
tools/reach_check.sh                                    # the tunnel's sail (now the default)
tools/reach_check.sh --sail.camber=0.10 --sail.zero_lift_deg_per_camber=60 --sail.lift_slope_factor=0.9 --sail.cl_transition_gain=0.3 --sail.alpha_luff_deg=5 --sail.twist_pressure_pa=0   # the legacy sail
tools/push_check.sh --sweep=sail.zero_lift_deg_per_camber=60,20 --seconds=120 --jobs=3 --run=paper_zero_lift
tools/simulate.sh beam_reach 60 --wind_kt=18 --twa=100 --steady=1   # the drag budget
```

## To continue (for an AI session)

"Read CLAUDE.md, ROADMAP.md (PH28, PH16), then Documentation/reports/ph28/sail_wind_tunnel.md and this file. Check out `ph28/sail-and-hull`. The sail is rebuilt from the wind tunnel (spec 2.17). Session 58 measured PH16 and fixed one cause of the bounce (Documentation/reports/ph28/hull_balance.md; `Game/dev/pitch_budget.gd`). Continue with the first open step in the table above (step 12, the trim press, needs Michiel's view first), measuring with `tools/reach_check.sh` against the report's tables. Commit and update this file after every step. Physics changes need Michiel's OK before any merge."
