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


def run(variant, args):
    out_dir = os.path.join(OUT, variant)
    os.makedirs(out_dir, exist_ok=True)
    env = dict(os.environ)
    env.setdefault("GODOT", DEFAULT_GODOT)
    bash = GIT_BASH if os.path.exists(GIT_BASH) else "bash"
    done = subprocess.run([bash, "tools/matrix.sh"] + args + ["--out_dir=" + out_dir.replace("\\", "/")],
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


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--vary", action="append", default=[], help="group.field=v1,v2,...")
    ap.add_argument("--winds", default="24,30")
    ap.add_argument("--board", default="pj_new_sealand_slalom_97")
    ap.add_argument("--sail", default="gg_sails_slalom_5_7")
    ap.add_argument("--extra", default="", help="more test arguments, e.g. \"--waves=1\"")
    ap.add_argument("--max-rake", type=float, default=25.0, help="the sail's max_rake_deg")
    a = ap.parse_args()
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


if __name__ == "__main__":
    main()
