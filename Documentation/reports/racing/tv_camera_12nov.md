# The TV camera made like TV, and the water's square gone (12 November 2026)

Max, 12 November 2026, evening, after watching the AI races in the watch mode ([watch_mode_10nov.md](watch_mode_10nov.md)):
"make the tv cam in tv mode more tv like. a few suggestions. use only the drone/helicopter, commety boat down the
start line at the start for looking for overerlues. but vcan override for the drone like camera cams. follow the
front or exiting things. this way watching is more exiting. also there is a square arount thje camera wich is ugly
increase view distance". And, asked where: "its only on open water".

Branch `watch/tv-camera-12nov` (from `ai/starts-fleet-10nov` 5bdaf50), worktree `WindsurfingMMZB-fixes`. Play folder
`WindsurfingMMZB-play-12nov2026-tv` (+ zip) in `source`: the starts6b folder's launchers (their key line updated), the clean
`push_and_body.cfg` of the 10 November starts folder, and three new Film launchers (lake O2, lake SD3, open water T1).
Not yet seen on Max's screen. Backlog E11.S11; roadmap RA33 (the camera; numbered RA31 before the merge of 13 November) and GR14 (the open water's square).

## What changed for the watcher

**T: the TV director** (`Game/race/tv_camera.gd`, `TvCamera`). The camera is flown the way a race is filmed for TV:
drones and a helicopter that glide with the boats, hard cuts between shots, the longer lenses of TV cameras (28 to
50 degrees instead of the game's 75), no low game cameras, no grid on the water.

| Shot | What it shows |
|---|---|
| Chase drone | 24 m behind and 9 m above the board, a little to one side; it swings round with the board through a tack or gybe. |
| Side drone | 32 m abeam, 6 m up, flying along with the board and slowly falling back past it. |
| Helicopter | 110 m out and 29 degrees up, slowly circling the board and the boats round it, on a long lens. |
| Overhead drone | 45 m straight above the board, turning slowly. |
| Group | A fight: the boats within 35 m of the board framed together, from behind and to one side. |
| Mark drone | Waiting 38 m beyond the board's next mark, 22 m up: the boats come towards it and round the mark in front of it. |
| Start, wide | Before the start: high behind the line, the fleet lining up, the line and the course beyond. |
| Committee boat | 10 m behind the committee boat on the line's own line, 11 m up, looking down the line to the pin (on a line shorter than 150 m at a point 150 m down it, so the camera stays level), with the start line drawn on the water: who is over early shows at once. The boat and its flag stay just below the picture. |
| Finish line | The same down the finish line, as the leader comes in. |

What the director does:
- **The start** as a sequence of the race clock: from 40 s before the gun the wide shot; from 12 s before until 7 s
  after the gun the committee boat's view down the line (the over-earlies); until 16 s after, the leaders leaving the
  line (the group shot, or the helicopter over the leader).
- **The front first** ("follow the front or exciting things"): every 7 to 12 s a cut to the board worth watching. The
  leader is worth most, then the second, third and fourth; then a fight (more in the front half of the fleet), a board
  near its mark, a board that just gained a place. A board still to start after the gun (back over the line, or a late
  starter) and a finished board are worth little. The board on the screen counts half, so the camera moves on but may
  stay with a good story.
- **The leaders' mark roundings are never missed:** when one of the first three comes within 70 m of its mark, the
  mark drone takes it (once a rounding), and holds until 4 s after it rounded.
- **The finish:** when the leader is within 140 m of the finish line, the finish line's shot, until 5 s after it finished.
- The shot suits the story: near a mark mostly the mark drone or the overhead drone, in a fight mostly the group,
  otherwise the chase drone, the side drone or the helicopter. Never the same shot twice in a row.

**5 to 9: one TV shot by hand** ("but [I] can override for the drone like camera cams"): 5 the helicopter (5 again
stops or starts its circling), 6 the committee boat down the start line, 7 the chase drone, 8 the side drone, 9 the
overhead drone. The shot stays on the board watched: Tab and L pick another board and the shot goes with it. The wheel
brings the drone nearer or farther. T gives the director back; 1 to 4 your own cameras.

Tab or L while the director is on: the director stops and its shot stays on the board you pick.

## The square on the open water

On the open water the waves are drawn on a square of water that moves with the camera (400 m wide at the Normal draw
distance; Settings > Graphics > Draw distance makes it up to 800 m). Past its edge the water was a flat plane with no
waves at all: no wave shading, no whitecaps, no grid. From the TV camera's height that edge showed as a big square of
waves in a flat, glassy sea. On the lake the far water already drew the lake's waves as shading, so there was no square.

Now (`Game/world/water.gdshader`, `Game/world/ocean.gd`):
- the far plane draws the open sea's waves too, as shading: each wave's exact slope at each pixel (`sea_pixel_surface()`),
  its whitecaps, and the water's clock, as the lake's far plane does. A wave too short for the pixels far out fades out
  and roughens the mirror instead, so the far water does not shimmer;
- the near square's own shading turns into that same per-pixel shading over its outer part (from half to 80 % of the
  way to its edge), and its waves' shape flattens in its last tenth, so near and far meet with nothing to see;
- from high up (the camera more than about 30 m above the water: the drones, the helicopter, an orbit camera wheeled
  far out, the top-down camera) all of the near square is shaded per pixel too. Its vertices are 1 m apart, so the
  shorter waves showed there as broad bands that the per-pixel shading does not have, and from up there that change
  still showed as a softer square;
- the grid fades out before the square's edge.

The sailing cameras, a few metres up, keep the near water's shading exactly as before (checked: the follow camera's
picture before and after differs only in the far band near the horizon, which now has a little wave texture).

## How it works

- `CameraRig.Mode.DIRECTED`: the rig keeps its far plane and calls `director` every frame instead of placing the
  camera itself; it gives the camera its own lens back when the mode changes. `directed_zoom`: the wheel while directed.
  The settings' start camera stays one of the four hand cameras.
- `TvCamera` (a RefCounted owned by `WatchMode`): `begin_auto()` (T), `hold(shot)` (5 to 9), `end()`, `step(real_dt)`
  (the director's cuts, real seconds), `frame(delta)` (the camera, every frame, through the rig). `keep_the_camera()`
  every frame takes the camera back when the scene set its start camera (after `--tv=1`, and at every R): only a camera
  key ends the TV camera. Plain-number helpers for the tests: `story_weights()`, `pick_shot()`, `start_part()`,
  `line_view()`, `orbit_offset()`.
- The camera never goes lower than 2.5 m above the water, nor lower than 12 m above a lake's shore under it
  (`SailingScene.shore_grid`).
- `SailingScene.show_course_lines()` / `course_lines_shown()`: the start and finish lines on the water for the line
  shots (put back as they were after them). `SailingScene.show_water_grid()` and `OceanNode.set_grid_hidden()`: no grid
  while the TV camera has the camera (kept when the water is built again).
- `WatchMode`: the old TV camera's shots and choice of boards moved to `TvCamera`; the bar of keys says
  "1-4 camera", "5-9 TV shots", "T TV director".

## Verified, and what is not

- Tests: `test_watch_mode.gd` 16/16 (the old choice-of-boards tests rewritten for `TvCamera`, and new ones: the front
  first, a late starter little, never the same shot twice, the mark and group shots only when they fit, the start's
  sequence, the committee boat's view straight down the line, the helicopter's height); the effects, draw-distance,
  camera and spectate tests green; the full unit run 1093/1093; `tools/check.sh` 515/0.
- Screenshot sequences at Max's 3137 x 1263 (in `.screenshots/tv/`, not committed): the lake's trapezoid O2 from 10 s
  before the gun to 95 s after, the open water's T1 loop, the lake's sprint slalom SD3 (the mark drone on the leader
  and then the second at mark 1); the open water from the helicopter before and after (the square gone); the sailing
  follow camera before and after.
- The play folder's own game (release build, 3137 x 1263): the open water's committee boat view (level, no flag in
  the picture after the short-line fix) and a drone shot 20 s after the gun; a race sailed yourself with the push and
  body gauges.
- Not checked: the keys 5 to 9 by hand (screenshots cannot press keys), the finish line's shot (no race was run to the
  finish), how the moves feel in motion, slow motion and fast forward with the drones, LAN (the watch mode is never on
  in a LAN game). Max's own screen.
