# 9A agent `fit_to_water`: CourseFitter, Fit to water, t2_slalom.json

**Branch:** `p9/fit_to_water`, from `feature/p9-racing` (f8db4a7).

**The clearance.** A grid of points 10 m apart over the lake. A flood fill from a lake spot finds the water (below the surface and joined to the lake, as in LakeArea). A two-sweep distance transform then gives each point's distance to land, less one grid step, so it never claims more water than there is. Checked every metre round 53 spots, it is 3 to 11 m below the truth, never above. It builds in 0.2 s, so I wrote no data file.

**The fit** follows the brief. I added one rule: a coarse spot gets the fine look when every mark there clears the margin less 71 m, half a coarse cell's diagonal. A course that only fits between coarse spots is then not missed. A brute force on a 10 m grid agrees: no PD3 fits at 70 %. Speed: PD3 26 ms, LG2 2 ms. Marks are checked before legs, the outermost first.

**The button** sits in the Size row. It uses the lake's wind now, makes one Undo step, and shows the reason when nothing fits. Screenshot: a full PD3 at the start (four marks on land), then fitted. I took it with a temporary `--course-fit` line in `wind_viewer.gd`, which is not my file, and did not commit that line.

**The rule against this lake.** With 200 m, T2 shrinks to 60 %: 1.34 km, 240 m slalom legs, 10° off the wind. The plan's "80 % is fine" needs 150 m (80 %, 15° off); 100 m gives 90 %. This is Max's choice. A full LG2 fits, square to the wind.

**Quirk:** if T2 is re-saved from the course maker as "T2 sprint slalom", it goes to `t2_sprint_slalom.json`, not `t2_slalom.json`.

**Checks:** tests 368 of 368 (mine 8); check 199 files, 0 failed. `course.gd` is unchanged.
**Not verified:** how the button feels with a real mouse.

Wind at 14:30: 16.9 kt from 222.1°, axis 222°; 4 boards.

| Course | Size | Axis | Nearest land: marks / legs | Legs | Fit |
|---|---|---|---|---|---|
| T2 sprint slalom (PD3), saved | 60 % | 232°, 10° right of the wind | 201 m / 201 m | Start→1 360 m 324°, 1→2 500 m 052°, 2→3 240 m 335°, 3→Finish 240 m 130° | 26 ms, 29,704 tries |
| LG2, the check | 100 % | 222°, square | 207 m / 217 m | Start→1 1852 m 222°, three legs of 1702 m (042°, 222°, 043°), 4S→Finish 450 m 127° | 2 ms, 907 tries |
