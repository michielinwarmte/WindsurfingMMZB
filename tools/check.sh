#!/usr/bin/env bash
# Checks that every script, scene and resource in Game/ still loads, without running the game.
# Catches typos, missing static types and broken file references quickly.
# Exit code 0 means everything loaded.
set -euo pipefail
source "$(dirname "$0")/common.sh"

godot="$(find_godot)"
import_project "$godot"

log="$REPO_ROOT/.logs/check.log"
status=0
"$godot" --headless --no-header --path "$PROJECT_DIR" -s res://dev/check_project.gd >"$log" 2>&1 || status=$?

# Show the summary and any engine errors (with the file and line they point at).
grep -E "^Checked|^  FAILED|SCRIPT ERROR|^ERROR|^WARNING|^ +at: " "$log" || true
if grep -qE "SCRIPT ERROR|^ERROR" "$log"; then status=1; fi
exit "$status"
