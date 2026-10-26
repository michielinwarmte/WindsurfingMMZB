# Documentation

The map of every document, so a reader (or an AI session) knows which file is live, which is reference and which is history. **What is open, in any part of the game, is in [ROADMAP.md](../ROADMAP.md)**: the documents here hold the detail behind its items. Nothing is deleted when work finishes: the plan or progress file moves to [archive/](archive/) with a banner that says where its open items went.

```
ROADMAP.md               live: everything open, by section, with IDs (GP, PH, RA, GR, SO, UI, MA, TE, PR)
CHANGELOG.md             what each version contains
CLAUDE.md                the rules and commands for AI sessions
Documentation/
  README.md              this map
  PROGRESS_LOG.md        live: one entry per session, newest first
  PHYSICS_SPEC.md        reference: the physics as built
  MAP_SILVAPLANA_PLAN.md live plan: the map track (open: MA1 to MA8)
  gameplay_controls_v0.2.pdf   the design behind version 0.2 (section GP)
  MALOJA_WIND_RESEARCH.md, SILVAPLANA_SPOT_NOTES.md, POLAR_15KT.md, iqfoil_...pdf   reference
  images/                the figures and screenshots
  reports/               what the agents measured and built, one report per package
  archive/               finished plans and progress files, kept as they were
```

Updated 26 October 2026 (Session 55): `AI_FLEET_PLAN.md` and `PHYSICS_REQUESTS_FROM_MAP.md` moved to the archive (their open items are in the roadmap), and the three report folders (`racing_reports/`, `u1_reports/`, `u2_reports/`) became `reports/racing/`, `reports/u1/` and `reports/u2/`. Every link was rewritten and checked.

## Start here

| File | What it is |
|---|---|
| [../README.md](../README.md) | The front page: features, controls, download, known gaps |
| [../ROADMAP.md](../ROADMAP.md) | **Live.** Every open item, sorted by section of the game (gameplay and controls, physics, racing and the AI fleet, graphics, sound, HUD and menus, the map and the wind, the tech, the project), each with an ID, the files it touches, what it waits on and its version; the plan for 0.2; what waits for whom; where the details of each section are; how an update and a release are made; the prompts to continue |
| [../CHANGELOG.md](../CHANGELOG.md) | What each version contains |
| [../CLAUDE.md](../CLAUDE.md) | The rules, commands and conventions every AI session follows |
| [PROGRESS_LOG.md](PROGRESS_LOG.md) | **Live.** One entry per session, newest first (Sessions 28 onwards; the Unity sessions are in Legacy/) |

## Live plans and designs

| File | What it is |
|---|---|
| [gameplay_controls_v0.2.pdf](gameplay_controls_v0.2.pdf) | The gameplay and control design for version 0.2, from a voice session with Tarpie on 23 October 2026: the player becomes the sailor (push against risk on a reach, railing upwind, absorbing chop, the gybe's timing, the mouse and the gamepad as the sailor's body). Max's direction of 26 October 2026: one dial (push), and the rail and the back foot on the mouse as an experiment. The plan is section GP of the roadmap |
| [MAP_SILVAPLANA_PLAN.md](MAP_SILVAPLANA_PLAN.md) | Max's map track: Lake Silvaplana from Swiss open data (phases M0 to M4) and the wind analyser (W0 to W5), with the open data's sources and the map's decisions. M0 to M3 and W0 to W5 are built; the open tasks (M4, W4b, the day types) are MA1 to MA8 in the roadmap |

## Reference

| File | What it is |
|---|---|
| [PHYSICS_SPEC.md](PHYSICS_SPEC.md) | **The physics as built.** Every model, formula, number and its source; the conventions; the tuning log. Updated with every physics change (Michiel's) |
| [POLAR_15KT.md](POLAR_15KT.md) | The board's speeds by course at 15 kt, from the validation suite; regenerated 26 October 2026 for the physics of 0.1.0 |
| [MALOJA_WIND_RESEARCH.md](MALOJA_WIND_RESEARCH.md) | How the Maloja wind behaves over Lake Silvaplana: the stations, the satellite photos, the gusts, the lee; the research behind the map's wind |
| [SILVAPLANA_SPOT_NOTES.md](SILVAPLANA_SPOT_NOTES.md) | Max's notes on the spot and his answers to the wind research's questions (some questions still open) |
| [iqfoil_2026_u23_worlds_notice_of_race.pdf](iqfoil_2026_u23_worlds_notice_of_race.pdf) | The iQFOiL Notice of Race of the 2026 U23 Worlds in Puck; Addendum A has the ten course diagrams the course maker's templates follow |
| [images/](images/) | The wind research's figures (`maloja/`) and the README's screenshots (`readme/`) |

## Reports: what the agents measured and built

One report per package, written by whoever built it and read by the lead before the merge. They hold the numbers behind the decisions, and several are still the evidence for open items (Michiel's reviews PH1 and PH2, the measurements of GP0). A new package's report goes into a folder here named after its work (for example `reports/gameplay/` for GP0).

| Folder | Work |
|---|---|
| [reports/gameplay/](reports/gameplay/) | Version 0.2's gameplay: GP0's measurement of the push and the body (`gp0_measure.md`: the dial's three settings, easing for the gusts, the warning signs before a catapult, the map of the rail against the back foot) |
| [reports/racing/](reports/racing/) | Phase 9 and the AI fleet: the race core, the courses on the water, the course fitter, the skipper, the learning harness, the sea query (with its before and after reach checks, identical on purpose), the physics without the engine's locks (`no_wait.md`, for Michiel's review PH2), the fleet frame, the living skipper, the trainer, real life (wind shadows and the rules), the personas, the generations' race |
| [reports/u1/](reports/u1/) | U1, planing on a smaller wet area: the sources, the measurements, the physics, the planing onset, the porpoising, the finish (`finish_u16.md` measured where the board rails out) |
| [reports/u2/](reports/u2/) | U2, the fin bends: the sources, the measurements (`fin_measure.md` has a sweep of the rail from 0 to 24 degrees), the fin's physics, the heeled hull, the technique (`fin_technique.md`: the map of rail against trim), the look, riding the fin (`fin_ride.md`: the weight aft), the hull's lift. For Michiel's review PH1 |

## Archive: finished work, kept as it was

Each file has a banner at the top that says when it was archived and where its open items went.

| File | What it was |
|---|---|
| [archive/REBUILD_PLAN.md](archive/REBUILD_PLAN.md) | The step-by-step plan of the rebuild in Godot, phases 0 to 9, with its decisions (D1 to D4), the known legacy pitfalls and every ticked task. All phases are in 0.1.0 |
| [archive/PLAYTEST_UPGRADES.md](archive/PLAYTEST_UPGRADES.md) | The researched play-test upgrades U1 (the wet area) and U2 (the fin), each with its execution brief for a lead and its agents, and the team's decisions |
| [archive/U1_PROGRESS.md](archive/U1_PROGRESS.md), [archive/U2_PROGRESS.md](archive/U2_PROGRESS.md) | The handoff files of U1 and U2: the agents, the stops, the numbers, the open items and the take-over prompts. Michiel's review is still open (PH1 in the roadmap) |
| [archive/RACING_PLAN.md](archive/RACING_PLAN.md) | Phase 9's plan: parts 9A to 9E, the two courses, how a race works, the skippers, the compute, the execution brief |
| [archive/P9_PROGRESS.md](archive/P9_PROGRESS.md) | Phase 9's handoff file: every package, the Stops for Max, the night runs, the thread bench, the fleet measurements, the token ledger |
| [archive/AI_FLEET_PLAN.md](archive/AI_FLEET_PLAN.md) | The AI fleet: smarter skippers with character, 20 to 40 boards, trained on the full physics. F1 to F5 are built; its design (D1 to D7) and the team's decisions of 20 October 2026 still describe how the fleet and the training work. Archived 26 October 2026; the open parts are section RA of the roadmap |
| [archive/PHYSICS_REQUESTS_FROM_MAP.md](archive/PHYSICS_REQUESTS_FROM_MAP.md) | What the map asked of the physics (R1 to R9), with the measurements behind them: the thin air, the fresh water, the Maloja at Segl-Maria, the lake's waves. R1 to R3, R5 and R9 are done; archived 26 October 2026, the open ones are PH11, PH13 and MA6 in the roadmap |

## How the documents are written

For a team that is not made of experienced programmers: plain language, jargon explained, numbers with their source, and a clear line between what was measured and what nobody has verified yet (how it feels to sail, how it sounds). A plan carries a status table at the top; a progress file is updated and committed by the lead after every launch, report and merge, so any session can take over. When a document is moved, every Markdown link to it is rewritten and checked.
