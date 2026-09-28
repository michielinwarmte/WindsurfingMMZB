#!/usr/bin/env bash
# Runs the automated tests without opening a window. Exit code 0 means everything passed.
#
#   tools/test.sh                        fast unit tests (run these after every change)
#   tools/test.sh validation             slow physics validation (after physics changes)
#   tools/test.sh all                    both
#   tools/test.sh unit -gselect=buoyancy only test files with "buoyancy" in their name
#
# Extra arguments go straight to GUT, the test framework (list them with: tools/test.sh unit -gh).
set -euo pipefail
source "$(dirname "$0")/common.sh"

suite="${1:-unit}"
if [[ $# -gt 0 ]]; then shift; fi
case "$suite" in
	unit | validation) dirs="res://tests/$suite" ;;
	all) dirs="res://tests/unit,res://tests/validation" ;;
	*)
		echo "Unknown test suite '$suite'. Use: unit, validation or all." >&2
		exit 2
		;;
esac

gut_args=(-gdir="$dirs" -ginclude_subdirs -gexit)
# Colours help in a terminal but only add noise when the output is read by a program.
if [[ ! -t 1 ]]; then gut_args+=(-gdisable_colors); fi

godot="$(find_godot)"
import_project "$godot"
"$godot" --headless --no-header --path "$PROJECT_DIR" -s res://addons/gut/gut_cmdln.gd "${gut_args[@]}" "$@"
