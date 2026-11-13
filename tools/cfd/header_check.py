"""Can the game's one number carry the shadow's header? (PH15)

The game's shadow multiplies the TRUE wind by a factor. For a board that is moving, less true wind also swings its
apparent wind forward: a header. So the one number gives a moving follower both a loss of apparent wind and a
header. The tunnel measured both for a follower at the caster's speed and course; the analysis turned the loss into
the factor that matches it ("deficit same-speed"), but that turn magnifies the gusts' noise about four times for a
planing board (13 November 2026: 7 to 9 % in gusty air, 2 to 5 % in smooth). The at-rest factor is the disturbance's
part along the true wind, the same for every follower. Here: the header that factor gives in the game's wind triangle,
against the header the tunnel measured. If they agree, the game's form is enough and only its numbers change; if
the tunnel's header is much larger, the direction would need a physics change (WindDisturbance gives a factor only).

  python -I tools/cfd/header_check.py [--dir=.sim_output/cfd] [--dx=15] [--suffix=]
"""
import glob
import json
import math
import os
import sys


def apparent(tws: float, twa_deg: float, boat: float, factor: float):
    """The apparent wind's angle off the bow (degrees) and speed for the true wind times the factor."""
    t = math.radians(twa_deg)
    ahead = factor * tws * math.cos(t) + boat
    across = factor * tws * math.sin(t)
    return math.degrees(math.atan2(across, ahead)), math.hypot(ahead, across)


def main() -> None:
    opts = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
    folder = opts.get("dir", ".sim_output/cfd")
    pattern = os.path.join(folder, f"*_dx{int(opts.get('dx', '15')):02d}{opts.get('suffix', '')}_wake.json")
    print("case            dist m | factor (at rest) | header from the game's factor | header in the tunnel (deg)")
    for path in sorted(glob.glob(pattern)):
        r = json.load(open(path))
        pose = r["pose"]
        boat = math.hypot(*json.load(open(path.replace("_wake.json", ".json")))["info"]["board_velocity_tunnel_ms"])
        base_angle, _ = apparent(pose["tws_ms"], abs(pose["twa_deg"]), boat, 1.0)
        for row in r["table"]:
            if row["distance_m"] not in (5.0, 10.0, 20.0):
                continue
            factor = 1.0 - row["deficit_rest"]
            angle, _ = apparent(pose["tws_ms"], abs(pose["twa_deg"]), boat, factor)
            print(f"{r['case']:15s} {row['distance_m']:5.0f}  | {factor:16.3f} | {base_angle - angle:+29.1f} | "
                  f"{row['turn_deg_on_axis']:+.1f}")


if __name__ == "__main__":
    main()
