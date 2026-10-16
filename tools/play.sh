#!/usr/bin/env bash
# Plays the game. Optionally start in a specific scene: tools/play.sh res://world/test.tscn
#
# Short names, so you don't have to type the res:// path:
#   tools/play.sh silvaplana     the Silvaplana map: fly around the terrain (map track, M1)
#   tools/play.sh wind           the wind viewer: the Maloja over Silvaplana, with the course maker (map track, W2, W4a)
#
# Double-clicked, it asks what to start; Enter opens the game's start menu.
set -euo pipefail
source "$(dirname "$0")/common.sh"

# A double-clicked script runs in a fresh window whose shell is the first one (SHLVL 1);
# from a terminal the script is a second shell (the same test as tools/map/build.sh).
double_clicked() {
	[[ -t 0 && "${SHLVL:-1}" -le 1 ]]
}

# Keep a double-clicked window open when something goes wrong before the game starts
# (for example when Godot isn't found), so the message can be read.
trap 'status=$?; if [[ $status -ne 0 ]] && double_clicked; then read -rp "Press Enter to close this window." _; fi' EXIT

# The scene behind a short name; anything else is passed on unchanged.
scene_for() {
	case "$1" in
		silvaplana) echo "res://maps/silvaplana/dev/terrain_view.tscn" ;;
		wind) echo "res://maps/silvaplana/wind_viewer.tscn" ;;
		*) echo "$1" ;;
	esac
}

args=("$@")
if [[ $# -eq 0 ]] && double_clicked; then
	echo "What do you want to start?"
	echo "  1  the game: the start menu (or just press Enter)"
	echo "  2  Silvaplana: fly around the terrain (keys 1-4: viewpoints, W A S D E Q: fly, right mouse: look)"
	echo "  3  Silvaplana wind viewer: the Maloja's streaks and speeds, and the course maker (Tab: camera, click: wind at a point, M: course)"
	read -rp "> " choice
	if [[ "$choice" == "2" ]]; then args=(silvaplana); fi
	if [[ "$choice" == "3" ]]; then args=(wind); fi
fi
if [[ ${#args[@]} -gt 0 ]]; then args[0]="$(scene_for "${args[0]}")"; fi

godot="$(find_godot)"
exec "$godot" --path "$PROJECT_DIR" ${args[@]+"${args[@]}"}
