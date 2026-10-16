#!/usr/bin/env bash
# The manoeuvre matrix on Lake Silvaplana (MAP_SILVAPLANA_PLAN.md W5): the cases of
# tools/matrix.sh sailed in the lake's environment (thin air, fresh water, the map's wind with
# its gusts and lulls) at 12:00, 14:30 and 17:00, one line per case. Game/dev/run_lake.gd.
#
#   tools/lake_matrix.sh                       every case at the three times
#   tools/lake_matrix.sh --times=14:30         only at 14:30
#   tools/lake_matrix.sh --only=tack           only the cases whose name contains "tack"
#   tools/lake_matrix.sh --wind=steady         the lake's mean wind of each time, no gusts
#   tools/lake_matrix.sh --air=1.225           sea-level air on the lake
#   tools/lake_matrix.sh --compare=1           the thin-air comparison (a straight beam reach)
#   tools/lake_matrix.sh --csv=1               a CSV per case in .sim_output/lake/
set -euo pipefail
source "$(dirname "$0")/common.sh"

extra=()
for arg in "$@"; do
	if [[ "$arg" == "--csv=1" ]]; then
		mkdir -p "$REPO_ROOT/.sim_output/lake"
		extra+=("--out_dir=$REPO_ROOT/.sim_output/lake")
	else
		extra+=("$arg")
	fi
done
godot="$(find_godot)"
import_project "$godot"
"$godot" --headless --no-header --path "$PROJECT_DIR" -s res://dev/run_lake.gd -- "${extra[@]}"
