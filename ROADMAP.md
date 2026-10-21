# Roadmap

What comes after version 0.1.0, who decides what, and how an update is made. This is the live "where things stand" file: an AI session reads it after [CLAUDE.md](CLAUDE.md); the team keeps its decisions here. The detailed history of every item is in the archived plans and progress files under [Documentation/archive/](Documentation/archive/) and in [Documentation/PROGRESS_LOG.md](Documentation/PROGRESS_LOG.md).

Last update: 21 October 2026 (Session 54, the 0.1.0 release).

## How an update is made

1. **Work on a branch** (`feature/<name>`; packages built by agents on `u<n>/<name>`, `f<n>/<name>` or `p9/<name>` branches in their own worktrees), in small commits. `tools/test.sh` after every change, `tools/check.sh` after scene or resource changes, a screenshot for every visual change.
2. **Physics changes** need Michiel's OK, an update of [Documentation/PHYSICS_SPEC.md](Documentation/PHYSICS_SPEC.md) and `tools/test.sh validation`. The map track does not touch `Game/sim/`.
3. **Merge to `main`** when the team agrees (a pull request, or a merge commit with `--no-ff` so the branch stays visible in the history). Nothing goes to `main` without the team. Branches are not deleted; nothing is thrown away.
4. **A session ends** with an entry at the top of the progress log and the finished items ticked or moved here.
5. **A release:**
   - set `config/version` in `Game/project.godot` (the start menu shows it) and the placeholder `v...` text in `Game/ui/start_menu.tscn`;
   - add the version to [CHANGELOG.md](CHANGELOG.md) with the date and what it contains; update the "Known gaps" of the README;
   - `tools/check.sh`, `tools/test.sh`, `tools/test.sh validation`, all as expected;
   - `tools/release.sh build`, then zip `.release/wsim.exe`, `wsim.pck` and `wsim_console.exe` as `WindsurfingSimulator-<version>-windows.zip` (the Windows export templates of Godot 4.7.2 must be installed once; the script's header says how);
   - tag `v<version>` on `main` and push the tag; on GitHub, "Draft a new release" from the tag with the changelog section as the text and the zip attached.

## Waiting for the team

Decisions and reviews that only Max or Michiel can make. Everything else below can be built without them.

**Michiel (the physics):**
- The U2 physics review (Stop 2 of U2): the bending fin, the heeled hull's lift, the sailor's technique, the gust calibration, the critical trim, the probe. The list and the questions are in [U2_PROGRESS.md](Documentation/archive/U2_PROGRESS.md) ("Stop 2 package") and in the brief's U2 subsections of [PLAYTEST_UPGRADES.md](Documentation/archive/PLAYTEST_UPGRADES.md).
- The F1 `no_wait` rewrite of `Game/sim/`: no formula changed, every answer bit for bit the same (the whole state hashed every tick over eight runs). The list per file is in [no_wait.md](Documentation/racing_reports/no_wait.md).
- The wind shadow's numbers (`Game/config/wind_shadow_default.tres`, spec 8.11).
- The sail sizes before the gear per persona goes on: as the sails are, a 7.8 is slower off the line than a 6.5 even in 12 kt (`Persona.rig()`, off by default).
- The hands' cost: `Game/sim/autopilot.gd:196` searches 21 angles of attack every tick (a fifth of the hands' cost; ten times a second or a table by apparent wind angle gives the same trim).
- The planing onset check, red on purpose at 13.4 kn against 8 to 10 kn; the buoyancy factor is built but off. U1's wet-area targets (0.6 to 1.0 m against 1.35 to 1.59 m measured): is the 1 degree vee's limit the answer?
- Max's questions from U2: the mast foot's 400 N (the sailor's own weight through the boom), the hands' share of the boom force, the fin's size and the mast track as player settings, Max's own fins' flex test.
- From the sea query: `fin_model.gd` still asks the sea twice per substep the old way (a warm query would move the waves by the solver's millimetre); the spec's 9.5 table ("about six passes") is for the old wave set.

**Max (play-tests and gameplay):**
- **Stop A2:** sail among the buoys of T1 and T2; the course maker's Fit to water; the race matrix; the night's brain.
- **F1's Stop:** the frame-time table by fleet size (20 AI boards and the player hold 60 fps on the release build, 24 do not, and the fall is a cliff). The levers for 32 and 40: the hands cheaper, the rest of the physics' locks, a cap on the catch-up ticks (2 instead of 8: a gameplay choice).
- **F2's Stop:** watch 16 boards gather and start on both courses (`tools/release.sh --race=t1_loop --skippers=<16 names> --prestart=60`); whether the gathering, the start styles (who loops, who holds) and the 60 s countdown look right.
- **F3's Stop:** race in a crowd of eight: does the shadow feel right, is 20 s the right price for a penalty, does the AI's circle look like a penalty turn.
- **F4's Stop:** the twelve personas' names and profiles (the lead's choice; the team may rename them), and whether the sheets make the characters the profiles promise (race them from the Race page).
- The team's look at the effects (Phase 7) and a careful listen to the sound (Phase 8): nobody has done either yet.
- The lake play-test (M3): the start spot, the Maloja setting, the shore.
- A license for the repository (the old README said MIT; there is no LICENSE file).
- Where the training nights run now that this laptop is ruled out (it crashed five times under full load): another machine, with `tools/train.sh --stages=S1,S2,S3,S4,S5,S6 --hours_each=4 --workers=<cores>`; the state of the nights is read from `.logs/nights.log` and `.sim_output/train/<run>/`.

## Next builds, in order

1. **F6, the big fleet in the game:** 24 and 32 boards measured and played, 40 if the frame allows (the Stop: 32 boards at 60 fps on a laptop). The levers are F1's: the hands' cost, the rest of the physics' locks, the catch-up cap. The fleet list on the HUD shortened to the top few and the boards around you; `Skippers.make_fleet()`'s numbered labels cut by the HUD ("All-rounder 1" shows as "All-rounder").
2. **The trained head, stages S2 to S6** on another machine, then F5's Stop: the first fleet race against the trained brain (`tools/release.sh --race=t1_loop --skippers=brain:s6_best,allrounder,rookie`). Then the personas on the trained head (D3's second half of [AI_FLEET_PLAN.md](Documentation/AI_FLEET_PLAN.md)).
3. **Collisions:** boards with each other and with the marks (simple custom checks, as the rebuild plan's decision said; the game's engine physics is not used for the board).
4. **The lake's shore for the opponents:** running aground on the lakebed (R4 of [PHYSICS_REQUESTS_FROM_MAP.md](Documentation/PHYSICS_REQUESTS_FROM_MAP.md)), so the AI boards stop where the player stops.
5. **The countdown sounds** and the race's small HUD items.
6. **The map's remaining phases:** M4 (the camping and the beach, the village, trees, landmarks), W4b (the tactics tools in the course maker), the day types of W3, and the later projects with Michiel (wind-driven waves, live weather, other spots): [MAP_SILVAPLANA_PLAN.md](Documentation/MAP_SILVAPLANA_PLAN.md).
7. **Sailing with a gamepad.**

## Smaller follow-ups (any session)

- `windsurfer.gd` could call `_rig.bend_fin(...)` instead of the rig reading its parent's `sim`.
- `board.glb` needs a Blender rebuild for the flat tail; the 44 cm fin's look is unverified; spray drag is missing (U1.7).
- The trainer: the lake's wind and water in the stages (D6 wanted courses fitted to Lake Silvaplana in the map's wind; the stages sail the open water's physics on courses of every shape); the idle steps of parked boards in S5 and S6; `tools/gens.sh --run=s1 --behind=20 --prestart=5` for runs whose early stages never saw a start.
- The plan's T1 episode and lap times corrected in the archived racing plan.
- Godot rewrites `Game/default_bus_layout.tres` on some runs; every agent restored it. Worth a look at why.
- The start menu's title is cut off at the top in a 1280 by 720 window.
- The editor build collapses beyond a few boards (a global engine lock on every read of another object's field in Godot 4.7.2); the release build is the way to play a fleet until the physics' remaining locks are gone.
- The pack is 325 MB because the lake's terrain and photos are in it; a smaller download would need a lower-resolution tile set.

## Prompts to continue (for an AI session)

**The AI fleet:** "Read CLAUDE.md, ROADMAP.md, Documentation/AI_FLEET_PLAN.md and Documentation/archive/P9_PROGRESS.md (F1 to F5 are merged and released in 0.1.0; four Stops for Max are listed in the roadmap). If training nights have run, read `.logs/nights.log` (the lines `=== stage ... over ===` and `check (`) and `.sim_output/train/<run>/curve.csv` first, run the last stage's `--evaluate` against the all-rounder, and say in plain language where the training stands. Then take Max's answers to the Stops and lead F6 (the big fleet) and the personas on the trained head as the archived RACING_PLAN.md's execution brief describes, with the plan's section D7 on tokens: one agent per package in a worktree on a branch from `main`, extra-high effort only where the brief says so, a stop for Max at each part's Stop; or, when Max has Fable tokens to spare, build the package yourself. Keep the roadmap and the progress log current after every launch, report and merge, with the token ledger."

**U1 and U2 (after Michiel's review):** the take-over prompt at the end of [U2_PROGRESS.md](Documentation/archive/U2_PROGRESS.md) applies, with Michiel's answers written into the archived brief and the decisions moved here. The full manoeuvre matrix (`tools/matrix.sh`, `tools/lake_matrix.sh`) is still to be run with the stance, the rig's lean, the fin and the hull as they are now; no manoeuvre was run in U1 or U2.

**The map:** [MAP_SILVAPLANA_PLAN.md](Documentation/MAP_SILVAPLANA_PLAN.md) has its own status table and phases; continue with the first unticked task.

## Done since the plans were written

Kept here so nothing is lost when the archived plans are read: Phase 9's parts 9A to 9C and the AI fleet's F1 to F5 are built and in 0.1.0 (the archived [RACING_PLAN.md](Documentation/archive/RACING_PLAN.md) still shows 9A and 9B as "built up to" and 9D as open: 9D continues as F5 and the personas on the trained head). Phases 7 and 8 of the rebuild plan are in 0.1.0 with the team's check open. U1 and U2 are in 0.1.0 with Michiel's review open. The decisions of 20 October 2026 in AI_FLEET_PLAN.md stand (wind shadows yes, the rules yes, 20 boards to start, T2 at 60 %, the countdown 60 s, the names stay, the same controller and the same 3 substeps for everyone).
