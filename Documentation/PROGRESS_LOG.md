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
