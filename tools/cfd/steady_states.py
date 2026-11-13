# The board's steady states for the wind tunnel (PH15): the means of the sail's numbers over the
# steady part of tools/reach_check.sh's CSVs (flat water, a steady wind, t >= 25 s).
#
#   tools/reach_check.sh --twas=48,100,135 --winds=12,18,24 --csv=1
#   python -I tools/cfd/steady_states.py [.sim_output/reach] [--json=out.json]
#
# Prints one line per case and, with --json, writes them for tools/cfd/wind_tunnel.py.
import csv
import glob
import json
import math
import os
import sys

FROM_S = 25.0
COLUMNS = ["speed_ms", "heading_deg", "tws_at_sail_kt", "twa_deg", "aws_kt", "awa_deg",
           "sail_angle_deg", "alpha_deg", "sail_lift_n", "sail_drag_n", "drive_n", "side_force_n",
           "rake", "rig_tilt", "rig_lean_deg", "heel_deg", "sheet", "sail_side", "boom_across",
           "sailor_x_m", "sailor_y_m", "feet_x_m", "feet_z_m"]


def means_of(path: str) -> dict:
    sums = {name: 0.0 for name in COLUMNS}
    count = 0
    with open(path, newline="") as handle:
        for row in csv.DictReader(handle):
            if float(row["time_s"]) < FROM_S:
                continue
            for name in COLUMNS:
                sums[name] += float(row[name])
            count += 1
    return {name: sums[name] / max(count, 1) for name in COLUMNS}


def main() -> None:
    folder = ".sim_output/reach"
    out_json = ""
    for arg in sys.argv[1:]:
        if arg.startswith("--json="):
            out_json = arg.split("=", 1)[1]
        else:
            folder = arg
    states = []
    for path in sorted(glob.glob(os.path.join(folder, "reach_*.csv"))):
        name = os.path.basename(path)[:-4]
        m = means_of(path)
        m["case"] = name
        states.append(m)
        kt = 0.514444
        aws_ms = m["aws_kt"] * kt
        q_pa = 0.5 * 1.225 * aws_ms * aws_ms
        cl = m["sail_lift_n"] / (q_pa * 8.0)
        cd = m["sail_drag_n"] / (q_pa * 8.0)
        print(f"{name:14s} TWS {m['tws_at_sail_kt']:5.1f} kt TWA {m['twa_deg']:6.1f}  board {m['speed_ms']:5.2f} m/s  "
              f"AWS {aws_ms:5.2f} m/s AWA {m['awa_deg']:6.1f}  alpha {m['alpha_deg']:5.1f}  boom {m['sail_angle_deg']:6.1f}  "
              f"lift {m['sail_lift_n']:6.0f} drag {m['sail_drag_n']:5.0f} N (CL {cl:4.2f} CD {cd:4.2f})  "
              f"rake {m['rake']:5.2f} tilt {m['rig_tilt']:5.2f} lean {m['rig_lean_deg']:5.1f}  heel {m['heel_deg']:5.1f}")
    if out_json:
        with open(out_json, "w") as handle:
            json.dump(states, handle, indent=1)
        print("written", out_json)


if __name__ == "__main__":
    main()
