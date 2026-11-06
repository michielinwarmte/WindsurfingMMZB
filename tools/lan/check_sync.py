"""LAN multiplayer's sync check (tools/lan_test.sh; Documentation/reports/multiplayer/PLAN.md).

Reads the host's and the guest's logs. A TRACK line is a board as the PC that sails it had it at a
host tick; a SEEN line is a board as the other PC showed it for that same tick. For every SEEN line
with a TRACK line of the same board and tick, the differences are measured: the place (m), the heading
(degrees), the speed (m/s), the mast's direction, the sailor's lean, and whether the sailor was on the
board on both; and (newer builds) the heel and the pitch, the rail and trim the sailor's feet aim for,
and how the feet press (the toes' share of their roll moment, the weight's share on the back foot), which
carry the body on the mouse (package B, GP2: the feet's press). Then the RESULT lines (each PC's finish list) are
compared.

    python -I tools/lan/check_sync.py .logs/lan/host.log .logs/lan/guest.log

Exits 1 when a shown board is more than PLACE_TOLERANCE_M from where its PC had it, or the finish
lists differ.

Spectating (Documentation/reports/multiplayer/spectate_6nov.md): a PC whose player spectates from the
start prints SPECTATOR; it sends no board, so the other PC must show none of it (no SEEN of its slot),
and it must have seen every board the other PC sails. Its WATCH lines (the board the camera went to:
tick, network number, name, place) must name at least two boards, one of them a player's. PARKED and
ON_THE_WATER lines (a board leaving the water to watch, and back at a start) are listed.
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
    extra = {"spectator": None, "watched": [], "moves": []}
    with open(path, encoding="utf-8", errors="replace") as log:
        for line in log:
            parts = line.split()
            if not parts:
                continue
            if parts[0] in ("TRACK", "SEEN") and len(parts) >= 12:
                tick, board = int(parts[1]), int(parts[2])
                numbers = [float(v) for v in parts[3:11]] + [int(parts[11])] + [float(v) for v in parts[12:18]]
                (tracks if parts[0] == "TRACK" else seens)[(tick, board)] = numbers
            elif parts[0] == "JUDGED" and len(parts) >= 5:
                judged[(int(parts[1]), int(parts[2]))] = (float(parts[3]), float(parts[4]))
            elif parts[0] == "RESULT":
                results.append(parts[1:])
            elif parts[0] == "SPECTATOR" and len(parts) >= 2:
                extra["spectator"] = int(parts[1])
            elif parts[0] == "WATCH" and len(parts) >= 5:
                extra["watched"].append((int(parts[1]), int(parts[2]), parts[3], parts[4]))
            elif parts[0] in ("PARKED", "ON_THE_WATER") and len(parts) >= 3:
                extra["moves"].append((parts[0], int(parts[1]), parts[2]))
            elif ("SCRIPT ERROR" in line or line.startswith("ERROR")) and not any(noise in line for noise in SHUTDOWN_NOISE):
                errors.append(line.strip())
    read.judged = judged
    read.extra = extra
    return tracks, seens, results, errors


def check_spectator(label, spectator, own_seens, other_tracks, other_seens):
    """A spectator (its slot) saw every board the other PC sails and was drawn by none; it watched at
    least two boards, one a player's. Returns whether all holds."""
    ok = True
    seen_boards = {key[1] for key in own_seens if key in other_tracks}
    sailed = {key[1] for key in other_tracks}
    missing = sorted(sailed - seen_boards)
    print("%s spectates (slot %d): it saw %d of the %d boards the other PC sails%s"
          % (label, spectator["slot"], len(sailed & seen_boards), len(sailed), (", missing %s" % missing) if missing else ""))
    if missing:
        print("FAIL: the spectator did not see every board")
        ok = False
    drawn = [key for key in other_seens if key[1] == spectator["slot"]]
    if drawn:
        print("FAIL: the other PC drew the spectator's board %d times" % len(drawn))
        ok = False
    boards = []
    for _tick, board, name, place in spectator["watched"]:
        if board not in [b for b, _n, _p in boards]:
            boards.append((board, name, place))
    print("%s watched: %s" % (label, ", ".join("%d %s (%s)" % b for b in boards) or "nothing"))
    if len(boards) < 2 or not any(b < 100 for b, _n, _p in boards):
        print("FAIL: the spectator's camera did not go round the racers (Tab)")
        ok = False
    return ok


def compare(label, seens, tracks):
    worst = {"place": 0.0, "height": 0.0, "heading": 0.0, "speed": 0.0, "mast": 0.0, "lean": 0.0,
             "heel": 0.0, "pitch": 0.0, "rail_aim": 0.0, "trim_aim": 0.0, "toes": 0.0, "back_foot": 0.0}
    # The largest rail and trim aims a PC sent, and the feet's largest press (the body's), to show what
    # was compared.
    aims = {"rail": 0.0, "trim": 0.0, "toes": 0.0, "back_foot": 0.0}
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
        if len(seen) >= 15 and len(track) >= 15:
            for i, name in enumerate(("toes", "back_foot")):
                worst[name] = max(worst[name], abs(seen[13 + i] - track[13 + i]))
            aims["toes"] = max(aims["toes"], abs(track[13]))
            aims["back_foot"] = max(aims["back_foot"], track[14])
    print("%s: %d moments of %d boards compared (of %d shown); worst: place %.4f m, height %.4f m, heading %.3f deg, "
          "speed %.4f m/s, mast %.5f, lean %.5f; sailor on/off the board differed %d times"
          % (label, matched, len(boards), len(seens), worst["place"], worst["height"], worst["heading"], worst["speed"],
             worst["mast"], worst["lean"], state_mismatch))
    print("%s  heel %.4f deg, pitch %.4f deg, the bank the feet aim for %.4f deg (a turn's too) and their trim aim "
          "%.4f deg (the largest sent: bank %.2f deg, trim %.2f deg)"
          % (" " * len(label), worst["heel"], worst["pitch"], worst["rail_aim"], worst["trim_aim"], aims["rail"], aims["trim"]))
    print("%s  the feet's press: toes %.4f, back foot %.4f (the largest sent: toes %.2f, weight on the back foot %.2f)"
          % (" " * len(label), worst["toes"], worst["back_foot"], aims["toes"], aims["back_foot"]))
    return matched, worst


def by_race(results):
    """The RESULT lines grouped by their race's number (the first field)."""
    races = {}
    for parts in results:
        if parts:
            races.setdefault(parts[0], []).append(parts[1:])
    return races


def main():
    host_tracks, host_seens, host_results, host_errors = read(sys.argv[1])
    host_judged = read.judged
    first_extra = read.extra
    guest_tracks, guest_seens, guest_results, guest_errors = read(sys.argv[2])
    second_extra = read.extra
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
    for who, extra in (("first", first_extra), ("second", second_extra)):
        for kind, tick, role in extra["moves"]:
            print("The %s PC's board: %s at tick %d (%s)" % (who, "off the water, watching" if kind == "PARKED" else "back on the water", tick, role))
    # A spectator sends no board: nothing of it to compare, and that is right.
    first_spectates = first_extra["spectator"] is not None
    second_spectates = second_extra["spectator"] is not None
    if first_spectates:
        ok = check_spectator("The first PC", {"slot": first_extra["spectator"], "watched": first_extra["watched"]},
                             host_seens, guest_tracks, guest_seens) and ok
    if second_spectates:
        ok = check_spectator("The second PC", {"slot": second_extra["spectator"], "watched": second_extra["watched"]},
                             guest_seens, host_tracks, host_seens) and ok
    if (matched_g == 0 and not first_spectates) or (matched_h == 0 and not second_spectates):
        print("FAIL: nothing to compare (did the two connect? see the logs)")
        ok = False
    for worst in (worst_g, worst_h):
        if worst["place"] > PLACE_TOLERANCE_M:
            print("FAIL: a board shown %.3f m from where its PC had it (tolerance %.2f m)" % (worst["place"], PLACE_TOLERANCE_M))
            ok = False
    # Each RESULT line starts with the race's number (a race after a race, RACE_DIRECTOR.md R4); a PC
    # that joined later has only the later races: the races both have are compared.
    host_races, guest_races = by_race(host_results), by_race(guest_results)
    common = sorted(set(host_races) & set(guest_races))
    for number in common:
        print("Race %s on the first:  %s" % (number, "; ".join(" ".join(r) for r in host_races[number])))
        print("Race %s on the second: %s" % (number, "; ".join(" ".join(r) for r in guest_races[number])))
        if host_races[number] != guest_races[number]:
            print("FAIL: the two PCs' finish lists of race %s differ" % number)
            ok = False
        else:
            print("The finish lists of race %s agree." % number)
    if (host_races or guest_races) and not common:
        print("No race finished on both PCs (first: races %s, second: races %s)." % (sorted(host_races), sorted(guest_races)))
    print("SYNC CHECK: " + ("PASS" if ok else "FAIL"))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
