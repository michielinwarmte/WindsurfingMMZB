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
7. **One general head first**, then the personas, then fleets (when Max says).
8. **Only planing winds** (14 kt and up): below that the numbers say nothing (Max).
9. **No play folder until Max sends the message to make one**, and only after the suite passes.
10. **Keep the PC at about 55 to 75 % CPU** (8 jobs, one per physical core; below).

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
| overstand | on a beat into the mark: how far its last tack was beyond the layline (the close-hauled track at 50 deg from the course's axis) | 25 m |
| gate extra turning | in a gate's 80 m circle: the heading turned beyond the turn from the way in to the way out | 120 deg |

## The speed (measured 8 November 2026, the 8-core Ryzen 7 5800X3D)

One board on the race tool: 4.0 to 5.8 times real time (the open water faster than the lake); about 5 s to start up.
8 races side by side on one logical processor per core (mask 0x5555): each at full speed, 33 times real time together,
about 55 to 60 % CPU, about 100 to 150 one-board races an hour. 12 side by side (mask 0x55FF): 3.1 times each, 37
together, 82 % CPU: not worth it. The suite sets its own mask (default 0x5555); every Godot it starts inherits it.
Five different full races side by side took 1:41 (T1) to 7:57 (a new LG2 lasting 37 minutes).

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

**Step 2, read the results.** The viewer for the overview. Then rank the failures by check and by what was drawn
(course kind, water, start, R): `results.jsonl` with a few lines of Python. For each failure class, open two or three
failures: the board's CSV (`<run>/rNNNN/<board>.csv`: race time, place, heading, speed, next step, what the skipper was
doing) and, when needed, replay with its `replay` command (it adds `--trace=<board>`: the whole telemetry). First check
the check: a failure that is the check's fault (a wrong expected time, a start need that ignores the countdown's hold)
is fixed in the suite, and said so.

**Step 3, choose the biggest class.** In order now: (1) the roundings and laylines (Max's main pain: wide exits,
overstands, gates; E09.S23), (2) the starts (16 of 43; E09.S21), (3) the slow legs (E09.S02, E09.S20).

**Step 4, find the cause in the skipper** (`Game/race/skipper.gd`, `skipper_config.gd`), never in the physics. Write
the change behind a switch in `SkipperConfig`, off by default, with a comment that says what it does and why (the
failure it answers, the numbers).

**Step 5, the on and off test on the tune set.** The same `--seed` and `--set`, 100 races or more, once with
`--extra="--skipper.<switch>=1"`, once without (runs `<name>_off` and `<name>_on`). Compare: the pass rate per check,
the roundings' medians and shares over the limits, falls, the legs' ratio to expected. A fleet test is not needed in
phase A.

**Step 6, confirm on the hold-out.** The same pair with `--set=holdout`, 100 races. The switch goes on only when the
hold-out gets better and no check gets worse. Write the numbers down (the report, the progress log).

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
