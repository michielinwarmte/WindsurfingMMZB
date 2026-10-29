# PH16: what holds the board's nose down, and the rig that bounced

Session 58, 29 October 2026, on the branch `ph28/sail-and-hull`. Max: "do the hull physics upgrade. this is the lock to the better physics right now. with the new sail working together". Physics changes on a branch: nothing is merged without Michiel's OK.

**In short.** The hull's own physics checks out: its friction and its lift are what planing theory (ITTC, Savitsky) gives for this board at the attitude it rides at. The long wet part (1.7 m on the 18 kt beam reach) comes from two other things. First, the balance of the whole windsurfer: the sail's push, high up and behind, holds the nose down, and only the sailor's weight lifts it. Second, the bounce: the board starts to porpoise at about 1.2 to 1.3° of trim, and it needs 1.5 to 1.8° to ride on 1.0 m. Letting the sailor press the tail for a higher trim gains 4 to 16 % where the board stays steady, but it starts new bounces elsewhere. It is measured below and not built. One suspect for the bounce was in the model: the rig pitched with every bounce of the board, where a real mast foot is a joint. A lag on the rig's pitch is built as an option, but **it is off**. It kept the 24 kt broad reach steady for 40 s, and that looked like a fix, but after a minute the board bounced the same. Nothing in the game changes in this session.

## The tool

`Game/dev/pitch_budget.gd` (a dev tool, outside `Game/sim/`) sails one reach-check case and, over the last 5 s, takes every substep apart. It makes the same calls as `WindsurferSim.step`, in the same order, and reads the hull's torque after each force model. It prints the hull's pitch moments by source, the whole windsurfer's moments about the water's push, and the forces and positions. Run it with `tools/godot.sh --path Game --headless -s res://dev/pitch_budget.gd -- --wind=18 --twa=100` and any `--sailor.<field>=` style override.

## 1. The hull itself is right for its attitude

- **The friction law.** Its coefficient is 0.0026 at a Reynolds number of 2.2·10⁷, which is the ITTC line.
- **The friction area.** I checked whether a heeled board's dry high rail was missing from it. It is not: the wet widths the lift uses, integrated along the wet part, give 0.94 m² against the friction's 0.93 m² (18 kt beam reach; 0.72 against 0.70 on the 24 kt broad reach; 1.05 against 1.01 at 12 kt). Wagner's climb (U2) already wets nearly the whole width.
- **The lift.** U2's probe (`Game/dev/hull_probe.gd`) gives the wet length that carries the hull's 615 N at 13.1 m/s. "Wet" and "TN 4187" are the sourced what-ifs: Savitsky's lift on the wet width, and the rolled-plate measurement.

| Trim | Level hull: model / Savitsky on the wet width | 2° of heel: model / wet width / TN 4187 |
|---|---|---|
| 1.0° | 1.51 / 1.51 m | 1.65 / 1.64 / 1.71 m |
| 1.2° | 1.25 / 1.23 m | 1.48 / 1.33 / 1.54 m |
| 1.5° | 1.04 / 0.97 m | 1.25 / 1.03 / 1.17 m |
| 1.8° | 0.89 / 0.81 m | 1.11 / 0.84 / 0.95 m |
| 2.2° | 0.71 / 0.66 m | 0.93 / 0.68 / 0.77 m |

On a heeled board at 1.5 to 2.2° the model's wet part is 7 to 20 % longer than TN 4187's. That is a real but second-order gap, for when the board rides that high. At the trim it rides at today (about 0.9 to 1.0°) the model and the sources agree. **So a 1.0 m wet part needs 1.5 to 1.8° of trim.** U1's target of 0.6 to 1.0 m needs 1.5 to 2.2°.

## 2. What sets the trim: the whole windsurfer's balance

18 kt beam reach, flat water, steady wind (the reach check's case): 13.09 m/s, trim 0.89°, 1.70 m wet, centre of the water's push 1.12 m from the tail. Pitch moments about the push, N·m (+ lifts the bow):

| Source | N·m | Why |
|---|---|---|
| The sail | −678 | its forward 302 N acts 1.51 m up (−456), and its upward 211 N (the rig leans 25° to windward) acts 1.05 m behind the push (−222) |
| The sailor's weight | +712 | 735 N at 0.17 m from the tail, 0.95 m behind the push |
| The fin | −61 | its upward 88 N (2° of leeward heel) behind the push |
| The windage, the rig's and the hull's weights, the buoyancy | the rest | small |

**The harness and the mast foot do not set the trim.** They pass loads between the sailor, the rig and the board, inside the windsurfer, and those cancel. What counts is where the sailor's weight is and where the sail's force acts. This corrects Session 57's first lever, that a lighter harness would lighten the mast foot and free the bow. It would change the trim only by moving the sailor.

**The sailor hangs under the boom.** The harness carries 65 % of the sailor's weight (hands up 478 N, the harness line 660 N), so the weight sits below the boom grip wherever the feet stand. Moving the feet back makes it worse:

| `stance_planing_z_m` (feet from the tail) | 18 kt 100°: speed, wet, push, trim | 24 kt 100° |
|---|---|---|
| 0.60 (default) | 13.08 m/s, 1.70 m, 1.12 m, 0.95° | 15.20, 1.44, 1.03, 1.01° |
| 0.45 | 12.99, 1.76, 1.24, 0.81° | 14.72, 1.73, 1.12, 0.65° |
| 0.35 | 13.00, 1.78, 1.29, 0.60° | 14.66, 1.76, 1.21, 0.58° |

The boom grip is where the rig's rake puts it, and the rake is the autopilot's steering. To hold the course the rig is raked back 19 to 23° (rake 0.77 to 0.93 of 25°). That puts the centre of effort 0.07 to 0.17 m from the tail, behind the fin, against the bear-away push of the drive, which acts 0.48 m to windward. **At 12 kt on the beam reach the grip is 0.23 m behind the sailor's hips, and the harness pulls the sailor backwards (−82 N).** A hooked-in sailor would not hold that: they hang behind the boom. This is Michiel's item (below): the posture and the rake.

On the 18 kt broad reach (135°) the rig stands upright (rake 0.02), the sailor hangs behind the grip and is pulled forward (132 N). The board rides at 2.5°, near its bounce. There the speed is limited by the sail's drive, 159 N at the tunnel's peak lift.

## 3. The lock: the bounce

Pressing the tail harder shows both the gain and the lock. These are reach-check runs, flat water, steady wind, with speed in m/s and pitch SD (the bounce) in degrees.

| Case | Default | Stiffer press (band 0.25°, reach 0.6 m) | The same, slow (0.02 m/s) and rig lag 0.3 s |
|---|---|---|---|
| 12 kt 100° | 9.21, 0.01 | 10.34, 0.13 | **10.72, 0.03** (+16 %) |
| 18 kt 100° | 13.08, 0.00 | 13.60, 0.45 | **13.63, 0.01** (+4 %, 1.29° on 1.31 m) |
| 18 kt 135° | 9.62, 0.05 | 9.18, 1.17 | 9.71, 0.13 |
| 24 kt 100° | 15.20, 0.25 | 15.52, 0.48 | 15.57, 0.67 |
| 24 kt 135° | 14.70, 0.93 | 14.92, 0.86 | 15.59, 0.73 |

The quick press pumped the bounce it was meant to calm (the reason it was made slow and weak in Session 37). Made slow, it holds 18 kt at 1.29° steadily, and the trim it aims for at 24 kt (1.5°) is above the bounce there. With the aim lowered at speed (1.1° at 15.5 m/s) the 24 kt beam reach steadies (15.31, 0.11), but the 12 kt close reach starts bouncing (7.04 m/s, 1.51°) and the 24 kt broad reach still does (0.77). A milder press (band 0.5°, 0.45 m, 0.03 m/s) is mixed in the same way. The press is the sailor's technique, and it needs a rule for where to stop pressing. Today's fixed target per speed is not that rule. Earlier attempts (Savitsky's chart as the target, section 16 of the spec) failed too. **Not built.**

## 4. Tried and built as an option, off: the rig does not pitch with every bounce

In the model, the rig took the hull's pitch at every substep. On a bouncing board the centre of effort and the boom swung with each bounce, and the sailor hanging on the boom swung with them. A real mast foot is a universal joint: it passes no moment, so the board cannot pitch the rig. The rig's pitch is what the sailor's hands and harness hold. The rig's inertia about the foot (about 25 kg m²) and the sailor on the boom keep it still through a 1.8 Hz bounce.

`SailorConfig.rig_pitch_follow_s` (0 = off, the default; 0.3 s was measured): the rig follows the hull's pitch with a first-order lag of this time, and turns with that pitch's rate instead of the hull's. Heading and roll are as before. It is reset when the sailor is put on the board. Code: `WindsurferSim._hold_the_rig`. Test: `test_rig_pitch_follow.gd`.

| Reach check (40 s, means from 25 s) | Off | Lag 0.1 s | 0.2 s | 0.3 s | 0.6 s |
|---|---|---|---|---|---|
| 24 kt 135° | 14.70 m/s, SD 0.93° | 14.77, 0.87 | 15.43, 0.10 | **15.43, 0.10** | 15.43, 0.10 |
| 24 kt 100° | 15.20, 0.25 | 15.19, 0.25 | 15.19, 0.26 | 15.19, 0.26 | 15.18, 0.27 |
| The other seven cases | | | | equal to before within 0.01 m/s and 0.01° | |

Any lag from 0.2 s up gives the same answer. **But it only delays the bounce.** On longer runs both settle to the same bouncing state, at a lower trim:

| 24 kt 135°, reach check | Off | Lag 0.3 s |
|---|---|---|
| 40 s, means from 30 s | 14.86 m/s, SD 0.93°, trim 1.14° | 15.66, 0.05, 1.20° |
| 90 s, means from 60 s | 15.69, 0.77, 0.88° | 15.63, 0.74, 0.83° |

The validation run, which starts the board differently, bounces at 40 s with the lag too (0.82°). This bounce comes at a low trim (0.8 to 0.9°, wet front 1.4 m), so it is not the high-trim porpoising of section 3. It is not understood yet.

In gusts (0.2) and waves it is neutral (`tools/push_check.sh --sweep=sailor.rig_pitch_follow_s=0,0.3 --winds=18,24 --seconds=120 --jobs=2 --run=ph16_rig_lag`). The speed made good is within ±1 %: 24 kt 100° 13.05 → 13.14 m/s, 135° 12.74 → 12.86, upwind 7.17 → 7.16; 18 kt 6.45 → 6.41, 11.56 → 11.53, 7.55 → 7.55. There are no falls either way, and the waves set the pitch SD there (0.8 to 1.5° in both).

## 5. For Michiel and Max

1. **The rig's pitch lag** (`rig_pitch_follow_s`, off). It is the better physics of the mast foot and was measured neutral everywhere. Switch it on or leave it, Michiel's call.
2. **The trim press (the next step).** A sailor presses the tail until the board starts to chatter, then eases off. The model's press aims at a fixed trim per speed. The slow, stiff press above wins 4 to 16 % where the aim sits below the bounce. A press that eases on the bounce it feels would find that point by itself on every course. This is technique, in the sailor model.
3. **The hooked-in posture.** At 12 kt the boom is behind the sailor and the harness pulls them back. A real sailor hangs behind the harness lines, and it is where the sailor's weight goes that sets the trim (section 2). The posture and the autopilot's steering by rake (19 to 23° on the reaches) are Michiel's.
4. **U1's wet-length target.** On this board 0.6 to 1.0 m wet needs 1.5 to 2.2° of trim, above where the model bounces. No measured porpoising limit of a windsurf board is known (spec section 5 F22). If Max's own feel or a photo says real boards ride at 2° without bouncing, then the bounce is the model's to fix. If not, the target is too short for this board.
5. **The 24 kt broad reach's low-trim bounce** (section 4). It is in the default after a minute, and it is what validation's `test_planing_wet_area.gd` target 2 and `test_rig_lean_and_fin_loading.gd` catch.
6. **The heeled lift at short wet lengths** is 7 to 20 % below TN 4187 at 1.5 to 2.2° (section 1). Small today, and it matters once the board rides higher.

## 6. Is it the board's shape? A slalom outline (Max's question, the same day)

Max asked whether the board's shape is the cause, since he wants a slalom board, and gave JP's Slalom S-TEC (sizes 62.5 to 85; the SL 72 is 228 × 72 cm, 117 l, 6.6 kg) with a product photo. The bottom view's silhouette was traced (width against length). Its width over length is 0.323, and the SL 72's published 72/228 is 0.316, so the photo is to scale. It is widest at 0.50 of the length from the tail, within 1 % of that from 0.48 to 0.60 (the "parallel outline"). Against the game's board at the same distance from the tail:

| From the tail | The game's board (2.40 × 0.72) | JP SL 72 (the photo, scaled) |
|---|---|---|
| 0.1 m | 0.32 m | 0.29 m |
| 0.2 m | 0.38 m | 0.41 m |
| 0.3 m (one foot) | 0.45 m | 0.49 m |
| 0.5 m | 0.57 m | 0.59 m |
| 0.7 m | 0.65 m | 0.66 m |
| widest | 0.72 m at 1.10 m | 0.72 m at 1.14 m |

The outlines are close. The slalom tail is 3 to 4 cm wider, and its cut-outs make the wet bottom narrower again, which the silhouette cannot show. Sailed in the reach check as `BoardConfig` length 2.28, width 0.72, widest point 1.14, tail width 0.49, nose width 0.56 (the photo at one foot from the nose) and volume 0.117. The mast foot, the fin and the stances were kept at the same distances from the tail (`--sail.mast_foot_local=0,0.06,-0.16 --fin.root_local=0,-0.06,0.84 --sailor.stance_planing_z_m=0.54 --sailor.stance_rest_z_m=0.09 --sailor.stance_tack_z_m=-0.26`; `run_reach.gd` now takes a point as x,y,z):

| Reach check, m/s | The game's board | SL 72 outline | SL 72 outline at 7.2 kg (6.6 and the straps, an estimate) |
|---|---|---|---|
| 12 kt 100° | 9.21 | 9.53 | 9.34 |
| 18 kt 100° | 13.08 (1.70 m wet) | 13.02 (1.63 m) | 13.04 (1.63 m) |
| 18 kt 135° | 9.62 | 9.56 | 9.71 |
| 24 kt 100° | 15.20 | 14.84 | 15.21 |
| 24 kt 135° | 14.70 (SD 0.93°) | 14.47 (1.05°) | 14.31 (1.16°) |

**The outline is not the cause:** the speeds are within 3 % and the bounce is the same. What makes a slalom board a slalom board is not in the model: the cut-outs (less wet width at the tail, a clean release), the V that changes along the bottom, and the scoop rocker. JP's own text says the new SL 72 is faster by "trimming the board to a higher water position, reducing wetted surface and drag" while staying stable. That points to the same question as section 3 (a real board rides higher without bouncing), but it is a maker's description, not a measurement.
