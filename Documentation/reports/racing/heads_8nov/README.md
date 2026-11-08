# The skipper's heads trained on Silvaplana (night of 8 November 2026)

Max's ask (00:30): train the rule-based skipper's heads one at a time (1 course sailing, 2 the start,
3 the racing rules, 4 tactics, 5 the personas) until 9:30, on Silvaplana only, from slightly random
places so it is no one-trick pony, the courses off the shore, enough information about the wind, the
water and the shore, every weird failure looked into and fixed, more wind if there is time.

Branch `ai/skipper-heads-8nov` (from `physics/realism-7nov`), worktree `WindsurfingMMZB-fixes`, committed,
not pushed, nothing merged. **Nothing in `Game/sim/` (the physics) and nothing in the autopilot or the
controller changed**: all the changes are in the skipper (`Game/race/skipper.gd`, `skipper_config.gd`), the
lake's iQFOiL course files, and the tools. Unit tests 1007/1007. The night step by step, with every
number: [PROGRESS.md](PROGRESS.md).

## How the training works

- **The suite** (`tools/heads/`): Godot sails the all-rounder alone on Silvaplana, headless, 14 at a time:
  *races* (every lake course at three hours, from a random spot round the start, as the game spawns),
  *drops* (the board set down at a random open-water spot on a random leg, heading roughly along it, at a
  random hour, two steps to sail), *starts* (eight personas, the countdown and 90 s after the gun) and
  *fleet races* (eight personas, the whole race, the rules and the wind shadows).
  **Every seed gives new places and hours**, so each round was also checked on a seed the skipper had never
  seen: that is the answer to "no one-trick pony".
- **The score** (`python -I tools/heads/suite.py <folder>`): a case is clean when the board gets there,
  never runs aground, never falls and is never stuck; every failure is listed with what the skipper was
  doing. The track files now carry the point the skipper aims at, which found most of the bugs.
- **The numbers** were chosen by A/B runs (`--skipper.<field>=<n>`), never guessed; three ideas were
  measured and *not* taken because they did not help.

## The result

Clean cases, the all-rounder alone, every Silvaplana course:

| Round | What | Clean |
|---|---|---|
| baseline (seed 1) | the skipper as it was | 111 / 121 (91.7 %), 2 aground, 26 falls |
| round 2 (seed 1) | shore fixes, wind lookout, refitted courses | 116 / 121 (95.9 %), 0 aground, 5 falls |
| round 3 (seed 2, never seen) | + mark roundings from below | 109 / 121 (90.1 %) |
| round 4 (seed 3, never seen) | + slow boards tack, tack past the layline | 115 / 121 (95.0 %), 0 falls |
| more wind x1.3 (seed 7) | the same code | 86 / 99, **every race and drop finished**, 0 aground, 18 falls |
| less wind x0.8 (seed 9) | the final code | **95 / 99, 0 aground, 0 falls**; one T2 drop not finished, 3 slalom starts over early (alone) |
| **final (seed 8, never seen)** | everything | **75 / 77 (97.4 %)**: all 33 races clean, 0 aground, 0 falls in the races; the two failures are both T2 (the old course, kept) stuck in its light patch near the finish |

## What changed, by head

**1 Course sailing** (`skipper.gd`)
- Beats and runs always tack or gybe away from the shore (a run at the polar's 130 degrees counted as a
  reach in a slightly turned local wind, turned along the shore and never gybed); they look 120 m ahead.
- At the edge and slow, it gets out on the tack it is on instead of waiting for a manoeuvre it cannot make.
- **Too slow to gybe (under 3 m/s) it heads up and tacks** (gybes at 1.5 m/s bore away, stalled, came back).
- **Well past the layline it tacks even when slow** (in light wind a board never reached the "pointing"
  speed and sailed 280 m away from its mark for three minutes).
- Mark roundings: a run out a few degrees past dead downwind no longer leaves the board with no plan; a
  beat in to a reach's mark arrives on the right tack; unable to lay the mark from close, it tacks twice
  (a board circled US4's mark 2 for four minutes).
- A close finish line downwind is sailed straight at (O2's 35 m line: swept past its end for two minutes).

**The courses** (Max: "not too close to the shore"): the ten iQFOiL lake courses refitted with the
shallows (under 2 m) counted as land, every mark 250 m and every leg 150 m from them (before about 190 m
and 108 m). The trapezoids are now 30 % of the class size, the sprints 40-50 %, LG2/LR2 still 100 % (their
1.8 km beats reach the shore: the boards short-tack there). The old files are in `courses_before/`.
**T2 was kept as it was** (a unit test and every older yardstick use it); its refit is ready in
`courses_not_used/` and its mark 3 lies in a light patch at 11:50 (two of round 4's failures).

**2 The start**: the slowest hold (`hold_floor_ms`) and the acceleration estimate (`start_accel_share`)
were measured on 22 start rounds of eight personas and left as they were (no gain). The start crosses
with a median of 4 s after the gun and OCS at the gun is rare (2 of 120); its open problem is late
starters, oddly the sharp ones (Hana, Mara): they aim close to the gun and lose the time getting going.
In light wind (x0.8) three slalom starts were over early with no other board about: the board crossed
the line's extension on the way to its waiting spot upwind of the committee boat and came back late;
turning back at once did not change it, so the cause is in the slalom start's geometry in light wind
(open).

**3 The racing rules**: keeping clear always bore away, which turns a windward board onto the leeward one
(17 of 22 penalties in the start rounds). Now by the rule after the gun: the windward board heads up, a
board clear astern or outside at a mark turns away from the other's side, port still bears away behind
starboard; before the gun it bears away as before (heading up near the line sent boards over early).
Measured on the same 15 start rounds of eight personas: penalties 39 -> 29, the windward board's 33 -> 20,
early starts and the median start unchanged. What is left are mostly port/starboard incidents, read one
by one with the new PENALTY lines (`run_race.gd` prints both boards): a starboard board nearly stopped in
the crowd (0.4 to 2.5 m/s, often right after the start) and port boards at 7 to 9 m/s that were already
keeping clear running into it; a fixed bear-away seen 15 m out is too little at that speed. A longer
look-ahead and a duck behind the starboard board's stern were measured and did not help; a third idea,
**passing clear** (the burdened board works out where both will be over the next 6 s and turns just
enough, either way, to pass 12 m clear: `keep_clear_by_passing`), was measured last against the very
same code without it on the 22 start rounds: 45 penalties against 46, nothing else changed. **Left off.**
So the incidents are not a question of the head's choice: the board does not turn in time at 9 m/s
(reaction, the think interval, the hands' steering), or the crowd is already too close at the gun. The
next step is a look at the hands' turn rate at speed and at the crowd on the line, with these PENALTY lines.

**4 Tactics, and the wind information** (Max: "give them enough information about wind, water and
shore"): **the wind lookout** reads the map's wind on the water 200 m ahead on both tacks on a beat or a
run and leaves a light patch for the side with more wind. Its A/B on 121 cases: as robust either way, about
3 % faster with it, and it keeps boards off the dying-wind lee shores; kept on. Its numbers are on the
sheet (`wind_look_m`, `wind_hole_share`), so personas can read the wind differently.

**5 The personas**: every persona sails on these heads. **The fleet races** (eleven, one per course,
eight personas, the whole race with the rules and the wind shadows): **88 of 88 boards finished, no
grounding, one fall**, 82 penalties, 4 OCS. Mean places: Kofi 3.6, Hana ("the pro") 3.9, Mara 4.1, Jonas
("the rookie") 4.1, Lena 4.1, Liv 4.2, Elin 5.4, Bruno ("lost when it is light") 6.6. The storm sailor
last in these mid winds is right; **the rookie in the middle is not: the levels do not spread enough
yet**, and the penalty turns (20 to 30 s each, 6 to 14 per persona) shuffle the order more than the
skills do. That is the personas' next step, after the penalties.

**A lesson for every fleet test**: a race of several boards repeats exactly with the same code, but any
change, even one that does nothing (the same sum added in another order), moves a heading by 0.1 degree
and the incidents of the crowd come out differently: two runs of "the same" start set gave 9 and 14
penalties in 48 boards. So fleet results need many rounds and a look at the kinds of incident; a
difference of a few penalties is noise.

## Measured and not taken

- A getting-going angle (`get_going_twa_deg`): 44 light-wind drops each at 0, 95, 115, 135 degrees: off was
  best (the refitted courses had removed most of the trap). Left at 0.
- A faster slowest hold at the start (2.5 m/s): fewer clean starts, more penalties. Left at 0.
- A start that reckons slower acceleration (0.7): inside the noise. Left at 1.0.
- Keeping clear: a longer look-ahead (4 s), a port duck behind the starboard board, and passing clear by
  working out both boards' paths: none cut the penalties. The look-ahead and passing clear stay on the
  sheet, off (`keep_clear_look_s` 0, `keep_clear_by_passing` false); the duck was taken out.

## For Michiel and Max (the hands and the physics, not changed)

- **Below about 2 m/s the board is nearly out of control**: the auto-sheet holds only the sail a standing
  sailor can hold (`Autopilot._alpha_for_torque_deg`: 2-5 degrees in 12-15 kt on a broad reach), so a board
  that gets that slow in a light patch stays at 1.5-2 m/s; and it hardly turns (heading 311-322 for 16 s
  while the skipper asked for 290). Most of the remaining failures are this crawl.
- **Tacks stall in the stronger wind**: at x1.3, 13 of 18 falls came within 25 s of a tack or gybe that
  stopped head to wind; the sailor then falls at a standstill.

## How to run it

```
bash tools/heads/freeze.sh                                   # a frozen copy of Game/ to run on
python -I tools/heads/make_jobs.py --out=.sim_output/heads/mine --seed=9 --drops=8
python -I tools/heads/pool.py --jobs=.sim_output/heads/mine/jobs.txt --out=.sim_output/heads/mine --cores=14 --project=.sim_output/heads/frozen/Game
python -I tools/heads/suite.py .sim_output/heads/mine
```
Starts: `make_jobs.py --races=0 --drops=0 --starts=2`; fleet races: `--fleet_races=1 --finish_window=600`;
more wind: `--wind_scale=1.3`; a number tried on every skipper: `--extra="--skipper.wind_look_m=0"`.
One drop by hand: `tools/race.sh --course=iq_us4 --map=lake --time=15:20 --skippers=allrounder
--drop_step=random --drop_seed=1002`.
