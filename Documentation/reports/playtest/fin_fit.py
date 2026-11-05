"""Fit the game's fin beam to BOTH of Nascimento's point-load tests on the 37 cm F-Hot slalom fin:
55.2 N/mm at 40 % of the span and 5.0 N/mm at 80 % (loads at the quarter chord, the load point's
deflection). The game's law EI = S c^4 has one free number, S; a power n in EI = S c^n (or a thickness
ratio that tapers) is the second. Which n gives the measured 11.05 : 1 ratio?"""
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
def deflection_at(load_pos, ei):
    step = span / N
    moments = [max(load_pos * span - span * j / N, 0.0) for j in range(N + 1)]
    sl = [0.0]
    for j in range(N):
        ch = moments[j] / ei[j] if ei[j] > 0 else 0
        cn = moments[j + 1] / ei[j + 1] if ei[j + 1] > 0 else 0
        sl.append(sl[j] + step * 0.5 * (ch + cn))
    d = [0.0]
    for j in range(N):
        d.append(d[j] + step * 0.5 * (sl[j] + sl[j + 1]))
    return d[int(round(load_pos * N))], sl, d
def ei_power(n, s_scale=1.0):
    return [s_scale * chord_shape(j / N) ** n for j in range(N + 1)]
measured_ratio = 55.236 / 4.998
print(f"measured: 55.2 N/mm at 40 %, 5.0 N/mm at 80 %: ratio {measured_ratio:.2f}")
print("the game's beam, EI = S c^n, the 40 % stiffness over the 80 % stiffness:")
best = None
for n10 in range(0, 81, 5):
    n = n10 / 10
    d40, _, _ = deflection_at(0.4, ei_power(n))
    d80, _, _ = deflection_at(0.8, ei_power(n))
    ratio = d80 / d40
    mark = ""
    if best is None or abs(ratio - measured_ratio) < abs(best[1] - measured_ratio):
        best = (n, ratio)
    print(f"  n = {n:3.1f}: ratio {ratio:6.2f}")
n = best[0]
# refine
lo, hi = n - 0.5, n + 0.5
for _ in range(40):
    mid = 0.5 * (lo + hi)
    d40, _, _ = deflection_at(0.4, ei_power(mid)); d80, _, _ = deflection_at(0.8, ei_power(mid))
    if d80 / d40 > measured_ratio: hi = mid
    else: lo = mid
n = 0.5 * (lo + hi)
print(f"\nthe power that repeats both tests: n = {n:.2f} (the game has 4.0: a uniform beam would be 0)")
# the elliptic sailing bend with that power, calibrated on the 80 % test
for power in (4.0, n):
    d80, _, _ = deflection_at(0.8, ei_power(power))
    S = d80 / 0.020 * 100.0  # S so that 100 N gives 20 mm (per-N deflection scaled)
    ei = ei_power(power, S / 100.0)
    # elliptic lift of 1 N: moments at edges
    def ell_area(x): return 2 / math.pi * (x * math.sqrt(max(0, 1 - x * x)) + math.asin(min(x, 1)))
    def ell_mom(x): return 4 / (3 * math.pi) * (1 - max(0, 1 - x * x) ** 1.5)
    step = span / N
    moments = []
    for j in range(N + 1):
        y = span * j / N; m = 0
        for i in range(j, N):
            share = ell_area((i + 1) / N) - ell_area(i / N)
            first = span * (ell_mom((i + 1) / N) - ell_mom(i / N))
            m += first - share * y
        moments.append(m)
    sl = [0.0]
    for j in range(N):
        ch = moments[j] / ei[j] if ei[j] > 0 else 0
        cn = moments[j + 1] / ei[j + 1] if ei[j + 1] > 0 else 0
        sl.append(sl[j] + step * 0.5 * (ch + cn))
    d = [0.0]
    for j in range(N):
        d.append(d[j] + step * 0.5 * (sl[j] + sl[j + 1]))
    # upward share at 700 N: sum share_i sin(theta_i)
    up = 0.0
    for i in range(N):
        share = ell_area((i + 1) / N) - ell_area(i / N)
        theta = min(700 * 0.5 * (sl[i] + sl[i + 1]), math.radians(35))
        up += share * math.sin(theta)
    fifths = [100 * (sl[int((q + 1) * N / 5)] - sl[int(q * N / 5)]) / sl[N] for q in range(5)]
    d40, _, _ = deflection_at(0.4, ei); d80b, _, _ = deflection_at(0.8, ei)
    print(f"\nn = {power:.2f}: 40 % test {1/d40:.1f} N/mm, 80 % test {1/d80b:.2f} N/mm; per 100 N of sailing lift the tip turns {math.degrees(sl[N])*100:.2f} deg and moves {d[N]*100*1000:.1f} mm")
    print(f"  the tip's angle gained per fifth of the span: " + "  ".join(f"{f:4.1f} %" for f in fifths))
    print(f"  at 700 N: tip {min(math.degrees(sl[N])*700, 35):.1f} deg, {d[N]*700*1000:.0f} mm, the upward share of the lift {100*up:.1f} % ({700*up:.0f} N)")
    tipload, _, dd = deflection_at(1.0, ei)
    print(f"  10 kg at the tip: {98.1*tipload*1000:.0f} mm")
