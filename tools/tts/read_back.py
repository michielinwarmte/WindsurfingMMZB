"""Read the commentary voice's sound files back into words with Whisper, to check without ears that
the computer voice says the lines right (Documentation/reports/broadcast/commentary_voice.md).

Reads <folder>/manifest.json (written by tools/tts/speak_lines.sh: every line's words and its WAV
file), turns each WAV back into text with faster-whisper on this PC's processor (nothing is sent
anywhere), and compares the words: the same words (case, punctuation and accents ignored) or not.
For a name on its own or in a sentence it also checks whether the name came back.

    python -E -P tools/tts/read_back.py <folder> [--model=small.en] [--threads=4] [--hints=0|1]
        [--only=bank|name|name_sentence] [--tag=<added to the result's file name>]

--hints=1 gives Whisper the game's names and brands first (as a viewer who reads the names on the
screen knows them); the default 0 is the strict check. Writes <folder>/read_back.json (every line
with what came back) and <folder>/read_back.md (the score and the lines that differ), and prints the
summary. The model is downloaded once from Hugging Face into the user's cache.
"""
import argparse
import difflib
import json
import os
import re
import sys
import time
import unicodedata
import wave

# Close: the letters at least this alike (a name spelled another way, one small word off).
CLOSE = 0.85
NUMBER_WORDS = {"1": "one", "2": "two", "3": "three", "4": "four", "5": "five", "6": "six",
                "7": "seven", "8": "eight", "9": "nine", "10": "ten", "1st": "first", "2nd": "second",
                "3rd": "third", "4th": "fourth", "5th": "fifth", "6th": "sixth"}


# Words that sound the same but are written another way: Whisper writes the common spelling.
SAME_SOUND = {"jibe": "gybe", "jive": "gybe", "jibes": "gybes", "sales": "sails", "fellow": "fella",
              "hes": "he is", "theyre": "they are", "its": "it is", "whos": "who is", "thats": "that is"}


def words_of(text):
    """The words to compare: lower case, no accents, no punctuation, numbers as words, contractions
    and words that sound the same written one way ("he's" and "he is", "jibe" and "gybe")."""
    text = unicodedata.normalize("NFKD", text)
    text = "".join(c for c in text if not unicodedata.combining(c))
    text = text.lower().replace("'", "").replace("’", "")
    text = re.sub(r"[^a-z0-9]+", " ", text)
    words = []
    for w in text.split():
        words.extend(SAME_SOUND.get(NUMBER_WORDS.get(w, w), NUMBER_WORDS.get(w, w)).split())
    return words


def similarity(said_words, heard_words):
    """How alike the two are as letters (0 to 1), the spaces left out: "Reuben Brower" for "Ruben
    Brouwer" is close (said right, spelled another way), "Call now" for "Hana" is not."""
    return difflib.SequenceMatcher(None, "".join(said_words), "".join(heard_words)).ratio()


def read_wav_16k(path):
    """A WAV file (16-bit, Piper's own) as Whisper's input: mono floats at 16 kHz. Read here, not
    through faster-whisper's own decoder (its PyAV call fails with this PC's PyAV version)."""
    import numpy as np
    with wave.open(path, "rb") as wav:
        rate = wav.getframerate()
        channels = wav.getnchannels()
        samples = np.frombuffer(wav.readframes(wav.getnframes()), dtype=np.int16).astype(np.float32) / 32768.0
    if channels > 1:
        samples = samples.reshape(-1, channels).mean(axis=1)
    if rate != 16000 and samples.size > 1:
        times = np.arange(int(samples.size * 16000 / rate)) * (rate / 16000.0)
        samples = np.interp(times, np.arange(samples.size), samples).astype(np.float32)
    return samples


def name_closeness(name_words, heard_words):
    """How alike the name is to the words heard where it fits best (0 to 1, as letters): the name
    alone, not the rest of the sentence."""
    target = "".join(name_words)
    best = 0.0
    for size in range(max(len(name_words) - 1, 1), len(name_words) + 3):
        for start in range(0, max(len(heard_words) - size + 1, 0)):
            best = max(best, difflib.SequenceMatcher(None, target, "".join(heard_words[start:start + size])).ratio())
    return best


def word_errors(said, heard):
    """How many words differ (the edit distance over words)."""
    rows = list(range(len(heard) + 1))
    for i, a in enumerate(said, 1):
        new = [i]
        for j, b in enumerate(heard, 1):
            new.append(min(rows[j] + 1, new[j - 1] + 1, rows[j - 1] + (a != b)))
        rows = new
    return rows[-1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("folder")
    parser.add_argument("--model", default="small.en")
    parser.add_argument("--threads", type=int, default=4)
    parser.add_argument("--hints", type=int, default=0)
    parser.add_argument("--only", default="", help="one kind of line: bank, name or name_sentence")
    parser.add_argument("--tag", default="", help="added to the output files' names")
    parser.add_argument("--rescore", default="", help="a read_back*.json: score what it heard again, no Whisper")
    args = parser.parse_args()

    with open(args.rescore or os.path.join(args.folder, "manifest.json"), encoding="utf-8") as f:
        items = json.load(f)
    if args.only:
        items = [i for i in items if i["kind"] == args.only]
    model = None
    if not args.rescore:
        from faster_whisper import WhisperModel
        model = WhisperModel(args.model, device="cpu", compute_type="int8", cpu_threads=args.threads)
    hint = None
    if args.hints:
        names = sorted({i["name"] for i in items if i.get("name")})
        hint = "Windsurf slalom racing. " + ". ".join(names) + "."

    started = time.time()
    for n, item in enumerate(items):
        if not item.get("made"):
            item["heard"] = None
            continue
        if model is None:
            heard = item.get("heard") or ""
        else:
            segments, _ = model.transcribe(read_wav_16k(item["wav"]), language="en", beam_size=5,
                                           initial_prompt=hint, condition_on_previous_text=False,
                                           vad_filter=False)
            heard = " ".join(s.text.strip() for s in segments).strip()
        said_words = words_of(item["text"])
        heard_words = words_of(heard)
        item["heard"] = heard
        item["same"] = said_words == heard_words
        item["word_errors"] = word_errors(said_words, heard_words)
        item["similarity"] = round(similarity(said_words, heard_words), 3)
        item["close"] = item["same"] or item["similarity"] >= CLOSE
        item["words"] = len(said_words)
        if item.get("name"):
            name_words = words_of(item["name"])
            joined = " " + " ".join(heard_words) + " "
            item["name_heard"] = (" " + " ".join(name_words) + " ") in joined
            item["name_similarity"] = round(name_closeness(name_words, heard_words), 3)
            item["name_close"] = item["name_heard"] or item["name_similarity"] >= CLOSE
        if model is not None and (n + 1) % 25 == 0:
            print("%d of %d read back (%.0f s)" % (n + 1, len(items), time.time() - started), flush=True)

    suffix = ("_hints" if args.hints else "") + ("_" + args.only if args.only else "") + args.tag
    with open(os.path.join(args.folder, "read_back%s.json" % suffix), "w", encoding="utf-8") as f:
        json.dump(items, f, indent=1, ensure_ascii=False)

    lines = ["# The commentary voice read back by Whisper (%s%s)" % (args.model, ", with the names as hints" if args.hints else ""), ""]
    for kind, label in (("bank", "Bank lines (slots filled)"), ("name", "Names alone"), ("name_sentence", "Names in a sentence")):
        group = [i for i in items if i["kind"] == kind and i.get("heard") is not None]
        if not group:
            continue
        same = sum(1 for i in group if i["same"])
        close = sum(1 for i in group if i["close"])
        words = sum(i["words"] for i in group)
        errors = sum(i["word_errors"] for i in group)
        line = ("- %s: %d of %d the same words (%.0f %%), %d of %d the same or close (%.0f %%; letters %.0f %% alike); "
                "%d word errors in %d words (%.1f %%)") % (
            label, same, len(group), 100.0 * same / len(group), close, len(group), 100.0 * close / len(group),
            100 * CLOSE, errors, words, 100.0 * errors / max(words, 1))
        if kind != "bank":
            named = sum(1 for i in group if i.get("name_heard"))
            near = sum(1 for i in group if i.get("name_close"))
            line += "; the name came back exactly in %d of %d, exactly or close in %d of %d (%.0f %%)" % (
                named, len(group), near, len(group), 100.0 * near / len(group))
        lines.append(line)
    not_made = [i for i in items if not i.get("made")]
    lines.append("- Not made: %d" % len(not_made))
    lines += ["", "## The lines that differ (close: the same sound spelled another way, or one small word off)", "",
              "| Kind | Id | Said | Heard | Close |", "|---|---|---|---|---|"]
    for i in items:
        if i.get("heard") is not None and not i["same"]:
            close = i["name_close"] if "name_close" in i else i["close"]
            lines.append("| %s | %s | %s | %s | %s |" % (i["kind"], i["id"], i["text"], i["heard"],
                                                     "close" if close else "**off**"))
    with open(os.path.join(args.folder, "read_back%s.md" % suffix), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    sys.stdout.reconfigure(encoding="utf-8")
    print("\n".join(lines[:6]))
    print("Written: %s" % os.path.join(args.folder, "read_back%s.md" % suffix))


if __name__ == "__main__":
    main()
