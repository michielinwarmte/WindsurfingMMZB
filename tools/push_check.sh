#!/usr/bin/env bash
# GP0 (ROADMAP.md, section GP): measures the push before it is built. The board is sailed by
# the player's beginner controller with the auto-sheet, holding a true wind angle on the game's
# open water (waves, the height gradient, gusts), and the autopilot's margin or the sailor's
# technique targets are set per case. One line per case: the speed made good, the VMG, the
# falls, the fin's load and slip, the heel, the trim. Each case is also a row in
# .sim_output/push/<run>/results.csv, and each fall a row in falls.csv with the 2 s before it.
#
#   tools/push_check.sh --sweep=pilot.hike_share=0.8,1.1,1.4           the push's main number
#   tools/push_check.sh --winds=18 --twas=100 --gusts=0 --waves=0      one steady case
#   tools/push_check.sh --sweep=sailor.fin_load_bank_deg=0,4,8 \
#       --sweep2=sailor.running_trim_deg+sailor.running_trim_fast_deg=1,2,3   the rail and the back foot
#   tools/push_check.sh --timing=1 --pilot.hike_share=1.4 --timing_lead_s=1 \
#       --timing_ease='pilot.hike_share:1.0'                            easing before each gust
#   tools/push_check.sh --jobs=4 --run=<name> ...                       four Godot processes at once
#
# --jobs splits the cases over that many processes (default 1). Keep it well below the number of
# cores on Max's laptop: it crashed under full load (ROADMAP.md, RA5). --run names the output
# folder (default "latest"; an existing results.csv there is replaced). The options are in
# Game/dev/run_push.gd.
set -euo pipefail
source "$(dirname "$0")/common.sh"

jobs=1
run="latest"
extra=()
for arg in "$@"; do
	case "$arg" in
		--jobs=*) jobs="${arg#--jobs=}" ;;
		--run=*) run="${arg#--run=}" ;;
		*) extra+=("$arg") ;;
	esac
done

out_dir="$REPO_ROOT/.sim_output/push/$run"
mkdir -p "$out_dir"
rm -f "$out_dir"/results*.csv "$out_dir"/falls*.csv "$out_dir"/log*.txt
godot="$(find_godot)"
import_project "$godot"

pids=()
for ((i = 0; i < jobs; i++)); do
	"$godot" --headless --no-header --path "$PROJECT_DIR" -s res://dev/run_push.gd -- \
		"--slice=$i/$jobs" "--out=$out_dir/results_$i.csv" "--falls_out=$out_dir/falls_$i.csv" "--label=$run" \
		${extra[@]+"${extra[@]}"} > "$out_dir/log_$i.txt" 2>&1 &
	pids+=($!)
done
status=0
for pid in "${pids[@]}"; do
	wait "$pid" || status=1
done

# One table and one CSV for the run, in the order the cases were listed.
head -n 2 "$out_dir/log_0.txt"
for ((i = 0; i < jobs; i++)); do
	grep -E '^ *[0-9]+ +[0-9]+ ' "$out_dir/log_$i.txt" || true
done
for kind in results falls; do
	first=1
	for ((i = 0; i < jobs; i++)); do
		file="$out_dir/${kind}_$i.csv"
		[[ -f "$file" ]] || continue
		if [[ $first == 1 ]]; then cat "$file"; first=0; else tail -n +2 "$file"; fi
	done > "$out_dir/$kind.csv"
done
grep -h -iE 'error|script_error' "$out_dir"/log_*.txt | head -n 20 || true
echo "Results: $out_dir/results.csv (falls: falls.csv)"
exit $status
