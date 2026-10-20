# fleet_frame (F1): the frame's work with a big fleet

**Built (branch `f1/fleet_frame`):**
- **Boards batched over eight threads.** The runner now has at most 8 tasks, and each task steps a group of boards one after the other. 33 boards are split 5, 4, 4, 4, 4, 4, 4, 4, with the player's board in the first group. `--threads=<n>` sets another count and `--threads=0` steps the boards one at a time. Helper: `RaceRunner.batches`.
- **The race order once per tick.** It was worse than quadratic: `place()` sorted the whole fleet every time it was asked, and the HUD's fleet list called it inside its own sort. At 33 boards the fleet list took **320 ms** (editor engine, every 0.25 s), and each `place()` took 0.6 ms. `RaceSim` now works the order out once after the boards move, at most once per tick. That brings the fleet list down to **0.3 ms**. The places come out the same. I also fixed one bug: the fleet list was blank during the countdown.
- **Less detail beyond 300 m.** Opponents beyond 300 m (where the name label already disappears) get their sailor, rig and sail posed every other tick, and their fin's bend is not updated every frame. The board itself still moves every tick. A far board's visuals cost 0.08 ms per tick instead of 0.15 ms (measured with all 32 far: the runner's checks and visuals 5.4 to 3.2 ms per tick). Physics and skippers are never leveled.
- **`--measure`** now prints one line for all the AI boards: median and worst for physics, sailor and visuals. It also shows how many are far away, and how many tasks ran.
- **`tools/fleet_measure.sh`**: no sound, a 3-minute limit per run, and only this checkout's game is stopped.

**Measured** on the release build, back to back, while the night training ran (8 Godot processes). The numbers are noisy:

| AI boards | fps before → after | Frame avg / worst (ms) | All boards' physics per tick (ms) | A board's own step, median / worst (ms) | Rest of frame (ms) |
|---|---|---|---|---|---|
| 8 | 63 → 61 | 15.8/33.9 → 16.3/36.7 | 8.2 → 8.9 | 7.5/7.6 → 5.5/5.7 | 5.7 → 5.1 |
| 16 | 3 → 5 | 310/336 → 204/228 | 28.2 → 14.9 | 25.8/27.2 → 5.1/6.7 | 5.0 → 5.8 |
| 24 | 2 → 4 | 434/456 → 251/262 | 39.1 → 17.4 | 32.1/35.0 → 4.3/5.9 | 5.8 → 6.3 |
| 32 | 2 → 3 | 623/662 → 337/366 | 57.0 → 22.6 | 35.4/45.7 → 4.7/5.5 | 7.3 → 8.0 |

**What still stops 32 boards at 60 fps** (main thread, per tick):
- The physics: 22.6 ms. A board's step takes 4.7 ms on a thread against 1.7 ms alone. This is the lock that `no_wait` is removing.
- The skippers: 0.39 ms each, about **13 ms** in total. At 8 boards it was 0.13 ms each, so it grows with the fleet. This is for `living_skipper`.
- The visuals: about 5 ms while everyone is within 300 m, as at the start.
