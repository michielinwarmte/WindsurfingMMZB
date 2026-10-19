# 9A agent `fit_to_water`: CourseFitter, Fit to water, t2_slalom.json

**The clearance.** A grid of points 10 m apart. A flood fill from a lake spot finds the water (below the surface and joined to the lake, as in LakeArea). A two-sweep distance transform gives each point's distance to land, less one step, so it never claims too much. Checked every metre round 53 spots, it is 3 to 11 m under the truth, never over. It builds in 0.2 s, so there is no data file.

**The fit** follows the brief, plus one rule: a coarse spot gets the fine look when every mark clears the margin less 71 m (half a coarse cell's diagonal). A course that only fits between coarse spots is then not missed. A 10 m brute force agrees: no PD3 fits at 70 %. Marks are checked before legs, the outermost first. PD3 takes 26 ms, LG2 2 ms.

**The button** sits in the Size row. It uses the lake's wind now, makes one Undo step, and shows the reason when nothing fits. The screenshot (a full PD3 at the start, then fitted) used a temporary `--course-fit` line in `wind_viewer.gd`, not my file and not committed.

**The rule against this lake.** At 200 m, T2 shrinks to 60 %: 1.34 km, 240 m slalom legs, 10° off the wind. The plan's "80 % is fine" needs 150 m (80 %, 15° off); 100 m gives 90 %. This is Max's choice. A full LG2 fits, square to the wind.

**Quirk:** re-saved from the course maker as "T2 sprint slalom", it goes to `t2_sprint_slalom.json`.

**Checks:** tests 368 of 368 (mine 8); check 199 files, 0 failed; `course.gd` untouched.
**Not verified:** the button with a real mouse.

Wind at 14:30: 16.9 kt from 222.1°, axis 222°; 4 boards.

| Course | Size | Axis | Nearest land: marks / legs | Legs | Fit |
|---|---|---|---|---|---|
| T2 sprint slalom (PD3), saved | 60 % | 232°, 10° right of the wind | 201 m / 201 m | Start→1 360 m 324°, 1→2 500 m 052°, 2→3 240 m 335°, 3→Finish 240 m 130° | 26 ms, 29,704 tries |
| LG2, the check | 100 % | 222°, square | 207 m / 217 m | Start→1 1852 m 222°, three legs of 1702 m (042°, 222°, 043°), 4S→Finish 450 m 127° | 2 ms, 907 tries |
