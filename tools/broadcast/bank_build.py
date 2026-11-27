"""Build the game's commentary bank from the reader's judged sheets.

    python -E -P tools/broadcast/bank_build.py <bank folder> <out commentary_bank.json>
        [--source="..."]

Reads <bank folder>/candidates.json (bank_candidates.py) and every
<bank folder>/judged/sheet_*.tsv the reader wrote:

    id <tab> keep <tab> moment <tab> needs <tab> text <tab> note

    keep     y or n
    moment   the moment the line belongs to (BANK_FORMAT.md's list)
    needs    the needs words, comma separated, or empty
    text     the line as the bank should hold it (his words; only a mis-heard word, a slot or
             the spelling may differ from the candidate), or empty = as the candidate has it

The count, the level, the seconds and the place it was said come from the measurements, not
from the reader. Lines the reader kept but that break the format (an unknown moment, slot or
needs word) are listed and left out.
"""
import argparse
import collections
import glob
import json
import os
import re
import sys

MOMENTS = ["pre_start", "start_gun", "start_good", "start_bad", "over_early", "identify", "speed", "leader",
           "rundown", "lead_change", "overtake", "chase", "fight", "airtime", "filler", "tactics", "tension",
           "form", "conditions", "mark_approach", "gybe_good", "gybe_safe", "gybe_bad", "fall", "near_miss",
           "trouble", "wow", "oh_no", "last_leg", "finish_win", "finish_place", "photo_finish", "after_race",
           "camera", "unsure",
           # an event week (the game's EventBroadcast)
           "heat_called", "heat_favourite", "heat_through", "heat_out", "final_win", "standings", "event_win"]
SLOTS = ["rider", "rider2", "place", "brand", "colour", "mark", "leg", "national", "nation_adj",
         "heat", "round", "elimination", "event"]
NEEDS = ["leader", "not_leader", "podium", "big_lead", "close", "camera_wide", "camera_close", "many", "pair",
         "last_lap", "wind_strong", "wind_light", "choppy", "flat", "windward", "leeward", "dirty_air",
         "final", "not_final"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("bank")
    ap.add_argument("out")
    ap.add_argument("--source", default="World Cup Fuerteventura 2026, Slalom-X: 5 stream days and 11 heat replays")
    ap.add_argument("--made", default="")
    a = ap.parse_args()
    with open(os.path.join(a.bank, "candidates.json"), encoding="utf-8") as f:
        cands = json.load(f)
    lines, bad, seen_text = [], [], set()
    judged = kept = 0
    for path in sorted(glob.glob(os.path.join(a.bank, "judged", "sheet_*.tsv"))):
        with open(path, encoding="utf-8") as f:
            for n, raw in enumerate(f):
                p = raw.rstrip("\n").split("\t")
                if n == 0 and p[0] == "id":
                    continue
                if len(p) < 3 or p[0] not in cands:
                    if raw.strip():
                        bad.append("%s line %d: not a candidate's row" % (os.path.basename(path), n + 1))
                    continue
                p += [""] * (6 - len(p))
                judged += 1
                if p[1].strip().lower() not in ("y", "yes"):
                    continue
                c = cands[p[0]]
                text = p[4].strip() or c["line"]
                moment = p[2].strip()
                needs = [x.strip() for x in p[3].split(",") if x.strip()]
                slots = re.findall(r"\{([a-z_0-9]+)\}", text)
                why = []
                if moment not in MOMENTS:
                    why.append("moment %r" % moment)
                why += ["slot %r" % s for s in slots if s not in SLOTS]
                why += ["needs %r" % x for x in needs if x not in NEEDS]
                if "{" in re.sub(r"\{[a-z_0-9]+\}", "", text) or "}" in re.sub(r"\{[a-z_0-9]+\}", "", text):
                    why.append("a broken slot")
                if why:
                    bad.append("%s %s: %s" % (p[0], text, ", ".join(why)))
                    continue
                if (moment, text.lower()) in seen_text:
                    continue
                seen_text.add((moment, text.lower()))
                kept += 1
                lines.append({"id": c["id"], "moment": moment, "text": text, "slots": slots, "level": c["level"],
                              "seconds": c["seconds"], "count": c["count"], "needs": needs, "src": c["src"]})
    lines.sort(key=lambda l: (MOMENTS.index(l["moment"]), -l["count"], l["text"]))
    per = collections.Counter(l["moment"] for l in lines)
    import datetime
    bank = {"format": 1, "made": a.made or datetime.date.today().isoformat(), "source": a.source,
            "moments": {m: {"lines": per[m]} for m in MOMENTS if per[m]}, "lines": lines}
    with open(a.out, "w", encoding="utf-8", newline="\n") as f:
        json.dump(bank, f, indent=1, ensure_ascii=False)
        f.write("\n")
    print("%d judged, %d kept in %d moments; %d left out for breaking the format" % (judged, kept, len(per), len(bad)))
    print("per moment: " + ", ".join("%s %d" % (m, per[m]) for m in MOMENTS if per[m]))
    print("no line yet for: " + (", ".join(m for m in MOMENTS if not per[m]) or "none"))
    for b in bad[:40]:
        print("LEFT OUT:", b)
    return 0


if __name__ == "__main__":
    sys.exit(main())
