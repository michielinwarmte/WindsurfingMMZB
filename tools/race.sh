#!/usr/bin/env bash
# Runs a race without a window (RACING_PLAN.md, Part 9A) and prints one line per board at the end:
# its place, finish time or DNF, the steps of the course it completed, its splits and its falls.
# Each board's track goes to .sim_output/race/<board>.csv (race time, x, z, heading, speed, next step).
# In 9A every board is the plain autopilot holding one wind angle, so none of them finishes yet.
#
#   tools/race.sh                                   the test loop, one board, 300 s after the gun
#   tools/race.sh --course=test --seconds=60        a minute
#   tools/race.sh --course=Game/maps/silvaplana/courses/<name>.json --boards=4 --laps=2
#   tools/race.sh --wind_kt=24 --prestart=30 --twa=60
#
# The options are explained in Game/dev/run_race.gd.
set -euo pipefail
source "$(dirname "$0")/common.sh"

out_dir="$REPO_ROOT/.sim_output/race"
mkdir -p "$out_dir"
godot="$(find_godot)"
import_project "$godot"
"$godot" --headless --no-header --path "$PROJECT_DIR" -s res://dev/run_race.gd -- \
	"--out_dir=$out_dir" "$@"
