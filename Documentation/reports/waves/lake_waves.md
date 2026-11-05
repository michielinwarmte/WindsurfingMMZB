# Lake Silvaplana's own waves (PH44, 5 November 2026)

Built on `ph44/lake-waves` (from 0fc5e0e) for Michiel's review on 6 November 2026, by Claude Opus 5.5. Not pushed, not merged. The physics of it is [PHYSICS_SPEC.md](../../PHYSICS_SPEC.md) section 9.17; the research behind it is `Documentation/reports/waves/wave_system_research.md` section 1 (written the same evening in the main folder; it is not on this branch).

Max asked: *"On Lake Silvaplana the waves need to be realistic: the water where the lake starts is flat and the waves get bigger while getting more downwind. Also the gusts impact the waves. And it needs to not be super CPU impactful."*

## In short

- **The lake now makes its own waves.** By the Sils shore the water is flat with small ripples; the waves grow with the open water the wind has blown over, and are biggest at the camping beach end. In the map's afternoon wind (18 kt) the significant height goes from about 4 cm 100 m out from the Sils shore to 13 cm in the middle and 18 to 21 cm at the downwind end, and the waves get longer: from half a metre to 3.5 to 4 m between crests.
- **The waves follow the map's wind**, not the fixed 222° of `wind_silvaplana.tres`: they are built for the direction and strength of the lake's wind at the time of day the sailing starts (`--time`, or the host's lake time in a LAN game).
- **The board floats on what you see.** The physics floats on the two longest wave trains (8 m and 4 m); the shorter chop (2 m, 1 m, 0.5 m) is drawn as shading only. With the short chop in the physics too, the board's hull could not ride it (the beam reach dropped from 20 to 11 kt): that is the known hull problem on short chop (PH9, PH10), a question for Michiel.
- **Gusts**: the real chop needs minutes to tens of minutes to grow, so a gust that lasts tens of seconds does not change the waves you ride (measured growth rates, below). What a gust changes within seconds is the water's small ripples (darker, rougher patches, as before) and, new, the half-metre wavelets, which now follow the wind of the last 8 to 35 seconds.
- **No extra CPU.** The sea's cost per board went down a little (0.97 to 0.89 ms a tick); 20 boards on the lake run at the same frame rate as before (88 fps at 1280×720, 75 against 72 fps at Max's 3137×1263).
- **A switch**: Settings > Waves > *Lake waves* (on by default on this branch). Off, the lake has the settings' waves again, bit for bit as before; the open water is never touched.

## What Max should look at on his screen

`tools/play.sh lake` (or the start menu's Lake Silvaplana). Compare with *Lake waves* off (Settings > Waves, last row; the sea changes at once, or at R in a race).

1. **At the start (camping beach)**: choppy water around the board, crests running toward the north-east (with the wind, from your right on the start heading). Does the size look like the real afternoon chop at the camping? (The research asks: knee, shin or ankle; one or two board lengths crest to crest?)
2. **Sail toward Sils** (south-west, upwind): the water should get calmer, with only small ripples near the Sils end. Is the change gradual enough, and does it happen in about the right place?
3. **From high up**: press the camera keys or start with `--overview=2781300,1148000,250` (above Silvaplana village looking toward Sils): wave texture on the near water, calmer far water, gust patches. No stripes or seams should show on the water.
4. **Gusts**: watch a darker patch come down the lake: the small ripples and wavelets in it should look rougher and choppier, a little behind the gust's edge.
5. **Sailing feel**: on a beam reach at the start the board should plane as before (the physics floats on the 8 m and 4 m trains); downwind it should pitch a little more over the longer waves near the beach. Say if it feels too calm or too bumpy.
6. **The settings page** at your window size: the new row *Lake waves* at the bottom of the Waves tab.

Screenshots (in [lake_waves/](lake_waves/)): `720_1_start.png` (the start, follow camera), `720_2_mid.png` (mid-lake), `720_3_sils.png` (near Sils), `720_4_high_toward_sils.png` (from above the village toward Sils), `720_6_gusts.png` (a steep view of mid-lake: gust patches and the lee along the south-east shore), `720_7_start_old_waves.png` (the start with Lake waves off), `720_settings_waves_end.png`; at 3137×1263: `wide_1_start.jpg`, `wide_4_high_toward_sils.jpg`, `wide_6_gusts.jpg`. All at 14:30 in the map's 18.2 kt. Not verified: how it looks while moving at 60 fps on Max's screen, and how it feels to sail.

## The model (plain language)

1. **The fetch map.** On a grid of points 16 m apart over the lake (from the depth grid), the open water upwind of each point is measured along nine lines 6° apart around the wind and averaged with more weight on the middle lines (the Shore Protection Manual's method, 1984). On a narrow lake this is smoother than one straight line and about 30 % shorter along the lake.
2. **The wind along the fetch.** The lake's mean wind of the day at that time (not the gusts), scaled by the map's wind pattern and the average lee under the south-east shore, averaged over the same upwind water (as the Lake Neuchâtel study suggests).
3. **How high and how long.** The Shore Protection Manual's fetch law (the same one `WindWaves` already used) gives the significant height and the peak period at each point; in shallow water the height stays below 0.6 of the depth. The Coastal Engineering Manual's law is a switch (same heights, 25 % shorter periods).
4. **Wave trains.** The sea is cut into five fixed wavelengths (8, 4, 2, 1 and 0.5 m); each gets the share of the sea's energy that the standard lake/sea spectrum (JONSWAP) puts in its octave. They keep their length and direction over the whole lake (so nothing jumps); only their heights change from place to place. Close to Sils only the shortest have any height; the long ones appear as the fetch grows.
5. **Physics and picture.** The physics floats on the 8 m and 4 m trains, reading their heights from the grid at each point it asks (one lookup). The water shader reads the very same grid and moves the surface by the same two trains, so the board sits on the surface you see (they differ by less than a millimetre). The 2 m, 1 m and 0.5 m trains, and the 8 m and 4 m trains away from the board, are drawn as short-crested shading (three parts each, turned ±26°), because one long straight train looks like brushed metal or corduroy.
6. **Gusts.** The 0.5 m wavelets grow with the wind of the last few seconds (their growth time from Plant's measured growth rate, 14 s at 18 kt), using a second channel of the gust picture that the graphics card already draws. The ripples follow the gusts at once, as before.

## Numbers and where they come from

| What | Value | Source |
|---|---|---|
| Fetch | 9 lines, 6° apart, cosine-weighted | Shore Protection Manual 1984, as the `lakefetch` documentation describes it (checked this session); the research 1.2 recommends it |
| Wind along the fetch | averaged over the upwind water | Casas, Bleninger and Stips 2025 (the research 1.3) |
| Growth law | SPM: g·Hs/U² = 0.0016 (gF/U²)^½, g·Tp/U = 0.286 (gF/U²)^⅓ | SPM 1984 (JONSWAP); already in `WindWaves` (spec 9.16) |
| Switch | CEM: u*² = 0.001(1.1 + 0.035 U)U², g·Hs/u*² = 0.0413 (gF/u*²)^½, g·Tp/u* = 0.651 (gF/u*²)^⅓ | Resio, Bratos and Thompson 2003 (CEM II-2), via the `waver` manual (the research 1.3) |
| Depth limit | Hs ≤ 0.6·depth | Coastal Engineering Manual 2002 (spec 9.16) |
| Spectrum | JONSWAP, γ = 3.3, σ = 0.07 / 0.09 | Hasselmann et al. 1973; SINTEF SIMA's form (the research 1.4) |
| Trains | 8, 4, 2, 1 m (and 0.5 m for the picture), octave bands | the research's recipe 1.7 |
| Trains' directions | 0, −7, +10, −14, +18° off downwind | **estimate**: the size of the settings' default spread |
| The physics on | the 8 m and 4 m trains | **measured** (below) |
| Grid | 16 m | **estimate**, within the research's 8 to 16 m |
| Short wavelets' response time | 1/(0.04 (u*/c)² ω): 35 s at 12 kt, 14 s at 18 kt, 8 s at 24 kt | Plant 1982 via Polnikov (the research 1.5). How fast they calm after a gust: **not measured**, the same time is used (estimate) |
| The picture's short-crested parts | ±26°, ×1.14 / 1 / 0.88 | **a choice for the look**, within Donelan-Banner spreading (about ±40°; Horvath 2015) |

My band amplitudes reproduce the research's table 1.4 to the millimetre, and the CEM law its 0.221 m and 1.38 s (`test_lake_waves.gd`).

## Measurements

### Height and wavelength down the lake

`tools/godot.sh --headless --path Game -s res://dev/lake_waves_table.gd -- --through=middle`: along the line through the lake's middle, wind from 222°, measured from the Sils shore. "Model" is the game's (9-line fetch, the map's wind along it); "law" is the plain SPM law for the straight distance in the lake's mean wind. Hs is the significant height, Lp the peak wavelength.

| From the Sils shore | 9-line fetch | 12 kt: model / law | 18 kt: model / law | 24 kt: model / law |
|---|---|---|---|---|
| 100 m | 103 m | 3.4 cm, 0.5 m / 3.2 cm, 0.4 m | 4.2 cm, 0.5 m / 4.7 cm, 0.6 m | 4.5 cm, 0.6 m / 6.3 cm, 0.7 m |
| 500 m | 521 m | 7.3 cm, 1.3 m / 7.1 cm, 1.3 m | 9.9 cm, 1.6 m / 10.6 cm, 1.7 m | 12.1 cm, 1.9 m / 14.1 cm, 2.0 m |
| 1000 m | 884 m | 9.5 cm, 1.9 m / 10.0 cm, 2.0 m | 13.4 cm, 2.4 m / 15.0 cm, 2.7 m | 16.9 cm, 2.8 m / 19.9 cm, 3.2 m |
| 2000 m | 1510 m | 12.6 cm, 2.7 m / 14.1 cm, 3.2 m | 18.4 cm, 3.5 m / 21.2 cm, 4.3 m | 23.8 cm, 4.2 m / 28.2 cm, 5.2 m |
| 2750 m | 1961 m | 14.2 cm, 3.2 m / 16.5 cm, 4.0 m | 20.9 cm, 4.2 m / 24.8 cm, 5.3 m | 27.3 cm, 5.0 m / 33.1 cm, 6.4 m |

The model is a little below the straight-line law because the 9-line fetch is shorter along the lake, and near Sils in strong wind also because of the lee along the south-east shore (the wind along the fetch there is 0.87 of the lake's mean at 18 kt, 0.70 at 24 kt). At the start spot in the map's 18.2 kt: Hs 18 cm, peak 3.4 m; the physics' trains 9 mm (8 m) and 47 mm (4 m), the shading's 34 mm (2 m) and 19 mm (1 m). The full tables (every 250 m, the trains' amplitudes) are printed by the same tool, `--through=start` for the line through the start spot.

### Why the physics floats on two trains, not four

A beam reach from the start spot in the map's wind at 14:30 (18.2 kt), `tools/lake_matrix.sh --only=straight --times=14:30` with `--waves=1` (the old sea) or `--lake_waves=1 [--lake_bands=...]`:

| The sea under the board | Mean speed, 12 s window | Top speed | Largest yaw rate |
|---|---|---|---|
| the old sea (the default set) | 20.5 kt | 22.0 kt | 8.6 °/s |
| the lake's 8 m and 4 m trains | 20.3 kt | 21.4 kt | 7.6 °/s |
| all four trains at half height | 20.9 kt | 22.3 kt | 8.7 °/s |
| all four trains | 10.7 kt | 22.3 kt | 30.8 °/s |
| the 2 m and 1 m trains alone | 5.6 kt | 6.3 kt | 42.8 °/s |
| the 2 m and 1 m trains, the water's velocity set to 0 | 4.7 kt | 10.2 kt | 41.9 °/s |

The 2 m and 1 m trains (3 and 2 cm high on the lake, steepness about 0.1) stop the board planing and make it yaw. Taking the water's own movement out does not help, so it is the heights and slopes under a hull longer than the waves (the strips and buoyancy rows; PH9, PH10), not the fin. In real life a planing board skims such chop. So the physics rides the 8 m and 4 m trains (`physics_trains = 2` in `lake_waves_silvaplana.tres`) and the picture shows the rest as shading. Once the hull rides short chop, `physics_trains = 4` puts them in.

### The manoeuvres on the lake

`tools/lake_matrix.sh --waves=1` (the old sea) against `--lake_waves=1` (the lake's own waves, the physics on the 8 m and 4 m trains): the beginner controller's manoeuvres in the map's wind at 12:00 (14.7 kt at 10 m), 14:30 (18.2 kt) and 17:00 (16.5 kt). The mean speed in the 12 s window after each (kt), old / lake:

| Case | 12:00 | 14:30 | 17:00 |
|---|---|---|---|
| straight (beam reach) | 23.3 / 22.8 | 20.5 / 20.3 | 23.7 / 20.7 |
| tack, starboard | 16.4 / 17.1 | 17.9 / 16.9 | 12.5 / 12.3 |
| tack, port | 10.5 / 13.7 | 10.4 / 9.1 | 18.4 / 18.1 |
| tack, held | 6.4 / 4.8 | 5.9 / 6.3 | 7.5 / 6.1 |
| gybe from a broad reach | 16.4 / 17.4 | 15.6 / 14.9 | 16.8 / 15.7 |
| gybe from a beam reach | 16.4 / 16.3 | 13.3 / 14.6 | 14.4 / 15.6 |
| run, turn left | not completed / completed at 38.1 s | 7.8 / 7.0 | 20.9 / 22.5 |
| out of irons | 3.8 / 3.7 | 3.0 / 3.6 | 3.8 / 4.0 |

No falls on either sea; on the old sea one manoeuvre did not complete (the 12:00 run), on the lake's own waves all did. The speeds are the same within the cases' usual scatter, except the 17:00 beam reach (3 kt slower) and more yaw-rate reversals on the gybes and the straight reach (5 to 15 against 0 to 10): the board pitches and swings a little more on the 4 m waves near the camping beach. The full output is in `.logs/lake_matrix_old.log` and `.logs/lake_matrix_lake.log` (not committed).

### Cost

Measured back to back on this PC (Ryzen 7 5800X3D).

| | The lake's old waves | The lake's own waves |
|---|---|---|
| A warm sea sample (`tools/sea_bench.sh --lake=old` / `--lake=2`, editor engine) | 6.95 µs (4 trains) | 6.28 µs (2 trains + one grid lookup) |
| The sea's share of a board's physics tick | 0.974 ms | 0.889 ms |
| 8 boards stepped side by side on threads, a tick | 6.82 ms | 6.85 ms |
| 20 boards on the lake, release build, 1280×720 (`tools/fleet_measure.sh --sizes=19 --course=t2_slalom --seconds=20`) | 88 fps; frame 11.4 ms (worst 17.6); all boards' physics 7.49 ms a tick; a board 2.43 ms | 88 fps; frame 11.3 ms (worst 18.3); 7.17 ms; 2.29 ms |
| The same at 3137×1263 | 72 fps; frame 13.8 ms (worst 23.0); an AI board 2.46 ms | 75 fps; frame 13.3 ms (worst 24.9); 2.34 ms |
| Building the lake's waves at the start | – | about 0.5 s (34 500 points, 9 lines each) |

For comparison, all four trains in the physics would cost 9.64 µs a sample and 1.33 ms a tick. The open sea's path is unchanged (6.92 µs, 0.968 ms, the same as before within noise). The graphics card draws the lake's waves per pixel and a second channel of the gust picture; at Max's size the frame rate did not drop.

### Checks

- `tools/test.sh` (the new `test_lake_waves.gd`, 24 tests: the fetch map against hand-worked fetches, the trains against the research's table, the CEM law, flat by the upwind shore and bigger downwind, the depth limit, sample_at against the three queries, physics and picture within a millimetre, the same sea from the same inputs, the short wavelets' response time against Plant's numbers, the switch: off is bit for bit the old sea, the open water ignores it, the settings reach the wave set and the file, one sea for every board): see the counts at the end.
- `tools/check.sh`, `tools/test.sh validation`: see the end.
- `--check-gusts=1` on the lake: the gust picture against MapWind within 0.0030 (red, the ripples) and 0.0024 (green, the new 14 s average); one 8-bit step is 0.0039.
- `tools/lan_test.sh --map=lake --seconds=40`: SYNC CHECK PASS; both PCs printed "Lake Silvaplana's own waves: built for 18.2 kt at 10 m from 222 degrees".

## Where this differs from the research, and why

- **The physics gets two trains, not the four of 1 m and longer** the research suggested: measured above, the hull cannot ride the 2 m and 1 m trains yet. The research itself flagged this (its section 3, PH9/PH10).
- **The fetch map is built at the start for the wind of that time**, not baked every 5° over the Maloja sector: building it takes 0.5 s, the wind's direction on the lake only turns about 20° over the whole day, and a run uses one direction. A rebuild during a long session (with a cross-fade) is open.
- **The 0.5 m wavelets' response time is Plant's for a 0.5 m wave** (8 to 35 s), longer than the research's "1 to 10 s" for the short bands, which is the range for 5 cm to 0.3 m waves in its own table. The centimetre ripples keep the instant response of the gust picture.
- **The wavelets' gust average is the wind downwind now** (frozen turbulence) rather than "the mean of the wind field over the last τ seconds at that point": the same thing for gusts that drift with the air and change over minutes, and three lookups instead of a history.

## Open, and questions for Michiel

1. **`physics_trains`**: 2 now. Do you want the 2 m and 1 m trains in the physics, and is PH10 (the strips on short chop) the way to get there? The table above is the measurement to repeat.
2. **The growth law**: SPM (default) or CEM. Same heights, 25 % different wavelengths (5.2 or 3.0 m at 16 kt over 3 km). Max's eye on the water can decide.
3. **The fetch**: the 9-line cosine average or one straight line; the wind averaged along the fetch or the local wind.
4. **The envelope**: the trains' heights are read at the asked point and used for the whole rest-point solve (the rest point is at most 0.1 m away; heights change over 16 m). The normal leaves out the height's slope (about 10⁻³). Fine for you?
5. **Speed in shallow water**: the trains move at their deep-water speed everywhere (spec 9.16's open item); the lake is deep for these waves on 94 % of its area.
6. **The day's wind**: the waves are built once per run, for its start. They do not follow the day's slow change during a long session (a few % per hour around 14:30).
7. **The AI's observation** `sea_height` still reads the settings' wave set, not the lake's waves (RaceObservation). Change it, or keep the brains' inputs as they were trained?

## Questions for Max (from the research, section 8)

At the camping beach on a typical afternoon: how high are the waves (ankle, shin, knee) and how many board lengths from crest to crest? Do they get calmer toward Sils as in the game? In a gust, does only the water's texture change, or do the waves get bigger within a minute? From what wind do you see whitecaps? (The game draws foam only on the steepest crests, which these waves rarely reach; whitecaps are a next step.)

## Files

- New: `Game/sim/lake_waves.gd`, `Game/sim/lake_wave_field.gd`, `Game/sim/fetch_map.gd`, `Game/sim/config/lake_waves_config.gd`, `Game/maps/silvaplana/lake_waves_silvaplana.tres`, `Game/tests/unit/test_lake_waves.gd`, `Game/dev/lake_waves_table.gd`.
- Physics (Michiel's): `wind_waves.gd` (the CEM law added), `wave_set_config.gd` (`place_waves`), `environment_config.gd` (`lake_waves`, `depth_grid_path`, `lake_waves_for()`), `windsurfer_sim.gd` (`environment`, `set_waves()`), PHYSICS_SPEC.md 9.17 with its sources and a tuning-log row.
- Picture: `world/gerstner.gdshaderinc`, `world/water.gdshader`, `world/ocean.gd` (the lake mesh), `maps/wind/wind_ripple_map.gd(shader)` (the green channel), `world/effects/wake_foam.gdshader`, `race/course_line.gdshader` (ride the lake's trains).
- Game: `maps/silvaplana/sail_silvaplana.gd` (the session's time for the sea, the console line, the gust picture's time), `gear/gear_choice.gd` (keeps the environment), `ui/settings_values.gd`, `ui/settings_menu.gd`, `ui/start_menu.gd` (`--page=settings/<tab>/end`).
- Tools: `dev/run_lake.gd` (`--lake_waves=1`, `--lake_bands`, `--lake_physics`, `--lake_scale`, `--lake_law`), `dev/sea_bench.gd` (`--lake=2|4|old`), `tools/screenshot.sh` (`SCREENSHOT_RESOLUTION`).
