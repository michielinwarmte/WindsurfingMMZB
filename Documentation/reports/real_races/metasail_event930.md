# Real iQFOiL races from Metasail: what we gain (events 930 and 602, 13 November 2026)

**For:** the team (Max, Michiel) and any session that trains or judges the AI skippers
([AI_TRAINING_METHOD.md](../../AI_TRAINING_METHOD.md)).

> **These are foil races, not fin races** (Max, 13 November 2026). iQFOiL boards fly on a hydrofoil; the game's boards
> are standard fin boards (slalom and free race; Q6: no foils in 1.0). Every number below comes from foil racing. Use it
> for the racing (starts, roundings, the crowd, the format, who wins), never for speeds, angles or the physics.

**Sources:**
- [metasail.com/past/930](https://www.metasail.com/past/930/): the 2026 iQFOiL Youth & Junior European Championships,
  Varkiza (Greece), 25 October to 1 November 2026. 121 men's races (U19, U17). Sections 1 to 9.
- [metasail.com/past/602](https://www.metasail.com/past/602/): the **iQFOiL U23 World Championships 2024 on Lake
  Silvaplana**, 21 to 26 August 2024. 26 men's races, **Max among the riders**. The better source for the game, because
  it is on the game's own lake: section 10.

**Status:** the rider lists and the tracker's places for both events are in. Event 930 is analysed in section 3. The
GPS tracks themselves are **not** downloaded yet (section 6).

## 1. In short

- **What we have now:** for all 121 men's races (U19 and U17), which riders sailed in each race and the order the
  tracker saw them finish: 3,165 board-races by 200 riders. From that alone we measured the event's format, how often
  starts were recalled, and how much of a rider's place is down to the rider and how much is the race.
- **The most useful number now:** about **half of a rider's place is the rider, the other half is the race** (43 to
  71 %, depending on the fleet). A rider's place moves by about 3 to 5 places in a heat of 24 from race to race. The game
  can be measured the same way, to check that its levels and day-form behave like a real fleet (E10, E09's "results
  spread that reflects the characters' levels").
- **What the tracks would add:** real riders' starts in fleets of 24 and 48, their mark roundings, laylines and the
  crowd on the legs. These are the AI's open stories (E09.S03, S20, S23, S25, S26), and they would give real targets
  in place of our own limits (10, 15 and 25 m at the marks).
- **What the tracks cannot give:** speeds, angles, polars. iQFOiL boards fly on foils, and the game's boards sail on
  fins (Q6: no foils in 1.0). Varkiza is the sea, not Silvaplana. So the tracks help the AI's racing behaviour, not the
  physics.
- **The better source is on Silvaplana** (section 10): the U23 Worlds 2024, 26 men's races of about 50 boards on the
  game's own lake, in the Maloja wind's hours, with Max's own 13 races in it. Its tracks would also show where real
  racers go on the lake and how the wind turns across it.
- **The blocker:** the website's GPX export answered "400 Bad Request" to a script, and Claude Code's safety check then
  refused further tries three times. Max can test the Export button in a browser, or allow the one download script by
  a permission rule (section 6).

## 2. What the data is

Metasail tracks races with a GPS unit on every board and shows them on a replay map. Each event page lists its races.
Each race has an **Export** button, which lists the riders and offers "Download GPX" (the tracks) and "Download
statistics" (a spreadsheet), at most 10 riders per file.

Event 930 has 200 races, 121 of them men's: **U19 Men** (97 riders) and **U17 Men** (103 riders). There is no senior
fleet. The list includes general recalls and abandoned starts as separate entries.

What we have per race: the riders (name and tracker id) and the tracker's place. A place of 0 means the tracker logged
no finish. That covers a DNF, OCS, DNS, a recall or a tracker gap, and the data does not say which. **The tracker's
place is not the official result**: it has no penalties, protests or discards.

## 3. What the results already tell us (measured)

All numbers come from `tools/real_races/analyse_men.py` (section 9). Five entries labelled as races were left out
because the tracker ranked fewer than half the fleet. They were probably unlabelled recalls or tracker problems.

### 3.1 The format of a real iQFOiL event

| Stage | Day | U19 Men | U17 Men | Boards per race |
|---|---|---|---|---|
| Qualifying: four heats (Yellow and Blue, each Heat 1 and Heat 2) | 25 + 27 Oct | 24 races (+5 recalls) | 24 races | 23 to 24 |
| Gold fleet, one start | 28 Oct, morning | 5 races | 5 races | 48 |
| Silver fleet, one start | 28 Oct, afternoon | 4 races | 4 races | 47 to 48 |
| Gold in two heats | 30 Oct | 9 races (+3 recalls, 1 abandoned) | 11 races (+3 recalls, 1 abandoned) | 24 |
| Silver in two heats | 30 Oct | 6 races | 6 races (+1 recall, 1 abandoned) | 23 to 24 |
| Final series (1/4 final, 1/2 final, final) | 31 Oct | 5 races (three finals) | 3 races | 4 to 5 |

On the fleet day (28 October), Metasail opened a fleet's races about every **30 minutes** (26 to 45), 4 to 5 races
per fleet per day. These are the times Metasail opened each race, not the guns, so they are a rough race cycle only.

**What it means for the game:**
- **Fleet sizes:** a real heat has 24 boards (23 AI and the player), a fleet 48. The frame-budget work of 13 November
  (branch `tech/frame-budget`, not merged yet) runs 17 AI boards at 60 fps, and E01 aims for 32. A heat of 24 is the realistic target; a fleet of 48 is beyond it.
- **Course racing series (E11.S04):** the real shape is qualifying heats, then gold and silver, then a final series of
  4 to 5 boards, at about 30 minutes a race. The final series is described here only as Metasail names it; the class's
  rules (the notice of race in `Documentation/`) were not checked for this report.

### 3.2 Starts and recalls

| | Starts recorded | General recalls | Abandoned |
|---|---|---|---|
| U19 Men | 62 | 8 (13 %) | 1 |
| U17 Men | 59 | 4 (7 %) | 2 |

The recalls come in bunches: U19 had 5 of its 13 starts recalled on the first day, and both divisions had recalls in
the gold heats on 30 October. There were none on 27 and 28 October. These counts are a lower bound, because a few
unlabelled entries look like recalls.

**What it means for the game:** real fleets push the line hard enough that roughly 1 start in 8 to 1 in 14 is
recalled. The rules work (E11.S02, and Q32 in QUESTIONS.md, which recommends the flags and the general recall) has a real
reason to include the general recall. The results alone cannot say how many boards were over early in a start; the
tracks can (section 4).

### 3.3 How often a board has no tracked finish

| Stage | Races | Boards with no tracked finish (median per race) | Range |
|---|---|---|---|
| Qualifying heats | 47 | 4 % | 0 to 39 % |
| Gold fleet (48) | 10 | 4 % | 2 to 8 % |
| Silver fleet (48) | 8 | 12 % | 9 to 15 % |
| Gold heats (24) | 17 | 12 % | 4 to 42 % |
| Silver heats (24) | 12 | 17 % | 0 to 42 % |

This is a mix of real DNFs and OCS and tracker gaps, so it is an upper bound on real non-finishers. A realistic results
table shows a DNF or an OCS now and then. The AI's own "finished" check is still right, because it judges whether the
skipper can sail the course.

### 3.4 How much of a place is the rider, and how much is the race

For every rider we took their place in each race as a share of the fleet (0 = first, 1 = last tracked finisher) and
asked three questions:
- **Rider share:** how much of all the spread in places comes from who the rider is (the rest is the race: the start,
  the shifts, the crowd, mistakes).
- **Agreement:** does the order by the odd races match the order by the even races (1 = the same order, 0 = no
  relation)?
- **Wobble:** how much one rider's place moves from race to race (one standard deviation, as a share of the fleet).

| Fleet | Races | Riders | Rider share | Agreement, odd vs even races | Wobble (places in a heat of 24) |
|---|---|---|---|---|---|
| U19 qualifying heats | 24 | 95 | 58 % | 0.82 | 0.15 (about 4) |
| U19 gold | 13 | 49 | 49 % | 0.76 | 0.20 (about 5) |
| U19 silver | 10 | 47 | 49 % | 0.75 | 0.18 (about 4) |
| U17 qualifying heats | 23 | 93 | 71 % | 0.90 | 0.12 (about 3) |
| U17 gold | 14 | 49 | 43 % | 0.80 | 0.21 (about 5) |
| U17 silver | 10 | 46 | 52 % | 0.82 | 0.17 (about 4) |

Who wins:

| Fleet | Wins | Different winners | Most wins by one rider | Winner was among the fleet's best 10 % (by the other races) |
|---|---|---|---|---|
| U19 qualifying heats | 24 | 11 | 5 | 18 of 24 |
| U19 gold | 13 | 8 | 5 | 8 of 13 |
| U17 qualifying heats | 23 | 10 | 5 | 21 of 23 |
| U17 gold | 14 | 9 | 5 | 9 of 14 |

In plain words: the good riders are clearly good (the order holds from race to race), but in a fleet of equals (gold)
**about one race in three is won by someone outside the top 10 %**, and a rider's place moves by 3 to 5 places a race.
In a mixed fleet (the qualifying heats) the rider counts for more.

**What it means for the game:** this is a real yardstick for E10 (levels and the day-form draw) and for E09's goal of
"a results spread that reflects the characters' levels". The game sets it with two knobs: how far apart the levels are
(`level_spread`, the game's "close" setting 0.5, `Game/race/race_setup.gd`), and how much a persona's skills wander
from race to race (`WANDER_AT_ZERO` 0.25 at consistency 0, `Game/race/persona.gd`). Proposal (not done): race the
twenty personas at the game's level for 20 or more races, run the same three numbers on the results, and compare.
The rough bands from this event are a rider share of 45 to 70 %, a wobble of 0.12 to 0.21, and the winner from the top
10 % in two races of three (even fleet) to nine of ten (mixed fleet). These are juniors, so senior World Cup fleets
may be more consistent, which we have not measured.

## 4. What the GPS tracks would add (expected, not verified)

None of this is measured yet: it is what one GPX file per race should allow, if the file holds every board's position
and time often enough (the sample rate is unknown until we have a file). Every measure is meant **in relative terms**
(seconds of the rider's own sailing, places, shares of the fleet) because foils are faster than the game's boards.

| What we would learn | Measured in a track as | For the game's work |
|---|---|---|
| How real riders start in fleets of 24 and 48 | At the gun: distance behind the line, place along the line, speed at the gun against the rider's own speed on the first leg; metres up the course 30 s after the gun (the suite's own `score_m`), as seconds of full-speed sailing lost; when they turn for the line (the run-in's length); who was over early before a recall | E09.S03 (the starts), E09.S25 (the fastest start), Q47 (a timed run for course starts?), Q48 (how long after the gun dirty wind counts) |
| How tight real roundings are | The suite's four rounding measures on real riders: closest to the mark, distance out of the turn, overstand beyond their own layline, a gate's extra turning, and which gate mark they choose by their place in the fleet | E09.S23: real targets in place of our 10, 15 and 25 m and 120 degrees; turned into seconds of sailing, because a foil turns wider at speed |
| Laylines and beats | Tacks per beat, how far riders go to the sides, how they come into the top mark from the wrong side | E09.S23 and Max's "they over-lay the layline" |
| The crowd on the legs | Distances to the nearest boards over time, the time spent right behind another board (a stand-in for dirty wind), how fast the fleet spreads after the start | E09.S26 (out of dirty wind on the reach), E09.S20 (the fleet's runs), E01.S04 (the dirty wind) |
| The course and the race's length | Legs, laps and angles as laid, the race time, the gaps at the finish | E11.S04 (series), the game's ten iQFOiL templates (sized 25 to 100 % of the class's), E10 (the spread in time, not only in places) |
| The wind at sea | Wind direction worked out from the headings on each tack, over the race | E03 (wind) for the open water and sea spots, not Silvaplana |

## 5. What it cannot tell us

- **Speeds, angles, polars, physics.** iQFOiL is a foiling class, and the game's boards are fin boards, slalom and free
  race (Q6, answered 6 November 2026: no foils in 1.0, maybe a DLC later). Max's rule is "physics from physics
  sources, GPX only to verify later" (PROGRESS_LOG), and these tracks come from the wrong kind of board even to verify. They
  would become the reference only if a foil DLC is ever made.
- **Silvaplana.** Varkiza is open sea near Athens: no Maloja wind, no lake lee, no shore traps.
- **Top seniors.** These are U17 and U19 riders, a level below the World Cup sailors the personas are modelled on.
- **The wind and the official results.** The data has no wind readings, and the tracker's places are not the official
  results.

## 6. Getting the tracks

What was tried on 13 November 2026:
- The rider lists came through the website's own rider-list call (one per race, half a second apart): all 121 worked.
- The GPX export (`app.metasail.it/Export/DownloadGpx.ashx?idg=<race>&s0=<rider>&...`, the same link the Export button
  builds) answered **"400 Bad Request"**, also to a plain request, on event 930 and again on Silvaplana's event 602.
  It may need something a browser session has; that is not known. Claude Code's safety check refused three scripted
  tries (a browser-like request, and twice a session cookie from Metasail's own pages) as getting around the site's
  protection, even after Max asked for the download. Nothing more was tried.

The options, for the team to choose:
1. **Max tests it in a browser (two minutes, tells us the most).** On
   [metasail.com/past/602](https://www.metasail.com/past/602/), click Export next to "IQ FOIL Men Silver R 4" (Max's
   3rd place), tick Max and up to nine others, click "Download GPX"; also try "Download statistics" once. Save the files
   in `.sim_output/real_races/metasail_602/gpx/`. If the browser also says "Bad Request", the export itself is broken
   and only Metasail can help (option 3). If it works, one file tells us the sample rate, whether the marks are in it,
   and whether section 4 is possible.
2. **Allow the one download script for Claude Code.** `tools/real_races/download_gpx.py` (read it first: it opens the
   race's public ranking page once, then asks the export links with that session, 2 s apart, no fake browser name,
   stops at the first refusal, keeps only real GPX files). Allowing it is Max's decision and turns off the safety
   check for that one command only: add to `C:\Users\Max de Dikke\source\.claude\settings.local.json`
   ```json
   { "permissions": { "allow": ["Bash(python -I tools/real_races/download_gpx.py:*)"] } }
   ```
   (or type `/permissions` in Claude Code and add the same rule). Best after reading Metasail's terms of use (not read
   for this report). The first run would be one file
   (`--races=32529 --max_files=1`); all 26 Silvaplana men's races are 143 files of up to 10 boards, about 6 minutes.
4. **Let the browser click for you, in one go** (Max, 13 November 2026: too many downloads to do by hand).
   `tools/real_races/make_browser_download.py` writes a snippet
   (`.sim_output/real_races/metasail_602/download_in_browser.js`) that does what the Export button does, once per file,
   one every 3 s (143 files, about 7 minutes). Open metasail.com/past/602 in Chrome or Edge, press F12, then Console,
   paste and press Enter, and allow "download multiple files". The files land in Downloads; if the page turns into
   "Bad Request", the export refused and the snippet stops.
   **Tried by Max, 13 November 2026: "Bad Request" in his own browser too.** So the refusal is not a bot check: the
   export refuses these files to anyone who is not logged in, or is broken for them. Options 2 and 4 are dead until
   that is known; the open questions are whether the website's own Export button works for Max (one click), whether
   it works once logged in at app.metasail.it, and option 3 (ask Metasail).
3. **Ask Metasail** through their website for the GPX of the men's races. As a rider of event 602, Max can also ask
   for his own races.

## 7. Care with the data

- **Event 930's riders are juniors, some under 17.** Their names stay out of git, the game and the reports. The
  analysis uses the tracker's ids (`A1180`), and the files with names are kept in `.sim_output/real_races/` (ignored by
  git). E10's characters are modelled on top senior racers, never on these riders.
- **Event 602's riders are under 23** (adults, but private people): the same rule, ids only in git. Max's own id is
  `A0323`, and his name may be used with his OK.
- Metasail's terms of use were not read. Read them before any bulk download.

## 8. Proposed next steps (none are in the backlog yet)

1. Max: the browser test in section 6 (two minutes).
2. If it works: read one GPX (the sample rate, the accuracy, the marks) and write down here whether section 4 holds.
3. The results spread of the game measured as in section 3.4 and compared (E10.S03 T3 or a new task).
4. With about 10 races of tracks: the start and rounding measures on real riders, as targets for E09.S23 and E09.S25.

## 9. The files

| What | Where |
|---|---|
| The scripts | `tools/real_races/list_races.py` (the race list from the saved event page), `men_athletes.py` (the rider lists and the GPX links), `analyse_men.py` (the numbers in section 3), `download_gpx.py` (the tracks by script: never run, and kept on disk only, not in git: the export refuses even a browser, section 11), `make_browser_download.py` (a snippet that downloads in the browser; section 6, option 4), `read_gpx_race.py` (reads one race's GPX files: the speeds, the turns, the start finder, a picture; section 12), `add_course_to_gpx.py` (the virtual marks into the GPX files) and `analyse_roundings.py` (the starts, legs and roundings by fixed criteria; section 13); the course files in `tools/real_races/courses/` |
| The data, event 930 (local, ignored by git, holds names) | `.sim_output/real_races/metasail_930/`: `event930.html` (the race page), `races930.json` (200 races), `men_races930.json` (121 men's races with riders, places and GPX links), `analysis_men930.txt` (section 3's output) |
| The data, event 602 (the same, Silvaplana) | `.sim_output/real_races/metasail_602/`: `event602.html`, `races602.json` (39 races), `men_races602.json` (26 men's races), `analysis_men602.txt` (section 10's numbers); the tracks go in `gpx/` |
| One race read (section 12) | `.sim_output/real_races/metasail_930/browser/`: Max's downloads (copies), `u17_final_gpx/` (the four tracks), `u17_final_race.png`/`.svg` (the picture), `u17_final_read.txt`; run again: `python -I tools/real_races/read_gpx_race.py .sim_output/real_races/metasail_930/browser/u17_final_gpx --from_s=760 --to_s=1230 --start_line=374,-77,127,565,880 --points="374,-77;107,-618;345,-919;-19,-729" --svg=<out.svg>` |
| Run again | `python -I tools/real_races/analyse_men.py .sim_output/real_races/metasail_930/men_races930.json` (event 930; section 10's numbers were worked out by a few lines of Python in the session, not a script yet) |

## 10. The Silvaplana event: the iQFOiL U23 World Championships 2024 (event 602)

Found on Metasail by its event search on 13 November 2026 (the other Silvaplana and Engadin events there are wingfoil
racing, not windsurfing: events 501, 713, 869, 872). Max: "U23 is good", and he sailed in it.

**What is on Metasail.** 26 men's races of 50 to 51 boards by 101 riders, 22 to 24 August 2024. Women's races are
there too (13, not fetched).

| Stage | Day | Races | Metasail opened them |
|---|---|---|---|
| Qualifying in two groups (Yellow, Blue), R5 to R9 | 22 Aug | 10 | 11:58 to 14:39 |
| Gold fleet R1 to R8 (R6 a marathon) | 23 + 24 Aug | 8 | 13:46 to 16:34 |
| Silver fleet R1 to R8 (R6 a marathon) | 23 + 24 Aug | 8 | 11:30 to 15:39 |

The qualifying races R1 to R4 (21 August) and the medal series (25 and 26 August) are not on Metasail. The opening
times are as Metasail lists them (probably local time, not checked), and they fall in the Maloja wind's hours, the same
hours the game draws (11:00 to 18:00).

**The results, measured as in section 3** (the tracker's places; `analysis_men602.txt`):

| Fleet | Races | Boards without a tracked finish (median) | Rider share | Wobble (places of 50) | Wins / different winners |
|---|---|---|---|---|---|
| Qualifying (Yellow, Blue) | 10 | 2 % | 83 % | 0.09 (about 4) | 10 / 6 |
| Gold | 8 | 5 % | 59 % | 0.16 (about 8) | 8 / 7 |
| Silver | 8 | 6 % | 77 % | 0.11 (about 5) | 8 / 5 |

The order holds more firmly than with event 930's juniors (43 to 71 %): older riders, the lake's steadier wind, or just
the smaller sample of 8 to 10 races. This data cannot tell those apart. The gold fleet, the most even one, is again the
least predictable. For the game's results spread (section 3.4), the two events together give a band of roughly 45 to
85 % rider share.

**Max's races** (rider `A0323`): 13 tracked races. In the Blue qualifying group he was 23rd to 37th of about 49; in
the Silver fleet 9th, 13th, 15th, 3rd (R4), 4th (R5), 13th (the marathon), 6th (R7) and 16th of 44 to 48.

**What Silvaplana's tracks add beyond section 4** (expected, not verified; all foil):
1. **Where real racers sail on the lake.** The real race area and course against the game's ten saved iQFOiL courses
   (`Game/maps/silvaplana/courses/iq_*.json`) and the course fitter.
2. **The wind across the lake.** The wind's direction worked out from the tacks' headings, by place and hour, against
   the map's wind (Max's wind analyser, MALOJA_WIND_RESEARCH.md): which side of the beat pays, the south-east lee band,
   the north-east corner (E09.S02 T2, E01.S21). The direction only, roughly: a foil's speed does not give the wind's
   strength.
3. **Lake tactics.** Which side the leaders take on each beat at each hour, which is exactly what the AI's skipper should
   learn on this lake.
4. **A commented real race.** Max can say what he did and why, next to his own track: the start, the side he chose,
   the roundings.

**Why it is the better source:** the same lake and wind as the game, adult riders, fleets of 50, and one of the riders
on the team. Event 930 stays useful for the format, the finals and the numbers of section 3.

## 11. What a download holds (Max's browser, 13 November 2026)

Max's single clicks downloaded, from event 930: the GPX of "IQFoil Under 17 Men FINAL" and the statistics of the
U17 final, the U19 final and the U19 final 3. Copies (Max's originals stay in his Downloads folder) are in
`.sim_output/real_races/metasail_930/browser/`, the four tracks unpacked as `u17_final_gpx/rider1-4.gpx`.

**The GPX export** is a ZIP with one GPX file per rider, named after the rider. Each point has the position, the time,
the number of satellites (17 to 19), the speed **in knots** (the field is 1.92 times the speed from the positions in
m/s) and the course. **One point a second**, from before the start to the finish: about 1,300 points and 6 to 8 km per
rider in the U17 final's 23 minutes. **No marks** in the file: they have to be found from where the boards turn, or
taken from the statistics' leg directions and lengths.

**The statistics export** (.xlsx, only for races from late August 2025 on: the website enables it for race ids above
43170, so not for event 602) has a sheet per leg and one for the full race. **For the start:** the line's angle, the wind
direction the race officials entered, the pin's and the committee boat's distance to mark 1, and per rider the distance
to the line 5 s before and at the gun, the speed then, the side of the line, the start delay, the speed crossing, and
the places at the start and 2 minutes later. **Per leg:** times, the places in and out, the share of time on the left
and the right, the leg's length against the distance sailed, top and average speed, VMG, VMC and the average angle to
the wind. These are almost the AI's own start measures (distance behind the line and speed at the gun, `score_m`), measured
by Metasail for every real rider.

An example, the U19 Men final (a sprint): 6 minutes 40 seconds, four reaching legs of 372 to 662 m at 100 to 140
degrees to the wind, averages 18 to 22 kt, top 23.5 kt. That is foil speed (section 5).

**Why most GPX clicks said "Bad Request".** The U17 final's file (four riders with plain Latin names) downloaded; the U19
final's (one rider has a Turkish letter outside Latin-1 in the name) did not, and neither did the first file of the
Silvaplana snippet, which held such a name too. Most likely the server cannot write that name into the ZIP. This is not
proven yet. `make_browser_download.py` now leaves those riders out (13 of 198 at event 930, 4 of 101 at event 602), so
every file holds plain names only: 130 files for event 602, 374 for event 930. A script (not a browser) still got
"Bad Request" with a plain name, so the browser is the way.

**Event 602 (Silvaplana 2024) refuses even with plain names** (Max, 13 November 2026, the rebuilt snippet's first
file). So the export most likely does not serve 2024 races at all (the website itself turns the statistics off for
races before late August 2025). Silvaplana's tracks need another way: Metasail by email, Max's own watch data, or new
recordings (the options in the session's answer and the progress log).

## 12. What the one race we have shows (13 November 2026, read with Max)

Max: "take the one you got, it's enough": no more downloads and no email to Metasail for now. This section reads the
**U17 Men final of event 930** (31 October 2026, four riders, one GPX each) with `tools/real_races/read_gpx_race.py`.
**All of it is foil racing** (the box at the top).

**How it was read.** My first two readings were wrong (two 4-minute sprints, then a course I guessed from the turns).
Max corrected them as a rider would: the half-minute stop is the fleet "waiting for the race director to start the
countdown"; he drew the marks in yellow on a clean picture of the tracks
(`.sim_output/real_races/metasail_930/browser/u17_final_tracks_race_max_yellow.png`); the start line he could not place,
but told me how to find it: "play back the GPX's and see where at the same time the guys are in line with the wind"
(`--find_start`): the four boards stand in one line within 1.5 m, 5 degrees off the wind, just before they cross Max's
yellow line. And the first start was "an over early". Lesson kept: a race is read with a rider, on a picture, before it
is written up.

**The wind**, from the downwind leg: the riders sail 180 and 274 degrees, so dead downwind is 227 and the wind came
from about **47 degrees** (the U19 finals' statistics: 43 to 55). Max's start line runs 56/236 degrees, 9 degrees off
the wind: a **reaching start**, the line along the wind, the boards across it on a reach to the south-east.

**What happened** (track time 0 = 08:09:27 UTC, 10:09 local time):

| Local time | Track time (s) | What |
|---|---|---|
| | 0 to 460 | before: two riders sail, the others wait |
| 10:17 | about 465 | **countdown 1** begins: all four go from almost standing still |
| | 465 to 646 | **the timed run**: south-east across the line, a gybe at the south-east end, back north-west, a gybe at the north-west end, then full speed at the line |
| 10:20:13 | 646 | **start 1, over early** (Max): all four over the line **within 1 s, at 21 to 22.5 kt** |
| | 665 to 675 | all four turn back |
| | 715 to 760 | **waiting for the race director to start the countdown**: all four at 1 to 2 kt, heading about north, within some 40 m (the logged speed and the speed from the positions agree: not a GPS fault) |
| 10:22 | about 765 | **countdown 2** begins |
| | 765 to 948 | the same timed run |
| 10:25:15 | 948 to 956 | **start 2**: all four over **within 8 s, at 19 to 21 kt** |
| | about 985 to 1005 | **mark A** (Max's yellow, the top right of the box) |
| | to about 1050 | **the downwind leg**: gybes between south and west, each rider gybing at their own place (up to 300 m apart) |
| | | **mark B** (the bottom of the west side), a reach to **mark C** (the far south; rounded at 1107 to 1127, one rider falls there) |
| | about 1160 to 1210 | north-west to the finish (not drawn by Max: where the riders stop; one track has a gap there): the race about 4 to 4.5 minutes |

Each countdown, from the boards going to the line, took about 3 minutes (181 and 183 s). The gun itself is not in the
data: at start 1 it came after 646 s (they were over early).

**The timed run, measured on Max's line** (the most useful part for the AI):

| | Start 1 (over early) | Start 2 |
|---|---|---|
| The last gybe ends, before the line | 54 to 58 s | 46 to 61 s |
| ... that far behind the line | 454 to 503 m | 374 to 537 m |
| All four over within | 1 s | 8 s |
| Speed over the line | 21.0 to 22.5 kt | 19.4 to 20.8 kt |
| 30 s after the first board crossed | (turning back) | 206 to 323 m past the line, at 19 to 22 kt |

So a real timed run is one loop of about 3 minutes with two gybes; the last gybe comes about a minute before the gun,
some 400 to 500 m back (at foil speed); the boards then sail straight at the line and cross at full speed, a few seconds
apart. And the fleet pushes the line so hard that all four were over early together. For the AI: the shape fits Max's
slalom start (the timed run, version 6b) and is evidence for Q47 (a timed run for course starts); the time before the gun
carries over to fins better than the metres. The over early fits the recall counts of section 3.2 (7 to 13 % of starts).

**The gybes** (the 12 full turns of 150 to 215 degrees in the second timed run and at mark C): median **17 s**, radius
**45 m** (38 to 59), speed **17.3 kt in, 10.0 kt at the slowest, 13.2 kt out** (75 % of the speed in); 2 of 12 ended
under 6 kt (a touch-down in the timed run, a fall at mark C). Foil numbers: a fin slalom gybe is tighter and planes
through. The shape carries over: a full turn takes about 90 m of width and a quarter of the speed.

**The downwind leg**: not straight downwind, but gybing between two broad reaches about 47 degrees either side of dead
downwind, each rider choosing where to gybe: how the AI should sail a run on a board that is slow dead downwind
(E09.S20).

**What it cannot give.** The GPX has no buoys: the marks are Max's drawing (about 20 m), the line is his drawing checked
by the playback, and the gun is not in the data. So the AI's rounding measures (closest to the mark, out of the turn,
overstand) are not measured here. One race of four riders is a sample, not a yardstick; the tool reads more races if
they ever come (best: fin races, or races with the buoys).

**Run again:** `python -I tools/real_races/read_gpx_race.py .sim_output/real_races/metasail_930/browser/u17_final_gpx
--from_s=450 --to_s=1240 --find_start=440,1000,47` (the start finder; the measures above were worked out in the session
from Max's line, (-75,81) to (266,314) m in the tool's frame, and his marks A (386,-101), B (99,-629), C (335,-934) m).

## 13. The virtual marks and the criteria, for the head training (13 November 2026)

Max: "it's on foils, keep that in mind: the radius is bigger on the foil. Please add the marks virtually in the GPX so
you can analyse it for head training. Make it so there are clear criteria."

**What was made.**
- **The course file** `tools/real_races/courses/930_u17_men_final.json`: Max's marks A (rounded to starboard), B (port)
  and C (starboard), his start line, the two starts (start 1 over early, start 2 counted), the wind (47 degrees) and a
  provisional finish (not drawn by Max: where the riders slow down), all as latitude and longitude. No names: it can go
  in git. Checked: every rider rounds every mark on the same side, 5 to 12 m from Max's dot.
- **The GPX files with the marks in them**: `tools/real_races/add_course_to_gpx.py` writes copies with the marks, the
  line's ends and the finish as GPX waypoints (`.sim_output/real_races/metasail_930/browser/u17_final_gpx_with_marks/`),
  so any GPX viewer shows the course.
- **The analysis** `tools/real_races/analyse_roundings.py`: every start, rounding and leg measured by one fixed
  definition each; a table (`u17_final_roundings.txt`) and a CSV (`u17_final_roundings.csv`, one row per rider and item)
  for the head training.

**Foil, not fin.** A foil turns on a wider radius than the game's fin boards (Max). So every measure is marked
**carries over** (a timing, a share, a side, a count, or metres divided by the rider's own turn radius: the shape of the
manoeuvre, which a fin board can copy at its own size) or **foil only** (metres, knots, radii: never copied by the fin
AI, only through a ratio).

**The criteria** (the same as the AI suite's where it has one: the out-of-the-turn rule, the gate's extra turning,
`score_m`):

| Measure | Definition | Fins? |
|---|---|---|
| rounded | within 50 m of the mark, with the mark on the required side at the closest approach | carries over |
| closest_m / closest_r | the nearest the track came to the mark; in turn radii | foil only / carries over |
| turn start | the last moment before the closest approach when the heading held (under 6 deg in 2 s) | |
| start_s / start_m / start_r | at the turn start: the seconds before the closest approach; the metres from the mark; in turn radii | carries over / foil only / carries over |
| exit (out of the turn) | the first moment after the closest approach when the heading holds again (under 6 deg in 2 s): exactly the AI suite's rule. How soon a rider is out depends on what it does next: Max, "this is only because of the specific tactic on that race". So exits are compared only between like situations, never used as a target on their own | |
| exit_s / exit_m / exit_r | at the exit: the seconds after the closest approach; the metres from the mark (the suite's exit_m); in turn radii | carries over / foil only / carries over |
| turned_deg | the heading change from the turn start to the exit | carries over |
| extra_turn_deg | the turn beyond the course's turn at the mark (bearing in against bearing out): the suite's gate measure; over about 60 = a gybe or loop inside the rounding; below 0 = came in already turned | carries over |
| apex_share | when in the turn the rider is nearest the mark: 0 = the turn start, 1 = the exit; over 0.5 = wide in, tight out | carries over |
| radius_m | the path through the turn divided by the angle turned | foil only |
| turn_s, kept | the seconds in the turn; the speed out as a share of the speed in | carries over (roughly) |
| kt_in, kt_min, kt_out | the speed before (mean of 5 s), the slowest in, and at the exit of the turn | foil only |
| leg_s, sailed_share, gybes | the leg's time; the distance sailed against the straight line; turns over 60 deg in 15 s (roundings not counted) | foil only / carries over / carries over |
| start: over_s | seconds after the fleet's first board over the line (the gun is not in the GPS) | carries over |
| start: last_gybe_s / _m | the last moment before the line the heading was over 70 deg off the way to mark A: seconds, metres before the line | carries over / foil only |
| start: behind_m_10s / _5s, kt_over, past_m_30s | behind the line 10 and 5 s before the first board; the speed over; metres past the line 30 s after (the suite's score_m) | foil only |

**The results, U17 Men final, start 2** (measured; one race of four riders):

| | Mark A (starboard, course turn 73) | Mark B (port, course turn 66) | Mark C (starboard, course turn 158) |
|---|---|---|---|
| rounded, right side | 4 of 4 | 4 of 4 | 4 of 4 |
| closest (m; radii) | 7 to 10; 0.10 to 0.17 | 8 to 10; 0.02 to 0.12 | 5 to 12; 0.16 to 0.39 |
| turn starts before the mark (s; radii) | 3 to 5; 0.54 to 0.67 | 4; 0.10 to 0.48 | 3 to 11; 0.88 to 1.79 |
| out of the turn after the mark (s; radii) | 2 (one rider 12); 0.23 to 0.32 (1.28) | 1 to 2; 0.09 to 0.27 | 1 to 8; 0.34 to 1.07 |
| extra turning (deg) | -24 to -18 (one rider +86) | -32 to -26 | -12 to +26 |
| apex share | 0.65 to 0.72 (one rider 0.27) | 0.58 to 0.88 | 0.25 to 0.90 |
| radius (m, foil) | 58 to 76 | 75 to 121 | 31 to 41 |
| speed kept | 1.01 to 1.10 | 0.94 to 0.98 | 0.65 to 0.79 (a fall: 0.16) |

The outliers, each explained: at A one rider bore away and gybed in one turn (86 degrees extra, out of the turn 75 m
and 12 s later); at C one rider fell (3 kt). (A first version of the exit rule also asked for half the course's turn;
a rider coming in already angled never turns that much, so its exit came far too late. Now it is the suite's rule.) The downwind leg A to B:
1.39 to 1.49 times the straight distance, 1 to 2 gybes each. The counted start: all four over within 9 s at 19.4 to
20.8 kt, the last gybe 46 to 60 s before the line; the over-early start 1: within 1 s, the last gybe 52 to 57 s before.

**What the head training can take from it** (proposals; candidates from one race, not targets):
1. **Measure the AI the same way.** Done the same night: `tools/real_races/ai_suite_measure.py`; the comparison and the
   plan for the head are in [HEAD_PLAN.md](HEAD_PLAN.md).
2. **The shape of a good rounding** (here): the turn begins about 3 to 5 s before the mark (half to one and a half turn
   radii out), the board passes the mark at a tenth to a third of a radius, the nearest point late in the turn on the
   bear-aways (apex share about 0.6 to 0.9: wide in, tight out), no extra turning unless a gybe is wanted there. How
   soon it is out of the turn is the race's own tactic (Max), not a rule.
3. **The start**: the last gybe about 45 to 60 s before the gun, then straight at the line; the fleet over within 10 s
   at full speed; a whole fleet over early happens.
4. **The downwind leg**: gybing between two broad reaches, about 1.4 times the straight distance, 1 to 2 gybes.

**Limits.** The marks are Max's drawing (about 20 m; the riders' sides and their 5 to 12 m agree with it), the finish
is provisional, the gun is not recorded, and four riders in one race on foils are a sample. The criteria and the tools
are ready for more races (best: fin races, or races with the buoys).

**Run again:** `python -I tools/real_races/analyse_roundings.py tools/real_races/courses/930_u17_men_final.json
.sim_output/real_races/metasail_930/browser/u17_final_gpx --csv=<out.csv>`; the marks into the GPX files:
`python -I tools/real_races/add_course_to_gpx.py tools/real_races/courses/930_u17_men_final.json <gpx folder> <out folder>`.
A new race: a tracks-only picture (`read_gpx_race.py --marks=0 --size_px=1600`), Max draws the marks, a course file like
this one, then the two commands.
