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
| [AI_TRAINING_METHOD.md](AI_TRAINING_METHOD.md) | **Live.** How the AI skippers are trained and judged from 8 November 2026 (Max: "no one-trick ponies"): every race drawn at random (water, course, wind, countdown, start, R), checks every board must pass, every mark rounding measured, a hold-out set, the general head first, then the personas, then fleets; the tools (`tools/heads/random_suite.py`, the viewer), the speed, the steps |
| [MAP_SILVAPLANA_PLAN.md](MAP_SILVAPLANA_PLAN.md) | Max's map track: Lake Silvaplana from Swiss open data (phases M0 to M4) and the wind analyser (W0 to W5), with the open data's sources and the map's decisions. M0 to M3 and W0 to W5 are built; the open tasks (M4, W4b, the day types) are MA1 to MA8 in the roadmap |

## Reference

| File | What it is |
|---|---|
| [PHYSICS_SPEC.md](PHYSICS_SPEC.md) | **The physics as built.** Every model, formula, number and its source; the conventions; the tuning log. Updated with every physics change (Michiel's) |
| [POLAR_15KT.md](POLAR_15KT.md) | The board's speeds by course at 15 kt, from the validation suite; regenerated 26 October 2026 for the physics of 0.1.0 |
| [MALOJA_WIND_RESEARCH.md](MALOJA_WIND_RESEARCH.md) | How the Maloja wind behaves over Lake Silvaplana: the stations, the satellite photos, the gusts, the lee; the research behind the map's wind |
| [SILVAPLANA_SPOT_NOTES.md](SILVAPLANA_SPOT_NOTES.md) | Max's notes on the spot and his answers to the wind research's questions (some questions still open) |
| [Science/2501.13254v1.pdf](Science/2501.13254v1.pdf) | The full-scale wind-tunnel study of an iQFOiL 8 m² sail (Zhang et al. 2025, arXiv 2501.13254): its flying shape, twist, lift, drag and rolling moment at 4 to 8 m/s. The source of the sail's curve and twist (PH28, PHYSICS_SPEC.md 2.17) |
| [Science/Simon_Fagg.pdf](Science/Simon_Fagg.pdf) | Fagg (1997), PhD thesis, Bournemouth University: *The development of a reversible and finitely variable camber windsurf fin*. Added by Max for the fin physics. Read in Session 58: the fin on a planing board lifts 300 to 600 N and drags 20 to 50 N, about one sixth of the total drag (from Sutherland 1993 and Broers et al. 1992); fins are "typically sailed at an incidence angle of 6 degrees" (no source); tests of fins with tailored flex were inconclusive; nothing on the fin's vertical force or the board's pitch |
| [Science/s00138-020-01149-3.pdf](Science/s00138-020-01149-3.pdf) | Maciel et al. (2021), *Machine Vision and Applications* 32:26: the 3D flying shape of a sail from one camera with passive markers. Added by Max; not read yet |
| [Science/s00348-023-03752-2.pdf](Science/s00348-023-03752-2.pdf) | Viola et al. (2024), *Experiments in Fluids* 65:15: on-water sailing measurements (the wind angles taken at 10 m height). Added by Max; not read yet |
| [iqfoil_2026_u23_worlds_notice_of_race.pdf](iqfoil_2026_u23_worlds_notice_of_race.pdf) | The iQFOiL Notice of Race of the 2026 U23 Worlds in Puck; Addendum A has the ten course diagrams the course maker's templates follow |
| [images/](images/) | The wind research's figures (`maloja/`) and the README's screenshots (`readme/`) |

## Reports: what the agents measured and built

One report per package, written by whoever built it and read by the lead before the merge. They hold the numbers behind the decisions, and several are still the evidence for open items (Michiel's reviews PH1 and PH2, the measurements of GP0). A new package's report goes into a folder here named after its work (for example `reports/gameplay/` for GP0).

| Folder | Work |
|---|---|
| [reports/autopilot/](reports/autopilot/) | The autopilot on the PH28 physics (31 October 2026): the plan and the goal in numbers (`PLAN.md`), the rounds and the token ledger (`PROGRESS.md`, `rounds/`), the report (`autopilot_rework.md`: the rail's shape as the lever, the couple at 150 N, the push dial without the late ease, what is open). The suite is `tools/autopilot_suite.sh` and `tools/autopilot_summary.py` 6 November 2026, the evening: staying on the board (`stay_on_the_board.md`: the fall's bar moved, for Michiel's OK, and the recovery reflex; the rounds in `rounds/`, the night run's sweep `rounds/night6nov_reflex.txt`). |
| [reports/ph28/](reports/ph28/) | PH28, the sail rebuilt from the wind tunnel (`sail_wind_tunnel.md`: the tunnel against the legacy sail, the speeds before and after, the drag budget, why the hull is next), PH16 measured (`hull_balance.md`: what holds the nose down, the bounce, the rig's pitch lag), the three reviews of the branch (`review_sail.md`, `review_hull.md`, `review_sim.md`), what flying the board takes (`flying_the_board.md`), the sailor's controls read from the photos (`sailor_controls_plan.md`), Max's answers (`questions_for_max.md`), and Session 61's three builds: the real 8.0 and the twist's formula (`real_eight.md`), the rider's body, the front foot's couple and the rail (`rider_feet_body.md`), the hull's clip, the push's centre and the heeled bottom (`hull_suction.md`); the branch's live state is `PROGRESS.md` |
| [reports/fleet_gear/](reports/fleet_gear/) | Sessions 64 and 65 (31 October and 1 November 2026): the fleet's training and the gear. The nights reviewed, the brains sail but do not race, the diagnosis and the options (`nights_review.md`; the run's log, curves, evaluations and races in `nights/`). The plan with the parts, the lead's decisions and the stops (`PLAN.md`), the launches, merges and the token ledger (`PROGRESS.md`); the brands' slalom and free race gear researched with the game's gear set and the physics numbers (`brand_research.md`), the eleven made-up brands' logos and palettes (`brands.md`), the trainer on this machine: the conditions, the brain's push, the wind clock, the yardstick and the nights' command (`training.md`), the gear page and the catalogue with the sail sizes measured (`gear_page.md`), the boards and sails shaped and coloured after the brands (`gear_models.md`) 6 November 2026, the evening: the fin brands with a 28 to 52 cm depth slider (`fin_brands.md`). |
| [reports/fleet_speed/](reports/fleet_speed/) | Session 66 (1 to 3 November 2026): the AI sailors fastest around T1 and T2 (Michiel's brief of 1 November, evening). The plan with the packages, the lead's decisions and the stops (`PLAN.md`), the launches, merges and the token ledger (`PROGRESS.md`), the baseline race and persona matrices (`baseline/`), the agents' reports (`skipper_speed.md`, `trainer_tacks.md`, `characters.md`, `start.md`), the second night's review (`night_review.md`, its logs in `nights_tk/`) |
| [reports/gameplay/](reports/gameplay/) | Version 0.2's gameplay: GP0's measurement of the push and the body (`gp0_measure.md`: the dial's three settings, easing for the gusts, the warning signs before a catapult, the map of the rail against the back foot); GP11's measurement (`gp11_broad_reach.md`: from rest the board planes on courses up to 120° at 18 kt and sits on the hull's hump deeper, whatever the technique); GP2, the body on the mouse (`gp2_mouse_body.md`, the feet's press `gp2_feet_pressure.md`) and the push on the mouse with how the push and the body combine (`gp2_push_on_mouse.md`) 6 November 2026, the evening: the push on the mouse (`gp2_push_on_mouse.md`: the wheel and the burst, how the push and the body combine) and the manoeuvres (`gp_manoeuvres_6nov.md`: Space + A/D, the interactive turn, body carve and flip on cue). |
| [reports/racing/](reports/racing/) | Phase 9 and the AI fleet: the race core, the courses on the water, the course fitter, the skipper, the learning harness, the sea query (with its before and after reach checks, identical on purpose), the physics without the engine's locks (`no_wait.md`, for Michiel's review PH2), the fleet frame, the living skipper, the trainer, real life (wind shadows and the rules), the personas, the generations' race; `heads_8nov/` (8 November 2026): the skipper's heads trained on Silvaplana and racing each other (`README.md`, `PROGRESS.md`), the AI after R, dropped anywhere and the fleet's speed (`RESTART.md`) |
| [reports/waves/](reports/waves/) | Session 67 (2 November 2026): the waves and the wind (`waves_direction.md`): the rendered waves measured against the physics from two top-down screenshots (`wave_direction.py`, the screenshots), what was wrong for the player (the sea only changed at a restart, the file's spread, the chop bound to the wind), and what changed (the chop from a compass bearing, the wave spread, the sea at once, the menu's stutter, the push in the race block); Session 68 (3 November 2026), section 7: the 90° on Max's screen was the ripples' slopes, measured before and after (`ripple_compare.py`, `ripples_*.png`); PH44 (5 and 6 November 2026): Lake Silvaplana's own waves (`lake_waves.md`, `lake_waves/`) and their full version in the physics, with the hull's view of them and the check "Are the waves correct?" (`lake_waves_full.md`, `lake_waves_full/`); stage 4 (6 November 2026): SWAN installed and set up on the lake's depth and wind (its run waits for its runtime files), and what the eye sees: the game's individual waves against a real sea of the same Hs (`swan_silvaplana.md`, `swan_silvaplana/`) 6 November 2026, the evening: the wind's strength on the water and the lake wind multiplier (`wind_on_water.md`, the contact sheets at 8 to 30 kt in `wind_on_water/`) and the board's effects on the water (`board_fx.md`: the spray, the wake, the splashes, the before and after sheets in `board_fx/`). |
| [reports/ui/](reports/ui/) | Session 68: the race block and the push gauge, before and after (`race_hud_before.png`, `race_hud_countdown.png`, `race_hud_racing.png`; ROADMAP UI6). 6 November 2026: [race_screen_6nov.md](reports/ui/race_screen_6nov.md), the screen over the whole window, the mini-map's size setting, Max's buoys and the bigger boats, and the hooks for the LAN race director (ROADMAP UI7, UI8, GR10; the pictures in `race_screen_6nov/`) 6 November 2026, the evening: the small fixes (`small_fixes_6nov_evening.md`: the push gauge after the LAN menus, the finish list, UI scale, draw distance, the screenshots at four window sizes) and the race types with the slalom start and the marks (`race_types_6nov.md`). |
| [reports/u1/](reports/u1/) | U1, planing on a smaller wet area: the sources, the measurements, the physics, the planing onset, the porpoising, the finish (`finish_u16.md` measured where the board rails out) |
| [reports/u2/](reports/u2/) | U2, the fin bends: the sources, the measurements (`fin_measure.md` has a sweep of the rail from 0 to 24 degrees), the fin's physics, the heeled hull, the technique (`fin_technique.md`: the map of rail against trim), the look, riding the fin (`fin_ride.md`: the weight aft), the hull's lift. For Michiel's review PH1 |
| [reports/multiplayer/](reports/multiplayer/) | LAN multiplayer: the design and its log (`PLAN.md`), the race director of 6 November 2026 (`RACE_DIRECTOR.md`: up to 8 players, joining late, the live course, the lake sweeps), and spectating a LAN race (`spectate_6nov.md`: watch any racer, the lobby's and the menu's Spectate, finished players and late joiners watching, retiring). |
| [reports/playtest/](reports/playtest/) | Max's play-tests and the lead's progress files: the play-test of 5 November 2026 (`feedback_5_november_2026.md`: the fin, the dive, package B's design), the fourteen asks of 6 November 2026 built by Opus agents (`six_asks_6nov.md`: every branch, report, token count, merge and open question) and the night run of 6 to 7 November (`night_run_6nov.md` the plan, `night_run_6nov.sh` the script, `night_run_6nov.py` the summary, `night_run_6nov_results.md` the results). |

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
