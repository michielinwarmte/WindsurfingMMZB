#!/usr/bin/env bash
# The night of 7 November 2026's scenario suite for the autopilot (the player's controller): light
# wind, steering below the plane, taps, Shift carve, flying, the reflex, tacks and gybes. One Godot
# process per case in a pool; the options and the scoring are in tools/night_suite.py, the report in
# Documentation/reports/autopilot/night_7nov/README.md.
#
#   tools/night_suite.sh --label=baseline [--cores=14] [--cases=1] [--controller.<field>=<n> ...]
set -euo pipefail
source "$(dirname "$0")/common.sh"

godot="$(find_godot)"
import_project "$godot"
python_bin="python3"
if ! python3 -c "" >/dev/null 2>&1; then
	python_bin="python"
fi
status=0
"$python_bin" -I "$REPO_ROOT/tools/night_suite.py" "--godot=$godot" "$@" || status=$?
(cd "$REPO_ROOT" && git checkout -- Game/project.godot Game/default_bus_layout.tres 2>/dev/null || true)
exit $status
