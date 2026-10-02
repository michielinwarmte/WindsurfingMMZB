# Rebuild Plan: Windsurfing Simulator in Godot 4.7

Written 28 September 2026 (Session 28), for the AI sessions doing the work and for the MMZB team reviewing it. The rules and commands are in [CLAUDE.md](../CLAUDE.md); this file says what to build and in which order.

## How to use this plan

- Work through the phases in order. Within a phase, work top to bottom and tick a box (`- [x]`) only when the task is done **and verified**.
- Every phase ends with a **Stop**: give the team a plain-language summary and the play-test checklist, suggest a commit, and wait for their go-ahead before starting the next phase.
- Record every session at the top of [PROGRESS_LOG.md](PROGRESS_LOG.md).
- If the plan turns out to be wrong somewhere, change it, write down why in the progress log, and mention it at the next Stop.

## Status

| Phase | What | Status |
|---|---|---|
| 0 | Preparation: Godot installed, project skeleton, tools, first tests | ✅ Done (Session 28) |
| 1 | Physics spec from the Unity version | ✅ Done (Session 29) |
| 2 | Core simulation, headless and tested | ✅ Done (Session 30) |
| 3 | Playable prototype on flat water | ✅ Done (Session 30), play-tested in Session 31: falls, downwind trim and beginner assists added |
| 4 | Autopilot, validation suite and tuning | ⬜ Next |
| 5 | Waves and ocean | ⬜ |
| 6 | Rig visuals: board, sail, boom, mast | ⬜ |
| 7 | Environment and effects | ⬜ |
| 8 | Audio | ⬜ |
| 9 | Gameplay: racing | ⬜ |

## What we are building

The same game as the Unity version:
- A physics-first 3D windsurfing simulator: apparent wind, sail lift and drag, fin, hull drag, planing and buoyancy.
- Real windsurfing controls: sheet in and out, mast-rake steering, tacks and gybes. Beginner assists, plus an advanced mode with full manual control.
- Third-person camera and a telemetry HUD.
- Free sailing on about 1 km² of open water first, then slalom racing against AI opponents. Single-player first, multiplayer later.

## Key decisions

### D1. Godot 4.7.2, GDScript, Forward+ renderer
Standard build, not .NET. All code is statically typed; untyped declarations are errors. GDScript is Godot's best-supported language, it is readable for beginners, and the AI writes it well when held to Godot 4 syntax. Forward+ gives the ocean the best look.

### D2. We own the physics: a pure-GDScript rigid-body simulation
The board, with the sailor and rig on it, is simulated by our own code in `Game/sim/`, not by Godot's `RigidBody3D` or Jolt. The simulation is made of plain classes (RefCounted or Resource) with no Nodes, and `step(dt, controls)` advances it. In the game, the windsurfer node copies the simulated position and rotation onto the visuals every physics tick.

Why:
- Tests run the real simulation headless, far faster than real time, so the AI can tune the physics against numbers instead of guesses.
- It is deterministic: the same inputs give the same result, in tests and in the game.
- No hidden engine behaviour. In Unity the tuning got tangled up with PhysX damping and solver details.
- The Unity version already calculated every force itself; the engine only moved the body. We only need to add that last step.

What it costs:
- We write a small 6-degrees-of-freedom integrator (position, velocity, orientation, angular velocity, inertia) with fixed substeps. It needs its own unit tests.
- Collisions with islands and buoys are simple custom checks (Phases 7 and 9). Godot physics can still be used for things that don't move the board, such as camera collision or trigger areas.

### D3. SI units, tuning values in resource files
- Inside the simulation: metres, seconds, kilograms, newtons, radians. Convert to km/h, knots and degrees only for display, test names and messages. Put the unit in the name when it isn't obvious: `speed_ms`, `area_m2`, `mass_kg`, `heading_deg`.
- Every tuning number lives in a config Resource (for example `class_name BoardConfig extends Resource` with commented `@export` variables), saved as a `.tres` file in `Game/config/`. The team can change values in the Godot inspector, and tests load the same files.

### D4. Coordinate and sign conventions (fixed, and enforced by tests)

| Thing | Convention |
|---|---|
| Up | +Y |
| Bow (forward) | local −Z (`Vector3.FORWARD`) |
| Starboard (right) | local +X |
| Compass | North = world −Z, East = world +X. Headings are compass bearings in degrees, clockwise from North. |
| Wind direction | where the wind comes FROM, as a compass bearing (sailors' convention) |
| True and apparent wind angle (TWA, AWA) | angle between the bow and where the wind comes from: 0° = head to wind, ±180° = dead downwind. **Positive = wind from starboard.** In the board's local frame: `atan2(from_local.x, -from_local.z)` |
| Tack | Starboard tack = wind from starboard (AWA > 0), sail on the port side. Port tack is the mirror image. |
| Mast rake | positive = raked back, toward the tail. Rake back makes the board head up (turn toward the wind); rake forward makes it bear away. The same on both tacks. |
| Steering keys | A turns left and D turns right on screen, on either tack. The controller converts that to rake and weight shift. |

The Unity docs have some of these backwards in their tables (the Unity code was right). Derive conventions; don't copy them. `tests/unit/test_engine_conventions.gd` pins the Godot facts, and Phase 2 adds behaviour tests for each row.

### D5. One wave function for physics and rendering
The same Gerstner wave parameters (one Resource) feed both the GDScript height query used for buoyancy and the ocean shader. The formulas exist twice, in GDScript and in the shader, each with a comment pointing to the other. Phase 5 adds tests for the GDScript side.

### D6. The simulation drives the visuals, never the other way round
Visual scripts read the simulation state (sail angle, forces, planing ratio and so on). Nothing visual feeds back into the physics.

### D7. Verify, don't assume
- Physics: every behaviour has a test. A physics check passes when the simulation falls in the real-world range for the right physical reason (see D8).
- Visuals: take a screenshot with `tools/screenshot.sh` and look at it before saying it works.
- Tell the team clearly what could not be verified.

### D8. The physics is simulated, not tuned (added in Session 29)
Real windsurfing physics is the core mechanic of the game. Every force comes from a physical model with real-world coefficients and real equipment dimensions. How fast the board goes, which point of sail is fastest, when it starts planing and how it reacts to the rig are outcomes of the simulation, never numbers we choose: there are no behaviour targets, no speed caps, no artificial torques and no "feel" constants. Validation compares the simulation with what real windsurfing kit does (a planing freeride board in 15 kt goes faster than the wind, fastest on a broad reach, planes from about 15 km/h, points about 45° to the wind). When a check fails we look for the physical cause (a coefficient that does not match real equipment, a missing effect, a force applied at the wrong point) and fix the model, writing the real-world source of the fix in the spec's tuning log. The Unity version is a list of lessons, not a reference for behaviour. Where real life is unplayable in a game (balance reflexes, falling in), the sailor model may help the player in beginner mode; such help is explicit, documented in the spec and switchable off. The decisions this replaced are in [PHYSICS_SPEC.md](PHYSICS_SPEC.md) section 15.

## Target project layout

```
Game/
├── project.godot, main.tscn, main.gd
├── sim/              # physics model: no Nodes, no rendering, runs headless in tests
├── config/           # tuning values as .tres files (board, sail, fin, sailor, water, wind)
├── windsurfer/       # windsurfer scene: runs the sim, input, visuals, sound
├── world/            # water, sky, islands, wind visuals
├── camera/
├── ui/               # HUD, telemetry
├── assets/           # models, textures, sounds (our own, see the Phase 6 notes)
├── tests/unit/       # fast tests, run after every change
├── tests/validation/ # slow physics validation runs
├── dev/              # developer tools (screenshot helper, project check, sim scenarios)
└── addons/gut/       # GUT test framework 9.7.1 (vendored, don't edit)
```

Change the layout when there is a good reason, and update this section when you do.

---

## Phase 0: Preparation ✅ (Session 28)

- [x] Moved the Unity project, old docs, README and CONTRIBUTING to `Legacy/` with `git mv` (history kept).
- [x] Installed Godot 4.7.2 with `tools/install_godot.sh` (official build, checksum verified, no sudo needed) and added an app-menu entry.
- [x] Created the Godot project in `Game/`: Forward+, untyped code is an error, physics interpolation on, 1280×720 window.
- [x] Added the GUT 9.7.1 test framework with `unit` and `validation` suites, run by `tools/test.sh`.
- [x] Added `tools/check.sh` (does everything load?), `tools/screenshot.sh` (lets the AI see the game), `tools/api_docs.sh` (exact Godot API), and wrappers for play, edit and godot.
- [x] Added a placeholder main scene with sky, a water plane, and the old board and sail models. Screenshot checked.
- [x] Installed the godot-tools extension in VS Code and pointed it at the installed Godot.
- [x] Wrote CLAUDE.md, README.md and this plan.

## Phase 1: Physics spec from the Unity version ✅ (Session 29)

**Goal:** one engine-neutral document, `Documentation/PHYSICS_SPEC.md`, that describes every force model we will build, in D4 conventions and with its numbers. No code yet.

**Read** (paths under `Legacy/WindsurfingGame/Assets/Scripts/` unless noted):
- `Physics/Core/`: `PhysicsConstants.cs`, `Aerodynamics.cs`, `Hydrodynamics.cs`, `SailingState.cs`
- `Physics/Board/`: `AdvancedSail.cs`, `AdvancedFin.cs`, `AdvancedHullDrag.cs`, `BoardMassConfiguration.cs`, `ApparentWindCalculator.cs`
- `Physics/Buoyancy/AdvancedBuoyancy.cs`
- `Physics/Water/GerstnerWave.cs`, `Physics/Water/WaterSurface.cs`, `Environment/WindSystem.cs`
- `Player/AdvancedWindsurferController.cs` (control modes, assists, how input becomes rake and sheet)
- `Legacy/Documentation/`: `PHYSICS_DESIGN.md`, `PHYSICS_VALIDATION.md`, `KNOWN_ISSUES.md`, and `PROGRESS_LOG.md` Sessions 12 to 26 (what broke and why)

**Tasks:**
- [x] For each model, write down its purpose, formula, inputs and units, coefficients and values, where the force acts, and the source (legacy file and line, or literature). The models: apparent wind; sail lift and drag (coefficient curves, aspect ratio, camber, centre of effort); sail side and tacking; rake steering; fin (lift, drag, stall, induced drag); hull drag, displacement lift and Savitsky planing; buoyancy (hull shape, rocker, taper, volume weights); damping; mass, inertia and the sailor's centre-of-mass shift; wind (gusts, shifts, height gradient); Gerstner waves.
- [x] Translate every direction and sign into D4 conventions, and note each place where Unity's left-handed frame changes a sign.
- [x] List every stabiliser or fudge in the legacy code, with a recommendation (keep, drop or re-evaluate) and the reason. Known ones:
  - rake steering base torque (`150 × rake`) and the speed term
  - high-speed steering scale-down (to 0.3 between 15 and 25 kt)
  - speed-dependent angular damping (up to ×5)
  - pitch stabilisation that fades out with heel
  - planing lift capped at 85 % and displacement lift capped at 30 % of weight
  - submersion penalties: planing off above 50 % submersion, underwater drag up to ×5, the 12× submersion drag multiplier
  - centre of effort height set to 0
  - planing lift applied at the centre of mass
  - the high-speed sail downforce (added in Session 24, removed in Session 26)

  Default: start without the fudge, and add it back only when a Phase 4 test shows it is needed, with a note saying why.

  Session 29 note: this list was written from the legacy docs. [PHYSICS_SPEC.md](PHYSICS_SPEC.md) section 12 corrects it against the code that actually ran (the final rake torque is 0.3 × sail force + 200 to 350 N·m + 25 × speed, the high-speed scale-down goes to 0.5 at 30 kt, the planing lift was a speed ramp rather than Savitsky, and the played cap was 0.4 × 0.15 of the weight) and adds 27 more items, F-10 to F-36.
- [x] Resolve the legacy contradictions listed under "Known legacy pitfalls" below, and write down the resolution.
- [x] Write a validation targets table (what Phase 4 will test), with a source or reason for every number.
- [x] Pick a default configuration: board (volume, length, width, mass), sail (area, luff and boom length), fin (area, aspect ratio), sailor mass. The legacy config says 120 L, 2.5 m × 0.6 m, 6 m² sail, 75 kg sailor plus 15 kg of equipment. The old board model measures 2.28 m × 0.80 m. Choose, and say why.

**Done when:** PHYSICS_SPEC.md is complete enough that Phase 2 can be written from it without opening `Legacy/` again.
**Stop:** show the team the targets table and the open questions at the end of this plan, and get their answers. (Session 29: settled under D8, see PHYSICS_SPEC.md sections 14 and 15; the team asked for a playable demo without a stop here.)

## Phase 2: Core simulation, headless and tested

**Goal:** `Game/sim/` can simulate a windsurfer on flat water from code, with unit tests for every piece. No scenes or visuals yet.

**Tasks:**
- [x] Config resources (`BoardConfig`, `SailConfig`, `FinConfig`, `SailorConfig`, `WaterConfig`, `WindConfig`) and their default `.tres` files, from the spec.
- [x] Rigid-body state and integrator: 6 degrees of freedom, inertia tensor in the body frame, forces and torques applied at points (for example `add_force_at(world_point, force)`), fixed substeps (start with 4 per 60 Hz tick and make it a setting). Tests:
  - free fall matches ½·g·t²
  - a force through the centre of mass causes no rotation
  - an off-centre force gives the expected torque
  - a torque-free spin keeps its angular momentum
  - identical inputs give identical results
- [x] Environment interfaces: `WindField` (constant wind for now) and `WaterSurface` (flat for now; height, normal and water velocity at a point). The simulation only talks to these, so Phase 5 can add waves without touching it.
- [x] Force models one at a time, each with tests, in this order: buoyancy, then hull drag and planing lift, fin, sail and apparent wind, rake steering, and the sailor's weight and centre-of-mass shift. Example tests:
  - At rest, the submerged volume equals total mass ÷ water density (±2 %), level in pitch and roll.
  - Tilted and released, the board rights itself.
  - Apparent wind is correct for a few hand-calculated cases, and the AWA sign follows D4.
  - With wind from starboard the sail sits to port, and the other way round.
  - Fin: no side force at zero slip; the force grows with slip and stalls past the stall angle; induced drag grows with the square of lift.
  - Savitsky planing lift depends on speed and trim, not on how deep the board sits (the Unity "trampoline" lesson).
- [x] `WindsurferSim`, which combines everything. `step(dt, controls)` takes controls for sheet (0 to 1), rake (−1 to 1) and weight shift, and a `Telemetry` snapshot reports speed, heading, TWA, AWA, sail angle, forces, submersion, planing ratio, pitch and roll.
- [x] Behaviour tests on flat water with fixed controls:
  - from standstill on a beam reach, the board sets off and accelerates
  - head to wind, it stops making way
  - rake back heads up and rake forward bears away, on both tacks
- [x] `tools/simulate.sh <scenario>`: runs a named scenario headless and writes CSV telemetry to `.sim_output/`, so the AI can analyse numbers and draw charts. Scenarios are GDScript files in `Game/dev/scenarios/`.

**Done when:** `tools/test.sh` and `tools/check.sh` are green, and the unit tests run in under 10 seconds.
**Stop:** plain-language summary of what the simulation can do, with a few numbers (speed on a beam reach, how deep the board floats at rest).

## Phase 3: Playable prototype on flat water

**Goal:** the team can sail. Simple visuals are fine.

**Tasks:**
- [x] Input map in `project.godot`: sheet in and out (W/S), steer left and right (A/D), fine rake (Q/E), tack or gybe (Space), toggle the HUD (F1), camera modes (1 to 4), reset (R), pause (Esc).
- [x] Windsurfer scene: a node that owns a `WindsurferSim`, steps it in `_physics_process` and copies its transform. Simple visuals: the old models in a wrapper scene that corrects their orientation (see the Phase 6 notes), or boxes if that is quicker. The sail turns with the simulated sail angle and rake.
- [x] Controller: a beginner mode (A/D turn relative to the screen, sheet assist) and an advanced mode (direct rake and sheet), based on the legacy `AdvancedWindsurferController`.
- [x] Cameras: follow (default), orbit, top-down and free. Smooth, and following the interpolated transform.
- [x] Telemetry HUD on F1: speed in km/h and knots, heading, TWA and AWA, sail angle, sheet, rake, planing %, submersion % and the main forces. Plus a wind indicator.
- [x] Main scene: flat water with a grid or texture so you can see the speed, a sky, a sun, and wind from a fixed direction.
- [x] Take a screenshot of each camera mode and check it.

**Done when:** tests and the check are green and the screenshots look right.
**Stop:** play-test checklist for the team:
- Can you start from standstill, sheet in and sail away on a beam reach?
- Does A/D steer the way you expect, on both tacks?
- Can you tack (Space) and get going on the other side?
- When you go fast, does the board plane (planing % rises, and it feels faster and lighter)?
- Is anything on the HUD confusing?

## Phase 4: Autopilot, validation suite and tuning

**Goal:** check the simulated physics against real-world windsurfing data, fix what the checks expose at its physical source, and keep it checked (D8).

**Tasks:**
- [ ] An autopilot for tests: holds a chosen TWA using rake (a simple PID controller) and trims the sheet for best speed. Phase 9 reuses it for the AI opponents.
- [ ] Validation tests in `tests/validation/`. Delete `test_validation_placeholder.gd` when you start.
  - Polar sweep at 15 kt of wind: steady speed at TWA 40, 45, 60, 75, 90, 105, 120, 135, 150 and 165°.
  - No-go zone: no lasting progress upwind closer than about 35 to 40° TWA.
  - Upwind: at about 45° TWA the board keeps moving with positive VMG, on both tacks.
  - Planing starts between 15 and 17 km/h of boat speed.
  - Top speed and fastest point of sail fall in the real-world ranges of PHYSICS_SPEC.md section 14 (faster than the wind, fastest on a broad reach). If not, the model is wrong, not the range.
  - Stable above 20 kt of boat speed: pitch and heave oscillation stay below a threshold (no porpoising), submersion stays steady (no trampoline effect), and the board doesn't fly off at 45+ km/h.
  - Recovers from a nose-dive: submerged at speed, it slows down and floats back up.
  - Symmetry: port and starboard tack give the same speeds (±2 %).
- [ ] When a check fails, find the physical cause (a coefficient that does not match real equipment, a missing effect, a force applied at the wrong point) and fix the model; never adjust a number to hit a range (D8). Log every change, with its real-world source, in PHYSICS_SPEC.md section 16.
- [ ] Save a polar diagram of the sweep in `Documentation/` (a chart, or at least a table the test prints).
- [ ] Keep `tools/test.sh validation` under about 2 minutes: flat water, and the shortest settling times that still give steady numbers.

**Done when:** the validation suite is green.
**Stop:** the team play-tests the feel: the Phase 3 checklist, plus upwind sailing, fast reaching and bearing away.

## Phase 5: Waves and ocean

**Goal:** the board floats on the waves you see.

**Tasks:**
- [ ] A Gerstner `WaveField` that implements the `WaterSurface` interface: height, normal and orbital velocity at a world point. It uses a fixed-point solve for the horizontal displacement, as the legacy `WaterSurface.cs` did. The wave set is one Resource, and the wave directions follow the wind.
- [ ] Unit tests: flat when the amplitude is 0; heights match hand-calculated values at sample points; heights stay within the total amplitude; the pattern repeats with the wave period.
- [ ] An ocean shader using the same parameters: vertex displacement with analytic normals, depth colour, Fresnel sky reflection, sun glint, and foam on the crests. The legacy `OceanWater.shader` has ideas, but it was never compiled, so treat it as notes rather than code.
- [ ] A water mesh that follows the camera, snapped to a grid so the waves don't slide, dense close to the camera, with its far edge hidden in fog.
- [ ] Run validation again with gentle waves. If the results change a lot, find out why (buoyancy sampling, damping) before tuning.

**Done when:** tests and validation pass on flat and wavy water, and a screenshot shows the board sitting on the visible wave surface, not above it or clipping through.
**Stop:** team check.

## Phase 6: Rig visuals

**Model notes (measured in Session 28):**
- `board.fbx` has a 2.28 m long mesh along the model's X axis, not −Z, and its origin is not at the centre. It also contains a stray camera and refers to a missing product-photo texture ("Starboard … iSonic … .jpg").
- `sail.fbx` has a sail cloth 5.08 m tall and 2.8 m long along +X from the mast at the origin, and a boom mesh that is fine. The mast is a curve without faces (Godot reports `surfaces.is_empty()` on import), and the file refers to a missing "Severne … .png".
- Godot prints errors about those missing textures when it imports the files. They are harmless. Don't add the brand images (copyright and trademarks); make our own textures.

**Tasks:**
- [ ] Clean up the models in Blender (installed at `/usr/bin/blender`): remove the camera and the texture references, set a sensible origin (for example the mast foot; pick one and document it), point the bow to −Z, and export as `.glb` into `Game/assets/models/`. If that is too fiddly, wrap the FBX in a scene with a correcting transform.
- [ ] A procedural mast (a cylinder), and a boom that follows the sail angle and rake.
- [ ] Sail cloth deformation from the simulation: belly to leeward, twist, and flutter when luffing. A vertex shader driven by uniforms is the preferred way.
- [ ] A debug view you can toggle, showing force vectors (sail, fin, buoyancy, drag).
- [ ] A placeholder sailor (a capsule) that changes stance. A real rigged character comes later.

**Done when:** screenshots from several angles on both tacks show the sail on the leeward side and the boom where the physics says it is.
**Stop:** team check.

## Phase 7: Environment and effects

- [ ] Sky (procedural or physical), sun and horizon fog.
- [ ] Distant islands (simple meshes) with a simple custom collision, so the board stops at the shoreline.
- [ ] Spray from the rails that grows with speed and planing (GPUParticles3D), foam and wake behind the tail, and a splash on landing.
- [ ] Wind visuals: gust patches on the water, and a flag or streamers.

**Done when:** screenshots look right and the game holds 60 fps with room to spare on the team's PCs (the RTX 3080 Ti machine at least).
**Stop:** team check.

## Phase 8: Audio

- [ ] Procedural sounds, as in the legacy `ProceduralAudioClips`: generate looping noise buffers (`AudioStreamWAV`) at startup, shape them with audio bus effects (filters), and drive volume and pitch from the simulation.
- [ ] Wind ambience from the apparent wind, hull lapping versus planing hiss, splashes on impacts, and sail flapping when luffing and during tacks.
- [ ] A volume setting.

**Done when:** unit tests confirm the logic (volume and pitch against speed). The AI can't listen, so the team checks the sound by ear.
**Stop:** team check.

## Phase 9: Gameplay: racing

- [ ] Buoys and a slalom course, with a start line and a countdown.
- [ ] Timer, splits and a results screen.
- [ ] AI opponents: the Phase 4 autopilot plus a simple course-following layer.
- [ ] Menus: start, pause and settings (control mode, volume).

**Done when:** you can sail a full race against three AI opponents.
**Stop:** team check.

## Later (not planned yet)

Multiplayer, a rigged sailor, more boards and sails, exported builds for Windows and Linux (needs Godot's export templates), and maybe a web build (possible because we use GDScript).

---

## Known legacy pitfalls (read before Phase 1)

1. Some sign tables in the legacy docs are wrong. In `PHYSICS_VALIDATION.md` the AWA and sail-side tables have port and starboard swapped (the code and its comments use AWA > 0 = wind from starboard). The testing checklist there says "rake back = bear away", but the code correctly makes rake back head up.
2. Unity is left-handed with +Z forward; Godot is right-handed with −Z forward. Cross products and signed angles flip. Don't copy vector maths; derive it again using D4, and test it.
3. The Unity physics collected many stabilisers (listed in Phase 1). Each one hints that something else was off, so prefer fixing the cause.
4. Planing lift must not depend on how deep the board sits. That dependency caused the "trampoline" oscillation.
5. Viscous damping belongs on vertical motion only. Applying it horizontally killed the forward speed.
6. Beam-reach submersion at low speed was never solved.
7. "Beam reach is the fastest point" (old README) conflicts with the Session 25 notes, which say a broad reach should be faster. Under D8 the simulation decides; real polars say broad reach.
8. At rest, a 120 L board carrying 90 kg is about 73 % submerged (90 kg ÷ 1025 kg/m³ ≈ 88 L). That is Archimedes, not a bug. The Unity "displacement lift" was partly added to fight it, so re-evaluate it.
9. The Session 27 code (ocean shader, sail deformer, spray, audio) was never compiled or played. Use it for ideas only.

## Former open questions (settled in Session 29 under D8)

The plan used to ask the team four questions here: the top speed, the fastest point of sail, the default equipment and the control modes. They are not questions any more. The top speed and the fastest point of sail are whatever the simulation gives (real life: faster than the wind, fastest on a broad reach); the equipment is a real, common freeride setup (120 L board, 6.5 m² sail, 38 cm fin, 75 kg sailor); the game has a beginner and an advanced mode. The decisions, with reasons, are in [PHYSICS_SPEC.md](PHYSICS_SPEC.md) section 15.

## Tooling notes (from Session 28)

- **Tests** use GUT 9.7.1. A test file `extends GutTest`, its name starts with `test_`, and so do its test functions. Useful asserts: `assert_eq`, `assert_almost_eq` (floats and vectors), `assert_true`, and `pending("reason")`. Run one file with `tools/test.sh unit -gselect=<part of the file name>` and one test with `-gunit_test_name=<part of the test name>`. Simulation tests shouldn't need the scene tree. When a test does need nodes, use `add_child_autofree(node)` and `await wait_physics_frames(n)`.
- **`tools/test.sh` and `tools/check.sh` run an import first**, so new `class_name` scripts and new assets are picked up. The import log is in `.logs/import.log`.
- **`tools/check.sh`** loads every `.gd`, `.tscn`, `.tres` and `.res` outside `addons/`. It can't see shader errors, because shaders only compile when drawn; `tools/screenshot.sh` reports those (`SHADER ERROR`).
- **`tools/screenshot.sh`** starts the real game with the `DevCapture` autoload (`Game/dev/dev_capture.gd`), which saves a PNG after N frames and quits. It runs at a fixed 60 fps, so frames equal game time (60 frames = 1 s). A window opens briefly, and audio is off.
- **`tools/api_docs.sh`** writes the exact Godot 4.7.2 class reference to `.godot_api/`.
- **VS Code:** GDScript autocomplete and errors in VS Code come from the Godot editor's language server, so open the editor (`tools/edit.sh`) while editing in VS Code.
- **Godot for other team members:** on Linux run `tools/install_godot.sh`. On Windows or macOS, install Godot 4.7.2 (standard, not .NET) from godotengine.org, then either open `Game/project.godot` in it or set `GODOT` to its path and use `tools/*.sh` from Git Bash.
