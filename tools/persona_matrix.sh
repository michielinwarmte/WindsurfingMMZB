#!/usr/bin/env bash
# The personas by course family (AI_FLEET_PLAN.md, D3 and F4): the twelve personas race each other
# headless on a windward-leeward (the course family) and on a slalom (the slalom family), at one
# wind, and the places are put side by side, so the specialists show: a slalom specialist near the
# top of the slalom and down the order on the windward-leeward, and the other way round.
#
#   tools/persona_matrix.sh                     LG2 at 40 % and PD3 at 60 %, 15 kt, 60 s countdown (some 20 minutes)
#   tools/persona_matrix.sh --wind_kt=18 --seed=2
#   tools/persona_matrix.sh --personas=lena,tobias,mara,jonas    a few of them
#
# Extra options go to both races (Game/dev/run_race.gd lists them). The two races run as two Godot
# processes at once; the result lines and the table are printed and saved to
# .sim_output/persona_matrix.txt; each race's CSV files go to .sim_output/persona_matrix/<family>/.
set -euo pipefail
source "$(dirname "$0")/common.sh"

wind=15
seed=1
personas=""
extra=()
for arg in "$@"; do
	case "$arg" in
		--wind_kt=*) wind="${arg#*=}" ;;
		--seed=*) seed="${arg#*=}" ;;
		--personas=*) personas="${arg#*=}" ;;
		*) extra+=("$arg") ;;
	esac
done
if [[ -z "$personas" ]]; then
	personas="$(ls "$REPO_ROOT/Game/race/personas/"*.tres | xargs -n1 basename | sed 's/\.tres$//' | tr '\n' ',' | sed 's/,$//')"
fi
skippers="$(echo "$personas" | sed 's/\([^,]*\)/persona:\1/g')"

out="$REPO_ROOT/.sim_output/persona_matrix.txt"
mkdir -p "$REPO_ROOT/.sim_output/persona_matrix"
godot="$(find_godot)"
import_project "$godot"
declare -A courses=([course]="template:LG2@40" [slalom]="template:PD3@60")
for family in course slalom; do
	dir="$REPO_ROOT/.sim_output/persona_matrix/$family"
	mkdir -p "$dir"
	"$godot" --headless --no-header --path "$PROJECT_DIR" -s res://dev/run_race.gd -- \
		"--course=${courses[$family]}" "--wind_kt=$wind" "--skippers=$skippers" --prestart=60 --seconds=1500 \
		--finish_window=900 "--seed=$seed" "--out_dir=$dir" "${extra[@]+"${extra[@]}"}" > "$dir/out.txt" 2>&1 &
done
wait

: > "$out"
for family in course slalom; do
	dir="$REPO_ROOT/.sim_output/persona_matrix/$family"
	{
		echo "== ${courses[$family]} at $wind kt (the $family family)"
		grep -E '^ *[0-9]+\. ' "$dir/out.txt" || echo "(no result: see $dir/out.txt)"
	} | tee -a "$out"
done

# The table: one line per persona, its place on each family, and the difference.
{
	echo
	printf '%-14s %8s %8s   %s\n' "persona" "course" "slalom" "specialist?"
	for name in $(echo "$personas" | tr ',' ' '); do
		shown="$(grep -m1 '^name = ' "$REPO_ROOT/Game/race/personas/$name.tres" | sed 's/name = "\(.*\)"/\1/')"
		pc="$(grep -E "^ *[0-9]+\. +$shown( |$)" "$REPO_ROOT/.sim_output/persona_matrix/course/out.txt" | head -1 | sed -E 's/^ *([0-9]+)\..*/\1/')"
		ps="$(grep -E "^ *[0-9]+\. +$shown( |$)" "$REPO_ROOT/.sim_output/persona_matrix/slalom/out.txt" | head -1 | sed -E 's/^ *([0-9]+)\..*/\1/')"
		note=""
		if [[ -n "$pc" && -n "$ps" ]]; then
			if (( ps + 3 <= pc )); then note="slalom"; elif (( pc + 3 <= ps )); then note="course"; fi
		fi
		printf '%-14s %8s %8s   %s\n' "$shown" "${pc:--}" "${ps:--}" "$note"
	done
} | tee -a "$out"
echo "Saved to $out"
