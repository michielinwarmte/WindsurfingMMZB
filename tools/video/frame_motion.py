"""How much each frame differs from the one before it, through a whole video.

A normal video changes a similar amount every frame. Slow motion made by stretching
footage shows a pattern: a big change every Nth frame (a real new picture) and small
changes in between (copies or blends). N then tells the slow-down factor.

  python tools/video/frame_motion.py <video> [--start S] [--end S]

Prints one line per frame: time, frame number, mean absolute difference (0-255) on a
small grey copy of the picture, and a bar.
"""

import argparse
import os
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from video import ffmpeg, probe  # noqa: E402

W, H = 90, 160  # small grey copy: enough to see change, cheap to compare


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("video")
    ap.add_argument("--start", type=float, default=0.0)
    ap.add_argument("--end", type=float)
    a = ap.parse_args()
    info = probe(a.video)
    end = a.end if a.end is not None else info["duration"]
    raw = subprocess.run(
        [ffmpeg("ffmpeg"), "-v", "error", "-ss", "%.3f" % a.start, "-to", "%.3f" % end,
         "-i", a.video, "-vf", "scale=%d:%d,format=gray" % (W, H), "-f", "rawvideo", "-"],
        capture_output=True, check=True).stdout
    frames = np.frombuffer(raw, np.uint8).reshape(-1, H, W).astype(np.float32)
    prev = None
    for i, f in enumerate(frames):
        t = a.start + i / info["fps"]
        d = 0.0 if prev is None else float(np.abs(f - prev).mean())
        print("%7.3f  f%04d  %6.2f  %s" % (t, round(t * info["fps"]), d, "#" * int(d * 4)))
        prev = f


if __name__ == "__main__":
    main()
