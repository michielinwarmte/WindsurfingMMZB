# U1 agent 4, `physics`: U1.2 and U1.3 (report)

**Done** (spec 5, 7.5, 10, 14, 16) on `worktree-agent-a211b44dc916c6718`, which contains `u1/physics`.
- **U1.3.** The feet's bow-down 117 N·m was the trim press: it moved only where the legs push, aft of a body that stayed put. The board feels the weight at the centre of mass, so the body now goes with the press, the hang-back measured from the feet: the sailor leans back 0.47 m, the feet pass 32 N·m bow-up, within the legs' 60 to 100 N·m. New test. `running_trim_deg` 2 → 1.5 (Gourlay), else the 18 kt broad reach bounced.
- **U1.2.** Full lean is agent 2's 45° stance (`lean_max_m` 0.88, `lean_height_drop_m` 0.28), not a full hike: 954 → 683 N, 91 → 63 %, line 1.44 → 0.77 m.
- **Retest (a): rake-first on.** No bow-down; close reaches 4 to 8 % faster. The rake still sits at its stop.
- **Retest (b): factor 0.5 off.** The 24 kt broad reach bounces (0.83°).

**Stop rule: targets 3 to 5 conflict with statics.**
1. Hooked in, the arms only steer, so the line carries the boom force: 600 to 750 N at 18 kt. 415 N needs two thirds of the sail force the pilot holds.
2. The push sits ahead of the weight (0.47 m from the tail) by the drive's couple: 280 N × 1.9 m / 800 N = 0.66 m.

Still off: wet front by 0.4 to 0.7 m, push 0.33 to 0.39 m, harness 203 N, rig 13 points; pending.

**For Michiel:** a pilot that sheets to a normal stance (slower), or targets for one 6.5 m² sail. The stance costs the close reaches 3 % and lengthens their wet part (full hike: 843 N, 73 %).

**Checks:** unit 343 of 343; check 0 failed; validation fails only the onset (11.6 kn, was 12.7).

| Reach check | 12/60 | 12/100 | 12/135 | 18/60 | 18/100 | 18/135 | 24/60 | 24/100 | 24/135 |
|---|---|---|---|---|---|---|---|---|---|
| Speed m/s, Latest → now | 7.80 → 7.58 | 10.28 → 10.30 | 5.73 → 6.41 | 9.00 → 8.70 | 12.28 → 12.74 | 11.23 → 12.55 | 9.37 → 9.06 | 13.79 → 14.31 | 15.58 → 16.04 |
| Front / push m | 1.87 / 1.43 | 1.82 / 1.32 | 1.95 / 0.86 | 1.76 / 1.25 | 1.71 / 1.13 | 1.39 / 1.10 | 1.71 / 1.19 | 1.65 / 1.08 | 1.66 / 1.14 |
| Trim °, pitch SD ° | 2.11, 0.00 | 1.77, 0.00 | 2.54, 0.05 | 2.10, 0.01 | 1.64, 0.00 | 1.53, 0.09 | 2.17, 0.00 | 1.67, 0.01 | 1.45, 0.26 |
| Harness N, rig % | 708, 81 | 705, 79 | 185, 16 | 666, 71 | 683, 63 | 500, 55 | 647, 66 | 695, 57 | 706, 60 |
