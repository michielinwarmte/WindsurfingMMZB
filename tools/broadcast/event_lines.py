"""The commentator's own lines for the event week's moments, into the game's event bank.

The event's moments (the heat called, who goes through, who is out, the standings) are not in the
candidate sheets' rules, so his sentences for them are picked by hand from the streams' sentences
(a picks file) and looked up here for what was measured: how long he took, how excited he was, where
he said it, and whether it was his voice.

    python -E -P tools/broadcast/event_lines.py <picks file> <media folder> <event bank json>
        [--voice=0.84]

The picks file: one line per pick,
    his sentence, as written out | moment | needs (comma separated) | the bank's line
(a name or a number in his sentence made a slot in the line). Lines starting with # are skipped.

The event bank (Game/race/commentary/commentary_bank_event.json) keeps its lines written for the
game (ids E....) and gets his lines with ids H + a hash of the line, so a line keeps its id when the
picks grow. A pick whose sentence is not found, or was not said by the main voice, is listed and
left out.
"""
import argparse
import glob
import hashlib
import json
import os
import re

MOMENTS = ["heat_called", "heat_favourite", "heat_through", "heat_out", "final_win", "standings", "event_win"]
NEEDS = ["final", "not_final", "event_leader", "opening", "pair"]
SLOTS = ["rider", "rider2", "place", "national", "nation_adj", "heat", "round", "elimination", "event"]


def level_of(pitch_rel, loud_db):
    """As tools/broadcast/bank.py has it: 1 calm, 2 the normal race voice, 3 lifted, 4 shouting."""
    score = pitch_rel + max(loud_db, 0.0)
    return 1 if score < -2.0 else (2 if score < 1.5 else (3 if score < 4.0 else 4))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("picks")
    ap.add_argument("media")
    ap.add_argument("bank")
    ap.add_argument("--voice", type=float, default=0.84)
    a = ap.parse_args()

    said = {}
    for path in sorted(glob.glob(os.path.join(a.media, "*", "sentences.jsonl"))):
        vid = os.path.basename(os.path.dirname(path))
        with open(path, encoding="utf-8") as f:
            for raw in f:
                row = json.loads(raw)
                said.setdefault(row.get("text", "").strip(), []).append((vid, row))

    with open(a.bank, encoding="utf-8") as f:
        bank = json.load(f)
    lines = [l for l in bank["lines"] if not l["id"].startswith("H")]
    seen = {(l["moment"], l["text"].lower()) for l in lines}
    added, left_out = 0, []
    with open(a.picks, encoding="utf-8") as f:
        for raw in f:
            raw = raw.strip()
            if not raw or raw.startswith("#"):
                continue
            parts = [p.strip() for p in raw.split("|")]
            if len(parts) != 4:
                left_out.append("%s: not four fields" % raw[:60])
                continue
            sentence, moment, needs_text, text = parts
            needs = [n.strip() for n in needs_text.split(",") if n.strip()]
            slots = []
            for slot in re.findall(r"\{([a-z_0-9]+)\}", text):
                if slot not in slots:
                    slots.append(slot)
            why = []
            if moment not in MOMENTS:
                why.append("moment %r" % moment)
            why += ["needs %r" % n for n in needs if n not in NEEDS]
            why += ["slot %r" % s for s in slots if s not in SLOTS]
            found = said.get(sentence, [])
            if not found:
                why.append("his sentence is not in the streams' text")
            if why:
                left_out.append("%s: %s" % (sentence, ", ".join(why)))
                continue
            # Of the times he said it: the one most surely his voice.
            vid, row = max(found, key=lambda pair: pair[1].get("voice_main", -1.0))
            voice = row.get("voice_main")
            if voice is not None and voice < a.voice:
                left_out.append("%s: not the main voice (likeness %.2f)" % (sentence, voice))
                continue
            if (moment, text.lower()) in seen:
                continue
            seen.add((moment, text.lower()))
            lines.append({
                "id": "H" + hashlib.sha1((moment + "|" + text).encode("utf-8")).hexdigest()[:7].upper(),
                "moment": moment, "text": text, "slots": slots,
                "level": level_of(float(row.get("pitch_rel", 0.0)), float(row.get("loud_db", 0.0))),
                "seconds": round(max(float(row.get("seconds", 0.0)), 0.8), 1), "count": len(found), "needs": needs,
                "src": "%s@%.1f" % (vid, float(row.get("start", 0.0))),
                "voice": "not checked" if voice is None else round(float(voice), 2)})
            added += 1
    bank["lines"] = lines
    bank["source"] = ("written for the game's event week (ids E...), and the commentator's own sentences for the "
                      "event's moments picked from the 2026 streams (ids H...)")
    with open(a.bank, "w", encoding="utf-8", newline="\n") as f:
        json.dump(bank, f, indent=1, ensure_ascii=False)
        f.write("\n")
    print("%d of his lines in, %d lines in the event bank" % (added, len(lines)))
    unchecked = sum(1 for l in lines if l.get("voice") == "not checked")
    if unchecked:
        print("%d of them without a voice check yet (voices.py has not run on their stream)" % unchecked)
    for row in left_out:
        print("left out: " + row)


if __name__ == "__main__":
    main()
