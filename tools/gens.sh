#!/usr/bin/env bash
# A night's generations race each other, so that the team can see what got better from
# generation to generation (Max, 21 October 2026; AI_FLEET_PLAN.md, F5). The trainer
# (tools/race_evolve.sh) saves the best brain of generation 1 and of every tenth generation as
# Game/race/brains/<run>_gen<N>.json, and the best of the whole run as <run>_best.json. This picks
# up to --count of them, spread evenly from the first generation to the last (the first, the last
# and best always among them), and puts them on the course together, each on its own board, no
# scripted characters and no player's board.
#
# The race is set up the way the brains were trained, or they do not start at all: 15 kt, the
# boards 150 m behind the line, a 30 s countdown, placed along the line, and blind to each other
# (a brain never saw another board in training). The boards pass through each other.
#
#   tools/gens.sh                                 the night2b generations, 20 boards, in the game:
#                                                 the camera follows the leader; Tab and Shift+Tab
#                                                 step through the boards, L follows the leader
#                                                 again, 1 to 4 are the camera modes, R starts again
#   tools/gens.sh --run=night2a --count=10        another run, fewer boards
#   tools/gens.sh --headless                      the same race without a window: a table by
#                                                 generation (the start after the gun, the steps,
#                                                 the distance left to the next mark, falls, tacks)
#   tools/gens.sh --build                         rebuild the game first (after a code change)
#   ... [--course=t1_loop] [--wind=15] [--prestart=30] [--behind=150] [--blind=1] [--seconds=720]
#       [--mute] [--spectate=1]
#
# The game is the release build (tools/release.sh): rebuild it with --build after any change to
# the game's code, or the race runs on the old pack.
set -euo pipefail
source "$(dirname "$0")/common.sh"

run="night2b"
count=20
course="t1_loop"
wind=15
prestart=30
behind=150
blind=1
seconds=720
spectate=1
headless=0
mute=0
build=0
for arg in "$@"; do
	case "$arg" in
		--run=*) run="${arg#*=}" ;;
		--count=*) count="${arg#*=}" ;;
		--course=*) course="${arg#*=}" ;;
		--wind=*) wind="${arg#*=}" ;;
		--prestart=*) prestart="${arg#*=}" ;;
		--behind=*) behind="${arg#*=}" ;;
		--blind=*) blind="${arg#*=}" ;;
		--seconds=*) seconds="${arg#*=}" ;;
		--spectate=*) spectate="${arg#*=}" ;;
		--headless) headless=1 ;;
		--mute) mute=1 ;;
		--build) build=1 ;;
		*) echo "Unknown option $arg (see the top of tools/gens.sh)" >&2; exit 2 ;;
	esac
done

brains="$REPO_ROOT/Game/race/brains"

# The run's generations, by number: "<run>_gen<N>.json" gives N; "<run>_best.json" comes last.
gens=()
for file in "$brains/${run}"_gen*.json; do
	[[ -f "$file" ]] || continue
	name="$(basename "$file" .json)"
	gens+=("${name#${run}_gen}")
done
if [[ ${#gens[@]} -eq 0 ]]; then
	echo "No brains named ${run}_gen<N>.json in Game/race/brains (runs there: $(ls "$brains" | sed -n 's/_best\.json$//p' | tr '\n' ' '))" >&2
	exit 1
fi
mapfile -t gens < <(printf '%s\n' "${gens[@]}" | sort -n)
best=""
[[ -f "$brains/${run}_best.json" ]] && best="best"

# Pick --count of them: all when there are no more than that; otherwise evenly spread from the
# first to the last (both always in), with best taking one place.
slots=$count
[[ -n "$best" ]] && slots=$((count - 1))
picked=()
total=${#gens[@]}
if (( total <= slots )); then
	picked=("${gens[@]}")
else
	for (( i = 0; i < slots; i++ )); do
		# The nearest generation to i/(slots-1) of the way through the list.
		index=$(( (i * (total - 1) * 2 + (slots - 1)) / ((slots - 1) * 2) ))
		picked+=("${gens[$index]}")
	done
fi

skippers=""
for g in "${picked[@]}"; do
	skippers+="brain:${run}_gen${g},"
done
[[ -n "$best" ]] && skippers+="brain:${run}_best,"
skippers="${skippers%,}"
[[ -n "$best" ]] && boards=$(( ${#picked[@]} + 1 )) || boards=${#picked[@]}

echo "Run $run: generations ${picked[*]}${best:+ and best} ($boards boards) on $course at $wind kt, $behind m behind the line, a $prestart s countdown, blind $blind"

if (( headless )); then
	# The headless race, then its result lines sorted by generation, with the generation in front.
	output="$("$REPO_ROOT/tools/race.sh" "--course=$course" "--skippers=$skippers" "--wind_kt=$wind" "--prestart=$prestart" \
		"--behind=$behind" "--blind=$blind" "--seconds=$seconds" --spawn=line 2>&1)"
	echo "$output" | grep -E "^Race on|^Finished|^Stopped" || true
	echo
	printf '%-6s %-9s %-7s %-16s %-30s %s\n' "gen" "place" "steps" "start after gun" "finish / distance left" "falls tacks gybes"
	echo "$output" | grep -E "^ *[0-9]+\. ${run}_" | while IFS= read -r line; do
		name="$(echo "$line" | sed -E 's/^ *[0-9]+\. +([^ ]+).*/\1/')"
		gen="${name#${run}_}"
		gen="${gen#gen}"
		place="$(echo "$line" | sed -E 's/^ *([0-9]+)\..*/\1/')"
		steps="$(echo "$line" | sed -E 's/.* ([0-9]+\/[0-9]+) steps.*/\1/')"
		splits="$(echo "$line" | sed -E 's/.*splits ([^ ]+|-).*/\1/')"
		start="$splits"
		[[ "$splits" == "-" ]] && start="no start"
		finish="$(echo "$line" | sed -E 's/^ *[0-9]+\. +[^ ]+ +([^ ]+) .*/\1/')"
		if [[ "$finish" == "DNF" ]]; then
			finish="$(echo "$line" | sed -nE 's/.*to (.*) m$/\1 m left/p')"
		fi
		rest="$(echo "$line" | sed -E 's/.*falls ([0-9]+) +tacks ([0-9]+) +gybes ([0-9]+).*/\1 \2 \3/')"
		order="$gen"
		[[ "$gen" == "best" ]] && order=999999
		printf '%s\t%-6s %-9s %-7s %-16s %-30s %s\n' "$order" "$gen" "$place" "$steps" "$start" "$finish" "$rest"
	done | sort -n | cut -f2-
	exit 0
fi

(( build )) && "$REPO_ROOT/tools/release.sh" build
game_args=("--race=$course" "--skippers=$skippers" "--prestart=$prestart" --spawn=line "--behind=$behind" "--blind=$blind" "--spectate=$spectate" "--wind=$wind")
(( mute )) && game_args=(--mute "${game_args[@]}")
exec "$REPO_ROOT/tools/release.sh" "${game_args[@]}"
