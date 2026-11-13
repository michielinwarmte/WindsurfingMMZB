# E09 · The AI sailors: the skill

Owner: the lead with agents; Michiel's PC for nights; Max's eye on the racing | Roadmap: RA1 to RA28, MP11, PH42, PH45 | Questions: Q26, Q27

**Goal.** AI sailors that can sail any course on any spot in any conditions: start well, round cleanly, keep off the shore, stay on the board, sail in a crowd by the rules, use the gear of the day, pump, and finish; the same physics and controller as the player (rule 7); fast enough for a fleet of fifty. **The trained neural network is the goal** (Max and Michiel, 6 November 2026, Q26): the brain races at 1.0; the rule-based skipper is its teacher, its fallback and its yardstick until the brain beats it.

**Done when (1.0).** On every spot and every race format, a fleet of the fifty characters (E10) races every saved course at every hour and wind band of the spot's climatology without groundings, with a fall rate within the budget (E09.S08), starts within a few seconds of the gun, and a results spread that reflects the characters' levels; the racers are the trained brains, each shaped by its persona's sheet (one strong brain, many personas: D3 of the archived fleet plan), beating the scripted skipper on the yardstick; the scripted skipper stays in the game as the fallback and the training's opponent; the autopilot suite is the regression gate for every physics, controller and brain change.

**Where things stand (6 November 2026).** The game's AI is the rule-based stack: the scripted skipper (the head: laylines, start plans, the slalom start, keep-clear by the rules, penalty turns, the shore lookout, the push off the wind) on the beginner controller and the autopilot (the hands), with twenty personas and four characters. Measured: every persona finishes the six T1 and T2 races alone (3 falls in 120); the polar per wind; the start within 3 s of the gun on both courses; on the lake, 8 of 10 iQFOiL courses clean, LR2 and LG2 with groundings in the shallows on the way to the leeward gate and boards crawling in the south-east lee band; the slalom start slower off the line than the old start; the 24 kt beam hold still catapults on 8 of 17 lake hours; tail-stands at walking pace before the start; penalty circles at reaching starts; catapults leaving a wind shadow in a crowd; the push falls on 24 kt bear-aways. The night run of 6 to 7 November measures the final code on every course (its first race: 11 finish, 0 aground, 1 fall, the median start 31 s late). The neural brains (PPO, stages S1 to S6, C1, C2) finish a course alone but are not race-ready; RA5 and RA14 are "later" (Max, 5 November). The stay-on-the-board work moved the fall's bar (Michiel's OK pending, E01.S01). 12 November 2026: the starts in company (E09.S25): Max's slalom start, a timed run in clean wind, on (3 to 5 times as far up the course 30 s after the gun as the old start); lag on course starts; each persona on its own tack; next, out of dirty wind on the reach (E09.S26).

## Stories

### E09.S01 · The night run of 6 to 7 November read
Status: next | Size: S | Owner: the lead | Milestone: M1 | Needs: the run to finish | Roadmap: RA27, PH45
Done when: `night_run_6nov_results.md` is written and read, the race-type numbers are in the race-types report, the reflex sweep's table in the autopilot report, every red (an OCS fleet, a grounding, a new validation name, a LAN FAIL) is a task in a story here, and the frame-time part answers E01.S01 T5.
- [ ] T1 `python -I Documentation/reports/playtest/night_run_6nov.py` and the results read
- [ ] T2 Part A per course: finishers, DNF, falls, OCS, not started, the longest start delay; the slalom start's numbers against the old start
- [ ] T3 Part B: the reflex variant chosen (less falls at the same speed within 2 %)
- [ ] T4 Parts C, D, E, F: the manoeuvre falls at 24 kt, the fps on an idle PC, the eight validation names, the LAN release test
- [ ] T5 The reds turned into tasks below; a line for Max

### E09.S02 · Every course on Silvaplana clean, at every hour, with every persona
Status: todo | Size: M | Owner: the lead | Milestone: M2 | Needs: E09.S01 | Roadmap: MP11, RA2
Done when: the ten iQFOiL courses and the saved courses race clean (no grounding, no board stuck in the lee band) at 12:00, 14:30 and 17:00 with the twenty personas and the four characters, at lake wind x0.7, 1.0 and 1.5, measured with `tools/lake_courses_check.sh`.
- [ ] T1 The leeward gate shallows on LR2 and LG2 (slow boards in shallow water): the lookout's depth and look-ahead by speed, or the course fitter's margin
- [ ] T2 The south-east lee band: the skipper reads the wind field and avoids the band (the stronger lanes), not only escapes it
- [ ] T3 The sweep at the three hours and three multipliers; the results table in `Documentation/reports/multiplayer/RACE_DIRECTOR.md` or a new report
- [ ] T4 Running aground as physics (E01.S10 T2) when it exists; until then the scene's stop for the AI (RA2, built)
Notes: 8 Nov 2026 night (`ai/skipper-heads-8nov`): the scripted skipper's heads trained on Silvaplana from random drops: 75 of 77 clean on the final seed, lake wind x1.3 86 of 99 finished, x0.8 95 of 99 (`Documentation/reports/racing/heads_8nov/README.md`). Evening: the lake's north-east corner traps boards on starboard (E01.S21). 8 Nov 2026 late evening: in one suite race T2's last leg took 470 s against 29 s expected (the start's countdown 2 min, 15:54, x1.26).

### E09.S03 · The starts
Status: todo | Size: M | Owner: the lead | Milestone: M2 | Needs: E09.S01 | Roadmap: RA27, RA20, RA23, RA11, RA16
Done when: on every course type the fleet starts within 10 s of the gun (the median under 4 s), with at most one OCS per twenty boards, no board outside the sailing area at the gun, no penalty circles in the first 30 s on a reaching start, and the 12 kt start no later than the 18 kt one by more than 5 s.
- [ ] T1 The slalom start off the line: the reach down from the row timed by the polar, the luffing wait, the go time (RA27's open numbers: 35 m, 140°; PM1 and SM1 as slalom starts?)
- [ ] T2 The crowd at the reaching start: the skipper chooses its spot and time knowing the others' (RA20, RA23)
- [ ] T3 The 12 kt start and the boards waiting raked back for minutes (Greta, Kofi, Jonas): pump out of the wait (E01.S09 T4)
- [ ] T4 The figure-of-eight hold for a line along the wind from far back (RA16), or the boards placed nearer in light wind
- [ ] T5 The countdown's length per format (RA11b: 60 s now; a slalom's 3-2-1 minute sequence as the PWA runs it)
Notes: 8 Nov 2026 day: racing each other, the 22 start rounds' penalties 46 -> 25 with the starts unchanged; evening: starts from anywhere (E09.S21), and every board starts after R (E09.S18).

### E09.S04 · Staying on the board
Status: todo | Size: M | Owner: the lead, Michiel for the physics causes | Milestone: M2 | Needs: E01.S01 T3 | Roadmap: PH45, PH42, RA17, RA20
Done when: the fall budget (E09.S08) holds on the lake and the open water at 12 to 24 kt in every persona's hands: the 24 kt beam hold, the tail-stand at walking pace, the windward roll out of irons, leaving a wind shadow at planing speed, the push on bear-aways, the penalty turn at speed.
- [ ] T1 The 24 kt beam reach held 45 s (8 of 17 lake hours fall): the cause from the fall records
- [ ] T2 The tail-stand at walking pace before the start (the buoyancy's pitch moment nearly awash: Michiel) and the windward roll out of irons
- [ ] T3 Leaving a shadow (with E01.S04 T3); the hold-back near a windward board in the last 10 s
- [ ] T4 The push on the 24 kt bear-away and run (RA17): ease before the bear-away, the gybe at 14 m/s
- [ ] T5 The reflex's chosen variant (from E09.S01 T3) and its fade above 80 % push kept for the player
Notes: 8 Nov 2026: standstill falls while waiting luffed up in the slalom's spot (E09.S21 T2); below about 2 m/s the board barely steers (for Michiel).

### E09.S05 · The AI's push, and the specialists that show
Status: todo | Size: M | Owner: the lead | Milestone: M2 | Needs: E09.S04 | Roadmap: RA7, RA19, RA21
Done when: a persona's push level, reaction time and gybe timing are on its sheet and show in the results (a pusher wins in strong wind off the wind and falls more; a course racer beats a slalom pro on a beat and loses on a reach), with each persona's run angle from the race-tested best and the shifts read by its upwind sense.
- [ ] T1 The push and the reaction time per persona (RA7, PH25); the gybe's timing per persona through the held flip (E07.S05)
- [ ] T2 The course and slalom specialists (RA19): a per-sailor gybe, the run angle, the shifts
- [ ] T3 The polar per gear for the skipper's timing (RA21, with E06.S07)
- [ ] T4 The persona matrix as the proof (`tools/persona_matrix.sh` on three seeds)
Notes: 8 Nov 2026 evening: the push is not why the AI was slower than Max on SM1 (his 9:43): Hana alone sails 9:41 to 9:46 at any push (the polar's, +0.2 off the wind, 90 % or 100 % everywhere; `push_everywhere`, off).

### E09.S06 · The AI on a sea spot
Status: todo | Size: M | Owner: the lead | Milestone: M3 | Needs: E01.S12, E04.S04 | Roadmap: —
Done when: the skipper sails with a current (the laylines and the start plan corrected by it), reads the swell (eases over sets, picks the gybe between them), avoids the shore break and the shallows at low tide, and the fleet races Brouwersdam's and the Gorge's courses clean.
- [ ] T1 The navigation with a current field (laylines, the time to the line, the leeward gate's approach)
- [ ] T2 The swell on the hands (the airborne ease exists for the lake's chop; the sets' timing)
- [ ] T3 The tide on the lookout (the depth grid offset by the level) and the start's beach
- [ ] T4 The sweep on Brouwersdam and the Gorge as they are built

### E09.S07 · The AI in every race format
Status: todo | Size: M | Owner: the lead | Milestone: M7 | Needs: E11.S03, E11.S05 | Roadmap: RA28
Done when: the skipper races an elimination heat (8 to 10 boards, four gybe marks, one chance), a long-distance race (the Défi: 40 km along a beach in a crowd of hundreds), a speed run (the canal's timing gates) and the hybrid courses, with the race type as an input (not guessed from the geometry).
- [ ] T1 The race type on the skipper's plan (RA28 for the rules too, not only the brains)
- [ ] T2 The heat's tactics: the start spot by the boat or the pin, the first gybe mark's crowd, the lanes
- [ ] T3 The long-distance race: pace, the reach's trim, the gybe at the far mark, the crowd of hundreds (far boards simplified: Q8)
- [ ] T4 The speed run: the entry, the line, the exit

### E09.S08 · The autopilot suite as the regression gate
Status: todo | Size: S | Owner: the lead | Milestone: M2 | Needs: — | Roadmap: —
Done when: every physics or controller change runs `tools/autopilot_suite.sh` rounds on the open water and the lake (and later each spot) with a fall budget (falls per race per persona per wind band) and a time budget (the finish time within a band of the previous release), the result table is in the report, and a red blocks the merge.
- [ ] T1 The budgets written per wind band and water from today's numbers
- [ ] T2 The suite's "release gate" round and its summary line in the pull request's text
- [ ] T3 The night-run script generalised (parts per spot) for the second machine
Notes: 7 November: the lake suite (`tools/lake_suite.py`, 30 Silvaplana cases, branch `autopilot/lake-speed` and on `physics/realism-7nov`) now has the night's low-speed steering cases among its guards, with a cost on a wandering course and on a key turn that does not stay, after the trainings had traded the player's low-speed steering away (E07.S12). The lake tuner's runs are kept in `.sim_output/lake_speed/`.

### E09.S09 · The brain's yardstick, and the next night
Status: todo | Size: M | Owner: the lead, Michiel's PC | Milestone: M9 | Needs: E09.S08, E17.S07 | Roadmap: RA5, RA14, RA9, RA10
Done when: the yardstick is written (the scripted skipper's race times, falls, starts and penalties on both courses at 12, 18 and 24 kt, alone and in company), the next night's changes (RA14) have run on the second machine, and `tk_c2_best`'s successor is measured against it with the evaluation table (RA10), so the team sees how far the brain is from the rules.
- [ ] T1 The yardstick written (the numbers from E09.S08)
- [ ] T2 The next night (RA14's list: ent 0.005, a 12 kt C1, the run reward, a C3 in company, the slalom gybe cost, the game's placing, resume from `tk_c2_best`)
- [ ] T3 The evaluation table (RA10), the brain files with the physics commit they were trained on, a warning when the physics is newer
- [ ] T4 The gap report: what the brain still loses on (the start, the pinching, the slalom's tacks, company) as the brief for E09.S14
Notes: Q26 answered 6 November 2026: "neural is the goal". The stories E09.S13 to E09.S17 are the neural line to 1.0; the rule-based stories above keep the game racing meanwhile and give the brain its opponent.

### E09.S10 · The AI race committee
Status: todo | Size: M | Owner: the lead | Milestone: M7 | Needs: E03.S04, E11.S06 | Roadmap: —
Done when: in single player the race committee sets the day's course from the spot's templates for the day's wind and tide (the class's guideline distances), postpones on no wind, abandons on too much, shortens a course, and signals it on the notice board and by the flags on the committee boat.
- [ ] T1 The course of the day from the wind band and the format (the class guideline's distances)
- [ ] T2 Postponement, abandonment, shortening, the flags
- [ ] T3 The race director's table (E05.S04) overrides it in free sailing and LAN

### E09.S11 · The AI on the beach
Status: todo | Size: S | Owner: the lead | Milestone: later | Needs: E05.S11 | Roadmap: —
Done when: the AI characters rig up at the racks, walk to the water for their start and come back after the race, as scenery that makes the beach alive.
- [ ] T1 The beach routine per character around the race's times

### E09.S12 · Efficient AI
Status: todo | Size: M | Owner: the lead, Michiel for PH19 | Milestone: M11 | Needs: E17.S01 | Roadmap: PH19, RA4
Done when: an AI board's tick (the physics, the hands and the head, or the brain's inference) costs under 1.3 ms on Max's PC with the lake's full waves (today 2.3 to 2.4 ms with the old waves), so 50 boards can step at 60 fps on the release build (E17.S01).
- [ ] T1 The hands' cost: the 21-angle search ten times a second or a table (PH19)
- [ ] T2 The skipper's own cost measured and trimmed (the lookout, the laylines per tick)
- [ ] T3 No far-board rule: every board keeps the full physics (Max, 6 November 2026, rule 7); the fleet's size is what the frame allows

### E09.S13 · The training machine and the nights automated
Status: todo | Size: M | Owner: the lead; Michiel's PC or a dedicated machine | Milestone: M9 | Needs: E17.S07 | Roadmap: RA9
Done when: a machine other than Max's runs training nights unattended (the stack in its venv, the headless Godot workers, a STOP file, retries, NaN guards exist), the brains and the logs come back into the repository by a script, every run records the physics commit, and a night costs the team one command.
- [ ] T1 The machine (Michiel's PC with 12 workers as before, or a rented box) and its access
- [ ] T2 `tools/train.sh` from a remote session; the results pulled (`.logs/nights.log`, the brains) and committed
- [ ] T3 The trainer's leftovers (RA9: the lake's wind and water in the stages, the idle steps of parked boards, the early-stage starts)
Notes: 8 Nov 2026: measured on Max's PC: one board 4.0 to 5.8x real time on the race tool; 8 side by side on one logical processor per core 33x together at about 55 % CPU; the game's release engine is no faster and cannot run the race tool's script.

### E09.S14 · The brain learns the whole race
Status: todo | Size: L | Owner: the lead | Milestone: M9 | Needs: E09.S09, E09.S13 | Roadmap: RA14, RA28, RA12
Done when: a brain finishes the T1 and T2 races alone within 5 % of the scripted skipper's time at 12, 18 and 24 kt, starts within 5 s of the gun from the game's placing, rounds and gybes a slalom without extra tacks, and in company with the all-rounder and two personas loses no more than a minute to them; the race type is an input (RA28).
- [ ] T1 The curriculum revised (C1 at 12 kt, the run reward along the polar's best angle, the slalom's tack cost, the game's placing, a C3 in company)
- [ ] T2 The race type and the course's shape as inputs; the push output kept (RA12)
- [ ] T3 The rules as the brain sees them (the keep-clear and the penalty turn stay the hands' job, or the brain learns them: decide by measurement)
- [ ] T4 The nights until the done-when holds; each night's review in `Documentation/reports/fleet_speed/`

### E09.S15 · One brain, fifty personas
Status: todo | Size: M | Owner: the lead | Milestone: M9 | Needs: E09.S14, E10.S03 | Roadmap: RA7, RA19
Done when: the persona's sheet shapes the brain's sailing (the skills as inputs or as noise and limits on its outputs: the start's nerve, the push, the reaction time, the manoeuvre's quality, the wind skills), so fifty characters on one brain are as different from each other as the scripted personas are, and the specialists show.
- [ ] T1 The sheet's fields mapped onto the brain's inputs and output limits; a persona without the brain sails the scripted skipper as before
- [ ] T2 The persona matrix on the brain: the spread of levels and the specialists
- [ ] T3 The persona's gear choice (E06.S07) and the brain's polar awareness

### E09.S16 · The brain on every spot and in every condition
Status: todo | Size: L | Owner: the lead | Milestone: M9 | Needs: E09.S14, E04.S01, E09.S06 | Roadmap: RA9
Done when: the training's stages draw from every built spot's wind, waves, tide and current and every race type, and a brain trained on them races every saved course on every spot clean (no groundings, the fall budget) at every hour and wind band, measured by the suite (E09.S08) on the second machine.
- [ ] T1 The stages on the spot list (the lake share, the sea share, the currents); the shore in the observation
- [ ] T2 The suite's spot rounds on the brain; the gap report per spot
- [ ] T3 The nights until it holds

### E09.S17 · The brain in the game by default
Status: todo | Size: M | Owner: the lead | Milestone: M9 | Needs: E09.S15, E09.S16, E17.S01 | Roadmap: RA15, RA10
Done when: the race page, the season and the LAN race the brains by default (the scripted skipper as a choice and the fallback when a brain is missing for a spot), the inference cost per board is within the fleet's budget (E09.S12), the brains ship with the game with the physics commit they match, and a physics change triggers a retraining night before a release.
- [ ] T1 The default switched; the fallback rule
- [ ] T2 The inference cost measured with fifty boards; the network's size against it
- [ ] T3 The release rule: a physics change, a night, the suite, then the release

### E09.S18 · The AI after R (the race again)
Status: review | Size: S | Owner: the lead; Max's play-test | Milestone: M2 | Needs: — | Roadmap: —
Done when: after R, and after the race director's race after a race, pressed at any moment (in the countdown, mid-race, after the finish), every AI board starts and races as in a first race; checked by Max on his screen.
- [x] T1 The cause: `Skipper.setup()` reset its clock but kept its last manoeuvre's end, so no tack or gybe after R for as long as the race before had lasted (fixed 3ae30e9)
- [x] T2 Tests: `tests/unit/test_skipper_restart.gd`, one through the game's own R (f321f1f)
- [x] T3 The restart suite: 18 cases (R at six moments on SM1, PD3, O2): every board started, none early, none aground
- [ ] T4 Max's play-test (play folder `WindsurfingMMZB-play-8nov2026-restart`)
- [ ] T5 The open case: the rookie crawling after R on O2 in 2 of 18 cases (the sail let out, heeled to leeward; fine in a fresh race from the same spot): what outlives R
Notes: 8 Nov 2026 evening, branch `ai/skipper-heads-8nov`; report `Documentation/reports/racing/heads_8nov/RESTART.md`. Old code: R after 10 minutes or after the finish left 10 or 11 of 11 boards never starting, aground.

### E09.S19 · Trained and tested the way the game runs
Status: doing | Size: S | Owner: the lead | Milestone: M2 | Needs: — | Roadmap: —
Done when: every change to the skipper is checked through R (`--restart_after`), at the game's level (`--spread=0.5`) and from drops anywhere round the course (`--spawn=anywhere`), by one suite command, and the regression gate (E09.S08) includes it.
- [x] T1 The race tool's `--restart_after` and `--spawn=anywhere` (3ae30e9)
- [x] T2 One suite command: `tools/heads/random_suite.py` (every race drawn at random, the checks, the roundings, tune and hold-out sets, the live viewer; 9d8229f, 3657669, 60a73a0)
- [ ] T3 In the regression gate (E09.S08)
- [ ] T4 Phase A's gate: on a fresh hold-out of 200 races, 95 % pass every check, the roundings within E09.S23's limits
- [ ] T5 Phase B, the personas (`--phase=B`): the same loop
- [ ] T6 Phase C, fleets (when Max says): a `--fleet` draw (4 to 6 boards mostly, some 15 to 31) and the crowd's checks (penalties, starts in a crowd)
- [ ] T7 The menu's own options in the draw (E09.S24)
Notes: every training run before 8 Nov 2026 used fresh skippers and the sheets as written (spread 1, where the game uses 0.5), so the R bug was never seen. 8 Nov 2026 late evening: the method agreed with Max and written down (`Documentation/AI_TRAINING_METHOD.md`, the steps 0 to 11); the speed: 8 one-board races side by side on one logical processor per core, 4.2x real time each, 33x together, about 55 % CPU (about 100 to 150 races an hour); baseline_A (phase A, 300 races) started 21:19: at 43 races 25 passed every check, the start failed 16 times, a leg 8. The loop is taken the efficient way (Max: "needs to be taken when training AI from now on"): a fresh chat per loop, one wake-up per run (`tools/heads/suite_summary.py <run> --wait`), summaries not logs, small batches when the effect is big; about 50 to 100 thousand new tokens and 5 to 12 hours of machine time a loop.

### E09.S20 · The fleet's runs
Status: todo | Size: M | Owner: the lead | Milestone: M2 | Needs: — | Roadmap: RA20
Done when: in an 11-board fleet on SM1 the boards lose no more than 15 s each per run against the same boards alone in the same wind, without more penalties.
- [ ] T1 The measure: the fleet against each board alone with the lake's wind at the same moment (to tell the crowd from the wind)
- [ ] T2 Out of the line of the boards just behind on a run (a few degrees higher or lower) rather than a gybe (`dirty_air_on_runs` made no difference in 8 pairs)
- [ ] T3 The second run back through the boards still beating up
Notes: 8 Nov 2026 evening: against Hana alone, the start, the reach, the beat and the finish cost 0 to 14 s a board; the first run 28 to 44 s, the second 42 to 55 s. Every AI at its best (`--spread=0`) was hardly faster (about 10 s a board). Alone the best personas match Max's 9:43 on SM1.

### E09.S21 · Starts from anywhere
Status: todo | Size: M | Owner: the lead | Milestone: M2 | Needs: — | Roadmap: RA16
Done when: a board dropped anywhere round the course before the start sails the shortest way to the line and starts no later than the distance allows (within 20 s of the all-rounder's time from there), with no turn-back flips and no standstill falls.
- [ ] T1 The way to the line as a route (beat up to the run-in, then the start's plan) instead of switching between "back behind the line" and the plan; a slalom line along the wind approached from its downwind side (`start_free_beyond_ends_m` cut the flips 18 -> 8, not the time)
- [ ] T2 The slalom's wait no slower than the board stays up; a board at rest in its waiting spot gets going first (Bruno fell twice after R on PD3)
- [ ] T3 A tack that does not go: take the other tack and keep it (`change_slow_tack`, off: 1 of 32 drops rescued); a fleet test
- [x] T4 A long countdown not sailed away out of reach: `start_away_max_m` 200 m, on (9 Nov 2026, the random suite's hold-out: start 69 -> 72 %)
Notes: 8 Nov 2026 evening: 96 single drops (6 courses), 84 started within 4 minutes, none aground; 5 fleet races of 11 dropped anywhere, 54 of 55 finished. The lake's north-east corner: E01.S21. 8 Nov 2026 late evening: the start check failed in 16 of the first 43 baseline races (the check itself to be checked first: the start need from the all-rounder's expected time); O2 turned and shifted started 87 s late from behind the line. 9 Nov 2026 night (loops 3-4, `ai/skipper-heads-8nov` d467469): baseline_A complete, start 68 % (lake 40 % failed, open water 11 %). Lake failures: the way back behind the line or its extension from far away (an R or a drop on the course side: r0036 sailed west 100 s without coming nearer, at the gun 587 m off), sailing away far in a long countdown (45 % failed beyond 300 m: r0137 went 520 m and came back 42 s short), holding back too long. Taken: `start_away_max_m` = 200 (turn back 200 m from its spot): tune start 66 -> 70 %, hold-out 100 races start 69 -> 72 %, pass 63 -> 67 %, no check worse. Measured, off: `start_free_beyond_ends_m` = 100 in the suite (5 of 50 races changed, no gain). Next: T1's route back behind the line from far away (the biggest class). 9 Nov 2026 morning (loops 5-7, 429be92): with the cap on, the biggest start failure is a board stalled off its hold (14 of 43 in 150 races): a debug replay (r0007) showed the course for the line higher than the beam reach it held on, the stick hard toward the wind for 30 s at 2 m/s, the sail spilled, 2 m/s for 40 s. `go_reach_twa_deg` = 90 (speed first, then up for the line): hold-out start 72 -> 78 %, pass 67 -> 69 %, but legs 90 -> 86 % (7 worse, 0 better with the tune set; cause not found): off. Measured, off: `hold_floor_ms` 3 (start 70 -> 58 %), `get_going_twa_deg` 100 (legs worse). 9 Nov 2026 evening (phase S, the starts first, `ai/skipper-heads-8nov`): the suite's start-only races (`--phase=S`: one board, reachable drops, judged race by race with the sign test). baseline_S (200, tune seed 11): 73 % on time; late: crawling at the gun 24 of 54 (off the hold or beating back at 1.5 to 2 m/s with the stick hard toward the wind: the board does not turn and its sail draws at 1.5 to 4 deg), far behind 12, over early 9. `go_reach_twa_deg` 90 measured again: hold-out 13 fixed / 5 broken but the median after the gun 7.1 -> 9.4 s and three broken by its reach-first detour: off. Taken: `crawl_no_head_up_ms` 2.5 (stuck in the crawl for 4 s it lets go of the stick toward the wind until 4 m/s; not on slalom starts, not while the shore lookout steers): tune 7 / 0, hold-out (seed 23) 5 fixed / 0 broken, 78 -> 83 % on time (loop S2d; S2 to S2c, the first versions, broke starts or failed the sign test). Next: the reaching starts (PM1/SM1, the line along the wind: the hold runs at the line, `reaching_loop_excess_s`), the slalom dive's turn by a tack at speed (`slalom_dive_gybes`). 10 Nov 2026 night (loops S3 to S9): taken `crawl_go_stuck_s` 0 with `early_unlatches_go` (in the go off its hold the crawl rule lets go at once; about to cross early it stops going until its timing says go, instead of flipping between going and holding back every think): hold-out (seed 28) 7 fixed / 0 broken, on time 74 -> 81 %, median 7.2 -> 5.5 s. Measured, off: `reaching_loop_excess_s` (wins every PM1 reaching start on the open water, breaks lake starts by loops), `slalom_dive_gybes` (no gain), `crawl_in_timing` (5 / 1, chance), the release after 2 s (too weak). The slalom starts (a third of the late ones) flip both ways under every change tried: waiting at 0.5 to 1 m/s, a dive that cannot slow (its time 1.5 times the reckoning), a waiting spot 20 m from the line's extension, T2's start area in a lee at 8 to 10 kt: a redesign, for Max. The loop ended 10 Nov 05:15: on the same races as before the defaults went from 73.0 to 83.5 % on time (200, 22 fixed / 1 broken) and 69 to 85 % (hold-out 100, 16 / 0); a fresh hold-out of 200: 81.5 % on time, median 5.4 s after the gun. Gate (100 of 100) not reached. For Max: the slalom start's redesign, the reaching loop (open water only?), the rule for one broken start (S5 9 / 1 was blocked); the lake's light corners to E01.S21. 10-12 Nov 2026: the starts in company (three boards on one start), Max's slalom timed run and lag on course starts: E09.S25.

### E09.S22 · The AI carves its tacks and gybes with Shift
Status: blocked | Size: S | Owner: Max (the OK for the controller change), the lead | Milestone: M2 | Needs: Max's OK, Q50 | Roadmap: RA34
Done when: the AI's hands use the carve (Shift) inside their tacks and gybes as the player can, measured faster with no more falls.
- [ ] T1 The controller takes the AI hands' turn key in a manoeuvre (`PlayerController._turn_key_along()` returns 0 for AI hands today): a small controller change, Max's OK
- [ ] T2 The skipper carves where it pays; an A/B on the drops and the fleet races
- [ ] T3 First a check (HEAD_PLAN.md P2, step 1): the gybe's slowest speed and the speed kept at gybe marks in full slalom races (100 or more gybes), against the drills' (5.7 kt, 0.29 kept): is the drop off the plane the head's or the drill's?
- [ ] T4 The fin target for a gybe at a mark (Q50: Max's numbers or his own GPS)
Notes: 8 Nov 2026: the AI already uses Shift for its keep-clear turns, from 5 m/s (slower it threw sailors off). 13 Nov 2026 (the real race, `Documentation/reports/real_races/HEAD_PLAN.md` P2): in phase R's gybe drills with a beam reach after the mark (59, final check 82) the head's slowest point is a median 5.7 kt and it keeps 0.29 of its speed; real foil riders 9.9 kt and 0.70 (a foil keeps flying: not the fin's target); 8 such gybes in full races kept 1.16, hence T3 first.

### E09.S23 · Mark roundings and laylines
Status: review | Size: M | Owner: the lead; Max's play-test | Milestone: M2 | Needs: E09.S19 | Roadmap: RA31
Done when: on a hold-out of 200 random-suite races (`Documentation/AI_TRAINING_METHOD.md`) the distance out of the turn has a median of 15 m or less, the overstand on beats into a mark a median of 25 m or less, no gate turns more than 120 degrees beyond its way in and out, and no check gets worse.
- [ ] T1 The wide exits: out of the turn median 29 m, 92 % over 15 m (baseline_A, the first 43 races): the turn's start, rate and the heading after it (9 Nov: `round_early` measured, not taken; see notes). 13 Nov: `round_early` and `gybe_at_mark` on: 31 -> 19 m (90 -> 63 % over 15 m) in the full races; the goal 15 m not reached yet
- [x] T2 The overstands: median 51 m, up to 160 m (92 % over 25 m): the layline's margin, the lake wind's shifts, the tack's timing. 13 Nov: `mark_layline_margin_m` 3 on: median 26 -> 18 m (over 25 m 52 -> 34 %) in the full races; drills not overstood 84 -> 96 %
- [ ] T3 The gates: circling (691 degrees extra on SM1), the choice of the gate mark, the turn through it (13 Nov: not worked on; over 120 degrees 35 -> 38 % of the gates with the switches on, tune 3)
- [x] T4 Each change behind a switch; on and off on the tune set, confirmed on the hold-out (the method's steps 4 to 7; 13 Nov, rows R-1 to R-7)
- [x] T5 The rounding drill (`run_race.gd --round_drill=gybe|top`, `random_suite.py --phase=R`: one board before a slalom gybe mark or a top mark, from every angle) and the layline drill in company (`--phase=L`, three boards to one top mark), scored by the metres down the next leg at a fixed time (Max's "fastest gybe"; 1159df0, aba2aa2)
- [x] T6 `gybe_at_mark`, `round_early` and `mark_layline_margin_m` 3 on by default (Max's choice, 13 Nov; 33d049c)
- [ ] T7 Max's play-test of the roundings (with the new dirty wind, E01.S04): play folder `WindsurfingMMZB-play-13nov2026-roundings`
- [ ] T8 The branch `ai/roundings-13nov` merged (pushed 13 Nov; Max's word)
- [ ] T9 The gybe's shape from the real race (HEAD_PLAN.md P3): the turn begun a little earlier in turn radii (`round_early_lead_r`), the nearest point later in the turn (`round_apex_late`), out tighter; judged on gybe drills of one kind (a gybe mark, a beam reach after it), the drill's score first, the exit never against the race's own tactic (Max); best after E09.S22
Notes: Max, 8 November 2026: "weak point of the AI is now mark roundings: takes it very wide, overlays the layline by a lot, issues with gate roundings". Measured by `tools/heads/random_suite.py` at every mark and gate (closest approach, out of the turn, overstand, a gate's extra turning). 9 Nov 2026 night (loop 1, `ai/skipper-heads-8nov` d16e120): baseline_A complete (300 races): out of the turn 30 m (93 % over 15); the turn began only once the rounding counted (about 5 deg of it in the 6 s before the mark). The overstand's measure corrected (14fb96b): against the board's own close-hauled track, not 50 deg off the course's axis (on the lake the hour's wind does not blow along the course): median 31 m, not 58. T1: switch `round_early` (the turn begun before the mark, from the arc worked out at the controller's rates): tune 50 a side, out of the turn 26.3 -> 19.5 m, checks the same; hold-out 100 a side, 29.0 -> 21.1 m (94 -> 71 % over 15), closest 7.8 -> 6.2 m, gates 98 -> 81 deg, 722 s less racing; but finished, stuck, falls 1 to 2 races worse, aground 1, start 1 (known lake traps met on another line: r0092 the north-east corner E01.S21, r0046 T2's mark 3; none during an early turn). Not taken by the rule (no check worse); off, for Max to decide. Switch `gybe_at_mark` (gybe round a slalom mark, not after it) written, off, smoke races only. T3: a gate's extra turning partly counts the heading's wobble of a board stalled just after the gate (r0212: 9 to 0.5 m/s heading up on the lake's east side). 12-13 Nov 2026 night (`ai/roundings-13nov`, pushed): Max: "mark roundings are terrible"; "when comming from the wrong way when going upwind the over-lay the layline". The rounding drill (phase R, 3600 drills) and the layline drill in company (phase L, 1200 drills of three boards): the three switches win at the marks on tune 71, hold-out 81 and the final check 82, alone and together (together 164 better, 8 worse; not overstood 84 -> 96 %); margin 0 won the drills by a few metres but lost full races (pass never better, a check one or two races worse on every seed). Full races (phase A, seeds 3 to 7, 140 races): pass the same or better (70 -> 73 %, 77.5 -> 80 %); one race aground in the north-east corner (seed 6 r0009, E01.S21). On 9 November `gybe_at_mark` alone had lowered pass 60 -> 52 %. Max: "okay if its better with the switches on than do it": on. Dirty wind at the top mark is rare with the 20 m shadow (0.2 s a board, even three from one side). Every number: the training method's rows R-0 to R-7, L-0 to L-2. 13 Nov 2026 (the real race, HEAD_PLAN.md P3): gybe drills with a beam reach after the mark: the turn begins 1.10 turn radii before the mark (real foil 1.32), the nearest point at 0.29 of the turn (0.40), out of the turn at 1.04 radii (0.62), passing at 0.21 radii (0.22), 62 of 63 on the right side.

### E09.S24 · The menu race that did not race
Status: blocked | Size: S | Owner: the lead; Max for his menu choices | Milestone: M2 | Needs: Max's menu choices | Roadmap: —
Done when: Max's race from the menu (15 boards) is reproduced, its cause fixed with a test, and the AI races from the menu as from the launchers, checked by Max.
- [ ] T1 Max's choices on the race page: water, course, countdown, "Who", the level, whether R or the race director (M) was used, the first race of the session or not
- [ ] T2 Reproduced through the menu's own setup (the RaceSetup as `race_page.gd` builds it) in the real game, headless and sped up (`--fixed-fps 60`)
- [ ] T3 The cause fixed, with a test; the menu's options added to the random suite's draw
- [x] T4 The race page's countdowns 2, 3 and 5 minutes (Max; they were 30 s, 60 s and 3 min)
Notes: 8 November 2026, the late evening: from the launchers the AI raced, from the menu with 15 boards not (Max). Not reproduced: the real game with the menu's 15 personas (Aiko to Pia) raced normally on SM1, T2 and T1. The race page builds the same RaceSetup as the launchers. Max's session log was lost (the race tool's runs share the game's log folder of five files).

### E09.S25 · Starts in company: the fastest start (phase S3)
Status: review | Size: L | Owner: the lead; Max's play-test | Milestone: M2 | Needs: — | Roadmap: RA29
Done when: three boards on one start (the suite's phase S3) start on time at full speed and out of each other's dirty wind: the start's score (metres up the course 30 s after the gun) better than the old start beyond chance on fresh races, no check worse (or Max's choice), and Max likes it on his screen.
- [x] T1 The measure: metres up the course 30 s after the gun (`score_m`), the speed over the line, close together (`near_s`), the felt wind (79580d0)
- [x] T2 Three boards in the suite: `random_suite.py --phase=S3`, three copies of the general head, each its own start spot (c25afab)
- [x] T3 Max's slalom start: the timed run behind the line (`slalom_timed_run`, versions 2 to 5b; the night of 11-12 Nov)
- [x] T4 Dirty wind measured and judged: `dirty_s`, `wind_lost_s`; the check "clean wind" in place of "untangled" (8e9d421)
- [x] T5 The timed run in clean wind, version 6b (`slalom_run_clean_wind`); both on as Max's choice (a5de8ee)
- [x] T6 Each persona starts a course race on its own tack (`start_tack`: 13 starboard, 4 port, 3 either; 04646f0)
- [x] T7 The lag package on course starts only (`start_go_lag_s` 2, `early_holds_its_tack`, `start_dip`; af969cc)
- [ ] T8 Max's play-test: play folder `WindsurfingMMZB-play-12nov2026-starts6b`
- [ ] T9 Lag's final check on a fresh seed (on with 60 races a set), if Max wants it
- [x] T10 The branch `ai/starts-fleet-10nov` pushed (12 Nov) and merged into main (13 Nov 2026, through `merge/main-13nov`)
- [ ] T11 Bring the old validation test `test_living_skipper_fleet.gd` (written 21 October: 16 boards dropped at random round T2's 40 m slalom line, a 60 s countdown, every board across within 20 s of the gun) in line with the method, or retire it. On the merge of 13 Nov its T2 half fails (14 of 16 not started, 6 over early; T1 passes); on 10 Nov, before version 6b, it already had 5 late. It judges a different start from the method's (reachable drops, the game's countdowns of 2 to 5 min, `score_m`, clean wind), so it is no fault of 6b (Max, 13 Nov: "the 6b is the best ai for starts"). A known red until rewritten
Notes: 10 to 12 Nov 2026, branch `ai/starts-fleet-10nov` (af969cc, local). Every number in `Documentation/AI_TRAINING_METHOD.md` (phase S3, log rows S3-1 to S3-30, four reports); 7808 races in 91 runs. Max: "i prefer 3 seconds late at full speed than 0.2 sec but at half speed"; "it its not wrong if they are close togeter but there is one with dirty wind"; "6b is good i think"; "no lag on slalom / lag on course". The slalom start against the old start, four sets of 100 fresh races (tune 36, check 49, final checks 53 and 54): 3 to 5 times as far up the course 30 s after the gun (median about 240 m against 47 to 87 m), on time 78 % against 58 %, falls 2 % against 25 %; dirty wind 9 % of boards against 6 % (worse beyond chance on check 49 and final check 53; version 6, which moves more boards, failed only 53 but scored less). The dirty wind left: a third before the gun, a third in the first 10 s after it, a third on the reach (E09.S26). Lag on course races (tune 37, hold-out 50, 60 races each): better beyond chance on both, about 5 m further up the course, nothing worse. Seeds used: tune 31 to 37, hold-out 41 to 54. Open questions Q47 (a timed run for course starts?) and Q48 (the start's dirty-wind check until 30 s or about 5 s after the gun?).

### E09.S26 · Out of dirty wind on the reach after the start
Status: todo | Size: M | Owner: the lead | Milestone: M2 | Needs: — | Roadmap: —
Done when: on the reach after a start, a board in another's dirty wind gets out of it (bears away to clear its wind, or the faster board sails through by the rules): the seconds in dirty wind 10 to 30 s after the gun halved on fresh races, with no more penalties and no check worse.
- [ ] T1 The measure along the race, not only the start's 40 s (`dirty_s` per leg)
- [ ] T2 The leeward board clears its wind (bears away a little, or eases and crosses behind)
- [ ] T3 The faster board passes, to windward keeping clear or to leeward
- [ ] T4 Judged by the method's loop on race training's races
Notes: Max, 12 Nov 2026: "this is for race training and not start training". From the tracks of the slalom starts (version 6b, check 49 and seed 53): a third of the dirty seconds are 10 to 30 s after the gun, both boards on the same heading on the reach. E09.S20 T2 asks the same on the runs.

### E09.S27 · Real races as the head's yardstick
Status: review | Size: M | Owner: the lead; Max for the readings and the decisions | Milestone: M2 | Needs: Q49 | Roadmap: RA34
Done when: real race tracks are read with Max (a tracks-only picture, his marks, his reading), measured by fixed criteria that carry over from foil to fin, the head is measured by the same criteria on its own runs, the suite prints those measures every loop, and the plan for the head is agreed with Max.
- [x] T1 The tools: the GPX reader and the start finder (`read_gpx_race.py`), the virtual marks (`tools/real_races/courses/*.json`, `add_course_to_gpx.py`), the criteria (`analyse_roundings.py`), the head's runs by the same criteria (`ai_suite_measure.py`)
- [x] T2 The U17 Men final of the iQFOiL Youth & Junior Europeans 2026 (Metasail event 930) read with Max: the countdowns, the over-early start, the timed runs, his marks, the downwind leg
- [x] T3 The head measured on its runs on disk and the plan written (`Documentation/reports/real_races/HEAD_PLAN.md`)
- [ ] T4 The suite reports the real-race measures every loop (HEAD_PLAN.md P0): the line speed share, the final run, the turn start and exit in radii, the apex share, the slowest speed and the speed kept, in `HEADS_RESULT` and `suite_summary.py`
- [ ] T5 More real data (HEAD_PLAN.md P4): fin races with buoys, or Max's own GPS on Silvaplana (with the time, the gear and the wind)
- [ ] T6 Max's answers to Q49 and Q50
Notes: 13 Nov 2026 (`docs/real-races`): foil races, not fin (Max): only the measures that carry over (seconds, shares, sides, counts, metres in turn radii) are compared; exits depend on the race's own tactic (Max) and are compared only between like situations. Found: over the start line at 0.58 of its top speed (real 0.93 to 1.00); the last gybe 22 s before the line where a fin board needs 29 s to 90 % of its speed (real 56 s); the gybe at a mark (reach to reach) slowest 5.7 kt and 0.29 of the speed kept (real foil 9.9 kt, 0.70); the turn begun 1.10 radii out (real 1.32), the nearest point at 0.29 of the turn (0.40), out at 1.04 radii (0.62); downwind (130 degrees, 2 gybes a leg) and the mark sides fine. Metasail's GPX export refuses scripts and most files (a rider's name outside Latin-1 breaks a file; event 602, Silvaplana 2024, refuses all): `Documentation/reports/real_races/metasail_event930.md`.

### E09.S28 · The timed run arrives flat out (the slalom start, from the real race)
Status: todo | Size: M | Owner: the lead; Max's play-test | Milestone: M2 | Needs: E09.S27, Q49 | Roadmap: RA34, RA29
Done when: on phase S3's slalom races the speed over the line is a median 0.85 or more of the board's top speed in the 30 s after (6b: 0.58), and on a fresh hold-out of 100 races `score_m` is better than version 6b beyond chance (the sign test), with on time, over early, falls and dirty wind no worse beyond chance; Max likes it on his screen.
- [ ] T1 The switch `slalom_run_full_speed`: the last gybe at least `slalom_final_run_s` before the line (swept: 30, 40, 50 s; a fin board needs a median 29 s to 90 % of its speed after a gybe), the spare time taken by the earlier loops, no easing off in the last `slalom_run_no_ease_s` (about 15 s): the error left taken by the heading, not by luffing
- [ ] T2 Tune 50 new races, then a hold-out of 100 (the method's phase S3 loop); the numbers in the method's log
- [ ] T3 Max's play-test
- [ ] T4 Later, the same for course starts if Q47 says so
Notes: 13 Nov 2026 (HEAD_PLAN.md P1): version 6b over the line at 0.58 of its top speed (0.52 when on time), its final run a median 22 s; boards whose final run was 30 s or more eased off to 0.43. The real riders: the last gybe 46 to 60 s before the line, flat out for the last 15 to 20 s, 0.93 to 1.00 of their top speed. Max, 11 Nov: "i prefer 3 seconds late at full speed than 0.2 sec but at half speed".
