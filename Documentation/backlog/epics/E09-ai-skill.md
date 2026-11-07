# E09 · The AI sailors: the skill

Owner: the lead with agents; Michiel's PC for nights; Max's eye on the racing | Roadmap: RA1 to RA28, MP11, PH42, PH45 | Questions: Q26, Q27

**Goal.** AI sailors that can sail any course on any spot in any conditions: start well, round cleanly, keep off the shore, stay on the board, sail in a crowd by the rules, use the gear of the day, pump, and finish; the same physics and controller as the player (rule 7); fast enough for a fleet of fifty. **The trained neural network is the goal** (Max and Michiel, 6 November 2026, Q26): the brain races at 1.0; the rule-based skipper is its teacher, its fallback and its yardstick until the brain beats it.

**Done when (1.0).** On every spot and every race format, a fleet of the fifty characters (E10) races every saved course at every hour and wind band of the spot's climatology without groundings, with a fall rate within the budget (E09.S08), starts within a few seconds of the gun, and a results spread that reflects the characters' levels; the racers are the trained brains, each shaped by its persona's sheet (one strong brain, many personas: D3 of the archived fleet plan), beating the scripted skipper on the yardstick; the scripted skipper stays in the game as the fallback and the training's opponent; the autopilot suite is the regression gate for every physics, controller and brain change.

**Where things stand (6 November 2026).** The game's AI is the rule-based stack: the scripted skipper (the head: laylines, start plans, the slalom start, keep-clear by the rules, penalty turns, the shore lookout, the push off the wind) on the beginner controller and the autopilot (the hands), with twenty personas and four characters. Measured: every persona finishes the six T1 and T2 races alone (3 falls in 120); the polar per wind; the start within 3 s of the gun on both courses; on the lake, 8 of 10 iQFOiL courses clean, LR2 and LG2 with groundings in the shallows on the way to the leeward gate and boards crawling in the south-east lee band; the slalom start slower off the line than the old start; the 24 kt beam hold still catapults on 8 of 17 lake hours; tail-stands at walking pace before the start; penalty circles at reaching starts; catapults leaving a wind shadow in a crowd; the push falls on 24 kt bear-aways. The night run of 6 to 7 November measures the final code on every course (its first race: 11 finish, 0 aground, 1 fall, the median start 31 s late). The neural brains (PPO, stages S1 to S6, C1, C2) finish a course alone but are not race-ready; RA5 and RA14 are "later" (Max, 5 November). The stay-on-the-board work moved the fall's bar (Michiel's OK pending, E01.S01).

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

### E09.S03 · The starts
Status: todo | Size: M | Owner: the lead | Milestone: M2 | Needs: E09.S01 | Roadmap: RA27, RA20, RA23, RA11, RA16
Done when: on every course type the fleet starts within 10 s of the gun (the median under 4 s), with at most one OCS per twenty boards, no board outside the sailing area at the gun, no penalty circles in the first 30 s on a reaching start, and the 12 kt start no later than the 18 kt one by more than 5 s.
- [ ] T1 The slalom start off the line: the reach down from the row timed by the polar, the luffing wait, the go time (RA27's open numbers: 35 m, 140°; PM1 and SM1 as slalom starts?)
- [ ] T2 The crowd at the reaching start: the skipper chooses its spot and time knowing the others' (RA20, RA23)
- [ ] T3 The 12 kt start and the boards waiting raked back for minutes (Greta, Kofi, Jonas): pump out of the wait (E01.S09 T4)
- [ ] T4 The figure-of-eight hold for a line along the wind from far back (RA16), or the boards placed nearer in light wind
- [ ] T5 The countdown's length per format (RA11b: 60 s now; a slalom's 3-2-1 minute sequence as the PWA runs it)

### E09.S04 · Staying on the board
Status: todo | Size: M | Owner: the lead, Michiel for the physics causes | Milestone: M2 | Needs: E01.S01 T3 | Roadmap: PH45, PH42, RA17, RA20
Done when: the fall budget (E09.S08) holds on the lake and the open water at 12 to 24 kt in every persona's hands: the 24 kt beam hold, the tail-stand at walking pace, the windward roll out of irons, leaving a wind shadow at planing speed, the push on bear-aways, the penalty turn at speed.
- [ ] T1 The 24 kt beam reach held 45 s (8 of 17 lake hours fall): the cause from the fall records
- [ ] T2 The tail-stand at walking pace before the start (the buoyancy's pitch moment nearly awash: Michiel) and the windward roll out of irons
- [ ] T3 Leaving a shadow (with E01.S04 T3); the hold-back near a windward board in the last 10 s
- [ ] T4 The push on the 24 kt bear-away and run (RA17): ease before the bear-away, the gybe at 14 m/s
- [ ] T5 The reflex's chosen variant (from E09.S01 T3) and its fade above 80 % push kept for the player

### E09.S05 · The AI's push, and the specialists that show
Status: todo | Size: M | Owner: the lead | Milestone: M2 | Needs: E09.S04 | Roadmap: RA7, RA19, RA21
Done when: a persona's push level, reaction time and gybe timing are on its sheet and show in the results (a pusher wins in strong wind off the wind and falls more; a course racer beats a slalom pro on a beat and loses on a reach), with each persona's run angle from the race-tested best and the shifts read by its upwind sense.
- [ ] T1 The push and the reaction time per persona (RA7, PH25); the gybe's timing per persona through the held flip (E07.S05)
- [ ] T2 The course and slalom specialists (RA19): a per-sailor gybe, the run angle, the shifts
- [ ] T3 The polar per gear for the skipper's timing (RA21, with E06.S07)
- [ ] T4 The persona matrix as the proof (`tools/persona_matrix.sh` on three seeds)

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
