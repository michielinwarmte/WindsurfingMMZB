# The training on Michiel's PC: every course in every condition, the brain's own push

Part 1 of [PLAN.md](PLAN.md), by the trainer agent (Claude Opus 5.5, for Fable's lead), 31 October 2026, on `race/train-all` in `../WindsurfingMMZB-train`. Michiel's brief: "new training for the AI to improve at doing the different courses in different conditions; first train them to become as fast as possible around all the courses with different wind and wave conditions; you can use all the power of the PC."

**In short:** the trainer runs on this PC (a Python venv shared by every worktree, torch with CUDA). Every training race is now drawn from the settings menu's whole range of wind and sea, the sea capped at a 0.6 m crest (the hands cannot sail rougher today), and a worker gets a new race every two episodes (before, it sailed **one course in one wind for the whole night**). The brain has a fourth output, the push slider (RA12). It starts at the slider level where the fleet sails today. The fleet's gusts run on one clock (RA13), in the game and in training. Nothing in `Game/sim/` changed. The long run is **not** launched: the command is at the end, for the lead.

## 1. The set-up

- **The venv:** `~/.local/venvs/windsurf`, outside the repo, so every worktree uses the same one. It holds Python 3.14.7, **torch 2.14.1+cu130** (PyTorch's CUDA 13.0 build, which has a wheel for Python 3.14; the driver is 615.71, CUDA 13.4), Stable-Baselines3 2.9.2, gymnasium 1.4.0 and numpy 2.5.4. torch sees the RTX 3080 Ti. `tools/train.sh` finds the venv on its own: it tries `$PYTHON` first, then the venv, then `python`. Its header has the three install lines.
- **The machine:** a Ryzen 7 5800X3D has **8 real cores**, 16 with hyper-threading. So 12 workers already share cores, and Godot's physics is the limit.
- **CPU against CUDA** (stage S1, 12 workers of 4 boards, 4 minutes each, the same seed):

| | Decisions a second | One update of the network (6,144 decisions, 10 passes) |
|---|---|---|
| CPU (`--device=cpu`) | 119 to 122 | 0.23 s |
| CUDA (`--device=cuda`) | 119 to 121 | 0.36 s |

  The network is tiny (two layers of 64), so the graphics card is slower at it: copying the numbers to the card costs more than the sums. An update takes under 1 % of a rollout, which lasts about 51 s and is all Godot physics. **The CPU stays the default.** `--device=cuda` or `auto` is there if a bigger network is ever tried.

## 2. What was changed, and why

### The conditions: the range the game offers, the sea capped at 0.6 m (`training_drops.gd`)

**What a race now draws.** Every race of every stage, S1 to S6, draws its conditions from the settings menu's ranges (`SettingsValues`). The menu's own code builds the sea, so a training race is one a player could set up:
- **The wind:** 4 to 35 kt (before: 10 to 24).
- **The sea:** one of the menu's five, at a random height, **capped at a 0.6 m crest**.
  - The five are flat water, the swell, the medium and the strong chop, and the sea made by the wind over a fetch of 0.2 to 20 km at a depth of 0.5 to 20 m.
  - The height is 0.5 to 2 times the preset's, and the swell alone 0 to 3 times.
  - **The cap** is `TrainingDrops.SEA_HEIGHT_MAX_M = 0.6`. It applies to the sea's height as the brain sees it (`sea_height`): the highest crest above still water, the sum of the waves' amplitudes.
    - **Why (the lead's decision, 31 October):** the hands cannot sail the rough end today (point 5 of section 3), so a race in such a sea teaches the brain only falling. Making the board sail rougher water is a physics and controller item for Michiel, who may raise the number once the hands can.
    - **How:** the menu's height factor for a rough sea is drawn only up to the value that keeps it at or under the cap. Each wave's amplitude is the factor times its own, so the sea's height is the factor times its height at 1. The kind of sea is drawn as before, so flat water keeps its fifth, and the seas from 0.45 to 0.6 m stay: there the brain must learn to ease the push.
  - Over 2,000 draws (the same seed both times), the highest crest above still water came out as:

| | Flat | 0 to 0.45 m | 0.45 to 0.6 m | Above 0.6 m |
|---|---|---|---|---|
| **With the cap** | **19.6 %** | **68.8 %** | **11.7 %** | **0 %** (the highest seen 0.598 m) |
| Without it (the first version) | 20 % | 66 % | 9 % to 0.7 m | 6 % above 0.7 m (up to 1.8 m) |

  Before, S1 to S3 sailed only on flat water.
- **The gust patches:** on, at a strength from 0 to 0.5 (the menu's strongest).
- **The shifts:** 0 to 45 degrees either way, at a period of 15 to 300 s.
- **The lake:** from S4 on, as designed, 30 % of the races. The wind there is the map's own, and the drawn sea is put on the lake, as the game does with the player's sea.

The courses were already the ten templates at random sizes and the random shapes, and they still are. The same seed gives the same race.

**A bug that would have wasted the nights.** In S1 to S4 a board whose episode ends is set down again in the same race, and the trainer resets a worker only once. So each worker would have sailed **one course in one set of conditions for the whole stage**: 12 courses and 12 winds in a night. The fix is in `TrainBridge`: once a race has run two episodes' time (180 s in S1, 16 min in S4), every board's episode is cut there and a new race begins, with a new course and new conditions. The cut is reported as a time limit, so the trainer values the cut episode correctly. At the start all the episodes end together, so the first cut costs nothing.

### The brain's own push (RA12)

**The fourth output.** The brain has a fourth output, `push`, which is the push slider: -1 is 0 %, +1 is 100 %, and 0 is the middle. Every decision writes it to `AiHands.push`, so the controller moves its slider exactly as the player's Up and Down keys do. The idea is that a brain can push on flat water and ease in waves and gusts; a fall already costs it 50 m.

**Old brains.** The game finds the push output **by its name** in the brain file, as it already found the inputs. A brain without one (every brain so far) leaves `AiHands.push` at NaN. That is the autopilot's own margin, as today.

**Where a fresh brain starts.** A fresh policy's push starts at the slider level that gives the autopilot's own pull, which is hike share 1.1 on `push_curve_default.tres`. That level is **78.3 %**, a third of the way from "neutral" (75 %, 1.0) to 85 % (1.3). The worker sends it in its hello and the trainer sets the output's bias to it, the way `--twa_bias` starts the wind angle at a close reach.

The match is close but not exact. At 78 % the slider also adds about 1 degree of rig lean and up to 3 degrees of "rail for the sea" in waves, which the bare autopilot does not. The pull held, the lever that pays, is the same.

**Three new inputs.** To choose the push, the brain must see the water, so the observation has three more numbers, picked by name, so old brains still sail:
- `pushing`: the push it last told the hands;
- `sea_height`: the highest crest above still water, in metres;
- `gust_spread`: how gusty the wind is. On the lake this is the map's own gust spread.

**Python and the brain files.** The export matches a brain's outputs by name too. A three-output brain, such as the S1 brain of 21 October, can start the four-output policy. Its three outputs are copied, and the push row starts fresh at 78 %. `parity.py` checks this both ways, and the parity fixture now has four outputs. The brains README says what `push` is. The evolution trainer names only the outputs its brains have.

### The gust clocks (RA13): fixed outside `Game/sim/`

`RaceWindClock` (`Game/race/race_wind_clock.gd`) holds a wind field's clock: its time, how far its air has travelled (which moves the patches), and the lake's time of day. It can hand that clock to another field. All three are public numbers of `WindField` and `MapWindField`, so nothing in the physics changed.

- **The game:** `RaceRunner` takes the clock from the player's field at every restart, because the player's gusts are the ones drawn on the water. Before every tick it hands the clock to every board's field, and after the step it reads it back. All the fields step the same time, so the fleet and the player sail in the same patches, however late a board's field was made. A new sea from the pause menu is covered too.
- **Training:** `RaceEnv` does the same every tick, and hands the clock to a board's new field when it is set down again.

The waves have their own clock (`WindsurferSim.time_s`, counted from `reset()`). In the game all the boards are reset in the same frame, so it does not matter there. In training a board set down again has its waves on another phase than the others. Its company is blind in S1 to S4, so nothing sees it; I left it.

### The trainer, for unattended nights (`tools/train/`)

- `--run_prefix=all`: the nights' runs become `all_s1` to `all_s6`. **Without it they would write over the committed brains `s1_*.json` of 21 October.**
- `--resume=<brain.json>` with `--stages` starts the first stage from that brain.
- A stage continues its own model, or else starts from the best brain of the stage before it in the curriculum, whichever stages are listed. So a stopped night goes on with `--stages=` from the stage it stopped in.
- **A stage that stops on an error** (a Godot worker that crashed or stopped answering) starts again from the model it saved on the way out, for the hours it has left, up to 4 times.
- **A clean stop:** `touch .sim_output/train/STOP`, or Ctrl-C once. Both save, close the workers and end the nights. The next start removes the file.
- **NaN or infinity:** numbers like these in an observation or a reward are set to 0 and counted. One broken board then cannot stop a night.
- **New columns on each rollout's line:**
  - `push`: the mean slider level the brain asked for (it is also in `curve.csv`);
  - `learn`: how long the network's update took;
  - `busy`: the share of the workers' time spent sailing rather than waiting for the slowest worker.
- `--evaluate=none --reference=allrounder` sails only the character, for a yardstick on its own. The evaluation's lines show each race's sea, gusts and shifts.

## 3. The two short tries (S1, 10 minutes, 4 workers of 4 boards, seed 1)

try0 is the trainer as it was: flat water, 10 to 24 kt, three outputs. try1 is the trainer as it is now: every condition and the push. The training lines show the mean over the last (up to 300) episodes, at the first and the last rollout:

| | try0 (as it was) | try1 (every condition, the push) |
|---|---|---|
| Decisions a second | 100 | 53 to 58 |
| Decisions, episodes in 10 min | 60,240, 320 | 32,912, 176 |
| Mean reward | -1.54 to -0.70 | -0.87 to -1.86 |
| Speed made good | 0.51 to 1.45 m/s | 1.27 to 0.64 m/s |
| Falls per episode | 0.00 to 0.03 | 0.00 to 0.90 |
| Manoeuvres per episode | 3.9 to 3.7 | 4.2 to 3.7 |
| Push asked for | (none) | 78 % to 75 to 77 % |

Then each try's brain sailed **the same 20 new S1 drops** (every condition, no noise), beside the all-rounder and the S1 brain of 21 October:

| On the same 20 S1 drops | Speed made good | Share of the all-rounder's | Falls / episode | Manoeuvres / episode | Rounded the mark |
|---|---|---|---|---|---|
| The all-rounder (the yardstick) | **3.70 m/s** | 100 % | 1.10 | 1.3 | 5 of 20 |
| `s1_best.json` (21 October: 0.5 h, flat water, older physics) | 3.30 m/s | **89 %** | 0.80 | 2.8 | 1 of 20 |
| try0's brain (10 min, flat water) | 2.68 m/s | 72 % | 0.70 | 0.8 | 0 |
| try1's brain (10 min, every condition) | 1.74 m/s | 47 % | 0.55 | 0.6 | 0 |

**What I see:**
1. **The rough conditions halve the pace of learning per minute.** Waves cost the physics about twice what flat water costs, so try1 made half the decisions of try0.
2. **try1's training curve went down while it learned.** The mean is over a mix of conditions that changes as new races come: its first races happened to be mild, and the later ones brought 30 kt and rough seas, where even the all-rounder falls. Ten minutes and 176 episodes are far too few to read a trend in so wide a mix. The fixed-drop table is the fair comparison, and there try1, with half the practice, is behind try0.
3. **The push moved a little, from 78 % to 75 to 77 %.** That is within the noise of 10 minutes.
4. **The S1 brain of 21 October already makes 89 % of the all-rounder's speed on the new drops.** S1's "done when" bar is 80 %, so it is already past it. Hence the suggestion to start the nights from it (section 6).
5. **The rough end of the range is beyond what the hands can sail today.** The all-rounder, sailing the autopilot's own margin:
   - on the S1 drops falls 8 times in 90 s at 35 kt in a 0.70 m sea, and 5 times at 20 kt in a 0.61 m sea;
   - on S4 falls 25 times in 4 minutes on the lake in a 0.55 m sea at 16 kt, and stalls in 0.45 to 0.83 m seas at 17 kt.

   About 15 % of the races drew a sea above 0.45 m. The brain can only learn there what the push and the course can do: ease, choose the angle, stay up. **Decided by the lead (31 October):** the sea is capped at a 0.6 m crest (section 2); the seas from 0.45 to 0.6 m stay. Sailing the rougher seas is an item for Michiel's physics and controller.

## 4. The all-rounder's yardstick (the scripted character, the pilot's own margin)

*Sections 3 and 4 were measured before the sea cap, on drops with seas up to 1.8 m. The same seeds now give lower seas in their rough races, so the numbers on the capped drops will be somewhat higher (fewer falls and stalls). The nights' first S1 check gives the new figure, or `tools/train.sh --evaluate=none --reference=allrounder --stage=S1 --episodes=20 --seed=1` in 4 minutes.*

- **S1** (20 drops, seed 1; `tools/train.sh --evaluate=Game/race/brains/s1_best.json --stage=S1 --episodes=20 --seed=1 --reference=allrounder`):
  - speed made good **3.70 m/s**; 25 % of the drops rounded the mark within 90 s (in 63 s on average);
  - 1.10 falls and 1.3 manoeuvres per episode; mean reward 0.93.
  - S1 is done at 80 % of this, so about 3.0 m/s on these drops. (Before, on flat water in 10 to 24 kt, the all-rounder made 4.8 to 5.8 m/s.)
- **S4** (10 drops, seed 1; `tools/train.sh --evaluate=none --reference=allrounder --stage=S4 --episodes=10 --seed=1`, 25 minutes):
  - speed made good **5.29 m/s**; 3.80 falls (25 of them in the one lake race in a 0.55 m sea) and 3.5 manoeuvres per episode; mean reward 8.91;
  - **finished only 3 of 10 courses in the 8 minutes** (in 243 s on average). Many courses at full size take longer than 8 minutes, and three races stalled in rough seas.
  - **S4's "done when" (finishes 90 %, within 1.3 times the all-rounder's time) cannot be met on these drops,** so S4 will always run its full 4 hours. That is fine for the nights, but the bar wants another look: the all-rounder's share, or longer episodes.

## 5. The checks

- `tools/test.sh`: **626 of 626** (617 before; 9 new tests):
  - the stages' drawn ranges over 400 seeds, and a race sailing in the conditions it drew;
  - the push output on the hands and on the controller's slider, and an old brain's NaN;
  - the push in `RaceEnv`, and the clock after a respawn;
  - two fields on one clock, and the lake's clock;
  - the new race after two episodes' time;
  - the hello's push start, and the fixture's output names.
- `tools/check.sh`: 305 files, 0 failed.
- `python tools/train/parity.py`: torch, numpy and GDScript agree to 7e-8, and a brain goes back into a policy by its outputs' names.
- No validation run: nothing in `Game/sim/` changed.

**The unattended path, tried in small:**

```
tools/train.sh --stages=S1,S2 --minutes_each=2.5 --workers=2 --run_prefix=check --check_every_min=1 \
    --save_every_min=1 --check_episodes=2 --resume=Game/race/brains/s1_best.json
```

Everything the nights need did what it should:
- **S1 started from the old brain:** "the policy starts from the brain s1_best.json (3 new inputs start at zero weight: pushing, sea_height, gust_spread) (new outputs start fresh: push)". The push started at 78 %.
- **The check:** after a minute it saved, evaluated `check_s1_latest.json` against the all-rounder and parsed the number: "3.65 m/s, 104 % of the all-rounder's -- DONE" (on two drops).
- **The next stage:** S2 started from `check_s1_best.json`.
- **The clean stop:** a `STOP` file during S2 saved it and ended the nights with the message on how to go on.
- **The runs:** `.sim_output/train/check_s1/` and `check_s2/` (the curve, `checks.log`, the workers' logs, the model), and the brains `check_s1_*.json`, all where the header of `tools/train.sh` says. The try and check brains were moved out of `Game/race/brains/` into `.sim_output/train/<run>/brains/`, so they are kept but not committed.

## 6. The long run: the command for the lead

From this worktree. It is detached, so it survives the terminal; it uses 12 workers, and the other agents keep about four threads:

```
cd /home/michieldz/Projects/Git/WindsurfingMMZB-train
setsid nohup tools/train.sh --stages=S1,S2,S3,S4,S5,S6 --hours_each=4 --workers=12 --run_prefix=all \
    --resume=Game/race/brains/s1_best.json > .logs/nights.log 2>&1 < /dev/null &
```

**About `--resume`.** It starts S1 from the brain of 21 October, which is already at 89 %. Its push output starts at 78 % and its three new inputs at zero weight. S1 should then end at its first check, after about an hour, and S2 starts from `all_s1_best.json`. Leave `--resume` out to start S1 afresh, which adds an hour or two. `PYTHON=` is not needed: the venv is found on its own. At most 6 × 4 = 24 hours. S4 and S6 always run their 4 hours, and S2, S3 and S5 end when their numbers hold.

**Where to read the state:**
- `.logs/nights.log` has one line per rollout (about one a minute at 12 workers), the stage headers ("=== stage S2 (run all_s2, ...) ==="), the checks ("check (20 drops, 3.1 min): speed made good ..., 84 % of the all-rounder's -- DONE") and the saves.
- `.sim_output/train/all_s<N>/` holds, for each stage:
  - `curve.csv`, one line per rollout;
  - `checks.log`, the evaluations in full;
  - `worker_<k>.log`, Godot's own output for each worker;
  - `model.zip` and `vecnormalize.pkl`, to continue from;
  - `generation.txt`.
- The brains, in `Game/race/brains/`:
  - `all_s<N>_best.json`, the best mean reward;
  - `all_s<N>_latest.json`;
  - `all_s<N>_gen<K>.json`, one every 30 minutes.

**How to evaluate a brain**, while the run goes on (it takes one more core):

```
tools/train.sh --evaluate=Game/race/brains/all_s1_best.json --stage=S1 --episodes=20 --reference=allrounder
tools/race.sh --course=t1_loop --skippers=brain:all_s4_best,allrounder,cautious --seconds=720
```

**How to stop it:**
- **Clean:** `touch .sim_output/train/STOP`. Within a decision the model and a brain are saved, the workers closed and the nights end. To go on later, run the same command with `--stages=` from the stage it was in; that stage continues its own model.
- **Hard:** `pkill -f tools/train/train.py; pkill -f train_worker.gd`. At most the last 30 minutes are lost.

**What to watch in the first hour:**
- **The first line.** It should come within a minute, after "12 workers connected in ... s: S1 (beat) ... 71 numbers seen", "the policy starts from the brain s1_best.json (3 new inputs start at zero weight: pushing, sea_height, gust_spread) (new outputs start fresh: push)" and "the push output starts at 0.567: the slider at 78 %".
- **The speed.** About 110 to 125 decisions a second (measured 119 to 122 with the machine otherwise idle). `busy` read 80 % with 2 workers; with 12 it will be lower, because there are more workers to wait for (not measured). A speed far lower means the machine is shared or a worker is slow.
- **A stuck worker.** No new line for more than 5 minutes and `busy` falling. The worker's log in `.sim_output/train/all_s1/worker_<k>.log` says why. After 10 minutes without an answer the bridge gives up, and the stage starts again from its saved model ("=== stage S1: the training stopped on an error (attempt 1 of 4) ...").
- **A flat curve.** `reward` and `vmg` should rise over the hour, from the brain's starting point near 3.3 m/s on these drops. If they stay flat or fall with `falls` rising, look at the `push` column. A push sliding toward 0 % means the brain is learning to stand still to avoid falls. Tell me or the lead: it would be the reward's weights, not a bug.
- **"(N numbers were not numbers)"** on a line means a board's physics gave NaN. A few are harmless; a steady stream needs a look at that worker's log.
- **The first check, after about an hour.** It shows the share of the all-rounder's speed; at 80 % S1 is done.

## 7. What I could not verify

- **Whether the brain learns the push:** ten minutes are too few. The long run's `push` column and the per-condition evaluation will tell. Nor did I check how a pushing brain looks or feels in a race against the player.
- **The game's race with the clock hand-off** ran once, in a window: `tools/screenshot.sh res://main.tscn .screenshots/train/race_clock.png 420 --course=t1_loop --skippers=allrounder,cautious,brain:s1_best` gives four boards in the countdown and no script error. I did not look at gust patches drawn and felt alike on screen: the default settings have gusts off.
- **Long runs:** the speed and the stability over 24 hours, the memory of 12 workers over a night, and the retry after a real worker crash (only reasoned through, not provoked).
- **S5 and S6** in the new conditions were not run here; they work as before (the unit tests sail them briefly).

## 8. Suggestions for the next part: about 20 characters on the trained head (D3)

- **One trained head, many hands.** Following D3, a persona is a skill sheet over the one strong brain, and `Game/race/personas/` and `persona.gd` already hold twelve. The new push output gives each persona a natural knob. A persona's **risk** can shift the brain's push (the cautious ones 10 to 20 points lower, the gamblers higher), and its **boat speed** and **consistency** can add noise to the wind angle and the push. The physics then makes the difference in falls and speed honestly. That needs a small "push offset" and "push noise" in `LearnedSkipper`, applied after the brain.
- **From rookie to pro, about 20 in all:**
  - the twelve personas, each on the trained head with its offsets;
  - a few "generations" of the nights' own brains as the weaker sailors (`all_s4_gen2` is a real beginner, `all_s6_best` a pro);
  - the all-rounder and the scripted characters as they are.
- **The persona matrix** (`tools/persona_matrix.sh`) on the trained head, at 12, 18 and 24 kt and in two seas, would show whether the specialists still show.
- **Before that, two levers on the speed of training:**
  1. In S1 to S4 the boards are blind and alone, so each board could have **its own conditions** instead of the race's. Each worker would then mix rough and flat water, and none would wait for a worker whose whole race is in a 1 m sea; `busy` will show how much that is worth.
  2. Look again at the bars for S1 (80 % is already met) and S4 (90 % finished cannot be met).
