# The AI fleet: smarter skippers, personas, and 20 to 40 boards on the full physics

Written 20 October 2026 (Session 51) by Claude Fable 5.1 for Max and Michiel, and for the AI session that builds it, in another chat. It continues Phase 9 of [RACING_PLAN.md](RACING_PLAN.md) after Max's first races against the three scripted skippers; the state is in [P9_PROGRESS.md](P9_PROGRESS.md).

Max, 20 October 2026: "I want the AI to be more smart: AIs with character that spawn on a random location before the competition and manage the start as best as possible, and the race. The same AI must perform well in a slalom and a course race. When there is no race it just free-sails, and when a countdown starts it goes to the start line and starts as close to 0 as possible. Mistakes are okay, a player makes them too, but it needs to be trained so it performs well. More personalities, so a persona can be good at slalom but worse in course racing. I want to run 20 to 40 AIs in one race; it needs to be optimised. Think with me so we can make this feel more like real life." And then: "Train randomly on all iQFOiL courses and random ones. No polar boards: that can cause cheating, not falling and so on. Is there no way to make the AIs less impactful but keep the full functionality? This is a long process and my tokens must be spent super carefully."

## What was measured first (Session 51, Max's laptop, an i7-12700H with 14 cores)

| | |
|---|---|
| A board's physics, one tick in the game | 3.2 ms (the sea is more than half of it: 1.5 ms on flat water) |
| The same with 2 substeps instead of 4 | 1.7 ms with the waves, 0.9 ms flat; the steady speed the same to two decimals on a 120 s beam reach (one case; the validation suite decides) |
| Four boards side by side on threads, the editor engine | 5.0 ms; 249 fps |
| Eight boards, the editor engine | collapse: each board's step 22 ms, 4 fps |
| Eight boards, the **release engine** (the exported game, `tools/release.sh`) | 5.2 ms side by side; 244 fps, 14 ms at worst |
| Sixteen boards, the release engine | collapse again: 17 ms per board, 4 fps (the thread ceiling is about 8, and the frame's other work grows with the fleet) |

So: the editor build we always played in is what made the race stutter at four boards and what collapses at eight; the exported game scales to eight. GDScript threads stop paying beyond about eight, so a bigger fleet must share eight threads. And a board can be made twice as cheap by integrating the same physics more coarsely, and nearly twice again with a cheaper sea query, without taking anything away from what it does.

## The design

### D1. A skipper is a head and a pair of hands

- **The hands** keep the board fast and upright through the real physics: the trim, clean tacks and gybes, surviving a gust, and, new, holding back before the start without stalling. Today these are `PlayerController` (beginner mode, auto-sheet) and `Autopilot`, driven through `AiHands`. They take a wanted wind angle and "tack now"; they never see the course.
- **The head** decides where to go: the start plan (which end of the line, the approach, when to turn in), the laylines, the shifts and gusts, the traffic, the gybe-mark entries in slalom, and before the race, where to sail for fun. It thinks at 1 or 2 Hz on a coarse picture (the course's next steps, the wind here and around, the nearest boards) and only ever gives the hands a wind angle and a manoeuvre request. Today the scripted `Skipper` is a head written as rules; the night's brain was a head learnt by evolution.
- One head serves slalom and course racing because it sees only the next steps of whatever course it is on (RaceSim's steps: lines, marks with a side, gates), and it is trained on all of them (D6).

### D2. One physics, the same for everyone: no cheap model, no cheating

Every board, the player's and every AI's, runs `WindsurferSim` with the same controller, the same autopilot and the same substeps: it falls, it catches gusts, it slams on waves, it obeys the same rules. (Michiel, 20 October 2026: "the same AI controller and steps for everyone, every AI the same." The earlier idea of a coarser integration for far boards is dropped.)

- **The substeps are 3 for every board** (Michiel, 20 October 2026, from the measurements below; 2 is out: the 24 kt broad reach falls).

**The substeps, measured (20 October 2026, for Michiel's verdict).** The physics tick is 1/60 s cut into substeps; every force is computed at every substep, so the cost is per substep and nothing in the model changes with their number, only how finely it is integrated. The reach check (nine steady cases, flat water, 40 s each) and the validation suite (the polar, the onset, the stability, the recovery, the waves, the fin, and the skipper's races on T1 and T2 at 12, 18 and 24 kt) at each setting:

| Substeps | Step | Cost per board and tick (waves) | The reach check against 4 | The validation suite against 4 |
|---|---|---|---|---|
| 4 (today) | 1/240 s | 3.3 ms | | 40 pass, 1 fail (the onset, red on purpose), 2 pending (U1's targets) |
| 3 | 1/180 s | about 2.5 ms | all nine cases the same within 0.1 % (the 24 kt broad reach: 16.45 against 16.42 m/s, pitch steadiness 0.23 against 0.25 deg) | the same, plus two differences in the skipper's races: the all-rounder falls once alone on T1 at 24 kt (none at 4), and rounds T2's mark 2 at 20.2 m instead of under 20 |
| 2 | 1/120 s | 1.7 ms | eight cases the same within 1 %; **the 24 kt broad reach at 32 knots falls** (a catapult: pitch steadiness 5.4 deg where 4 gives 0.25) | not run: the reach check already fails |

What it means: the steady sailing is the same at 3 and 4; the fast events at 24 kt (a catapult on a broad reach, a fall in a long race) are where a coarser step shows, because the board, the sailor on the harness and the rig move fastest there. At 2 the integration itself gives way in the fastest case. So 4 stays unless Michiel accepts 3 with its 24 kt difference (a quarter of the cost saved; the fleet from 16 to about 21 boards at 60 fps). The sea query is the bigger and the safer lever: half of a board's cost without touching the integration.
- **The sea query, measured (20 October 2026).** The hull asks the sea three things at each of its 21 sample points (7 rows x 3 columns) every substep: the height, the normal and the water's velocity. Each answer first solves the Gerstner rest point by a fixed-point iteration (up to 8 passes of the 4-wave sum, about 4 on average), then sums the 4 waves again. Measured on the default sea: one wave sum 0.9 microseconds; `height_at` 3.8; the three answers as the hull asks them 12.1; one solve and then the three answers from it 6.4, **identical to 0.000 mm**. So the buoyancy grid alone costs 21 x 12.1 x 4 substeps = 1.0 ms of the 3.3 ms tick, and the hull's other velocity queries add to it (the sea is about 1.8 ms in all: 3.3 ms with waves against 1.5 flat).
  **The cheaper query, with identical answers:** solve the rest point once per sample point per substep; start the solve from that point's rest point of the previous substep (the board moves 4 cm per substep, so one or two passes reach the millimetre instead of four to six); and compute the height, the normal and the velocity in one pass over the 4 waves, since they share the same phases. About 3 microseconds per point instead of 12, within the solver's own millimetre: the sea from about 1.8 ms to about 0.5 ms per tick, a board from 3.3 to about 2.0 ms at 4 substeps and about 1.5 ms at 3. It is a refactor of `wave_field.gd`, `buoyancy_model.gd` and `hull_model.gd` (Michiel's folder) that changes no formula; the reach check and the validation suite prove the answers unchanged, `--measure` the cost. One package for one agent, with Michiel's go-ahead. **Built and merged** (F1, agent `sea_query`, 20 October 2026): the sea in a board's tick 1.4 to 0.5 ms; the numbers in the budget below and in P9_PROGRESS.md.
- **The release engine** (`tools/release.sh`): the game and the training runs use the exported build, where threads scale. The editor build stays for development and the tests.
- **Eight threads, boards batched:** the race runner's group task gets at most eight tasks, each stepping a batch of boards one after the other, so 32 boards cost about four boards' time per thread. The frame's other work with many boards (the HUD's fleet order is quadratic today, the labels, the figures) gets the same treatment: levels of visual detail beyond 300 m, the fleet order computed once per tick. Only visuals are leveled; the physics never is.
- **The budget, from the measurements:** at 4 substeps today, 16 boards cost about 16 x 3.3 / 8 x 1.3 = 8.6 ms of physics per tick: 60 fps on the laptop with room; 32 boards about 17 ms, too much. With the cheaper sea query (identical answers) a board costs about 2.0 ms: 32 boards about 10 ms, 60 fps. With 3 substeps as well, about 1.5 ms: 32 boards 8 ms, 40 boards 10 ms. Max's sizes: 20 to start with, 32 nice, 40 very nice; measured at 8, 16, 24, 32 and 40 in F1.
  **Measured after the sea refactor (merged c87617a, 20 October 2026):** a board alone on waves 2.5 to 1.7 ms per tick at 3 substeps; four boards in the release race 2.8 to 2.2 ms of physics per tick; **eight boards on threads 4.2 to 4.0 ms, level.** So at eight boards on threads the time is not in the sea, and the budget above does not yet hold for a fleet on threads: the next F1 package measures where the eight-board time goes before any fleet size is measured. The agent's explanation, not checked in the engine's source: a read of another object's field takes a global engine lock (an object per sample point made eight boards twice as slow; a packed array made them level), and the physics reads `board.*` and `body.*` everywhere. If that is it, the lever is in Michiel's folder: the values a model reads many times per substep copied once into locals or packed arrays at the top of its step, no formula touched.
  **The fleet measured after the merge (release build, T1, 8 worker threads, the player and n AI boards):** 8 AI boards 255 fps; 10 AI boards 134 fps; 12 AI boards 33 fps; 16 AI boards 5 fps. **Today's ceiling is 10 AI boards and the player at 60 fps.** A board's own step takes 1.7 ms alone, 4.7 ms beside 8 others, 16.4 ms beside 16: the same work, three to ten times the time, which is waiting, not computing. The table is in P9_PROGRESS.md (Numbers).

### D3. One strong brain, many personas

Train one good head and keep one good set of hands, then make a persona from a **skill sheet** that degrades or biases them. The sheet (numbers from 0 to 1, with their effect):

| Skill | What it changes |
|---|---|
| start timing | the error on the start plan's clock (0: +/- 8 s, 1: +/- 0.5 s) |
| start nerve | how close to the line and how near the favoured end it dares to be |
| tacking, gybing | the time lost and the chance of a fall in each (slalom specialists gybe; course specialists tack): on the full physics these are the hands' noise and timing in the manoeuvre |
| boat speed | the hands' noise and reaction time on the trim and the heading hold |
| upwind sense | how well it sees wind shifts (a lag and a noise on the wind it reads) and whether it uses laylines early |
| downwind sense | the same for gusts and the gybe angles |
| gust appetite | how far it goes looking for more wind (the lake's gusts) |
| risk | the margins at marks and laylines, OCS risk |
| aggression | how close it sails to others, whether it takes a leeward position in a pack |
| consistency | the day-to-day wander of all of the above |
| gear | the sail and fin size it chooses for the wind (a bigger sail is faster in light wind and overpowered in strong; a smaller fin gybes better): real config resources, so the physics makes the difference |

A persona is a sheet plus a name, a colour, a home water and a short profile the menu shows ("Lena: slalom specialist, fearless starts, loses the beat"). One training run gives dozens of personas, and a persona's strengths show in the results: slalom specialists at the top on the slaloms, course specialists on the windward-leewards. Style biases on top, no training needed: prefers the left side of the beat, starts at the pin, sails low and fast, points high, gybes wide. Every fall is the physics' own: a persona only makes the hands clumsier, never the board.

### D4. Behaviour states, so the fleet lives on the water

Every skipper runs a small state machine:
- **Free sailing:** no race on. It picks a point of sail and a leg, sails it for a while, tacks or gybes, stays inside the sailing area, keeps off the shore and the others. Where it spawns is random inside the area.
- **Pre-start:** a countdown has begun. It works out the time to the start area and goes there (a navigation skill: the fewest manoeuvres to a point), reads the line bias (which end is nearer the wind), picks its end by its sheet, and runs its start plan: a timing loop (sail away on a reach, turn back so that it reaches the line at the gun at full speed), or a hold near the line (the new "hold back" skill of the hands: luff and sheet out without stopping), with its timing error. If it is over early it goes back round the end.
- **Racing:** the head's race tactics.
- **Finished:** sails clear of the finish, then free sailing.

### D5. What makes it feel real (in the order of effect)

1. **Wind shadows.** A sail leaves a cone of slower and disturbed wind behind it (about 5 mast heights long, 30 % less wind near the sail, fading). A `FleetWindField` wraps the scene's wind field and subtracts the shadows of the boards upwind of a point: no change inside `Game/sim/`, which only asks the field for the wind at a point. The boards in a pack then slow each other, the favoured end gets crowded, and a clean lane matters.
2. **The start crowd:** line bias, the loop, over-early boards going back, the boat end packed. From D3 and D4.
3. **The rules:** port and starboard, windward and leeward, mark room, with a penalty turn (RACING_PLAN.md, 9E). The AI keeps clear by the rules; the player gets a warning and a penalty.
4. **Crashes at the gybe mark** in slalom: the physics does them when the hands are clumsy and the mark is crowded.
5. **Gear:** personas on different sails and fins, visibly.
6. **Sound and sight of a fleet:** the sails all round, the splashes, the names.

### D6. The training: all the courses, random ones, on the real physics

- **The courses.** Every race the trainer draws a course: one of the ten iQFOiL templates (LG2, LR2, O2, I2, US3, US4, PD3, SD3, PM1, SM1, from `CourseTemplates`) at a random size between 40 and 100 % of the class's distances, or a random shape of the same families (a windward-leeward, a trapezoid, a slalom with 2 to 5 marks, a reaching start or an upwind start), set to a random wind of 10 to 24 kt with the default gusts and shifts, on the open water or on Lake Silvaplana (fitted to the water by `CourseFitter`, in the map's wind at a random hour). The head never sees the same race twice, so it learns racing, not a course.
- **The head** by PPO in Python over the bridge of RACING_PLAN.md (9C), on the real physics at the substeps Michiel settles on, on the release engine, 6 to 12 boards per race in self-play (every board the same network, each with a random skill sheet, so it learns to race with and against every kind of skipper). Observation: its own state and sheet, the next two steps' geometry, the line's bias and the time to the gun, the wind at points around, the nearest 6 boards. Actions: the wanted wind angle, tack or gybe now, hold back. Reward: the finishing place and time, minus OCS, collisions and rule breaches, as RACING_PLAN.md's table, extended for the fleet.
- **The compute, estimated from the measurements (at 2 substeps; double the times at 4):** a board on flat water costs 0.9 ms per tick, with waves 1.7 ms; a process runs one race; 20 processes on the laptop. A 6-board race of 6 minutes with waves is 6 x 21,600 x 1.7 ms = 3.7 minutes on one process, so about 320 races an hour on 20 processes; a 12-board race about 160 an hour. The self-play of a head needs on the order of 10,000 races: three to five nights, with checkpoints to watch after each night, as the night of 19 to 20 October gave. Flat water doubles that pace for the early stages. That is the price of training on the real physics, and it is nights of the laptop's time, not tokens.
- **Every morning, a race against last night's brain** (Max, 20 October 2026: "in-between test runs in game for me to try every morning"): the trainer writes each night's checkpoint as `Game/race/brains/latest.json`, and one command puts it on the line with two characters: `tools/release.sh --race=t1_loop --skippers=brain:latest,allrounder,rookie`. The Race page lists the latest brain when the file is there.
- **The hands** stay the scripted controller and autopilot, improved where the skipper agent found them short (the tack stops the board for 6.5 s; no way to slow down without stalling; the gybe entry), and optionally refined by the evolution trainer on the fine physics with a speed reward, per wind. The night's harness, the observation and the brain file carry over.
- **The test before the game:** the trained head races on fine boards in `tools/race.sh` against the scripted skipper on all ten templates at three winds; it must finish them all and beat the all-rounder more often than not.

### D6b. F5's training design (21 October 2026, after two nights of evolution)

Agreed with Max on 21 October 2026, after the gens tool showed what two nights of evolution buy: brains that start, beat to mark 1 and park beside it. The inputs were not the problem (the brain already sees the next two steps with their distance, bearing, bearing from the wind and the side to leave them on); the candy was, and the rehearsal.

**1. The candy follows the course, not the straight line to the mark.** The old reward paid "metres closer to the next mark", so the best-paid place on the course was beside the mark, and going round it (sailing away first) cost candy. The new reward, per tick:
- On a leg whose next point lies inside the tacking cone (its bearing from the wind within the pointing angle plus a margin), the reward is the **speed made good to windward along the course axis**, so going out to a layline pays the same as pointing at the mark, and the brain can learn that sailing further from the mark before tacking is faster (Max). Inside the gybing cone downwind, the same with the speed made good downwind.
- Otherwise (the mark can be laid), the reward is the **closing speed to the rounding point**: the point past the mark where the rounding completes, on the correct side, not the mark itself.
- **A bonus for every completed rounding** (worth about 50 m of progress), a **small penalty for every tack and gybe** (about 5 m: the lost speed already costs progress; the candy makes the lesson clear early), the penalties for falls (50 m) and OCS (50 m), a bonus for finishing (100 m) and the time penalty, with the weights in `RaceEnv`'s table as before.
- Two numbers more in what it sees: the bearing to the rounding point, and the direction of the leg after the mark.

**2. Training in parts (a curriculum), each from random situations with short episodes**, the same brain carried from part to part, each part ended by a criterion or by the morning:

| Stage | Dropped where | Episode | Paid for | Done when |
|---|---|---|---|---|
| S1 the beat | 150 to 600 m below a windward mark, up to 200 m to either side, any heading, 10 to 24 kt | 90 s | speed made good, few tacks | its speed made good is 80 % of the all-rounder's |
| S2 the rounding | 60 to 150 m from a mark at any bearing, inside and outside the laylines, port and starboard roundings | 60 s | the rounding, then the next leg | 80 % of the drops round within 40 s |
| S3 the run and the gybe mark, the gate | the same, downwind steps and gates | 60 s | the same | the same |
| S4 full laps | the ten templates at random sizes and random shapes, 10 to 24 kt, both waters (D6) | 8 min | the whole course | finishes 90 %, within 1.3 times the all-rounder's time |
| S5 the start | F2's sailing area, the countdown, the line and its bias | 3 min | the start, OCS | starts within 10 s of the gun, OCS under 10 % |
| S6 company | 6 to 12 boards in self-play, the wind shadows once F3 lands | 8 min | the place and the time | beats the all-rounder more often than not on all templates |

**3. PPO in Python over the bridge** (decision 3: torch and Stable-Baselines3 on Max's PC), as RACING_PLAN.md's 9C planned and the night of 19 to 20 October did not build (it built the evolution harness instead). The head decides at 2 Hz (D1); between decisions the hands sail. Each Godot worker runs one race of up to 12 boards and exchanges all its boards' observations and actions with Python once per decision, so a 16-process laptop gives about 300 decisions per second. The trainer writes a brain file every half hour of training as `Game/race/brains/<run>_gen<N>.json` and the best as `<run>_best.json`, so `tools/gens.sh --run=<run>` shows the progress of any night, and `brain:<run>_best` races in the game.

**What it costs.** The learning costs the laptop's nights, not tokens: the short stages (S1 to S3) a few hours each, S4 and S5 a night each, S6 two nights or more: four to six nights in all, each started with one command (`tools/train.sh --stage=<name> --hours=<n>`, resuming from the last brain). The tokens went to building it: Fable itself built the whole of it in Session 53 (21 October 2026) for about 470,000 of context (the ledger in P9_PROGRESS.md), instead of the planned agent at extra-high effort; a look at the curve each morning costs under 50,000. Done once on Max's PC in Session 53: `pip install torch stable-baselines3` (torch 2.14 for the CPU, Stable-Baselines3 2.9).

**Built as designed, with three things settled in the building (Session 53):** (1) the reward is a *potential*: the fall of the sailing distance still to go round the course (SailingDistance.remaining_m), which gives D6b's two rules (the speed made good inside the cones, the closing speed to the rounding point outside) as one continuous number, pays nothing for a detour, and can only ever pay for completing a step (the triangle inequality); (2) the head decides every half second (D1's 2 Hz), written in the brain's note, and its third output is the hold-back; (3) brains pick their inputs by name, so the observation can grow (the personas' skill sheet of D3 goes in the same way) without retiring the brains made before.

### D7. Tokens: how the process stays cheap

This is a long process, and Max's tokens are the scarce thing; the laptop's nights are not. So:
- **The lead plans, briefs, merges and measures; it does not read code it does not have to.** Every package is a written brief with the file list, the tests and the one-line tool that measures it, as RACING_PLAN.md's execution brief does. No exploratory agents.
- **Fewer, larger agents:** one agent per part where possible, at extra-high effort only for the packages that touch the physics' edges or the training (F1's resolution work, F5); high effort for plumbing, menus and personas.
- **Measure with one-line tools** (`tools/race.sh`, `tools/race_matrix.sh`, `--measure`), never by reading CSV files or transcripts.
- **Michiel's parts are Michiel's:** the substep validation, the sea query, the hands' tack. They are asked for with exact lines, not built around.
- **Compute runs are Max's:** one command, a night, a look at the curve in the morning; the lead reads the last lines of the log, not the log.
- **A ledger** in P9_PROGRESS.md: the tokens each part cost (the night's five agents cost 0.3 to 0.9 M each; the lead's own work on the race in the game cost less than one agent), so the team sees the rate.

## Parts, in order

- **F1. The cheap full physics.** `tools/release.sh` (done, Session 51); the substeps for everyone (done: 3, Michiel's decision, 20 October 2026); the sea query (done, merged c87617a: one solve per point, identical answers; `fin_model.gd`'s two queries per substep stay on the old path: a warm query would move the waves by the solver's millimetre, so it waits for a package that may); **`fleet_wait`: where boards on threads wait, and its removal** (done: the cause measured 21 October 2026 and removed by the agent `no_wait`, merged dcb81d5, bit for bit the same answers; a board beside 15 others from 24.9 to 4.6 ms); the runner's eight-thread batching, the fleet order once per tick and visual levels beyond 300 m (done: the agent `fleet_frame`, merged 667122d); `tools/fleet_measure.sh --sizes=8,16,24,32,40` on the release engine (the table in P9_PROGRESS.md). *Stop: the table of frame times by fleet size, and Michiel's verdict on the substeps.*
  **`fleet_wait` (the next package, first):** find where boards stepped side by side on worker threads wait for each other, and remove the waiting without touching a formula. Measured 20 October 2026 (release build, T1, 8 threads): a board's step takes 1.7 ms alone, 4.7 ms beside 8 others, 16.4 ms beside 16, the same work; 10 AI boards and the player hold 60 fps, 12 do not. The guess to test first: a global engine lock taken when GDScript reads a field of another object (`board.*`, `body.*`, the config resources) or passes an object to a typed parameter; the sea query agent saw an object per sample point make eight boards twice as slow and a packed array make them level. Prove it with a measurement before changing anything (one board's step timed with 1, 4, 8 and 16 idle boards reading nothing, then reading fields, in `Game/dev/`); then the fix, if that is it, in Michiel's folder with his one condition (no formula changes, identical answers): each model copies what it reads many times per substep into locals or packed arrays at the top of its step. Ruled out by Max (20 October 2026): more threads (14 ran 3 times slower than 1; more waiters) and the GPU (thousands of small branching steps per board in GDScript; the compute is not the problem: 40 boards are 68 ms on one core, 9 ms over 8 without the waiting). *Stop: the measured cause, and the fleet table again after the fix.* **Measured (21 October 2026, 00:00, `tools/thread_bench.sh --release`; the table is in P9_PROGRESS.md): the guess was right. Every read or write of another object's field takes a global engine lock on the release engine as on the editor engine (100,000 reads: 8 ms on one thread, 500 ms per thread on eight, 1,475 on sixteen), shared or not; so do new objects, Arrays, Dictionaries and objects passed to typed parameters. Method calls on another object, `self.field` inside a method, static functions, packed arrays and value maths take none. The fix is the agent `no_wait`'s package (launched the same night): each model reads what it needs once per step into locals or its own fields and gives its results through its own fields and method calls, bit for bit the same answers.**
- **F2. The living skipper.** The state machine, free sailing in an area, the navigation skill, the start plan with the timing loop and the hold-back skill in the hands, the end choice from the line bias; spawning anywhere; the countdown gathers the fleet. In the game with the scripted head. **Built** (the agent `living_skipper`, merged babc43b, 21 October 2026: 16 boards from random spots all start within 6 s of the gun on both courses at 15 kt; the head thinks at 2 Hz). *Stop: Max watches 16 boards gather and start.* (Open for Max, P9_PROGRESS.md.)
- **F3. Real life.** Wind shadows, the keep-clear rules with penalties, gear per persona. **Built** (the shadows and the rules; Session 53, 21 October 2026, by Fable itself: [racing_reports/real_life.md](racing_reports/real_life.md); gear per persona goes with F4). The shadow's numbers are Michiel's: `Game/config/wind_shadow_default.tres`; the one physics-side change is the hook `WindField.disturbance` (PHYSICS_SPEC.md 8.11), null by default. *Stop: Max races in a crowd* (open, P9_PROGRESS.md).
- **F4. Personas.** The skill sheet, the profiles, 12 personas, the fleet picker in the menu (size, who), the results by course family showing the specialists. **Built** (Session 53, 21 October 2026, by Fable itself: [racing_reports/personas.md](racing_reports/personas.md); the sheet on the scripted skipper, the trained head's side when a stage is done; the gear built but off until Michiel tunes the sail sizes). *Stop: the team names them* (open, P9_PROGRESS.md).
- **F5. The trained head.** The training design of D6b (the candy along the course, the curriculum S1 to S6, PPO over the bridge), the random-course drops, the Python package, the nights with `<run>_gen<N>.json` for `tools/gens.sh` and the morning race for Max, the evaluation on all templates against the scripted head, the personas on the trained head. Moved ahead of F3 and F4 on 21 October 2026 so the laptop's nights are used. **The trainer is built** (Session 53, 21 October 2026, by Fable itself: `tools/train.sh`, the report [racing_reports/trainer.md](racing_reports/trainer.md); the all-rounder's yardstick on S1's drops 4.8 to 5.8 m/s of sailing distance made good); the nights are the next step (P9_PROGRESS.md, "Next action"). *Stop: the first fleet race against the trained head.*
- **F6. The big fleet in the game.** 24 and 32 boards measured and played; 40 if the frame allows. *Stop: 32 boards at 60 fps on the laptop.*

## The decisions (answered 20 October 2026)

| | Decision | Answer |
|---|---|---|
| 1 | Wind shadows | Max: yes. Michiel sets the shape and the numbers. |
| 2 | The rules first | Max: yes: port and starboard, and room at the mark; a penalty turn for the AI, a warning and a time penalty for the player. |
| 3 | The training stack | Max: torch and Stable-Baselines3 on his PC, nights of training, **and a race against last night's brain every morning** (D6). |
| 4 | The fleet size | Max: 20 to start with, 32 nice, 40 very nice. |
| 5 | T2's size | Max: 200 m from the shore is the minimum: T2 stays at 60 %. |
| 6 | The countdown | Max: 60 s for now; longer later. |
| 7 | The characters' names | Max: leave them; the next development may rename them, the lead's choice. |
| 8 | The substeps | Michiel: the same controller and the same steps for everyone, every AI the same, no shortcuts. Measured (D2): 2 is out, 3 is the same steady physics with a 24 kt fall difference. **Michiel took 3** (20 October 2026, evening); the game runs at 3 since then. |
| 9 | The sea query | Measured (D2): one solve per point instead of three, warm-started, one pass for the three answers: a board from 3.3 to about 2.0 ms with identical answers. **Michiel: "yes, big go"** (20 October 2026); the agent `sea_query` built it as F1's first package, **merged c87617a** the same evening: a board alone 2.5 to 1.7 ms on waves at 3 substeps, flat water bit for bit the same, waves within 0.002 mm; eight boards on threads level with before, the next lever (D2's budget). |
| 10 | More threads for the fleet? | **Max: no** (20 October 2026). The boards wait on each other, they are not short of cores: 14 threads ran 3 times slower than 1. The task is `fleet_wait` (Part F1). |
| 11 | The GPU for the physics? | **Max: no** (20 October 2026). Thousands of small branching steps per board in GDScript, and the compute is not the problem (40 boards are 9 ms over 8 cores without the waiting). |
| 10 | The tack that stops the board | Michiel asked whether the tack is the autopilot's: half of it. The turn through the wind (its rate, heading up, when to stop) is `PlayerController._steer_tack` and `_start_manoeuvre`; the sail's part (backing it, flipping the rig to the new side) is the `Autopilot`'s tack phases (`update_tack`, `carry_boom_across_the_flip`). Both are the hands, the same for the player and the AI, so the 6.5 s cost everyone. |

Not answered yet: pushing `feature/p9-racing` to GitHub.

## To continue in another chat

F1 and F2 were built in the night of 20 to 21 October 2026 (Session 52); F5's trainer, F3 and F4 on 21 October (Session 53), and the nights of F5 started that afternoon. Paste the "To continue" prompt at the end of P9_PROGRESS.md.

## Sources and prior art

- The two-level skipper (boat handling under tactics) is how sailors and coaches split the sport, and how racing games build drivers: one good controller, error and style models per driver (Togelius and Lucas, "Evolving controllers for simulated car racing", 2005; the industry's driver profiles).
- Self-play PPO for multi-agent racing: "Gran Turismo Sophy" (Wurman et al., Nature 2022) trained a racing agent against a fleet with rules by self-play on the real game physics.
- Wind shadow of a sail: about 5 to 7 mast heights of disturbed air downwind, strongest within 2, as sailing tactics books (Stuart Walker, "Advanced Racing Tactics") and wind-tunnel studies on sail interaction describe; the numbers want Michiel's eye.
- The game's own measurements: this file's first table; P9_PROGRESS.md, Session 51; RACING_PLAN.md, "The numbers".
