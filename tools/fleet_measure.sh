#!/usr/bin/env bash
# The fleet's frame time by fleet size (F1, Documentation/AI_FLEET_PLAN.md, D2): the release build
# (tools/release.sh) runs a race once per size with that many AI boards and --measure, and this
# prints one table row per size. The AI boards are the four characters repeated (allrounder,
# gambler, rookie, cautious, allrounder, ...), so their names repeat: fine for a measurement.
#
#   tools/fleet_measure.sh                                  8, 16, 24, 32 and 40 AI boards on T1
#   tools/fleet_measure.sh --sizes=8,16 --seconds=12 --course=t1_loop
#   tools/fleet_measure.sh --build                          rebuild the pack first (after a change)
#   tools/fleet_measure.sh --threads=0                      any other option goes to the game
#
# The numbers depend on the machine and on what else it is doing (a training in the background
# slows everything): compare runs made back to back on the same machine. Each run ends by itself
# (the game quits after --measure); a run that takes more than three minutes is stopped and its row
# says so. Every run is silent (--mute: Max sleeps next to the laptop). The full output of each
# run is kept in .logs/fleet_measure_<size>.log.
set -euo pipefail
source "$(dirname "$0")/common.sh"

sizes="8,16,24,32,40"
course="t1_loop"
seconds="12"
rebuild=0
extra=()
for arg in "$@"; do
	case "$arg" in
		--sizes=*) sizes="${arg#*=}" ;;
		--course=*) course="${arg#*=}" ;;
		--seconds=*) seconds="${arg#*=}" ;;
		--build) rebuild=1 ;;
		*) extra+=("$arg") ;;
	esac
done

release_dir="$REPO_ROOT/.release"
if [[ "$rebuild" == 1 || ! -f "$release_dir/wsim.pck" ]]; then
	"$REPO_ROOT/tools/release.sh" build
fi
mkdir -p "$REPO_ROOT/.logs"

characters=(allrounder gambler rookie cautious)
LIMIT_S=180

# The names of n AI boards: the four characters, repeated.
skipper_names() {
	local n="$1" names="" i
	for ((i = 0; i < n; i++)); do
		names+="${names:+,}${characters[i % 4]}"
	done
	echo "$names"
}

# Stops this release build's game (only the engine in this checkout's .release folder, so another
# checkout's game or the editor engine of a training run is left alone).
stop_the_game() {
	local exe_dir
	exe_dir="$(cygpath -w "$release_dir" 2>/dev/null || echo "$release_dir")"
	powershell.exe -NoProfile -Command "Get-CimInstance Win32_Process -Filter \"Name like 'wsim%'\" | Where-Object { \$_.ExecutablePath -like '$exe_dir*' } | ForEach-Object { taskkill /F /T /PID \$_.ProcessId | Out-Null }" || true
}

# One table row from a run's output (the lines --measure prints, main.gd).
row_from_log() {
	gawk -v ai="$1" '
		match($0, /Measured .* ([0-9.]+) fps; a frame ([0-9.]+) ms on average, ([0-9.]+) ms at worst; physics ([0-9.]+) ms and the rest ([0-9.]+) ms/, m) {
			fps = m[1]; avg = m[2]; worst = m[3]; rest = m[5]
		}
		match($0, /all boards. physics ([0-9.]+) ms/, m) { together = m[1] }
		# The summary line of the AI boards (since F1 fleet_frame).
		match($0, /the AI boards .*physics median ([0-9.]+), worst ([0-9.]+)/, m) { median = m[1]; worst_board = m[2] }
		# One line per opponent (before fleet_frame): the median and the worst are worked out here.
		match($0, /^  Opponent[0-9]+: .*physics ([0-9.]+),/, m) { steps[++n] = m[1] + 0 }
		END {
			if (fps == "") { printf "| %s | no measurement (see the log) | | | | |\n", ai; exit }
			if (median == "" && n > 0) {
				asort(steps)
				median = (n % 2 == 1) ? steps[(n + 1) / 2] : (steps[n / 2] + steps[n / 2 + 1]) / 2
				worst_board = steps[n]
				median = sprintf("%.2f", median); worst_board = sprintf("%.2f", worst_board)
			}
			printf "| %s | %s | %s / %s | %s | %s / %s | %s |\n", ai, fps, avg, worst, together, median, worst_board, rest
		}' "$2"
}

echo "Fleet on $course, the release build, $seconds s measured per size (the player's board as well)."
echo
echo "| AI boards | fps | A frame, average / worst (ms) | All boards' physics per tick, side by side (ms) | A board's own step, median / worst (ms) | The rest of a frame (ms) |"
echo "|---|---|---|---|---|---|"
IFS=',' read -r -a size_list <<< "$sizes"
for size in "${size_list[@]}"; do
	log="$REPO_ROOT/.logs/fleet_measure_$size.log"
	"$REPO_ROOT/tools/release.sh" --mute --race="$course" --skippers="$(skipper_names "$size")" --measure="$seconds" "${extra[@]}" > "$log" 2>&1 &
	pid=$!
	waited=0
	while kill -0 "$pid" 2>/dev/null && ((waited < LIMIT_S)); do
		sleep 1
		waited=$((waited + 1))
	done
	if kill -0 "$pid" 2>/dev/null; then
		stop_the_game
		kill "$pid" 2>/dev/null || true
		wait "$pid" 2>/dev/null || true
		echo "| $size | stopped: still running after $LIMIT_S s | | | | |"
		continue
	fi
	wait "$pid" 2>/dev/null || true
	row_from_log "$size" "$log"
done
