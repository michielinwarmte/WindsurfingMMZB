#!/usr/bin/env bash
# The reach check of U1 (Documentation/PLAYTEST_UPGRADES.md, execution brief): the beam-reach
# scenario on flat water in a steady wind, 40 s per case, at 12, 18 and 24 kt and true wind
# angles of 60, 100 and 135 degrees, in one Godot process. One line per case: the means over
# the last 15 s of the wet part, the push, the trim, the steadiness, the loads and the speed.
#
#   tools/reach_check.sh                              all 9 cases (about a minute)
#   tools/reach_check.sh --winds=18 --twas=100        only the 18 kt beam reach
#   tools/reach_check.sh --sailor.lean_height_drop_m=0.15 --board.tail_rocker_m=0
#   tools/reach_check.sh --board.length_samples=13    the grid check (a finer buoyancy grid)
#   tools/reach_check.sh --csv=1                      also write each case's CSV to .sim_output/reach/
#   tools/reach_check.sh --fin.span_m=0.44 --fin.area_m2=0.0489   another fin (any plain number of FinConfig)
#
# The cases are set up as `tools/simulate.sh beam_reach 40 --wind_kt=W --twa=A --steady=1
# --gradient=0` sets them up; a --board.<field> override here also reaches the buoyancy grid.
# The fin columns at the end of each line: the slip, the lift, the fin's roll moment, the
# upward part of its force, its share of the stall, and the heel.
# The options are in Game/dev/run_reach.gd.
set -euo pipefail
source "$(dirname "$0")/common.sh"

extra=()
for arg in "$@"; do
	if [[ "$arg" == "--csv=1" ]]; then
		mkdir -p "$REPO_ROOT/.sim_output/reach"
		extra+=("--out_dir=$REPO_ROOT/.sim_output/reach")
	else
		extra+=("$arg")
	fi
done
godot="$(find_godot)"
import_project "$godot"
"$godot" --headless --no-header --path "$PROJECT_DIR" -s res://dev/run_reach.gd -- ${extra[@]+"${extra[@]}"}
