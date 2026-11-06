#!/usr/bin/env python3
"""What the board and the sailor did before a fall, from a telemetry CSV (tools/lake_matrix.sh --csv=1,
tools/matrix.sh, tools/simulate.sh): one row every --every seconds over the --back seconds before
the first fall (or before --at), the columns that tell a catapult from a nose-dive or a fall off.

    python -I tools/fall_trace.py <file.csv> [--back=4] [--every=0.25] [--at=<time_s>]
"""
import csv
import sys

COLUMNS = [("time_s", "t", "%5.2f"), ("speed_kmh", "kmh", "%5.1f"), ("twa_deg", "twa", "%6.1f"), ("awa_deg", "awa", "%6.1f"),
           ("yaw_rate_dps", "yaw", "%6.1f"), ("pitch_deg", "pitch", "%5.1f"), ("heel_deg", "heel", "%6.1f"),
           ("felt_heel_deg", "felt", "%6.1f"), ("felt_push_ms2", "push", "%5.1f"), ("wanted_bank_deg", "bank", "%5.1f"),
           ("sheet", "sheet", "%4.2f"), ("alpha_deg", "alpha", "%5.1f"), ("side_force_n", "side", "%5.0f"),
           ("drive_n", "drive", "%5.0f"), ("rake", "rake", "%5.2f"), ("rig_tilt", "tilt", "%5.2f"), ("lean", "lean", "%5.2f"),
           ("stance", "stnc", "%4.2f"), ("feet_moment_excess_nm", "fexc", "%5.0f"), ("bow_immersion_m", "bow", "%5.2f"),
           ("water_height_m", "wave", "%5.2f"), ("sailor_state", "st", "%2s"), ("fall_kind", "fall", "%s")]


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    path = sys.argv[1]
    options = dict(a[2:].split("=", 1) for a in sys.argv[2:] if a.startswith("--") and "=" in a)
    back = float(options.get("back", "4"))
    every = float(options.get("every", "0.25"))
    rows = list(csv.DictReader(open(path, newline="")))
    at = float(options["at"]) if "at" in options else None
    if at is None:
        for r in rows:
            if r.get("fall_kind", "") not in ("", None):
                at = float(r["time_s"])
                print("fall: %s at %.2f s" % (r["fall_kind"], at))
                break
    if at is None:
        print("no fall in %s" % path)
        return
    print(" ".join(name for _key, name, _fmt in COLUMNS))
    next_t = at - back
    for r in rows:
        t = float(r["time_s"])
        if t < next_t - 1e-6 or t > at + 0.3:
            continue
        next_t = t + every - 1e-6
        cells = []
        for key, _name, fmt in COLUMNS:
            value = r.get(key, "")
            try:
                cells.append(fmt % (float(value) if fmt != "%s" and fmt != "%2s" else value))
            except (TypeError, ValueError):
                cells.append(str(value))
        print(" ".join(cells))


if __name__ == "__main__":
    main()
