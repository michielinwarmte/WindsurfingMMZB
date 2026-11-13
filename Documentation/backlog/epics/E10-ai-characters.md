# E10 · The AI characters: the roster of fifty

Owner: Max for the names and the levels, the lead for the build | Roadmap: RA6, RA22, GR7, SO5 | Questions: Q27, Q28, Q29, Q30

**Goal.** Fifty AI sailors with a level and a persona each, named after the top slalom, course-racing, olympic and iQFOiL sailors of the last twenty years with their letters mixed up, from different countries, on their own brand's gear, so that in racing you remember the names.

**Done when (1.0).** A roster of fifty characters (men and women, Q29) with a name by the agreed rule (Q28), a nationality and flag, a home spot, a level (the world ranking's seeding) and a persona sheet (the skills, the style, the wind skills, the push, the gear brand, the look), shown in the results, the HUD, the standings, the beach and the interviews; a heat or a fleet is drawn from the roster by level and event entry; a small day-form draw keeps results from repeating; the real sailors' list stays outside `Game/` and the names pass the legal check (E18.S05).

**Where things stand (6 November 2026).** Twenty personas with invented names (Aiko, Bruno, Elin, Greta, Hana the pro, Ines, Jonas the rookie, Kofi, Lena, Liv the light-wind sailor, Mara, Marco the gambler, Noor, Pavel, Pia the beginner, Ravi, Sven, Tobias, Tomas, Yusuf), each with a sail colour, a home water, a one-line profile, eleven skills from 0 to 1, a style (start spot and style, pointing offset), light-wind and strong-wind skills and a brand for the sail, the board and the fin; a seeded day-to-day wander; a "Close: everyone can win" level squeeze; four characters (all-rounder, cautious, gambler, rookie). No nationality, no flag, no ranking, no memory across races, no look of their own, no name on the sail. The reference list of about 110 real racers 2006 to 2026 (PWA slalom men and women per year, IFCA, the Olympics, iQFOiL, Formula, the Défi, Lüderitz) with nationalities, results and gear brands is in `Documentation/reports/characters/real_sailors.md`.

## Stories

### E10.S01 · The source list in the project
Status: done | Size: S | Owner: the lead | Milestone: M1 | Needs: — | Roadmap: —
Done when: the real sailors' reference list with its sources is in `Documentation/reports/characters/real_sailors.md`, never in `Game/`.
- [x] T1 The research of 6 November 2026 saved with its caveats and sources
- [ ] T2 Max's additions (sailors he knows, Dutch names from the windsurf-archief project, the women's tours' gaps)

### E10.S02 · The naming rule and the fifty names
Status: todo | Size: S | Owner: Max | Milestone: M6 | Needs: Q29 | Roadmap: —
Done when: the rule (Q28 answered 6 November 2026: light mixing, two or three letters switched per name, chosen creatively so the name still reads well, and where the first and the last name share a letter that letter is used for the switch) is written, the fifty are chosen from the source list (about 30 men and 20 women, or as Q29 says, across the eras and the countries, the fifteen iconic ones in), each given its altered first and last name, and a test pins that no real full name is in `Game/`.
- [ ] T1 The rule, with three worked examples per level of mixing
- [ ] T2 The fifty chosen (a table: real name, altered name, nationality, sex, era, level seed, discipline, the brand mapping to the game's brands)
- [ ] T3 The test that no name from the source list appears in `Game/` (as the brands' test does)

### E10.S03 · The level and persona sheet per character
Status: todo | Size: M | Owner: the lead, Max for the levels | Milestone: M6 | Needs: E10.S02, E09.S05 | Roadmap: RA6, RA22
Done when: each of the fifty has a persona resource: the eleven skills set from the real sailor's profile (a legend's start and boat speed, an olympian's upwind sense, a speed sailor's push), the style, the wind skills, the push and the reaction time, the gear brands (the real sailor's makers mapped to the game's brands), the home spot, a look (E08.S04), and the ranking seed; the roster's spread of levels is checked with the persona matrix.
- [ ] T1 The sheet's new fields (nationality, ranking seed, era, discipline, look, home spot)
- [ ] T2 The fifty sheets written (an agent from the source list and the rule; Max's eye)
- [ ] T3 The persona matrix on three seeds: the top ten by level, the specialists visible (E09.S05)
- [ ] T4 The race page's draw by level and the mixed order (RA22)

### E10.S04 · Memorable: the name everywhere
Status: todo | Size: M | Owner: the lead | Milestone: M6 | Needs: E10.S03, E06.S10 | Roadmap: GR7, SO5
Done when: the name and the nationality are on the sail, in the standings, the results, the HUD's fleet list, the race card's "behind you", the beach, the interviews and the season's ranking; a profile card (the name, the flag, the home spot, the results so far, the gear) opens from any list; the other boards are heard near you (SO5).
- [ ] T1 The sail number and the national letters on the sail (E06.S10 T1); the name on the HUD at close range
- [ ] T2 The profile card
- [ ] T3 The fleet's sound (SO5)

### E10.S05 · Flags, home spots and sponsors
Status: todo | Size: S | Owner: the lead | Milestone: M6 | Needs: E10.S03 | Roadmap: —
Done when: each character has a flag, a home spot (a small advantage on home water in the day form?), and sponsors from the game's brands on the lycra and the sail, as the career's sponsors look (E14.S03).
- [ ] T1 The flags (a sprite set) and the home spot
- [ ] T2 The sponsor logos on the AI's gear and clothing

### E10.S06 · The roster in races and heats
Status: todo | Size: S | Owner: the lead | Milestone: M7 | Needs: E10.S03, E13.S03 | Roadmap: —
Done when: an event's entry list is drawn from the roster by the format and the spot (the whole roster at a world cup; fewer at a national event), a heat ladder is seeded by the ranking, and a free race lets the player pick any names.
- [ ] T1 The entry draw and the seeding
- [ ] T2 The free race's picker (any of the fifty, by level)

### E10.S07 · Form over a season, and later ageing
Status: todo | Size: S | Owner: the lead | Milestone: M7 | Needs: Q30 | Roadmap: —
Done when: a character's day form (a few per cent) follows a slow curve over the season with a seed, so streaks happen; ageing and retirements are a later story.
- [ ] T1 The form curve and its seed in the season save
- [ ] T2 Later: ageing, retirements, new names entering

### E10.S08 · The legal check of the names
Status: todo | Size: S | Owner: Max | Milestone: M7 | Needs: E10.S02, E18.S05 | Roadmap: —
Done when: the altered names are reviewed against the rule and the distribution plan (Q5) and signed off; any name too close is changed.
- [ ] T1 The review with the legal story's checklist
