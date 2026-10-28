"""The apparent wind's twist over the sail's height per course (sail_wind_tunnel.md, measurement 7). Run: python flow_twist.py"""
import math
KT = 0.514444
def tws(ref_kt, h):  # sim's profile: 10 m reference, exponent 0.11
    return ref_kt * KT * (h / 10.0) ** 0.11
def awa(ref_kt, twa, v, h):
    w = tws(ref_kt, h); t = math.radians(twa)
    along = w * math.cos(t) + v; perp = w * math.sin(t)
    return math.degrees(math.atan2(perp, along)), math.hypot(along, perp)
cases = [("upwind", 48, {24: 4.30/math.cos(math.radians(48)), 18: 3.90/math.cos(math.radians(48)), 12: 1.76/math.cos(math.radians(48))}),
         ("beam", 100, {24: 13.05, 18: 11.56, 12: 7.16}),
         ("broad", 135, {24: 12.74, 18: 7.55, 12: 4.05}),
         ("broad legacy", 135, {24: 14.21, 18: 10.57, 12: 5.59})]
low, high = 0.8, 4.2   # the tunnel's bottom section (0.67 m above the board) to the top batten
print("course        wind  board  AWA low  AWA high  flow twist  AWS at CE  q at CE")
for name, twa, speeds in cases:
    for kt, v in speeds.items():
        a1, _ = awa(kt, twa, v, low); a2, _ = awa(kt, twa, v, high); _, s = awa(kt, twa, v, 2.0)
        q = 0.5 * 1.225 * s * s
        print(f"{name:12s} {kt:4d}  {v:5.2f}  {a1:6.1f}  {a2:7.1f}  {a2-a1:9.1f}  {s:8.2f}  {q:6.0f}  f={max(1/(1+q/140),0.75):.2f}")
