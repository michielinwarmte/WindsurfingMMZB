"""SWAN on Lake Silvaplana (PH44 stage 4): TU Delft's spectral wave model run on the lake's real
outline and depth, in the Maloja, to check the game's own waves (the SPM law at the 9-ray fetch,
Game/sim/lake_waves.gd). The report: Documentation/reports/waves/swan_silvaplana.md.

What it does, from the repo root:
    python tools/map/swan_silvaplana.py [export] [write] [run] [report] [--cases=...] [--jobs=2]
  (plain python, not -I: the maps need Pillow, which sits in the user's site-packages on Max's PC)
  export  the game's own lake, written by Godot (Game/dev/swan_export.gd): the depth (swissBATHY3D
          at 2 m, the game's depth grid), the map's wind (its pattern and the lee) and the game's
          wave model on one 10 m grid, and the points of the lines down the lake.
          -> .map_data/work/swan/export/
  write   only writes one SWAN input file per case (one folder per case): .map_data/work/swan/runs/<case>/
  run     writes them and runs SWAN in each folder (the input file kept next to the output)
  report  the tables (Markdown, printed and written) and the maps (PNG, Pillow):
          -> .map_data/work/swan/report/ (copy what the report shows into Documentation/)
With no step named it does all three; a case already run is not run again (delete its folder).

SWAN: version 41.51 (swanmodel.sourceforge.io), installed per user in
%LOCALAPPDATA%/Programs/SWAN/41.51 (the report says how); set SWAN_EXE to use another swan.exe.

Every case is SWAN in stationary 2D mode on the 10 m grid with 36 directions and 31 log-spaced
frequencies from 0.3 to 6 Hz (df/f = 0.10, what SWAN's quadruplet approximation is built for),
the default third-generation physics unless the case says otherwise, depth-induced breaking and
JONSWAP bottom friction on, fresh water (1000 kg/m3). A case's name says what differs:
    <wind><kt>_<physics>_<bottom>
    wind:    u = one wind everywhere (the lake's mean at 10 m from the lake's direction), or
             map = the map's own wind (its pattern and the lee: the wind the game's waves use)
    physics: westh (SWAN 41.51's default: van der Westhuysen whitecapping, Yan's wind input),
             komen (Komen et al. 1984, the older default), st6 (Rogers et al. 2012, the manual's
             recommended calibration)
    bottom:  real (swissBATHY3D) or deep (the same outline, 50 m deep everywhere: the bottom's
             effect is the difference)
"""

import argparse
import concurrent.futures
import json
import math
import os
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np

REPO = Path(__file__).resolve().parents[2]
WORK = REPO / ".map_data" / "work" / "swan"
EXPORT = WORK / "export"
RUNS = WORK / "runs"
REPORT = WORK / "report"
SWAN_EXE = Path(os.environ.get("SWAN_EXE", Path(os.environ.get("LOCALAPPDATA", "")) / "Programs" / "SWAN" / "41.51" / "swan.exe"))

KTS = [12, 18, 24]
KNOT_MS = 0.514444
G = 9.81
# The spectral grid (see the top).
DIRECTIONS = 36
F_LOW_HZ = 0.3
F_HIGH_HZ = 6.0
FREQUENCIES = 31
DEEP_M = 50.0

PHYSICS = {
    "westh": "GEN3 WESTH",
    "komen": "GEN3 KOMEN",
    # The manual's recommended ST6 line (swanuse.pdf, GEN3), with the swell dissipation it asks for.
    "st6": "GEN3 ST6 2.8E-6 3.5E-5 4.0 4.0 UP HWANG VECTAU U10PROXY 32.0 AGROW\nSSWELL ZIEGER",
}

DEFAULT_CASES = (
    [f"u{kt}_westh_real" for kt in KTS]
    + [f"u{kt}_westh_deep" for kt in KTS]
    + [f"map{kt}_westh_real" for kt in KTS]
    + [f"u{kt}_komen_real" for kt in KTS]
    + [f"u{kt}_st6_real" for kt in KTS]
)

# The output fields (SWAN's names) written as one file each.
FIELDS = ["HSIGN", "TPS", "RTP", "TM01", "TM02", "DIR", "DSPR", "DEPTH", "WLEN", "STEEPNESS", "QB"]


# ------------------------------------------------------------------ the game's lake

def run_export(godot: str) -> None:
    """Writes the game's lake with Godot (Game/dev/swan_export.gd)."""
    EXPORT.mkdir(parents=True, exist_ok=True)
    command = ["bash", str(REPO / "tools" / "godot.sh"), "--headless", "--path", "Game", "-s", "res://dev/swan_export.gd",
               "--", f"--out={EXPORT}"]
    env = dict(os.environ)
    if godot:
        env["GODOT"] = godot
    print("export:", " ".join(command))
    subprocess.run(command, cwd=REPO, env=env, check=True)


def load_export() -> dict:
    meta = json.loads((EXPORT / "meta.json").read_text())
    rows, columns = meta["rows"], meta["columns"]

    def grid(name: str) -> np.ndarray:
        return np.fromfile(EXPORT / name, dtype="<f4").reshape(rows, columns)

    lake = {"meta": meta, "depth": grid("depth.f32"), "turn": grid("wind_turn.f32")}
    for kt in KTS:
        for part in ["wind_factor", "game_hs", "game_tp", "game_fetch", "game_wind"]:
            lake[f"{part}_{kt}"] = grid(f"{part}_{kt}.f32")
    return lake


# ------------------------------------------------------------------ SWAN's input

def parse_case(name: str) -> dict:
    wind_kt, physics, bottom = name.split("_")
    wind = "map" if wind_kt.startswith("map") else "u"
    kt = int(wind_kt[len(wind):])
    return {"name": name, "wind": wind, "kt": kt, "physics": physics, "bottom": bottom}


def write_case(lake: dict, case: dict) -> Path:
    meta = lake["meta"]
    folder = RUNS / case["name"]
    folder.mkdir(parents=True, exist_ok=True)
    rows, columns, cell = meta["rows"], meta["columns"], meta["cell_m"]
    x0, y0 = meta["x0_m"], meta["y0_m"]
    depth = lake["depth"].astype(np.float64).copy()
    if case["bottom"] == "deep":
        depth[depth > 0.0] = DEEP_M
    # Rows from the south, each from west to east: SWAN's layout 3 (lower-left corner first).
    np.savetxt(folder / "bottom.txt", depth, fmt="%.2f")
    wind_ms = case["kt"] * KNOT_MS
    from_deg = meta["from_deg"]
    lines = [
        f"PROJECT 'Silvaplana' '{case['name'][:16]}'",
        f"$ Lake Silvaplana in the Maloja: written by tools/map/swan_silvaplana.py from the game's lake (Game/dev/swan_export.gd).",
        f"$ Wind {case['kt']} kt at 10 m ({wind_ms:.3f} m/s) from {from_deg:.2f} deg; {case['wind']} wind; {case['physics']} physics; {case['bottom']} bottom.",
        "SET LEVEL=0. DEPMIN=0.05 RHO=1000. NAUTICAL",
        "MODE STATIONARY TWODIMENSIONAL",
        "COORDINATES CARTESIAN",
        f"CGRID REGULAR {x0:.1f} {y0:.1f} 0. {(columns - 1) * cell:.1f} {(rows - 1) * cell:.1f} {columns - 1} {rows - 1} &",
        f"      CIRCLE {DIRECTIONS} {F_LOW_HZ} {F_HIGH_HZ} {FREQUENCIES}",
        f"INPGRID BOTTOM REGULAR {x0:.1f} {y0:.1f} 0. {columns - 1} {rows - 1} {cell:.1f} {cell:.1f}",
        "READINP BOTTOM 1. 'bottom.txt' 3 0 FREE",
    ]
    if case["wind"] == "map":
        factor = lake[f"wind_factor_{case['kt']}"].astype(np.float64)
        speed = wind_ms * factor
        to_rad = np.radians(from_deg + lake["turn"].astype(np.float64) + 180.0)
        u = speed * np.sin(to_rad)
        v = speed * np.cos(to_rad)
        with open(folder / "wind.txt", "w") as out:
            np.savetxt(out, u, fmt="%.3f")
            np.savetxt(out, v, fmt="%.3f")
        lines += [
            f"INPGRID WIND REGULAR {x0:.1f} {y0:.1f} 0. {columns - 1} {rows - 1} {cell:.1f} {cell:.1f}",
            "READINP WIND 1. 'wind.txt' 3 0 FREE",
        ]
    else:
        lines.append(f"WIND {wind_ms:.3f} {from_deg:.2f}")
    lines += [
        PHYSICS[case["physics"]],
        "BREAKING",
        "FRICTION JONSWAP",
        # The default absolute criterion (5 mm) is too coarse for 5 to 25 cm waves.
        "NUMERIC STOPC 0.0005 0.005 0.002 99.5 STATIONARY 80",
    ]
    for field in FIELDS:
        lines.append(f"BLOCK 'COMPGRID' NOHEADER '{field.lower()}.txt' LAYOUT 3 {field}")
    points = line_points(meta, case["kt"])
    with open(folder / "points.txt", "w") as out:
        for point in points:
            out.write(f"{point['x']:.2f} {point['y']:.2f}\n")
    lines += [
        "POINTS 'LINE' FILE 'points.txt'",
        "TABLE 'LINE' HEADER 'points.tbl' XP YP DEP HSIGN TPS RTP TM01 TM02 DIR DSPR WIND",
        "SPECOUT 'LINE' SPEC1D ABS 'points.sp1'",
        "COMPUTE",
        "STOP",
    ]
    (folder / f"{case['name']}.swn").write_text("\n".join(lines) + "\n")
    return folder


def line_points(meta: dict, kt: int) -> list:
    """The points of the lines (the middle one first), as the export gives them for this wind."""
    tag = f"{kt}"
    return meta["lines"][f"middle_{tag}"] + meta["lines"][f"start_{tag}"]


def run_case(lake: dict, name: str, threads: int) -> str:
    case = parse_case(name)
    folder = RUNS / name
    if (folder / "hsign.txt").exists() and (folder / "norm_end").exists():
        return f"{name}: already run"
    folder = write_case(lake, case)
    shutil.copyfile(folder / f"{name}.swn", folder / "INPUT")
    env = dict(os.environ)
    env["OMP_NUM_THREADS"] = str(threads)
    with open(folder / "swan_stdout.txt", "w") as log:
        result = subprocess.run([str(SWAN_EXE)], cwd=folder, env=env, stdout=log, stderr=subprocess.STDOUT)
    if (folder / "PRINT").exists():
        shutil.copyfile(folder / "PRINT", folder / f"{name}.prt")
    ok = (folder / "norm_end").exists()
    return f"{name}: SWAN exit {result.returncode}, {'normal end' if ok else 'NO normal end (see the .prt file)'}"


# ------------------------------------------------------------------ SWAN's answer

def read_field(name: str, field: str, shape: tuple) -> np.ndarray:
    values = np.loadtxt(RUNS / name / f"{field.lower()}.txt").reshape(shape)
    return values


def bilinear(grid: np.ndarray, meta: dict, x: float, y: float) -> float:
    fx = (x - meta["x0_m"]) / meta["cell_m"]
    fy = (y - meta["y0_m"]) / meta["cell_m"]
    i, j = int(math.floor(fx)), int(math.floor(fy))
    tx, ty = fx - i, fy - j
    corners = grid[j:j + 2, i:i + 2]
    return float((corners[0, 0] * (1 - tx) + corners[0, 1] * tx) * (1 - ty) + (corners[1, 0] * (1 - tx) + corners[1, 1] * tx) * ty)


def spm(wind_ms: float, fetch_m: float) -> tuple:
    """The game's SPM law (WindWaves.significant_height_m, peak_period_s): JONSWAP with U10."""
    if wind_ms <= 0 or fetch_m <= 0:
        return 0.0, 0.0
    number = G * fetch_m / wind_ms ** 2
    hs = min(0.0016 * math.sqrt(number), 0.2433) * wind_ms ** 2 / G
    tp = min(0.286 * number ** (1 / 3), 8.134) * wind_ms / G
    return hs, tp


def cem(wind_ms: float, fetch_m: float) -> tuple:
    """The CEM 2002 law (WindWaves.significant_height_cem_m, peak_period_cem_s)."""
    if wind_ms <= 0 or fetch_m <= 0:
        return 0.0, 0.0
    u_star = math.sqrt(0.001 * (1.1 + 0.035 * wind_ms)) * wind_ms
    number = G * fetch_m / u_star ** 2
    hs = min(0.0413 * math.sqrt(number), 211.5) * u_star ** 2 / G
    tp = min(0.651 * number ** (1 / 3), 239.8) * u_star / G
    return hs, tp


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("steps", nargs="*", default=["export", "run", "report"])
    parser.add_argument("--cases", default=",".join(DEFAULT_CASES))
    parser.add_argument("--jobs", type=int, default=2, help="SWAN runs side by side (keep it low: other work shares the PC)")
    parser.add_argument("--threads", type=int, default=2, help="OpenMP threads per SWAN run")
    parser.add_argument("--godot", default=os.environ.get("GODOT", ""))
    args = parser.parse_args()
    if "export" in args.steps and not (EXPORT / "meta.json").exists():
        run_export(args.godot)
    lake = load_export()
    if "write" in args.steps:
        for name in [name for name in args.cases.split(",") if name]:
            print("written:", write_case(lake, parse_case(name)))
    if "run" in args.steps:
        if not SWAN_EXE.exists():
            sys.exit(f"SWAN not found at {SWAN_EXE} (set SWAN_EXE)")
        names = [name for name in args.cases.split(",") if name]
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
            for message in pool.map(lambda name: run_case(lake, name, args.threads), names):
                print(message, flush=True)
    if "report" in args.steps:
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        import swan_report  # the tables and maps (tools/map/swan_report.py)
        swan_report.make(lake, [name for name in args.cases.split(",") if name])


if __name__ == "__main__":
    main()
