# Progress Log

One entry per session, newest first. Sessions 1 to 27 (the Unity version) are in [Legacy/Documentation/PROGRESS_LOG.md](../Legacy/Documentation/PROGRESS_LOG.md).

Template for new entries:

```
## <date> - Session <n>: <topic>
**Phase:** <phase from REBUILD_PLAN.md>
**Done:** what changed, in plain language
**Verified:** which tests/checks/screenshots passed; what could NOT be verified
**Decisions:** anything decided, and why
**Next:** where the next session should pick up
```

---

## 2 October 2026 - Session 29: Physics spec from the Unity version

**Phase:** 1, done. Started on 28 September 2026, finished on 2 October after the session's token limit interrupted the first attempt.

**Done:**
- Wrote [PHYSICS_SPEC.md](PHYSICS_SPEC.md) (about 5,800 lines, 17 sections): conventions and notation; apparent wind; sail; rake steering and the stabilisers around it; fin; hull drag, displacement lift and Savitsky planing; buoyancy and water damping; mass, inertia and the sailor's centre of mass; wind; Gerstner waves; controls; the master table of every tuning value; a register of 36 stabilisers and fudges (`F-01` to `F-36`); the legacy contradictions and their resolution; the default configuration and the Phase 4 validation targets; the open questions; an empty tuning log.
- How it was made: the first attempt fanned the work out to 16 extraction agents with three reviewers each. That exhausted the 5-hour session limit in about ten minutes, so none of the reviewers ran, and the scratch folder with the drafts was wiped before the next session. Nine drafts were recovered from the agents' Write calls and five more from Bash heredocs in their transcripts; the fudge register, the open questions, the tuning log and the header were written by hand. Every section was then read and corrected by hand against the legacy code.
- What the spec found that the plan did not know (header of the spec, "Six things"): the Unity scene file holds the values that ran, and the Session 22 numbers survived to the last played Session 26 scene, so the documented tuning (0.85 lift cap, 4000 damping, Savitsky) was never played; the played planing lift was a speed ramp capped at 6 % of the weight; the body weighed 94 kg while the hull's caps used 91 kg; the sail force acted at the board origin; the sail side came from the Space key, not the wind; the legacy TWA had the opposite sign of the legacy AWA; the validated runs were on flat water in 15 kt (22 kt in the Session 26 commit) with the wind sampled at the board origin.
- Corrected the plan's own fudge list (the "150 × rake" and "0.3 between 15 and 25 kt" figures came from older docs) with a note in the plan, ticked the Phase 1 boxes and set Phase 2 to Next.

**Verified:**
- `tools/test.sh`: 10/10 unit tests pass. `tools/check.sh`: 6 files, 0 failed. Nothing under `Game/` changed this session.
- Read and cross-checked by hand: SailingState, Aerodynamics, AdvancedSail, AdvancedHullDrag, AdvancedBuoyancy, AdvancedFin, Hydrodynamics, BoardMassConfiguration, AdvancedWindsurferController, WindSystem, GerstnerWave, WaterSurface, PhysicsConstants, the setup wizard and the project settings. The inconsistencies found between sections were fixed: the default wind (15 kt from 270°, not the wizard's 12 kt from 45°), the mass arithmetic (8 + 6 + 80 = 94), wrong section numbers, and which section owns the default configuration (section 14).
- Not verified: the automated three-lens reviews (source fidelity, sign conventions, physics) did not run. Line references inside the sections were produced from the files by the agents and were spot-checked, not re-verified one by one. The real-equipment numbers in section 14 come from web pages read on 28 September and were not re-checked. Nothing about how the game feels can be known until Phase 3.

**Decisions:**
- Section 14 owns the default configuration: 120 L board of 2.40 × 0.72 × 0.12 m and 9 kg; 6.5 m² sail with a 4.60 m luff and 1.95 m boom; 38 cm fin of 0.0365 m²; sailor 75 kg, rig 8 kg, total 92 kg; tests in 15 kt from the West on flat water. Open for the team (question 3). The worked examples in the model sections keep the legacy configuration (2.5 × 0.6 m, 91 or 94 kg) because that is what the legacy code was checked against.
- Phase 2 keeps a speed-based planing ratio as a model input (section 5 F4); planing onset is measured as the speed at which dynamic lift carries half the weight (section 14). The planing lift gets one hard cap at exactly the weight and no tunable fraction.
- Every fudge has an ID; config comments and the tuning log cite it, so nothing is re-added by reflex.
- Process: do not run large multi-agent workflows in this project; they exhaust the session limit. Work solo, or with one or two agents at most.

**Next:** Phase 1 Stop. The team answers the seven questions in PHYSICS_SPEC.md section 15 (top speed, fastest point of sail, default equipment, control modes, what Space does, the wind reference height, how fast full rake should turn). Then Phase 2 starts from sections 0, 14 and 11 and the owning sections, in the plan's order: config resources, integrator, environment interfaces, buoyancy, hull drag and planing, fin, sail and apparent wind, rake steering, sailor mass and centre of mass.

---

## 28 September 2026 - Session 28: Switch to Godot, preparation

**Phase:** 0 (preparation), done.

**Done:**
- The team decided to restart from scratch in Godot 4.7 instead of continuing in Unity. The main reason is better AI support: an AI session can now run the tests, check every file and look at screenshots itself. Before, Session 27 had to be written without ever running Unity.
- Moved the whole Unity project, the old docs, README and CONTRIBUTING into `Legacy/` with `git mv`, so their history is kept. The Unity `.gitignore` moved into `Legacy/WindsurfingGame/`. `Legacy/README.md` now starts with a banner explaining what is useful there and which legacy tables are wrong.
- Installed Godot 4.7.2 (official build, SHA-512 checked) in `~/.local/opt/godot/4.7.2-stable/`, with `~/.local/bin/godot` and an app-menu entry. No sudo needed. `tools/install_godot.sh` does this again for anyone on Linux.
- Created the Godot project in `Game/`:
  - Forward+ renderer, 1280×720 window, physics interpolation on
  - untyped GDScript declarations are errors
  - GUT 9.7.1 test framework
  - `DevCapture` autoload for screenshots
  - placeholder `main.tscn` with sky, sun, a water plane, and the old board and sail models (copied from Unity)
  - its own icon
- Tools in `tools/`: `install_godot.sh`, `godot.sh`, `test.sh`, `check.sh`, `screenshot.sh`, `api_docs.sh`, `play.sh`, `edit.sh`, all sharing `common.sh`.
- First tests: `tests/unit/test_engine_conventions.gd` (Godot's axes and angle signs that our physics conventions depend on) and `tests/unit/test_project_setup.gd` (version, typing rule, physics interpolation, main scene). A pending placeholder sits in `tests/validation/`.
- VS Code: installed the godot-tools extension (2.7.1) and set its Godot path in the user settings.
- Wrote `CLAUDE.md`, `README.md`, `Documentation/REBUILD_PLAN.md` and this log.

**Verified:**
- `tools/test.sh`: 10/10 unit tests pass. `tools/test.sh all`: 10 pass, 1 pending (the validation placeholder).
- `tools/check.sh`: every file loads. It was also confirmed to fail on a deliberately broken script and on an untyped variable, and `tools/test.sh` was confirmed to fail on a deliberately failing test. The probe files were deleted afterwards.
- `tools/screenshot.sh`: the placeholder scene renders on the RTX 3080 Ti (Vulkan, Wayland session): sky, water, sail and boom visible. The image was checked.
- Not verified: opening the editor by hand (`tools/edit.sh`) and the GUT editor panel. Everything was driven from the command line.

**Decisions:** see "Key decisions" D1 to D7 in the plan. The biggest one: we write our own rigid-body simulation in plain GDScript (D2), so the physics can be tested headless and fast.

**Found along the way:**
- Legacy `PHYSICS_VALIDATION.md` has port and starboard swapped in its AWA and sail-side tables, and says "rake back = bear away". The Unity code (correctly) uses AWA > 0 for wind from starboard and makes rake back head up.
- `board.fbx` points along X, contains a stray camera and refers to a missing Starboard product photo. `sail.fbx` has a mast without faces and refers to a missing Severne graphic. Details are in the Phase 6 notes of the plan.
- The repository has no LICENSE file, although the old README said MIT.

**Next:** Phase 1, writing `Documentation/PHYSICS_SPEC.md` from the legacy physics code and docs.
