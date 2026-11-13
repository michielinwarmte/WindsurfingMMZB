"""Gusty air coming into the wind tunnel (PH15): the turbulence of the wind over open water, made by random
Fourier modes (Kraichnan 1970; Smirnov, Shi and Celik 2001): a sum of many swirling waves of random direction and
phase, sized by the von Karman spectrum, each wave square to its own direction so the air neither piles up nor
thins out. The field is frozen and carried in with the apparent wind (Taylor's hypothesis): the inlet sees it slide
past at the apparent wind's speed.

Why: a wake recovers mostly by mixing with the gusty air around it (wind-farm studies find the ambient turbulence
sets a turbine wake's length); smooth inflow gives the longest possible shadow. Over open water at a sail's height
the wind's gustiness is about 10 % of its speed (about 1 / ln(z / z0) with z0 = 0.2 mm at 2 m).
"""
import math

import torch


class InflowTurbulence:
    """turbulence(step) -> (3, ny, nz) the gusts at the inlet, lattice units.

    intensity_lattice: the gusts' rms speed per component (lattice units), before the field's own normalising.
    length_cells: the von Karman length scale, in cells. convect_lattice: how fast the field slides in (cells/step).
    Below calm_below_cells the gusts fade to nothing at the water (the slippery floor)."""

    def __init__(self, ny: int, nz: int, intensity_lattice: float, length_cells: float, convect_lattice: float,
                 device, modes: int = 256, seed: int = 7, calm_below_cells: int = 3):
        gen = torch.Generator(device="cpu").manual_seed(seed)
        self.convect = convect_lattice
        k_e = 0.747 / length_cells                            # the spectrum's peak (von Karman)
        k_min = 2 * math.pi / max(ny, nz)                       # the largest eddy the tunnel holds
        k_max = 2 * math.pi / 4.0                               # the smallest the cells carry (4 cells a wave)
        k = torch.exp(torch.linspace(math.log(k_min), math.log(k_max), modes + 1))
        k_mid = torch.sqrt(k[1:] * k[:-1])
        dk = k[1:] - k[:-1]
        energy = (k_mid / k_e) ** 4 / (1 + (k_mid / k_e) ** 2) ** (17.0 / 6.0)
        amplitude = torch.sqrt(energy * dk)
        # Random wave directions on the sphere, and a swirl direction square to each.
        d = torch.randn(modes, 3, generator=gen)
        d /= d.norm(dim=1, keepdim=True)
        s = torch.cross(d, torch.randn(modes, 3, generator=gen), dim=1)
        s /= s.norm(dim=1, keepdim=True)
        phase = 2 * math.pi * torch.rand(modes, generator=gen)
        self.wave = (k_mid[:, None] * d).to(device)            # (modes, 3) wave vectors, per cell
        self.swirl = (amplitude[:, None] * s).to(device)      # (modes, 3)
        self.phase = phase.to(device)
        y = torch.arange(ny, device=device, dtype=torch.float32)
        z = torch.arange(nz, device=device, dtype=torch.float32)
        self.y, self.z = torch.meshgrid(y, z, indexing="ij")
        taper = torch.clamp(z / max(calm_below_cells, 1), max=1.0)
        self.taper = taper.view(1, 1, nz)
        # Normalise: the field's rms per component over many steps is the intensity asked for.
        sample = torch.stack([self._raw(t) for t in range(0, 4000, 40)])
        rms = float(sample[:, :, :, nz // 4:].pow(2).mean().sqrt())
        self.gain = intensity_lattice / max(rms, 1e-12)

    def _raw(self, step: int) -> torch.Tensor:
        x = -self.convect * step
        arg = (self.wave[:, 0, None, None] * x + self.wave[:, 1, None, None] * self.y
               + self.wave[:, 2, None, None] * self.z + self.phase[:, None, None])  # (modes, ny, nz)
        return torch.einsum("mc,myz->cyz", self.swirl, torch.cos(arg)) * self.taper

    def __call__(self, step: int) -> torch.Tensor:
        return self._raw(step) * self.gain
