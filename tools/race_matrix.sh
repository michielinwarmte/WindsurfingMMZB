#!/usr/bin/env bash
# The race matrix (RACING_PLAN.md, Part 9B): the four scripted characters (allrounder, cautious,
# gambler, rookie) on the line together, on T1 (t1_loop, open water) and T2 (t2_slalom, raced on the
# open water's sea as tools/race.sh does) at 12, 18 and 24 kt; one race each, one line per board
# (place, time or DNF, the steps done, the splits, falls, tacks and gybes). Printed and saved to
# .sim_output/race_matrix.txt; each race's CSV files go to .sim_output/race_matrix/<course>_<wind>/.
#
#   tools/race_matrix.sh                 the six races (four boards each: some 30 minutes)
#   tools/race_matrix.sh --seed=3        another seed for the skippers' steering noise
#
# Extra options go to every race (Game/dev/run_race.gd lists them). The countdown is the game's
# 60 s; the race waits up to 15 minutes after the first finisher, so every board gets a time.
set -euo pipefail
source "$(dirname "$0")/common.sh"

skippers="allrounder,cautious,gambler,rookie"
out="$REPO_ROOT/.sim_output/race_matrix.txt"
mkdir -p "$REPO_ROOT/.sim_output/race_matrix"
godot="$(find_godot)"
import_project "$godot"
: > "$out"
for course in t1_loop t2_slalom; do
	for wind in 12 18 24; do
		dir="$REPO_ROOT/.sim_output/race_matrix/${course}_${wind}"
		mkdir -p "$dir"
		"$godot" --headless --no-header --path "$PROJECT_DIR" -s res://dev/run_race.gd -- \
			"--course=$course" "--wind_kt=$wind" "--skippers=$skippers" --prestart=60 --seconds=1500 \
			--finish_window=900 "--out_dir=$dir" "$@" > "$dir/out.txt" 2>&1
		{
			echo "== $course at $wind kt"
			grep -E '^[0-9]+\. ' "$dir/out.txt" || echo "(no result: see $dir/out.txt)"
		} | tee -a "$out"
	done
done
echo "Saved to $out"
