# The slalom week, live: 64 sailors in brackets, never more than 16 on the water

Status: **plan, Max's decisions in** (27 November 2026, see "Max's answers"); the build is not started. Nothing of this is built. It stands on tonight's broadcast work ([PLAN.md](PLAN.md)) and ties together backlog stories that already exist: E11.S03 (slalom elimination ladders), E13.S03 (the event flow), E10.S06 (the roster in heats), E11.S07 (results and rankings), E11.S09 and E11.S11 (watch mode and the TV director), E16.S06 (the commentary).

## What Max asked

27 November 2026: "i want to simulate the whole slalom week with eliminations with 64 people in brackets all live broadcasted with smart loading in and out sailors to keep the game running max 16 sailors max. this needs good planning so you can do that now".

## The goal

You start "the Sotavento week" and watch it like the stream: every heat of every elimination, filmed by the TV director, called by the commentator, with the ladder filling in and the event's ranking growing, until there is a champion. The PC never sails more than 16 boards at once, however many sailors are entered. You can watch at the stream's pace, speed it up, or jump ahead, and close the game and go on later.

## How a real slalom week runs

From the sport's practice and tonight's replays. **Step W0 checks every line of this** against the PWA's rule book and the 27 hours of commentary, where he explains the format many times.

- **One elimination with 64 sailors is 16 heats** of 8: eight first-round heats, four quarter-finals, two semi-finals, then the losers' final (places 9 to 16) and the winners' final (places 1 to 8). The first four of a heat go through.
- **The ladder is seeded** by the ranking: the first elimination from the world ranking, the later ones from the event's standings so far.
- **Each elimination gives points** (the winner the fewest), and the worst results are dropped as the week goes on (the commentator in Elimination 7: "discarding two second places").
- **A week holds as many eliminations as the wind allows.** Fuerteventura 2026: 11 for the men over 5 race days, so two or three a day. No wind: no racing that day.
- **Three kinds of race that week:** normal slalom, slalom with an obstacle to jump, and a long-distance race with the whole fleet on one line.
- **A heat on the stream** (measured tonight on nine heats): 90 s before the start (the line-up card, the riders named), about 190 s of racing, then results and talk. While a heat races, the next heat is already on the water near the start.

## What the game has, and what it lacks

| Have | Lack |
|---|---|
| A heat: 8 AI boards on a slalom course with a slalom start, places, a finish | Anything above one race: no ladder, no heats in a row, no event, no ranking, no save |
| Watch mode, the TV director (being set to the stream tonight), the commentary as subtitles (built tonight) | The pictures and the talk between heats: the line-up card, who goes through, the ladder, the standings |
| 20 AI characters with skills, gear and sail colours | 64 sailors with names, countries and flags (the backlog plans fifty: E10) |
| Sotavento with the PWA event site and the course rebuilt from the replays (branches, not merged) | An AI that sails that course well: tonight 2 of 6 boards started 19 and 27 s late |
| 17 AI boards at 60 pictures a second on open water (measured 13 November, release build) | The same measurement at Sotavento, whose sea costs more |
| Fast forward up to 8 times in watch mode; a race sailed without a screen (`tools/race.sh`) | Heats sailed in the background while you watch another |

## The design in six parts

### 1. The week's book-keeping (no pictures)

A plain piece of logic, tested without the game's pictures: the entry list, the seeded ladder, who goes through, the places of the ones knocked out, the points, the dropped results, the standings, the days. It can run a whole week as text in seconds with made-up heat results, which is how it gets tested. It is saved after every heat, so a week can be closed and picked up again.

### 2. Sixteen on the water: who is loaded when

Every AI board sails the full physics (the team's rule: no cheap boards), so the limit is boards on the water, not sailors in the event. A sailor is in one of five states:

| State | Costs a board? | What you see |
|---|---|---|
| On the beach | no | a rigged sail on the sand at the event site (the site already draws thirty) |
| Sailing out to the start | yes | the next heat leaving the beach |
| Waiting near the start | yes | the next heat hovering behind the line, as on the stream |
| Racing | yes | the heat |
| Sailing in | yes, until the beach | the finishers coming home; then back to a sail on the sand |

The budget: **8 racing + 8 of the next heat = 16.** When the player sails in the week (D1), the player's board is one of those 16: one of the 8 in its own heat, and loaded early enough to sail out to the start like the others. The rules that keep it there:

- A sailor is loaded only when a place is free; the heat after next waits on the beach.
- A finisher frees its place when it reaches the beach, or sooner when no camera is on it. With the short time between heats (D4) most finishers are freed on the water right after the finish, off camera, and not sailed home. Nothing appears or vanishes in the picture: the TV director knows what is on screen, and loading happens outside it.
- The 16 boards are made once and re-dressed (name, sail, gear, skills) for each sailor, so a new sailor doesn't cost a stutter.
- A board that falls and can't finish in time is retired by the race committee, as in a real heat, so one swimmer can't block the next heat.
- Whether 16 holds at Sotavento is **measured first** (step W0). If the PC only manages 12 there, the next heat comes out later; the picture stays the same.

### 3. Heats you don't watch

Sixteen heats at the stream's pace is about two hours for one elimination, and a week has up to eleven. So:

- **Fast forward** (2 to 8 times) exists.
- **Jump ahead** ("to the quarter-finals", "to the final", "to tomorrow"): the heats in between are sailed by the real AI without pictures, in the background, as fast as the PC can. That keeps every result honest: the same sailors, the same physics, the same wind. The backlog already asks for this (E13.S03 T2).
- The other way would be to draw skipped results from the sailors' levels: instant, but then a skipped heat isn't a sailed heat. See decision D2.

### 4. The broadcast between the heats

The stream's rhythm, with tonight's measured numbers: the line-up card while the commentator names the eight (about 40 s), the beach camera wide on the line, the race, the winner sailing in, "who goes through", the ladder, the next heat. After each elimination: the result and the event's standings.

This needs:
- **Graphics:** the line-up card, the ladder, the heat's result with the four who go through, the standings with the dropped results. This is phase P5 of the broadcast plan (the stream's look, as the VWA), which this feature now needs.
- **New commentary moments:** naming the heat, who goes through and who is out, the standings, the fight for the title. The 27 hours are full of exactly this talk. The bank left it out as "talk about that week"; with a simulated week the game has its own standings, so these lines can be used, with gaps for points and places.
- **The TV director between heats:** it has the before-the-start and after-the-race phases from tonight; they get the next heat and the beach to film.

### 5. The 64 sailors

The game has 20 characters; the backlog plans a roster of fifty with names made by the team's rule, a country and a flag (E10.S02, Max's). For 64 there are two ways: make a provisional roster now (skills spread around the existing characters, placeholder names, countries, the game's gear brands), or wait for the real roster. See decision D3. Countries also unlock the commentator's "the Italian", "the Frenchman" lines, which are skipped today.

### 6. The week itself

Days with wind drawn per day (strong, normal, too light to race), two or three eliminations on a race day, the standings carried over, a champion at the end. Until Sotavento has its own day types (the spot's plan, P5) the draw is a simple one.

## The steps, each ending with a stop for Max

| Step | What | Max sees at the end |
|---|---|---|
| **W0** Facts first | The real format from the rule book and the commentary (seeding, who goes through, points, dropped results, time between heats). How many boards Sotavento holds at 60 pictures a second. How reliably the AI sails a heat on the rebuilt course (finishers, late starts). | A short report, and the decisions below answered |
| **W1** The book-keeping | The ladder, the points, the standings, the save; a week run as text | A printed week: every heat, every ladder, the champion |
| **W2** Heats in a row, 16 on the water | The loading rules, the next heat waiting, the finishers sailing in, the retire rule; watch mode at Sotavento | Three heats in a row on your screen, never more than 16 boards |
| **W3** Close and go on | The week saved after every heat and picked up where it was (the jump over heats is dropped: D2, all live) | A week closed in the middle of an elimination and going on from the next heat |
| **W4** The broadcast | The line-up card, the ladder, the results, the standings; the new commentary moments; the director between heats | An elimination that looks and sounds like the stream |
| **W5** The week | The days and the wind, eleven eliminations, the dropped results, the champion | The Sotavento week from the first heat to the champion |
| Later | The play-test of sailing in it yourself (built along from W2, D1). The women's fleet. The obstacle and the long-distance race. Interviews (E13.S06). Other spots. | |

Size: W1 and W3 are a session each for one worker; W2 and W4 are the big ones (two workers each); W5 is small once the others stand. Five to seven sessions in all, not one night.

## What can go wrong

- **The AI on this course.** A heat where two boards start half a minute late is not a World Cup heat. The AI needs its own training on the rebuilt Sotavento course, by the training method, at night, on your go. Without it the week runs but looks poor. This is the biggest risk and it is not part of the steps above.
- **The gybes.** Tonight's finding: the AI's gybes drop from 23 knots to 3 or 4. The commentator will never have a good gybe to call until that improves (the AI track).
- **Sixteen boards at Sotavento.** The swell makes the sea cost about half as much again as open water. Measured in W0, not assumed.
- **No collisions yet** (E11.S01). Eight boards at the first mark pass through each other's space as they do today.
- **The branches.** Sotavento, its water and its course, the TV director and the commentary are five branches that are not in main. W1 can start on main; W2 needs them merged, which needs your look and Michiel's OK on the sea's physics.

## Decisions for Max

- **D1 Watching, or sailing in it?** (a) First only watching: the week as a broadcast. (b) You are one of the 64 from the start. *Recommended: (a); (b) is the "later" row and joins the season (E13).*
  **Max, 27 November 2026: "watch and play but test only watch".** So the week is built for both: you can watch it, or be one of the 64 and sail your own heats. For now only the watching is tested and shown to Max; the playing is built along (the player's board takes one of the 8 places of a heat, the player's results go into the same ladder and standings) but its play-test waits.
- **D2 Heats you jump over:** (a) sailed by the real AI in the background (honest; a jump over ten heats takes a few minutes). (b) Drawn from the sailors' levels (instant; not really sailed). *Recommended: (a).*
- **D3 The 64:** (a) a provisional roster now, placeholder names, until your fifty (E10.S02) are ready. (b) Wait for the real roster. And: 64 men only, or the women's fleet too (the real event: 39 men and 13 women)? *Recommended: (a), 64 men first, the women's fleet as its own ladder later.*
- **D4 The pace:** the stream's (about 8 minutes a heat with the talk), or a quick one (about 5), with the other as a setting? *Recommended: quick as the default, the stream's as a setting.*
- **D5 The week's size and wind:** eleven eliminations over five days like 2026, or shorter? The wind per day drawn, or set by you? *Recommended: drawn, with a short week (three eliminations) for testing and the full one as the real thing.*
- **D6 The race kinds:** normal slalom only at first; the obstacle and the long-distance race later? *Recommended: yes. The long-distance race has the whole fleet on one line, which the 16-board limit can't show.*
- **D7 The other eight boards:** the next heat waiting near the start (as on the stream), with the finishers freed as they reach the beach? *Recommended: yes.*
- **D8 The AI's training on the Sotavento course:** start it as night runs alongside W1, so the heats are worth watching by W2? *Recommended: yes; it needs your go for each night.*

### Max's answers (27 November 2026)

| | Max | What it means for the build |
|---|---|---|
| D1 | "watch and play but test only watch" | Built for watching and for sailing in it as one of the 64; only the watching is tested and shown for now. |
| D2 | "no all live" | **No heat is jumped over or sailed in the background: every heat of the week is sailed on the screen.** Part 3 of the design and step W3 change: the jump is dropped. What stays of W3 is closing the game and going on later, because a whole week live is many hours (my assumption; Max hasn't said so). Watch mode's own fast-forward keys stay as they are. |
| D3 | "my names you are going to create later" | A provisional roster with placeholder names now. The real names are made later by the lead, by Max's naming rule (Q28). |
| D4 | "live speed as fast as the sailors are going", then: "we can do more little time between races so it goes faster. our sailors do not need a pause" | The race runs in real time. **Between heats there is as little time as possible:** the next heat is already at the line; its countdown (short: about 30 s, a setting) starts as soon as the heat before is decided, which is when its fourth board is home (the four who go through are known). The last boards of that heat finish during the countdown and are freed off camera. No sailor needs a rest or the sail back upwind: a sailor who goes through is put at the line for his next heat off camera, even if that is the very next one. So a heat takes about 190 s of racing plus about half a minute: **an elimination of 16 heats in about an hour, the eleven eliminations in about eleven hours** (an estimate from tonight's heat length). |
| D5 | "just to recreate the real event" | The week is the World Cup Fuerteventura 2026 as it was sailed: its race days, how many eliminations on which day, the wind of each day. Step W0 takes that from the 27 hours of commentary and the replays (so far: Eliminations 1 and 2 on 22 July, 3 and 4 on the 23rd, 5 to 7 on the 24th, 8 to 11 on the 26th). The results are the game's own: the AI sails them. |
| D6 | "yes normal slalom" | Normal slalom only. The obstacle heats and the full-fleet races of the real week are sailed as normal slalom or left out; W0 lists which eliminations were which. |
| D7 (the other eight boards) | not asked again | Stays as recommended: the next heat waits near the start. |
| D8 | "yes but later" | The AI's night training on the Sotavento course comes after the first steps, on Max's go. |

**One point this leaves open:** Max asked for 64 in the brackets; the real event had 39 men (and 13 women). "Recreate the real event" with 64 means the real days, wind and number of eliminations with a full 64 ladder; with 39 it would also be the real ladder with its free passes in the first round. The plan assumes 64 until Max says otherwise.

## Step W0, done in part on the night of 27 November: what the streams say

Read from the text of the five stream days (the speech-to-text was at 67 of 81 pieces; `tools/broadcast/format_facts.py` lists the sentences by topic, `pwa_broadcast/lists/format_facts.txt` is its print). The rule book itself has not been read.

| Question | The commentator | In the game now |
|---|---|---|
| Who goes through | "Top four will qualify", "four riders will go through", "top four is where you need to be in the quarterfinals to get into the semis"; a heat is eight ("there's eight in this here") | the same (`EliminationLadder.THROUGH` 4, `HEAT_SIZE` 8) |
| The rounds | a qualifying round, four quarter-finals, two semi-finals, the winners' final, and the losers' ("runners-up") final "to decide nine to 16th" | the same |
| The first round | the real fleet (about 40 men) had only "two qualifying heats to go into the quarterfinals"; everyone else began in a quarter-final | 64 sail a full first round of eight heats (Max: "64 people in brackets") |
| The points | the leader had "4.8 points" after six eliminations with one result dropped: four wins and a second, so a win is 0.7 and a second 2 | the same |
| Dropped results | "elimination 4 ... the discard will come in"; "we have had six eliminations, so this next one means two discards will come in"; "this is elimination 12, and that's when three discards come in" | 1 from four, 2 from seven, 3 from twelve (**was ten: set right**); a week of eleven ends with two dropped |
| Over the line early | "General recall ... all jumped the gun, so three guys were out" | **different:** the game's race lets a board go back and start again. A question for Max. |
| The days | eliminations 1 and 2 on 22 July, 3 and 4 on the 23rd, 5 to 7 on the 24th, 8 and 9 on the 25th, 10 and 11 on the 26th | the same (`schedules/sotavento_2026.json`; **was 0 on the 25th and 4 on the 26th: set right**) |
| The wind | 22nd: no number, the heaviest riders on 5.6 m2; 23rd: "like 30 knots average" in the afternoon, lighter in the morning; 24th: "already 35 knots at this time of day", one gust read at 50; 25th: "over 40 knots", "40 knots for sure"; 26th: "the lighter wind day, still cranking", 5.6 to 6.7 m2 | in the schedule as 30, 30, 35, 40 and 28 knots, each with the words it comes from (the 22nd and the 26th are estimates from the sail sizes). **Not used yet:** every heat is sailed in the wind the game is started with (30 knots). The AI has never been tried in 35 or 40. |
| Time between heats | not read yet | a 60 s countdown (what the AI's start needs) and 8 s for the result |

**Not said on the streams, so still the lead's reading:** the snake of the seeding, how sailors knocked out in the same round are ranked against each other, and the tie-break. **Not measured yet:** how many boards the PC carries at Sotavento (the live week uses eight at a time).

## After the decisions

The steps become backlog stories under E11.S03, E13.S03 and E10.S06 (with E16.S06 for the new commentary moments), W0's report is written in `Documentation/reports/broadcast/`, and W1 starts.
