#!/usr/bin/env bash
# Opens the project in the Godot editor.
set -euo pipefail
source "$(dirname "$0")/common.sh"

godot="$(find_godot)"
exec "$godot" --path "$PROJECT_DIR" --editor "$@"
