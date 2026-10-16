#!/usr/bin/env bash
# Runs a headless physics scenario and writes its telemetry to .sim_output/<scenario>.csv.
# Lets you (or an AI) check the physics with numbers instead of guesses.
#
#   tools/simulate.sh beam_reach                 60 s on a beam reach in 15 kt
#   tools/simulate.sh close_hauled 90            90 s upwind
#   tools/simulate.sh beam_reach 60 --wind_kt=20 --twa=100
#
# Scenarios are GDScript files in Game/dev/scenarios/ (see sim_scenario.gd).
# The summary is printed; the CSV has one row per 0.1 s (change with --every=<steps>).
set -euo pipefail
source "$(dirname "$0")/common.sh"

scenario="${1:-beam_reach}"
seconds="${2:-60}"
if [[ $# -gt 0 ]]; then shift; fi
if [[ $# -gt 0 ]]; then shift; fi

mkdir -p "$REPO_ROOT/.sim_output"
out="$REPO_ROOT/.sim_output/$scenario.csv"

godot="$(find_godot)"
import_project "$godot"
"$godot" --headless --no-header --path "$PROJECT_DIR" -s res://dev/run_scenario.gd -- \
	"--scenario=$scenario" "--seconds=$seconds" "--out=$out" "$@"
