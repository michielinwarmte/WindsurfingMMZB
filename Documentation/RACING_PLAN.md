# Phase 9 Plan: Racing, and the skippers who race you

Written 19 October 2026 (Session 50) by Claude Fable 5.1 for Max, Michiel and the AI sessions that will build it. It fills in Phase 9 of [REBUILD_PLAN.md](REBUILD_PLAN.md) ("Gameplay: racing"). The rules and commands are in [CLAUDE.md](../CLAUDE.md); the course maker this plan builds on is W4a in [MAP_SILVAPLANA_PLAN.md](MAP_SILVAPLANA_PLAN.md).

Max asked for three things on 19 October 2026: races with AI opponents; opponents that are a little different from each other; and, because he is fascinated by neural networks that learn by reinforcement, one or two courses to train such skippers on. This plan does all three, in an order where the game gets a playable race first and the learning comes on top of it.

## How to use this plan

- Work through the parts in order (9A to 9D; 9E is optional polish). Tick a box only when the task is done **and verified**.
- Every part ends with a **Stop**: a plain-language summary and a play-test checklist for the team, a suggested commit, and the team's go-ahead before the next part.
- Record every session at the top of [PROGRESS_LOG.md](PROGRESS_LOG.md). If the plan is wrong somewhere, change it, say why in the log, and mention it at the next Stop.
- The execution brief at the end says who builds what (the lead, the agents, the branches) and when to stop.

## Status

| Part | What | Status |
|---|---|---|
| 9A | A race you can sail alone: the course on the water, the start, the rounding, the clock, the results | 🔶 Built up to the two courses (Sessions 50 and 51): the race core and the rounding geometry, the buoys and boats on the water, T1 and T2 (fitted to the lake), the headless race tool; the race mode in both scenes with the countdown, the HUD's race items, the results and two Race buttons in the start menu (Session 51); the Race page with choices and the countdown sounds are still to build; state in [P9_PROGRESS.md](P9_PROGRESS.md) |
| 9B | Scripted skippers: three opponents with their own characters, built on the Phase 4 autopilot | 🔶 The skipper and its four characters built (Session 51): all finish T1 and T2 at 12, 18 and 24 kt headless; the fleet sails in the scene with sail colours and name labels, its physics on worker threads after Max's first race showed frame drops (Session 51: 249 fps with four boards, 53 without threads); collisions are still to build |
| 9C | The learning harness: the race as a training environment, the bridge to Python, the first learned skipper on course T1 | 🔶 The harness built with an in-Godot evolution trainer first (Session 51, the night run): a brain learnt to start and beat to mark 1 on T1, not yet to round it; the Python bridge and PPO are still to build |
| 9D | Learned skippers in the game: the curriculum T1 to T2, personalities, evaluation | ⬜ |
| 9E | Later: racing rules and penalties, replays, a leaderboard | ⬜ |
| 9F | The AI fleet: a head and hands, polar boards for the far ones, personas as skill sheets, a living fleet that free-sails and gathers for the start, wind shadows and rules, a trained head, 20 to 40 boards | 📝 Planned (Session 51): [AI_FLEET_PLAN.md](AI_FLEET_PLAN.md), parts F1 to F6, five decisions for Max and Michiel first |

**Phase 9 is done** (the rebuild plan's "done when") at the end of 9B: a full race against three AI opponents. 9C and 9D are Max's neural-network track on top of it.

## What we are building, in plain words

- **A race.** You pick a course, a wind and up to three opponents. A countdown runs, the gun goes, you sail the course round its marks, through its gates and over the finish line. The game keeps the time, the splits at every mark and your place, and shows a results table at the end.
- **Two courses to begin with, and any course the team makes.** T1 is a short windward-leeward loop on open water, the training ground. T2 is a sprint slalom on Lake Silvaplana in the Maloja wind. The course maker (W4a) already lets the team put any iQFOiL course on the lake; every course saved there becomes a race.
- **Opponents who sail the same physics you do.** An AI skipper gets the same board, the same controls and the same limits as the player. It cannot cheat: no hidden push, no knowledge a sailor could not have. It can only sail better or worse, and differently.
- **Two kinds of skipper.** *Scripted* skippers follow written rules (hold close-hauled, tack on the layline, round the mark with a margin), with a handful of personality numbers each. *Learned* skippers are small neural networks that taught themselves to race by sailing the course thousands of times headless, rewarded for progress and punished for falling. The scripted ones come first: they are the safety net if the learning disappoints, and the yardstick the learned ones are measured against.
- **Different from each other.** A scripted skipper has a character sheet (how high it points, how big a margin it takes, how early it starts, how often it hunts a gust). A learned skipper gets its character from what it was rewarded for, from the random seed it learned with, and from how far through its training it was when we saved it (a rookie and a veteran are the same network at different ages).

## Key decisions

### RD1. The AI sails like a player
An AI skipper drives the board through the same `PlayerController` (beginner mode, auto-sheet) and `Autopilot` the player uses, with the same rates and limits. It may read only what a sailor on the water could know: its own telemetry, the course, the other boards it can see, and the wind on the water around it (`WindField.velocity_at`, which on the lake includes the gusts the player sees as ripples). Nothing in `Game/sim/` knows about races or skippers (D2, D6, D8 stay as they are).

Why: the physics is the game. An opponent that is fast because it is given a push is not an opponent, and the team could never tell a physics problem from an AI problem.

### RD2. Scripted first, learned on top
The scripted skipper (9B) is built before any learning. It makes Phase 9 playable on its own, it provides opponents for the learned skipper to train against, and its lap times are the measure of whether learning worked.

### RD3. Learning: PPO in Python, the race in Godot, our own small bridge
The learned skipper is trained with PPO (Proximal Policy Optimisation, the standard method for this kind of task) from the Stable-Baselines3 library in Python, with Godot running the races headless. The two talk over a local TCP socket with one JSON line per message. We write that bridge ourselves (one GDScript file, one Python file) rather than adopt the Godot RL Agents plugin: the plugin is written for Godot 4 but its fit with 4.7.2 is unverified, it brings its own node types and conventions, and our own bridge is about 200 lines each side that the team can read. Its design (one process per training environment, a sync step, batches of boards) is borrowed from the plugin.

Fallback, if the bridge or PPO fights us: neuroevolution inside Godot (a population of networks, the best ones kept and mutated), which needs no Python and no backpropagation, only more compute. Section "If PPO disappoints" says how.

### RD4. A brain is a built artefact, like the Blender models
A trained network is saved as `Game/race/brains/<name>.json` (the weights, the input scales, the names of the inputs, and a note of the physics commit and the training run it came from). The game runs it with a GDScript forward pass (`NeuralNet`, about 60 lines). A unit test checks that the GDScript network gives the same outputs as Python on 20 saved inputs, to within 1e-5. When the physics changes (U1, U2, anything later), the brains are retrained with one command, as the models are rebuilt after a config change.

### RD5. Courses are `Course` objects
Races use the course maker's `Course` and `CourseMark` (W4a) unchanged: the marks, the official order ("Start-1-4S/4P-1-4S-Finish"), the rounding sides. The two built-in courses are templates placed by code; the team's saved courses load from `Game/maps/silvaplana/courses/`. Open-water courses get an optional "game metres" frame in the file, because they have no Swiss coordinates.

### RD6. Simple rules first
Version one has no right-of-way rules and no protests. A board over the line early must go back behind it (the one rule every sailor knows). Boards and marks are soft: a collision is a gentle push apart and a loss of speed, nothing more. Rules and penalties come in 9E, once the team has raced and knows what annoys them.

### RD7. Difficulty and personality never touch the physics
A weaker skipper has worse numbers in its character sheet (a longer reaction time, a noisier helm, a bigger margin), or is an earlier checkpoint of a learned one. Nobody gets a lighter board or more wind.

### RD8. Branches and the physics track
9A and 9B are built on `feature/p9-racing` from `feature/u2-fin` (Max's decision on 19 October 2026 to build now: that branch carries U1 and U2, which Max plays on, and this plan; the pull requests go in the order U1, U2, P9). They do not depend on the U1/U2 physics. Training (9C, 9D) waits until U1 and U2 are merged, because a brain is trained against one physics and must be retrained when it changes. The few additions to `Game/sim/` that racing needs are small and go past Michiel: a way to step one shared wind field once per tick instead of once per board, and a contact force for collisions (section "What racing asks of the physics").

## The two courses

### T1: the training loop on open water

- The shape of the windward-leeward course with a gate (template LG2), set to the scene's wind, at 30 % of the class's size: the beat about 550 m, the leeward gate 150 m above the start line, the gate 75 m wide, the start line 60 m (the class rule gives less for four boards; the skippers need room).
- Order: start, mark 1 to port, the gate (either mark), mark 1 again, the gate again, finish. In the game a race is one lap of this sequence (two beats and two runs); it takes the scripted all-rounder 8 minutes at 15 kt and 7 at 18 kt (Session 51 corrected the plan's 3 minutes, which forgot the second beat and overrated the board's speed to windward: 2.9 to 4.1 m/s). Training episodes are shorter: the start and the first beat to mark 1 take about 200 s.
- Wind 15 kt with the default gusts and shifts (`wind_default.tres`), the default gentle sea; also run at 12 and 24 kt. Flat water is a training option.
- Why this course: it has everything a windsurfer race asks for except gybing round slalom marks: the start, a beat with tacks and laylines, a rounding, a run with gybes, a gate choice, a finish. It is short, so a training episode is cheap.

### T2: the sprint slalom on Lake Silvaplana

- The sprint slalom (template PD3, also the iQFOiL medal race MR2): a reaching start to mark 1 600 m from the pin, a 830 m run to mark 2, two 400 m slalom legs with 25° between them, the finish. Placed by Max in the course maker in the main basin, square to the lake's 14:30 wind, and saved as the team's course `t2_slalom`; the plan's code loads it by name. If it does not fit, Max scales it (80 % is fine).
- The map's wind of the day with its moving gusts and the lee of the shore, thin air, fresh water (the lake scene as it is).
- **Placed to fit the water.** Max, 19 October 2026: a template placed by code would land on the shore. So a course placed by code, and the course maker on request, fits itself to the lake: every mark at least 200 m from the shore, every leg over water with 50 m of clearance, found by trying the class's size first and then smaller (down to 40 %), the wind's axis first and then up to 15° off it, over every spot on the lake; the largest course that fits, closest to the wind, nearest the preferred spot, wins (`CourseFitter`). The fitted T2 is saved as `t2_slalom.json`, so the game loads it instead of fitting at startup.
- Why: gybes at speed round marks, gusts worth hunting, a shore to stay off. It is the iQFOiL race the game was always meant to have ("slalom racing against AI opponents", the rebuild plan's "What we are building").

### Any saved course

The race menu lists `t1_loop` and `t2_slalom` and every course saved by the course maker. A course with a mark on land or a leg over land is listed with its warning and can still be raced (the skippers will sail round the land as best they can).

## How a race works

### The flow

1. **Pre-start.** The boards are placed 150 m behind the start line, spread across it, sailing slowly on a reach (the player on the autopilot until they touch a key). The countdown runs: 60 s by default; 30 s and 3 min are settings. Sounds at 60, 30, 10 and 5 to 1, and the gun, made from noise like everything in Phase 8.
2. **The gun.** The race clock starts. A board over the line at the gun (or crossing it before) is OCS ("on course side"): the HUD shows it, and the board's crossing only counts once it has gone back behind the line.
3. **The legs.** The next step of the course (a mark, a gate, the finish) is the only thing checked. The HUD shows its name, its distance and the way to it; the mini-map shows the marks and every board.
4. **The finish.** The clock stops at the line; the board keeps sailing. The results page opens when everyone has finished, or 60 s after the first finisher, or on Esc: place, name, time, gap, the split at each mark, falls.

### When a mark counts as rounded

A plain geometric rule, in one place (`RoundingCheck`, unit-tested), so a board cannot cut a corner or be refused a fair rounding:

- **A line** (the start, the finish, a gate): the board's track crosses the segment between its two ends, in the leg's direction. The start crossing counts only after the gun and only from behind the line.
- **A single mark** with a rounding side: let *in* be the direction of the leg arriving at the mark and *out* the direction of the leg leaving it. The board rounds the mark on its outside, so it crosses the ray from the mark along *in − out* (the turn's outside bisector) at most 80 m from the mark, going the turn's way. Crossing the opposite ray is the wrong side and does not count (the HUD says so). A turn of 180° (a windward mark on a windward-leeward) gives a ray pointing upwind; a 25° slalom turn gives one pointing out of the turn. A mark sailed straight past (*in* = *out*) uses the perpendicular on its required side.
- A fallen or aground board keeps its place in the order; nothing is lost but time.

### The player's HUD during a race

The countdown large in the middle; the race clock; "next: mark 1, 420 m" with an arrow on the compass rose; the place ("2nd of 4"); a split line for 3 s at every rounding ("mark 1: 1:42, +0:06 on Lena"); the OCS warning; the mini-map with the course, the boards as coloured dots and the wind arrow (today it is lake-only: it gets a course-centred mode for the open water). The other boards carry a name label above the mast head when within 300 m and a sail of their own colour.

## The skippers

### The scripted skipper (9B): the autopilot given a course

The Phase 4 `Autopilot` holds a wind angle and trims the sheet; the beginner `PlayerController` holds a heading and does tacks and gybes on request. The scripted skipper is a layer above them, `Skipper`, that decides where to go next and asks the controller for it. It never writes to `SimControls` itself. Its rules, in order:

1. **The target point** for the current step: a mark, offset by a margin (5 to 15 m, by character) to its required side; a gate, the mark that is nearer or better placed for the wind; the start, a spot on the line chosen by character (the boat end, the middle, the pin); the finish, its middle.
2. **Can I sail straight there?** The bearing to the target gives the true wind angle it needs. Between the close-hauled limit (about 45°, plus the character's pointing offset) and the running limit (about 165°) it holds that heading.
3. **Upwind:** hold close-hauled on the present tack until the layline to the target (with a margin in metres by character), then tack. Tack earlier when the wind has headed by more than the character's shift sensitivity and the other tack is lifted, or when the shore (on the lake) is closer than a safety distance. A cap on the number of tacks per beat.
4. **Downwind:** the same with gybes: sail the fast broad reach, gybe on the downwind layline. Dead downwind is slow on a windsurfer, and the polar in [POLAR_15KT.md](POLAR_15KT.md) says so; the skipper reads its gybe angle from the polar, not from a constant.
5. **The start:** a timed run. Sail away from the chosen spot on a reach, turn back when the time left equals the distance divided by the expected speed, plus the character's timing error (early starters risk OCS, late ones lose metres). Cross at speed.
6. **Keep clear:** a board within 15 m and converging makes the skipper bear away a little to leeward of it. No rules are enforced on anyone in version one (RD6).
7. **Gust hunting** (the lake only): sample the wind 100 to 200 m ahead on both tacks and lean the decision toward the side with more wind, weighted by the character's gust appetite.
8. **Reaction and noise:** every decision is delayed by the character's reaction time, and its wanted heading wanders by its steering noise, so a weak skipper sails a wobbly line and a strong one a clean one.

**The character sheet** is a resource, `SkipperConfig` (`Game/race/skippers/<name>.tres`), so the team can edit a skipper in the inspector:

| Number | What it does | Range |
|---|---|---|
| `name`, `sail_colour` | shown on the label, the results and the mini-map | |
| `pointing_offset_deg` | sails higher (negative) or lower and faster (positive) than the polar's best upwind angle | −4 to +6 |
| `layline_margin_m` | how far past the layline it goes before tacking: a small margin means more tacks and a risk of not laying the mark | 0 to 60 |
| `mark_margin_m` | how close it rounds | 4 to 20 |
| `reaction_time_s` | the delay between seeing and doing | 0.2 to 1.0 |
| `steering_noise_deg` | the wobble of its line | 0 to 6 |
| `start_spot` | 0 = the pin, 1 = the boat | |
| `start_timing_error_s` | negative starts early (OCS risk), positive late | −3 to +6 |
| `shift_sensitivity_deg` | how big a header makes it tack | 5 to 20 |
| `gust_appetite` | how much more wind it goes looking for (lake only) | 0 to 1 |
| `max_tacks_per_beat` | | 2 to 8 |

Three characters to ship with (Max and Michiel name them): a clean, fast all-rounder with small margins; a cautious one with big margins, a late start and no OCS ever; a gambler who points low and fast, starts at the boat end early, and hunts gusts. A fourth, "the rookie", with a long reaction time and a noisy helm, for beginners to beat.

### The learned skipper (9C, 9D): a network that taught itself

**What it is.** A small neural network (about 45 inputs, two hidden layers of 64, 3 outputs) that is asked ten times a second "what now?" and answers with three numbers: how hard to turn, how much to ease the sheet, and whether to tack or gybe now. Those are exactly a player's keys, fed into the same beginner controller (RD1). Between two answers the last one is held.

**What it sees** (the observation, each number scaled to about −1 to 1, with fixed scales written in the brain file; the same code builds it for training and in the game):
- Itself: speed, the true wind angle as sine and cosine (the sign says the tack), heel, pitch, yaw rate, the planing ratio, which side the sail is on, fallen or not, sheet and rake, seconds since the last manoeuvre, whether a manoeuvre is under way.
- The course: for the next step and the one after it: the distance (clipped at 1 km), the bearing relative to its heading (sine and cosine), the bearing relative to the wind (sine and cosine; this tells it the leg is a beat or a run), the required side; for a gate, both marks; the start: seconds to the gun, the distance to the line, which side of it it is on.
- The wind: its strength, its direction relative to the course axis (so a shift is visible), and the wind at four points 150 m away (ahead, behind, left, right), relative to the wind here: the gusts.
- The others: the two nearest boards, their position and velocity in its own frame, clipped at 100 m.

**What it is rewarded for** (per decision):
- plus the metres gained toward the next step since the last decision, divided by 100 (the dense signal that teaches sailing toward a point, and through it tacking);
- plus 50 at each step completed, plus 200 at the finish;
- minus 0.01 per decision (so faster is better);
- minus 20 for a fall, minus 20 for running aground, minus 5 for touching a mark or a board, minus 10 for OCS;
- the episode ends at the finish, at the time limit, or when the board is more than 1.5 km from the course.

The weights of these are the personality knobs (below). The sum of the progress reward over a clean race equals the course length, which is one of the tests.

**How it learns (PPO, in a paragraph).** The network starts random and sails badly. Each race it plays, the trainer looks at every decision and what came after it: decisions that were followed by more reward than expected are made a little more likely, the others a little less. "A little" is the point of PPO (the "proximal" in its name): it changes the network only slightly per round, so it never throws away what it already learnt. Rounds repeat for millions of decisions. Stable-Baselines3 does all of this; our part is the environment (the race) and the reward.

**The curriculum** (each stage starts from the previous brain):
1. T1, alone, one lap, 15 kt steady wind, flat water: learn to reach the mark, tack, round, run, gybe, finish. Done when it finishes 95 of 100 races and its time is within 10 % of the all-rounder's.
2. T1 with the default gusts and sea, at 12, 15, 18 and 24 kt, two laps.
3. T2, alone: gybes at speed, gusts, the shore.
4. T1 and T2 with one to three scripted opponents: the start, keeping clear.
5. Self-play: four copies of the brain race each other (all four learn, sharing one network), on both courses.
6. Export the brain and its checkpoints to the game.

**Personalities for learned skippers:**
- the reward weights: a fall penalty of 5 instead of 20 breeds a bold skipper, 60 a careful one; a bonus for wind strength at its own position breeds a gust hunter; an extra reward for height upwind breeds a pointer;
- the seed: two trainings with the same rewards and different seeds settle on different styles;
- the age: the checkpoints saved every half-million decisions are skippers of rising skill, so "rookie", "club sailor" and "pro" are one training run at three ages;
- a pinch of randomness at play time (a little noise on the turn output) makes a skipper less robotic, and it is a setting, not a hidden change.

**Watching it learn** is the fun part, so it is built in: the trainer saves a checkpoint every half-million decisions and a CSV of the reward and the finish rate per round; `tools/race_plot.sh` draws the curve; `tools/play.sh race --brain=<checkpoint>` lets Max watch any checkpoint sail; and a "brains race" mode puts four checkpoints of different ages on one start line.

### If PPO disappoints

> Session 51: this fallback was built and run first, in the night of 19 to 20 October 2026, because nothing could be installed on Max's PC at night. Two lessons for the PPO track: GDScript threads slow each other down in Godot 4.7.2 (the trainer runs one Godot process per core instead), and the network does better choosing the true wind angle to hold (the controller's heading hold does the rest) than twitching the stick ten times a second. Both carry over to the bridge.

Stop rule 3 (below) fires when stage 1 shows no learning after about two million decisions with two reward settings tried. Then the fallback is neuroevolution inside Godot: 64 copies of the network with random weights sail T1 at once in one headless process (they are independent `RefCounted` objects, so `WorkerThreadPool` can step them in parallel), the best 8 are kept and copied with small random changes, and this repeats for a few hundred generations. It is slower to learn but has no bridge, no Python, and almost no settings, and it gives a population of different skippers for free. The environment, the observation, the reward and the brain file are the same, so nothing from 9C is wasted.

## The numbers: how much compute a learned skipper costs

Measured on 19 October 2026 on Max's laptop (an i7-12700H, 14 cores, 20 threads, 16 GB), with `tools/simulate.sh beam_reach <seconds>`:

| What | Measured |
|---|---|
| Godot headless start-up | 4.6 s |
| One board at 60 Hz with 4 substeps | 0.098 s of wall time per second of sailing: 10 times faster than real time, about 610 ticks per second per process |
| Estimated with 12 processes at once | about 7,000 ticks per second (to be measured in 9C.1; the cores share the work, so 12 processes or 12 threads in one process should come to the same) |
| One lap of T1 alone (about 3 min of sailing) | 10,800 ticks, 18 s of wall time in one process |
| Decisions at 10 Hz | 6 ticks each: about 1,200 learner decisions per second with 12 processes, alone; a quarter of that with three opponents |

What that means: a task like stage 1 usually learns in 2 to 10 million decisions, which is half an hour to four hours here. Stages with three opponents cost four times the ticks per decision and run overnight. The team's RTX 3080 Ti desktop will likely be faster if it has more cores; a GPU does not help (the network is tiny; the physics is the cost). Every doubling of the simulation's speed halves every training time, so a profile of the hot spots in `Game/sim/` is worth a look, as Michiel's call.

These are estimates. 9C ends with the measured ones, and stop rule 3 protects against an open-ended training that does not learn.

## What racing asks of the physics (for Michiel)

Small, and none of it changes how a board sails:

1. **One wind for all boards.** `WindsurferSim.step()` steps its own `WindField` every substep. Four boards would step four copies, which is four times the work and, on the lake, four clocks. Asked for: a flag so the scene (or the race) steps one shared field once per tick and the sims only read it. Default off, so nothing changes for the tests.
2. **A contact force.** Collisions (board to board, board to mark) are computed in the race layer from the boards' positions and sizes, and applied as a short push through a new public `WindsurferSim.add_external_force(point, force)` for the next step only. The same hook serves running aground later (map request R4).
3. **Nothing else.** The sailor, the rig, the hull and the fin are untouched. The skippers act through `PlayerController` and `Autopilot` (RD1); if the course layer needs something from them, it is a question for the lead, not a change to the physics.

## Part 9A: A race you can sail alone

**Goal:** pick T1 or T2, start on the countdown, sail the course, see your time and splits.

**Tasks:**
- [ ] `Game/race/`: `RaceSim` (the race state machine: pre-start, countdown, racing, finished; the boards' progress through the course's steps; the clock and the splits; OCS), `RoundingCheck` (the geometry above), `RaceResult`. Plain classes, no nodes, so a race can run headless. Tests: every rounding case (port and starboard, 180° and 25° turns, the wrong side, a gate from either end, a line crossed backwards, the start before and after the gun, OCS and clearing it), the clock and the splits, the finish order, two boards finishing in the same tick.
- [ ] The course on the water (`CourseOnWater`, a node): buoys (an orange inflatable shape, floating on the wave height, with a small flag), the committee and finish boats (simple hulls with the Phase 7 flag), optionally a faint line on the water between a line's ends (a setting, off by default; the mini-map always shows the lines). Built from a `Course` in both the open-water and the lake scene.
- [ ] Built-in courses: `t1_loop` placed by code from the LG2 template at 30 % and set to the scene's wind; `t2_slalom` loaded from the course maker's save (Max places it; until then the code places a PD3 at the lake's start as a stand-in). Any saved course by name. The course file gets its optional "game metres" frame for the open water (RD5).
- [ ] `CourseFitter` (`Game/maps/course/course_fitter.gd`): a shore-clearance field from the lake's 2 m grid, the fit search (size, axis, position) with marks 200 m and legs 50 m off the shore, a "Fit to water" button in the course maker, and `tools/fit_courses.sh`, which writes `t2_slalom.json`. Tests: every fitted mark is 200 m from land when checked independently on a ring of samples; an impossible fit says why.
- [ ] The race in the scene: `main.gd` and `sail_silvaplana.gd` get a race mode (`--race=<course> --laps=2 --prestart=60`): the board is placed behind the line, the autopilot sails the pre-start until a key is touched, the countdown runs, the HUD shows the race, the results page opens at the end.
- [ ] The start menu gets **Race**: course (the built-in two and the saved ones), wind (the open water's settings, or the lake's time of day), laps, pre-start time, opponents (none yet: the list is there, empty, for 9B). The pause menu gets "Restart race" and "Leave race". The settings are saved like the others.
- [ ] The HUD as described above; the mini-map's course-centred mode for the open water; the countdown sounds and the gun in `Game/audio/`.
- [ ] `tools/race.sh <course> [--laps=1] [--wind_kt=15] [--skippers=autopilot]`: a headless race, one line per board at the end (finish time, the splits, falls, tacks, gybes), CSV of every board's track in `.sim_output/race/`. In 9A the only skipper is the plain autopilot sailing a fixed wind angle, so it will not finish; the script is here for its plumbing, and 9B makes it meaningful.
- [ ] Screenshots: the pre-start with the countdown, a rounding of mark 1, the gate from above, the finish, the results page; on both courses.

**Done when:** tests and the check are green; Max sails T1 and T2 against the clock and the splits make sense to him.
**Stop:** the team's checklist: Is the countdown long enough to get going? Is the next mark always clear on the HUD? Does a rounding ever fail to count, or count when it should not? Is OCS fair? Are the marks visible from far enough away?

## Part 9B: Scripted skippers

**Goal:** three opponents on the line with you, each with a character, on both courses; the Phase 9 "done when".

**Tasks:**
- [ ] `Skipper` (`Game/race/skipper.gd`): the course layer above `PlayerController` and `Autopilot`, rules 1 to 8 above, driven by a `SkipperConfig`. It reads the polar for its angles (`POLAR_15KT.md`'s table as a resource, with the game's own polar run regenerating it). Tests: alone on T1 at 12, 18 and 24 kt it finishes without a fall and lays mark 1 in at most `max_tacks_per_beat` tacks; on T2 it rounds every slalom mark within 20 m and finishes; a rookie finishes later than the all-rounder; the start: the all-rounder crosses within 3 s after the gun, the gambler is OCS in some races and clears it; determinism: the same seed, the same race.
- [ ] Opponents in the scene: N `WindsurferNode`s with their own sail colour and name label, one `GameAudio` (the player's only), their effects (spray, wake) as the player's. The pre-start places everyone.
- [ ] Collisions: board to board and board to mark as soft pushes through the contact force (section "What racing asks of the physics"); a short speed loss; the HUD says "contact". A test: two boards sent at each other end up apart and slower, and nobody is launched.
- [ ] Performance: measure the physics time per tick with four boards in both scenes on the laptop and the desktop. If it is over 8 ms, step the opponents' simulations on `WorkerThreadPool` (they are independent objects; the shared wind field is read-only during a step) and measure again. Report the numbers; a setting caps the opponents on a slow PC.
- [ ] The race menu's opponents list: the four shipped characters with one-line descriptions, each on or off.
- [ ] `tools/race.sh` with `--skippers=<name,name,...>`; `tools/race_matrix.sh`: the four characters on T1 and T2 at 12, 18 and 24 kt, one line per board (used as 9D's yardstick).
- [ ] Screenshots: four boards at the gun; the fleet at mark 1; the mini-map with the dots.

**Done when:** the tests above are green, the race matrix runs with no fall by the all-rounder, the frame time is reported, and Max has raced three opponents on both courses.
**Stop (Phase 9's):** the checklist: Are the opponents believable (a human line, not a rail)? Can a beginner beat the rookie and lose to the all-rounder? Do they get in your way at the start the way real sailors do, or too much? Did anyone sail through a mark or through you? And the names and colours.

## Part 9C: The learning harness, and the first learned skipper on T1

**Goal:** a race is a training environment; Python trains a network in it; the game runs the network. Proven on T1 alone.

**Tasks:**
- [ ] `RaceEnv` (`Game/race/race_env.gd`): wraps a `RaceSim` with N boards for learning: `reset(seed)`, `observe(board)` (the observation above as a `PackedFloat32Array`), `act(board, action)` (the three numbers into the controller), `tick()`, `reward(board)`, `done(board)`. The same observation code is used in the game (RD4). Tests: every observation stays within −3 and 3 over a race; the progress reward over a clean lap sums to the lap's length within 1 %; the same seed and actions give the same rewards twice; a fall, OCS and a mark touch each cost what the table says.
- [ ] The bridge, Godot side: `Game/dev/race_server.gd`, run headless with `-s`, `--port=<n> --boards=<n> --course=<name> --opponents=<names> --wind_kt=<kt> --laps=<n>`. It listens on localhost, and per JSON line handles `reset`, `step` (one action per learning board, returns the observations, rewards, done flags and a few info numbers) and `close`. A race is one episode for all its boards; a board that finishes is parked, reports done once, and then zero reward until the race ends.
- [ ] The bridge, Python side: `tools/race/env.py` (a Stable-Baselines3 `VecEnv` over K Godot processes times B boards), `train.py` (PPO with a config file per stage: the course, the wind, the opponents, the reward weights, the seed, the number of decisions; checkpoints every half-million; a CSV log), `export_brain.py` (the brain file with 20 sample inputs and outputs for the parity test), `evaluate.py` (100 races, the finish rate and the mean time), `plot.py`; `requirements.txt` (numpy, torch CPU build, stable-baselines3, gymnasium); `tools/race_train.sh <stage.yaml>`, `tools/race_plot.sh`. Installed with `pip install -r tools/race/requirements.txt` (torch's CPU build is about 200 MB; Python 3.12.9 and numpy are on Max's laptop already, torch is not).
- [ ] `NeuralNet` (`Game/race/neural_net.gd`): loads a brain file, `forward()`. `LearnedSkipper`: builds the observation, runs the network at 10 Hz, holds the action between. The parity unit test against the file's samples (RD4). The learned skipper is a choice in the race menu and in `tools/race.sh --skippers=brain:<name>`.
- [ ] 9C.1, measure: the ticks per second with 1, 4, 8 and 12 processes, and with `WorkerThreadPool` inside one process; the bridge's overhead per step (should be under 10 % at 10 Hz decisions). Write the numbers into this plan's table.
- [ ] Stage 1 of the curriculum run by the lead on Max's laptop: T1 alone, flat water, 15 kt steady. The learning curve and the finish rate reported. Compare the time with the all-rounder's from `tools/race_matrix.sh`.
- [ ] A short "How to train a skipper" section in this file: the three commands, where the files go, what the curve should look like.

**Done when:** tests and the check are green; a brain trained on T1 finishes 95 of 100 races headless; the same brain sails T1 in the game (screenshot of it rounding mark 1); the numbers are in the table.
**Stop:** show Max the learning curve and let him watch the rookie and the veteran checkpoints sail. Decide with the team: go on to 9D, or stop here and keep the scripted skippers as the opponents. Stop rule 3 may fire earlier.

## Part 9D: Learned skippers in the game

**Goal:** the curriculum through T2 and the opponents; a cast of learned skippers with characters; the evaluation table.

**Tasks:**
- [ ] Stages 2 to 5 of the curriculum, each a config file, each run overnight where needed; the curves kept in `Documentation/racing_reports/`.
- [ ] Personalities: at least three brains with different reward weights or seeds (a bold one, a careful one, a gust hunter), plus three ages of one of them (rookie, club, pro). Their `SkipperConfig` names them, colours them, and points at the brain file.
- [ ] The evaluation table in this file: every skipper (scripted and learned) on T1 and T2 at 12, 18 and 24 kt, alone and in a fleet of four: finish rate, mean time, falls, tacks. The learned skippers' times against the all-rounder's. Max's own times beside them if he likes.
- [ ] The "brains race" mode (four checkpoints on one line) and `tools/play.sh race --brain=<file>` for watching a checkpoint.
- [ ] The retraining command (`tools/race_train.sh all`) documented, and the brain files carrying the physics commit they were trained on; a check that warns when the game's physics commit is newer than the brains'.
- [ ] Anything the learned skippers found: a way to sail that is faster than the polar, a manoeuvre the controller allows but a sailor could not do, a place on the lake where the wind model misbehaves. Each is a finding for Michiel (a learned skipper is an untiring tester of the physics), written up in `Documentation/racing_reports/findings.md`, and never trained into the brain on purpose.

**Done when:** the table is filled, the learned skippers are in the menu, and Max has raced a fleet of them on both courses.
**Stop:** the team's checklist: Do the learned skippers feel different from the scripted ones, and from each other? Which is the most fun to race against? What did they find in the physics?

## Part 9E: Later

Racing rules and penalties (port and starboard, windward and leeward, a 360° turn for a mark touch, the X flag); replays and a ghost of your best lap; a leaderboard per course in `user://`; a whole regatta (several races, points); fleets bigger than four once the frame time allows; the learned skippers racing each other online when multiplayer comes.

## Where things live

```
Game/race/                 the race: RaceSim, RoundingCheck, RaceResult, CourseOnWater, Skipper,
                           SkipperConfig, RaceEnv, NeuralNet, LearnedSkipper
Game/race/skippers/        the characters (*.tres)
Game/race/brains/          the trained networks (*.json, built artefacts, RD4)
Game/race/courses/         t1_loop (placed by code); the lake's courses stay in maps/silvaplana/courses/
Game/dev/race_server.gd    the bridge's Godot side (headless)
Game/tests/unit/test_race_*.gd, test_skipper.gd, test_race_env.gd, test_neural_net.gd
tools/race.sh, race_matrix.sh, race_train.sh, race_plot.sh
tools/race/                env.py, train.py, export_brain.py, evaluate.py, plot.py, stages/*.yaml, requirements.txt
Documentation/racing_reports/   the agents' reports, the learning curves, the findings for Michiel
```

## Execution brief

For the lead who builds Phase 9. The live state goes in [P9_PROGRESS.md](P9_PROGRESS.md) (made at the first launch, in the shape of U2_PROGRESS.md: the state, the next action, the take-over prompt).

### Go-ahead, branch and team

- **Go-ahead:** Max asked for the plan on 19 October 2026. Building needs the team's go, part by part at each Stop.
- **The branch** for 9A and 9B is `feature/p9-racing` from `main`. 9C and 9D are built on it after U1 and U2 are merged into `main` and `main` is merged into it (RD8). Nothing goes to `main` without a pull request and the team.
- **The lead is Claude Fable 5.1.** It launches the agents, reads their diffs (the race geometry, the skipper's rules, the reward: these are the places where a quiet mistake costs weeks), merges, keeps P9_PROGRESS.md current, runs the training stages, and handles the Stops. Max's Fable usage is limited: the lead reads narrowly and writes briefly.
- **The agents are Claude Opus 5.5 at extra-high effort** (`model: "opus"`, `effort: "xhigh"`), each in its own worktree (`isolation: "worktree"`) on a branch `p9/<name>` from the part's base, at most 3 at a time. The lead merges them back.

### The packages

| Part | Agent | Builds | Files it may touch |
|---|---|---|---|
| 9A | `race_core` | RaceSim, RoundingCheck, RaceResult, the tests, tools/race.sh | `Game/race/` (new), `Game/dev/run_race.gd`, `tools/race.sh`, its tests |
| 9A | `course_on_water` | buoys, boats, lines, the course in both scenes, t1 by code, the course file's game frame, the mini-map's course mode | `Game/race/course_on_water.gd`, `Game/maps/course/course.gd` (the frame only), `Game/ui/mini_map.gd`, the scenes' race hook |
| 9A | `fit_to_water` | CourseFitter, the clearance field, the Fit to water button, tools/fit_courses.sh, t2_slalom.json | `Game/maps/course/course_fitter.gd`, the editor and panel (the button), `Game/dev/fit_courses.gd`, `tools/fit_courses.sh`, `Game/maps/silvaplana/courses/`, its tests |
| 9A | `race_ui` | the Race menu page, the HUD's race items, the results page, the countdown sounds, the pause menu's items | `Game/ui/`, `Game/audio/`, `Game/main.gd` and `sail_silvaplana.gd` (race mode) |
| 9B | `skipper` | Skipper, SkipperConfig, the polar resource, the four characters, the tests at 12/18/24 kt | `Game/race/skipper*.gd`, `Game/race/skippers/`, its tests |
| 9B | `fleet` | opponents in the scene, colours and labels, collisions (with Michiel's contact force), the performance measurement and the threads if needed, race_matrix.sh | `Game/race/`, `Game/windsurfer/` (colour and label only), `tools/race_matrix.sh` |
| 9B | `start_and_tactics` | the timed start, shifts, gust hunting, keep clear; after `skipper` is merged | `Game/race/skipper*.gd`, its tests |
| 9C | `race_env` | RaceEnv, the observation and the reward, their tests | `Game/race/race_env.gd`, its tests |
| 9C | `bridge` | race_server.gd, the Python side, NeuralNet and the parity test, LearnedSkipper, the tools | `Game/dev/race_server.gd`, `Game/race/neural_net.gd`, `learned_skipper.gd`, `tools/race/`, `tools/race_*.sh` |
| 9D | `brains_in_game` | the learned characters, the brains race, the watch command, the physics-commit check | `Game/race/skippers/`, `Game/race/brains/`, `Game/ui/` (the list) |
| 9D | `evaluation` | the table, the findings file | `Documentation/` |

An agent that needs a file outside its list stops and says so. Any change to `Game/sim/` goes through the lead to Michiel.

### Tokens

- **Read narrowly.** Read this plan, CLAUDE.md, and the files of your package. PHYSICS_SPEC.md is over 6000 lines: never read it whole.
- **Measure with the one-line tools** (`tools/race.sh`, `tools/race_matrix.sh`), not by reading CSV files. Pipe long outputs through `tail`.
- **Pace the checks.** `tools/test.sh` after each change; `tools/check.sh` after scene or resource changes; a screenshot before saying a visual works; the validation suite is not needed unless `Game/sim/` changed.
- **Report briefly.** At most 300 words plus one table, committed as `Documentation/racing_reports/<name>.md`, and returned to the lead as the same text.

### Stop rules (tell Max in plain language, with the options)

1. **The frame time** with four boards is over 16 ms on the team's desktop after the threads: ask (fewer opponents, a cheaper simulation for the opponents, or Michiel profiles the simulation).
2. **The all-rounder cannot finish T1 at 24 kt without falling** after the skipper's own margins are tried: it is the physics or the controller, not the skipper. Michiel's call.
3. **No learning** in stage 1 after about two million decisions with two reward settings tried: ask (more compute, the neuroevolution fallback, or stop at the scripted skippers).
4. **A learned skipper found a hole** (faster than the polar, a manoeuvre no sailor could do): report it as a finding, do not train on it, carry on.
5. **Any change to `Game/sim/`** is needed: ask Michiel through Max, with the exact lines.
6. **Rounding disputes:** if Max's play-test finds a rounding counted wrongly, the geometry is wrong, not the margins: fix it with a test for that case before anything else.

### The team's parts

- **Max:** places `t2_slalom` on the lake with the course maker and saves it; names and colours the characters; play-tests every Stop; runs the overnight trainings (one command) and watches the curves, because that is the part he is curious about.
- **Michiel:** the two physics hooks (one shared wind step, the contact force); the findings the learned skippers turn up; the profile of the simulation if training is too slow.
- **The lead:** everything else, through the agents.

### To start 9A

Make the branch and the progress file, then launch `race_core` and `course_on_water` together (`race_ui` once `race_core`'s RaceSim exists, so the HUD has something to show). The first thing to verify by screenshot is a buoy floating at the right height on the lake's waves.

## Risks and open questions

- **The simulation's speed** bounds the training (about 7,000 ticks per second on the laptop). It is enough for the plan's stages, but a slow stage runs overnight. A profile of `Game/sim/` could change this a lot; Michiel's call.
- **PPO can be fickle:** a reward one notch wrong teaches the wrong thing (a skipper that circles a mark forever to collect progress, or never tacks because tacks cost speed). The tests on the reward (the sum over a lap, the penalties) and stop rule 3 limit the damage; the scripted skippers remain whatever happens.
- **Coupled episodes:** a race is one episode for all its boards, while Stable-Baselines3 expects independent ones; the parked-board convention above is a small cheat that adds a few empty samples per race. If it bothers the learning, a short training loop of our own (CleanRL's PPO is about 300 lines) with proper masks replaces it.
- **Four boards on screen** may cost more frame time than this laptop has; the threads and the opponent cap are the answers, measured in 9B.
- **The windward mark's rounding ray** is 80 m long; a board that overstands by more than that and bears away late crosses the ray further out and is not counted until it comes back within 80 m. Watch for it in the play-test (stop rule 6).
- **Open:** the lake's shore for the skippers (a safety distance from the 2 m grid: 40 m?); whether the gate should be chosen by which mark is nearer or by which is favoured by the wind (both are coded, the character picks); the countdown length the team likes; the name of the fourth character.

## Sources

- The iQFOiL course shapes and distances: the Notice of Race of the 2026 U23 Worlds, Addendum A ([Document_146274_20260925081258_en.pdf](Document_146274_20260925081258_en.pdf)) and the Class Race Management Guideline (2023), as already used by W4a in [MAP_SILVAPLANA_PLAN.md](MAP_SILVAPLANA_PLAN.md).
- PPO: Schulman et al., "Proximal Policy Optimization Algorithms" (2017), https://arxiv.org/abs/1707.06347; the implementation is Stable-Baselines3, https://stable-baselines3.readthedocs.io/.
- Godot and Python for reinforcement learning, the design the bridge borrows: Godot RL Agents, Beeching et al. (2021), https://arxiv.org/abs/2112.03636 and https://github.com/edbeeching/godot_rl_agents.
- Reinforcement learning for sailing upwind in a changing wind: Suda and Nikovski, "Deep Reinforcement Learning for Optimal Sailing Upwind", IJCNN 2022, https://merl.com/publications/TR2022-102.
- Reinforcement learning on a sailing simulator with sail and rudder control through waypoints: "Reinforcement-learning robotic sailboats: simulator and preliminary results" (2024), https://arxiv.org/abs/2402.03337.
- Neuroevolution for racing opponents of rising skill: Togelius and Lucas, "Evolving controllers for simulated car racing" (2005), and Aguilera et al., "Driving-bots with a neuroevolved brain: Screaming Racers" (2005), https://rua.ua.es/dspace/handle/10045/692.
- The game's own polar at 15 kt, which the skippers read their angles from: [POLAR_15KT.md](POLAR_15KT.md).
