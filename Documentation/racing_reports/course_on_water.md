# course_on_water (9A): the course on the water

**Built.** Course files saved without a map carry `"frame": "game"` and game metres; lake files load as before. `RaceCourses`: T1 (LG2, 15 kt, 30 %: beat 556 m, line 60 m), T2 from `t2_slalom.json` or a PD3 stand-in, saved courses by name, the pre-start spot (150 m behind the line, beam reach toward mark 1, else starboard). `CourseOnWater`: orange buoys (yellow at a gate) with name flags, white boats with the Phase 7 flag (orange start, blue finish), pins; all float and tilt on the waves. The lines are shader strips on the same waves, off by default. Both scenes: `--course=<name>`, `--lines=1`, `--course_view=all|start|<mark>`. The HUD names the course; the mini-map draws it, course-centred on the open water. `play.sh` passes options through.

**Decisions to check**
- T1's gate (and finish) moved back to 150 m above the line, as the plan says; 30 % alone gives 45 m.
- The flags read the wind over the whole water, not `velocity_at()`: on the lake that call remembers its last spot for the physics, so a visual asking it would change the simulation.
- As briefed, the stand-in is centred on the start spot: marks 2, 3 and the finish land on land (a 100 % PD3 fits nowhere near). The fitted `t2_slalom.json` (now on `feature/p9-racing`) loads and lies on the water: tried uncommitted.
- Outside my list: the new `Game/race/course_line.gdshader`, and two lines moved before `super()` in `sail_silvaplana.gd`.
- `race_ui` edits the same scene and HUD files: expect small conflicts.

**Not verified:** how it looks in motion (bobbing, flags) and with the keys. From low, crests break up the lines.

**Frame rate** (RTX A1000 laptop, no vsync): lake 176 → 170 fps (+0.2 ms); open water 280 → 272 fps.

| Check | Result |
|---|---|
| `tools/test.sh` | 375 of 375 pass (360 before). Mine: test_course +2, test_race_courses 7, test_course_on_water 7 |
| `tools/check.sh` | 200 files, 0 failed |
| `t1_course_from_above.png` | the whole T1 from 260 m up (marks tiny), mini-map |
| `t1_start_area.png` | start line with boat, pin, line; gate and finish boat beyond |
| `committee_boat.png` | head to wind, orange flag downwind, line to the pin |
| `lake_buoy.png` | mark 1 on the lake's waves, float ring at the waterline |
| `lake_minimap.png` | lake map with the stand-in's marks, legs, board |
| `lake_minimap_fitted_t2.png` | the fitted T2 loaded, all marks on the water |
| `open_water_minimap.png` | course-centred map: wind, marks, lines, legs, board |
