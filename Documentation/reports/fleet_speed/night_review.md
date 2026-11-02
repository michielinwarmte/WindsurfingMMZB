# The second night reviewed: the brain finishes a course, but does not race it (3 November 2026)

The lead's review of package 4 of [PLAN.md](PLAN.md): the trainer of package 2 ([trainer_tacks.md](trainer_tacks.md)) run on the two courses for a night. The short answer: **the brain now finishes the courses on its own, the first brain that does, but it is still far behind the scripted all-rounder**: 1.4 to 2 times its time alone from 18 kt, no finish on T1 in 12 kt, and twice as slow again with one other board in the race. The scripted skipper stays the game's AI (the plan's decision 4). Section 6 says what the next night should change. The logs, curves, checks and evaluations are in [nights_tk/](nights_tk/).

## 1. The run

```
tools/train.sh --stages=C1,C2 --stage_hours=C1:8,C2:16 --workers=10 --run_prefix=tk --resume=Game/race/brains/all_s6_best.json
```

From `../WindsurfingMMZB-train` (branch `race/train-tk`, the code of `gear/lead` at 118fed6: packages 1 and 2 merged), 2 November 00:35 to 3 November 00:04, 10 Godot workers of 4 boards at 96 to 110 decisions a second, no crash. Ten workers instead of twelve so that the caster's and the starter's races had room beside it.

| Stage | What it trains | Episodes | Ran | Its last check | The bar |
|---|---|---|---|---|---|
| C1 | a leg or two of T1 or T2, alone, 12 to 24 kt | 180 s | 8.0 h (16 generations, 2.46 M steps, 10,841 episodes) | speed made good 4.15 m/s, 63 % of the all-rounder's; the goal in 90 % of the drops; 3.1 manoeuvres a drop against its 1.8 | 90 % of both: the goals yes, the speed no |
| C2 | the whole course alone, 12 to 24 kt | 1200 s | 16.0 h (32 generations, 5.74 M steps, 6,251 episodes), from `tk_c1_best` | finishes 67 % of the drops, in 1.58 times the all-rounder's time; 12.2 manoeuvres against its 4.3 | finishes as often, no slower: no |

**The curves** ([tk_c1_curve.csv](nights_tk/tk_c1_curve.csv), [tk_c2_curve.csv](nights_tk/tk_c2_curve.csv), the means by the hour):

- **C1 learned steadily for its eight hours**: the goal share 0.39 to 0.64, the speed made good 2.9 to 4.0 m/s, the manoeuvres 3.9 to 3.0 a drop, the falls 0.24 to 0.08. The checks on fresh drops went 56, 59, 61, 63, 62, 62, 63 % of the all-rounder's speed and 80 to 95 % of its goals. The policy's spread fell from 0.19 to 0.064.
- **C2 learned for twelve hours and then got worse**: the goal share 0.65 (hour 2) to 0.79 (hours 10 to 12) and down to 0.61 (hours 14 to 16); the speed made good 3.4 to 4.5 and back to 3.5 m/s; the falls 0.72, 0.3, and 0.85 at the end; the manoeuvres 14 to 10 to 12. The checks every two hours: finished 100, 100, 83, 100, 100, 100 and 67 % of the six drops, in 1.56 to 1.67 times the all-rounder's time. The spread fell to 0.045 by hour 12 and stayed there: **the collapse the recipe warned of, and the last four hours undid part of the work.** The best brain is generation 24 (hour 12, 20:13), `tk_c2_best`; the final one (`tk_c2_latest`) is worse (section 2).

## 2. The brains measured on the same drops (seed 1)

`tools/train.sh --evaluate=<brain> --stage=<C1|C2> --seed=1 --reference=allrounder` in the train worktree (the night's own code), the scripted all-rounder sailing the very same drops after the brain ([eval_c1_best.log](nights_tk/eval_c1_best.log), [eval_c2_best.log](nights_tk/eval_c2_best.log), [eval_c2_latest.log](nights_tk/eval_c2_latest.log)). The "before" rows are trainer_tacks.md's, on the same drops.

| Brain | Drops | Reached the goal | Time to it | Speed made good | Falls / drop | Manoeuvres / drop |
|---|---|---|---|---|---|---|
| the all-rounder | C1, 40 of 180 s | **100 %** | 78.9 s | **7.44 m/s** | 0.03 | 1.6 |
| `all_s6_best` (the starting point) | C1 | 57.5 % | | 3.2 m/s (43 %) | | 4.5 |
| the tacker's 30-minute try | C1 | 72.5 % | | 4.1 m/s (55 %) | | 4.1 |
| **`tk_c1_best`** | C1 | **90 %** | 119.4 s | **4.57 m/s (61 %)** | 0.10 | 3.2 |
| the all-rounder | C2, 10 of 1200 s | **100 %** | 335.5 s | **7.36 m/s** | 0.00 | 4.7 |
| **`tk_c2_best`** (generation 24) | C2 | **100 %** | 506.9 s (1.51 times) | 4.87 m/s (66 %) | 0.40 | 12.1 |
| `tk_c2_latest` (generation 32) | C2 | 60 % | 487.8 s | 3.27 m/s (44 %) | 2.20 | 11.9 |

Three things to read off this:
- **The night bought a third more on the legs** (the goal share 72.5 to 90 %, the speed 4.1 to 4.6 m/s) and **the whole course for the first time**: ten of ten C2 drops finished, where no earlier brain finished a lap.
- **The gap to the all-rounder is the same shape as before**: 61 to 66 % of its speed made good, two and a half times its manoeuvres, and 1.5 times its time round a course.
- **The last eight generations are a regression** (2.2 falls a race, 60 % finished): the run should have stopped at hour 12, or kept its spread.

## 3. The races, alone and against the all-rounder

`tools/race.sh` in the train worktree (the night's code; the tool's old placing, 150 m behind the line, which is where the brain trained), seed 1, the game's 60 s countdown, with the tracks ([solo_*.log](nights_tk/), [duel_t1_18.log](nights_tk/duel_t1_18.log)). The all-rounder's times are the lead's on the same code and placing (PROGRESS.md, 2 November 00:10).

| Race | `tk_c2_best` alone | the all-rounder alone | before the night |
|---|---|---|---|
| T1 12 kt | **DNF**: 2 of 6 steps, mark 1 at 13:46, 609 m from the gate at the 20-minute limit, 33 tack changes | 13:27 | `all_s6_best` DNF everywhere |
| T1 18 kt | **10:54.9**, 15 tacks, 1 gybe | 7:33 | 17:11 with 29 tacks; the 30-minute try 12:27 with 20 |
| T1 24 kt | 11:28.8, 2 falls, 19 tacks, 2 gybes | 6:40 | |
| T2 12 kt | 11:02.6, 14 tacks, 3 gybes | 5:00 | |
| T2 18 kt | 6:12.7, 1 fall, 11 tacks, 2 gybes | 3:08 | DNF at mark 1 with 22 to 26 tacks (Session 65) |
| T2 24 kt | 5:42.8, 12 tacks, 1 gybe | 3:07 | |

**Against the all-rounder on T1 at 18 kt** (`--skippers=brain:tk_c2_best,allrounder`): the all-rounder 7:46.7, the brain **19:00.1**, eleven minutes behind, where alone on the same seed it sails 10:55. It crossed the line 67 s after the gun (alone 3 s) and reached mark 1 at 8:38 (alone 4:50): in its fifth and sixth minutes it sailed a reach at 112 to 117 degrees off the wind, away from the beat, with the all-rounder in sight. C1 and C2 train the brain alone, so the other-board inputs it had learned in the first nights' S5 and S6 now derail it.

**On the merged code** (`gear/lead` at 9d785d7: packages 3 and 5 too, the all-rounder's new start, the game's own placing, 60 m behind the line; `.sim_output/review_lead/` in the lead's repo):

| Race | the all-rounder | `tk_c2_best` |
|---|---|---|
| T1 12 kt | 12:34.2 | **DNF**: 1 of 6 steps, 859 m from mark 1 at the 24-minute limit, 26 tacks |
| T1 18 kt | 7:48.9 | 17:09.5 (+9:20), 19 tacks; alone from the same placing 13:25.2, the start 1:13 after the gun |
| T1 24 kt | 6:55.2 | **DNF**: 3 of 6 steps, 3 falls, 21 tacks, the race over 15 minutes after the all-rounder |
| T2 12 kt | 4:55.3 | 15:16.4 (+10:21), 22 tacks |
| T2 18 kt | 3:09.2 | 7:07.4 (+3:58), 1 fall, 12 tacks |
| T2 24 kt | 2:30.8 | 6:20.0 (+3:49), 1 fall, 11 tacks |

The logs are [duel_*_lead.log](nights_tk/) and [solo_t1_loop_18_lead.log](nights_tk/solo_t1_loop_18_lead.log). This is the race the game would show: the brain learned its start from 150 m behind the line and from the game's 60 m it crosses 10 to 70 s after the gun even alone; against the all-rounder it is two to three times slower and does not finish T1 in 12 or 24 kt. In the game's fleet of twenty it would be last everywhere.

## 4. What the tracks show

The tracks read by the wind angle the board held ([solo_tracks.py](../fleet_gear/nights/solo_tracks.py), the wind from 270 on T1 and 232 on T2):

- **The beat is right**: 50 to 55 degrees off the wind on T1's beats in every wind, the polar's own angle, and it tacks at the laylines now rather than every 15 s (13 to 19 tack changes a race against the first nights' 30 to 43; the all-rounder 5).
- **The run is dead downwind**: 155 to 179 degrees on T1's runs and T2's deep legs, where the all-rounder runs at 130 to 140 and is twice as fast there.
- **It stops a lot**: under 2 m/s for 15 % of the race on T1 at 18 kt, 19 % at 24 kt, 28 % on T2 at 18 kt (a slalom: all reaches) and **55 to 61 % of the time in 12 kt**, pinched at 50 degrees at a mean 2.0 m/s: RA14's pinching, worst in light wind, where the board needs to foot off to get going.
- **It tacks on a slalom**: 11 to 14 tacks on T2, which the all-rounder sails with 3 gybes and no tack: at the marks it heads up and tacks instead of bearing away into a gybe.
- **Two falls at 24 kt**, in the gybes at speed.

## 5. The verdict

The trainer's changes of package 2 did what they were for: with the tack discipline and the course stages the brain learned to get round a course, and it is the first brain of this project that finishes T1 and T2. It is not a racer: 1.4 times the all-rounder alone at best, twice on the slalom, no finish on T1 in 12 kt, and eleven minutes behind with one other board in the race. **The scripted skipper stays the game's AI**, with its twenty characters; the brain is the Race page's "The trained brain and the personas" option (`RacePage.latest_brain()` takes `tk_c2_best`, the latest stage's best), where the team can watch it.

## 6. What the next night should change

In the order of their weight, all in the trainer and the hands (nothing in `Game/sim/`):

1. **Keep the spread**: `--ent=0.005` (the recipe's own remedy; the spread fell to 0.045 by hour 12 and the last four hours of C2 got worse), and stop a stage when its checks stop improving instead of running its hours.
2. **Light wind**: a C1 at 12 kt alone (the brain spends 55 to 61 % of a 12 kt race stopped), and the bear-away-to-build-speed in the hands that RA14 names (a board under 3 m/s on a beat foots off until it planes, as the scripted skipper's `FOOT_DEG_PER_MS` does).
3. **The run**: the reward's progress is measured toward the mark, which a dead run maximises per second at the slowest speed; measure it as speed made good along the polar's best run angle, or give the hands the polar's run angle as a floor.
4. **Company**: a C3 that races the brain against the all-rounder (and two personas) on the whole course, so the other-board inputs are trained on the courses too; without it the brain cannot be raced in the game's fleet.
5. **The slalom's gybes**: a manoeuvre cost for a tack where the next leg is a reach (or the hands' tack refused above 90 degrees off the wind when the target is to leeward).
6. **The boards placed as the game places them** (60 m behind the line for a 60 s countdown, or random spots; `race_env.gd` puts them 150 m back): the brain learned a start the game never gives it, and RA16's leftover (T2's reaching start from 150 m) only exists at that distance.
7. Resume from `tk_c2_best` (generation 24), not from `tk_c2_latest`.

A night costs a day of Michiel's PC; the brain's gain per night is real but slow, and the scripted skipper with its characters is what the game ships in 0.2.

## 7. Where things are

- The four brains (`tk_c1_best`, `tk_c1_latest`, `tk_c2_best`, `tk_c2_latest`) are committed on `race/train-tk` (5b1cffc) and merged into `gear/lead` (9d785d7); the 48 hourly generations stay in the train worktree's `.sim_output/train/tk_c<n>/brains/`, out of git, as before.
- The night's log, the two curves, the checks, the all-rounder's reference summaries on the check drops, the evaluations and the races: [nights_tk/](nights_tk/).
- The roadmap: RA5 (the night reviewed), RA14 (the next night's changes).
