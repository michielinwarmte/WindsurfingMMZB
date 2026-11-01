# The trainer's tacks: package 2 of the plan (RA14, RA15)

Package 2 of [PLAN.md](PLAN.md), by the tacker (Claude Opus 5.5, an Opus agent for the Fable lead), 1 and 2 November 2026, on `race/train-tacks` in `../WindsurfingMMZB-tacks`. It builds on [the nights' review](../fleet_gear/nights_review.md) (the brains sail but do not race: they change tack every 10 to 15 s) and on [training.md](../fleet_gear/training.md) (how the trainer is built). Nothing in `Game/sim/` changed. Every number below was measured on this PC while a game, the lead's baseline races and the speeder's work shared it (a load of 20 to 35 on 16 threads), so the training speeds are lower than the night will see.

## 1. In short

- **The tack discipline works on the old brains, without any new training.** After a tack or a gybe the hands now wait 20 s before they act on a wish for the other tack (a rounding cuts the wait to 6 s, because the next leg may need a manoeuvre at once). On T1 at 18 kt the two best old brains went from 78 and 81 tacks in 20 minutes to 19 to 35; three of the six races with a gap of 20 to 30 s now finish (13:19 to 19:32; the all-rounder 7:52). On S3's drops they round more marks with half the manoeuvres. A brain's file says which rule it learned with, so every old brain still sails exactly as it did (its note has no gap: the old 6 s).
- **The other half of the habit is pinching.** The old brains spend a third to a half of a race under 2 m/s, most of it 15 to 45 degrees off the wind. A floor for the wind angle (never nearer than 35 or 45 degrees) was tried and made it worse; it stays off (section 2).
- **Two new stages on the plan's two courses**, T1 and T2 at 12 to 24 kt in the game's open water as the race tool sails it: **C1**, a leg or two (the board set down where the all-rounder needs a third to two thirds of the 180 s episode to the goal), and **C2**, the whole course alone from the start line (1200 s). The all-rounder reaches **every** goal on seed 1: 40 of 40 C1 drops (in 80 s on average), 10 of 10 C2 courses.
- **The bars are shares of the all-rounder's own number on the same drops** (S1 at 100 % of its speed made good, C1 90 % of its goals and speed, C2 as many finishes and no slower), measured on a fixed set of drops so the checks of a night can be compared, and the all-rounder sails them once per run.
- **The small tries** (20 minutes each on C1 from `all_s6_best`): the brain learns in all of them (goals reached from 14 % to 33 to 38 %, the manoeuvres per drop from 5.2 to 4.0); the entropy bonus, each board its own conditions and a manoeuvre cost of 20 m showed no gain in 20 minutes and are not in the night's command (section 4).
- **30 minutes of C1 with 8 workers** took `all_s6_best` from 57.5 % to 72.5 % of C1's goals on seed 1 and from 3.2 to 4.1 m/s made good, and **T1 at 18 kt alone from 17:11 with 29 tacks to 12:27 with 20 tacks and no fall** (the all-rounder 7:52 with 3). The manoeuvres per drop fell in every 5 minutes of the curve (4.7 to 3.8).
- **RA15 is fixed**: a brain is named by its run in a race ("all_s3 best", "all_s6 best"), each board gets its own track file, and the Race page takes the best brain of the latest stage whatever its run's prefix.
- **The night's command** is in section 6: C1 then C2 from `all_s6_best`, 12 workers.

## 2. The tack discipline, measured on the old brains

**What changed** (`Game/race/learned_skipper.gd`, `Game/race/race_env.gd`). The brain's steering output is the wind angle it wants, and its sign is the tack. The hands asked for a tack whenever that sign was clearly the other tack, at most every 3 s and not within 6 s of the last manoeuvre. Now the wait after a manoeuvre is `manoeuvre_gap_s`: 20 s (`LearnedSkipper.MANOEUVRE_GAP_S`) for every brain trained from now on. During the wait the board sails the angle it was asked for on the tack it is on. When the board completes a step of the course (a mark, the gate, the start), what is left of the wait is cut to 6 s. The trainer writes the gap into the brain's file (`meta.manoeuvre_gap_s`); a brain without it keeps the old 6 s. `--manoeuvre_gap_s=<s>` sets another in the evaluation, in the race tool and in the trainer, which is how the old brains were measured here.

**The manoeuvre cost in the reward** (the alternative the brief named) was already there: 5 m per tack or gybe (`RaceEnv.Options.manoeuvre_cost_m`). It cannot be measured on an old brain: the reward changes what a brain learns, not how a finished brain sails. The trainer can now set it (`--manoeuvre_cost_m=20`); it was tried in training in section 4.

**On S3's drops** (20 drops of 60 s near a downwind mark or a gate, seed 1; `tools/train.sh --evaluate=Game/race/brains/<brain>.json --stage=S3 --episodes=20 --seed=1 --manoeuvre_gap_s=<s>`). The all-rounder on the same drops: 70 % rounded in 37.1 s, 2.10 m/s, 1.6 manoeuvres.

| Brain | Gap | Rounded | Speed made good | Falls / drop | Manoeuvres / drop |
|---|---|---|---|---|---|
| `all_s3_best` | 6 s (as before) | 55 % in 35.6 s | 2.22 m/s | 0.70 | 3.0 |
| | **20 s** | **60 %** in 33.1 s | **2.34 m/s** | 0.85 | **1.7** |
| | 25 s | 55 % in 31.6 s | 2.18 m/s | 1.00 | 1.4 |
| | 30 s | 55 % in 34.6 s | 2.10 m/s | 0.95 | 1.4 |
| `all_s6_best` | 6 s (as before) | 30 % in 35.4 s | 1.64 m/s | 0.80 | 2.8 |
| | **20 s** | **45 %** in 32.1 s | **1.88 m/s** | 0.85 | **1.5** |
| | 25 s | 45 % in 34.7 s | 1.80 m/s | 1.00 | 1.4 |
| | 30 s | 40 % in 33.3 s | 1.77 m/s | 0.80 | 1.4 |

The 6 s rows are exactly the review's numbers: the old brains sail as before.

**On T1 at 18 kt, alone** (seed 1, the game's 60 s countdown, the race up to 20 minutes; `tools/race.sh --course=t1_loop --skippers=brain:<brain> --wind_kt=18 --seed=1 --manoeuvre_gap_s=<s>`). The all-rounder alone: **7:52.0**, 3 tacks and 3 gybes, no fall.

| Brain | Gap 6 s (as before) | Gap 20 s | Gap 25 s | Gap 30 s |
|---|---|---|---|---|
| `all_s3_best` | DNF, 4 of 6 steps, 78 tacks | DNF, 4 of 6, 35 tacks, 4 falls | **13:19.0**, 19 tacks | **19:31.6**, 27 tacks |
| `all_s6_best` | DNF, 4 of 6 steps, 81 tacks | **17:10.8**, 29 tacks | DNF, 4 of 6, 34 tacks, 3 falls | DNF, 4 of 6, 29 tacks |
| time under 2 m/s | 45 % and 45 % | 41 % and 32 % | 18 % (`all_s3_best`) | |

(The review's races ended a minute after the all-rounder finished, at about 9 minutes, with 1 and 2 steps; alone the brains had 20 minutes, hence 4 steps here.)

**What I read from it:**
- Any gap of 20 to 30 s takes the tacks from about 80 to 20 to 35 a race, and the time under 2 m/s falls with it. One race each is a noisy measure (one fall or one missed layline decides a finish); the 20 drops of S3 are the steadier one, and there 20 s is the best of the three.
- **20 s stays the constant.** A longer gap blocks a needed second tack at the layline, and a brain trained under the rule should learn to want fewer tacks on its own; the gap is the backstop that stops the zigzag while it learns. The trainer can sweep it (`--manoeuvre_gap_s`).
- 19 to 35 tacks are still six to ten times the all-rounder's 3. The rule removes the worst; the habit itself has to be trained out (sections 4 and 6).

**The pinching, and a floor that did not help.** The old brains' tracks show where they are slow: 32 to 50 % of a race under 2 m/s, most of it 15 to 45 degrees off the wind (`all_s6_best` at 20 s: 1282 of its 3312 slow tenths of a second at 30 to 45 degrees, 603 at 15 to 30). A brain that points at the mark asks for 0 to 25 degrees, which the hands read as "as high as it goes on this tack" and steer into, and from low speed the board does not get going there (the scripted skipper's autopilot bears away to build speed first; these hands do not). So I tried a floor, `closest_twa_deg`: the hands never steer nearer the wind than it (gap 20 s):

| Floor | `all_s3_best` | `all_s6_best` |
|---|---|---|
| none | S3: 60 %, 2.34 m/s; T1: 4 of 6 steps, 41 % slow | S3: 45 %, 1.88 m/s; T1: finished 17:11, 32 % slow |
| 35 degrees | S3: 45 %, 1.85 m/s; T1: **1 of 6 steps, 91 % of the race slow at 30 to 45 degrees** | S3: 50 %, 2.13 m/s; T1: 3 of 6, 53 % slow |
| 45 degrees | T1: 3 of 6, only 9 % slow, but **1.7 km past mark 1**: it never tacked | T1: 4 of 6, 44 % slow |

At 35 degrees the board holds an angle it cannot accelerate at; at 45 it sails, but a wish near 0 is never "clearly the other tack", so the board sails away on one tack. Either way the old brains would need to learn what the floor means. **The floor stays in the code (a brain's note can ask for one) and is off in training**; the pinching is left to the training, where the progress reward pays for speed made good.

**On C1's drops** (the new stage, section 3; 40 drops, seed 1, gap 20 s, no floor): `all_s3_best` reaches 52.5 % of the goals at 3.06 m/s with 5.0 manoeuvres per drop; `all_s6_best` **57.5 %** at **3.2 m/s** with **4.5**. The all-rounder: 100 %, 7.35 m/s, 1.6. So the night starts from `all_s6_best`, which also learned the start in S5.

## 3. The new stages and their yardstick

`Game/race/training_drops.gd` has two stages on the plan's courses (`TrainingDrops.PLAN_COURSES`: `t1_loop` and `t2_slalom`), a coin choosing the course of each race, the wind 12 to 24 kt from the course's axis, the game's default sea (the swell) and the default wind file's gusts and shifts (off), exactly as `tools/race.sh` sails them. The old stages S1 to S6 are as they were (their tests pass); they now also carry the tack discipline.

- **C1, a leg or two** (180 s episodes, 4 boards, blind, each board set down again at once). A goal is drawn (a step after the start, up to the finish), then the board is set down back along the course from it, where the all-rounder would need 30 to 65 % of the episode to get there. The time comes from `expected_leg_s()`: the leg's length over the all-rounder's pace on a beat, a run or a reach (3.0, 4.5 and 7.0 m/s at 18 kt, half that at 12 kt and 1.2 times at 24, a little under what it sailed on T1 and T2 alone). On a long leg the board is part of the way along it; past a short one it is on the leg before (so T1's 109 m to the finish is never a drop of its own), two legs at most: the goal is the next one or two steps. Up to a fifth of what is left to either side of the leg, heading along it give or take 40 degrees, never head to wind.
- **C2, the whole course** (1200 s, stalled after 90 s without a gain): just past the start line, started, alone against the clock. No countdown: a countdown would make the four boards of a race wait for the slowest, and the brain met the start in S5. The 1200 s are for T1 at 12 kt, where the all-rounder needs about 850 s.

**The all-rounder on the drops, seed 1** (`tools/train.sh --evaluate=none --reference=allrounder --stage=C1 --episodes=20 --seed=1`, and `--seed=21`; C2 with `--episodes=5 --seed=1` and `--seed=6`):

| Stage | Drops | Reached the goal | Mean time to it | Speed made good | Falls / drop | Manoeuvres / drop |
|---|---|---|---|---|---|---|
| C1 | 40 | **40 (100 %)** | 80 s of 180 (33 to 126 s) | 7.03 and 7.66 m/s | 0 | 1.5 and 1.6 |
| C2 | 10 (6 on T1, 4 on T2, 16 to 23 kt) | **10 (100 %)** | T1 397 to 503 s, T2 157 to 212 s | 6.84 and 7.91 m/s | 0.2 | 4.0 and 5.4 |

The brief asked for at least 80 %. No C2 drop of seed 1 to 10 drew a wind under 16 kt; the race tool's T1 at 12 kt (14:41 from the gun, 849 s from the start line) shows that 1200 s holds the slowest case.

**The bars** (`stage_done()` in `tools/train/train.py`): the brain's number on a fixed set of drops (`CHECK_SEED` = 1001, not the morning's seed 1), as a share of the all-rounder's on the same drops. The all-rounder sails them once per run; its summary is kept in the run's folder (`reference_<stage>_allrounder_<n>_1001.json`); the brain and the all-rounder are evaluated side by side in two Godot processes, not one after the other.

| Stage | Done when (a share of the all-rounder's own) | Before |
|---|---|---|
| S1 | speed made good 100 % | 80 % (ended after 1 h, still improving) |
| S2, S3 | goals 90 %, within 1.1 times its time | 80 % of the drops within 40 s (the all-rounder rounds 70 %) |
| S4 | goals 90 %, within 1.3 times its time | 90 % of the laps (the all-rounder finishes 38 %) |
| **C1** | **goals 90 % and speed made good 90 %** | (new) |
| **C2** | **as many finishes, no slower** | (new) |
| S5 | the start's own numbers, as before | |
| S6 | its hours, as before | |

Every check's line also says the manoeuvres per drop against the all-rounder's, the number the nights' checks never showed.

## 4. The small tries

Four tries of C1, 20 minutes each, from `all_s6_best`, 4 workers of 4 boards, two at a time (8 workers in all, the machine shared), seed 1; the line's means over the last 60 episodes (`--recent=60`, new: the default 300 would hide a trend in 200 episodes). The numbers are the training's own, with the policy's noise on every decision (the spread starts at 0.22 of the range, about 40 degrees on the wind angle), so they start far below the same brain's 57 % without noise. The curves are in `.sim_output/train/tr<A to D>/curve.csv`, the logs in `.sim_output/tacks/tries/`.

| Try | What differs | Goal reached (after 5 min, at 20 min) | Speed made good | Manoeuvres / drop | Falls / drop | Spread | Busy |
|---|---|---|---|---|---|---|---|
| A | nothing: the gap 20 s, the cost 5 m, no entropy bonus | 16 %, **38 %** | 1.41, **3.25 m/s** | 5.2, **4.0** | 0.38, 0.22 | 0.22, 0.21 | 90 % |
| B | entropy bonus `--ent=0.005` | 14 %, 33 % | 1.58, 3.08 m/s | 5.3, 4.5 | 0.50, 0.37 | 0.22, 0.21 | 89 % |
| C | each board its own conditions (`--own_conditions=1`) | 25 %, 38 % | 2.34, 2.55 m/s | 4.4, 4.4 | 0.45, 0.37 | 0.22, 0.21 | 89 % |
| D | a tack or gybe costs 20 m (`--manoeuvre_cost_m=20`) | 11 %, 33 % | 1.79, 2.76 m/s | 5.2, 4.7 | 0.33, 0.28 | 0.22, 0.21 | 89 % |

All four learn: in 20 minutes (about 55,000 decisions, 180 drops) the goal share doubles or more and the speed made good rises. None does better than A:
- **The entropy bonus (B)** is meant against the spread's collapse, which took two hours in the nights (0.22 to 0.08). In 20 minutes the spread did not move in any try, so there was nothing for it to stop, and it learned a little slower. Not in the night's command; if the night's `std` column falls below about 0.10 while the goal share stalls, the next try is `--ent=0.005`.
- **Each board its own conditions (C)** was meant to keep a worker from waiting on a race in a rough sea. C1 and C2 sail the game's one sea, where every race costs the same, so the workers were 89 % busy either way. It learned less (C's first drops drew easier winds, so its start is higher and its gain smaller). It stays an option for S1 to S4, where the seas differ; not for C1 and C2.
- **A 20 m manoeuvre cost (D)** did not take the manoeuvres down faster than A in 20 minutes (4.7 against 4.0), and it lowers every reward, which makes the curve harder to read. The cost stays 5 m; with the gap doing the hard part, the progress reward already pays for fewer tacks (a tack costs 10 to 20 m of progress).

So the night keeps A's settings: the gap 20 s, the cost 5 m, no entropy bonus, the race's conditions.

### The 30-minute try with 8 workers

The night's first stage in small: `tools/train.sh --stage=C1 --run=try30 --minutes=30 --workers=8 --save_every_min=10 --recent=100 --seed=1 --resume=Game/race/brains/all_s6_best.json` (88 to 95 decisions a second, 157,664 decisions, 563 drops; the curve in `.sim_output/train/try30/curve.csv`, the brains in `.sim_output/train/try30/brains/`). The curve, the means over the last 100 drops averaged over each band:

| Minutes | Manoeuvres / drop | Goal reached | Speed made good | Falls / drop | Spread |
|---|---|---|---|---|---|
| 3 to 7 | 4.73 | 30 % | 2.03 m/s | 0.38 | 0.218 |
| 7 to 12 | 4.48 | 27 % | 2.58 m/s | 0.47 | 0.210 |
| 12 to 18 | 4.25 | 36 % | 3.18 m/s | 0.27 | 0.203 |
| 18 to 24 | 4.04 | 42 % | 3.01 m/s | 0.20 | 0.198 |
| 24 to 30 | **3.79** | **41 %** | 2.76 m/s | **0.18** | 0.191 |

The manoeuvres per drop fall in every band, the goal share rises, the falls halve. Then its best brain (`try30_best`, generation 2, after 20 minutes) without the training's noise, against `all_s6_best` where it started, both with the gap of 20 s:

| On the same drops and race | `all_s6_best` (the start) | `try30_best` (30 minutes of C1) | The all-rounder |
|---|---|---|---|
| C1, 40 drops of seed 1: goals reached | 57.5 % | **72.5 %** (in 125 s) | 100 % (in 80 s) |
| speed made good | 3.2 m/s | **4.1 m/s** | 7.35 m/s |
| manoeuvres, falls per drop | 4.5, 0.15 | 4.1, 0.15 | 1.6, 0 |
| T1 at 18 kt alone, seed 1 | 17:10.8, 29 tacks, 32 % of the race under 2 m/s | **12:27.4, 20 tacks, 2 gybes, no fall, 12 % under 2 m/s** | 7:52.0, 3 tacks, 3 gybes |

Half an hour on the course stages took a third of the gap to the all-rounder on T1 away, and most of the pinching. The tacks are still six times the all-rounder's; that is the night's work.

## 5. RA15: the brains' names in a race and on the Race page

- **In a race a brain is named by its run and its generation**: `brain:all_s3_best` is "all_s3 best", `brain:all_s6_best` "all_s6 best" (`LearnedSkipper.skipper_name()`). Before, both were "best", and their tracks went to one `best.csv`. In a race of one run's generations only (`tools/gens.sh`, `Skippers.make_fleet()`), they keep the short "gen 40" and "best", as before.
- **The race tool gives every board its own track file**: a second board with the same name gets `_2` (`Game/dev/run_race.gd`).
- **The Race page's "The trained brain and the personas"** takes the best brain of the latest stage in `Game/race/brains/`, whatever its run's prefix (`RacePage.latest_brain()`): C2 above C1, above S6 down to S1, and of two of the same stage the one trained last (its note's date). Today that is `all_s6_best` (it was Session 63's `s1_best`); after the night it will be `tk_c2_best`.
- Tests: `test_gens.gd` (the names of two runs' brains in one fleet; the Race page's choice among `s1_best`, `all_s3_best`, two S6 brains and a C1 brain, in a folder of test brains). The solo races of section 2 show the new names in the results ("1. all_s3 best 13:19.0").

## 6. The night's command, and how to read it the next morning

**The command** (for the lead, after this branch is merged; from whichever worktree has it, the train worktree as in the first nights; detached, so it survives the terminal):

```
cd /home/michieldz/Projects/Git/WindsurfingMMZB-train      # with gear/lead (and this branch) merged in
setsid nohup tools/train.sh --stages=C1,C2 --stage_hours=C1:8,C2:16 --workers=12 --run_prefix=tk \
    --resume=Game/race/brains/all_s6_best.json > .logs/nights_tk.log 2>&1 < /dev/null &
```

- **The stages**: C1 (a leg or two of T1 or T2) for up to 8 hours, ending earlier when the brain reaches 90 % of the all-rounder's goals and 90 % of its speed made good at an hourly check; then C2 (the whole course) for up to 16 hours, from C1's best brain, ending earlier only if the brain finishes as often as the all-rounder and no slower (checked every 2 hours on 6 courses). At most 24 hours.
- **The workers**: 12 Godot processes of 4 boards on this 16-thread PC, as the first nights; the other agents keep about four threads.
- **The run prefix** `tk`: the runs are `tk_c1` and `tk_c2`, the brains `tk_c1_best.json`, `tk_c2_best.json`, ... (nothing older is written over).
- **The resume**: `all_s6_best`, the better of the old brains on C1's drops (section 2). The gap (20 s), the cost (5 m) and the stages' conditions are the trainer's defaults; the brain's note will say them.
- To stop it cleanly: `touch .sim_output/train/STOP` (the model and a brain saved, the night ends; the same command goes on later, each stage continuing its own model).

**How to read it in the morning:**
1. **The log**, `.logs/nights_tk.log`: the stage headers ("=== stage C1 (run tk_c1, up to 8.00 h, from ...) ==="), one line a rollout and the checks. The first line should say "12 workers connected ...: C1 (course_legs) ..., a manoeuvre at most every 20 s, costing 5 m". A check reads like "check (20 drops, 4.1 min): speed made good 3.00 m/s, 50 % of the all-rounder's 6.01 (done at 90); goal 50 % against the all-rounder's 100 % (50 %, done at 90); 2.0 manoeuvres per episode against its 1.5"; "-- DONE" ends the stage.
2. **The curves**, `.sim_output/train/tk_c1/curve.csv` and `tk_c2/curve.csv`, one line a rollout: `manoeuvres_per_episode` should fall toward the all-rounder's (1.6 on C1's drops, 4 to 5 on a whole course), `goal_share` and `vmg_ms` should rise, `falls_per_episode` stay under about 0.5. `policy_std` starts at 0.22; if it falls under about 0.10 while the goal share stands still, the spread has collapsed as in the first nights, and the next try adds `--ent=0.005`. The checks in full are in each run's `checks.log`, the all-rounder's summary on the check drops in `reference_*.json`.
3. **The evaluation on seed 1**, the same drops as this report:
   ```
   tools/train.sh --evaluate=Game/race/brains/tk_c1_best.json --stage=C1 --episodes=40 --seed=1 --reference=allrounder
   tools/train.sh --evaluate=Game/race/brains/tk_c2_best.json --stage=C2 --episodes=10 --seed=1 --reference=allrounder
   ```
   Before the night: on C1 `all_s6_best` 57.5 % of the goals, 3.2 m/s, 4.5 manoeuvres per drop, and after the 30-minute try 72.5 %, 4.1 m/s, 4.1; the all-rounder 100 %, 7.35 m/s, 1.6. On C2 the all-rounder finishes 10 of 10 (T1 in 400 to 500 s, T2 in 160 to 210 s, 4 to 5 manoeuvres).
4. **The races, alone and against the all-rounder**, with the tracks:
   ```
   tools/race.sh --course=t1_loop --skippers=brain:tk_c2_best --wind_kt=18 --seed=1 --out_dir=$PWD/.sim_output/race/tk_t1_18
   tools/race.sh --course=t2_slalom --skippers=brain:tk_c2_best --wind_kt=18 --seed=1 --out_dir=$PWD/.sim_output/race/tk_t2_18
   tools/race.sh --course=t1_loop --skippers=brain:tk_c2_best,allrounder --wind_kt=18 --seed=1 --finish_window=900
   python3 Documentation/reports/fleet_gear/nights/solo_tracks.py .sim_output/race/tk_t1_18
   ```
   and the same at 12 and 24 kt. The race's line gives the time, the steps, the tacks and the gybes; the track's reading gives the wind angle by minute, the tack changes and the time under 2 m/s (the pinching of section 2). The yardstick: the all-rounder alone on T1 7:52 (18 kt), 14:41 (12), 7:37 (24); on T2 3:09 (18), 5:35 (12), 2:58 (24); `all_s6_best` today, with the gap: T1 at 18 kt in 17:11 with 29 tacks; after the 30-minute try 12:27 with 20. (`solo_tracks.py` reads the wind from 270 degrees, T1's; for T2 set its `WIND_FROM_DEG` to 232.)

**The checks before the commits:** `tools/test.sh` 671 of 671 (661 before; 10 new tests, 3 extended), `tools/check.sh` 392 files, 0 failed, `python tools/train/parity.py` torch, numpy and GDScript within 7.45e-08. Nothing in `Game/sim/` changed, so no validation run.

## 7. What I could not verify, and what is open

- **Whether a night under these rules makes a brain that races as fast as the all-rounder.** The tries are 20 and 30 minutes; the first nights also improved in their first hour and then stood still (the spread here fell from 0.22 to 0.19 in 30 minutes; watch it). The rule takes away the zigzag and the stages fit the look-ahead; whether the brain learns to tack once at the layline, and to stop pinching, only the night can tell.
- **The pinching is not solved.** The old brains are under 2 m/s for a third of a race, 15 to 45 degrees off the wind. A floor did not help (section 2). The structural cure would be in the hands: bear away to build speed when slow, as the scripted skipper's autopilot does (`bear_away_twa_deg`), for the brains trained from then on. That is a change to how a brain's output is read, for the lead and Michiel to decide (a new RA item); the night can show whether the progress reward teaches it.
- **One race per setting.** The race table of section 2 is one race each; a fall or a missed layline decides a finish. The S3 and C1 evaluations (20 and 40 drops) are the steadier numbers.
- **The fleet.** Everything here is a brain alone on the course. With company, wind shadows and the racing rules, the gap may cost a needed tack to keep clear; not measured.
- **C2 at 12 kt**: no drop of seed 1 to 10 drew under 16 kt. The race tool's T1 at 12 kt (849 s from the line) says 1200 s holds.
- **The checks stop the training while they run**: a C1 check of 20 drops takes a few minutes, a C2 check of 6 whole courses about 10 to 20 minutes every 2 hours (the end-to-end proof's C2 check of 2 courses took 3.5 minutes).
- **The start**: C2 begins just past the line. The brain met starts in S5; a race in the game still has the countdown. If the night's brain races well but starts badly, S5 after C2 is the next step.
- **The Race page on screen**: `latest_brain()` is tested in code, not looked at in a window.
- **The busy share with 12 workers** on the game's sea: 88 to 90 % with 4 workers here.
- **ROADMAP**: RA15 done; RA14 partly (the trainer changed and measured; the night that proves it is RA5's next run).
