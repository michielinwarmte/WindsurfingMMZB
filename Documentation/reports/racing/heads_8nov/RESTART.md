# The AI after R, dropped anywhere, and the fleet's speed (8 November 2026, evening)

Max, after a race on SM1 (his 9:43, the AI boards on mark 4 of 6): "if I press R for restart the AI lost
their minds ... for me it's the most important that you can drop the AI anywhere on the field before the
start and they always try to be the fastest at the finish". Then: "continue training on the restart races
and other stuff". Branch `ai/skipper-heads-8nov` (worktree `WindsurfingMMZB-fixes`), pushed on the evening of 8 November, not merged. The
backlog's stories: E09.S18 to E09.S22 and E01.S21 (on `docs/backlog-1.0`).
Nothing in `Game/sim/`, the controller or the autopilot changed.

## 1. R broke every AI board (fixed, 3ae30e9)

**What happened.** `RaceRunner.restart()` (R, and the race director's race after a race) sets every skipper up
again on the new race. `Skipper.setup()` set the skipper's own clock (`_time_s`) back to 0 but kept the time
its last tack or gybe ended (`_manoeuvre_ended_s`) from the race before. A tack or gybe is refused while
`_time_s - _manoeuvre_ended_s < MIN_TACK_INTERVAL_S` (8 s), so after a 10-minute race no board could tack or
gybe for the next 10 minutes: it could not turn back to the line, nor away from the shore.

**Why the training never saw it.** Every training and test run (`run_race.gd`, the pools) built brand-new
skippers for each race. Nothing ever raced a second race with the same skipper objects, which is what R does.

**The fix.** The skipper's clock runs on across races, so every "time since" it keeps stays true; the
manoeuvre, penalty, dirty-air, traffic and hold-back timers are also forgotten at setup.
`tests/unit/test_skipper_restart.gd` (two tests, one through the game's own R, `main.tscn`'s `_restart_run()`)
fails on the old code and passes now (f321f1f).

**Measured** (the race tool's new `--restart_after=<s>`: the game's R, the same skippers set up again, new
random spots; 11 personas as in Max's launcher):

| R pressed | Course | Old code | Fixed |
|---|---|---|---|
| 10 min into the race | SM1 | 10 of 11 never started, 10 aground | all 11 finished, 0 early, slowest start 32 s, 0 aground, 0 falls |
| 10 min into the race | O2 | 10 of 11 never started, 10 aground | racing normally: at 852 s of the second race most boards on the last step (the job hit the pool's 90-minute limit on a busy CPU) |
| after everyone finished | I2 | 11 of 11 never started, 11 aground | racing normally: at 670 s every board on step 5 or 6 (the same limit) |
| 30 s after the gun | SM1 | 8 over the line early, slowest start 69 s, 1 aground | all 11 finished, 0 early, slowest start 25 s, 0 aground, 0 falls |

**The restart suite** (4 personas, R at six moments: 40 s and 10 s before the gun, 5 s, 60 s and 200 s after it, and
after the race was over; SM1, PD3, O2; the second race watched to 4 minutes after its gun): every board started in
every case, none over early, none aground. One weak spot: on PD3, after R once the race was over, Bruno was put at
rest right in the slalom's waiting spot. Waiting luffed up as slowly as it steers he sat at 0.2 to 0.6 m/s and fell
off twice (the standstill falls); then, needing the other tack for its reach down, he was too slow to be allowed a
tack and sailed 30 s the wrong way first: 67 s late. (Proposal: on a slalom's wait, no slower than the board stays
up; a board at rest in its spot gets going on a reach before it waits.)

**Open: a rookie that crawls after R** (2 of the 18 restart cases, both on O2, R 5 s and 200 s after the gun):
Jonas held back as usual, but after "go" he stayed at 2 to 2.7 m/s for 90 to 200 s on a beam reach, the sail let
out (sheet 0.1 to 0.2, angle of attack 4 to 11 degrees, lift 80 to 130 N against 300 to 500 N), the board heeled 9
degrees to leeward with the toes pressing. In his first race, and in a fresh race from exactly the same spot with the
same seeds, the same "go" took him to 7 to 8 m/s within 10 s. So something outlives R. Not it: the skipper's timers
(reset now), the rig side the pilot holds (cleared every tick), the race tool's reused controls. Still to check: the
controller's and the simulation's state that a reset does not clear, and the lake's wind (the fresh race starts the
wind's clock two minutes earlier). Every other board in every case started and raced.

## 2. Dropped anywhere before the start

The game puts the AI boards at random spots in a box round the start line (`SailingArea`: 150 m each side
across the wind, 100 m below the line, 50 m above it), and the training used the same box. The race tool's
new `--spawn=anywhere` drops every board anywhere round the whole course before the countdown (the box round
all its marks and lines, 300 m wider each way: above the top mark, far below the line, out to the sides), in
open water, heading any way but into the wind; with `--restart_after` it drops them anywhere again at R.

**Fleet races, 11 personas dropped anywhere** (PD3, US3, O2, SM1, I2): every board started, none ran aground, 54
of 55 finished. The one that did not: Bruno on I2, trapped in the lake's north-east corner (below), 12 falls, 9
minutes late. A sixth race, dropped anywhere again at an R after 400 s, had every board racing (steps 3 to 6 of 6)
when the 90-minute limit stopped it. Boards dropped far up the course start late, as they must: on SM1 the
last two were dropped 1.0 and 1.2 km away, deep down the course, and crossed the line 6 minutes after the gun.

**Single boards** (the all-rounder Hana and the rookie Jonas, 6 courses x 8 drops, stopped 4 minutes after the
gun): most start within a minute of what the distance allows. What went wrong:

- **The slalom line along the wind (PD3).** "Over the line" was the course side of the line's endless extension,
  even 300 to 500 m beyond its pin. A board beating up along the extension crossed it at every tack, turned back
  "behind the line", turned again for the line, and stalled at each turn. A switch that ignores the extension far
  beyond the ends (`start_free_beyond_ends_m`, 50 m) cut these flips from 18 to 8 on 27 drops, but the start delays
  stayed the same (121.8 against 120.8 s on average) and one board stalled longer: it stays off.
- **The lake's north-east corner** (game x 850 to 1050, z -940 to -1100, beyond I2's and PD3's start lines). Three
  boards were trapped there: on starboard they crawled at 0.3 to 4 m/s on a close reach, fell off at a standstill
  (Bruno 12 times on I2, 9 minutes late, did not finish), and the fin slipped 7 to 44 degrees; on port, at the same
  spot, they did 6 to 9 m/s at once. The wind at the sail there is 14 to 16 kt, so it is not a lull. On open water
  port and starboard are the same (upwind 6.99 against 6.92 m/s, the fin slip 6.5 against 6.2 degrees), so it is
  the place, not the tack (the lake's own waves are biggest at that end, where the wind has crossed the whole lake;
  for Michiel). The skipper keeps choosing starboard because its plan is geometry (laylines), not the speed it gets:
  proposal below. The AI's "getting going" (bear away to build speed) is off for every persona (last night's
  measurement) and only works after the gun anyway.
- **The rookie** takes much longer than Hana from the same spot (O2: 184 against 56 s), as he should.

## 3. Why the AI was minutes behind Max's 9:43

- **Not the push.** Hana alone on SM1 at 14:30 (3 seeds): 9:45 with her own push, 9:45 with 20 points more off the
  wind, 9:44 at 90 % everywhere, 9:41 to 10:10 at 100 % everywhere, no falls. Alone, the best personas sail SM1 as
  fast as Max did: Liv 9:37, Hana 9:45. The others alone take 10:43 to 11:39 (the sheets as written).
- **Not the personas' levels either.** With every AI at its best (`--spread=0`, two races paired with the default
  level's) the SM1 fleet was hardly faster: the winners 9:44 and 9:50, the field about 10 s a board faster on average
  (23 s faster in one race, 4 s slower in the other), and Liv, first at the default level, was ninth in one.
  Even with equal skill an 11-board race spreads over 2 to 3 minutes: only the winner comes near the time alone,
  and most boards lose 1 to 2 minutes to the crowd (the start, the shadows, keeping clear) and to the side of the
  lake they sail. That is the main thing to work on for a fleet that beats Max.
- **The fleet's time goes on the runs.** Leg by leg against Hana alone (3 fleet races of 11 on SM1 at 14:30): the
  start, the reach, the beat and the finish cost almost nothing (0 to 14 s a board on average); the first run costs
  28 to 44 s and the second run 42 to 55 s (median about 50 s, nearly every board). On the second run the boards
  sail 5 to 20 % slower (5.5 to 6.5 m/s against 6.85) and longer to the layline; keeping clear there is only 4 to
  33 s. Part of it may be the lake's wind, which changes through the race: the boards behind sail that run a minute
  or two later than Hana alone did (her three runs alone, all at the same moment, took 158 to 159 s). To measure.
- **The fleet costs some time, unevenly.** Against the same fleet with no shadows and no rules (the same seeds and
  spots) the wind shadows cost about 29 s a board on average, the rules about nothing on average, but single boards lose or gain a minute or more: a fleet race is
  chaotic. On SM1 the first run is where the crowd costs most (the shadows lie ahead of the sails downwind, so the
  boards behind blanket the leaders), and the second run comes back down through the boards still beating up.
- **The tests did not use the game's level.** The game pulls the personas' skills halfway to the top
  (`RaceSetup.LEVEL_CLOSE` 0.5, Max's choice of 3 November); the race tool used the sheets as written (1). With
  0.5 the SM1 winners sailed 9:38 to 10:07 and the fleet's average 11:09 to 11:34.
- The R bug itself: in a race after an R the AI could not tack or gybe for the first minutes.

The play folder has a launcher with every AI at its best (`--spread=0`).

## 4. What to improve next (proposals)

1. **Train and test the way the game runs** (done in the tool, to keep doing): R and the race director's race after a
   race (`--restart_after`), the game's level (`--spread=0.5`), drops anywhere (`--spawn=anywhere`).
2. **A faster fleet comes from racing in the crowd, not from the level**: every AI at its best (`--spread=0`) was
   hardly faster on SM1. The time goes on the runs (30 to 55 s a board on each); the work is there, measured
   against the same boards alone, with the lake's wind at the same moment (to tell the crowd from the wind).
3. **The first run in a crowd**: the boards behind blanket the leaders. Gybing out of dirty air on a run
   (`dirty_air_on_runs`) made no difference in 8 pairs of fleet races (+0.6 s a board; on I2 and O2 it never
   fired): off. The next try: on a run, keep out of the line of the boards just behind (sail a few degrees higher
   or lower), rather than gybe.
4. **Starts from far away and from the slalom's downwind side**: a board on the course side of the line's extension
   far beyond the ends should sail its way in rather than turn back at every tack; the switch tried tonight removed
   the flips but not the time. The next try: plan the way to the line as a route (beat up to the run-in, then the
   normal start) instead of switching between "back behind the line" and the start's plan.
5. **A tack that does not go**: when the board has crawled on one tack for a while and the other tack was fast,
   take the other tack and keep it a while. Tried (`change_slow_tack`, at 45 % and 60 % of the polar, kept 45 and
   90 s): it rescued 1 of the 32 drops on I2 and PD3 (Hana now starts instead of never) and changed nothing else;
   off until a fleet test. The corner itself (item 6) is the bigger part.
6. **For Michiel**: the lake's north-east corner, where a board on starboard crawls at a close reach in 15 kt and
   falls off at a standstill (the fin slipping 7 to 44 degrees; port at the same spot 6 to 9 m/s); the earlier
   findings (the board barely steers below 2 m/s, tacks stall in strong wind) stand. **For Max**: letting the AI carve its tacks and gybes with Shift needs a small change in the
   controller.
7. **The open case after R** (section 1): find what outlives R for the rookie on O2.
8. **A slalom start from rest in the waiting spot** (section 1): no slower than the board stays up.

## 5. The switches measured tonight (all off in the game)

| Switch (`SkipperConfig`) | What it does | Measured | Result |
|---|---|---|---|
| `start_free_beyond_ends_m` (50) | far beyond the start line's ends, its extension does not count as over | 27 drops | flips 18 -> 8, start delays the same (121.8 / 120.8 s), more stalled: off |
| `dirty_air_on_runs` | gybe out of other sails' shadows on a run | 8 pairs of 11-board fleet races | +0.6 s a board, penalties 35 / 32: off |
| `change_slow_tack` (45 %, 60 %) | crawling on one tack while the other went: take the other | 96 and 32 drops | 1 drop rescued, nothing else changed: off |
| `push_everywhere` (0.9, 1.0) | the push slider fixed at that level everywhere | Hana alone, 3 seeds | 9:41 to 10:10 against 9:45: off |

## How to run it

`tools/heads/pool.py --jobs=<file> --out=<folder> --project=<frozen copy>/Game` with `run_race.gd` arguments, for
example `--course=iq_o2 --map=lake --time=14:00 --skippers=persona:hana,persona:jonas --spawn=anywhere --spawn_seed=5
--seed=5 --restart_after=60 --stop_after_gun=240 --spread=0.5`. The jobs files and logs of tonight are under
`.sim_output/heads/` (restart, rsuite, anywhere, startany, runs, spread0, fleetcost, push). Keep the PC at about 75 %:
the jobs on 10 of 16 logical processors (`ProcessorAffinity` 0x3FF).

## 6. The late evening: the menu, and the new training method

**The menu race.** Max played the play folder: from the launchers the AI raced, from the menu with 15 boards it did not.
Not reproduced yet: the real game (the play folder's build, headless, sped up with `--fixed-fps 60`) with the menu's 15
personas (Aiko to Pia, alphabetically: Noor, Pavel and Pia had never been in a test) raced normally on SM1, on T2 (the
menu's first lake course) and on T1 (its first open-water course): every board started within 40 s, no falls, all racing
at 4 minutes. The menu builds the same RaceSetup as the launchers; the difference must be one of Max's choices
(characters or the trained brain under "Who", another course or hour, the race director during the race, a second race
in the session). Waits on Max's choices (backlog E09.S24). The race page's countdowns are now 2, 3 and 5 minutes (Max;
they were 30 s, 60 s and 3 minutes). Max's session's own log was lost: the race tool's runs share the game's log folder,
which keeps five files.

**The new training method** (agreed with Max; the steps in
[../../../AI_TRAINING_METHOD.md](../../../AI_TRAINING_METHOD.md)): `tools/heads/random_suite.py` draws every race at
random (water, course: saved, shifted and turned, or laid new by the course fitter; wind, only planing: 14 kt and up;
countdown 2, 3 or 5 minutes; the start box, behind the line or anywhere; R in 20 %), sails it with one general head,
judges every board by checks that must always hold, measures every mark rounding, keeps a hold-out set, and writes a
live page Max can open and close (`Open the AI training viewer.bat`).

**The speed** (one board, the race tool): 4.0 times real time alone; 8 side by side on one logical processor per core
4.2 times each, 33 together, about 55 % CPU; 12 side by side 3.1 each, 37 together, 82 % CPU. The game's release engine
is no faster (about 3 times with its scene, one board) and cannot run the race tool's script. **Five different full
races** side by side (8 minutes in all): lake SM1 13:46 of racing in 2:54 (4.8x), lake O2 turned and shifted 14:47 in
3:10, a new LG2 laid on the lake 37:36 in 7:57, open-water T1 9:52 in 1:41 (5.8x), open-water PD3 at full size with an R
about 12 minutes in 2:04. Four passed every check; O2 turned and shifted started 87 s late from behind the line. Every
race showed Max's complaints in numbers: out of the turn 21 to 75 m from the mark (limit 15), overstands of 36 to 123 m
on the beats into a mark (limit 25), and on SM1 a gate with 691 degrees of extra turning (circling).

**The first baseline** (phase A, the tune set, 300 races, from 21:19): at 43 races, 25 passed every check; the start
failed in 16, a leg in 8; 156 roundings: out of the turn median 29 m (92 % over 15 m), overstand median 51 m (92 % over
25 m). The roundings and the starts are the work (backlog E09.S23, E09.S21).
