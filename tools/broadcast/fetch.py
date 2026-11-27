"""Download PWA World Tour stream replays for the broadcast study (E16.S06, E11.S11).

Each video goes into its own folder under the media root, at 480p (enough to see the
camera shots, small on the disk), with yt-dlp's info file next to it.

    python -I tools/broadcast/fetch.py 2FJY7lpVYDA l05DkmpTA3o
    python -I tools/broadcast/fetch.py --list ids.txt
    python -I tools/broadcast/fetch.py --audio-only <id>      # the commentary: speech quality, ~22 MB/hour
    python -I tools/broadcast/fetch.py --best-audio <id>      # the voice step: best quality, ~60 MB/hour

The media root is C:/Users/Max de Dikke/source/pwa_broadcast/media (outside the repo,
--root to change). Downloads are data: nothing in them is run.
"""
import argparse
import os
import subprocess
import sys

HOME = os.path.expanduser("~")
ROOT = os.path.join(HOME, "source", "pwa_broadcast", "media")
FFMPEG_DIR = os.environ.get(
    "FFMPEG_DIR",
    os.path.join(HOME, "AppData/Local/Programs/ffmpeg/ffmpeg-9.1-essentials_build/bin"))


def fetch(vid, root, audio_only, best_audio):
    out = os.path.join(root, vid)
    os.makedirs(out, exist_ok=True)
    if best_audio:
        fmt, name = "ba", "audio_best.%(ext)s"
    elif audio_only:
        # YouTube's format 249 is Opus at about 50 kbit/s: plenty for speech to text.
        fmt, name = "249/250/wa", "audio.%(ext)s"
    else:
        fmt, name = "bv*[height<=480][ext=mp4]+ba[ext=m4a]/b[height<=480]/b", "video.%(ext)s"
    cmd = [sys.executable, "-m", "yt_dlp", "--ffmpeg-location", FFMPEG_DIR,
           "-f", fmt, "--merge-output-format", "mp4", "--write-info-json",
           "--no-playlist", "--no-overwrites", "-o", os.path.join(out, name),
           "https://www.youtube.com/watch?v=" + vid]
    print(">", vid, flush=True)
    return subprocess.call(cmd)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("ids", nargs="*")
    ap.add_argument("--list")
    ap.add_argument("--root", default=ROOT)
    ap.add_argument("--audio-only", action="store_true")
    ap.add_argument("--best-audio", action="store_true")
    a = ap.parse_args()
    ids = list(a.ids)
    if a.list:
        with open(a.list, encoding="utf-8") as f:
            ids += [l.split("#")[0].strip() for l in f if l.split("#")[0].strip()]
    bad = [v for v in ids if fetch(v, a.root, a.audio_only, a.best_audio) != 0]
    print("done", len(ids) - len(bad), "of", len(ids), ("failed: " + " ".join(bad)) if bad else "")


if __name__ == "__main__":
    main()
