"""Where the Silvaplana map is: the areas every tools/map script works on.

All coordinates are Swiss LV95 (EPSG:2056) in metres: east, north. Heights are metres above
sea level (LN02), as in the swisstopo data. See Documentation/MAP_SILVAPLANA_PLAN.md, MD1 and MD4.
"""
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
RAW_DIR = REPO_ROOT / ".map_data" / "raw"
WORK_DIR = REPO_ROOT / ".map_data" / "work"
GAME_MAP_DIR = REPO_ROOT / "Game" / "maps" / "silvaplana"

# The lake's bounding box (from the swissBATHY3D item), for orientation only.
LAKE_EAST_M = (2_779_050.0, 2_781_970.0)
LAKE_NORTH_M = (1_145_060.0, 1_148_200.0)

# The shore band of MD4: the 1 km tiles named by their south-west corner in km,
# east 2778 to 2782 and north 1144 to 1148 (25 tiles). Full detail here.
SHORE_TILES_EAST_KM = range(2778, 2783)
SHORE_TILES_NORTH_KM = range(1144, 1149)

# The surroundings: the swissALTIRegio 10 km tiles (south-west corners in km) around the lake,
# covering east 2755 to 2805 km and north 1124 to 1174 km. visible.py works out what of this
# can be seen. From the lake you see down the valley both ways: past Maloja to the south-west,
# and toward Samedan to the north-east, so the area reaches about 25 km each way. visible.py
# stops at 30 km; further away the haze hides the land anyway.
REGIO_TILES_EAST_KM = (2755, 2765, 2775, 2785, 2795)
REGIO_TILES_NORTH_KM = (1124, 1134, 1144, 1154, 1164)

# The weather station at the south-west end of the lake (MeteoSwiss Segl-Maria, SIA).
WIND_STATION = "sia"

# Where the land is seen from, for visible.py: (name, on "lake" or "shore", metres above the
# water or the ground there). Only land seen from at least one of these gets built.
# They cover the game's cameras in Game/camera/camera_rig.gd:
#   - the follow camera, about 2 m up behind the board ("sailor"),
#   - the orbit camera and the free camera, up to 60 m from the board ("orbit camera"),
#   - the top-down camera, up to 300 m but looking straight down, so it only sees land close to
#     the board, which the shore band already has.
# Replays will want higher shots and shots from land, so a drone over the lake and cameras on
# the shore are included as well. If the cameras change, change this list and run
# tools/map/build.sh again.
VIEWPOINTS = [
    ("sailor", "lake", 2.0),
    ("orbit camera", "lake", 60.0),
    ("replay drone", "lake", 150.0),
    ("beach camera", "shore", 2.0),
    ("shore drone", "shore", 50.0),
]
# Shore viewpoints stand on land up to this far from the water.
SHORE_VIEW_DISTANCE_M = 300.0


def shore_tiles() -> list[tuple[int, int]]:
    """The 1 km tiles of the shore band as (east_km, north_km) south-west corners."""
    return [(e, n) for e in SHORE_TILES_EAST_KM for n in SHORE_TILES_NORTH_KM]


def regio_tiles() -> list[tuple[int, int]]:
    """The 10 km swissALTIRegio tiles as (east_km, north_km) south-west corners."""
    return [(e, n) for e in REGIO_TILES_EAST_KM for n in REGIO_TILES_NORTH_KM]


def lv95_to_wgs84(east_m: float, north_m: float) -> tuple[float, float]:
    """Swisstopo's approximate formulas (about 1 m accurate): returns (longitude, latitude)
    in degrees. Only used to ask the STAC API for an area; the map itself stays in LV95."""
    y = (east_m - 2_600_000.0) / 1e6
    x = (north_m - 1_200_000.0) / 1e6
    lon = 2.6779094 + 4.728982 * y + 0.791484 * y * x + 0.1306 * y * x * x - 0.0436 * y ** 3
    lat = 16.9023892 + 3.238272 * x - 0.270978 * y * y - 0.002528 * x * x - 0.0447 * y * y * x - 0.0140 * x ** 3
    return lon * 100.0 / 36.0, lat * 100.0 / 36.0
