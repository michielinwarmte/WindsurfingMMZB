# 🏄 Windsurfing Simulator

A physics-first 3D windsurfing game by the MMZB team, built with **Godot 4.7** and GDScript.

![Godot](https://img.shields.io/badge/Godot-4.7.2-478cbf?logo=godotengine&logoColor=white)
![GDScript](https://img.shields.io/badge/GDScript-typed-478cbf)
![Status](https://img.shields.io/badge/Status-Rebuilding%20in%20Godot-orange)

## Status

In September 2026 we restarted the game from scratch in Godot. The Unity version (Sessions 1 to 27) is kept in [`Legacy/`](Legacy) for reference; its physics work and lessons learned feed the new version.

The step-by-step plan, with its current status, is in [Documentation/REBUILD_PLAN.md](Documentation/REBUILD_PLAN.md). Phase 0 (setup) is done; next is Phase 1, writing the physics spec.

## What we are building

- **Real sailing physics:** apparent wind, sail lift and drag, fin, hull drag, planing (Savitsky) and buoyancy (Archimedes).
- **Real windsurfing controls:** sheet in and out, steering by mast rake, tacks and gybes, with beginner assists and an advanced manual mode.
- **Free sailing first, then slalom racing** against AI opponents.

## Quick start

### Linux

```bash
git clone https://github.com/michielinwarmte/WindsurfingMMZB.git
cd WindsurfingMMZB
tools/install_godot.sh   # installs Godot 4.7.2 for your user (no sudo), once
tools/edit.sh            # open the project in the Godot editor
```

After installing you can also start "Godot Engine 4.7.2" from your app menu and open `Game/project.godot`.

### Windows or macOS

Install **Godot 4.7.2, the standard build (not .NET)** from [godotengine.org](https://godotengine.org/download/archive/), then open `Game/project.godot` in it. To use the `tools/*.sh` scripts from Git Bash, set the `GODOT` environment variable to the Godot executable.

## Everyday commands

Run these from the repo root.

| What | Command |
|---|---|
| Play the game | `tools/play.sh` |
| Open the editor | `tools/edit.sh` |
| Run the tests (after every change) | `tools/test.sh` |
| Run the slow physics validation | `tools/test.sh validation` |
| Check that every script and scene loads | `tools/check.sh` |
| Save a screenshot of the game | `tools/screenshot.sh` (writes `.screenshots/latest.png`) |

In the editor, the **GUT** panel at the bottom also runs the tests.

## Working with AI

Most of the code is written with Claude. The setup is made so the AI can check its own work: it runs the tests, loads every file, and takes and views screenshots.

- [CLAUDE.md](CLAUDE.md) holds the rules and commands every AI session follows.
- [Documentation/REBUILD_PLAN.md](Documentation/REBUILD_PLAN.md) says what to build next.
- [Documentation/PROGRESS_LOG.md](Documentation/PROGRESS_LOG.md) records what each session did.

To continue, start a Claude Code session in this folder and ask it, for example: *"Read CLAUDE.md and the rebuild plan, then do the next phase."* It stops at the end of each phase so you can play-test.

## Project structure

```
WindsurfingMMZB/
├── CLAUDE.md            # rules for AI sessions
├── Documentation/       # plan, progress log, (soon) physics spec
├── Game/                # the Godot project (open Game/project.godot)
│   ├── main.tscn        # placeholder scene until Phase 3
│   ├── assets/models/   # board and sail models carried over from Unity
│   ├── dev/             # developer helpers (project check, screenshots)
│   ├── tests/           # unit/ (fast) and validation/ (slow physics runs)
│   └── addons/gut/      # GUT test framework
├── tools/               # scripts: install Godot, play, edit, test, check, screenshot
└── Legacy/              # the frozen Unity version, reference only
```

## Controls (planned, as in the Unity version)

| Key | Action |
|---|---|
| W / S | Sheet in / out |
| A / D | Steer left / right |
| Q / E | Fine mast rake |
| Space | Tack or gybe |
| F1 | Telemetry HUD |
| 1 to 4 | Camera modes |

## License

The original README says MIT License, but the repository has no LICENSE file yet. The GUT test framework in `Game/addons/gut` is MIT licensed (see its `LICENSE.md`).

## Team

**MMZB Development Team**
