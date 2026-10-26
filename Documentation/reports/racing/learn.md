# learn (Part 9C, the neuroevolution track): a network that teaches itself to sail T1

**Built.** `RaceObservation` (58 numbers), `NeuralNet`, `RaceEnv`, `LearnedSkipper`, the trainer (`Game/dev/evolve.gd`, `tools/race_evolve.sh`) and the brains README. `--actions=twa` is now the default: the network gives the wind angle to hold. One `LearnedSkipper.Driver`, shared by trainer and game, steers for it every tick. 442 of 442 tests pass (26 mine); `tools/check.sh`: 219 files.

**Threads slow down, processes speed up** (table). In Godot 4.7.2 GDScript calls get slower when threads run side by side, so the trainer runs one Godot per core.

**The ceiling.** A hand-written wind-angle policy, from 25 m behind the line, starts at 28.3 s and rounds mark 1 at 204.2 s (209 s after reset). A learner must come close to that to round mark 1 within 240 s.

**Learning, 10 minutes each.**
- The first wind-angle brains tacked their boards to a standstill: their wish flipped sides as the board turned.
- The fix: a wish counts as the other tack only between 25° and 165° off the wind, and no tack until 6 s after the last one.
- After the fix, the wind-angle mode beats the stick mode (lines below).
- From 150 m back with a 30 s countdown: no start in 9 generations, but progress of +50 to 66 m, where the stick mode settled at -20 m.
- What is missing: choosing the tack from where the mark lies.

**Beyond the brief.** The sheet's dead zone; a quitter pays for its unused time; the tack rules above; `--output_scale=0.5` in the wind-angle mode (0 means head to wind).

**Not verified.** Learnt tacking; other boards; a finish (T1's full order is about 7 minutes).

**Finding.** At 150° the board makes 2.6 m/s in 15 kt, against 8.7 m/s at 92°.

| Parallel races | 1 | 4 | 8 | 14 | 20 |
|---|---|---|---|---|---|
| Threads, ticks/s | 570 | 997 | 337 | 191 | |
| Processes, ticks/s | 521 | 1698 | 2860 | 3928 | 4388 |

```
        stick (48 boards)                 twa (32 boards)
        best   mean  started            best   mean  started
gen  1  -25.4  -26.1   0                 1.1  -23.4   0
gen  4    0.8  -23.4   0                 1.5  -17.9   0
gen  8    1.5  -15.6   0                 1.7   -4.9   0   (median 1.4)
gen  9   27.1  -16.7   1                27.2   -7.3   5
gen 10    1.7  -12.7   0                27.2   -6.5   4
```
