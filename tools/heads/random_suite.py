#!/usr/bin/env python3
"""The random suite (Max, 8 November 2026: "the AI needs to be able to do all kinds of races in all conditions").

Every run draws its own race, so the skipper is never tuned to a few fixed ones, and every board is judged by
checks that must always hold (not by who wins), with every mark rounding measured:

    python -I tools/heads/random_suite.py --run=<name> [--count=200] [--seed=1] [--cores=8]
        [--project=<a frozen copy>/Game] [--cpu_mask=0x5555] [--set=tune|holdout] [--phase=A|B|S|S3]
        [--extra="--skipper.<switch>=1 ..."]

  --phase=A      one general head on every board (the default): a persona at its best with steady hands
  --phase=B      the personas and characters: any of the 20 personas or the 4 characters, at the game's level (0.5)
  --phase=S      the starts (Max, 9 November 2026): the general head, start-only races (run_race --start_only=1: the
                 race ends once the board is over the line, or 60 s after the gun), only drops that reach the line
                 with 30 s to spare (--start_spare_s=30; a drop too far prints DROP_TOO_FAR and is drawn again), R in
                 20 % of the races in the countdown or up to 2 minutes after the gun; checks: start, stuck, aground,
                 falls (none at all)
  --phase=S3     the starts in company (Max, 10 November 2026: "train with 3 players because now sometimes in testing
                 they get stuck in eachother. and to train with dirty wind from the other players"; "we want the
                 fastest skipper"): phase S's races with three copies of the general head, each with its own start spot
                 drawn at random (--start_spots), the rules and the wind shadows on (the race tool's defaults), each
                 watched to 30 s after the gun (--start_follow_s=30) for the start's score: how far up the course it is
                 then (score_m); every board judged on its own
  --extra="..."  arguments added to every race (an A/B: the same --seed and --set with and without a switch)

Speed (measured 8 November 2026 on the 8-core Ryzen 7 5800X3D, one board, the editor engine): 4.0x real time alone,
4.2x each with 8 side by side on one logical processor per core (mask 0x5555; about 55 % CPU, 33x real time
together), 3.1x each with 12 on 12 logical processors (82 % CPU, 37x together: two jobs share a core). So 8 on 0x5555.
The game's release engine is no faster (about 3x with its scene) and cannot run this script.

  --set=tune     draws from the seeds the skipper may be tuned on (the default)
  --set=holdout  draws from seeds that are never used for tuning: a fix counts only if these get better

What a run draws (the plan agreed with Max, 8 November 2026):
  water        lake 80 %, open water 20 %
  course       lake: a saved course 40 %, the same shifted up to 50 m and turned up to 10 deg 30 %, a new course laid
               by the course fitter anywhere it fits 30 %; open water: T1, the iQFOiL templates at 50 % and 100 %
  wind         lake: an hour from 11:00 to 18:00 times 0.7 to 1.4, redrawn when under 14 kt (no planing, no
               information); open water: 14 to 26 kt
  countdown    2, 3 or 5 minutes
  start        the game's start box, behind the line, or anywhere round the course
  who          phase A: one general head (a persona at its best with steady hands); the personas come later
  R            in 20 % of the runs, at a random moment (the countdown, mid-race, after the finish)

The checks, per board: it starts in time (no later than the way from where it was allows, plus 20 s); it is never
stuck (under 1 m/s on the board) for more than 20 s; it never runs aground; it finishes; every leg within 1.4 times
the leg's expected time plus 30 s; the race within 1.25 times the expected plus 60 s; at most one fall per 5 minutes.
At every mark and gate: the closest approach, the distance out of the turn, the overstand of the layline on a beat
into it, the extra turning in a gate. Every failure keeps the command that replays it.

Writes .sim_output/suite/<run>/: jobs.txt, logs/, the boards' CSV files, results.jsonl, status.json, viewer.html;
and .sim_output/suite/viewer.html, the page of the run going now (it reloads itself; closing it stops nothing).
"""
import concurrent.futures
import ctypes
import html
import json
import math
import os
import random
import re
import statistics
import subprocess
import sys
import threading
import time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DEFAULT_GODOT = "C:/Users/Max de Dikke/AppData/Local/Programs/Godot/4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe"
LAKE_SAVED = ["t2_slalom", "iq_i2", "iq_lg2", "iq_lr2", "iq_o2", "iq_pd3", "iq_pm1", "iq_sd3", "iq_sm1", "iq_us3", "iq_us4"]
TEMPLATES = ["LG2", "LR2", "O2", "I2", "US3", "US4", "PD3", "SD3", "PM1", "SM1"]
# Where a new course may be centred: the lake's water lies in this box (game metres); a point on land is refused by
# the fitter and the run is drawn again.
LAKE_BOX = (0.0, 1100.0, -1150.0, 100.0)
GENERAL_HEAD = ["--skippers=persona:hana", "--spread=0", "--steady_hands=1"]
PERSONAS = ["aiko", "bruno", "elin", "greta", "hana", "ines", "jonas", "kofi", "lena", "liv", "mara", "marco", "noor", "pavel",
            "pia", "ravi", "sven", "tobias", "tomas", "yusuf"]
CHARACTERS = ["allrounder", "cautious", "gambler", "rookie"]
TUNE_SEED_BASE = 1
HOLDOUT_SEED_BASE = 700001
REDRAWN_MARKS = ("COURSE_ILLEGAL", "WIND_TOO_LOW", "FIT_FAILED", "DROP_TOO_FAR")
# Phase S: only drops that reach the start line with this much to spare (Max, 9 November 2026), and how long after the
# gun a start-only race is watched (the start check's limit is 20 s; the rest says how late a late start was).
PHASE_S_SPARE_S = 30
PHASE_S_WATCH_S = 60
# Phase S3 (10 November 2026): three boards a race, each watched to 30 s after the gun for the start's score.
PHASE_S3_BOARDS = 3
PHASE_S3_FOLLOW_S = 30
# The checks' limits.
START_SPARE_S = 20.0
STUCK_LIMIT_S = 20.0
LEG_FACTOR = 1.4
LEG_EXTRA_S = 30.0
RACE_FACTOR = 1.25
RACE_EXTRA_S = 60.0
FALL_EVERY_S = 300.0
# The roundings' limits (metres, degrees).
ROUND_CLOSEST_M = 10.0
ROUND_EXIT_M = 15.0
OVERSTAND_M = 25.0
CLOSE_HAULED_TRACK_DEG = 57.0  # only without the board's own track, on the open water (own_close_hauled_track()): measured 57 deg (baseline_A, 31 races; it was 50)
OWN_TRACK_MIN_S = 5.0
OWN_TRACK_ROW_S = 0.1  # the race tool's CSV row every 6 ticks
GATE_EXTRA_TURN_DEG = 120.0
ZONE_M = 60.0
GATE_ZONE_M = 80.0


def options_from(argv):
    options = {}
    for arg in argv:
        if arg.startswith("--") and "=" in arg:
            key, value = arg[2:].split("=", 1)
            options[key] = value
    return options


def limit_cpu(mask_text):
    """This process (and so every Godot it starts) on the processors of the mask (Windows): Max's 75 %."""
    if os.name != "nt" or not mask_text:
        return
    mask = int(mask_text, 16) if mask_text.lower().startswith("0x") else int(mask_text)
    kernel32 = ctypes.windll.kernel32
    # The argument types matter: without them the process's pseudo-handle is cut to 32 bits and the call fails.
    kernel32.GetCurrentProcess.restype = ctypes.c_void_p
    kernel32.SetProcessAffinityMask.argtypes = [ctypes.c_void_p, ctypes.c_size_t]
    kernel32.SetProcessAffinityMask.restype = ctypes.c_int
    if not kernel32.SetProcessAffinityMask(kernel32.GetCurrentProcess(), mask):
        print("could not limit the processors (mask %s)" % mask_text)


# ---------------------------------------------------------------- the draw

def draw_race(rng, phase="A"):
    """One race's arguments for run_race.gd and a short description of what was drawn."""
    if phase == "S3":
        # Three copies of the general head (Max: "we want the fastest skipper"), each with its own start spot drawn
        # at random (the head's sheet has one: all three aimed at the same point).
        spots = [rng.random() for _ in range(PHASE_S3_BOARDS)]
        who = "general head x%d, spots %s" % (PHASE_S3_BOARDS, " ".join("%.2f" % x for x in spots))
        args = list(GENERAL_HEAD) + ["--boards=%d" % PHASE_S3_BOARDS, "--start_spots=" + ",".join("%.2f" % x for x in spots),
                                     "--gear=1", "--finish_window=60", "--min_wind_kt=14"]
    elif phase == "B":
        who = rng.choice(["persona:" + p for p in PERSONAS] + CHARACTERS)
        args = ["--skippers=%s" % who, "--spread=0.5", "--gear=1", "--finish_window=60", "--min_wind_kt=14"]
    else:
        who = "general head"
        args = list(GENERAL_HEAD) + ["--gear=1", "--finish_window=60", "--min_wind_kt=14"]
    if phase in ("S", "S3"):
        args += ["--start_only=1", "--start_spare_s=%d" % PHASE_S_SPARE_S, "--start_watch_s=%d" % PHASE_S_WATCH_S]
    if phase == "S3":
        args += ["--start_follow_s=%d" % PHASE_S3_FOLLOW_S]
    seed = rng.randint(1, 10**6)
    args += ["--seed=%d" % seed]
    d = {"who": who, "phase": phase}
    countdown = rng.choice([120, 180, 300])
    args.append("--prestart=%d" % countdown)
    d["countdown_s"] = countdown
    if rng.random() < 0.8:
        d["water"] = "lake"
        hour = rng.uniform(11.0, 18.0)
        scale = rng.uniform(0.7, 1.4)
        args += ["--map=lake", "--time=%02d:%02d" % (int(hour), int((hour % 1) * 60)), "--lake_wind_scale=%.2f" % scale]
        d["hour"] = "%02d:%02d" % (int(hour), int((hour % 1) * 60))
        d["wind_scale"] = round(scale, 2)
        kind = rng.random()
        if kind < 0.4:
            course = rng.choice(LAKE_SAVED)
            args.append("--course=%s" % course)
            d["course_kind"] = "saved"
            d["course"] = course
        elif kind < 0.7:
            course = rng.choice(LAKE_SAVED)
            turn = rng.uniform(-10.0, 10.0)
            shift = (rng.uniform(-50.0, 50.0), rng.uniform(-50.0, 50.0))
            args += ["--course=%s" % course, "--course_turn=%.1f" % turn, "--course_shift=%.0f,%.0f" % shift]
            d["course_kind"] = "shifted"
            d["course"] = "%s %+.0f deg (%+.0f, %+.0f) m" % (course, turn, shift[0], shift[1])
        else:
            template = rng.choice(TEMPLATES)
            at = (rng.uniform(LAKE_BOX[0], LAKE_BOX[1]), rng.uniform(LAKE_BOX[2], LAKE_BOX[3]))
            args += ["--course=fit:%s" % template, "--fit_at=%.0f,%.0f" % at]
            d["course_kind"] = "new"
            d["course"] = "new %s near (%.0f, %.0f)" % (template, at[0], at[1])
    else:
        d["water"] = "open"
        wind = rng.uniform(14.0, 26.0)
        args.append("--wind_kt=%.1f" % wind)
        d["wind_kt"] = round(wind, 1)
        pick = rng.random()
        if pick < 0.2:
            args.append("--course=t1_loop")
            d["course_kind"] = "T1"
            d["course"] = "t1_loop"
        else:
            template = rng.choice(TEMPLATES)
            size = rng.choice([50, 100])
            args.append("--course=template:%s@%d" % (template, size))
            d["course_kind"] = "template"
            d["course"] = "%s at %d %%" % (template, size)
    spawn = rng.random()
    if spawn < 0.4:
        args += ["--spawn=random", "--spawn_seed=%d" % seed]
        d["start"] = "start box"
    elif spawn < 0.7:
        args += ["--spawn=line"]
        d["start"] = "behind the line"
    else:
        args += ["--spawn=anywhere", "--spawn_seed=%d" % seed]
        d["start"] = "anywhere"
    d["restart"] = "-"
    with_r = rng.random() < 0.2  # one draw whatever the phase: phase A's and B's races stay what they were
    if with_r and phase in ("S", "S3"):
        # Phase S: R in the countdown or up to 2 minutes after the gun; the start after the last R counts.
        if rng.random() < 0.5:
            at_s = -rng.uniform(5.0, countdown - 5.0)
            d["restart"] = "countdown %.0f s" % at_s
        else:
            at_s = rng.uniform(0.0, 120.0)
            d["restart"] = "after the gun %.0f s" % at_s
        args.append("--restart_after=%.0f" % at_s)
    elif with_r:
        when = rng.random()
        if when < 0.33:
            at_s = -rng.uniform(5.0, countdown - 5.0)
            d["restart"] = "countdown %.0f s" % at_s
        elif when < 0.66:
            at_s = rng.uniform(20.0, 600.0)
            d["restart"] = "mid-race %.0f s" % at_s
        else:
            at_s = 99999.0
            d["restart"] = "after the finish"
        args.append("--restart_after=%.0f" % at_s)
    return args, d


# ---------------------------------------------------------------- the score

def read_csv(path):
    rows = []
    try:
        with open(path, encoding="utf-8") as handle:
            header = handle.readline().strip().split(",")
            for line in handle:
                parts = line.rstrip("\n").split(",")
                if len(parts) < 7:
                    continue
                try:
                    rows.append((float(parts[0]), float(parts[1]), float(parts[2]), float(parts[3]), float(parts[4]), int(parts[5]), parts[6]))
                except ValueError:
                    continue
    except OSError:
        return []
    # After an R only the race after the last restart (the race clock jumps back).
    start = 0
    for k in range(1, len(rows)):
        if rows[k][0] < rows[k - 1][0] - 1.0:
            start = k
    return rows[start:]


def bearing(a, b):
    """The compass bearing from a to b (game X east, Z south), degrees."""
    return math.degrees(math.atan2(b[0] - a[0], -(b[1] - a[1]))) % 360.0


def turn(a_deg, b_deg):
    return (b_deg - a_deg + 180.0) % 360.0 - 180.0


def dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


def own_close_hauled_track(rows, k, tack_at):
    """The board's own close-hauled track over the ground on the tack of its last tack before mark k, from the same
    leg before that tack: the median of the 1-s tracks where it was beating (the skipper's note) steadily (under 3 deg
    in 1 s) on a heading within 15 deg of the last tack's. None with fewer than OWN_TRACK_MIN_S seconds of it. The
    layline 50 deg off the course's axis was wrong on the lake, where the hour's wind does not blow along the course:
    baseline_A (8 November 2026, 74 beats into a mark on the lake) beat 70 deg off the axis (median), so a tack on its
    own layline counted as a 44 m overstand; against its own track the median was 21 m."""
    t_tack = tack_at[0]
    after = [q[3] for q in rows if q[5] == k and t_tack + 4.0 <= q[0] <= t_tack + 12.0]
    final_heading = statistics.median(after) if after else tack_at[3]
    leg = [q for q in rows if q[5] == k and t_tack - 600.0 <= q[0] < t_tack - 2.0]
    tracks = []
    j = 0
    for i, q in enumerate(leg):
        while j < len(leg) and leg[j][0] < q[0] + 1.0:
            j += 1
        if j >= len(leg):
            break
        p = leg[j]
        if q[6].startswith("beat") and abs(turn(final_heading, q[3])) < 15.0 and abs(turn(q[3], p[3])) < 3.0 and dist((q[1], q[2]), (p[1], p[2])) > 0.5:
            tracks.append(bearing((q[1], q[2]), (p[1], p[2])))
    if len(tracks) * OWN_TRACK_ROW_S < OWN_TRACK_MIN_S:
        return None
    ref = tracks[0]
    return (ref + statistics.median([turn(ref, t) for t in tracks])) % 360.0


def roundings(rows, course, axis_deg, axis_is_wind=True):
    """Every mark and gate the board rounded: what, the closest approach, the distance out of the turn, the overstand on
    a beat into it, the gate's extra turning. The overstand is measured against the board's own close-hauled track;
    without one, against a track CLOSE_HAULED_TRACK_DEG off the course's axis where the wind blows along it (axis_is_wind:
    the open water), and not at all on the lake."""
    out = []
    steps = course["steps"]
    for k in range(1, len(steps) - 1):
        step = steps[k]
        if step["kind"] not in ("MARK", "GATE"):
            continue
        idx = next((i for i in range(1, len(rows)) if rows[i - 1][5] == k and rows[i][5] == k + 1), None)
        if idx is None:
            continue
        here = (rows[idx][1], rows[idx][2])
        points = [tuple(p) for p in step["points"]]
        mark = min(points, key=lambda p: dist(p, here))
        t0 = rows[idx][0]
        window = [r for r in rows if t0 - 40.0 <= r[0] <= t0 + 40.0]
        closest = min(dist((r[1], r[2]), mark) for r in window)
        # Out of the turn: from the rounding on, the first moment the heading holds (under 6 deg in 2 s).
        exit_m = None
        after = [r for r in rows if r[0] >= t0]
        for i, r in enumerate(after):
            later = next((q for q in after[i:] if q[0] >= r[0] + 2.0), None)
            if later is None:
                break
            if abs(turn(r[3], later[3])) < 6.0:
                exit_m = dist((r[1], r[2]), mark)
                break
        # The overstand: on a beat into the mark, how far beyond the layline the last tack was made.
        overstand = None
        prev = tuple(steps[k - 1]["points"][0]) if steps[k - 1]["points"] else None
        if prev is not None and abs(turn(axis_deg, bearing(prev, mark))) < 50.0:
            before = [r for r in rows if t0 - 300.0 <= r[0] <= t0]
            tack_at = None
            for i in range(len(before) - 1, 0, -1):
                earlier = next((q for q in reversed(before[:i]) if q[0] <= before[i][0] - 8.0), None)
                if earlier is None:
                    break
                if abs(turn(earlier[3], before[i][3])) > 60.0 and abs(turn(axis_deg, before[i][3])) < 90.0:
                    tack_at = before[i]
                    break
            if tack_at is not None:
                p = (tack_at[1], tack_at[2])
                track = own_close_hauled_track(rows, k, tack_at)
                if track is not None:
                    # Beyond the board's own layline: the mark lies off its close-hauled track on that tack to leeward
                    # (away from the course's axis, where the wind comes from).
                    off = turn(track, bearing(p, mark))
                    beyond = -off if turn(track, axis_deg) > 0.0 else off
                    overstand = dist(p, mark) * math.sin(math.radians(min(max(beyond, 0.0), 90.0)))
                elif axis_is_wind:
                    off = abs(turn(axis_deg, bearing(p, mark)))
                    overstand = dist(p, mark) * math.sin(math.radians(off - CLOSE_HAULED_TRACK_DEG)) if off > CLOSE_HAULED_TRACK_DEG else 0.0
        # A gate's extra turning: the heading turned within the gate's circle beyond the turn from the way in to the way out.
        extra_turn = None
        if step["kind"] == "GATE":
            zone = [r for r in rows if dist((r[1], r[2]), mark) <= GATE_ZONE_M and abs(r[0] - t0) < 90.0]
            if len(zone) > 2:
                turned = sum(abs(turn(a[3], b[3])) for a, b in zip(zone, zone[1:]))
                needed = abs(turn(zone[0][3], zone[-1][3]))
                extra_turn = max(turned - needed, 0.0)
        out.append({"step": k, "name": step["name"], "kind": step["kind"], "closest_m": round(closest, 1),
                    "exit_m": round(exit_m, 1) if exit_m is not None else None,
                    "overstand_m": round(overstand, 1) if overstand is not None else None,
                    "extra_turn_deg": round(extra_turn) if extra_turn is not None else None})
    return out


def score(label, log_text, csv_dir, drawn):
    """The run's result: per board the checks and the roundings."""
    course = None
    m = re.search(r"^COURSE_JSON (.*)$", log_text, re.M)
    if m:
        course = json.loads(m.group(1))
    boards = []
    for line in re.findall(r"^HEADS_RESULT (.*)$", log_text, re.M):
        r = json.loads(line)
        splits = r.get("splits", [])
        legs_expected = r.get("legs_expected", [])
        prestart = r.get("prestart_s", 60.0)
        checks = {}
        start_allowed = max(0.0, r.get("start_need_s", 0.0) - prestart) + START_SPARE_S
        checks["start"] = (splits[0] <= start_allowed, "%.0f s after the gun (allowed %.0f)" % (splits[0], start_allowed)) if splits else (False, "never started")
        checks["stuck"] = (r.get("longest_stuck_s", 0.0) <= STUCK_LIMIT_S, "longest %.0f s" % r.get("longest_stuck_s", 0.0))
        checks["aground"] = (not r.get("aground", False), r.get("aground_note", "") or "no")
        if drawn.get("phase") in ("S", "S3"):
            # Phase S: a start-only race. The checks are the start's; a fall anywhere from the countdown to the start
            # counts (the measures that may not get worse: falls, stuck, aground, over early).
            checks["falls"] = (r.get("falls", 0) == 0, "%d (none allowed in a start)" % r.get("falls", 0))
            start = {"start_s": round(splits[0], 1) if splits else None, "allowed_s": round(start_allowed, 1),
                     "need_s": round(r.get("start_need_s", 0.0), 1), "countdown_s": prestart,
                     "gun_speed_ms": r.get("gun_speed_ms", -1.0), "gun_behind_m": r.get("gun_behind_m", 0.0),
                     "gun_to_line_m": r.get("gun_to_line_m", -1.0), "ocs": bool(r.get("ocs", False)),
                     "ocs_at_gun": bool(r.get("ocs_at_gun", False)), "falls_before_gun": r.get("falls_before_gun", 0),
                     "restarted": bool(r.get("restarted", False)), "spawn": r.get("spawn", []),
                     # Phase S3: the start's score (metres up the course 30 s after the gun), the speed when the start
                     # counted, the seconds tangled within 5 m of another board, the penalties, and the wind at the gun.
                     "score_m": r.get("score_m"), "cross_speed_ms": r.get("cross_speed_ms", -1.0),
                     "near_s": r.get("near_s", 0.0), "penalties": r.get("penalties", 0), "boards": r.get("boards", 1),
                     "gun_mean_kt": r.get("gun_mean_kt"), "gun_felt_kt": r.get("gun_felt_kt"),
                     "gun_felt_60s_kt": r.get("gun_felt_60s_kt"), "gun_felt_spread_kt": r.get("gun_felt_spread_kt")}
            boards.append({"board": r["board"], "checks": {k: {"ok": v[0], "what": v[1]} for k, v in checks.items()},
                           "pass": all(v[0] for v in checks.values()), "legs": [], "roundings": [],
                           "falls": r.get("falls", 0), "note": r.get("note", ""), "start": start})
            continue
        checks["finished"] = (bool(r.get("reached")), "%d of %d steps" % (len(splits), r.get("steps", 0)))
        legs = []
        leg_fail = []
        for k in range(1, len(splits)):
            if k - 1 < len(legs_expected):
                took = splits[k] - splits[k - 1]
                expected = legs_expected[k - 1]
                ok = took <= LEG_FACTOR * expected + LEG_EXTRA_S
                legs.append({"leg": k, "took_s": round(took, 1), "expected_s": expected, "ratio": round(took / max(expected, 1.0), 2), "ok": ok})
                if not ok:
                    leg_fail.append("leg %d %.0f s / %.0f" % (k, took, expected))
        checks["legs"] = (not leg_fail, ", ".join(leg_fail) or "all within %.1fx + %.0f s" % (LEG_FACTOR, LEG_EXTRA_S))
        if r.get("reached") and splits and legs_expected:
            total = splits[-1] - splits[0]
            allowed = RACE_FACTOR * sum(legs_expected) + RACE_EXTRA_S
            checks["race_time"] = (total <= allowed, "%.0f s of %.0f allowed" % (total, allowed))
        race_s = (splits[-1] if splits else r.get("watched_s", 0.0)) or 1.0
        falls_allowed = max(1, int(race_s // FALL_EVERY_S))
        checks["falls"] = (r.get("falls", 0) <= falls_allowed, "%d (allowed %d)" % (r.get("falls", 0), falls_allowed))
        rounds = []
        # The race tool names the file as RunRace._file_name() does: lower case, spaces as underscores.
        csv_path = os.path.join(csv_dir, r["board"].lower().replace(" ", "_") + ".csv")
        if course and os.path.exists(csv_path):
            rounds = roundings(read_csv(csv_path), course, course.get("axis_deg", 0.0), drawn.get("water") != "lake")
        boards.append({"board": r["board"], "checks": {k: {"ok": v[0], "what": v[1]} for k, v in checks.items()},
                       "pass": all(v[0] for v in checks.values()), "legs": legs, "roundings": rounds,
                       "falls": r.get("falls", 0), "note": r.get("note", "")})
    return {"label": label, "drawn": drawn, "boards": boards, "pass": bool(boards) and all(b["pass"] for b in boards),
            "course_steps": len(course["steps"]) if course else 0}


# ---------------------------------------------------------------- the viewer

def start_card(results, e):
    """Phase S's card: the starts' numbers, and the starts on time by water and course kind, by course, by start place."""
    starts = [(r, b["start"]) for r in results for b in r["boards"] if "start" in b]
    falls_before = sum(1 for r in results for b in r["boards"] if "start" in b and b["falls"] > 0)
    scores = [st["score_m"] for _, st in starts if st.get("score_m") is not None]
    crossing = [st["cross_speed_ms"] for _, st in starts if st.get("cross_speed_ms", -1.0) >= 0.0]
    tangled = sum(1 for _, st in starts if st.get("near_s", 0.0) > 5.0)
    penalties = sum(st.get("penalties", 0) for _, st in starts)
    if not starts:
        return ""
    on_time = [st["start_s"] is not None and st["start_s"] <= st["allowed_s"] for _, st in starts]
    after = sorted(st["start_s"] if st["start_s"] is not None else float("inf") for _, st in starts)
    med = statistics.median(after)
    speeds = [st["gun_speed_ms"] for _, st in starts if st["gun_speed_ms"] >= 0.0]
    behind = [st["gun_behind_m"] for _, st in starts]
    tiles = (
        '<div class="tile"><div class="big">%d / %d</div><div class="dim">starts on time (under 20 s)</div></div>' % (sum(on_time), len(on_time)) +
        '<div class="tile"><div class="big">%s</div><div class="dim">median seconds after the gun</div></div>' % ("%.1f s" % med if med != float("inf") else "over 60 s") +
        '<div class="tile"><div class="big">%d</div><div class="dim">over early at the gun</div></div>' % sum(st["ocs_at_gun"] for _, st in starts) +
        '<div class="tile"><div class="big">%d</div><div class="dim">fell before the start</div></div>' % falls_before +
        '<div class="tile"><div class="big">%s</div><div class="dim">median speed at the gun</div></div>' % ("%.1f m/s" % statistics.median(speeds) if speeds else "-") +
        '<div class="tile"><div class="big">%s</div><div class="dim">median behind the line at the gun</div></div>' % ("%.0f m" % statistics.median(behind) if behind else "-"))
    if scores:
        tiles += (
            '<div class="tile"><div class="big">%.0f m</div><div class="dim">median start score: up the course 30 s after the gun</div></div>' % statistics.median(scores) +
            '<div class="tile"><div class="big">%s</div><div class="dim">median speed over the line</div></div>' % ("%.1f m/s" % statistics.median(crossing) if crossing else "-") +
            '<div class="tile"><div class="big">%d</div><div class="dim">boards tangled (over 5 s within 5 m of another)</div></div>' % tangled +
            '<div class="tile"><div class="big">%d</div><div class="dim">penalties</div></div>' % penalties)

    def table(key_of):
        groups = {}
        for (r, st), ok in zip(starts, on_time):
            g = groups.setdefault(key_of(r), [0, 0])
            g[0] += 1
            g[1] += 1 if ok else 0
        return "".join('<tr><td>%s</td><td class="num">%d</td><td class="num">%d</td><td class="num">%.0f %%</td></tr>' % (
            e(k), v[0], v[0] - v[1], 100.0 * v[1] / v[0]) for k, v in sorted(groups.items(), key=lambda kv: -(kv[1][0] - kv[1][1])))
    head = '<tr><th>what</th><th class="num">races</th><th class="num">late</th><th class="num">on time</th></tr>'
    course_of = lambda r: r["drawn"].get("course", "?").split(" ")[0] if r["drawn"].get("course_kind") in ("saved", "shifted") else (
        "new " + r["drawn"].get("course", "?").split(" ")[1] if r["drawn"].get("course_kind") == "new" else r["drawn"].get("course", "?").split(" ")[0])
    return ('<div class="card"><h2>The starts (phase S)</h2><div class="tiles">%s</div></div><div class="grid">'
            '<div class="card"><h2>Starts by water and course kind</h2><table>%s%s</table></div>'
            '<div class="card"><h2>Starts by start place, countdown and R</h2><table>%s%s</table></div>'
            '<div class="card"><h2>Starts by course</h2><table>%s%s</table></div></div>') % (
        tiles, head, table(lambda r: "%s / %s" % (r["drawn"].get("water"), r["drawn"].get("course_kind"))),
        head, table(lambda r: "%s, %d s%s" % (r["drawn"].get("start"), r["drawn"].get("countdown_s", 0), ", R" if r["drawn"].get("restart", "-") != "-" else "")),
        head, table(course_of))


def write_viewer(out_dir, state, results):
    done = len(results)
    total = state["count"]
    elapsed = time.time() - state["started"]
    per_run = elapsed / done if done else 0.0
    eta = per_run * (total - done) if done else 0.0
    passed = sum(1 for r in results if r["pass"])
    check_names = ["start", "stuck", "aground", "finished", "legs", "race_time", "falls"]
    check_rows = []
    for name in check_names:
        vals = [b["checks"][name]["ok"] for r in results for b in r["boards"] if name in b["checks"]]
        if vals:
            check_rows.append((name, sum(vals), len(vals)))
    rnd = [x for r in results for b in r["boards"] for x in b["roundings"]]
    def share(pred, items):
        items = list(items)
        return (100.0 * sum(1 for i in items if pred(i)) / len(items)) if items else 0.0
    closest = [x["closest_m"] for x in rnd]
    exits = [x["exit_m"] for x in rnd if x["exit_m"] is not None]
    overs = [x["overstand_m"] for x in rnd if x["overstand_m"] is not None]
    gates = [x["extra_turn_deg"] for x in rnd if x["extra_turn_deg"] is not None]
    by_kind = {}
    for r in results:
        key = "%s / %s" % (r["drawn"].get("water"), r["drawn"].get("course_kind"))
        k = by_kind.setdefault(key, [0, 0, []])
        k[0] += 1
        k[1] += 1 if r["pass"] else 0
        k[2] += [lg["ratio"] for b in r["boards"] for lg in b["legs"]]
    by_start = {}
    for r in results:
        key = r["drawn"].get("start", "?") + (" + R" if r["drawn"].get("restart", "-") != "-" else "")
        k = by_start.setdefault(key, [0, 0])
        k[0] += 1
        k[1] += 1 if r["pass"] else 0
    failures = [r for r in results if not r["pass"]][-40:]
    e = html.escape

    def bar(value, of):
        pct = 100.0 * value / of if of else 0.0
        return '<div class="bar"><div class="fill %s" style="width:%.1f%%"></div></div>' % ("good" if pct >= 95 else ("warn" if pct >= 80 else "bad"), pct)

    rows_checks = "".join('<tr><td>%s</td><td class="num">%d / %d</td><td>%s</td></tr>' % (e(n), ok, of, bar(ok, of)) for n, ok, of in check_rows)
    rows_kind = "".join('<tr><td>%s</td><td class="num">%d</td><td class="num">%.0f %%</td><td class="num">%s</td></tr>' % (
        e(k), v[0], 100.0 * v[1] / v[0], ("%.2f" % statistics.median(v[2])) if v[2] else "-") for k, v in sorted(by_kind.items()))
    rows_start = "".join('<tr><td>%s</td><td class="num">%d</td><td class="num">%.0f %%</td></tr>' % (e(k), v[0], 100.0 * v[1] / v[0]) for k, v in sorted(by_start.items()))
    rows_fail = ""
    for r in reversed(failures):
        what = "; ".join("%s: %s" % (n, c["what"]) for b in r["boards"] for n, c in b["checks"].items() if not c["ok"]) or "no result (crashed or timed out)"
        rows_fail += '<tr><td>%s</td><td>%s</td><td>%s</td><td><code>%s</code></td></tr>' % (
            e(r["label"]), e("%s, %s, %s, %s" % (r["drawn"].get("course"), r["drawn"].get("hour", r["drawn"].get("wind_kt", "")), r["drawn"].get("start"), r["drawn"].get("restart"))),
            e(what), e(r.get("replay", "")))
    running = "".join("<li>%s <span class='dim'>%s, %.0f s</span></li>" % (e(lbl), e(d.get("course", "")), time.time() - t) for lbl, (d, t) in list(state["running"].items()))
    rnd_html = """
      <div class="tiles">
        <div class="tile"><div class="big">%s</div><div class="dim">roundings measured</div></div>
        <div class="tile"><div class="big">%s</div><div class="dim">median closest approach (limit %.0f m)</div><div class="%s">%.0f %% wider</div></div>
        <div class="tile"><div class="big">%s</div><div class="dim">median distance out of the turn (limit %.0f m)</div><div class="%s">%.0f %% wider</div></div>
        <div class="tile"><div class="big">%s</div><div class="dim">median overstand on beats into a mark (limit %.0f m)</div><div class="%s">%.0f %% more</div></div>
        <div class="tile"><div class="big">%s</div><div class="dim">gates with more than %.0f&deg; extra turning</div></div>
      </div>""" % (
        len(rnd),
        ("%.1f m" % statistics.median(closest)) if closest else "-", ROUND_CLOSEST_M, "bad" if share(lambda v: v > ROUND_CLOSEST_M, closest) > 20 else "dim", share(lambda v: v > ROUND_CLOSEST_M, closest),
        ("%.1f m" % statistics.median(exits)) if exits else "-", ROUND_EXIT_M, "bad" if share(lambda v: v > ROUND_EXIT_M, exits) > 20 else "dim", share(lambda v: v > ROUND_EXIT_M, exits),
        ("%.0f m" % statistics.median(overs)) if overs else "-", OVERSTAND_M, "bad" if share(lambda v: v > OVERSTAND_M, overs) > 20 else "dim", share(lambda v: v > OVERSTAND_M, overs),
        ("%.0f %%" % share(lambda v: v > GATE_EXTRA_TURN_DEG, gates)) if gates else "-", GATE_EXTRA_TURN_DEG)
    starts_html = start_card(results, e)
    page = """<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="refresh" content="15"><title>AI training viewer</title><style>
:root{--bg:#f6f7f9;--card:#fff;--ink:#1d2330;--dim:#667085;--line:#e3e6eb;--good:#2e9d5b;--warn:#d9a21b;--bad:#d14343;--accent:#2f6fdb}
@media (prefers-color-scheme: dark){:root{--bg:#0f141b;--card:#171d26;--ink:#e6e9ee;--dim:#98a2b3;--line:#2a3340;--good:#3fbf74;--warn:#e8b53a;--bad:#ef6464;--accent:#5b8ff0}}
body{margin:0;background:var(--bg);color:var(--ink);font:14px/1.45 system-ui,-apple-system,"Segoe UI",sans-serif}
main{max-width:1400px;margin:0 auto;padding:16px}
h1{font-size:20px;margin:0 0 4px}h2{font-size:15px;margin:0 0 10px}
.card{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:14px 16px;margin:12px 0}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(340px,1fr));gap:12px}
.tiles{display:grid;grid-template-columns:repeat(auto-fit,minmax(170px,1fr));gap:10px}
.tile{border:1px solid var(--line);border-radius:8px;padding:10px}.big{font-size:22px;font-weight:600}
.dim{color:var(--dim)}.bad{color:var(--bad);font-weight:600}.num{text-align:right;white-space:nowrap}
.bar{height:10px;background:var(--line);border-radius:5px;overflow:hidden;min-width:120px}.fill{height:100%%}
.fill.good{background:var(--good)}.fill.warn{background:var(--warn)}.fill.bad{background:var(--bad)}
.progress{height:16px;background:var(--line);border-radius:8px;overflow:hidden}.progress div{height:100%%;background:var(--accent)}
table{border-collapse:collapse;width:100%%}td,th{border-bottom:1px solid var(--line);padding:5px 6px;vertical-align:top;text-align:left}
code{font-size:11px;word-break:break-all;color:var(--dim)}ul{margin:0;padding-left:18px}
.wrap{overflow-x:auto}
</style></head><body><main>
<h1>AI training viewer: %s</h1>
<div class="dim">%s set &middot; started %s &middot; this page reloads every 15 s; closing it does not stop the training</div>
<div class="card"><div class="tiles">
  <div class="tile"><div class="big">%d / %d</div><div class="dim">races done</div></div>
  <div class="tile"><div class="big">%.0f %%</div><div class="dim">races passing every check</div></div>
  <div class="tile"><div class="big">%d</div><div class="dim">running now</div></div>
  <div class="tile"><div class="big">%d</div><div class="dim">redrawn (course on land, wind under 14 kt)</div></div>
  <div class="tile"><div class="big">%s</div><div class="dim">time left (about)</div></div>
  <div class="tile"><div class="big">%.0f s</div><div class="dim">per race, all cores together</div></div>
</div><div style="margin-top:10px" class="progress"><div style="width:%.1f%%"></div></div></div>
%s<div class="grid">
<div class="card"><h2>The checks (every board, every race)</h2><table>%s</table></div>
<div class="card"><h2>Mark roundings</h2>%s</div>
</div>
<div class="grid">
<div class="card"><h2>By water and course</h2><table><tr><th>what</th><th class="num">races</th><th class="num">pass</th><th class="num">median leg / expected</th></tr>%s</table></div>
<div class="card"><h2>By start and R</h2><table><tr><th>what</th><th class="num">races</th><th class="num">pass</th></tr>%s</table></div>
</div>
<div class="card"><h2>Running now</h2><ul>%s</ul></div>
<div class="card"><h2>Failures (newest first, the last 40)</h2><div class="wrap"><table><tr><th>race</th><th>drawn</th><th>what failed</th><th>replay</th></tr>%s</table></div></div>
<div class="dim">Written %s. Files: %s</div>
</main></body></html>""" % (
        e(state["run"]), e(state["set"]), time.strftime("%H:%M", time.localtime(state["started"])),
        done, total, (100.0 * passed / done) if done else 0.0, len(state["running"]), state["redrawn"],
        time.strftime("%H:%M:%S", time.gmtime(eta)) if done else "-", per_run, 100.0 * done / max(total, 1),
        starts_html, rows_checks or "<tr><td class='dim'>no races yet</td></tr>", rnd_html, rows_kind, rows_start,
        running or "<li class='dim'>none</li>", rows_fail or "<tr><td class='dim' colspan=4>none</td></tr>",
        time.strftime("%H:%M:%S"), e(out_dir))
    for path in (os.path.join(out_dir, "viewer.html"), os.path.join(os.path.dirname(out_dir), "viewer.html")):
        # A temporary file of this process's own, and a page in use (two suites side by side write the shared page;
        # Windows refuses the rename while the other has it open: s2b_off crashed so on 9 November 2026) is left for
        # the next write.
        tmp = "%s.%d.tmp" % (path, os.getpid())
        try:
            with open(tmp, "w", encoding="utf-8") as handle:
                handle.write(page)
            os.replace(tmp, path)
        except OSError:
            try:
                os.remove(tmp)
            except OSError:
                pass
    with open(os.path.join(out_dir, "status.json"), "w", encoding="utf-8") as handle:
        json.dump({"done": done, "count": total, "passed": passed, "redrawn": state["redrawn"], "running": list(state["running"].keys())}, handle)


# ---------------------------------------------------------------- the run

def main(argv):
    options = options_from(argv)
    run = options.get("run", time.strftime("suite_%d%b_%H%M"))
    count = int(options.get("count", "200"))
    cores = int(options.get("cores", "8"))
    which = options.get("set", "tune")
    seed = int(options.get("seed", "1")) + (HOLDOUT_SEED_BASE if which == "holdout" else TUNE_SEED_BASE)
    project = os.path.abspath(options.get("project", os.path.join(ROOT, "Game")))
    godot = os.environ.get("GODOT", DEFAULT_GODOT)
    out_dir = os.path.join(ROOT, ".sim_output", "suite", run)
    os.makedirs(os.path.join(out_dir, "logs"), exist_ok=True)
    limit_cpu(options.get("cpu_mask", "0x5555"))
    lock = threading.Lock()
    results = []
    results_path = os.path.join(out_dir, "results.jsonl")
    if os.path.exists(results_path):
        with open(results_path, encoding="utf-8") as handle:
            results = [json.loads(line) for line in handle if line.strip()]
    state = {"run": run, "set": which, "count": count, "started": time.time(), "running": {}, "redrawn": 0}
    jobs_file = open(os.path.join(out_dir, "jobs.txt"), "a", encoding="utf-8")
    counter = [len(results)]

    def one(number):
        attempt = 0
        while True:
            # Each race number (and each redraw of it) its own draw: the same races whatever the order, and a run that
            # is stopped and started again goes on with new races instead of repeating its first ones.
            attempt += 1
            args, drawn = draw_race(random.Random(seed * 1000003 + number * 101 + attempt), options.get("phase", "A"))
            args += options.get("extra", "").split()
            label = "r%04d" % number
            csv_dir = os.path.join(out_dir, label)
            full = args + ["--out_dir=%s" % csv_dir.replace("\\", "/")]
            command = [godot, "--headless", "--no-header", "--path", project, "-s", "res://dev/run_race.gd", "--"] + full
            with lock:
                state["running"][label] = (drawn, time.time())
                jobs_file.write("%s %s\n" % (label, " ".join(args)))
                jobs_file.flush()
            try:
                done = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=2400)
                log_text = done.stdout + done.stderr
            except subprocess.TimeoutExpired as err:
                log_text = (err.stdout or "") if isinstance(err.stdout, str) else ""
                log_text += "\nSUITE_TIMEOUT"
            with open(os.path.join(out_dir, "logs", label + ".log"), "w", encoding="utf-8") as handle:
                handle.write(log_text)
            with lock:
                state["running"].pop(label, None)
            if any(mark in log_text for mark in REDRAWN_MARKS):
                with lock:
                    state["redrawn"] += 1
                continue
            result = score(label, log_text, csv_dir, drawn)
            board = result["boards"][0]["board"].replace(" ", "_") if result["boards"] else "Hana"
            result["replay"] = "godot --headless --path Game -s res://dev/run_race.gd -- %s --trace=%s" % (" ".join(args), board)
            with lock:
                results.append(result)
                with open(results_path, "a", encoding="utf-8") as handle:
                    handle.write(json.dumps(result) + "\n")
                write_viewer(out_dir, state, results)
            return

    write_viewer(out_dir, state, results)
    stop = threading.Event()

    def refresher():
        while not stop.is_set():
            with lock:
                write_viewer(out_dir, state, results)
            stop.wait(15)

    threading.Thread(target=refresher, daemon=True).start()
    with concurrent.futures.ThreadPoolExecutor(max_workers=cores) as pool:
        list(pool.map(one, range(counter[0] + 1, count + 1)))
    stop.set()
    with lock:
        write_viewer(out_dir, state, results)
    passed = sum(1 for r in results if r["pass"])
    print("%s: %d races, %d pass every check, %d redrawn; viewer %s" % (run, len(results), passed, state["redrawn"], os.path.join(out_dir, "viewer.html")))


if __name__ == "__main__":
    main(sys.argv[1:])
