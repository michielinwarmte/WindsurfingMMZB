"""The stream's director as a profile the game's TV director can be set to.

shot_stats.py counts everything the notes hold. This boils the notes down to the few
pictures a game camera can make, per phase of a heat, with for each picture: its share of
the phase's time, how long it stays, and its framing (how tall the followed sail is in the
picture and where the horizon sits). The framing is what the game copies: with its own lens
it works out the distance and the height that give the same picture.

    python -E -P tools/broadcast/director_profile.py <media root> --ids=<id,...>
        --heats=<json> [--formats=regular,obstacle] --out=<stream_profile.json>

A picture = a camera (drone or the shore's long lens) + where it is against the boards
(behind-side, side, front-side: the notes' behind and front are folded in) + what it is on
(front: the leader or the lead group; pack: a duel, the chasers, one rider, the fleet; mark;
line: the start or finish line).
"""
import argparse
import collections
import json

import shot_stats as ss

VIEW = {"behind": "behind_side", "behind_side": "behind_side", "side": "side", "front_side": "front_side",
        "front": "front_side", "top_down": "top_down", "na": "na"}
ON = {"leader": "front", "lead_group": "front", "duel": "pack", "chasers": "pack", "one_rider": "pack",
      "fleet": "fleet", "mark": "mark", "start_line": "line", "finish_line": "line", "shore": "scenery",
      "people": "people", "graphic": "graphic", "none": "scenery"}


def spread(pairs):
    q = ss.weighted_quantiles(pairs)
    return {"p25": q[0], "median": q[1], "p75": q[2]} if q else None


def beat_lengths(rows):
    vals = sorted(r["len"] for r in rows)
    q = lambda p: round(vals[min(len(vals) - 1, int(p * len(vals)))], 1)
    return {"p25_s": q(0.25), "median_s": q(0.5), "p75_s": q(0.75), "beats": len(vals)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("root")
    ap.add_argument("--ids", required=True)
    ap.add_argument("--heats", required=True)
    ap.add_argument("--formats", default="regular,obstacle")
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    with open(a.heats, encoding="utf-8") as f:
        heats = json.load(f)
    formats = set(a.formats.split(","))
    rows, used = [], []
    for vid in a.ids.split(","):
        if heats.get(vid, {}).get("format") not in formats:
            continue
        r, _ = ss.read("%s/%s/shots/shot_notes.csv" % (a.root, vid), vid)
        ss.mark_takes(r)
        r = ss.apply_heats(r, heats)
        for x in r:
            x["take"] = (vid, x["take"])
            # Seconds against the gun and the winner's finish, for the timing of the sequences.
            x["from_gun"] = x["a"] - heats[vid]["gun_s"]
            x["from_finish"] = x["a"] - heats[vid]["finish_s"]
        rows += r
        used.append(vid)

    profile = {"source": "shot notes of %d slalom heat replays, World Cup Fuerteventura 2026 (Slalom-X)" % len(used),
               "videos": used, "start_phase_s": [-ss.START_BEFORE_S, ss.START_AFTER_S], "phases": {}}
    for ph in ss.PHASES:
        pr = [r for r in rows if r["phase"] == ph]
        total = sum(r["len"] for r in pr) or 1.0
        groups = collections.defaultdict(list)
        for r in pr:
            if r["camera"] in ("drone", "shore_long_lens"):
                key = (r["camera"], VIEW[r["view"]] if r["camera"] == "drone" else "shore", ON[r["subject"]])
            else:
                key = (r["camera"], "", "")
            groups[key].append(r)
        pictures = []
        for key, g in sorted(groups.items(), key=lambda kv: -sum(r["len"] for r in kv[1])):
            sec = sum(r["len"] for r in g)
            moves = collections.Counter()
            for r in g:
                moves[r["move"]] += r["len"]
            pic = {"camera": key[0], "view": key[1], "on": key[2], "share_pct": round(100.0 * sec / total, 1),
                   "beat": beat_lengths(g),
                   "move_pct": {k: round(100.0 * v / sec) for k, v in moves.most_common(3)}}
            if key[0] in ("drone", "shore_long_lens"):
                pic["sail_pct"] = spread([(r["sail"], r["len"]) for r in g])
                pic["horizon_pct"] = spread([(r["horizon"], r["len"]) for r in g])
                pic["horizon_out_of_picture_pct"] = round(
                    100.0 * sum(r["len"] for r in g if r["horizon"] is None) / sec)
            pictures.append(pic)
        action = [r for r in pr if r["camera"] in ("drone", "shore_long_lens")]
        profile["phases"][ph] = {
            "seconds_per_heat": round(total / max(len(used), 1), 1),
            "take_length": ss.lengths(pr, rows),
            "take_length_action": ss.lengths(action, rows) if action else None,
            "pictures": pictures,
        }
    # The marks: when the picture goes to the mark against the moment the notes call the rounding.
    race = [r for r in rows if r["phase"] == "race"]
    mark = [r for r in race if r["subject"] == "mark" or r["moment"] == "mark_rounding"]
    # The first cut of the race: the first take that begins after the gun, per heat.
    first_cuts = []
    for vid in used:
        starts = {}
        for r in rows:
            if r["video"] == vid:
                starts[r["take"]] = min(starts.get(r["take"], 1e9), r["a"])
        after = sorted(t - heats[vid]["gun_s"] for t in starts.values() if t - heats[vid]["gun_s"] > 1.0)
        if after:
            first_cuts.append(round(after[0], 1))
    profile["race"] = {
        "first_cut_after_gun_s": spread([(t, 1.0) for t in first_cuts]),
        "mark_time_pct": round(100.0 * sum(r["len"] for r in mark) / (sum(r["len"] for r in race) or 1.0), 1),
        "mark_beat": beat_lengths(mark) if mark else None,
        "on_pct": {k: v for k, v in sorted(
            collections.Counter({ON[r["subject"]]: 0 for r in race}).items())},
    }
    on = collections.Counter()
    for r in race:
        on[ON[r["subject"]]] += r["len"]
    tot = sum(on.values()) or 1.0
    profile["race"]["on_pct"] = {k: round(100.0 * v / tot, 1) for k, v in on.most_common()}
    with open(a.out, "w", encoding="utf-8", newline="\n") as f:
        json.dump(profile, f, indent=1)
        f.write("\n")
    for ph, d in profile["phases"].items():
        print("== %s: %.0f s per heat; a take lasts %s" % (ph, d["seconds_per_heat"], d["take_length_action"] or d["take_length"]))
        for p in d["pictures"][:9]:
            s, h = p.get("sail_pct"), p.get("horizon_pct")
            print("   %5.1f %%  %-15s %-11s %-7s beat %4.1f s (%d)  sail %s  horizon %s  %s"
                  % (p["share_pct"], p["camera"], p["view"], p["on"], p["beat"]["median_s"], p["beat"]["beats"],
                     "%g (%g-%g)" % (s["median"], s["p25"], s["p75"]) if s else "-",
                     "%g (%g-%g)" % (h["median"], h["p25"], h["p75"]) if h else "-", p["move_pct"]))
    print("race:", profile["race"])


if __name__ == "__main__":
    main()
