# LAN multiplayer, part 2: the race director, up to 8 players, joining late (plan and progress)

**The ask** (Max, 6 November 2026, after play-testing the morning build `WindsurfingMMZB-play-6nov2026-morning`):

> the next thing i want is a fully working lan multiplayer that i can do:
> - the course editor in real time synced so i as host can change the course. this is done in game directly in multiplayer in the wind viewer and course maker from earlier. the ai sailors can adapt without reloading where the start is and when the next start is. i as host act as a race director also now. for now you can change your gear between starts and not while racing (ai to).
> - people can join after the host has started it.
> - the buoys and committee boat need to be bigger [...] also the buoys update realtime what the host changes
> - in the ui everything is in the left top corner, make it more over the whole screen.
> - make the minimap update realtime from what the host does. and make the minimap bigger and in the settings how big it is.

**Max's answers to the questions** (6 November 2026):
1. Players: **up to 8** (the host and 7 guests), with the AI fleet.
2. While the host has the course maker open, **the autopilot sails the host's board** (and races it); closing the course maker gives the board back.
3. The next start: **automatic, the host can change it**: when a race ends the next countdown is planned by itself (3 minutes after the race ends by default); the host can start it sooner or later and change the countdown's length. Everyone sees the time; the AI boards sail to the line for it.

**Who builds what** (branches from `night2/look` 707888e, the build Max played):
- `mp/race-director` (this branch, worktree `WindsurfingMMZB-playtest`): the lead, Claude Opus 5.5: everything in this file.
- `ui/race-screen` (an Opus agent): the buoys (1.2 m by 0.7 m cylinders), the committee boat, the HUD over the whole screen, the minimap's size setting, and `CourseOnWater.set_course()` / the minimap's course redrawn live, which this branch calls.
- `gr/sailor-polish` and `ph44/swan` (Opus agents): the sailor's animation and the straps; SWAN and the waves' height. Not LAN.

---

## 1. The design (decisions by Claude, with the reasons)

| # | Decision | Why |
|---|---|---|
| R1 | **Up to 8 players**: `Lan.MAX_PLAYERS` 8. Every PC still sails only its own board (D3 of PLAN.md); a guest's states go to every other PC through the host (Godot's server relay), the host's and the AI boards' from the host. A guest takes a board's states only from the PC that sails it. | Max's answer 1. The relay is built into Godot; nothing is simulated twice. |
| R2 | **Joining late**: the host lets a guest in while the game runs. The guest loads the scene and gets everything as it is now: the AI fleet, every board's keyframe, the course as the race director has it, the race and the next start. It sails free and races **from the next start** (it is put into the race when the next countdown begins). Its arrival does not restart anyone's race. | Max: "people can join after the host has started it". Joining a race already under way would make an unfair start. |
| R3 | **Gear between starts**: a board's gear can change only while no race is under way (between the end of a race and the gun of the next). The player opens **Change gear** in the menu (Esc); the board is rebuilt on the new gear where it is. The AI boards choose their gear for the wind of the moment at every new countdown. A board's new gear travels as a new keyframe with a new number (its *epoch*), so no PC writes an old board's states into the new one. | Max: "you can change your gear between starts and not while racing (ai too)". |
| R4 | **A race after a race, without reloading**: when a race ends (every board in, the finish window, or the time limit), the next countdown is planned GAP after it (3 minutes by default); when it begins, a new race is built with the boards **where they are** (no one is moved): the AI boards sail free until then and to the line during the countdown, as they already do in a race from the menu with free sailing first. The race director can start the countdown now, move it by a minute, change the countdown's and the gap's length and the laps, abandon a race, or put everyone back at the line (the old R). | Max's answer 3; "the ai sailors can adapt without reloading where the start is and when the next start is". |
| R5 | **The race director's view** (the host; also in a race alone): **M** opens it: the camera goes up above the lake (the wind viewer's map camera: W A S D, the wheel, the right mouse), the wind viewer's streaks and speed colours on the lake (V and C), the course maker's panel on the right with the race's course, a race director panel on the left (the next start, the countdown, the gap, laps, abandon, everyone to the line), every board as a dot with its name. While it is open the autopilot (an all-rounder skipper) sails and races the host's board. M or Esc closes it. | Max: "this is done in game directly in multiplayer in the wind viewer and course maker from earlier"; his answer 2. |
| R6 | **The course is live**: every change the race director makes goes to every PC at once (at most 10 times a second while a mark is dragged, and once more when it is let go), as the course's own JSON in game metres. Each PC puts it on the water, on the minimap and into the race. **During a race only the marks' places change** (dragging marks or lines, turning or resizing the course): the race's steps keep their order and every board its progress; the AI sails to the mark where it is now. Changes that alter the course's shape (a template, adding or deleting a mark, the order, loading, clearing) wait until no race is under way: the course maker refuses them during a race with a message. | A race committee moves marks during a race; changing which marks are sailed mid-race would leave the boards' progress meaningless. |

## 2. The steps

| Step | What | Test |
|---|---|---|
| S1 | 8 players, the relay, joining late, the keyframe's epoch, gear changes over the network (`WindsurferNode.change_gear()`). | `tools/lan_test.sh --guests=2 --late=20`: three instances, one joining 20 s late; every pair's sync check. |
| S2 | The race after a race (`RaceRunner.new_start()`, `RaceDirector` schedule), the next start on every PC's HUD, the AI's gear at each countdown, Change gear in the menu. | Unit tests; a LAN run with a short time limit and gap: two races in a row on both PCs, the same results. |
| S3 | The race director's view (M), the live course (`RaceSim.refresh_course()`, `SailingScene.apply_course()`), the host's board on the autopilot. | Unit tests for refresh_course; a LAN run where the host moves a mark by script: the guest's course and buoys follow, the AI rounds the mark where it now is; screenshots of the view at 1280x720 and 3137x1263. |
| S4 | Merge `ui/race-screen` (set_course, the minimap), the checks, a play folder for Max. | `tools/check.sh`, `tools/test.sh`, `tools/lan_test.sh --release=1`. |

## Progress log (newest first)

### 6 November 2026, midday: the plan
The plan above, from reading `Game/net/`, `Game/race/race_runner.gd`, `race_sim.gd`, `skipper.gd`, `Game/maps/course/course_editor.gd`, `Game/maps/silvaplana/wind_viewer.gd` and `main.gd`. Facts it rests on: the AI reads its next mark's place from `RaceSim.next_step()` every time it thinks, so marks moved in the race's steps reach it at once; `RaceSim` copies the marks' places into its steps when it is built, so it needs `refresh_course()`; `GearChoice.sim_with()` builds a board's simulation on new gear in the same place, wind and sea, so a board can change gear without a new scene; Godot's `SceneMultiplayer.server_relay` passes a guest's messages to the other guests.

## Token ledger
| When | What | Tokens (estimate) |
|---|---|---|
| 6 Nov midday | Three Opus agents launched (sailor polish, SWAN, race screen) | reported when they finish |
