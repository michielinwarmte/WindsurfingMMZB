# Where the stream's drone flies, and its lens

27 November 2026. Max: "also analyse the position and field of view of the drone to match that". This is the measurement, from the nine slalom heat replays of the World Cup Fuerteventura 2026. It goes with the camera numbers in [data/shot_stats_slalom.md](data/shot_stats_slalom.md) and feeds the game's TV director (backlog E11.S11).

## The answer in short

- **The drone flies low:** about 2.4 to 3 sail heights above the water, which is about **6 to 10 m**. It looks down at the board by about 15 to 25 degrees.
- **It is close:** about **15 to 40 m** from the board over the water, nearest when it sits behind the pack or over a mark, farthest when it flies ahead of the leaders.
- **Its lens is a wide one:** between about **47 and 59 degrees** of vertical view. The standard wide lens of a camera drone gives about 47, and that fits. The footage can't pin it tighter (see "The lens" below).
- The game's chase drone (24 m behind, 9 m up, 50 degrees) was already close to the real one. The game's side drone flies lower than the real one (6 m against about 9.5), and the game's mark drone much higher (22 m against 6 to 11).

## The drone's height (measured, no lens needed)

A thing standing on the water reaches up to the horizon in the picture exactly when its top is as high as the camera. So the drone's height, counted in sail heights, is how far the sail's foot stands below the horizon divided by how tall the sail is in the picture. No lens and no distance come into it.

Measured on 102 follow shots of the race (a program found the sail in the picture; a shot counts only when its sail size agrees with the size the human reader noted for that shot):

| The picture | Shots | Height in sail heights (middle, and the middle half) | Looks down by |
|---|---|---|---|
| Behind and to the side, on the leader or the lead group | 19 | 2.5 (2.3 to 3.0) | 21° |
| Ahead and to the side, on the leader or the lead group | 18 | 2.4 (1.9 to 2.7) | 15° |
| From the side, on the leader or the lead group | 10 | 3.0 (2.0 to 3.2) | 20° |
| Behind and to the side, on the pack | 10 | 2.4 (2.0 to 3.4) | 23° |
| Behind and to the side, at a mark | 9 | 2.7 (2.2 to 4.1) | 24° |
| From the side, at a mark | 11 | 3.0 (2.1 to 5.5) | 16° |
| Ahead and to the side, at a mark | 9 | 3.0 (2.3 to 3.2) | 16° |
| Behind and to the side, on the fleet | 8 | 2.5 (1.9 to 3.0) | 18° |

The angles are for a lens of 47 degrees; with a wider lens they are a few degrees more.

**In metres** this needs the height a sail shows. A slalom rig at speed is raked back and leaned to windward (the team's own video measurements: 33 to 36 degrees of rake, 23 to 29 of lean), so its top is about 3.5 m above the water, and from behind it shows lower than from ahead because the top leans back towards the camera. With that: **about 6 to 7 m from behind, about 9 to 10 m from the side and from ahead.** This step is an estimate.

## The lens

The picture alone can't tell a wide lens close by from a long lens far away: the board has the same size and the horizon sits in the same place. What does tell them apart is how fast a sail grows when a board sails towards a drone that hangs still, if the board's speed is known.

- Found: four clean passes (boards sailing at a still drone at the start line and at a mark, with land on the horizon to take out the camera's turning).
- The boards' speed is **not measured here** (the still side-on shots were too few and too messy), so it is taken as a range: 3.6 to 4.8 sail heights per second, which is about 25 to 33 knots.
- Result per pass, vertical view in degrees:

| Pass | Slow end (3.6) | Middle (4.2) | Fast end (4.8) |
|---|---|---|---|
| Elimination 2, the start, leader | 57 | 51 | 46 |
| Elimination 2, the start, second board | 70 | 59 | 51 |
| Elimination 1, the start | 61 | 55 | 49 |
| Elimination 2, a mark | 44 | 38 | 33 |
| **The middle of the four** | **59** | **53** | **48** |

So: a wide lens, most likely between 47 and 59 degrees. A camera drone's standard wide lens (24 mm in photo terms) gives 44 to 48 degrees of vertical view in a 16:9 picture; that matches the fast end, and the boards at a World Cup start in 30 knots are fast. **The game is set to 47 degrees** (a choice inside the measured range, not a measurement). If someone knows which drones the stream's crew flies, the lens is on its data sheet and this question is closed.

Tried and dropped, because the geometry gives nothing: the same sail measured near and far in one picture, the path of a board under a hovering drone, the wakes' vanishing point. On flat water with a small tilt all of these come out the same for any lens.

## Where the drone is, with the lens

From the height, the look-down angle and the lens, the distance over the water follows.

| The picture | Height | Distance over the water, lens 47° | Lens 59° |
|---|---|---|---|
| Behind and to the side, on the front | 6.9 m | 23 m (17 to 29) | 16 m |
| Ahead and to the side, on the front | 9.0 m | 37 m (29 to 43) | 29 m |
| From the side, on the front | 9.7 m | 28 m (20 to 48) | 20 m |
| Behind and to the side, on the pack | 6.5 m | 18 m (12 to 21) | 12 m |
| Behind and to the side, at a mark | 6.1 m | 14 m (10 to 19) | 9 m |
| From the side, at a mark | 9.6 m | 32 m (22 to 45) | 24 m |
| Ahead and to the side, at a mark | 11.4 m | 39 m (22 to 60) | 30 m |

**Which side** of the board the drone is on comes from the readers' notes (behind-side 36 % of the race's drone time, side 35 %, ahead-side 25 %). Two readers agreed on it for only 58 % of the seconds, so it is rough. The wake's direction in the picture would measure it; that is not done yet.

## The beach camera

Max, 27 November 2026: "try to match the camera angles on the beach". This became possible when his Sotavento spot arrived (branch `spot/sotavento`): it has the judges' tower and the Slalom X course in real coordinates, so the distances from the beach to the start line, the marks and the finish are known. With a known distance a lens can be worked out, which the drones didn't allow.

**Its height (measured, no lens needed):** on 41 beach-camera shots the sail's foot stands 1.0 to 1.5 sail heights below the horizon (middle 1.3), so the camera is about **4.5 m above the water** (3.5 to 5). That is a camera standing on the beach, not on the judges' tower's deck (7 m up on the beach top, about 10 m above the water). A few finish shots of the full-fleet race come out higher (2.0 to 2.6 sail heights, about 8 m); those may be a second camera or a drone the readers took for the beach camera.

**Its lens (from the spot's distances; an estimate, because the game's course was laid from a drawing of the event, not a survey):**

| The shot | Sail in the picture | Distance from the tower | Vertical view |
|---|---|---|---|
| Wide on the start line, before and at the start | 3 to 4 % of the picture's height | 620 to 720 m | **8 to 10°** |
| Half close: a group on a reach, the finish | 14 to 20 % | 250 to 580 m | 2 to 4° |
| Tight on the leaders at a mark or in a fight | 27 to 55 % | 370 to 580 m | **1 to 1.5°** |

A check on the wide shot: the start line is 140 m long and 670 m away, which is 12 degrees wide; a picture with 8 degrees of vertical view is 14 degrees wide. So the wide shot is framed exactly on the start line, as the pictures show.

**Where it points** (bearings from the tower; the beach runs 013°, straight out to sea is 103°):

| At | Bearing | Distance |
|---|---|---|
| The start line | 056 to 064° (up the coast and out) | 620 to 720 m |
| Mark 1 | 074° | 685 m |
| Mark 2 | 070° | 455 m |
| Mark 3 | 087° | 580 m |
| Mark 4 | 090° | 370 m |
| The finish line | 103° (straight out) | 250 to 330 m |

**How it frames:** wide on the start, the camera is tilted up: the horizon sits low in the picture, 70 to 75 % from the top, the sea a thin band under a lot of sky. Tight on the leaders the horizon sits at 25 to 35 % from the top and the board's foot at about 70 %. It stays in one place and pans.

## Against the game's drones today

| | The stream | The game (12 November) |
|---|---|---|
| Behind the board | 23 m back, 7 m up, lens about 47° | chase: 24 m back, 9 m up, 50° |
| Beside the board | 28 m off, 9.5 m up | track: 32 m off, 6 m up, 40° |
| Ahead of the board | 37 m ahead, 9 m up | none |
| At a mark | 14 to 39 m from the board, 6 to 11 m up | mark drone: 38 m beyond the mark, 22 m up, 42° |
| High and far | not used in the race | helicopter: 110 m off; overhead: 45 m up |

## How sure

- **Height in sail heights:** measured, and the firm part. Four of the 102 pictures were looked at by eye: three right, one wrong (a sail with a clear lower panel was found as two pieces, which made that drone look higher than it was). The middle values hold against a few of those; single shots don't.
- **Height in metres:** an estimate, because a raked sail's shown height is one (plus or minus about 15 %).
- **The lens:** a range, 47 to 59 degrees, from four passes and an assumed speed.
- **The distances:** follow from the lens, so they carry its range (the two columns above).
- Only this event and these drones. Another crew may fly differently.

## The tools

`tools/broadcast/sail_track.py` (finds and follows sails by colour, and the land on the horizon for the camera's turning), `follow_heights.py` (the heights), `drone_geometry.py` (the lens from a pass), `track_beats.py`, `frame_strip.py` (gridded frames for measuring by eye). The tables per shot: [data/drone_heights_fov47.csv](data/drone_heights_fov47.csv) and [data/drone_heights_fov59.csv](data/drone_heights_fov59.csv).
