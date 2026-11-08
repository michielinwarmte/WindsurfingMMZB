#!/usr/bin/env python3
"""Runs many headless Godot jobs side by side (the skipper's heads, 8 November 2026).

    python -I tools/heads/pool.py --jobs=<jobs.txt> --out=<folder> [--cores=14] [--script=res://dev/run_race.gd] [--low=1]

Each line of the jobs file is "<label> <arguments for the script>" (lines starting with # are skipped).
Every job runs as one headless Godot process on the project in Game/ (Godot from $GODOT), its output in
<out>/<label>.log. Jobs whose log already ends with a finished run are skipped, so a pool that was
stopped carries on where it was. One line per finished job on the screen.
"""
import concurrent.futures
import os
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DEFAULT_GODOT = "C:/Users/Max de Dikke/AppData/Local/Programs/Godot/4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe"
DONE_MARK = "HEADS_DONE"
# --low=1: the jobs run below normal priority (Windows), so they only use what other pools leave free.
LOW_PRIORITY = False


def read_options(argv):
    options = {}
    for arg in argv:
        if arg.startswith("--") and "=" in arg:
            key, value = arg[2:].split("=", 1)
            options[key] = value
    return options


def read_jobs(path):
    jobs = []
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            label, _, args = line.partition(" ")
            jobs.append((label, args.split()))
    return jobs


def already_done(log_path):
    if not os.path.exists(log_path):
        return False
    with open(log_path, encoding="utf-8", errors="replace") as handle:
        return DONE_MARK in handle.read()


def run_one(godot, project, script, label, args, out_dir, timeout_s):
    log_path = os.path.join(out_dir, label + ".log")
    if already_done(log_path):
        return label, "skipped", 0.0
    started = time.time()
    args = [arg.replace("@OUT@", os.path.abspath(out_dir).replace("\\", "/")) for arg in args]
    command = [godot, "--headless", "--no-header", "--path", project, "-s", script, "--"] + args
    with open(log_path, "w", encoding="utf-8", errors="replace") as log:
        try:
            flags = getattr(subprocess, "BELOW_NORMAL_PRIORITY_CLASS", 0) if LOW_PRIORITY else 0
            result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, timeout=timeout_s, creationflags=flags)
            status = "exit %d" % result.returncode
        except subprocess.TimeoutExpired:
            status = "timeout"
        log.write("\n%s %s %.0f s\n" % (DONE_MARK, status, time.time() - started))
    return label, status, time.time() - started


def main():
    options = read_options(sys.argv[1:])
    godot = os.environ.get("GODOT", DEFAULT_GODOT)
    project = options.get("project", os.path.join(ROOT, "Game"))
    script = options.get("script", "res://dev/run_race.gd")
    out_dir = options["out"]
    cores = int(options.get("cores", "14"))
    timeout_s = float(options.get("timeout", "5400"))
    global LOW_PRIORITY
    LOW_PRIORITY = options.get("low", "0") == "1"
    os.makedirs(out_dir, exist_ok=True)
    jobs = read_jobs(options["jobs"])
    print("%d jobs, %d at a time, logs in %s" % (len(jobs), cores, out_dir), flush=True)
    started = time.time()
    with concurrent.futures.ThreadPoolExecutor(max_workers=cores) as pool:
        futures = [pool.submit(run_one, godot, project, script, label, args, out_dir, timeout_s) for label, args in jobs]
        for done, future in enumerate(concurrent.futures.as_completed(futures), 1):
            label, status, seconds = future.result()
            print("%3d/%d %-40s %-10s %5.0f s" % (done, len(jobs), label, status, seconds), flush=True)
    print("POOL_DONE %d jobs in %.0f s" % (len(jobs), time.time() - started), flush=True)


if __name__ == "__main__":
    main()
