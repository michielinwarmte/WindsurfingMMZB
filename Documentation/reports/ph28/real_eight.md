# The real eight: Max's HGO 8.0 and the twist that follows its formula (branch `ph28/real-eight`)

30 October 2026, for Max and Michiel. Built on `ph28/sail-and-hull` (7f337a7). It answers `review_sail.md` findings 1 to 6 and 11, and Max's answers 12 ("the real" sail) and 22 ("follow the formula") in `questions_for_max.md`. Every number below says where it comes from; the ones that are not measured say "estimate". All measurement logs are in `.logs/real_eight_*` in this worktree (not committed).

## In short

- The game's default sail is now Max's real Severne HGO 8.0: luff 5.22 m, boom 2.20 m, on an Apex 490 with a 36 cm extension (the masthead 5.26 m up). Before, it had the mast's length as its luff (4.9 m), and a 3 % fudge (`lift_slope_factor` 1.03) made up for that. The fudge is gone.
- The sail's twist now follows its formula at every wind (Max's choice). In the wind tunnel the sail was measured up to 15.5 kt of apparent wind. The game's planing reaches see 21 to 39 kt of apparent wind, and there the sail now keeps 0.34 to 0.63 of a stiff sail's pull per degree. Before, it kept 0.75 everywhere above about 16 kt. **Neither choice is measured: both extrapolate.**
- **The catapult.** At 24 kt in gusts and waves the pushed sailor no longer catapults: no falls in six cases of 400 s each. The old floor gives no falls either, on today's gear. The catapult comes back from 28 kt, with the formula and with the floor alike. **So the catapult unit test stays at 24 kt and still passes:** heading up sheeted fully in, the sailor goes over at 20.4 s.
- On flat water the board is 1 to 4 % faster at 18 and 24 kt (except the 24 kt broad reach, 2.3 % slower), and 2 to 7 % slower on the 12 kt close and beam reaches. **The speed in strong wind depends on one extrapolated number:** the twisted sail's force point coming down (`twist_ce_drop`). Without it the formula sail is 7 to 11 % slower on the 18 and 24 kt close and beam reaches.
- **New:** the force's height now depends on the angle of attack, from the tunnel's Fig. 8d. With the sail eased, the force sits up to a metre lower.
- **Validation:** 37 pass, 7 fail, 2 pending (the same count as the base). One known red went green (the speed on waves at 120°). One new red appeared, and it is caused by the formula: the board porpoises when the sailor aims for 12° of heel, where the old floor held to 15°.

## What changed

| What | Old | New | Source |
|---|---|---|---|
| `luff_m` (the 8.0) | 4.9 m (the mast's length) | **5.22 m** | Severne's HGO page and Starboard's iQFOiL equipment table, as cited in `sail_config.gd` and `review_sail.md` (not re-checked online in this session); Max: "the real" |
| `boom_m` | 2.0 m | **2.20 m** | the same |
| `mast_m` (the rig's inertia, the drawn mast) | 4.9 m | **5.26 m** | Apex 490 plus the 36 cm race extension (Starboard's table, as cited) |
| `lift_slope_factor` | 1.03 | **1.0** | with the real luff (aspect ratio 3.41, the paper's 3.36) the formula gives the tunnel's 0.069 per degree itself; `test_sail.gd` passes against Fig. 8a |
| `twist_pressure_pa` | 140 Pa | **125 Pa** | the formula's value for the tunnel's own 8 m² sail. It is a fit through three wind speeds, not a measurement; a direct fit gives about 100 to 110 Pa (`review_sail.md` finding 4). The 6.5 keeps 140, an estimate |
| `twist_min_factor` | 0.75 (a floor) | **0.1** (a numerical guard: the formula reaches it only at 83 kt of apparent wind) | Max, 30 October 2026: "follow the formula" |
| The centre of effort's height by angle of attack (new: `ce_height_table_deg/share`, `ce_height_share()`) | fixed at 0.41 of the luff (only the twist lowered it) | **× 0.53 at 1.3°, 0.855 at 5.3°, 0.94 at 8.7°, 1 from 12.2°** | Fig. 8d of Zhang et al. 2025, read in this session to about 0.02 m (below) |
| The stiff fin's pin in `test_fin_bend.gd` | 1.72°, 652 N, 22 N | **1.82°, 692 N, 24 N** | a regression pin, re-pinned as its comment says to (below) |
| The 3D models (`Game/assets/models/*.glb`) | 4.9 m sail | the 5.22 m sail, foot and roach adjusted | **visual only.** Built by the previous builder. A rebuild here with Blender 5.2.2 gives the same geometry (the same vertex counts and bounding boxes), so the committed files were kept. Checked in `dev/rig_view` from the side |

Not changed, open for Michiel: `rig_mass_kg` stays 9.5 kg. The published parts add up to about 12.4 kg (the comment in `sail_config.gd` gives the sum, with a 1.3 kg estimate for the extension, base and lines). With 12.4 kg the beginner's board no longer gets out of irons after a tack in 18 kt.

**A correction made in this session.** The branch's first table for the height by angle of attack (0.5, 0.85, 0.975, 1 at 1, 5, 9 and 12°) divided the heights by 2.0 m. That mixes in the lowering caused by the wind, which `twist_ce_drop` already models. Read off the figure, as a share of the same wind's height at 12.2° (outhaul-on sail; 4, 6 and 8 m/s):

| Angle | 4 m/s | 6 m/s | 8 m/s | Mean (the table) |
|---|---|---|---|---|
| 1.3° | 1.23 / 2.07 = 0.60 | 1.08 / 2.01 = 0.54 | 0.91 / 1.95 = 0.47 | 0.53 |
| 5.3° | 0.88 | 0.85 | 0.84 | 0.855 |
| 8.7° | 0.95 | 0.94 | 0.93 | 0.94 |
| 12.2° | 1 | 1 | 1 | 1 |

The steady reaches sail at 12.5 to 18° of attack, so this table does not change them: the reach check is the same to the last digit with either table. It does act on the eased, luffing and backed sail, in tacks and gybes, and in gusts.

## The measurements

### The reach check (`tools/reach_check.sh --seconds=90 --from=60`; steady wind, flat water)

The base numbers are the base branch's, from `review_sim.md` section 2. Each cell gives the speed in m/s, then in brackets the wet length (m) and the pitch SD (°).

| Case | Base | This branch | Speed | Angle of attack, sheet, apparent wind, twist share |
|---|---|---|---|---|
| 12 kt 60° | 7.25 (1.35, 0.00) | 6.76 (1.46, 0.00) | −6.8 % | 13.8°, 1.00, 21 kt, 0.63 |
| 12 kt 100° | 11.62 (1.22, 0.00) | 11.36 (1.18, 0.00) | −2.2 % | 16.6°, 1.00, 23 kt, 0.60 |
| 12 kt 135° | 5.81 (1.78, 0.00) | 5.88 (1.77, 0.00) | +1.2 % | 18.0°, 0.44, 9 kt, 0.91 |
| 18 kt 60° | 10.39 (1.29, 0.00) | 10.69 (1.30, 0.00) | +2.9 % | 13.5°, 1.00, 33 kt, 0.41 |
| 18 kt 100° | 14.97 (1.28, 0.01) | 15.10 (1.32, 0.00) | +0.9 % | 15.0°, 0.92, 31 kt, 0.44 |
| 18 kt 135° | 13.30 (1.04, 0.17) | 13.50 (1.06, 0.12) | +1.5 % | 18.0°, 0.83, 18 kt, 0.70 |
| 24 kt 60° | 10.79 (1.28, 0.00) | 11.20 (1.34, 0.00) | +3.8 % | 12.5°, 0.92, 39 kt, 0.34 |
| 24 kt 100° | 16.77 (1.25, 0.00) | 17.44 (1.18, 0.00) | +4.0 % | 13.7°, 0.84, 37 kt, 0.36 |
| 24 kt 135° | 18.29 (1.27, 0.04) | 17.87 (1.24, 0.01) | −2.3 % | 18.0°, 0.83, 24 kt, 0.57 |

The last column is the mean over the same 30 s, from the per-case CSVs (`.logs/real_eight_reach_csv/`). All nine cases are steady and none fell. The 12 kt close and beam reaches are sheeted fully in, so there the sail is the limit, and a weaker sail is slower.

To find out why strong wind got faster, I ran two A/B checks on the same code at 18 and 24 kt (`.logs/real_eight_reach_floor.txt`, `.logs/real_eight_reach_no_ce_drop.txt`):

| Case | The formula | The old floor (0.75) | The formula, `twist_ce_drop` 0 |
|---|---|---|---|
| 18 kt 60 / 100 / 135° | 10.69 / 15.10 / 13.50 | 10.49 / 14.74 / 13.64 | 9.47 / 14.07 / 13.38 |
| 24 kt 60 / 100 / 135° | 11.20 / 17.44 / 17.87 | 11.32 / 16.90 / 18.50 | 9.97 / 15.76 / 17.89 |

The formula and the floor are within 3.4 % of each other. Take away the twist's lowering of the force point and the formula sail loses 7 to 11 % on the close and beam reaches. The lower force point means a smaller heeling moment, so the sailor can hold more force. At 37 kt of apparent wind the formula lowers the point by 20 %. The tunnel lowered it by 2 to 6 % in the 12 to 18° band where the sailor sails (Fig. 8d, from 4 to 8 m/s). **This 20 % is the least supported number in the build.**

### The push check (gusts, waves, the height gradient; neutral `hike_share` 1.0 and pushed 1.6)

24 kt, 400 s per case (`--seconds=400`; the brief's 120 s run gave the same: no falls). The formula is the build; the floor is the same code with `--sail.twist_min_factor=0.75`.

| Course | Formula: speed m/s, falls, angle of attack | Floor: speed, falls, angle |
|---|---|---|
| 48°, neutral | 7.67, **0**, 12.1° | 7.71, **0**, 6.5° |
| 48°, pushed | 7.93, **0**, 12.1° | 8.52, **0**, 7.2° |
| 100°, neutral | 14.21, **0**, 13.8° | 13.94, **0**, 8.3° |
| 100°, pushed | 15.08, **0**, 14.6° (fin slip at most 3.5°) | 14.30, **0**, 9.1° (fin slip up to 45.5°, the fin's load 0.95: a near spin-out) |
| 135°, neutral | 13.29, **0** | 13.48, **0** |
| 135°, pushed | 13.31, **0** | 13.50, **0** |

18 kt, 120 s per case (the formula): no falls. The speeds are 6.28 and 6.34 at 48°, 12.31 and 12.67 at 100°, and 8.22 and 8.22 at 135° (neutral and pushed).

Where the catapult comes back (120 s per case, six cases per wind):

| Wind | The formula: falls | The floor: falls |
|---|---|---|
| 28 kt | **3**, all pushed (100°: 1 catapult; 135°: 2 catapults) | **4** (135° pushed: 3 catapults, 1 fell off) |
| 30 kt | **4** (100° neutral: 1 catapult; 135° neutral: 1 fell off; 135° pushed: 2 catapults) | **16**, and the board hardly sails (1.8 to 6.8 m/s on three cases) |

### The sail's force by hand (sea-level air, the model's own formulas)

I wrote a small script of `lift_coefficient`, `drag_coefficient` and `twist_factor`. It first reproduced `review_sail.md` finding 11's floored table to the newton. The total is lift and drag together.

| Apparent wind | q, q·A | Sail, share | 8° | 12° | 18° (peak) |
|---|---|---|---|---|---|
| 18 kt (9.26 m/s) | 52 Pa, 420 N | the old sail (luff 4.9, ×1.03, 140 Pa, floor), 0.75 | 215 N | 301 N | 413 N |
| | | the 8.0 with the floor, 0.75 | 218 N | 306 N | 419 N |
| | | **the 8.0, the formula, 0.70** | **205 N** | **287 N** (lift 285, drag 34) | **409 N** |
| 24 kt (12.35 m/s) | 93 Pa, 747 N | the old sail, 0.75 | 381 N | 534 N | 734 N |
| | | the 8.0 with the floor, 0.75 | 388 N | 544 N | 745 N |
| | | **the 8.0, the formula, 0.57** | **297 N** | **415 N** (lift 412, drag 50) | **678 N** |
| 37 kt (19.0 m/s; the 24 kt beam reach's own) | 222 Pa, 1776 N | the 8.0 with the floor, 0.75 | 923 N | 1293 N | 1771 N |
| | | **the 8.0, the formula, 0.36** | **448 N** | **624 N** | **1420 N** |

- At 18 kt of apparent wind the formula costs 2 to 6 %.
- At 24 kt it costs 23 to 24 % below the stall and 9 % at the peak, where `twist_peak_share` gives most of the loss back. (The review's "585 N with the formula at the peak" left that rule out.)
- At 37 kt, where the 24 kt beam reach actually sails, the formula keeps 0.36 of the stiff sail's lift up to 12° but 0.71 at the peak. So between 12 and 18° the lift climbs about three times as steeply as below 12°: 624 N at 12°, 867 N at 14°, 1420 N at 18°. The sailor sails in that band. This curve shape comes from `twist_peak_share`, which was read at 8 m/s and is used here at almost six times the tunnel's highest pressure.

### Validation (`tools/test.sh validation`, 567 s, one process)

The full run gave 36 pass, 8 fail, 2 pending. After the fin's re-pin (its file re-run alone: 4/4) that is **37 pass, 7 fail, 2 pending**, the base's count. Reds by cause:

| Red | Now | Base | Cause |
|---|---|---|---|
| `test_polar_sweep.gd` real-world range | 60°: 9.08, 90°: 13.11, 105°: 14.39, 120°: 13.43, 135°: 7.97 m/s | 9.85, 13.02, 14.03, (in band), 7.85 | known: the band was drawn for a 120 l board, a 6.5 and 75 kg |
| `test_top_speed` | 14.39 m/s | 14.03 | known, same cause |
| `test_planing_onset_and_fully_planing` | 14.4 kn | 15.0 | known, red on purpose (8 to 10) |
| `test_stable_at_speed_on_the_broad_reach` | the trim 0.36° | 0.15° | known (the trim at speed) |
| `test_force_sanity_on_the_beam_reach` | the fin's side force 682 N | 677 N | known (no source for the 650 N band) |
| `test_skipper.gd`, the time at 12 kt | 13:05.8 | 13:38.5 | known; 33 s faster, still over 12:00 |
| **`test_rig_lean_and_fin_loading.gd`, "the tilted fin lifts more at 12 degrees"** | 236 N at 12° of heel against 286 N at 9°; the 12° run porpoises (pitch SD 3.25°) | passed | **new, caused by the formula:** the same file with the old floor on the same code passes (12°: 307 N against 258 N, pitch SD 0.32°). The railing-out limit falls from 15° to 12° of aimed heel. Kept red as the evidence, not loosened |
| Pending: `test_planing_wet_area.gd` targets 3 and 4 | the wet front 1.19 to 1.33 m; the push 0.90 to 1.24 m, the trim −0.05 to 0.09° | 1.19 to 1.28; 0.90 to 1.13 m, 0.38 to 0.82° | known (the "second lock") |

Gone green: `test_waves.gd`, the speed on waves at 120° (11.59 m/s against 13.43 flat, −13.7 %, inside the 15 %; the base was −17 %).

The re-pin: `test_fin_bend.gd`'s stiff fin lifted 692 N against its pin of 652 ± 5 %. The slip was 1.82° and the upward force 24 N, both inside their bands. Re-pinned to 1.82°, 692 N and 24 N, with a line in the test's trail. The cause is the sail: on the same code the reach check's 18 kt beam reach gives the fin 714 N with the formula and 659 N with the floor.

### The checks

- `tools/test.sh`: 567 of 567, twice: before and after my changes. In the catapult test the sailor goes over at 20.4 s.
- `tools/check.sh`: 289 files, 0 failed.
- `tools/screenshot.sh res://dev/rig_view.tscn ... --tack=starboard --figure=0`: the tall sail up to the masthead, its foot to the deck, looked at from the side.

## What the formula does to the catapult

Session 57 put the floor in because with a 0.5 floor a pushed sailor never catapulted at 24 kt. On today's gear (80 kg, the full hike, the straps and the bounce lock) neither the formula nor the floor catapults at 24 kt in 400 s. Both catapult again from 28 kt. At 30 kt the formula falls a quarter as often as the floor (4 against 16), because it pulls less in the gusts. So the catapult at 24 kt no longer depends on Max's choice. Getting overpowered just starts higher, at about 28 kt, with either extrapolation.

The catapult unit test (24 kt, sheeted fully in, heading up to 60°) still catapults, so it was not moved. Its comment now says so.

The formula has its own risk. The 12° heel run porpoises, and pushed hard the board gets nervous earlier when railed (the new validation red).

## Open items

1. **For Michiel: the extrapolation as a whole.**
   - The formula is used at up to six times the tunnel's highest pressure, and two numbers fitted inside the tunnel carry it there. `twist_peak_share` gives the steep lift from 12 to 18°. `twist_ce_drop` gives the 20 % lower force point that the speed depends on.
   - A measured point above 8 m/s would settle it. The paper has none.
   - Both numbers could be made angle-dependent, as Fig. 8d shows for the force point (a 2 % drop at 16.5° against 10 % at 5°). That is not built; it would be fitted inside the tunnel and extrapolated just the same.
2. **The new red:** railing out to 12° porpoises with the formula (`test_rig_lean_and_fin_loading.gd`). Kept red.
3. **The autopilot's own `alpha_luff_deg`** is 5.0 (`Game/sim/autopilot.gd:114`) and is not read from the sail's config (2.0). Its no-go band (line 230) and the "filled" angle after a tack (line 272) are 3° wider than the sail's luff fade (`review_sail.md` 7b). Not built.
4. **The rig's mass:** the real rig is about 12.4 kg (the published parts plus an estimate for the extension, base and lines). The config keeps 9.5 kg, because with 12.4 kg the beginner's board does not get out of irons after a tack in 18 kt. The comment in `sail_config.gd` says why. This is the rider's model, for Michiel.
5. **Not mine to edit:** ROADMAP.md line 105 still says "the rider cannot close the sail". What is built is "the sail closes and its top spills" (spec 2.17 now says so).
6. `cl_peak_deg` stays at 18, where the tunnel's stall is at about 20°. Not re-fitted.
7. `tools/push_check.sh` is mode 100644 in git. I ran it through `bash`; the lead is fixing the mode on the hull branch.
8. What I could not verify: how any of this feels to sail; the web sources for the sail's sizes (taken from the earlier builder's comment and the review, not re-read); the figure readings beyond about ±0.02 m.

## Sources

- [W-T] Zhang, Bertrand, Rabaud, Augier and Fermigier 2025, the full-scale wind tunnel study of an iQFOiL 8 m² sail, `Documentation/Science/2501.13254v1.pdf`. Fig. 8a (lift), 8d (the centre of effort's height, read in this session from a 500 dpi render), 8e, and page 13 (the stall delay, the wall effect).
- Severne's HGO page (severnesails.com/sails/hgo-hyper-glide-iqfoil/) and Starboard's iQFOiL equipment table (iqfoil.star-board.com/equipment/iqfoil-class/), as cited in `Game/sim/config/sail_config.gd` and `review_sail.md` (with windfoilen.nl's review).
- Max's answers 12 and 22, `Documentation/reports/ph28/questions_for_max.md` (main, b37124b).
- The base numbers: `Documentation/reports/ph28/review_sim.md` section 2; `review_sail.md` findings 1 to 12.
- Logs (this worktree, not committed): `.logs/real_eight_reach_check.txt`, `real_eight_reach_check_wip_table.txt`, `real_eight_reach_floor.txt`, `real_eight_reach_no_ce_drop.txt`, `real_eight_reach_csv/`, `real_eight_push_18.txt`, `real_eight_push_24.txt`, `real_eight_push_24_floor.txt`, `real_eight_push_24_400.txt`, `real_eight_push_24_400_floor.txt`, `real_eight_push_28_30.txt`, `real_eight_push_28_30_floor.txt`, `real_eight_validation.txt`, `real_eight_rig_lean_floor.txt`, `real_eight_fin_bend_repinned.txt`, `real_eight_unit_2.txt`, `real_eight_check_2.txt`. Push CSVs: `.sim_output/push/real_eight_*`.
