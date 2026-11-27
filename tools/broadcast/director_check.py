"""The reality check for the TV director: the game's director set beside the real stream.

    python -I tools/broadcast/director_check.py <run folder> --profile=<stream_profile.json> --out=<report.md>

tools/tv_check.sh runs it after its races. It reads every race_*.csv in the run folder (the game's
TvTakeLog: one row per take, and one per part of a take that runs over a phase's border, with the
framing measured from the real camera and board) and the stream's profile (nine slalom heats), and
writes per phase of a heat (pre-start, start, race, after the race):

- the take lengths (the first quarter, the middle, the third quarter), a take counted once, in the
  phase it began in, with its whole length;
- the time shares per picture (camera, view, what it is on), per camera, per subject, per drone view
  and per move;
- per picture the sail's height and the horizon's place (their middle values), as measured;
- per race picture the drone's height, distance and look-down angle, beside the lead's measurement of
  the stream's drones (Documentation/reports/broadcast/drone_position.md, lens 47 degrees);
- the start's and the marks' timing;
- how steady the numbers are from race to race.

Each line has the stream's number, the game's and whether the game is inside the tolerance stated in
the table's heading. Before the start and after the race the stream's shares are of its live pictures
only (the line-up graphic, the handheld beach camera, the interviews and the people are left out: the
game has none of them), so they add up to 100 % like the game's.
"""
import argparse
import collections
import csv
import glob
import json
import math
import os

PHASES = ["pre_start", "start", "race", "after_race"]
PHASE_TITLES = {"pre_start": "Before the start", "start": "The start (10 s before the gun to 12 s after)",
                "race": "The race", "after_race": "After the race"}
LIVE_CAMERAS = ("drone", "shore_long_lens")

# The lead's measurement of where the stream's drones fly (drone_position.md, 27 November 2026): the
# drone's height in sail heights (how far the sail's foot stands below the horizon, in sail heights:
# lens-free, the firm part; middle and the middle half), and with a 47-degree lens and a raked sail whose
# top is about 3.5 m up: its height above the water and level distance to the board (middle, and the
# middle half; estimates, about +-15 %) and the angle it looks down at the board (middle).
DRONE_POSITION = {
    "drone behind_side front": ((2.5, 2.3, 3.0), (6.9, 6.1, 8.9), (23.0, 17.0, 29.0), 21.0),
    "drone front_side front": ((2.4, 1.9, 2.7), (9.0, 7.0, 10.2), (37.0, 29.0, 43.0), 15.0),
    "drone side front": ((3.0, 2.0, 3.2), (9.7, 6.7, 10.6), (28.0, 20.0, 48.0), 20.0),
    "drone behind_side pack": ((2.4, 2.0, 3.4), (6.5, 4.8, 8.8), (18.0, 12.0, 21.0), 23.0),
    "drone behind_side mark": ((2.7, 2.2, 4.1), (6.1, 5.7, 10.5), (14.0, 10.0, 19.0), 24.0),
    "drone side mark": ((3.0, 2.1, 5.5), (9.6, 6.9, 18.0), (32.0, 22.0, 45.0), 16.0),
    "drone front_side mark": ((3.0, 2.3, 3.2), (11.4, 8.6, 12.1), (39.0, 22.0, 60.0), 16.0),
    "drone behind_side fleet": ((2.5, 1.9, 3.0), None, None, 18.0),
}
# The start's timing counted on the nine heats' shot notes (27 November 2026; the config's header says how).
LINE_DRONE_BEFORE_GUN_S = (2.6, 3.1, 3.7)
MARK_CUT_BEFORE_S = (2.0, 5.0)

# The tolerances.
TAKE_MIDDLE_SHARE = 0.20      # a take's middle length within 20 % of the stream's
TAKE_QUARTER_SHARE = 0.30     # its quarters within 30 %
SHARE_POINTS = 5.0            # a picture's, a camera's, a subject's share of the time within 5 points
LOOSE_SHARE_POINTS = 8.0      # the drone's view and the move within 8 points (the readers agreed on the side for 58 % only)
SAIL_POINTS = 2.0             # the sail's middle height within 2 points or 25 %, whichever is more
SAIL_SHARE = 0.25
HORIZON_POINTS = 7.0          # the horizon's middle place within 7 points (the readers rounded to 5)
LOOK_DOWN_DEG = 5.0           # the drone's look-down angle within 5 degrees
FIRST_CUT_S = 3.0             # the first cut after the gun: its middle within 3 s


def quartiles(values):
    """The first quarter, the middle and the third quarter, as the profile counts them."""
    vals = sorted(values)
    if not vals:
        return None
    q = lambda p: vals[min(len(vals) - 1, int(p * len(vals)))]
    return (q(0.25), q(0.5), q(0.75))


def weighted_middle(pairs):
    """The middle of values weighted by their seconds."""
    pairs = sorted((v, w) for v, w in pairs if v is not None and w > 0)
    total = sum(w for _, w in pairs)
    if total <= 0:
        return None
    acc = 0.0
    for v, w in pairs:
        acc += w
        if acc >= total / 2:
            return v
    return pairs[-1][0]


def num(text):
    try:
        value = float(text)
        return None if math.isnan(value) else value
    except (TypeError, ValueError):
        return None


def read_runs(folder):
    """Every race of the run: {name: rows}; only races filmed to their end (rows after the race)."""
    races, partial = {}, []
    for path in sorted(glob.glob(os.path.join(folder, "race_*.csv"))):
        with open(path, encoding="utf-8") as f:
            rows = list(csv.DictReader(f))
        for r in rows:
            r["length_s"] = num(r["length_s"]) or 0.0
            r["clock_s"] = num(r["clock_s"])
            for k in ("to_mark_s", "sail_pct", "horizon_pct", "horizon_out_pct", "sail_heights", "height_m", "distance_m",
                      "look_down_deg", "angle_deg", "lens_deg", "sail_wanted_pct", "horizon_wanted_pct"):
                r[k] = num(r.get(k))
        name = os.path.splitext(os.path.basename(path))[0]
        if any(r["phase"] == "after_race" for r in rows):
            races[name] = rows
        else:
            partial.append(name)
    return races, partial


def takes_of(rows):
    """The takes: (race, take) -> {phase it began in, its whole length, its first row}; the last take of
    each race is left out (the log's end cut it short)."""
    takes = collections.OrderedDict()
    for r in rows:
        key = (r["race"], r["take"])
        t = takes.setdefault(key, {"phase": r["take_phase"], "length": 0.0, "first": r})
        t["length"] += r["length_s"]
    if takes:
        takes.popitem()
    return list(takes.values())


def stream_pictures(profile, phase):
    """The stream's pictures of a phase that a game camera makes, their shares among themselves."""
    pics = [p for p in profile["phases"][phase]["pictures"]
            if p["camera"] in LIVE_CAMERAS and p["on"] not in ("people",)]
    total = sum(p["share_pct"] for p in pics) or 1.0
    out = {}
    for p in pics:
        key = "%s %s %s" % (p["camera"], p["view"], p["on"])
        out[key] = dict(p, share=100.0 * p["share_pct"] / total)
    return out


def shares(rows, field):
    total = sum(r["length_s"] for r in rows) or 1.0
    acc = collections.Counter()
    for r in rows:
        acc[r[field]] += r["length_s"]
    return {k: 100.0 * v / total for k, v in acc.items()}


def stream_shares(pics, how):
    acc = collections.Counter()
    for p in pics.values():
        if how == "camera":
            acc[p["camera"]] += p["share"]
        elif how == "on":
            acc[p["on"]] += p["share"]
        elif how == "view":
            if p["camera"] == "drone":
                acc[p["view"]] += p["share"]
        elif how == "move":
            for move, pct in (p.get("move_pct") or {}).items():
                acc[move] += p["share"] * pct / 100.0
    if how == "view":
        total = sum(acc.values()) or 1.0
        return {k: 100.0 * v / total for k, v in acc.items()}
    return dict(acc)


def mark(ok):
    return "yes" if ok else "**no**"


def fmt(v, digits=1):
    return "-" if v is None else ("%.*f" % (digits, v))


class Report:
    def __init__(self):
        self.lines = []
        self.passed = 0
        self.failed = []

    def add(self, text=""):
        self.lines.append(text)

    def judge(self, ok, what):
        if ok is None:
            return "-"
        if ok:
            self.passed += 1
        else:
            self.failed.append(what)
        return mark(ok)


def share_table(rep, title, game, stream, tolerance, phase):
    rep.add("**%s** (within %.0f points)" % (title, tolerance))
    rep.add("")
    rep.add("| | Stream | Game | Inside |")
    rep.add("|---|---|---|---|")
    for key in sorted(set(game) | set(stream), key=lambda k: -(stream.get(k, 0.0) + game.get(k, 0.0))):
        s, g = stream.get(key, 0.0), game.get(key, 0.0)
        ok = None if s < 1.0 and g < 1.0 else abs(s - g) <= tolerance
        rep.add("| %s | %.1f %% | %.1f %% | %s |" % (key, s, g, rep.judge(ok, "%s: %s %s" % (phase, title, key))))
    rep.add("")


def take_table(rep, phase, takes, stream_q):
    lengths = [t["length"] for t in takes if t["phase"] == phase]
    game_q = quartiles(lengths)
    rep.add("**How long a take lasts** (the middle within %d %%, the quarters within %d %%; %d takes in the game)" % (
        100 * TAKE_MIDDLE_SHARE, 100 * TAKE_QUARTER_SHARE, len(lengths)))
    rep.add("")
    rep.add("| | Stream (s) | Game (s) | Inside |")
    rep.add("|---|---|---|---|")
    for i, (name, share) in enumerate((("first quarter", TAKE_QUARTER_SHARE), ("middle", TAKE_MIDDLE_SHARE), ("third quarter", TAKE_QUARTER_SHARE))):
        s = stream_q[i] if stream_q else None
        g = game_q[i] if game_q else None
        ok = None if s is None or g is None else abs(g - s) <= share * s
        rep.add("| %s | %s | %s | %s |" % (name, fmt(s), fmt(g), rep.judge(ok, "%s: take %s" % (phase, name))))
    rep.add("")
    return game_q


def framing_table(rep, phase, rows, pics):
    total = sum(r["length_s"] for r in rows) or 1.0
    by_pic = collections.defaultdict(list)
    for r in rows:
        by_pic[r["picture"]].append(r)
    rep.add("**The framing per picture, as measured on the screen** (the sail's height within %.0f points or %.0f %%, the horizon within %.0f points; pictures with at least 1 %% of the phase)" % (
        SAIL_POINTS, 100 * SAIL_SHARE, HORIZON_POINTS))
    rep.add("")
    rep.add("| Picture | Time | Sail: stream | Sail: game | Inside | Horizon: stream | Horizon: game | Out of the picture | Inside |")
    rep.add("|---|---|---|---|---|---|---|---|---|")
    for key, group in sorted(by_pic.items(), key=lambda kv: -sum(r["length_s"] for r in kv[1])):
        seconds = sum(r["length_s"] for r in group)
        if 100.0 * seconds / total < 1.0:
            continue
        sail = weighted_middle([(r["sail_pct"], r["length_s"]) for r in group])
        horizon = weighted_middle([(r["horizon_pct"], r["length_s"]) for r in group])
        out = sum((r["horizon_out_pct"] or 0.0) * r["length_s"] for r in group) / (seconds or 1.0)
        p = pics.get(key)
        s_sail = p["sail_pct"]["median"] if p and p.get("sail_pct") else None
        s_hor = p["horizon_pct"]["median"] if p and p.get("horizon_pct") else None
        ok_sail = None if s_sail is None or sail is None else abs(sail - s_sail) <= max(SAIL_POINTS, SAIL_SHARE * s_sail)
        ok_hor = None if s_hor is None or horizon is None else abs(horizon - s_hor) <= HORIZON_POINTS
        rep.add("| %s | %.0f %% | %s %% | %s %% | %s | %s %% | %s %% | %.0f %% | %s |" % (
            key, 100.0 * seconds / total, fmt(s_sail, 0), fmt(sail), rep.judge(ok_sail, "%s: sail of %s" % (phase, key)),
            fmt(s_hor, 0), fmt(horizon), out, rep.judge(ok_hor, "%s: horizon of %s" % (phase, key))))
    rep.add("")


def position_table(rep, rows):
    by_pic = collections.defaultdict(list)
    for r in rows:
        if r["camera"] == "drone":
            by_pic[r["picture"]].append(r)
    rep.add("**Where the drone is** (the stream: the lead's measurement, drone_position.md. The height in sail heights is "
            "measured without the lens and is the firm number; the metres assume a 47-degree lens and a sail top 3.5 m up, "
            "about +-15 %%. The game inside the stream's middle half for the height and the distance, the look-down within %.0f degrees. "
            "The game's metres scale with its own rig: its sail top stands higher than 3.5 m)" % LOOK_DOWN_DEG)
    rep.add("")
    rep.add("| Picture | Sail heights: stream | Sail heights: game | Inside | Height: stream | Height: game | Inside | Distance: stream | Distance: game | Inside | Looks down: stream | Looks down: game | Inside | Angle round the board: game | Lens: game | The game's sail top (height / sail heights) |")
    rep.add("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for key, group in sorted(by_pic.items(), key=lambda kv: -sum(r["length_s"] for r in kv[1])):
        k = weighted_middle([(r.get("sail_heights"), r["length_s"]) for r in group])
        h = weighted_middle([(r["height_m"], r["length_s"]) for r in group])
        d = weighted_middle([(r["distance_m"], r["length_s"]) for r in group])
        down = weighted_middle([(r["look_down_deg"], r["length_s"]) for r in group])
        angle = weighted_middle([(r["angle_deg"], r["length_s"]) for r in group])
        lens = weighted_middle([(r["lens_deg"], r["length_s"]) for r in group])
        ref = DRONE_POSITION.get(key)
        ref = ref or (None, None, None, None)
        sk, sh, sd, sdown = ref
        cells = [key]
        for stream_v, game_v, what, digits, unit in ((sk, k, "sail heights", 2, ""), (sh, h, "height", 1, " m"), (sd, d, "distance", 0, " m")):
            if stream_v is None:
                cells += ["-", "%s%s" % (fmt(game_v, digits), unit if game_v is not None else ""), "-"]
                continue
            middle, low, high = stream_v
            ok = None if game_v is None else low <= game_v <= high
            cells += ["%s%s (%s to %s)" % (fmt(middle, digits), unit, fmt(low, digits), fmt(high, digits)),
                      "%s%s" % (fmt(game_v, digits), unit), rep.judge(ok, "race: %s of %s" % (what, key))]
        if sdown is None:
            cells += ["-", "%s deg" % fmt(down, 0), "-"]
        else:
            ok = None if down is None else abs(down - sdown) <= LOOK_DOWN_DEG
            cells += ["%.0f deg" % sdown, "%s deg" % fmt(down, 0), rep.judge(ok, "race: look-down of %s" % key)]
        top = weighted_middle([(r["height_m"] / r["sail_heights"], r["length_s"]) for r in group
                               if r["height_m"] is not None and r.get("sail_heights") and r["sail_heights"] > 0.5])
        cells += ["%s deg" % fmt(angle, 0), "%s deg" % fmt(lens, 1), "-" if top is None else "%.1f m (the stream's: about 3.5)" % top]
        rep.add("| " + " | ".join(cells) + " |")
    rep.add("")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("folder")
    ap.add_argument("--profile", required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    with open(a.profile, encoding="utf-8") as f:
        profile = json.load(f)
    races, partial = read_runs(a.folder)
    rep = Report()
    if not races:
        print("No race filmed to its end in %s." % a.folder)
        return 1
    all_rows = [r for rows in races.values() for r in rows]
    director = all_rows[0]["director"]
    takes = [t for rows in races.values() for t in takes_of(rows)]
    rep.add("# The TV director beside the real stream")
    rep.add("")
    rep.add("The game's director: **%s**. Races: %d (%s)%s. The stream: %s." % (
        director, len(races), ", ".join(races), "; left out, not filmed to the end: " + ", ".join(partial) if partial else "", profile["source"]))
    rep.add("")
    summary_at = len(rep.lines)
    for phase in PHASES:
        rows = [r for r in all_rows if r["phase"] == phase]
        pics = stream_pictures(profile, phase)
        prof = profile["phases"][phase]
        seconds = sum(r["length_s"] for r in rows) / len(races)
        rep.add("## %s" % PHASE_TITLES[phase])
        rep.add("")
        rep.add("The stream: %.0f s per heat. The game: %.0f s per race." % (prof["seconds_per_heat"], seconds))
        rep.add("")
        if not rows:
            continue
        stream_q = prof["take_length_action"] if phase in ("pre_start", "after_race") and prof.get("take_length_action") else prof["take_length"]
        take_table(rep, phase, takes, (stream_q["p25_s"], stream_q["median_s"], stream_q["p75_s"]))
        share_table(rep, "Time per picture", shares(rows, "picture"), {k: p["share"] for k, p in pics.items()}, SHARE_POINTS, phase)
        share_table(rep, "Time per camera", shares(rows, "camera"), stream_shares(pics, "camera"), SHARE_POINTS, phase)
        share_table(rep, "Time per subject", shares(rows, "on"), stream_shares(pics, "on"), SHARE_POINTS, phase)
        drone_rows = [r for r in rows if r["camera"] == "drone"]
        if drone_rows:
            share_table(rep, "The drone's view (of the drone's time)", shares(drone_rows, "view"), stream_shares(pics, "view"), LOOSE_SHARE_POINTS, phase)
        share_table(rep, "How the camera moves", shares(rows, "move"), stream_shares(pics, "move"), LOOSE_SHARE_POINTS, phase)
        framing_table(rep, phase, rows, pics)
        if phase == "race":
            position_table(rep, rows)
            race_extras(rep, races, takes, profile)
        if phase == "start":
            start_extras(rep, races)
    steadiness(rep, races)
    rep.lines[summary_at:summary_at] = [
        "**In short:** %d checks inside the tolerance, %d outside%s." % (
            rep.passed, len(rep.failed), (": " + "; ".join(rep.failed)) if rep.failed else ""), ""]
    with open(a.out, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(rep.lines) + "\n")
    print("%d races; %d checks inside, %d outside. The report: %s" % (len(races), rep.passed, len(rep.failed), a.out))
    for what in rep.failed:
        print("  outside: " + what)
    return 0


def start_extras(rep, races):
    line, first = [], []
    for rows in races.values():
        parts = [r for r in rows if r["part"] == "1" and r["clock_s"] is not None]
        line_cuts = [r for r in parts if r["phase"] == "start" and r["shot"] == "COMMITTEE"]
        if line_cuts:
            line.append(-line_cuts[0]["clock_s"])
        after = sorted(r["clock_s"] for r in parts if r["clock_s"] > 1.0)
        if after:
            first.append(after[0])
    rep.add("**The start's timing**")
    rep.add("")
    rep.add("| | Stream | Game | Inside |")
    rep.add("|---|---|---|---|")
    lq = quartiles(line)
    ok = None if not lq else 1.0 <= lq[1] <= 4.0
    rep.add("| The line drone comes, s before the gun (quarters; the stream counted on nine heats, the notes say 1 to 4) | %s | %s | %s |" % (
        " / ".join(fmt(x) for x in LINE_DRONE_BEFORE_GUN_S), " / ".join(fmt(x) for x in lq) if lq else "-", rep.judge(ok, "start: the line drone's time")))
    rep.add("")
    rep.extras_first_cut = first


def race_extras(rep, races, takes, profile):
    first = getattr(rep, "extras_first_cut", None)
    if first is None:
        first = []
        for rows in races.values():
            after = sorted(r["clock_s"] for r in rows if r["part"] == "1" and r["clock_s"] is not None and r["clock_s"] > 1.0)
            if after:
                first.append(after[0])
    pf = profile["race"]["first_cut_after_gun_s"]
    fq = quartiles(first)
    marks = [t for t in takes if t["phase"] == "race" and t["first"]["on"] == "mark"]
    mq = quartiles([t["length"] for t in marks])
    to_mark = [t["first"]["to_mark_s"] for t in marks if t["first"]["to_mark_s"] is not None]
    tq = quartiles(to_mark)
    sm = profile["race"]["mark_beat"]
    rep.add("**The start, the marks and the finish in the race**")
    rep.add("")
    rep.add("| | Stream | Game | Inside |")
    rep.add("|---|---|---|---|")
    ok = None if not fq else abs(fq[1] - pf["median"]) <= FIRST_CUT_S
    rep.add("| The first cut more than 1 s after the gun, s (quarters; middle within %.0f s) | %s / %s / %s | %s | %s |" % (
        FIRST_CUT_S, pf["p25"], pf["median"], pf["p75"], " / ".join(fmt(x) for x in fq) if fq else "-", rep.judge(ok, "race: first cut after the gun")))
    ok = None if not mq else abs(mq[1] - sm["median_s"]) <= TAKE_MIDDLE_SHARE * sm["median_s"]
    rep.add("| A take at a mark, s (quarters; middle within %d %%) | %s / %s / %s | %s | %s |" % (
        100 * TAKE_MIDDLE_SHARE, sm["p25_s"], sm["median_s"], sm["p75_s"], " / ".join(fmt(x) for x in mq) if mq else "-", rep.judge(ok, "race: mark take length")))
    ok = None if not tq else MARK_CUT_BEFORE_S[0] - 0.5 <= tq[1] <= MARK_CUT_BEFORE_S[1] + 0.5
    rep.add("| The cut to a mark comes before its board arrives, s (the notes: 2 to 5) | 2 to 5 | %s | %s |" % (
        " / ".join(fmt(x) for x in tq) if tq else "-", rep.judge(ok, "race: cut before the mark")))
    rep.add("| Takes at a mark per race | - | %.1f | - |" % (len(marks) / max(len(races), 1)))
    rep.add("")


def steadiness(rep, races):
    rep.add("## From race to race")
    rep.add("")
    rep.add("How much the main numbers move between the races (each race on its own).")
    rep.add("")
    rep.add("| Race | Race takes (middle, s) | On the front | At a mark | The pack | Beach cam | Race seconds |")
    rep.add("|---|---|---|---|---|---|---|")
    cols = collections.defaultdict(list)
    for name, rows in races.items():
        race_rows = [r for r in rows if r["phase"] == "race"]
        q = quartiles([t["length"] for t in takes_of(rows) if t["phase"] == "race"])
        on = shares(race_rows, "on")
        cam = shares(race_rows, "camera")
        vals = [q[1] if q else None, on.get("front", 0.0), on.get("mark", 0.0), on.get("pack", 0.0), cam.get("shore_long_lens", 0.0),
                sum(r["length_s"] for r in race_rows)]
        for i, v in enumerate(vals):
            if v is not None:
                cols[i].append(v)
        rep.add("| %s | %s | %.0f %% | %.0f %% | %.0f %% | %.0f %% | %.0f |" % (name, fmt(vals[0]), vals[1], vals[2], vals[3], vals[4], vals[5]))
    if len(races) > 1:
        rep.add("| lowest to highest | %s | %s | %s | %s | %s | %s |" % tuple(
            ("%.1f to %.1f" % (min(cols[i]), max(cols[i]))) if cols[i] else "-" for i in range(6)))
    rep.add("")


if __name__ == "__main__":
    raise SystemExit(main())
