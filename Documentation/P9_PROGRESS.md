# Phase 9 progress (handoff)

The live state of Phase 9, racing. The plan and its execution brief are in [RACING_PLAN.md](RACING_PLAN.md). **The lead updates and commits this file after every launch, report and merge**, so any session can take over.

- **Branch:** `feature/p9-racing` (from `feature/u2-fin` at f598a00, which carries U1 and U2). Agents work on `p9/<name>` branches, made from it in their own worktrees. Not pushed yet.
- **Last update:** 20 October 2026, midday (Session 51): the race is playable in the game against the AI skippers (below, "Playing a race"); after Max's first race the frame drops are fixed with threads, the start is nearer the line and the HUD is made for racing; 446 unit tests, 232 files. Everything below is merged on the branch; the tests and the check are green (443 unit tests, 228 files; the skipper's own races are in the validation suite, `tools/test.sh validation -gselect=skipper`, about 12 minutes).
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
| F1 | `sea_query` | the sea's answers for the hull at half the cost with identical results: one solve per sample point, warm-started, one pass for height, normal and velocity; the hull's rows reuse the grid's samples; `tools/sea_bench.sh` | launched 20 October 2026 (evening) | `f1/sea_query` | |

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

## Next action

**Max's next ask (20 October 2026, after his races): smarter AIs with character, a living fleet of 20 to 40 boards, trained on all the iQFOiL courses and random ones, on the full physics (no cheap models), with the tokens spent carefully.** Planned in [AI_FLEET_PLAN.md](AI_FLEET_PLAN.md) (parts F1 to F6), to be run in another chat with its "To start" prompt. **Max and Michiel answered on 20 October 2026** (the table in the plan): wind shadows yes; the rules yes; the training stack yes with a race against last night's brain every morning; 20 boards to start, 32 nice, 40 very nice; T2 stays at 60 % (200 m is the minimum); the countdown 60 s for now; the names stay; Michiel: the same controller and the same substeps for everyone, decided by the simulation. **Measured the same day** (AI_FLEET_PLAN.md, D2): 2 substeps are out (the 24 kt broad reach falls); 3 give the same steady numbers within 0.1 % but one fall at 24 kt and a 20.2 m rounding in the skipper's races where 4 give none; 4 stays unless Michiel accepts 3 (Max: 0.1 % is nothing). The sea query measured the same evening (AI_FLEET_PLAN.md, D2): the hull's three answers per sample point cost 12.1 microseconds with three solves, 6.4 with one solve and identical answers; one solve per point, warm-started, with one pass for the three answers brings a board from 3.3 to about 2.0 ms per tick with no formula changed. The lead's suggestion: the sea refactor first (Michiel's go-ahead), then 3 substeps if Michiel takes them; together about 32 to 40 boards at 60 fps and training 2.2 times faster. **Michiel's answers the same evening: the sea refactor "yes, big go"; 3 substeps OK; every board the same, no shortcuts.** Done at once: the game runs at 3 substeps (`sim_default.tres`, the spec's row, the two skipper assertions that differ at 3 relaxed with a note); the agent `sea_query` launched on `f1/sea_query` as F1's first package. T2's size and the countdown are also the answers to Stop A2's open points; the push is still unanswered. Measured for it (Session 51): the editor engine collapses at eight boards (4 fps) where the exported release engine runs them at 244 fps (`tools/release.sh`, new; the Windows export templates are installed on Max's laptop); the thread ceiling is about eight; the sea is over half a board's cost (3.3 ms per tick with waves, 1.5 flat); 2 substeps halve the cost with the same speeds on a beam reach (the validation suite decides). The start menu takes `--race=<course> [--skippers=] [--prestart=]` so an exported build can start a race from the command line.

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

## Open items

- Max's answers to the lead's questions of 19 October 2026 (the countdown length, T1 also on the lake, the lines on the water, the characters' names) and the decisions above.
- The plan's T1 episode and lap times corrected (RACING_PLAN.md).
- `Skippers.make()` returns a `RaceSkipper`; the game's race menu (9A `race_ui`) will list the characters and the brains from `Skippers.names()` and the brains folder.
- Godot rewrites `Game/default_bus_layout.tres` on some runs; every agent restored it. Worth a look at why.

## Prompts

**To continue** (paste into a new session): "Read Documentation/P9_PROGRESS.md and continue Phase 9 from its Next action, as the lead described in RACING_PLAN.md's execution brief. Wait for Max's decisions at Stop A2 before launching agents; training runs may be started when Max asks."
