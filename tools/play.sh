#!/usr/bin/env bash
# Plays the game. Optionally start in a specific scene: tools/play.sh res://world/test.tscn
set -euo pipefail
source "$(dirname "$0")/common.sh"

godot="$(find_godot)"
exec "$godot" --path "$PROJECT_DIR" "$@"
