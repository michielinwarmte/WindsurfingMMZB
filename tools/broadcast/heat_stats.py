"""What the AI did in an event week's heats, from the game's log.

    python -E tools/broadcast/heat_stats.py <log> [<log> ...]

Reads the "EVENT elimination ..." lines EventBroadcast writes for every heat (each board's place,
its finish time or where it was, its falls and its split times: the start line, every mark, the
finish) and prints, over all heats: the winner's time, how many were home when the heat was decided,
when the boards crossed the start line, how long each leg took (the fastest board and the middle
one), how many boards lost more than half a minute on a leg (a missed mark), and how many gave up.
The stream's leader, for comparison: legs of 32, 33, 38, 38 and 40 s, home after about 187 s.
"""
import re
import statistics
import sys

STREAM_LEGS = [32, 33, 38, 38, 40]


def main():
    heats = []
    for path in sys.argv[1:]:
        with open(path, encoding="utf-8", errors="replace") as f:
            for line in f:
                m = re.match(r"EVENT elimination (\d+), ([^:]+): (.*)", line)
                if not m:
                    continue
                boards = []
                for part in m.group(3).split("; "):
                    b = re.match(r"(\d+) (.+?) \(seed (\d+), (.+?), falls (\d+), splits ?([\d ]*)\)", part.strip())
                    if not b:
                        continue
                    state = b.group(4)
                    boards.append({"place": int(b.group(1)), "name": b.group(2), "seed": int(b.group(3)),
                                   "time": float(state.split()[0]) if state.endswith(" s") else None,
                                   "gave_up": state.startswith("gave up"), "falls": int(b.group(5)),
                                   "splits": [float(x) for x in b.group(6).split()]})
                if boards:
                    heats.append({"name": "elimination %s, %s" % (m.group(1), m.group(2)), "boards": boards})
    if not heats:
        print("no heats in the log")
        return
    print("%d heats, %d boards" % (len(heats), sum(len(h["boards"]) for h in heats)))
    winners = [h["boards"][0]["time"] for h in heats if h["boards"][0]["time"] is not None]
    print("the winner's time: %.0f to %.0f s, the middle %.0f s (the stream's leader: about 187 s)"
          % (min(winners), max(winners), statistics.median(winners)))
    home = [sum(1 for b in h["boards"] if b["time"] is not None) for h in heats]
    print("home when the heat was decided: %s of 8 (the middle %.0f)" % (" ".join(str(n) for n in home), statistics.median(home)))
    gave_up = [sum(1 for b in h["boards"] if b["gave_up"]) for h in heats]
    if any(gave_up):
        print("gave up: %s (%d in all)" % (" ".join(str(n) for n in gave_up), sum(gave_up)))
    falls = sum(b["falls"] for h in heats for b in h["boards"])
    print("falls after the gun: %d (%.1f a heat)" % (falls, falls / len(heats)))
    starts = sorted(b["splits"][0] for h in heats for b in h["boards"] if b["splits"])
    print("over the start line after the gun: the middle %.0f s, nine in ten within %.0f s, the latest %.0f s; %d of %d boards never started"
          % (statistics.median(starts), starts[int(len(starts) * 0.9) - 1], starts[-1],
             sum(1 for h in heats for b in h["boards"] if not b["splits"]), sum(len(h["boards"]) for h in heats)))
    seeds_through = [b["seed"] for h in heats for b in h["boards"][:4]]
    print("the four who went through had seeds with the middle %.0f (by chance it would be about 32)" % statistics.median(seeds_through))
    print()
    print("leg                 the fastest  the middle  the stream's leader  boards over the middle + 30 s")
    for leg in range(5):
        times = [b["splits"][leg + 1] - b["splits"][leg] for h in heats for b in h["boards"] if len(b["splits"]) > leg + 1]
        if not times:
            continue
        middle = statistics.median(times)
        slow = sum(1 for t in times if t > middle + 30.0)
        # A board that never completed the leg although others of its heat did, and had started it.
        stuck = sum(1 for h in heats for b in h["boards"] if len(b["splits"]) == leg + 1 and b["time"] is None)
        name = "start to mark 1" if leg == 0 else ("mark 4 to finish" if leg == 4 else "mark %d to mark %d" % (leg, leg + 1))
        print("%-19s %8.0f s %9.0f s %15d s      %3d of %d; %d more did not complete it"
              % (name, min(times), middle, STREAM_LEGS[leg], slow, len(times), stuck))


if __name__ == "__main__":
    main()
