#!/usr/bin/env python3
"""Writes a job list for tools/heads/pool.py: the skipper's suite on Lake Silvaplana (8 November 2026).

    python -I tools/heads/make_jobs.py --out=<folder> [--races=1] [--drops=6] [--seed=1] [--hours=12:00,14:00,16:30]
        [--wind_scale=1] [--skippers=allrounder] [--extra="--controller.x=1 ..."]

- races: every course on the lake, the skipper alone (or --skippers), at every hour of --hours, from a
  random spot round the start (--spawn=random, its seed from --seed), the whole race;
- drops: --drops per course, each on a random leg (the harness picks it from the drop seed) at a random
  hour between --drop_from and --drop_to (11:30 and 17:30), two steps to sail (rounding included);
- starts (--starts=N, with --races=0 --drops=0 for a start round): N per course, eight personas from random
  spots round the start (the game's spawn), the countdown and --after_gun seconds after the gun;
- fleet races (--fleet_races=N): N per course, the eight personas, the whole race (the rules, the shadows),
  the race ending --finish_window seconds after the first finisher.
Every seed gives other spots and hours, so a new --seed is a fresh test the skipper was never tuned on.
The jobs file is <out>/jobs.txt; each job's CSV tracks go to <out>/<label>/ (pool.py puts the folder in for @OUT@, as paths with spaces cannot be split).
"""
import os
import random
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))).replace("\\", "/")
# The start's fleet (--starts): eight personas, so the boards want different spots on the line.
FLEET = ["lena", "bruno", "liv", "kofi", "mara", "jonas", "hana", "elin"]
COURSES = ["iq_i2", "iq_lg2", "iq_lr2", "iq_o2", "iq_pd3", "iq_pm1", "iq_sd3", "iq_sm1", "iq_us3", "iq_us4", "t2_slalom"]


def read_options(argv):
    options = {}
    for arg in argv:
        if arg.startswith("--") and "=" in arg:
            key, value = arg[2:].split("=", 1)
            options[key] = value
    return options


def clock_minutes(text):
    hours, minutes = text.split(":")
    return int(hours) * 60 + int(minutes)


def main():
    o = read_options(sys.argv[1:])
    out = os.path.abspath(o["out"]).replace("\\", "/")
    os.makedirs(out, exist_ok=True)
    seed = int(o.get("seed", "1"))
    hours = o.get("hours", "12:00,14:00,16:30").split(",")
    scale = o.get("wind_scale", "1")
    skippers = o.get("skippers", "allrounder")
    extra = o.get("extra", "")
    courses = o.get("courses", ",".join(COURSES)).split(",")
    wind = "" if scale == "1" else " --lake_wind_scale=%s" % scale
    tag = "" if scale == "1" else "_x%s" % scale
    lines = []
    if o.get("races", "1") != "0":
        for course in courses:
            for k, hour in enumerate(hours):
                s = seed * 100 + k
                label = "race_%s_%s_s%d%s" % (course, hour.replace(":", ""), s, tag)
                lines.append("%s --course=%s --map=lake --time=%s --skippers=%s --spawn=random --spawn_seed=%d --seed=%d%s --out_dir=@OUT@/%s %s" % (
                    label, course, hour, skippers, s, s, wind, label, extra))
    starts = int(o.get("starts", "0"))
    fleet = o.get("fleet", ",".join("persona:" + n for n in FLEET))
    for course in courses if starts else []:
        for k in range(starts):
            s = seed * 10 + k
            hour = hours[k % len(hours)]
            label = "start_%s_%s_s%d%s" % (course, hour.replace(":", ""), s, tag)
            lines.append("%s --course=%s --map=lake --time=%s --skippers=%s --spawn=random --spawn_seed=%d --seed=%d --stop_after_gun=%s%s --out_dir=@OUT@/%s %s" % (
                label, course, hour, fleet, s, s, o.get("after_gun", "90"), wind, label, extra))
    fleet_races = int(o.get("fleet_races", "0"))
    for course in courses if fleet_races else []:
        for k in range(fleet_races):
            s = seed * 10 + k
            hour = hours[(courses.index(course) + k) % len(hours)]
            label = "fleet_%s_%s_s%d%s" % (course, hour.replace(":", ""), s, tag)
            lines.append("%s --course=%s --map=lake --time=%s --skippers=%s --spawn=random --spawn_seed=%d --seed=%d --finish_window=%s%s --out_dir=@OUT@/%s %s" % (
                label, course, hour, fleet, s, s, o.get("finish_window", "300"), wind, label, extra))
    drops = int(o.get("drops", "6"))
    rng = random.Random(seed)
    drop_from = clock_minutes(o.get("drop_from", "11:30"))
    drop_to = clock_minutes(o.get("drop_to", "17:30"))
    for course in courses:
        for k in range(drops):
            s = seed * 1000 + k
            minutes = rng.randrange(drop_from, drop_to + 1, 10)
            hour = "%02d:%02d" % (minutes // 60, minutes % 60)
            label = "drop_%s_%d%s" % (course, s, tag)
            lines.append("%s --course=%s --map=lake --time=%s --skippers=%s --drop_step=random --drop_seed=%d --seed=%d%s --out_dir=@OUT@/%s %s" % (
                label, course, hour, skippers, s, s, wind, label, extra))
    with open(os.path.join(out, "jobs.txt"), "w", encoding="utf-8") as handle:
        handle.write("\n".join(line.rstrip() for line in lines) + "\n")
    print("%d jobs in %s/jobs.txt" % (len(lines), out))


if __name__ == "__main__":
    main()
