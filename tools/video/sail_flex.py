"""The sail's twist and the mast's sideways bend, seen from straight ahead: video 07 (points read
by eye) and the game's own sail (its red cloth found row by row), measured the same way.

  python tools/video/sail_flex.py

From ahead a sail sheeted at angle beta shows the width chord x sin(beta) square to the mast; with
twist the upper sail shows more width for its chord. So beta at each height is asin(width / chord),
with the chord from the sail's outline: the game's traced Severne HGO 8.0 (build_rig_models.py: the leech
runs about straight from the clew to a head 0.40 of the boom's chord wide), 2.0 m narrowing to 0.8 m. Far points are a little smaller
(perspective): the width is scaled up by (distance + chord) / distance. Every number here is an
estimate (one camera, an assumed outline); the game's sail, whose twist is known (RigVisuals:
8 to 16 degrees at the head), checks the method. Written 26 November 2026, for twist_stall_shift_deg.
"""

import math
import os

import numpy as np

VIDEOS = "C:/Users/Max de Dikke/source/WindsurfingMMZB-videos"
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Video 07 at 3 s (original pixels): the luff (the bright line along the mast sleeve) at two
# heights, the boom clamp and the mast foot, and the leech at the batten ends, top to bottom.
REAL = dict(t=3.0, luff_top=(427, 125), clamp=(588, 856), foot=(867, 1380),
            leech=[(644, 88), (678, 219), (706, 344), (723, 469), (738, 588), (756, 725)],
            clew=(925, 900), boom_height_m=1.45, luff_above_boom_m=3.15, boom_chord_m=2.0,
            head_chord_m=0.8, px_per_m_at_mast=455.0, camera_m=10.0)


def chord_at(f, boom_chord, head_chord):
    return boom_chord + (head_chord - boom_chord) * f


def real_twist(r=REAL):
    """beta at each leech point and the lower and upper mast's lean in the picture."""
    p0 = np.array(r["luff_top"], float)
    clamp = np.array(r["clamp"], float)
    u = (clamp - p0) / np.linalg.norm(clamp - p0)       # down the upper luff
    n = np.array([u[1], -u[0]])                          # square to it, toward the leech
    if n[0] < 0:
        n = -n
    clamp_along = float(np.dot(clamp - p0, u))
    lower = np.array(r["foot"], float) - clamp
    px_per_m_mast = np.linalg.norm(lower) / r["boom_height_m"]
    rows = []
    for q in r["leech"]:
        d = float(np.dot(np.array(q, float) - p0, n))
        h_m = (clamp_along - float(np.dot(np.array(q, float) - p0, u))) / px_per_m_mast
        f = h_m / r["luff_above_boom_m"]
        c = chord_at(f, r["boom_chord_m"], r["head_chord_m"])
        width_m = d / r["px_per_m_at_mast"] * (r["camera_m"] + c) / r["camera_m"]
        beta = math.degrees(math.asin(min(width_m / c, 1.0)))
        rows.append((h_m, f, c, width_m, beta))
    lean_upper = math.degrees(math.atan2(abs(u[0]), u[1]))
    lean_lower = math.degrees(math.atan2(abs(lower[0]), lower[1]))
    return rows, lean_upper, lean_lower


def twist_fit(rows):
    """The head twist that fits the rise of beta with height, for the game's law (twist grows
    as f^1.3 from the boom to the head) and for a straight law (f)."""
    f = np.array([r[1] for r in rows])
    b = np.array([r[4] for r in rows])
    out = {}
    for name, g in (("f^1.3 (the game's)", f ** 1.3), ("straight", f)):
        a = np.vstack([np.ones_like(g), g]).T
        (b0, tau), *_ = np.linalg.lstsq(a, b, rcond=None)
        out[name] = (b0, tau)
    return out


def game_sail_rows(png, mast_px, clamp_px, foot_px, boom_height_m, luff_above_boom_m, boom_chord_m,
                   head_chord_m, camera_m):
    """The game's sail from ahead: for each picture row above the boom, the red cloth's right edge
    (the leech), measured square to the luff line like the real one."""
    from PIL import Image
    img = np.asarray(Image.open(png).convert("RGB")).astype(int)
    red = (img[:, :, 0] > 150) & (img[:, :, 1] < 90) & (img[:, :, 2] < 90)
    p0 = np.array(mast_px, float)
    clamp = np.array(clamp_px, float)
    u = (clamp - p0) / np.linalg.norm(clamp - p0)
    n = np.array([u[1], -u[0]])
    if n[0] < 0:
        n = -n
    clamp_along = float(np.dot(clamp - p0, u))
    px_per_m_mast = np.linalg.norm(np.array(foot_px, float) - clamp) / boom_height_m
    px_per_m_lateral = px_per_m_mast  # the game's mast is short of rake toward the camera here
    rows = []
    for y in range(int(p0[1]) + 5, int(clamp[1]) - 5, 8):
        xs = np.nonzero(red[y])[0]
        if len(xs) == 0:
            continue
        q = np.array([xs.max(), y], float)
        d = float(np.dot(q - p0, n))
        h_m = (clamp_along - float(np.dot(q - p0, u))) / px_per_m_mast
        f = h_m / luff_above_boom_m
        if f <= 0.02 or f >= 0.9:
            continue
        c = chord_at(f, boom_chord_m, head_chord_m)
        width_m = d / px_per_m_lateral * (camera_m + c) / camera_m
        rows.append((h_m, f, c, width_m, math.degrees(math.asin(min(max(width_m / c, 0.0), 1.0)))))
    return rows


def main():
    rows, up, low = real_twist()
    print("Video 07 at 3 s, from ahead (estimates):")
    print("  height above boom m | share of luff | chord m | width m | beta deg")
    for r in rows:
        print("  %8.2f | %5.2f | %5.2f | %5.2f | %5.1f" % r)
    for name, (b0, tau) in twist_fit(rows).items():
        print("  fit %-18s: beta at the boom %.1f deg, twist at the head %.1f deg" % (name, b0, tau))
    print("  mast in the picture: lower part %.1f deg from vertical, upper luff %.1f deg: the top bends %.1f deg to leeward"
          % (low, up, low - up))


def draw_overlay(r=REAL):
    """Video 07's frame with the luff line, the lower mast's line carried on up (the bend), the
    leech points and the sail's angle at each height, for checking by eye and for the doc."""
    import sys
    from PIL import Image, ImageDraw, ImageFont
    sys.path.insert(0, os.path.dirname(__file__))
    from grid_overlay import frame_at
    from video import original, probe
    path = original("07_unknown_front_drone")
    info = probe(path)
    img = frame_at(path, r["t"], info["width"], info["height"]).convert("RGB")
    d = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("arial.ttf", 26)
    except OSError:
        font = ImageFont.load_default()
    rows, up, low = real_twist(r)
    p0, clamp, foot = (np.array(r[k], float) for k in ("luff_top", "clamp", "foot"))
    d.line([tuple(p0), tuple(clamp)], fill=(255, 255, 0), width=4)
    d.line([tuple(clamp), tuple(foot)], fill=(255, 255, 0), width=4)
    extend = clamp + (clamp - foot) / np.linalg.norm(clamp - foot) * np.linalg.norm(clamp - p0)
    d.line([tuple(clamp), tuple(extend)], fill=(0, 255, 255), width=3)
    d.text((extend[0] - 250, extend[1]), "lower mast carried on", fill=(0, 255, 255), font=font)
    u = (clamp - p0) / np.linalg.norm(clamp - p0)
    for q, row in zip(r["leech"], rows):
        q = np.array(q, float)
        base = p0 + u * float(np.dot(q - p0, u))
        d.line([tuple(base), tuple(q)], fill=(255, 80, 80), width=3)
        d.ellipse([q[0] - 8, q[1] - 8, q[0] + 8, q[1] + 8], outline=(255, 40, 40), width=3)
        d.text((q[0] + 12, q[1] - 14), "%.0f deg" % row[4], fill=(255, 255, 255), font=font)
    out = img.crop((330, 40, 1080, 1420))
    out_dir = os.path.join(VIDEOS, "07_unknown_front_drone", "flex")
    os.makedirs(out_dir, exist_ok=True)
    path_out = os.path.join(out_dir, "twist_overlay.png")
    out.save(path_out)
    return path_out


if __name__ == "__main__":
    main()
    print(draw_overlay())
