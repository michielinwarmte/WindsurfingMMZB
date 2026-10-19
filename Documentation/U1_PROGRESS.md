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

**Baseline:** to be measured by agent 1 before any change (the reach check's 9 cases, the straight runs, the test counts). Until then, the 18 kt beam reach of 19 October: front of the wet part 1.87 m, trim 0.93°, steadiness 0.00°, harness 945 N, rig's share 91 %, friction 223 N, 23.9 kt.

**Latest:** none yet.

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
