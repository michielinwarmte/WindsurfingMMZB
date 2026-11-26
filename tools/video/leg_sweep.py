"""Leg frequency x damping, measured on the two things the legs must do at once:
  - the strong-wind gybes on race gear (the reality check's strong_62: 97 l + 5.7 at 24 and 30 kt;
    falls and the time off the plane, the check's own measure), and
  - the lake chop (straight at 12:00, 14:30, 17:00: pitch, knees, speed; reality_sweep's measure).
Each variant is two headless runs through the project's scripts; up to --workers at once.
    python tools/video/leg_sweep.py <repo folder> [--workers=10] [--variants=1.2:0.9,0.4:0.4,...]
        [--default-gear] [--skip-runs]
CSVs in .sim_output/leg_sweep/f<Hz>_z<zeta>_<gybe|chop|matrix>/. Written 26 November 2026 for the
reality fixes (Documentation/reports/reality_fixes/PROGRESS.md). Ten Godots starting at once once
failed to parse a script (the class cache): re-run that variant with --variants.
"""
import argparse
import os
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

ap = argparse.ArgumentParser()
ap.add_argument("repo")
ap.add_argument("--workers", type=int, default=10)
ap.add_argument("--variants", default="1.2:0.9,0.4:0.4,0.4:0.7,0.4:1.0,0.6:0.4,0.6:0.7,0.6:1.0,0.8:0.4,0.8:0.7,0.8:1.0")
ap.add_argument("--default-gear", action="store_true", help="also the game's own matrix (all manoeuvres, 12/18/24 kt)")
ap.add_argument("--skip-runs", action="store_true")
a = ap.parse_args()

sys.path.insert(0, os.path.join(a.repo, "tools", "video"))
from reality_check import DEFAULT_GODOT, GIT_BASH, load_csv, measure, fell  # noqa: E402
from reality_sweep import chop_summary  # noqa: E402

OUT = os.path.join(a.repo, ".sim_output", "leg_sweep")
variants = [tuple(v.split(":")) for v in a.variants.split(",")]
RUNS = {
    "gybe": ("tools/matrix.sh", ["--only=gybe", "--winds=24,30", "--gear_board=pj_new_sealand_slalom_97",
                                 "--gear_sail=gg_sails_slalom_5_7"]),
    "chop": ("tools/lake_matrix.sh", ["--only=straight", "--lake_waves=1"]),
}
if a.default_gear:
    RUNS["matrix"] = ("tools/matrix.sh", [])


def folder(f, z, kind):
    return os.path.join(OUT, "f%s_z%s_%s" % (f, z, kind))


def run(job):
    f, z, kind = job
    script, args = RUNS[kind]
    out_dir = folder(f, z, kind)
    os.makedirs(out_dir, exist_ok=True)
    env = dict(os.environ)
    env.setdefault("GODOT", DEFAULT_GODOT)
    cmd = [GIT_BASH, script] + args + ["--sailor.leg_natural_frequency_hz=" + f,
                                       "--sailor.leg_damping_ratio=" + z,
                                       "--out_dir=" + out_dir.replace("\\", "/")]
    done = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace",
                          cwd=a.repo, env=env)
    with open(os.path.join(out_dir, "log.txt"), "w", encoding="utf-8") as fh:
        fh.write(done.stdout + "\n" + done.stderr)
    return job, done.returncode


if not a.skip_runs:
    jobs = [(f, z, kind) for f, z in variants for kind in RUNS]
    with ThreadPoolExecutor(max_workers=a.workers) as pool:
        for (f, z, kind), code in pool.map(run, jobs):
            print("done f=%s z=%s %s exit %d" % (f, z, kind, code), flush=True)

print()
print("%-12s | %-58s | %-40s" % ("legs", "strong_62 gybes: off-plane s (F = fell)", "lake chop 12:00/14:30/17:00"))
print("%-12s | %-58s | %-40s" % ("Hz / zeta", "beam24 beam30 key24 key30 broad24 broad30  falls", "pitch deg | knees cm | speed kn"))
for f, z in variants:
    cells, falls = [], 0
    for name in ("gybe_beam_24", "gybe_beam_30", "gybe_beam_key_24", "gybe_beam_key_30", "gybe_broad_24", "gybe_broad_30"):
        path = os.path.join(folder(f, z, "gybe"), name + ".csv")
        if not os.path.exists(path):
            cells.append("  -  ")
            continue
        off = measure(load_csv(path), {"stat": "off_plane_s"})
        if fell(path):
            falls += 1
            cells.append("  F  ")
        else:
            cells.append("%5.2f" % off)
    pitch, knee, speed = [], [], []
    for when in ("1200", "1430", "1700"):
        path = os.path.join(folder(f, z, "chop"), "straight_%s.csv" % when)
        if os.path.exists(path):
            s = chop_summary(path)
            pitch.append("%.2f" % s["pitch"])
            knee.append("%.1f" % s["knee_cm"])
            speed.append("%.1f%s" % (s["speed_kn"], "F" if s["fell"] else ""))
    line = "%-12s | %s   %d   | %s | %s | %s" % ("%s / %s" % (f, z), " ".join(cells), falls,
                                                "/".join(pitch), "/".join(knee), "/".join(speed))
    if a.default_gear:
        mpath = folder(f, z, "matrix")
        mfalls = sum(1 for n in os.listdir(mpath) if n.endswith(".csv") and fell(os.path.join(mpath, n))) if os.path.isdir(mpath) else -1
        line += " | matrix falls %d" % mfalls
    print(line)
