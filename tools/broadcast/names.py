"""Riders' names in the commentary: finding them, however the speech-to-text wrote them.

Used by bank.py. A word counts as a rider's name when its sound spelling is a rider's from
the entry list, or close to it (one letter off in a word under eight letters, two in a
longer one; or the start of a longer name). Ways of writing a name that are too far off for
that ("Machet" for Maciek) come from an aliases file: a JSON of
{"as written": "the name as the entry list has it"}, made by reading the list of unknown
capital words of an earlier run (proper_nouns.tsv).
"""
import json
import os
import re

APOS_S = re.compile("['’]s$")
PARTICLES = ("van", "der", "de", "di", "den", "la", "le")
ACCENTS = (("à", "a"), ("á", "a"), ("â", "a"), ("ä", "a"), ("è", "e"), ("é", "e"),
           ("ê", "e"), ("ë", "e"), ("ï", "i"), ("î", "i"), ("í", "i"), ("ö", "o"),
           ("ô", "o"), ("ø", "o"), ("ó", "o"), ("ü", "u"), ("û", "u"), ("ú", "u"),
           ("ç", "s"), ("ñ", "n"))
SOUNDS = (("tsch", "x"), ("tch", "x"), ("sch", "x"), ("sh", "x"), ("cz", "x"), ("ch", "k"), ("ck", "k"),
          ("cqu", "k"), ("qu", "k"), ("q", "k"), ("c", "k"), ("ph", "f"), ("z", "s"), ("w", "v"), ("j", "i"),
          ("y", "i"), ("th", "t"), ("e", "i"), ("u", "o"), ("h", ""))


# Ordinary words whose sound spelling falls near a rider's name: never a name.
NEVER = set("""then they them there their these those this that than when where what which while who whose
why how here have has had been being were was will would could should might must shall can may does did
done doing going gone goes come comes came coming look looks looked looking like liked just only even still
also very really quite some many much more most less least few other another each every both either neither
first second third fourth fifth last next best better good great well right left back front down over under
into onto from with without about after before behind between through during again against around across
along away off out now not yes yeah nope okay and but for nor yet because though although unless until since
him her his hers she you your yours our ours its it's one two three four five six seven eight nine ten
man men boy boys guy guys girl girls rider riders sailor sailors board boards sail sails fin fins mark marks
race races racing heat heats final finals start starts line lines wind winds wave waves water chop speed
time times day days week year years event events place places point points lead leader leaders
france italy poland spain germany holland japan brazil aruba bonaire denmark europe""".split())


def bare(word):
    """The word without a possessive 's."""
    return APOS_S.sub("", word)


def sound(word):
    """A rough sound spelling, so 'Rakowski' lands near 'Rutkowski' and 'Franz' on 'Frans'."""
    w = bare(word.lower())
    for a, b in ACCENTS:
        w = w.replace(a, b)
    w = re.sub(r"[^a-z]", "", w)
    for a, b in SOUNDS:
        w = w.replace(a, b)
    return re.sub(r"(.)\1+", r"\1", w)


def edit(a, b):
    if a == b:
        return 0
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (ca != cb)))
        prev = cur
    return prev[-1]


class Riders:
    """The entry list: tells whether a word is (a way of writing) a rider's name."""

    def __init__(self, path, aliases_path=""):
        self.first, self.last = set(), set()
        with open(path, encoding="utf-8") as f:
            d = json.load(f)
        for r in d.get("men", []) + d.get("women", []):
            listed = r["listed"]
            if "(" in listed:
                self.first.add(listed[listed.index("(") + 1:listed.index(")")])
                listed = listed[:listed.index("(")].strip()
            parts = listed.split()
            self.first.add(parts[-1])
            for p in parts[:-1]:
                if p.lower() not in PARTICLES:
                    self.last.add(p.title() if p.isupper() else p)
        self.aliases, self.patterns = {}, []
        if aliases_path and os.path.exists(aliases_path):
            with open(aliases_path, encoding="utf-8") as f:
                for k, v in json.load(f).items():
                    if k.startswith("~"):
                        # "~kowski$": any word that fits this pattern (lower case) is that rider.
                        self.patterns.append((re.compile(k[1:]), v))
                    else:
                        self.aliases[k.lower()] = v
        self.first_keys = {sound(n): n for n in self.first}
        self.last_keys = {sound(n): n for n in self.last}
        self._memo = {}

    def match(self, word):
        """'first', 'last' or '' for a capitalised word."""
        base = bare(word)
        if base not in self._memo:
            self._memo[base] = self._match(base)
        return self._memo[base]

    def _match(self, base):
        if base in self.first:
            return "first"
        if base in self.last:
            return "last"
        if base.lower() in NEVER or "'" in base or "’" in base:
            return ""
        if base.lower() in self.aliases:
            return "last" if self.aliases[base.lower()] in self.last else "first"
        for pat, rider in self.patterns:
            if pat.search(base.lower()):
                return "last" if rider in self.last else "first"
        key = sound(base)
        if len(key) < 3:
            return ""
        for keys, kind in ((self.last_keys, "last"), (self.first_keys, "first")):
            for k in keys:
                if key == k:
                    return kind
                if len(key) >= 4 and len(k) >= 4:
                    longest = max(len(key), len(k))
                    d = edit(key, k)
                    if d <= (1 if longest < 8 else 2) and d / longest <= 0.25:
                        return kind
                    if (k.startswith(key) or key.startswith(k)) and abs(len(k) - len(key)) <= 2:
                        return kind
        return ""
