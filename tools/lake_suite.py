#!/usr/bin/env python3
"""The lake-speed suite (Documentation/reports/autopilot/lake_speed/README.md; Max, 7 November 2026).

    tools/lake_suite.sh --label=baseline [--cases=1] [--refs=1] [--controller.<field>=<n> ...]
    tools/lake_suite.sh --label=x --cores=12 --project=<a frozen copy of Game/>

The player's controller as the autopilot drives it (the push at 75 %, the night-tuned steering on)
on Lake Silvaplana in the Maloja afternoon's wind (13:00 to 16:00, the map's wind at x1.0 and a
stronger day at x1.3) on the lake's full waves, on three gear combos, from places spread over the
water a Maloja afternoon is sailed on (the camping beach to the middle). Every case is its own
headless Godot process (Game/dev/run_lake_speed.gd), seeded and the same every run, and writes a CSV
of where it sailed and the wind it had there. Four scenarios, and the guards:

  start   from rest in the lake's own wind: the time to plane, the balance in the first 30 s (the
          board's heel and pitch swings, how fast the sailor's lean moves), the nose dives, falls
  strong  from rest at x1.3: the nose dives below the plane (the bow buried, the nose down), the
          time buried, the deepest pitch, the time to plane, falls
  reach   beam (90) and broad (135) reaches at x1.0 and x1.3: the speed in the gusts (the mean of the
          90th percentile and the mean speed while the wind at the board is in its top quarter)
          against Max's targets (50 km/h beam, 55 km/h broad: a shortfall costs, beyond is a small
          bonus), the mean speed, the waves' control (pitch rate SD, the board in the air), falls
  guards  last night's taps, Shift carve, the reflex, tacks and gybes (tools/night_suite.py's cases
          and costs, with the night-tuned steering), at half weight: nothing may regress

Each scenario gets a cost (lower is better: falls weigh 100 each); the total is their sum. The
results land in .sim_output/lake_speed/suite/<label>/ (one log and one CSV per case, results.json,
scores.json), and one table is printed.
"""
import json
import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import night_suite  # noqa: E402

ROOT = night_suite.ROOT
FALL_COST = 100.0
GUARD_WEIGHT = 0.5
SCENARIOS = ["start", "strong", "reach", "guards"]
GEARS = ["small", "medium", "big"]
TARGET_BEAM_KMH = 50.0
TARGET_BROAD_KMH = 55.0
HARNESS = "res://dev/run_lake_speed.gd"
GUARD_SCENARIOS = ("taps", "carve", "reflex", "turns")

# (id, scenario, args) for one gear; the place, the hour and the course spread over the cases.
LAKE_CASES = [
    ("start_camping_1330_100", "start", ["--scenario=start", "--place=camping", "--hour=13.5", "--twa=100"]),
    ("start_between_1430_120", "start", ["--scenario=start", "--place=between", "--hour=14.5", "--twa=120"]),
    ("start_middle_1530_90p", "start", ["--scenario=start", "--place=middle", "--hour=15.5", "--twa=90", "--tack=port"]),
    ("strong_middle_1430_100", "strong", ["--scenario=strong", "--place=middle", "--hour=14.5", "--twa=100", "--lake_wind_scale=1.3"]),
    ("strong_between_1330_130", "strong", ["--scenario=strong", "--place=between", "--hour=13.5", "--twa=130", "--lake_wind_scale=1.3"]),
    ("beam_middle_1430_x1.0", "reach", ["--scenario=reach", "--place=middle", "--hour=14.5", "--twa=90"]),
    ("beam_south_1500_x1.0p", "reach", ["--scenario=reach", "--place=south", "--hour=15.0", "--twa=90", "--tack=port"]),
    ("beam_between_1330_x1.3", "reach", ["--scenario=reach", "--place=between", "--hour=13.5", "--twa=90", "--lake_wind_scale=1.3"]),
    ("broad_between_1530_x1.0", "reach", ["--scenario=reach", "--place=between", "--hour=15.5", "--twa=135"]),
    ("broad_middle_1430_x1.3", "reach", ["--scenario=reach", "--place=middle", "--hour=14.5", "--twa=135", "--lake_wind_scale=1.3"]),
]
# Not scored: the same beam reach without the waves, and without the waves in sea-level air (what the
# waves and the thin air cost, for the physics questions).
REFERENCE_CASES = [
    ("ref_beam_flat_x1.0", "ref", ["--scenario=reach", "--place=middle", "--hour=14.5", "--twa=90", "--waves=0"]),
    ("ref_beam_flat_sea_x1.0", "ref", ["--scenario=reach", "--place=middle", "--hour=14.5", "--twa=90", "--waves=0", "--air=1.225"]),
    ("ref_broad_flat_x1.3", "ref", ["--scenario=reach", "--place=middle", "--hour=14.5", "--twa=135", "--lake_wind_scale=1.3", "--waves=0"]),
    ("ref_beam_flat_x1.3", "ref", ["--scenario=reach", "--place=between", "--hour=13.5", "--twa=90", "--lake_wind_scale=1.3", "--waves=0"]),
]


def night_tuning_overrides(project):
    """PlayerController.NIGHT_TUNING as --controller.<field>=<value> (the guards' harnesses do not set it)."""
    path = os.path.join(project, "windsurfer", "player_controller.gd")
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
    body = text.split("const NIGHT_TUNING: Dictionary[String, float] = {", 1)[1].split("}", 1)[0]
    return [f"--controller.{k}={v}" for k, v in re.findall(r'"(\w+)":\s*(-?[\d.]+)', body)]


def cases(refs=False):
    """Every case: (id, scenario, script, args)."""
    out = []
    for gear in GEARS:
        for case_id, scenario, args in LAKE_CASES + (REFERENCE_CASES if refs else []):
            out.append((f"{gear}/{case_id}", scenario, HARNESS, args + [f"--gear={gear}"]))
    for case_id, scenario, script, args in night_suite.cases():
        if scenario in GUARD_SCENARIOS:
            out.append((f"guards/{case_id}", "guards:" + scenario, script, args))
    return out


def target_of(r):
    return TARGET_BEAM_KMH if float(r.get("twa", 90)) <= 110.0 else TARGET_BROAD_KMH


def gust_speed(r):
    """The speed in the gusts, km/h: the mean of the 90th percentile and the speed in the top quarter of the wind."""
    return 0.5 * (r["p90_kmh"] + r["gust_kmh"])


def lake_cost(scenario, r):
    """One lake case's cost (lower is better) and its falls; None: it broke."""
    if r is None:
        return 500.0, 5
    falls = int(r.get("falls", 0)) + (5 if r.get("nan") else 0)
    cost = FALL_COST * falls
    if scenario == "start":
        plane_s = r["plane_s"] if r["plane_s"] >= 0 else r["seconds"] + 20.0
        cost += plane_s + 2.0 * r["heel_sd"] + 2.0 * r["pitch_sd"] + 20.0 * r["lean_rate_rms"] + 5.0 * r["dives"]
    elif scenario == "strong":
        plane_s = r["plane_s"] if r["plane_s"] >= 0 else r["seconds"] + 10.0
        cost += 15.0 * r["dives"] + 5.0 * r["buried_s"] + 2.0 * max(-r["pitch_min_deg"] - 4.0, 0.0) + 0.5 * plane_s
    elif scenario == "reach":
        target = target_of(r)
        v = gust_speed(r)
        cost += 2.0 * max(target - v, 0.0) - 0.5 * min(max(v - target, 0.0), 10.0)
        cost += -0.5 * r["speed_kmh"] + 0.5 * r["pitch_rate_sd"] + 0.05 * r["air_per_min"]
    return cost, falls


def overrides_for(script, overrides, base):
    if script == HARNESS:
        return [o for o in overrides if o.lstrip("-").startswith(("pilot.", "controller."))]
    return night_suite.overrides_for(script, base + overrides)


def evaluate_many(variants, godot, project, cores, out_root, refs=False):
    """Several variants [(label, overrides)] in one pool; a list of summaries in the same order."""
    base = night_tuning_overrides(project)
    jobs = []
    for label, overrides in variants:
        out_dir = os.path.join(out_root, label)
        for case_id, scenario, script, args in cases(refs):
            extra = [f"--csv={os.path.join(out_dir, case_id + '.csv')}"] if script == HARNESS else []
            jobs.append((label + "/" + case_id, script, args + extra + overrides_for(script, overrides, base),
                         os.path.join(out_dir, case_id + ".log")))
    started = time.time()
    night_suite.run_pool(jobs, godot, project, cores)
    seconds = time.time() - started
    return [score_dir(os.path.join(out_root, label), label, overrides, seconds, refs) for label, overrides in variants]


def score_dir(out_dir, label, overrides, seconds, refs=False):
    results = {}
    scenarios = {s: {"cost": 0.0, "falls": 0} for s in SCENARIOS}
    for case_id, scenario, script, args in cases(refs):
        path = os.path.join(out_dir, case_id + ".log")
        if scenario.startswith("guards:"):
            inner = scenario.split(":", 1)[1]
            shift_s = sum(float(a.split("=")[1]) for a in args if a.startswith("--shift="))
            parsed = night_suite.parse_matrix(path, shift_s) if inner == "turns" else night_suite.parse_night(path)
            if inner == "turns" and not parsed:
                parsed = None
            cost, falls = night_suite.case_cost(inner, parsed)
            cost *= GUARD_WEIGHT
            bucket = "guards"
        else:
            parsed = night_suite.parse_night(path)
            if scenario == "ref":
                results[case_id] = {"scenario": "ref", "cost": 0.0, "falls": 0, "result": parsed}
                continue
            cost, falls = lake_cost(scenario, parsed)
            bucket = scenario
        results[case_id] = {"scenario": bucket, "cost": round(cost, 3), "falls": falls, "result": parsed}
        scenarios[bucket]["cost"] += cost
        scenarios[bucket]["falls"] += falls
    for s in scenarios.values():
        s["cost"] = round(s["cost"], 3)
    total = round(sum(s["cost"] for s in scenarios.values()), 3)
    summary = {"label": label, "overrides": overrides, "total": total, "scenarios": scenarios, "seconds": round(seconds, 1),
               "speeds": speed_summary(results)}
    with open(os.path.join(out_dir, "results.json"), "w", encoding="utf-8") as handle:
        json.dump(results, handle, indent=1)
    with open(os.path.join(out_dir, "scores.json"), "w", encoding="utf-8") as handle:
        json.dump(summary, handle, indent=1)
    return summary


def speed_summary(results):
    """The speed in the gusts per reach kind (beam / broad, x1.0 / x1.3), averaged over gear and place."""
    groups = {}
    for case_id, entry in results.items():
        r = entry["result"]
        if entry["scenario"] != "reach" or r is None:
            continue
        kind = ("beam" if float(r["twa"]) <= 110.0 else "broad") + " x" + str(r["wind_scale"])
        groups.setdefault(kind, []).append(gust_speed(r))
    return {k: round(sum(v) / len(v), 2) for k, v in sorted(groups.items())}


def table(summary):
    lines = ["| scenario | cost | falls |", "|---|---:|---:|"]
    for name in SCENARIOS:
        s = summary["scenarios"][name]
        lines.append(f"| {name} | {s['cost']:.1f} | {s['falls']} |")
    lines.append(f"| **total** | **{summary['total']:.1f}** | {sum(s['falls'] for s in summary['scenarios'].values())} |")
    lines.append("")
    lines.append("Speed in the gusts (km/h, the mean over the gear and places): " +
                 ", ".join(f"{k} {v}" for k, v in summary.get("speeds", {}).items()))
    return "\n".join(lines)


def case_table(out_dir):
    """One line per lake case: where, the wind there, the speeds and the balance."""
    with open(os.path.join(out_dir, "results.json"), encoding="utf-8") as handle:
        results = json.load(handle)
    lines = ["| case | cost | falls | start (LV95 E, N) | wind at the board kt (mean / p90 / max) | plane s | speed km/h (mean / p90 / in gusts / max) | target | TWA | numbers |",
             "|---|---:|---:|---|---|---:|---|---:|---:|---|"]
    for case_id, entry in results.items():
        r = entry["result"]
        if case_id.startswith("guards/"):
            continue
        if r is None:
            lines.append(f"| {case_id} | {entry['cost']:.1f} | {entry['falls']} | broke | | | | | | |")
            continue
        target = f"{target_of(r):.0f}" if entry["scenario"] in ("reach", "ref") else ""
        numbers = {"start": f"heel SD {r['heel_sd']}, pitch SD {r['pitch_sd']}, lean rate {r['lean_rate_rms']}, dives {r['dives']}",
                   "strong": f"dives {r['dives']}, buried {r['buried_s']} s, pitch min {r['pitch_min_deg']}, bow max {r['bow_max_m']} m",
                   "reach": f"pitch rate SD {r['pitch_rate_sd']}, air {r['air_per_min']}/min",
                   "ref": f"pitch rate SD {r['pitch_rate_sd']}"}[entry["scenario"]]
        if r.get("aground"):
            numbers += f", aground at {r['seconds']} s"
        lines.append(f"| {case_id} | {entry['cost']:.1f} | {entry['falls']} | {r['start_lv95'][0]:.0f}, {r['start_lv95'][1]:.0f} |"
                     f" {r['wind_mean_kt']} / {r['wind_p90_kt']} / {r['wind_max_kt']} | {r['plane_s']} |"
                     f" {r['speed_kmh']} / {r['p90_kmh']} / {r['gust_kmh']} / {r['max_kmh']} | {target} | {r['twa_mean_deg']} | {numbers} |")
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
    cores = int(options.get("cores", "12"))
    label = options.get("label", "run")
    out_root = os.path.join(ROOT, ".sim_output", "lake_speed", "suite")
    refs = options.get("refs") == "1"
    summary = evaluate_many([(label, overrides)], godot, project, cores, out_root, refs)[0]
    print(f"{label}: {summary['seconds']} s")
    print(table(summary))
    if options.get("cases") == "1":
        print(case_table(os.path.join(out_root, label)))


if __name__ == "__main__":
    main()
