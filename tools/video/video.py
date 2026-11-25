"""Video analysis helper: download a video, then make frame grids and single frames to read.

Videos and frames live outside git in VIDEOS_ROOT (other people's videos: private study only).
The text findings go to Documentation/reports/video/.

  python tools/video/video.py fetch  <url> <name>
  python tools/video/video.py info   <name>
  python tools/video/video.py grid   <name> [--start S] [--end S] [--fps F] [--cols C] [--thumb W]
                                     [--crop x,y,w,h]
  python tools/video/video.py frames <name> --start S --end S [--fps F]

<name> is the folder in VIDEOS_ROOT, e.g. 01_sotavento_speedrun. Times are in seconds.
fetch never overwrites a download that is already there; grid and frames write new files
named after their time range, so earlier ones are kept.

Needs yt-dlp (pip install --user yt-dlp), ffmpeg (FFMPEG_DIR or the default below) and Pillow.
"""

import argparse
import glob
import json
import math
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont

VIDEOS_ROOT = os.environ.get(
    "VIDEOS_ROOT", "C:/Users/Max de Dikke/source/WindsurfingMMZB-videos")
FFMPEG_DIR = os.environ.get(
    "FFMPEG_DIR",
    os.path.join(os.environ.get("LOCALAPPDATA", ""),
                 "Programs/ffmpeg/ffmpeg-9.1-essentials_build/bin"))


def ffmpeg(name):
    exe = os.path.join(FFMPEG_DIR, name + ".exe")
    return exe if os.path.exists(exe) else name


def video_dir(name):
    return os.path.join(VIDEOS_ROOT, name)


def original(name):
    hits = [p for p in glob.glob(os.path.join(video_dir(name), "original_*"))
            if os.path.splitext(p)[1].lower() in (".mp4", ".webm", ".mkv", ".mov")]
    if not hits:
        sys.exit("no original_* video in " + video_dir(name))
    return hits[0]


def probe(path):
    out = subprocess.run(
        [ffmpeg("ffprobe"), "-v", "error", "-select_streams", "v:0", "-show_entries",
         "stream=width,height,r_frame_rate,nb_frames:format=duration", "-of", "json", path],
        capture_output=True, text=True, check=True).stdout
    d = json.loads(out)
    s = d["streams"][0]
    num, den = s["r_frame_rate"].split("/")
    return {"width": int(s["width"]), "height": int(s["height"]),
            "fps": float(num) / float(den), "duration": float(d["format"]["duration"]),
            "frames": s.get("nb_frames")}


def cmd_fetch(a):
    d = video_dir(a.name)
    os.makedirs(d, exist_ok=True)
    subprocess.run(
        [sys.executable, "-m", "yt_dlp", "--ffmpeg-location", FFMPEG_DIR,
         "-S", "res,fps,vcodec:h264", "-f", "bv*+ba/b", "--merge-output-format", "mp4",
         "--write-info-json", "--no-overwrites",
         "-o", os.path.join(d, "original_%(id)s.%(ext)s"), a.url], check=True)
    cmd_info(a)


def cmd_info(a):
    p = original(a.name)
    print(p)
    print(json.dumps(probe(p), indent=1))


def extract(path, start, end, fps, outdir, crop=None):
    """Frames from start to end (seconds); fps=None keeps every frame; crop = "x,y,w,h" in the
    video's pixels or None. Returns (time, file) pairs."""
    filters = []
    if fps:
        filters.append("fps=%g" % fps)
    if crop:
        x, y, w, h = crop.split(",")
        filters.append("crop=%s:%s:%s:%s" % (w, h, x, y))
    vf = ["-vf", ",".join(filters)] if filters else []
    subprocess.run(
        [ffmpeg("ffmpeg"), "-v", "error", "-ss", "%.3f" % start, "-to", "%.3f" % end,
         "-i", path] + vf + ["-start_number", "0", os.path.join(outdir, "f%05d.png")],
        check=True)
    files = sorted(glob.glob(os.path.join(outdir, "f*.png")))
    if fps:
        return [(start + i / fps, f) for i, f in enumerate(files)]
    # Every frame: the first one is the first whole frame at or after `start`, so the
    # times (and the frame numbers printed from them) sit exactly on the video's frames.
    video_fps = probe(path)["fps"]
    first = math.ceil(start * video_fps - 1e-6)
    return [((first + i) / video_fps, f) for i, f in enumerate(files)]


def font(size):
    for f in ("C:/Windows/Fonts/consola.ttf", "C:/Windows/Fonts/arial.ttf"):
        if os.path.exists(f):
            return ImageFont.truetype(f, size)
    return ImageFont.load_default()


def tag(name, start, end, fps):
    return "%s_%06.2f-%06.2f_%s" % (name, start, end, ("%gfps" % fps) if fps else "all")


def cmd_grid(a):
    p = original(a.name)
    info = probe(p)
    end = a.end if a.end is not None else info["duration"]
    out_dir = os.path.join(video_dir(a.name), "grids")
    os.makedirs(out_dir, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        shots = extract(p, a.start, end, a.fps, tmp, a.crop)
        if not shots:
            sys.exit("no frames in that range")
        src_w, src_h = Image.open(shots[0][1]).size
        w = a.thumb
        h = round(w * src_h / src_w)
        cols = a.cols
        rows = (len(shots) + cols - 1) // cols
        pad, label = 6, max(18, w // 12)
        sheet = Image.new("RGB", (cols * (w + pad) + pad, rows * (h + label + pad) + pad),
                          (24, 24, 24))
        draw = ImageDraw.Draw(sheet)
        f = font(label - 4)
        for i, (t, fp) in enumerate(shots):
            x = pad + (i % cols) * (w + pad)
            y = pad + (i // cols) * (h + label + pad)
            draw.text((x + 2, y), "%d  t=%.2fs  f%d" % (i, t, math.floor(t * info["fps"] + 0.5)),
                      fill=(255, 230, 120), font=f)
            sheet.paste(Image.open(fp).convert("RGB").resize((w, h), Image.LANCZOS),
                        (x, y + label))
    crop_tag = ("_crop" + a.crop.replace(",", "-")) if a.crop else ""
    out = os.path.join(out_dir, tag(a.name, a.start, end, a.fps) + crop_tag + "_grid.png")
    sheet.save(out)
    print(out, sheet.size, len(shots), "frames")


def cmd_frames(a):
    p = original(a.name)
    out_dir = os.path.join(video_dir(a.name), "frames", tag(a.name, a.start, a.end, a.fps))
    os.makedirs(out_dir, exist_ok=True)
    fps_v = probe(p)["fps"]
    with tempfile.TemporaryDirectory() as tmp:
        for t, fp in extract(p, a.start, a.end, a.fps, tmp):
            dst = os.path.join(out_dir, "t%06.3f_f%05d.png" % (t, math.floor(t * fps_v + 0.5)))
            if not os.path.exists(dst):
                os.replace(fp, dst)
    print(out_dir, len(os.listdir(out_dir)), "frames")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("fetch"); s.add_argument("url"); s.add_argument("name")
    s.set_defaults(func=cmd_fetch)
    s = sub.add_parser("info"); s.add_argument("name"); s.set_defaults(func=cmd_info)
    s = sub.add_parser("grid"); s.add_argument("name")
    s.add_argument("--start", type=float, default=0.0)
    s.add_argument("--end", type=float)
    s.add_argument("--fps", type=float, default=1.0, help="frames per second; 0 = every frame")
    s.add_argument("--cols", type=int, default=7)
    s.add_argument("--thumb", type=int, default=300, help="width of one frame in the grid")
    s.add_argument("--crop", help="x,y,w,h in the video's pixels: zoom in on one part")
    s.set_defaults(func=cmd_grid)
    s = sub.add_parser("frames"); s.add_argument("name")
    s.add_argument("--start", type=float, required=True)
    s.add_argument("--end", type=float, required=True)
    s.add_argument("--fps", type=float, default=0.0, help="0 = every frame")
    s.set_defaults(func=cmd_frames)
    a = ap.parse_args()
    if hasattr(a, "fps") and a.fps == 0:
        a.fps = None
    a.func(a)


if __name__ == "__main__":
    main()
