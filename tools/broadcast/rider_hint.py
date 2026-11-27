"""Make Whisper's hint for one event: the sport's words and the riders' names.

Whisper reads at most 223 word pieces of the hint. The riders come in the entry list's
order: as many as fit get their full name, the rest only the surname.

    python -E -P tools/broadcast/rider_hint.py <riders.json> <out.txt> [--model=large-v3-turbo]
"""
import argparse
import json

from faster_whisper import WhisperModel
from faster_whisper.tokenizer import Tokenizer

import transcribe


def split_name(listed):
    nick = None
    if "(" in listed:
        nick = listed[listed.index("(") + 1:listed.index(")")]
        listed = listed[:listed.index("(")].strip()
    parts = listed.split()
    last = " ".join(parts[:-1])
    return (nick or parts[-1]), (last.title() if last.isupper() else last)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("riders")
    ap.add_argument("out")
    ap.add_argument("--model", default="large-v3-turbo")
    a = ap.parse_args()
    with open(a.riders, encoding="utf-8") as f:
        d = json.load(f)
    names = [split_name(r["listed"]) for r in d.get("men", []) + d.get("women", [])]
    model = WhisperModel(a.model, device="cpu", compute_type="int8", cpu_threads=2)
    tok = Tokenizer(model.hf_tokenizer, True, task="transcribe", language="en")
    limit = model.max_length // 2 - 1

    def text(full):
        seen, words = set(), []
        for i, (first, last) in enumerate(names):
            w = "%s %s." % (first, last) if i < full else last + "."
            if w not in seen:
                seen.add(w)
                words.append(w)
        return transcribe.SPORT_WORDS + " ".join(words)

    full = len(names)
    while full > 0 and len(tok.encode(" " + text(full))) > limit:
        full -= 1
    hint = text(full)
    with open(a.out, "w", encoding="utf-8") as f:
        f.write(hint + chr(10))
    print("%d riders, %d with the full name, %d of %d word pieces"
          % (len(names), full, len(tok.encode(" " + hint)), limit))


if __name__ == "__main__":
    main()
