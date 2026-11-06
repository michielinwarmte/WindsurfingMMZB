"""What more (or differently spaced) wave trains would do to the individual waves (PH44; the report
Documentation/reports/waves/swan_silvaplana.md, "What we can do").

The game's lake is four trains, one per octave (8, 4, 2 and 1 m long). In deep water a wave's
frequency goes as one over the square root of its length, so the 2 m train has exactly twice the
frequency of the 8 m one and the 1 m train exactly twice that of the 4 m one: at a fixed point those
pairs keep the same shape for ever, and their crests can never all meet there.

This takes the JONSWAP spectrum of a point (the model's Hs and Tp: by default the start spot at
18 kt), keeps the part the physics floats on (0.71 to 11.3 m long: the four octaves), and builds it
from N trains in different ways. For each it measures, at one point over 20 minutes (zero-down-
crossing, as wave_statistics.py), the median over 40 random sets of phases: H1/3, the highest wave
and how many waves are higher than 1.5 x Hs. The surface is linear (a plain sum of sines): the
game's Gerstner shape sharpens the crests a little but hardly changes the heights crest to trough.
    python -I tools/map/wave_options.py [--hs=0.178] [--tp=1.47]
"""

import argparse
import math

import numpy as np

from wave_statistics import G, jonswap_shape, summary, waves_of

STEP_S = 0.05
MINUTES = 20.0
SEEDS = 40


def omega_of_length(length_m: np.ndarray) -> np.ndarray:
    return np.sqrt(G * 2 * math.pi / length_m)


def band_energy(hs: float, tp: float, low_hz: np.ndarray, high_hz: np.ndarray) -> np.ndarray:
    """Each band's share of the spectrum's energy m0 = (Hs / 4)^2 (integrated numerically)."""
    fp = 1.0 / tp
    f = np.linspace(0.2 * fp, 12.0 * fp, 20000)
    s = jonswap_shape(f, fp)
    total = np.trapezoid(s, f)
    out = []
    for lo, hi in zip(low_hz, high_hz):
        part = (f >= lo) & (f < hi)
        out.append(np.trapezoid(s[part], f[part]) / total * (hs / 4.0) ** 2)
    return np.array(out)


def surface(freq_hz: np.ndarray, amplitude: np.ndarray, phase: np.ndarray) -> np.ndarray:
    t = np.arange(int(MINUTES * 60 / STEP_S)) * STEP_S
    return (amplitude[:, None] * np.sin(2 * math.pi * freq_hz[:, None] * t[None, :] + phase[:, None])).sum(axis=0)


def octave_trains(hs, tp, rng, shift: bool) -> tuple:
    """The game's way: one train per octave at 8, 4, 2, 1 m (shift: each train's length moved at
    random within its octave, so the frequencies are no longer exact multiples)."""
    lengths = np.array([8.0, 4.0, 2.0, 1.0])
    f_long = omega_of_length(lengths * math.sqrt(2)) / (2 * math.pi)
    f_short = omega_of_length(lengths / math.sqrt(2)) / (2 * math.pi)
    energy = band_energy(hs, tp, f_long, f_short)
    if shift:
        lengths = lengths * 2 ** (rng.random(4) - 0.5)
    freq = omega_of_length(lengths) / (2 * math.pi)
    return freq, np.sqrt(2 * energy)


def split_trains(hs, tp, rng, count: int) -> tuple:
    """count trains, the same four octaves cut into count equal steps of log frequency, each train at
    a random frequency within its step (the usual way to build a random sea)."""
    f_lo = omega_of_length(np.array([8.0 * math.sqrt(2)])) / (2 * math.pi)
    f_hi = omega_of_length(np.array([1.0 / math.sqrt(2)])) / (2 * math.pi)
    edges = np.geomspace(f_lo[0], f_hi[0], count + 1)
    energy = band_energy(hs, tp, edges[:-1], edges[1:])
    freq = edges[:-1] * (edges[1:] / edges[:-1]) ** rng.random(count)
    return freq, np.sqrt(2 * energy)


def grouped_trains(hs, tp, rng, depth: float) -> tuple:
    """The game's four octave trains, each with a travelling envelope 1 + depth cos(...) that makes
    wave groups (sets): a train a (1 + m cos(dw t)) sin(w t) is the same as three trains at w - dw,
    w and w + dw with amplitudes a m / 2, a, a m / 2; the energy is kept (a scaled by 1/sqrt(1 + m^2/2))."""
    freq, amplitude = octave_trains(hs, tp, rng, shift=True)
    keep = 1.0 / math.sqrt(1.0 + depth * depth / 2.0)
    group = 0.12 + 0.06 * rng.random(4)  # sets every 6 to 8 waves (an estimate of a wind sea's groups)
    f_all, a_all = [], []
    for f, a, g in zip(freq, amplitude * keep, group):
        f_all += [f * (1 - g), f, f * (1 + g)]
        a_all += [a * depth / 2, a, a * depth / 2]
    return np.array(f_all), np.array(a_all)


def measure(name: str, builder, hs: float, tp: float, trains: int) -> None:
    rows = []
    for seed in range(SEEDS):
        rng = np.random.default_rng(seed)
        freq, amplitude = builder(hs, tp, rng)
        phase = rng.random(len(freq)) * 2 * math.pi
        rows.append(summary(waves_of(surface(freq, amplitude, phase), STEP_S)))
    med = lambda key: float(np.median([r[key] for r in rows]))
    p = lambda key, q: float(np.percentile([r[key] for r in rows], q))
    print(f"| {name} | {trains} | {med('hm0'):.3f} m | {med('h13'):.2f} Hs | {med('hmax'):.2f} ({p('hmax', 5):.2f}-{p('hmax', 95):.2f}) Hs | "
          f"{med('over_15'):.0f} | {med('over_12'):.0f} |")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--hs", type=float, default=0.178)
    parser.add_argument("--tp", type=float, default=1.47)
    args = parser.parse_args()
    hs, tp = args.hs, args.tp
    print(f"The spectrum: Hs {hs} m, Tp {tp} s (JONSWAP, peak enhancement 3.3); the part 0.71 to 11.3 m long; one point, 20 minutes, median of {SEEDS} phase sets.")
    print("| How the sea is built | Trains (the cost scales with this) | Hm0 of the part | H1/3 | Highest wave | Waves over 1.5 Hs | Over 1.2 Hs |")
    print("|---|---|---|---|---|---|---|")
    measure("Today: one train per octave, 8/4/2/1 m (frequencies locked 2:1)", lambda h, t, r: octave_trains(h, t, r, False), hs, tp, 4)
    measure("One per octave, each length moved at random within its octave", lambda h, t, r: octave_trains(h, t, r, True), hs, tp, 4)
    for count in [6, 8, 12, 16, 32]:
        measure(f"{count} trains, random frequencies within equal log steps", lambda h, t, r, c=count: split_trains(h, t, r, c), hs, tp, count)
    for depth in [0.5, 0.8]:
        measure(f"One per octave (moved) with a travelling group envelope, depth {depth}", lambda h, t, r, d=depth: grouped_trains(h, t, r, d), hs, tp, 4)


if __name__ == "__main__":
    main()
