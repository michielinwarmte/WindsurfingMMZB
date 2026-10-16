"""Downloads the raw Swiss open data for the Silvaplana map into .map_data/raw/ (never committed).

Documentation/MAP_SILVAPLANA_PLAN.md, M0. The data comes in stages, so nobody downloads
gigabytes before they are needed:

  heights      swissALTI3D 0.5 m (shore band), swissBATHY3D (lakebed), swissALTIRegio 10 m
               (surroundings)                                   about 0.5 GB, needed from M1
  wind         MeteoSwiss Segl-Maria 10-minute data 2020-2029   about 40 MB
  wind-valley  MeteoSwiss 10-minute data 2010 to now of five stations along the Maloja's path
               (silvaplana_area.VALLEY_STATIONS), for the wind research    about 0.4 GB
  photos-far   SWISSIMAGE 2 m for the 1 km tiles visible.py marks as visible   small, M2
  photos-near  SWISSIMAGE 10 cm for the shore band              about 1.1 GB, M2
  surface      swissSURFACE3D 0.5 m for the shore band (trees, buildings)      about 0.3 GB, M4

Usage (from the repo root):
  python tools/map/download.py heights wind      # one or more stages
  python tools/map/download.py photos-near --dry-run   # only show what it would download
  python tools/map/download.py photos-near --yes       # needed when a run is over 1 GB

Every file is checked against the SHA-256 checksum the STAC API publishes, files that are
already there are skipped, and .map_data/raw/manifest.json lists every file with its URL.
"""
import argparse
import hashlib
import json
import re
import sys
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

import silvaplana_area as area

STAC = "https://data.geo.admin.ch/api/stac/v1"
BIG_DOWNLOAD_BYTES = 1_000_000_000
MANIFEST = area.RAW_DIR / "manifest.json"


class RawFile:
    """One file to download: where from, where to, and its published checksum (if any)."""

    def __init__(self, url: str, target: Path, sha256: str | None) -> None:
        self.url = url
        self.target = target
        self.sha256 = sha256
        self.size = 0


def fetch_json(url: str) -> dict:
    with urllib.request.urlopen(url, timeout=60) as response:
        return json.load(response)


def stac_items(collection: str, east_m: tuple[float, float], north_m: tuple[float, float]) -> list[dict]:
    """All STAC items of a collection that touch an LV95 rectangle (follows the pages)."""
    lon0, lat0 = area.lv95_to_wgs84(east_m[0], north_m[0])
    lon1, lat1 = area.lv95_to_wgs84(east_m[1], north_m[1])
    url = f"{STAC}/collections/{collection}/items?bbox={lon0},{lat0},{lon1},{lat1}&limit=100"
    items = []
    while url:
        page = fetch_json(url)
        items += page["features"]
        url = next((link["href"] for link in page.get("links", []) if link.get("rel") == "next"), None)
    return items


def newest_per_tile(items: list[dict]) -> dict[tuple[int, int], dict]:
    """Picks the newest item per tile. Item ids end in _<east km>-<north km>, with a year before."""
    best: dict[tuple[int, int], dict] = {}
    for item in items:
        match = re.search(r"_(\d{4})-(\d{4})$", item["id"])
        if not match:
            continue
        tile = (int(match.group(1)), int(match.group(2)))
        if tile not in best or item["properties"]["datetime"] > best[tile]["properties"]["datetime"]:
            best[tile] = item
    return best


def asset_ending(item: dict, ending: str) -> dict:
    for name, asset in item["assets"].items():
        if name.endswith(ending):
            return asset
    raise KeyError(f"{item['id']} has no asset ending in {ending}")


def checksum_of(asset: dict) -> str | None:
    """The STAC checksum is a multihash: '1220' (SHA-256, 32 bytes) then the hex digest."""
    multihash = asset.get("file:checksum", "")
    return multihash[4:].lower() if multihash.upper().startswith("1220") else None


def tiles_1km(collection: str, ending: str, tiles: list[tuple[int, int]], folder: str) -> list[RawFile]:
    """The newest file per 1 km tile for the given tiles."""
    east_km = [t[0] for t in tiles]
    north_km = [t[1] for t in tiles]
    # Ask for a box a little inside the outer tiles, so neighbouring tiles don't come back.
    items = stac_items(collection, (min(east_km) * 1000 + 50, (max(east_km) + 1) * 1000 - 50),
                       (min(north_km) * 1000 + 50, (max(north_km) + 1) * 1000 - 50))
    newest = newest_per_tile(items)
    files = []
    missing = []
    for tile in tiles:
        if tile not in newest:
            missing.append(f"{tile[0]}-{tile[1]}")
            continue
        asset = asset_ending(newest[tile], ending)
        files.append(RawFile(asset["href"], area.RAW_DIR / folder / Path(asset["href"]).name, checksum_of(asset)))
    if missing:
        # Swiss data stops at the border: tiles in Italy have no file.
        print(f"  note: {collection} has no file for {len(missing)} tile(s), probably outside Switzerland: "
              f"{', '.join(missing)}", file=sys.stderr)
    return files


def stage_heights() -> list[RawFile]:
    files = tiles_1km("ch.swisstopo.swissalti3d", "_0.5_2056_5728.tif", area.shore_tiles(), "swissalti3d")
    bathy = fetch_json(f"{STAC}/collections/ch.swisstopo.swissbathy3d/items/swissbathy3d_silvaplanersee")
    asset = asset_ending(bathy, ".esriasciigrid.zip")
    files.append(RawFile(asset["href"], area.RAW_DIR / "swissbathy3d" / Path(asset["href"]).name, checksum_of(asset)))
    for east_km, north_km in area.regio_tiles():
        item_id = f"swissaltiregio_{east_km}-{north_km}"
        item = fetch_json(f"{STAC}/collections/ch.swisstopo.swissaltiregio/items/{item_id}")
        asset = asset_ending(item, ".xyz.zip")
        files.append(RawFile(asset["href"], area.RAW_DIR / "swissaltiregio" / Path(asset["href"]).name, checksum_of(asset)))
    return files


def stage_wind() -> list[RawFile]:
    item = fetch_json(f"{STAC}/collections/ch.meteoschweiz.ogd-smn/items/{area.WIND_STATION}")
    asset = asset_ending(item, f"_{area.WIND_STATION}_t_historical_2020-2029.csv")
    return [RawFile(asset["href"], area.RAW_DIR / "meteoswiss" / Path(asset["href"]).name, checksum_of(asset))]


def stage_wind_valley() -> list[RawFile]:
    """All valley stations, 2010 to now. The 'recent' file (this year up to yesterday) changes
    every day; delete it to fetch a newer one."""
    files = []
    for station in area.VALLEY_STATIONS:
        item = fetch_json(f"{STAC}/collections/ch.meteoschweiz.ogd-smn/items/{station}")
        for period in ("historical_2010-2019", "historical_2020-2029", "recent"):
            asset = asset_ending(item, f"_{station}_t_{period}.csv")
            files.append(RawFile(asset["href"], area.RAW_DIR / "meteoswiss" / Path(asset["href"]).name,
                                 checksum_of(asset)))
    return files


def stage_photos_near() -> list[RawFile]:
    return tiles_1km("ch.swisstopo.swissimage-dop10", "_0.1_2056.tif", area.shore_tiles(), "swissimage_10cm")


def stage_photos_far() -> list[RawFile]:
    visible = area.WORK_DIR / "visible_tiles.json"
    if not visible.exists():
        raise SystemExit("photos-far needs the list of visible tiles: run tools/map/visible.py first.")
    tiles = [tuple(t) for t in json.loads(visible.read_text())["tiles_1km"]]
    files = []
    # Ask per 10 km block, so the STAC queries stay small.
    blocks: dict[tuple[int, int], list[tuple[int, int]]] = {}
    for tile in tiles:
        blocks.setdefault((tile[0] // 10, tile[1] // 10), []).append(tile)
    for block_tiles in blocks.values():
        files += tiles_1km("ch.swisstopo.swissimage-dop10", "_2_2056.tif", block_tiles, "swissimage_2m")
    return files


def stage_surface() -> list[RawFile]:
    return tiles_1km("ch.swisstopo.swisssurface3d-raster", "_0.5_2056_5728.tif", area.shore_tiles(), "swisssurface3d")


STAGES = {
    "heights": stage_heights,
    "wind": stage_wind,
    "wind-valley": stage_wind_valley,
    "photos-far": stage_photos_far,
    "photos-near": stage_photos_near,
    "surface": stage_surface,
}


def remote_size(url: str) -> int:
    request = urllib.request.Request(url, method="HEAD")
    with urllib.request.urlopen(request, timeout=60) as response:
        return int(response.headers.get("Content-Length", 0))


def sha256_of(path: Path) -> str:
    digest = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def download(raw: RawFile) -> None:
    raw.target.parent.mkdir(parents=True, exist_ok=True)
    partial = raw.target.with_suffix(raw.target.suffix + ".part")
    for attempt in range(3):
        try:
            with urllib.request.urlopen(raw.url, timeout=120) as response, open(partial, "wb") as out:
                while block := response.read(1 << 20):
                    out.write(block)
            break
        except OSError as error:
            if attempt == 2:
                raise
            print(f"    retrying after: {error}")
            time.sleep(3)
    if raw.sha256 and sha256_of(partial) != raw.sha256:
        partial.unlink()
        raise SystemExit(f"Checksum mismatch for {raw.url}: the file was deleted, try again.")
    partial.replace(raw.target)


def load_manifest() -> dict:
    return json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {"files": {}}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("stages", nargs="+", choices=list(STAGES))
    parser.add_argument("--dry-run", action="store_true", help="only list what would be downloaded")
    parser.add_argument("--yes", action="store_true", help="allow a run of more than 1 GB")
    args = parser.parse_args()

    todo: list[RawFile] = []
    for stage in args.stages:
        files = STAGES[stage]()
        missing = [f for f in files if not f.target.exists()]
        for f in missing:
            f.size = remote_size(f.url)
        size = sum(f.size for f in missing)
        print(f"{stage:12s} {len(files):4d} files, {len(files) - len(missing):4d} already here, "
              f"{len(missing):4d} to download ({size / 1e6:,.0f} MB)")
        todo += missing

    total = sum(f.size for f in todo)
    print(f"Total to download: {total / 1e6:,.0f} MB")
    if args.dry_run or not todo:
        return
    if total > BIG_DOWNLOAD_BYTES and not args.yes:
        raise SystemExit("That is more than 1 GB. Check with the team (and the free disk space), then add --yes.")

    manifest = load_manifest()
    for number, raw in enumerate(todo, 1):
        print(f"  [{number}/{len(todo)}] {raw.target.relative_to(area.RAW_DIR)} ({raw.size / 1e6:.1f} MB)")
        download(raw)
        manifest["files"][str(raw.target.relative_to(area.RAW_DIR).as_posix())] = {
            "url": raw.url,
            "sha256": raw.sha256,
            "bytes": raw.target.stat().st_size,
            "downloaded": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        }
        MANIFEST.write_text(json.dumps(manifest, indent=1, sort_keys=True))
    print("Done.")


if __name__ == "__main__":
    main()
