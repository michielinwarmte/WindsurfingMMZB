# Documentation

The map of every document, so a reader (or an AI session) knows which file is live, which is reference and which is history. Nothing is deleted when work finishes: the plan or progress file moves to [archive/](archive/) with a banner, and what is still open from it goes to [ROADMAP.md](../ROADMAP.md).

## Start here

| File | What it is |
|---|---|
| [../README.md](../README.md) | The front page: features, controls, download, known gaps |
| [../ROADMAP.md](../ROADMAP.md) | **Live.** What comes next, what waits for whom, how an update and a release are made, the prompts to continue |
| [../CHANGELOG.md](../CHANGELOG.md) | What each version contains |
| [../CLAUDE.md](../CLAUDE.md) | The rules, commands and conventions every AI session follows |
| [PROGRESS_LOG.md](PROGRESS_LOG.md) | **Live.** One entry per session, newest first (Sessions 28 onwards; the Unity sessions are in Legacy/) |

## Live plans

| File | What it is |
|---|---|
| [AI_FLEET_PLAN.md](AI_FLEET_PLAN.md) | The AI fleet: smarter skippers with character, 20 to 40 boards, trained on the full physics. Parts F1 to F6; F1 to F5 built, F6 and the personas on the trained head open. The team's decisions of 20 October 2026 |
| [MAP_SILVAPLANA_PLAN.md](MAP_SILVAPLANA_PLAN.md) | The map track: Lake Silvaplana from Swiss open data (phases M0 to M4) and the wind analyser (W0 to W5). M4, W4b and the later projects open |
| [PHYSICS_REQUESTS_FROM_MAP.md](PHYSICS_REQUESTS_FROM_MAP.md) | What the map needs from the physics (thin air, fresh water, running aground, moving gusts, wind waves), with measured numbers; some done, some open |

## Reference

| File | What it is |
|---|---|
| [PHYSICS_SPEC.md](PHYSICS_SPEC.md) | **The physics as built.** Every model, formula, number and its source; the conventions; the tuning log. Updated with every physics change |
| [POLAR_15KT.md](POLAR_15KT.md) | The board's speeds by course at 15 kt, from the validation suite |
| [MALOJA_WIND_RESEARCH.md](MALOJA_WIND_RESEARCH.md) | How the Maloja wind behaves over Lake Silvaplana: the research behind the map's wind |
| [SILVAPLANA_SPOT_NOTES.md](SILVAPLANA_SPOT_NOTES.md) | Max's notes on the spot and his answers to the wind research's questions |
| [iqfoil_2026_u23_worlds_notice_of_race.pdf](iqfoil_2026_u23_worlds_notice_of_race.pdf) | The iQFOiL Notice of Race of the 2026 U23 Worlds in Puck; Addendum A has the ten course diagrams the course maker's templates follow |
| [images/](images/) | The wind research's figures (`maloja/`) and the README's screenshots (`readme/`) |

## Reports: what the agents measured and built

One report per package, written by the agent that built it and read by the lead before the merge. They hold the numbers behind the decisions.

| Folder | Work |
|---|---|
| [racing_reports/](racing_reports/) | Phase 9 and the AI fleet: the race core, the courses on the water, the course fitter, the skipper, the learning harness, the sea query, the physics without the engine's locks (`no_wait.md`, for Michiel), the fleet frame, the living skipper, the trainer, real life (wind shadows and the rules), the personas, the generations' race |
| [u1_reports/](u1_reports/) | U1, planing on a smaller wet area: the sources, the measurements, the physics, the porpoising, the finish |
| [u2_reports/](u2_reports/) | U2, the fin bends: the sources, the measurements, the fin's physics, the heeled hull, the technique, the look, riding the fin, the hull's lift |

## Archive: finished work, kept as it was

| File | What it was |
|---|---|
| [archive/REBUILD_PLAN.md](archive/REBUILD_PLAN.md) | The step-by-step plan of the rebuild in Godot, phases 0 to 9, with its decisions (D1 to D4), the known legacy pitfalls and every ticked task. All phases are in 0.1.0 |
| [archive/PLAYTEST_UPGRADES.md](archive/PLAYTEST_UPGRADES.md) | The researched play-test upgrades U1 (the wet area) and U2 (the fin), each with its execution brief for a lead and its agents, and the team's decisions |
| [archive/U1_PROGRESS.md](archive/U1_PROGRESS.md), [archive/U2_PROGRESS.md](archive/U2_PROGRESS.md) | The handoff files of U1 and U2: the agents, the stops, the numbers, the open items and the take-over prompts. Michiel's review is still open (see the roadmap) |
| [archive/RACING_PLAN.md](archive/RACING_PLAN.md) | Phase 9's plan: parts 9A to 9E, the two courses, how a race works, the skippers, the compute, the execution brief |
| [archive/P9_PROGRESS.md](archive/P9_PROGRESS.md) | Phase 9's handoff file: every package, the Stops for Max, the night runs, the thread bench, the fleet measurements, the token ledger |

## How the documents are written

For a team that is not made of experienced programmers: plain language, jargon explained, numbers with their source, and a clear line between what was measured and what nobody has verified yet (how it feels to sail, how it sounds). A plan carries a status table at the top; a progress file is updated and committed by the lead after every launch, report and merge, so any session can take over.
