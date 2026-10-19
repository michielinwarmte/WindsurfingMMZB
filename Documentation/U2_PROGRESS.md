# U2 progress (handoff)

The live state of U2, "the fin bends, and its size". The plan and its execution brief are in [PLAYTEST_UPGRADES.md](PLAYTEST_UPGRADES.md). **The lead updates and commits this file after every launch, report and merge.** A lead who takes over starts here; U1's take-over prompt in [U1_PROGRESS.md](U1_PROGRESS.md) applies with U2 in place of U1.

- **Branch:** `feature/u2-fin` (from `feature/u1-planing-wet-area` at c1eee63). Agents work on `u2/<name>` branches, made from it in their own worktrees.
- **Last update:** 19 October 2026. Agents 1 and 2 merged; Stop 1 passed; agent 3 (fin_physics) launched with the lead's design.

## State

| # | Agent | Package | State | Branch | Report |
|---|---|---|---|---|---|
| 1 | `fin_sources` | the stiffness, the catalogue fins, the literature | merged | `u2/fin_sources` | [fin_sources.md](u2_reports/fin_sources.md) |
| 2 | `fin_measure` | the fin's baseline, the overrides, the telemetry, the what-ifs, the pending check | merged | `u2/fin_measure` | [fin_measure.md](u2_reports/fin_measure.md) |
| 3 | `fin_physics` | the bending fin, by the lead's design | running | `u2/fin_physics` | |
| 4 | `fin_look` | the bending mesh, the HUD, the screenshots, the checklist | waits for Stop 2 | `u2/fin_look` | |

| Stop | State |
|---|---|
| Stop 1, the lead: agents 1 and 2 in, the stiffness sourced | **passed** on 19 October 2026: the flex test is measured (IST Lisbon), the baseline is pinned, nothing regressed (verified by the lead: see Numbers) |
| Stop 2, the lead reviews agent 3's diff, then Michiel | not reached |
| Stop 3, Max's play-test | not reached |

## Next action

Agent 3 (`fin_physics`) is running on `u2/fin_physics`: the bending fin by the brief's design, the bend check made real, the 37 stiff/flex/44 cm comparisons. When it reports: **the lead reads its diff itself** (`git diff feature/u2-fin u2/fin_physics -- Game/sim`), checks it against the design point by point, merges if sound, verifies (`tools/check.sh`, `tools/test.sh`, `tools/test.sh validation`, `tools/reach_check.sh`), writes the numbers, and then stops at **Stop 2 for Michiel** with the diff, the spec sections and the report. Agent 4 (`fin_look`) is launched after Michiel's OK.

## Numbers

**Verified by the lead on the merged branch after Stop 1 (a514a49):** `tools/check.sh` 193 files, 0 failed; `tools/test.sh` 343 of 343; `tools/test.sh validation` 29 pass, 1 fail (U1's onset check, 11.6 kn, on purpose), 3 pending (U1's targets 3 and 4, the bend). The reach check equals U1's Latest in every old column. Fin columns (slip °, lift N, roll N·m, up N, stall %, heel °): 12 kt 60° 4.9, 464, 98, 37, 51, −4.5; 12 kt 100° 2.9, 498, 105, 39, 30, −4.5; 12 kt 135° 1.1, 74, 16, 1, 11, −0.8; 18 kt 60° 3.9, 487, 103, 38, 41, −4.5; 18 kt 100° 2.0, 527, 111, 41, 20, −4.5; 18 kt 135° 1.2, 323, 68, 6, 13, −1.1; 24 kt 60° 3.8, 505, 107, 40, 39, −4.5; 24 kt 100° 1.6, 546, 115, 42, 17, −4.5; 24 kt 135° 1.2, 520, 110, 37, 13, −4.2. The close reaches load the fin most (up to 51 % of stall at 12 kt); the broad reaches at 18 kt and the 12 kt broad reach barely heel, so the fin lifts nothing there.

**Baseline (the lead, 19 October 2026, the 18 kt beam reach of U1's Latest):** fin lift 527 N at a 2.0 deg slip (stall at 12 deg), drag 35 N, roll moment from the fin 111 N m, heel -4.5 deg, rig lean 25 deg, so the heel's upward part of the fin's force is about 41 N. Agent 2 measures the 9 cases.

**Baseline, agent 2 (`fin_measure`), on `feature/u2-fin` at d9f5a9b before any change:** `tools/check.sh` 192 files, 0 failed; `tools/test.sh` 343 of 343; `tools/test.sh validation` 29 tests: 26 pass, 1 fail (the onset, 11.6 kn, known), 2 pending (U1's targets 3 and 4). The reach check equals U1's Latest in every column, no fall, no NaN. Its new fin columns (telemetry only, no physics changed; every old column stayed identical):

| Case | Speed m/s | Pitch SD ° | Heel ° | Slip ° | Fin lift N | Fin roll N m | Up N | Stall % |
|---|---|---|---|---|---|---|---|---|
| 12 kt 60° | 7.58 | 0.00 | -4.5 | 4.9 | 464 | 98 | 37 | 51 |
| 12 kt 100° | 10.30 | 0.00 | -4.5 | 2.9 | 498 | 105 | 39 | 30 |
| 12 kt 135° | 6.41 | 0.05 | -0.8 | 1.1 | 74 | 16 | 1 | 11 |
| 18 kt 60° | 8.70 | 0.01 | -4.5 | 3.9 | 487 | 103 | 38 | 41 |
| 18 kt 100° | 12.74 | 0.00 | -4.5 | 2.0 | 527 | 111 | 41 | 20 |
| 18 kt 135° | 12.55 | 0.09 | -1.1 | 1.2 | 323 | 68 | 6 | 13 |
| 24 kt 60° | 9.06 | 0.00 | -4.5 | 3.8 | 505 | 107 | 40 | 39 |
| 24 kt 100° | 14.31 | 0.01 | -4.5 | 1.6 | 546 | 115 | 42 | 17 |
| 24 kt 135° | 16.04 | 0.26 | -4.2 | 1.2 | 520 | 110 | 37 | 13 |

Up = the world-upward part of the fin's force (today only from the heel); Stall % = the fin's lift coefficient as a share of its peak at 12°. **After agent 2's changes:** check 193 files, 0 failed; unit 343 of 343; validation 33 tests: 29 pass, 1 fail (the onset), 3 pending (U1's two and the bend of `test_fin_bend.gd`). The what-ifs are in `u2_reports/fin_measure.md`.

## Open items

- Max's own fins: brand, model, and if possible a flex test (clamp the base, hang a known weight at the tip, measure the tip's displacement).
- Inherited from U1: the red onset check, the pending wet-area targets, the hands' share, the rail-down angle, `board.glb`.

## Notes

Decisions and surprises along the way, newest first.

- 19 October 2026 (agent 2): `--fin.<field>=` overrides, fin columns in the reach check, `fin_up_n`, `fin_load_share`, `fin_tilt_deg` (from the force itself, so agent 3's tilt shows up by itself) and `fin_bend_tip_deg` in the telemetry and the HUD; `test_fin_bend.gd` pins the stiff fin (slip 1.98°, lift 526 N, up 41 N) with the bend pending. The fin works at 13 to 20 % of its stall on the planing reaches. A 44 cm stiff fin drops the slip by a quarter and raises the roll moment 13 %, but lifts no more: a stiff fin only lifts more by heeling more (bank 0 to 24°: 20 to 243 N up at 18 kt; steady to 20°, wobbling at 24°; at 24 kt 135° it wobbles from 8° on).

- 19 October 2026 (agent 1): the stiffness has a measured source: a 37 cm F-Hot carbon slalom fin, 100 N at 80 % of the span moves the load point 20 mm (Nascimento 2017, IST Lisbon); its FEA bends the tip 0.106 mm per newton of sailing lift, the brief's beam 0.112 mm, within 6 %. No G10 test found (G10 probably 2 to 4 times stiffer, estimate). Unifiber G10 freeride: 38 cm 365 cm², 44 cm 411 cm². Makers say a soft tip lifts the board and shrinks the wet area; no number anywhere for the upward force. Spin-out at 8 to 16° in three measurements. Twist findings contradict each other: left out, as planned. Preview with the beam: 70 N up from the bend at 527 N on the 38 cm fin, 161 N at 800 N; the 44 cm fin 105 and 238 N (tip angle 32° at 800 N, near the 35° cap). **The lead corrected the chord law:** `c_root = area / (0.686 × span)` keeps the area right for every span.

- 19 October 2026 (the lead): the fin's upward push has two parts, the board's heel (in the model, 41 N today) and the fin's bend (not in the model). A fin bent toward its force tilts that force upward on both tacks. The bend is a cantilever with the stiffness falling as the chord to the fourth power, so the tip does the bending; one flex test sets the scale. Details in the brief.
