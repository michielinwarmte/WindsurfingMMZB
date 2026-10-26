# U2 agent 2, `fin_measure`: report

**Done** on `u2/fin_measure`, with no physics changed.
- `--fin.<field>=` in `simulate.sh` and `reach_check.sh`, set on a copy of the fin before the simulation is built, so agent 3's bend sees the new size.
- Telemetry and CSV: `fin_up_n` (world-upward part of the fin's force), `fin_load_share` (|cl| over its peak), `fin_tilt_deg` (worked out from the force, so agent 3's tilted force shows up there on its own), `fin_bend_tip_deg` (0).
- HUD fin line: "load 27 % of stall, up 66 N" (checked on a screenshot). Reach check: slip, lift, roll, up, stall %, heel.
- `test_fin_bend.gd`: the stiff fin at 18 kt on 100° pinned (slip 1.98 ± 0.25°, lift 526 N ± 5 %, up 40.9 ± 10 N, force in the board's plane); the bend pending.
- Baseline in U2_PROGRESS.md. Validation: 29 pass, 1 fail (the onset), 3 pending.

**Findings (stiff fin):**
- The heel alone lifts about lift × sin(heel). The fin works at 13 to 20 % of its stall on the planing reaches.
- 44 cm fin, area scaled by the same planform to 0.0489 m² (no catalogue number on this branch): the slip drops by a quarter and the roll moment rises 13 %. The upward force stays the same, because the heel does. Stiff, it lifts more only by heeling more.
- Bank 0 to 24°: up 20 to 243 N, and the sailor never falls. 18 kt on 100°: steady to 20°, wobbling at 24° (pitch SD 0.69). 24 kt on 135°: the heel falls short of the bank, and the board wobbles from 8°.

**For the lead:** agent 3's file list leaves out the telemetry block, and `fin_bend_tip_deg` needs one line in `windsurfer_sim.gd`. `_stiff_fin()` in the test should become the stiff limit.

| Run | Case | Speed m/s | Heel ° | Slip ° | Lift N | Roll N m | Up N | Stall % | Pitch SD ° |
|---|---|---|---|---|---|---|---|---|---|
| default (bank 4.5) | 18/100 | 12.74 | -4.5 | 2.0 | 527 | 111 | 41 | 20 | 0.00 |
| default | 24/135 | 16.04 | -4.2 | 1.2 | 520 | 110 | 37 | 13 | 0.26 |
| 44 cm | 18/100 | 12.67 | -4.5 | 1.5 | 532 | 125 | 41 | 16 | 0.00 |
| 44 cm | 24/135 | 15.82 | -4.0 | 0.9 | 507 | 119 | 35 | 9 | 0.31 |
| bank 0 | 18/100 | 12.98 | -2.4 | 1.8 | 497 | 105 | 20 | 19 | 0.01 |
| bank 0 | 24/135 | 16.57 | -2.4 | 1.1 | 516 | 109 | 21 | 12 | 0.30 |
| bank 8 | 18/100 | 12.66 | -8.0 | 2.2 | 569 | 120 | 79 | 22 | 0.00 |
| bank 8 | 24/135 | 15.64 | -6.2 | 1.3 | 507 | 107 | 56 | 13 | 0.38 |
| bank 12 | 18/100 | 12.57 | -12.0 | 2.3 | 599 | 126 | 124 | 24 | 0.00 |
| bank 12 | 24/135 | 15.34 | -8.5 | 1.3 | 496 | 104 | 75 | 13 | 0.57 |
| bank 16 | 18/100 | 12.39 | -16.0 | 2.4 | 608 | 128 | 167 | 25 | 0.04 |
| bank 16 | 24/135 | 15.07 | -10.4 | 1.3 | 478 | 100 | 89 | 13 | 0.80 |
| bank 20 | 18/100 | 12.23 | -20.0 | 2.5 | 600 | 126 | 205 | 25 | 0.04 |
| bank 20 | 24/135 | 14.82 | -12.7 | 1.3 | 475 | 100 | 108 | 14 | 0.80 |
| bank 24 | 18/100 | 12.28 | -24.0 | 2.5 | 597 | 126 | 243 | 25 | 0.69 |
| bank 24 | 24/135 | 14.59 | -15.1 | 1.4 | 476 | 100 | 129 | 14 | 0.77 |
