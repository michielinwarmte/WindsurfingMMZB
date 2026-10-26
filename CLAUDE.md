# CLAUDE.md

Windsurfing simulator by the MMZB team in **Godot 4.7.2 (standard build, GDScript)**. The Godot project is in `Game/`. Version 0.1.0 was released on 21 October 2026; the old Unity version is in `Legacy/` as a read-only reference.

**Where things stand:** [ROADMAP.md](ROADMAP.md): every open item by section of the game (GP gameplay, PH physics, RA racing, GR graphics, SO sound, UI, MA map, TE tech, PR project), each with an ID, its files, what it waits on and its version; the plan for 0.2; what waits for whom; how an update and a release are made; the prompts to continue. Refer to items by their ID, and when an item is done or a new one appears, update the roadmap in the same session. The newest entry in [Documentation/PROGRESS_LOG.md](Documentation/PROGRESS_LOG.md) says where the last session stopped. The map of every document is [Documentation/README.md](Documentation/README.md); finished plans and progress files live in `Documentation/archive/` and are never deleted, and the agents' reports in `Documentation/reports/<work>/`.

**The tracks:**
- **The gameplay and controls** (`Game/windsurfer/player_controller.gd`, the input map, the HUD): version 0.2 makes the player the sailor, from [the design](Documentation/gameplay_controls_v0.2.pdf) (a voice session with Tarpie, 23 October 2026) and Max's direction of 26 October: easy to just go and a little challenging to go fast. Package A is one dial (push); package B, an experiment, puts the rail and the back foot's pressure on the mouse. The items are section GP of the roadmap. Both set numbers the autopilot and the sailor's technique already have, from the controller (B through the player's own copy of `SailorConfig`); a new field of `SimControls` would be a physics change (below).
- **The physics** (`Game/sim/`): Michiel's. Every change needs his OK, a branch, an update of [Documentation/PHYSICS_SPEC.md](Documentation/PHYSICS_SPEC.md) and `tools/test.sh validation`.
- **The map** (`Game/maps/`, `tools/map/`): Max's. Lake Silvaplana from Swiss open data and the Maloja wind (the wind analyser, W0 to W5), planned in [Documentation/MAP_SILVAPLANA_PLAN.md](Documentation/MAP_SILVAPLANA_PLAN.md). It does not touch `Game/sim/`; what it still needs from the physics is in the roadmap (PH11, PH13), and the requests with their measurements are in the archived [PHYSICS_REQUESTS_FROM_MAP.md](Documentation/archive/PHYSICS_REQUESTS_FROM_MAP.md). The map's big files (terrain tiles, photos, the height grid) are stored with **Git LFS**: install it and run `git lfs install` before cloning or pulling, or you get small pointer files instead of the terrain and `tools/check.sh` fails on them. Map commands: `tools/map/build.sh` (download the data and prepare it; see [tools/map/README.md](tools/map/README.md)) and `tools/blender.sh <script.py> [args]` (a Blender script headless).
- **Racing and the AI fleet** (`Game/race/`): led by a Fable session with Opus agents; the open items are section RA of the roadmap, and the design (D1 to D7, the training's curriculum, the team's decisions) is in the archived [AI_FLEET_PLAN.md](Documentation/archive/AI_FLEET_PLAN.md). Play-test feedback becomes a researched upgrade with an execution brief before anything is built (the pattern is in the archived [PLAYTEST_UPGRADES.md](Documentation/archive/PLAYTEST_UPGRADES.md)).

## The team

The team are not very experienced programmers and rely on AI for most of the code. So:
- Explain what you did and why in plain language. Avoid jargon, or explain it when you need it.
- Write simple, readable code: clear names, short functions, comments that explain the physics or the reason behind a choice. No clever tricks.
- Verify your own work (tests, check, screenshots) before saying something works. Say clearly what you could not verify, such as how it feels to sail or how it sounds.
- Stop at the end of each phase or package so the team can play-test. Stop and ask at a brief's Stops and stop rules, in plain language, with the options; proceed on your own for visuals-only work and verification.
- Max answers decisions in short numbered lists and relays Michiel's decisions. Max has two budgets: his normal usage (Opus agents) and his Fable usage; when he says Fable is to spare, build the package yourself and spawn no agents. Agents cost about 0.3 to 0.9 M tokens each; keep a token ledger in the progress file of the work.

## Commands (run from the repo root)

| What | Command |
|---|---|
| Fast unit tests, after every change | `tools/test.sh` |
| Slow physics validation | `tools/test.sh validation` (or `tools/test.sh all`) |
| Only some tests | `tools/test.sh unit -gselect=buoyancy` |
| Every manoeuvre (tack, gybe, run, irons, straight) at 12, 18 and 24 kt, one line each | `tools/matrix.sh [--only=tack] [--winds=18] [--waves=1] [--pilot.field=value ...]` (45 s; the per-case CSVs land in `.sim_output/matrix/`) |
| The same manoeuvres on Lake Silvaplana in the map's own wind (12:00, 14:30 and 17:00), thin air and fresh water | `tools/lake_matrix.sh [--only=straight] [--compare=1]` (the thin-air comparison; options in `Game/dev/run_lake.gd`) |
| Does every script, scene and resource load? | `tools/check.sh` |
| Screenshot of the running game | `tools/screenshot.sh [res://scene.tscn] [out.png] [frames] [--options]`, then Read the PNG (default `.screenshots/latest.png`). With no scene it shows the start menu; `res://main.tscn --autopilot=1 --camera=2` is the sailing scene, `--pause=<s> --page=settings/wind` opens a menu page, `--settings=<file.cfg>` plays with those settings (otherwise the defaults) |
| Look up the exact Godot 4.7 API | `tools/api_docs.sh` once, then grep `.godot_api/doc/classes/<Class>.xml` |
| Play the game / open the editor | `tools/play.sh` (the start menu) / `tools/edit.sh` (these open windows and are meant for the team). `tools/play.sh res://main.tscn` goes straight to sailing on open water, `tools/play.sh lake` to sailing on Lake Silvaplana, `tools/play.sh silvaplana` opens the Silvaplana terrain view, `tools/play.sh wind` the wind viewer (with the race course maker); `tools/play_push.sh` is GP0's playtest (24 kt, gusts, the sailor pushed; the F1 panel freezes what came before each fall); double-clicked, play.sh asks what to start |
| A race, headless | `tools/race.sh --course=t1_loop --skippers=allrounder,cautious,gambler,rookie --seconds=720` (also `persona:<name>`, `brain:<name>`, `--laps=`, `--rules=0`, `--shadows=0`); `tools/race_matrix.sh` runs the four characters on both courses at 12, 18 and 24 kt |
| GP0's measurement: the player's beginner controller sailed headless with the autopilot's margin (`--pilot.<field>`) or the sailor's technique (`--sailor.<field>`) set or swept per case, in the game's open water with gusts; the speed made good, the falls and the 2 s before each fall | `tools/push_check.sh --sweep=pilot.hike_share=0.8,1.1,1.6 [--winds=18 --twas=100] [--timing=1 ...] [--jobs=4 --run=<name>]` (the CSVs in `.sim_output/push/<run>/`; the options are in `Game/dev/run_push.gd`; keep `--jobs` well below the cores on Max's laptop) |
| The twelve personas raced against each other on a windward-leeward and a slalom, their places side by side (the specialists show) | `tools/persona_matrix.sh [--wind_kt=15] [--seed=1] [--personas=lena,tobias]` (some 20 minutes; the table in `.sim_output/persona_matrix.txt`) |
| Train the AI fleet's head (PPO in Python on races Godot sails headless, one curriculum stage at a time; `pip install torch stable-baselines3` once), or see how a brain does on a stage's drops against the all-rounder | `tools/train.sh --stage=S1 --hours=3`, then `--stage=S2 --resume=Game/race/brains/s1_best.json`; unattended: `tools/train.sh --stages=S1,S2,S3,S4,S5,S6 --hours_each=4 --workers=12` (log `.logs/nights.log`); `tools/train.sh --evaluate=Game/race/brains/s1_best.json --stage=S1 --reference=allrounder` (the stages and options are in `Game/race/training_drops.gd` and `tools/train/train.py`). Not on Max's laptop: it crashed five times under full load |
| The older evolution trainer, and a night's generations racing each other on T1 | `tools/race_evolve.sh --run=<name> --hours=5` (one Godot per core); `tools/gens.sh [--run=night2b] [--count=20] [--headless]` |
| The game as a release build (the engine without the editor: the AI boards' physics scales over threads there, the editor build collapses beyond four boards) | `tools/release.sh build`, then `tools/release.sh --race=t1_loop [--skippers=a,b,c] [--measure=12]`; needs the Windows export templates installed once (see the script's header). `tools/fleet_measure.sh --sizes=16,20,24,32,40` measures the frame by fleet size on it |
| Benches | `tools/thread_bench.sh [--release]` (what GDScript work waits on a global engine lock), `tools/sea_bench.sh` (the sea query's cost) |
| Contact sheets of the sailor figure, or the rig from eleven cameras | `tools/godot.sh --path Game --resolution 1280x720 --audio-driver Dummy res://dev/figure_view.tscn -- --wind=18 --times=8` and `tools/screenshot.sh res://dev/rig_view.tscn .screenshots/rig/view.png 600` (the options are in the two scripts' headers) |
| Rebuild the board, sail, boom, mast and fin models after a size changed in `Game/config/` | `tools/blender.sh tools/blender/build_rig_models.py` (about 2 s; writes `Game/assets/models/*.glb`) |
| Fit the saved courses to the lake's water | `tools/fit_courses.sh` |
| Anything else with Godot | `tools/godot.sh <args>` |

Always go through these scripts instead of calling `godot` directly: they use the pinned Godot version, exit non-zero on failure and keep logs in `.logs/`. On Max's Windows PC set `GODOT` first in the Bash shell: `export GODOT=/c/Users/maxba/AppData/Local/Programs/Godot/Godot_v4.7.2-stable_win64_console.exe` (Godot 4.7.2 is installed in `C:\Users\maxba\AppData\Local\Programs\Godot`). `tools/screenshot.sh` opens a game window for a few seconds; that is expected. Long quoted heredocs fail silently in that shell: write a script file and run `python -I <path>`; never put `&` at the end of a chained command.

## Godot 4, not Godot 3

A lot of GDScript online is Godot 3. Use Godot 4.7 syntax and APIs:
- Annotations `@export`, `@onready`, `@tool`; `await some_signal` (not `yield`); `some_signal.connect(callable)`; `super()`.
- `Node3D`, `CharacterBody3D`, `Transform3D`, `PackedVector3Array`, `instantiate()`, `FileAccess.open()`, `deg_to_rad()`, `randf_range()`. Not `Spatial`, `KinematicBody`, `Transform`, `PoolVector3Array`, `instance()`, `File.new()`, `deg2rad()`, `rand_range()`.
- Static types everywhere: `var speed_ms: float = 0.0`, `func drag(v: Vector3) -> Vector3:`, `for i: int in count:`, `Array[float]`, `Dictionary[String, float]`. **Untyped declarations are errors in this project.**
- Scene and resource files are text (`.tscn`/`.tres`, `format=3`). Editing them by hand is fine; run `tools/check.sh` afterwards.
- When unsure whether a method or property exists, look it up with `tools/api_docs.sh` instead of guessing.
- In Godot 4.7.2 every read or write of another object's field from a worker thread takes a global engine lock (the release engine too); method calls, `self.field`, statics and packed arrays do not. Physics stepped on threads reads other objects' fields once per function and hands results back through its own fields and methods (the `no_wait` package).

## Architecture rules

1. `Game/sim/` is the physics: plain GDScript classes (RefCounted or Resource), **no Nodes and no engine physics bodies**, with the time step passed in. Tests run it headless; scene scripts copy its state onto the visuals. (Decision D2 of the archived rebuild plan.)
2. The simulation drives the visuals. Nothing visual feeds back into the physics.
3. Tuning numbers live in config resources (`.tres` files in `Game/config/`), not in code.
4. SI units inside the simulation (m, s, kg, N, rad). Put the unit in the name when it isn't obvious: `speed_ms`, `area_m2`, `heading_deg`. Convert to km/h, knots and degrees only for display.
5. Conventions (decision D4):
   - +Y is up, the bow is local −Z (`Vector3.FORWARD`), starboard is local +X.
   - Compass: North is world −Z, East is world +X.
   - Wind is described by the direction it comes FROM.
   - Wind angles (TWA/AWA) are positive when the wind comes from starboard: `atan2(from_local.x, -from_local.z)`. Do not use `signed_angle_to` for this, because it is positive toward port.
   - Rake back makes the board head up and rake forward makes it bear away, on both tacks.
   - `tests/unit/test_engine_conventions.gd` pins the engine facts behind these rules. If a test and these rules disagree, stop and ask.
6. Physics interpolation is on. Move things in `_physics_process`, let cameras follow with `get_global_transform_interpolated()`, and call `reset_physics_interpolation()` after teleporting something.
7. Every AI board runs the same physics, the same controller and the same substeps as the player (Michiel, 20 October 2026): no cheap models, no shortcuts.

## Workflow

- Work in small steps. After each change run `tools/test.sh`, and after scene or resource changes also run `tools/check.sh`. Never end a session with failing tests or a failing check (the one validation check that is red on purpose, the planing onset, is listed in the roadmap).
- Visual change: run `tools/screenshot.sh` and look at the image before saying it works.
- Physics change: run `tools/test.sh validation` and update `Documentation/PHYSICS_SPEC.md`.
- New behaviour gets a new test. For a bug, first write a test that reproduces it.
- End of every session: add an entry at the top of `Documentation/PROGRESS_LOG.md` and move the finished items in `ROADMAP.md`.
- End of a phase or package: stop, give the team a plain-language summary and the play-test checklist, and suggest a commit.
- Git: work on a feature branch and make small commits with clear messages when the team agrees. Nothing goes to `main` without the team. Branches, worktrees, brains and documents are not deleted: finished documents move to `Documentation/archive/`.
- A lead with agents: at most three Opus agents at a time (model opus, effort xhigh, their own worktrees on `<track>/<name>` branches); read every physics diff yourself before Michiel sees it; update and commit the progress file after every launch, report and merge.
- Releases: the steps are in `ROADMAP.md` ("How an update is made"): the version in `Game/project.godot`, the changelog, the checks, `tools/release.sh build`, the zip, the tag.
- Godot writes `.uid` files next to scripts and `.import` files next to assets. Commit them. Never commit `Game/.godot/`. Don't edit `Game/addons/gut/` (the GUT test framework, version 9.7.1). Brains in `Game/race/brains/` are built files and are committed.
- Moving or renaming files outside the Godot editor breaks `res://` references. Update the references and run `tools/check.sh`. Moving a document breaks Markdown links: rewrite them and check every link (the release's script did this with a link checker).
- `Legacy/` is read-only. Don't edit it, and don't copy code from it as-is: it is C# written for Unity's left-handed coordinates. Several of its sign-convention tables are wrong; see "Known legacy pitfalls" in the archived rebuild plan.
