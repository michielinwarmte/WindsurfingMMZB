#!/usr/bin/env bash
# Runs the whole manoeuvre matrix (tacks, gybes, turns on a run, out of irons, straight
# sailing) with the beginner controller in one Godot process and prints one line per case.
# Per-case CSV files go to .sim_output/matrix/<case>_<kt>.csv for .scratch/trace.py.
#
#   tools/matrix.sh                      every case at 12, 18 and 24 kt
#   tools/matrix.sh --only=tack          only the cases whose name contains "tack"
#   tools/matrix.sh --winds=18           only at 18 kt
#   tools/matrix.sh --every=1            a CSV row every step instead of every second one
set -euo pipefail
source "$(dirname "$0")/common.sh"

out_dir="$REPO_ROOT/.sim_output/matrix"
mkdir -p "$out_dir"
godot="$(find_godot)"
import_project "$godot"
"$godot" --headless --no-header --path "$PROJECT_DIR" -s res://dev/run_matrix.gd -- \
	"--out_dir=$out_dir" "$@"
