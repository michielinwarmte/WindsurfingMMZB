# U1 progress (handoff)

The live state of U1, "planing on a smaller wet area". The plan and its execution brief are in [PLAYTEST_UPGRADES.md](PLAYTEST_UPGRADES.md). **The lead updates and commits this file after every launch, report and merge.** A lead who takes over starts here.

- **Branch:** `feature/u1-planing-wet-area` (from `main` at 561849c). Agents work on `u1/<name>` branches, made from it in their own worktrees.
- **Last update:** 19 October 2026, the lead launched agents 1, 2 and 3 (Opus 5.5, xhigh, own worktrees). Nothing merged yet.

## State

| # | Agent | Package | State | Branch | Report |
|---|---|---|---|---|---|
| 1 | `measure` | baseline, the reach check, U1.1, then U1.4 (flat tail) | running | `u1/measure` | |
| 2 | `sources` | the four numbers that need a source | running | `u1/sources` | |
| 3 | `porpoising` | U1.5's diagnosis | running | `u1/porpoising` | |
| 4 | `physics` | U1.5's fix, U1.2, U1.3 | waits for Stop 1 | `u1/physics` | |
| 5 | `finish` | U1.6, U1.7, U1.8's screenshots | waits for Stop 2 | `u1/finish` | |

The possible states are: not started → running → reported → merged.

| Stop | State |
|---|---|
| Stop 1, the lead: agents 1 to 3 in, the go/no-go for agent 4 | not reached |
| Stop 2, Michiel reviews agent 4's physics | not reached |
| Stop 3, Max's play-test | not reached |

## Next action

Agents 1, 2 and 3 are running. For each one that reports: read `Documentation/u1_reports/<name>.md` on `u1/<name>`, merge `u1/<name>` into `feature/u1-planing-wet-area`, set its state to merged here, commit. When all three are in, handle Stop 1 (the brief's three conditions), then launch agent 4 with the reports of agents 2 and 3. An agent that was running but has no committed report is relaunched with the brief's prompt and continues on its branch.

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

**Latest: U1.4, the flat tail** (agent 1; `tail_rocker_m` 0, commit 54282ee, **reverted** in d55bd6a until the lead decides; see `u1_reports/measure.md`):
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

- `board.glb` is not rebuilt after the flat tail: Blender isn't installed on Max's PC. Rebuild it with `tools/blender.sh tools/blender/build_rig_models.py` on a PC that has Blender 4.5.

## Notes

Decisions and surprises along the way, newest first.

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
