"""The event's format, schedule and wind as the commentator tells them (step W0 of EVENT_WEEK_PLAN.md).

Reads the transcript pieces of the stream days (finished or not) and prints the sentences that
speak of the format (who goes through, the rounds, the discards, the fleet's size), the schedule
(which elimination, which day) and the wind (knots, sail sizes), grouped by topic and in order of
time, each with its video and time. A reading aid: the numbers are then read by a person.

  python -E tools/broadcast/format_facts.py <media folder> <video id> [<video id> ...] [--topic=wind]
"""
import glob
import json
import os
import re
import sys

TOPICS = {
    "through": r"top four|first four|four (will |to |can |riders |guys |sailors )?(go|advance|qualif|progress)"
               r"|qualif\w* for|go(es|ing)? through|advance[sd]? to|knocked out|eliminated|doesn.t make it|not through",
    "rounds": r"round one|round two|first round|second round|third round|quarter.?final|semi.?final|loser.?s? final"
              r"|winner.?s? final|b final|a final|small final|big final",
    "discard": r"discard",
    "fleet": r"sixty.?four|\b64\b|forty|\b4[0-9] (men|riders|sailors|guys)|how many (riders|sailors|men)|fleet of"
             r"|heats? of (eight|ten|8|10)|(eight|ten|8|10) (riders|sailors|men|guys|man)|registered|entr(y|ies)",
    "elimination": r"elimination (number )?(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|\d+)"
                   r"|(first|second|third|fourth|fifth|sixth|seventh|eighth|ninth|tenth|eleventh) elimination"
                   r"|eliminations? (today|so far|done|completed|in the bag)|day (one|two|three|four|five|1|2|3|4|5)\b",
    "wind": r"\bknots?\b|sail sizes?|\b[4-9]\.[0-9]\b|\b[4-9] point [0-9]\b|metres? squared|square met|gusting|gusts? (of|to|up)"
            r"|wind (is|has|was) (up|down|dropp|pick|increas|fill)|light(er)? wind|strong(er)? wind|nuclear|howling|overpowered",
    "points": r"\bpoints?\b.*(lead|ahead|behind|gap)|event lead|overall lead|leads the event|tied on|0\.7|zero point seven",
}


def clock(seconds):
    seconds = int(seconds)
    return "%d:%02d:%02d" % (seconds // 3600, seconds // 60 % 60, seconds % 60)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    only = [a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--topic=")]
    media, ids = args[0], args[1:]
    found = {topic: [] for topic in TOPICS}
    for vid in ids:
        for path in sorted(glob.glob(os.path.join(media, vid, "transcript", "piece_*.json"))):
            try:
                piece = json.load(open(path, encoding="utf-8"))
            except (OSError, ValueError):
                continue
            for seg in piece.get("segments", []):
                text = (seg.get("text") or "").strip()
                for topic, pattern in TOPICS.items():
                    if re.search(pattern, text, re.I):
                        found[topic].append((vid, float(seg.get("start", 0.0)), text))
    for topic in TOPICS:
        if only and topic not in only:
            continue
        rows = sorted(found[topic])
        print("== %s (%d)" % (topic, len(rows)))
        for vid, start, text in rows:
            print("%s %s | %s" % (vid[:5], clock(start), text))
        print()


if __name__ == "__main__":
    main()
