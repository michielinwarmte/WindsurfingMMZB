# E13 · The season: the tour, the weather days, the interviews

Owner: Max for the design, the lead for the build | Roadmap: — (new) | Questions: Q16, Q37, Q39

**Goal.** A full season like a real world tour: events at the spots over several days each, a chance of different conditions every day (lay days included), a world ranking, results that are remembered, a save, and the option to skip or simulate what you do not want to sail. Interviews with a Ben Proffitt-like reporter to reflect on your racing (optional).

**Done when (1.0).** A season of the agreed size (Q37) can be played from the first beach to the final ranking and saved after every race; each day's conditions are drawn from the spot's climatology (E03.S04) and the committee runs the day (E09.S10); the AI results are simulated headless when skipped; the ranking and the records persist in the profile; the interviews exist in their agreed form (Q39) or the story is dropped with the reason.

**Where things stand (6 November 2026).** Nothing exists: no calendar, no event, no ranking, no save beyond the settings and the time-trial bests, no profile, no interviews. The pieces it stands on: the race types and the director's back-to-back races (built), the climatology and the day draw (E03.S04, todo), the formats (E11, todo), the roster (E10, todo), the beach's office and board (E05.S06, todo).

## Stories

### E13.S01 · The season's design
Status: todo | Size: M | Owner: Max with the lead | Milestone: M7 | Needs: Q37, Q16 | Roadmap: —
Done when: `Documentation/SEASON_DESIGN.md` says: the calendar (which spots, in what order, how many days each), the formats per event, the day's flow (the draw, the committee's call, the races, the results), the scoring and the ranking, what can be skipped, the saves, how the career hooks in (money, sponsors), and the interviews' place.
- [ ] T1 The calendar and the formats (from the real tours: the PWA's slalom events, the iQFOiL's course events, the Défi, Lüderitz)
- [ ] T2 The day's flow and the skip rule
- [ ] T3 The scoring and the ranking (the PWA's and the class's systems as the source)
- [ ] T4 The saves and the profile (one slot per career, several free profiles?)

### E13.S02 · The day draw and the lay day
Status: todo | Size: S | Owner: the lead | Milestone: M7 | Needs: E03.S04 | Roadmap: —
Done when: each event day draws its wind band, sea state and sky from the spot's climatology with the season's seed, the committee decides what is sailed (course racing above 9 kt, sprints under 15 kt, nothing on a lay day, as the class's policies say), and the notice board shows the forecast of the next days.
- [ ] T1 The draw and the committee's rules per format
- [ ] T2 The forecast on the board (with its own small error)
- [ ] T3 A lay day's beach: the lessons, the gear, the interviews

### E13.S03 · The event flow
Status: todo | Size: L | Owner: the lead | Milestone: M7 | Needs: E13.S01, E11.S03, E11.S04, E10.S06, E05.S06 | Roadmap: —
Done when: the player registers at the office, sails the day's races in the format (the heats or the fleet races), sees the results and the event's table, travels to the next spot, and the ranking grows; skipped races are simulated headless with the roster's levels and the day's conditions; the save after every race.
- [ ] T1 The event state machine (registration, the days, the races, the results, the travel)
- [ ] T2 The headless simulation of skipped races (the race tool's results fed back)
- [ ] T3 The event's table, the ranking, the prize money
- [ ] T4 The travel between events (E05.S08) and the calendar's clock

### E13.S04 · The profile and the save
Status: todo | Size: M | Owner: the lead | Milestone: M4 | Needs: — | Roadmap: GP4
Done when: a player profile (name, look, the controls' level, the records, the lessons passed, the results, later the career) is saved in `user://` with versioning, several profiles can exist, and the time-trial records move into it.
- [ ] T1 The profile's format with a version and a migration
- [ ] T2 The records and the lessons; the results history
- [ ] T3 The profile picker (on the beach's first start)

### E13.S05 · The notice board and the calendar on the beach
Status: todo | Size: S | Owner: the lead | Milestone: M7 | Needs: E05.S06, E13.S03 | Roadmap: —
Done when: the board on every beach shows the season's calendar, today's draw and forecast, the event's results and the ranking, the sponsors' letters and the story's notes.
- [ ] T1 The board's panels fed from the season state

### E13.S06 · The interviews (optional)
Status: todo | Size: M | Owner: Max for the lines, the lead | Milestone: M8 | Needs: Q39, E13.S03 | Roadmap: —
Done when: after a race (or a day) a reporter asks two or three questions keyed to what happened (the start, a penalty, a fall, a win, the conditions) with templated lines written by the team, the player picks an answer, and the choice colours the sponsors' mood (E14) a little; or, if Q39 says so, a language model writes the questions at play time as an option.
- [ ] T1 The event hooks (what happened in the race) and the line templates (a few hundred, by Max)
- [ ] T2 The interview scene on the beach (the reporter character, the camera)
- [ ] T3 The optional generated version (an API key, offline fallback to the templates)

### E13.S07 · Prize money and the career's hooks
Status: todo | Size: S | Owner: the lead | Milestone: M8 | Needs: E14.S02 | Roadmap: —
Done when: the event's prize money, the ranking's bonuses and the sponsors' results clauses feed the career's wallet.
- [ ] T1 The money table per event and place
- [ ] T2 The hooks into E14
