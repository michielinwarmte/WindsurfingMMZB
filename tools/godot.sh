#!/usr/bin/env bash
# Runs the Godot version this project uses, passing all arguments through.
# Use this instead of a bare `godot`, so everyone (and every AI session) gets the same version.
#
# Example: tools/godot.sh --headless --path Game --script res://dev/check_project.gd
set -euo pipefail
source "$(dirname "$0")/common.sh"

godot="$(find_godot)"
exec "$godot" "$@"
