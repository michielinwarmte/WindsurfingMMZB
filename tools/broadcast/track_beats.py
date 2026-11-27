"""Run sail_track.py on beats of the shot notes, named as <video id>:<shot><part>.

    python -E -P tools/broadcast/track_beats.py <media root> <out root> <id:shot> [...] [--max-seconds=8]

The stretch and the horizon's row come from the beat's row in shot_notes.csv.
"""
import csv
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict(a[2:].split("=") for a in sys.argv[1:] if a.startswith("--"))
    root, out = args[0], args[1]
    longest = float(opts.get("max-seconds", 8.0))
    for name in args[2:]:
        vid, shot = name.split(":")
        with open(os.path.join(root, vid, "shots", "shot_notes.csv"), encoding="utf-8-sig") as f:
            rows = [r for r in csv.DictReader(f) if r["shot"] + r["part"] == shot]
        if not rows:
            print(name, "not in the notes")
            continue
        r = rows[0]
        a, b = float(r["start_s"]) + 0.3, float(r["end_s"]) - 0.2
        b = min(b, a + longest)
        hz = r["horizon_pct"]
        video = os.path.join(root, vid, "video.mp4")
        folder = os.path.join(out, "%s_%s" % (vid[:5], shot))
        cmd = [sys.executable, "-E", "-P", os.path.join(HERE, "sail_track.py"), video, "%.2f" % a, "%.2f" % b, folder]
        if hz not in ("none", "", "na"):
            cmd.append("--horizon=%d" % round(float(hz) * 4.8))
        print(name, r["view"], r["subject"], r["move"], "horizon", hz, "->", end=" ", flush=True)
        subprocess.call(cmd)


if __name__ == "__main__":
    main()
