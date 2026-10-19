# learn (Part 9C, the neuroevolution track): a network that teaches itself to sail T1

**Built.** `RaceObservation` (58 numbers), `NeuralNet`, `RaceEnv`, `LearnedSkipper`, the trainer (`Game/dev/evolve.gd`, `tools/race_evolve.sh`) and `Game/race/brains/README.md`. 21 new tests; 437 of 437 pass. `tools/check.sh`: 219 files, 0 failed.

**Threads slow down, processes speed up.** In Godot 4.7.2 GDScript function calls get slower when threads run side by side: 14 threads are three times slower than one. So the trainer runs one copy of Godot per core, and each copy claims races from a work folder. `--parallel=threads` stays in for measuring.

**Verified.** A hand-written policy, using `act()`, starts, rounds mark 1, passes the gate and rounds mark 1 again; the steps, bonuses and progress add up. A brain sails the same track to the last bit through `LearnedSkipper` as through `RaceEnv`.

**Learning.** The brief's run (150 m behind the line, sigma 0.1) learnt nothing in 9 generations. From there T1's 60 m line needs a tack, and the population settled on doing nothing. With the board 25 m back, sigma 0.03 and a small first output layer, boards start within a few generations. Below: the night recipe for 10 minutes. "Started" means it started in both of its races.

**Beyond the brief.** The sheet output has a dead zone of ±0.5. Without it the auto-sheet never trims: any value that is not exactly 0 counts as a hand on the sheet. A board that quits early pays for the time it had left. New options: start distance, countdown, `stall_s`, `episodes`, `output_scale`, `resume`, `evaluate`. The loader is called `load_file()`, because `load` would hide Godot's own.

**Not verified.** Tacking. The observation of other boards (one board tonight). A finish: T1's full order is about 2 km, about 7 minutes of sailing, and an episode is 240 s.

| Parallel races | 1 | 4 | 8 | 14 | 20 |
|---|---|---|---|---|---|
| Threads, ticks/s | 570 | 997 | 337 | 191 | |
| Processes, ticks/s | 521 | 1698 | 2860 | 3928 | 4388 |

```
gen  1  best -25.4  mean -26.1  started 0/48  progress -143 m  42 s
gen  4  best   0.8  mean -23.4  started 0/48  progress  -22 m  59 s
gen  8  best   1.5  mean -15.6  started 0/48  progress   52 m  68 s
gen  9  best  27.1  mean -16.7  started 1/48  progress  113 m  71 s
gen 10  best   1.7  mean -12.7  started 0/48  progress   73 m  78 s
```
