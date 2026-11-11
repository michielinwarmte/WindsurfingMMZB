"""One board's start in a few lines: every change of what it is doing (the note without its numbers), from --from s to
--to s race time, with speed, heading and the time spent; e.g. python -I trace.py s3_hold_base r0001 1 [-60] [35]"""
import csv
import os
import re
import sys

SUITE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", ".sim_output", "suite")


def main(argv):
    run, race, board = argv[0], argv[1], int(argv[2])
    t_from = float(argv[3]) if len(argv) > 3 else -60.0
    t_to = float(argv[4]) if len(argv) > 4 else 35.0
    path = os.path.join(SUITE, run, race, "hana_%d.csv" % (board + 1))
    last_key, start_row, rows = None, None, []
    for row in csv.DictReader(open(path, encoding="utf-8")):
        t = float(row["race_time_s"])
        if t < t_from or t > t_to:
            continue
        key = re.sub(r"\([^)]*s to spare\)", "", row["doing"]).strip()
        if key != last_key:
            if start_row is not None:
                rows.append((start_row, prev))
            start_row, last_key = row, key
        prev = row
    if start_row is not None:
        rows.append((start_row, prev))
    for a, b in rows:
        print("%7.1f..%7.1f  v %4.1f->%4.1f  hdg %3.0f  (%6.1f,%6.1f)  %s" % (
            float(a["race_time_s"]), float(b["race_time_s"]), float(a["speed_ms"]), float(b["speed_ms"]),
            float(a["heading_deg"]), float(a["x_m"]), float(a["z_m"]), a["doing"][:110]))


if __name__ == "__main__":
    main(sys.argv[1:])
