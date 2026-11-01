# The nights reviewed: what 21 hours of training bought (1 November 2026)

The lead's review of the training run of RA5, written for the team after the run ended. The brief (Michiel, 31 October): "train them to become as fast as possible around all the courses with different wind and wave conditions", then about 20 characters. The short answer: **the brains sail, but they do not race.** On the same drops and against the same scripted all-rounder they are slower on every kind of drop, and in a real race on the training loop every one of them fails to finish, changing tack every 10 to 15 seconds. The all-rounder, the scripted skipper the game already has, finishes the loop in eight minutes with five tacks. Section 4 says why, section 6 what to do about it.

The logs of everything below are in [nights/](nights/): the run's own log (`nights.log`), each stage's learning curve (`all_s<n>_curve.csv`), the evaluations (`eval_*.log`) and the races (`race_*.log`, `solo_*.log`).

## 1. The run

```
tools/train.sh --stages=S1,S2,S3,S4,S5,S6 --hours_each=4 --workers=12 --run_prefix=all --resume=Game/race/brains/s1_best.json
```

From the worktree `../WindsurfingMMZB-train` (branch `race/train-all`), 31 October 21:45 to 1 November 19:05, 12 Godot workers of 4 boards at 110 to 125 decisions a second, the machine at a load of 12 on 16 threads and 10 of 31 GB. One crash: at 09:10, right after S4's first check, worker 0 dropped its TCP connection; the trainer's retry picked S4 up from its saved model within a minute. (The restart counted its hours from the resume, so S4 had 3.8 hours in all, and its `curve.csv` holds only the part after the restart; the first two hours are in `nights.log`.)

| Stage | What it trains | Episodes | Ran | Its check at the end | The bar ("done when") |
|---|---|---|---|---|---|
| S1 | the beat, alone, blind | 90 s | 21:45 to 22:49 | speed made good 2.33 m/s, 91 % of the all-rounder's on its own fresh drops | 80 %: **passed after 1 hour** |
| S2 | rounding a mark | 60 s | 22:57 to 02:57 | rounds 25 % of the drops, in 38.6 s | 80 % within 40 s |
| S3 | rounding, downwind | 60 s | 02:57 to 06:57 | rounds 45 %, in 29.5 s | 80 % within 40 s |
| S4 | laps, 30 % on the lake | 480 s | 06:57 to 10:59 | finishes no lap | 90 % of the laps, within 1.3 times the all-rounder's time |
| S5 | the start, 6 boards, the rules | 120 s | 10:59 to 14:58 | starts 75 % of the time, 59 s after the gun, 12 % over early | 90 % within 10 s, under 10 % early |
| S6 | full races, 8 boards | 480 s | 14:58 to 19:05 | reward -8.5, finishes no race | none: its hours |

The learning curves say the same in more detail. S2 and S3 improved for an hour and then sat still (the goal share 20 to 25 %, the policy's spread fallen from 0.22 to 0.08, so it stopped exploring). S4 crept up on the progress reward and nothing else. S6 got worse as it went: the manoeuvres per episode rose from 16 to 24 and the falls stayed at 2.

## 2. The brains measured on the same drops

Every brain was sailed on a stage's drops with seed 1 (`tools/train.sh --evaluate=<brain> --stage=S<n> --episodes=<k> --seed=1 --reference=allrounder`), and the scripted all-rounder sailed the very same drops after it. The all-rounder is the scripted skipper of `Game/race/skippers/allrounder.tres`, with the pilot's own margin on the push.

| Brain | Drops | Speed made good | Reached the goal | Falls / episode | Manoeuvres / episode |
|---|---|---|---|---|---|
| the all-rounder | S1 beat, 20 of 90 s | **4.00 m/s** | 25 % | 0.25 | 1.6 |
| `s1_best` (Session 63's brain, the starting point) | S1 | 3.29 m/s (82 %) | 5 % | 0.80 | 2.9 |
| `all_s1_best` | S1 | 3.09 m/s (77 %) | 0 % | 0.65 | 2.2 |
| `all_s3_best` | S1 | 3.22 m/s (81 %) | 0 % | 0.25 | 2.8 |
| `all_s6_best` | S1 | 3.15 m/s (79 %) | 10 % | 0.25 | 2.2 |
| the all-rounder | S3 rounding, 20 of 60 s | 2.10 m/s | **70 %** in 37.1 s | 0.60 | 1.6 |
| `all_s3_best` | S3 | 2.22 m/s (106 %) | 55 % in 35.6 s | 0.70 | 3.0 |
| the all-rounder | S4 laps, 8 of 480 s | 5.30 m/s | 38 % in 231 s | 2.25 | 3.6 |
| `all_s4_best` | S4 | 2.79 m/s (53 %) | 0 % | 1.62 | 15.6 |
| the all-rounder | S6 races, 6 of 480 s | 5.58 m/s | 50 % in 314 s | 3.33 | 6.0 |
| `all_s6_best` | S6 | 1.99 m/s (36 %) | 0 % | 2.00 | 22.2 |

Three things to read off this table:
- **The night did not make the beat faster.** S1's check said 91 %, but that was on its own fresh drops; on seed 1 the new S1 brain is at 77 % and Session 63's brain, which it started from, at 82 %. What the later stages did buy is fewer falls (0.25 per drop instead of 0.80).
- **The rounding is the one skill where the brain is near the all-rounder** (55 % of the marks against 70 %, at a slightly higher speed made good). These drops are short, 60 s with the mark 50 to 150 m away.
- **The longer the drop, the worse the brain**: on laps 53 %, on races 36 %, with 15 to 22 manoeuvres per episode where the all-rounder makes 4 to 6.

## 3. The races

The T1 training loop at 18 kt (seed 1, the game's 60 s countdown, wind shadows and the rules), each brain alone against the all-rounder, `tools/race.sh --course=t1_loop --skippers=brain:<name>,allrounder --wind_kt=18 --seed=1`:

| Board | Result | Steps of 6 | Tacks | Gybes | Falls |
|---|---|---|---|---|---|
| the all-rounder | **7:56 to 8:02** | 6 | 5 | 5 | 0 |
| `s1_best` (Session 63) | DNF, 22 m from mark 1 | 1 | 29 | 5 | 2 |
| `all_s1_best` | DNF, never crossed the start | 0 | 2 | 0 | 0 |
| `all_s3_best` | DNF, 14 m from mark 1 | 1 | 43 | 0 | 0 |
| `all_s6_best` | DNF, at the gate after 8:23 | 2 | 31 | 3 | 0 |

With the rookie in the fleet (`race_t1_18.log`, five boards) the all-rounder finished in 7:58 and the rookie reached 4 of 6 steps. On the T2 sprint slalom at 18 kt (`race_t2_18.log`) the all-rounder finished in 3:09.7, the rookie in 3:30.2, and all three brains were still at mark 1 when the race ended, with 22 to 26 tacks.

## 4. What the tracks show: the diagnosis

The boards' tracks (`.csv` per board, read by the wind angle each board held, `nights/solo_tracks.py`) say what the brains do between the tacks:

- **The sailing itself is there.** On the beat the brains hold a mean wind angle of 45 to 65 degrees, the right band, and reach 9 to 10 m/s. `all_s6_best` averaged 4.0 m/s over its race, `all_s3_best` 2.8 m/s; the all-rounder 7.0 m/s.
- **They change tack every 10 to 15 seconds; the all-rounder every 90.** Each tack takes the speed away and costs 10 to 20 m. At that rate a 500 m beat never ends, and the tracks show exactly that: `all_s3_best` crossed the start after 40 s, sailed to within 14 m of mark 1 and spent the next seven minutes tacking around it.
- **Why the checks did not see it:** on S2's and S3's drops the mark is 50 to 150 m away and the episode 60 s, so a brain that tacks every 15 s still rounds half of them. The habit only becomes fatal when the leg is long.
- **Why the brain tacks:** its steering output is the wind angle to sail at, and the sign of that angle is the tack; the hands tack whenever the output crosses zero (at most every 3 s). The brain learned, roughly, to point at the mark. On a beat the mark is dead upwind, so its wish crosses the wind every few seconds as the board zigzags across the rhumb line. The scripted skipper has a rule for this (sail one tack to the layline, tack once); the brain would have to discover the same rule from the reward within its look-ahead of 250 to 500 s, and in 21 hours it did not.
- **The S1 brain alone in a race sat still for nine minutes,** pinched at 32 degrees to the wind at 0.7 m/s. It never saw a start line in training (S1's drops begin on the course), so the start's inputs (the line, the countdown) put it outside everything it knows. The later brains, which trained starts in S5, did cross the line.
- **S4 and S6 could not learn their job:** on their drops not even the all-rounder finishes most laps in 480 s (38 % and 50 %), and the brain's look-ahead (gamma 0.998, a decision every 0.5 s) is about 500 s. The stages' bars (90 % of the laps) were out of anyone's reach.

## 5. Small things found on the way

- In a race `brain:all_s3_best` is shown as "best" (`Generations.label_of()` keeps the last word of the name), so a fleet of several brains has several boards called "best" and their tracks all land in one `best.csv` (`run_race.gd` names the file after the board). The solo races above were run for that reason.
- The Race page's "The trained brain and the personas" looks for `s6_best` down to `s1_best` in `Game/race/brains/`, so it still takes Session 63's `s1_best`, not the nights' `all_s6_best`. Given section 3, that is no loss today.
- The bars of S2 to S6 are above what the all-rounder itself does on the same drops (S3 rounds 70 %, S4 finishes 38 %, S6 50 %), so no stage after S1 can ever end early. S1's bar (80 %) ended it after one hour while it was still improving.
- The twelve brains are committed (`all_s<n>_best.json` and `all_s<n>_latest.json`); the hourly generations are kept out of git in the train worktree's `.sim_output/train/all_s<n>/brains/`, as the trainer did with its tries.

## 6. What to do next: the options

**A. The twenty characters now, on the scripted skippers** (the lead's recommendation). The twelve personas of `Game/race/personas/` and the four characters exist, and they finish races. `persona.gd` already turns a skill sheet (start timing, nerve, tacking, boat speed, risk, consistency, ...) into the scripted skipper's numbers. What is missing for the brief: eight more personas from rookie to pro; a **push level** per persona on the slider (`AiHands.push`; the scripted skipper leaves it at the pilot's margin today), which is the honest knob for "different speed": more push is faster and falls more, as the push slider's measurements showed; and each persona's gear from the catalogue (GE5), so a light-wind specialist rigs the 8.0. The persona matrix (`tools/persona_matrix.sh`) is the proof that the specialists show. One session with Opus agents, no physics, no nights on the PC. The trained head can take the same sheet later, as D3 planned, once it races.

**B. Another night, after the trainer is changed** (RA14). The fixes the diagnosis points at, in order of weight: (1) a minimum time between tacks in `LearnedSkipper`, 20 to 30 s, or a tack cost in the reward, so the policy cannot zigzag; (2) drops that fit the look-ahead: S4 on half-size courses (`template:PD3@50`), and bars set at the all-rounder's own share on the same drops instead of 80 to 90 %; (3) S1's bar at 100 % so the beat keeps improving past the first hour; (4) an entropy bonus (`--ent`) against the spread's collapse, and each board its own conditions in S1 to S4 (the trainer's own suggestion) so no worker waits on a rough race. Each try costs a day of Michiel's PC, and there is no promise the brain beats the scripted skipper, which is a strong baseline with rules the brain has to rediscover.

**C. Both, A first.** The characters are what the game needs for 0.2; the head is research that can run on the PC on a free day.

The commands to repeat any number above are the ones quoted; `--seed=1` gives the same drops and the same race.
