"""Checks of the photo textures made by tools/map/photos.py (MAP_SILVAPLANA_PLAN.md, M2).

Plain checks with assert, no test framework needed. Run from the repo root, after photos.py:
  python tools/map/tests/test_photos.py
It prints one line per check and exits with an error if any check fails.
"""
import json
import sys
import traceback
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import photos  # noqa: E402
import silvaplana_area as area  # noqa: E402

TERRAIN = area.WORK_DIR / "terrain"
PHOTOS = area.GAME_MAP_DIR / "terrain" / "photos"
GAME_TERRAIN = area.GAME_MAP_DIR / "terrain"


def chunks() -> list[dict]:
    return json.loads((TERRAIN / "chunks.json").read_text())["chunks"]


def check_every_chunk_has_its_photo() -> str:
    for chunk in chunks():
        path = PHOTOS / f"{chunk['name']}.webp"
        assert path.exists(), f"no photo for {chunk['name']}"
        per_km = photos.SHARP_CHUNKS.get(chunk["name"], photos.PIXELS_PER_KM[chunk["zone"]])
        expected = int(chunk["size_m"] // 1000) * per_km
        with Image.open(path) as image:
            assert image.size == (expected, expected), f"{path.name} is {image.size}, expected {expected} px"
    return f"{len(chunks())} photos, each the expected size"


def check_godot_makes_mipmaps_and_compresses() -> str:
    # Without mipmaps far terrain shimmers; without compression the 8192 px photos take 4 times
    # the graphics memory.
    for chunk in chunks():
        settings = (PHOTOS / f"{chunk['name']}.webp.import").read_text()
        assert "mipmaps/generate=true" in settings, f"{chunk['name']}: no mipmaps"
        assert "compress/mode=2" in settings, f"{chunk['name']}: not compressed for the graphics card"
    return "every photo is imported with mipmaps and graphics-card compression"


def blueness_contrast(photo: np.ndarray, ground: np.ndarray) -> float:
    """How much bluer the photo is over deep water than over land. Water in the photo is teal
    (blue well above red); forest, meadows and rock are not."""
    blueness = photo[..., 2].astype(float) - photo[..., 0].astype(float)
    return float(blueness[ground < -3.0].mean() - blueness[ground > 3.0].mean())


def check_photos_line_up_with_the_lake() -> str:
    # Where the heights say deep water, the photo must show water. A photo that is flipped or
    # shifted by 100 m lines up worse, so this catches mistakes in the placement.
    meta = json.loads((GAME_TERRAIN / "shore_heights.json").read_text())
    grid = np.fromfile(GAME_TERRAIN / meta["file"], "<u2").reshape(meta["rows"], meta["columns"])
    grid = meta["height_offset_m"] + grid * meta["height_scale_m"]
    results = []
    for name in ("near_2780_1147", "near_2781_1147", "near_2779_1145", "near_2781_1146"):
        east_km, north_km = int(name.split("_")[1]), int(name.split("_")[2])
        with Image.open(PHOTOS / f"{name}.webp") as image:
            photo = np.asarray(image.convert("RGB").resize((500, 500), Image.BOX))
        row = int((meta["north_m"] - (north_km + 1) * 1000) / meta["cell_m"])
        column = int((east_km * 1000 - meta["west_m"]) / meta["cell_m"])
        ground = grid[row:row + 500, column:column + 500]
        right = blueness_contrast(photo, ground)
        flipped = blueness_contrast(photo[::-1], ground)
        shifted = blueness_contrast(np.roll(photo, 50, axis=1), ground)
        assert right > 30.0, f"{name}: the water is hardly bluer than the land ({right:.0f})"
        assert right > flipped + 10.0 and right > shifted + 5.0, \
            f"{name}: lines up as well flipped ({flipped:.0f}) or shifted ({shifted:.0f}) as placed ({right:.0f})"
        results.append(f"{name} {right:.0f}")
    return "water bluer than land by: " + ", ".join(results)


def check_no_black_holes() -> str:
    # Every built tile has a photo or a painted colour: no black (empty) patches.
    darkest = 255.0
    for chunk in chunks():
        with Image.open(PHOTOS / f"{chunk['name']}.webp") as image:
            small = np.asarray(image.convert("RGB").resize((64, 64), Image.BOX)).astype(float)
        darkest = min(darkest, float(small.mean(axis=-1).min()))
    assert darkest > 3.0, f"a chunk has a black patch (darkest {darkest:.0f})"
    return f"darkest 1/64 of any photo: {darkest:.0f} of 255"


def main() -> None:
    checks = [check_every_chunk_has_its_photo, check_godot_makes_mipmaps_and_compresses,
              check_photos_line_up_with_the_lake, check_no_black_holes]
    failed = 0
    for check in checks:
        name = check.__name__.removeprefix("check_").replace("_", " ")
        try:
            print(f"ok    {name}: {check()}")
        except Exception as error:  # report every check, then fail at the end
            failed += 1
            print(f"FAIL  {name}: {error}")
            if not isinstance(error, AssertionError):
                traceback.print_exc()
    print(f"{len(checks) - failed} of {len(checks)} checks passed")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
