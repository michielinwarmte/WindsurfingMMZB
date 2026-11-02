# The start and the race in company (package 5, 2 November 2026)

The starter (Opus) on the branch `race/start`: the AI skippers' start (RA16, RA11) and the fleet of twenty in company (RA20). Nothing in `Game/sim/` changed. The brief is in the lead's log ([PROGRESS.md](PROGRESS.md)).

## 1. In short

- **The race tool now waits where the game puts the boards**: 1 m behind the line per second of countdown, 40 to 100 m (60 m for the 60 s countdown), as `RaceRunner` does. It waited 150 m back, from where no board can reach T1's line in a minute in 12 kt (its best way to windward is 2.3 m/s). `--behind=150` still gives the old distance (`tools/gens.sh` passes it for the brains). In the game the AI boards appear by default at random spots in the sailing area (up to 100 m downwind of the line), and the player waits 60 m back.
- **The start plan at the polar's beat (RA16)**: before its start the skipper points at the polar's angle for the wind (54 / 55 / 50 degrees in 12 / 18 / 24 kt), not at 45; the run in to its spot is 15 degrees wider than that (60 to 72); late, it beats to its spot and tacks on the spot's layline with no margin; its waiting point is at least 30 m behind the line or its extensions; and out past an end of the line a board that has gone may still change its mind.
- **The all-rounder alone, from the game's 60 m, crosses within 3 s of the gun at every wind on both courses** (T1 +1.9 / +0.8 / +2.1 s, T2 +2.9 / +1.6 / +1.5 s at 12 / 18 / 24 kt), no OCS. T1 at 12 kt was +11.9 s from 60 m and +59.8 s from 150 m.
- **The race's time limit fits the course and the wind** (`RaceTimeLimit`): 2.5 times the polar's time for the course, never less than 20 minutes. T1 in 12 kt gets 24:15, two laps 45:39; 18 and 24 kt stay at 20 minutes. `tools/race.sh --seconds` longer than the limit raises it.
- **The penalty turn eases down first** (to 5 m/s, at most 6 s), gybes first from a beam reach or deeper, and gets going again on a reach between its two manoeuvres. 6 of the 15 falls in the fleet of twenty were penalty turns begun at 6 to 11 m/s.
- **The fleet of twenty, after:** all 120 races finish (119 before; Ravi finishes T1 in 12 kt), the starts on T1 in 12 kt a minute earlier, but 16 falls against 15 (the penalty-turn falls 6 to 1, the catapults on the close reach in the crowd 5 to 10, half of them at the start, where the twenty now arrive together from 60 m), and on T2 in 12 kt 9 of 20 are over the line at the gun (none before).
- **Not done:** T2's reaching start from 150 m at 24 kt is still over the line at the gun (the game's distances do not produce it; a turn-away I tried made it 27 s later instead); the catapults on close reaches in the crowd (8 of the 15 falls) are not found; the penalty circles on T2 (one to four a board) are reported, not cut.
- **One validation test went red:** `test_living_skipper_fleet.gd`, T1: of 16 boards from random spots at 15 kt, Gambler 2 does not start within 20 s (section 7). The skipper validation's 12 kt limit stays red, nearer: 12:19 against the 12:00 it wants (13:31 before).

## 2. What changed and why

**The race tool's waiting distance** (`Game/dev/run_race.gd`, `wait_behind_m()`). The game places the player and, with the spawn "line", the AI boards 1 m behind the line per second of countdown, 40 to 100 m (`RaceRunner.WAIT_M_PER_S`, `NEAREST_M`, `FARTHEST_M`; Max, 20 October 2026: a player wants the line in sight). The race tool waited 2.5 m per second, 150 m. Its comment said the farther wait was for the 9A autopilot, but the autopilots are placed by their own constant (`APPROACH_M_PER_S`); the skippers' 150 m was a leftover. The numbers that matter are the game's, so the tool's default is now the game's. The brains' tools pass `--behind=150` themselves.

**The start plan at the polar's beat** (`Game/race/skipper.gd`):
- `_pointing_twa_deg()` no longer points at 45 before the start: the polar's angle for the wind, the character's own difference and its pointing offset (`_beat_twa_deg()`), and the foot when slow, as racing. Package 1 had put the start back at 45 because a noisy skipper looped behind T1's line at the wider angle; the three fixes below are what that took.
- The run in (`_run_in_twa_deg()`): `START_RUN_IN_ABOVE_BEAT_DEG` (15) wider than the beat, between 60 and `START_RUN_IN_WIDEST_TWA_DEG` (72), chosen once at the countdown's first look. The old 60 was 15 above the old 45; at the polar's 59 (the gambler's 55 + 4) its track could not lay its spot, it slid along behind the line past the end and was over at the gun (T1, 18 and 24 kt). A cap of 66 brought that back (measured).
- Late, with its spot a beat (`_late_for_the_spot_deg()`): it beats to the spot itself and tacks on the spot's layline with no margin. Aimed through the line (a point that moves with the board) and with its character's layline margin (the rookie's 25 m), the rookie overstood from 150 m, ran up behind T1's line past its end and was OCS. Late and about to cross early with the spot on the other tack, it tacks there and then even when slow (`_ask_for_manoeuvre(needed, even_slow)`): holding back hard it soon sailed too slowly to tack and slid over (the cautious one at 15 kt, 40 m back for a 30 s countdown: OCS, now +5.4 s).
- The waiting point at least `START_WAIT_BEHIND_M` (30 m) behind the line or its extensions (`_well_behind_the_line()`): the way in along the line out past its end lay 20 m behind the extension, and the turn onto it at speed (a tack, toward the wind) took 16 of those metres; the rookie then ran down the extension 2 m behind it at 12 m/s.
- The go latch: a board that has gone keeps going near the line, but out past an end of the line by more than `START_WALL_M` it may change its mind with more than 4 s to spare (the rookie, 134 m past T1's end, kept going with 4 s to spare). Without this change the 16-board fleet test and the rookie on T1 at 24 kt got worse (measured).

**The time limit** (`Game/race/race_time_limit.gd`, `RaceRunner.restart()`, `run_race.gd`): the polar's time for a leg is the way toward (or away from) the wind over the VMG at the best angle on a beat or a run, and the distance over the polar's speed on a reach; the limit is 2.5 times the course's sum, at least 1200 s. The all-rounder alone takes about 1.4 times the polar's time on T1, the slowest of the twenty about 2 (Ravi needed some 1230 s). The game sets it at each start from the player's wind; the HUD and the results' DNF are unchanged.

**The penalty turn** (`_penalty_turn_heading()` and three helpers): phases `PENALTY_EASING` (held back to 5 m/s on its course until slower than 6.5 m/s, at most 6 s), `PENALTY_FIRST` (from 80 degrees off the wind and deeper the gybe, held back to 5 m/s and pressed from 105 degrees; closer to the wind the tack, pressed below 90 degrees and faster than 3 m/s), `PENALTY_BETWEEN` (getting going on a reach, no closer than the pilot's 70-degree bear-away angle, to 4 m/s), `PENALTY_SECOND` (the other one), then done when the controller is free. A manoeuvre the controller did not begin is pressed again after 3 s.

## 3. The starts, before and after

Seconds from the gun to the crossing (the race tool's start report), seed 1, start-only races (`--stop_after_gun`). "Before" is the code of f8173ad.

**The all-rounder alone:**

| Course, wind | before, 150 m | before, 60 m | before, random spots (2) | after, 60 m | after, random spots (4) | after, 150 m |
|---|---|---|---|---|---|---|
| T1 12 kt | +59.8 | +11.9 | +11.8, +10.0 | **+1.9** | +13.7, +7.5, +7.6, +1.8 | +24.8 |
| T1 18 kt | +2.0 | +2.4 | +3.3, +3.9 | **+0.8** | +0.7, +2.2, +1.1, +0.6 | +1.7 |
| T1 24 kt | +2.8 | +3.3 | +3.8, +4.4 | **+2.1** | +0.6, +3.1, +1.0, +1.2 | +1.6 |
| T2 12 kt | +4.4 | +2.9 | +7.9, +12.7 | **+2.9** | +4.4, +5.5, +2.1, +3.1 | +4.4 |
| T2 18 kt | +3.2 | +1.0 | +1.5, +1.2 | **+1.6** | +1.5, +1.3, +3.9, +1.3 | +2.5 |
| T2 24 kt | +28.6 OCS | +1.5 | +1.3, +1.3 | **+1.5** | +1.6, +1.5, +1.8, +1.6 | +28.5 OCS |

From 150 m in 12 kt T1's line is out of reach in a minute (physics, not the skipper). From random spots in 12 kt the T1 start is still 7 to 14 s late in three of four: the board appears far along the line or on the course side and its way to the spot is long and slow.

**The four characters together** (all-rounder / cautious / gambler / rookie), 60 m:

| Course, wind | before | after |
|---|---|---|
| T1 12 kt | +12.7 / +16.4 / +3.5 / +51.6 | +1.8 / +11.1 / +1.0 / +21.7 |
| T1 18 kt | +5.0 / +5.0 / +1.9 / +5.8 | +0.9 / +3.0 / +1.0 / +3.5 |
| T1 24 kt | +3.5 / +6.9 / +1.3 / +3.9 | +2.0 / +6.5 / +0.7 / +3.7 |
| T2 12 kt | +10.6 / +11.4 / +1.4 / +21.0 | +6.9 / +12.1 / +1.4 / **+29.5 OCS** |
| T2 18 kt | +1.2 / +3.1 / +0.7 / +4.4 | +0.6 / +3.3 / +0.7 / +4.2 |
| T2 24 kt | +1.1 / +4.3 / +1.2 / +3.2 | +1.5 / +4.5 / +1.1 / +2.2 |

Better or equal in 19 of 24, the sum 181 s to 125 s; worse: the rookie on T2 in 12 kt (OCS; it is stuck at 1.5 to 2 m/s for 25 s in the others' wind shadows on a line that runs along the wind, before it starts its way in), and four by 0.2 to 0.7 s (the cautious one on T2 at 12, 18 and 24 kt, the all-rounder on T2 at 24 kt). From 150 m the T1 starts in 12 kt went from +45 to +76 s to +24 to +44 s; T2 at 24 kt from 150 m is unchanged (all-rounder and rookie OCS, section 6).

**The twenty in a fleet** (`tools/persona_matrix.sh --courses=t1_loop,t2_slalom --run=fleet_after`, seed 1, their own gear, the rules and the shadows), against the caster's `fleet` run (the code of 54734ed, the boards 150 m back): the median start and the latest, and the boards over at the gun.

| Race | before (150 m): median, latest, OCS | after (60 m): median, latest, OCS |
|---|---|---|
| T1 12 kt | +70 s, +144 s, 0 | **+9 s**, +63 s, 0 |
| T1 18 kt | +4.7 s, +69 s, 0 | +1.6 s, +32 s, 1 |
| T1 24 kt | +1.7 s, +146 s, 0 | +1.2 s, +72 s, 1 |
| T2 12 kt | +6.6 s, +15 s, 0 | **+19 s, +82 s, 9** |
| T2 18 kt | +5.3 s, +46 s, 1 | +3.4 s, +7.4 s, 0 |
| T2 24 kt | +1.8 s, +38 s, 1 | +1.3 s, +6.9 s, 0 |

T1 in 12 kt starts a minute earlier, T2 in 18 and 24 kt without the stragglers. **T2 in 12 kt is worse: 9 of 20 over the line at the gun.** Twenty boards 60 m back on a line that runs along the wind are a column in each other's wind shadows in 12 kt (the rookie's OCS among the four characters is the same thing); I did not get to it. Every one of the 120 races finishes (119 before: Ravi now finishes T1 at 12 kt in 15:47.6, 18th; the limit there is 24:15). The winners: T1 11:35.4 (Lena), 8:22.5 (Pavel), 6:49.7 (Sven); T2 5:04.1 (Pavel), 3:14.9 (Mara), 2:48.9 (Elin); before 12:39.5, 7:45.4, 6:46.0, 5:13.0, 3:26.9, 2:43.0. The table of places is in `.sim_output/persona_matrix_fleet_after.txt`.

## 4. The races

**The all-rounder alone** (`tools/race_matrix.sh --skippers=allrounder`), the time, the start and the falls; before on f8173ad's code from 60 m (`--behind=60`):

| Course, wind | before, seed 1 | after, seed 1 | after, seed 2 |
|---|---|---|---|
| T1 12 kt | 13:01.2, start +11.9 | **12:16.0**, +1.9 | 12:19.5, +2.0 |
| T1 18 kt | 7:36.3, +2.4 | 7:34.6, +0.8 | 7:31.8, +1.1 |
| T1 24 kt | 6:20.7, +3.3 | 6:25.9, +2.1 | 6:17.4, +2.0 |
| T2 12 kt | 5:00.6, +2.9 | 5:00.6, +2.9 | 4:57.2, +2.9 |
| T2 18 kt | 3:04.8, +1.0 | 3:06.5, +1.6 | 3:08.5, +1.5 |
| T2 24 kt | 2:40.9, +1.5, 1 fall | 2:40.9, +1.5, 1 fall | 2:30.6, +1.5 |

T1 in 12 kt is 45 s faster, all of it at the start; the rest is within a few seconds either way (T2's start is a reaching start, whose run in is the first leg and did not change, so T2's races barely move). From the tool's old 150 m the 12 kt race was 13:31 (the lead's runs); the skipper validation's 12 kt race (seed 0) is now 12:19.3.

**The four characters together** (`tools/race_matrix.sh`, seed 0; before: `--behind=60` on f8173ad's code), the starts and the times:

| Race | before: starts (A / C / G / R), places | after: starts, places |
|---|---|---|
| T1 12 kt | +16.5 / +63.5 / +2.5 / +20.8; A 12:42.4, G 12:57.5, C 14:20.3, R 15:57.2 | +1.6 / +12.5 / +1.5 / +12.1; A 12:48.8, G 13:03.7, C 14:14.9, R 15:13.0 |
| T1 18 kt | +4.7 / +6.1 / +1.9 / +4.2; A 7:53.2, G 8:04.7, R 8:24.4, C 8:37.8 | +0.6 / +3.0 / +1.0 / **+40.6**; G 7:40.3, A 7:58.9, C 8:37.9, R 9:08.4 |
| T1 24 kt | +3.3 / +6.2 / +1.8 / +5.5; A 6:29.5, C 6:58.1, G 7:03.0, R 7:15.0 (1 fall) | +2.0 / +5.5 / +0.9 / +3.7; A 6:29.7, G 6:57.8, C 7:29.7 (1 fall), R 7:54.9 |
| T2 12 kt | +10.3 / +12.0 / +1.5 / +17.4; G 4:53.3, C 5:32.2, R 5:55.8, A 6:30.9 | +7.4 / +13.9 / +1.5 / +19.0; G 4:55.0, A 5:00.9, R 5:44.0, C 5:57.5 |
| T2 18 kt | +1.5 / +3.4 / +0.7 / +4.1; G 3:06.1, R 3:21.9, C 3:34.1, A 3:35.5 | +1.1 / +2.6 / +0.5 / +4.1; G 3:07.7, R 3:18.7, A 3:30.1, C 3:45.2 |
| T2 24 kt | +1.1 / +4.8 / +0.6 / +4.0; A 2:30.0, G 2:36.8 (1 fall), C 2:39.3, R 3:00.7 | +1.4 / +4.2 / +0.6 / +4.0; G 2:34.1, R 2:41.2, C 2:50.6 (1 fall), A 3:11.6 (2 falls) |

The starts: the sum 198 s before, 145 s after; no OCS before or after; worse in this seed: the rookie on T1 at 18 kt (+40.6 s; +3.5 s on seed 1). The 24 times: 2:43:59.7 before, 2:44:14.6 after (+0.15 %, the same within a seed's noise). The falls: 2 before, 4 after (none in a penalty turn: T2 at 24 kt had no penalty at all); the all-rounder's two on T2 at 24 kt are on the reaches, where it falls once alone on seed 1 too.

## 5. The falls in company

Read from the caster's fleet tracks (`../WindsurfingMMZB-characters/.sim_output/race_matrix_fleet/`), the 8 s before each fall; the skipper's note says what it was doing. The 15 counted falls:

| Kind | Falls | Who, where |
|---|---|---|
| A penalty turn begun at speed: the tack stops the board (0.2 to 0.8 m/s), the bear-away for the gybe right after it puts the sailor in ("fell off"); or the head-up from a run at 10.7 m/s ("catapult") | 6 | Bruno 4 (T1 18 kt and 24 kt twice, T2 24 kt), Liv (T1 24 kt), Aiko (T1 24 kt) |
| A catapult on a close reach or a beat at 8 to 11 m/s, sailing for the layline to mark 1 or keeping clear | 5 | Marco, Pia, Tomas (T1 18 kt), Noor, Elin (T1 24 kt) |
| A catapult on a beam reach at 12 to 14 m/s | 2 | Hana (T2 18 kt, keeping clear), Bruno (T2 24 kt) |
| Heading up at 7 m/s across the start line, keeping clear | 1 | Elin (T2 24 kt) |
| A gybe at 15 m/s at mark 3 | 1 | Pavel (T2 24 kt) |

The first kind is the skipper's and is fixed (section 2, the penalty turn; a unit test). The catapults on reaches have no common skipper action in the 5 s before them: a third were keeping clear (bearing away up to 15 degrees), the others sailed on. Alone the same personas fell 3 times in 120 races, so the crowd adds them; the likely cause is the wind shadows (a board leaving another's shadow at planing speed gets the full wind at once), which is the shadow model and the catapult in the physics, not the skipper. I did not prove that.

**After, in the fleet of twenty** (the same reading of `fleet_after`): **16 falls against 15** (T1 0 / 6 / 7, T2 0 / 0 / 3 at 12 / 18 / 24 kt; before 0 / 4 / 6 and 0 / 1 / 4). In a penalty turn: 1 (Liv, T2 at 24 kt, at 8.8 m/s after the tack) against 6. On a close reach or a beat at 7 to 11 m/s on port tack, mostly sailing for the layline to mark 1 or keeping clear: 10 against 5 (Lena twice, Marco, Ravi, Pia on T1 at 18 kt; Aiko, Hana, Marco on T1 at 24 kt, with Bruno and Kofi going for the line at 10 m/s before the gun), and one before the gun on the way to the waiting point (Sven, 11.7 m/s). On a reach at 15 m/s and a gybe at a mark at 14 m/s: 2 (Bruno, Pavel; before too). So the penalty falls are gone, but the catapults on the close reach in the crowd rose: from 60 m the twenty reach the line together, at speed, in each other's shadows (5 of the 10 are at the start), where from 150 m they straggled in over a minute or two. **The falls did not go down, against the brief's "must not rise": 16 against 15.** The penalties: 305 given against 310, 211 circles turned against 196.

## 6. T2's reaching start from 150 m, and the penalty circles

**The reaching start (RA16's second half).** From the game's distances (60 m on the line, random spots) the all-rounder starts T2 at 24 kt within 2 s. Only from 150 m (the old tool default, the brains' distance) is it over at the gun: it reaches its waiting point with 12 s more than its way in can use up (held back to 2 m/s on a track nearly straight at the line, the line running along the wind), and a loop costs some 30 s. I tried a turn-away (tack away from the line, slow, when early by more than 8 s at the slowest): no OCS, but the all-rounder was 55 s late (the go logic took over after the turn and sailed away on the other tack) and the cautious one 20 s instead of 1. Reverted. What it would take: a third start plan for a line along the wind, a slow figure of eight behind the line (two tacks at the hold speed, each away leg timed to half the excess), kept apart from the go logic until the time left is what the way in can use up.

**The penalty circles.** The caster's fleet turned 23 to 45 penalty circles a race (39 to 66 penalties given). Most begin on the first leg: on T2 16 of about 31 in the first 30 s after the gun, on T1 at 18 and 24 kt 10 and 16. The judge gives none before the gun, so these are the boards crossing the line together: on T2 the line runs along the wind, the boards come in on the same reach, overlapped, and the windward one must keep clear (rule 11). Giving room earlier would mean the skipper choosing its spot and its time on the line knowing the others' (a spot not taken by a board to leeward, or crossing a second later behind it); the skipper sees the others only for keeping clear. That is a new piece of the start, not a cheap fix; with the penalty turn now easing down first, the circles cost time but should cost fewer falls.

## 7. What I could not verify

- **`test_living_skipper_fleet.gd` (validation) is red for T1**: 16 boards (four of each character) from random spots at 15 kt, Gambler 2 does not start within 20 s after the gun. It was green before this work (the lead's runs of the skipper validation). The gambler (pointing +4, its spot at the boat end) runs in at the 72-degree cap from 136 m along the line and slides down the line early, holding back and going in turn, and crosses the far end's extension. A cap of 66 made the same test worse (4 not started), and so did the old go latch (2). The ROADMAP calls this test flaky (RA11); it is a real late start here. Reproduce: `tools/race.sh --course=t1_loop --skippers=allrounder,cautious,gambler,rookie --boards=16 --wind_kt=15 --seed=0 --spawn=random --spawn_seed=1 --shadows=0 --rules=0 --gear=0 --stop_after_gun=40`.
- **The skipper validation**: `tools/test.sh validation -gselect=skipper`: test_skipper.gd as before, only the 12 kt limit red (12:19.3 against 12:00; 13:31 before); the 24 kt race finishes; the 18 kt start +1.9 s. 10 of 12 tests pass.
- How the starts look and feel in the game, with the player among the boards: not seen (headless only).
- The catapults in company: the cause is a guess (section 5).
- One seed for the starts (seed 1) and the fleet; the alone races on seeds 1 and 2.

## 8. Open items for the roadmap

- **RA (the fleet start test, first):** `test_living_skipper_fleet.gd` red on T1 (Gambler 2, section 7): the run in for a skipper whose beat is 59 degrees and more, from far along the line.
- **RA16 (rest):** T2's reaching start from 150 m at 24 kt (section 6): a figure of eight behind a line along the wind. Only the brains' distance produces it.
- **RA11 (rest):** from random spots in 12 kt the T1 start is still 7 to 14 s late (three of four spots); the countdown's length stays the team's decision (the second RA11).
- **RA20 (rest):** the catapults on close reaches in the crowd (8 of 15 falls), likely the wind shadows: a physics question first (a PH item for Michiel: how sudden is the wind's return out of a shadow, and does the pilot's sheet catch it); the penalty circles at the reaching start (section 6).
- **RA (first with the fleet test): T2's start in 12 kt in a crowd**: 9 of 20 over at the gun in the fleet, the rookie among the four characters: twenty boards 60 m back on a line along the wind sit in each other's shadows, slow, and come in late and then over. Before (150 m) none.
- **RA20 (falls):** 16 against 15 in the fleet; the catapults on a port-tack close reach at 7 to 11 m/s in the crowd (10), half at the start. A skipper lever to try: hold back to 7 or 8 m/s on a close reach while another board is within a few lengths to windward (its shadow) or in the last 10 s before the gun; and the physics question above.
- **RA11 done in part, RA16 done in part, RA20's limit and the penalty falls done.**

## 9. The commands

- The starts (start-only races): `tools/race.sh --course=t1_loop --skippers=allrounder --wind_kt=12 --seed=1 --stop_after_gun=120` (add `--behind=150`, or `--spawn=random --spawn_seed=0`; the four characters `--skippers=allrounder,cautious,gambler,rookie`). The start report is printed at the end ("Starts:").
- The all-rounder alone: `tools/race_matrix.sh --skippers=allrounder --seed=1 --run=alone_after_s1` (and `--seed=2`); before, on f8173ad's code: `--behind=60 --run=alone_before60`.
- The four characters: `tools/race_matrix.sh --run=chars_after` (before: `--behind=60 --run=before60` on f8173ad's code). The brief's `--run=start_after` would share its folder with the persona matrix's run of the same name, so the two runs have their own names.
- The twenty in a fleet: `tools/persona_matrix.sh --courses=t2_slalom --run=fleet_after`, `--courses=t1_loop --run=fleet_after`, then `--courses=t1_loop,t2_slalom --run=fleet_after --table_only=1` (`.sim_output/persona_matrix_fleet_after.txt`).
- The falls and the penalty circles in a fleet's tracks: the two small Python scripts of this work read the CSVs (a fall: the first row whose note begins "in the water"; a circle: the first row whose note begins "penalty turn"); they are a few lines each and are described here rather than kept.
- The tests: `tools/test.sh`, `tools/test.sh validation -gselect=skipper`, `tools/check.sh`.

## 10. The tokens

About 0.6 M tokens, the whole budget (my estimate; the harness has the exact count). Most went on reading the start code and the tracks and on the start's iterations (seven rounds of start-only races); the measuring ran in the background, some 200 headless races beside the training night, never more than six Godot processes of mine at once.
