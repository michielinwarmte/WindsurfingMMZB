"""Which way do the rendered waves run and move? Two top-down screenshots half a second apart.

The water texture is Fourier-analysed: the strongest long-wave component (100 to 300 px long)
gives the crest orientation; the phase difference between the two frames at that wave vector
gives the shift along it (sign = travel direction on screen). The grid's 5 m lines (about 40 to
70 px) give the world axes on screen.
"""
import sys
import numpy as np
from PIL import Image, ImageFilter

a_path, b_path = sys.argv[1], sys.argv[2]


def load(path):
    img = Image.open(path).convert("L")
    w, h = img.size
    img = img.crop((0, 60, min(w, 1100), h))  # away from the HUD line and the compass rose
    g = np.asarray(img, dtype=np.float64)
    blur = np.asarray(Image.fromarray(g.astype(np.uint8)).filter(ImageFilter.GaussianBlur(40)), dtype=np.float64)
    hp = g - blur
    win = np.outer(np.hanning(hp.shape[0]), np.hanning(hp.shape[1]))
    return hp * win


A = load(a_path)
B = load(b_path)
FA = np.fft.fft2(A)
FB = np.fft.fft2(B)
h, w = A.shape
fy = np.fft.fftfreq(h)[:, None]
fx = np.fft.fftfreq(w)[None, :]
radius = np.sqrt(fx**2 + fy**2)
wavelength_px = np.where(radius > 0, 1.0 / np.maximum(radius, 1e-9), np.inf)
power = np.abs(FA) ** 2


def strongest(lo_px, hi_px, label):
    mask = (wavelength_px >= lo_px) & (wavelength_px <= hi_px) & (fy <= 0)  # one half-plane
    p = np.where(mask, power, 0.0)
    iy, ix = np.unravel_index(np.argmax(p), p.shape)
    kx, ky = fx[0, ix], fy[iy, 0]
    # Screen angle of the wave vector, clockwise from screen-up (y grows downward on screen).
    ang = np.degrees(np.arctan2(kx, -ky)) % 360.0
    lam = 1.0 / np.hypot(kx, ky)
    phase = np.angle(FB[iy, ix] / FA[iy, ix])
    shift_px = -phase / (2 * np.pi) * lam  # a positive shift: the pattern moved along +k
    print(f"{label}: wavelength {lam:.0f} px, wave vector at {ang:.0f} deg clockwise from screen-up; "
          f"crests along {(ang + 90) % 180:.0f}/{(ang + 270) % 360:.0f} deg; "
          f"moved {shift_px:+.1f} px along the wave vector between the frames")
    return ang, lam, shift_px


print("Grid (5 m cells):")
g1 = strongest(40, 70, "  grid peak")
# The second grid family: 90 degrees away; look for it in a narrow angular band.
angles = np.degrees(np.arctan2(fx, -fy)) % 360.0
want = (g1[0] + 90.0) % 180.0
band = (np.abs(((angles - want + 90) % 180) - 90) < 10) | (np.abs(((angles - want - 180 + 90) % 180) - 90) < 10)
mask = (wavelength_px >= 40) & (wavelength_px <= 70) & (fy <= 0) & band
p = np.where(mask, power, 0.0)
iy, ix = np.unravel_index(np.argmax(p), p.shape)
print(f"  other grid family at {np.degrees(np.arctan2(fx[0, ix], -fy[iy, 0])) % 360:.0f} deg")
print("Long waves (the swell, 14 m):")
strongest(100, 300, "  swell peak")
print("Medium waves (the 7 m chop):")
strongest(60, 100, "  chop peak")
