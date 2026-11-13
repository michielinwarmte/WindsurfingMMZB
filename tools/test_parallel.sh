#!/usr/bin/env bash
# The tests as tools/test.sh runs them, but split over several Godot processes side by side, so they
# use more of the processor (tools/test.sh keeps one thread busy):
#
#   tools/test_parallel.sh                     the unit tests over 8 processes
#   tools/test_parallel.sh validation --jobs=6 the validation tests (also: all)
#
# Each process's output is in .logs/tests/part_<n>.log; the totals and any failure are printed.
# The details: tools/test_parallel.py.
set -euo pipefail
source "$(dirname "$0")/common.sh"

suite="unit"
jobs="8"
for arg in "$@"; do
	case "$arg" in
		unit | validation | all) suite="$arg" ;;
		--jobs=*) jobs="${arg#*=}" ;;
		*) echo "Unknown option '$arg'. Use: [unit|validation|all] [--jobs=<n>]" >&2; exit 2 ;;
	esac
done

godot="$(find_godot)"
import_project "$godot"
python -I "$REPO_ROOT/tools/test_parallel.py" --godot="$godot" --project="$PROJECT_DIR" \
	--jobs="$jobs" --suite="$suite" --logs="$REPO_ROOT/.logs/tests"
