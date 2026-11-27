"""Turn the commentary of downloaded streams into text with a time on every word.

Runs Whisper (faster-whisper) on this PC's processor; nothing is sent anywhere.
The audio is read through ffmpeg and cut into pieces of about 20 minutes, each cut
placed in the quietest moment near the 20-minute point so no word is split. Every piece
is saved as soon as it is done, so a stopped run goes on where it was.

Writes next to the video or audio file:
    transcript/piece_0000.json ...  one file per piece (the resume points)
    transcript.json  the sentences, each with start/end seconds and its words' times
    transcript.txt   one line per sentence: [h:mm:ss] text

    python -E -P tools/broadcast/transcribe.py <media folder> [...]
        [--model=large-v3-turbo] [--jobs=3] [--threads=4]     3 x 4 = 12 of 16 threads
        [--hint-file=<txt>]   the sport's words and the riders' names (made by rider_hint.py)
        [--seconds=180]      a timing test on the first seconds only (writes transcript_test*.json)

The model is downloaded once from Hugging Face into the user's cache.
"""
import argparse
import json
import os
import subprocess
import sys
import time
from concurrent.futures import ProcessPoolExecutor, as_completed

import numpy as np

HOME = os.path.expanduser("~")
FFMPEG = os.path.join(
    os.environ.get("FFMPEG_DIR",
                   os.path.join(HOME, "AppData/Local/Programs/ffmpeg/ffmpeg-9.1-essentials_build/bin")),
    "ffmpeg.exe")
RATE = 16000
PIECE_S = 1200.0        # the aim for one piece
SEARCH_S = 45.0         # look this far either side of the aim for the quietest moment

# Words of the sport and the riders' names, given to Whisper for every stretch so it spells
# them the sport's way. Written as short sentences: a comma list makes Whisper answer in
# one long comma sentence. Whisper reads at most about 220 word pieces of this, so the
# sport's words come first and the riders after (--riders, a JSON from the PWA entry list).
SPORT_WORDS = ("PWA World Tour. Slalom-X at Sotavento, Fuerteventura. A laydown gybe at the mark. "
               "The Defi Wind. Severne. Duotone. Patrik. ")


HOTWORDS = SPORT_WORDS

_model = None


def find_media(path):
    if os.path.isfile(path):
        return path
    for name in ("audio.webm", "audio.m4a", "audio.opus", "video.mp4"):
        p = os.path.join(path, name)
        if os.path.exists(p):
            return p
    raise SystemExit("no video or audio in " + path)


def read_audio(media, start=0.0, seconds=None):
    """The audio as 16 kHz mono floats, decoded by ffmpeg."""
    cmd = [FFMPEG, "-v", "error", "-nostdin"]
    if start > 0:
        cmd += ["-ss", "%.3f" % start]
    cmd += ["-i", media]
    if seconds:
        cmd += ["-t", "%.3f" % seconds]
    cmd += ["-vn", "-ac", "1", "-ar", str(RATE), "-f", "s16le", "-"]
    raw = subprocess.run(cmd, stdout=subprocess.PIPE, check=True).stdout
    return np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0


def loudness_envelope(media):
    """The loudness of every 0.1 s of the whole file (one pass, little memory)."""
    cmd = [FFMPEG, "-v", "error", "-nostdin", "-i", media, "-vn", "-ac", "1", "-ar", "8000",
           "-f", "s16le", "-"]
    hop = 800
    env = []
    with subprocess.Popen(cmd, stdout=subprocess.PIPE) as p:
        while True:
            raw = p.stdout.read(hop * 2 * 600)
            if not raw:
                break
            x = np.frombuffer(raw[:len(raw) // 2 * 2], dtype=np.int16).astype(np.float32)
            n = len(x) // hop
            if n:
                env.append(np.sqrt((x[:n * hop].reshape(n, hop) ** 2).mean(axis=1)))
    return np.concatenate(env) if env else np.zeros(1, dtype=np.float32)


def plan_pieces(media):
    """Cut points in seconds: each near a multiple of PIECE_S, at the quietest half second."""
    env = loudness_envelope(media)
    total = len(env) * 0.1
    cuts = [0.0]
    smooth = np.convolve(env, np.ones(5) / 5.0, mode="same")
    while total - cuts[-1] > PIECE_S * 1.5:
        aim = cuts[-1] + PIECE_S
        a, b = int((aim - SEARCH_S) * 10), int((aim + SEARCH_S) * 10)
        cuts.append((a + int(np.argmin(smooth[a:b]))) * 0.1)
    cuts.append(total)
    return [(round(cuts[i], 2), round(cuts[i + 1], 2)) for i in range(len(cuts) - 1)]


def _load(model_name, threads, hotwords):
    global _model, HOTWORDS
    HOTWORDS = hotwords
    from faster_whisper import WhisperModel
    _model = WhisperModel(model_name, device="cpu", compute_type="int8", cpu_threads=threads)


def _piece(media, start, end, out):
    t0 = time.time()
    audio = read_audio(media, start, end - start)
    segments, _ = _model.transcribe(
        audio, language="en", word_timestamps=True, vad_filter=True,
        vad_parameters={"min_silence_duration_ms": 700},
        hotwords=HOTWORDS, beam_size=5, condition_on_previous_text=False)
    rows = []
    for s in segments:
        rows.append({"start": round(s.start + start, 2), "end": round(s.end + start, 2),
                     "text": s.text.strip(), "avg_logprob": round(s.avg_logprob, 3),
                     "no_speech_prob": round(s.no_speech_prob, 3),
                     "words": [[round(w.start + start, 2), round(w.end + start, 2), w.word,
                                round(w.probability, 3)] for w in (s.words or [])]})
    took = time.time() - t0
    tmp = out + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump({"start": start, "end": end, "seconds_taken": round(took, 1), "segments": rows}, f)
    os.replace(tmp, out)
    return media, start, end, took, len(rows)


def clock(t):
    h, rest = divmod(int(t), 3600)
    return "%d:%02d:%02d" % (h, rest // 60, rest % 60)


def join(folder, media, pieces, tag=""):
    rows, took = [], 0.0
    for i, _ in enumerate(pieces):
        with open(os.path.join(folder, "transcript" + tag, "piece_%04d.json" % i), encoding="utf-8") as f:
            d = json.load(f)
        rows += d["segments"]
        took += d["seconds_taken"]
    with open(os.path.join(folder, "transcript%s.json" % tag), "w", encoding="utf-8") as f:
        json.dump({"media": os.path.basename(media), "duration_s": pieces[-1][1],
                   "seconds_taken": round(took, 1), "segments": rows}, f, indent=1)
    with open(os.path.join(folder, "transcript%s.txt" % tag), "w", encoding="utf-8") as f:
        for r in rows:
            f.write("[%s] %s\n" % (clock(r["start"]), r["text"]))
    return len(rows), took


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("paths", nargs="+")
    ap.add_argument("--model", default="large-v3-turbo")
    ap.add_argument("--jobs", type=int, default=3)
    ap.add_argument("--threads", type=int, default=4)
    ap.add_argument("--seconds", type=int, default=0)
    ap.add_argument("--hint-file", default="")
    a = ap.parse_args()
    hotwords = SPORT_WORDS
    if a.hint_file:
        with open(a.hint_file, encoding="utf-8") as f:
            hotwords = f.read().strip()

    todo, plans = [], {}
    for p in a.paths:
        media = find_media(p)
        folder = os.path.dirname(media)
        if a.seconds:
            tag, pieces = "_test%ds_%s" % (a.seconds, a.model), [(0.0, float(a.seconds))]
        else:
            tag, pieces = "", plan_pieces(media)
        os.makedirs(os.path.join(folder, "transcript" + tag), exist_ok=True)
        plans[media] = (folder, pieces, tag)
        for i, (s, e) in enumerate(pieces):
            out = os.path.join(folder, "transcript" + tag, "piece_%04d.json" % i)
            if not os.path.exists(out):
                todo.append((media, s, e, out))
        print("%s: %d pieces, %s of audio" % (folder, len(pieces), clock(pieces[-1][1])), flush=True)

    # The longest pieces first, so the pool stays full to the end.
    todo.sort(key=lambda j: j[1] - j[2])
    audio_total = sum(e - s for _, s, e, _ in todo)
    print("to do: %d pieces, %s of audio, %d jobs x %d threads, model %s"
          % (len(todo), clock(audio_total), a.jobs, a.threads, a.model), flush=True)
    t0, done_audio = time.time(), 0.0
    if todo:
        with ProcessPoolExecutor(max_workers=a.jobs, initializer=_load,
                                 initargs=(a.model, a.threads, hotwords)) as pool:
            futures = [pool.submit(_piece, *j) for j in todo]
            for n, fut in enumerate(as_completed(futures), 1):
                media, s, e, took, count = fut.result()
                done_audio += e - s
                wall = time.time() - t0
                left = (audio_total - done_audio) * wall / max(done_audio, 1.0)
                print("%d/%d  %s %s-%s  %d sentences  piece %.1fx  overall %.1fx real time  about %s left"
                      % (n, len(todo), os.path.basename(os.path.dirname(media)), clock(s), clock(e),
                         count, (e - s) / max(took, 0.1), done_audio / max(wall, 0.1), clock(left)),
                      flush=True)
    for media, (folder, pieces, tag) in plans.items():
        count, took = join(folder, media, pieces, tag)
        print("%s: %s of audio, %d sentences, %.0f s of work" % (folder, clock(pieces[-1][1]), count, took),
              flush=True)


if __name__ == "__main__":
    sys.exit(main())
