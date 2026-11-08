# The board: where we stand, and the current sprint

Updated: 6 November 2026, 23:15 (the lead, Claude Fable 5.1), from the audit of the whole project and the team's answers of the evening; the sprint part on 8 November 2026, 00:30 (the lead, Claude Opus 5.5), after the 7 November work. Every session updates the sprint part at its start and its end; the "where we stand" part is rewritten at every release.

## Where we stand, 6 November 2026

**The headline.** Version 0.1.0 shipped on 21 October 2026, 23 days after the restart in Godot. Since then: 0.2.0-beta.1 to beta.3 (on hold or team-only), everything merged into `main` on 5 November (485eae5), and 173 commits of 6 November on `play/6nov-evening` waiting for Michiel's OKs and Max's checks. 73 sessions since 28 September; about 200 commits a week in the last three weeks; 955 unit tests (533 at 0.1.0), 48 validation tests of which 8 are red by decision. The night run of 6 to 7 November is racing the AI fleet on every iQFOiL course as this is written (two of twelve courses done at 22:45).

**What 1.0 asks for against what exists.** 173 stories in 18 epics, 649 tasks; 1 story done, 10 in review (the 6 November work waiting for the team's eyes and Michiel's OK), 2 blocked, the rest to do. Run `python -I tools/backlog.py` for today's numbers, or open the dashboard: `python -I tools/backlog.py --html` writes `Documentation/backlog/dashboard.html` (one page: the headline, who is waited on, the sprint, the milestones, the epics, every story with its tasks and filters); it is committed and pushed with the files, so every PC that pulls the branch has the same page (a Claude account's published copy cannot be shared across the company and private accounts). The milestones (M1 to M11) have no order; the tracks run in parallel.

| Epic | Exists today | Missing for 1.0 |
|---|---|---|
| E01 Physics | A 6-DoF simulation with sourced models for the sail, hull, fin, sailor, wind and lake chop; the dive after a crest; a 1 MB spec | A spin-out, the wind shadow simulated, legs that give, the hull over the hump, pumping, the gybe's flip, contact, the bottom, the sea (swell, tides, current), 8 red tests, the yardstick |
| E02 Waves and water | Lake chop in four trains (6 Nov, Michiel's OK pending), the look (whitecaps, foam, spray), SWAN installed but never run | Swell with groups, the bottom per spot, tides, currents, the shore break, the sea's look, the +2.3 ms found |
| E03 Wind | The Maloja measured and modelled (pattern, day, gusts, lee), the wind viewer, the course maker, the lake multiplier | A wind model per spot type, the generic terrain run, day types and climatology, the viewer on any spot, tactics tools, the sea's gust statistics |
| E04 Spots | Silvaplana (terrain, lakebed, photos, courses); the pipeline is Swiss-only and the lake is hard-wired in 15 files | The spot abstraction, the generic pipeline, Silvaplana's details, twelve spots in no set order, the props library, the download's size |
| E05 Beach | Nothing on foot (no character controller, no beach, no hut, no tower); the start menu with the open water behind it | All of it: the design, the character (third person), the hut, the tower, the beach start, the office, the coach, travel, the menu-less flow |
| E06 Gear | 17 made-up brands after the makers, 22 boards, 36 sails, fins at any depth, one Blender table, the Gear page, the AI on its gear | The brand list frozen, every model traced (the made-up names stay), every size numbered, masts and booms, the fins' planforms, the AI's gear choice, condition and registration |
| E07 Controls | Push on the keys and the mouse, the body on the mouse, interactive manoeuvres, the reflex, the time trial; gamepad in menus only | GD1 to GD7 decided, tuning by play, the ladder, the gamepad, the two-press gybe, pumping, chop timing, lessons, feedback after a fall, speed runs |
| E08 Sailor figure | A procedural figure posed by the physics (polished 6 Nov) | A rigged model, the manoeuvres' animations, customisation (65 to 100 kg), on-foot animation, the fleet's budget |
| E09 AI skill | The rule-based skipper and autopilot: every persona finishes T1 and T2; 8 of 10 lake courses clean; starts within 3 s on the two courses; neural brains that finish a course alone but are not race-ready | The neural brain as the racer (the goal): the training machine, the whole race learnt, one brain for fifty personas, every spot and condition, the default in the game; meanwhile the scripted skipper clean on every course and hour, the starts, staying on the board, the sea, every format, the regression gate, the committee |
| E10 AI characters | 20 personas with invented names and skill sheets; 4 characters; the research list of 110 real racers (6 Nov) | The fifty names by the light-mixing rule, their sheets and looks, the name everywhere, flags and sponsors, the roster in heats, form, the legal check |
| E11 Racing | A race with the gun, OCS, roundings, splits, results; rules 10, 11, 12, 18; a geometric touch; race types; the race director; the course maker | Contact, the rules completed, elimination ladders, series scoring, long distance and speed, the maker on every spot, results and rankings saved, replays |
| E12 Multiplayer | LAN for 2 proven on real PCs; up to 8, late join, the director, spectating built (one PC) | The real-PC test, the wind and collisions over the wire, an evening's stability with 8 PCs, every spot and format, internet (to decide) |
| E13 Season | Nothing | The design, the day draw, the event flow, the profile and the save, the notice board, the interviews, prize money |
| E14 Career | Nothing | The design session, money, sponsors, gear, the story, progression |
| E15 UI | The start menu, race, gear, settings, controls, LAN, credits, pause pages; the race screen over the whole window (6 Nov) | Max's eye on 6 Nov, the pages rewritten, the race page's formats, the in-world flow, the season and career screens, the gamepad everywhere, accessibility, languages |
| E16 Graphics and sound | The spray, chatter, gust patches, wind shading, board effects; synthesised sound with the fin's hum and the start signals; the sun fixed | The team's look and listen, the camera on Max's screen, the look per spot, the sea's look, the board's and the fleet's sound, music and voice |
| E17 Tech | 20 boards at 65 fps (release build), 955 tests, the release script, LFS; no CI; 300 MB zips; no licence | Fifty boards at 60 fps with the full physics (or the measured maximum), the minimum machine, the download, CI, the pipeline, saves, the second machine, hygiene, crash reports |
| E18 Project | The roadmap's 157 rows, the progress log, the lead-and-agents workflow, this backlog | The rest of the questions answered, main and 0.2 released, the sprint adopted, branch hygiene, the legal side, testers, the store page, the documents |

**The big risks the lead sees.** (1) The spots: twelve more at Silvaplana's depth is the largest block of work and the data abroad is thinner (no open bathymetry at eight of them); the generic pipeline (E04.S02) must come before any second spot. (2) The physics' reds: "correct for the player to feel" has no yardstick yet (Q7). (3) The sea: swell with a bottom, tides and currents are three new physics systems plus the hull's slam work (E01.S07) that gates them. (4) The neural goal: the brains are far from race-ready today (they lose minutes in company and pinch at 12 kt); it needs a dedicated training machine and many nights, with the scripted skipper carrying the game meanwhile. (5) Fifty boards with the full physics needs the remaining engine locks removed and perhaps a native sea; the measured maximum may land below fifty. (6) The beach is a new game inside the game (a character controller, interaction, animation) with nothing built; it decides the menu flow of everything after it. (7) The team's time: Michiel's OKs and Max's checks gate every physics change; batching them weekly keeps the agents from waiting.

## Sprint 1 · 7 to 13 November 2026 (proposed; the team confirms)

**Sprint goal:** the 6 November work checked, OK'd and merged into main; 0.2 released; the rest of the 1.0 questions answered.

### Now (doing)
- E18.S03 The backlog adopted: CLAUDE.md, ROADMAP.md and the document map point here; committed on `docs/backlog-1.0` and pushed (the lead)
- E09.S01 The night run read (the lead, when it finishes; parts A to F)

### Next (this sprint, in order)
1. E18.S01 The remaining questions answered (Max and Michiel, QUESTIONS.md: 32 of 46 open, Q46 the theme among them)
2. E15.S09 One theme for the game: Max and Michiel bring references, the lead mocks up one screen in each of three directions for the choice
3. E01.S01 Michiel's OK on the 6 November physics (the lake waves, the feet's press, the fall's bar, the fins' stiffness, the +2.3 ms)
3. The team's checks on the night3 build: E02.S09 (the water), E03.S01 (the lake wind), E06.S01 (the gear), E07.S01 (the controls and GD1 to GD7), E08.S01 (the figure), E12.S01 (LAN on two PCs), E15.S01 (the screens), E16.S01 (the look and the listen)
4. E18.S02 Main brought up to date and 0.2 released (the lead, after 2 and 3)
5. E18.S04 Branch and folder hygiene (the lead; Max decides on the folders)
6. E17.S07 and E09.S13 The second machine for the nights and the training (Max, Michiel): the first step of the neural goal
7. If time: E01.S03 the spin-out's model started (Michiel, from the research), E17.S04 CI

### Blocked
- E02.S02 SWAN: the five DLLs next to `swan.exe` (Max copies or allows)
- E01.S05 The dive after a crest against video: no video yet (Max)

### Waiting on whom
- **Michiel:** E01.S01 (the four OKs), E02.S01 (the seven wave decisions), Q7, Q9, Q10; from 7 November: E01.S19 (the two switches on `physics/realism-7nov`), E01.S17 (downwind), E01.S18 (the start's spin), E01.S20 (twist, legs, waves' cost); from 8 November: E01.S21 (the lake's north-east corner)
- **Max:** E09.S18 T4 (R in the play folder `WindsurfingMMZB-play-8nov2026-restart`), E09.S22 (the OK for the AI's carve), the merge of `ai/skipper-heads-8nov` (pushed 8 November), E07.S12 (the low-speed control and the push: the sign-off), the eight checks above, the open questions, the SWAN DLLs, the videos, the folders' fate
- **The lead:** the night run, the merge, the release, the roadmap rows and the progress log for the 6 November work

### Done this sprint
- 6 Nov: the audit of the whole project and this backlog (README, 1.0, QUESTIONS, BOARD, E01 to E18, `tools/backlog.py`); the research on the twelve spots (`Documentation/reports/spots/spot_dossier.md`) and the real racers 2006 to 2026 (`Documentation/reports/characters/real_sailors.md`); fourteen questions answered by Max and Michiel and folded into 1.0.md and the epics (Silvaplana the 13th, no foils, the neural AI as the goal, fifty boards if the physics stays, no order and no dates, third person, the made-up brand names, light name mixing, all formats, the backlog in the repository with ROADMAP.md kept); two more promises added late in the evening: the character with realistic joints, wetsuit, impact vest and lycra (E08.S02), and one visual theme for the game (E15.S09, Q46)
- 7 Nov: the night training (the player's steering, Shift carve, taps); the lake-speed training (stopped 23:25 on Max's word); the physics realism audit (`Documentation/reports/physics/realism_audit_7nov2026.md`): the hull's drag checked against Savitsky, the fin's plate-drag fault, the balance stance, both as switches for Michiel (E01.S19); the downwind issue (E01.S17); 100 % push and the low-speed control fixed (E07.S12, review); the session recorder (E17.S10); new stories E01.S18 to S20, E07.S12, E17.S10
- 8 Nov (`ai/skipper-heads-8nov`, pushed): the scripted skipper's heads trained on Silvaplana (night: 75 of 77 drops clean); racing each other without penalties (day: 46 -> 25 in the start rounds, 61 -> 29 in the fleet races; E11.S02 notes); the AI after R fixed (evening: every board starts after R, E09.S18 review); trained like the game (E09.S19); dropped anywhere and the fleet's speed measured (the runs cost 30 to 55 s a board each; E09.S20, E09.S21 new); E01.S21 and E09.S22 new; play folder `WindsurfingMMZB-play-8nov2026-restart`; report `Documentation/reports/racing/heads_8nov/RESTART.md`

## The sprints before this one

None: the backlog starts here. The history is in `Documentation/PROGRESS_LOG.md`.
