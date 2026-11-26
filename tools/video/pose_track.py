"""The sailor's joints on every frame, by a body tracker (MediaPipe's pose landmarker), instead of
by eye. Written 26 November 2026 after Max's yes to Q51 (Documentation/backlog/QUESTIONS.md).

  python -E -P tools/video/pose_track.py check
      video 07's four frames marked by eye (sailor_forces.FRONT) against the tracker: the
      distance per joint, the sideways balance both ways, and a picture (red by eye, green the
      tracker) in <videos>/07_unknown_front_drone/pose/check.png
  python -E -P tools/video/pose_track.py track <video> --start 0 --end 17.8 --crop x,y,w,h
      every frame from start to end: the tracker's 33 joints in the frame's pixels and its 3D
      joints in metres (hip-centred) to <videos>/<video>/pose/track_<start>_<end>.csv. The crop
      is where the sailor is on the first frame; it then follows the joints.
  python -E -P tools/video/pose_track.py legs <csv> [--front]
      how much the legs give: the shoulders' and the hips' distance from the feet per frame, the
      spread of the changes faster than 1 s (the reality check's "legs" case: the game's
      knee_bend_m, the same statistic), the main frequency; --front adds the sideways pull per
      frame from video 07's balance (sailor_forces.front_balance).

Run with -E -P, not -I: MediaPipe is installed in the user's site-packages (pip install --user
mediapipe), which -I hides; -P still keeps the script's folder off the import path. The model
file (pose_landmarker_heavy.task, about 30 MB, Google's, Apache 2.0) lives beside the videos in
<videos>/_models, not in git; MEDIAPIPE_POSE_MODEL overrides the path.

Limits: one camera. The tracker's hips are the hip joints, where the by-eye marks of 26 Nov sat
on the back of the seat; the harness hook and the boom are not tracked (the boom is taken at the
hands' midpoint, which matched by eye within 5 px; the hook is placed from the by-eye frames, in
the trunk's own frame). Joints with a low visibility (a leg hidden behind the other) are left out.
"""

import argparse
import csv
import math
import os
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from video import VIDEOS_ROOT, ffmpeg, original, probe  # noqa: E402

MODEL = os.environ.get("MEDIAPIPE_POSE_MODEL",
                       os.path.join(VIDEOS_ROOT, "_models", "pose_landmarker_heavy.task"))
NAMES = ["nose", "eye_in_l", "eye_l", "eye_out_l", "eye_in_r", "eye_r", "eye_out_r", "ear_l", "ear_r",
         "mouth_l", "mouth_r", "shoulder_l", "shoulder_r", "elbow_l", "elbow_r", "wrist_l", "wrist_r",
         "pinky_l", "pinky_r", "index_l", "index_r", "thumb_l", "thumb_r", "hip_l", "hip_r", "knee_l",
         "knee_r", "ankle_l", "ankle_r", "heel_l", "heel_r", "foot_l", "foot_r"]
IDX = {n: i for i, n in enumerate(NAMES)}
SHOULDER_TO_HIP_M = 0.50   # 0.288 x 1.75 m (Winter 2009), the scale sailor_forces.py uses
MIN_VIS = 0.5


def landmarker():
    import mediapipe as mp  # noqa: F401  (imported for its side effects on the tasks module)
    from mediapipe.tasks import python as mpp
    from mediapipe.tasks.python import vision
    if not os.path.exists(MODEL):
        sys.exit("no pose model at %s: download pose_landmarker_heavy.task from "
                 "https://storage.googleapis.com/mediapipe-models/pose_landmarker/"
                 "pose_landmarker_heavy/float16/latest/pose_landmarker_heavy.task" % MODEL)
    opts = vision.PoseLandmarkerOptions(
        base_options=mpp.BaseOptions(model_asset_path=MODEL),
        running_mode=vision.RunningMode.IMAGE, num_poses=1,
        min_pose_detection_confidence=0.2, min_pose_presence_confidence=0.2)
    return vision.PoseLandmarker.create_from_options(opts)


def detect(lm, frame, crop):
    """The joints in the frame's pixels (x, y, visibility) and in metres (the tracker's 3D), or None."""
    import mediapipe as mp
    x0, y0, cw, ch = crop
    sub = np.ascontiguousarray(frame[y0:y0 + ch, x0:x0 + cw])
    r = lm.detect(mp.Image(image_format=mp.ImageFormat.SRGB, data=sub))
    if not r.pose_landmarks:
        return None, None
    img = np.array([(x0 + p.x * cw, y0 + p.y * ch, p.visibility) for p in r.pose_landmarks[0]])
    world = np.array([(p.x, p.y, p.z) for p in r.pose_world_landmarks[0]])
    return img, world


def follow(img, W, H, margin=0.6, min_size=400):
    """The next frame's crop: the visible joints' box grown by the margin, square-ish, in the frame."""
    pts = img[img[:, 2] > 0.3][:, :2]
    if len(pts) < 8:
        return None
    (x_lo, y_lo), (x_hi, y_hi) = pts.min(0), pts.max(0)
    size = max(x_hi - x_lo, y_hi - y_lo, min_size / (1 + 2 * margin)) * (1 + 2 * margin)
    cx, cy = (x_lo + x_hi) / 2, (y_lo + y_hi) / 2
    w, h = min(size, W), min(size, H)
    x0 = int(min(max(cx - w / 2, 0), W - w))
    y0 = int(min(max(cy - h / 2, 0), H - h))
    return (x0, y0, int(w), int(h))


def frames(path, W, H, start, end):
    """Every frame from start to end (the video's own rate), as (t, rgb array)."""
    fps = probe(path)["fps"]
    proc = subprocess.Popen([ffmpeg("ffmpeg"), "-v", "error", "-ss", "%.3f" % start, "-i", path,
                             "-t", "%.3f" % (end - start), "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
                            stdout=subprocess.PIPE)
    n = 0
    size = W * H * 3
    while True:
        raw = proc.stdout.read(size)
        if len(raw) < size:
            break
        yield start + n / fps, np.frombuffer(raw, np.uint8).reshape(H, W, 3)
        n += 1
    proc.wait()


def out_dir(video):
    d = os.path.join(VIDEOS_ROOT, video, "pose")
    os.makedirs(d, exist_ok=True)
    return d


def cmd_track(a):
    path = original(a.video)
    info = probe(path)
    W, H = info["width"], info["height"]
    crop0 = tuple(int(v) for v in a.crop.split(",")) if a.crop else (0, 0, W, H)
    lm = landmarker()
    out = os.path.join(out_dir(a.video), "track_%g_%g.csv" % (a.start, a.end))
    head = ["t", "found", "crop_x", "crop_y", "crop_w", "crop_h"]
    head += ["%s_%s" % (n, c) for n in NAMES for c in ("x", "y", "vis")]
    head += ["%s_w%s" % (n, c) for n in NAMES for c in ("x", "y", "z")]
    crop, n_found, n = crop0, 0, 0
    with open(out, "w", newline="") as f:
        wr = csv.writer(f)
        wr.writerow(head)
        for t, frame in frames(path, W, H, a.start, a.end):
            img, world = detect(lm, frame, crop)
            n += 1
            if img is None and crop != crop0:
                crop = crop0
                img, world = detect(lm, frame, crop)
            row = [round(t, 4), int(img is not None)] + list(crop)
            if img is None:
                row += [""] * (len(head) - len(row))
            else:
                n_found += 1
                row += [round(float(v), 4) for v in img.reshape(-1)]
                row += [round(float(v), 5) for v in world.reshape(-1)]
                crop = follow(img, W, H) or crop0
            wr.writerow(row)
    print("%d of %d frames found -> %s" % (n_found, n, out))


def load(path):
    with open(path) as f:
        rows = list(csv.DictReader(f))
    t = np.array([float(r["t"]) for r in rows])
    found = np.array([r["found"] == "1" for r in rows])

    def joint(name):
        xy = np.full((len(rows), 2), np.nan)
        vis = np.zeros(len(rows))
        for i, r in enumerate(rows):
            if r["found"] == "1":
                xy[i] = float(r[name + "_x"]), float(r[name + "_y"])
                vis[i] = float(r[name + "_vis"])
        return xy, vis
    return t, found, joint


def mid(joint, a, b):
    """The midpoint of a left and right joint, or the visible one alone."""
    (pa, va), (pb, vb) = joint(a), joint(b)
    out = np.where((va >= MIN_VIS)[:, None] & (vb >= MIN_VIS)[:, None], 0.5 * (pa + pb),
                   np.where((va >= vb)[:, None], pa, pb))
    bad = (va < MIN_VIS) & (vb < MIN_VIS)
    out[bad] = np.nan
    return out


def moving_average(v, n):
    k = np.ones(n) / n
    pad = n // 2
    vp = np.pad(v, (pad, n - 1 - pad), mode="edge")
    return np.convolve(vp, k, mode="valid")


def fast_spread(v, fps):
    """The reality check's statistic: the value minus its 1 s moving average, its standard deviation."""
    ok = ~np.isnan(v)
    v = np.interp(np.arange(len(v)), np.nonzero(ok)[0], v[ok])
    return float((v - moving_average(v, max(3, int(round(fps))))).std())


def main_frequency(v, fps, lo=0.2, hi=5.0):
    ok = ~np.isnan(v)
    v = np.interp(np.arange(len(v)), np.nonzero(ok)[0], v[ok])
    v = v - moving_average(v, max(3, int(round(2 * fps))))
    spec = np.abs(np.fft.rfft(v * np.hanning(len(v))))
    f = np.fft.rfftfreq(len(v), 1.0 / fps)
    band = (f >= lo) & (f <= hi)
    return float(f[band][np.argmax(spec[band])])


def moving_median(v, n):
    pad = n // 2
    vp = np.pad(v, (pad, n - 1 - pad), mode="edge")
    return np.array([np.nanmedian(vp[i:i + n]) if np.any(~np.isnan(vp[i:i + n])) else np.nan
                     for i in range(len(v))])


def cmd_legs(a):
    t, found, joint = load(a.csv)
    fps = 1.0 / np.median(np.diff(t))
    keep = (t >= a.start) & (t <= (a.until if a.until is not None else t.max()))
    sh, hip = mid(joint, "shoulder_l", "shoulder_r"), mid(joint, "hip_l", "hip_r")
    ank = mid(joint, "ankle_l", "ankle_r")
    # The scale follows the camera's zoom: the trunk's length in pixels over the last second (its
    # median), each frame. Frames whose trunk is 20 % off that, or whose hips jump more than a
    # quarter of a trunk from the last frame, are the tracker losing the sailor: left out.
    trunk = np.linalg.norm(sh - hip, axis=1)
    trunk_s = moving_median(trunk, max(3, int(round(fps))))
    jump = np.r_[0.0, np.linalg.norm(np.diff(hip, axis=0), axis=1)]
    with np.errstate(invalid="ignore"):
        bad = (np.abs(trunk / trunk_s - 1.0) > 0.2) | (jump > 0.25 * trunk_s) | ~keep
    px_per_m = trunk_s / SHOULDER_TO_HIP_M
    d_sh = np.linalg.norm(sh - ank, axis=1) / px_per_m
    d_hip = np.linalg.norm(hip - ank, axis=1) / px_per_m
    up_sh = (ank[:, 1] - sh[:, 1]) / px_per_m       # the shoulders' height above the feet in the picture
    for v in (d_sh, d_hip, up_sh):
        v[bad] = np.nan
    n_smooth = max(3, int(round(fps / 6.0)))         # about 0.17 s: the tracker's jitter out, chop kept
    print("%s: %d frames at %.2f fps, %d found, %d kept (%.1f to %.1f s); scale %.0f to %.0f px/m "
          "(shoulder to hip = %.2f m)" % (os.path.basename(a.csv), len(t), fps, found.sum(),
                                          int((~np.isnan(d_hip)).sum()), t[keep].min(), t[keep].max(),
                                          np.nanmin(px_per_m[keep]), np.nanmax(px_per_m[keep]), SHOULDER_TO_HIP_M))
    print("%-36s %8s %8s %8s %8s %9s %8s" % ("", "mean m", "fast cm", "smooth", "jitter", "main Hz", "frames"))
    for name, v in (("shoulders to the feet", d_sh), ("hips to the feet", d_hip),
                    ("shoulders above the feet (picture)", up_sh)):
        vk = v[keep]
        ok = ~np.isnan(vk)
        vi = np.interp(np.arange(len(vk)), np.nonzero(ok)[0], vk[ok])
        smooth = moving_average(vi, n_smooth)
        jitter = float(np.diff(vi).std() / math.sqrt(2.0))
        print("%-36s %8.2f %8.1f %8.1f %8.1f %9.2f %8d" % (
            name, np.nanmean(vk), 100 * fast_spread(vk, fps), 100 * fast_spread(smooth, fps),
            100 * jitter, main_frequency(smooth, fps), ok.sum()))
    print("fast: the reality check's statistic (minus the 1 s average, the SD); smooth: the same after a "
          "%.2f s average takes the tracker's jitter out; jitter: the frame-to-frame noise (as white)."
          % (n_smooth / fps))
    if a.front:
        front_pull(t[keep], lambda n: tuple(x[keep] for x in joint(n)), a.mass, fps)


def hook_offset():
    """The harness hook from the by-eye frames of video 07, in the trunk's own frame (along the
    trunk from the tracker's hip midpoint, and across it), in trunk lengths. The by-eye hook is
    used with the tracker's hips and shoulders on the same frames (check.csv from 'check')."""
    path = os.path.join(VIDEOS_ROOT, "07_unknown_front_drone", "pose", "check.csv")
    if not os.path.exists(path):
        sys.exit("run 'check' first: it places the hook from the by-eye frames")
    with open(path) as f:
        rows = list(csv.DictReader(f))
    return float(np.mean([float(r["hook_along"]) for r in rows])), float(np.mean([float(r["hook_across"]) for r in rows]))


def place_hook(sh, hip, along, across):
    axis = sh - hip
    length = np.linalg.norm(axis)
    u = axis / length
    n = np.array([-u[1], u[0]])
    return hip + along * length * u + across * length * n


def tracked_keypoints(P):
    """sailor_forces' front-view joints from the tracker's (a dict name -> (x, y) in pixels)."""
    def m(a, b):
        return 0.5 * (np.array(P[a]) + np.array(P[b]))
    k = dict(head=tuple(P["nose"]), shoulder=tuple(m("shoulder_l", "shoulder_r")),
             hip=tuple(m("hip_l", "hip_r")), hand_f=tuple(P["wrist_l"]), hand_b=tuple(P["wrist_r"]))
    k["boom"] = tuple(m("wrist_l", "wrist_r"))
    return k


def front_pull(t, joint, mass, fps):
    from sailor_forces import front_balance
    along, across = hook_offset()
    J = {n: joint(n) for n in NAMES}
    pulls, lines, outs = [], [], []
    for i in range(len(t)):
        need = ["nose", "shoulder_l", "shoulder_r", "hip_l", "hip_r", "wrist_l", "wrist_r"]
        if any(np.isnan(J[n][0][i]).any() or J[n][1][i] < MIN_VIS for n in need):
            pulls.append(np.nan); lines.append(np.nan); outs.append(np.nan)
            continue
        P = {n: J[n][0][i] for n in NAMES}
        k = tracked_keypoints(P)
        legs = [s for s in ("l", "r") if J["knee_" + s][1][i] >= MIN_VIS and J["ankle_" + s][1][i] >= MIN_VIS]
        if not legs:
            pulls.append(np.nan); lines.append(np.nan); outs.append(np.nan)
            continue
        s = max(legs, key=lambda s_: J["ankle_" + s_][1][i])
        k["knee"], k["ankle"] = tuple(P["knee_" + s]), tuple(P["ankle_" + s])
        k["hook"] = tuple(place_hook(np.array(k["shoulder"]), np.array(k["hip"]), along, across))
        b = front_balance(k, mass)
        pulls.append(b["pull_n"]); lines.append(b["body_line_deg"]); outs.append(b["com_out_m"])
    pulls, lines, outs = np.array(pulls), np.array(lines), np.array(outs)
    w = mass * 9.81
    ok = ~np.isnan(pulls)
    print("\nThe sideways balance per frame (video 07's method; %d of %d frames usable):" % (ok.sum(), len(t)))
    print("  pull / weight: median %.2f, 10-90 %% %.2f to %.2f" % (np.nanmedian(pulls) / w,
          np.nanpercentile(pulls, 10) / w, np.nanpercentile(pulls, 90) / w))
    print("  body line from the feet: median %.1f deg, 10-90 %% %.1f to %.1f" % (np.nanmedian(lines),
          np.nanpercentile(lines, 10), np.nanpercentile(lines, 90)))
    print("  centre of mass outboard of the feet: median %.2f m" % np.nanmedian(outs))


def cmd_check(a):
    from PIL import Image, ImageDraw
    from grid_overlay import frame_at
    from sailor_forces import FRONT, front_balance
    path = original("07_unknown_front_drone")
    info = probe(path)
    W, H = info["width"], info["height"]
    lm = landmarker()
    crop = (0, 800, 1000, 700)
    tiles, rows = [], []
    pairs = [("head", "nose"), ("shoulder", ("shoulder_l", "shoulder_r")), ("hip", ("hip_l", "hip_r")),
             ("knee", None), ("ankle", None), ("hand_f", "wrist_l"), ("hand_b", "wrist_r")]
    print("%-5s " % "t" + "".join("%9s" % p[0] for p in pairs) + "   (px, by eye to the tracker)")
    for t, k in FRONT.items():
        img = frame_at(path, t, W, H).convert("RGB")
        pts, _ = detect(lm, np.asarray(img), crop)
        P = {n: pts[i, :2] for i, n in enumerate(NAMES)}
        vis = {n: pts[i, 2] for i, n in enumerate(NAMES)}
        s = "l" if vis["ankle_l"] > vis["ankle_r"] else "r"
        dists = []
        for eye, tr in pairs:
            if tr is None:
                q = P[eye + "_" + s]
            elif isinstance(tr, tuple):
                q = 0.5 * (P[tr[0]] + P[tr[1]])
            else:
                q = P[tr]
            dists.append(float(np.linalg.norm(np.array(k[eye]) - q)))
        print("%-5.1f " % t + "".join("%9.0f" % d for d in dists))
        tk = tracked_keypoints(P)
        tk["knee"], tk["ankle"] = tuple(P["knee_" + s]), tuple(P["ankle_" + s])
        sh, hp = np.array(tk["shoulder"]), np.array(tk["hip"])
        axis = sh - hp
        u = axis / np.linalg.norm(axis)
        n = np.array([-u[1], u[0]])
        rel = (np.array(k["hook"]) - hp) / np.linalg.norm(axis)
        tk["hook"] = k["hook"]
        by_eye, tracked = front_balance(k, a.mass), front_balance(tk, a.mass)
        rows.append(dict(t=t, hook_along=float(rel @ u), hook_across=float(rel @ n),
                         pull_eye=by_eye["pull_n"], pull_tracker=tracked["pull_n"],
                         line_eye=by_eye["body_line_deg"], line_tracker=tracked["body_line_deg"],
                         out_eye=by_eye["com_out_m"], out_tracker=tracked["com_out_m"],
                         knee_eye=by_eye["knee_deg"], knee_tracker=tracked["knee_deg"]))
        d = ImageDraw.Draw(img)
        for i, j in [(11, 12), (11, 23), (12, 24), (23, 24), (23, 25), (25, 27), (24, 26), (26, 28),
                     (11, 13), (13, 15), (12, 14), (14, 16), (27, 31), (28, 32)]:
            d.line([tuple(pts[i, :2]), tuple(pts[j, :2])], fill=(0, 255, 0), width=3)
        for q in pts:
            d.ellipse([q[0] - 5, q[1] - 5, q[0] + 5, q[1] + 5], fill=(0, 255, 0))
        for q in k.values():
            d.ellipse([q[0] - 8, q[1] - 8, q[0] + 8, q[1] + 8], outline=(255, 0, 0), width=3)
        d.text((20, 870), "t = %.0f s   red: by eye   green: the tracker" % t, fill=(255, 255, 255))
        tiles.append(img.crop((0, 850, 950, 1500)))
    w = a.mass * 9.81
    print("\n%-5s %18s %18s %18s %16s" % ("t", "pull/weight", "body line deg", "CoM out m", "knee deg"))
    for r in rows:
        print("%-5.1f %8.2f -> %5.2f %8.1f -> %5.1f %8.2f -> %5.2f %7.0f -> %4.0f" % (
            r["t"], r["pull_eye"] / w, r["pull_tracker"] / w, r["line_eye"], r["line_tracker"],
            r["out_eye"], r["out_tracker"], r["knee_eye"], r["knee_tracker"]))
    print("median pull/weight: by eye %.2f, the tracker's joints %.2f" % (
        np.median([r["pull_eye"] for r in rows]) / w, np.median([r["pull_tracker"] for r in rows]) / w))
    d = out_dir("07_unknown_front_drone")
    with open(os.path.join(d, "check.csv"), "w", newline="") as f:
        wr = csv.DictWriter(f, fieldnames=list(rows[0]))
        wr.writeheader()
        wr.writerows(rows)
    tw, th = tiles[0].size
    sheet = Image.new("RGB", (tw * 2, th * 2))
    for i, tl in enumerate(tiles):
        sheet.paste(tl, ((i % 2) * tw, (i // 2) * th))
    sheet.save(os.path.join(d, "check.png"))
    print("picture and table in", d)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("check")
    c.add_argument("--mass", type=float, default=85.0)
    tr = sub.add_parser("track")
    tr.add_argument("video")
    tr.add_argument("--start", type=float, default=0.0)
    tr.add_argument("--end", type=float, required=True)
    tr.add_argument("--crop", help="x,y,w,h where the sailor is on the first frame")
    lg = sub.add_parser("legs")
    lg.add_argument("csv")
    lg.add_argument("--front", action="store_true", help="the sideways pull per frame (video 07)")
    lg.add_argument("--mass", type=float, default=85.0)
    lg.add_argument("--start", type=float, default=0.0, help="leave out the frames before (s)")
    lg.add_argument("--until", type=float, help="leave out the frames after (s), e.g. where the tracker loses the sailor")
    a = ap.parse_args()
    {"check": cmd_check, "track": cmd_track, "legs": cmd_legs}[a.cmd](a)


if __name__ == "__main__":
    main()
