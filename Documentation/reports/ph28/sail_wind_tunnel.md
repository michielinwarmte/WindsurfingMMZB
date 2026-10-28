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
- The twist: `SailModel.twist_factor(q) = max(1 / (1 + q / 140 Pa), 0.75)` (the floor first 0.5, then the tunnel's lowest measured share, measurement 5) scales the lift below the stall, less of it at the peak (share 0.45), the separation drag, and lowers the centre of effort (0.32 × (1 − f)). `twist_pressure_pa = 0` is the rigid sail.
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

**4. The twist on against off, gusts 0.2 and waves, 120 s per case** (`tools/push_check.sh --sweep=sail.twist_pressure_pa=140,0 --seconds=120 --jobs=2 --run=ph28_twist`; the legacy column is run 1's). The speed made good (VMG upwind), and the sheet:

| Wind, course | Legacy | Tunnel curve, rigid | Tunnel curve, twisted (default) |
|---|---|---|---|
| 24 kt upwind | 4.03 | 4.08, sheet 0.86 | **4.46**, sheet 0.97 |
| 24 kt beam reach | 12.57 | 12.65, sheet 0.67 | **13.46**, sheet 0.81 |
| 24 kt broad reach | 14.21 | 13.28 | 12.76 |
| 18 kt upwind | 3.89 | 3.92 | 3.64, sheet 1.00 |
| 18 kt beam reach | 11.64 | 11.47 | 11.82, sheet 0.92 |
| 18 kt broad reach | 10.57 | 8.18 | 7.55 |
| 12 kt upwind | 2.74 | 2.42 | 1.76 |
| 12 kt beam reach | 8.89 | 7.92 | 7.16 |
| 12 kt broad reach | 5.59 | 4.25 | 4.05 |

No case fell, with any sail. In 24 kt the twisted sail is what a loose leech is for: the sailor sheets in fully and goes 7 to 11 % faster than with the legacy sail, as Max asked ("the character cannot fully close the sail"). The sheet's movement stays as calm as before (0.08 to 0.18 per second). In 12 kt the board does not get through the hump upwind: about 2.6 m/s through the water, where the hull's residuary drag peaks (`residuary_peak_froude` 0.55 on 2.4 m, 2.7 m/s).

A note on the tunnel's uniform wind: at sea the apparent wind twists with height (more than 5° upwind at 15 kt, [W-T] section 5), and the sail's own rest twist is made for it. The sim measures its angle of attack against the wind at the centre of effort, halfway up, while the tunnel measured it at the bottom section, so the sim reads the tunnel's curve a few degrees further up. That roughly makes up for the twisted wind, and nothing more is added for it.

**5. The twist's floor at 24 kt, gusts and waves, 150 s per case** (`--sweep=sail.twist_min_factor=0.5,0.65,0.8`, runs `ph28_floor_push` with GP0's push at the top of the dial, `ph28_floor_neutral` without). Speed made good (m/s) and falls:

| Floor | Pushed 100° | Pushed 120° | Pushed 135° | Neutral 100° | Neutral 120° | Neutral 135° |
|---|---|---|---|---|---|---|
| 0.5 | 14.71, 0 | 14.44, 0 | 12.77, 0 | 13.48, 0 | 14.36, 0 | 12.79, 0 |
| 0.65 | 14.55, 0 | 14.56, 0 | 12.80, 0 | 13.33, 0 | 14.44, 0 | 12.78, 0 |
| 0.8 | 14.31, 0 | 11.37, 4 catapults | 12.92, 0 | 13.09, 0 | 14.45, 0 | 12.85, 0 |

With 0.5 pushing at 24 kt had no risk at all, which is not real and takes package A's point away. The floor is now 0.75, the lowest share the tunnel measured: the twist is not extrapolated beyond the data. With it, the push again catapults (run `ph28_push_harder`, 24 kt): at hike_share 1.6 twice in 150 s on both the 100° and the 120° reach (12.54 and 12.70 m/s made good), at 2.0 and 2.5 three or four times. GP0's own validation test (`test_push_warning.gd`, one 150 s run at 24 kt 120°) saw none in its gust sequence; GP3 re-measures the dial on this sail anyway, since GP0's settings were found on the legacy one.

**6. The final defaults (the floor 0.75), `tools/push_check.sh --seconds=120 --jobs=3 --run=ph28_final`, gusts 0.2 and waves.** Speed made good (VMG upwind) against the legacy sail of run 1, the mean angle of attack and the sheet:

| Wind | Upwind (48°) | Beam reach (100°) | Broad reach (135°) |
|---|---|---|---|
| 24 kt | 4.30, **+7 %**, 7.3°, sheet 0.90 (legacy 3.7°, 0.84) | 13.05, **+4 %**, 9.4°, 0.73 (legacy 4.3°, 0.64) | 12.74, −10 % |
| 18 kt | 3.90, 0 %, 10.8°, 0.99 (legacy 5.2°) | 11.56, −1 %, 14.5°, 0.88 (legacy 5.9°) | 7.55, −29 % |
| 12 kt | 1.76, −36 % | 7.16, −19 % | 4.05, −28 % |

No case fell; the sheet's movement stays 0.07 to 0.18 per second, as calm as before. The reach check (flat, steady) with the final defaults: 24 kt 100° 15.20 m/s (legacy 14.80), 18 kt 100° 13.08 (13.17), 18 kt 135° 9.62 (13.09), 12 kt 100° 9.21 (10.34). The unit tests pass (539 of 539), `tools/check.sh` passes, and validation keeps the eight red tests of the progress file, all from the hull or the re-measured push.

**7. Max's intuition, checked (28 October): "the flex in the sail lets more pressure go upwind and keeps more power on the broad reach".** The physics agrees, in two ways (`flow_twist.py` next to this report; the board speeds are those of measurement 6):

- *The apparent wind.* On the broad reach the board runs away from the wind, so the sail meets less of it, and the twist grows with the wind's pressure. This is in the model already. At 18 kt the sail keeps 0.87 of its rigid lift on the broad reach (5.9 m/s apparent) against 0.75 upwind (12.4 m/s); at 12 kt 0.94 against 0.82. At 24 kt both keep 0.75, the floor: upwind the formula would give 0.49, but the tunnel measured nothing below 0.75 (measurement 5).
- *The wind's own twist with height* ([W-T] section 5, which the tunnel cannot make). The wind is slower near the water, so at the top of the sail the apparent wind comes from further aft. Over the sail (0.8 to 4.2 m above the water, the sim's profile with exponent 0.11) it turns about 2° upwind, 6° on the beam reach and 12° on the broad reach. The sail's own twist at full power in the tunnel's straight wind is 8 to 14° (Fig. 6: about 0.44, 0.62 and 0.72 degree of twist per degree of angle of attack at 4, 6 and 8 m/s, between the two cambers). On the broad reach the wind's twist fills the sail's, so the top keeps working; upwind it does not, and the top spills.

The sim reads the angle of attack halfway up, which takes the wind's twist in on average, so the lift below the stall is right. What it misses is the shape of the load: a sail whose twist fits the wind reaches more of its peak and keeps its centre of effort up. An estimate of the size: the loose top twists further when it meets more wind, so it fills a half to three quarters of the gap (the gap's share left is 1 − (1 − r) × wind twist / sail twist, r the twist per degree). That is about 3 % more peak lift on the broad reach at 18 and 24 kt (0.94 to 0.97, 0.89 to 0.92), the centre of effort about 2 % higher there, and no change upwind. Not built: it is small against the broad reach's 10 to 29 %, which is the lower measured peak meeting the hull's drag (measurements 2 and 3). It belongs with PH16, if the broad reach is still short once the hull is right.

## What this means

The legacy sail made about twice the measured lift at small angles and a third more at the peak. That extra lift hid a hull that is too draggy at speed: its wet part is too long, because the board rides at about 1° of trim. U1 found the two reasons: Savitsky's porpoising limit for this light load is about 1.2°, and the sailor-and-rig loads (the harness, the mast foot) push the bow down (U1.2, U1.3, archived `U1_PROGRESS.md` and `Documentation/reports/u1/`). The planing buoyancy (`board.planing_buoyancy_factor` 0.5) moves the onset but wins no speed.

So the sail is now as measured. To get the speed back, the hull and the sailor's loads come next:
1. The rig's load path: harness 650 to 690 N against the measured 368 to 415 N, and the mast foot's down-push. If the harness is too high, the mast foot is too: the bow goes down, the trim is low, the wet part long.
2. The porpoising limit at the trim a real board rides at: the sailor's legs and active pitch control (U1's "sailor damping as technique"), or a sourced tail vee with its steadying effect.

The state of the work and what comes next are in `PROGRESS.md` next to this report.
