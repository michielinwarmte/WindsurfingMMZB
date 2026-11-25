"""The reality check: the game run in the conditions of real videos, compared with what the
videos measured.

  python tools/video/reality_check.py [--skip-runs] [--only=<case id>[,<case id>...]]

Reads tools/video/reality_cases.json. Runs each game run the cases need once (through the
project's scripts tools/matrix.sh or tools/lake_matrix.sh, headless; their CSVs into
.sim_output/reality/<run>/), measures each case's quantity in the game the same way it was
measured in the video, and prints a table: the real value with its tolerance, the game's value,
the gap, and pass / FAIL (strict cases) or "indicative" (cases whose conditions do not match the
video well enough yet). Writes .sim_output/reality/report.md and report.json.
Exit code 1 when a strict case fails.

Re-run it after every physics change, like tools/test.sh validation, so a fix in one condition
cannot quietly break another. Godot: the GODOT environment variable, else the path on Max's PC
(handed to the scripts, which Git Bash runs).

The measures (all from the per-case CSV files the game writes):
  median_tail   the median over the last 10 s of a straight run (the steady state)
  fast_spread   the spread (standard deviation) of the changes faster than 1 s, over the last
                20 s: the value minus its 1 s moving average, the way the videos were measured
  off_plane_s   in a gybe: the time the planing ratio is under 0.5 within 4 s of the sail's flip
"""

import argparse
import csv
import datetime
import json
import os
import subprocess
import sys

import numpy as np

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CASES = os.path.join(os.path.dirname(__file__), "reality_cases.json")
OUT = os.path.join(REPO, ".sim_output", "reality")
DEFAULT_GODOT = "C:/Users/Max de Dikke/AppData/Local/Programs/Godot/4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe"
# Through the project's own scripts (CLAUDE.md: the pinned Godot, the import, the logs).
SCRIPTS = {"matrix": "tools/matrix.sh", "lake": "tools/lake_matrix.sh"}
GIT_BASH = "C:/Program Files/Git/bin/bash.exe"  # not the Windows "bash" (that may be WSL)


def run_game(name, spec):
    """One headless game run; its CSVs land in .sim_output/reality/<name>/."""
    out_dir = os.path.join(OUT, name)
    os.makedirs(out_dir, exist_ok=True)
    env = dict(os.environ)
    env.setdefault("GODOT", DEFAULT_GODOT)
    bash = GIT_BASH if os.path.exists(GIT_BASH) else "bash"
    # our --out_dir comes last, so it wins over the script's own default folder
    cmd = [bash, SCRIPTS[spec["tool"]]] + spec["args"] + ["--out_dir=" + out_dir.replace("\\", "/")]
    print("running %s: %s %s" % (name, spec["tool"], " ".join(spec["args"])), flush=True)
    done = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace",
                          cwd=REPO, env=env)
    with open(os.path.join(out_dir, "log.txt"), "w", encoding="utf-8") as fh:
        fh.write(done.stdout + "\n" + done.stderr)
    if done.returncode != 0:
        sys.exit("the game run %s failed (exit %d); see %s" % (name, done.returncode,
                                                               os.path.join(out_dir, "log.txt")))


def load_csv(path):
    with open(path, encoding="utf-8") as fh:
        rows = list(csv.DictReader(fh))

    def col(key):
        out = []
        for r in rows:
            try:
                out.append(float(r[key]))
            except (KeyError, TypeError, ValueError):
                out.append(np.nan)
        return np.array(out)
    return col


def moving_average(v, n):
    pad = np.pad(v, (n // 2, n - 1 - n // 2), mode="edge")
    return np.convolve(pad, np.ones(n) / n, mode="valid")


def fell(path):
    """Did the sailor fall in this run? (the game writes the fall's kind per row)"""
    with open(path, encoding="utf-8") as fh:
        return any(r.get("fall_kind") for r in csv.DictReader(fh))


def measure(col, m):
    t = col("time_s")
    dt = float(np.median(np.diff(t)))
    scale = m.get("scale", 1.0)
    if m["stat"] == "median_tail":
        keep = t > t.max() - 10.0
        return float(np.nanmedian(col(m["column"])[keep])) * scale
    if m["stat"] == "fast_spread":
        keep = t > t.max() - 20.0
        v = col(m["column"])[keep]
        v = v[~np.isnan(v)]
        return float((v - moving_average(v, max(3, int(round(1.0 / dt))))).std()) * scale
    if m["stat"] == "off_plane_s":
        side, planing = col("sail_side"), col("planing_ratio")
        flips = np.nonzero(np.diff(np.sign(side)) != 0)[0]
        if not len(flips):
            return float("nan")
        t_flip = t[flips[0] + 1]
        near = (t > t_flip - 4.0) & (t < t_flip + 4.0)
        return float(np.sum(planing[near] < 0.5) * dt)
    raise ValueError("unknown measure " + m["stat"])


def git_commit():
    try:
        return subprocess.run(["git", "-C", REPO, "log", "--oneline", "-1"], capture_output=True,
                              text=True).stdout.strip()
    except OSError:
        return "?"


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--skip-runs", action="store_true", help="use the CSVs of the last run")
    ap.add_argument("--only", default="", help="case ids, comma-separated")
    a = ap.parse_args()
    with open(CASES, encoding="utf-8") as fh:
        spec = json.load(fh)
    cases = [c for c in spec["cases"] if not a.only or c["id"] in a.only.split(",")]
    needed = sorted({g["run"] for c in cases for g in c["game"]})
    if not a.skip_runs:
        for name in needed:
            run_game(name, spec["runs"][name])
    results, strict_fail = [], False
    for c in cases:
        for g in c["game"]:
            path = os.path.join(OUT, g["run"], g["csv"])
            exists = os.path.exists(path)
            value = measure(load_csv(path), c["measure"]) if exists else float("nan")
            gap = value - c["real"]
            ok = bool(abs(gap) <= c["tol"])  # NaN (no value) never passes
            verdict = ("pass" if ok else "FAIL") if c["strict"] else ("close" if ok else "off")
            if not exists:
                verdict += ": no CSV"
            elif fell(path):
                verdict += ": the sailor fell off"
            strict_fail |= c["strict"] and not ok
            results.append({"case": c["id"], "run": g["run"], "csv": g["csv"], "real": c["real"],
                            "tol": c["tol"], "unit": c["unit"], "game": round(value, 3),
                            "gap": round(gap, 3), "verdict": verdict, "strict": c["strict"]})
    header = "%-13s %-24s %14s %9s %9s  %s" % ("case", "game run", "real", "game", "gap", "verdict")
    print("\n" + header + "\n" + "-" * len(header))
    for r in results:
        print("%-13s %-24s %8.2f +-%-4g %9.2f %9.2f  %s%s" % (
            r["case"], r["run"] + "/" + r["csv"].replace(".csv", ""), r["real"], r["tol"],
            r["game"], r["gap"], r["verdict"], "" if r["strict"] else " (indicative)"))
    n_strict = sum(1 for r in results if r["strict"])
    n_pass = sum(1 for r in results if r["strict"] and r["verdict"] == "pass")
    print("\nstrict: %d of %d pass" % (n_pass, n_strict))
    stamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "report.json"), "w", encoding="utf-8") as fh:
        json.dump({"when": stamp, "commit": git_commit(), "results": results}, fh, indent=1)
    with open(os.path.join(OUT, "report.md"), "w", encoding="utf-8") as fh:
        fh.write("# Reality check, %s (%s)\n\n" % (stamp, git_commit()))
        fh.write("| Case | Game run | Real | Game | Gap | Verdict |\n|---|---|---|---|---|---|\n")
        for r in results:
            fh.write("| %s | %s/%s | %g +- %g %s | %.2f | %.2f | %s%s |\n" % (
                r["case"], r["run"], r["csv"], r["real"], r["tol"], r["unit"], r["game"], r["gap"],
                r["verdict"], "" if r["strict"] else " (indicative)"))
        fh.write("\nStrict: %d of %d pass.\n" % (n_pass, n_strict))
    sys.exit(1 if strict_fail else 0)


if __name__ == "__main__":
    main()
