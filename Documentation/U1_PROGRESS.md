# U1 progress (handoff)

The live state of U1, "planing on a smaller wet area". The plan and its execution brief are in [PLAYTEST_UPGRADES.md](PLAYTEST_UPGRADES.md). **The lead updates and commits this file after every launch, report and merge.** A lead who takes over starts here.

- **Branch:** `feature/u1-planing-wet-area` (from `main` at 561849c). Agents work on `u1/<name>` branches, made from it in their own worktrees.
- **Last update:** 19 October 2026. Agent 4's round 3 (U1.2, U1.3) merged (1cf467a). **Stopped for the team:** a stop rule fired on targets 3 to 5. Round 4 (agent 5: U1.7, U1.8) not launched yet.

## State

| # | Agent | Package | State | Branch | Report |
|---|---|---|---|---|---|
| 1 | `measure` | baseline, the reach check, U1.1, then U1.4 (flat tail) | merged (U1.4 reverted) | `u1/measure` | [measure.md](u1_reports/measure.md) |
| 2 | `sources` | the four numbers that need a source | merged | `u1/sources` | [sources.md](u1_reports/sources.md) |
| 3 | `porpoising` | U1.5's diagnosis | merged | `u1/porpoising` | [porpoising.md](u1_reports/porpoising.md) |
| 4 | `physics` | all merged: U1.5 fix, grid, U1.4 back, onset (off), U1.2, U1.3, rake-first on. **Stop rule on targets 3 to 5** | merged (round 3, 1cf467a) | `u1/physics` | [physics.md](u1_reports/physics.md), [physics_onset.md](u1_reports/physics_onset.md), [physics_harness.md](u1_reports/physics_harness.md) |
| 5 | `finish` | U1.6: **merged** (3718ef4). U1.7 and U1.8 in a relaunch after U1.2 and U1.3 | merged (U1.6); waits for round 3 | `u1/finish` | [finish_u16.md](u1_reports/finish_u16.md) |

The possible states are: not started → running → reported → merged.

| Stop | State |
|---|---|
| Stop 1, the lead: agents 1 to 3 in, the go/no-go for agent 4 | **passed** on 19 October 2026 with four team decisions (in the brief, "Decisions at Stop 1") |
| Stop 2, Michiel reviews agent 4's physics | **passed** on 19 October 2026 with four decisions (in the brief, "Decisions at Stop 2") |
| Stop 3, Max's play-test | not reached |

## Next action

**Stopped for the team after round 3.** Agent 4's U1.2 and U1.3 are merged. The bounce is gone everywhere, the foot trim is fixed (the feet now pass 32 N·m bow-up instead of 117 N·m bow-down), the sailor stands in agent 2's 45° stance, the rake-first course hold is on by default, and the harness fell from 954 to 683 N with the rig at 63 % on the 18 kt beam reach. **But a stop rule fired: targets 3 to 5 conflict with statics as the pilot sails now.**
1. Hooked in, the arms only steer, so the harness line carries the whole boom force: 600 to 750 N at 18 kt with the 6.5 m² sail sheeted to the most the pilot can hold. 415 N needs two thirds of that sail force.
2. The water's push sits ahead of the sailor's weight (0.47 m from the tail) by the drive's couple: 280 N × 1.9 m / 800 N = 0.66 m. So the push centre lands at about 1.1 m, not 0.45 to 0.75 m, and the wet front at 1.65 to 1.71 m, not 0.6 to 1.0 m.

Still off target on the 18 and 24 kt beam and broad reaches: the wet front by 0.4 to 0.7 m, the push centre by 0.33 to 0.39 m, the harness by 203 N, the rig's share by 13 points. Targets 3 to 5 stay `pending` in `test_planing_wet_area.gd`.

**Michiel decides:** (a) a pilot that sheets to a normal stance instead of the most it can hold (slower; closer to Walls & Gale's sailor, whose sail was sized to the wind); or (b) keep the pilot and set the targets for this one 6.5 m² sail at 18 kt (that is, accept the harness and wet-front numbers as the physics of a fully sheeted 6.5 at 18 kt); or (c) something the lead hasn't thought of (the drive's couple is the real reason the push sits forward: a lower drive, or the weight further aft, moves it). Also still open: the onset (the buoyancy factor 0.5 stays off, the 24 kt broad reach bounces with it at 0.83°; the onset is now 11.6 kn with it off); Max's rail-down angle.

**After the decision:** if (b), launch round 4: relaunch agent 5 on `u1/finish` for U1.7 and U1.8 (with agent 4's three reports), then Stop 3. If (a) or (c), relaunch agent 4 on `u1/physics` first. The stance and the rig-lean default changed, so the full manoeuvre matrix before the pull request matters more now (the team runs it).

## Numbers

**Baseline** (agent 1, 19 October 2026, `feature/u1-planing-wet-area` at 090593e, no physics changed):
- `tools/check.sh` 188 files, 0 failed; `tools/test.sh` 335 of 335; `tools/test.sh validation` 20 of 20.
- `tools/matrix.sh --only=straight` (flat): no fall; 8.77, 11.10 and 12.01 m/s at 12, 18 and 24 kt.
- `tools/matrix.sh --only=straight --waves=1` (the default sea): no fall; 8.72, 10.90 and 12.07 m/s.
- `tools/lake_matrix.sh --only=straight`: no fall, no NaN; mean 22.1, 19.2 and 23.3 kt at 12:00, 14:30 and 17:00 (top 23.5, 20.5, 25.3 kt).
- The reach check, `tools/reach_check.sh` (means over t ≥ 25 s; positions from the tail):

| Case | Speed m/s | Front m | Wet m | Push m | Trim ° | Pitch SD ° | Harness N | Rig % | Mast foot N | Friction N | Drive N | Area m² |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 12 kt 60° | 7.66 | 1.50 | 1.50 | 1.12 | 2.63 | **0.81** | 770 | 74 | 513 | 77 | 142 | 0.86 |
| 12 kt 100° | 10.25 | 1.57 | 1.57 | 1.25 | 1.44 | **1.21** | 820 | 79 | 578 | 135 | 211 | 0.89 |
| 12 kt 135° | 5.70 | 1.46 | 1.46 | 1.02 | 4.66 | 0.04 | 171 | 16 | 192 | 45 | 100 | 0.84 |
| 18 kt 60° | 8.81 | 1.37 | 1.37 | 1.02 | 2.37 | **0.79** | 731 | 67 | 464 | 92 | 189 | 0.77 |
| 18 kt 100° | 12.30 | 1.87 | 1.87 | 1.58 | 0.93 | 0.00 | 947 | 91 | 679 | 224 | 318 | 1.07 |
| 18 kt 135° | 12.34 | 1.66 | 1.64 | 1.27 | 0.76 | **0.82** | 630 | 64 | 514 | 202 | 249 | 0.95 |
| 24 kt 60° | 9.26 | 1.33 | 1.33 | 0.97 | 2.34 | **0.70** | 722 | 64 | 438 | 97 | 220 | 0.75 |
| 24 kt 100° | 13.83 | 1.82 | 1.82 | 1.56 | 0.70 | 0.00 | 943 | 88 | 660 | 272 | 387 | 1.05 |
| 24 kt 135° | 15.70 | 1.81 | 1.81 | 1.62 | 0.37 | 0.06 | 973 | 95 | 726 | 342 | 433 | 1.04 |

  Five cases already miss target 2 (bold): the close reaches bounce at 1.1 to 1.2 Hz (pitch 2 to 4.4°, the wet front 1.0 to 1.8 m), the 12 kt beam reach at 1.55 Hz (pitch 0 to 3.4°), the 18 kt broad reach swings without a clear period. The 12 kt broad reach is barely planing (harness 171 N).
- The validation check (`test_planing_wet_area.gd`, last 10 s): the same numbers within 0.03 m/s and 0.03 m (the 18 kt beam reach identical); targets 2, 3 and 4 `pending`.
- The grid check (13 rows instead of 7): the front moves −1, **−34** and +3 cm at 18 kt (60°, 100°, 135°), and 0, **+7** and +4 cm at 24 kt. On 13 rows the 18 kt beam reach bounces (pitch SD 0.72°, front 1.53 m on average), so its steady 1.87 m on 7 rows is partly the grid. Over 5 cm: for the team (a finer grid is out of U1's scope).

**The merged branch** (lead, 19 October 2026, e2f1563): `tools/check.sh` 190 files, 0 failed; `tools/test.sh` all passed; `tools/test.sh validation` no failures, 3 pending (the new check's targets). Green.

**Round 3, U1.2 and U1.3 (agent 4, merged 1cf467a), agent 4's own numbers:** unit 343 of 343; check 0 failed; validation fails only the onset (11.6 kn). 18 kt beam reach: harness 683 N, rig 63 %, line 0.77 m, wet front 1.71 m, push 1.13 m, trim 1.64°. All 9 steady (worst 0.26° at 24 kt 135°). Speeds: the beam and broad reaches 4 to 11 % faster than Latest, the close reaches 3 % slower (the 45° stance). Full table in `u1_reports/physics_harness.md`.

**Latest, verified by the lead on the merged branch (1cf467a):** `tools/check.sh` 192 files, 0 failed; `tools/test.sh` 343 of 343; `tools/test.sh validation` 26 pass, 1 fail (the onset, 11.6 kn), 2 pending (targets 3 and 4). The reach check (means over t ≥ 25 s, positions from the tail):

| Case | Speed m/s | Front m | Push m | Trim ° | Pitch SD ° | Harness N | Rig % | Mast foot N | Friction N | Area m² |
|---|---|---|---|---|---|---|---|---|---|---|
| 12 kt 60° | 7.58 | 1.87 | 1.43 | 2.11 | 0.00 | 708 | 81 | 482 | 90 | 1.05 |
| 12 kt 100° | 10.30 | 1.82 | 1.32 | 1.77 | 0.00 | 705 | 79 | 462 | 154 | 1.02 |
| 12 kt 135° | 6.41 | 1.95 | 0.86 | 2.54 | 0.05 | 185 | 16 | 193 | 68 | 1.09 |
| 18 kt 60° | 8.70 | 1.76 | 1.25 | 2.10 | 0.01 | 666 | 71 | 414 | 111 | 1.00 |
| 18 kt 100° | 12.74 | 1.71 | 1.13 | 1.64 | 0.00 | 683 | 63 | 352 | 216 | 0.96 |
| 18 kt 135° | 12.55 | 1.39 | 1.10 | 1.53 | 0.09 | 500 | 55 | 401 | 171 | 0.76 |
| 24 kt 60° | 9.06 | 1.71 | 1.19 | 2.17 | 0.00 | 647 | 66 | 383 | 117 | 0.97 |
| 24 kt 100° | 14.31 | 1.65 | 1.08 | 1.67 | 0.01 | 695 | 57 | 320 | 258 | 0.93 |
| 24 kt 135° | 16.04 | 1.66 | 1.14 | 1.45 | 0.26 | 706 | 60 | 386 | 318 | 0.92 |

  Against the baseline: steady 9 of 9 (was 4 of 9); the 18 kt beam reach's harness 947 → 683 N, rig 91 → 63 %, mast foot 679 → 352 N, friction 224 → 216 N, speed 12.30 → 12.74 m/s; the wet front 1.87 → 1.71 m. The close reaches are slower (8.81 → 8.70 and 9.26 → 9.06 m/s at 18 and 24 kt) with a longer wet part.

**Earlier, U1.6 (agent 5, merged 3718ef4), agent 5's own numbers:** unit 341 of 341; validation fails only on the onset (now 12.7 kn); the reach check stays steady in 9 of 9 (pitch SD at most 0.07°); speeds within 3 % of Latest except the 18 kt broad reach, which is faster (11.23 → 11.88 m/s); the close reaches 2 to 3 % slower (the board now heels 4.5° there). 18 kt beam reach: harness 954 N, rig 91 %, line 1.44 m; with rake-first on: 854 N, 93 %, 1.05 m, rig lean 23°. The board rails out at 24° of heel (holds 21°). **Verified by the lead on the merged branch (3718ef4):** `tools/check.sh` 192 files, 0 failed; `tools/test.sh` 342 of 342; `tools/test.sh validation` 26 pass, 1 fail (the onset, 12.7 kn), 2 pending (targets 3 and 4). The reach check (means over t ≥ 25 s, positions from the tail):

| Case | Speed m/s | Front m | Push m | Trim ° | Pitch SD ° | Harness N | Rig % | Mast foot N | Friction N | Area m² |
|---|---|---|---|---|---|---|---|---|---|---|
| 12 kt 60° | 7.73 | 1.58 | 1.11 | 3.05 | 0.00 | 762 | 70 | 493 | 81 | 0.90 |
| 12 kt 100° | 10.29 | 1.91 | 1.47 | 1.82 | 0.01 | 917 | 87 | 645 | 160 | 1.07 |
| 12 kt 135° | 5.69 | 1.37 | 0.94 | 5.09 | 0.01 | 165 | 15 | 183 | 41 | 0.77 |
| 18 kt 60° | 8.76 | 1.49 | 1.02 | 2.95 | 0.00 | 715 | 62 | 434 | 98 | 0.84 |
| 18 kt 100° | 12.26 | 2.00 | 1.68 | 1.35 | 0.01 | 954 | 91 | 684 | 224 | 1.10 |
| 18 kt 135° | 11.88 | 1.75 | 1.28 | 1.49 | 0.01 | 597 | 60 | 489 | 193 | 0.98 |
| 24 kt 60° | 9.16 | 1.43 | 0.98 | 3.01 | 0.01 | 704 | 60 | 410 | 102 | 0.81 |
| 24 kt 100° | 13.74 | 1.94 | 1.61 | 1.32 | 0.01 | 925 | 84 | 630 | 272 | 1.07 |
| 24 kt 135° | 15.46 | 1.95 | 1.65 | 1.21 | 0.07 | 921 | 87 | 668 | 335 | 1.07 |

**Onset work (agent 4, merged, off by default):** the reach check and all checks are unchanged from the table below (`check.sh` 0 failed, `test.sh` all passed with one new test, validation 21 pass, onset fails, 2 pending). The onset without the correction is 16.0, 13.3, 11.0, 11.0 kn at 12, 15, 18, 24 kt (it jumps with the wind because the planing share hovers near 0.5); with factor 0.5 it is 8.8, 9.9, 9.4, 9.5 kn, and the 12 kt broad reach drops to 3.75 m/s at 9.3° trim, the 24 kt broad reach bounces at 0.64°. Full table in `u1_reports/physics_onset.md`.

**Earlier: `feature/u1-planing-wet-area` after agent 4's first merge** (verified by the lead on `u1/physics` at 18e2a82) (verified by the lead, 19 October 2026, not merged): `tools/check.sh` 190 files, 0 failed; `tools/test.sh` 337 of 337; `tools/test.sh validation` 21 pass, **1 fail** (`test_planing_onset_and_fully_planing`: onset 6.85 m/s = 13.3 kn, band 8 to 10 kn), 2 pending (targets 3 and 4). The reach check (means over t ≥ 25 s, positions from the tail):

| Case | Speed m/s | Front m | Push m | Trim ° | Pitch SD ° | Harness N | Rig % | Mast foot N | Friction N | Area m² |
|---|---|---|---|---|---|---|---|---|---|---|
| 12 kt 60° | 7.80 | 1.45 | 1.09 | 3.14 | 0.01 | 753 | 70 | 486 | 77 | 0.82 |
| 12 kt 100° | 10.28 | 1.91 | 1.47 | 1.82 | 0.01 | 917 | 87 | 645 | 160 | 1.07 |
| 12 kt 135° | 5.73 | 1.39 | 0.94 | 4.95 | 0.02 | 166 | 15 | 183 | 42 | 0.78 |
| 18 kt 60° | 9.00 | 1.26 | 0.98 | 3.06 | 0.00 | 702 | 62 | 426 | 86 | 0.69 |
| 18 kt 100° | 12.28 | 2.00 | 1.69 | 1.34 | 0.02 | 957 | 91 | 685 | 225 | 1.10 |
| 18 kt 135° | 11.23 | 2.24 | 1.08 | 0.39 | 0.01 | 537 | 52 | 441 | 211 | 1.24 |
| 24 kt 60° | 9.37 | 1.22 | 0.95 | 3.06 | 0.06 | 693 | 60 | 402 | 88 | 0.66 |
| 24 kt 100° | 13.79 | 1.93 | 1.60 | 1.25 | 0.00 | 926 | 85 | 633 | 272 | 1.07 |
| 24 kt 135° | 15.58 | 1.93 | 1.63 | 0.86 | 0.29 | 933 | 89 | 680 | 337 | 1.06 |

  Steady: 9 of 9 (target 2 met). Not met: the wet front (target 0.6 to 1.0 m), the trim (1.5° up) and the harness (350 to 480 N); the 18 kt broad reach is 1.1 m/s slower than the baseline with a longer wet part (2.24 m), which agent 1 tied to the flat tail and the feet (U1.3).

**Earlier: U1.4, the flat tail, first attempt** (agent 1; `tail_rocker_m` 0, commit 54282ee, **reverted** in d55bd6a until the lead decides; see `u1_reports/measure.md`):
- `tools/test.sh validation` 20 of 20, plus the new check (1 pass, 3 pending). `tools/test.sh` 333 of 335: two tests in `test_buoyancy.gd` (outside agent 1's files) fail, which is why it is reverted.
- Straight runs, no fall, no NaN: flat 8.87, 11.07 and 11.99 m/s; the sea 8.65, 10.76 and 11.84 m/s (calmer: 4 and 11 sheet reversals instead of 9 and 17); the lake 22.0, 19.0 and 23.1 kt.
- The reach check:

| Case | Speed m/s | Front m | Wet m | Push m | Trim ° | Pitch SD ° | Harness N | Rig % | Mast foot N | Friction N |
|---|---|---|---|---|---|---|---|---|---|---|
| 12 kt 60° | 7.72 | 1.40 | 1.40 | 1.05 | 3.25 | **0.40** | 744 | 69 | 480 | 74 |
| 12 kt 100° | 10.27 | 1.76 | 1.76 | 1.35 | 1.78 | 0.00 | 869 | 83 | 614 | 154 |
| 12 kt 135° | 5.85 | 1.49 | 1.49 | 0.97 | 4.45 | 0.04 | 173 | 16 | 191 | 48 |
| 18 kt 60° | 8.89 | 1.32 | 1.32 | 1.00 | 2.87 | **0.30** | 715 | 64 | 442 | 90 |
| 18 kt 100° | 12.30 | 1.88 | 1.88 | 1.59 | 1.21 | 0.01 | 949 | 91 | 681 | 224 |
| 18 kt 135° | **11.41** | **2.12** | 2.12 | 1.15 | **−0.06** | 0.01 | 557 | 56 | 466 | 210 |
| 24 kt 60° | 9.28 | 1.33 | 1.33 | 0.98 | 2.74 | **0.36** | 717 | 63 | 427 | 99 |
| 24 kt 100° | 13.83 | 1.83 | 1.83 | 1.57 | 0.99 | 0.00 | 942 | 88 | 659 | 272 |
| 24 kt 135° | 15.71 | 1.81 | 1.81 | 1.63 | 0.64 | 0.12 | 974 | 95 | 726 | 343 |

  The trim rises by about 0.3°, the bounce gets smaller, the wet front stays where it was on the beam reaches, and the 18 kt broad reach settles bow-down (pitch −1.05°).
- `simulate.sh --board.tail_rocker_m=0` (agent 3's way) leaves the buoyancy grid's tail row 1 cm up, but gives nearly the same: within 4 cm and 0.2° on the 18 kt broad reach, and identical within 0.02 on the 18 kt beam reach with `lean_height_drop_m=0.15` (front 1.12 m, trim 1.36°, still bouncing at 1.78 Hz).

## Open items

- U1.4, the flat tail, is reverted (d55bd6a). Bringing it back needs `Game/tests/unit/test_buoyancy.gd` updated (two tests) and an explanation for the 18 kt broad reach going bow-down.
- The buoyancy grid: 13 rows move the 18 kt beam reach's wet front by 34 cm. Out of U1's scope unless the team decides otherwise.
- `board.glb` is not rebuilt after the flat tail: Blender isn't installed on Max's PC. Rebuild it with `tools/blender.sh tools/blender/build_rig_models.py` on a PC that has Blender 4.5.

## Notes

Decisions and surprises along the way, newest first.

- 19 October 2026 (agent 4, round 3): the feet's bow-down came from the trim press itself, which moved only the legs' push point aft of a body that stayed put; now the body moves with the press and the hang-back is measured from the feet. `running_trim_deg` 2 → 1.5 (Gourlay). Full lean is agent 2's 45° stance (`lean_max_m` 0.88, `lean_height_drop_m` 0.28), not a full hike. Rake-first on by default. Buoyancy factor 0.5 still off (24 kt broad reach bounces). **Stop rule:** hooked in, the line carries the whole boom force (600 to 750 N at 18 kt); the push sits 0.66 m ahead of the weight by the drive's couple; targets 3 to 5 are out of reach with this pilot and sail. The lead removed two finished worktrees that held `u1/physics` and pointed the branch at round 3.

- 19 October 2026 (agent 5, U1.6): the rig stood up only 8° because the pilot's heading hold steers through `Helm.steer`, which tilts the rig to leeward as far as it rakes back; a beam reach needs a steady heading-up helm since the sail's centre of effort sits 0.37 m ahead of the fin. A rake-first hold (`Autopilot.trim_with_rake_first`) leans the rig 23° and shortens the harness line from 1.44 to 1.05 m, but is **off**: the rake hits its 25° stop and the grip aft worsens the bow-down of U1.3. Fin loading: `fin_load_bank_deg` 4.5°, an estimate. Agent 4's earlier "rig at 25°" run was in fact sailing at 130°.

- 19 October 2026 (agent 4, onset): the grid gives full Archimedes buoyancy to a planing bottom; the sources give about half (the water leaves the transom and rails). Built as `planing_buoyancy_factor`, default 1.0 (no change), phased in over Froude 0.4 to 1.0. At 0.5 the onset is right (9.9 kn) but the broad reaches plough and four checks fail, likely the sailor keeping the weight aft. Michiel's explanation of the steadiness above Savitsky's limit is in the report and in spec 17.2. Agent 4 moved `u1/physics` out of its old worktree; that old worktree (`.claude/worktrees/agent-a654…`) looks dirty and can be removed.

- 19 October 2026 (Michiel, via Max): Stop 2 decisions. (1) The onset at 13.3 kn is too fast, real is about 10 kn: find what the model is missing, don't move the band. (2) Fix the rig's lean and the helm first, then the harness. (3) 1° vee is fine for now. (4) Riding above the flat-bottom limit accepted, with a plain-language explanation to follow.

- 19 October 2026 (agent 4): the bounce is fixed with no new constant. A strip of bottom that is sinking meets more water across its oblique spray root than a rising one (Zarnick 1978); with a 1° tail vee (median of ten measured 2024 freeride boards) that gives the steadying the flat strips lacked. Also fixed: the gain behind the spray root was counted 1.5 times. 9 of 9 reach cases steady, also with the hips dropped 0.15 m. The grid (7 to 13 rows) moves the wet front at most 4 cm now that the bounce is gone; default kept at 7. The flat tail is back. **But:** the wet front got longer (2.0 to 2.2 m), the trim stays under 1.5°, the harness stays at 956 N, and the planing onset moved to 13.3 kn, failing the validation's 8 to 10 kn band. U1.2 stopped (stop rule: no source for an arms' share), U1.3 diagnosed only (the bow-down 116 N·m is the arms' forward pull; the legs carry 4 N).

- 19 October 2026 (Max, Michiel agrees): Stop 1 decisions. (1) A slight tail vee, documented, modelled physically. (2) The five baseline-bouncing cases must not get worse; fix if cheap. (3) Try grids of 7, 9, 11 and 13 rows. (4) The flat tail comes back with the vee. The lead read "the slight vee right?" as "bring the flat tail back too"; Max can correct that.

- 19 October 2026 (agent 1): `tools/reach_check.sh` (runner `Game/dev/run_reach.gd`) prints the 9 cases in 50 s and matches `simulate.sh`. Telemetry and the HUD show the friction area, the wet front and the push centre. `test_planing_wet_area.gd` holds targets 2 to 4 as `pending`; agent 4 sets `TARGETS_ARE_CHECKS = true`. The validation suite takes about 36 s longer now. Three findings for the team: the baseline misses target 2 in 5 of 9 cases; the grid check moves the 18 kt beam reach's wet front by 34 cm; the flat tail (U1.4) is reverted because two buoyancy unit tests fail and the 18 kt broad reach goes bow-down.

- 19 October 2026 (agent 3): the 1.8 Hz bounce is plain porpoising (Day & Haag 1952, Savitsky 1964): the board bounces once its trim rises above Savitsky's critical trim for its load, within about 0.2° of the limit at 12, 18 and 24 kt. The mast-foot load only keeps the trim just under it (0.97° against 1.25° on the 18 kt reach). Not the cause: legs, trim press, steering, grid, substeps, spray-root cap, tail kick. The pitch reflex damps it; freezing the sailor or adding lift lag makes it worse. **Stop rule fired:** targets 2 (steady) and 4 (trim 1.5 to 4°) conflict for a flat bottom.

- 19 October 2026 (agent 2): all four numbers are in PHYSICS_SPEC.md section 14 ("U1: the harness, the feet and the rail angle"). Only the harness tension is measured (Walls & Gale: 4.9 N/kg, so 368 N for the 75 kg sailor, inside the 350 to 480 N target). The rest are labelled estimates. **Item 3, the flat-water rail-down angle, was not found anywhere: the 3 to 6° in the spec is a placeholder, and Max should give his own estimate.** Hint for agent 4: a real harness line hangs the hips only 0.30 to 0.40 m from the boom; a much longer centre-of-mass-to-grip line may be part of the 945 N.
- 19 October 2026 (lead): an agent's worktree starts at `main` (561849c), not at the U1 branch head. Agents must make `u1/<name>` from `feature/u1-planing-wet-area` explicitly; agent 2 did.

- 19 October 2026 (Max): testing on reaches only (60°, 100° and 135°, at 12, 18 and 24 kt), no manoeuvres. The team runs the full manoeuvre matrix before the pull request to `main`.

## Prompts

**To start** (Max pastes this into a Claude Code session running Fable 5.1, in `C:\source\WindsurfingMMZB`):

```
You are the head developer of U1 in WindsurfingMMZB, on the branch feature/u1-planing-wet-area. Read CLAUDE.md, Documentation/U1_PROGRESS.md and the U1 execution brief in Documentation/PLAYTEST_UPGRADES.md, and follow the brief.
- You lead and delegate. The work is done by Opus 5.5 sub-agents at extra-high effort (model opus, effort xhigh, isolation worktree): at most 5 in all and 3 at a time, each launched with the brief's agent prompt.
- Testing is on reaches only (the reach check). No manoeuvres.
- My Fable usage is nearly used up, so keep your own reading and writing short. After every launch, report and merge, update and commit U1_PROGRESS.md, so another session can take over at any moment.
- Stop at the brief's stops, or when a stop rule fires, and tell me in plain language.
Start with the Next action in U1_PROGRESS.md.
```

**To take over** (if the lead stopped; any session, for example Opus 5.5 at extra-high effort):

```
Take over as the lead of U1 in WindsurfingMMZB; the previous lead stopped. Read CLAUDE.md, Documentation/U1_PROGRESS.md and the U1 execution brief in Documentation/PLAYTEST_UPGRADES.md, and follow the brief.
1. Check out feature/u1-planing-wet-area. Run git worktree list and git branch --list "u1/*", and compare them with the state table in U1_PROGRESS.md.
2. An agent whose report is committed on its branch (Documentation/u1_reports/<name>.md) is finished: merge its branch if that hasn't been done.
3. Launch any agent that was running but didn't finish again, with the brief's agent prompt. It continues on its existing branch. A relaunch doesn't count toward the 5.
4. Update and commit U1_PROGRESS.md, then go on from its Next action. Sub-agents: Opus 5.5 at extra-high effort (model opus, effort xhigh, isolation worktree), at most 3 at a time.
Keep your own reading and writing short. Stop at the brief's stops and tell me in plain language.
```
