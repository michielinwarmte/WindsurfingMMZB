# Map Plan: Lake Silvaplana (Silvaplanersee), Switzerland

Written 14 October 2026 (Session 37, map track), for the AI sessions doing the work and for the MMZB team reviewing it. Work on the branch `feature/map-silvaplana`. The rules and commands in [CLAUDE.md](../CLAUDE.md) still apply, and so does the "How to use this plan" section of [REBUILD_PLAN.md](REBUILD_PLAN.md): phases in order, tick a box only when it is done and verified, stop at the end of every phase so the team can play-test.

This is a side track next to the main plan. It builds the first real map: Lake Silvaplana in the Upper Engadin, one of the best-known windsurf spots in the Alps, famous for the afternoon Maloja wind.

**Who does what.**
- **Michiel** does the physics (`Game/sim/`): the simulation, and how the board, the sail and the water react to the wind and the waves.
- **Max** does the map, and the wind patterns that belong to it: the Maloja's daily cycle, its gusts and shifts, and where the wind is strong or weak on the lake (L1). He started those early, as the wind analyser (phases W0 to W4 below). Max knows the spot (notes: [SILVAPLANA_SPOT_NOTES.md](SILVAPLANA_SPOT_NOTES.md)).

The wind patterns describe what the air does; the physics decides what the board does with it. They meet at `WindField.velocity_at(point)`, and that connection is agreed with Michiel (requests R1 and R5).

The map track does not change the physics files (MD7). Everything the map needs from the physics is listed under "Later", as a request to Michiel.

The branch starts from `feature/physics-sim` (Phases 1 to 5), because `main` does not have the playable game yet. Merge Michiel's work into this branch regularly (MD7). (16 October 2026: the physics branch, up to Session 37, was merged into this one, and both go to `main` through pull requests #2 and #3; from then on merge `main`.)

## Status

| Phase | What | Status |
|---|---|---|
| M0 | Tools, round-trip test, data download | ✅ Done on Windows (Session 38). The 10 cm photos were agreed and downloaded in M2. Still open: the Linux PC check, and the surface model (M4) |
| M1 | Terrain and lakebed in Godot | ✅ Built on Windows (Session 39). Max's look, with the photos of M2 (Session 41): the terrain "is really good and nice" |
| M2 | The look: aerial photo, sky, the mountains you can see | ✅ Built on Windows (Sessions 40 and 41), with see-through lake water in the terrain view. Max's look (Session 41): the terrain really good, the first water "really bad", so the see-through water was built. Max, 16 October: the new water works well. Waiting for Michiel on R9 (the water in the game) |
| M3 | Sailing on the lake: start spot, one Maloja weather setting, shoreline | ⬜ |
| M4 | Details: camping and beach, village, trees, landmarks | ⬜ |
| W0 | Wind analyser: research into how the Maloja behaves | ✅ Done (Session 42): [MALOJA_WIND_RESEARCH.md](MALOJA_WIND_RESEARCH.md). Max answered its questions on 15 October (in SILVAPLANA_SPOT_NOTES.md and the research document) |
| W1 | Wind analyser: the fixed pattern over the terrain (WindNinja) | ✅ First version (Session 42): direction from WindNinja, strength on the lake from the satellite. Checked by Max on 15 October: the weak south-east shore, the weak Sils end, the direction along the lake and the stronger north-west side are right |
| W2 | Wind analyser: the 3D viewer in Godot | ✅ First version (Session 43): `tools/play.sh wind`. Max's first look: Windfinder's colours, and he missed the gusts (both done: the colours in W2, the gusts in W3) |
| W3 | Wind analyser: gusts, pulses, shifts and the day | 🔶 Mostly done (Session 43): gusts and lulls measured on the satellite photos (fronts across the lake, lanes along the wind), pulses and shifts, and the lee along the south-east shore. "The day" (start front, day types) postponed by Max on 15 October: W4 first |
| W4 | Wind analyser: course maker (W4a) and tactics tools (W4b) | 🔶 W4a done (Session 44): the ten iQFOiL courses as templates with the class's distances, dragging, turning, resizing, saving for the team. Checked by Max on 16 October: easy to use, and the templates look like the diagrams. Then added at his request: adding marks (dropped on a leg, or typed into the order), renaming, port or starboard, deleting; and after his look at a wide window, panels that fit any window size and rounding arrows that follow the course. Max, 16 October: adding marks works well, so W4a is checked. W4b next. On the average day |
| Later | Big projects for every spot, with Michiel: wind patterns, wind-driven waves, mountain-lake physics, live weather, other sailors | L1, the wind patterns: 🔶 Max's part mostly built as the wind analyser (W0 to W4); still open: the day types (W3) and the connection to the sailing (W5, Michiel). L2 to L5: ⬜ |

## Team decisions (14 October 2026)

1. **Size:** only Lake Silvaplana is sailable, and the map is as small as possible: the lake, a detailed band of shore around it, and further away only what you can see from the water (mountains, slopes), with nice graphics. Lake Sils is not sailable.
2. **Waves:** waves will be made by the wind, as one big general system for every spot (Later L2). Until then the map uses the current waves unchanged.
3. **Repository size:** at most 300 MB of map files. That is enough for the smaller map (MD2).
4. **Weather:** for now one fixed Maloja setting: 12 to 20 knots, with gusts and shifts from the simple options the wind model already has (M3). A realistic wind simulation is a big project for later (Later L1).
5. **Physics:** Michiel makes all physics changes. The map track stays out of the physics files (MD7). Max takes on the wind patterns later (L1), connected to the physics through an interface agreed with Michiel.
6. **Other kiters and windsurfers on the water:** later, nice to have (Later L5).
7. **Local knowledge:** Max knows the spot. His notes are the check for M2 to M4, and for the wind later.

**Since then (16 October 2026):** the wind patterns (L1, decisions 4 and 5) didn't wait: Max asked for the wind analyser on 14 October, and phases W0 to W4 built most of his part of L1. Decision 4 is still the plan for M3: the sailing keeps a fixed `WindConfig` setting until W5 connects it to the analyser's wind (R5, Michiel).

## The open data we use

All of it is free Swiss government data (Open Government Data). It may be used, changed and published, also commercially, as long as the source is named. The game gets a credits line: **"Terrain, aerial photos and lakebed: © swisstopo. Wind data: MeteoSwiss. Lake level: BAFU."**

Everything was checked to exist for this area in Session 37 through the STAC API at `https://data.geo.admin.ch/api/stac/v0.9/` (MeteoSwiss: `/api/stac/v1/`).

| Data | What it gives us | Format | Collection id |
|---|---|---|---|
| swissALTI3D | Ground height without trees and buildings, 0.5 m or 2 m grid. Lakes are flat at the water level. | Cloud-optimized GeoTIFF, 1 km tiles | `ch.swisstopo.swissalti3d` |
| swissALTIRegio | Ground height, 10 m grid, also over the border into Italy. For the mountains far away and for working out what is visible. | One cloud-optimized GeoTIFF of all Switzerland (10 GB, read only the part we need), or 10 km XYZ tiles | `ch.swisstopo.swissaltiregio` |
| swissBATHY3D | The lakebed of Lake Silvaplana, 1 m grid, survey of 2019, about 4 km². Only where the water is deeper than about 1 m. | ESRI ASCII grid or XYZ, one zip of 12 MB | `ch.swisstopo.swissbathy3d`, item `swissbathy3d_silvaplanersee` |
| SWISSIMAGE | Aerial photos, 10 cm or 2 m per pixel | Cloud-optimized GeoTIFF, 1 km tiles | `ch.swisstopo.swissimage-dop10` |
| swissSURFACE3D raster | Height including trees and buildings, 0.5 m. Minus swissALTI3D, this gives tree and building heights. | Cloud-optimized GeoTIFF, 1 km tiles | `ch.swisstopo.swisssurface3d-raster` |
| swissBUILDINGS3D 3.0 (2.0) | 3D buildings with roof shapes | DWG / file geodatabase (2.0: DXF) | `ch.swisstopo.swissbuildings3d_3_0` (`_2`) |
| swissTLM3D | Map features: roads, rivers, forest areas, the lake outline | Shapefile / geodatabase, all of Switzerland in one large file | `ch.swisstopo.swisstlm3d` |
| MeteoSwiss station **Segl-Maria (SIA)** | Wind every 10 minutes at the south-west end of the lake (LV95 2778576 / 1144976, 1804 m): mean direction (since 2004), mean speed, and the strongest 1-second and 3-second gust of each 10 minutes. Updated every 10 minutes. | CSV per station | `ch.meteoschweiz.ogd-smn`, parameters `dkl010z0`, `fkl010z0`, `fkl010z1`, `fkl010z3` (speeds in m/s) |
| MeteoSwiss Piz Corvatsch (COV), Samedan (SAM) | Wind on the mountain top and further down the valley, for comparison | same | same |
| BAFU hydrology station 2073, Silvaplanersee–Silvaplana | The lake level (LV95 2781560 / 1148150, about 1791 m) | hydrodaten.admin.ch; check how to download | — |

**The spot, in numbers.** The lake lies between LV95 east 2779 and 2782 km and north 1145 and 1148.2 km. It is about 3 km long, at 1790.63 m above sea level (measured on swissALTI3D in M0). Silvaplana village is at the north-east end (around 2781.1 / 1148.0).

The launch spot is the beach at **Camping Silvaplana** at the north end, with a surf centre. It is one of the three public access points to the lake for water sports. With the Maloja blowing, it is the downwind end of the lake.

The Maloja wind is a thermal valley wind from the south-west (from the Maloja pass, along the valley). Spot guides say it starts around noon and is strongest from 15:00 to 17:00, at typically 16 to 25 knots, and dies around 18:00 to 19:00. Season: June to September.

The station at Segl-Maria (2020 to 2025) confirms the pattern:
- 61 % of summer days have at least 3 hours of Maloja in the afternoon,
- it comes from 244°,
- it builds from 11:00, holds about 12 to 13 kt mean with 19 to 20 kt gusts from 13:00 to 16:00, and fades after 18:00.

The station stands on land, so its speeds are probably lower than on the water. Details: [PHYSICS_REQUESTS_FROM_MAP.md](PHYSICS_REQUESTS_FROM_MAP.md).

Found since (W0 and W1, Sessions 42 and 43; all of it in [MALOJA_WIND_RESEARCH.md](MALOJA_WIND_RESEARCH.md), five stations, 2014 to 2026, and satellite photos of the lake):
- The 244° is the station's own spot turning the wind. Over the lake the Maloja blows along the lake, from about 222° (WindNinja; Max: "pretty good").
- On the water a competition day is 12 to 14, 15 to 18 or 18 to 22 kt, depending on the day (Max). The wind analyser takes 1.3 times the station.

## Tools

| Tool | What we use it for | On Max's Windows PC (14 Oct 2026) |
|---|---|---|
| **Godot 4.7.2** | The game: plays the map, the sailing, the water, the wind | ✅ installed |
| **Blender 4.5 LTS** | All 3D: the terrain meshes (by script), the camping, the beach and the other props (by hand, with AI help). Export to `.glb` for Godot. | ✅ 4.5.4 LTS installed |
| BlenderGIS (Blender add-on) | Look at the Swiss data in Blender: import a height tile or an aerial photo at its real position. Handy for exploring and for placing props by hand. The pipeline does not depend on it. | ✅ 2.2.10 works in Blender 4.5 (checked in M0): GeoTIFF, `.asc`, shapefile and OpenStreetMap import. No coordinate conversion (no GDAL or PyProj), which we don't need |
| **Python 3.12** with `numpy`, `tifffile`, `Pillow`, `imagecodecs` | Download and prepare the data (MD2). `imagecodecs` lets tifffile read the compressed GeoTIFFs. | ✅ installed |
| **QGIS** (free GIS app, LTR version) | Look at all the Swiss data on a map, measure, and draw by hand (the camping layout). It brings GDAL, which converts swissBUILDINGS3D for M4. | ✅ QGIS LTR 3.44.14 installed |
| **Git + Git LFS** | Version control, big files (MD2) | ✅ installed |
| **VS Code** + godot-tools, **Claude Code** | Writing code and scripts with AI | ✅ installed |
| GIMP or Krita (optional) | Touch up textures, for example the camping signs | optional |
| **WindNinja 4.0.0** (US Forest Service, free) | The wind analyser's fixed pattern (W1): the wind over the real terrain. `WindNinja_cli.exe` is run by `tools/map/windninja_pattern.py`. | ✅ unpacked with 7-Zip into `%LOCALAPPDATA%/Programs/WindNinja/4.0.0` (no admin rights needed; the official installer asks for them). The scripts find it through `$WINDNINJA`, then that folder |

Everyone on the team uses the same Blender version (4.5 LTS, supported until 2027) so the scripts and the `.blend` files behave the same on every PC. The Linux PC has Blender at `/usr/bin/blender`; check its version.

## Key decisions

### MD1. Swiss coordinates straight into the game, no map projection
Swiss LV95 coordinates are already metres east and north on a flat grid. So the game uses them directly with a fixed origin, and nothing needs to be reprojected:

- game X = LV95 east − `ORIGIN_E`
- game Z = −(LV95 north − `ORIGIN_N`) (north is −Z, main-plan D4)
- game Y = height above sea level − `LAKE_LEVEL_M`, so the lake surface is at Y = 0, where the simulation already puts the water.

The origin is at the middle of the lake, LV95 2780500 / 1146600 (fixed in M0). The numbers live in one config resource, `Game/maps/silvaplana/map_config.tres`. A unit test checks that a few known points (Silvaplana church, the weather station, Piz Corvatsch) land in the right game position.

Godot uses 32-bit floats, which are still accurate to about 1 mm 10 km from the origin, so rounding is not a problem at this size.

### MD2. Python prepares the data, Blender builds the 3D, Godot plays it
Each tool does what it is good at:

1. **Python** (`tools/map/*.py`) downloads the raw data and turns it into clean grids and images, cut into chunks: height grids as numpy files for Blender and a 16-bit `.bin` for the game (M1: Godot reads 16-bit PNGs only as 8-bit), photos as WebP. It is repeatable and testable, and the AI can run it.
2. **Blender** turns those grids into 3D: terrain meshes made by a script (MD3), and props made by hand (M4). Everything leaves Blender as `.glb`.
3. **Godot** imports the `.glb` files and plays them. It never reads the raw data.

Details:
- Python packages: only `numpy`, `tifffile` (reads the GeoTIFFs, with `imagecodecs` for their compression) and `Pillow` (writes images). No GDAL or rasterio: we need no reprojection (MD1), and they are hard to install on Windows.
- Raw downloads go to `.map_data/raw/`, which is never committed (add it to `.gitignore`). Every download is listed in `.map_data/raw/manifest.json` with its URL and date, and is checked against the checksum the STAC API publishes.
- The game-ready files go to `Game/maps/silvaplana/`. They are committed through **Git LFS** (add `.gitattributes` rules for `.glb`, the image types and `.blend` files).
- Anyone can rebuild everything with one command: `tools/map/build.sh` (download if missing, prepare, then run the Blender scripts headless).

**The 300 MB budget.** A rough estimate for the small map is 100 to 200 MB: aerial photo textures of the shore band, thinned-out terrain meshes, and props. So 300 MB is enough. Measure it at the end of every phase.

Watch the Git LFS quota. GitHub's free quota for the account that owns the repository is 10 GB of storage and 10 GB of downloads a month. Every committed version of a big file counts toward the storage, so commit rebuilt map files at the end of a phase, not after every small change.

### MD3. The terrain and the props come from Blender as `.glb`
glTF (`.glb`) is the 3D format Godot works with best: meshes, materials, textures and positions come across, and on import Godot builds simpler versions of every mesh for far away (automatic LOD). The main plan's Phase 6 uses the same route for the board and the sail.

- **Terrain, made by a script.** `tools/blender/build_terrain.py` runs headless (`blender --background --python ...`). It reads the height grids from Python, builds one mesh per chunk, and exports the chunks as `.glb`. (The aerial photos go on in Godot instead, M2: then a new photo needs no new meshes.) The AI can run it and check its own work: Blender renders a preview image, and `tools/screenshot.sh` shows the result in the game.
- **Props, made by hand,** with AI help (the AI can write Blender scripts for repetitive work, like placing 40 tents). Camping, beach, surf centre, flags, tents: M4.
- **Never edit generated files by hand.** The script overwrites them on every build. Hand work goes into its own `.blend` files: for example a sculpted beach is a separate mesh that sits on top of the terrain.
- **Sources outside `Game/`.** `.blend` files live in `Art/silvaplana/`, and only the exported `.glb` files go into `Game/maps/silvaplana/`. Godot could import `.blend` files directly, but then every PC and every AI check (`tools/check.sh`) would need Blender, and two Blender versions could produce different results. Exporting `.glb` (`tools/blender/export_props.py`, one command) keeps the game independent of Blender.
- **Meshes are for looks, grids are for the game logic.** The shoreline check and the depth under the board read the Python grids, never the meshes. So a nicer mesh can never change how the board sails.
- **No terrain plugin.** Terrain3D, the best-known Godot terrain plugin, officially supports Godot 4.4 to 4.6, and 4.7 is not confirmed. If the `.glb` terrain is too slow or looks wrong in M2, look at Terrain3D again. (M2: about 1,500 fps, and Max likes the look, so no plugin is needed.)

### MD4. As small as possible: a detailed shore band, and only what you can see
- **The lake and its shore band** have full detail: the land up to about 500 m from the water. That is the 1 km tiles from east 2778 to 2782 km and north 1144 to 1148 km (25 tiles). swissALTI3D at 0.5 m. SWISSIMAGE at 10 cm around the camping and the beach, about 0.5 m on the rest of the band.
- **Everything further away is built only if it can be seen in the game.** `tools/map/visible.py` works this out from the viewpoints in `tools/map/silvaplana_area.py`. Which pieces of land can be seen from:
  - the sailor (2 m above the water),
  - the orbit and free cameras (up to 60 m),
  - the replay shots: a drone 150 m over the lake, and cameras on the shore at 2 m and 50 m?

  The top-down camera looks straight down, so it only sees land close to the board. When the cameras change, change the viewpoints and run `tools/map/build.sh` again.

  Only those pieces are built, with less detail the further away they are, out to the last visible ridge. The source is swissALTIRegio at 10 m, which also covers the Italian side. M1 uses four detail levels, so that one grid cell looks about equally big from the water at every distance (about 0.3°):

  | Zone | Grid | Where | Tiles of 1 km |
  |---|---|---|---|
  | near | 2 m | the shore band (swissALTI3D and the lakebed) | 25 |
  | mid | 10 m | visible, up to 3 km from the lake | 56 |
  | far | 20 m | visible, 3 to 8 km from the lake | 103 |
  | distant | 40 m | visible, further away | 170 |

  The first idea was 10 m up to 3 km and 50 m beyond. But Piz Corvatsch, the big mountain above the lake, is 4.1 km from the water and would have looked blocky at 50 m.
  - Result (M0): about 137 km² can be seen, in 354 tiles of 1 km.
    - The sailor alone sees 76 km²; the cameras add the rest, mostly higher slopes and side valleys.
    - The view runs along the valley both ways, past Maloja and toward Samedan.
    - 90 % of the visible land is within 22 km, and the farthest is 32 km away (the lines of sight stop at 30 km from each viewpoint).
    - The highest point is the Corvatsch summit area, 4.8 km south-east.
- **Lake Sils** is not sailable. The shoreline rule (M3) stops the board where the water gets too shallow toward it. If you can see it from Silvaplana, it shows as water, for looks only.

### MD5. The lakebed replaces the flat lake surface
In swissALTI3D the lake is a flat surface exactly at water level, and that would flicker against our water. So inside the lake the height grid takes the swissBATHY3D lakebed instead. Where the water is too shallow for the survey (under about 1 m), blend smoothly from the shoreline height to the first surveyed depth. A side benefit: the depth grid tells us where the water is shallow (M3).

### MD6. The map sets the scene, not the physics
The simulation keeps sailing on its `WaterSurface`. The map only:
- sets its own wind, with a map wind config (`Game/maps/silvaplana/wind_silvaplana.tres`) and a new `WindField` made from it. The open water keeps `wind_default.tres`. `tools/matrix.sh` shows how a scene can swap the wind without changing the simulation.
- sets the start position and heading,
- checks the water depth under the board in the scene layer, to stop the board at the shore (main-plan D6: the simulation drives the visuals, and the map doesn't push forces into the physics),
- sets the water colours through the existing shader parameters (`deep_color`, `shallow_color`, ...), without editing the shader.

The waves stay the current `waves_default.tres`, unchanged (team decision 2).

### MD7. Stay out of the physics track's way
Michiel works on the physics in parallel. To avoid getting in each other's way:
- **Don't change on this branch:** `Game/sim/`, the shared config defaults in `Game/config/`, `Game/tests/validation/`, `Game/world/` (the ocean), and `Documentation/PHYSICS_SPEC.md`. The map has its own files under `Game/maps/silvaplana/`, `tools/map/`, `tools/blender/`, `Art/` and `Documentation/MAP_*`.
- **Small, announced changes to shared files** are allowed when the map needs a hook: `main.gd` (choosing the map), `tools/common.sh` (the `BLENDER` variable), `Game/camera/camera_rig.gd` (the far plane, M2), `.gitignore`, `.gitattributes`, `CLAUDE.md`, `REBUILD_PLAN.md`, `PROGRESS_LOG.md`. Keep them small and mention them to Michiel.
- **Merge Michiel's branch** (`feature/physics-sim`, or `main` after pull request #2 is merged) into this branch at the start of every map phase. Then run `tools/test.sh` and `tools/check.sh` before continuing. A merge conflict at the top of `PROGRESS_LOG.md` is expected: keep both entries.
- **Session numbers:** map sessions add "(map track)" after the number in the progress log, so the two tracks don't get confused.
- **Wishes for the physics** (thin air, beaching, a real wind simulation, wind waves) go to Michiel as written requests: the "Later" section below.

## Phase M0: Tools, round-trip test, data download

**Goal:** the tools work on every team PC, the whole route Python → Blender → Godot is proven, and all raw data for the area is on disk, checked, with one command to get it again.

**Tasks:**
- [x] Tools on Max's Windows PC: `tifffile`, `Pillow` and `imagecodecs` installed; QGIS LTR 3.44.14 installed; Blender 4.5.4 runs headless. `tools/common.sh` has `find_blender` next to `find_godot` (`$BLENDER`, then `blender` on the PATH, then the default Windows install), and `tools/blender.sh` runs a Blender script headless with factory settings. The user variable `BLENDER` is set on this PC.
- [ ] The same check on the Linux PC: `blender --background --version` should say 4.5, `git lfs install` should have been run, and `tools/test.sh` should pass after pulling this branch.
- [x] The round-trip test: `tools/blender/roundtrip_test.py` builds a 100 m test square with one hill (top 20 m east, 30 m north, 10 m up) and exports `Game/maps/silvaplana/dev/roundtrip_hill.glb`.
  - `Game/tests/unit/maps/test_map_roundtrip.gd` checks the hill's top lands at game (20, 10, −30): Blender X east → Godot +X, Blender Z up → +Y, Blender Y north → −Z (MD1, D4).
  - `res://maps/silvaplana/dev/roundtrip_view.tscn` shows it for `tools/screenshot.sh`, with a red ball where the top should be.
  - It passes on Windows; the Linux PC is still to check.
- [x] `tools/map/download.py`: asks the STAC API (v1, which publishes SHA-256 checksums) for the newest file per tile, checks every download, skips what is there, and keeps `.map_data/raw/manifest.json`. It downloads in stages, so the big parts wait until a phase needs them:
  - `heights`, 0.5 GB, done: swissALTI3D 0.5 m (25 shore-band tiles, from 2023), the swissBATHY3D zip, and swissALTIRegio 10 m (25 tiles of 10 km: east 2755 to 2805, north 1124 to 1174).
  - `wind`, 40 MB, done: Segl-Maria 10-minute data, 2020 to 2029.
  - `photos-far`, 55 MB, done: SWISSIMAGE 2 m for 332 of the 354 visible tiles. The other 22 are in Italy (Val Bregaglia side), where the Swiss photos stop.
  - `photos-near` (SWISSIMAGE 10 cm for the shore band, 1.1 GB) and `surface` (swissSURFACE3D 0.5 m, 0.34 GB): **not downloaded**. They are needed in M2 and M4, and photos-near is over the 1 GB limit, so the team decides.
    - `photos-near`: Max agreed, downloaded in M2 (Session 40). `surface`: still to download, in M4.
- [x] Shows the sizes before downloading, and refuses more than 1 GB without `--yes`.
- [x] `tools/map/visible.py` (MD4): which land can be seen in the game.
  - It looks from 42 points on the lake and 52 on the shore, at the heights of the sailor and the cameras (MD4).
  - Lines of sight go out in 4096 directions to 30 km, over swissALTIRegio averaged to 50 m, with the Earth's curve and refraction.
  - It writes the visible tiles and a picture, `.map_data/work/visible_map.png`: orange is what the sailor sees, yellow what only the cameras see.
  - Visible land at the edge made the area grow twice, to the west and to the north. Now nothing visible touches the edge.
  - After the first version the team asked for the camera viewpoints: the sailor-only version missed what the orbit and replay cameras see.
- [x] `tools/map/build.sh` and `tools/map/README.md`. A second run downloads nothing. At the end it opens the visibility picture, and a double-clicked window stays open until you press Enter.
- [x] The lake level, from `tools/map/lake_level.py`: **1790.63 m**, the most common swissALTI3D height over the lake (1.42 km² exactly flat). It is in `Game/maps/silvaplana/map_config.tres` (generated) with the origin LV95 2780500 / 1146600. `MapConfig` (`Game/maps/map_config.gd`) converts between LV95 and the game; `Game/tests/unit/maps/test_map_config.gd` checks the lake level, the origin, the weather station (south-west), the village (north-east) and the round trip to the centimetre.
- [x] Git LFS rules in `Game/maps/.gitattributes` and `Art/.gitattributes` (`.glb`, images, `.blend`). `.map_data/` is in `.gitignore`.
- [x] A preview to look at, asked for by Max:
  - `tools/map/preview_data.py` and `tools/blender/build_preview.py` build `.map_data/work/preview/silvaplana_preview.blend`: the shore band at 5 m with the lakebed (deepest 76.8 m, as published), the surroundings at 100 m, the aerial photos, the water, and four cameras.
  - It renders four pictures to `renders/`.
  - It is part of `build.sh`, and is not the game terrain: M1 builds that, in chunks for Godot.
  - The lakebed merge in `preview_data.py` (`readers.paste`) is the first version of MD5.
- [x] BlenderGIS 2.2.10 loads in Blender 4.5.
- [ ] Optional, for exploring: open a few tiles with BlenderGIS and in QGIS, to get a feel for the data.

**Done when:** the round-trip test shows the hill in Godot, and `tools/map/build.sh` downloads everything on a clean checkout without errors (a second run downloads nothing). Done on Windows on 14 October 2026; all 129 unit tests and the check (78 files) pass.
**Stop:** show the team the visibility map and how much was downloaded (701 MB in `.map_data/`; C: has 17 GB free). Ask about the 10 cm photos. (Max agreed, Session 40.)

## Phase M1: Terrain and lakebed in Godot

**Goal:** you can fly a free camera around a grey Silvaplana valley and recognise it.

**Tasks:**
- [x] `tools/map/heights.py`: merges swissALTI3D, swissALTIRegio and swissBATHY3D into height grids (MD4, MD5) and cuts them into chunks. Heights are relative to the lake level, in metres.
  - Four detail levels (MD4). Every 1 km tile is a grid of vertices on its corners.
  - Where two levels meet, the finer tile's edge is put on the straight lines of the coarser one ("stitching"). The step at the seams is 0.06 mm.
  - The lakebed (MD5): swissBATHY3D wherever it has a depth. The 0.16 km² of shallow lake the survey didn't reach is filled in smoothly between the shoreline (0 m) and the first surveyed depths. Every cell there becomes the average of its neighbours, again and again, until nothing changes.
  - Chunks: 80 in all (near 1 km, mid 2 km, far 4 km, distant 8 km), in `.map_data/work/terrain/`, with `chunks.json` and a picture, `zones.png`.
  - The game grid is the shore band's 2 m vertices, 2501 × 2501: `Game/maps/silvaplana/terrain/shore_heights.bin` (12.5 MB, 16-bit) and `shore_heights.json` (scale, offset, position). The game reads it for the shoreline and the depth (M3).
- [x] Python checks: `tools/map/tests/test_heights.py`, 8 checks, all pass.
  - The lake surface in swissALTI3D is 0.005 m from the lake level.
  - Every surveyed lake point is under water, and the water area in the band is 2.89 km².
  - The deepest point is 76.9 m (published: 77 m).
  - Piz Corvatsch is 3450 m in swissALTIRegio (published: 3451 m). In its 20 m chunk it is 1651 m above the lake.
  - The weather station ground is at 1803.5 m (published: 1804 m), and the camping is 59 m from the water.
  - No holes (NaN), and no cracks between chunks (30,210 shared border vertices, 0 mm apart).
- [x] `tools/blender/build_terrain.py` (MD3): builds the chunk meshes and thins them out with Blender's Decimate (collapse).
  - Thinning keeps 10 % of the triangles near the lake and 35 to 60 % further out. Flat ground goes first. Each chunk's border is locked, so the chunks still meet exactly.
  - Each chunk gets a hidden "skirt" hanging down from its border, so a hairline gap between far-away versions shows ground, not sky.
  - The shading normals come from the height grid, so the light doesn't show the chunk borders.
  - It exports `.glb` to `Game/maps/silvaplana/terrain/` and writes `terrain.tscn`.
  - It renders `.screenshots/terrain_blender.png` (everything) and `terrain_blender_band.png` (the shore band, with the lake in blue).
  - 1.14 million vertices, 49.6 MB of `.glb`, about 1 minute.
  - Thinned mesh against the grid, at 2000 random points of the band: median 3 cm, 95 % within 15 cm, worst 52 cm (on rock).
- [x] `Game/maps/silvaplana/silvaplana.tscn` places all terrain chunks (through the generated `terrain.tscn`). Godot's import made 5 far-away versions (LOD) of every chunk.
  - No `visibility_range` on the terrain: every chunk must stay visible from everywhere (the mountains close the view), and the automatic LOD already makes far chunks cheap. Visibility ranges are for the M4 props.
  - The camera can draw the whole map at about 1,500 fps on Max's PC (RX 6950 XT), at 1280 × 720.
- [x] GUT unit tests, `Game/tests/unit/maps/test_silvaplana_terrain.gd`, 6 tests. They check:
  - the known points of MD1 (church, Piz Corvatsch),
  - the grid heights at the weather station, the camping, the camping's shore, the lake's middle and the village,
  - the meshes against the grid within half a metre at five points (worst 8 cm),
  - that every chunk is in `terrain.tscn` and has LODs.
  - `TerrainGrid` (`Game/maps/terrain_grid.gd`) reads the grid for the game.
- [x] Screenshots from the viewpoints, in `res://maps/silvaplana/dev/terrain_view.tscn`: a free camera (`Game/maps/fly_camera.gd`) and a flat blue stand-in for the lake.
  - The viewpoints: on the water at the launch spot, above Silvaplana village looking south-west, high above the valley from the north-east, and straight down.
  - `.screenshots/m1_<view>.png`, made with `tools/screenshot.sh res://maps/silvaplana/dev/terrain_view.tscn <file> 240 --view=<view>`.
  - Still to do by Max: compare them by eye with map.geo.admin.ch in 3D view. (Max's look after M2, Session 41: the terrain "is really good and nice". The side-by-side comparison is optional now.)

Notes for the next phases:
- Size after M1: `Game/maps/silvaplana/` is 62 MB of the 300 MB budget (49.6 MB of terrain `.glb`, 12.5 MB game grid). The near chunks are 30 MB of that; keeping 7 % instead of 10 % of their triangles would save about 9 MB if M2 needs the room.
- File formats (MD2): the chunk grids for Blender are numpy files in `.map_data/work/terrain/`, and the game grid is a plain 16-bit `.bin`. Godot can't read 16-bit PNGs at full precision (it turns them into 8-bit).
- The "above" view shows holes where nothing is built: land that can't be seen from the game's viewpoints (MD4). That is expected. A replay camera higher than 150 m would need `visible.py` run again with that viewpoint.
- Lake Sils and Lake St. Moritz are flat grey surfaces at their own level for now. Lej da Champfèr has the lakebed (it is in the swissBATHY3D survey of Silvaplanersee) but no water beyond the shore band's northern edge (1149 km). M2/M3 decide how other lakes look.
- The terrain is a bluish light grey in the view, because the sky light is strong. M2 brings the aerial photos and the real light.

**Done when:** tests and the check pass, and the screenshots show the right valley shape, with the lake where it belongs.
**Stop:** Max checks: does it look like Silvaplana from the water? Open the view by double-clicking `tools/play.sh` and choosing 2, or with `tools/play.sh silvaplana`. Keys 1 to 4 are the viewpoints; W A S D, E and Q fly; hold the right mouse button to look around. (Max, Session 41, with the photos of M2: the terrain "is really good and nice".)

## Phase M2: The look

**Goal:** the valley looks like the photos: real colours, the mountains you see from the water, alpine light.

**Tasks:**
- [x] `tools/map/photos.py`: cuts SWISSIMAGE into one texture per chunk, sharpest at the camping and the beach, coarser further away.
  - 8192 px per km (12 cm) on the two tiles of the camping and the launch beach (`near_2780_1147` and `near_2781_1147`: the camping sits on the border between them).
  - 2048 px (0.5 m) on the rest of the shore band, from the 10 cm photos (2025 flight, downloaded after the team's go).
  - 512 px (2 m) up to 8 km, and 128 px (8 m) further away, from the 2 m photos.
  - WebP, 50 MB in all. Godot imports them with mipmaps and graphics-card compression (a `.import` file per photo). The camping photo takes 45 MB of video memory.
  - `tools/map/tests/test_photos.py`, 4 checks: the sizes, the import settings, the photos line up with the lake (water is bluer than land; flipped or shifted by 100 m lines up worse), no black patches.
- [x] Terrain material: `Game/maps/terrain.gdshader` and `MapTerrain` (`Game/maps/map_terrain.gd`, the root of the generated `terrain.tscn`), which gives every chunk its photo.
  - Slope darkening: a vertical cliff is 25 % darker than flat ground.
  - The photos were flown in the morning: the shadows fall to the north-west, so the sun was in the south-east. To avoid two suns lighting the slopes, the game's sun shades the slopes only half as much as usual (`sun_shading` 0.5), and the photo's own light does the rest. Cast shadows stay full.
  - The photos go on in Godot, not in Blender as MD3 first said. Then a new photo doesn't need new meshes, and the shader can do the slope darkening and the light.
- [x] The water, in two steps:
  - **First (Session 40):** alpine lake colours through the game shader's parameters (MD6), in `lake_water.tres`. The colours are measured in the aerial photo: teal blue (sRGB 45, 95, 112); no grid lines on the lake. Max's verdict: "really bad", one flat colour.
  - **Then (Session 41, after research):** the map's own see-through lake water, `Game/maps/lake.gdshader` with `Game/maps/silvaplana/lake.tres`:
    - darker with depth (it reads the depth behind the water, so the real lakebed makes the shallows turquoise: the "lighter shallows" of this task),
    - refraction,
    - a Fresnel mirror,
    - wind ripples drifting downwind,
    - plus the `LakeReflections` probe in `silvaplana.tscn`, so the water mirrors the mountains.
  - It is shown in the terrain view; G switches to the game's water to compare. It costs about 6 % of the frame rate.
  - How it meets the physics' waves in the game is a question for Michiel: request R9 (his shader gets these features, or the waves move into a shared include file). Until then the game's water is unchanged (MD7).
- [x] The far mountains in a light haze: exponential fog, 0.000035 per metre (about 30 % at 10 km), half of it taking the sky's colour. No sea horizon: the mountains close the view, and where nothing is built (only visible from above the game's viewpoints) the sky's lower half has the colour of the haze.
- [x] Sky and sun, in the map scene `silvaplana.tscn`. The map brings its own light (MD6); M3 lets it replace the game's.
  - The sun: mid-July, 15:00 summer time at 46.45° N, 9.8° E. Azimuth 225° (south-west), 59° up, with shadows to 4 km. `test_silvaplana_look.gd` checks it; it caught the sun pointing 37° below the horizon in the first version.
  - The fill light is 60 % sky and 40 % a neutral grey-green, because all sky made the lake and the slopes too blue.
- [x] The camera's far plane: 3 km → 35 km in `Game/camera/camera_rig.gd` (a shared file, a one-line change: mention it to Michiel). The terrain view uses the same near (0.05 m) and far planes; no flickering on the far ridges in the screenshots. The open-water game looks the same (its fog ends at 1.5 km).
- [x] The 22 visible tiles in Italy (and the holes in a chunk) are painted.
  - `photos.py` learns the average photo colour of the Swiss tiles for each height (100 m steps), slope (5°) and lighting by the photo's morning sun. Lakes are left out, because they made flat ground dark blue.
  - It paints that colour, made lighter and darker by the small ridges of the 10 m heights.
  - The seam with the photographed tiles shows up close, but these tiles are 20 to 30 km from the lake and in haze, and they are only seen from the higher camera viewpoints.
- [x] Performance and size.
  - About 1,500 fps at every viewpoint on Max's PC (RX 6950 XT, 1280 × 720, no vsync). Max had to switch off a 100 fps cap in RivaTuner to measure this. The Linux PC is still to measure.
  - Size: `Game/maps/silvaplana/` is 111 MB of 300 MB: 52 MB of meshes, 50 MB of photos, 12.5 MB of game grid.
  - Room left for M4, or for sharper photos along the shore: 4096 px on the 14 near chunks that touch the lake would cost about 35 MB more.

Also in M2:
- **The skirts' shadows:** the skirts (M1) cast long dark bands across the slopes, where a simpler far-away neighbour let them stick out. Each skirt is now a separate mesh in its chunk's `.glb` (`<chunk>_skirt`), and `MapTerrain` switches its shadow off.
- **The terrain view:**
  - It shows the map's own light, and the lake in the lake's colours with the game's water shader (`lake_water.tres`).
  - Its camera has the game camera's near and far planes.
  - `--at=e,n,h --look=e,n,h` starts at any viewpoint.

**Done when:** screenshots from the three viewpoints look right next to real photos of the spot, at 60 fps.
**Stop:** Max checks the look against memory and photos of the spot:
- the colour of the lake from the water,
- the light and the haze,
- the mountains and the shore from the launch, from the village and from above (`tools/play.sh silvaplana`, keys 1 to 4).

Max's look (Session 41): the terrain "is really good and nice"; the first water "is really bad, a plain colour; water is semi-transparent". So the see-through water was built (Session 41). Max's look at the new water (16 October): it works well. Still open: Michiel's answer to R9.

## Phase M3: Sailing on the lake

**Goal:** you launch from the real spot and sail in a Maloja wind until you reach the other shore.

**Tasks:**
- [x] The wind direction (done in Session 37): the Maloja at Segl-Maria comes from **244°** (summers 2020 to 2025, 13:00 to 18:00), very steadily. The lake's long axis would give about 224°. Start with 244° and let Max judge on the water. The method and all numbers: [PHYSICS_REQUESTS_FROM_MAP.md](PHYSICS_REQUESTS_FROM_MAP.md), "The Maloja, measured"; the script is `tools/map/maloja_stats.py`.
  - **Changed by W1 (Session 42):** the 244° is the station's spot turning the wind about 20°. Over the lake the Maloja blows along the lake, from about 222° (WindNinja in stable air; Max, 15 October: "pretty good"). So the weather setting below uses 222°.
- [ ] The weather setting (team decision 4), in `Game/maps/silvaplana/wind_silvaplana.tres`, using only the options `WindConfig` already has:
  - `speed_kt = 16` with `gusts_enabled = true` and `gust_intensity = 0.25`, which gives 12 to 20 knots,
  - `shifts_enabled = true`, with `max_shift_deg` and `shift_period_s` set by feel (start at 10 degrees and 60 seconds),
  - `from_bearing_deg = 222` (the lake's direction, W1; first planned as the station's 244°).

  For reference, the station measures a 12 kt median 10-minute mean, with 1-second gusts 1.55 times the mean (about 19 kt). The 10-minute direction barely moves (median change 2°). The station is on land, though, and the wind on the water is probably stronger (Max: 12 to 22 kt on a competition day, depending on the day). Max tunes the gusts and the shifts by feel, from experience on the water there.

  The map already has a much better wind, `MapWind` (W2 and W3), but the sailing can't use it until W5 connects it to `WindField` (R5, Michiel). Until then M3 uses this `WindConfig` setting (team decision 4).
- [ ] The start spot: the beach at Camping Silvaplana at the north end of the lake (find it on the aerial photo). Start in the water just off the beach, with the board pointing across the wind.
- [ ] The shoreline (MD6): read the water depth under the board from the depth grid. If the water is shallower than the fin (0.38 m) plus a margin, the board stops and the game offers a reset to the start spot. No collision physics. This also keeps you off Lake Sils.
- [ ] The water area: no water may show through on land (the terrain covers the ocean mesh there); the lake surface stays at Y = 0. Watch the land lower than the lake: Lake St. Moritz (22 m lower) and the Inn valley toward Samedan lie below Y = 0, so a flat water plane around the camera would flood them. The look comes from M2: `lake.tres` (see-through) or `lake_water.tres` (the game's shader), depending on Michiel's answer to R9. The lake's water must be on render layer 2, so it mirrors the `LakeReflections` probe.
- [ ] The compass in the HUD shows the real north, and a small map shows the lake outline with the board's position.
- [ ] A menu choice or command-line option to start on the old open water or on Silvaplana.

**Done when:** all existing tests still pass (the physics didn't change), the map loads, and a screenshot from the launch spot shows the board on the water with the right wind direction.
**Stop:** play-test checklist for the team (Max as the local expert):
- Does the launch spot feel like the real one?
- Does the wind come from the right side (from the Maloja end of the lake)?
- Do the gusts and shifts feel like a Maloja afternoon?
- Can you sail the whole lake and back?
- What happens when you sail into the shore: is it clear, and is the reset quick?
- Do the mountains look right while you sail?

## Phase M4: Details

**Goal:** the camping, the beach, the village, the trees and the landmarks that make the spot recognisable. For looks only: nothing here affects the sailing.

**Tasks:**
- [ ] **The camping and the beach**, modelled by hand because no open dataset has tents, beaches or rig-up lawns. Use the 10 cm aerial photo as the floor plan, and Max's notes and photos for heights and colours.
  - The beach where you launch: sand or gravel strip, the water's edge, and boards and rigs lying on the grass.
  - The surf centre building, with board racks.
  - Tents, caravans and camper vans in the camping, as a handful of simple models repeated with `MultiMeshInstance3D`.
  - The paths, the fence, and a few flags that show the wind direction, so you can read the wind from the beach.
  - Real business names and logos are left out unless the owners agree: generic signs only.
  - Made in Blender (MD3): the `.blend` files in `Art/silvaplana/props/`, exported with one command as `.glb` to `Game/maps/silvaplana/props/`. Free CC0 packs (for example Kenney, Quaternius, Poly Haven) are fine for tents, caravans and plants. To place things at their real position, import the 10 cm aerial photo of the beach into Blender as a flat reference image (BlenderGIS can do this).
- [ ] Trees: swissSURFACE3D minus swissALTI3D gives vegetation height. Place simple low-detail trees with `MultiMeshInstance3D` where the forest is in the shore band, sized by that height. Further away the aerial photo is enough.
- [ ] Buildings: Silvaplana and Surlej from swissBUILDINGS3D, low detail, only in the shore band. Version 3.0 comes only as DWG or file geodatabase, and the older 2.0 (2018) also as DXF. Find the easiest route into Blender (QGIS/GDAL conversion, or Blender's DXF import), then export as `.glb` like the props.
- [ ] Landmarks that sailors navigate by: the church of Silvaplana, the Corvatsch cable car station, the bridge, and whatever Max adds to the spot notes.
- [ ] The credits screen with the swisstopo, MeteoSwiss and BAFU lines, and the credits of any CC0 models used.

**Done when:** 60 fps still holds, the map is under 300 MB, and screenshots from the launch beach and the three viewpoints show the camping, the village and the forest.
**Stop:** Max checks: does the beach look like the real one?

## The wind analyser (phases W0 to W4)

Asked for by Max on 14 October 2026: a simulated Maloja (speed, gusts and shifts) that you can **watch in the game**, like the Windfinder map but in 3D over the real terrain, in real time or sped up, to work out tactics for course racing. It is the first part of L1 (the wind patterns, Max's), and it changes nothing in the physics: the sailing keeps its own wind until W5 connects the two with Michiel (R5).

**What it is about:** how the Maloja behaves once it blows (its day, its gusts and shifts, where it is strong or weak), not when it comes.

### Wind decisions

- **WD1. One wind, two users.** The viewer and, later, the sailing ask the same code for the wind at a point and a moment. Otherwise you would see a gust coming and not feel it.
- **WD2. Fixed pattern plus moving weather.** The terrain's effect (where it is stronger, weaker, turned) is computed once, offline, and stored as a grid. The gusts, pulses, shifts and the day's build-up are drawn on top while the game runs, from a seed, so a "day" can be replayed exactly and run at any speed.
- **WD3. Checked against measurements.** The numbers in [MALOJA_WIND_RESEARCH.md](MALOJA_WIND_RESEARCH.md) are the targets: the station statistics, the satellite photos of the lake, and Max's experience on the water. Where they disagree, Max's experience on the water wins over the land station.
- **WD4. Map files only** (MD7): `tools/map/`, `Game/maps/` and `Documentation/`. Nothing in `Game/sim/`.

### Phase W0: Research

**Goal:** know how the Maloja behaves, in numbers the simulation can be checked against.

**Tasks:**
- [x] What is written about it: weather services, an old measurement study (Mörikofer 1938, measured at Sils in 1935), spot guides, glider pilots, race reports.
- [x] Five MeteoSwiss stations along its path (Vicosoprano, Segl-Maria, Piz Corvatsch, Samedan, Bivio), 2014 to 2026: `download.py wind-valley` and `maloja_research.py`. The day, the start and how it travels, day types, gusts, pulses, shifts.
- [x] Sentinel-2 photos of the lake on Maloja afternoons, against calm ones: where the water is rough. `satellite_wind.py`.
- [x] Charts and the document: [MALOJA_WIND_RESEARCH.md](MALOJA_WIND_RESEARCH.md), `maloja_charts.py`.

**Stop:** Max answers the questions at the end of the research document (what he sees on the water). (Max answered questions 1 to 6 on 15 October. Still open: 7, the start; 8, the evening turn; 9, how bright water turns into knots; 10, whether the lee switches shores.)

### Phase W1: The fixed pattern

**Goal:** a map of how the terrain shapes the Maloja over the lake: how much stronger or weaker than average, and how much it is turned, at every point.

**Tasks:**
- [x] WindNinja 4.0.0 (mass-conserving solver) on the terrain from the Maloja pass to St. Moritz (swissALTIRegio at 30 m), for incoming directions 220 to 250° and three kinds of air (stable, slightly stable, neutral), wind 5 m above the ground: `tools/map/windninja_pattern.py`, 12 runs in 2 minutes.
- [x] Compare each run with the satellite's roughness map and the station. Result ([MALOJA_WIND_RESEARCH.md](MALOJA_WIND_RESEARCH.md), "Computed over the terrain"): stable air reproduces the station's direction (the lake gets about 220°, along the lake; the station's spot reads 20° more), but no run reproduces the satellite's strength pattern (correlation 0.18 at best).
- [x] Store the pattern for the game: `Game/maps/silvaplana/wind/maloja_pattern.json` + `.bin` (generated, don't edit), 50 m cells, speed factor and turn. **Decision:** the direction comes from WindNinja (stable, 220°), the strength on Lake Silvaplana from the satellite (10 % rougher = 10 % more wind, an assumption), elsewhere from WindNinja. Checked by `tools/map/tests/test_wind_pattern.py` (6 checks).
- [x] Pictures for Max: `Documentation/images/maloja/pattern_game.png` (what the game uses), `pattern_lake.png` (WindNinja beside the satellite), `pattern_valley.png` (the flow down the valley).
- [x] One run of WindNinja's momentum solver (OpenFOAM, which has inertia), as a check of the fast solver: 52 minutes on a 35 m mesh (`.map_data/work/wind_pattern/runs/momentum_230`). It agrees that the south-east side of the Silvaplana half is weaker, but it can't do stable air and doesn't reproduce the station's turn, so it is not used for the game.

**Stop:** Max checks the picture: are the strong and weak places where he knows them? (Max, 15 October: yes. The weak south-east shore and Sils end, the direction along the lake and the stronger north-west side are right.)

### Phase W2: The viewer

**Goal:** the Windfinder view in 3D: the Silvaplana terrain, white streaks moving with the wind, the water coloured by wind speed.

**Tasks (first version):**
- [x] The wind in the game, one place for both users (WD1): `MapWind` (`Game/maps/wind/map_wind.gd`) answers "what is the air doing at this point, at this time of day?"
  - `WindPattern` reads W1's pattern. Between the 50 m cells it interpolates the wind as an arrow, not as an angle (as `windninja_pattern.py` does).
  - `WindDay` with `Game/maps/silvaplana/wind/maloja_day.tres`: **the average Maloja day**, a stand-in until W3. The station's hourly medians from 10:00 to 21:00 (MALOJA_WIND_RESEARCH.md), times 1.3 on the water (Max: 15 to 18 kt on a medium day when the station shows 12.6). The lake keeps its own direction (222°, the pattern) and turns through the day as much as the station turns from its afternoon 244°: a little right until 16:00, about 18° left by 21:00.
  - At 14:20 the lake's average is 16.9 kt; the pattern spreads that over about 13 to 21 kt on the lake.
  - The shaders compute the same wind on the graphics card (`wind_pattern.gdshaderinc`, from the pattern as a texture). Checked twice: a test samples the texture the way the graphics card does, and a screenshot pixel has exactly the legend's colour for the computed speed (17.4 kt: (65, 140, 230) computed, (65, 139, 230) on the screen).
- [x] A scene in `Game/maps/silvaplana/`: `wind_viewer.tscn`, with the terrain, the lake and two cameras. `tools/play.sh wind`, or double-click `play.sh` and choose 3.
  - The map camera (`TopCamera`, `Game/maps/top_camera.gd`) looks straight down with north up: W A S D or the arrows move, the wheel or E and Q zoom, the right mouse drags the map.
  - The free camera is the terrain view's `FlyCamera`. Tab switches.
- [x] Streaks (`WindStreaks`, `Game/maps/wind/wind_streaks.gd`): 5000 particles moved by the graphics card, each drawn as a short white ribbon along its recent path (Godot's particle trails).
  - **Watchable speed:** faster than the real wind, more the bigger the view, so they cross the screen in about the same time at every zoom: about 110× from 4.5 km up, 28× from 350 m, at least 4× from the water. [ and ] change it; the screen shows the factor.
  - **Also over land:** a little above the ground. They need the ground everywhere the pattern has wind, so `tools/map/wind_ground.py` writes `Game/maps/silvaplana/wind/ground.json` + `.bin` (50 m, generated, 0.35 MB).
  - **Not above the valley:** they fade out above 2100 m, where the W1 pictures stop drawing arrows too: up there the pattern is not the Maloja (a shallow wind, capped by an inversion). They are fainter in light wind (under 8 kt).
  - About 2 pixels wide at every distance. They fly at a quarter of the camera's height (0.3 to 15 m), so seen from the water they lie on the water.
- [x] The wind speed as colour on the water (`wind_speed_water.gdshader`) with a legend (`WindLegend`):
  - **Windfinder's colours** (`WindColors`), as Max asked after his first look: purple for calm, blue, cyan and green up to 23 kt, yellow at 27, brown, red and pink up to 53 kt. The colours were read from a screenshot of Windfinder's legend; the legend is drawn like Windfinder's, with the knots inside the bar. (The first version had one blue, from pale to deep; Max wanted the scale sailors know.)
  - The layer covers the water fully, and the viewer uses plain (linear) tone mapping instead of the map's filmic one. Otherwise the water's colours don't match the legend: filmic brightened and flattened them, so 13 and 19 kt looked the same. The terrain looks a little harsher than in the terrain view.
  - C switches the colours off (the see-through water shows), V the streaks.
- [x] A clock (`WindClock`): Pause/Play and 1×, 10×, 60× (buttons, or Space and 1, 2, 3), and a slider from 10:00 to 21:30. It stops at the end of the day. The wind is worked out from this clock, not the computer's, so any moment can be looked at again (WD2).
- [x] Click a point: an orange marker, and a panel (`WindProbeChart`) with the speed and the direction there over the last 10 minutes, a value every 10 seconds, in two charts (different units, so not one chart with two scales). Move the mouse over a chart to read a moment. The history is computed from the clock, so it is right also after a jump with the slider.
- [x] Start options for screenshots (`--camera=free`, `--at=`, `--look=`, `--top=`, `--time=`, `--probe=`, `--colours=off`, `--streaks=off`, `--paused`), listed at the top of `wind_viewer.gd`.
- [x] Tests: `Game/tests/unit/maps/test_map_wind.gd`, 9 tests: the pattern reads back as written (also at the station), the Maloja blows down the lake from about 222°, the average day, the graphics card's copy of the pattern, the ground, the clock, and the colours.
- [x] Speed: 2.2 ms per frame on the graphics card from above, 2.8 ms with the free camera (Max's RX 6950 XT, 1280 × 720); the streaks cost 0.3 ms.

Notes for W3:
- **The station and the water disagree in the model.** The pattern (WindNinja over land) puts the station's spot at 1.34 × the lake's average, while Max's numbers put the water at 1.3 × the station. So the "station" check of W3 (a simulated Segl-Maria) will read about 1.7 times too much. The pattern's land values are probably too high for a station at 10 m among buildings and trees; W3 has to decide what the simulated station reads.
- The average day is a smooth curve: no start front, the same every day. W3 replaces `maloja_day.tres` with real days. (Postponed by Max on 15 October: W4 first, on the average day.)
- The viewer shows the wind at 5 m above the ground (the pattern's height). How it changes with height comes with W5 (WindField).

**Stop:** Max checks the viewer (`tools/play.sh wind`):
- Can you read the strong and weak places on the water, and do the streaks show the direction you know?
- Is the streak speed comfortable from above and from the free camera (try [ and ])?
- Is the colour scale clear, or would you rather have Windfinder's colours? (Max, 15 October: Windfinder's. Done.)
- Does clicking a point give what you want to know for tactics?
- What is missing before the gusts (W3)? (Max: he can't see any gusts going over the lake. W3 started.)

### Phase W3: Gusts, pulses, shifts and the day

**Goal:** the moving weather on top of the pattern (WD2), matching the research numbers.

**Tasks (first version):**
- [x] **Gusts and lulls, measured on the satellite photos** (Session 43, third version): `WindGusts` (`Game/maps/wind/wind_gusts.gd`), with the Maloja's numbers and their sources in `Game/maps/silvaplana/wind/maloja_gusts.tres`. `MapWind` adds them, and the shaders compute exactly the same.
  - **How it got here.** First version: gust patches born and dying anywhere on the lake. Max: "gusts now come out of nothing and disappear". Second version: patches born upwind, rolling down the lake and growing. Max: "they are still round, it is a front that is wider", "too much difference", "I have the feeling you are guessing a lot". Indeed most of their numbers were estimates, fitted only to the land station's gust factor. So the third version is built on measurements: the 22 satellite photos (`tools/map/gust_shapes.py`; MALOJA_WIND_RESEARCH.md, "Gusts seen from space") and Max's answers (mostly fronts, sometimes lanes; lanes 50 to 100 m wide; the gusts stood out too much against the wind around them). The patch version is kept in `.map_data/work/wind_research/old_versions/`.
  - **What the photos say:** the wind on the lake is one continuous pattern of stronger and lighter areas, as many lulls as gusts, not single gusts on a steady background. Two kinds: fronts across the whole lake (500 to 800 m deep, 1.6 to 1.8 km apart) and lanes along the wind (about 1.8 times as long as wide). The Sils half and the Silvaplana half are the same, and the patches don't grow on the way.
  - **The model:** a smooth random pattern ("noise") in two parts, fronts and lanes, rolling down the lake with the air (`MapWind.travel_m()`) and slowly changing while they roll. Fronts carry 70 % of the variance, lanes 30 %. In knots the spread changes only slowly with the wind (the station's 1-second gust: 1.71 kt + 0.40 × the mean, fitted to the 12 hourly medians); at 12:28 it is 1.8 kt, 12 % of the mean. The sideways ups and downs, which turn the wind, are 0.8 times those along it (turbulence over flat ground, Panofsky and Dutton 1984). A gust adds knots, so it reaches full strength in a weak place too ("the little corner").
  - **Fitted by measuring the model like the photos:** `Game/maps/silvaplana/dev/export_gusts.gd` writes the model on the photos' grid with the photos' sensor noise, and `gust_shapes.py --model` measures it with the same steps (results below). That matters because the analysis can't see all of a front a kilometre long: it partly looks like a tilt and is taken out. So the model's true spread (12 %) is bigger than what the analysis shows (8 %), on the photos as on the model.
  - **Still estimates:** how long a gust lives (its size divided by the wind's spread: 210 s for lanes, 980 s for fronts), how fast they travel (1.1 times the mean wind), and how bright water turns into knots (10 % brighter = 10 % more wind, as in W1; sun-glint theory would give up to 1.7 times more wind for the same brightness).
  - **At one point on the water** (13:00 to 15:00, a value every second): the strongest second in 10 minutes is 1.18 to 1.25 times the mean (the land station: 1.52); a gust of 2 kt or more above the mean comes every 3 minutes or so and lasts about 30 s (Max: "every few minutes for half a minute or more"); the direction swings about 21 to 25° within 10 minutes.
- [x] **The lee along the south-east shore** (Session 43, after Max's look at the third version: the band "has too much wind compared to real life; on competition you have to really avoid it, and only once in every 10 or so there is a gust that is favourable and goes down all the way"). Measured on the photos at 10 m by `tools/map/shore_lee.py` (MALOJA_WIND_RESEARCH.md, "The lee along the south-east shore"); in the game `WindLee` (`Game/maps/wind/wind_lee.gd`) with `Game/maps/silvaplana/wind/shore_lee.json` + `.bin`.
  - The band runs from the Sils end to the north-east bend (Max drew the same), deepest 25 to 100 m from the shore, gone by about 450 m; weaker in the middle around "the little corner"; none north of the bend.
  - Its depth follows the photos' fit: about 10 % in the band at the usual wind, 1.1 % deeper per degree the wind comes from further left, 4.5 % per knot more. So a left shift makes the south-east side much lighter: 6 to 7° to the left, about half the wind is gone 75 m off the shore in the north-east.
  - Only the strongest 1 in 10 gusts get in (`reach_share` in `maloja_gusts.tres`; the photos: about 1 in 8), lift the lee to the open lake's wind, and roll down the band ("goes down all the way").
  - W1 held the photos' average lee, flattened by its smoothing; that part is taken out again (`shore_lee.bin`, second layer), so over time the band averages to the photos.
  - `test_map_wind_lee.gd`, 6 tests. The colour check (graphics card against the game's numbers) passes with the lee: within 1 of 255.
  - Found on the way, not built in: when the wind veers, the lee may switch to the north-west shore (on six photos the south-east band was 4 to 9 % rougher than the north-west one). For Max to check.
- [x] Pulses and shifts (Session 43): the whole lake stronger and lighter (±10, 7 and 5 %) and turned left and right (±6, 4 and 2.5°), each as three slow waves of 13 to 45 minutes, travelling down the lake with the gusts. Together: a spread of about 9 % and 5°, as the station's 10-minute means.
- [ ] The day: start front travelling down the lake (about 15 minutes for the 3 km), build-up, the afternoon, the evening turn to the left; light, medium and strong days. **Postponed** (Max, 15 October 2026): W4 comes first, on the average day (`maloja_day.tres`).
- [ ] A check that a simulated "station" at Segl-Maria gives the measured 10-minute statistics. Not done: the station stands on land, gustier than the water (see the note on the station and the water under W2), and the gusts are now fitted to the water itself.

The model against the photos (`python tools/map/gust_shapes.py --model .map_data/work/wind_research/model_gusts`), every number measured the same way:

| | photos | model |
|---|---|---|
| lanes: the oval where the correlation is 0.3 (lane days; the model's lanes only) | 110 × 56 m | 115 × 61 m |
| fronts: where the across-lake bands' correlation halves (front days; the model's fronts only) | 240 m (per day 120 to 280) | 230 m |
| spread (front days; the whole model) | 8.1 % | 7.9 % |
| share in across-lake bands (front days; the whole model) | 39 % (per day 39 to 45) | 35 % |

Pictures: `Documentation/images/maloja/gust_photos.png` (photos) and `gust_model.png` (the model, the same steps). The model's lanes are rounder spots of 100 to 200 m; the real lanes are finer streaks. That is as far as this kind of noise goes.

Done in Session 43 as well:
- `test_map_wind_gusts.gd`, 12 tests: the random numbers are exact 32-bit arithmetic (as on the graphics card), the noise's spread is 1 everywhere (also on its grid lines, so no rhythm in the gusts), it has no jumps; the gusts keep the mean, add knots also in a weak place, fronts reach across the lake and lanes lie along the wind, they roll down the lake with the air, the sideways part is 0.8 times the part along the wind; the pulses and shifts have the station's size; the same moment always gives the same wind; nothing jumps from one tenth of a second to the next.
- The graphics card and the game compute the same wind, gusts included: `tools/godot.sh --path Game res://maps/silvaplana/wind_viewer.tscn -- --check-colours --time=14:30` compares the water's colour at 33 points with the colour of MapWind's speed: within 1 of 255 at 11:10, 14:30, 16:05 and 19:30.
- The click history takes a value every 2 seconds, to show single gusts.
- Speed, with the lee: 0.6 to 0.8 ms per frame on the graphics card (Max's RX 6950 XT, 1280 × 720, the PC otherwise idle). Earlier measurements of 2 to 3 ms were taken while other calculations ran on the PC.

### Phase W4: Tactics tools

Asked for by Max on 15 October 2026, in two parts: first a **course maker** (W4a), so the team can put any iQFOiL course on the lake by dragging the marks, from templates; then the **tactics tools** on top of it (W4b), which need a course to measure against.

**Sources for the courses:**
- The iQFOiL Notice of Race and Sailing Instructions of the 2026 U23 Worlds in Puck, Addendum A: the course diagrams, the mark order and the side each mark is left on. Added by Max: [Document_146274_20260925081258_en.pdf](Document_146274_20260925081258_en.pdf).
- The [iQFOiL Class Race Management Guideline](https://www.iqfoilclassofficial.org/_files/ugd/297cf0_da903893fa6a436ca1e1a103a1c8b198.pdf) (published 9 August 2023): the distances, angles, gate and line sizes. The Notice of Race gives none of these: the race committee sets them on the day.
- The [iQFOiL Class Racing Policies](https://www.iqfoilclassofficial.org/_files/ugd/297cf0_68270a37800b4a41b4b149cab8d9e5af.pdf) (5 July 2025): course racing above 9 kt, sprints under 15 kt; in the medal series MR1 above 9 kt and the slalom MR2 below.

**Decisions (Max, 15 October 2026):**
- **WD5. The course maker lives in the wind viewer for now.** In the game it may become something else later, so the course code is its own part (`Game/maps/course/`, for every map) and the viewer only hosts it.
- **WD6. Courses are saved in the project**, in `Game/maps/silvaplana/courses/`, so the whole team gets them through git. Positions in Swiss coordinates (LV95), so a course stays where it is whatever happens to the game's origin.
- **WD7. Templates are shapes set to the wind**, as a race committee sets them: mark 1 straight upwind of the start line, at the class's distance for the wind of the moment. Max didn't know the beat length; the class guideline gives it per wind range, so that is the default, and a size in percent makes it smaller (the guideline: "distances should be decreased" for youth fleets and newcomers).

**The class's numbers** (Race Management Guideline 2023), in `Game/maps/course/iqfoil_courses.tres`:

| | Windward-leeward (LG2, LR2) | Trapezoid (O2, I2) |
|---|---|---|
| Mark 1 from the start | 0.90 nm at 10 to 13 kt, 1.00 nm at 13 to 17 kt, 1.05 nm above | 0.85, 0.95 and 1.00 nm |
| The reach | to the finish: 400 to 500 m, 90 to 100° from the wind | mark 1 to 2: 0.7 to 0.8 nm, 80 to 90° (90° under 15 kt) |
| Start line | number of boards × 2.20 m × 3 | the same |
| Gate, finish line | 70 to 80 m, 30 to 40 m | the same |

Sprint slalom (PD3 and SD3, also the medal race MR2) and the medal race MR1 (PM1 and SM1) start on a reach: mark 1 is 600 m from the pin, 90° from the wind. Mark 1 to 2 is 0.40 to 0.50 nm downwind. The slalom legs are 400 m with 25° between them, and MR1's reach to the finish is 400 to 500 m at 90 to 100°. Their start line has no bias, is at least 40 m and about 7 m per board, up to 170 m.

Where the guideline gives a range, the templates take the middle. Not in the guideline, so **estimates**, labelled in the file:
- the leeward gate 150 m upwind of the start line, clear of the starting area (75 m around the line, Sailing Instructions 18.4);
- the trapezoid's outer gate level with the start line, and its reach to the finish (450 m, 120° from the wind): read from the diagram;
- the trapezoid's reach at 90° from the wind: the guideline's 80 to 90° doesn't say from which line it is measured, and 90° is in the range either way;
- MR1's gate: the course racing gate's 70 to 80 m;
- the upwind sprint (US3, US4) has no class distances. Its shape is read from the Notice of Race's diagram, with mark 1 1000 m from the start: the 7-minute target time at the average speed that course racing's distances and 16-minute target time imply.

**Silvaplana, measured** (the shore band's height grid, water at least 0.5 m deep): along the Maloja (222°) the main basin is about 2.8 km of water, and 760 to 1370 m wide. A full windward-leeward course (1852 m to mark 1 at 13 to 17 kt) fits along the lake. The full trapezoid reach (1.3 to 1.5 km across the wind) does not, so its reach has to be shortened, as the guideline allows ("variations depending on the venue").

### Phase W4a: The course maker

**Goal:** put any iQFOiL course on the lake in a minute: pick a template, it appears set to the wind, drag the marks where you want them, save it for the team.

**Tasks (first version, Session 44):**
- [x] The course (`Game/maps/course/`): `Course` holds the marks and the official mark order (written as in the Notice of Race, for example `Start-1-4S/4P-1-4S-Finish`), and works out the legs. `CourseMark` is a mark with its name, position and rounding side; in all ten templates a mark is left on the same side every time. Saved as JSON with LV95 positions.
- [x] The class's numbers with their sources in a resource: `iqfoil_courses.tres` (`CourseRules`).
- [x] Ten templates (`CourseTemplates`): LG2, LR2, O2, I2, US3, US4, PD3, SD3, PM1, SM1. Each is built in the course's own frame (up is upwind) and then turned to the wind.
- [x] Editing in the viewer (`CourseEditor`, with `CoursePanel` and `CourseOverlay`):
  - choose a template: it appears in the middle of the view, squared to the lake's wind of the moment and sized for its strength;
  - drag a mark to move it (a gate moves as a pair, the ends of the start and finish lines one by one); Shift and drag moves the whole course; a click on open water still shows the wind there;
  - Axis: turn the course to a compass direction; "Square to wind" turns it back to the lake's wind now;
  - Size: smaller or bigger than the class's distances, in percent (the gates and lines keep their length);
  - Boards: the number of boards, which sets the start line's length;
  - Undo (Ctrl+Z) and Clear;
  - Save under a name, Load the team's courses;
  - M shows and hides the course.
- [x] On the map: the marks with their names and which way they are rounded, the start and finish lines with the committee and finish boats, and the legs in order with arrows. Each leg is drawn just to the right of its line, so the beats and the runs lie side by side as in the diagrams. It is drawn on the screen over the 3D view (`CourseOverlay`), so it stays the same size at every zoom and works from both cameras; from the free camera, legs that run behind it are cut off.
- [x] The panel lists the legs (length, compass course, angle to the wind now) and warns when a mark is on land or off the map, or a leg crosses land (checked every 10 m on the 2 m shore grid); those marks get a red ring.
- [x] Tests: `test_course.gd` (11: the class's distances per wind range, mark 1 dead upwind, the committee boat on the right looking upwind, the rounding sides against the turns, the mark order, the mirror-image courses, the reaching start, the gates and lines keeping their size when the course is scaled, turning and moving, save and load to the centimetre, the land warnings, and on Silvaplana: a full windward-leeward course fits, the full trapezoid's mark 2 is on land) and `test_course_editor.gd` (7, with made-up mouse and key events: a dragged mark follows the mouse, a gate moves as a pair, Shift and drag moves the whole course, a click away from the marks goes to the wind probe, Ctrl+Z step by step, M, save and load).
- [x] Screenshots of the ten templates on the lake (`.screenshots/w4a_templates_sheet.png`), a close-up of a start, and the free camera low over the water.

Notes:
- **The rounding sides** were read from the diagrams, and a test checks each against the way the course turns there (a board turning right leaves the mark to starboard). It found no disagreement.
- **The cameras** read W A S D directly, so they now ignore the keyboard while a text field (the course name, a number) has it; a click on the map gives the keyboard back.
- **Square to wind** uses the lake's mean wind of the moment (the day's direction, without the moving shifts), as a race committee averages the wind before it sets a course.
- **Speed:** 98 to 102 fps in the screenshot runs with and without a course (their cap); the course costs nothing measurable.
- **Not verified:** how the dragging feels with a real mouse, and whether the panel is easy to use: Max play-tests.

**Added after Max's play-test (16 October): adding marks to a course.** Max: "I would like to add a mark to existing courses"; he chose "drop it on a leg, but it needs to work really well, and if I want I can type it if it won't work how I want".
- [x] **Add mark**, then a click on the water: the new mark goes into the leg drawn nearest to the click (within 60 pixels). Legs are drawn to the right of the way they are sailed, so of a beat and a run on the same line it is the one on the side where the mark is dropped. It also goes into the same leg on the other laps: legs running the same way (within 15°) and close by (at most 40 m further away). Shift: only the leg under the mouse. Away from every leg it is a lone mark, listed as "not in the order yet".
- [x] Before the click, the legs it will go into are lit in yellow, with a pale mark and dashed lines where it will go.
- [x] It is named with the next number (5 after gate 4) and left on the side the course bends round it (a right turn round it is starboard; on the line, port). Example: dropped just south-east of mark 1 on a windward-leeward course, it becomes an offset mark after mark 1 on both laps, left to port.
- [x] **The order can be typed** in the panel, as in the Notice of Race (`Start-1-5-4S/4P-1-5-4S-Finish`; spaces and small letters don't matter). A wrong order is refused with the reason, and the text stays to put right.
- [x] **Click a mark to select it** (yellow ring): rename it (like 1a; also in the order), choose port or starboard, or delete it (also the Delete key; a gate goes as a whole, the start and finish lines stay). Esc deselects or stops adding.
- [x] Tests: 6 more in `test_course.gd` (names, putting into legs, removing, renaming, typing the order, the side) and 7 more in `test_course_editor.gd` (beside a run into both runs, beside a beat into both beats, Shift for one leg, a lone mark typed into the order, Esc, rename, side and delete, a click that only selects is no undo step). Screenshot of the preview: `.screenshots/w4a_add_mark.png`.

**Fixed after Max's look at a 3137 × 1263 window (16 October):** "the UI is not nice for other resolutions, and the drawing of the arrows is wrong on a gate".
- [x] The viewer's panels were placed for 1280 × 720. Now each is anchored to its corner or edge (the course panel and the speed legend at the top right, the clock along the bottom, the wind chart on the left), and the viewer switches its window to Godot's "canvas items" stretch, laid out for 1280 × 720 with more room across in a wider window. Godot then draws the text, lines and panels at the window's full resolution, so they stay sharp. (A first try scaled the panels themselves: Max, "I can count the pixels now, it's ugly".) Only while the viewer runs: the game's own screen settings are unchanged, and the window's are put back when the viewer closes.
- [x] The course panel and the clock bar now have the wind chart's look: dark, see-through, rounded, with room inside.
- [x] The rounding arrows followed nothing: the same three-quarter turn from the top of every mark. Now each comes in beside the mark on the side the board passes (from the leg in), goes round the mark's far side, and leaves pointing along the next leg (`Course.turn_at()`, `CourseOverlay.rounding_arc()`). At a gate the boats come down between the marks and turn outwards, back upwind, as on the diagrams. A test checks it for a gate's two marks and for mark 1.
- [x] Checked: screenshots at 3137 × 1263 and 1280 × 720 (the same as before); `--check-colours` still within 1 of 255 (the course is hidden for it).

**Stop:** Max play-tests (`tools/play.sh wind`):
- Is it easy: pick a template, drag, turn, resize, save, load? (Max, 16 October: yes.)
- Adding marks: does dropping on a leg pick the leg you mean? Is the side right? (Max, 16 October: works well.)
- Do the templates look like the diagrams in the Notice of Race? (Max: yes.)
- Where does the race committee put the course at Silvaplana? Save it as the team's first course. (Max: not important for now.)
- How would a race committee shorten the trapezoid here? (Max: not important for now.)

### Phase W4b: Tactics tools

After W4a, detailed with Max then. First ideas:
- **Lifts and headers relative to the course:** the water coloured by how far the wind is turned left or right of the course axis.
- **The stronger lanes:** the water coloured by the difference from the lake's average wind (also a question from W3's look: are the gusts visible enough in Windfinder's colours?).
- **Laylines** from the marks. They need the iQFOiL's upwind and downwind angles: from Max, or later from the physics.
- **Which side paid** over the last minutes: two imaginary boards sail the left and the right side of the beat through the wind of the last minutes, and the panel shows who got to the mark first.

### W5 (later, with Michiel)

The sailing reads the same wind (R5): `WindField.velocity_at(point)` asks the map's wind.

## Later: big projects, for every spot, with Michiel

Most of these change the physics (`Game/sim/`), so Michiel leads them, on the physics branch and with the physics rules (D8, the validation suite, PHYSICS_SPEC.md). The exception is L1, the wind patterns: Max leads those as part of the map work. They plug into the physics through `WindField`, and Michiel agrees that connection. They are general systems, so every future spot gets them too; Silvaplana is the first test case. The written request to Michiel, with the measured numbers, the sources and suggested interfaces, is [PHYSICS_REQUESTS_FROM_MAP.md](PHYSICS_REQUESTS_FROM_MAP.md):

- **L1. Wind patterns (Max, connected with Michiel):** gusts and lulls that move across the water, shifts, the daily cycle, and less wind under the shores. They are built from the measured Maloja statistics and Max's local knowledge (request R5).
  - Max builds the patterns: the data, the model, and the visible gusts on the water.
  - Michiel makes sure `WindField` can take a pattern per map, and keeps the physics validation green with it.
  - **Status, 16 October 2026: Max's part is mostly built for Silvaplana**, as the wind analyser (W0 to W4). Built:
    - the fixed pattern over the terrain (W1),
    - the gusts and lulls rolling down the lake, the pulses and shifts, and the lee along the south-east shore (W3),
    - the average day (W2).

    All of it is one function, `MapWind.velocity_at(point, time_of_day_s)`, and the wind viewer shows it (`tools/play.sh wind`). Still open:
    - W3: the day types (light, medium, strong) and the start front, postponed by Max;
    - W5: Michiel's part, the connection to `WindField` (R5). Until then the sailing doesn't feel any of this wind.
- **L2. Waves made by the wind** (R6). They wait for the two-body sailor, because the lake chop is the short, steep kind the physics can't handle yet.
- **L3. Mountain-lake physics:** thin air (measured 0.98 kg/m³, 20 % less sail force), fresh water, and running aground on the lakebed (R2 to R4). All of it needs R1 first: a map brings its own air, water and wind settings.
- **L4. Replay and live weather** (R7).
- **L5. Other kiters and windsurfers on the water** (R8).
