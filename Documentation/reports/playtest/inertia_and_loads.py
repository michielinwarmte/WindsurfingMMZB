import csv, math
# The kit's pitch inertia (mass_model.gd's formulas) against the hull alone
def box(m, sx, sy, sz): return m/12*(sy*sy+sz*sz)        # about x (pitch)
def cyl(m, r, h): return m/12*(3*r*r+h*h)
board_m, sailor_m, rig_m = 7.8, 85.0, 9.5
hull_I = box(board_m, 0.72, 0.13, 2.28)
# full hike while planing: lean 1 -> sailor at (1.08, 1.0-0.435, 0.54+hang 0.3); rig at mast foot (z=-0.105) + 1.8 m up, leaned 25 deg
sailor_p = (1.08, 0.565, 0.84)
rig_p = (math.sin(math.radians(25))*1.8, 0.065+math.cos(math.radians(25))*1.8, -0.105)
board_p = (0.0, 0.0, 0.0)
M = board_m+sailor_m+rig_m
com = tuple(sum(m*p[i] for m, p in ((board_m,board_p),(sailor_m,sailor_p),(rig_m,rig_p)))/M for i in range(3))
def Ix(m, own, p):
    dy, dz = p[1]-com[1], p[2]-com[2]
    return own + m*(dy*dy+dz*dz)
whole = Ix(board_m, hull_I, board_p) + Ix(sailor_m, cyl(sailor_m,0.2,1.75), sailor_p) + Ix(rig_m, rig_m*5.26**2/12, rig_p)
print(f"pitch inertia: the hull alone (the sim's rigid body) {hull_I:.1f} kg m2; the whole kit about its centre of mass {whole:.0f} kg m2 (ratio {whole/hull_I:.0f})")
print(f"a 60 N m nose-down moment alone would pitch the hull at {math.degrees(60/hull_I):.0f} deg/s2, the whole kit at {math.degrees(60/whole):.1f} deg/s2")
for path in ("matrix_waves/straight_18.csv", "matrix_waves/straight_24.csv"):
    with open(path, newline="") as f:
        rows = list(csv.DictReader(f))
    fin = [float(r["fin_lift_n"]) for r in rows if r["sailor_state"] == "0"]
    bend = [float(r["fin_bend_tip_deg"]) for r in rows if r["sailor_state"] == "0"]
    up = [float(r["fin_up_n"]) for r in rows if r["sailor_state"] == "0"]
    fin.sort(); bend.sort()
    n = len(fin)
    print(f"{path}: fin lift median {fin[n//2]:.0f} N, 90th pct {fin[int(0.9*n)]:.0f} N, max {fin[-1]:.0f} N; tip bend median {bend[n//2]:.1f} deg, max {bend[-1]:.1f} deg; fin up max {max(up):.0f} N")
