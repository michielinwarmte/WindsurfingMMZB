# Review of PH28: the sail from the wind tunnel (branch `ph28/sail-and-hull`, HEAD d1e583d against `origin/main` 4b9297f)

Independent physics review, 30 October 2026, for the lead and Michiel. Read-only: nothing in the repo was changed but this file. Scope: `Game/sim/sail_model.gd`, `Game/sim/config/sail_config.gd`, `Game/sim/autopilot.gd`, `Game/config/sail_default.tres`, `Game/config/sail_6_5.tres`, spec section 2.17, the report `sail_wind_tunnel.md`, the paper `Documentation/Science/2501.13254v1.pdf` (Zhang et al. 2025; its figures were rendered and read, since the numbers were read off Fig. 5d, 6 and 8).

## Verdict

The sail is an honest build. Where the paper has data (4 to 8 m/s of wind, 1 to 17 degrees of attack) the code reproduces it: the lift curve, the camber, the loss of lift as the wind rises and the centre of effort coming down are all in the paper where the comments say they are, and the figure readings in the test match what the figure shows. I found no bug, no sign that flips on one tack, and no path to a division by zero or NaN. The autopilot change is not a hidden physics change: its margin settings still cap the pull; only the conversion from "pull the sailor can hold" to "boom angle" now uses the softer sail. The sail tests pass (48 of 48 in the `sail` selection, `test_sail.gd` 16 of 16).

Three things need Michiel's decision or a fix before merging, in this order:

1. **The game sails outside the tunnel's range, and the one number that matters there (the twist's floor, 0.75) was chosen for gameplay.** The tunnel stopped at 39 Pa of wind pressure (8 m/s, 15.5 kt apparent). The game's planing winds are 50 to 160 Pa. The code holds the twist at the tunnel's last measured share (0.75) above that; the formula's trend would go on to 0.5 at 24 kt. Both are extrapolations. The floor was picked because 0.5 made the pushed sailor unable to catapult at 24 kt. The code says so honestly, but it is a gameplay choice, not a measurement, and it is worth 25 % of the sail force at 24 kt.
2. **The default 8.0 sail is the tunnel's own sail but carries the wrong numbers from the 6.5:** `twist_pressure_pa` 140 where the spec's own argument gives 125 for the 8 m² sail, and a luff of 4.9 m (the mast's length) where the real sail's luff is 5.22 m. The second is why a `lift_slope_factor` of 1.03 had to be added.
3. **Spec 2.17 still describes the 6.5 as the default sail** (140 Pa "for the sim's 6.5 m² sail on a 460 mast", slope factor 1.0, centre of effort 0.40). It was written in Session 57 and the default changed in Session 58.

Everything else is labelling, tests that could pin more, and small inconsistencies.

## How the pieces map to the paper (what is measured, what is fitted)

| Number in the code | Where it is claimed from | Checked | Status |
|---|---|---|---|
| `camber` 0.07 | Fig. 5d: 6.3 to 6.6 % with the outhaul on, 7.1 to 7.6 % eased | Fig. 5d shows exactly that | measured; 0.07 sits between the two settings, while the lift fit below uses the outhaul-on sail. Harmless: camber only sets the zero-lift angle (28 × 0.07 = 1.96°) |
| `zero_lift_deg_per_camber` 28 (lift starts at −1.96°) | Fig. 8a: lift 0.15 to 0.18 at 1.3° | Fig. 8a: 0.18 at 4 m/s, 0.15 at 8 m/s at 1.3°. Extrapolating the 4 m/s points back gives −1.3 to −1.9° | measured, "about −2°" is fair |
| `lift_slope_factor` 1.0 (6.5) / 1.03 (8.0) | 0.069 per degree at 4 m/s; the formula gives 0.068 for AR 3.36 | Fig. 8a, 5.3° to 12.2° at 4 m/s: (0.96 − 0.50) / 6.9 = 0.067 per degree | measured. The 1.03 on the 8.0 is a correction for the game's wrong aspect ratio (finding 3), not a sail property |
| `cl_transition_gain` 0.15 (peak 1.10 untwisted) | rigid model 1.21 at 17°; full scale 0.98 to 1.08 | Fig. 8a: rigid (black) 1.21 at 18°; full scale 0.98 (outhaul on, 16.5°, 4 m/s) to 1.09 (eased, 20°, 4 m/s) | the untwisted peak 1.10 is a model choice between the two; nothing in the tunnel is untwisted |
| `cl_peak_deg` 18 | – | the paper: stall at 17° rigid, delayed to 20° for the flexible sail | kept at 18; not updated (cosmetic) |
| `alpha_luff_deg` 2 | 0.15 to 0.18 still carried at 1.3° | Fig. 8a | measured |
| twist shares 0.94, 0.85, 0.75 at 4, 6, 8 m/s | Fig. 8a, "of the untwisted curve" | Against the model's own untwisted line the figure gives 0.91 to 1.02 at 4 m/s, 0.83 to 0.86 at 6, 0.75 to 0.77 at 8 (my readings, 5.3° to 12.2°) | 0.85 and 0.75 are measured shares; 0.94 is the formula's value, the data say about 0.97. There is no wind-free measurement: the "untwisted curve" is the model's line |
| `twist_pressure_pa` 125 for the tunnel sail, 140 for the 6.5 | "118 to 153 from the three speeds" | 118 to 153 is what you get by assuming the shares above first (circular). Fitting the formula to the measured ratios 6/4 and 8/4 directly gives about 100 to 110 Pa | fitted; the formula 1 / (1 + q / q_twist) is a model with one parameter through three wind speeds, label it so |
| `twist_min_factor` 0.75 | "the tunnel's lowest measured share" | 0.75 to 0.77 at 8 m/s, yes. But with 140 Pa the model gives 0.78 at 8 m/s, so the floor only starts at 17 kt apparent (47 Pa), beyond the data | the value is measured; applying it as a floor is a choice (finding 1) |
| `twist_peak_share` 0.45 | "at 8 m/s the peak fell to 0.89 of the light-wind peak" | Fig. 8a, eased sail at 20°: 1.09 (4 m/s) to 0.96 (8 m/s) = 0.88 | fitted from the *eased* sail's points (the outhaul-on sail has no points past 16.5°); the rest of the fit is to the outhaul-on sail. Label mixed |
| `twist_ce_drop` 0.32 ("6 % lower at 8 m/s") | Fig. 8d | 8 m/s against 4 m/s: 0.90 at 5.3°, 0.92 at 8.7°, 0.94 at 12.2°, 0.98 at 16.5° | fair at 12°; at the 7 to 9° the sim sails at 24 kt it is 8 to 10 %. Estimate |
| `ce_height_fraction` 0.41 (2.0 m) | "the tunnel's 2.0 m above the board is 41 % of its mast" | Fig. 8d: 2.0 m from 12° up (both winds); 1.6 to 1.8 m at 5°; 0.9 to 1.2 m at 1.3° | measured at sailing angles. The height's big dependence on the angle of attack is **not** in the model (finding 6) |
| separation drag × twist share | "drag at 20° fell 39 % from 4 to 8 m/s" | the paper says exactly that | measured, but the sim's separation drag at 20° is tiny (0.014), so the effect is cosmetic; the induced drag (which follows the lift squared) does most of it |
| angle of attack | the paper's AoA: chord of the section 67 cm up, under the boom, in the horizontal plane; rig-back 18° | the sim: the boom's level chord against the horizontal apparent wind (`sail_model.gd:176-178`), unchanged by rake or the square boom | the same convention; fine |

## Findings, ranked

### 1. Wrong physics / open decision: the twist's floor is a gameplay choice applied where the game actually sails

`Game/sim/config/sail_config.gd:104-108`, `Game/sim/sail_model.gd:261-264`, spec 2.17 ("twist_min_factor 0.75"), report measurement 5.

The tunnel measured up to 39 Pa (8 m/s, 15.5 kt of apparent wind). On the game's 18 and 24 kt reaches the apparent wind is 9 to 16 m/s, that is 50 to 160 Pa: two to four times the tunnel's maximum. Nothing in the paper says what the sail does there. The code keeps the share at 0.75 ("constant beyond the data"); the formula's trend would give 0.73 at 18 kt and 0.60 at 24 kt of apparent wind, and the paper says the twist keeps growing with the wind (and a real sailor adds downhaul in strong wind, which twists the top more still). So the floor is probably on the high side, and it was chosen because at 0.5 the pushed sailor could not catapult (the config comment and measurement 5 say so plainly). That is the right thing to have written down, but it is a gameplay argument inside a physics number.

What it is worth: at 24 kt of apparent wind and 12° of attack the sail gives 530 N with the floor and about 425 N with the formula (0.60); at 18° 727 N against 585 N.

For Michiel: decide which extrapolation the game uses, and write the reason into spec 2.17 as a choice ("held at the last measured share because ..."), not as "not extrapolated" (both options extrapolate). If the floor stays, the push's catapult (GP0/GP3) depends on it and should say so.

### 2. Mismatch with the paper: the 8.0 keeps the 6.5's twist pressure

`Game/config/sail_default.tres:38` (`twist_pressure_pa = 140.0`), `Game/sim/config/sail_config.gd:94-103`, spec 2.17.

The spec's own reasoning: the tunnel's 8 m² sail gives q_twist about 125 Pa; 140 was the estimate for a *smaller* 6.5 on a softer mast. Since Session 58 the default is the tunnel's sail (8.0 m², a 4.9 m mast, "the wind tunnel's own"), but it kept 140. With 140 the model gives a share of 0.78 at 8 m/s, not the 0.75 the comment at `sail_config.gd:104-105` says it reaches there. Fix: 125 on the 8.0 (the measured one), 140 stays on `sail_6_5.tres` as the labelled estimate. The effect is small (the floor is then reached at 16 instead of 17 kt apparent), but the default should carry the measured number.

### 3. Mismatch with the paper: the 8.0's luff is the mast's length, and the slope factor 1.03 patches it

`Game/config/sail_default.tres` (`luff_m = 4.9`, `boom_m = 2.0`, `lift_slope_factor = 1.03`), spec tuning log (line 6598), Session 58's log.

The paper gives its sail's aspect ratio as 3.36 (Fig. 8 caption), which for 8 m² means a span of 5.2 m; the manufacturer's spec for the HGO 8.0 is a luff of 522 cm and a boom of 220 cm on the Apex 490 (the mast plus an extension). The game's 8.0 has `luff_m` 4.9 (the mast's length) and so an aspect ratio of 3.0; the lift slope formula then came out 3 % low against the tunnel's curve, and Session 58 added `lift_slope_factor` 1.03 to put it back. That factor is a correction for the wrong geometry, not a property of the sail. Fix: `luff_m` 5.2 (`mast_m` can stay 4.9 for the rig's inertia; say so in the comment), `lift_slope_factor` back to 1.0, then re-run the tunnel test. The centre of effort then sits at 0.41 × 5.2 = 2.13 m along the mast, which with 18° of rake is 2.0 m vertical, exactly the tunnel's 2.0 m. `boom_m`: the paper's maximum chord is 2.0 m and the wishbone 2.3 m long, so 2.0 from mast to clew may be right; uncertain, label it. (The 3D model is built from these sizes; that is the visuals agent's.)

### 4. Fitted, not measured: label the twist formula and two of its numbers as a model

`Game/sim/config/sail_config.gd:94-116`, spec 2.17 ("f(q) = 1 / (1 + q / q_twist) ... q_twist about 125 Pa (118 to 153 from the three speeds)").

See the table above. The honest statement is: "the measured lift at 6 and 8 m/s is 0.85 and 0.75 of the model's untwisted line; a one-parameter formula was fitted through the three wind speeds; the 4 m/s data sit at about 0.97, where the formula says 0.94". The "118 to 153" range is circular (it assumes the shares and then solves for q_twist); fitting the formula to the measured 6/4 and 8/4 ratios gives about 100 to 110 Pa. `twist_peak_share` 0.45 was read from the eased sail's 20° points while everything else is the outhaul-on sail. `twist_ce_drop` 0.32 is an average over angles where the measured drop runs from 2 to 10 %. None of this is wrong for a game sail; it must just not be called "measured". The spec's "not extrapolated" belongs to finding 1.

### 5. Spec 2.17 does not say what the code does (list of mismatches)

`Documentation/PHYSICS_SPEC.md:1057-1090`.

- "For the sim's 6.5 m² sail on a 460 mast, `twist_pressure_pa` is 140 Pa": the default is the 8.0 on a 490; see finding 2.
- The table's "Now" column: `lift_slope_factor` 1.0; the default is 1.03 (only the tuning log at line 6598 says so). `ce_height_fraction`: "the legacy height of 40 % stands"; the default is 0.41.
- "Peak lift ... stall delayed to about 20°": the code keeps `cl_peak_deg` 18 and the table does not say so.
- "the top always keeps a positive angle (Fig. 6)": Fig. 6 and the paper's text have two negative twist angles at small angles of attack for the outhaul-on sail (the loose tip drops under gravity). Cosmetic.
- "falls by about the same share at every angle below the stall": true between wind speeds (the figure), but the paper's own sentence is that the gap to the *rigid* model is smaller at low angles. Say which comparison is meant.
- "from about 17 kt of apparent wind the sail keeps 0.75": only with 140 Pa; 16 kt with 125.
- The formula block (f, CL_twisted, CD_twisted, the centre of effort) matches `sail_model.gd:261-296, 313-324, 191-194` line for line. The autopilot paragraph matches. The test paragraph matches `test_sail.gd`.

### 6. Mismatch with the paper, left out: the centre of effort's height follows the angle of attack much more than the wind

`Game/sim/sail_model.gd:137, 191-194`; Fig. 8d.

In the tunnel the force's height climbs from 0.9 to 1.2 m at 1.3° through 1.6 to 1.8 m at 5° to 2.0 m from 12° up, at every wind speed; the wind's own effect (what `twist_ce_drop` models) is the smaller one. The model has one fixed fraction (0.41 of the luff) at every angle. At the angles the sim sails powered up (7 to 15°) that is within 10 %; eased (a luffing sail, a gybe entry, the backed sail in a tack) the real force sits a metre lower, which matters for the heeling and pitching moments there. Not built and not mentioned in the spec; a note for Michiel, low priority. The paper's 8d would give it directly (a short table against the angle).

### 7. The autopilot: what changed and whether it still obeys its margins

`Game/sim/autopilot.gd:196, 319-321 (_sail_pressure_pa), 327-345 (best_alpha_deg), 426-442 (_alpha_for_torque_deg), 450-459 (_alpha_rise_limit_dps), 465-473 (_backing_alpha_deg)`.

What changed: the pilot now asks the sail's lift and drag curves at the dynamic pressure the sail feels right now (the same q the sail model uses: `telemetry.aws_kt` is set from `sail.aws_ms` at `windsurfer_sim.gd:1477`, and the pilot's `air_density_kg_m3` is the sim's). Before, it asked the rigid curve. It does this in four places: the most-drive angle, the angle the sailor can hold, how fast the sheet may come in, and the backed sail in a tack.

Is it a physics change hidden in the pilot? No. The margin is unchanged: `hike_share` and `ankle_share` still set the moment the sailor can hold (`_righting_moment_now_nm`, lines 381-389), `max_alpha_deg`, `min_alpha_deg`, the depower reflexes and the catch all work as before on the resulting angle. What changed is only the conversion from "this much pull" to "this boom angle": with a sail that pulls 25 % less per degree, the same allowed pull is reached 2 to 4° further in. That is the sailor feeling the pull, which is what the pilot already modelled. GP0's settings (`hike_share` 1.6, the depower rates, `catch_alpha_max_deg`) are written into the same fields and are obeyed; their *effect* changes because the sail changed, which is why the report's measurement 5 and GP3 re-measure the dial.

Reservations: (a) the pilot reads the sail's exact twisted curve, an oracle, as it did the rigid one; a real sailor only feels the result. Unchanged in kind. (b) The pilot's own `alpha_luff_deg` stays 5.0 (`autopilot.gd:114`) while the sail's is now 2.0; the pilot's no-go band (`luff_band_deg`, line 230) and the "filled" angle after a tack (line 272) are therefore 3° wider than the sail's luff fade. It is not read from the sail config anywhere. Harmless (a little conservative in tacks), but inconsistent; either set it from the config or note it. (c) `Game/dev/slingshot.gd:45` calls the private `_sail_pressure_pa()` from outside; make it public or leave it, cosmetic.

### 8. Sign conventions and units: sound

`Game/sim/sail_model.gd:149-152, 176-178, 191-194, 251-255, 261-264, 274-296`.

- The twist depends only on the dynamic pressure, a scalar: no sign to flip. `lift_coefficient()` works on |alpha|, as before.
- The lowered centre of effort (`:191-194`) uses the same `mast_direction()` and `boom_direction_local` on both tacks; `boom_direction_local` carries the tack through `sail_side` in `chord_local` (`:149`).
- The square boom (`:251-255`): the level chord with its along-mast component removed. By hand: chord · mast = sail_side · sin(sheet) · sin(lean) + cos(sheet) · cos(lean) · sin(rake). On the other tack `sail_side` and the lean (which is toward the sailor) both flip, so the product is the same: mirror-symmetric. Raked back the boom points aft and down on either tack; leaned toward the sailor the boom on the far side tips down, which is the right geometry.
- The angle of attack and the force direction still use the level chord (`:176-178`), as `sail_config.gd:33-34` says; the tunnel also measured its angle in the horizontal plane with 18° of rig-back, so the convention matches the data.
- Units: Pa, m/s, N, rad inside; the knots only in the telemetry.

I found no place where the twist or the square boom could behave differently on one tack. The symmetry is not pinned by a test with these features on (finding 10).

### 9. Numerical safety: sound, one cosmetic hole

- `twist_factor()` guards `twist_pressure_pa <= 0` (`sail_model.gd:262`); q is never negative; the floor is a `maxf`.
- `boom_direction()`'s `normalized()` cannot see a zero vector: the chord is horizontal and the mast always has an upward component (rake at most 25°, the lean clamped to `_max_total_rig_lean_deg` in `windsurfer_sim.gd:962-975`).
- Zero or near-zero apparent wind: `_clear_forces()` (`:157-159`), which now also resets `twist_share` to 1 (`:233`). 0° and 180° AWA: alpha goes through 0, handled by the existing luff fade and the `lift_dir` guard (`:200-205`); the twist adds nothing singular there.
- A fall: `sail.clear()` at `windsurfer_sim.gd:636`; `sail.compute()` only runs while sailing (`:429-431`), so no twist or boom calculation happens with the rig in the water. `ce_local` keeps its last value after `clear()`, but the force is zero so nothing uses it.
- Cosmetic: `twist_min_factor` above 1 or `twist_peak_share` outside 0..1 are not clamped; a typo in a `.tres` would lift the sail above its rigid curve without a warning.
- Thread note: `twist_factor()` reads the model's copied fields while `lift_coefficient()` reads `config.*`, as the existing note at the top of the file allows (the autopilot calls from the main thread). Consistent.

### 10. Untested: what the tests pin and what they do not

Ran `tools/test.sh unit -gselect=sail`: 5 scripts, 48 tests, all pass (`test_sail.gd` 16 of 16, `test_sail_silvaplana.gd` 8 of 8, the sailor tests 24).

Pinned by `Game/tests/unit/test_sail.gd`: the default sail's lift at 4 angles and 3 winds within 0.08 of Fig. 8a (the readings match the figure; the real misses are up to 0.07 at 12.2° in 4 m/s, 0.89 against 0.96, so 0.08 is as tight as this fit allows); the 8/4 m/s ratio 0.80 ± 0.05; the lower centre of effort 5 % ± 1.5 %; a rigid sail's centre of effort; the square boom's geometry and that it does not change the force. `test_environment_config.gd` pins thin air with the twist.

Not pinned:
- The floor in a real `compute()` at the game's winds (that `twist_share` is 0.75 at 18 and 24 kt and that the lift there equals the 8 m/s curve). A two-line test.
- Mirror symmetry with the twist and the square boom on: `test_mirror_symmetry` (`test_sail.gd:126-136`) builds the legacy config with both off. Run it once on `sail_default.tres`.
- The autopilot's pressure-aware sheeting: no test calls `best_alpha_deg()` or `_alpha_for_torque_deg()` with a pressure; the only coverage is indirect, through the catapult test and the validation suite.
- `sail_6_5.tres`'s own curve: the file is only used as a base for the legacy worked examples, with the curve overridden (`test_sail.gd:10-24`).
- A test was loosened on the way (sim side, but the lead should know): `test_windsurfer_sim.gd:79-117`, the catapult test, moved from 18 to 24 kt in 8584330 (the new sail can be held sheeted in at 18 kt, which is plausible) and its "did not roll over" limit went from 45° to 90° in 7be6cb9/7b53d4d, with a new check that the board comes back upright.

### 11. Plausibility: the forces by hand, and "the sail that never closes"

The default 8.0 (`sail_default.tres`: aspect ratio 3.0, slope 3.88 per radian with the 1.03, zero lift at −1.96°, untwisted peak 1.10 at 18°, twist 140 Pa floored at 0.75), sea-level air:

| Apparent wind | q, q·A | share used (formula) | 8° | 12° | 18° (peak) |
|---|---|---|---|---|---|
| 18 kt (9.3 m/s) | 52 Pa, 420 N | 0.75 (0.73) | 215 N | 301 N (lift 298, drag 38) | 413 N |
| 24 kt (12.3 m/s) | 93 Pa, 747 N | 0.75 (0.60) | 381 N | 534 N (lift 530, drag 68) | 734 N |

The paper's own 8 m/s curve scaled to 24 kt (which is what the floor does) gives 545 N at 12.2° and 672 N at 16.5°: the same. The old sail for comparison: the legacy 6.5 at 24 kt and 12° made 668 N; an 8.0 on the legacy curve would make about 820 N at 12° (and the rigid new curve 707 N). So the new sail pulls about a third less than the legacy one at the same angle in strong wind.

Against the real world: an 80 kg sailor hooked in holds roughly 600 to 900 N of side force. The fully powered 8.0 at 24 kt (734 N) sits at the top of that, a 12° trim (534 N) is comfortable, and the sim's measured outcome (the pilot sheets to a mean 7 to 9° of attack at 24 kt with 0.90 of sheet, 10 to 15° at 18 kt sheeted fully) is consistent with that. The spread between the floor and the formula at 24 kt (734 against 585 N at the peak) is the size of finding 1.

"The sail that never closes" (ROADMAP line 105: "the rider cannot close the sail, and the drive is capped by the rider's balance"; GP0 follow-up 2). What is built: the sail now twists so that at the same boom angle it pulls less, and the rider's balance cap is unchanged (it lives in the autopilot's `hike_share`, as before; nothing in the sail model caps the drive by the rider). The result is the opposite of the phrase: the sailor now *does* close the sail (sheet 0.90 to 1.00 at 24 kt, 0.99 at 18 kt upwind, report measurement 6) because the twisted top spills what the rider cannot hold, instead of the rigid sail sitting at the edge of luffing at 4 to 6° of attack. That is how a loose leech works and is what Max described ("the flex lets more pressure go"), so the symptom he reported is addressed, but in a different way from how PH28 is worded: the roadmap's and the follow-up's description should say "the sail closes and its top spills" rather than "the rider cannot close the sail". Whether the catapult risk at the top of the dial is right again now depends on the floor (finding 1).

### 12. Cosmetic

- `sail_6_5.tres` applies the tunnel's curve (camber, zero lift, peak, twist 140) to a 6.5: an assumption carried over, say so in the file's comment or the spec.
- `sail_config.gd:61-64` says `lift_slope_factor` "1.0 ... the full slope" while the default `.tres` has 1.03; the comment should say why (finding 3) or the value should go back to 1.0.
- `rig_visuals.gd` `FLUTTER_NONE_LOAD` 0.55 to 0.45: visual only, follows the lower curve; fine.
- The report's measurement 7 (`flow_twist.py`, the wind's own twist with height) is an estimate and is labelled as one and not built; nothing to review.

## What I could not verify

How any of it feels to sail; the validation suite (another reviewer); the drag coefficient against the paper (the authors distrust their own drag, the sim keeps the legacy drag model, and the two agree within 0.01 at 12° anyway); the figure readings beyond about ±0.02.

Sources outside the repo used for finding 3: the Starboard iQFOiL equipment table and a windfoilen.nl review both list the HGO 8.0 at a 522 cm luff and 220 cm boom on the Apex 490.
