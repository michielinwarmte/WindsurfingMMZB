# The TV director set to the real stream (27 November 2026)

Max, 27 November 2026: "the drone shots trained on real data". Phase P4 of the [broadcast plan](PLAN.md), backlog E11.S11. Branch `broadcast/tv-director`.

On 12 November the game got a TV director for watched races (T in watch mode, [tv_camera_12nov.md](../racing/tv_camera_12nov.md)). Its numbers were chosen by hand. Tonight two readers wrote down every shot of nine real slalom heat replays (393 beats), and the lead measured where the stream's drones fly ([drone_position.md](drone_position.md), on the lead's branch). The game's director now films a race the way those numbers say, phase by phase. A check sets the game beside the stream.

**Not seen on Max's screen yet.** Everything below was checked with tests, headless races and screenshots.

## How to watch it

- In watch mode, **T** starts the director. It is now the stream's director.
- The old director of 12 November is still there, unchanged, for comparing: start the game with `--tv_director=12nov`. For example, on open water: `tools/play.sh res://main.tscn --course=template:PD3@60 --skippers=allrounder,cautious,gambler,rookie --spectate=1 --tv=1 --tv_director=12nov` (without the last option: the stream's).
- The keys by hand stay: **5** the helicopter and **9** the overhead drone (as on 12 November; the stream never uses them), **6** the view down the start line, **7** the drone behind and to the side, **8** the drone beside the board (these three now framed like the stream). The wheel still brings the drone nearer or farther: the sail gets bigger or smaller, the horizon stays where it is.

## A picture is set by what you see, not by metres

The stream's lens and the drone's distance can't be read off the video. What the readers could write down is the picture:

- **the sail's height** as a share of the picture's height (from the board to the mast top), and
- **where the horizon sits**, as a share of the picture's height from the top.

The game works back from those two. A drone has a lens (47 degrees of vertical view, see below); from the lens and the board's real sail the game works out how far away and how high the drone must be to give that picture (`TvFraming.drone_place()`). The beach cam stands where it can (on the shore, or on a camera boat) and works out its zoom instead (`TvFraming.lens_place()`). Both look down just enough to put the horizon where the stream has it.

The shares are of the picture's **height**. The game's camera keeps its height of view in any window shape, so the picture is the same in a 16:9 window and in Max's 3137 x 1263 (a test checks this, and the screenshots below show it).

Three things come from the lead's drone measurement:

- **The lens: 47 degrees** for every drone. The lead measured between 47 and 59 degrees on four passes; 47 is a camera drone's standard wide lens. A choice inside a measured range, not a measurement.
- **Where the board sits in the picture.** The lead measured how high the drone flies in "sail heights" without needing the lens: the sail's foot stands that many sail heights below the horizon (2.4 to 3.0 for the race's drones). The game uses those numbers to place the sail in each picture, so its drones fly at the stream's height in sail heights.
- **The sail's real top.** A slalom rig at speed is raked back and leaned to windward; its top is lower than the mast is long, and from behind it looks shorter than from ahead. The game frames on the board's real drawn mast top (its height and its lean towards the camera), not on the mast's length.

**What that shows (a finding):** the game's sails stand taller than the stream's. At speed their top is about 4.9 m above the water; the lead's estimate for the real riders is 3.5 m. So for the same picture the game's drones fly higher and farther in metres (about 12 m up and 40 to 55 m away behind the leader, against the stream's 7 m and 23 m), while in sail heights they are where the stream's are. Whether the rigs should stand lower at speed is a physics question for Michiel (rake and lean), not a camera one.

## Phase by phase: the stream and the game

The four phases (Max's), by the race clock: **before the start**, **the start** (10 s before the gun to 12 s after it), **the race** (until the race has ended), **after the race** (until the next countdown).

| Phase | The stream (nine heats) | The game now (12 November in brackets) |
|---|---|---|
| Before the start | More than half a line-up graphic. The live pictures: the long lens on the beach, wide and still, on the fleet milling (sail 3 %, horizon low at 70 %) and on the line; now and then a drone on the line. Takes 9 s in the middle (5 to 20). | The long lens wide on the fleet and the line (84 % of the live time, as the stream's), a drone on the line now and then; the graphic is left for phase P5. Takes drawn from the stream's spread. (Before: the usual drone shots, from 40 s before the gun a high drone behind the line.) |
| The start | The long lens wide on the line; 1 to 4 s before the gun a static low drone at the end of the line, the fleet sailing at it; just after the gun a drone runs with the fleet off the line for 8 to 12 s. The first cut more than 1 s after the gun: 8 s in the middle. | The same sequence: the long lens wide on the line from 10 s before the gun; the line drone (Max's committee boat view, the line drawn) about 3 s before the gun (drawn 2.6 to 3.7 s, as counted); just after the gun (0.6 to 1.8 s) a drone behind or ahead of the front runs with the fleet for 8 to 12 s. (Before: the committee boat from 12 s before to 7 s after the gun, then the group or the helicopter.) |
| The race | 90 % drone, 10 % the long lens. On the leader or the lead group 52 %, a mark 22 %, the pack 12 %, the fleet 7 %, the finish 7 %. The drone travels with the boards (63 %), from behind and to the side, from ahead and to the side, from the side, about equally; never straight down, no circling. Takes 8 s in the middle, a quarter under 5 s, a quarter over 12 s. At a mark a drone is already waiting; the cut 2 to 5 s before the leader arrives; then often the chasers at the same mark, then the leader again. At the finish the drone flies through the line with the winner, or a drone hovers side-on at the line and holds while the places come in. | Free takes drawn by the stream's shares of picture and subject; takes from the stream's spread (not an even 7 to 12 s); the new drone ahead and to the side; the beach cam tight on the leader now and then; the pack closer and steeper. Marks: the cut 2 to 5 s before the leader arrives (by its speed), the hold until the gybe is done (4 to 16 s), the chasers at the same mark in 7 of 10 marks, then back to the leader. The finish: fly-through or the side-on hover (half and half). The helicopter and the overhead drone only by hand. (Before: chase, side, helicopter, overhead, group, mark drones at random, a cut every 7 to 12 s, the mark drone 22 m up, the finish line's view down the line.) |
| After the race | Mostly interviews. What a game can take: the long lens close on the winner sailing in (20 to 30 s), a drone with the finishers, a high drone pulling out. | Exactly those three: the long lens on the winner first (20 to 30 s), then drawn by the stream's shares. (Before: the director cut on as in the race.) |

## The check: the game beside the stream

How it works: a watched race runs headless in the real sailing scene with the director on and every take written down (`--tv_log=`): its phase, its picture (camera, view, what it is on), the place of the board it is on, its length, and the framing **measured from the real camera and the real board** every frame (the sail's share of the picture's height, the horizon's place, the drone's height in sail heights, its height, distance, look-down angle and angle round the board, the lens), not taken from the settings. Then `tools/broadcast/director_check.py` sets it beside `stream_profile.json`, phase by phase, and writes a report (`.sim_output/tv_check/<run>/report.md`).

The commands (one race after the other, the boards on one core; a race of about 6 minutes takes 15 to 25 minutes while the PC is busy):

```
tools/tv_check.sh --map=res://maps/sotavento/sail_sotavento.tscn --course=pwa_slalom_x --races=3 --seed=11 --run=sotavento --gap=90
tools/tv_check.sh --map=lake --races=2 --seed=11 --run=lake --gap=90
tools/tv_check.sh --map=open --races=3                       # the open water's sprint slalom (PD3 at 60 %)
tools/tv_check.sh --director=12nov ...                       # the 12 November director, the same way
tools/tv_check.sh --report_only=1 --run=<name>               # the report again from a run's logs
```

`--map=` takes `open`, `lake` or any map's sailing scene (`res://...tscn`, with `--course=` one of its courses).

**The tolerances** (stated in each table's heading): a take's middle length within 20 % of the stream's, its quarters within 30 %; a picture's, a camera's, a subject's share of the phase's time within 5 points; the drone's view and the camera's move within 8 points (the readers agreed on the side for only 58 % of the seconds); the sail's middle height within 2 points or 25 %; the horizon's within 7 points (the readers rounded to 5); the drone's height and distance inside the lead's middle half, its look-down within 5 degrees; the beach cam's eye within 3.5 to 5 m and its zoom (for a 3.5 m sail) within the lead's range; the first cut after the gun within 3 s.

**What the check rests on.** Tonight's races, each with 8 boards (as the stream's heats), the AI at the game's level, 18 kt:
- **Sotavento, the course rebuilt from the replays**: 2 races with the final director (`sotavento_course3`), 3 races one step earlier (`sotavento_course2`: before the race phase's end and "back to the leader after the pack"; its first race also before the beach cam's reach rule), 1 race with the 12 November director (`sotavento_12nov_course2`).
- **Lake Silvaplana, T2**: 1 race with the final director, 3 earlier.
- Earlier, on the first (too small) Sotavento course and on the open water, 5 races that led to the fixes below; not counted.
A race of about 6 minutes took 20 to 30 minutes while the PC was busy, one core each; that is what the night allowed.

**The race, the main numbers** (stream against game; "inside" for the final director):

| | Stream (9 heats) | Final (2 races) | One step earlier (3 races) | 12 November (1 race) | Tolerance | Inside |
|---|---|---|---|---|---|---|
| Take length, quarters (s) | 5.0 / 8.1 / 12.2 | 5.5 / 7.4 / 10.7 | 5.2 / 7.5 / 11.2 | 7.7 / 9.3 / 10.4 | 30 / 20 / 30 % | yes |
| Drone / beach cam | 90.5 / 9.5 % | 98.5 / 1.5 % | 83.5 / 16.5 % | 100 / 0 % | 5 points | no |
| On the leader, at a mark, the pack, the fleet, the finish | 51.9 / 21.8 / 12.1 / 7.2 / 7.0 % | 50.2 / 17.5 / 22.6 / 4.2 / 5.5 % | 50.0 / 15.1 / 27.5 / 3.1 / 4.3 % | (labels differ: 16.7 / 23.5 / 54.8 / 0 / 5.0 %) | 5 points | yes, yes, no, yes, yes |
| The drone's side: behind, beside, ahead | 39.0 / 35.2 / 25.8 % | 39.1 / 30.6 / 30.3 % | 45.2 / 35.3 / 19.5 % | 31.7 / 25.0 / 23.5 % (+ helicopter 13.8, straight down 6.0) | 8 points | yes |
| The camera follows, pans, stands still | 62.6 / 22.1 / 14.7 % | 76.5 / 9.0 / 14.6 % | 68.0 / 23.0 / 9.0 % | 57.7 / 23.5 / 5.0 % (+ circling 13.8) | 8 points | no, no, yes |
| The drone's height, in sail heights (behind-side on the leader) | 2.5 (2.3 to 3.0) | 2.50 | 2.52 | 1.86 | middle half | yes |
| The first cut more than 1 s after the gun (s, middle) | 8.4 | 9.7 | 11.3 | 7.0 | 3 s | yes |
| A take at a mark (s, middle) | 6.7 | 6.3 | 6.2 | 8.5 | 20 % | yes |
| The cut to a mark before the leader arrives (s, middle) | 2 to 5 | 3.1 | 2.3 | 3.8 | 2 to 5 | yes |

**How steady.** Between races the take lengths hardly move (the middle 7.2 to 8.0 s in all five races on the rebuilt course); the shares move a lot from one 4-minute race to the next: the leader 43 to 58 %, the marks 12 to 20 %, the pack 16 to 39 %, the beach cam 1 to 25 %. Five races are enough for the take lengths and the timing, not yet for the shares to a few points.

**What the numbers say.**
- The take lengths, the start's and the marks' timing, the drone's sides and its height in sail heights are the stream's.
- The leader, the marks, the finish and the fleet are inside or near; **the pack gets too much** (22.6 % against 12.1). Each change tonight brought it down (39 % in the worst earlier race); the next step would be to lower the pack pictures' weight a little, on more races.
- **The beach cam** swings: 16.5 % before the reach rule, 1.5 % after it on this long course, where the leaders are mostly more than a kilometre from the beach camera and the zoom stops at 1 degree. The stream's 9.5 % lies between. The reach rule's threshold (`lens_reach_share`, 0.6) is the number to set: about 0.4 would let the beach cam film the leaders at the marks a kilometre off at about 40 % of the asked sail. Not tried tonight.
- **The pans** fell with the beach cam (most pans are the beach cam's).
- Before the start the game has more drones than the stream (37 % against 16 %): the pre-start is shorter in the game (50 s against 90 s) and its few takes swing; after the race the game films the winner (the stream's live pictures after the race are mostly riders sailing in and the podium, which the readers counted as "one rider", the pack).

The tables in full (from `.sim_output/tv_check/<run>/report.md`, not committed):

### Sotavento, the course rebuilt from the replays, the final director (2 races)

All checks: 112 inside the tolerance, 81 outside (`.sim_output/tv_check/sotavento_course3/report.md` has every table).

**The race** (the stream: 199 s per heat)

*How long a take lasts*

| | Stream (s) | Game (s) | Inside |
|---|---|---|---|
| first quarter | 5.0 | 5.5 | yes |
| middle | 8.1 | 7.4 | yes |
| third quarter | 12.2 | 10.7 | yes |

*Time per camera*

| | Stream | Game | Inside |
|---|---|---|---|
| drone | 90.5 % | 98.5 % | **no** |
| shore_long_lens | 9.5 % | 1.5 % | **no** |

*Time per subject*

| | Stream | Game | Inside |
|---|---|---|---|
| front | 51.9 % | 50.2 % | yes |
| mark | 21.8 % | 17.5 % | yes |
| pack | 12.1 % | 22.6 % | **no** |
| line | 7.0 % | 5.5 % | yes |
| fleet | 7.2 % | 4.2 % | yes |

*The drone's view*

| | Stream | Game | Inside |
|---|---|---|---|
| behind_side | 39.0 % | 39.1 % | yes |
| side | 35.2 % | 30.6 % | yes |
| front_side | 25.8 % | 30.3 % | yes |

*How the camera moves*

| | Stream | Game | Inside |
|---|---|---|---|
| follows | 62.6 % | 76.5 % | **no** |
| pan | 22.1 % | 9.0 % | **no** |
| static | 14.7 % | 14.6 % | yes |
| orbit | 0.3 % | 0.0 % | - |

*The framing per picture, as measured on the screen*

| Picture | Time | Sail: stream | Sail: game | Inside | Horizon: stream | Horizon: game | Out of the picture | Inside |
|---|---|---|---|---|---|---|---|---|
| drone front_side front | 27 % | 15 % | 14.3 % | yes | 35 % | 36.3 % | 0 % | yes |
| drone behind_side front | 20 % | 15 % | 13.2 % | yes | 25 % | 22.3 % | 0 % | yes |
| drone side pack | 17 % | 10 % | 7.9 % | yes | 25 % | 40.0 % | 0 % | **no** |
| drone behind_side mark | 9 % | 20 % | 18.3 % | yes | 15 % | 15.0 % | 0 % | yes |
| drone behind_side pack | 6 % | 20 % | 14.0 % | **no** | 15 % | 21.0 % | 0 % | yes |
| drone side line | 5 % | 5 % | 4.4 % | yes | 25 % | 27.0 % | 0 % | yes |
| drone side mark | 5 % | 15 % | 16.0 % | yes | 25 % | 21.3 % | 0 % | yes |
| drone behind_side fleet | 4 % | 15 % | 9.2 % | **no** | 35 % | 40.3 % | 0 % | yes |
| drone side front | 3 % | 10 % | 4.9 % | **no** | 35 % | 35.0 % | 0 % | yes |
| drone front_side mark | 3 % | 10 % | 21.2 % | **no** | 25 % | 5.2 % | 0 % | **no** |

*The beach cam*

| Picture | Eye: stream | Eye: game | Inside | Zoom: stream | Zoom: game | Zoom for a 3.5 m sail | Inside | Distance: game | Horizon: game |
|---|---|---|---|---|---|---|---|---|---|
| shore_long_lens shore mark | 4.5 m (3.5 to 5.0) | 4.5 m | yes | 1 to 4.0 deg | 1.0 deg | 0.7 deg | **no** | 1193 m | 30 % |
| shore_long_lens shore front | 4.5 m (3.5 to 5.0) | 4.5 m | yes | 1 to 1.5 deg | 1.0 deg | 0.7 deg | **no** | 679 m | 25 % |

*Where the drone is*

| Picture | Sail heights: stream | Sail heights: game | Inside | Height: stream | Height: game | Inside | Distance: stream | Distance: game | Inside | Looks down: stream | Looks down: game | Inside | Angle round the board: game | Lens: game | The game's sail top (height / sail heights) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| drone front_side front | 2.40 (1.90 to 2.70) | 2.42 | yes | 9.0 m (7.0 to 10.2) | 12.5 m | **no** | 37 m (29 to 43) | 39 m | yes | 15 deg | 17 deg | yes | 130 deg | 47.0 deg | 5.1 m (the stream's: about 3.5) |
| drone behind_side front | 2.50 (2.30 to 3.00) | 2.50 | yes | 6.9 m (6.1 to 8.9) | 12.0 m | **no** | 23 m (17 to 29) | 41 m | **no** | 21 deg | 16 deg | **no** | 39 deg | 47.0 deg | 4.8 m (the stream's: about 3.5) |
| drone side pack | - | 2.72 | - | - | 13.5 m | - | - | 72 m | - | - | 11 deg | - | 84 deg | 47.0 deg | 5.0 m (the stream's: about 3.5) |
| drone behind_side mark | 2.70 (2.20 to 4.10) | 2.75 | yes | 6.1 m (5.7 to 10.5) | 13.2 m | **no** | 14 m (10 to 19) | 29 m | **no** | 24 deg | 25 deg | yes | 139 deg | 47.0 deg | 4.8 m (the stream's: about 3.5) |
| drone behind_side pack | 2.40 (2.00 to 3.40) | 2.40 | yes | 6.5 m (4.8 to 8.8) | 12.1 m | **no** | 18 m (12 to 21) | 41 m | **no** | 23 deg | 17 deg | **no** | 41 deg | 47.0 deg | 5.0 m (the stream's: about 3.5) |
| drone side line | - | 2.73 | - | - | 13.9 m | - | - | 137 m | - | - | 6 deg | - | 102 deg | 47.0 deg | 5.1 m (the stream's: about 3.5) |
| drone side mark | 3.00 (2.10 to 5.50) | 3.06 | yes | 9.6 m (6.9 to 18.0) | 14.2 m | yes | 32 m (22 to 45) | 37 m | yes | 16 deg | 21 deg | **no** | 103 deg | 47.0 deg | 4.7 m (the stream's: about 3.5) |
| drone behind_side fleet | 2.50 (1.90 to 3.00) | 2.51 | yes | - | 12.5 m | - | - | 61 m | - | 18 deg | 12 deg | **no** | 42 deg | 47.0 deg | 5.0 m (the stream's: about 3.5) |
| drone side front | 3.00 (2.00 to 3.20) | 3.04 | yes | 9.7 m (6.7 to 10.6) | 15.5 m | **no** | 28 m (20 to 48) | 119 m | **no** | 20 deg | 7 deg | **no** | 86 deg | 47.0 deg | 5.1 m (the stream's: about 3.5) |
| drone front_side mark | 3.00 (2.30 to 3.20) | 3.14 | yes | 11.4 m (8.6 to 12.1) | 13.9 m | **no** | 39 m (22 to 60) | 29 m | yes | 16 deg | 26 deg | **no** | 145 deg | 47.0 deg | 4.4 m (the stream's: about 3.5) |

*The start, the marks and the finish in the race*

| | Stream | Game | Inside |
|---|---|---|---|
| The first cut more than 1 s after the gun, s (quarters; middle within 3 s) | 4.7 / 8.4 / 10.3 | 9.6 / 9.7 / 9.7 | yes |
| A take at a mark, s (quarters; middle within 20 %) | 5.4 / 6.7 / 9.4 | 5.4 / 6.3 / 7.9 | yes |
| The cut to a mark comes before its board arrives, s (the notes: 2 to 5) | 2 to 5 | 2.2 / 3.1 / 3.4 | yes |
| Takes at a mark per race | - | 7.0 | - |

**Before the start**

*How long a take lasts*

| | Stream (s) | Game (s) | Inside |
|---|---|---|---|
| first quarter | 4.9 | 8.4 | **no** |
| middle | 9.0 | 12.0 | **no** |
| third quarter | 19.8 | 14.1 | yes |

*Time per camera*

| | Stream | Game | Inside |
|---|---|---|---|
| shore_long_lens | 83.9 % | 63.0 % | **no** |
| drone | 16.1 % | 36.9 % | **no** |

*Time per subject*

| | Stream | Game | Inside |
|---|---|---|---|
| fleet | 59.6 % | 36.9 % | **no** |
| line | 38.2 % | 39.0 % | yes |
| pack | 2.2 % | 24.2 % | **no** |

**The start**

*How long a take lasts*

| | Stream (s) | Game (s) | Inside |
|---|---|---|---|
| first quarter | 4.8 | 3.4 | yes |
| middle | 8.0 | 8.4 | yes |
| third quarter | 12.0 | 9.2 | yes |

*Time per camera*

| | Stream | Game | Inside |
|---|---|---|---|
| drone | 67.6 % | 68.9 % | yes |
| shore_long_lens | 32.4 % | 31.1 % | yes |

*Time per subject*

| | Stream | Game | Inside |
|---|---|---|---|
| line | 72.2 % | 47.7 % | **no** |
| front | 9.5 % | 31.7 % | **no** |
| fleet | 18.3 % | 20.6 % | yes |

*The start's timing*

| | Stream | Game | Inside |
|---|---|---|---|
| The line drone comes, s before the gun (quarters; the stream counted on nine heats, the notes say 1 to 4) | 2.6 / 3.1 / 3.7 | 1.6 / 4.7 / 4.7 | **no** |

**After the race**

*How long a take lasts*

| | Stream (s) | Game (s) | Inside |
|---|---|---|---|
| first quarter | 9.7 | 12.2 | yes |
| middle | 19.0 | 16.5 | yes |
| third quarter | 31.7 | 25.9 | yes |

*Time per camera*

| | Stream | Game | Inside |
|---|---|---|---|
| drone | 48.2 % | 58.4 % | **no** |
| shore_long_lens | 51.8 % | 41.6 % | **no** |

*Time per subject*

| | Stream | Game | Inside |
|---|---|---|---|
| front | 38.5 % | 81.2 % | **no** |
| pack | 35.4 % | 0.0 % | **no** |
| scenery | 13.7 % | 18.8 % | **no** |
| mark | 11.1 % | 0.0 % | **no** |
| line | 1.3 % | 0.0 % | yes |

### How steady from race to race

The final director (`sotavento_course3`):

| Race | Race takes (middle, s) | On the front | At a mark | The pack | Beach cam | Race seconds |
|---|---|---|---|---|---|---|
| race_1 | 7.2 | 43 % | 15 % | 29 % | 2 % | 267 |
| race_2 | 7.7 | 58 % | 20 % | 16 % | 1 % | 264 |
| lowest to highest | 7.2 to 7.7 | 42.5 to 58.0 | 15.2 to 19.8 | 16.1 to 29.1 | 1.2 to 1.9 | 264.5 to 267.5 |

The director just before its last two changes (the race phase's end, back to the leader after the pack), on the same course (`sotavento_course2`, its first race also before the zoom's reach rule):

| Race | Race takes (middle, s) | On the front | At a mark | The pack | Beach cam | Race seconds |
|---|---|---|---|---|---|---|
| race_1 | 8.0 | 50 % | 17 % | 23 % | 10 % | 305 |
| race_2 | 7.3 | 43 % | 12 % | 39 % | 15 % | 315 |
| race_3 | 6.6 | 58 % | 16 % | 20 % | 25 % | 313 |
| lowest to highest | 6.6 to 8.0 | 42.6 to 58.0 | 12.2 to 16.7 | 20.2 to 38.9 | 9.5 to 24.7 | 304.8 to 314.6 |

### The 12 November director on the same course (1 race, for comparing)

All checks: 57 inside, 105 outside.

*How long a take lasts*

| | Stream (s) | Game (s) | Inside |
|---|---|---|---|
| first quarter | 5.0 | 7.7 | **no** |
| middle | 8.1 | 9.3 | yes |
| third quarter | 12.2 | 10.4 | yes |

*Time per camera*

| | Stream | Game | Inside |
|---|---|---|---|
| drone | 90.5 % | 100.0 % | **no** |
| shore_long_lens | 9.5 % | 0.0 % | **no** |

*Time per subject*

| | Stream | Game | Inside |
|---|---|---|---|
| front | 51.9 % | 16.7 % | **no** |
| pack | 12.1 % | 54.8 % | **no** |
| mark | 21.8 % | 23.5 % | yes |
| line | 7.0 % | 5.0 % | yes |
| fleet | 7.2 % | 0.0 % | **no** |

*The drone's view*

| | Stream | Game | Inside |
|---|---|---|---|
| behind_side | 39.0 % | 31.7 % | yes |
| side | 35.2 % | 25.0 % | **no** |
| front_side | 25.8 % | 23.5 % | yes |
| na | 0.0 % | 13.8 % | **no** |
| top_down | 0.0 % | 6.0 % | yes |

### Lake Silvaplana, T2 sprint slalom, the final director (1 race)

All checks: 100 inside, 76 outside.

*How long a take lasts*

| | Stream (s) | Game (s) | Inside |
|---|---|---|---|
| first quarter | 5.0 | 4.6 | yes |
| middle | 8.1 | 6.9 | yes |
| third quarter | 12.2 | 12.3 | yes |

*Time per camera*

| | Stream | Game | Inside |
|---|---|---|---|
| drone | 90.5 % | 93.2 % | yes |
| shore_long_lens | 9.5 % | 6.8 % | yes |

*Time per subject*

| | Stream | Game | Inside |
|---|---|---|---|
| front | 51.9 % | 72.3 % | **no** |
| mark | 21.8 % | 14.6 % | **no** |
| pack | 12.1 % | 5.3 % | **no** |
| line | 7.0 % | 5.4 % | yes |
| fleet | 7.2 % | 2.4 % | yes |

*The beach cam*

| Picture | Eye: stream | Eye: game | Inside | Zoom: stream | Zoom: game | Zoom for a 3.5 m sail | Inside | Distance: game | Horizon: game |
|---|---|---|---|---|---|---|---|---|---|
| shore_long_lens shore mark | 4.5 m (3.5 to 5.0) | 4.5 m | yes | 1 to 4.0 deg | 2.5 deg | 1.7 deg | yes | 340 m | 30 % |
| shore_long_lens shore front | 4.5 m (3.5 to 5.0) | 4.5 m | yes | 1 to 1.5 deg | 1.0 deg | 0.7 deg | **no** | 537 m | 15 % |

## What a map needs for the director (Sotavento, the lake, a new spot)

Nothing in the director is tied to a map by name. A map works when it gives:

1. **A sailing scene** whose script extends the sailing scene (`main.gd`'s `SailingScene`, as `SpotSailing` and the lake's scene do), so a race can be watched with `--course=... --skippers=... --spectate=1 --tv=1`.
2. **Its land as `shore_grid`**: a `TerrainGrid` of the ground's height above the session's water (land above 0, water at or below 0), covering the course and the shore round it. It is the same grid the aground check, the race's sailing area and the shore lookout already use (from the map's `EnvironmentConfig.depth_grid()`). The beach cam uses it to find a shore and to never look across land; the drones use it to stay 12 m above land. A sea coast (land on one side only) works: the search looks all the way round.
3. **Optionally, where its beach camera stands**: any `Node3D` (a `Marker3D`) in the group `tv_shore_camera`, at the camera's eye (its height above the water is the marker's height above the water level). With one, the beach cam stands there for the whole heat and only pans and zooms, as the stream's camera on the beach in front of the judges' tower does. With several, the one nearest what it films. When land hides the water at its subject from there, a drone films that subject instead. Without a marker: the nearest shore with a clear view, 60 to 1200 m off (looked for all the way round, a view from the side preferred), the eye at 4.5 m; where no shore is in reach, a camera boat.
4. **A course with a start line and a finish line** (the marks `start boat`, `start pin`, `finish boat`, `finish pin`, as every course has): the line drone stands off the start line's end, the finish hover off the finish line's. Without a finish line the finish hover is left out.

**Never a picture through land** (the lead's rule, for every map): before every cut, and every quarter second while a camera that stands somewhere is on (the beach cam, a static drone), the director tests the sight line from the camera to what it films against the map's ground (`shore_grid`, every 8 m). Land in it: a drone picture on the same subject instead (at a mark another mark drone, on the start line the line drone), and a take on the screen ends. When a map's beach-camera marker can't see some of the course's marks, the game's log says so once ("TV director: from the map's beach camera ... land hides the marks ..."), for the map maker.

**The marker on Sotavento** (on the throwaway test branch only, for the lead to carry to the combined branch): in `Game/maps/sotavento/pwa_event_site.gd`, a `Marker3D` named `TvShoreCamera` in the group `tv_shore_camera`, on the seaward edge of the rocky headland up the coast from the judges' tower, 130 m along the beach and 150 m out (`beach_point(130.0, 150.0)`, rock about 1.6 m above the water there), its eye 4.5 m above the session's water (or standing height, 1.7 m, on the rock when the rock is higher).

**Why not at the judges' tower's foot**, where the lead first placed it: there the game's ground is at the waterline, and 100 to 165 m up the coast the headland rises to 3 m and more right in the sight line to the start: the start pin is hidden (Max, on the first pictures: "a big mountain in front of the important part"). The real stream's wide shot of the start line has no land in front (the replay dLbDV6jDm2s at 00:47). Checked along the sight lines on the spot's depth grid, on the course as Max had it corrected tonight (rebuilt from the replays: 2.7 km, the first reach to the beach; branch `spot/sotavento-first-reach`): from the headland's edge every mark and both lines are clear (the start line 1.65 to 1.7 km off, mark 1 1.2 km, mark 2 1.2 km, mark 3 620 m, mark 4 740 m, the finish 155 to 230 m); from the tower's foot the start line, mark 1 and mark 3 are hidden.

## What the game's director still does differently, and why

- **The metres.** The game's sails stand about 4.4 to 5.2 m above the water at speed, the stream's raked rigs about 3.5 m. For the same picture the game's drones fly about 40 % higher and farther (about 12 m up and 35 to 60 m off behind the leader, against 7 m and 23 m). In sail heights, the firm measurement, they fly where the stream's fly (2.3 to 3.1). Lower, more raked rigs at speed would be a physics change (Michiel's).
- **The sail measures about 8 % smaller than asked**: the framing counts the sail from the board's waterline, the check from the drawn mast foot on the deck. Inside the tolerance; a small fix for later.
- **The pack gets too much** (22.6 % of the race against 12.1 in the final two races): the next tuning step, on more races.
- **The beach cam's share swings** with the course's size and its reach rule (16.5 % before the rule, 1.5 % after it on the rebuilt Sotavento course, the stream 9.5 %): its threshold (`lens_reach_share`) is the number to set; and **the pans** go with it.
- **The marks' share of the race** comes out lower in percent when the race is long: at the check's 18 kt the rebuilt course takes the leader about 250 s (the stream's heats: about 185 s in 25 to 30 kt), with about as many seconds on the marks per heat as the stream.
- **The fleet** is seldom one picture: after the first reach the boats spread, and the director then films the pack instead (the stream's wide fleet shots are on the first reach).
- **The beach cam's zoom** stops at 1 degree (Godot's camera takes nothing narrower). A board so far off that its sail would show at less than 60 % of what the picture asks is filmed by a drone instead; the real camera's longest lens may go further, and on a long course like the rebuilt Sotavento one that leaves the beach cam little (above).
- **The start's labels:** the stream's readers called the drone running with the fleet just after the gun "on the start line"; the game logs it on the fleet or the front. The pictures match; the subject shares of the start phase differ by that.
- **A mark drone that starts to fly with the group out of the mark** (the same take): the game cuts instead.
- **Which side** of the board each drone is on, and the follow drones' exact angle: the middle of each view until the lead measures them (only `angle_deg` changes then).

## What a game camera can't copy, and what it does instead

- **The line-up graphic** before the start (55 % of the stream's pre-start) and **the interviews** after the race (most of the stream's after-race): not cameras. The graphics are phase P5 of the plan. The check compares the game with the stream's **live pictures** only, their shares among themselves.
- **The handheld camera on the beach** among the riders, the podium, the highlights replays: left out.
- **The beach cam on open water:** there is no shore. The honest equivalent is a **camera boat** off the course: 150 m from the board for the tight picture, 450 m for the wide one (the game's choice), on the side of the board and never with another board close in front of it. On a map with land and no marker (the lake) it stands at the **water's edge of the nearest shore with a clear view** (60 to 1200 m away; when none is in reach, a camera boat again, never looking across land). Its eye is 4.5 m above the water (the stream's, measured), its zoom follows from the distance (1 to 30 degrees of view: Godot's camera takes nothing narrower than 1 degree; the stream's tight shots are 1 to 1.5).
- **The stream's line drone** hangs at the end of the line with the pin or the start boat in the foreground. Max's committee boat view of 12 November is that camera now, with the line still drawn on the water. Exactly end-on, the drawn line hides behind the committee boat, so it stands 20 degrees round from the line's own line, on the course side: the line shows as a slanted line, a board over early is on the camera's side of it, and the fleet sails towards the camera as in the stream. The 20 degrees are the game's choice.
- **"Which side" of the board** a drone is on: the readers agreed on it for only 58 % of the seconds. The game takes the middle of each view: 45 degrees round from dead behind for behind-and-to-the-side, 90 for the side, 135 for ahead-and-to-the-side. The lead will measure the side from the wakes; then only `angle_deg` in the config changes.
- **The stream's camera operators** see who is who by sail colour and follow the commentator's story; the game's director knows the race order exactly and picks the leader, the lead group, a fight behind, the fleet.
- **A drone that hovers and then starts to fly with the group out of a mark** (the same take): the game cuts instead.

## What is estimated (the game's choices, with the reason)

All in `Game/config/tv_director.tres`, whose header says where every number comes from.

- The drones' lens, 47 degrees: inside the measured 47 to 59.
- The angle round the board per view (45, 90, 135 degrees): the middle of each view, until the side is measured.
- How a take draws its framing: one number for both the sail and the horizon, within the middle half of each (between the stream's first and third quarters). A bigger sail goes with a horizon higher in the picture, as when a drone that keeps its height comes closer and looks down more steeply. The readers wrote each picture's sail and horizon, not how they go together. (Drawn on their own, the first test race had a drone 43 m up.)
- The drones' height in sail heights where the lead did not measure a picture: 2.7, the middle of the measured 2.4 to 3.0.
- How often the chasers at a mark follow the leader's take there (70 %) and how often the drone flies through the finish with the winner instead of the hover at the line (50 %): the readers' notes say "often" and show both about equally.
- The lead group: the leader and the boards within 40 m of it, at most four (the readers' "the first 2 to 4 together").
- The race phase ends 13 s after the winner finished (measured: the readers' last board shown, 6 to 37 s after the winner, 13 in the middle).
- The beach cam films a board only when its 1-degree zoom shows at least 60 % of the sail the picture asks for (`lens_reach_share`, the game's choice; see the check).
- After a take on the pack the next is on the leader (the stream's back and forth, from the readers' notes; the number of takes is the game's).
- A take whose time is up runs on when the leader's cut to its mark is due within 4 s (set by the check: without it a quarter of the race's takes came out under 3 s, cut short by the mark).
- A mark's gybe counts as done once the board has come within 25 m of the buoy and goes away again (the race counts the rounding only past a line beyond the mark, seconds after the gybe on the screen).
- A picture on the fleet only while the boards still racing are within 150 m of their middle (the stream's are on the first reach); a board sailing back to restart after an early start is seldom the pack's story.
- The beach cam's place and range (above), the pull-out's growth (four times as far), how fast each camera glides.
- The start line drone 20 degrees round from the line (above).

## Screenshots

All in `.screenshots/tv_director/` (not committed), each at 1280 x 720 and at Max's 3137 x 1263, the TV screen (`--screen=tv`), the director forced to one camera where needed (`--tv_only=<shot>`, a check option). Each run's takes are in the `.csv` beside it.

**Sotavento, the course rebuilt from the replays** (the first reach to the beach; `sotavento_course2/` and `sotavento_course2_mark1/`, with the stream's water look; the beach cam on the headland's marker). These are the pictures to put beside the replays:
- `sotavento_course2/start_*_1.png` (9 s before the gun): **the beach cam wide on the start line**: the boards in a row on the line in the lower part of the picture, the pin on the left, the committee boat on the right, a big hazy mountain behind, no land in front; the line 1.74 km off, 3.3 degrees of view (about 2.3 for the stream's shorter sail; the lead expects about 2), sail 4.6 %, horizon at 64 % from the top.
- `sotavento_course2/start_*_2.png` (2 s before the gun): **the line drone**: the start line drawn from the pin to the committee boat, the boards coming at it, the hotels on the coast behind.
- `sotavento_course2_mark1/beach_tight_*_4.png` (64 s): **the beach cam on the leader at mark 1**, 1.3 km off at 1 degree: the buoy, the leader coming in, the hazy mountain behind (the sail 22 %, the most the zoom gets there).
- `sotavento_course2_mark1/mark_*_4.png` (64 s): **a mark drone at mark 1** looking out to sea, the leader and the second coming in to the buoy.
- `sotavento_course2/beach_tight_*.png`: taken before the reach rule: the beach cam at 1.5 km with the sail at 18 %, the reason for it.

**Sotavento, the first course** (`sotavento_final/`, the beach cam on the headland's marker):
- `start_*_1.png` (9 s before the gun): **the beach cam wide on the start line**: the line with the pin, the boards and the committee boat on a band of sea in the lower part of the picture, hazy hills behind, no land in front of the line (the headland's own rock at the bottom left, under the camera). Zoom 20.7 degrees at 478 m, sail 2.9 %, horizon 70 %. For Max to put beside the replay's wide start (dLbDV6jDm2s at 00:47).
- `start_*_2.png` (2 s before the gun): **the line drone**: the start line drawn on the water as a slanted line, the board over early right at it, the coast and the hotels behind; 7 m up, 71 m off.
- `start_*_3.png` (5 s after the gun): the line drone as the runner takes over.
- `beach_tight_*.png` (18 to 30 s): **the beach cam tight**: from the headland about 480 m off, 1.0 to 1.8 degrees of view: the leader's sail 34 to 61 % of the picture, the horizon at 15 to 30 % from the top; at 30 s two boards stacked by the long lens behind mark 2's buoy (the first set, from the tower's foot at about 670 m, had 1.0 to 1.3 degrees and the sail at 35 to 43 %).
- `mark_*.png` (14 to 22 s): **the mark drones**: waiting at mark 1, the leader coming in, the other marks and the coast with the hotels behind (the stream's "drone toward land with the buoy in the foreground"); after the gybe the drone holds on the buoy as the next board comes.
- `front_side_*.png`: the drone ahead and to the side; at 23 s the mark drone still holding on mark 1.
- `prestart_*.png` (35 and 25 s before the gun): the long lens before the start. The first set (`sotavento/`, the marker still at the tower) showed the problem that led to the rule "never through land": half the picture a hill. The final set's first picture was aimed at the line's middle, open water at 3 degrees of view, the boards cut off at the edge: fixed afterwards (a still long lens now aims at the board it is zoomed for), not re-shot.

**Open water, PD3 at 60 %** (in `.screenshots/tv_director/`, before some later changes):
- `front_side_*.png` (22 and 27 s): **the drone ahead and to the side**, the leader sailing at the camera: sail 14.5 % (asked 13.4), horizon 36 %, 12.7 m up, 40 m off.
- `beach_tight_*.png`: the camera boat's long lens tight on a board (sail about 30 to 50 %), horizon at 25 to 36 %.
- `mark_*.png` (28 to 36 s): the mark drone; it showed the problem of a drone behind the arriving boards (the leader passing under it, out of the picture), fixed by standing it round the boards' way out.
- `start_*.png`: the beach cam wide (the fleet small along the horizon at 70 % in the wide window), and the old line drone exactly end-on (the drawn line hidden behind the committee boat), fixed by standing it 20 degrees round.
- `prestart_*.png`: the camera boat's long lens before the start.

**Lake Silvaplana** (T2 sprint slalom; no marker: the nearest shore with a clear view):
- `lake_beach_wide_*.png` (35 s before the gun): the long lens from the shore on the line, the pin close, the boards, the mountainside behind, no land in front.
- `lake_beach_tight_*.png` (22 s after the gun): the long lens tight from the shore (sail 30 %), the committee boat and the pin in the picture; on a board that had not started yet (three of four boards were late in that short-countdown run), which led to leaving late boards out of the pack.
- `lake_start_*.png`: the line drone on the lake.

**Open water, the line drone after its change** (`start2_*.png`, 2 s before the gun): the drawn start line now shows as a long slanted line from the pin; the boards small at the pin end at that moment.

## Play-test checklist for Max

1. Watch a race with **T** on the open water (`template:PD3@60`, the Race page's "You: Watch") and on the lake (T2 sprint slalom). Does it feel like the stream?
2. **Before the start:** mostly the long lens, wide and still, on the fleet and on the line; a drone on the line now and then.
3. **The start:** about 10 s before the gun the long lens wide on the line; 1 to 4 s before the gun the low drone at the end of the line with the line drawn: can you see who is over early? Just after the gun a drone runs with the fleet off the line.
4. **The race:** takes of different lengths (some short, some long), mostly on the leader or the lead group, from behind and to the side, from ahead (the boards coming at you, new) and from the side. Now and then the long lens tight on the leader. Never straight down, never circling.
5. **The marks:** the cut comes a few seconds before the leader arrives, the drone already there; then often the chasers at the same mark; then back to the leader.
6. **The finish:** the drone flies through the line with the winner, or a drone side-on at the line holds while the places come in.
7. **After the race:** the long lens close on the winner, a drone with the finishers, a high drone pulling out.
8. Compare with the old one: the same race with `--tv_director=12nov`.
9. Keys 5 to 9 by hand, and the wheel; your wide window.
10. Is the board ever too small, or the horizon in a strange place? Note the moment (the full screen's race number and dice repeat it with `--seed=`).

## Not checked

- **Max's screen**, and how the cuts and the drones feel in motion: only screenshots and logs tonight.
- **The keys 5 to 9 by hand** and the wheel (screenshots can't press keys), and the old director by hand on the screen.
- Slow motion and fast forward with the director (the takes count real seconds, as before).
- **A restart with new sailors on the same boards** (the lead's event week, another branch): the director clears everything it keeps per board when the race restarts (watch mode's `restarted`), but that was not run.
- The shares to a few points: five races on the rebuilt course, one final race on the lake.
- The Sotavento marker lives only on the throwaway test branch (`test/tv-director-on-sotavento`, uncommitted, and as a patch in `.sim_output/tv_check/sotavento_tv_shore_camera.patch`); `broadcast/tv-director` itself holds no Sotavento code.

## Files

- `Game/race/tv_framing.gd` (`TvFraming`): the picture's maths, plain functions with tests.
- `Game/race/tv_stream_director.gd` (`TvStreamDirector`): the stream's director.
- `Game/race/tv_director_config.gd`, `tv_picture.gd`, `tv_phase_mix.gd`: its numbers' shape; `Game/config/tv_director.tres`: its numbers.
- `Game/race/tv_director_12nov_config.gd`, `Game/config/tv_director_12nov.tres`: the 12 November numbers.
- `Game/race/tv_camera.gd` (`TvCamera`): the camera; both directors; the new pictures (ahead-side drone, beach cam, pull-out).
- `Game/race/tv_take_log.gd` (`TvTakeLog`): the takes written down for the check (`--tv_log=`).
- `tools/tv_check.sh`, `tools/broadcast/director_check.py`: the check.
- Tests: `Game/tests/unit/test_tv_director.gd`; `test_watch_mode.gd` (the 12 November director, now against its resource).
- `Game/race/watch_mode.gd` is not changed (its header comment still describes the 12 November director: to update at the merge).
