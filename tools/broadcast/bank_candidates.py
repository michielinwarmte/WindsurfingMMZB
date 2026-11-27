"""Pick the lines a reader should judge for the commentary bank, and cut them into sheets.

bank.py leaves every sentence of the main commentator with its line (names as slots), its
count and a moment by rule. That is tens of thousands of lines; a reader can't judge them
all. This picks the ones worth a look:

    A  every clean line he said at least twice (whatever the rules made of it)
    B  clean lines said once that a rule gave a moment, the surest ones first, so many per moment
    C  two sentences he says in one breath, again and again ("Here we go. Look at that.")

"Clean" = no place name, year, number, unknown name or first person in it, at most 22 words
and 9 seconds, and the speech-to-text sure of its words.

    python -E -P tools/broadcast/bank_candidates.py <bank folder> [--per-moment=110] [--sheet=350]

Reads <bank folder>/lines.jsonl; writes there:
    candidates.json          everything known about each candidate (count, level, seconds, where said)
    sheets/sheet_01.tsv ...  for the reader: id, count, the rule's moment, level, seconds, the line,
                             and what he said just before and after it (for the sense of it)
"""
import argparse
import collections
import hashlib
import json
import os

MIN_SURE = 0.80
MIN_SURE_ONCE = 0.88


def line_id(key):
    """The bank's id for a line: from its words, so the same line keeps its id for ever."""
    return "L" + hashlib.sha1(key.encode("utf-8")).hexdigest()[:7].upper()


def clean(r):
    return not r["flags"] and r["sure"] >= MIN_SURE and 1 <= len(r["line"].split()) <= 22 and r["seconds"] <= 9.0


def middle(vals):
    v = sorted(vals)
    return v[len(v) // 2]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("bank")
    ap.add_argument("--per-moment", type=int, default=110)
    ap.add_argument("--sheet", type=int, default=350)
    a = ap.parse_args()
    with open(os.path.join(a.bank, "lines.jsonl"), encoding="utf-8") as f:
        rows = [json.loads(l) for l in f]
    rows.sort(key=lambda r: (r["video"], r["start"]))
    for i, r in enumerate(rows):
        r["i"] = i

    def around(r):
        i = r["i"]
        before = rows[i - 1]["text"] if i > 0 and rows[i - 1]["video"] == r["video"] and r["start"] - rows[i - 1]["end"] < 6 else ""
        after = rows[i + 1]["text"] if i + 1 < len(rows) and rows[i + 1]["video"] == r["video"] and rows[i + 1]["start"] - r["end"] < 6 else ""
        return before[-90:], after[:90]

    groups = collections.defaultdict(list)
    for r in rows:
        if clean(r) and r["key"]:
            groups[r["key"]].append(r)

    cands = {}

    def add(key, g, kind, text=None, seconds=None):
        best = max(g, key=lambda r: r["sure"])
        before, after = around(best)
        moments = collections.Counter(r["moment"] for r in g if r["moment"])
        cands[line_id(key)] = {
            "id": line_id(key), "kind": kind, "key": key, "line": text or best["line"],
            "count": len(g), "moment": moments.most_common(1)[0][0] if moments else "",
            "level": middle([r["level"] for r in g]),
            "seconds": round(seconds if seconds is not None else middle([r["seconds"] for r in g]), 1),
            "sure": best["sure"], "src": "%s@%.1f" % (best["video"], best["start"]),
            "said": ["%s@%.1f" % (r["video"], r["start"]) for r in sorted(g, key=lambda r: -r["sure"])[:8]],
            "before": before, "after": after}

    # A: said at least twice.
    for key, g in groups.items():
        if len(g) >= 2:
            add(key, g, "A")
    # B: said once, with a moment, the surest first, so many per moment.
    once = collections.defaultdict(list)
    for key, g in groups.items():
        if len(g) == 1 and g[0]["moment"] and g[0]["sure"] >= MIN_SURE_ONCE and 2 <= len(g[0]["line"].split()) <= 16:
            once[g[0]["moment"]].append((key, g))
    for moment, items in once.items():
        items.sort(key=lambda kg: -kg[1][0]["sure"])
        for key, g in items[:a.per_moment]:
            add(key, g, "B")
    # C: two sentences in one breath, the same pair at least three times.
    pairs = collections.defaultdict(list)
    for x, y in zip(rows, rows[1:]):
        if x["video"] == y["video"] and 0 <= y["start"] - x["end"] < 0.6 and clean(x) and clean(y) \
                and len(x["line"].split()) + len(y["line"].split()) <= 16:
            if x["key"] == "{rider}" and y["key"] == "{rider}":
                continue
            pairs[x["key"] + " | " + y["key"]].append((x, y))
    for key, g in pairs.items():
        if len(g) >= 3:
            x, y = max(g, key=lambda p: p[0]["sure"] + p[1]["sure"])
            text = x["line"] + " " + y["line"].replace("{rider}", "{rider2}") if "{rider}" in x["line"] and "{rider}" in y["line"] \
                else x["line"] + " " + y["line"]
            joined = [dict(x, moment=x["moment"] or y["moment"], level=max(x["level"], y["level"]),
                           sure=min(x["sure"], y["sure"])) for x, y in g]
            add(key, joined, "C", text=text, seconds=middle([q["end"] - p["start"] for p, q in g]))

    with open(os.path.join(a.bank, "candidates.json"), "w", encoding="utf-8") as f:
        json.dump(cands, f, indent=0, ensure_ascii=False)
    sheets = os.path.join(a.bank, "sheets")
    os.makedirs(sheets, exist_ok=True)
    # Sheets by moment, so the reader sees a moment's lines together; the moment-less last.
    order = sorted(cands.values(), key=lambda c: (c["moment"] == "", c["moment"], -c["count"], c["line"]))
    for n in range(0, len(order), a.sheet):
        with open(os.path.join(sheets, "sheet_%02d.tsv" % (n // a.sheet + 1)), "w", encoding="utf-8") as f:
            f.write("id\tcount\trule_moment\tlevel\tseconds\tline\tbefore\tafter\n")
            for c in order[n:n + a.sheet]:
                f.write("%s\t%d\t%s\t%d\t%.1f\t%s\t%s\t%s\n" % (c["id"], c["count"], c["moment"], c["level"], c["seconds"],
                                                              c["line"], c["before"], c["after"]))
    kinds = collections.Counter(c["kind"] for c in cands.values())
    per = collections.Counter(c["moment"] or "(none)" for c in cands.values())
    print("%d candidates (said twice or more %d, said once with a moment %d, pairs %d) on %d sheets"
          % (len(cands), kinds["A"], kinds["B"], kinds["C"], (len(order) + a.sheet - 1) // a.sheet))
    print("per moment: " + ", ".join("%s %d" % kv for kv in per.most_common()))


if __name__ == "__main__":
    main()
