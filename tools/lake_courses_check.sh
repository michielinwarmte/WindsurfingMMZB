#!/usr/bin/env bash
# Races the AI fleet on every iQFOiL course laid on Lake Silvaplana (Game/maps/silvaplana/courses/
# iq_*.json, made by tools/fit_courses.sh --all=1) and counts the boards that run aground (Max,
# 6 November 2026: "be sure that the ai can race all the iq courses on silvaplana without going onto
# the shore"). One headless race per course (Game/dev/run_race.gd --map=lake), several side by side;
# each race's output in .sim_output/lake_iq/<run>/<course>.txt, and a table at the end: the course,
# how many boards finished, how many ran aground, and the AGROUND lines.
#
#   tools/lake_courses_check.sh [--run=guard] [--time=14:30] [--skippers=allrounder,cautious,gambler,rookie]
#                               [--jobs=8] [--shore_guard=1] [--courses=iq_o2,iq_lg2] [--seed=0]
set -euo pipefail
source "$(dirname "$0")/common.sh"

run="guard"
time_of_day="14:30"
skippers="allrounder,cautious,gambler,rookie"
jobs=8
shore_guard=1
courses=""
seed=0
for arg in "$@"; do
	case "$arg" in
		--run=*) run="${arg#*=}" ;;
		--time=*) time_of_day="${arg#*=}" ;;
		--skippers=*) skippers="${arg#*=}" ;;
		--jobs=*) jobs="${arg#*=}" ;;
		--shore_guard=*) shore_guard="${arg#*=}" ;;
		--courses=*) courses="${arg#*=}" ;;
		--seed=*) seed="${arg#*=}" ;;
		*) echo "Unknown option $arg" >&2; exit 2 ;;
	esac
done

out="$REPO_ROOT/.sim_output/lake_iq/$run"
mkdir -p "$out"
godot="$(find_godot)"
import_project "$godot"
if [[ -z "$courses" ]]; then
	courses="$(cd "$PROJECT_DIR/maps/silvaplana/courses" && ls iq_*.json | sed 's/\.json$//' | paste -sd, -)"
fi
IFS=',' read -r -a list <<< "$courses"

race_one() {
	local course="$1"
	"$godot" --headless --no-header --path "$PROJECT_DIR" -s res://dev/run_race.gd -- \
		--out_dir="$out/csv_$course" --map=lake --time="$time_of_day" --course="$course" --skippers="$skippers" \
		--shore_guard="$shore_guard" --seed="$seed" --spawn=random --finish_window=300 > "$out/$course.txt" 2>&1 || true
}
export -f race_one
export godot out time_of_day skippers shore_guard seed PROJECT_DIR
printf '%s\n' "${list[@]}" | xargs -P "$jobs" -I{} bash -c 'race_one "$@"' _ {}

echo "Lake Silvaplana at $time_of_day, $skippers, shore lookout $shore_guard ($run):"
total=0
for course in "${list[@]}"; do
	file="$out/$course.txt"
	finished=$(grep -cE "^ *[0-9]+\. .* [0-9]+:[0-9]" "$file" || true)
	aground=$(grep -c "^AGROUND" "$file" || true)
	total=$((total + aground))
	printf '  %-8s aground %d   %s\n' "$course" "$aground" "$(grep -E "^Finished|^Stopped" "$file" | head -1)"
	grep "^AGROUND\|SCRIPT ERROR" "$file" | head -6 | sed 's/^/      /'
done
echo "In all: $total boards aground."
