#!/usr/bin/env bash
# Times the sea's queries and a whole board's physics tick on the waves (F1, the sea query;
# Documentation/AI_FLEET_PLAN.md, D2). About half a minute. The numbers depend on the
# machine and on what else it is doing: compare runs on the same machine, back to back.
#
#   tools/sea_bench.sh                      20 000 points, 600 ticks
#   tools/sea_bench.sh --points=5000 --ticks=300
#
# The options are in Game/dev/sea_bench.gd.
set -euo pipefail
source "$(dirname "$0")/common.sh"

godot="$(find_godot)"
import_project "$godot"
"$godot" --headless --no-header --path "$PROJECT_DIR" -s res://dev/sea_bench.gd -- "$@"
