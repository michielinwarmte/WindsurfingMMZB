"""The game's beam under a point load 2 cm from the tip (peterman.dk's test): the deflection at the
quarter points as a share of the tip's, for the game's law (thickness a fixed share of the chord)
and for thickness laws that taper. Compare with peterman's measured 1/4, 1/2, 3/4 shares."""
import math
N = 200
span, area = 0.38, 0.0365
tip_ratio, taper, round_start = 0.37, 1.1, 0.82
def chord_shape(s):
    v = 1.0 + (tip_ratio - 1.0) * s ** taper
    if s > round_start:
        a = (s - round_start) / (1.0 - round_start)
        v *= math.sqrt(max(0.0, 1.0 - a * a))
    return v
def profile(t_root, t_tip, root_boost=1.0, boost_to=0.0):
    """Deflection shares at 1/4, 1/2, 3/4 of the span for a tip load, with EI = c * t^3,
    t/c falling linearly from t_root to t_tip; the first boost_to of the span root_boost times stiffer."""
    step = span / N
    ei = []
    for j in range(N + 1):
        s = j / N
        c = chord_shape(s)
        tc = t_root + (t_tip - t_root) * s
        k = c * (c * tc) ** 3
        if s < boost_to:
            k *= root_boost
        ei.append(k)
    load_at = 1.0 - 0.02 / span
    moments = [max(load_at * span - span * j / N, 0.0) for j in range(N + 1)]
    sl = [0.0]
    for j in range(N):
        ch = moments[j] / ei[j] if ei[j] > 0 else 0
        cn = moments[j + 1] / ei[j + 1] if ei[j + 1] > 0 else 0
        sl.append(sl[j] + step * 0.5 * (ch + cn))
    d = [0.0]
    for j in range(N):
        d.append(d[j] + step * 0.5 * (sl[j] + sl[j + 1]))
    tip = d[int(load_at * N)]
    return [100 * d[int(q * N)] / tip for q in (0.25, 0.5, 0.75)]
print("deflection at 1/4, 1/2, 3/4 of the span as % of the tip's, under a load 2 cm from the tip:")
print("  uniform beam (constant EI):      %5.1f %5.1f %5.1f" % tuple(100 * (3 * q * q - q ** 3) / 2 for q in (0.25, 0.5, 0.75)))
print("  the game's law (t/c 10 %% flat):  %5.1f %5.1f %5.1f" % tuple(profile(0.10, 0.10)))
print("  t/c 10 %% root to 8 %% tip:         %5.1f %5.1f %5.1f" % tuple(profile(0.10, 0.08)))
print("  t/c 12 %% root to 7 %% tip:         %5.1f %5.1f %5.1f" % tuple(profile(0.12, 0.07)))
print("  t/c 12 %% to 7 %%, root fifth x3:   %5.1f %5.1f %5.1f" % tuple(profile(0.12, 0.07, 3.0, 0.2)))
print("  peterman.dk, 17 formula fins:     21-28  51-59  72-79  (measured, the clamp's give included)")
print("  a hinge at the root (pure clamp give): 25  50  75")
