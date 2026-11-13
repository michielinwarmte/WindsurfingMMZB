#!/usr/bin/env bash
# The lake-speed suite of 7 November 2026 (Max: balance getting going, no nose dives in a strong
# wind, the speed across and downwind in the waves on Lake Silvaplana, three gear combos). One Godot
# process per case in a pool; the options and the scoring are in tools/lake_suite.py, the report in
# Documentation/reports/autopilot/lake_speed/README.md.
#
#   tools/lake_suite.sh --label=baseline [--cores=12] [--cases=1] [--refs=1] [--controller.<field>=<n> ...]
set -euo pipefail
source "$(dirname "$0")/common.sh"

godot="$(find_godot)"
import_project "$godot"
python_bin="python3"
if ! python3 -c "" >/dev/null 2>&1; then
	python_bin="python"
fi
status=0
"$python_bin" -I "$REPO_ROOT/tools/lake_suite.py" "--godot=$godot" "$@" || status=$?
(cd "$REPO_ROOT" && git checkout -- Game/project.godot Game/default_bus_layout.tres 2>/dev/null || true)
exit $status
