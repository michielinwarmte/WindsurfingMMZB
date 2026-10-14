# Map Plan: Lake Silvaplana (Silvaplanersee), Switzerland

Written 14 October 2026 (Session 37, map track), for the AI sessions doing the work and for the MMZB team reviewing it. Work on the branch `feature/map-silvaplana`. The rules and commands in [CLAUDE.md](../CLAUDE.md) still apply, and so does the "How to use this plan" section of [REBUILD_PLAN.md](REBUILD_PLAN.md): phases in order, tick a box only when it is done and verified, stop at the end of every phase so the team can play-test.

This is a side track next to the main plan. It builds the first real map: Lake Silvaplana in the Upper Engadin, one of the best-known windsurf spots in the Alps, famous for the afternoon Maloja wind.

**Who does what.**
- **Michiel** does the physics (`Game/sim/`): the simulation, and how the board, the sail and the water react to the wind and the waves.
- **Max** does the map, and later the wind patterns that belong to it: the Maloja's daily cycle, its gusts and shifts, and where the wind is strong or weak on the lake (Later L1). Max knows the spot (notes: [SILVAPLANA_SPOT_NOTES.md](SILVAPLANA_SPOT_NOTES.md)).

The wind patterns describe what the air does; the physics decides what the board does with it. They meet at `WindField.velocity_at(point)`, and that connection is agreed with Michiel (requests R1 and R5).

The map track does not change the physics files (MD7). Everything the map needs from the physics is listed under "Later", as a request to Michiel.

The branch starts from `feature/physics-sim` (Phases 1 to 5), because `main` does not have the playable game yet. Merge Michiel's work into this branch regularly (MD7).

## Status

| Phase | What | Status |
|---|---|---|
| M0 | Tools, round-trip test, data download | ✅ Done on Windows (Session 38). The 10 cm photos were agreed and downloaded in M2. Still open: the Linux PC check, and the surface model (M4) |
| M1 | Terrain and lakebed in Godot | ✅ Built on Windows (Session 39). Waiting for Max's check: does it look like Silvaplana from the water? |
| M2 | The look: aerial photo, sky, the mountains you can see | ✅ Built on Windows (Sessions 40 and 41), with see-through lake water in the terrain view. Waiting for Max's check of the look, and for Michiel on R9 (the water in the game) |
| M3 | Sailing on the lake: start spot, one Maloja weather setting, shoreline | ⬜ |
| M4 | Details: camping and beach, village, trees, landmarks | ⬜ |
| Later | Big projects for every spot, with Michiel: wind simulation, wind-driven waves, mountain-lake physics, live weather, other sailors | ⬜ |

## Team decisions (14 October 2026)

1. **Size:** only Lake Silvaplana is sailable, and the map is as small as possible: the lake, a detailed band of shore around it, and further away only what you can see from the water (mountains, slopes), with nice graphics. Lake Sils is not sailable.
2. **Waves:** waves will be made by the wind, as one big general system for every spot (Later L2). Until then the map uses the current waves unchanged.
3. **Repository size:** at most 300 MB of map files. That is enough for the smaller map (MD2).
4. **Weather:** for now one fixed Maloja setting: 12 to 20 knots, with gusts and shifts from the simple options the wind model already has (M3). A realistic wind simulation is a big project for later (Later L1).
5. **Physics:** Michiel makes all physics changes. The map track stays out of the physics files (MD7). Max takes on the wind patterns later (L1), connected to the physics through an interface agreed with Michiel.
6. **Other kiters and windsurfers on the water:** later, nice to have (Later L5).
7. **Local knowledge:** Max knows the spot. His notes are the check for M2 to M4, and for the wind later.

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

**The spot, in numbers.** The lake lies between LV95 east 2779 and 2782 km and north 1145 and 1148.2 km. It is about 3 km long, at about 1791 m above sea level (read the exact level from swissALTI3D in M0). Silvaplana village is at the north-east end (around 2781.1 / 1148.0).

The launch spot is the beach at **Camping Silvaplana** at the north end, with a surf centre. It is one of the three public access points to the lake for water sports. With the Maloja blowing, it is the downwind end of the lake.

The Maloja wind is a thermal valley wind from the south-west (from the Maloja pass, along the valley). Spot guides say it starts around noon and is strongest from 15:00 to 17:00, at typically 16 to 25 knots, and dies around 18:00 to 19:00. Season: June to September.

The station at Segl-Maria (2020 to 2025) confirms the pattern:
- 61 % of summer days have at least 3 hours of Maloja in the afternoon,
- it comes from 244°,
- it builds from 11:00, holds about 12 to 13 kt mean with 19 to 20 kt gusts from 13:00 to 16:00, and fades after 18:00.

The station stands on land, so its speeds are probably lower than on the water. Details: [PHYSICS_REQUESTS_FROM_MAP.md](PHYSICS_REQUESTS_FROM_MAP.md).

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

Everyone on the team uses the same Blender version (4.5 LTS, supported until 2027) so the scripts and the `.blend` files behave the same on every PC. The Linux PC has Blender at `/usr/bin/blender`; check its version.

## Key decisions

### MD1. Swiss coordinates straight into the game, no map projection
Swiss LV95 coordinates are already metres east and north on a flat grid. So the game uses them directly with a fixed origin, and nothing needs to be reprojected:

- game X = LV95 east − `ORIGIN_E`
- game Z = −(LV95 north − `ORIGIN_N`) (north is −Z, main-plan D4)
- game Y = height above sea level − `LAKE_LEVEL_M`, so the lake surface is at Y = 0, where the simulation already puts the water.

Start with the origin at the middle of the lake (around 2780500 / 1146600; M0 fixes the exact numbers). The numbers live in one config resource, `Game/maps/silvaplana/map_config.tres`. A unit test checks that a few known points (Silvaplana church, the weather station, Piz Corvatsch) land in the right game position.

Godot uses 32-bit floats, which are still accurate to about 1 mm 10 km from the origin, so rounding is not a problem at this size.

### MD2. Python prepares the data, Blender builds the 3D, Godot plays it
Each tool does what it is good at:

1. **Python** (`tools/map/*.py`) downloads the raw data and turns it into clean grids and images: height grids as 16-bit PNG or EXR, photos as JPG or WebP, cut into chunks. It is repeatable and testable, and the AI can run it.
2. **Blender** turns those grids into 3D: terrain meshes made by a script (MD3), and props made by hand (M4). Everything leaves Blender as `.glb`.
3. **Godot** imports the `.glb` files and plays them. It never reads the raw data.

Details:
- Python packages: only `numpy`, `tifffile` (reads the GeoTIFFs, with `imagecodecs` for their compression) and `Pillow` (writes images). No GDAL or rasterio: we need no reprojection (MD1), and they are hard to install on Windows.
- Raw downloads go to `.map_data/raw/`, which is never committed (add it to `.gitignore`). Every download is listed in `.map_data/manifest.json` with its URL and date, and is checked against the checksum the STAC API publishes.
- The game-ready files go to `Game/maps/silvaplana/`. They are committed through **Git LFS** (add `.gitattributes` rules for `.glb`, the image types and `.blend` files).
- Anyone can rebuild everything with one command: `tools/map/build.sh` (download if missing, prepare, then run the Blender scripts headless).

**The 300 MB budget.** A rough estimate for the small map is 100 to 200 MB: aerial photo textures of the shore band, thinned-out terrain meshes, and props. So 300 MB is enough. Measure it at the end of every phase.

Watch the Git LFS quota. GitHub's free quota for the account that owns the repository is 10 GB of storage and 10 GB of downloads a month. Every committed version of a big file counts toward the storage, so commit rebuilt map files at the end of a phase, not after every small change.

### MD3. The terrain and the props come from Blender as `.glb`
glTF (`.glb`) is the 3D format Godot works with best: meshes, materials, textures and positions come across, and on import Godot builds simpler versions of every mesh for far away (automatic LOD). The main plan's Phase 6 uses the same route for the board and the sail.

- **Terrain, made by a script.** `tools/blender/build_terrain.py` runs headless (`blender --background --python ...`). It reads the height grids from Python, builds one mesh per chunk, puts the aerial photo on it, and exports the chunks as `.glb`. The AI can run it and check its own work: Blender renders a preview image, and `tools/screenshot.sh` shows the result in the game.
- **Props, made by hand,** with AI help (the AI can write Blender scripts for repetitive work, like placing 40 tents). Camping, beach, surf centre, flags, tents: M4.
- **Never edit generated files by hand.** The script overwrites them on every build. Hand work goes into its own `.blend` files: for example a sculpted beach is a separate mesh that sits on top of the terrain.
- **Sources outside `Game/`.** `.blend` files live in `Art/silvaplana/`, and only the exported `.glb` files go into `Game/maps/silvaplana/`. Godot could import `.blend` files directly, but then every PC and every AI check (`tools/check.sh`) would need Blender, and two Blender versions could produce different results. Exporting `.glb` (`tools/blender/export_props.py`, one command) keeps the game independent of Blender.
- **Meshes are for looks, grids are for the game logic.** The shoreline check and the depth under the board read the Python grids, never the meshes. So a nicer mesh can never change how the board sails.
- **No terrain plugin.** Terrain3D, the best-known Godot terrain plugin, officially supports Godot 4.4 to 4.6, and 4.7 is not confirmed. If the `.glb` terrain is too slow or looks wrong in M2, look at Terrain3D again.

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
**Stop:** show the team the visibility map and how much was downloaded (701 MB in `.map_data/`; C: has 17 GB free). Ask about the 10 cm photos.

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
  - Still to do by Max: compare them by eye with map.geo.admin.ch in 3D view.

Notes for the next phases:
- Size after M1: `Game/maps/silvaplana/` is 62 MB of the 300 MB budget (49.6 MB of terrain `.glb`, 12.5 MB game grid). The near chunks are 30 MB of that; keeping 7 % instead of 10 % of their triangles would save about 9 MB if M2 needs the room.
- File formats (MD2): the chunk grids for Blender are numpy files in `.map_data/work/terrain/`, and the game grid is a plain 16-bit `.bin`. Godot can't read 16-bit PNGs at full precision (it turns them into 8-bit).
- The "above" view shows holes where nothing is built: land that can't be seen from the game's viewpoints (MD4). That is expected. A replay camera higher than 150 m would need `visible.py` run again with that viewpoint.
- Lake Sils and Lake St. Moritz are flat grey surfaces at their own level for now. Lej da Champfèr has the lakebed (it is in the swissBATHY3D survey of Silvaplanersee) but no water beyond the shore band's northern edge (1149 km). M2/M3 decide how other lakes look.
- The terrain is a bluish light grey in the view, because the sky light is strong. M2 brings the aerial photos and the real light.

**Done when:** tests and the check pass, and the screenshots show the right valley shape, with the lake where it belongs.
**Stop:** Max checks: does it look like Silvaplana from the water? Open the view by double-clicking `tools/play.sh` and choosing 2, or with `tools/play.sh silvaplana`. Keys 1 to 4 are the viewpoints; W A S D, E and Q fly; hold the right mouse button to look around.

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

## Phase M3: Sailing on the lake

**Goal:** you launch from the real spot and sail in a Maloja wind until you reach the other shore.

**Tasks:**
- [x] The wind direction (done in Session 37): the Maloja at Segl-Maria comes from **244°** (summers 2020 to 2025, 13:00 to 18:00), very steadily. The lake's long axis would give about 224°. Start with 244° and let Max judge on the water. The method and all numbers: [PHYSICS_REQUESTS_FROM_MAP.md](PHYSICS_REQUESTS_FROM_MAP.md), "The Maloja, measured"; the script is `tools/map/maloja_stats.py`.
- [ ] The weather setting (team decision 4), in `Game/maps/silvaplana/wind_silvaplana.tres`, using only the options `WindConfig` already has:
  - `speed_kt = 16` with `gusts_enabled = true` and `gust_intensity = 0.25`, which gives 12 to 20 knots,
  - `shifts_enabled = true`, with `max_shift_deg` and `shift_period_s` set by feel (start at 10 degrees and 60 seconds),
  - `from_bearing_deg = 244`.

  For reference, the station measures a 12 kt median 10-minute mean, with 1-second gusts 1.55 times the mean (about 19 kt). The 10-minute direction barely moves (median change 2°). The station is on land, though, and the wind on the water is probably stronger. Max tunes the gusts and the shifts by feel, from experience on the water there.
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

## Later: big projects, for every spot, with Michiel

Most of these change the physics (`Game/sim/`), so Michiel leads them, on the physics branch and with the physics rules (D8, the validation suite, PHYSICS_SPEC.md). The exception is L1, the wind patterns: Max leads those as part of the map work. They plug into the physics through `WindField`, and Michiel agrees that connection. They are general systems, so every future spot gets them too; Silvaplana is the first test case. The written request to Michiel, with the measured numbers, the sources and suggested interfaces, is [PHYSICS_REQUESTS_FROM_MAP.md](PHYSICS_REQUESTS_FROM_MAP.md):

- **L1. Wind patterns (Max, connected with Michiel):** gusts and lulls that move across the water, shifts, the daily cycle, and less wind under the shores. They are built from the measured Maloja statistics and Max's local knowledge (request R5).
  - Max builds the patterns: the data, the model, and the visible gusts on the water.
  - Michiel makes sure `WindField` can take a pattern per map, and keeps the physics validation green with it.
- **L2. Waves made by the wind** (R6). They wait for the two-body sailor, because the lake chop is the short, steep kind the physics can't handle yet.
- **L3. Mountain-lake physics:** thin air (measured 0.98 kg/m³, 20 % less sail force), fresh water, and running aground on the lakebed (R2 to R4). All of it needs R1 first: a map brings its own air, water and wind settings.
- **L4. Replay and live weather** (R7).
- **L5. Other kiters and windsurfers on the water** (R8).
