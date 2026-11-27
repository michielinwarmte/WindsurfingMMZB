"""Split a downloaded stream into its camera shots, for the drone study (E11.S11).

A shot is the stretch between two cuts. The streams hold long drone takes, so one picture
per shot says too little: this saves a picture every --step seconds (every 2 x step after 12 s in the
same shot, every 4 x step after 40 s) and
puts them in time order on numbered contact sheets (20 per sheet). Each picture carries its
time and its shot number; the first picture of a new shot has a red bar on its left.

    python -E -P tools/broadcast/shots.py <media folder> [...] [--step=2] [--threshold=27]

Writes into <media folder>/shots/:
    shots.csv    shot, start_s, end_s, length_s
    frames.csv   frame, time_s, shot, sheet, cell (row-column on the sheet), picture
    f_000123.jpg ...   the pictures (320 px wide)
    sheet_001.jpg ...  the contact sheets
"""
import argparse
import csv
import os

import cv2
from PIL import Image, ImageDraw
from scenedetect import ContentDetector, detect

THUMB_W = 320
COLS, ROWS = 5, 4
LABEL_H = 18


def find_cuts(video, threshold):
    scenes = detect(video, ContentDetector(threshold=threshold, min_scene_len=10))
    return [(a.get_seconds(), b.get_seconds()) for a, b in scenes]


def shot_of(t, shots):
    for i, (a, b) in enumerate(shots, 1):
        if a <= t < b:
            return i
    return len(shots)


def run(folder, step, threshold):
    video = os.path.join(folder, "video.mp4")
    out = os.path.join(folder, "shots")
    os.makedirs(out, exist_ok=True)
    shots = find_cuts(video, threshold)
    cap = cv2.VideoCapture(video)
    fps = cap.get(cv2.CAP_PROP_FPS) or 25.0
    total = cap.get(cv2.CAP_PROP_FRAME_COUNT) / fps
    if not shots:
        shots = [(0.0, total)]

    # Picture times: every `step` seconds inside each shot, starting a little after the cut,
    # so every shot has at least one picture, however short it is.
    times = []
    for i, (a, b) in enumerate(shots, 1):
        t = a + min(0.4, (b - a) / 2.0)
        first = True
        while t < b - 0.05:
            times.append((t, i, first))
            first = False
            # Long takes change slowly: fewer pictures the longer the shot runs.
            into = t - a
            t += step if into < 12.0 else (2.0 * step if into < 40.0 else 4.0 * step)
    frames = []
    for n, (t, shot, first) in enumerate(times, 1):
        cap.set(cv2.CAP_PROP_POS_MSEC, 1000.0 * t)
        ok, frame = cap.read()
        if not ok:
            continue
        h, w = frame.shape[:2]
        small = cv2.resize(frame, (THUMB_W, int(h * THUMB_W / w)), interpolation=cv2.INTER_AREA)
        pic = "f_%06d.jpg" % n
        cv2.imwrite(os.path.join(out, pic), small, [cv2.IMWRITE_JPEG_QUALITY, 82])
        frames.append({"frame": n, "time_s": "%.2f" % t, "shot": shot, "first": first, "picture": pic})
    cap.release()

    per = COLS * ROWS
    for s in range(0, len(frames), per):
        group = frames[s:s + per]
        tw, th = Image.open(os.path.join(out, group[0]["picture"])).size
        sheet = Image.new("RGB", (COLS * tw, ROWS * (th + LABEL_H)), "black")
        draw = ImageDraw.Draw(sheet)
        for i, f in enumerate(group):
            x, y = (i % COLS) * tw, (i // COLS) * (th + LABEL_H)
            sheet.paste(Image.open(os.path.join(out, f["picture"])), (x, y + LABEL_H))
            t = float(f["time_s"])
            draw.text((x + 8, y + 3), "%02d:%02d  shot %d" % (t // 60, t % 60, f["shot"]),
                      fill="yellow" if f["first"] else "white")
            if f["first"]:
                draw.rectangle([x, y, x + 4, y + th + LABEL_H], fill="red")
            f["sheet"] = s // per + 1
            f["cell"] = "%d-%d" % (i // COLS + 1, i % COLS + 1)
        sheet.save(os.path.join(out, "sheet_%03d.jpg" % (s // per + 1)), quality=85)

    with open(os.path.join(out, "shots.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["shot", "start_s", "end_s", "length_s"])
        for i, (a, b) in enumerate(shots, 1):
            w.writerow([i, "%.2f" % a, "%.2f" % b, "%.2f" % (b - a)])
    with open(os.path.join(out, "frames.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["frame", "time_s", "shot", "sheet", "cell", "picture"])
        for fr in frames:
            w.writerow([fr["frame"], fr["time_s"], fr["shot"], fr["sheet"], fr["cell"], fr["picture"]])
    lengths = sorted(b - a for a, b in shots)
    print("%s: %.0f s, %d shots (median %.1f s, longest %.1f s), %d pictures, %d sheets"
          % (os.path.basename(folder), total, len(shots), lengths[len(lengths) // 2], lengths[-1],
             len(frames), (len(frames) + per - 1) // per), flush=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("folders", nargs="+")
    ap.add_argument("--step", type=float, default=2.0)
    ap.add_argument("--threshold", type=float, default=27.0)
    a = ap.parse_args()
    for f in a.folders:
        run(f.rstrip("/\\"), a.step, a.threshold)


if __name__ == "__main__":
    main()
