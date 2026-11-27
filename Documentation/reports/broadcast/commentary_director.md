# The commentary director: the stream commentator's lines as subtitles in watch mode (27 November 2026)

Max, 27 November 2026: "i want a fifa kind of commentating in the game", and: "you have to replicate their exact
sentences". This is phase P6 of the broadcast study ([PLAN.md](PLAN.md)): the commentator's own lines, said at the right
moment of the race, about what the camera shows, as **subtitles first**. The voice waits for the commentator's yes (P7).

Branch `broadcast/commentary-director` (from `broadcast/study-27nov`), worktree `WindsurfingMMZB-commentary`.
Backlog E16.S06. Not yet seen on Max's screen.

## What it does, in plain words

While you watch the AI race with the TV director on (T), a line of the real commentator appears at the bottom of the
screen, the way TV subtitles do: "You've got Mara in the middle on that Savanna." "Here we go. Look at that." "Oh, what
a gybe from Hana." The names are the game's own sailors, the brands the game's own brands.

Three parts do the work:

1. **The race story** watches the race about 20 times a second and notices what happens: the gun, a lead change, a
   board closing on the one ahead, a fall, a gybe at a mark and how well it went, the finish. Each of these is a
   *moment* (the list is in [BANK_FORMAT.md](BANK_FORMAT.md)).
2. **The commentary director** decides what to say and when: the biggest thing first, never two lines at once, a short
   breath between lines, small talk about the board on the screen when nothing is happening, never the same line twice
   in a short time.
3. **The subtitles** show the line for as long as he takes to say it, plus a moment to read it.

The lines come from the bank, `Game/race/commentary/commentary_bank.json`. Today that is the starter bank: 76 real lines
from one heat, picked by hand (73, and three for the newest moments). The full bank (hundreds to thousands of lines
from 27 hours of streams) replaces it later in the same format; nothing in the game needs to change for that. The
moments are the 35 of BANK_FORMAT.md: the first list's 28, the three the lead added from the replays (`trouble`, `wow`,
`oh_no`) and Max's four (`tactics`, `tension`, `form`, `conditions`).

Every line that starts goes out as a signal (`line_started`: its id, its words, its seconds, its level), so a sound
player can be attached later, when each line has its own sound file.

## The keys and the options

| Key / option | What it does |
|---|---|
| **V** (watch mode) | The commentary on or off. It comes on by itself with the TV director (T) and goes off with it. With V you can switch it on or off at any time; without the TV director it talks about the board you follow. |
| H (the screen levels) | Full and TV screen: the subtitles show. Clean screen: no subtitles (the commentary goes on unseen, so it is right there when the screen comes back). |
| P (freeze) | The commentary stops with the race; the subtitle on the screen stays. |
| `--commentary=1` or `=0` | On or off from the start (after `--tv`, whatever their order). |
| `--subtitle_test="<words>"` | Keeps those words on the screen: for screenshots of where the subtitles sit. |

The V key is in watch mode's key row and in the Watch button's tooltip on the Race page. To make the key row fit a
1280 x 720 window with the new key, "new race / same again" became "new race / again". The corner card says
"Commentary on (V)" in the full screen.

## The moments: how each is detected

All the numbers are in `Game/config/commentary_default.tres` (`CommentaryConfig`); the defaults are given here.
The story reads only what the race (`RaceSim`) and each board's telemetry already offer; nothing in `Game/sim/` changed.

**Before and at the start**

| Moment | How it is detected |
|---|---|
| `pre_start` | At 50, 28 and 12 s before the gun (`pre_start_at_s`). |
| `start_gun` | The race clock passes 0. |
| `over_early` | Boards over the line at the gun (the race's own OCS check); one moment for the first of them (the second as `{rider2}`). The starter bank has no lines for it yet, so it is heard but not said. |
| `start_good` | 8 s after the gun (`start_judge_s`): the first board over the line within 3 s of the gun (`good_start_within_s`) while planing. |
| `start_bad` | At the same time: the board farthest from the line that has not crossed it and was not over early. |

**On a leg**

| Moment | How it is detected |
|---|---|
| `lead_change` | A new first place that has held 2.5 s (`order_hold_s`; the game's smart order moves a little all the time), not in the first 15 s after the gun (`order_from_s`, the start's shuffle). `{rider2}` is the old leader. |
| `overtake` | A board up a place (not to first) that has held 2.5 s; `{rider2}` is the board now behind it, if it was ahead before. |
| `chase` | A board closing on the board just ahead in the order: within 50 m of it (`chase_near_m`) and at least 8 m nearer (`chase_gain_m`) than up to 8 s ago (`chase_window_s`), but not yet within fight range. Not again for the same two within 40 s. |
| `fight` | Two boards next to each other in the order within 15 m (`fight_m`) for 6 s (`fight_after_s`). `{rider}` is the board ahead ("{rider} needs to hold off {rider2}"), `{place}` its place ("the battle for second place"). Not again for the same two within 45 s. |
| `trouble` (new, the lead's addition) | Without a fall: a board off the plane for 3 s (`trouble_off_plane_s`) while at least half the racing fleet planes (else it is a lull), not round a mark (that is the gybe's), not within 15 s of a fall or of the gun; or a board down 2 places or more (`trouble_places`) within 15 s without a fall. |
| `airtime` | The water carries less than 8 % of the board's whole weight (its buoyancy and planing lift: the same two the autopilot reads for "light over a crest") for at least 0.25 s, and the board is still sailing 1 s after it landed. |
| `last_leg` | The leader starts the last leg (sailing to the finish). |
| `tactics` (Max's) | Small talk about the board on the screen, when there is something to say about its line: it sails in another sail's dirty wind (the shadows take at least 3.75 % of its wind, `dirty_air_share`: the race's own threshold for dirty air, about half a full shadow); or it is at least 4 m to windward or to leeward (`tactics_side_m`) of the board next to it in the order within 25 m (`tactics_near_m`; that board is `{rider2}`); or else at least 25 m above or below its straight line from the last mark to the next (`tactics_line_m`). The moment says which (the needs `windward`, `leeward`, `dirty_air`), so "He's got a lower line." can be kept for a board that is lower. |
| `tension` (Max's) | Small talk: the lead or the last place on the podium (`tension_places` 1 and 3) on its last two legs (`tension_legs`), the board behind within 3 s of it (`tension_s`: the gap on the water over the chaser's speed). `{rider}` holds the place, `{rider2}` chases. |
| `form` (Max's) | Small talk about the board on the screen: it has led for 60 s or more (`form_lead_s`), or it is up 2 places or more within 60 s (`form_places`, `form_window_s`). |
| `conditions` (Max's) | Small talk, from the countdown on (most at home there, where there is little else to say): the day. The lines are picked by the needs `wind_strong`, `wind_light`, `choppy`, `flat` (below), so "It's absolutely howling out there." never comes in light wind. |

**At a mark**

| Moment | How it is detected |
|---|---|
| `mark_approach` | A board of the first three within 70 m of its next mark or gate (`mark_approach_m`, `mark_front`), once per board and mark. `{mark}` is "first", "second" ... "last". |
| `gybe_good`, `gybe_safe`, `gybe_bad` | See "How a gybe is judged" below. |

**When it goes wrong**

| Moment | How it is detected |
|---|---|
| `fall` | The sailor goes into the water (the telemetry's sailor state). Level 4 for the leader, 3 for the first three, 2 behind. |
| `near_miss` | Two racing boards within 4 m (`near_miss_m`) whose speeds differ by at least 3 m/s (`near_speed_ms`): crossing or closing, not two boards side by side in a fight. Not in the first 8 s after the gun. The game's boards pass through each other, so a near miss can also be a touch. |

**The finish and after**

| Moment | How it is detected |
|---|---|
| `finish_win` | The first board over the finish line. |
| `finish_place` | Every board after it, with its place. |
| `photo_finish` | Two boards next to each other in the order, both on the last leg within 50 m of the line and within 6 m of each other; or crossing within 1 s of each other. |
| `after_race` | 8 s after the winner crossed, and again when the race is over. |

**Small talk** (what fills the time between events; offered by the story, chosen by the director)

| Moment | When it is offered |
|---|---|
| `identify` | Always, about the board on the screen. The same board is not identified again within 40 s. |
| `unsure` | Only on a wide shot, about the board on the screen ("Is that {rider}? Can't quite see from here."). |
| `camera` | Always; the lines' own `camera_wide` / `camera_close` needs pick the shot they fit. |
| `tactics`, `tension`, `form`, `conditions` | As above, when the race shows them. |
| `speed` | The board on the screen planes at 4 % or more above the fleet's median planing speed, or gained a place in the last 20 s. From 15 s after the gun. |
| `leader` | About the leader. From 15 s after the gun. |
| `rundown` | From 15 s after the gun, with at least 3 boards. |
| `filler` | Racing. The starter bank has no filler lines yet. |

**His reactions** (`wow`, `oh_no`, the lead's addition): these are not detected by the story. The director adds one in
front of a big moment (see "Pairs" below).

### How a gybe at a mark is judged

What the race really offers about a rounding: each board's speed, whether it planes, its heading, the side its sail is
on, its wind angle, where it is, whether it fell, and when the race counts the mark as rounded. So the story watches
every rounding from 35 m before the mark (`rounding_from_m`) until 4 s after the board's stern went through the wind
(`gybe_exit_s`: the gybe and the way out of it), or, when it does not gybe, until 8 s after the race counted the mark
(`gybe_wait_s`), and keeps:

- the speed going in (when the watch began), and the least speed through the turn: **the share of the speed kept**;
- the seconds **off the plane** (for a board that was planing going in);
- **how near the mark** it went: its nearest distance to the mark, or to the nearer end of a gate;
- whether it **fell**;
- whether it **gybed**: its stern went through the wind, that is its wind angle changed sides beyond 150 degrees
  (`gybe_twa_deg`: from -178 to +178, say; a tack changes sides through 0). A rounding without a gybe (a bear-away at a
  windward mark, a head-up) gets no gybe line at all.

| Judged | When |
|---|---|
| `gybe_good` | kept at least half its speed at its slowest (`good_kept` 0.5), at most 1 s off the plane (`good_off_plane_s`), within 8 m of the mark (`tight_m`): a planing gybe, tight |
| `gybe_bad` | all but stopped: less than 15 % of its speed kept (`bad_kept`), or wider than 20 m (`wide_m`) |
| `gybe_safe` | everything between: it came off the plane but kept going |
| (nothing) | it fell: the fall is told as a fall |

**Where the numbers come from: the AI's own gybes.** The transcript lists every rounding the story watched with what
it measured, and the race tool's tracks (`.sim_output/race/<board>.csv`) have each board's heading and speed every
0.1 s. In the T2 slalom at 18 kt (6 personas, seed 1) the AI gybes only at the last mark (marks 1 and 2 are rounded
without one: the wind angle stays at 110 to 136 degrees). Its six gybes there:

- the race counts the mark 3.3 to 4.7 s **before** the stern goes through the wind (the sail goes across at the same
  moment). The first version watched until 3 s after the mark, so it saw no gybe at all: every rounding came out "no
  gybe line". Now the watch goes on until 4 s after the stern went through the wind;
- they go in at 23 to 24 kt and slow to **3 to 4 kt** (13 to 18 % of the speed kept), the slowest about 4 s after the
  stern went through the wind, 4 to 6 m from the mark; 8 s after it they are back at 14 to 18 kt.

So the AI's gybes today all but stop. A real slalom gybe keeps far more than that, so none of the six is good by these
numbers; the three that kept less than 15 % are bad and the other three safe. These are the numbers of one race in
one wind: to be checked on more races (the random suite measures every rounding: `tools/real_races/ai_suite_measure.py
--what=roundings`), and against what Max calls a good gybe. If the AI's gybes are judged against each other instead
(the best of the race good), that is a change of the numbers in the config, not of the code. **This is a finding for
the AI's track too: in this race its gybes lose about 85 % of their speed.**

**The day's needs** (`conditions`, and any line that carries them):

| Need | Holds when | Why that number |
|---|---|---|
| `wind_strong` | the fleet's mean true wind at 10 m, smoothed over 20 s (`day_smooth_s`), is 22 kt or more (`wind_strong_kt`) | the game sails 12 to 24 kt (its matrices: 12, 18, 24); 22 and up is the top of that, where the lake's matrix starts to see catapults |
| `wind_light` | that mean is 13 kt or less (`wind_light_kt`) | the boards plane from about 10 kt (the planing onset check, 9.9 kt); 12 to 13 kt is the light end of a slalom day |
| `choppy` | the sea's significant wave height is 0.3 m or more (`choppy_hs_m`) | measured under the boards: four times the standard deviation of the water's height under each board over 20 s, averaged over the fleet (the usual measure of a sea). The game's lake grows its own waves with the wind over its 3 km (PHYSICS_SPEC 9.17: about 0.17 m at 12 kt, 0.23 m at 16 kt, 0.34 m at 24 kt), so 0.3 m is the lake in a strong wind |
| `flat` | that height is 0.12 m or less (`flat_hs_m`) | below the lake's 12 kt sea; the open water's fixed set of waves is about 0.2 m, so it is neither flat nor choppy |

Measured with the race tool: on the open water the story measured 0.23 m, which is exactly the significant height of
the game's fixed set of waves (4 x the root of half the sum of the squared amplitudes: 0.08, 0.02 and 0.005 m), so the
measure is right; on the lake at 15:00 (the lake's mean wind 16.7 kt, the fleet measured 18.0 kt at its boards) near
T2's start, 0.13 m, about half the law's value for the whole lake's fetch (that part of the lake has less fetch). So
on the lake today `flat` is close and `choppy` needs a strong wind; on the open water neither holds.


## The picking rules and their numbers

- **One voice at a time.** A line takes its `seconds` (measured from the stream). Then a breath of 0.4 to 1.5 s
  (`pause_min_s`, `pause_max_s`, drawn each time) before news; 1 to 3 s before small talk (`quiet_pause_min_s`,
  `quiet_pause_max_s`). The stream's pace (about 300 short sentences in 9 minutes, in bursts with 1 to 3 s pauses) is
  the yardstick; see the transcript's numbers below.
- **The biggest news first.** Every moment has a priority (`priority`): the winner 10, a photo finish 9.5, a lead change
  9, the gun 8.5, a fall 8, a near miss and over early 7.5, airtime 6.5, a bad gybe and a place at the finish 6, the last
  leg, a good gybe and trouble 5.5, an overtake and the start's judgements 5, a fight and the verdict 4.5, a chase and a
  mark approach 4, a safe gybe 3.5, the fleet lining up 3; small talk 1 to 2.5. Each level above 2 adds 1 (the
  leader's fall is bigger than a fall at the back); a moment about the board on the screen adds 1.5; one about a board
  from sixth place back that is not on the screen loses 1.5.
- **Big moments cut in.** A moment of priority 7 or more (`cut_in_from`) that is at least 3 bigger (`cut_margin`) than
  the line being said cuts it short: a lead change, a fall or the finish over an identify. The cut line's
  `line_stopped` signal goes out, so a sound player can stop it too.
- **Too late is dropped, not said late.** Each moment may wait a few seconds for its turn (`late_s`): the gun 1.5 s, a
  photo finish and a near miss 3 s, a fall, airtime and the winner 4 s, a gybe 4 to 5 s, a lead change, an overtake and
  trouble 6 s, a chase and a place at the finish 8 s, a fight 10 s, the verdict 20 s; the others 5 s. Later than that,
  it is dropped.
- **The board on the screen.** Small talk is about the board the TV director shows (its `focus`); news about it counts
  more (above). `camera_wide` holds on the helicopter, the overhead drone, the start's wide shot, the committee boat and
  the finish line; `camera_close` on the chase drone, the drone beside the board and the group shot; the mark's drone
  is neither.
- **No line twice in a short time.** Not the same line within 240 s (`repeat_line_s`); a line with a slot, whose words
  change with the board, within 40 s (`repeat_slotted_line_s`: his most said line by far is a rider's name on its own,
  "{rider}.", 148 times in 1 h 45 min of replays, so it must be able to come back for another board); and not the same
  words within 90 s whatever the line (`repeat_words_s`: "Hardcore racing." and "Hardcore racing!" count as the same,
  and "Hana." is not said again for 90 s). The memory lasts across races (R), so a new race does not start with the
  same lines.
- **Spread over the bank, his staples more often.** Of the lines that fit: the nearest level first, then the least used
  for how often he says it (a line's uses over the square root of its `count`), then by chance. So every line gets
  used, and a line he said 9 times in the streams comes about three times as often as one he said once.
- **The level fits the moment.** The story gives each moment a level (a photo finish 4, a lead change 3, a routine
  rounding at the back 1); the line with the nearest level is taken.
- **The needs.** `leader`, `not_leader`, `podium`, `big_lead` (the leader 60 m clear, `big_lead_m`), `close` (within
  15 m, `close_m`), `camera_wide`, `camera_close`, `many` (6 boards or more), `pair`, `last_lap`, the day's
  `wind_strong`, `wind_light`, `choppy`, `flat` (above), and the tactics' `windward`, `leeward`, `dirty_air`, as in
  BANK_FORMAT.md. A line whose needs do not hold is not taken.
- **The slots.** `{rider}`, `{rider2}`: the sailors' names as the game shows them (the player's own board, "You", is
  not named: a line with its name is skipped). `{place}`: "first" to "twentieth". `{mark}`: "first", "second" ...,
  "last". `{leg}`: "first" ..., "penultimate", "last". `{brand}`: the brand of the board's sail from the game's own
  catalogue (a board on the default rig has none: skipped). `{colour}`: the colour the sail shows (an AI skipper's own
  tint), named only when sure: red, orange, yellow, green, turquoise, blue, light blue, purple, pink, brown, white,
  grey, black; a colour between two names (Sven's teal) or a pale one (Elin's cream) gets no word, and the line is
  skipped. `{national}`, `{nation_adj}` (the lead's addition): the game's sailors have no country yet, so those lines
  are skipped. A line with any slot that cannot be filled is skipped.
- **Not twice in a row.** A mark approach, a safe gybe, a chase, a fight, the fleet lining up and the start's
  judgements do not come twice in a row within 6 s (`not_in_a_row`): three boards at a mark are not three mark
  approaches one after the other.
- **The rundown.** A sequence: one line per board, down the order to sixth place (`rundown_places`), 0.3 s apart
  (`rundown_pause_s`). A line names the board or its place. Anything new stops it. A place said on its own ("Second.")
  is followed by the board's name as the pair's second line.
- **Pairs.** His reaction first, then the line about what happened, with no breath between (0.15 s, `pair_gap_s`):
  "Wow." before a lead change, an overtake, airtime, a good gybe, a photo finish, the winner, a chase; "Oh no." before
  a fall, a near miss, trouble, a bad gybe, over early (`reaction`). Only for big moments (level 3 or more), half the
  time (`reaction_chance`), and only when a reaction line fits. The starter bank has no reaction lines yet, so this
  waits for the full bank.
- **Small talk** when nothing new is happening: chosen by weight (`quiet_weight`: identify 3, speed 2.5, tension 2.5,
  leader 2, rundown 1.5, tactics 1.5, form 1.2, conditions 0.8, camera 0.7, unsure 0.7, filler 0.6), each kind not again
  within its own time (`quiet_again_s`: identify 5 s, speed 14 s, tactics 20 s, leader 22 s, filler 25 s, tension 25 s,
  camera 35 s, unsure 45 s, form 45 s, conditions 60 s, rundown 70 s).
- **Time.** The director runs on real seconds (at 4x speed he does not talk four times as fast: he says less of the
  race, and more is dropped as too late); the story on the race's clock, looking every 0.05 s (`look_every_s`).

## Reading a race's commentary without watching it

```
tools/race.sh --course=t2_slalom --skippers=persona:mara,persona:hana,persona:kofi,persona:liv,persona:noor,persona:tobias --spread=0.5 --wind_kt=18 --seed=1 --commentary=1
```

writes `.sim_output/commentary/t2_slalom_seed1.txt` (`--commentary_out=<file>` for another name,
`--commentary_seed=<n>` for other choices of line). Each line: the race time (negative before the gun), the moment,
the line's id, the words, and in brackets the shot and the board on the screen, the moment's boards and what the story
measured (for a gybe: the speed kept, the time off the plane, how near the mark). At the end: the lines said, the pace,
what was dropped, said / heard per moment, the day as measured (the wind's mean, the sea's wave height), and every
rounding watched with its numbers and its verdict (to check the gybe numbers). The race tool has no camera, so a stand-in picks the board and the shot
with the TV director's own rules and numbers (`CommentaryRun.Camera`). With `--commentary=1` the race is told the wind,
so it ranks the boards by the smart order as the game does; the finishers' places are the same as without it.

An excerpt of a real run of the command above (the T2 slalom at 18 kt, six personas, seed 1; 27 November 2026; the
starter bank of 76 lines). From the gun to the first rundown, then the last mark and the finish:

```
  0:00.0  start_gun     S0004    Here we go. Look at that.                                      [COMMITTEE on Tobias; start_gun]
  0:07.0  identify      S0012    Then there's a Point.9 coming through.                         [GROUP on Hana; identify Hana]
  0:08.1  near_miss     S0062    Oh no. Noor has just nearly took out Mara.                     [GROUP on Hana; near_miss Noor / Mara; 2.2 m apart, 3.2 m/s between them]
  0:13.8  airtime       S0052    Gets airborne on this first reach and he's holding on, Mara.   [GROUP on Hana; airtime Mara; 0.3 s in the air]
  0:18.6  chase         S0047    But there you can see Kofi closing in a little bit further back. [TRACK on Kofi; chase Kofi / Tobias; 17 m behind, 8 m nearer than 8 s ago]
  0:24.9  fight         S0050    This is going to be an out and out speed battle for Tobias and Kofi. [TRACK on Kofi; fight Tobias / Kofi; 12 m apart for 6 s]
  0:29.9  mark_approach S0053    But it will be Hana who's going to go around this mark in first place. [MARK on Hana; mark_approach Hana]
  0:34.7  rundown       S0039    Hana in first place.                                           [MARK on Hana; rundown Hana]
  0:37.2  rundown       S0041    Liv's in there.                                                [MARK on Hana; rundown Liv]
  0:38.8  rundown       S0037    Then it looks like Tobias.                                     [ORBIT on Liv; rundown Tobias]
  0:40.6  rundown       S0038    Then we've got Kofi.                                           [ORBIT on Liv; rundown Kofi]
  0:42.2  rundown       S0036    So Mara in fifth.                                              [ORBIT on Liv; rundown Mara]
  0:44.1  rundown       S0040    Then Noor in sixth place.                                      [ORBIT on Liv; rundown Noor]
  2:14.7  speed         S0022    He's got just such good control over the chop.                 [MARK on Tobias; speed Tobias]
  2:20.2  mark_approach S0053    But it will be Hana who's going to go around this mark in first place. [CHASE on Liv; mark_approach Hana]
  2:32.2  leader        S0029    But Hana is still leading this.                                [MARK on Hana; leader Hana]
  2:35.6  gybe_bad      S0059    A little bit of a wayward gybe.                                [MARK on Liv; gybe_bad Hana; kept 14 % of its speed (23.5 to 3.4 kt), 3.1 s off the plane, 5 m from the mark]
  2:38.0  chase         S0045    Liv though putting the hammer down.                            [MARK on Liv; chase Liv / Hana; 50 m behind, 39 m nearer than 8 s ago]
  2:41.5  identify      S0012    Then there's a s3kauai coming through.                         [MARK on Kofi; identify Kofi]
  2:44.1  gybe_safe     S0058    And he does.                                                   [MARK on Kofi; gybe_safe Liv; kept 18 % of its speed (22.8 to 4.1 kt), 2.7 s off the plane, 6 m from the mark]
  2:47.4  tactics       S0075    Pushing hard above Tobias though.                              [MARK on Kofi; tactics Kofi / Tobias; 5 m to windward of Tobias]
  2:51.2  camera        S0017    We're going to have to get a closer view.                      [FINISH_LINE on Hana; camera]
  2:54.8  leader        S0033    On a heater right now.                                         [FINISH_LINE on Hana; leader Hana]
  2:59.7  finish_win    S0066    Hana gets the bullet.                                          [FINISH_LINE on Hana; finish_win Hana]
  3:05.3  finish_place  S0068    And Liv will get the second place.                             [FINISH_LINE on Hana; finish_place Liv]
```

Its summary:

```
# Lines said: 68 (28 of them small talk) from -0:60.0 to 3:45.4: 14.3 a minute; he talked 50 % of that time.
# Moments heard: 53; dropped as too late: 7; no line fitted: 20; lines cut short by a bigger moment: 1.
# Said / heard by moment (small talk is not heard, only said): pre_start 3/3, start_gun 1/1, start_good 0/1, start_bad 0/1, identify 5/0, speed 4/0, leader 5/0, rundown 17/0, overtake 0/6, chase 7/7, fight 2/3, airtime 1/2, tactics 3/0, form 1/0, mark_approach 3/10, gybe_safe 1/3, gybe_bad 1/3, near_miss 1/1, trouble 0/3, last_leg 0/1, finish_win 1/1, finish_place 3/5, after_race 2/2, camera 6/0, unsure 1/0
# The day as the story measured it at the end: the wind's mean 18.0 kt (wind_strong from 22, wind_light to 13), the sea's significant wave height 0.23 m (choppy from 0.30, flat to 0.12).
```

What it shows: the pace is 14 lines a minute, talking half the time. The stream's commentator says about 33 short
sentences a minute; here the starter bank is the limit (76 lines, each not again for 4 minutes, a slotted one for
40 s): with the full bank he can talk more, and `pause_*` and `quiet_pause_*` can then bring him nearer the stream. The
lines that were heard but not said are the moments the starter bank has no line for (overtake, trouble, last leg).
One choice is wrong in this run: at 1:44 "Pushing hard above Liv though." (S0075) was said while Hana was 11 m to
*leeward* of Liv: that line carries no `windward` need in the bank (see "For the lead" below).

## What is tested

`Game/tests/unit/test_commentary.gd`, 51 tests:
- the bank: the real starter bank loads with no problem (76 lines, the 35 moments, the moments list's counts match), every line's slots
  match its words; a made-up bank with an unknown moment, an unknown slot, an unknown needs word, slots that do not match
  the words, a doubled id, a wrong level and a stray brace: each line left out with its reason; a broken file, a wrong
  format and a missing file;
- the words: places, marks ("last"), legs ("penultimate"), the fleet's sail colours named or not;
- the director: every `needs` word (also the day's and the tactics'); the slots filled, and a line skipped for a missing brand, an unsure colour, no
  second board, no mark, a board with no name to say, the nation slots; no line twice and not the same words; the least
  used first (nine lines from three: three each); a staple more often (said 9 times
  in the streams: about three times as often); a line with a slot back for another board after 40 s; the level; one voice with a breath between; a big moment cutting in
  over small talk while a small one waits; a late moment dropped; the bigger moment and the board on the screen first;
  the rundown down the order, stopped by a fall; a place said alone followed by the name; the reaction pair;
- the story on made-up races: the first look only takes note; the fleet lining up and the gun; over early; a good and a
  bad start; a lead change once held, told once; a brief swap is no overtake; an overtake naming the board passed; no
  order news in the start's shuffle; a chase; a fight; a fall, bigger for the leader, told once; trouble off the plane
  (and none in a lull); trouble from places lost; a near miss crossing but not side by side; airtime after a clean
  landing, a fall instead after a crash; the front at a mark; the gybe judged good, safe, bad (wide, all but stopped), and
  no gybe line when the stern never went through the wind or after a fall; a whole rounding through a mark ending in "gybe_good"; the last leg, a photo finish, the
  winner, the places and the verdict; the small talk offered about the board on the screen; tactics to windward of
  the board beside it, in dirty wind (and not at 2 %), below its straight line; tension for the lead (not at 6 s, not
  early) and for third; form from a long lead and from a run of places; the day's wind and water measured into the
  `wind_strong`, `wind_light`, `choppy`, `flat` needs;
- the race as the commentator sees it, from a real `RaceSim` (present boards, places, names, brands, the water's share);
- the config knows every moment; the shots wide or close; watch mode's V key; the transcript's clock.

Checked with screenshots (`.screenshots/commentary/`): the full screen and the TV screen at 1280 x 720 and at
3137 x 1263, on the open water and on the lake; a long line wraps onto two lines between the speed card and the small
map, above the keys; when the push gauge shows in the middle at the bottom (the full screen, once the board followed
has a push), the subtitle sits just above it; nothing covers the race card, the standings, the countdown or the
warnings.

## What is not detected yet, and why

- **A spin-out, a catapult, a missed gybe as such.** The fall is told as a fall whatever its kind; trouble covers a board
  off the plane or losing places. The telemetry has the fall's kind and the fin's stall, but RaceLook does not read them
  yet: the bank has no lines that need the difference.
- **A general recall or a black flag.** The game's race has no recall; over early is one moment.
- **Who goes through to the next round, the heat's results as a list.** The game races one race, no eliminations.
- **"Brave" gybes, inside or outside at the mark, who gains at the mark.** The judging uses the speed kept, the time off
  the plane and the distance to the mark only.
- **A near miss as a near miss.** The boards pass through each other in the game, so a near miss may be a touch.
- **Two voices.** The bank is the main commentator only (BANK_FORMAT.md).
- **The gusts and "which leg is the long one" (conditions).** The day's needs read the wind's mean and the sea's
  height; there is no need word yet for a gusty day or for the course's shape, so such lines are said without that
  check (or the bank leaves them out).
- **Tactics "inside" at a mark.** Who has the inside at a mark needs the rules' overlap; the rules judge (RaceRules)
  knows it but the story does not read it yet.
- **The `filler`, `overtake`, `over_early`, `trouble`, `last_leg`, `wow` and `oh_no` lines.** Detected and heard, but
  the starter bank has no lines for them yet, so they are not said until the full bank comes (the transcript's
  "said / heard" shows them as 0 of n).
- **The player's own race.** Built for (the `Commentary` node takes any `RaceRunner`, no TV camera needed, and names
  the player's board by `player_name`), not switched on yet.

## A play-test for Max

1. Race page, "Watch: the AI races, you direct". Press T: the TV director and the commentary come on together.
2. Do the lines fit what you see? Names, brands and colours right? Anything said about a board that is not in the
   picture when it should be?
3. The pace: too much talk, too little, the pauses right? (The stream: bursts with 1 to 3 s pauses.)
4. Do the big moments come in time: the gun, a lead change, a fall, the finish? Anything said late?
5. Press V: the subtitles go and come back. H: full, TV and clean screen (no subtitles on the clean one).
6. In your 3137 x 1263 window: can you read the subtitles easily, over the water and with the mountains behind?
7. Watch at 2x and 4x (+): he says less; is that right, or should he stop talking at high speed?

## For the lead: the bank's lines and the new needs words

- `S0074` "He's got a lower line." carries no `needs`, so it can be said about a board that is higher. It should get
  `leeward`; `S0075` "Pushing hard above {rider2} though." should get `windward` (it has `close` and `pair`).
- `S0067` "But who will get second?" (photo_finish) names a place in its words. Said at a photo finish for another
  place it is wrong. The builders could turn such a place into `{place}` ("But who will get {place}?").
- `S0042` "He's right up there in the top five." (rundown) names no board and no place, so a rundown never takes it;
  it may fit `speed` or `identify` with a need for the first five.
- The needs words `windward`, `leeward` and `dirty_air` are new (BANK_FORMAT.md, at the end of the needs table, beside
  the lead's four day words, which this branch also wrote there: the two copies of that table may need a hand at the
  merge).

## Questions for Max

1. The key: V for the commentary (C is taken by the camera's look key). All right?
2. Should the commentary come on by itself with the TV director, or only with V?
3. At fast forward (2x and more): keep talking (less of the race), or quiet?
4. The gybe numbers: good = at least half the speed kept, planing, within 8 m of the mark; bad = all but stopped or
   wide. The AI's gybes today slow from 23 to 3 or 4 kt, so they come out safe or bad, never good. Keep it like that
   (honest), or judge the AI's gybes against each other (the best of the race good)?
5. The new needs words `windward`, `leeward`, `dirty_air` for the tactics lines: all right?

## Files

- `Game/race/commentary/commentary_bank.gd` (`CommentaryBank`): reads and checks the bank.
- `Game/race/commentary/commentary_words.gd` (`CommentaryWords`): places, marks, legs and colours as words.
- `Game/race/commentary/race_look.gd` (`RaceLook`): the race as the commentator sees it.
- `Game/race/commentary/race_moment.gd` (`RaceMoment`): a moment.
- `Game/race/commentary/race_story.gd` (`RaceStory`): the moments from the race.
- `Game/race/commentary/commentary_director.gd` (`CommentaryDirector`): which line, when.
- `Game/race/commentary/commentary_config.gd` (`CommentaryConfig`) and `Game/config/commentary_default.tres`: the numbers.
- `Game/race/commentary/commentary.gd` (`Commentary`): the node in the sailing scene.
- `Game/race/commentary/commentary_subtitles.gd` (`CommentarySubtitles`): the subtitles.
- `Game/dev/commentary_run.gd` (`CommentaryRun`) and `Game/dev/run_race.gd` (`--commentary=1`): the transcript.
- `Game/race/watch_mode.gd`: the V key, `--commentary`, the screen levels; `Game/ui/hud.gd`: `gauges_shown()`;
  `Game/ui/race_page.gd`: the Watch button's tooltip.
- The release build: the bank is a `.json` file, and the export preset's include filter (`Game/export_presets.cfg`,
  `include_filter="*.bin, *.json"`) already takes every `.json` in the project (the courses are read the same way in the
  release folder), so no change was needed.
