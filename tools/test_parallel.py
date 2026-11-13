"""The GUT tests split over several Godot processes at once (tools/test_parallel.sh runs this).

tools/test.sh runs every test file in one Godot, which keeps one of the processor's threads busy
(on Max's PC 1,113 unit tests took 7 minutes on one of sixteen threads). This deals the test files
into `jobs` lists, runs one Godot per list side by side, and adds up what they report.

The lists are balanced on each file's own time, from the last run (GUT's JUnit report of each list,
kept in .logs/tests/durations.json): the slowest file first, each to the list with the least work so
far. A file not timed yet counts by its size. Each list's full output is in .logs/tests/part_<n>.log.

    python -I tools/test_parallel.py --godot=<exe> --project=<Game folder> --logs=<folder>
        [--jobs=8] [--suite=unit|validation|all]
"""
import argparse
import json
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ElementTree
from pathlib import Path

# A file never timed: about this many seconds per kilobyte (the unit tests' median, 13 November 2026).
SECONDS_PER_KB_UNTIMED = 0.15


def test_files(project: Path, suite: str) -> list[str]:
    folders = ["unit", "validation"] if suite == "all" else [suite]
    files: list[str] = []
    for folder in folders:
        files += ["res://" + p.relative_to(project).as_posix() for p in sorted((project / "tests" / folder).rglob("test_*.gd"))]
    return files


def expected_seconds(script: str, project: Path, durations: dict[str, float]) -> float:
    if script in durations:
        return durations[script]
    return (project / script.removeprefix("res://")).stat().st_size / 1024.0 * SECONDS_PER_KB_UNTIMED


def deal(files: list[str], jobs: int, project: Path, durations: dict[str, float]) -> list[tuple[list[str], float]]:
    """The files into `jobs` lists of about the same time, the slowest first; with each list's time."""
    lists: list[list[str]] = [[] for _ in range(jobs)]
    loads = [0.0] * jobs
    for script in sorted(files, key=lambda s: expected_seconds(s, project, durations), reverse=True):
        lightest = loads.index(min(loads))
        lists[lightest].append(script)
        loads[lightest] += expected_seconds(script, project, durations)
    return [(part, load) for part, load in zip(lists, loads) if part]


def number(pattern: str, text: str) -> int:
    found = re.findall(pattern, text, re.MULTILINE)
    return int(found[-1]) if found else 0


def read_durations(path: Path) -> dict[str, float]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def times_from_report(report: Path) -> dict[str, float]:
    """Each test file's time from GUT's JUnit report (one testsuite per file)."""
    times: dict[str, float] = {}
    try:
        for suite in ElementTree.parse(report).getroot().iter("testsuite"):
            name = suite.get("name", "")
            times[name if name.startswith("res://") else "res://" + name] = float(suite.get("time", "0"))
    except (OSError, ElementTree.ParseError, ValueError):
        pass
    return times


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", required=True)
    parser.add_argument("--project", required=True)
    parser.add_argument("--jobs", type=int, default=8)
    parser.add_argument("--suite", default="unit", choices=["unit", "validation", "all"])
    parser.add_argument("--logs", required=True)
    args = parser.parse_args()
    project = Path(args.project)
    logs = Path(args.logs)
    logs.mkdir(parents=True, exist_ok=True)
    durations_file = logs / "durations.json"
    durations = read_durations(durations_file)
    parts = deal(test_files(project, args.suite), max(args.jobs, 1), project, durations)
    # GUT always reads a settings file, and the project's (Game/.gutconfig.json) lists whole folders,
    # which GUT would run on top of the list: each process gets one without folders.
    config = logs / "gutconfig_parts.json"
    config.write_text('{"dirs": [], "include_subdirs": true, "prefix": "test_", "suffix": ".gd", '
                      '"log_level": 1, "should_exit": true}', encoding="utf-8")
    print(f"{sum(len(p) for p, _ in parts)} test files over {len(parts)} Godot processes side by side "
          f"(the longest list expected to take {max(load for _, load in parts):.0f} s)")

    start = time.time()
    running = []
    for n, (part, _) in enumerate(parts, start=1):
        report = logs / f"part_{n}.xml"
        report.unlink(missing_ok=True)
        log = open(logs / f"part_{n}.log", "w", encoding="utf-8", errors="replace")
        command = [args.godot, "--headless", "--no-header", "--path", str(project),
                   "-s", "res://addons/gut/gut_cmdln.gd", f"-gconfig={config.resolve().as_posix()}",
                   f"-gtest={','.join(part)}", f"-gjunit_xml_file={report.resolve().as_posix()}",
                   "-gexit", "-gdisable_colors"]
        running.append((n, part, log, report, time.time(), subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)))

    # Each list's own time: when its Godot ends, whichever ends first.
    finished: dict[int, float] = {}
    while len(finished) < len(running):
        for n, _, _, _, started, process in running:
            if n not in finished and process.poll() is not None:
                finished[n] = time.time() - started
        time.sleep(0.2)
    totals = {"tests": 0, "passing": 0, "failing": 0, "pending": 0}
    failed_parts = []
    part_seconds = [finished[n] for n, *_ in running]
    for n, part, log, report, started, process in running:
        code = process.returncode
        log.close()
        durations.update(times_from_report(report))
        text = (logs / f"part_{n}.log").read_text(encoding="utf-8", errors="replace")
        tests = number(r"^Tests\s+(\d+)", text)
        passing = number(r"^Passing Tests\s+(\d+)", text)
        failing = number(r"^Failing Tests\s+(\d+)", text)
        pending = number(r"^Pending\s+(\d+)", text)
        for key, value in (("tests", tests), ("passing", passing), ("failing", failing), ("pending", pending)):
            totals[key] += value
        if code != 0 or failing > 0 or tests == 0:
            failed_parts.append(n)
            print(f"part {n} ({len(part)} files): exit {code}, {tests} tests, {failing} failing -> .logs/tests/part_{n}.log")
            for line in text.splitlines():
                if "[Failed]" in line or "SCRIPT ERROR" in line or line.startswith("ERROR"):
                    print("   ", line.strip()[:200])
    durations_file.write_text(json.dumps(durations, indent=1, sort_keys=True), encoding="utf-8")
    minutes = (time.time() - start) / 60.0
    print("the lists' times (s): " + ", ".join(f"{s:.0f}" for s in part_seconds))
    print(f"Tests {totals['tests']}, passing {totals['passing']}, failing {totals['failing']}, "
          f"pending {totals['pending']}, in {minutes:.1f} minutes")
    if failed_parts:
        print("---- Some tests failed (see above) ----")
        return 1
    print("---- All tests passed! ----")
    return 0


if __name__ == "__main__":
    sys.exit(main())
