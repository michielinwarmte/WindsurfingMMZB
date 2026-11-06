# E11 · Racing: the rules, the collisions, the formats

Owner: Max (the racing track), the lead for the build, Michiel for the contact physics | Roadmap: RA1, RA3, RA11, RA27, UI11, GR10 | Questions: Q9, Q31, Q32, Q33

**Goal.** Real racing: the sailing rules the classes actually apply, collisions that happen, every format the real tour sails (slalom elimination ladders, course racing with discards, the hybrid sprints, the long-distance race, the speed run, the time trial; all confirmed by Max and Michiel on 6 November 2026, Q31), the race committee that runs a day, and results and rankings that mean something.

**Done when (1.0).** The rules set of Q32 is implemented and tested; boards and marks collide (E01.S10) and the rules count it; the formats of Q31 exist with their real scoring; the race director's course maker works on every spot and in single player the AI committee runs the day; results, splits, penalties and rankings are shown and saved; Max's Stops from 0.1 (RA1) are done.

**Where things stand (6 November 2026).** A race with a countdown, the gun, OCS and going back, roundings by geometry (checked against the ten iQFOiL templates), splits, the clock, the place, the results table; the rules 10, 11, 12 and 18 (same tack), a geometric "touch" (centres within 2 m with the burdened board closing), a penalty turn or 20 s; T1 and T2 plus the ten iQFOiL templates on the lake and the open water; the race types (course, slalom, iQ hybrid, free sailing) with the slalom start upwind of the boat; the race director (the course edited live, the next start automatic); Max's buoys, bigger marks, striped pins; the race screen over the whole window; the time trial. No contact physics; no rules 13 to 17, no 19 to 21, no flags, no general recall, no protests, no series scoring; no elimination ladder, no long distance, no speed run; no results beyond one race.

## Stories

### E11.S01 · Collisions
Status: todo | Size: M | Owner: the lead, Michiel for PH12 | Milestone: M2 | Needs: E01.S10, Q9 | Roadmap: RA3, MP2
Done when: boards collide with each other and with the marks through the contact force, the touch is the rules' touch (no more 2 m geometry), "contact" shows on the HUD, the AI avoids contact as it avoids a foul, and it works over LAN.
- [ ] T1 The game's side of PH12: the contact event, the HUD, the rules' touch from the contact
- [ ] T2 The marks hit (rule 31: a penalty turn)
- [ ] T3 The AI's keep-clear reads the hull's shape, not the centre
- [ ] T4 LAN: the host judges the contact; the puppets show it (E12.S02)

### E11.S02 · The rules completed
Status: todo | Size: L | Owner: the lead, Max for the class's practice | Milestone: M3 | Needs: Q32, E11.S01 | Roadmap: RA1
Done when: the rules set the PWA and the iQFOiL class apply is in `race_rules.gd` with a test per rule: 10 to 12 (done), 13 while tacking, 14 avoiding contact, 15 to 17 acquiring right of way, changing course, proper course, 18 at the mark on both tacks and at gates, 19 obstructions, 20 room to tack, 21 exoneration, 31 touching a mark, the start's flags (I, Z, U, black), individual and general recalls, the finish, abandonment; penalties by the class (one turn or two, the 20 s), and a simple protest (the game's record decides, no hearing).
- [ ] T1 The rules list agreed with Max (the class's sailing instructions as the source)
- [ ] T2 Each rule built with its test and its AI behaviour
- [ ] T3 The flags, the recalls, the black flag; the sounds
- [ ] T4 The protest from the record; the scoring codes (DNF, DNS, OCS, BFD, DSQ, RET)
- [ ] T5 Max's Stops from 0.1: the shadow's feel, the 20 s, the AI's circle (RA1 F3)

### E11.S03 · Slalom elimination ladders
Status: todo | Size: L | Owner: the lead, Max for the format | Milestone: M2 | Needs: E09.S03, E10.S06 | Roadmap: —
Done when: an event runs eliminations as the PWA does: heats of 8 to 10 from a seeded ladder, the first places advance (the winners' round and, if chosen, the losers' round), a final, the elimination's points, up to three eliminations per event and the event's result from them with the class's scoring; the player sails only their own heats and can watch the others (or skip them, simulated headless).
- [ ] T1 The ladder's structure as a resource (the heat size, how many advance, the rounds)
- [ ] T2 The heats run one after another with the race director's gaps; the AI heats simulated headless when skipped
- [ ] T3 The scoring (the PWA's points per place per elimination, the event's result, the tour's result)
- [ ] T4 The ladder screen (the brackets, the player's next heat, the clock)
- [ ] T5 Played by Max on the lake's PD3 with the twenty personas

### E11.S04 · Course racing series
Status: todo | Size: M | Owner: the lead | Milestone: M2 | Needs: E11.S02 | Roadmap: RA27
Done when: a day of course races (the windward-leeward and the trapezoids, as the iQFOiL class sails them on fins here) scores a series with discards and the class's low-point system, with a medal race option, and the results table shows the series.
- [ ] T1 The series' scoring and discards as a resource
- [ ] T2 The race page and the office: a series of N races today
- [ ] T3 The results table for a series

### E11.S05 · Long distance and speed
Status: todo | Size: L | Owner: the lead | Milestone: M7 | Needs: E04.S07, E04.S14, E07.S10, Q8 | Roadmap: —
Done when: the Défi Wind's race (a 10 km leg along the beach out and back, 40 km, a start line of hundreds, the fin and the unlimited classes) and the speed run (a 500 m course with timing gates, the 2 s and 10 s bests) exist as formats with their scoring, and the fleet of hundreds runs within the frame budget by the rule agreed in Q8.
- [ ] T1 The long-distance format: the course along a beach, the far mark, the laps, the time limit, the start of hundreds
- [ ] T2 The crowd of hundreds: never by simplified physics (Max, 6 November 2026, rule 7); as many boards as the frame allows at full physics, the rest in waves of starts or flights
- [ ] T3 The speed run format and the records (E07.S10)

### E11.S06 · The course maker everywhere, and the committee's day
Status: todo | Size: M | Owner: the lead | Milestone: M4 | Needs: E04.S01, E05.S04 | Roadmap: MP10
Done when: every spot has its saved courses (the templates fitted and the real events' courses), the course maker opens from the tower and the race director's view on any spot, the race page offers the spot's courses, and in single player the AI committee sets the course of the day (E09.S10).
- [ ] T1 The courses folder per spot and the fitter on any depth grid
- [ ] T2 The course maker generic (today the wind viewer's and the director's view; the shared panel exists)
- [ ] T3 The race type selector on the race page too (the maker has it, the page not)
- [ ] T4 The director view's wind streaks fixed (off until V today)

### E11.S07 · Results, splits, penalties and rankings
Status: todo | Size: M | Owner: the lead | Milestone: M2 | Needs: E11.S04 | Roadmap: UI9
Done when: a race's results show the place, the time, the splits per leg, the penalties and their reasons, the gear sailed, the fall count; a series and an event show their tables; a ranking (the season's) accumulates; everything is saved to the profile (E13.S04).
- [ ] T1 The results record as a resource saved per race
- [ ] T2 The results screen with the detail per sailor (the splits and the penalties' reasons)
- [ ] T3 The ranking table

### E11.S08 · Later: replays and ghosts
Status: todo | Size: M | Owner: the lead | Milestone: later | Needs: E07.S08 | Roadmap: —
Done when: a race can be replayed from its saved states with the free camera, and a time trial can be sailed against the ghost of your best.
- [ ] T1 The state recording per race (the LAN's snapshot layout as the format)
- [ ] T2 The replay viewer; the ghost board
