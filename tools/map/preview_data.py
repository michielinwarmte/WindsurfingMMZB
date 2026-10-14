"""Prepares a quick look at the real valley for Blender (tools/blender/build_preview.py).

Not the game terrain (that is M1's job): a preview, so the team can see the data early. It writes
two height grids and two aerial-photo textures that Blender's own Python can read (numpy files
and JPGs) to .map_data/work/preview/:

  near   the shore band (5 x 5 km) at 5 m, from swissALTI3D, with the swissBATHY3D lakebed under
         the water, and the 2 m aerial photos
  far    the surroundings (50 x 50 km) at 100 m, from swissALTIRegio, with the 2 m photos
         shrunk to 20 m per pixel; where there is no Swiss photo (Italy) a grey relief

Run from the repo root, after download.py heights photos-far and lake_level.py:
  python tools/map/preview_data.py
"""
import glob
import json
import warnings

import numpy as np
import tifffile
from PIL import Image

import readers
import silvaplana_area as area
import visible

OUT = area.WORK_DIR / "preview"
NEAR_CELL_M = 5.0
FAR_CELL_M = 100.0
FAR_PHOTO_M = 20.0     # metres per pixel of the far photo
NEAR_PHOTO_M = 2.0
# Where the survey has no depth (water under about 1 m), the preview puts the bottom this far down.
SHALLOW_DEPTH_M = 0.5


def block_mean(heights: np.ndarray, factor: int) -> np.ndarray:
    rows, columns = heights.shape[0] // factor, heights.shape[1] // factor
    blocks = heights[:rows * factor, :columns * factor].reshape(rows, factor, columns, factor)
    with warnings.catch_warnings():
        warnings.simplefilter("ignore", RuntimeWarning)  # blocks without any data simply stay NaN
        return np.nanmean(blocks, axis=(1, 3)).astype(np.float32)


def near_grid(lake_level: float) -> readers.Grid:
    tiles = [readers.read_alti3d_tile(e, n) for e, n in area.shore_tiles()]
    small = [readers.Grid(block_mean(t.heights, int(NEAR_CELL_M / t.cell_m)), t.west_m, t.north_m, NEAR_CELL_M) for t in tiles]
    ground = readers.mosaic(small, NEAR_CELL_M)

    bathy = readers.read_bathy()
    bed = readers.Grid(block_mean(bathy.heights, int(NEAR_CELL_M / bathy.cell_m)), bathy.west_m, bathy.north_m, NEAR_CELL_M)
    # Only below the lake surface: the survey also has a strip of shore, where swissALTI3D is better.
    bed.heights[bed.heights > lake_level - 0.05] = np.nan
    surveyed = readers.paste(ground, bed)
    print(f"near: lakebed pasted into {surveyed:,} cells of 5 m ({surveyed * NEAR_CELL_M ** 2 / 1e6:.2f} km2)")

    # Lake surface the survey didn't reach (shallow water) is still flat at the lake level in
    # swissALTI3D: put the bottom a little lower, so the water covers it.
    flat_lake = np.abs(ground.heights - lake_level) < 0.05
    ground.heights[flat_lake] = lake_level - SHALLOW_DEPTH_M
    return ground


def photo_tile(east_km: int, north_km: int) -> np.ndarray | None:
    files = sorted(glob.glob(str(area.RAW_DIR / "swissimage_2m" / f"swissimage-dop10_*_{east_km}-{north_km}_2_2056.tif")))
    if not files:
        return None
    image = tifffile.imread(files[-1])
    return image[..., :3] if image.ndim == 3 else np.repeat(image[..., None], 3, axis=2)


def photo_mosaic(west_km: int, south_km: int, east_km: int, north_km: int, metres_per_pixel: float,
                 fallback: np.ndarray | None) -> np.ndarray:
    """The 2 m photos of a block of 1 km tiles, scaled to metres_per_pixel. Missing tiles come
    from `fallback` (an RGB image of the same block at the same scale), or stay grey."""
    pixels_per_km = int(round(1000.0 / metres_per_pixel))
    height = (north_km - south_km) * pixels_per_km
    width = (east_km - west_km) * pixels_per_km
    mosaic = fallback.copy() if fallback is not None else np.full((height, width, 3), 128, dtype=np.uint8)
    for e in range(west_km, east_km):
        for n in range(south_km, north_km):
            tile = photo_tile(e, n)
            if tile is None:
                continue
            if tile.shape[0] != pixels_per_km:
                tile = np.asarray(Image.fromarray(tile).resize((pixels_per_km, pixels_per_km), Image.LANCZOS))
            row = (north_km - 1 - n) * pixels_per_km
            column = (e - west_km) * pixels_per_km
            mosaic[row:row + pixels_per_km, column:column + pixels_per_km] = tile
    return mosaic


def main() -> None:
    lake = json.loads((area.WORK_DIR / "lake.json").read_text())
    lake_level = lake["lake_level_m"]
    OUT.mkdir(parents=True, exist_ok=True)

    near = near_grid(lake_level)
    np.save(OUT / "near_heights.npy", near.heights)
    west_km, south_km = int(near.west_m // 1000), int(near.south_m // 1000)
    east_km, north_km = int(near.east_m // 1000), int(near.north_m // 1000)
    Image.fromarray(photo_mosaic(west_km, south_km, east_km, north_km, NEAR_PHOTO_M, None)).save(OUT / "near_photo.jpg", quality=90)
    print(f"near: {near.heights.shape[1]} x {near.heights.shape[0]} heights at {NEAR_CELL_M:.0f} m, "
          f"lowest {np.nanmin(near.heights):.1f} m, highest {np.nanmax(near.heights):.1f} m")

    regio = readers.read_regio()
    far = readers.Grid(block_mean(regio.heights, int(FAR_CELL_M / regio.cell_m)), regio.west_m, regio.north_m, FAR_CELL_M)
    np.save(OUT / "far_heights.npy", far.heights)
    # Grey relief where Switzerland's photos stop, at the photo's scale.
    shaded = visible.relief(block_mean(regio.heights, int(FAR_PHOTO_M / regio.cell_m)), FAR_PHOTO_M)
    fallback = (70 + 150 * shaded).astype(np.uint8)
    fallback = np.dstack([fallback, (fallback * 1.02).clip(0, 255).astype(np.uint8), (fallback * 0.95).astype(np.uint8)])
    far_photo = photo_mosaic(int(far.west_m // 1000), int(far.south_m // 1000), int(far.east_m // 1000),
                             int(far.north_m // 1000), FAR_PHOTO_M, fallback)
    Image.fromarray(far_photo).save(OUT / "far_photo.jpg", quality=88)
    print(f"far: {far.heights.shape[1]} x {far.heights.shape[0]} heights at {FAR_CELL_M:.0f} m, photo {far_photo.shape[1]} x {far_photo.shape[0]} px")

    (OUT / "preview.json").write_text(json.dumps({
        "origin_east_m": lake["origin_east_m"],
        "origin_north_m": lake["origin_north_m"],
        "lake_level_m": lake_level,
        "near": {"west_m": near.west_m, "north_m": near.north_m, "cell_m": NEAR_CELL_M,
                 "heights": "near_heights.npy", "photo": "near_photo.jpg"},
        "far": {"west_m": far.west_m, "north_m": far.north_m, "cell_m": FAR_CELL_M,
                "heights": "far_heights.npy", "photo": "far_photo.jpg"},
    }, indent=1))
    print(f"Wrote {OUT.relative_to(area.REPO_ROOT)}")


if __name__ == "__main__":
    main()
