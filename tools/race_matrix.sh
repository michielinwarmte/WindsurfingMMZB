#!/usr/bin/env bash
# The race matrix (RACING_PLAN.md, Part 9B): the four scripted characters (allrounder, cautious,
# gambler, rookie) on the line together, on T1 (t1_loop, open water) and T2 (t2_slalom, raced on the
# open water's sea as tools/race.sh does) at 12, 18 and 24 kt; one race each, one line per board
# (place, time or DNF, the steps done, the splits, falls, tacks and gybes). Printed and saved to
# .sim_output/race_matrix.txt; each race's CSV files go to .sim_output/race_matrix/<course>_<wind>/.
#
#   tools/race_matrix.sh                 the six races, side by side (some 10 minutes)
#   tools/race_matrix.sh --seed=3        another seed for the skippers' steering noise
#   tools/race_matrix.sh --courses=t2_slalom --winds=12,24   part of the matrix
#   tools/race_matrix.sh --skippers=allrounder --seed=1 --run=solo
#                                        the all-rounder alone against the clock, kept apart from
#                                        the fleet's matrix: .sim_output/race_matrix_solo.txt and
#                                        .sim_output/race_matrix_solo/<course>_<wind>/
#
# Extra options go to every race (Game/dev/run_race.gd lists them). The countdown is the game's
# 60 s; the race runs to its own time limit (RaceTimeLimit, as in the game) and waits up to 15
# minutes after the first finisher, so every board gets a time. The
# six races run as six Godot processes at once (each one is a race of its own).
set -euo pipefail
source "$(dirname "$0")/common.sh"

skippers="allrounder,cautious,gambler,rookie"
# --run=<name> keeps this matrix apart from the others (the default: race_matrix.txt); --courses= and
# --winds= race part of it; every other option goes to the races (a later --skippers= replaces the
# four characters).
name="race_matrix"
courses="t1_loop,t2_slalom"
winds="12,18,24"
extra=()
for arg in "$@"; do
	case "$arg" in
		--run=*) name="race_matrix_${arg#--run=}" ;;
		--courses=*) courses="${arg#--courses=}" ;;
		--winds=*) winds="${arg#--winds=}" ;;
		*) extra+=("$arg") ;;
	esac
done
out="$REPO_ROOT/.sim_output/$name.txt"
mkdir -p "$REPO_ROOT/.sim_output/$name"
godot="$(find_godot)"
import_project "$godot"
races=()
for course in ${courses//,/ }; do
	for wind in ${winds//,/ }; do
		races+=("${course}_${wind}")
		dir="$REPO_ROOT/.sim_output/$name/${course}_${wind}"
		mkdir -p "$dir"
		"$godot" --headless --no-header --path "$PROJECT_DIR" -s res://dev/run_race.gd -- \
			"--course=$course" "--wind_kt=$wind" "--skippers=$skippers" --prestart=60 \
			--finish_window=900 "--out_dir=$dir" ${extra[@]+"${extra[@]}"} > "$dir/out.txt" 2>&1 &
	done
done
wait
: > "$out"
for race in "${races[@]}"; do
	dir="$REPO_ROOT/.sim_output/$name/$race"
	{
		echo "== ${race%_*} at ${race##*_} kt"
		grep -E '^[0-9]+\. ' "$dir/out.txt" || echo "(no result: see $dir/out.txt)"
	} | tee -a "$out"
done
echo "Saved to $out"
