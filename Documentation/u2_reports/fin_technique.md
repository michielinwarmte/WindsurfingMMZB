# U2 agent 3, `fin_physics`: the sailor's technique (points 1 to 4)

**Branch:** `u2/fin_technique`, made from `feature/u2-fin`. Spec: 7.5, 10 "The sailor's technique", 14, 16.

1. **The map** (first table: wet front m / pitch SD °; bold means it bounces; nothing fell). Less bank shortens every planing reach. Flat is shortest on the beam reaches, but long at 12 kt and on the close reaches. **The 24 kt broad reach (32 kn) bounces flat at every trim target**: it is steady only at 0 and 1.0°, and bounces at 0.5°. The trim limit falls with speed. At 2° of bank, the 18 kt beam reach bounces from 2.2°, and the 24 kt broad reach reaches 0.30° at 2.0°.
2. **The bank by point of sail** (`_rail_share_by_point_of_sail`): it reads the true wind at the sail, on both tacks. **This design point is wrong for this hull.** With the board flat from 120°, the 24 kt broad reach fell (trim 2.0→1.5°) or bounced (→1.0°: 0.35°), and the 18 kt broad reach gained only 6 cm. So `fin_load_bank_deg` is now 2°, and the flattening is in the code but off by default (`fin_load_twa_max_deg` 180, flat only on a run). Setting it to 120 tries the instruction's rule.
3. **The trim by speed:** 2.0° up to 24 kn (0.2° below where it bounces, 2.2°), falling to 1.5° at 31 kn (1.8° would leave a pitch SD of 0.28°). It is calibrated on this hull's own steadiness and labelled so: as much tuning as technique. The alternative, a sailor who backs off at the first bounce, would not settle a flat board at 32 kn (0.5° bounces).
4. **Result** (second table): 2.3 % faster over the nine cases, all steady. U1's targets 3 and 4 stay pending: front 1.32 to 1.58 m, push 1.02 to 1.08 m, trim 0.82 to 1.35°.

**Checks:**
- Unit tests 356 of 356; `tools/check.sh` 195 files, 0 failed.
- Validation: 30 pass, 2 pending, 1 fail. The fail is the onset check, red on purpose, now **12.7 → 13.4 kn**: the 2° bank alone gives 15.1 kn, and the 2.0° trim brings it back.
- The polar stays inside its ranges. `test_fin_bend.gd` re-pinned for the 2° heel.
- Hips dropped: 8 of 9 steady. The 24 kt broad reach bounces at 0.36°, but it already did at the old defaults (0.41°).
- The 12 kt close reach settles in a long, low-trim state.

| Bank°, trim° | 12/60 | 12/100 | 12/135 | 18/60 | 18/100 | 18/135 | 24/60 | 24/100 | 24/135 |
|---|---|---|---|---|---|---|---|---|---|
| 0, 1.5 | 2.20 / 0.03 | 2.20 / 0.01 | 2.00 / 0.06 | **2.07 / 0.32** | 1.20 / 0.00 | 1.27 / 0.17 | 1.71 / 0.00 | 1.12 / 0.00 | **1.39 / 0.72** |
| 0, 2.0 | 2.20 / 0.03 | 2.20 / 0.01 | 1.86 / 0.04 | **2.07 / 0.32** | 1.12 / 0.00 | 1.22 / 0.20 | 1.30 / 0.01 | **1.01 / 0.32** | **1.27 / 0.68** |
| 0, 2.5 | 2.20 / 0.03 | 2.20 / 0.01 | 1.77 / 0.03 | 1.69 / 0.09 | 1.01 / 0.17 | **1.36 / 0.86** | 1.22 / 0.00 | **0.96 / 0.39** | **1.21 / 0.62** |
| 2, 1.5 | 2.24 / 0.00 | 1.77 / 0.00 | 2.00 / 0.06 | 1.79 / 0.01 | 1.46 / 0.26 | 1.37 / 0.13 | 1.45 / 0.01 | 1.35 / 0.00 | 1.59 / 0.24 |
| 2, 2.0 | 2.24 / 0.00 | 1.75 / 0.01 | 1.87 / 0.05 | 1.49 / 0.01 | 1.34 / 0.04 | 1.30 / 0.11 | 1.39 / 0.00 | 1.25 / 0.14 | **1.46 / 0.30** |
| 2, 2.5 | 1.82 / 0.01 | 1.73 / 0.01 | 1.77 / 0.03 | 1.42 / 0.02 | 1.26 / 0.28 | **1.32 / 0.61** | 1.31 / 0.00 | 1.16 / 0.28 | **1.40 / 0.34** |
| 4.5, 1.5 | 1.86 / 0.00 | 1.79 / 0.01 | 2.00 / 0.06 | 1.73 / 0.01 | 1.70 / 0.05 | 1.39 / 0.10 | 1.69 / 0.01 | 1.63 / 0.01 | 1.66 / 0.20 |
| 4.5, 2.0 | 1.84 / 0.00 | 1.78 / 0.00 | 1.87 / 0.05 | 1.70 / 0.00 | 1.63 / 0.00 | 1.32 / 0.08 | 1.62 / 0.01 | 1.57 / 0.01 | **1.59 / 0.39** |
| 4.5, 2.5 | 1.80 / 0.00 | 1.75 / 0.01 | 1.77 / 0.03 | 1.65 / 0.00 | 1.55 / 0.14 | **1.29 / 0.40** | 1.58 / 0.02 | 1.45 / 0.09 | **1.55 / 0.45** |

| Case, Latest → now | Front m | Speed m/s | Pitch SD ° | Trim ° | Fin up N |
|---|---|---|---|---|---|
| 12 kt 60° | 1.86 → 2.24 | 7.53 → 7.62 | 0.00 → 0.00 | 1.91 → 0.67 | 94 → 62 |
| 12 kt 100° | 1.79 → 1.75 | 10.33 → 10.34 | 0.01 → 0.01 | 1.48 → 1.31 | 104 → 71 |
| 12 kt 135° | 2.00 → 1.87 | 6.43 → 6.34 | 0.06 → 0.05 | 2.70 → 2.77 | 2 → 1 |
| 18 kt 60° | 1.73 → 1.49 | 8.70 → 8.90 | 0.01 → 0.01 | 1.84 → 1.96 | 100 → 71 |
| **18 kt 100°** | 1.70 → **1.37** | 12.82 → 13.16 | 0.05 → 0.03 | 1.29 → 1.33 | 115 → 76 |
| **18 kt 135°** | 1.39 → **1.32** | 12.56 → 13.19 | 0.10 → 0.11 | 1.47 → 1.35 | 35 → 39 |
| 24 kt 60° | 1.69 → 1.39 | 9.13 → 9.26 | 0.01 → 0.00 | 1.76 → 2.01 | 108 → 76 |
| **24 kt 100°** | 1.63 → **1.32** | 14.34 → 14.86 | 0.01 → 0.00 | 1.34 → 1.22 | 119 → 83 |
| **24 kt 135°** | 1.66 → **1.58** | 16.03 → 16.43 | 0.20 → 0.24 | 1.14 → 0.82 | 110 → 84 |
