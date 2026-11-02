# The AI sailors fastest around two courses: the plan (1 November 2026)

**Michiel's brief (1 November 2026, evening):** "Please try to improve the AI sailors to be the fastest around a specific 2 courses of your choice. You can use more Opus agents if you need them; please try to use a maximum of 70 % of the 5 h within the 5 h. I need you to take the lead on this and make sure the autopilot and the characters are functioning optimally. It can take 24+ [hours]."

The lead is a Fable session; the work is done by Opus agents (effort xhigh) in their own worktrees on branches from `gear/lead`, at most two at a time, and merged into `gear/lead` after the lead has read every diff. The ledger and the log are in [PROGRESS.md](PROGRESS.md). The previous work's review, which this plan builds on, is [../fleet_gear/nights_review.md](../fleet_gear/nights_review.md): the trained brains sail but do not race; the scripted all-rounder is the fastest AI sailor the game has.

## The two courses

- **T1, the training loop** (`t1_loop`, open water): start, mark 1 upwind, the gate 4S/4P downwind, mark 1 again, 4S, the finish; one lap, six steps. A beat, a run, a beat, a run and gybes at the gate. The all-rounder alone at 18 kt: 7:58 with 5 tacks and 5 gybes.
- **T2, the sprint slalom** (`t2_slalom`, raced on the open water's sea as `tools/race.sh` does): start, marks 1, 2, 3, the finish; reaches and three gybes. The all-rounder at 18 kt: 3:09.7.

Both at **12, 18 and 24 kt**, with the game's open-water sea, the gust patches and the wind shifts the settings give by default. `tools/race_matrix.sh` races the four scripted characters on both courses at the three winds (six Godot processes, some 10 minutes) and writes `.sim_output/race_matrix.txt`; `tools/race.sh --course=t1_loop --skippers=allrounder --wind_kt=18 --seed=1` is one board alone against the clock, the same race for the same seed. "Fastest" is measured as the all-rounder's time alone on each course and wind, and as the fleet's times and finish rate in company.

## The yardstick before the work

The baseline race matrix of 1 November (before any change) is in [baseline/](baseline/): the four characters on T1 and T2 at 12, 18 and 24 kt, and the twelve personas at 18 kt. Known from before: the all-rounter's 12 kt race took 14:39 against the 12:00 the test wants ([autopilot_rework.md](../autopilot/autopilot_rework.md), section 6); the push dial pays +4 % at 18 kt and +7 % at 24 kt but the 24 kt broad reach falls when pushed; at 12 kt the push changes nothing (the physics, PH26). The 15 kt polar ([POLAR_15KT.md](../../POLAR_15KT.md)) has the best VMG at 45 degrees upwind and 135 downwind; nobody has measured the best angles at 12 and 24 kt with the push levels. With full gear configs the 8.0 beats the 6.5 in 12 kt and the 6.5 is 4 to 6 % faster from 18 kt (PH14, Session 64), but the AI boards all sail the default rig: the personas' own sail (`Persona.rig()`, `--gear=1`) is off because it only scaled the area.

## The packages

| # | Package | Who | Branch, worktree | Delivers |
|---|---|---|---|---|
| 1 | **The skipper's speed:** the scripted all-rounder (and with it the characters and personas) as fast as possible around T1 and T2 at 12, 18 and 24 kt: the best angles per wind from a fresh polar with the push levels, the push set by point of sail and wind through the AI hands, the laylines and tack count, the roundings and gybes, the start at full speed, the 12 kt pace, and the sail for the wind from the gear catalogue (GE5) | the speeder (Opus) | `race/skipper-speed`, `../WindsurfingMMZB-speed` | the code, tests, `skipper_speed.md` with the before/after matrix |
| 2 | **The trainer's tacks (RA14, RA15):** a minimum time between tacks (or a tack cost) for the learned skipper, a curriculum on the two courses whose drops the all-rounder can finish, bars at the all-rounder's own share, S1's bar at 100 %, an entropy bonus and per-board conditions tried in small, the brains' names in a race and on the Race page fixed; the night's command for the lead | the tacker (Opus) | `race/train-tacks`, `../WindsurfingMMZB-tacks` | the code, tests, `trainer_tacks.md`, the command |
| 3 | **The characters (RA6):** about twenty personas on the tuned skipper, from rookie to pro, each with its push level, its hands' noise and its gear; the Race page's lists; the persona matrix at 12, 18 and 24 kt on T1 and T2 | the caster (Opus), after package 1 is merged | `race/characters`, `../WindsurfingMMZB-characters` | the personas, tests, `characters.md` |
| 4 | **The night:** the trainer of package 2 run on the two courses on this PC for as long as it takes (Michiel: "it can take 24+"), then reviewed as the last one was | the lead | the train worktree | the brains, the review |
| 5 | **The start and the race in company (RA16, RA11, RA20),** added 2 November after package 3: the start plan built round the polar's beat angle, the 12 kt way in planned for the board's real speed, T2's reaching start at 24 kt without an OCS; the race's time limit fitted to the course and the wind, the falls in company found and fixed, the penalty circles; measured alone, with the four characters and with the twenty in a fleet | the starter (Opus), after package 3 is merged | `race/start`, `../WindsurfingMMZB-start` | the code, tests, `start.md` |

## The lead's decisions

1. The two courses are T1 and T2, the game's own training courses: they are in the Race page, the race tool, the race matrix and the persona matrix, and they cover a beat, a run, reaches and gybes.
2. "The autopilot functioning optimally" is read as: the beginner controller's autopilot with the AI hands, which every AI board sails, measured on the polar per wind and push level, and its numbers chosen by the skipper per point of sail; nothing in `Game/sim/` changes (Michiel's physics; a physics finding becomes a PH item in the report).
3. The budget: two agents at a time, about 0.9 M tokens each, package 3 after the first two are merged; the lead keeps the ledger in PROGRESS.md and stays under Michiel's 70 % of the five-hour window by not starting package 3 before the window allows.
4. The scripted skipper is the fastest sailor today and stays the game's AI until a brain beats it on both courses on the same seeds.

## The stops

- An agent that finds it needs a change in `Game/sim/` stops that lever and reports it as a PH item.
- An agent at its token cap stops, commits what works with its tests green, and reports where it stands.
- The lead stops for Michiel before merging anything to `main` (nothing goes to `main` without the team) and before a night that would occupy the PC on a day he needs it.
