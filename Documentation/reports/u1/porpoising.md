# U1, agent 3 `porpoising`: report

**The cause.** The 1.8 Hz bounce is the hull's own pitch-and-heave instability: porpoising as in Day & Haag (1952) and Savitsky (1964). The board porpoises once its trim (the pitch of the flat bottom) rises above Savitsky's critical trim for its load (the chart fit coded in OpenPlaning; 2° deadrise, √(C_L/2) 0.11 to 0.14). In the onset sweeps, steady turns to bouncing within about 0.2° of that limit at 12, 18 and 24 kt. The mast-foot load guards only by holding the trim just below it: the default 18 kt reach rides at 0.97° against 1.25°. Lighten it, and the push moves aft and the trim passes the limit.

**Not the cause** (each switched alone): the legs, the trim press, the steering, a 13-row grid, 16 substeps, the spray-root cap, the tail kick (the flat tail bounces the same). The pitch reflex damps it (off: twice the bounce); freezing the sailor or adding lift lag makes it worse. Two runs bounce below the limit: the frozen sailor on the flat tail (1.17° against 1.25°, heading wandering), and feet at 0.4 m (a 0.65 Hz swing).

**For agent 4. Stop rule: a source contradicts a target.** For the targets' wet part (0.6 to 1.0 m) at 13 to 16 m/s, Savitsky's limit for a 2° bottom is 0.9 to 2.2°. Most of target 4's band (1.5 to 4°) lies above it, so targets 2 and 4 conflict. Tail vee raises the limit (5°: about 2.0°; 10°: 2.6°), but the game's flat strips miss that: 10° of deadrise still bounces. Options: a sourced tail vee, with its steadying effect in the hull model; a trim target below the limit; sailor damping as technique.

**Method.** Overrides; for the grid and substeps a copy of `run_scenario.gd` outside git. CSVs: `.sim_output/porp/`.

| Run, 18 kt beam reach, flat water | Pitch SD (°) | Hz | Mean pitch / limit (°) |
|---|---|---|---|
| Default | 0.00 | – | 0.97 / 1.25 |
| Hips 0.15 m (the bounce) | 0.55 | 1.78 | 1.49 / 1.22 |
| Same, flat tail | 0.53 | 1.77 | 1.42 / 1.20 |
| + legs 0.6 or 2.5 Hz, damping ratio 0.3 or 2.0 | 0.43 to 0.55 | 1.78 to 1.91 | 1.38 to 1.51 / 1.2 |
| + trim press off | 0.46 to 0.57 | 1.83 to 1.86 | 1.50 to 1.52 / 1.25 to 1.26 |
| + pitch reflex off | 0.90 to 1.18 | 1.42 to 1.56 | 1.52 to 1.70 / 1.21 to 1.28 |
| + sailor frozen from 10 s | 0.64 to 1.05 | 1.56 to 1.79 | 1.17 to 1.44 / 1.25 to 1.29 |
| + lift lag 0.05 s (at 0.15 s it drops off the plane) | 0.65 | 1.71 to 1.76 | 1.49 to 1.59 / 1.17 to 1.20 |
| + grid, substeps, spray-root cap, steering gains | 0.35 to 0.63 | 1.54 to 1.85 | 1.36 to 1.83 / 1.2 |
| + deadrise 10° (Savitsky's limit: about 2.5°) | 0.45 | 1.58 | 1.82 / 2.5 |
| Onset sweep, 12 kt, flat tail: last steady → first bouncing | 0.00 → 0.93 | 1.57 | 1.73 → 1.89 / 1.87 → 1.82 |
| Onset sweep, 18 kt, flat tail | 0.00 → 0.52 | 1.77 | 1.19 → 1.24 / 1.22 → 1.18 |
| Onset sweep, 18 kt, current tail | 0.01 → 0.57 | 2.10 | 0.98 → 1.26 / 1.25 → 1.20 |
| Onset sweep, 24 kt, flat tail | 0.00 → 0.41 | 1.81 | 1.12 → 1.19 / 0.98 → 0.97 |
