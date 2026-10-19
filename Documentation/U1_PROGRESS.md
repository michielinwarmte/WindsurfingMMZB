# U1 progress (handoff)

The live state of U1, "planing on a smaller wet area". The plan and its execution brief are in [PLAYTEST_UPGRADES.md](PLAYTEST_UPGRADES.md). **The lead updates and commits this file after every launch, report and merge.** A lead who takes over starts here.

- **Branch:** `feature/u1-planing-wet-area` (from `main` at 561849c). Agents work on `u1/<name>` branches, made from it in their own worktrees.
- **Last update:** 19 October 2026. Agent 4 reported on `u1/physics` (18e2a82), held unmerged; **Stop 2: waiting for Michiel.**

## State

| # | Agent | Package | State | Branch | Report |
|---|---|---|---|---|---|
| 1 | `measure` | baseline, the reach check, U1.1, then U1.4 (flat tail) | merged (U1.4 reverted) | `u1/measure` | [measure.md](u1_reports/measure.md) |
| 2 | `sources` | the four numbers that need a source | merged | `u1/sources` | [sources.md](u1_reports/sources.md) |
| 3 | `porpoising` | U1.5's diagnosis | merged | `u1/porpoising` | [porpoising.md](u1_reports/porpoising.md) |
| 4 | `physics` | U1.5's fix with a slight tail vee, the grid trial, U1.4 back, U1.2, U1.3 | reported, **not merged** (one validation check fails: the planing onset) | `u1/physics` | `git show u1/physics:Documentation/u1_reports/physics.md` |
| 5 | `finish` | U1.6, U1.7, U1.8's screenshots | waits for Stop 2 | `u1/finish` | |

The possible states are: not started → running → reported → merged.

| Stop | State |
|---|---|
| Stop 1, the lead: agents 1 to 3 in, the go/no-go for agent 4 | **passed** on 19 October 2026 with four team decisions (in the brief, "Decisions at Stop 1") |
| Stop 2, Michiel reviews agent 4's physics | **reached** on 19 October 2026; waits for Michiel (the questions are in Next action) |
| Stop 3, Max's play-test | not reached |

## Next action

**Stop 2: Michiel reviews agent 4's physics on `u1/physics`** (18e2a82, four commits on top of e51a4b5). The branch is held unmerged because its validation is not green: the planing-onset check fails (onset 13.3 kn against the 8 to 10 kn band), and a stop rule fired on U1.2. To review: `git diff e51a4b5 u1/physics` (hull_model.gd, board_config.gd, board_default.tres, the tests), PHYSICS_SPEC.md sections 5, 7.5, 14, 16 and 17.2, and the report. Michiel decides:
1. **The planing onset.** It moved from 9.8 kn (which rode a 5.9° bouncing bow-up overshoot) to 13.3 kn. Move the band in the validation check (and write it in the tuning log), or look for missing hump lift first?
2. **U1.2's route.** The harness stays at 956 N because the line runs 1.45 m from the hiked body to the grip (real: 0.30 to 0.40 m): the pilot's weather helm tilts the rig back to 8°. Options: fix the rig's lean and the helm first (that is U1.6, agent 5's package) and then U1.2; or give the arms a share of the boom force (no source). 415 N needs the arms to take a third.
3. **The vee: 1° (sourced, median of ten 2024 freeride boards) or 2°.** 2° also steadies the 24 kt broad reach (0.46 to 0.50° now, just above target 2's 0.3°) but slows the 12 kt broad reach by 10 %.
4. **OK with the board riding above Savitsky's flat-bottom limit?** The vee raised the limit, which is the physical reason it is steady now.

After Michiel's OK: merge `u1/physics` into `feature/u1-planing-wet-area`, apply his decision on the onset check so validation is green, run `tools/check.sh`, `tools/test.sh`, `tools/test.sh validation` and `tools/reach_check.sh`, update Numbers, then launch agent 5 (`finish`: U1.6, U1.7, U1.8) with agent 4's report and Michiel's decisions. U1.2 and U1.3 are still open: agent 5 or a relaunch of agent 4 after U1.6, as the team decides. Note that the wet front is still long (1.9 to 2.2 m against the 0.6 to 1.0 m target): U1's main goal is not reached yet; the bounce is fixed.

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

- U1.4, the flat tail, is reverted (d55bd6a). Bringing it back needs `Game/tests/unit/test_buoyancy.gd` updated (two tests) and an explanation for the 18 kt broad reach going bow-down.
- The buoyancy grid: 13 rows move the 18 kt beam reach's wet front by 34 cm. Out of U1's scope unless the team decides otherwise.
- `board.glb` is not rebuilt after the flat tail: Blender isn't installed on Max's PC. Rebuild it with `tools/blender.sh tools/blender/build_rig_models.py` on a PC that has Blender 4.5.

## Notes

Decisions and surprises along the way, newest first.

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
