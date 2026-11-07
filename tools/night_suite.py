#!/usr/bin/env python3
"""The night of 7 November 2026's scenario suite (Documentation/reports/autopilot/night_7nov/README.md).

    tools/night_suite.sh --label=baseline                         (the branch as it is)
    tools/night_suite.sh --label=try1 --controller.steer_rise_s=0.3 --pilot.hike_share=1.0
    tools/night_suite.sh --label=x --cores=14 --project=<a frozen copy of Game/>

Every case is its own headless Godot process (Game/dev/run_night.gd, and Game/dev/run_matrix.gd for
the tacks and gybes), seeded and the same every run; a pool of --cores processes runs them. The
player's beginner controller sails every case the way the autopilot drives it (the heading hold and
the auto-sheet, keys pressed by script). The seven scenarios:

  plane   light wind, from rest: the time to plane and the speed made good (open water 10, 12, 14 kt
          on a beam and a broad reach; the lake at 0.6 and 0.75 of its wind)
  steer   below the plane, 8 and 10 kt: the heading hold's error, and a 30 degree turn away and up
          (overshoot, settle time, the heel, lean and rake jumps)
  taps    0.1, 0.2 and 0.3 s A/D taps at 8 and 18 kt: the heading change and the jumps
  carve   Shift + A/D at 12, 18 and 24 kt: the rate turned, the falls (and plain A/D for comparison)
  fly     24 and 30 kt in waves 1.5 times higher, the lake at 1.32 and 1.65 of its wind: falls, the
          board leaving the water, the speed
  reflex  gusty 18 and 24 kt reaches (and 24 kt with the push at 75 % and the mouse body held, and the
          lake at 1.0 and 1.32): how much of the time the reflex eases, the falls, the speed
  turns   the tacks and gybes of the matrix at 12, 18 and 24 kt: plain Space, the key held, and
          the key held with Shift (at 18 and 24 kt also over another wave, 1.3 s later): the time and the falls

Each scenario gets a cost (lower is better: falls weigh 100 each, then time and speed, then the
jolts); the total is their sum. The results land in .sim_output/night7nov/<label>/ (one log per
case, results.json, scores.json), and one table is printed.
"""
import json
import os
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FALL_COST = 100.0
SCENARIOS = ["plane", "steer", "taps", "carve", "fly", "reflex", "turns"]
# When the manoeuvre starts in each matrix case (Space, or the key for tack_held): run_matrix.gd.
MATRIX_START_S = {"tack_stb": 25.0, "tack_port": 25.0, "tack_held": 25.0, "gybe_broad": 30.0,
                  "gybe_beam": 27.0, "gybe_beam_key": 27.0}
JOB_TIMEOUT_S = 900


def cases():
    """Every case: (id, scenario, script, args)."""
    out = []
    night = "res://dev/run_night.gd"
    for kt in (10, 12, 14):
        for twa in (90, 130):
            out.append((f"plane_{kt}_{twa}", "plane", night, ["--scenario=plane", f"--kt={kt}", f"--twa={twa}"]))
    for scale in ("0.6", "0.75"):
        out.append((f"plane_lake{scale}", "plane", night, ["--scenario=plane", "--map=lake", f"--lake_wind_scale={scale}", "--twa=120"]))
    for kt in (8, 10):
        out.append((f"steer_{kt}", "steer", night, ["--scenario=steer", f"--kt={kt}", "--twa=90"]))
    for kt in (8, 18):
        out.append((f"taps_{kt}", "taps", night, ["--scenario=taps", f"--kt={kt}", "--twa=100"]))
    for kt in (12, 18, 24):
        out.append((f"carve_{kt}", "carve", night, ["--scenario=carve", f"--kt={kt}", "--twa=100"]))
    for kt in (24, 30):
        for twa in (110, 135):
            out.append((f"fly_{kt}_{twa}", "fly", night, ["--scenario=fly", f"--kt={kt}", f"--twa={twa}", "--wave_scale=1.5"]))
    for kt in (24, 30):
        out.append((f"fly_{kt}_120_g6.5", "fly", night, ["--scenario=fly", f"--kt={kt}", "--twa=120", "--wave_scale=1.5", "--gust_period=6.5"]))
    for scale in ("1.32", "1.65"):
        out.append((f"fly_lake{scale}", "fly", night, ["--scenario=fly", "--map=lake", f"--lake_wind_scale={scale}", "--twa=120"]))
    for kt in (18, 24):
        for twa in (100, 135):
            out.append((f"reflex_{kt}_{twa}", "reflex", night, ["--scenario=reflex", f"--kt={kt}", f"--twa={twa}", "--gust_intensity=0.3"]))
    out.append(("reflex_24_push75_body", "reflex", night, ["--scenario=reflex", "--kt=24", "--twa=120", "--gust_intensity=0.3",
                                                           "--push=0.75", "--body.side=0", "--body.back=0"]))
    for scale in ("1.0", "1.32"):
        out.append((f"reflex_lake{scale}", "reflex", night, ["--scenario=reflex", "--map=lake", f"--lake_wind_scale={scale}", "--twa=130"]))
    matrix = "res://dev/run_matrix.gd"
    for kt in (12, 18, 24):
        out.append((f"turns_{kt}_space", "turns", matrix, ["--only=tack,gybe", f"--winds={kt}"]))
        out.append((f"turns_{kt}_key", "turns", matrix, ["--only=tack,gybe", f"--winds={kt}", "--hold_turn=1"]))
        out.append((f"turns_{kt}_shift", "turns", matrix, ["--only=tack,gybe", f"--winds={kt}", "--hold_turn=1", "--sharp=1"]))
    # The same turns over another wave (the keys and Space 1.3 s later): one wave is a lucky draw.
    for kt in (18, 24):
        out.append((f"turns_{kt}_key_late", "turns", matrix, ["--only=tack,gybe", f"--winds={kt}", "--hold_turn=1", "--shift=1.3"]))
        out.append((f"turns_{kt}_shift_late", "turns", matrix, ["--only=tack,gybe", f"--winds={kt}", "--hold_turn=1", "--sharp=1", "--shift=1.3"]))
    return out


def overrides_for(script, overrides):
    """The overrides a harness takes: run_night.gd the pilot, controller and body; run_matrix.gd the
    pilot, controller, sailor and sail."""
    groups = ("pilot.", "controller.", "body.") if script.endswith("run_night.gd") else ("pilot.", "controller.", "sailor.", "sail.")
    return [o for o in overrides if o.lstrip("-").startswith(groups)]


def run_pool(jobs, godot, project, cores, log=print):
    """jobs: list of (key, script, args, log_path). Runs them cores at a time; returns {key: exit code}."""
    pending = list(jobs)
    running = []
    codes = {}
    while pending or running:
        while pending and len(running) < cores:
            key, script, args, log_path = pending.pop(0)
            os.makedirs(os.path.dirname(log_path), exist_ok=True)
            handle = open(log_path, "w", encoding="utf-8", errors="replace")
            command = [godot, "--headless", "--no-header", "--path", project, "-s", script, "--"] + args
            process = subprocess.Popen(command, stdout=handle, stderr=subprocess.STDOUT, cwd=ROOT)
            running.append((key, process, handle, time.time()))
        still = []
        for key, process, handle, started in running:
            code = process.poll()
            if code is None and time.time() - started > JOB_TIMEOUT_S:
                process.kill()
                code = -9
            if code is None:
                still.append((key, process, handle, started))
            else:
                handle.close()
                codes[key] = code
        running = still
        time.sleep(0.2)
    return codes


def parse_night(path):
    for line in reversed(read_lines(path)):
        if line.startswith("RESULT "):
            return json.loads(line[len("RESULT "):])
    return None


def parse_matrix(path, shift_s=0.0):
    """The matrix's case lines: name, kt, fell, done (s from the case's start; shift_s: --shift)."""
    rows = []
    for line in read_lines(path):
        parts = line.split("|")
        if len(parts) < 4:
            continue
        head = parts[0].split()
        if len(head) != 2 or head[0] not in MATRIX_START_S:
            continue
        fall = parts[1].strip()
        times = parts[2].split()
        done = times[1] if len(times) > 1 else "-"
        rows.append({"shift_s": shift_s, "name": head[0], "kt": head[1], "fell": fall != "-" and not fall.startswith("- "),
                     "nan": "NaN" in fall, "done_s": None if done == "-" else float(done)})
    return rows


def read_lines(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            return handle.read().splitlines()
    except OSError:
        return []


def case_cost(scenario, r):
    """One case's cost (lower is better) and its falls, from its parsed result (None: it broke)."""
    if r is None:
        return 500.0, 5
    if scenario == "turns":
        cost, falls = 0.0, 0
        for row in r:
            falls += 1 if (row["fell"] or row["nan"]) else 0
            if row["done_s"] is None:
                cost += 25.0
            else:
                cost += max(row["done_s"] - MATRIX_START_S[row["name"]] - row.get("shift_s", 0.0), 0.0)
        return cost + FALL_COST * falls, falls
    falls = int(r.get("falls", 0)) + (5 if r.get("nan") else 0)
    cost = FALL_COST * falls
    presses = r.get("presses", [])
    if scenario == "plane":
        plane_s = r["plane_s"] if r["plane_s"] >= 0 else r.get("seconds", 60.0)
        cost += plane_s - 3.0 * r["made_good_ms"]
    elif scenario == "steer":
        cost += 2.0 * r["hold_rms_deg"]
        for p in presses:
            cost += max(p["turn_max_deg"] - 30.0, 0.0) + 0.5 * abs(p["turn_deg"] - 30.0)
            cost += (p["settle_s"] if p["settle_s"] >= 0 else 7.0)
            cost += 0.3 * p["heel_jump_deg"] + 10.0 * p["lean_jump"] + 3.0 * p["rake_jump"]
            cost += FALL_COST * (1 if p["fell"] else 0) * 0.0  # counted in the case's falls
    elif scenario == "taps":
        for p in presses:
            tap_s = float(p["name"][3:6])
            wanted_deg = 15.0 * tap_s
            cost += 0.5 * p["heel_jump_deg"] + 10.0 * p["lean_jump"] + 5.0 * p["rake_jump"]
            cost += max(p["turn_max_deg"] - p["turn_deg"], 0.0)
            cost += max(wanted_deg - p["turn_deg"], 0.0) + 0.5 * max(p["turn_deg"] - 4.0 * wanted_deg, 0.0)
    elif scenario == "carve":
        for p in presses:
            if p["name"].startswith("sharp"):
                cost -= 0.3 * p["rate_dps"]
    elif scenario == "fly":
        cost -= 2.0 * r["speed_ms"]
    elif scenario == "reflex":
        cost += 20.0 * r["reflex_share"] - 2.0 * r["speed_ms"]
    return cost, falls


def evaluate(label, overrides, godot, project, cores, out_root, log=print):
    """Run the suite for one variant; returns {"total", "scenarios": {name: {cost, falls}}, "cases"}."""
    out_dir = os.path.join(out_root, label)
    jobs = []
    for case_id, scenario, script, args in cases():
        jobs.append((case_id, script, args + overrides_for(script, overrides), os.path.join(out_dir, case_id + ".log")))
    started = time.time()
    run_pool(jobs, godot, project, cores, log)
    return score_dir(out_dir, label, overrides, time.time() - started)


def evaluate_many(variants, godot, project, cores, out_root, log=print):
    """Several variants [(label, overrides)] in one pool (the PC stays full to the end); a list of
    summaries in the same order."""
    jobs = []
    for label, overrides in variants:
        out_dir = os.path.join(out_root, label)
        for case_id, scenario, script, args in cases():
            jobs.append((label + "/" + case_id, script, args + overrides_for(script, overrides), os.path.join(out_dir, case_id + ".log")))
    started = time.time()
    run_pool(jobs, godot, project, cores, log)
    seconds = time.time() - started
    return [score_dir(os.path.join(out_root, label), label, overrides, seconds) for label, overrides in variants]


def score_dir(out_dir, label, overrides, seconds):
    results = {}
    scenarios = {s: {"cost": 0.0, "falls": 0} for s in SCENARIOS}
    for case_id, scenario, script, _args in cases():
        path = os.path.join(out_dir, case_id + ".log")
        shift_s = sum(float(a.split("=")[1]) for a in _args if a.startswith("--shift="))
        parsed = parse_matrix(path, shift_s) if scenario == "turns" else parse_night(path)
        if scenario == "turns" and not parsed:
            parsed = None
        cost, falls = case_cost(scenario, parsed)
        results[case_id] = {"scenario": scenario, "cost": round(cost, 3), "falls": falls, "result": parsed}
        scenarios[scenario]["cost"] += cost
        scenarios[scenario]["falls"] += falls
    for s in scenarios.values():
        s["cost"] = round(s["cost"], 3)
    total = round(sum(s["cost"] for s in scenarios.values()), 3)
    summary = {"label": label, "overrides": overrides, "total": total, "scenarios": scenarios, "seconds": round(seconds, 1)}
    with open(os.path.join(out_dir, "results.json"), "w", encoding="utf-8") as handle:
        json.dump(results, handle, indent=1)
    with open(os.path.join(out_dir, "scores.json"), "w", encoding="utf-8") as handle:
        json.dump(summary, handle, indent=1)
    return summary


def table(summary):
    lines = ["| scenario | cost | falls |", "|---|---:|---:|"]
    for name in SCENARIOS:
        s = summary["scenarios"][name]
        lines.append(f"| {name} | {s['cost']:.1f} | {s['falls']} |")
    lines.append(f"| **total** | **{summary['total']:.1f}** | {sum(s['falls'] for s in summary['scenarios'].values())} |")
    return "\n".join(lines)


def case_table(out_dir):
    """One line per case with its main numbers, for the baseline's report."""
    with open(os.path.join(out_dir, "results.json"), encoding="utf-8") as handle:
        results = json.load(handle)
    lines = ["| case | cost | falls | numbers |", "|---|---:|---:|---|"]
    for case_id, entry in results.items():
        r = entry["result"]
        if r is None:
            numbers = "broke"
        elif entry["scenario"] == "turns":
            numbers = ", ".join(f"{row['name']} {'-' if row['done_s'] is None else round(row['done_s'] - MATRIX_START_S[row['name']] - row['shift_s'], 1)}{' FELL' if row['fell'] else ''}" for row in r)
        else:
            keys = {"plane": ("plane_s", "made_good_ms"), "steer": ("hold_rms_deg", "speed_ms"), "taps": ("speed_ms",),
                    "carve": ("speed_ms",), "fly": ("speed_ms", "air_per_min"), "reflex": ("reflex_share", "speed_ms")}[entry["scenario"]]
            numbers = ", ".join(f"{k} {r[k]}" for k in keys)
            if r.get("aground"):
                numbers += f", aground at {r['seconds']} s"
            for p in r.get("presses", []):
                numbers += f"; {p['name']}: turn {p['turn_deg']}, heel {p['heel_jump_deg']}, lean {p['lean_jump']}, rake {p['rake_jump']}"
                if entry["scenario"] == "carve":
                    numbers += f", rate {p['rate_dps']}"
                if entry["scenario"] == "steer":
                    numbers += f", max {p['turn_max_deg']}, settle {p['settle_s']}"
        lines.append(f"| {case_id} | {entry['cost']:.1f} | {entry['falls']} | {numbers} |")
    return "\n".join(lines)


def main():
    options = {}
    overrides = []
    for arg in sys.argv[1:]:
        if arg.startswith("--") and "=" in arg:
            key, value = arg[2:].split("=", 1)
            if "." in key:
                overrides.append(arg)
            else:
                options[key] = value
    godot = options.get("godot") or os.environ.get("GODOT")
    project = os.path.abspath(options.get("project", os.path.join(ROOT, "Game")))
    cores = int(options.get("cores", "14"))
    label = options.get("label", "run")
    out_root = os.path.join(ROOT, ".sim_output", "night7nov", "suite")
    summary = evaluate(label, overrides, godot, project, cores, out_root)
    print(f"{label}: {summary['seconds']} s")
    print(table(summary))
    if options.get("cases") == "1":
        print(case_table(os.path.join(out_root, label)))


if __name__ == "__main__":
    main()
