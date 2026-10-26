# Map tools: Lake Silvaplana

Scripts that turn Swiss open data into the Silvaplana map. The plan behind them is [Documentation/MAP_SILVAPLANA_PLAN.md](../../Documentation/MAP_SILVAPLANA_PLAN.md). Run everything from the repo root.

**One command builds it all:** `tools/map/build.sh`. It is safe to run again: it only downloads what is missing. At the end it opens the visibility picture; when you double-click it, the window stays open until you press Enter.

## Setup (once per PC)

- Python 3 with `pip install numpy tifffile pillow imagecodecs`. `imagecodecs` is what lets tifffile read the compressed GeoTIFFs.
- Blender 4.5 LTS, for the 3D scripts in `tools/blender/`. `tools/common.sh` finds it through `$BLENDER`, then `blender` on the PATH, then the default Windows install.
- Git LFS (`git lfs install`), because the map's big files in `Game/maps/` and `Art/` are stored with LFS.

## The steps

| Script | What it does | Output |
|---|---|---|
| `download.py <stages>` | Downloads raw data from the swisstopo and MeteoSwiss STAC API, checks every file against its published SHA-256 checksum, and skips files already there. Stages: `heights`, `wind`, `photos-far`, `photos-near`, `surface` (sizes in the script's help, `--dry-run` to only list). Runs over 1 GB need `--yes`. | `.map_data/raw/`, plus `manifest.json` listing every file and its URL |
| `lake_level.py` | Finds the lake level: the most common swissALTI3D height over the lake. Writes the map's position settings (plan MD1). | `Game/maps/silvaplana/map_config.tres` (generated, don't edit), `.map_data/work/lake.json` |
| `visible.py` | Works out which land can be seen in the game, so only that gets built (plan MD4). It looks from the sailor, the orbit camera and the replay viewpoints listed in `silvaplana_area.VIEWPOINTS`. | `.map_data/work/visible_tiles.json`, `visible_50m.npz` and `visible_map.png` (a picture for the team: orange is what the sailor sees, yellow what only the cameras see) |
| `preview_data.py` | Prepares a quick look at the real valley for Blender: the shore band at 5 m with the lakebed under the water, the surroundings at 100 m, and the aerial photos as textures. Not the game terrain. | `.map_data/work/preview/` |
| `tools/blender/build_preview.py` (run with `tools/blender.sh`) | Builds `silvaplana_preview.blend` from that, with four cameras (on the water at the launch, above the village, a valley overview, from Corvatsch), and renders a picture from each. | `.map_data/work/preview/silvaplana_preview.blend`, `renders/*.png` |
| `heights.py` | The game terrain's heights (plan M1, MD4, MD5), in metres above the lake. Four detail levels: 2 m in the shore band (swissALTI3D with the swissBATHY3D lakebed, the unsurveyed shallows filled in smoothly), 10 m up to 3 km from the lake, 20 m up to 8 km, 40 m beyond (swissALTIRegio), only where something can be seen. Neighbouring detail levels are stitched so the meshes meet without cracks. | `.map_data/work/terrain/` (one height grid per chunk, `chunks.json`, `zones.png`), and `Game/maps/silvaplana/terrain/shore_heights.bin` + `.json` (the shore band at 2 m for the game logic; generated, don't edit) |
| `tests/test_heights.py` | Checks of heights.py's output: the lake at 0 m, the lake covered with water, the deepest point (77 m), Piz Corvatsch, the weather station, the camping at the shore, no holes, no cracks between chunks. | printed, one line per check |
| `tools/blender/build_terrain.py` (run with `tools/blender.sh`) | Builds one mesh per chunk, thins out flat ground (the border stays locked), adds a hidden skirt against gaps, sets the shading normals from the height grid, and exports `.glb`. Writes `terrain.tscn` with all chunks, and renders two pictures from above. `--only=<name>` rebuilds some chunks, `--no-render` skips the pictures. About 1 minute. | `Game/maps/silvaplana/terrain/*.glb` and `terrain.tscn` (generated, don't edit), `.screenshots/terrain_blender.png` and `terrain_blender_band.png` |
| `photos.py` | One aerial-photo texture per terrain chunk (plan M2): 8192 px per km (12 cm) on the two tiles of the camping and the launch beach, 2048 px (0.5 m) on the rest of the shore band, 512 px (2 m) up to 8 km and 128 px (8 m) further away. Where there is no Swiss photo (22 tiles in Italy), it paints the colour the Swiss photos have at that height, slope and lighting. `--only=<name>` makes some chunks. About 3 minutes. | `Game/maps/silvaplana/terrain/photos/*.webp` and their `.import` files (mipmaps, graphics-card compression; generated, don't edit), `.map_data/work/terrain/photo_fallback.png` (the learned colours) |
| `tests/test_photos.py` | Checks of photos.py's output: every chunk has its photo at the right size, Godot makes mipmaps and compresses them, the photos line up with the lake (flipped or shifted 100 m lines up worse), no black patches. | printed, one line per check |
| `maloja_stats.py <csv>` | Statistics of the Maloja wind and the air density from MeteoSwiss Segl-Maria. | printed; the results are in `Documentation/archive/PHYSICS_REQUESTS_FROM_MAP.md` |
| `maloja_research.py` | The wind analyser's research (map plan W0): how the Maloja behaves at five stations along its path, 2014 to now: the day, the start and how it travels, day types, gusts, pulses, shifts. Needs `download.py wind-valley`. About 40 s. | printed (keep it with `> .map_data/work/wind_research/report.txt`), `.map_data/work/wind_research/results.json`; explained in `Documentation/MALOJA_WIND_RESEARCH.md` |
| `maloja_charts.py` | The charts of the research document, from `results.json`, each in a light and a dark version. | `Documentation/images/maloja/*.png` |
| `satellite_wind.py` | Where the lake's water is rough on Maloja afternoons: every Sentinel-2 photo since 2017 taken in a Maloja (>= 10 kt at Segl-Maria) or a calm, averaged on a 10 m grid. Downloads only the lake's corner of each photo (about 10 MB each). About 45 minutes the first time, then it reuses the cut-outs. | `.map_data/work/wind_research/satellite/` (cut-outs, `scenes.json`, `roughness.npz`, pictures) |
| `windninja_pattern.py` | The Maloja's fixed pattern over the terrain (map plan W1): runs WindNinja for several directions and kinds of air, compares them with the satellite and the station, reruns the best at 50 m. Needs WindNinja (map plan, Tools). About 3 minutes. | `Game/maps/silvaplana/wind/maloja_pattern.json` + `.bin` (generated, don't edit), `Documentation/images/maloja/pattern_*.png`, `.map_data/work/wind_pattern/` (every run, `comparison.json`) |
| `gust_shapes.py [--model <folder>]` | Gusts seen from space (map plan W3): on each clean Maloja photo of `satellite_wind.py`, what is left after the lake's fixed pattern: its typical patch shape (along or across the wind, length, width), how much it varies across the lake, and the fronts across the lake; for all photos, the lane days and the front days. With `--model`, the wind analyser's gusts go through the same steps: first write them with `tools/godot.sh --headless --path Game -s res://maps/silvaplana/dev/export_gusts.gd -- <folder>` (about 10 minutes). A few seconds without `--model`. | printed, `.map_data/work/wind_research/gust_shapes.json`, `Documentation/images/maloja/gust_photos.png` and (with `--model`) `gust_model.png`; explained in `Documentation/MALOJA_WIND_RESEARCH.md`, "Gusts seen from space" |
| `shore_lee.py` | The lee along the south-east shore of Lake Silvaplana (map plan W3), from the satellite photos at 10 m: its shape across and along the shore (the north-west shore as the control), how deep it is per photo against the station's direction and speed (a straight-line fit), and what the fixed pattern (W1) already holds of it. Needs `satellite_wind.py` and `windninja_pattern.py`. A few seconds. | `Game/maps/silvaplana/wind/shore_lee.json` + `.bin` (generated, don't edit); explained in `Documentation/MALOJA_WIND_RESEARCH.md`, "The lee along the south-east shore" |
| `wind_ground.py` | The ground (or a lake's surface) under the wind pattern, for the wind viewer's streaks (map plan W2): the mean of swissALTIRegio's 10 m heights in each of the pattern's 50 m cells, from the Maloja pass to St. Moritz. Needs `heights.py`'s swissALTIRegio mosaic and the pattern. A few seconds. | `Game/maps/silvaplana/wind/ground.json` + `.bin` (generated, don't edit; the game reads it with `TerrainGrid`) |
| `silvaplana_area.py` | Not a step: the areas every script works on (lake, shore band, surroundings). | — |
| `readers.py` | Not a step: reads the raw files into height grids. | — |

`tools/blender/roundtrip_test.py` is the M0 check that Blender → `.glb` → Godot keeps the axes right. Run it with `tools/blender.sh tools/blender/roundtrip_test.py Game/maps/silvaplana/dev/roundtrip_hill.glb`; `Game/tests/unit/maps/test_map_roundtrip.gd` checks the result.

`.map_data/` is never committed. Anyone can rebuild it with `tools/map/build.sh`.

## To look at

- **The terrain in Godot:** double-click `tools/play.sh` and choose 2, or run `tools/play.sh silvaplana`. (It opens `res://maps/silvaplana/dev/terrain_view.tscn`.)
  - Keys 1 to 4 jump to the viewpoints: on the water at the launch, above the village, high above the valley, straight down.
  - Fly with W A S D, up and down with E and Q, Shift goes faster. Hold the right mouse button to look around; the mouse wheel changes the speed.
  - The lake is a flat stand-in with the map's see-through lake water (`Game/maps/lake.gdshader`, `Game/maps/silvaplana/lake.tres`): darker with depth, ripples, the mountains mirrored. **G** switches to the game's water shader in the lake's colours (`lake_water.tres`) to compare; `-- --water=game` starts with it. The real water, with waves, comes in M3.
  - When the view quits, Godot prints "7 RIDs of type Texture were leaked". That comes from the lake's reflection probe and is harmless.
  - `tools/play.sh silvaplana -- --measure=1` measures the frame rate at every viewpoint and quits.
  - `tools/play.sh silvaplana -- --at=2778600,1145000,150 --look=2758500,1128500,900` starts at any point (LV95 east, north, metres above the lake), looking at another.
- The map's look (sun, sky, haze) is in `Game/maps/silvaplana/silvaplana.tscn`; the terrain's look (photo, slope darkening, how much the sun shades the slopes) in `Game/maps/terrain.gdshader` and the `Terrain` node (`MapTerrain`).
- `.screenshots/terrain_blender_band.png`: the shore band from above, as Blender built it.
- `.map_data/work/terrain/zones.png`: where the terrain has which detail.
- `.map_data/work/visible_map.png`: what can be seen in the game. Orange: the sailor. Yellow: only the cameras.
- `.map_data/work/preview/renders/*.png`: the valley from four viewpoints.
- `.map_data/work/preview/silvaplana_preview.blend`: open it in Blender 4.5 and look around.
  - Numpad 0 looks through the active camera; pick another camera in the Outliner, then Ctrl+Numpad 0.
  - The axes: X is east, Y is north, Z is up, and Z = 0 is the lake surface.

BlenderGIS (2.2.10, in Blender 4.5) also works for exploring by hand. It imports GeoTIFF heights and photos, the lakebed's `.asc` grids, shapefiles and OpenStreetMap data. It can't convert coordinate systems (no GDAL or PyProj in Blender), but everything here is in Swiss LV95 anyway (EPSG:2056).

## Data and sizes (October 2026)

| Stage | Data | Size |
|---|---|---|
| `heights` | swissALTI3D 0.5 m, 25 tiles of the shore band (2023); swissBATHY3D Silvaplanersee; swissALTIRegio 10 m, 25 tiles of 10 km (east 2755 to 2805, north 1124 to 1174) | 0.54 GB |
| `wind` | MeteoSwiss Segl-Maria (SIA), 10-minute values 2020 to 2029 | 40 MB |
| `wind-valley` | MeteoSwiss Vicosoprano, Segl-Maria, Piz Corvatsch, Samedan and Bivio, 10-minute values 2010 to now (the `recent` file changes daily; delete it to get a newer one) | 0.41 GB |
| `photos-far` | SWISSIMAGE 2 m, 332 of the 354 visible tiles of 1 km (the other 22 are in Italy) | 55 MB |
| `photos-near` | SWISSIMAGE 10 cm, the 25 shore-band tiles (2025 flight) | 1.1 GB, downloaded in M2 (agreed by the team; `build.sh` passes `--yes`) |
| `surface` | swissSURFACE3D 0.5 m, the 25 shore-band tiles | about 0.34 GB, not downloaded yet (M4) |

## Credits

Every map built from this data must show: **"Terrain, aerial photos and lakebed: © swisstopo. Wind data: MeteoSwiss. Lake level: BAFU."** Pictures made from the satellite photos say "Contains modified Copernicus Sentinel data" with the years. The data is free Swiss Open Government Data, and naming the source is the only condition.
