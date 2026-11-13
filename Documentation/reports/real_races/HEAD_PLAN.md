# The head against a real race: the analysis and the plan (13 November 2026)

**For:** the team (Max, Michiel) and the sessions that train the head, the rule-based skipper (`Game/race/skipper.gd`,
`skipper_config.gd`), by [AI_TRAINING_METHOD.md](../../AI_TRAINING_METHOD.md).
**Status:** the analysis is done on runs already on disk (no new runs). The plan is a proposal: nothing is built, and
every item waits for Max's go (training runs only at night, on his word).

> **Foil against fin.** The real race is iQFOiL: foils, which turn on a wider radius than the game's fin boards (Max).
> Only measures that carry over are compared: seconds, shares, sides, counts, and metres divided by the board's own turn
> radius. Metres, knots and radii from the foils are never copied into the fin AI.
>
> **Tactics.** How soon a rider is out of a turn depends on what it does next (Max: "this is only because of the
> specific tactic on that race"). Exits are compared only between the same kind of mark and next leg, and are never a
> target on their own.

## 1. In short

| | Real riders (foil) | The head (fin) | Verdict |
|---|---|---|---|
| **Speed over the start line, against its own top speed in the next 30 s** | **0.93 to 1.00** | **0.58** (on-time boards 0.52) | **the biggest gap** |
| The run from the last gybe to the line | 56 s | 22 s | too short for a fin board too (it needs 29 s to 90 % speed) |
| Boards that do run 30 s or more | (all) 0.97 of top speed | 0.43 | it arrives early and eases off: the timing is wrong, not only the length |
| Gybe at a mark, reach to reach: the slowest point | 9.9 kt | **5.7 kt** | the AI drops off the plane |
| ... the speed kept (out / in) | 0.70 | **0.29** | the second gap |
| ... where it turns (turn start, in its own radii, before the mark) | 1.32 | 1.10 | a little late |
| ... nearest the mark at (apex share) | 0.40 | 0.29 | nearest too early in the turn |
| ... out of the turn (radii) | 0.62 | 1.04 | wide out (but see "Tactics") |
| ... passes the mark at (radii), the right side | 0.22, 4 of 4 | 0.21, 62 of 63 | fine |
| ... turn radius | 33 m | 27 m | fin tighter than foil: as Max said |
| Downwind legs: the angle to the wind | 133 deg | 130 deg | fine |
| ... gybes per leg | 1 to 2 (600 m) | 2 (median) | fine |

So: **1. the start's timed run arrives slow; 2. the gybe at a mark loses most of the speed; 3. the gybe's shape is a
little late in, wide out.** The downwind sailing and the mark positions are fine.

## 2. How it was measured

- **Real**: the U17 Men final of the iQFOiL Youth & Junior Europeans 2026 (Metasail, four riders, 1 point a second), read
  with Max: his marks, his start line, start 1 over early, start 2 counted (the report,
  [metasail_event930.md](metasail_event930.md), sections 12 and 13; `tools/real_races/analyse_roundings.py`).
- **The head**: the same criteria on its own tracks, from runs on disk (`tools/real_races/ai_suite_measure.py`, which
  reads a suite run's per-board CSVs and logs):
  - **starts**: version 6b's final checks, seeds 53 and 54 (`WindsurfingMMZB-fixes/.sim_output/suite/w3_hsl53_clean6b`,
    `w3_hsl54_clean6b`): 200 slalom races of three boards, 566 board-starts;
  - **roundings**: phase R's final check 82 with the three switches on (`WindsurfingMMZB-night13/.sim_output/suite/rb_h82_all`):
    63 gybe drills (the slalom gybe at a mark; 59 of them with a beam reach after the mark, like the real mark C) and
    114 top-mark drills; and 50 roundings from full races (`ra_t6_pkg`, `ra_t7_pkg`);
  - **downwind legs**: full races with the package on, tune seeds 3 to 7 (`ra_t3_pkg` to `ra_t7_pkg`): 231 legs.
- The head's numbers are from its best persona (`--spread=0`, the general head), as the method trains it.
- One real race of four riders is a sample: the real numbers are bands to check against, not targets to hit exactly.

## 3. The findings in detail

### 3.1 The start: the timed run arrives slow (the biggest gap)

| | Real (2 starts, 8 board-starts) | The head (version 6b, 566 board-starts) |
|---|---|---|
| Speed over the line / its top in the next 30 s | 0.93 to 1.00 | median 0.58 (middle half 0.45 to 0.75) |
| ... boards over within 1 s of the gun | (start 1 was over early at 0.94 to 0.99) | 0.52 |
| ... boards 5 s or more late | | 0.64 |
| From the last gybe to the line | 46 to 60 s (median 56) | median 22 s (middle half 15 to 32) |
| From the last gybe to 90 % of top speed | median 38 s (foil) | median 29 s (fin) |
| Boards whose final run is 30 s or more: speed over the line | 0.97 | 0.43 |
| Over within ... of the fleet's first board | 1 s (start 1), 9 s (start 2) | median 0.5 s |
| Over early | the whole fleet, at start 1 | 13 to 16 % of boards at the gun |

What it means. A fin board needs about 29 s after a gybe to reach 90 % of its top speed (the head's own numbers), but
the head's last gybe comes a median 22 s before the line: it crosses still accelerating. And where its final run is long
enough, it arrives early and eases off (the settings' note on `slalom_run_turn_s`: boards "luffing up a median 6 s before
the gun"), so it is even slower. The real riders do it the other way round: the last gybe about a minute out, some 40 s
to get up to speed, then the last 15 to 20 s flat out; the timing is settled before the last gybe, never by slowing on
the way in. Max said it on 11 November: "i prefer 3 seconds late at full speed than 0.2 sec but at half speed".

### 3.2 The gybe at a mark: the speed

In the gybe drills with a beam reach after the mark (59, the real mark C's situation) the head's slowest point is a
median 5.7 kt and it keeps 0.29 of its speed (middle half 0.18 to 0.91: many gybes fall off the plane, a quarter keep
it). The real riders: slowest 9.9 kt, 0.70 kept. A foil keeps flying through a gybe, so the foil's 0.70 is not the fin's
target; but a fin slalom gybe is meant to plane through, and 5.7 kt is well below planing. The 8 such gybes in full
races kept more (median 1.16): the drills drop the board 120 to 260 m before the mark, which may play a part; with 59
against 8, the drills are the stronger evidence, and the first step below checks it.

The head cannot carve its gybes today: `PlayerController._turn_key_along()` gives AI hands no turn key in a manoeuvre
(E09.S22, waiting for Max's OK for the controller change).

### 3.3 The gybe at a mark: the shape

| (gybe drills, beam reach out; real: mark C) | Real | The head |
|---|---|---|
| Turn start before the mark: radii; seconds | 1.32; 5 s | 1.10; 2.7 s |
| Apex share (0 = nearest at the turn start, 1 = at the exit) | 0.40 | 0.29 |
| Out of the turn: radii | 0.62 | 1.04 |
| Passes the mark at: radii | 0.22 | 0.21 |

The head turns a little late and passes the mark early in its turn, so it comes out wide: the same story as E09.S23's
open "out of the turn 19 m, the goal 15 m". With the tactics note above, the exit is judged only on drills of the same
kind (a gybe mark, a beam reach after it).

### 3.4 What is fine

- **Downwind legs**: the head sails 130 degrees off the wind (real 133), almost never dead downwind (2 % of the time
  over 160), 2 gybes a leg (real 1 to 2 on 600 m). Its distance sailed is 1.61 times the straight line against the
  riders' 1.39 to 1.49, but its legs point straighter downwind (175 against 162 degrees), so that is geometry, not a
  fault.
- **Rounding sides and the distance at the mark**: 62 of 63 gybe drills and 113 of 114 top drills on the right side;
  passing at about a fifth of a radius, as the riders do.
- **The fin radius**: 27 m against the foil's 33 m: smaller, as it should be.

### 3.5 What this race cannot tell

No beat, no top mark, no layline or overstand, no gate, only four riders (no crowd, no dirty wind), the gun not
recorded, the marks drawn (about 20 m). Those need other races: best fin races, or races with the buoys, and Max's own
GPS on Silvaplana.

## 4. The plan

Each item: why (the numbers above), the change in the head (behind a switch, off until it passes, as the method says),
how it is judged, and what it waits on. In the order proposed.

### P0. The suite reports the real-race measures (tools only; small)

- **Why:** today these numbers come from reading the CSVs afterwards. Every loop should print them.
- **Change:** `run_race.gd`'s `HEADS_RESULT` and `suite_summary.py` gain: the speed over the line against the board's
  top in the next 30 s (`line_speed_share`), the run from the last gybe to the line (`final_run_s`), and per rounding the
  turn start in radii (`start_r`), the apex share, the exit in radii (`exit_r`), the slowest speed and the speed kept.
  The definitions are `analyse_roundings.py`'s (one source).
- **Judged by:** a smoke run gives the same numbers as `ai_suite_measure.py` on the same races.
- **Waits on:** nothing (no change to the skipper, the controller or the physics). Backlog: E09.S19 (a new task).

### P1. The timed run arrives at full speed (the start; the biggest gap)

- **Why:** 3.1: over the line at 0.58 of its top speed, 0.52 when on time; the final run 22 s where a fin board needs
  about 29 s to 90 %; long runs eased off (0.43).
- **The change (one switch, `slalom_run_full_speed`, with two numbers):**
  1. **A final run long enough to be flat out**: the last gybe at least `slalom_final_run_s` before the line, the time a
     fin board needs to 90 % of its speed plus a margin flat out (a first value about 40 s: the head's own 29 s plus
     some 10 s; to be swept, for example 30, 40 and 50 s).
  2. **The timing settled before the last gybe**: the earlier loops (out and back) take up the spare time; when the last
     gybe is due, the time left is the final run, so nothing is left to burn on the way in.
  3. **No easing off in the last part of the run** (`slalom_run_no_ease_s`, about 15 s): the small error left is taken
     by the heading (a few degrees higher or lower toward the line's end: the "dive that can slow by its heading" the
     method asked for on 10 November), never by luffing or sheeting out; it rather crosses a second or two late than
     slow, as Max wants (`slalom_run_aim_late_s` 2 stays).
- **Judged by:** phase S3 on slalom races, the method's way: a tune set of 50 new races, then a hold-out of 100 with the
  sign test, on `score_m` (metres up the course 30 s after the gun); alongside, the line speed share (target: a median
  of 0.85 or more), on time, over early, falls, dirty wind (no worse beyond chance).
- **Waits on:** Max's go for the runs (a night). Backlog: E09.S25 (a new task); later the same idea for course starts
  (Q47: a timed run for course starts?).

### P2. The gybe at a mark planes through (the speed)

- **Step 1 (check, small):** the same measure on full slalom races (not drills) with enough gybes (100 or more) to see
  whether the drop off the plane is the head's or the drill's (3.2: drills 0.29 kept, 8 full-race gybes 1.16).
- **Step 2, if it is the head's: the carve.** E09.S22: the AI's hands use the carve (Shift) in their gybes, as the
  player can (a small controller change: `PlayerController._turn_key_along()` gives AI hands the turn key in a
  manoeuvre), and the skipper carves where it pays.
- **The fin target is not known yet.** The foils' 0.70 is not it. Max's number for a good fin slalom gybe at a mark (the
  speed in, the slowest, the speed out), or a GPS of his own gybes on Silvaplana, sets it (measure, don't guess).
- **Judged by:** phase R gybe drills: the speed kept and the slowest speed (better beyond chance), the drill's score
  (metres down the next leg at a fixed time), falls not worse.
- **Waits on:** Max's OK for the controller change (E09.S22 is blocked on it) and his fin target.

### P3. The gybe's shape: in a little earlier, nearest later, out tighter

- **Why:** 3.3: the turn starts 1.10 radii out (real 1.32), nearest the mark early in the turn (apex 0.29, real 0.40),
  out at 1.04 radii (real 0.62).
- **The change:** `round_early` (on since 13 November) starts the turn from the arc at the controller's rates; give it a
  lead in radii (`round_early_lead_r`, about 0.2 to 0.3 of a radius earlier) and aim the second half of the turn at the
  mark's far side so the nearest point comes later (`round_apex_late`). Measured in radii, so it fits the fin board's
  own turn.
- **Judged by:** phase R gybe drills of one kind (a gybe mark with a beam reach after it, the next leg the same in both
  arms): the drill's score first; exit_r, the apex share and the "out of the turn" (E09.S23's goal 15 m) alongside,
  never against the tactics (Max).
- **Waits on:** Max's go; best after P2, because a carved gybe changes the turn's shape. Backlog: E09.S23 T1.

### P4. More real data for what this race cannot show

- Beats, laylines, top marks, gates, crowds and dirty wind: fin races with buoys if they can be found, and **Max's own
  GPS on Silvaplana** (with the time, the gear and the wind), which serves the head and the physics alike.
- Every new race goes the same way: a tracks-only picture, Max draws the marks and says what happened, a course file,
  then `analyse_roundings.py` and the comparison with `ai_suite_measure.py`.

## 5. What not to take from the real race

- No metres, knots or radii from the foils into the fin head (the turn radius, the speeds, the 400 to 500 m of the final
  run, the 0.70 kept).
- No exit time or distance as a target: it is the race's own tactic.
- Not the over-early start as a goal: the head is over early at the gun 13 to 16 % of the time already.

## 6. For Max to decide

1. The order: P0, then P1, then P2 (step 1, then the carve), then P3?
2. P2: OK to let the AI carve its gybes with Shift (the controller change of E09.S22)?
3. P2: the target for a fin slalom gybe at a mark: your numbers (speed in, slowest, out), or a GPS session of your own?
4. P1: a night for the runs (the method's loop: tune 50, hold-out 100, phase S3 slalom races), and when?

## 7. The files

| What | Where |
|---|---|
| The head measured by the real-race criteria | `tools/real_races/ai_suite_measure.py <run> [...] --what=starts|roundings|legs --csv=<out>` |
| The real race measured | `tools/real_races/analyse_roundings.py tools/real_races/courses/930_u17_men_final.json <gpx folder> --csv=<out>` |
| The numbers of this plan | `.sim_output/real_races/ai_compare/` (ignored by git): `ai_starts_6b.csv`, `ai_roundings_drills_h82.csv`/`.txt`, `ai_roundings_full_races_t6t7.csv`/`.txt`, `ai_downwind_legs_pkg.csv` |
| The runs read | `WindsurfingMMZB-fixes/.sim_output/suite/w3_hsl53_clean6b`, `w3_hsl54_clean6b`; `WindsurfingMMZB-night13/.sim_output/suite/rb_h82_all`, `ra_t3_pkg` to `ra_t7_pkg` |
