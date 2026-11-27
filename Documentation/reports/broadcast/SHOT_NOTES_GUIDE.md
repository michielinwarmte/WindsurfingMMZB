# Shot notes: how the stream's pictures are written down

This guide is for whoever writes the shot notes of a stream replay (a person or a Claude worker). The notes feed the game's TV director (`Game/race/tv_camera.gd`, backlog E11.S11): which camera, what it shows, for how long, at which moment of the race.

## What you get per replay

In `C:/Users/Max de Dikke/source/pwa_broadcast/media/<video id>/`:

- `shots/sheet_001.jpg ...`: contact sheets, 20 small pictures per sheet in time order (left to right, top to bottom). Above each picture: its time in the video (`mm:ss`) and its shot number. A **red bar** on the left and a yellow label mark the first picture of a new shot (the picture right after a cut).
  A picture is saved every 2 s for the first 12 s of a shot, every 4 s until 40 s, then every 8 s.
- `shots/shots.csv`: every shot's start, end and length in seconds, found by a cut detector. It can be wrong: see "Fixing the cut detector" below.
- `shots/frames.csv`: which picture sits where (sheet and row-column).
- `sentences.txt`: what the commentator says, with the time of every sentence. Read it next to the sheets: it tells you the race moment (the start, a mark, the finish) and who is in the picture.

Look at **every** sheet of your replays, in order. Don't sample.

## What you write

One file per replay: `shots/shot_notes.csv` (UTF-8, comma separated, a header row, text fields in double quotes when they hold a comma). **One row per beat.** A beat is a shot, or a part of a long shot in which the camera does one job. When a long take changes its job (it follows the leader, then holds on the mark while the fleet gybes), split it into parts `a`, `b`, `c` with the time of the first picture of each part.

| Column | What to write |
|---|---|
| `video` | the video id (the folder name) |
| `shot` | the shot number from the sheet |
| `part` | empty, or `a`, `b`, `c` when the shot is split |
| `start_s`, `end_s` | seconds in the video. For a whole shot copy them from `shots.csv`. For a part, use the time of its first picture and of the next part's first picture. |
| `camera` | `drone`, `shore_long_lens` (a camera on land with a long lens: the picture looks flat, the boards stacked close together, low over the water), `boat`, `beach_handheld` (among people on the beach), `graphic` (a full-screen graphic or title), `other` |
| `view` | where the camera is, seen from the boards it shows and their direction of travel: `behind`, `behind_side`, `side`, `front_side`, `front` (they sail towards the camera), `top_down` (looking straight down), `na` |
| `height` | `water` (about the sailor's head height or lower), `low` (about the mast top: sails cut the horizon), `medium` (clearly above the mast tops, the horizon in the upper third), `high` (the boards are small, the horizon near the top or out of the picture), `top_down`, `na` |
| `horizon_pct` | where the line between the sea and the sky or land sits, in percent of the picture's height **from the top** (0 = top edge, 50 = the middle). `none` when no horizon is in the picture. Round to 5. |
| `sail_pct` | how tall the main subject's sail is, in percent of the picture's height (a sail from the board to the mast top). Typical for the beat. Round to 5 above 10; give 1, 2, 3, 5, 8 below. `na` without a board. |
| `boards` | boards in the picture: `0`, `1`, `2`, `3`, `4-6`, `7+` |
| `subject` | `leader`, `lead_group` (the first 2 to 4 together), `duel` (two boards fighting, not for first), `chasers` (a group behind the lead), `fleet` (most of the heat), `one_rider` (a single board that isn't leading), `mark` (the buoy, boards coming through), `start_line`, `finish_line`, `shore` (beach, people, scenery), `people` (presenter, interview, a rider on land), `graphic`, `none` |
| `move` | `follows` (the camera travels with the boards and keeps them about the same size), `static` (it stays in place, the boards move through the picture), `pan` (it stays in place and turns with them), `push_in`, `pull_out`, `orbit` (it circles the subject), `fly_over`, `na` |
| `phase` | one of the four phases of a heat (Max, 27 November 2026): `pre_start`, `start`, `race`, `after_race`. Their exact borders are under "The four phases" below. |
| `moment` | the finer race moment inside the phase, from the picture and the commentary: `intro`, `pre_start` (boards milling or lining up), `start` (the last seconds to the line and the first seconds after), `first_reach`, `reach` (a later leg), `mark_approach`, `mark_rounding` (the gybe), `last_leg`, `finish`, `after_finish`, `replay` (action shown again, slow motion or not), `results` (a results graphic, or the commentator going through the order), `interview`, `other` |
| `graphics` | the graphics on the picture, `+` between them: `logo` (corner logo), `caption` (a small title bar), `leaderboard`, `clock`, `name_tag` (a rider's name bar), `results_table`, `sponsor`, `none` |
| `sure` | `yes`, or `no` when you had to guess one of the fields; say which in `note` |
| `note` | anything short and useful: "cut to the second drone, cooler colours", "leader gybes inside", "camera loses the leader, searches" |

### The four phases

Every beat belongs to exactly one phase. All the drone numbers (which camera, how high, how long a shot lasts) are worked out per phase, and the game's TV director gets its settings per phase.

| Phase | From | Until | Moments inside it |
|---|---|---|---|
| `pre_start` | the first picture of the heat | the boards turn for their final run at the line (about the last 10 s before the gun) | `intro`, `pre_start` |
| `start` | the final run at the line | the fleet is clear of the line and strung out on the first reach (about 10 to 15 s after the gun) | `start` |
| `race` | the fleet on the first reach | the last board that the stream shows crosses the finish line | `first_reach`, `reach`, `mark_approach`, `mark_rounding`, `last_leg`, `finish` |
| `after_race` | after that finish | the end of the video | `after_finish`, `replay`, `results`, `interview` |

- A beat that runs across a border goes to the phase it starts in, unless it is a long take: then split it at the border into parts.
- Note the time of **the gun** and of **the winner's finish** in `director_notes.md` (as `mm:ss`), with how you know (the commentary, a flag, the boards crossing the line). Everything is later measured against these two times.
- A heat that is started twice (a general recall): the first try is `pre_start` again from the recall on; say so in `note`.
- `other` as a moment keeps the phase of the beats around it.

### How to judge the hard ones

- **Drone or shore camera?** A drone looks down on the water: you see the sea's surface as an area, wakes as lines. A shore long lens looks along the water: the boards overlap each other, the far shore or the horizon sits high behind them, the sea is a thin band.
- **`height` goes with `horizon_pct`:** a horizon at 10 to 25 % with boards far below it is `high`; around 35 to 50 % with sails reaching up to it is `low`.
- **`follows` or `static`?** Compare the boards' size and place from one picture of the shot to the next. Same size, same place in the picture, background sliding by: `follows`. Boards moving across or shrinking: `static` or `pan`.
- **The race moment** is easiest from `sentences.txt`: the countdown and the gun, "into the first mark", "gybe", "across the line". The replays also carry chapter marks in the video's `video.info.json` ("chapters"), which give a rough guide.
- When a field can't be told from the small pictures, write your best guess and `sure` = `no`. Don't leave fields empty.

### Fixing the cut detector

- **A cut it missed:** the picture changes to a different camera inside one shot number, with no red bar. Split the shot into parts and write `missed cut` in `note`.
- **A false cut:** a red bar, but the picture runs on from the same camera (spray or a fast pan fooled the detector). Write the rows as they are numbered, and put `same take as shot N` in `note`.

## The second file: what the director does

Per replay, also write `shots/director_notes.md`, half a page at most:

- the order of cameras through the heat (for example: wide high drone at the line → low drone on the leader → shore lens at mark 1 → ...);
- what makes the director cut (a mark coming up, the leader clear, a fall, the finish);
- how the start, each mark and the finish are covered: which camera, from where, how long before and after;
- the graphics: what comes on screen, where on the picture, and when;
- anything the stream does that a game camera couldn't know or copy.

Times as `mm:ss`. Facts you saw, not guesses about why.
