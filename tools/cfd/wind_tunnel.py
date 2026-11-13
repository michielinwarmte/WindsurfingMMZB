"""The wind tunnel (PH15): a windsurfer's rig in the air on the GPU, its force and the wind it leaves behind.

The rig is posed from a steady state of the game's physics (tools/reach_check.sh --csv=1, then
tools/cfd/steady_states.py --json=...). The tunnel's air comes in along the board's apparent wind at the sail,
with the game's wind gradient over the water (WindConfig: the speed grows as height ^ 0.11) minus the board's
speed, so the apparent wind twists with height as on the water; the water is a slippery floor (lbm.py says
why). Use tools/wind_tunnel.sh.

Modes:
  --check=plate          the solver's check: a square plate across the wind (drag coefficient about 1.17)
  --check=wing           a flat wing of aspect ratio 2.5 at 10 degrees (lift coefficient about 0.5 to 0.6)
  --case=<name> --mode=force --twist=<deg>   the rig's force in a short tunnel (for the calibration)
  --case=<name> --mode=calibrate             the twist that makes the sail pull what the game's sail pulls
  --case=<name> --mode=wake [--twist=<deg>]  the long tunnel: the force and the wind behind, time-averaged
Options: --dx=0.1 (m) --states=.sim_output/reach/steady_states.json --out=.sim_output/cfd --flows=<n>
  --model=actuator (default: the rig as the game's forces on the air) or solid (a membrane sail: too much friction
  on 10 cm cells, see rig_shape.py) --gusts=0.1 (the inflow's gustiness, rms per component over the true wind;
  0 = smooth air, the file's name ends _calm; 0.11 asked gives about 0.10 at the rig) --gust_length_m=6 (the gusts'
  von Karman length). The defaults: 15 cm cells, a tunnel 8 + 50 m long, 40 m wide, 16 m tall.
  --no_sailor=1 --no_board=1 --down_m=45 --width_m=26 --height_m=12
"""
import json
import math
import os
import sys
import time

import numpy as np
import torch

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lbm import Lattice, Tunnel  # noqa: E402
from inflow_turbulence import InflowTurbulence  # noqa: E402
import rig_shape  # noqa: E402

RHO_AIR = 1.225
WIND_SHEAR_EXPONENT = 0.11   # Game/config/wind_default.tres
WIND_MIN_HEIGHT_M = 0.1
U_LATTICE = 0.07             # the apparent wind at the sail, in cells per step (well below the lattice's limit)
NU_AIR = 1.5e-5


def options() -> dict:
    opts = {}
    for arg in sys.argv[1:]:
        if arg.startswith("--") and "=" in arg:
            key, value = arg[2:].split("=", 1)
            opts[key] = value
    return opts


# The least viscosity the air is given, lattice units. At air's own (a relaxation time a hair above 0.5) the
# method's shear stresses flip sign every step and never die: a 2-step flicker of 2 m/s across the wind
# (13 November 2026). 0.001 is the smallest that kills it; at 10 cm cells it is 0.02 m2/s, a few percent of a
# turbulent wake's own mixing (about 0.3 to 1 m2/s).
NU_FLOOR_LATTICE = 0.001


def tau_for(dx: float, speed_ms: float) -> float:
    """The relaxation time for air's own viscosity at this cell size and speed scale, or the floor's if more (the
    turbulence model adds the eddies' viscosity on top)."""
    dt = dx * U_LATTICE / speed_ms
    nu_lattice = max(NU_AIR * dt / (dx * dx), NU_FLOOR_LATTICE)
    return 0.5 + 3.0 * nu_lattice


def run(tunnel: Tunnel, spin_steps: int, average_steps: int, keep_field: bool, label: str) -> dict:
    """Runs the tunnel: spin_steps to settle, then average_steps over which the forces (and with keep_field
    the wind everywhere) are averaged. Prints the forces now and then."""
    dev = tunnel.lat.device
    n_objects = tunnel.link_masks.shape[0]
    force_sum = torch.zeros(n_objects, 3, device=dev)
    series = []
    u_sum = u2_sum = None
    samples = 0
    if keep_field:
        u_sum = torch.zeros(3, tunnel.nx, tunnel.ny, tunnel.nz, device=dev)
        u2_sum = torch.zeros(tunnel.nx, tunnel.ny, tunnel.nz, device=dev)
        rho_sum = torch.zeros(tunnel.nx, tunnel.ny, tunnel.nz, device=dev, dtype=torch.float64)
    started = time.time()
    total = spin_steps + average_steps
    log_every = max(total // 40, 50)
    window = torch.zeros(n_objects, 3, device=dev)
    window_count = 0
    for n in range(total):
        rho, u, forces = tunnel.step()
        window += forces
        window_count += 1
        if n >= spin_steps:
            force_sum += forces
            if keep_field and n % 5 == 0:
                u_sum += u
                u2_sum += (u * u).sum(0)
                rho_sum += rho - 1.0
                samples += 1
        if (n + 1) % log_every == 0 or n == total - 1:
            mean = (window / window_count).cpu().numpy()
            series.append([n + 1] + mean.reshape(-1).tolist())
            window.zero_()
            window_count = 0
            ok = bool(torch.isfinite(rho[::8, ::8, ::8]).all())
            rate = (n + 1) / (time.time() - started)
            print(f"[{label}] step {n + 1:6d}/{total} ({rate:5.1f}/s, {(total - n - 1) / rate / 60:4.1f} min left) "
                  f"rho {float(rho.min()):.3f}..{float(rho.max()):.3f} force(lattice) {np.round(mean[0], 4).tolist()}",
                  flush=True)
            if not ok:
                raise RuntimeError("the air blew up (not finite)")
    result = {"force_lattice": (force_sum / max(average_steps, 1)).cpu().numpy(), "series": series,
              "seconds": time.time() - started, "steps": total}
    if keep_field:
        result["u_mean"] = (u_sum / samples).cpu().numpy()
        result["u2_mean"] = (u2_sum / samples).cpu().numpy()
        result["rho_dev_mean"] = (rho_sum / samples).float().cpu().numpy()
    return result


# --- The solver's checks -----------------------------------------------------------------------------------

def plate_points(centre, along_a, along_b, size_a, size_b, n_a, n_b) -> np.ndarray:
    a = np.linspace(-size_a / 2, size_a / 2, n_a)
    b = np.linspace(-size_b / 2, size_b / 2, n_b)
    return np.array(centre)[None, None, :] + a[:, None, None] * np.array(along_a) + b[None, :, None] * np.array(along_b)


def disk_check(dx: float, flows: float) -> dict:
    """The actuator model's check: a 4 m disc square to the wind pushing back on the air with a thrust
    coefficient CT of 0.6. Momentum theory (Rankine and Froude): the air at the disc slows to 1 - a of the wind,
    a = (1 - sqrt(1 - CT)) / 2 = 0.184, so 0.816; the wake toward 1 - 2a = 0.632 before it mixes out. And the
    momentum the air loses through the tunnel must be the thrust."""
    dev = torch.device("cuda")
    lat = Lattice(dev)
    length, width, height, upstream, radius, ct = 32.0, 16.0, 16.0, 8.0, 2.0, 0.6
    grid = rig_shape.Grid(dx, int(length / dx), int(width / dx), int(height / dx), -upstream, -width / 2)
    u = U_LATTICE
    rings = np.linspace(0, radius, 41)
    pts, areas = [], []
    for r0, r1 in zip(rings[:-1], rings[1:]):
        r = 0.5 * (r0 + r1)
        n = max(int(2 * math.pi * r / (dx / 3)), 6)
        for k in range(n):
            a = 2 * math.pi * (k + 0.5) / n
            pts.append([0.0, r * math.cos(a), height / 2 + r * math.sin(a)])
            areas.append(math.pi * (r1 * r1 - r0 * r0) / n)
    pts = np.array(pts)
    areas = np.array(areas)
    thrust = ct * 0.5 * u * u * math.pi * radius * radius / (dx * dx)  # lattice units
    forces = np.zeros_like(pts)
    forces[:, 0] = -thrust * areas / areas.sum()  # on the air: against the wind
    push_box, push = rig_shape._spread(pts, forces, grid, rig_shape.SPREAD_CELLS * dx, dev)
    inflow = torch.zeros(3, grid.nz, device=dev)
    inflow[0] = u
    tunnel = Tunnel(lat, grid.nx, grid.ny, grid.nz, inflow, (0, 1, 0, 1, 0, 1),
                    torch.zeros((1, 19, 1, 1, 1), dtype=torch.bool, device=dev), tau_for(dx, 10.0),
                    push_box=push_box, push=push.float(), sponge_cells=(int(2 / dx), int(3 / dx), int(2 / dx), int(2 / dx)),
                    push_ramp_steps=int(grid.nx / u / 3))
    flow_steps = int(grid.nx / u)
    result = run(tunnel, int(flow_steps * flows * 0.6), int(flow_steps * flows * 0.4), True, "disk")
    ux = result["u_mean"][0] / u
    x, y = (grid.x0 + (np.arange(grid.nx) + 0.5) * dx), (grid.y0 + (np.arange(grid.ny) + 0.5) * dx)
    z = (np.arange(grid.nz) + 0.5) * dx
    Y, Z = np.meshgrid(y, z - height / 2, indexing="ij")
    on_disk = Y ** 2 + Z ** 2 < radius ** 2
    i0 = int(np.argmin(np.abs(x)))
    at_disk = float(ux[i0][on_disk].mean())
    j_mid, k_mid = int(np.argmin(np.abs(y))), int(np.argmin(np.abs(z - height / 2)))
    wake = {f"{d:.0f}D": float(ux[int(np.argmin(np.abs(x - d * 2 * radius))), j_mid, k_mid]) for d in (1, 2, 3, 4, 5)}
    # The momentum budget from the last state: the flux of streamwise momentum (rho u u + p) through a plane
    # before the disc and one after it.
    rho_now = tunnel.f.sum(0)
    ux_now = torch.einsum("q,qxyz->xyz", lat.c[:, 0], tunnel.f) / rho_now

    def flux(i):
        return float((rho_now[i] * ux_now[i] ** 2 + rho_now[i] / 3.0).sum())
    budget = flux(int(np.argmin(np.abs(x + 4.0)))) - flux(int(np.argmin(np.abs(x - 16.0))))
    a = (1 - math.sqrt(1 - ct)) / 2
    print(f"disk: air at the disc {at_disk:.3f} of the wind (momentum theory {1 - a:.3f}); on the axis behind it "
          + ", ".join(f"{k} {v:.3f}" for k, v in wake.items()) + f" (toward {1 - 2 * a:.3f}); momentum lost "
          f"{budget:.3f} against the thrust {thrust:.3f} ({budget / thrust * 100:.0f} %); {result['seconds'] / 60:.1f} min",
          flush=True)
    return {"check": "disk", "dx_m": dx, "at_disk": at_disk, "theory_at_disk": 1 - a, "wake": wake,
            "theory_far_wake": 1 - 2 * a, "momentum_share": budget / thrust, "minutes": result["seconds"] / 60}


def check(kind: str, dx: float, flows: float, smagorinsky: float = 0.14, aligned: bool = False, aoa_deg: float = 10.0,
          small: bool = False) -> dict:
    if kind == "disk":
        return disk_check(dx, flows)
    """aligned (the wing): the wing lies along the grid and the wind comes in at the angle instead (no staircase).
    small: a 16 x 10 x 9 m tunnel (room for 5 cm cells), the same for every cell size."""
    dev = torch.device("cuda")
    lat = Lattice(dev)
    speed = 10.0
    length, width, height, upstream = (16.0, 10.0, 9.0, 5.0) if small else (32.0, 16.0, 12.0, 8.0)
    middle = height / 2
    grid = rig_shape.Grid(dx, int(length / dx), int(width / dx), int(height / dx), -upstream, -width / 2)
    if kind == "plate":
        # A 2 m square plate square to the wind, in the middle of the tunnel's height.
        pts = plate_points([0.0, 0.0, middle], [0, 1, 0], [0, 0, 1], 2.0, 2.0, int(2 / dx * 2.5), int(2 / dx * 2.5))
        area = 4.0
        expected = "drag coefficient 1.17 (Hoerner, Fluid-Dynamic Drag, 1965: a square plate, 1.16 to 1.18)"
    else:
        # A flat 2 m x 5 m wing standing up (aspect ratio 2.5), at the angle to the wind (10 degrees).
        a = math.radians(aoa_deg)
        chord_dir = [1.0, 0.0, 0.0] if aligned else [math.cos(a), math.sin(a), 0.0]
        pts = plate_points([0.0, 0.0, middle], chord_dir, [0, 0, 1], 2.0, 5.0, int(2 / dx * 2.5), int(5 / dx * 2.5))
        area = 10.0
        expected = ("lift coefficient 0.53 (Helmbold's low aspect ratio slope 2 pi A / (2 + sqrt(A^2 + 4)) at 10 "
                    "degrees) to 0.61 (Prandtl's lifting line); measured flat plates of aspect ratio 2 to 3 at "
                    "10 degrees: about 0.5 to 0.6")
    tri = rig_shape._triangles(pts)
    lo = np.floor(grid.index_of(pts.reshape(-1, 3).min(0))).astype(int) - 3
    hi = np.ceil(grid.index_of(pts.reshape(-1, 3).max(0))).astype(int) + 4
    box = (int(lo[0]), int(hi[0]), int(lo[1]), int(hi[1]), int(lo[2]), int(hi[2]))
    mask = rig_shape.membrane_link_mask(grid, box, tri, dev).unsqueeze(0)
    u = U_LATTICE
    wind_angle = math.radians(-aoa_deg) if (aligned and kind == "wing") else 0.0
    inflow = torch.zeros(3, grid.nz, device=dev)
    inflow[0] = u * math.cos(wind_angle)
    inflow[1] = u * math.sin(wind_angle)
    tunnel = Tunnel(lat, grid.nx, grid.ny, grid.nz, inflow, box, mask, tau_for(dx, speed), smagorinsky)
    flow_steps = int(grid.nx / u)
    result = run(tunnel, int(flow_steps * flows * 0.6), int(flow_steps * flows * 0.4), False, kind)
    f = result["force_lattice"][0]
    q_area = 0.5 * 1.0 * u * u * (area / (dx * dx))
    along = np.array([math.cos(wind_angle), math.sin(wind_angle), 0.0])
    cd = float(f @ along) / q_area
    cl = float(np.linalg.norm(f - (f @ along) * along)) / q_area
    print(f"{kind}: drag coefficient {cd:.3f}, lift coefficient {cl:.3f} (expected: {expected}); "
          f"{grid.nx}x{grid.ny}x{grid.nz} cells, {result['seconds'] / 60:.1f} min", flush=True)
    return {"check": kind, "dx_m": dx, "cd": float(cd), "cl": float(cl), "expected": expected,
            "minutes": result["seconds"] / 60,
            "series": result["series"]}


# --- The rig ---------------------------------------------------------------------------------------------

def load_state(path: str, case: str) -> dict:
    with open(path) as handle:
        for state in json.load(handle):
            if state["case"] == case:
                return state
    raise SystemExit(f"no case {case} in {path}")


def rig_tunnel(state: dict, twist_deg: float, dx: float, up_m: float, down_m: float, width_m: float,
               height_m: float, with_sailor: bool, with_board: bool, model: str = "actuator",
               gustiness: float = 0.0, gust_length_m: float = 6.0):
    """The tunnel set up for a steady state: (tunnel, grid, pose, frame, names, scale (lattice per m/s), info,
    solid cells). model "actuator" (the default): the rig as the game's forces on the air (rig_shape.py says
    why); "solid": the sail as a membrane, the sailor and the board as solid cells."""
    dev = torch.device("cuda")
    lat = Lattice(dev)
    pose = rig_shape.RigPose.from_state(state, twist_deg)
    frame = rig_shape.TunnelFrame(pose)
    grid = rig_shape.Grid(dx, int((up_m + down_m) / dx), int(width_m / dx), int(height_m / dx), -up_m, -width_m / 2)
    scale = U_LATTICE / pose.aws_ms
    true_wind, board_velocity = frame.winds()
    z_ce = frame.ce_height_m()
    heights = (np.arange(grid.nz) + 0.5) * dx
    gradient = (np.maximum(heights, WIND_MIN_HEIGHT_M) / z_ce) ** WIND_SHEAR_EXPONENT
    inflow_ms = np.zeros((3, grid.nz))
    inflow_ms[0] = true_wind[0] * gradient - board_velocity[0]
    inflow_ms[1] = true_wind[1] * gradient - board_velocity[1]
    fastest = float(np.max(np.hypot(inflow_ms[0], inflow_ms[1]))) * scale
    if fastest > 0.12:
        print(f"warning: the inflow reaches {fastest:.3f} cells per step at the top", flush=True)
    inflow = torch.tensor(inflow_ms * scale, dtype=torch.float32, device=dev)
    push_box = push = None
    if model == "solid":
        box, masks, solid, names, info = rig_shape.build_walls(grid, pose, dev, with_sailor, with_board)
    else:
        box = (0, 1, 0, 1, 0, 1)
        masks = torch.zeros((1, 19, 1, 1, 1), dtype=torch.bool, device=dev)
        solid = torch.zeros((1, 1, 1), dtype=torch.bool, device=dev)
        names = ["walls"]
        push_box, push, actuator = rig_shape.actuator_push(grid, pose, inflow_ms, state["sail_lift_n"],
                                                           state["sail_drag_n"], state["alpha_deg"], scale, dev,
                                                           RHO_AIR, with_sailor)
        info = {"model": "actuator", "actuator": actuator}
    # The sponges: 2 m at the inlet, the sides and the ceiling, 3 m at the outlet; the push eased in over a third
    # of the time the air takes through the tunnel.
    # With gusts the inlet has no sponge (it would calm them).
    gusts = None
    if gustiness > 0.0:
        # The gusts' size: gustiness times the true wind at the sail, per component.
        gusts = InflowTurbulence(grid.ny, grid.nz, gustiness * pose.tws_ms * scale, gust_length_m / dx, U_LATTICE,
                                 dev, calm_below_cells=max(int(0.3 / dx), 1))
    sponge = (0 if gusts else int(2.0 / dx), int(3.0 / dx), int(2.0 / dx), int(2.0 / dx))
    tunnel = Tunnel(lat, grid.nx, grid.ny, grid.nz, inflow, box, masks, tau_for(dx, pose.aws_ms),
                    push_box=push_box, push=push, sponge_cells=sponge,
                    push_ramp_steps=int(grid.nx / U_LATTICE / 3), inflow_gusts=gusts)
    info.update({"z_ce_m": z_ce, "true_wind_tunnel_ms": true_wind.tolist(),
                 "board_velocity_tunnel_ms": board_velocity.tolist(), "bow_tunnel": frame.bow_direction().tolist(),
                 "leeward_tunnel": frame.leeward_direction().tolist(), "box": list(box),
                 "solid_cells": int(solid.sum()), "inflow_ms": inflow_ms.tolist(),
                 "area_check": rig_shape.sail_area_check(pose)})
    return tunnel, grid, pose, frame, names, scale, info, solid


def forces_newton(force_lattice: np.ndarray, dx: float, scale: float) -> np.ndarray:
    """Lattice force to newtons: F = F_lattice * rho_air * dx^2 / scale^2 (scale: lattice velocity per m/s)."""
    return force_lattice * RHO_AIR * dx * dx / (scale * scale)


def force_summary(names, force_n: np.ndarray, state: dict, pose: rig_shape.RigPose, info: dict = None) -> dict:
    """The sail's drag (along the apparent wind) and lift (across it, the whole force square to the wind),
    the sailor's and the board's drag, against the physics'. For the actuator model: the forces it applied."""
    out = {}
    q = 0.5 * RHO_AIR * pose.aws_ms ** 2
    if info is not None and info.get("model") == "actuator":
        sail = np.array(info["actuator"]["sail_force_n"])
        out["sail"] = {"drag_n": float(sail[0]), "side_n": float(sail[1]), "up_n": float(sail[2]),
                       "lift_n": float(math.hypot(sail[1], sail[2]))}
        if "sailor_force_n" in info["actuator"]:
            body = np.array(info["actuator"]["sailor_force_n"])
            out["sailor"] = {"drag_n": float(body[0]), "side_n": float(body[1]), "drag_area_m2": float(body[0]) / q}
        out["physics"] = {"lift_n": state["sail_lift_n"], "drag_n": state["sail_drag_n"],
                          "sailor_windage_drag_n": q * 0.5}
        out["model"] = "actuator"
        return out
    for name, f in zip(names, force_n):
        out[name] = {"drag_n": float(f[0]), "side_n": float(f[1]), "up_n": float(f[2]),
                     "lift_n": float(math.hypot(f[1], f[2]))}
    sail = out["sail"]
    sail["cl"] = sail["lift_n"] / (q * rig_shape.SAIL_AREA_M2)
    sail["cd"] = sail["drag_n"] / (q * rig_shape.SAIL_AREA_M2)
    out["physics"] = {"lift_n": state["sail_lift_n"], "drag_n": state["sail_drag_n"],
                      "sailor_windage_drag_n": q * 0.5}
    if "sailor" in out:
        out["sailor"]["drag_area_m2"] = out["sailor"]["drag_n"] / q
    return out


def force_run(state: dict, twist_deg: float, dx: float, opts: dict) -> dict:
    """The rig in a short tunnel: its force, to calibrate the twist."""
    tunnel, grid, pose, frame, names, scale, info, _ = rig_tunnel(
        state, twist_deg, dx, 5.0, 13.0, 18.0, 10.0, opts.get("no_sailor") != "1", opts.get("no_board") != "1")
    flow_steps = int(grid.nx / U_LATTICE)
    flows = float(opts.get("flows", "2.5"))
    result = run(tunnel, int(flow_steps * (flows - 1.0)), flow_steps, False, f"{state['case']} twist {twist_deg:.1f}")
    force_n = forces_newton(result["force_lattice"], dx, scale)
    summary = force_summary(names, force_n, state, pose)
    print(f"twist {twist_deg:5.1f}: sail lift {summary['sail']['lift_n']:6.0f} N (physics {state['sail_lift_n']:.0f}), "
          f"drag {summary['sail']['drag_n']:5.0f} N (physics {state['sail_drag_n']:.0f})"
          + (f", sailor drag area {summary['sailor']['drag_area_m2']:.2f} m2 (physics 0.50)" if "sailor" in summary else ""),
          flush=True)
    del tunnel
    torch.cuda.empty_cache()
    return {"twist_deg": twist_deg, "forces": summary, "minutes": result["seconds"] / 60, "info": info,
            "series": result["series"]}


def calibrate(state: dict, dx: float, opts: dict) -> dict:
    """The twist at which the sail's lift is the physics' lift (the secant method on a few short runs)."""
    target = state["sail_lift_n"]
    tries = []
    for twist in (5.0, 20.0):
        tries.append(force_run(state, twist, dx, opts))
    for _ in range(3):
        (t0, l0), (t1, l1) = [(r["twist_deg"], r["forces"]["sail"]["lift_n"]) for r in tries[-2:]]
        if abs(l1 - target) < 0.04 * target or abs(l1 - l0) < 1e-6:
            break
        twist = t1 + (target - l1) * (t1 - t0) / (l1 - l0)
        twist = float(np.clip(twist, -5.0, 45.0))
        tries.append(force_run(state, twist, dx, opts))
        if twist in (-5.0, 45.0):
            break
    best = min(tries, key=lambda r: abs(r["forces"]["sail"]["lift_n"] - target))
    print(f"calibrated twist for {state['case']}: {best['twist_deg']:.1f} degrees "
          f"(lift {best['forces']['sail']['lift_n']:.0f} N against {target:.0f})", flush=True)
    return {"case": state["case"], "twist_deg": best["twist_deg"], "tries": tries}


def wake_run(state: dict, twist_deg: float, dx: float, opts: dict, out_dir: str) -> dict:
    """The long tunnel: the force and the time-averaged wind behind the rig, saved for analyse_wake.py."""
    # The tunnel: 8 m before the rig, 50 m after it, 40 m wide, 16 m tall (13 November 2026: in 26 x 12 m the
    # sail's vortex system reached the walls and the shadow read 5 to 20 % weaker beyond 20 m).
    down = float(opts.get("down_m", "50"))
    width = float(opts.get("width_m", "40"))
    height = float(opts.get("height_m", "16"))
    gustiness = float(opts.get("gusts", "0.11"))
    tunnel, grid, pose, frame, names, scale, info, solid = rig_tunnel(
        state, twist_deg, dx, 8.0, down, width, height, opts.get("no_sailor") != "1", opts.get("no_board") != "1",
        opts.get("model", "actuator"), gustiness, float(opts.get("gust_length_m", "6")))
    info["gustiness"] = gustiness
    flow_steps = int(grid.nx / U_LATTICE)
    # Gusty air needs long averages (the gusts' noise in the mean falls as one over the square root of the time:
    # 17 flows, about a minute of real air, puts it near 0.4 % of the wind; about 44 minutes on an RTX 3080 Ti, the
    # 45 Michiel allowed a test); smooth air settles in a few.
    flows = float(opts.get("flows", "17" if gustiness > 0 else "6"))
    spin = int(flow_steps * 1.5)
    average = int(flow_steps * (flows - 1.5))
    print(f"{state['case']}: {grid.nx}x{grid.ny}x{grid.nz} = {grid.nx * grid.ny * grid.nz / 1e6:.1f} M cells, "
          f"{spin + average} steps (one step {dx * scale * 1000:.2f} ms of real time)", flush=True)
    result = run(tunnel, spin, average, True, state["case"])
    force_n = forces_newton(result["force_lattice"], dx, scale)
    summary = force_summary(names, force_n, state, pose, info)
    u_mean = result["u_mean"] / scale
    speed2 = result["u2_mean"] / (scale * scale)
    fluct = np.sqrt(np.maximum(speed2 - (u_mean ** 2).sum(0), 0.0))
    x0, x1, y0, y1, z0, z1 = info["box"]
    solid_np = solid.cpu().numpy()
    for comp in range(3):
        u_mean[comp, x0:x1, y0:y1, z0:z1][solid_np] = np.nan
    fluct[x0:x1, y0:y1, z0:z1][solid_np] = np.nan
    os.makedirs(out_dir, exist_ok=True)
    tag = opts.get("tag", "")
    model_tag = ("" if opts.get("model", "actuator") == "actuator" else "_solid") + \
        ("" if gustiness > 0 else "_calm")
    stem = os.path.join(out_dir, f"{state['case']}_dx{int(round(dx * 100)):02d}{model_tag}{tag}")
    # The pressure, as the air's density less 1 in lattice units (p = rho / 3 there); with the scale it is the
    # momentum check's missing half (analyse_wake.momentum_check()).
    np.savez_compressed(stem + ".npz", u_mean=u_mean.astype(np.float16), fluct=fluct.astype(np.float16),
                        rho_dev=result["rho_dev_mean"].astype(np.float32), scale=np.float64(scale))
    meta = {"case": state["case"], "state": state, "twist_deg": twist_deg, "dx_m": dx, "nx": grid.nx, "ny": grid.ny,
            "nz": grid.nz, "x0_m": grid.x0, "y0_m": grid.y0, "forces": summary, "info": info,
            "minutes": result["seconds"] / 60, "steps": result["steps"], "series": result["series"],
            "pose": {"awa_deg": pose.awa_deg, "aws_ms": pose.aws_ms, "twa_deg": pose.twa_deg, "tws_ms": pose.tws_ms,
                     "sheet_angle_deg": pose.sheet_angle_deg, "rake_deg": pose.rake_deg, "lean_deg": pose.lean_deg}}
    with open(stem + ".json", "w") as handle:
        json.dump(meta, handle, indent=1)
    print(f"{state['case']}: sail lift {summary['sail']['lift_n']:.0f} N (physics {state['sail_lift_n']:.0f}), "
          f"drag {summary['sail']['drag_n']:.0f} N (physics {state['sail_drag_n']:.0f}); written {stem}.npz "
          f"({result['seconds'] / 60:.1f} min)", flush=True)
    return meta


def main() -> None:
    opts = options()
    dx = float(opts.get("dx", "0.15"))
    out_dir = opts.get("out", ".sim_output/cfd")
    os.makedirs(out_dir, exist_ok=True)
    print(torch.__version__, torch.cuda.get_device_name(0), flush=True)
    if "check" in opts:
        result = check(opts["check"], dx, float(opts.get("flows", "3")), float(opts.get("smag", "0.14")),
                       opts.get("aligned") == "1", float(opts.get("aoa", "10")), opts.get("small") == "1")
        with open(os.path.join(out_dir, f"check_{opts['check']}_dx{int(round(dx * 100)):02d}.json"), "w") as handle:
            json.dump(result, handle, indent=1)
        return
    state = load_state(opts.get("states", ".sim_output/reach/steady_states.json"), opts["case"])
    mode = opts.get("mode", "wake")
    if mode == "force":
        result = force_run(state, float(opts.get("twist", "15")), dx, opts)
        path = os.path.join(out_dir, f"force_{state['case']}_dx{int(round(dx * 100)):02d}.json")
    elif mode == "calibrate":
        result = calibrate(state, dx, opts)
        path = os.path.join(out_dir, f"calibrate_{state['case']}_dx{int(round(dx * 100)):02d}.json")
    else:
        twist = opts.get("twist")
        if twist is None and opts.get("model", "actuator") == "actuator":
            twist = "10"  # only where the force sits (the leech a little to leeward at the head); an estimate
        if twist is None:
            calib = os.path.join(out_dir, f"calibrate_{state['case']}_dx{int(round(dx * 100)):02d}.json")
            with open(calib) as handle:
                twist = json.load(handle)["twist_deg"]
        wake_run(state, float(twist), dx, opts, out_dir)
        return
    with open(path, "w") as handle:
        json.dump(result, handle, indent=1)
    print("written", path)


if __name__ == "__main__":
    main()
