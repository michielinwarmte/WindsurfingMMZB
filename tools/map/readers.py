"""Readers for the raw swisstopo files in .map_data/raw/, shared by the tools/map scripts.

Every reader returns a Grid: a 2D numpy array of heights (metres above sea level, NaN where
there is no data) plus where it lies in LV95. Row 0 is the NORTH edge, as in the files.
"""
import glob
import io
import zipfile
from pathlib import Path

import numpy as np
import tifffile

import silvaplana_area as area


class Grid:
    """Heights on a regular grid. west_m/north_m are the outer corner of the first cell."""

    def __init__(self, heights: np.ndarray, west_m: float, north_m: float, cell_m: float) -> None:
        self.heights = heights
        self.west_m = west_m
        self.north_m = north_m
        self.cell_m = cell_m

    @property
    def east_m(self) -> float:
        return self.west_m + self.heights.shape[1] * self.cell_m

    @property
    def south_m(self) -> float:
        return self.north_m - self.heights.shape[0] * self.cell_m

    def cell_of(self, east_m: float, north_m: float) -> tuple[int, int]:
        """(row, column) of the cell that contains an LV95 point."""
        return int((self.north_m - north_m) // self.cell_m), int((east_m - self.west_m) // self.cell_m)

    def height_at(self, east_m: float, north_m: float) -> float:
        row, column = self.cell_of(east_m, north_m)
        return float(self.heights[row, column])


def read_alti3d_tile(east_km: int, north_km: int) -> Grid:
    """One swissALTI3D 0.5 m tile (the newest one downloaded)."""
    pattern = str(area.RAW_DIR / "swissalti3d" / f"swissalti3d_*_{east_km}-{north_km}_0.5_*.tif")
    files = sorted(glob.glob(pattern))
    if not files:
        raise FileNotFoundError(f"No swissALTI3D tile {east_km}-{north_km}: run tools/map/download.py heights")
    with tifffile.TiffFile(files[-1]) as tif:
        geo = tif.geotiff_metadata
        heights = tif.pages[0].asarray().astype(np.float32)
    scale = geo["ModelPixelScale"]
    tiepoint = geo["ModelTiepoint"]
    heights[heights < -1000] = np.nan
    return Grid(heights, tiepoint[3], tiepoint[4], scale[0])


def mosaic(grids: list[Grid], cell_m: float) -> Grid:
    """Pastes grids with the same cell size into one grid covering all of them."""
    west = min(g.west_m for g in grids)
    north = max(g.north_m for g in grids)
    east = max(g.east_m for g in grids)
    south = min(g.south_m for g in grids)
    rows = int(round((north - south) / cell_m))
    columns = int(round((east - west) / cell_m))
    heights = np.full((rows, columns), np.nan, dtype=np.float32)
    for g in grids:
        row = int(round((north - g.north_m) / cell_m))
        column = int(round((g.west_m - west) / cell_m))
        h, w = g.heights.shape
        target = heights[row:row + h, column:column + w]
        has_data = ~np.isnan(g.heights)
        target[has_data] = g.heights[has_data]
    return Grid(heights, west, north, cell_m)


def paste(into: Grid, source: Grid) -> int:
    """Copies source's values (not its NaNs) into the part of `into` they overlap. Both grids
    must have the same cell size and lie on the same cell boundaries. Returns the cells copied."""
    cell = into.cell_m
    west = max(into.west_m, source.west_m)
    east = min(into.east_m, source.east_m)
    north = min(into.north_m, source.north_m)
    south = max(into.south_m, source.south_m)
    if west >= east or south >= north:
        return 0
    rows = int(round((north - south) / cell))
    columns = int(round((east - west) / cell))
    into_row, into_column = int(round((into.north_m - north) / cell)), int(round((west - into.west_m) / cell))
    source_row, source_column = int(round((source.north_m - north) / cell)), int(round((west - source.west_m) / cell))
    target = into.heights[into_row:into_row + rows, into_column:into_column + columns]
    values = source.heights[source_row:source_row + rows, source_column:source_column + columns]
    has_data = ~np.isnan(values)
    target[has_data] = values[has_data]
    return int(has_data.sum())


def read_bathy() -> Grid:
    """The swissBATHY3D lakebed of Silvaplanersee, 1 m: absolute heights of the lake floor."""
    files = sorted(glob.glob(str(area.RAW_DIR / "swissbathy3d" / "*silvaplanersee*.zip")))
    if not files:
        raise FileNotFoundError("No swissBATHY3D zip: run tools/map/download.py heights")
    grids = []
    with zipfile.ZipFile(files[-1]) as archive:
        for name in sorted(n for n in archive.namelist() if n.endswith(".asc")):
            grids.append(_read_ascii_grid(archive.read(name).decode("ascii")))
    return mosaic(grids, 1.0)


def _read_ascii_grid(text: str) -> Grid:
    """An ESRI ASCII grid: six header lines, then the rows from north to south."""
    lines = text.split("\n", 6)
    header = {line.split()[0].lower(): float(line.split()[1]) for line in lines[:6]}
    columns, rows, cell = int(header["ncols"]), int(header["nrows"]), header["cellsize"]
    values = np.array(lines[6].split(), dtype=np.float32).reshape(rows, columns)
    values[values == header["nodata_value"]] = np.nan
    # xllcorner/yllcorner is the outer south-west corner of the grid.
    return Grid(values, header["xllcorner"], header["yllcorner"] + rows * cell, cell)


def read_regio() -> Grid:
    """The swissALTIRegio 10 m surroundings, all tiles of silvaplana_area.REGIO_TILES as one grid.
    The text files are slow to read, so the result is cached in .map_data/work/."""
    cache = area.WORK_DIR / "swissaltiregio_10m.npz"
    tiles = np.array(area.regio_tiles())
    if cache.exists():
        data = np.load(cache)
        if "tiles" in data and np.array_equal(data["tiles"], tiles):
            return Grid(data["heights"], float(data["west"]), float(data["north"]), 10.0)
    grids = []
    for east_km, north_km in area.regio_tiles():
        files = sorted(glob.glob(str(area.RAW_DIR / "swissaltiregio" / f"swissaltiregio_{east_km}-{north_km}_*.xyz.zip")))
        if not files:
            raise FileNotFoundError(f"No swissALTIRegio tile {east_km}-{north_km}: run tools/map/download.py heights")
        with zipfile.ZipFile(files[-1]) as archive:
            text = archive.read(archive.namelist()[0]).decode("ascii")
        grids.append(_read_xyz_10m(text, east_km * 1000.0, (north_km + 10) * 1000.0))
    result = mosaic(grids, 10.0)
    area.WORK_DIR.mkdir(parents=True, exist_ok=True)
    np.savez(cache, heights=result.heights, west=result.west_m, north=result.north_m, tiles=tiles)
    return result


def _read_xyz_10m(text: str, west_m: float, north_m: float) -> Grid:
    """An XYZ file of cell centres every 10 m inside a 10 km tile."""
    values = np.array(text.split("\n", 1)[1].split(), dtype=np.float64).reshape(-1, 3)
    heights = np.full((1000, 1000), np.nan, dtype=np.float32)
    rows = ((north_m - values[:, 1]) // 10.0).astype(int)
    columns = ((values[:, 0] - west_m) // 10.0).astype(int)
    inside = (rows >= 0) & (rows < 1000) & (columns >= 0) & (columns < 1000)
    heights[rows[inside], columns[inside]] = values[inside, 2]
    return Grid(heights, west_m, north_m, 10.0)
