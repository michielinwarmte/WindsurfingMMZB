#!/usr/bin/env python3
"""The autopilot's test suite, run as one pool of Godot processes (tools/autopilot_suite.sh calls it).

    tools/autopilot_suite.sh --round=lc1 --variants=Documentation/reports/autopilot/rounds/lc1.txt
    tools/autopilot_suite.sh --round=lc1 --variants=... --only=lake --cores=14
    tools/autopilot_suite.sh --round=lc9 --variants=... --only=lake --lake_wave_scale=1.5
    tools/autopilot_suite.sh ... --matrix_times=12:00,13:15,14:30,15:45,17:00   (more lake patterns)

Every variant (a line "<label>: <overrides>" of the variants file) is scored by the parts in --only
(default reach,push,pushed,matrix,lake; race on request):

- reach   the reach check: nine flat-water reaches (12, 18, 24 kt at 60, 100, 135 degrees), 90 s
          each, the means from 60 s (Game/dev/run_reach.gd) -> reach.txt and reach/*.csv
- push    the push check in the open water's gusts and waves at the neutral dial: nine cases of
          120 s (Game/dev/run_push.gd) -> push_neutral.txt
- pushed  the same at the pushed dial (--pilot.hike_share=1.6), 18 and 24 kt -> push_pushed.txt
- matrix  the manoeuvre matrix on the open water (Game/dev/run_matrix.gd) -> matrix.txt
- lake    Lake Silvaplana on its own waves (Game/dev/run_lake.gd --lake_waves=1):
            lake_afternoons.txt  the beam reach, the broad reach and the broad reach from the middle
                                 at ten times of day (12:30 to 17:00), the map's wind
            lake_map.txt         every manoeuvre of the lake matrix at 12:00, 14:30 and 17:00, the
                                 map's wind
            lake_steady18.txt    every manoeuvre in a steady 18 kt (the lake's mean direction of
            lake_steady24.txt    12:00, 14:30 and 17:00: three wave patterns), and in a steady 24 kt
- race    a race on T2 on the lake with four AI skippers (Game/dev/run_race.gd --map=lake) at
          14:30 and 16:00 -> race_1430.txt, race_1600.txt

The overrides are the harnesses' --pilot.<field>=, --controller.<field>=, --sailor.<field>=,
--sail.<field>=, --board.<field>= and --fin.<field>= settings (each harness takes the groups it
knows). Everything lands in .sim_output/autopilot/<round>/<label>/, and
tools/autopilot_summary.py <round> reads it (--table: one line per variant).
"""
import os
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT = os.path.join(ROOT, "Game")
AFTERNOON_TIMES = ["12:30", "13:00", "13:30", "14:00", "14:30", "15:00", "15:30", "16:00", "16:30", "17:00"]
MATRIX_TIMES = ["12:00", "14:30", "17:00"]
STEADY_KTS = ["18", "24"]
RACE_TIMES = ["14:30", "16:00"]
RACE_SKIPPERS = "allrounder,cautious,gambler,rookie"
ALL_PARTS = "reach,push,pushed,matrix,lake"
# Which override groups each harness takes.
GROUPS = {
    "reach": ("pilot", "sailor", "sail", "board", "fin"),
    "push": ("pilot", "sailor", "sail", "board", "controller"),
    "matrix": ("pilot", "sailor", "sail", "controller"),
    "lake": ("pilot", "sailor", "sail", "controller"),
    "race": ("pilot", "controller"),
}
JOB_TIMEOUT_S = 2400


class Job:
    def __init__(self, label, script, args, out_path, weight):
        self.label = label
        self.script = script
        self.args = args
        self.out_path = out_path
        self.weight = weight
        self.process = None
        self.started = 0.0
        self.handle = None


def parse_args(argv):
    options = {"only": ALL_PARTS, "cores": "14", "lake_wave_scale": ""}
    for arg in argv:
        if arg.startswith("--") and "=" in arg:
            key, value = arg[2:].split("=", 1)
            options[key] = value
        else:
            print("Unknown option: %s" % arg, file=sys.stderr)
            sys.exit(2)
    for key in ("round", "variants", "godot"):
        if not options.get(key):
            print(__doc__)
            sys.exit(2)
    return options


def read_variants(path):
    text = sys.stdin.read() if path == "-" else open(path, encoding="utf-8").read()
    variants = []
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#") or ":" not in line:
            continue
        label, overrides = line.split(":", 1)
        variants.append((label.strip(), overrides.split()))
    return variants


def only_groups(overrides, part):
    keep = GROUPS[part]
    return [o for o in overrides if o.startswith("--") and o[2:].split(".", 1)[0] in keep]


def jobs_for(label, overrides, out_dir, parts, scale_args):
    jobs = []
    reach_over = only_groups(overrides, "reach")
    if "reach" in parts and not reach_over and label != "base":
        # The reach check sails the Autopilot itself: a variant of only --controller. settings sails it
        # exactly as the defaults do, so it is not run again (the summary says so).
        open(os.path.join(out_dir, "reach_as_base.txt"), "w", encoding="utf-8").write("the reach check is the defaults' (no setting reaches it)" + chr(10))
    elif "reach" in parts:
        os.makedirs(os.path.join(out_dir, "reach"), exist_ok=True)
        jobs.append(Job(label, "res://dev/run_reach.gd",
                        ["--seconds=90", "--from=60", "--out_dir=" + os.path.join(out_dir, "reach")] + reach_over,
                        os.path.join(out_dir, "reach.txt"), 810))
    for part, winds, cases, extra in (("push", "12,18,24", 9, []), ("pushed", "18,24", 6, ["--pilot.hike_share=1.6"])):
        if part not in parts:
            continue
        push_dir = os.path.join(out_dir, part)
        os.makedirs(push_dir, exist_ok=True)
        for i in range(cases):
            jobs.append(Job(label, "res://dev/run_push.gd",
                            ["--winds=" + winds, "--seconds=120", "--slice=%d/%d" % (i, cases),
                             "--out=" + os.path.join(push_dir, "results_%d.csv" % i),
                             "--falls_out=" + os.path.join(push_dir, "falls_%d.csv" % i),
                             "--label=" + label] + extra + only_groups(overrides, "push"),
                            os.path.join(push_dir, "log_%d.txt" % i), 160))
    if "matrix" in parts:
        matrix_dir = os.path.join(out_dir, "matrix")
        os.makedirs(matrix_dir, exist_ok=True)
        for kt in ("12", "18", "24"):
            jobs.append(Job(label, "res://dev/run_matrix.gd",
                            ["--winds=" + kt, "--out_dir=" + matrix_dir] + only_groups(overrides, "matrix"),
                            os.path.join(matrix_dir, "matrix_%s.txt" % kt), 330))
    if "lake" in parts:
        lake_dir = os.path.join(out_dir, "lake")
        os.makedirs(lake_dir, exist_ok=True)
        lake_over = only_groups(overrides, "lake")
        for t in AFTERNOON_TIMES:
            jobs.append(Job(label, "res://dev/run_lake.gd",
                            ["--lake_waves=1", "--times=" + t, "--only=straight,broad"] + scale_args + lake_over,
                            os.path.join(lake_dir, "afternoons_%s.txt" % t.replace(":", "")), 125))
        for t in MATRIX_TIMES:
            jobs.append(Job(label, "res://dev/run_lake.gd",
                            ["--lake_waves=1", "--times=" + t] + scale_args + lake_over,
                            os.path.join(lake_dir, "map_%s.txt" % t.replace(":", "")), 420))
            for kt in STEADY_KTS:
                jobs.append(Job(label, "res://dev/run_lake.gd",
                                ["--lake_waves=1", "--times=" + t, "--wind=steady", "--kt=" + kt] + scale_args + lake_over,
                                os.path.join(lake_dir, "steady%s_%s.txt" % (kt, t.replace(":", ""))), 420))
    if "race" in parts:
        race_over = only_groups(overrides, "race")
        for i, t in enumerate(RACE_TIMES):
            race_dir = os.path.join(out_dir, "race_%s" % t.replace(":", ""))
            os.makedirs(race_dir, exist_ok=True)
            jobs.append(Job(label, "res://dev/run_race.gd",
                            ["--course=t2_slalom", "--skippers=" + RACE_SKIPPERS, "--map=lake", "--time=" + t,
                             "--seed=%d" % (i + 1), "--finish_window=600", "--out_dir=" + race_dir] + scale_args + race_over,
                            os.path.join(out_dir, "race_%s.txt" % t.replace(":", "")), 2400))
    return jobs


def start(job, godot):
    job.handle = open(job.out_path, "w", encoding="utf-8")
    command = [godot, "--headless", "--no-header", "--path", PROJECT, "-s", job.script, "--"] + job.args
    job.process = subprocess.Popen(command, stdout=job.handle, stderr=subprocess.STDOUT, cwd=ROOT)
    job.started = time.time()


def run_pool(jobs, godot, cores):
    waiting = sorted(jobs, key=lambda j: -j.weight)
    running = []
    done = 0
    total = len(jobs)
    began = time.time()
    while waiting or running:
        while waiting and len(running) < cores:
            job = waiting.pop(0)
            start(job, godot)
            running.append(job)
        time.sleep(0.5)
        for job in list(running):
            code = job.process.poll()
            if code is None and time.time() - job.started > JOB_TIMEOUT_S:
                job.process.kill()
                job.process.wait()
                job.handle.write("\nJOB TIMED OUT after %d s\n" % JOB_TIMEOUT_S)
                code = -1
            if code is not None:
                job.handle.close()
                running.remove(job)
                done += 1
                if done % 20 == 0 or done == total:
                    print("  %d of %d jobs done (%.0f s)" % (done, total, time.time() - began), flush=True)


def lines_of(path):
    if not os.path.exists(path):
        return []
    return open(path, encoding="utf-8", errors="replace").read().splitlines()


def merge_push(push_dir, cases, target):
    out = []
    first = lines_of(os.path.join(push_dir, "log_0.txt"))
    out.extend(first[:2])
    import re
    for i in range(cases):
        for line in lines_of(os.path.join(push_dir, "log_%d.txt" % i)):
            if re.match(r"^ *[0-9]+ +[0-9]+ ", line):
                out.append(line)
    open(target, "w", encoding="utf-8").write("\n".join(out) + "\n")


def merge_matrix(matrix_dir, target):
    import re
    out = []
    totals = [0, 0, 0, 0]
    for kt in ("12", "18", "24"):
        for line in lines_of(os.path.join(matrix_dir, "matrix_%s.txt" % kt)):
            m = re.match(r"(\d+) cases: (\d+) with a fall, (\d+) with NaN, (\d+) manoeuvres not completed", line)
            if m:
                for k in range(4):
                    totals[k] += int(m.group(k + 1))
            elif re.match(r"^[a-z_]+ +\d+ \|", line):
                out.append(line)
    out.append("%d cases: %d with a fall, %d with NaN, %d manoeuvres not completed" % tuple(totals))
    open(target, "w", encoding="utf-8").write("\n".join(out) + "\n")


def merge_lake(lake_dir, out_dir):
    import re
    groups = {"afternoons": ["afternoons_%s.txt" % t.replace(":", "") for t in AFTERNOON_TIMES],
              "map": ["map_%s.txt" % t.replace(":", "") for t in MATRIX_TIMES]}
    for kt in STEADY_KTS:
        groups["steady" + kt] = ["steady%s_%s.txt" % (kt, t.replace(":", "")) for t in MATRIX_TIMES]
    for name, files in groups.items():
        out = []
        for f in files:
            for line in lines_of(os.path.join(lake_dir, f)):
                if re.match(r"^[a-z_]+ +\d\d:\d\d ", line) or "JOB TIMED OUT" in line or "SCRIPT ERROR" in line:
                    out.append(line)
        if any(os.path.exists(os.path.join(lake_dir, f)) for f in files):
            open(os.path.join(out_dir, "lake_%s.txt" % name), "w", encoding="utf-8").write("\n".join(out) + "\n")


def main():
    global MATRIX_TIMES
    options = parse_args(sys.argv[1:])
    if options.get("matrix_times"):
        # More times of day for the lake's matrix and the steady winds: more wave and gust patterns.
        MATRIX_TIMES = options["matrix_times"].split(",")
    parts = set(options["only"].split(","))
    cores = max(int(options["cores"]), 1)
    scale_args = ["--lake_wave_scale=" + options["lake_wave_scale"]] if options["lake_wave_scale"] else []
    round_dir = os.path.join(ROOT, ".sim_output", "autopilot", options["round"])
    variants = read_variants(options["variants"])
    jobs = []
    for label, overrides in variants:
        out_dir = os.path.join(round_dir, label)
        os.makedirs(out_dir, exist_ok=True)
        open(os.path.join(out_dir, "overrides.txt"), "w", encoding="utf-8").write(" ".join(overrides) + "\n")
        if scale_args:
            open(os.path.join(out_dir, "lake_wave_scale.txt"), "w", encoding="utf-8").write(options["lake_wave_scale"] + "\n")
        jobs.extend(jobs_for(label, overrides, out_dir, parts, scale_args))
    print("=== %s: %d variants, %d jobs on %d cores (%s)" % (options["round"], len(variants), len(jobs), cores, ",".join(sorted(parts))), flush=True)
    run_pool(jobs, options["godot"], cores)
    for label, _overrides in variants:
        out_dir = os.path.join(round_dir, label)
        if "push" in parts:
            merge_push(os.path.join(out_dir, "push"), 9, os.path.join(out_dir, "push_neutral.txt"))
        if "pushed" in parts:
            merge_push(os.path.join(out_dir, "pushed"), 6, os.path.join(out_dir, "push_pushed.txt"))
        if "matrix" in parts:
            merge_matrix(os.path.join(out_dir, "matrix"), os.path.join(out_dir, "matrix.txt"))
        if "lake" in parts:
            merge_lake(os.path.join(out_dir, "lake"), out_dir)
    print("ROUND_DONE %s" % options["round"], flush=True)


if __name__ == "__main__":
    main()
