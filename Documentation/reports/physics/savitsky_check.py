"""The hull's drag against Savitsky's (1964) planing method, outside the game (the realism audit P1,
7 November 2026). For each sailing state of Game/dev/pitch_budget.gd it takes the water's load on the
hull (planing lift + buoyancy), the centre of that push (x push, from the tail), the mean wet beam
(the strips' wet area over the wet length) and the speed, solves Savitsky's equations for the wet length
and the trim that carry that load with its centre there, and gives the drag the method predicts
(pressure drag D tan(trim) plus the ITTC-1957 friction on the wet bottom at Savitsky's mean bottom
velocity). Next to it: the game's hull drag (friction + planing + residuary + bow) and Drake's rule of
thumb (a well-trimmed board's drag about 0.15 of its lift from about 6 to over 20 knots).
Savitsky, D. (1964) Hydrodynamic design of planing hulls, Marine Technology 1(1): equations for
2 <= trim <= 15 deg, lambda <= 4, 0.6 <= Cv <= 13 (outside that the numbers are extrapolated: marked *).
argv: the folder of pitch-budget prints (pb_<kt>_<twa>.txt)."""
import math, os, re, sys

RHO, NU, G, BETA = 1025.0, 1.19e-6, 9.81, 1.0

def read(path):
    vals = {}
    for line in open(path, encoding="utf-8", errors="replace"):
        m = re.match(r"\s{3}(\S.*?\S)\s{2,}(-?[0-9.]+)\s*$", line)
        if m:
            vals.setdefault(m.group(1).strip(), float(m.group(2)))
    return vals

def savitsky(load_n, v, b, lp):
    cv = v / math.sqrt(G * b)
    # wet length from the centre of pressure: lp / (lam b) = 0.75 - 1 / (5.21 Cv^2 / lam^2 + 2.39)
    lo, hi = 0.05, 12.0
    for _ in range(80):
        lam = 0.5 * (lo + hi)
        f = lam * b * (0.75 - 1.0 / (5.21 * cv * cv / (lam * lam) + 2.39)) - lp
        lo, hi = (lo, lam) if f > 0 else (lam, hi)
    cl_beta = load_n / (0.5 * RHO * v * v * b * b)
    cl0 = cl_beta
    for _ in range(50):
        cl0 = cl_beta + 0.0065 * BETA * cl0 ** 0.6
    tau = (cl0 / (0.012 * lam ** 0.5 + 0.0055 * lam ** 2.5 / (cv * cv))) ** (1 / 1.1)
    t = math.radians(tau)
    dyn = 0.012 * tau ** 1.1 * lam ** 0.5
    vm = v * math.sqrt(max(1.0 - (dyn - 0.0065 * BETA * dyn ** 0.6) / (lam * math.cos(t)), 0.05))
    re_n = vm * lam * b / NU
    cf = 0.075 / (math.log10(re_n) - 2.0) ** 2
    friction = 0.5 * RHO * vm * vm * lam * b * b * cf / math.cos(math.radians(BETA))
    drag = load_n * math.tan(t) + friction / math.cos(t)
    ok = 2.0 <= tau <= 15.0 and lam <= 4.0 and 0.6 <= cv <= 13.0
    return drag, tau, lam * b, friction, cv, ok

folder = sys.argv[1]
print("| wind kt | TWA | speed km/h | water load N | push from tail m | wet beam m | game: trim, wet m | Savitsky: trim, wet m | game hull drag N | Savitsky drag N | game/Savitsky | game hull+fin / weight | fin N |")
print("|---:|---:|---:|---:|---:|---:|---|---|---:|---:|---:|---:|---:|")
for name in sorted(os.listdir(folder), key=lambda n: [int(x) for x in re.findall(r"\d+", n)]):
    m = re.match(r"pb_(\d+)_(\d+)\.txt", name)
    if not m:
        continue
    d = read(os.path.join(folder, name))
    try:
        v = d["speed m/s"]; load = d["planing lift N"] + d["buoyancy N"]; lp = d["x push"]
        wet = d["wet length m"]; b = d["wet-width area m2"] / max(wet, 1e-3)
        game = d["friction N"] + d["planing drag N"] + d["residuary N"]
        fin = d["fin drag N"]
    except KeyError as e:
        print(name, "missing", e); continue
    sd, tau, wl, fr, cv, ok = savitsky(load, v, b, lp)
    weight = 9.81 * 98.0
    print("| %s | %s | %.1f | %.0f | %.2f | %.2f | %.2f, %.2f | %.2f%s, %.2f | %.0f | %.0f | %.2f | %.3f | %.0f |" % (
        m.group(1), m.group(2), v * 3.6, load, lp, b, d["pitch deg"], wet, tau, "" if ok else "*", wl, game, sd, game / sd, (game + fin) / weight, fin))
