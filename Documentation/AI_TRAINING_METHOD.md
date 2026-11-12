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
10. **Keep the PC at about 80 % CPU, give or take 5** (Max, 10 November 2026; until then 55 to 75 %): 12 jobs on
    mask 0x55FF (below).
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
| Phase S (the starts) | the same three tools | `random_suite.py --phase=S` (start-only races from reachable drops; below); `suite_summary.py <off> <on>` judges phase S runs race by race (fixed / broken per measure, the sign test's verdict, the races' labels); `--classes` ranks the late starts by class; the race tool's `--start_only=1 --start_watch_s=60 --start_spare_s=30`; unit tests `python -I tools/heads/test_suite_summary.py` and `Game/tests/unit/test_run_race_start_only.gd` |
| Phase S3 (the starts in company) | the same three tools | `random_suite.py --phase=S3` (three copies of the general head, each its own random start spot, the rules and shadows on, watched to 30 s after the gun); `suite_summary.py <off> <on>` judges every board on its own and adds the start's score (better / worse by more than 5 m, the sign test), no penalty, untangled; the race tool's `--start_follow_s=30` and `HEADS_RESULT`'s `score_m`, `cross_speed_ms`, `near_s`, `gun_felt_*`; unit tests `Game/tests/unit/test_felt_wind.gd`, `test_run_race_start_only.gd`, `tools/heads/test_suite_summary.py` |

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

**Start-only races (phase S, measured 9 November 2026):** 16 races on 8 cores (mask 0x5555) in 2:54, with 7 drops too
far drawn again (each costs a Godot start-up of a few seconds): about 330 starts an hour, 6 to 7 times the full races'
50. A run of 200 takes about 36 minutes, an on/off pair of 50 a side about 18, a hold-out pair of 100 a side about 36.

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

| baseline S | 9 Nov 2026 | none: `baseline_S`, phase S, 200 start-only races (tune seed 11; 123 drops redrawn) | 146 on time (73 %), median 6.0 s after the gun; stuck 99.5 %, aground 99.5 %, no fall 90 %, not over early 95 %. Late: lake 50 of 134 (saved courses 45 %, new 50 %, shifted 15 %), open water 4 of 66. By course: iq_lr2 6 of 9, iq_lg2 5 of 10, new LG2 4 of 4, new PD3 4 of 6, iq_i2 4 of 7, SM1 3 of 7. By what happened: **crawling at the gun** (under 3 m/s) 24, all on the lake (4 of them slalom dives): off the hold at 2 m/s on a beam reach the go pointed at once (Skipper._upwind_twa_deg() lets a board going from its hold point at 50 deg plus noise), the stick hard toward the wind did not turn the board and the sail drew at 2 to 4 deg (r0002: 2 m/s for 75 s, never over); **far behind at the gun** (over 100 m) 12; **over early at the gun** 9; at speed and near but late 7; fell 2 | - | - |
| S1 | 9 Nov 2026 | `go_reach_twa_deg` = 90 (loop 7's switch, now judged by phase S): no closer to the wind than 90 deg at the go until 5 m/s. Replays of 7 crawling starts of baseline_S: 90 deg 6 under 20 s (the seventh 21 s), 85 deg 5, 80 deg 5, 110 deg 1 (too low, away from the line) | 50 races (seed 12): on time 64 -> 78 %, **7 fixed, 0 broken** (p 0.008), median 8.9 -> 7.3 s, nothing else worse | 100 races (seed 21): on time 69 -> 77 %, **13 fixed, 5 broken** (p 0.048, passes), but the **median after the gun 7.1 -> 9.4 s** (rule 3: may not go up; of 64 on time in both, 25 later, 13 earlier). Broken, traced: r0015, r0051, r0057 (4.6, 8.3, 5.1 s -> 20.1, 24.0, 22.0 s: reaching at 90 deg first carried the board away from its crossing, the switch's own action), r0086 (stalled at 0.3 m/s at the gun), r0091 (over at the gun, fell) | **No**: rules 3 and 4 (the median up; three broken by its own action). The crawl's cause is right; S2 answers it without the detour |
| S2 | 9 Nov 2026 | `crawl_no_head_up_ms` = 2.5 (new): before its start, not holding back, slower than 2.5 m/s, the stick never asks to head up (bearing away it may) until 4 m/s (Skipper._steer_toward()). The crawl seen in the traces: at 1.5 to 2 m/s on a reach or broad reach with the stick held hard toward the wind the board did not turn and its sail drew at 1.5 to 4 deg (r0007 of s1_on: 80 s on a broad reach at 1.5 m/s in 16 kt, 200 m behind at the gun, the same at the go in r0002). Replays of 15 late baseline_S starts: about 10 fixed (crawling at the go 6 of 7 under 20 s, most 1.5 to 7 s after the gun; far behind r0020, r0048; slalom dives r0024, r0132) | 50 races (seed 13): on time 64 -> 68 %, 7 fixed, 5 broken (chance), **no fall 82 -> 96 % (7 fixed, 0 broken)**, median 6.2 -> 7.7 s. The 7 fixed all crawls on the lake (off late or never at 0.2 to 4.4 m/s, on 1 to 18 s after the gun). The 5 broken: three slalom approaches after an R (r0014, r0037, r0049: the two arms part in the slalom's own luff-up and back-behind flips; off crossed at 0.5 to 0.8 s by luck), r0024 the reaching start's drift onto the line (SM1, the arms 24 m apart at -50 s, off over by 2.4 s), r0023 a new PM1 | Not run: the switch left out of slalom starts first (S2b) | No (as written) |
| S2b | 9 Nov 2026 | `crawl_no_head_up_ms` = 2.5, not on a slalom's start (`Course.starts_upwind_of_the_boat()`: its crawl comes after its own luff-up, a cause of its own) | 50 races (seed 14): on time 64 = 64 %, **5 fixed, 5 broken** (no gain), over early 4 broken, median 7.2 -> 10.6 s. Broken: r0017 ran aground on the lake (on 284 m behind at the gun, off 1.3 s: the switch kept it from heading up off the shore, its own action), r0014, r0031, r0037 over early (PM1 reaching starts on a knife edge: off over the line 2 to 3 m behind at the gun at 1.8 m/s, on 10 s earlier at the hold after a different way there), r0024 | - | No: its own action broke r0017 |
| S2c | 9 Nov 2026 | `crawl_no_head_up_ms` = 2.5 with `crawl_stuck_s` = 4 (new): it lets go of the stick toward the wind only once stuck in the crawl, slower than 2.5 m/s with the stick asking to head up by more than 10 deg for 4 s (the trap lasted 75 to 80 s; a head-up at a crawl that works, off the shore or back behind the line, turns the board in a few). Replays: 8 of 9 crawling or far baseline_S starts fixed (r0002 7.1 s, r0016 11.2, r0086 9.1, r0034 6.1, r0063 6.6, r0094 4.1, r0020 0.8, r0048 3.3; r0021 24.2), and S2b's 5 broken sail as with the switch off (r0017 1.2 s, r0024 18.2, r0014 3.4, r0031 0.8, r0037 1.6) | 50 races (seed 15): on time 64 -> 76 %, **6 fixed, 0 broken** (p 0.016), median 6.8 -> 5.6 s, speed at the gun 5.3 -> 5.8 m/s, nothing else worse | 100 races (seed 22): on time 78 -> 82 %, **5 fixed, 1 broken** (p 0.109: chance; 7-1 passes), median 5.7 = 5.7 s; aground 1 broken. This hold-out had fewer crawls to fix (78 % on time off, 64 to 69 % in the other sets). Traced: r0026 (broken) the release acted 131 s before the gun on the way to the waiting point (3.2 against 1.7 m/s), and the board came to the line early after an R 13 s after the gun: over at the gun, 54.5 s; r0091 trapped in both arms in the lake's far corner (1105, -1315), 370 m off at the gun, crawling in circles with the shore lookout steering; on, the release let it gather speed on a heading into the shore: aground at -18 s | **No** (the sign test). The release must stand aside while the shore lookout steers (S2d) |
| S2d | 9 Nov 2026 | `crawl_no_head_up_ms` = 2.5 with `crawl_stuck_s` = 4, standing aside while the shore lookout turns it (`Skipper._shore_steers`). Replays: r0091 no longer aground (late in both arms, as off); the crawl fixes kept (s2c's hold-out r0013 10.0 s, r0024 6.6, r0051 11.4; baseline_S r0002 7.1, r0016 11.2, r0086 9.1, r0020 0.8, r0048 3.3) | 50 races (seed 16): on time 64 -> 78 %, **7 fixed, 0 broken** (p 0.008), median 8.9 -> 8.0 s, speed at the gun 4.2 -> 5.0 m/s, nothing else worse | 100 races (seed 23): on time 78 -> 83 %, **5 fixed, 0 broken** (p 0.031, passes), median 5.8 -> 5.7 s, nothing else worse (one race fell, r0014: late in both arms in the lake's north-east, on crossed at 53.8 s after a standstill fall 3 s after the gun, off never) | **Yes**: on by default (2.5 m/s, `crawl_stuck_s` 4) |
| S3 | 9 Nov 2026 | `reaching_loop_excess_s` = 5 (new): on a line its hold's track runs at (0.7 or more of it toward the line: a reaching start, the line along the wind), a skipper who loops sails its timing loop once its time to spare beats what the way in can use up by 5 s instead of 35 (Skipper._loop_excess_s()). With the crawl rule on, the biggest class left: over early on the PM1 and SM1 templates (8 of 28 late in S2d's 150 on-arm starts): held back straight at the line from 150 m with 67 s to spare, 12 to 18 s early at the go point. Replays: the 5 late reaching starts tried all start 0.4 to 0.6 s after the gun at 7 to 10 m/s (baseline_S r0045, r0049, r0166; s2b_off r0003, r0010); two on time on a knife edge (r0031, r0037 at 1.7 m/s) at 4.1 and 10.7 m/s | 50 races (seed 17, the crawl rule on in both arms): on time 74 -> 78 %, **2 fixed, 0 broken** (few reaching starts in the set), over early 2 fixed, median 7.2 = 7.2 s | 100 races (seed 24): on time 73 -> 76 %, **4 fixed, 1 broken** (p 0.188: chance), over early 7 -> 4 %, median 7.9 -> 6.9 s. The 4 fixed are PM1 reaching starts on the open water (off over the line at the gun and 32 to 41 s late; on 0.5 to 0.6 s after the gun at 6 to 10 m/s). Broken, traced: r0099 (iq_sm1 on the lake, its hold runs at the line too): both arms flip between away, turning back, to the waiting point and back behind the line for two minutes (E09.S21 T1); the switch added one loop, and on it came back 93 m short (23.4 s against off's 3.8) | **No**: the sign test, and r0099 broken by its own action (a loop in a flipping lake approach). The cause on the open water is right; the lake's flips first (T1). (The number of away loops says nothing by itself: of 300 starts, 0, 1, 2 and 3+ loops were 21, 24, 21 and 23 % late) |
| S4 | 9 Nov 2026 | `slalom_dive_gybes` (written in S2's time): on a slalom's dive with its crossing on the other tack, from 70 deg or deeper it bears away and gybes (Skipper._gybe_now()) instead of asking at once (the controller tacks up to 100 deg; r0024 of baseline_S tacked at 6 m/s on T2, stopped in the wind's eye, 52 s late). Replays of 11 late slalom starts of baseline_S: r0024 52 -> 11.8 s, r0132 51.9 -> 7.5 s, four others much earlier but still late (r0191 never -> 21.6, r0133 41 -> 31, r0172 52 -> 37, r0186 23 -> 21) | 50 races (seed 18): **0 fixed, 0 broken**; one more over early (r0001); median 6.1 = 6.1 s: in fresh races the turn it changes hardly comes up | - | **No**: no gain. (Also tried in replays and dropped: `slalom_early_ease`, easing instead of the early luff on the dive: 1 of 11 changed; a gybe instead of the tack at the go when the line is on the other tack at a crawl: 6 of 9 unchanged, 3 later) |
| S5 | 9 Nov 2026 | `crawl_go_stuck_s` = 0 (new): in the go off its hold the crawl rule lets go at once instead of after crawl_stuck_s's 4 s. With the crawl rule on, S3's off arms (150 starts) still had 10 of 40 late starts crawling at the gun on the lake, half of them 20 to 24 s late: gone from the hold at 1.6 to 2 m/s some 33 m back, the 4 s and the climb out of the crawl. Replays of those 10: 7 under 20 s (5.6 to 16.7 s after the gun, the falls gone), r0025 21.4, r0042 23.2, r0004 never | 50 races (seed 19): **0 fixed, 0 broken** (84 % on time in both: few late starts in the set), speed at the gun 5.4 -> 6.0 m/s, behind the line 16.3 -> 13.7 m, median 5.2 -> 5.1 s. A 0-0 says nothing either way, so one more tune set of 50 (seed 20; written down before it ran): on time 70 -> 74 %, **2 fixed, 0 broken**, median 9.3 -> 6.8 s, speed at the gun 6.0 -> 6.7 m/s | 100 races (seed 25): on time 74 -> 82 %, **9 fixed, 1 broken** (p 0.011, passes), median 6.3 -> 5.3 s, speed at the gun 5.7 -> 6.2 m/s, behind the line 18.1 -> 14.9 m. Broken, traced: r0001 (iq_i2, R in the countdown): off went at -10 s from its hold at 2.3 m/s, crawled and started 7.7 s after the gun; on, let go at once, it gathered speed faster than the go's timing expects (from 2.3 to 7 m/s by -2 s), held back hard too late and was over at the gun (then round the end, a fall at +46 s) | **No** by rule 4: its own action broke r0001 (the go's timing does not know the board now gains speed at once). Its 9 fixed say the release in the go is worth having once the go's timing allows for it |
| S6 | 9-10 Nov 2026 | `reaching_loop_excess_s` = 5 again (S3), now with `loop_within_away_max` (new): a skipper who loops starts its timing loop only nearer its spot than start_away_max_m (from farther out it turned back at once and began again: S3's broken r0099 flipped between away, turning back and to the waiting point for two minutes on the lake). Replay of r0099 with both: 0.4 s after the gun (off 3.8 s, S3's switch alone 23.4 s). Loops that turned back within 2 s of starting: 8 races of 250 | 50 races (seed 21): on time 76 -> 80 %, 4 fixed, 2 broken, over early 2 fixed, median 6.2 -> 5.4 s, speed at the gun 5.7 -> 6.9 m/s. Broken, traced: r0028 (a new PM1 on the lake) and r0044 (a new LG2 on the lake, R in the countdown): on sailed a timing loop the off arm did not, came back through back behind the line and the line on the other tack, 44.9 and 21.3 s against 5.4 and 9.3 | Not run: two starts broken on the tune set by its own action (loops on the lake), which rule 4 would block on the hold-out too | **No**. On the open water the reaching loop wins every time (S3's four PM1 starts); on the lake a loop's way back does not hold (shifts, lee, the shore). Kept off for Max |
| S7 | 10 Nov 2026 | `crawl_go_stuck_s` = 2 (S5's switch at 2 s instead of 0, on new seeds): in the go off its hold the crawl rule lets go after 2 s, so the board gains speed sooner but not at once (S5's broken r0001 gained it at once and came early). Replays of S3's 10 crawling-at-the-gun starts and S5b's 2: 6 under 20 s (r0021 14.8 s, r0084 18.2, r0025 6.3, r0037 15.9, r0077 17.2, s5b r0048 16.7), no start early. (Also tried in replays and dropped: the crawl rule on slalom starts too, `crawl_on_slalom`: none of 12 late slalom starts changed; their crawl is the light wind in T2's start area and the dive's timing, not the head-up trap) | 50 races (seed 22): on time 68 -> 70 %, **1 fixed, 0 broken**, median 8.8 -> 7.3 s, speed at the gun 5.2 -> 5.6 m/s | 100 races (seed 26): on time 76 -> 77 %, **1 fixed, 0 broken** (chance), median 5.6 -> 5.5 s, speed at the gun 5.4 -> 5.8 m/s, nothing else worse | **No**: too weak to show (the 2 s grace keeps few of S5's rescues) |
| (slalom, replays only) | 10 Nov 2026 | The slalom courses' starts (86 in the off arms of S3 to S6 under the present defaults: 23 late after a clean dive, 16 dives that luffed up early, 9 of them over at the gun; 8 of the 46 in the tune sets over at the gun). Measured: in 151 clean dives (no early luff, no other turn before the line) the dive took 1.44 to 1.73 times the skipper's reckoning (_time_to_cross_s(), median by the speed at the go), some 10 s longer. Tried on the 46 slalom starts of the tune sets S3, S5, S5b and S6 (replays, the off results known): `slalom_dive_time_factor` 1.3 (go earlier) 6 fixed / 7 broken, most broken over early; with `slalom_dive_ease` (ease when ahead) by the reckoning 7 / 7, by the way to its spot over the time left 5 / 5, by its closing rate on the line 7 / 8; the ease alone 0 / 1; `start_free_beyond_ends_m` 5 m 7 / 8 (the waiting spot upwind of the boat lies about 20 m from the line's extension, the parking circle's radius: boards on the way there or parked cross it and turn back behind the line; 25 m 5 / 7) | - | - | **None run**: every change flips some 15 of the 46 both ways. The slalom start is on a knife edge (waiting at 0.5 to 1 m/s, a dive that cannot slow, a waiting spot by the extension, T2's start area in a lee at 8 to 10 kt); it needs a redesign rather than a switch (for Max) |
| (late, replays only) | 10 Nov 2026 | After the gun, a late board that never reached its hold sails "for the spot" (beating up to its own spot) and a going one for its spot when that is a reach: tried crossing where it crosses soonest instead (`late_quickest_crossing`, only after the gun, so it cannot bring a board over early). Replays of the late and the on-time-after-8-s non-slalom starts of five tune sets (S3, S5, S5b, S6, S7; about 70 ran): it acted in some 20, **1 fixed, 0 broken**, 34 late in both | - | - | **None run**, the switch removed: the late boards are late for other reasons (a crawl, distance, the lake's light patches), not for the point of the line they choose. Under the present defaults the late starts (S7's off arms, 150 starts: 111 on time) are mostly well late: 5 at 20 to 30 s, 19 at 30 to 45 s, 5 at 45 to 60 s, 10 never |
| S8 | 10 Nov 2026 | `crawl_in_timing` (new): the time it reckons it needs to cross (Skipper._time_to_cross_s()) counts crawl_stuck_s more when it is crawling and the course to the line is more than 10 deg toward the wind of its heading, the wait before the crawl rule lets it gather speed, so it goes that much sooner. Under the present defaults boards gone from a hold along the line at about 2 m/s gathered speed along it after the wait, ran out of line ("the line is on the other tack"), crossed its extension and started 20 to 47 s late (S7's off arm r0017, r0034, r0050). Replays of the late and the on-time-after-8-s non-slalom starts of five tune sets: **7 fixed, 2 broken** (one over early), the on-time starts 2.5 s sooner (median); the starts on time within 8 s, the likeliest to come early, were not replayed | 50 races (seed 23): on time 60 -> 66 %, **4 fixed, 1 broken**, median 11.1 -> 9.1 s, behind the line at the gun 19.6 -> 15.8 m, no more over early. Broken, traced: r0031 (iq_lr2, R in the countdown): on went at -9 s instead of -4 s at 2.4 m/s, gathered speed along the line, met its extension at the gun and turned back behind it: 46.4 s against 3.0 (its own action) | 100 races (seed 27): on time 76 -> 80 %, **5 fixed, 1 broken** (p 0.109: chance), median 5.8 -> 5.7 s, falls 2 fewer. Broken, traced: r0018 (a new LR2, behind the line): on went at -21 s instead of -16, came to the line early at 8 m/s, flipped between going and holding back hard every think and was over at the gun (32.1 s against 0.5; its own action) | **No**: the sign test and rule 4. The go's flip near the line (going, early, going) is a weakness of its own: next |
| S9 | 10 Nov 2026 | `crawl_go_stuck_s` = 0 (S5) with `early_unlatches_go` (new): going for the line and about to cross it early with time to spare by its own timing, it stops going until that timing says go again (near the line it kept going once gone, so turned away from the line it headed for it again at once: going, early, going, every think; S5's broken r0001 and S8's r0018 were over at the gun so). The two judged together as one change: the faster go and its safety. `early_unlatches_go` alone in replays of 99 tune-set starts (every over-early non-slalom one and every one on time within 5 s): 1 fixed, 0 broken, over early 14 -> 12 | 50 races (seed 24): on time 78 -> 80 %, **1 fixed, 0 broken** (few crawls in the set), behind the line at the gun 20.2 -> 15.7 m, median 6.2 = 6.2 s, nothing else worse | 100 races (seed 28): on time 74 -> 81 %, **7 fixed, 0 broken** (p 0.008, passes), median 7.2 -> 5.5 s, speed at the gun 5.1 -> 6.2 m/s, behind the line 18.1 -> 15.4 m; falls and over early one fewer each, nothing else worse; no broken start to trace | **Yes**: both on by default (`crawl_go_stuck_s` 0, `early_unlatches_go` true) |
| (replays) | 10 Nov 2026 | Under the new defaults (S9 on): `slalom_slot_back_m` = 20 (new: the slalom's waiting spot 20 m further behind the line and its extension) on 43 slalom tune starts (S9's on arm, S8's and S7's off arms, both arms replayed): **8 fixed, 5 broken**, over early 9 -> 7; three broken over early (a longer dive, as variable as ever, came early). The reaching loop again (S6's switches) on S6's six flipped starts: 4 fixed, 1 broken (r0028, a new PM1 on the lake: the away run, from out past the line's end, crossed the line's extension and the way back to the waiting point was a beat of 80 s); with no loop from out past an end of the line as well: worse (r0028 never, r0024 and r0048 late) | - | - | None run: the best slalom change yet is still a coin-flip on the hold-out by rule 4; the reaching loop on the lake stays unreliable |
| **before / after** | 10 Nov 2026 | The defaults as taken (S2d, S9) sailed again on the same races as before (the suite is deterministic): baseline_S's 200 (tune seed 11) and S1's hold-out of 100 (seed 21, sailed then on the baseline's code) | 200 races (seed 11): on time **73.0 -> 83.5 %**, **22 fixed, 1 broken** (p < 0.001), median 6.0 -> 5.7 s, speed at the gun 5.9 -> 6.5 m/s, stuck, falls and over early one fewer each | 100 races (seed 21): on time **69 -> 85 %**, **16 fixed, 0 broken** (p < 0.001), median 7.1 -> 5.4 s, speed at the gun 5.1 -> 6.1 m/s, nothing worse | Left late (seed 11, 33 of 200): the slalom courses 12 (new PD3 4 of 6), the long lake courses (iq_lg2, iq_lr2, new LG2) 9, SM1 on the open water 3 |
| (replays) | 10 Nov 2026 | Under the present defaults, on tune starts: `crawl_release_ms` 5.5 (head up again only from 5.5 m/s, not 4: on iq_lg2 the go sat at 2 to 5 m/s on a beam reach for 15 s in 15 kt, heading up at 4 m/s slowed it back into the crawl) on 109 non-slalom starts: 1 fixed, 5 broken (a longer run along the line); `slalom_early_abort` (a dive more than 6 s early given up, back to the waiting spot) on 55 slalom starts: 0 / 2; `slalom_wait_ms` 2.5 (waiting upwind of the boat at 2.5 m/s and 60 deg instead of as slow as it steers): 7 / 10 | - | - | None run, the switches removed |
| **final** | 10 Nov 2026 | The present defaults on a fresh hold-out of 200 (seed 29) | - | **163 of 200 on time (81.5 %)**, median 5.4 s after the gun, speed at the gun 6.5 m/s, behind the line at the gun 15.4 m; stuck 100 %, aground 100 %, no fall 91.5 %, not over early 95.5 %. Late: the lake 34 of 136 (new courses 34 %, saved 23 %, shifted 19 %), the open water 3 of 64; by course iq_pd3 7 of 10, T2 4 of 7 (the slalom courses), PM1 3 of 9, new SM1 2 of 2, iq_pm1 2 of 9 (reaching starts), iq_us4 4 of 14, new I2 3 of 7 | The gate (100 of 100) not reached; the loop stopped at 05:15 with no switch-sized idea left that the rules could take (see "State after the first phase S loop") |

| baseline S3 | 10 Nov 2026 | none: phase S3 (three copies of the general head, own random start spots, rules and shadows on, watched to 30 s after the gun), `s3_base` (tune seed 31) and `s3_hold_base` (hold-out seed 41), 100 races (300 board starts) each, frozen copy `frozen_S3` (79580d0 + c25afab). 12 jobs on 0x55FF: 80 to 82 % CPU, **about 50 races an hour per run of 3 jobs** (200 an hour in all; 10 November's estimate was 125: a run of 100 takes about 2 h, not 3.2) | on time 78.3 %, not over early 94.7 %, no penalty 91.0 %, untangled 79.0 %, score median 71.8 m (mean 82.3), felt/mean wind at the gun 1.0 (median: most starts are not in a lull) | on time 79.7 %, not over early 89.3 %, no penalty 92.7 %, untangled 81.0 %, score median 70.8 m (mean 89.2) | - |
| (classes) | 10 Nov 2026 | The bad boards of both baselines (late, or score under 20 m; 600 board starts): **over early 39** (27 on the lake; 19 slid over from "holding back hard, early" at 1.5 to 1.9 m/s and 8 of those were then 20 to 47 m over at the gun, the way back sailing off on a reach to tack or gybe for a point behind the line, e.g. s3_hold_base r0001/1; 17 slalom dives, the knife edge waiting on Max), fell 22 (all on the lake, mean score -79 m), more than 60 m behind the line at the gun 20 (17 lake), a penalty 14, slow at the gun in a lull (felt under 85 % of the mean) 13, 25 to 60 m behind at the gun 13, slow at the gun 10, tangled 2 | - | - | - |
| S3-1 | 10 Nov 2026 | `felt_wind_s` = 60: the skipper reckons with the mean of what its own sail felt over 60 s (FeltWind) instead of the telemetry's wind (on the lake the lake's mean) | 100 races (seed 31): score median 71.8 -> 60.4 m, mean 82.3 -> 71.9; **93 boards better, 128 worse (WORSE by the sign test, p 0.992 the other way)**; on time 78.3 = 78.3 % (23 fixed, 23 broken), untangled 79 -> 83 %, penalties 91 -> 93 % | 100 races (seed 41): score median 70.8 -> 65.9 m, mean 89.2 -> 87.3; 111 better, 120 worse (no gain); on time 79.7 -> 78.0 %, not over early 89.3 -> 87.0 % | **No** (worse on tune, no gain on the hold-out) |
| S3-2 | 10-11 Nov 2026 | `start_gust_lead` = 1 alone (S3-1 not taken): in a wind that varies it goes for the line earlier, by the felt wind's spread over its mean (last 60 s) times its reckoned time to the line | 100 races (seed 32): score median 57.5 -> 58.4 m, mean 80.8 -> 80.7; 76 boards better, 72 worse (chance); on time 71.3 -> 71.7 % (12 fixed, 11 broken), untangled 75.7 -> 80.0 %, no penalty 91.7 -> 94.0 % | 100 races (seed 42): score median 68.1 -> 66.0 m, mean 87.4 -> 84.8; 84 better, 69 worse (p 0.129, chance); on time 72.0 -> 73.0 % (14 fixed, 11 broken), untangled 89.0 -> 86.7 % | **No** (chance on both) |
| S3-3 | 11 Nov 2026 | `start_dip` (new, the biggest class: over early): before the gun, at a crawl early at the line, or just over the line itself, it bears away on its tack to the angle closest to the wind whose track runs away from the line (where none does, a reaching start, it tacks or gybes away at once) instead of creeping on or sailing off on a reach to tack or gybe back. Frozen copy `frozen_S3b`. Smoke race (hold-out 41 r0001): one board no longer over, one over by 2.9 m instead of 11.5 | 96 of 100 races (seed 33): score median 67.5 -> 65.1 m, mean 80.7 -> 77.0; 44 boards better, 52 worse (no gain); on time 78.8 -> 77.4 % (14 fixed, 18 broken), not over early 90.6 -> 89.6 % (7 fixed, 10 broken), no penalty 94.4 -> 96.5 % | 96 of 100 races (seed 43): score median 62.2 -> 64.8 m, mean 85.6 -> 86.1; 56 better, 53 worse (chance); not over early 89.9 -> 93.1 % (**15 fixed, 6 broken**), untangled 77.4 -> 80.9 % (17 fixed, 7 broken), on time 79.9 = 79.9 % | **No** (the score: no gain on either set; over early fixed on the hold-out but not on tune) |
| S3-4 | 11 Nov 2026 | `slalom_wait_moving` (new, the second class: falls; 54 of the baselines' 88 falls came waiting upwind of a slalom's committee boat, luffed up at 0.2 to 0.4 m/s, mostly in 20 kt or more): the slower it goes while waiting there, the further it bears away, from its luffed-up angle at 2.5 m/s to a beam reach at 0.8 m/s. Frozen copy `frozen_S3c`. Replays of four hold-out fall races: falls 29 -> 2, the score mixed. Traced (hold-out 45 r0016/0): waiting at 1.6 m/s instead of 0.5 it went from 50 m elsewhere 3.5 s later and was at the line 1 s early: the slalom dive's timing, the knife edge | 100 races (seed 34): **no fall 91.0 -> 94.7 % (12 fixed, 1 broken)**; score median 73.4 -> 71.0 m, mean 85.6 -> 82.5, 27 boards better, 26 worse (chance); on time 76.7 -> 74.3 % (6 fixed, 13 broken), not over early 91.0 -> 89.0 % (4 fixed, 10 broken) | 100 races (seed 45): **no fall 88.0 -> 94.0 % (18 fixed, 0 broken)**; score median 70.2 -> 67.8 m, mean 93.5 -> 84.7, 29 better, 38 worse (no gain); not over early 92.3 -> 91.0 % (6 fixed, 10 broken) | **No** (the score no gain; for Max: the falls fixed beyond chance, the cost is the slalom dive's timing) |
| S3-5 | 11 Nov 2026 | `start_accel_share` = 0.8 (an existing setting, never judged; Max's risky or safe): it reckons with 80 % of the measured acceleration off a hold, so it goes for the line earlier. At the gun the boards were a median 12 to 18 m behind the line and 4 to 8 s late | 100 races (seed 35): score median 64.4 -> 65.3 m, mean 84.5 -> 83.4; 61 boards better, 67 worse (no gain); behind the line at the gun 14.9 -> 14.6 m; on time 78.3 -> 77.7 % (4 fixed, 6 broken) | 100 races (seed 46): score median 62.9 -> 60.3 m, mean 59.4 -> 55.8; 56 better, 49 worse (chance); behind at the gun 18.3 -> 16.1 m; on time 76.0 -> 73.0 % (**1 fixed, 10 broken**) | **No** (chance; going earlier by the reckoning barely moves the boards) |
| S3-6 | 11 Nov 2026 | `slalom_wait_moving` gentler (S3-4's switch with its new settings `slalom_wait_luff_from_ms` = 1.5, `slalom_wait_widest_twa_deg` = 70: luffed up from 1.5 m/s, at a stall no wider than 70 deg, so it waits slower, nearer the old wait). Frozen copy `frozen_S3d`; the last block, sized to end by 08:15 | 45 races (seed 34, against S3-4's off arm `s3bA_base`): no fall 92.6 -> 95.6 % (4 fixed, 0 broken); score 7 boards better, 15 worse (no gain), mean 79.0 -> 73.2 m; on time 76.3 -> 73.3 % (2 fixed, 6 broken). Against S3-4's on arm: over early 5 fixed, 1 broken; falls 0 fixed, 3 broken | 55 races (seed 47): **no fall 90.3 -> 95.2 % (8 fixed, 0 broken)**; score 20 better, 15 worse (chance), median 68.2 -> 71.9 m; on time 75.8 -> 79.4 % (9 fixed, 3 broken, p 0.07), not over early 89.7 -> 91.5 % (7 fixed, 4 broken) | **No** (the score: no gain on tune, chance on the hold-out); the falls fixed again, without S3-4's over-early cost on the hold-out: the direction for the slalom's redesign |
| S3-7 | 11 Nov 2026 | `start_accel_share` = 0.65 (S3-5 further: goes earlier still). Tune only (the last block had room for one hold-out pair, given to S3-6) | 45 races (seed 35, against S3-5's off arm `s3bB_base`): score 35 boards better, 25 worse (p 0.12, chance), median 80.8 -> 84.0 m, mean 107.8 -> 112.1; behind the line at the gun 10.3 -> 8.1 m; on time 85.2 -> 83.7 % (0 fixed, 2 broken), over early 1 fixed, 2 broken | - | Not judged (no hold-out); a lead: the first value that moved the boards nearer the line |
| S3-8 | 11 Nov 2026 | `start_go_lag_s` = 3 (new; the day's run, Max: "a little more safe but fast over the startline"): the time getting going from a hold takes beyond its reckoning, added to the time it reckons it needs, the whole of it at 2 m/s and slower, none from 5 m/s up (measured on the night's off arms: going at 1 to 3 m/s a median 2.8 to 3.7 s late). Frozen copy `frozen_S4`; the day's block 1 | 100 races (seed 31, against `s3_base`): score 90 boards better, 66 worse (p 0.033, pass), median 71.8 -> 70.2 m, mean 82.3 -> 76.1; behind the line at the gun 16.5 -> 5.2 m, start median 6.0 -> 2.8 s after the gun; **over early 1 fixed, 7 broken (WORSE)**; on time 7 fixed, 11 broken | 100 races (seed 48, fresh, against `d1_hold_base`): score 75 better, 48 worse (p 0.009, pass), mean 70.9 -> 66.4 m; behind at the gun 15.4 -> 6.0 m; **over early 2 fixed, 13 broken (WORSE)**; on time 2 fixed, 15 broken | **No** (over early `WORSE` on both sets). Nearer and earlier, but of the 20 boards newly over early 5 crept over holding back hard at a crawl (`start_dip`'s case) and 8 were turning onto the way in at speed in the last seconds; next with `start_dip` and the new `early_holds_its_tack` (S3-10) |
| S3-9 | 11 Nov 2026 | The slalom package: S3-6's gentler `slalom_wait_moving` with `slalom_dive_time_share` = 1.4 (new: the dive from the wait reckons with 1.4 times its time to the line, so it goes a little earlier and less on the knife edge). Frozen copy `frozen_S4b`; the day's block 2 | 100 races (seed 32, against `s3b2_base`): score 35 boards better, 28 worse (chance), median 57.5 -> 59.2 m, mean 80.8 -> 81.1; **no fall 94.3 -> 97.7 % (10 fixed, 0 broken)**, untangled 75.7 -> 81.0 % (16 fixed, 0 broken); not over early 88.7 -> 87.7 % (11 fixed, 14 broken); falls or over early 16 fixed, 12 broken (p 0.29, chance); penalties 26 -> 21 | 100 races (seed 48, against `d1_hold_base`): score 38 better, 43 worse (no gain), mean 70.9 -> 68.0 m; no fall 88.3 -> 92.7 % (15 fixed, 2 broken); not over early 89.7 -> 88.3 % (10 fixed, 14 broken); falls or over early 21 fixed, 13 broken (p 0.12, chance). Against the gentle wait alone on the same races (`d1_hold_wait2`): 9 fixed, 12 broken | **No** (not safer beyond chance on the hold-out: the dive share takes back the gentle wait's over-early gain, 14 boards newly over early against the wait alone's 8). The dive share alone is not run |
| S3-10 | 11 Nov 2026 | The fast package: `start_go_lag_s` = 3 with `start_dip` and `early_holds_its_tack` (new: early at the line on the other tack than its way in's, it holds back hard on the tack it is on instead of turning onto the way in's tack at speed; replays of S3-8's newly-over boards: 4 of 5 no longer over). Frozen copy `frozen_S4d`; the day's block 2 | 100 races (seed 31, against `s3_base`): **score 123 boards better, 81 worse (p 0.002, pass)**, median 71.8 -> 72.8 m, mean 82.3 -> 80.0; behind the line at the gun 16.5 -> 5.0 m, start median 6.0 -> 2.6 s after the gun; on time 78.3 -> 80.7 % (21 fixed, 14 broken); not over early 94.7 -> 93.7 % (6 fixed, 9 broken, ok); no fall 3 fixed, 6 broken; untangled 21 fixed, 24 broken; penalties 27 -> 22. Against S3-8's lag alone: falls or over early 11 fixed, 6 broken | 100 races (seed 48, against `d1_hold_base`): **score 125 better, 73 worse (p 0.000, pass)**, median 65.2 -> 69.3 m, mean 70.9 -> 72.8; behind at the gun 15.4 -> 5.8 m, start median 7.3 -> 6.0 s; on time 16 fixed, 18 broken; not over early 15 fixed, 18 broken (ok); untangled 83.3 -> 79.7 % (15 fixed, 26 broken, p 0.059: ok, but near); falls or over early 13 fixed, 17 broken (chance). Against S3-8's lag alone: 18 fixed, 12 broken | **Yes** by the S3 rule (the score passes on both sets, nothing `WORSE`), to the final check on hold-out 44. Fast, not safer: falls plus over early at chance against the evening. Traced: the most worse boards are over early by under a second. Tune r0096/2 went 5.5 s earlier from 2.6 m/s in a strong wind, was at 9.7 m/s in 3.5 s, held back hard twice and still crossed in the last second before the gun; hold-out r0043/0 crept to 10 m from the line at 1.6 m/s, went 3.5 s earlier than the evening's, turned away and held back, and crossed anyway. Of the 18 newly over on the hold-out 5 were holding back hard at speed, 6 coming in off the line's extension, 1 turning onto the way in (S3-8: 8). Next: the lag close to the line (it adds 3 s even when the reckoned time is no longer than that) |
| S3-11 | 11 Nov 2026 | `start_cross_room_deg` = 15 (new, the biggest cause of lateness: of the night's 1,710 clean starts from a hold 615 tacked or gybed after going, a median 8 to 10 s late; from a crawl the board sags below a crossing chosen at the close-hauled limit): a crossing closer to the wind than 15 deg beyond its beat's track is chosen again, a point with that room preferred. Frozen copy `frozen_S4d`; the day's block 3 | 100 races (seed 31, against `s3_base`): **score 34 boards better, 81 worse (`WORSE`)**, median 71.8 -> 67.2 m, mean 82.3 -> 79.4; behind the line at the gun 16.5 -> 11.1 m; not over early 0 fixed, 4 broken (p 0.06); falls or over early 0 fixed, 5 broken (`WORSE`); clean starts from a hold that tacked or gybed on the way 54 -> 61 | 100 races (seed 48, against `d1_hold_base`): **score 37 better, 69 worse (`WORSE`)**, median 65.2 -> 59.5 m; behind at the gun 15.4 -> 11.6 m; not over early 1 fixed, 4 broken; tacked or gybed on the way 66 -> 66 | **No** (the score `WORSE` on both sets, and the tacks on the way it was for did not go). Traced (tune r0015/2, -98 m): the same start until 3 s after the gun, when the spot check with its room sent it onto the other tack for half a second at the line; it beat on 5 deg lower and slower. The tack after going needs another explanation |
| S3-12 | 11 Nov 2026 | S3-6's gentler `slalom_wait_moving` alone (luffed up from 1.5 m/s, at a stall no wider than 70 deg), judged in full: hold-out 48 in block 1 (`d1_hold_wait2`), tune 32 in block 3 (`d3_wait2_t32`). Frozen copies `frozen_S4` and `frozen_S4d` | 100 races (seed 32, against `s3b2_base`): score 34 boards better, 28 worse (chance), median 57.5 -> 60.3 m, mean 80.8 -> 84.2; no fall 94.3 -> 97.7 % (10 fixed, 0 broken); not over early 88.7 -> 91.3 % (13 fixed, 5 broken); untangled 15 fixed, 5 broken; **falls or over early 20 fixed, 5 broken (p 0.002, pass)**; penalties 26 -> 21 | 100 races (seed 48, against `d1_hold_base`): score 35 better, 37 worse (no gain), median 65.2 -> 64.3 m; no fall 88.3 -> 93.0 % (16 fixed, 2 broken); not over early 9 fixed, 8 broken; **falls or over early 18 fixed, 7 broken (p 0.022, pass)**; penalties 22 -> 17 | **Yes by the day's safer-at-no-cost rule** (not by the S3 rule: the score no gain on the hold-out): safer beyond chance on both sets, the score not `WORSE` on either, nothing else `WORSE`. Then **not taken** after its own final check on hold-out 44 (S3-16: the score `WORSE` there) |
| S3-13 | 11 Nov 2026 | The final check of the fast package (S3-10, lag 3) together with the gentler wait (S3-12) on the fresh hold-out 44: `d4_hold44_fast` against `d4_hold44_base` (`frozen_S4d`, every switch off) | - | 100 races (seed 44): **score 125 boards better, 98 worse (p 0.041, pass)**, median 64.5 -> 65.6 m, mean 92.7 -> 84.8; behind the line at the gun 16.8 -> 6.3 m, speed at the gun 5.9 -> 5.5 m/s; no fall 87.0 -> 93.3 % (22 fixed, 3 broken); not over early 16 fixed, 21 broken (ok); falls or over early 33 fixed, 21 broken (p 0.067, chance); **untangled 89.0 -> 81.0 % (4 fixed, 28 broken, `WORSE`)**; no penalty 16 fixed, 15 broken | **No by the S3 rule** (untangled `WORSE`; on hold-out 48 it was near, p 0.059). Boards more than 10 s within 5 m of another 21 -> 37 of 300. Traced (r0011, all three newly tangled, no penalty): the three wait at a crawl near the line in each other's company, holding back, turning away and dipping, keeping clear. The crowding of a start nearer the line; for Max: is it a fault when the penalties stay the same? |
| S3-14 | 11 Nov 2026 | The fast package with the lag at 2 s (`start_go_lag_s` = 2, `early_holds_its_tack`, `start_dip`): "a little more safe". The evening's goes from a crawl were a median 2.7 s late (quartiles 1.7 to 4.5), so with 3 s about half the boards came early and braked at the line. Frozen copy `frozen_S4d` | 100 races (seed 31, against `s3_base`): **score 110 boards better, 73 worse (p 0.004, pass)**, median 71.8 -> 74.5 m, mean 82.3 -> 82.2; behind the line at the gun 16.5 -> 10.1 m, speed at the gun 5.8 -> 6.1 m/s, start median 6.0 -> 3.8 s after the gun; **on time 22 fixed, 11 broken (p 0.040, pass)**; not over early 7 fixed, 7 broken; no fall 3 fixed, 6 broken; untangled 23 fixed, 23 broken; penalties 27 -> 22. Against S3-10 (lag 3) on the same races: score 60 better, 63 worse; over early 4 fixed, 1 broken | 100 races (seed 48, against `d1_hold_base`): **score 114 better, 73 worse (p 0.002, pass)**, median 65.2 -> 65.8 m, mean 70.9 -> 73.7; behind at the gun 15.4 -> 11.6 m; on time 16 fixed, 16 broken; not over early 14 fixed, 17 broken; untangled 14 fixed, 16 broken; falls or over early 12 fixed, 17 broken (chance). Against S3-10: score 45 better, 64 worse (lag 3 scores more here), untangled 15 fixed, 6 broken | **Yes** by the S3 rule (the score passes on both sets, nothing `WORSE`, untangled even on both), to the final check on hold-out 44 (S3-15) |
| S3-15 | 11 Nov 2026 | The final check of S3-14 (lag 2) together with the gentler wait (S3-12) on hold-out 44: `d4_hold44_lag2` against `d4_hold44_base` | - | 100 races (seed 44): score 111 boards better, 89 worse (p 0.069, chance), median 64.5 -> 66.2 m, mean 92.7 -> 87.0; behind the line at the gun 16.8 -> 10.1 m, speed at the gun 5.9 = 5.9 m/s; no fall 22 fixed, 3 broken; not over early 18 fixed, 20 broken; **falls or over early 35 fixed, 20 broken (p 0.029, pass)**; **untangled 89.0 -> 81.3 % (10 fixed, 33 broken, `WORSE`)**. Against S3-13 (lag 3 and the wait) on the same races: score 53 better, 54 worse; untangled 14 fixed, 13 broken; falls or over early 5 fixed, 2 broken | **No** by the S3 rule (the score at chance, untangled `WORSE`) |
| S3-16 | 11 Nov 2026 | The final check of the gentler wait alone (S3-12) on hold-out 44: `d4_hold44_wait2` against `d4_hold44_base` (70 races, the last half hour of the day) | - | 70 races (seed 44): **no fall 86.2 -> 92.4 % (13 fixed, 0 broken)**, falls or over early 13 fixed, 4 broken (p 0.025, pass); **score 20 boards better, 35 worse (`WORSE`)**, median 59.2 -> 52.7 m, mean 86.0 -> 71.0; on time 8 fixed, 16 broken (no gain), start median 6.9 -> 7.7 s after the gun; untangled 1 fixed, 2 broken. Against it on the same races, S3-15 (lag 2 and the wait): score 77 better, 45 worse (pass), untangled 5 fixed, 20 broken (`WORSE`); S3-13 (lag 3 and the wait): 85 better, 53 worse, untangled 1 fixed, 16 broken (`WORSE`) | **No** (the score `WORSE` on 44, so not safer at no cost; the default change made for it was undone). The falls fixed on all three sets (10 / 0, 16 / 2, 13 / 0), but its slalom starts come later. And it splits S3-13 and S3-15: the wait does not tangle the boards, the lag does (on 44; on tune 31 and hold-out 48 lag 2 did not); the score the lag gains is there on 44 too. A unit test showed one such late start: `test_rules_in_race.gd`'s penalty test (one board, t2_slalom, 24 kt) was still reaching down onto the line 15 s after the gun with the wait on |
| S3-17 | 11 Nov 2026 | Max's slalom start, version 3 (`slalom_timed_run`, `frozen_S5c`; the night's block 1, slalom races only, `--kind=slalom`) | 100 races (seed 36, against `n1_sl_base`): **no fall 70.3 -> 96.7 % (84 fixed, 5 broken)**; **score 175 boards better, 113 worse (pass)**, median 87.0 -> 215.8 m, mean 113.0 -> 150.6; behind the line at the gun 20.7 -> 3.2 m; on time 58.0 -> 62.7 % (72 fixed, 58 broken); **not over early 86.7 -> 70.7 % (29 fixed, 77 broken, `WORSE`)**; no penalty 16 fixed, 6 broken | 100 races (seed 49, against `n1_hsl_base`): **no fall 78.7 -> 99.0 % (61 fixed, 0 broken)**; **score 208 better, 78 worse (pass)**, median 47.4 -> 247.2 m, mean 91.5 -> 173.9; behind at the gun 23.4 -> 3.3 m; **on time 53.7 -> 70.7 % (91 fixed, 40 broken, pass)**; **not over early 85.0 -> 73.0 % (31 fixed, 67 broken, `WORSE`)** | **No** (over early `WORSE` on both sets); everything else far better. 127 of the 135 newly over came in early and luffed up at the line; next versions 4, 5 and 5b |
| S3-18 | 12 Nov 2026 | Max's slalom start, version 5b (`slalom_timed_run`; `frozen_S5f`: the gybe's cost 12 s, aims 2 s after the gun, eased far out, full speed for the last 8 s, away from the join only when the run behind the line can use up the time left; the night's block 3, slalom races only) | 100 races (seed 36, against `n1_sl_base`): **score 195 boards better, 95 worse (pass)**, median 87.0 -> 236.2 m, mean 113.0 -> 180.0; **on time 58.0 -> 75.3 % (90 fixed, 38 broken, pass)**; **no fall 70.3 -> 97.7 % (88 fixed, 6 broken)**; not over early 86.7 -> 85.3 % (35 fixed, 39 broken, ok); behind the line at the gun 20.7 -> 5.9 m; untangled 18 fixed, 21 broken; **falls or over early 106 fixed, 40 broken (pass)**. Against version 3 (S3-17): over early 66 fixed, 22 broken; on time 61 fixed, 23 broken; score 147 better, 127 worse | 100 races (seed 49, against `n1_hsl_base`): **score 210 better, 75 worse (pass)**, median 47.4 -> 244.7 m, mean 91.5 -> 196.1; **on time 53.7 -> 80.3 % (109 fixed, 29 broken, pass)**; **no fall 78.7 -> 99.3 % (63 fixed, 1 broken)**; not over early 85.0 -> 88.7 % (37 fixed, 26 broken); behind at the gun 23.4 -> 5.5 m; untangled 22 fixed, 30 broken (ok); **falls or over early 86 fixed, 20 broken (pass)** | **Yes** by the S3 rule (the score passes on both sets, nothing `WORSE`), and safer beyond chance on both; to the final check on fresh hold-out 51 and 52 |
| S3-19 | 12 Nov 2026 | `--start_tacks=1,2,0` (`start_tack`: board 0 starboard, 1 port, 2 either; Max: some start one way, some the other); the night's block 2, course races only (`--kind=course`), `frozen_S5b` | 100 races (seed 37, against `n2_c_base`): score 47 boards better, 46 worse (chance); on time 3 fixed, 5 broken; not over early 3 fixed, 2 broken; untangled 10 fixed, 10 broken; nothing `WORSE` | 100 races (seed 50, against `n2_hc_base`): score 51 better, 49 worse (chance); not over early 4 fixed, 0 broken; untangled 18 fixed, 7 broken; nothing `WORSE` | **Yes as Max's choice** (nothing `WORSE` on either set; no gain either: a mixed fleet starts as well as the old one); to the final check on hold-out 51 |
| S3-20 | 12 Nov 2026 | The lag-2 package (S3-14) on course races only: `start_go_lag_s` 2, `early_holds_its_tack`, `start_dip`; the night's block 3 | 100 races (seed 37, against `n2_c_base`): **score 126 boards better, 54 worse (pass)**, median 65.3 -> 74.2 m; behind the line at the gun 14.7 -> 9.6 m; not over early 12 fixed, 5 broken; **no fall 0 fixed, 5 broken (`WORSE`)**; untangled 12 fixed, 22 broken | 100 races (seed 50, against `n2_hc_base`): **score 137 better, 62 worse (pass)**, median 58.5 -> 66.4 m; **on time 25 fixed, 13 broken (pass)**; not over early 18 fixed, 10 broken; no fall 4 fixed, 1 broken; untangled 12 fixed, 21 broken; **falls or over early 22 fixed, 11 broken (pass)** | **No** by the S3 rule (5 boards newly fell on tune, none fixed); on the hold-out faster and safer. For Max: the falls on tune, to trace |
| S3-21 | 12 Nov 2026 | The lag-2 package (S3-20) with `--start_tacks=1,2,0` (S3-19) on course races only; the night's block 4, `frozen_S5b` | 100 races (seed 37, against `n2_c_base`): **score 130 boards better, 78 worse (pass)**, median 65.3 -> 73.4 m; behind the line at the gun 14.7 -> 9.6 m; not over early 13 fixed, 5 broken; no fall 2 fixed, 4 broken (ok); **untangled 19 fixed, 34 broken (`WORSE`)**; falls or over early 14 fixed, 8 broken (chance). Against the tacks alone (`n2_c_tacks`): score 123 better, 58 worse (pass); untangled 13 fixed, 28 broken (`WORSE`) | 100 races (seed 50, against `n2_hc_base`): **score 147 better, 74 worse (pass)**, median 58.5 -> 66.6 m; **on time 25 fixed, 13 broken (pass)**; not over early 18 fixed, 9 broken; no fall 5 fixed, 5 broken; untangled 23 fixed, 21 broken; falls or over early 23 fixed, 14 broken (chance) | **No** by the S3 rule (more boards tangled on tune); the fall S3-20 saw on tune is gone, and the score gain (some 8 m) holds on both sets in both tries. For Max: lag-2 on course races is faster every time, but each try broke one safety check on tune (falls in S3-20, crowding here); to trace before it goes on |
| S3-22 | 12 Nov 2026 | The final checks of Max's slalom start, version 5b (S3-18; `frozen_S5f`; slalom races only) | - | 125 races (seed 51, `n5_hsl51_run5` against `n4_hsl51_base`): **score 268 boards better, 89 worse (pass)**, median 40.6 -> 243.4 m; **on time 51.2 -> 78.1 % (143 fixed, 42 broken, pass)**; **no fall 72.8 -> 97.9 % (99 fixed, 5 broken)**; not over early 56 fixed, 42 broken; untangled 18 fixed, 27 broken (ok); **falls or over early 125 fixed, 39 broken (pass)**. 160 races (seed 52, `n5_hsl52_run5` against `n5_hsl52_base`): **score 347 better, 108 worse (pass)**, median 80.0 -> 259.6 m; **on time 58.1 -> 82.7 % (157 fixed, 39 broken, pass)**; no fall 88 fixed, 5 broken; not over early 60 fixed, 39 broken; **untangled 94.4 -> 88.8 % (24 fixed, 51 broken, `WORSE`)**; falls or over early 128 fixed, 33 broken (pass) | **Passes on 51, not on 52** (more boards close together; the same way, short of chance, on every set: 82 fixed, 129 broken over all four). Not switched on by me; for Max (the morning report, question 1) |
| S3-23 | 12 Nov 2026 | The final check of `--start_tacks=1,2,0` (S3-19; `frozen_S5b`; course races only) | - | 120 races (seed 51, `n5_hc51_tacks` against `n4_hc51_base`): score 42 boards better, 45 worse (no gain); on time 6 fixed, 7 broken; not over early 1 fixed, 2 broken; no fall 2 fixed, 3 broken; untangled 19 fixed, 7 broken; nothing `WORSE` | **Yes as Max's choice**: the personas get their own tack (`start_tack` in `race/personas/*.tres`: 13 starboard, 4 port, 3 either) |
| S3-24 | 12 Nov 2026 | The dirty-wind measure (`dirty_s`, `wind_lost_s` in `run_race.gd`; `frozen_S6`) and the rule's new check, clean wind for untangled (Max: "it its not wrong if they are close togeter but there is one with dirty wind") | - | The measure does not change the races: the night's arms raced again (`w1_sl_base`, `w1_sl_run5` on tune 36, `w1_hsl_base`, `w1_hsl_run5` on check 49), every board's score the same as the night's. Version 5b against the old start under the new check: tune clean wind 93.3 -> 88.0 % (17 fixed, 33 broken, `WORSE`); check 94.3 -> 84.7 % (15 fixed, 44 broken, `WORSE`): the timed run brings the boards in level, one in another's dirty wind. Most dirty boards were not close (`near_s` 0) | Rule changed; version 5b fails it the same way as before (now on dirty wind, not on close) |
| S3-25 | 12 Nov 2026 | Version 6: `slalom_run_clean_wind` with the timed run (`frozen_S6b`; slalom races only): 20 s to 3 s before it crosses, its spot moved along the line out of the dirty wind of boards coming in | - | Against the old start, tune 36 (`w1_sl_clean` against `w1_sl_base`, 100 races): **score 196 better, 97 worse (pass)**; on time 90 fixed, 36 broken; no fall 88 fixed, 6 broken; clean wind 93.3 -> 91.3 % (19 fixed, 25 broken, ok); nothing `WORSE`. Check 49 (`w1_hsl_clean` against `w1_hsl_base`): **score 201 better, 85 worse (pass)**; on time 107 fixed, 26 broken; no fall 63 fixed, 1 broken; clean wind 94.3 -> 91.7 % (16 fixed, 24 broken, ok); nothing `WORSE`. Against version 5b: clean wind 88.0 -> 91.3 % on tune (21 fixed, 11 broken), 84.7 -> 91.7 % on check (27 fixed, 6 broken); score on tune 72 better, 64 worse (chance), **on check 58 better, 84 worse (`WORSE`, p 0.988)**. Traced: half the boards moved their spot (148 of 300 on check) where 43 had dirty wind; the boards it moved lost 5 to 21 m up the course on average, either way along the line (check r0059/0: its spot 30 m to leeward 2 s before it crossed, gybed away after the gun: 321 -> 31 m). (A first trace had the moves' sides the wrong way round, read from the sign of the gap; the side is the sign times the line's way to leeward, from the log's `COURSE_JSON` and wind) | Passes against the old start; costs score against 5b on check. Its final checks started (seeds 53, 54: `w2_hsl53_clean`, `w2_hsl54_clean` against `w2_hsl53_base`, `w2_hsl54_base`); version 6b made from the trace |
| S3-26 | 12 Nov 2026 | Version 6b (`frozen_S6c`): moves only when its spot would be in dirty wind (under 85 %, not when a board is merely close), only for boards crossing within 2 s of it (level), and only to leeward (never to windward, where it must keep clear by the rules; and no leapfrogging) | - | Against the old start: tune 36 (`w3_sl_clean6b` against `w1_sl_base`, 100 races) **score 197 better, 93 worse (pass)**, on time 89 fixed, 36 broken, no fall 88 fixed, 5 broken, clean wind 93.3 -> 92.3 % (19 fixed, 22 broken), nothing `WORSE`; check 49 (`w3_hsl_clean6b`) **score 208 better, 73 worse (pass)**, on time 109 fixed, 28 broken, **clean wind 94.3 -> 88.3 % (15 fixed, 33 broken, `WORSE`)**. Against 5b: clean wind 14 fixed, 1 broken (tune), 15 fixed, 4 broken (check); score by chance. Against 6: on check score 82 better, 50 worse (pass) but clean wind 8 fixed, 18 broken (`WORSE`): it moved the spots of 38 boards of 300 on check where 6 moved 148, and leaves more dirty wind | Fails on check 49; not taken. Its final checks run anyway to fill the pool (S3-27). Its code reverted (`290b6a3`): the repo holds version 6 |
| S3-27 | 12 Nov 2026 | The final checks of versions 6 and 6b (slalom races only; `frozen_S6b`, `frozen_S6c`) | - | Seed 53 (100 races; `w2_hsl53_clean`, `w3_hsl53_clean6b` against `w2_hsl53_base`): version 6 **score 200 better, 88 worse (pass)**, on time 90 fixed, 36 broken, no fall 65 fixed, 1 broken, **clean wind 94.3 -> 90.3 % (16 fixed, 28 broken, `WORSE`)**; version 6b the same way: score 206 better, 87 worse (pass), **clean wind 94.3 -> 90.3 % (16 fixed, 28 broken, `WORSE`)**. Seed 54 (`w2_hsl54_clean`, `w3_hsl54_clean6b` against `w2_hsl54_base`): version 6 **score 185 better, 105 worse (pass)**, on time 89 fixed, 42 broken, clean wind 14 fixed, 17 broken, nothing `WORSE`; version 6b score 188 better, 97 worse (pass), clean wind 13 fixed, 15 broken, nothing `WORSE`. 6b against 6 on both: by chance. Where the dirty wind left comes from (rebuilt from the tracks, `dirty_when.py` in the day's scratchpad; check 49 and seed 53): about a third on the run in before the gun, a fifth to a third in the first 10 s after it, a third 10 to 30 s after it with both boards on the same heading on the reach | Version 6 passes 3 sets of 4, version 6b 2 of 4; neither switched on by me. For Max: version 6 now as his choice, or version 7 (out of dirty wind on the reach after the gun) first (the day report, question 1) |
| S3-28 | 12 Nov 2026 | The lag-2 package with the start tacks (S3-14, S3-21; `frozen_S6b`; course races only) under the new rule | - | 60 races each (paused at 12:35 for version 6b, resumed 15:21). Tune 37 (`w2_c_lag2tacks` against `w2_c_base`, 59 races both have): **score 71 better, 49 worse (pass)**, median 62.2 -> 67.1 m; on time 7 fixed, 6 broken; not over early 7 fixed, 4 broken; no penalty 9 fixed, 10 broken; clean wind 10 fixed, 14 broken; untangled 13 fixed, 20 broken (info); nothing `WORSE`. Hold-out 50 (`w2_hc_lag2tacks` against `w2_hc_base`): **score 89 better, 46 worse (pass)**, median 57.8 -> 62.2 m; on time 8 fixed, 8 broken; no fall 2 fixed, 3 broken; no penalty 12 fixed, 17 broken; clean wind 11 fixed, 15 broken; nothing `WORSE` | **Passes** (on 60 races a set). Its final check (a fresh seed, 55 or up) waits for Max's go |
| S3-29 | 12 Nov 2026 | Max's choice: version 6b of the slalom start on ("6b is good i think") | - | Version 6b brought back (`git revert 290b6a3`) and switched on: `slalom_timed_run` and `slalom_run_clean_wind` default to true, their tests flipped. Its numbers: S3-26, S3-27 (against the old start: score passes on all four sets, on time and falls far better on all four; clean wind `WORSE` on check 49 and final check 53, 10 to 12 % of boards in dirty wind against 6 %) | **On as Max's choice.** The old start is now the switches off. Dirty wind on the reach after the start goes to race training (Max: "this is for race training and not start training") |

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

**Done 9 November 2026 (evening)**, as listed, with three choices made on the way:
- A start-only race is watched 60 s after the gun (`--start_watch_s=60`), not only to the check's 20 s, so a late start
  says how late it was (never over within 60 s counts as endless in the median). It ends as soon as the board is over.
- In phase S the falls check allows no fall at all from the countdown to the start (phase A allows one per 5 minutes:
  a start is never that long), so a switch that makes the board fall shows in the sign test.
- The R draw: one random number decides R whatever the phase, so phase A's and B's races are drawn exactly as before
  (checked on 2,000 draws each).
The judging measures per race: the start on time, never stuck, never aground, no fall, not over early at the gun.
Smoke run `smoke_S` (seed 900, 16 races, not a phase S seed): 12 on time and clean; it showed the late classes to
expect (over early at the gun at 2 m/s and back 45 s late; 1.7 m/s at the gun 25 m behind and never over in 60 s).

**The loop in phase S** is steps 2 to 7 with these changes: step 1's baseline is `--phase=S`, 200 races on tune seed 11
(`baseline_S`); step 3 takes the biggest class of late starts (by water, course kind, start place, countdown, R; first
the slalom courses and the lake); steps 5 and 6 use new seeds and the judging above.

**The gate to fleets.** On a fresh hold-out of 100 races every start under 20 s. If the last few failures come from
outside the head (the physics, a known lake trap), show them to Max: he decides. Then phase C (fleets: starts in a
crowd), then back to the roundings.

**State after the first phase S loop (9-10 November 2026, one chat, 17:50 to 05:15).** Taken: `crawl_no_head_up_ms`
(S2d) and `crawl_go_stuck_s` 0 with `early_unlatches_go` (S9). On the same races as before (the suite is deterministic):
the baseline's 200 starts 73.0 -> 83.5 % on time (22 fixed, 1 broken), S1's hold-out of 100 69 -> 85 % (16 fixed,
0 broken); the median start 5.4 to 5.7 s after the gun, the speed at the gun up by 0.6 to 1 m/s; on a final fresh hold-out of 200
(seed 29) 81.5 % on time (the log's last row). The gate (100 of 100) is not near. What is left, and why no switch took it:
- **The slalom courses** (about a third of the late starts): the waiting spot upwind of the boat is held at 0.5 to 1 m/s,
  the dive down onto the line cannot slow once gone and takes 1 to 1.7 times its reckoning, the waiting spot lies some
  20 m from the line's extension (boards cross it and turn back behind the line), and T2's start area is in a lee (8 to
  10 kt at the board when the lake's mean is 14 or more). Every change tried (eleven, replays of 43 to 55 slalom starts)
  flipped starts both ways; the best (`slalom_slot_back_m` 20) 8 fixed, 5 broken. It needs a redesign of the slalom
  start (a timing run from a set point at speed, a dive that can slow by its heading), not a switch: for Max.
- **The reaching starts** (PM1, SM1, the line along the wind): the timing loop with a small excess
  (`reaching_loop_excess_s` 5) gives starts 0.5 s after the gun at 7 to 10 m/s on the open water every time, but on the
  lake its loops break starts (the way back from a loop meets shifts, lee, the shore, a beat). For Max: take it with a
  rule for the open water, or wait for a better way back on the lake.
- **The lake's light corners** (far behind at the gun, crawling and falling: the north-east and east shores): the
  physics and the wind map (E01.S21), not the head.
- **Switches that won but were blocked by one broken start** (rule 4, or the sign test at 5-1): S5 (9 fixed, 1 broken),
  S8 (5-1), S2c (5-1), S3 (4-1). Each broken start is traced in the log. Loop 1 to 2's proposal (a check counts as worse
  only when it loses 3 or more races more than it gains, every flip traced) would have taken S5; S9 took its idea safely.

**Open: Max's PWA course.** A play build cannot save a course (its `res://` is inside the pack); when Max saves it
from the course maker in the Godot editor, or describes it (the start line's angle to the wind, the marks and which
side they are rounded), it joins phase S's draw.

## The starts in company (phase S3, from 10 November 2026: Max's order)

Max, 10 November 2026, watching the AI race in the watch mode ("they have improved significantly"): on the lake, on the
sprint slalom PD3, the wind at the start is very light because the start lies in the lake's lull, so a board must be
close to the line. He asked for:
1. **A measure that rewards going over the line as fast as possible**: "this way you have the best start. but in tricky
   situations they have to learn to be risky or safe."
2. **Three boards a race**: "now sometimes in testing they get stuck in eachother", and **dirty wind** from the others.
3. **The wind the AI feels**: "if the ai's do not have info about the current wind and average wind felt in the last
   minute or 2 ... give them that so they can adapt to wind speed in sail."
4. **Still the start, and the 30 s after it**: "the rest is quite ok".
5. **Get the suite ready first; the training runs at night** (Max stopped the first runs at 20:40: "i want to do that in
   the night").

**What was found (10 November 2026).** On the lake the telemetry's `tws_10m_kt`, which the skipper used for its polar's
speeds and angles, the acceleration it reckons with off a hold, and the push, is the lake's MEAN wind of the moment
(`MapWindField`: the mean carries the "where is the wind from" decisions), not the wind where the board is. The sail
feels the local wind (the map's pattern, the lulls, the lee, the other sails' shadows). A start in a lull was timed with
the mean's speed and acceleration, so the board went too late and crossed slow. In the smoke race (PD3, 14:30) the mean
was 18.2 kt and the sails felt 14.5 to 15.8 kt. Also: the polar has no rows below 12 kt (below that it uses the 12 kt
row), and the acceleration law is measured from 12 kt up (0.65 m/s2 at 12 kt and below); if the baseline shows starts
in 8 to 11 kt felt winds failing, measure 8 and 10 kt rows with `tools/push_check.sh` (Measure, don't guess).

**What a race is in phase S3.** Phase S's draw (water, course, wind, countdown, start place, R; start-only, reachable
drops) with three copies of the general head (Hana at her best, `--spread=0 --steady_hands=1 --boards=3`; Max: "we want
the fastest skipper"; the personas come later, phase B), each with its own start spot drawn at random per race
(`--start_spots`: the head's sheet has one spot, 0.5, and all three aimed at the same point; drawn, they sometimes
spread along the line and sometimes want the same place), the rules and the wind shadows on (the race tool's
defaults), each watched to 30 s after the gun (`--start_follow_s=30`). Every board is judged on its own (race r0007's
second board is `r0007/1`), so a race gives three starts.

**The measures, per board** (the race tool's `HEADS_RESULT`, the suite's `start`, the summary):
- **The start's score** (`score_m`): how far up the course it is 30 s after the gun, metres: how much nearer the first
  mark (or gate) than the start line's middle. Late, slow over the line, the far end, dirty air, a tangle, all cost
  metres; over early it must come back, which costs more; not started by then it scores minus its distance from the
  line. This is the measure that rewards the fastest start, and it judges risky against safe: too risky (over early,
  or a dive into a lull) and too safe (late, slow) both lose metres.
- `cross_speed_ms`: its speed when its start counted.
- `near_s`: seconds within 5 m of another board from 30 s before the gun to 30 s after (the boards pass through each
  other, so a tangle shows as time close); "untangled" is 5 s or less. Shown, not judged, from 12 November 2026.
- `dirty_s` (from 12 November 2026): seconds in another board's dirty wind (its sail's wind shadow leaves under 85 %
  of the wind) from 10 s before the gun to the score's 30 s after; "clean wind" is 3 s or less. `wind_lost_s` adds up
  the share of the wind lost each second. Max, 12 November 2026: "it its not wrong if they are close togeter but there
  is one with dirty wind".
- `penalties` (the rules), and phase S's: on time, stuck, aground, no fall, over early at the gun.
- The wind at the gun: `gun_mean_kt` (the race's 10 m mean), `gun_felt_kt`, `gun_felt_60s_kt`, `gun_felt_spread_kt`
  (what its sail felt, FeltWind). The summary prints `felt/mean wind` (the median share: the lulls the starts are in).

**How a switch is judged in phase S3** (phase S's rules, per board):
1. **The start's score**: per board better or worse by more than 5 m; the better must beat the worse by the one-sided
   sign test (under 5 %) on the hold-out (`pass`), and win on the tune set.
2. **Nothing worse by the sign test the other way**: on time, stuck, aground, no fall, over early, no penalty,
   clean wind (`WORSE` in the summary blocks it). Untangled, judged until 12 November 2026, is shown as `(info)`:
   close together is not a fault (Max, above), dirty wind is.
3. **The most worse boards traced** (the summary prints the six; their CSV, a replay when needed). If the switch's own
   action made a start worse, it is not taken, whatever the numbers.

**The switches waiting to be judged** (in `SkipperConfig`, off by default):
- `felt_wind_s` (0 = off): the wind the skipper reckons with is the mean of what its own sail felt over that many
  seconds (`Skipper.wind_kt()`, `FeltWind`), for the polar's speeds and angles, the acceleration and the push, all
  race long. Try 60 first, then 120 or 20 if 60 wins.
- `start_gust_lead` (0 = off): risky or safe. In a wind that varies it goes for the line earlier, by this share of its
  reckoned time to the line for each unit of the felt wind's spread over its mean (last 60 s). Try 1 (on top of
  `felt_wind_s` if that is taken), then 0.5 or 2.

**Speed (measured 10 November 2026).** A three-board lake race runs at about real time on one core (3.5 minutes for a 2
minute countdown and 60 s watched, start-up included): about 55 races an hour per 4 cores, 110 (330 board starts) on 8.
An on/off pair of 100 races a side on 4 cores each takes about 1.8 hours. At 12 jobs (mask 0x55FF, Max's 80 % CPU)
each job runs slower (two share a physical core), about 13 % more races in all (8 November's one-board measure):
about 125 races an hour, four runs of 100 in about 3.2 hours (an estimate: measure it).

**Seeds.** Phase S3 starts at tune seed 31 and hold-out seed 41 (new seeds per loop, as in phase S). A first pair with
three personas instead of the general head (tune seed 31) was started at 20:13 on 10 November and stopped at 20:40
(Max: the night; then "do we not use 3x the general head"): kept as `s3_base_personas_stopped` and
`s3_felt60_personas_stopped`, one race each, not to be resumed.

**The night's plan (10-11 November 2026, until 08:30)**, the efficient loop (a fresh chat; one wake-up per block).
Max, 10 November 2026: "you can use about 80% cpu +-5%. and you are stopping early every day. is there a reson for?.
this round should be done at around 8:30 in the morining."

*The night's rules* (they come before anything else in this document for this night):
- **CPU 80 % ± 5 %**: 12 jobs on the 12 logical processors of mask 0x55FF (8 November: 12 one-board jobs there were 82 %
  CPU). Four runs at once, `--cores=3 --cpu_mask=0x55FF` each. A minute after each block starts, check
  `Get-Counter '\Processor(_Total)\% Processor Time'` (a few samples); under 75 % add a job (`--cores=4` on the next
  block), over 85 % take one off. Never touch sc-tuner (Max's wheel software).
- **No early stop. The pool is never idle until the last block.** Before reading a finished block, start the next one.
  End a turn only with a block running and its `--wait` pending. When the queue below is used up, take the next class
  of bad starts from the baseline (`--classes`, the most worse boards), write a switch for it and test it; with no idea
  that fits the rules, run the switches' other values (below) on new seeds. A run that only confirms is still useful.
- **Aim to be done at 08:30; if not ready, keep going until ready** (Max: "and if not ready for 8:30 keep going till
  ready"). The last block is sized to finish by about 08:15 (measure block 1's speed and size the later blocks to fit);
  then the log of the loops, the morning report for Max (what was taken, the numbers, the most worse boards traced,
  what to look at together), commit locally, nothing pushed. If a block runs late or the final check (block 4) has not
  been done by 08:30, nothing is cut short or skipped: the running block finishes, the final check runs, then the
  report. "Ready" is the whole queue judged, the final check done and the report written.

*Why the loops stopped early before* (9 and 10 November): the queue of planned tests ran out (phase S on 10 November at
05:15, with "no switch-sized idea left the rules could take"), and the chat chose to stop rather than run tests it did
not believe in; and a chat only goes on when something wakes it (a background `--wait`): a turn ended without a run
going stops the night. Both are fixed by the two rules above.

*Step 0*: fetch; branch `ai/starts-fleet-10nov`; nothing else running (`Get-Process Godot*`); the frozen copy is
`.sim_output/suite/frozen_S3/Game` (refresh: `cp -r Game/<part>/. .sim_output/suite/frozen_S3/Game/<part>/` for race
dev windsurfer ui maps/course maps/silvaplana/courses sim config; after a new `class_name`, run
`godot --headless --path .sim_output/suite/frozen_S3/Game --import` once).

*The queue* (each run 100 races; four runs at once; one block about 3 h at 12 jobs, an estimate from 10 November's
speed: measure it in block 1):
1. **Block 1, `felt_wind_s` 60, tune and hold-out together** (21:00 to about 00:00): `s3_base` and `s3_felt60` (tune
   seed 31), `s3_hold_base` and `s3_hold_felt60` (hold-out seed 41):
   `python -I tools/heads/random_suite.py --run=s3_base --count=100 --cores=3 --cpu_mask=0x55FF --seed=31 --set=tune --phase=S3 --project=$PWD/.sim_output/suite/frozen_S3/Game`,
   the others the same with `--run=`, `--seed=41 --set=holdout`, and `--extra="--skipper.felt_wind_s=60"` on the on
   arms. Wait once: `python -I tools/heads/suite_summary.py s3_base s3_felt60 --wait` (then the hold-out pair the
   same, and `--classes` on `s3_base` and `s3_hold_base`: the baseline's classes of bad starts).
2. **Block 2, `start_gust_lead` 1** (about 00:00 to 03:00): on top of `felt_wind_s` 60 if block 1 took it (otherwise
   alone); off and on arms on tune seed 32 and hold-out seed 42 (the off arm is the defaults after block 1).
3. **Block 3, the biggest class of bad starts** (about 03:00 to 06:00): from block 1's baselines (the tangles, the
   slalom's shared waiting spot, the over-early, the lulls): a switch written for it, off by default, tune seed 33 and
   hold-out seed 43. With no switch that fits: `felt_wind_s` 120 and 20, `start_gust_lead` 0.5 and 2 (tune seed 33).
4. **Block 4, the final check** (about 06:00 to 08:15): a fresh hold-out (seed 44), the defaults taken tonight against
   the defaults of the evening (79580d0's: both switches off), 100 a side or what fits by 08:15.
5. Log each block in the log of the loops; take a switch only by the S3 rules above; commit locally; nothing pushed.
   What is left is for Max and the lead to look at together ("then we will improve").

**The night's report (10-11 November 2026, for Max).** Run 20:43 to 08:16, 12 jobs on mask 0x55FF, 79 to 82 % CPU
all night, the pool never idle (each next run chained to start the moment a run finished). 2200 races (6600 board
starts) in six blocks: the suite ran 200 races an hour, twice the estimate, so there was room for two more blocks than
planned. Nothing pushed; committed locally on `ai/starts-fleet-10nov`.

1. **Taken: nothing.** Seven tests (six judged; 0.65 on tune only), by the S3 rules (the start's score must win on
   tune and pass the sign test on the hold-out); none did. The log of the loops has every number (S3-1 to S3-7).

   | Test | Tune: score boards better / worse | Hold-out: better / worse | Also |
   |---|---|---|---|
   | `felt_wind_s` 60 (the wind its sail felt) | 93 / 128 (WORSE) | 111 / 120 | |
   | `start_gust_lead` 1 (earlier in a varying wind) | 76 / 72 | 84 / 69 | |
   | `start_dip` (new: a crawling board early at the line bears away) | 44 / 52 | 56 / 53 | over early on the hold-out 15 fixed / 6 broken, on tune 7 / 10 |
   | `slalom_wait_moving` (new: keeps moving while waiting at the slalom boat) | 27 / 26 | 29 / 38 | **falls 12 fixed / 1 broken and 18 / 0** |
   | `start_accel_share` 0.8 (risky: goes earlier) | 61 / 67 | 56 / 49 | on time on the hold-out 1 fixed / 10 broken |
   | `slalom_wait_moving` gentler (luffed up from 1.5 m/s, at most 70 deg; the last block, 45 and 55 races) | 7 / 15 | 20 / 15 | **falls 4 fixed / 0 broken and 8 / 0**; on the hold-out on time 9 fixed / 3 broken, over early 7 / 4 |
   | `start_accel_share` 0.65 (riskier still; tune only, 45 races) | 35 / 25 (p 0.12) | - | 2.2 m nearer the line at the gun; not judged without a hold-out |

2. **Where the bad starts are** (the ten off arms of the night, 1000 races, 3000 board starts on the evening's defaults):
   on time 76.9 %, over early at the gun 9.1 %, fell before the gun 9.6 %, the start's score median 67.5 m, a median
   15 m behind the line at the gun and 5.7 s late. The lake 72.5 % on time, the open water 87.4 %. **The slalom
   starts** (upwind of the committee boat) are 24 % of the starts but **57 % on time, 15.6 % over early, 26.6 %
   fell**; the other starts 83.2 %, 7.0 % and 4.2 %. Of the 88 falls in the first two baselines, 54 came while waiting
   upwind of the boat, luffed up at 0.2 to 0.4 m/s; of the 169 boards more than 60 m from the line at the gun (no fall,
   not over early) 93 were in the slalom's dive. The wind at the gun is mostly not a lull (felt / mean median 1.0).

3. **The most worse boards traced.** `start_dip`: hold-out 41 r0001 (iq_pm1, a line along the wind): no angle on the
   run-in tack runs away from that line, so the first version did nothing; with a tack away added, board 1 was no longer
   over (-32 -> +18 m). `slalom_wait_moving`: hold-out 45 r0016/0: waiting at 1.6 m/s instead of 0.5 it went for the
   line from 50 m elsewhere, 3.5 s later, and was at the line 1 s early: the dive's timing (phase S measured the dive at
   1.44 to 1.73 times the skipper's reckoning), not the wait itself.

4. **To look at together.**
   1. The slalom start's redesign (open since 10 November): it is where most bad starts are. The night showed the
      falls can be fixed (keep the board moving while waiting: 30 fixed, 1 broken at the first try; 12 fixed, 0 broken
      at the gentler try), and the gentler wait did not bring the boards early on its hold-out (over early 7 fixed,
      4 broken; on time 9 fixed, 3 broken), but neither try won the start's score. Next: the gentler wait together
      with the dive's timing (the dive takes 1.44 to 1.73 times the skipper's reckoning).
   2. A rule: may a switch be taken that fixes a check beyond chance (falls) while the start's score stays at chance?
      `slalom_wait_moving` is that case (and `start_dip` nearly, for over early on one set).
   3. `felt_wind_s`: off (worse on tune). The starts are mostly not in lulls at the gun, so the lake's mean wind was not
      what made them late.
   4. Risky or safe: `start_accel_share` 0.8 did nothing; 0.65 was the first value that moved the boards nearer the
      line at the gun (2.2 m) and leaned better on tune (35 / 25, chance). Worth a tune and hold-out pair next night?
   5. The final check (block 4) was not run: nothing was taken, and the suite is deterministic, so tonight's defaults
      against the evening's would have raced the same code to the same result. Its time went to blocks A, B and the last block (C).

5. **Housekeeping.** Frozen copies `frozen_S3` (the evening's code), `frozen_S3b` (+ `start_dip`), `frozen_S3c`
   (+ `slalom_wait_moving`), `frozen_S3d` (+ its two settings); all switches off by default, so each copy's defaults
   race the evening's code. Runs: `s3_*`, `s3b2_*`, `s3b3_*`, `s3bA_*`, `s3bB_*`, `s3bC_*` (seeds used: tune 31 to
   35, hold-out 41 to 43 and 45 to 47; 44 kept fresh for a final check); smoke and replays `smoke_dip_hold41*`,
   `replays/`. A slip at 20:40: `random_suite.py --help` started a default run (the tool has no help option); stopped
   after two minutes and kept as `void_help_accident_10Nov_2040`. Unit tests 1056/1056.

**The day's run (11 November 2026, 10:00 to 19:00).** Max, the morning after the night's report: "going to school
so try to fix it. going a little more safe but fast over the startline is better in real life. try again and see you
around 19:00". The same loop as the night (12 jobs on mask 0x55FF, about 80 % CPU, the pool never idle), on the
frozen copies `frozen_S4` (+ `start_go_lag_s`) and `frozen_S4b` (+ `slalom_dive_time_share`); all switches off by
default, so each copy's defaults race the evening's code (checked: `d1_det31`, 12 races of tune seed 31, against
`s3_base`: every board the same).

*How the message is read (the day's rule; Max may overrule it at 19:00).* Max's answer to the report's question
"risky or safe" is "a little more safe", and the start should cross the line fast. So a switch is taken by the S3
rules above (the start's score wins on tune and passes the sign test on the hold-out), **or** when it is safer at no
cost: the start's score not `WORSE` on either set (the sign test the other way), falls and over early together fewer
beyond chance on the hold-out (`pass`) and not worse on tune, and nothing else `WORSE`. The second way is this chat's
reading of "a little more safe"; each switch taken by it says so in the log of the loops.

*What was measured first* (the night's ten off arms, the board CSVs: at the moment a board went, the time it reckoned
it needed, the gun's time left less its spare in the note, against the time it took to cross):
- **Starts from a hold** (1661): taken / reckoned a median 1.40 (quartiles 1.18 to 1.89). By the speed it went at:
  1 to 3 m/s a median 2.8 to 3.7 s late (the lake from 1 to 2 m/s 7.5 s), 3 to 5 m/s 1.9 s, from 5 m/s up on time
  (0.1 s). A board held back at a crawl must bear away from its hold, sheet in and gain speed, and the reckoning
  (the open water's acceleration from 2.5 m/s, no time for the turn) leaves part of that out.
- **Slalom dives** (413): a median 1.84 times the reckoning; dives not held back early: the open water 1.18 to 1.35,
  the lake 1.56 to 1.87 (its slalom start lies in a lull). In 24 kt on the open water the broad reach down was sailed
  at 7 to 8 m/s where the reckoning counted 11 to 12. 398 of the 724 slalom boards went straight from "to its spot"
  (drifted more than 20 m from the spot while waiting luffed up, and sailing back to it when it was time).

*The switches* (in `SkipperConfig`, off by default; unit tests in `test_skipper_go_lag.gd` and
`test_skipper_slalom_wait.gd`):
- `start_go_lag_s` (0 = off): the lag added to the time it reckons it needs to cross from a hold, the whole of it at
  2 m/s and slower, none from 5 m/s up (`Skipper._go_lag_s()`). Try 3 (a little under the median: the safe side).
- `slalom_dive_time_share` (1 = off): the slalom dive's reckoned time stretched by this share. Try 1.4 (a little
  under the median), with the gentler wait (`slalom_wait_moving`, luffed up from 1.5 m/s, at most 70 degrees: the
  night's falls 12 fixed, 0 broken) as one package, and alone.

*The queue* (each run 100 races, 3 cores; the tune sets reuse the night's off arms, which the suite's determinism
allows; the hold-out is fresh, seed 48, because the lag and the share were measured on the night's hold-out sets):
1. Block 1 (10:00 to about 12:15): `d1_lag3` (tune 31, against `s3_base`), `d1_hold_base` and `d1_hold_lag3`
   (hold-out 48), `d1_det31` then `d1_hold_wait2` (the gentler wait alone on hold-out 48).
2. Block 2 (about 12:15 to 14:30): `d2_slalom` (tune 32, the package, against `s3b2_base`), `d2_hold_slalom`
   (hold-out 48), `d2_lag3_t32` (tune 32), `d2_hold_dive14` (the share alone, hold-out 48).
3. Block 3 (about 14:30 to 16:45): what block 1 and 2 leave open (another value, or the two together).
4. Block 4, the final check (to about 18:30): the day's defaults against the evening's on the fresh hold-out 44.
5. The log, the report for Max, commit locally, nothing pushed.

*After block 1 (12:05; the queue as changed).* `start_go_lag_s` 3 was not taken (S3-8: over early `WORSE` on both
sets). What the boards newly over early were doing just before they went over (`over_how.py`, the night's twelve off
arms for comparison: 320 of 3465 boards over early, 121 creeping over holding back hard, 115 on a slalom's dive, 14
turning onto the way in): with the lag the creep (3.5 % of boards) and the dives (3.3 %) stayed as they were, and the
turn onto the way in's tack, a few metres from the line at 5 to 7 m/s in the last seconds, went from 0.4 % to 1.5 %.
And the night's clean starts from a hold, by what happened after the go (`go_grid.py`, `go_turn_when.py`): of 1710,
**615 tacked or gybed on the way** ("the line is on the other tack") and crossed a median 8 to 10 s later than they
reckoned, the straight goes 1.5 to 3 s (from a crawl) or on time (from 5 m/s up). 446 of those found it a median 9 s
after going: the point it made for was reachable at the angle it points once it has speed, but from a crawl the board
sails wider until it has speed and sagged below it (its track ran a median 34 degrees off its aim in the first 6 s;
the straight goes 13). Two new switches (off by default; `test_skipper_cross_room.gd`, `test_skipper_early_holds.gd`):
- `start_cross_room_deg` (0 = off): of the points of the line it can reach on its tack, it makes for one at least this
  much further off the wind than its beat's track when there is one, else as before (never a new tack). Try 15.
  Frozen copy `frozen_S4c`; smoke `smoke_room15_t31` (3 races of tune 31): 4 starts changed, none over early.
- `early_holds_its_tack`: early at the line on the other tack than its way in's, it holds back hard on the tack it is on
  instead of turning. Replays of 4 races of `d1_hold_lag3` with it: 4 of the 5 boards over early no longer over
  (r0030/0 -5 -> 75 m, r0030/2 -13 -> 96, r0037/1 -32 -> 79, r0065/1 no longer over), r0064/1 still over, the other
  boards the same or within 3 m. Frozen copy `frozen_S4d` (both switches).
The pair `d2_lag3_t32` and the lag with `start_dip` (`d2_hold_lagdip`, `d2_lagdip`) were stopped minutes in and kept
as `void_replaced_11Nov_*`; in their place **the fast and safe package** (the lag for the speed at the line, the hold on
its tack and the dip for the safety): `d2_fast` (tune 31) and `d2_hold_fast` (hold-out 48), `start_go_lag_s` 3 with
`early_holds_its_tack` and `start_dip`. Block 3 chained: `d3_room15` (tune 31) and `d3_hold_room15` (hold-out 48)
after the slalom pair; `d3_wait2_t32` (the gentler wait alone on tune 32: on hold-out 48, `d1_hold_wait2`, falls or
over early 18 boards fixed, 7 broken, p 0.022, the score 35 better, 37 worse: the day's safer-at-no-cost case if tune
agrees) after `d2_fast`; `d3_hold_dive14` (the dive's share alone) after `d2_hold_fast`. The day's safer-at-no-cost
measure is `safe_test.py` (per board: no fall and not over early at the gun; fixed against broken, the sign test).

*After blocks 2 and 3 (16:10; the queue as changed).* The slalom package was not taken (S3-9: against the gentler wait
alone the dive's share brought 14 boards newly over early against the wait's 8), so the share alone (`d3_hold_dive14`)
was not run; its slot went to the final check's off arm, `d4_hold44_base` (`frozen_S4d`, every switch off, hold-out 44).
**The fast package was taken by the S3 rule** (S3-10: the score passed on both sets, nothing `WORSE`), but it is fast,
not safer: falls and over early together at chance against the evening. Why: the lag of 3 s is about the median of how
late the evening's goes from a crawl were (reckoned 6 to 12 s: 2.7 s late, quartiles 1.7 to 4.5; reckoned under 6 s:
2.4, quartiles 0.6 to 4.4), so about half the boards come to the line early and must brake there, where a few creep
over. A lag of 2 s is "a little more safe": the package with it, `d4_lag2` (tune 31) and `d4_hold_lag2` (hold-out 48),
judged against the same off arms and against S3-10 on the same races. `start_cross_room_deg` 15 was not taken (S3-11).
The gentler wait on tune 32 (`d3_wait2_t32`, 86 of 100 races at 16:08): falls or over early 16 fixed, 4 broken
(p 0.006), the score 30 boards better, 20 worse (chance); with hold-out 48's 18 fixed, 7 broken it is taken by the
day's safer-at-no-cost rule, if its last races agree. **The final check** on hold-out 44 (6 cores each, the tool
`chain.py` now waits for several runs): `d4_hold44_fast`, the fast package and the gentler wait, against
`d4_hold44_base`, from about 16:30; then `d4_hold44_lag2`, the same with the lag at 2, so that whichever lag tune 31 and
hold-out 48 pick has its check on 44 too. The lag is chosen on tune and hold-out 48, not on 44.

**The day's report (11 November 2026, 19:00).** 12 jobs at about 80 % CPU from 10:00 to 18:47, the pool never idle;
1,682 races (5,046 board starts) in 18 runs, besides the smoke race, the replays and the 7 void runs (14 races). Nothing pushed; committed locally on `ai/starts-fleet-10nov`.

1. **Taken: nothing.** Every switch stays off, so the game's skippers start as they did last evening. Two came close,
   and each stopped at the last check:

   | Test (log) | Tune: score better / worse | Hold-out 48 | Final check, hold-out 44 | Why not |
   |---|---|---|---|---|
   | Lag 3 alone (S3-8) | 90 / 66 | 75 / 48 | - | over early `WORSE` on both sets |
   | Slalom package: gentler wait + dive share 1.4 (S3-9) | 35 / 28 | 38 / 43 | - | not safer beyond chance |
   | **Fast package, lag 3** (S3-10, S3-13) | **123 / 81** | **125 / 73** | **125 / 98** (with the wait) | boards tangled `WORSE` on 44 |
   | Room 15 at the crossing (S3-11) | 34 / 81 | 37 / 69 | - | score `WORSE` on both sets |
   | Gentler slalom wait alone (S3-12, S3-16) | 34 / 28 | 35 / 37 | 20 / 35 | score `WORSE` on 44 |
   | **Fast package, lag 2** (S3-14, S3-15) | **110 / 73** | **114 / 73** | 111 / 89 (with the wait) | tangled `WORSE` on 44 |

2. **The best candidate: the fast package with the lag at 2 s** (`start_go_lag_s` 2, `early_holds_its_tack`,
   `start_dip`). What it does: a board waiting at a crawl goes for the line about 2 s earlier than it reckons it needs
   (getting going from a crawl takes longer than the skipper thought: measured, a median 2.7 s); if it is early at the
   line it holds back on the tack it is on instead of turning at speed; if it is crawling early at the line it bears
   away from it. On tune 31 and hold-out 48: the start's score better beyond chance on both, the boards 10 to 12 m behind the
   line at the gun instead of 15 to 16, on time more often on tune (22 fixed, 11 broken), not more over early, not more falls,
   not more tangled. Lag 3 is faster still (5 to 6 m behind the line) but about half its boards come to the line early and
   must brake there; lag 2 is the "a little more safe" one. On the final set 44 both lags tangled the boards: 33
   boards newly spent more than 5 s within 5 m of another board (10 fixed), with no more penalties. A start nearer the
   line is a more crowded one; the rule counts that as worse.

3. **The slalom wait**: keeping the board moving while it waits upwind of the committee boat fixed falls on every set
   (10 fixed / 0 broken, 16 / 2, 13 / 0), but those starts come later, and on the final set the start's score was
   `WORSE` (20 better, 35 worse). It is not "safe at no cost" yet. The slalom start still needs its redesign: the
   wait and the dive's timing together (the dive share tried today brought boards over early).

4. **Learned.** The night's biggest cause of late starts (a third of the starts from a hold tack or gybe after going
   and cross about 10 s late) is not the board sagging below its crossing: aiming with 15 degrees of room did not
   change how often they tacked (54 -> 61, 66 -> 66). Still open. The most worse boards of every test were traced; the
   numbers are in the log of the loops (S3-8 to S3-16).

5. **Questions for Max.**
   1. Boards within 5 m of each other for more than 5 s around the start (the check "untangled"): is that a fault when
      the penalties do not go up? If not, the fast package with lag 2 is the one to take; its own final check (without
      the slalom wait) is one more hour of runs on a fresh hold-out seed, on your go.
   2. The slalom wait: fewer falls but later starts. Is upright and a little late the better start in real life?
   3. A play folder only on your message.

6. **Housekeeping.** Frozen copies `frozen_S4` (+ `start_go_lag_s`), `frozen_S4b` (+ `slalom_dive_time_share`),
   `frozen_S4c` (+ `start_cross_room_deg`), `frozen_S4d` (+ `early_holds_its_tack`; the code as committed today); every
   switch off by default. Runs `d1_*` to `d4_*`; seeds: tune 31 and 32 (the night's off arms reused), hold-out 48 and 44
   (both used now: a next final check needs a fresh seed, 49 or up). Slips, all kept: block 1 was first started on the
   evening's frozen copy (`frozen_S3`), which lacks the lag, stopped and renamed `void_wrong_copy_11Nov_*`; three runs
   replaced by better ones minutes in, `void_replaced_11Nov_*`. The gentler wait was made the default at about 17:40 while
   its final check ran, and undone at 18:48 when the check failed (the diff kept outside the repo). The analysis tools
   are in `tools/heads/s3_analysis/` (README there).

**The night of 11-12 November 2026 (Max's go at 20:10: "do the ai training till tomorrow morning 8 o clock").** After
the day's report Max described the real starts: "in a real slalom start ... we take the same direction as mark one, jibe
or tack depending on the position of the line you want to start, then cross the line at a time (different depending on
the room behind the starting line), and if that is for example 100 s, we know that at around 50 s if we go back at the
same speed we get a perfect start. But we have to gybe, so that will take some time, so we add 5 s, because the last part
of the reach toward the line [has] to be full speed. In a real course race start there are many different strategies, but
the most common is on starboard, where we have right of way: sail just under the line and steer up at 0 s." His answers:
(1) the slalom start his way; (2) the course starts are quite good, but the skippers should choose starboard or port, so
that some start one way and some the other; (3) reuse the lag parts. Built (all off by default; frozen copy `frozen_S5b`):
- `slalom_timed_run` (`Skipper._slalom_run_heading()`, `test_skipper_slalom_run.gd`): no more waiting upwind of the
  committee boat. The run lies on the reach toward mark 1 through its spot; away from the line on the reciprocal, a gybe
  when the time left is the way back at the speed it sailed out (scaled by the polar's two reaches) plus
  `slalom_run_turn_s` (15.5 s: the game's gybe from 10 m/s, held back to 5 m/s through it as the course loop is), then
  back at full speed. T2's sailing area leaves only some 80 m behind the line, so with time for a loop it sails on
  through the line onto the course side (no fault before the gun), gybes 80 m beyond and comes back through its spot;
  with less time it eases on the way in, the last 30 m at full speed. Smoke (T2, 18 kt, 120 s): out, two loops, the
  last gybe at the far end, crossed 0.7 s after the gun at 9 m/s.
- `start_tack` (`SkipperConfig.StartTack`: `EITHER` as before, `STARBOARD`, `PORT`; also on the personas;
  `test_skipper_start_tack.gd`) and the race tool's `--start_tacks=a,b,c` (each board its own).
- The suite's `--kind=slalom|course`: only that kind of race (a race of the other kind is drawn again), so each start
  is judged on its own races.

How they are judged: by the S3 rule; and, because Max chose them, also taken when nothing is `WORSE` on either set
(the score and every check, by the sign test the other way), said so in the log. The plan (100 races a run, 3 cores, 12
jobs on 0x55FF, each block chained so the pool never idles; fresh seeds: tune 36 slalom, 37 course; hold-out 49 slalom,
50 course; 51 kept for the final checks):
1. `n1_sl_base` / `n1_sl_run` (tune 36) and `n1_hsl_base` / `n1_hsl_run` (hold-out 49): the slalom run.
2. `n2_c_base` / `n2_c_tacks` (tune 37) and `n2_hc_base` / `n2_hc_tacks` (hold-out 50): `--start_tacks=1,2,0`.
3. `n3_c_lag2`, `n3_c_lag2tacks` (tune 37), `n3_hc_lag2`, `n3_hc_lag2tacks` (hold-out 50): the lag-2 package (S3-14)
   alone and with the tacks, against block 2's off arms.
4. Chosen after block 1 (the slalom run's gybe cost from what the boards did, or more races).
5. The final checks on hold-out 51 of what is taken, against the off arm on the same races; to 08:00.

*Block 1 and the versions (20:20 to 23:50).* The first version (v2, `frozen_S5b`) was stopped 23 minutes in and kept as
`void_replaced_11Nov_n1_*_v2`: its smoke (8 slalom races of tune 32, `s3b2_base`, 24 boards) had 9 boards over early
against 5. Version 3 (`frozen_S5c`: eased out when the far end comes before its gybe is due; the course side's gybe
timed) raced block 1 (`n1_sl_run3`, `n1_hsl_run3`), logged as S3-17: the falls nearly gone, the score far better, and
over early `WORSE` on both sets. What the newly over boards did (`over_how.py`): 127 of 135 came in "early: luffing up";
those over at the gun were luffing a median 22 to 26 s before it (they came in with too much time for easing and too
little for another loop), those not over a median 6 s (2.5 s before they would cross: so the timed last gybe came some
3.5 s early, and the gybe's cost is some 12 s, not 15.5). Max then (23:10): early, slow down 10 to 20 s before and
accelerate in the last 10 s; "i prefer 3 seconds late at full speed than 0.2 sec but at half speed"; the basics first.
The versions, smoked on the same 24 boards (boards that fell / over early / the score better and worse than the old
start's; the old start: 7 fell, 5 over):

| Version | Frozen copy | What changed | Fell | Over early | Better / worse |
|---|---|---|---|---|---|
| v2 | `frozen_S5b` | the run with the loop through the line | 0 | 9 | - |
| v3 | `frozen_S5c` | eased out; the course side's gybe timed | 1 | 5 | 17 / 7 |
| v4 | `frozen_S5d` | the gybe's cost 12 s; a shorter loop (legs of 4 s); eased down to 3 m/s, the last 30 m at full speed | 0 | 3 | 17 / 5 |
| v5 | `frozen_S5e` | Max's: aims 2 s after the gun (`slalom_run_aim_late_s`); full speed for the last 8 s | 0 | 4 | 18 / 6 |
| v5b | `frozen_S5f` | away from the join only when the run behind the line can use up the time left | 0 | 3 | 17 / 6 |

v5b fixed the one unit test v5 failed (one board on T2 in 18 kt: with 90 s left and 80 m of room it eased out at 3 m/s
for 30 s, still came to the far end early, and crept over). Block 3's two slalom slots race v5b (`n3_sl_run5`,
`n3_hsl_run5`, against block 1's off arms); the lag-2 package with the tacks moved to block 4 (`n4_c_lag2tacks`,
`n4_hc_lag2tacks`), with the final checks' off arms on hold-out 51 (`n4_hsl51_base`, `n4_hc51_base`).


*The morning report (12 November 2026, 08:20).* The pool ran at about 80 % from 20:20 to 08:05, never idle (the
last 50 minutes were extra races on the final checks).

1. **In one line.** Max's slalom start is far better: boards are some 250 m up the course 30 s after the gun instead
   of 40 to 80 m, three in four are on time instead of one in two, and the falls are nearly gone. One thing got worse:
   boards end up close together a little more often. By our rule that keeps it from being switched on by me, so it
   waits for Max's yes (question 1). The start tacks are in: each persona now starts a course race on its own tack.

2. **The slalom start, version 5b.** Old start -> new start, on four sets of races. *Tune*: the races I was allowed
   to adjust the start on. *Check*: fresh races I never adjusted on, to see that it holds. Close together: boards
   within 5 m of each other for more than 5 s around the start.

   | Races | How many | On time | Fell | Over early | Metres up the course 30 s after the gun | Close together |
   |---|---|---|---|---|---|---|
   | Tune (seed 36) | 100 | 58 -> 75 % | 30 -> 2 % | 13 -> 15 % | 87 -> 236 | 7 -> 8 % |
   | Check (seed 49) | 100 | 54 -> 80 % | 21 -> 1 % | 15 -> 11 % | 47 -> 245 | 9 -> 11 % |
   | Final check (seed 51) | 125 | 51 -> 78 % | 27 -> 2 % | 18 -> 14 % | 41 -> 243 | 5 -> 8 % |
   | Final check (seed 52) | 160 | 58 -> 83 % | 19 -> 2 % | 14 -> 10 % | 80 -> 260 | 6 -> 11 % |

   On time, fell and metres are better beyond chance on every set; over early is no worse anywhere; penalties did not
   go up. Close together got worse on every set, and beyond chance on the last (24 boards fixed, 51 broken). A likely
   cause, not measured yet: the suite races three copies of Hana, all aiming at the middle of the line at the same
   second; the old start spread them by luck, the timed run brings all three in together at full speed. Max's point 4
   (spread them along the line) would be the fix.

3. **The course start: starboard or port.** Tested with a third of the boards on each tack and a third choosing:
   nothing better or worse beyond chance on all three sets (tune 37, check 50, final check 51 with 120 races);
   close together was a little better on the final check (19 fixed, 7 broken). Taken as Max's choice. The personas
   now: 13 start on starboard; 4 on port (the bold ones: Marco, Tomas, Lena, Yusuf); 3 choose by where they are on
   the line (Hana, Mara, Pavel; Hana keeps the suite's races as they were). That split is mine and not tested as such
   (question 2).

4. **Lag-2 on course races (Max's question 3, the parts of lag 1-2-3).** Faster every time: some 8 m further up the
   course 30 s after the gun, on both sets in both tries. But each try broke one safety check on the tune races:
   5 boards newly fell (S3-20), then more boards close together (S3-21). Not taken; the boards that broke are the
   thing to trace.

5. **Questions for Max.**
   1. The slalom start: switch it on now, with boards close together about 1 in 9 instead of 1 in 18? Or first spread
      the boards along the line (a day's work and one night of checks)? My advice: switch it on now. The gain is large,
      penalties did not go up, and you said close quarters need not be policed much yet. Then do the spread next. The
      change is one line plus its test; with it on, all 1072 unit tests pass.
   2. The tack split, 13 starboard, 4 port and 3 choosing: right for now?
   3. Lag-2: trace its falls and crowding next, or park it?
   4. A play folder only on your message.

6. **Housekeeping.** Frozen copies `frozen_S5` to `frozen_S5f` (see block 1's table; `frozen_S5f` is the code as
   committed). Runs `n1_*` to `n5_*`; the final checks' runs were resumed to more races in the morning, with the same
   races numbered on. Seeds now used: tune 31 to 37, hold-out 41 to 52; a next check needs 53 or up. Slips, all kept:
   version 2 was stopped 23 minutes in (`void_replaced_11Nov_n1_*_v2`); commit `0beb62b` went in with one unit test
   failing (the command chain did not check the test's exit code), fixed an hour later by `401e547`; at 05:10 two
   waiting fill chains were stopped and re-timed before they had started anything. The patch that switches the slalom
   start on is saved (`.sim_output/suite/slalom_on_12nov.patch`: `slalom_timed_run = true` and its test; `git apply` it).

*The day report (12 November 2026, 18:00).* Max's order at 08:30: "train again and fix that they are to close to
getter. it its not wrong if they are close togeter but there is one with dirty wind".

1. **In one line.** The suite now measures dirty wind and judges it instead of "close together". I taught the
   slalom start to aim for clean wind: a third to a half less dirty wind than last night's version, with all its gains
   kept. It is not yet as clean as the old, slow start, which spread the boards out by being late. Most of the
   dirty wind that is left comes after the gun, on the reach, where the start code does not reach.

2. **What changed in the judging.** Each board's seconds in another board's dirty wind (its sail's shadow leaves under
   85 % of the wind), from 10 s before the gun to 30 s after, are now measured. A board with more than 3 s is "dirty".
   This check replaces "close together", which is still shown but no longer judged. Adding the measure changes no race:
   last night's races, run again, gave the same scores.

3. **The slalom start, four versions.** *Old start*: the start in the game now. *5b*: Max's timed run, last night's
   version. *6*: 5b, plus each board moves its aim along the line out of a board coming in that would shade it.
   *6b*: 6, but it moves only when the board would really be in dirty wind, only for boards that cross at the same
   moment, and only to leeward. *Tune*: races I may adjust on. *Check* and *final check*: fresh races, never adjusted on.

   | Races (100 each) | Version | On time | Fell | Over early | Metres up the course 30 s after the gun | Close together | Dirty wind |
   |---|---|---|---|---|---|---|---|
   | Tune (seed 36) | old start | 58 % | 30 % | 13 % | 87 | 7 % | 7 % |
   | | 5b | 75 % | 2 % | 15 % | 236 | 8 % | 12 % (worse) |
   | | 6 | 76 % | 2 % | 14 % | 243 | 8 % | 9 % |
   | | 6b | 76 % | 2 % | 14 % | 240 | 8 % | 8 % |
   | Check (seed 49) | old start | 54 % | 21 % | 15 % | 47 | 9 % | 6 % |
   | | 5b | 80 % | 1 % | 11 % | 245 | 11 % | 15 % (worse) |
   | | 6 | 81 % | 1 % | 12 % | 244 | 8 % | 8 % |
   | | 6b | 81 % | 1 % | 11 % | 243 | 10 % | 12 % (worse) |
   | Final check (seed 53) | old start | 60 % | 22 % | 15 % | 74 | 7 % | 6 % |
   | | 6 | 78 % | 1 % | 16 % | 233 | 6 % | 10 % (worse) |
   | | 6b | 79 % | 1 % | 16 % | 235 | 8 % | 10 % (worse) |
   | Final check (seed 54) | old start | 60 % | 28 % | 14 % | 82 | 7 % | 5 % |
   | | 6 | 76 % | 4 % | 14 % | 243 | 3 % | 6 % |
   | | 6b | 78 % | 3 % | 13 % | 247 | 6 % | 5 % |

   "(worse)": more boards in dirty wind than with the old start, beyond chance. That blocks a version by our rule.
   Every version is far better than the old start on on time, falls and metres, on every set. Penalties did not go up.
   Version 6 passes three sets of four and fails the final check on seed 53 by a small margin (16 boards fixed, 28
   broken). Version 6b fails two (check 49 and seed 53): it moves fewer boards, so it scores a little better than 6 on
   the check set (82 boards better, 50 worse) but leaves more dirty wind. Neither passes everywhere, so I have not
   switched either one on. Version 6 is the better of the two.

4. **Where the dirty wind that is left comes from.** Rebuilt from the boards' tracks, the seconds in another board's
   shadow split roughly into thirds: on the run in before the gun, the first 10 s after it, and 10 to 30 s after it,
   both boards on the same heading on the reach. The start code works only up to the line, so the last third needs the
   reach itself to change: a board in another's dirty wind on the reach should bear away to clear its wind, or the
   faster board should sail through. That is version 7, a day's work and a night of checks.

5. **Course races: lag 2 again, under the new rule.** The lag start (`start_go_lag_s` 2, built on 11 November from
   your "a little more safe but fast"; tried at 1, 2 and 3 s) with the start tacks, 60 races on each set. Tune (seed 37): 71 boards better, 49 worse (better beyond chance), about 5 m
   further up the course, nothing worse. Check (seed 50): 89 better, 46 worse (better beyond chance), about 4 m
   further, nothing worse.
   Last night it was blocked twice: once on falls, once on "close together". Close together no longer counts, and dirty
   wind did not get worse beyond chance (tune 10 boards fixed, 14 broken; check 11 fixed, 15 broken). It passes now.
   What is left is its final check, on a fresh seed (an hour or two of runs).

6. **Questions for Max.**
   1. The slalom start: switch on version 6 now? Boards are on time 76 to 81 % instead of 54 to 60 %, falls go from about
      1 in 4 to about 1 in 50, and boards are 160 to 200 m further up the course. In exchange, dirty wind is about 1
      board in 12 instead of 1 in 17. Or wait for version 7 (the reach), with a night of checks? My advice: switch on version 6 now
      and build version 7 next. The gain is very large, and there is a third to a half less dirty wind than last night's version had.
   2. Version 7, getting out of dirty wind on the reach after the start: build it next, and check it in a night run on
      your go?
   3. Lag 2 on course races passes now: run its final check (seed 55, one to two hours), and switch it on if that
      passes?
   4. A play folder only on your message.

7. **Housekeeping.** Frozen copies: `frozen_S6` (the dirty-wind measure), `frozen_S6b` (version 6), `frozen_S6c`
   (version 6b). Runs `w1_*` to `w3_*`. Seeds now used: tune 31 to 37, hold-out 41 to 54; a next check needs 55 or up.
   Commits (local, not pushed): `8e9d421` (the measure, the new check, version 6), `16647ac` (version 6b), `ae4f96b`
   (a correction to its comments), `290b6a3` (version 6b reverted: the code is version 6 again, the same as at
   `8e9d421`, where all 1080 unit tests passed), and this report. Your yes to question 1 is one patch:
   `.sim_output/suite/slalom_v6_on_12nov.patch` switches on the timed run and clean wind, with their two tests. Slips, all kept: at 12:35 I paused the four course runs to make
   room for version 6b, and resumed them at 15:21 (one race of `w2_c_base`, r0020, was lost to the pause, and r0021 is
   in it twice, which is harmless). From 15:07 to 15:22 the pool ran below 80 %: my wait reported only when the last
   of six runs had finished. All runs ended at 17:25, and nothing has run since, as the day ended at 18:00. My first
   trace of version 6 read the sides of the moves the wrong way round. It is
   corrected in the log (S3-25) and in commit `ae4f96b`.

*Max's answers (12 November 2026, evening).* "6b is good i think. so its 4 times better? 1. 6b 2. this is for race
training and not start training 3. what is lag?"
1. **Version 6b is switched on** as Max's choice (S3-29): `slalom_timed_run` and `slalom_run_clean_wind` default to
   true. "4 times better": 30 s after the gun the boards are 3 to 5 times as far up the course as with the old start
   (median 240 m against 47 to 87 m), on time 78 % against 58 %, falls 2 % against 25 %; dirty wind 9 % of boards
   against the old start's 6 % (last night's version 14 %, on the two sets it ran). The four sets' averages.
2. **Dirty wind on the reach after the start belongs to race training, not start training.** Version 7 (out of dirty
   wind on the reach) waits for the race phase (phase B and on).
3. **Lag** (`start_go_lag_s`): a board waiting near the line at walking pace reckons the seconds it needs to reach
   the line, but getting going from slow takes longer than it reckons (measured: about 3 s more from 1 to 3 m/s).
   Lag 2 adds 2 s to its reckoning, so it pulls in 2 s earlier and crosses nearer the gun at speed. The package adds
   two safety parts: a board early at the line on the other tack holds back on the tack it is on, instead of turning
   in the last seconds (`early_holds_its_tack`), and a board early at the line sails away from it instead of creeping
   over (`start_dip`). Max asked the same evening whether lag is outdated now that 6b is "miles better": not for
   course starts, where boards still hold near the line and go from slow; it would be if course starts get a timed
   run like 6b. Its final check waits for Max's go.

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
