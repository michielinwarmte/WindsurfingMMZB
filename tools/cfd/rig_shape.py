"""The rig in the wind tunnel (PH15): the sail, the sailor and the board, placed as the game's physics places them
(Game/sim/sail_model.gd: the mast raked and leaned, the boom square to the mast at the sheet angle), and the
walls the air solver needs from them.

Frames:
- Body frame (the physics' own): x starboard, y up, z aft, origin at the board's centre of mass.
- Tunnel frame: X downstream along the apparent wind at the sail's centre of effort, Y across, Z up from the
  water, origin on the water under the mast foot.

The sail is a thin cambered membrane, a mesh of small triangles; the solver bounces every link between two
cells that crosses it (no thick layer of solid cells). The sailor (a cylinder from the feet to the shoulders)
and the board (a box) are solid cells.

Estimates (not in the physics' configs), each in one place below: the sail's outline (the foot rounded down,
the leech's round sized to the area), the head's width, the twist's shape up the sail, the board's size and
height, the sailor's thickness.
"""
import math
from dataclasses import dataclass, field

import numpy as np
import torch

from lbm import DIRECTIONS

# The default sail (Game/config/sail_default.tres) and the physics' numbers this file uses.
SAIL_AREA_M2 = 8.0
LUFF_M = 5.22
MAST_M = 5.26
BOOM_M = 2.2
BOOM_HEIGHT_M = 1.5
CAMBER = 0.07
MAX_RAKE_DEG = 25.0
CE_HEIGHT_FRACTION = 0.41
CE_BOOM_FRACTION = 0.35
MAST_FOOT_BODY = np.array([0.0, 0.081, -0.125])
# Estimates of the shape (see the top).
TACK_ABOVE_FOOT_M = 0.10       # the sail's tack above the mast foot (a race sail's foot sweeps the deck)
HEAD_CHORD_M = 0.12            # the sail's width at the head
FOOT_ROUND_POWER = 0.6         # the foot from tack to clew, rounded down (1 = straight)
DRAFT_POSITION = 0.40          # the deepest point of the camber, share of the chord from the mast
TWIST_POWER = 1.5              # the twist grows up the sail above the boom as (share of the way up) ^ this
BOARD_COM_ABOVE_WATER_M = 0.05  # a planing board's centre of mass above the water
BOARD_LENGTH_M = 2.35
BOARD_WIDTH_M = 0.72
DECK_ABOVE_WATER_M = 0.12
SAILOR_RADIUS_M = 0.18         # a body 0.36 m thick: about the physics' windage of 0.5 m2 (area times drag)


@dataclass
class RigPose:
    """What the tunnel needs of a steady state of the physics (tools/cfd/steady_states.py)."""
    awa_deg: float          # apparent wind angle at the sail, positive from starboard
    aws_ms: float           # apparent wind speed at the sail
    twa_deg: float          # true wind angle at the sail
    tws_ms: float           # true wind speed at the sail
    sheet_angle_deg: float  # the boom's angle from the centreline, on the sail's side
    sail_side: int          # +1 boom to starboard (port tack), -1 boom to port (starboard tack)
    rake_deg: float         # the mast raked back
    lean_deg: float         # the mast tipped sideways, positive toward starboard
    sailor_body: np.ndarray = field(default_factory=lambda: np.array([1.0, 0.55, 0.8]))  # x, y, z body frame
    feet_body: np.ndarray = field(default_factory=lambda: np.array([0.22, 0.08, 0.85]))
    twist_top_deg: float = 15.0  # how much more open the head is than the boom (calibrated, wind_tunnel.py)

    @staticmethod
    def from_state(state: dict, twist_top_deg: float) -> "RigPose":
        kt = 0.514444
        side = -1 if state["sail_side"] < 0 else 1
        # Turn a port-tack state into its starboard-tack mirror, so every case is set up the same way.
        sign = 1.0 if side == -1 else -1.0
        feet_y = MAST_FOOT_BODY[1]  # the feet on the deck, at the mast foot's height
        return RigPose(
            awa_deg=sign * state["awa_deg"], aws_ms=state["aws_kt"] * kt,
            twa_deg=sign * state["twa_deg"], tws_ms=state["tws_at_sail_kt"] * kt,
            sheet_angle_deg=abs(state["sail_angle_deg"]), sail_side=-1,
            rake_deg=state["rake"] * MAX_RAKE_DEG, lean_deg=sign * state["rig_lean_deg"],
            sailor_body=np.array([sign * state["sailor_x_m"], state["sailor_y_m"], state["feet_z_m"]]),
            feet_body=np.array([sign * state["feet_x_m"], feet_y, state["feet_z_m"]]),
            twist_top_deg=twist_top_deg)


def mast_direction(pose: RigPose) -> np.ndarray:
    """sail_model.gd mast_direction(): raked back by the rake, tipped sideways by the lean (body frame)."""
    rake = math.radians(pose.rake_deg)
    lean = math.radians(pose.lean_deg)
    return np.array([math.sin(lean), math.cos(lean) * math.cos(rake), math.cos(lean) * math.sin(rake)])


def boom_direction(pose: RigPose, extra_open_deg: float) -> np.ndarray:
    """sail_model.gd boom_direction(): the level chord at the sheet angle (plus the twist here), turned square
    to the mast."""
    angle = math.radians(pose.sheet_angle_deg + extra_open_deg)
    level = np.array([pose.sail_side * math.sin(angle), 0.0, math.cos(angle)])
    mast = mast_direction(pose)
    square = level - mast * level.dot(mast)
    return square / np.linalg.norm(square)


def head_height_m() -> float:
    return MAST_M


def _roach_m() -> float:
    """The leech's round above the boom that gives the outline the sail's area."""
    foot_area = BOOM_M * (BOOM_HEIGHT_M - TACK_ABOVE_FOOT_M) / (FOOT_ROUND_POWER + 1.0)
    upper_span = head_height_m() - BOOM_HEIGHT_M
    straight_area = 0.5 * (BOOM_M + HEAD_CHORD_M) * upper_span
    return (SAIL_AREA_M2 - foot_area - straight_area) / (upper_span * 2.0 / math.pi)


def chord_m(s: np.ndarray) -> np.ndarray:
    """The sail's width (mast to leech, square to the mast) at a distance s up the mast from its foot."""
    s = np.asarray(s, dtype=np.float64)
    low = np.clip((s - TACK_ABOVE_FOOT_M) / (BOOM_HEIGHT_M - TACK_ABOVE_FOOT_M), 0.0, 1.0)
    u = np.clip((s - BOOM_HEIGHT_M) / (head_height_m() - BOOM_HEIGHT_M), 0.0, 1.0)
    below = BOOM_M * low ** FOOT_ROUND_POWER
    above = BOOM_M + (HEAD_CHORD_M - BOOM_M) * u + _roach_m() * np.sin(math.pi * u)
    return np.where(s < BOOM_HEIGHT_M, below, above)


def twist_deg(pose: RigPose, s: np.ndarray) -> np.ndarray:
    u = np.clip((np.asarray(s) - BOOM_HEIGHT_M) / (head_height_m() - BOOM_HEIGHT_M), 0.0, 1.0)
    return pose.twist_top_deg * u ** TWIST_POWER


def camber_line(t: np.ndarray) -> np.ndarray:
    """The camber's depth along the chord (share of the chord), NACA's four-digit mean line, deepest at
    DRAFT_POSITION, as deep as the physics' camber."""
    p = DRAFT_POSITION
    m = CAMBER
    return np.where(t < p, m / p ** 2 * (2 * p * t - t * t), m / (1 - p) ** 2 * ((1 - 2 * p) + 2 * p * t - t * t))


def sail_points_body(pose: RigPose, n_up: int, n_along: int) -> np.ndarray:
    """A grid of points on the sail (n_up x n_along x 3), body frame."""
    mast = mast_direction(pose)
    foot = MAST_FOOT_BODY
    s_values = np.linspace(TACK_ABOVE_FOOT_M, head_height_m(), n_up)
    t_values = np.linspace(0.0, 1.0, n_along)
    leeward = np.array([pose.sail_side, 0.0, 0.0])
    points = np.zeros((n_up, n_along, 3))
    for a, s in enumerate(s_values):
        chord = float(chord_m(s))
        boom = boom_direction(pose, float(twist_deg(pose, s)))
        normal = np.cross(mast, boom)
        normal /= np.linalg.norm(normal)
        if normal.dot(leeward) < 0.0:
            normal = -normal
        depth = camber_line(t_values) * chord
        points[a] = foot + mast * s + np.outer(t_values * chord, boom) + np.outer(depth, normal)
    return points


def sail_area_check(pose: RigPose) -> dict:
    """The outline's area and centre of effort height, against the physics' (for the report)."""
    s = np.linspace(TACK_ABOVE_FOOT_M, head_height_m(), 2000)
    c = chord_m(s)
    ds = s[1] - s[0]
    area = float((c * ds).sum())
    centroid_s = float((s * c * ds).sum() / area)
    return {"area_m2": area, "centroid_up_mast_m": centroid_s, "physics_ce_up_mast_m": CE_HEIGHT_FRACTION * LUFF_M,
            "roach_m": _roach_m()}


class TunnelFrame:
    """Turns body-frame points into tunnel-frame points for a pose, and tells the tunnel's winds."""

    def __init__(self, pose: RigPose):
        self.pose = pose
        a = math.radians(pose.awa_deg)
        # The apparent wind blows toward (-sin AWA, 0, cos AWA) in the body frame: the tunnel's X.
        self.x_axis = np.array([-math.sin(a), 0.0, math.cos(a)])
        self.y_axis = np.array([math.cos(a), 0.0, math.sin(a)])
        self.foot_height_m = BOARD_COM_ABOVE_WATER_M + MAST_FOOT_BODY[1]

    def to_tunnel(self, body_points: np.ndarray) -> np.ndarray:
        rel = body_points - MAST_FOOT_BODY
        x = rel @ self.x_axis
        y = rel @ self.y_axis
        z = rel[..., 1] + self.foot_height_m
        return np.stack([x, y, z], axis=-1)

    def ce_height_m(self) -> float:
        """The height above the water of the point where the physics samples the apparent wind."""
        mast = mast_direction(self.pose)
        point = MAST_FOOT_BODY + mast * (CE_HEIGHT_FRACTION * LUFF_M)
        return float(self.to_tunnel(point)[2])

    def winds(self):
        """The true wind and the board's velocity through the air at the sail, tunnel frame (X, Y), m/s.
        The apparent wind there is (aws, 0) by the tunnel's choice of X; the true wind keeps its angle to it."""
        p = self.pose
        diff = math.radians(p.twa_deg - p.awa_deg)
        true_wind = np.array([p.tws_ms * math.cos(diff), -p.tws_ms * math.sin(diff)])
        apparent = np.array([p.aws_ms, 0.0])
        board_velocity = true_wind - apparent
        return true_wind, board_velocity

    def bow_direction(self) -> np.ndarray:
        """The board's heading in the tunnel frame (X, Y)."""
        bow_body = np.array([0.0, 0.0, -1.0])
        return np.array([bow_body @ self.x_axis, bow_body @ self.y_axis])

    def leeward_direction(self) -> np.ndarray:
        """Leeward (the side the boom is on) in the tunnel frame (X, Y)."""
        lee = np.array([self.pose.sail_side, 0.0, 0.0])
        return np.array([lee @ self.x_axis, lee @ self.y_axis])


@dataclass
class Grid:
    """The tunnel's cells: cell (i, j, k) has its centre at x0 + (i + 0.5) dx, y0 + (j + 0.5) dx, (k + 0.5) dx."""
    dx: float
    nx: int
    ny: int
    nz: int
    x0: float
    y0: float

    def centre(self, i, j, k):
        return (self.x0 + (i + 0.5) * self.dx, self.y0 + (j + 0.5) * self.dx, (k + 0.5) * self.dx)

    def index_of(self, points: np.ndarray) -> np.ndarray:
        """The cell index each point falls in (floats; floor them)."""
        return np.stack([(points[..., 0] - self.x0) / self.dx - 0.5,
                         (points[..., 1] - self.y0) / self.dx - 0.5,
                         points[..., 2] / self.dx - 0.5], axis=-1)


def _triangles(points: np.ndarray) -> np.ndarray:
    """Two triangles per quad of a point grid: (n, 3 corners, 3)."""
    a = points[:-1, :-1]
    b = points[1:, :-1]
    c = points[1:, 1:]
    d = points[:-1, 1:]
    first = np.stack([a, b, c], axis=2).reshape(-1, 3, 3)
    second = np.stack([a, c, d], axis=2).reshape(-1, 3, 3)
    return np.concatenate([first, second], axis=0)


def membrane_link_mask(grid: Grid, box: tuple, triangles: np.ndarray, device) -> torch.Tensor:
    """(19, bx, by, bz) bool: the number arriving in the cell along the direction crossed the membrane (its
    segment from the cell it left to this cell's centre passes through a triangle). Moller-Trumbore."""
    x0, x1, y0, y1, z0, z1 = box
    shape = (x1 - x0, y1 - y0, z1 - z0)
    mask = torch.zeros((19,) + shape, dtype=torch.bool, device=device)
    tri = torch.tensor(triangles, dtype=torch.float64, device=device)
    centroid_cell = torch.floor(torch.tensor(grid.index_of(triangles.mean(axis=1)), device=device)).long()
    reach = 3
    offsets = torch.stack(torch.meshgrid(*[torch.arange(-reach, reach + 1, device=device)] * 3, indexing="ij"),
                          dim=-1).reshape(-1, 3)
    dirs = torch.tensor(DIRECTIONS, dtype=torch.float64, device=device)
    eps = 1e-9
    for start in range(0, tri.shape[0], 512):
        t = tri[start:start + 512]
        cells = centroid_cell[start:start + 512, None, :] + offsets[None, :, :]  # (T, O, 3)
        centres = torch.stack([grid.x0 + (cells[..., 0] + 0.5) * grid.dx, grid.y0 + (cells[..., 1] + 0.5) * grid.dx,
                               (cells[..., 2] + 0.5) * grid.dx], dim=-1)
        v0 = t[:, None, None, 0, :]
        e1 = (t[:, 1, :] - t[:, 0, :])[:, None, None, :]
        e2 = (t[:, 2, :] - t[:, 0, :])[:, None, None, :]
        d = (dirs * grid.dx)[None, None, :, :]  # (1, 1, 19, 3): the segment from the cell it left
        origin = centres[:, :, None, :] - d
        pvec = torch.cross(d.expand_as(origin), e2.expand_as(origin), dim=-1)
        det = (e1 * pvec).sum(-1)
        ok = det.abs() > eps
        inv = 1.0 / torch.where(ok, det, torch.ones_like(det))
        tvec = origin - v0
        u = (tvec * pvec).sum(-1) * inv
        qvec = torch.cross(tvec, e1.expand_as(tvec), dim=-1)
        v = (d * qvec).sum(-1) * inv
        along = (e2 * qvec).sum(-1) * inv
        tol = 1e-7
        hit = ok & (u >= -tol) & (v >= -tol) & (u + v <= 1 + tol) & (along >= 0) & (along <= 1)
        hit[:, :, 0] = False
        tt, oo, qq = torch.nonzero(hit, as_tuple=True)
        c = cells[tt, oo]
        bi, bj, bk = c[:, 0] - x0, c[:, 1] - y0, c[:, 2] - z0
        inside = (bi >= 0) & (bi < shape[0]) & (bj >= 0) & (bj < shape[1]) & (bk >= 0) & (bk < shape[2])
        mask[qq[inside], bi[inside], bj[inside], bk[inside]] = True
    # Every link is bounced at both ends or at neither. A link that grazes the membrane's edge can pass the test
    # one way and not the other; bounced at one end only, it lets air through one way and stops it the other,
    # and the force it reports is wrong (13 November 2026: a square plate's drag coefficient read 5.8, not 1.2).
    for q, (cx, cy, cz) in enumerate(DIRECTIONS):
        if q > 0:
            partner = DIRECTIONS.index((-cx, -cy, -cz))
            mask[q] |= torch.roll(mask[partner], shifts=(cx, cy, cz), dims=(0, 1, 2))
    return mask


def solid_link_mask(solid: torch.Tensor) -> torch.Tensor:
    """(19, bx, by, bz) bool from a solid-cell mask of the box: the number arriving in a fluid cell came from a
    solid cell. The box is padded with fluid so nothing comes from outside it."""
    masks = []
    for q, (cx, cy, cz) in enumerate(DIRECTIONS):
        if q == 0:
            masks.append(torch.zeros_like(solid))
            continue
        came_from = torch.roll(solid, shifts=(cx, cy, cz), dims=(0, 1, 2))
        masks.append(came_from & ~solid)
    return torch.stack(masks)


def cylinder_solid(grid: Grid, box: tuple, a: np.ndarray, b: np.ndarray, radius: float, device) -> torch.Tensor:
    """Solid cells of the box inside the capped cylinder from a to b (tunnel frame)."""
    x0, x1, y0, y1, z0, z1 = box
    i, j, k = torch.meshgrid(torch.arange(x0, x1, device=device), torch.arange(y0, y1, device=device),
                             torch.arange(z0, z1, device=device), indexing="ij")
    p = torch.stack([grid.x0 + (i + 0.5) * grid.dx, grid.y0 + (j + 0.5) * grid.dx, (k + 0.5) * grid.dx], dim=-1)
    a_t = torch.tensor(a, dtype=torch.float32, device=device)
    axis = torch.tensor(b - a, dtype=torch.float32, device=device)
    length = float(np.linalg.norm(b - a))
    along = ((p - a_t) @ axis) / (length * length)
    closest = a_t + along.clamp(0, 1)[..., None] * axis
    return ((p - closest).norm(dim=-1) <= radius)


def box_solid(grid: Grid, box: tuple, corner_body: np.ndarray, size_body: np.ndarray, frame: TunnelFrame,
              device) -> torch.Tensor:
    """Solid cells of the box inside the board (a box in the body frame, from the corner, of the size)."""
    x0, x1, y0, y1, z0, z1 = box
    i, j, k = torch.meshgrid(torch.arange(x0, x1, device=device), torch.arange(y0, y1, device=device),
                             torch.arange(z0, z1, device=device), indexing="ij")
    X = grid.x0 + (i + 0.5) * grid.dx
    Y = grid.y0 + (j + 0.5) * grid.dx
    Z = (k + 0.5) * grid.dx
    # Back to the body frame (the horizontal turn is a rotation; the height is shifted).
    bx = X * frame.x_axis[0] + Y * frame.y_axis[0] + MAST_FOOT_BODY[0]
    bz = X * frame.x_axis[2] + Y * frame.y_axis[2] + MAST_FOOT_BODY[2]
    by = Z - frame.foot_height_m + MAST_FOOT_BODY[1]
    lo = corner_body
    hi = corner_body + size_body
    return (bx >= lo[0]) & (bx <= hi[0]) & (by >= lo[1]) & (by <= hi[1]) & (bz >= lo[2]) & (bz <= hi[2])


# --- The actuator model: the rig as the forces it puts on the air -----------------------------------------
#
# A solid sail on 10 cm cells cannot hold its boundary layer: the solver's checks (13 November 2026) gave a flat
# wing far too much friction (drag coefficient 0.11 at no angle) and too little lift (0.28 against about 0.5;
# 0.39 on 5 cm cells), so a solid sail's wake would be too strong. Wind-farm studies meet the same limit with
# the actuator line and surface (Sorensen and Shen 2002): the blade is replaced by the force it puts on the air,
# spread over where it is. Here that force is the game's own: the physics' lift and drag on the sail and the
# sailor's windage, so the tunnel shows the shadow of the game's rig.

# The physics' centre of effort (Game/config/sail_default.tres; sail_model.gd compute()).
CE_TABLE_DEG = [1.3, 5.3, 8.7, 12.2]
CE_TABLE_SHARE = [0.53, 0.855, 0.94, 1.0]
TWIST_PRESSURE_PA = 125.0
TWIST_CE_DROP = 0.32
SAILOR_WINDAGE_M2 = 0.5  # Game/config/sailor_default.tres windage_area_cd_m2
SPREAD_CELLS = 1.5       # the force's Gaussian width, in cells (actuator lines use 1.5 to 2)


def physics_ce_up_mast_m(alpha_deg: float, aws_ms: float, rho_air: float = 1.225) -> float:
    """How far up the mast the physics puts the sail's force (sail_model.gd: the table by angle of attack, lowered
    as the top twists open)."""
    q = 0.5 * rho_air * aws_ms * aws_ms
    twist_share = max(1.0 / (1.0 + q / TWIST_PRESSURE_PA), 0.1)
    share = float(np.interp(abs(alpha_deg), CE_TABLE_DEG, CE_TABLE_SHARE))
    return CE_HEIGHT_FRACTION * LUFF_M * share * (1.0 - TWIST_CE_DROP * (1.0 - twist_share))


def _spread(points: np.ndarray, forces: np.ndarray, grid: Grid, width_m: float, device):
    """Spreads point forces (n, 3) at tunnel points (n, 3) over the cells around them (a Gaussian of the width,
    each point's weights summing to 1). Returns (box, push (3, bx, by, bz))."""
    reach = int(math.ceil(2.5 * width_m / grid.dx))
    idx = np.floor(grid.index_of(points)).astype(int)
    lo = idx.min(0) - reach - 1
    hi = idx.max(0) + reach + 2
    lo[2] = max(lo[2], 0)
    box = (int(lo[0]), int(hi[0]), int(lo[1]), int(hi[1]), int(lo[2]), int(hi[2]))
    push = torch.zeros((3, hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]), dtype=torch.float64, device=device)
    offsets = np.stack(np.meshgrid(*[np.arange(-reach, reach + 1)] * 3, indexing="ij"), -1).reshape(-1, 3)
    pts = torch.tensor(points, dtype=torch.float64, device=device)
    frc = torch.tensor(forces, dtype=torch.float64, device=device)
    cells = torch.tensor(idx, device=device)[:, None, :] + torch.tensor(offsets, device=device)[None]  # (n, o, 3)
    centres = torch.stack([grid.x0 + (cells[..., 0] + 0.5) * grid.dx, grid.y0 + (cells[..., 1] + 0.5) * grid.dx,
                           (cells[..., 2] + 0.5) * grid.dx], -1)
    weight = torch.exp(-((centres - pts[:, None, :]) ** 2).sum(-1) / (width_m * width_m))
    weight = torch.where(cells[..., 2] >= 0, weight, torch.zeros_like(weight))  # nothing below the water
    weight = weight / weight.sum(1, keepdim=True)
    local = cells - torch.tensor(lo, device=device)
    flat = (local[..., 0] * push.shape[2] + local[..., 1]) * push.shape[3] + local[..., 2]
    for k in range(3):
        push[k].view(-1).index_add_(0, flat.reshape(-1), (weight * frc[:, None, k]).reshape(-1))
    return box, push


def actuator_push(grid: Grid, pose: RigPose, inflow_ms: np.ndarray, lift_n: float, drag_n: float,
                  alpha_deg: float, scale: float, device, rho_air: float = 1.225, with_sailor: bool = True):
    """The force the game's rig puts on the air, spread over the sail and the sailor, in lattice units per cell
    per step: (box, push (3, bx, by, bz) float32, info).

    The sail: the physics' lift and drag (N), spread over the sail's area as the local dynamic pressure (the
    apparent wind at each height, inflow_ms) times a share that falls up the sail so the force's centre is where
    the physics puts it; at each height the drag lies along the local apparent wind and the lift square to it,
    to leeward, tilted up by the rig's lean (as sail_model.gd tilts it). The sailor: the physics' windage (0.5 m2
    of drag area) along the local apparent wind, spread along the body. The air gets the opposite of each."""
    frame = TunnelFrame(pose)
    n_up, n_along = 120, 24
    s_edges = np.linspace(TACK_ABOVE_FOOT_M, head_height_m(), n_up + 1)
    s_mid = 0.5 * (s_edges[1:] + s_edges[:-1])
    t_mid = (np.arange(n_along) + 0.5) / n_along
    mast = mast_direction(pose)
    leeward = np.array([pose.sail_side, 0.0, 0.0])
    points_body = []
    areas = []
    s_of_point = []
    for s in s_mid:
        chord = float(chord_m(s))
        boom = boom_direction(pose, float(twist_deg(pose, s)))
        normal = np.cross(mast, boom)
        normal /= np.linalg.norm(normal)
        if normal.dot(leeward) < 0.0:
            normal = -normal
        for t in t_mid:
            depth = float(camber_line(np.array(t))) * chord
            points_body.append(MAST_FOOT_BODY + mast * s + boom * (t * chord) + normal * depth)
            areas.append(chord * (s_edges[1] - s_edges[0]) / n_along)
            s_of_point.append(s)
    points = frame.to_tunnel(np.array(points_body))
    areas = np.array(areas)
    s_of_point = np.array(s_of_point)

    def apparent_at(z):
        k = np.clip((z / grid.dx - 0.5).astype(int), 0, inflow_ms.shape[1] - 1)
        return inflow_ms[0][k], inflow_ms[1][k]
    ax, ay = apparent_at(points[:, 2])
    speed = np.hypot(ax, ay)
    q = 0.5 * rho_air * speed * speed
    # The share falling up the sail that puts the force's centre at the physics' height (a straight search).
    target = physics_ce_up_mast_m(alpha_deg, pose.aws_ms)
    span = (s_of_point - TACK_ABOVE_FOOT_M) / (head_height_m() - TACK_ABOVE_FOOT_M)
    best = None
    for fall in np.linspace(0.0, 1.2, 241):
        load = q * areas * np.clip(1.0 - fall * span, 0.0, None)
        centre = float((load * s_of_point).sum() / load.sum())
        if best is None or abs(centre - target) < abs(best[1] - target):
            best = (fall, centre, load)
    fall, centre, load = best
    share = load / load.sum()
    # Directions at each point: drag along the local apparent wind, lift square to it toward leeward, tilted up by
    # the lean (a lean to windward lifts the sail's force upward).
    drag_dir = np.stack([ax / speed, ay / speed, np.zeros_like(ax)], -1)
    lee = frame.leeward_direction()
    lift_h = np.stack([-drag_dir[:, 1], drag_dir[:, 0], np.zeros_like(ax)], -1)
    lift_h *= np.sign((lift_h[:, :2] @ lee))[:, None]
    lean = math.radians(abs(pose.lean_deg))
    lift_dir = lift_h * math.cos(lean) + np.array([0.0, 0.0, 1.0]) * math.sin(lean)
    sail_force = share[:, None] * (lift_n * lift_dir + drag_n * drag_dir)  # on the sail, N
    # The physics' sail is two-dimensional: its lift and drag are square to and along the apparent wind at the
    # centre of effort (the tunnel's X). Turned with the wind at each height the total drifts from that (on the
    # 18 kt beam reach 101 N along the wind against 86); the difference is shared out by load, so the total is
    # the physics' force exactly and each height keeps its own direction.
    lean_up = math.sin(lean)
    game_total = np.array([drag_n, lift_n * math.cos(lean) * float(np.sign(lee[1])), lift_n * lean_up])
    sail_force += share[:, None] * (game_total - sail_force.sum(0))[None, :]
    all_points = [points]
    all_forces = [-sail_force]
    info = {"ce_up_mast_target_m": target, "ce_up_mast_m": centre, "load_fall": float(fall),
            "sail_force_n": sail_force.sum(0).tolist()}
    if with_sailor:
        feet = pose.feet_body
        shoulders = 2.0 * pose.sailor_body - feet
        body = frame.to_tunnel(feet[None, :] + np.linspace(0.05, 1.0, 24)[:, None] * (shoulders - feet)[None, :])
        bx, by = apparent_at(body[:, 2])
        bspeed = np.hypot(bx, by)
        windage = (SAILOR_WINDAGE_M2 / 24) * 0.5 * rho_air * bspeed * bspeed
        body_force = windage[:, None] * np.stack([bx / bspeed, by / bspeed, np.zeros_like(bx)], -1)
        info["sailor_force_n"] = body_force.sum(0).tolist()
        info["sailor_points"] = body.tolist()[::6]
        sail_box, sail_push = _spread(points, -sail_force, grid, SPREAD_CELLS * grid.dx, device)
        body_box, body_push = _spread(body, -body_force, grid, max(SAILOR_RADIUS_M, SPREAD_CELLS * grid.dx), device)
        box, push = _merge(sail_box, sail_push, body_box, body_push, device)
    else:
        box, push = _spread(points, -sail_force, grid, SPREAD_CELLS * grid.dx, device)
    lattice_per_newton = scale * scale / (rho_air * grid.dx * grid.dx)
    info["air_push_n"] = (push.sum((1, 2, 3)).cpu().numpy()).tolist()
    return box, (push * lattice_per_newton).float(), info


def _merge(box_a, push_a, box_b, push_b, device):
    lo = [min(box_a[0], box_b[0]), min(box_a[2], box_b[2]), min(box_a[4], box_b[4])]
    hi = [max(box_a[1], box_b[1]), max(box_a[3], box_b[3]), max(box_a[5], box_b[5])]
    push = torch.zeros((3, hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]), dtype=push_a.dtype, device=device)
    for b, p in ((box_a, push_a), (box_b, push_b)):
        push[:, b[0] - lo[0]:b[1] - lo[0], b[2] - lo[1]:b[3] - lo[1], b[4] - lo[2]:b[5] - lo[2]] += p
    return (lo[0], hi[0], lo[1], hi[1], lo[2], hi[2]), push


def build_walls(grid: Grid, pose: RigPose, device, with_sailor: bool = True, with_board: bool = True):
    """The walls of the rig: (box, link masks (objects, 19, ...), solid cells of the box, object names)."""
    frame = TunnelFrame(pose)
    n_up = max(int(head_height_m() / (grid.dx / 2.5)), 40)
    n_along = max(int(BOOM_M * 1.3 / (grid.dx / 2.5)), 20)
    sail = frame.to_tunnel(sail_points_body(pose, n_up, n_along))
    triangles = _triangles(sail)
    # The sailor: a cylinder from the feet through the centre of mass to the shoulders.
    # The centre of mass sits about halfway up the body, so the shoulders are as far beyond it as the feet
    # are before it.
    feet = pose.feet_body
    shoulders = 2.0 * pose.sailor_body - feet
    sailor_a = frame.to_tunnel(feet + np.array([0.0, SAILOR_RADIUS_M, 0.0]))
    sailor_b = frame.to_tunnel(shoulders)
    board_corner = np.array([-BOARD_WIDTH_M / 2, -BOARD_COM_ABOVE_WATER_M, -BOARD_LENGTH_M / 2])
    board_size = np.array([BOARD_WIDTH_M, DECK_ABOVE_WATER_M, BOARD_LENGTH_M])
    board_pts = frame.to_tunnel(np.array([[x, y, z] for x in (board_corner[0], board_corner[0] + board_size[0])
                                          for y in (board_corner[1], board_corner[1] + board_size[1])
                                          for z in (board_corner[2], board_corner[2] + board_size[2])]))
    every = np.concatenate([sail.reshape(-1, 3), sailor_a[None], sailor_b[None], board_pts], axis=0)
    lo = np.floor(grid.index_of(every.min(axis=0))).astype(int) - 3
    hi = np.ceil(grid.index_of(every.max(axis=0))).astype(int) + 4
    lo[2] = 0
    box = (int(lo[0]), int(hi[0]), int(lo[1]), int(hi[1]), int(lo[2]), int(hi[2]))
    masks = [membrane_link_mask(grid, box, triangles, device)]
    names = ["sail"]
    solid = torch.zeros((box[1] - box[0], box[3] - box[2], box[5] - box[4]), dtype=torch.bool, device=device)
    if with_sailor:
        body = cylinder_solid(grid, box, sailor_a, sailor_b, SAILOR_RADIUS_M, device)
        masks.append(solid_link_mask(body))
        names.append("sailor")
        solid |= body
    if with_board:
        board = box_solid(grid, box, board_corner, board_size, frame, device)
        masks.append(solid_link_mask(board))
        names.append("board")
        solid |= board
    # Nothing arrives through the water's surface from below (the solver's water does that), and a solid
    # object's cells are not bounced by another's mask.
    link_masks = torch.stack(masks)
    for q in range(19):
        if DIRECTIONS[q][2] == 1:
            link_masks[:, q, :, :, 0] = False
    link_masks &= ~solid.unsqueeze(0).unsqueeze(0)
    return box, link_masks, solid, names, {"sailor_feet": sailor_a.tolist(), "sailor_shoulders": sailor_b.tolist(),
                                           "sail_triangles": int(triangles.shape[0])}
