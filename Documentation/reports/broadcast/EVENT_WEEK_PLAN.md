# The slalom week, live: 64 sailors in brackets, never more than 16 on the water

Status: **plan, waiting for Max's decisions** (27 November 2026). Nothing of this is built. It stands on tonight's broadcast work ([PLAN.md](PLAN.md)) and ties together backlog stories that already exist: E11.S03 (slalom elimination ladders), E13.S03 (the event flow), E10.S06 (the roster in heats), E11.S07 (results and rankings), E11.S09 and E11.S11 (watch mode and the TV director), E16.S06 (the commentary).

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

The budget: **8 racing + 8 of the next heat = 16.** The rules that keep it there:

- A sailor is loaded only when a place is free; the heat after next waits on the beach.
- A finisher frees its place when it reaches the beach, or sooner when no camera is on it. Nothing appears or vanishes in the picture: the TV director knows what is on screen, and loading happens outside it.
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
| **W3** Jump ahead | Heats sailed in the background, jump to a round, close and go on | One whole elimination, part watched, part jumped |
| **W4** The broadcast | The line-up card, the ladder, the results, the standings; the new commentary moments; the director between heats | An elimination that looks and sounds like the stream |
| **W5** The week | The days and the wind, eleven eliminations, the dropped results, the champion | The Sotavento week from the first heat to the champion |
| Later | You as one of the 64. The women's fleet. The obstacle and the long-distance race. Interviews (E13.S06). Other spots. | |

Size: W1 and W3 are a session each for one worker; W2 and W4 are the big ones (two workers each); W5 is small once the others stand. Five to seven sessions in all, not one night.

## What can go wrong

- **The AI on this course.** A heat where two boards start half a minute late is not a World Cup heat. The AI needs its own training on the rebuilt Sotavento course, by the training method, at night, on your go. Without it the week runs but looks poor. This is the biggest risk and it is not part of the steps above.
- **The gybes.** Tonight's finding: the AI's gybes drop from 23 knots to 3 or 4. The commentator will never have a good gybe to call until that improves (the AI track).
- **Sixteen boards at Sotavento.** The swell makes the sea cost about half as much again as open water. Measured in W0, not assumed.
- **No collisions yet** (E11.S01). Eight boards at the first mark pass through each other's space as they do today.
- **The branches.** Sotavento, its water and its course, the TV director and the commentary are five branches that are not in main. W1 can start on main; W2 needs them merged, which needs your look and Michiel's OK on the sea's physics.

## Decisions for Max

- **D1 Watching, or sailing in it?** (a) First only watching: the week as a broadcast. (b) You are one of the 64 from the start. *Recommended: (a); (b) is the "later" row and joins the season (E13).*
- **D2 Heats you jump over:** (a) sailed by the real AI in the background (honest; a jump over ten heats takes a few minutes). (b) Drawn from the sailors' levels (instant; not really sailed). *Recommended: (a).*
- **D3 The 64:** (a) a provisional roster now, placeholder names, until your fifty (E10.S02) are ready. (b) Wait for the real roster. And: 64 men only, or the women's fleet too (the real event: 39 men and 13 women)? *Recommended: (a), 64 men first, the women's fleet as its own ladder later.*
- **D4 The pace:** the stream's (about 8 minutes a heat with the talk), or a quick one (about 5), with the other as a setting? *Recommended: quick as the default, the stream's as a setting.*
- **D5 The week's size and wind:** eleven eliminations over five days like 2026, or shorter? The wind per day drawn, or set by you? *Recommended: drawn, with a short week (three eliminations) for testing and the full one as the real thing.*
- **D6 The race kinds:** normal slalom only at first; the obstacle and the long-distance race later? *Recommended: yes. The long-distance race has the whole fleet on one line, which the 16-board limit can't show.*
- **D7 The other eight boards:** the next heat waiting near the start (as on the stream), with the finishers freed as they reach the beach? *Recommended: yes.*
- **D8 The AI's training on the Sotavento course:** start it as night runs alongside W1, so the heats are worth watching by W2? *Recommended: yes; it needs your go for each night.*

## After the decisions

The steps become backlog stories under E11.S03, E13.S03 and E10.S06 (with E16.S06 for the new commentary moments), W0's report is written in `Documentation/reports/broadcast/`, and W1 starts.
