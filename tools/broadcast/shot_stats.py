"""The stream's camera work in numbers, from the shot notes (SHOT_NOTES_GUIDE.md).

Reads <media root>/<id>/shots/shot_notes.csv of the replays named, checks every word against
the guide's lists, and counts per phase of a heat (pre_start, start, race, after_race):
which camera, from where, how high, on what, moving how, for how long, and how the picture
is framed (where the horizon sits, how tall the sail is). Everything is weighted by time on
screen, not by the number of shots.

    python -E -P tools/broadcast/shot_stats.py <media root> --ids=<id,id,...> [--out=<folder>]
        [--agree=<id>]     also compare shot_notes.csv with shot_notes_check.csv of this
                           replay (two readers, apart): the share of seconds they agree on
        [--heats=<json>]   per replay {"gun_s": .., "finish_s": .., "recalled": [[gun, recall]],
                           "format": "regular" | "obstacle" | "long_distance"}: the start phase
                           is then set by the clock, the same for every heat
        [--formats=regular,obstacle]   only the heats of these formats

Writes shot_stats.json (the numbers the game's TV director is set to) and shot_stats.md.
"""
import argparse
import collections
import csv
import json
import os

PHASES = ["pre_start", "start", "race", "after_race"]
ALLOWED = {
    "camera": ["drone", "shore_long_lens", "boat", "beach_handheld", "graphic", "other"],
    "view": ["behind", "behind_side", "side", "front_side", "front", "top_down", "na"],
    "height": ["water", "low", "medium", "high", "top_down", "na"],
    "boards": ["0", "1", "2", "3", "4-6", "7+"],
    "subject": ["leader", "lead_group", "duel", "chasers", "fleet", "one_rider", "mark", "start_line",
                "finish_line", "shore", "people", "graphic", "none"],
    "move": ["follows", "static", "pan", "push_in", "pull_out", "orbit", "fly_over", "na"],
    "phase": PHASES,
    "moment": ["intro", "pre_start", "start", "first_reach", "reach", "mark_approach", "mark_rounding",
               "last_leg", "finish", "after_finish", "replay", "results", "interview", "other"],
    "sure": ["yes", "no"],
}
FIELDS = ["camera", "view", "height", "subject", "move", "boards", "moment"]


def number(text):
    try:
        return float(text)
    except (TypeError, ValueError):
        return None


def read(path, video):
    rows, bad = [], []
    with open(path, encoding="utf-8-sig", newline="") as f:
        for n, r in enumerate(csv.DictReader(f), 2):
            r = {k.strip(): (v or "").strip() for k, v in r.items() if k}
            a, b = number(r.get("start_s")), number(r.get("end_s"))
            if a is None or b is None or b <= a:
                bad.append("%s line %d: times %r to %r" % (video, n, r.get("start_s"), r.get("end_s")))
                continue
            for col, words in ALLOWED.items():
                if r.get(col, "") not in words:
                    bad.append("%s line %d: %s = %r" % (video, n, col, r.get(col, "")))
            r["video"], r["a"], r["b"], r["len"] = video, a, b, b - a
            r["horizon"] = number(r.get("horizon_pct"))
            r["sail"] = number(r.get("sail_pct"))
            rows.append(r)
    return rows, bad


START_BEFORE_S = 10.0   # the start phase: from this long before the gun ...
START_AFTER_S = 12.0    # ... until this long after it (SHOT_NOTES_GUIDE.md, "The four phases")


def mark_takes(rows):
    """Number the real takes: the cut detector's shots, set right by the reader's notes.
    A part noted "missed cut" starts a new take; a shot noted "same take as shot N" runs on."""
    take, last = 0, None
    for r in sorted(rows, key=lambda r: (r["video"], r["a"])):
        note = r.get("note", "").lower()
        new = last is None or r["video"] != last["video"]
        if not new and r["shot"] != last["shot"]:
            new = "same take" not in note
        elif not new and "missed cut" in note:
            new = True
        if new:
            take += 1
        r["take"] = take
        last = r


def apply_heats(rows, heats):
    """The border between pre_start and start set by the clock, the same for every heat:
    the start phase runs from START_BEFORE_S before the gun to START_AFTER_S after it (a
    recalled try: from START_BEFORE_S before its gun to the recall). Beats are cut at the
    borders. The readers' own border differed from heat to heat; the race's end stays theirs."""
    out = []
    for r in rows:
        h = heats.get(r["video"])
        if not h or h.get("gun_s") is None or r["phase"] == "after_race":
            out.append(r)
            continue
        windows = [(a - START_BEFORE_S, b) for a, b in h.get("recalled", [])]
        windows.append((h["gun_s"] - START_BEFORE_S, h["gun_s"] + START_AFTER_S))
        last_end = windows[-1][1]
        cuts = sorted(set([r["a"], r["b"]] + [t for w in windows for t in w if r["a"] < t < r["b"]]))
        for a, b in zip(cuts, cuts[1:]):
            piece = dict(r)
            piece["a"], piece["b"], piece["len"] = a, b, b - a
            mid = (a + b) / 2.0
            if any(w0 <= mid < w1 for w0, w1 in windows):
                piece["phase"] = "start"
            elif mid < last_end:
                piece["phase"] = "pre_start"
            else:
                piece["phase"] = "race"
            out.append(piece)
    return out


def weighted_quantiles(pairs, qs=(0.25, 0.5, 0.75)):
    """Quantiles of values weighted by seconds on screen."""
    pairs = sorted((v, w) for v, w in pairs if v is not None and w > 0)
    total = sum(w for _, w in pairs)
    if not pairs or total <= 0:
        return None
    out, run, i = [], 0.0, 0
    for q in qs:
        while i < len(pairs) - 1 and run + pairs[i][1] < q * total:
            run += pairs[i][1]
            i += 1
        out.append(pairs[i][0])
    return out


def shares(rows, col):
    t = collections.Counter()
    for r in rows:
        t[r[col]] += r["len"]
    total = sum(t.values()) or 1.0
    return {k: round(100.0 * v / total, 1) for k, v in t.most_common()}


def lengths(rows, everything=None):
    """How long the picture stays on one camera: a whole take, counted in the phase it starts in."""
    everything = everything if everything is not None else rows
    whole, first = collections.Counter(), {}
    for r in everything:
        whole[r["take"]] += r["len"]
        if r["take"] not in first or r["a"] < first[r["take"]]["a"]:
            first[r["take"]] = r
    mine = set(id(r) for r in rows)
    vals = sorted(whole[t] for t, r in first.items() if id(r) in mine)
    if not vals:
        return None
    q = lambda p: vals[min(len(vals) - 1, int(p * len(vals)))]
    return {"shots": len(vals), "p25_s": round(q(0.25), 1), "median_s": round(q(0.5), 1),
            "p75_s": round(q(0.75), 1), "longest_s": round(vals[-1], 1)}


def frame(rows):
    out = {}
    for name in ("horizon", "sail"):
        qs = weighted_quantiles([(r[name], r["len"]) for r in rows])
        if qs:
            out[name + "_pct"] = {"p25": qs[0], "median": qs[1], "p75": qs[2]}
    return out


def kinds(rows, top=8):
    """The pictures that fill the time: camera + view + height + subject + move."""
    t, groups = collections.Counter(), collections.defaultdict(list)
    for r in rows:
        key = (r["camera"], r["view"], r["height"], r["subject"], r["move"])
        t[key] += r["len"]
        groups[key].append(r)
    total = sum(t.values()) or 1.0
    out = []
    for key, sec in t.most_common(top):
        g = groups[key]
        row = {"camera": key[0], "view": key[1], "height": key[2], "subject": key[3], "move": key[4],
               "share_pct": round(100.0 * sec / total, 1), "beats": len(g),
               "median_beat_s": round(sorted(x["len"] for x in g)[len(g) // 2], 1)}
        row.update(frame(g))
        out.append(row)
    return out


def agreement(rows_a, rows_b):
    """Second by second: the share of seconds on which two readers wrote the same word."""
    end = int(min(max(r["b"] for r in rows_a), max(r["b"] for r in rows_b)))

    def at(rows, t):
        for r in rows:
            if r["a"] <= t < r["b"]:
                return r
        return None
    same, n, diffs = collections.Counter(), 0, collections.defaultdict(list)
    for t in range(end):
        a, b = at(rows_a, t + 0.5), at(rows_b, t + 0.5)
        if a is None or b is None:
            continue
        n += 1
        for col in ["phase"] + FIELDS:
            same[col] += a[col] == b[col]
        for name in ("horizon", "sail"):
            if a[name] is not None and b[name] is not None:
                diffs[name].append(abs(a[name] - b[name]))
    out = {"seconds": n}
    for col in ["phase"] + FIELDS:
        out[col] = round(100.0 * same[col] / max(n, 1), 1)
    for name, d in diffs.items():
        d.sort()
        out[name + "_pct_median_difference"] = d[len(d) // 2] if d else None
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("root")
    ap.add_argument("--ids", required=True)
    ap.add_argument("--agree", default="")
    ap.add_argument("--heats", default="")
    ap.add_argument("--formats", default="")
    ap.add_argument("--out", default="")
    a = ap.parse_args()
    heats = {}
    if a.heats:
        with open(a.heats, encoding="utf-8") as f:
            heats = json.load(f)
    formats = set(x for x in a.formats.split(",") if x)
    out = a.out or os.path.join(os.path.dirname(a.root.rstrip("/\\")), "shot_stats")
    os.makedirs(out, exist_ok=True)

    rows, bad, per_video = [], [], {}
    for vid in a.ids.split(","):
        if formats and heats.get(vid, {}).get("format") not in formats:
            continue
        path = os.path.join(a.root, vid, "shots", "shot_notes.csv")
        if not os.path.exists(path):
            bad.append("%s: no shot_notes.csv" % vid)
            continue
        r, b = read(path, vid)
        mark_takes(r)
        r = apply_heats(r, heats)
        rows += r
        bad += b
        per_video[vid] = {"beats": len(r), "seconds": round(sum(x["len"] for x in r), 1),
                          "unsure_pct": round(100.0 * sum(x["len"] for x in r if x.get("sure") == "no")
                                              / max(sum(x["len"] for x in r), 1.0), 1)}
    for i, r in enumerate(rows):
        r["take"] = (r["video"], r["take"])
    stats = {"videos": per_video, "formats": sorted(formats) or "all", "problems": bad, "phases": {}}
    for ph in PHASES:
        pr = [r for r in rows if r["phase"] == ph]
        if not pr:
            continue
        action = [r for r in pr if r["camera"] in ("drone", "shore_long_lens", "boat")]
        stats["phases"][ph] = {
            "seconds": round(sum(r["len"] for r in pr), 1),
            "seconds_per_heat": round(sum(r["len"] for r in pr) / max(len(per_video), 1), 1),
            "shot_length": lengths(pr, rows),
            "shot_length_by_camera": {c: lengths([r for r in pr if r["camera"] == c], rows)
                                      for c in ("drone", "shore_long_lens")
                                      if any(r["camera"] == c for r in pr)},
            "shares_pct": {col: shares(pr, col) for col in FIELDS},
            "drone": {"view": shares([r for r in pr if r["camera"] == "drone"], "view"),
                      "height": shares([r for r in pr if r["camera"] == "drone"], "height"),
                      "move": shares([r for r in pr if r["camera"] == "drone"], "move"),
                      "subject": shares([r for r in pr if r["camera"] == "drone"], "subject"),
                      "frame_by_height": {h: frame([r for r in pr if r["camera"] == "drone" and r["height"] == h])
                                          for h in ("water", "low", "medium", "high", "top_down")
                                          if any(r["camera"] == "drone" and r["height"] == h for r in pr)}},
            "pictures": kinds(action),
        }
    # Inside the race: what the picture is on at each moment.
    race = [r for r in rows if r["phase"] == "race"]
    stats["race_moments"] = {m: {"seconds": round(sum(r["len"] for r in g), 1), "pictures": kinds(g, 4)}
                             for m in ALLOWED["moment"]
                             for g in [[r for r in race if r["moment"] == m]] if g}
    # What follows what: from one camera picture to the next, in the race.
    follow = collections.Counter()
    ordered = sorted(race, key=lambda r: (r["video"], r["a"]))
    for x, y in zip(ordered, ordered[1:]):
        if x["video"] == y["video"] and x["take"] != y["take"]:
            follow[("%s %s %s" % (x["camera"], x["height"], x["subject"]),
                    "%s %s %s" % (y["camera"], y["height"], y["subject"]))] += 1
    stats["race_cuts"] = [{"from": k[0], "to": k[1], "times": n} for k, n in follow.most_common(15)]
    if a.agree:
        p1 = os.path.join(a.root, a.agree, "shots", "shot_notes.csv")
        p2 = os.path.join(a.root, a.agree, "shots", "shot_notes_check.csv")
        if os.path.exists(p1) and os.path.exists(p2):
            r1, _ = read(p1, a.agree)
            r2, b2 = read(p2, a.agree)
            stats["agreement"] = agreement(r1, r2)
            stats["agreement"]["video"] = a.agree
            stats["problems"] += ["check: " + x for x in b2]
    with open(os.path.join(out, "shot_stats.json"), "w", encoding="utf-8") as f:
        json.dump(stats, f, indent=1)

    md = ["# The stream's camera work in numbers", "",
          "From the shot notes of %d replays (%d beats, %.0f min). Shares are of the time on screen."
          % (len(per_video), len(rows), sum(r["len"] for r in rows) / 60.0), ""]
    for ph, s in stats["phases"].items():
        md += ["## %s (%.0f s per heat)" % (ph, s["seconds_per_heat"]), ""]
        sl = s["shot_length"]
        md += ["A shot lasts %.1f s (the middle one; a quarter are under %.1f s, a quarter over %.1f s; the longest %.1f s; %d shots)."
               % (sl["median_s"], sl["p25_s"], sl["p75_s"], sl["longest_s"], sl["shots"]), ""]
        for col in ("camera", "subject", "move"):
            md.append("- **%s:** " % col + ", ".join("%s %s %%" % kv for kv in s["shares_pct"][col].items()))
        md.append("- **the drone's view:** " + ", ".join("%s %s %%" % kv for kv in s["drone"]["view"].items()))
        md.append("- **the drone's height:** " + ", ".join("%s %s %%" % kv for kv in s["drone"]["height"].items()))
        md += ["", "| Share | Camera | View | Height | On | Move | Beat (s) | Horizon from top | Sail height |",
               "|---|---|---|---|---|---|---|---|---|"]
        for k in s["pictures"]:
            hz = k.get("horizon_pct")
            sa = k.get("sail_pct")
            md.append("| %s %% | %s | %s | %s | %s | %s | %s | %s | %s |"
                      % (k["share_pct"], k["camera"], k["view"], k["height"], k["subject"], k["move"], k["median_beat_s"],
                         ("%g %% (%g to %g)" % (hz["median"], hz["p25"], hz["p75"])) if hz else "-",
                         ("%g %% (%g to %g)" % (sa["median"], sa["p25"], sa["p75"])) if sa else "-"))
        md.append("")
    if "agreement" in stats:
        g = stats["agreement"]
        md += ["## How far two readers agree (%s, %d s)" % (g["video"], g["seconds"]), "",
               ", ".join("%s %s %%" % (c, g[c]) for c in ["phase"] + FIELDS) + ".",
               "Middle difference: horizon %s points, sail height %s points."
               % (g.get("horizon_pct_median_difference"), g.get("sail_pct_median_difference")), ""]
    if bad:
        md += ["## Problems in the notes (%d)" % len(stats["problems"]), ""] + ["- " + b for b in stats["problems"][:60]]
    with open(os.path.join(out, "shot_stats.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(md) + "\n")
    print("%d replays, %d beats, %d problems -> %s" % (len(per_video), len(rows), len(stats["problems"]), out))


if __name__ == "__main__":
    main()
