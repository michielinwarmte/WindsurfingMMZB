# F1: no waiting (agent no_wait, 21 October 2026)

Branch `f1/no_wait`, from `feature/p9-racing` (9ea21a3). No formula changed; every answer is the same to the last bit.

**The cause** (`tools/thread_bench.sh --release`): two engine-wide locks. The object table's: reading or writing another object's field, handing an object to a typed parameter, comparing it with null. The Basis pool's: a function taking, keeping or making a Basis (SimMath.to_body() 39 times slower on 8 threads). Method calls, statics, packed arrays and `v * basis` take neither.

**What changed.** Models copy their configs' numbers once per tick (`copy_config()`; configs never change inside a tick). Functions read others' fields once; the hull's helpers take no objects; no Dictionary, Array or array literal in the substeps. The body keeps its world-axes inertia until its axes or inertia change, and answers axis questions itself (`to_body()`, `heel_rad()`), as does the rig. `basis.transposed() * v` became `v * basis`: the same products in the same order.

**Still locked** (counted in the code): per substep about 85 field reads (about 1,400 before) and 25 Basis values; per tick about 150 config copies and 130 telemetry reads and writes. The sail's and fin's coefficient curves still read their configs (the autopilot calls them too).

**Not done:** the fin's two sea queries: cold, `sample_at` saves nothing; warm, it saves 10 µs of a 1.7 ms tick and moves waves runs by the solver's millimetre.

**The goal.** Beside 8 others a board's step costs 1.45 to 2.0 times its 1.7 ms alone, against 1.6 for plain arithmetic on as many threads: the waiting is nearly gone. 16 AI boards: 52, 116 and 205 fps in three runs; their physics is 4 to 4.7 ms of a tick, the race's checks and sailors (main thread, outside Game/sim) as much again.

A training (6 Godot processes) ran throughout, before and after alike, back to back.

| | Before | After |
|---|---|---|
| Unit tests; validation | 453/453; 40 pass, 1 fail, 2 pending | 453/453; 40 pass, 1 fail (the onset, 6.89 m/s), 2 pending |
| Whole state hashed every tick (flat, waves, falls, water starts, nose dive: 8 runs); `simulate.sh beam_reach 60` flat and `--waves=1`; `matrix.sh` 18 kt and 24 kt waves (16 CSVs); lake, 3 straight runs | | identical to the last bit |
| Release bench, a board on waves, ms per tick: alone / beside 3 / 7 / 15 | 1.9 / 3.4 / 5.9 / 24.9 | 1.7 / 2.8 / 3.3 / 4.6 |
| Only arithmetic on as many threads (the floor): x8 / x16 | 1.6 / 1.9 | 1.6 / 1.8 |
| Release race T1, 8 AI + player: fps; all boards' physics; a board's step (ms) | 164–242; 5.7–6.9; 5.1–6.2 | 209–299; 2.9–3.7; 2.5–3.5 |
| 16 AI + player | 4–5; 20.9–22.9; 18.4–20.4 | 52–205; 4.0–4.7; 3.1–4.2 |
| `sea_bench.sh` (editor engine, autopilot on the threads): alone on waves / 8 boards (ms) | 1.9–4.2 / 18.1–25.4 | 2.5–3.9 / 17.0–19.8 |
