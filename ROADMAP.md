# Roadmap

What comes after version 0.1.0, and who does what. **The overview below is the short version.** The sections further down list every open item once, with its details, so this is the one place to look. When an item is done it moves to [CHANGELOG.md](CHANGELOG.md).

Last update: 26 October 2026 (Session 56: GP0 measured). An AI session reads this file after [CLAUDE.md](CLAUDE.md); the newest entry in [Documentation/PROGRESS_LOG.md](Documentation/PROGRESS_LOG.md) says where the last session stopped.

**GP0's code is not on `main` yet** (26 October 2026): `tools/push_check.sh`, `tools/play_push.sh`, `Game/dev/run_push.gd`, the F1 panel's last-fall table (`Game/ui/fall_watch.gd`), `PlayerController.pilot_overrides` and the tests `test_fall_watch.gd` and `test_push_warning.gd` live on the branch `gp0/measure` (pushed, not merged). This documentation already describes them and came to `main` ahead of the code, so nobody misses the findings. Check that branch out (`git fetch`, `git checkout gp0/measure`) to run them or to build on GP0 (GP1, GP2, GP10). Remove this note when the branch is merged.

## Overview

**Where we are.** Version 0.1.0 is out (21 October 2026): real windsurfing physics, Lake Silvaplana in the Maloja wind, and races against up to 20 AI boards. Next is **version 0.2: the player becomes the sailor.** In 0.1 the autopilot sails and the player mostly watches. In 0.2:

| You do | What happens |
|---|---|
| Nothing | The board sails itself, safely. Easy to just go |
| Push with W/S (package A) | The sailor holds more power: faster, until a gust is too much and you catapult or spin out. Ease off before the gust |
| Move the mouse (package B, an experiment) | Sideways is the rail, forward and back the back foot. Find the fastest angle and hold it |

Real physics only: every fall comes from the simulation, and you read the edge from the board, the spray and the sound, not from numbers on the screen.

### The next steps, in order

| | What | Who | Items |
|---|---|---|---|
| 1 | Answer the gameplay questions: where the push dial sits, whether it springs back, how fast "let go" sails, how the mouse behaves | Max and Tarpie | GD1 to GD7 |
| 2 | **Done (Session 56):** measured whether pushing, the rail and the back foot pay off, and where the edge is ([the report](Documentation/reports/gameplay/gp0_measure.md)) | An AI session | GP0 |
| 3 | Package A: the push dial, with the fin's sound, the spray and a HUD without trim numbers | An AI session | GP1, SO1, GR1, UI1 |
| 4 | Package B: the experiment with the rail and the back foot on the mouse | An AI session, then Max plays it | GP2 |
| 5 | A real spin-out, gusts you can see on the open water, and the two reviews of 0.1's physics | Michiel | PH6, PH7, PH1, PH2 |
| 6 | Tune it by playing, add a time trial so you see yourself get faster, release 0.2 | The team | GP3, GP4, PR3 |

Alongside, at any time: the small fixes that are ready (RA2, SO3, UI3, UI4, MA2, TE1) and the play-tests left over from 0.1 (RA1, MA1, GR6, SO4).

### The versions at a glance

| Version | What it brings |
|---|---|
| **0.2** (43 items) | The push dial and the mouse experiment; the feedback (the fin's sound, the spray, gusts you can read, a HUD without trim numbers); a time trial; a real spin-out and gusts on the open water; the top speed; the reviews of 0.1's physics; small fixes (the fleet list, the start menu's title, the countdown sounds, the credits screen) |
| **0.3** (18 items) | The mouse experiment made permanent, and on the gamepad; the gybe in two presses; chop you absorb (its physics first); collisions; the big fleet (32 boards); the trained AI skipper; the AI using the push |
| **Later** (21 items) | The lake's details (the camping, trees, the village, landmarks); the course maker's tactics tools; the Maloja's day types; replay and live weather; other spots; multiplayer; a smaller download |

### The sections at a glance

| Section | What it covers | Open: 0.2 / 0.3 / later | In 0.2 | Who |
|---|---|---|---|---|
| [GP Gameplay and controls](#gp-gameplay-and-controls) | How the player sails: the inputs and the skill | 5 / 5 / 0, and 7 decisions | The push dial, the mouse experiment, tuning, a time trial (GP0's measurement is done) | Max and Tarpie decide; AI sessions build |
| [PH Physics](#ph-physics) | The simulation in `Game/sim/` | 16 / 8 / 5 | The reviews of 0.1, a real spin-out, gusts on the open water, the top speed, the planing onset, the findings from the races | Michiel (Tarpie: the top speed) |
| [RA Racing and the AI fleet](#ra-racing-and-the-ai-fleet) | Races, the AI skippers, their training | 2 / 5 / 4 | Max's play-tests of 0.1's fleet; the AI boards stop at the lake's shore | Max leads; AI sessions build |
| [GR Graphics and the look](#gr-graphics-and-the-look) | What you see | 6 / 0 / 1 | The board at the limit (spray, chatter), gust patches you can read, the sailor's body, the camera, the models, the team's look | AI sessions; the team looks |
| [SO Sound](#so-sound) | What you hear | 4 / 0 / 2 | The fin's hum, the board at the limit, the countdown and the gun, the team's listen | AI sessions; the team listens |
| [UI HUD, menus and settings](#ui-hud-menus-and-settings) | The screen and the menus | 4 / 0 / 1 | A HUD without trim numbers, the controls pages, the fleet list, the start menu's title | AI sessions |
| [MA The map and the wind](#ma-the-map-and-the-wind) | Lake Silvaplana and the Maloja wind | 2 / 0 / 6 | The lake play-test, the credits screen | Max |
| [TE Performance, tools and code](#te-performance-tools-and-code) | Speed, tools and tidying up | 2 / 0 / 4 | Godot rewriting the audio bus file, the tools on Max's PC | AI sessions; Max for his PC |
| [PR The project and releases](#pr-the-project-and-releases) | The license and the releases | 2 / 0 / 1, and 1 now | The license, the 0.2 release; now: check 0.1's release page | The team |

## Contents

- [Overview](#overview)
- [Version 0.2: the player becomes the sailor](#version-02-the-player-becomes-the-sailor) (the reasoning and the proposal in full)
- [Who is waiting on whom](#who-is-waiting-on-whom)
- [Where to look for the details](#where-to-look-for-the-details)
- [How to read the sections](#how-to-read-the-sections), then the sections: [GP Gameplay and controls](#gp-gameplay-and-controls) · [PH Physics](#ph-physics) · [RA Racing and the AI fleet](#ra-racing-and-the-ai-fleet) · [GR Graphics and the look](#gr-graphics-and-the-look) · [SO Sound](#so-sound) · [UI HUD, menus and settings](#ui-hud-menus-and-settings) · [MA The map and the wind](#ma-the-map-and-the-wind) · [TE Performance, tools and code](#te-performance-tools-and-code) · [PR The project and releases](#pr-the-project-and-releases)
- [How an update is made](#how-an-update-is-made)
- [Prompts to continue (for an AI session)](#prompts-to-continue-for-an-ai-session)
- [Done since the plans were written](#done-since-the-plans-were-written)

---

## Version 0.2: the player becomes the sailor

**The source** is [the gameplay and control design](Documentation/gameplay_controls_v0.2.pdf), from a voice session with Tarpie on 23 October 2026.

**The problem.** Version 0.1 is playable and the physics is far along, but the player is a passenger:
- On a reach you point the board and wait for the tack. The autopilot does the sailing.
- Upwind is dead time. You point at the wind and wait for the layline, and that is the longest part of a race.
- Practice does not pay off. Almost nothing separates a player with hours of practice from a new one.
- What a real sailor is always doing is automated or missing: committing or backing off, railing the board, absorbing chop, timing a gybe.

**The answer** is not a less real simulation. The player's input changes how the board is sailed, and the existing physics decides what happens when they get it wrong. Four rules from the design:
1. The autopilot keeps sailing. The player's input sits on top of it as the sailor's body.
2. No extra HUD readouts. The feedback is what a sailor sees, hears and feels: heel and pitch, spray, sound, wave faces, dark gust patches on the water.
3. Every failure comes from the physics: the fin's lift, grip and flex against the stall, the board's pitch, airtime. Never a scripted fall.
4. Difficulty grows with the conditions: flat water is easy; chop and gusts ask for more.

**Max's direction (26 October 2026), on top of the design:** "It is too hard to control every variable on the character. User input must impact the sailing in an intuitive and learnable way: a little challenging to go fast, but easy to just go. All in one package, or maybe two, so you learn to get faster." So 0.2 has **one dial (push)** as package A, which anyone can use, and the autopilot does the rest. Then Max's follow-up the same day: package B is an experiment, with **the mouse as the sailor's body** (sideways the rail, forward and back the back foot's pressure), "real physics still, nothing that is not real". Section GP has the design.

**Proposed for 0.2** (the team decides):
- **Package A, the push:** GP0 (measured: done), GP1 (the dial), and the feedback that makes it learnable: SO1, GR1 and UI1. Then GP3 (tuning) and GP4 (a time trial, so you see yourself get faster).
- **Package B, the body on the mouse (an experiment, Max's idea of 26 October 2026):** GP2. The mouse sideways sets the rail, forward and back the back foot's pressure; the real sailor's feet and the real hull and fin do the rest.
- **From Michiel:** PH6 (a real spin-out) and PH7 (gusts you can see on the open water), which make the push's risk real and readable; PH1 and PH2, the reviews of 0.1, before anything in `Game/sim/` changes; PH8 (the top speed, Tarpie).
- **The small items that are ready now:** RA2, SO3, UI3, UI4, MA2 and TE1.
- **The play-tests left over from 0.1:** RA1, MA1, GR6 and SO4.

**Proposed for 0.3:** the AI's push (RA7), package B made permanent if the experiment works (GP6, PH3) and on the gamepad's right stick (GP5), the gybe in two presses (GP8, PH4), chop (GP7, with the physics PH5 and PH9 to PH11 underneath), collisions (RA3), the big fleet (RA4) and the trained head (RA5).

**The push does not need a physics change.** The autopilot already sails with a margin that it reads from its own settings: how much pull it holds against what the sailor's weight can balance, and how early it eases when the board heels. The player's controller can set those every tick from the dial, the way it already caps the sail's power for the AI's hold-back before a start. So package A can start at once and does not wait for Michiel. His part makes the risk real: a fin that spins out (PH6) and gusts you can see coming on the open water (PH7).

**What GP0 measured** ([the report](Documentation/reports/gameplay/gp0_measure.md)): pushing pays when the sailor holds more pull *and* eases late (upwind +16 to 19 %, the close reach +12 to 15 %, the other reaches +4 to 6 %). At 18 kt in normal gusts nothing falls. At 24 kt a board pushed all the time catapults and is slower than neutral; one that pushes and eases as each gust arrives beats both. Every fall is a catapult; most round up in the last half second, and the fin warns of nothing. The pushed sailor is overloaded half the time, so that marks the edge rather than the fall; the early warning has to be the gust seen on the water. On the mouse, the back foot is worth about 10 % on the 18 kt broad reach, and the flattest rail is the fastest until speed makes it bounce or fall.

## Who is waiting on whom

These are the decisions and checks only a person can give. Everything else can be built.

**Michiel (the physics), in order:**
1. PH6 (a real spin-out), PH7 (gusts on the open water, with Max) and PH25 (the sailor's reaction time, small): they make the push's risk real and readable. Then PH26 and PH27 from Max's answers to GP0: light wind too weak, and the rail at planing speed; and PH28, the sail's twist (the rider cannot close the sail, and the drive is capped by the rider's balance), with PH29 (the body breaking beyond its numbers).
2. PH1 and PH2: the reviews of 0.1's physics (U2 and `no_wait`), before anything in `Game/sim/` changes.
3. A look at package B's experiment (GP2): it writes the rail's and the back foot's targets into the player's own copy of `SailorConfig` every tick, with no change in `Game/sim/`. If it works, PH3 makes them real controls. PH4 comes with the gybe's timing (GP8).
4. PH5 and PH9 to PH11: the chop (for 0.3).
5. PH12 to PH24: the contact force for collisions, running aground, the sail sizes, the wind shadow's numbers, the onset check, the findings from the races, Max's U2 questions and the code follow-ups.

**Michiel, also:** a look at GP0's findings ([the report](Documentation/reports/gameplay/gp0_measure.md), "Findings for Michiel"): the push pays only with the autopilot's safety nets weakened, the falls are all catapults, 0.1's margin catapults on the 24 kt broad reach, and the open sea's gusts jump (PH24).

**Tarpie:** PH8, the top speed. The design says "Tarpie knows the fix; handled separately". With Max: the gameplay decisions GD1 to GD7.

**Max:**
- GP0's stop, partly answered on 26 October: the mouse's ranges are OK; pushing must be risky at 12 and 18 kt too, as in real life (PH25, PH26); `gp0/measure` stays off `main` for now ("no merge"). Still open: the dial's three settings (the report's table), which way he tilts a wide board in light wind (PH27), whether GP10's smooth ease is built now, and whether the playtest gets a key to switch the push on and off;
- the gameplay decisions GD1 to GD7, and a play-test of every GP item;
- the Stops left from 0.1 (RA1) and the lake play-test (MA1);
- which machine runs the training nights (RA5), and the catch-up cap (RA4);
- his PC's tools (TE2), the license (PR1) and the GitHub Release page of 0.1.0 (PR2).

**The whole team:** the version plan above, a look at the effects (GR6) and a careful listen to the sound (SO4). Nobody has done the last two yet.

## Where to look for the details

| Section | Live documents | Reference and history |
|---|---|---|
| Gameplay and controls | This file (GP); [the design PDF](Documentation/gameplay_controls_v0.2.pdf) | [PHYSICS_SPEC.md](Documentation/PHYSICS_SPEC.md) section 10 (from keys to rake, sheet and weight); the header of `Game/windsurfer/player_controller.gd` (the two modes) |
| Physics | [PHYSICS_SPEC.md](Documentation/PHYSICS_SPEC.md): the physics as built; sections 17.12 and 17.13 list the open items of the waves and the sailor | Michiel's review questions in the archived [U2_PROGRESS.md](Documentation/archive/U2_PROGRESS.md) and [PLAYTEST_UPGRADES.md](Documentation/archive/PLAYTEST_UPGRADES.md); [reports/u1/](Documentation/reports/u1/), [reports/u2/](Documentation/reports/u2/), [no_wait.md](Documentation/reports/racing/no_wait.md) |
| Racing and the AI fleet | This file (RA) | The archived [AI_FLEET_PLAN.md](Documentation/archive/AI_FLEET_PLAN.md) (the design D1 to D7, the training's curriculum, the team's decisions), [RACING_PLAN.md](Documentation/archive/RACING_PLAN.md) and [P9_PROGRESS.md](Documentation/archive/P9_PROGRESS.md) (the Stops, the fleet table, the nights, the thread bench); [reports/racing/](Documentation/reports/racing/) |
| Graphics | This file (GR) | The archived [REBUILD_PLAN.md](Documentation/archive/REBUILD_PLAN.md), phases 6 and 7; the map plan, M2 and M4 |
| Sound | This file (SO) | The archived [REBUILD_PLAN.md](Documentation/archive/REBUILD_PLAN.md), phase 8, "What to listen for" |
| HUD, menus and settings | This file (UI) | The controls table in [README.md](README.md) |
| The map and the wind | [MAP_SILVAPLANA_PLAN.md](Documentation/MAP_SILVAPLANA_PLAN.md) (the status table, M4, W4b, Later) | [MALOJA_WIND_RESEARCH.md](Documentation/MALOJA_WIND_RESEARCH.md), [SILVAPLANA_SPOT_NOTES.md](Documentation/SILVAPLANA_SPOT_NOTES.md); the archived [PHYSICS_REQUESTS_FROM_MAP.md](Documentation/archive/PHYSICS_REQUESTS_FROM_MAP.md) (R4, R6 to R8 and the measurements behind them) |
| Performance and tools | [CLAUDE.md](CLAUDE.md) (every command) | The archived P9_PROGRESS.md, "Numbers" (the fleet table, the thread bench) |
| What each session did | [PROGRESS_LOG.md](Documentation/PROGRESS_LOG.md) | [Documentation/README.md](Documentation/README.md): the map of every document |

---

## How to read the sections

Each section below has a table with these columns:

| Column | What it says |
|---|---|
| **ID** | Two letters for the section and a number (GP3, PH12). Use it in branch names, commits and chats: "GP1 done", `feature/gp1-push`. The two letters do not clash with the older names: U1 and U2, F1 to F6, the training stages S1 to S6, the courses T1 and T2, the map's M0 to M4 and W0 to W5, and the physics requests R1 to R9 |
| **Item** | What it is and why, with its source |
| **Where** | The files it touches (under `Game/` unless the path says otherwise) |
| **Waits on** | A decision, a person or another item. **Ready** means it can be built now |
| **Size** | **S**: a session or less. **M**: one package (one agent, or one Fable session). **L**: several packages |
| **For** | The version it is aimed at: 0.2, 0.3 or later. This is a proposal; the team moves items |

---

## GP Gameplay and controls

**What there is in 0.1.** Two keyboard modes, switched with Tab (`PlayerController`, `Game/windsurfer/player_controller.gd`):
- **Beginner:** A/D ask for a turn, and the controller finds the rake, the tilt and the rail. The balance is automatic, and so is the sheet (T).
- **Advanced:** Q/E rake the rig, the arrows tilt it, A/D move the weight, all on top of the balance reflex.
- **Both:** Space tacks or gybes.

A gamepad works in the menus only. The right mouse button orbits the camera.

**What the autopilot already decides.** With the auto-sheet on, the autopilot sheets the sail for the most drive, but only up to the pull the sailor's weight can balance (`Autopilot.hike_share` 1.1 and `ankle_share` 0.8, in `Game/sim/autopilot.gd`), and it eases when the board heels to leeward or the sailor is pulled toward the sail (`depower_heel_allowance_deg`, `depower_rate_per_s`, the catch). Those numbers are the sailor's margin: how close to the edge the board is sailed. Today the margin is fixed.

### The design: one dial, and the body on the mouse

**1. The push (package A).** One input says how hard the sailor commits. The controller turns it into the autopilot's margin every tick, the way it already caps the sail's power (`Autopilot.max_alpha_deg`) for the AI's hold-back before a start. Steering stays as it is, and so does the manoeuvre button. Everything else stays automatic.

| The dial | What the sailor does | What happens |
|---|---|---|
| Eased | Lets the sail out below full power | Slower and very safe. This is the hold-back the AI already uses before a start |
| Neutral (no input) | Sails with a margin: holds less pull than the weight could balance, eases early in a gust | Easy to just go. Hard to fall |
| Pushed | Holds more pull, eases late | Faster, until a gust is too much. Then the physics catapults the sailor or spins the fin out |

The skill is timing: see the gust coming on the water, ease just before it hits, push again after it. In light wind there is little to gain or lose; in strong, gusty wind it is the whole game, as the design's rule 4 wants. **No file in `Game/sim/` changes:** the controller only sets numbers the autopilot already has. GP0 measured which of them make the difference: `hike_share` (how much pull is held) together with a late ease (`depower_alpha_per_deg`, the depower rates and the catch weakened). The three settings for eased, neutral and pushed are in [its report](Documentation/reports/gameplay/gp0_measure.md), "What this means for the build".

**2. The body on the mouse (package B, an experiment).** Max, 26 October 2026: the mouse sideways mimics the board's roll, so with precision you hold the best rail angle; the mouse forward and back is the back foot's pressure (more pressure lifts the nose, less lowers it). Real physics only.

The sim's sailor already makes both choices, as targets their real feet work toward (`Game/sim/windsurfer_sim.gd`):
- **The rail:** the bank the feet aim for while hiked out in the straps and not turning (`SailorConfig.fin_load_bank_deg`, 2° now). The ankles hold it only as firmly as they are stiff (`feet_roll_stiffness_nm_per_rad`, `feet_moment_max_nm`). The fin's roll pushes a powered board past it, and the sailor feels that and corrects within 0.4 s (`lean_feel_time_s`).
- **The back foot:** the nose angle the feet press toward while planing (`running_trim_deg` 2.0°, falling to 1.5° at speed), pressed at most 0.3 m aft or forward (`trim_press_max_m`).

Both were chosen in U2 for a steady ride, not for speed. They are read from the config fresh every tick, so the experiment needs **no change in `Game/sim/`**. The player's board gets its own copy of the config (others share it), and the mouse writes the two targets into it every tick. The physics does the rest with the real feet, hull, fin and sail; there are no new forces.

U2's map ([fin_technique.md](Documentation/reports/u2/fin_technique.md)) already shows the edge to play with. Less bank and more trim make the wet part of the hull shorter (less drag), until the board bounces. The bounce limit falls with speed: at 2° of bank the 18 kt beam reach bounces from 2.2° of trim, and the 32 kn broad reach bounces flat at almost any trim. Flat boards drag on the close reaches; 4.5° of bank made every planing reach slower than 2°. So the best angle moves with the wind and the speed, and going past it is visible and audible. GP0 extended the map to 10° of rail, 3.5° of trim, upwind and gusts: the flattest board is the fastest on every reach and rail buys stability at speed; the back foot is worth about 10 % over 0.1's trim on the 18 kt broad reach; at 24 kt too much trim on a flat board catapults, while 5 to 6° of rail makes the same trim safe and the fastest. Upwind and below planing the two do almost nothing.

Two levels to try:
- **Level 1:** the mouse sets the targets, and the sailor's feet still correct automatically within 0.4 s. The skill is choosing the angle as the speed and the wind change.
- **Level 2:** the automatic correction slowed down (`lean_feel_time_s` long), so a gust heels the board past the angle and the player's hand holds it. This is closer to "with precision you hold the optimum angle".

Leave the mouse alone and the sailor sails as in 0.1. So there are three steps: touch nothing and it sails; use the push (A) to go faster; use the mouse (B) to go faster still. WASD for the push and the steering plus the mouse for the body is the standard PC layout; on a gamepad it is two sticks (GP5).

**3. The gybe's timing (later).** The tack stays one press. The gybe becomes two presses: the first carves into it, the second flips the sail. Flip too early and the sail stalls; too late and it backs and catapults; the window gets smaller in more wind. The controller holds the sail on its old side with `SimControls.hold_side` until the second press, as it already does through a tack (GP8, PH4). In 0.3 the same press could absorb a wave on chop (GP7).

**How the player learns.** From what a sailor senses, not from numbers on the screen: the fin's hum rising as it nears its limit (SO1), the spray, the chatter and the heel (GR1), the gusts on the water (GR2). And from the result: a time trial with the time against your own best, split by leg (GP4). For the experiment itself the team may show the speed, the bank and the trim (F1's detail panel), to tune it.

**What changed from the design PDF.** The PDF puts the rail and the fore-aft trim on the mouse's two axes, absorb on a button and a push of its own. Max's direction: a push dial (A), with the rail and the back foot on the mouse as an experiment (B) on targets the sailor's technique already has. Absorb comes with chop (GP7). The PDF's virtual centre that springs back is a question for B (GD7).

### Decisions (Max and Tarpie)

| ID | Question | The lead's recommendation |
|---|---|---|
| GD1 | Where is the dial? | Keyboard: W pushes and S eases (W and S are the sheet in 0.1, already a power control). Gamepad: the right trigger pushes, the left trigger eases, the left stick steers. Mouse: later (GP5) |
| GD2 | Does the dial spring back to neutral when you let go, or stay where you put it? | It springs back: letting go is always safe, and pushing is something you do on purpose and hold, like a throttle in a racing game |
| GD3 | How fast is neutral? As fast as 0.1's autopilot (so pushing only adds speed and risk on top), or a little slower (so a good player clearly beats it)? | A little slower. GP0's numbers: neutral at `hike_share` 1.0 with today's safety nets, 1 to 3 % slower than 0.1, and it does not catapult on the 24 kt broad reach where 0.1 does (twice in 400 s). That is 82 to 84 % of the full push upwind and 94 to 98 % on the reaches |
| GD4 | A new mode, or the beginner mode changed? | The beginner mode becomes the push mode: A/D steer as now, W/S push and ease instead of sheeting, Space as now. Advanced stays raw for whoever wants every control. One fewer mode to explain |
| GD5 | Race against AI opponents, or a time trial? This decides how much upwind tactics like dirty air matter | Both. The races with the AI stay, and a time trial (GP4) is cheap because `RaceSim` already runs a board alone |
| GD6 | What stays on the screen while sailing? Today there are the telemetry strip, the detail panel (F1) and the racing HUD | The race's information stays (the next mark, the place, the clock). Speed, wind angles and trim readouts are off by default. F1's detail panel stays as a tool for the team |
| GD7 | Package B: (a) does the mouse stay where you put it, or spring slowly back to the centre (the PDF's virtual centre)? (b) Sideways: does the board roll the way the mouse moves as you see it (so the sweet spot swaps sides at every tack), or does one direction always mean more rail? | Try both of each in the experiment. The lead's guesses: (a) it stays, because holding an angle is the point, and it re-centres at every tack, gybe and fall, where the centre is the sailor's own technique; (b) the board rolls the way the mouse moves, because that is what "mimic the roll" means, and the re-centre at the tack hides the swap |

### Items

| ID | Item | Where | Waits on | Size | For |
|---|---|---|---|---|---|
| GP1 | **The push (package A's core).** The dial on the keyboard and the gamepad (GD1), springing back (GD2). The controller sets the autopilot's margin from it every tick, between the eased setting, neutral and the pushed setting that GP0 found. Beginner mode becomes the push mode (GD4); advanced stays as it is. Tests with the dial set by values, so no device is needed. This is also the old roadmap's "sailing with a gamepad" | `windsurfer/player_controller.gd`, `project.godot` (the input map), `Game/config/` (the dial's settings) | GD1 to GD4 (GP0 is done: its report has the three settings) | M | 0.2 |
| GP2 | **The body on the mouse (package B, an experiment).** The mouse captured while sailing: sideways sets the rail (the bank the feet aim for), forward and back the back foot (the trim the feet press for), written every tick into the player's own copy of `SailorConfig` (`fin_load_bank_deg`, `running_trim_deg` and `running_trim_fast_deg`); the mouse left alone is the sailor's technique as in 0.1. Levels 1 and 2 (the feel's correction at 0.4 s or slowed) and GD7's choices as settings, so Max can try them all. The orbit camera's mouse drag moves to a held key. It only acts where the technique does: planing, hiked out in the straps, not in a turn; below planing the mouse does nothing yet. Built on a branch as an experiment: no change in `Game/sim/`, and nothing merged until Max says it feels right | `windsurfer/player_controller.gd`, `windsurfer/windsurfer.gd` (the player's own config copy), `camera/camera_rig.gd`, `main.gd`, `project.godot` | Ready (GP0 gave the ranges: the rail 0 to 8°, the trim 0.5 to 3.5°); GD7 is tried in it | M | 0.2 |
| GP3 | **Tune the curve:** the dial's range and neutral per wind strength, and package B's ranges and level. Play-tests by Max and Tarpie with a short checklist ("could you just go? did pushing pay? did you see the fall coming? could you find and hold the best rail?"). The numbers live in the config | `Game/config/` | GP1, GP2 | S to M | 0.2 |
| GP4 | **A time trial.** A course sailed alone against your own best, with the record kept per course and wind and the splits by leg, so practice shows as a number. `RaceSim` already runs one board (Phase 9A); it needs a record file and a line on the results | `race/race_sim.gd`, `race/race_hud.gd`, `ui/race_page.gd`, a file in `user://` | GD5 | S to M | 0.2 |
| GP5 | **Package B on the gamepad:** the right stick for the body (sideways the rail, forward and back the back foot), the left stick to steer, the triggers for the push | `windsurfer/player_controller.gd`, `project.godot` | GP2 works | S | 0.3 |
| GP6 | **Package B made permanent,** if the experiment works: from writing the config to two real controls (PH3), with tests | `windsurfer/player_controller.gd`; `sim/` through PH3 | GP2, PH3 | S to M | 0.3 |
| GP7 | **Chop: absorbing the waves** with the timing button. Press as the nose meets a wave face: good timing keeps the board in the water and the fin gripping; bad timing launches the board off the ramp, the fin loses grip in the air, and it lands in a spin-out or a catapult. The rhythm is set by the real wave spacing (the wind and the fetch); more speed gives a tighter window. **The physics cannot carry this yet.** The sea is mostly swell, with the chop turned down to almost nothing, because the slam on short waves is overstated and the sailor's legs do not give in pitch and roll (PHYSICS_SPEC.md 17.12, open items 1 and 2) | `windsurfer/player_controller.gd`; `sim/` through PH5 and PH9 to PH11 | PH5, PH9 to PH11 | L | 0.3 |
| GP8 | **The gybe's timing:** the gybe in two presses, the sail held on its old side (`SimControls.hold_side`) until the second press; too early stalls, too late backs and catapults, a smaller window in more wind. The tack stays one press | `windsurfer/player_controller.gd` (`_start_manoeuvre()`, `_manoeuvre_turn()`) | GP9, PH4 | M | 0.3 |
| GP10 | **The sheet by hand jerks** (Max, playing GP0's test). With W held, the beginner's controller eases when overpowered with an on-off switch (`ease_when_overpowered`: on at 1 per second past 85 % of the hike or 10° of heel, off at 0.8), which pumps the sheet 7 to 25 times harder than the auto-sheet and falls 1 to 9 times in 80 s; 3 s after the key the auto-sheet takes over again. Make the ease proportional (it should settle where the pull is just holdable, as the auto-sheet's limit does), or let W become the push (GP1) so this path is only the advanced mode's | `windsurfer/player_controller.gd` | Ready | S | 0.2 |
| GP9 | **Measure the gybe's timing** (left over from GP0, part (c)): the gybe's result against the moment the sail flips, with `SimControls.hold_side` holding it on its old side until a chosen moment, at 12, 18 and 24 kt. It needs a harness of its own (the controller's gybe with the flip held back), as `Game/dev/run_push.gd` is for the push | `Game/dev/`; a report in `Documentation/reports/gameplay/` | Ready | S to M | 0.3 |

---

## PH Physics

**Owner: Michiel.** Every change needs his OK, a branch, an update of [PHYSICS_SPEC.md](Documentation/PHYSICS_SPEC.md) and `tools/test.sh validation` (CLAUDE.md). The one validation check that is red on purpose is PH16's.

### The reviews of 0.1 (before anything in `Game/sim/` changes)

| ID | Item | Where | Waits on | Size | For |
|---|---|---|---|---|---|
| PH1 | **The U2 review** (U2's Stop 2): the bending fin, the heeled hull's lift, the sailor's technique, the gust calibration, the critical trim, the probe. The questions are in the archived [U2_PROGRESS.md](Documentation/archive/U2_PROGRESS.md) ("Stop 2 package") and the U2 sections of [PLAYTEST_UPGRADES.md](Documentation/archive/PLAYTEST_UPGRADES.md) | `sim/fin_model.gd`, `sim/hull_model.gd`, `sim/windsurfer_sim.gd` | Michiel | M | 0.2 |
| PH2 | **The `no_wait` review:** the rewrite of `Game/sim/` that lets 20 boards run on threads. No formula changed, and every answer is bit for bit the same (the whole state hashed every tick over eight runs). The list per file is in [no_wait.md](Documentation/reports/racing/no_wait.md) | all of `sim/` | Michiel | M | 0.2 |

### For the gameplay

The push (GP1) needs none of these to start: it only sets numbers the autopilot already has. PH6 and PH7 make its risk real and readable; the rest is needed only if GP0 asks for it, or for chop.

| ID | Item | Where | Waits on | Size | For |
|---|---|---|---|---|---|
| PH6 | **A real spin-out.** Ventilation is not modelled: air drawn down the fin at high slip, after which the lift collapses at once. The post-stall curve gives only a soft spin-out (spec section 4, open question T10). Pushing against risk needs a spin-out that comes suddenly, after warning signs a player can learn. (The catapult, the other risk of pushing, is there already: GP0's 124 falls were all catapults or falls off the board, and the fin stalled only around falls already under way) | `sim/fin_model.gd`, `FinConfig` | Michiel; sources | M | 0.2 |
| PH7 | **Gusts you can see on the open water.** The open sea's gusts are a sine in time, the same everywhere at once (`sim/wind_field.gd`), so there is nothing to read on the water and no way to ease just before a gust. The open water needs moving gust patches like the lake's lanes (`MapWind`), drawn on the water by GR2. On the lake they exist already | `sim/wind_field.gd`, or a new field like `sim/map_wind_field.gd` | Michiel with Max | M | 0.2 |
| PH25 | **The sailor's reaction time** (GP0's follow-up). The autopilot eases for a gust in the same tick it arrives (`_alpha_for_torque_deg()` reads the apparent wind as it is), so pushing is free of risk at 18 kt. Fed the gust 0.3 s late, the pushed board falls 6 to 7 times in 200 s upwind at 18 kt, and 9 to 17 times at 0.6 s. A reaction time (the felt apparent wind lagging the real one) in `Autopilot`, set by the dial (GP1) and for the AI by its persona; at 0 every answer bit for bit the same | `sim/autopilot.gd` | Michiel's OK | S | 0.2 |
| PH26 | **Light wind is too weak** (Max, after GP0: "in 12 knots in real life you can push too much"). At 12 kt nothing the sailor does changes the speed or makes a fall: the 6.5 m² sail never pulls more than the sailor can hold, even in gusts to 15.6 kt. Probably the same cause as the late planing onset (PH16: 13.4 kn against 8 to 10) and the low top speed (PH8), which make the sim's 12 kt sail like a real 9 to 10 kt | `sim/hull_model.gd`, `sim/sail_model.gd`, the configs | Michiel, with PH16 and PH8 | M | 0.2 |
| PH27 | **The rail at planing speed** (Max, after GP0: "in real life a flat board is not the fastest", on boards of 70 to 75 cm and up). In light wind the sim agrees: at 12 kt any rail is 2 to 6 % faster than flat, the windward rail down the most. Fully planing (18 kt) the flat board is the fastest, because the leeward rail makes the wet part longer (1.19 m flat, 1.71 m at 6°). A heeled flat bottom should be wet over less of its width; the planing beam narrows only by the heel's cosine (`lift_beam_m`). Check against Max's experience (which way he tilts a wide board, and how much it gains) | `sim/hull_model.gd` | Michiel, with Max | M | 0.2 |
| PH28 | **Built on `ph28/sail-and-hull` (28 October 2026), for Michiel's review:** the sail's curve and its twist under load from the full-scale wind-tunnel study of an iQFOiL sail ([Documentation/2501.13254v1.pdf](Documentation/2501.13254v1.pdf); spec 2.17; [the report](Documentation/reports/ph28/sail_wind_tunnel.md)). The legacy sail made twice the measured lift at small angles; now it sheets in further (7 to 15° of attack instead of 4 to 6) and the board is 4 to 7 % faster at 24 kt upwind and across, as fast at 18 kt, but 19 to 36 % slower at 12 kt and 10 to 29 % on the broad reaches until PH16 wins the speed back; the push catapults at 24 kt again with the twist floored at the tunnel's lowest measured share. Validation: eight red tests, by cause in [the progress file](Documentation/reports/ph28/PROGRESS.md). The tunnel's centre of effort barely moves, so the 30 % stand-in below is not what a real sail does. Originally: **The sail's twist** (Max, playing GP0's test: "the character cannot fully close the sail"). The sail is rigid, with its centre of effort fixed at 40 % of the mast, so at the top of its range the rider can hold it only eased to the edge of luffing (a 3 to 7° angle of attack at 24 kt, even at 110 kg; 6° on the 18 kt beam reach at 75 kg), and the drive is capped by the rider's balance. A real leech twists open under load, which takes force off the top and lowers the centre of effort. Lowering it to 30 % as a stand-in made the board 3 to 14 % faster with the sheet further in and no falls; a flatter sail alone changed nothing. A twist that grows with the load, then the sail's range checked against real sail charts (a 6.5 for 75 kg in about 15 to 24 kt). Likely part of PH8's low top speed. [GP0's report](Documentation/reports/gameplay/gp0_measure.md), "Follow-up 2" | `sim/sail_model.gd`, `config/sail_default.tres` | Michiel | M | 0.2 |
| PH29 | **The sailor's body breaks beyond its numbers** (found by GP0): with stronger feet (`feet_moment_max_nm` 300 to 600 against 120) or the body hung further out (`lean_max_m` 1.1 to 1.3 against 0.88), the rider falls more, the sheet jerks hard, and 7 of 36 runs blew up (NaN). Today's numbers are realistic, but a model should degrade, not explode, a little beyond them | `sim/windsurfer_sim.gd`, `sim/sailor_body.gd` | Michiel | S to M | 0.2 |
| PH3 | **The rail and the back foot as real controls,** if package B's experiment works (GP2): two fields of `SimControls` that override the technique's bank and trim targets (`_fin_load_bank_rad()`, `_running_trim_target_deg()`), in place of the experiment writing the config. With the fields unset, every answer must be bit for bit the same as now, proven the way `no_wait` was (the state hashed every tick). Michiel may also want the mouse to act below planing (the stance through the hump), which the targets do not reach today | `sim/sim_controls.gd`, `sim/windsurfer_sim.gd` (`_update_sailor()`); spec sections 7.5 and 10 | GP2, PH1, PH2; Michiel's OK | M | 0.3 |
| PH4 | **The gybe's flip in the physics.** Check that a sail held on its old side through a gybe (`SimControls.hold_side`, as in a tack today) stalls when it is flipped too early and backs into a catapult when it is flipped too late (GP9). If it does, there is nothing to change; if not, the change it needs | `sim/windsurfer_sim.gd`, `sim/sail_model.gd` | GP9 | S to M | 0.3 |
| PH5 | **Absorb, for chop:** the knees as an input (today `knee_bend_m` is a reflex), for GP7's timing button. With the input at 0, bit for bit the same | `sim/sim_controls.gd`, `sim/windsurfer_sim.gd` | PH9 | M | 0.3 |
| PH8 | **The top speed:** about 50 km/h at 16 to 18 kn, against about 60 km/h on real boards (from the design: "Tarpie knows the fix; handled separately") | Tarpie's fix | Tarpie | ? | 0.2 |

### For chop (0.3)

| ID | Item | Where | Waits on | Size | For |
|---|---|---|---|---|---|
| PH9 | **Legs that give in pitch and roll** (the two-body sailor A-17; spec 17.12, open item 1). This is what lets a real board slam and skip under a level body, and the step that lets the chop come back | `sim/windsurfer_sim.gd`, `sim/sailor_body.gd` | Michiel | L | 0.3 |
| PH10 | **The slam on short waves** (spec 17.12, open item 2). The strip theory overstates it on waves shorter than about three hull lengths. The engineering fix is to smooth the surface the strips see over the board's width, or to add a pressure-relief time | `sim/hull_model.gd` | PH9 | M | 0.3 |
| PH11 | **Wind-made chop on the water, and airtime.** The fetch-limited chop (`sim/wind_waves.gd`, spec 9.16, request R6) is built as a preset, not the default. Make it the lake's and the sea's once PH9 and PH10 hold, and check a board launched off a crest, its fin out of the water, and the landing. Also from 17.12, item 3: two manoeuvre cases still fall on the swell, and upwind on the swell loses a third of its speed | `sim/wind_waves.gd`, `sim/wave_field.gd`, `config/waves_default.tres` | PH9, PH10 | M to L | 0.3 |

### For racing

| ID | Item | Where | Waits on | Size | For |
|---|---|---|---|---|---|
| PH12 | **A contact force** for collisions between boards and with the marks: soft pushes and a short loss of speed (the hook the racing plan asked for). The game's side is RA3 | `sim/windsurfer_sim.gd` | Michiel | M | 0.3 |
| PH13 | **Running aground on the lakebed** (request R4): a depth the simulation can ask for, so the fin (0.38 m) touches the bottom near the shore. The scene's shore stop stands in for it today, for the player only (RA2) | `sim/water_surface.gd` or a new bed surface; the map's depth grid | Michiel | M | later |
| PH14 | **The sail sizes.** As the sails are, a 7.8 is slower off the line than a 6.5 even in 12 kt, so the gear per persona is built but switched off (RA8) | `config/sail_default.tres` and the other sails, `sim/sail_model.gd` | Michiel | M | 0.3 |
| PH15 | **The wind shadow's numbers** (`config/wind_shadow_default.tres`, spec 8.11), together with Max's crowd race (RA1, F3's Stop) | `config/wind_shadow_default.tres` | Michiel | S | 0.2 |

### Tuning and findings

| ID | Item | Where | Waits on | Size | For |
|---|---|---|---|---|---|
| PH16 | **Measured in Session 58 (29 October 2026) on `ph28/sail-and-hull`; nothing in the game changed.** The hull's own friction (the ITTC line, on the area its wet widths give) and lift (Savitsky, TN 4187) check out for the attitude it rides at. What sets the long wet part is the whole windsurfer's balance: the sail pushes the nose down (−678 N·m on the 18 kt beam reach) and only the sailor's weight lifts it (+712). The sailor hangs under the boom (the harness carries 65 % of the weight), and the boom is where the steering rake puts it. The harness and the mast foot pass loads inside the windsurfer and do not set the trim. The lock is the bounce: a 1.0 m wet part needs 1.5 to 1.8° of trim, and the board porpoises from about 1.2 to 1.3°. Built as an option, off: the rig's pitch following the board's with a lag (`SailorConfig.rig_pitch_follow_s`; a mast foot is a joint). It held the 24 kt broad reach steady for 40 s, but after a minute it bounced the same, so there is no measured gain; this low-trim bounce is not understood yet. Measured, not built: a slow, stiff trim press is 4 to 16 % faster where the board stays steady (18 kt and 12 kt beam reaches) but bounces elsewhere; it needs to ease off on the bounce it feels. Also for Michiel: at 12 kt the boom grip sits 0.23 m behind the sailor's hips and the harness pulls them backwards; and U1's 0.6 to 1.0 m target needs more trim than the model holds steadily. [The report](Documentation/reports/ph28/hull_balance.md); the tool `Game/dev/pitch_budget.gd`. Before (28 October 2026, after PH28): with the sail as measured in the wind tunnel, the hull's drag shows: on the 18 kt beam reach its skin friction is 231 N of the 312 N drive, over 0.96 m² (1.74 m wet) at the ITTC friction line, because the board rides at 0.76° of trim. Pressing for 3° with the back foot does not lift it (the rig's 365 N on the mast foot holds the bow down; the harness carries 663 N against the measured 368 to 415 N, U1.2); where it does lift, it bounces at 24 kt (Savitsky's limit). The planing buoyancy 0.5 wins no speed. The levers for Michiel: the rig's load path (the harness geometry, the mast foot's push) and the porpoising limit at a real board's trim ([the report](Documentation/reports/ph28/sail_wind_tunnel.md)). Also, RA: with PH28 the course's hand-written policy needs 245 s to mark 1 in 15 kt, past the training's 240 s episodes. Before: **The planing onset,** red on purpose: 13.4 kn against the 8 to 10 kn of real boards. The buoyancy factor is built but off. Also U1's wet-area targets: 0.6 to 1.0 m wanted, 1.35 to 1.59 m measured. Is the 1 degree vee the limit? | `sim/hull_model.gd`, `sim/buoyancy_model.gd` | Michiel | M | 0.2 |
| PH17 | **The findings from the races** (the archived [P9_PROGRESS.md](Documentation/archive/P9_PROGRESS.md)): catapults at 24 kt on broad reaches at 13.6 to 14.1 m/s in four-board races; the controller's tack stops the board for about 6.5 s; at 150 degrees from the wind the board makes 2.6 m/s in 15 kt, against 8.7 m/s at 92 degrees. The tack and the slow run matter to the player too (GP2). GP0 measured the catapults: 0.1's margin (`hike_share` 1.1) catapults twice in 400 s on the 24 kt 135° reach in gusts of 0.2, where 1.0 does not; and the run at 150° makes 5.0 to 5.2 m/s at 18 kt, 9.6 at 24 kt | `sim/autopilot.gd`, `windsurfer/player_controller.gd`, `sim/sail_model.gd` | Michiel | M | 0.2 |
| PH24 | **The open sea's gusts jump, and repeat** (found by GP0): `WindField` wraps the gust's phase every period, but its second and third waves (2.3 and 5.7 times the frequency) do not restart there, so the wind drops by 3.8 % in one tick every 8 s at intensity 0.2. The gusts also repeat exactly every period, so a player could learn their rhythm by ear. Together with PH7 | `sim/wind_field.gd` | Michiel | S | 0.2 |
| PH18 | **Max's questions from U2:** the mast foot's 400 N (the sailor's own weight through the boom); the hands' share of the boom force; the fin's size and the mast track as player settings (UI5); a flex test of Max's own fins (the brand and model; clamp the base, hang a known weight at the tip, measure how far the tip moves) | `sim/windsurfer_sim.gd`, `FinConfig` | Michiel; Max for the fins | S to M | 0.2 |

### Code follow-ups (no change of behaviour)

| ID | Item | Where | Waits on | Size | For |
|---|---|---|---|---|---|
| PH19 | **The hands' cost:** `sim/autopilot.gd:196` (`best_alpha_deg()`) searches 21 angles of attack every tick, a fifth of the hands' cost. Ten times a second, or a table by apparent wind angle, gives the same trim. This is also the first lever of the big fleet (RA4) | `sim/autopilot.gd` | Michiel | S | 0.2 |
| PH20 | **The fin's sea queries:** `fin_model.gd` still asks the sea twice per substep the old way (a warm query would move the waves by the solver's millimetre). The spec's 9.5 table ("about six passes") is for the old wave set | `sim/fin_model.gd`, spec 9.5 | Michiel | S | later |
| PH21 | **`reset()` leaves some sailor state behind** (the knee bend, the felt hand moments, the tipping timer). On waves a reset board differs from a new one by 1.3 mm after 2 s | `sim/windsurfer_sim.gd` | Michiel | S | later |
| PH22 | **The buoyancy grid:** 13 rows move the 18 kt beam reach's wet front by 34 cm (left out of U1) | `sim/buoyancy_model.gd` | Michiel | S | later |
| PH23 | **Spray drag** is missing (U1.7) | `sim/hull_model.gd` | Michiel | S to M | later |

---

## RA Racing and the AI fleet

**What there is in 0.1:**
- races on T1 (the open water) and T2 (the lake);
- scripted skippers with four characters and twelve personas;
- wind shadows and the racing rules;
- 20 AI boards and the player at 60 fps on the release build;
- a PPO trainer whose first brains start and beat to the mark, but do not round it.

The open items are here; the design behind them (D1 to D7, the training's curriculum, the team's decisions) is in the archived [AI_FLEET_PLAN.md](Documentation/archive/AI_FLEET_PLAN.md). Rule 7 of CLAUDE.md holds for every item: every AI board runs the same physics, controller and substeps as the player.

| ID | Item | Where | Waits on | Size | For |
|---|---|---|---|---|---|
| RA1 | **Max's Stops left from 0.1.** The commands are in the archived [P9_PROGRESS.md](Documentation/archive/P9_PROGRESS.md), "The Stops for Max". **A2:** sail among T1's and T2's buoys; the course maker's Fit to water; the race matrix. **F1:** the frame-time table by fleet size. **F2:** watch 16 boards gather and start. **F3:** race in a crowd of eight. Does the shadow feel right, is 20 s the right penalty, does the AI's circle look like a penalty turn? **F4:** the twelve personas' names and profiles | — | Max | S each | 0.2 |
| RA2 | **The opponents stop at the lake's shore.** The player stops at the shore today, but the AI boards sail on through it. Give them the player's scene-side stop now; the physics version (PH13) comes later | `race/race_runner.gd`, `maps/shore_check.gd` | Ready | S | 0.2 |
| RA3 | **Collisions:** boards with each other and with the marks, as simple custom checks (the rebuild plan's decision: no engine physics for the board), through PH12's contact force. "Contact" shows on the HUD, and a touch counts for the rules | `race/`, `race/race_rules.gd`; `sim/` through PH12 | PH12 | M | 0.3 |
| RA4 | **F6, the big fleet:** 24 and 32 boards measured and played, and 40 if the frame allows. The Stop is 32 boards at 60 fps on a laptop. The levers: (a) the hands' cost (PH19); (b) the rest of the physics' engine locks: about 85 field reads and 25 Basis values per substep, and the telemetry per tick; (c) a cap on the catch-up ticks, 2 instead of 8. With the cap, an overloaded tick slows the clock a little instead of collapsing; that is a gameplay choice for Max. This also removes most of TE5 | `race/race_runner.gd`, `sim/`, `tools/fleet_measure.sh` | PH19; Max for the cap | L | 0.3 |
| RA5 | **The trained head, stages S2 to S6, on another machine.** Max's laptop crashed five times under full load and is ruled out. The command is `tools/train.sh --stages=S1,S2,S3,S4,S5,S6 --hours_each=4 --workers=<cores>`, and the state is read from `.logs/nights.log` and `.sim_output/train/<run>/`. Then F5's Stop: the first fleet race against the trained brain | `tools/train/`, `race/` | Max: which machine | L | 0.3 |
| RA6 | **The personas on the trained head** (the second half of D3 in AI_FLEET_PLAN.md) | `race/persona.gd`, `race/personas/` | RA5 | M | later |
| RA7 | **The AI's push.** The AI boards sail through the same controller (rule 7), so they get the same dial. A new number on the persona's skill sheet says how hard it pushes and how well it eases before a gust (today `gust_appetite` and `risk` only change the course it steers and its margins at marks), and the gybe's timing goes on the sheet too. Until then the AI's dial is set to 0.1's margin, so the AI sails as it does now. With package B the AI sails with the mouse left alone (the technique), like a player who never uses it; a persona's own rail and trim can come later | `race/persona.gd`, `race/skipper_config.gd`, `windsurfer/ai_hands.gd` | GP1 | M | 0.3 |
| RA8 | **The gear per persona switched on** (`Persona.rig()`, built but off) | `race/persona.gd` | PH14 | S | 0.3 |
| RA9 | **The trainer's follow-ups:** the lake's wind and water in the stages (D6 wanted courses fitted to Lake Silvaplana in the map's wind); the idle steps of parked boards in S5 and S6; `tools/gens.sh --run=s1 --behind=20 --prestart=5` for runs whose early stages never saw a start | `race/training_drops.gd`, `tools/train/` | Ready | S each | later |
| RA10 | **Phase 9D's leftovers** (the archived [RACING_PLAN.md](Documentation/archive/RACING_PLAN.md)): the evaluation table (every skipper on T1 and T2 at 12, 18 and 24 kt, alone and in a fleet of four); brain files that record the physics commit they were trained on, with a warning when the physics is newer; the Race page listing the brains | `race/`, `ui/race_page.gd` | Ready | M | later |
| RA11 | **A longer countdown** than 60 s (decision 6 of AI_FLEET_PLAN.md: "60 s for now; longer later") | `race/race_sim.gd`, `ui/race_page.gd` | Max | S | later |

---

## GR Graphics and the look

| ID | Item | Where | Waits on | Size | For |
|---|---|---|---|---|---|
| GR1 | **The board at the limit, seen** (the design's warnings; part of package A): tail spray that grows with the fin's load and slip, a chatter of the board and the rig as the fin nears its limit, and the leeward spray of a board on its rail. It is visual only, driven by numbers the telemetry already has (the fin's slip, stall and load, the heel, how much of the hike is used); nothing visual feeds back into the physics (CLAUDE.md, rule 2) | `windsurfer/effects.gd`, `world/effects/`, `windsurfer/rig_visuals.gd` | Ready. GP0: the pushed sailor's overload (`feet_moment_excess_nm`) marks the edge (it is on half the time at the dial's top); a catapult shows in its last half second as the nose lifting and the board rounding up; the fin's load and the heel do not warn. The early warning is the gust seen on the water (GR2, PH7) | M | 0.2 |
| GR2 | **Gust patches you can read.** On the lake the gusts show mostly in the glitter today; Phase 7 noted that "a stronger look needs the shader". The design asks for dark patches, as a sailor sees them. On the open water this waits for PH7 | `world/water.gdshader`, the lake's `WindRippleMap` | PH7 for the open water | M | 0.2 |
| GR3 | **The sailor figure shows the push and the body:** hanging further out and lower when pushing, upright when eased, the ankles rolling the rail, the weight on the back foot. The skeleton is posed from the simulation's body and feet (it already reads the stance and the feet's press), so most of this may show by itself. Check it with the contact sheets of `res://dev/figure_view.tscn` | `windsurfer/figure_skeleton.gd`, `windsurfer/sailor_figure.gd` | GP1, GP2 | S | 0.2 |
| GR4 | **A camera for sailing with the push,** close enough to see the rail, the spray and the water ahead (the gusts and the wave faces) | `camera/camera_rig.gd` | GP1 | S | 0.2 |
| GR5 | **The models.** `board.glb` needs a Blender rebuild for the flat tail (`tools/blender.sh tools/blender/build_rig_models.py`; Blender 4.5 is not on Max's PC, see TE2). Nobody has checked the 44 cm fin's look | `Game/assets/models/`, `tools/blender/` | TE2 | S | 0.2 |
| GR6 | **The team's look at the effects and the water** (Phase 7's check, never done): the water's colour, the foam, the far edge, the spray, the wake and the splash | — | the team | S | 0.2 |
| GR7 | **The fleet, seen:** the personas' gear visible (sail sizes and colours) and their names (D5 of AI_FLEET_PLAN.md) | `race/`, `windsurfer/rig_visuals.gd` | RA8 | M | later |

The map's details (the camping, trees, buildings and landmarks) are MA3.

---

## SO Sound

**What there is in 0.1:** every sound is made from noise at startup and shaped by the simulation: the wind, the lapping and the planing hiss, the splashes, and the sail's flutter, crack and swoosh (`Game/audio/`, tested in `tests/unit/test_audio.gd`). Nothing comes from the fin yet.

| ID | Item | Where | Waits on | Size | For |
|---|---|---|---|---|---|
| SO1 | **The fin's voice,** the design's main warning sign and part of package A: a hum that rises in pitch as the fin's lift nears the stall, and breaks up in a spin-out. It is driven by the fin's slip and stall in the telemetry. With it, the rig's load: a creak or strain as the pull nears what the sailor can hold | `audio/sound_bank.gd` (a new loop), `audio/sound_mix.gd`, `audio/sound_mix_config.gd`, `tests/unit/test_audio.gd` | Ready. GP0: the fin's hum would warn of nothing today (no spin-outs until PH6); the rig's strain can follow the sailor's overload (`feet_moment_excess_nm`, the hike used) as "at the edge": at the dial's top it is on half the time, a little more before a catapult | M | 0.2 |
| SO2 | **The board's sounds at the limit:** chatter and slap on chop, louder tail spray when pushing, the leeward spray of a railed board | the same files | Ready (on chop: GP7) | S to M | 0.2 |
| SO3 | **The countdown sounds and the gun** (left over from Phase 9A) | `audio/`, `race/race_hud.gd` | Ready | S | 0.2 |
| SO4 | **The team's careful listen** (Phase 8's check, never done). The list "What to listen for" is in the archived [REBUILD_PLAN.md](Documentation/archive/REBUILD_PLAN.md), phase 8 | — | the team | S | 0.2 |
| SO5 | **The fleet's sound:** the other boards' splashes and sails when they are near you (D5 of AI_FLEET_PLAN.md) | `audio/` | Ready | M | later |
| SO6 | A harmless warning when the game quits, "ObjectDB instances were leaked": Godot does not free sounds that are still playing at that moment | `audio/game_audio.gd` | Ready | S | later |

---

## UI HUD, menus and settings

| ID | Item | Where | Waits on | Size | For |
|---|---|---|---|---|---|
| UI1 | **The sailor's view:** the HUD without trim aids (GD6), part of package A | `ui/hud.gd`, `race/race_hud.gd` | GD6 | S | 0.2 |
| UI2 | **The controls in the menus:** the gamepad's dead zones, the mouse's sensitivity and package B's choices (GP2). The Controls page, the How to sail page ("let go of W/S and it sails itself; push to go faster; ease before a gust") and the README's controls table rewritten for the push | `ui/settings_menu.gd`, `ui/settings_values.gd`, `ui/game_settings.gd`, `ui/controls_page.gd`, `ui/howto_page.gd`, `README.md` | GP1 | S to M | 0.2 |
| UI3 | **The fleet list** fills half the screen with 17 boards or more: show the top few and the boards around you. Also, the HUD cuts `Skippers.make_fleet()`'s numbered labels ("All-rounder 1" shows as "All-rounder") | `race/race_hud.gd`, `race/skippers.gd` | Ready | S | 0.2 |
| UI4 | **The start menu's title** is cut off at the top in a 1280 by 720 window | `ui/start_menu.tscn` | Ready | S | 0.2 |
| UI5 | **Gear as a player choice:** the fin's size and the mast track (Max's U2 question; aft is faster and looser, and livelier in gusts) | `ui/settings_menu.gd`, `Game/config/` | PH18 | S to M | later |

---

## MA The map and the wind

**Owner: Max.** The plan is [MAP_SILVAPLANA_PLAN.md](Documentation/MAP_SILVAPLANA_PLAN.md). The map does not touch `Game/sim/`.

| ID | Item | Where | Waits on | Size | For |
|---|---|---|---|---|---|
| MA1 | **The lake play-test** (M3 and W5): the start spot, the Maloja setting, the shore. Does the wind feel like the Maloja? Is the time of day useful on the HUD? Can you see the gusts coming on the water? | — | Max | S | 0.2 |
| MA2 | **The credits screen** with "Terrain, aerial photos and lakebed: © swisstopo. Wind data: MeteoSwiss. Lake level: BAFU." The open data asks for its source to be named (the map plan, M4) | `ui/` | Ready | S | 0.2 |
| MA3 | **M4, the details:** the camping and the beach (by hand, from the 10 cm photo and Max's notes), trees (a MultiMesh, sized by swissSURFACE3D minus swissALTI3D), the buildings of Silvaplana and Surlej (swissBUILDINGS3D), and the landmarks sailors steer by (the church, the Corvatsch station, the bridge) | `maps/silvaplana/`, `tools/map/`, `tools/blender/` | TE2 | L | later |
| MA4 | **W4b, the tactics tools** in the course maker: lifts and headers against the course, the stronger lanes, laylines, which side paid | `maps/` (the wind viewer) | Max | M | later |
| MA5 | **The day types and the start front** (W3, moved to the plan's Later, L1, by Max): light, medium and strong days, and the front travelling down the lake | `maps/silvaplana/wind/`, `maps/wind/` | Max | M | later |
| MA6 | **Replay a measured day, or today's live wind** (request R7, Later L4), from the Segl-Maria station | `maps/`, `sim/map_wind_field.gd` | Max with Michiel | M | later |
| MA7 | **Other spots** (the map plan's later projects). The general systems (the wind patterns, wind-made waves, the lake's physics) are built so that a new spot gets them | — | the team | L | later |
| MA8 | **The map's tools on the Linux PC** (M0): Blender 4.5, `git lfs install`, `tools/test.sh` | — | the Linux PC | S | later |

Wind-made waves for the lake (Later L2, request R6) are PH11. Other water users (Later L5, request R8) are on the water as the AI fleet.

---

## TE Performance, tools and code

| ID | Item | Where | Waits on | Size | For |
|---|---|---|---|---|---|
| TE1 | **Godot rewrites `Game/default_bus_layout.tres`** on some runs, and every agent has had to restore it. Find out why | `default_bus_layout.tres` | Ready | S | 0.2 |
| TE2 | **Max's PC:** Blender 4.5 LTS (for GR5 and MA3), and the Python packages tifffile, Pillow and imagecodecs for the map's tools | — | Max | S | 0.2 |
| TE3 | **The download is 325 MB** because the lake's terrain and photos are in it. A smaller one needs a lower-resolution set of tiles | `tools/release.sh`, `maps/silvaplana/terrain/` | Ready | M | later |
| TE4 | `windsurfer.gd` could call `_rig.bend_fin(...)` instead of the rig reading its parent's `sim` | `windsurfer/windsurfer.gd`, `windsurfer/rig_visuals.gd` | Ready | S | any |
| TE5 | **The editor build collapses beyond a few boards:** Godot 4.7.2 takes a global engine lock on every read of another object's field. The release build is the way to play a fleet until RA4 removes the physics' remaining locks | — | RA4 | — | — |
| TE6 | The archived RACING_PLAN.md's T1 episode and lap times corrected (7 to 11 minutes, not 3) | `Documentation/archive/RACING_PLAN.md` | Ready | S | any |
| TE7 | **The physics spec is 1 MB (about 7,000 lines).** Its history sections (12, the legacy code's fudges; 13, the legacy contradictions; 16, the tuning log; 17, the implementation notes of each session) could move to an archived companion file, so the live spec is the models, the numbers and the checks. Michiel's document, so his call; links into those sections would be rewritten and checked | `Documentation/PHYSICS_SPEC.md` | Michiel | S | any |

---

## PR The project and releases

| ID | Item | Where | Waits on | Size | For |
|---|---|---|---|---|---|
| PR1 | **A license** for the repository. The old README said MIT; there is no LICENSE file | `LICENSE`, `README.md` | the team | S | 0.2 |
| PR2 | **The GitHub Release page of 0.1.0.** The tag `v0.1.0` is on GitHub. The page with the zip and the changelog's text is made by hand (there is no `gh` on Max's PC); check that it is there | GitHub | Max | S | now |
| PR3 | **The release of 0.2,** with the steps below | `Game/project.godot`, `CHANGELOG.md`, `README.md` | the 0.2 items | S | 0.2 |
| PR4 | **Later** (the rebuild plan): multiplayer, a rigged sailor, more boards and sails, a Linux export, maybe a web build | — | the team | L | later |

---

## How an update is made

1. **Work on a branch** named after the item (`feature/gp3-reaching`; packages built by agents on `<id>/<name>` branches in their own worktrees), in small commits. Run `tools/test.sh` after every change, `tools/check.sh` after scene or resource changes, and take a screenshot for every visual change.
2. **Physics changes** need Michiel's OK, an update of [Documentation/PHYSICS_SPEC.md](Documentation/PHYSICS_SPEC.md) and `tools/test.sh validation`. The map track does not touch `Game/sim/`.
3. **Merge to `main`** when the team agrees: a pull request, or a merge commit with `--no-ff` so the branch stays visible in the history. Nothing goes to `main` without the team. Branches are not deleted; nothing is thrown away.
4. **A session ends** with an entry at the top of the progress log, and with this file brought up to date: a finished item moves to the changelog's next version, a new item gets the next free ID in its section, and an ID is never reused.
5. **A release:**
   - set `config/version` in `Game/project.godot` (the start menu shows it) and the placeholder `v...` text in `Game/ui/start_menu.tscn`;
   - add the version to [CHANGELOG.md](CHANGELOG.md) with the date and what it contains, and update the "Known gaps" of the README;
   - run `tools/check.sh`, `tools/test.sh` and `tools/test.sh validation`, all as expected;
   - run `tools/release.sh build`, then zip `.release/wsim.exe`, `wsim.pck` and `wsim_console.exe` as `WindsurfingSimulator-<version>-windows.zip` (the Windows export templates of Godot 4.7.2 must be installed once; the script's header says how);
   - tag `v<version>` on `main` and push the tag. On GitHub, "Draft a new release" from the tag, with the changelog's section as the text and the zip attached.

## Prompts to continue (for an AI session)

**Version 0.2, the gameplay:** "Read CLAUDE.md and ROADMAP.md (the section 'Version 0.2' and section GP, with Max's direction: easy to just go and a little challenging to go fast; package A, one push dial; package B, an experiment with the rail and the back foot on the mouse, real physics only), then the design, Documentation/gameplay_controls_v0.2.pdf. GP0 is done on the branch `gp0/measure`, which is not merged into main (Max, 26 October): branch from it, because GP1 needs its `PlayerController.pilot_overrides` and the harness. Read [its report](Documentation/reports/gameplay/gp0_measure.md) for the dial's three settings, the warning signs, the mouse's ranges and the follow-ups from Max's play (`tools/push_check.sh` measures again, `tools/play_push.sh` sails the pushed sailor). Build package A (GP1 with SO1, GR1 and UI1) and package B's experiment (GP2), each on its own branch, with Max's answers to GD1 to GD4 and GD7's choices as settings; neither changes anything in Game/sim/. Keep this file's items and the progress log current."

**The AI fleet:** "Read CLAUDE.md, ROADMAP.md (section RA), Documentation/archive/AI_FLEET_PLAN.md and Documentation/archive/P9_PROGRESS.md (F1 to F5 are merged and released in 0.1.0; Max's Stops are RA1). If training nights have run, read `.logs/nights.log` (the lines `=== stage ... over ===` and `check (`) and `.sim_output/train/<run>/curve.csv` first, run the last stage's `--evaluate` against the all-rounder, and say in plain language where the training stands. Then take Max's answers to the Stops and lead RA4 (F6, the big fleet) and RA6 (the personas on the trained head) as the archived RACING_PLAN.md's execution brief describes, with section D7 of the fleet plan on tokens: one agent per package in a worktree on a branch from `main`, extra-high effort only where the brief says so, a stop for Max at each part's Stop. When Max has Fable tokens to spare, build the package yourself. Keep the roadmap and the progress log current after every launch, report and merge, with the token ledger."

**U1 and U2 (after Michiel's review, PH1):** the take-over prompt at the end of the archived [U2_PROGRESS.md](Documentation/archive/U2_PROGRESS.md) applies, with Michiel's answers written into the archived brief and the decisions moved here. The full manoeuvre matrix (`tools/matrix.sh`, `tools/lake_matrix.sh`) is still to be run with the stance, the rig's lean, the fin and the hull as they are now; no manoeuvre was run in U1 or U2.

**The map:** [MAP_SILVAPLANA_PLAN.md](Documentation/MAP_SILVAPLANA_PLAN.md) has its own status table and phases. Continue with section MA here, then the plan's first unticked task.

## Done since the plans were written

Kept here so nothing is lost when the archived plans are read. Phase 9's parts 9A to 9C and the AI fleet's F1 to F5 are built and in 0.1.0. (The archived [RACING_PLAN.md](Documentation/archive/RACING_PLAN.md) still shows 9A and 9B as "built up to" and 9D as open; 9D continues as F5, RA6 and RA10.) Phases 7 and 8 of the rebuild plan are in 0.1.0, with the team's check open (GR6, SO4). U1 and U2 are in 0.1.0, with Michiel's review open (PH1). The archived U1_PROGRESS.md lists the flat tail (U1.4) as reverted; it was brought back in 239cff9 and is in 0.1.0. The decisions of 20 October 2026 in AI_FLEET_PLAN.md stand: wind shadows yes, the rules yes, 20 boards to start, T2 at 60 %, the countdown 60 s, the names stay, and the same controller and the same 3 substeps for everyone.
