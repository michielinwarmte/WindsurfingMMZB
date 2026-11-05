"""The game's fin beam (fin_model.gd) redone in Python: where along the span the bend happens,
and the tip's movement at the loads the sim shows."""
import math
N = 20
span, area = 0.38, 0.0365
tip_ratio, taper, round_start = 0.37, 1.1, 0.82
def chord_shape(s):
    v = 1.0 + (tip_ratio - 1.0) * s ** taper
    if s > round_start:
        a = (s - round_start) / (1.0 - round_start)
        v *= math.sqrt(max(0.0, 1.0 - a * a))
    return v
mean = sum(chord_shape((i + 0.5) / 200) for i in range(200)) / 200
c_root = area / (mean * span)
def ell_area(x): return 2 / math.pi * (x * math.sqrt(max(0, 1 - x * x)) + math.asin(min(x, 1)))
def ell_mom(x): return 4 / (3 * math.pi) * (1 - max(0, 1 - x * x) ** 1.5)
def stiffness(S): return [S * (c_root * chord_shape(j / N)) ** 4 for j in range(N + 1)]
def slopes(moments, ei, step):
    s = [0.0]
    for j in range(N):
        ch = moments[j] / ei[j] if ei[j] > 0 else 0
        cn = moments[j + 1] / ei[j + 1] if ei[j + 1] > 0 else 0
        s.append(s[j] + step * 0.5 * (ch + cn))
    return s
def defl(sl, step):
    d = [0.0]
    for j in range(N):
        d.append(d[j] + step * 0.5 * (sl[j] + sl[j + 1]))
    return d
def point_moments(load, pos):
    return [load * max(pos * span - span * j / N, 0) for j in range(N + 1)]
def ell_moments():
    out = []
    for j in range(N + 1):
        y = span * j / N
        m = 0
        for i in range(j, N):
            share = ell_area((i + 1) / N) - ell_area(i / N)
            first = span * (ell_mom((i + 1) / N) - ell_mom(i / N))
            m += first - share * y
        out.append(m)
    return out
step = span / N
# calibrate: 100 N at 0.8 span -> 20 mm at the load point
sl = slopes(point_moments(100, 0.8), stiffness(1.0), step)
d1 = defl(sl, step)
at = 0.8 * N; j = int(at)
d_load = d1[j] + (d1[j + 1] - d1[j]) * (at - j)
S = d_load / 0.020
print(f"root chord {c_root*100:.1f} cm, S = {S:.3e} N/m2, EI root {S*c_root**4:.1f} N m2")
ei = stiffness(S)
sl = slopes(ell_moments(), ei, step)
d = defl(sl, step)
print(f"per 100 N of sailing lift: tip turns {math.degrees(sl[N])*100:.2f} deg, moves {d[N]*100*1000:.1f} mm")
print("where the bend happens (share of the tip's angle gained in each fifth of the span, root to tip):")
for q in range(5):
    a, b = q * 4, (q + 1) * 4
    print(f"  {q*20:3d}-{(q+1)*20:3d} % of the span: {100*(sl[b]-sl[a])/sl[N]:5.1f} %   (chord {c_root*chord_shape(a/N)*100:.1f} to {c_root*chord_shape(b/N)*100:.1f} cm, thickness {c_root*chord_shape(a/N)*100:.1f} to {c_root*chord_shape(b/N)*100:.1f} mm at 10 %)")
for F in (300, 500, 700, 1000, 1500):
    print(f"  lift {F:5d} N: tip {min(math.degrees(sl[N])*F, 35):5.1f} deg (cap 35), tip moves {d[N]*F*1000:6.1f} mm = {d[N]*F/span*100:4.1f} % of the span")
# 10 kg at the very tip (Max's home test)
slt = slopes(point_moments(98.1, 1.0), ei, step)
print(f"10 kg hung at the tip: {defl(slt, step)[N]*1000:.1f} mm")
