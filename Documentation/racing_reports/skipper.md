# skipper (Part 9B): the scripted skipper

**Built.** `SkipperConfig`; four characters in `Game/race/skippers/` (placeholder names); `Skipper` on the controller's `AiHands`, rules 1 to 6 and 8. Rule 7 (gusts) is an empty hook, `_gust_lean_deg()`: headless races have no gusts. `Skippers.make()` with a marked `brain:` spot; `RaceSim.board_position()`; `race.sh --skippers --seed`; `tools/race_matrix.sh`; 11 tests.

**Verified.** 427 of 427 unit tests pass. Alone on T1 the all-rounder finishes in 10:46, 7:07 and 6:42 (12, 18, 24 kt) without falling, starting 0.6 to 0.7 s after the gun at 18 and 24 kt.

**Where the plan's rules fell short**
- **Lap time.** T1 is two beats and two runs, and the board makes 2.9 to 4.1 m/s to windward. A lap takes 7 to 11 minutes, not 3; the test limits are 12, 8 and 8.5 minutes.
- **The polar.** POLAR_15KT's 45/135 do not fit the sea: at 12 kt the board stops planing beyond 125 degrees. The skipper runs at its measured polar's best angle, heads up when off the plane and foots when slow.
- **Marks.** A beat or run must end on the tack the mark is rounded from (added).
- **The start.** Easing the sheet stops the board and heading up at speed is slow, so spare time is used far from the line.
- **Stop rule 2, in part.** In the four-board matrix at 24 kt, broad reaches at 13.6 to 14.1 m/s ended in catapults (the all-rounder once here, the gambler in an earlier run). Gentler steering at speed did not cure it. Michiel's call.

**Threads.** Shared config resources made threaded boards 6 times slower; each now has copies.

**Test time.** `test_skipper.gd` takes 11 to 13 minutes; the 12 kt race sets it. I suggest the validation suite.

**Not verified.** Wind shifts (off by default); the scenes.

| Course, wind | All-rounder | Cautious | Gambler | Rookie |
|---|---|---|---|---|
| T1, 12 kt | 11:06.5, 0 falls, 5 tacks, 3 gybes | 12:09.1, 0, 5, 3 | 11:00.1, 0, 5, 3 | 12:01.6, 0, 5, 3 |
| T1, 18 kt | 7:07.4, 0, 3, 3 | 7:34.1, 0, 3, 3 | 7:33.6, 0, 4, 4 | 7:45.5, 0, 3, 3 |
| T1, 24 kt | 8:07.2, 1, 5, 5 | 7:03.0, 0, 3, 3 | 8:25.3, 0, 7, 5 | 7:23.5, 0, 5, 3 |
| T2, 12 kt | 4:36.9, 0, 0, 5 | 5:02.9, 0, 1, 5 | 4:32.5, 0, 0, 5 | 5:27.6, 0, 1, 5 |
| T2, 18 kt | 3:05.9, 0, 0, 5 | 3:21.7, 0, 0, 5 | 3:01.7, 0, 0, 5 | 3:19.1, 0, 0, 5 |
| T2, 24 kt | 2:48.2, 0, 0, 5 | 3:02.9, 0, 0, 5 | 2:45.7, 0, 0, 5 | 3:08.3, 0, 0, 5 |
