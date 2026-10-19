#!/usr/bin/env bash
# Runs a race without a window (RACING_PLAN.md, Parts 9A and 9B) and prints one line per board at the
# end: its place, finish time or DNF, the steps of the course it completed, its splits, its falls,
# and the tacks and gybes it made. Each board's track goes to .sim_output/race/<board>.csv (race
# time, x, z, heading, speed, next step, what its skipper is doing).
#
#   tools/race.sh                                   the test loop, one autopilot board, 300 s after the gun
#   tools/race.sh --course=t1_loop --skippers=allrounder --prestart=60 --seconds=420
#   tools/race.sh --course=t2_slalom --skippers=allrounder,cautious,gambler,rookie --wind_kt=18
#   tools/race.sh --course=t1_loop --skippers=rookie --seed=3    the same seed, the same race
#   tools/race.sh --course=Game/maps/silvaplana/courses/<name>.json --boards=4 --laps=2
#   tools/race.sh --wind_kt=24 --prestart=30 --twa=60              the 9A autopilot (--skippers=autopilot)
#
# The skippers are the character sheets in Game/race/skippers/ (allrounder, cautious, gambler,
# rookie); "autopilot" is the plain fixed-angle pilot of 9A. The options are explained in
# Game/dev/run_race.gd.
set -euo pipefail
source "$(dirname "$0")/common.sh"

out_dir="$REPO_ROOT/.sim_output/race"
mkdir -p "$out_dir"
godot="$(find_godot)"
import_project "$godot"
"$godot" --headless --no-header --path "$PROJECT_DIR" -s res://dev/run_race.gd -- \
	"--out_dir=$out_dir" "$@"
