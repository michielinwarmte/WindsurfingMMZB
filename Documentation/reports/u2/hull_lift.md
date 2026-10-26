# U2 agent 6, `hull_lift`: the hull's lift under heel (diagnosis)

**Probe.** `Game/dev/hull_probe.gd` recomputes every step of `_apply_planing_lift` (`chk` 1.000). At the 18 kt reach's state (pitch 1.43°, heel 4.5°, leeway 2°, 1.76 m wet) it gives 445 N lift, 143 N buoyancy; the sim 452/145. (The brief's 533 N is the fin's column.)

**Level (2).** The model equals Savitsky: 0.91 at 1.0 m (the vee's chine-dry part counted in λ and again in the front strip's width), 1.00 at 1.4 m, 1.02 to 1.06 at 1.76 m (root in the nose rocker; clipping adds 31 % of the 2D sum). Nothing else is lost.

**Heel (3).** At 1.4 m and 1.5°: −24 % at 2°, −80 % at 4.5°, −96 % at 8°. The lift is the widest wet strip's, (w/0.72)², and at tan(heel)/tan(trim) = 3 the high rail is dry for 1.3 m: w = 0.32 m. Wagner's climb is applied to the vee only, not the heel (`_root_advance_factor` is 1 when steady). Leeway toward the low rail costs another 11 %.

**Real plate (4).** NACA TN 4187 (ntrs.nasa.gov/citations/19930085133, read 19 Oct 2026): a rolled flat plate's high chine is dry over 2b·tanφ/(π·tanτ) (eq. 2, fig. 23: Wagner's climb); roll lowers C_L at given λ and τ (effective deadrise up); moving toward the rolled-down side lowers the effective trim. At 4.5° and 1.5°: about 40 % less wet area, a third less lift, not 80 % (extrapolated: tested at 6 to 30° trim). Judge, Troesch & Perlin 2004 (J. Eng. Math. 48:279, abstract): asymmetric 2D theory holds only for small sideways/vertical speed ratios (here 1.4). Xu et al. 1998 not read; no sailing-craft data.

**Cause and options (5).** Low trim times heel. The sourced fixes A and B save 10 to 12 cm at 1.43°; the attitude is the lever: flatter (D) or more trim (E, if porpoising allows). C: no source.

| Lift (N), 12.7 m/s, trim 1.5°, no leeway: today / A / B | heel 0 | 2° | 4.5° | 8° |
|---|---|---|---|---|
| 1.0 m | 511 | 246 / 327 / 473 | 37 / 72 / 333 | 4 / 5 / 215 |
| 1.4 m | 753 | 576 / 651 / 660 | 148 / 282 / 511 | 29 / 63 / 329 |
| 1.76 m | 1303 | 896 / 943 / 818 | 561 / 861 / 688 | 194 / 405 / 500 |

| Wet length (m) carrying 597 N, leeway 2° | today | A: Wagner on the heel (TN 4187 eq. 2) | B: TN 4187 rolled plate | C: anchor on the wet width |
|---|---|---|---|---|
| D: 1.43°, level / 2° | 1.10 / 1.43 | 1.10 / 1.31 | 1.04 / 1.27 | 1.04 / 1.11 |
| 1.43°, 4.5° (the reach) | 1.76 | 1.66 | 1.64 | 1.23 |
| 1.43°, 8° | 1.97 | 1.84 | 1.84 | 1.42 |
| E: 2.0° / 2.5°, 4.5° | 1.58 / 1.33 | 1.37 / 1.15 | 1.12 / 0.88 | 0.86 / 0.71 |
