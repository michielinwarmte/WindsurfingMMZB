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

## 7. The whole slalom board: rocker, thickness and cut-outs (Max: "model the whole board also rocker and stuff and try again")

**The rocker**, traced from the side view (the bottom's edge against the straight line through it from 0.15 to 0.9 m from the tail, 2 mm scatter there):

| From the tail | 0.2 to 0.9 m | 1.1 m | 1.3 m | 1.6 m | 1.8 m | 2.0 m | 2.2 m | nose tip |
|---|---|---|---|---|---|---|---|---|
| JP SL 72, rise | flat | 7 mm | 16 mm | 36 mm | 60 mm | 93 mm | 156 mm | 208 mm |
| The game's board | flat to 1.5 m | 0 | 0 | 1 mm | 9 mm | 25 mm | 49 mm | 80 mm |

A scoop: it rises from about 0.7 m from the tail, where the game's board stays flat to 1.5 m. As `BoardConfig`'s parabola it is `nose_rocker_m` 0.128 over `nose_rocker_length_m` 1.6, fitted from 1.0 to 1.9 m, where the board meets the water. The last 30 cm of the nose is higher than the parabola. The tail rises 7 to 12 mm over its last 15 cm in the photo, which may be a small kick or the thin tail edge, so both were run. The straps hide the thickness except near the tips: about 45 mm at the tail and 40 mm at the nose, and 130 mm in the middle where nothing stands out.

**The cut-outs** are new in the model: `BoardConfig.cutout_from_tail_m` and `cutout_depth_m`, with the bottom narrower than the deck by the depth on each side at the tail, narrowing to nothing at the cut-out's front (`bottom_width_at`, used by the hull model and the buoyancy grid; the visuals keep the deck's outline). JP does not publish their size, so 0.45 m long and 1.5 or 3 cm deep were run (estimates). Off by default; `test_board_cutouts.gd`.

The reach check, with the outline of section 6, the rocker above, 2.28 m, 117 l, 7.2 kg, thickness 0.13, tail 0.045 and nose 0.04, and the mast foot, fin and stances kept from the tail:

| m/s (pitch SD) | The game's board | SL 72 | + cut-outs 1.5 cm | + cut-outs 3 cm | + tail kick 8 mm |
|---|---|---|---|---|---|
| 12 kt 60° | 7.16 | 6.59 | 6.59 | 6.60 | 6.47 |
| 12 kt 100° | 9.21 | 9.61 | 9.68 | 9.75 | 9.26 |
| 12 kt 135° | 5.42 | 5.07 | 5.07 | 5.08 | 5.03 |
| 18 kt 60° | 8.98 | 9.22 | 9.25 | 9.28 | 9.25 |
| 18 kt 100° | 13.08 (1.70 m wet) | **13.72** (1.22 m) | 13.76 | 13.80 | 13.74 |
| 18 kt 135° | 9.62 | 8.91 | 8.94 | 8.96 | 8.78 |
| 24 kt 60° | 9.71 | 9.73 | 9.74 | 9.76 | 9.73 |
| 24 kt 100° | 15.20 (0.25°) | **15.78** (0.01°) | 15.81 | 15.83 | 15.85 |
| 24 kt 135° | 14.70 (0.93°) | **15.62** (0.43°) | 15.67 | 15.69 | 15.64 |

At the same trim (about 1°) the planing reaches ride 0.2 to 0.5 m shorter and 4 to 6 % faster, steadier at 24 kt. The slow and broad cases are 6 to 8 % slower (more rocker in the water before the board planes). The cut-outs add 0.3 to 1 %, and the kick changes nothing useful.

**But the gain comes from one assumption of the hull model, and theory says it is too much.** The probe (`hull_probe.gd`, which now takes `--board.<field>=`) at the SL 72's own state (13.7 m/s, 1.0°, 2° of heel):

| Wet length | Today's board: model / Savitsky, N | SL 72: model / Savitsky, N | SL 72: the clip's share |
|---|---|---|---|
| 1.0 m | 147 / 408 | 333 / 444 | 48 N |
| 1.22 m | 259 / 493 | **908 / 532** | **528 N** |
| 1.5 m | 440 / 579 | 2000 / 623 | 1441 N |

Where the scoop runs into the wet part, the spray root meets the water at the rocker's own angle (3° more than the pitch at 1.22 m), and the strips behind it, where the bottom flattens and lifts away from the water, would pull: the strip theory's suction. The model does not let a strip pull ("the water has let go instead", `HullModel._apply_planing_lift` step 6), so the root's push stays and the suction is dropped: 528 of the 908 N. In consistent strip theory the suction cancels it, and the total follows the angle at the aft end. Thin-wing theory (the lift's weight on the camber is small near the front edge) gives this scoop about 0.1 to 0.2° of effective trim more than the flat tail, so 10 to 20 % more lift, where the model gives 70 %. (A correction: this report first said Savitsky and Brown (1976) measured rocker lifting less. Their measured additions are stern wedges and flaps, not rocker. No measurement of a rockered planing bottom was found.) A ventilated bottom would let go as the model has it; the suction this would take here (about 4500 Pa) is far more than the 100 to 300 Pa of water above the bottom, so air from the rails could get in. Which one a real board does is the open question. **So the SL 72's 4 to 6 % is not to be trusted** until the pressure on a curved bottom is settled. That is a hull-model item, not a board, and it touches today's board too wherever its wet part reaches the nose rocker (level at 1.7 m wet the clip gives 495 of 966 N; at 2° of heel, 40 of 510).

## 8. For Michiel (added)

7. **The clip on the strips (`_apply_planing_lift`, step 6).** Is a strip allowed to pull (suction, as consistent strip theory and thin-wing theory have it) or not (ventilation)? It decides what rocker does in the model, and so whether a slalom board's scoop rocker is faster here or slower. A bound in between, the suction no larger than the water's head above the bottom plus a sourced ventilation limit, would be physics rather than a choice.

## 9. The most realistic setup we know, as the default (Max: "implement the most realistic settings we know"; "the 72 and the 8.0 from the data")

Now the default gear:
- **The board is the JP Slalom SL 72:** 2.28 × 0.72 m and 117 l (JP's data), 7.8 kg (6.6 published, plus straps and fin, an estimate), with the outline and the scoop rocker traced from JP's photos (sections 6 and 7). Cut-outs off, since their size is unknown.
- **The sail is an 8.0 m²:** the wind tunnel's own sail, with a 4.9 m luff and mast, a 2.0 m boom and the centre of effort at 0.41 of the luff. On its aspect ratio of 3.0 the lift slope factor is 1.03, which gives the curve Session 57 checked against the tunnel. The rig weighs 9.5 kg with its centre 1.8 m up (estimates). JP recommends 7.0 to 8.2 m² for the SL 72.
- **The mast foot, the fin box and the stances** stay at their distances from the tail.
- **The rig's pitch lag** is on (0.3 s).
- **The sailor trims by feel:** the pitch is averaged over 1.5 s, the weight keeps moving aft at 0.03 m/s while the board rides below its aim, and it moves forward when the board starts to chatter (pitch-rate RMS above 1.7°/s). It comes off the tail quickly (0.3 m/s) when the nose rides above the aim and off the plane. With the slow release a beginner's tack reared the board to 72° as it slowed heading up, and it turned over.

The old gear is kept as `board_freeride_240.tres` and `sail_6_5.tres`. The tests that pin the old board's and the old sail's own numbers load those files.

| Reach check, 90 s, means from 60 s (m/s, pitch SD) | The old default (2.40 freeride, 6.5) | The new default |
|---|---|---|
| 12 kt 60° | 7.16 | 7.58 |
| 12 kt 100° | 9.21 | **11.00** (+19 %) |
| 12 kt 135° | 5.42 | 5.96 |
| 18 kt 60° | 8.98 | 8.74 |
| 18 kt 100° | 13.08 (1.70 m wet) | **13.52** (1.00 m wet) |
| 18 kt 135° | 9.62 | **14.52** (+51 %, now planing) |
| 24 kt 60° | 9.71 | 9.06 (an 8.0 is big for 24 kt) |
| 24 kt 100° | 15.20 (0.25°) | 15.35 (0.00°) |
| 24 kt 135° | 14.70 (0.93°, bouncing) | **17.93** (0.17°, steady) |

On the planing reaches the wet part is now 0.93 to 1.27 m long. Two things are not right yet:
- **The scoop rocker's share of the gain is overstated** by the strips' clip (section 7).
- **The 3D models still show the 2.40 m board and the 6.5 sail.** They are rebuilt with `tools/blender.sh tools/blender/build_rig_models.py` once Blender 4.5 is installed on this PC.

**What still needs research:**
1. The pressure on a curved bottom, suction against ventilation (section 8, item 7).
2. The hooked-in posture: the harness carries about 400 N in the measurement against 610 to 690 N here, and the boom sits behind the hips at 12 kt (section 5).
3. The cut-outs' size and the V of a slalom tail.
4. The mast track's and the straps' places on the SL 72.

## 10. Max's play-test of the new gear (the same evening)

Max: "the fin is the problem for the bouncing and weird falls: it pushes the board straight up at high speeds and high load; in real life this translates more in the nose lifting up". "The sailor is too weak: in 15 kn not being able to close the sail in a broad reach is not acceptable." "If you slingshot downwind you gain a lot of speed, and closing the sail then keeps the pressure through the apparent wind." "If the physics are correct then I'm wrong."

**The slingshot** (`Game/dev/slingshot.gd`: 60 s on a beam reach at 15 kt, flat water, then a bear-away to 135°). The sim's sailor *eased* the sail in the bear-away: the boom went from 24 to 31°, the angle of attack from 9 to 5.8° where 18° drove best, the drive from 216 to 124 N, and the board fell from 12.5 to 8.5 m/s. The board that started on the broad reach went just as fast. The cause was the autopilot's cap on the pull, the alpha the sailor's righting moment *now* can hold. On the beam reach the sailor was at full lean and held 9.5° of the best 18. In the bear-away the pull dropped, the body came in, the cap fell with it, and the sail was let go.

**The sailor too weak: Max is right.** The full lean was a 45° stance (U1.2), 0.66 m outboard of the feet. Gourlay & Martellotta (2011, section 6.1) put a real sailor's body "at least 20 to 30 degrees above horizontal", with the centre of mass 1.03 m along it. At 30° that is 0.89 m outboard of the feet: `lean_max_m` 1.11, `lean_height_drop_m` 0.48, now the default. Results:
- **The slingshot:** the sail stays in through the bear-away (boom 17 to 24°), and the speed holds at 13 m/s for 3 s.
- **The reach check:** 15 kt beam 12.54 → 12.99 m/s, 18 kt beam 13.53 → 14.26, 24 kt beam 15.35 → 16.16.
- **Gusts and waves, no falls:**

| | Upwind (VMG) | Beam reach | Broad reach |
|---|---|---|---|
| 24 kt | 3.85 → 4.46 | 12.40 → 13.32 | 12.75 → 12.78 |
| 18 kt | 3.70 → 4.04 | 11.10 → 11.92 | 8.14 → 8.10 |
| 12 kt | 2.16 → 2.16 | 7.90 → 7.83 | 5.48 → 5.57 |

The harness now carries 770 to 850 N, against about 415 N measured (the hooked-in posture, still open). In validation's steady 24 kt reach at 120° the autopilot now holds enough of the 8.0 to catapult, which is what an 8.0 in 24 kt does. A change of the autopilot's cap alone (never below the pull it holds) measured no gain and was not kept.

**The broad reach at 15 kt still does not plane.** Kept sheeted in, the board still slows from 13 to 9 m/s over 20 s. At 12 m/s on 135° the sail at its best angle drives with about 155 N (apparent wind 16 kt at 37°), and the board's drag is about 190 N (friction about 125, the bottom's tilt 30, the fin 22, the sailor's windage 16). In the game the wind is set at 10 m: "15 kt" there is about 12.5 kt at the sail (the height gradient). If Max's 15 kn is a reading on the beach or felt at the sail, the game's 18 kt is his 15.

**The fin: Max's observation holds in the sim, with the sign the other way.** Under load the bending fin's force turns upward (the tip bends to windward). With the full hike, flat water:

| | Bending fin: up force, trim, wet length, speed | Stiff fin |
|---|---|---|
| 15 kt 100° | 105 N, 0.73°, 1.28 m, 12.99 m/s | 20 N, 1.47°, 1.12 m, 13.24 |
| 18 kt 100° | 111 N, 0.71°, 1.25 m, 14.26 | 20 N, 1.32°, 1.09 m, 14.53 |
| 24 kt 100° | 120 N, 0.80°, 1.20 m, 16.16 | 20 N, 1.37°, 1.01 m, 16.55 |
| 24 kt 135° | 123 N, 0.20°, 1.27 m, 18.10 | 22 N, 0.70°, 1.19 m, 18.44 |

In the sim the push at the tail lifts the tail and the nose goes down, 0.6° less trim and 2 % slower, and in a gust it is a likely trigger of a nose dive. An upward push at the tail lifts the nose only if the riders weight is behind the fin. In the sim the sailors weight is right above it (the whole windsurfers centre of mass 0.31 m from the tail, the fin 0.30 m). A real hooked-in rider hangs behind the boom, so further aft. That is the same open point as the harness: **the hooked-in posture is now the one physics item behind three findings**: the trim (section 2), the harness load, and the fin's effect. The fin's own stiffness (the Nascimento 2017 flex test of a 37 cm fin, 20 mm under 100 N) is also a soft fin for a slalom board, but no slalom fin's flex was found.

**Fagg (1997), read for the fin** (`Documentation/Science/Simon_Fagg.pdf`, Max). The fin's loads on a planing board are 300 to 600 N of lift and 20 to 50 N of drag, about one sixth of the total drag. These come from Sutherland (1993) and Broers et al. (1992), the sources the spec already uses, and the sim is inside them (500 to 630 N, the fin about an eighth of the drag). Fins are "typically sailed at an incidence angle of 6 degrees", with no source; on this fin that is the same lift at about 7.5 m/s, and at planing speed the sim's fin runs at 1.5 to 2 degrees. Fins with tailored flex were tested and found inconclusive. There is nothing on the fin's vertical force or on the board's pitch, so the question of the nose stays with the hooked-in posture. The original fin sources are Sutherland (1993, MSc, Southampton) and Broers, Chiu and Walker (1993, AIAA 93-3000, fins with deformable tips).

## 11. Max's answers on the rider: the brief for the hooked-in posture (the next build)

Max on 29 October 2026, as the team's experienced windsurfer. His on-water feedback is the check for the physics; Michiel does the hard physics because he has Fable. His answers, and what each means for the model:

1. **The harness lines** hang between the hands on the boom. They are 30 inch loops, so the hook hangs about 0.30 to 0.35 m from the boom (spec section 14: 0.30 to 0.40 m for 22 to 32 inch loops). Most riders set them a little behind the centre of effort, so the front arm carries more (55/45 to 60/40). The back hand can let go, and the lines hold the rig. *Model:* the line is short and sits at or just behind the centre of effort's place on the boom. The arms carry a share, the front arm the larger one. Today the sim's line runs 0.7 m or more from the centre of mass to the grip, and the arms carry nothing beyond what the line leaves.
2. **The harness** is a hybrid with the hook at the height of the underwear band, so at the hips, near the centre of mass. Shorter lines are used for light wind for the sail, longer when overpowered.
3. **The weight split depends on power.** Underpowered, more of the weight hangs in the harness. Overpowered, the arms force the sail more.
4. **The body angle depends on power.** Underpowered, the rider stands more upright, the back and the legs nearly straight. Overpowered, the bum goes down, the lines are longer, and the rider sits lower with more control. *Model:* the lean and the drop are not one fixed full hike (today 30°, `lean_max_m` 1.11). They follow how much the sail pulls against the rider.
5. **The weight is on the back foot.** On flat water and not overpowered, the front foot pulls the nose up a little or holds it neutral. Overpowered, the nose comes up by itself, and the rider puts weight on the front foot and depowers the fin. *Model:* this is the nose lifting under the fin's load (section 10) that the sim gets the wrong way round, and the front foot's job when overpowered (a trim press forward, and less fin load).
6. **The mast foot and the back strap's positions** on his slalom board: not yet, Max will give them.

**What to build (for the next session).** A hooked-in rider whose hips hang from the boom on the short line, behind and below it. The line is at or just behind the centre of effort, and the arms take part of the pull, the front arm more. The lean, the height and the line's length follow the sail's pull (upright when underpowered, low when overpowered). The weight sits further aft than the fin, so the fin's lift raises the nose. Check it against sections 2 and 10 (the trim, the harness about 415 N measured, the fin's effect on the nose) and with Max on the water. The tools are `Game/dev/pitch_budget.gd`, `Game/dev/slingshot.gd`, `tools/reach_check.sh` (90 s runs) and `tools/push_check.sh`.

