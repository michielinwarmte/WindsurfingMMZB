"""Frames out of a video for looking at a board over a wave: extracts frames between two times at a
given rate with the bundled ffmpeg, and lays them out on contact sheets (PNG) with the time stamped
on each frame, so a sequence can be read in one image.

  python video_frames.py <video> <out_dir> --start=12.0 --end=15.0 --fps=10 [--cols=5] [--width=480]
"""
import os
import subprocess
import sys

import imageio_ffmpeg
from PIL import Image, ImageDraw

args = [a for a in sys.argv[1:] if not a.startswith("--")]
opts = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--"))
video, out_dir = args[0], args[1]
start = float(opts.get("start", 0.0))
end = float(opts.get("end", start + 3.0))
fps = float(opts.get("fps", 10.0))
cols = int(opts.get("cols", 5))
width = int(opts.get("width", 480))
os.makedirs(out_dir, exist_ok=True)
for old in os.listdir(out_dir):
    if old.startswith("f_") and old.endswith(".png"):
        os.remove(os.path.join(out_dir, old))

ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
pattern = os.path.join(out_dir, "f_%04d.png")
cmd = [ffmpeg, "-hide_banner", "-loglevel", "error", "-ss", f"{start:.3f}", "-to", f"{end:.3f}", "-i", video,
       "-vf", f"fps={fps},scale={width}:-2", "-y", pattern]
subprocess.run(cmd, check=True)
frames = sorted(f for f in os.listdir(out_dir) if f.startswith("f_") and f.endswith(".png"))
print(f"{len(frames)} frames from {start:.2f} to {end:.2f} s at {fps:g} fps")

# Contact sheets of cols x rows frames, at most 4 rows each, the time on every frame.
per_sheet = cols * 4
sheet_no = 0
for first in range(0, len(frames), per_sheet):
    batch = frames[first:first + per_sheet]
    images = [Image.open(os.path.join(out_dir, f)) for f in batch]
    w, h = images[0].size
    rows = (len(batch) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * w, rows * h), "black")
    draw = ImageDraw.Draw(sheet)
    for i, im in enumerate(images):
        x, y = (i % cols) * w, (i // cols) * h
        sheet.paste(im, (x, y))
        t = start + (first + i) / fps
        draw.rectangle([x, y, x + 78, y + 18], fill="black")
        draw.text((x + 4, y + 3), f"{t:6.2f} s", fill="yellow")
    sheet_no += 1
    path = os.path.join(out_dir, f"sheet_{sheet_no:02d}.png")
    sheet.save(path)
    print(path)
