# gens: watching a night's generations race (F5, agent `gens`, 21 October 2026)

**What there is now (the game side; `tools/gens.sh` and the headless table are the lead's).** The
race path takes four new options: `--behind=<m>` (the boards wait that far behind the line),
`--wind=<kt>` (a steady wind from the settings' direction, no gusts or shifts, as in training),
`--blind=1` (the brains ignore the other boards) and `--spectate=1`. While spectating, your board is
parked: hidden, not stepped, not in the race. The camera follows the leader and moves to a new
leader only after it has led for 3 s. Tab and Shift+Tab step through the race order, L goes back to
the leader, and 1 to 4, R and Esc work as before. The HUD's top block shows the board being watched
("Watching gen 90"), and the fleet list marks it "<< camera". Brains are labelled "gen N" or
"best". With two or more of them, the sails go from red (the oldest) through yellow to green (the
newest), and the best is white.

**Checked.** `tools/test.sh` (8 new tests in `test_gens.gd`) and `tools/check.sh` pass. I looked
at screenshots from the editor engine: `.screenshots/p9/gens_t1_prestart.png` (4 s into the
countdown: 16 boards on the line, labels, the ramp of colours) and `.screenshots/p9/gens_t1.png`
(60 s after the gun, below). On the release build, 16 boards ran at 53 fps (`--measure=10`, other
jobs running). The parked board cost 0 ms.

**Not checked.** Tab, Shift+Tab and L were not pressed in a real window (only the logic is
tested). How it feels to watch.

**60 s after the gun** (night2b, all 16 brains, 150 m behind, 30 s countdown, 15 kt, blind):

| Place | Board | Going to | Gap |
|---|---|---|---|
| 1 | gen 90 | mark 1 | (camera) |
| 2 | gen 70 | mark 1 | +0.4 s |
| 3 to 16 | gen 100, 120, 110, 30, 130, 80, 40, best, 20, 1, 50, 10, 140, 60 | still to start | |

A minute after the gun only two generations had started. In the morning's evaluation the best
brain's starts came 33 to 53 s after the gun, so this is in line with the training. The lead's
headless table will show the whole race.
