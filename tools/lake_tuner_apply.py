#!/usr/bin/env python3
"""Writes the lake tuner's best set (Documentation/reports/autopilot/lake_speed/best.txt) into
PlayerController.NIGHT_TUNING (Game/windsurfer/player_controller.gd): the player's board only, the AI
fleet keeps the code's defaults. Used by tools/lake_tuner_apply.sh.

    python -I tools/lake_tuner_apply.py [--best=<path>]
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONTROLLER = os.path.join(ROOT, "Game", "windsurfer", "player_controller.gd")
HEAD = "const NIGHT_TUNING: Dictionary[String, float] = {"


def read_best(path):
    numbers = []
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            match = re.match(r"^--controller\.(\w+)=(-?[\d.eE+-]+)\s*$", line.strip())
            if match:
                numbers.append((match.group(1), float(match.group(2))))
    return numbers


def main():
    options = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
    best = options.get("best", os.path.join(ROOT, "Documentation", "reports", "autopilot", "lake_speed", "best.txt"))
    numbers = read_best(best)
    if not numbers:
        sys.exit(f"no numbers in {best}")
    with open(CONTROLLER, encoding="utf-8") as handle:
        text = handle.read()
    before, rest = text.split(HEAD, 1)
    _old, after = rest.split("\n}\n", 1)
    body = "".join(f'\n\t"{name}": {value:.6g},' for name, value in numbers)
    # Every value as a float literal (GDScript's typed dictionary wants floats).
    body = re.sub(r": (-?\d+),", r": \1.0,", body)
    with open(CONTROLLER, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(before + HEAD + body + "\n}\n" + after)
    print(f"NIGHT_TUNING: {len(numbers)} numbers from {best}")


if __name__ == "__main__":
    main()
