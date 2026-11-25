# Video analysis: index

Real windsurfing videos that Max picked for the game: the physics of the sail, the board
and the water, plus the map's look and the sailor's control. Each video gets a report here
(`<nn>_<name>.md`) with the findings. The downloaded videos and all their frames live
outside git, in `C:/Users/Max de Dikke/source/WindsurfingMMZB-videos/` (other people's
videos: private study only, never pushed).

Method: download, cut where Max says, frame grids, read the grids with Max first, then
measure. Numbers read off a single camera view are labelled as estimates. The tools are in
`tools/video/`: `analyse.py` (the automatic pass: shots, segments, jump/gybe/straight, water
state, timeline chart, one grid per segment), `video.py` (fetch, info, grid with `--crop`,
frames), `frame_motion.py` (cuts and copied frames) and `sample_colours.py` (median colours in
named boxes), `grid_overlay.py` (labelled pixel grid for reading points), `front_view.py`
(rig lean and board tilt from a camera ahead), `front_bounce.py` (legs over chop), `side_pitch.py`
(pitch against a level line), `reality_check.py` + `reality_cases.json` (the game against the videos).
Progress and pitstops: [PROGRESS.md](PROGRESS.md).

**The main write-up is Max's Claude Doc "Windsurf video analysis"**
(https://claude.ai/artifact/XBjFrrT4r9poau2DYbGnQP, private to Max's account): the method, the
labels, every video, the comparison tables and the ideas for the game. The files here are the
in-repo record.

| # | Video | Where | Conditions | Gear | Status |
|---|---|---|---|---|---|
| 01 | [yWc4jUGIm7c](https://youtube.com/shorts/yWc4jUGIm7c) | Sotavento, Fuerteventura | 35 kn, chop and swell | ~62 cm board, ~5.6 race sail | [report](01_sotavento_speedrun.md), Max's answers in (25 Nov) |
| 02 | [8lpLPppvjso](https://www.youtube.com/shorts/8lpLPppvjso) | unknown | 20-25 kn, medium to low chop | 62 or 72 board, 6.5 or 7.4 race sail | deep analysis 25 Nov (in the doc) |
| 03 | [gkgseKC4zZ4](https://www.youtube.com/shorts/gkgseKC4zZ4) | Netherlands, behind a small dam | 30 kn, flat water | 50 cm wide board, 6.0 freerace sail | deep analysis 25 Nov (in the doc) |
| 04 | [Zk0aWEaSgOg](https://www.youtube.com/shorts/Zk0aWEaSgOg) | Gruissan, Defi Wind | 30-40 kn, medium to low chop | 62 board, 5.6 race sail | deep analysis 25 Nov (in the doc) |
| 05 | [aOh4VOciz3E](https://www.youtube.com/shorts/aOh4VOciz3E) | Tenerife | 25-30 kn, medium to low chop | 62 board, 5.6 race sail | deep analysis 25 Nov (in the doc) |
| 06 | [S64Vlm8PLOY](https://www.youtube.com/shorts/S64Vlm8PLOY) | unknown | 20-25 kn, low to medium chop | 62 board, 5.6 race sail | deep analysis 25 Nov (in the doc) |
| 07 | [UE9JXU4x1b4](https://www.youtube.com/shorts/UE9JXU4x1b4) | unknown | 15-20 kn, low chop | 72 board, 7.4 race sail | deep analysis 25 Nov (in the doc) |
| 08 | [eRZbrmupYwo](https://www.youtube.com/shorts/eRZbrmupYwo) | Bonaire | 20-25 kn, low chop | 72 board, 7.4 race sail | deep analysis 25 Nov (in the doc) |

## 01: Sotavento speed run (added 25 Nov 2026)

Max's context, as he sent it:

```
URL:        https://youtube.com/shorts/yWc4jUGIm7c
Where:      Sotavento, Fuerteventura
Conditions: 35kn chop and swell
gear:       +-62cm board   +-5,6 race sail
What:       speedrun inbetween the swells just of the sandbank in sotavento.
Cut:        full video
Look at:    for the map project. look at the area and colors of the sea and sand For the physics: look for wind water and sail reactions. for the sailor look at controlling of the whole rig
```

## 02 to 07 (added 25 Nov 2026)

Max's context, as he sent it. The first two entries share one link: Max then sent the Bonaire
link (https://www.youtube.com/shorts/eRZbrmupYwo, "this is bonaire"). So the first entry is 02
(8lpLPppvjso, spot unknown) and the second (Bonaire) is 08 (eRZbrmupYwo).

```
URL:      https://www.youtube.com/shorts/8lpLPppvjso
Where:    unknown
Conditions: 20-25kn, medium to low chop
gear:     62cm or 72 board   6,5 or 7,4 race sail
What:     speedrun downwind flying the board on the edge of control.
Cut:      full video
Look at:  . look at the area and colors of the sea and sand For the physics: look for wind water and sail reactions. for the sailor look at controlling of the whole rig

URL:      https://www.youtube.com/shorts/8lpLPppvjso
Where:    bonaire
Conditions: 20-25kn, low chop
gear:     72 board   7,4 race sail
What:     crosswind little downwind flying the board on the edge of control. fly by
Cut:      full video
Look at:  for the map project. look at the area and colors of the sea and sand For the physics: look for wind water and sail reactions. for the sailor look at controlling of the whole rig

URL:      https://www.youtube.com/shorts/gkgseKC4zZ4
Where:    Netherlands behind a small dam
Conditions: 30kn, flat water
gear:     50wide board   6 freerace sail
What:     speedrun downwind flying the board on the edge of control. stand stil shot. with a gybe at the end
Cut:      full video
Look at:  for the map project. look at the area and colors of the sea and sand For the physics: look for wind water and sail reactions. for the sailor look at controlling of the whole rig

URL:      https://www.youtube.com/shorts/Zk0aWEaSgOg
Where:    gruissan at defi wind
Conditions: 30-40kn, medium to low chop you see the beach
gear:     62 wide board   5,6 race sail
What:     crpsswind flying the board on the edge of control. filmed with boat
Cut:      full video
Look at:  for the map project. look at the area and colors of the sea and sand For the physics: look for wind water and sail reactions. for the sailor look at controlling of the whole rig

URL:      https://www.youtube.com/shorts/aOh4VOciz3E
Where:    tenerife
Conditions: 25-30kn, medium to low chop you see the beach
gear:     62 wide board   5,6 race sail
What:     tutorial video of control by nico prien
Cut:      full video
Look at:  for the map project. look at the area and colors of the sea and sand For the physics: look for wind water and sail reactions. for the sailor look at controlling of the whole rig

URL:      https://www.youtube.com/shorts/S64Vlm8PLOY
Where:    unknown
Conditions: 20-25kn, low to medium chop
gear:     62 board   5,6 race sail
What:     crosswind little downwind flying the board on the edge of control.filmed by boat
Cut:      full video
Look at:  for the map project. look at the area and colors of the sea and sand For the physics: look for wind water and sail reactions. for the sailor look at controlling of the whole rig

URL:      https://www.youtube.com/shorts/UE9JXU4x1b4
Where:    unknown
Conditions: 15-20kn, low  chop
gear:     72 board   7,4 race sail
What:     crosswind little upwind flying the board on the edge of control.filmed by drone from the front to see railing and wet area of board
Cut:      full video
Look at:  for the map project. look at the area and colors of the sea and sand For the physics: look for wind water and sail reactions. for the sailor look at controlling of the whole rig
```
