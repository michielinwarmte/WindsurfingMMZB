#!/usr/bin/env bash
# Starts the game in a window, lets it run for a moment, saves a screenshot and quits.
# Lets you (or an AI) check what the game looks like without playing it.
#
#   tools/screenshot.sh                                 main scene -> .screenshots/latest.png
#   tools/screenshot.sh res://world/test.tscn           a different scene
#   tools/screenshot.sh res://main.tscn out.png 180     scene, output file, frames to wait
#
# The game runs at a fixed 60 frames per second of game time, so 180 frames = 3 seconds.
# Prints any engine or shader errors. Needs a desktop session: a window opens briefly.
set -euo pipefail
source "$(dirname "$0")/common.sh"

scene="${1:-}"
output="${2:-$REPO_ROOT/.screenshots/latest.png}"
frames="${3:-60}"

mkdir -p "$(dirname "$output")"
output="$(cd "$(dirname "$output")" && pwd)/$(basename "$output")"
rm -f "$output"

godot="$(find_godot)"
import_project "$godot"

args=(--no-header --path "$PROJECT_DIR" --resolution 1280x720 --fixed-fps 60 --audio-driver Dummy)
# Safety net: quit even if the screenshot helper never runs (for example after a script error).
args+=(--quit-after "$((frames + 600))")
if [[ -n "$scene" ]]; then args+=("$scene"); fi

log="$REPO_ROOT/.logs/screenshot.log"
status=0
timeout 300 "$godot" "${args[@]}" -- --screenshot="$output" --frames="$frames" >"$log" 2>&1 || status=$?

grep -E "SCRIPT ERROR|SHADER ERROR|^ERROR|^WARNING|^ +at: " "$log" || true
if [[ $status -ne 0 || ! -f "$output" ]]; then
	echo "No screenshot was saved (exit code $status). Full log: $log" >&2
	exit 1
fi
echo "Screenshot: $output"
