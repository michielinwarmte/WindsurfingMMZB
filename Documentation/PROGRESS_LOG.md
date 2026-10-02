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

## 2 October 2026 - Session 31: first play-test, falls instead of capsizes, downwind speed, low-speed handling

**Phase:** 3 play-tested; the fixes are Phase 4 work (physics corrected at the source).

**Done:**
- The team's play-test said: the whole set capsized when heading up while planing (never happens; the sailor should go over the sail), half wind was faster than downwind (weird), and the board had "grip" at low speed. Each was measured in a scenario, traced to its mechanism and fixed. Spec section 17.7 has the full story with sources; section 16 has one tuning-log row per change.
- Falls: the sailor now goes over when the balance is lost (20 degrees of leeward heel = catapult, 25 degrees of windward heel = fell back). The board is then simulated alone, the rig in the water drags on the mast foot, and after 4 s the sailor waterstarts across the wind. On screen the rig pivots onto the water and the sailor flies over it; the HUD shows a countdown and R waterstarts at once. Why: the mast foot is a joint and feet cannot pull a board up, so a sail cannot roll a board; only a one-body model can.
- Downwind: the pilot and the player's auto-sheet now sheet for the most drive from the sail's own curves instead of a fixed 15 degrees. The polar is run from a planing start (new runner option `--twa2=<deg> --switch=<s>`): at 24 kt the fastest course is 105 to 120 degrees (52 km/h), 135 degrees gives 46 km/h; at 18 kt the beam reach still wins because a 6.5 m2 is marginal for 75 kg in 16 kt at the sail. The sail's lift curve was checked against wind-tunnel measurements of windsurf sails (Zhang et al. 2025, Mok et al. 2023) and kept.
- Low speed: the rounding up from rest is physical (no speed, no fin grip, the sail's centre of effort behind the hull's resistance). Beginner mode now does the sailor's part: auto-sheet on by default (W/S override it for 3 s), a heading hold with the rig when no key is held, speed-sensitive steering (less rake at speed) and an automatic ease when overpowered. Advanced mode keeps the raw controls and the consequences (spin-outs, catapults).
- Numerics: the heave damping is weighted by the wetted area share (a light board alone was undamped) and held to the momentum there is per step (a 9 kg board blew up dead downwind); the sail force is skipped when the board stands on its nose.
- New scenarios: `overpowered`, `bear_away`, `low_speed_turn`; new runner options `--twa2`, `--switch`; `--fall=<s>` for `tools/screenshot.sh`.

**Verified:**
- `tools/test.sh`: 103/103 (new: catapult and waterstart, auto-sheet with override, overpower ease, heading hold on both tacks, speed-sensitive rake, drive-maximising trim). `tools/check.sh`: 59 files, 0 failed.
- Scenarios: `overpowered` (catapult at 23 degrees of heel, the board stops level in a second, waterstart at 4 s), polars at 18 and 24 kt from a planing start, `low_speed_turn`, `bear_away`, dead downwind without NaN.
- Screenshots `.screenshots/fall_mid.png` and `fall.png`: the rig over the water and lying on it, the sailor beyond, the board upright.
- Not verified: how the beginner assists feel in play, whether 20 and 25 degrees are the right fall thresholds in play, the gybe on Space at speed (it may spin out), the planing onset (T2).

**Decisions:**
- Falls are an event in the one-body model (A-17), not a two-body sailor yet. If the team wants to feel the sailor being pulled before a catapult, the two-body sailor is the next step.
- Beginner assists are control, not physics; the physics is identical in both modes.
- The 6.5 m2 sail stays the default; a bigger sail is the team's equipment choice if they want more downwind speed in 18 kt.

**Next:** the team plays again (same checklist, plus: get catapulted on purpose in advanced mode, and bear away from a beam reach at speed in both modes). Then Phase 4 proper: planing onset (T2), steering with the sheet eased (T7), and the polar against GPS data if the team has any.

---

## 2 October 2026 - Session 30: Phase 2 (the headless simulation) and Phase 3 (the playable prototype)

**Phase:** 2 and 3, both done. Same day as Session 29, after the team asked for simulated physics instead of tuned limits (decision D8) and a playable demo.

**Done:**
- Built the whole simulation in `Game/sim/` (14 scripts, no Nodes): a rigid body with its own integrator, the mass model, buoyancy on a grid with a real rocker line, the hull (friction, wave hump, sideways drag, planing lift), the fin, the sail, the wind, the water, the sailor and the `WindsurferSim` that combines them; six config resources in `Game/config/`; 92 unit tests in 11 files; a headless scenario tool `tools/simulate.sh` that writes CSV telemetry; and an autopilot that plays the sailor in tests and scenarios.
- Every number comes from real equipment or real physics; nothing is capped to hit a target. The spec's new section 17 explains each choice; section 16 (the tuning log) has one row per change.
- The hard part was planing. The spec's Savitsky lift at one point made the board porpoise (bounce in pitch), and the sailor's reflexes were hiding it. Holding the sailor still in a scenario showed the board pitching to 24 degrees and capsizing on its own. The fix was physics, not a damper: the planing lift is now computed strip by strip with the slender-body theory of planing, which contains the pitch damping that the water gives a planing hull, matched to Savitsky's measured lift. Section 17.2 of the spec tells the story.
- Along the way, several real effects that were missing were added: the rig leaned to windward with the sailor, the sailor hanging back against the sail's pull, the sailor's legs as a suspension, the sailor's windage, the water's added mass in heave and pitch, flat-plate drag of the fin at large slip, a freeride rocker line, and a planing beam that follows the board's taper.
- Numbers (18 kt at 10 m, 16 kt at the sail): beam reach 35.9 km/h (19.4 kt), close-hauled 22.7 km/h at 52 degrees to the wind with 6.6 kt of upwind VMG, broad reach 21.6 km/h; steady, identical on both tacks; the board rounds up and stops when nobody steers; at rest it displaces 89.8 L and floats level.
- Phase 3, the playable prototype: an input map in `project.godot` (W/S sheet, A/D steer, Q/E rake, Space tack or gybe, T auto-sheet, Tab mode, 1 to 4 cameras, R reset, Esc pause, F1 panel); `windsurfer/windsurfer.tscn`, a node that owns the simulation, steps it every physics tick and copies the state onto simple shapes (a box board with an orange nose, a fin, a mast, a sail that turns with the sheet, the rake and the rig lean, a boom, and a capsule for the sailor that leans and steps back as the simulated sailor does); `windsurfer/player_controller.gd` with a beginner mode (A/D turn left and right on the screen on either tack, automatic balance) and an advanced mode (Q/E rake, A/D weight), both with W/S sheeting, an optional auto-sheet and a tack or gybe on Space; `camera/camera_rig.gd` with follow, orbit (right mouse button to turn, wheel to zoom), top-down (bow up) and free (spectator) cameras on the board's interpolated transform; `ui/hud.gd` with a one-line strip, a detail panel (F1), a wind rose and the key help; `world/water.gdshader`, a flat sea with a 5 m grid so that speed shows; `main.tscn` and `main.gd` that tie it together, with `--camera=`, `--autopilot=1` and `--hud=0` options for screenshots. The old FBX models stay in `assets/models/` for Phase 6; the prototype uses plain shapes.

**Verified:**
- `tools/test.sh`: 92/92 pass in about 8 s. `tools/check.sh`: 50 files, 0 failed.
- Scenarios `beam_reach`, `close_hauled`, `broad_reach` on both tacks, `fixed_controls`, and `beam_reach --freeze=40` (sailor held still fore and aft): all steady.
- Phase 3: `tools/test.sh` 97/97 (five new controller tests: sheet pace, screen-relative steering on both tacks, advanced mode, tack and gybe on Space, a stuck manoeuvre is abandoned); `tools/check.sh` 56 files, 0 failed; screenshots of all four cameras with the autopilot sailing (`tools/screenshot.sh res://main.tscn .screenshots/cam1.png 360 --camera=1 --autopilot=1`, and 2 to 4), looked at and corrected (help line cut off, free camera starting inside the board).
- Not verified: how it feels to sail with the keys (nobody has played it yet; the autopilot sailed for the screenshots), whether the tack and gybe on Space carry the board through the wind in play, the planing-onset speed (check T2), steering with the sheet eased (part of T7), and anything on waves.

**Decisions:**
- The sailor's reflexes (balance, hang-back, legs, pitch reflex) live in the simulation and stay on in every control mode; the player gives intentions. A windsurfer cannot be balanced by someone holding still (spec 17.3).
- The planing model is the strip model of spec 17.2; the point model of section 5 is superseded.
- Added mass, legs and the other additions are physics the spec had left out, not tuning; recorded in the tuning log with their sources.

**Next:** the team play-tests the prototype (checklist in the plan, Phase 3). Then Phase 4, validation and physics fixes at the source, starting with what the play-test turns up and with checks T2 and T7.

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
