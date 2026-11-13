# Watching and filming the AI races (10 November 2026)

Max, 10 November 2026, evening: "can you make a version only for AI watching and spectating, where I'm the race
director. I want to video a few races so I can broadcast them to Michiel. Or a mode in the launcher for spectator
races, with a few features that are handy for filming and testing for myself."

Branch `watch/broadcast-10nov` (from `ai/skipper-heads-8nov` 372fb72, the AI after phase S's start training).
Backlog: E11.S09. Play folder `WindsurfingMMZB-play-10nov2026-watch` (+ zip). Not yet checked on Max's screen.

## What it is

The watch mode: the player's board stays ashore (parked, as `--spectate=1` already did), only the AI boards race,
and the player is their race director (M). Races follow one another by themselves (the director's gap, 3 minutes by
default). On top of the spectator's Tab, Shift+Tab and L, keys for filming and for testing:

| Key | What it does |
|---|---|
| T | The TV camera. **Changed on 12 November 2026:** the TV director, drones and the committee boat only, the front first: [tv_camera_12nov.md](tv_camera_12nov.md). |
| 5 | The helicopter. **From 12 November 2026** keys 5 to 9 are TV shots by hand: [tv_camera_12nov.md](tv_camera_12nov.md). |
| - + 0 | Slower, faster, normal: 1/4, 1/2, 1, 2, 4, 8 times. |
| P | The race frozen, without a menu; the camera still moves (right mouse, wheel, the circling). P, Esc, R or M go on. |
| H | The screen: full (every card, the keys) -> TV (the race card, the standings, the minimap, the compass, the speed card; no keys, no gauges, no F1 panel; the title "Hana, 3rd" without the keys) -> clean (no HUD at all). |
| N | The names above the boards. |
| I | The AI's head of the board watched: `RaceSkipper.note` (the words the training's race tool prints: "start: away", "beat, keeping clear", "penalty turn: the gybe"), its speed and angle to the wind, the metres to its next mark, its tacks, gybes and penalty turns. |
| R / Shift+R | A new race / the same race again: the same dice (the AI boards' start spots and each skipper's day). The full screen's top-left card shows the race's number and its dice. |
| M | The race director's view, as for a player racing alone; its status also shows the dice. |

How to start it: the Race page's new button "Watch: the AI races, you direct" beside "Start the race" (a button, not a
row: the page must fit the menu's 800 px, `test_menus`); or `--spectate=1` with `--race=`; the play folder's launchers.
Command-line options for launchers and screenshots: `--tv=1`, `--screen=full|tv|clean`, `--speed=<x>` (the nearest
offered), `--head=1`; `--watch=1` puts the menu's focus on the Watch button.

Filming: Windows' Game Bar (Win+Alt+R starts and stops; an .mp4 with sound in Videos\Captures), or OBS.

## How it works

- `Game/race/watch_mode.gd` (`WatchMode`, a node of the sailing scene). `main.gd` makes one when the race is
  watched on this PC alone (`RaceRunner.spectating`, no LAN game) and hands it every key first, also while frozen
  (`_unhandled_input()`); the keys it does not take go on to the scene as before.
- **The race director while watching:** `_add_race_director()` no longer leaves out a spectator on one PC (it was
  left out for `tools/gens.sh`'s viewer, which now gets the director and the watch keys too). The director's view
  gives no autopilot to a parked board (`_give_the_board_to_the_pilot()`): it is not stepped, and while watching the
  race's first board is an AI board's, so the pilot would have read another board's race.
- **The speeds** keep every physics tick at 1/60 s of the race: `Engine.physics_ticks_per_second` and
  `Engine.time_scale` change by the same share (`WatchMode.pace_for()`), the way `NetBoards` slows a LAN guest. So the
  race is the same race at any speed; only the work per real second changes. `max_physics_steps_per_frame` rises
  with the speed (enough for 30 frames a second). Beyond what the PC can step, the race simply goes as fast as it
  can, and the card says so ("this PC manages 3.2x", measured from the race clock against the real clock). Physics
  interpolation (on in project.godot) keeps slow motion smooth. Everything goes back to normal when the scene ends
  (`_exit_tree()`).
- **The in-between time of the water, the wake and the course lines** (`ocean.gd`, `effects.gd`,
  `course_on_water.gd`) was `1 / ticks per second`; it is now `time_scale / ticks per second`, the length of a tick
  in the race's time. In normal play the two are the same; in slow motion the old one made the water jump four
  times too far within each tick. The LAN guest's slow-down had the same small error.
- **The water's clock while watching (a bug fixed):** the drawn water runs on the player's board's simulation clock
  (`main.gd` gives the ocean `_windsurfer.sim`), and a parked board is not stepped, so the waves on the screen stood
  still whenever someone spectated (also in LAN). `RaceRunner._keep_the_parked_boards_clock()` gives the parked
  board the clock of a board that sails (all boards' clocks start at 0 at a start and run together), so the waves
  drawn are the ones the AI boards float on. `test_spectate` checked "not stepped" by that clock; it now checks the
  position and the heading, and that the clock is the race's.
- **The TV camera** (`_tv_step()`, `_cut()`): a board is drawn by weight (`story_weights()`: the leader +2, a board
  within 25 m of another racing board +3, within 70 m of its next mark +4, a finished board 0.2, the board on the
  screen x0.15) and a shot (follow, behind and high, beside, in front, the helicopter, overhead; never the same twice;
  near a mark the high and overhead shots more often). The orbit shots are placed from the board's heading
  (`_yaw_of()`: that azimuth is right behind it) and some circle slowly (`CameraRig.orbit_drift_rad_s`, new). The
  camera follows the board through `RaceRunner.watch_board()` (new): the spectator's choice, not following the
  leader by itself.
- **Shift+R:** `RaceRunner.last_dice` is the dice of the last start; `repeat_dice` makes the next start (only that
  one) throw the same. The wind's gusts run on with their own clock, so it is the same start, not a perfect replay.
- **The screens:** `Hud.set_tv_screen()` hides the keys, the gauges and the detail panel; `Hud.set_watch_keys()`
  puts the watch keys along the bottom; `RaceHud.plain_title` drops the spectator's keys from the title. The clean
  screen hides the HUD layer (not while the director's view is open: that view hides it itself). The names: the watch
  mode sets every AI board's label each frame, after the scene's own rule (the board watched has none).
- The orbit camera may be wheeled out to 400 m while watching (`CameraRig.orbit_max_m`; sailing keeps 60 m).

## Checked

- `tools/check.sh`: 504 files, 0 failed.
- Unit tests: the full run 1039 of 1041 before two fixes (the Race page's height with a "You" row, which became the
  button; the spectate test's clock check); then `test_menus` 11/11, `test_spectate` 11/11 and the new
  `test_watch_mode` 9/9 (the speeds keep 1/60 s a tick, the nearest speed, the TV camera's weights, the plain title,
  the Race page's watch setup never alone).
- The release build started the film launcher's race (TV camera, TV screen, 2x, the head card) on the lake with 11
  personas for 1500 frames without a script error. No screenshots were judged (Max asked to skip them for speed).

## Open (E11.S09)

- Max's look on his screen (3137 x 1263): the TV camera's shots and pace, the cards' places, the slow motion's
  smoothness, how fast 4x and 8x really go with 11 boards on his PC.
- The in-game Controls page lists the watch keys.
- A film straight to a file with Godot's Movie Maker (`--write-movie`, smooth at any frame rate, the race slower
  than real time while it records): whether it works in the release build, and the files' size.
- Fixed cameras at the marks and on the start boat for the TV camera.
- Shift+R with the gusts too (the wind's clock set back with the dice), for an exact replay of a start.
- The AI's head for a learned brain (`LearnedSkipper` writes no note).
- The watch keys for a LAN spectator (without the speeds: the host keeps the pace).
