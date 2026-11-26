"""Where the sailor puts the forces: the body read off video frames by eye, its centre of mass
from body segments, and the forces from the balance; then the whole windsurfer's balance in pitch
and roll, the videos' geometry against the game's.

  python tools/video/sailor_forces.py [--overlays] [--mass 85]

Written 26 November 2026 for the Claude Doc "Windsurf video analysis", tab "The sailor's forces".
Joints are read by eye on labelled grids (tools/video/grid_overlay.py) and checked on the
overlays this script draws (--overlays: <video>/forces/overlay_<t>.png in the videos folder).
Everything here is an estimate from single camera views; the statics turn angles into forces.

The body's mass by segment (Winter 2009, Biomechanics and Motor Control of Human Movement, table
4.1): head and neck 8.1 %, trunk 49.7 % (centre half way from the shoulders to the hips), both
arms 10.0 % (upper arm, forearm and hand; centre about 47 % from the shoulder to the hand), both
thighs 20.0 % (43.3 % from the hip), both shanks 9.3 % (43.3 % from the knee), both feet 2.9 %.
"""

import argparse
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))

G = 9.81
VIDEOS = "C:/Users/Max de Dikke/source/WindsurfingMMZB-videos"

# Joints in the original frame's pixels (x right, y down), read by eye. Front view (07): the
# camera ahead of the board, so the picture's sideways is the board's sideways (windward to the
# left) and its up is up. Both feet overlap from ahead; "ankle" is the front foot's.
FRONT = {
    1.0: dict(head=(233, 972), shoulder=(228, 1060), hip=(252, 1215), hook=(330, 1170),
              boom=(515, 985), hand_f=(483, 955), hand_b=(550, 1022), knee=(480, 1300),
              ankle=(683, 1368), mast_foot=(833, 1300)),
    3.0: dict(head=(240, 975), shoulder=(235, 1060), hip=(262, 1245), hook=(345, 1205),
              boom=(495, 1035), hand_f=(524, 996), hand_b=(515, 1090), knee=(470, 1330),
              ankle=(712, 1415), mast_foot=(867, 1380)),
    5.0: dict(head=(70, 938), shoulder=(60, 1038), hip=(93, 1205), hook=(168, 1138),
              boom=(310, 972), hand_f=(327, 930), hand_b=(393, 1013), knee=(310, 1280),
              ankle=(468, 1367), mast_foot=(660, 1280)),
    7.0: dict(head=(145, 938), shoulder=(128, 1030), hip=(162, 1205), hook=(262, 1130),
              boom=(412, 980), hand_f=(403, 922), hand_b=(487, 997), knee=(362, 1280),
              ankle=(587, 1330), mast_foot=(795, 1280)),
}

# Side view (08, a fly-by from the windward side at water level; the board heads left). The
# board is seen about 50 degrees off square, so lengths along it are foreshortened: angles of
# the body only.
SIDE = {
    2.8: dict(nose=(101, 805), tail=(419, 812), mast_foot=(251, 785), ankle_f=(344, 786),
              ankle_b=(394, 800), knee=(466, 733), hip=(554, 746), hook=(560, 705),
              boom=(501, 655), shoulder=(594, 639), head=(602, 612), hand_f=(477, 602),
              hand_b=(501, 621), mast_at_boom=(410, 541)),
}

SEGMENTS = [  # (mass share, from, to, where along)
    (0.081, "head", "head", 0.0),
    (0.497, "shoulder", "hip", 0.5),
    (0.100, "shoulder", "hands", 0.47),
    (0.200, "hip", "knee", 0.433),
    (0.093, "knee", "ankle", 0.433),
    (0.029, "ankle", "ankle", 0.0),
]


def up(p):
    """Picture pixels to x right, y up."""
    return np.array([p[0], -p[1]], dtype=float)


def centre_of_mass(k):
    pts = {n: up(v) for n, v in k.items()}
    pts["hands"] = 0.5 * (pts["hand_f"] + pts["hand_b"])
    pts.setdefault("ankle", pts.get("ankle_b"))
    com = np.zeros(2)
    for share, a, b, along in SEGMENTS:
        com += share * (pts[a] + along * (pts[b] - pts[a]))
    return com, pts


def cross(a, b):
    return a[0] * b[1] - a[1] * b[0]


def angle_from_vertical(v):
    return math.degrees(math.atan2(abs(v[0]), v[1]))


def front_balance(k, mass):
    """The sideways plane: moments about the feet give the pull along the harness line; the feet
    take the rest. The arms are taken to pull along the lines (the hands sit beside them)."""
    com, p = centre_of_mass(k)
    weight = np.array([0.0, -mass * G])
    feet = p["ankle"]
    u = (p["boom"] - p["hook"]) / np.linalg.norm(p["boom"] - p["hook"])
    pull = -cross(com - feet, weight) / cross(p["hook"] - feet, u)
    feet_force = -(weight + pull * u)          # on the sailor
    trunk_px = np.linalg.norm(p["shoulder"] - p["hip"])
    px_per_m = trunk_px / 0.50                 # shoulder to hip 0.50 m (0.288 x 1.75 m)
    body = com - feet
    return {
        "body_line_deg": angle_from_vertical(body),
        "com_out_m": abs(body[0]) / px_per_m,
        "com_up_m": body[1] / px_per_m,
        "line_up_deg": math.degrees(math.atan2(u[1], abs(u[0]))),
        "hook_to_boom_m": np.linalg.norm(p["boom"] - p["hook"]) / px_per_m,
        "com_to_hands_m": np.linalg.norm(p["hands"] - com) / px_per_m,
        "pull_n": pull,
        "rig_carries_up_n": pull * u[1],
        "feet_up_n": feet_force[1],
        "feet_side_n": abs(feet_force[0]),
        "feet_force_n": float(np.linalg.norm(feet_force)),
        "feet_force_deg": angle_from_vertical(feet_force),
        "leg_deg": angle_from_vertical(p["hip"] - feet),
        "knee_deg": joint_angle(p["hip"], p["knee"], p["ankle"]),
        "rig_lean_deg": None,
        "com_px": com,
    }


def joint_angle(a, b, c):
    """The angle at b between b->a and b->c (180 = straight)."""
    v1, v2 = a - b, c - b
    return math.degrees(math.acos(np.dot(v1, v2) / np.linalg.norm(v1) / np.linalg.norm(v2)))


def side_angles(k):
    com, p = centre_of_mass(k)
    return {
        "knee_deg": joint_angle(p["hip"], p["knee"], p["ankle_b"]),
        "hip_deg": joint_angle(p["shoulder"], p["hip"], p["knee"]),
        "trunk_back_deg": angle_from_vertical(p["shoulder"] - p["hip"]),
        "shank_deg": angle_from_vertical(p["knee"] - p["ankle_b"]),
        "body_line_deg": angle_from_vertical(com - p["ankle_b"]),
        "line_up_deg": math.degrees(math.atan2((p["boom"] - p["hook"])[1], abs((p["boom"] - p["hook"])[0]))),
        "hip_behind_back_foot_px": (p["hip"] - p["ankle_b"])[0],
        "com_px": com,
    }


# --- The whole windsurfer's balance ---------------------------------------------------------
# Positions in metres forward of the tail (x) and up from the hull's bottom (z); the game's
# pitch budget (Game/dev/pitch_budget.gd, 18 kt TWA 100, default gear, the autopilot's rake-first
# hold) gives the forces and the positions of the "game" case.
GAME_18 = dict(sail_fwd=299.8, sail_up=249.5, sail_side=571.5, x_ce=0.08, z_ce=1.57, y_ce=0.47,
               windage_fwd=-69.5, windage_pitch=40.3, fin_up=126.5, fin_drag=47.2, x_fin=0.18,
               z_fin=-0.15, x_push=0.82, wet=0.96, x_sailor=-0.04, z_sailor=0.62, y_sailor=1.05,
               x_mast=1.26, x_rig=0.77, x_hull=1.14, m_sailor=85.0, m_rig=9.5, m_hull=7.8,
               rake_deg=0.69 * 25.0, mast_foot_down=349.8, hands_up=506.1, legs_down=324.5,
               friction=173.7, planing_drag=19.9)


def ce_after_rake(c, rake_deg, z_mast_foot=0.12):
    """The centre of effort swung about the mast foot from the game's rake to another."""
    dx, dz = c["x_ce"] - c["x_mast"], c["z_ce"] - z_mast_foot
    r, a = math.hypot(dx, dz), math.atan2(-dx, dz) + math.radians(rake_deg - c["rake_deg"])
    return c["x_mast"] - r * math.sin(a), z_mast_foot + r * math.cos(a)


def pitch_sum_without_sailor(c, x_push, x_ce, z_ce, fin_up, fin_depth):
    """Pitch moment about the push (+ lifts the bow) of everything but the sailor's weight."""
    m = -c["sail_fwd"] * z_ce + c["sail_up"] * (x_ce - x_push)
    m += c["windage_pitch"]
    m += fin_up * (c["x_fin"] - x_push) - c["fin_drag"] * fin_depth
    m += -c["m_rig"] * G * (c["x_rig"] - x_push) - c["m_hull"] * G * (c["x_hull"] - x_push)
    return m


def sailor_x_needed(c, x_push, rake_deg, fin_up, fin_depth):
    x_ce, z_ce = ce_after_rake(c, rake_deg)
    m = pitch_sum_without_sailor(c, x_push, x_ce, z_ce, fin_up, fin_depth)
    # the sailor's weight at x_s: -W (x_s - x_push) + m = 0
    return x_push + m / (c["m_sailor"] * G), x_ce, z_ce


# --- Side views marked: where the weight acts along the board -----------------------------
# A hiked-out body is up to a metre nearer or farther from the camera than the board, so in a
# side view it shows in the wrong place fore and aft (perspective). So each picture gets the
# board's own scale (from points whose distance from the tail is known: the footstraps 0.235 and
# 0.825 m, the mast foot 1.28 m on the real 62/72 boards and 1.26 m in the game, the nose), and
# where the weight acts is drawn as a plumb line on the board at that scale; the visible body is
# marked separately. Real board 2.33 m (Max: 62 and 72 cm wide slalom boards), game JP SL 72.
SCREENS = "C:/Users/Max de Dikke/source/WindsurfingMMZB-reality/.screenshots/sailor_forces"
EXAMPLES = [
    dict(name="Real 1: video 04 at 12 s, boat beside, board square", video="04_gruissan_defiwind", t=12.0,
         crop=(250, 1150, 1080, 1610), refs=[((780, 1515), 1.28), ((1025, 1478), 2.33)],
         body={"shoulder (through the sail)": (400, 1310), "head": (440, 1245)},
         wet=None, needed_for=(0.5, 0.7), ce=True,
         note="tail in the spray; the mast foot falls 1.28 m from the tail by this scale"),
    dict(name="Real 2: video 04 at 6 s, close beside", video="04_gruissan_defiwind", t=6.0,
         crop=(250, 880, 1080, 1100), refs=[((505, 985), 0.235), ((670, 975), 0.825), ((822, 980), 1.28)],
         body={}, wet=((610, 1018), (640, 1016)), needed_for=None, ce=False,
         note="scale from the two footstraps and the mast foot"),
    dict(name="Real 3: video 06 at 11 s, boat beside (board heads left)", video="06_unknown_crosswind_boat",
         t=11.0, crop=(0, 1380, 620, 1560), refs=[((253, 1467), 1.28), ((42, 1433), 2.33)],
         body={}, wet=((410, 1497), (380, 1493)), needed_for=None, ce=False,
         note="scale from the mast foot and the nose"),
    dict(name="Real 4: video 08 at 2.8 s, fly-by from windward (board 50 deg off square)",
         video="08_bonaire_flyby", t=2.8, crop=(40, 500, 720, 850),
         refs=[((419, 812), 0.0), ((251, 785), 1.28), ((101, 805), 2.33)],
         body={"back foot": (394, 800), "knee": (466, 733), "hip": (554, 746), "shoulder": (594, 639),
               "head": (602, 612)}, wet=None, needed_for=None, ce=False, oblique=True,
         note="oblique: the hike to windward shows as fore and aft; body angles only"),
    dict(name="Game 1: 18 kt beam reach, leeward side (as video 04)", screen="rig_starboard_port_close_18kt.png",
         crop=(560, 120, 1700, 900), refs=[((1325, 815), 0.0), ((895, 785), 1.26)], body={},
         game=dict(wet=0.96, push=0.82, com=-0.04, ce=(0.08, 1.57)), needed_for=(0.5, 0.7), ce=True,
         note="the game's numbers from its pitch budget; the straps fall 0.24 and 0.83 m from the tail"),
    dict(name="Game 2: 24 kt beam reach, leeward side", screen="rig_starboard_port_close_24kt.png",
         crop=(540, 300, 1680, 920), refs=[((1300, 848), 0.0), ((880, 775), 1.26)], body={},
         game=dict(wet=0.95, push=0.81, com=-0.13, ce=(0.13, 1.59)), needed_for=(0.5, 0.7), ce=False,
         note="the game's numbers from its pitch budget at 24 kt"),
    dict(name="Game 3: 18 kt beam reach, windward side (as video 08)", screen="rig_starboard_starboard_close_18kt.png",
         crop=(330, 330, 1440, 900), refs=[((595, 822), 0.0), ((1022, 788), 1.26)], body={},
         game=dict(wet=0.96, push=0.82, com=-0.04, ce=(0.08, 1.57)), needed_for=(0.5, 0.7), ce=False,
         note="the figure hikes toward the camera, so it shows further aft than it is"),
]


def board_axis(refs):
    """The board's line in the picture: the tail's point and the pixels per metre along it (and
    its direction), fitted through the reference points."""
    m = np.array([r[1] for r in refs])
    p = np.array([r[0] for r in refs], dtype=float)
    a = np.vstack([np.ones_like(m), m]).T
    coef, *_ = np.linalg.lstsq(a, p, rcond=None)   # p = tail + m * per_m
    tail, per_m = coef[0], coef[1]
    up = np.array([per_m[1], -per_m[0]])
    if up[1] > 0:
        up = -up
    up = up / np.linalg.norm(up) * np.linalg.norm(per_m)   # a metre up, square to the board
    return tail, per_m, up


def needed_band(wet_lo, wet_hi):
    """Where the sailor's centre of mass must be (m from the tail) for a wet length, real rake 31,
    the fin pushing 30 to 126 N: the whole band over the wet lengths given."""
    c = GAME_18
    xs = []
    for wet in (wet_lo, wet_hi):
        for fin in (30.0, c["fin_up"]):
            xs.append(sailor_x_needed(c, wet * c["x_push"] / c["wet"], 31.0, fin, -c["z_fin"])[0])
    return min(xs), max(xs)


def draw_example(ex):
    from PIL import Image, ImageDraw, ImageFont
    if "screen" in ex:
        img = Image.open(os.path.join(SCREENS, ex["screen"])).convert("RGB")
    else:
        from grid_overlay import frame_at
        from video import original, probe
        path = original(ex["video"])
        info = probe(path)
        img = frame_at(path, ex["t"], info["width"], info["height"]).convert("RGB")
    d = ImageDraw.Draw(img, "RGBA")
    try:
        font = ImageFont.truetype("arial.ttf", 18)
        small = ImageFont.truetype("arial.ttf", 15)
    except OSError:
        font = small = ImageFont.load_default()
    tail, per_m, up = board_axis(ex["refs"])
    at = lambda m, h=0.0: tuple(tail + m * per_m + h * up)
    blue, orange, white, red = (40, 140, 255, 255), (255, 120, 20, 255), (255, 255, 255, 255), (255, 40, 40, 255)
    # the board's line and a tick every half metre from the tail
    d.line([at(-0.6), at(2.4)], fill=(255, 255, 255, 170), width=2)
    for k in range(-1, 5):
        mm = 0.5 * k
        d.line([at(mm, -0.06), at(mm, 0.06)], fill=white, width=3)
        d.text(at(mm, -0.16), ("tail" if mm == 0 else "%.1f m" % mm), fill=white, font=small, anchor="mm")
    for (p, mm) in ex["refs"]:
        d.ellipse([p[0] - 7, p[1] - 7, p[0] + 7, p[1] + 7], outline=(255, 255, 0, 255), width=3)
    lines = [ex["name"], ex["note"]]
    if ex.get("wet"):
        # the front of the wet part, read on the picture, as metres from the tail
        ms = [float(np.dot(np.array(p) - tail, per_m) / np.dot(per_m, per_m)) for p in ex["wet"]]
        lo, hi = min(ms), max(ms)
        d.line([at(0.0, -0.04), at(lo, -0.04)], fill=blue, width=9)
        d.line([at(lo, -0.04), at(hi, -0.04)], fill=(40, 140, 255, 120), width=9)
        lines.append("wet part, read here: 0 to %.2f-%.2f m from the tail" % (lo, hi))
        x0, x1 = needed_band(lo, hi)
        lines.append("weight must act %.2f to %.2f m behind the tail for it (balance, rake 31 deg)" % (-x1, -x0))
        ex = dict(ex, needed_for=None, band=(x0, x1))
    if ex.get("needed_for"):
        x0, x1 = needed_band(*ex["needed_for"])
        ex = dict(ex, band=(x0, x1))
        lines.append("blue: where the weight must act for %.1f-%.1f m wet (videos): %.2f to %.2f m behind the tail"
                     % (ex["needed_for"][0], ex["needed_for"][1], -x1, -x0))
    if ex.get("band"):
        x0, x1 = ex["band"]
        poly = [at(x0, 0.0), at(x1, 0.0), at(x1, 0.75), at(x0, 0.75)]
        d.polygon(poly, fill=(40, 140, 255, 70), outline=blue)
        d.text(at(0.5 * (x0 + x1), 0.85), "weight needed", fill=blue, font=font, anchor="mm")
    g = ex.get("game")
    if g:
        d.line([at(0.0, -0.04), at(g["wet"], -0.04)], fill=orange, width=9)
        d.line([at(g["com"], 0.0), at(g["com"], 0.75)], fill=orange, width=4)
        d.ellipse([at(g["com"], 0.62)[0] - 8, at(g["com"], 0.62)[1] - 8, at(g["com"], 0.62)[0] + 8,
                   at(g["com"], 0.62)[1] + 8], outline=orange, width=4)
        d.text(at(g["com"] + 0.05, 0.62), " game's weight", fill=orange, font=font, anchor="lm")
        px, py = at(g["push"], -0.45)
        qx, qy = at(g["push"], -0.07)
        d.line([(px, py), (qx, qy)], fill=orange, width=4)
        d.polygon([(qx, qy - 2), (qx - 7, qy + 12), (qx + 7, qy + 12)], fill=orange)
        lines.append("orange, the game: wet %.2f m, water's push %.2f m, weight %.2f m from the tail"
                     % (g["wet"], g["push"], g["com"]))
    if ex.get("ce"):
        for (x, z), col, txt in (((-0.23, 1.25), blue, "CE at 31 deg rake"), ((0.08, 1.57), orange, "CE at 17 deg (game)")):
            cx, cy = at(x, z)
            d.line([(cx - 9, cy - 9), (cx + 9, cy + 9)], fill=col, width=4)
            d.line([(cx - 9, cy + 9), (cx + 9, cy - 9)], fill=col, width=4)
            d.text((cx + 12, cy), txt, fill=col, font=small, anchor="lm")
    for n, p in ex["body"].items():
        d.ellipse([p[0] - 7, p[1] - 7, p[0] + 7, p[1] + 7], outline=red, width=3)
        d.text((p[0] + 10, p[1] - 10), n, fill=red, font=small)
    crop = img.crop(ex["crop"])
    w = 980
    crop = crop.resize((w, int(crop.height * w / crop.width)))
    band_h = 26 * len(lines) + 10
    out = Image.new("RGB", (w, crop.height + band_h), (20, 20, 24))
    out.paste(crop, (0, 0))
    dd = ImageDraw.Draw(out)
    for i, line in enumerate(lines):
        dd.text((12, crop.height + 8 + 26 * i), line, fill=(235, 235, 235), font=font if i == 0 else small)
    return out, lines


def draw_examples():
    from PIL import Image
    out_dir = os.path.join(SCREENS, "examples")
    os.makedirs(out_dir, exist_ok=True)
    pics = []
    for i, ex in enumerate(EXAMPLES):
        pic, lines = draw_example(ex)
        pic.save(os.path.join(out_dir, "example_%d.png" % (i + 1)))
        pics.append(pic)
        print(" | ".join(lines))
    for name, group in (("real", pics[:4]), ("game", pics[4:])):
        h = sum(p.height for p in group)
        sheet = Image.new("RGB", (group[0].width, h), (20, 20, 24))
        y = 0
        for p in group:
            sheet.paste(p, (0, y))
            y += p.height
        sheet.save(os.path.join(out_dir, "sheet_%s.png" % name))
    print("examples in", out_dir)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--overlays", action="store_true")
    ap.add_argument("--examples", action="store_true", help="the side views marked (SCREENS/examples)")
    ap.add_argument("--mass", type=float, default=85.0)
    a = ap.parse_args()

    print("== Front view (07): the sideways plane, %.0f kg ==" % a.mass)
    keys = ["body_line_deg", "com_out_m", "com_up_m", "line_up_deg", "hook_to_boom_m", "com_to_hands_m",
            "pull_n", "rig_carries_up_n", "feet_up_n", "feet_side_n", "feet_force_n", "feet_force_deg",
            "leg_deg", "knee_deg"]
    rows = {t: front_balance(k, a.mass) for t, k in FRONT.items()}
    print("%-18s" % "" + "".join("%9s" % ("t=%.0f" % t) for t in rows) + "   median")
    for key in keys:
        vals = [rows[t][key] for t in rows]
        print("%-18s" % key + "".join("%9.2f" % v for v in vals) + "%9.2f" % float(np.median(vals)))

    print("\n== Side view (08): angles ==")
    for t, k in SIDE.items():
        s = side_angles(k)
        print("t=%.1f " % t + "  ".join("%s %.1f" % (n, v) for n, v in s.items() if n != "com_px"))

    print("\n== The whole windsurfer in pitch: where must the sailor's centre of mass be? ==")
    c = GAME_18
    x_s, x_ce, z_ce = sailor_x_needed(c, c["x_push"], c["rake_deg"], c["fin_up"], -c["z_fin"])
    print("game check: rake %.1f, push %.2f -> sailor at %.2f m (the game has %.2f), CE x %.2f z %.2f"
          % (c["rake_deg"], c["x_push"], x_s, c["x_sailor"], x_ce, z_ce))
    print("%6s %6s %6s %7s | %8s %8s %8s" % ("rake", "wet", "push", "fin up", "CE x", "CE z", "sailor x"))
    for rake in (c["rake_deg"], 25.0, 31.0, 35.0):
        for wet in (0.96, 0.7, 0.6, 0.5):
            x_push = wet * c["x_push"] / c["wet"]   # the push at the game's share of the wet length
            for fin_up in (c["fin_up"], 30.0):
                x_s, x_ce, z_ce = sailor_x_needed(c, x_push, rake, fin_up, -c["z_fin"])
                print("%6.1f %6.2f %6.2f %7.0f | %8.2f %8.2f %8.2f" % (rake, wet, x_push, fin_up, x_ce, z_ce, x_s))

    print("\n== The whole windsurfer in roll (about the board's centreline at the bottom) ==")
    # + heels to windward (the sailor's side). The sail's side force to leeward high up and the
    # fin's to windward below make the heeling couple; the weights and the sail's lift right it.
    heel = -c["sail_side"] * c["z_ce"] - c["sail_side"] * (-c["z_fin"])
    lift = -c["sail_up"] * c["y_ce"]          # an upward pull on the windward side lifts it
    rig = c["m_rig"] * G * c["y_ce"] * 0.9    # the rig's weight about where it leans (estimate)
    y_needed = -(heel + lift + rig) / (c["m_sailor"] * G)
    print("heeling couple %.0f N m, sail lift at the CE %.0f, rig weight %.0f -> sailor %.2f m to windward "
          "of the centreline (the game has %.2f)" % (heel, lift, rig, y_needed, c["y_sailor"]))

    if a.overlays:
        draw_overlays(rows, a.mass)
    if a.examples:
        draw_examples()


def draw_overlays(rows, mass):
    from PIL import Image, ImageDraw
    from grid_overlay import frame_at
    from video import original, probe
    path = original("07_unknown_front_drone")
    info = probe(path)
    w, h = info["width"], info["height"]
    out_dir = os.path.join(VIDEOS, "07_unknown_front_drone", "forces")
    os.makedirs(out_dir, exist_ok=True)
    for t, k in FRONT.items():
        img = frame_at(path, t, w, h).convert("RGB")
        d = ImageDraw.Draw(img)
        chain = ["head", "shoulder", "hip", "knee", "ankle"]
        for a_, b_ in zip(chain, chain[1:]):
            d.line([k[a_], k[b_]], fill=(255, 255, 0), width=4)
        d.line([k["shoulder"], k["hand_f"]], fill=(255, 200, 0), width=3)
        d.line([k["shoulder"], k["hand_b"]], fill=(255, 200, 0), width=3)
        d.line([k["hook"], k["boom"]], fill=(0, 255, 255), width=4)
        for n, p in k.items():
            d.ellipse([p[0] - 7, p[1] - 7, p[0] + 7, p[1] + 7], outline=(255, 0, 0), width=3)
            d.text((p[0] + 9, p[1] - 9), n, fill=(255, 255, 255))
        com = rows[t]["com_px"]
        cx, cy = com[0], -com[1]
        d.ellipse([cx - 12, cy - 12, cx + 12, cy + 12], outline=(255, 0, 255), width=4)
        d.text((cx + 14, cy), "CoM", fill=(255, 0, 255))
        d.line([k["ankle"], (cx, cy)], fill=(255, 0, 255), width=2)
        crop = img.crop((0, 820, 1000, 1500))
        crop.save(os.path.join(out_dir, "overlay_%04.1f.png" % t))
    print("overlays in", out_dir)


if __name__ == "__main__":
    main()
