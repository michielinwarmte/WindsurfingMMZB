"""The air solver of the wind tunnel (PH15): a lattice-Boltzmann method on the GPU, in PyTorch.

In plain words. The air is cut into small cubes ("cells") of side dx. Each cell keeps 19 numbers: how much air
in it is moving in each of 19 directions (standing still, toward the 6 faces, toward the 12 edges). One time
step does two things:

1. Collision. In every cell the 19 numbers relax toward the mix that belongs to the cell's density and
   velocity (the "equilibrium"). How quickly they relax sets the air's viscosity. Air at a sail's scale is
   turbulent, and cells of 10 cm cannot hold its small eddies, so a turbulence model (Smagorinsky's) adds the
   eddies' extra viscosity wherever the flow is sheared. The "regularised" collision keeps the method
   stable at this almost-zero viscosity.
2. Streaming. Every number moves one cell along its own direction.

Walls: a number that would cross a wall (the sail, the sailor, the board) is sent back the way it came
("bounce-back"), which stops the air at the wall; the momentum it hands over is the force on the wall.
The water and the tunnel's ceiling are slippery: a number going into them comes back mirrored, so the air
slides along them. (13 November 2026: a floor moving at the board's speed, bouncing the air with the water's
speed, made this method unstable at air's own viscosity: a disturbance of a millionth grew into a jet in 3000
steps. The few centimetres of air the water drags along are far below a 10 cm cell; the wind's height profile,
which matters, comes in with the inflow.)

Everything is in lattice units: dx = 1, dt = 1, density about 1. wind_tunnel.py converts.
The axes: x downstream (along the apparent wind at the sail), y across, z up.
"""
import math

import torch

# The 19 directions (x, y, z): rest, the 6 faces, the 12 edges.
DIRECTIONS = [
    (0, 0, 0),
    (1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1),
    (1, 1, 0), (-1, -1, 0), (1, -1, 0), (-1, 1, 0),
    (1, 0, 1), (-1, 0, -1), (1, 0, -1), (-1, 0, 1),
    (0, 1, 1), (0, -1, -1), (0, 1, -1), (0, -1, 1),
]
WEIGHTS = [1.0 / 3.0] + [1.0 / 18.0] * 6 + [1.0 / 36.0] * 12
# The direction opposite each one (a bounce sends a number back along it).
OPPOSITE = [DIRECTIONS.index((-x, -y, -z)) for (x, y, z) in DIRECTIONS]
# The direction mirrored in a horizontal plane (the tunnel's slippery ceiling).
MIRROR_Z = [DIRECTIONS.index((x, y, -z)) for (x, y, z) in DIRECTIONS]
GOING_UP = [i for i, d in enumerate(DIRECTIONS) if d[2] == 1]
GOING_DOWN = [i for i, d in enumerate(DIRECTIONS) if d[2] == -1]
GOING_UPSTREAM = [i for i, d in enumerate(DIRECTIONS) if d[0] == -1]


class Lattice:
    """The directions and weights as tensors on the GPU, and the tensors the collision needs."""

    def __init__(self, device: torch.device):
        self.device = device
        self.c = torch.tensor(DIRECTIONS, dtype=torch.float32, device=device)  # (19, 3)
        self.w = torch.tensor(WEIGHTS, dtype=torch.float32, device=device)  # (19,)
        self.opposite = torch.tensor(OPPOSITE, dtype=torch.int64, device=device)
        cx, cy, cz = self.c[:, 0], self.c[:, 1], self.c[:, 2]
        # The six parts of the momentum flux a direction carries: xx, yy, zz, xy, xz, yz. The cross terms are
        # counted twice in the full tensor, hence the 2 in the regularised collision's weights below.
        self.cc = torch.stack([cx * cx, cy * cy, cz * cz, cx * cy, cx * cz, cy * cz], dim=1)  # (19, 6)
        third = 1.0 / 3.0
        self.hermite = torch.stack([cx * cx - third, cy * cy - third, cz * cz - third,
                                    2 * cx * cy, 2 * cx * cz, 2 * cy * cz], dim=1)  # (19, 6)

    def equilibrium(self, rho: torch.Tensor, u: torch.Tensor) -> torch.Tensor:
        """The 19 numbers of air at rest-frame density rho moving at velocity u (u: (3, ...))."""
        cu = torch.einsum("qd,d...->q...", self.c, u)
        usq = (u * u).sum(0)
        shape = (19,) + (1,) * rho.dim()
        return self.w.view(shape) * rho * (1.0 + 3.0 * cu + 4.5 * cu * cu - 1.5 * usq)


def collide(lat: Lattice, f: torch.Tensor, tau0: float, smagorinsky: float):
    """One collision in every cell. Returns the numbers after it, and the density and velocity before it."""
    rho = f.sum(0)
    u = torch.einsum("qd,qxyz->dxyz", lat.c, f) / rho
    feq = lat.equilibrium(rho, u)
    fneq = f - feq
    # The part of the momentum flux that is not in equilibrium: it measures how sheared the flow is.
    pi = torch.einsum("qk,qxyz->kxyz", lat.cc, fneq)
    pi_size = torch.sqrt(pi[0] ** 2 + pi[1] ** 2 + pi[2] ** 2 + 2.0 * (pi[3] ** 2 + pi[4] ** 2 + pi[5] ** 2))
    # Smagorinsky: the eddies' viscosity grows with the shear (Hou et al. 1996's closed form for the
    # relaxation time).
    tau = 0.5 * (tau0 + torch.sqrt(tau0 * tau0 + 18.0 * math.sqrt(2.0) * smagorinsky ** 2 * pi_size / rho))
    # Regularised: keep only the momentum-flux part of the non-equilibrium (drops the noise that makes the
    # plain method blow up at this low viscosity).
    fneq_reg = 4.5 * lat.w.view(19, 1, 1, 1) * torch.einsum("qk,kxyz->qxyz", lat.hermite, pi)
    f_post = feq + (1.0 - 1.0 / tau) * fneq_reg
    return f_post, rho, u


def stream(f_post: torch.Tensor) -> torch.Tensor:
    """Every number moves one cell along its direction (the domain wraps around; the walls fix the edges)."""
    return torch.stack([torch.roll(f_post[i], shifts=DIRECTIONS[i], dims=(0, 1, 2)) for i in range(19)])


def collide_with_sponge(lat: Lattice, f: torch.Tensor, tau0: float, smagorinsky: float, sponge: torch.Tensor,
                        f_calm: torch.Tensor):
    """The collision, then the sponge: in the tunnel's edge layers the air is pulled a share sponge (0 inside the
    tunnel, up to about 0.1 a step at its very edge) back toward the calm inflow f_calm, so the pressure waves that
    reach them (the push starting up, the gusts) are absorbed instead of bouncing round the tunnel. (13 November
    2026: added for a flicker of 17 % of the wind everywhere, which turned out to be the method's own 2-step flicker,
    cured by the viscosity floor in wind_tunnel.py; the sponge stays as a guard.)"""
    f_post, rho, u = collide(lat, f, tau0, smagorinsky)
    f_post = f_post - sponge * (f_post - f_calm)
    return f_post, rho, u


def _collide_for_check(lat, f, tau0, smagorinsky, sponge, f_calm):
    return collide_with_sponge(lat, f, tau0, smagorinsky, sponge, f_calm)


def _stream_for_check(f_post):
    return stream(f_post)


def push_air(lat: Lattice, f_post: torch.Tensor, rho: torch.Tensor, u: torch.Tensor, push: torch.Tensor) -> None:
    """Gives the air in some cells a push (a force per cell per step, lattice units), in place: the "exact
    difference" method (Kupershtokh 2004), the numbers moved from the equilibrium at the cell's velocity to the
    equilibrium at the velocity the push gives it. This is how the sail and the sailor act on the air in the
    actuator model (rig_shape.actuator_push())."""
    f_post += lat.equilibrium(rho, u + push / rho) - lat.equilibrium(rho, u)


def make_sponge(nx: int, ny: int, nz: int, cells: tuple, device) -> torch.Tensor:
    """The sponge's strength in every cell: 0 inside, rising as the square of the depth into the edge layers to
    0.1 at the edge. cells = (inlet, outlet, each side, ceiling) layer thicknesses in cells; the water has none
    (the wake near it matters)."""
    inlet, outlet, side, ceiling = cells

    def ramp(n: int, start: int, end: int) -> torch.Tensor:
        r = torch.zeros(n, device=device)
        if start > 0:
            r[:start] = ((start - torch.arange(start, device=device, dtype=torch.float32)) / start) ** 2
        if end > 0:
            r[n - end:] = torch.maximum(r[n - end:], ((torch.arange(end, device=device, dtype=torch.float32) + 1) / end) ** 2)
        return r
    sx = ramp(nx, inlet, outlet).view(nx, 1, 1)
    sy = ramp(ny, side, side).view(1, ny, 1)
    sz = ramp(nz, 0, ceiling).view(1, 1, nz)
    return (0.1 * torch.maximum(torch.maximum(sx, sy), sz)).contiguous()


class Tunnel:
    """The whole tunnel: the air, its boundaries, the walls in it and the pushes on it.

    inflow_u: (3, nz) the air's velocity coming in at each height (lattice units).
    box: (x0, x1, y0, y1, z0, z1) the part of the tunnel that holds the walls.
    link_masks: (objects, 19, bx, by, bz) bool, per wall object: the number arriving in this cell along this
        direction came through the object (it is bounced back instead).
    push_box, push: optional, a part of the tunnel and the force on the air in each of its cells (3, bx, by, bz),
        lattice units (the actuator model's sail and sailor).

    The collision and the streaming are compiled (torch.compile, about twice as fast); the boundaries and the
    push are applied in plain PyTorch between and after them. (13 November 2026: a uniform flow drifting into a
    jet along the water was first blamed on the compiler; it was the moving floor, see the top. The compiled
    parts are still compared with plain PyTorch before every run, check_compiled().)
    """

    def __init__(self, lat: Lattice, nx: int, ny: int, nz: int, inflow_u: torch.Tensor, box: tuple,
                 link_masks: torch.Tensor, tau0: float, smagorinsky: float = 0.14, push_box: tuple = None,
                 push: torch.Tensor = None, sponge_cells: tuple = (0, 0, 0, 0), push_ramp_steps: int = 0,
                 inflow_gusts=None):
        self.lat = lat
        self.nx, self.ny, self.nz = nx, ny, nz
        self.tau0 = tau0
        self.smagorinsky = smagorinsky
        self.box = box
        self.link_masks = link_masks
        self.any_mask = link_masks.any(0)
        self.push_box = push_box
        self.push = push
        self.push_ramp_steps = push_ramp_steps
        self.steps_done = 0
        # Optional gusts on the inflow (inflow_turbulence.InflowTurbulence: step -> (3, ny, nz), lattice units).
        self.inflow_gusts = inflow_gusts
        self.inflow_u = inflow_u
        dev = lat.device
        # The air coming in: the same at every y, its own velocity at every height.
        rho_in = torch.ones(ny, nz, device=dev)
        u_in = inflow_u.view(3, 1, nz).expand(3, ny, nz)
        self.f_inflow = lat.equilibrium(rho_in, u_in).contiguous()  # (19, ny, nz)
        # The slippery water and ceiling: what goes into them comes back mirrored in the horizontal plane.
        self.up = torch.tensor(GOING_UP, device=dev)
        self.down = torch.tensor(GOING_DOWN, device=dev)
        self.upstream = torch.tensor(GOING_UPSTREAM, device=dev)
        self.up_from = torch.tensor([MIRROR_Z[i] for i in GOING_UP], device=dev)
        self.down_from = torch.tensor([MIRROR_Z[i] for i in GOING_DOWN], device=dev)
        # The air starts as the inflow everywhere.
        self.f = self.f_inflow.view(19, 1, ny, nz).expand(19, nx, ny, nz).contiguous()
        self.f_calm = self.f_inflow.view(19, 1, ny, nz)
        self.sponge = make_sponge(nx, ny, nz, sponge_cells, dev)
        self._collide = torch.compile(collide_with_sponge)
        self._stream = torch.compile(stream)
        self.check_compiled()

    def check_compiled(self) -> None:
        """The compiled collision and streaming against plain PyTorch on a disturbed block of the air: they must
        agree to float32's rounding, or the run stops. (Through wrappers of their own, so the check's small block
        does not change how the tunnel's full-size step is compiled; a full-size copy would not fit beside a wake
        run.)"""
        torch.manual_seed(1)
        f = self.f[:, :48, :32, :24].clone()
        f = f * (1.0 + 0.02 * torch.randn_like(f))
        sponge = self.sponge[:48, :32, :24].contiguous()
        calm = self.f_calm[:, :, :32, :24].contiguous()
        plain = collide_with_sponge(self.lat, f, self.tau0, self.smagorinsky, sponge, calm)[0]
        compiled = torch.compile(_collide_for_check)(self.lat, f, self.tau0, self.smagorinsky, sponge, calm)[0]
        worst = float((plain - compiled).abs().max())
        worst = max(worst, float((stream(plain) - torch.compile(_stream_for_check)(plain)).abs().max()))
        if worst > 1e-5:
            raise RuntimeError(f"the compiled step differs from plain PyTorch by {worst}")

    def _step_eager(self, f: torch.Tensor):
        lat = self.lat
        f_post, rho, u = self._collide(lat, f, self.tau0, self.smagorinsky, self.sponge, self.f_calm)
        if self.push is not None:
            # The sail and the sailor push the air (eased in over the first steps, so the start sends no pressure
            # wave round the tunnel); the air's velocity there is the mean over the step.
            x0, x1, y0, y1, z0, z1 = self.push_box
            ramp = 1.0 if self.push_ramp_steps <= 0 else min(1.0, self.steps_done / self.push_ramp_steps)
            push = self.push * ramp
            rho_box = rho[x0:x1, y0:y1, z0:z1]
            u_box = u[:, x0:x1, y0:y1, z0:z1]
            push_air(lat, f_post[:, x0:x1, y0:y1, z0:z1], rho_box, u_box, push)
            u[:, x0:x1, y0:y1, z0:z1] = u_box + 0.5 * push / rho_box
        self.steps_done += 1
        f_new = self._stream(f_post)
        # The water slips: the numbers that arrived going up came from below it; they are the mirror of those that
        # went down into it.
        f_new[self.up, :, :, 0] = f_post[self.up_from, :, :, 0]
        # The ceiling slips the same way.
        f_new[self.down, :, :, -1] = f_post[self.down_from, :, :, -1]
        # The walls in the box: a number that came through a wall is the one that went into it, sent back.
        x0, x1, y0, y1, z0, z1 = self.box
        post_into_wall = f_post[lat.opposite, x0:x1, y0:y1, z0:z1]
        arrived = f_new[:, x0:x1, y0:y1, z0:z1]
        f_new[:, x0:x1, y0:y1, z0:z1] = torch.where(self.any_mask, post_into_wall, arrived)
        # The force on each wall object: every bounce turns a number's momentum around (twice it, onto the wall).
        hits = (self.link_masks * post_into_wall.unsqueeze(0)).sum((2, 3, 4))  # (objects, 19)
        forces = -2.0 * hits @ lat.c  # (objects, 3)
        # The way out: the numbers coming back in from beyond it are taken from the cell before.
        f_new[self.upstream, -1] = f_new[self.upstream, -2]
        # The way in: the inflow as it is, or with the gusts sliding in.
        if self.inflow_gusts is None:
            f_new[:, 0] = self.f_inflow
        else:
            u_in = self.inflow_u.view(3, 1, self.nz) + self.inflow_gusts(self.steps_done)
            f_new[:, 0] = lat.equilibrium(torch.ones(self.ny, self.nz, device=f.device), u_in)
        return f_new, rho, u, forces

    def step(self):
        """One time step. Returns the density and velocity (before the step) and the forces on the objects."""
        self.f, rho, u, forces = self._step_eager(self.f)
        return rho, u, forces
