# The waves and the wind: what was measured and what changed (Session 67, 2 November 2026)

For Max and Michiel. Written by Fable 5.1 on Max's PC, on the branch `gp/sea-follows-wind` from `gear/lead` (19b15d3).

Max, playing the release build of `gear/lead`: "the wind direction waves are not correct and moving with other wind directions", then "the wind and wave direction is always coupled, and is wrong", on the open water and on Silvaplana; the wave direction should be settable on its own, and the waves should follow the wind properly when they are set to.

## 1. What was measured: the rendered waves run with the wind

Two top-down screenshots half a second apart (`swell_t150.png`, `swell_t180.png`: the wind from the North, the swell at three times its height, the top-down camera bow-up with the board heading 330), read by `wave_direction.py` (a Fourier analysis of the water's picture: the strongest long-wave component gives the crest orientation, the phase difference between the frames the travel direction; the 5 m grid lines give the world axes on screen).

| Wave | On screen | As a bearing | The physics says |
|---|---|---|---|
| the swell (14 m; 156 px, 14.7 m) | travels at 225°, 20.8 px in 0.5 s (3.9 m/s against the board's drift) | toward 195 | wind 0 + 180 + 12 = 192 |
| the long chop (7 m; 73 px) | travels at 184° | toward 154 | wind 0 + 180 − 28 = 152 |
| the grid's N–S lines | along 29° | bearing 0 | (the heading 330 puts North at +30° on screen) |

So the picture and the physics agree to a few degrees, and both run downwind with the file's offsets. There is no sign error in the shader or the wave field: `k·(d·x) − ω·t` travels along +d in both, and `d` is the bearing's unit vector by (F0.1).

## 2. What was wrong for the player

1. **The sea only changed at a restart.** A new "Wind from" (or any wave setting) in the pause menu turned the wind at once but rebuilt the sea only when R was pressed, so the waves kept running with the old wind; the only hint was a line in the pause menu. Fixed first (`apply_settings_live()` rebuilds the sea at once while sailing; a race still waits for R, since the fleet's boards sail their own copies of the sea).
2. **The file's spread made the sea look as if it ignored the wind.** `waves_default.tres` (Session 36/37's sea, kept for the validation suite) sends the 7 m, 3.5 m and 1.8 m chop waves 28° left, 40° right and 55° left of downwind, and the swell 12° right: with a chop preset the crests cross at up to 95° (`waves_top.png`, strong chop ×2, wind from the West: two diagonal families). A windsurfer reads that as waves from other directions.
3. **The chop could not be set apart from the wind.** The swell could ("Swell comes from: a compass bearing"), the chop always turned with the wind.

## 3. What changed

- **The chop from a compass bearing** (`WaveSetConfig.chop_relative_to_wind`, `chop_from_deg`; PHYSICS_SPEC.md 9.15): the Waves tab's "Chop comes from" (the wind's direction, or a compass bearing) and "Chop from" (the bearing); "Chop direction" turns it from that base. Default: with the wind, as before. The lake's settings apply there too (its base wind is the Maloja's 222).
- **The wave spread** (`SettingsValues.wave_spread`, the Waves tab's "Wave spread"): the file's per-wave offsets and the swell's offset are multiplied by it. Default 0.25: the chop within ±14° of its direction, the swell +3° (`waves_top_narrow.png`: one family of crests across the wind). 0 is long parallel crests; 1 is the file's full spread. The file itself, the validation suite and the measurement harnesses (which read the file, not the settings) are unchanged.
- **The sea follows the settings at once** (point 1 above), with a test that walks the player's own route: Esc, Settings, the "Wind from" slider, Back (`test_menus.gd`).
- **The menu no longer stutters** (Max: "the UI lags"): every slider step called `GameSettings.apply_display()`, which set the shadow atlas, the 3D scaling, MSAA, vsync and the window mode again each time; now only when a graphics setting changed.
- **The push slider in a race** (from the morning): the race block's wind line says "push 75 %", the key help names Up/Down.

## 4. How to check it yourself

- Open water, Esc, Settings, Wind: move "Wind from"; Back: the waves turn with it at once (R is not needed).
- Waves tab: "Chop comes from: a compass bearing", "Chop from" 0° (the North): the chop runs South whatever the wind; "Wave spread" 0 for parallel crests, 1 for the old jumbled sea.
- Top-down camera (3) over strong chop shows the crests; `wave_direction.py <a.png> <b.png>` measures two screenshots.

## 5. Open

- The default spread (0.25) is Max's direction by eye; Michiel may want another number, or the file's offsets narrowed for the validation sea too (then `test_the_default_set_has_the_same_four_waves_as_before_the_groups` and the validation move).
- On the lake the chop's base is `wind_silvaplana.tres`'s 222 and does not follow the Maloja's turn through the day (−8° in the morning); the map's own wave direction (the fetch along the lake) would be the map track's item.

## 6. Max's play-test of the beta: still 90° off (2 November 2026, evening)

Max, playing the 0.2.0-beta.1 build: "the waves are still wrong, by 90 degrees"; the beta is on hold. So section 1's conclusion is contradicted by the player's eye, and this report is not the last word.

What was checked afterwards, so it need not be repeated:

- The physics, the shader, `WaveField.shader_parameters()`, the HUD's compass and the mini-map all use the same convention (north = −Z, east = +X, `direction_for_bearing(b) = (sin b, −cos b)`), and the shader's phase is the physics' phase on the world (x, z).
- The top-down camera of `camera_rig.gd` is bow-up (its `look_at` takes the board's heading as up), as section 1's measurement assumed. The map's `top_camera.gd` is north-up; if a screenshot came from that camera, the measurement's bearing is off by the board's heading.
- On the lake the waves are built once from `wind_silvaplana.tres`'s 222 while the Maloja wind blows from 236 to 245 through the day: a 20° gap, not 90.

What the next session does first, with Max at the screen: a screenshot of his exact situation (the water, the camera, the wind setting, the flag and the HUD's wind line in view) and the crests compared with the flag and the sails, not with a number; then the measurement's screen-to-world step in `wave_direction.py`; then whether the flag and the sails stream with the sim's wind. ROADMAP GR8. The lesson of this report: a fix for what the player sees is verified on the player's screen, with the player.

## 7. Found: the ripples' slopes did not turn with the wind (Session 68, 3 November 2026)

Written by Claude Opus 5.5 on Max's laptop, on `gp/sea-follows-wind`.

The water has two kinds of waves. The Gerstner waves move the surface and are what section 1 measured (with the swell at three times its height, they fill the picture). On top of them `water.gdshader` draws **ripples**: a normal map with bumps 7 m and 2.5 m long, which only changes the shading but in an ordinary sea, with the waves a few decimetres high, is most of what the eye reads as waves. The shader turned the ripples' pattern with the wind (it drifts downwind, stretched along the crests) but not their slopes: the normal map's tilt stayed on the map's own axes, which are the world's East and North. The light, the sun's glints and the mirrored sky come from the slopes, so the crests you see kept the map's direction:

- right for a wind from the West (270), the game's default, which is why the early play-tests looked fine;
- 90° off for a wind from the North or the South (Session 67's measurement was in a North wind, but measured the Gerstner swell, not the ripples);
- 25 to 48° off on the lake (the Maloja from 222 to 245).

The fix (`ripple_layer()` in `Game/world/water.gdshader`, and the same in the map's `Game/maps/lake.gdshader`): the map's tilt is turned onto the downwind and across directions, and the stretch halves the slope across the wind, so the ripples' crests lie across the wind whatever its direction.

Measured on flat water (the waves off, so only the ripples show), 18 kt, the follow camera, the wind from the camera's left in both: the West wind with the board heading North (the case that was right) against the North wind heading East. `ripple_compare.py` reads the water left of the board: the share of the picture's gradient across the screen, and how alike the two pictures' spectra are.

| | West, heading North | North, heading East | Spectra alike |
|---|---|---|---|
| Before | 0.05 (`ripples_west_before.png`) | 0.10 (`ripples_north_before.png`: grainy, cross-hatched) | 0.81 |
| After | 0.06 (`ripples_west_after.png`) | 0.06 (`ripples_north_after.png`) | 0.97 |

After the fix the North wind's water looks like the West wind's, turned with it. **Not verified yet: Max's own eye on his screen** (section 6's lesson). To check: open water, Settings, Wind, "Wind from" 0 (North), Back, and look at the water against the flag.
