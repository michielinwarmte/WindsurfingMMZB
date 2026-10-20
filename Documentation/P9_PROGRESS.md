# Phase 9 progress (handoff)

The live state of Phase 9, racing. The plan and its execution brief are in [RACING_PLAN.md](RACING_PLAN.md). **The lead updates and commits this file after every launch, report and merge**, so any session can take over.

- **Branch:** `feature/p9-racing` (from `feature/u2-fin` at f598a00, which carries U1 and U2). Agents work on `p9/<name>` branches, made from it in their own worktrees.
- **Last update:** 20 October 2026, 02:45 (Session 50, the night): all of 9A's three agents merged, the learning harness merged (two rounds, c279c67; 442 tests, 219 files). **A training run is in progress**: `tools/race_evolve.sh --run=night --hours=5 --actions=twa --population=32 --episodes=2 --episode_s=300 --start_behind_m=25 --prestart_s=5 --stall_s=30 --sigma=0.03 --sigma_min=0.01 --output_scale=0.5 --threads=16`, started 02:42, log in `.sim_output/evolve/night.log` and `night.csv`, brains in `Game/race/brains/night_*.json`. The `skipper` agent (9B) still runs on `p9/skipper`.
- **Max's instruction (19 October 2026):** "go till the 2 training courses": build 9A up to and including the two training courses, with the course placement fitting itself to the water (every mark at least 200 m from the shore). Then stop for his look.

## State

| # | Agent | Package | State | Branch | Report |
|---|---|---|---|---|---|
| 1 | `race_core` | RaceSim (the countdown, the steps, OCS, the clock and splits), RoundingCheck (the geometry), RaceResult, their tests, `tools/race.sh` with `Game/dev/run_race.gd` | merged (37d880c) | `p9/race_core` | [race_core.md](racing_reports/race_core.md) |
| 2 | `course_on_water` | buoys, the boats and the lines on the water in both scenes (`--course=<name>`), T1 placed by code (`RaceCourses`), the course file's game-metres frame, the mini-map with the marks | merged (ee79036) | `p9/course_on_water` | [course_on_water.md](racing_reports/course_on_water.md) |
| 3 | `fit_to_water` | `CourseFitter`: the shore clearance field, the fit (shrink, turn, move; marks 200 m off the shore, legs 50 m), the course maker's "Fit to water" button, `tools/fit_courses.sh` writing `t2_slalom.json` | merged (560574d) | `p9/fit_to_water` | [fit_to_water.md](racing_reports/fit_to_water.md) |

| Stop | State |
|---|---|
| Stop A1, the lead: the three agents merged, tests and check green, the courses seen in screenshots | **passed** late on 19 October 2026: 416 tests, 211 files, `tools/race.sh --course=t1_loop` and `--course=t2_slalom` run; the buoy and the start line checked in screenshots |
| Stop A2, Max: sails among the buoys of T1 and T2; the course maker's Fit to water | open |

## Next action

Max went to bed on 19 October 2026 with "experiment with the AI if you like, use the laptop's CPU, be careful with my tokens, surprise me tomorrow". The lead launches two agents: `skipper` (9B, the scripted skipper and its four characters, headless on T1 and T2) and `learn` (9C-lite: RaceEnv, the observation and the reward, NeuralNet and the brain file, LearnedSkipper, and an in-Godot evolution trainer on all cores, PPO over Python postponed because nothing may be installed at night). When both are merged the lead runs the trainer overnight on T1 and writes the morning report here and in the progress log. Stop A2 (Max sails among the buoys) is open.

## Numbers

**The learning harness (agent `learn`, [learn.md](racing_reports/learn.md)):** GDScript threads slow each other down in Godot 4.7.2 (14 threads run 3 times slower than 1), so the trainer runs one Godot process per core: 521 ticks/s with 1 process, 3928 with 14, 4388 with 20. The hand-written wind-angle policy (the ceiling) starts at 28 s and rounds mark 1 at 204 s of race time from 25 m behind the line. Fitness to read the log by: nothing about -30, starts in one of two races about -5, in both +20 or more, rounds mark 1 in both about +75.

Baseline on `feature/u2-fin` (f598a00): `tools/check.sh` 196 files, 0 failed; `tools/test.sh` 360 of 360.

## Open items

- Max's answers to the lead's questions of 19 October 2026 (the countdown length, the names, whether T1 also goes on the lake, the lines on the water).
- Michiel: the two physics hooks (RACING_PLAN.md, "What racing asks of the physics"), needed from 9B.

## Prompts

**To continue** (paste into a new session): "Read Documentation/P9_PROGRESS.md and continue Phase 9 from its Next action, as the lead described in RACING_PLAN.md's execution brief. Max's instruction stands: build up to the two training courses, then stop for his look."
