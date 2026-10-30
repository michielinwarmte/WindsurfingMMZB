# The hull on the rocker: what a strip may pull, where the push sits, and the heeled bottom

For Max and Michiel. Session 61 (30 and 31 October 2026), the lead (Fable 5.1) on the branch `ph28/hull-suction`, from the brief in [PROGRESS.md](PROGRESS.md) ("To continue after Session 61", item 3), the hull review ([review_hull.md](review_hull.md), finding 1) and [flying_the_board.md](flying_the_board.md) section 4. Max on this item: "if it can't get helped it's okay for now." Every number below is measured on the sim; where a number is an estimate it says so.

## 1. In short

The hull review found that the shipped board's planing lift is not Savitsky's but the hull model's rule that no strip of the bottom may pull (assumption A-05), acting on the JP SL 72's scoop rocker: at the wet lengths the board rides at, the lift is two to three times what a flat planing plate would make. The brief asked for the consistent alternative, a pull bounded by the water's head above the bottom, built as an option and switched on if it sails steadily.

It was built, with two more options the brief asked for, and all three were measured. **None of them is on.**

1. **A strip may pull, bounded by the water's head** (`BoardConfig.strip_suction_heads`). Held still, it does what the review wanted: the wall in the lift is gone and the old board is unchanged. Sailing, **the board does not plane any more**: on the close reaches it stays fully wet at zero trim doing 4 to 5 m/s, on the beam reaches it ploughs along with the whole bottom wet at 13 m/s, and at 24 kt it falls. The rocker's net push at the spray root, which the clip keeps and a consistent theory takes back, is what gets the sim's board over the hump and onto the plane. No source in the project says which of the two a real rockered bottom does at speed.
2. **The whole push at Savitsky's centre** (`push_at_savitsky_centre`), with the clip kept. On the way it turned out that the model only ever pinned the front root's part of the push at Savitsky's centre; the whole push sat 0.1 to 0.25 m further forward on the old board. With the whole push pinned the board sails without falls, but it rides on 1.5 to 2.1 m instead of 1.25 to 1.35 m and is 2 to 8 % slower: the push pinned further aft lengthens the wet part under the same moments. And with the clip the bottom behind the root is taken as ventilated, for which Savitsky's attached-flow centre is no better a source than what the model had. For Michiel.
3. **The heeled bottom as the rolled flat plate of NACA TN 4187** (`heel_as_rolled_plate`). Held still it is right: the heeled lift at short wet parts is the measurement's within 1 %, where the model had a third to a half of it, and level it fixes a small under-count at short wet parts. Sailing it is within 1 % of the clip on every reach, but it catapults once on the flat-water 18 kt beam reach while settling, because the way the strips are anchored scales their damping along with their lift, and on a wet sliver that scale runs to 36. A reference that does not do that would be the fix; not built.

Also found and fixed inside the options: the oblique spray root's push was relieved at the transom while the front root's never was. And the bounce check the brief asked for first could not split the bounce into the clip's share and the rest, because on today's code nothing on flat water bounces any more.

With all three options off the physics is bit for bit as before, so the rest of PH28 (the sail and the rider branches) stands on the same hull.

## 2. The bounce check first

The brief (flying_the_board.md 4.6): before touching the clip, find out whether the 1.8 Hz bounce of hull_balance.md section 14 is the clip's, by rerunning the bouncing case with the old rocker (a real porpoising survives, an artefact goes), with 13 grid rows and a halved substep (an artefact of the grid changes, physics does not), and by splitting the clipped share out of the water's +4.5 W in `pitch_budget.gd`.

`pitch_budget.gd` now prints what the clip withholds (the pulls it does not apply, as a force and a moment, and their power into the bounce), the pitch's mean and swing, the bounce's frequency and the wet front's range, and it takes `--sim.substeps=6` and `x,y,z` overrides for the mast foot and the fin. The case that bounced in Session 60 was Max's setup before the bounce lock of step 18; after it the setup is steady. The two cases that had bounced on this branch's history were run (90 s, the last 30 s measured):

| Case | Pitch mean / SD, bounce | Wet front | What the clip withholds (hull moment about its centre of mass) |
|---|---|---|---|
| 24 kt beam reach, the mast foot at 1.245 m (Session 60's "2 cm from a bounce") | −0.28° / 0.00°, none | 1.25 m | +246 N·m |
| the same with the old rocker (0.08 m over 0.9 m) | +0.07° / 0.00°, none | 1.67 m | −135 N·m |
| the same with 13 grid rows | −0.21° / 0.00°, none | 1.23 m | +224 N·m |
| the same with a halved substep | −0.28° / 0.00°, none | 1.25 m | +246 N·m |
| 18 kt beam reach, the default | −0.30° / 0.01°, none | 1.27 to 1.28 m | +223 N·m |
| 24 kt beam reach, the default | −0.33° / 0.00°, none | 1.25 m | +250 N·m |
| 18 kt beam reach, 12° of bank (the railing-out case that porpoised in step 16) | −6.98° / 0.01°, none | 2.28 m (the whole bottom) | −1256 N·m |
| the 12° bank with the old rocker | +1.52° / 0.00° | 1.83 m | −21 N·m |

So nothing bounces, and the +4.5 W of section 14 cannot be split: it belonged to a sailor rule that is gone. What the static numbers say: on the beam reaches the clip withholds pulls worth 220 to 250 N·m of bow-up moment about the hull body's centre of mass (the pulling strips sit on the rocker between 0.7 and 1.2 m from the tail, aft of the hull-and-rig body's centre at about 1.2 m), and at 12° of bank, where the board rides nose-down with the whole bottom wet, 1256 N·m the other way. Those pulls, applied, are what the options below measure. Thirteen rows and a halved substep change nothing, so the grid is not the cause of anything here.

With the pull on (option 1) the 12° bank case bounces violently (pitch SD 6°, the hull's water putting +59 W into the heave, the speed down to 6.6 m/s); with the pull and the rolled plate together it is steady at −1.0°.

## 3. What a strip may pull, held still

The probe (`Game/dev/hull_probe.gd`) holds the hull at a trim, a heel and a wet length at the 18 kt beam reach's speed (14.97 m/s) and prints the strips' lift against Savitsky's (1964) for the same plate. The review's table, extended with the options. "Sav" is Savitsky's lift at the low rail's wet length (the model's anchor); the numbers are the lift over it.

**The JP SL 72, 1° of trim:**

| Wet length | Level: the clip | Level: the pull, bounded (1 head) | Level: the pull, unbounded | 2° heel: the clip | 2° heel: bounded | 2° heel: unbounded |
|---|---|---|---|---|---|---|
| 0.60 m | 0.81 | 0.81 | 0.81 | 0.28 | 0.28 | 0.28 |
| 0.80 m | 0.89 | 0.89 | 0.89 | 0.40 | 0.40 | 0.40 |
| 1.00 m | 1.57 | 1.05 | 1.04 | 0.79 | 0.73 | 0.72 |
| 1.28 m | 1.23 | 1.20 | 1.17 | **2.19** | 1.29 | 1.12 |
| 1.50 m | 1.45 | 1.28 | 1.17 | **3.27** | 1.40 | 1.16 |

**The old freeride 2.40 (flat to 1.5 m from the tail):** identical with the pull on and off at 1.0, 1.28 and 1.5 m, level and heeled (413, 609, 692 N level); at 1.7 m, on its nose rocker, 1295 → 999 N level.

What the bound is. The buoyancy model applies the full hydrostatic pressure under the bottom at planing speed (`planing_buoyancy_factor` 1.0), and the strips add the dynamic part. The pressure under the bottom cannot fall below the air's: at the rails and the transom the water is at the air's pressure, and air would get in. So the dynamic part may be negative by at most the hydrostatic head, ρ g depth, over the strip's wet area. That is `strip_suction_heads` 1: geometry, an estimate of where the flow ventilates, not a fit. 0 is A-05 (no pull at all, which ignores the head the buoyancy model does apply); a large number is the strip theory as written (which ignores ventilation); anything between is a fit and has no source.

The bound binds: at 1.28 and 1.5 m heeled the theory wants 150 to 270 N of pull and the head allows 38 to 88 N, which is why the bounded lift sits between the clip's and the unbounded theory's. The review's hope of "within 25 % of Savitsky at 1.0, 1.28 and 1.5 m" is met level (5 to 28 %) and nearly heeled (27, 29, 40 %: the low end at 1.0 m is the heeled under-count of section 5, the high end the rocker's root). The wall is gone: the lift rises 1.09-fold from 1.28 to 1.5 m instead of 1.5-fold. The unbounded theory gives 1.04 to 1.17 level, the 10 to 20 % thin-wing theory predicts for a rockered plate (review_hull.md section 7).

## 4. Where the push sits, and the transom relief

The brief asked for the push's centre within 0.05 m of Savitsky's on both boards from one to two and a half beams of wet length. Building it showed what the model had:

| Case (14.97 m/s, 1°) | The clip: the push ahead of Savitsky's centre | With `push_at_savitsky_centre` |
|---|---|---|
| SL 72 level, 0.6 / 1.0 / 1.28 / 1.5 m | +0.04 / +0.15 / −0.15 / −0.04 m | 0.000 |
| SL 72, 2° heel, 1.0 / 1.28 / 1.5 m | +0.14 / +0.19 / +0.27 m | 0.000 |
| freeride level, 1.0 / 1.28 / 1.5 m | +0.12 / +0.18 / +0.25 m | 0.000 |
| freeride 2° heel, 1.0 / 1.28 / 1.5 m | 0.00 / +0.01 / +0.04 m | 0.000 |
| test_hull's flat plate with its 2° vee (7 m/s, 4°, 1.07 m wet) | +0.09 m (9 % of the wet length, inside that test's 10 % band) | 0.000 |

A-03 ("the root force spread as a triangle whose centroid is Savitsky's centre of pressure") held for the front root's push only. The push where the water reaches further across the bottom going aft (the oblique spray root of a vee or a heeled bottom, step 3's wetting gains) sat on its own strips, which are the forward ones on a level vee (the chine-dry part) and the whole length on a heeled board, so the push of the whole sat forward of Savitsky's centre on the old board level by 0.12 to 0.25 m, and on the SL 72 forward or aft depending on the clip. With the option, that oblique push joins the front root's and the triangle is solved (bisection, 30 steps) so that the whole push has Savitsky's centre, to the millimetre, on both boards, level and heeled, from 0.8 to 1.8 m. It is always on with the pull, since with the strips pulling the whole push would otherwise sit behind Savitsky's centre.

**The transom relief.** flying_the_board.md 4.3 suspected the half-beam relief of double-counting Savitsky's transom fall-off, 0.87 of his lift at 0.6 m level. Level the relief does nothing: on the flat tail the strips' convective forces are nil, and the root's push is never relieved; the 0.81 to 0.89 at 0.6 and 0.8 m level is the vee's chine-dry front counted twice (section 5). Heeled it did matter, inconsistently: the oblique root's push was relieved at the transom while the front root's never was, which left a heeled bottom at 0.6 m and 4.5° carrying 0.85 of the anchor's lift. With the push placed at Savitsky's centre the oblique root joins the front root unrelieved and the relief (A-02) acts on the convective part only, which is what A-02 described. With the options off nothing changes.

## 5. The heeled bottom at short wet parts (TN 4187)

The model anchors the strips' total to Savitsky's lift at the low rail's wet length over the full beam, scaled by how much of the width the strips wet. At a short wet part on a heeled board that gave a third to a half of what NACA TN 4187 (Savitsky, Prowse and Lueders 1958) measured on a rolled flat plate, and next to nothing at 4.5°. `heel_as_rolled_plate` takes TN 4187 as the anchor: Savitsky's lift at the mean wetted length of the two rails (the high rail dry over 2 b tan φ / (π tan τ) more than the low one, its equation 2), the heel as an added deadrise, and the strips' total anchored on the widest wet strip, so the vee's chine-dry front is counted once.

| 14.97 m/s, lift in N | 0.6 m | 0.8 m | 1.0 m | 1.28 m |
|---|---|---|---|---|
| 1°, 2° heel: the model / TN 4187 | 90 / 190 | 172 / 303 | 417 / 467 | 1447 / 1290 |
| 1°, 2° heel: the option (with the pull) | 203 | 304 | 432 | 755 |
| 1°, 4.5° heel: the model / TN 4187 | 2 / 110 | 12 / 177 | 97 / 290 | 662 / 681 |
| 1°, 4.5° heel: the option (with the pull) | 121 | 184 | 282 | 580 |
| 1°, level: the model / Savitsky | 258 / 320 | 379 / 426 | 833 / 531 | 815 / 662 |
| 1°, level: the option (with the pull) | 320 | 426 | 580 | 792 |
| 2°, 2° heel: the model / TN 4187 | 415 / 592 | 640 / 811 | 1062 / 1096 | 2298 / 2145 |
| 2°, 2° heel: the option (with the pull) | 592 | 811 | 1032 | 1403 |

So held still the option is the measurement itself at short wet parts, and level it is Savitsky's at 0.6 and 0.8 m. Beyond 1.0 m the rocker's root shows (1.10 to 1.40 of the anchor), as in section 3. This is the item that would let the hull reward Max's rail (PH27): a heeled board carrying its load on a shorter wet part. Sailing, see section 6.

## 6. Sailing: the reach check

`tools/reach_check.sh --seconds=90 --from=60`, flat water, steady wind; speed in m/s, the wet length in m, the pitch SD in degrees. The base is the branch `ph28/sail-and-hull` (review_sim.md section 2).

| Case | The base (the clip) | The pull, bounded | The pull, unbounded | The push at Savitsky's centre (the clip kept) | The rolled plate |
|---|---|---|---|---|---|
| 12 kt 60° | 7.25 (1.35, 0.00) | **4.97 (2.28, 2.18)** not planing | 4.97 (2.28, 2.18) | 7.39 (1.55, 0.00) | 7.21 (1.38, 0.00) |
| 12 kt 100° | 11.62 (1.22, 0.00) | 10.71 (1.60, 0.00) | 10.64 (1.60, 0.08) | 10.92 (1.53, 0.00) | 11.58 (1.22, 0.00) |
| 12 kt 135° | 5.81 (1.78, 0.00) | 5.95 (1.88, 0.46) | 5.95 (1.88, 0.46) | 5.91 (1.86, 0.56) | 5.81 (1.78, 0.00) |
| 18 kt 60° | 10.39 (1.29, 0.00) | **3.86 (2.28, 3.29)** not planing | 3.88 (2.28, 3.25) | 9.87 (2.02, 0.00) | 10.32 (1.30, 0.00) |
| 18 kt 100° | 14.97 (1.28, 0.01) | 13.35 (2.28, 0.04) ploughing | 13.30 (2.03, 0.01) | 14.38 (1.56, 0.29) | 14.92 (1.28, 0.02) **one catapult at 19.5 s** |
| 18 kt 135° | 13.30 (1.04, 0.17) | 11.97 (1.17, 0.75) | 11.95 (1.18, 0.80) | 12.08 (1.17, 0.80) | 13.23 (1.03, 0.19) |
| 24 kt 60° | 10.79 (1.28, 0.00) | **fell** | fell | 10.35 (1.70, 0.00) | 10.79 (1.29, 0.00) |
| 24 kt 100° | 16.77 (1.25, 0.00) | **fell** (10.42, 1.79) | 14.81 (2.04) then fell | 16.32 (1.46, 0.00) | 16.75 (1.25, 0.01) |
| 24 kt 135° | 18.29 (1.27, 0.04) | **fell** | fell | 16.78 (1.38, 0.19) | 18.28 (1.27, 0.10) |

The pull and the rolled plate together are the pull's column within 1 %, with the same falls (the pull decides).

**Why the board does not plane with the pull.** On the 18 kt close reach it never gets over the hump: fully wet, 0° of trim, 3.9 m/s, the planing ratio 0.00. On the beam reach it ploughs at 13.3 m/s with the whole bottom wet, the dynamic lift 0.02 of the weight, carried by the buoyancy (the sunk board displaces more than it weighs). In both the bottom is wet up to the nose, where the rocker meets the water at 9 to 10°: the root there pushes hard, and the strips behind it, down the convex rocker, take the push back (the theory: the water follows the bottom and gives its momentum back; bounded by the head, which is large with the board deep). Net, nothing. With the clip the root's push stands and the strips' pull is dropped, which lifts the nose, raises the trim and gets the board onto its tail. So the clip's "wrong" lift on the rocker is what the sim's hump crossing lives on, and the sailor rules downstream (the stance that moves aft above hump speed when the bow is low, the trim press scaled by the planing ratio) never get a planing ratio to act on. Where the pull does plane, it planes shorter and higher: the 18 kt broad reach on 1.17 m at 2.4° of trim (the clip: 1.04 m at 1.7°), bouncing (SD 0.75°).

In the real world a board at 13 m/s with its nose rocker in the water does not plough; it comes up. What a real rockered bottom does at speed, the flow attached and sucking as the theory says or ventilated as A-05 says, is the question, and the project's sources do not measure it. The sim also has no bow-up moment of the hump of its own (the bow wave's); the clip's root push on the rocker has stood in for it.

**The push at Savitsky's centre, with the clip.** Sails everywhere, no falls, steady on seven of nine (the 18 kt beam reach at 0.29°). The wet part is 0.2 to 0.8 m longer and the board 2 to 8 % slower. The balance says why: the push pinned further aft at a given wet length means a longer wet part for the same moments. It is not a lever toward the goal of 0.6 to 1.0 m; it is the honest state of a model whose push is at the measured centre, if the measured centre of an attached flat plate applies to a ventilated rockered bottom, which is not known. Measured, for Michiel.

**The rolled plate.** The same as the clip within 1 % (12 kt 60° −0.5 %, 18 kt 135° −0.5 %), the wet lengths the same, and one catapult on the 18 kt beam reach while settling, reproducible (two runs). The trace (the reach CSV): from 15 s the board porpoises at 15 m/s with the wet front swinging from 0.5 to 2.0 m and the pitch from −4° to +5°, growing each swing (the fin slipping, the yaw rate to ±55°/s), to +14° at 19.3 s and a catapult at 19.5 s; after the waterstart (23.5 s) the run is steady and the 60 to 90 s means are the clip's. The cause is in how the strips are anchored: the whole 2D strip total, the damping terms included, is scaled by Savitsky's lift over the slender reference; with the reference on the widest wet strip, a heeled board on a short wet part has a sliver for a reference (0.05 m at 4.5° and 0.6 m) and the factor runs to 36 (the probe), so the convective damping is scaled 36-fold too and the board's pitch is no longer damped as a plate's but kicked. The fix is a reference that keeps the convective terms at a flat plate's scale while the static lift takes TN 4187's; that is a change to step 4 of the model and is not built here.

## 7. What is on, what is off, and what would decide it

| Option | Default | Why |
|---|---|---|
| `strip_suction_heads` | 0 (the clip, A-05) | with the pull, bounded or not, the board does not plane |
| `push_at_savitsky_centre` | false (true with the pull) | sails, but longer and slower, and for a ventilated bottom Savitsky's centre is no better sourced than A-03; Michiel's call |
| `heel_as_rolled_plate` | 0 | right held still, but catapults once while settling (the anchor's factor on a wet sliver) |

What would decide the clip (A-05): a measurement of a rockered planing bottom's lift and pressure, which the project does not have. The nearest things: a photo or video of Max's board from the side at full speed on flat water (flying_the_board.md section 7, item 1: how much of the board is wet and how high the nose rides) against the probe's wet length for the same load; or a tank test from the literature on a convex (rockered) planing surface. Until then the clip stands, labelled as what it is: the model's assumption that the flow lets go of the rocker, with 2 to 3 times Savitsky's lift at the ridden state, and the thing the sim's hump crossing rests on.

For the goal of flying the board (0.6 to 1.0 m wet at 1.0 to 2.5°), nothing here is a lever. The levers are in the balance (the rider's couple, one body, the rake, the lean: the rider branch and the autopilot) and, for the hull, two things this session found rather than fixed: the sim has no bow-up moment of the hump of its own, and the anchoring of the strips scales their damping with their lift.

## 8. Checks

- `tools/test.sh unit -gselect=hull_suction`: 7 tests, 261 asserts; `tools/test.sh`: 571 of 571; `tools/check.sh`: 290 files, 0 failed.
- The probe and the reach checks above; the pitch budgets (`.logs/hull_bounce_*.txt`, `.logs/hull_bank12_*.txt`, `.logs/hull_probe_*.txt`, `.logs/hull_reach_*.txt` on this PC).
- With all three options off the physics is bit for bit the base's (the off paths are untouched; the 564 tests of the base pass unchanged), so the validation run and the push check of the merged branch cover this one. The pull and the rolled plate were not run through the push check (gusts and waves) or validation: the pull does not plane on flat water, and the rolled plate catapults on flat water, so there was nothing to measure there yet.
- Not verified: how any of it feels; what a real rockered bottom does.

## 9. Tests

`Game/tests/unit/test_hull_suction.gd`, the hull held still as the probe holds it, Savitsky's and TN 4187's lift computed in the test:
1. with the options off the clip is the old rule (0.7 to 0.9, 2.0 to 2.4, 3.0 to 3.5 of Savitsky at 1.0, 1.28, 1.5 m heeled; the freeride at 1.5 m level Savitsky's within 3 %);
2. the bounded pull takes the wall out (the bands of section 3; the unbounded 1.05 to 1.25 at 1.5 m heeled);
3. the push at Savitsky's centre within 0.05 m on both boards, level and heeled, 0.8 to 1.8 m, with the pull or with the centre option alone; the clip's push more than 0.1 m ahead at 1.28 m heeled;
4. the old board's lift unchanged below 1.5 m within 0.5 %, its push moved to Savitsky's centre (level it was 0.1 to 0.3 m ahead), the clip's extra gone on its nose rocker at 1.7 m;
5. the flat plate's lift unchanged by either option (Savitsky's within 2 %), its push to Savitsky's centre (0.05 to 0.15 m ahead before);
6. level the rolled-plate anchor gives Savitsky's within 10 % at 0.6 and 0.8 m (under 0.98 of it before), within 15 % at 1.0 m;
7. heeled the lift follows TN 4187 within 15 % from 0.6 to 1.0 m at 2 and 4.5° (under 0.85 of it before at 0.8 m).

The bands are a record of what the theory gives on the shipped board, as section 3 and 5 list it; nothing was fitted to them.

## Sources

- Savitsky, D. (1964), *Hydrodynamic design of planing hulls*, Marine Technology 1(1): the lift, the centre of pressure, the chine-dry length (as in the model).
- Savitsky, D., Prowse, R. E. and Lueders, D. H. (1958), NACA TN 4187, *Hydrodynamic forces on a flat planing surface at yaw and roll*: equation 2 (the high chine dry), the roll as an effective deadrise.
- Zarnick, E. E. (1978), the strip theory of planing (the force as the rate of change of the added mass's momentum), as cited in `hull_model.gd`.
- Shuford (1958), Faltinsen (2005), on the planing buoyancy (F21), for the head's argument.
- [review_hull.md](review_hull.md) finding 1 and section 7 (the thin-wing estimate); [flying_the_board.md](flying_the_board.md) section 4; [hull_balance.md](hull_balance.md) sections 7, 8 and 14; `PHYSICS_SPEC.md` section 5 (F21 to F24, A-02, A-03, A-05).
