#!/usr/bin/env bash
# The steering check (Documentation/reports/push_slider/PLAN.md, round 3): how fast the beginner's
# controller turns the board from a planing reach, heading up and bearing away, at 12, 18 and
# 24 kt, with the legs on or off (PlayerController.legs_share) and the push slider at a level.
# One line per wind and direction: the time to turn 30 and 60 degrees, the peak yaw rate, the
# speed, the helm, a fall. The options are in Game/dev/steer_check.gd.
#
#   tools/steer_check.sh                                  the controller as it is
#   tools/steer_check.sh --legs=0.5 --run=legs05           the legs carrying half the helm
#   tools/steer_check.sh --push=0.85 --waves=1 --gusts=1   at 85 % on the sea
set -euo pipefail
source "$(dirname "$0")/common.sh"

run="latest"
extra=()
for arg in "$@"; do
	case "$arg" in
		--run=*) run="${arg#--run=}" ;;
		*) extra+=("$arg") ;;
	esac
done

out_dir="$REPO_ROOT/.sim_output/steer/$run"
mkdir -p "$out_dir"
rm -f "$out_dir/results.csv"
godot="$(find_godot)"
import_project "$godot"
"$godot" --headless --no-header --path "$PROJECT_DIR" -s res://dev/steer_check.gd -- \
	"--out=$out_dir/results.csv" "--label=$run" ${extra[@]+"${extra[@]}"} 2>&1 | tee "$out_dir/log.txt" | grep -vE '^\s*$'
(cd "$REPO_ROOT" && git checkout -- Game/project.godot Game/default_bus_layout.tres 2>/dev/null || true)
echo "Results: $out_dir/results.csv"
