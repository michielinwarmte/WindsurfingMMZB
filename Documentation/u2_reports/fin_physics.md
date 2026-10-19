# U2 agent 3, `fin_physics`: report

**Done** on `u2/fin_physics`, by the lead's design. `FinModel` works out the beam once at `_init`: 20 strips, `EI = S c^4`, an elliptic load whose strip moments are exact. Each step scales its slopes by the lift (capped at 35°) and tilts the lift. `S` = 2.23·10⁵ N/m² (86 N·m² at the root). `bends = false` is the old fin, bit for bit: with `--fin.bends=0` the reach check equals U1's Latest. Unit tests 352/352 (9 new); check 0 failed; validation 30 pass, 2 pending, 1 fail (the onset, 11.6 → 12.0 kn). The bend check passes.

**Where I departed from the design (please review):** calibrating `S` on the current fin would give the 44 cm fin another material. So the test fin has its own size, `flex_test_span_m`/`flex_test_area_m2` (0.38 m, 0.0365 m²), and the 44 cm fin keeps the same `S`. `root_chord_m()` is a function. The chord law's mean is 0.6846, not 0.686 (no effect: `S` absorbs it).

**Target 1:** steady in 9 of 9 (worst pitch SD 0.25°), no fall, no NaN, the polar inside its ranges. The costs: speeds up to 1.1 % lower, trims up to 0.28° lower.

**(c) The fin's lift makes the wet part longer, not shorter.** The push at the tail pitches the bow down. The wet front moves 0 to 9 cm forward. The stance does not answer it.

**Target 4:** the 44 cm fin pushes up more, rolls more, slips less and works further from its stall (19 against 21 % of it). The feet hold the heel at -4.5° (U1.6).

**Sourced:** the flex test, the 44 cm area. **Estimates:** the planform, the test fin's size, the cap. **Not my files:** the Blender script's old root chord, and the tip on the HUD (agent 4).

| 18 kt beam reach | Tip ° | Tip mm | Tilt ° | Up N | Slip ° | Roll N·m | Heel ° | Wet front m | Harness N |
|---|---|---|---|---|---|---|---|---|---|
| 38 cm stiff | 0 | 0 | 0 | 41 | 1.98 | 111 | -4.5 | 1.71 | 683 |
| 38 cm flex | 14.0 | 59 | 7.8 | 113 | 2.03 | 111 | -4.5 | 1.76 | 685 |
| 44 cm flex | 21.3 | 103 | 11.9 | 151 | 1.79 | 124 | -4.5 | 1.79 | 682 |
