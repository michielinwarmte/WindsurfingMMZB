# U2 progress (handoff)

The live state of U2, "the fin bends, and its size". The plan and its execution brief are in [PLAYTEST_UPGRADES.md](PLAYTEST_UPGRADES.md). **The lead updates and commits this file after every launch, report and merge.** A lead who takes over starts here; U1's take-over prompt in [U1_PROGRESS.md](U1_PROGRESS.md) applies with U2 in place of U1.

- **Branch:** `feature/u2-fin` (from `feature/u1-planing-wet-area` at c1eee63). Agents work on `u2/<name>` branches, made from it in their own worktrees.
- **Last update:** 19 October 2026. Agents 1 and 2 launched (Opus 5.5, xhigh, own worktrees).

## State

| # | Agent | Package | State | Branch | Report |
|---|---|---|---|---|---|
| 1 | `fin_sources` | the stiffness, the catalogue fins, the literature | running | `u2/fin_sources` | |
| 2 | `fin_measure` | the fin's baseline, the overrides, the telemetry, the what-ifs, the pending check | running | `u2/fin_measure` | |
| 3 | `fin_physics` | the bending fin, by the lead's design | waits for Stop 1 | `u2/fin_physics` | |
| 4 | `fin_look` | the bending mesh, the HUD, the screenshots, the checklist | waits for Stop 2 | `u2/fin_look` | |

| Stop | State |
|---|---|
| Stop 1, the lead: agents 1 and 2 in, the stiffness sourced | not reached |
| Stop 2, the lead reviews agent 3's diff, then Michiel | not reached |
| Stop 3, Max's play-test | not reached |

## Next action

Agents 1 and 2 are running. For each that reports: read `Documentation/u2_reports/<name>.md` on `u2/<name>`, merge into `feature/u2-fin`, verify, set its state here, commit. When both are in: Stop 1 (the stiffness sourced, nothing regressed); the lead fills the flex-test numbers into the design and launches agent 3 with the two reports. An agent that was running but has no committed report is relaunched with the brief's prompt.

## Numbers

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

- 19 October 2026 (the lead): the fin's upward push has two parts, the board's heel (in the model, 41 N today) and the fin's bend (not in the model). A fin bent toward its force tilts that force upward on both tacks. The bend is a cantilever with the stiffness falling as the chord to the fourth power, so the tip does the bending; one flex test sets the scale. Details in the brief.
