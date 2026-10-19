# race_core (Part 9A): the race, its geometry, the headless race

**Built.** `Game/race/`: `RoundingCheck` (all the geometry), `RaceStep` (one step of the course), `RaceSim` (countdown, gun, OCS, each board's next step, splits, places, the end), `RaceResult`. All plain classes, no nodes. Tests: `test_rounding_check.gd` (16) and `test_race_sim.gd` (15). `tools/race.sh` runs `Game/dev/run_race.gd`.

**Verified.** `tools/test.sh`: 391 of 391 pass. `tools/check.sh`: 203 files, 0 failed. `tools/race.sh --course=test --seconds=60` prints:
`1. board1  DNF  -  1/4 steps  splits 0:00.8  falls 0`.
The boards reach the line just after the gun at 12, 15 and 24 kt, with countdowns of 10, 30 and 60 s. A PD3 course saved with `Course.save()` loads and races.

**The course code and the geometry agree.** I checked every single mark of all ten templates at two wind directions, for turns of 5 to 170 degrees. `Course.natural_side()`, the template's own side, `turn_at()` and the direction RoundingCheck counts all match. A track that keeps the mark on its side counts once and gives no warning.

**Read before merging:** the table lists where I went beyond the brief.

**Not verified.** Nothing is connected to a scene or the HUD yet. No lake course has been saved yet. I did not measure the frame time with four boards, or how the warning feels in play. Godot rewrites `Game/default_bus_layout.tres` on import; I did not commit that change.

| Point | The brief | What I built, and why |
|---|---|---|
| Wrong side | Crossing the opposite ray (out − in) | Two cases. (1) The opposite ray, but only while the board sails on along the leg out. (2) The rounding ray crossed the wrong way round. At a windward mark the opposite ray runs straight downwind, along the beat. Taken literally, the rule warned boards tacking up under the mark, and never warned a board that rounded it the wrong way. Both cases are tested. |
| Which way round | From the in side to the out side | The mark's side decides: port is anticlockwise. This is the same as the brief for every natural side. At a 180° turn there is no in side or out side. If a mark's side goes against the bend (the course maker allows this), the board must go right round the mark, as the brief's ray implies. |
| Straight past | in = out | Any bend under 5°, the same limit `natural_side()` uses. |
| Two boards finishing in one tick | The board further over the line wins, or the lower index | The crossing time is worked out within the tick, which picks the board further over the line when speeds are equal. An exact tie goes to the lower index. |
| OCS | Over the line | On the course side of the line or its extensions. Cleared by going back behind it. |
| API | As suggested | Added: `RaceStep`, `next_step()`, `clock_s()` (negative during the countdown), `is_started()`, `board_count()`, `board_name()`; `RaceResult.index`, `steps_done`, `steps_total`. A board completes at most one step per tick; a tick's move is under a metre. |
| race.sh | | Added `--twa=50`. The CSV has an extra `next_step` column. The boards wait, not simulated, until 10 s before the gun. |
