"""The night run's summary (Documentation/reports/playtest/night_run_6nov.md): reads the logs under
.logs/night_6nov/ and writes Documentation/reports/playtest/night_run_6nov_results.md with one table
per part. Run from the repository root: python -I Documentation/reports/playtest/night_run_6nov.py
It can be run while the night run is still going: the parts without a log yet say so."""
import glob
import os
import re
import sys
import time

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
LOG = os.path.join(ROOT, ".logs", "night_6nov")
OUT = os.path.join(ROOT, "Documentation", "reports", "playtest", "night_run_6nov_results.md")


def read(name):
    path = os.path.join(LOG, name)
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()


def race_row(name, text):
    """One table row for a race log: finishers, DNF, falls, the first time, the start summary."""
    if text is None:
        return f"| {name} | (no log yet) | | | | | |"
    results = re.findall(r"^\s*(\d+)\.\s+(\S+)\s+(DNF|\d+:\d\d\.\d)\s.*?falls (\d+)", text, re.M)
    finishers = sum(1 for r in results if r[2] != "DNF")
    dnf = sum(1 for r in results if r[2] == "DNF")
    falls = sum(int(r[3]) for r in results)
    first = next((r[2] for r in results if r[2] != "DNF"), "-")
    stuck = len(re.findall(r"DNF.*?to mark \d+ \d+ m", text))
    start = re.search(r"longest start delay ([\d.]+) s, (\d+) not started, (\d+) OCS(?:, (\d+) outside the sailing area)?", text)
    start_text = f"{start.group(1)} s / {start.group(2)} / {start.group(3)} / {start.group(4) or 0}" if start else "-"
    return f"| {name} | {finishers} | {dnf} ({stuck} on the course) | {falls} | {first} | {start_text} |"


def matrix_row(name, text):
    if text is None:
        return f"| {name} | (no log yet) | |"
    falls = len(re.findall(r"\bfell\b|\bfall\b(?!s 0)", text))
    lines = [l for l in text.splitlines() if re.search(r"\bfall|catapult|fell", l, re.I)]
    return f"| {name} | {falls} lines mention a fall | {'; '.join(l.strip()[:80] for l in lines[:4])} |"


def main():
    parts = []
    parts.append("# The night run of 6 to 7 November 2026: the results\n")
    parts.append(f"Written by `night_run_6nov.py` on {time.strftime('%d %B %Y at %H:%M')} from the logs in `.logs/night_6nov/`. "
                 "What each part is for, and what a good result looks like, is in [night_run_6nov.md](night_run_6nov.md).\n")
    progress = read("00_progress.txt")
    parts.append("## Progress\n\n```\n" + (progress or "(no progress file)") + "\n```\n")

    parts.append("## A. The AI fleet on every iQFOiL course, by race type\n")
    parts.append("| Course | Finishers | DNF (of them stuck on the course) | Falls | First finisher | Longest start delay / not started / OCS / outside the area |")
    parts.append("|---|---|---|---|---|---|")
    for c in ["iq_pd3", "iq_sd3", "iq_lg2", "iq_lr2", "iq_o2", "iq_i2", "iq_us3", "iq_us4", "iq_pm1", "iq_sm1", "t2_slalom", "t1_loop"]:
        parts.append(race_row(c, read(f"race_{c}.log")))
    parts.append("\nSlalom: PD3, SD3, T2. Course race: LG2, LR2, O2, I2, T1. Hybrid: US3, US4, PM1, SM1.\n")

    parts.append("## B. The autopilot's recovery reflex, swept\n")
    table = read("reflex_table.txt")
    parts.append("```\n" + (table or "(no table yet)") + "\n```\n")

    parts.append("## C. The manoeuvres with the player's hands at 24 kt\n")
    parts.append("| Run | Falls | The lines |")
    parts.append("|---|---|---|")
    for name in ["matrix_all_24", "matrix_no_back_foot_24", "matrix_no_carve_24"]:
        parts.append(matrix_row(name, read(name + ".log")))
    parts.append("\nThe agent's evening numbers: hands-off 0, each part alone 0, everything at once 5 falls in 45.\n")

    parts.append("## D. The frame time on an idle PC\n")
    for name in ["fps_open", "fps_lake_12", "fps_lake_12_wide"]:
        text = read(name + ".log")
        if text is None:
            parts.append(f"- {name}: (no log yet)")
            continue
        lines = [l.strip() for l in text.splitlines() if re.search(r"fps|ms|frame", l, re.I)]
        parts.append(f"- {name}:\n```\n" + "\n".join(lines[-12:]) + "\n```")
    parts.append("")

    parts.append("## E. The validation suite\n")
    text = read("validation.log")
    if text is None:
        parts.append("(no log yet)\n")
    else:
        summary = re.search(r"Tests\s+\d+.*?Time\s+[\d.]+s", text, re.S)
        failing = sorted(set(re.findall(r"^\s*(?:\[Failed\]|\[FAILED\]|FAILED)?\s*(test_\w+)\s*$", text, re.M)))
        names = re.findall(r"^(test_[\w]+)\s*\n.*?(?:Failed|FAILED)", text, re.M | re.S)
        parts.append("```\n" + (summary.group(0) if summary else "(no summary)") + "\n```")
        fails = [l.strip() for l in text.splitlines() if re.search(r"\[Failed\]|FAILED|failed", l) and "Failing Tests" not in l]
        parts.append("The failing lines (the eight known reds are expected: compare with the autopilot report's checks):\n```\n" + "\n".join(fails[:40]) + "\n```\n")

    parts.append("## F. LAN on the release build\n")
    for name in ["lan_lake", "lan_lake_spectate_late"]:
        text = read(name + ".log")
        if text is None:
            parts.append(f"- {name}: (no log yet)")
            continue
        checks = [l.strip() for l in text.splitlines() if "SYNC CHECK" in l or "spectator" in l.lower() or "late" in l.lower() and "join" in l.lower()]
        parts.append(f"- {name}: " + ("; ".join(checks[-6:]) if checks else "(no SYNC CHECK line)"))
    parts.append("")

    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(parts))
    print("written", OUT)


if __name__ == "__main__":
    main()
