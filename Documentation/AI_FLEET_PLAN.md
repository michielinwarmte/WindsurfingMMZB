# The AI fleet: smarter skippers, personas, and 20 to 40 boards in one race

Written 20 October 2026 (Session 51) by Claude Fable 5.1 for Max and Michiel, and for the AI session that builds it. It continues Phase 9 of [RACING_PLAN.md](RACING_PLAN.md) after Max's first races against the three scripted skippers (the state is in [P9_PROGRESS.md](P9_PROGRESS.md)).

Max, 20 October 2026: "I want the AI to be more smart: AIs with character that spawn on a random location before the competition and manage the start as best as possible, and the race. The same AI must perform well in a slalom and a course race. When there is no race it just free-sails, and when a countdown starts it goes to the start line and starts as close to 0 as possible. Mistakes are okay, a player makes them too, but it needs to be trained so it performs well. More personalities, so a persona can be good at slalom but worse in course racing. I want to run 20 to 40 AIs in one race; it needs to be optimised. Think with me so we can make this feel more like real life."

## The two facts the design rests on

1. **A board's physics costs 3.2 ms per tick in the game** (Session 51, `--measure`), and GDScript threads stop helping beyond about four (the learn agent: 4 threads 1.7 times the speed of 1, 8 threads slower than 1; the race runner: four boards side by side in 5.0 ms). So the full physics can run for 4 to 6 boards at 60 Hz, not for 40. Whatever we do with the AI, a 40-board fleet needs most boards on a cheaper model.
2. **The full physics is too slow to train tactics on.** The night run (RACING_PLAN.md, "If PPO disappoints"; P9_PROGRESS.md) managed 100 generations of 32 boards in 5 hours and learnt the start and the beat to mark 1, nothing of the fleet. Tactics (starts in a crowd, laylines, shifts, traffic) need thousands of races, with many boards in each, and a fast model gives them.

Both point the same way: **two levels of board, and two levels of skipper.**

## The design

### D1. A skipper is a head and a pair of hands

- **The hands** keep the board fast and upright through the real physics: the trim, clean tacks and gybes, surviving a gust, and, new, holding back before the start without stalling. Today these are `PlayerController` (beginner mode, auto-sheet) and `Autopilot`, driven through `AiHands`. They take a wanted wind angle and "tack now"; they never see the course.
- **The head** decides where to go: the start plan (which end of the line, the approach, when to turn in), the laylines, the shifts and gusts, the traffic, the gybe-mark entries in slalom, and before the race, where to sail for fun. It thinks at 1 or 2 Hz on a coarse picture (the course's next steps, the wind here and around, the nearest boards) and only ever gives the hands a wind angle and a manoeuvre request. Today the scripted `Skipper` is a head written as rules; the night's brain was a head learnt by evolution.
- One head serves slalom and course racing because it sees only the next steps of whatever course it is on (RaceSim's steps: lines, marks with a side, gates). It is trained on T1, T2 and courses generated at random (windward-leeward, trapezoid, slalom, at random sizes and wind directions), so it learns racing, not a course.

### D2. Two kinds of board: full physics near you, a polar board elsewhere

- The boards within about 150 m of the player (and the player) run `WindsurferSim`, on worker threads as now: at most 4 to 6 of them.
- Every other board runs a **polar board**: a small model calibrated from the real simulation, with the same interface for a skipper (position, speed, heading, wind angle, a wanted wind angle and a manoeuvre request). It has: speed by wind angle and wind strength (the sim's polar at 10, 12, 15, 18, 21, 24 kt, run by `tools/matrix.sh` and the skipper agent's measured polar), acceleration and deceleration time constants, the turn rate, the time and distance lost in a tack and a gybe, and a chance of a fall per manoeuvre and per minute of planing, by wind and by the persona's skill. It costs microseconds per tick, so 40 of them are free, and a 40-board race simulates in seconds headless.
- **The hand-over:** when a polar board comes within the radius it becomes a full simulation started at its speed and heading, and the other way round when it leaves. The physics needs one hook for that, `WindsurferSim.reset_moving(position, heading, speed)` (today `reset()` starts at rest): Michiel's. The player never sees a hand-over at less than 150 m; the rest is dots on the water.
- **The polar board is also the training ground.** With it, a race of 40 boards runs at hundreds of times real time, so the head can be trained by reinforcement learning in self-play with thousands of races, which the full physics cannot give (fact 2).
- The cost: a polar board does not fall over a wave or catch a gust the way the real board does, so a far board is a little more regular than a near one. The persona's fall chance covers the big part; the calibration covers the speeds; a check races the two models over the same course and compares the times.

### D3. One strong brain, many personas

Train one good head and keep one good set of hands, then make a persona from a **skill sheet** that degrades or biases them. The sheet (numbers from 0 to 1, with their effect):

| Skill | What it changes |
|---|---|
| start timing | the error on the start plan's clock (0: +/- 8 s, 1: +/- 0.5 s) |
| start nerve | how close to the line and how near the favoured end it dares to be |
| tacking, gybing | the time lost per manoeuvre and the chance of a fall in it (slalom specialists gybe; course specialists tack) |
| boat speed | a share of the polar's speed it reaches (0.9 to 1.0) and, on the full physics, the hands' noise and reaction time |
| upwind sense | how well it sees wind shifts (a lag and a noise on the wind it reads) and whether it uses laylines early |
| downwind sense | the same for gusts and the gybe angles |
| gust appetite | how far it goes looking for more wind (the lake's gusts) |
| risk | the margins at marks and laylines, OCS risk |
| aggression | how close it sails to others, whether it takes a leeward position in a pack |
| consistency | the fall chance when planing, and the day-to-day wander of all of the above |
| gear | the sail and fin size it chooses for the wind (a bigger sail is faster in light wind and overpowered in strong; a smaller fin gybes better) |

A persona is a sheet plus a name, a colour, a home water and a short profile the menu shows ("Lena: slalom specialist, fearless starts, loses the beat"). The skill sheet feeds the head as noise, lags, margins and preferences, and the hands as noise and reaction time. One training run gives dozens of personas, and a persona's strengths show in the results: slalom specialists at the top on T2, course specialists on T1.

Style biases on top, no training needed: prefers the left side of the beat, starts at the pin, sails low and fast, points high, gybes wide.

### D4. Behaviour states, so the fleet lives on the water

Every skipper runs a small state machine:
- **Free sailing:** no race on. It picks a point of sail and a leg, sails it for a while, tacks or gybes, stays inside the sailing area, keeps off the shore and the others. Where it spawns is random inside the area.
- **Pre-start:** a countdown has begun. It works out the time to the start area and goes there (a navigation skill: the fewest manoeuvres to a point), reads the line bias (which end is nearer the wind), picks its end by its sheet, and runs its start plan: a timing loop (sail away on a reach, turn back so that it reaches the line at the gun at full speed), or a hold near the line (the new "hold back" skill of the hands: luff and sheet out without stopping), with its timing error. If it is over early it goes back round the end.
- **Racing:** the head's race tactics, as today's skipper does and the trained head will do better.
- **Finished:** sails clear of the finish, then free sailing.

### D5. What makes it feel real (in the order of effect)

1. **Wind shadows.** A sail leaves a cone of slower and disturbed wind behind it (about 5 mast heights long, 30 % less wind near the sail, fading). A `FleetWindField` wraps the scene's wind field and subtracts the shadows of the boards upwind of a point: no change inside `Game/sim/`, which only asks the field for the wind at a point. The boards in a pack then slow each other, the favoured end gets crowded, and a clean lane matters, as in real life.
2. **The start crowd:** line bias, the loop, over-early boards going back, the boat end packed. From D3 and D4.
3. **The rules:** port and starboard, windward and leeward, mark room, with a penalty turn (RACING_PLAN.md, 9E). The AI keeps clear by the rules; the player gets a warning and a penalty.
4. **Crashes at the gybe mark** in slalom: the polar board's fall chance in a gybe rises with the wind and the crowding; the full-physics boards simply fall.
5. **Gear:** personas on different sails and fins, visibly (a 7.8 and a 5.8 look different).
6. **Sound and sight of a fleet:** the sails all round, the splashes, the names.

### D6. The training, in two halves

- **The head** by PPO in Python over the bridge of RACING_PLAN.md (9C), on polar boards, 10 to 40 per race, in self-play (every board the same network, each with a random skill sheet, so it learns to race with and against every kind of skipper), on random courses of both kinds in random winds with the map's shifts and gusts. Observation: its own state and sheet, the next two steps' geometry, the line's bias and the time to the gun, the wind at points around, the nearest 6 boards. Actions: the wanted wind angle, tack or gybe now, hold back. Reward: the finishing place and time, minus OCS, collisions and rule breaches. A 40-board race on polar boards takes seconds, so this is minutes to hours, not nights.
- **The hands** stay the scripted controller and autopilot, improved where the skipper agent found them short (the tack stops the board for 6.5 s; no way to slow down without stalling; the gybe entry), and optionally refined by the evolution trainer on the full physics with a speed reward, per wind. The night's harness, the observation and the brain file carry over.
- **The hand-over test:** the trained head races on full-physics boards in `tools/race.sh` against the scripted skipper; it must finish both courses and beat the all-rounder more often than not before it goes in the game.

### D7. The big fleet in the game

20 to 40 boards at 60 fps on Max's laptop: the near ones on full physics and threads, the rest polar boards (D2); the visuals in levels too: beyond 300 m a board is a simple rig without the cloth shader and the figure posed every tenth tick, name labels only near, the mini-map shows every dot. Measured with `--measure` at 10, 20 and 40 boards; the target is a frame under 12 ms at worst.

## What this needs

| Need | Who | Size |
|---|---|---|
| `WindsurferSim.reset_moving()` for the hand-over, and a look at the tack that stops the board | Michiel | small |
| The polar board calibrated from the sim (speeds, accelerations, manoeuvre losses, fall chances by wind) and a check racing the two models | an agent | a day |
| The skipper's state machine (free sailing, pre-start, start plan, racing, finished), the navigation skill, the hold-back skill in the hands | an agent | two days |
| `FleetWindField` (wind shadows) and the keep-clear rules in the head | an agent | a day |
| The skill sheet, the persona files, 12 personas with profiles, the menu's fleet picker (size, who) | an agent | a day |
| The fleet in the game: the near/far hand-over, the visual levels, the measurements | an agent | a day |
| The Python bridge, PPO on polar boards in self-play, random courses, the evaluation | an agent, then overnight runs on Max's PC (torch, Stable-Baselines3 installed) | three days, then compute |
| The documentation and the play-tests at every Stop | the lead, Max, Michiel | |

Optional, later, and large: **the physics in C++ (a GDExtension)**, with the GDScript simulation as the reference and the 446 tests as the oracle. It would make the full physics 20 to 50 times faster (an estimate from GDScript against C++ in general, not a measurement), so 40 boards could all run it and the hands could be trained by PPO too. It costs a second codebase the team cannot read as easily. The polar board makes it unnecessary for the fleet; it stays on the list for a day the training of the hands matters more.

## The numbers to plan with (Session 51)

| | |
|---|---|
| A full-physics board, one tick in the game | 3.2 ms; 4.7 ms each when four step side by side on threads |
| Four boards side by side | 5.0 ms per tick; the game at 249 fps, 12 ms at worst |
| The GDScript thread ceiling | about 4 useful threads (8 threads slower than 1) |
| A polar board, one tick (estimate) | 20 to 50 microseconds; 40 of them under 2 ms |
| A 40-board race of 5 minutes on polar boards, headless (estimate) | 5 to 15 s per process; 20 processes on the laptop |
| The night's full-physics training | 32 boards, 2 races of 300 s per generation, 37 to 260 s per generation, 100 generations in 5 hours |

## Parts, in order

- **F1. The polar board and the fleet tool.** `PolarBoard` calibrated from the sim; the race tool races any mix of full and polar boards (`--skippers=... --fleet=40`); the check of the two models over T1 and T2 at 12, 18 and 24 kt. *Stop: the comparison table.*
- **F2. The living skipper.** The state machine, free sailing in an area, the navigation skill, the start plan with the timing loop and the hold-back skill, the end choice from the line bias; spawning anywhere; the countdown gathers the fleet. In the game with the scripted head first. *Stop: Max watches 12 boards gather and start.*
- **F3. Real life.** Wind shadows, the keep-clear rules, crashes at the gybe mark, gear per persona. *Stop: Max races in a crowd.*
- **F4. Personas.** The skill sheet, the profiles, 12 personas, the fleet picker in the menu, the results by course type showing the specialists. *Stop: the team names them.*
- **F5. The trained head.** The bridge, PPO in self-play on polar boards over random courses, the evaluation against the scripted head, the personas on the trained head. *Stop: the first fleet race against the trained head.*
- **F6. The big fleet in the game.** The near/far hand-over, the visual levels, 20 and 40 boards measured. *Stop: 40 boards at 60 fps on the laptop.*

## Decisions for Max and Michiel before F1

1. **The polar board for the far boards** (D2), rather than every board on the full physics (which would need the C++ port first). The AI's board is then the measured average of the real one; the near ones stay real.
2. **Personas as skill sheets on one trained brain** (D3), rather than a training per persona.
3. **Wind shadows** as a wrapper around the wind field (D5.1): Michiel's view on the shape and the numbers (a cone, 30 % less wind, 5 mast heights).
4. **The rules** to enforce first: port and starboard and mark room, with a penalty turn for the AI and a warning and a time penalty for the player.
5. **The training stack:** PPO in Python (torch and Stable-Baselines3 on Max's PC) for the head; the evolution trainer stays for the hands.

## To start in another chat

Paste: "Read Documentation/AI_FLEET_PLAN.md and Documentation/P9_PROGRESS.md. Max has decided on the plan's five decisions as follows: <his answers>. Lead Part F1 as RACING_PLAN.md's execution brief describes (the lead delegates to Opus 5.5 agents at extra-high effort in worktrees, at most three at a time, on branches `f1/<name>` from `feature/p9-racing`, and stops for Max at the part's Stop). Keep P9_PROGRESS.md current after every launch, report and merge."

## Sources and prior art

- The two-level skipper (boat handling under tactics) is how sailors and sailing coaches split the sport, and how racing games build drivers: one optimal controller, error and style models per driver (Togelius and Lucas, "Evolving controllers for simulated car racing", 2005, for evolved drivers of rising skill; the industry practice of "AI driver profiles" in modern racing games).
- Polar-based boat models for fleets: Virtual Regatta and the offshore race simulators run thousands of boats on polars; the calibration of a polar from a full model is standard velocity-prediction practice.
- Self-play PPO for multi-agent racing: OpenAI's and DeepMind's self-play results, and the "Gran Turismo Sophy" work (Wurman et al., Nature 2022) for training a racing agent against a fleet with rules.
- Wind shadow of a sail: about 5 to 7 mast heights of disturbed air downwind, strongest within 2, as sailing tactics books (Stuart Walker, "Advanced Racing Tactics") and wind-tunnel studies on sail interaction describe; the numbers above are the usual rules of thumb and want Michiel's eye.
- The game's own measurements: P9_PROGRESS.md, Session 51; RACING_PLAN.md, "The numbers".
