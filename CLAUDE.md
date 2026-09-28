# CLAUDE.md

Windsurfing simulator by the MMZB team, being rebuilt from scratch in **Godot 4.7.2 (standard build, GDScript)**. The Godot project is in `Game/`. The old Unity version is in `Legacy/` as a read-only reference.

**What to work on:** [Documentation/REBUILD_PLAN.md](Documentation/REBUILD_PLAN.md). Check its Status table, then continue with the first unticked task of the current phase. The newest entry in [Documentation/PROGRESS_LOG.md](Documentation/PROGRESS_LOG.md) says where the last session stopped.

## The team

The team are not very experienced programmers and rely on AI for most of the code. So:
- Explain what you did and why in plain language. Avoid jargon, or explain it when you need it.
- Write simple, readable code: clear names, short functions, comments that explain the physics or the reason behind a choice. No clever tricks.
- Verify your own work (tests, check, screenshots) before saying something works. Say clearly what you could not verify, such as how it feels to sail or how it sounds.
- Stop at the end of each phase so the team can play-test.

## Commands (run from the repo root)

| What | Command |
|---|---|
| Fast unit tests, after every change | `tools/test.sh` |
| Slow physics validation | `tools/test.sh validation` (or `tools/test.sh all`) |
| Only some tests | `tools/test.sh unit -gselect=buoyancy` |
| Does every script, scene and resource load? | `tools/check.sh` |
| Screenshot of the running game | `tools/screenshot.sh [res://scene.tscn] [out.png] [frames]`, then Read the PNG (default `.screenshots/latest.png`) |
| Look up the exact Godot 4.7 API | `tools/api_docs.sh` once, then grep `.godot_api/doc/classes/<Class>.xml` |
| Play the game / open the editor | `tools/play.sh` / `tools/edit.sh` (these open windows and are meant for the team) |
| Anything else with Godot | `tools/godot.sh <args>` |

Always go through these scripts instead of calling `godot` directly: the shell Claude Code uses is zsh without `~/.local/bin` on its PATH, and the scripts use the pinned Godot version. They exit non-zero on failure and keep logs in `.logs/`. `tools/screenshot.sh` opens a game window for a few seconds; that is expected.

## Godot 4, not Godot 3

A lot of GDScript online is Godot 3. Use Godot 4.7 syntax and APIs:
- Annotations `@export`, `@onready`, `@tool`; `await some_signal` (not `yield`); `some_signal.connect(callable)`; `super()`.
- `Node3D`, `CharacterBody3D`, `Transform3D`, `PackedVector3Array`, `instantiate()`, `FileAccess.open()`, `deg_to_rad()`, `randf_range()`. Not `Spatial`, `KinematicBody`, `Transform`, `PoolVector3Array`, `instance()`, `File.new()`, `deg2rad()`, `rand_range()`.
- Static types everywhere: `var speed_ms: float = 0.0`, `func drag(v: Vector3) -> Vector3:`, `for i: int in count:`, `Array[float]`, `Dictionary[String, float]`. **Untyped declarations are errors in this project.**
- Scene and resource files are text (`.tscn`/`.tres`, `format=3`). Editing them by hand is fine; run `tools/check.sh` afterwards.
- When unsure whether a method or property exists, look it up with `tools/api_docs.sh` instead of guessing.

## Architecture rules

1. `Game/sim/` is the physics: plain GDScript classes (RefCounted or Resource), **no Nodes and no engine physics bodies**, with the time step passed in. Tests run it headless; scene scripts copy its state onto the visuals. (Plan decision D2.)
2. The simulation drives the visuals. Nothing visual feeds back into the physics.
3. Tuning numbers live in config resources (`.tres` files in `Game/config/`), not in code.
4. SI units inside the simulation (m, s, kg, N, rad). Put the unit in the name when it isn't obvious: `speed_ms`, `area_m2`, `heading_deg`. Convert to km/h, knots and degrees only for display.
5. Conventions (plan decision D4):
   - +Y is up, the bow is local −Z (`Vector3.FORWARD`), starboard is local +X.
   - Compass: North is world −Z, East is world +X.
   - Wind is described by the direction it comes FROM.
   - Wind angles (TWA/AWA) are positive when the wind comes from starboard: `atan2(from_local.x, -from_local.z)`. Do not use `signed_angle_to` for this, because it is positive toward port.
   - Rake back makes the board head up and rake forward makes it bear away, on both tacks.
   - `tests/unit/test_engine_conventions.gd` pins the engine facts behind these rules. If a test and these rules disagree, stop and ask.
6. Physics interpolation is on. Move things in `_physics_process`, let cameras follow with `get_global_transform_interpolated()`, and call `reset_physics_interpolation()` after teleporting something.

## Workflow

- Work in small steps. After each change run `tools/test.sh`, and after scene or resource changes also run `tools/check.sh`. Never end a session with failing tests or a failing check.
- Visual change: run `tools/screenshot.sh` and look at the image before saying it works.
- Physics change: run `tools/test.sh validation` and update `Documentation/PHYSICS_SPEC.md`.
- New behaviour gets a new test. For a bug, first write a test that reproduces it.
- End of every session: add an entry at the top of `Documentation/PROGRESS_LOG.md` and tick the finished boxes in the plan.
- End of a phase: stop, give the team a plain-language summary and the play-test checklist from the plan, and suggest a commit.
- Git: work on a feature branch and make small commits with clear messages when the team agrees.
- Godot writes `.uid` files next to scripts and `.import` files next to assets. Commit them. Never commit `Game/.godot/`. Don't edit `Game/addons/gut/` (the GUT test framework, version 9.7.1).
- Moving or renaming files outside the Godot editor breaks `res://` references. Update the references and run `tools/check.sh`.
- `Legacy/` is read-only. Don't edit it, and don't copy code from it as-is: it is C# written for Unity's left-handed coordinates. Several of its sign-convention tables are wrong; see "Known legacy pitfalls" in the plan.
