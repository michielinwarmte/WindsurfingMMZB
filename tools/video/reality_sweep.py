"""Which setting closes a reality-check gap? Runs the game's straight case with one setting
changed at a time and prints the numbers the reality check measures.

  python tools/video/reality_sweep.py --vary sail.ce_boom_fraction=0.25,0.30,0.40
      [--vary sailor.<field>=a,b] [--winds 24,30] [--board <gear id>] [--sail <gear id>]
      [--extra "--waves=1"]

Each --vary is swept on its own (one setting changed, everything else as the game has it), plus
one run with nothing changed. Diagnosis only: nothing in the game is edited, the setting is
handed to the manoeuvre test (tools/matrix.sh --<group>.<field>=<value>). CSVs in
.sim_output/reality_sweep/<variant>/.
Printed per variant and wind: the rig's rake (degrees; the rake share times max_rake_deg), the
rig's lean to windward, the wet length, the trim, the heel, the speed, and whether the sailor fell.
"""

import argparse
import csv
import os
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from reality_check import DEFAULT_GODOT, GIT_BASH, REPO  # noqa: E402

OUT = os.path.join(REPO, ".sim_output", "reality_sweep")


def run(variant, args, tool="matrix"):
    out_dir = os.path.join(OUT, tool + "_" + variant)
    os.makedirs(out_dir, exist_ok=True)
    env = dict(os.environ)
    env.setdefault("GODOT", DEFAULT_GODOT)
    bash = GIT_BASH if os.path.exists(GIT_BASH) else "bash"
    script = "tools/matrix.sh" if tool == "matrix" else "tools/lake_matrix.sh"
    done = subprocess.run([bash, script] + args + ["--out_dir=" + out_dir.replace("\\", "/")],
                          capture_output=True, text=True, encoding="utf-8", errors="replace",
                          cwd=REPO, env=env)
    with open(os.path.join(out_dir, "log.txt"), "w", encoding="utf-8") as fh:
        fh.write(done.stdout + "\n" + done.stderr)
    return out_dir


def summary(path, max_rake_deg):
    with open(path, encoding="utf-8") as fh:
        rows = list(csv.DictReader(fh))
    fell = any(r.get("fall_kind") for r in rows)
    t = np.array([float(r["time_s"]) for r in rows])
    keep = t > t.max() - 10.0

    def med(key, scale=1.0):
        v = np.array([float(r[key]) for r in rows])[keep]
        return float(np.median(v)) * scale
    return {"rake_deg": med("rake", max_rake_deg), "lean_deg": med("rig_lean_deg"),
            "wet_m": med("wetted_length_m"), "trim_deg": med("trim_deg"), "heel_deg": med("heel_deg"),
            "speed_kn": med("speed_ms", 1.9438), "fell": fell}


def fast(v, dt):
    """The changes faster than 1 s: the value minus its 1 s moving average."""
    n = max(3, int(round(1.0 / dt)))
    pad = np.pad(v, (n // 2, n - 1 - n // 2), mode="edge")
    return v - np.convolve(pad, np.ones(n) / n, mode="valid")


def chop_summary(path):
    """Over chop, the last 20 s: how much the board pitches and heaves, how much the knees
    work, how much the body moves for each centimetre the board moves (body = the board's
    height minus the knee bend; 0 = a level body, 1 = it moves with the board), how often the
    turn rate wags past 5 deg/s from side to side (per 12 s, as tools/lake_matrix.sh counts)."""
    with open(path, encoding="utf-8") as fh:
        rows = list(csv.DictReader(fh))
    fell = any(r.get("fall_kind") for r in rows)
    col = lambda k: np.array([float(r[k]) for r in rows])
    t = col("time_s")
    keep = t > t.max() - 20.0
    dt = float(np.median(np.diff(t)))
    # the board's height under the feet: they stand stance_z aft of the origin (0.05 m at rest
    # to 0.54 m planing, sailor_default.tres), and a bow-up pitch lowers a point aft
    stance = np.clip(col("stance")[keep], 0.0, 1.0)
    feet_aft_m = 0.05 + (0.54 - 0.05) * stance
    board = fast(col("y")[keep] - feet_aft_m * np.sin(np.radians(col("pitch_deg")[keep])), dt)
    knee = fast(col("knee_bend_m")[keep], dt)
    body = board - knee
    side, last, wags = 0, 0, 0
    for v in col("yaw_rate_dps")[keep]:
        side = 1 if v > 5.0 else (-1 if v < -5.0 else 0)
        if side != 0:
            wags += 1 if (last != 0 and side != last) else 0
            last = side
    return {"pitch": fast(col("pitch_deg")[keep], dt).std(), "heave_cm": board.std() * 100,
            "knee_cm": knee.std() * 100, "body_ratio": body.std() / max(board.std(), 1e-6),
            "wags": wags * 12.0 / 20.0, "speed_kn": float(np.median(col("speed_ms")[keep])) * 1.9438,
            "fell": fell}


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--vary", action="append", default=[], help="group.field=v1,v2,...")
    ap.add_argument("--winds", default="24,30")
    ap.add_argument("--board", default="pj_new_sealand_slalom_97")
    ap.add_argument("--sail", default="gg_sails_slalom_5_7")
    ap.add_argument("--extra", default="", help="more test arguments, e.g. \"--waves=1\"")
    ap.add_argument("--max-rake", type=float, default=25.0, help="the sail's max_rake_deg")
    ap.add_argument("--skip-runs", action="store_true", help="re-read the last runs' CSVs")
    ap.add_argument("--chop", action="store_true",
                    help="Lake Silvaplana's own chop (tools/lake_matrix.sh --lake_waves=1) and the bounce numbers")
    a = ap.parse_args()
    if a.chop:
        return main_chop(a)
    base = ["--only=straight", "--winds=" + a.winds, "--gear_board=" + a.board,
            "--gear_sail=" + a.sail] + a.extra.split()
    variants = [("as the game has it", [])]
    for v in a.vary:
        field, values = v.split("=", 1)
        for value in values.split(","):
            variants.append(("%s=%s" % (field, value), ["--%s=%s" % (field, value)]))
    winds = a.winds.split(",")
    print("%-34s %4s %8s %8s %7s %7s %7s %8s  %s" % ("variant", "kt", "rake", "lean", "wet m",
                                                    "trim", "heel", "speed", "fell"))
    for name, extra in variants:
        folder = name.replace("=", "_").replace(" ", "_")
        out_dir = run(folder, base + extra)
        max_rake = float(extra[0].split("=")[1]) if extra and "max_rake_deg" in extra[0] else a.max_rake
        for kt in winds:
            path = os.path.join(out_dir, "straight_%s.csv" % kt)
            if not os.path.exists(path):
                print("%-34s %4s  (no result: see %s)" % (name, kt, os.path.join(out_dir, "log.txt")))
                continue
            s = summary(path, max_rake)
            print("%-34s %4s %7.1f° %7.1f° %7.2f %6.1f° %6.1f° %6.1f kn  %s" % (
                name, kt, s["rake_deg"], s["lean_deg"], s["wet_m"], s["trim_deg"], s["heel_deg"],
                s["speed_kn"], "FELL" if s["fell"] else ""), flush=True)


def main_chop(a):
    base = ["--only=straight", "--lake_waves=1"] + a.extra.split()
    variants = [("as the game has it", [])]
    for v in a.vary:
        field, values = v.split("=", 1)
        for value in values.split(","):
            variants.append(("%s=%s" % (field, value), ["--%s=%s" % (field, value)]))
    print("%-36s %5s %7s %8s %8s %6s %6s %8s  %s" % ("variant", "time", "pitch", "at feet", "knees",
                                                   "body", "wags", "speed", "fell"))
    for name, extra in variants:
        folder = name.replace("=", "_").replace(" ", "_")
        out_dir = os.path.join(OUT, "lake_" + folder) if a.skip_runs else run(folder, base + extra, tool="lake")
        for when in ("1200", "1430", "1700"):
            path = os.path.join(out_dir, "straight_%s.csv" % when)
            if not os.path.exists(path):
                print("%-36s %5s  (no result: see %s)" % (name, when, os.path.join(out_dir, "log.txt")))
                continue
            s = chop_summary(path)
            print("%-36s %5s %6.2f° %6.1fcm %6.1fcm %6.2f %6.1f %6.1f kn  %s" % (
                name, when, s["pitch"], s["heave_cm"], s["knee_cm"], s["body_ratio"], s["wags"],
                s["speed_kn"], "FELL" if s["fell"] else ""), flush=True)


if __name__ == "__main__":
    main()
