# Changelog

What each version of the Windsurfing Simulator contains, newest first. The version number lives in `Game/project.godot` (`config/version`) and the start menu shows it. "Session n" refers to the entries in [Documentation/PROGRESS_LOG.md](Documentation/PROGRESS_LOG.md), where every session is written up in detail.

Version numbers: `0.x` while the team still changes the physics freely. A patch (`0.1.1`) is fixes only; a minor (`0.2.0`) adds features. How a release is made is in [ROADMAP.md](ROADMAP.md).

## 0.1.0 — 21 October 2026

The first release: the state of the game after Session 53, merged into `main` from `feature/p9-racing` (which carried U1, U2, Phase 9 and the AI fleet's F1 to F5). The first version that can be downloaded and played without Godot.

### The game, rebuilt in Godot (Phases 0 to 6; Sessions 28 to 38, 28 September to 16 October 2026)

- **The physics specification** written from the Unity version's code and documents, every model with its formula, inputs, units, coefficients and source, and the legacy contradictions resolved (Session 29; [Documentation/PHYSICS_SPEC.md](Documentation/PHYSICS_SPEC.md)).
- **The core simulation**, headless and tested: a 6-degree-of-freedom rigid body with fixed substeps, the force models one at a time with tests (buoyancy, hull drag and planing lift, fin, sail and apparent wind, rake steering, the sailor's weight), `WindsurferSim.step()` and a `Telemetry` snapshot (Session 30).
- **The playable prototype**: the input map, four cameras (follow, orbit, top-down, free), the telemetry HUD, a sky and water (Session 30). Then, from the first play-tests: falls instead of capsizes, downwind trim, the helm (rake, rig tilt, rail), beginner assists, a hull that carves when banked, tacks and gybes on Space and on the keys, trim by feel, getting out of irons, sheeting to the pull, sailing in 24 kt, and the manoeuvre matrix `tools/matrix.sh` (Sessions 31 to 34).
- **The autopilot, the validation suite and the tuning**: `tools/test.sh validation` with its sailing checks, and the polar at 15 kt (Session 35; [Documentation/POLAR_15KT.md](Documentation/POLAR_15KT.md)).
- **Waves and the ocean**: a Gerstner wave field, the ocean shader (vertex displacement, depth colour, Fresnel reflection, sun glint, foam) and a water mesh that follows the camera; the validation on a swell-dominated sea (Session 36). The sailor became a body of their own and the rig is held by the sailor (Session 37).
- **The rig's visuals**: board, sail, boom, mast and fin as Blender models built from the configuration's sizes by `tools/blender/build_rig_models.py`, a sail that bends with the simulation, the sailor figure on a fixed-length skeleton; the start, settings and pause menus, the controls and how-to pages (Session 38).

### Lake Silvaplana, the first real map (the map track; 14 to 16 October 2026)

- **M0 to M3**: the tools and the Swiss open data (the terrain, the lakebed, the 10 cm aerial photos), the terrain and the lakebed in Godot, the look (the photos, the sky, the mountains, see-through water, then realistic lake water), and sailing on the lake: the start off the camping beach, the thin air at 1,791 m, fresh water, the shore stop, the mini-map ([Documentation/MAP_SILVAPLANA_PLAN.md](Documentation/MAP_SILVAPLANA_PLAN.md)).
- **The wind analyser, W0 to W4a and W5**: the research into the Maloja wind ([Documentation/MALOJA_WIND_RESEARCH.md](Documentation/MALOJA_WIND_RESEARCH.md)), the fixed pattern over the terrain (direction from WindNinja, strength from satellite photos), the 3D wind viewer, gusts and lulls measured on the photos, pulses, shifts and the day's cycle, the race course maker with the ten iQFOiL templates, and the map's wind connected to the sailing (`MapWind`, with the time of day on the HUD).
- The physics and the map tracks merged on 16 October 2026.

### Environment, effects and sound (Phases 7 and 8; Session 39, 16 October 2026)

- One water shader for the sea and the lake, the sky and the haze with the Silvaplana light, spray from the rails, wake and foam behind the tail, a splash on landing, the red streamer at the masthead, the orange wind flag on a buoy, the force arrows (F3), gust patches on the lake from the map's wind.
- Every sound made from noise at startup and shaped by the simulation: the wind, the water (lapping, the planing hiss, splashes) and the sail (flapping, the crack when it fills), on three audio buses with sliders on the Audio tab.
- Waves by group (swell and chop), the board's shape, and the first sailing on Silvaplana in the game.

### Play-test upgrades (U1 and U2; Sessions 46 to 49, 19 October 2026)

- **U1, planing on a smaller wet area**: the porpoising fixed with a 1 degree tail vee and the flat tail, the stance and the rig's lean, the gust calibration; the wet length measured and reported in the telemetry ([Documentation/archive/PLAYTEST_UPGRADES.md](Documentation/archive/PLAYTEST_UPGRADES.md), [U1_PROGRESS.md](Documentation/archive/U1_PROGRESS.md)).
- **U2, the fin bends**: the fin as a bending beam with a measured stiffness (the IST Lisbon flex test), the heeled hull's lift fixed (the cause of the long wet part), the sailor's technique, the bending fin drawn, the fin's push as an arrow in the force view; the sailor riding the fin and the hull's planing lift against Savitsky studied and reported ([U2_PROGRESS.md](Documentation/archive/U2_PROGRESS.md)). Max: "feels quite nice now".

### Racing (Phase 9; Sessions 50 to 53, 19 to 21 October 2026)

- **A race you can sail** (9A): `RaceSim` (the countdown, the gun, OCS, the roundings by geometry checked against all ten iQFOiL templates, the clock, the splits, the results), the courses on the water (buoys, the committee boat, the pin, the lines, the mini-map), `CourseFitter` and the course maker's "Fit to water", the T1 training loop and the T2 sprint slalom, the race buttons in the menu, the racing HUD, R to race again ([Documentation/archive/RACING_PLAN.md](Documentation/archive/RACING_PLAN.md), [P9_PROGRESS.md](Documentation/archive/P9_PROGRESS.md)).
- **Scripted skippers** (9B): the `Skipper` (laylines, tacks and gybes, the timed start, keeping clear) with four characters, `tools/race.sh` and `tools/race_matrix.sh`; all four finish both courses at 12, 18 and 24 kt.
- **The learning harness** (9C): `RaceObservation`, `NeuralNet`, `RaceEnv`, `LearnedSkipper`, the evolution trainer `tools/race_evolve.sh` on all cores, and the first night brains.
- **The AI fleet, F1**: the release build (`tools/release.sh`), 3 substeps for every board (Michiel's decision), the sea query at half the cost with identical answers, the physics step without the engine's locks (`no_wait`, bit for bit the same), the race runner's batched worker tasks (`fleet_frame`): 20 AI boards and the player at 60 fps, measured with `tools/fleet_measure.sh`; the thread bench that found the global engine lock.
- **F2, the living skipper**: states driven by the race (free sailing in an area, the pre-start with the line bias and the end choice, loop or hold back, the OCS return, racing, finished), boards spawning anywhere, the countdown gathering the fleet.
- **F3, real life**: wind shadows through one hook in the wind fields (spec 8.11), the racing rules (`RaceRules`: port and starboard, windward and leeward, clear astern, room at the mark) with the penalty turn or 20 s, in the game, the race tool and the trainer.
- **F4, personas**: the skill sheet (`Persona`), twelve personas, `persona:<name>` in any race, the Race page in the menu, `tools/persona_matrix.sh`, `template:<ID>@<percent>` as a course name; the gear per persona built but off (a bigger sail is slower in this physics, for Michiel).
- **F5, the trainer**: `SailingDistance` as the reward, `RaceEnv` v2 with drops and respawns, `RandomCourses`, the curriculum S1 to S6 (`TrainingDrops`), the TCP bridge to Python, PPO with `tools/train.sh` (`pip install torch stable-baselines3`), the brain export with its parity test, the evaluation against the all-rounder, and `tools/gens.sh` to watch a night's generations race. The first PPO brains of stage S1 are in `Game/race/brains/`.

### Verified at the release

`tools/check.sh` 274 files, 0 failed; `tools/test.sh` 533 of 533; the validation suite at 3 substeps 40 pass, 1 fail (the planing onset, red on purpose), 2 pending (U1's wet-area targets).

### Housekeeping for the release (Session 54, 21 October 2026)

- The version set to 0.1.0; the export preset points at the release folder.
- The documentation reorganised without deleting anything: the finished plans and progress files moved to `Documentation/archive/` with a banner each, every link rewritten and checked, the iQFOiL notice of race renamed to a readable name, an index in `Documentation/README.md`.
- This changelog, [ROADMAP.md](ROADMAP.md) (what comes next and how updates are made), the README rewritten as the front page with the full feature list, and `CLAUDE.md` rewritten for the new state.
- The night brains and S1's generations committed (brains are built files; nothing is thrown away).

## Before 0.1: the Unity version (December 2025 to September 2026; Sessions 1 to 27)

The game began on 19 December 2025 as a Unity project in C#: the physics simulation, the controller, the UI, Blender models of the board and sail, and in Session 27 ideas for an ocean shader, Gerstner waves, sail cloth, spray and procedural audio that were never compiled or played. It was never released. It is kept, read-only, in [`Legacy/`](Legacy) with its own documentation and progress log; several of its sign-convention tables are wrong, and the Godot version derives its conventions afresh.
