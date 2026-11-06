# The open questions for 1.0

Written 6 November 2026 by the lead (Claude Fable 5.1) for Max and Michiel. Each question has a number, the options, the lead's recommendation and an empty **Answer** line. Answer in any form ("Q6: b", a sentence, "ask again later"); the next session moves every answer into [1.0.md](1.0.md) and the epics and strikes the question through here. A question is never deleted.

Numbers in the answers are better than words ("8 boards", "end of 2027"). Where the recommendation says *measure*, the answer can also be "measure it first".

---

## A. Scope, versions and the pace

### ~~Q1 · Is Silvaplana the thirteenth spot, or one of the twelve?~~ (answered)
Why it matters: your list of twelve does not name Silvaplana. Thirteen spots is one more big chunk of work; twelve means one of the list goes.
Options: a) 12 + Silvaplana = 13. b) Silvaplana is one of the 12, so one of the list drops. c) Silvaplana stays as the practice lake only, not a tour stop.
Recommendation: a. Silvaplana is built and is where the physics was tuned; it is a real course-racing venue (iQFOiL events). Keep it as the first tour stop.
Answer: a. Silvaplana is the thirteenth spot (Max and Michiel, 6 November 2026).

### ~~Q2 · The version ladder: do you agree with the order in 1.0.md (0.2 the sailor, 0.3 the race, 0.4 the sea, 0.5 the beach, 0.6 the gear, 0.7 the characters, 0.8 the tour, 0.9 the career, 1.0)?~~ (answered)
Why it matters: the order decides what gets built first and what the play-tests are about for months.
Options: a) As proposed. b) Swap two (say which). c) Your own order.
Recommendation: a, with one rule: the physics epic (E01) runs alongside every version, because you made it priority one.
Answer: No fixed order: the tracks run in parallel and several things are built at once; the plan uses milestones without an order instead of a version ladder (6 November 2026).

### ~~Q3 · When do you want 1.0, and how many sessions a week are realistic?~~ (answered)
Why it matters: the plan's size is about 190 stories. At the pace of the last three weeks (one or two sessions a day with agents) that is roughly a year of work; at one evening a week it is several years. A date fixes what has to be cut.
Options: a) A date (which?). b) No date; the order matters, not the clock. c) A date for 0.5 (the beach) only, then look again.
Recommendation: c. Aim 0.3 before Christmas 2026, 0.5 by Easter 2027, then re-plan with the pace you measured.
Answer: No dates (6 November 2026).

### Q4 · What is explicitly NOT in 1.0?
Why it matters: everything not on the list below will be asked for by a play-tester; saying no now keeps the plan honest.
Candidates to leave out: foiling (iQFOiL as foils), wave sailing and jumping, freestyle, wing or kite, VR, internet multiplayer (a relay server), consoles, Mac and Linux, a web build, mod support, online leaderboards, weather forecasts from the internet.
Recommendation: leave all of these out of 1.0 except internet multiplayer, which should get a decision in Q33.
Answer:

### Q5 · Where does 1.0 go: a free download on GitHub as today, itch.io, or Steam, and paid or free?
Why it matters: Steam needs a store page, a build pipeline, a price, legal names for the company, and it raises the bar on brand look-alikes and real sailors' names (Q16, Q25). Free on GitHub needs none of that.
Options: a) GitHub releases, free (as now). b) itch.io, free or pay-what-you-want. c) Steam, paid. d) Decide at 0.8.
Recommendation: d, but plan the legal questions (Q16, Q25, Q41) as if it were c, so nothing has to be rebuilt.
Answer:

---

## B. The physics (priority one)

### ~~Q6 · Foiling: are the iQFOiL courses sailed on foils in 1.0?~~ (answered)
Why it matters: the course templates are iQFOiL's, the sail model comes from an iQFOiL wind-tunnel study, but the gear list is slalom and free race fins. A foil is a whole new physics (lift off the water, the mast and fuselage, the foil's stall, flight height) and a new control problem; it is at least as big as the hull work of the last month.
Options: a) No foils in 1.0: course racing on fins with the iQFOiL course shapes. b) Foils in 1.0 as a second class. c) Foils after 1.0.
Recommendation: a, written in 1.0.md as "fin racing only"; c as the first thing after 1.0.
Answer: a. Not in 1.0; maybe a DLC later (6 November 2026).

### Q7 · What proves the physics is "correct for the player to feel"? Which checks must be green at 1.0?
Why it matters: today eight validation tests are red (accepted until the autopilot improves). "Realistic" needs a yardstick, or it is argued about forever.
Candidates: the eight reds green; polars against real boards' GPS data per wind strength; Max's on-the-water comparisons written as pass/fail checks; videos of real sailors over crests against the sim; a blind test (Michiel and Max cannot tell a logged real session's speeds from the sim's).
Recommendation: all of: the reds green (or each red replaced by a measured target with a source), a polar table per catalogue board and sail against published GPS speeds, and a written "feel checklist" that Max ticks on every physics release. The lead writes the checklist from his play-test notes so far.
Answer:

### ~~Q8 · The performance target: how many boards at 60 fps on which PC?~~ (answered)
Why it matters: "50 AI sailors" and "efficient physics" need a number. Today: 20 boards at 65 to 68 fps on the release build on Max's PC with the full lake waves (the editor build collapses at a few boards). PWA slalom heats are 8 to 10 boards; course racing fleets 20 to 50+.
Options: a) 50 boards at 60 fps on Max's PC (needs the native sea and the remaining engine locks removed: a big tech story). b) 32 boards at 60 fps, and bigger fleets sail in heats or with a lower physics rate for far-away boards (against rule 7: every board the same physics). c) 24 boards.
Recommendation: b for 1.0, with a minimum-spec laptop named by you (Max's laptop?) as the second test machine, and the 50 characters as a roster from which heats and fleets are drawn (Q24).
Answer: Fifty boards on the water is the goal if it can be done without making the physics less realistic; if not, the measured maximum. No simplified far boards (6 November 2026).

### Q9 · Collisions: what happens when two boards touch?
Why it matters: today boards sail through each other; the rules count a geometric touch as a penalty. "All the sailing rules and collision" could mean a rule only, or a physical bump.
Options: a) Rules only, no bump (today). b) A soft contact force: the boards push apart, lose speed, the sailor may fall (PH12 and RA3 in the roadmap). c) Full contact with damage to the gear (feeds the career's repair costs).
Recommendation: b for 0.3; c only as a career-mode option (Q35), because damage needs a gear-condition system first.
Answer:

### Q10 · Which physics items are must-haves for 1.0 and which are nice-to-haves? (The lead's split is in E01; tick or move.)
Must (lead): spin-out by ventilation PH6, the wind shadow simulated PH15, the dive after a crest checked against video PH43, legs that give in pitch and roll PH9, the slam on short waves PH10, pumping PH39, the gybe's flip PH4, the contact force PH12, running aground PH13, the hull over the hump PH16/PH30/PH31, the mast foot and fin from the board PH40.
Nice (lead): the yaw flutter PH38, the windward bank in a carve PH37, spray drag PH23, the buoyancy grid PH22, reset() leftovers PH21.
Answer:

---

## C. The waves, the wind and the spots

### ~~Q11 · Which spot comes next, and in which order do the twelve follow?~~ (answered)
Why it matters: the first sea spot proves the pipeline for every other; its data must be good and one of you must know the water.
Lead's proposed order: 1 Brouwersdam (home water, the best open data in the world: AHN lidar, Rijkswaterstaat depths, PDOK 8 cm photos; sea and lake side, tides, a dam, a beach you know), 2 Lago di Santa Croce (a lake like Silvaplana: the pipeline's second lake; Max already has a wind-data project for it), 3 Lake Garda Malcesine (lake, famous, Ora wind, big), 4 Gruissan (sea, flat-ish, the Tramontane, the Défi), 5 Bol (sea, Maestral), 6 Alaçatı (flat bay, thermal), 7 Bonaire (flat lagoon, trade wind, reef), 8 Pozo (sea, swell, shore break, strong trade), 9 Fuerteventura Sotavento (sea, tides, a lagoon at low tide), 10 the Gorge (river current, swell against the current), 11 Lüderitz (the canal and the bay; speed), 12 Japan (which spot? Q12).
Answer: No particular order: everything needs to be built (6 November 2026). The technical dependencies (the spot abstraction and the generic pipeline first) stay.

### Q12 · Japan: which spot?
Why it matters: "Japan" is not a spot. The research (`Documentation/reports/spots/spot_dossier.md`) found that Tsukuihama beach in Yokosuka (Miura, at the mouth of Tokyo Bay) has hosted the PWA World Cup every year since 2017 (slalom 2017 to 2019, the foil slalom finals 2022 to 2025); Omaezaki only appears as a wave event and Hayama is a club spot. Its wind is synoptic (no thermal), with many light days, a 1.5 to 2 m tide and typhoon swell at times; the land data is excellent, the bathymetry closed.
Recommendation: Yokosuka, Tsukuihama beach, unless one of you has sailed another Japanese spot.
Answer:

### Q13 · How "fully modelled" is a spot? Three levels; pick one as the 1.0 standard.
Why it matters: Silvaplana took about 20 sessions for its terrain, photos, lakebed, wind research and the viewer. Eleven more at that level is the biggest block of the plan.
Options: a) Silvaplana level everywhere: real terrain and lake or sea bed from open data, aerial photos, a measured wind pattern (station data plus satellite gust photos), the local landmarks. b) Real terrain and photos where the country has open data, a generic thermal or trade-wind model tuned by someone who knows the spot, landmarks by hand (fewer). c) Stylised spots: the shape of the bay and the mountains, a wind model, no photos.
Recommendation: b, with a per-spot "who knows this water" name in E04 (a local sailor to ask: five questions per spot, as the Silvaplana spot notes were).
Answer:

### Q14 · The sea: which of these effects must 1.0 have? Tides, currents (the Gorge is a river), swell from the ocean, shoaling and breaking on the bottom (SWAN), shore break at the beach, wind against current chop, water temperature and colour per spot.
Why it matters: each one is a physics story and a graphics story. The lake has none of them.
Recommendation: all of them, in this order: swell + bottom (0.4, SWAN per spot, computed offline), tides as a slow water-level and current field (0.4, needed for Brouwersdam and Fuerteventura), shore break as a look and a start-hazard (0.5 with the beach), the river current (with the Gorge).
Answer:

### Q15 · The wind per spot: measured like Silvaplana, or a model?
Why it matters: Silvaplana's wind came from a WindNinja terrain run, 22 satellite photos of gusts and a MeteoSwiss station. Not every spot has that. A thermal (Garda's Ora, Alaçatı, Santa Croce) and a trade wind (Bonaire, Pozo, Fuerteventura) behave differently from the Maloja.
Options: a) The Silvaplana method everywhere (terrain run + satellite gust photos + a station), weeks per spot. b) A wind model per type (thermal, trade, funnel, katabatic, river) with the terrain run for the direction field, and the strength and gust character from a station plus the local sailor's answers. c) One generic model, tuned by hand.
Recommendation: b, and the day types (light, medium, strong, the start of the thermal) become part of the model so the season mode can draw a day (Q14 of E13).
Answer:

### Q16 · Conditions that vary by day: should each spot have a climatology (a chance of each wind and wave state per month), so a season day is drawn like a real one, with lay days?
Recommendation: yes, a small table per spot (month × wind band × chance, from Windfinder statistics) and a "today" draw; the race director (AI) then sets the course for the day. The player can also pick the conditions by hand in free sailing.
Answer:

---

## D. The gear

### Q17 · Which brands, and which model year?
Why it matters: "the complete current range" needs a list and a frozen year, or it never ends. The gear research (GE1) covered eleven makers' 2025/2026 slalom and free race lines plus twelve more makers.
Options: a) The eleven of GE1 (name them in E06 and strike out any you do not want). b) Fewer (which?). c) More (which?). Model year: 2026, or 2027 when it is published?
Recommendation: a, frozen on the 2026 lines; the 2027 lines as a free update after 1.0.
Answer:

### ~~Q18 · Real names or the game's own names, with designs that look like the real ones?~~ (answered)
Why it matters: today no real maker's or model's name is in the game (a test enforces it). Look-alike graphics with made-up names is what football games did for years; it is legally safer than real names but not risk-free on Steam (trade dress). Real names need licences.
Options: a) Made-up names stay, the outlines and the graphics follow the real models closely (your "more to real life designs"). b) Ask the makers for permission (a letter each; some say yes to small games). c) Real names without asking (not recommended).
Recommendation: a now; b as a story in 0.8 once there is something to show them, because a yes gives real names and logos for free.
Answer: a. The made-up names stay, with designs that follow the real ones closely (6 November 2026).

### Q19 · "The complete range": every size of every slalom and free race board and sail (hundreds of items), or one model per line with its real sizes as numbers?
Why it matters: each model needs an outline, a deck graphic and a sail panel design; each size needs numbers (the physics) but can share the shape.
Recommendation: every model as its own look (outline and graphics), every size as numbers from the makers' published tables (the physics), the 3D shape scaled per size by the builder. Masts and booms per sail size as numbers; a fin per brand with the slider as now.
Answer:

### Q20 · Does the Gear page go away when the gear hut exists (Q31), or do both stay?
Recommendation: both until 1.0's beach is on every spot; then the page stays as the quick way (the pause menu) and the hut is the world's way.
Answer:

---

## E. The player's controls

### Q21 · The control ladder: fixed levels, or assists you switch off one by one?
Why it matters: "interactive, learnable and progressable" needs a shape the player can see. Today: beginner (push on W/S, A/D steer), body on the mouse (feet), the manoeuvre cues, and advanced (raw rake, tilt, weight).
Options: a) Four named levels (1 Autopilot: steer only; 2 Push; 3 Push and body; 4 Manual) and the game names the level on the HUD. b) A list of assists (auto-sheet, balance reflex, auto-flip, auto-rail...) each on or off. c) Both: the levels are presets of the assists.
Recommendation: c. The levels are what a new player sees; the list is what Michiel tunes and what a pro turns off.
Answer:

### Q22 · Does progress unlock controls, or is everything open from the start?
Options: a) Everything open; the levels are a free choice. b) The career unlocks levels by results or a coach's lessons; free sailing has everything open. c) Lessons on the beach (a coach) teach each level, with a certificate, but nothing is locked.
Recommendation: c, with b's unlock only inside the career mode.
Answer:

### Q23 · Gamepad: full sailing on a gamepad in 1.0?
Recommendation: yes: the left stick steers, the triggers push and ease, the right stick is the body, the face buttons the manoeuvres; menus already work. Steam Deck is then free.
Answer:

### Q24 · "Fun on long straights": which of these are in 1.0? Reading gusts on the water and easing in time (exists), the rail and trim on the mouse (exists), pumping onto the plane (PH39), absorbing chop with timing (GP7), speed runs with a GPS-style best-speed record per spot, a wind-shadow duel (covering an opponent), the sail's trim by hand on a reach (outhaul and downhaul on the beach only).
Recommendation: all but the last; the speed record is cheap and makes Lüderitz a spot.
Answer:

### Q25 · The tutorial: a coach on the beach, in-game lessons (the How to sail page today), or both?
Recommendation: a coach on the beach with five lessons that mirror the ladder, each a two-minute drill with a pass mark; the text page stays as the reference.
Answer:

---

## F. The AI sailors

### ~~Q26 · "Fully trained": the rule-based skipper made excellent, or the neural brains?~~ (answered)
Why it matters: the scripted skipper with its personas sails every race today; the neural brains finish a course alone but are not race-ready (RA5) and need Michiel's PC for nights. The user said "train the autopilot = the rule-based autopilot" on 6 November for the chop; this asks it for the whole plan.
Options: a) Rule-based only; the neural work stops. b) Rule-based for 1.0, neural kept as a research line that may replace parts (the start, the gybe) if it beats the rules on a yardstick. c) Neural is the goal.
Recommendation: b, with a yardstick story (E09.S09) so a brain earns its place by numbers.
Answer: c. The neural network is the goal for 1.0 (6 November 2026). The rule-based skipper stays as the teacher, the fallback and the yardstick until a brain beats it (E09.S09 and E09.S13 to E09.S17).

### ~~Q27 · Fifty AI characters: on the water at once, or a roster?~~ (answered)
Options: a) A roster of 50 names; a race takes a heat of 8 to 12 (slalom) or a fleet of up to 32 (course), drawn by level and by who entered the event. b) 50 on the water at once (needs Q8 a).
Recommendation: a.
Answer: See Q8: fifty on the water as the goal if the physics stays as it is; the roster of fifty either way (6 November 2026).

### ~~Q28 · The names: how far from the real ones?~~ (answered)
Why it matters: "mixed-up letters" can be light ("Antonie Ablaeu") or a new name with the same sound ("Tony Ableau"). The lighter it is, the more it reads as the real person, which is the fun but also the legal risk (Q5).
Options: a) Light: two or three letters swapped, the nationality kept. b) Medium: a new first name, the surname altered, the nationality kept. c) Heavy: new names in the style of the country, the real sailors only as the inspiration for the level and the style.
Recommendation: b for the men's and women's tours, and the real sailors' lists kept in the project as the source (E10 notes), never in the game's files. Nationality flags: yes.
Answer: Light mixing is OK; be creative about which letters to switch, and where the first and the last name share a letter, use that letter for the switch (6 November 2026).

### Q29 · Men and women in one fleet, or two tours?
Recommendation: one roster with both; the season mode (Q34) decides who enters which event; free races mix freely. Women's results and names as prominent as the men's.
Answer:

### Q30 · Do the AI characters change over a season (form, learning, ageing, injuries), or are they fixed?
Recommendation: fixed levels for 1.0, with a small day-form draw (± a few per cent) so the same name does not win every race; ageing and careers after 1.0.
Answer:

---

## G. Racing

### ~~Q31 · Which race formats are in 1.0?~~ (answered)
Candidates: slalom elimination ladders as the PWA runs them (heats of 8 to 10, winners and losers' rounds, up to three eliminations per event); course racing fleets with discards (iQFOiL style on fins); the hybrid sprints (US3/US4, PM1/SM1); a long distance race (the Défi Wind: 40 km along the beach, hundreds of boards); speed runs on a 500 m course (Lüderitz); a time trial.
Recommendation: all of them, with the elimination ladder and the long distance as the two new big stories; the Défi's hundreds of boards as a special case with far boards simplified only if Q8 allows no other way (Michiel's call).
Answer: All of them: the slalom elimination ladders, the course racing series with discards, the long-distance race and the speed runs, the hybrid sprints and the time trial (6 November 2026).

### Q32 · The rules: how complete?
Today: port and starboard, windward and leeward, clear astern, room at the mark, OCS and going back, a penalty turn or 20 s. Candidates: the whole of RRS Part 2 as the class uses it, rule 42 (pumping limits; windsurfing has exceptions), black flag and the U flag, general recall, a protest with a jury verdict after the race, exoneration, the finish line's rules, the race committee's abandonment.
Recommendation: the Part 2 set the PWA and the iQFOiL class actually apply, the flags and the general recall, and a simple protest (a verdict from the game's record of the touch); no jury hearings.
Answer:

### Q33 · The race director in single player: who sets the course of the day?
Recommendation: the AI race committee sets it from the spot's templates for the day's wind (the season), and the player can walk to the tower and change it in free sailing and in LAN.
Answer:

---

## H. The beach and the world on foot

### ~~Q34 · On foot: first person or third person? And can the player's sailor be customised (sex, size, weight, clothes)?~~ (answered)
Why it matters: the sailor's weight is a physics number (80 kg today); a customisable sailor changes the physics and every polar. Third person needs the walking animations; first person needs none but shows no character.
Options: a) Third person, the sailor figure, customisable within limits (65 to 100 kg feeds the physics; the look is free). b) First person on the beach, third person on the water. c) Third person, fixed sailor.
Recommendation: a, with the weight as the only physics-relevant choice and the polars measured at three weights.
Answer: a. Third person, customisable, the weight 65 to 100 kg into the physics (6 November 2026).

### Q35 · What can you do on the beach in 1.0? Tick: rig up and change gear at the hut (walk the gear there); carry gear to the water and beach-start; walk to the tower (the wind viewer); set the course (the race director's table); talk to the race office (enter a race, see results); talk to sponsors (career); the coach (lessons); a notice board (the forecast, the season's calendar); travel to another spot (the only loading screen); the settings as a pause menu; sit and watch a race from the beach; other LAN players walking around; day and time control.
Recommendation: all but "other LAN players walking around" and "sit and watch" (both after 1.0); the travel board as the one loading.
Answer:

### Q36 · The beach start and the water start: does the player walk the board into the water and beach-start (a new physics state: standing in shallow water with the gear), with a water start after a fall as today?
Recommendation: yes, as a short scripted step that hands over to the physics at knee depth, not as a full walking-in-water simulation.
Answer:

---

## I. The season, the career and the interviews

### Q37 · The season: how big, and can you skip?
Candidates: 8 to 13 events (one per spot), 3 to 5 days each, one to three races a day depending on the wind draw, a world ranking, prize money that feeds the career, a save after every race, "simulate this race" or "skip the day" for the ones you do not want to sail, the AI racing each other in the background for the results.
Recommendation: an event per spot, 4 days each, the wind draw deciding how many races are sailed, skip allowed (the AI results simulated headless), one save slot per career.
Answer:

### Q38 · The career: how deep for 1.0?
"Need further planning" was your note. The lead's reading of the minimum: a start as a one-rig sailor with little money, entry fees and travel costs, prize money and a few sponsors with simple conditions (results, a brand to sail), buying and registering gear (a quiver limit per event, as the PWA registers gear), condition that wears and can be repaired, a story told in a few scenes.
Options: a) That minimum in 1.0. b) Less: money, sponsors and gear only, no story. c) More: a written story with characters (who writes it?).
Recommendation: a, with the story as short texts on the notice board and in the interviews, written by Max.
Answer:

### Q39 · The interviews (the Ben Proffitt-like reporter): templated text, or generated?
Options: a) Templated: a few hundred lines keyed to the result and the race's events, written by the team. b) Generated by a language model at play time (needs the internet and an API key; costs per play). c) Both: templated offline, a generated version as an option.
Recommendation: a for 1.0; voice later. Optional as you said: it is the last story of E13.
Answer:

---

## J. The process, the tools and the legal side

### ~~Q40 · Keep ROADMAP.md as the detailed ledger with this backlog on top (the lead's choice), or move everything into the backlog and archive ROADMAP.md?~~ (answered)
Recommendation: keep both for 0.2 and 0.3; at 0.4 move the open rows into the stories and archive ROADMAP.md.
Answer: Keep ROADMAP.md as the detailed ledger under the backlog (6 November 2026).

### Q41 · The sprint: one week from play-test evening to play-test evening, with Max as the product owner (what and in which order), Michiel as the physics owner (what is true), the lead running the agents? And Tarpie?
Answer:

### ~~Q42 · The tool: this folder in the repository (the lead's choice), plus a rendered page for reading? Or a real tracker (Linear, Notion, GitHub Projects) connected to Claude?~~ (answered)
Recommendation: the folder; it travels with the branches and every AI session can read it. A rendered page can be generated from it when you want one.
Answer: The folder in the repository; committed and pushed on 6 November 2026 on the branch docs/backlog-1.0.

### Q43 · Legal and credits: who checks the open data licences per country (each spot's credits line), the brand look-alikes and the scrambled names before a public release? Is a short "legal check" story at 0.8 enough?
Answer:

### Q44 · The game's name at 1.0: "Windsurfing Simulator", "WindsurfingMMZB", or a new name?
Answer:

### Q45 · Agents and budgets: how many agents at once (three today), and which PC runs the training nights and the SWAN runs? Is there a second machine for the long runs so Max's PC stays free for play-tests?
Answer:

### Q46 · The game's visual theme: which direction?
Why it matters: Max, 6 November 2026: "the UI and main menu is very AI-like; we need to pick a theme for our game to make it more united." A theme chosen now shapes every screen that follows (the beach's panels, the season, the career), so it is cheaper to pick it before they are built (E15.S09).
Options: a) The race-broadcast look of a PWA live stream (dark panels, bold numbers, flags, the sponsor strip). b) A beach-club and surf-poster look (warm colours, hand-drawn type, wood and canvas). c) A clean instrument look like a sailing watch or a chartplotter (light panels, one accent colour, thin type). d) Your own references (links or photos).
Recommendation: a for the race screens and c for the settings is the usual compromise, but one theme everywhere is what you asked for: bring three references each to the next session and the lead mocks up one screen in each (E15.S09 T1).
Answer:
