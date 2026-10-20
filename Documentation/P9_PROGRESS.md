# Phase 9 progress (handoff)

The live state of Phase 9, racing. The plan and its execution brief are in [RACING_PLAN.md](RACING_PLAN.md). **The lead updates and commits this file after every launch, report and merge**, so any session can take over.

- **Branch:** `feature/p9-racing` (from `feature/u2-fin` at f598a00, which carries U1 and U2). Agents work on `p9/<name>` branches, made from it in their own worktrees. Not pushed yet.
- **Last update:** 21 October 2026, 01:45 (Session 52, the AI fleet chat, Max asleep): the waiting of boards on threads is found and measured (below, "The thread bench"); `fleet_frame` (667122d) and `no_wait` (dcb81d5) merged; `living_skipper` still running; the night's training stage `night2a` running on 6 processes. Everything merged is green (458 unit tests, 235 files; the validation suite on `no_wait`'s branch 40 pass, 1 fail (the onset, red on purpose), 2 pending, as before).
- **Max's instruction (19 October 2026):** "go till the 2 training courses", then "experiment with the AI, use the laptop's CPU, be careful with my tokens, surprise me tomorrow". Both done; the state is below. **Stop A2 (Max's look) is open.**

## State

| # | Agent | Package | State | Branch | Report |
|---|---|---|---|---|---|
| 1 | `race_core` | RaceSim (the countdown, the steps, OCS, the clock and splits), RoundingCheck (the geometry, checked against all ten templates), RaceStep, RaceResult, `tools/race.sh` | merged (37d880c) | `p9/race_core` | [race_core.md](racing_reports/race_core.md) |
| 2 | `course_on_water` | buoys, boats and lines on the water in both scenes (`--course=<name>`, `--lines=1`), `RaceCourses` (T1 by code, saved courses by name, the pre-start spot), the course file's game-metres frame, the mini-map with the course | merged (ee79036) | `p9/course_on_water` | [course_on_water.md](racing_reports/course_on_water.md) |
| 3 | `fit_to_water` | `CourseFitter` (the shore clearance, the fit), the course maker's Fit to water button, `tools/fit_courses.sh`, `t2_slalom.json` | merged (560574d) | `p9/fit_to_water` | [fit_to_water.md](racing_reports/fit_to_water.md) |
| 4 | `skipper` | `Skipper` (the course layer: laylines, tacks and gybes, the timed start, keep clear), `SkipperConfig` and the four characters, `--skippers=` in `tools/race.sh`, `tools/race_matrix.sh` | merged (0087073) | `p9/skipper` | [skipper.md](racing_reports/skipper.md) |
| 5 | `learn` | `RaceObservation`, `NeuralNet`, `RaceEnv`, `LearnedSkipper` (the wind-angle action mode), the evolution trainer `tools/race_evolve.sh` | merged (39191b1, c279c67) | `p9/learn` | [learn.md](racing_reports/learn.md) |
| lead | | `AiHands` (the controller fed by values), `RaceSkipper` (the base of both skippers), `brain:<name>` in the race tool, the night's training run | 96928d6 | | this file |
| F1 | `sea_query` | the sea's answers for the hull at half the cost with identical results: one solve per sample point, warm-started, one pass for height, normal and velocity; the hull's rows reuse the grid's samples; `tools/sea_bench.sh` | merged c87617a (20 October 2026, late evening) | `f1/sea_query` | `racing_reports/sea_query.md` |
| lead | | the thread bench (`tools/thread_bench.sh [--release]`, `Game/dev/thread_bench.gd`, run by the start menu on `--bench=thread`): what GDScript work waits on a global engine lock | 9ea21a3 (21 October 2026, 00:00) | | this file, "The thread bench" |
| F1 | `no_wait` | the physics step without the engine's locks: the configs' numbers copied once per tick (`copy_config()`), other objects' fields read once per function, results through own fields and methods, no Dictionary or Array per substep, no Basis handed around (the body answers the axis questions: `to_body()`, `heel_rad()`, ...; `v * basis` for `basis.transposed() * v`), the world inertia kept until the axes change; **every answer bit for bit the same** (the whole state hashed every tick over 8 runs, 16 matrix CSVs, the lake: identical). Not done: the fin's two old sea queries (a warm query would move the waves by the solver's millimetre and end the bit-for-bit proof) | merged dcb81d5 (21 October 2026, 01:40) | `f1/no_wait` | [no_wait.md](racing_reports/no_wait.md) |
| F1 | `fleet_frame` | the runner's group task batched over at most 8 threads (`RaceRunner.batches`, `--threads=<n>`); the race order once per tick (`RaceSim.race_order()`; the fleet list at 33 boards from 320 ms to 0.3 ms); far opponents posed on alternate ticks beyond 300 m; `--measure` summarised; `tools/fleet_measure.sh --sizes=8,16,24,32,40` on the release build, silent | merged 667122d (21 October 2026, 01:20) | `f1/fleet_frame` | [fleet_frame.md](racing_reports/fleet_frame.md) |
| F2 | `living_skipper` | the skipper's states (free sailing in a sailing area, pre-start with the navigation skill, the line bias, the end choice, the timing loop or the hold with the hands' hold-back skill, over-early boards going back; racing; finished); AI boards spawn anywhere in the area and the countdown gathers them; `--spawn=` in the race tool and the menu's races; the 16-board validation test on T1 and T2 | **running** (launched 00:08; Opus 5.5, extra-high effort, worktree) | `f2/living_skipper` | `racing_reports/living_skipper.md` (to come) |

| Stop | State |
|---|---|
| Stop A1, the lead: 9A's agents merged, green, the courses seen in screenshots | **passed** 19 October 2026 |
| Stop A2, Max: sails among the buoys of T1 and T2; the course maker's Fit to water; the race matrix; the night's brain | **open** |

## Playing a race (built by the lead, 20 October 2026, after Max's "make it so I can race against the AIs in game")

- **Start menu:** *Race on open water* (the T1 training loop, three AI skippers: the all-rounder, the gambler and the rookie, a 60 s countdown) and *Race on Lake Silvaplana* (the T2 sprint slalom, the same three). Or from the command line: `tools/play.sh res://main.tscn --course=t1_loop --skippers=allrounder,gambler,rookie --prestart=30` (also `--laps=`, `brain:night_best` as a skipper, and `lake` with `--course=t2_slalom`).
- **On the screen:** the countdown large; at the bottom the race clock, the next mark and its distance, your place; a split at every rounding; warnings for over the line early and the wrong side of a mark; the results table when you finish or the race is over. R starts the race again; Esc is the pause menu.
- **The opponents** are full windsurfer boards (the same physics, the same beginner controller, with their AiHands), each with its character's sail colour and a name above the mast head within 300 m, and as small white dots on the mini-map. They have no wind-flag buoy of their own.
- **What it is made of:** `RaceRunner` (the boards on the line, the race told where they are each tick, R), `RaceHud`, `RaceSetup` (the menu's hand-over to a scene), `WindsurferNode.skipper` and `hands`, `RigVisuals.tint_sail` with a `sail_tint` in the sail's shader. Screenshots: `.screenshots/p9/menu_race.png`, `race_t1_countdown.png`, `race_t1_after_gun.png`, `race_t2_lake.png`.
- **Not yet:** collisions (boards pass through each other and the marks), the Race page with choices (who, laps, the countdown), the countdown sounds, the lake's shore for the opponents (they may run aground on the lake; the player stops, they do not), the frame time with four boards measured on the desktop. Not verified by a human: how it feels; the screenshots were taken with nobody steering the player's board.

### After Max's first race (20 October 2026): "a lot of frame drops, we spawn a bit far from the line, make the HUD for racing"

- **The frame drops, measured** (`tools/godot.sh --path Game res://main.tscn -- --course=t1_loop --skippers=allrounder,gambler,rookie --measure=12`, which prints the frame rate without vsync, the worst frame, and what each board's tick costs): one board's physics step costs 3.2 ms in the game, so four boards filled the whole 16.7 ms of a 60 Hz tick (16.9 ms of physics per frame, 37 to 53 fps, frames of 42 to 72 ms at worst) and the game fell into catch-up. The opponents' spray and wake were not the cost (2 fps); the skippers cost 0.4 ms each, the visuals 0.1 ms.
- **The fix:** the race runner steps all four boards' physics side by side on worker threads (`WorkerThreadPool`, one task per board), each opponent with its own copies of the config resources so the threads share nothing. Now 249 fps, a frame 4.0 ms on average and 12.3 ms at worst, the physics 8.4 ms of a frame (the four steps take 5.0 ms side by side; each is 1.5 times slower on a thread than alone, as the learn agent found). `--threads=0` keeps the old way for comparing (53 fps).
- **For Michiel:** one small change in `Game/sim/windsurfer_sim.gd`, no physics: `create_for()` got a third argument `own_copies` (default off, nothing changes) that duplicates the eight config resources for a simulation stepped on a thread beside others.
- **The start:** the boards now wait 1 m per second of countdown behind the line (60 m for the menu's 60 s; at least 40, at most 100), not the race tool's 2.5 m (150 m).
- **The racing HUD** (`RaceHud`, and `Hud.set_race_mode`): the telemetry strip and panel are hidden in a race (F1 brings the panel back) and a block at the top left shows the speed and tack, the wind, the next mark with its distance and the turn to it ("12 deg to port"), the place and the race clock, and the fleet in race order with where each board is going and its gap to you at the last mark you both rounded. The next mark is an orange dot on the compass rose. The countdown, the splits, the warnings and the results stay in the middle. The key help names the racing keys.
- The opponents' boards have no spray, wake or splashes by default (`--opponent_effects=1` gives them back); they cost little, but the margin is welcome on the laptop.

## What there is now

- **Two courses on the water.** `tools/play.sh res://main.tscn --course=t1_loop` (open water: the start line with the committee boat and the pin, mark 1 556 m upwind, the gate, the finish) and `tools/play.sh lake --course=t2_slalom` (the lake: the sprint slalom fitted to the water at 60 % of the class size, every mark 200 m from the shore). `--lines=1` draws the start and finish lines on the water. The HUD names the course; the mini-map shows it. The screenshots are in `.screenshots/p9/`.
- **A race, headless.** `tools/race.sh --course=t1_loop --skippers=allrounder,cautious,gambler,rookie --seconds=720`: the countdown, the gun, the roundings, the splits, one line per board. `tools/race_matrix.sh` runs the four characters on both courses at 12, 18 and 24 kt (the table is in skipper.md). All four finish both courses at every wind; one fall in 18 races (the all-rounder, a catapult on a 24 kt broad reach in company).
- **A learning harness and a first brain.** `tools/race_evolve.sh` trains a network by evolution on all cores (one Godot per core); `--evaluate=<brain>` races a brain; `tools/race.sh --skippers=brain:night_best,allrounder` puts a brain on the line against a character.

## The night run (20 October 2026, 02:42 to 07:42)

`tools/race_evolve.sh --run=night --hours=5 --actions=twa --population=32 --episodes=2 --episode_s=300 --start_behind_m=25 --prestart_s=5 --stall_s=30 --sigma=0.03 --sigma_min=0.01 --output_scale=0.5 --threads=16`; the log is `.sim_output/evolve/night.log` and `night.csv`.

| Generation | Best fitness | Boards starting in both races | Best's progress toward mark 1 |
|---|---|---|---|
| 1 | -4.9 | 0 of 32 | 7 m |
| 10 | 21.2 | 4 | 124 m |
| 30 | 22.2 | 15 | 223 m |
| 50 | 24.3 | 29 | 434 m |
| 80 | 25.1 | 29 | 513 m |
| 101 | 25.5 | 26 | 550 m of the 556 m beat |

- **What it learnt:** to start (the line is 60 m wide and needs a tack from some spots), to pick the tack that points at mark 1, and to beat up to it: 550 m of the 556 m in 300 s. Evaluated on 5 fresh races: 5 starts, 529 to 554 m of progress, no falls. **What it did not learn:** the rounding (steps stay at 1 of 6; it reaches the mark and does not get round it), and anything after it.
- **It does not transfer yet.** In `tools/race.sh` (a 10 s countdown, the race tool's own pre-start spot) the same brain starts but then tacks 23 times in 5 minutes instead of beating; with the all-rounder beside it (inputs it never saw, which were zeros in training) it never starts and tacks 59 times. The brain is good in exactly the conditions it trained in. That is normal for a first stage, and the next stages are made for it.
- **The ceiling:** a hand-written wind-angle policy starts at 28 s and rounds mark 1 at 204 s of race time from the same spot (a unit test). The scripted all-rounder sails the whole T1 in 8:05 at 15 kt, 7:07 at 18 kt.
- **Speed:** 2,600 to 4,000 ticks per second on 16 processes; 37 s per generation at first, 250 s once every board sails its 300 s.
- The brains: `Game/race/brains/night_best.json`, `night_gen1.json` (the rookie), `night_gen50.json` are committed; `night_gen10..100.json` are in the folder uncommitted.

## The second night (20 to 21 October 2026): `night2a`

The recommended next stage from the first night, started 21 October 2026 at 00:03, resumed from `night_best.json`: `tools/race_evolve.sh --run=night2a --hours=2.5 --threads=6 --resume=Game/race/brains/night_best.json --actions=twa --population=32 --episodes=2 --episode_s=420 --start_behind_m=150 --prestart_s=30 --spot_jitter_m=20 --stall_s=30 --sigma=0.03 --sigma_min=0.01` (the real 150 m pre-start spot, a 30 s countdown, the start spot moved up to 20 m by the seed, 420 s episodes; 6 processes so the agents' thread measurements stay readable). The log is `.sim_output/evolve/night2a.log`, the curve `night2a.csv`, the brains `Game/race/brains/night2a_best.json` and `night2a_gen<N>.json`. A second stage `night2b` on 16 processes follows once the fleet is measured on a quiet machine.

## Next action

**The night of 20 to 21 October 2026 (Session 52; Max: "lead the rest of F1 and then F2; train the AIs overnight as well").** The lead found the waiting first ("The thread bench" under Numbers: every read or write of another object's field takes a global engine lock, on the release engine too), then launched the three agents in the State table at once, and the training stage `night2a` (6 processes, 2.5 hours, so the agents' measurements stay readable; `night2b` on 16 processes follows once F1's physics package is merged and the fleet is measured on a quiet machine). The order for the rest of the night: merge `no_wait` (read its diff for Michiel: no formula change, bit-for-bit answers) and `fleet_frame` (fleet_frame first if both are ready), rebuild the release, run `tools/fleet_measure.sh --sizes=8,16,24,32,40` on the quiet laptop for F1's Stop table, start `night2b`, merge `living_skipper`, and write the two Stops for Max (F1: the table and the substeps verdict (3, done); F2: the one command to watch 16 boards gather and start). The morning race against last night's brain (D6) is `tools/race.sh --skippers=brain:night2a_best,allrounder` for now (the Race page lists brains later, in F5).

**Max's next ask (20 October 2026, after his races): smarter AIs with character, a living fleet of 20 to 40 boards, trained on all the iQFOiL courses and random ones, on the full physics (no cheap models), with the tokens spent carefully.** Planned in [AI_FLEET_PLAN.md](AI_FLEET_PLAN.md) (parts F1 to F6), to be run in another chat with its "To start" prompt. **Max and Michiel answered on 20 October 2026** (the table in the plan): wind shadows yes; the rules yes; the training stack yes with a race against last night's brain every morning; 20 boards to start, 32 nice, 40 very nice; T2 stays at 60 % (200 m is the minimum); the countdown 60 s for now; the names stay; Michiel: the same controller and the same substeps for everyone, decided by the simulation. **Measured the same day** (AI_FLEET_PLAN.md, D2): 2 substeps are out (the 24 kt broad reach falls); 3 give the same steady numbers within 0.1 % but one fall at 24 kt and a 20.2 m rounding in the skipper's races where 4 give none; 4 stays unless Michiel accepts 3 (Max: 0.1 % is nothing). The sea query measured the same evening (AI_FLEET_PLAN.md, D2): the hull's three answers per sample point cost 12.1 microseconds with three solves, 6.4 with one solve and identical answers; one solve per point, warm-started, with one pass for the three answers brings a board from 3.3 to about 2.0 ms per tick with no formula changed. The lead's suggestion: the sea refactor first (Michiel's go-ahead), then 3 substeps if Michiel takes them; together about 32 to 40 boards at 60 fps and training 2.2 times faster. **Michiel's answers the same evening: the sea refactor "yes, big go"; 3 substeps OK; every board the same, no shortcuts.** Done at once: the game runs at 3 substeps (`sim_default.tres`, the spec's row, the two skipper assertions that differ at 3 relaxed with a note; the validation suite at 3 confirmed the same evening: 40 pass, 1 fail (the onset, red on purpose), 2 pending); the agent `sea_query` launched on `f1/sea_query` as F1's first package. T2's size and the countdown are also the answers to Stop A2's open points; the push is still unanswered. Measured for it (Session 51): the editor engine collapses at eight boards (4 fps) where the exported release engine runs them at 244 fps (`tools/release.sh`, new; the Windows export templates are installed on Max's laptop); the thread ceiling is about eight; the sea is over half a board's cost (3.3 ms per tick with waves, 1.5 flat); 2 substeps halve the cost with the same speeds on a beam reach (the validation suite decides). The start menu takes `--race=<course> [--skippers=] [--prestart=]` so an exported build can start a race from the command line.

**F1's first package, the sea query, is merged (c87617a, 20 October 2026, late evening; the report is `racing_reports/sea_query.md`).** The models ask the sea once per point per substep (`WaterSurface.sample_at`): one solve, started from the point's answer a substep ago, and one pass over the waves for the height, the normal and the velocity; the hull reuses the buoyancy grid's records. No formula changed: flat water is bit for bit the same (the reach check and the 18 kt matrix identical), on waves the answers are within 0.002 mm (the solver's own tolerance is 1 mm), which moves the skipper's race times by 0.4 to 6 s and takes away the one 24 kt fall, as any micrometre nudge does. A board alone on waves went from 2.5 to 1.7 ms per tick at 3 substeps (the sea in it from 1.4 to 0.5), four boards in the release race from 2.8 to 2.2 ms of physics per tick. **Eight boards on threads stayed level (4.2 to 4.0 ms)**: there the time is not in the sea. The agent's explanation, not checked in the engine's source: reading another object's field (`board.*`, `body.*`, everywhere in the physics) takes a global engine lock, and boards on threads wait for each other there; its first version with an object per sample point made eight boards twice as slow, the packed array made them level. So the first question for the other chat's F1 is where the eight-board time goes (measure before batching); the fleet sizes come after that answer. **Max, the same evening: more threads no, the GPU no; the task is written as F1's `fleet_wait` package in AI_FLEET_PLAN.md (find the waiting, prove it by measurement, remove it with no formula change), and `feature/p9-racing` is pushed.**

1. **Max's look (Stop A2):** the two courses in the game, the Fit to water button in the course maker (`tools/play.sh wind`), the race matrix, and the night's brain (`tools/race_evolve.sh --evaluate=Game/race/brains/night_best.json --races=3 --episode_s=300 --start_behind_m=25 --prestart_s=5` prints the splits and writes the track).
2. **Decisions for Max:** (a) T2's size: 60 % with marks 200 m off the shore, or 80 % with 150 m (`tools/fit_courses.sh --mark_margin=150`); (b) the next training stage: the recommended one is `--resume=Game/race/brains/night_best.json --start_behind_m=150 --prestart_s=30 --spot_jitter_m=20 --episode_s=420` (the real pre-start and a varied spot, so the brain stops depending on one place), then with the all-rounder on the line; (c) whether to push `feature/p9-racing`.
3. **For Michiel** (findings, no change made): the 24 kt catapults on broad reaches at 13.6 to 14.1 m/s in four-board races (stop rule 2, in part); the controller's tack stops the board for about 6.5 s; at a wind angle of 150 degrees the board makes only 2.6 m/s in 15 kt against 8.7 at 92 (the skippers run at the polar's best downwind angle instead); GDScript threads slow each other down in Godot 4.7.2 (14 threads run 3 times slower than 1), so parallel work is by process; the two physics hooks of the plan (one shared wind step, a contact force) are still wanted for 9B's fleet.
4. **Then 9A's remaining tasks:** the race mode in the scenes (the player on the line with the countdown and the HUD's race items), the Race page in the menu, the results page, the countdown sounds (`race_ui`); and 9B's `fleet` (opponents in the scene, collisions, the frame time) and `start_and_tactics` (shifts and gust hunting are empty hooks).

## Numbers

Baseline on `feature/u2-fin` (f598a00): `tools/check.sh` 196 files, 0 failed; `tools/test.sh` 360 of 360. Now (96928d6): 228 files, 0 failed; 443 of 443 unit tests; `test_skipper.gd` in the validation suite (10 tests, about 12 minutes, 9 races on worker threads).

**The fitter (agent 3):** the clearance grid builds in 0.2 s; the PD3 fit takes 26 ms (29,704 tries), the LG2 2 ms. With marks 200 m from the shore the PD3 fits at 60 % (240 m slalom legs, 10 degrees right of the wind); 70 % fits nowhere (6 m short); 150 m gives 80 %, 100 m gives 90 %. The full LG2 fits square to the wind at 100 %.

**The course on the water (agent 2):** the frame rate with the course is within noise (lake 176 to 170 fps, open water about 280 to 272, vsync off on the RTX A1000).

**The skippers (agent 4), alone on T1:** the all-rounder 10:46 at 12 kt, 7:07 at 18, 6:42 at 24, no falls; it crosses the line 0.6 to 0.7 s after the gun at 18 and 24 kt, 7 s late at 12 kt. **A lap of T1 takes 7 to 11 minutes, not the plan's 3**: the LG2 sequence is two beats and two runs, and the board makes 2.9 to 4.1 m/s toward the wind.

**The learning harness (agent 5):** 521 ticks/s with 1 process, 3,928 with 14, 4,388 with 20 (threads: 570 with 1, 191 with 14). The observation is 58 numbers; the network 58-64-64-3, 8,131 weights. The stick action mode learnt almost nothing in 10 minutes; the wind-angle mode (the network says which true wind angle to hold, the controller's heading hold does the rest) started boards within a few generations.

**The sea query (agent sea_query, F1, merged):** the bench (`tools/sea_bench.sh`): a warm sample 3.5 to 4.3 microseconds against 12.5 to 12.8 for the three answers as the hull asked them before; a board's tick on waves 2.42 to 2.59 ms before, 1.60 to 1.76 after (the sea in it 1.36 to 1.48, then 0.47 to 0.62); `simulate.sh beam_reach 120 --waves=1` 22.1 to 22.5 s before, 17.5 after; the editor game with four boards 3.6 to 3.0 ms per board, one board alone 2.5 to 1.85; the release race, all boards' physics per tick, four boards 2.8 to 2.2 ms, eight boards 4.1 to 4.3 before and 3.9 to 4.1 after. Unit tests 446 to 453 (7 new, in `test_wave_field.gd`); the validation suite 40 pass, 1 fail (the onset), 2 pending, as before.

**The fleet on the release build after the sea query (lead, 20 October 2026, late evening; `tools/release.sh --race=t1_loop --skippers=<n names> --measure=12`, T1 at 3 substeps, the player's board and n AI boards on 8 worker threads, vsync off):**

| AI boards (+ the player) | fps | A frame, average / worst (ms) | All AI boards' physics per tick, side by side (ms) | The player's own board's physics per tick (ms) |
|---|---|---|---|---|
| 8 (9) | 255 | 3.9 / 12.6 | 5.6 | 4.7 |
| 10 (11) | 134 | 7.4 / 15.8 | 9.3 | 8.3 |
| 12 (13) | 33 | 30.5 / 84.6 | 12.7 | 11.3 |
| 16 (17) | 5 | 197.6 / 205.4 | 19.4 | 16.4 |

So **10 AI boards and the player hold 60 fps today; 12 do not.** The signature is contention, not work: a board's own step takes 1.7 ms alone (the bench), 4.7 ms beside 8 others and 16.4 ms beside 16, for the same physics. The sea query's saving shows alone and at four boards and is eaten here. Where the waiting is (the agent's guess: a global engine lock on reads of another object's fields) is the other chat's first F1 question.

**The thread bench (lead, 21 October 2026, 00:00; `tools/thread_bench.sh --release`; each case run on 1, 8 and 16 worker threads at once, 100,000 iterations per thread, the release engine on the laptop's 14 cores; the slowdown is the wall time with n threads divided by the time with 1, so 1.0 is perfect and 8 means the threads ran one after the other):**

| What a thread does | 1 thread, ms | 8 threads | 16 threads |
|---|---|---|---|
| float and Vector3 maths; Basis and Transform3D values; PackedFloat64Array reads and writes; a formatted String | 1 to 37 | 1.0 to 3.9 | 1.1 to 6.1 |
| calling a method of another object (`own.add(0.5)`, a getter), a static function | 10 to 21 | 1.2 to 1.5 | 1.3 to 2.0 |
| **reading a float field of another object** (`own.f`, owned by the thread, shared with nobody) | 8 to 12 | **40 to 63** | **116 to 186** |
| **writing a float field of another object** | 4 | **32** | **84** |
| reading a Vector3 or Basis field of another object | 10 | 27 to 51 | 68 to 124 |
| reading a float of a Resource (a config, own copy or shared) | 5 to 9 | 34 to 63 | 97 to 208 |
| passing an object to a typed parameter | 15 | 12 | 37 |
| `RefCounted.new()`; a small Array; a small Dictionary | 25 to 42 | 14 to 22 | 54 to 75 |

So the sea query agent's guess was right: in Godot 4.7.2, on the release engine as on the editor engine, **every read or write of another object's field takes a global engine lock**, whether or not the object is shared, and so do new objects, Arrays, Dictionaries and objects passed to typed parameters; method calls, `self.field` inside a method, static functions, packed arrays and value maths take none. (The editor engine also locks on every method call, which is why it collapses at four boards.) The physics reads other objects' fields about 800 places textually (windsurfer_sim.gd 383, hull_model.gd 132, autopilot.gd 74, sail_model.gd 65, fin_model.gd 64, mass_model.gd 49), many in loops over the hull's 21 points, at 3 substeps per tick: hundreds of thousands of locked reads per second per board. That is where the eight-board time goes, and it is the `no_wait` package's job (the pattern: read once into locals, results through own fields and method calls, bit-for-bit identical answers).

**The fleet after fleet_frame (agent, release build, before and after back to back while the training ran on 6 processes, so noisy; the lead measures again on a quiet machine after `no_wait`):** 16 AI boards: all boards' physics per tick 28.2 to 14.9 ms (8 tasks instead of 16 threads), a board's own step 25.8 to 5.1 ms; 32 AI boards: 57.0 to 22.6 ms, a board's step 35.4 to 4.7 ms (against 1.7 alone: the lock `no_wait` removes). The rest of a frame stays 5 to 8 ms at 32 boards. **New finding:** the skippers cost 0.13 ms each at 8 boards and 0.39 ms each at 32, about 13 ms per tick on the main thread at 32: the part that looks at the other boards grows with the fleet. Given to `living_skipper` (the head at 2 Hz, spread over the ticks; the hands per tick; target under 3 ms for 32).

**The physics without the locks (agent `no_wait`, release engine, before and after back to back while the training ran on 6 processes):** a board's step on waves alone / beside 3 / 7 / 15 others: 1.9 / 3.4 / 5.9 / 24.9 ms before, **1.7 / 2.8 / 3.3 / 4.6 ms after** (plain arithmetic on as many threads costs 1.6 times at 8 and 1.9 at 16 tonight: the floor). The release race with 16 AI boards and the player: 4 to 5 fps before, 52 to 205 fps after (the physics 4.0 to 4.7 ms of a tick; the race's checks and the sailors on the main thread about as much again). What is still locked, counted: about 85 field reads and 25 Basis values per substep (1,400 field reads before), 150 config copies and 130 telemetry reads per tick. A second lock found on the way: every Basis a function takes, keeps or makes comes from one engine-wide pool under a lock (`SimMath.to_body()` 39 times slower on 8 threads); products with a vector make none.

## Token ledger (D7 of AI_FLEET_PLAN.md)

| Package | Agent | Tokens | Tool uses | Wall time | Note |
|---|---|---|---|---|---|
| F1 `sea_query` | Opus 5.5, extra-high effort, worktree | 436,000 | 270 | 1 h 48 min | in Michiel's folder with the identical-answers proof; the first version (an object per point) measured and replaced |
| lead (Fable), Session 51 | the brief, the diff read, the merge, the tests, these documents | not metered here | | | |
| lead (Fable), Session 52 | the thread bench written, run twice on both engines and committed; three briefs; the training started; this file | about 150,000 so far | | 1 h | |
| F1 `no_wait` | Opus 5.5, extra-high effort, worktree | 565,000 | 228 | 1 h 40 min | Michiel's folder with the bit-for-bit proof; a second lock found (the Basis pool) |
| F1 `fleet_frame` | Opus 5.5, high effort, worktree | 167,000 | 87 | 38 min | plumbing at high effort: a quarter of the sea query's cost |
| F2 `living_skipper` | Opus 5.5, extra-high effort, worktree | running | | | |

## Open items

- From the sea query (F1): `fin_model.gd` still asks the sea twice per substep the old way (it was outside the package; a small follow-up in F1). The comment in `wave_field.gd` and the table in the spec's 9.5 ("about six passes") are for the old wave set; the default sea needs two or three passes cold (for Michiel; nothing changed). `reset()` leaves some sailor state alone (the knee bend, the felt hand moments, the tipping timer): on waves a reset board differs from a new one by 1.3 mm after 2 s, before and after the change (for Michiel).

- Max's answers to the lead's questions of 19 October 2026 (the countdown length, T1 also on the lake, the lines on the water, the characters' names) and the decisions above.
- The plan's T1 episode and lap times corrected (RACING_PLAN.md).
- `Skippers.make()` returns a `RaceSkipper`; the game's race menu (9A `race_ui`) will list the characters and the brains from `Skippers.names()` and the brains folder.
- Godot rewrites `Game/default_bus_layout.tres` on some runs; every agent restored it. Worth a look at why.

## Prompts

**To continue** (paste into a new session): "Read Documentation/P9_PROGRESS.md and continue Phase 9 from its Next action, as the lead described in RACING_PLAN.md's execution brief. Wait for Max's decisions at Stop A2 before launching agents; training runs may be started when Max asks."
