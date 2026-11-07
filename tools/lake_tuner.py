#!/usr/bin/env python3
"""The lake-speed tuner for the player's controller (Max, 7 November 2026), after tools/night_tuner.py.

    python -I tools/lake_tuner.py --godot=<Godot> [--project=<frozen copy of Game/>] [--cores=12] [--fresh=1]

Coordinate descent over the controller's numbers in PARAMS (each with its range), starting from the
player's set (the code's defaults with PlayerController.NIGHT_TUNING on top): for one number at a time
it scores the best set so far with that number a step up and a step down, both by the lake suite
(tools/lake_suite.py) in one pool of Godot processes; the better one is kept when it lowers the total
cost by more than MIN_GAIN and has no more falls than the baseline in any scenario. When a whole round
keeps nothing, the steps are halved down to SMALLEST_STEP_SHARE of each range; a round at the smallest
steps that keeps nothing means it has converged, and it stops. No AI in the loop.

It is resumable: the state is in .sim_output/lake_speed/tuner_state.json, and running it again carries
on from there (--fresh=1 starts over). Stop it with the file .sim_output/lake_speed/STOP (it stops after
the pair it is scoring). Every candidate goes into .sim_output/lake_speed/leaderboard.md; the best set
into Documentation/reports/autopilot/lake_speed/best.txt (the whole NIGHT_TUNING it would make,
rewritten whenever the best improves; tools/lake_tuner_apply.sh puts it into the code).
"""
import datetime
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lake_suite  # noqa: E402

ROOT = lake_suite.ROOT
OUT = os.path.join(ROOT, ".sim_output", "lake_speed")
STATE = os.path.join(OUT, "tuner_state.json")
LEADERBOARD = os.path.join(OUT, "leaderboard.md")
BEST = os.path.join(ROOT, "Documentation", "reports", "autopilot", "lake_speed", "best.txt")
STOP_FILE = os.path.join(OUT, "STOP")
MIN_GAIN = 0.5
FIRST_STEP_SHARE = 0.25
SMALLEST_STEP_SHARE = 1.0 / 32.0

# (PlayerController field, lowest, highest), in the order they are tried. The starting value is the
# player's (NIGHT_TUNING, or the code's default where the night left it).
PARAMS = [
    # Getting going (Max: "better balance and control at low speeds")
    ("start_alpha_deg", 6.0, 90.0),
    ("start_help_until_ms", 4.0, 9.0),
    ("start_sheet_in_share", 0.0, 1.0),
    ("start_hike_share", 0.0, 1.4),
    ("start_rake_back", 0.0, 0.5),
    ("plane_head_up_deg", 0.0, 30.0),
    ("plane_head_up_from_twa_deg", 95.0, 125.0),
    # The nose dive in a strong wind at low speed
    ("nose_dive_bow_m", 0.0, 0.3),
    ("nose_dive_pitch_deg", 3.0, 20.0),
    ("nose_dive_below_ms", 4.0, 10.0),
    ("nose_dive_alpha_deg", 2.0, 16.0),
    ("nose_dive_rake_back", 0.0, 0.6),
    ("nose_dive_hold_s", 0.1, 1.5),
    # Across and downwind in the waves
    ("gust_bear_away_deg", 0.0, 15.0),
    ("gust_from_kt", 0.0, 3.0),
    ("gust_full_kt", 1.5, 6.0),
    ("chop_trim_aim_deg", -3.0, 4.0),
    ("chop_hike_drop", 0.0, 0.5),
    ("pilot_sheet_rate_per_s", 0.8, 3.0),
    ("airborne_alpha_deg", 2.0, 24.0),
    ("airborne_support_share", 0.15, 0.5),
    ("airborne_hold_s", 0.05, 0.8),
    ("airborne_helm_hold", 0.0, 1.0),
    ("airborne_wind_from_kt", 12.0, 26.0),
    ("airborne_wind_full_kt", 13.0, 30.0),
    # Getting on the plane and steering below it (last night's)
    ("plane_bear_away_deg", 0.0, 25.0),
    ("plane_bear_away_to_twa_deg", 100.0, 145.0),
    ("plane_help_full_ms", 2.0, 6.0),
    ("plane_help_until_ms", 6.0, 9.6),
    ("helm_rate_per_s", 1.0, 3.5),
    ("slow_rate_gain_scale", 0.3, 3.0),
    ("slow_integral_scale", 0.3, 3.0),
    ("slow_hold_scale", 0.4, 2.0),
    ("hold_lead_s", 0.0, 0.8),
    ("hold_rate_per_deg", 0.3, 1.5),
    ("hold_rate_limit_dps", 8.0, 30.0),
    ("rate_gain", 0.004, 0.025),
    ("rate_integral_gain", 0.005, 0.05),
    # The reflex (last night's)
    ("reflex_from_share", 0.5, 0.85),
    ("reflex_full_share", 0.75, 0.99),
    ("reflex_alpha_deg", 2.0, 14.0),
    ("reflex_bear_away_dps", 0.0, 16.0),
    ("reflex_hold_s", 0.1, 0.8),
]


def log(text):
    print(f"[{datetime.datetime.now():%H:%M:%S}] {text}", flush=True)


def code_defaults(project):
    """Every float field's default in player_controller.gd: {field: value}."""
    path = os.path.join(project, "windsurfer", "player_controller.gd")
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
    return {k: float(v) for k, v in re.findall(r"^var (\w+): float = (-?[\d.]+)\s*$", text, re.M)}


def night_tuning(project):
    return {o.split("=")[0][len("--controller."):]: float(o.split("=")[1]) for o in lake_suite.night_tuning_overrides(project)}


def overrides_of(values, start):
    """The numbers that differ from the player's starting set, as --controller.field=value."""
    return [f"--controller.{n}={values[n]:.6g}" for n, _lo, _hi in PARAMS if abs(values[n] - start[n]) > 1e-9]


def tuning_of(values, defaults, tuned):
    """The whole NIGHT_TUNING the values make: last night's entries, then every number off its code default."""
    out = dict(tuned)
    for name, _lo, _hi in PARAMS:
        if abs(values[name] - defaults[name]) > 1e-9:
            out[name] = values[name]
        else:
            out.pop(name, None)
    return out


def valid(v):
    return (v["reflex_from_share"] < v["reflex_full_share"] - 0.04 and v["gust_full_kt"] > v["gust_from_kt"] + 0.5
            and v["airborne_wind_full_kt"] > v["airborne_wind_from_kt"] + 0.5 and v["plane_help_until_ms"] > v["plane_help_full_ms"] + 0.5)


def falls_ok(summary, baseline):
    return all(s["falls"] <= baseline["scenarios"][n]["falls"] for n, s in summary["scenarios"].items())


def save_state(state):
    tmp = STATE + ".tmp"
    with open(tmp, "w", encoding="utf-8") as handle:
        json.dump(state, handle, indent=1)
    os.replace(tmp, STATE)


def write_best(state):
    best, base = state["best"], state["baseline"]
    lines = [
        "# The lake tuner's best set so far (tools/lake_tuner.py, 7 November 2026): the whole",
        "# PlayerController.NIGHT_TUNING it makes (tools/lake_tuner_apply.sh writes it into the code).",
        f"# Written {datetime.datetime.now():%Y-%m-%d %H:%M}; candidate {best['label']}; round {state['round']};"
        f" total cost {best['total']:.1f} (baseline {base['total']:.1f}; lower is better).",
        "# Per scenario (cost / falls), best against baseline:",
    ]
    for name in lake_suite.SCENARIOS:
        b, s = base["scenarios"][name], best["scenarios"][name]
        lines.append(f"#   {name:7s} {s['cost']:8.1f} / {s['falls']}   (baseline {b['cost']:8.1f} / {b['falls']})")
    lines.append("# Speed in the gusts, km/h (best; baseline): " + ", ".join(
        f"{k} {v} ({base['speeds'].get(k, '-')})" for k, v in best.get("speeds", {}).items()))
    lines.append("# The numbers, one per line:")
    for name, value in tuning_of(state["values"], state["defaults"], state["night_tuning"]).items():
        lines.append(f"--controller.{name}={value:.6g}")
    os.makedirs(os.path.dirname(BEST), exist_ok=True)
    with open(BEST, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(lines) + "\n")


def write_leaderboard(state):
    rows = state["history"]
    names = lake_suite.SCENARIOS
    lines = [
        "# The lake tuner's leaderboard (7 November 2026)", "",
        f"Updated {datetime.datetime.now():%Y-%m-%d %H:%M:%S}. Round {state['round']}, {len(rows)} candidates scored,"
        f" step share {state['step_share']:.4g}. Baseline total {state['baseline']['total']:.1f}, best"
        f" {state['best']['total']:.1f} ({state['best']['label']}). Lower is better; a fall costs 100. Kept: the new"
        " best (falls never above the baseline's in any scenario). The best set: Documentation/reports/autopilot/lake_speed/best.txt.",
        "", "Sorted by total (the 40 best), then every candidate in the order scored.", "",
    ]
    header = "| # | time | change | total | " + " | ".join(names) + " | falls | gust km/h | kept |"
    rule = "|---|---|---|---:|" + "---:|" * len(names) + "---:|---|---|"

    def row(r):
        cells = " | ".join(f"{r['scenarios'][n]['cost']:.1f}" for n in names)
        falls = sum(r["scenarios"][n]["falls"] for n in names)
        speeds = ", ".join(f"{v:.1f}" for v in r.get("speeds", {}).values())
        return f"| {r['label']} | {r['time']} | {r['change']} | {r['total']:.1f} | {cells} | {falls} | {speeds} | {'yes' if r['accepted'] else ''} |"

    lines += [header, rule] + [row(r) for r in sorted(rows, key=lambda r: r["total"])[:40]]
    lines += ["", "## Every candidate", "", header, rule] + [row(r) for r in rows]
    with open(LEADERBOARD, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(lines) + "\n")


def fresh_state(project):
    defaults = code_defaults(project)
    tuned = night_tuning(project)
    start = {n: tuned.get(n, defaults[n]) for n, _lo, _hi in PARAMS}
    for n, lo, hi in PARAMS:
        start[n] = min(max(start[n], lo), hi)
    return {"defaults": defaults, "night_tuning": tuned, "start": start, "values": dict(start),
            "step_share": FIRST_STEP_SHARE, "round": 1, "index": 0, "kept_this_round": 0, "counter": 0,
            "baseline": None, "best": None, "history": [], "converged": False}


def record(state, summary, change, accepted):
    state["history"].append({"label": summary["label"], "time": datetime.datetime.now().strftime("%d %H:%M"), "change": change,
                             "total": summary["total"], "scenarios": summary["scenarios"], "speeds": summary.get("speeds", {}),
                             "overrides": summary["overrides"], "accepted": accepted})


def main():
    options = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
    godot = options.get("godot") or os.environ.get("GODOT")
    project = os.path.abspath(options.get("project", os.path.join(ROOT, "Game")))
    cores = int(options.get("cores", "12"))
    out_root = os.path.join(OUT, "candidates")
    os.makedirs(OUT, exist_ok=True)
    if options.get("fresh") == "1" or not os.path.exists(STATE):
        state = fresh_state(project)
    else:
        with open(STATE, encoding="utf-8") as handle:
            state = json.load(handle)
        log(f"resumed: round {state['round']}, number {state['index']}, {len(state['history'])} candidates")
    log(f"project {project}, {cores} processes, {len(PARAMS)} numbers")
    if state["converged"]:
        log("already converged: nothing to do (--fresh=1 starts over)")
        return
    if state["baseline"] is None:
        summary = lake_suite.evaluate_many([("c0000", [])], godot, project, cores, out_root)[0]
        state["baseline"] = state["best"] = summary
        record(state, summary, "the player's set (baseline)", True)
        save_state(state)
        write_leaderboard(state)
        write_best(state)
        log(f"baseline total {summary['total']:.1f} in {summary['seconds']} s; gusts {summary['speeds']}")

    names = [p[0] for p in PARAMS]
    ranges = {n: (lo, hi) for n, lo, hi in PARAMS}
    while True:
        if os.path.exists(STOP_FILE):
            log("STOP file found: stopping")
            break
        if state["index"] >= len(names):
            if state["kept_this_round"] == 0:
                if state["step_share"] <= SMALLEST_STEP_SHARE + 1e-12:
                    state["converged"] = True
                    save_state(state)
                    log("a round at the smallest steps kept nothing: converged")
                    break
                state["step_share"] = max(state["step_share"] * 0.5, SMALLEST_STEP_SHARE)
                log(f"a round kept nothing: steps halved to {state['step_share']:.4g} of each range")
            state["round"] += 1
            state["index"] = 0
            state["kept_this_round"] = 0
            save_state(state)
            continue
        name = names[state["index"]]
        lo, hi = ranges[name]
        step = state["step_share"] * (hi - lo)
        now_value = state["values"][name]
        variants, changes = [], []
        for direction in (1.0, -1.0):
            value = min(max(now_value + direction * step, lo), hi)
            if abs(value - now_value) < 1e-9:
                continue
            values = dict(state["values"])
            values[name] = value
            if not valid(values):
                continue
            state["counter"] += 1
            variants.append((f"c{state['counter']:04d}", overrides_of(values, state["start"]), values))
            changes.append(f"{name} {now_value:.4g} -> {value:.4g}")
        if not variants:
            state["index"] += 1
            continue
        summaries = lake_suite.evaluate_many([(label, ov) for label, ov, _v in variants], godot, project, cores, out_root)
        best_i = -1
        for i, summary in enumerate(summaries):
            good = summary["total"] < state["best"]["total"] - MIN_GAIN and falls_ok(summary, state["baseline"])
            if good and (best_i < 0 or summary["total"] < summaries[best_i]["total"]):
                best_i = i
        for i, summary in enumerate(summaries):
            record(state, summary, changes[i], i == best_i)
            log(f"{summary['label']} {changes[i]}: total {summary['total']:.1f} (best {state['best']['total']:.1f})"
                f"{' KEPT' if i == best_i else ''} [{summary['seconds']} s] gusts {summary['speeds']}")
        if best_i >= 0:
            state["values"] = variants[best_i][2]
            state["best"] = summaries[best_i]
            state["kept_this_round"] += 1
            write_best(state)
        state["index"] += 1
        save_state(state)
        write_leaderboard(state)
    save_state(state)
    write_leaderboard(state)
    log(f"stopped: best {state['best']['label']} total {state['best']['total']:.1f} (baseline {state['baseline']['total']:.1f})")


if __name__ == "__main__":
    main()
