"""Cut a transcript into the commentator's sentences and measure how each one is said.

Whisper gives blocks of about 30 seconds with a time on every word. This rebuilds the
sentences from the words (a full stop, question mark or exclamation mark ends one, and so
does a pause of 1.5 s), mends the false full stop Whisper puts where one of its blocks
ends in the middle of a sentence, and measures for each sentence, from the audio:

    seconds   how long it takes to say
    pace      words per second
    loud_db   loudness against the usual loudness of this stream's speech (0 = usual)
    pitch_hz  the voice's pitch (median over the voiced parts; 0 = not measured)
    pitch_rel pitch against the usual pitch of this stream's speech, in semitones
    sure      Whisper's own certainty about the words (0 to 1)

    python -E -P tools/broadcast/sentences.py <media folder> [...]

Reads <folder>/transcript.json, writes <folder>/sentences.jsonl (one sentence per line)
and <folder>/sentences.txt ([h:mm:ss] loud pitch | text).
"""
import argparse
import json
import os
import re
import subprocess

import numpy as np

import transcribe

PAUSE_S = 1.5          # a silence this long ends a sentence, full stop or not
JOIN_GAP_S = 0.6       # block end + lowercase next word within this gap = one sentence
END = re.compile(r"[.!?]+[\"')\]]*$")
HOP_S = 0.01
RATE = 8000


def rebuild(segments):
    """Sentences as lists of [start, end, word, probability]."""
    words = []
    for si, seg in enumerate(segments):
        ws = seg.get("words") or []
        for wi, w in enumerate(ws):
            words.append([w[0], w[1], w[2].strip(), w[3], wi == len(ws) - 1])
    out, cur = [], []
    for i, w in enumerate(words):
        nxt = words[i + 1] if i + 1 < len(words) else None
        text = w[2]
        ends = bool(END.search(text))
        if ends and w[4] and nxt is not None:
            # The last word of a Whisper block: its full stop is false when the talk
            # runs straight on in lower case.
            first = nxt[2][:1]
            if first.islower() and nxt[0] - w[1] < JOIN_GAP_S and not text.endswith(("?", "!")):
                text = text.rstrip(".")
                ends = False
        cur.append([w[0], w[1], text, w[3]])
        gap = (nxt[0] - w[1]) if nxt is not None else 99.0
        if ends or gap >= PAUSE_S:
            out.append(cur)
            cur = []
    if cur:
        out.append(cur)
    return out


def load_segments(folder):
    """The whole transcript, or the pieces done so far when the run is still going."""
    whole = os.path.join(folder, "transcript.json")
    if os.path.exists(whole):
        with open(whole, encoding="utf-8") as f:
            return json.load(f)["segments"]
    segments = []
    pieces = os.path.join(folder, "transcript")
    for name in sorted(os.listdir(pieces)):
        if name.startswith("piece_") and name.endswith(".json"):
            with open(os.path.join(pieces, name), encoding="utf-8") as f:
                segments += json.load(f)["segments"]
    return segments


def voice_frames(media):
    """Loudness (dB) and pitch (Hz, 0 = unvoiced) for every 10 ms of the file."""
    cmd = [transcribe.FFMPEG, "-v", "error", "-nostdin", "-i", media, "-vn", "-ac", "1",
           "-ar", str(RATE), "-f", "s16le", "-"]
    hop, win = int(RATE * HOP_S), 320            # 40 ms windows
    lo, hi = RATE // 400, RATE // 75             # lags for 400 Hz down to 75 Hz
    db, f0 = [], []
    carry = np.zeros(0, dtype=np.float32)
    block = hop * 6000                           # one minute at a time
    with subprocess.Popen(cmd, stdout=subprocess.PIPE) as p:
        while True:
            raw = p.stdout.read(block * 2)
            if not raw:
                break
            x = np.concatenate([carry, np.frombuffer(raw[:len(raw) // 2 * 2], dtype=np.int16)
                                .astype(np.float32) / 32768.0])
            n = (len(x) - win) // hop + 1
            if n <= 0:
                carry = x
                continue
            idx = np.arange(win)[None, :] + hop * np.arange(n)[:, None]
            fr = x[idx]
            carry = x[n * hop:]
            rms = np.sqrt((fr ** 2).mean(axis=1) + 1e-12)
            db.append(20.0 * np.log10(rms))
            fr = fr - fr.mean(axis=1, keepdims=True)
            spec = np.fft.rfft(fr * np.hanning(win)[None, :], 1024, axis=1)
            ac = np.fft.irfft(np.abs(spec) ** 2, axis=1)[:, :hi + 1]
            ac0 = ac[:, 0] + 1e-9
            lag = lo + np.argmax(ac[:, lo:hi + 1], axis=1)
            strength = ac[np.arange(n), lag] / ac0
            f0.append(np.where((strength > 0.45) & (rms > 0.01), RATE / lag, 0.0))
    return np.concatenate(db), np.concatenate(f0)


def measure(folder):
    media = transcribe.find_media(folder)
    segments = load_segments(folder)
    sents = rebuild(segments)
    db, f0 = voice_frames(media)

    def span(a, b):
        i, j = int(a / HOP_S), max(int(b / HOP_S), int(a / HOP_S) + 1)
        return db[i:j], f0[i:j]

    rows = []
    for n, ws in enumerate(sents, 1):
        a, b = ws[0][0], ws[-1][1]
        d, p = span(a, b)
        voiced = p[p > 0]
        rows.append({"id": n, "start": round(a, 2), "end": round(b, 2), "seconds": round(b - a, 2),
                     "text": " ".join(w[2] for w in ws), "words": len(ws),
                     "pace": round(len(ws) / max(b - a, 0.3), 2),
                     "_db": float(np.percentile(d, 80)) if len(d) else -99.0,
                     "pitch_hz": round(float(np.median(voiced)), 1) if len(voiced) >= 8 else 0.0,
                     "sure": round(float(np.mean([w[3] for w in ws])), 3)})
    usual_db = float(np.median([r["_db"] for r in rows if r["words"] >= 3])) if rows else 0.0
    pitched = [r["pitch_hz"] for r in rows if r["pitch_hz"] > 0]
    usual_hz = float(np.median(pitched)) if pitched else 0.0
    for r in rows:
        r["loud_db"] = round(r.pop("_db") - usual_db, 1)
        r["pitch_rel"] = round(12.0 * np.log2(r["pitch_hz"] / usual_hz), 1) if r["pitch_hz"] > 0 and usual_hz > 0 else 0.0
    with open(os.path.join(folder, "sentences.jsonl"), "w", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
    with open(os.path.join(folder, "sentences.txt"), "w", encoding="utf-8") as f:
        for r in rows:
            f.write("[%s] %+5.1f dB %+5.1f st | %s\n" % (transcribe.clock(r["start"]), r["loud_db"],
                                                       r["pitch_rel"], r["text"]))
    print("%s: %d sentences, %d words, usual pitch %.0f Hz"
          % (os.path.basename(folder.rstrip("/\\")), len(rows), sum(r["words"] for r in rows), usual_hz),
          flush=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("folders", nargs="+")
    a = ap.parse_args()
    for folder in a.folders:
        measure(folder.rstrip("/\\"))


if __name__ == "__main__":
    main()
