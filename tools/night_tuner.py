#!/usr/bin/env python3
"""The night's automatic tuner for the autopilot (the player's controller), 7 November 2026.

    python -I tools/night_tuner.py --godot=<Godot> [--project=<frozen copy of Game/>] [--cores=14]
                                   [--until=09:00] [--fresh=1]

Coordinate descent over the controller's numbers in PARAMS (each with its range): for one number at a
time it tries the best set so far with that number a step up and a step down, both scored by the night
suite (tools/night_suite.py) in one pool of Godot processes; the better one is kept when it lowers the
total cost by more than MIN_GAIN and has no more falls than the baseline in any scenario. When a whole
round over every number keeps nothing, the steps are halved. No AI in the loop.

It stops by itself at --until (local time) and is resumable: its state is in
.sim_output/night7nov/tuner_state.json, and running it again carries on from there (--fresh=1 starts
over). Every candidate goes into .sim_output/night7nov/leaderboard.md; the best set's overrides into
Documentation/reports/autopilot/night_7nov/best.txt, rewritten whenever it improves. To stop it before
its time: create the file .sim_output/night7nov/STOP (it stops after the candidate it is scoring).
"""
import datetime
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import night_suite  # noqa: E402

ROOT = night_suite.ROOT
OUT = os.path.join(ROOT, ".sim_output", "night7nov")
STATE = os.path.join(OUT, "tuner_state.json")
LEADERBOARD = os.path.join(OUT, "leaderboard.md")
BEST = os.path.join(ROOT, "Documentation", "reports", "autopilot", "night_7nov", "best.txt")
STOP_FILE = os.path.join(OUT, "STOP")
MIN_GAIN = 0.5
# The steps start at this share of each range and are halved after a round that keeps nothing.
FIRST_STEP_SHARE = 0.25
SMALLEST_STEP_SHARE = 0.03

# (name, the code's default, lowest, highest): the controller's numbers (PlayerController) the night may
# change. Grouped by Max's asks of 7 November 2026.
PARAMS = [
    # 3, Shift carve
    ("controller.sharp_turn_factor", 2.0, 1.5, 2.5),
    ("controller.sharp_rail_gain", 1.0, 0.4, 1.6),
    ("controller.sharp_manoeuvre_factor", 1.5, 1.0, 2.0),
    ("controller.sharp_cap_factor", 1.25, 1.0, 1.6),
    # 7, taps and controllability
    ("controller.steer_rise_s", 0.2, 0.0, 0.45),
    ("controller.steer_fall_s", 0.15, 0.0, 0.35),
    ("controller.tap_rail_full_s", 0.4, 0.0, 0.9),
    ("controller.helm_rate_per_s", 2.0, 1.0, 3.5),
    # 1, getting on the plane
    ("controller.plane_bear_away_deg", 0.0, 0.0, 25.0),
    ("controller.plane_bear_away_to_twa_deg", 125.0, 100.0, 145.0),
    ("controller.plane_help_until_ms", 8.5, 6.0, 9.6),
    # 2, steering below the plane (and the heading hold everywhere)
    ("controller.slow_rate_gain_scale", 1.0, 0.3, 3.0),
    ("controller.slow_integral_scale", 1.0, 0.3, 3.0),
    ("controller.slow_hold_scale", 1.0, 0.4, 2.0),
    ("controller.hold_lead_s", 0.3, 0.0, 0.8),
    ("controller.hold_rate_per_deg", 0.8, 0.3, 1.5),
    ("controller.hold_rate_limit_dps", 20.0, 8.0, 30.0),
    ("controller.rate_gain", 0.01, 0.004, 0.025),
    ("controller.rate_integral_gain", 0.02, 0.005, 0.05),
    ("controller.carve_rate_dps", 57.0, 35.0, 80.0),
    ("controller.head_up_rate_budget_dps_ms", 100.0, 60.0, 160.0),
    # 4, flying
    ("controller.airborne_helm_hold", 0.0, 0.0, 1.0),
    ("controller.airborne_alpha_deg", 6.0, 2.0, 14.0),
    ("controller.airborne_support_share", 0.3, 0.15, 0.5),
    ("controller.airborne_hold_s", 0.3, 0.05, 0.8),
    # 5, the reflex
    ("controller.reflex_from_share", 0.65, 0.5, 0.85),
    ("controller.reflex_full_share", 0.9, 0.75, 0.99),
    ("controller.reflex_alpha_deg", 6.0, 2.0, 14.0),
    ("controller.reflex_bear_away_dps", 8.0, 0.0, 16.0),
    ("controller.reflex_hold_s", 0.3, 0.1, 0.8),
    # 6, faster tacks and gybes
    ("controller.key_gybe_rate_dps", 40.0, 28.0, 60.0),
    ("controller.key_tack_rate_dps", 20.0, 14.0, 30.0),
    ("controller.gybe_rate_max_dps", 40.0, 32.0, 60.0),
    ("controller.tack_rate_max_dps", 20.0, 15.0, 30.0),
    ("controller.gybe_entry_alpha_deg", 8.0, 3.0, 15.0),
    ("controller.settle_rate_dps", 15.0, 6.0, 25.0),
]


def log(text):
    stamp = datetime.datetime.now().strftime("%H:%M:%S")
    print(f"[{stamp}] {text}", flush=True)


def overrides_of(values):
    """Only the numbers that differ from the code's defaults, as --group.field=value."""
    out = []
    for name, default, _lo, _hi in PARAMS:
        if abs(values[name] - default) > 1e-9:
            out.append(f"--{name}={values[name]:.6g}")
    return out


def valid(values):
    return values["controller.reflex_from_share"] < values["controller.reflex_full_share"] - 0.04


def deadline(until_text):
    now = datetime.datetime.now()
    hour, minute = (int(x) for x in until_text.split(":"))
    end = now.replace(hour=hour, minute=minute, second=0, microsecond=0)
    if end <= now:
        end += datetime.timedelta(days=1)
    return end


def falls_ok(summary, baseline):
    for name, s in summary["scenarios"].items():
        if s["falls"] > baseline["scenarios"][name]["falls"]:
            return False
    return True


def save_state(state):
    tmp = STATE + ".tmp"
    with open(tmp, "w", encoding="utf-8") as handle:
        json.dump(state, handle, indent=1)
    os.replace(tmp, STATE)


def write_best(state):
    best = state["best"]
    lines = [
        "# The night tuner's best set so far (tools/night_tuner.py, 7 November 2026).",
        f"# Written {datetime.datetime.now():%Y-%m-%d %H:%M}; candidate {best['label']}; total cost {best['total']:.1f}"
        f" (baseline {state['baseline']['total']:.1f}; lower is better).",
        "# Per scenario (cost / falls), best against baseline:",
    ]
    for name in night_suite.SCENARIOS:
        b = state["baseline"]["scenarios"][name]
        s = best["scenarios"][name]
        lines.append(f"#   {name:7s} {s['cost']:8.1f} / {s['falls']}   (baseline {b['cost']:8.1f} / {b['falls']})")
    lines.append("# The overrides (PlayerController's numbers that differ from the code's defaults), one per line:")
    lines.extend(overrides_of(state["values"]) or ["# (none: the defaults are still the best)"])
    os.makedirs(os.path.dirname(BEST), exist_ok=True)
    with open(BEST, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(lines) + "\n")


def write_leaderboard(state):
    rows = state["history"]
    lines = [
        "# The night tuner's leaderboard (7 November 2026)",
        "",
        f"Updated {datetime.datetime.now():%H:%M:%S}. Round {state['round']}, {len(rows)} candidates scored."
        f" Baseline total {state['baseline']['total']:.1f}, best {state['best']['total']:.1f} ({state['best']['label']})."
        " Lower is better; a fall costs 100. Accepted: kept as the new best (falls never above the baseline's"
        " in any scenario). The best set's overrides: Documentation/reports/autopilot/night_7nov/best.txt.",
        "",
        "Sorted by total (the 40 best), then every candidate in the order scored.",
        "",
    ]
    header = "| # | time | change | total | " + " | ".join(night_suite.SCENARIOS) + " | falls | kept |"
    rule = "|---|---|---|---:|" + "---:|" * len(night_suite.SCENARIOS) + "---:|---|"

    def row(r):
        cells = " | ".join(f"{r['scenarios'][n]['cost']:.1f}" for n in night_suite.SCENARIOS)
        falls = sum(r["scenarios"][n]["falls"] for n in night_suite.SCENARIOS)
        return f"| {r['label']} | {r['time']} | {r['change']} | {r['total']:.1f} | {cells} | {falls} | {'yes' if r['accepted'] else ''} |"

    lines += [header, rule] + [row(r) for r in sorted(rows, key=lambda r: r["total"])[:40]]
    lines += ["", "## Every candidate", "", header, rule] + [row(r) for r in rows]
    lines += ["", "## The numbers of each kept candidate", ""]
    for r in rows:
        if r["accepted"] or r["label"] == "c0000":
            lines.append(f"- {r['label']}: {' '.join(r['overrides']) or '(the defaults)'}")
    with open(LEADERBOARD, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(lines) + "\n")


def fresh_state():
    return {
        "values": {name: default for name, default, _lo, _hi in PARAMS},
        "steps": {name: FIRST_STEP_SHARE * (hi - lo) for name, _d, lo, hi in PARAMS},
        "round": 1,
        "index": 0,
        "kept_this_round": 0,
        "counter": 0,
        "baseline": None,
        "best": None,
        "history": [],
    }


def record(state, summary, change, accepted):
    state["history"].append({
        "label": summary["label"], "time": datetime.datetime.now().strftime("%H:%M"), "change": change,
        "total": summary["total"], "scenarios": summary["scenarios"], "overrides": summary["overrides"],
        "accepted": accepted,
    })


def main():
    options = {}
    for arg in sys.argv[1:]:
        if arg.startswith("--") and "=" in arg:
            key, value = arg[2:].split("=", 1)
            options[key] = value
    godot = options.get("godot") or os.environ.get("GODOT")
    project = os.path.abspath(options.get("project", os.path.join(ROOT, "Game")))
    cores = int(options.get("cores", "14"))
    end = deadline(options.get("until", "09:00"))
    out_root = os.path.join(OUT, "candidates")
    os.makedirs(OUT, exist_ok=True)
    if options.get("fresh") == "1" or not os.path.exists(STATE):
        state = fresh_state()
    else:
        with open(STATE, encoding="utf-8") as handle:
            state = json.load(handle)
        log(f"resumed: round {state['round']}, number {state['index']}, {len(state['history'])} candidates")
    log(f"project {project}, {cores} processes, until {end:%H:%M}")

    if state["baseline"] is None:
        summary = night_suite.evaluate_many([("c0000", overrides_of(state["values"]))], godot, project, cores, out_root)[0]
        state["baseline"] = summary
        state["best"] = summary
        record(state, summary, "the defaults (baseline)", True)
        save_state(state)
        write_leaderboard(state)
        write_best(state)
        log(f"baseline total {summary['total']:.1f} in {summary['seconds']} s")

    names = [p[0] for p in PARAMS]
    ranges = {name: (lo, hi) for name, _d, lo, hi in PARAMS}
    while datetime.datetime.now() < end:
        if os.path.exists(STOP_FILE):
            log("STOP file found: stopping")
            break
        if state["index"] >= len(names):
            if state["kept_this_round"] == 0:
                for name in names:
                    state["steps"][name] *= 0.5
                log("a round kept nothing: steps halved")
            state["round"] += 1
            state["index"] = 0
            state["kept_this_round"] = 0
            save_state(state)
            if all(state["steps"][n] < SMALLEST_STEP_SHARE * (ranges[n][1] - ranges[n][0]) for n in names):
                log("every step is at its smallest: done")
                break
            continue
        name = names[state["index"]]
        lo, hi = ranges[name]
        step = state["steps"][name]
        now_value = state["values"][name]
        variants = []
        changes = []
        for direction in (1.0, -1.0):
            value = min(max(now_value + direction * step, lo), hi)
            if abs(value - now_value) < 1e-9:
                continue
            values = dict(state["values"])
            values[name] = value
            if not valid(values):
                continue
            state["counter"] += 1
            variants.append((f"c{state['counter']:04d}", overrides_of(values), values))
            changes.append(f"{name.split('.', 1)[1]} {now_value:.4g} -> {value:.4g}")
        if not variants:
            state["index"] += 1
            continue
        summaries = night_suite.evaluate_many([(label, ov) for label, ov, _v in variants], godot, project, cores, out_root)
        best_i = -1
        for i, summary in enumerate(summaries):
            good = summary["total"] < state["best"]["total"] - MIN_GAIN and falls_ok(summary, state["baseline"])
            if good and (best_i < 0 or summary["total"] < summaries[best_i]["total"]):
                best_i = i
        for i, summary in enumerate(summaries):
            record(state, summary, changes[i], i == best_i)
            log(f"{summary['label']} {changes[i]}: total {summary['total']:.1f} (best {state['best']['total']:.1f})"
                f"{' KEPT' if i == best_i else ''} [{summary['seconds']} s]")
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
