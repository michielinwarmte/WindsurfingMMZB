"""The wind tunnel's wake, read the way the game uses it (PH15): what a board behind another feels, and the game's
shadow numbers (Game/config/wind_shadow_default.tres) fitted to it.

What the tunnel gives: the time-averaged wind around and behind the rig, in the tunnel frame (X along the caster's
apparent wind at its sail, Y across, Z up). Less the undisturbed inflow, that is the DISTURBANCE: the change the
rig makes to the air, the same seen from any board. What another board feels depends on its own speed:

- a board at the caster's speed and course (two boards on the same reach, the trail's usual case): its apparent wind
  is the caster's inflow plus the disturbance;
- a board at rest (a board waiting on the line): its apparent wind is the true wind plus the disturbance.

Both are averaged over a sail's height the way the sail's area is spread (a sail feels its whole height, not one
point). The game's model has one number: the share of the TRUE wind left at a point (WindShadows.factor_at()).
So for each case it is turned into that share: the factor on the true wind that gives the follower the same
apparent wind strength (f_same for the follower at the caster's speed, f_rest for the board at rest).

Then: the wake's axis and its bend toward the caster's stern, the deficit along it, its width, its edge (PH42: how
quickly the wind comes back across it), the gustiness in it, and the game's six numbers fitted.

  python -I tools/cfd/analyse_wake.py [--cases=reach_18_100,...] [--dir=.sim_output/cfd] [--dx=10]
Writes <case>_wake.json and the pictures <case>_*.png next to the tunnel's results.
"""
import glob
import json
import math
import os
import sys
import zlib
import struct

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rig_shape  # noqa: E402

WIND_SHEAR_EXPONENT = 0.11
WIND_MIN_HEIGHT_M = 0.1
# The game's shadow now (Game/config/wind_shadow_default.tres, 13 November 2026).
GAME_NOW = {"deficit": 0.3, "full_until_m": 5.0, "length_m": 20.0, "half_width_m": 2.5, "spread_deg": 8.0,
            "stern_bend_deg": 7.0}
# The proposal (wind_tunnel.md section 7, option A): only the strength and the bend change, the length stays Max's
# 20 m (a longer trail costs CPU) and the widths match the tunnel's within it.
GAME_PROPOSED = {"deficit": 0.075, "full_until_m": 1.0, "length_m": 20.0, "half_width_m": 2.5, "spread_deg": 8.0,
                 "stern_bend_deg": 3.0}


# --- Reading a case --------------------------------------------------------------------------------------

def load(stem: str):
    with open(stem + ".json") as handle:
        meta = json.load(handle)
    data = np.load(stem + ".npz")
    return meta, data["u_mean"].astype(np.float32), data["fluct"].astype(np.float32)


def sail_height_weights(meta: dict, nz: int, dx: float) -> np.ndarray:
    """How a following sail's area is spread over height (an upright rig on a board like the caster's)."""
    heights = (np.arange(nz) + 0.5) * dx
    foot = rig_shape.BOARD_COM_ABOVE_WATER_M + rig_shape.MAST_FOOT_BODY[1]
    s = heights - foot
    inside = (s >= rig_shape.TACK_ABOVE_FOOT_M) & (s <= rig_shape.head_height_m())
    weights = np.where(inside, rig_shape.chord_m(np.clip(s, 0, None)), 0.0)
    return weights / weights.sum()


def true_wind_profile(meta: dict, nz: int, dx: float) -> np.ndarray:
    """The true wind at each height, tunnel frame (2, nz): the game's gradient through the sail's true wind."""
    heights = (np.arange(nz) + 0.5) * dx
    gradient = (np.maximum(heights, WIND_MIN_HEIGHT_M) / meta["info"]["z_ce_m"]) ** WIND_SHEAR_EXPONENT
    w = np.array(meta["info"]["true_wind_tunnel_ms"])
    return w[:, None] * gradient[None, :]


# --- What a board behind feels ---------------------------------------------------------------------------

def follower_maps(meta: dict, u_mean: np.ndarray) -> dict:
    """Maps (nx, ny) of what another board feels at each place: f_same, f_rest (the game's equivalent shares of
    the true wind), the change of its apparent wind's direction (degrees, + = the wind comes from further
    toward the caster's leeward), and the loss of apparent wind speed for the follower at the caster's speed."""
    dx = meta["dx_m"]
    nz = u_mean.shape[3]
    w = sail_height_weights(meta, nz, dx)
    band = w > 0
    wz = w[band]
    inflow = np.array(meta["info"]["inflow_ms"])[:2][:, band]  # (2, nzb) the caster's apparent wind
    true = true_wind_profile(meta, nz, dx)[:, band]
    board_v = np.array(meta["info"]["board_velocity_tunnel_ms"])
    u = np.nan_to_num(u_mean[:2, :, :, band])  # (2, nx, ny, nzb) the measured wind in the caster's frame
    disturbance = u - inflow[:, None, None, :]
    # The follower at the caster's speed: its apparent wind is the measured wind.
    s_d = (u[0] ** 2 + u[1] ** 2) @ wz
    s_0 = float(((inflow ** 2).sum(0)) @ wz)
    apparent_speed_share = np.sqrt(s_d / s_0)
    # Its direction change, weighted; sign: + toward the caster's leeward side in the tunnel frame.
    lee = np.array(meta["info"]["leeward_tunnel"])
    cross = inflow[0][None, None, :] * u[1] - inflow[1][None, None, :] * u[0]
    dot = inflow[0][None, None, :] * u[0] + inflow[1][None, None, :] * u[1]
    angle = np.degrees(np.arctan2(cross, dot)) @ wz
    # The air turning toward +Y moves the wind's "from" direction toward -Y: + = from further to leeward.
    direction_change = -angle * np.sign(lee[1]) if abs(lee[1]) > 1e-6 else -angle
    # The game's share of the TRUE wind that gives the follower the same apparent wind strength:
    # |f W(z) - V|^2 averaged = s_d  ->  a f^2 + b f + c = 0.
    a = float(((true ** 2).sum(0)) @ wz)
    b = float(-2.0 * ((true[0] * board_v[0] + true[1] * board_v[1]) @ wz))
    c = float(board_v @ board_v) - s_d
    disc = np.maximum(b * b - 4 * a * c, 0.0)
    f_same = (-b + np.sqrt(disc)) / (2 * a)
    # The board at rest: its apparent wind is the true wind plus the disturbance.
    rest = true[:, None, None, :] + disturbance
    f_rest = np.sqrt(((rest[0] ** 2 + rest[1] ** 2) @ wz) / float(((true ** 2).sum(0)) @ wz))
    # The true wind's own turn there (what a board at rest feels, and what the game would turn if its shadow turned
    # the wind): + the wind from further toward the caster's leeward, as above.
    cross_t = true[0][None, None, :] * rest[1] - true[1][None, None, :] * rest[0]
    dot_t = true[0][None, None, :] * rest[0] + true[1][None, None, :] * rest[1]
    angle_t = np.degrees(np.arctan2(cross_t, dot_t)) @ wz
    turn_rest = -angle_t * np.sign(lee[1]) if abs(lee[1]) > 1e-6 else -angle_t
    # The wake itself: the air slowed along the caster's apparent wind, as a share of it (the marker for its axis
    # and width; the same for every follower).
    slowed = -(disturbance[0] @ wz) / pose_aws(meta)
    return {"f_same": f_same, "f_rest": f_rest, "direction_change_deg": direction_change, "turn_rest_deg": turn_rest,
            "apparent_speed_share": apparent_speed_share, "slowed": slowed}


def pose_aws(meta: dict) -> float:
    return meta["pose"]["aws_ms"]


# --- The wake's shape ------------------------------------------------------------------------------------

def coordinates(meta: dict):
    dx = meta["dx_m"]
    x = meta["x0_m"] + (np.arange(meta["nx"]) + 0.5) * dx
    y = meta["y0_m"] + (np.arange(meta["ny"]) + 0.5) * dx
    return x, y


def sample(field: np.ndarray, meta: dict, px: np.ndarray, py: np.ndarray) -> np.ndarray:
    """Bilinear sample of an (nx, ny) map at tunnel points."""
    dx = meta["dx_m"]
    fi = (px - meta["x0_m"]) / dx - 0.5
    fj = (py - meta["y0_m"]) / dx - 0.5
    i0 = np.clip(np.floor(fi).astype(int), 0, meta["nx"] - 2)
    j0 = np.clip(np.floor(fj).astype(int), 0, meta["ny"] - 2)
    ti = np.clip(fi - i0, 0, 1)
    tj = np.clip(fj - j0, 0, 1)
    return (field[i0, j0] * (1 - ti) * (1 - tj) + field[i0 + 1, j0] * ti * (1 - tj)
            + field[i0, j0 + 1] * (1 - ti) * tj + field[i0 + 1, j0 + 1] * ti * tj)


def wake_axis(slowed: np.ndarray, meta: dict) -> dict:
    """The wake's line: at each distance behind the rig the centre of the slowed air across it (its positive part,
    within 8 m of the line so far), and the straight line through those centres (its angle off the apparent wind,
    + toward the caster's stern)."""
    x, y = coordinates(meta)
    rows = []
    centre = 0.0
    for xi in np.arange(1.0, min(40.0, x[-1] - 3.5), 1.0):
        i = int(np.argmin(np.abs(x - xi)))
        near = np.abs(y - centre) < 8.0
        profile = np.clip(np.nan_to_num(slowed[i]), 0.0, None) * near
        if profile.sum() <= 0:
            continue
        centre = float((profile * y).sum() / profile.sum())
        spread = float(np.sqrt((profile * (y - centre) ** 2).sum() / profile.sum()))
        rows.append((float(x[i]), centre, float(profile.max()), spread))
    rows = np.array(rows)
    use = (rows[:, 0] >= 3.0) & (rows[:, 0] <= 30.0)
    weights = rows[use, 2]
    slope = float((weights * rows[use, 0] * rows[use, 1]).sum() / (weights * rows[use, 0] ** 2).sum())
    stern = -np.array(meta["info"]["bow_tunnel"])
    toward_stern = 1.0 if np.sign(slope) == np.sign(stern[1]) else -1.0
    return {"points": rows.tolist(), "slope": slope,
            "bend_toward_stern_deg": float(toward_stern * math.degrees(math.atan(abs(slope))))}


def along_across(deficit: np.ndarray, meta: dict, slope: float, distances, sides):
    """The deficit on a grid of distances along the wake's straight axis and sides across it."""
    angle = math.atan(slope)
    d, s = np.meshgrid(distances, sides, indexing="ij")
    px = d * math.cos(angle) - s * math.sin(angle)
    py = d * math.sin(angle) + s * math.cos(angle)
    return sample(deficit, meta, px, py)


def edge_width(profile: np.ndarray, sides: np.ndarray) -> float:
    """How far across the wake the deficit takes to fall from 90 % to 10 % of its middle's, the mean of both
    sides (m): the sharpness of the shadow's edge."""
    peak_index = int(np.argmax(profile))
    peak = profile[peak_index]
    if peak <= 0.005:
        return float("nan")
    widths = []
    for direction in (1, -1):
        idx = np.arange(peak_index, len(profile) if direction == 1 else -1, direction)
        vals = profile[idx]
        dist = np.abs(sides[idx] - sides[peak_index])
        try:
            at90 = np.interp(0.9 * peak, vals[::-1], dist[::-1]) if np.all(np.diff(vals) <= 0) else \
                dist[np.argmax(vals < 0.9 * peak)]
            at10 = dist[np.argmax(vals < 0.1 * peak)] if np.any(vals < 0.1 * peak) else float("nan")
            widths.append(at10 - at90)
        except ValueError:
            pass
    return float(np.nanmean(widths)) if widths else float("nan")


# --- The game's model, and its fit -----------------------------------------------------------------------

def game_model(d: np.ndarray, s: np.ndarray, deficit, full_until_m, length_m, half_width_m, spread_deg) -> np.ndarray:
    """WindShadows' cone, by distance down the wake and side across it (wind_shadows.gd factor_at())."""
    width = half_width_m + d * math.tan(math.radians(spread_deg))
    strength = np.where(d > full_until_m, 1.0 - (d - full_until_m) / max(length_m - full_until_m, 1e-6), 1.0)
    share = np.abs(s) / width
    value = deficit * strength * (1.0 - share * share)
    return np.where((d > 0) & (d < length_m) & (np.abs(s) < width), value, 0.0)


def fit_game(grid_deficit: np.ndarray, distances: np.ndarray, sides: np.ndarray) -> dict:
    """The game's five shape numbers that come closest to the measured deficit (least squares on the grid of
    distances and sides; a coarse search, then a finer one around the best)."""
    d, s = np.meshgrid(distances, sides, indexing="ij")
    target = np.nan_to_num(grid_deficit)
    ranges = {"deficit": np.linspace(0.02, 0.6, 30), "full_until_m": np.linspace(0, 20, 11),
              "length_m": np.linspace(6, 60, 19), "half_width_m": np.linspace(0.5, 6, 12),
              "spread_deg": np.linspace(0, 20, 11)}
    best = None
    for _ in range(2):
        for full in ranges["full_until_m"]:
            for length in ranges["length_m"]:
                if length <= full:
                    continue
                for hw in ranges["half_width_m"]:
                    for spread in ranges["spread_deg"]:
                        shape = game_model(d, s, 1.0, full, length, hw, spread)
                        denom = float((shape * shape).sum())
                        if denom <= 0:
                            continue
                        deficit = float(np.clip((shape * target).sum() / denom, 0, 1))  # best deficit for this shape
                        err = float(((deficit * shape - target) ** 2).sum())
                        if best is None or err < best[0]:
                            best = (err, deficit, full, length, hw, spread)
        _, deficit, full, length, hw, spread = best
        ranges = {"deficit": None,
                  "full_until_m": np.linspace(max(full - 2, 0), full + 2, 9),
                  "length_m": np.linspace(max(length - 3, 4), length + 3, 13),
                  "half_width_m": np.linspace(max(hw - 0.5, 0.2), hw + 0.5, 11),
                  "spread_deg": np.linspace(max(spread - 2, 0), spread + 2, 9)}
    err, deficit, full, length, hw, spread = best
    total = float((target ** 2).sum())
    return {"deficit": deficit, "full_until_m": full, "length_m": length, "half_width_m": hw, "spread_deg": spread,
            "explained_share": 1.0 - err / total if total > 0 else 0.0}


def game_error(grid_deficit: np.ndarray, distances, sides, numbers: dict) -> float:
    d, s = np.meshgrid(distances, sides, indexing="ij")
    target = np.nan_to_num(grid_deficit)
    model = game_model(d, s, numbers["deficit"], numbers["full_until_m"], numbers["length_m"],
                       numbers["half_width_m"], numbers["spread_deg"])
    total = float((target ** 2).sum())
    return 1.0 - float(((model - target) ** 2).sum()) / total if total > 0 else 0.0


# --- The shadow as bell curves across it (robust in gusty air) -------------------------------------------

def bell_fit(profile: np.ndarray, sides: np.ndarray, centre_guess: float):
    """The bell curve a exp(-(s - c)^2 / 2 sigma^2) + b closest to a profile across the wake (b: the background,
    the gusts' leftover noise): (a, c, sigma, b). A search over the centre and width, a and b solved directly."""
    p = np.nan_to_num(profile)
    best = None
    for c in np.arange(centre_guess - 2.0, centre_guess + 2.01, 0.1):
        for sigma in np.arange(0.3, 6.01, 0.05):
            g = np.exp(-0.5 * ((sides - c) / sigma) ** 2)
            design = np.stack([g, np.ones_like(g)], 1)
            coef = np.linalg.lstsq(design, p, rcond=None)[0]
            err = float(((design @ coef - p) ** 2).sum())
            if best is None or err < best[0]:
                best = (err, float(coef[0]), float(c), float(sigma), float(coef[1]))
    return best[1:]


def shadow_line(deficit_rest: np.ndarray, meta: dict) -> dict:
    """At each metre behind the rig (along the apparent wind) the bell curve across the at-rest deficit: its
    strength above the background, centre and width; and the straight line through the centres (its angle off the
    apparent wind, + toward the caster's stern)."""
    x, y = coordinates(meta)
    rows = []
    centre = 0.5
    for xi in np.arange(1.0, min(41.0, x[-1] - 3.5), 1.0):
        i = int(np.argmin(np.abs(x - xi)))
        near = np.abs(y - centre) <= 8.0
        a, c, sigma, b = bell_fit(deficit_rest[i, near], y[near], centre)
        if a > 0.002:
            centre = c
        rows.append({"distance_m": float(x[i]), "strength": a, "centre_m": c, "sigma_m": sigma, "background": b})
    use = [r for r in rows if 3.0 <= r["distance_m"] <= 35.0 and r["strength"] > 0.002]
    w = np.array([r["strength"] for r in use])
    d = np.array([r["distance_m"] for r in use])
    c = np.array([r["centre_m"] for r in use])
    design = np.stack([np.ones_like(d), d], 1) * w[:, None]
    offset, slope = np.linalg.lstsq(design, c * w, rcond=None)[0]
    stern = -np.array(meta["info"]["bow_tunnel"])
    toward_stern = 1.0 if np.sign(slope) == np.sign(stern[1]) else -1.0
    return {"rows": rows, "slope": float(slope), "offset_m": float(offset),
            "bend_toward_stern_deg": float(toward_stern * math.degrees(math.atan(abs(slope))))}


def game_numbers_from_bells(rows: list) -> dict:
    """The game's numbers that match the bell curves: its parabola (1 - (s / w)^2) as wide at half strength as the
    bell (w = 1.665 sigma), w = half_width_m + distance tan(spread) fitted along 3 to 35 m; its strength (deficit,
    full until full_until_m, then straight to nothing at length_m) fitted to the bells' strength along 2 to 40 m."""
    use = [r for r in rows if 3.0 <= r["distance_m"] <= 35.0 and r["strength"] > 0.002]
    d = np.array([r["distance_m"] for r in use])
    w = 1.665 * np.array([r["sigma_m"] for r in use])
    design = np.stack([np.ones_like(d), d], 1)
    half_width, growth = np.linalg.lstsq(design, w, rcond=None)[0]
    along = [r for r in rows if 2.0 <= r["distance_m"] <= 40.0]
    dd = np.array([r["distance_m"] for r in along])
    aa = np.array([max(r["strength"], 0.0) for r in along])
    best = None
    for full in np.arange(0.0, 20.01, 0.5):
        for length in np.arange(max(full + 2.0, 6.0), 90.01, 1.0):
            shape = np.where(dd <= full, 1.0, np.clip(1.0 - (dd - full) / (length - full), 0.0, None))
            deficit = float((shape * aa).sum() / (shape * shape).sum())
            err = float(((deficit * shape - aa) ** 2).sum())
            if best is None or err < best[0]:
                best = (err, deficit, full, length)
    total = float(((aa - aa.mean()) ** 2).sum())
    return {"deficit": best[1], "full_until_m": best[2], "length_m": best[3], "half_width_m": float(half_width),
            "spread_deg": float(math.degrees(math.atan(growth))), "strength_fit_explains": 1.0 - best[0] / total}


# --- Pictures (no plotting library in the venv: a small PNG writer) --------------------------------------

def write_png(path: str, rgb: np.ndarray) -> None:
    h, w, _ = rgb.shape
    raw = b"".join(b"\x00" + rgb[row].astype(np.uint8).tobytes() for row in range(h))

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as handle:
        handle.write(png)


def colour(values: np.ndarray, low: float, high: float) -> np.ndarray:
    """Blue (low, less than nothing: more wind) through white (0) to red (high)."""
    stops = np.array([[33, 102, 172], [146, 197, 222], [247, 247, 247], [244, 165, 130], [178, 24, 43], [103, 0, 31]],
                     dtype=float)
    positions = np.array([low, low / 2, 0.0, high / 3, 2 * high / 3, high])
    v = np.nan_to_num(values, nan=0.0)
    out = np.zeros(v.shape + (3,))
    for k in range(3):
        out[..., k] = np.interp(v, positions, stops[:, k])
    out[np.isnan(values)] = [60, 60, 60]
    return out


def map_picture(path: str, field: np.ndarray, meta: dict, low: float, high: float, outlines=()) -> None:
    """A map seen from above: the apparent wind blows left to right, grid lines every 5 m, the mast foot a black
    dot, the outlines (game cones) in black and dark green; 2 pixels per cell at 10 cm cells."""
    x, y = coordinates(meta)
    keep_x = (x >= -5) & (x <= 45)
    keep_y = (y >= -12) & (y <= 12)
    sub = field[np.ix_(keep_x, keep_y)]
    rgb = colour(sub, low, high)
    xs, ys = x[keep_x], y[keep_y]
    for value in np.arange(-5, 46, 5):
        i = int(np.argmin(np.abs(xs - value)))
        rgb[i, :] = rgb[i, :] * 0.6 + 60
    for value in np.arange(-10, 11, 5):
        j = int(np.argmin(np.abs(ys - value)))
        rgb[:, j] = rgb[:, j] * 0.6 + 60
    for line_colour, mask in outlines:
        m = mask[np.ix_(keep_x, keep_y)]
        edge = m & ~(np.roll(m, 1, 0) & np.roll(m, -1, 0) & np.roll(m, 1, 1) & np.roll(m, -1, 1))
        rgb[edge] = line_colour
    i0 = int(np.argmin(np.abs(xs))); j0 = int(np.argmin(np.abs(ys)))
    rgb[max(i0 - 2, 0):i0 + 3, max(j0 - 2, 0):j0 + 3] = [0, 0, 0]
    # Image rows run down the picture: Y up the picture, X to the right.
    image = np.transpose(rgb, (1, 0, 2))[::-1]
    image = np.repeat(np.repeat(image, 2, axis=0), 2, axis=1)
    # A colour bar under the picture.
    bar_values = np.linspace(low, high, image.shape[1])
    bar = np.repeat(colour(bar_values, low, high)[None], 14, axis=0)
    write_png(path, np.concatenate([image, np.full((4, image.shape[1], 3), 255.0), bar], axis=0))


def cone_mask(meta: dict, slope_deg: float, numbers: dict) -> np.ndarray:
    x, y = coordinates(meta)
    X, Y = np.meshgrid(x, y, indexing="ij")
    a = math.radians(slope_deg)
    d = X * math.cos(a) + Y * math.sin(a)
    s = -X * math.sin(a) + Y * math.cos(a)
    return game_model(d, s, 1.0, numbers["full_until_m"], numbers["length_m"], numbers["half_width_m"],
                      numbers["spread_deg"]) > 0


# --- One case --------------------------------------------------------------------------------------------

def analyse(stem: str) -> dict:
    meta, u_mean, fluct = load(stem)
    maps = follower_maps(meta, u_mean)
    deficit_same = 1.0 - maps["f_same"]
    deficit_rest = 1.0 - maps["f_rest"]
    line = shadow_line(deficit_rest, meta)
    axis = {"slope": line["slope"], "bend_toward_stern_deg": line["bend_toward_stern_deg"]}
    distances = np.arange(0.5, 40.01, 0.5)
    sides = np.arange(-8.0, 8.01, 0.25)
    grid_same = along_across(deficit_same, meta, axis["slope"], distances, sides)
    grid_rest = along_across(deficit_rest, meta, axis["slope"], distances, sides)
    grid_turn = along_across(maps["direction_change_deg"], meta, axis["slope"], distances, sides)
    grid_slowed = along_across(maps["slowed"], meta, axis["slope"], distances, sides)
    xs_all, ys_all = coordinates(meta)
    table = []
    by_distance = {round(r["distance_m"]): r for r in line["rows"]}
    for dist in (2.0, 5.0, 10.0, 15.0, 20.0, 25.0, 30.0, 40.0):
        bell = min(line["rows"], key=lambda r: abs(r["distance_m"] - dist))
        on_line = np.array([dist]), np.array([bell["centre_m"]])
        near = [(on_line[0], on_line[1] + o) for o in (-0.5, 0.0, 0.5)]
        table.append({"distance_m": dist, "deficit_rest": bell["strength"], "background": bell["background"],
                      "deficit_same": float(np.mean([sample(deficit_same, meta, px, py) for px, py in near])),
                      "slowed": float(np.mean([sample(maps["slowed"], meta, px, py) for px, py in near])),
                      "half_width_m": 1.177 * bell["sigma_m"], "edge_90_10_m": 1.69 * bell["sigma_m"],
                      "centre_m": bell["centre_m"],
                      "turn_deg_on_axis": float(np.mean([sample(maps["direction_change_deg"], meta, px, py) for px, py in near])),
                      "true_wind_turn_deg": float(np.mean([sample(maps["turn_rest_deg"], meta, px, py) for px, py in near])),
                      "turn_deg_most": float(np.max(np.abs(grid_turn[int(np.argmin(np.abs(distances - dist)))])))})
    dx = meta["dx_m"]
    k_ce = int(meta["info"]["z_ce_m"] / dx)
    aws = meta["pose"]["aws_ms"]
    # Per component (the vector's rms over the square root of 3), as a share of the true wind: the usual measure
    # of the wind's gustiness (about 0.1 over open water).
    tws = meta["pose"]["tws_ms"]
    flick = []
    a = math.atan(axis["slope"])
    for dist in (-2.0, 5.0, 10.0, 20.0, 30.0):
        value = sample(np.nan_to_num(fluct[:, :, k_ce]), meta, np.array(dist * math.cos(a)), np.array(dist * math.sin(a)))
        flick.append({"distance_m": dist, "rms_share": float(value) / math.sqrt(3.0) / tws})
    fit_same = fit_game(grid_same, distances, sides)
    fit_rest = fit_game(grid_rest, distances, sides)
    from_bells = game_numbers_from_bells(line["rows"])
    xs, ys = coordinates(meta)
    X, Y = np.meshgrid(xs, ys, indexing="ij")
    away = (np.hypot(X - 1.0, Y - 1.0) > 2.5) & (X > -6) & (X < 12) & (np.abs(Y) < 9)
    gain_map = np.where(away, -np.nan_to_num(deficit_rest), -np.inf)
    gi = np.unravel_index(int(np.argmax(gain_map)), gain_map.shape)
    bow = np.array(meta["info"]["bow_tunnel"])
    lee = np.array(meta["info"]["leeward_tunnel"])
    spot = np.array([xs[gi[0]], ys[gi[1]]])
    gain = {"rest": float(gain_map[gi]), "ahead_m": float(spot @ bow), "to_leeward_m": float(spot @ lee)}
    result = {"case": meta["case"], "dx_m": meta["dx_m"], "pose": meta["pose"], "forces": meta["forces"],
              "twist_deg": meta["twist_deg"], "axis_bend_toward_stern_deg": axis["bend_toward_stern_deg"],
              "table": table, "gustiness": flick, "fit_same": fit_same, "fit_rest": fit_rest,
              "game_numbers": from_bells, "bells": line["rows"],
              "game_numbers_explain_rest": game_error(grid_rest, distances, sides, from_bells),
              "game_now_explains_same": game_error(grid_same, distances, sides, GAME_NOW),
              "game_now_explains_rest": game_error(grid_rest, distances, sides, GAME_NOW),
              "most_gain": gain}
    with open(stem + "_wake.json", "w") as handle:
        json.dump(result, handle, indent=1)
    # The game's shadow, laid along the measured middle line, in black (the proposal keeps its outline: only its
    # strength changes).
    slope_deg = math.degrees(math.atan(axis["slope"]))
    outlines = [([0, 0, 0], cone_mask(meta, slope_deg, GAME_PROPOSED))]
    map_picture(stem + "_deficit_same.png", deficit_same, meta, -0.1, 0.4, outlines)
    map_picture(stem + "_deficit_rest.png", deficit_rest, meta, -0.06, 0.06, outlines)
    map_picture(stem + "_turn.png", maps["direction_change_deg"], meta, -4.0, 4.0)
    return result


def print_result(r: dict) -> None:
    f = r["forces"]
    print(f"\n== {r['case']} (cells {r['dx_m'] * 100:.0f} cm, twist {r['twist_deg']:.1f} deg): AWA {r['pose']['awa_deg']:.1f}, "
          f"AWS {r['pose']['aws_ms']:.1f} m/s; sail lift {f['sail']['lift_n']:.0f} N (physics {f['physics']['lift_n']:.0f}), "
          f"drag {f['sail']['drag_n']:.0f} N (physics {f['physics']['drag_n']:.0f})"
          + (f"; sailor drag {f['sailor']['drag_n']:.0f} N (physics {f['physics']['sailor_windage_drag_n']:.0f})" if "sailor" in f else ""))
    print(f"   wake axis bent {r['axis_bend_toward_stern_deg']:+.1f} deg toward the caster's stern (game: +7)")
    print("   dist m | game now | deficit at rest (background) | deficit same-speed | half-width m (game) | edge 90-10 m | header same-speed / true wind turned (deg)")
    for row in r["table"]:
        d = row["distance_m"]
        now = float(game_model(np.array(d), np.array(0.0), GAME_NOW["deficit"], GAME_NOW["full_until_m"], GAME_NOW["length_m"],
                               GAME_NOW["half_width_m"], GAME_NOW["spread_deg"]))
        game_half = (GAME_NOW["half_width_m"] + d * math.tan(math.radians(GAME_NOW["spread_deg"]))) * math.sqrt(0.5)
        print(f"   {d:5.0f}  | {now:8.3f} | {row['deficit_rest']:15.3f} ({row['background']:+.3f})  | {row['deficit_same']:18.3f} | "
              f"{row['half_width_m']:8.2f} ({game_half:4.2f})    | {row['edge_90_10_m']:12.2f} | {row['turn_deg_on_axis']:+5.1f} / {row['true_wind_turn_deg']:+5.1f}")
    print("   gustiness (rms per component / true wind), on the axis:", ", ".join(f"{g['distance_m']:.0f} m: {g['rms_share']:.3f}" for g in r["gustiness"]))
    g = r["game_numbers"]
    print(f"   THE GAME'S NUMBERS FROM THE BELLS: deficit {g['deficit']:.3f}, full until {g['full_until_m']:.1f} m, length {g['length_m']:.0f} m, "
          f"half-width {g['half_width_m']:.2f} m, spread {g['spread_deg']:.1f} deg (the strength's fit explains {g['strength_fit_explains'] * 100:.0f} %; "
          f"the cone explains {r['game_numbers_explain_rest'] * 100:.0f} % of the at-rest map)")
    for name in ("fit_same", "fit_rest"):
        fit = r[name]
        print(f"   {name}: deficit {fit['deficit']:.2f}, full until {fit['full_until_m']:.1f} m, length {fit['length_m']:.1f} m, "
              f"half-width {fit['half_width_m']:.2f} m, spread {fit['spread_deg']:.1f} deg (explains {fit['explained_share'] * 100:.0f} %)")
    print(f"   the game's numbers now explain {r['game_now_explains_same'] * 100:.0f} % (same speed), "
          f"{r['game_now_explains_rest'] * 100:.0f} % (at rest); the most extra wind at rest {r['most_gain']['rest'] * 100:.1f} %, "
          f"{r['most_gain']['ahead_m']:.1f} m ahead and {r['most_gain']['to_leeward_m']:.1f} m to leeward of the mast")


def combined_numbers(results: list) -> dict:
    """One set of the game's numbers for every case together (each case's bells weigh the same): the linear fade
    the game has, and the 1 / sqrt(distance) law the wakes follow (Roncin and Kobus 2004), as the deficit at 5 m."""
    rows = []
    for r in results:
        rows += [dict(b, case=r["case"]) for b in r["bells"]]
    combined = game_numbers_from_bells(rows)
    along = [b for b in rows if 2.0 <= b["distance_m"] <= 40.0]
    d = np.array([b["distance_m"] for b in along])
    a = np.array([max(b["strength"], 0.0) for b in along])
    law = np.sqrt(5.0 / np.maximum(d, 2.0))
    at_5 = float((law * a).sum() / (law * law).sum())
    total = float(((a - a.mean()) ** 2).sum())
    combined["sqrt_law_deficit_at_5m"] = at_5
    combined["sqrt_law_explains"] = 1.0 - float(((at_5 * law - a) ** 2).sum()) / total
    combined["stern_bend_deg"] = float(np.mean([r["axis_bend_toward_stern_deg"] for r in results]))
    combined["cases"] = [r["case"] for r in results]
    return combined


def main() -> None:
    opts = dict(arg[2:].split("=", 1) for arg in sys.argv[1:] if arg.startswith("--") and "=" in arg)
    folder = opts.get("dir", ".sim_output/cfd")
    tag = opts.get("dx", "10")
    suffix = opts.get("suffix", "")
    if "cases" in opts:
        stems = [os.path.join(folder, f"{c}_dx{int(tag):02d}{suffix}") for c in opts["cases"].split(",")]
    else:
        stems = sorted(p[:-4] for p in glob.glob(os.path.join(folder, f"*_dx{int(tag):02d}{suffix}.npz")))
    results = [analyse(stem) for stem in stems]
    for r in results:
        print_result(r)
    summary = {"cases": results}
    if len(results) > 1:
        c = combined_numbers(results)
        summary["combined"] = c
        print(f"\n== ALL CASES TOGETHER ({', '.join(c['cases'])}): deficit {c['deficit']:.3f}, full until {c['full_until_m']:.1f} m, "
              f"length {c['length_m']:.0f} m, half-width {c['half_width_m']:.2f} m, spread {c['spread_deg']:.1f} deg, stern bend "
              f"{c['stern_bend_deg']:.1f} deg (the fade explains {c['strength_fit_explains'] * 100:.0f} %); or the 1/sqrt(distance) law: "
              f"{c['sqrt_law_deficit_at_5m']:.3f} at 5 m (explains {c['sqrt_law_explains'] * 100:.0f} %)")
    with open(os.path.join(folder, f"wake_summary_dx{int(tag):02d}{suffix}.json"), "w") as handle:
        json.dump(summary, handle, indent=1)


if __name__ == "__main__":
    main()
