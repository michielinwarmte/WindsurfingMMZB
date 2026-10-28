# PH28: the sail from the wind tunnel, and what it shows about the hull

Session 57, 28 October 2026, on the branch `ph28/sail-and-hull` (from `gp0/measure`). Max: "the sail needs improving ... there is a document of an iQFOiL sail of the Olympics that is fully tested in a wind tunnel ... we implement this and then later do all the other stuff"; then "1 yes try, 2 combine (the hull), 3 yes (commit the paper)"; then "test and improve until tokens run out, save along the way". Physics changes on a branch: nothing is merged without Michiel's OK.

## The source

Zhang, Bertrand, Rabaud, Augier and Fermigier (2025), *Flying shape and aerodynamics of a full-scale flexible Olympic windsurf sail*, arXiv 2501.13254 (`Documentation/2501.13254v1.pdf`; the journal version is in the Journal of Sailing Technology, doi 10.5957/jst/2026.11.1.31). A Severne HGO iQFOiL 8 m² on an Apex 490 in the 6 m by 6 m S6 tunnel at 4 to 8 m/s, rig-back 18°. Stereo cameras give the flying shape, a balance gives lift, drag and the rolling moment.

What it measured, against the game's sail as it was:

| | The game's sail (legacy) | The tunnel |
|---|---|---|
| Camber | 10 % | 6.3 to 7.6 % at the third batten, deepest at a quarter of the chord |
| Lift starts at | −6° | about −2° (also on a rigid quarter-scale model, Mok et al. 2023) |
| Lift at 5° | 0.68 | 0.37 to 0.50 |
| Peak lift | 1.42 at 18° | 0.96 to 1.08 at 16 to 20° (rigid model: 1.21 at 17°) |
| Twist | none | grows with the angle and the wind, up to 10 to 14° at 8 m/s; the top keeps lifting |
| Lift at a fixed angle as the wind rises | the same | 0.94, 0.85, 0.75 of the light-wind curve at 4, 6, 8 m/s |
| Centre of the force | 40 % of the luff | about 2.0 m above the board (41 % of the mast), about 6 % lower at 8 m/s than at 4 m/s |
| Mast head | rigid | 6 to 7 cm to leeward under load (1 % of its length) |

Its limits: only 4 to 8 m/s (8 to 16 kt of apparent wind), a race sail of 8 m², the drag doubtful by the authors' own account, the tunnel wall possibly adding lift at large angles.

## What was built

`Game/sim/sail_model.gd`, `Game/sim/config/sail_config.gd`, `Game/config/sail_default.tres`, `Game/sim/autopilot.gd`, spec section 2.17:
- The numbers: camber 0.07, zero-lift 28° per unit camber (−1.96°), lift slope factor 1.0, transition gain 0.15 (peak 1.10 untwisted), luff fade within 2°.
- The twist: `SailModel.twist_factor(q) = max(1 / (1 + q / 140 Pa), 0.5)` scales the lift below the stall, less of it at the peak (share 0.45), the separation drag, and lowers the centre of effort (0.32 × (1 − f)). `twist_pressure_pa = 0` is the rigid sail.
- The autopilot reads the same twisted curves at the pressure it feels.
- Visual only: the cloth's flutter threshold follows the new curve (`RigVisuals.FLUTTER_NONE_LOAD` 0.55 to 0.45).
- Tests: the default sail against Fig. 8a at 4, 6 and 8 m/s (within 0.08, most within 0.03); the twist; the lower centre of effort. The spec's legacy worked examples are kept on the legacy curve. The catapult test sheets in at 24 kt now: at 18 kt a 75 kg sailor holds the measured 6.5 sheeted in, as a real one does.

## Measurements

**1. Only the zero-lift angle (−6° to −2°), `tools/push_check.sh`, gusts and waves, 120 s per case** (run `paper_zero_lift`). The speed made good (VMG upwind) and the mean angle of attack:

| Wind, course | Legacy | Zero-lift −2° |
|---|---|---|
| 24 kt upwind | 4.03, 3.7° | 4.08, 5.5° |
| 24 kt beam reach | 12.57, 4.3° | 12.71, 7.0° |
| 18 kt upwind | 3.89, 5.2° | 3.89, 8.6° |
| 18 kt beam reach | 11.64, 5.9° | 11.61, 10.1° |
| 18 kt broad reach | 10.57 | 8.74 (−17 %) |
| 12 kt upwind | 2.74 | 2.16 (−21 %) |
| 12 kt beam reach | 8.89 | 8.22 (−8 %) |
| 24 kt broad reach | 14.21 | 13.51 (−5 %) |

In strong wind the sail closes 2 to 4° further at the same speed (the sailor's balance is the limit). Where the sail is the limit, the board is slower.

**2. The drag budget, 18 kt beam reach, steady, legacy sail** (`tools/simulate.sh beam_reach 60 --wind_kt=18 --twa=100 --steady=1`, means over the last 20 s): 47.5 km/h, drive 272 N = hull 198 N (skin friction 185 N) + fin 35 N + windage. The wet part is 1.4 m long. The harness carries 650 N; the one study we have (Walls and Gale 2001) measured 368 to 415 N.

**3. U1's reach check (`tools/reach_check.sh`, flat water, steady wind, 40 s per case)**, speed in m/s:

| Wind, TWA | A legacy sail | B the tunnel's sail | C B + planing buoyancy 0.5 | D B + back foot 3.0/2.5° |
|---|---|---|---|---|
| 12, 60 | 7.62 | 6.63 | 6.37 | |
| 12, 100 | 10.34 | 9.13 | 8.68 | |
| 12, 135 | 6.34 | 5.42 | 3.92 | |
| 18, 60 | 8.90 | 9.28 | 9.17 | 9.64 |
| 18, 100 | 13.17 | 13.27 | 13.29 | 13.28 |
| 18, 135 | 13.09 | 9.62 | 9.05 | 10.03 |
| 24, 60 | 9.26 | 10.19 | 9.96 | 10.23 |
| 24, 100 | 14.80 | 15.13 | 15.37 | 15.61 (pitch SD 0.32°) |
| 24, 135 | 16.45 | 14.68 (pitch SD 0.88°) | 14.51 | 15.02 (pitch SD 1.03°) |

At 18 kt on the beam reach (B) the hull's friction is 231 N of the 312 N drive. Its friction area is 0.96 m² (1.74 m wet), and its friction coefficient (0.0027) is the ITTC line's. So the area is too large, not the friction law. The trim is only 0.76°. Pressing for 3° with the back foot (D) does not move it on that reach: the rig's load on the mast foot (365 N, the harness 663 N) holds the bow down.

## What this means

The legacy sail made about twice the measured lift at small angles and a third more at the peak. That extra lift hid a hull that is too draggy at speed: its wet part is too long, because the board rides at about 1° of trim. U1 found the two reasons: Savitsky's porpoising limit for this light load is about 1.2°, and the sailor-and-rig loads (the harness, the mast foot) push the bow down (U1.2, U1.3, archived `U1_PROGRESS.md` and `Documentation/reports/u1/`). The planing buoyancy (`board.planing_buoyancy_factor` 0.5) moves the onset but wins no speed.

So the sail is now as measured. To get the speed back, the hull and the sailor's loads come next:
1. The rig's load path: harness 650 to 690 N against the measured 368 to 415 N, and the mast foot's down-push. If the harness is too high, the mast foot is too: the bow goes down, the trim is low, the wet part long.
2. The porpoising limit at the trim a real board rides at: the sailor's legs and active pitch control (U1's "sailor damping as technique"), or a sourced tail vee with its steadying effect.

The state of the work and what comes next are in `PROGRESS.md` next to this report.
