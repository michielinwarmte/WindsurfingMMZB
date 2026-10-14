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
| `maloja_stats.py <csv>` | Statistics of the Maloja wind and the air density from MeteoSwiss Segl-Maria. | printed; the results are in `Documentation/PHYSICS_REQUESTS_FROM_MAP.md` |
| `silvaplana_area.py` | Not a step: the areas every script works on (lake, shore band, surroundings). | — |
| `readers.py` | Not a step: reads the raw files into height grids. | — |

`tools/blender/roundtrip_test.py` is the M0 check that Blender → `.glb` → Godot keeps the axes right. Run it with `tools/blender.sh tools/blender/roundtrip_test.py Game/maps/silvaplana/dev/roundtrip_hill.glb`; `Game/tests/unit/maps/test_map_roundtrip.gd` checks the result.

`.map_data/` is never committed. Anyone can rebuild it with `tools/map/build.sh`.

## To look at

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
| `photos-far` | SWISSIMAGE 2 m, 332 of the 354 visible tiles of 1 km (the other 22 are in Italy) | 55 MB |
| `photos-near` | SWISSIMAGE 10 cm, the 25 shore-band tiles | about 1.1 GB, not downloaded yet (M2) |
| `surface` | swissSURFACE3D 0.5 m, the 25 shore-band tiles | about 0.34 GB, not downloaded yet (M4) |

## Credits

Every map built from this data must show: **"Terrain, aerial photos and lakebed: © swisstopo. Wind data: MeteoSwiss. Lake level: BAFU."** The data is free Swiss Open Government Data, and naming the source is the only condition.
