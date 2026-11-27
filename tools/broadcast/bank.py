"""From the streams' sentences to candidate lines for the commentary bank.

Reads every <media folder>/sentences.jsonl (made by sentences.py and voices.py), keeps the
main commentator's sentences, sets the speech-to-text's spelling right, turns riders' names,
makers' names, nationalities and places-in-the-race into slots, counts how often he says the
same line, and gives every line a race moment by the rules in MOMENT_RULES. The result is a
list of candidates for a reader to check (BANK_FORMAT.md says what the bank looks like);
nothing here decides what goes into the game.

    python -E -P tools/broadcast/bank.py <media root> --riders=<riders.json>
        [--aliases=<json>]       other ways the speech-to-text writes a rider's name (names.py)
        [--only=<id,id>]         only these media folders
        [--voice=0.84]           the least likeness to the main voice (voices.py's voice_main)
        [--out=<folder>]         default <media root>/../bank

Writes into the out folder:
    lines.jsonl        every kept sentence: where, the words as heard, the line with slots,
                       the moment, the level, the seconds
    templates.tsv      one row per distinct line: count, moment, level, seconds, an example's place
    proper_nouns.tsv   every word he says with a capital in the middle of a sentence, how it
                       was read (rider, maker, nation, place, unknown), and how often
    summary.txt        the counts
"""
import argparse
import collections
import json
import math
import os
import re

import names

# --- spelling: what Whisper writes -> what the sport writes ---------------------------------
SPELLING = [
    (r"\bjibe(s|d)?\b", r"gybe\1"), (r"\bjibing\b", "gybing"), (r"\bjive(s|d)?\b", r"gybe\1"),
    (r"\bJibe(s|d)?\b", r"Gybe\1"), (r"\bJibing\b", "Gybing"), (r"\bJive(s|d)?\b", r"Gybe\1"),
    (r"\bsale(s)?\b", r"sail\1"), (r"\bSale(s)?\b", r"Sail\1"),
    (r"\b(Peterway|PWA|P\.W\.A\.)\b", "VWA"),
    (r"\b(Salomex|Slalomex|Slalom X|Slalom-X|Salom X|Salomax)\b", "Slalom-X"),
    (r"\bwhiteboard\b", "white board"), (r"\bredboard\b", "red board"),
]

# --- words with a capital that are not riders -------------------------------------------------
MAKERS = ["Severne", "Severn", "Saverne", "Duotone", "Duetone", "North", "Patrik", "Patrick", "GA",
          "Gaastra", "S2 Maui", "S2Maui", "S2", "Point-7", "Point 7", "NeilPryde", "Neil Pryde",
          "Pryde", "Pride", "Starboard", "JP", "Fanatic", "Tabou", "Phantom", "FMX", "FutureFly",
          "Future Fly", "Challenger", "Loftsails", "Loft", "Simmer", "Goya", "iSonic", "Falcon",
          "Carbon Art", "Z Fins", "Zulu", "Tribal", "Chopper", "AV Boards", "Exocet", "RRD", "Naish"]
# Makers' names that are also ordinary words: a maker only after "a", "the", "that", a colour ...
MAKER_WORDS = ("North", "Pride", "Patrick", "Loft", "Falcon", "Zulu", "Tribal", "Chopper")
NATIONS = {  # the word he uses -> the slot
    "Italian": "national", "Frenchman": "national", "Frenchwoman": "national", "Dutchman": "national",
    "Dutchwoman": "national", "German": "national", "Pole": "national", "Brit": "national",
    "Englishman": "national", "Spaniard": "national", "Dane": "national", "Brazilian": "national",
    "Aruban": "national", "Belgian": "national", "Swiss": "national", "Turk": "national",
    "French": "nation_adj", "Polish": "nation_adj", "Dutch": "nation_adj", "British": "nation_adj",
    "Spanish": "nation_adj", "Danish": "nation_adj", "English": "nation_adj", "Bonairean": "nation_adj",
    "Guadeloupean": "nation_adj", "Israeli": "nation_adj", "Japanese": "nation_adj",
}
PLACES = ["Fuerteventura", "Sotavento", "Sylt", "Japan", "Yokosuka", "Costa Brava", "Canaries",
          "Canary", "Pozo", "Tenerife", "Gran Canaria", "Maui", "Europe", "France", "Italy", "Germany",
          "Holland", "Netherlands", "Poland", "Spain", "Aruba", "Bonaire", "Guadeloupe", "Brazil",
          "Denmark", "Rene Egli", "Defi Wind", "Defi", "Olympic", "Olympics", "World Cup", "World Tour",
          "VWA", "Slalom-X", "Grand Slam", "July", "August", "Monday", "Tuesday", "Wednesday",
          "Thursday", "Friday", "Saturday", "Sunday", "UK"]
ALWAYS_CAPITAL = {"I", "I'm", "I've", "I'll", "I'd", "OK", "TV", "GPS", "Mr", "Mrs", "God"}

WORD = re.compile(r"[A-Za-zÀ-ÿ0-9][A-Za-zÀ-ÿ0-9'’\-]*")
TOKEN = re.compile(r"\{[A-Za-z_0-9]+\}|[A-Za-zÀ-ÿ0-9][A-Za-zÀ-ÿ0-9'’\-]*|[^A-Za-zÀ-ÿ0-9{]+")
ORD = "first|second|third|fourth|fifth|sixth|seventh|eighth|ninth|tenth"
ORDINALS = ORD.split("|")
COLOURS = ["red", "blue", "white", "yellow", "green", "orange", "black", "pink", "purple", "grey", "gray"]
# "the first mark", "the second reach": not a place in the race.
NOT_A_PLACE = (r"mark|reach|leg|gybe|time|heat|elimination|round|day|race|one|start|final|half|part|event|"
               r"season|year|row|lap|run|attempt|try|thing|of all|and foremost|rider|man|woman|person|to\b")


def fix_spelling(text):
    for pat, rep in SPELLING:
        text = re.sub(pat, rep, text)
    return text


def places_to_slots(line):
    """'in second', 'second place', 'Second.' -> {place}; 'the first mark' stays."""
    line = re.sub(r"(?i)\b(%s)( place\b)" % ORD, lambda m: "{place}" + m.group(2), line)
    line = re.sub(r"(?i)(\b(?:in|into|to|for|from) )(%s)\b(?!\s+(?:%s))" % (ORD, NOT_A_PLACE),
                  lambda m: m.group(1) + "{place}", line)
    line = re.sub(r"(?i)^(%s)([.!?])$" % ORD, lambda m: "{place}" + m.group(2), line)
    return line


def capital_census(sentences):
    """For every word: how often it stands inside a sentence with and without a capital."""
    upper, lower = collections.Counter(), collections.Counter()
    for text in sentences:
        words = WORD.findall(text)
        for w in words[1:]:
            base = names.bare(w)
            if base[:1].isupper():
                upper[base] += 1
            else:
                lower[base.lower()] += 1
    return upper, lower


class Slotter:
    def __init__(self, riders, upper, lower):
        self.riders, self.upper, self.lower = riders, upper, lower
        self.makers = sorted(MAKERS, key=len, reverse=True)
        self.places = sorted(PLACES, key=len, reverse=True)
        self.place_words = set(w for p in PLACES for w in p.split())
        self.seen = collections.Counter()

    def ordinary(self, base):
        """An ordinary word is one he also says without a capital, more often than with one."""
        return self.lower[base.lower()] > self.upper[base] // 4

    def is_name_word(self, w):
        """A word with a capital that isn't an ordinary word, a maker, a nation or a place."""
        base = names.bare(w)
        if not base[:1].isupper() or base in ALWAYS_CAPITAL or base in NATIONS or base in self.place_words:
            return False
        if base.lower() in ORDINALS or base.lower() in COLOURS or len(base) < 2:
            return False
        return not self.ordinary(base)

    def rider_word(self, w, starts):
        """Is this capitalised word a rider's name? The first word of a sentence has its
        capital anyway, so there an ordinary word ("Then", "Look") is never a name."""
        kind = self.riders.match(w)
        if not kind:
            return ""
        base = names.bare(w)
        if base in self.riders.first or base in self.riders.last:
            return kind
        return "" if (self.ordinary(base) or (starts and self.lower[base.lower()] > 0)) else kind

    def slot(self, text):
        """The line with slots, and what stops it being reusable (flags)."""
        flags = []
        for m in self.makers:
            plain = r"(?<![A-Za-z])%ss?(?![A-Za-z])" % re.escape(m)
            if not re.search(plain, text):
                continue
            if m in MAKER_WORDS:
                pat = (r"(?i)\b((?:a|an|the|that|this|on|his|her|another|of the|red|blue|white|yellow|green|"
                       r"orange|black|two|three|four)\s+)%ss?\b" % m)
                if not re.search(pat, text):
                    continue
                text = re.sub(pat, lambda g: g.group(1) + "{brand}", text)
            else:
                text = re.sub(plain, "{brand}", text)
            self.seen[("maker", m)] += 1
        for p in self.places:
            if p not in ("VWA", "Slalom-X") and re.search(r"(?<![A-Za-z])%s(?![A-Za-z])" % re.escape(p), text):
                flags.append("place")
                self.seen[("place", p)] += 1
        for word, kind in NATIONS.items():
            if re.search(r"\b%ss?\b" % word, text):
                text = re.sub(r"\b%s\b" % word, "{%s}" % kind, text)
                self.seen[("nation", word)] += 1
        # Names: runs of name words. A run with a rider's name in it is a rider.
        tokens = TOKEN.findall(text)
        out, i, starts = [], 0, True
        while i < len(tokens):
            t = tokens[i]
            if t.startswith("{") or not WORD.fullmatch(t):
                out.append(t)
                if re.search(r"[.!?]", t):
                    starts = True
                i += 1
                continue
            capital = t[:1].isupper()
            kind = self.rider_word(t, starts) if capital else ""
            if not (capital and (kind or (not starts and self.is_name_word(t)))):
                out.append(t)
                starts = False
                i += 1
                continue
            run, j, any_rider = [t], i + 1, bool(kind)
            while j + 1 < len(tokens) and tokens[j].strip(" ") in ("", "-") and len(tokens[j]) <= 3 \
                    and WORD.fullmatch(tokens[j + 1]) and tokens[j + 1][:1].isupper() \
                    and (self.rider_word(tokens[j + 1], False) or self.is_name_word(tokens[j + 1])):
                any_rider = any_rider or bool(self.rider_word(tokens[j + 1], False))
                run.append(tokens[j + 1])
                j += 2
            possessive = names.APOS_S.search(run[-1])
            if any_rider:
                out.append("{rider}" + (possessive.group(0) if possessive else ""))
                self.seen[("rider", " ".join(run))] += 1
            else:
                out.append(" ".join(run))
                flags.append("name")
                self.seen[("unknown", " ".join(run))] += 1
            starts = False
            i = j
        text = "".join(out)
        # Two riders in one line: the second is {rider2}.
        if text.count("{rider}") == 2:
            first = text.index("{rider}") + len("{rider}")
            text = text[:first] + text[first:].replace("{rider}", "{rider2}")
        elif text.count("{rider}") > 2:
            flags.append("many_riders")
        text = places_to_slots(text)
        if re.search(r"\b(19|20)\d\d\b", text):
            flags.append("year")
        if re.search(r"\b\d+\s*(kilos?|kg|knots?|metres?|meters?|points?)\b", text):
            flags.append("number")
        if re.search(r"\b(I|I'm|I've|I'll|I'd|my|me|we|we're|we've|we'll|our|us)\b", text):
            flags.append("first_person")
        return text, flags


# --- the moments: the first rule that fits gives the moment ------------------------------------
# Each rule: (moment, a pattern on the line with slots, in lower case). Order matters: the
# sharper rules come first. A line no rule fits gets no moment and waits for a reader.
R = r"\{rider\}"
MOMENT_RULES = [
    ("over_early", r"over early|general recall|black flag|false start|premature|\brecall"),
    ("near_miss", r"nearly took out|took (him|her) out|almost (hit|took|collid)|collision|crash(ed|es)? into|contact|"
                  r"ran into|nearly hit|right in front of"),
    ("fall", r"in the drink|\bis down\b|goes down|went down|gone down|he's down|she's down|crash|wipe ?out|catapult|"
             r"in the water|swimming|falls? (in|off)|fallen|dropped (it|the gybe)|drops (it|the gybe)|'s gone\b|is gone\b"),
    ("photo_finish", r"photo finish|too close to call|who (will get|gets|got|takes) |by a nose|neck and neck to the"),
    ("finish_win", r"gets the bullet|takes the (win|bullet|victory)|wins (it|the|this)|will win|has won|is going to win|"
                   r"the winner|takes it\b|gets the win|crosses the line in first|another bullet|\bvictory"),
    ("finish_place", r"settle for|will get the|across the line|crosses the line|over the line in|finish(es)? in|"
                     r"comes? home in|(takes|gets) \{place\}|in \{place\} it will be|\{place\} place in the end"),
    ("lead_change", r"taking the lead|takes the lead|into the lead|new leader|hits the front|goes into first|"
                    r"has the lead now|now leading|moves into first|takes over at the front"),
    ("overtake", r"overtak|goes past|gone past|\bpasses\b|\bpassed\b|goes through|moves up|up into \{place\}|"
                 r"gets past|got past|comes through|coming through|sneaking ahead|gets ahead|rolls? (him|her)|rolled"),
    ("trouble", r"mistake|back off|backs off|slows down|slowed (him|her) down|slipped to|slips to|loses? (ground|places?|"
                r"speed)|lost (ground|places?|speed|it)|spin ?out|spun out|a little moment|a moment there|shocker|disaster|"
                r"nightmare|in trouble|struggling|stuck|buried"),
    ("gybe_good", r"what a gybe|great gybe|good gybe|perfect gybe|beautiful gybe|lovely gybe|nice gybe|nails the gybe|"
                  r"clean gybe|smooth (gybe|round)|amazing gybe|sick gybe|laydown"),
    ("gybe_bad", r"wayward gybe|wide gybe|goes wide|gone wide|too wide|bad gybe|slow gybe|messy|wobbl|"
                 r"off the plane|stalls? (in|out)"),
    ("gybe_safe", r"round(s|ed)? safely|safely round|gybes? (first|second|third|round|around)|round(s|ing)? the mark|"
                  r"around the mark in|makes it round|through the gybe|out of the gybe|gybe mark|\bgybes\b|\bgybing\b"),
    ("mark_approach", r"into the (first|second|third|last|final) (mark|gybe)|coming (in)?to the mark|approach|go in tight|"
                      r"inside line|on the inside|on the outside|going to gybe|sets? up for the|next mark|this mark|the mark"),
    ("start_gun", r"here we go|and they're off|they are off|we're racing|we are racing|green flag|and we're off|go go go|"
                  r"three,? two,? one|racing has started|we have a start|clean start|all clear"),
    ("start_good", r"good start|great start|flying start|perfect start|nailed the start|best start|won the start|"
                   r"on the gun|timed (it|that) (well|perfect)|hits the line|start of the day"),
    ("start_bad", r"bad start|late (at|on|to|off) the|slow off the line|missed the start|poor start|terrible start|"
                  r"second row"),
    ("pre_start", r"lined up|lining up|line up|pin end|boat end|start line|getting ready|seconds to go|one minute|"
                  r"30 seconds|thirty seconds|ten seconds|countdown|sequence|before the start|pre-?start|red flag|"
                  r"yellow flag|bottom end|top end|let's get ready"),
    ("airtime", r"airborne|gets? air|in the air|takes? off|launch|flying through the air|into orbit|little jump"),
    ("fight", r"head to head|battle|side by side|neck and neck|nothing in it|hold(ing)? (him|her|them)? ?off|"
              r"needs to hold off|fighting|scrap|duel|toe to toe|drag race|pushing " + R + r"|all the way"),
    ("chase", r"chasing|closing in|closing the gap|catching|reeling|hammer down|putting the pressure|pressure on|"
              r"making a bid|coming back|comeback|on the hunt|hunting|on the charge|charging|gaining|eating into|"
              r"here comes|back in it|fight his way back|fight her way back"),
    ("last_leg", r"last (reach|leg)|final (reach|leg)|run to the finish|to the finish|home straight|"
                 r"one (reach|leg) to go|penultimate"),
    ("leader", r"in the lead|leading|out in front|at the front|leader\b|leads\b|still in first|extending|pulling away|"
               r"on a heater|controlling|clear ahead|untouchable|running away|so much room"),
    ("rundown", r"" + R + r" in \{place\}|^\{place\}( place)?[.!]?$|in \{place\}( place)?[.!]?$|then (we've got|it's|"
                r"it looks like|comes)|then " + R + r"|'s in there|top (three|four|five)|behind (him|her)|further back|"
                r"followed by|^(and|then|and then) " + R + r"[.!]?$"),
    ("camera", r"drone|camera|\bcam\b|closer view|better angle|overall view|get a (look|view)|can't see|on (the|your) "
               r"screen|zoom|helicopter|shot of"),
    ("unsure", r"is that " + R + r"|who's (on )?that|who is that|hard to (tell|pick|see)|can't quite|not sure (who|if)|"
               r"could (well )?be " + R + r"|looks like " + R + r"|sail numbers?|^or " + R),
    ("oh_no", r"^oh no|^oh dear|^no[.!,]|oh no[.!]?$|that's a shame|heartbreak"),
    ("wow", r"^wow|oh my life|oh my word|oh my god|my goodness|look at (this|that)|what the hell|would you believe|"
            r"^oof|^ooh|^whoa|are you kidding"),
    ("speed", r"flying|speed|\bfast|quick|rapid|rocket|chop|control|lit up|powered|full power|on fire|ripping|sending|"
              r"hauling|wound up|eating up|means business|looking (very |really |so )?(good|comfortable|strong)|"
              r"in the money|right in the game"),
    ("identify", r"you've got " + R + r"|there's " + R + r"|that's " + R + r"|this is " + R + r"|that is " + R + r"|"
                 r"here's " + R + r"|we've got " + R + r"|it's " + R + r"|it is " + R + r"|^(but |so |and it's )?" + R + r"[.!]?$|"
                 + R + r" is there|there (he|she) is|" + R + r" (in|on|down|up) (the|this|that) |there's a \{brand\}|"
                 r"the \{brand\}|on (that|the) \{brand\}|^the \{national\}[.!]?$|^it's the \{national\}"),
    ("after_race", r"what a race|what a heat|what a final|hardcore racing|ridiculous|incredible|unbelievable|"
                   r"amazing race|great racing|solid result|well deserved|what a performance|impressive stuff"),
]
_RULES = [(m, re.compile(p)) for m, p in MOMENT_RULES]


def moment_of(line):
    low = line.lower()
    for moment, pat in _RULES:
        if pat.search(low):
            return moment
    return ""


def level_of(pitch_rel, loud_db):
    score = pitch_rel + max(loud_db, 0.0)
    return 1 if score < -2.0 else (2 if score < 1.5 else (3 if score < 4.0 else 4))


def template_key(line):
    """The same words said twice count as one line: case, spaces and end marks don't matter."""
    return re.sub(r"[^a-z0-9{}_' ]", "", line.lower().replace("’", "'")).strip()


def load(root, only):
    rows = []
    for vid in sorted(os.listdir(root)):
        path = os.path.join(root, vid, "sentences.jsonl")
        if (only and vid not in only) or not os.path.exists(path):
            continue
        with open(path, encoding="utf-8") as f:
            for l in f:
                r = json.loads(l)
                r["video"] = vid
                rows.append(r)
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("root")
    ap.add_argument("--riders", required=True)
    ap.add_argument("--aliases", default="")
    ap.add_argument("--only", default="")
    ap.add_argument("--voice", type=float, default=0.84)
    ap.add_argument("--out", default="")
    a = ap.parse_args()
    out = a.out or os.path.join(os.path.dirname(a.root.rstrip("/\\")), "bank")
    os.makedirs(out, exist_ok=True)

    rows = load(a.root, set(x for x in a.only.split(",") if x))
    main_rows = [r for r in rows if r.get("voice_main", 1.0) >= a.voice]
    # The usual pitch per video is the main voice's own (the interviews pull it up otherwise).
    pitches = collections.defaultdict(list)
    for r in main_rows:
        if r["pitch_hz"] > 0:
            pitches[r["video"]].append(r["pitch_hz"])
    usual = {v: sorted(p)[len(p) // 2] for v, p in pitches.items()}

    for r in main_rows:
        r["fixed"] = fix_spelling(r["text"])
    upper, lower = capital_census([r["fixed"] for r in main_rows])
    slotter = Slotter(names.Riders(a.riders, a.aliases), upper, lower)

    groups = collections.defaultdict(list)
    for r in main_rows:
        r["line"], r["flags"] = slotter.slot(r["fixed"])
        r["slots"] = re.findall(r"\{([a-z_0-9]+)\}", r["line"])
        r["moment"] = moment_of(r["line"])
        rel = 12.0 * math.log2(r["pitch_hz"] / usual[r["video"]]) if r["pitch_hz"] > 0 and r["video"] in usual else 0.0
        r["pitch_main"] = round(rel, 1)
        r["level"] = level_of(rel, r["loud_db"])
        r["key"] = template_key(r["line"])
        groups[r["key"]].append(r)

    keep = ("video", "id", "start", "end", "seconds", "text", "line", "slots", "flags", "moment", "level",
            "pitch_main", "loud_db", "pace", "sure", "voice_main", "key")
    with open(os.path.join(out, "lines.jsonl"), "w", encoding="utf-8") as f:
        for r in main_rows:
            f.write(json.dumps({k: r[k] for k in keep}, ensure_ascii=False) + "\n")
    with open(os.path.join(out, "templates.tsv"), "w", encoding="utf-8") as f:
        f.write("count\tmoment\tlevel\tseconds\tsure\tflags\tline\texample\n")
        for key, g in sorted(groups.items(), key=lambda kv: -len(kv[1])):
            best = max(g, key=lambda r: r["sure"])
            f.write("%d\t%s\t%d\t%.1f\t%.2f\t%s\t%s\t%s@%.1f\n"
                    % (len(g), best["moment"], sorted(r["level"] for r in g)[len(g) // 2],
                       sorted(r["seconds"] for r in g)[len(g) // 2], best["sure"],
                       ",".join(sorted(set(best["flags"]))), best["line"], best["video"], best["start"]))
    with open(os.path.join(out, "proper_nouns.tsv"), "w", encoding="utf-8") as f:
        f.write("count\tread_as\tword\n")
        for (kind, word), n in slotter.seen.most_common():
            f.write("%d\t%s\t%s\n" % (n, kind, word))
    tagged = collections.Counter(r["moment"] or "(none)" for r in main_rows)
    summary = ("sentences: %d, by the main voice (likeness >= %.2f): %d\n"
               "distinct lines: %d, said twice or more: %d\n"
               "without a flag (no place, year, number, unknown name, first person): %d\n"
               "with a moment: %d (%.0f %%)\nby moment: %s\n"
               % (len(rows), a.voice, len(main_rows), len(groups), sum(1 for g in groups.values() if len(g) > 1),
                  sum(1 for r in main_rows if not r["flags"]),
                  sum(1 for r in main_rows if r["moment"]),
                  100.0 * sum(1 for r in main_rows if r["moment"]) / max(len(main_rows), 1),
                  ", ".join("%s %d" % kv for kv in tagged.most_common())))
    with open(os.path.join(out, "summary.txt"), "w", encoding="utf-8") as f:
        f.write(summary)
    print(summary)


if __name__ == "__main__":
    main()
