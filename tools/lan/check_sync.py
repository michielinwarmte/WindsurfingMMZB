"""LAN multiplayer's sync check (tools/lan_test.sh; Documentation/reports/multiplayer/PLAN.md).

Reads the host's and the guest's logs. A TRACK line is a board as the PC that sails it had it at a
host tick; a SEEN line is a board as the other PC showed it for that same tick. For every SEEN line
with a TRACK line of the same board and tick, the differences are measured: the place (m), the heading
(degrees), the speed (m/s), the mast's direction, the sailor's lean, and whether the sailor was on the
board on both; and (newer builds) the heel and the pitch and the rail and trim the sailor's feet aim for,
which carry the body on the mouse (package B, GP2). Then the RESULT lines (each PC's finish list) are
compared.

    python -I tools/lan/check_sync.py .logs/lan/host.log .logs/lan/guest.log

Exits 1 when a shown board is more than PLACE_TOLERANCE_M from where its PC had it, or the finish
lists differ.
"""
import math
import sys

# A SEEN line is a state a puppet took, a TRACK line the state its PC sent for that tick: they should
# be the same numbers (to the four decimals printed and the 32-bit floats that travel).
PLACE_TOLERANCE_M = 0.01
# What Godot prints when a game quits (leak reports of the engine itself): not the game's errors.
SHUTDOWN_NOISE = ("Unreferenced static string", "resources still in use at exit", "Pages in use exist at exit",
                  "ObjectDB instances were leaked")


def read(path):
    tracks, seens, results, errors = {}, {}, [], []
    judged = {}
    with open(path, encoding="utf-8", errors="replace") as log:
        for line in log:
            parts = line.split()
            if not parts:
                continue
            if parts[0] in ("TRACK", "SEEN") and len(parts) >= 12:
                tick, board = int(parts[1]), int(parts[2])
                numbers = [float(v) for v in parts[3:11]] + [int(parts[11])] + [float(v) for v in parts[12:16]]
                (tracks if parts[0] == "TRACK" else seens)[(tick, board)] = numbers
            elif parts[0] == "JUDGED" and len(parts) >= 5:
                judged[(int(parts[1]), int(parts[2]))] = (float(parts[3]), float(parts[4]))
            elif parts[0] == "RESULT":
                results.append(parts[1:])
            elif ("SCRIPT ERROR" in line or line.startswith("ERROR")) and not any(noise in line for noise in SHUTDOWN_NOISE):
                errors.append(line.strip())
    read.judged = judged
    return tracks, seens, results, errors


def compare(label, seens, tracks):
    worst = {"place": 0.0, "height": 0.0, "heading": 0.0, "speed": 0.0, "mast": 0.0, "lean": 0.0,
             "heel": 0.0, "pitch": 0.0, "rail_aim": 0.0, "trim_aim": 0.0}
    # The largest rail and trim aims a PC sent, to show what was compared (the body adds to them).
    aims = {"rail": 0.0, "trim": 0.0}
    state_mismatch = 0
    matched = 0
    boards = set()
    for key, seen in seens.items():
        track = tracks.get(key)
        if track is None:
            continue
        matched += 1
        boards.add(key[1])
        worst["place"] = max(worst["place"], math.hypot(seen[0] - track[0], seen[2] - track[2]))
        worst["height"] = max(worst["height"], abs(seen[1] - track[1]))
        heading = abs((seen[3] - track[3] + 180.0) % 360.0 - 180.0)
        worst["heading"] = max(worst["heading"], heading)
        worst["speed"] = max(worst["speed"], abs(seen[4] - track[4]))
        worst["mast"] = max(worst["mast"], math.hypot(seen[5] - track[5], seen[6] - track[6]))
        worst["lean"] = max(worst["lean"], abs(seen[7] - track[7]))
        if seen[8] != track[8]:
            state_mismatch += 1
        if len(seen) >= 13 and len(track) >= 13:
            for i, name in enumerate(("heel", "pitch", "rail_aim", "trim_aim")):
                worst[name] = max(worst[name], abs(seen[9 + i] - track[9 + i]))
            aims["rail"] = max(aims["rail"], abs(track[11]))
            aims["trim"] = max(aims["trim"], abs(track[12]))
    print("%s: %d moments of %d boards compared (of %d shown); worst: place %.4f m, height %.4f m, heading %.3f deg, "
          "speed %.4f m/s, mast %.5f, lean %.5f; sailor on/off the board differed %d times"
          % (label, matched, len(boards), len(seens), worst["place"], worst["height"], worst["heading"], worst["speed"],
             worst["mast"], worst["lean"], state_mismatch))
    print("%s  heel %.4f deg, pitch %.4f deg, the bank the feet aim for %.4f deg (a turn's too) and their trim aim "
          "%.4f deg (the largest sent: bank %.2f deg, trim %.2f deg)"
          % (" " * len(label), worst["heel"], worst["pitch"], worst["rail_aim"], worst["trim_aim"], aims["rail"], aims["trim"]))
    return matched, worst


def main():
    host_tracks, host_seens, host_results, host_errors = read(sys.argv[1])
    host_judged = read.judged
    guest_tracks, guest_seens, guest_results, guest_errors = read(sys.argv[2])
    ok = True
    for who, errors in (("host", host_errors), ("guest", guest_errors)):
        for error in errors[:5]:
            print("%s log: %s" % (who, error))
    matched_g, worst_g = compare("The guest shows the host's boards", guest_seens, host_tracks)
    matched_h, worst_h = compare("The host shows the guest's board ", host_seens, guest_tracks)
    # The judge (on the host) has the guest's board where its newest state, moved on by its speed for
    # the state's age, puts it now: against where the guest's own PC had it at that tick.
    judge_errors = [math.hypot(x - guest_tracks[key][0], z - guest_tracks[key][2]) for key, (x, z) in host_judged.items() if key in guest_tracks]
    if judge_errors:
        judge_errors.sort()
        print("The host's judge has the guest's board, against the guest's own: median %.3f m, worst %.3f m (%d moments)"
              % (judge_errors[len(judge_errors) // 2], judge_errors[-1], len(judge_errors)))
    if matched_g == 0 or matched_h == 0:
        print("FAIL: nothing to compare (did the two connect? see the logs)")
        ok = False
    for worst in (worst_g, worst_h):
        if worst["place"] > PLACE_TOLERANCE_M:
            print("FAIL: a board shown %.3f m from where its PC had it (tolerance %.2f m)" % (worst["place"], PLACE_TOLERANCE_M))
            ok = False
    if host_results or guest_results:
        print("Results on the host:  " + "; ".join(" ".join(r) for r in host_results))
        print("Results on the guest: " + "; ".join(" ".join(r) for r in guest_results))
        if host_results != guest_results:
            print("FAIL: the two PCs' finish lists differ")
            ok = False
        else:
            print("The finish lists agree.")
    print("SYNC CHECK: " + ("PASS" if ok else "FAIL"))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
