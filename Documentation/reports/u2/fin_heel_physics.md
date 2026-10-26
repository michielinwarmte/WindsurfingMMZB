# U2 agent 3, `fin_physics`: the heeled hull's lift, the fix (points 1 to 4)

**Branch:** `u2/fin_physics_heel`, made from `feature/u2-fin`, because an older worktree still has `u2/fin_physics` checked out. Spec: section 5 F23, 10 "U1.6", 14, 16.

1. **Wagner's climb across the heel** (`_wet_width`, `WAGNER_CUT`). Each section's depth is flattened by 2/π about its deepest point. The level vee comes out exactly as before.
   - Probe: 861 N at 1.76 m wet, 4.5° heel, 1.5° trim (was 561). The 861 needs 1.5° and no leeway; at the reach's own 1.43° and 2° leeway it is 693 N (was 445).
   - `test_hull.gd`: the 15° plate now carries 1.32 × the level lift, so its band was widened from 1.3 to 1.4.
   - Left open: λ still uses the low rail's length. At 1.76 m wet, 4.5° heel, 1.5° trim the model gives 861 N, about 25 % above TN 4187's 688; the length that carries the load differs by only 2 cm.
2. **Camber sign flipped.** Thin-airfoil theory; Savitsky 1964 and Savitsky & Brown 1976 (the 1976 paper is paywalled, not read). The effect is small: the level hull at 1.76 m goes from 1302 to 1241 N. The 1.47 × Savitsky comes from the strips on the nose rocker plus 397 N of clipped suction, not from the camber term. Reported, not changed.
3. **Heel hold.** The feet's aim stopped at level. Now the feet may press the windward rail by up to 2 × `feet_moment_max_nm` / stiffness (no new number). On the 18 kt beam reach, bank 0 / 2 / 4.5° gives a heel of 0.0 / −2.0 / −4.5° and a front of 1.20 / 1.46 / 1.70 m. With bank 0 the 24 kt broad reach bounces (0.72°), so 4.5° stays the default.
4. **Trim 2.0°:** the 24 kt broad reach bounces (0.39°), so 1.5° stays. The fronts would have been 1.63, 1.32, 1.57, 1.59 m.

**Checks:**
- Unit tests 354 of 354; `tools/check.sh` 195 files, 0 failed.
- Validation: 30 pass. The onset check is red as planned, but has moved from 12.0 to 12.7 kn (point 1 +0.5, point 2 +0.2): in the hump the wet part reaches the nose rocker and lifts less.
- U1's targets 3 and 4 are still pending: front 1.39 to 1.70 m, push 1.12 to 1.19 m, trim 1.14 to 1.47°.
- Reach check: all 9 steady (worst 0.20°), no fall, no NaN. Hips-dropped case: pitch SD 0.002°.

| Planing reach, Latest → now | Front m | Speed m/s | Planing lift N | Buoyancy N | Pitch SD ° |
|---|---|---|---|---|---|
| 18 kt 100° | 1.76 → 1.70 | 12.68 → 12.82 | 452 → 494 | 145 → 102 | 0.00 → 0.05 |
| 18 kt 135° | 1.42 → 1.39 | 12.50 → 12.56 | 688 → 693 | 100 → 91 | 0.10 → 0.10 |
| 24 kt 100° | 1.71 → 1.63 | 14.20 → 14.34 | 487 → 533 | 120 → 79 | 0.01 → 0.01 |
| 24 kt 135° | 1.71 → 1.66 | 15.86 → 16.03 | 542 → 569 | 117 → 86 | 0.25 → 0.20 |
