#!/usr/bin/env bash
# The personas side by side (AI_FLEET_PLAN.md, D3 and F4; fleet_speed package 3), so the specialists
# show. Two ways:
#
# By course family (the default): the personas race each other headless on a windward-leeward (the
# course family) and on a slalom (the slalom family), at one wind; a slalom specialist should be
# near the top of the slalom and down the order on the windward-leeward, and the other way round.
#
#   tools/persona_matrix.sh                     LG2 at 40 % and PD3 at 60 %, 15 kt, 60 s countdown (some 20 minutes)
#   tools/persona_matrix.sh --wind_kt=18 --seed=2
#   tools/persona_matrix.sh --personas=lena,tobias,mara,jonas    a few of them
#
# On the game's two courses at several winds (--courses=): every persona on T1 and T2 at 12, 18
# and 24 kt through tools/race_matrix.sh (one Godot process per race, all at once: six for the
# full matrix), then one table: each persona's place in every race, its falls, the races it did not
# finish, and whether it is a course or a slalom sailor, a light-wind or a strong-wind one.
#
#   tools/persona_matrix.sh --courses=t1_loop,t2_slalom [--winds=12,18,24] [--run=personas] [--gear=1]
#                                               (some 40 to 60 minutes for twenty personas)
#   tools/persona_matrix.sh --courses=t1_loop,t2_slalom --alone=1 [--jobs=6] [--run=solo]
#                                               each persona alone against the clock in every race (one
#                                               board, no rules or shadows to meet: the skills alone),
#                                               at most --jobs Godot processes at a time; the table
#                                               ranks the times (.sim_output/persona_alone_<run>.txt)
#   tools/persona_matrix.sh --courses=t2_slalom --run=a   then --courses=t1_loop --run=a, then
#   tools/persona_matrix.sh --courses=t1_loop,t2_slalom --run=a --table_only=1
#                                               the same in halves (fewer Godot processes at once),
#                                               and the table of both from the races already run
#
# Extra options go to every race (Game/dev/run_race.gd lists them: --gear=1, --skipper_push=0,
# --steady_hands=1, ...). The result lines and the table are printed and saved to
# .sim_output/persona_matrix.txt (by family) or .sim_output/persona_matrix_<run>.txt (by course and
# wind); each race's CSV files go to the folder beside it.
set -euo pipefail
source "$(dirname "$0")/common.sh"

wind=15
seed=1
personas=""
courses=""
winds="12,18,24"
run="personas"
table_only=0
alone=0
jobs=6
extra=()
for arg in "$@"; do
	case "$arg" in
		--wind_kt=*) wind="${arg#*=}" ;;
		--seed=*) seed="${arg#*=}" ;;
		--personas=*) personas="${arg#*=}" ;;
		--courses=*) courses="${arg#*=}" ;;
		--winds=*) winds="${arg#*=}" ;;
		--run=*) run="${arg#*=}" ;;
		--table_only=*) table_only="${arg#*=}" ;;
		--alone=*) alone="${arg#*=}" ;;
		--jobs=*) jobs="${arg#*=}" ;;
		*) extra+=("$arg") ;;
	esac
done
if [[ -z "$personas" ]]; then
	personas="$(ls "$REPO_ROOT/Game/race/personas/"*.tres | xargs -n1 basename | sed 's/\.tres$//' | tr '\n' ',' | sed 's/,$//')"
fi
skippers="$(echo "$personas" | sed 's/\([^,]*\)/persona:\1/g')"

# The name a persona shows in the results (its sheet's name).
shown_name() {
	grep -m1 '^name = ' "$REPO_ROOT/Game/race/personas/$1.tres" | sed 's/name = "\(.*\)"/\1/'
}

# A persona's result line in a race's output, or nothing.
result_line() {
	grep -E "^ *[0-9]+\. +$2( |$)" "$1" | head -1 || true
}

# Alone: every persona on its own in every race, a few Godot processes at a time; then each race's
# times ranked, and one line per persona.
if [[ -n "$courses" && "$alone" == "1" ]]; then
	folder="$REPO_ROOT/.sim_output/persona_alone_$run"
	out="$REPO_ROOT/.sim_output/persona_alone_$run.txt"
	if [[ "$table_only" != "1" ]]; then
		godot="$(find_godot)"
		import_project "$godot"
		for course in ${courses//,/ }; do
			for w in ${winds//,/ }; do
				mkdir -p "$folder/${course}_${w}"
				for name in $(echo "$personas" | tr ',' ' '); do
					while (( $(jobs -rp | wc -l) >= jobs )); do wait -n || true; done
					"$godot" --headless --no-header --path "$PROJECT_DIR" -s res://dev/run_race.gd -- \
						"--course=$course" "--wind_kt=$w" "--skippers=persona:$name" --prestart=60 \
						"--seed=$seed" "--out_dir=$folder/${course}_${w}/$name" ${extra[@]+"${extra[@]}"} \
						> "$folder/${course}_${w}/$name.txt" 2>&1 &
				done
			done
		done
		wait
	fi
	{
		# One row per race and persona: the race, the name, the time in seconds (99999 for no
		# finish), the falls, and the time as printed.
		for course in ${courses//,/ }; do
			for w in ${winds//,/ }; do
				for name in $(echo "$personas" | tr ',' ' '); do
					line="$(grep -E '^ *1\. ' "$folder/${course}_${w}/$name.txt" 2>/dev/null | head -1 || true)"
					shown="$(shown_name "$name")"
					if [[ -z "$line" ]]; then echo "${course}_${w} $shown 99999 0 none"; continue; fi
					time="$(echo "$line" | awk '{print $3}')"
					falls="$(echo "$line" | sed -E 's/.*falls ([0-9]+).*/\1/')"
					seconds="$(echo "$time" | awk -F: '$1 ~ /^[0-9]+$/ {print $1 * 60 + $2; next} {print 99999}')"
					echo "${course}_${w} $shown $seconds $falls $time"
				done
			done
		done
	} > "$folder/rows.txt"
	{
		echo "Each persona alone against the clock (seed $seed): time, and its rank among the personas in that race"
		printf '%-8s' "persona"
		for course in ${courses//,/ }; do for w in ${winds//,/ }; do printf ' %13s' "$(echo "$course" | sed 's/_.*//')@$w"; done; done
		printf '  %5s %5s\n' "falls" "mean"
		for name in $(echo "$personas" | tr ',' ' '); do
			shown="$(shown_name "$name")"
			printf '%-8s' "$shown"
			falls=0; rank_sum=0; races=0
			for course in ${courses//,/ }; do
				for w in ${winds//,/ }; do
					row="$(awk -v r="${course}_${w}" -v n="$shown" '$1 == r && $2 == n' "$folder/rows.txt")"
					seconds="$(echo "$row" | awk '{print $3}')"
					rank="$(awk -v r="${course}_${w}" -v s="$seconds" '$1 == r && $3 < s {k++} END {print k + 1}' "$folder/rows.txt")"
					falls=$((falls + $(echo "$row" | awk '{print $4}')))
					rank_sum=$((rank_sum + rank)); races=$((races + 1))
					printf ' %9s %3s' "$(echo "$row" | awk '{print $5}')" "$rank"
				done
			done
			printf '  %5d %5s\n' "$falls" "$(awk -v s="$rank_sum" -v n="$races" 'BEGIN {printf "%.1f", s / n}')"
		done
	} | tee "$out"
	echo "Saved to $out"
	exit 0
fi

if [[ -n "$courses" ]]; then
	if [[ "$table_only" != "1" ]]; then
		"$(dirname "$0")/race_matrix.sh" "--run=$run" "--courses=$courses" "--winds=$winds" "--skippers=$skippers" \
			"--seed=$seed" ${extra[@]+"${extra[@]}"} > /dev/null
	fi
	folder="$REPO_ROOT/.sim_output/race_matrix_$run"
	out="$REPO_ROOT/.sim_output/persona_matrix_$run.txt"
	races=()
	for course in ${courses//,/ }; do
		for w in ${winds//,/ }; do
			races+=("${course}_${w}")
		done
	done
	{
		for race in "${races[@]}"; do
			echo "== ${race%_*} at ${race##*_} kt"
			grep -E '^ *[0-9]+\. ' "$folder/$race/out.txt" || echo "(no result: see $folder/$race/out.txt)"
		done
		echo
		# One line per persona: its place in each race (D = did not finish), its falls, and the notes.
		printf '%-8s' "persona"
		for race in "${races[@]}"; do printf ' %9s' "$(echo "${race%_*}" | sed 's/_.*//')@${race##*_}"; done
		printf '  %5s %4s   %s\n' "falls" "DNF" "specialist?"
		for name in $(echo "$personas" | tr ',' ' '); do
			shown="$(shown_name "$name")"
			printf '%-8s' "$shown"
			falls=0; dnf=0
			first_sum=0; first_n=0; second_sum=0; second_n=0; light_sum=0; light_n=0; strong_sum=0; strong_n=0
			first_course="${courses%%,*}"
			lightest="$(echo "$winds" | tr ',' '\n' | sort -n | head -1)"
			strongest="$(echo "$winds" | tr ',' '\n' | sort -n | tail -1)"
			for race in "${races[@]}"; do
				line="$(result_line "$folder/$race/out.txt" "$shown")"
				if [[ -z "$line" ]]; then printf ' %9s' "-"; continue; fi
				place="$(echo "$line" | sed -E 's/^ *([0-9]+)\..*/\1/')"
				f="$(echo "$line" | sed -E 's/.*falls ([0-9]+).*/\1/')"
				falls=$((falls + f))
				if echo "$line" | grep -q ' DNF '; then dnf=$((dnf + 1)); printf ' %9s' "D$place"; else printf ' %9s' "$place"; fi
				if [[ "${race%_*}" == "$first_course" ]]; then first_sum=$((first_sum + place)); first_n=$((first_n + 1));
				else second_sum=$((second_sum + place)); second_n=$((second_n + 1)); fi
				if [[ "${race##*_}" == "$lightest" ]]; then light_sum=$((light_sum + place)); light_n=$((light_n + 1)); fi
				if [[ "${race##*_}" == "$strongest" ]]; then strong_sum=$((strong_sum + place)); strong_n=$((strong_n + 1)); fi
			done
			# A specialist: three places better on average on one course than the other, or in the
			# lightest wind than the strongest.
			note=""
			if (( first_n > 0 && second_n > 0 )); then
				if (( first_sum * second_n + 3 * first_n * second_n <= second_sum * first_n )); then note="course ($first_course)";
				elif (( second_sum * first_n + 3 * first_n * second_n <= first_sum * second_n )); then note="slalom"; fi
			fi
			if (( light_n > 0 && strong_n > 0 && lightest != strongest )); then
				if (( light_sum * strong_n + 3 * light_n * strong_n <= strong_sum * light_n )); then note="$note light wind";
				elif (( strong_sum * light_n + 3 * light_n * strong_n <= light_sum * strong_n )); then note="$note strong wind"; fi
			fi
			printf '  %5d %4d   %s\n' "$falls" "$dnf" "$note"
		done
	} | tee "$out"
	echo "Saved to $out"
	exit 0
fi

out="$REPO_ROOT/.sim_output/persona_matrix.txt"
mkdir -p "$REPO_ROOT/.sim_output/persona_matrix"
godot="$(find_godot)"
import_project "$godot"
declare -A families=([course]="template:LG2@40" [slalom]="template:PD3@60")
for family in course slalom; do
	dir="$REPO_ROOT/.sim_output/persona_matrix/$family"
	mkdir -p "$dir"
	"$godot" --headless --no-header --path "$PROJECT_DIR" -s res://dev/run_race.gd -- \
		"--course=${families[$family]}" "--wind_kt=$wind" "--skippers=$skippers" --prestart=60 \
		--finish_window=900 "--seed=$seed" "--out_dir=$dir" "${extra[@]+"${extra[@]}"}" > "$dir/out.txt" 2>&1 &
done
wait

: > "$out"
for family in course slalom; do
	dir="$REPO_ROOT/.sim_output/persona_matrix/$family"
	{
		echo "== ${families[$family]} at $wind kt (the $family family)"
		grep -E '^ *[0-9]+\. ' "$dir/out.txt" || echo "(no result: see $dir/out.txt)"
	} | tee -a "$out"
done

# The table: one line per persona, its place on each family, and the difference.
{
	echo
	printf '%-14s %8s %8s   %s\n' "persona" "course" "slalom" "specialist?"
	for name in $(echo "$personas" | tr ',' ' '); do
		shown="$(shown_name "$name")"
		pc="$(result_line "$REPO_ROOT/.sim_output/persona_matrix/course/out.txt" "$shown" | sed -E 's/^ *([0-9]+)\..*/\1/')"
		ps="$(result_line "$REPO_ROOT/.sim_output/persona_matrix/slalom/out.txt" "$shown" | sed -E 's/^ *([0-9]+)\..*/\1/')"
		note=""
		if [[ -n "$pc" && -n "$ps" ]]; then
			if (( ps + 3 <= pc )); then note="slalom"; elif (( pc + 3 <= ps )); then note="course"; fi
		fi
		printf '%-14s %8s %8s   %s\n' "$shown" "${pc:--}" "${ps:--}" "$note"
	done
} | tee -a "$out"
echo "Saved to $out"
