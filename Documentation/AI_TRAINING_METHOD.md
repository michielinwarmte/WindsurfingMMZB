# The AI training method (from 8 November 2026)

**Live.** How the AI skippers are trained and judged from now on, step by step, so any session (another chat, another
PC, an agent) can carry on. Agreed with Max on the evening of 8 November 2026. The tools are on the branch
`ai/skipper-heads-8nov`; the backlog's stories are E09.S19 (this method), E09.S23 (the roundings), E09.S24 (the menu
race) on `docs/backlog-1.0`.

## Why

Max, 8 November 2026: "I still have the strong feeling you are training the AIs to be one-trick ponies. If there are
more sailors they break, if the course changes one tiny bit they break." He was right. Every test before tonight used
fixed setups: brand-new skippers (R was never pressed, and it broke every board), the launchers and the race tool only
(never the menu), 8 to 11 boards with the same 11 personas (9 of the 20 never raced), the personas' sheets as written
(the game uses half that spread), the 10 saved lake courses at three hours. The numbers were tuned on those setups and
judged on the same setups. So the skipper got good at exactly what was looked at.

The rules that follow from it:

1. **Test through the game's own doors**: R, the menu's setups, the launchers, the race director's race after a race.
2. **Draw every race at random** (the table below), never a fixed list.
3. **Judge by checks that must always hold** (below), not by who wins or by one race's time.
4. **Measure every mark rounding** (below): Max's main pain.
5. **Keep a set the AI never trains on** (the hold-out). A fix counts only if the hold-out gets better.
6. **Fix causes, not cases**: no special rule for one course or one persona.
7. **One general head first**, then the personas, then fleets (when Max says). From 9 November 2026 the starts come
   first of all (phase S, below): one board per race until every start is under 20 s.
8. **Only planing winds** (14 kt and up): below that the numbers say nothing (Max).
9. **No play folder until Max sends the message to make one**, and only after the suite passes.
10. **Keep the PC at about 55 to 75 % CPU** (8 jobs, one per physical core; below).
11. **Take the loop the efficient way** ("The loop, efficiently" below): a fresh chat per loop, one wake-up per run,
    summaries instead of logs, small batches when the effect is big.

What does not change: nothing in `Game/sim/` (the physics, Michiel's), the controller or the autopilot (Max approved
them on 7 November) without their OK; never delete data (move it, ask before a cleanup); English only; commit locally,
push only when Max asks.

## The tools

| What | Where | How |
|---|---|---|
| The random suite | `tools/heads/random_suite.py` | `python -I tools/heads/random_suite.py --run=<name> --count=300 --cores=8 --seed=1 --set=tune --phase=A --project=<frozen copy>/Game` |
| The viewer | `.sim_output/suite/viewer.html` (the run going now) and `.sim_output/suite/<run>/viewer.html` | Max opens `C:\Users\Max de Dikke\source\Open the AI training viewer.bat`; the page reloads every 15 s; closing it stops nothing |
| The results | `.sim_output/suite/<run>/results.jsonl` (one race per line), `status.json`, `logs/`, `jobs.txt`, a CSV per board in `<run>/rNNNN/` | Read with Python; every failure has a `replay` command |
| The race tool | `Game/dev/run_race.gd` | New options: `--course=fit:<template> --fit_at=x,z` (a new course laid on the lake), `--course_turn=<deg>`, `--course_shift=dx,dz` (refused on land or near the shore: `COURSE_ILLEGAL`), `--min_wind_kt=14` (`WIND_TOO_LOW`), `--restart_after=<s>` (the game's R), `--spawn=anywhere`, `--spread`; it prints `COURSE_JSON` and per board `HEADS_RESULT` with `spawn`, `start_need_s`, `legs_expected` |
| A frozen copy | `.sim_output/suite/frozen/Game` | The suite runs on a copy, so the working tree can be edited while it runs. Make or refresh it: copy `.sim_output/heads/frozenAny/Game` (it has the import cache), then `cp -r Game/<part>/. <copy>/Game/<part>/` for `race dev windsurfer ui maps/course maps/silvaplana/courses sim config` |
| On and off tests | `--extra="--skipper.<switch>=1"` | The same `--seed` and `--set` with and without the switch: the same races, so the difference is the switch |
| Scoring again | `tools/heads/rescore.py` | `<run>` scores a finished run's roundings again with the present measures (the old `results.jsonl` kept as `results_before_<time>.jsonl`); `--dry` only prints the medians |
| The summary | `tools/heads/suite_summary.py` | `<run>` (about 20 lines), `<run_off> <run_on>` (side by side, better / worse / same), `--failures=5`, `--wait` (waits until the run is complete: the one wake-up) |

The Godot engine: `C:/Users/Max de Dikke/AppData/Local/Programs/Godot/4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe`
(the suite has it built in; the GODOT environment variable overrides it). The game's release engine cannot run the
race tool's script and is no faster.

## What a race draws (phase A)

| What | Drawn from |
|---|---|
| Water | lake 80 %, open water 20 % |
| Course | lake: a saved course (T2 and the 10 iQFOiL ones) 40 %, the same shifted up to 50 m and turned up to 10 deg 30 %, a new course laid by the course fitter at a random spot (any of the 10 iQFOiL templates, 25 to 100 % of the class's size, marks 150 m and legs 60 m from the shore) 30 %; open water: T1 20 %, an iQFOiL template at 50 % or 100 % |
| Wind | lake: any hour from 11:00 to 18:00 times 0.7 to 1.4, drawn again when under 14 kt; open water: 14 to 26 kt |
| Countdown | 2, 3 or 5 minutes (the menu's, since 8 November) |
| Start | the game's start box 40 %, behind the line 30 %, anywhere round the course 30 % |
| Who | phase A: the general head (Hana at its best: `--spread=0 --steady_hands=1`); phase B: any of the 20 personas or 4 characters at the game's level (0.5) |
| R | in 20 % of the races: in the countdown, mid-race (20 to 600 s) or after the finish |
| Rules, shadows, gear | on (a single board: the rules and shadows do nothing yet) |

Not drawn yet: gusts on the open water (the race tool has none), fleets (phase C).

## The checks (every board must pass all of them)

| Check | Passes when |
|---|---|
| start | it crosses the start line no later than the way from where it was allows (the all-rounder's expected time from its spot to the line, less the countdown) plus 20 s |
| stuck | never under 1 m/s on the board for more than 20 s |
| aground | it never runs aground |
| finished | it finishes |
| legs | every leg within 1.4 times the leg's expected time (`TrainingDrops.expected_leg_s`) plus 30 s: on a beat, tacking still counts as progress; an overstand, a wide rounding, getting lost or crawling shows as a slow leg |
| race_time | the race within 1.25 times the expected plus 60 s |
| falls | at most one fall per 5 minutes |

## The roundings (measured at every mark and gate)

| Measure | How | Limit |
|---|---|---|
| closest | the nearest it came to the mark rounded (for a gate, the mark nearer to it) | 10 m |
| out of the turn (`exit_m`) | its distance from the mark when its heading first holds after the rounding (under 6 deg in 2 s) | 15 m |
| overstand | on a beat into the mark: how far its last tack was beyond its own layline: its own close-hauled track over the ground on that tack, from the same leg (without one: 57 deg off the course's axis on the open water, not measured on the lake). Until 9 November it was 50 deg off the axis, which counted a tack on the board's own layline as a 25 to 45 m overstand (it beats 57 deg off the wind on the open water, and on the lake the hour's wind does not blow along the course); rescore older runs with `tools/heads/rescore.py <run>` | 25 m |
| gate extra turning | in a gate's 80 m circle: the heading turned beyond the turn from the way in to the way out | 120 deg |

## The speed (measured 8 November 2026, the 8-core Ryzen 7 5800X3D)

One board on the race tool: 4.0 to 5.8 times real time (the open water faster than the lake); about 5 s to start up.
8 races side by side on one logical processor per core (mask 0x5555): each at full speed, 33 times real time together,
about 55 to 60 % CPU, about 100 to 150 one-board races an hour. 12 side by side (mask 0x55FF): 3.1 times each, 37
together, 82 % CPU: not worth it. The suite sets its own mask (default 0x5555); every Godot it starts inherits it.
Five different full races side by side took 1:41 (T1) to 7:57 (a new LG2 lasting 37 minutes).

## The loop, efficiently (required from 8 November 2026)

Max, 8 November 2026: "this loop needs to be documented and needs to be taken when training AI from now on". The loop
is steps 2 to 7 below. It costs machine time (the races) and tokens (the session's reading and writing). Every session
that trains the AI keeps both down this way:

1. **A fresh chat per loop, or at least per day.** Everything a session needs is in this document, the backlog and
   memory; a short conversation makes every step cheaper (each step re-reads the whole conversation).
2. **One wake-up per run, never one per race.** Start a run, then wait for it with one background command that ends
   when the run is complete and prints its summary:
   `python -I tools/heads/suite_summary.py <run> --wait` (or both arms: `... <run_off> <run_on> --wait`).
   No monitor that fires on every finished race, no polling, no waiting turn by turn in the chat. While the races run,
   the session reads code and prepares the next step, or ends its turn.
3. **Summaries, not logs.** Read `tools/heads/suite_summary.py` (about 20 lines a run; two runs side by side with
   "better / worse / same"), and `--failures=5` for the newest failures with their replay commands. Open a board's CSV
   or a replay's trace only for the two or three failures being diagnosed, and then only the rows that matter.
4. **Read only the code that matters.** `Game/race/skipper.gd` is about 3,000 lines: search for the function, read that
   function, not the file.
5. **Small batches when the problem is big.** When most races fail a measure (92 % of the roundings in the baseline), a
   real fix shows in 40 to 60 races a side; use 100 a side only for small effects, and 200 for phase A's final gate.
6. **Run what can run at once at once.** The on and off arms side by side, and the hold-out pair alongside when the
   tune pair already looks clear (8 jobs in all on mask 0x5555; two suites of 4 cores each, or one of 8).
7. **Related fixes in one loop** (for example the exit and the overstand of a rounding), each behind its own switch, so
   the numbers can still tell them apart.
8. **Write down as you go, briefly**: the numbers of each loop in this document's log below and in the story's notes.

**The budget of one loop** (estimates of 8 November 2026): machine time about 10 to 12 hours done one step after another
(the suite does about 50 races an hour on 8 cores: about 12 minutes of sailing per race, the R races sailed twice,
one draw in four redrawn), 5 to 8 hours with the arms side by side and small batches; tokens about 50 to 100 thousand
new (read and written) plus the conversation re-read at every step (about 3 to 6 million cached tokens in a long chat,
far less in a fresh one). Steps 1 to 8 in all: 3 to 4 days of running as first written, about 1.5 to 2 days with these
rules, less with the second PC as a second pool.

## The log of the loops

| Loop | Date | What was fixed (switch) | Tune set (off -> on) | Hold-out (off -> on) | Taken |
|---|---|---|---|---|---|
| baseline | 8-9 Nov 2026 | none: baseline_A, phase A, 300 races (seed 1) | 58.5 % pass every check; start 68 %, legs 89 %, race time 97 %, falls 97 %, aground 98.6 %; out of the turn median 30 m (93 % over 15), overstand median 31 m by the board's own track (212 beats; 58 m by the old 50 deg measure), closest median 7.6 m (33 % over 10), gates over 120 deg extra 41 %. The turn round a mark starts only once the rounding has counted: about 5 deg of it in the 6 s before the mark, the rest after (exit 35 m at a windward mark, 51 m at a leeward mark or gate onto a beat, 48 m at a slalom gybe mark) | - | - |
| 1 | 9 Nov 2026 | `round_early`: the turn round a mark or through a gate begins before it, as soon as the arc worked out at the controller's turn rates still rounds it with 4 m to spare (Skipper._round_early_deg(), _predict_rounding()) | 50 races (seed 2): out of the turn median 26.3 -> 19.5 m (over 15 m 89 -> 64 %), closest 7.7 -> 6.1 m, gates' extra turning 101 -> 81 deg, falls 0.1 -> 0.0 a race, every check the same; race time 101 s less in all (30 races faster, 19 slower) | 100 races (seed 1): out of the turn 29.0 -> 21.1 m (94 -> 71 % over 15), closest 7.8 -> 6.2 m, gates 98 -> 81 deg, race time 722 s less in all (73 faster, 19 slower, median 5 s a race), legs 89 = 89 %; but pass 63 -> 62 %, finished 99 -> 97, stuck 99 -> 97, falls 97 -> 95, aground 100 -> 99, start 69 -> 68 (3 worse, 2 better, before any rounding). Each traced: r0092 crawled into the shore in the lake's north-east corner (E01.S21) on its way to the finish, r0046 stalled at T2's mark 3 by the shore (both arms; off took 525 s there), r0011 stalled at a mark by the east shore, two legs over their limit by under a second; none during an early turn: a tighter rounding puts the board on another line, which sometimes meets a known trap | No (a check got worse on the hold-out, the rule in step 6). Left for Max: on with `round_early = true` if he takes the reasoning; off until then |
| 2 | 9 Nov 2026 | `mark_layline_margin_m` = 3 (the last tack of a beat into a mark 3 m past its layline instead of layline_margin_m's 10; Skipper._course_to(), the other-tack branch, where that tack is made) | 50 races (seed 3): overstand median 28.8 -> 19.2 m (over 25 m 58 -> 22 %), gates over 120 deg 38 -> 28 %, falls 0.2 -> 0.1 a race, race time 291 s less in all (21 faster, 11 slower); checks the same but legs, one race (r0034 swept past the finish line's end on the last run, a known weakness, on another line) | 100 races (seed 1, against round_early_hold_off: the suite is deterministic, the same code sails the same races to the second): overstand 30.8 -> 20.0 m (over 25 m 69 -> 31 %), pass 63 -> 64 %, legs 89 -> 92, race time 94 -> 96, 623 s less in all (51 faster, 19 slower); but start 69 -> 68 (r0068: R after the finish, the start after it 1 s over its 102 s) and falls 97 -> 96 (r0060, broken in both arms: off took 3004 s for leg 1) | No by the rule (a check worse by one race); for Max with round_early. The first on arm (`mark_margin_on_void_wrong_branch`) changed the beat branch, where the layline tack is never made: identical to off, no result |
| 3 | 9 Nov 2026 | `start_free_beyond_ends_m` = 100 (E09.S21: far beyond an end of the start line its extension's course side does not count as over; an existing switch, never run in the suite) | 50 races (seed 3): 5 races changed; start the same (r0024 better, r0025 worse after a mid-race R), legs and race time one race worse (r0024's leg 2), 95 s more racing | - | No: no gain |
| 4 | 9 Nov 2026 | `start_away_max_m` = 200 (E09.S21: in a long countdown, sailing away to use up its time to spare, it turns back 200 m from its spot; on the lake 45 % of the starts that went beyond 300 m away failed, r0137 went 520 m to the shore and came back 42 s short) | 50 races (seed 3): start 66 -> 70 % (5 better, 3 worse), pass 56 -> 60 %, stuck 98 -> 100 %, aground and finished the same (r0012 better, r0049 worse, both in the lake's north-east corner, E01.S21), 53 s less racing | 100 races (seed 1): start 69 -> 72 % (9 better, 5 worse), pass 63 -> 67 %, legs 89 -> 90, race time 94 -> 95, every other check the same, racing time the same (+3 s) | **Yes**: on by default (200 m), unit tests 1012/1012, the race tool's smoke run the same as the suite's on arm |
| 5 | 9 Nov 2026 | `hold_floor_ms` = 3 (an existing setting: never held back slower than 3 m/s before the start) | 50 races (seed 3, against the new defaults): start 70 -> 58 % (4 better, 11 worse: held faster it came to the line early), pass 60 -> 54 %, falls 96 -> 100 %, aground 98 -> 100 % | - | No |
| 6 | 9 Nov 2026 | `get_going_twa_deg` = 100 (an existing setting: under 2.5 m/s for 6 s after the gun it sails 100 deg off the wind until 5 m/s). Found with a debug replay of r0007 (hold-out): after the start's go at 2 m/s on a beam reach the stick was held hard toward the wind for 30 s, which at that speed did not turn the board and spilled the sail (angle of attack 3 to 5 deg): 2 m/s for 40 s | 50 races: start 70 -> 72 %, but legs 92 -> 88 % (it acts on any slow board, mid-race too), 237 s more racing | - | No |
| 7 | 9 Nov 2026 | `go_reach_twa_deg` = 90 (new: at the start's go, under 5 m/s, no closer to the wind than 90 deg until it has speed; r0007: over the line 4 s after the gun instead of 58) | 50 races: start 70 -> 74 %, aground and finished 98 -> 100 %, but legs 92 -> 86 % (r0039: both arms over the line together, the same track for 200 s, then apart at the west shore), 842 s more racing | 100 races: start 72 -> 78 % (8 better, 2 worse), pass 67 -> 69 %, race time 95 -> 96, falls 97 -> 98; legs 90 -> 86 % (4 worse, none better; with the tune set 7 worse, 0 better: too one-sided for chance, cause not found) | No (legs worse); the starts' cause is right, the legs' cost to be found |
| (for Max) | 9 Nov 2026 | `round_early` and `mark_layline_margin_m` = 3 together (a measurement for Max's decision, not a loop) | - | 100 races (against away_cap_hold_on): out of the turn 29.0 -> 20.4 m (93 -> 68 % over 15), overstand 31.3 -> 21.1 m (74 -> 38 % over 25), closest 7.8 -> 5.8 m, 858 s less racing (73 races faster, 21 slower), legs 90 -> 93 %; but pass 67 -> 64 %, start 72 -> 70 (2 better, 4 worse), falls 97 -> 94, stuck 99 -> 97, finished 99 -> 97, aground 100 -> 99: the same four races as round_early alone (the suite is deterministic: r0046 T2's mark 3, r0092 the north-east corner, r0019 a stall, r0060 broken in both arms) | Max's call |
| 8 | 9 Nov 2026 | `gybe_at_mark` (written in loop 1: at a mark whose next leg is on the other gybe it bears away and asks for the gybe once the gybe's arc rounds the mark) | 50 races (seed 3, against away_cap_on): it acted in 38 of 50 races, not only at slalom marks (any mark with the next leg on the other gybe, windward marks into a run too); out of the turn 31.6 -> 29.2 m, 27 races faster and 5 slower (26 s more in all); pass 60 -> 52 %, start 70 -> 66 %, legs 92 -> 88 % | - | No |

**Proposed for Max (9 November 2026, not agreed yet).** Step 6's "no check gets worse" on 100 races blocks a fix for one race's flip: a fix that changes the board's line changes which of the lake's known traps it meets (the north-east corner, T2's mark 3, the east shore), and a start after R depends on where the race before ended. Loops 1 and 2 each won clearly on the hold-out and lost one or two races on a check, every one traced to such chance. Proposed: a check counts as worse when it loses 3 or more races in 100 more than it gains, every flip traced in the log, and none of them during what the switch does. (In phase S the sign test below judges instead, explained to Max on 9 November; whether it also applies to the roundings later is his call.)

## The start phase (phase S, from 9 November 2026: Max's order)

Max, 9 November 2026, after racing the play build on an iQFOiL slalom course he had made more like a PWA slalom in the
race director (one board of eleven started): "first train the AI to be really good at starting because that is the
most important. because if you cant even start its already a disaster." Until the gate below, phase S comes before
everything else in step 3: the roundings (`round_early`, `mark_layline_margin_m`) and phase B wait, and stay off.

**Why the starts.** Loops 1 to 8's off arms (150 races, one board each): 43 boards late or never over the line; 38 of
the 42 late ones could have made it in the countdown by the start check's own estimate, 25 from the start box or from
right behind the line, some more than 2 minutes late. The lake is worse than the open water (55 to 69 % on time against
89 to 100 %), and the slalom courses worst: T2 slalom 30 %, iQFOiL SD3 43 %, PD3 0 to 50 % (few races).

**What phase S changes in a race (Max's decisions).**
1. **One board per race.** The CPU goes to the rough training; fleets (phase C) are polishing and come only after the
   gate ("if it starts 15 sec late its already 10x better then now").
2. **Never the same start twice.** Every race is drawn at random as in phase A (water, course: saved, shifted and
   turned, or new from the fitter; wind, countdown, start place, R), so the skipper learns a head for every start and
   not the fastest way for one course. **Every loop draws new races**: a new tune seed per loop and a new hold-out seed
   per confirmation, never one used before (the log records them). On 9 November tune seeds 1 to 3 and hold-out seed 1
   were used; phase S starts at tune seed 11 and hold-out seed 21.
3. **Only reachable drops.** A board is put only where it can reach the line with at least 30 s to spare: the start
   need from its spot (`start_need_s`) at most the countdown less 30 s; after an R, against the countdown it then has.
   A drop too far is drawn again, like a course on land (Max: "1 is better ... it also is faster in testing").
4. **Start-only races.** A race ends once the board is over the line (or at the start check's limit), so a race costs
   its countdown and a few seconds instead of a whole course: about 8 times more starts per hour than full races
   (estimate, to be measured in the first run).
5. **R** in 20 % of the races as before, in the countdown or up to 2 minutes after the gun; the start that counts is
   the one after the last R.

**The measures, per board.** The start check (over the line no later than 20 s after the gun), and alongside it: the
seconds after the gun it crosses, its speed at the gun, how far behind the line it is at the gun, over early (and
whether it went back), falls, stuck, aground.

**How a switch is judged (replaces step 6's rule in phase S).** Both arms sail the same races (the same seed: the suite
is deterministic), so per race the switch either **fixed** the start (late -> on time), **broke** it (on time -> late)
or changed nothing. A late start from a spot it could never make is late in both arms and counts for neither.
1. **Tune set**, 50 new races: it must fix more than it breaks; otherwise it stays off, with the reason in the log.
2. **Hold-out**, 100 new races: the fixed must beat the broken by more than chance: a one-sided sign test under 5 %.
   The fewest fixed that pass for each number broken:

   | Broken | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
   |---|---|---|---|---|---|---|---|---|
   | Fixed at least | 5 | 7 | 9 | 10 | 12 | 13 | 15 | 16 |

   (8-2, 11-4 and 14-6 just fail.)
3. **Nothing else worse by the same test**: falls, stuck, aground and over early may not lose by a margin that passes
   the sign test the other way; the median seconds after the gun may not go up.
4. **Every broken start traced** (its CSV, a replay when needed). If the switch's own action broke it, it is not taken,
   whatever the numbers.

Why not "no check worse": any change moves the board's path a little, which takes it into a lake trap here and out of
one there by chance; that rule blocked loops 1 and 2 over one or two races. The sign test lets chance through, not a
switch that really breaks starts.

**Step S0, the tools (once, before the first loop).**
- `Game/dev/run_race.gd`: `--start_only=1` (the race ends when every board is over the line, or at the start check's
  limit; the result says so); `--start_spare_s=30` (a drop whose `start_need_s` is over the countdown less this prints
  `DROP_TOO_FAR` and quits, like `COURSE_ILLEGAL`); in `HEADS_RESULT` the speed at the gun, the distance behind the line
  at the gun and over early.
- `tools/heads/random_suite.py`: `--phase=S` (one general head, start-only, the reachable drops, R in the countdown or
  up to 2 minutes after the gun); `DROP_TOO_FAR` joins `REDRAWN_MARKS`; the start measures in the results and the
  viewer.
- `tools/heads/suite_summary.py <off> <on>`: per check the races fixed and broken, and the sign test's verdict
  (`pass` / `chance`); the same for falls, stuck, aground and over early; the median seconds after the gun.
- Measure the speed of a start-only race and write it under "The speed".
- Unit tests for the sign test and the drop rule; nothing in `Game/sim/`, the controller or the autopilot.

**The loop in phase S** is steps 2 to 7 with these changes: step 1's baseline is `--phase=S`, 200 races on tune seed 11
(`baseline_S`); step 3 takes the biggest class of late starts (by water, course kind, start place, countdown, R; first
the slalom courses and the lake); steps 5 and 6 use new seeds and the judging above.

**The gate to fleets.** On a fresh hold-out of 100 races every start under 20 s. If the last few failures come from
outside the head (the physics, a known lake trap), show them to Max: he decides. Then phase C (fleets: starts in a
crowd), then back to the roundings.

**Open: Max's PWA course.** A play build cannot save a course (its `res://` is inside the pack); when Max saves it
from the course maker in the Godot editor, or describes it (the start line's angle to the wind, the marks and which
side they are rounded), it joins phase S's draw.

## The steps

**Step 0, before a run.** Fetch first (`git fetch --all --prune`; the two PCs hand over through GitHub). Work on
`ai/skipper-heads-8nov` or a branch from it. Refresh the frozen copy from the working tree. Check that nothing else is
running (`Get-Process Godot*`).

**Step 1, the baseline.** Phase A on the tune set:
`python -I tools/heads/random_suite.py --run=baseline_A --count=300 --cores=8 --seed=1 --set=tune --project=$PWD/.sim_output/suite/frozen/Game`
A run that is stopped goes on where it was when started again with the same command (it reads `results.jsonl`; each
race number has its own draw). The first `baseline_A` began on 8 November at 21:19; at 22:40 it had 43 races: 25 passed
every check; the start failed 16 times, a leg 8 times; 156 roundings: out of the turn median 29 m (92 % over 15 m),
overstand median 51 m (92 % over 25 m).

**Step 2, read the results.** `python -I tools/heads/suite_summary.py <run> --failures=5` (the viewer is Max's
overview). Then rank the failures by check and by what was drawn (course kind, water, start, R): `results.jsonl` with a
few lines of Python, printing counts only. For each failure class, open two or three
failures: the board's CSV (`<run>/rNNNN/<board>.csv`: race time, place, heading, speed, next step, what the skipper was
doing) and, when needed, replay with its `replay` command (it adds `--trace=<board>`: the whole telemetry). First check
the check: a failure that is the check's fault (a wrong expected time, a start need that ignores the countdown's hold)
is fixed in the suite, and said so.

**Step 3, choose the biggest class.** From 9 November 2026: phase S's late starts first, until its gate (above). The
order before that: (1) the roundings and laylines (Max's main pain: wide exits,
overstands, gates; E09.S23), (2) the starts (16 of 43; E09.S21), (3) the slow legs (E09.S02, E09.S20).

**Step 4, find the cause in the skipper** (`Game/race/skipper.gd`, `skipper_config.gd`), never in the physics. Write
the change behind a switch in `SkipperConfig`, off by default, with a comment that says what it does and why (the
failure it answers, the numbers).

**Step 5, the on and off test on the tune set.** The same `--seed` and `--set`, 100 races or more, once with
`--extra="--skipper.<switch>=1"`, once without (runs `<name>_off` and `<name>_on`, side by side with `--cores=4` each).
Wait for both with one background command: `python -I tools/heads/suite_summary.py <name>_off <name>_on --wait`. It
compares the pass rate per check, the roundings' medians and shares over the limits, falls and the legs' ratio to
expected, each marked better, worse or same. A fleet test is not needed in phase A.

**Step 6, confirm on the hold-out.** The same pair with `--set=holdout`, 100 races. The switch goes on only when the
hold-out gets better and no check gets worse. Write the numbers down: a row in the log of the loops above, the story's
notes, the progress log.

**Step 7, take it.** The switch on by default; `tools/test.sh unit` (1009 tests on 8 November) and the race tool's smoke
run; commit with the numbers in the message; the story's tasks ticked in the backlog; the dashboard rebuilt.

**Step 8, repeat** steps 2 to 7 until phase A's gate: on a fresh hold-out of 200 races, 95 % pass every check, and the
roundings' medians within the limits (out of the turn 15 m, overstand 25 m), no gate over 120 deg extra.

**Step 9, phase B: the personas.** `--phase=B` (all 20 personas and the 4 characters at the game's level). The same
loop; a persona's sloppiness (reaction, noise) may cost time, but no check may fail because of it.

**Step 10, phase C: fleets, when Max says.** The suite has no fleet draw yet: add `--fleet` (4 to 6 boards mostly,
some 15 to 31, drawn from all personas, with the rules and shadows), and the crowd's checks (penalties per board, starts
in a crowd). Fleets are about 15 times slower per race than one board.

**Step 11, a play folder only on Max's message.** `tools/release.sh build`, a new folder
`WindsurfingMMZB-play-<date>-<what>` with the launchers (push and body on the mouse), a README of what changed and what
to try, and a zip for the other PC. Max checks it on his screen.

## Known, open (8 November 2026)

- The menu race with 15 boards that did not race (Max): not reproduced; T1 and T2 with the menu's 15 personas race
  normally through the same setup. Waits on Max's menu choices (E09.S24).
- A rookie crawling after R on O2 in 2 of 18 restart cases (E09.S18 T5).
- The lake's north-east corner: a board on starboard crawls there (E01.S21, Michiel).
- T2's last leg 470 s against 29 s expected in one suite race (E09.S02).
- The AI cannot carve its tacks and gybes with Shift: a controller change, Max's OK (E09.S22).

The evening's full report: [reports/racing/heads_8nov/RESTART.md](reports/racing/heads_8nov/RESTART.md).
