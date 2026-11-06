#!/usr/bin/env bash
# Starts the game in a window, lets it run for a moment, saves a screenshot and quits.
# Lets you (or an AI) check what the game looks like without playing it.
#
#   tools/screenshot.sh                                 main scene -> .screenshots/latest.png
#   tools/screenshot.sh res://world/test.tscn           a different scene
#   tools/screenshot.sh res://main.tscn out.png 180     scene, output file, frames to wait
#   tools/screenshot.sh res://main.tscn out.png 180 --camera=3 --autopilot=1
#                                                       extra options for the game (main.gd)
#   tools/screenshot.sh res://ui/start_menu.tscn wide.png 120 --resolution=3137x1263
#                                                       another window size (default 1280x720)
#
# The game runs at a fixed 60 frames per second of game time, so 180 frames = 3 seconds.
# The window is 1280x720; --resolution=3137x1263 (or SCREENSHOT_RESOLUTION=3137x1263 before the
# command) makes it another size (Max's wide window). The game is drawn at that size even where the
# screen is smaller than it (the window then shows it shrunk; --render_size in Game/dev/dev_capture.gd),
# so the picture is that size.
# A sequence, to see something move: ... --sequence=6 --every=60 saves out_1.png to out_6.png,
# the first after the frames to wait and then one every 60 frames (Game/dev/dev_capture.gd).
# Prints any engine or shader errors. Needs a desktop session: a window opens briefly.
set -euo pipefail
source "$(dirname "$0")/common.sh"

scene="${1:-}"
output="${2:-$REPO_ROOT/.screenshots/latest.png}"
frames="${3:-60}"
# The window size is Godot's own option; every other extra option goes to the game. Another size
# than the default is also the size the game draws at (--render_size).
resolution="${SCREENSHOT_RESOLUTION:-1280x720}"
extra=()
for option in "${@:4}"; do
	case "$option" in
		--resolution=*) resolution="${option#--resolution=}" ;;
		*) extra+=("$option") ;;
	esac
done
if [[ "$resolution" != "1280x720" ]]; then extra+=(--render_size="$resolution"); fi

mkdir -p "$(dirname "$output")"
output="$(cd "$(dirname "$output")" && pwd)/$(basename "$output")"
rm -f "$output"

# A sequence (--sequence=<count> --every=<frames>): wait for all of it, and check its first picture.
count=1
every=60
for option in "${extra[@]}"; do
	case "$option" in
		--sequence=*) count="${option#--sequence=}" ;;
		--every=*) every="${option#--every=}" ;;
	esac
done
first="$output"
if [[ "$count" -gt 1 ]]; then
	first="${output%.*}_1.${output##*.}"
	rm -f "$first"
fi

godot="$(find_godot)"
import_project "$godot"

args=(--no-header --path "$PROJECT_DIR" --resolution "$resolution" --fixed-fps 60 --audio-driver Dummy)
# Safety net: quit even if the screenshot helper never runs (for example after a script error).
args+=(--quit-after "$((frames + (count - 1) * every + 600))")
if [[ -n "$scene" ]]; then args+=("$scene"); fi

log="$REPO_ROOT/.logs/screenshot.log"
status=0
timeout 300 "$godot" "${args[@]}" -- --screenshot="$output" --frames="$frames" "${extra[@]}" >"$log" 2>&1 || status=$?

grep -E "SCRIPT ERROR|SHADER ERROR|^ERROR|^WARNING|^ +at: " "$log" || true
if [[ $status -ne 0 || ! -f "$first" ]]; then
	echo "No screenshot was saved (exit code $status). Full log: $log" >&2
	exit 1
fi
if [[ "$count" -gt 1 ]]; then echo "Screenshots: ${output%.*}_1 to _$count.${output##*.}"; else echo "Screenshot: $output"; fi
