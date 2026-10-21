# U1 agent 1, `measure`: report

**Done (U1.1), on `u1/measure`:**
- `tools/reach_check.sh` (runner `Game/dev/run_reach.gd`) runs the 9 cases, one line each, in 50 s. Its numbers equal `simulate.sh beam_reach … --steady=1 --gradient=0`. A `--board.<field>` override also reaches the buoyancy grid.
- Telemetry has `friction_area_m2`, `wet_front_m` and `push_centre_m`. The HUD shows them, plus harness and mast-foot load (screenshot checked).
- `test_planing_wet_area.gd`: targets 2 to 4 are `pending` with numbers, and match the reach check. Agent 4 sets `TARGETS_ARE_CHECKS = true`.
- The baseline is in U1_PROGRESS.md: 188 files, 335 of 335, 20 of 20, the straight runs, the lake.

**Findings**
1. The baseline already misses target 2 in 5 of 9 cases: close reaches at 1.1 to 1.2 Hz, the 12 kt beam reach at 1.55 Hz.
2. The grid check: 13 rows move the 18 kt beam reach's wet front by **−34 cm** (and it bounces), and the 24 kt beam reach's by +7 cm. That is over 5 cm, so it goes to the team.
3. Agent 3's `--board.tail_rocker_m=0` gives nearly the same as the real flat tail: within 4 cm and 0.2°.

**U1.4, the flat tail: stopped and reverted** (54282ee, reverted in d55bd6a). Validation was 20 of 20 and the straight runs had no fall, but two stop rules fired:
- Two `test_buoyancy.gd` tests fail, a file outside my list. One pins the 1 cm kick. The other's "still bouncing after 4 s" height check misses only by phase: both tails tumble to 30 to 40° undamped, and its energy checks pass.
- The 18 kt broad reach settles bow-down (pitch −1.05°, 0.9 m/s slower). This is only partly explained: the feet press the bow down harder (−167 N·m), which is U1.3's open question.

To bring it back: `git revert d55bd6a`, then update both tests.

| 18/24 kt, 100°/135° | Baseline | Flat tail | Target |
|---|---|---|---|
| Wet front, m | 1.87, 1.66, 1.82, 1.81 | 1.88, 2.12, 1.83, 1.81 | 0.6 to 1.0 |
| Push centre, m | 1.58, 1.27, 1.56, 1.62 | 1.59, 1.15, 1.57, 1.63 | 0.45 to 0.75 |
| Trim, ° | 0.93, 0.76, 0.70, 0.37 | 1.21, −0.06, 0.99, 0.64 | 1.5 to 4 |
| Steady (all 9) | 4 of 9 | 6 of 9 | 9 of 9 |
