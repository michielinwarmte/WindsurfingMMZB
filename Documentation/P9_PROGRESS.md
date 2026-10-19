# Phase 9 progress (handoff)

The live state of Phase 9, racing. The plan and its execution brief are in [RACING_PLAN.md](RACING_PLAN.md). **The lead updates and commits this file after every launch, report and merge**, so any session can take over.

- **Branch:** `feature/p9-racing` (from `feature/u2-fin` at f598a00, which carries U1 and U2). Agents work on `p9/<name>` branches, made from it in their own worktrees.
- **Last update:** 19 October 2026, late evening (Session 50): fit_to_water and course_on_water merged (385 tests, 204 files); race_core still running. The AiHands (the controller fed by values) added by the lead (121f017). T2 fits at 60 % with the 200 m rule (150 m would give 80 %: Max decides).
- **Max's instruction (19 October 2026):** "go till the 2 training courses": build 9A up to and including the two training courses, with the course placement fitting itself to the water (every mark at least 200 m from the shore). Then stop for his look.

## State

| # | Agent | Package | State | Branch | Report |
|---|---|---|---|---|---|
| 1 | `race_core` | RaceSim (the countdown, the steps, OCS, the clock and splits), RoundingCheck (the geometry), RaceResult, their tests, `tools/race.sh` with `Game/dev/run_race.gd` | launched | `p9/race_core` | |
| 2 | `course_on_water` | buoys, the boats and the lines on the water in both scenes (`--course=<name>`), T1 placed by code (`RaceCourses`), the course file's game-metres frame, the mini-map with the marks | merged (ee79036) | `p9/course_on_water` | [course_on_water.md](racing_reports/course_on_water.md) |
| 3 | `fit_to_water` | `CourseFitter`: the shore clearance field, the fit (shrink, turn, move; marks 200 m off the shore, legs 50 m), the course maker's "Fit to water" button, `tools/fit_courses.sh` writing `t2_slalom.json` | merged (560574d) | `p9/fit_to_water` | [fit_to_water.md](racing_reports/fit_to_water.md) |

| Stop | State |
|---|---|
| Stop A1, the lead: the three agents merged, tests and check green, the courses seen in screenshots | open |
| Stop A2, Max: sails among the buoys of T1 and T2; the course maker's Fit to water | open |

## Next action

The three agents run. When each reports: the lead reads the diff (the rounding geometry and the fitter's search most carefully), merges in the order `race_core`, `fit_to_water`, `course_on_water`, wires `run_race.gd` to `RaceCourses` (one line), runs `tools/test.sh` and `tools/check.sh`, takes the screenshots, and updates this file. Then Stop A2 for Max.

## Numbers

Baseline on `feature/u2-fin` (f598a00): `tools/check.sh` 196 files, 0 failed; `tools/test.sh` 360 of 360.

## Open items

- Max's answers to the lead's questions of 19 October 2026 (the countdown length, the names, whether T1 also goes on the lake, the lines on the water).
- Michiel: the two physics hooks (RACING_PLAN.md, "What racing asks of the physics"), needed from 9B.

## Prompts

**To continue** (paste into a new session): "Read Documentation/P9_PROGRESS.md and continue Phase 9 from its Next action, as the lead described in RACING_PLAN.md's execution brief. Max's instruction stands: build up to the two training courses, then stop for his look."
