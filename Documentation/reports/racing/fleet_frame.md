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

## 13 November 2026: the frame budget, and three speed-ups (branch `tech/frame-budget`)

**The question** (Max): the graphics card does little while playing; can work move to it? And: the most AI boards in a race, without changing the looks much or the physics.

**The budget** (`--measure`, release build, lake iQFOiL O2, 24 kt with the full lake waves, Ryzen 7 5800X3D with 8 cores and 16 threads, RX 6950 XT, 1280 x 720; main 4683335 before the speed-ups). The main thread, per tick and per frame:

| AI boards | fps | A physics tick | of it: the boards' physics (12 threads) | the sailors and skippers | the posing | the rest of the tick | Per frame: scripts + drawing + setup | the engine's rest | the graphics card |
|---|---|---|---|---|---|---|---|---|---|
| 11 | 86 | 8.4 ms | 4.6 | 1.7 | 1.5 | 0.6 | 1.4 ms | 4.3 ms | 5.6 ms |
| 31 | 5 | 22.2 ms | 12.4 | 4.8 | 4.0 | 1.0 | 2.4 ms | 4.6 ms | 5.9 ms |

- Beyond a tick of about 16 ms Godot runs up to 8 ticks a frame to catch up, and the frame rate collapses (23 AI boards: 8 fps).
- One board's physics alone: 2.75 ms a tick (`--threads=0`); beside the others on the threads 3.9 ms, 5.9 times faster than one after the other for 32 boards: the engine locks are mostly gone, the rest is the processor. Its parts (a temporary timing, removed again): the hull 48 %, the buoyancy 24 %, the sail 14 %, the sailor 3 %, the fin 3 %, the rest 8 %: the water is 72 % of it.
- 8, 12 and 16 threads: 16.3, 15.0 and 15.5 ms for 32 boards: 12 stays.
- Of the sailors and skippers, the controllers (the AI's hands on the controls) were 3.9 ms at 31 boards, the skippers 0.8.
- Only 3 to 9 of the 31 AI boards were in the camera's view, but every one was posed every tick.
- The graphics card: 5.6 ms a frame at 1280 x 720 (the transparent lake 3.0 ms, the opaque pass 1.0, the shadows 0.8: `--gpu-profile`), 10.4 ms at 3137 x 1263. The physics cannot move to it: shaders count in single precision (the physics in double), each of 180 substeps a second would wait for its answer, and two PCs with different cards would sail different races (LAN).
- The engine's rest, 3 to 4.5 ms a frame whatever the fleet, the window size or the water: not the HUD (`show_hud_panel` off), not the physics interpolation (off for a test: the same), not the graphics card. Not found without a native profiler.

**The speed-ups** (the race the same to the last bit: `--race_report`'s state hash, seed 7, the same before and after over a 60 s countdown, and threads against one after the other through the start and 55 s of racing):
1. An AI board's controller runs on its worker thread just before its physics. It reads only its own board and its own config copies; each board still runs its skipper, its controller and its physics in that order with the same inputs. 31 boards: the tick 22.2 -> 20.7 ms.
2. Boards out of the camera's view (with a 10 m margin) and farther than 50 m are posed every 8th tick; the board's place every tick. 31 boards: the posing 4.0 -> 1.45 ms, the tick 18.2 ms.
3. Each board is posed as soon as its own step is done (a task per board), while the threads go on. 15 boards: the physics and the posing 9.7 -> 9.0 ms.

| AI boards (seed 7) | main | after |
|---|---|---|
| 11 | 89 fps | 92 fps |
| 15 | 65 | 73 |
| 17 | 53 | 60 |
| 19 | 34 | 54 |
| 21 | 22 | 43 |
| 23 | 8 | 33 |

At 3137 x 1263, 17 AI boards: 59 fps, the graphics card 10.4 ms. The catch-up cap (RA4 (c)) tried with a switch, 2 ticks a frame at most: 25 AI boards 29 fps at 96 % of real time, 31 boards 24 fps at 79 % (7 fps without). Max: no, "full speed or nothing"; the switch is gone again.

**Left:** the physics itself (E17.S01 T4: the hull and the sea in native code would cut the 72 %; Michiel's) and the engine's rest per frame.
