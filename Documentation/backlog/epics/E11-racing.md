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
Notes: 8 Nov 2026 day (`ai/skipper-heads-8nov`): the skipper keeps clear by the rules at any distance (`RaceRules.must_keep_clear_why()`, passing 6 s ahead, Shift from 5 m/s), turns its penalty circle clear of the crowd and does not tack onto port into a starboard board: penalties 46 -> 25 in 22 start rounds, 61 -> 29 in 9 fleet races, no falls.

### E11.S03 · Slalom elimination ladders
Status: doing | Size: L | Owner: the lead, Max for the format | Milestone: M2 | Needs: E09.S03, E10.S06 | Roadmap: —
Done when: an event runs eliminations as the PWA does: heats of 8 to 10 from a seeded ladder, the first places advance (the winners' round and, if chosen, the losers' round), a final, the elimination's points, up to three eliminations per event and the event's result from them with the class's scoring; the player sails only their own heats and can watch the others (or skip them, simulated headless).
- [x] T1 The ladder's structure (the heat size, how many advance, the rounds): `EliminationLadder`, 64 in 16 heats of 8, the first four through (E11.S13, 27 Nov 2026; a resource for other sizes is still to make)
- [ ] T2 The heats run one after another with the race director's gaps; the AI heats simulated headless when skipped
- [x] T3 The scoring per elimination and the event's result with the dropped results: `EventWeek` (27 Nov 2026, checked against the 2026 streams' commentary); the tour's result is still to make
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

### E11.S09 · Watching and filming the AI races as their race director
Status: review | Size: M | Owner: Max (the look and the feel), the lead | Milestone: M2 | Needs: — | Roadmap: —
Done when: on one PC the player can watch the AI race as their race director, with the keys to film a race for the team (a TV camera that picks the boards and shots by itself, slow motion and fast forward, a frozen frame, a screen without cards) and to test the AI (what the watched AI is thinking, the same race again), and Max has checked it on his screen.
- [x] T1 The watch mode (`Game/race/watch_mode.gd`): T the TV camera, 5 the helicopter, - + 0 the speeds (1/4 to 8x, every tick still 1/60 s), P freeze, H full / TV / clean, N names, I the AI's head, Shift+R the same dice; `--tv`, `--screen`, `--speed`, `--head` (f2b949c)
- [x] T2 The race director while watching; the Race page's "Watch: the AI races, you direct" button; the play folder's watch and film launchers (`WindsurfingMMZB-play-10nov2026-watch`)
- [x] T3 The waves on the screen stood still while spectating (the parked board's clock): fixed, also for LAN spectators
- [ ] T4 Max's look on his screen: the TV camera's shots and pace, the cards at 3137 x 1263, the slow motion, how fast 4x and 8x really go with 11 boards
- [ ] T5 The in-game Controls page lists the watch keys
- [ ] T6 A film straight to a file with Godot's Movie Maker (`--write-movie`): does it work in the release build, how big are the files
- [x] T7 Cameras at the marks and on the start boat for the TV camera: a drone beyond the mark for the leaders and the committee boat's view down the line (E11.S11, 12 Nov 2026)
- [ ] T8 Shift+R with the gusts too (the wind's clock set back with the dice): an exact replay of a start
- [ ] T9 The AI's head for a learned brain (`LearnedSkipper` writes no note); the watch keys for a LAN spectator (without the speeds)
Notes: 10 Nov 2026 evening (Max: "a version only for AI watching and spectating, where I'm the race director. I want to video a few races so I can broadcast them to Michiel"), branch `watch/broadcast-10nov` (pushed, from `ai/skipper-heads-8nov` 372fb72). Report `Documentation/reports/racing/watch_mode_10nov.md`. Unit tests green after two fixes (1039 of 1041 first: the Race page's height, the spectate test's clock check); no screenshots judged (Max asked to skip them). Filming: Win+Alt+R (Game Bar) or OBS.

### E11.S10 · The start on the course: a slalom start or a course start
Status: review | Size: S | Owner: Max (the look), the lead | Milestone: M2 | Needs: — | Roadmap: RA30
Done when: every course says how its boards start, the course maker chooses it, and the AI starts the way it says.
- [x] T1 `Course.start_type` (slalom start, course start; older files and the templates: the race type's own start), saved as `"start_type"` in the course files and sent with the director's course; `--start_type=` for `run_race.gd` (af969cc)
- [x] T2 The course maker's "Start" choice under "Race type" (the wind viewer's and the race director's course maker); a warning for a slalom start on a line across the wind
- [x] T3 The ten lake course files tagged (PD3 and SD3 slalom; the rest course)
- [x] T4 The AI follows it: a slalom start the timed run without lag, a course start the hold with lag (E09.S25)
- [ ] T5 Max's look in the play folder `WindsurfingMMZB-play-12nov2026-starts6b` (M in a race, change "Start", then R)
- [ ] T6 The open water's courses (T1, T2) tagged in their files; `--start_type=` for the game like `--race_type=`
Notes: Max, 12 Nov 2026: "do the courses have a clear tag on when its a slalom start and wen its a course race start? in the course maker make this an option so the skippers know witch to choose". Before, the start followed from the race type and the line's direction (RA27). A slalom start needs the line along the wind (the committee boat upwind); on a line across the wind the boards wait behind it. 3 new tests (`test_race_types.gd`). In the play build the course maker cannot save to a file; the race director puts the choice into the race at once.

### E11.S11 · The TV camera like a race on TV
Status: review | Size: M | Owner: Max (the look and the feel), the lead | Milestone: M2 | Needs: E11.S09 | Roadmap: RA33, GR14
Done when: the watch mode's TV director (T) films an AI race like a race on TV (drone and helicopter shots only, the committee boat's view down the start line at the start to see who is over early, the front and the exciting moments most, the leaders' mark roundings always), the shots can be taken by hand on the board you watch, the open water shows no square round the camera, and Max has checked it on his screen.
- [x] T1 `Game/race/tv_camera.gd` (TvCamera) flies the camera through the rig's new TV mode (`CameraRig.Mode.DIRECTED`): chase, side, helicopter, overhead, group and mark drones that glide with the boats; the start's wide shot from 40 s before the gun, the committee boat down the line with the line drawn on the water from 12 s before to 7 s after, the leaders leaving the line; the finish boat's view as the leader comes in; hard cuts every 7 to 12 s, longer TV lenses, no grid on the water while it films
- [x] T2 The story it follows: the front first (the leader most, then 2nd to 4th), fights, boards near a mark, boards that just gained a place; late starters and the back of the fleet seldom; a drone waits beyond the mark for each of the first three
- [x] T3 By hand on the board you watch, until T or 1 to 4: 5 the helicopter (5 again stops or starts the circling), 6 the committee boat, 7 the chase drone, 8 the side drone, 9 the overhead drone; Tab and L take the shot to another board; the wheel brings the drone nearer or farther
- [x] T4 The open water's square: the far water now shades the same waves and whitecaps per pixel (`water.gdshader`, `sea_pixel_surface()`), the near mesh blends into it at its edge, and fully from about 30 m up (the drones, the top-down camera); the sailing camera's look unchanged (before and after screenshots)
- [x] T5 Tests (`test_watch_mode.gd`, 17 TV camera tests); the play folder `WindsurfingMMZB-play-12nov2026-tv` (+zip) with three Film launchers (the lake's O2 and SD3, the open water's T1)
- [ ] T6 Max's look on his screen: the shots and their pace, whether the director follows the right boats, the committee boat at the gun, the square gone; and whether 5 to 9 by hand is what he meant by "override for the drone like camera cams"
- [ ] T7 Not checked by the lead: the keys 5 to 9 (screenshots cannot press keys), the finish line's shot (no race sailed to its finish), the drones in motion, slow motion and fast forward with the drones
- [ ] T8 The in-game Controls page lists 5 to 9 (with E11.S09 T5)
Notes: 12 Nov 2026 evening, Max: "make the tv cam in tv mode more tv like ... use only the drone/helicopter, committee boat down the start line at the start for looking for over-earlies, but can override for the drone like camera cams. follow the front or exciting things ... also there is a square around the camera which is ugly, increase view distance", then "its only on open water". Branch `watch/tv-camera-12nov` (from `ai/starts-fleet-10nov` 5bdaf50), not committed yet (Max's word). Report `Documentation/reports/racing/tv_camera_12nov.md`. With E11.S12: unit 1103/1103, check 516/0.

### E11.S12 · The smart leaderboard: the polar and the laylines
Status: review | Size: S | Owner: Max (the order on the water), the lead | Milestone: M2 | Needs: — | Roadmap: RA32
Done when: from the gun the standings rank the boards by the time each still needs to the finish, worked out with the polar and the laylines, the gaps change live along every leg, and Max finds that the order matches who is ahead on the water.
- [x] T1 `RaceSim.time_to_finish_s()`: the way to the next step plus every leg after it (`legs_after_s()`, laps included), each leg by `RaceTimeLimit.leg_time_s()` in the wind of the moment: on a beat or a run the way toward (or away from) the wind at the polar's best angle, so inside the laylines the sideways place costs nothing; on a reach or past a layline the distance at the polar's speed for that angle; a standing penalty (+20 s) added; the wind handed over every tick by `RaceRunner._tell_the_race_the_wind()`
- [x] T2 The gaps in the standings: the differences of the expected finishes (`RaceSim.expected_finish_s()`, `RaceHud.gap_between()`), live along the leg instead of only at the marks
- [x] T3 The old order kept before the gun, on a LAN guest (the host's order), and in the race tool and the trainer (they hand no wind over, so the training's numbers are unchanged); the AI never reads the order
- [x] T4 Tests (`test_race_smart_order.gd`, 9); in the play folder `WindsurfingMMZB-play-12nov2026-tv`
- [ ] T5 Max's look on a beat (O2 or LG2): does the order match who is ahead on the water
- [ ] T6 A long race with wind shifts; a LAN race (the guest still shows the old gaps)
- [ ] T7 Later, if wanted: the time lost in tacks, gybes and roundings; each board's own gust or lull
Notes: 12 Nov 2026 late evening, Max: "the leaderboard is not correctly calculated. please keep the wind polar in consideration. make a smart leaderboard with laylines kept in mind". Before, the boards still racing ranked by their straight line to the next mark, and the gaps were those at the last mark both had rounded (on the first beat the start's). Same branch as E11.S11, not committed yet. Report `Documentation/reports/racing/smart_order_12nov.md`. Related: E11.S07 (results and splits).

### E11.S13 · The slalom week as a live broadcast
Status: review | Size: L | Owner: Max (the look, the format, the names), the lead | Milestone: M2 | Needs: E11.S03, E11.S11, E16.S06, E09 (the AI at Sotavento) | Roadmap: —
Done when: the game's slalom world cup at Sotavento runs by itself as a broadcast: 64 sailors in a ladder, every heat sailed live by eight AI sailors, filmed by the TV director with the pictures of the real streams, talked through by the commentator (subtitles and a voice), with the results, the ladder and the standings on the screen; the week is saved and goes on; Max finds it looks and sounds like a stream.
- [x] T1 The study of the real streams (27 Nov 2026): 27 h of commentary and 11 heat replays of the World Cup Fuerteventura 2026 written out, the shots noted by two readers, the stream's profile (`Documentation/reports/broadcast/`)
- [x] T2 The commentary: 42 moments, a bank of the commentator's lines with slots (772 lines from the 27 h and the replays, judged by hand; for the event's own moments 39 of his sentences and 47 written for the game), a director that picks the line (`Game/race/commentary/`)
- [x] T3 The TV director set to the stream's measured numbers, with a beach camera and the drone's heights (`Game/race/tv_stream_director.gd`, `Game/config/tv_director.tres`)
- [x] T4 The commentary heard: a computer voice beside the game (`CommentaryVoice`, `SpeechEngine`; NOT the commentator's own voice; its licence allows play tests only)
- [x] T5 The week's book-keeping: the roster of 64 (provisional names), the ladder of 16 heats, the points, the dropped results, the standings, the schedule of the real week, the save (`Game/race/event/`, 13 tests)
- [x] T6 Heats in a row on the water: `EventBroadcast` (`--event=sotavento_2026`), the heat's card, the results card with the heat's name, the standings by themselves at the next elimination, the results as a text file; the play folder `WindsurfingMMZB-play-28nov2026-live`
- [x] T7 Sotavento's course set right: the first reach to the beach, the stream's leg lengths, the wind axis 025 (the file said 205), the start boat on the upwind end
- [ ] T8 Max's look and listen on his screen: the pictures against the streams, the voice (how it sounds, how loud, the names), the cards
- [ ] T9 The AI at Sotavento: mark 1 with the fleet arriving together (about one board in eight does not get round it: it turns in early, is pushed inside the mark or falls at it, and a slalom board cannot beat back up; such a board gives up after 45 s, the lead's rule, Q66) and the gybes (about 5 s lost at every mark against the stream's leader); set for now: every event sailor at least 14 m off a mark (no more missed marks beyond mark 1); training there on Max's go (Q63); the measurements in `Documentation/reports/broadcast/PROGRESS.md` and `tools/broadcast/heat_stats.py`
- [ ] T10 The next heat waiting on the water (16 boards), the player's own heats, each day's own wind (30, 30, 35, 40, 28 kt in the schedule; the AI has never been tried above 30)
- [ ] T11 The rest of the 27 h: about 2,500 once-said candidate lines not read yet (his staples of every moment and the thin moments' lines are in, 28 Nov 2026); ten of his event sentences left out because the voice check was not sure it is him
- [ ] T12 Max's 64 names; the start boat's end confirmed; an early starter out of his heat as in the real event, or back to start again as now (Max's choice)
Notes: 27 Nov 2026, Max: "we do the commentary and drone plan", then "i want to simulate the whole slalom week with eliminations with 64 people in brackets all live broadcasted", then the night order: "tomorrow morning i want a fully working livestream with audable commentary and the full races with results working". Built on `broadcast/on-sotavento` (the run's `broadcast/study-27nov` with Max's `spot/sotavento`), not pushed, not merged. Five Opus workers (the commentary director, two shot readers, the TV director, the voice); the lead built the event week, judged the lines and read the format from the streams (`EVENT_WEEK_PLAN.md`: the top four go through, 0.7 for a win, results dropped after 4, 7 and 12 eliminations, the days 2-2-3-2-2). Measured at Sotavento in 30 kt with a 60 s countdown: the eight cross the line 0 to 18 s after the gun, the winner needs 195 to 215 s (the stream's leader: about 187 s). The log of the night: `Documentation/reports/broadcast/PROGRESS.md`.
